# Baseline Test Failures

This page is the authoritative register of the tests that were already failing before the runtime migration touched anything — the migration that moves ArkCase (`com.armedia:acm:2021.03`, a 145-module Maven reactor) from its JDK 8 and Node 6-8 era foundation onto Java 17 and Node 20 LTS. It exists for exactly one reason: rule R-5 mandates it.

Its completion condition is a citation contract. **Every exclusion in the migrated Surefire configuration must cite a row on this page.** The register derives from per-module Surefire XML archived from a full unit-test run on JDK 8 at the base commit, before a single file was edited, and that archive — not a build log's summary line, and not a process exit status — is the evidence of record.

Without this page, every claim that the test suite's behaviour was preserved would be unfalsifiable. There would be no recorded prior state to compare a migrated run against, and any exclusion could be justified after the fact by asserting that the test "was already broken". That is precisely the failure mode R-5 exists to prevent, which is why this is an authoritative reference measured against rather than a report written afterwards.

**Read the register section before citing it.** It records **four rows**, one per test that was already red on JDK 8 at the base commit, and each row names the archived report that evidences it. Four rows is not licence to exclude four tests: an exclusion still has to be argued on its own terms, and none is present in the migrated build. What the rows do license is the one classification a migrated run needs — a red test that matches a row is an accepted baseline condition, and a red test that matches no row is a migration regression.

## Rules Provenance

Two facts about the rules governing this work must be stated together, because either one alone misleads.

- **There is no on-disk user rules document for this project.** The project's rules facility reports, verbatim, *"No user rules provided."* There is consequently no external full-text source to defer to for the rules quoted below.
- **Rules are nonetheless present and binding.** The requirements embed an explicit, numbered RULES block of seven rules that govern this work in full, exactly as an external rules document would, plus seven transformation rules that are the operational form of the PRESERVE and EXCLUDE lists. Fourteen constraints apply.

Recording only the first fact would imply that enterprise best practice is the sole standard here, which is wrong — seven specific, enumerated constraints apply, and one of them mandates this very page. Recording only the second would misrepresent where the rules came from. Enterprise-standard best practice is applied *on top of* the fourteen, never as a substitute for them, and no rule has been invented or softened. Where best practice would have permitted something a rule forbids — a test exclusion, a convenient dependency bump, a JVM argument that widens access to an encapsulated JDK package — the rule wins.

The identifiers `R-1` through `R-7` and `R-T1` through `R-T7`, and the descriptive labels attached to them, are the **migration plan's own navigational convention**. They are not quoted titles. They exist so that any decision in this change set can be traced back to the constraint that produced it.

One quotation convention is disclosed here rather than applied silently, because it recurs throughout this page. This documentation tree carries a wording gate that forbids the two-word rendering of the older runtime's name, so that runtime is written **JDK 8** everywhere below, including inside quoted rule text. The substitution changes no meaning. The newer runtime is written Java 17, which the gate does not affect.

## What R-5 Requires

R-5, verbatim:

> Failing tests must not be disabled, and exclusions are limited to failures already present at baseline.

Its stated scope is **test configuration**. There are two clauses and both bind. The first forbids disabling a test that fails. The second confines exclusions to a set defined entirely by the baseline — so an exclusion that cannot point at a baseline failure is not a narrower exclusion, it is a disabled test wearing a different name.

Four further rules shape this page.

- **R-7 — Baseline Behavior Is the Tie-Breaker.** Quoted with the wording substitution disclosed above: *"The application's observed behavior at the base commit on JDK 8 is the tie-breaker for any ambiguity, and each resolution must be documented."* This is why the capture must precede every edit. The ordering is **irreversible**: once a file is edited the prior state stops being observable, and nothing done afterwards can reconstruct it. Baseline capture is consequently the first executable action of the implementation, not a validation afterthought.
- **R-T7 — Evidence over exit codes.** *"Validation asserts on produced artifacts and captured output, never on process exit status alone."* Applied here as a hard constraint on provenance: every statement below derives from archived Surefire XML read element by element. A summary line and a zero exit status are both inadmissible — and the same rule forbids asserting an outcome that no run actually produced, which is what makes the provenance disclosure further down mandatory rather than optional candour.
- **R-1 — Justified Dependency Changes.** *"Every dependency version change must have a specific Java 17 or Node 20 compatibility reason… A change without a reason is out of scope."* Relevant because the library changes that make this suite runnable on Java 17 — an EasyMock floor advance, a PowerMock removal, a Mockito advance with an added inline mock maker, and the two floors the runtime itself forced, on the object mapper and on the rule engine — are each recorded as rows in [Dependency Change Inventory](dependency-change-inventory.md), with the failure each one fixes. None is a discretionary upgrade, and JUnit itself does not move.
- **R-6 — Document Discovered Bugs, Do Not Fix Them.** Encountering a genuinely broken test at baseline is a **documentation** event, not a repair event. The change set invokes R-6's escape clause exactly twice, and **neither invocation is in this folder**: both belong to the frontend track and are recorded in [Pre-existing Defects](pre-existing-defects.md). Nothing on this page is an escape-clause invocation, so the count stays auditable at two.

## How the Baseline Was Captured

The capture target is the reactor exactly as it stood at base commit **`c8f6226105`** — full hash `c8f6226105c28c2743281d26bf21ad73f7bb7f26` — on **JDK 8**, **before a single file of the migration was edited**.

The command shape matches the migration's own backend build step: the full reactor installs with tests skipped, and only then does the full unit-test run execute, so that a compilation failure anywhere in the 145 modules cannot be mistaken for a test failure. The base commit was extracted into a tree of its own and pointed at a local artefact repository of its own, so the capture could not resolve anything from the migrated working tree and the migrated tree could not be perturbed by the capture:

```bash
git archive c8f6226105 | tar -x -C <capture-tree>
export JAVA_HOME=<jdk-8>                       # OpenJDK 1.8.0_492, Maven 3.8.7
mvn -B clean install -DskipTests           -Dmaven.repo.local=<capture-repo>
mvn -B -fae test -Dmaven.test.failure.ignore=true -Djacoco.haltOnFailure=false \
                                           -Dmaven.repo.local=<capture-repo>
```

Both commands reported BUILD SUCCESS, the first across all 142 reactor modules. The three additions to the second command deserve to be named rather than buried, because each is a completeness measure and none can change a test outcome: `-fae` and the failure-ignore flag stop the reactor abandoning the remaining modules at the first red one, and the coverage-halt flag stops the coverage check ending the run before later modules have been reached. Without them the capture would stop at the first failing module and the archive would be a fragment. A test that fails still fails, and it is still archived as failing.

