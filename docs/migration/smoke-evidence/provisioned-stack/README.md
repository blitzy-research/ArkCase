# Smoke Evidence With The Reference Services Provisioned

This directory holds a **second** migrated-side smoke capture, taken against the same
deployed artifact as the paired capture in `../migrated/` but with two reference services
provisioned that the paired capture did not have. It exists because the paired capture
left four of the eight flows unexercised, and the reason turned out to be a single missing
service rather than eight separate obstacles.

## What this is not

**This is not a baseline comparison, and it must never be read as one.** There is no
`../baseline/` counterpart taken with the same services provisioned, because obtaining one
would require the base commit deployed on the older runtime against the same stack, which
this environment cannot produce. The comparison of record therefore remains the paired
`../baseline/` against `../migrated/` capture, whose two sides share one posture and are
diffable row for row. Nothing here supersedes that pair, and nothing here is a
before-and-after measurement.

What this capture *is*: direct observation that behaviours the paired capture could not
reach do work on the migrated runtime. That is one-sided evidence, and one-sided evidence
is worth having when the alternative is none — but it is evidence of function, not of
equivalence.

## The blocking chain, which was one service and not four

The paired capture recorded four flows as `NOT-EXERCISED` with four different reasons — no
fixture object, no event produced, workflow not started, no case file available. Tracing
them showed a single cause behind all four, and it is worth stating because the four
separate reasons obscure it.

Complaint creation `POST /api/latest/plugin/complaint` returned **400** with
`RollbackException: Transaction "rolled back" because transaction was set to RollbackOnly`.
The cause is upstream of the database: ArkCase creates the object's ECM container folder
through CMIS **inside the same transaction**, so with no content repository reachable the
Camel route raises `CmisConnectionException: Connection refused`, the folder creation fails,
the transaction is marked rollback-only and no object is ever created. Flows 3, 5 and 7
then had nothing to act on, and flow 8 found no case file. So the content repository is a
**hard, transactional** dependency of object creation, not a soft one that degrades.

**The whole chain is quoted verbatim in [`blocking-chain.txt`](blocking-chain.txt)**, extracted
from the deployment's own log4j2 error log by the committed
[`extract-blocking-chain.py`](extract-blocking-chain.py) over a stated three-second window, with
the source path, the record counts and the extractor's digest in the header so the extraction can
be repeated rather than taken on trust. An earlier revision of this section named
`CmisConnectionException` with no committed evidence carrying it — the chain had been read from a
live log and not preserved — so the strongest claim on this page rested on nothing a reader could
check. That file is the repair. It also carries the independent evidence for the folder-creation
claim in the next section: a *suppressed* `CamelCmisObjectNotFoundException` names the exact path
`/Sites/acm/documentLibrary/Complaints/2026`, which is the application looking the parent up, not
finding it, and failing instead of creating it.

The chain reads identically on either runtime — every exception in it is a refused connection to
a service that was not running — so it explains a **coverage** gap and is not a defect report
against Java 17.

## What was provisioned, and how

Provisioned for this capture only, on the container host, with clone-scoped names and ports
so nothing collides with a parallel run:

| Service | Image | Name | Port |
| --- | --- | --- | --- |
| Content repository | `alfresco/alfresco-content-repository-community:6.2.0-ga` | `arkcase-w046-alfresco` | 46091 |
| Its database | `postgres:13-alpine` | `arkcase-w046-alfresco-db` | internal |
| Search | `solr:7.6.0` | `arkcase-w046-solr` | 46983 |
| TLS front for search | `nginx:1.27.5-alpine` | `arkcase-w046-solr-tls` | 46443 |

Four configuration steps were needed beyond starting the containers, and each is recorded
because each is a fact about what ArkCase requires rather than an incidental detail.

1. **The `acm` site and its folder structure had to be created by hand.** ArkCase resolves
   `/Sites/acm/documentLibrary/<ObjectType>/<year>` and, when the parent is missing, does
   **not** create it — it fails the whole transaction. The site plus `Complaints`,
   `Case Files`, `Tasks`, `Documents`, `Consultations`, `People`, `Organizations`,
   `Timesheets` and `Costsheets` were created; ArkCase creates the year folder itself.
2. **Two dynamic fields had to be added to the search schema.** The stock configset carries
   `*_s`, `*_ss`, `*_i`, `*_b` and `*_dt` but not ArkCase's `*_tdt` or `*_lcs`, so a sort on
   `create_date_tdt` was rejected with `sort param field can't be found`. Both were added
   through the Schema API, plus a `catch_all` field, since ArkCase queries pass
   `df=catch_all`.
3. **Search had to be fronted with TLS.** See the defect note below — the indexing path
   ignores the configured protocol.
4. **That TLS certificate had to be trusted**, by importing it into the deployment's
   truststore.

Read together, points 1 and 2 say something useful beyond this capture: a content
repository and a search core that merely *exist* are not sufficient for ArkCase: it expects
a specific folder tree and a specific set of dynamic fields, and it fails in unhelpful ways
when either is absent.

