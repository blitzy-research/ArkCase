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
| 5a | Whether to reinstate the old `Class`-typed accessor and mutator | Keep the `String` pair the plan directs | A `Class` setter overload; a renamed accessor |
| 6 | How to prove the frontend is unchanged | Byte-comparison of five artefacts | Trusting exit codes; writing new tests |
| 6a | Which baseline the artefacts are compared against | Also capture the historical Node runtime; publish both, accept the residual | Reporting only the same-runtime comparison; changing a minifier |
| 7 | How to widen the Base64 decoder cast | To the input-stream supertype | A narrower rewrite |
| 8 | Which duplicate JAXB implementation to keep | The explicitly declared reference implementation | Leaving nearest-wins to decide |
| 9 | Whether a suite present on only one side is an evidence hole | Only a *lost* counterpart is | Treating additions as holes |
| 10 | Whether to advance a library the plan holds frozen (the rule engine) | Advance to the bisected floor; raise for owner ratification | Standing still; opening the module; a dialect change |
| 11 | Whether to advance a library the plan does not list (Jackson) | Advance to the bisected floor; raise for owner ratification | Reverting; opening the module; patching the tests |
| 12 | Which frontend packages may be removed for security | Only provably dead ones, under R-4 | Upgrading vulnerable packages |

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

### 5a — Whether to reinstate the old `Class`-typed accessor and mutator

**The ambiguity.** Changing the field's type also changed the JVM descriptors of two public methods: `getContextFactory` went from `()Ljava/lang/Class;` to `()Ljava/lang/String;`, and `setContextFactory` from `(Ljava/lang/Class;)V` to `(Ljava/lang/String;)V`. A caller compiled against the old descriptors would fail to link. The question is whether to reinstate them, or a bridge for them, on top of the new pair.

**What baseline behaviour decided it.** Three measurements, in the order they matter.

- **The plan specifies the new pair.** The transformation mapping directs this exact change — the field type from `Class` to `String` *with matching accessor and mutator* — and the requirement list names it as the single security-adjacent edit, describing it as a representation change that JNDI consumes identically. The plan is the frozen contract, so a resolution that contradicts it is not available here regardless of its merits.
- **The old accessor cannot be reinstated at all.** Java permits no two methods differing only in return type, so `()Ljava/lang/Class;` and `()Ljava/lang/String;` cannot coexist. Restoring the old getter therefore means deleting the one the plan directs. Half of this finding is unsatisfiable by construction, whichever way the other half is decided.
- **Nothing in the deployed artifact calls either method.** Every class file in the assembled WAR — all 636 library jars and the web application's own classes — was scanned for references to the two method names. The only ArkCase class that mentions them is the declaring class itself. The eight other hits are unrelated third-party types that happen to declare same-named methods of their own: Rhino's `ContextFactory`, Shiro's LDAP realm, Tomcat's `JNDIRealm`, Batik's Rhino interpreter, and `spring-ldap`'s own `AbstractContextSource`. That last one is worth naming explicitly, because it *does* declare a `Class`-typed pair — but `ActiveDirectoryAbstractContextSource` implements `BaseLdapPathContextSource` and `InitializingBean` and does **not** extend it, so no interface or superclass contract requires the old shape. The property is reached from configuration, by name, as a string.

**Chosen:** keep the `String` accessor and mutator, and decline to reinstate the old descriptors. The finding is recorded here rather than closed silently, because a declined finding that leaves no trace is indistinguishable from one that was missed.

**Rejected, with the reason stated rather than asserted:** *adding `setContextFactory(Class<?>)` as an overload*, which would restore the mutator descriptor while leaving the plan-directed one in place. This was probed rather than dismissed: with both setters present, the JavaBeans `Introspector` and Spring's `BeanWrapper` both resolve the property to the `String` write method — so the overload would not have broken configuration on this runtime. It is rejected on two grounds. It buys back **half** a binary contract that no caller in the deployed artifact uses, since the accessor half is unrestorable. And the mechanism it relies on is the `Introspector`'s tie-breaking between overloaded write methods, which is a resolution rule rather than a guarantee — accepting a subtle, environment-dependent resolution risk on the property that selects the LDAP provider, in the one subsystem whose security outcomes must be preserved, in exchange for a contract nobody is holding, is the wrong side of that trade. Also rejected: *a differently-named `Class`-returning accessor*, which is not a binary bridge at all — a caller compiled against `getContextFactory` is not helped by a method with another name.

## 6 — Proving the Frontend Is Unchanged

**The ambiguity.** The frontend declares two test frameworks and contains **zero specification files**. With no behavioural tests, what constitutes proof that the pipeline still does the same thing?

**What baseline behaviour decided it.** Whether byte-comparison is even *valid* had to be established before it could be relied on, because a pipeline with any nondeterminism would make it meaningless. Three properties were confirmed: cache busting is content-hash based with no timestamp, banner or date injection; minification runs with identifier mangling disabled, removing the main source of benign drift; and concatenation order derives from frozen asset globs, so preserving every dependency key fixes the order.

**Chosen:** byte-comparison of the five build artefacts against a baseline captured before any edit.

**Rejected:** trusting exit codes, which `grunt.option('force', true)` makes worthless — a broken build exits zero, and two registered defects are masked by exactly that mechanism. Also rejected: writing new specification files. New tests would establish what the code does *now*, which is not the question; only a comparison against the prior state answers it.

One caveat is scoped rather than hidden: source-map generation embeds file paths, so the comparison build must run from the same relative path or the map differs while the bundles do not.

### 6a — Which baseline the artefacts are compared against, and what the historical runtime actually produced

**The ambiguity.** "Compared against a baseline" has two readings, and they are not the same claim. A baseline built from the base-commit manifest **on the migrated runtime** isolates the package-manager change. A baseline built **on the historical runtime** additionally covers the runtime move, which is the migration's headline change. An earlier revision of this change set captured only the first and said so; a reviewer reasonably asked for the second.

**What baseline behaviour decided it.** The second capture was performed rather than argued about: Node v8.17.0 and yarn 1.22.22 were installed, the base-commit tree was extracted and built with the exact install command the base-commit runtime wiring used, and the output was compared artefact by artefact. **Three of the five are byte-identical** — the concatenated bundle, the vendor bundle and the rewritten entry document. **Two differ**, and both are minifier output: the minified script by 2 bytes, the minified stylesheet by 789. The cause was isolated rather than guessed: the minifier versions are identical on both sides, and their input is byte-identical, so the difference comes from the JavaScript engine the minifier itself runs on. For the script it is one escaped forward slash inside a regular-expression character class, and normalising that escape makes the two 2 MB bundles compare equal — the two patterns match the same strings. For the stylesheet it is `clean-css` grouping the same declarations into different rule blocks, with no declaration found on one side and missing on the other.

**Chosen:** capture it, publish both digest sets, characterise both differences to the byte, and record the residual as an **accepted deviation** — stating plainly that a strict reading of "five artefacts byte-identical to a build on the original runtime" is not met, and that what the criterion exists to detect, a change in what the application loads, was not found. The evidence is in [`smoke-evidence/historical-frontend/comparison.txt`](smoke-evidence/historical-frontend/comparison.txt) with the capture script committed beside it.

**Rejected:**

- *Reporting only the same-runtime comparison.* It is the more flattering number and it was already published; leaving it as the whole story is what the reviewer objected to, correctly.
- *Changing either minifier to close the gap.* Both install and run on Node 20 at the versions the lockfile pins, so neither has a Node 20 incompatibility, and R-1 forbids a dependency change without one. It would also make things worse rather than better: a different minifier version changes far more than two bytes and 789 bytes of grouping.
- *Presenting the two differences as byte-identity by widening what "identical" means.* The differences are real. They are reported as differences, with their extent measured, and the burden of judging them is left with the reader rather than absorbed by the wording.

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

## 10 — Whether to Advance a Library the Plan Holds Frozen: the Rule Engine

**The ambiguity.** The rule engine cannot fire a rule at all on Java 17. `ClassGenerator`, the ASM consequence-invoker generator the decision-table path reaches through `KnowledgeBuilderImpl.addPackageFromDecisionTable`, asks in its static initialiser for reflective access to the protected four-argument `ClassLoader.defineClass`; `java.base` does not open `java.lang` to the unnamed module, and the initialiser dies. All 39 live decision tables are on that path, so object numbering and queue routing are affected in the deployed application, not merely in tests. The plan's scope section holds this library frozen, on the stated ground that with zero `.drl` files the rule-compilation path is absent — a ground that execution contradicts, because compiling a spreadsheet enters exactly that path. Four constraints then pull in different directions: **R-2** forbids opening the module in the launch configuration, **R-T3** requires the library to be fixed instead, **R-5** forbids leaving a non-baseline failure in place, and the plan's own scope section says do not change the version.

**What baseline behaviour decided it.** At the base commit on JDK 8 the tables compile and fire. The migration's promise is that they still do, and that each one still produces the same decision. That promise cannot be kept by any option that leaves the engine unable to compile a table, which eliminates standing still. It also cannot be kept by a remedy nobody has measured against the tables themselves — which is what made an earlier revision of this register decline the change: the measurement did not exist yet. It exists now. Every one of the 39 tables was compiled under both versions and the **generated rule text is byte-identical, table for table** — 39 digests, 39 files, zero differences — so the version change provably cannot alter a numbering sequence or a routing decision. That measurement is what broke the tie, and it is recorded per table at [`smoke-evidence/dependency-parity/decision-table-parity.txt`](smoke-evidence/dependency-parity/decision-table-parity.txt) with the harness committed beside it.

**Chosen:** advance the family to `7.49.0.Final`, the release the bisection identifies as the earliest that compiles *and* fires a real decision table on JDK 17, and stay on the 7.x line so the `javax` namespace and the rule semantics are untouched. **The plan is not amended, and this register does not claim authority to amend it.** The change is recorded as a deviation from the plan's scope section, raised for **owner ratification**, with the contradiction between the plan's stated ground and the observed behaviour named explicitly rather than smoothed over. If the owner declines to ratify it, the honest consequence must be stated with it: the reactor then carries a rule engine that cannot fire a rule on the target runtime, and no other remedy is available inside the rules.

**Rejected:** three options. *Standing still*, which keeps the plan's scope section literally intact and leaves the deployed application unable to evaluate a single decision table on Java 17 — the letter of one scope sentence at the cost of the migration's central objective. *Opening `java.lang` in the launch configuration*, which is prohibited outright by R-2 and would put the first entry into a register delivered empty. *Changing the rule dialect configuration*, an earlier candidate remedy that converts the suite to green by altering how rules generated from all 39 tables are compiled: it is rejected because it is a semantic change to the subsystem under preservation, and because the version advance is now the better-evidenced option — byte-identical rule text is a stronger guarantee than a passing suite.

## 11 — Whether to Advance a Library the Plan Does Not List: Jackson

**The ambiguity.** Jackson 2.10.3 cannot build a bean deserializer for any type carrying a `java.time` property on Java 17: `ClassUtil.checkAndFixAccess` calls `setAccessible` on `LocalDate`'s private fields and `java.base` does not open `java.time` to the unnamed module. Five controller tests in `acm-service-users` fail on it, and two production paths — the FOIA and privacy portal submission services, which read a request object carrying two `LocalDateTime` properties through a plain `new ObjectMapper()` — fail with an unchecked error that escapes the `catch (IOException)` around them. The library serialises every REST response, and the plan's dependency inventory does not list it at all, so it is neither authorised nor explicitly frozen.

**What baseline behaviour decided it.** The probe was run three ways — JDK 8 with 2.10.3, which *is* the baseline; JDK 17 with 2.10.3, which is what reverting produces; and JDK 17 with 2.12.7, which is what ships — and the baseline settled it decisively. The migrated library reproduces the baseline on every REST-response path (same registered module set, same written bytes, same read result) and on the plain-mapper read path exactly, including the **exception type** on the two payload shapes that already failed at baseline. The reverted library reproduces none of them: on Java 17, 2.10.3 fails for *every* payload, even one that never mentions the `java.time` property, because the failure happens while the deserializer is being built. Response shape was compared separately across **2,663 project classes**: zero serializer differences, zero property-name-set differences, nine classes with an adjacent-property order difference. Both records are in [`smoke-evidence/dependency-parity/`](smoke-evidence/dependency-parity/).

**Chosen:** advance to `2.12.7`, the earliest release that does not reflect into those types at all, and record it as an unlisted change **raised for owner ratification** on the same terms as entry 10. One asymmetry is disclosed rather than buried, because R-7 requires it: a plain mapper *writing* a `java.time`-bearing type produced a bean-shaped rendering at baseline and now raises a clean `InvalidDefinitionException`. Every plain-mapper write site in production was checked against that and none carries such a property, so the asymmetry is not reachable from production code.

**Rejected:** *reverting to 2.10.3*, which the review that raised this finding proposed and which the baseline comparison refutes — it does not restore baseline behaviour, it removes it, and it breaks portal request submission on the target runtime. *Opening `java.time` in the launch configuration*, prohibited by R-2. *Registering the JSR-310 module inside the five failing tests*, which would turn the suite green while leaving the two production paths broken, and which treats a library defect as a test defect — the inverse of R-T3.

## 12 — Which Frontend Packages May Be Removed for Security

**The ambiguity.** The committed lockfile carried a large advisory count. Reducing it is desirable; the obvious route is upgrading the vulnerable packages.

**What baseline behaviour decided it.** Upgrading is closed on two independent grounds: R-1 forbids a dependency change without a specific Java 17 or Node 20 compatibility reason, and the build artefacts must be byte-identical, which an upgraded library will not generally leave them. What *is* available is removal of packages that are provably never loaded — and the test of "provably" is behavioural: the removal must leave all five artefacts byte-identical, which was verified rather than assumed.

**Chosen:** remove only packages proven dead, justified under **R-4** (which forbids vendored dead packages) rather than under R-1, and verify byte-identity afterwards. Five qualified; the advisory count fell substantially and the installed package count roughly halved, with all five artefacts byte-identical.

**Rejected:** upgrading vulnerable packages to reduce the count, which trades a rule violation and an unverifiable artefact difference for a better-looking number. The residual advisories are recorded as risk-accepted exceptions with their reasons in [Frontend Dependency Security](frontend-dependency-security.md) rather than being made to disappear.

## How to Use This Register

- **Adding an entry.** State the ambiguity, the options, the baseline observation that broke the tie, and the rejected options with reasons. An entry with no rejected options is not a resolution — it is a note.
- **Revisiting an entry.** The baseline observation is the load-bearing part. If it is wrong, the resolution may be wrong; if it is right, a later preference does not override it.
- **Interpreting a choice that looks untidy.** Several of these deliberately chose the less elegant option — the larger jar, the 40-character version specifier, the extra exclusion. Elegance was not the criterion, and tidying one of them would be a behaviour change with no compatibility justification.
- **When a remedy exists and was not applied.** Entry 4 is of this kind, and it records the remedy in enough detail that nobody has to rediscover it. That is the intended handover: the decision is documented as open, not closed.
- **When a change the plan does not authorise was nevertheless made.** Entries 10 and 11 are both of this kind. Neither amends the plan, and neither claims the authority to: each states the constraint chain that leaves no other remedy, supplies the behavioural measurement that shows the change is inert, and is raised for owner ratification. If ratification is declined, the consequence recorded in the entry is what follows — not a quiet reversal.

Related registers: [Dependency Change Inventory](dependency-change-inventory.md), [Pre-existing Defects](pre-existing-defects.md), [Baseline Test Failures](baseline-test-failures.md), [Static Audit Output](static-audit-output.md), [JDK Access Exceptions](add-opens-exceptions.md) and [Frontend Dependency Security](frontend-dependency-security.md).