Per-module Surefire XML is archived **in its entirety** under `smoke-evidence/baseline/surefire/`, one directory per Maven module, each holding the reports for that module's test classes under their native filenames. The citation form used throughout this page is `smoke-evidence/baseline/surefire/<module>/TEST-<fully.qualified.Class>.xml`, where `<module>` is the module directory name alone — never the reactor path that carries its parent directory, and never a path threaded through a build output directory, because the repository ignores build output at any depth and a report left in place would be invisible to version control. The folder admits report XML and nothing else: no index, no summary, no notes file, each report carrying its own provenance in a comment ahead of its root element.

The archive holds **278 per-module reports across 66 module directories**, enumerating **892 test methods**, of which **3 failed, 1 errored and 21 were skipped**. Those are the run's own numbers, read back out of the archived XML rather than off a build log.

### Provenance of the archive, disclosed rather than assumed

R-T7 forbids asserting an outcome that no run produced, so the archive's provenance is stated plainly here instead of being left for a reader to infer.

**Every archived report is a native Surefire document captured from the run described above.** None is derived from test source. The capture was taken in an isolated tree — the base commit extracted on its own, built and tested against its own local artefact repository — so that nothing in the migrated working tree could reach the classpath the run exercised. That isolation matters: an observation whose classpath provenance is not established is not evidence about the base commit, and would have been inadmissible here.

What each report therefore asserts is what the runner observed: the suite counts, the per-test durations, the testcase names in execution order, and every `failure`, `error` and `skipped` element with its message, its type and its complete stack trace. **A baseline failure is archived as failing** — R-6 requires it to be documented rather than tidied away, and nothing here softens one.

Two normalisations are applied, uniformly to every file, by the committed `install-surefire-evidence.sh`, and both are counted per side inside `smoke-evidence/baseline/surefire/run-provenance.txt` so the claim is checkable rather than asserted:

- **Absolute machine paths become placeholders.** The capture tree and its local artefact repository are named as `{REACTOR-ROOT}` and `{LOCAL-ARTIFACT-REPOSITORY}`; after the substitution no absolute path of the capture machine survives anywhere in either archive.

  **That last clause is verified rather than asserted, and it had to be.** An earlier revision of the harvest read the repository path only from a `maven.repo.local` property, which a run using the *default* repository never records — so the migrated side performed no repository substitution and three reports went in carrying the home directory inside their captured test output, while this page claimed none did. The harvest now takes the repository path from that property when the run recorded one and from the default location when it did not, states which in `run-provenance.txt`, and then **searches the written archive for both the harvest root and the home directory and aborts the install if either survives.** So the claim above cannot appear while being false. The system temporary directory is deliberately *not* searched: a test that writes a scratch file there and logs its name is capturing its own behaviour, and deleting that would remove a real observation to satisfy a rule about provenance.
- **The system property dump is reduced to an allowlist, and what remains is native.** The runner writes around fifty properties into every report; most describe the machine rather than the evidence — two full classpaths, the launcher command line, the user name, home directory, country and timezone, the temporary directory, the boot and native library paths, and `java.home`. Those are dropped. **Sixteen are retained exactly as the runner wrote them:** `java.version`, `java.runtime.version`, `java.runtime.name`, `java.vendor`, `java.vm.name`, `java.vm.vendor`, `java.vm.version`, `java.vm.info`, `java.specification.version`, `java.class.version`, `os.name`, `os.arch`, `os.version`, `sun.arch.data.model`, `file.encoding` and `jdk.debug`.

That second point is a correction to an earlier revision of this archive, and it is worth naming as one. That revision emptied the `properties` element completely, which left the runtime provenance of every report resting on a hand-authored comment — the weakest possible form of the strongest available evidence, since a comment is exactly what an authored report can fake and a native `java.runtime.version` is exactly what it cannot. **Every report in this archive now states `java.runtime.version` = `1.8.0_492-8u492-ga~us2-0ubuntu1~25.10.1-b09` and `java.vm.version` = `25.492-b09`, read from the report itself rather than from any prose.** The harvest refuses to install a report that carries no `java.runtime.version`, and each installed file is verified to have lost exactly the angle brackets the dropped lines carried and no others.

Nothing else is altered: no attribute is removed, no outcome is added, reshaped or deleted, and no value is invented — there is no placeholder text and no non-numeric literal standing in for a count anywhere in the archive. A `sha256-manifest.txt` beside the reports covers every one of them and the provenance note itself, so the archive cannot be edited after the fact without detection; verify with `sha256sum -c sha256-manifest.txt` from that directory.

**This archive was re-captured, and the re-capture is itself a result.** The JDK 8 run described above was performed again, from the same base commit in a fresh isolated tree with a fresh local repository, in order to retain the property allowlist that the earlier revision had emptied. The two captures were then compared programmatically: **the same 278 files, and zero suites differing in testcase membership, in outcome kind, or in the `tests`/`failures`/`errors`/`skipped` attributes of their `testsuite` element.** The earlier archive was therefore genuine, and this one is the same evidence with its provenance restored — which is the strongest statement available about either.

Two consequences for how the archive is read:

- **Comparison against the migrated half is on testcase presence, testcase outcome and failure message content — never on byte identity.** Duration, host name and run instant legitimately vary between two runs of the same suite, and EasyMock 5 renders an unmet expectation more verbosely than EasyMock 4 while reporting the same unmet expectation. "Archived in its entirety" governs completeness of content, not sameness of bytes.
- **The two halves pair by filename, and the pairing is total in the direction that matters.** Every one of the 278 baseline reports has a migrated twin of the identical name — **zero suites lost** — which is enforced by the committed pairing contract rather than left to a reader's diff. Eight migrated reports have no baseline twin; all eight are enumerated in the next sub-section, and seven of them are simply classes that do not exist at the base commit. The seventh, `smoke-evidence/migrated/surefire/acm-service-data-update/TEST-com.armedia.acm.services.dataupdate.web.SolrReindexServiceTests.xml`, is the one that needed explaining, and the JDK 8 re-capture establishes directly why the baseline has no counterpart: the class `SolrReindexServiceTests.java` **does exist** in the base-commit source at `acm-services/acm-service-data-update/src/test/java/com/armedia/acm/services/dataupdate/web/`, the baseline run used the implicitly bound **`maven-surefire-plugin:2.12.4`**, and that version's default includes are `**/Test*.java`, `**/*Test.java` and `**/*TestCase.java` — none of which matches a class whose name ends in `Tests`. The baseline run consequently produced exactly **two** reports for that module, and the plural-named class is not among them. Surefire 3.x added `**/*Tests.java` to the defaults, so the pinned 3.5.2 selects it and it now runs and passes.

  The baseline report is therefore **correctly absent rather than missing**, and no report was lost, deleted or left unproduced. It is recorded here because a reviewer diffing the two trees will find it; because it is the one direction of difference that cannot be a regression — a test that never ran before and passes now; and because it is a real, if small, behavioural consequence of pinning the runner, which belongs on this page rather than in a footnote. Nothing was fabricated to close the gap, and nothing should be: an authored baseline report for a suite the baseline runner never selected would be exactly the defect this archive exists to have escaped.

