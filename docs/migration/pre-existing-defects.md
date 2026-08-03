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

Twelve entries. **Zero fixed.**

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

Both copies are **provably unreachable**. In `acm-foia` the only Spring declaration of the predicate bean sits inside a comment region, its only consumer is commented, and the enclosing property assignment is commented as a whole; the active declaration names a different, non-JavaScript predicate class. In `acm-privacy` there is no XML reference at all — the apparent cross-module references are `<bean>` examples inside Javadoc. No POM, XML, properties file or shell script anywhere mentions the engine.

Adding a standalone script engine to make this code work would introduce a library to the production dependency graph solely to support code that cannot execute — a change with no compatibility justification, which R-1 forbids — and would convert dead code into live code, which is a behaviour *change* relative to the baseline. Documenting it is the R-7-consistent outcome. See [Ambiguity Resolutions](ambiguity-resolutions.md).

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

## The Escape Clause, Invoked Exactly Twice

R-6 permits fixing a pre-existing defect when it blocks a validation item. Two conditions blocked the fresh-checkout frontend build gate, which runs a clean checkout, deletes every untracked file, installs from the lockfile and runs the build. Both were fixed. Both are labelled here so the count is auditable and cannot grow quietly.

| # | Condition fixed | Why it blocked the gate | Why the fix is behaviourally inert |
|---|---|---|---|
| E1 | `profiles.js` was absent from version control | `config/config.js:16` requires `./../profiles`, and the gate's clean step deletes every untracked file before installing. The module was written at deploy time, so a fresh checkout could not build at all | The deploy-time writer uses replace-existing semantics, so a deployed environment continues to overwrite the tracked default with its own value. The tracked file exports `{ profiles: [ ] }`, matching what that writer emits |
| E2 | The Sass toolchain could not build on Node 20 | Its transitive native compiler fails to install — the only failure among eighteen legacy packages tested — so the install step could not complete | Removal, not replacement, and output-neutral by entry 5 above: no Sass task is declared and the SCSS globs are never consumed. Modern replacements were verified to install and were **declined on evidence, not availability** |

**Neither invocation is in this folder, and no third invocation exists.** Ten of the twelve defects above are untouched; entries 1 and 2 sit in the very file that E1 makes loadable and were still left alone, which is the sharpest available illustration that the escape clause was read narrowly rather than as permission to tidy.

## What Is Not on This Page

Two categories are deliberately excluded, because including them would blur what this register means.

**Migration-induced failures are not pre-existing defects.** The migrated unit suite carries 124 failures that do not exist at the JDK 8 baseline, from three root causes. They are regressions, not inherited conditions, and putting them here would launder them into accepted state. They are enumerated, diagnosed and attributed in [Baseline Test Failures](baseline-test-failures.md) under *The Migrated Run*, where the fact that they are unresolved is unavoidable rather than filed away.

**Frontend dependency advisories have their own register.** They are a security posture with a remediation plan and risk-accepted exceptions, not a list of code defects, and they are recorded in [Frontend Dependency Security](frontend-dependency-security.md).

## How to Use This Register

- **Fixing an entry.** Do it in a change set whose purpose is that fix, so the resulting behaviour difference has one explanation. Entries 1 and 2 in particular need a configuration with active profiles to test against, which this change set does not have.
- **Adding an entry.** Verify the anchor against the tree, state what makes it a defect, and state why it is out of scope. An entry without the last part is a to-do list item wearing a register's clothes.
- **Invoking the escape clause.** Name the validation item blocked, and add a row to the table above. If a third row ever appears, the reason it is not simply "we also fixed this one" must be on it.
- **Interpreting a build failure.** Check entry 6 first. An unprovisioned local artifact repository looks exactly like a dependency resolution regression and is neither.

Related registers: [Dependency Change Inventory](dependency-change-inventory.md), [Baseline Test Failures](baseline-test-failures.md), [Ambiguity Resolutions](ambiguity-resolutions.md), [Static Audit Output](static-audit-output.md), [JDK Access Exceptions](add-opens-exceptions.md) and [Frontend Dependency Security](frontend-dependency-security.md).
