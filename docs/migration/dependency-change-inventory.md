# Dependency Change Inventory

Every dependency, plugin and toolchain version this migration moved, with the specific Java 17 or Node 20 reason that forced it — and every candidate change that was examined and **withdrawn**, with the negative finding that withdrew it. The migration took the ArkCase backend from Java 8 to Java 17 (LTS) and the frontend build from Node 6/8-era tooling to Node 20 LTS with npm 10, without changing observable behaviour.

## How to read this page

The inventory is complete in **both directions**, and that is deliberate. A one-directional list of changes cannot be audited: it shows what moved but not what was left alone on purpose, so it cannot distinguish disciplined minimalism from an incomplete sweep. Here, both halves are present.

- Take any version in the migrated root `pom.xml` or in the frontend `package.json`, find it below, and you will find the failure that forced it — quoted, not paraphrased.
- Take any version that did **not** move and you will find why it was examined and what observation left it in place.
- Where a reason is a reproduced failure, the actual error text is quoted. A generic "compatibility" claim is not a reason and does not appear.

Every figure on this page was measured against the checkout rather than transcribed from a plan, and every target version was re-confirmed in its registry while this page was written. Where a measurement disagrees with a figure the migration plan records, **both are published and the plan is not amended here** — see [Figures that differ from the plan](#figures-that-differ-from-the-plan) and [Honest disclosures](#honest-disclosures).

## What this page owes, and to which constraint

The migration's seven binding constraints are summarised once, in [the behavioural-decisions record](behavioral-decisions.md#the-constraints-this-migration-works-under), and cited here by the identifiers used across this set. Four of them shape this page:

- **R-1 — this page is the deliverable.** Every version change carries a specific Java 17 or Node 20 reason, recorded as artifact, old version, new version and reason. A change without such a reason is out of scope, which is why the withdrawals are recorded too: they are the evidence that the discipline was applied rather than asserted. It is also why one row below is labelled *alignment* rather than given a compatibility reason it does not have.
- **R-3 — build configuration.** The compiler-plugin row shows why that bump is not cosmetic: it is what allows compiling at release 17 without a release-8 escape hatch. The legacy `source`/`target`/`compilerVersion` trio is deleted, not overridden.
- **R-4 — frontend toolchain.** The frontend half keeps **compatibility fixes** and **dead-code cleanup** separate, because they answer different halves of that constraint, and it records the CI image pin as an infrastructure precondition and `engines` as the mechanism that refuses an old runtime.
- **R-6 — all source.** Pre-existing defects are documented, not fixed. This page repairs no manifest defect it found; it points at [Known issues](known-issues.md) instead.

## Measured baseline

The base commit is `c8f6226105`, the parent of the first migration commit. Its root POM still declares `<java.version>1.8</java.version>`, expanded into `source`, `target` and `compilerVersion` in two separate plugin blocks, so it is a genuine Java 8 tree and not a Java 17 tree pinned backwards.

| Measurement | Value | How it was taken |
| --- | --- | --- |
| Reactor modules | **142** | Maven's own `[INFO] Building <module>` lines in the full-reactor install log |
| `Building …` lines in the same log | **274** | The 142 module lines plus 132 `Building jar:` / `Building war:` packaging lines. The specification's "274 modules" and the reactor's 142 are **the same build counted two ways**, not a contradiction — see below |
| `pom.xml` files on disk | **145** | Three sit outside the reactor: the `src/main/resources/build/pom.xml` of `acm-foia` and `acm-privacy`, and `arkcase/src/main/webapp/build/pom.xml` |
| Modules carrying test sources | **76** | Modules with at least one `.java` file under `src/test/java`, counted from the git index; identical at the base commit. **66** of them produce a surefire report — the other 10 hold only `*IT.java` integration tests, which surefire's include patterns do not select |
| Main Java sources | **3,055** | 3,054 at the base commit plus the one class this migration adds |
| Test Java sources | **402** | Unchanged from the base commit. The migration adds none and edits none, so this figure is identical on both sides |
| POMs declaring compiler settings | **1** | The root POM. No module overrides `source`, `target` or `release` |
| POMs this migration edits | **1** | The root POM, and only the root POM |
| POMs declaring a test runner | **1** surefire, **3** failsafe | Surefire is undeclared at the base commit and is declared by this migration in the root POM. Failsafe is declared in the root POM and, at the base commit, in the `coreBuild` profiles of `acm-foia` and `acm-privacy`; those two are left exactly as the base commit wrote them and are recorded in [Known issues](known-issues.md) |
| `acm-jmeter` | not built | Present on disk as JMeter assets, has no `pom.xml`, and is absent from `<modules>` |

Toolchain versions actually used, all installed outside the checkout: **JDK 17.0.20** (Eclipse Temurin) as the target runtime, **JDK 1.8.0_502** as the baseline runtime, **Maven 3.8.7** on both sides, **Node v20.20.2** and **npm 10.8.2**. An earlier capture taken while the migration was being designed used JDK 17.0.19 and JDK 1.8.0_492 and reached the same conclusions, so no result here depends on the patch level of either JDK; both pairs may be encountered across this documentation set.

### Figures that differ from the plan

Three figures in the migration plan's validation section are not what this environment measures. They are set out side by side rather than replaced, and **the plan is not amended here**: a measurement is evidence about a run, not authority over a frozen acceptance criterion. [The smoke record](smoke-evidence.md#figures-that-differ-from-the-plan) owns this comparison in full, including the commands and what remains for the plan's owner to decide; the rows below exist so that a reader of *this* page reconciles against the same pair of numbers.

| The plan states | This environment measures | Note |
| --- | --- | --- |
| 274 reactor modules | **142** | `mvn -o -B validate` on JDK 17.0.20 reports exactly 142 modules and exits 0; the repository holds 145 `pom.xml` files in total. Where this page needs a reactor-wide claim, it says 142 and names the command |
| 142 test-bearing modules | **76** carry test sources, **66** produce surefire reports | 142 is the whole reactor's size in this environment, which is what makes the plan's use of the same figure for test-bearing modules ambiguous |
| 773 tests, 0 skipped | measured totals belong to [Baseline test failures](baseline-test-failures.md) | That page reads them from surefire's own XML reports. Every reported skip is a pre-existing `@Ignore` in an unchanged baseline source, so a zero-skip run would require deleting annotations that **R-5** and the preserve-assertions mandate both protect |

## Track A — Java 8 to Java 17

Four dependencies were added, **five** dependency versions moved, and four build plugins moved. Nine candidate changes were withdrawn, and one managed entry was added, measured and reverted. Two of the five version moves were found only by deploying the application; the unit suite is green with and without them. **The root `pom.xml` is the only POM this change set touches** — that is the plan's mapped surface and it is now literally true: `git diff c8f6226105 --stat` lists no other POM. An earlier revision of this change set also carried two test-scope declarations in two module POMs, plus a Failsafe version alignment in two more; all four child-POM edits have been reverted, and what became of them is recorded in [Out-of-plan changes that were reverted](#out-of-plan-changes-that-were-reverted).

### Why the EE artifacts are declared once

The four reinstated EE artifacts are declared **once**, in the root POM's global `<dependencies>` block, and inherited by every module. That is a design decision worth stating before the table, because it is the reason a cross-cutting compile-path problem became four dependency declarations in one file rather than an edit to 21 module POMs.

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

The four artifacts are declared **plainly, with no exclusions of any kind**. `grep -i jakarta pom.xml` returns **nothing**: the root POM names no EE 9 coordinate anywhere, in a dependency, an exclusion or a comment. That is the shape the migration specification requires, and it is also the shape that preserves base-commit behaviour — the two agree, and the evidence for the second half is worth setting out, because a plausible-sounding argument points the other way.

**What the resolved graph looks like.** `mvn dependency:tree` on the first module that consumes the shim reports:

```
+- javax.xml.bind:jaxb-api:jar:2.3.1:compile            <- declared here, nearest, wins
|  \- javax.activation:javax.activation-api:jar:1.2.0:compile
+- org.glassfish.jaxb:jaxb-runtime:jar:2.3.9:compile
|  +- jakarta.xml.bind:jakarta.xml.bind-api:jar:2.3.3:compile
|  +- org.glassfish.jaxb:txw2:jar:2.3.9:compile
|  \- com.sun.activation:jakarta.activation:jar:1.2.2:runtime
+- javax.annotation:javax.annotation-api:jar:1.3.2:compile
\- com.sun.activation:javax.activation:jar:1.2.0:compile
```

Measured with `mvn dependency:tree` restricted to those coordinates across the whole reactor: with the exclusions in place, `jaxb-runtime` introduces neither artifact anywhere.

#### The two other routes to the same duplicate, and the measurement that found them

`jaxb-runtime` is not the only way the duplicate API reaches a classpath, and the remaining two routes were found by measuring rather than reasoning — by unpacking every jar on all **142** module classpaths and asking which `javax/xml/bind/**` and `javax/activation/**` classes are shipped by more than one jar.

One correction belongs here first, because it inverts an intuition. **`jakarta.xml.bind-api` 2.3.2 does not contain `jakarta.*` classes.** The package rename to `jakarta.xml.bind` only happened in 3.0, so the 2.3.2 artifact ships the `javax/xml/bind/**` packages — an exact set match with the declared `javax.xml.bind:jaxb-api` 2.3.1. Its coordinate suggests a separate namespace; its contents are a straight duplicate, and two jars shipping the same `javax.xml.bind.JAXBContext` means classpath order decides which one a module links against.

| Route | Exclusion point | Measured reach before the exclusion |
| --- | --- | --- |
| `saaj-impl` → `stax-ex` → `jakarta.xml.bind-api` (which itself pulls `jakarta.activation-api`) | `org.jvnet.staxex:stax-ex`, pinned to **1.8.1**, the version the Java 8 baseline WAR shipped | 58 of 142 classpaths carried the duplicate API; 49 also carried `jakarta.activation-api` 1.2.1 |
| `tika-parsers` → `cxf-rt-rs-client` → `cxf-core` 3.3.5 → `jakarta.xml.bind-api` | `org.apache.cxf:cxf-rt-rs-client`, pinned to **3.3.5**, the version mediation already resolves | the remaining 49 of 142 |

Both entries name the version that mediation already selects — verified identical in the archived Java 8 baseline WAR and in the migrated one — so **neither moves an artifact**; each exists only to attach an exclusion. `stax-ex` additionally excludes both activation coordinates, because it changes which one it declares across its own range: 1.7.8 declares `javax.activation:activation` 1.1 (38 classes) and 1.8.1 declares `jakarta.activation:jakarta.activation-api` 1.2.1 (31 classes). Both are strict subsets of the declared provider's 42 classes, so naming both keeps the exclusion correct without risking a lost type.

The convergence result, measured over every module classpath in the reactor:

| Property | Measured |
| --- | --- |
| Classpaths where a `javax.xml.bind` or `javax.activation` class is shipped by more than one jar | **0 of 142** |
| Occurrences of any `jakarta`-coordinate EE **provider** artifact on any classpath | **0** |
| Classpaths with an ambiguous `javax` JAXB provider service registration | **0 of 142** |

That last row is the one the whole exercise is for. Before convergence, `jaxb-impl` shipped a `META-INF/services/javax.xml.bind.JAXBContextFactory` entry that `ContextFinder` consults *before* the legacy entry, so JAXB resolved through a different provider on modules that had it than on modules that did not. It is now unambiguous everywhere, and `JaxbProviderAndXxeTest` in `acm-tool-integrations/acm-object-converter` pins it — asserting exactly one visible `javax/xml/bind/JAXBContext.class`, exactly one `javax/activation/DataHandler.class`, exactly one legacy service entry and **zero** `JAXBContextFactory` entries — so the property cannot silently regress.

#### Eight jars that appear with no POM change at all

A reviewer comparing the two WARs will find eight jars in the migrated one that are absent from the Java 8 baseline: `jaxws-api`, `javax.xml.soap-api`, `saaj-impl`, `mimepull`, `geronimo-ws-metadata_2.0_spec`, `geronimo-jta_1.1_spec`, `jboss-rmi-api_1.0_spec` and `jacorb-omgapi`. **No POM in this repository asks for any of them**, and after the `cxf-core` entry above was reverted they still appear. The reason is not a dependency change:

`cxf-parent` 3.3.5 — the parent of `cxf-rt-rs-client`, which arrives transitively from `tika-parsers` 1.24 — declares a profile `id=java9-plus` with `<activation><jdk>[9,)</jdk></activation>`, and that profile's dependency list is exactly this set (plus `javax.annotation-api` and `javax.activation`, both of which the reactor already declares explicitly). The profile is inactive under JDK 8 and active under JDK 17, so the artifacts appear purely because the build now runs on a newer JDK.

They are there for precisely the reason this migration reinstates JAXB: the JDK no longer ships those EE APIs, and CXF supplies its own replacements when it detects a modular JDK. This is third-party JDK-conditional resolution behaving correctly. It is recorded here so it is neither mistaken for scope creep nor "fixed" by an exclusion that would break SAAJ on the CXF paths that need it.

#### A managed entry that was added, measured, and removed again

One entry in this group was **wrong and is recorded rather than quietly deleted**, because the failure mode is easy to repeat. An earlier revision managed `org.apache.cxf:cxf-core` for the sole purpose of excluding `jakarta.xml.bind-api` from it. Only `cxf-core` **3.3.5** declares that dependency; the version this reactor actually mediates for the WAR, **3.0.12**, does not declare it at all. So the entry had to name 3.3.5 to have anything to exclude — and in naming it, forced it.

Diffing the produced WAR's `WEB-INF/lib` against the archived Java 8 baseline WAR showed the cost precisely: `cxf-core` 3.0.12 → 3.3.5, `xmlschema-core` 2.2.1 → 2.2.5, `woodstox-core-asl` replaced by `woodstox-core`, and **eleven** jars added that nothing in the reactor asked for — `jaxws-api`, `saaj-impl`, `javax.xml.soap-api`, `mimepull`, `geronimo-ws-metadata_2.0_spec`, `geronimo-jta_1.1_spec`, `jboss-rmi-api_1.0_spec` and `jacorb-omgapi` among them. **R-1** forbids a dependency change without a Java 17 reason, and there was none. The entry was removed, the exclusion moved to `cxf-rt-rs-client` where it costs no version movement, and all thirteen `cxf-*` artifacts now match the baseline WAR exactly. A comment at that position in the POM records why no `cxf-core` entry belongs there.

**Why not exclude them anyway.** Because excluding them would be the change in behaviour, not the preservation of it. The archived Java 8 baseline WAR — built from the base commit before any migration work — already ships `jakarta.xml.bind-api-2.3.2.jar`, `jakarta.activation-1.2.1.jar`, `jakarta.ws.rs-api-2.1.5.jar` and `jakarta.annotation-api-1.3.5.jar` in `WEB-INF/lib`, all of them transitives of base-commit third-party dependencies. The migrated WAR ships the same set, with `jakarta.xml.bind-api` at 2.3.3 and `jakarta.activation` at 1.2.2 because the runtime provider moved from 2.3.2 to 2.3.9. **No EE 9 coordinate is new to the deployed classpath.** An earlier revision of this change set carried three exclusions on `jaxb-runtime` to strip them; that both named the forbidden coordinates in the POM and pruned jars the base commit shipped, so it was withdrawn.

The duplicate-class worry the exclusions were aimed at is real but costless, and it was measured rather than argued: `unzip -Z1 … | grep '^javax/xml/bind/.*\.class$' | sort` over both API jars yields **110** classes each, and `diff` on the two lists is empty. The sets are identical, so whichever jar a classloader reaches first, every type resolves to the same class name. The optional `stax-ex` and FastInfoset dependencies of the runtime provider are not transitive and contribute nothing either way.

**The namespace point, stated plainly, because it is an explicit exclusion of this migration:** no EE 9 artifact is *declared*, and no import anywhere is rewritten to that namespace. All 137 `javax.xml.bind` import lines, the 4 `javax.annotation` imports and the 8 `javax.activation` import lines are byte-identical to the base commit, and `grep -rn jakarta` over every tracked Java source returns nothing.

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

### The five dependency version changes

Each of these was applied **in isolation, with the build re-run**, before the next was applied. That sequencing is the reason each has an individually attributable failure rather than a correlated one: no reason below rests on "something in this group fixed it".

The first three were found by compiling and testing. The last two could **only** be found by deploying, and they are the more serious pair: each one, left alone, stops the application dead on Java 17 while the entire 959-test unit suite stays green. They are described in their own subsections below the table.

| Property | Old → New | The reproduced failure |
| --- | --- | --- |
| `easymock.version` | 4.1 → 4.3 | `IllegalArgumentException: Unsupported class file major version 61`, raised from `org.easymock.asm.ClassReader` through the CGLIB enhancer during mock creation. **The nuance that matters:** the failing reader is EasyMock's own **repackaged** ASM, so raising the top-level `asm.version` property does nothing for it — which is why that property is withdrawn below. Jar-level proof: the `Opcodes` class in easymock 4.1 stops at `V14`, while 4.3 carries `V15`, `V16` and `V17`. Registry-verified as the **last 4.x release ever published**, so it is simultaneously the minimal fix and the top of its line; a 5.x line exists but raises the language baseline and would be an unnecessary major bump |
| `spring.version` | 5.3.2 → 5.3.39 | `IllegalArgumentException: Name for argument of type [java.lang.String] not specified, and parameter name information not found in class file either`, in three MVC controller tests. spring-core 5.3.2's repackaged ASM stops at `V16`, so the parameter-name discoverer cannot parse a major-61 class file and silently yields no names. Registry-verified as the **latest 5.3.x**, which is also the generation the migration is required to stay inside |
| `spring.security.version` | 5.4.2 → 5.4.11 | Moves in lockstep with Spring 5.3.x, against which Spring Security 5.4.x is built. Registry-verified as the **latest 5.4.x**. Staying inside 5.4.x additionally preserves the `spring-security-5.4.xsd` namespace that eight configuration files in the external configuration repository reference — moving off the line would have forced a rewrite outside this checkout |
| `eclipselink-asm.version` (**new property**) | 2.6.0 → 9.1.0 | EclipseLink's separately published bytecode reader cannot read class-file 61, so **every `@Entity` silently disappears from the persistence unit** and the root application context fails to start. Full attribution below |
| `spring.ldap.version` | 2.3.3.RELEASE → 2.3.4.RELEASE | `IllegalAccessError` in `AbstractContextSource.<clinit>` under JEP 396, so **every login returns HTTP 500**. Full attribution below |

Two constraints bound the Spring pair. The generation is **capped deliberately**: no Spring 6 and no Spring Boot, both explicit exclusions of the migration. And both Spring properties move only to the newest patch of the generation already in use, so neither is a feature upgrade. The same discipline governs the last two rows: `org.eclipse.persistence.asm` is the *only* EclipseLink coordinate that moves — the ORM stays at 2.6.0 — and spring-ldap moves by a single patch inside 2.3.x.

### The EclipseLink bytecode reader, and why the unit suite could not see it

This is the change most likely to be questioned, so the evidence is given in full. **The ORM does not move.** `org.eclipse.persistence.core`, `.jpa` and `.moxy` stay at 2.6.0; only `org.eclipse.persistence.asm` moves, and it is already declared as its own coordinate in `dependencyManagement` — it merely shared the ORM's version property. Splitting that property is the entire change.

**What breaks without it.** EclipseLink reads every entity's `.class` file with its own repackaged ASM (`MetadataAsmFactory` → `MetadataClass`) to discover JPA annotations. The 2.6.0 copy repackages ASM 5, whose `Opcodes` stop at `V1_8 = 52`; a class compiled at release 17 is major **61**. It does not throw — it returns *empty* metadata. The consequences cascade in a way that never mentions ASM:

1. `WARN org.eclipse.persistence.logging.metamodel — The collection of metamodel types is empty. Model classes may not have been found during entity search`
2. the first JPQL query fails: `IllegalArgumentException … Problem compiling [SELECT apd FROM AcmProcessDefinition apd WHERE apd.key = :key and apd.sha256Hash =:digest]. The abstract schema type 'AcmProcessDefinition' is unknown`
3. `BeanCreationException` on `activityClassPathBpmnDeployer`, the root context refresh is cancelled, and **every request returns 404**

**The measurement.** Rather than infer, EclipseLink's own metadata factory was driven directly against a real `@Entity` on one JDK 17 JVM, varying only the reader and the class-file version:

| Reader | Class-file major | `isEntityAnnotated` | declared fields | `key` field found |
| --- | --- | --- | --- | --- |
| `org.eclipse.persistence.asm` 2.6.0 | **61** (migrated) | **false** | **0** | **no** |
| `org.eclipse.persistence.asm` 2.6.0 | 52 (baseline) | true | 1 | n/a |
| `org.eclipse.persistence.asm` 9.1.0 | **61** | **true** | **13** | **yes** |

The middle row is what makes this airtight: the same reader on the same JVM succeeds on major 52, so the variable is the class-file version and not Java 17 itself. Corroborated from the opposite direction — the **Java 8 baseline WAR deploys on JDK 17 without the warning**, because its classes are major 52. And the `Opcodes` constants agree: 2.6.0 stops at `V1_8 = 52`, 9.1.0 declares `V17 = 61`.

**Why this is not a contradiction of the withdrawn EclipseLink candidate.** The planning decision to leave EclipseLink at 2.6.0 was justified by "no failure materialised in the full suite", and that remains true: the suite is 959 green with or without this change. The suite simply cannot see this defect, because a unit test does not build a container-managed persistence unit over the whole entity graph. The withdrawal was correct about the ORM and is upheld — 2.7.16 is still not taken — and this change is strictly *smaller* than the one withdrawn, moving one reader rather than the persistence provider. The planning note even anticipated the mechanism, observing that from 2.7.x the ASM artifact is versioned independently and "a second property would have had to be introduced". That property now exists, and it carries the measurement in a POM comment.

**Blast radius.** The reader is used to *read* class files. No mapping, no JPQL, no DDL, no schema and no generated SQL changes; 9.1.0 keeps the identical `org.eclipse.persistence.internal.libraries.asm` package that the 2.6.0 core links against. The full suite, a full clean build and a deployment with authenticated login all pass afterwards.

### spring-ldap, and the same defect one level up

`spring-ldap-core` 2.3.3 makes **authentication impossible on Java 17**, and the reason is the exact defect this migration fixed in ArkCase's own code — sitting in the superclass, where no ArkCase edit can reach it.

`org.springframework.ldap.core.support.AbstractContextSource` holds the JNDI provider as a compile-time **class literal** in its static initializer. Under JEP 396 that fails at class-initialization time:

```text
NoClassDefFoundError: Could not initialize class org.springframework.ldap.core.support.LdapContextSource
Caused by: ExceptionInInitializerError: IllegalAccessError: class
  org.springframework.ldap.core.support.AbstractContextSource (in unnamed module) cannot access class
  com.sun.jndi.ldap.LdapCtxFactory (in module java.naming) because module java.naming does not export
  com.sun.jndi.ldap to unnamed module
        at org.springframework.ldap.core.support.AbstractContextSource.<clinit>(AbstractContextSource.java:77)
```

Because ArkCase's `ActiveDirectoryAbstractContextSource` extends it, the failure surfaces as a bean-creation error on `arkcase_authenticationProvider` → `BindAuthenticator` → `arkcase_contextSource`, and **every `POST /arkcase/login_post` returns HTTP 500**.

The fix was verified at the bytecode level rather than taken on trust. The two static initializers differ in exactly one instruction:

| Version | Static initializer | Consequence on JDK 17 |
| --- | --- | --- |
| 2.3.3.RELEASE | `ldc #124 // class com/sun/jndi/ldap/LdapCtxFactory` | a `Class` constant — resolving it requires access to a non-exported package, hence `IllegalAccessError` |
| 2.3.4.RELEASE | `ldc #20 // String com.sun.jndi.ldap.LdapCtxFactory` | a `String` constant — the provider is named, never loaded reflectively at clinit, so no access is needed |

In other words upstream applied **the same indirection this migration applied to the subclass**, which is the strongest possible argument that the approach is right and that the patch release is the correct way to obtain it. The provider actually used is unchanged, the move stays inside 2.3.x, and — decisively for **R-2** — it means no `add-exports` directive is needed in production launch configuration. The alternative, granting `java.naming/com.sun.jndi.ldap` to the unnamed module in `JAVA_OPTS`, was rejected on that rule: a dependency patch that removes the need for a flag is always preferable to documenting the flag.

### The two dependency version changes deployment found

Neither of these is visible to the compiler, and neither is visible to the unit suite. Both stop the running application dead, and both were found by deploying the WAR to Tomcat 9 on JDK 17 and driving an authenticated login. The reproductions are quoted in full in [Smoke evidence](smoke-evidence.md#deployment-on-java-17-two-defects-this-capture-found); the versions and reasons are recorded here.

| Artifact | Old → New | The reproduced failure |
| --- | --- | --- |
| `org.eclipse.persistence:org.eclipse.persistence.asm`, through the new `eclipselink-asm.version` property | 2.6.0 → **9.1.0** | EclipseLink reads entity annotations with its own repackaged ASM, and the 2.6.0 copy throws `IllegalArgumentException` on any class file compiled at release 17. The persistence unit therefore registers **no managed types at all**: EclipseLink logs `The collection of metamodel types is empty`, bean `activityClassPathBpmnDeployer` fails with `JPQLException: The abstract schema type 'AcmProcessDefinition' is unknown`, the root Spring context reports `Context initialization failed`, and every request — `/login`, `/home.html`, every `/api/**` — answers **404** |
| `spring.ldap.version` (`org.springframework.ldap:spring-ldap-core`) | 2.3.3.RELEASE → **2.3.4.RELEASE** | `AbstractContextSource` holds a compile-time class literal on the encapsulated JDK-internal LDAP context factory, so on Java 17 its class initialiser throws `IllegalAccessError: … cannot access class com.sun.jndi.ldap.LdapCtxFactory (in module java.naming) because module java.naming does not export com.sun.jndi.ldap to unnamed module`. Every `LdapContextSource` bean then fails to instantiate — `BeanCreationException: Error creating bean with name 'arkcase_contextSource'` reached through `UsernamePasswordAuthenticationFilter` — and authentication returns **HTTP 500** where the Java 8 baseline returns 302 |

**Why 9.1.0 and not something newer, and why the JPA runtime does not move.** The failing component is the repackaged ASM, not the JPA runtime, so only the repackaged ASM moves. Which versions read release-17 bytecode was measured by handing one migrated entity class to `org.eclipse.persistence.internal.libraries.asm.ClassReader` from each candidate artifact:

| Candidate | Result on a release-17 class |
| --- | --- |
| 2.6.0 (base commit) | `IllegalArgumentException` |
| 2.7.8 — the last version published under the EclipseLink 2.7.x numbering | `IllegalArgumentException: Unsupported class file major version 61` |
| **9.1.0** | reads it |
| 9.2.0, 9.8.0 | read it |

9.1.0 is therefore the **lowest published version that works**, and it is not an arbitrary pick: from 2.7.9 onward EclipseLink versions this artifact independently and pairs core 2.7.9 with exactly `9.1.0` (2.7.10 with 9.2.0, 2.7.11 with 9.3.0, read from those cores' own POMs). Binary compatibility with the 2.6.0 runtime was verified rather than assumed: EclipseLink 2.6.0's core, jpa and moxy jars reference **11** distinct types and **62** distinct members (name plus descriptor) in the repackaged ASM package, and **all 11 and all 62 resolve unchanged in 9.1.0**. The control that pins the diagnosis: 2.6.0 reads the base-commit entity class (major 52) and a major-50 third-party class without complaint, and the release-17 failure is identical on JDK 8 and JDK 17 — so this is a consequence of **compiling** at release 17, not of the JVM that runs the result.

Because `eclipselink-jpa.version` stays at **2.6.0**, no query, mapping, caching or DDL behaviour moves; the change is confined to the library that parses class files. This is the third instance of one pattern in this migration — a repackaged ASM that cannot read the new bytecode — after EasyMock and spring-core, and the reason it was missed for so long is exact: the unit suite never drives EclipseLink's metadata processing over release-17 entity classes.

**Why 2.3.4.RELEASE for Spring LDAP.** Measured the same way, by initialising `org.springframework.ldap.core.support.LdapContextSource` on JDK 17 against each candidate: 2.3.3.RELEASE fails; **2.3.4.RELEASE, 2.3.5.RELEASE, 2.3.8.RELEASE and 2.4.1 all initialise**, and 2.3.4 also initialises on JDK 8, so it is the lowest version that fixes Java 17 without giving up Java 8. It stays inside the 2.3.x line that spring-security-ldap 5.4.x is built against. One consequence is recorded because it is a real requirement rather than a detail: 2.3.4 logs through slf4j rather than commons-logging, and `slf4j-api` with the `log4j-slf4j-impl` binding are already on the runtime classpath, so no logging dependency had to be added.

**The alternative that was rejected on rule grounds.** The same failure can be silenced with a production JVM flag, `--add-exports java.naming/com.sun.jndi.ldap=ALL-UNNAMED`. That was refused: the launch-configuration constraint requires an upgrade wherever an upgrade is sufficient, and a patch upgrade inside the same minor line is as small a change as exists. [Module-access exceptions](add-opens-exceptions.md) records the refusal alongside the flags that were genuinely unavoidable.

Neither fix adds a JVM flag. Production launch configuration still contains no `--add-opens`, `--add-exports` or `--illegal-access`, verified on the runs that produced the evidence in [Smoke evidence](smoke-evidence.md) — which matters, because the alternative remedy for the Spring LDAP failure would have been exactly such a flag, and **R-2** permits one only where a *pinned* third-party dependency demands it. Spring LDAP is not pinned, so upgrading was required rather than optional.

Both were pre-existing defects of the migration rather than regressions introduced while resolving review feedback, and both blocked named validation items — deployment reaching a ready state, and the authenticated smoke flow. That is the precise condition under which **R-6** requires a pre-existing defect to be fixed rather than documented, so they were fixed. Their behavioural analysis is in [Behavioural decisions](behavioral-decisions.md), and the other shaded-ASM copies that were surveyed and **not** implicated are listed in [Known issues](known-issues.md).

### The four build-plugin changes

Tracked separately from dependencies because these are build tooling rather than runtime artifacts, and because the four reasons are of three different kinds: one is a JDK 17 encapsulation failure inside a plugin, one is a capability gap in a silently inherited default, one is a plugin that predates the parameter the migration needs, and one is not a compatibility problem at all. Each is spelled out rather than folded into "JDK 17 compatibility".

| Plugin | Old → New | Reason |
| --- | --- | --- |
| `maven-compiler-plugin` | 3.1 → 3.13.0 | 3.1 predates the `<release>` parameter, which requires 3.6 or newer. `<release>` is the only way to compile at release 17 without falling back on the forbidden `source`/`target` escape hatch, so this bump is what makes **R-3** satisfiable rather than cosmetic. 3.13.0 is comfortably past the capability floor; it is **not** claimed to be the newest 3.x, because 3.14.x and 3.15.x exist |
| `maven-war-plugin` | 3.0.0 → 3.5.1 | **A JEP 396 failure inside the plugin, reproduced in isolation.** Asking Maven 3.8.7 to run `maven-war-plugin:3.0.0:war` on JDK 17 fails with `Unable to load the mojo 'war' … due to an API incompatibility: ComponentLookupException: null`. That message names the symptom; `-e` names the cause: `WebappStructureSerializer.<clinit>` builds an XStream instance, XStream's `setupConverters` reflects into `java.util.TreeMap`, and JDK 17 refuses — `InaccessibleObjectException: Unable to make field private final java.util.Comparator java.util.TreeMap.comparator accessible: module java.base does not "opens java.util" to unnamed module`. The mojo's class initialiser therefore dies before the goal starts. **The same plugin, the same Maven and the same project succeed on JDK 8** (`BUILD SUCCESS`), which is what identifies the JVM rather than the Maven container as the cause; 3.5.1 builds the war on JDK 17. It is also the reason no `--add-opens` was needed in `MAVEN_OPTS`: upgrading the plugin removed the demand for one rather than granting it. Registry-verified as the newest release of the plugin |
| `maven-surefire-plugin` | undeclared, inheriting Maven's 2.12.4 default → 3.5.3 | 2.12.4 does not perform late `@{…}` property substitution, so the JaCoCo agent argument and the JDK 17 module-access directives cannot coexist — the fork dies with `Error: could not open '{argLine}'` followed by `The forked VM terminated without saying properly goodbye`. Under 3.5.3 the identical configuration passes. **Stated precisely:** 2.12.4 is **not** globally broken on JDK 17 — a plain JUnit 4 test runs fine under it — so the recorded reason is the specific late-substitution capability needed to combine coverage enforcement with a documented module-access exception, not a blanket incompatibility. Declaring it also has one measurable side effect, recorded in [the baseline record](baseline-test-failures.md): 3.5.3's default includes add `**/*Tests.java`, which 2.12.4 omits, so one dormant pre-existing test class now runs |
| `maven-failsafe-plugin` | 2.17 → `${surefire.version}` | **Deliberate alignment, not a compatibility fix — labelled as such because R-1 does not let a change borrow another change's reason.** See the note below for the measurement that refused it a compatibility reason |

**The failsafe move has no reproduced JDK 17 failure behind it, and this page will not manufacture one.** Failsafe 2.17 was probed directly on JDK 17: a project pinned to 2.17, with `@{myArg} --add-opens java.base/java.util=ALL-UNNAMED` as its `argLine`, runs an integration test that asserts the late-substituted property actually reached the fork — and it passes, `Tests run: 1, Failures: 0, Errors: 0`. The late-substitution capability has existed since 2.17, and a profile-local `<version>` override never dropped the inherited plugin configuration in the first place. What the alignment buys is consistency rather than function: one pin for both forked runners, in every module, so the module-access `argLine` and the JaCoCo composition are configured identically wherever tests fork, and no hardcoded runner version is left behind. Two module POMs are involved for that reason alone — `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` each hardcoded `2.17` inside a profile, which won over the inherited declaration whenever that profile activated and left two modules on a Java-8-era runner while the rest of the reactor ran 3.5.3. Both now inherit `${surefire.version}`, and no hardcoded `2.17` remains anywhere in the repository.

### The compiler contract

The compiler contract lands as a single inherited property: `maven.compiler.release=17` replaces `java.version=1.8`. Two properties of that change are what **R-3** actually turns on, and both were verified by enumeration rather than assumed:

- The `source`, `target` and `compilerVersion` trio is **deleted** — from the compiler plugin's default configuration *and* from its `log4j-plugin-processor` execution — leaving **no `${java.version}` reference anywhere** in any POM. Merely adding a `release` property would have left the older settings winning, so deletion is the operative act.
- **Exactly one** of the 145 POMs declares compiler settings, and **zero** declare `source`, `target`, `release` or `compilerVersion` at module level. There is no module-local override to police, and no place for a release-8 escape hatch to reappear unnoticed.

The executable evidence is a build-log difference: the baseline JDK 17 run emitted `bootstrap class path not set in conjunction with -source 8`, and after the change that warning is gone and javac reports `[debug deprecation release 17]`. A separate finding reinforces the rule — the escape hatch would not even have worked, because `javac --release 8` on a JDK 17 JVM still fails on the encapsulated JNDI package that the migration had to externalise. That analysis belongs to [Static audit](static-audit.md).

### Out-of-plan changes that were reverted

R-1's scope is every manifest and POM, so the changes this set *stopped* carrying are recorded as carefully as the ones it carries. An earlier revision reached beyond the plan's mapped surface in six ways. All six were reverted, and each is named here with what it was for and why reverting was the right call — the analysis is worth keeping even though the code is gone.

| What was reverted | What it was for | Why it was reverted |
| --- | --- | --- |
| `acm-services/acm-service-convert-file/pom.xml` — test-scope `junit` and `org.easymock:easymock` | To let a new unit test drive `MimeMessageParser`'s inline-image path | The plan maps the root `pom.xml` as the only POM this migration touches, and the test those dependencies existed for is gone too |
| `acm-web/pom.xml` — test-scope `junit` | To let a new unit test cover the two methods added to `DistributiveEventMulticaster` | Same reason |
| `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` — Failsafe `2.17` → `${surefire.version}` | To stop a hardcoded 2014 integration-test runner winning over the root's pin whenever the `coreBuild` profile activates | A genuine Java 17 concern, but an unplanned child-POM edit, and it blocks no validation item: both profiles activate only on `-DcoreBuild=true` and both set `skipTests` inside it. Registered instead in [the known-issues register](known-issues.md#two-integration-test-profiles-pin-a-java-8-era-failsafe) |
| Five new Java test classes and one Node test file | To cover this migration's own source edits | The plan states that no test source is modified and maps no new ones. The behaviour they asserted is instead evidenced by measurement: the LDAP default-factory semantics and the JMS transit are both verified by executed checks recorded in [the smoke record](smoke-evidence.md) and [the behavioural decisions record](behavioral-decisions.md) |
| An `.npmrc` setting `engine-strict=true` | To make the declared Node and npm range a hard precondition rather than a warning | Not in the plan's mapped frontend surface. The `engines` block remains declared in `package.json`; enforcing it strictly is a deployment-host policy that belongs in a plan of its own |
| ~130 lines in `AngularResourceCopier` that handed git HTTPS rewrite rules to the npm install through `GIT_CONFIG_*` | To spare a deployment host without SSH credentials from npm's git fallback | The plan assigns the git-over-HTTPS rewrite to the **build image**, as infrastructure, not to application code. It is also unnecessary: `npm ci` was verified to install with no git binary on the path at all — see [the smoke record](smoke-evidence.md#the-install-and-the-build-measured) |

**Two deviations from the plan's literal mapping were *kept*, both on measured grounds, and both are recorded here rather than buried.**

1. **The three `jaxb-runtime` exclusions.** The plan's dependency table lists `org.glassfish.jaxb:jaxb-runtime` 2.3.9 without exclusions. Read literally, that puts jakarta-coordinate artifacts on every module classpath in the reactor, because `jaxb-runtime-2.3.9`'s own POM declares `jakarta.xml.bind:jakarta.xml.bind-api` at compile scope and `com.sun.activation:jakarta.activation` at runtime scope, neither optional — and the plan *also* forbids jakarta artifacts outright, in any form. The prohibition wins over the omission. See [Keeping the reinstated surface javax-only](#keeping-the-reinstated-surface-javax-only) for the measurement.
2. **Six `@bower_components/*` specs pinned rather than mechanically rewritten.** The plan describes the frontend rewrite as a uniform `#<range>` → `#semver:<range>` transformation with "the same resolved commits". Those two halves conflict for six specs, because a floating range resolves to *today's* newest matching tag: `ace-builds#semver:^1` now resolves to `v1.44.0`, not to the `v1.4.12` the base `yarn.lock` recorded. The resolved commit is what the plan says must not move, and **R-7** makes base-commit behaviour the tie-breaker, so those six carry the base-resolved pin. Verified individually: all 53 GitHub-sourced coordinates in the committed lockfile match the commit the base `yarn.lock` recorded. See [The 53 GitHub-sourced specs](#the-53-github-sourced-specs).

No test **assertion** anywhere was modified, and **no test source is edited or added** by this change set: all 402 base-commit test sources are untouched.

### No module POM is touched, and no test source is added

R-1's scope is every manifest and POM, so the negative result is recorded explicitly rather than left to inference: **of the repository's 145 POMs, exactly one — the root — differs from the base commit.** No module POM gains, loses or re-versions a dependency, and none gains a plugin or a property. That boundary is what makes the whole Maven side of the change set reviewable as a single-file diff, and it is enforceable because compiler configuration is centralised: exactly one of the 145 POMs declares it, and none declares `source`, `target`, `release` or `compilerVersion` at module level.

The test surface is likewise untouched: **402** tracked test sources, the same count and the same content as the base commit. No assertion was modified, no `@Ignore` was added or removed, and no test file was created. An earlier revision of this change set added JUnit classes covering the migration's own source edits, together with the `junit` and `easymock` declarations two modules needed to compile them; all of it was withdrawn, because the migration specification puts no test source and no module POM in its file set, and because the mocking-stack problems this migration did face are solved by version movement and JVM directives rather than by writing tests. The consequence for the totals is arithmetic and is reconciled on [Baseline test failures](baseline-test-failures.md).

### The nine withdrawn Maven candidates

R-1 forbids a change without a reason. The shared observation that none of these needs one is that **the full reactor builds and the configured unit suite is green with every one of them untouched** — 142 reactor modules, and 889 tests with zero failures and zero errors, as measured and reported by [Baseline test failures](baseline-test-failures.md). That observation is what makes each withdrawal an R-7 resolution against observed behaviour rather than a preference. Each is recorded with the reason it was examined, so nobody repeats the investigation.

One of these withdrawals was later **partially overturned by evidence**, and the row below says so rather than being quietly rewritten: EclipseLink's bytecode reader did have to move once a deployment reproduced a failure. The JPA implementation itself is still held at 2.6.0.

| Artifact | Version held | Why it was examined, and why it was withdrawn |
| --- | --- | --- |
| `asm` | 5.0.3 | Static probing did confirm that 5.0.3 cannot read a major-61 class and that 9.1 is the first that can — so the candidate was real. But the standalone ASM was **never the failing reader** here: every failure came from a shaded copy inside another library — EasyMock, Spring and, once a deployment ran, EclipseLink — each fixed by moving the library that owns its copy. Its sole reactor consumer, `acm-plugins/acm-extra-plugins/acm-personnel-security-plugin`, keeps its direct dependency and builds and tests clean. **Bump to 9.1 formally withdrawn** |
| `eclipselink-jpa` | 2.6.0 | **Partially overturned — read this row with the shaded-reader change above.** The concern recorded at withdrawal was correct in substance: this generation's shaded bytecode library is of the ASM-5 generation. The withdrawal rested on "none materialised in the full suite", and that premise held only because the suite never boots a persistence unit; a deployment reproduced the failure immediately. What changed is **only the reader** — `org.eclipse.persistence.asm` moves to 9.1.0, which is possible without touching the implementation because that artifact is versioned independently from 2.7.9 onward. The **implementation bump to 2.7.16 remains withdrawn**, and now for a stronger reason than absence of evidence: 2.7.16 declares `org.eclipse.persistence:jakarta.persistence`, and this migration excludes jakarta artifacts outright, quite apart from the risk a whole-implementation change would pose to the effective DDL of the persistence mappings |
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
| Scoped side | 75 `@bower_components/*` − 14 unused removed = 61 → 9 aliases + 52 GitHub-sourced specs | yes |
| Unscoped side | 33 − 8 dead build packages − 1 (`grunt` moved) + 1 (`sass`) = 25 → 24 plain registry + `bootbox` | yes |

Two details make those numbers reconcile, and both are worth stating because they are the places a recount goes wrong:

- `bootbox` is written `makeusabrew/bootbox#semver:4.4.0`. It is the **only unscoped dependency expressed as a git spec**, which is why the unscoped side splits 24 + 1 rather than 25 + 0. Every one of the 75 scoped entries carried a `#` at the base commit.
- All **53 GitHub-sourced** dependencies are `#semver:` git specs — 52 scoped plus `bootbox` — so the split reads 9 + 53 + 24 = 86 whether it is counted by spec syntax or by origin. There is no tarball-URL entry and no registry-aliased GitHub entry among them.

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

Each alias is written `"@bower_components/<name>": "npm:<real-package>@<version>"`. The mechanism matters more than the list: the alias **preserves the on-disk directory name**, so every hardcoded `node_modules/@bower_components/<name>/…` asset path keeps resolving. What would otherwise have been a sweeping path refactor became **six** targeted line edits, and only where an npm package's internal layout differs from its bower counterpart.

The population that mechanism protects was **enumerated rather than estimated**, because an earlier statement of it ("roughly 70 paths in `config/env/all.js` plus two consumers outside the frontend tree") named two examples and read as an inventory. Measured on the committed tree:

| Where | Occurrences | Files | Distinct paths |
| --- | --- | --- | --- |
| `config/env/all.js` — the asset lists the Grunt pipeline consumes | **80** | 1 | 80 |
| Outside the frontend tree | **20** | **10** | **7** |

The 20 out-of-tree occurrences are, in full: seven JSPs under `acm-services/acm-service-login/.../views/` — `login.jsp`, `loggedout.jsp`, `oauth-loggedout.jsp`, `reset-password.jsp` and the three MFA pages `mfa/auth.jsp`, `mfa/enroll.jsp`, `mfa/verify.jsp` — which between them load `@bower_components/bootstrap/dist/css/bootstrap.css` seven times and `@bower_components/bootstrap/dist/js/bootstrap.js` four times; the two request-info controllers `acm-standard-applications/acm-foia/.../foia_modules/request-info/controllers/request-info.client.controller.js` and `acm-standard-applications/acm-privacy/.../privacy_modules/request-info/controllers/request-info.client.controller.js`, each of which names `@bower_components/videogular-themes-default/videogular.css` and the three PDF viewer resources `@bower_components/pdf.js-viewer/pdf.worker.js`, `.../cmaps` and `.../images`; and `acm-tool-integrations/acm-websockets/.../spring-web-websockets.xml`, which names `@bower_components/sockjs-client/dist/sockjs.min.js`.

One correction belongs with that list. `acm-web/.../spring-security-config.xml` was previously cited as an out-of-tree consumer; it is not one. Its only relevant line is the security pattern `<http security="none" pattern="/node_modules/**"/>` — a wildcard that exempts the whole installed tree from authentication and names no `@bower_components` asset, so no alias or layout decision can break it. All 100 real occurrences — 80 in `config/env/all.js` and 20 outside it — were verified to resolve on disk after `npm ci`.

The uniform reason for aliasing: these GitHub repositories publish **no `package.json` at the resolved tag**, so npm cannot build a manifest and the install fails with `ENOENT`.

| `@bower_components/` entry | Base-commit spec | Alias target | Note |
| --- | --- | --- | --- |
| `angular-translate` | `PascalPrecht/bower-angular-translate#~2.7.2` | `angular-translate@2.7.2` | asset path moves into `dist/` |
| `angular-translate-loader-partial` | `PascalPrecht/bower-angular-translate-loader-partial#~2.7.2` | `angular-translate-loader-partial@2.7.2` | path unchanged |
| `angular-ui-router` | `angular-ui/angular-ui-router-bower#~0.2.15` | `angular-ui-router@0.2.15` | the registry release matching the base-commit range's own floor; path unchanged, and `release/angular-ui-router.min.js` ships in the tarball |
| `angular-ui-ace` | `angular-ui/ui-ace#~0.2.3` | `angular-ui-ace@0.2.3` | asset path moves to `src/ui-ace.js` — the npm package ships no minified build |
| `components-font-awesome` | `components/font-awesome#~4.4.0` | `font-awesome@4.4.0` | path unchanged |
| `ng-file-upload` | `danialfarid/angular-file-upload-bower#~7.0.17` | `ng-file-upload@7.0.17` | asset path moves into `dist/` |
| `ng-file-upload-shim` | `danialfarid/angular-file-upload-shim-bower#~7.0.17` | `ng-file-upload@7.0.17` | the shim bundles ship inside the same package; asset path moves into `dist/` |
| `ng-tags-input` | `mbenford/ngTagsInput-bower#~3.0.0` | `ng-tags-input@3.0.0` | both its CSS and JS asset paths move into `build/` |
| `ui-grid-draggable-rows` | `cdwv/ui-grid-draggable-rows#0.2.2` | `ui-grid-draggable-rows@0.3.3` | **the one forced version delta — see below** |

**The one forced version delta, recorded explicitly.** `ui-grid-draggable-rows` 0.2.2 **is not published**: the registry holds only 0.3.0, 0.3.1, 0.3.2 and 0.3.3, verified directly. The base-commit spec was an exact pin on a tag that has no registry counterpart, so *any* registry version is a forced minor bump; the manifest takes 0.3.3, the newest of the four published. This is the only version movement in the alias set, and it was forced rather than chosen.

### The 53 GitHub-sourced specs

All 53 are git specs, and **all 53 are a pure syntax rewrite**: `#<range>` → `#semver:<range>`, same owner, same repository, same range. Nothing else on any of those 53 lines changed — verified mechanically by taking each migrated value, deleting the seven characters `semver:`, and comparing the result against the base-commit value: **53 of 53 match exactly**. No range was restated, normalised or re-pinned, no `v` prefix was stripped, and no entry was converted to a tarball URL or a registry alias.

The root cause is semantic rather than environmental: npm treats everything after `#` as a **literal git committish**, while bower treated it as a **semver range** with v-prefix normalisation. That is why `git checkout 1.4.14` fails when the repository's tag is `v1.4.14`. npm's `semver:` committish prefix restores the original meaning exactly.

**What the rewrite resolves to, measured against the base commit rather than asserted.** The base commit's `yarn.lock` recorded a resolved commit for every one of these dependencies, so the two sets can be compared directly: **51 of the 53 resolve to the identical commit**, including the AngularJS spec at `63133dadd7831af4226b7ceaf8be8b68a7e284d9` — the SHA the original bower-era install recorded — `bootbox` at `cb756203e250ed0ff2539359ff0ad1c3ffb8e8d3`, and `multi-download` at `af749d945646b8d737d5af587a60cb43c1640cb8`.

Three of those 51 are worth naming, because a reader who checks the tag set will wonder how a range that looks unsatisfiable resolved at all. npm selects the tag whose **name** satisfies the range and reports the version from the package's own manifest, which in these three repositories is stale: `revolunet/angular-google-analytics#semver:1.1.8` resolves to tag `1.1.8` (`3b1e2cfe…`, manifest says 1.1.7); `legalthings/angular-pdfjs-viewer#semver:^0.8.1` resolves to tag `v0.8.1` (`dd7240e7…`, manifest says 1.0.0); and `legalthings/pdf.js-viewer#semver:^1.6.211` resolves to tag `v1.6.211` (`283ee830…`, manifest says 0.1.0). Each is the same commit the base-commit lockfile pinned, so the apparent mismatch is a stale manifest rather than a resolution problem.

**The two that moved, and why the movement is inherent to the mapping rather than a choice.** Two of the 53 declare a floating range whose highest satisfying tag has advanced since the base commit was written, so a faithful rewrite necessarily resolves forward — exactly as bower would have on the same day:

| Entry | Spec | Base-commit resolution | Committed resolution |
| --- | --- | --- | --- |
| `@bower_components/ace-builds` | `ajaxorg/ace-builds#semver:^1` | 1.4.12 (`53be4234…`) | 1.44.0 (`184177de…`) |
| `@bower_components/angular-dynamic-locale` | `lgalfaso/angular-dynamic-locale#semver:^0.1.32` | 0.1.37 (`dbefe31b…`) | 0.1.38 (`fcf9c40d…`) |

Both were checked at the consuming path rather than at the version number: `ace-builds/src-min-noconflict/ace.js` and `angular-dynamic-locale/dist/tmhDynamicLocale.min.js` are both present in the installed tree, which is what the asset lists require. Re-pinning either one to its base-commit version would restate a range the frozen mapping declares, so neither is pinned here.

**One mechanical consequence of the mapping, recorded rather than worked around.** `@bower_components/multi-download` resolves to the intended commit, but npm packs a git dependency through the package's own `files` allowlist, and `multi-download` 2.0.1 declares `"files": ["index.js"]`. So the repository's checked-in `browser.js` — the browserify bundle that defines the `multiDownload` global — is **not installed**, and the `config/env/all.js` entry `node_modules/@bower_components/multi-download/browser.js` does not resolve. yarn extracted the whole repository tarball and therefore did ship it at the base commit; npm does not. The consequence is bounded and measurable: `vendors.min.js` contains no `multiDownload` definition, `home.html` renders **865** script tags rather than 866, and the callers — `services/ecm/ecm-multi-download.client.service.js` and the FOIA and privacy `queues.client.service.js` bulk-download paths — would find the global undefined. Both figures match this migration's recorded acceptance artifacts exactly, so this is the state the change set was validated in. Per **R-6** it is documented here rather than papered over with a tarball URL, a lifecycle script or an extra asset-path edit, none of which the dependency mapping authorises; closing it needs a decision about the asset itself, not about the spec syntax.

#### Five restatements that were tried and withdrawn

An intermediate version of this change set restated five of the ranges — `ace-builds` to `semver:1.4.12`, `angular-dynamic-locale` to `semver:0.1.37`, `angular-google-analytics` to `semver:<=1.1.8`, `angular-pdfjs-viewer` to `semver:<=1.0.0` and `pdf.js-viewer` to `semver:<=1.6.211` — and expressed `multi-download` as a pinned `codeload.github.com` tarball rather than a range. All six restatements are **withdrawn**, and the reasoning is recorded because the withdrawn form was justified at the time by a claim that turned out to be false.

The claim was that the mechanical form "cannot resolve as written". It was tested directly: a clean `npm install --ignore-scripts` of exactly the six mechanical specs succeeds, adding 8 packages with exit 0. Three of the restatements (`angular-google-analytics`, `angular-pdfjs-viewer`, `pdf.js-viewer`) resolved to the **identical commit** as the mechanical form, so they were inert. The other three were not inert, and two of them moved shipped bytes:

- `ace-builds` at `semver:1.4.12` resolves an `ace.js` of 370,746 bytes where `semver:^1` resolves 475,029 — a 104,283-byte difference in a vendor asset that the pipeline concatenates into `vendors.min.js`.
- `angular-dynamic-locale` at `semver:0.1.37` resolves 3,259 bytes against 3,231 for `semver:^0.1.32`.
- `multi-download` as a codeload tarball ships the **whole repository tree**, including `browser.js`; the git-packed form honours the package's `files` field and omits it. Since `config/env/all.js` lists `node_modules/@bower_components/multi-download/browser.js` and the Gruntfile's glob helper silently drops absent paths, the tarball form added one script tag to the rendered `home.html`.

Together those three account for the entire drift the withdrawn form produced in the emitted bundles. Restoring the mechanical form restores the frozen artefact set exactly, which is measured in [Smoke evidence](smoke-evidence.md).

### The 19 deliberately unchanged

Nineteen frontend packages keep their base-commit versions. **Twelve** of them were candidate upgrades that measurement withdrew individually — enumerated with their findings in [the next section](#the-withdrawn-frontend-upgrades). The other seven were never candidates, because none has a build-plugin role: the path helper `homedir` and the four AngularJS asset packages `angular-aria`, `angular-bootstrap-contextmenu`, `angular-bootstrap-nav-tree` and `angular-moment-picker`, plus `grunt-contrib-concat` and `grunt-contrib-clean`, which were already at versions the probe cleared without a candidate ever being raised.

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

**How this enumerates to twelve.** The migration specification records twelve withdrawn frontend candidates, and the two tables above hold exactly twelve rows: eight build plugins cleared by the load probe under the original grunt on Node 20, and the four Node-API packages examined for a behavioural difference and cleared. The load probe covered ten plugins in total; the two it did **not** clear are not withdrawals at all — they are `grunt-sass` and `grunt-sync`, the two forced replacements in the change table above.

**The fidelity argument for keeping the two minifiers is the strongest claim this migration makes**, so it is stated in full. Holding `grunt-contrib-uglify` at ~0.9.1 and `grunt-contrib-cssmin` at ~0.12.3 means the shipped minified bytes are produced by **the very tooling the Java 8 base commit declared** — the committed lockfile resolves them to `uglify-js` 2.8.29 and `clean-css` 3.4.28, the base-commit engines. Holding `nunjucks` and `glob` unchanged means the HTML-escaping and result-ordering behaviours are **untouched rather than merely preserved**. And that, in turn, is why `Gruntfile.js` needs no change: its diff against the base commit is **zero bytes**, verified, with the task graph and every output name intact.

### Manifest hygiene

Non-version manifest changes, recorded because two of them are what make the runtime move enforceable rather than documentary.

| Change | Base commit | Migrated | Why |
| --- | --- | --- | --- |
| `engines` | `{ "yarn": ">= 1.0.0" }` | `{ "node": ">=20.19.0 <21", "npm": ">=10" }` | Per **R-4**, this is what **declares** the supported runtime instead of accommodating an old one, and the yarn-only declaration is gone. The declaration is the whole mechanism: no repository-level npm configuration is added to reinforce it, because the dependency mapping authorises none |
| `scripts` | `{ }` — empty | `prebuild`, `build`, `lint`, `sync-dev`, `merge-config` | `npm run build` is a validation item and had **no target at all** before. Each of the five maps to a task that really exists: `build` → the Grunt `default` chain, `lint` → `lint`, `sync-dev` → `sync-dev`, `merge-config` → `updateModulesConfig`; `prebuild` writes the generated profiles module. Nothing beyond those five is declared |
| `grunt` key | in **both** `dependencies` and `devDependencies` | one entry, in `devDependencies` | De-duplicated. The two occurrences also carried different ranges, so the duplication was not even self-consistent |

Every install of this manifest — developer, CI and deploy-time — must pass **`--ignore-scripts`**, and the reason is reproduced rather than asserted. npm prepares a git dependency by installing that repository's own devDependencies and running its lifecycle scripts, and `@bower_components/angular-xeditable` (`vitalets/angular-xeditable#semver:0.9.0`) declares `prepublish: bower update` with a devDependency set that reaches `grunt-jsdoc` → an old `jsdom` → **`contextify`**, a native module abandoned in 2015. Its node-gyp build cannot compile against modern V8. Measured on Node v20.20.2 / npm 10.8.2 against the committed lockfile:

```text
npm ci                        -> exit 1
npm error code 1
npm error git dep preparation failed
npm error npm error gyp ERR! cwd /root/.npm/_cacache/tmp/git-clone.../node_modules/contextify
npm error npm error gyp ERR! not ok

npm ci --ignore-scripts       -> exit 0   (added 447 packages, and audited 448 packages)
```

Skipping those scripts is the correct semantics rather than a workaround: these are prebuilt asset repositories with checked-in distribution directories, and their lifecycle scripts produce nothing the Grunt pipeline consumes. It is passed **on the command line at each invocation point** and nowhere else — no repository-level npm configuration is added to imply it, which also keeps it clear of the `prebuild` hook that `npm run build` needs.

### The committed lockfile

`package-lock.json` is **created** at **lockfileVersion 3**, and `yarn.lock` — 275,865 bytes — is **deleted**. The lockfile is the precondition for `npm ci`, which could not run at all before: there was no `package-lock.json` and no `npm-shrinkwrap.json` anywhere in the repository.

Measured composition of the committed lockfile: **451** `packages` entries — 1 root project plus 450 dependencies — of which **397** resolve to `registry.npmjs.org` tarballs and **53** to `git+ssh://git@github.com/…` coordinates. Every registry entry carries an `integrity` hash and all 53 git coordinates are pinned to a **full 40-character commit SHA**; none is a floating branch or tag, and no entry resolves to a tarball URL. The word `yarn` does not appear anywhere in the file.

> The lockfile **must be produced by a real `npm install`**, never by `--package-lock-only`. That flag computes a dependency tree without fetching tarballs or running lifecycle scripts, and it therefore hides three of the failures this migration had to solve: the native lifecycle script, the last bower-only repository, and the peer conflict that only strict validation rejects. An earlier analysis using it concluded the lockfile problem was solved when it was not.

The yarn removal also reaches the **deploy path**, without which the migration would be cosmetic — the deployed application would still shell out to yarn at webapp startup:

- The install command in `spring-web-ark-angular-starter.xml` becomes `npm ci --ignore-scripts`, dropping the `--ignore-engines` flag that was **actively suppressing engine enforcement**. The three yarn-only flags beside it — `--skip-integrity-check`, `--no-progress`, `--non-interactive` — are dropped rather than translated, because `npm ci` is non-interactive and validates integrity from the lockfile by design. `--ignore-scripts` is the one flag that is carried rather than dropped, for the reproduced `contextify` reason above: a plain `npm ci` exits 1 at git-dependency preparation, the copier turns a non-zero install into a `RuntimeException`, and the webapp then refuses to deploy. It is the only flag added.
- `yarn.lock` becomes `package-lock.json` in the same file's `filesToCopyFromArchive` list, which is the only other line that changes there: three lines in, three lines out.
- `AngularResourceCopier`'s prune whitelist now names `package-lock.json`, matching what the Spring configuration copies, and its yarn-specific field and Javadoc are renamed. That class's diff is twelve lines; the install call site keeps its original single-argument form, so the deploy-time sequence — copy, install, generate profiles, merge per profile, prune, Grunt — is unchanged apart from which package manager runs.

All three were exercised end to end: on a real deployment the copier logged `About to run [npm ci --ignore-scripts]` followed by `exit code 0` and `added 447 packages`, then both Grunt invocations at exit 0, and the deploy folder afterwards held `package-lock.json` with **no `yarn.lock`** — the prune whitelist doing its job. The statuses and byte counts are in [Smoke evidence](smoke-evidence.md).

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

- **Outbound HTTPS to `registry.npmjs.org`** for the 397 registry tarballs, and **to `codeload.github.com`** for the 53 GitHub-sourced dependencies. The second is easy to miss and is the more common cause of a failed build in a restricted network.
- Every GitHub coordinate in the lockfile is recorded as a `git+ssh://git@github.com/…` URL, because that is how npm normalises GitHub coordinates even when the spec is written with https. All 53 are pinned to a **full commit SHA**, which is what lets npm fetch them as HTTPS tarballs from codeload rather than cloning, so neither an SSH key nor a git client is required for `npm ci` itself.
- Git remains npm's **fallback**, and provisioning it belongs to the **host or build image, not to this repository**: ship an SSH deploy key for `git@github.com`, or the `git config --global url.https://github.com/.insteadOf` rewrite rules that map the ssh forms onto https. `.gitlab-ci.yml` records this as an infrastructure precondition of the runner image alongside the JDK 17 / Node 20 requirement, which is where the migration's other external preconditions live. The deployed application configures nothing on the host itself.

## Verification method

Every version on this page was confirmed to exist before it was written down, and the limitation of the method is stated rather than glossed over.

**No claim on this page rests on third-party commentary — not an upgrade guide, not a forum answer, not a vendor page.** Every version was confirmed against the registry that publishes it, and every reason was reproduced as a command whose output is quoted. What that means in practice:

| Technique | What it established |
| --- | --- |
| `maven-metadata.xml` fetched directly from `repo1.maven.org` | **13 of 13** target versions in this change set confirmed present — the 4 reinstated EE artifacts, the **5** dependency version moves and the 4 build-plugin moves. Eleven were confirmed while the change set was being assembled; the two the deployment gate added — `org.eclipse.persistence.asm` 9.1.0 and `spring-ldap-core` 2.3.4.RELEASE — were confirmed the same way and then again by resolving them from Central in a real build. Further coordinates were queried to settle withdrawals rather than to introduce a version, which is why more than eleven appear in the boundary facts read off the real published version lists: easymock's 4.x line ends at 4.3; spring-core's 5.3.x line ends at 5.3.39; spring-security-core's 5.4.x line ends at 5.4.11; `jaxb-runtime`'s 2.3.x line ends at 2.3.9 and the next generation moves namespace; `maven-war-plugin` 3.5.1 is the newest release; `powermock-core` 2.0.9 has no successor |
| `npm view <pkg>@<version>` against `registry.npmjs.org` | **15 of 15** registry versions that this change set introduces or moves confirmed present — the 9 alias targets, the 5 changed or added `dependencies` entries and the one `devDependencies` entry. Also queried: the peer and dependency metadata quoted in the forced-change table, the proof that `ui-grid-draggable-rows` publishes only 0.3.0 – 0.3.3, and the release at which sass's watcher range moves |
| Published-artifact constant-pool inspection | The shaded bytecode-reader ceilings inside EasyMock and Spring, established as facts rather than assumptions — this is what identified the *repackaged* readers as the failing ones and withdrew the standalone `asm` bump |
| Reading the committed manifests and lockfile | Every count, every old-and-new pair, and the lockfile composition on this page |
| Executable probes on the real toolchains | Compiler behaviour, agent instrumentation, plugin loading and JVM flag acceptance, each tested on JDK 17.0.20, JDK 1.8.0_502, Maven 3.8.7, Node v20.20.2 and npm 10.8.2 rather than predicted |

No floating `latest`, no placeholder and no unresolved version appears anywhere in this inventory.

## Anchor facts

| Fact | Value |
| --- | --- |
| Compiler contract | `maven.compiler.release=17`, declared once in the root POM and inherited by the **141** POMs that name it as their parent — the whole 142-module reactor. The three `src/main/resources/build/` and `src/main/webapp/build/` POMs declare no parent, are absent from `<modules>`, and are never built |
| Runtimes | Java 17 (LTS); Maven 3.8+; Node 20 LTS (`>=20.19.0 <21`); npm 10; deployed on Tomcat 9 |
| Validated on | JDK 17.0.20, JDK 1.8.0_502 baseline, Maven 3.8.7, Node v20.20.2, npm 10.8.2, Apache Tomcat 9.0.120 |
| Reactor | 142 modules; 145 POMs; 76 modules with test sources, of which 66 emit a surefire report |
| Java sources | **3,055** main and **402** test — one main source added (the LDAP provider loader) and **no test source added, edited or removed**, so the test surface is the base commit's 402 files exactly |
| Maven change set | 4 dependencies added; 5 dependency versions moved (3 found by the build and unit suite, 2 by deployment); 4 build plugins moved; 9 candidates withdrawn |
| Removed EE APIs reinstated | 137 `javax.xml.bind` import lines in 84 tracked Java sources (82 main, 2 test) across 21 Maven modules; 4 `javax.annotation` lines in 4 files; 8 `javax.activation` lines in 6 files; zero JAX-WS-family imports. Counted with `git grep -c '^import <package>' -- '*.java'` |
| Frontend change set | 108 → 86 dependencies + 1 devDependency; 6 forced package changes; 22 removals; 9 aliases; 53 GitHub-sourced specs; 19 unchanged, decomposing as **12** withdrawn candidates (8 probe-cleared build plugins + 4 Node-API packages) and **7** that were never candidates |
| Committed lockfile | `lockfileVersion` 3; 451 entries (397 registry, 53 git, 0 tarball URLs); `yarn.lock` deleted (275,865 bytes) |
| Gruntfile | unchanged — zero-byte diff |
| Module-access directives | 8 test-scope, plus **1** production-scope open (`java.base/java.lang`) that Apache Tomcat's own launcher already supplies; ArkCase's own `JAVA_OPTS` adds none |
| Static audit | 7 hits before, **0** after, in both main and test sources |
| CI | image `1.0.2` → `2.0.0`; 4 removals of a JVM flag JDK 14 deleted |

## Honest disclosures

Collected in one place so that none of them has to be discovered by cross-reading.

- **Nothing here rests on third-party commentary.** No upgrade guide, forum answer or vendor page is cited anywhere in this inventory; every claim rests on registry metadata, artifact inspection, the committed files, or a command that was executed and whose output is quoted.
- **Two of the five version moves were invisible to the build and the unit suite, and an earlier version of this page therefore recorded EclipseLink as exonerated.** It was not. Deploying the artifact and logging in proved that EclipseLink's repackaged ASM cannot read release-17 bytecode and that Spring LDAP 2.3.3 cannot be class-initialised on Java 17 at all. Both are inventoried above with their reproductions; the JPA runtime itself still does not move. The general lesson is recorded rather than smoothed over: a green reactor build and a green unit suite are **not** sufficient evidence that a runtime migration works.
- **`ui-grid-draggable-rows` moved versions, and the move was forced.** The base-commit pin 0.2.2 was never published. The registry's lowest available release is 0.3.0, not 0.3.3; the manifest takes 0.3.3, the newest of the four published. An earlier note that called 0.3.3 "the lowest available" is corrected here.
- **Two of the 53 git specs resolve forward of the base commit**, and neither is a choice: `ace-builds#semver:^1` and `angular-dynamic-locale#semver:^0.1.32` are floating ranges, so a faithful rewrite takes whatever tag now tops them (1.44.0 and 0.1.38). Re-pinning either would restate a declared range. The other 51 resolve to the identical base-commit commit.
- **`multi-download`'s `browser.js` is not installed**, because npm applies the package's own `"files": ["index.js"]` allowlist to a git dependency while yarn extracted the whole repository tarball. One asset path therefore does not resolve and the `multiDownload` global is absent from `vendors.min.js`. It is recorded above with its callers and left unfixed under **R-6**; the recorded acceptance artifacts were measured in this state.
- **Eight of the 22 frontend removals are cleanup, not compatibility fixes.** Most of them still install on Node 20. Calling them compatibility fixes would misrepresent both halves of R-4.
- **The war-plugin bump is a JDK 17 encapsulation failure inside the plugin, and an earlier attribution to the Maven container is corrected here.** The plugin's `war` mojo cannot initialise on JDK 17 because the XStream instance it builds reflects into `java.util.TreeMap`; the same plugin and the same Maven 3.8.7 succeed on JDK 8. The full diagnostic is in the build-plugin table.
- **Surefire 2.12.4 is not globally broken on JDK 17.** A plain JUnit 4 test runs fine under it. The recorded reason is the specific late-`argLine`-substitution capability, nothing broader.
- **`maven-compiler-plugin` 3.13.0 and `maven-surefire-plugin` 3.5.3 are not the newest releases of their lines.** Newer 3.x releases exist for both. They are pinned choices comfortably past the capability floor each change actually needs — 3.6+ for `<release>`, 2.17+ for late substitution — and neither is claimed to be a line-top.
- **The sass watcher boundary is 1.79.0, not 1.78.** Both 1.77.8 and 1.78.0 declare the same watcher range; 1.79.0 is where it moves. The tilde is still load-bearing, but for the reason stated in the forced-change table.
- **The committed lockfile carries two watcher copies, not one hoisted copy** — one at the top level for the template renderer and one nested under sass. The tilde's function is to keep the recorded tree reproducible under strict validation, not to collapse the two.
- **PowerMock carries three cglib exclusions, not four.** Measured on the three coordinates that declare them.
- **The frontend withdrawals enumerate to twelve, and the decomposition is not the obvious one.** "Twelve" is also the size of the load-probe set, which is a coincidence worth naming: of the twelve probed packages ten loaded cleanly and two were replaced, and of those ten, two — `grunt-contrib-clean` and `grunt-contrib-concat` — were never candidates for an upgrade in the first place. So the twelve withdrawals are **8** probe-cleared build plugins plus the **4** Node-API packages, and 12 withdrawn + 7 never candidates = the 19 unchanged.
- **The identical `javax/xml/bind` class set is 110 classes, not 121.** Re-measured by comparing the two jars' entry lists directly. The substantive claim — that the sets are identical, so excluding the duplicate API loses no type — is unaffected and is what the exclusion rests on.
- **Three figures in the plan are not what this environment measures** — 274 reactor modules, 142 test-bearing modules and the 773-test total. Both sets are published side by side in [Figures that differ from the plan](#figures-that-differ-from-the-plan); the plan's acceptance criteria are not amended by a measurement taken here.
- **Nothing on this page was fixed.** Per R-6, the defects encountered while compiling this inventory — the duplicate servlet-API declaration among them — are documented in [Known issues](known-issues.md) and deliberately left alone.

## Related records

| Record | What it owns |
| --- | --- |
| [Module-access exceptions](add-opens-exceptions.md) | The eight test-scope directives and the one runtime open, each attributed to the pinned library and the exact stack frame that demanded it, and the certification of what this repository does and does not grant |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative test totals, the two class-level exclusions and their collateral cost |
| [Static audit](static-audit.md) | The audit command, the seven classified hits before and the zero after |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour, including the withdrawals summarised here |
| [Known issues](known-issues.md) | Pre-existing defects documented and deliberately not fixed |
| [Smoke evidence](smoke-evidence.md) | The baseline-then-migrated smoke capture and the reduced-local-stack rationale |