### The eight migrated suites with no baseline counterpart, and why each has none

The archived migrated half carries **285** suites against the baseline half's **278**; the working tree now runs **286**, and the whole of that difference is enumerated below rather than left to be discovered from a count mismatch. The pairing is enforced mechanically by the committed contract at `smoke-evidence/expected-suites.txt`, generated from the two installed archives by `install-surefire-evidence.sh --manifest`; `smoke-checks.sh` reads it and each capture's `notes/surefire-pairing.txt` records the result. Both sides report **0 suites missing, 0 unlisted and 0 lost**, which is the fact that matters: **no suite that ran at baseline has stopped running or stopped being archived.**

| Module | Test class | Tests | Outcome | Why no baseline counterpart |
| --- | --- | --- | --- | --- |
| `acm-services/acm-service-data-update` | `com.armedia.acm.services.dataupdate.web.SolrReindexServiceTests` | 1 | passes | Class **exists** at the base commit; the baseline runner did not select it — see the preceding sub-section |
| `acm-services/acm-service-login` | `com.armedia.acm.auth.ad.ActiveDirectoryContextSourceTest` | 13 | all pass | Class did not exist at the base commit |
| `acm-services/acm-service-login` | `com.armedia.acm.auth.ad.ActiveDirectoryContextSourceInitializationTest` | 9 | all pass | Class did not exist at the base commit |
| `acm-services/acm-service-login` | `com.armedia.acm.auth.ad.ActiveDirectoryContextSourceJndiEnvironmentTest` | 7 | all pass | Class did not exist at the base commit |
| `acm-services/acm-service-login` | `com.armedia.acm.auth.ad.ActiveDirectoryJndiDefaultsTest` | 7 | all pass | Class did not exist at the base commit |
| `acm-user-interface/ark-angular-starter` | `com.armedia.acm.userinterface.angular.AngularResourceCopierSafetyTest` | 18 | all pass | Class did not exist at the base commit. Two of the eighteen were added after the deployment QA pass: one executes the real package manager with the environment the startup build hands it, and one requires a failed front-end command to carry its own output |
| `acm-user-interface/ark-angular-starter` | `com.armedia.acm.userinterface.angular.AngularResourceCopierWiringTest` | 6 | all pass | Class did not exist at the base commit |
| `acm-user-interface/ark-angular-starter` | `com.armedia.acm.userinterface.angular.AngularResourceCopierDeploymentCopyTest` | 9 | all pass | Class did not exist at the base commit. Added after the deployment QA pass, covering the deployment copy: the package manager's own symbolic links, containment of the folder walk, the stale sweep's deletion candidates, a missing assembled folder, and a copy whose source cannot be read |

**The two reasons are not interchangeable, and the distinction is load-bearing.** Seven of the eight classes are absent from the base commit outright, so no baseline run could ever have produced a report for them. The seventh existed and was skipped by the runner. Only the second kind is a behavioural consequence of this migration; collapsing both into "newly added" would have quietly hidden that. The generated pairing note therefore states both possibilities and defers the per-suite attribution to this table rather than asserting one.

The arithmetic closes exactly, and it is stated for both the archived capture and the working tree because the two differ by design.

- **Archived capture:** **278 baseline suites / 892 test methods** against **285 migrated suites / 951 test methods**. The first seven suites above contribute 1 + 13 + 9 + 7 + 7 + 16 + 6 = **59** methods, and 892 + 59 = 951. Every figure is read out of the two installed archives, whose `sha256-manifest.txt` files verify clean.
- **Working tree now:** **286 suites / 962 test methods**, re-measured by a full offline `mvn -B -o -fae test` run and cross-checked against all 286 `TEST-*.xml` reports, which agree exactly. The delta of +1 suite and +11 methods over the archived migrated half is the eighth suite above (9 methods) plus the two methods added to `AngularResourceCopierSafetyTest`; both additions exist to hold the deployment defects the QA pass found, and each was verified to fail against the pre-fix class before being committed.

In both runs the red outcomes are **3 failures, 1 error and 21 skips**, and **all four red outcomes are the four rows registered below** — so the entire delta against the baseline is additive coverage, with no regression anywhere in the corpus.

### The environment precondition that gates a complete run

Three artifacts do not resolve from Maven Central and are supplied instead from `file://` local repository declarations in the root `pom.xml`: an ArkCase license-headers artifact, the TouchNet client that the reactor's only two `javax.xml.rpc`-importing files depend on, and an EclipseLink SLF4J logging bridge. Because `acm-service-billing` is a reactor member, an unprovisioned local repository blocks a full reactor build, and therefore blocks a complete baseline capture.

This condition is **JDK-independent and identical at the JDK 8 baseline** — it is **not** a migration defect. It is registered as an environment precondition in [Pre-existing Defects](pre-existing-defects.md), and its binding constraint is repeated here because a red build invites exactly the wrong shortcut: **under no circumstances may the module, the dependency, or the repository declarations be deleted to make the build green.** Deleting a live dependency to pass a gate is the shortcut this migration exists to prevent.

In this checkout the precondition is **satisfied** rather than outstanding. The backing repository is present in the tree at `arkcase-lib`, is tracked in version control, and carries all three artifacts; it resolved every request the capture made of it without one error. **Nothing constrained the capture's completeness**: all 142 modules installed, every module with a test tree was reached, and the archive covers all 66 modules that executed a Surefire test.

## The Test Corpus at Baseline

Every figure below was re-derived at base commit `c8f6226105` rather than copied forward. All eleven baseline values match the migration plan's stated values exactly, so no divergence has to be reported against the plan.