## Flow census, against the paired capture

| Flow | `../migrated/` (paired) | Here |
| --- | --- | --- |
| 1 login | OBSERVED-AUTHENTICATED-AND-IDENTITY-CONFIRMED | unchanged |
| 2 views | OBSERVED-INCOMPLETE-2-REQUIREMENTS-UNMET | OBSERVED-INCOMPLETE-**1** |
| 3 alfresco-roundtrip | **NOT-EXERCISED-NO-FIXTURE-OBJECT** | **OBSERVED-ROUNDTRIP-COMPLETED** |
| 4 solr-search | OBSERVED-INCOMPLETE-5-REQUIREMENTS-UNMET | **OBSERVED-SEARCH-ANSWERED** |
| 5 activemq-event | **NOT-EXERCISED-NO-EVENT-PRODUCED** | **OBSERVED-INCOMPLETE-1** |
| 6 generated-number | OBSERVED-INCOMPLETE-4-REQUIREMENTS-UNMET | OBSERVED-INCOMPLETE-**1** |
| 7 workflow-start | **NOT-EXERCISED-WORKFLOW-NOT-STARTED** | **OBSERVED-INCOMPLETE-3** |
| 8 queue-transition | **NOT-EXERCISED-NO-CASE-FILE-AVAILABLE** | **OBSERVED-INCOMPLETE-2** |

**Zero flows remain unexercised, against four before.** Three flows reach a complete
verdict. The run is still `completeness: INCOMPLETE`, and that is correct — an
`OBSERVED-INCOMPLETE` verdict is not a pass, and the residual requirements are listed below
rather than absorbed into the headline.

## What this capture discharges

Each item names the observation and where to re-read it, because a claim of discharge is
only as good as the field it rests on.

- **The rule-engine numbering path, which the plan calls the highest-impact runtime fix in
  the backend track.** `flow-6-generated-number.status` records `CREATE: 200` and
  `NUMBER_ASSIGNED: yes`, and `flow-6-generated-number.out` records
  `numbering-format-observed: 99999999_999` against
  `numbering-format-expected: 99999999_999`. Successive creations produced successive
  numbers, so the sequence advances rather than repeating. This is the MVEL-through-decision-table
  path executing on the new runtime and returning the same number shape.
- **The content-repository round trip, and with it the activation framework's MIME
  resolution.** `flow-3-alfresco-roundtrip.status` records `upload-document=200`,
  `download-document=200`, `retrieved-bytes-match=yes`, `mime-identity=yes` and
  `roundtrip=requirements-unmet-0`. The MIME identity is the specific reason the plan
  requires the activation *reference implementation* rather than the API-only jar, and this
  is the first place that requirement is observed rather than argued.
- **The workflow-start request path — and NOT process instantiation, which an earlier
  revision of this list claimed.** `flow-7-workflow-start.status` records `START: 200` and
  `PROCESS_INSTANTIATED: yes`, and that second token does not mean what its name suggests.
  The flow's own record defines it narrowly — instantiation is claimed *only* where the
  start request answered with a JSON body — and the same record states plainly that no
  process instance was created by this run. `PROCESS_INSTANCE_ID: none`,
  `PROCESS_DEFINITION_KEY: not-observed` and `TASK_ASSIGNED: no` are the fields that carry
  the substance, and all three are absences. What this capture discharges is therefore that
  the workflow-start endpoint accepts a request and answers on the migrated runtime; it does
  NOT discharge instantiation. The residual-risk field reads
  `process-engine-observed-here-not-cleared` and it is correct to.
- **The search round trip, through the application.** `flow-4-solr-search` reaches
  `OBSERVED-SEARCH-ANSWERED`: `search-through-application=200` with `RESULT_COUNT: 5`,
  `RESULT_COUNT_STABLE: yes`, and `RESULT_IDS_ORDERED` naming the complaint objects this run
  created. The write half is observed independently — the application's own
  `Posted to Solr` records are in `startup/messaging-init.log` — so index and query are both
  observed rather than inferred from one another.
  One field in the same file is an explicit non-observation and is not glossed:
  `search-engine-direct=000` and `SOLR_PING: 000`. The direct engine probe did not answer,
  because the search engine in this posture is reached through a TLS front the probe does not
  address. That bounds the claim to the path THROUGH the application, which is the path the
  flow is named for; it is not evidence about the engine's own HTTP surface.
- **Served-asset integrity.** `flow-2-views.status` records
  `served-equals-recorded=MATCH` for all five contracted artifacts, so what the deployed
  application serves is byte-identical to what was digested from the build.

## What is still not observed, stated as requirements rather than excuses

