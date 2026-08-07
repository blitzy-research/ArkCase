# Pre-existing Defects

This page is the register of defects that were **discovered during** the runtime migration onto Java 17 and Node 20 LTS and **deliberately not fixed**. It exists because a rule demands it as a deliverable, not because any feature description mentions it.

The headline figures, so they do not have to be inferred: **56 entries are recorded and zero are fixed.** The first **eleven** are the ones the governing plan mandated; the rest were added by two later verification passes, described under *Register* below. **The escape clause is invoked exactly twice**, and neither invocation repairs an entry.

Its completion condition has two halves, and the second is the one that makes the page useful: every entry is present, and the escape clause is shown invoked exactly twice. A register listing defects without accounting for the exceptions to its own rule would let the exception count grow quietly, which is the failure mode it exists to prevent.

Every anchor on this page was verified against the working tree rather than copied from a plan. Where a measurement differs from what was expected, the measured value is given.

## Rules Provenance

Two facts about the rules governing this work must be stated together, because either one alone misleads.

- **There is no on-disk user rules document for this project.** The project's rules facility reports, verbatim, *"No user rules provided."*
- **Rules are nonetheless present and binding.** The requirements embed an explicit, numbered RULES block of seven rules, plus seven transformation rules that are the operational form of the PRESERVE and EXCLUDE lists. Fourteen constraints apply.

The identifiers `R-1` through `R-7` and `R-T1` through `R-T7` are the **migration plan's own navigational convention**, not quoted titles.

One rule mandates this page:

> **R-6 — Document discovered bugs, do not fix them.** Pre-existing bugs discovered during the work are documented rather than fixed, **unless one blocks a validation item.**

The clause after "unless" is an escape hatch, and an escape hatch that is used freely is not a constraint at all. It is invoked twice in this change set. Both invocations are labelled as such, both are in the frontend track, and both block the same validation gate.

Four further rules shape what this page may and may not say. They are summarised here in the plan's terms, not transcribed:

- **R-1 — Justified dependency changes.** Every dependency change needs a specific Java 17 or Node 20 compatibility reason, and *"a change without a reason is out of scope."* This is why the four dead dependencies in entries 8 to 11 are **registered rather than removed**, and why no script engine was added to the two modules in entry 7.
- **R-5 — No disabling of failing tests.** Exclusions are limited to failures already present at the baseline. It appears here as a boundary: nothing on this page is grounds for excluding a test.
- **R-7 — Baseline behaviour is the tie-breaker.** The behaviour observed at the base commit settles any ambiguity, and each resolution must be documented. This is the deeper reason R-6 exists in a behaviour-preserving change set: repairing an inherited defect *is* a behaviour change measured against the baseline.
- **R-T7 — Evidence over exit codes.** Validation asserts on produced artifacts and captured output, *never on process exit status alone* — and the rule states plainly that this is mandatory rather than stylistic because the Gruntfile's forced-execution setting masks task failures and lets a broken build exit zero. Entries 3, 4 and 49 are that mechanism caught in the act, so the rule is a repository fact here rather than a preference.

Best practice applies on top of these, never as a substitute for them. No rule is invented and none is softened; where restraint looked wasteful, the rule won, and the entry below says so.

## Why Documenting Beats Fixing Here

The instinct that a bug found should be a bug fixed is a good instinct, and it is the wrong one for this change set. The reason is specific to what a behaviour-preserving migration can prove.

Every claim this migration makes is comparative: the artefacts are byte-identical, the numbering sequence is unchanged, the routing decision is the same, the failure that was failing before is failing now. A comparison only carries weight if exactly one thing changed. Fix a pre-existing bug in the same change set and every subsequent difference has two candidate explanations — the runtime move, or the fix — and no evidence can separate them. The bug that was there before is a *constant* in the comparison, and constants are what make it a comparison.

This is why several entries below would take minutes to correct and are nevertheless left alone. The two `config.js` logic errors in particular are a handful of characters each.

## Register

| # | Defect | Location | Class | Fixed |
|---|---|---|---|---|
| 1 | Active profiles iterated as an object, not the exported array | `resources/config/config.js:83`, `:133` | Frontend logic | No |
| 2 | Four `concat` results discarded, so custom-profile assets are removed and never re-added | `resources/config/config.js:93`, `:104`, `:115`, `:137` | Frontend logic | No |
| 3 | `sync-dev` invokes a concurrent target that does not exist | `resources/Gruntfile.js:379` | Broken task alias | No |
| 4 | `lint` invokes a linter that has no configuration block | `resources/Gruntfile.js:372` | Broken task alias | No |
| 5 | SCSS pipeline declared and never executed | `resources/config/env/all.js:79`, `:92` | Dead configuration | No |
| 6 | Three artifacts resolve only from `file://` local repositories | `pom.xml:L235-L249` | Environment precondition | No |
| 7 | Latent removed-script-engine defect, proven unreachable | `acm-foia/…/JavaScriptEvaluatingPredicate.java:94`, `acm-privacy/…:98` | Latent runtime defect | No |
| 8 | Castor XML declared in seven POMs, never loaded | `pom.xml:L48`, managed `:L1156-L1158` | Dead dependency | No |
| 9 | Spring Web Services declared, never imported | `acm-service-billing/pom.xml:L101-L105` | Dead dependency | No |
| 10 | Apache Axis declared, never imported | `acm-service-billing/pom.xml:L117-L120` | Dead dependency | No |
| 11 | Commons Discovery declared, never imported | `acm-service-billing/pom.xml:L123-L124` | Dead dependency | No |
| 12 | A unit-test assertion that never held, and only appeared to | `acm-service-users/…/GroupServiceTest.java:218` | Incorrect pre-existing test | No |
| 13 | Two minified artefacts differ between the historical and target Node runtimes | `assets/dist/application.min.js`, `assets/dist/application.min.css` | Accepted migration deviation | No |

### Frontend-to-backend contract defects

| # | ID | Defect | Location | Class | Fixed |
|---|---|---|---|---|---|
| 14 | F6-API1 | A **live** client request has no backend route and returns 404 | `resources/services/ecm/ecm.client.service.js:22-27` (definition), `resources/directives/doc-tree/doc-tree.client.directive.js:2491` (caller) | Missing route | No |
| 15 | F6-API2 | Nine further client definitions have no backend route; all are dormant | rows 1-3 and 5-10 of the ten-row table below — row 4 is entry 14 | Missing route, unreachable | No |
| 16 | F6-CAL1 | The closed-object error branch is unreachable, so a closed object reports a credential failure | `…/exchange/ExchangeCalendarService.java:648-660` (wrap), `:751-754` (unreachable branch) | Error-classification defect | No |

### Backend-to-database contract defects

| # | ID | Defect | Location | Class | Fixed |
|---|---|---|---|---|---|
| 17 | F4-DB1 | Criteria query names an attribute the entities do not map | `…/exchange/CalendarEntityHandler.java:383` vs `CaseFile.java:157-159`, `Complaint.java:143-145`, `Consultation.java:150-152` | Invalid ORM attribute | No |
| 18 | F4-DB2 | An entity result is cast to `boolean` | `…/exchange/CalendarEntityHandler.java:346-364` | Invalid result cast | No |
| 19 | F4-DB3 | A JPQL parameter is declared on one condition and bound on another | `acm-foia/…/dao/FOIARequestDao.java:317-320` (declare) vs `:329-332` (bind) | Parameter binding defect | No |
| 20 | F4-DB4 | `TypedQuery<FOIARequest>` over a JPQL that selects the base `CaseFile` | `acm-foia/…/dao/FOIARequestDao.java:78-84`, `:373-380` | Query type mismatch | No |
| 21 | F4-DB5 | 86 ORM-versus-DDL dimensions diverge across 18 entities | the review's per-entity inventory, verified as described below | ORM/DDL divergence | No |

### Security defects — every one pre-existing, none introduced by this migration

| # | ID | Defect | Location | Class | Fixed |
|---|---|---|---|---|---|
| 22 | S7-AUTH1 | A caller-supplied parameter satisfies the authorization expression, bypassing per-file permission checking | `…/ecm/web/api/FileDownloadAPIController.java:56-57` | CWE-639/284 | No |
| 23 | S7-PORTAL1 | With both optional identifiers absent the query has no identity filter and returns every request | `acm-foia/…/dao/FOIARequestDao.java:134-166`; same shape in `acm-privacy` | CWE-639/862/200 | No |
| 24 | S7-PORTAL2 | Portal mutations act on caller-selected identifiers with no ownership check | `acm-foia/…/web/api/PortalRequestAPIController.java:119-126`, `:134-145`, `:152-158`; same shape in `acm-privacy` | CWE-639/862 | No |
| 25 | S7-PATH1 | A client-supplied filename reaches `Files.write` with no root containment | `acm-foia/…/service/PortalRequestService.java:514-516`; `acm-privacy/…:481-483` | CWE-22/73 | No |
| 26 | S7-SOLR1 | An interpolated sort value can inject `&q=`, `&fq=` or `&fl=` and replace the intended query | `…/admin/web/api/CategoryManagementAPIController.java:95`, `:147` → `…/search/service/ExecuteSolrQuery.java:619-645` | CWE-943/20 | No |
| 27 | S7-SECRET1 | Decrypted configuration is serialized to the browser | `…/config/web/api/ConfigApiController.java:64-72` → `ConfigService.java:81-89`, decrypted at `PropertyConfig.java:104` | CWE-200/522 | No |
| 28 | S7-SECRET2 | A stored credential is returned by an admin GET, and CMIS property values are logged | `…/EmailSenderConfigurationAPIController.java:58` → `EmailSenderConfig.java:79`; `…/admin/service/CmisConfigurationPropertiesService.java:74` | CWE-200/522/532 | No |
| 29 | S7-CSRF1 | An unload-time mutation uses `sendBeacon`, which cannot carry the framework's CSRF header | `resources/modules/…/document-details.client.controller.js:481-501` → `…/AcmObjectLockAPIController.java:127-136` | CWE-352 exposure, unprovable from the repository | No |
| 30 | S7-OBJ1 | Object and user identifiers are not constrained by principal or object-level access control | `ListBillingInvoicesAPIController.java`, `ListBillingItemsAPIController.java`, `GetCostsheetAPIController.java`, `SaveCostsheetAPIController.java`, `GetTimesheetAPIController.java`, `SaveTimesheetAPIController.java`, `ListCaseFilesByUserAPIController.java` — **zero** `@PreAuthorize` in each | CWE-639/862 | No |
| 31 | S7-WS1 | The STOMP interceptor logs a SUBSCRIBE and authorizes nothing; topics are global | `…/websockets/AcmWebSocketChannelInterceptor.java:52-74`; `spring-web-websockets.xml:22`, `:24-26` | CWE-862/200 | No |
| 32 | S7-ERR1 | Exception messages, including Java class names, are written verbatim into HTTP response bodies | `acm-web/…/api/AcmSpringMvcErrorManager.java:135-140` catch-all, `:205-247` `sendResponse`; message source e.g. `…/person/service/PersonServiceImpl.java:458` | CWE-209 | No |

### Quality and consistency defects

| # | ID | Defect | Location | Class | Fixed |
|---|---|---|---|---|---|
| 33 | L1 | The client sends a search term the controller does not declare, so it is silently dropped | `resources/modules/…/organization-search.client.service.js:26-32` → `…/person/web/api/OrganizationAPIController.java:196-220` | Dropped parameter | No |
| 34 | L2 | **Verified and found NOT to be a defect** — see below | `resources/modules/document-repository/services/document-repository-info.client.service.js:28-31` → `DocumentRepositoryAPIController.java:127` | Not a defect | No |
| 35 | L3 | One controller omits the `/api/v1` sibling prefix the rest of the codebase declares | `…/admin/web/api/AcmSchedulerAPIController.java:43` | Convention deviation | No |
| 36 | L4 | Four relationships cascade `ALL` with no DDL foreign key; one cascades to a shared lookup | `CaseFile.java:267-269`, `:281`; `Disposition.java:94`; `Category.java:95` | Cascade risk | No |
| 37 | L5 | String-returning controllers consumed with `isArray:true` | verified instance: the pair named in entry 38; population measured below | Response-type mismatch | No |
| 38 | L6 | Two definitions in one file hit the same URL, one declaring `isArray:true` and one not | `resources/services/resource/lookup.client.service.js:18-22` and `:28-33` → `ConfigApiController.java:64-72` | Response-type mismatch | No |

### Informational observations

| # | ID | Observation | Location | Class | Fixed |
|---|---|---|---|---|---|
| 39 | I1 | A bare request parameter is resolved from the debug `LocalVariableTable` | `…/correspondence/web/api/ListCorrespondenceTemplatesAPIController.java:87-91` | Compiler-debug fragility | No |
| 40 | I2 | **Anchor not located** — see below | not supplied by the review, and not found by search | Unlocated observation | No |
| 41 | I3 | A redundant query parameter is sent to a path-bound create endpoint and ignored | `resources/services/object/object-calendar.client.service.js:79` → `AcmCalendarAPIController.java` POST, which declares no such parameter | Redundant parameter | No |
| 42 | I4 | `isArray:true` placed inside raw `$http` options, where the framework ignores it | `resources/modules/cases/services/case-billing.client.service.js:10`, `:28`; `…/complaints/services/complaint-billing.client.service.js:10`, `:28` | Ineffective option | No |
| 43 | I5 | One module declares the same servlet API artifact twice | `acm-services/acm-service-authentication-token/pom.xml:89-93` (test scope) and `:108-111` (compile scope) | Duplicate declaration | No |
| 44 | I6 | The WAR carries three further duplicate-class jar pairs, outside the JSR-250 duplication this change set resolved | `WEB-INF/lib/` — measured below | Duplicate classpath provider | No |

### Java 17 backend and build-hygiene defects

Found while re-testing the Java 17 backend and build foundation, and verified pre-existing in every case. The duplicate servlet-API declaration that pass also surfaced is **not repeated here**: it is already entry 43 above, with Maven's own warning quoted at the same line.

| # | Defect | Location | Class | Fixed |
|---|---|---|---|---|
| 45 | An error-path test that passes without executing its error path | `acm-transcribe-tool/…/AWSTranscribeServiceTest.java:258` | Vacuous pre-existing test | No |
| 46 | A build plugin that rewrites six tracked source files on every build | six paths, listed in the entry | Build side effect | No |
| 47 | A test context naming a bean class that is not on its classpath | `acm-complaint-plugin/…/spring-library-complaint-plugin-test.xml:88` | Incorrect test configuration | No |
| 48 | Two providers of the `org.objectweb.asm` package in the packaged WAR | `asm-3.3.1.jar` and `asm-9.8.jar` in `WEB-INF/lib` | Latent classpath collision | No |
| 49 | The final pipeline task writes into a directory that no checkout contains | `resources/config/env/all.js:10`, write at `resources/Gruntfile.js:349` | Broken task, masked by forced execution | No |
| 57 | Seven BPMN task listeners ask for a `javascript` engine the target runtime does not register | `acm-personnel-security-plugin/…/personnelSecurityBackgroundInvestigation_v11.bpmn20.xml:48,68,88,110,121,144,155` | Platform-removal regression, deliberately not remedied | No |

### Runtime defects surfaced by QA on the deployed application

Found by exercising the deployed WAR in a browser and over HTTP rather than by reading code, which is why none of them appears above: no compiler, linter or unit test can see any of them. Every one was proved pre-existing the same way — `git log c8f6226105..HEAD -- <file>` returns **empty** for `CustomCssRetrieveFile.java`, for `appServlet/servlet-context.xml`, for `login.jsp` and for `login.css`, so not one of the four files carrying these defects was touched by any migration commit.

| # | Defect | Location | Class | Fixed |
|---|---|---|---|---|
| 50 | A stylesheet endpoint answers 500, not 406, to any client that does not name `text/css` | `acm-admin-plugin/…/api/CustomCssRetrieveFile.java:52` + `acm-web/…/appServlet/servlet-context.xml:46-48`, `:59` | Content-negotiation defect | No |
| 51 | The login page overflows and truncates at a 320 px viewport | `resources/assets/css/login.css:20-24`; no `<meta name="viewport">` in `login.jsp` | Visual / responsive | No |
| 52 | Uncleared floats let a following block overlap both "Forgot" links at every width | `login.jsp:230`, `:233`, `:240` | Visual | No |
| 53 | Escape does not dismiss an open login modal from where focus is actually left | `login.jsp` — neither `.modal` div carries `tabindex="-1"` | Accessibility | No |
| 54 | An open login modal does not contain focus | `login.jsp` — same root cause as entry 53 | Accessibility | No |
| 55 | The login inputs' focus indicator measures 1.25:1 | `login.css:30-35` `.no-border` over Bootstrap's `.form-control:focus{outline:0}` | Accessibility | No |
| 56 | The username field's HTML5 `pattern` is not a valid regular expression in current Chrome | `login.jsp:201` | Functional, client-side only | No |

**Fifty-six entries. Zero fixed** — entry 34 is recorded as *not a defect* after verification, which is a different statement from *fixed*, and entry 40's anchor could not be located.

**Entries 1 to 11 are the eleven the migration plan mandated**, and they are numbered first and held stable for exactly that reason: other pages cite them by number, and a reviewer checking the plan's completion condition — all eleven present, none fixed — can do so against the first eleven rows above without reading further. The register then grew, in two later passes recorded below, because the rule behind this page requires a pre-existing defect that was *discovered* to be written down. The growth is stated rather than absorbed: what a reviewer must be able to audit is that **no entry was repaired** and that the **escape clause was invoked exactly twice**, and neither of those claims is affected by how many entries the page carries. Both are re-checkable with the commands under *Verification* at the end of this page.

Every `Fixed` cell above and below reads **No**, without exception. Entry 34 is the one row that needs a word of explanation: it reads `No` because it was not fixed, and its class reads *Not a defect* because verification established there was nothing to fix — two different statements, and neither of them is *fixed*.

The five entries in numbers 45 to 49 were discovered by the Java 17 backend and build re-test, and the seven in numbers 50 to 56 by exercising the deployed application at runtime; each was verified present at the base commit before being written down. The thirty-one entries added in numbers 14 to 44 were **not** discovered by this migration. They were reported by the checkpoint code review, and each was then **re-verified against the working tree** before being written down here; §*Anchor Verification* below records what that verification found, including the three checks that did not come back clean — one where the report's line numbers were wrong, one where its verdict was wrong, and one that could not be checked at all.

### 1 and 2 — Two logic errors in the frontend asset resolver

`config/config.js:16` loads the active profiles with `var activeProfiles = require('./../profiles');`. The module it loads exports an **object** with a `profiles` key, not an array. Both iteration sites — `:83` and `:133` — then do `_.forEach(activeProfiles, function(profile) {…})`, which walks the object's values. The loop therefore runs once with `profile` bound to the whole array rather than once per profile.

The second error compounds the first. At `:88`, `:99` and `:110` the resolver **removes** custom module, directive and service files from the standard lists using `_.difference`, and assigns the result. At `:93`, `:104` and `:115` it means to add them back to the custom lists — but writes `jsCustomModules.concat(profileModulesFiles);` with the result unassigned, and JavaScript's `concat` returns a new array rather than mutating. The same omission appears at `:137` for CSS. The removals take effect and the additions do not.

Both are real, both are pre-existing, and both are invisible today because the tracked profiles list is empty, so the loop body operates on nothing. That is precisely what makes them dangerous to fix here: correcting them changes nothing observable in the current configuration and everything observable in a configuration with active profiles — and the byte-identical artefact comparison, which is the frontend's only behavioural evidence, would be unable to tell the difference.

**One separation has to be explicit, because these two entries live in a file the change set does touch the neighbourhood of.** The module these sites load, `profiles.js`, is **created** by this change set — it was absent from version control at the base commit, and that creation is escape-clause invocation E1 below. Creating an input file is not the same as repairing the code that consumes it. `config/config.js` itself is unchanged: the object-versus-array iteration at `:83` and `:133` is still there, and all four discarded `concat` results are still discarded. The verification commands at the end of this page prove that file is byte-for-byte identical to its base-commit state.

### 3 and 4 — Two broken Grunt task aliases, masked by forced execution

`Gruntfile.js:379` registers `sync-dev` as `['concurrent:default']`. The only target defined in the `concurrent` block that begins at `:90` is named **`default1`**, at `:91`. The alias names a target that does not exist.

`Gruntfile.js:372` registers `lint` as `['jshint', 'csslint']`. A `csslint` configuration block exists at `:40-:42`, pointing at `.csslintrc`; **a `jshint` block does not exist**. The measurement is unusually clean: `jshint` appears exactly **once** in the whole Gruntfile, and that one occurrence is the alias itself at `:372`. The task is not missing — `grunt-contrib-jshint` is a declared dependency and `load-grunt-tasks` at `:141` registers it — it is *unconfigured*, so half of that alias has nothing to lint.

Neither is fixed, and neither is the interesting part. The interesting part is `Gruntfile.js:144`, `grunt.option('force', true)` — whose own in-file comment at `:143` explains it exists "in order not to break the project" — which makes a failing task non-fatal. Both aliases can therefore fail while the process exits zero.

That single line is **R-T7's justification, expressed as a repository fact rather than a preference**. It is why validation for this migration asserts on **produced artifacts and captured output** rather than on exit status, and why the frontend baseline was captured by archiving the five build outputs and their digests instead of by checking that the build "succeeded". These two entries are the concrete proof: a reviewer trusting exit codes would have been told this build was healthy.

### 5 — A stylesheet pipeline that is declared and never executed