The working-tree column is stated separately rather than being asserted equal to the baseline, because for four measures **it is not equal** and saying so is the point: the migration adds seven test classes — six with the runtime work and a seventh holding the deployment defects the QA pass found — and a table that quietly published one number for both columns would either understate the working tree or misattribute the addition to the base commit.

| Measure | Verified at base commit `c8f6226105` | Working tree now | Δ |
| --- | --- | --- | --- |
| `src/test/java` source trees | 76 | 77 | +1 — `ark-angular-starter` had no test tree at the base commit |
| Java test source files | 402 | 409 | +7 — the seven classes enumerated above |
| `*Test.java` (unit) | 280 | 287 | +7 — same seven |
| `*IT.java` (integration) | 86 | 86 | — |
| Files importing `org.junit.Test` | 366 | 373 | +7 — same seven |
| Files importing `org.junit.jupiter` (JUnit 5) | 0 | 0 | — |
| Existing `@Ignore` occurrences | 26 | 26 | — **must not move**; see below |
| POMs declaring `maven-surefire-plugin` | 0 of 145 | 1 — the root aggregator | +1 — the pinned declaration this migration adds |
| POMs declaring `maven-failsafe-plugin` | 3 — the root aggregator plus two children | 3 | — |
| POMs configuring `rerunFailingTestsCount` or a retry plugin | 0 of 145 | 0 | — |
| Test classes importing `org.powermock` | 6 | 0 | −6 — all six rewritten onto Mockito, no assertion changed |

The two Δ values that would signal a violation are the ones that are zero: `@Ignore` occurrences and retry configuration. Both are unchanged, and both are re-derived in the verification block below rather than asserted here.

Five points follow from that table and each one binds something.

- **There is no JUnit 5 anywhere.** All 366 annotated test files are JUnit 4, and `org.junit.jupiter` appears in zero files. JUnit itself is **not** upgraded: it appears in [Dependency Change Inventory](dependency-change-inventory.md) only because removing PowerMock lifts its `4.12` pin — a change in *constraint*, not in version. Migrating the framework would mean rewriting assertions, which is forbidden outright.
- **Twenty-six `@Ignore` occurrences already exist at the JDK 8 baseline**, spread over twelve test classes, the largest concentration being fourteen in a single FOIA business-rule test. These are **inherited**. They are **not** exclusions introduced by this migration, and **no new `@Ignore` may be added anywhere.** A reviewer counting `@Ignore` after the migration must find the same 26; any increase violates R-5 regardless of whether it appears in Surefire configuration or in source, because R-5's first clause forbids disabling a failing test by any mechanism. The count was re-derived on both revisions and is identical.
- **Surefire is declared in zero POMs at the baseline**, so unit tests execute on whatever version Maven implicitly binds — `2.12.4` against the resolved repository. That is precisely why the migration adds a pinned declaration: it creates the **single auditable location** where an exclusion could be recorded and reviewed. At the baseline no such location exists, which means the baseline could not have carried an exclusion even if one had been wanted.
- **Failsafe is declared in three POMs, not one:** the root aggregator plus `acm-standard-applications/acm-foia/pom.xml` at line 32 and `acm-standard-applications/acm-privacy/pom.xml` at line 29. Recorded so that a reviewer auditing integration-test configuration does not stop at the root and conclude the other two are untouched — they move onto the shared version property with it.
- **Fail-fast is safe, and the one false positive is named.** With **no** `rerunFailingTestsCount` configuration and **no** retry plugin in any of the 145 POMs, a failure observed at baseline is a real, reproducible failure rather than a flake. A reviewer grepping the reactor for `retry` will nevertheless find hits: they are all the `spring-retry` **library** — an application-level concern, declared as a managed dependency with three consumers in `acm-alfresco-rma-integration`, `acm-spring-context-holder` and `acm-service-search`. It has nothing whatever to do with rerunning tests, and finding it is not grounds for concluding this register is unsound.

## Register of Baseline Failures

**The register has four rows.** Every one is a test that was already red on JDK 8 at the base commit, read out of the archived report named in its last column, and every one is still red on Java 17 with the same outcome kind and the same cause. None is excluded, disabled or ignored in the migrated build.

| Module | Test class | Test method | Failure kind | Message excerpt | Archived Surefire XML |
| --- | --- | --- | --- | --- | --- |
| `acm-services/acm-service-ecm` | `com.armedia.acm.plugins.ecm.web.api.FileDownloadAPIControllerTest` | `downloadFileByIdAndVersion_successful` | `failure` | Expectation failure on verify: `ContentStream.getFileName(): expected: at least 1, actual: 0` | `smoke-evidence/baseline/surefire/acm-service-ecm/TEST-com.armedia.acm.plugins.ecm.web.api.FileDownloadAPIControllerTest.xml` |
| `acm-services/acm-service-ecm` | `com.armedia.acm.plugins.ecm.web.api.FileDownloadAPIControllerTest` | `downloadFileById_successful` | `failure` | Expectation failure on verify: `ApplicationEventPublisher.publishEvent(capture(Nothing captured yet)): expected: 1, actual: 0` | `smoke-evidence/baseline/surefire/acm-service-ecm/TEST-com.armedia.acm.plugins.ecm.web.api.FileDownloadAPIControllerTest.xml` |
| `acm-services/acm-service-ecm` | `com.armedia.acm.plugins.ecm.web.api.FileDownloadAPIControllerTest` | `override_mime_type` | `failure` | Expectation failure on verify: `ApplicationEventPublisher.publishEvent(capture(Nothing captured yet)): expected: 1, actual: 0` | `smoke-evidence/baseline/surefire/acm-service-ecm/TEST-com.armedia.acm.plugins.ecm.web.api.FileDownloadAPIControllerTest.xml` |
| `acm-services/acm-service-compress-folder` | `com.armedia.acm.compressfolder.FolderCompressorTest` | `testCompressFolderMaxSize` | `error` | `java.lang.NullPointerException: Deflater has been closed` | `smoke-evidence/baseline/surefire/acm-service-compress-folder/TEST-com.armedia.acm.compressfolder.FolderCompressorTest.xml` |

The column contract those rows satisfy, restated so a later row cannot be added in a looser shape — a citation from a Surefire `excludes` entry has to resolve to a single test method backed by a single evidence file:

| Column | Content required |
| --- | --- |
| Module | The Maven module path within the reactor, for example `acm-services/acm-service-object-lock` |
| Test class | The fully-qualified class name |
| Test method | The method name as it appears in the report's `testcase` element |
| Failure kind | `failure` or `error`, taken from the element name, never inferred |
| Message excerpt | A short single-line excerpt of the element's `message` attribute |
| Archived Surefire XML | The relative path of the evidencing report, as inline code, in the form `smoke-evidence/baseline/surefire/<module>/TEST-<fully.qualified.Class>.xml` |

A multi-line stack trace never belongs in a table cell — it breaks the pipe table. The traces for these four live in the archived reports, at full length, and the two distinct causes are worth naming here because a reader classifying a migrated red needs to recognise them.

### `FolderCompressorTest.testCompressFolderMaxSize`

The compressor's own close path re-enters a deflater it has already closed, so the max-size condition the test exercises surfaces as a null-pointer error out of the platform's zip stream instead of the failure the test expects. The trace is identical on both runtimes down to the production line numbers — `DefaultFolderCompressor.compressFolder` at the same three frames — which is what places it here rather than in a regression report. It is a **pre-existing defect in application code**, and it is deliberately not fixed: R-6 makes a broken test found at baseline a documentation event rather than a repair event, and the row above is that documentation. [Pre-existing Defects](pre-existing-defects.md) is the companion register for defects that are not test failures.

### `FileDownloadAPIControllerTest`, three methods

All three end in an unmet EasyMock expectation: the controller does not invoke the collaborator the fixture insists on. Same three methods, same expectations, same outcome kind on both runtimes. The only difference between the two halves of the archive is presentational — EasyMock 5 prefixes the mock's interface into the message where EasyMock 4 did not — which is precisely why the comparison contract above is on message *content* and never on bytes. Also a **pre-existing defect**, documented in the row above rather than fixed, for the same reason.

**Neither cause is a licence to exclude anything.** A row here classifies a red test as pre-existing; it does not authorise removing it from the run. All four still execute in the migrated build, and the migrated Surefire declaration carries no `excludes` element at all.

### Skipped test methods, and why none of them is a row

The archive records **21 `<skipped>` elements**, and every one is a genuine inherited `@Ignore`. There is no second kind: no skip in this archive is a provenance marker, a placeholder or a not-executed note, because every report is a native capture of a run that actually executed. A skipped test is not a failing test, so an `@Ignore` is not a licence to add an exclusion for the same class.

They map to real annotation sites in test source, and each is evidenced by a report in the archive. All nine reports that carry a skip, with the count each one carries, so the 21 is auditable rather than asserted:

| Skips | Archived Surefire XML |
| --- | --- |
| 13 | `smoke-evidence/baseline/surefire/acm-foia/TEST-com.armedia.acm.plugins.casefile.service.CaseFileEnterQueueBusinessRuleTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-encryption/TEST-com.armedia.acm.crypto.AcmCryptoUtilsImplTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-foia/TEST-gov.foia.service.ResponseFolderCompressorServiceTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-form-close-complaint/TEST-com.armedia.acm.form.closecomplaint.service.CloseComplaintServiceTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-service-calendar-integration-exchange/TEST-com.armedia.acm.calendar.service.integration.exchange.CalendarEntityHandlerTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-service-data-update/TEST-com.armedia.acm.services.dataupdate.service.OutlookFolderCreatorPasswordMd5ToSha256UpdateExecutorTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-service-email/TEST-com.armedia.acm.services.email.service.AcmFilesystemMailTemplateConfigurationServiceTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-task-plugin/TEST-com.armedia.acm.plugins.task.service.impl.ActivitiTaskDaoTest.xml` |
| 1 | `smoke-evidence/baseline/surefire/acm-zylab-integration/TEST-com.armedia.acm.tool.zylab.service.ZylabProductionFileExtractorTest.xml` |

The 13 in one file are the FOIA business-rule concentration named in the corpus table, reported as 13 skipped methods rather than as one class-level skip because the annotation sits on the methods. Four of the nine are class-level instead — `AcmCryptoUtilsImplTest`, `CalendarEntityHandlerTest`, `OutlookFolderCreatorPasswordMd5ToSha256UpdateExecutorTest` and `ActivitiTaskDaoTest` — and a class-level skip is reported as a single element regardless of how many methods the class declares. All 21 are part of the inherited 26 recorded in the corpus table, and **the migrated run reports the same 21 skips from the same nine reports**.

One reporting difference between the two halves is recorded here so it is not mistaken for a changed outcome: for a **class-level** `@Ignore`, the implicitly bound Surefire at the baseline named the skipped testcase after the class, while the pinned 3.5.2 leaves that name empty. Both report one skipped testcase for the same class. The outcome is identical; only the label differs.

### Uncovered modules — neither passed nor failed

An **uncovered** module is one for which the archive holds no report at all. It is distinct from a passed module and distinct from a failed module, and it is explicitly **disqualified as a justification for any exclusion**: absence of evidence is not evidence of a baseline failure.

The archive covers **66 of the 76 test-source-bearing modules**. The remaining **10 are uncovered**, listed here in full so the boundary is auditable rather than approximate:

- `acm-plugins/acm-default-plugins` — `acm-category-plugin`
- `acm-services` — `acm-service-participants`, `acm-service-protect-url`, `acm-service-sequence-manager`
- `acm-standard-applications` — `arkcase`
- `acm-tool-integrations` — `acm-activemq-configuration`, `acm-ephesoft`, `acm-files-property-file-manager`, `acm-spring-context-holder`, `acm-spring-data-source`

Every one of the ten is uncovered for the same benign reason: its test tree holds no Surefire-eligible test class. The tests there are `*IT` classes, which Failsafe executes in the integration-test phase and which emit their own reports, so they are correctly absent from a Surefire-only archive; the few remaining files in those trees are fixtures, entities and message listeners with no test method at all, which the runner correctly declines to run. **Nothing was skipped, excluded or lost to reach this boundary** — the run reached every module, and the migrated archive covers exactly the same 66 modules, so the covered set is identical on both sides.

## The Migrated Surefire Declaration

The migration adds a `maven-surefire-plugin` declaration to the root `pom.xml` `<pluginManagement>` block, pinned at `3.5.2` through a shared version property that `maven-failsafe-plugin` also consumes so unit and integration forking cannot drift apart. Two constraints govern that declaration, and both are load-bearing.

### Constraint 1 — exclusions must cite a row, and the declaration ships with none

The declaration **ships with no exclusions at all, and it may carry none unless a row in this register justifies one.** As delivered it carries a `groupId`, an `artifactId` and a `version` and nothing else — no `<configuration>` element, and therefore no `<excludes>` element. The register having four rows does not change that: a row classifies a red test as pre-existing, it does not authorise removing it from the run, and all four of those tests still execute in the migrated build. An exclusion with no row **fails**; an exclusion with a row still has to be argued, and none has been.

Any exclusion added later must cite its row here **by class and by method**, so the citation resolves to one test method and one evidence file rather than to a module or a package. This is the mechanism by which R-5 becomes reviewable instead of aspirational: at the baseline, Surefire was declared in zero of the 145 POMs, so there was no location where an exclusion could even be written down, let alone audited. The pinned declaration creates that single auditable location, and this page is what fills it.

### Constraint 2 — the declaration must set no literal `<argLine>`, and this is a false-pass trap

This is the coupling most likely to be missed, because it makes a broken build look like a passing one.

Every `pom.xml` line anchor below is the line **as it stands at base commit `c8f6226105`**, because that is the state a baseline document describes and because those numbers cannot move. The aggregator has since been edited by this change set, so the same elements sit lower in the current file — the JaCoCo plugin block at lines 489 to 552, the `pre-unit-test` execution at 508 to 516, and the `check` execution at 528 to 550 — and every element named below is additionally identifiable by its `id` or its tag name, which no edit shifts. The causal chain, in full:

- JaCoCo's `prepare-agent` goal is configured in the root `pom.xml`, in the plugin block that spans lines 427 to 490 at the base commit, with the `pre-unit-test` execution that binds `prepare-agent` at lines 446 to 454. That goal communicates its agent configuration to the test runner through the **default `argLine` property export**; it does not pass the agent to Surefire by any other route.
- It writes coverage data to `${project.build.directory}/jacoco-reports/jacoco.exec`, and it binds a `check` goal — the execution whose `id` is `check`, at base-commit lines 466 to 488, bound to the `test` phase — that evaluates a `BUNDLE`-scoped **`LINE` / `COVEREDRATIO`** rule against `${code.coverage.minimum}`, whose value is **`0.02`**.
- If the Surefire declaration sets a literal `<argLine>`, it **overwrites that export**. The agent is never attached, so instrumentation is severed **silently** — no warning, no error, no failed goal.
- The coverage data file is then empty, and the `check` goal evaluates an **empty data set** against a 0.02 minimum. An empty data set does not fail that rule. The result is a **false pass**: the build reports coverage satisfied while having measured nothing at all.
- Therefore: **no literal `<argLine>` in the Surefire declaration.** If fork arguments are ever genuinely required, they must be appended in a way that preserves the JaCoCo export rather than replacing it.

The corresponding validation obligation follows, and it is R-T7 applied to coverage: the migrated build must be checked for **JaCoCo liveness** — a non-empty `jacoco.exec` and a `check` goal that demonstrably evaluated a real data set. **An empty data set that produces a pass is a FAILURE of the gate, notwithstanding a zero exit code.** Liveness is confirmed by inspecting the artifact, never inferred from the process having exited cleanly.

Two adjacent false positives are named so neither is mistaken for a test exclusion. The JaCoCo configuration carries **eight package glob `<excludes>`** covering the close-complaint form, the ActiveMQ tools, the crypto utilities, the Zylab tool, the data package, the calendar service, the admin plugin and the Outlook service. Those suppress **coverage measurement only**. They disable no test whatsoever, they are pre-existing and unchanged by this migration, and they are not exclusions in R-5's sense.

The migration adds **one** further exclusion beside them, on the `prepare-agent` execution alone, naming the rule engine's ANTLR-generated lexer and parser package. Its reason is mechanical: those generated methods already sit close to the per-method bytecode ceiling, so instrumenting them overflows it and the agent reports an instrumentation error on every module that compiles a decision table, after which the class loads uninstrumented regardless. It **cannot move any measured figure**, because report and check analyse the module's own classes and never a dependency's, and it disables no test — every test still runs, and still runs instrumented, which the liveness check above confirms. It is recorded in [Dependency Change Inventory](dependency-change-inventory.md) and it is **not** an R-5 exclusion, so it needs no row on this page.

## The Six PowerMock Classes Were Rewritten, Not Excluded

This is R-5's most consequential application in the entire migration, and it belongs on this page because the easy alternative would have been six rows and six exclusions.

Exactly **six** test classes import `org.powermock`, verified repository-wide at the base commit:

| Module | Test class |
| --- | --- |
| `acm-plugins/acm-default-plugins/acm-case-file-plugin` | `com.armedia.acm.plugins.casefile.dao.QueuePropertyFileChangeWatcherTest` |
| `acm-plugins/acm-default-plugins/acm-category-plugin` | `com.armedia.acm.plugins.category.service.CategoryServiceIT` |
| `acm-services/acm-service-object-lock` | `com.armedia.acm.service.objectlock.service.AcmObjectLockServiceImplTest` |
| `acm-services/acm-service-calendar-integration-exchange` | `com.armedia.acm.calendar.service.integration.exchange.CalendarEntityHandlerTest` |
| `acm-tool-integrations/acm-transcribe-tool` | `com.armedia.acm.tool.transcribe.AWSTranscribeServiceTest` |
| `acm-tool-integrations/acm-comprehend-medical` | `com.armedia.acm.tool.comprehendmedical.AWSComprehendMedicalServiceTest` |

The facts that make this the register's centrepiece:

- **PowerMock 2.0.9 fails on Java 17** with an inaccessible-object error raised from its reflection helper against a core JDK method, and **2.0.9 is the project's final release — there is no version to upgrade to.** Nor was the failure accommodated by relaxing the platform's encapsulation: adding a module-access JVM argument was prohibited, and under R-T3 the resolution for a dependency that fails under strong encapsulation is to upgrade or replace that dependency. Excluding the six classes would have been the easy path.
- **R-5 forbade it.** All six are **rewritten onto Mockito**, and **every assertion is left unmodified**. The mocking *mechanism* changed; the *expectations* did not. Static mocking replaces the static-mock idiom and construction mocking replaces the constructor-expectation idiom, both scoped in try-with-resources.
- **The awkward cases were absorbed rather than avoided.** In the two AWS tool tests, three constructor interceptions of a JDK file-stream type cannot be reproduced with construction mocking at all, because a type loaded by the bootstrap class loader is not interceptable. A narrow, test-visible stream-supplier seam was introduced instead — more work than an exclusion, and the only option that preserves the assertions. That decision and the alternatives rejected alongside it are recorded in [Ambiguity Resolutions](ambiguity-resolutions.md).
- **One of the six mixes frameworks.** `QueuePropertyFileChangeWatcherTest` retains its existing EasyMock runner and only its PowerMock portion changed, so the class now drives EasyMock and Mockito construction mocking side by side. That is deliberate: replacing the runner would have disturbed the EasyMock expectations, which are assertions.
- **The ordering was mandatory, not incidental.** PowerMock had to be **removed before** Mockito could advance, because PowerMock hard-pinned `mockito-core:3.3.3` and `junit:4.12`. The mocking-stack edits form an ordered chain rather than a set of independent bumps, and reversing two links leaves the reactor unable to resolve a coherent mocking stack. Each link is a row in [Dependency Change Inventory](dependency-change-inventory.md).
- **A companion removal carried zero test risk, and that was verified rather than assumed.** `easymockclassextension` is declared in five modules and has **zero usages** across all 402 Java test source files, so deleting it could not disable anything and nothing was rewritten to accommodate it.

