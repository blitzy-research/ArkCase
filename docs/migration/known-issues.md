# Known Issues

This page is the register of defects that were **already present at the Java 8 base commit** `c8f6226105` and were deliberately **not** fixed by the Java 17 and Node 20 migration, together with the single condition that *was* fixed because it blocked a named validation item. Everything here was reproduced against the real checkout; nothing is inferred.

The register spans three classes of defect, in the order they appear below: **backend** defects in Java sources, POMs and build plugins; **database and schema-authority** defects in the ORM mappings, the Liquibase changelogs and the stored routines; and **frontend** defects in the Grunt pipeline and its configuration. The database class deserves its own section rather than a line inside the backend one, because its defects are not reached by compiling or testing the code — they surface only when a schema is migrated or a routine is called, which is a different exercise path and, for two of the three, a different deployment profile.

It has two halves, and they are different in character. The first half — the backend and frontend defect sections — is the small set the migration itself tripped over while moving the runtimes. The second half is much larger: **137 test-quality defects, 8 security findings in test fixtures, a coverage-integrity gap and an integration-test surface that has never executed**, all raised by a dedicated review of the reactor's test sources. They are registered together because they share one disposition and one reason for it, but two of them need an owner rather than a reader — see [Test fixtures carrying credentials and personal data](#test-fixtures-carrying-credentials-and-personal-data-required-human-action).

| What is registered here | Count |
| --- | ---: |
| Backend defects | 5 |
| Frontend defects | 4 |
| Pre-existing test-quality defects | **137** (75 major, 62 minor) |
| Security findings in test fixtures and tests | **8** (1 critical, 5 major, 2 minor) |
| Coverage-integrity and discovery findings | 2 |
| Integration-test surface never executed | 86 classes / 211 annotations |
| Conditions fixed under the R-6 carve-out | 1 |

## Why nothing here is fixed

