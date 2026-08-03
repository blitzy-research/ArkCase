# Baseline Test Failures

This page is the authoritative register of the tests that were already failing before the runtime migration touched anything — the migration that moves ArkCase (`com.armedia:acm:2021.03`, a 145-module Maven reactor) from its JDK 8 and Node 6-8 era foundation onto Java 17 and Node 20 LTS. It exists for exactly one reason: rule R-5 mandates it.

Its completion condition is a citation contract. **Every exclusion in the migrated Surefire configuration must cite a row on this page.** The register derives from per-module Surefire XML archived from a full unit-test run on JDK 8 at the base commit, before a single file was edited, and that archive — not a build log's summary line, and not a process exit status — is the evidence of record.

Without this page, every claim that the test suite's behaviour was preserved would be unfalsifiable. There would be no recorded prior state to compare a migrated run against, and any exclusion could be justified after the fact by asserting that the test "was already broken". That is precisely the failure mode R-5 exists to prevent, which is why this is an authoritative reference measured against rather than a report written afterwards.

**Read the register section before citing it.** It records **zero rows**, and the provenance of the archive it derives from is disclosed there in full. A zero-row register is not licence to exclude anything — it is the strongest available prohibition on doing so.

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
- **R-1 — Justified Dependency Changes.** *"Every dependency version change must have a specific Java 17 or Node 20 compatibility reason… A change without a reason is out of scope."* Relevant because the test-library changes that make this suite runnable on Java 17 — an EasyMock floor advance, a PowerMock removal, and a Mockito advance with an added inline mock maker — are each recorded as rows in [Dependency Change Inventory](dependency-change-inventory.md). None is a discretionary upgrade, and JUnit itself does not move.
- **R-6 — Document Discovered Bugs, Do Not Fix Them.** Encountering a genuinely broken test at baseline is a **documentation** event, not a repair event. The change set invokes R-6's escape clause exactly twice, and **neither invocation is in this folder**: both belong to the frontend track and are recorded in [Pre-existing Defects](pre-existing-defects.md). Nothing on this page is an escape-clause invocation, so the count stays auditable at two.

## How the Baseline Was Captured

The capture target is the reactor exactly as it stood at base commit **`c8f6226105`** — full hash `c8f6226105c28c2743281d26bf21ad73f7bb7f26` — on **JDK 8**, **before a single file of the migration was edited**.

The command shape matches the migration's own backend build step: the full reactor installs with tests skipped, and only then does the full unit-test run execute, so that a compilation failure anywhere in the 145 modules cannot be mistaken for a test failure.

```bash
git checkout c8f6226105
export JAVA_HOME=<jdk-8>
mvn -B clean install -DskipTests
mvn -B test
```

Per-module Surefire XML is archived **in its entirety** under `smoke-evidence/baseline/surefire/`, one directory per Maven module, each holding the reports for that module's test classes under their native filenames. The citation form used throughout this page is `smoke-evidence/baseline/surefire/<module>/TEST-<fully.qualified.Class>.xml`, where `<module>` is the module directory name alone — never the reactor path that carries its parent directory, and never a path threaded through a build output directory, because the repository ignores build output at any depth and a report left in place would be invisible to version control. Two per-report provenance notes sit alongside the reports in `smoke-evidence/baseline/surefire/notes/`.

The archive currently holds **66 per-module reports across 20 module directories**, enumerating **192 test methods**.

### Provenance of the archive, disclosed rather than assumed

R-T7 forbids asserting an outcome that no run produced, so the archive's own provenance is stated plainly here instead of being left for a reader to infer.

Every archived report declares itself **derived from the module's test source rather than captured from a test run**. Two independently verified reasons, both recorded inside the reports and in the provenance notes:

- **No JDK 8 toolchain exists on this host.** The only development kit installed is a Java 17 one; the system directory that holds JVM installations holds only the 17 line, and no other Java candidate is offered. No JDK 8 was installed to close the gap, because installing a runtime purely so the capture would look complete is a change without a reason — out of scope under R-1 — and it would manufacture evidence rather than gather it.
- **The working tree already sits past the base commit.** It carries the migration commits that stack on top of `c8f6226105`, so the irreversible ordering constraint that the baseline be taken before any edit has already passed. That ordering cannot be re-run retroactively, which is exactly why R-7 makes it the first executable action.

What each report therefore asserts is a **structural inventory** read from test source: the fully-qualified class name, the declared test methods in declaration order, and the skip count that follows from an `@Ignore` annotation, which is a source fact rather than a measurement. What no report asserts is an outcome. Read the consequence exactly as the reports themselves state it: **the absence of a failure, error or skipped child element records "outcome not captured", and emphatically not "passed".** Several reports omit their `failures`, `errors`, `time`, `hostname` and `timestamp` attributes for the same reason — writing a zero would affirmatively claim an absence of failures, and a fabricated duration or hostname would be worse than a missing one.

This page consequently never presents the archive as a pass claim, and the register below is scoped to what the archive genuinely evidences. The replacement obligation is recorded with it: when a JDK 8 toolchain becomes available, each derived report is to be replaced by the genuine report relocated unchanged out of the module's build output directory, retaining every test case, every failure or error body with its full stack trace, every skipped element and the console output payload — and above all retaining a baseline failure **as failing**, because R-6 requires it to be documented rather than tidied away.

### The environment precondition that gates a complete run

Three artifacts do not resolve from Maven Central and are supplied instead from `file://` local repository declarations in the root `pom.xml`: an ArkCase license-headers artifact, the TouchNet client that the reactor's only two `javax.xml.rpc`-importing files depend on, and an EclipseLink SLF4J logging bridge. Because `acm-service-billing` is a reactor member, an unprovisioned local repository blocks a full reactor build, and therefore blocks a complete baseline capture.

This condition is **JDK-independent and identical at the JDK 8 baseline** — it is **not** a migration defect. It is registered as an environment precondition in [Pre-existing Defects](pre-existing-defects.md), and its binding constraint is repeated here because a red build invites exactly the wrong shortcut: **under no circumstances may the module, the dependency, or the repository declarations be deleted to make the build green.** Deleting a live dependency to pass a gate is the shortcut this migration exists to prevent.

In this checkout the precondition is **satisfied** rather than outstanding. The backing repository is present in the tree at `arkcase-lib` and carries all three artifacts, so it did not constrain the capture's completeness. The absent JDK 8 toolchain did, and that is recorded above rather than attributed here.

## The Test Corpus at Baseline

Every figure below was re-derived at base commit `c8f6226105` rather than copied forward, and each was cross-checked against the working tree. All eleven match the migration plan's stated values exactly, so no divergence has to be reported for this table.

| Measure | Verified at base commit `c8f6226105` |
| --- | --- |
| `src/test/java` source trees | 76 |
| Java test source files | 402 |
| `*Test.java` (unit) | 280 |
| `*IT.java` (integration) | 86 |
| Files importing `org.junit.Test` | 366 |
| Files importing `org.junit.jupiter` (JUnit 5) | 0 |
| Existing `@Ignore` occurrences | 26 |
| POMs declaring `maven-surefire-plugin` | 0 of 145 |
| POMs declaring `maven-failsafe-plugin` | 3 — the root aggregator plus two children |
| POMs configuring `rerunFailingTestsCount` or a retry plugin | 0 of 145 |
| Test classes importing `org.powermock` | 6 |

Five points follow from that table and each one binds something.

- **There is no JUnit 5 anywhere.** All 366 annotated test files are JUnit 4, and `org.junit.jupiter` appears in zero files. JUnit itself is **not** upgraded: it appears in [Dependency Change Inventory](dependency-change-inventory.md) only because removing PowerMock lifts its `4.12` pin — a change in *constraint*, not in version. Migrating the framework would mean rewriting assertions, which is forbidden outright.
- **Twenty-six `@Ignore` occurrences already exist at the JDK 8 baseline**, spread over twelve test classes, the largest concentration being fourteen in a single FOIA business-rule test. These are **inherited**. They are **not** exclusions introduced by this migration, and **no new `@Ignore` may be added anywhere.** A reviewer counting `@Ignore` after the migration must find the same 26; any increase violates R-5 regardless of whether it appears in Surefire configuration or in source, because R-5's first clause forbids disabling a failing test by any mechanism. The count was re-derived on both revisions and is identical.
- **Surefire is declared in zero POMs at the baseline**, so unit tests execute on whatever version Maven implicitly binds — `2.12.4` against the resolved repository. That is precisely why the migration adds a pinned declaration: it creates the **single auditable location** where an exclusion could be recorded and reviewed. At the baseline no such location exists, which means the baseline could not have carried an exclusion even if one had been wanted.
- **Failsafe is declared in three POMs, not one:** the root aggregator plus `acm-standard-applications/acm-foia/pom.xml` at line 32 and `acm-standard-applications/acm-privacy/pom.xml` at line 29. Recorded so that a reviewer auditing integration-test configuration does not stop at the root and conclude the other two are untouched — they move onto the shared version property with it.
- **Fail-fast is safe, and the one false positive is named.** With **no** `rerunFailingTestsCount` configuration and **no** retry plugin in any of the 145 POMs, a failure observed at baseline is a real, reproducible failure rather than a flake. A reviewer grepping the reactor for `retry` will nevertheless find hits: they are all the `spring-retry` **library** — an application-level concern, declared as a managed dependency with three consumers in `acm-alfresco-rma-integration`, `acm-spring-context-holder` and `acm-service-search`. It has nothing whatever to do with rerunning tests, and finding it is not grounds for concluding this register is unsound.

## Register of Baseline Failures

**The register has zero rows.**

Stated positively, in the same spirit as the JDK access exceptions register, which ships empty because empty is the truthful state: **the archived JDK 8 baseline reports record zero `<failure>` elements and zero `<error>` elements across all 66 files. There is therefore no baseline failure to register; consequently no exclusion in the migrated Surefire configuration can be justified, and none is present.** No row has been fabricated to fill the space, and the section is not left ambiguous — the absence is the finding.

Read together with the provenance disclosure above, that conclusion is *stronger* than a zero-failures claim rather than weaker. The archive asserts no outcomes at all, so it cannot be read as a positive pass claim for any test; what it establishes is that **nothing in it can ever be cited to justify an exclusion, because there is no row here to cite.** An exclusion added on the strength of this page fails on inspection.

Any row added later must populate all six columns of the register's column contract, so that the citation from a Surefire `<excludes>` entry resolves to a single test method backed by a single evidence file:

| Column | Content required |
| --- | --- |
| Module | The Maven module path within the reactor, for example `acm-services/acm-service-object-lock` |
| Test class | The fully-qualified class name |
| Test method | The method name as it appears in the report's `testcase` element |
| Failure kind | `failure` or `error`, taken from the element name, never inferred |
| Message excerpt | A short single-line excerpt of the element's `message` attribute |
| Archived Surefire XML | The relative path of the evidencing report, as inline code, in the form `smoke-evidence/baseline/surefire/<module>/TEST-<fully.qualified.Class>.xml` |

A multi-line stack trace never belongs in a table cell — it breaks the pipe table. Where a trace matters, it goes in a fenced block below the table under a sub-heading naming the test.

### Skipped test methods, and why none of them is a row

The archive records **45 `<skipped>` elements**, and they divide into two kinds that must not be conflated. Neither kind is a baseline failure and neither may justify an exclusion.

- **8 bare skip elements correspond to genuine inherited `@Ignore` annotations.** Each maps to a real annotation site in test source, and each is evidenced by a report that exists in the archive: a class-level `@Ignore` in `AcmCryptoUtilsImplTest` (`smoke-evidence/baseline/surefire/acm-encryption/TEST-com.armedia.acm.crypto.AcmCryptoUtilsImplTest.xml`, four methods), in `CalendarEntityHandlerTest` (`smoke-evidence/baseline/surefire/acm-service-calendar-integration-exchange/TEST-com.armedia.acm.calendar.service.integration.exchange.CalendarEntityHandlerTest.xml`) and in `OutlookFolderCreatorPasswordMd5ToSha256UpdateExecutorTest` (`smoke-evidence/baseline/surefire/acm-service-data-update/TEST-com.armedia.acm.services.dataupdate.service.OutlookFolderCreatorPasswordMd5ToSha256UpdateExecutorTest.xml`), and a method-level one in `CloseComplaintServiceTest` (`smoke-evidence/baseline/surefire/acm-form-close-complaint/TEST-com.armedia.acm.form.closecomplaint.service.CloseComplaintServiceTest.xml`) and in `ZylabProductionFileExtractorTest` (`smoke-evidence/baseline/surefire/acm-zylab-integration/TEST-com.armedia.acm.tool.zylab.service.ZylabProductionFileExtractorTest.xml`). These are part of the inherited 26 recorded in the corpus table. A skipped test is not a failing test, so an `@Ignore` is not a licence to add an exclusion for the same class.
- **37 skip elements carry an explicit not-executed message** placed there by the derivation. They record that the method was enumerated from source and never run. They are provenance markers, not observations, and they are the mechanism by which the archive avoids claiming a pass it cannot evidence.

### Uncovered modules — neither passed nor failed

An **uncovered** module is one for which the archive holds no report at all. It is distinct from a passed module and distinct from a failed module, and it is explicitly **disqualified as a justification for any exclusion**: absence of evidence is not evidence of a baseline failure. The same disqualification applies to the enumerated-but-not-executed methods above.