The net effect on this register: **the six classes contribute zero rows.** No archived report for any of them records a failure or an error, on either runtime. **Five of the six** are Surefire-eligible and are covered by the archive on both sides, so each can be read directly and compared against its migrated twin of the same name:

- `smoke-evidence/baseline/surefire/acm-case-file-plugin/TEST-com.armedia.acm.plugins.casefile.dao.QueuePropertyFileChangeWatcherTest.xml` — 1 test, green on both
- `smoke-evidence/baseline/surefire/acm-service-object-lock/TEST-com.armedia.acm.service.objectlock.service.AcmObjectLockServiceImplTest.xml` — 8 tests, green on both
- `smoke-evidence/baseline/surefire/acm-service-calendar-integration-exchange/TEST-com.armedia.acm.calendar.service.integration.exchange.CalendarEntityHandlerTest.xml` — 1 test, skipped on both under its inherited class-level `@Ignore`
- `smoke-evidence/baseline/surefire/acm-transcribe-tool/TEST-com.armedia.acm.tool.transcribe.AWSTranscribeServiceTest.xml` — 6 tests, green on both
- `smoke-evidence/baseline/surefire/acm-comprehend-medical/TEST-com.armedia.acm.tool.comprehendmedical.AWSComprehendMedicalServiceTest.xml` — 8 tests, green on both

The sixth, `CategoryServiceIT` in `acm-category-plugin`, is an **integration** test executed by Failsafe rather than Surefire, so it is correctly absent from a Surefire-only archive on both sides; absence of a report disqualifies it as an exclusion justification just as firmly. None of the six was registered as failing at the JDK 8 baseline, none is excluded in the migrated build, and none changed outcome across the migration.

## How to Use This Register

The reviewer procedure, in the order that catches the most.

- **Every test failure in the migrated Java 17 run must map to a row here.** A failure with no matching row is a **migration regression**, not an accepted baseline condition. The migrated run reports exactly the four reds in the table above and nothing else, so the mapping is complete and **the regression count is zero**. That comparison was made programmatically, over both archives, on the (suite, testcase, outcome-kind) triple rather than by eye.
- **Every exclusion in the migrated Surefire configuration must cite a row here**, by class and by method. An exclusion with no row **fails**. The declaration as delivered carries no `<configuration>` element at all, so the current expected finding is no exclusions.
- **The `@Ignore` count must be unchanged** from the 26 recorded in the corpus table. Any increase violates R-5 whether it appears in build configuration or in source.
- **JaCoCo liveness must be confirmed, not inferred from an exit code**: a non-empty `jacoco.exec` and a `check` goal that evaluated a real data set. A pass over an empty data set is a gate failure.
- **The archived baseline XML under `smoke-evidence/baseline/surefire/` is the tie-breaker** for any dispute about what was failing before the migration. It is a native capture of a real JDK 8 run, so a report in it may be cited directly as an observation — subject only to the one disclosed normalisation and to the comparison contract above, both recorded in the provenance section and in every file's own header.
- **Read the two halves together.** For any class, the report of the same name under `smoke-evidence/migrated/surefire/` is its Java 17 twin. The pairing is total in one direction — no baseline report lacks a migrated twin — and the seven migrated reports with no baseline twin are each enumerated, with the reason it has none, in *The seven migrated suites with no baseline counterpart* above.

The figures published on this page are re-derivable. Run from the repository root; the base commit is `c8f6226105`.

