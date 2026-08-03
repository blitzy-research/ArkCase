# Pre-existing Defects

This page is the register of defects that were **discovered during** the runtime migration onto Java 17 and Node 20 LTS and **deliberately not fixed**. It exists because a rule demands it as a deliverable, not because any feature description mentions it.

Its completion condition has two halves, and the second is the one that makes the page useful: every entry is present, and **the escape clause is shown invoked exactly twice**. A register listing defects without accounting for the exceptions to its own rule would let the exception count grow quietly, which is the failure mode it exists to prevent.

Every anchor on this page was verified against the working tree rather than copied from a plan. Where a measurement differs from what was expected, the measured value is given.

## Rules Provenance

Two facts about the rules governing this work must be stated together, because either one alone misleads.

- **There is no on-disk user rules document for this project.** The project's rules facility reports, verbatim, *"No user rules provided."*
- **Rules are nonetheless present and binding.** The requirements embed an explicit, numbered RULES block of seven rules, plus seven transformation rules that are the operational form of the PRESERVE and EXCLUDE lists. Fourteen constraints apply.

The identifiers `R-1` through `R-7` and `R-T1` through `R-T7` are the **migration plan's own navigational convention**, not quoted titles.

One rule governs this page:

> **R-6 — Document discovered bugs, do not fix them.** Pre-existing bugs discovered during the work are documented rather than fixed, **unless one blocks a validation item.**

The clause after "unless" is an escape hatch, and an escape hatch that is used freely is not a constraint at all. It is invoked twice in this change set. Both invocations are labelled as such, both are in the frontend track, and both block the same validation gate.

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
| 9 | Spring Web Services declared, never imported | `acm-service-billing/pom.xml:L102-L105` | Dead dependency | No |
| 10 | Apache Axis declared, never imported | `acm-service-billing/pom.xml:L118` | Dead dependency | No |
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
| 34 | L2 | **Verified and found NOT to be a defect** — see below | `resources/modules/document-repository/services/document-repository-info.client.service.js:28-31` → `DocumentRepositoryAPIController.java:127` | Not a defect | n/a |
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

**Forty-nine entries. Zero fixed** — entry 34 is recorded as *not a defect* after verification, which is a different statement from *fixed*, and entry 40's anchor could not be located.

The five entries in numbers 45 to 49 were discovered by the Java 17 backend and build re-test, and each was verified present at the base commit before being written down. The thirty-one entries added in numbers 14 to 44 were **not** discovered by this migration. They were reported by the checkpoint code review, and each was then **re-verified against the working tree** before being written down here; §*Anchor Verification* below records what that verification found, including the three checks that did not come back clean — one where the report's line numbers were wrong, one where its verdict was wrong, and one that could not be checked at all.

### 1 and 2 — Two logic errors in the frontend asset resolver

`config/config.js:16` loads the active profiles with `var activeProfiles = require('./../profiles');`. The module it loads exports an **object** with a `profiles` key, not an array. Both iteration sites — `:83` and `:133` — then do `_.forEach(activeProfiles, function(profile) {…})`, which walks the object's values. The loop therefore runs once with `profile` bound to the whole array rather than once per profile.

The second error compounds the first. At `:88`, `:99` and `:110` the resolver **removes** custom module, directive and service files from the standard lists using `_.difference`, and assigns the result. At `:93`, `:104` and `:115` it means to add them back to the custom lists — but writes `jsCustomModules.concat(profileModulesFiles);` with the result unassigned, and JavaScript's `concat` returns a new array rather than mutating. The same omission appears at `:137` for CSS. The removals take effect and the additions do not.

Both are real, both are pre-existing, and both are invisible today because the tracked profiles list is empty, so the loop body operates on nothing. That is precisely what makes them dangerous to fix here: correcting them changes nothing observable in the current configuration and everything observable in a configuration with active profiles — and the byte-identical artefact comparison, which is the frontend's only behavioural evidence, would be unable to tell the difference.