| Flow | Unmet | Requirement to close it |
| --- | --- | --- |
| 2 views | `document-view=404` | A document rendition endpoint, which needs the document-preview service; not provisioned |
| 5 activemq-event | `delivery=NOT-OBSERVED` | Broker management credentials so the destination's enqueue count can be read; the twelve delivery probes all answered 200 but transit itself is not asserted from an ambient query |
| 6 generated-number | one requirement | **Not a defect in this run** — the create and the number are both observed (`CREATE: 200`, `NUMBER_ASSIGNED: yes`, `20260807_179` then `20260807_180`, format token `99999999_999` matching the expected token). The one unmet requirement is the one-sidedness of this whole capture: `flow-6-generated-number.result.txt` grades both comparison halves `RECORDED AND COMPARABLE` rather than met, because no counterpart capture was named for the invocation and a sequence-and-format comparison needs two sides. Closing it needs a counterpart, not a fix |
| 7 workflow-start | `TASK_ASSIGNED: no`, `PROCESS_INSTANCE_ID: none` | A process definition whose start event assigns a task to the calling user, and a start response that returns the instance identifier |
| 8 queue-transition | `next-possible-queues=500` | A case file that **has** a queue. See the second defect below: the endpoint raises a null-pointer rather than returning an empty list when the case file's queue is null, and queue assignment did not fire for an API-created case file in this deployment |

Flow 8's object discovery **did** work — `OBJECT_ID: 104` is the case file this run created,
found through search — so the flow reached its subject and stopped at the endpoint, not
before it.

## Two pre-existing defects found while doing this

Both are registered in [Pre-existing Defects](../../pre-existing-defects.md) and neither is
fixed here, per the rule that discovered defects are documented rather than repaired. Both
are unrelated to the runtime migration: they behave identically on either runtime.

1. **The search indexing path ignores the configured protocol.**
   `SolrRestClient.postToSolr` builds its URL with a hardcoded `https://` scheme while the
   query path honours the configured `solr.protocol`. A deployment configured for plain
   HTTP therefore searches successfully and indexes nothing, and the failure is quiet: the
   post throws, the message returns to its queue and the only symptom is an index that
   stays empty. This is why a TLS front had to be put in front of search here rather than
   simply configuring `http`.
2. **`nextPossibleQueues` raises a null-pointer for a case file with no queue.** The
   controller dereferences `CaseFile.getQueue().getName()` without a null check, so a case
   file that has not been assigned a queue produces a 500 rather than an empty list.

## Provenance, including four fields in this capture that would otherwise mislead

The 67 files the producer wrote are accounted for by its own
[`notes/manifest.txt`](notes/manifest.txt), which reports `manifest-state: COMPLETE-AND-EXACT`,
`required-but-missing: 0` and `produced-but-not-in-the-manifest: 0`. Four of its fields need
reading in context, and they are set out here rather than left for a reader to stumble over.

| Field | What it says | What it means here |
| --- | --- | --- |
| `published-to: /tmp/smoke-final/migrated` | The directory the producer staged into and published to | **Not** this directory. The producer knows nothing about `provisioned-stack/`; the capture was moved here afterwards, deliberately under a name that cannot be mistaken for the paired `../migrated/`. The field records where the run wrote, which is what makes it re-derivable, so it is left as the producer emitted it rather than edited to match its final home |
| `authored-paths-present-of-those-enumerated: 0 of 6` | None of the six authored files the producer expects are present | Correct and intended. Those six belong to the paired capture and are not duplicated here; `authored-paths-enumerated-but-not-carried: 0` reads 0 because there was no previous publication at the staging path to carry from, which the field beside it states |
| `produced-paths-excluding-the-archived-report-subtree: 67` | The producer wrote 67 paths | This directory holds 70. The three extra are authored additions with no producer: this `README.md`, `blocking-chain.txt` and `extract-blocking-chain.py`. They sit at the capture root rather than inside `notes/` precisely so they cannot be mistaken for producer output or disturb its accounting |
| `both-startup-tiers-present: no` | Only one startup tier was captured | The same condition the paired capture reports; it is not a difference introduced by this posture |

The verdict fields are the producer's own and are not edited anywhere in this directory:
`completeness: INCOMPLETE` in `summary.txt` is correct, because five of the eight flows record
`OBSERVED-INCOMPLETE-n-REQUIREMENTS-UNMET` and an `OBSERVED-*` verdict is not a pass.

## Reproducing

The capture is produced by the committed `../smoke-checks.sh` with the mutating half
enabled, which the script refuses unless both the permission flag and the host allowlist
are set:

```bash
ALLOW_SMOKE_MUTATIONS=1 SMOKE_MUTATION_HOSTS=localhost \
SMOKE_ENGINE_DB_CONTAINER=<engine-db-container> SMOKE_ENGINE_DB_PASSWORD=<password> \
ARKCASE_BASE_URL=<base-url> ARKCASE_USER=<user> ARKCASE_PASSWORD=<password> \
REPO_ROOT="$PWD" CATALINA_LOG=<catalina.out> \
SMOKE_OUT_DIR=<output-directory> ./docs/migration/smoke-evidence/smoke-checks.sh
```

Assertions are on the captured fields, never on the script's exit status — it exits non-zero
whenever any flow is incomplete, which is true of this run and is the correct outcome to
report rather than to suppress.