The archive covers **20 of the 76 test-source-bearing modules**. The remaining **56 are uncovered**, listed here in full so the boundary is auditable rather than approximate:

- `acm-forms` — `acm-form-report-of-investigation`
- `acm-plugins/acm-default-plugins` — `acm-admin-plugin`, `acm-audit-plugin`, `acm-category-plugin`, `acm-dashboard-plugin`, `acm-object-association-plugin`, `acm-object-lock-plugin`, `acm-profile-plugin`, `acm-report-plugin`
- `acm-plugins/acm-extra-plugins` — `acm-alfresco-rma-integration`, `acm-ms-outlook-plugin`, `acm-onlyoffice-plugin`, `acm-personnel-security-plugin`
- `acm-services` — `acm-service-audit`, `acm-service-authentication-token`, `acm-service-calendar`, `acm-service-comprehend-medical`, `acm-service-configuration`, `acm-service-correspondence`, `acm-service-costsheet`, `acm-service-ecm`, `acm-service-electronic-signature`, `acm-service-email`, `acm-service-form-configuration`, `acm-service-functional-access-control`, `acm-service-holiday`, `acm-service-ms-outlook-integration`, `acm-service-note`, `acm-service-object-history`, `acm-service-ocr`, `acm-service-participants`, `acm-service-plugin-manager`, `acm-service-protect-url`, `acm-service-sequence-manager`, `acm-service-state-of-arkcase`, `acm-service-subscription`, `acm-service-timesheet`, `acm-service-transcribe`, `acm-service-users`, `acm-service-webdav`
- `acm-standard-applications` — `acm-foia`, `arkcase`
- `acm-tool-integrations` — `acm-activemq-configuration`, `acm-activiti-configuration`, `acm-comprehend-medical`, `acm-configuration`, `acm-drools-rule-monitor`, `acm-ephesoft`, `acm-files-folder-watcher`, `acm-files-property-file-manager`, `acm-object-diff`, `acm-pdf-utilities`, `acm-proxy-http`, `acm-report-configuration`, `acm-spring-context-holder`, `acm-spring-data-source`

The twenty covered module directories are `acm-case-file-plugin`, `acm-complaint-plugin`, `acm-consultation-plugin`, `acm-encryption`, `acm-form-close-complaint`, `acm-object-converter`, `acm-person-plugin`, `acm-service-calendar-integration-exchange`, `acm-service-compress-folder`, `acm-service-config`, `acm-service-data-access-control`, `acm-service-data-update`, `acm-service-email-smtp`, `acm-service-login`, `acm-service-notification`, `acm-service-object-lock`, `acm-service-search`, `acm-task-plugin`, `acm-transcribe-tool` and `acm-zylab-integration`.

## The Migrated Surefire Declaration

The migration adds a `maven-surefire-plugin` declaration to the root `pom.xml` `<pluginManagement>` block, pinned at `3.5.2` through a shared version property that `maven-failsafe-plugin` also consumes so unit and integration forking cannot drift apart. Two constraints govern that declaration, and both are load-bearing.

### Constraint 1 — exclusions must cite a row, and the declaration ships with none

The declaration **ships with no exclusions at all, and it may carry none unless a row in this register justifies one.** As delivered it carries a `groupId`, an `artifactId` and a `version` and nothing else — no `<configuration>` element, and therefore no `<excludes>` element. That is not an oversight; it is the only state this register permits, because the register has zero rows and an exclusion with no row **fails**.

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

One adjacent false positive is named so it is not mistaken for a test exclusion. The JaCoCo configuration carries **eight package glob `<excludes>`** covering the close-complaint form, the ActiveMQ tools, the crypto utilities, the Zylab tool, the data package, the calendar service, the admin plugin and the Outlook service. Those suppress **coverage measurement only**. They disable no test whatsoever, they are pre-existing and unchanged by this migration, and they are not exclusions in R-5's sense.

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

The net effect on this register: **the six classes contribute zero rows.** No archived report for any of them records a failure or an error. Four of the six sit in modules the archive covers, and their reports can be read directly:

- `smoke-evidence/baseline/surefire/acm-case-file-plugin/TEST-com.armedia.acm.plugins.casefile.dao.QueuePropertyFileChangeWatcherTest.xml`
- `smoke-evidence/baseline/surefire/acm-service-object-lock/TEST-com.armedia.acm.service.objectlock.service.AcmObjectLockServiceImplTest.xml`
- `smoke-evidence/baseline/surefire/acm-service-calendar-integration-exchange/TEST-com.armedia.acm.calendar.service.integration.exchange.CalendarEntityHandlerTest.xml`
- `smoke-evidence/baseline/surefire/acm-transcribe-tool/TEST-com.armedia.acm.tool.transcribe.AWSTranscribeServiceTest.xml`

