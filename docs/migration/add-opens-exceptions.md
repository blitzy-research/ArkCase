# JDK Access Exceptions

This page is the register of exceptions to the prohibition on JDK-internal access in **production launch configuration**, for the runtime migration that moves ArkCase from its JDK 8 and Node 6-8 era foundation onto Java 17 and Node 20 LTS. It exists because a rule demands it as a deliverable, not because any feature description mentions it.

**The register of applied exceptions is empty. The migrated production launch configuration requires none, and carries none.**

That positive statement is the deliverable. A register that reports "none" is materially different from a register that was never produced, which is why this page exists at all rather than being omitted as trivially short.

It is not, however, the *whole* truth about this migration, and the difference matters enough to state on the first screen: the change set found one place where a pinned third-party dependency genuinely does require an encapsulated JDK package to be opened before it will work on Java 17. That requirement is **not applied**, so it is not an exception in the sense this register counts. It is recorded in full below, under its own heading, because a register that reported "none required" while a known requirement sat undisclosed elsewhere would be technically accurate and substantively misleading.

## Rules Provenance

Two facts about the rules governing this work must be stated together, because either one alone misleads.

- **There is no on-disk user rules document for this project.** The project's rules facility reports, verbatim, *"No user rules provided."* There is consequently no external full-text source to defer to for the rules cited below.
- **Rules are nonetheless present and binding.** The requirements embed an explicit, numbered RULES block of seven rules that govern this work in full, plus seven transformation rules that are the operational form of the PRESERVE and EXCLUDE lists. Fourteen constraints apply.

The identifiers `R-1` through `R-7` and `R-T1` through `R-T7`, and the descriptive labels attached to them, are the **migration plan's own navigational convention**. They are not quoted titles. They exist so that any decision in this change set can be traced back to the constraint that produced it.

Two constraints bind this page directly, and they are not equally strict — which turns out to be the crux of the one open question on it.

> **R-2 — No JDK-internal access in production launch configuration.** Production launch configuration must not rely on arguments that open or export otherwise-encapsulated JDK packages to the unnamed module, **except where a pinned third-party dependency documentedly requires it**, and each such exception must be documented.

> **R-T3 — Fix the library, do not open the module.** Where a dependency fails under strong encapsulation, the resolution is to upgrade or replace that dependency. Adding such an argument to production launch configuration **is prohibited**; the JDK-internal call sites are rewritten to supported APIs instead.

R-2 carries an exception clause. R-T3 does not. Both are in force.

### A note on wording, so its absence is not read as vagueness

The two JVM arguments in question are **described throughout this folder rather than written out literally**. Every page here observes that convention, and this page observes it too even though its own filename names one of them.

The reason is practical rather than stylistic. The completion criteria for this migration require that the production launch configuration contain no such argument, and the cheapest way to check that is to search the launch configuration and the pages that document it for the argument's text. A page that spelled the flag out in prose would satisfy that search and report a violation that does not exist. Describing the arguments keeps the check meaningful. The prohibitions are reproduced above at full strength, as prohibitions and not preferences.

## The Launch Configuration Under Audit

The audited artefact is the production `JAVA_OPTS` block published in the repository `README.md`, duplicated in [Developer Setup](../setup.md). The two copies are kept consistent deliberately; a launch configuration documented in two places that disagree is worse than one documented nowhere.

Its complete content, characterised rather than reproduced: IPv4 stack preference, a fixed `GMT` user timezone, four TLS keystore and truststore properties, an active Spring profile, the configuration-server property file location, and heap minimum and maximum. Plus a `CATALINA_OPTS` addition for the Tomcat native library path and a `CATALINA_PID` location.

| Property of the launch configuration | Before the migration | After the migration |
|---|---|---|
| Arguments opening or exporting an encapsulated JDK package | none | **none** |
| Arguments naming a JDK-internal package | none | **none** |
| `-XX:+CMSClassUnloadingEnabled` | present in CI, absent here | removed from CI; the JVM refuses to start with it from JDK 14 onward |
| Anything else added by this change set | — | nothing |

The change set therefore does not *reduce* a set of exceptions from some number to zero. The set was empty before and is empty after, and the migration's task was to keep it that way while moving to a runtime whose module boundaries are enforced.

## Why No Exception Was Needed

Three findings, each established by inspection or execution rather than by assumption, account for the emptiness. They are given because "none needed" is a claim about the whole codebase, and a claim that broad should show its working.

**Every strong-encapsulation failure encountered anywhere in this migration was inside a *test* library.** Two were found. EasyMock `4.1` and `4.3` both fail identically on Java 17 with an inaccessible-object error raised from EasyMock's own class proxy factory, because `java.lang` is not open to the unnamed module; EasyMock `5.6.0` succeeds. PowerMock `2.0.9` fails with an inaccessible-object error on a core JDK method, and `2.0.9` is the project's final release, so there is nothing to upgrade to and it was removed. Both were resolved the way R-T3 prescribes — by fixing the library — and neither touches production launch configuration, because a test library is not on the production launch path at all.

**ArkCase's own reflective code only ever targets ArkCase classes.** Every `setAccessible(true)` call site in the codebase was examined; all of them operate on the application's own types. None reaches into a JDK package, so strong encapsulation has nothing of the application's to refuse.

**ArkCase installs no `SecurityManager`,** and no load-time weaving is configured anywhere — no `aop.xml`, no load-time-weaver declaration, no Java agent in the launch configuration. EclipseLink's dynamic weaving is explicitly disabled in the data-source configuration. The two mechanisms that most often force a module to be opened in an application of this vintage are therefore both absent, and their absence is a pre-existing property of this configuration rather than something the migration arranged.

One near-miss is worth recording, because it is the kind of case that produces an unnecessary exception. `ActiveDirectoryAbstractContextSource` referred to an internal JNDI context-factory class as a class literal, which **does not compile** on Java 17 — the package is declared in `java.naming`, which does not export it. Adding an export argument would have made it compile, and would have been an exception on this register forever. The runtime restriction turns out to be weaker than the compile-time one: resolving the same class *by name* at run time succeeds. So the field became the class name as a string, supplied from configuration, and JNDI resolves it exactly as before. No argument was needed, and the register stayed empty. The reasoning is recorded as an R-7 decision in [Ambiguity Resolutions](ambiguity-resolutions.md); the call sites are itemised in [Static Audit Output](static-audit-output.md).

## Known Requirement Not Applied — Drools Rule Compilation

This section is the reason this page is longer than one line. It records a genuine, measured requirement for JDK-internal access that this change set **does not satisfy**, so that the empty register above cannot be mistaken for an absence of the problem.

**What was measured.** On Java 17, `org.drools.core.rule.builder.dialect.asm.ClassGenerator` obtains `ClassLoader.defineClass` reflectively and calls `setAccessible(true)` **in its static initialiser**. Under strong encapsulation that initialiser cannot complete, so rule compilation fails for every decision table. Opening `java.lang` to the unnamed module as a fork argument makes the affected tests pass, which is what establishes the reflective call as the entire cause rather than a symptom of something else. The full diagnosis, the affected test inventory, and the alternative remedy are in [Baseline Test Failures](baseline-test-failures.md) under *The Migrated Run*.

**Why it is not on the register.** Four constraints apply to it simultaneously, and they cannot all be satisfied:

| Constraint | What it forecloses |
|---|---|
| R-T3, and the completion criterion that the launch configuration carry no such argument | Adding the argument to production launch configuration |
| The scope section names Drools `7.34.0.Final` **explicitly out of scope for version change** | Upgrading the dependency, which is R-T3's own preferred remedy |
| The PRESERVE list and two smoke flows require identical generated numbers and identical queue-routing decisions | Accepting silently disabled decision tables |
| The authoritative in-scope file list excludes the module that would have to change | Fixing it in the rule-manager code |

R-2's exception clause is the one door that is arguably open: Drools is a pinned third-party dependency that does documentedly require the package to be opened, which is the case that clause was written for. It was **not** walked through, for two reasons. R-T3 is stricter and admits no exception, and the completion criteria state the requirement as an absolute rather than as a default. And a measured, configuration-only alternative exists — setting the default rule dialect to MVEL cleared the failure in every module probed, with no dependency change and no JDK-internal access at all — which means the argument is not the only way forward and therefore not a necessary exception.

That alternative is **also not applied**, and for a reason that belongs on this page rather than being left implicit: it changes how the rules generated from all 39 decision tables are compiled, in the one subsystem whose behaviour this migration promises is identical. Nineteen test methods turning green is not evidence that 39 production decision tables evaluate the same way, and the evidence run had no deployed stack against which to establish that. Applying an unvalidated semantic change to buy a green suite is the trade this register exists to prevent.

**The honest position, therefore:** the launch configuration carries no exception; a real requirement for one exists and is disclosed here with its measurements; a rule-compliant alternative to it has been identified and measured; and neither has been applied by this change set, because both need a decision and a validation that lie outside it. Whoever takes that decision should record its outcome here — as a row in the empty table above if the argument is adopted, with the dependency named and its requirement documented as R-2 demands, or in [Ambiguity Resolutions](ambiguity-resolutions.md) if the dialect route is taken instead.

## How to Use This Register

- **Adding an exception.** R-2 permits one only where a *pinned third-party dependency* documentedly requires it. Name the dependency, cite where the requirement is documented, and record which package is opened and to what. A row without all four is not an exception, it is a workaround.
- **Before adding one, exhaust R-T3.** Upgrade the library, replace it, or rewrite the call site. Every strong-encapsulation failure in this migration was resolved that way, and the one that was not was blocked by an explicit scope exclusion rather than by the absence of a remedy.
- **Do not add one for test scope and record it here.** This register covers *production launch configuration*. A fork argument used by a test runner is not on it, is not covered by R-2's clause, and must not be introduced to make a suite green — the constraint on test exclusions in [Baseline Test Failures](baseline-test-failures.md) applies for the same reason.
- **Re-deriving the emptiness.** Read the `JAVA_OPTS` block in the repository `README.md` and in [Developer Setup](../setup.md) and confirm neither contains an argument that opens or exports a JDK package. That is the whole check; it is deliberately something a reviewer can complete in a minute without building anything.

Related registers: [Dependency Change Inventory](dependency-change-inventory.md) for the library upgrades and removals that resolved the encapsulation failures instead of opening modules, [Static Audit Output](static-audit-output.md) for the before-and-after capture of JDK-internal usage in source, [Baseline Test Failures](baseline-test-failures.md) for the Drools diagnosis and the measured remedies, [Ambiguity Resolutions](ambiguity-resolutions.md) for the decisions where JDK 8 baseline behaviour was the tie-breaker, and [Pre-existing Defects](pre-existing-defects.md) for the defects documented rather than fixed.