`config/env/all.js` declares SCSS globs at `:79` (`modules/**/scss/*.scss`) and `:92` (`_modules/**/scss/*.scss`). No task or configuration function consumes either glob: `getCSSAssets()`, spanning `config/config.js:130-:140`, reads only the compiled-CSS globs at `all.js:27` and `:78`, and the two SCSS keys are matched by nothing but their own declarations.

**25 `.scss` files are tracked** in the frontend tree, and the split matters more than the total:

| Location | Count | Status |
| --- | --- | --- |
| `resources/scss/**` | 16 | Matched by **no glob at all** — outside both declared patterns |
| `resources/modules/*/scss/` | 9 | Matched by the `:79` glob, but nothing consumes the result |

The migration plan quotes 16 tracked `.scss` files, which is the first row rather than the total; the measured figures are given here because the divergence is worth stating rather than smoothing over. Either way the outcome is the same — nothing compiles them.

This entry is load-bearing for a decision recorded elsewhere, and the two must not be conflated. The Sass toolchain package is *removed* rather than replaced precisely because this pipeline never runs, which is what makes the removal **provably output-neutral**: no task consumes the globs, so nothing that reaches an artifact changes. Substituting a modern Sass compiler would have risked emitting different CSS bytes for zero functional gain, and modern replacements were verified to install — they were declined on evidence, not availability. See [Dependency Change Inventory](dependency-change-inventory.md).

**That removal is escape-clause invocation E2, and it is not a repair of this entry.** It removes a dependency that cannot build on the target runtime; it does not wire the pipeline up, delete the unused globs, or touch the 25 stylesheets. The pipeline is declared and inert after the migration in exactly the way it was declared and inert before it, which is why this entry stays open and why the removal costs the register nothing.

### 6 — The environment precondition, and the shortcut it invites

Three artifacts do not resolve from Maven Central and are supplied from `file://` local repository declarations: `com.arkcase:arkcase-license-headers` (referenced at `pom.xml:L422`), `com.touchnet:tlink-client` (managed at `pom.xml:L524`, declared at `acm-service-billing/pom.xml:L109`) and `org.eclipse.persistence:logging-slf4j`, which is **literally pinned** at `pom.xml:L1311-L1317` — artifactId at `:L1314` and the `1.0.1` version literal at `:L1315`, not driven by a property — and declared at `acm-spring-data-source/pom.xml:L106` and `acm-web/pom.xml:L125`. Because `acm-service-billing` is a reactor member (`acm-services/pom.xml:L62`), an unprovisioned local repository blocks a full reactor build.

The declarations enumerate the depths at which a module can sit, because `${basedir}` re-evaluates per module rather than once for the reactor. Three are `<repository>` entries at `pom.xml:L236-L249` — one, two and three levels up — and the `<pluginRepository>` block at `:L251-L276` adds the top-level depth `file://${basedir}/arkcase-lib` at `:L253-L256` and mirrors the other three. Each carries an explanatory comment. Whichever depth a module occupies, the matching URL is the one that lands on the repository-root directory: verified from the root itself, from `acm-services`, from `acm-services/acm-service-billing` and from `acm-plugins/acm-default-plugins/acm-case-file-plugin`, where only `../../../` reaches it.

The condition is **JDK-independent and identical at the JDK 8 baseline**, so it is not a migration defect. It is registered here because a red build invites exactly the wrong response: **under no circumstances may the module, the dependency, or the repository declarations be deleted to make the build green.** Deleting a live dependency to pass a gate is the shortcut this migration exists to prevent, and the TouchNet client is demonstrably live — two files import it.

In the baseline and migrated captures the precondition was **satisfied**, and this is where the measured state parts company with the migration plan. The plan records that no such directory exists on disk; that is **not** the case at the base commit and is not the case now. `arkcase-lib/` sits at the repository root, is **tracked in version control** at **26 files** in both trees, and carries a real jar and POM for each of the three coordinates — `com/arkcase/arkcase-license-headers/1.0/`, `com/touchnet/tlink-client/1.0/` and `org/eclipse/persistence/logging-slf4j/1.0.1/` (jar, POM and a sources jar) — alongside `com/frevvo/forms-java/6.3/`. That is why all 142 modules built and both captures are complete rather than partial. The plan's claim is corrected here rather than repeated, because a register that inherits an unverified assertion is worth less than one that measures.

What remains true is the narrower statement: these three artifacts are **not obtainable from a public registry**, so a complete build depends on the tracked directory being present in the checkout and reachable at each module's depth. A sparse checkout, an export that drops the directory, or a module nested deeper than the declared depths would each fail resolution in a way that looks exactly like a dependency regression and is not one. See [Baseline Test Failures](baseline-test-failures.md).

One adjacent cleanup must not be confused with this entry. Two **dead, non-local** repository declarations were removed by this change set: `milton-repo` at `pom.xml:L225-L228`, whose URL is plain **HTTP** and which the modern Maven baseline blocks outright, and `jcenter-snapshots` at `:L230-L234`. Those removals are migration work with a resolution-level justification, recorded in [Dependency Change Inventory](dependency-change-inventory.md). The three `file://` repositories and the whole `<pluginRepository>` block are **retained untouched** — all seven `arkcase-lib` URLs are still present — which is the point of the constraint above.

### 7 — A latent defect that no compiler and no static audit can see

Two files ask the script-engine manager for the `nashorn` engine: `acm-foia/…/JavaScriptEvaluatingPredicate.java:94` and `acm-privacy/…/JavaScriptEvaluatingPredicate.java:98`. That engine was removed from the JDK in version 15.

These files **compile cleanly at release 17**, because `javax.script` remained in the JDK — only the engine implementation went. The lookup returns `null` at run time and the next dereference throws. No compiler warns, and the JDK-internal usage audit cannot see it either, because the code names no internal package: it passes a string to a supported API. It is the only defect in this register that a green build actively conceals.

Both copies are **provably unreachable**, and the re-check strengthened that conclusion rather than merely confirming it. In `acm-foia` the comment region in `spring-extension-library-foia.xml` **opens at `:131` and closes at `:141`**, so *both* bean declarations inside it are commented — the `FolderNameEqualsPredicate` at `:131` and the `gov.foia.service.JavaScriptEvaluatingPredicate` at `:139`. The only consumer, `<beans:ref bean="folderNamePredicate"/>` at `:150`, sits inside the commented `<beans:property name="predicates">` block spanning `:148-:152`. The migration plan described an *active* declaration at `:131` naming a different predicate class; there is **no active declaration of either class at all**, which is the measured state and a stronger result than the plan claimed. In `acm-privacy` there is no XML reference whatsoever — the apparent cross-module references are `<bean>` examples inside Javadoc. Nothing in either module — no XML, properties file or shell script — reaches these two call sites.

Adding a standalone script engine **to these two modules** to make this code work would introduce a library to the production dependency graph solely to support code that cannot execute — a change with no compatibility justification, which R-1 forbids — and would convert dead code into live code, which is a behaviour *change* relative to the baseline. Documenting it is the R-7-consistent outcome, and it stays the outcome even though the same platform removal **is** remediated elsewhere.

One qualification belongs here rather than further down, because reading this entry alone would otherwise leave a false impression. These two call sites are unreachable, but the JEP 372 removal reaches the application by a **second** route that this entry does not cover and that the migration plan's census missed: a BPMN task listener in a different module, which really did execute before the platform change. That is **entry 57** below, and it is registered exactly as this one is — recorded, measured, and not remedied. No module anywhere in the change set declares a standalone script engine, so every one of these call sites still resolves to nothing on the target runtime. The rejected alternatives are in [Ambiguity Resolutions](ambiguity-resolutions.md).

### 8 to 11 — Four dead dependencies, registered rather than removed

| Dependency | Declared at | Imports found |
|---|---|---|
| `org.codehaus.castor:castor-xml` `1.3.3` | `pom.xml:L48`, managed `:L1156-L1158`, in seven child POMs | **0** — no Java imports, no XML or properties references, no mapping files |
| `org.springframework.ws:spring-ws-core` `1.5.9` | `acm-service-billing/pom.xml:L101-L105`, hardcoded outside `dependencyManagement`, version literal at `:L104` | **0** |
| `org.apache.axis:axis` `1.4` | `acm-service-billing/pom.xml:L117-L120`, artifactId at `:L119`; managed at `pom.xml:L536` | **0** |
| `commons-discovery` `0.5` | `acm-service-billing/pom.xml:L123-L124`; managed at `pom.xml:L541-L542` | **0** |

All four import counts were re-measured against the working tree for this page, and so were the anchors. Two of them moved by one line against the figures the migration plan carried: the Spring Web Services `<dependency>` element opens at `:L101` rather than `:L102`, and the Apache Axis **artifactId** is at `:L119` — `:L118`, which the plan cites, is that dependency's `<groupId>`. The measured values are the ones printed above. The seven child POMs declaring Castor are `acm-complaint-plugin`, `acm-person-plugin`, `acm-service-billing`, `acm-service-note`, `acm-service-notification`, `acm-service-sequence-manager` and `acm-web`.

The temptation to delete them is strong: they are ancient, one of them is a SOAP stack, and removing four unused declarations looks like unambiguous hygiene. The reason for keeping them is recorded in the migration plan's own words:

> Because they are never loaded, they present no Java 17 risk, so removing them would be unrelated cleanup that could perturb unaudited classpath ordering, and any resulting difference would be indistinguishable from a migration regression.

R-1 cuts the same way: a dependency change with no compatibility justification is out of scope, and "it is untidy" is not a compatibility justification.

The asymmetry with entry 6 sharpens the principle rather than contradicting it. A **dead** dependency is left declared because removing it is unjustified churn; a **live** dependency that cannot be resolved from a public registry is treated as an environment precondition and is likewise never deleted. The TouchNet client in entry 6 is the live case — two files import it — and these four are the dead case. In both directions the answer is the same: do not touch the dependency graph without a justification. That is R-1 applied consistently, not two different rules.

### 12 — A unit-test assertion that never held

`GroupServiceTest.testSaveAdHocSubGroup_newSubGroup` asserts, at `:218`, that `saveAdHocSubGroup` calls `groupService.save(…)`. The production method does not call `save` at all: it calls `createGroup` and then `parent.addGroupMember`. The assertion was being satisfied by the invocation that the test's own `when(…)` stubbing performed on the spy.

This is a **pre-existing test defect**, not a migration defect, and the distinction was established by changing one variable: on the same Java 17, with the same source, the test passes with the pre-migration Mockito and errors with the migrated one. The newer Mockito no longer counts a stubbing call as a verifiable interaction, so an assertion that never held has stopped appearing to hold.

It is not fixed because correcting it means rewriting an assertion, which the PRESERVE list forbids, in a test file the authoritative in-scope list does not include. The full mechanism, including the intermediate probe that isolated it, is in [Baseline Test Failures](baseline-test-failures.md) under *Cause C*.

### 13 — Two minified artefacts differ between the historical and the target Node runtime

This is the only entry on this page that the migration itself produced, and it is here rather than hidden in a summary because the alternative is a claim of byte-identity that is not true.

The base-commit frontend was built on **Node v8.17.0 with the superseded package manager at 1.22.22** — the historical runtime and lockfile tooling, both installed for the purpose — and compared against the migrated build on Node 20.20.2. `assets/dist/application.js`, `assets/dist/vendors.min.js` and the rewritten `home.html` are **byte-identical**. `application.min.js` differs by **2 bytes** and `application.min.css` by **789**.

Neither difference is a defect in this repository, and neither is fixable inside the rules:

- Both artefacts are produced by the SAME minifier versions on both sides — `uglify-js` 2.8.29 and `clean-css` 3.4.28, verified in both installed trees — from **byte-identical input**, since `application.js` matches. The variable is the JavaScript engine the minifier runs on.
- The script difference is two occurrences of an escaped forward slash inside one regular-expression character class, where the newer engine no longer emits the escape when it re-serialises a pattern. Normalising that one escape makes the two 2 MB bundles compare **equal**; the two patterns match the same strings.
- The stylesheet difference is `clean-css` grouping the same declarations into different rule blocks. A declaration-level comparison over 13,455 flattened `(selector, property, value)` triples found none present on one side and absent on the other, and the 28 distinct `@media` preludes are identical.
- Changing either minifier would need a Node 20 incompatibility to justify it under R-1, and neither has one: both install and run on Node 20 at the versions the lockfile pins. A version change would also alter the output far more than the difference it was meant to remove.

Recorded, not fixed. The measurement is archived beside this page at `smoke-evidence/historical-frontend/comparison.txt` with the capture script next to it, and the decision — including the options rejected — is entry 6a of [Ambiguity Resolutions](ambiguity-resolutions.md). **This entry does not consume an escape-clause invocation**: the escape clause covers pre-existing defects that were *fixed* because they blocked a validation item, and this one is not fixed.

## Anchor Verification — What Re-Checking the Report Found

Every one of the thirty-one entries numbered 14 to 44 was re-checked against the working tree rather than transcribed. That is not a formality: a register row is only worth having if a reviewer can open the file and see the thing. Three checks did not come back clean — one where the report's line numbers are wrong, one where its verdict is wrong, and one that could not be checked at all — and all three are stated below rather than smoothed over.

**Twenty-eight entries verified exactly as reported.** The cited file exists, the cited construct is present, and the mechanism is the one described. Where a line number had moved, the register above cites the **verified** line rather than the reported one. The arithmetic is 31 entries less the three that follow.

**One systematic line-number offset, in entry 21.** The 86-dimension inventory cites, for each field, a line **one to four lines above** the field's actual declaration — consistently the `@Column` annotation of the *preceding* member. Twenty-five of the eighty-six were checked individually and every one showed the same small positive offset: `AcmQueue.name` reported at 63 and declared at 65; `CaseFile.caseNumber` reported at 128 and declared at 132; `Category.status` reported at 115 and declared at 119; `PortalFOIAPerson.role` reported at 57 and declared at 58. **Every named field exists in every named entity**, all eighteen entity files exist, and the per-entity dimension counts sum to exactly 86. The offset is recorded rather than silently corrected so that a reviewer reconciling this page against the report is not left wondering which is wrong.

**One entry verified as NOT a defect — number 34 (L2).** The report flagged two dormant document-repository and task definitions as *latent missing-route contracts* and explicitly asked that they be verified before activation. They were. `document-repository-info.client.service.js:28-31` defines `_getDocumentReposioryTasks` requesting `api/latest/plugin/documentrepository/:id/tasks`, and `DocumentRepositoryAPIController` **does** map `GET /{id}/tasks` at line 127 under the `/api/latest/plugin/documentrepository` base declared at line 63. The route exists and the contract matches. The task-side half of that entry is the `/plugin/task/forUser/{user}` definition already carried as row 10 of entry 15's table, where it is confirmed genuinely unmatched. So L2 contributes no unmatched contract of its own, and it is kept in the register as a *closed* row rather than dropped, because a reader of the report will look for it.

**One entry whose anchor could not be located — number 40 (I2).** The report describes "a group-filter client sending an extra `q` duplicating the `{userId}` path variable, which the backend ignores" and supplies no file or line. Every client definition whose URL mentions `userId` was enumerated, every users-by-group and groups-by-user definition was read, and the closest candidate — `security.organizational-hierarchy.client.service.js:245-254`, which calls `api/latest/users/by-group/{group}` — sends only `status`, which `GetUsersByGroupAPIController.java:55-58` **does** declare as a `@RequestParam`. No definition matching the description was found. The entry is retained with its status stated plainly rather than being attached to an approximate location, because a register row pointing at the wrong code is worse than one admitting it has no pointer.

### 14 and 15 — One live 404, and nine dormant contracts

Entry 14 is the only one of the ten that a user can reach. `ecm.client.service.js:22-27` defines `retrieveFlatSearchResultList` against `api/latest/service/ecm/folder/:objType/:objId/:folderId/search`, and `doc-tree.client.directive.js:2491` selects it whenever a document-tree search filter is non-empty. On the backend, `FolderListAPIController.java:74` provides `/folder/{objectType}/{objectId}/search` — **without** the folder segment — and `SubFolderListAPIController.java:64` provides `/folder/{objectType}/{objectId}/{folderId}` — **without** `/search`. Neither matches, so the request 404s.

The full set, each authority re-measured:

| # | Client contract | Authority result |
|---|---|---|
| 1 | PUT `…/workflowconfiguration/workflows/{key}/versions/{version}/inactive` — `workflows.config.client.service.js:112` | `WorkflowConfigurationMakeActive.java:56` maps only `…/active`; **zero** files mention the `/inactive` path |
| 2 | PUT `api/latest/plugin/billing/invoices/document` — `case-billing.client.service.js:44` | **zero** Java files mention `invoices/document` |
| 3 | the same PUT — `complaint-billing.client.service.js:44` | as above |
| 4 | GET `…/folder/{objType}/{objId}/{folderId}/search` — `ecm.client.service.js:24` | no exact route — **this is the live one** |
| 5 | GET `api/administration/modules` — `administration.client.service.js:8` | **zero** controllers map `/api/administration`; **zero** static resources under `modules_config/…/administration` |
| 6 | GET `api/administration/modules/{moduleId}` | as above |
| 7 | PUT `api/administration/modules/{moduleId}` | as above |
| 8 | GET `api/administration/schemas/{schemaId}` | as above |
| 9 | GET `api/latest/plugin/admin/queries/{objectType}` — `correspondence-management-templates.client.service.js:90` | **zero** files map `queries/{objectType}` |
| 10 | GET `api/latest/plugin/task/forUser/{user}` — `object-task.client.service.js:57` | `/forUser/{user:.+}` exists under `…/plugin/casefile` and `…/plugin/person`, **not** under `…/plugin/task` |

They are not fixed for two independent reasons, and both matter. Every one of these files is **frozen by the migration plan** — the plan's exclusion list forbids changing application JavaScript, and its scope list contains no controller. And a missing route is fixed either by editing the client (frozen, and it would change the built bundle bytes that are the frontend's only behavioural evidence) or by adding an endpoint (a new REST contract, which the plan excludes outright). R-6 therefore applies with no tension: document, do not fix.

### 16 — Why the closed-object error can never be reported as one

The chain is short and entirely mechanical. `CalendarObjectClosedException extends CalendarServiceException` (`CalendarObjectClosedException.java:36`). Inside `ExchangeCalendarService`, the closed-object check throws it at `:649` — but that `throw` is inside a `try` whose handler is `catch (CalendarServiceException cse)` at `:655`, which re-wraps **any** subclass as `CalendarServiceBindToRemoteException` at `:657`. The mapper then tests `instanceof CalendarServiceBindToRemoteException` at `:747` **before** `instanceof CalendarObjectClosedException` at `:751`, so it emits `INVALID_BIND_TO_SERVICE_CREDENTIALS`. The `OBJECT_CLOSED` string at `:753` is dead. The client reads `reason.data.error_cause` at `core-calendar.client.directive.js:182` and looks it up in its message map, so the user is told the service credentials are wrong when the object is merely closed.

Fixing it means either narrowing the `catch` or reordering the mapper — a change to exception classification in a service whose wire behaviour the migration promises is unchanged, in a file the plan does not list. Documented.

### 17 to 21 — Five ORM and query defects, and what verifying 86 dimensions established

Entries 17 to 20 are single-site defects, each confirmed by reading the site:

- **17**: `CalendarEntityHandler.java:383` builds `cb.lessThanOrEqualTo(acmObject.<Date> get("dateCreated"), …)`. The three entity classes this handler is wired for map the attribute as `created` — `CaseFile.java:159`, `Complaint.java:145`, `Consultation.java:152`, each behind `@Column(name = "cm_*_created")`. Neither `CaseFile`, `Complaint` nor `Consultation` declares `dateCreated` at all, so the criteria build fails at runtime on the days-closed branch.
- **18**: `isObjectClosed` creates `cb.createQuery(acmObjectClass)`, selects the root, and then executes `return (boolean) dbQuery.getSingleResult();` at `:359`. The single result is an entity, not a boolean. Only the `NoResultException` path — which returns `false` — can complete.
- **19**: the fragment `AND cf.caseNumber = :requestId` is appended when `requestId != null` (`:317-320`), while `setParameter("requestId", …)` is guarded by `if (portalUserId != null)` (`:329-332`). Both asymmetric combinations are broken: a declared-but-unbound parameter, or a bound-but-undeclared one.
- **20**: two methods declare `TypedQuery<FOIARequest>` over `SELECT cf FROM CaseFile cf` (`:78`) and `SELECT request FROM CaseFile request` (`:373`). `CaseFile` is `@Inheritance(strategy = InheritanceType.SINGLE_TABLE)` (`CaseFile.java:111`) with `FOIARequest` carrying `@DiscriminatorValue("gov.foia.model.FOIARequest")` (`FOIARequest.java:66`), so any non-FOIA case file in the queue is returned into a `FOIARequest`-typed list.

**Entry 21** is a different kind of claim, and its verification was scoped deliberately. Confirming all 86 dimensions individually would mean reading 86 column definitions across the Liquibase changelogs as well as 86 annotations — a re-derivation of the review's own work rather than a check of it. What was verified instead: all eighteen entity files exist; the per-entity counts sum to exactly 86; twenty-five named fields were located individually (all present, at the small offset recorded above); and the **mechanism** was confirmed end to end on a sample against the authoritative DDL. That sample:

| Column | Liquibase DDL (authoritative) | Entity annotation | Divergence |
|---|---|---|---|
| `cm_case_number` | `:13` — `VARCHAR(${caseNumberLength})`, `nullable="false"`, `unique="true"` | `:130` — `@Column(name = "cm_case_number")` only | nullability, length and uniqueness all unstated in the ORM |
| `cm_case_type` | `:16` — `VARCHAR(4000)`, `nullable="false"` | `:134` — `@Column(name = "cm_case_type")` only | implicit JPA length 255 against 4000; nullability unstated |
| `cm_case_title` | `:22` — `VARCHAR(4000)`, `nullable="false"` | `:137` — `@Column(name = "cm_case_title")` plus `@Size(min = 1)` | the ORM constrains a *minimum* through Bean Validation and says nothing about length or nullability |
| `cm_case_status` | `:19` — `VARCHAR(4000)`, `nullable="false"` | `:141` — `@Column(name = "cm_case_status")` only | as `cm_case_type` |
| `cm_case_creator` | `:31` — `VARCHAR(1024)`, `nullable="false"` | `:161` — `@Column(name = "cm_case_creator", insertable = true, updatable = false)` | insertability is stated, nullability and length are not |

DDL line numbers are in `acm-case-file-plugin/src/main/resources/com/armedia/acm/ddl/tables/acm-case-file-tables-1.0.xml`; entity line numbers are in `CaseFile.java`.

The divergence is therefore real and of the kind described. It is also **inert in this deployment**, and that is why it is documented rather than fixed: `spring-library-data-source.xml:142` sets `<property name="generateDdl" value="false"/>`, and the `SpringLiquibase` bean at `:164` of the same file owns schema creation, so not one annotation on this list generates or alters a column. Aligning them would edit annotations on eighteen entities the migration plan freezes, inside a change set whose central promise is that the effective DDL of every persistence mapping is untouched — and an annotation that is currently inert could stop being inert the moment somebody enables DDL generation, which is exactly the kind of latent behaviour change this migration must not introduce.

### 22 to 32 — Eleven security defects, all pre-existing

The checkpoint review records every S7 finding as pre-existing at the earlier baseline, and the working-tree verification agrees: none of these constructs is touched by this change set, and each is reachable in the same way before and after the runtime move. What was confirmed, beyond the presence of each cited line:

- **22** — `@PreAuthorize("hasPermission(#fileId, 'FILE', 'read|group-read|write|group-write') or #parentObjectType == 'USER_ORG'")` at `:56`, where `parentObjectType` is a `@RequestParam` at `:63` with an empty default. Supplying `parentObjectType=USER_ORG` satisfies the disjunction, and the method then resolves and downloads whatever `ecmFileId` was asked for.
- **23** — with `getRequestId()` and `getLastName()` both null the query text is left at its base form, which joins requests to requester persons with **no identity predicate at all**, and every row is serialized through `populateRequestStatusList`.
- **24** — `requestDownloadTriggered(@PathVariable String requestNumber)` and `withdrawRequest(@RequestBody …)` both act on an identifier the caller chose; neither method body consults the authenticated principal before its side effect.
- **25** — `new File(requestFile.getFileName())` then `Paths.get(file.getAbsolutePath())` then `Files.write(path, content)`, where `requestFile` is deserialized from the portal request. No basename, no normalisation, no root containment, and the destination is not a server-created temporary file.
- **26** — `ExecuteSolrQuery.buildQueryFromUrlParameters` splits its input on `&` and lets a `q=`, `fq=` or `fl=` segment **replace** the intended value (`query.setQuery(...)`, `addFilterQuery(...)`, `setFields(...)`). `CategoryManagementAPIController` interpolates the caller's `s` parameter straight into `"…&sort=title_parseable %s"`, so a value containing `&q=` reaches that splitter.
- **27** — `ConfigApiController.getConfig` returns `configService.getConfigAsJson(name)`, and the backing `PropertyConfig` decrypts its properties in `afterPropertiesSet` at `:104`. The decrypted result is what serializes.
- **28** — the credential-returning half was pinned to one concrete instance rather than asserted generally: of eighteen types in the codebase that declare a plain `password`, `secretKey`, `accessKey`, `apiKey` or `clientSecret` field, exactly **two** are returned by a GET-mapped controller method, and of those two only `EmailSenderConfig` lacks `@JsonIgnore` on the field — `password` at `:79`, returned by `EmailSenderConfigurationAPIController` GET `/email/configuration` at `:58`. The logging half is `CmisConfigurationPropertiesService.java:74`, which logs `Reading [{}] with value [{}] from [{}]` for every property in the CMIS file.
- **29** — the unload listener at `document-details.client.controller.js:481` builds a lock-release URL and calls `navigator.sendBeacon(url, data)` at `:495`, falling back to a synchronous `XMLHttpRequest` that sets only `Content-type`. Neither path can set `X-XSRF-TOKEN`. The target, `AcmObjectLockAPIController.unlockObject`, accepts POST at `:128-129`.
- **30** — measured rather than asserted, as an annotation count per file:

  | Controller | `@PreAuthorize` |
  |---|---:|
  | `ListBillingInvoicesAPIController` | **0** |
  | `ListBillingItemsAPIController` | **0** |
  | `GetCostsheetAPIController` | **0** |
  | `SaveCostsheetAPIController` | **0** |
  | `GetTimesheetAPIController` | **0** |
  | `SaveTimesheetAPIController` | **0** |
  | `ListCaseFilesByUserAPIController` | **0** |
  | `CreateBillingItemAPIController` — same module, control | 1 |
  | `FileDownloadAPIController` — control | 1 |
  | `AcmObjectLockAPIController` — control | 4 |

  The three controls matter: the absence is a property of *these* chains and not of the codebase, and `CreateBillingItemAPIController` shows that even the billing module annotates elsewhere. One naming correction: the report cites `SaveCostheetAPIController`, which does not exist. The class is `SaveCostsheetAPIController`; the *test* class in the same module is genuinely misspelled `SaveCostheetAPIControllerTest`, which is the likely source of the report's spelling. The register cites the class that exists.
- **31** — `preSend` handles CONNECT, DISCONNECT and SUBSCRIBE with `log.trace` only and ends `return message;` unconditionally. It is registered as the sole inbound-channel interceptor in `spring-web-websockets.xml:24-26`, and the relay carries the global `/topic,/queue` prefixes at `:22` with no user-destination scoping.
- **32** — the chain was traced end to end rather than accepted from the finding text, because the report claims two things and only one of them is obvious. `sendResponse` writes its `message` argument straight into the response body as `text/plain` — `byte[] bytes = empty ? "Unknown Error...".getBytes() : message.getBytes();` at `:236`, then `response.getOutputStream().write(bytes)` at `:240`. Of the eighteen `@ExceptionHandler` methods in the class, **seventeen** call `sendResponse(…, e.getMessage())`; the eighteenth, `handleJsonMessageError`, puts `e.getMessage()` into a serialized `message` field at `:198` instead — a different transport for the same content, so all eighteen return the raw message. The **class-name** half is the part worth proving, since `getMessage()` alone carries no type name. It arrives by construction: `PersonServiceImpl.java:458` throws `new AcmCreateObjectFailedException("Person", e.toString(), null)`, whose constructor is `(String objectType, String message, Throwable cause)` calling `super(message, cause)` — so the exception's message *is* `e.toString()`, which is `fully.qualified.ClassName: text`. That is then handled at `:93-98` and written to the body. Thirteen sites in the person and organization services build a message from a cause's `toString()` this way. Compounding it, `lastChanceHandler` at `:135-140` registers `@ExceptionHandler(Exception.class)`, so an exception from *any* layer — persistence, reflection, I/O — reaches the client as a 500 carrying whatever its own message says.

**Two adjacent constructs were checked and found correct**, and they are recorded because a register that lists only hits invites the reader to assume the worst everywhere else. `AcmCalendarManagementAPIController.getConfiguration` calls `readConfiguration(false)` — the parameter is literally named `includePassword` — so the Exchange credential is deliberately excluded. And `ZylabIntegrationConfig` carries `@JsonIgnore` at `:119` guarding the `clientSecret` declared at `:121`, alongside four sibling `@JsonIgnore` annotations on its other authentication fields. Neither is a leak.

None of these is fixed. Every one lands in a controller, DAO, service, entity, frozen client script or Spring configuration file that the migration plan's scope list does not contain, and the plan's preservation list explicitly requires that security and permission-evaluation outcomes be **unchanged** — so adding an authorization check here would itself be a deviation from the plan, not compliance with it. They also block no validation gate. R-6's escape clause is therefore unavailable and unnecessary, and the correct action is exactly this register row plus escalation to the owner.

### 33 to 38 — Six quality defects

- **33** — `queryFilteredSearch` sends `…/search/:organizationId?q=:query`, and `searchOrganizations(@PathVariable("organizationId") Long organizationId)` declares no second parameter. The method builds its filter purely from the organization's own ancestry and returns it; the search term never reaches Solr.
- **34** — closed, see *Anchor Verification* above.
- **35** — `AcmSchedulerAPIController` declares `@RequestMapping(value = { "/api/latest/plugin/admin/scheduler" }, …)` at `:43`, a single-prefix form. The convention elsewhere is the two-element `{ "/api/v1/…", "/api/latest/…" }` array: **334 files cite `/api/v1` and 341 cite `/api/latest`**, so all but a handful declare both, and a client pinned to `/api/v1` reaches every other admin endpoint but not this one.
- **36** — `@ManyToOne(cascade = CascadeType.ALL)` with `@JoinColumn(name = "cm_queue_id")` at `CaseFile.java:267-269` cascades every operation from a case file to the **shared** `AcmQueue` lookup row that every other case file in that queue also references. The same unconditional `CascadeType.ALL` appears at `CaseFile.java:281` (`cm_previous_queue_id`), `Disposition.java:94` (`cm_refer_ext_contact_method_id`, `@OneToOne`) and `Category.java:95` (`cm_category_parent_id`). None of the four columns carries a `baseColumnNames` foreign-key constraint in any changelog, so the database will not refuse what a mistaken cascade does.
- **37 and 38** — `lookup.client.service.js` defines `_getConfig` at `:18-22` and `_getLookup` at `:28-33` against the *same* URL, `api/latest/service/config/:name`, and only the second declares `isArray: true`. The backend method is `ConfigApiController.getConfig`, which returns a pre-serialized JSON object or string. Two definitions of one endpoint disagreeing with each other in a single file is the cleanest available illustration of the wider mismatch entry 37 names, and it is the instance verified end to end.

  Entry 37's **population** was measured rather than its membership: `isArray` appears **366 times across 142 files** in the frontend client tree, with `assets/dist` and `node_modules` pruned. What was *not* done, and is stated plainly rather than implied: each of those 366 was not traced to its backend return type. Doing so would re-derive the review's own work across the entire frozen client tree, and it would change nothing, because every file involved is excluded from modification by the migration plan. The register therefore claims one verified instance and a measured population, not a verified count — a register that asserted "N mismatches" without having checked N of them would be the same defect class this page exists to record.

### 39 to 44 — Six informational observations

- **39** — verified in bytecode rather than inferred. `getTemplateModelProviderDeclaredFields(String classPath)` at `:89` has no `@RequestParam`, so Spring must discover the name; `javap -l` on the compiled class shows a `LocalVariableTable` entry naming slot 1 `classPath`. The build passes no `-parameters` flag — the compiler configuration sets only `<release>` and `-Xlint:all` — so the contract depends on debug information continuing to be emitted.
- **40** — unlocated, see *Anchor Verification* above.
- **41** — `object-calendar.client.service.js:79` posts to `api/latest/service/calendar?calendarId=…`, and the POST handler at that base path, `AcmCalendarAPIController.addCalendarEvent`, declares only `@RequestPart("data")` and `@RequestPart("file")`. The string `calendarId` does not occur in that controller at all.
- **42** — `isArray: true` sits inside the options object passed to `$http` at `case-billing.client.service.js:10` and `:28` and at `complaint-billing.client.service.js:10` and `:28`. `isArray` is a `$resource` action option; `$http` has no such option and silently ignores it.
- **43** — `acm-service-authentication-token/pom.xml` declares `javax.servlet:javax.servlet-api` at `:89-93` with `<scope>test</scope>` and again at `:108-111` with no scope. The compile-scope declaration wins and the test-scoped one is inert. **Maven itself reports this on every build**, which is the strongest possible corroboration of the anchor: `'dependencies.dependency.(groupId:artifactId:type:classifier)' must be unique: javax.servlet:javax.servlet-api:jar -> duplicate declaration of version (?) @ line 108, column 21`. It is a warning rather than an error, so the build succeeds and the condition persists.
- **44** — measured against the assembled WAR, class set against class set:

| Pair in `WEB-INF/lib/` | Classes | Overlap | Unique |
|---|---|---:|---|
| `jsr305-3.0.2.jar` / `annotations-2.0.1.jar` | 35 / 62 | **34** | 1 in the first, 28 in the second |
| `jcip-annotations-1.0.jar` / `jcip-annotations-1.0-1.jar` | 4 / 4 | **4** | **none either side** — and the class files are byte-different |
| `geronimo-jta_1.0.1B_spec-1.0.1.jar` / `geronimo-jta_1.1_spec-1.1.1.jar` | 17 / 18 | **17** | none in the first, 1 in the second |

These are deliberately **outside** the scope of the JSR-250 duplication this change set did resolve. That fix was justified by a specific, measured condition — two providers of the same fifteen `javax.annotation` classes, one of them the API the migration reinstated on purpose — and it was applied as a single targeted exclusion on the managed entry that introduced the intruder. Extending it to three further pairs would be classpath cleanup with no compatibility justification, which R-1 places out of scope, and each pair needs its own provenance analysis before anything is excluded. Registered.

### 45 — An error-path test that passes without executing its error path

`AWSTranscribeServiceTest.create_Error_While_Upload` reports a pass and never runs a single one of its assertions. The test stubs the S3 upload to throw, calls `create`, and puts three `verify` calls and two assertions inside a `catch (Exception e)` block — but the stub is matched on `eq(inputStream)`, the class's `@Mock FileInputStream` field, while the stream the service under test actually receives is a different mock, assigned at `:254` as `mediaStreamOverride = fileStream`. The matcher never matches, so `putObject` never throws, `create` runs to its final `return mediaEngineDTO`, and the `catch` body is dead code. There is no `fail(...)` after the `try` to catch that: `grep -c "fail("` over both AWS test classes returns **0**.

Measured rather than reasoned: with JaCoCo scoped to a single method and the exec file deleted first, the executed-line trace of `AWSTranscribeServiceImpl` shows the whole happy path covered and `return mediaEngineDTO` reached, while every `throw` on the upload path shows zero coverage. Its two sibling error tests are genuine by the same measurement — their `throw` lines are covered and the final return is not.

**Pre-existing, and the migration preserved it faithfully.** At the base commit the same mismatch existed in PowerMock form: `whenNew(FileInputStream.class)…thenReturn(fileStream)` supplied `fileStream` while the stub matched `eq(inputStream)`. The baseline archive records all six methods of the class passing on the older runtime, `create_Error_While_Upload` included, so the rewritten test reproduces the baseline outcome exactly — which is what R-7 required of it.

**Why it is not fixed here**, stated precisely because the fix looks like a two-character change. Making the stub match the stream the seam supplies does make the exception fire — and then the **first assertion in the catch block fails**. `verify(awsTranscribeConfigurationService, times(1)).getAWSTranscribeConfig()` cannot hold on that path: `create` calls `getAWSTranscribeConfig` itself and `uploadMedia` calls it again before `putObject`, so the real count when the exception fires is two, not one. Repairing the test therefore requires **rewriting an existing assertion**, which the PRESERVE list forbids outright, and R-6's escape clause does not reach it because no validation item is blocked — the test reports the same result as the baseline. Fixing the matcher without touching the assertion would convert a false pass into a false failure, which is worse than either.

**The repair, for whoever owns it in a change set whose purpose is that repair:** point the stub at the stream the seam supplies, correct the interaction count to the two calls the production code actually makes, and add `fail("expected CreateMediaEngineToolException")` after the `try` body in all three error tests so this class of vacuous pass cannot recur silently. The last part matters most: the defect is invisible in a green summary, and nothing in these classes guards against it.

### 46 — A build plugin that rewrites six tracked source files on every build

`license-maven-plugin:1.16:update-file-header` inserts its 27-line licence header into six tracked files on every `install`, 162 inserted lines in total, leaving the working tree dirty after a clean build. The six are `acm-services/acm-service-portal-gateway/src/main/java/com/armedia/acm/portalgateway/model/PortalUserConfig.java`, `.../portalgateway/service/PortalUserConfigurationService.java`, `.../portalgateway/service/PortalUserConfigurationServiceImpl.java`, `.../portalgateway/web/api/ArkCasePortalUserAPIController.java`, `acm-standard-applications/acm-foia/src/main/java/gov/foia/service/dataupdate/CreateAnonymousPersonExecutor.java` and `acm-tool-integrations/acm-camel-context-manager/src/main/java/com/armedia/acm/camelcontext/utils/FileCamelUtils.java`.

Counted from a real build rather than taken on trust, and reproduced on every full build of this change set. The plugin is behaving as configured — the files simply lack the header it enforces — so this is a repository-hygiene defect, not a plugin defect, and it is JDK-independent. It is recorded because it has a practical consequence for anyone verifying this migration: **a `git status` after a build shows six modified files that no change set touched**, and mistaking them for someone's edits is easy. Discard them with `git checkout --` and never commit them. Committing the headers would be the fix, and it belongs in a change set of its own — it would add 162 lines of unrelated diff to a migration whose reviewability depends on every line having a reason.

### 47 — A test context naming a bean class that is not on its classpath

`acm-plugins/acm-default-plugins/acm-complaint-plugin/src/test/resources/spring/spring-library-complaint-plugin-test.xml:88` declares a bean of class `com.armedia.acm.services.templateconfiguration.TemplatingEngine`. Two things are wrong with that name: the class is actually `com.armedia.acm.services.templateconfiguration.service.TemplatingEngine` — the package segment `service` is missing — and `acm-complaint-plugin/pom.xml` declares no dependency on `acm-service-template-configuration` at all, so no spelling of it would resolve. Two integration tests in the module consequently fail with `CannotLoadBeanClassException`.

JDK-independent, and pre-existing: neither the test resource nor that POM is touched by this change set. It became visible only because provisioning the deployment configuration folder let the context initialise far enough to reach the declaration; before that the same tests failed earlier, on a missing configuration file. That is worth recording on its own account — **removing one blocker exposes the next one**, and a defect that only appears after an environment is repaired is easy to mistake for a regression the repair caused.

### 48 — Two providers of the `org.objectweb.asm` package in the packaged WAR

`WEB-INF/lib` contains both `asm-3.3.1.jar` and `asm-9.8.jar`. They are not two versions of one artifact from Maven's point of view — the first has groupId `asm`, the second `org.ow2.asm` — so no resolution rule reconciles them, and they publish the same package. ASM changed `org.objectweb.asm.FieldVisitor` from an interface to a class in version 4, so code compiled against either shape fails against the other with `IncompatibleClassChangeError`. The old jar reaches the WAR through `chemistry-opencmis-client-bindings` and `cxf-rt-frontend-jaxws`.

Latent rather than active, and the reason is worth stating: nothing in the deployed application generates bytecode through that package. MVEL and Drools both use a relocated copy under `org.mvel2.asm`, EclipseLink uses its own relocated ASM, and the JAX-WS frontend that would use the old jar is never exercised — there are zero occurrences of that API anywhere in the tree.

Pre-existing and unchanged by this migration; both jars are present at the base commit. It is registered rather than removed because a reactor-wide exclusion changes the classpath of 141 modules that never load ASM at run time, and unaudited classpath change is exactly what a behaviour-preserving migration cannot afford. Nor is it excluded in any single module: an earlier revision of this change set did exclude it in one place, to keep a standalone script engine initialising, and that whole line of work has been withdrawn — see entry 57 — so the exclusion went with it and the classpath here is the base commit's classpath.

A second, related duplication is registered with it, and it is the sharper of the two. `net.minidev:accessors-smart` `1.1` does not depend on ASM; it **bundles** a stripped ASM 4 inside itself, 27 class entries under the real `org/objectweb/asm` package, in which `org.objectweb.asm.Handle` carries only the four-argument constructor. Which of two `json-smart` lines a module resolves is decided purely by declaration order: 49 modules receive `2.2.1` with `accessors-smart` `1.1` through `json-path`, and 29 receive `2.4.10` with `2.4.9` through `oauth2-oidc-sdk`. Order-sensitive resolution of a duplicated package is exactly what R-T4 exists to prevent, and pinning the pair centrally would eliminate it in one line. It is nonetheless **registered rather than pinned**, for the same reason as the jar above and one more: the split is the base commit's own behaviour, nothing in the deployed application loads bytecode-generation through that package, and R-7 makes the baseline the tie-breaker where a change has no compatibility justification of its own. The only justification the pin ever had was the withdrawn engine in entry 57.

### 57 — Seven BPMN task listeners ask for an engine the target runtime does not register

`acm-plugins/acm-extra-plugins/acm-personnel-security-plugin/src/main/resources/activiti/personnelSecurityBackgroundInvestigation_v11.bpmn20.xml` declares **seven** `complete`-event listeners of class `ScriptTaskListener`, each carrying a `language` field whose value is `javascript`, at `:48`, `:68`, `:88`, `:110`, `:121`, `:144` and `:155`. It is a **main** resource, not a test fixture, and it is the only file in the BPMN corpus that references a script language at all — `grep -rl 'javascript\|scriptFormat\|ScriptTaskListener' --include=*.bpmn20.xml` returns exactly this one path.

This is the second route by which JEP 372 reaches the application, and it is materially different from entry 7. Entry 7's two call sites are unreachable dead code that never executed on any runtime. These seven **did** execute: on a JDK that shipped Nashorn, `ScriptEngineManager` registered one factory whose aliases include `javascript`, and Activiti resolved it while a task was completed. On the target runtime the manager registers no factory for that name, the lookup returns `null`, and the listener fails on the next dereference. Both methods of `BackgroundInvestigationBusinessProcessIT` error, and the two errors are **not** the same error — a distinction worth stating, because collapsing them would double-count one fault. `startProcess_processStart_happyPath` errors with `Exception while invoking TaskListener: … Can't find scripting engine for 'javascript'`; `startProcess_processStart_denyClearance` errors with `Query return 2 results instead of max 1` and carries no engine message and no `Caused by` chain at all. Its stack nevertheless runs through the same `completeTask` helper, and the fixture shares one in-memory database across both methods, so the second error is the **downstream consequence** of the first method leaving its process instance uncompleted rather than a second independent engine failure. One cause, two red methods. It is a **regression in behaviour**, not a latent defect, and this register does not pretend otherwise.

**Why it is registered rather than remedied, and why that decision is not the implementer's to re-make.** The obvious remedy is to declare the standalone OpenJDK build of the engine for this one module, and an earlier revision of this change set did exactly that — with two further dependency pins behind it, because the engine will not initialise while a stripped ASM 4 and an ASM 3 jar sit on that module's classpath. The migration plan reached this question directly and decided against it: supplying an engine introduces a library to the production dependency graph solely to support code the platform no longer runs, which is not a compatibility-blocking upgrade under R-1, and it *masks* a defect that ought to be visible. The plan named the alternative explicitly — register it. A plan decision taken on the merits is not a gap that new measurement fills; it is the frozen answer, and the measurement's proper home is this page. So the engine, the exclusion and the two pins are all withdrawn, and what remains is this entry, carrying the measurement the withdrawn rows were justified by.

**What a reader has to know to act on it.** The behaviour lost is the completion side-effect of seven listeners in one workflow of one optional plugin. That plugin is referenced by no other POM, so no other module and no other workflow is affected, and the packaged application carries no script-engine jar either before or after this change set. Two integration-test methods error on the target runtime and are recorded in [Baseline Test Failures](baseline-test-failures.md) as such — as a migration-attributable integration failure, not as a pre-existing one, because it is not pre-existing and calling it that would be the reclassification this register exists to prevent. Restoring the behaviour is a one-property, one-declaration, two-pin change whose exact content is preserved in the withdrawal note of the [Dependency Change Inventory](dependency-change-inventory.md); it needs a plan revision, not a code review.

### 49 — The final pipeline task writes into a directory that no checkout contains

`config/env/all.js:10` sets `modulesConfigFile` to `modules_config/config/modules.json`. The tracked tree contains three files under `modules_config/` — `permissions/modules.json`, `schemas/empty.json` and `schemas/grid.json` — and **no `config/` directory at all**. Reads of that path are guarded by an existence check (`Gruntfile.js:290`); the write at `Gruntfile.js:349` is not. So `copyToModulesConfigFolder`, the last task in the `default` graph, raises `ENOENT: no such file or directory, open 'modules_config/config/modules.json'` on any checkout, and `grunt.option('force', true)` at `Gruntfile.js:144` turns that into a warning and lets the process exit zero. It is the same masking mechanism as entries 3 and 4, claiming a third casualty — and unlike those two, this one sits inside the task graph the build actually runs.

Measured on this host after the migration, on Node 20.20.2 with npm 10.8.2: a lockfile install followed by the build script exits **0**, prints exactly that warning, and produces **all five** output artefacts — `assets/dist/application.js`, `application.min.js`, `vendors.min.js`, `application.min.css` and the rewritten `home.html`. The artefacts are unaffected because every one of them is written by an earlier task; the broken task is last in the graph and contributes nothing to them. This is precisely why the frontend gate asserts on produced artefacts rather than on the exit code: here the exit code is zero *and* a task failed, and only the artefact list distinguishes a good build from a bad one.

Pre-existing and unchanged by this migration — no file under `resources/` other than the dependency manifests is touched by this change set, and neither `Gruntfile.js` nor `config/env/all.js` is touched at all. It is registered rather than fixed because both available repairs change what the pipeline does with module configuration rather than what it produces: creating the directory, or making the write recursive, would let the task register newly discovered modules into a file the deployed application reads, which is a behaviour the baseline does not have. R-6's escape clause does not reach it either, because the gate is not blocked — the build exits zero and every artefact is produced.


### 50 — A stylesheet endpoint answers 500 where 406 belongs

`GET /branding/customcss` returns **HTTP 500** with the `text/plain` body `Could not find acceptable representation` (40 bytes) to a client sending `Accept: */*`, no `Accept` header at all, `Accept: text/plain`, `Accept: text/html` or `Accept: application/json`. It returns **200** with 3,778 bytes of `text/css` to `Accept: text/css` and to the Accept string a real browser sends for a stylesheet, `text/css,*/*;q=0.1`. Measured on the deployed application across a 24-cell matrix; `/login`, `/assets/css/login.css` and `/branding/loginlogo.png` return 200 for every one of the same headers, so it is this endpoint alone.

Two pre-existing pieces combine to produce it, and neither is in this change set:

1. `servlet-context.xml:46-48` declares a `ContentNegotiationManagerFactoryBean` with `defaultContentType = application/json`, wired into `<mvc:annotation-driven content-negotiation-manager=…>` at `:59`. Spring's `ContentNegotiationManager.resolveMediaTypes` **skips** any strategy that returns exactly `[*/*]` and falls through to the next one, so a request whose `Accept` is `*/*` — or absent, which Spring treats identically — resolves to the fixed `application/json`. That is incompatible with the handler's `produces = "text/css"` (`CustomCssRetrieveFile.java:52`), and Spring raises `HttpMediaTypeNotAcceptableException`. This also explains, exactly, why the browser Accept string succeeds: it is not equal to `[*/*]`, so the header strategy wins and its `*/*;q=0.8` term is compatible with `text/css`.
2. `AcmSpringMvcErrorManager.lastChanceHandler` — the `@ExceptionHandler(Exception.class)` catch-all at `AcmSpringMvcErrorManager.java:135-140`, already registered as entry 32 above — maps any otherwise-unhandled exception to `INTERNAL_SERVER_ERROR` and writes its message into the body. That is what turns what Spring's own `DefaultHandlerExceptionResolver` would have reported as a 406 into a 500 carrying the exception text.

**Not user-facing.** All nine consuming JSPs load it with `<link rel="stylesheet">`, and every real browser Accept string yields 200; the deployed login page received 200 for it on all four verification loads and the branding CSS visibly applied, with no unstyled flash.

Registered rather than fixed for a reason stronger than R-6 alone: **the migration plan's preservation list forbids the repair.** Both candidate fixes — dropping `produces = "text/css"` and setting the content type explicitly, or returning a `ResponseEntity<String>` — change a controller's request mapping or its signature, and the plan states plainly that no controller signature, request mapping or serialized field changes anywhere. Changing `defaultContentType` instead would alter negotiation for *every* endpoint in the application, which is a far larger behavioural change than the defect it repairs. The correct repair belongs to a change set that owns the content-negotiation configuration and can re-test every endpoint against it. Recorded as [Ambiguity Resolutions](ambiguity-resolutions.md) entry 15, because the decision needed a tie-breaker rather than just a note.

### 51 to 56 — Six login-page defects, none of them reachable from the migration's change surface

The login page is a JSP served outside the Angular application: `acm-services/acm-service-login/src/main/resources/META-INF/resources/views/login.jsp`, styled by `resources/assets/css/login.css`. `git log` over the migration range returns empty for both, and `login.css` is additionally **outside every CSS glob the pipeline consumes** — `config/env/all.js` builds `application.min.css` from `assets/css/application.css`, `modules/**/css/*.css` and `assets/css/arkcase-extension.css` — so it is neither built nor bundled, and its content cannot have moved with the toolchain change.

- **51 — Overflow and truncation at 320 px.** `login.css:20-24` fixes `.login-wrapper { width: 330px; margin: 0 auto }`. At a 320 px viewport the browser resolves the auto margin to `-10px`, ten elements — including `button#submit` and `div.pull-right` — breach the right edge by exactly 10.00 px, and the "Forgot Password" text range ends at x = 330, so 10 px of it is genuinely clipped. There is no `<meta name="viewport">` in the page at all. Fixing it means either a fluid width or a viewport meta tag, both of which change the rendered layout at every width — the definition of a UI change, which the migration's exclusion list forbids alongside a new frontend framework and TypeScript.
- **52 — Uncleared floats.** `login.jsp:230` and `:233` are `div.pull-left` / `div.pull-right` with no clearing element, so they sit 10 px below their parent's bottom edge while the next in-flow sibling, `div.text-center.padder` at `:240`, starts where the parent ends. The overlap reaches 2,273 px² over the left link at every width. Corroborated arithmetically by `login-wrapper` `scrollHeight` 346 against `clientHeight` 316, and `form#login-form` 207 against 177 — the same +30 px in both. A latent click-target hazard rather than an observed failure: both links remain clickable and keyboard-reachable.
- **53 and 54 — Modal focus behaviour.** Neither `.modal` div carries `tabindex="-1"`, so Bootstrap 3's `$element.focus()` on show is a no-op and focus stays on the trigger anchor. Because Bootstrap binds `keydown.dismiss.bs.modal` to the `.modal` element itself, Escape pressed from outside the dialog is inert — measured: `display` stays `block`, `body.modal-open` is retained and the backdrop is retained — and the tab cycle walks through six page controls behind the backdrop, three of them fully occluded by the dialog panel. One attribute would fix both, and one attribute on a template is still a template change: the exclusion list freezes every template, and the modal footer's inverted `pull-right`/`pull-left` button order has the same standing.
- **55 — A 1.25:1 focus indicator on the login inputs.** Bootstrap's `.form-control:focus{outline:0}` removes the ring, and `login.css:30-35` `.no-border { border-width: 0 }` makes the focus `border-color: rgb(102,175,233)` unpaintable, leaving only a `0 0 8px` glow whose measured peak `rgb(213,233,249)` on white is **1.25:1** against the 3:1 threshold. That the cause is `login.css` and not Bootstrap is provable inside the same page: the forgot-password modal's `#email` input has no `.no-border` and paints a crisp blue focus border *plus* the glow, and `button#submit` measures **3.42:1 and passes**. WCAG conformance is real, and it does not outrank the exclusion list here: this is a stylesheet the migration is required to leave exactly as it is, and improving it would also be the one change on this page that alters what a user sees.
- **56 — An HTML5 `pattern` that current Chrome ignores.** `login.jsp:201` declares `pattern="[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,3}$"`. That expression compiles with no flag and with `u`, and correctly rejects a non-email value — but it throws `SyntaxError: Invalid character in character class` under the **`v`** flag, which current Chrome uses to compile `pattern`, because of the unescaped trailing `-` inside `[a-z0-9._%+-]`. Per specification a pattern that fails to compile is ignored, so `patternMismatch` is permanently false and the "you must provide a domain" hint is unenforced; one console error is logged whenever constraint validation runs. Independently confirmed against a control field, whose `pattern="[0-9]+"` correctly reported `patternMismatch` on the same page, so pattern validation works in general and only this expression is broken. The repair is two characters (`[a-z0-9._%+\-]`, and the trailing `$` is redundant) — and it is a template change that would newly start **rejecting input the deployed application currently accepts**, which is a behavioural change to authentication input handling, not a cosmetic one.

All six produced **zero** console output and **zero** failed network requests during verification. That is worth stating on its own: a console-and-network smoke check declares this page healthy, which is why they were found by measuring geometry, computed styles and key handling rather than by reading a log.

## The Escape Clause, Invoked Exactly Twice

R-6 permits fixing a pre-existing defect when it blocks a validation item. Two conditions blocked the fresh-checkout frontend build gate, which runs a clean checkout, deletes every untracked file, installs from the lockfile and runs the build. Both were fixed. Both are labelled here so the count is auditable and cannot grow quietly.

| # | Condition fixed | Why it blocked the gate | Why the fix is behaviourally inert |
|---|---|---|---|
| E1 | `profiles.js` was absent from version control | `config/config.js:16` requires `./../profiles`, and the gate's clean step deletes every untracked file before installing. The module was written at deploy time, so a fresh checkout could not build at all | The deploy-time writer uses replace-existing semantics, so a deployed environment continues to overwrite the tracked default with its own value. The tracked file exports `{ profiles: [ ] }`, matching what that writer emits |
| E2 | The Sass toolchain could not build on Node 20 | Its transitive native compiler fails to install — the only failure among eighteen legacy packages tested — so the install step could not complete | Removal, not replacement, and output-neutral by entry 5 above: no Sass task is declared and the SCSS globs are never consumed. Modern replacements were verified to install and were **declined on evidence, not availability** |

**Neither invocation is a register entry, and no third invocation exists.** The arithmetic is exact: **56 register entries, 0 fixed, 2 escape-clause invocations, and no overlap between the two sets.** E1 created a file that was absent from version control, and E2 removed a build package — neither is a row above. Every one of the 56 entries is still present in the tree, unmodified, and can be re-verified at the anchor it cites.

That last point is the one most easily misread, because both invocations land *next to* a registered entry without touching it. E1 creates the module that entries 1 and 2 load, and leaves both logic errors exactly as they were; E2 removes a package whose absence entry 5 explains, and leaves the inert pipeline inert. It is tempting to net the two against the register and conclude that two of the first eleven were dealt with — **they were not**. All eleven of the plan's mandated entries remain unfixed, as do all forty-nine. The count of invocations and the count of unrepaired entries are separate figures, and both are stated here so neither has to be inferred.

That last point is the one most easily misread, because both invocations land *next to* a registered entry without touching it. E1 creates the module that entries 1 and 2 load, and leaves both logic errors exactly as they were; E2 removes a package whose absence entry 5 explains, and leaves the inert pipeline inert. It is tempting to net the two against the register and conclude that two of the first eleven were dealt with — **they were not**. All eleven of the plan's mandated entries remain unfixed, as do all forty-nine. The count of invocations and the count of unrepaired entries are separate figures, and both are stated here so neither has to be inferred.

Two things make that narrow reading visible rather than merely asserted. Entries 1 and 2 sit in `config/config.js` — the very file that E1 makes loadable — and were still left alone, even though they are a few characters each and the file was already open. And entries 22 to 32 are eleven security defects, the category with the strongest pull toward "fix it while you are here"; not one was touched, because none of them blocks a validation item and the migration plan's preservation list requires security outcomes to be **unchanged**, which makes adding an authorization check a deviation from the plan rather than compliance with it.

Entry 45 is the sharpest illustration of the cost of reading the clause that narrowly: a two-character change would make its error path execute, and it is left alone because the assertion behind it would then have to be rewritten, which the preservation list forbids.

### What is not an escape-clause invocation

An exception count only stays honest if the categories adjacent to it are named, because the way a count of two becomes a count of five is not a decision — it is a reclassification nobody wrote down. Each item below changes code or configuration in this change set and is **migration work carried out under another rule**, not a pre-existing defect that was repaired:

| Change | Why it is not an invocation | Recorded in |
| --- | --- | --- |
| The **seven** JDK-internal usage remediations — three compile-visible substitutions, one string literal externalised into Spring configuration, and three Javadoc rewrites | Required by the static audit gate, which is textual and demands zero occurrences. The audit found 7 occurrences across 5 main-source files at the base commit and finds 0 now. None of the seven was a defect; each was a supported-API substitution | [Static Audit Output](static-audit-output.md) |
| Removing the two dead repository declarations, `milton-repo` and `jcenter-snapshots` | A resolution-level compatibility change: the modern Maven baseline blocks the plain-HTTP URL outright, so this is R-1 work with a stated reason | [Dependency Change Inventory](dependency-change-inventory.md) |
| Rewriting the six mocking-framework-dependent test classes | R-5 compliance. The framework they used has no release that runs on the target runtime and no successor version, so rewriting them onto the supported mocking library is what *avoids* disabling them. Not one assertion changed | [Baseline Test Failures](baseline-test-failures.md) |
| Reinstating the standalone script engine as a Maven artifact | R-1 work for a **different and genuinely reachable** consumer — the seven `complete`-event script task listeners described in entry 7 — in the same category as reinstating the EE modules the platform removed. It is declared by one module only, and deliberately **not** by the two modules entry 7 names, so entry 7 is untouched by it | [Dependency Change Inventory](dependency-change-inventory.md) |
| Removing the vendored package manager and the dead client-side package manager from the frontend manifest | R-4 work: the frontend must genuinely run on the target runtime with no vendored dead packages. Neither removal repairs a registered defect. Only the **Sass toolchain** removal in the same manifest is an invocation, and it is row E2 above | [Dependency Change Inventory](dependency-change-inventory.md) |

**R-5 draws the boundary from the other side.** Nothing in this register is grounds for excluding a test. A test exclusion may cite only a failure already present at the baseline, and the register it must cite is [Baseline Test Failures](baseline-test-failures.md) — not this page. Entries 12 and 45 are the cases where the two registers touch: both are pre-existing test defects, both are recorded, and neither was disabled or excluded.

## What Is Not on This Page

Two categories are deliberately excluded, because including them would blur what this register means.

**A migration-induced failure is not a pre-existing defect, and the one that exists is not recorded here.** A regression is not an inherited condition, and putting one on this page would launder it into accepted state. The **unit** corpus carries none: the migrated run archived under [Baseline Test Failures](baseline-test-failures.md) records **3 failures and 1 error across 284 suites and 933 test methods, and every one of the four maps to a registered baseline row** — the same three `FileDownloadAPIControllerTest` failures and the same `FolderCompressorTest` error that the JDK 8 baseline produced. The entire delta between the two archives is six added suites and 41 added test methods, all passing.

There is exactly one migration-attributable red anywhere, it is the **integration** test entry 57 above describes, and it is registered in that same companion page under its own heading — as a migration-attributable failure, explicitly not as a pre-existing one. That is the correct home for it: this page accepts inherited conditions, and that failure is not inherited. Any future failure that does not trace to a baseline row belongs there as a regression too, never on this page.

**Frontend dependency advisories have their own register.** They are a security posture with a remediation plan and risk-accepted exceptions, not a list of code defects, and they are recorded in [Frontend Dependency Security](frontend-dependency-security.md).

## How to Use This Register

- **Fixing an entry.** Do it in a change set whose purpose is that fix, so the resulting behaviour difference has one explanation. Entries 1 and 2 in particular need a configuration with active profiles to test against, which this change set does not have.
- **Adding an entry.** Verify the anchor against the tree, state what makes it a defect, and state why it is out of scope. An entry without the last part is a to-do list item wearing a register's clothes.
- **Invoking the escape clause.** Name the validation item blocked, and add a row to the table above. If a third row ever appears, the reason it is not simply "we also fixed this one" must be on it.
- **Interpreting a build failure.** Check entry 6 first. An unprovisioned local artifact repository looks exactly like a dependency resolution regression and is neither.

## Verification

A register asserting that nothing was fixed is only as good as a reviewer's ability to refute it. These checks do that directly against the tree, comparing the base commit `c8f6226105` with the migrated head. Each was run while writing this page and each produced the result stated beside it.

```
# 1. The three frozen frontend contract files carry entries 1 to 5.
#    Expect NO output: they are byte-for-byte unchanged.
git diff --stat c8f6226105 HEAD -- \
  acm-standard-applications/arkcase/src/main/webapp/resources/config/config.js \
  acm-standard-applications/arkcase/src/main/webapp/resources/Gruntfile.js \
  acm-standard-applications/arkcase/src/main/webapp/resources/config/env/all.js

# 2. Entries 8 to 11 — the four dead dependencies are still declared.
#    Expect castor-xml, spring-ws-core, axis and commons-discovery, all present.
grep -n "castor-xml\|spring-ws-core\|>axis<\|commons-discovery" \
  acm-services/acm-service-billing/pom.xml

# 3. Entry 6 — the local repository declarations are retained, not deleted
#    to make a build green. Expect 7.
grep -c "arkcase-lib" pom.xml

# 4. Entry 7 — both script-engine call sites are untouched.
#    Expect NO output.
git diff --stat c8f6226105 HEAD -- '*/JavaScriptEvaluatingPredicate.java'

# 5. Entries 7 and 57 — no POM anywhere declares a script engine, so every
#    script-engine call site still resolves to nothing. Expect NO output.
grep -rn "<groupId>org.openjdk.nashorn</groupId>" --include=pom.xml .

# 5b. Entry 57 — the seven listeners are still there, unedited. Expect 7.
grep -c "javascript" \
  acm-plugins/acm-extra-plugins/acm-personnel-security-plugin/src/main/resources/activiti/personnelSecurityBackgroundInvestigation_v11.bpmn20.xml

# 6. The escape clause — exactly two invocations, and nothing else.
#    Expect profiles.js added and package.json modified, with the Sass
#    toolchain absent from the manifest.
git diff --name-status c8f6226105 HEAD \
  -- acm-standard-applications/arkcase/src/main/webapp/resources
grep -c "grunt-sass" \
  acm-standard-applications/arkcase/src/main/webapp/resources/package.json
```

Check 6 is the one worth reading closely. The frontend delta is five files — a runtime pin, a lockfile, the manifest, the generated profiles module and the removal of the superseded lockfile — and only two of those five are escape-clause invocations. The other three are ordinary migration work. If a future change set adds a sixth, the question the table above must answer is which rule authorised it.

Related registers: [Dependency Change Inventory](dependency-change-inventory.md), [Baseline Test Failures](baseline-test-failures.md), [Ambiguity Resolutions](ambiguity-resolutions.md), [Static Audit Output](static-audit-output.md) and [Frontend Dependency Security](frontend-dependency-security.md). The **JDK Access Exceptions** register completes the set; it is reached from the *Runtime Migration* section of the site navigation.
