# Known Issues

This page is the register of defects that were **already present at the Java 8 base commit** `c8f6226105` and were deliberately **not** fixed by the Java 17 and Node 20 migration, together with the single condition that *was* fixed because it blocked a named validation item. Everything here was reproduced against the real checkout; nothing is inferred.

## Why nothing here is fixed

**R-6** requires that a pre-existing bug discovered during this work be documented rather than repaired, with one carve-out: a bug that blocks a validation item may be fixed. Exactly one item on this page sits on the fixed side of that line, in [The one condition fixed under the carve-out](#the-one-condition-fixed-under-the-carve-out). Everything else is left exactly as the base commit wrote it.

The reasoning is worth making legible, because the rule is not bureaucracy. A compatibility migration earns its review by being attributable: if the same change set moves a compiler contract, a dependency surface *and* an unrelated defect, then any behavioural difference observed afterwards has two candidate causes and the reviewer can no longer tell which one produced it. Keeping the repairs out is what makes the runtime move reviewable at all. The corollary is the discipline this page holds itself to — describing a defect here does not license fixing it.

A note on where the rules come from, because it is unusual and a reader should not go looking in the wrong place. **`review_rules` reports that no user rules were provided**, and there is no on-disk rules document for this project. The seven binding constraints this migration works under arrive instead through the **RULES block of the user prompt**, whose full verbatim text is available via **`review_prompt`**. They are cited across this documentation set as **R-1** through **R-7**. This page cites them by identifier and summarises what each requires of it; it does not reproduce their text, because the prompt is the source of truth for that.

| Rule | What it requires of this page |
| --- | --- |
| **R-6** — pre-existing bugs are documented, not fixed | Primary. This page *is* the register R-6 asks for, and R-6 is the only reason it exists — the migration's deliverable list does not name it. Every entry must state whether it blocks a validation item, and the one that does must say which |
| **R-5** — failing tests must not be disabled | The four baseline test failures are pre-existing defects and belong here, but their exclusion accounting belongs to [the baseline record](baseline-test-failures.md). This page summarises and links; it publishes no suite totals |
| **R-4** — the frontend must genuinely run on Node 20, with no vendored dead packages | The retained vendored `lib/` tree must be *justified*, not merely noted, because a careless reading of R-4 would treat it as exactly the thing R-4 forbids |
| **R-2** — no module-access flags or JDK-internal reliance in production launch configuration | Nothing in production launch configuration is changed here. The ActiveMQ finding below is a documentation item by direction, not a missing flag; the launch-configuration certification lives in [the module-access record](add-opens-exceptions.md) |

### How to read an entry

Every entry names **what** the defect is, **where** it is, and **why it does not block a validation item** — that last clause is the justification for leaving it alone, and an entry without it would not satisfy R-6. The validation items referred to are the five the migration is measured against:

| # | Validation item |
| --- | --- |
| 1 | `mvn clean install -DskipTests` then `mvn test` exit 0 on JDK 17 |
| 2 | `npm ci` then `npm run build` exit 0 on Node 20 from a fresh checkout |
| 3 | The JDK-internal-API static audit returns zero hits in main source |
| 4 | The assembled artifact deploys and reaches a ready state |
| 5 | Smoke flows match the Java 8 baseline |

Line numbers are given for the **migrated tree** as published. Where the migration legitimately moved a line, the base-commit number is given alongside it in parentheses, so the citation is checkable against either tree.

## Backend defects — documented, not fixed

| Defect | Location | Blocks a validation item? |
| --- | --- | --- |
| Compressor closes a stream and then finishes it again | `DefaultFolderCompressor.java:215-219` with `MaxThroughputAwareFileOutputStream.java:123` | **No** — it is one of the two baseline exclusions, so item 1 is unaffected |
| Three unmet EasyMock expectations in one controller test | `FileDownloadAPIControllerTest` in `acm-services/acm-service-ecm` | **No** — same exclusion; item 1 is unaffected |
| The same servlet API declared twice in one module POM | `acm-services/acm-service-authentication-token/pom.xml:89-93` and `:109-112` | **No** — it is a Maven warning, the build succeeds, and nothing reaches the artifact |
| The build injects licence headers into tracked sources | `pom.xml:468-496` — `license-maven-plugin` on `process-sources` | **No** — it mutates the working tree, not the build outcome |
| ActiveMQ's TLS transport does not work on Java 17 | No location — no broker URL exists in this repository | **No** — and the project setup instructions direct that it be documented, not fixed |

### The compressor closes a stream and then finishes it again

`FolderCompressorTest.testCompressFolderMaxSize` in `acm-services/acm-service-compress-folder` ends in a `NullPointerException` carrying the message `Deflater has been closed`. The defect is in production code, not in the test, and the register names that location because [the baseline record](baseline-test-failures.md) owns the stack trace rather than the source:

- `DefaultFolderCompressor.compressFolder` opens a `ZipOutputStream` over a `MaxThroughputAwareFileOutputStream` in a try-with-resources at `:215-219`.
- `MaxThroughputAwareFileOutputStream.write` throws an `IOException` at `:123` as soon as the configured size limit is exceeded — which is precisely what this test provokes.
- The per-entry `catch (IOException)` inside the private `compressFolder(zos, …)` overload at `:386-391` **swallows** that failure: it logs a warning and lets the loop continue. `copy` is `org.apache.commons.io.IOUtils.copy`, statically imported at `:32`, and closes nothing itself.
- The try-with-resources then closes the `ZipOutputStream` on the way out, and `close()` runs `finish()` over a deflater the failing path has already ended. The JDK raises the `NullPointerException` from there.

**Why it does not block a validation item.** It is one of the four measured baseline failures, and its owning class is one of the two class-level entries in the surefire `<excludes>` block at `pom.xml:366-367`, so validation item 1 exits 0 with it in place. The failure is **identical on JDK 8 and JDK 17**, differing only in library-internal line numbers, which is what qualifies it as pre-existing rather than migration-attributable. The exclusion accounting, the two narrower alternatives that were rejected on evidence, and the collateral cost of a class-level exclusion are all in [the baseline record](baseline-test-failures.md) and are deliberately not repeated here.

### Three unmet EasyMock expectations in one controller test

`FileDownloadAPIControllerTest` in `acm-services/acm-service-ecm` holds four tests, of which three fail: `downloadFileById_successful`, `downloadFileByIdAndVersion_successful` and `override_mime_type`. All three are the **same mock-verification assertion**, raised from the test's own verify-all call rather than from three independent causes, and the unmet expectations are a content-stream filename read and a published application event that the controller never performs.

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

### ActiveMQ's TLS transport does not work on Java 17

The broker must be addressed over `tcp://` rather than `ssl://`, because ActiveMQ's TLS transport at the pinned version does not work on Java 17. The project setup instructions are explicit about the disposition: **document it, do not fix it, and do not fail setup for it.** That last clause is stated plainly here because it is the one most likely to be second-guessed by someone who finds the finding without the direction attached to it.

There is also nothing in this repository to change. Searching every tracked file for a broker URL — `git grep -nE '(ssl|tcp)://'` outside the documentation tree — returns **zero hits**. Endpoints reach ArkCase from the external configuration bundle, so the remedy is a configuration choice made outside this checkout and the finding cannot be a repository edit even in principle.

**Why it does not block a validation item.** Messaging over `tcp://` works, so nothing in items 1 through 5 depends on the TLS transport. Two further clarifications matter under R-2: this is **not** a module-access problem, so no `--add-opens` would help and none is offered; and production launch configuration is certified free of module-access flags in [the module-access record](add-opens-exceptions.md), a certification this finding does not disturb.

## Frontend defects — documented, not fixed

All four were verified against the source tree. `Gruntfile.js` has a **zero-byte diff** against the base commit, so its line numbers are identical in both trees; `config/config.js` grew from 140 to 167 lines when the carve-out fix landed, so its numbers are given for the migrated tree with the base-commit line in parentheses.

| Defect | Location | Why it does not block a validation item |
| --- | --- | --- |
| A dead concurrent-task target — `sync-dev` is registered as `['concurrent:default']` while the `concurrent` configuration declares its only target as `default1` | `Gruntfile.js:91` and `:379` | It affects only the `sync-dev` developer-convenience task. No validation item invokes it; the `default` chain at `:376` never touches `concurrent` |
| An eagerly-evaluated path join against a value that can be null — `destPath` is initialised to `null` at `:13` and assigned at `:15` inside a `try` whose `catch` only logs and continues, yet six `path.join(destPath, …)` calls sit in the object literal handed to `grunt.initConfig` and evaluate on every invocation | `Gruntfile.js:104-124`, with `:13-18` | The defect is **latent**: `homedir()` resolves on every supported platform, so the join never receives `null`. Measured on the validated runtime — `homedir()` returns a path and `npm run build` exits 0. Only a host where `homedir()` throws would reach it, and there the `catch`'s stated intent to continue is what the eager joins defeat |
| A loop that iterates the wrapper object rather than its array — `activeProfiles` is `{ profiles: [ … ] }`, and lodash iterates an object's **values**, so `profile` binds to the array and `profile + dir` stringifies it. It works only by accident with a single profile, where `['custom']` stringifies to exactly `custom` | `config/config.js:110` and `:160` (base `:83`, `:133`) | The single-profile case is the one the pipeline exercises, so the default build resolves the same asset paths it always did. A second profile would produce a comma-joined prefix, but no validation item configures one |
| Four discarded non-mutating array concatenations — the results of `jsCustomModules.concat(…)`, `jsCustomDirectives.concat(…)`, `jsCustomServices.concat(…)` and `cssResources.concat(…)` are computed and thrown away | `config/config.js:120`, `:131`, `:142`, `:164` (base `:93`, `:104`, `:115`, `:137`) | The discarded results are additive-only, so the emitted asset set is exactly what it was. Repairing them would *add* files to the bundles, which is a behavioural change the preservation mandate forbids |

The last row is the clearest illustration of why R-6 is the right rule rather than an obstacle: the obvious one-character fix — assigning the `concat` result back — would silently enlarge the shipped bundles. Leaving the defect in place is what keeps the pipeline outputs equivalent.

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

They are **first-party in-repo source**, not vendored third-party packages:

- **`lib/acm-json8-patch/` is an ArkCase fork with no upstream equivalent.** There is no registry package to replace it with, so "replace the vendored copy with a dependency" has no target.
- **Two of the six are load-bearing at build time through relative-path requires.** `Gruntfile.js:227` requires `./lib/acm-json8-patch/apply` and `:228` requires `./lib/json8/lib/clone` — by **path**, not by package name, so `node_modules` is never consulted for them. Adding registry copies would create two divergent implementations of the same code with only the Gruntfile deciding which one runs, which is strictly worse than the status quo.
- **The tree is deployed, not dormant.** `lib` appears on three separate copy lists in `acm-user-interface/ark-angular-starter/src/main/resources/spring/spring-web-ark-angular-starter.xml`, at `:65`, `:76` and `:88`, and it is explicitly whitelisted from the temp-folder prune in `AngularResourceCopier.java:219`.

**Why it does not block a validation item.** Nothing about the tree obstructs items 1 through 5: `npm ci` and `npm run build` both exit 0 with it in place, and it is the *removal* that would break the two relative requires. This is retention with a reason, which is what R-4 asks for — the rule's target is dead weight, and dead weight is precisely what this is not. The eight genuinely dead build packages that R-4 *did* reach were removed, and that accounting belongs to [the dependency inventory](dependency-change-inventory.md).

## The one condition fixed under the carve-out

This is the single place where the migration departs from "document, do not fix", so it is stated unambiguously.

**The defect.** At the base commit, `config/config.js:16` reads `var activeProfiles = require('./../profiles');` — an **unconditional** top-level require of a generated module. `profiles.js` is not tracked and is not present in a checkout; it exists only in the deploy-time assembly folder, where `AngularResourceCopier.createProfilesJsFileInDir` writes it immediately before invoking Grunt (base `:206-215`, migrated `:267-276`). That require site is the **only** one for the module anywhere in the frontend tree.

**Why it is a permitted fix rather than a violation.** `config/config.js` is loaded by the `loadConfig` task, which is the *first* entry in the `default` chain at `Gruntfile.js:376`. An unresolvable require there aborts the whole run before any task executes, so a bare checkout **cannot run `npm run build` at all**. That directly blocks **validation item 2** — `npm ci` then `npm run build` must exit 0 on Node 20 from a fresh checkout — and a defect that blocks a named validation item is precisely the exception R-6 contemplates. Nothing else on this page is in that position.

**The fix, in two parts.**

- A new prebuild helper, `scripts/ensure-profiles.js`, writes `<frontend root>/profiles.js` when and only when it is absent, emitting the **identical manifest** the Java assembler produces and mirroring its single-profile fallback. It is wired as the `prebuild` script, so `npm run build` runs it automatically.
- A **guarded require** at `config/config.js:35-43` defaults to `{ profiles: [ 'custom' ] }`, the exact value the assembler emits for its own single-profile case. The guard is narrow on purpose: only `MODULE_NOT_FOUND` for this file's own require is defaulted, and every other failure is re-thrown, so a generated module that exists but does not parse still surfaces its real error instead of being silently replaced by a single default profile.

A deployed WAR and a bare checkout therefore follow the same code path, and the generated module wins whenever it is present, so deployed behaviour is unchanged. Measured on Node v20.20.2 with npm 10.8.2 from a clean tree: `npm ci --ignore-scripts` exits 0, then `npm run build` reports `ensure-profiles: created …/resources/profiles.js with profiles [ custom ]` and exits 0.

**Scope discipline.** This is the *only* fix. The module-config copy warning described immediately above is adjacent to it, equally cosmetic and equally easy to silence, and was deliberately left alone — that contrast is the evidence that the line was drawn deliberately rather than stretched to cover whatever was convenient.

**One consequence of the fix, disclosed rather than buried.** The frontend root's `.gitignore` lists only `node_modules/` and is unchanged from the base commit, so the generated `profiles.js` lands in the working tree as an **untracked, non-ignored** file. It joins two pre-existing generated paths in the same condition — `assets/dist/` and `home.html`, both written by the base-commit pipeline and neither ignored — so a post-build `git status` shows three untracked generated paths. This blocks no validation item, and it is **not** repaired here: an ignore-rule change is outside this change set, and R-6's carve-out does not extend to it. It does, however, sharpen the warning above — the licence-plugin header injections are not the only thing a blanket `git add -A` would sweep up.

## Not defects — recorded so they are not mistaken for regressions

None of the following is a bug. Each is recorded because it looks like one at first glance, or because a reader may otherwise mistake it for something the migration broke.

| Observation | Measured detail | Why it is not a regression |
| --- | --- | --- |
| **WAR size** | 277,014,616 bytes — roughly 264 MB — at the unchanged path `acm-standard-applications/arkcase/target/arkcase-2021.03.war` | The name, the coordinates and the location are all unchanged. The artifact is about 4 MB larger than the Java 8 baseline WAR at 273,020,897 bytes, and the growth is fully attributable to the reinstated `javax`-namespaced EE artifacts plus the Spring patch bumps — see [the dependency inventory](dependency-change-inventory.md). The exact byte count varies between builds because archive timestamps and the licence plugin's year stamp are embedded, so the durable claim is the magnitude, not the digits |
| **A network-dependent build input** | `config/env/all.js:38` — the `customJs` asset list pulls an Atlassian issue-collector script over HTTPS from an external host | Pre-existing and **deliberately unchanged**. Altering or vendoring it would change the pipeline's inputs, which the preservation mandate forbids. Flagged so that a build failing on network egress is diagnosed correctly rather than blamed on the toolchain move |
| **MariaDB must run as `utf8mb3`** | 11 column-level `MODIFY COLUMN … CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci` statements across 6 Liquibase changelogs, including `acm_case_file.cm_case_details` at `acm-case-file-tables-1.0.xml:586` — the exact column whose row-size limit fails on a `utf8mb4` server | The changelogs are legitimate and the schema is on the preservation list, so this is **server configuration, never a changelog edit**. No changelog is touched by this migration. Every one of the 11 is column-level; none sets a table or schema default |
| **Activiti writes into the working directory** | Tomcat should be started from a scratch directory rather than the repository root | An operational instruction, not a repository change. Activiti stays at its pinned version, so the behaviour is identical to the base commit |
| **`acm-jmeter` is never built** | The root POM's `<modules>` names exactly eight top-level aggregators — `acm-web`, `acm-plugins`, `acm-standard-applications`, `acm-services`, `acm-tool-integrations`, `acm-forms`, `acm-user-interface`, `acm-core-api` — and `acm-jmeter` is not among them. The directory holds JMeter assets and **no `pom.xml` at all**, and no POM in the repository references it. Those eight are the direct entries, not the size of the reactor, which is the transitive closure beneath them and is counted in [the dependency inventory](dependency-change-inventory.md) | Not a defect, and not something the migration removed. It surprises readers of [the module overview](../overview.md), which catalogues `acm-jmeter` alongside the reactor modules; the overview is a directory map, not a reactor listing |
| **The JaCoCo coverage floor stays at 2%** | `code.coverage.minimum` is `0.02` at `pom.xml:154`, enforced as a `BUNDLE` / `LINE` / `COVEREDRATIO` limit by the `check` goal at `:536-555` | Unchanged from the base commit and **not raised opportunistically**. Recorded so the low value is not read as something the migration lowered. Raising it is a coverage initiative with its own review, not a side effect of a runtime move |

## Honest corrections on the record

Three figures that circulated while this migration was planned did not survive measurement. They are named rather than quietly replaced, because a reader who has seen them needs to know which value is authoritative.

| Earlier figure | Measured value | How it was measured |
| --- | --- | --- |
| The licence plugin affects "seven" main sources | **Six** | Counting main `.java` files without the header marker, at the base commit and in the migrated tree — the same six both times — and confirmed by running `process-sources` on the module that holds four of them |
| "Column-level `utf8mb4` ALTERs in six places" | **11 statements across 6 files** | `git grep -n utf8mb4` over the changelogs. The earlier count conflated statements with files. The substantive point is unaffected: every occurrence is column-level, so none of them is the server-level setting the requirement is about |
| `config/config.js` defects at `:16`, `:83`, `:93`, `:104`, `:115`, `:133`, `:137` | `:36`, `:110`, `:120`, `:131`, `:142`, `:160`, `:164` | Those were base-commit numbers. The carve-out fix added 27 lines above them, taking the file from 140 to 167. Both sets are given side by side above, since a wrong line number in a register is worse than no register |

## What this record does not cover

**Suite totals and the exclusion accounting.** This page names the four baseline failures and the two classes that carry them, and it publishes no test counts at all — those are measured and owned by [the baseline record](baseline-test-failures.md), which is the single source of truth for them. It also owns the collateral cost of a class-level exclusion and the pre-existing skipped tests, neither of which is a defect this page registers.

**Module-access directives.** None of the defects here needs one, and none reaches production. The eight the migration did need are confined to the forked test JVMs and are attributed individually in [the module-access record](add-opens-exceptions.md).

**Version changes.** Every dependency and plugin move, its reproduced reason, and the candidates that were considered and withdrawn belong to [the dependency inventory](dependency-change-inventory.md). This page cites versions only where a defect's disposition depends on one.

**JDK-internal API references in source.** Those are a separate audit with a separate remedy, in [the static audit](static-audit.md). Every one of them was cleared, so none is a known issue.

**Anything resolved rather than recorded.** Ambiguities settled against observed Java 8 base-commit behaviour are decisions, not defects, and belong to [the behavioural decisions record](behavioral-decisions.md).

## Related records

| Record | What it owns |
| --- | --- |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative suite totals, the two class-level exclusions and their collateral cost |
| [Module-access exceptions](add-opens-exceptions.md) | The eight test-scope directives with their per-library attribution, and the certification that production launch configuration has none |
| [Dependency change inventory](dependency-change-inventory.md) | Every dependency and plugin change with its reproduced reason, including the removals R-4 required |
| [Static audit](static-audit.md) | The JDK-internal-API audit command, its classified hits before and the zero-hit result after |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour |
