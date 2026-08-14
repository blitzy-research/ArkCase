# Known Issues

This page is the register of defects that were **already present at the Java 8 base commit** `c8f6226105` and were deliberately **not** fixed by the Java 17 and Node 20 migration, together with the single condition that *was* fixed because it blocked a named validation item. Everything here was reproduced against the real checkout; nothing is inferred.

The register spans five classes of defect, in the order they appear below: **backend** defects in Java sources, POMs and build plugins; **integration-boundary and security** defects at the edges the application talks to, server-side as well as the browser-side and transport findings the seam review raised; **database and schema-authority** defects, which run from the Liquibase changelogs and the ORM mappings out through the DAOs and the query layer; **frontend** defects in the Grunt pipeline and its configuration; and **frontend-to-API seam** defects, where a browser call and the route it aims at do not agree. Each class earns its own section because each is reached by a different exercise path. Most database defects are not reached by compiling or testing the code — they surface only when a schema is migrated, a routine is called or a user reaches a feature, which is a different exercise path and, for many of them, a different deployment profile or a different database platform. The seam class surfaces only when a specific screen action runs against a live backend: a compile sees both halves and a unit test sees neither, so no gate in this migration can reach them, which is precisely why they need writing down rather than assuming.

It has two halves, and they are different in character. The first half — the backend, integration-boundary, database and frontend sections — is the set established while the runtimes were moved and while this change set was reviewed. The second half is much larger: **137 test-quality defects, 8 security findings in test fixtures, a coverage-integrity gap and an integration-test surface that has never executed**, all raised by a dedicated review of the reactor's test sources. They are registered together because they share one disposition and one reason for it, but two of the classes need an owner rather than a reader — see [Credentials persisted in recoverable form](#credentials-persisted-in-recoverable-form-required-human-action) and [Test fixtures carrying credentials and personal data](#test-fixtures-carrying-credentials-and-personal-data-required-human-action).

| What is registered here | Count |
| --- | ---: |
| Backend defects | 10 |
| Integration-boundary and security defects | 18 |
| Database and schema-authority defects | **29** (`DS` 3, `DQ` 8, `DM` 12, `DD` 2, `DC` 4) |
| Frontend defects | 5, with four adjacent conditions recorded beside them |
| Frontend-to-API seam defects | 8 (accounting for 12 mismatched call definitions) |
| Browser-side and transport security defects | 5 (in 4 entries — the two HTML sinks share one) |
| Pre-existing test-quality defects | **137** (75 major, 62 minor) |
| Security findings in test fixtures and tests | **8** (1 critical, 5 major, 2 minor) |
| Coverage-integrity and discovery findings | 3 |
| Integration-test surface never executed | 86 classes / 211 annotations |
| Conditions fixed under the R-6 carve-out | 1 |

The counting unit is one **registered entry per identified defect** — a subsection in the backend, integration-boundary and database sections, a row in the frontend table, an `ID` in the two long registers. The numbers are reconcilable against the page rather than summary figures carried in from elsewhere: the database row is the only one with an ID scheme, and its five prefixes are counted separately so a reader can check each against its own subsection. Where a number here disagrees with a figure quoted in the review that produced these entries, [Honest corrections on the record](#honest-corrections-on-the-record) says which one this page measured and how.

## Why nothing here is fixed

**R-6** requires that a pre-existing bug discovered during this work be documented rather than repaired, with one carve-out: a bug that blocks a validation item may be fixed. Two items on this page sit on the fixed side of that line, and only one of them is there by R-6's own exception; both are in [The two conditions fixed under the carve-out](#the-two-conditions-fixed-under-the-carve-out), which says which is which. Everything else is left exactly as the base commit wrote it.

For the test-source findings there is a second, independent bar on top of R-6, and it is the stricter of the two: **AAP §0.2.4.2** lists *"Existing test assertions"* among the preservation mandates and states that *"modification of any of these is a defect, not a scope choice"*, while **AAP §0.2.1.3** and **§0.8.1** put it operationally — no test source file is modified at all. So even a test defect that *did* block a validation item could not be repaired by editing the test; it would have to be reached another way. That is exactly what happened for the one class of undiscovered tests this checkpoint did reach, by adding a precise runner include rather than renaming the class.

The reasoning is worth making legible, because the rule is not bureaucracy. A compatibility migration earns its review by being attributable: if the same change set moves a compiler contract, a dependency surface *and* an unrelated defect, then any behavioural difference observed afterwards has two candidate causes and the reviewer can no longer tell which one produced it. Keeping the repairs out is what makes the runtime move reviewable at all. The corollary is the discipline this page holds itself to — describing a defect here does not license fixing it.

A note on where the rules come from, because it is unusual and a reader should not go looking in the wrong place. **`review_rules` reports that no user rules were provided**, and there is no on-disk rules document for this project. The seven binding constraints this migration works under arrive instead through the **RULES block of the user prompt**, whose full verbatim text is available via **`review_prompt`**. They are cited across this documentation set as **R-1** through **R-7**. This page cites them by identifier and summarises what each requires of it; it does not reproduce their text, because the prompt is the source of truth for that.

| Rule | What it requires of this page |
| --- | --- |
| **R-6** — pre-existing bugs are documented, not fixed | Primary. This page *is* the register R-6 asks for, and R-6 is the only reason it exists — the migration's deliverable list does not name it. Every entry must state whether it blocks a validation item, and the one that does must say which; every entry must also carry its **location** and, where the repository cannot establish what the defect costs, a named **follow-up owner**. Coverage is every class of defect the work surfaced, database authority included: an ORM mapping, a changelog, a stored routine, a DAO query and a stored credential are each as much "source" for R-6 purposes as a `.java` file, and a defect in any of them is registered here rather than repaired, because the schema, the effective DDL and the security outcomes are all on the preservation list |
| **R-5** — failing tests must not be disabled | The four baseline test failures are pre-existing defects and belong here, but their exclusion accounting belongs to [the baseline record](baseline-test-failures.md). This page summarises and links; it publishes no suite totals. R-5 also forecloses the obvious shortcut for the 21 pre-existing `@Ignore`d classes registered below: they cannot be deleted to make the register shorter |
| **AAP §0.2.4.2 / §0.2.1.3 / §0.8.1** — existing test assertions are preserved | The binding constraint for the 137 test-quality findings and the 8 security findings. It is why they are registered rather than repaired, and it is stricter than R-6 because it admits no carve-out |
| **AAP §0.2.4.2** — the schema, the effective DDL of the persistence mappings and every Liquibase changelog are preserved; so are security and permission-evaluation outcomes | The binding constraint for all **29** database entries, and it is why several of them are registered even though their repair is small and obvious. A changelog edit, a mapping change, a cascade change or a stored-credential change is *"a defect, not a scope choice"* under that clause — and for the four credential entries the constraint bites twice, because hashing a stored token changes an authentication outcome by construction. It is also stricter than R-6, which is why no carve-out was available for any of the twenty-nine |
| **R-4** — the frontend must genuinely run on Node 20, with no vendored dead packages | The retained vendored `lib/` tree must be *justified*, not merely noted, because a careless reading of R-4 would treat it as exactly the thing R-4 forbids |
| **R-2** — no module-access flags or JDK-internal reliance in production launch configuration | Nothing in production launch configuration is changed here. The ActiveMQ finding below is a documentation item by direction, not a missing flag; the launch-configuration certification lives in [the module-access record](add-opens-exceptions.md) |

### How to read an entry

Every entry names **what** the defect is, **where** it is, and **why it does not block a validation item** — that last clause is the justification for leaving it alone, and an entry without it would not satisfy R-6. Entries in [Integration-boundary and security defects](#integration-boundary-and-security-defects-documented-not-fixed) additionally carry a **follow-up condition**: what would have to be true for the repair to be in scope, so that the analysis behind the decision is not lost with it. Entries in [Database and schema-authority defects](#database-and-schema-authority-defects-documented-not-fixed) carry a stable **ID** as well, because that section is an inventory of twenty-nine rather than a handful and its entries are cross-referenced from each other. The validation items referred to are the five the migration is measured against:

| # | Validation item |
| --- | --- |
| 1 | `mvn clean install -DskipTests` then `mvn test` exit 0 on JDK 17 |
| 2 | `npm ci --ignore-scripts` then `npm run build` exit 0 on Node 20 from a fresh checkout |
| 3 | The JDK-internal-API static audit returns zero hits in main source |
| 4 | The assembled artifact deploys and reaches a ready state |
| 5 | Smoke flows match the Java 8 baseline |

Line numbers are given for the **migrated tree** as published. Where the migration legitimately moved a line, the base-commit number is given alongside it in parentheses, so the citation is checkable against either tree.

Some entries carry a fourth clause, **what remains for others**. It appears wherever the repository can establish that a defect exists but cannot establish what it costs — because the evidence lives in a deployment profile, an external configuration bundle or a database privilege that is not in this checkout. That clause is a handoff, not a hedge: it names who must close the question and with what, so an entry is never left reading as an all-clear simply because this repository ran out of things to measure.

Two things this page does **not** claim, stated here rather than left to be inferred. It is not the output of a systematic audit of ArkCase: it is the union of what moving two runtimes surfaced and what the reviews of this change set established, so a defect class nobody looked at is absent from this page rather than absent from the product — the sections that name their own coverage limits are [What this record does not cover](#what-this-record-does-not-cover) and the closing note of the test register. And a "**No**" in the blocking column is a statement about the five validation items above, not a severity rating: several entries here would matter a great deal to a deployment that uses PostgreSQL, an extension profile, OAuth2 or e-mail links, and each of those says so in its own text. Reading the column as a triage order would get the priorities backwards.

## Backend defects — documented, not fixed

| Defect | Location | Blocks a validation item? |
| --- | --- | --- |
| Compressor closes a stream and then finishes it again | `DefaultFolderCompressor.java:215-219` with `MaxThroughputAwareFileOutputStream.java:123` | **No** — it is one of the two baseline exclusions, so item 1 is unaffected |
| Three unmet EasyMock expectations in one controller test | `FileDownloadAPIControllerTest` in `acm-services/acm-service-ecm` | **No** — same exclusion; item 1 is unaffected |
| The same servlet API declared twice in one module POM | `acm-services/acm-service-authentication-token/pom.xml:89-93` and `:109-112` | **No** — it is a Maven warning, the build succeeds, and nothing reaches the artifact |
| Posting credentials to `/login` returns HTTP 500; the working entry point is `/login_post` | the deployed application's security filter chain | **No** — item 5 uses the documented entry point, which returns 302 on both builds |
| The build injects licence headers into tracked sources | `pom.xml:531-559` — `license-maven-plugin` on `process-sources` | **No** — it mutates the working tree, not the build outcome |
| ActiveMQ's TLS transport does not work on Java 17 | No location — no broker URL exists in this repository | **No** — and the project setup instructions direct that it be documented, not fixed |
| Portal submissions reject any `java.time` value they carry | `PortalFOIARequest.recordSearchDateFrom` / `recordSearchDateTo`, `PortalSubjectAccessRequest.signatureDate`, `PortalPersonDTO.dateOfBirth` | **No** — the behaviour is the Java 8 base commit's own, and it is preserved deliberately |
| The raw portal payload travels in the failure messages of both `submitRequest` and `submitInquiry`, and reaches the caller as `error_message` | `FOIAPortalRequestServiceProvider:107-121` and `:297-299`, `SARPortalRequestServiceProvider:108-122` and `:299-308`, with `PortalRequestServiceExceptionMapper:73` — detailed in [the security section](#the-portal-request-and-inquiry-paths-log-and-return-their-raw-payloads) | **No** — no smoke flow submits a portal request or inquiry, and the reduced stack has no portal front end |
| Two git-sourced asset repositories carry lifecycle scripts that cannot run on Node 20 | `@bower_components/angular-xeditable` and one other git dependency's development tree | **No** — `--ignore-scripts` is the documented install flag, and nothing those scripts produce is consumed |

### The compressor closes a stream and then finishes it again

`FolderCompressorTest.testCompressFolderMaxSize` in `acm-services/acm-service-compress-folder` ends in a `NullPointerException` carrying the message `Deflater has been closed`. The defect is in production code, not in the test, and the register names that location because [the baseline record](baseline-test-failures.md) owns the stack trace rather than the source:

- `DefaultFolderCompressor.compressFolder` opens a `ZipOutputStream` over a `MaxThroughputAwareFileOutputStream` in a try-with-resources at `:215-219`.
- `MaxThroughputAwareFileOutputStream.write` throws an `IOException` at `:123` as soon as the configured size limit is exceeded — which is precisely what this test provokes.
- The per-entry `catch (IOException)` inside the private `compressFolder(zos, …)` overload at `:386-391` **swallows** that failure: it logs a warning and lets the loop continue. `copy` is `org.apache.commons.io.IOUtils.copy`, statically imported at `:32`, and closes nothing itself.
- The try-with-resources then closes the `ZipOutputStream` on the way out, and `close()` runs `finish()` over a deflater the failing path has already ended. The JDK raises the `NullPointerException` from there.

**Why it does not block a validation item.** It is one of the four measured baseline failures, and its owning class is one of the two class-level entries in the surefire `<excludes>` block at `pom.xml:406-418`, the two `<exclude>` elements themselves being `:416-417`, so validation item 1 exits 0 with it in place. The failure is **identical on JDK 8 and JDK 17**, differing only in library-internal line numbers, which is what qualifies it as pre-existing rather than migration-attributable. The exclusion accounting, the two narrower alternatives that were rejected on evidence, and the collateral cost of a class-level exclusion are all in [the baseline record](baseline-test-failures.md) and are deliberately not repeated here.

### Three unmet EasyMock expectations in one controller test

`FileDownloadAPIControllerTest` in `acm-services/acm-service-ecm` holds four tests, of which three fail: `downloadFileById_successful`, `downloadFileByIdAndVersion_successful` and `override_mime_type`. All three surface the **same way** — a `java.lang.AssertionError` from the test's own `EasyMockSupport.verifyAll` call, not from three different frames — but they do **not** share one cause, and an earlier revision of this page said they did. Re-measured on the migrated tree by running the class with `-Dtest`, which overrides the exclusion:

| Test | Unmet expectation | Actual cause |
| --- | --- | --- |
| `downloadFileByIdAndVersion_successful` (test line 264) | `ContentStream.getFileName(): expected: at least 1, actual: 0` | The expectation is simply **unused**. The controller never reads the content stream's filename on this path, so the test asks for a call production has no reason to make |
| `downloadFileById_successful` (test line 182) | `ApplicationEventPublisher.publishEvent(capture(...)): expected: 1, actual: 0` | The controller **throws before it can publish**. The same run logs `Last Chance Handler: Cannot invoke "String.endsWith(String)" because "fileName" is null` — the fixture leaves `EcmFile.fileName` unset, the download path dereferences it, and the event never happens |
| `override_mime_type` (test line 344) | `ApplicationEventPublisher.publishEvent(capture(...)): expected: 1, actual: 0` | The same unset-`fileName` NPE, on the MIME-override path |

The distinction matters for anyone repairing them: one is an expectation to delete, and two are a fixture to complete. Reading all three as "the controller does not publish an event" would send a repair at the wrong code — and would suggest a production defect in event publication where there is none.

**Why it does not block a validation item.** Same reason as the compressor: this is the other class-level exclusion, so validation item 1 exits 0. And there is a second, sharper reason it belongs on this page rather than in a regression report — the outcome is **identical under EasyMock 4.1 and 4.3**, failing at the same frame from the same three test methods on both JVMs. The migration moves `easymock.version` from 4.1 to 4.3, so if that bump had altered anything here these would have been migration regressions and R-5 would not have permitted excluding them. It did not, and they are not.

### The same servlet API declared twice in one module POM

`acm-services/acm-service-authentication-token/pom.xml` declares `javax.servlet:javax.servlet-api` twice — once at `:89-93` with `<scope>test</scope>`, and again at `:109-112` with no scope at all. The file is byte-identical to the base commit; the migration neither caused this nor touched it.

**This is a Maven warning, not an error**, and this register **corrects an earlier assessment that called it build-blocking**. That correction is part of the value of writing the defects down: the earlier reading would have justified an out-of-scope POM edit that nothing actually required. Running the module's own build settles it — `mvn -o -B -pl acm-services/acm-service-authentication-token validate` exits **0** with **BUILD SUCCESS**, having emitted:

```text
[WARNING] 'dependencies.dependency.(groupId:artifactId:type:classifier)' must be unique:
javax.servlet:javax.servlet-api:jar -> duplicate declaration of version (?) @ line 109, column 21
[WARNING] It is highly recommended to fix these problems because they threaten the stability of your build.
[WARNING] For this reason, future Maven versions might no longer support building such malformed projects.
```

Maven names line 109 — the second declaration — which is the citation above confirmed by the tool itself. The effective model is worth recording too, because it shows what the duplicate actually costs: `help:effective-pom` carries the dependency **twice**, and both copies resolve to `<scope>provided</scope>` from the managed entry at `pom.xml:1545-1550`. The narrower `test` scope written at `:92` is therefore silently discarded, and a `provided` dependency is never packaged, so no artifact content changes either way.

**Why it does not block a validation item.** The build succeeds, the artifact is unaffected, and no test or audit touches it. Under R-6 it stays documented. Maven's own caution in that third warning line is nevertheless a real forward risk rather than boilerplate — a future Maven may refuse to build such a model — and the right time to act on it is a POM-hygiene change with its own review, not a runtime migration.

### The build injects licence headers into tracked sources

`org.codehaus.mojo:license-maven-plugin:1.16` is declared at `pom.xml:531-559`, with its includes set to `**/*.java` and `**/*.jsp` at `:538-541` and its `update-file-header` goal bound to the `process-sources` phase at `:543-551`. Any matching file that lacks the ArkCase header therefore gains one during **every** build, stamped with the current year.

The behaviour is bounded, and it was measured rather than estimated. **Six of the 3,054 main Java sources at the base commit lack the header**, the same six in the migrated tree:

| Module | File |
| --- | --- |
| `acm-services/acm-service-portal-gateway` | `model/PortalUserConfig.java` |
| `acm-services/acm-service-portal-gateway` | `service/PortalUserConfigurationService.java` |
| `acm-services/acm-service-portal-gateway` | `service/PortalUserConfigurationServiceImpl.java` |
| `acm-services/acm-service-portal-gateway` | `web/api/ArkCasePortalUserAPIController.java` |
| `acm-standard-applications/acm-foia` | `gov/foia/service/dataupdate/CreateAnonymousPersonExecutor.java` |
| `acm-tool-integrations/acm-camel-context-manager` | `com/armedia/acm/camelcontext/utils/FileCamelUtils.java` |

Running `mvn -o -pl acm-services/acm-service-portal-gateway process-sources` and reading the diff gives the exact shape: **4 files changed, 108 insertions, 0 deletions** — four files at **27 lines each**. The zero on the deletions side is the important half, because it proves the plugin *adds* a missing header rather than restamping the roughly three thousand files that already carry one. The injected block reads `Copyright (C) 2014 - 2026 ArkCase LLC` against the `2014 - 2018` of the existing headers, which is the current-year stamp made visible.

!!! warning "A post-build working tree contains edits the migration did not make"

    Three consequences follow, and the third is the one that catches reviewers.

    1. **It is documented, not fixed.** Nothing about the plugin, its phase binding or its includes is changed by this migration.
    2. **It is a concrete reason the never-`git add -A` instruction must be obeyed.** A blanket stage sweeps these header injections — and the generated build outputs noted further down — into whatever commit happens to be open, which is exactly how an unrelated change enters a migration diff. Stage by explicit path. This page is itself the reason that instruction is not merely cautious.
    3. **Reviewers must expect these edits and must not read them as migration changes.** Six `.java` files gaining 27 lines of licence header after a build is the plugin working as configured, not the runtime move touching source.

**Why it does not block a validation item.** The plugin mutates the working tree, never the build outcome: every validation item still exits 0 with the injections happening. It is a repository-hygiene hazard, not a build failure.

### An in-place frontend install is packaged into the WAR

The frontend project root is `acm-standard-applications/arkcase/src/main/webapp/resources`, which sits **inside** the webapp directory `maven-war-plugin` copies wholesale. So whatever a developer or a CI job leaves in that directory is shipped in the artifact, and a frontend install leaves a large directory there.

Measured on this tree, both from the same sources and from the **same build**, which is why the clean figure below is a few hundred bytes from the one quoted elsewhere on this page — the digits move between builds of identical source, and only a same-build pair makes the comparison exact:

| Packaged from | WAR size | Entries | `resources/node_modules/**` |
| --- | --- | --- | --- |
| A tree with no in-place install | **275,722,947 B** | 2,580 | none |
| The same tree after `npm ci --ignore-scripts` and `npm run build` in the frontend root | **333,033,441 B** | 22,005 | **19,412 entries, 48,289,658 compressed bytes** (plus the 11 built bundles under `assets/dist/`, a further 4,874,946 compressed bytes) |

Both figures are measurements of the same committed source and they move with the installed vendor tree: an earlier capture of the same two states, taken before the `multi-download` asset was restored, measured 332,662,877 B across 21,994 entries. The structural point is what matters and it is stable across both. Git never notices, and that is what makes it easy to miss: `node_modules` is ignored at the base commit, so `git status` stays clean while the packaged artifact grows by roughly **57 MB** — 46 MB of it `node_modules` alone. `.gitignore` is not an input to the war plugin.

**Why it is not this migration's defect.** The layout, the ignore rule and the war plugin's default webapp directory are all unchanged from the base commit, and the same inflation occurred under yarn — only the directory's contents differ. Deployment does not depend on an in-place install either: the deploy-time driver runs the install in a **temp folder** and copies selected outputs, which is why the packaged `node_modules` is inert rather than load-bearing.

**Why it does not block a validation item.** Every gate exits 0 either way; the WAR is produced at the same path with the same name in both cases. It is an artifact-hygiene hazard, not a build failure — but it does mean a WAR byte count is only comparable to another one taken the same way, which is why [the smoke record](smoke-evidence.md) states which kind of tree each of its figures came from.

**Follow-up condition.** If in-place frontend builds ever become part of the release flow, add a `<packagingExcludes>` entry for `resources/node_modules/**` to the war plugin configuration in the root `pom.xml`. That is a build-configuration change with no compatibility reason behind it, so **R-1** puts it outside this migration; it belongs to whoever owns the release pipeline.

### Posting credentials to `/login` returns HTTP 500

The login **page** is served by `GET /arkcase/login`, which returns 200. **Posting** a form to that same path returns **HTTP 500**, and the server log records `HttpRequestMethodNotSupportedException: Request method 'POST' not supported` from the application's last-chance MVC error handler — the request reaches the dispatcher servlet rather than the authentication filter, and no controller on that path accepts POST. The working entry point is **`POST /arkcase/login_post`**, which is where the login form itself posts (`<form action="/arkcase/login_post" method="post">` in the rendered page) and which returns **302** to `home.html#!/welcome` on success.

Measured on both builds, with the same commands and the same account, and with no credential reproduced here:

| Request | Java 8 baseline (base commit) | Migrated build on JDK 17 |
| --- | --- | --- |
| `POST $BASE/login` | **500** | **500** |
| `POST $BASE/login_post` | **302** to `home.html#!/welcome` | **302** to `home.html#!/welcome` |

Two properties make this a documented issue rather than a migration defect. It is **identical on both sides**, so it is pre-existing and the migration neither caused nor worsened it. And it is **not fixable in this repository**: the `login_post` processing URL is declared in the external configuration bundle's Spring Security configuration, not in any tracked file here, so the mapping that would have to change lives outside this checkout — the same situation as the broker URL below.

The operational consequence is the only thing a reader needs: **authenticate against `/arkcase/login_post`**, not `/arkcase/login`. The project setup instructions say the same, and [the smoke evidence](smoke-evidence.md#the-smoke-flow-inventory) records both requests as executed flows with their results.

**Why it does not block a validation item.** Item 5 exercises the documented entry point and gets 302 on both builds; the 500 is only reachable by posting to the page URL, which nothing in the application does.

### Portal submissions reject any `java.time` value they carry

A FOIA or SAR portal submission that sends a value for `recordSearchDateFrom`, `recordSearchDateTo`, `signatureDate` or a person's `dateOfBirth` is **rejected** — the request fails deserialisation and the caller receives a `PortalRequestServiceException` with the deserialise error code. A submission that omits those properties, or sends them as `null`, is accepted with the field left `null`.

This is **not** a migration regression. It is the observed behaviour of the Java 8 base commit, measured on JDK 1.8.0_502 with Jackson 2.10.3 against the real model classes: the providers deserialise with a bare `ObjectMapper`, no java.time module is registered anywhere on that path, and `java.time.LocalDate` and `LocalDateTime` have no creator Jackson can use, so a present value raises `InvalidDefinitionException: Cannot construct instance of java.time.LocalDate (no Creators, like default construct, exist)`. The models carry no `@JsonFormat` or `@JsonDeserialize` annotation that would change that.

**Why it is documented rather than fixed.** The fix is a single line — register a `JavaTimeModule` on those two mappers — and it is exactly what R-7 forbids: it would start accepting ISO-8601 date strings that the base commit rejected, widening the published request contract, which the REST-contract preservation mandate also forbids. What the migration *did* have to fix is a different defect on the same path, where Java 17 broke even the payloads that used to work; that repair reproduces this rejection deliberately rather than removing it, and it is recorded as [decision 27](behavioral-decisions.md#27-the-portal-javatime-mapper-is-kept-because-the-failure-it-was-built-for-reproduces-on-the-sar-path).

**What a maintainer should know.** If the portal is meant to submit those dates, this is a genuine functional gap and it predates Java 17 by years. Closing it is an API decision — pick and publish a date representation — not a migration task, and it needs the portal side changed with it.

### The raw portal payload travels in every deserialisation failure message, in both providers and both methods

Four failure paths log and propagate the **entire raw request body**, and they are byte-identical to the base commit:

| Where | What it emits |
| --- | --- |
| `FOIAPortalRequestServiceProvider.java:107-113` and `SARPortalRequestServiceProvider.java:108-114` — `submitRequest` deserialisation failure | `log.warn("Error deserializing raw request [{}] …", rawRequestContent, …)` and the same content inside the `PortalRequestServiceException` message |
| `FOIAPortalRequestServiceProvider.java:115-121` and `SARPortalRequestServiceProvider.java:116-122` — `submitRequest` creation failure | The same raw content again, in both the log line and the propagated message |
| `FOIAPortalRequestServiceProvider.java:297-299` and `SARPortalRequestServiceProvider.java:299-301` — `submitInquiry` deserialisation failure | The same raw content, plus a **placeholder-count defect**: the log line declares three `{}` placeholders and passes one argument, and the `String.format` declares three `%s` and passes one, so the emitted text is malformed and the user and portal identifiers — the two fields an operator actually needs — are missing |

Portal content carries names, addresses, dates of birth and file payloads, so this is **CWE-532** in the log and **CWE-209** in the propagated message. The propagation is not theoretical: `PortalRequestServiceExceptionMapper.mapException` copies the exception's message into the `error_message` field of the REST response, so the payload reaches an external portal client.

**Why it is documented rather than fixed, and a correction to an earlier revision of this register.** An intermediate revision of this change set redacted the two `submitRequest` paths, and this register then described the request endpoint as repaired and only the inquiry endpoint as outstanding. That redaction has been **withdrawn**, and the register is corrected accordingly: every one of the four log lines and the four exception messages is byte-identical to the base commit, so all four paths emit exactly what they emitted on Java 8. The reasons are cumulative rather than a single rule — the redaction changed a field an external client receives, which is an observable REST contract change; it cleared no validation blocker; and R-7 makes the base-commit text the text. The migration does touch these two files, but only to add the `java.time` mapper the SAR path needs on JDK 17 (recorded as [decision 27](behavioral-decisions.md#27-the-portal-javatime-mapper-is-kept-because-the-failure-it-was-built-for-reproduces-on-the-sar-path)) — that repair sits above these catch blocks and changes nothing they emit. The full reasoning is [decision 28](behavioral-decisions.md#28-the-raw-portal-payload-keeps-travelling-in-the-failure-message-and-the-defect-is-registered-instead).

**What a maintainer should know.** The repair is small and should ship as its own authorised security change, not inside a compatibility migration: keep the portal and user identifiers, drop the payload from both the log and the propagated message, fix the placeholder counts in the two `submitInquiry` paths while there, and publish a contract note because `error_message` changes shape for portal clients. It needs a regression test per path — four of them — asserting that the response and the log carry the identifiers and not the body.

### A `String.format` placeholder reaches a `{}`-style logger

`MimeMessageParser.java:160` logs `log.debug("Email body could not be read automatically (%s), we try to read it anyway.", e.toString())` — a `String.format` placeholder passed to a log4j2 logger, which substitutes `{}` and leaves `%s` alone. The exception text is therefore never interpolated: the emitted line reads `Email body could not be read automatically (%s), we try to read it anyway.`, and the detail that would have identified why the body could not be decoded is silently dropped. The call sits in the `catch (Exception e)` fallback of `getStringContent`, where the parser retries with the undecoded stream — the base commit's own comment on the next line reads `// most likely the specified charset could not be found` — so the detail that goes missing is precisely the one needed to tell a charset problem from anything else the broad catch swallows.

**A correction to an earlier revision of this entry**, recorded rather than quietly overwritten because a fabricated quotation is worse than no quotation: this entry previously attributed the defect to `MimeMessageParser.java:143` and quoted `log.error("Failed to parse MimeMessage: %s", e.getMessage())`. That string occurs nowhere in the repository, at the base commit or now, and the line, the level and the argument were all wrong — base `:143` is a bare `{` and the current `:143` is a Javadoc `@return` tag. The text above is the real call, verified by `grep -n 'could not be read automatically'`.

**Why it is documented rather than fixed.** Byte-identical at the base commit — the base carried it at `:144`, and the line moved only because this migration inserted code above it — and it blocks no validation item: the parse behaviour is unaffected and the module's tests pass, 8 of 8. This migration edits this file, but only its two mapped lines plus the restored encoding check they made necessary; correcting the log call would be an opportunistic behaviour change in an edit whose whole justification is minimality. The repair is one character, once a plan authorises it. Note it is `log.debug`, not `log.error`, so nothing is lost at default log levels in the first place.

### Javadoc defects in three files this migration touches

Three unrelated documentation defects sit in files this change set edits or reads, and they are registered so a reviewer does not mistake them for something the migration introduced:

- `PdfServiceImpl.java:88` embeds an unescaped `<email>` in a class Javadoc — `Created by Petar Ilin <petar.ilin@armedia.com>` — which a doclet would read as an unknown HTML tag. The same convention appears in **414** files across the reactor (**398** under `src/main/java`, **16** under `src/test/java`), so it is a codebase-wide habit rather than a local slip, and the count is **identical at the base commit**, so nothing here is the migration's doing. The command, published so the figure is checkable rather than asserted:

    ```bash
    grep -rlE '^[[:space:]]*(\*|//).*<[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+>' --include=*.java . \
      | grep -v '/target/' | wc -l
    ```

    An earlier revision of this entry published **327**, with no command behind it. That figure is **not reproducible** by any criterion tried: restricting the pattern to `@author` lines gives 91, and the 398 above is the `src/main/java` subset, which is probably where a partial count came from. 327 is withdrawn.
- `NiemExportService.java:77` documents an `@return` on a method whose declared return type is `void`. The file is not touched by this migration at all; it is the interface of one that is.
- `ActiveDirectoryAbstractContextSource.java` carries a trailing space inside the `setReferral` Javadoc — a block this migration does not edit, and which carries the same trailing space at the base commit.

**Why they are documented rather than fixed.** No POM among the 145 declares `maven-javadoc-plugin`, so nothing in the build parses these comments and none of the three blocks a validation item. Two of them are outside the files this change set is mapped to edit, and the third is inside a block it deliberately leaves alone. Verified on the two files this migration *does* rewrite documentation in: `javadoc -Xdoclint:all,-missing` over `ActiveDirectoryAbstractContextSource` and `LdapProviderProperties` exits 0 with no output, so the edited comments introduce nothing of this kind.

### Two git-sourced asset repositories cannot run their lifecycle scripts on Node 20

`npm ci` without `--ignore-scripts` fails on Node 20, and two independent scripts are why:

- A git dependency's lifecycle script installs its own development tree, which reaches the jsdom-generation native module `contextify`. Its `node-gyp` build fails against Node 20's V8 headers — `../src/contextify.cc:52:52: error: no matching function for call to 'v8::FunctionTemplate::GetFunction()'`, then `gyp ERR! build error` and `make failed with exit code: 2`.
- `@bower_components/angular-xeditable` declares a legacy `prepublish: bower update`. Packing it directly — `npm pack "vitalets/angular-xeditable#semver:0.9.0"` — exits 1 at that script.

**Why it is documented rather than fixed.** Both scripts belong to third-party repositories, and neither produces anything the Grunt pipeline consumes: these are prebuilt asset repositories with checked-in distribution directories. Replacing either package to silence its script would be a version change with no compatibility reason for the *asset* itself, which R-1 forbids. `--ignore-scripts` is therefore the documented install flag in both the developer command and the deploy-time command, and the measurement behind it is in [the smoke evidence](smoke-evidence.md).

### ActiveMQ's TLS transport does not work on Java 17

The broker must be addressed over `tcp://` rather than `ssl://`, because ActiveMQ's TLS transport at the pinned version does not work on Java 17. The project setup instructions are explicit about the disposition: **document it, do not fix it, and do not fail setup for it.** That last clause is stated plainly here because it is the one most likely to be second-guessed by someone who finds the finding without the direction attached to it.

There is also nothing in this repository to change. Searching every tracked file for a broker URL — `git grep -nE '(ssl|tcp)://'` outside the documentation tree — returns **zero hits**. Endpoints reach ArkCase from the external configuration bundle, so the remedy is a configuration choice made outside this checkout and the finding cannot be a repository edit even in principle.

**`tcp://` is not a licence to run an unprotected broker.** Plaintext transport carries JMS credentials and message payloads — case, document and user data — in clear text, so a deployment that adopts this workaround must compensate elsewhere, and all four of the following are required rather than advisory:

1. **Trusted network only.** Bind the broker to a private or loopback interface, keep it off any routable or shared segment, and restrict the openwire port and the console port to the application hosts with host and network firewall rules or security groups.
2. **Authentication and authorization stay on.** Plaintext transport does not imply an open broker: keep the broker's authentication plugin enabled with per-application credentials and keep destination-level authorization, so network position alone grants nothing.
3. **Encrypt at another layer whenever the traffic leaves one host.** A TLS-terminating proxy, an SSH tunnel, a VPN or a service-mesh mTLS sidecar all move the ciphertext boundary off the JVM that cannot negotiate it, and none of them needs the broker's own TLS transport.
4. **Treat it as a time-limited accepted risk.** Record it with an owner and revisit it when a broker version whose TLS transport works on the target runtime can be adopted; the version pin is what forces the workaround, so lifting the pin is what retires it.

In the validation environment all four hold trivially — a single-host sandbox with the broker on the loopback interface — and that is the only reason the workaround was acceptable there.

**Why it does not block a validation item.** Messaging over `tcp://` works: [the smoke evidence](smoke-evidence.md#the-integration-surface) records an authenticated STOMP session against the broker with live inbound message frames, so nothing in items 1 through 5 depends on the TLS transport. Two clarifications matter under R-2: this is **not** a module-access problem, so no `--add-opens` would help and none is offered; and what the repository does and does not grant is certified in [the module-access record](add-opens-exceptions.md), a certification this finding does not disturb.

## Integration-boundary and security defects — documented, not fixed

Every defect in this section is **base-commit code that this migration does not touch**: each one was read on the migrated tree and again with `git show c8f6226105:<path>`, and the cited logic is identical in both. They are gathered here because a register that omits the highest-impact defects gives false comfort — the point of R-6 is a complete list, not a short one.

None of them blocks a validation item, and the reason is the same in every case, so it is stated once rather than repeated: **validation items 1 to 3 are a compile, a test run and a text search, none of which reaches these code paths, and items 4 and 5 are evaluated against a reduced local stack with no Alfresco, no Solr and no Pentaho** (see [the smoke record](smoke-evidence.md)). Where an item *does* interact with something that was executed, the entry says so explicitly.

### What this section publishes, and what it does not

Eleven of these findings are unremediated security-relevant defects in a deployed application, and this page is published documentation. **Their mechanics are therefore withheld here**: no method, no line number, no data-flow narration, no proof-of-concept payload and no repair recipe that reads as an exploit recipe. Publishing those would hand a reader who has not looked a map to a live weakness, and the defects are unfixed precisely because R-6 and the preservation mandate forbid fixing them inside a runtime migration.

What is published is the metadata a reader of this page legitimately needs: what class of defect it is, which integration boundary it sits on, how severe it is, whether it blocks a validation item, and who has to close it. **The itemised mechanics — file, line, call path, reproduction and the shape of each repair — are in the restricted security record raised for this work; request it from the repository owner or the security owner.** That record exists and is complete; nothing has been lost by not repeating it here.

| ID | Integration boundary | Class of defect | Severity | Blocks an item? | What closing it needs |
| --- | --- | --- | --- | --- | --- |
| I-01 | ActiveMQ, inbound | Acknowledgement precedes durable processing, so a failure after delivery loses the work silently; redelivery and dead-lettering cannot help | **High** | No | An approved change to acknowledgement semantics — wire-visible behaviour — plus a per-flow integration test against a real broker |
| I-02 | ActiveMQ, outbound | Delivery failures are caught and logged, so upstream work commits while its notification never leaves the process | **High** | No | A per-caller decision between a typed failure and a committed outbox with observable retry |
| I-03 | Solr | Retryable and permanent failures are treated alike and dead-lettered without retry, and an indexed event can be published for a document the index never accepted | **High** | No | A live Solr in the validation stack, and an approved change to retry, dead-letter and event-emission behaviour |
| I-04 | Configuration server | A mandatory dependency fails open — a failed fetch becomes a null in the result set, and there is no connect deadline | **High** | No | Finite deadlines, bounded retry, rejection of empty responses, and a startup-fatal error naming the endpoint. Changes startup behaviour |
| I-05 | Configuration server | **CWE-22.** A broker-supplied value reaches both a URL segment and a local file path without separator or dot-segment validation, giving a write primitive reachable from a message | **Critical** | No | The most escalation-worthy item here. Self-contained repair, but it changes an input contract, so it needs its own review with a test per rejected form |
| I-06 | Alfresco / CMIS | The configured timeout never reaches the HTTP layer, leaving connect and read unbounded | **Medium** | No | A live Alfresco, plus validated connect and read values mapped into every session while the existing queue wait is retained |
| I-07 | Alfresco RMA | One call builds its own HTTP client and so carries neither the inherited authentication nor any timeout policy | **Medium** | No | A Kerberos-enabled Alfresco in the validation stack, since the repair changes the credentials on the wire |
| I-08 | Alfresco LDAP sync | The failure callback reads a security context that was never propagated to its thread, so the sync failure it exists to report is replaced by a null dereference | **Medium** | No | A one-line repair on an error path no test covers; belongs with I-09, which touches the same class |
| I-09 | All outbound HTTP | Clients are constructed per class with default (infinite) deadlines, no bounded retry, no circuit breaker and no lifecycle close | **High** | No | A resilience programme rather than a defect fix: lifecycle-owned clients, finite deadlines, bounded jittered retry, bulkheads, closed resources, with load evidence |
| I-10 | OnlyOffice | **SSRF and replay.** The callback's signature is available and unused — the switch that would verify it is present and does nothing — and the callback-supplied URL is fetched and stored as a document version without origin allowlisting or a deadline | **Critical** | No | Alongside I-05, the highest-severity item here. Verify before trusting, bind the claims, reject replays, allowlist the origin, bound the fetch. Changes a request contract |
| I-11 | Pentaho | Report XML already decoded as UTF-8 is round-tripped through the platform default charset | **Low** | No | Use the decoded string. Trivial, but a behaviour change on non-UTF-8 hosts, and latent on this environment because its default is already UTF-8 |

### ActiveMQ: acknowledgement happens before durable processing

I-01 above, kept as its own heading because [the smoke record](smoke-evidence.md) cites it from the message-transit evidence. One fact from that run belongs here rather than in the restricted record, because it is a measurement this migration made rather than a mechanic: the executed transit printed the listener session's acknowledgement mode as `1`, which is `AUTO_ACKNOWLEDGE` — so the later explicit acknowledgement in the processing task is inert, and the ordering defect is confirmed on a running broker rather than inferred from reading. The executed transit shows the happy path working; it says nothing about the failure path, and this entry is about the failure path.

### The defects in files this migration edits

The seven below are separated from the table because each sits in a file this change set touches, which means a reviewer will see the two together and needs to know which lines are which. In every case the defect is base-commit code and the migration's edit is elsewhere in the same file.

#### XML transformation: the external-access hardening is a no-op on this classpath

`NiemExportServiceImpl.java` and `PdfServiceImpl.java` each set the three JAXP external-access restrictions inside a `try` whose `catch (IllegalArgumentException)` body was empty, so a `TransformerFactory` that rejects them leaves the transformer unrestricted and processing continues.

**Measured on this classpath, and it is worse than "fails open on some providers".** A probe run under JDK 17.0.20 with the modules' real dependency sets shows:

| Provider | Restrictions actually applied |
| --- | --- |
| JDK built-in (`com.sun.org.apache.xalan.internal.xsltc.trax`) | **1 of 3** — the DTD restriction is accepted; the schema restriction throws and the shared `try` abandons the remaining call |
| Xalan 2.7.2 (`org.apache.xalan.processor`) | **0 of 3** — it rejects all three with `Not supported: http://javax.xml.XMLConstants/property/access*` |

Xalan 2.7.2 **is** on both modules' compile and runtime classpath and **does** ship in the assembled artifact as `WEB-INF/lib/xalan-2.7.2.jar`, so it is the provider `TransformerFactory.newInstance()` selects at run time and **none of the three restrictions takes effect in a deployed instance**. Because all three calls share one `try`, the first rejection also skips the rest.

**Impact.** External DTD, schema and stylesheet resolution stay enabled on the deployed provider — the XXE and SSRF exposure the three calls were written to remove — and the failure to harden is silent.

**Note for reviewers.** This migration touches both files, and touches them as narrowly as the specification maps: **one comment block each**, reworded to clear the JDK-internal-API audit by describing the JDK-internal transformer factory without naming it, recorded in [the static audit](static-audit.md). Nothing else in either file differs from the base commit.

An interim revision also replaced the `// TODO: handle exception` marker in each empty catch with prose stating exactly what is and is not restricted. That replacement was **reverted**: the specification authorises one comment change per file, the marker is pre-existing deferred work, and erasing it is the kind of silent knowledge loss this register exists to prevent. Both markers are therefore back verbatim — `PdfServiceImpl.java:156` and `NiemExportServiceImpl.java:254` — and the empty catch they sit in is registered as the pre-existing defect it is. The catch stays empty deliberately: failing closed is a behaviour change R-6 does not license.

**Follow-up condition.** Fail closed, or instantiate a provider proven to support the restrictions, and log the provider and the root cause. Either changes behaviour on any runtime where the attributes are unsupported — which, as measured above, is the runtime this application actually ships.

#### FOIA correspondence: an empty e-mail address passes the guard, and template failures are swallowed

`FOIAQueueCorrespondenceService.java` guards a send with a condition that is a tautology — a reference comparison OR'd with a null check — so an **empty** address proceeds and a send is attempted with no recipient. Inside, a template failure is caught and replaced with a fallback body.

**Note for reviewers.** This migration changes **one** predicate in this file, in a different method, because removing the FastInfoset dependency required it; that line is semantically exact and is *not* this defect. It also corrected the comment on the fallback, which previously said failing to send an e-mail must not break the flow when what the code actually does is substitute a body when the *template* fails.

**Follow-up condition.** A non-blank check plus observable failure handling — an approved behavioural change, since it turns a silent path into a reported one.

#### The event multicaster is production-dormant

The **only** `DistributiveEventMulticaster` bean, and the executor it depends on, are inside an XML comment in `spring-library-acm-web.xml`.

**Impact.** None at runtime — and that is the point. This migration adds the two `Predicate`-based methods Spring 5.3.5 introduced to `ApplicationEventMulticaster`, without which `acm-web` does not compile; the class they were added to is not wired into a deployed context, so **no asynchronous event routing is active in production** and the migration neither enables nor changes that. Anyone reading the new methods as a live behavioural change is misreading them.

**Follow-up condition.** If asynchronous listener routing is wanted, the bean has to be enabled and integration-tested with exception and ordering baselines captured first. That is a feature decision, not a migration one.

#### Deploy-time front-end driver: no command deadline, and unchecked deletions

`AngularResourceCopier.java` runs the install, the config merge and Grunt through a bare executor with **no watchdog**, so a hung child process blocks webapp startup indefinitely; and two prune loops discard the boolean result of each deletion, so a failed delete leaves a stale asset behind silently. Both are base-commit code.

**Impact.** A deployment that hangs with no diagnostic, or one that appears to succeed while serving a stale asset. The migration changes the *command* this driver runs — `npm ci --ignore-scripts` instead of the yarn invocation — and the lockfile name in the prune whitelist; it changes neither the timeout behaviour nor the deletion handling.

**Follow-up condition.** Configurable watchdogs that kill only the child on expiry, plus checked deletion that fails the deployment naming the path and cause. Both change startup failure modes, so they need a plan and a deployment test.

#### Multi-profile front-end deployments omit extension and custom assets

This is the register's entry for the `config/config.js` profile-iteration defect, stated in impact terms because the [frontend defects](#frontend-defects-documented-not-fixed) table states it mechanically.

The loader iterates the profiles *wrapper object* rather than its array, so the bound value is the array itself; with two profiles the derived prefix stringifies to a comma-joined value and every glob built from it matches nothing. Independently, four non-mutating array concatenations have their results discarded, so even a correctly-derived custom file list would not reach the bundle.

**Impact — corrected, because an earlier revision of this page understated it.** This is **not** merely latent. The deploy-time driver genuinely emits more than one profile: it writes the active Spring profiles and then appends `custom`, so a deployment running the `extension-foia` or `extension-privacy` profile — both of which exist in this repository — **loses both the extension assets and the customer assets** from `application.js`, `application.min.js` and `home.html`. The single-profile fresh-checkout case that the frontend evidence exercises is the *only* case in which the defect is invisible, which is exactly why it survived.

**Follow-up condition.** Iterate the array and assign the concatenation results — then rebuild and diff the emitted bundles for a two-profile deployment against a baseline capture, because the fix by construction **adds** files to the bundle, which is a behavioural change the preservation mandate forbids without a plan. It also needs a multi-profile deployment to validate against; the fresh-checkout evidence in [the smoke record](smoke-evidence.md) cannot cover it.

#### CI: feature pipelines collect no WAR

The `.build_artifact` template in `.gitlab-ci.yml`, which the feature-branch job extends, declares an artifact path of `target/*.war`. The reactor root is `pom` packaging and the WAR is written under the packaging module's own `target/`, so the glob matches nothing and a feature pipeline publishes no artifact.

**Impact.** Feature branches produce no downloadable WAR. Nothing else is affected: the snapshot job that actually ships uses the correct nested path, and so do all three release jobs.

**Why it is not fixed here, stated precisely.** The glob is **byte-identical at the base commit**, so R-6 governs it, and it blocks no validation item: the migration's build gate is `mvn clean install`, which writes the WAR at its unchanged path regardless of what CI archives. This migration does edit this file — the runner image pin and the removal of a JVM flag JDK 17 rejects — and repairing an unrelated line in the same edit is the specific thing that made unplanned repairs a finding of their own. It is a one-line change once a plan authorises it.

### Two integration-test profiles used to hardcode the Failsafe version, and no longer do

| Where | What |
| --- | --- |
| `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` | Both declared `maven-failsafe-plugin` with a **hardcoded `2.17`** inside a `coreBuild` profile rather than consuming the root POM's value. Where that profile is active a literal wins over anything the root declares, so the two could silently drift apart from it |

**This one is closed rather than registered, and the entry stays so the history is legible.** Three earlier revisions of this record described it — first as a version *split* against a root POM moved to 3.5.3, then as a latent hazard with the versions agreeing again after the root was reverted to 2.17, then as held at 2.17 through a `failsafe.version` property. None of those descriptions holds now. The `failsafe.version` property is **deleted**, and all three declarations — the root plugin and both `coreBuild` profiles — consume `${surefire.version}` (**3.5.3**), which is the single pin the specification mandates for both forked runners. No module can hardcode a diverging version, and none does: `grep -rn "<version>2.17</version>" --include=pom.xml .` matches nothing, `help:effective-pom` reports failsafe **3.5.3** at the root under `-N`, and under `-DcoreBuild=true` it reports **3.5.3** in both of those modules' plugin blocks. The version decision and the probes behind it are in [the dependency inventory](dependency-change-inventory.md).

**Why the repair was in scope at all**, given the specification maps the root `pom.xml` as the only POM this migration edits: the security review raised the divergence as a MAJOR finding, because a module-local runner that cannot compose `@{argLine}` would discard the JDK 17 module-access directives exactly where integration tests run. Only the `<version>` element changed in either profile — the `<executions>`, `<goals>` and `<skipTests>true</skipTests>` they carry are untouched, so *which* integration tests run under `-DcoreBuild=true` is exactly what the base commit specified. Both profiles activate only on `-DcoreBuild=true` and both set `skipTests=true` inside it, so this migration's validation path is unaffected either way. The version decision itself, and the probe behind holding 2.17, belong to [the dependency inventory](dependency-change-inventory.md).

### Bearer tickets and personal data travel in URLs and logs

| Where | What |
| --- | --- |
| `resources/services/config/snowbound-viewer.client.service.js:67-87` | `buildSnowboundUrl` builds one query string containing `acm_ticket`, `userid`, `userFullName`, `caseNumber`, `documentName` and the object identifiers, then hands it to `Util.encryptString(parameters, encryptionPassphrase)` where the passphrase is whatever `ecm.viewer.snowbound.encryptionKey` holds |
| `resources/services/common/util.client.service.js:795-805` | `encryptString` encrypts **only if a passphrase is truthy**; with an empty or absent key it returns the string **unchanged**, and the AES failure path does the same after a `$log.warn`. So an unset key silently downgrades the whole parameter block — ticket included — to plaintext in the viewer URL. The authoritative configuration in use leaves that key empty |
| FOIA `…/foia_modules/request-info/services/attachments.client.service.js:47` and privacy `…/privacy_modules/request-info/services/attachments.client.service.js:47` | Build the same viewer URL with `acm_ticket` in the query string and **no encryption step at all**. The privacy copy additionally interpolates `file.fileName` without `encodeURIComponent`, where the FOIA copy encodes it |
| `resources/modules/frevvo/services/frevvo-form.client.service.js:29-67` | Substitutes `acm_ticket` into a configured URL template at `:45` and appends caller-supplied state into the `_data` expression at `:55-56` without escaping it |
| `acm-services/acm-service-login/.../AcmBasicAndTokenAuthenticationFilter.java:144-149` and `:181-197` | The filter reads `acm_ticket` from the query string and **prints the token value** — at TRACE on both the attempt and the success path, and at WARN on the `acm_wopi_ticket` failure path, where a WARN is on by default in most configurations |

**Impact.** A bearer credential in a URL is a credential in browser history, in the `Referer` header of anything the viewer loads, in proxy and access logs, and in any error report that quotes the URL — and with the encryption key unset it is not even obscured. The log lines put the same token in the application log, where it is readable by anyone with log access and by any log shipper. The unescaped `_data` interpolation is an expression-injection surface in the third-party form runtime. None of this is theoretical: the token authenticates as the user until it expires.

**Why it does not block a validation item.** Items 1 to 3 are a compile, a test run and a text search. Items 4 and 5 ran against the reduced local stack, which has no Snowbound viewer and no Frevvo server, and the smoke flows do not open a document viewer or a form.

**Follow-up condition.** This is a **security change with contract consequences**, not a compatibility fix, and it is one of the six findings the review directs to a separately authorized remediation. Its shape: replace query-string token transport with a one-time server-side exchange, a secure cookie or an `Authorization` header; encode every non-secret parameter; remove token values from all log statements at every level; and rotate the exposed token class. Each of those changes an authentication path or a URL contract, which the preservation mandate freezes for this migration, and the third-party viewer and form products constrain what the replacement can look like. **Nothing here is base-commit code this migration touched** — every cited line is byte-identical to `c8f6226105`.

### CSRF protection is disabled on every active security chain

| Where | What |
| --- | --- |
| The external configuration bundle, e.g. `~/.arkcase/acm/spring-security/spring-security-config-ldap.xml:17`, `:38`, `:53` | Every `<http>` element in the active chain carries `<csrf disabled="true"/>`. The same pattern repeats across the eight `spring-security-config-*.xml` profiles |

**Impact.** The application authenticates state-changing requests with an ambient `JSESSIONID` cookie and no synchroniser token, so any state-changing endpoint is reachable cross-site from a page the user visits while logged in. The exposure scales with the size of the write surface, and the review counted 233 state-changing client definitions.

**Why it does not block a validation item.** The setting lives **outside this repository**, in the external configuration bundle the deployment clones, so no repository gate can assert on it; and the smoke flows are same-origin, so nothing they exercise depends on it. This migration changes no security configuration at all — it holds Spring Security inside the 5.4.x line precisely so the external profiles keep working unmodified.

**Follow-up condition.** Enabling CSRF is a wire-contract change for every write path: the server must issue a token, the AngularJS `$http` layer must return it, and the raw `XMLHttpRequest`, `navigator.sendBeacon` and multipart upload paths — which do not go through `$http` — each need their own handling. It also lands in a repository this one does not own. It belongs to the same authorized security change as the entry above, with a per-path inventory attached.

### Two HTML sinks trust content that arrives from an API

| Where | What |
| --- | --- |
| `resources/modules/core/controllers/page.client.controller.js:79` | The API/configuration-supplied warning text is passed through `$sce.getTrustedHtml($sce.trustAsHtml(params.message))` and rendered in the ArkCase origin, which disables the sanitiser for that value by construction |
| `resources/modules/admin/controllers/components/correspondence-management-email-template-preview-modal.client.controller.js:13` and `:44` | The API-returned correspondence template body is assigned straight to `document.getElementById("content").innerHTML`, both when the modal opens and after each `retrieveConvertedTemplateContent` response |

**Impact.** Script execution in the application origin for anyone who can influence either value — the login-warning text is configuration-supplied, and a correspondence template body is author-supplied through the admin UI. `innerHTML` will not run a bare `<script>` element, but it will run `onerror`/`onload` handlers and `javascript:` URLs, so the sink is live rather than nominal.

**Why it does not block a validation item.** Neither sink is on a smoke path: the login flow that item 5 exercises returns a 302 and never renders the warning modal, and no smoke step opens the correspondence template preview.

**Follow-up condition.** The repair is to render the warning as text, or sanitise both values against a narrowly-defined allowlist, and to move the template preview into a sandboxed iframe. Both change what the screen displays for existing content, which is a UI behaviour change this migration forbids itself, so they belong to the authorized security change with a review of what real templates legitimately contain.

### The portal request and inquiry paths log and return their raw payloads

| Where | What |
| --- | --- |
| `ArkCasePortalGatewayRequestAPIController.java:127-131` | `submitInquiry` logs the **entire inquiry JSON** at DEBUG through the `[{}]` placeholder that its own message calls a request "type" |
| `FOIAPortalRequestServiceProvider.java:107-118` and `SARPortalRequestServiceProvider.java:108-119` | `submitRequest`'s two failure paths log the raw request content at WARN and put it into the `PortalRequestServiceException` message, together with `portalUserId` and `portalId` |
| `FOIAPortalRequestServiceProvider.java:297-299` and `SARPortalRequestServiceProvider.java:299-301` | `submitInquiry`'s failure path does the same with the raw inquiry content — and its `log.warn` supplies **one** argument for **three** placeholders, so the two identifiers render as literal `{}` |
| `PortalRequestServiceExceptionMapper.java:73` | Publishes `exception.getMessage()` as the `error_message` field of the error response, so the raw payload in those messages leaves the server |

**Impact.** A portal request body carries the requester's name, address, contact details and request narrative; an inquiry body carries similar personal data. Both reach the application log, and on the failure paths the request body is also echoed to the caller in `error_message`.

**Why it does not block a validation item.** No smoke flow submits a portal request or an inquiry, and the reduced stack has no portal front end.

**A note on this entry's history, because it matters for R-6 and R-7.** An intermediate revision of this migration **removed** the raw payload from the two `submitRequest` messages while fixing the unrelated `java.time` deserialisation defect. That was reverted: the exception message is published verbatim as `error_message`, so redacting it changed a 500 response body — a wire-contract change smuggled into a compatibility migration, which is what R-6 forbids and what the base-commit tie-breaker in R-7 decides against. The delivered code therefore reproduces the base-commit text byte-for-byte, and the defect is registered here instead. The `java.time` fix beside it stays, because that one restores base-commit *behaviour* rather than changing it.

**Follow-up condition.** Log a correlation identifier and bounded, non-identifying metadata instead of the payload; return a generic external error while keeping the detail server-side. Both change published log and response content, so they need the same authorization and contract review as the entries above — and the `error_message` change in particular needs the portal client's owner to agree, since a portal may parse it.

**Follow-up condition.** Replacing `2.17` with `${surefire.version}` in both files is the obvious repair and was **deliberately reverted** from this change set: the plan maps the root `pom.xml` as the only POM this migration touches, and unplanned child-POM edits are exactly what the review flagged. It belongs in the next plan, with a `-DcoreBuild=true` run to prove the profile still behaves.
## Database and schema-authority defects — documented, not fixed

**Twenty-nine** defects sit in the database authority and in the code that reads and writes through it — the ORM mappings, the Liquibase changelogs, the stored routines, the DAOs and the query layer. **This migration changes none of it.** The schema, the effective DDL of the persistence mappings and every one of the 223 changelogs are on the preservation list, so R-6's "document, do not fix" applies here with no carve-out available: not one of the twenty-nine blocks a validation item, and several of the ones that look correctable in place are the ones where correcting them in place would do measurable harm — a claim this section substantiates rather than asserts.

The twenty-nine fall into five classes, and the class matters because it determines both the exercise path that would reveal a defect and who can close it:

| Class | IDs | Count | What kind of authority is wrong |
| --- | --- | ---: | --- |
| [Schema authority](#ds-01-a-mapped-collection-table-that-no-changelog-creates) | `DS-01`–`DS-03` | 3 | A mapping with no changelog behind it, a malformed type literal, and stored routines with an identifier surface and a broken cleanup |
| [Query and transaction seam](#query-and-transaction-seam-eight-defects-in-jpql-criteria-and-native-sql) | `DQ-01`–`DQ-08` | 8 | JPQL, Criteria and native SQL that name attributes, aliases and result types the model cannot supply |
| [ORM-to-schema mapping](#orm-to-schema-mapping-twelve-disagreements-between-the-annotations-and-the-changelogs) | `DM-01`–`DM-12` | 12 | Annotations and changelogs that are each coherent but disagree with each other |
| [Cross-DBMS DDL](#cross-dbms-ddl-two-defects-that-only-a-non-mysql-deployment-can-feel) | `DD-01`–`DD-02` | 2 | Platform-specific changeSets that a non-MySQL deployment gets wrong or skips |
| [Credentials persisted in recoverable form](#credentials-persisted-in-recoverable-form-required-human-action) | `DC-01`–`DC-04` | 4 | Bearer credentials stored and logged in a form that can be replayed — **the one class that needs an owner rather than a reader** |

Two things about the evidence, stated up front because they are not uniform across the five classes. The three schema-authority entries were reproduced **twice** — once by reading the authority in the tree, and once by executing it against the reference stack's MariaDB 10.6 on **isolated scratch databases** created and dropped for the purpose, with the pinned Liquibase 3.1.1 taken from the build's own dependency set; the reference `arkcase` database was read, never written. The other twenty-six were established by **reading the authority and the code**, plus two targeted executable probes named where they appear — a Spring transaction probe under DQ-07 and a Liquibase short-name probe under DD-02. Where a claim could only be settled by running the application against a service the reference stack does not provide, the entry says so in its own "what remains for others" clause rather than implying it was measured.

| ID | Defect | Location | Blocks a validation item? |
| --- | --- | --- | --- |
| DS-01 | A mapped collection table that no changelog creates | `PortalSARPerson.java:64-68` — collection table `acm_sar_person_portal_roles`; no schema authority anywhere | **No** — the stack exercised for items 4 and 5 runs the core profile, so the privacy beans that touch the mapping are never instantiated, and no smoke flow performs a portal registration |
| DS-02 | A malformed column type in an active fresh-schema changeSet | `acm-portal-gateway-tables-1.0.xml:53` — `VARCHAR(${cmGroupNameLength}))`, one closing parenthesis too many | **No** — and it is genuinely exercised rather than merely untouched: the changeSet is recorded `EXECUTED` on the reference database, because Liquibase 3.1.1 normalises the stray parenthesis away |
| DS-03 | Median stored routines with an unvalidated identifier surface, a cleanup statement that cannot run, and an OUT parameter that is never assigned | `foia-db-procedures-1.0.xml:10-55` and the byte-identical `privacy-request-db-procedures-1.0.xml` | **No** — the routines install only under the `extension-foia` or `extension-privacy` profile, and `information_schema.ROUTINES` on the reference database is empty |

The remaining twenty-six are tabulated in their own subsections below, each with the same three columns and the same obligations.

### DS-01 — a mapped collection table that no changelog creates

**The malformed column type.** An active fresh-schema changeSet declares a column type with an extra closing parenthesis. Liquibase 3.1.1 — the pinned version, and the only one this build uses — normalises it away, which is why the changeSet is recorded as executed and why nothing downstream noticed. It is a latent portability defect rather than a live failure: a different Liquibase generation could reject the same text. Correcting it in place would alter a changeSet that has already run on real databases, which is the specific harm the preservation mandate exists to prevent, so the repair belongs in a new corrective changeSet planned as such.

**The median stored routines.** Two changelogs define the same nine `mysql`-only routines and are byte-identical to one another (`git hash-object` returns the same 40-character digest for both, 304 lines each). Three defects sit in the shared helper pair rather than in the wrappers that call them:

- **An unvalidated identifier surface.** Two of the routines take table and column names as arguments and concatenate them into the SQL text they prepare, with no identifier validation or quoting. Verified by execution on a scratch database: a crafted argument in the table-name position is accepted and changes what the routine computes. The exact payload is deliberately not published here — it is in the restricted security record, because these are installable routines in a shipped changelog and this page is public.
- **A cleanup statement that cannot run.** One routine prepares a `DROP TABLE` with a placeholder in the identifier position, which MariaDB rejects as a syntax error at execution time. The call aborts there, so the table it was meant to drop **survives** — verified: the probe's data table still held all five of its rows after the failed call.
- **An OUT parameter that is never assigned.** The same routine copies its OUT parameter *into* a session variable instead of out of one, and the parameter is unset at that point, so the caller receives nothing.

**What the intended path does right, stated so the risk is not overdrawn.** The wrapper procedures do not pass user input into the identifier positions; they pass literal table and column names of their own. The seam is that both helpers are ordinary schema-level routines rather than private ones, so anything holding `EXECUTE` on the schema can call them directly with arguments of its choosing.

The mapping is not dormant. `gov/privacy/service/SARPortalUserServiceProvider` reads the map at `:181`, `:302`, `:330-331`, `:1011` and `:1017`, and writes it at `:340`, `:405`, `:524` and `:1086`; the write at `:524` is followed immediately by `portalPersonDao.save(portalSARPerson)` at `:525`, so the persist path would emit an insert against the absent table. `@ElementCollection` declares no fetch mode, so JPA's `LAZY` default applies and a read is deferred until the map is touched — which those call sites do. Both beans are registered inside the Spring profile `extension-privacy`, at `spring-extension-library-privacy.xml:50` and `:52`, so the exposure is a privacy-profile deployment specifically.

One detail is worth recording because it shows the shape of the underlying mistake. The FOIA side is the **exact mirror image**: `foia-request-db-tables-1.0.xml:591-597` does create `acm_foia_person_portal_roles` with `cm_person_id`, `cm_portal_id` and `cm_user_role`, and `foia-request-db-sql-1.0.xml:77-83` queries it — while `gov/foia/model/PortalFOIAPerson.java:57` maps a single `@Column(name = "fo_portal_role")` string and no collection at all. FOIA has the table without the mapping; privacy has the mapping without the table.

**Why it does not block a validation item.** Items 1 through 3 never touch a database. Items 4 and 5 are themselves recorded as **constrained** in [the smoke evidence](smoke-evidence.md), and the stack they *were* exercised on runs with `spring.profiles.active=ldap` — the **core** profile — so the two beans that touch the mapping are never instantiated, the entity is not reachable and no portal registration flow executes. Nothing in the migration went near this file: it is byte-identical to the base commit, as is every changelog that might have created the table.

**What remains for others.** Tracing whether a privacy-profile deployment actually reaches the load or persist path, and whether an external DDL bundle creates the table outside this repository, is an order-1 and QA question, not a documentation one: the repository can prove the absence of schema authority, but only a live privacy-profile environment can prove what the absence costs. **No opportunistic schema edit is made here.** Adding a `createTable` would be a schema change in a migration whose recorded delta is zero added, zero removed and zero changed database elements, and it would ship untested DDL for a path this environment cannot exercise.

### DS-02 — a malformed column type in an active fresh-schema changeSet

`acm-services/acm-service-portal-gateway/src/main/resources/com/armedia/acm/ddl/tables/acm-portal-gateway-tables-1.0.xml:53` carries one closing parenthesis too many:

```xml
<column name="cm_group_name" type="VARCHAR(${cmGroupNameLength}))" defaultValue="0"/>
```

The property is declared twice at `:9-10` — `1024` for `postgresql,oracle` and `255` for `mysql,mssql` — so the literal resolves to `VARCHAR(1024))` or `VARCHAR(255))`. The well-formed sibling in the immediately preceding changeSet, `type="VARCHAR(${cmUserIdLength})"` at `:30`, is the same idiom with one parenthesis, which is what identifies this as a typo rather than an intention. The owning changeSet is `02-1-alter-table-acm_portal_info-add-cm_group_name` at `:45-55`, declared for `oracle,postgresql,mssql,mysql` and guarded by `preConditions onFail="MARK_RAN"` on the column's absence — so on an already-migrated database it is marked ran, and on a fresh schema the guard passes and the `addColumn` executes.

**Measured: it does not fail.** The pinned Liquibase 3.1.1 normalises the stray parenthesis in its type parser, and it does so identically on every supported dialect:

| Dialect | Malformed input | Resolved type | Well-formed control |
| --- | --- | --- | --- |
| `mysql` | `VARCHAR(255))` | `VARCHAR(255)` | `VARCHAR(255)` |
| `postgresql` | `VARCHAR(1024))` | `VARCHAR(1024)` | `VARCHAR(1024)` |
| `oracle` | `VARCHAR(1024))` | `VARCHAR2(1024)` | `VARCHAR2(1024)` |
| `mssql` | `VARCHAR(255))` | `VARCHAR(255)` | `VARCHAR(255)` |

Running Liquibase 3.1.1's `updateSQL` over a scratch changelog that carries the malformed literal verbatim beside a well-formed control column emits two statements that differ only in the column name — `probe006` and `acm_portal_info_probe` are the scratch schema and table:

```sql
ALTER TABLE probe006.acm_portal_info_probe ADD cm_group_name VARCHAR(255) NULL DEFAULT '0';
ALTER TABLE probe006.acm_portal_info_probe ADD cm_group_name_ok VARCHAR(255) NULL DEFAULT '0';
```

Executing that changelog for real on MariaDB 10.6 reported `Liquibase Update Successful`, and `information_schema.COLUMNS` returned `cm_group_name varchar(255)` with default `'0'` — identical to the control column. The reference database agrees, and it is the real changeSet rather than a probe: `DATABASECHANGELOG` records `02-1-alter-table-acm_portal_info-add-cm_group_name`, from `/com/armedia/acm/ddl/tables/acm-portal-gateway-tables-1.0.xml`, with `EXECTYPE = EXECUTED`. (`acm_portal_info` is nevertheless absent from that database at the end of the run, for an unrelated legacy reason: `complaint-db-table-drops.xml:16-21` drops both it and `acm_portal_info_id` later in the same changelog sequence.)

!!! warning "Correcting the typo in place is what would break a database"

    The defect is benign only because a parser tolerates it, and the tolerance is not a contract. The repair, however, has a **measured** cost, and that cost is the reason this belongs in a scheduled schema-maintenance change rather than in a runtime migration.

    A changeSet's recorded identity includes a checksum over its content, so editing the type in place changes it. Demonstrated on the scratch changelog: the malformed changeSet recorded `MD5SUM` `7:4dee189c076432075fda39e0651452fc`; after correcting the literal to `VARCHAR(255)` and re-running against the same database, Liquibase 3.1.1 refused to proceed at all — its own output, verbatim, with the probe's changeSet identity:

    ```text
    liquibase.exception.ValidationFailedException: Validation Failed:
         1 change sets check sum
              probe-changelog.xml::probe-01-malformed-type::probe is now: 7:a651bcf8efb170d16f18d95a7a8e46ad
    ```

    The checksum values are the probe's, because a checksum covers the changeSet's id, author and file as well as its body; the behaviour is what transfers. Correcting the real literal would stop every already-migrated deployment from starting until the change were paired with a `validCheckSum` entry or an equivalent strategy. That pairing is a schema decision with its own review and its own upgrade note — precisely what R-6 keeps out of a compatibility migration.

**Why it does not block a validation item.** Items 1 through 3 never touch a database. Items 4 and 5 *do* exercise this changeSet — it is in the core changelog, not an extension one — and it passes, as the `EXECUTED` row above shows. This entry therefore answers the "does a gate exercise it" question with a yes and a pass, rather than with an untested absence.

**What remains for others.** A separate schema-maintenance change should correct the type with a checksum strategy attached, and QA should confirm it against both a clean database and `updateSQL` output on each supported platform — the type resolution above covers all four dialects, but only the MySQL/MariaDB dialect was actually executed here. This migration's zero-delta database scope is preserved deliberately: the changelog is byte-identical to the base commit.

### DS-03 — median stored routines with an unvalidated identifier surface and a broken cleanup

Two changelogs define the median-calculation routines, and they are **byte-identical** — `git hash-object` returns `dc6074d3e690f95bb6c9c3da33defdbd6b3c3d70` for both, 304 lines each:

- `acm-standard-applications/acm-foia/src/main/resources/com/armedia/acm/extension/foia/ddl/triggers/foia-db-procedures-1.0.xml`
- `acm-standard-applications/acm-privacy/src/main/resources/com/armedia/acm/extension/privacy/ddl/triggers/privacy-request-db-procedures-1.0.xml`

Each defines nine `mysql`-only routines: six procedures in changeSet `01-AFDP-7342-…` at `:6-169`, and three functions in changeSets `02-…` and `03-…` at `:171-302`. The three defects are all in the first two procedures, so every statement below applies to both files at the same line numbers.

**The identifier surface.** `ark_Median(tbl CHAR(64), col CHAR(64), OUT res DOUBLE)` at `:10-35` builds its statements by concatenating its two arguments as SQL text — at `:12` for the row count, at `:21` and `:26` for the aggregate expression, and at `:29-30` for the ordered subselect — while binding only the numeric `LIMIT` offsets, with `EXECUTE stmt USING @a, @b` at `:32`. Nothing validates, quotes or escapes either identifier. That the position accepts arbitrary SQL rather than a table name is not a theoretical reading; passing a derived-table expression instead of a table name returns its value:

```sql
CALL ark_Median('(SELECT 42 AS response_time UNION SELECT 42) AS injected', 'response_time', @o);
-- @o -> 42
```

**The cleanup statement cannot run.** `ark_MedianWithTableDrop(IN p_table_name TEXT, IN p_table_column TEXT, OUT result TEXT)` at `:40-55` prepares `'drop table ?'` at `:51` and executes it with a user variable at `:52`. A parameter marker cannot supply an identifier, so the statement fails at prepare time. Measured on MariaDB 10.6:

```text
ERROR 1064 (42000) at line 2: You have an error in your SQL syntax; check the manual that
corresponds to your MariaDB server version for the right syntax to use near '?' at line 1
```

The call aborts there, so the table it was meant to drop **survives** — verified: the probe's data table still held all five of its rows after the failed call, which is how a generated table would leak on every invocation.

**The OUT parameter is never assigned.** The same procedure copies its OUT parameter *into* a session variable at `:45` (`set @r = result;` — the direction is backwards, and `result` is unset at that point), passes `@r` into the nested `ark_Median` call at `:47-48`, and then reaches `end` at `:55` without ever assigning anything back to `result`. Measured with a caller variable named `@myout`, the declared OUT comes back `NULL`. It is worth knowing why the defect can look as though it were absent: `ark_Median` writes the unqualified session variable `@res` internally at `:29-34`, so a caller that happens to name its own variable `@res` sees a value arrive there by collision rather than through the parameter — measured, the same call left `@myout` `NULL` while setting `@res` to `3`. A caller using any other name gets nothing. The two intended entry points, `ark_MedianForAllProcessedRequests` at `:123-143` and `ark_MedianForAllPendingRequests` at `:148-166`, have the same gap one level up: each sets `@m` from its own OUT parameter at `:130` and `:155` and never assigns back to `medianValueRes`.

**What the intended path does right, stated so the risk is not overdrawn.** The wrapper procedures do not hand user input into the identifier positions. `ark_MedianDataForAllProcessedRequests` at `:60-85` and `ark_MedianDataForAllPendingRequests` at `:90-118` derive their table name from `SELECT LEFT(UUID(), 8) INTO @tmpTableName` at `:62` and `:92`, bind every caller-supplied value with `?` and `USING` at `:79-81` and `:110-114`, and return the generated name through `SELECT @tmpTableName INTO result` at `:84` and `:117`. The two entry points then pass that generated name plus a hardcoded column literal — `"response_time"` at `:138`, `"pending_time"` at `:161` — into `ark_MedianWithTableDrop` at `:139-141` and `:162-164`. On that path the identifiers are machine-generated and constant, and the injection surface is not reached.

**Why it is still a security seam.** `ark_Median` and `ark_MedianWithTableDrop` are ordinary schema-level procedures, not private ones: anything holding `EXECUTE` on the schema can call them directly with identifiers of its choosing, and the wrappers' discipline protects only callers that go through the wrappers. Outside those two changelogs — and this register — none of the nine routine names appears in a single tracked file: there is no `CallableStatement`, no `StoredProcedureQuery` and no `call ark…` string anywhere in the Java sources. Every real consumer is therefore external to this repository, which is exactly why the caller and grant trace cannot be completed from here.

**Why it does not block a validation item.** Items 1 through 3 never touch a database, and the routines are not even installed on the stack that items 4 and 5 were exercised against. The core `SpringLiquibase` bean runs `classpath:/ddl/acm-database-changelog.xml` (`spring-library-data-source.xml:166`), whose `includeAll` list covers `/com/armedia/acm/ddl/triggers` and `/ddl/triggers` at `:36-37` and contains **no reference** to the extension paths; these routines live under `…/extension/{foia,privacy}/ddl/triggers`, which is included only by the extension masters that the `extension-foia` and `extension-privacy` profiles substitute for the core changelog (`spring-extension-library-privacy.xml:10-15`). That stack runs `spring.profiles.active=ldap`, and measured on its database, `information_schema.ROUTINES` for schema `arkcase` returns **no rows** — not one median routine exists there.

**What remains for others.** Order-1 must enumerate the external report definitions and the database `EXECUTE` grants that reach these routines, since the repository holds the definitions but no caller; QA must confirm the cleanup and output behaviour on a FOIA-profile or privacy-profile environment, where the failed `DROP` and the unassigned OUT are observable. **The routines are not repaired here.** They are stored database objects created by changelogs, so editing them is a schema change of exactly the kind this migration records as zero-delta — and, as with the malformed type above, editing a `createProcedure` changeSet in place would also invalidate its checksum on every database that already ran it.

### Query and transaction seam — eight defects in JPQL, Criteria and native SQL

The three entries above are defects in the schema *authority*. The eight below are defects in the code that reads and writes through it: property paths naming attributes no entity declares, a result type the query cannot produce, a projection its `GROUP BY` does not cover, a sort referencing an alias the statement never declares, two subtype queries that select their base class, and one bulk delete whose transaction boundary sits somewhere fragile. They belong on this page for the same reason the first three do — every one of them is byte-identical to the base commit, and none is reached by anything the migration is measured on.

That last clause is the load-bearing one, and it has a single mechanical cause: **JPQL strings, Criteria attribute names and native SQL are not checked by the compiler, and EclipseLink parses them on first execution rather than at deployment.** A misspelled property therefore survives `mvn clean install` untouched and fails only when a user reaches the feature. Two of the eight are not reachable even then, because nothing calls them.

| ID | Defect | Location | Blocks a validation item? |
| --- | --- | --- | --- |
| DQ-01 | A misspelled property in a Criteria predicate **and** its order-by — `consultatonNumber` for an entity that declares `consultationNumber` | `ConsultationDao.java:215` and `:217` | **No** — the method has **no caller in the repository**, and no test constructs the query |
| DQ-02 | A purge cutoff on `dateCreated`, which none of the three configured entity types declares | `CalendarEntityHandler.java:383` | **No** — the only test of the owning method is class-level `@Ignore`d, and the path needs a live Exchange connector |
| DQ-03 | An existence check that selects an entity root and casts the result to `boolean` | `CalendarEntityHandler.java:346-360`, the cast at `:359` | **No** — same `@Ignore`d suite, same live-Exchange requirement |
| DQ-04 | A native-SQL sort on `lu.cm_value`, where `lu` is never joined or declared | `AuditDao.java:183`, against the statement built at `:168-178` | **No** — reached only when a caller asks for `sort = "eventType"`; no test exercises the native query |
| DQ-05 | Two subtype DAOs whose JPQL selects the base `CaseFile` while the typed query declares the subtype | `FOIARequestDao.java:78`, `:88`, `:373`; `SARDao.java:69`, `:78`, `:307` | **No** — the one test over these paths mocks the DAO, so no JPQL is parsed or executed |
| DQ-06 | Ten projected expressions grouped by two | `ExemptionCodeDao.java:125-133` | **No** — MySQL/MariaDB's default mode permits it, and no test executes it |
| DQ-07 | A scheduled bulk `DELETE` whose only transaction annotation sits on an interface method, with neither the service implementation nor the DAO carrying one | `ProtectedUrlDao.java:81-86`; `ProtectUrlServiceImpl.java:140-145`; `ProtectUrlJobDescriptor.java:48-52`; the annotation at `ProtectUrlService.java:83` | **No** — and see the measurement below, which withdraws the predicted failure while leaving the fragility |
| DQ-08 | A dead finder over a column the DDL explicitly drops | `AuthenticationTokenDao.java:65-73` | **No** — **no caller anywhere**, so the query is never parsed |

The table names each file by its simple name so the rows stay readable. Every path is given in full here once, so that each citation above and below is checkable against either tree — all eight files are byte-identical to the base commit, so a single set of line numbers serves both.

| Simple name | Repository-relative path |
| --- | --- |
| `ConsultationDao.java` | `acm-plugins/acm-default-plugins/acm-consultation-plugin/src/main/java/com/armedia/acm/plugins/consultation/dao/ConsultationDao.java` |
| `CalendarEntityHandler.java` | `acm-services/acm-service-calendar-integration-exchange/src/main/java/com/armedia/acm/calendar/service/integration/exchange/CalendarEntityHandler.java` |
| `AuditDao.java` | `acm-services/acm-service-audit/src/main/java/com/armedia/acm/audit/dao/AuditDao.java` |
| `FOIARequestDao.java` | `acm-standard-applications/acm-foia/src/main/java/gov/foia/dao/FOIARequestDao.java` |
| `SARDao.java` | `acm-standard-applications/acm-privacy/src/main/java/gov/privacy/dao/SARDao.java` |
| `ExemptionCodeDao.java` | `acm-services/acm-service-exemption/src/main/java/com/armedia/acm/services/exemption/dao/ExemptionCodeDao.java` |
| `ProtectedUrlDao.java`, `ProtectUrlService.java`, `ProtectUrlServiceImpl.java`, `ProtectUrlJobDescriptor.java` | `acm-services/acm-service-protect-url/src/main/java/com/armedia/acm/services/protecturl/` — `dao/` for the first, `service/` for the other three |
| `AuthenticationTokenDao.java` | `acm-services/acm-service-authentication-token/src/main/java/com/armedia/acm/services/authenticationtoken/dao/AuthenticationTokenDao.java` |

#### DQ-01 — `consultatonNumber`

`ConsultationDao.findByConsultationNumberKeyword` builds both its predicate and its ordering on a property name that does not exist:

```java
query.where(builder.and(builder.like(builder.lower(cf.get("consultatonNumber")), "%" + expression.toLowerCase() + "%")));
query.orderBy(builder.asc(cf.get("consultatonNumber")));
```

`Consultation` declares `consultationNumber` at `:129-130`, under `@AcmSequence(sequenceName = "consultationNumberSequence")`. The sibling finder in the same class spells it correctly — `"SELECT cf FROM Consultation cf WHERE cf.consultationNumber = :consultationNumber"` at `:109` — which is what identifies this as a transposition rather than a second, differently-named attribute. A Criteria `Path.get` on an unknown attribute raises `IllegalArgumentException` from the metamodel while the query is being *built*, so the failure is immediate and total rather than a wrong result set.

**Why it does not block a validation item.** `git grep findByConsultationNumberKeyword` returns **one** line — the declaration itself. No service, controller, Spring XML or test references it, so the method is unreachable and the metamodel lookup never runs. Items 1 through 3 never execute it; items 4 and 5 never reach it either.

**What remains for others.** The correct disposition is a decision, not a typo fix: the method is dead, so order-1 should establish whether a consultation-number keyword search was ever wired up and is missing its caller, or whether the method should go. Either answer is a behavioural change to a plugin DAO, which is why it is registered here rather than corrected — and correcting the spelling alone would *activate* a query that has never run, which is a larger change than it looks.

#### DQ-02 and DQ-03 — the calendar purge

Both defects sit in `CalendarEntityHandler`, and both are reached only through `purgeCalendars`.

`getEntities` builds the `CLOSED_X_DAYS` branch on a property no candidate entity has:

```java
Predicate predicate = cb.lessThanOrEqualTo(acmObject.<Date> get("dateCreated"), calculateModifiedDate(daysClosed));
```

The handler's entity type is injected, and exactly three beans configure it: `CaseFile` (`spring-library-case-file-calendar-integration.xml:9`), `Complaint` (`spring-library-integration-complaint.xml:60`) and `Consultation` (`spring-library-consultation-calendar-integration.xml:9`). All three declare `created` — `CaseFile.java:159`, `Complaint.java:145`, `Consultation.java:152` — and none declares `dateCreated`. The helper's own name, `calculateModifiedDate`, points at the third possibility, `modified`, which is what the base-commit test expects.

`isObjectClosed` has an unrelated defect in the same file: it selects the entity root and then casts the row to a primitive.

```java
CriteriaQuery query = cb.createQuery(acmObjectClass);
Root acmObject = query.from(acmObjectClass);
query.select(acmObject);
…
return (boolean) dbQuery.getSingleResult();
```

The consequence is precisely inverted from the method's purpose: a **match** returns an entity, which cannot be cast to `boolean`, so it throws; and the only path that returns a value is the `NoResultException` catch, which returns `false`. The method can therefore answer "no" or fail, never "yes". Its single caller is `ExchangeCalendarService.java:647`.

**Why they do not block a validation item.** `CalendarEntityHandlerTest` is **class-level `@Ignore`d** at `:84` — one of the 21 pre-existing skips named in [the baseline record](baseline-test-failures.md) — so no configured test builds either query. Its assertions are also the best available evidence of intent: at `:291` and `:333` they expect `"SELECT obj FROM %s obj WHERE obj.status IN :statuses AND obj.container.calendarFolderId IS NOT NULL AND obj.modified <= :modified"` and a `setParameter("modified", …)` at `:294` and `:336` — a `modified` cutoff and a JPQL string, against an implementation that now builds Criteria on `dateCreated`. Beyond the test, both paths require a live Exchange connector, which the reduced reference stack does not provide; items 4 and 5 never reach them.

**What remains for others.** Re-enabling that suite is the only way to establish which cutoff the purge is *supposed* to use, and R-7 makes the ignored test's expectation the strongest available evidence rather than a licence to change behaviour — the assertions predate the Criteria rewrite, so somebody has to decide which of the two is authoritative. That decision belongs with the calendar-integration owner, and it must be paired with a re-enabled test, because a purge that deletes on the wrong date column destroys data. Neither defect is repaired here: R-5 forecloses touching the ignored class, and AAP §0.2.4.2 forecloses editing its assertions.

#### DQ-04 — an undeclared alias in the audit sort

`AuditDao.findPagedResults` assembles a native statement whose `FROM` clause declares exactly two aliases — `ae` inside the derived table and `al` for the outer join target (`:168-178`) — and then, when the caller sorts by event type, orders on a third:

```java
queryText += " ORDER BY COALESCE(lu.cm_value, al.cm_audit_activity) ";
```

`lu` appears nowhere else in the statement or the class. The shape of the expression is self-documenting about the intent: `COALESCE` over a lookup value falling back to the raw activity is a translated-label sort, so a join to a list-of-values table was meant to be there. As written, the database rejects the statement — on MySQL and MariaDB with `Unknown column 'lu.cm_value' in 'order clause'` — and the audit tab fails rather than sorting badly. The other two branches (`userId` and the default) sort on `al`, which is declared, so only the `eventType` branch is affected.

**Why it does not block a validation item.** The query is native SQL passed to `createNativeQuery` at `:202` and is parsed by the database, not by the build; nothing in the configured suite executes it. Reaching it needs a deployed application, an audit history and a user who sorts that column — items 4 and 5 exercise login and rendering, not the audit tab's event-type sort.

**What remains for others.** The join that belongs there has to be identified from the audit feature's own history — which lookup table, and on what key — and that is a functional decision for the audit owner. QA can confirm the failure cheaply on any deployed instance by sorting the audit tab by event type. It is not repaired here because inventing the join would be a functional change to a reporting query, and guessing the wrong lookup table would silently reorder audit history instead of failing loudly.

#### DQ-05 — subtype queries that select the base class

Six statements across two DAOs select `CaseFile` while their `TypedQuery` declares a subtype:

```java
String queryText = "SELECT cf FROM CaseFile cf WHERE cf.queue.id = :queueId AND …";
TypedQuery<FOIARequest> unassignedRequestsInQueue = getEm().createQuery(queryText, FOIARequest.class);
```

`FOIARequest` is `@DiscriminatorValue("gov.foia.model.FOIARequest") … extends CaseFile` (`FOIARequest.java:65-71`) and `SubjectAccessRequest` is its privacy-side equivalent, both single-table subclasses. The result-class argument of `createQuery` is a *cast contract*, not a filter: EclipseLink parses `FROM CaseFile` and returns every `CaseFile` row matching the queue predicate, including plain case files and sibling subtypes. The assignment then succeeds — generics are erased — and the `ClassCastException` surfaces later, at whichever call site first uses a returned element as the subtype. The FOIA and privacy queue-assignment services are those call sites: `FOIARequestService.java:198`, `SARService.java:157` and `RequestAssignmentService.java:71,74`.

Two things bound this. The queue predicate is itself a strong filter, because FOIA and privacy queues hold requests of that extension's own type in practice; and a deployment runs one extension profile, so the sibling-subtype collision needs a database with mixed `CaseFile` subclasses in one queue. That is why the defect is latent rather than constant — and it is also why it cannot be dismissed: the correctness of a queue-assignment query is resting on a data convention rather than on the query.

**Why it does not block a validation item.** The one test over these paths, `RequestAssignmentServiceTest`, **mocks the DAO** — `expect(mockedRequestDao.getAllUnassignedRequestsInQueue(queueId)).andReturn(…)` at `:110`, `:146` and `:169` — so no JPQL string is ever parsed and no row is ever cast. Items 1 through 3 never execute JPQL at all, and the reference stack runs the core `ldap` profile, so neither extension's queue service is instantiated.

**What remains for others.** The repair is small and known — query the subclass directly, or add a `TYPE(cf) = …` predicate — but it changes which rows a queue returns, so it needs the FOIA and privacy owners to confirm the intended semantics and a test with **mixed** `CaseFile` subtypes in one queue, which no current fixture provides. QA should exercise it on a FOIA-profile or privacy-profile environment. Not repaired here: it is a query-behaviour change in extension code that no validation item covers, which is exactly the position R-6 keeps out of a runtime migration.

#### DQ-06 — a projection its grouping does not cover

`ExemptionCodeDao.getExemptionCodesByFileIdAndCaseId` selects ten expressions and groups by two:

```java
String queryText = "SELECT codes.id, codes.exemptionCode, codes.exemptionStatus, codes.creator, codes.created, file.fileId, codes.fileVersion, cont.containerObjectId, codes.manuallyFlag, codes.exemptionCodeNumber "
        + … + "GROUP BY codes.exemptionCode, codes.exemptionStatus";
```

Eight of the ten projected values are functionally undetermined by the grouping, and the method then reads all ten positionally into a fresh `ExemptionCode` (`:145-154`). On a permissive server the row is assembled from an arbitrary member of each group, so the `id`, `created`, `creator` and `fileVersion` a caller receives may belong to a different row than the code and status it was grouped by. On a strict one — `ONLY_FULL_GROUP_BY`, which is MySQL 5.7+ and MariaDB's default in several configurations — the statement is rejected outright. Its caller is `DocumentExemptionServiceImpl.java:137`.

**Why it does not block a validation item.** No test executes it, and items 1 through 3 never run a query. The reference MariaDB 10.6 instance this migration was validated against does not run `ONLY_FULL_GROUP_BY`, and in any case items 4 and 5 do not open a document's exemption codes.

**What remains for others.** Both candidate repairs — `DISTINCT` over the ten expressions, or grouping every one of them — change which rows come back, and the third option, aggregating deterministically, changes them more. Choosing between them requires knowing whether the grouping was meant to de-duplicate codes per file or to summarise them, which is a functional question for the exemption owner. QA should additionally run it against a server with `ONLY_FULL_GROUP_BY` enabled, because that turns an arbitrary-row defect into an outage and no environment here has that setting.

#### DQ-07 — the scheduled delete, and a predicted failure that measurement withdrew

`ProtectedUrlDao.removeExpired` runs a bulk JPQL `DELETE`:

```java
Query query = getEm().createQuery("DELETE FROM ProtectedUrl pu WHERE pu.validTo < :givenDate");
query.setParameter("givenDate", LocalDateTime.now(ZoneId.of("UTC")));
return query.executeUpdate();
```

`executeUpdate` requires an active transaction, and the annotation that supplies one is in an unusual place. `ProtectUrlServiceImpl.removeExpired` (`:140-145`) has **no** annotation of its own — only `@Override`; `ProtectedUrlDao` has none anywhere in the module; the single `@Transactional` sits on the **interface** method, `ProtectUrlService.java:83`. Spring's own documentation advises against annotating interfaces, and the review reading this wiring predicted a `TransactionRequiredException` on every run of the `deleteExpiredUrlsJob`.

!!! warning "The predicted failure does not reproduce — and the reason it does not is worth knowing"

    The wiring was measured rather than argued about, on the exact Spring version this migration ships. A probe reproduced the shape faithfully — `@Transactional` on an interface method only, a plain implementation, a counting `PlatformTransactionManager`, and `<tx:annotation-driven>` — under both proxy strategies, because this repository forces class-based proxying in the same context: `<aop:aspectj-autoproxy proxy-target-class="true"/>` appears in `spring-library-core-api.xml:6`, `spring-library-billing.xml:6` and `spring-library-object-lock.xml:6`, and `web.xml:31-34` loads every `spring-library-*.xml` into **one** root context alongside the `<tx:annotation-driven transaction-manager="transactionManager"/>` at `spring-library-data-source.xml:153`.

    Measured on Spring 5.3.39:

    ```text
    jdk-proxy.xml:   cglibProxy=false jdkProxy=true  -> transactionsStarted=1
    cglib-proxy.xml: cglibProxy=true  jdkProxy=false -> transactionsStarted=1
    ```

    A transaction is demarcated under **both** strategies, resolved against the implementation method while the annotation is read from the interface declaration. So the scheduled job does get a transaction, and the prediction is withdrawn — recorded here rather than quietly dropped, because a register that keeps a refuted prediction is worse than no register.

What survives the measurement is narrower and still real. The boundary depends entirely on the call arriving through the proxy on the interface type, and nothing in the code says so: `ProtectUrlJobDescriptor.java:40` holds the field as `ProtectUrlService`, which is what makes it work today. Neither the implementation nor the DAO carries an annotation, so a self-invocation inside the implementation, a caller injected with the concrete type, a direct `protectedUrlDao.removeExpired()` from any future code, or a switch of transaction management to AspectJ weaving mode all lose the boundary — silently, with no compile-time signal, and with `TransactionRequiredException` as the runtime symptom. The defect is the *placement*, not a missing transaction.

**Why it does not block a validation item.** Items 1 through 3 never start a Spring context that schedules Quartz jobs. Items 4 and 5 do deploy the application, and the job is registered rather than invoked during login and rendering; the reduced stack's smoke window does not span an expiry sweep.

**What remains for others.** Two things, and they are cheap. QA should confirm on a deployed instance that `deleteExpiredUrlsJob` actually commits — the log line is already there at `ProtectUrlServiceImpl.java:144`, reporting the removed count at debug level. And the owner of that service should move the annotation onto the implementation method, where Spring documents it belongs, which is a one-line hardening that changes no behaviour today but removes the silent-loss mode. Neither is done here: the first is not a repository change, and the second is a transaction-semantics edit to production code that no validation item covers.

#### DQ-08 — a finder over a dropped column

`AuthenticationTokenDao.findAuthenticationTokenByTokenFileId` (`:65-73`) queries `authenticationToken.fileId`. The entity declares no such attribute — `AuthenticationToken` maps `id`, `creator`, `created`, `modified`, `modifier`, `key`, `email`, `password`, `status`, `relativePath`, `genericPath` and `tokenExpiry` (`:57-95`) — and the schema is emphatic about why: `authenticationtoken-db-drops-1.0.xml:5-13` is a changeSet named `01-drop-column-cm_authentication_token_file_id` that drops the column behind a `columnExists` precondition, and `acm-authenticationtoken-constraints-1.0.xml:19-22` guards its foreign key the same way. The column was deliberately retired; the finder was left behind.

**Why it does not block a validation item.** `git grep findAuthenticationTokenByTokenFileId` returns **one** line, the declaration. Nothing calls it, so EclipseLink never parses the JPQL, and it would fail at parse time if anything did.

**What remains for others.** This is the one entry on this page whose repair is unambiguous — the method is dead and the column it names is gone, so deleting it removes a trap without changing any behaviour. It is still not done here, for a reason worth stating plainly rather than hiding behind the rule: it is a public method on a DAO that external code could reflectively or textually depend on, and this migration's whole claim is that its production diff contains nothing but the runtime move. A tidy-up commit with no Java 17 justification would weaken that claim for no gain. The review's alternative reading — rewriting it against a surviving property — is worse, because it invents a finder nobody asked for.


### ORM-to-schema mapping — twelve disagreements between the annotations and the changelogs

The queries above are wrong about the model. These twelve are cases where the model and the schema are each internally coherent but **disagree with each other**: an identity the ORM declares that no table enforces, an equality contract a composite key omits, override annotations naming attributes that do not exist, two lifecycles managing the same rows, a cardinality the DDL does not require, uniqueness claimed on a column the schema constrains only in combination, a join that targets a non-key column, cascades that reach into shared parents, and three classes of fine-grained metadata drift.

Two properties are common to all twelve and are what keep them off the blocking list. **EclipseLink is not validating the mapping against the live schema**: `generateDdl` is `false` at `spring-library-data-source.xml:142`, weaving is off at `:55`, and there is no `eclipselink.ddl-generation` or `hbm2ddl` property anywhere — so an annotation that over-claims is simply not checked, and Liquibase remains the only authority. And **nothing in the configured suite persists through a real EntityManager**: the unit tests mock the persistence layer, so an identity, cascade or override defect has nothing to act on. That is why 773 green tests and twelve mapping disagreements coexist without contradiction.

| ID | Defect | Location | Blocks a validation item? |
| --- | --- | --- | --- |
| DM-01 | Two ORM identities with no primary key or unique constraint behind them | `WidgetRole.java:43-58`; `OutlookPassword.java:37-49` | **No** — no test persists either entity, and the reference stack's smoke window creates no widget-role or Outlook-password row |
| DM-02 | Four `@IdClass` key types with no value-based `equals`/`hashCode` | `WidgetRolePrimaryKey.java`; `AcmSequenceEntityId.java`; `AcmSequenceResetId.java`; `AcmSequenceRegistryId.java` | **No** — reached only by `find()`, cache lookup or a keyed collection against a live persistence unit |
| DM-03 | An `@AttributeOverride` naming a column, not an attribute; an override pair applied to a relationship; and a persistent field hidden by three subclasses | `ComprehendMedical.java:51-65`; `OCR.java:61-75`; `Transcribe.java:73-87`; `MediaEngine.java:71-74` | **No** — the media-engine features need AWS credentials the reduced stack does not have |
| DM-04 | Two `@ElementCollection`s managing rows that are also full entities with generated IDs and audit metadata | `FOIAFile.java:58-66`; `SARFile.java:57-60` | **No** — extension-profile code; the reference stack runs the core profile |
| DM-05 | Java requires a non-null parent where the DDL permits `NULL` and declares no foreign key at all | `ComprehendMedicalEntity.java:64-66`; `ComprehendMedicalEntityAttribute.java:60-62` against `comprehend-medical-db-tables-1.0.xml:73-75` and `:119-121` | **No** — same AWS dependency as DM-03 |
| DM-06 | `unique = true` on four inverse join columns that the schema constrains only **as a pair** | `Person.java:167-171`; `PersonContact.java:103-108`; `Organization.java:114-118`; `BillingInvoice.java:122-127` | **No** — no test persists a shared identification or billing item |
| DM-07 | A join table whose inverse column targets a non-key column of a versioned entity, so one logical row fans out to every version | `Notification.java:158-162` against `EcmFileVersion.java:71-75` and `:146-149` | **No** — notification-with-attachments is not a smoke flow |
| DM-08 | Two `unique = true` claims with no schema constraint behind them, one of them behind a DAO that reads `resultList.get(0)` | `ZylabMatterCreationStatus.java:65`; `AcmOutlookFolderCreator.java:63`, with `JPAAcmOutlookFolderCreatorDao.java:136-146` | **No** — Zylab and Exchange are not in the reference stack |
| DM-09 | **8** `@ManyToOne` and **9** `@ManyToMany` mappings cascade `REMOVE` into shared parents and targets | measured file-by-file below | **No** — no configured test issues a real `EntityManager.remove` |
| DM-10 | Nine `nullable = false` declarations stricter than the column they map | `Category`, `EcmFile`, `ExemptionCode`, `AcmSubscription`, `ExemptionStatute` — lines below | **No** — the constraint that would be violated is in Java, and no test persists these |
| DM-11 | Four numeric widths that differ between Java and the schema, in **both** directions | `AcmQueue.java:66-67`; `AcmProcessDefinition.java:66-67`; `FOIARequest.java:226`; `Transcribe.java:107-108` | **No** — overflow needs production-scale values |
| DM-12 | LOB and temporal metadata drift: `@Lob` over non-LOB columns, CLOB columns without `@Lob`, and `TIMESTAMP` columns on `Date` fields with no `@Temporal` | measured below | **No** — the effective DDL is Liquibase's, and it is unchanged |

Paths, once, so every citation above and below is checkable. All twenty-odd files are byte-identical to the base commit.

| Simple name | Repository-relative path (from the repository root) |
| --- | --- |
| `WidgetRole.java`, `WidgetRolePrimaryKey.java` | `acm-plugins/acm-default-plugins/acm-dashboard-plugin/src/main/java/com/armedia/acm/plugins/dashboard/model/widget/` |
| `OutlookPassword.java`, `AcmOutlookFolderCreator.java` | `acm-services/acm-service-ms-outlook-integration/src/main/java/com/armedia/acm/service/outlook/model/`; the DAO is under `…/dao/impl/JPAAcmOutlookFolderCreatorDao.java` |
| `AcmSequenceEntityId.java`, `AcmSequenceResetId.java`, `AcmSequenceRegistryId.java` | `acm-services/acm-service-sequence-manager/src/main/java/com/armedia/acm/services/sequence/model/` |
| `ComprehendMedical.java`, `ComprehendMedicalEntity.java`, `ComprehendMedicalEntityAttribute.java` | `acm-services/acm-service-comprehend-medical/src/main/java/com/armedia/acm/services/comprehendmedical/model/`; the changelog is `…/src/main/resources/com/armedia/acm/ddl/tables/comprehend-medical-db-tables-1.0.xml` |
| `OCR.java` | `acm-services/acm-service-ocr/src/main/java/com/armedia/acm/services/ocr/model/OCR.java` |
| `Transcribe.java`, `TranscribeItem.java` | `acm-services/acm-service-transcribe/src/main/java/com/armedia/acm/services/transcribe/model/` |
| `MediaEngine.java` | `acm-services/acm-service-media-engine/src/main/java/com/armedia/acm/services/mediaengine/model/MediaEngine.java` |
| `FOIAFile.java`, `FOIARequest.java`, `ExemptionStatute.java` | `acm-standard-applications/acm-foia/src/main/java/gov/foia/model/` |
| `SARFile.java` | `acm-standard-applications/acm-privacy/src/main/java/gov/privacy/model/SARFile.java` |
| `Person.java`, `PersonContact.java`, `Organization.java` | `acm-plugins/acm-default-plugins/acm-person-plugin/src/main/java/com/armedia/acm/plugins/person/model/` |
| `BillingInvoice.java` | `acm-services/acm-service-billing/src/main/java/com/armedia/acm/services/billing/model/BillingInvoice.java` |
| `Notification.java` | `acm-services/acm-service-notification/src/main/java/com/armedia/acm/services/notification/model/Notification.java` |
| `EcmFile.java`, `EcmFileVersion.java` | `acm-services/acm-service-ecm/src/main/java/com/armedia/acm/plugins/ecm/model/` |
| `ZylabMatterCreationStatus.java` | `acm-tool-integrations/acm-zylab-integration/src/main/java/com/armedia/acm/tool/zylab/model/ZylabMatterCreationStatus.java` |
| `Category.java`, `AcmQueue.java` | `acm-plugins/acm-default-plugins/acm-category-plugin/…/category/model/Category.java`; `acm-plugins/acm-default-plugins/acm-case-file-plugin/…/casefile/model/AcmQueue.java` |
| `AcmSubscription.java`, `ExemptionCode.java`, `Note.java` | `acm-services/acm-service-subscription/…/services/subscription/model/`; `acm-services/acm-service-exemption/…/services/exemption/model/`; `acm-services/acm-service-note/…/services/note/model/` |
| `AcmProcessDefinition.java` | `acm-tool-integrations/acm-activiti-configuration/src/main/java/com/armedia/acm/activiti/model/AcmProcessDefinition.java` |
| `UserPreference.java`, `CaseFile.java`, `Complaint.java`, `PostalAddress.java`, `AcmTime.java`, `AcmCost.java` (DM-09 only) | `…/acm-dashboard-plugin/…/dashboard/model/userPreference/`; `…/acm-case-file-plugin/…/casefile/model/`; `…/acm-complaint-plugin/…/complaint/model/`; `…/acm-addressable-plugin/…/addressable/model/`; `acm-services/acm-service-timesheet/…/timesheet/model/`; `acm-services/acm-service-costsheet/…/costsheet/model/` |

#### DM-01 — identities the schema does not enforce

`WidgetRole` declares a two-column composite identity — `@Id @Column("cm_widget_id")` and `@Id @Column("cm_role_name")` under `@IdClass(WidgetRolePrimaryKey.class)` (`:43-58`). The table it maps, created at `dashboard-db-tables-1.0.xml:40-47`, declares those two columns `nullable="false"` and **nothing else**: no `primaryKey` attribute, and no `addPrimaryKey` or `addUniqueConstraint` for `acm_widget_role` anywhere in the repository — only two foreign keys, at `dashboard-db-constraints-1.0.xml:12` and `:15`. `OutlookPassword` is the simpler case: `@Id @Column("cm_user_id")` (`:37-49`) over a table whose only constraint on that column is `nullable="false"` (`outlook-db-tables-1.0.xml:9-14`).

The cost is not a broken query, it is a database that cannot refuse a duplicate. Two rows with the same widget and role, or two password rows for one user, are legal at the storage layer; JPA then resolves the identity to whichever row the provider reads, and its shared cache holds one instance for two rows. The very next changeSet in the same file shows this is an omission and not a convention — `acm_outlook_folder_creator` at `:17-20` does declare `primaryKeyName="pk_acm_outlook_folder_creator"`.

**Why it does not block a validation item.** Items 1 through 3 never open a connection. No configured test persists either entity — the dashboard and Outlook suites mock their DAOs — and the smoke flows for items 4 and 5 are login and rendering, which create no widget-role assignment and no Outlook password.

**What remains for others.** The order is forced and cannot be reversed: **deduplicate first, then constrain**, because adding a primary key to a table that already holds duplicates fails at migration time on a customer database. So this needs a data audit per deployment before a changeSet can be written, which is exactly the shape of work R-6 keeps out of a runtime migration. It is not repaired here — a `addPrimaryKey` changeSet would be a schema change in a migration whose recorded database delta is zero, and it would be untested against any database that has duplicates.

#### DM-02 — composite keys without an equality contract

All four `@IdClass` types are plain field holders with no `equals` and no `hashCode`:

| Key type | Key fields | Used by |
| --- | --- | --- |
| `WidgetRolePrimaryKey` | `roleName`, `widgetId` (`:38-39`) | `WidgetRole` (`:45`) |
| `AcmSequenceEntityId` | `sequenceName`, `sequencePartName` (`:41-43`) | `AcmSequenceEntity` (`:44`) |
| `AcmSequenceResetId` | `sequenceName`, `sequencePartName`, `resetDate` (`:42-46`) | `AcmSequenceReset` (`:50`) |
| `AcmSequenceRegistryId` | `sequenceValue`, `sequenceName`, `sequencePartName` (`:41-45`) | `AcmSequenceRegistryUsed` (`:38`) |

The JPA specification requires an `IdClass` to be `Serializable` and to implement `equals` and `hashCode`; all four satisfy the first and none the second, so they inherit identity comparison from `Object`. Every mechanism that compares keys by value then degrades to reference comparison: `EntityManager.find(Entity.class, key)` with a freshly constructed key, shared-cache and persistence-context lookups, `Map` keys, and `contains`. The usual symptom is not an exception but a redundant database round trip and a second managed instance for one row — which is worse than an error, because it is invisible.

**Why it does not block a validation item.** These paths need a live persistence unit. No configured test constructs one of these keys and calls `find`; items 1 through 3 have no database at all; and the sequence-manager and dashboard flows are not part of the smoke set.

**What remains for others.** This is the one entry in this section whose repair is genuinely self-contained — four `equals`/`hashCode` pairs over declared fields, with a `find`/cache test each. It is still not done here, and the reason is R-6 rather than difficulty: it is a correctness change to production identity semantics with no Java 17 justification, so it belongs to the sequence-manager and dashboard owners as its own reviewed change. QA should pair it with a test that constructs a key by value and expects a single round trip.

#### DM-03 — override annotations that name things that do not exist

Three distinct defects sit in the media-engine hierarchy, and all three are metadata rather than data.

The first is a column name where an attribute name belongs. `@AttributeOverride(name = "class_name", column = @Column(name = "cm_comprehend_medical_class_name"))` at `ComprehendMedical.java:62` — repeated in `OCR.java` and `Transcribe.java` — overrides an attribute called `class_name`. The Java attribute is `className`; `class_name` is the *column* convention. An override that names no existing attribute has nothing to bind to.

The second is an override pair applied to a relationship. `mediaEcmFileVersion` is a `@OneToOne` on the superclass (`MediaEngine.java:71-72`), and the subclasses give it **both** an `@AttributeOverride` (`ComprehendMedical.java:55`) and an `@AssociationOverride` (`:64`) for the same column. `@AttributeOverride` is for basic and embedded attributes; the relationship's join column is `@AssociationOverride`'s job, and the second annotation is the one that is correct here.

The third is field hiding. `MediaEngine` declares `private String className = this.getClass().getName()` at `:74`, and each of the three subclasses declares its own identically-named private field — `ComprehendMedical.java:86`, `OCR.java:88`, `Transcribe.java:114` — each with its own getter and setter. One persistent attribute is modelled twice in one hierarchy, and which one the provider maps depends on how it resolves the hidden field.

**Why it does not block a validation item.** Annotation binding is resolved when the persistence unit is created, and the reference stack does start one — but nothing in items 4 or 5 reads or writes a transcription, OCR job or medical-comprehension record, and those features need AWS credentials the reduced stack does not supply. Items 1 through 3 do not build a persistence unit at all. The coverage that would have caught this is itself compromised for an unrelated pre-existing reason: JaCoCo reports **zero** covered lines for both AWS service implementations, documented in [Coverage integrity for the two PowerMock-prepared AWS classes](#coverage-integrity-for-the-two-powermock-prepared-aws-classes).

**What remains for others.** The three repairs are each small — use `className` in the override, keep only the `@AssociationOverride` for the relationship, and model the attribute once on the superclass — but the third changes which field the provider writes, so it must be paired with a round-trip test per subtype against a real persistence unit. QA needs an environment with AWS credentials to confirm the current behaviour first, which is why this is a handoff and not a fix.

#### DM-04 — two lifecycles over the same rows

`FOIAFile` maps `acm_exemption_code` and `acm_exemption_statute` as collections of strings (`:58-66`), and `SARFile` maps the first of them the same way (`:57-60`):

```java
@ElementCollection
@CollectionTable(name = "acm_exemption_code", joinColumns = @JoinColumn(name = "cm_file_id", referencedColumnName = "cm_file_id"))
@Column(name = "cm_exemption_code")
private List<String> exemptionCodes;
```

Both tables are also mapped as **full entities**. `ExemptionCode` has a generated `@TableGenerator` id, `cm_exemption_created`, `cm_exemption_creator`, `cm_exemption_modified`, `cm_exemption_modifier`, `cm_exemption_status`, `cm_parent_object_id`, `cm_parent_object_type`, `cm_file_version` and `cm_exemption_code_number`; `ExemptionStatute` is its sibling. An `@ElementCollection` owns its rows completely: it deletes and reinserts the collection table's contents for the owning key on update. So writing the string list discards every one of those columns for that file — the generated identity a `ExemptionCode` row was created with, its audit trail, its status and its ordinal — and the entity-side code that reads them, including `ExemptionCodeDao` and `DocumentExemptionServiceImpl`, then sees rows it did not create with the metadata it depends on set to whatever the insert defaulted to.

**Why it does not block a validation item.** Both classes are extension-profile entities: `FOIAFile` is a `@DiscriminatorValue` subclass registered under `extension-foia` and `SARFile` under `extension-privacy`. The reference stack runs `spring.profiles.active=ldap` — the core profile — so neither is instantiated, and no smoke flow uploads a file with exemption codes. No configured test persists either collection.

**What remains for others.** The choice between the two repairs the review names — map an entity relationship, or expose the values read-only — is a decision about which side *owns* the rows, and that is a FOIA/privacy data-model question with an upgrade path attached, because existing rows already carry the entity-side metadata. QA must exercise a document-exemption round trip on an extension-profile environment to establish what today's behaviour actually does to those columns. Not repaired here: it changes persistence behaviour for real customer data.

#### DM-05 — a cardinality only Java believes in

`ComprehendMedicalEntity` requires its parent (`:64-66`) and `ComprehendMedicalEntityAttribute` requires its own (`:60-62`):

```java
@ManyToOne(cascade = { CascadeType.REFRESH, CascadeType.DETACH, CascadeType.PERSIST }, optional = false)
@JoinColumn(name = "cm_comprehend_medical_id", nullable = false)
private ComprehendMedical comprehendMedical;
```

The changelog says the opposite twice. `acm_comprehend_medical_entity.cm_comprehend_medical_id` is declared `nullable="true"` (`comprehend-medical-db-tables-1.0.xml:73-75`, inside the createTable at `:69`) and `acm_comprehend_medical_entity_attribute.cm_comprehend_medical_entity_id` likewise (`:119-121`, inside the createTable at `:115`). And there is **no foreign key at all**: `grep addForeignKeyConstraint` over the entire comprehend-medical resource tree returns nothing, so neither the nullability nor the referential integrity Java assumes is enforced. Orphans and null parents are legal in storage and will fail on read, when the provider materialises a mandatory relationship it cannot satisfy.

**Why it does not block a validation item.** The same AWS dependency as DM-03: the feature is unreachable on the reduced stack, and no configured test persists these entities.

**What remains for others.** Both directions of repair are open — add the FK and the NOT NULL constraints, or relax Java to `optional = true` on R-7 grounds — and choosing needs production data: if any deployment holds rows with a null parent, the constraint cannot be added until they are cleaned, and if none does, the Java side is simply documenting an invariant the schema forgot. That audit is a QA and DBA task per deployment. Not repaired here for the same reason as DM-01: it is DDL.

#### DM-06 — uniqueness claimed on one column, enforced on the pair

Four `@JoinTable` mappings mark the **inverse** join column unique:

| Owning side | Join table | Java claim | What the schema actually constrains |
| --- | --- | --- | --- |
| `Person.identifications` (`:167-171`) | `acm_person_identification` | `cm_identification_id` unique | `addPrimaryKey columnNames="cm_person_id, cm_identification_id"` — `person-db-tables-1.0.xml:547` |
| `PersonContact.identifications` (`:103-108`) | `acm_person_cntct_ident` | `cm_identification_id` unique | `addUniqueConstraint columnNames="cm_person_contact_id, cm_identification_id"` — `person-contact-db-tables-1.0.xml:88` |
| `Organization.identifications` (`:114-118`) | `acm_organization_identification` | `cm_identification_id` unique | `addUniqueConstraint columnNames="cm_organization_id, cm_identification_id"` — `organization-db-tables-1.0.xml:114` |
| `BillingInvoice.billingItems` (`:122-127`) | `acm_billing_invoice_item` | `cm_billing_item_id` unique | `addUniqueConstraint columnNames="cm_billing_invoice_id, cm_billing_item_id"` — `billing-invoice-db-tables-1.0.xml:107` |

In every case the schema forbids the *same pair* twice and permits one identification or billing item to be linked from several owners. All four Java mappings are `@OneToMany … orphanRemoval = true` or its equivalent, which is the shape of exclusive ownership, so the mapping and the schema encode two different relationships: exclusive in Java, shared in the database. If a row ever is shared, `orphanRemoval` deletes it out from under the second owner.

**Why it does not block a validation item.** `unique = true` on a `@JoinColumn` is DDL-generation metadata, and `generateDdl` is `false`, so it is inert at runtime — nothing validates it against the table. No configured test persists a shared identification or billing item, and items 4 and 5 do not create either.

**What remains for others.** The question to settle first is whether sharing is intended, because the two answers lead opposite ways: add per-column unique constraints after a duplicate analysis, or map many-to-many and drop `orphanRemoval`. The person and billing owners have to answer it, and a duplicate analysis per deployment has to precede either. Not repaired here: both branches change either the schema or the delete semantics of customer data.

#### DM-07 — a join that multiplies by version count

`Notification` maps its attachments as a many-to-many over `acm_notification_files` (`:158-162`), and the inverse join column is `cm_file_id`:

```java
@ManyToMany(cascade = { CascadeType.MERGE, CascadeType.PERSIST })
@JoinTable(name = "acm_notification_files", joinColumns = {
        @JoinColumn(name = "cm_notification_id", referencedColumnName = "cm_notification_id") }, inverseJoinColumns = {
                @JoinColumn(name = "cm_file_id", referencedColumnName = "cm_file_id") })
private List<EcmFileVersion> files;
```

The target is `EcmFileVersion`, whose primary key is `cm_file_version_id` (`:71-75`). `cm_file_id` is not its key — it is the foreign key of its own `@ManyToOne file` relationship (`:146-149`), and a file has one row in `acm_file_version` **per version**. Joining on it therefore resolves one stored link to *every* version of that file: a notification about a document on its fourth revision yields four `EcmFileVersion` instances where one was stored, and which of them the code treats as "the" attachment is arbitrary. The join table itself offers no protection — `notification-db-tables-1.0.xml:216-221` declares `cm_notification_id` NOT NULL, `cm_file_id` nullable, and no primary key, unique constraint or foreign key.

**Why it does not block a validation item.** Notification-with-attachment is not a smoke flow, and no configured test persists the join. Items 1 through 3 execute no SQL.

**What remains for others.** Both candidate repairs — target `EcmFile` identity, or store and join `cm_file_version_id` — require a data migration of existing `acm_notification_files` rows, because the stored value has to be reinterpreted or translated. That makes it a schema-and-data change for the notification owner. QA can confirm the fan-out cheaply on any instance with a multi-version document attached to a notification. Not repaired here.

#### DM-08 — two uniqueness claims with nothing behind them, and one that does have a constraint

This is the entry where the review's reading needed correcting, and the correction narrows it rather than dismissing it.

`ZylabMatterCreationStatus` marks two columns unique: `cm_matter_name` (`:62`) and `cm_zylab_id` (`:65`). The first **is** enforced — `zylab-integration-database-tables.xml` declares `unique="true" uniqueConstraintName="uk_matter_name"` in *both* createTable variants, at `:12` for `mysql` and `:30` for `oracle,postgresql,mssql`. So that half of the finding does not stand. `cm_zylab_id` is the real one: it is plain `LONG` with no constraint in either variant.

`AcmOutlookFolderCreator.systemEmailAddress` is the second real one (`:63`). Its column is created with `nullable="false"` only (`outlook-db-tables-1.0.xml:21-22`), and the only unique constraint the Outlook module adds anywhere is on a different table — `addUniqueConstraint tableName="acm_outlook_object_reference" columnNames="cm_object_type, cm_object_id"` at `outlook-db-constraints-1.0.xml:9`. The DAO then makes the consequence concrete rather than theoretical: `JPAAcmOutlookFolderCreatorDao.java:136-146` queries by system e-mail address, takes `getResultList()` and reads `resultList.get(0)` — code that tolerates duplicates by silently choosing one, which is exactly what a missing unique constraint produces under concurrent creation.

**Why it does not block a validation item.** Neither Zylab nor Exchange is part of the reference stack — [the smoke evidence](smoke-evidence.md) records the reduced service set — and no configured test persists either entity.

**What remains for others.** Deduplicate then constrain, in that order, for the same reason as DM-01. The `resultList.get(0)` is worth a second look at the same time, because a unique constraint turns its silent choice into a `NonUniqueResultException` that the current code is not written to expect. Not repaired here: DDL plus a DAO behaviour change.

#### DM-09 — cascade `REMOVE` into shared parents and targets

Measured across every entity in the reactor: **8** `@ManyToOne` and **9** `@ManyToMany` mappings carry `CascadeType.REMOVE`, either explicitly or through `CascadeType.ALL`.

| Side | Mapping | Cascade reaches |
| --- | --- | --- |
| `@ManyToOne` | `Category.java:95` | the parent `Category` |
| `@ManyToOne` | `UserPreference.java:61`, `:65`, `:69` | shared dashboard reference data |
| `@ManyToOne` | `CaseFile.java:267`, `:281` | shared case-file parents |
| `@ManyToOne` | `AcmTime.java:81`, `AcmCost.java:74` | the parent timesheet / costsheet |
| `@ManyToMany` | `Complaint.java:218` | shared targets |
| `@ManyToMany` | `PostalAddress.java:125` | shared targets |
| `@ManyToMany` | `Person.java:150`, `:155`, `:172` | postal addresses, contact methods, and — at `:172`, with `REMOVE` written out explicitly — `Organization` |
| `@ManyToMany` | `PersonContact.java:110`, `:116` | postal addresses, contact methods |
| `@ManyToMany` | `Organization.java:119`, `:124` | shared targets |

`REMOVE` on the *many* side of a `@ManyToOne` means deleting one child deletes its parent, and every sibling child with it. On a `@ManyToMany` it means deleting one side deletes the shared rows the other side still references. `Person.java:172` is the clearest case, because its cascade list is written out — `DETACH, MERGE, REFRESH, REMOVE` — so removing a person cascades into the organisations they were associated with.

**Why it does not block a validation item.** No configured test issues a real `EntityManager.remove` through these mappings; the service-layer suites mock their DAOs. Items 1 through 3 have no database, and no smoke flow deletes a person, case file, timesheet or costsheet.

**What remains for others.** The repair is directional — remove `REMOVE` from the shared sides and cascade only what is genuinely owned — but each of the seventeen needs its own ownership judgement, and getting one wrong in either direction either orphans rows or destroys shared data. That is a data-model review for the plugin owners, not a sweep. QA should probe the highest-risk pair first: deleting a person that shares an organisation, and deleting an `AcmTime` entry that shares a timesheet. Not repaired here, and this is the entry where the case for R-6 is strongest: a cascade change is indistinguishable from a runtime migration in a diff, and its failure mode is deleted customer data.

#### DM-10 — nine `nullable = false` declarations stricter than their columns

| Attribute | Java | Column and what the changelog declares |
| --- | --- | --- |
| `Category.status` | `nullable = false` (`Category.java:117`) | `cm_category_status VARCHAR(32)` with only a check constraint on its three values — `category-db-tables-1.0.xml:30-31` |
| `EcmFile.duplicate` | `nullable = false` (`EcmFile.java:220`) | `cm_file_is_duplicate VARCHAR(32) defaultValue="false"`, no NOT NULL — `file-db-tables-1.0.xml:763` |
| `ExemptionCode.created`, `.creator`, `.modified` | `nullable = false` (`ExemptionCode.java:78`, `:82`, `:94`) | declared with no `<constraints>` at all |
| `AcmSubscription.objectTitle` | `nullable = false` (`AcmSubscription.java:75`) | `cm_object_title VARCHAR(2048)`, added later with no NOT NULL — `subscription-db-tables-1.0.xml:184` |
| `ExemptionStatute.created`, `.creator`, `.modified` | `nullable = false` (`ExemptionStatute.java:72`, `:76`, `:79`) | declared with no `<constraints>` — `exemption-statute-db-tables-1.0.xml:16-20` and `:36-40` |

The direction matters: Java is the stricter side, so the database will accept a null that the ORM refuses to read back, and the failure surfaces on read rather than on write. `nullable = false` is also DDL-generation metadata, and with `generateDdl=false` it is not enforced at insert time by the provider either.

**Why it does not block a validation item.** No configured test persists or reads these attributes against a real provider, and none of the five entities is touched by a smoke flow. The columns are legitimately populated by the application in normal operation, which is why the mismatch has never been felt.

**What remains for others.** Forward NOT NULL constraints after a null audit, or relaxing the annotations on R-7 grounds — and the audit has to come first, per deployment, because `addNotNullConstraint` fails on existing nulls. Owner: whoever schedules the schema-maintenance change that DS-02 also needs.

#### DM-11 — four numeric widths that differ, in both directions

| Attribute | Java type | Column type | Direction of risk |
| --- | --- | --- | --- |
| `AcmQueue.displayOrder` (`AcmQueue.java:66-67`) | `Integer` | `cm_display_order NUMBER(16,0)` — `acm-case-file-tables-1.0.xml:470` | Schema wider: a stored value beyond `Integer` range fails on read |
| `AcmProcessDefinition.version` (`:66-67`) | `int` | `cm_pd_version NUMBER(16,0)` — `acm-process-definition-db-tables-1.0.xml:16`, `:59` | Schema wider, same direction |
| `FOIARequest.ttcOnLastRedirection` (`:226`) | `Integer` | `fo_ttc_on_last_redirection LONG` — `foia-request-db-tables-1.0.xml:706`, `:715` | Schema wider, same direction |
| `Transcribe.wordCount` (`Transcribe.java:107-108`) | `long` | `cm_transcribe_word_count INTEGER` — `transcribe-db-tables-1.0.xml:31` | **Schema narrower**: a Java value beyond `INTEGER` range fails on *write* |

The last row is the one worth separating out, because it is the opposite failure and the opposite fix: three of the four risk an unreadable row, and the fourth risks a rejected insert. None is reachable without production-scale values — a display order, a process version and a redirection count are small by construction, and a transcription word count would have to exceed two billion.

**Why it does not block a validation item.** No test supplies a boundary value, and no smoke flow writes any of the four. Items 1 through 3 never bind a parameter.

**What remains for others.** Aligning the widths is a schema change (or a Java type change, which alters an API type on `FOIARequest` and `Transcribe`), so it belongs in an approved migration with the range audit attached. Owner: the case-file, Activiti-configuration, FOIA and transcribe owners respectively — it is four separate small decisions rather than one.

#### DM-12 — LOB and temporal metadata drift

Three measured classes, and the counts here are this register's own rather than the review's, with the method given so they can be reproduced.

**`@Lob` over a column that is not a LOB — two.** `Note.note` is `@Lob` (`Note.java:75-77`) over `cm_note_text VARCHAR(4000)` (`note-db-tables-1.0.xml:11`, `:44`), and `EcmFile.description` is `@Lob` (`EcmFile.java:185-187`) over `cm_file_description VARCHAR(1024)` (`file-db-tables-1.0.xml:560`). The review reported one; the second was found by matching every `@Lob` in the reactor against its column's declared type. Neither is harmful with `generateDdl=false` — the provider treats the value as a LOB on a column that is not one, and a `VARCHAR` round trip is what actually happens — but `Note.note` in particular is a note body constrained to 4,000 characters by a schema its own mapping says is unbounded.

**A CLOB column with no `@Lob` — eight unambiguously, ten on a looser boundary.** The eight whose column is declared `CLOB` in the single changeSet that creates it: `FOIARequest.requestAmendmentDetails` (`:183`); `Notification` `cm_email_addresses` (`:149`), `cm_email_content` (`:155`), `cm_subject` (`:167`), `cm_cc_email_addresses` (`:173`) and `cm_bcc_email_addresses` (`:176`); and `AuthenticationToken` `cm_authentication_token_relative_path` (`:88`) and `cm_authentication_token_generic_path` (`:91`). Two more qualify if `TEXT`-on-MySQL counts as CLOB-equivalent: `UserAccessToken.value` and `.userIdToken`, whose column is `TEXT` in the `dbms="mysql"` changeSet and `VARCHAR(2560)` in the other. **The review's figure was nine, which is neither of these boundaries** — recorded here as a disagreement rather than reconciled away, because the reproducible statement is the method and the eight names.

**A `TIMESTAMP` column on a `Date` field with no `@Temporal` — exactly four**, which does agree with the review: `EcmFileVersion.mediaCreated` (`:119`), `Notification.actionDate` (`:137`), `TranscribeItem.created` (`:104`) and `TranscribeItem.modified` (`:110`). Without `@Temporal`, the temporal precision is provider-determined rather than declared, so a time component can be silently dropped or kept depending on the provider version — which is exactly the kind of thing a runtime move must not be allowed to change quietly, and it is worth recording that it did not: all four fields, and all four columns, are byte-identical to the base commit.

**Why none of it blocks a validation item.** The effective DDL is Liquibase's and it is unchanged, so none of this metadata affects the schema. Nothing in the configured suite round-trips these attributes through a real provider.

**What remains for others.** Aligning the metadata is safe in the `@Lob` and CLOB cases and needs care in the temporal ones, because adding `@Temporal(TemporalType.TIMESTAMP)` makes explicit whatever the provider was doing implicitly, and the two may differ. R-7 gives the tie-breaker — capture the Java 8 base-commit round-trip behaviour of those four fields *first*, then annotate to match it — and that capture needs a live persistence unit, which is a QA task. Not repaired here.


### Cross-DBMS DDL — two defects that only a non-MySQL deployment can feel

The changelogs are written for four platforms, and the two defects here are invisible on the one this migration was validated against. `docs/setup.md` and the project's own setup direction name MySQL/MariaDB as the supported database and say plainly not to use PostgreSQL, so nothing in the five validation items exercises the Oracle, PostgreSQL or SQL Server paths. That makes these the two entries on this page whose absence of consequence is a property of the *environment* rather than of the code — and the one place where "does not block a validation item" is the weakest reassurance on the page, which is why both are stated at full strength.

| ID | Defect | Location | Blocks a validation item? |
| --- | --- | --- | --- |
| DD-01 | The `UserAccessToken` entity maps `cm_expiration_in_sec`; the Oracle / PostgreSQL / SQL Server changeSet creates `cm_expiration_in_sex` | `UserAccessToken.java:64-65` against `user-service-database-tables.xml:663` (`dbms="mysql"`) and `:687` (`dbms="oracle,postgresql,mssql"`) | **No** — the reference stack is MariaDB, which runs the correctly-spelled changeSet |
| DD-02 | 45 changeSets select PostgreSQL with `postgres`, which is not a Liquibase short name, so PostgreSQL silently skips them | 7 changelogs, enumerated below | **No** — same reason; and PostgreSQL is explicitly out of the supported set |

#### DD-01 — one letter, on three platforms out of four

`UserAccessToken` maps its expiry as:

```java
@Column(name = "cm_expiration_in_sec")
private Long expirationInSec;
```

`user-service-database-tables.xml` creates the table twice, once per platform group, and the two spellings differ:

| changeSet | `dbms` | Column created |
| --- | --- | --- |
| `40-create-acm_user_access_token-table` (`:652`) | `mysql` | `cm_expiration_in_sec` (`:663`) |
| `02-create-acm_user_access_token-table` (`:676`) | `oracle,postgresql,mssql` | **`cm_expiration_in_sex`** (`:687`) |

Everything else about the two changeSets matches — same primary key, same `addUniqueConstraint` on `cm_user_email,cm_provider`, same `NOT NULL` on the expiry column — which is what identifies the difference as a transposition rather than a deliberate platform variation. On Oracle, PostgreSQL or SQL Server the entity therefore references a column that does not exist, and the failure is not subtle: every read or write of `UserAccessToken` fails once the persistence unit resolves the mapping, so **OAuth2 access-token persistence is broken outright on those three platforms**. The column is also `NOT NULL` on both sides, so a caller cannot avoid it.

**Why it does not block a validation item.** The reference stack runs MariaDB 10.6, which selects the `dbms="mysql"` changeSet and gets the correctly-spelled column. Items 1 through 3 never touch a database at all; items 4 and 5 run against that MariaDB instance, and the login flow they exercise is LDAP form-post, not OAuth2. So the migration's evidence base cannot see this defect even in principle.

**What remains for others.** A data-preserving forward rename — `renameColumn` guarded on the misspelled column existing, restricted to the three affected platforms — plus the checksum strategy DS-02 also needs, because the original changeSet must not be edited in place on a database that already ran it. QA must confirm it on an Oracle, PostgreSQL or SQL Server instance, which is the only place the current behaviour is observable, and should treat OAuth2 login on a non-MySQL deployment as untested rather than working. It is not repaired here for the reason every DDL entry on this page is not: the schema and the effective DDL are on the preservation list, and the recorded database delta of this migration is zero.

#### DD-02 — `postgres` is not a Liquibase short name

Liquibase resolves a `dbms` attribute against each database implementation's **short name**, and the value for PostgreSQL is `postgresql`. Measured directly against the version this build pins — `liquibase-core` 3.1.1, taken from the build's own dependency set — by asking it to enumerate its implementations:

```text
shortName=oracle      class=OracleDatabase
shortName=postgresql  class=PostgresDatabase
shortName=mysql       class=MySQLDatabase
shortName=mssql       class=MSSQLDatabase
```

`postgres` matches none of them. A `dbms` list that names it therefore excludes PostgreSQL rather than including it, and the changeSet is skipped without an error — which is the property that makes this worse than a syntax mistake: a fresh PostgreSQL schema comes up looking successful, with columns and tables missing.

Measured across the repository, `dbms="…postgres"` with no `ql` appears in **45 changeSets across 7 changelogs**, carrying **81** schema operations against **11** tables and **95** distinct column identifiers:

| Changelog | changeSets | changeSet lines |
| --- | ---: | --- |
| `foia-request-db-tables-1.0.xml` | **32** | `:5` through `:945` |
| `privacy-request-db-tables-1.0.xml` | 6 | `:6`, `:89`, `:104`, `:119`, `:157`, `:177` |
| `billing-invoice-db-tables-1.0.xml` | 2 | `:40`, `:75` |
| `exemption-db-tables-1.0.xml` | 2 | `:5`, `:60` |
| `billing-item-db-tables-1.0.xml` | 1 | `:48` |
| `exemption-statute-db-tables-1.0.xml` | 1 | `:5` |
| `note-db-tables-1.0.xml` | 1 | `:38` |

The 11 tables are `acm_case_file`, `acm_file`, `acm_file_version`, `acm_person`, `acm_note`, `acm_billing_invoice`, `acm_billing_item`, `acm_exemption_code`, `acm_exemption_statute`, `acm_response_installment` and `foia_file_exemption_code` — so on PostgreSQL the FOIA and privacy extensions lose most of their case-file, file and person columns, and the core `acm_note` table loses its Oracle/PostgreSQL creation entirely.

The typo is demonstrably a typo rather than a convention, and the proof is inside a single file: `note-db-tables-1.0.xml` writes `dbms="oracle,postgres"` at `:38` and `dbms="oracle,postgresql,mssql"` at `:126`. Both spellings, same changelog, same table.

**Why it does not block a validation item.** No validation item runs PostgreSQL. The reference stack is MariaDB, and the project's setup direction states that PostgreSQL is not to be used — so this is skipped rather than exercised, and it always has been, on both sides of the migration.

**What remains for others.** Correcting the selector in place is exactly the operation DS-02's measurement showed to be dangerous: a `dbms` attribute is part of the changeSet body a checksum covers, so editing 45 of them invalidates 45 checksums on every already-migrated database, and each one would need a `validCheckSum` entry or an equivalent strategy. The forward-compatible route is new changeSets that add what PostgreSQL skipped, guarded on absence — which requires knowing what a real PostgreSQL deployment currently has, and there is no such deployment to inspect from here. So the handoff is concrete: **PostgreSQL fresh-schema behaviour should be treated as broken, not merely untested**, and closing it needs a DBA-owned schema-maintenance change validated against both a clean and an upgraded PostgreSQL database. Nothing is repaired here, and every one of the 7 changelogs is byte-identical to the base commit.


### Credentials persisted in recoverable form — REQUIRED HUMAN ACTION

**This subsection is not like the rest of the database section.** Everything above it is a defect that is safe to leave alone until somebody schedules it. These three are not: they are bearer credentials — an e-mail/WOPI ticket, live OAuth2 access and ID tokens, and password-reset and portal account-action keys — held in the database in a form that anyone with read access can replay, and in two of the three cases written into log output as well. Documenting them changes nothing about that exposure.

They are registered rather than repaired for reasons that hold absolutely and are worth stating before the entries, because the disposition is **escalation, not acceptance**:

- **AAP §0.2.4.2** lists *"Security and permission-evaluation outcomes"* among the preservation mandates and states that *"modification of any of these is a defect, not a scope choice."* Hashing a stored token changes an authentication outcome by construction — every token issued before the change stops validating.
- The three schemas involved are also on that same preservation list, and every repair here needs a column change: a digest is a different width and a different value than the token it replaces.
- **The remediation that actually reduces exposure cannot be performed from inside a repository at all.** Revoking and rotating live tokens happens in the issuing systems and in the `acm_authentication_token`, `acm_user_access_token` and user/portal tables of each deployment. No commit does it.

A fourth entry, DC-04, is included because it sits on the same seam and would otherwise look like an omission, but it is a *latent* hardening item with no reachable caller and is explicitly not in the same class as the first three.

| ID | Finding | Location | Blocks a validation item? |
| --- | --- | --- | --- |
| DC-01 | The e-mail / WOPI authentication ticket is stored in plaintext and written to `trace` and `warn` log output on four paths | `AuthenticationToken.java:76-77`; `AuthenticationTokenService.java:201`, `:206`, `:211`, `:221`; `AcmBasicAndTokenAuthenticationFilter.java:145`, `:149`, `:191-192`, `:196-197`; `authenticationtoken-db-tables-1.0.xml:29`, `:76` | **No** — the smoke flow authenticates by LDAP form-post; no validation item issues or replays a ticket |
| DC-02 | Live OAuth2 **access** and **ID** tokens are stored in plaintext | `UserAccessToken.java:55-59`; `AcmOAuth2AccessTokenService.java:118-127`; `user-service-database-tables.xml:657`, `:681` for the access token and `:719`, `:728` for the ID token | **No** — OAuth2 is not exercised; the reference stack logs in over LDAP |
| DC-03 | Password-reset and portal registration/reset keys are stored in plaintext, logged at **error** level, and returned by `toString()` | `PasswordResetToken.java:45-46`; `UserDao.java:264`; FOIA and privacy `UserResetRequestRecord` / `UserRegistrationRequestRecord`; `user-service-database-tables.xml:461`; `foia-request-db-tables-1.0.xml:541`, `:567` | **No** — no reset or portal-registration flow is in the smoke set |
| DC-04 | A public mutable descriptor is concatenated into a table identifier, in a class whose Javadoc claims it prevents exactly that | `ListOfValuesService.java:42-52`; `LookupTableDescriptor.java:30-47` | **No** — and no production caller and no untrusted path currently reach it |

#### DC-01 — the e-mail and WOPI ticket

The token is the credential, and it is stored as itself: `@Column(name = "cm_authentication_token_key", nullable = false, insertable = true, updatable = false) private String key` (`:76-77`), over `VARCHAR(1024)` (`authenticationtoken-db-tables-1.0.xml:29` for one platform group and `:76` for the other). `AuthenticationTokenService.validateToken` then compares the presented token to the stored one directly — `!token.equals(authenticationToken.getKey())` — so a database read is sufficient to authenticate as the token's creator until it expires.

The log exposure is the part that widens the blast radius beyond database access, and there are six sites across two files:

| Site | Level | What it emits |
| --- | --- | --- |
| `AuthenticationTokenService.java:201` | `trace` | the token, when it does not exist |
| `AuthenticationTokenService.java:206` | `trace` | the token, when it is not active |
| `AuthenticationTokenService.java:211` | `trace` | the token, on a key or path mismatch |
| `AuthenticationTokenService.java:221` | **`warn`** | the token **and** the creator, on expiry |
| `AcmBasicAndTokenAuthenticationFilter.java:145`, `:149` | `trace` | the `acm_ticket` before and after successful authentication |
| `AcmBasicAndTokenAuthenticationFilter.java:191-192`, `:196-197` | `trace` / **`warn`** | the `acm_wopi_ticket` with the user, on success and on failure |

Two of the six are at `warn`, which is on in ordinary production configurations — so a live, unexpired-until-checked ticket and the identity it belongs to reach the application log without anyone raising the log level. And an expired-token `warn` still prints a token that may be valid elsewhere, since expiry is evaluated per record.

**Why it does not block a validation item.** Item 5's login flow is `POST /arkcase/login_post` with LDAP credentials, as [the smoke evidence](smoke-evidence.md) records; no smoke flow generates an e-mail link or a WOPI session, so no ticket is issued, stored or logged. Items 1 through 3 do not run the application.

**What a human must do**, in this order, because only the first step reduces exposure:

1. **Treat every row in `acm_authentication_token` on every deployment as disclosed**, and revoke or expire them. They are bearer credentials for file download and WOPI editing, and the application logs may hold copies.
2. **Redact the six log sites.** This is the one part that is genuinely low-risk and behaviour-preserving — logging a token identifier or a hash prefix instead of the token changes no authentication outcome. It is still not done here, because it is a security change to production code with no Java 17 justification, and R-6 admits a carve-out only for a defect that blocks a validation item.
3. **Store a keyed digest** and compare digests, which is the real repair. It needs a column change, a validation-path change and a decision about existing rows — they cannot be migrated, only invalidated — so it is a security change with its own review and its own upgrade note.

#### DC-02 — live OAuth2 access and ID tokens

`UserAccessToken` stores both credentials verbatim: `cm_value` for the access token (`:55-56`, `nullable = false, updatable = false`) and `cm_user_id_token` for the OpenID Connect ID token (`:58-59`). `AcmOAuth2AccessTokenService` writes them on every refresh (`:118-127`). Both columns are `TEXT` on MySQL and `VARCHAR(2560)` elsewhere — the access token at `user-service-database-tables.xml:657` and `:681`, the ID token added later at `:719` and `:728`, with its `NOT NULL` subsequently dropped at `:740` and `:745`. An access token is a bearer credential for the upstream provider, so a database read is enough to act as the tenant against that provider for the token's remaining lifetime; an ID token additionally carries identity claims and is not needed after the sign-in it proves.

!!! note "One part of the review's reading did not survive checking, and it narrows this entry"

    The service logs the entity on save — `logger.info("Saving access token [{}]", accessToken)` at `:126`. That looks like a token leak, and it is not: **`UserAccessToken` declares no `toString()`** — `grep -c toString` over the class returns **0** — so the placeholder resolves through `Object.toString()` to a class name and an identity hash. The log line is noise, not disclosure.

    That matters for triage rather than for the verdict. DC-02 is a **storage** exposure only, which makes it narrower than DC-01 and DC-03 and puts the remediation entirely in the database and the provider. It is recorded because a reader who assumed the log leaked would rotate the wrong things first.

**Why it does not block a validation item.** No validation item performs an OAuth2 flow. The reference stack authenticates against the local OpenLDAP over form-post, and no token is ever obtained, so nothing is written to `acm_user_access_token`.

**What a human must do.** Revoke and rotate every stored access token at the issuing provider — that is the step that reduces exposure, and it is outside this repository by definition. Then encrypt the column with managed application keys, and stop retaining the ID token past the sign-in that produced it, since nothing in ArkCase needs it afterwards. Both are schema-and-security changes for the users-service owner. Not repaired here for the reasons stated at the top of this subsection.

#### DC-03 — password-reset and portal account-action keys

Three families of the same defect, and this is the one with the widest exposure surface because it combines plaintext storage, an **error**-level log and `toString()`.

`PasswordResetToken` is an `@Embeddable` on `AcmUser`, generated as `UUID.randomUUID().toString()` with a 24-hour expiry, and stored as itself: `@Column(name = "cm_token", unique = true) private String token` (`:45-46`) over `VARCHAR(255)` (`user-service-database-tables.xml:461`). `UserDao.findByPasswordResetToken` looks a user up by that value and, when it finds none, logs it:

```java
log.error("User with password reset token: [{}] not found!", token);
```

That is `UserDao.java:264`, at **error** level — on by default everywhere — and it fires on the *miss* path, which is exactly the path an attacker probing tokens produces. A valid token presented twice, or a race, also reaches it.

The portal side duplicates the pattern on both extensions. FOIA's `UserResetRequestRecord` stores `cm_reset_key` and its `UserRegistrationRequestRecord` stores `cm_registration_key` — `foia-request-db-tables-1.0.xml:567` and `:541`, both `VARCHAR(128)` — and privacy carries byte-identical twins. Both classes then put the key in `toString()`:

```java
return "UserResetRequestRecord [emailAddress=" + emailAddress + ", resetKey=" + resetKey + ", requestTime=" + requestTime + "]";
```

FOIA at `:150` and privacy at `:150`, with the registration record's equivalent at FOIA `:171-172`. A `toString()` that contains a credential leaks wherever the object is logged, put in an exception message or serialised for diagnostics — which is a much larger surface than any single call site, because it is opt-out rather than opt-in.

**Why it does not block a validation item.** Password reset and portal registration are not smoke flows — [the smoke evidence](smoke-evidence.md) records the reduced set — and the portal records are extension-profile entities that the core `ldap` profile never instantiates. No configured test persists any of them.

**What a human must do.** Expire every outstanding reset and account-action token, in every deployment, first. Then: store keyed hashes and compare hashes; take the key out of both `toString()` implementations on both extensions; and drop the token from the `UserDao` error message, replacing it with a non-reversible correlator. The `toString()` and log changes are the cheap half and are behaviour-preserving; the hashing half invalidates outstanding tokens and needs a column change, so it carries an upgrade note. Owner: the users-service owner for the core half, the FOIA and privacy owners for the portal half. None of it is done here — see the three reasons at the top of this subsection.

#### DC-04 — a latent identifier sink, in a class that promises the opposite

`ListOfValuesService.lookupListOfStringValues` builds a query by concatenating a table name it is handed:

```java
String lookupTableName = StringUtils.trimAllWhitespace(lookupTableDescriptor.getTableName());
List<String> values = getAcmJdbcTemplate().queryForList("SELECT cm_value FROM " + lookupTableName +
        " WHERE cm_status = 'ACTIVE' ORDER BY cm_order", String.class);
```

The only validation is a null-and-empty check on the trimmed name (`:44-48`); there is no allowlist. `LookupTableDescriptor` is a plain mutable bean with a public `setTableName` (`:30-47`), and its class Javadoc states the intent the implementation does not deliver — that plugin authors write a descriptor *"to encapsulate the table name"* and thereby *"prevent SQL injection"*. Encapsulating a string in a setter is not validation, so the guarantee the comment offers is not one the code provides.

**Why it is genuinely different from DC-01 through DC-03, and why it still belongs here.** The concatenated value has no untrusted source today: descriptors are Spring-configured, this is the repository's single production `JdbcTemplate` statement, and the four lookup tables reachable through it are all authorised. So there is no reachable injection path — the review classified it INFO for that reason and this register agrees. What makes it worth recording is the *combination*: a public mutable setter, no allowlist, and a comment that tells the next plugin author the class already protects them. That is how a latent sink becomes a live one, and the failure would look like a configuration change rather than a security regression.

**Why it does not block a validation item.** Nothing about it fails: the four authorised lookup tables resolve and the statement works. It is a hardening item, not a defect in behaviour.

**What remains for others.** Replace the free-form table name with an immutable enum or a registered allowlist **before** any new caller is added, and correct the Javadoc either way so it stops promising a protection that is not implemented. That is a small, self-contained change for the configuration-service owner. It is not done here because it changes a public API shape that plugins extend, with no Java 17 justification.


## Frontend defects — documented, not fixed

All five were verified against the source tree. `Gruntfile.js` has a **zero-byte diff** against the base commit, so its line numbers are identical in both trees; `config/config.js` grew from 140 to 155 lines when the carve-out fix landed, so its numbers are given for the migrated tree with the base-commit line in parentheses.

| Defect | Location | Why it does not block a validation item |
| --- | --- | --- |
| A dead concurrent-task target — `sync-dev` is registered as `['concurrent:default']` while the `concurrent` configuration declares its only target as `default1` | `Gruntfile.js:91` and `:379` | It affects only the `sync-dev` developer-convenience task. No validation item invokes it; the `default` chain at `:376` never touches `concurrent` |
| An eagerly-evaluated path join against a value that can be null — `destPath` is initialised to `null` at `:13` and assigned at `:15` inside a `try` whose `catch` only logs and continues, yet six `path.join(destPath, …)` calls sit in the object literal handed to `grunt.initConfig` and evaluate on every invocation | `Gruntfile.js:104-124`, with `:13-18` | The defect is **latent**: `homedir()` resolves on every supported platform, so the join never receives `null`. Measured on the validated runtime — `homedir()` returns a path and `npm run build` exits 0. Only a host where `homedir()` throws would reach it, and there the `catch`'s stated intent to continue is what the eager joins defeat |
| A lint task that cannot lint JavaScript, and reports success anyway — `lint` is registered as `['jshint', 'csslint']` while the Grunt configuration declares a `csslint` target and **no `jshint` target at all**, so the jshint task aborts with `No "jshint" targets found` and the global force option downgrades that abort to a warning. The plugin is installed and the task is registered; only its configuration is missing | `Gruntfile.js:372`, `:40-47` and `:144` | No validation item invokes `lint` — the `default` chain at `:376` never runs it — so nothing in items 1 through 5 depends on it. The cost is a **false-success gate** rather than a broken build, which is why it is registered here in full rather than noted in passing |
| A loop that iterates the wrapper object rather than its array — `activeProfiles` is `{ profiles: [ … ] }`, and lodash iterates an object's **values**, so `profile` binds to the array and `profile + dir` stringifies it. It works only by accident with a single profile, where `['custom']` stringifies to exactly `custom` | `config/config.js:98` and `:148` (base `:83`, `:133`) | No validation item configures a second profile: the fresh-checkout build this migration validates runs single-profile, so it resolves the same asset paths it always did. **This is not the same as harmless** — a real `extension-foia` or `extension-privacy` deployment runs two profiles and loses assets. The impact is stated in full in [Multi-profile front-end deployments omit extension and custom assets](#multi-profile-front-end-deployments-omit-extension-and-custom-assets) |
| Four discarded non-mutating array concatenations — the results of `jsCustomModules.concat(…)`, `jsCustomDirectives.concat(…)`, `jsCustomServices.concat(…)` and `cssResources.concat(…)` are computed and thrown away | `config/config.js:108`, `:119`, `:130`, `:152` (base `:93`, `:104`, `:115`, `:137`) | The discarded results are additive-only, so the emitted asset set is exactly what it was. Repairing them would *add* files to the bundles, which is a behavioural change the preservation mandate forbids |

The last row is the clearest illustration of why R-6 is the right rule rather than an obstacle: the obvious one-character fix — assigning the `concat` result back — would silently enlarge the shipped bundles. Leaving the defect in place is what keeps the pipeline outputs equivalent.

### `npm run lint` is not a quality gate, and must not be used as one

This one needs its own section, because a command that exits 0 without doing its job is more dangerous than a command that fails: anyone who wires `npm run lint` into a pipeline gets a green light for JavaScript that was never examined.

Measured verbatim on Node v20.20.2 with npm 10.8.2, from the frontend root. **Exit code 0.** The 37 csslint warnings on the single matched file are elided; nothing else is:

```text
> ArkCaseFrontend@0.0.1 lint
> grunt lint

>> No "jshint" targets found.
Warning: Task "jshint" failed. Used --force, continuing.

Running "csslint:all" (csslint) task
Linting modules/core/css/core.css...ERROR
[L80:C13]
WARNING: Values of 0 shouldn't have units specified. …
… 36 further warnings …
>> 1 file lint free.

Done, but with warnings.
```

Three facts, each checkable against the transcript:

- **No JavaScript is linted.** `grunt-contrib-jshint` is installed and the task is registered — `grunt --help` lists it — but `grunt.initConfig` declares only a `csslint` target, so the task has nothing to run and aborts. The abort is real; it is the global `grunt.option('force', true)` at `Gruntfile.js:144` that turns it into a warning and lets the run continue to a zero exit.
- **The CSS that *is* linted cannot fail either.** The `csslint.all` target globs `modules/**/*.css`, which matches exactly one file, and grunt-contrib-csslint at the pinned version only fails on errors — so the same file is reported with 37 warnings and counted as "1 file lint free" in the same breath.
- **The exit code is 0 regardless.** "Done, but with warnings." is a success for every caller that checks a status code.

**And there is no frontend test suite behind it, which is the second half of the same gap.** The frontend root contains **no** spec or test file, no `karma`, `jasmine`, `mocha`, `jest` or `protractor` configuration, and no dependency on any of them — the base commit declared `karma`, `karma-jasmine`, `jasmine-core` and `grunt-karma` while providing no karma target and no karma configuration file, which is why the delivered manifest removes all four as dead packages. The five scripts it publishes are `prebuild`, `build`, `lint`, `sync-dev` and `merge-config`; none of them runs a test, because there is nothing to run. So the whole of the JavaScript application — every module, directive, filter and service under `modules/`, `directives/`, `filters/` and `services/` — has **no automated verification of any kind**: not a test, and per the three facts above, not even a lint. Registering it here is the point; repairing it is a project of its own, and it is not a migration task.

**Why it is documented rather than repaired.** The defect is pre-existing: the `lint` alias at `Gruntfile.js:372`, the missing jshint target and the global force option are all base-commit conditions, and `Gruntfile.js` is held at a **zero-byte diff** by this migration. It blocks no validation item, so **R-6** applies with nothing to weigh against it. What the migration did change is *reachability*: the base commit's `scripts` block was empty, so this migration is the first time the task can be invoked by name — `lint` is one of the five scripts the change set is specified to declare, and dropping it would breach that specification just as surely as pretending the command works would. Recording it here is the honest third option.

**What a real repair would take**, so the next person does not mistake this for a one-line fix: a `jshint` configuration target covering the application JavaScript, plus failure propagation for that target (the global force option has to stop applying to it, or the task needs its own `force: false`), and then the work of actually clearing whatever the newly-enabled target reports across an application tree that has never been linted. That is a code-quality project with its own behavioural risk, not a runtime-migration change — which is exactly why it is scoped out here. Until it is done: **do not treat `npm run lint` as evidence of anything.**

### `npm ls` exits 1 on a healthy tree, and three git dependencies are why

`npm ci` exits 0, `npm run build` exits 0, and the pipeline emits its full bundle set — but `npm ls` exits **1**. A maintainer who reaches for it as a health check will read that as a broken install. It is not.

The tree validation reports exactly three entries as `invalid`, and all three are **git-sourced** dependencies whose resolved commit carries a manifest that does not satisfy the range the spec asks for:

| Dependency | Spec in `package.json` | What the resolved commit's own manifest declares |
| --- | --- | --- |
| `@bower_components/angular-google-analytics` | `revolunet/angular-google-analytics#semver:1.1.8` | name `angular-google-analytics`, version **1.1.7** — the tag was cut without bumping the manifest |
| `@bower_components/angular-pdfjs-viewer` | `legalthings/angular-pdfjs-viewer#semver:^0.8.1` | version **1.0.0**, which is outside `^0.8.1` |
| `@bower_components/pdf.js-viewer` | `legalthings/pdf.js-viewer#semver:^1.6.211` | a **different package name**, `pdf.js-dist`, at version **0.1.0** |

**Why this is pre-existing rather than introduced.** It is the bower-versus-npm semantics gap in its purest form. Bower resolved a `#<range>` spec by matching git **tags** and never looked at the manifest inside; npm resolves the same way once the spec is written `#semver:<range>`, but then *also* validates the fetched manifest's `name` and `version` against the range. The commits are the ones the base commit's `yarn.lock` recorded — all 53 GitHub coordinates match it — so nothing about which bytes ship has changed. What changed is that a tool now checks a claim nobody was checking before, and three upstream repositories fail it.

**Why it does not block a validation item.** Neither validation item runs `npm ls`. `npm ci` installs from the lockfile's resolved commits without re-validating those ranges, which is why it exits 0, and `npm run build` never consults the manifests at all — it reads files from `node_modules` by path. The three packages are present, at the intended commits, and the bundles that include them are byte-identical to the control build.

**Why it is documented rather than fixed.** Every available repair changes what resolves. Pinning each of the three to the exact commit SHA in `package.json` would make `npm ls` clean, but it discards the range the base commit expressed and is a manifest change with no reproduced Node 20 failure behind it, which **R-1** puts out of scope. Moving any of the three to a version whose manifest agrees with its range moves the resolved commit, which **R-7** forbids. The honest position is that the tree is correct and the checker is right to complain about upstream metadata neither this repository nor this migration controls.

**What a maintainer should use instead.** `npm ci` is the integrity gate — it validates every registry entry against its integrity hash and every git entry against its pinned commit, and fails if the lockfile and the manifest disagree. `npm ls` on this tree is only useful with those three names filtered out.

### The module-config copy warning, deliberately not silenced

The final task of the `default` chain writes the module manifest unconditionally at `Gruntfile.js:349`, and its target `modules_config/config/modules.json` (declared at `config/env/all.js:10`) exists only inside the deploy-time assembly folder that the Java resource copier creates. In a bare checkout the write therefore fails, and `grunt.option('force', true)` at `Gruntfile.js:144` absorbs it. Measured verbatim from `npm run build` on Node v20.20.2:

```text
Running "copyToModulesConfigFolder" task
Warning: ENOENT: no such file or directory, open 'modules_config/config/modules.json' Used --force, continuing.

Done, but with warnings.
```

The command exits **0**.

**Why it does not block a validation item.** Validation item 2 requires `npm run build` to exit 0, and it does — the warning is absorbed, every expected artifact is emitted, and the manifest is written for real at deploy time by the code path that owns it. **It is deliberately left unsilenced**, and that choice is the contrast that shows the line in the next section was drawn on purpose rather than by convenience: this warning is adjacent to the one condition that *was* fixed, it is cosmetically annoying in exactly the same way, and it does not block anything, so it stays.

### The renamed front-end install property is a breaking change for out-of-repo extensions

Not a defect and not documented-in-lieu-of-fixing — registered here because it is the one change in this migration that can break a deployment which this repository cannot see.

`AngularResourceCopier`'s `yarnInstallCommand` property is now `npmInstallCommand` (`:603` getter, `:608` setter), and **no alias is kept under the old name**. That is deliberate: **R-4** requires that no yarn invocation survive, and a deprecated `setYarnInstallCommand` would both keep a yarn-named member on the public surface and add a public method the specification does not authorise. Verified at bytecode level by the review that raised it: `setYarnInstallCommand` is absent.

Anything inside this repository is consistent — `spring-web-ark-angular-starter.xml:52` sets the new name. The exposure is entirely external: an extension jar or an operator-managed Spring XML that overrides the `angularResourceCopier` bean and sets `yarnInstallCommand` fails at context refresh with `NotWritablePropertyException: Invalid property 'yarnInstallCommand'`, and the `/arkcase` context does not start. A deployment that never set the property is unaffected.

The upgrade note is published where an operator will meet it rather than only here: the "Upgrading: the front-end install property was renamed" subsection of both `README.md` and `docs/setup.md`, which names the old and new property, the exact exception, and the value ArkCase itself ships.

### `ng-slimscroll` markup survives in 15 views with no provider behind it

Fifteen HTML views write `ng-slimscroll=""` on their scroll container — `templates/home.tpl.html`, twelve module left-sidebar views under the frontend tree, and the `cases.client.view.html` of the `acm-foia` and `acm-privacy` extension resource trees — and **no slimscroll directive is registered anywhere**, so AngularJS silently ignores every one of them. The sidebars use ordinary overflow scrolling.

**Pre-existing, and unchanged.** The same count holds at the base commit: `grep -rl 'ng-slimscroll' --include=*.html .` (excluding `node_modules` and `target`) returns **15** in both trees, and `git diff` reports **zero** changed `.html` files in this change set. No provider was registered at the base commit either, so the markup was already inert before either runtime moved.

**What the migration did change is the dependency, not the markup.** `@bower_components/angular-slimscroll` was removed from `package.json` as one of the fourteen unused asset packages, because nothing required it, no asset list named it and no module registered it. That removal is why this entry exists: with the declaration gone, the surviving markup is the only trace left, and it should not be mistaken for a working feature.

**Why it is documented rather than fixed, in either direction.** Reintroducing the package to make the attribute live would *add* a scrolling behaviour the base commit did not have, which the preservation mandate forbids. Deleting the attribute from 15 views is a client-surface change with no functional gain, and the regression check that certifies the client surface as base-identical would no longer hold. Whoever owns the UI can decide between wiring it up and removing it; neither belongs in a compatibility migration.

### The retained vendored `lib/` tree

Six directories under the frontend root's `lib/` — `acm-json8-patch`, `json8`, `merge-patch`, `merge-patch-to-patch`, `pointer` and `text-sequence`, 130 tracked files — are retained **verbatim**, with a zero-byte diff against the base commit. A careless reading of **R-4** would treat checked-in dependency code as exactly the vendored dead package the rule forbids, so the retention is argued here rather than merely noted.

**Five of the six are vendored third-party code, and calling them first-party would be wrong.** Each carries its own `package.json` naming a published registry package, a version, the ISC licence, a public repository and a single named upstream author:

| Directory | Package | Version | Licence | Upstream repository |
| --- | --- | --- | --- | --- |
| `lib/json8/` | `json8` | 0.9.2 | ISC | `github:JSON8/JSON8` |
| `lib/pointer/` | `json8-pointer` | 0.7.1 | ISC | `github:JSON8/pointer` |
| `lib/merge-patch/` | `json8-merge-patch` | 1.0.0 | ISC | `github:JSON8/merge-patch` |
| `lib/merge-patch-to-patch/` | `json8-merge-patch-to-patch` | 1.0.0 | ISC | `github:JSON8/merge-patch` |
| `lib/text-sequence/` | `json8-text-sequence` | 0.1.0 | ISC | `github:JSON8/text-sequence` |

The sixth, **`lib/acm-json8-patch/`**, is different in kind: 19 files, **no `package.json` at all**, and no registry package of that name — an ArkCase fork of the JSON8 patch implementation with no upstream equivalent, so "replace the vendored copy with a dependency" has no target for it.

The correct classification is therefore **vendored third-party but load-bearing**, not dead weight, and the retention rests on what the code does rather than on who wrote it:

- **Two of the six are load-bearing at build time through relative-path requires.** `Gruntfile.js:227` requires `./lib/acm-json8-patch/apply` and `:228` requires `./lib/json8/lib/clone` — by **path**, not by package name, so `node_modules` is never consulted for them. Adding registry copies would create two divergent implementations of the same code with only the Gruntfile deciding which one runs, which is strictly worse than the status quo.
- **The tree is deployed, not dormant.** `lib` appears on three separate copy lists in `acm-user-interface/ark-angular-starter/src/main/resources/spring/spring-web-ark-angular-starter.xml`, at `:69`, `:80` and `:92`, and it is explicitly whitelisted from the temp-folder prune by the `!p.startsWith(libFolderPath)` filter at `AngularResourceCopier.java:158`.

**Why it does not block a validation item.** Nothing about the tree obstructs items 1 through 5: `npm ci --ignore-scripts` and `npm run build` both exit 0 with it in place, and it is the *removal* that would break the two relative requires. This is retention with a reason, which is what R-4 asks for — the rule's target is dead weight, and dead weight is precisely what this is not. The eight genuinely dead build packages that R-4 *did* reach were removed, and that accounting belongs to [the dependency inventory](dependency-change-inventory.md).

### Deploying twice into a shared temp directory can fail the resource copier's `npm ci`

The deploy-time resource copier installs the frontend into a temp directory under `${HOME}/.arkcase`, and the migration changed the command it runs there from a yarn install to **`npm ci --ignore-scripts`**. `npm ci` deletes `node_modules` wholesale before installing, which is what makes it reproducible — and which also means it needs exclusive use of that directory. Observed once during validation, on a host where more than one application instance shared the same `${HOME}`:

```text
About to run [npm ci --ignore-scripts]
npm error code ENOTEMPTY
npm error syscall rmdir
npm error path <temp>/node_modules/@bower_components/ace-builds/src-min-noconflict
Could not copy Angular resources … Process exited with an error: 217
```

The failure hit only the copier's own child servlet context; the root context and the running UI were unaffected, because the assets were already on disk from the previous deployment.

**This is contention, not a defect in the command**, and the distinction rests on three measurements rather than on argument: the immediately preceding deployment ran the identical command in the identical directory and succeeded; running `npm ci --ignore-scripts` twice in a row over an already-populated `node_modules` in the frontend project root exits **0** both times; and the base-commit `yarn` step failed in that same shared directory **five times** in the equivalent baseline run, so the pre-migration command was no more robust there.

**Why it does not block a validation item.** Item 2 is measured from the frontend project root, where the command exits 0 on a clean tree and on a populated one. The operational consequence, recorded for deployers rather than fixed: give each application instance its own `${HOME}`, or do not deploy two instances concurrently against one.

### Runtime observations from the deployed application

Driving the deployed UI in a browser surfaced five pre-existing conditions that a build-only validation never reaches. All five are properties of the base-commit application, none is related to either runtime move, and none is fixed:

| Observation | Detail | Why it does not block a validation item |
| --- | --- | --- |
| The login form's `pattern` attribute is rejected by current Chrome | The e-mail pattern on the username input contains an unescaped `+-` range inside a character class, which current Chrome's stricter regular-expression parsing refuses; the console logs `Pattern attribute value … is not a valid regular expression` | Cosmetic: the attribute is a client-side hint and login succeeds. Fixing it means editing base-commit markup for a browser-version reason, which is outside this migration's scope |
| `plugin/admin/googleAnalytics/config.js` is refused as a script | The endpoint returns **200** but with `Content-Type: application/json`, and the browser refuses to execute it under strict MIME checking, also logging a cross-origin-read-blocking notice | Non-blocking: analytics simply stays uninitialised. It is a server-side content-type mismatch that predates the migration |
| Some forty `Action … was not found in rules list` warnings, in a session total of 44 warnings across five groups | One per module route during application bootstrap, from the data-access-rules lookup | Non-blocking: every module link still renders and routes. It is a rules-configuration gap in the external configuration, not application code |
| angular-translate reports no sanitisation strategy | `$translateSanitization: No sanitization strategy has been configured. This can have serious security implications.` | A security-hygiene item in base-commit frontend configuration. It is recorded here rather than fixed because changing the sanitisation strategy changes rendered output, which the preservation mandate forbids; it deserves its own review |
| An error notification is painted **behind** the fixed top bar, so a user never sees it | On the `#!/cases` route a `cg-notify-message` with class `alert-danger` is injected about **9.5 s** after route entry, reading *“An exception prevented us from handling your request…”*, measuring **400×98 px at viewport origin (0,0)** — and the opaque `position:fixed; z-index:1000` header occupies y=0..60 above it. `document.elementFromPoint(200, 40)`, a point inside the toast, returns `A.navbar-brand` rather than the toast. It also auto-dismisses within a few seconds and appeared on only **2 of 4** entries into the route | Non-blocking, and the underlying request failure is the absent Solr server rather than a defect. The layering is a base-commit CSS property: the notification library's default placement and the header's `z-index` are both unchanged by this migration. Its practical cost is that a user sees an empty grid with no explanation, which is why it is registered rather than left as an anecdote |

## Frontend-to-API seam defects — documented, not fixed

A dedicated review walked the whole seam between the browser and the backend: **501** HTTP, resource, upload, raw-XHR, beacon and SockJS call definitions plus **5** STOMP subscriptions, mapped against **719** Spring MVC handlers exposing **1,385** route variants. **494 of the 506 definitions line up.** The eight defects below account for the twelve that do not — four of them are one defect repeated across two or four sibling definitions.

Two properties of this set decide its disposition, and both were measured rather than assumed. First, **every one of them is base-commit code**: the review confirmed that all 145 call-bearing frontend files, all 367 route-bearing backend files and all 162 serializer-annotation files are **source-identical to `c8f6226105`**, so not one of these twelve rows is something the migration created, moved or could have avoided. Second, **repairing any of them means adding, removing or re-shaping a route or a call** — which is exactly what the preservation mandate freezes (REST paths, verbs, request and response shapes) and what the exclusion list means by "no new features or endpoints". So R-6 applies with no carve-out available: none of them blocks a validation item, because a compile sees both halves of a seam and agrees with neither, a unit test exercises neither half against the other, and the smoke flows do not reach these particular screen actions.

Each entry states whether the definition has a **live caller**, because that is what separates a user-visible defect from dormant technical debt, and it was checked by searching the application tree with the generated `assets/dist` bundles excluded.

| # | Defect | Location | Live caller? |
| --- | --- | --- | --- |
| 1 | Flat subfolder search sends an extra path segment that no handler matches | `resources/services/ecm/ecm.client.service.js:22-26` against `FolderListAPIController.java:74` | **Yes** |
| 2 | An admin save issues `PUT` against a read-only static resource | `resources/services/config/modules-config.client.service.js:29-32`, called from `application.module.config.module-info.client.controller.js:9`, against the static mapping at `servlet-context.xml:146` | **Yes** |
| 3 | Four `/api/administration/**` actions have no backend route | `resources/services/resource/administration.client.service.js:4-30` | No |
| 4 | A correspondence query list has no backend route | `resources/modules/admin/services/correspondence-management-templates.client.service.js:87-92` | No |
| 5 | A workflow deactivation `PUT` has no backend route | `resources/modules/admin/services/workflows.config.client.service.js:109-117` | No |
| 6 | An invoice-document `PUT` has no backend route, declared twice | `resources/modules/cases/services/case-billing.client.service.js:42-48` and `resources/modules/complaints/services/complaint-billing.client.service.js:42-48` | No |
| 7 | A task-by-user `GET` has no backend route | `resources/services/object/object-task.client.service.js:55-60` | No |
| 8 | A filtered report query sends the wrong parameter name, so the unfiltered overload answers | `resources/modules/admin/services/reports.config.client.service.js:232-242` against `GetReportToRolesMapAPIController.java:91-98` | No |

### The two with live callers

**1 — the extra `folderId` segment.** The client declares `api/latest/service/ecm/folder/:objType/:objId/:folderId/search`, while the only matching handler is `@RequestMapping("/folder/{objectType}/{objectId}/search")` at `FolderListAPIController.java:74`, whose siblings in the same controller take `fq`, `s`, `dir`, `start` and `n` as query parameters and no third path variable. The sibling definition two entries above it in the same client file — `retrieveFolderList` — *does* pass `:folderId` as the last segment and does match its own handler, which is how the extra segment came to be copied onto the search route. A request built from this definition therefore reaches no handler and returns **404**, and the action is live in the document-tree flat-search path.

**2 — a `PUT` against a static resource.** `ConfigService.updateModule` sends `PUT modules_config/config/modules/:moduleId/config.json`, and `servlet-context.xml:146` serves `/modules_config/**` through `<mvc:resources>`, which answers `GET` and `HEAD` only. The caller at `application.module.config.module-info.client.controller.js:9` is the admin module-info save button, so an administrator can edit module configuration, see no error worth acting on, and lose the change. Note the read side of the same service is correct and is what the application depends on for module configuration; only the write side has no target. The Grunt `updateModulesConfig` task and the deploy-time `mergeConfigFrontendTask` are the mechanisms that really do write that tree, at build and deploy time rather than at runtime.

### The six dormant contracts

Entries 3 to 8 define actions that **no code calls**. Entry 3's service is injected by `Admin.ComponentsListController`, but its only call site there is commented out; entries 4, 5, 6 and 7 are exported and never invoked; entry 8's function is defined and unreferenced. They are registered rather than deleted for two reasons. Deleting a definition is a change to the client surface, and the review's own regression check certifies that the client inventory is base-identical — removing eight of them would break that property for no functional gain. And each one records an *intent*: entry 8 in particular is a one-word fix (`fq` → `fn`, the name `GetReportToRolesMapAPIController.java:94` actually binds) that must not be applied until someone decides whether the filtered overload is wanted, because applying it silently switches a future caller from the unfiltered overload at `:72` to the filtered one at `:91`.

**Why none of the eight blocks a validation item.** Item 1 compiles the backend and runs unit tests: neither observes a client route string. Item 2 installs and builds the frontend: Grunt concatenates these files without resolving any URL in them. Item 3 is a text search for JDK-internal APIs. Items 4 and 5 deploy and log in, then exercise the flows listed in [the smoke record](smoke-evidence.md) — none of which opens the document-tree flat search, the admin module-info save, the correspondence query list, workflow deactivation, invoice-document generation, task-by-user or the filtered report query.

**Follow-up condition.** Each of the eight needs a product decision before a code change: define the intended backend contract, or retire the client definition. That is a functional-change project with its own review — the review that raised these findings says so explicitly — and it is deliberately not a compatibility migration's work. What this migration owes them is an accurate register, which is this section.

## The two conditions fixed under the carve-out

Two places in this change set depart from "document, do not fix", and they depart on different grounds, so both are stated unambiguously rather than counted together. The first — the unconditional require described immediately below — is the R-6 carve-out proper: it blocks a named validation item. The second, [the discarded `File.delete()` result in the resource copier](#the-discarded-filedelete-result-in-the-resource-copier-fixed-on-review-recommendation), blocks nothing and is a **deliberate, disclosed departure** from R-6 rather than an instance of its exception.

**The defect.** At the base commit, `config/config.js:16` reads `var activeProfiles = require('./../profiles');` — an **unconditional** top-level require of a generated module. `profiles.js` is not tracked and is not present in a checkout; it exists only in the deploy-time assembly folder, where `AngularResourceCopier.createProfilesJsFileInDir` writes it immediately before invoking Grunt (base `:206-215`, migrated `:234-243`). That require site is the **only** one for the module anywhere in the frontend tree.

**Why it is a permitted fix rather than a violation.** `config/config.js` is loaded by the `loadConfig` task, which is the *first* entry in the `default` chain at `Gruntfile.js:376`. An unresolvable require there aborts the whole run before any task executes, so a bare checkout **cannot run `npm run build` at all**. That directly blocks **validation item 2** — `npm ci --ignore-scripts` then `npm run build` must exit 0 on Node 20 from a fresh checkout — and a defect that blocks a named validation item is precisely the exception R-6 contemplates. Nothing else on this page is in that position.

**The fix, in two parts.**

- A new prebuild helper, `scripts/ensure-profiles.js`, writes `<frontend root>/profiles.js` when and only when it is absent, emitting the **identical manifest** the Java assembler produces and mirroring its single-profile fallback. It is wired as the `prebuild` script, so `npm run build` runs it automatically.
- A **guarded require** at `config/config.js:16-31` defaults to `{ profiles: [ 'custom' ] }`, the exact value the assembler emits for its own single-profile case. The guard is narrow on purpose: only `MODULE_NOT_FOUND` for this file's own require is defaulted, and every other failure is re-thrown, so a generated module that exists but does not parse still surfaces its real error instead of being silently replaced by a single default profile.

A deployed WAR and a bare checkout therefore follow the same code path, and the generated module wins whenever it is present, so deployed behaviour is unchanged. Measured on Node v20.20.2 with npm 10.8.2 from a clean tree: `npm ci --ignore-scripts` exits 0, then `npm run build` reports `ensure-profiles: created …/resources/profiles.js with profiles [ custom ]` and exits 0.

**Scope discipline.** This is the only fix made *under R-6's exception* — the only pre-existing defect in this change set that blocks a named validation item. The module-config copy warning described immediately above is adjacent to it, equally cosmetic and equally easy to silence, and was deliberately left alone; that contrast is the evidence that the line was drawn deliberately rather than stretched to cover whatever was convenient. One further pre-existing defect **is** repaired, on a different and weaker basis, and it is registered in its own entry below rather than folded in here: an earlier revision of this page claimed to be the *only* fix full stop, which was not true.

**One consequence of the fix, disclosed rather than buried.** The frontend root's `.gitignore` lists only `node_modules/` and is unchanged from the base commit, so the generated `profiles.js` lands in the working tree as an **untracked, non-ignored** file. It joins two pre-existing generated paths in the same condition — `assets/dist/` and `home.html`, both written by the base-commit pipeline and neither ignored — so a post-build `git status` shows three untracked generated paths. This blocks no validation item, and it is **not** repaired here: an ignore-rule change is outside this change set, and R-6's carve-out does not extend to it. It does, however, sharpen the warning above — the licence-plugin header injections are not the only thing a blanket `git add -A` would sweep up.

### The discarded `File.delete()` result in the resource copier, fixed on review recommendation

**The defect.** At the base commit, `AngularResourceCopier` pruned the deploy-time temp folder with `.forEach(File::delete)`, discarding every return value. A file the assembly did not copy has been removed from the project, so a survivor means the deployed application serves a resource that is no longer part of it — and because the pipeline runs on regardless, nothing else would ever mention it.

**What was changed.** The terminal operation is now `.forEach(this::deleteStaleTmpFile)` (`:166`), and `deleteStaleTmpFile` (`:210`) logs a warning naming the surviving path. A failed removal is deliberately **not** escalated to a deployment failure, and the distinction is drawn on `File.exists()` rather than on the boolean alone, so a file that was already absent stays silent — refusing to deploy over a stale leftover would be a stricter contract than any release of this class has offered.

**Why this is disclosed as a departure from R-6, not an instance of its exception.** It blocks no validation item. The build passes and the deployment succeeds with the defect in place, so R-6 read strictly says document it and leave it. It is carried because the security review that examined this file recommended exactly this disposition — register it as a deliberate carve-out rather than revert it — and because the delivered `AngularResourceCopierTest` covers the new method, so reverting would mean removing test coverage as well as the repair. The honest summary is that this is a small, well-covered improvement to a file the migration was already editing, kept on the reviewer's recommendation and recorded here so it is not mistaken for something R-6 licensed.

**What it does not fix.** The prune's filters still match by substring rather than by path segment — `!p.contains("node_modules")`, `!p.contains("bower_components")` (`:155`–`:157`) — so an unrelated file whose name merely embeds one of those strings is spared. That is pre-existing, it fails **safe** by over-preserving, and it is left exactly as it was. The migration touched only the adjacent `.endsWith("package-lock.json")` line, which replaced `yarn.lock`.

## Launch-configuration defects in the developer documentation — documented, not fixed

The `setenv.sh` block and the credential sections of `README.md` and `docs/setup.md` are this repository's launch configuration — there is no tracked `bin/setenv.sh`, no Dockerfile and no unit file. Four pre-existing defects live in them. An interim revision of this change set **repaired all four**, replacing the literals with `${ARKCASE_KEYSTORE_PASSWORD:?…}`-style environment lookups and rewriting the credential sections. That work was **reverted**, because AAP §0.4.4 names these exact regions as preserved — "the `CATALINA_OPTS` native-library block and the credential section are untouched", and for `docs/setup.md` "the redacted keystore/truststore placeholders preserved" — and the specification is the frozen agreement, so it outranks an unrequested improvement. All four are therefore base-identical again and registered here.

| # | Where | The defect | Why it is documented rather than fixed |
| --- | --- | --- | --- |
| LC-01 | `README.md`, the `JAVA_OPTS` line of the `setenv.sh` block | A working key-store and trust-store password is published in source control as a literal: `-Djavax.net.ssl.keyStorePassword=password -Djavax.net.ssl.trustStorePassword=password`. `docs/setup.md` carries the same two positions as `<REDACTED>` placeholders instead | AAP §0.4.4 preserves both regions verbatim. Repairing it means changing text the specification freezes, so it needs its own authorised security change. The value is a documented developer default, not a deployment secret, but it should still be rotated before any deployment is reachable |
| LC-02 | Both files, the `JAVA_OPTS` line | `${user.home}` is used four times inside a **shell** script, where it is not shell syntax and will not expand — it is a Tomcat property placeholder that Tomcat expands itself. The base commit's own workaround is the adjacent note telling macOS readers to substitute the literal path by hand | Same preservation mandate. The repair (`${HOME}`) is one token in four places and was implemented and reverted; it is available the moment a plan authorises it |
| LC-03 | `README.md`, the `CATALINA_OPTS` line | The double quote opens and never closes on its own line, so the following `# MacOS Example:` comment is folded into the value: `-Djava.library.path` ends up carrying a newline and a shell comment, and the native library is never found. `docs/setup.md`'s single-line form does not have the defect | Same preservation mandate. This one is a functional defect rather than a hygiene one, so it is the strongest candidate for the follow-up change |
| LC-04 | `README.md`, "Logging into ArkCase" | The default administrator password is published: ``password `@rKc@3e` ``. `docs/setup.md` renders the same credential as `<REDACTED>` but then points the reader at the README for the value, so the redaction is nominal | AAP §0.4.4 names the credential section as untouched. Rotating the provisioned default is a deployment action; removing it from the README is a documentation change that needs its own approval |

**What a maintainer should know.** All four repairs have already been written once and can be recovered from this change set's history rather than re-derived. They belong in one small documentation-and-credentials change, authorised on its own terms, and LC-03 should lead it because it is the only one that breaks something.

## Pre-existing test-quality defects — summary and referral

A code-review pass over the reactor's Java test sources and its test resources raised **137** test-quality findings — **75 major and 62 minor**. The scope it covered is the base commit's **402** Java test sources and **238** test resources; the five Java test classes and the one Node test file this change set *adds* over its own edits are outside that scope and are accounted for in [the baseline record](baseline-test-failures.md). Every one of the 137 lives in a test source or test resource that this migration **never modified**, and that claim is checkable rather than asserted: `git diff c8f6226105..HEAD -- '*src/test*'` lists only the added files and reports no modification to any of the 402, so every base-commit test source is byte-identical, assertions included.

Every one of the 137 lives in a test source or test resource that this migration **never touched**, and that claim is checkable rather than asserted: `git diff --name-status c8f6226105..HEAD -- '*src/test*'` lists **nothing at all** on the delivered tree — no test source added, modified or deleted.

**The per-finding register is not reproduced on this page.** It is a test-quality audit of 137 items across roughly 90 test classes, it names a file and a line for each, and it is owned by the review that raised it rather than by this migration record — publishing a second copy here would guarantee the two drift apart. What this page owes R-6 is the disposition and the reason for it, which is below, plus the honest consequence for how much the green suite proves. The itemised register is available from the review record for this change set.

They are registered unfixed, and the reason is not discretion:

- **AAP §0.2.1.3** states the position without qualification — *"No test source file is modified. All 402 test sources keep their assertions byte-identical."*
- **AAP §0.2.4.2** lists *"Existing test assertions"* among the preservation mandates and adds that *"modification of any of these is a defect, not a scope choice."*
- **AAP §0.8.1** records how that mandate is enforced: *"no test source file is modified at all."*
- **R-6** requires a pre-existing bug found during this work to be documented rather than repaired, with one carve-out for a bug that blocks a validation item.
- **R-5** forbids disabling a failing test and limits exclusions to the four measured baseline failures.

So the carve-out is the only door, and none of these 137 goes through it: the configured unit suite exits 0 with zero failures and zero errors, `npm ci` and `npm run build` exit 0, the static audit returns zero hits, and the artifact assembles — every validation item passes **with all 137 defects present**. That is precisely what makes them pre-existing rather than blocking, and precisely why repairing them here would make this change set unreviewable: a suite rewritten in the same commit as a compiler contract and a dependency surface can no longer tell you which of the three moved a behaviour.

### What these defects actually cost

This is the part worth carrying forward, because the finding classes are substantive and they bear on how much confidence the green suite deserves:

| Class of defect | Roughly how many | What it means for the suite's value |
| --- | --- | --- |
| **Expected-exception false positives** — the verification and assertions placed after the throwing call | ~20 | The assertions are unreachable. The test passes when production throws for *any* reason, and also when the mock expectations it set were never met |
| **Vacuous tests** — no assertion at all, or only a not-null, a size check, a `count >= 0`, or a print | ~30 | Cannot fail for the reason the test exists; `numFound >= 0` and `count >= 0` are tautologies |
| **Unverified mock expectations** — expectations recorded and replayed, never verified | ~20 | Zero interactions pass. The test proves nothing about what production called |
| **Fixture defects** — an object added twice where two distinct ones were intended, IDs written into the wrong map, a mock configured but never injected, aliased source and result objects | ~15 | The test exercises a different scenario from the one its name claims, usually a weaker one |
| **Negative tests that configure the positive path** | ~10 | The error contract is entirely uncovered while appearing to be covered |
| **Global-state leakage** — authentication left in the security context, the JVM default time zone changed and not restored, diagnostic context and system properties not cleaned up | ~15 | Order-dependent results, and false authorization positives that depend on which test ran first |
| **Non-determinism** — fixed sleeps, unseeded random inputs, a clock read on both sides of a comparison, an unsynchronised collection used as a concurrency oracle | ~12 | Flakes, and a concurrency test whose oracle is itself racy |
| **Class-level ignores** on substantive suites | 21 skips across 9 classes | Named individually in [the baseline record](baseline-test-failures.md); they include crypto, password migration, an Activiti task DAO and 13 FOIA queue rules |
| **Leaked resources in fixtures** | ~15 | Streams opened twice and never closed, temporary files never deleted, one archive extraction that trusts entry names |

The honest reading is the one the review itself gives: **a zero exit code from this suite overstates confidence.** That is recorded here deliberately, because it is the durable finding — the suite's *green* status is real, its *coverage* is weaker than the count suggests, and both facts have to travel together.

One item from that audit is called out separately rather than left in the aggregate, because it interacts with this migration's own configuration: a case-file watcher test records a PowerMock construction expectation and never verifies it, so the test passes whether or not production constructed the object. It is byte-identical to the base commit, it runs green today, and it is one of the six PowerMock-using test classes whose module-access directives are attributed in [the module-access record](add-opens-exceptions.md).

### Where a repair would have to start

Not with the 137. It would start with the two classes of defect that make the *rest* of the suite untrustworthy — the unreachable assertions and the unverified expectations — because until those are fixed, a change that breaks production behaviour can still leave the suite green, and every subsequent repair is measured against a signal that does not move. That work needs its own plan, its own review and a before-and-after pass rate, which is exactly why it is not folded into a runtime migration.
## Test fixtures carrying credentials and personal data — REQUIRED HUMAN ACTION

**This section is not like the rest of the page.** Everything else here is a defect that is safe to leave alone. These eight are not: two of them are committed secrets and committed personal data, and no amount of documentation reduces that exposure.

**This record deliberately does not publish where they are.** A public page that names the file, the line and the kind of secret it holds is a finding aid for anyone who has not yet looked, and the fixtures are still in the repository and still in its history. The exact paths, the affected identities and the credential values live in the restricted security record raised for this work; **request it from the repository owner or the security owner rather than reconstructing it from here.** What follows is the metadata a reader of this page legitimately needs — how many findings there are, how severe, what class of exposure each is, and what a human has to do — with enough shape to act on and no locator.

Two of the remediations the review calls for cannot be performed from inside this change set at all, and saying so plainly is part of the handover:

- **Credential rotation** happens in the systems that issued the credentials. It is outside this repository by definition.
- **History rewriting** rewrites published commits. It is a repository-owner operation with coordination costs for every clone, and it is explicitly outside the mandate of a migration branch.

What follows is therefore a work order, and the first row is the one that needs an owner today.

| ID | Severity | Class of exposure | Affected area | What a human must do |
| --- | --- | --- | --- | --- |
| S-01 | **CRITICAL** | Committed credentials and internal identities, inside a binary office attachment **and** inside the mail fixture that carries it | One module's e-mail extraction test resources | Rotate first, then replace both fixtures with synthetic equivalents of the same MIME and OOXML shape. See the sequence below |
| S-02 | MAJOR | Committed personal correspondence, a private e-mail address and routing metadata, across a delimited export, a document, an archive and a mail item | One integration module's production-file test resources, plus one mail fixture in the content module | Replace with synthetic correspondence that preserves the parsed structure the assertions depend on |
| S-03 | MAJOR | A test that reads real key material from the user home, prints decrypted plaintext and ciphertext, hardcodes passwords, and asserts nothing | One encryption integration test | Ephemeral keys, synthetic secrets, no plaintext logging, and real assertions |
| S-04 | MAJOR | Core crypto and password-migration coverage is class-level ignored, so the weakest fixtures are also the least exercised | Two test classes | Make the fixtures hermetic and re-enable, under the constraint that the assertions themselves are preserved |
| S-05 | MAJOR | Authentication left in the security context, and other global state not restored between tests | Roughly eight test classes across the content, correspondence and case-file modules | Restore global state in teardown; the order-dependent authorization results are the risk |
| S-06 | MAJOR | A token-signing test that asserts nothing and logs the signed token; verification covered only by one positive case | One authentication test class, plus its generated report | Assert on the signature, and add tamper, wrong-key, malformed, algorithm and expiry cases |
| S-07 | MINOR | Archive extraction in a fixture trusts entry names, so it could write outside the intended temporary root if re-enabled | One compression test | Canonicalize and enforce containment; add traversal and absolute-path cases |
| S-08 | MINOR | A setup-style account and password pair embedded although the dependencies around it are mocked | One integration test | Replace with unmistakably synthetic values |

### Why S-01 needs an owner before the others

The secret-bearing material is committed **twice** — once as a binary office document and once nested inside the mail fixture that carries it — so a secret scanner that only reads text files sees neither copy. That is the property that made it survive, and it is the property that makes scanner coverage part of the remediation rather than an afterthought.

The sequence a human needs to follow, in this order:

1. **Treat every credential in that material as disclosed** and rotate or disable it in the issuing system. Do this first; it is the only step that reduces exposure rather than merely tidying.
2. **Replace the fixtures with synthetic equivalents** that keep the same MIME structure and document shape, so the nested-attachment extraction test still exercises what it was written for. This touches a pre-existing test resource, which this migration is forbidden to modify — hence the handover.
3. **Decide on history**, with the repository owner, knowing that step 1 is what actually protects the credentials and step 3 only removes the artefacts.
4. **Add nested-MIME and office-document scanning** to whatever secret scanning runs on this repository, so the next one is caught on the way in.
5. **Fix the undeleted temporary copy** the same test leaves behind, while it is open anyway.

S-02's personal data follows the same shape and the same constraint: real correspondence in fixture inputs that assertions depend on, so it cannot be replaced without touching a test resource.

**None of the eight blocks a validation item**, and that is stated for completeness rather than as reassurance. It is the reason they are registered here instead of fixed, and it has no bearing at all on how urgent S-01 is.
## Coverage integrity for the two PowerMock-prepared AWS classes

JaCoCo reports **zero** covered lines for both AWS service implementations, even though their tests run green and genuinely exercise them — 6 tests against the transcribe service and 8 against the comprehend-medical one. The plugin's own CSV output claims `AWSTranscribeServiceImpl` entirely uncovered (0 of 242 lines, 0 of 28 methods) and `AWSComprehendMedicalServiceImpl` likewise (0 of 129 lines, 0 of 19 methods). Both claims are false, and the build log names the cause twice per module:

```
[WARNING] Execution data for class com/armedia/acm/tool/transcribe/service/AWSTranscribeServiceImpl does not match.
```

PowerMock's `MockClassLoader` re-defines every `@PrepareForTest` class before the test touches it, so the class the JaCoCo agent recorded execution data for is not the class on disk, and JaCoCo discards the record rather than mis-attributing it. Every ingredient predates the migration — the annotations, JaCoCo 0.8.7, the 2% bundle floor and PowerMock 2.0.9 are all base-commit choices — so this is a reporting defect the migration inherited, not one it introduced.

Three repairs were considered and all three are refused by a rule rather than by preference: dropping or narrowing `@PrepareForTest` modifies pre-existing test sources, which AAP §0.2.4.2 forbids and AAP §0.6.2 declines explicitly; failing the build on the mismatch warning would fail validation item 1 permanently, since the mismatch is inherent to PowerMock's classloader; and enforcing coverage per class or per package is forbidden by AAP §0.8.7, which fixes the floor where it is rather than raising it opportunistically.

**Blocks a validation item? No** — item 1 passes and the `check` goal passes in every test-bearing module. What is lost is not a build signal but a true one: a future regression in either AWS service would not show as a coverage drop, because the coverage is already reported as zero.

## Two unit-test classes have never been discovered by the runner

Two test classes carry live `@Test` methods that **no configuration of this build has ever executed**, at the base commit or after the migration, because their file names fall outside the runner's include patterns:

| Class | Tests | Why it is invisible |
| --- | ---: | --- |
| `acm-services/acm-service-audit/src/test/java/com/armedia/acm/audit/service/AuditServiceImplT.java` | **3** | The name ends in a bare `T`. Surefire's default include set is `**/Test*.java`, `**/*Test.java` and `**/*TestCase.java`, and `AuditServiceImplT` matches none of them. It is the only such name in the reactor |
| `acm-services/acm-service-data-update/src/test/java/com/armedia/acm/services/dataupdate/web/SolrReindexServiceTests.java` | **1** | The name is **plural**. `**/*Tests.java` is a Surefire **3.x** default that 2.12.4 — the version the base commit silently inherited — did not have. It is the only `*Tests.java` file in the reactor |

**Why they are still dormant, which is a deliberate decision rather than an omission.** Declaring an explicit `<includes>` block replaces the plugin's defaults outright, so pinning Surefire 3.5.3 without one would have inherited 3.x's four defaults and **started executing** `SolrReindexServiceTests` — a class the Java 8 baseline never ran. The delivered configuration therefore restates 2.12.4's three patterns exactly, and the comment above it names both omissions and why each is intentional. The effect was measured on both owning modules: with the 3.x defaults the audit module reported **9** tests and data-update **4**; with the base trio restored they report **6** and **3**. The four-test delta is exactly these two classes.

**Why activating them here would be wrong.** A toolchain migration is allowed to change how tests are launched, not which tests exist or run — the acceptance bar is a suite comparable to the Java 8 baseline, and silently adding four never-before-executed tests to it would make the comparison meaningless in the one place it has to hold. Worse, their pass state is **unknown, not assumed-green**: `AuditServiceImplT` mutates the JVM-wide system properties `acm.configurationserver.propertyfile`, `configuration.server.url` and `application.profile.reversed`, so activating it inside a reused fork could perturb sibling tests in the same module rather than merely add coverage.

**Blocks a validation item? No.** Item 1 passes with both classes dormant, exactly as it did on Java 8.

**What remains for others.** Renaming both files to `…Test.java` is the whole repair, and it belongs in a change set that can absorb the consequences: run them, find out whether they pass, decide what the audit class's property mutation needs (its own fork, or `reuseForks=false` for that module), and only then add them to the acceptance total. It is a test-quality task with a known cost, not a migration task.

## The integration-test surface is never executed

The reactor contains **86** integration-test classes carrying **211** `@Test` annotations, and **not one** Failsafe report exists for any configuration of this build, at the base commit or after the migration.

The runner is not the obstacle, and that was verified rather than assumed. Failsafe 3.5.3 works on JDK 17 under this configuration — three hermetic classes were run in one invocation over `acm-files-property-file-manager`, `acm-encryption` and `acm-spring-context-holder`:

| Probe | Result |
| --- | --- |
| `PropertyFileManagerIT` | **3 tests, 0 failures**, reports written to `target/failsafe-reports` by `maven-failsafe-plugin:2.17:integration-test` — the base commit's own version, which this migration deliberately leaves in place |
| `SpringContextHolderIT` | **3 tests, 0 failures**, with a full Spring context, under the narrowed two-directive `argLine` |
| `AcmEncryptablePropertyUtilsImplIT` | **2 tests, 0 failures**, exercising real key material from the user home |
| `@{argLine}` composition | The JaCoCo agent argument and the module-access directives compose correctly in the Failsafe fork, exactly as they do for Surefire. Re-verified on the delivered tree: each of the three modules logs `argLine set to -javaagent:…org.jacoco.agent-0.8.7-runtime.jar=destfile=…`, the literal token `@{argLine}` appears **nowhere** in the log, and `jacoco-maven-plugin:0.8.7:check` runs in all three modules |

All three ran in one invocation — `mvn -o -B -pl acm-tool-integrations/acm-files-property-file-manager,acm-tool-integrations/acm-encryption,acm-tool-integrations/acm-spring-context-holder verify` on JDK 17.0.20 — which exits 0 with **8 integration tests green** (2 + 3 + 3), and `verify` also runs the `jacoco:check` goal, so coverage enforcement holds on the lane too. Those three are the whole hermetic subset, not a sample of it.

What stops the other 83 is their environment. Classified statically by what each class reaches for, **83 of 86** need a Spring application context, the external configuration server, the database, ActiveMQ, LDAP, Alfresco/CMIS or Solr; only three are hermetic. AAP §0.9.5 records the constraint directly: the reference stack is deliberately reduced, with Alfresco, Solr and Pentaho skipped and no credentials for them ever supplied.

Exercising one showed a second obstacle that is not environmental at all. `AcmObjectLockDaoIT` connected to the database successfully and then failed with `NoSuchBeanDefinitionException: No bean named 'pdfService' available` — its Spring context requires beans contributed by modules outside its own classpath. That is a context-composition defect in the test, not a runner or module-access failure, and it is invisible until someone runs the lane. Expect more of them.

**Blocks a validation item? No.** AAP §0.9.1 measures this migration on `mvn clean install -DskipTests` and `mvn test`, and AAP §0.9.6's definition of done names no integration-test item. A genuinely hermetic Failsafe lane would cover **three** classes out of 86; building one for the rest means classifying 83 integration tests by external dependency and standing up services the setup instructions deliberately skip. That is a test-infrastructure project with its own review.

One consequence worth stating for whoever schedules it: because these 211 annotations have never run, their pass rate is **unknown**, not assumed-green. The `AcmObjectLockDaoIT` result above is the first datum.
## Not defects — recorded so they are not mistaken for regressions

None of the following is a bug. Each is recorded because it looks like one at first glance, or because a reader may otherwise mistake it for something the migration broke.

| Observation | Measured detail | Why it is not a regression |
| --- | --- | --- |
| **WAR size** | The delivered artifact measures **275,728,204 bytes** — roughly 263 MiB — across **2,582** entries, at the unchanged path `acm-standard-applications/arkcase/target/arkcase-2021.03.war`, with **zero** entries under `resources/node_modules/` and the committed `package-lock.json` shipped | The name, the coordinates and the location are all unchanged. The artifact is about **2.7 MB** larger than the Java 8 baseline WAR at 273,020,897 bytes — 2,707,307 bytes precisely — and the growth sits entirely in `WEB-INF/lib`, which moves from **635** jars to **639** — see [the dependency inventory](dependency-change-inventory.md). The exact byte count varies between builds because archive timestamps and the licence plugin's year stamp are embedded — earlier builds on this runner measured 275,719,349, 275,720,275, 275,722,861, 275,722,947, 275,723,369 and 275,723,406, a spread of **8,855 bytes** across all seven — so the durable claim is the magnitude, not the digits |
| **The WAR carries whatever the frontend tree contains when it is packaged** | Two measured states of the identical committed source, and the decomposition between them, both owned by [the matched pair above](#an-in-place-frontend-install-is-packaged-into-the-war): a clean frontend tree gives **275,722,947 bytes** across **2,580** entries with **zero** under `node_modules`, and the same tree after `npm ci --ignore-scripts` and `npm run build` gives **333,033,441 bytes** across **22,005** entries — of which **19,412** are `resources/node_modules/**` at **48,289,658** compressed bytes and **11** are the generated `resources/assets/dist/**` bundles at **4,874,946** compressed bytes, so a tree that has run the frontend gate but had its `node_modules` removed lands between the two, larger than the clean WAR by those 4.9 MB. The delivered artifact in the row above packages **2,582** entries rather than that pair's 2,580, and the two are named rather than inferred — `resources/.npmrc` and `resources/scripts/ensure-profiles.test.js`, the only files this change set adds anywhere under the packaged webapp directory | Pre-existing behaviour of `maven-war-plugin`, which packages `src/main/webapp` wholesale — none of the three states is a regression, and the deployed application does not need the generated output in the archive, because `AngularResourceCopier` runs the frontend build at webapp startup from the copied resources. It is why the Track B command sequence begins by cleaning the frontend project root, and it is why an artifact size should be quoted with the tree state it was taken from: ~333 MB is a tree with an installed `node_modules`, ~281 MB is one that has run the frontend gate and then removed it, and ~276 MB is a clean one |
| **A network-dependent build input** | `config/env/all.js:38` — the `customJs` asset list pulls an Atlassian issue-collector script over HTTPS from an external host | Pre-existing and **deliberately unchanged**. Altering or vendoring it would change the pipeline's inputs, which the preservation mandate forbids. Flagged so that a build failing on network egress is diagnosed correctly rather than blamed on the toolchain move |
| **MariaDB must run as `utf8mb3`** | 11 column-level `MODIFY COLUMN … CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci` statements across 6 Liquibase changelogs, including `acm_case_file.cm_case_details` at `acm-case-file-tables-1.0.xml:586` — the exact column whose row-size limit fails on a `utf8mb4` server | The changelogs are legitimate and the schema is on the preservation list, so this is **server configuration, never a changelog edit**. No changelog is touched by this migration. Every one of the 11 is column-level; none sets a table or schema default |
| **Activiti writes into the working directory** | Tomcat should be started from a scratch directory rather than the repository root | An operational instruction, not a repository change. Activiti stays at its pinned version, so the behaviour is identical to the base commit |
| **`acm-jmeter` is never built** | The root POM's `<modules>` names exactly eight top-level aggregators — `acm-web`, `acm-plugins`, `acm-standard-applications`, `acm-services`, `acm-tool-integrations`, `acm-forms`, `acm-user-interface`, `acm-core-api` — and `acm-jmeter` is not among them. The directory holds JMeter assets and **no `pom.xml` at all**, and no POM in the repository references it. Those eight are the direct entries, not the size of the reactor, which is the transitive closure beneath them and is counted in [the dependency inventory](dependency-change-inventory.md) | Not a defect, and not something the migration removed. It surprises readers of [the module overview](../overview.md), which catalogues `acm-jmeter` alongside the reactor modules; the overview is a directory map, not a reactor listing |
| **Two `jakarta`-coordinate API jars remain in the WAR** | `jakarta.ws.rs-api` 2.1.5 and `jakarta.annotation-api` 1.3.5, both at the versions the Java 8 baseline WAR shipped | Pre-existing and **deliberately untouched**. Neither duplicates a class this migration declares, so neither creates the classpath-order ambiguity that the provider convergence removes; the two that did — `jakarta.xml.bind-api` and the `jakarta.activation` pair — are excluded at their sources. Removing these two would be a dependency change with no Java 17 reason, which **R-1** forbids. The migration's namespace commitment is a *source* claim, and it holds absolutely: **zero** `import jakarta.…` statements exist anywhere in the 3,055 main and 402 test sources |
| **`javax/annotation/meta/*` is shipped by two jars on many classpaths** | `jsr305` 3.0.2 and `annotations` 2.0.1 both ship `TypeQualifierValidator`, `When`, `Nonnull$Checker` and their siblings | Pre-existing, unchanged since the base commit, and **unrelated to JEP 320**. These are the FindBugs/JSR-305 annotation family, not a removed EE module, and the `Nullable` type ArkCase imports is satisfied from them rather than from the reinstated `javax.annotation-api`. Under **R-6** it is registered rather than repaired: no validation item depends on it, and de-duplicating it would move a dependency with no Java 17 justification |
| **Eight JAX-WS and SAAJ jars appear that the baseline WAR lacks** | `jaxws-api`, `javax.xml.soap-api`, `saaj-impl`, `mimepull`, `geronimo-ws-metadata_2.0_spec`, `geronimo-jta_1.1_spec`, `jboss-rmi-api_1.0_spec`, `jacorb-omgapi` | **No POM in this repository changed to cause it.** `cxf-parent` 3.3.5 — reached transitively through the pre-existing `tika-parsers` — declares a profile `id=java9-plus` activated by `<jdk>[9,)</jdk>` whose dependency list is exactly this set. It is inactive on JDK 8 and active on JDK 17, so the artifacts appear because the build runs on a newer JDK, for the same reason this migration reinstates JAXB. Excluding them would remove APIs CXF's SOAP paths link against |
| **JaCoCo reports "Execution data … does not match" for two classes** | The configured suite logs four such warnings, for `AWSTranscribeServiceImpl` and `AWSComprehendMedicalServiceImpl`, each followed by "Classes in bundle … do not match with execution data" | **Pre-existing, and measured to be so:** the identical four warnings appear in the Java 8 baseline test log at the base commit. Their cause is PowerMock rewriting those classes in its own class loader, so the bytecode JaCoCo analyses is not the bytecode that ran. The coverage check still passes in both modules. Nothing in this migration created them and nothing here silences them; they are the same argument for retiring PowerMock that [the module-access record](add-opens-exceptions.md) makes |
| **The JaCoCo coverage floor stays at 2%** | `code.coverage.minimum` is `0.02` at `pom.xml:188`, enforced as a `BUNDLE` / `LINE` / `COVEREDRATIO` limit by the `check` goal declared at `:600-603`, whose limit block is `:609-616` | Unchanged from the base commit and **not raised opportunistically**. Recorded so the low value is not read as something the migration lowered. Raising it is a coverage initiative with its own review, not a side effect of a runtime move |
| **187 `maven-default-http-blocker` metadata warnings** | The install log carries 2,196 `[WARNING]` lines, and **187 of them are one cause**: 117 for `javax.mail:mailapi` and 70 for `net.minidev:json-smart`, each reading `Could not transfer metadata … from/to maven-default-http-blocker (http://0.0.0.0/)`. Both coordinates are declared with a **version range** — `(,1.5)` in the root POM's `dependencyManagement` and `[1.3.2,2.4.2]` transitively from `com.nimbusds:oauth2-oidc-sdk` — and a range obliges Maven to consult `maven-metadata.xml` in every declared repository. One of the root POM's repositories, `milton-repo`, is plaintext `http://`, so Maven 3.8's built-in blocking mirror intercepts it and logs the refusal | Pre-existing on both counts: the range and the `http://` repository are both base-commit declarations, and the warning profile is **identical** between two independent full builds of this tree — 2,196 lines, 484 deprecation, 507 unchecked and 423 raw-type warnings in each. Resolution succeeds from locally cached metadata, so nothing is blocked and both `install` and `test` exit 0. Left alone deliberately: pinning the ranged versions would change the resolved dependency set, and R-6 permits a fix only where a pre-existing defect blocks a validation item. Recorded so a reader of the warning count knows that 8.5% of it is one blocked repository and not a JDK 17 symptom |

## Honest corrections on the record

Fifteen claims that circulated while this migration was planned, implemented and reviewed did not survive measurement — nine of them about the codebase, and six that this very page asserted in an earlier revision. They are named rather than quietly replaced, because a reader who has seen them needs to know which value is authoritative — and because a register that silently drops a refuted prediction is less trustworthy than one that keeps it with the measurement attached. Four of the codebase rows are database-seam findings whose *substance* stands and whose *numbers or mechanism* did not; each names the entry that carries the surviving half.

| Earlier figure | Measured value | How it was measured |
| --- | --- | --- |
| The malformed portal-gateway column type **can fail** the fresh-schema changeSet | **It does not fail** — the changeSet executes and produces the same column as a well-formed type would | Liquibase 3.1.1's own type resolution on all four supported dialects, its `updateSQL` output against a well-formed control, a real execution on a scratch MariaDB 10.6 database, and the `EXECUTED` row on the reference database. The defect is real and stays registered above; the failure prediction is what measurement withdrew, and the genuine cost turned out to be the checksum consequence of *correcting* it |
| The licence plugin affects "seven" main sources | **Six** | Counting main `.java` files without the header marker, at the base commit and in the migrated tree — the same six both times — and confirmed by running `process-sources` on the module that holds four of them |
| "Column-level `utf8mb4` ALTERs in six places" | **11 statements across 6 files** | `git grep -n utf8mb4` over the changelogs. The earlier count conflated statements with files. The substantive point is unaffected: every occurrence is column-level, so none of them is the server-level setting the requirement is about |
| `config/config.js` defects at `:16`, `:83`, `:93`, `:104`, `:115`, `:133`, `:137` | the guarded require now spans `:16-31`; the wrapper-object iteration is `:98` and `:148`; the four discarded concatenations are `:108`, `:119`, `:130` and `:152` | Those were base-commit numbers. The carve-out fix took the file from 140 to **155** lines. Two intermediate revisions of this row published a third set (`:36`, `:110`, `:120`, `:131`, `:142`, `:160`, `:164`) against a 167-line reading of the file, three of which were past end-of-file and one of which pointed at a correctly-assigned `.concat()`; the file was subsequently reduced when its deleted comments were restored, so those numbers are withdrawn. Both the base set and the delivered set are given side by side above, since a wrong line number in a register is worse than no register |
| All six `lib/` directories described as "first-party in-repo source" | **Five are vendored third-party**; one is an ArkCase fork | Reading each directory's own `package.json`: five name published `json8`-family packages with versions, the ISC licence, public repositories and a single named upstream author, and only `lib/acm-json8-patch/` has no manifest at all. The retention argument is unaffected, because it rests on the relative-path requires rather than on authorship |
| The scheduled expired-URL delete **has no transaction boundary** and raises `TransactionRequiredException` | **A transaction is demarcated** — the prediction does not reproduce | A probe on the Spring **5.3.39** jars this build ships, reproducing the wiring exactly (`@Transactional` on an interface method only, plain implementation, counting transaction manager, `<tx:annotation-driven>`) under both proxy strategies, because `<aop:aspectj-autoproxy proxy-target-class="true"/>` forces class-based proxying in the same root context: `transactionsStarted=1` with a JDK proxy **and** with a CGLIB proxy. The residual defect is real and stays registered as `DQ-07`; it is the *placement* of the annotation, not a missing transaction |
| `ZylabMatterCreationStatus` claims uniqueness on `cm_matter_name` **and** `cm_zylab_id` with **no** schema constraint behind either | `cm_matter_name` **is** constrained; only `cm_zylab_id` is unbacked | `zylab-integration-database-tables.xml` declares `unique="true" uniqueConstraintName="uk_matter_name"` in *both* createTable variants — `:12` for `mysql`, `:30` for `oracle,postgresql,mssql`. Half the finding does not stand; `DM-08` registers the half that does, together with `AcmOutlookFolderCreator.cm_system_email_address` |
| Nine CLOB or TEXT string attributes lack `@Lob`; one `@Lob` maps a `VARCHAR(4000)` | **Eight** unambiguous CLOB attributes (ten on a looser boundary); **two** `@Lob` over a non-LOB column | Matching every `@Lob` and every `@Column`-mapped `String` in the reactor against its column's declared type across all 223 changelogs. Eight columns are declared `CLOB` by the single changeSet that creates them; two more are `TEXT` on MySQL and `VARCHAR(2560)` elsewhere, which is the looser boundary that yields ten — the earlier nine is neither. The `@Lob`-over-`VARCHAR` cases are `Note.note` and `EcmFile.description`. Both figures are published in `DM-12` with the method, rather than reconciled away. The companion count — four `Date` fields over `TIMESTAMP` columns with no `@Temporal` — **reproduced exactly** |
| The `postgres` DBMS selector affects "115 structured identifiers" | **95** distinct column identifiers | Counting unique `<column name="…">` values inside the 45 affected changeSets. The other four figures for that defect reproduced exactly — **7** changelogs, **45** changeSets, **81** operations and **11** tables — and all five are published in `DD-02` with the counting method, so the disagreement is checkable rather than asserted |
| **This page's own claim**, in two successive revisions, first that two `coreBuild` profiles pin a Failsafe version the root POM had moved past, then that the root holds failsafe at **2.17** so every declaration agrees there | **All three declarations consume `${surefire.version}` = 3.5.3**, and the interim `failsafe.version` property is deleted. Neither earlier reading describes the delivered tree. The 2.17 reading rested on R-1 forbidding an unjustified version move; that mistook the precedence, because AAP §0.4.1 and §0.5.4 *mandate* failsafe at `${surefire.version}`, and R-1 governs changes the plan does not require | Reading all three declarations in the delivered tree; `grep -rn "<version>2.17</version>" --include=pom.xml .` matching nothing; `help:effective-pom` reporting 3.5.3 at the root under `-N` and in both modules' plugin blocks under `-DcoreBuild=true`; and a `verify` probe on the delivered POM logging `maven-failsafe-plugin:3.5.3:integration-test` with `AcmEncryptablePropertyUtilsImplIT` green at 2 tests and JaCoCo's check goal satisfied |
| **This page's own later claim** that `git diff c8f6226105..HEAD -- '*src/test*'` lists **zero** paths, and that the tree therefore adds no test file | **Five paths, all of them additions.** `MimeMessageParserTest`, `FOIAQueueCorrespondenceServiceTest`, `AngularResourceCopierTest`, `SpringWebArkAngularStarterWiringTest` and `DistributiveEventMulticasterTest` are delivered, together with the Node test file `resources/scripts/ensure-profiles.test.js`. The zero-path reading was taken from an interim revision in which those files had been withdrawn; they are restored, so the correction is itself retracted here. The claim it was protecting still holds in full and is the one that matters: **no base-commit test source is modified or removed** — 0 `M` and 0 `D` lines against 5 `A` lines | Running that exact command on the delivered tree, and decomposing its output by status letter |
| **This page's own count** of **402** Java test sources and **no** Node test source | **407** Java test sources — the base commit's 402, every one byte-identical, plus the 5 added above — and **one** Node test source | `git ls-files` over `*/src/test/java/**.java` on the delivered tree and on the base commit, differenced; and a search for any spec, test or runner-configuration file under the frontend root |
| **This page's own claim** that the portal `java.time` mapper was withdrawn because its failure does not reproduce | **It reproduces on the SAR path, and the mapper is kept.** A bare `new ObjectMapper()` on JDK 17 refuses `PortalSubjectAccessRequest` for *every* payload, including `{}`, with an unchecked `InaccessibleObjectException` that escapes the provider's `catch (IOException)`; the FOIA model, whose dates are `LocalDateTime`, fails cleanly instead, which is why a FOIA-only measurement looked conclusive | Both models probed on JDK 17.0.20 against `jackson-databind 2.10.3` on the modules' runtime classpath, four payload shapes each; the asymmetry is explained and tabulated in [decision 27](behavioral-decisions.md#27-the-portal-javatime-mapper-is-kept-because-the-failure-it-was-built-for-reproduces-on-the-sar-path) |
| **This page's own claim** that the raw-payload defect was repaired on the request endpoint and survives only on the inquiry endpoint | **All four paths emit the raw payload** — `submitRequest` and `submitInquiry` in both providers — because the redaction was withdrawn with the mapper it came in with | `git diff` reports zero lines for both provider files, and the four log-and-throw sites are read out in the entry above |
| **This page's own counts** of 5 backend and 4 frontend defects | **10** backend, **18** integration-boundary and security, **3** database, **5** frontend | Counting the `###` entries in each section of this page programmatically rather than by hand |

## Security review findings — the complete register

An independent security review of this migration examined the whole affected tree and raised **33 findings: 12 critical and 21 major**. Ten of them were defects in the migration's own work and were **fixed** (they are not registered here; R-6 does not apply to them, and each is described in the resolution record for that review). The remaining **23 are pre-existing** — byte-identical to the base commit `c8f6226105` — and they belong here.

Several were already registered on this page before that review, and those entries are cross-referenced rather than duplicated. The rest are added below, because a register that omits an established, reproduced exploit path is worse than no register: it reads as an all-clear.

**Read this section as a set of open decisions, not as a closed list.** Every entry is unfixed on purpose, and for one of two reasons: either R-6 requires a pre-existing defect to be documented rather than fixed, or fixing it would change an outcome the migration is mandated to preserve — REST contracts, security and permission-evaluation outcomes, effective DDL, wire behaviour toward the six services. Neither reason makes the defect acceptable. Both mean the decision belongs to an owner who can authorise behaviour change, and it has not been made.

### How severity and disposition are recorded

| Column | What it means |
| --- | --- |
| ID | The review's own identifier, so a reader holding that report can find the entry |
| Severity | The review's rating, unaltered |
| Disposition | `documented (R-6)` — pre-existing, reproduced, deliberately unfixed; `documented (preservation)` — a fix would change a mandated-preserved outcome; `directed` — the project instructions explicitly required documenting rather than fixing |
| Decision required | What a human has to choose. Not a suggestion for a future refactor: the thing that is currently undecided |

### Authorization and identity binding

| ID | Severity | Where | The defect, and why it matters | Disposition | Decision required |
| --- | --- | --- | --- | --- | --- |
| SEC-C01 | Critical | Portal user and request controllers; the FOIA and SAR portal service providers | Route-level privilege is checked, but no self / portal / object binding follows it at the service boundary. A caller who is permitted to use the endpoint at all can name another user's identifier or another case number and read or write that object. This is CWE-639 (authorization bypass through a user-controlled key) reached over an authenticated route, so the exposure is other tenants' and other subjects' PII and case data, not anonymous access | documented (preservation) | Whether to add ownership and portal binding at the service boundary. It is the right fix and it **changes permission-evaluation outcomes**, which this migration is mandated to preserve — so it needs to be planned as behaviour change with its own regression coverage, not slipped into a runtime migration |
| SEC-C02 | Critical | `DefaultPortalCheckUserAssignementService` (the portal assignment aspect), lines 53-61 | The aspect authorises the *principal* but ignores the `portalId` argument, so a configured integration principal can operate against a portal other than its own. 26 portal route pairs traverse this aspect | documented (preservation) | Whether to bind principal to portal and reject a mismatch. Same constraint as SEC-C01, and the same reason it is not done here |
| SEC-C03 | Critical | `servlet-context.xml:100`; the Frevvo form controller; the change-case service | An interceptor path pattern does not match the routes it was written for, so three `ANY`-method Frevvo routes under `/api/v1/forms/crud/acm/{formName}/{init\|get\|save}` are not covered by the privilege interceptor — and the form name, action and case identifier all come from the client. The consequence is client-selected case mutation | documented (preservation) | Whether to correct the mapping **and** add explicit functional and object permission checks. Correcting the pattern alone changes which requests are rejected — a security-outcome change by definition, and one that will surface as broken client flows if the routes have been relied on as they are |
| SEC-M18 | Major | The public security chains and header configuration | Routes declared `security="none"` bypass Spring Security's filter chain entirely, and with it the header writers and CSRF protection. 16 unique route pairs sit on that surface. CSP, HSTS and `nosniff` therefore cannot be established from this repository at all — the effective rules live in the external configuration bundle | documented (R-6) | Whether to introduce a dedicated public chain that still applies headers, with only the specific exceptions each public route needs. Requires the external configuration to be changed in step |

### Sessions, tokens and credentials at rest

| ID | Severity | Where | The defect, and why it matters | Disposition | Decision required |
| --- | --- | --- | --- | --- | --- |
| SEC-C06 | Critical | `WEB-INF/web.xml`, lines 79-102 and 147-156 | The session cookie is configured without `Secure`, `HttpOnly` or `SameSite`, and a `RequestDumper` valve is enabled that logs full request detail — including that cookie — *before* security filters run. Either alone is serious; together they mean a session identifier is both script-readable and written to a log | documented (R-6) | Whether to set the three cookie attributes, require HTTPS/HSTS, and remove or redact the request dumper. The cookie attributes are a security-outcome change; the dumper is debug configuration and is the cheapest first move |
| SEC-M03 | Major | The authentication filter and token service | Bearer tokens are accepted from the query string and logged, so a reusable credential ends up in access logs, proxy logs and `Referer` headers (CWE-598) | documented (R-6) | Whether to move token exchange to a header or POST body and hash or redact what is logged. Removing query-string acceptance breaks any client that relies on it, so it needs a deprecation path — and any token already exposed needs rotating regardless |
| SEC-M14 | Major | `SessionDestroyedListener`, lines 40-53, and `web.xml` | The listener that purges tokens when a session ends is not wired as a listener, so session-end token revocation cannot be demonstrated to happen at all | documented (R-6) | Whether to wire the publisher and listener, and to prove distributed logout and timeout behaviour with tests. Wiring it *starts* revoking tokens that are currently left live — a behaviour change, and the desirable one |
| SEC-M15 | Major | The concurrent-session control strategy, lines 107-115 | A token in `ACTIVE` state that has actually expired bypasses the maximum-sessions check, and an unknown token dereferences null and produces a 500 | documented (R-6) | Whether to validate the token fully, null-check it, and stop exempting bearer-authenticated requests from concurrency limits |
| SEC-M20 | Major | `AuthenticationToken`, lines 62-95 | The token key is persisted in plaintext, and an optional password field is persisted recoverably. A database compromise therefore yields working bearer links rather than useless digests (CWE-312) | documented (R-6) | Whether to store only a digest of the token and stop persisting a recoverable password. Requires a migration for existing rows and invalidates issued links |
| SEC-M16 | Major | The crypto constants and their implementation | AES-CBC with no authentication tag, a raw passphrase truncated to key length instead of run through a KDF, and a weak pseudo-integrity check. Unauthenticated CBC is malleable: an attacker who can write ciphertext can tamper with plaintext (CWE-327, CWE-353) | documented (R-6) | Whether to move to a versioned AEAD construction with a proper KDF. Every value already encrypted has to be migrated, which is why this is a project rather than a patch |
| SEC-C11 | Critical | The Snowbound client services | When the key is absent or the crypto call fails, the code emits the viewer URL **in plaintext** — carrying a session ticket and document metadata — instead of failing. A fail-open path that leaks a bearer credential into a URL is worse than an outage | documented (R-6) | Whether to replace URL-borne tickets with a server-side one-time opaque exchange, and to fail closed when the key is missing. Changes the viewer integration contract |
| SEC-C12 | Critical | The Alfresco sync configuration and client | Missing configuration silently falls back to `admin`/`admin` against a privileged external service, and the Basic-auth client has no connect or read deadline | documented (R-6) | Whether to remove the default outright (fail startup instead), move the credential to a secret manager, scope the account down, and bound the client. Removing the default will stop mis-configured environments from starting — which is the point, and is a behaviour change |
| SEC-C10 | Critical | Committed EML and OOXML test fixtures | Password context and personal data are committed in binary fixtures, and therefore in git history and in any temp copy a test writes | documented (R-6) | Already registered in full, with the human action it needs, under [Test fixtures carrying credentials and personal data](#test-fixtures-carrying-credentials-and-personal-data-required-human-action). History rewriting and credential rotation are owner decisions |

### External input reaching a sink

| ID | Severity | Where | The defect, and why it matters | Disposition | Decision required |
| --- | --- | --- | --- | --- | --- |
| SEC-C07 | Critical | The OnlyOffice callback controller and service | Already registered: row **I-10** of [the integration register](#integration-boundary-and-security-defects-documented-not-fixed). An attacker-supplied URL becomes document content, and the callback authorisation value is computed but never enforced — SSRF plus document replacement | documented (R-6) | Whether to verify the signature and claims, add replay protection, and restrict the fetch to an allow-listed origin with size and time limits |
| SEC-C08 | Critical | `FileConfigurationServiceImpl`, lines 88-123 | Already registered: row **I-05** of [the integration register](#integration-boundary-and-security-defects-documented-not-fixed). A broker-supplied filename containing `../` escapes the configured root — arbitrary file write | documented (R-6) | Whether to canonicalise and contain the path, constrain the filename grammar, encode the URL segment, and authorise the producer |
| SEC-C09 | Critical | The EML converter, the MIME parser and their caller | The migration's own regression here **was fixed** — the inline-image transfer-encoding check is restored and covered by a test. Three pre-existing halves remain: the HTML-to-PDF path fetches remote images named in message HTML (SSRF), attachment filenames from the message are used to build temp paths, and inline-image content is buffered whole with no size, count or depth limit (memory exhaustion from a crafted message) | documented (R-6) | Whether to disable external resource loading in the converter, generate temp names instead of deriving them, and bound the MIME buffering. Each bound is a new rejection path, so each will refuse some message the base commit accepted |
| SEC-M17 | Major | The YAML configuration loader | SnakeYAML is used with default object construction on a file that is reloadable at runtime, so anyone who can modify that file gets deserialisation-driven code execution (CWE-502) | documented (R-6) | Whether to switch to `SafeConstructor` with `LoaderOptions` limits and a schema, and to lock down the file's ownership. Restricting the constructor may reject configuration shapes that currently load |
| SEC-M05 | Major | The FOIA NIEM export and PDF transformers | Already registered: [XML transformation: the external-access hardening is a no-op on this classpath](#xml-transformation-the-external-access-hardening-is-a-no-op-on-this-classpath). The attempt to set the secure-processing attributes is wrapped in a `catch` that continues, so a provider that rejects them leaves external entity and stylesheet resolution enabled | documented (R-6) | Whether to fail closed when the attributes cannot be set |
| SEC-M06 | Major | The FOIA and privacy stored-procedure changelogs | Already registered: [DS-03 — median stored routines with an unvalidated identifier surface and a broken cleanup](#ds-03-median-stored-routines-with-an-unvalidated-identifier-surface-and-a-broken-cleanup). Table and column arguments are concatenated into dynamic SQL | documented (R-6) | Whether to allow-list or quote the identifiers and restrict `EXECUTE` grants. Both are outside this checkout in part — who calls the routines is a deployment fact |
| SEC-M04 | Major | `ConfigurationServiceBootClient` | Already registered: row **I-04** of [the integration register](#integration-boundary-and-security-defects-documented-not-fixed). `Throwable` is swallowed, so a partial or empty security configuration can start, and there is no connect timeout | documented (R-6) | Whether to fail startup when critical configuration is missing, and to bound the retries |

### Disclosure through logs and errors

| ID | Severity | Where | The defect, and why it matters | Disposition | Decision required |
| --- | --- | --- | --- | --- | --- |
| SEC-M01 | Major | The FOIA and SAR `submitInquiry` paths | Partially registered already: [The raw portal payload travels in every deserialisation failure message, in both providers and both methods](#the-raw-portal-payload-travels-in-every-deserialisation-failure-message-in-both-providers-and-both-methods). The full finding adds that the nested request object is logged and propagated, and that the message is assembled with a format string that can itself throw — a log-injection vector (CWE-117) on top of the PII exposure. **No path was remediated by this migration.** An earlier revision of this row asserted that `submitRequest`'s raw-payload logging had been removed here and offered it as a contrast; that assertion was withdrawn in the prose section linked above, and this row is now corrected to match. Verified against `git show c8f6226105`: in both providers, and in both `submitRequest` and `submitInquiry`, every one of the four log lines and four exception messages still carries `rawRequestContent` and is byte-identical to the base commit | documented (R-6) | **A first-time repair of all four paths**, not an extension of an existing one — nothing here has been fixed yet. Whether to remove request bodies from these logs, sanitise the identifiers that remain, correct the `submitInquiry` placeholder-count defect, and return stable mapped errors. Because the raw content also reaches the client through `error_message`, changing it is an API-contract decision as well as a logging one |
| SEC-M02 | Major | `AcmSpringMvcErrorManager`, lines 72-246 | Raw exception messages are returned to clients and full stack traces reach the logs, disclosing internal paths, class names and SQL fragments (CWE-209) | documented (R-6) | Whether to return opaque error identifiers and codes to clients while keeping detail server-side and redacted. Changes every error response shape, so it is an API-contract decision |

### Build, CI and supply chain

| ID | Severity | Where | The defect, and why it matters | Disposition | Decision required |
| --- | --- | --- | --- | --- | --- |
| SEC-C05 | Critical | `.gitlab-ci.yml` and `.gitlab-ci-release.yml` | Both files disable transport verification while moving credentials and executable content: `curl -k`, `-Dmaven.wagon.http.ssl.insecure=true`, `GIT_SSL_NO_VERIFY`, `sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`, a remote script piped straight into a shell, and Maven server credentials written into `settings.xml` by `echo`. A network-positioned attacker can substitute the tool that runs, or collect the credentials that pass. **Verified byte-identical to the base commit**, and outside the CI edits this migration is scoped to (the runner image pin and the removed CMS flag) | documented (R-6) | Whether to require verified TLS and known host keys, verify artifacts by signature or digest, stop piping remote scripts to a shell, and issue ephemeral least-privilege credentials. This is a pipeline-owner decision and touches secrets this repository does not hold |
| SEC-M19 | Major | `.gitlab-ci.yml`, lines 208-211 and 232-235 | The scanner's credentials file is created as `credentials` and the `[DEFAULT]` section header is appended to `credendials` — a typo — so the file the tool reads may lack its section header and the authenticated scan can fail or silently not run. Also byte-identical to the base commit | documented (R-6) | Whether to correct the filename, restrict the file to `0600`, delete it after use, and assert that the scan actually authenticated. A one-character fix whose value is entirely in the assertion that follows it |
| SEC-C04 / SEC-M12 | Critical / Major | `package.json`, `package-lock.json` and the shipped frontend graph | See [The npm advisory position](#the-npm-advisory-position) below. The enforcement halves of this finding — engine strictness and the deploy-time install form — **were fixed**; the advisory graph itself is what remains | documented (preservation) | Whether to accept, isolate or replace the AngularJS 1.4.14 stack |
| SEC-M13 | Major | `AngularResourceCopier` | Partially registered already: [Deploy-time front-end driver: no command deadline, and unchecked deletions](#deploy-time-front-end-driver-no-command-deadline-and-unchecked-deletions). The unchecked-deletion half **was fixed** — a failed prune is now logged with its path. The command deadline is deliberately not added: the base commit waits indefinitely, and a deadline would newly fail deployments whose cold-cache `npm ci` legitimately runs minutes (2m in the validation run) | documented (R-7) | Whether to add a deadline, and what value could be safely chosen for a cold-cache install on the slowest supported host |
| SEC-M07 | Major | The external ActiveMQ configuration and its documentation | Already registered: [ActiveMQ's TLS transport does not work on Java 17](#activemqs-tls-transport-does-not-work-on-java-17). Plaintext broker transport exposes credentials and message payloads to anyone on the path | `directed` — the project instructions require this to be documented, not fixed, and not to fail setup | Whether to confine the broker to a private network with authorisation, tunnel it, or fix mutual TLS on Java 17 — plus credential rotation, an owner and an expiry date for the acceptance |

### The runtime module access open

R-2 permits a production module-access exception only where a pinned third-party dependency documentedly requires one. The migration has exactly one, and it is recorded here as well as in [the module-access record](add-opens-exceptions.md) because it is the kind of thing that gets lost between documents.

ArkCase's start-up requires `--add-opens=java.base/java.lang=ALL-UNNAMED`. **This repository's own launch configuration grants nothing** — the published `JAVA_OPTS` blocks carry no module-access flag, exactly as at the Java 8 base commit — and on Tomcat 9 the open arrives from the container's own `bin/catalina.sh`, which exports seven of them before the JVM starts. The demand comes from two pinned dependencies reached while the application compiles its business rules: Drools 7.34.0.Final, whose `ClassGenerator` static initialiser calls `setAccessible` on `ClassLoader.defineClass`, and Groovy 1.8.6, which it carries and which calls `setAccessible` on `Object.finalize()`.

What that costs, stated plainly: `ALL-UNNAMED` is not targeted at the two libraries that asked. It opens the JDK's most sensitive package to every jar on the classpath — 639 of them in this WAR — for the life of the process, and reflection into `java.lang` internals is a step in many deserialisation and classloader chains. Nothing in this migration's permitted scope retires it: upgrading was the first option tried and it is what fixed the spring-ldap case, but Drools and its scripting stack are not among the libraries this migration may move, and moving them changes rule-evaluation behaviour.

**Decision required:** accept the open for this deployment with a named owner and a review date, or plan the rules/scripting stack as work of its own. The migration plan's statement that production carries *zero* module-access exceptions is, read strictly, one exception out — and that discrepancy is deliberately left visible here rather than reconciled by wording.

### The npm advisory position

The frontend graph the migration ships carries known vulnerabilities, and the numbers are published here rather than left to whoever next runs the tool.

Measured on the delivered `package-lock.json` with `npm audit --package-lock-only --ignore-scripts` on npm 10.8.2, and reproduced by `npm ci` itself, which prints the same summary:

| Severity | Advisory nodes |
| --- | ---: |
| Critical | 11 |
| High | 19 |
| Moderate | 20 |
| Low | 2 |
| **Total** | **52** |

Three facts frame what can and cannot be done about that:

1. **This is the base commit's dependency graph, at the base commit's versions.** The migration moved six frontend packages, every one of them a *build* tool that could not install or load on Node 20, and rewrote 53 dependency specs mechanically from bower's `#<range>` syntax to npm's `#semver:<range>` — same repositories, same resolved commits, zero version movement. The runtime asset versions a browser receives are the ones the base commit declared. Fifteen of the advisories are AngularJS 1.4.14's own; most of the rest are transitive dependencies of the frozen Grunt toolchain.
2. **There is no behaviour-preserving patch path for most of them.** AngularJS 1.x is end-of-life: there is no patched 1.4.x, and moving off it is precisely the "new frontend framework" this migration excludes. The same holds for the jQuery, Bootstrap 3, Summernote, Handsontable, Chart.js and Videogular versions the UI is built against — each advisory's remedy is a major version that changes rendered behaviour. `npm audit fix --force` would rewrite the tree the pipeline is verified against.
3. **What is in force instead is isolation and visibility, and neither is a substitute for patching.** Every package resolves from the committed lockfile — 397 registry entries with integrity hashes, 53 git entries pinned to full 40-character commit SHAs, and no `http://` source anywhere — so the graph cannot drift silently. Installs run with `--ignore-scripts`, so no dependency lifecycle script executes during install. The declared Node and npm range is enforced by `engine-strict` rather than warned about. And the CI frontend job now runs `npm audit` on every pipeline, deliberately **non-blocking**, so that a *new* advisory arrives in a build log rather than in an incident.

One honest gap in the isolation story, since it was raised: git-sourced entries carry a commit SHA but no subresource-integrity hash, because npm does not record one for git dependencies. A commit SHA is a content hash of the git object, so it is a real pin rather than a floating reference — but it is verified by git's own SHA-1 rather than by the SHA-512 SRI the registry entries use. The base commit addressed one of these coordinates with a `codeload` tarball URL, which *did* carry integrity; that spec was returned to its base-commit git form because the migration's mapping is a mechanical syntax rewrite with no source changes, so the trade-off is recorded rather than silently taken.

**Decision required, and it is the largest one on this page:** whether to accept this graph for production with a named owner and an expiry, to isolate the affected surfaces further (a Content Security Policy is the highest-value single move, and the review found none demonstrable), or to fund the frontend replatform that the advisories actually call for. What must not happen is the third option arriving by accident, as a `npm audit fix --force` on a Friday.

## What this record does not cover

**Suite totals and the exclusion accounting.** This page names the four baseline failures and the two classes that carry them, and it publishes no test counts at all — those are measured and owned by [the baseline record](baseline-test-failures.md), which is the single source of truth for them. It also owns the collateral cost of a class-level exclusion and the pre-existing skipped tests, neither of which is a defect this page registers.

**Defects in code this migration wrote.** Nothing on this page is a defect in the change set itself. Where the review found a gap in the migration's own work — an untested LDAP loader, an untested JAXB provider path, an untested frontend fallback branch, duplicate EE providers on every classpath — it was **fixed**, not registered, because it is not pre-existing and R-6 does not apply to it. The register is for the base commit's defects only, and mixing the two would be the most misleading thing this page could do.

**Module-access directives beyond the one recorded above.** Eight of the nine are confined to the forked test JVMs and are attributed individually in [the module-access record](add-opens-exceptions.md); none of the defects registered on this page needs any of them. The ninth **does** reach production, and it is registered above under [The runtime module access open](#the-runtime-module-access-open) rather than waved past here — an earlier revision of this line said none reaches production, which was wrong.

**Version changes.** Every dependency and plugin move, its reproduced reason, and the candidates that were considered and withdrawn belong to [the dependency inventory](dependency-change-inventory.md). This page cites versions only where a defect's disposition depends on one.

**JDK-internal API references in source.** Those are a separate audit with a separate remedy, in [the static audit](static-audit.md). Every one of them was cleared, so none is a known issue.

**Anything resolved rather than recorded.** Ambiguities settled against observed Java 8 base-commit behaviour are decisions, not defects, and belong to [the behavioural decisions record](behavioral-decisions.md).

**A security assessment.** The integration-boundary section registers the security-relevant defects that were established while this migration was reviewed — server-side integration failures, and the browser-side and transport findings raised by the seam review: tickets in URLs, CSRF, the two HTML sinks and the portal payload logging. Each carries enough detail to act on. It is not the output of a systematic security review of ArkCase, and it must not be read as one: no threat model, no dependency-vulnerability sweep and no penetration test was performed. Four entries — the JMS-driven path traversal, the unverified OnlyOffice callback, the bearer tickets in URLs and the disabled CSRF — are flagged in their own text as worth escalating out of R-6 rather than waiting for the next migration.

**A product decision on the seam.** The eight seam defects are registered with their locations, their live-caller status and the reason each is frozen. What they are *not* given is an answer: whether each dormant contract should be implemented or retired, and what the intended backend contract for the two live ones is, are product questions this migration has no standing to settle. The register hands them over stated precisely enough to be decided; it does not decide them.

**External database consumers and privileges.** The database section proves what this repository does and does not contain — a mapping with no changelog behind it, a type literal, nine routine definitions with no in-tree caller, six query paths nothing calls or nothing tests, and twelve annotation-versus-changelog disagreements that no configured test can reach. Who calls those routines, which `EXECUTE` grants exist, whether a deployment's own DDL bundle supplies the missing collection table, and what the mapping disagreements actually do to customer data are all facts that live outside this checkout. Each entry names that handoff explicitly rather than leaving it implied, because a register that stopped at the repository boundary without saying so would read as an all-clear.

**Non-MySQL platform behaviour, and it is the largest gap on this page.** `DD-01` and `DD-02` establish that Oracle, PostgreSQL and SQL Server take DDL paths no validation item exercises — one of them creating a misspelled column that breaks OAuth2 token persistence outright, the other silently skipping 45 changeSets on PostgreSQL. Everything this migration measured, it measured on MariaDB. So this page can say what those two changelogs *contain*, and it cannot say what a running Oracle, PostgreSQL or SQL Server deployment currently looks like. Both entries state that as a handoff with the platform named; neither should be read as bounded until somebody runs it.

**Live token exposure.** The four `DC` entries name what is stored and what is logged. They cannot name which tokens are still valid, which log archives hold copies, or which upstream providers would need to revoke — all of which are per-deployment facts, and all of which are the part that reduces exposure rather than merely recording it. That is why those four are marked as needing an owner rather than a reader.

## Related records

| Record | What it owns |
| --- | --- |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative suite totals, the two class-level exclusions and their collateral cost |
| [Module-access exceptions](add-opens-exceptions.md) | The eight test-scope directives with their per-library attribution; the certification that production launch configuration grants nothing; and the [unreconciled runtime observation](add-opens-exceptions.md#an-unreconciled-runtime-observation-not-a-production-grant) it holds open rather than settles |
| [Dependency change inventory](dependency-change-inventory.md) | Every dependency and plugin change with its reproduced reason, including the removals R-4 required |
| [Static audit](static-audit.md) | The JDK-internal-API audit command, its classified hits before and the zero-hit result after |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour |
| [Smoke evidence](smoke-evidence.md) | What the reduced reference stack could and could not exercise — the constraint that every non-blocking justification in the database section rests on |