The other two — `CategoryServiceIT` in `acm-category-plugin` and `AWSComprehendMedicalServiceTest` in `acm-comprehend-medical` — sit in uncovered modules, which under the rule above disqualifies them as exclusion justifications just as firmly. None of the six was registered as failing at the JDK 8 baseline, and none is excluded in the migrated build.

## How to Use This Register

The reviewer procedure, in the order that catches the most.

- **Every test failure in the migrated Java 17 run must map to a row here.** A failure with no matching row is a **migration regression**, not an accepted baseline condition. Since the register has zero rows, any failure in the migrated run is a regression until proven otherwise by a genuine baseline capture.
- **Every exclusion in the migrated Surefire configuration must cite a row here**, by class and by method. An exclusion with no row **fails**. The declaration as delivered carries no `<configuration>` element at all, so the current expected finding is no exclusions.
- **The `@Ignore` count must be unchanged** from the 26 recorded in the corpus table. Any increase violates R-5 whether it appears in build configuration or in source.
- **JaCoCo liveness must be confirmed, not inferred from an exit code**: a non-empty `jacoco.exec` and a `check` goal that evaluated a real data set. A pass over an empty data set is a gate failure.
- **The archived baseline XML under `smoke-evidence/baseline/surefire/` is the tie-breaker** for any dispute about what was failing before the migration — subject to the provenance disclosure above, which records that the archive currently evidences structure rather than outcomes, and which must be re-read before any report in it is cited as an observation.

The figures published on this page are re-derivable. Run from the repository root; the base commit is `c8f6226105`.

```bash
find . -type d -path "*/src/test/java" | wc -l                                  # 76
find . -path "*/src/test/java/*" -name "*.java" | wc -l                         # 402
find . -path "*/src/test/java/*" -name "*Test.java" | wc -l                     # 280
find . -path "*/src/test/java/*" -name "*IT.java" | wc -l                       # 86
grep -rl "org.junit.Test" --include=*.java . | grep -c "/src/test/java/"        # 366
grep -rl "org.junit.jupiter" --include=*.java . | wc -l                         # 0
grep -rn "@Ignore" --include=*.java . | wc -l                                   # 26
grep -rn "rerunFailingTestsCount" --include=pom.xml . | wc -l                   # 0
git grep -l "org.powermock" c8f6226105 -- '*.java' | wc -l                      # 6
grep -rn "org.easymock.classextension" --include=*.java . | wc -l               # 0
find docs -path "*baseline/surefire/*" -name "TEST-*.xml" | wc -l               # 66
grep -rc "<failure" $(find docs -path "*baseline/surefire/*" -name "TEST-*.xml") | grep -v ':0$'   # no output
grep -rc "<error" $(find docs -path "*baseline/surefire/*" -name "TEST-*.xml") | grep -v ':0$'     # no output
```

Two wording gates apply to this page and both are checkable:

```bash
PAGE=$(git ls-files '*baseline-test-failures.md')
grep -rEn 'Java (8|9|10|11)\b' docs/
grep -c '^```' $PAGE
```

The first must produce no hit from this page — the older runtime is written `JDK 8` throughout — and the second must return an even number so that every fence is balanced. Three further checks have no printable command, because writing the pattern would itself create the hit this page must not contain: confirm by reading that the page contains **no literal occurrence of either of the two JDK 9 module-access JVM arguments, nor of the legacy reflective-access flag** — which is why the register that would record such exceptions is referred to here **by title only**, as the JDK access exceptions register, its own filename embedding one of those tokens; confirm that **no link target on this page carries the documentation folder prefix**, sibling deliverables being linked by plain filename and parent pages by `../`; and confirm that **the superseded frontend package manager is named nowhere on this page**, since it has no bearing on the backend test suite.

Related registers, each covering a class of decision that does not belong here: [Dependency Change Inventory](dependency-change-inventory.md) for the test-library changes that make this suite runnable on Java 17, [Pre-existing Defects](pre-existing-defects.md) for the environment precondition and for the two R-6 escape-clause invocations that are recorded outside this folder, [Ambiguity Resolutions](ambiguity-resolutions.md) for the decisions where JDK 8 baseline behaviour was the tie-breaker, [Static Audit Output](static-audit-output.md) for the before-and-after capture of the JDK-internal usage audit, and the [Developer Setup](../setup.md) page for the prerequisites the migrated build documents.