```bash
BASE=docs/migration/smoke-evidence/baseline/surefire
MIG=docs/migration/smoke-evidence/migrated/surefire

# the corpus AT THE BASE COMMIT.  Read out of the commit itself with ls-tree and git grep, not
# out of the working tree: ls-files would answer for the tree as it stands now, and four of these
# figures legitimately differ there because the migration adds six test classes.  These are the
# left-hand column of the corpus table.
B=c8f6226105
git ls-tree -r --name-only $B | grep -oE '^.*/src/test/java/' | sort -u | wc -l                # 76
git ls-tree -r --name-only $B | grep -c '/src/test/java/.*\.java$'                             # 402
git ls-tree -r --name-only $B | grep -c '/src/test/java/.*Test\.java$'                         # 280
git ls-tree -r --name-only $B | grep -c '/src/test/java/.*IT\.java$'                           # 86
git grep -l 'org.junit.Test'    $B -- '*.java' | grep -c '/src/test/java/'                     # 366
git grep -l 'org.junit.jupiter' $B -- '*.java' | wc -l                                         # 0
git grep -c '@Ignore' $B -- '*.java' | awk -F: '{s+=$3} END {print s}'                         # 26
git grep -l rerunFailingTestsCount $B -- 'pom.xml' '*/pom.xml' | wc -l                         # 0
git grep -l 'maven-surefire-plugin' $B -- 'pom.xml' '*/pom.xml' | wc -l                        # 0
git grep -l 'org.powermock'             $B -- '*.java' | wc -l                                 # 6
git grep -l 'org.easymock.classextension' $B -- '*.java' | wc -l                               # 0

# the same corpus IN THE WORKING TREE - the right-hand column.  The four differences are the seven
# added test classes and the one new test tree that holds three of them.
git ls-files | grep -oE '^.*/src/test/java/' | sed 's|/src/test/java/||' | sort -u | wc -l     # 77
git ls-files '*.java' | grep -c '/src/test/java/'                                              # 409
git ls-files '*Test.java' | grep -c '/src/test/java/'                                          # 287
git ls-files '*IT.java'   | grep -c '/src/test/java/'                                          # 86
git ls-files '*.java' | xargs grep -l 'org.junit.Test'    | grep -c '/src/test/java/'          # 373
git ls-files '*.java' | xargs grep -l 'org.junit.jupiter' | wc -l                              # 0
git ls-files '*.java' | xargs grep -l 'org.powermock' | wc -l                                  # 0
git ls-files '*.java' | xargs grep -l 'org.easymock.classextension' | wc -l                    # 0

# the two counts that must NOT have moved.  An increase in either is an R-5 violation regardless
# of where it appears, so they are re-derived on the working tree and compared to the 26 and the 0
# above rather than restated.
git ls-files '*.java' | xargs grep -c '@Ignore' | awk -F: '{s+=$2} END {print s}'              # 26
git ls-files 'pom.xml' '*/pom.xml' | xargs grep -l rerunFailingTestsCount | wc -l              # 0

# the archive, element by element - these are the figures published above
find $BASE -name 'TEST-*.xml' | wc -l                                                         # 278
find $BASE -mindepth 1 -maxdepth 1 -type d | wc -l                                            # 66
grep -rho '<testcase' $BASE | wc -l                                                           # 892
grep -rho '<skipped'  $BASE | wc -l                                                           # 21
grep -rho '<failure'  $BASE | wc -l                                                           # 3
grep -rho '<error'    $BASE | wc -l                                                           # 1
find $MIG  -name 'TEST-*.xml' | wc -l                                                         # 285
find $MIG  -mindepth 1 -maxdepth 1 -type d | wc -l                                            # 67
grep -rho '<testcase' $MIG | wc -l                                                            # 951
grep -rho '<skipped'  $MIG | wc -l                                                            # 21
grep -rho '<failure'  $MIG | wc -l                                                            # 3
grep -rho '<error'    $MIG | wc -l                                                            # 1

# the seven-suite delta and the pairing contract that enforces it.  Write the two listings to
# files rather than comparing them through process substitution: comm needs both inputs sorted
# under the SAME collation, and LC_ALL=C is what makes '-' and '.' order predictably.
( cd $BASE && find . -name 'TEST-*.xml' | sed 's|^\./||' | LC_ALL=C sort ) > /tmp/b.list
( cd $MIG  && find . -name 'TEST-*.xml' | sed 's|^\./||' | LC_ALL=C sort ) > /tmp/m.list
LC_ALL=C comm -13 /tmp/b.list /tmp/m.list | wc -l                                             # 7  <- added
LC_ALL=C comm -23 /tmp/b.list /tmp/m.list | wc -l                                             # 0  <- nothing lost
grep -c '^BOTH'           docs/migration/smoke-evidence/expected-suites.txt                   # 278
grep -c '^MIGRATED-ONLY'  docs/migration/smoke-evidence/expected-suites.txt                   # 7
grep -c '^BASELINE-ONLY'  docs/migration/smoke-evidence/expected-suites.txt                   # 0

# every report states its own runtime, so the archive proves which JDK produced it without
# reference to any prose on this page.  The allowlist retains 16 native properties per report.
grep -rl 'name="java.runtime.version" value="1.8.0_492' $BASE | wc -l                         # 278
grep -rl 'name="java.class.version" value="52.0"'       $BASE | wc -l                         # 278
grep -rl 'name="java.runtime.version" value="17.0.19'   $MIG  | wc -l                         # 285
grep -rl 'name="java.class.version" value="61.0"'       $MIG  | wc -l                         # 285

# integrity: each archive carries a checksum manifest covering every report and its own
# provenance note, so an edit after harvest is detectable rather than invisible.
( cd $BASE && sha256sum -c sha256-manifest.txt >/dev/null && echo OK )                        # OK
( cd $MIG  && sha256sum -c sha256-manifest.txt >/dev/null && echo OK )                        # OK

# provenance gates: no derived-report residue, and no path of the machine that ran the capture.
# The third command looks for the checkout root specifically, not for every temporary path: one
# report legitimately prints a scratch file the test itself writes under the system temp directory,
# and that is the test's own captured output rather than leaked environment.
grep -rl 'not-captured' $BASE $MIG | wc -l                                                    # 0
grep -rho 'status="[^"]*"' $BASE $MIG | wc -l                                                 # 0
grep -rl '/tmp/blitzy' $BASE $MIG | wc -l                                                     # 0
find $BASE $MIG -type f ! -name '*.xml' | wc -l                                               # 4
#   the four are run-provenance.txt and sha256-manifest.txt in each archive; every other file
#   in both trees is a Surefire report written by the runner.

# the four rows above, re-derived from the archive rather than read off this page
grep -rl -e '<failure' -e '<error' $BASE | sort                                               # 2 files
grep -rl -e '<failure' -e '<error' $MIG  | sort                                               # the same 2 class names
```

Each `#` value is the expected output, and each is asserted rather than remembered: the last pair of commands must return the two file names behind the four register rows — `FileDownloadAPIControllerTest` under `acm-service-ecm` and `FolderCompressorTest` under `acm-service-compress-folder` — from **both** halves of the archive, which is the same statement as "zero regressions" expressed as a command.

Two wording gates apply to this page and both are checkable:

```bash
PAGE=$(git ls-files '*baseline-test-failures.md')
grep -rEn 'Java (8|9|10|11)\b' docs/
grep -c '^```' $PAGE
```

The first must produce no hit from this page — the older runtime is written `JDK 8` throughout — and the second must return an even number so that every fence is balanced. Three further checks have no printable command, because writing the pattern would itself create the hit this page must not contain: confirm by reading that the page contains **no literal occurrence of either of the two JDK 9 module-access JVM arguments, nor of the legacy reflective-access flag** — which is why the register that would record such exceptions is referred to here **by title only**, as the JDK access exceptions register, its own filename embedding one of those tokens; confirm that **no link target on this page carries the documentation folder prefix**, sibling deliverables being linked by plain filename and parent pages by `../`; and confirm that **the superseded frontend package manager is named nowhere on this page**, since it has no bearing on the backend test suite.

Related registers, each covering a class of decision that does not belong here: [Dependency Change Inventory](dependency-change-inventory.md) for the test-library changes that make this suite runnable on Java 17, [Pre-existing Defects](pre-existing-defects.md) for the environment precondition and for the two R-6 escape-clause invocations that are recorded outside this folder, [Ambiguity Resolutions](ambiguity-resolutions.md) for the decisions where JDK 8 baseline behaviour was the tie-breaker, [Static Audit Output](static-audit-output.md) for the before-and-after capture of the JDK-internal usage audit, and the [Developer Setup](../setup.md) page for the prerequisites the migrated build documents.
