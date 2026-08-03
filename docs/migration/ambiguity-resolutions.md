# Ambiguity Resolutions

This page records every decision in the runtime migration onto Java 17 and Node 20 LTS where the requirements admitted more than one defensible answer, and where **the platform's observed behaviour at the base commit on JDK 8 was used as the tie-breaker**. It exists because a rule demands it as a deliverable, not because any feature description mentions it.

Each entry states the ambiguity, the options weighed, the option chosen, and — the part that makes the page worth reading — **what was rejected and why**. A register that recorded only the chosen option would be a changelog. The rejected options are the evidence that a choice was actually made.

## Rules Provenance

Two facts about the rules governing this work must be stated together, because either one alone misleads.

- **There is no on-disk user rules document for this project.** The project's rules facility reports, verbatim, *"No user rules provided."*
- **Rules are nonetheless present and binding.** The requirements embed an explicit, numbered RULES block of seven rules, plus seven transformation rules that are the operational form of the PRESERVE and EXCLUDE lists. Fourteen constraints apply.

The identifiers `R-1` through `R-7` and `R-T1` through `R-T7` are the **migration plan's own navigational convention**, not quoted titles.

One rule governs this page:

> **R-7 — Baseline behaviour is the tie-breaker.** The application's observed behaviour at the base commit on JDK 8 is the tie-breaker for any ambiguity, and each resolution must be documented.

R-7 is the most consequential of the fourteen, and not because it is invoked most often. It is consequential because in almost every entry below it selected the **less obvious** option — the untidier dependency, the uglier version specifier, the extra exclusion. A rule that only ever confirmed the instinctive answer would not be doing any work.

## Index

| # | Ambiguity | Resolution | Options rejected |
|---|---|---|---|
| 1 | Which activation-framework artifact | The reference implementation | The API-only jar |
| 2 | How to resolve the duplicated JPA API | Advance the javax-named pin and exclude its twin | Three alternatives |
| 3 | How to pin frontend Git dependencies | Exact commit SHAs | Semver-qualified ranges; tags |
| 4 | What to do about the removed script engine | Document the latent defect | Add a standalone engine |
| 5 | How to represent the internal JNDI context factory | The class name as a string, supplied from configuration | A module-opening argument; a hardcoded literal |
| 6 | How to prove the frontend is unchanged | Byte-comparison of five artefacts | Trusting exit codes; writing new tests |
| 7 | How to widen the Base64 decoder cast | To the input-stream supertype | A narrower rewrite |
| 8 | Which duplicate JAXB implementation to keep | The explicitly declared reference implementation | Leaving nearest-wins to decide |
| 9 | Whether a suite present on only one side is an evidence hole | Only a *lost* counterpart is | Treating additions as holes |
| 10 | Whether to apply the measured Drools remedy | Neither remedy; document both | Applying either |
| 11 | Which frontend packages may be removed for security | Only provably dead ones, under R-4 | Upgrading vulnerable packages |

## 1 — The Activation Framework Artifact

**The ambiguity.** JEP 320 removed the JavaBeans Activation Framework from the JDK, so it must be reinstated as an ordinary dependency. Two artifacts satisfy the same `javax.activation` API, and the coordinates give no hint that the choice matters.

**What baseline behaviour decided it.** Reading both jars showed they are not equivalent. The API-only artifact carries 31 classes and **lacks** `META-INF/mimetypes.default` and `META-INF/mailcap.default`. The reference implementation is a strict superset at 42 classes and ships **both** resources. Five of the six activation-consuming files use MIME-type mapping, which reads exactly those resources.

**Chosen:** the reference implementation.

**Rejected:** the API-only jar. It is the tidier dependency — smaller, and "API only" reads like the disciplined choice. It would have compiled cleanly, deployed cleanly, and then **silently resolved MIME types differently** from the JDK 8 baseline. This is the entry that best illustrates why R-7 exists: nothing short of comparing observed behaviour would have caught it, because both options satisfy the compiler and neither produces an error.

## 2 — The Duplicated JPA API

**The ambiguity.** The EclipseLink advance pulls a JPA API artifact whose coordinates carry the forbidden namespace, while the reactor separately pins a javax-named one. Reading the coordinates suggests a namespace violation; reading the jars tells a different story.

**What baseline behaviour decided it.** The two artifacts' class sets are **identical** — 213 entries, 209 under `javax/persistence/`, symmetric difference zero. The differently-named artifact is the same javax API republished. Separately, the javax-named `2.2.1` adds exactly two annotation-container types over the previously pinned version, and **neither appears anywhere in the source**, so the version advance cannot alter any mapping that generates DDL.

**Chosen:** advance the javax-named pin and exclude the twin at the managed entry that introduces it, leaving exactly one API jar on the classpath — javax-named *and* javax-contented.

**Rejected, all three:**

- *Keep the API at its old version and exclude the twin.* The migrated provider implements the newer API level, so this starves it of classes it expects.
- *Drop the explicit pin and accept the transitive.* This leaves a jar whose coordinates carry the forbidden namespace in the resolved graph, which the EXCLUDE directive prohibits regardless of internal package names. R-T1's requirement to inspect jar *contents* cuts both ways: contents do not launder coordinates.
- *Keep both.* 213 duplicate class entries resolved by nearest-wins, which is order-sensitive and therefore not reproducible. A classpath whose behaviour depends on resolution order is not a preserved baseline.

## 3 — Pinning the Frontend Git Dependencies

**The ambiguity.** The manifest expresses its Git dependencies in a form the previous package manager accepted and the new one cannot parse at all. Some rewrite is unavoidable; which rewrite is the question.

**What baseline behaviour decided it.** The idiomatic rewrite — a semver-qualified range — was tested and found unsafe in two independent ways. An open range **re-resolves to whatever tag exists today**, so two checkouts of the same commit can install different library versions; and at least one repository fails the resolution outright with a package-metadata cache error. Exact commit SHAs resolve correctly and are immutable. The previous lockfile recorded a SHA for 76 of 77 entries across 75 distinct packages, with **no package carrying conflicting SHAs**, so the mapping was unambiguous.

**Chosen:** exact commit SHAs, mined from the previous lockfile before it was deleted. Measured against the migrated manifest: at the base commit all 76 Git specifications were unpinned semver ranges and **none** named a commit; now **all 76 name an exact 40-character commit and none is semver-qualified.**

They appear in two forms, which is a sub-decision worth stating because a reader counting one form will come up short. Fifty-eight use the short `owner/repo#<sha>` form. The remaining eighteen use a codeload tarball URL carrying the same commit in its path — the one form that records an HTTPS resolved URL in the lockfile, adopted where it was needed to keep restore working without credentials. Both are exact-commit pins; neither is a range. Every dependency **key** is preserved unchanged, which is what the asset-layout contract requires: the asset resolver names 65 distinct installed packages by literal path, and all 65 are present.

**Rejected:** semver-qualified ranges, and tags. Both are more readable, and both reintroduce the exact mechanism by which a "no behaviour change" refactor silently changes behaviour. A version range is not a pin.

One consequence deserves its own note, because deduplicating would have looked like an improvement. One library appears twice — once as a direct Git dependency at a specific tag, once as a transitive registry range resolving to a much later major version. The direct dependency owns the top-level installation slot, so the literal asset path that references it continues to resolve to the same version it did before, and that path carries an in-file comment warning that the newer minified build is broken. Understanding the duplication was necessary in order *not* to remove it.

## 4 — The Removed Script Engine

**The ambiguity.** Two files request a script engine the JDK removed. They compile cleanly and fail at run time. Restoring the capability and documenting the defect are both defensible.

**What baseline behaviour decided it.** Both call sites are **provably unreachable** — the bean declarations are inside comment regions, the only active declaration names a different class, and nothing anywhere references the engine by name. So the observed baseline behaviour of this code is *that it never runs*.

**Chosen:** document the latent defect. Registered in [Pre-existing Defects](pre-existing-defects.md).

**Rejected:** adding a standalone engine dependency. It would introduce a library to the production dependency graph solely to support code that cannot execute — a change with no compatibility justification, which R-1 forbids — and it would convert dead code into live code, which is a behaviour *change* measured against the baseline. The instinct that a broken thing should be repaired points the wrong way here: repairing it is the deviation.

## 5 — Representing the Internal JNDI Context Factory

**The ambiguity.** The Active Directory context source referred to an internal JNDI factory class as a class literal, which does not compile on Java 17 because the owning module does not export the package. Several routes restore compilation.

**What baseline behaviour decided it.** The runtime restriction is weaker than the compile-time one: resolving the same class **by name** at run time succeeds, and JNDI matches the initial context factory by exact class name anyway — so passing the name is not an approximation of the old behaviour, it is what the old code ultimately did. Two further facts constrained the shape of the fix. No `ActiveDirectoryContextSource` bean definition exists in this repository at all — they live in an external configuration repository this repository cannot edit — so a fix that relied on new wiring would leave every existing deployment broken. And the JDK-internal usage audit is a **literal text search over `src/main/java` only**, so the value cannot live in a `.java` file even as a string.

**Chosen:** the field holds the class name as a `String`, defaulted from a properties resource on the classpath that also supplies the connection-pooling flag key. The same resource is exposed as a bean so a definition that wants to override either value wires it from one place rather than repeating a literal. A definition that sets neither property behaves exactly as it did on JDK 8.

**Rejected:**

- *A launch-configuration argument exporting the package.* Prohibited by R-T3, and it would not have worked anyway: the audit is textual, so the literal would still be present and the gate would still fail. The rule and the gate independently foreclose the same shortcut. See [JDK Access Exceptions](add-opens-exceptions.md).
- *Keeping the value as a literal in the class.* Fails the textual audit for the same reason.
- *Deriving the factory name from the LDAP framework's own accessor.* Tested: it raises an error on Java 17. The value has to come from configuration.

The pooling flag was recovered differently, and the distinction is worth recording because it is the one place where nothing had to be externalised: the LDAP framework exposes that property key as a compile-time constant, which is inlined at compile time and therefore leaves no forbidden text in the class file *or* the source.

## 6 — Proving the Frontend Is Unchanged

**The ambiguity.** The frontend declares two test frameworks and contains **zero specification files**. With no behavioural tests, what constitutes proof that the pipeline still does the same thing?

**What baseline behaviour decided it.** Whether byte-comparison is even *valid* had to be established before it could be relied on, because a pipeline with any nondeterminism would make it meaningless. Three properties were confirmed: cache busting is content-hash based with no timestamp, banner or date injection; minification runs with identifier mangling disabled, removing the main source of benign drift; and concatenation order derives from frozen asset globs, so preserving every dependency key fixes the order.

**Chosen:** byte-comparison of the five build artefacts against a baseline captured before any edit.

**Rejected:** trusting exit codes, which `grunt.option('force', true)` makes worthless — a broken build exits zero, and two registered defects are masked by exactly that mechanism. Also rejected: writing new specification files. New tests would establish what the code does *now*, which is not the question; only a comparison against the prior state answers it.

One caveat is scoped rather than hidden: source-map generation embeds file paths, so the comparison build must run from the same relative path or the map differs while the bundles do not.

## 7 — Widening the Base64 Decoder Cast

**The ambiguity.** A vendor Base64 decoder-stream type had to go. The narrowest possible replacement and the natural supertype are both available.

**What baseline behaviour decided it.** The value's only use was as the argument to a byte-stream reader on the very next line, and that reader already accepts the input-stream supertype — which the vendor decoder already extends. The supertype is therefore not a widening for convenience; it is the type the consumer always wanted.

**Chosen:** widen to `java.io.InputStream`.

**The asymmetry is disclosed rather than buried,** because R-7 requires it: widening a cast is not perfectly symmetric, and a path that previously threw a cast exception on unexpected content will now proceed instead. **No previously-successful path changes**, which is the property behaviour preservation actually requires. Recording that distinction was the resolution; pretending the change was exactly neutral would have been easier and false. Full anchors in [Static Audit Output](static-audit-output.md).

## 8 — Which Duplicate JAXB Implementation Survives

**The ambiguity.** The reactor carried three JAXB implementation artifacts at once: an explicitly declared reference implementation and two arriving transitively through unrelated dependency chains. Any of them can serve the API, and whichever wins is decided by resolution order.

**What baseline behaviour decided it.** The transitive arrivals were shown to be safely removable rather than assumed to be. One is entirely covered by the declared implementation's own class graph. The other's nine additional classes are a bytecode-injection optimiser that the declared version deliberately dropped, and the class that would use it does not reference them. The consuming module has no direct references to either. A real marshal-and-unmarshal round trip on the single-implementation classpath succeeds on Java 17 and resolves to the expected provider. Separately, and decisively for provider choice: the full deployed classpath shape — including the JPA provider's own competing JAXB implementation — resolves to the reference implementation and produces identical XML.

**Chosen:** exclude both transitive implementations, leaving exactly one provider registration.

**Rejected:** leaving nearest-wins resolution to decide. It happens to select the right provider today, which is exactly the problem — the outcome depends on declaration order rather than on anything stated, so a future unrelated dependency change could silently alter generated XML. Also rejected: adding a provider-selection properties file, which would be a behavioural change dressed as a safety measure, and which the round-trip evidence showed is unnecessary.

## 9 — Whether a One-Sided Suite Is an Evidence Hole

**The ambiguity.** The cross-run comparison requires the two archived test-report sets to correspond. When a suite appears on only one side, is that a hole?

**What baseline behaviour decided it.** The asymmetry is not symmetric, and the base commit is what makes that concrete. A suite present only at baseline has **lost** its counterpart: something that used to run either stopped running or stopped being archived, and its behaviour can no longer be compared. A suite present only on the migrated side **did not exist at the base commit**, so it cannot have a counterpart, and no action could give it one.

**Chosen:** a lost counterpart makes the capture incomplete and fails the run; an addition is counted and listed by name. There are currently zero of the former and four of the latter.

**Rejected:** treating any one-sided suite as a hole. It is the simpler rule and it is wrong: it makes every newly added test an evidence gap, which would penalise precisely the tests a review most wants added — three of the four additions here exist because a review finding asked for them. Also rejected: ignoring one-sided suites entirely, which is how 62 baseline suites came to have no counterpart without anything saying so. Details in [Baseline Test Failures](baseline-test-failures.md).

## 10 — Whether to Apply the Measured Drools Remedy

**The ambiguity.** Rule compilation fails on Java 17, silently disabling every decision table. Two remedies were executed and both work. Applying one would turn 85 failing test methods green.

**What baseline behaviour decided it.** The baseline is the reason *not* to apply either. The subsystem in question computes generated object numbers, queue-routing decisions and participant privilege flags, and the migration's promise about all three is that they are **identical**. A configuration change to the rule dialect alters how the rules generated from all 39 decision tables are compiled; nineteen test methods passing is not evidence that 39 production tables evaluate the same way, and the evidence run had no deployed stack against which to establish it. A module-opening argument is prohibited outright, and upgrading the dependency is closed by an explicit scope exclusion.

**Chosen:** apply neither. Document both remedies with their measurements, name the constraint that forecloses each, and state plainly that the four applicable constraints cannot all be satisfied at once.

**Rejected:** applying the dialect change to obtain a green suite. This is the single most tempting decision in the change set — it is one property, it needs no new dependency, and it converts a red suite to green. It is rejected because a green suite bought with an unvalidated semantic change to the subsystem under preservation is exactly the outcome this register exists to prevent, and because the remedy would still be a change nobody had measured against the 39 tables that matter. Also rejected: excluding the failing tests, which the constraint on test exclusions forbids since none of them fails at baseline.

## 11 — Which Frontend Packages May Be Removed for Security

**The ambiguity.** The committed lockfile carried a large advisory count. Reducing it is desirable; the obvious route is upgrading the vulnerable packages.

**What baseline behaviour decided it.** Upgrading is closed on two independent grounds: R-1 forbids a dependency change without a specific Java 17 or Node 20 compatibility reason, and the build artefacts must be byte-identical, which an upgraded library will not generally leave them. What *is* available is removal of packages that are provably never loaded — and the test of "provably" is behavioural: the removal must leave all five artefacts byte-identical, which was verified rather than assumed.

**Chosen:** remove only packages proven dead, justified under **R-4** (which forbids vendored dead packages) rather than under R-1, and verify byte-identity afterwards. Five qualified; the advisory count fell substantially and the installed package count roughly halved, with all five artefacts byte-identical.

**Rejected:** upgrading vulnerable packages to reduce the count, which trades a rule violation and an unverifiable artefact difference for a better-looking number. The residual advisories are recorded as risk-accepted exceptions with their reasons in [Frontend Dependency Security](frontend-dependency-security.md) rather than being made to disappear.

## How to Use This Register

- **Adding an entry.** State the ambiguity, the options, the baseline observation that broke the tie, and the rejected options with reasons. An entry with no rejected options is not a resolution — it is a note.
- **Revisiting an entry.** The baseline observation is the load-bearing part. If it is wrong, the resolution may be wrong; if it is right, a later preference does not override it.
- **Interpreting a choice that looks untidy.** Several of these deliberately chose the less elegant option — the larger jar, the 40-character version specifier, the extra exclusion. Elegance was not the criterion, and tidying one of them would be a behaviour change with no compatibility justification.
- **When a remedy exists and was not applied.** Entries 4 and 10 are both of this kind, and both record the remedy in enough detail that nobody has to rediscover it. That is the intended handover: the decision is documented as open, not closed.

Related registers: [Dependency Change Inventory](dependency-change-inventory.md), [Pre-existing Defects](pre-existing-defects.md), [Baseline Test Failures](baseline-test-failures.md), [Static Audit Output](static-audit-output.md), [JDK Access Exceptions](add-opens-exceptions.md) and [Frontend Dependency Security](frontend-dependency-security.md).