### 3 and 4 — Two broken Grunt task aliases, masked by forced execution

`Gruntfile.js:379` registers `sync-dev` as `['concurrent:default']`. The only target defined in the `concurrent` block that begins at `:90` is named **`default1`**, at `:91`. The alias names a target that does not exist.

`Gruntfile.js:372` registers `lint` as `['jshint', 'csslint']`. A `csslint` configuration block exists; **a `jshint` block does not** — measured, zero occurrences. Half of that alias cannot run.

Neither is fixed, and neither is the interesting part. The interesting part is `Gruntfile.js:144`, `grunt.option('force', true)`, which makes a failing task non-fatal. Both aliases can therefore fail while the process exits zero. That single line is the reason the validation approach for this migration asserts on **produced artefacts** rather than on exit status, and it is why the frontend baseline was captured by archiving the five build outputs and their digests instead of by checking that the build "succeeded".

### 5 — A stylesheet pipeline that is declared and never executed

`config/env/all.js` declares SCSS globs at `:79` (`modules/**/scss/*.scss`) and `:92` (`_modules/**/scss/*.scss`). **25 `.scss` files are tracked** in the frontend tree — more than the plan anticipated, which is why the measured figure is given here. No task or configuration function consumes either glob: the CSS asset resolver reads only the compiled-CSS globs at `:27` and `:78`.

This entry is load-bearing for a decision recorded elsewhere. The Sass toolchain is *removed* rather than replaced precisely because this pipeline never runs, which makes the removal provably output-neutral. Substituting a modern Sass compiler would have risked emitting different CSS bytes for zero functional gain. See [Dependency Change Inventory](dependency-change-inventory.md).

### 6 — The environment precondition, and the shortcut it invites

Three artifacts do not resolve from Maven Central and are supplied from `file://` local repository declarations at `pom.xml:L235-L249`: an ArkCase license-headers artifact, the TouchNet client that the reactor's only two `javax.xml.rpc`-importing files depend on, and an EclipseLink SLF4J logging bridge. Because `acm-service-billing` is a reactor member, an unprovisioned local repository blocks a full reactor build.

The condition is **JDK-independent and identical at the JDK 8 baseline**, so it is not a migration defect. It is registered here because a red build invites exactly the wrong response: **under no circumstances may the module, the dependency, or the repository declarations be deleted to make the build green.** Deleting a live dependency to pass a gate is the shortcut this migration exists to prevent, and the TouchNet client is demonstrably live — two files import it.

In the baseline and migrated captures the precondition was **satisfied**: the backing repository is present in the tree at `arkcase-lib` and carries all three artifacts, which is why all 142 modules built and both captures are complete rather than partial. See [Baseline Test Failures](baseline-test-failures.md).

### 7 — A latent defect that no compiler and no static audit can see

Two files ask the script-engine manager for the `nashorn` engine: `acm-foia/…/JavaScriptEvaluatingPredicate.java:94` and `acm-privacy/…/JavaScriptEvaluatingPredicate.java:98`. That engine was removed from the JDK in version 15.

These files **compile cleanly at release 17**, because `javax.script` remained in the JDK — only the engine implementation went. The lookup returns `null` at run time and the next dereference throws. No compiler warns, and the JDK-internal usage audit cannot see it either, because the code names no internal package: it passes a string to a supported API. It is the only defect in this register that a green build actively conceals.

Both copies are **provably unreachable**. In `acm-foia` the only Spring declaration of the predicate bean sits inside a comment region, its only consumer is commented, and the enclosing property assignment is commented as a whole; the active declaration names a different, non-JavaScript predicate class. In `acm-privacy` there is no XML reference at all — the apparent cross-module references are `<bean>` examples inside Javadoc. Nothing in either module — no XML, properties file or shell script — reaches these two call sites.

Adding a standalone script engine **to these two modules** to make this code work would introduce a library to the production dependency graph solely to support code that cannot execute — a change with no compatibility justification, which R-1 forbids — and would convert dead code into live code, which is a behaviour *change* relative to the baseline. Documenting it is the R-7-consistent outcome, and it stays the outcome even though the same platform removal **is** remediated elsewhere.