**R-6** requires that a pre-existing bug discovered during this work be documented rather than repaired, with one carve-out: a bug that blocks a validation item may be fixed. Exactly one item on this page sits on the fixed side of that line, in [The one condition fixed under the carve-out](#the-one-condition-fixed-under-the-carve-out). Everything else is left exactly as the base commit wrote it.

For the test-source findings there is a second, independent bar on top of R-6, and it is the stricter of the two: **AAP §0.2.4.2** lists *"Existing test assertions"* among the preservation mandates and states that *"modification of any of these is a defect, not a scope choice"*, while **AAP §0.2.1.3** and **§0.8.1** put it operationally — no test source file is modified at all. So even a test defect that *did* block a validation item could not be repaired by editing the test; it would have to be reached another way. That is exactly what happened for the one class of undiscovered tests this checkpoint did reach, by adding a precise runner include rather than renaming the class.

The reasoning is worth making legible, because the rule is not bureaucracy. A compatibility migration earns its review by being attributable: if the same change set moves a compiler contract, a dependency surface *and* an unrelated defect, then any behavioural difference observed afterwards has two candidate causes and the reviewer can no longer tell which one produced it. Keeping the repairs out is what makes the runtime move reviewable at all. The corollary is the discipline this page holds itself to — describing a defect here does not license fixing it.

A note on where the rules come from, because it is unusual and a reader should not go looking in the wrong place. **`review_rules` reports that no user rules were provided**, and there is no on-disk rules document for this project. The seven binding constraints this migration works under arrive instead through the **RULES block of the user prompt**, whose full verbatim text is available via **`review_prompt`**. They are cited across this documentation set as **R-1** through **R-7**. This page cites them by identifier and summarises what each requires of it; it does not reproduce their text, because the prompt is the source of truth for that.

| Rule | What it requires of this page |
| --- | --- |
| **R-6** — pre-existing bugs are documented, not fixed | Primary. This page *is* the register R-6 asks for, and R-6 is the only reason it exists — the migration's deliverable list does not name it. Every entry must state whether it blocks a validation item, and the one that does must say which. Coverage is every class of defect the work surfaced, database authority included: an ORM mapping, a changelog or a stored routine is as much "source" for R-6 purposes as a `.java` file, and a defect there is registered here rather than repaired, because the schema and the effective DDL are on the preservation list |
| **R-5** — failing tests must not be disabled | The four baseline test failures are pre-existing defects and belong here, but their exclusion accounting belongs to [the baseline record](baseline-test-failures.md). This page summarises and links; it publishes no suite totals. R-5 also forecloses the obvious shortcut for the 21 pre-existing `@Ignore`d classes registered below: they cannot be deleted to make the register shorter |
| **AAP §0.2.4.2 / §0.2.1.3 / §0.8.1** — existing test assertions are preserved | The binding constraint for the 137 test-quality findings and the 8 security findings. It is why they are registered rather than repaired, and it is stricter than R-6 because it admits no carve-out |
| **R-4** — the frontend must genuinely run on Node 20, with no vendored dead packages | The retained vendored `lib/` tree must be *justified*, not merely noted, because a careless reading of R-4 would treat it as exactly the thing R-4 forbids |
| **R-2** — no module-access flags or JDK-internal reliance in production launch configuration | Nothing in production launch configuration is changed here. The ActiveMQ finding below is a documentation item by direction, not a missing flag; the launch-configuration certification lives in [the module-access record](add-opens-exceptions.md) |

### How to read an entry

Every entry names **what** the defect is, **where** it is, and **why it does not block a validation item** — that last clause is the justification for leaving it alone, and an entry without it would not satisfy R-6. Entries in [Integration-boundary and security defects](#integration-boundary-and-security-defects-documented-not-fixed) additionally carry a **follow-up condition**: what would have to be true for the repair to be in scope, so that the analysis behind the decision is not lost with it. The validation items referred to are the five the migration is measured against:

| # | Validation item |
| --- | --- |
| 1 | `mvn clean install -DskipTests` then `mvn test` exit 0 on JDK 17 |
| 2 | `npm ci --ignore-scripts` then `npm run build` exit 0 on Node 20 from a fresh checkout |
| 3 | The JDK-internal-API static audit returns zero hits in main source |
| 4 | The assembled artifact deploys and reaches a ready state |
| 5 | Smoke flows match the Java 8 baseline |

Line numbers are given for the **migrated tree** as published. Where the migration legitimately moved a line, the base-commit number is given alongside it in parentheses, so the citation is checkable against either tree.

Some entries carry a fourth clause, **what remains for others**. It appears wherever the repository can establish that a defect exists but cannot establish what it costs — because the evidence lives in a deployment profile, an external configuration bundle or a database privilege that is not in this checkout. That clause is a handoff, not a hedge: it names who must close the question and with what, so an entry is never left reading as an all-clear simply because this repository ran out of things to measure.

## Backend defects — documented, not fixed

| Defect | Location | Blocks a validation item? |
| --- | --- | --- |
| Compressor closes a stream and then finishes it again | `DefaultFolderCompressor.java:215-219` with `MaxThroughputAwareFileOutputStream.java:123` | **No** — it is one of the two baseline exclusions, so item 1 is unaffected |
| Three unmet EasyMock expectations in one controller test | `FileDownloadAPIControllerTest` in `acm-services/acm-service-ecm` | **No** — same exclusion; item 1 is unaffected |
| The same servlet API declared twice in one module POM | `acm-services/acm-service-authentication-token/pom.xml:89-93` and `:109-112` | **No** — it is a Maven warning, the build succeeds, and nothing reaches the artifact |
| Posting credentials to `/login` returns HTTP 500; the working entry point is `/login_post` | the deployed application's security filter chain | **No** — item 5 uses the documented entry point, which returns 302 on both builds |
| The build injects licence headers into tracked sources | `pom.xml:468-496` — `license-maven-plugin` on `process-sources` | **No** — it mutates the working tree, not the build outcome |
| ActiveMQ's TLS transport does not work on Java 17 | No location — no broker URL exists in this repository | **No** — and the project setup instructions direct that it be documented, not fixed |
| Portal submissions reject any `java.time` value they carry | `PortalFOIARequest.recordSearchDateFrom` / `recordSearchDateTo`, `PortalSubjectAccessRequest.signatureDate`, `PortalPersonDTO.dateOfBirth` | **No** — the behaviour is the Java 8 base commit's own, and it is preserved deliberately |
| The raw portal payload travels in the `submitInquiry` failure message | `FOIAPortalRequestServiceProvider:300-302`, `SARPortalRequestServiceProvider:302-304` | **No** — a different endpoint from the one this change set had to touch |
| Two git-sourced asset repositories carry lifecycle scripts that cannot run on Node 20 | `@bower_components/angular-xeditable` and one other git dependency's development tree | **No** — `--ignore-scripts` is the documented install flag, and nothing those scripts produce is consumed |

### The compressor closes a stream and then finishes it again

`FolderCompressorTest.testCompressFolderMaxSize` in `acm-services/acm-service-compress-folder` ends in a `NullPointerException` carrying the message `Deflater has been closed`. The defect is in production code, not in the test, and the register names that location because [the baseline record](baseline-test-failures.md) owns the stack trace rather than the source:

- `DefaultFolderCompressor.compressFolder` opens a `ZipOutputStream` over a `MaxThroughputAwareFileOutputStream` in a try-with-resources at `:215-219`.
- `MaxThroughputAwareFileOutputStream.write` throws an `IOException` at `:123` as soon as the configured size limit is exceeded — which is precisely what this test provokes.
- The per-entry `catch (IOException)` inside the private `compressFolder(zos, …)` overload at `:386-391` **swallows** that failure: it logs a warning and lets the loop continue. `copy` is `org.apache.commons.io.IOUtils.copy`, statically imported at `:32`, and closes nothing itself.
- The try-with-resources then closes the `ZipOutputStream` on the way out, and `close()` runs `finish()` over a deflater the failing path has already ended. The JDK raises the `NullPointerException` from there.

**Why it does not block a validation item.** It is one of the four measured baseline failures, and its owning class is one of the two class-level entries in the surefire `<excludes>` block at `pom.xml:366-367`, so validation item 1 exits 0 with it in place. The failure is **identical on JDK 8 and JDK 17**, differing only in library-internal line numbers, which is what qualifies it as pre-existing rather than migration-attributable. The exclusion accounting, the two narrower alternatives that were rejected on evidence, and the collateral cost of a class-level exclusion are all in [the baseline record](baseline-test-failures.md) and are deliberately not repeated here.

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

Maven names line 109 — the second declaration — which is the citation above confirmed by the tool itself. The effective model is worth recording too, because it shows what the duplicate actually costs: `help:effective-pom` carries the dependency **twice**, and both copies resolve to `<scope>provided</scope>` from the managed entry at `pom.xml:1237-1242`. The narrower `test` scope written at `:92` is therefore silently discarded, and a `provided` dependency is never packaged, so no artifact content changes either way.

**Why it does not block a validation item.** The build succeeds, the artifact is unaffected, and no test or audit touches it. Under R-6 it stays documented. Maven's own caution in that third warning line is nevertheless a real forward risk rather than boilerplate — a future Maven may refuse to build such a model — and the right time to act on it is a POM-hygiene change with its own review, not a runtime migration.

### The build injects licence headers into tracked sources

`org.codehaus.mojo:license-maven-plugin:1.16` is declared at `pom.xml:468-496` with its `update-file-header` goal bound to the `process-sources` phase and its includes set to `**/*.java` and `**/*.jsp`. Any matching file that lacks the ArkCase header therefore gains one during **every** build, stamped with the current year.

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
| The same tree after `npm ci --ignore-scripts` and `npm run build` in the frontend root | **332,662,877 B** | 21,994 | **19,401 entries, 47,921,835 compressed bytes** (plus the 11 built bundles under `assets/dist/`, a further 4,872,960 compressed bytes) |

Git never notices, and that is what makes it easy to miss: `node_modules` is ignored at the base commit, so `git status` stays clean while the packaged artifact grows by roughly **57 MB** — 46 MB of it `node_modules` alone. `.gitignore` is not an input to the war plugin.

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

**Why it is documented rather than fixed.** The fix is a single line — register a `JavaTimeModule` on those two mappers — and it is exactly what R-7 forbids: it would start accepting ISO-8601 date strings that the base commit rejected, widening the published request contract, which the REST-contract preservation mandate also forbids. What the migration *did* have to fix is a different defect on the same path, where Java 17 broke even the payloads that used to work; that repair reproduces this rejection deliberately rather than removing it, and it is recorded as [decision 20](behavioral-decisions.md).

**What a maintainer should know.** If the portal is meant to submit those dates, this is a genuine functional gap and it predates Java 17 by years. Closing it is an API decision — pick and publish a date representation — not a migration task, and it needs the portal side changed with it.

### The raw portal payload travels in the `submitInquiry` failure message

`submitInquiry` in both portal providers logs and propagates the **entire raw request body** when deserialisation fails: `log.warn("Error deserializing raw request [{}] …", rawRequestContent)` and the same content inside the `PortalRequestServiceException` message. Portal content carries names, addresses, dates of birth and file payloads, so this is CWE-532 in the log and CWE-209 in the propagated message. The same code also passes one argument to a three-placeholder format string, so the message it produces is malformed as well.

**Why it is documented rather than fixed.** It is pre-existing base-commit code on the **inquiry** endpoint, which no finding in this change set touches. The identical pattern on the **request** endpoint was removed, because that path had to be reworked for Java 17 anyway and leaving personal data in a message the migration made reachable more often would have been a deliberate choice; that boundary is [decision 21](behavioral-decisions.md). Extending the same repair here would be an opportunistic fix, which R-6 forbids.

**What a maintainer should know.** The remedy is the one already applied next door: keep the portal and user identifiers, drop the payload, and fix the placeholder count while doing it.

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

None of them blocks a validation item, and the reason is the same in every case, so it is stated once here rather than repeated fourteen times: **validation items 1 to 3 are a compile, a test run and a text search, none of which reaches these code paths, and items 4 and 5 are evaluated against a reduced local stack that has no Alfresco, no Solr and no Pentaho** (see [the smoke record](smoke-evidence.md)). Where an item *does* interact with something that was executed, the entry says so explicitly instead of leaning on the general clause.

Each entry carries a **follow-up condition**: what would have to be true for the repair to be in scope. That is deliberate. R-6 asks for documentation rather than repair *now*; it does not ask for the knowledge to be lost.

### ActiveMQ: acknowledgement happens before durable processing

| Where | What |
| --- | --- |
| `AcmObjectBrokerClientListener.java:60-123` | `onMessage` unmarshals the payload and then hands the work to `broker.getExecutor().execute(...)`, so the JMS delivery completes on the listener thread while the real processing runs later on a pool thread. The `message.acknowledge()` inside that task (`:113`) is reached only after the handler returns `true` |
| `AcmObjectBrokerClient.java:74-103` | The listener container is created with `Session.AUTO_ACKNOWLEDGE` semantics, which is what makes the later `acknowledge()` call inert. **Measured, not inferred:** the executed transit in [the smoke record](smoke-evidence.md#2b-the-activemq-message-transit-executed-not-argued) printed `listener session ack : 1`, and `1` is `AUTO_ACKNOWLEDGE`. The same constructor also calls `setMessageListener(...)` and `init()` **before** any handler can be injected, and the two concrete subclasses then call `start()` from their own constructors — `FOIARequestBrokerClient.java:62-67` and `SARBrokerClient.java:62-67` — so a message can in principle be delivered to a half-built object |
| `AcmFileBrokerClient.java:167-188` | The pull consumer calls `message.acknowledge()` at `:173` immediately after `consumer.receive(2000)` and **before** `FileUtils.copyInputStreamToFile(...)` at `:185` writes the blob to disk, so a failure during the copy loses the file. The `receive` is a timed poll, and its result is dereferenced at `:175` with **no null check**, so an empty queue produces a `NullPointerException` rather than a clean "nothing to do" |
| `AcmFileBrokerClient.java:240-264` | The session is created as `createSession(false, Session.AUTO_ACKNOWLEDGE)` at `:247`, which is the acknowledgement mode that makes the ordering above unrecoverable |

**Impact.** Loss of a message, or of an uploaded file, on any failure between delivery and the end of processing — silently, because acknowledgement has already happened. Redelivery and dead-lettering cannot help, since the broker considers the message consumed. The executed transit shows the happy path working; it says nothing about the failure path, and this entry is precisely about the failure path.

**Follow-up condition.** A repair changes acknowledgement semantics, which is observable wire behaviour toward the broker and therefore forbidden by the preservation mandate until a plan approves it. The shape it would take: process on the listener's own transaction/thread or hand off transaction-aware, acknowledge only after durable success, configure redelivery and a dead-letter destination, move `start()` out of the constructors to a post-injection lifecycle callback, and null-check the timed `receive`. It needs an integration test against a real broker per flow, with the ack/redelivery behaviour captured before and after.

### JMS producers swallow delivery failures

| Where | What |
| --- | --- |
| `SendDocumentsToSolr.java:112-167` | Three `sendToJmsQueue` overloads (`:112`, `:132`, `:150`) each wrap `getJmsTemplate().convertAndSend(...)` in `try { … } catch (JmsException e) { log.error(...) }`. The caller cannot tell that nothing was sent |
| `ChangedParticipantToJmsSender.java:57-76` | The same pattern for participant-change notifications |
| `ZylabProductionSyncStatusToJmsSender.java:54-72` | The same pattern for ZyLAB production status |

**Impact.** Upstream work commits while its downstream notification never leaves the process, so the index or the peer system drifts from the database with nothing in the request path to notice. It is only visible as a log line.

**Follow-up condition.** Propagating the failure changes transactional outcomes for callers that currently succeed, so it needs a plan and a per-caller decision: a typed exception, or an outbox row committed with the work and retried by a scheduler. Either way the retry behaviour must be observable rather than logged.

### Solr: retryable and non-retryable failures are not distinguished

| Where | What |
| --- | --- |
| `SolrRestClient.java:54-135` | Both `postToSolr` overloads treat **4xx and 5xx alike** — `isUnRecoverable` at `:140-143` is `status.is4xxClientError() \|\| status.is5xxServerError()` — and send the payload straight to a `DLQ.`-prefixed destination with no retry, so a transient 503 is dead-lettered exactly like a permanent 400. The DLQ message is `entity.getBody()` only, so the original correlation and headers are dropped |
| `SolrPostQueueListener.java:49-67` | The listener rethrows **only** when the cause chain contains a `ConnectException` (`:62-66`); every other transport failure is logged and the transacted session commits, so the message is gone |
| `SolrPostContentFileQueueListener.java:51-69` | The same narrow rethrow for content-file posts |
| `ContentFileSolrPostClient.java:103-119` | `applicationEventPublisher.publishEvent(new EcmFileContentIndexedEvent(...))` at `:118` fires after `postToSolr` returns, and `postToSolr` returns normally on the dead-lettered 4xx/5xx path — so a **content-indexed event can be published for a document Solr never accepted** |

**Impact.** Search silently misses documents the application believes are indexed, and a transient Solr outage produces dead-lettered work that no retry will pick up.

**Follow-up condition.** Retry, dead-letter and event-emission behaviour toward Solr are all wire-visible, so this needs an approved plan plus a live Solr in the validation stack — which the reduced local stack does not have. The shape: roll back retryable failures, separate 4xx from 5xx, preserve the original work and correlation in the DLQ payload, and emit the indexed event only on a confirmed 2xx.

### Configuration server: a mandatory dependency fails open

| Where | What |
| --- | --- |
| `ConfigurationServiceBootClient.java:247-294` | `getRemoteEnvironment` maps over the application names in a `parallelStream`, and its per-element `try` catches **`Throwable`** (`:281-285`), logs it and returns `null` into the result list |
| `ConfigurationServiceBootClient.java:101-110` | `loadConfiguration` then iterates that list and calls `getCompositeMap(environment)` on each element, so a failed fetch surfaces later as a `NullPointerException` or, worse, as a silently partial configuration |
| `ConfigurationServiceBootClient.java:86-99` | `configRestTemplate()` sets a 60-second **read** timeout on a `SimpleClientHttpRequestFactory` and **no connect timeout**, so a black-holed config host stalls startup indefinitely |

**Impact.** ArkCase reads all of its configuration from this server. Failing open here means the application can start with part of its configuration missing and behave inexplicably, instead of refusing to start with a message that names the endpoint.

**Follow-up condition.** Turning a null into a startup-fatal exception changes startup behaviour, which is exactly what a runtime migration must not perturb while it is being reviewed. The shape: finite connect and read deadlines, bounded retry, rejection of null or empty responses, and a fatal exception that preserves endpoint, profile and cause.

### Configuration server: a JMS-supplied filename controls a URL segment and a local path

| Where | What |
| --- | --- |
| `FileConfigurationServiceImpl.java:88-105` | `getFileFromConfiguration(String fileName, String customFilesLocation)` interpolates `fileName` **unvalidated** into the config-server URL it builds at `:97-101` and into `new File(customFilesLocation + "/" + brandingPath + "/" + fileName)` at `:103`, then writes the response body there with `FileUtils.copyInputStreamToFile` at `:105` |
| `FileConfigurationServiceImpl.java:109-123` | The caller is a `@JmsListener` on `VirtualTopic.ConfigFileUpdated` whose payload *is* the filename (`:112`), so the value arrives from the message broker |

**Impact.** CWE-22. A filename containing `../` or an absolute path lets anyone who can publish to that topic write the fetched bytes outside the branding directory, with the container's privileges. The two extension checks at `:113-122` filter rule and stylesheet files; they do nothing about separators or dot segments.

**Follow-up condition.** This is the entry most worth escalating out of R-6 rather than leaving to a later migration: it is a write primitive reachable from a message. The repair is self-contained — reject separators, absolute paths and dot segments, URL-encode the path segment, canonicalize the destination and enforce that it stays under the allowed root — but it changes an input contract, so it needs its own review with a test per rejected form.

### CMIS / Alfresco: the configured timeout does not reach the HTTP layer

| Where | What |
| --- | --- |
| `ArkCaseCMISConfig.java:68-69` | `cmis.timeout` is a configuration property of the repository config |
| `CamelContextManager.java:183` and `:215` | …and it is consumed **only** as the Camel route and queue wait, through `newInstance(template, id, repositoryConfig.getTimeout())` and `setTimeout(...)` |
| `ArkCaseCMISSessionFacade.java:54-69` | `initSession` builds the OpenCMIS session parameter map with binding type, ATOMPUB URL, user, password and HTTP invoker class — and **no** `SessionParameter.CONNECT_TIMEOUT` or `READ_TIMEOUT` |
| `CamelBasicAuthenticationHttpInvoker.java:128-138` | The invoker reads both parameters from the session with a default of `-1`, and since nothing ever puts them there, both stay `-1`: **unbounded** connect and read |

**Impact.** A hung or half-open Alfresco connection holds an ArkCase thread indefinitely. The SEDA wait bounds how long a caller waits for the queue, not how long the HTTP call may hang, so thread exhaustion under a slow content repository is reachable.

**Follow-up condition.** Needs a live Alfresco to validate against, plus separate validated connect and read values mapped into every OpenCMIS session while the existing queue wait is retained. Absent from the reduced stack, so it cannot be exercised here.

### Alfresco RMA: the metadata call bypasses the authentication-aware client

| Where | What |
| --- | --- |
| `SetRecordMetadataService.java:51-65` | The class extends `AlfrescoService`, which supplies a Kerberos-aware `RestTemplate`, and then builds its **own** plain `new RestTemplate()` in its constructor at `:62-65` |
| `SetRecordMetadataService.java:102-124` | That plain template is what posts the record metadata at `:104`, so the call carries neither the inherited authentication nor any timeout policy |

**Impact.** On a Kerberos-protected Alfresco the metadata update fails while the rest of the integration works, and the failure surfaces as an opaque `AlfrescoServiceException`. On any Alfresco the call is unbounded in time.

**Follow-up condition.** Switching clients changes the credentials on the wire, so it needs a Kerberos-enabled Alfresco in the validation stack.

### Alfresco LDAP sync: the failure callback dereferences a context it does not have

| Where | What |
| --- | --- |
| `AlfrescoLdapSyncer.java:93` | The caller captures `Authentication authentication = SecurityContextHolder.getContext().getAuthentication()` **before** dispatching, and `onSuccess` uses that captured value at `:112` |
| `AlfrescoLdapSyncer.java:123-133` | `onFailure` ignores the captured value and re-reads `SecurityContextHolder.getContext().getAuthentication()` **on the callback thread** at `:127`, where no context has been propagated, then calls `.getName()` on it at `:128` |

**Impact.** The sync failure that the callback exists to report is replaced by a `NullPointerException` inside the callback, so the operator sees the wrong error and no `AcmServiceLdapSyncEvent` is published.

**Follow-up condition.** A one-line repair, but it changes an error path that no test covers and no reduced-stack flow reaches. It belongs with the broader outbound-HTTP work below, where the same class needs deadlines anyway.

### Outbound HTTP: no deadlines, no bounded retry, no lifecycle ownership

| Where | What |
| --- | --- |
| `SetRecordMetadataService.java:62-65`, `AlfrescoLdapSyncer.java:75`, `ReportServiceImpl.java` (Pentaho), the Okta, OAuth/ZyLAB, OnlyOffice, AWS transcript and Solr clients | Each constructs its own `RestTemplate`, `AsyncRestTemplate` or `HttpURLConnection` with default (infinite) connect and read timeouts, no bounded retry, no circuit breaker, and no lifecycle close. `ConfigurationServiceBootClient.java:86-99` is the one place that sets any deadline at all, and it sets only the read half |

**Impact.** Any slow or black-holed peer can hold ArkCase threads until the container is exhausted; because the clients are constructed per class rather than owned centrally, there is no single place to fix it and no consistent policy to audit.

**Follow-up condition.** This is a resilience programme rather than a defect fix: lifecycle-owned clients, finite deadlines, bounded jittered retry, bulkheads or circuit breakers, and closed resources — with load evidence. It touches every integration boundary, so it needs its own plan; doing it inside a runtime migration would make both unreviewable.

### OnlyOffice: the callback is trusted before it is verified

| Where | What |
| --- | --- |
| `OnlyOfficeApiController.java:72-89` | `callbackHandler` accepts the document server's `Authorization` header as a parameter and **never uses it** — the code says so itself at `:81`, `// TODO verify callback token and data are matching` — and proceeds to a permission check derived from the caller-supplied `key` |
| `CallbackServiceImpl.java:72-101` | `handleCallback` has `if (config.isInboundVerifyEnabled()) { // TODO verify callback data in token are equal as provided }` at `:77-80`: the verification switch exists and does nothing |
| `CallbackServiceImpl.java:140-190` | `handleReadyForSaving` opens `new URL(callBackData.getUrl()).openConnection()` at `:144-146` and streams the response straight into `ecmFileService.update(...)` at `:161`, with no origin allowlist, no replay defence and no timeout on the connection |
| `DocumentHistoryManagerImpl.java:72-114` | The history path fetches `changesUrl` the same way and with the same absence of checks |

**Impact.** A caller who can reach the callback endpoint can make ArkCase fetch an arbitrary URL (SSRF) and store the result as a document version, and can replay a previous callback. The signature the document server sends is available and ignored.

**Follow-up condition.** The highest-severity item in this register alongside the path traversal above, and like it, the repair is self-contained: verify the token first, bind its claims to the key, status and URLs, reject replays, allowlist the document-server origin, and bound the fetch. It changes a request contract, so it needs its own review and a test per rejected case.

### XML transformation: the external-access hardening fails open

| Where | What |
| --- | --- |
| `NiemExportServiceImpl.java:243-251` | The three `factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_*, "")` calls sit in a `try` whose `catch (IllegalArgumentException)` body is empty apart from a `// TODO: handle exception` marker, so a `TransformerFactory` that rejects the attributes leaves the transformer **unrestricted** and processing continues |
| `PdfServiceImpl.java:145-153` | The identical pattern for the PDF stylesheet transformer |

Note for reviewers: this migration *does* touch both files — one comment line each, to clear the JDK-internal-API audit, recorded in [the static audit](static-audit.md). The empty catch below that comment is base-commit code and is deliberately untouched.

**Impact.** XXE and SSRF exposure through DTD, schema or stylesheet resolution on whichever JAXP implementation happens to be first on the classpath — silently, since the failure to harden is swallowed.

**Follow-up condition.** Failing closed changes behaviour on any runtime where the attributes are unsupported, which is precisely the kind of change a runtime migration must not smuggle in. The shape: fail closed or instantiate a provider proven to support the restrictions, and log the provider and the root cause.

### Pentaho report XML is re-encoded through the platform default charset

| Where | What |
| --- | --- |
| `ReportServiceImpl.java:146-161` | The response is decoded correctly with `EntityUtils.toString(entity, "utf-8")` at `:151`, and then at `:160` the already-decoded string is round-tripped as `new String(xml.getBytes(), StandardCharsets.UTF_8)` — and `String.getBytes()` with no argument uses the **platform default** charset |

**Impact.** On a JVM whose default charset is not UTF-8, non-ASCII characters in report definitions are mangled before parsing. On this environment it is latent, because the default is already UTF-8.

**Follow-up condition.** Use the decoded string directly. Trivial, but it is a behaviour change on non-UTF-8 hosts and no validation item reaches it, so it waits for an approved change.

### FOIA correspondence: an empty e-mail address passes the guard, and failures are swallowed

| Where | What |
| --- | --- |
| `FOIAQueueCorrespondenceService.java:246-280` | `emailCorrespondenceLetter` guards with `if (emailAddress != null \|\| emailAddress != "")` at `:249`. The condition is a tautology — a reference comparison OR'd with a null check — so an **empty** address proceeds to the inner `if (emailAddress != null)` and an e-mail is attempted with no recipient. Inside, a template failure is caught at `:262-269` and replaced with a fallback body, with a comment stating that failing to send must not break the flow |

Note for reviewers: this migration changes **one** predicate in this file, in a different method — the `getInlineImageMap`-adjacent notification guard now uses `StringUtils.isNotEmpty` — because removing the FastInfoset dependency required it. That changed line is semantically exact and is *not* this defect. The tautological guard at `:249` is base-commit code.

**Impact.** A recipient-less send attempt that fails downstream, and a template failure that silently degrades the e-mail body rather than surfacing.

**Follow-up condition.** A non-blank check plus observable failure handling — an approved behavioural change, since it turns a silent path into a reported one.

### The event multicaster is production-dormant

| Where | What |
| --- | --- |
| `spring-library-acm-web.xml:19-44` | The **only** `DistributiveEventMulticaster` bean, and the `asyncAplicationListenerExecutor` it depends on, are inside an XML comment |

**Impact.** None at runtime — and that is the point. This migration adds the two `Predicate`-based methods Spring 5.3.5 introduced to `ApplicationEventMulticaster`, without which `acm-web` does not compile; the class they were added to is not wired into a deployed context, so **no asynchronous event routing is active in production** and the migration neither enables nor changes that. Anyone reading the new methods as a live behavioural change is misreading them.

**Follow-up condition.** If asynchronous listener routing is actually wanted, the bean has to be enabled and integration-tested with exception and ordering baselines captured first. That is a feature decision, not a migration one.

### Deploy-time front-end driver: no command deadline, and unchecked deletions

| Where | What |
| --- | --- |
| `AngularResourceCopier.java:386-423` | `runFrontEndBuildCommand` runs the install, the config merge and Grunt through a bare `DefaultExecutor` with **no watchdog**, so a hung child process blocks webapp startup indefinitely. Base-commit code: the same bare executor is at `c8f6226105:…:329` |
| `AngularResourceCopier.java:215-227` and `:333-344` | Two prune loops end in `.forEach(File::delete)` and **ignore the boolean result**, so a failed deletion leaves a stale asset behind silently and the deployment continues with a mixed-version tree. Base-commit code at `:166` and `:282` |

**Impact.** A deployment that hangs with no diagnostic, or one that appears to succeed while serving a stale asset. The migration changes the *command* this driver runs — `npm ci --ignore-scripts` instead of the yarn invocation — and the lockfile name in the prune whitelist; it changes neither the timeout behaviour nor the deletion handling.

**Follow-up condition.** Configurable Commons Exec watchdogs that kill only the child on expiry, plus checked `Files.delete`/`deleteIfExists` that fails the deployment naming the path and cause. Both change startup failure modes, so they need a plan and a deployment test.

### Multi-profile front-end deployments omit extension and custom assets

This is the register's entry for the `config/config.js` profile-iteration defect, and it is stated here in impact terms because the [frontend defects](#frontend-defects-documented-not-fixed) table above states it in mechanical terms.

`config/config.js:110` iterates `activeProfiles`, which is `{ profiles: [ … ] }`, so lodash binds `profile` to the **array**; `:160` does the same for CSS. With two profiles the prefix stringifies to a comma-joined value such as `foia,custom`, and every glob built from it matches nothing. Independently, the four `concat` results at `:120`, `:131`, `:142` and `:164` are discarded, so even a correctly-derived custom file list would not reach the bundle.

**Impact — corrected, because an earlier revision of this page understated it.** This is **not** merely latent. `AngularResourceCopier.java:196-205` genuinely emits more than one profile: it writes the active Spring profiles and then appends `custom`, so a deployment running the `extension-foia` or `extension-privacy` profile — both of which exist in this repository, wired in `spring-extension-library-message-broker.xml` and its privacy counterpart — produces `{ profiles: [ 'extension-foia', 'custom' ] }` and therefore **loses both the extension assets and the customer assets** from `application.js`, `application.min.js` and `home.html`. The single-profile fresh-checkout case that the frontend evidence exercises is the *only* case in which the defect is invisible, which is exactly why it survived. What is latent is the null-join in the Gruntfile, not this.

**Follow-up condition.** Iterate `activeProfiles.profiles` and assign the `concat` results — then rebuild and diff the emitted bundles for a two-profile deployment against a baseline capture, because the fix by construction **adds** files to the bundle, which is a behavioural change the preservation mandate forbids without a plan. It also needs a multi-profile deployment to validate against; the fresh-checkout evidence in [the smoke record](smoke-evidence.md) cannot cover it.

### CI: feature pipelines collect no WAR

| Where | What |
| --- | --- |
| `.gitlab-ci.yml:71-77` | The `.build_artifact` template, which `.build_feature` extends for `feature/*` branches, declares `artifacts.paths: target/*.war`. The reactor root is `pom` packaging and the WAR is written to `acm-standard-applications/arkcase/target/`, so the glob matches nothing and a feature pipeline publishes no artifact |

**Impact.** Feature branches produce no downloadable WAR. Nothing else is affected: the snapshot job that actually ships (`.build_backend_snapshot`) uses the correct nested path in its SFTP command at `:67`, and so do all three release jobs in `.gitlab-ci-release.yml`.

**Why it is not fixed here, stated precisely.** The glob is **byte-identical at the base commit**, so it is a pre-existing defect and R-6 governs it. It blocks no validation item: the migration's build gate is `mvn clean install`, which writes the WAR at its unchanged path regardless of what CI archives. This migration does edit this file — the runner image pin and the removal of a JVM flag JDK 17 rejects — and repairing an unrelated line in the same edit is the specific thing that made the launch-block repairs a finding of their own. Fixing it is a one-line change once a plan authorises it: point the path at `acm-standard-applications/arkcase/target/*.war`, keeping the artifact name.

### Two integration-test profiles pin a Java-8-era Failsafe

| Where | What |
| --- | --- |
| `acm-standard-applications/acm-foia/pom.xml:30-33` and `acm-standard-applications/acm-privacy/pom.xml:27-30` | Both declare `maven-failsafe-plugin` **2.17** inside a `coreBuild` profile. Where that profile is active the hardcoded version wins over the root POM's `${surefire.version}` pin, so those integration tests would run on a 2014 runner that predates the late `@{argLine}` substitution the JDK 17 module-access directives depend on |

**Impact.** Confined to `-DcoreBuild=true` builds. Both profiles activate only on that property, and both configure `skipTests=true` inside it, so nothing in the migration's validation path loads the old plugin.

**Follow-up condition.** Replacing `2.17` with `${surefire.version}` in both files is the obvious repair and was **deliberately reverted** from this change set: the plan maps the root `pom.xml` as the only POM this migration touches, and unplanned child-POM edits are exactly what the review flagged. It belongs in the next plan, together with a `-DcoreBuild=true` run to prove the profile still behaves.

## Database and schema-authority defects — documented, not fixed

Three defects sit in the database authority — the ORM mappings, the Liquibase changelogs and the stored routines. **This migration changes none of it.** The schema, the effective DDL of the persistence mappings and every one of the 223 changelogs are on the preservation list, so R-6's "document, do not fix" applies here with no carve-out available: none of these three blocks a validation item, and the two that look correctable in place are the two where correcting them in place would do measurable harm — a claim this page substantiates rather than asserts.

Each entry below was reproduced twice — once by reading the authority in the tree, and once by executing it. The execution ran against the reference stack's MariaDB 10.6 on **isolated scratch databases** created and dropped for the purpose, with the pinned Liquibase 3.1.1 taken from the build's own dependency set. The reference `arkcase` database was read, never written.

| Defect | Location | Blocks a validation item? |
| --- | --- | --- |
| A mapped collection table that no changelog creates | `PortalSARPerson.java:64-68` — collection table `acm_sar_person_portal_roles`; no schema authority anywhere | **No** — the stack exercised for items 4 and 5 runs the core profile, so the privacy beans that touch the mapping are never instantiated, and no smoke flow performs a portal registration |
| A malformed column type in an active fresh-schema changeSet | `acm-portal-gateway-tables-1.0.xml:53` — `VARCHAR(${cmGroupNameLength}))`, one closing parenthesis too many | **No** — and it is genuinely exercised rather than merely untouched: the changeSet is recorded `EXECUTED` on the reference database, because Liquibase 3.1.1 normalises the stray parenthesis away |
| Median stored routines with an unvalidated identifier surface, a cleanup statement that cannot run, and an OUT parameter that is never assigned | `foia-db-procedures-1.0.xml:10-55` and the byte-identical `privacy-request-db-procedures-1.0.xml` | **No** — the routines install only under the `extension-foia` or `extension-privacy` profile, and `information_schema.ROUTINES` on the reference database is empty |

### A mapped collection table that no changelog creates

`gov/privacy/model/PortalSARPerson.java:64-68` maps a collection table that does not exist in this repository's schema authority:

```java
@ElementCollection
@CollectionTable(name = "acm_sar_person_portal_roles", joinColumns = @JoinColumn(name = "cm_person_id", referencedColumnName = "cm_person_id"))
@MapKeyColumn(name = "cm_portal_id")
@Column(name = "cm_user_role")
private Map<String, String> portalRoles = new HashMap<>();
```

`git grep acm_sar_person_portal_roles` over every tracked file returns **exactly one hit outside this register** — the annotation above. None of the **223** Liquibase changelogs creates the table, and the privacy extension cannot supply it from anywhere else: its only tables changelog, `privacy-request-db-tables-1.0.xml`, holds 14 changeSets and **zero** `createTable` elements — every one of them alters a core table — and its master, `acm-extension-privacy-database-changelog.xml`, includes the core changelog at `:6` plus the privacy and `custom` paths only, never the FOIA paths.

**No repository mechanism fills the gap at runtime either**, which is the half that makes the mapping load-bearing rather than harmless. `generateDdl` appears exactly once in the whole repository — `spring-library-data-source.xml:142`, set to `false`, inside the `EclipseLinkJpaVendorAdapter` bean at `:140-144` — and there is no `eclipselink.ddl-generation`, `hbm2ddl` or `create-tables` property anywhere. The provider is `org.eclipse.persistence.jpa.PersistenceProvider` (`:52`) with `eclipselink.weaving` off (`:55`), so schema comes solely from the `SpringLiquibase` bean at `:164-167`. Liquibase is the only authority, and it has nothing to say about this table.

The mapping is not dormant. `gov/privacy/service/SARPortalUserServiceProvider` reads the map at `:181`, `:302`, `:330-331`, `:1011` and `:1017`, and writes it at `:340`, `:405`, `:524` and `:1086`; the write at `:524` is followed immediately by `portalPersonDao.save(portalSARPerson)` at `:525`, so the persist path would emit an insert against the absent table. `@ElementCollection` declares no fetch mode, so JPA's `LAZY` default applies and a read is deferred until the map is touched — which those call sites do. Both beans are registered inside the Spring profile `extension-privacy`, at `spring-extension-library-privacy.xml:50` and `:52`, so the exposure is a privacy-profile deployment specifically.

One detail is worth recording because it shows the shape of the underlying mistake. The FOIA side is the **exact mirror image**: `foia-request-db-tables-1.0.xml:591-597` does create `acm_foia_person_portal_roles` with `cm_person_id`, `cm_portal_id` and `cm_user_role`, and `foia-request-db-sql-1.0.xml:77-83` queries it — while `gov/foia/model/PortalFOIAPerson.java:57` maps a single `@Column(name = "fo_portal_role")` string and no collection at all. FOIA has the table without the mapping; privacy has the mapping without the table.

**Why it does not block a validation item.** Items 1 through 3 never touch a database. Items 4 and 5 are themselves recorded as **constrained** in [the smoke evidence](smoke-evidence.md), and the stack they *were* exercised on runs with `spring.profiles.active=ldap` — the **core** profile — so the two beans that touch the mapping are never instantiated, the entity is not reachable and no portal registration flow executes. Nothing in the migration went near this file: it is byte-identical to the base commit, as is every changelog that might have created the table.

**What remains for others.** Tracing whether a privacy-profile deployment actually reaches the load or persist path, and whether an external DDL bundle creates the table outside this repository, is an order-1 and QA question, not a documentation one: the repository can prove the absence of schema authority, but only a live privacy-profile environment can prove what the absence costs. **No opportunistic schema edit is made here.** Adding a `createTable` would be a schema change in a migration whose recorded delta is zero added, zero removed and zero changed database elements, and it would ship untested DDL for a path this environment cannot exercise.

### A malformed column type in an active fresh-schema changeSet

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

### Median stored routines with an unvalidated identifier surface and a broken cleanup

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

## Frontend defects — documented, not fixed

All five were verified against the source tree. `Gruntfile.js` has a **zero-byte diff** against the base commit, so its line numbers are identical in both trees; `config/config.js` grew from 140 to 167 lines when the carve-out fix landed, so its numbers are given for the migrated tree with the base-commit line in parentheses.

| Defect | Location | Why it does not block a validation item |
| --- | --- | --- |
| A dead concurrent-task target — `sync-dev` is registered as `['concurrent:default']` while the `concurrent` configuration declares its only target as `default1` | `Gruntfile.js:91` and `:379` | It affects only the `sync-dev` developer-convenience task. No validation item invokes it; the `default` chain at `:376` never touches `concurrent` |
| An eagerly-evaluated path join against a value that can be null — `destPath` is initialised to `null` at `:13` and assigned at `:15` inside a `try` whose `catch` only logs and continues, yet six `path.join(destPath, …)` calls sit in the object literal handed to `grunt.initConfig` and evaluate on every invocation | `Gruntfile.js:104-124`, with `:13-18` | The defect is **latent**: `homedir()` resolves on every supported platform, so the join never receives `null`. Measured on the validated runtime — `homedir()` returns a path and `npm run build` exits 0. Only a host where `homedir()` throws would reach it, and there the `catch`'s stated intent to continue is what the eager joins defeat |
| A lint task that cannot lint JavaScript, and reports success anyway — `lint` is registered as `['jshint', 'csslint']` while the Grunt configuration declares a `csslint` target and **no `jshint` target at all**, so the jshint task aborts with `No "jshint" targets found` and the global force option downgrades that abort to a warning. The plugin is installed and the task is registered; only its configuration is missing | `Gruntfile.js:372`, `:40-47` and `:144` | No validation item invokes `lint` — the `default` chain at `:376` never runs it — so nothing in items 1 through 5 depends on it. The cost is a **false-success gate** rather than a broken build, which is why it is registered here in full rather than noted in passing |
| A loop that iterates the wrapper object rather than its array — `activeProfiles` is `{ profiles: [ … ] }`, and lodash iterates an object's **values**, so `profile` binds to the array and `profile + dir` stringifies it. It works only by accident with a single profile, where `['custom']` stringifies to exactly `custom` | `config/config.js:110` and `:160` (base `:83`, `:133`) | No validation item configures a second profile: the fresh-checkout build this migration validates runs single-profile, so it resolves the same asset paths it always did. **This is not the same as harmless** — a real `extension-foia` or `extension-privacy` deployment runs two profiles and loses assets. The impact is stated in full in [Multi-profile front-end deployments omit extension and custom assets](#multi-profile-front-end-deployments-omit-extension-and-custom-assets) |
| Four discarded non-mutating array concatenations — the results of `jsCustomModules.concat(…)`, `jsCustomDirectives.concat(…)`, `jsCustomServices.concat(…)` and `cssResources.concat(…)` are computed and thrown away | `config/config.js:120`, `:131`, `:142`, `:164` (base `:93`, `:104`, `:115`, `:137`) | The discarded results are additive-only, so the emitted asset set is exactly what it was. Repairing them would *add* files to the bundles, which is a behavioural change the preservation mandate forbids |

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

**Why it is documented rather than repaired.** The defect is pre-existing: the `lint` alias at `Gruntfile.js:372`, the missing jshint target and the global force option are all base-commit conditions, and `Gruntfile.js` is held at a **zero-byte diff** by this migration. It blocks no validation item, so **R-6** applies with nothing to weigh against it. What the migration did change is *reachability*: the base commit's `scripts` block was empty, so this migration is the first time the task can be invoked by name — `lint` is one of the five scripts the change set is specified to declare, and dropping it would breach that specification just as surely as pretending the command works would. Recording it here is the honest third option.

**What a real repair would take**, so the next person does not mistake this for a one-line fix: a `jshint` configuration target covering the application JavaScript, plus failure propagation for that target (the global force option has to stop applying to it, or the task needs its own `force: false`), and then the work of actually clearing whatever the newly-enabled target reports across an application tree that has never been linted. That is a code-quality project with its own behavioural risk, not a runtime-migration change — which is exactly why it is scoped out here. Until it is done: **do not treat `npm run lint` as evidence of anything.**

### The module-config copy warning, deliberately not silenced

The final task of the `default` chain writes the module manifest unconditionally at `Gruntfile.js:349`, and its target `modules_config/config/modules.json` (declared at `config/env/all.js:10`) exists only inside the deploy-time assembly folder that the Java resource copier creates. In a bare checkout the write therefore fails, and `grunt.option('force', true)` at `Gruntfile.js:144` absorbs it. Measured verbatim from `npm run build` on Node v20.20.2:

```text
Running "copyToModulesConfigFolder" task
Warning: ENOENT: no such file or directory, open 'modules_config/config/modules.json' Used --force, continuing.

Done, but with warnings.
```

The command exits **0**.

**Why it does not block a validation item.** Validation item 2 requires `npm run build` to exit 0, and it does — the warning is absorbed, every expected artifact is emitted, and the manifest is written for real at deploy time by the code path that owns it. **It is deliberately left unsilenced**, and that choice is the contrast that shows the line in the next section was drawn on purpose rather than by convenience: this warning is adjacent to the one condition that *was* fixed, it is cosmetically annoying in exactly the same way, and it does not block anything, so it stays.

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
- **The tree is deployed, not dormant.** `lib` appears on three separate copy lists in `acm-user-interface/ark-angular-starter/src/main/resources/spring/spring-web-ark-angular-starter.xml`, at `:50`, `:61` and `:73`, and it is explicitly whitelisted from the temp-folder prune by the `!p.startsWith(libFolderPath)` filter at `AngularResourceCopier.java:158`.

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

Driving the deployed UI in a browser surfaced four pre-existing conditions that a build-only validation never reaches. All four are properties of the base-commit application, none is related to either runtime move, and none is fixed:

| Observation | Detail | Why it does not block a validation item |
| --- | --- | --- |
| The login form's `pattern` attribute is rejected by current Chrome | The e-mail pattern on the username input contains an unescaped `+-` range inside a character class, which current Chrome's stricter regular-expression parsing refuses; the console logs `Pattern attribute value … is not a valid regular expression` | Cosmetic: the attribute is a client-side hint and login succeeds. Fixing it means editing base-commit markup for a browser-version reason, which is outside this migration's scope |
| `plugin/admin/googleAnalytics/config.js` is refused as a script | The endpoint returns **200** but with `Content-Type: application/json`, and the browser refuses to execute it under strict MIME checking, also logging a cross-origin-read-blocking notice | Non-blocking: analytics simply stays uninitialised. It is a server-side content-type mismatch that predates the migration |
| Roughly 43 `Action … was not found in rules list` warnings | One per module route during application bootstrap, from the data-access-rules lookup | Non-blocking: every module link still renders and routes. It is a rules-configuration gap in the external configuration, not application code |
| angular-translate reports no sanitisation strategy | `$translateSanitization: No sanitization strategy has been configured. This can have serious security implications.` | A security-hygiene item in base-commit frontend configuration. It is recorded here rather than fixed because changing the sanitisation strategy changes rendered output, which the preservation mandate forbids; it deserves its own review |

## The one condition fixed under the carve-out

This is the single place where the migration departs from "document, do not fix", so it is stated unambiguously.

**The defect.** At the base commit, `config/config.js:16` reads `var activeProfiles = require('./../profiles');` — an **unconditional** top-level require of a generated module. `profiles.js` is not tracked and is not present in a checkout; it exists only in the deploy-time assembly folder, where `AngularResourceCopier.createProfilesJsFileInDir` writes it immediately before invoking Grunt (base `:206-215`, migrated `:267-276`). That require site is the **only** one for the module anywhere in the frontend tree.

**Why it is a permitted fix rather than a violation.** `config/config.js` is loaded by the `loadConfig` task, which is the *first* entry in the `default` chain at `Gruntfile.js:376`. An unresolvable require there aborts the whole run before any task executes, so a bare checkout **cannot run `npm run build` at all**. That directly blocks **validation item 2** — `npm ci --ignore-scripts` then `npm run build` must exit 0 on Node 20 from a fresh checkout — and a defect that blocks a named validation item is precisely the exception R-6 contemplates. Nothing else on this page is in that position.

**The fix, in two parts.**

- A new prebuild helper, `scripts/ensure-profiles.js`, writes `<frontend root>/profiles.js` when and only when it is absent, emitting the **identical manifest** the Java assembler produces and mirroring its single-profile fallback. It is wired as the `prebuild` script, so `npm run build` runs it automatically.
- A **guarded require** at `config/config.js:35-43` defaults to `{ profiles: [ 'custom' ] }`, the exact value the assembler emits for its own single-profile case. The guard is narrow on purpose: only `MODULE_NOT_FOUND` for this file's own require is defaulted, and every other failure is re-thrown, so a generated module that exists but does not parse still surfaces its real error instead of being silently replaced by a single default profile.

A deployed WAR and a bare checkout therefore follow the same code path, and the generated module wins whenever it is present, so deployed behaviour is unchanged. Measured on Node v20.20.2 with npm 10.8.2 from a clean tree: `npm ci --ignore-scripts` exits 0, then `npm run build` reports `ensure-profiles: created …/resources/profiles.js with profiles [ custom ]` and exits 0.

**Scope discipline.** This is the *only* fix. The module-config copy warning described immediately above is adjacent to it, equally cosmetic and equally easy to silence, and was deliberately left alone — that contrast is the evidence that the line was drawn deliberately rather than stretched to cover whatever was convenient.

**One consequence of the fix, disclosed rather than buried.** The frontend root's `.gitignore` lists only `node_modules/` and is unchanged from the base commit, so the generated `profiles.js` lands in the working tree as an **untracked, non-ignored** file. It joins two pre-existing generated paths in the same condition — `assets/dist/` and `home.html`, both written by the base-commit pipeline and neither ignored — so a post-build `git status` shows three untracked generated paths. This blocks no validation item, and it is **not** repaired here: an ignore-rule change is outside this change set, and R-6's carve-out does not extend to it. It does, however, sharpen the warning above — the licence-plugin header injections are not the only thing a blanket `git add -A` would sweep up.

## Pre-existing test-quality defects — the full register

A code-review pass over the reactor's **407** Java test sources, its **238** test resources and the one Node test source raised **137** test-quality findings — **75 major and 62 minor**. Every one of them lives in a test source or test resource that this migration **never touched**, and that claim is checkable rather than asserted: `git diff c8f6226105..HEAD -- '*src/test*'` lists exactly five paths, all of them **new** files added to cover this change set's own source edits, and not one modification to a pre-existing test. Each finding below was spot-verified against the migrated tree to confirm the file is byte-identical to the base commit.

They are registered here, unfixed, and the reason is not discretion:

- **AAP §0.2.1.3** states the position without qualification — *"No test source file is modified. All 402 test sources keep their assertions byte-identical."*
- **AAP §0.2.4.2** lists *"Existing test assertions"* among the preservation mandates and adds that *"modification of any of these is a defect, not a scope choice."*
- **AAP §0.8.1** records how that mandate is enforced: *"no test source file is modified at all."*
- **R-6** requires a pre-existing bug found during this work to be documented rather than repaired, with one carve-out for a bug that blocks a validation item.
- **R-5** forbids disabling a failing test and limits exclusions to the four measured baseline failures.

So the carve-out is the only door, and none of these 137 goes through it: the configured unit suite exits 0 with zero failures and zero errors, `npm ci` and `npm run build` exit 0, the static audit returns zero hits, and the artifact assembles — every validation item passes **with all 137 defects present**. That is precisely what makes them pre-existing rather than blocking, and precisely why repairing them here would make this change set unreviewable: a suite that was rewritten in the same commit as a compiler contract and a dependency surface can no longer tell you which of the three moved a behaviour.

### What these defects actually cost

It matters that this register is not read as a style complaint, because the finding classes are substantive and they bear on how much confidence the green suite deserves:

| Class of defect | Roughly how many | What it means for the suite's value |
| --- | --- | --- |
| **Expected-exception false positives** — `@Test(expected = ...)` or a bare `try/catch`, with the verification and assertions placed after the throwing call | ~20 | The assertions are unreachable. The test passes when production throws for *any* reason, including a reason unrelated to the case, and it also passes when the mock expectations it set were never met |
| **Vacuous tests** — no assertion at all, or only `assertNotNull`, a size check, `count >= 0`, or a `System.out` print | ~30 | Cannot fail for the reason the test exists. `numFound >= 0` and `count >= 0` are tautologies |
| **Unverified mock expectations** — expectations recorded and replayed, `verifyAll` never called | ~20 | Zero interactions pass. The test proves nothing about what production called |
| **Fixture defects** — an object added twice where two distinct ones were intended, IDs written into the wrong map, a mock configured but never injected, aliased source and result objects | ~15 | The test exercises a different scenario from the one its name claims, usually a weaker one |
| **Negative tests that configure the positive path** — a "not found" case that stubs a successful lookup and a successful delete | ~10 | The error contract is entirely uncovered while appearing to be covered |
| **Global-state leakage** — an authentication left in `SecurityContextHolder`, the JVM default time zone changed and not restored, MDC and system properties not cleaned up | ~15 | Order-dependent results, and false authorization positives that depend on which test ran first |
| **Non-determinism** — fixed `Thread.sleep` waits, unseeded random inputs, `new Date()` on both sides of a comparison, an unsynchronised `HashSet` used as a concurrency oracle | ~12 | Flakes, and a concurrency test whose oracle is itself racy |
| **Class-level `@Ignore`** on substantive suites | 21 skips across 9 classes | Named individually in [the baseline record](baseline-test-failures.md). Includes crypto, password migration, Activiti task DAO and 13 FOIA queue rules |
| **Leaked resources in fixtures** | ~15 | Streams opened twice and never closed, temp files never deleted, one ZIP extraction that trusts entry names |

The honest reading is the one the review itself gives: **a zero exit code from this suite overstates confidence.** That conclusion is recorded here deliberately, because it is the durable finding — the suite's *green* status is real, and its *coverage* is weaker than the count suggests, and both facts have to travel together.

### The register

Locations are quoted from the review as repository-relative paths; where the review abbreviated a shared package prefix with `...`, the module heading above the table completes it. Severities are the review's.

#### Forms, Admin, Case File, Complaint, Dashboard, Category, Person

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-001 | MINOR | `acm-forms/acm-form-report-of-investigation/src/test/java/.../ROIServiceTest.java:79-94` | Separate `new Date()` calls make serialization boundary-flaky. Inject/freeze a clock or bracket deterministically. | — |
| Q-002 | MAJOR | `acm-forms/acm-form-close-complaint/src/test/java/.../CloseComplaintServiceTest.java:57-64` | Entire direct form-init test is ignored. | Re-enable with deterministic fixtures. |
| Q-003 | MAJOR | `acm-plugins/acm-default-plugins/acm-admin-plugin/src/test/java/.../GetTranscribeConfigurationAPIControllerTest.java:124-146`; `SaveTranscribeConfigurationAPIControllerTest.java:122-158` | Try/catch negative tests pass if no exception occurs. | Use `assertThrows` or explicit `fail()`, then verify response/interactions. |
| Q-004 | MAJOR | `acm-plugins/acm-default-plugins/acm-case-file-plugin/src/test/java/.../dao/SpelTest.java:65-118` | Diagnostic-only test prints results and asserts nothing. | Assert each fiscal-year boundary. |
| Q-005 | MAJOR | `.../service/SaveCaseFileRulesTest.java:146-154` | `date` invokes no production rule and has no assertion. | Replace with a real due-date rule assertion. |
| Q-006 | MAJOR | `.../service/MergeCaseServiceImplTest.java:101-150` | Expectations are never verified and state assertions are commented out. | Restore state assertions and `verifyAll`. |
| Q-007 | MAJOR | `.../web/api/GetNumberOfActiveCaseFilesByQueueAPIControllerTest.java:98-151` | Helper reassigns list parameters; assertions check the prebuilt mock map rather than parsed response. | Mutate fixtures, exercise mapping, and assert `resultMap`. |
| Q-008 | MINOR | `.../web/api/GetQueuesAPIControllerTest.java:93-120` | Status-only route test never asserts queue JSON/order. | Assert exact body. |
| Q-009 | MINOR | `.../web/api/SplitCaseFilesAPIControllerTest.java:92-135` | Exact authentication/service expectations are not verified. | Add `verifyAll` and inspect captures. |
| Q-010 | MINOR | `.../MergeCaseFileServiceIT.java:154-202`; `SplitCaseFileServiceIT.java:145-180`; `AcmQueueDaoIT`; `CaseFileDaoIT` | MDC/system properties and external config are not restored. | Isolate configuration and add teardown. |
| Q-011 | MINOR | `.../service/CaseFileEventListenerTest` helper | Captured descriptions are not asserted; null/non-case paths do not verify zero interactions. | Assert descriptions and no-op behavior. |
| Q-012 | MAJOR | `acm-plugins/acm-default-plugins/acm-complaint-plugin/src/test/java/.../ComplaintCaptureFileEventListenerTest.java:191-254` | A 10-second wait is compared to 10 milliseconds. | Use `TimeUnit.SECONDS.toMillis` or an injected sleeper. |
| Q-013 | MAJOR | `acm-plugins/acm-default-plugins/acm-dashboard-plugin/src/test/java/.../DashboardPropertyReaderTest.java:132-146` | Checks for a `correspondence` key instead of `type == correspondence`, so removal can fail undetected. | Assert exact remaining types. |
| Q-014 | MAJOR | `acm-plugins/acm-default-plugins/acm-person-plugin/src/test/java/.../DeletePersonByIdAPIControllerTest.java:79-136` | Null collaborator is injected; the not-found test repeats successful deletion and asserts no error. Initialize it, force the real not-found path, and assert response/interactions. | — |
| Q-015 | MINOR | `ComplaintCaptureFileEventListenerTest.java:256-278` | Fixture parser swallows all exceptions and returns null. Fail immediately with cause. | — |
| Q-016 | MINOR | `ComplaintCaptureFileEventListenerTest.java:161-188` | Second save returns the first complaint and captures are only checked for non-null. Return/assert both exact complaints and attachments. | — |
| Q-017 | MINOR | `ComplaintDaoIT.java:88-95` | Fixed one-second setup sleep is nondeterministic. | Synchronize on readiness. |
| Q-018 | MINOR | `ComplaintPipelineIT`; `ComplaintServiceIT`; `ConsultationPipelineIT` | MDC/system-property state is not restored. | Add symmetric cleanup. |
| Q-019 | MINOR | `ComplaintEventListenerTest.java:481-520`; `ConsultationEventListenerTest.java:470-522` | Event descriptions are captured but never asserted. | Assert exact text. |
| Q-020 | MAJOR | `acm-plugins/acm-default-plugins/acm-category-plugin/src/test/java/.../CategoryServiceIT.java:90` | Entire CRUD/exception suite is ignored; expected-message code also contains `%n` where an ID is intended. | Repair and re-enable. |
| Q-021 | MINOR | `PersonServiceIT`; `FindPersonAPIControllerTest`; related dashboard/person GET tests | Concurrency coverage is ignored and several APIs assert only status/size. | Re-enable deterministically and assert exact returned entities. |

#### Profile, Task, RMA, Outlook, OnlyOffice, Personnel Security

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-022 | MAJOR | `acm-plugins/acm-default-plugins/acm-profile-plugin/src/test/java/.../UserOrgDaoIT.java:129-151` | Silently returns when no profile exists, yielding a vacuous pass. | Seed a profile or use an explicit documented assumption. |
| Q-023 | MAJOR | `acm-plugins/acm-default-plugins/acm-task-plugin/src/test/java/.../AcmApplicationTaskEventListenerTest.java:65-85` | Class initialization changes JVM default timezone permanently. Save/restore timezone or inject time. | — |
| Q-024 | MAJOR | `acm-plugins/acm-extra-plugins/acm-personnel-security-plugin/src/test/java/.../BackgroundInvestigationBusinessProcessIT.java:94-212` | `correspondenceService` is omitted from replay/verify; calls in record mode prove nothing. Include it and assert exact generated path. | — |
| Q-025 | MINOR | `acm-plugins/acm-extra-plugins/acm-ms-outlook-plugin/src/test/java/.../CreateCalendarAppointmentAPIControllerTest`; `CreateContactItemAPIControllerTest`; `CreateTaskItemAPIControllerTest` | Exact expectations/captures are never verified. | Add `verifyAll` and assert captured item/user fields. |
| Q-026 | MINOR | `OnlyOfficeApiControllerTest`; RMA `CmisFileWriter` | Classpath streams are not closed. | Use try-with-resources. |
| Q-027 | MINOR | `acm-plugins/acm-default-plugins/acm-task-plugin/src/test/java/.../CreateAdHocTaskAPIControllerTest.java:237-301` | Negative path omits verification. | Use `assertThrows` and verify in reachable code. |
| Q-028 | MINOR | `BuckslipArkcaseIT`; Alfresco RMA ITs | Fixed sleeps, MDC/system properties, remote artifacts, and missing teardown make reruns order/environment dependent. | Add polling and cleanup. |
| Q-029 | MAJOR | `acm-plugins/acm-default-plugins/acm-task-plugin/src/test/java/.../ActivitiTaskDaoTest.java:99` | More than 1,200 lines of task DAO coverage are class-level ignored. | Repair fixtures and re-enable. |

#### Compress Folder, Calendar, Config, Correspondence, Data Update, Costsheet, Participants

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-030 | MAJOR | `acm-services/acm-service-compress-folder/src/test/java/.../FolderCompressorTest.java:84-385` | All three substantive compressor tests are excluded, removing direct recursive/error/max-size/event coverage. | Add active replacement tests or repair the approved baseline defect. |
| Q-031 | MINOR | `FolderCompressorTest.java:139-155,249-305` | MDC is not cleared and fixed temp paths collide. | Use isolated temp folders and cleanup. |
| Q-032 | MINOR | `FolderCompressorAPIControllerTest.java:188-232` | Selected-node case asserts only HTTP 200. | Capture `CompressNode` and response bytes/headers. |
| Q-033 | MAJOR | `acm-services/acm-service-calendar-integration-exchange/src/test/java/.../CalendarEntityHandlerTest.java:81-355` | Entire purge suite is ignored, including the only static Exchange coverage. | Re-enable with deterministic clock/zone. |
| Q-034 | MINOR | `DateTimeAdjusterTest.java:39-55`; `OutputTest.java:41-54`; authentication-token controller test | Missing null/empty/case, malformed AWS output, service-failure, and unauthenticated boundaries; one resource stream leaks. | Add exact negative/boundary cases and close resources. |
| Q-035 | MAJOR | `acm-services/acm-service-config/src/test/java/.../ConfigLookupDaoIT.java:440-475` | `expected=AssertionError` plus JUnit `fail()` makes tests pass when production accepts illegal mutation. | Distinguish production exception with explicit assertion. |
| Q-036 | MAJOR | `ConfigLookupDaoIT.java:82-559` | Mutates shared config with no rollback and often asserts only inequality. | Use isolated fixtures and exact entry/order assertions. |
| Q-037 | MAJOR | `acm-services/acm-service-correspondence/src/test/java/.../CorrespondenceGeneratorTest.java:290-294` | `fixBadParagraph` is empty. | Exercise production and assert transformed text. |
| Q-038 | MAJOR | `acm-services/acm-service-correspondence/src/test/java/.../HTMLEscapeTest.java:40-46` | Tests Jsoup directly, not ArkCase behavior. | Invoke the real correspondence escaping path. |
| Q-039 | MAJOR | `acm-services/acm-service-data-update/src/test/java/.../DocumentRepositoryParticipantTypesUpdateExecutorTest.java:66-170` | Assertions live only inside unverified EasyMock callbacks; zero calls still pass. | Add `verifyAll` and direct state/capture assertions. |
| Q-040 | MAJOR | `acm-services/acm-service-costsheet/src/test/java/.../CostsheetServiceTest.java:106-228` | Wildcard pipeline expectations and assertions on the configured mock object do not protect Save/Submit status or operation/context. | Capture and assert all semantics. |
| Q-041 | MINOR | Costsheet controller/tests | Streams are not closed, captures are ignored, and error cases can pass through NPE. | Close resources and assert exact body/error/captures. |
| Q-042 | MINOR | `acm-services/acm-service-participants/src/test/java/.../DecoratedParticipantAnnotationTest` | Mocks are replayed but not verified; unexpected participant types do not fail. | Verify and assert exact type set. |

#### ECM

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-043 | MAJOR | `acm-services/acm-service-ecm/src/test/java/.../FileDownloadAPIControllerTest.java:128-382` | All four controller tests are excluded, eliminating successful/latest/historical/MIME/event/not-found direct coverage. | Repair fixtures or add active replacements. |
| Q-044 | MAJOR | `.../ContentFileToSolrFlowIT.java:153-193` | Sleeps 30 seconds after submission but never queries/asserts Solr. | Add correlated bounded polling and exact indexed content. |
| Q-045 | MAJOR | `.../EcmFileServiceImplTest.java:230-261` | Expected exception makes `verifyAll` unreachable and even records a destructive delete. | Assert exception explicitly and verify zero destructive interactions. |
| Q-046 | MAJOR | `.../EcmFileParticipantServiceTest.java:970-1054` | Adds `participantOrig1` twice instead of `participantOrig2` and checks only one result. | Correct fixture and assert full set/types. |
| Q-047 | MAJOR | `.../EcmFileFolderMovedEventHandlerTest.java:140-165` | Source and return file alias the same mutated object. | Use distinct source/returned objects and verify move arguments/state. |
| Q-048 | MAJOR | `.../EcmNodeDeletedEventHandlerTest.java:100-134` | Tests verify classification lookups but not actual file/folder deletion. | Verify deletion services and resulting state/events. |
| Q-049 | MAJOR | `.../TikaMetadataIT.java:251-263,306-312` | Four Excel fixtures may all return the same allowed MIME and pass. | Assert each exact expected MIME. |
| Q-050 | MAJOR | `.../EcmFileParticipantsAPIControllerTest.java:84-138` | Empty arrays and size-zero assertions do not test body binding or serialization. | Use non-empty exact participants and invalid/duplicate cases. |
| Q-051 | MINOR | `.../UpdateFileMetadataAPIControllerTest.java:142-180` | Blanket exception swallow can accept unrelated failures. | Assert exact response/cause. |
| Q-052 | MINOR | `AddFileFlowIT`; `ContentFileToSolrFlowIT`; `GetTotalPageCountAPIControllerTest`; `FormBusinessProcessRulesIT`; `EmailAttachmentExtractorComponentTest` | Streams/temp files are not reliably closed/deleted; some resources assume exploded files. | Use classpath streams and guaranteed cleanup. |
| Q-053 | MINOR | `EmailAttachmentExtractorComponentTest.java:125-142` | Checksum errors return null; two failures can produce `assertEquals(null,null)`. Fail on checksum error. | — |
| Q-054 | MINOR | `FileLockingProviderTest.java:197,356` | Shared user list grows across parameter rows. | Reset per row. |
| Q-055 | MINOR | `EcmFileDaoIT`; `EcmFileVersionDaoIT`; `DocumentApprovalProcessIT` | Non-null/`>=0`/log-only assertions and external dependencies provide weak semantics. | Seed known data and assert exact outcomes. |

#### Signature, Email, SMTP, Functional Access, Holiday

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-056 | MAJOR | `acm-services/acm-service-electronic-signature/src/test/java/.../SignatureAPIControllerTest.java:165-196` | Broad `expected=Exception` accepts unrelated failures and does not prove no save/event. | Assert exact authentication rejection and zero side effects. |
| Q-057 | MAJOR | `acm-services/acm-service-email/src/test/java/.../AcmProcessMailServiceTest.java:82-134` | Upload expectations/captures are never verified or inspected. | Verify both uploads, names, types, and bytes. |
| Q-058 | MAJOR | `acm-services/acm-service-email-smtp/src/test/java/.../SmtpServiceTest.java:247,330` |  | Test calls `publishEvent` itself instead of Mockito `verify`, proving nothing about production. Verify with captor; verify production closes streams. |
| Q-059 | MAJOR | `acm-services/acm-service-email/src/test/java/.../AcmFilesystemMailTemplateConfigurationServiceTest.java:94-99` | Only direct test is ignored and intentionally fails. | Replace with deterministic active retrieval/error cases. |
| Q-060 | MAJOR | `acm-services/acm-service-functional-access-control/src/test/java/.../SaveApplicationRolesToGroupsAPIControllerTest.java:87-118` | Empty input and mocked `true` do not protect request binding or mappings. | Use non-empty exact mappings and false/error cases. |
| Q-061 | MINOR | `FunctionalAccessServiceTest.java:64-78`; `GetUsersByPrivilegeAndGroupAPIControllerTest.java:93-170` | Size-only assertions accept arbitrary/duplicate entities. | Assert exact role/user identities. |
| Q-062 | MINOR | Signature positive test / `SignatureDaoIT` | Captured signature fields are not inspected; DAO integration asserts only query/non-null. | Assert signer/object/IP and seeded retrieval. |
| Q-063 | MINOR | `AcmEmailContentGeneratorServiceTest.java:92-138`; `AcmObjectPatternMailFilterTest` | Missing multi-file/recipient, token failure, escaping, malformed URL, and null-subject cases. | Add boundaries. |
| Q-064 | MINOR | `HolidayConfigurationServiceTest`; SMTP attachment setup | Fixture streams leak and SMTP attachment bytes are never validated. | Close streams and assert content. |

#### Login, Note, Notification, Object Lock/History, OCR

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-065 | MAJOR | `acm-services/acm-service-login/src/test/java/.../AcmAuthenticationManagerTest.java:159-245` | Expected exceptions make all verification/event/message assertions unreachable. | Capture exception, then verify exact events/provider sequence/messages. |
| Q-066 | MAJOR | `acm-services/acm-service-note/src/test/java/.../DeleteNoteByIdAPIControllerTest.java:145-177` | Not-found test configures a found note and successful delete. | Force not-found and assert error contract. |
| Q-067 | MAJOR | `ListAllNotesAPIControllerTest.java:157-193,253-289`; `SaveNoteAPIControllerTest.java:148-192` | DAO-timeout/save-failure cases assert no status/body/error semantics. | Assert exact HTTP and event behavior. |
| Q-068 | MAJOR | `acm-services/acm-service-notification/src/test/java/.../TemplatingEngineTest.java:174-209` | Complex template test only prints output. | Assert every formatted branch/value. |
| Q-069 | MAJOR | `NotificationServiceTest.java:240-327`; `NotificationTransformerTest.java:74-92` | Failed-mail state is never asserted; transformer mocks are not verified. | Assert persisted states/events and verify collaborators. |
| Q-070 | MAJOR | `DeleteNotificationByIdAPIControllerTest.java:111-130`; `ListAllNotificationsAPIControllerTest.java:186-224`; `SaveNotificationAPIControllerTest.java:151-199` | Negative tests repeat success or omit response/failure assertions. | Exercise exact not-found/timeout/save failure contracts. |
| Q-071 | MAJOR | `acm-services/acm-service-object-lock/src/test/java/.../AcmObjectLockDaoIT.java:98-103` | `testRemove` only saves and never removes. | Invoke remove and assert absence. |
| Q-072 | MAJOR | `acm-services/acm-service-ocr/src/test/java/.../OCRQueueJobTest.java:138-166` | IDs for maps 2-5 are written into map 1. | Correct each fixture and assert order/limit. |
| Q-073 | MAJOR | `OCRBusinessProcessRulesTest.java:95-145` | Only non-null/log assertions permit inverted decisions or wrong process names. | Assert exact booleans/names. |
| Q-074 | MAJOR | `ArkCaseOCRServiceTest.java:190-267` | Exception tests do not fail on success; already-exists test actually configures no existing OCR. | Use `assertThrows`, verify no creation, and configure true existing state. |
| Q-075 | MINOR | `AcmAuthenticationDetailsFactoryTest`; `ContextIT`; related login tests | Missing malformed/untrusted proxy boundaries; parent context/global state is not closed/restored. | Add boundaries and teardown. |
| Q-076 | MINOR | `acm-services/acm-service-object-history/src/test/java/.../AcmObjectHistoryServiceImplTest.java:74-146` | No `verifyAll`; event is `anyTimes`. | Require exact publication and verify. |
| Q-077 | MINOR | `AcmObjectLockServiceImplTest` | Reversed test names and global authentication leakage reduce clarity/independence. | Correct names and teardown. |
| Q-078 | MINOR | Notification fixtures/captures | Realistic addresses/URLs and uninspected captures reduce specificity/privacy. | Sanitize and assert DTO/user values. |

#### Subscription, Sequence, Transcribe, State, Search, Participants, Timesheet

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-079 | MAJOR | `acm-services/acm-service-subscription/src/test/java/.../ListSubscriptionByUserAPIControllerTest.java:200-227` | `PreventNegativePagesize` expects `-10` to be accepted with HTTP 200. | Assert rejection or normalization. |
| Q-080 | MAJOR | `acm-services/acm-service-sequence-manager/src/test/java/.../AcmSequenceGeneratorIT.java:193-273` | Unsynchronized `HashSet` and non-atomic contains/add make the concurrency oracle racy. | Use concurrent atomic add and deterministic latches. |
| Q-081 | MAJOR | `acm-services/acm-service-transcribe/src/test/java/.../TranscribeQueueJobTest.java:142-170` | Repeats the OCR map-assignment defect. | Correct maps and assert queue order. |
| Q-082 | MAJOR | `TranscribeBusinessProcessRulesTest.java:95-145`; `TranscribeRulesTest` | Non-null/log-only assertions allow wrong decisions, process names, IDs, status, or language. | Assert exact values. |
| Q-083 | MAJOR | `ArkCaseTranscribeServiceTest.java:232-420` | Six exception paths pass if production succeeds. | Use `assertThrows` and verify no downstream creation. |
| Q-084 | MAJOR | `CreateTranscribeAPIControllerTest.java:129-152`; `GetTranscribeAPIControllerTest.java:169-239` | Error tests lack mandatory failure; Get tests configure normal returns rather than exceptions. | Configure real failures and assert exact contract. |
| Q-085 | MAJOR | `acm-services/acm-service-state-of-arkcase/src/test/java/.../ErrorsLogFileServiceIT.java:54-75` | Only non-null assertions; writes real log-path files and has no Failsafe report. | Use isolated temp logs and assert exact content/date/path. |
| Q-086 | MINOR | `acm-services/acm-service-search/src/test/java/.../AdvancedSearchQueryFlowIT.java:78-106` | Non-null and `numFound >= 0` prove no matching/access behavior. | Seed and assert exact hits. |
| Q-087 | MINOR | `JpaObjectsToSearchServiceTest` | Only two of four captures are asserted. | Assert every transformed document. |
| Q-088 | MINOR | Participant JPA ITs | External-state dependence and duplicated persistence tests reduce isolation. | Use transactional fixtures and consolidate. |
| Q-089 | MINOR | Timesheet save tests; `GetTimesheetsForObjectIdAndTypeAPIControllerTest.java:105-121` | Pipeline context/operation are wildcarded; `time1.objectId` is set twice and `time2` left unset. | Capture exact context and fix fixture. |

#### Users and WebDAV

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-090 | MAJOR | `acm-services/acm-service-users/src/test/java/.../RetryExecutorTest.java:55-95` | “Second try success” expects an exception; multiple assertions are unreachable after throwing calls. | Assert exact attempts/result/error explicitly. |
| Q-091 | MAJOR | `.../LdapAuthenticateServiceTest.java:157-178,213-254` | Negative password tests make `verifyAll` and token-expiry assertion unreachable. | Capture exception, then verify LDAP/DAO and token state. |
| Q-092 | MAJOR | `.../LdapGroupUtilsTest.java:89-106` | One-way `everyItem(isIn(...))` permits empty/incomplete ancestry. | Assert exact sets/cardinality. |
| Q-093 | MAJOR | `.../AcmGroupsSyncResultTest.java` | Repeated one-way membership assertions permit missing security-group members. | Assert bidirectional exact sets. |
| Q-094 | MAJOR | `.../AcmGroupDaoIT.java:84-115` | `saveGroupTest` has no assertion; member test configures the wrong object. | Assert persistence and correct member metadata. |
| Q-095 | MAJOR | `.../SpringLdapDaoIT.java:96-223` | Six tests only time/log live LDAP and assert nothing; global truststore settings are not restored. | Seed directory data and assert filters/paging/results. |
| Q-096 | MINOR | `.../AcmRoleToGroupMappingTest.java:173-198` | Verification occurs before the relevant call and one-way set checks remain. | Verify after invocation and assert exact sets. |
| Q-097 | MINOR | `.../UserDaoIT.java:68-73`; `AcmUsersStateProviderTestIT.java:77-83` | `count >= 0` is tautological. | Assert seeded expected counts. |
| Q-098 | MINOR | `.../AcmUserContextMapperTest.java:41-85` | Omits control/member/name/null-uid mapping. | Add exact directory variants and missing-value cases. |
| Q-099 | MINOR | `.../UserInfoAPIControllerTest.java:111-119` | `assertNotNull(retval.getUserId(), "user")` checks the literal message due overload order. | Use `assertEquals("user", retval.getUserId())` and exact authorities. |
| Q-100 | MINOR | `GetUsersByGroupAPIControllerTest.java:74-122`; `AcmGroupAPIControllerTest.java:118-140`; `AdHocGroupMembersAPIControllerTest.java:94-135` | Status/size/one-way membership assertions undercheck response contracts. | Assert exact bodies/cardinality. |
| Q-101 | MINOR | `PasswordValidationServiceTest.java:95-115` | Checks only message count and uses unseeded random passwords. | Assert exact rules with deterministic boundaries. |
| Q-102 | MINOR | `acm-services/acm-service-webdav/src/test/java/.../AcmFileSystemResourceFactoryTest.java:64,90-149` | Missing malformed URL, unsupported extension, absent file, denial, and cache-isolation cases; regex fixture uses a character class instead of alternation. | Add negative boundaries. |

#### FOIA Application

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-103 | MAJOR | `acm-standard-applications/acm-foia/src/test/java/.../CaseFileEnterQueueBusinessRuleTest.java:114-399` | Thirteen high-risk queue/required-field cases are individually ignored. | Repair and re-enable without weakening messages. |
| Q-104 | MAJOR | `.../GeneralCounselBusinessProcessIT.java:91-106` | Records enqueue but never verifies it or process state. | Verify collaborator and process outcome. |
| Q-105 | MAJOR | `gov/foia/service/ResponseFolderCompressorServiceTest.java:97-123` | Only direct compression test is ignored and would still omit verification. | Re-enable with exact folder/path/event assertions. |
| Q-106 | MAJOR | `gov/foia/service/ResponseFolderServiceTest.java:93-191` | Expectations target mocks not passed to production; no verification; success only asserts non-null. | Use one coherent fixture and assert identity/interactions. |
| Q-107 | MAJOR | `gov/foia/service/RequestAssignmentServiceTest.java:132-164` | “Oldest” case returns only one candidate. | Supply multiple dated candidates and assert exact selection. |
| Q-108 | MAJOR | `gov/foia/service/dataupdate/MultiplePortalUsersWithSameEmailCleanupExecutorTestIT.java:69-159` | Fixed IDs, no cleanup, unverified LDAP deletion, and weak survivor assertions make reruns stateful. | Use transactional unique fixtures and exact deletion/survivor checks. |
| Q-109 | MAJOR | `gov/foia/broker/FOIARequestBrokerClientTestIT.java:67-168` | Static inbound state, fixed sleep, external broker/config, and no cleanup permit stale success. Reset/correlate, poll boundedly, and clean artifacts. | — |
| Q-110 | MINOR | `.../IntakeBusinessProcessIT.java:90-130` | Request DAO mock is created/expected but never injected/replayed/verified. | Wire it or remove dead setup. |
| Q-111 | MINOR | `.../SplitRequestRulesTest.java:99-132` | `details` and `componentAgency` are populated but not asserted. | Assert every copied/non-copied field. |
| Q-112 | MINOR | Five FOIA decision-table tests | XLS streams are opened twice and never closed. | Buffer once with try-with-resources. |
| Q-113 | MINOR | `CaseFileRuleTest.java:96-230` | Timestamp has only a one-day lower bound; future/stale values pass. | Bracket before/after execution. |
| Q-114 | MINOR | `ResponseFolderNotifyServiceTest.java:120-177` | Does not assert body/template/link/parent/type. | Assert complete notification. |
| Q-115 | MINOR | `FOIARequestBrokerClientTestIT.java:149-157` | Redundant file creation and unreliable cleanup. | Use a temporary-folder fixture/finally. |

#### ArkCase Rules, ActiveMQ, Activiti, AWS Comprehend, Configuration

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-116 | MAJOR | `acm-standard-applications/arkcase/src/test/java/.../DataAccessControlRulesIT.java:93-163` | Checks counts and only the first privilege; wrong/missing remaining permission outcomes pass. | Assert the exact full privilege set. |
| Q-117 | MINOR | `AssignmentRulesIT.java:64-90`; `DataAccessControlRulesIT.java:64-90` | Decision-table streams are opened twice and leaked. Close/buffer once. | — |
| Q-118 | MAJOR | `acm-tool-integrations/acm-activemq-configuration/src/test/java/.../ActiveMqIT.java:80-193`; `TestQueueListener.java` | Sends 99 messages but asserts no delivery/advisory/payload; exceptions are swallowed and JMS resources/global settings leak. | Add correlated send/receive assertions and close all resources. |
| Q-119 | MINOR | `acm-tool-integrations/acm-activiti-configuration/src/test/java/.../WorkflowDiagramIT.java:64-76` | BPMN deployment is never deleted. | Clean it in teardown. |
| Q-120 | MINOR | `.../AcmBpmnServiceIT.java:279-306` | Writes a fixed temp BPMN and never deletes it. | Use unique temp file and guaranteed cleanup. |
| Q-121 | MINOR | `.../AcmBpmnServiceTest.java:106-316` | DAO expectations are not verified and close errors are swallowed. | Verify and fail on cleanup errors. |
| Q-122 | MAJOR | `acm-tool-integrations/acm-comprehend-medical/src/test/java/.../AWSComprehendMedicalServiceTest.java:344-409` | STOP_REQUESTED and STOPPED tests both feed FAILED, duplicating one path. | Use actual statuses and assert mappings. |
| Q-123 | MINOR | `AWSComprehendMedicalServiceTest.java:151-152,199-200` | JSON/S3 streams are opened twice and not closed. | Buffer once with try-with-resources. |
| Q-124 | MINOR | `acm-tool-integrations/acm-configuration/src/test/java/.../CollectionPropertiesConfigurationServiceImplTest.java:209-235,419-489` | Size/selected-member assertions permit wrong keys/extra entries. | Assert exact maps/lists. |

#### File Watchers, Property Manager, Object Converter/Diff, PDF, Proxy, Spring

| ID | Severity | Location | Defect | Repair the review recommends |
| --- | --- | --- | --- | --- |
| Q-125 | MAJOR | `acm-tool-integrations/acm-files-property-file-manager/src/test/java/.../PropertyFileManagerIT.java:46-162` | Fixed `/tmp/test.properties`, conditional cleanup, and swallowed I/O errors allow stale-state passes. | Use unique temporary files and fail/cleanup unconditionally. |
| Q-126 | MAJOR | `acm-tool-integrations/acm-files-folder-watcher/src/test/java/.../CaptureFileWatcherIT.java:78-140` | Shared counters/folders and two fixed five-second sleeps make results flaky. | Use unique correlated events and bounded polling. |
| Q-127 | MAJOR | `.../ConfigFileWatcherTest.java:106-116` | Ignore-folder test never verifies file-event expectations; doing nothing passes. | Add `verifyAll`. |
| Q-128 | MINOR | `.../AttachmentCaptureFileListenerIT.java:114-347` | Authentication/file captures are never inspected and shared folders lack teardown. | Assert identity/bytes/metadata and isolate folders. |
| Q-129 | MINOR | `acm-tool-integrations/acm-object-converter/src/test/java/ObjectConverterTest.java:56-66` | Default timezone is changed and not restored; date results are printed without complete assertions. | Restore timezone and assert round trips. |
| Q-130 | MAJOR | `acm-tool-integrations/acm-object-diff/src/test/java/.../AcmDiffServiceTest.java:177-244` | Conditional path assertions never fail on unknown paths or prove all expected paths. | Compare an exact path→value map. |
| Q-131 | MAJOR | `acm-tool-integrations/acm-pdf-utilities/src/test/java/.../PdfServiceImplTest.java:79-89` | TIFF conversion asserts no output existence/pages/content and leaks a fixed temp file. | Assert generated TIFF structure and clean resources. |
| Q-132 | MINOR | `ProxyServletTest.java:37-46`; `ReportNameEnumTest` | Only spaces/one positive enum value are covered. | Add reserved, Unicode, percent-encoded, empty/null, and unknown cases. |
| Q-133 | MINOR | `acm-tool-integrations/acm-spring-context-holder/src/test/java/.../SpringContextHolderIT.java:76-97` | Replaced/added child context remains after the test. Remove/restore it or dirty the context. | — |
| Q-134 | MAJOR | `acm-tool-integrations/acm-transcribe-tool/src/test/java/.../AWSTranscribeServiceTest.java:165-315` | Three negative create tests do not fail on success; upload-error stub targets the wrong stream instance. | Use `assertThrows`, capture the constructed stream, and verify no job start. |
| Q-135 | MINOR | `AWSTranscribeServiceTest.java:318-445` | JSON/HTTP resources are not closed or verified closed. | Use try-with-resources and close verification. |
| Q-136 | MINOR | `acm-tool-integrations/acm-spring-data-source/src/test/java/.../SpringEntityListenerConfigurerIT.java:87-108` | Counts adapters but helper callbacks have no counters, so delegation/argument identity is unproved. | Invoke adapters and assert callbacks. |
| Q-137 | MAJOR | `acm-tool-integrations/acm-zylab-integration/src/test/java/.../ZylabProductionFileExtractorTest.java:44-85` | Sole extraction/content test is ignored. | Replace PII fixtures, re-enable, and assert safe extraction/content. |

### Where a repair would have to start

For the human or agent who picks this up, the ordering that gets the most value first — derived from the classes above rather than from the ID sequence:

1. **The false positives, before anything else.** The ~20 expected-exception tests and ~30 vacuous tests are actively misleading: they occupy the space where coverage would be, so fixing them changes the suite's reported truthfulness more than any new test would. `assertThrows` plus a verification of *zero* side effects is the pattern; the review names the exact call for each.
2. **The fixture defects** (Q-046, Q-072, Q-081, Q-089, Q-110, Q-014, Q-047). Each of these is a one- or two-line correction that changes which scenario the test actually exercises, so the effort-to-value ratio is the best on the page.
3. **Global-state leakage** (S-05, Q-023, Q-010, Q-018, Q-028, Q-031, Q-077, Q-095, Q-129, Q-133). These make the whole suite order-dependent, so they undermine every other repair until they are done. Symmetric teardown, or Spring Security's test support for the authentication cases.
4. **The 21 `@Ignore`d classes.** Highest risk, highest effort. Note the constraint that applies even then: re-enabling must not weaken an assertion or a message, and the two exclusion classes are governed separately by [the baseline record](baseline-test-failures.md).
5. **The non-determinism**, last, because a flaky test that is currently green is a smaller liability than a green test that cannot fail.

None of this is scheduled by this migration, and none of it is a prerequisite for it. It is recorded so the next person starts from measurement rather than from a fresh audit.

## Test fixtures carrying credentials and personal data — REQUIRED HUMAN ACTION

**This section is not like the rest of the page.** Everything else here is a defect that is safe to leave alone. These eight are not: two of them are committed secrets and committed personal data, and no amount of documentation reduces their exposure. They are registered rather than fixed for exactly the reasons above — every affected file is a pre-existing test resource or test source that this migration never touched, and repairing them means rewriting assertions that depend on those fixtures, which AAP §0.2.4.2 forbids outright — but the disposition is **escalation**, not acceptance.

Two of the remediations the review calls for cannot be performed from inside this change set at all, and saying so plainly is part of the handover:

- **Credential rotation** happens in the systems that issued the credentials. It is outside this repository by definition.
- **History rewriting** (`purge history`, `scrub history`) rewrites published commits. It is a repository-owner operation with coordination costs for every clone, and it is explicitly outside the mandate of a migration branch.

What follows is therefore a work order, and the first row is the one that needs an owner today.

| ID | Severity | Location | Finding | Remediation the review requires |
| --- | --- | --- | --- | --- |
| S-01 | CRITICAL | `acm-services/acm-service-ecm/src/test/resources/email/eml/ENVIRONMENTS.docx`; `example.eml:1-213`; `EmailAttachmentExtractorComponentTest.java:97-123` | Real-looking internal URLs, account IDs, employee identities, and multiple plaintext passwords are committed twice; the test also copies the document to an undeleted temp file. | Rotate/disable credentials, replace both fixtures with synthetic data, purge history, clean temp files, and add nested MIME/OOXML secret scanning. |
| S-02 | MAJOR | `acm-tool-integrations/acm-zylab-integration/src/test/resources/ProductionFiles/...CSV:10`; `ABC000528.pdf`; `ProductionFiles.zip`; ECM `example.msg` | Real personal correspondence, private email, names, and routing metadata are committed in multiple formats. | Replace with generated fictional fixtures and scrub history. |
| S-03 | MAJOR | `AcmEncryptablePropertyUtilsImplIT.java:59-88` | Reads real user-home key material, prints decrypted plaintext/ciphertext, hardcodes passwords, and has no assertions. | Use ephemeral keys and synthetic secrets, assert round trips/failures, and never log secret material. |
| S-04 | MAJOR | `AcmCryptoUtilsImplTest.java:47-113`; `OutlookFolderCreatorPasswordMd5ToSha256UpdateExecutorTest.java:53-159` | Core crypto and password-migration coverage is class-level ignored. | Make fixtures hermetic, re-enable tests, and add correct-key/wrong-key/tamper/idempotence cases. |
| S-05 | MAJOR | `CaseFileStateServiceTest.java:60`; `CorrespondenceGeneratorTest.java:169`; `EcmFileParticipantServiceTest.java:110`; `EcmFileServiceImplTest.java:127`; `EcmNodeDeletedEventHandlerTest.java:127`; `FileDownloadAPIControllerTest.java:120`; `UpdateFileMetadataAPIControllerTest.java:92`; `AcmObjectLockServiceImplTest.java:108` | Authentication remains in `SecurityContextHolder`, creating order-dependent false authorization positives. | Clear/restore context in symmetric teardown or use Spring Security test support. |
| S-06 | MAJOR | `JWTSigningServiceImplTest.java:50-75`; generated Surefire XML | The signing test asserts nothing and logs the JWT; verification has only one positive key/token and no tamper, wrong-key, malformed, algorithm, or expiry cases. | Remove logging and add complete positive/negative signature assertions. |
| S-07 | MINOR | `FolderCompressorTest.java:249-275` | Test ZIP extraction trusts entry names and can write outside the intended temp root when re-enabled. | Normalize/canonicalize and enforce containment; add traversal and absolute-path cases. |
| S-08 | MINOR | `OutlookServiceRetryLogicIT.java:106-109` | A setup-style account/password pair is embedded although dependencies are mocked. | Replace with unmistakably synthetic values. |

### Why S-01 needs an owner before the others

The document and the mail fixture are committed **twice** — once as the OOXML attachment and once inside the `.eml` that carries it — so a secret scanner that only reads text files sees neither. That is the property that makes this worse than an ordinary committed credential: it is invisible to the usual controls. The test then copies the document to a temporary file it never deletes, so the material also lands outside the repository on every machine that runs the ECM module's suite.

The sequence a human needs to follow, in this order:

1. **Treat every credential in those two fixtures as disclosed** and rotate or disable it in the issuing system. Do this first; it is the only step that reduces exposure rather than merely tidying.
2. **Replace both fixtures with synthetic equivalents** that keep the same MIME structure and OOXML shape, so `EmailAttachmentExtractorComponentTest` still exercises nested-attachment extraction. This requires touching that test's assertions — the checksum and filename expectations are tied to the fixture bytes — which is why it cannot be done under the preservation mandate and must be scheduled as its own change.
3. **Decide on history**, with the repository owner, knowing that step 1 is what actually protects the credentials and step 3 only removes the artefacts.
4. **Add nested MIME and OOXML scanning** to whatever secret-scanning runs on this repository, so the next one is caught on the way in.
5. **Fix the undeleted temp copy** while the test is open anyway.

S-02's personal data follows the same shape and the same constraint: real correspondence, a private email address and routing metadata, in a CSV, a PDF, a ZIP and an `.msg`, all of them fixture inputs that assertions depend on.

**None of the eight blocks a validation item**, and that is stated for completeness rather than as reassurance. It is the reason they are registered here instead of fixed, and it has no bearing at all on how urgent S-01 is.

## Coverage integrity for the two PowerMock-prepared AWS classes

JaCoCo reports **zero** covered lines for both AWS service implementations, even though their tests run green and genuinely exercise them. Measured on the migrated tree, from the plugin's own CSV output:

| Class | Lines covered | Lines missed | Methods covered | What the report claims |
| --- | ---: | ---: | ---: | --- |
| `com.armedia.acm.tool.transcribe.service.AWSTranscribeServiceImpl` | **0** | 242 | 0 of 28 | Entirely uncovered |
| `com.armedia.acm.tool.comprehendmedical.service.AWSComprehendMedicalServiceImpl` | **0** | 129 | 0 of 19 | Entirely uncovered |

Both are false. `AWSTranscribeServiceTest` runs 6 green tests against the first and `AWSComprehendMedicalServiceTest` runs 8 against the second. The cause is visible in the build log, twice per module:

```
[WARNING] Execution data for class com/armedia/acm/tool/transcribe/service/AWSTranscribeServiceImpl does not match.
```

PowerMock's `MockClassLoader` re-defines every `@PrepareForTest` class before the test touches it, so the class the JaCoCo agent recorded execution data for is not the class on disk. JaCoCo identifies classes by a CRC of their bytes, the two no longer agree, and the recorded data is discarded — silently, apart from that warning. The `check` goal then passes anyway, because the floor is a **BUNDLE**-level ratio: two fully-uncovered classes are diluted by the rest of the module and never bring the bundle under 2%.

This predates the migration in every respect that matters — the `@PrepareForTest` annotations, JaCoCo 0.8.7, the 2% bundle floor and PowerMock 2.0.9 are all base-commit choices — and both test classes are byte-identical to the base commit. It is registered rather than fixed because each of the three available repairs is closed off:

| Candidate repair | Why it is not taken here |
| --- | --- |
| Stop the classloader transformation — drop or narrow `@PrepareForTest` | Modifies pre-existing test sources, which AAP §0.2.4.2 forbids. **AAP §0.6.2 declines this explicitly**, recording that migrating the PowerMock tests to Mockito's inline static mocking *"is not adopted here because it means adding a new mocking artifact and rewriting working tests"*, and naming it the recommended follow-up instead |
| Fail the build on the mismatch warning | The mismatch is inherent to PowerMock's classloader, so this would fail validation item 1 permanently — trading a reporting gap for a broken build |
| Enforce coverage per class or per package instead of per bundle | **AAP §0.8.7 forbids it**: *"the JaCoCo line-coverage floor stays at its configured 2% … rather than being raised opportunistically."* Tightening the rule shape is the same opportunistic change in a different dimension, and it would fail modules well beyond these two |

**Blocks a validation item? No** — item 1 passes, and the `check` goal passes in every test-bearing module. What is lost is not a build signal but a true one: any future regression in either AWS service would be invisible to coverage reporting. The follow-up AAP §0.6.2 already recommends — moving those five PowerMock unit tests to Mockito inline static mocking — would fix this and retire six of the eight module-access directives at the same time. That is the change to schedule.

## A PowerMock expectation that proves nothing

`acm-plugins/acm-default-plugins/acm-case-file-plugin/src/test/java/com/armedia/acm/plugins/casefile/dao/QueuePropertyFileChangeWatcherTest.java:59,81-122` calls `PowerMock.expectNew(TransactionTemplate.class, ...)` while the class runs under `EasyMockRunner` with no `@PrepareForTest`. Without the PowerMock classloader, constructor interception never happens: production calls the real constructor, the expectation is never satisfied and never verified, and the test passes regardless. The correct repair is either to drop the false expectation and assert the transaction manager's observable effects, or to inject a factory and verify it.

Byte-identical to the base commit, and it blocks no validation item — the class runs green today. Registered under R-6.

## The integration-test surface is never executed

The reactor contains **86** integration-test classes carrying **211** `@Test` annotations, and **not one** Failsafe report exists for any configuration of this build, at the base commit or after the migration. The reason is in the pipeline, and it is pre-existing: `.gitlab-ci.yml` runs `mvn -DskipITs` at both build entry points (`:68` and `:74`), and every release job in `.gitlab-ci-release.yml` runs `mvn -DskipTests` (`:94`, `:126`, `:183`). The migration's diff of those two files touches only the runner image tag and the `MAVEN_OPTS` line that carried the removed CMS flag — every skip flag is exactly as the base commit wrote it. The one job this checkpoint does add to that file, `.validate_frontend`, gates the Node 20 toolchain and does not touch the Maven lane.

The runner itself is not the problem, and that was verified rather than assumed. Failsafe **works** on JDK 17 under this configuration:

| Probe | Result |
| --- | --- |
| `PropertyFileManagerIT` | **3 tests, 0 failures**, reports written to `target/failsafe-reports` by `maven-failsafe-plugin:3.5.3:integration-test` |
| `SpringContextHolderIT` | **3 tests, 0 failures**, with a full Spring context, under the narrowed two-directive `argLine` |
| `AcmEncryptablePropertyUtilsImplIT` | **2 tests, 0 failures**, exercising real key material from the user home |
| `@{argLine}` composition | The JaCoCo agent argument and the module-access directives compose correctly in the Failsafe fork, exactly as they do for Surefire |

All three ran in one invocation — `mvn -o -B -pl acm-tool-integrations/acm-files-property-file-manager,acm-tool-integrations/acm-encryption,acm-tool-integrations/acm-spring-context-holder verify` — which exits 0 with **8 integration tests green**, and `verify` also runs the `jacoco:check` goal, so coverage enforcement holds on the lane too. Those three are the whole hermetic subset, not a sample of it.

What stops the other 83 is their environment. Classified statically by what each class reaches for, **83 of 86** need a Spring application context, the external configuration server, the database, ActiveMQ, LDAP, Alfresco/CMIS or Solr; only three are hermetic. AAP §0.9.5 records the constraint directly: the reference stack is deliberately reduced, with Alfresco, Solr and Pentaho skipped and no credentials for them ever supplied.

And exercising one shows the second obstacle, which is not environmental at all. `AcmObjectLockDaoIT` connected to the database successfully — `Connected: jdbc:mysql://localhost:3306/arkcase` — and then failed with `NoSuchBeanDefinitionException: No bean named 'pdfService' available`: its Spring context requires beans contributed by modules outside its own classpath. That is a context-composition defect in the test, not a runner or module-access failure, and it is invisible until someone runs the lane. Expect more of them.

**Blocks a validation item? No.** AAP §0.9.1 measures this migration on `mvn clean install -DskipTests` and `mvn test`, and AAP §0.9.6's definition of done names no integration-test item. A genuinely hermetic Failsafe lane would cover **three** classes out of 86; building one for the rest means classifying 83 integration tests by external dependency and standing up the four services the setup instructions deliberately skip. That is a test-infrastructure project with its own review, and it is recorded here as the follow-up it is rather than folded into a runtime migration.

One consequence worth stating for whoever schedules it: because these 211 annotations have never run, their pass rate is **unknown**, not assumed-green. The `AcmObjectLockDaoIT` result above is the first datum.

## Not defects — recorded so they are not mistaken for regressions

None of the following is a bug. Each is recorded because it looks like one at first glance, or because a reader may otherwise mistake it for something the migration broke.

| Observation | Measured detail | Why it is not a regression |
| --- | --- | --- |
| **WAR size** | 275,722,861 bytes — roughly 263 MiB — across 2,580 entries, at the unchanged path `acm-standard-applications/arkcase/target/arkcase-2021.03.war` | The name, the coordinates and the location are all unchanged. The artifact is about 2.7 MB larger than the Java 8 baseline WAR at 273,020,897 bytes, and the growth sits entirely in `WEB-INF/lib`, which moves from **635** jars to **639** — see [the dependency inventory](dependency-change-inventory.md). The exact byte count varies between builds because archive timestamps and the licence plugin's year stamp are embedded — three builds of identical source here measured 275,723,406, 275,722,947 and 275,722,861 — so the durable claim is the magnitude, not the digits |
| **The WAR carries whatever the frontend tree contains when it is packaged** | Two measured states of the identical committed source, and the decomposition between them. A clean frontend tree gives **275,722,861 bytes** across **2,580** entries with **zero** under `node_modules`. The same tree after `npm ci --ignore-scripts` and `npm run build` gives **332,662,877 bytes** across **21,994** entries — of which **19,401** are `resources/node_modules/**` at **47,921,835** compressed bytes and **11** are the generated `resources/assets/dist/**` bundles at **4,872,960** compressed bytes, so a tree that has run the frontend gate but had its `node_modules` removed lands between the two, larger than the clean WAR by those 4.9 MB | Pre-existing behaviour of `maven-war-plugin`, which packages `src/main/webapp` wholesale — none of the three states is a regression, and the deployed application does not need the generated output in the archive, because `AngularResourceCopier` runs the frontend build at webapp startup from the copied resources. It is why the Track B command sequence begins by cleaning the frontend project root, and it is why an artifact size should be quoted with the tree state it was taken from: ~333 MB is a tree with an installed `node_modules`, ~281 MB is one that has run the frontend gate and then removed it, and ~276 MB is a clean one |
| **A network-dependent build input** | `config/env/all.js:38` — the `customJs` asset list pulls an Atlassian issue-collector script over HTTPS from an external host | Pre-existing and **deliberately unchanged**. Altering or vendoring it would change the pipeline's inputs, which the preservation mandate forbids. Flagged so that a build failing on network egress is diagnosed correctly rather than blamed on the toolchain move |
| **MariaDB must run as `utf8mb3`** | 11 column-level `MODIFY COLUMN … CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci` statements across 6 Liquibase changelogs, including `acm_case_file.cm_case_details` at `acm-case-file-tables-1.0.xml:586` — the exact column whose row-size limit fails on a `utf8mb4` server | The changelogs are legitimate and the schema is on the preservation list, so this is **server configuration, never a changelog edit**. No changelog is touched by this migration. Every one of the 11 is column-level; none sets a table or schema default |
| **Activiti writes into the working directory** | Tomcat should be started from a scratch directory rather than the repository root | An operational instruction, not a repository change. Activiti stays at its pinned version, so the behaviour is identical to the base commit |
| **`acm-jmeter` is never built** | The root POM's `<modules>` names exactly eight top-level aggregators — `acm-web`, `acm-plugins`, `acm-standard-applications`, `acm-services`, `acm-tool-integrations`, `acm-forms`, `acm-user-interface`, `acm-core-api` — and `acm-jmeter` is not among them. The directory holds JMeter assets and **no `pom.xml` at all**, and no POM in the repository references it. Those eight are the direct entries, not the size of the reactor, which is the transitive closure beneath them and is counted in [the dependency inventory](dependency-change-inventory.md) | Not a defect, and not something the migration removed. It surprises readers of [the module overview](../overview.md), which catalogues `acm-jmeter` alongside the reactor modules; the overview is a directory map, not a reactor listing |
| **Two `jakarta`-coordinate API jars remain in the WAR** | `jakarta.ws.rs-api` 2.1.5 and `jakarta.annotation-api` 1.3.5, both at the versions the Java 8 baseline WAR shipped | Pre-existing and **deliberately untouched**. Neither duplicates a class this migration declares, so neither creates the classpath-order ambiguity that the provider convergence removes; the two that did — `jakarta.xml.bind-api` and the `jakarta.activation` pair — are excluded at their sources. Removing these two would be a dependency change with no Java 17 reason, which **R-1** forbids. The migration's namespace commitment is a *source* claim, and it holds absolutely: **zero** `import jakarta.…` statements exist anywhere in the 3,055 main and 410 test sources |
| **`javax/annotation/meta/*` is shipped by two jars on many classpaths** | `jsr305` 3.0.2 and `annotations` 2.0.1 both ship `TypeQualifierValidator`, `When`, `Nonnull$Checker` and their siblings | Pre-existing, unchanged since the base commit, and **unrelated to JEP 320**. These are the FindBugs/JSR-305 annotation family, not a removed EE module, and the `Nullable` type ArkCase imports is satisfied from them rather than from the reinstated `javax.annotation-api`. Under **R-6** it is registered rather than repaired: no validation item depends on it, and de-duplicating it would move a dependency with no Java 17 justification |
| **Eight JAX-WS and SAAJ jars appear that the baseline WAR lacks** | `jaxws-api`, `javax.xml.soap-api`, `saaj-impl`, `mimepull`, `geronimo-ws-metadata_2.0_spec`, `geronimo-jta_1.1_spec`, `jboss-rmi-api_1.0_spec`, `jacorb-omgapi` | **No POM in this repository changed to cause it.** `cxf-parent` 3.3.5 — reached transitively through the pre-existing `tika-parsers` — declares a profile `id=java9-plus` activated by `<jdk>[9,)</jdk>` whose dependency list is exactly this set. It is inactive on JDK 8 and active on JDK 17, so the artifacts appear because the build runs on a newer JDK, for the same reason this migration reinstates JAXB. Excluding them would remove APIs CXF's SOAP paths link against |
| **JaCoCo reports "Execution data … does not match" for two classes** | The configured suite logs four such warnings, for `AWSTranscribeServiceImpl` and `AWSComprehendMedicalServiceImpl`, each followed by "Classes in bundle … do not match with execution data" | **Pre-existing, and measured to be so:** the identical four warnings appear in the Java 8 baseline test log at the base commit. Their cause is PowerMock rewriting those classes in its own class loader, so the bytecode JaCoCo analyses is not the bytecode that ran. The coverage check still passes in both modules. Nothing in this migration created them and nothing here silences them; they are the same argument for retiring PowerMock that [the module-access record](add-opens-exceptions.md) makes |
| **The JaCoCo coverage floor stays at 2%** | `code.coverage.minimum` is `0.02` at `pom.xml:154`, enforced as a `BUNDLE` / `LINE` / `COVEREDRATIO` limit by the `check` goal at `:536-555` | Unchanged from the base commit and **not raised opportunistically**. Recorded so the low value is not read as something the migration lowered. Raising it is a coverage initiative with its own review, not a side effect of a runtime move |
| **187 `maven-default-http-blocker` metadata warnings** | The install log carries 2,196 `[WARNING]` lines, and **187 of them are one cause**: 117 for `javax.mail:mailapi` and 70 for `net.minidev:json-smart`, each reading `Could not transfer metadata … from/to maven-default-http-blocker (http://0.0.0.0/)`. Both coordinates are declared with a **version range** — `(,1.5)` in the root POM's `dependencyManagement` and `[1.3.2,2.4.2]` transitively from `com.nimbusds:oauth2-oidc-sdk` — and a range obliges Maven to consult `maven-metadata.xml` in every declared repository. One of the root POM's repositories, `milton-repo`, is plaintext `http://`, so Maven 3.8's built-in blocking mirror intercepts it and logs the refusal | Pre-existing on both counts: the range and the `http://` repository are both base-commit declarations, and the warning profile is **identical** between two independent full builds of this tree — 2,196 lines, 484 deprecation, 507 unchecked and 423 raw-type warnings in each. Resolution succeeds from locally cached metadata, so nothing is blocked and both `install` and `test` exit 0. Left alone deliberately: pinning the ranged versions would change the resolved dependency set, and R-6 permits a fix only where a pre-existing defect blocks a validation item. Recorded so a reader of the warning count knows that 8.5% of it is one blocked repository and not a JDK 17 symptom |

## Honest corrections on the record

Four claims that circulated while this migration was planned and reviewed did not survive measurement. They are named rather than quietly replaced, because a reader who has seen them needs to know which value is authoritative.

| Earlier figure | Measured value | How it was measured |
| --- | --- | --- |
| The malformed portal-gateway column type **can fail** the fresh-schema changeSet | **It does not fail** — the changeSet executes and produces the same column as a well-formed type would | Liquibase 3.1.1's own type resolution on all four supported dialects, its `updateSQL` output against a well-formed control, a real execution on a scratch MariaDB 10.6 database, and the `EXECUTED` row on the reference database. The defect is real and stays registered above; the failure prediction is what measurement withdrew, and the genuine cost turned out to be the checksum consequence of *correcting* it |
| The licence plugin affects "seven" main sources | **Six** | Counting main `.java` files without the header marker, at the base commit and in the migrated tree — the same six both times — and confirmed by running `process-sources` on the module that holds four of them |
| "Column-level `utf8mb4` ALTERs in six places" | **11 statements across 6 files** | `git grep -n utf8mb4` over the changelogs. The earlier count conflated statements with files. The substantive point is unaffected: every occurrence is column-level, so none of them is the server-level setting the requirement is about |
| `config/config.js` defects at `:16`, `:83`, `:93`, `:104`, `:115`, `:133`, `:137` | `:36`, `:110`, `:120`, `:131`, `:142`, `:160`, `:164` | Those were base-commit numbers. The carve-out fix added 27 lines above them, taking the file from 140 to 167. Both sets are given side by side above, since a wrong line number in a register is worse than no register |
| All six `lib/` directories described as "first-party in-repo source" | **Five are vendored third-party**; one is an ArkCase fork | Reading each directory's own `package.json`: five name published `json8`-family packages with versions, the ISC licence, public repositories and a single named upstream author, and only `lib/acm-json8-patch/` has no manifest at all. The retention argument is unaffected, because it rests on the relative-path requires rather than on authorship |

## What this record does not cover

**Suite totals and the exclusion accounting.** This page names the four baseline failures and the two classes that carry them, and it publishes no test counts at all — those are measured and owned by [the baseline record](baseline-test-failures.md), which is the single source of truth for them. It also owns the collateral cost of a class-level exclusion and the pre-existing skipped tests, neither of which is a defect this page registers.

**Defects in code this migration wrote.** Nothing on this page is a defect in the change set itself. Where the review found a gap in the migration's own work — an untested LDAP loader, an untested JAXB provider path, an untested frontend fallback branch, duplicate EE providers on every classpath — it was **fixed**, not registered, because it is not pre-existing and R-6 does not apply to it. The register is for the base commit's defects only, and mixing the two would be the most misleading thing this page could do.

**Module-access directives.** None of the defects here needs one, and none reaches production. The eight the migration did need are confined to the forked test JVMs and are attributed individually in [the module-access record](add-opens-exceptions.md).

**Version changes.** Every dependency and plugin move, its reproduced reason, and the candidates that were considered and withdrawn belong to [the dependency inventory](dependency-change-inventory.md). This page cites versions only where a defect's disposition depends on one.

**JDK-internal API references in source.** Those are a separate audit with a separate remedy, in [the static audit](static-audit.md). Every one of them was cleared, so none is a known issue.

**Anything resolved rather than recorded.** Ambiguities settled against observed Java 8 base-commit behaviour are decisions, not defects, and belong to [the behavioural decisions record](behavioral-decisions.md).

**A security assessment.** The integration-boundary section registers the security-relevant defects that were established while this migration was reviewed, with enough detail to act on each. It is not the output of a systematic security review of ArkCase, and it must not be read as one: no threat model, no dependency-vulnerability sweep and no penetration test was performed. Two entries — the JMS-driven path traversal and the unverified OnlyOffice callback — are flagged in their own text as worth escalating out of R-6 rather than waiting for the next migration.
**External database consumers and privileges.** The three database entries above prove what this repository does and does not contain: a mapping with no changelog behind it, a type literal, and nine routine definitions with no in-tree caller. Who calls those routines, which `EXECUTE` grants exist, and whether a deployment's own DDL bundle supplies the missing collection table are all facts that live outside this checkout. Each entry names that handoff explicitly rather than leaving it implied, because a register that stopped at the repository boundary without saying so would read as an all-clear.

## Related records

| Record | What it owns |
| --- | --- |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative suite totals, the two class-level exclusions and their collateral cost |
| [Module-access exceptions](add-opens-exceptions.md) | The eight test-scope directives and the one runtime open, with their per-library attribution and the measurement behind them |
| [Dependency change inventory](dependency-change-inventory.md) | Every dependency and plugin change with its reproduced reason, including the removals R-4 required |
| [Static audit](static-audit.md) | The JDK-internal-API audit command, its classified hits before and the zero-hit result after |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour |
