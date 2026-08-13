# Dependency Change Inventory

Every dependency, plugin and toolchain version this migration moved, with the specific Java 17 or Node 20 reason that forced it — and every candidate change that was examined and **withdrawn**, with the negative finding that withdrew it. The migration took the ArkCase backend from Java 8 to Java 17 (LTS) and the frontend build from Node 6/8-era tooling to Node 20 LTS with npm 10, without changing observable behaviour.

## How to read this page

The inventory is complete in **both directions**, and that is deliberate. A one-directional list of changes cannot be audited: it shows what moved but not what was left alone on purpose, so it cannot distinguish disciplined minimalism from an incomplete sweep. Here, both halves are present.

- Take any version in the migrated root `pom.xml` or in the frontend `package.json`, find it below, and you will find the failure that forced it — quoted, not paraphrased.
- Take any version that did **not** move and you will find why it was examined and what observation left it in place.
- Where a reason is a reproduced failure, the actual error text is quoted. A generic "compatibility" claim is not a reason and does not appear.

Every figure on this page was measured against the checkout rather than transcribed from a plan, and every target version was re-confirmed in its registry while this page was written. Where measurement disagreed with an earlier figure, the measured value is published and the earlier one is withdrawn by name — see [Figures this page withdraws](#figures-this-page-withdraws) and [Honest disclosures](#honest-disclosures).

## Governing rules

A note on where the rules come from, because it affects how they are cited here. The `review_rules` facility reports **no user rules provided** for this project, and there is no on-disk rules document. The binding rules arrive instead through the project prompt's own rules block, and they are referred to throughout this documentation set by the stable identifiers **R-1** through **R-7**. Their full verbatim text lives in that prompt — the migration plan names the `review_prompt` facility as the way to read it in full, precisely because `review_rules` holds nothing — and this page summarises what each rule requires of *it* and cites the rule by identifier, without reproducing rule text.

| Rule | Scope | What it requires of this page |
| --- | --- | --- |
| **R-1** | All manifests and POMs | **This page is the deliverable.** Every version change carries a specific Java 17 or Node 20 reason recorded as artifact, old version, new version, reason. A change without such a reason would be out of scope, so the withdrawals are recorded too — they are the evidence that the discipline was applied rather than asserted |
| **R-3** | Build configuration | The compiler-plugin row must show why the bump is not cosmetic: it is what allows compiling at release 17 **without** a release-8 escape hatch. The legacy `source`/`target`/`compilerVersion` trio is deleted, not overridden |
| **R-4** | Frontend toolchain | The frontend half must keep **compatibility fixes** and **dead-code cleanup** separate, because they answer different halves of the rule. It must also record the CI image pin as an infrastructure precondition and the `engines` declaration as the mechanism that refuses an old runtime |
| **R-6** | All source | Pre-existing defects are documented, not fixed. This page fixes nothing and repairs no manifest defect it found; it points at [Known issues](known-issues.md) instead |
| **R-7** | All behavioural decisions | Every withdrawal is a resolution decided against observed base-commit behaviour. The shared observation is stated once for the group; the fuller reasoning belongs to [Behavioural decisions](behavioral-decisions.md) |

## Measured baseline

The base commit is `c8f6226105`, the parent of the first migration commit. Its root POM still declares `<java.version>1.8</java.version>`, expanded into `source`, `target` and `compilerVersion` in two separate plugin blocks, so it is a genuine Java 8 tree and not a Java 17 tree pinned backwards.

| Measurement | Value | How it was taken |
| --- | --- | --- |
| Reactor modules | **142** | Transitive closure of the root POM's `<modules>`, including the root aggregator |
| `pom.xml` files on disk | **145** | Three sit outside the reactor: the `src/main/resources/build/pom.xml` of `acm-foia` and `acm-privacy`, and `arkcase/src/main/webapp/build/pom.xml` |
| Modules carrying test sources | **79** | Directories with at least one `.java` file under `src/test/java` |
| Main Java sources | **3,055** | 3,054 at the base commit plus the one class this migration adds |
| Test Java sources | **407** | 402 at the base commit plus the five test classes this migration adds to cover its own source edits |
| POMs declaring compiler settings | **1** | The root POM. No module overrides `source`, `target` or `release` |
| POMs declaring a test runner | **1** surefire, **3** failsafe | Surefire is undeclared at the base commit; failsafe is declared in the root POM and in two module profiles |
| `acm-jmeter` | not built | Present on disk as JMeter assets, has no `pom.xml`, and is absent from `<modules>` |

Toolchain versions actually used, all installed outside the checkout: **JDK 17.0.20** (Eclipse Temurin) as the target runtime, **JDK 1.8.0_502** as the baseline runtime, **Maven 3.8.7** on both sides, **Node v20.20.2** and **npm 10.8.2**. An earlier capture taken while the migration was being designed used JDK 17.0.19 and JDK 1.8.0_492 and reached the same conclusions, so no result here depends on the patch level of either JDK; both pairs may be encountered across this documentation set.

### Figures this page withdraws

Three figures that circulated during planning did not survive measurement. They are named rather than quietly replaced, because a reader who has seen them needs to know which value is authoritative.

| Withdrawn figure | Measured value | Why the earlier figure was wrong |
| --- | --- | --- |
| "274 reactor modules" | **142** | The reactor is the transitive closure of `<modules>`, and the repository holds only 145 POMs in total, so 274 was never reachable. 142 is what the closure yields, and it agrees with the module count the recorded full-reactor runs report |
| "142 test-bearing modules" | **79** | 142 is the size of the whole reactor, not the count of modules with test sources. Most reactor entries are aggregators or carry main sources only |
| "773 tests, 0/0/0" | **918 tests, 0 failures, 0 errors, 21 skipped** | Superseded, and the ownership of test totals belongs to [Baseline test failures](baseline-test-failures.md), which measured them from surefire's own XML reports. The totals moved because tests were **added**, never because any test was disabled; the 21 skips are pre-existing `@Ignore` annotations in unchanged baseline sources |

## Track A — Java 8 to Java 17

Four dependencies were added, three dependency versions moved, and four build plugins moved. Nine candidate changes were formally withdrawn. The only other movement in the Maven dependency surface is two test-scope declarations in two module POMs, both carrying their version by inheritance — recorded in full below, so that this inventory accounts for every POM the change set touches and not only the root.

### Why the EE artifacts are declared once

The four reinstated EE artifacts are declared **once**, in the root POM's global `<dependencies>` block, and inherited by every module. That is a design decision worth stating before the table, because it is the reason a cross-cutting compile-path problem became a four-line diff in one file.

The root POM already carried a global `<dependencies>` block holding exactly one entry — `log4j-core`, with an in-POM comment recording that it is needed there because of the log4j plugin processor configured in the compiler plugin. That is established repository precedent for using inheritance to satisfy a compile-path need that spans modules, and reusing it converted what would otherwise have been **21 module-POM edits into four lines in one file**. It also makes the change auditable: the whole EE reinstatement is visible in a single-file diff.

The mechanism was proven rather than assumed. `acm-tool-integrations/acm-object-converter` is the first Java module in the reactor and the migration's very first failure — five of its sources stop compiling on JDK 17 with:

```text
package javax.xml.bind does not exist
```

With the inherited block in place and no edit to that module's POM at all, the same module compiles clean, and the build log line records the new contract in force:

```text
Compiling 13 source files with javac [debug deprecation release 17]
```

### The four reinstated EE artifacts

JEP 320 removed six Java EE modules from the JDK in Java 11. Measured usage in this codebase shows that only three of the six matter, and the fourth artifact below is the runtime provider the first one needs.

| Coordinate | Version | Reason (reproduced) |
| --- | --- | --- |
| `javax.xml.bind:jaxb-api` | 2.3.1 | JEP 320 removed the JAXB API from the JDK. **137** import lines across **84** files in **21** modules stop compiling without it — the first failure of the migration, in `acm-tool-integrations/acm-object-converter`, five files reporting `package javax.xml.bind does not exist`. Deliberately `javax`-namespaced: this is a compatibility shim, so not one import statement changes |
| `org.glassfish.jaxb:jaxb-runtime` | 2.3.9 | The API alone is insufficient at runtime, because `JAXBContext`, `Marshaller` and `Unmarshaller` are all used and not only the annotations. The 2.3.x line is the **last that still exposes the `javax.xml.bind` packages** — confirmed in the registry, where 2.3.9 is the top of that line and the next generation moves to the EE 9 namespace. It also makes the JAXB runtime explicit where the OpenCMIS exclusion previously left it implicit |
| `javax.annotation:javax.annotation-api` | 1.3.2 | JEP 320 removed the annotation module; **4** files import `javax.annotation` types. 1.3.2 is the top of its line in the registry |
| `com.sun.activation:javax.activation` | 1.2.0 | JEP 320 removed the activation module; **8** import lines across **6** files. 1.2.0 is the top of its line in the registry |

Measured `javax.xml.bind` usage, by distinct type and frequency, so the scale of what the shim carries is on the record: `XmlElement` 56, `XmlTransient` 24, `XmlJavaTypeAdapter` 23, `XmlRootElement` 14, `Unmarshaller` 4, `XmlAdapter` 3, `XmlAccessorType` 3, `XmlAccessType` 3, `JAXBContext` 3, `JAXBElement` 2, `Marshaller` 1, `DatatypeConverter` 1.

> One footnote on the annotation artifact, because a text search invites the wrong conclusion. `Nullable`, imported by `acm-services/acm-service-users/.../model/ldap/MapperUtils.java`, does **not** come from `javax.annotation:javax.annotation-api`. It is a findbugs/jsr305 type and is satisfied separately by a dependency that was already present. Only four files consume the reinstated annotation module.

### Keeping the reinstated surface javax-only

`org.glassfish.jaxb:jaxb-runtime` 2.3.9 is declared with **three exclusions**, and they are part of the change set rather than incidental tidying. Its own dependencies would otherwise reintroduce a second, differently versioned copy of the same packages on every classpath in the reactor — a direct consequence of declaring the artifact by inheritance, which is what makes this worth recording here.

Read the table below as a list of **removals**. Each row names a coordinate the build takes *out* of the dependency graph; none of them is added anywhere, and no artifact outside the `javax` namespace enters the reactor through this migration.

| Excluded from `jaxb-runtime` | Why the exclusion is required |
| --- | --- |
| `jakarta.xml.bind:jakarta.xml.bind-api` | Declared at compile scope by 2.3.9. It still ships the `javax.xml.bind` packages, so without the exclusion **every** inherited classpath carried `javax/xml/bind` twice — 2.3.3 beside the 2.3.1 API declared above. Excluding it is provably safe, and the proof is a direct comparison of the two jars' entry lists: their `javax/xml/bind` class sets are **identical**, 110 classes in each, so every type the reactor compiles against is still present at runtime |
| `jakarta.activation:jakarta.activation-api` | Excluded at the same point so the alternate coordinate cannot re-enter through the activation implementation |
| `com.sun.activation:jakarta.activation` | Declared at runtime scope by 2.3.9 and itself pulling the API above; it duplicates `javax/activation/DataHandler`. Activation resolves instead to the explicit `com.sun.activation:javax.activation` 1.2.0 declared alongside |

Measured with `mvn dependency:tree` restricted to those coordinates across the whole reactor: with the exclusions in place, `jaxb-runtime` introduces neither artifact anywhere. The optional `stax-ex` and FastInfoset dependencies are not transitive and need no exclusion.

**The namespace point, stated plainly, because it is an explicit exclusion of this migration:** no artifact in the EE 9 namespace is added, and no import anywhere is rewritten to it. All 137 `javax.xml.bind` import lines, the 4 `javax.annotation` imports and the 8 `javax.activation` import lines are byte-identical to the base commit. The three exclusions above exist precisely to keep that surface single-namespaced; they are removals, not additions.

### JAX-WS: deliberately not reinstated

The migration specification names JAX-WS among the modules to reinstate. It is deliberately **omitted**, and the omission is recorded here rather than left implicit, because an unexplained gap against a written instruction is indistinguishable from an oversight.

Measured across the whole repository:

| Evidence sought | Found |
| --- | --- |
| `javax.xml.ws`, `javax.jws`, `javax.xml.soap` imports | **0** |
| `.wsdl` files | **0** |
| `@WebService` / `@WebMethod` annotations | **0** |
| Apache CXF dependency in any POM | **0** |
| A `wsimport` plugin binding | **0** |

There is no consumer. The full build and the full test suite are green with no JAX-WS artifact present, so adding one would be a dependency without a reason — which R-1 forbids. The omission is therefore a deliberate, documented deviation from the specification's wording, taken to comply with the specification's own rule.

### JAX-RPC is not a removed-module problem

Related and easy to conflate. `javax.xml.rpc.ServiceException` is imported by the billing service's `TouchNetAPIController` and `TouchNetService`. It is satisfied by the third-party `javax.xml:jaxrpc-api` 1.1, declared alongside `org.apache.axis:axis` 1.4, both already present at the base commit. JAX-RPC was **never** part of the JDK, so JEP 320 did not touch it and neither did this migration.

### The OpenCMIS runtime exclusions

The Alfresco/CMIS client excludes both `com.sun.xml.ws:jaxws-rt` and `com.sun.xml.bind:jaxb-impl`, in the root POM's `dependencyManagement` entry for `chemistry-opencmis-client-impl` and again on the same artifact in `acm-tool-integrations/acm-camel-context-manager/pom.xml`. On Java 8 those exclusions were harmless, because the JDK supplied both runtimes. On Java 17 the JDK supplies neither, so they had to be re-evaluated rather than inherited by habit.

**Resolution: the exclusions are retained verbatim, and the JAXB runtime is supplied explicitly instead.** Two pieces of evidence support it. ArkCase configures the **ATOMPUB** CMIS binding rather than the web-services binding, so no JAX-WS runtime is on the hot path; and the full test suite is green with the exclusions in place. Nothing about the CMIS client version moved — `chemistry` remains 1.1.0.

### The three dependency version changes

Each of these was applied **in isolation, with the build re-run**, before the next was applied. That sequencing is the reason each has an individually attributable failure rather than a correlated one: no reason below rests on "something in this group fixed it".

| Property | Old → New | The reproduced failure |
| --- | --- | --- |
| `easymock.version` | 4.1 → 4.3 | `IllegalArgumentException: Unsupported class file major version 61`, raised from `org.easymock.asm.ClassReader` through the CGLIB enhancer during mock creation. **The nuance that matters:** the failing reader is EasyMock's own **repackaged** ASM, so raising the top-level `asm.version` property does nothing for it — which is why that property is withdrawn below. Jar-level proof: the `Opcodes` class in easymock 4.1 stops at `V14`, while 4.3 carries `V15`, `V16` and `V17`. Registry-verified as the **last 4.x release ever published**, so it is simultaneously the minimal fix and the top of its line; a 5.x line exists but raises the language baseline and would be an unnecessary major bump |
| `spring.version` | 5.3.2 → 5.3.39 | `IllegalArgumentException: Name for argument of type [java.lang.String] not specified, and parameter name information not found in class file either`, in three MVC controller tests. spring-core 5.3.2's repackaged ASM stops at `V16`, so the parameter-name discoverer cannot parse a major-61 class file and silently yields no names. Registry-verified as the **latest 5.3.x**, which is also the generation the migration is required to stay inside |
| `spring.security.version` | 5.4.2 → 5.4.11 | Moves in lockstep with Spring 5.3.x, against which Spring Security 5.4.x is built. Registry-verified as the **latest 5.4.x**. Staying inside 5.4.x additionally preserves the `spring-security-5.4.xsd` namespace that eight configuration files in the external configuration repository reference — moving off the line would have forced a rewrite outside this checkout |

Two constraints bound this group. The Spring generation is **capped deliberately**: no Spring 6 and no Spring Boot, both explicit exclusions of the migration. And both Spring properties move only to the newest patch of the generation already in use, so neither is a feature upgrade.

### The source change the Spring bump forces

The Spring patch bump is **inseparable from a source edit**, and it is recorded here because a version-only reading of the change set would miss it.

Spring 5.3.5 added two methods to `ApplicationEventMulticaster`. `acm-web/src/main/java/com/armedia/acm/web/api/DistributiveEventMulticaster.java` is a hand-written implementation of that interface, so moving to 5.3.39 makes it stop compiling until it implements them. The two methods follow that class's own existing conventions rather than introducing new behaviour: the predicate-based listener removal delegates to both wrapped multicasters exactly as the existing single-listener removal does, and the listener-**bean** removal is a no-op exactly as its existing single-bean counterpart is, because this multicaster does not track listener bean names.

The coupling is **invisible on an incremental build**. Only a clean full-reactor build recompiles `acm-web`, which is why this surfaced late and why partial application of the change set has no meaningful green state.

### The four build-plugin changes

Tracked separately from dependencies because these are build tooling rather than runtime artifacts, and because two of the four reasons are not Java-language problems at all — one is a Maven-container incompatibility and one is a capability gap in a silently inherited default. Both attributions are spelled out rather than folded into "JDK 17 compatibility".

| Plugin | Old → New | Reason |
| --- | --- | --- |
| `maven-compiler-plugin` | 3.1 → 3.13.0 | 3.1 predates the `<release>` parameter, which requires 3.6 or newer. `<release>` is the only way to compile at release 17 without falling back on the forbidden `source`/`target` escape hatch, so this bump is what makes **R-3** satisfiable rather than cosmetic. 3.13.0 is comfortably past the capability floor; it is **not** claimed to be the newest 3.x, because 3.14.x and 3.15.x exist |
| `maven-war-plugin` | 3.0.0 → 3.5.1 | `Unable to load the mojo 'war' … due to an API incompatibility: ComponentLookupException` under Maven 3.8.7. The old plugin ships the pre-Eclipse Sisu generation — `sisu-inject-bean` 1.4.2 and `sisu-guice` 2.1.7-noaop — that modern Maven no longer provides. **Honest attribution:** this is a Maven-container incompatibility surfaced by the toolchain move, not a JDK 17 language problem. It is nonetheless unavoidable, because a JDK-17-capable Maven is a precondition of the migration, and it is why the documented Maven floor rises to 3.8+. Registry-verified as the newest release of the plugin |
| `maven-surefire-plugin` | undeclared, inheriting Maven's 2.12.4 default → 3.5.3 | 2.12.4 does not perform late `@{…}` property substitution, so the JaCoCo agent argument and the JDK 17 module-access directives cannot coexist — the fork dies with `Error: could not open '{argLine}'` followed by `The forked VM terminated without saying properly goodbye`. Under 3.5.3 the identical configuration passes. **Stated precisely:** 2.12.4 is **not** globally broken on JDK 17 — a plain JUnit 4 test runs fine under it — so the recorded reason is the specific late-substitution capability needed to combine coverage enforcement with a documented module-access exception, not a blanket incompatibility. The capability has existed since 2.17; 3.5.3 is the version this migration standardises on for both forked runners, and it replaces a silently inherited default with an explicit, auditable pin |
| `maven-failsafe-plugin` | 2.17 → `${surefire.version}` | The same late-substitution mechanism for integration tests, and one pin for both forked runners. Its `forkCount`, `reuseForks` and `threadCount` settings are preserved verbatim |

The failsafe change lands in **three POMs, not one**, and the two extra edits are the interesting part. `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` each hardcoded `2.17` inside a profile. A profile-local version **wins over the inherited declaration** whenever that profile activates, so leaving them would have kept a Java-8-era integration-test runner in the reactor and lost the root POM's late-substituted `argLine` — the JaCoCo agent argument together with the module-access directives — exactly in the modules where integration tests run. Both now inherit `${surefire.version}`, and no hardcoded `2.17` remains anywhere in the repository.

### The compiler contract

The compiler contract lands as a single inherited property: `maven.compiler.release=17` replaces `java.version=1.8`. Two properties of that change are what **R-3** actually turns on, and both were verified by enumeration rather than assumed:

- The `source`, `target` and `compilerVersion` trio is **deleted** — from the compiler plugin's default configuration *and* from its `log4j-plugin-processor` execution — leaving **no `${java.version}` reference anywhere** in any POM. Merely adding a `release` property would have left the older settings winning, so deletion is the operative act.
- **Exactly one** of the 145 POMs declares compiler settings, and **zero** declare `source`, `target`, `release` or `compilerVersion` at module level. There is no module-local override to police, and no place for a release-8 escape hatch to reappear unnoticed.

The executable evidence is a build-log difference: the baseline JDK 17 run emitted `bootstrap class path not set in conjunction with -source 8`, and after the change that warning is gone and javac reports `[debug deprecation release 17]`. A separate finding reinforces the rule — the escape hatch would not even have worked, because `javac --release 8` on a JDK 17 JVM still fails on the encapsulated JNDI package that the migration had to externalise. That analysis belongs to [Static audit](static-audit.md).

### Test-scope additions in two module POMs

Two module POMs gained test-scope dependencies. Both carry version and scope by inheritance from the root `dependencyManagement`, so neither introduces a version to this inventory — but R-1's scope is all manifests and POMs, so they are recorded.

| POM | Added | Why |
| --- | --- | --- |
| `acm-services/acm-service-convert-file/pom.xml` | `junit`, `org.easymock:easymock` | To unit-test `MimeMessageParser`'s inline-image path, whose stream cast was widened to `java.io.InputStream`. The test drives the parser with a `javax.mail.Part` yielding a plain `ByteArrayInputStream` — exactly what the widened cast must accept — and `Part` is an interface, so EasyMock supplies it |
| `acm-web/pom.xml` | `junit` | To unit-test the delegation contract of the two methods added to `DistributiveEventMulticaster` for the grown Spring interface surface |

No test **assertion** anywhere was modified, and no test source was edited: the five new test classes cover this migration's own source edits, and the 402 pre-existing test sources are untouched.

### The nine withdrawn Maven candidates

R-1 forbids a change without a reason. The shared observation that none of these needs one is that **the full reactor builds and the configured unit suite is green with every one of them untouched** — 142 modules, and 918 tests with zero failures and zero errors, as measured and reported by [Baseline test failures](baseline-test-failures.md). That observation is what makes each withdrawal an R-7 resolution against observed behaviour rather than a preference. Each is recorded with the reason it was examined, so nobody repeats the investigation.

| Artifact | Version held | Why it was examined, and why it was withdrawn |
| --- | --- | --- |
| `asm` | 5.0.3 | Static probing did confirm that 5.0.3 cannot read a major-61 class and that 9.1 is the first that can — so the candidate was real. But the standalone ASM was **never the failing reader** here: both failures came from the shaded copies inside EasyMock and Spring, which their own upgrades fix. Its sole reactor consumer, `acm-plugins/acm-extra-plugins/acm-personnel-security-plugin`, keeps its direct dependency and builds and tests clean. **Bump to 9.1 formally withdrawn** |
| `eclipselink-jpa` | 2.6.0 | Its shaded bytecode library is of the ASM-5 generation, so a JPA weaving failure was plausible; none materialised in the full suite. Leaving it also avoids a structural complication — from 2.7.x the EclipseLink ASM artifact is versioned independently, so one property could no longer drive both coordinates and a second property would have had to be introduced. **Bump to 2.7.16 formally withdrawn** |
| `aspectj` | 1.7.4 | spring-aspects 5.3.39 declares aspectjweaver 1.9.7, so a peer alignment was expected. No failure implicated AspectJ. **Bump to 1.9.7 formally withdrawn** |
| `mockito.core` | 3.7.7 | Examined because the whole mocking and bytecode stack was in play once EasyMock proved to be. No failure implicated it. **Bump to 4.11.0 formally withdrawn** |
| `powermock` | 2.0.9 | Registry-verified as the **newest PowerMock release that has ever existed**, so upgrading is impossible. It was made to work with test-scope JVM directives instead, attributed in [Module-access exceptions](add-opens-exceptions.md). Its **three** `cglib:cglib-nodep` exclusions — on `powermock-api-easymock`, `powermock-api-mockito2` and `powermock-module-junit4` — are preserved verbatim, because an in-POM comment records that an older cglib broke ArkCase's unit tests |
| `jacoco` | 0.8.7 | Examined because a coverage agent must instrument the new bytecode. The 0.8.7 agent was tested directly against a major-61 class on JDK 17: it instruments correctly, writes a valid execution file and behaves identically to 0.8.12. Its `check` goal still passes at the configured **2%** line-coverage floor, which is deliberately not raised opportunistically. **Bump withdrawn** |
| `javassist` | 3.18.2-GA | The version transitively declared by `org.reflections:reflections` 0.9.9. Tested directly: it reads and re-emits a major-61 class on JDK 17. **The evidence limit, recorded honestly:** Javassist reads and writes class-file versions numerically, so its named version constants stop at Java 11 in every release from 3.27 to 3.32 and yield no "Java 17" marker either way — which is precisely why this decision rests on the executed suite rather than on a constant |
| `junit` 4.13.1, `easymock-extension` 3.2, `ehcache` 2.6.9, `hazelcast` 3.11.2, `kryo` 5.0.0-RC4, `jackson` 2.10.3 | unchanged | All untouched. Kryo and Hazelcast were specifically examined as `sun.misc.Unsafe` dependents — 15 and 9 classes respectively reference it — because the audit target includes that package. `sun.misc.Unsafe` itself **remains accessible on JDK 17**, and no failure required moving either. Jackson is the one that drives a module-access directive instead of a version move; the behaviour-preserving reason is in [Behavioural decisions](behavioral-decisions.md) |
| `liquibase` 3.1.1, `bouncycastle` 1.54, `activiti` 5.15.1, `activemq` 5.13.2 | pinned | Pinned by in-POM constraints or by ArkCase policy: one in-POM comment forbids moving Liquibase past 3.1.1 until an upstream issue closes, and another records that Bouncy Castle 1.54 is required by OpenSAML 2.6.4, which would otherwise pull 1.46. Moving either would be a policy change, not a migration step |

One deliberate non-change is worth naming separately, because a text search would flag it. The duplicate `javax.servlet:javax.servlet-api` declaration in `acm-services/acm-service-authentication-token/pom.xml` — once at test scope, once at compile scope — is a Maven **warning**, not an error, and blocks no validation item. Under R-6 it is documented and **not fixed**; see [Known issues](known-issues.md).

## Track B — Node 6/8-era tooling to Node 20 LTS

The frontend project root is `acm-standard-applications/arkcase/src/main/webapp/resources`. It is **not relocated**: moving it would change entry points and asset layout and would break the WAR packaging that consumes `src/main/webapp/resources`.

The frontend's problem turned out to be **resolution semantics, not code**. Most of the manifest could not install on Node 20 because npm reads a dependency spec differently from the bower-era tool that wrote it — not because the packages are incompatible. Separating those two causes is what kept this change set small, and it is why `Gruntfile.js` needed no change at all.

### Totals and reconciliation

Two independent arithmetic checks are published, because the category counts are easy to get wrong and a single check cannot catch a compensating error. Both were computed from the committed `package.json`, not transcribed.

**108 dependencies → 86 dependencies plus 1 devDependency.**

| Check | Arithmetic | Holds |
| --- | --- | --- |
| Total | 108 − 22 removed − 1 (`grunt` moved out of `dependencies`) + 1 added (`sass`) = **86** | yes |
| Composition | 9 registry aliases + 53 GitHub-sourced specs + 24 plain registry packages = **86** | yes |
| Scoped side | 75 `@bower_components/*` − 14 unused removed = 61 → 9 aliases + 52 GitHub-sourced | yes |
| Unscoped side | 33 − 8 dead build packages − 1 (`grunt` moved) + 1 (`sass`) = 25 → 24 plain registry + `bootbox` | yes |

Two details make those numbers reconcile, and both are worth stating because they are the places a recount goes wrong:

- `bootbox` is written `makeusabrew/bootbox#semver:4.4.0`. It is the **only unscoped dependency expressed as a git spec**, which is why the unscoped side splits 24 + 1 rather than 25 + 0. Every one of the 75 scoped entries carried a `#` at the base commit.
- Of the **53 GitHub-sourced** dependencies, **52** are `#semver:` git specs and **1** — `@bower_components/multi-download` — is expressed instead as a pinned `codeload.github.com` tarball URL. Counted by spec syntax the split is 9 + 52 + 1 + 24; counted by origin it is 9 + 53 + 24. Both readings total 86, and the deploy-time install driver independently describes the same population as "53 locked dependencies are GitHub repositories".

### The six forced package changes

This is the **entire** build-package change set, and it is the compatibility half of **R-4**. Exactly **two** packages provably fail on Node 20 — one at install time, one at load time — and **four** more move only as forced peer consequences. Every peer claim below was re-read from the registry rather than inferred.

| Package | Old → New | Forced because |
| --- | --- | --- |
| `grunt-sass` | ~1.0.0 → ^4.1.0 | Cannot **install** on Node 20. grunt-sass 1.0.0 declares `node-sass ^3.0.0`, whose node-gyp 3.8.0 native rebuild fails outright on Node 20. **Framing matters:** this is an install-time failure, not a task failure — the sass task is commented out in the Gruntfile — but it blocks `npm ci`, which is a validation item, so the task being dormant is no defence. The 4.x line uses dart-sass and needs no native build; `node-sass` is absent from the committed lockfile entirely |
| `sass` | *(new)* → ~1.77.8 | The dart-sass peer that grunt-sass 4.x requires. **The tilde is load-bearing:** sass declares its file-watcher as `>=3.0.0 <4.0.0` up to and including 1.78.0, moves to `^4.0.0` at **1.79.0**, and the current release requires `^5.0.0`. A caret range would therefore let the resolved watcher drift out of the recorded tree, and `npm ci`'s strict validation then rejects it with a message of the form `lock file's chokidar@5.0.0 does not satisfy chokidar@3.6.0`. The tilde holds sass inside 1.77.x, the last minor whose watcher stays on the 3.x line that the committed lockfile records |
| `grunt` | ~0.4.5 and ^0.4.5 → ^1.6.3, **devDependencies only** | grunt-sass 4.x declares `peerDependencies: { "grunt": ">=1" }`. The move also de-duplicates the key, which appeared in **both** blocks at the base commit and — easy to miss — with **two different ranges**: `~0.4.5` in `dependencies` and `^0.4.5` in `devDependencies`. A build tool belongs in `devDependencies`, so that is the one that survives |
| `grunt-cli` | ~0.1.13 → ^1.5.0 | 0.1.13 cannot drive grunt 1.x |
| `grunt-ng-annotate` | ^1.0.1 → ^4.0.0 | 1.0.1 declares `peerDependencies: { "grunt": "~0.4.5" }`, which **pins** the 0.4 line and produces a hard `ERESOLVE` against grunt 1.6.3. 4.0.0 declares `{ "grunt": ">=0.4.5" }` — a floor rather than a pin. A peer audit across the whole plugin set confirmed this is the **only** plugin that pinned that line; every other declares a floor grunt 1.x satisfies |
| `grunt-sync` | ^0.6.2 → ^0.8.2 | Cannot **load** on Node 20: `Loading "sync.js" tasks…ERROR >> TypeError: Cannot read properties of undefined (reading 'length')` |

### The 22 removals

The removals answer **R-4's no-dead-packages requirement**, and they are split below because the two groups satisfy different halves of that rule. Presenting the second group as compatibility fixes would be false, since most of them still install perfectly well on Node 20.

**Fourteen unused asset packages** — cleanup. Each was verified to be referenced nowhere in the repository: `angular-slimscroll`, `angular-ui-event`, `angular-ui-indeterminate`, `angular-ui-mask`, `angular-ui-scroll`, `angular-ui-scrollpoint`, `angular-ui-uploader`, `angular-ui-utils`, `angular-ui-validate`, `font-awesome`, `html5shiv`, `pikaday`, `slimScroll`, `zeroclipboard`.

Two of the fourteen have a compatibility dimension as well: `angular-ui-utils` and `font-awesome` were bower-only repositories that npm cannot install at all, so they would have had to be resolved one way or another. `font-awesome` in particular was a stale duplicate of the icon font that is actually used, which reaches the tree through the `components-font-awesome` entry.

**Eight dead build packages** — cleanup, explicitly **not** compatibility fixes: `app-root-path`, `bower`, `grunt-karma`, `jasmine-core`, `karma`, `karma-jasmine`, `npm` (the package manager declared as a runtime dependency of the project it manages) and `template`.

The framing here is a requirement, not a nicety. The karma/jasmine cluster has **no karma target in the Gruntfile and no karma configuration file anywhere**, so it never ran; and both `karma` and `npm` **do** still install on Node 20. They are removed because they are dead, not because they broke. Lockfile proof that the removal is complete: none of the eight appears anywhere in `package-lock.json`, at any depth.

### The nine registry aliases

Each alias is written `"@bower_components/<name>": "npm:<real-package>@<version>"`. The mechanism matters more than the list: the alias **preserves the on-disk directory name**, so roughly **70** hardcoded `node_modules/@bower_components/<name>/…` asset paths in `config/env/all.js` keep resolving — plus two more outside the frontend tree, in `acm-tool-integrations/acm-websockets/.../spring-web-websockets.xml` and `acm-web/.../spring-security-config.xml`. What would otherwise have been a sweeping path refactor became **six** targeted line edits, and only where an npm package's internal layout differs from its bower counterpart.

The uniform reason for aliasing: these GitHub repositories publish **no `package.json` at the resolved tag**, so npm cannot build a manifest and the install fails with `ENOENT`.

| `@bower_components/` entry | Base-commit spec | Alias target | Note |
| --- | --- | --- | --- |
| `angular-translate` | `PascalPrecht/bower-angular-translate#~2.7.2` | `angular-translate@2.7.2` | asset path moves into `dist/` |
| `angular-translate-loader-partial` | `PascalPrecht/bower-angular-translate-loader-partial#~2.7.2` | `angular-translate-loader-partial@2.7.2` | path unchanged |
| `angular-ui-router` | `angular-ui/angular-ui-router-bower#~0.2.15` | `angular-ui-router@0.2.18` | 0.2.18 is the highest release satisfying the base-commit `~0.2.15` range, so this stays inside the declared range; path unchanged |
| `angular-ui-ace` | `angular-ui/ui-ace#~0.2.3` | `angular-ui-ace@0.2.3` | asset path moves to `src/ui-ace.js` — the npm package ships no minified build |
| `components-font-awesome` | `components/font-awesome#~4.4.0` | `font-awesome@4.4.0` | path unchanged |
| `ng-file-upload` | `danialfarid/angular-file-upload-bower#~7.0.17` | `ng-file-upload@7.0.17` | asset path moves into `dist/` |
| `ng-file-upload-shim` | `danialfarid/angular-file-upload-shim-bower#~7.0.17` | `ng-file-upload@7.0.17` | the shim bundles ship inside the same package; asset path moves into `dist/` |
| `ng-tags-input` | `mbenford/ngTagsInput-bower#~3.0.0` | `ng-tags-input@3.0.0` | both its CSS and JS asset paths move into `build/` |
| `ui-grid-draggable-rows` | `cdwv/ui-grid-draggable-rows#0.2.2` | `ui-grid-draggable-rows@0.3.3` | **the one forced version delta — see below** |

**The one forced version delta, recorded explicitly.** `ui-grid-draggable-rows` 0.2.2 **is not published**: the registry holds only 0.3.0, 0.3.1, 0.3.2 and 0.3.3, verified directly. The base-commit spec was an exact pin on a tag that has no registry counterpart, so *any* registry version is a forced minor bump; the manifest takes 0.3.3, the newest of the four published. This is the only version movement in the alias set, and it was forced rather than chosen.

### The 53 GitHub-sourced specs

Fifty-two of the 53 are git specs, and **47 of those 52 moved no version at all**: the transformation is `#<range>` → `#semver:<range>`, keeping the same repository and resolving to the same commit. Five needed the range restated as well, and the 53rd is expressed as a pinned tarball. All three groups are itemised below.

The root cause is semantic rather than environmental: npm treats everything after `#` as a **literal git committish**, while bower treated it as a **semver range** with v-prefix normalisation. That is why `git checkout 1.4.14` fails when the repository's tag is `v1.4.14`. npm's `semver:` committish prefix restores the original meaning exactly.

Proven equivalence, verified in the committed lockfile: the rewritten AngularJS spec resolves to commit `63133dadd7831af4226b7ceaf8be8b68a7e284d9` — the identical SHA the original bower-era install recorded.

Five of the 52 needed the **range restated as well**, because the shorthand the base commit used cannot resolve as written once it is interpreted as a range against the repository's actual tag set. These are recorded individually because "pure syntax rewrite" would not be true of them:

| Entry | Base-commit spec | Migrated spec |
| --- | --- | --- |
| `@bower_components/ace-builds` | `ajaxorg/ace-builds#^1` | `ajaxorg/ace-builds#semver:1.4.12` |
| `@bower_components/angular-dynamic-locale` | `lgalfaso/angular-dynamic-locale#^0.1.32` | `lgalfaso/angular-dynamic-locale#semver:0.1.37` |
| `@bower_components/angular-google-analytics` | `revolunet/angular-google-analytics#1.1.8` | `revolunet/angular-google-analytics#semver:<=1.1.8` |
| `@bower_components/angular-pdfjs-viewer` | `legalthings/angular-pdfjs-viewer#^0.8.1` | `legalthings/angular-pdfjs-viewer#semver:<=1.0.0` |
| `@bower_components/pdf.js-viewer` | `legalthings/pdf.js-viewer#^1.6.211` | `legalthings/pdf.js-viewer#semver:<=1.6.211` |

The 53rd GitHub-sourced dependency, `@bower_components/multi-download`, is expressed differently again: the base-commit spec `sindresorhus/multi-download#~2.0.0` became the direct tarball URL `https://codeload.github.com/sindresorhus/multi-download/tar.gz/af749d945646b8d737d5af587a60cb43c1640cb8`, pinning the exact commit rather than a range.

### The 19 deliberately unchanged

Nineteen frontend packages keep their base-commit versions, and fourteen of them were candidate upgrades that measurement withdrew individually — enumerated with their findings in [the next section](#the-withdrawn-frontend-upgrades). The other five were never candidates, because none of them has a build-plugin role: the path helper `homedir` and the four AngularJS asset packages `angular-aria`, `angular-bootstrap-contextmenu`, `angular-bootstrap-nav-tree` and `angular-moment-picker`.

The complete list, exactly as the manifest declares it:

`fs-extra` ~0.22.1, `glob` ~5.0.14, `lodash` ~3.10.1, `nunjucks` ^1.3.4, `load-grunt-tasks` ~3.2.0, `grunt-cache-bust` ^1.7.0, `grunt-concurrent` ^2.3.1, `grunt-contrib-clean` ^2.0.0, `grunt-contrib-concat` ^1.0.0, `grunt-contrib-csslint` ~0.4.0, `grunt-contrib-cssmin` ~0.12.3, `grunt-contrib-jshint` ~0.11.2, `grunt-contrib-uglify` ~0.9.1, `grunt-contrib-watch` ^1.0.0, `homedir` 0.6.0, `angular-aria` 1.5.7, `angular-bootstrap-contextmenu` ^1.2.0, `angular-bootstrap-nav-tree` ^0.2.1, `angular-moment-picker` 0.10.2.

### The withdrawn frontend upgrades

The measurement that withdrew them was a **per-plugin load probe**. Twelve grunt-ecosystem packages were probed individually on Node 20: **ten loaded cleanly** and were withdrawn as candidates, and the two that did not are exactly the two forced changes above. Installing the whole original dependency set **minus `grunt-sass`** also succeeded outright. That is the observation, and it is what reduced an intended eighteen upgrades to six.

Where R-4's no-dead-packages requirement and the specification's "replace a build package only if it cannot run on Node 20" pull in opposite directions, the tie was broken by measuring each package individually rather than by choosing a side.

The probe was re-run against the committed tree while this page was written, so the ten withdrawals are countable and each carries its own result. All twelve load without error on Node v20.20.2 under grunt 1.6.3, at these resolved versions:

| Probed package | Resolved | Disposition |
| --- | --- | --- |
| `load-grunt-tasks` | 3.2.0 | loads — **upgrade withdrawn**, held at ~3.2.0 |
| `grunt-cache-bust` | 1.7.0 | loads — **upgrade withdrawn**, held at ^1.7.0 |
| `grunt-concurrent` | 2.3.1 | loads — **upgrade withdrawn**, held at ^2.3.1 |
| `grunt-contrib-clean` | 2.0.0 | loads — **upgrade withdrawn**, held at ^2.0.0 |
| `grunt-contrib-concat` | 1.0.1 | loads — **upgrade withdrawn**, held at ^1.0.0 |
| `grunt-contrib-csslint` | 0.4.0 | loads — **upgrade withdrawn**, held at ~0.4.0 |
| `grunt-contrib-cssmin` | 0.12.3 | loads — **upgrade withdrawn**, held at ~0.12.3 |
| `grunt-contrib-jshint` | 0.11.3 | loads — **upgrade withdrawn**, held at ~0.11.2 |
| `grunt-contrib-uglify` | 0.9.2 | loads — **upgrade withdrawn**, held at ~0.9.1 |
| `grunt-contrib-watch` | 1.1.0 | loads — **upgrade withdrawn**, held at ^1.0.0 |
| `grunt-sass` | 4.1.0 | replaced — could not install at ~1.0.0; see the forced-change table |
| `grunt-sync` | 0.8.2 | replaced — could not load at ^0.6.2; see the forced-change table |

Four further packages were examined as Node-API risks rather than as plugins, and each produced a negative finding that withdrew it:

| Package | Held at | The negative finding that withdrew the upgrade |
| --- | --- | --- |
| `fs-extra` | ~0.22.1 | Its API is unchanged across the entire major-version jump for **all eight** methods the Gruntfile uses, so an upgrade would have been movement without benefit. It loads correctly on Node 20 |
| `lodash` | ~3.10.1 | The **four** functions the Gruntfile uses behave identically across its major jump. It loads correctly on Node 20 |
| `glob` | ~5.0.14 | The one behavioural difference a newer major introduces — a dropped trailing slash — is provably benign here, because every consumer either joins the path or copies through a filesystem call. Holding it keeps result ordering untouched rather than merely preserved |
| `nunjucks` | ^1.3.4 | Loads and renders correctly on Node 20. Holding it keeps the HTML-escaping contract untouched, which matters because the rendered `home.html` is a pipeline output |

**Reconciliation, stated rather than smoothed over.** The figure carried through planning was "twelve withdrawn frontend upgrades", and it names the **probe set** — the twelve packages listed in the first table. Counted as withdrawals, the enumerable total is **fourteen**: the ten probed packages that were cleared and held, plus the four Node-API packages above. The two remaining members of the probe set are not withdrawals at all; they are the two forced replacements. Both readings are consistent with the manifest, and the enumeration is what should be trusted, because it is countable.

**The fidelity argument for keeping the two minifiers is the strongest claim this migration makes**, so it is stated in full. Holding `grunt-contrib-uglify` at ~0.9.1 and `grunt-contrib-cssmin` at ~0.12.3 means the shipped minified bytes are produced by **the very tooling the Java 8 base commit declared** — the committed lockfile resolves them to `uglify-js` 2.8.29 and `clean-css` 3.4.28, the base-commit engines. Holding `nunjucks` and `glob` unchanged means the HTML-escaping and result-ordering behaviours are **untouched rather than merely preserved**. And that, in turn, is why `Gruntfile.js` needs no change: its diff against the base commit is **zero bytes**, verified, with the task graph and every output name intact.

### Manifest hygiene

Non-version manifest changes, recorded because two of them are what make the runtime move enforceable rather than documentary.

| Change | Base commit | Migrated | Why |
| --- | --- | --- | --- |
| `engines` | `{ "yarn": ">= 1.0.0" }` | `{ "node": ">=20.19.0 <21", "npm": ">=10" }` | Per **R-4**, this is the mechanism that **refuses** an old runtime instead of accommodating it. The yarn-only declaration is gone |
| `.npmrc` | absent | `engine-strict=true` | The other half of that mechanism. npm's default is `engine-strict=false`, under which an out-of-range runtime only prints an `EBADENGINE` warning and the install proceeds — which would let a Node 6/8-era or Node 22+ runtime still produce a bundle, exactly the outcome the migration exists to prevent. The file is also staged into the deploy-time temp folder, so the same gate applies to the deployed install path. `ignore-scripts` is deliberately **not** set here, because that would also suppress the `prebuild` hook |
| `scripts` | `{ }` — empty | `prebuild`, `build`, `lint`, `sync-dev`, `merge-config`, `test` | `npm run build` is a validation item and had **no target at all** before. Each script maps to a task that really exists: `build` → the Grunt `default` chain, `lint` → `lint`, `sync-dev` → `sync-dev`, `merge-config` → `updateModulesConfig`; `prebuild` writes the generated profiles module, and `test` runs the Node test runner over the `scripts/` helpers |
| `grunt` key | in **both** `dependencies` and `devDependencies` | one entry, in `devDependencies` | De-duplicated. The two occurrences also carried different ranges, so the duplication was not even self-consistent |

The install must be run with `--ignore-scripts`. One git-sourced asset repository's `prepare` script attempts to build an ancient native module, and npm runs `prepare` for git dependencies. Skipping it is the correct semantics rather than a workaround: these are prebuilt asset repositories with checked-in distribution directories, and their lifecycle scripts produce nothing the Grunt pipeline consumes.

### The committed lockfile

`package-lock.json` is **created** at **lockfileVersion 3**, and `yarn.lock` — 275,865 bytes — is **deleted**. The lockfile is the precondition for `npm ci`, which could not run at all before: there was no `package-lock.json` and no `npm-shrinkwrap.json` anywhere in the repository.

Measured composition of the committed lockfile: **436** `packages` entries — 1 root project plus 435 dependencies — of which **382** resolve to `registry.npmjs.org` tarballs, **52** to `git+ssh://git@github.com/…` coordinates and **1** to a `codeload.github.com` tarball. All 52 git coordinates are pinned to a **full 40-character commit SHA**; none is a floating branch or tag.

> The lockfile **must be produced by a real `npm install`**, never by `--package-lock-only`. That flag computes a dependency tree without fetching tarballs or running lifecycle scripts, and it therefore hides three of the failures this migration had to solve: the native lifecycle script, the last bower-only repository, and the peer conflict that only strict validation rejects. An earlier analysis using it concluded the lockfile problem was solved when it was not.

The yarn removal also reaches the **deploy path**, without which the migration would be cosmetic — the deployed application would still shell out to yarn at webapp startup:

- The install command in `spring-web-ark-angular-starter.xml` becomes `npm ci --ignore-scripts --engine-strict`, dropping the `--ignore-engines` flag that was **actively suppressing engine enforcement**.
- `.npmrc` joins the copy list so the temp-folder install enforces the same declared range.
- `AngularResourceCopier`'s prune whitelist now names `package-lock.json`, matching what the Spring configuration copies, and its yarn-specific field and Javadoc are renamed.

## CI and infrastructure

### The CI runner image

The pipeline declares exactly one runtime pin, and the jobs included from `.gitlab-ci-release.yml` declare no image of their own, so this single line governs every job.

| Setting | Old → New |
| --- | --- |
| `.gitlab-ci.yml` `image` | `arkcase-gitlab-ci:1.0.2` → `arkcase-gitlab-ci:2.0.0` |

This is an **infrastructure precondition, and it is external to this repository** — recorded here as an actionable dependency of the migration rather than as a warning. The image must supply **JDK 17, Node 20 LTS and npm 10**; its Dockerfile lives **outside this repository** and must be rebuilt before the pipeline can pass. The tag is a new major because the base runtime changed incompatibly: the reactor now compiles at release 17 and the frontend refuses a runtime outside `node >=20.19.0 <21`, so the superseded JDK 8 / Node 6-8 image cannot build this branch at all. Per **R-4**, this is the opposite of container-pinning to an old runtime — the pin moves forward with the code, and the `engines` declaration guarantees an old image fails loudly instead of silently producing a bundle.

### The removed JVM flag

`-XX:+CMSClassUnloadingEnabled` is removed from **four** places: once from `MAVEN_OPTS` in `.gitlab-ci.yml`, and three times from `MAVEN_OPTS` in `.gitlab-ci-release.yml`. Verified: four occurrences at the base commit, zero now.

JDK 14 removed the flag along with the CMS collector under JEP 363. This is a **hard blocker, not hygiene** — the Maven JVM could not even launch under JDK 17 with the previous configuration. Verified directly on both runtimes: JDK 8 starts normally with those exact flags; JDK 17 reports

```text
Unrecognized VM option 'CMSClassUnloadingEnabled'
Error: Could not create the Java Virtual Machine.
```

and exits 1; with the flag removed it starts normally. Nothing else in either CI file changed — the build invocations, the settings-file generation and the Maven extension side-load are untouched.

### Network reachability for `npm ci`

The second actionable precondition, stated in terms of what the committed lockfile actually contains rather than in general terms.

- **Outbound HTTPS to `registry.npmjs.org`** for the 382 registry tarballs, and **to `codeload.github.com`** for the GitHub-sourced dependencies. The second is easy to miss and is the more common cause of a failed build in a restricted network.
- Every GitHub coordinate in the lockfile is recorded as a `git+ssh://git@github.com/…` URL, because that is how npm normalises GitHub coordinates even when the spec is written with https. All 52 are pinned to a **full commit SHA**, which is what lets npm fetch them as HTTPS tarballs from codeload rather than cloning, so neither an SSH key nor a git client is required for `npm ci` itself.
- Git remains npm's **fallback**, and the fallback is provisioned rather than left to chance: the deploy-time driver injects `url.https://github.com/.insteadOf` rewrite rules for the four GitHub URL forms through the child process environment, so even a fallback clone needs no SSH credentials. A build image that prefers to satisfy the fallback directly can ship the same rewrite rules or an SSH deploy key.

## Verification method

Every version on this page was confirmed to exist before it was written down, and the limitation of the method is stated rather than glossed over.

**`web_search` returned no results in this environment on every attempt — including a re-test while this page was being written — and vendor-documentation fetches returned empty bodies throughout the migration. No claim on this page rests on a search result.** What was used instead:

| Technique | What it established |
| --- | --- |
| `maven-metadata.xml` fetched directly from `repo1.maven.org` | **12 of 12** Maven coordinates confirmed present, and the boundary facts read off the real published version list: easymock's 4.x line ends at 4.3; spring-core's 5.3.x line ends at 5.3.39; spring-security-core's 5.4.x line ends at 5.4.11; `jaxb-runtime`'s 2.3.x line ends at 2.3.9 and the next generation moves namespace; `maven-war-plugin` 3.5.1 is the newest release; `powermock-core` 2.0.9 has no successor |
| `npm view <pkg>@<version>` against `registry.npmjs.org` | **14 of 14** npm targets confirmed present, plus the peer and dependency metadata quoted in the forced-change table, plus the proof that `ui-grid-draggable-rows` publishes only 0.3.0 – 0.3.3 and the release at which sass's watcher range moves |
| Published-artifact constant-pool inspection | The shaded bytecode-reader ceilings inside EasyMock and Spring, established as facts rather than assumptions — this is what identified the *repackaged* readers as the failing ones and withdrew the standalone `asm` bump |
| Reading the committed manifests and lockfile | Every count, every old-and-new pair, and the lockfile composition on this page |
| Executable probes on the real toolchains | Compiler behaviour, agent instrumentation, plugin loading and JVM flag acceptance, each tested on JDK 17.0.20, JDK 1.8.0_502, Maven 3.8.7, Node v20.20.2 and npm 10.8.2 rather than predicted |

No floating `latest`, no placeholder and no unresolved version appears anywhere in this inventory.

## Anchor facts

| Fact | Value |
| --- | --- |
| Compiler contract | `maven.compiler.release=17`, declared once, inherited by all 145 POMs |
| Runtimes | Java 17 (LTS); Maven 3.8+; Node 20 LTS (`>=20.19.0 <21`); npm 10 |
| Validated on | JDK 17.0.20, JDK 1.8.0_502 baseline, Maven 3.8.7, Node v20.20.2, npm 10.8.2 |
| Reactor | 142 modules; 145 POMs; 79 modules with test sources |
| Java sources | 3,055 main; 407 test — 402 base-commit sources untouched, five added |
| Maven change set | 4 dependencies added; 3 dependency versions moved; 4 build plugins moved; 9 candidates withdrawn |
| Removed EE APIs reinstated | 137 `javax.xml.bind` imports in 84 files across 21 modules; 4 `javax.annotation`; 8 `javax.activation` in 6 files; zero JAX-WS-family imports |
| Frontend change set | 108 → 86 dependencies + 1 devDependency; 6 forced package changes; 22 removals; 9 aliases; 53 GitHub-sourced specs; 19 unchanged, of which 14 are enumerated withdrawals from a 12-package probe set plus 4 Node-API packages |
| Committed lockfile | `lockfileVersion` 3; 436 entries (382 registry, 52 git, 1 codeload); `yarn.lock` deleted (275,865 bytes) |
| Gruntfile | unchanged — zero-byte diff |
| Module-access directives | 8, all test-scope; **0** in production launch configuration |
| Static audit | 7 hits before, **0** after, in both main and test sources |
| CI | image `1.0.2` → `2.0.0`; 4 removals of a JVM flag JDK 14 deleted |

## Honest disclosures

Collected in one place so that none of them has to be discovered by cross-reading.

- **`web_search` returned nothing in this environment.** Every claim rests on registry metadata, artifact inspection, the committed files, or an executed probe.
- **`ui-grid-draggable-rows` moved versions, and the move was forced.** The base-commit pin 0.2.2 was never published. The registry's lowest available release is 0.3.0, not 0.3.3; the manifest takes 0.3.3, the newest of the four published. An earlier note that called 0.3.3 "the lowest available" is corrected here.
- **`angular-ui-router` reads as 0.2.18, not 0.2.15**, in the alias set. It is the highest release satisfying the base-commit `~0.2.15` range, so nothing moved outside the declared range.
- **Eight of the 22 frontend removals are cleanup, not compatibility fixes.** Most of them still install on Node 20. Calling them compatibility fixes would misrepresent both halves of R-4.
- **The war-plugin bump is a Maven-container incompatibility, not a JDK 17 language problem.** It is unavoidable only because a JDK-17-capable Maven is a precondition of the migration.
- **Surefire 2.12.4 is not globally broken on JDK 17.** A plain JUnit 4 test runs fine under it. The recorded reason is the specific late-`argLine`-substitution capability, nothing broader.
- **`maven-compiler-plugin` 3.13.0 and `maven-surefire-plugin` 3.5.3 are not the newest releases of their lines.** Newer 3.x releases exist for both. They are pinned choices comfortably past the capability floor each change actually needs — 3.6+ for `<release>`, 2.17+ for late substitution — and neither is claimed to be a line-top.
- **The sass watcher boundary is 1.79.0, not 1.78.** Both 1.77.8 and 1.78.0 declare the same watcher range; 1.79.0 is where it moves. The tilde is still load-bearing, but for the reason stated in the forced-change table.
- **The committed lockfile carries two watcher copies, not one hoisted copy** — one at the top level for the template renderer and one nested under sass. The tilde's function is to keep the recorded tree reproducible under strict validation, not to collapse the two.
- **PowerMock carries three cglib exclusions, not four.** Measured on the three coordinates that declare them.
- **The frontend withdrawals enumerate to fourteen, not twelve.** "Twelve" names the load-probe set, of which ten were cleared and held and two were replaced; four further Node-API packages were examined and withdrawn as well. The enumeration is countable and is what should be trusted.
- **The identical `javax/xml/bind` class set is 110 classes, not 121.** Re-measured by comparing the two jars' entry lists directly. The substantive claim — that the sets are identical, so excluding the duplicate API loses no type — is unaffected and is what the exclusion rests on.
- **Three planning figures are withdrawn** — 274 reactor modules, 142 test-bearing modules and the 773-test total — with the measured values and the reasons in [Figures this page withdraws](#figures-this-page-withdraws).
- **Nothing on this page was fixed.** Per R-6, the defects encountered while compiling this inventory — the duplicate servlet-API declaration among them — are documented in [Known issues](known-issues.md) and deliberately left alone.

## Related records

| Record | What it owns |
| --- | --- |
| [Module-access exceptions](add-opens-exceptions.md) | The eight test-scope directives, each attributed to the pinned library and the exact stack frame that demanded it, and the statement that production launch configuration has none |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative test totals, the two class-level exclusions and their collateral cost |
| [Static audit](static-audit.md) | The audit command, the seven classified hits before and the zero after |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour, including the withdrawals summarised here |
| [Known issues](known-issues.md) | Pre-existing defects documented and deliberately not fixed |
| [Smoke evidence](smoke-evidence.md) | The baseline-then-migrated smoke capture and the reduced-local-stack rationale |