That distinction has to be stated explicitly, because the change set does now declare a standalone engine — in exactly one other module, `acm-personnel-security-plugin`, whose main-resource BPMN definition drives seven `complete`-event script task listeners with a `javascript` language field. Those listeners **executed at the baseline and stopped executing on the target runtime**, which makes them a regression rather than a latent defect, and R-7 requires restoring them. The engine is deliberately not declared by `acm-foia` or `acm-privacy`, so these two call sites still resolve to nothing and still never run. The full split and its rejected alternatives are in [Ambiguity Resolutions](ambiguity-resolutions.md); the artifact and its two classpath consequences are declared in [Dependency Change Inventory](dependency-change-inventory.md).

### 8 to 11 — Four dead dependencies, registered rather than removed

| Dependency | Declared at | Imports found |
|---|---|---|
| `org.codehaus.castor:castor-xml` `1.3.3` | `pom.xml:L48`, managed `:L1156-L1158`, in seven child POMs | **0** — no Java imports, no XML or properties references, no mapping files |
| `org.springframework.ws:spring-ws-core` `1.5.9` | `acm-service-billing/pom.xml:L102-L105`, hardcoded outside `dependencyManagement` | **0** |
| `org.apache.axis:axis` `1.4` | `acm-service-billing/pom.xml:L118` | **0** |
| `commons-discovery` `0.5` | `acm-service-billing/pom.xml:L123-L124` | **0** |

All four import counts were re-measured against the working tree for this page.

The temptation to delete them is strong: they are ancient, one of them is a SOAP stack, and removing four unused declarations looks like unambiguous hygiene. They are kept because **they are never loaded, so they present no Java 17 risk**, which means removing them is unrelated cleanup — and unrelated cleanup has a real cost in this change set. Altering the declared dependency set changes classpath composition and ordering in ways nobody audited, and any resulting difference would be indistinguishable from a migration regression. R-1 also cuts the same way: a dependency change with no compatibility justification is out of scope, and "it is untidy" is not a compatibility justification.

### 12 — A unit-test assertion that never held

`GroupServiceTest.testSaveAdHocSubGroup_newSubGroup` asserts, at `:218`, that `saveAdHocSubGroup` calls `groupService.save(…)`. The production method does not call `save` at all: it calls `createGroup` and then `parent.addGroupMember`. The assertion was being satisfied by the invocation that the test's own `when(…)` stubbing performed on the spy.

This is a **pre-existing test defect**, not a migration defect, and the distinction was established by changing one variable: on the same Java 17, with the same source, the test passes with the pre-migration Mockito and errors with the migrated one. The newer Mockito no longer counts a stubbing call as a verifiable interaction, so an assertion that never held has stopped appearing to hold.

It is not fixed because correcting it means rewriting an assertion, which the PRESERVE list forbids, in a test file the authoritative in-scope list does not include. The full mechanism, including the intermediate probe that isolated it, is in [Baseline Test Failures](baseline-test-failures.md) under *Cause C*.

### 13 — Two minified artefacts differ between the historical and the target Node runtime

This is the only entry on this page that the migration itself produced, and it is here rather than hidden in a summary because the alternative is a claim of byte-identity that is not true.

The base-commit frontend was built on **Node v8.17.0 with yarn 1.22.22** and compared against the migrated build on Node 20.20.2. `assets/dist/application.js`, `assets/dist/vendors.min.js` and the rewritten `home.html` are **byte-identical**. `application.min.js` differs by **2 bytes** and `application.min.css` by **789**.

Neither difference is a defect in this repository, and neither is fixable inside the rules:

- Both artefacts are produced by the SAME minifier versions on both sides — `uglify-js` 2.8.29 and `clean-css` 3.4.28, verified in both installed trees — from **byte-identical input**, since `application.js` matches. The variable is the JavaScript engine the minifier runs on.
- The script difference is two occurrences of an escaped forward slash inside one regular-expression character class, where the newer engine no longer emits the escape when it re-serialises a pattern. Normalising that one escape makes the two 2 MB bundles compare **equal**; the two patterns match the same strings.
- The stylesheet difference is `clean-css` grouping the same declarations into different rule blocks. A declaration-level comparison over 13,455 flattened `(selector, property, value)` triples found none present on one side and absent on the other, and the 28 distinct `@media` preludes are identical.
- Changing either minifier would need a Node 20 incompatibility to justify it under R-1, and neither has one: both install and run on Node 20 at the versions the lockfile pins. A version change would also alter the output far more than the difference it was meant to remove.

Recorded, not fixed. The measurement is at [`smoke-evidence/historical-frontend/comparison.txt`](smoke-evidence/historical-frontend/comparison.txt) with the capture script beside it, and the decision — including the options rejected — is entry 6a of [Ambiguity Resolutions](ambiguity-resolutions.md). **This entry does not consume an escape-clause invocation**: the escape clause covers pre-existing defects that were *fixed* because they blocked a validation item, and this one is not fixed.

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

Pre-existing and unchanged by this migration; both jars are present at the base commit. It is registered rather than removed because a reactor-wide exclusion changes the classpath of 141 modules that never load ASM at run time, and unaudited classpath change is exactly what a behaviour-preserving migration cannot afford. One narrow exception was necessary and is declared in the **Dependency Change Inventory**: the module whose BPMN listeners compile scripts does now exclude the old jar, because there the collision is not latent — it stopped the reinstated script engine from initialising at all. That one module is the proof of what the other 141 are exposed to if anything ever does generate bytecode there.

### 49 — The final pipeline task writes into a directory that no checkout contains

`config/env/all.js:10` sets `modulesConfigFile` to `modules_config/config/modules.json`. The tracked tree contains three files under `modules_config/` — `permissions/modules.json`, `schemas/empty.json` and `schemas/grid.json` — and **no `config/` directory at all**. Reads of that path are guarded by an existence check (`Gruntfile.js:290`); the write at `Gruntfile.js:349` is not. So `copyToModulesConfigFolder`, the last task in the `default` graph, raises `ENOENT: no such file or directory, open 'modules_config/config/modules.json'` on any checkout, and `grunt.option('force', true)` at `Gruntfile.js:144` turns that into a warning and lets the process exit zero. It is the same masking mechanism as entries 3 and 4, claiming a third casualty — and unlike those two, this one sits inside the task graph the build actually runs.

Measured on this host after the migration, on Node 20.20.2 with npm 10.8.2: a lockfile install followed by the build script exits **0**, prints exactly that warning, and produces **all five** output artefacts — `assets/dist/application.js`, `application.min.js`, `vendors.min.js`, `application.min.css` and the rewritten `home.html`. The artefacts are unaffected because every one of them is written by an earlier task; the broken task is last in the graph and contributes nothing to them. This is precisely why the frontend gate asserts on produced artefacts rather than on the exit code: here the exit code is zero *and* a task failed, and only the artefact list distinguishes a good build from a bad one.

Pre-existing and unchanged by this migration — no file under `resources/` other than the dependency manifests is touched by this change set, and neither `Gruntfile.js` nor `config/env/all.js` is touched at all. It is registered rather than fixed because both available repairs change what the pipeline does with module configuration rather than what it produces: creating the directory, or making the write recursive, would let the task register newly discovered modules into a file the deployed application reads, which is a behaviour the baseline does not have. R-6's escape clause does not reach it either, because the gate is not blocked — the build exits zero and every artefact is produced.


## The Escape Clause, Invoked Exactly Twice

R-6 permits fixing a pre-existing defect when it blocks a validation item. Two conditions blocked the fresh-checkout frontend build gate, which runs a clean checkout, deletes every untracked file, installs from the lockfile and runs the build. Both were fixed. Both are labelled here so the count is auditable and cannot grow quietly.

| # | Condition fixed | Why it blocked the gate | Why the fix is behaviourally inert |
|---|---|---|---|
| E1 | `profiles.js` was absent from version control | `config/config.js:16` requires `./../profiles`, and the gate's clean step deletes every untracked file before installing. The module was written at deploy time, so a fresh checkout could not build at all | The deploy-time writer uses replace-existing semantics, so a deployed environment continues to overwrite the tracked default with its own value. The tracked file exports `{ profiles: [ ] }`, matching what that writer emits |
| E2 | The Sass toolchain could not build on Node 20 | Its transitive native compiler fails to install — the only failure among eighteen legacy packages tested — so the install step could not complete | Removal, not replacement, and output-neutral by entry 5 above: no Sass task is declared and the SCSS globs are never consumed. Modern replacements were verified to install and were **declined on evidence, not availability** |

**Neither invocation is a register entry, and no third invocation exists.** The arithmetic is exact: **49 register entries, 0 fixed, 2 escape-clause invocations, and no overlap between the two sets.** E1 created a file that was absent from version control, and E2 removed a build package — neither is a row above. Every one of the 49 entries is still present in the tree, unmodified, and can be re-verified at the anchor it cites.

Two things make that narrow reading visible rather than merely asserted. Entries 1 and 2 sit in `config/config.js` — the very file that E1 makes loadable — and were still left alone, even though they are a few characters each and the file was already open. And entries 22 to 32 are eleven security defects, the category with the strongest pull toward "fix it while you are here"; not one was touched, because none of them blocks a validation item and the migration plan's preservation list requires security outcomes to be **unchanged**, which makes adding an authorization check a deviation from the plan rather than compliance with it.

Entry 45 is the sharpest illustration of the cost of reading the clause that narrowly: a two-character change would make its error path execute, and it is left alone because the assertion behind it would then have to be rewritten, which the preservation list forbids.

## What Is Not on This Page

Two categories are deliberately excluded, because including them would blur what this register means.

**Migration-induced failures would not be pre-existing defects, and there are none.** A regression is not an inherited condition, and putting one here would launder it into accepted state — so the exclusion stands as a rule even though the current count is zero. The rule was written when an earlier revision of this change set did carry migration-induced failures; it no longer does. The migrated run archived under [Baseline Test Failures](baseline-test-failures.md) records **3 failures and 1 error across 285 suites and 951 test methods, and every one of the four maps to a registered baseline row** — the same three `FileDownloadAPIControllerTest` failures and the same `FolderCompressorTest` error that the JDK 8 baseline produced. The entire delta between the two archives is seven added suites and 59 added test methods, all passing. Any future failure that does not trace to a baseline row belongs in that register as a regression, never on this page.

**Frontend dependency advisories have their own register.** They are a security posture with a remediation plan and risk-accepted exceptions, not a list of code defects, and they are recorded in [Frontend Dependency Security](frontend-dependency-security.md).

## How to Use This Register

- **Fixing an entry.** Do it in a change set whose purpose is that fix, so the resulting behaviour difference has one explanation. Entries 1 and 2 in particular need a configuration with active profiles to test against, which this change set does not have.
- **Adding an entry.** Verify the anchor against the tree, state what makes it a defect, and state why it is out of scope. An entry without the last part is a to-do list item wearing a register's clothes.
- **Invoking the escape clause.** Name the validation item blocked, and add a row to the table above. If a third row ever appears, the reason it is not simply "we also fixed this one" must be on it.
- **Interpreting a build failure.** Check entry 6 first. An unprovisioned local artifact repository looks exactly like a dependency resolution regression and is neither.

Related registers: [Dependency Change Inventory](dependency-change-inventory.md), [Baseline Test Failures](baseline-test-failures.md), [Ambiguity Resolutions](ambiguity-resolutions.md), [Static Audit Output](static-audit-output.md), [JDK Access Exceptions](add-opens-exceptions.md) and [Frontend Dependency Security](frontend-dependency-security.md).
