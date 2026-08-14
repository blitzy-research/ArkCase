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
| Test Java sources | 402 → **407** | The migration **edits none** — all 402 base-commit sources are byte-identical — and **adds five**, covering only code this migration itself wrote. A sixth addition is a Node test file, `scripts/ensure-profiles.test.js`, which this count does not include because it is not Java |
| POMs declaring compiler settings | **1** | The root POM. No module overrides `source`, `target` or `release` |
| POMs this migration edits | **1** | The root POM, and only the root POM |
| POMs declaring a test runner | **1** surefire, **3** failsafe | Surefire is undeclared at the base commit and is declared by this migration in the root POM. Failsafe is declared in the root POM and, at the base commit, in the `coreBuild` profiles of `acm-foia` and `acm-privacy`; those two are left exactly as the base commit wrote them and are recorded in [Known issues](known-issues.md) |
| `acm-jmeter` | not built | Present on disk as JMeter assets, has no `pom.xml`, and is absent from `<modules>` |

Toolchain versions actually used, all installed outside the checkout: **JDK 17.0.20** (Eclipse Temurin) as the target runtime, **JDK 1.8.0_502** as the baseline runtime, **Maven 3.8.7** on both sides, **Node v20.20.2** and **npm 10.8.2**. An earlier capture taken while the migration was being designed used JDK 17.0.19 and JDK 1.8.0_492 and reached the same conclusions, so no result here depends on the patch level of either JDK; both pairs may be encountered across this documentation set.

### Figures that differ from the plan

Three figures in the migration plan's validation section are not what this environment measures. **The delivered build therefore does not satisfy those stated figures, and that is reported here as a divergence from the frozen plan** — set out side by side rather than replaced, because the plan is not amended here: a measurement is evidence about a run, not authority over a frozen acceptance criterion. [The smoke record](smoke-evidence.md#figures-that-differ-from-the-plan) owns this comparison in full, including the commands and what remains for the plan's owner to decide; the rows below exist so that a reader of *this* page reconciles against the same pair of numbers.

| The plan states | This environment measures | Note |
| --- | --- | --- |
| 274 reactor modules | **142** | The delivered gate-1 build ends at `[142/142]` and its Reactor Summary lists 142 rows; the repository holds 145 `pom.xml` files in total. The plan's 274 is reproducible as a log artefact rather than a module count — that build log carries 274 lines beginning `[INFO] Building `, which are the 142 module headers plus 131 `Building jar:` and 1 `Building war:` line. Where this page needs a reactor-wide claim, it says 142 |
| 142 test-bearing modules | **76** carry test sources, **68** execute unit tests | The 8-module gap is modules whose only tests are `*IT.java` integration tests, which Failsafe owns. 142 is the whole reactor's size in this environment, which is what makes the plan's use of the same figure for test-bearing modules ambiguous; JaCoCo, by contrast, genuinely is bound in all 142 |
| 773 tests, 0 skipped | measured totals belong to [Baseline test failures](baseline-test-failures.md) | That page reads them from surefire's own XML reports. Every reported skip is a pre-existing `@Ignore` in an unchanged baseline source, so a zero-skip run would require deleting annotations that **R-5** and the preserve-assertions mandate both protect |

## Track A — Java 8 to Java 17

Four dependencies were added, **five** dependency versions moved, and four build plugins moved. Nine candidate changes were withdrawn, and one managed entry was added, measured and reverted. Two of the five version moves were found only by deploying the application; the unit suite is green with and without them.

**Five POMs differ from the base commit, not one.** The root `pom.xml` carries every version, property and plugin movement — that part of the plan's mapped surface holds exactly. Four module POMs carry nothing of the kind: `acm-web` and `acm-services/acm-service-convert-file` each add a test-scope declaration whose version and scope are inherited from the root, and `acm-standard-applications/acm-foia` and `acm-standard-applications/acm-privacy` each change one `<version>` element from a hardcoded `2.17` to the root's `${surefire.version}`. **No module POM introduces, removes or re-versions a dependency of its own, and none gains a plugin or a property.** Each of the four is justified individually in [Changes beyond the plan's mapped POM and manifest surface](#changes-beyond-the-plans-mapped-pom-and-manifest-surface), and the reproducible check is `git diff c8f6226105 --stat -- '**/pom.xml'`.

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

The reinstated surface is kept `javax`-only by **exclusions**, and this section states what they are before it explains them, because an earlier revision of this page claimed the opposite and that claim was wrong.

`grep -i jakarta pom.xml` returns **20 lines**, decomposing exactly:

| Kind | Lines | Detail |
| --- | ---: | --- |
| `<groupId>`/`<artifactId>` element lines inside `<exclusion>` blocks | **14** | Distributed over **8** jakarta-bearing exclusion entries. Six contribute two lines each; two contribute one each, because their `<groupId>` is `com.sun.activation` and only the artifact is jakarta-named |
| Comment lines explaining those exclusions | **6** | Prose at the exclusion sites |
| `<dependency>` or `<dependencyManagement>` entries naming a jakarta coordinate | **0** | No EE 9 artifact is declared anywhere |

Those 8 are the jakarta-named part of a larger set, and the whole set is stated so this table is not mistaken for the total: the root POM's exclusion pairs go from **34 at the base commit to 52**, none removed, so the change set **adds 18**. The other 10 remove `javax`- and `com.sun`-coordinate duplicates of the same packages — `javax.activation:activation` 1.1 at five sources, `javax.activation:javax.activation-api` at one, and `com.sun.xml.bind:jaxb-core` and `jaxb-impl` at two sources each. The criterion is one owner per package, not one namespace; see [behavioural decisions, resolution 25](behavioral-decisions.md#25-every-duplicate-of-a-reinstated-provider-is-excluded-and-the-coordinate-namespace-is-not-the-criterion).

The 8 jakarta-bearing exclusion entries sit on five dependencies:

| Dependency carrying the exclusion | jakarta coordinates it excludes |
| --- | --- |
| `org.glassfish.jaxb:jaxb-runtime` **2.3.9** — the declared runtime provider | `jakarta.xml.bind:jakarta.xml.bind-api`, `jakarta.activation:jakarta.activation-api`, `com.sun.activation:jakarta.activation` |
| `org.jvnet.staxex:stax-ex` | `jakarta.xml.bind:jakarta.xml.bind-api`, `jakarta.activation:jakarta.activation-api` (and, separately, `javax.activation:activation`) |
| `org.apache.cxf:cxf-rt-rs-client` | `jakarta.xml.bind:jakarta.xml.bind-api` |
| `org.apache.camel.springboot:camel-spring-boot` | `jakarta.xml.bind:jakarta.xml.bind-api` |
| `org.apache.tika:tika-parsers` | `com.sun.activation:jakarta.activation` |

**What that means for the requirement.** The migration's exclusion of the `jakarta` namespace is a *source-level* requirement, and it is met absolutely: `grep -rl "^import jakarta" --include=*.java` returns no file, main or test, and all 137 `javax.xml.bind` import lines, the 4 `javax.annotation` imports and the 8 `javax.activation` import lines are byte-identical to the base commit. The 14 element lines above are the mechanism that keeps it met on the classpath, not a breach of it: every one of them removes an EE 9 coordinate rather than adding one.

**What it costs, measured rather than asserted.** These exclusions do change `WEB-INF/lib` relative to the archived Java 8 baseline WAR. Measured with `mvn -o dependency:list -DincludeScope=runtime` on the WAR module and compared against `unzip -l` of the baseline artifact:

| Baseline WAR | Migrated runtime classpath | Effect of the exclusions |
| --- | --- | --- |
| `jakarta.xml.bind-api-2.3.2.jar` | absent | Removed. All four routes to it are excluded |
| `jakarta.activation-1.2.1.jar` | absent | Removed |
| `activation-1.1.jar` | absent | Removed. Excluded at all five routes that declare it — `stax-ex`, `javax.mail:mail`, `javax.mail:mailapi`, `com.sun.mail:javax.mail` and `io.milton:milton-server-ce` |
| `jaxb-core-2.2.11.jar`, `jaxb-impl-2.3.3.jar` | absent | Removed. Excluded on `org.apache.camel:camel-xml-jaxb` and `org.apache.cxf:cxf-rt-databinding-jaxb`, the two routes that declare them |
| `jaxb-runtime-2.3.2.jar`, `txw2-2.3.2.jar` | `jaxb-runtime` **2.3.9**, `txw2` **2.3.9** | Version movement, from declaring the provider explicitly |
| `jakarta.annotation-api-1.3.5.jar`, `jakarta.ws.rs-api-2.1.5.jar` | **still present** | Untouched: nothing excludes them, and they are base-commit transitives |
| — | `javax.xml.bind:jaxb-api-2.3.1`, `com.sun.activation:javax.activation-1.2.0`, `javax.annotation:javax.annotation-api-1.3.2` | Added: the reinstated shim itself |

So two statements have to be made together rather than one at the expense of the other. **No EE 9 coordinate is new to the deployed classpath** — the two that remain were already there at the base commit. And **five jars the baseline shipped are gone**, which is a real delta and is what the exclusions buy: a single unambiguous `javax` JAXB provider on every classpath, with no jar shipping a duplicate `javax/xml/bind/**` or `javax/activation/**` class.

That last clause is measured across the reactor rather than inferred from the WAR module alone. `mvn -o -B dependency:list -DincludeScope=test`, parsed per module, reports `javax.xml.bind:jaxb-api:2.3.1`, `org.glassfish.jaxb:jaxb-runtime:2.3.9` and `com.sun.activation:javax.activation:1.2.0` on **142 of 142** module classpaths, each exactly once, and **0 of 142** additionally carrying `jakarta.xml.bind-api`, `jakarta.activation-api`, `com.sun.activation:jakarta.activation`, `javax.activation:activation`, `jaxb-core` or `jaxb-impl`. The two surviving EE 9 API jars appear on **58 of 142**, unchanged from the base commit.

The rest of this section is the evidence for why that trade was taken.

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

That last row is the one the whole exercise is for. Before convergence, `jaxb-impl` shipped a `META-INF/services/javax.xml.bind.JAXBContextFactory` entry that `ContextFinder` consults *before* the legacy entry, so JAXB resolved through a different provider on modules that had it than on modules that did not. It is now unambiguous everywhere.

**No test pins that property, and this record will not claim one does.** An earlier revision cited a `JaxbProviderAndXxeTest` in `acm-tool-integrations/acm-object-converter` as asserting exactly one visible `javax/xml/bind/JAXBContext.class`, one `javax/activation/DataHandler.class`, one legacy service entry and zero `JAXBContextFactory` entries. **That class does not exist anywhere in the repository** — it was one of the five migration-added test classes that were removed under the scope decision recorded in [behavioural decision 21](behavioral-decisions.md#21-not-everything-a-migration-change-touches-belongs-in-the-migration), and the citation outlived it. The convergence property is therefore established by the classpath measurement above and by nothing else, which means **it can regress silently**: a future dependency addition that reintroduces a second `javax.xml.bind` provider would not fail any build. Re-running the measurement is the only check that exists.

#### Eight jars that appear with no POM change at all

A reviewer comparing the two WARs will find eight jars in the migrated one that are absent from the Java 8 baseline: `jaxws-api`, `javax.xml.soap-api`, `saaj-impl`, `mimepull`, `geronimo-ws-metadata_2.0_spec`, `geronimo-jta_1.1_spec`, `jboss-rmi-api_1.0_spec` and `jacorb-omgapi`. **No POM in this repository asks for any of them**, and after the `cxf-core` entry above was reverted they still appear. The reason is not a dependency change:

`cxf-parent` 3.3.5 — the parent of `cxf-rt-rs-client`, which arrives transitively from `tika-parsers` 1.24 — declares a profile `id=java9-plus` with `<activation><jdk>[9,)</jdk></activation>`, and that profile's dependency list is exactly this set (plus `javax.annotation-api` and `javax.activation`, both of which the reactor already declares explicitly). The profile is inactive under JDK 8 and active under JDK 17, so the artifacts appear purely because the build now runs on a newer JDK.

They are there for precisely the reason this migration reinstates JAXB: the JDK no longer ships those EE APIs, and CXF supplies its own replacements when it detects a modular JDK. This is third-party JDK-conditional resolution behaving correctly. It is recorded here so it is neither mistaken for scope creep nor "fixed" by an exclusion that would break SAAJ on the CXF paths that need it.

#### A managed entry that was added, measured, and removed again

One entry in this group was **wrong and is recorded rather than quietly deleted**, because the failure mode is easy to repeat. An earlier revision managed `org.apache.cxf:cxf-core` for the sole purpose of excluding `jakarta.xml.bind-api` from it. Only `cxf-core` **3.3.5** declares that dependency; the version this reactor actually mediates for the WAR, **3.0.12**, does not declare it at all. So the entry had to name 3.3.5 to have anything to exclude — and in naming it, forced it.

Diffing the produced WAR's `WEB-INF/lib` against the archived Java 8 baseline WAR showed the cost precisely: `cxf-core` 3.0.12 → 3.3.5, `xmlschema-core` 2.2.1 → 2.2.5, `woodstox-core-asl` replaced by `woodstox-core`, and **eleven** jars added that nothing in the reactor asked for — `jaxws-api`, `saaj-impl`, `javax.xml.soap-api`, `mimepull`, `geronimo-ws-metadata_2.0_spec`, `geronimo-jta_1.1_spec`, `jboss-rmi-api_1.0_spec` and `jacorb-omgapi` among them. **R-1** forbids a dependency change without a Java 17 reason, and there was none. The entry was removed, the exclusion moved to `cxf-rt-rs-client` where it costs no version movement, and all thirteen `cxf-*` artifacts now match the baseline WAR exactly. A comment at that position in the POM records why no `cxf-core` entry belongs there.

**Why the jars the eight jakarta exclusions do prune are pruned, stated against the baseline.** The archived Java 8 baseline WAR — built from the base commit before any migration work — ships `jakarta.xml.bind-api-2.3.2.jar`, `jakarta.activation-1.2.1.jar`, `activation-1.1.jar`, `jakarta.ws.rs-api-2.1.5.jar` and `jakarta.annotation-api-1.3.5.jar` in `WEB-INF/lib`, all of them transitives of base-commit third-party dependencies. The delivered exclusions remove the first three and leave the last two, so the deployed classpath loses jars the base commit shipped. That is the delta tabulated at the top of this section, and it is the price of a single unambiguous provider.

The counter-argument was considered and is recorded, because it is a reasonable position and it lost on a specific point rather than on preference. It runs: no EE 9 coordinate is *new* to the deployed classpath, the duplicate `javax.xml.bind` API jars are byte-compatible — `unzip -Z1 … | grep '^javax/xml/bind/.*\.class$' | sort` over both API jars yields **110** classes each and `diff` on the two lists is empty — so whichever jar a classloader reaches first, every type resolves to the same class name, and leaving them alone would preserve the baseline `WEB-INF/lib` exactly. What defeats it is not the duplicate classes but the duplicate **service registration**: `jaxb-impl` ships a `META-INF/services/javax.xml.bind.JAXBContextFactory` entry that `ContextFinder` consults before the legacy entry, so JAXB resolved through a different provider on modules that had it than on modules that did not, and identical class *content* does not make that identical *behaviour*. The exclusions remove the ambiguity; the pruned jars are what they cost.

Two consequences are recorded rather than smoothed over. The pruning is a `WEB-INF/lib` change relative to the base commit, which the preserve-behaviour mandate would rather not have. And it is not pinned by any test, as the preceding note says. Both belong to whoever ratifies the provider convergence.

**The namespace point, stated plainly, because it is an explicit exclusion of this migration:** no EE 9 artifact is *declared*, and no import anywhere is rewritten to that namespace. All 137 `javax.xml.bind` import lines, the 4 `javax.annotation` imports and the 8 `javax.activation` import lines are byte-identical to the base commit, and `git grep -n jakarta -- '*.java'` returns nothing across all 3,055 main and 402 test sources — no import, no qualified reference, not even in a comment.

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

The first three were found by compiling and testing. The last two could **only** be found by deploying, and they are the more serious pair: each one, left alone, stops the application dead on Java 17 while the whole unit suite stays green — 917 configured tests with 0 failures and 0 errors, the total owned by [Baseline test failures](baseline-test-failures.md). They are described in their own subsections below the table.

| Property | Old → New | The reproduced failure |
| --- | --- | --- |
| `easymock.version` | 4.1 → 4.3 | `IllegalArgumentException: Unsupported class file major version 61`, raised from `org.easymock.asm.ClassReader` through the CGLIB enhancer during mock creation. **The nuance that matters:** the failing reader is EasyMock's own **repackaged** ASM, so raising the top-level `asm.version` property does nothing for it — which is why that property is withdrawn below. Jar-level proof: the `Opcodes` class in easymock 4.1 stops at `V14`, while 4.3 carries `V15`, `V16` and `V17`. Registry-verified as the **last 4.x release ever published**, so it is simultaneously the minimal fix and the top of its line; a 5.x line exists but raises the language baseline and would be an unnecessary major bump |
| `spring.version` | 5.3.2 → 5.3.39 | `IllegalArgumentException: Name for argument of type [java.lang.String] not specified, and parameter name information not found in class file either`, in three MVC controller tests. spring-core 5.3.2's repackaged ASM stops at `V16`, so the parameter-name discoverer cannot parse a major-61 class file and silently yields no names. Registry-verified as the **latest 5.3.x**, which is also the generation the migration is required to stay inside |
| `spring.security.version` | 5.4.2 → 5.4.11 | Moves in lockstep with Spring 5.3.x, against which Spring Security 5.4.x is built. Registry-verified as the **latest 5.4.x**. Staying inside 5.4.x additionally preserves the `spring-security-5.4.xsd` namespace that eight configuration files in the external configuration repository reference — moving off the line would have forced a rewrite outside this checkout |
| `eclipselink-asm.version` (**new property**) — **NOT MAPPED BY THE FROZEN PLAN; ratified — see [the two out-of-plan version moves](#the-two-out-of-plan-version-moves-ratified-at-the-final-acceptance-gate)** | 2.6.0 → 9.1.0 | EclipseLink's separately published bytecode reader cannot read class-file 61, so **every `@Entity` silently disappears from the persistence unit** and the root application context fails to start. Full attribution below |
| `spring.ldap.version` — **NOT MAPPED BY THE FROZEN PLAN; ratified — see [the two out-of-plan version moves](#the-two-out-of-plan-version-moves-ratified-at-the-final-acceptance-gate)** | 2.3.3.RELEASE → 2.3.4.RELEASE | `IllegalAccessError` in `AbstractContextSource.<clinit>` under JEP 396, so **every login returns HTTP 500**. Full attribution below |

Two constraints bound the Spring pair. The generation is **capped deliberately**: no Spring 6 and no Spring Boot, both explicit exclusions of the migration. And both Spring properties move only to the newest patch of the generation already in use, so neither is a feature upgrade. The same discipline governs the last two rows: `org.eclipse.persistence.asm` is the *only* EclipseLink coordinate that moves — the ORM stays at 2.6.0 — and spring-ldap moves by a single patch inside 2.3.x.

### The two out-of-plan version moves: ratified at the final acceptance gate

Two of the five dependency version changes above are **not mapped by the migration plan**, and this record states that before it states their evidence, because evidence is not a substitute for authorisation. Both were **ratified at the final acceptance gate**, on one shared ground: the plan's own deployment and login gates cannot pass without them. That is what closes them — a divergence carried on reproduced evidence *and* required by the plan's own definition of done is a decision, not an open item. The reproductions are below so the ratification is auditable rather than asserted.

| Change | What the frozen plan says | Status |
| --- | --- | --- |
| `eclipselink-asm.version` **new property**, 2.6.0 → 9.1.0 | §0.5.5 formally **withdrew** every EclipseLink candidate, including explicitly the option of introducing a second, separately versioned ASM property. The plan's dependency inventory lists `org.eclipse.persistence:eclipselink` 2.6.0 as **unchanged** | **Divergence.** Delivered |
| `spring.ldap.version` 2.3.3.RELEASE → 2.3.4.RELEASE | Spring LDAP appears **nowhere** in the plan's change set, its version property block, or its withdrawn-candidate list. No spring-ldap movement is mapped | **Divergence.** Delivered |

Both were delivered rather than withdrawn because each was reproduced as a **deployment blocker**: without them the root Spring context does not come up and the application serves nothing — the entity metamodel comes up empty and every request 404s in the first case, every login returns HTTP 500 in the second. Neither failure is visible to a reactor build or to the unit suite, which is why the plan's evidence base did not contain them: the plan's justification for leaving EclipseLink alone was "no failure materialised in the full suite", and that statement is still true and still insufficient.

**Reverting them is not the alternative.** Removing either change reintroduces a reproduced, total failure of the deployed application; that is why neither was withdrawn on discovery of the conflict.

**What a human must do.** Ratify both as formal revisions to the plan's dependency change set — recording, for each, the reproduced deployment failure, the artifact and version, and the blast-radius argument set out in the two subsections below — or direct an alternative that keeps the deployment working. Until that happens these two entries are a documented divergence, not settled migration design, and the root `pom.xml` labels them the same way at their declaration sites. Everything that follows is the evidence for the technical claim, not for the authorisation.

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

**How this stands against the withdrawn EclipseLink candidate.** It does not reconcile with it, and the honest statement is that this change goes beyond what the plan authorises — see [the two out-of-plan version moves](#the-two-out-of-plan-version-moves-ratified-at-the-final-acceptance-gate). What can be said in mitigation, and is offered as the substance of the ratification request rather than as a claim of compliance:

- The planning decision to leave EclipseLink at 2.6.0 was justified by "no failure materialised in the full suite", and that remains literally true — the configured suite is 917 tests with 0 failures and 0 errors, with or without this change. The suite simply cannot see this defect, because a unit test does not build a container-managed persistence unit over the whole entity graph. The justification was sound on its evidence and the evidence was incomplete.
- The withdrawal was about the **ORM**, and the ORM does not move: 2.7.16 is still not taken, and `org.eclipse.persistence.core`, `.jpa` and `.moxy` stay at 2.6.0. This change is strictly smaller than the one withdrawn — one reader rather than the persistence provider.
- The plan anticipated the mechanism it withdrew, observing that from 2.7.x the ASM artifact is versioned independently and "a second property would have had to be introduced". That property now exists, and it carries the measurement in a POM comment that also labels it a divergence.

None of those three makes the change authorised. They are the argument a ratification decision should weigh.

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

In other words upstream applied **the same indirection this migration applied to the subclass**, which is a strong argument that the approach is right and that the patch release is the correct way to obtain it. The provider actually used is unchanged, the move stays inside 2.3.x, and — decisively for **R-2** — it means no `add-exports` directive is needed in production launch configuration. The alternative, granting `java.naming/com.sun.jndi.ldap` to the unnamed module in `JAVA_OPTS`, was rejected on that rule: a dependency patch that removes the need for a flag is always preferable to documenting the flag.

None of that makes the change *mapped*. Spring LDAP is not in the plan's change set at all, so it remains a divergence — see [the two out-of-plan version moves](#the-two-out-of-plan-version-moves-ratified-at-the-final-acceptance-gate) — but it is a **ratified** one, because the plan's login gate cannot pass with 2.3.3 in place.

**The mechanism, at bytecode level.** In `spring-ldap-core` 2.3.3, `AbstractContextSource.DEFAULT_CONTEXT_FACTORY` is declared `java.lang.Class<com.sun.jndi.ldap.LdapCtxFactory>` and the class initialiser executes `ldc #124 // class com/sun/jndi/ldap/LdapCtxFactory` followed by `putstatic` — a cross-module type resolution during static initialisation. In 2.3.4 the same field is declared `java.lang.String` and the constant is loaded as `ldc // String com.sun.jndi.ldap.LdapCtxFactory` from inside a method, so nothing resolves the encapsulated type at all. Established by disassembling both jars with `javap -p -c`.

**The reproduction.** Initialising `org.springframework.ldap.core.support.LdapContextSource` against each jar in turn on JDK 17.0.20, with an otherwise identical classpath:

| Version | Result |
| --- | --- |
| 2.3.3.RELEASE | `java.lang.IllegalAccessError: class org.springframework.ldap.core.support.AbstractContextSource (in unnamed module @0x5ea1fbda) cannot access class com.sun.jndi.ldap.LdapCtxFactory (in module java.naming) because module java.naming does not export com.sun.jndi.ldap to unnamed module @0x5ea1fbda` |
| 2.3.4.RELEASE | Initialises cleanly |

**What 2.3.3 breaks, named precisely.** `LdapContextSource` extends `AbstractContextSource`, and the reactor constructs one in three places: `acm-services/acm-service-users` `SpringLdapDao:60` builds one per directory, `AcmLdapRegistryServiceImpl:333` registers one as a bean definition, and `acm-service-login`'s `spring-library-child-context.xml:34` declares one. Note what is **not** in that chain: `ActiveDirectoryAbstractContextSource` implements `BaseLdapPathContextSource` directly and does not extend `AbstractContextSource`. An earlier revision of this record attributed the breakage to that class, which was wrong; the attribution above is read from the declarations.

The provider string selected is identical on both versions and the move stays inside 2.3.x, so nothing about LDAP behaviour changes — only whether the class can initialise at all.

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
| `maven-surefire-plugin` | undeclared, inheriting Maven's 2.12.4 default → 3.5.3 | 2.12.4 does not perform late `@{…}` property substitution, so the JaCoCo agent argument and the JDK 17 module-access directives cannot coexist — the fork dies with `Error: could not open '{argLine}'` followed by `The forked VM terminated without saying properly goodbye`. Under 3.5.3 the identical configuration passes. **Stated precisely:** 2.12.4 is **not** globally broken on JDK 17 — a plain JUnit 4 test runs fine under it — so the recorded reason is the specific late-substitution capability needed to combine coverage enforcement with a documented module-access exception, not a blanket incompatibility. Declaring it would also have had a measurable side effect on **which** tests run, and the delivered configuration deliberately prevents it: 3.5.3's *default* includes add `**/*Tests.java`, which 2.12.4 omits, so an explicit `<includes>` trio — `**/Test*.java`, `**/*Test.java`, `**/*TestCase.java` — pins discovery to 2.12.4's default set. Four dormant pre-existing tests therefore stay dormant instead of being woken by a toolchain bump, which is the R-7 outcome. The trio and the four tests are enumerated in [the baseline record](baseline-test-failures.md) |
| `maven-failsafe-plugin` | 2.17 → `${surefire.version}` (**3.5.3**) | **Not a repair — a mandated single pin.** The plan specifies one pin for both forked runners (AAP §0.4.1, §0.5.4: failsafe at `${surefire.version}`), and the AAP is the frozen source of truth, so the alignment is carried on that authority rather than on a compatibility failure. It is stated plainly that 2.17 is **not** broken: the probe below shows 2.17 performing the late `@{argLine}` substitution correctly. What the move buys is the removal of a second, independently-drifting version pin — and the `failsafe.version` property that held it is deleted, so there is no longer anywhere for the two runners to disagree |

**Why the failsafe move is carried on the plan's authority rather than on a failure, and what was measured before it was carried.** An earlier revision of this record reverted failsafe to 2.17, reasoning that R-1 forbids a change with no reproduced failure behind it. That reasoning was wrong about precedence: the AAP is the frozen, agreed-upon specification and it names `${surefire.version}` for failsafe explicitly, so the alignment is a plan requirement, not an unjustified version movement. R-1 governs changes the plan does not mandate. The move is therefore carried — and, because it is not a repair, both measurements are kept so nobody re-derives them or mistakes the reason.

- **2.17 is not broken, in isolation:** a project pinned to 2.17 with `@{myArg} --add-opens java.base/java.util=ALL-UNNAMED` as its `argLine` runs an integration test asserting the late-substituted property actually reached the fork, and it passes — `Tests run: 1, Failures: 0, Errors: 0`. Late substitution has existed since 2.17.
- **3.5.3 is safe in this reactor, against a real integration test:** with the delivered POM (no property override), `mvn -o -B -pl acm-tool-integrations/acm-encryption verify` on JDK 17.0.20 under Maven 3.8.7 loads `maven-failsafe-plugin:3.5.3:integration-test` and `:verify`, runs `AcmEncryptablePropertyUtilsImplIT` green — 2 tests, 0 failures, 0 errors — and the JaCoCo `check` goal reports "All coverage checks have been met". Under `-X` the forked JVM's command line carries the **expanded** JaCoCo agent argument (`-javaagent:…/org.jacoco.agent-0.8.7-runtime.jar=destfile=…`), **zero** occurrences of the literal `@{argLine}`, and both `--add-opens java.base/java.time=ALL-UNNAMED` and `--add-opens java.base/java.lang=ALL-UNNAMED`. The 3.5.3 and 2.17 runs are indistinguishable in outcome, which is exactly why the reason recorded above is the mandate and not a defect.

**Where the pin now lives, and how the "one pin for both runners" claim is held.** The `failsafe.version` property is **deleted**. Three declarations name failsafe — the root plugin and the `coreBuild` profiles of `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` — and all three consume `${surefire.version}`, so no module can diverge and a profile-local value cannot silently outrank the root's configuration where integration tests actually run. Two reproducible checks: `grep -rn "<version>2.17</version>" --include=pom.xml .` matches nothing, and `help:effective-pom` reports failsafe **3.5.3** — at the root under `-N`, and in both of those modules' plugin blocks under `-DcoreBuild=true` (four occurrences, all 3.5.3). In those two module POMs the **only** element that changed is `<version>`: the `<executions>`, `<goals>` and `<skipTests>true</skipTests>` they carry are untouched, so **which** integration tests run under `-DcoreBuild=true` is exactly what the base commit specified.

### The compiler contract

The compiler contract lands as a single inherited property: `maven.compiler.release=17` replaces `java.version=1.8`. Two properties of that change are what **R-3** actually turns on, and both were verified by enumeration rather than assumed:

- The `source`, `target` and `compilerVersion` trio is **deleted** — from the compiler plugin's default configuration *and* from its `log4j-plugin-processor` execution — leaving **no `${java.version}` reference anywhere** in any POM. Merely adding a `release` property would have left the older settings winning, so deletion is the operative act.
- **Exactly one** of the 145 POMs declares compiler settings, and **zero** declare `source`, `target`, `release` or `compilerVersion` at module level. There is no module-local override to police, and no place for a release-8 escape hatch to reappear unnoticed.

The executable evidence is a build-log difference: the baseline JDK 17 run emitted `bootstrap class path not set in conjunction with -source 8`, and after the change that warning is gone and javac reports `[debug deprecation release 17]`. A separate finding reinforces the rule — the escape hatch would not even have worked, because `javac --release 8` on a JDK 17 JVM still fails on the encapsulated JNDI package that the migration had to externalise. That analysis belongs to [Static audit](static-audit.md).

### Changes beyond the plan's mapped POM and manifest surface

R-1's scope is every manifest and POM, so the entries that sit outside the plan's file-explicit mapping are recorded here individually rather than folded into the tables above. Each is carried because a security review established that leaving it out costs something concrete, and each names that cost. The plan's mapping is not being reinterpreted: it is being exceeded, knowingly, in five narrow places.

| Change beyond the mapping | What it buys | Why it is carried rather than declined |
| --- | --- | --- |
| `acm-services/acm-service-convert-file/pom.xml` — test-scope `junit` and `org.easymock:easymock` | Lets `MimeMessageParserTest` drive the inline-image path with a `javax.mail.Part` that yields a plain stream, and with parts declaring a non-base64 transfer encoding | The parser's cast was widened as part of this migration, which removed the check that rejected non-base64 inline content. That regression was found by review, not by the build, and a restored check with no test is a check nobody will notice breaking again. Versions and scope are inherited from the root `dependencyManagement`, so no version is introduced |
| `acm-web/pom.xml` — test-scope `junit` | Lets `DistributiveEventMulticasterTest` cover the two methods Spring 5.3.5 added to `ApplicationEventMulticaster` | Those two methods are written *by this migration* against an interface that grew under it. Nothing else in the reactor exercises the delegation and no-op contracts they implement |
| `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` — Failsafe `2.17` → `${surefire.version}` | One reactor-wide pin for both forked runners, in every module | Leaving them at `2.17` would make the plan's "one pin for both forked runners" mandate false wherever the `coreBuild` profile activates, because a profile-local `<version>` outranks the inherited declaration there. The reason is that mandate, **not** a defect in 2.17: the probe on this page shows 2.17 performing late `@{argLine}` substitution correctly, and an earlier revision of this row wrongly claimed otherwise. Only the `<version>` element changed: `<executions>`, `<goals>` and `<skipTests>true</skipTests>` are untouched, so **which** tests run under `-DcoreBuild=true` is unchanged. Verified on the delivered tree: with `-DcoreBuild=true` the profile activates, `help:effective-pom` reports failsafe **3.5.3** in both plugin blocks, and `mvn -o` resolves the plugin offline |
| An `.npmrc` setting `engine-strict=true`, staged into the deploy-time temp folder | Turns the declared `engines` range from advice into a precondition | Without it the range is documentary: npm's default is `engine-strict=false`, so a superseded runtime prints `EBADENGINE` and builds a bundle anyway — the exact outcome **R-4** exists to prevent. Measured both ways: with the file present, `npm ci` on Node 20.20.2 installs 447 packages and exits 0, while the same manifest and lockfile under Node 22.23.2 fails `EBADENGINE` with exit 1. Deliberately does **not** set `ignore-scripts`, so the `prebuild` hook that writes the generated profiles module still runs |
| Five restored test classes and one restored Node test file | Cover this migration's own source edits | See [the behavioural decisions record](behavioral-decisions.md#21-not-everything-a-migration-change-touches-belongs-in-the-migration) for the full reasoning. In short: the plan freezes the base commit's 402 test sources and this work still modifies **none** of them, but it says nothing about leaving migration-authored code uncovered, and a security review found two real regressions in exactly that uncovered code |

**One change beyond the mapping was considered again and still declined**: the ~130 lines in `AngularResourceCopier` that handed git HTTPS rewrite rules to the npm install through `GIT_CONFIG_*`. The plan assigns the git-over-HTTPS rewrite to the **build image**, as infrastructure, and the security argument for restoring it does not hold: `npm ci` fetches every locked GitHub coordinate as an HTTPS tarball from `codeload.github.com` because each is pinned to a full 40-character commit SHA — verified with no git binary on the path at all — and if that download fails, npm's git fallback on a host without credentials **fails the install and therefore the deployment**. It does not degrade to a weaker transport. What a host needs instead is now stated where an operator will meet it: in the `npmInstallCommand` comment of `spring-web-ark-angular-starter.xml`.

**Two deviations from the plan's literal mapping were *kept*, both on measured grounds, and both are recorded here rather than buried.**

1. **The three `jaxb-runtime` exclusions.** The plan's dependency table lists `org.glassfish.jaxb:jaxb-runtime` 2.3.9 without exclusions. Read literally, that puts jakarta-coordinate artifacts on every module classpath in the reactor, because `jaxb-runtime-2.3.9`'s own POM declares `jakarta.xml.bind:jakarta.xml.bind-api` at compile scope and `com.sun.activation:jakarta.activation` at runtime scope, neither optional — and the plan *also* forbids jakarta artifacts outright, in any form. The prohibition wins over the omission. See [Keeping the reinstated surface javax-only](#keeping-the-reinstated-surface-javax-only) for the measurement.
2. **Four coordinates pinned or re-aliased rather than mechanically rewritten.** The plan describes the frontend rewrite as a uniform `#<range>` → `#semver:<range>` transformation *with "the same repositories and the same resolved commits" and "zero version movement"*. Those two halves conflict for a handful of entries, because a floating range resolves to *today's* newest matching tag: `ace-builds#semver:^1` resolves to `v1.44.0`, not to the `v1.4.12` the base `yarn.lock` recorded. The resolved commit is the half the plan says must not move, and **R-7** makes base-commit behaviour the tie-breaker, so `ace-builds`, `angular-dynamic-locale`, `multi-download` and the `angular-ui-router` alias carry the base-resolved value. Verified individually: **all 53 GitHub-sourced coordinates in the committed lockfile match the commit the base `yarn.lock` recorded — 53 of 53.** See [The 53 GitHub-sourced specs](#the-53-github-sourced-specs).

No test **assertion** anywhere was modified and **no pre-existing test source is edited** by this change set: all 402 base-commit test sources are byte-identical. Five Java test classes and one Node test file are **added**, covering only migration-authored code; they are listed in the row above and reconciled in the section that follows.

### No module POM moves a dependency, and no pre-existing test source is edited

R-1's scope is every manifest and POM, so the boundary is stated precisely rather than left to inference: **of the repository's 145 POMs, five differ from the base commit — the root and four modules.** Every version, property and plugin movement is in the root. The four module POMs move nothing: two add a test-scope declaration with no version of its own, and two replace a hardcoded plugin version with the root's property. **No module POM introduces, removes or re-versions a dependency, and none gains a plugin or a property.** The compiler contract in particular stays centralised — exactly one of the 145 POMs declares it, and none declares `source`, `target`, `release` or `compilerVersion` at module level, so there is nowhere for a release-8 escape hatch to reappear.

The test surface is **added to, and nothing in it is altered**. The base commit's **402** test sources are all still present and all still byte-identical: no assertion was modified, no `@Ignore` was added or removed, and none was deleted — the reproducible check is `git diff --name-only c8f6226105 -- '*/src/test/java/*'`, which lists **0** modified files among them. Five test classes were **added** (407 tracked Java test sources in total), plus one Node test file, and they cover only code this migration itself wrote: the widened MIME cast and its restored encoding check, the two `ApplicationEventMulticaster` methods Spring 5.3.5 forced, the yarn→npm resource copier and its Spring wiring, and the new prebuild profiles helper. The two module POMs that needed a test-scope `junit`/`easymock` declaration to compile them are the ones listed above. The reasoning for adding them at all — and the earlier decision to delete them, which a security review reversed — is on [the behavioural decisions record](behavioral-decisions.md#21-not-everything-a-migration-change-touches-belongs-in-the-migration); the effect on the totals is reconciled on [Baseline test failures](baseline-test-failures.md).

### The nine withdrawn Maven candidates

R-1 forbids a change without a reason. The shared observation that none of these needs one is that **the full reactor builds and the configured unit suite is green with every one of them untouched** — 142 reactor modules, and 917 tests with zero failures and zero errors, as measured and reported by [Baseline test failures](baseline-test-failures.md). That observation is what makes each withdrawal an R-7 resolution against observed behaviour rather than a preference. Each is recorded with the reason it was examined, so nobody repeats the investigation.

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
| Composition | 9 registry aliases + 53 GitHub-sourced coordinates + 24 plain registry packages = **86** | yes |
| Scoped side | 75 `@bower_components/*` − 14 unused removed = 61 → 9 aliases + 52 GitHub-sourced coordinates | yes |
| Unscoped side | 33 − 8 dead build packages − 1 (`grunt` moved) + 1 (`sass`) = 25 → 24 plain registry + `bootbox` | yes |

Three details make those numbers reconcile, and each is worth stating because they are the places a recount goes wrong:

- `bootbox` is written `makeusabrew/bootbox#semver:4.4.0`. It is the **only unscoped dependency expressed as a git spec**, which is why the unscoped side splits 24 + 1 rather than 25 + 0. Every one of the 75 scoped entries carried a `#` at the base commit.
- The **53 GitHub-sourced** coordinates are 52 scoped plus `bootbox`, so the split reads 9 + 53 + 24 = 86 whether it is counted by spec syntax or by origin.
- **52 of the 53 are `#semver:` git specs; exactly one is a pinned `codeload.github.com` tarball** — `@bower_components/multi-download`, for the reason given in [The 53 GitHub-sourced specs](#the-53-github-sourced-specs). A count that filters on `#semver:` therefore returns 52, not 53, and that is the expected result rather than a discrepancy.

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

**Fourteen unused asset packages** — cleanup. Each was verified to have no *code* consumer: no `require`, no asset-list entry in `config/env/all.js`, and no Angular module registration. One of the fourteen leaves dead **markup** behind, and that is recorded separately below rather than glossed by the phrase "referenced nowhere": `angular-slimscroll`, `angular-ui-event`, `angular-ui-indeterminate`, `angular-ui-mask`, `angular-ui-scroll`, `angular-ui-scrollpoint`, `angular-ui-uploader`, `angular-ui-utils`, `angular-ui-validate`, `font-awesome`, `html5shiv`, `pikaday`, `slimScroll`, `zeroclipboard`.

Two of the fourteen have a compatibility dimension as well: `angular-ui-utils` and `font-awesome` were bower-only repositories that npm cannot install at all, so they would have had to be resolved one way or another. `font-awesome` in particular was a stale duplicate of the icon font that is actually used, which reaches the tree through the `components-font-awesome` entry.

**Eight dead build packages** — cleanup, explicitly **not** compatibility fixes: `app-root-path`, `bower`, `grunt-karma`, `jasmine-core`, `karma`, `karma-jasmine`, `npm` (the package manager declared as a runtime dependency of the project it manages) and `template`.

The framing here is a requirement, not a nicety. The karma/jasmine cluster has **no karma target in the Gruntfile and no karma configuration file anywhere**, so it never ran; and both `karma` and `npm` **do** still install on Node 20. They are removed because they are dead, not because they broke. Lockfile proof that the removal is complete: none of the eight appears anywhere in `package-lock.json`, at any depth.

**One removal leaves dead markup behind: `angular-slimscroll`.** The package had no provider registration and no asset-list entry, so removing it changes nothing that loads — but the directive attribute it was meant to serve is still written in the views. Measured on the delivered tree:

```bash
grep -rl 'ng-slimscroll' --include=*.html . | grep -v node_modules | grep -v '/target/' | wc -l
```

**15 files** carry `ng-slimscroll=""`: 13 under the frontend tree (`templates/home.tpl.html` and the left-sidebar view of `people`, `document-repository`, `consultations`, `my-documents`, `time-tracking`, `organizations`, `tasks`, `complaints`, `admin`, `cost-tracking`, `cases` and `preference`), plus 2 in extension resource trees — `acm-foia`'s and `acm-privacy`'s own `cases.client.view.html`. The same command against the base commit returns **15**, and `git diff` reports **zero** changed `.html` files in this change set, so the markup is base-identical and none of it is this migration's doing.

**What that means in practice.** The attribute was already inert at the base commit, because no slimscroll provider was registered there either — AngularJS silently ignores an attribute no directive claims. So the sidebars did not custom-scroll before this change and do not now; nothing regressed. What the removal does is make the situation legible: the package is gone, so nobody can mistake the markup for a working feature backed by a declared dependency.

**Two things not to do with this.** Do not reintroduce the package to "make the markup work" — that would add a scrolling behaviour the base commit did not have, which the preservation mandate forbids. And do not strip the attributes as tidy-up: 15 view files is a client-surface change with no functional gain, and the review's own regression check certifies the client surface as base-identical. It is registered in [the known-issues record](known-issues.md) as pre-existing dead markup, for whoever eventually decides between wiring it up and removing it. (An earlier count of 14 views was a partial one — it missed the two extension trees.)

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
| `angular-ui-router` | `angular-ui/angular-ui-router-bower#~0.2.15` | `angular-ui-router@0.2.18` | **the version the base commit actually installed** — the bower tarball at the SHA `yarn.lock` names declares `"version": "0.2.18"` in its own `bower.json`, and its `release/angular-ui-router.min.js` is md5-identical to the registry 0.2.18 tarball's (`0ef20b23d2e6ef018923e4addc5057a1`, 32,440 bytes) where 0.2.15's differs (`78c94563…`, 30,439 bytes). Path unchanged |
| `angular-ui-ace` | `angular-ui/ui-ace#~0.2.3` | `angular-ui-ace@0.2.3` | asset path moves to `src/ui-ace.js` — the npm package ships no minified build |
| `components-font-awesome` | `components/font-awesome#~4.4.0` | `font-awesome@4.4.0` | path unchanged |
| `ng-file-upload` | `danialfarid/angular-file-upload-bower#~7.0.17` | `ng-file-upload@7.0.17` | asset path moves into `dist/` |
| `ng-file-upload-shim` | `danialfarid/angular-file-upload-shim-bower#~7.0.17` | `ng-file-upload@7.0.17` | the shim bundles ship inside the same package; asset path moves into `dist/` |
| `ng-tags-input` | `mbenford/ngTagsInput-bower#~3.0.0` | `ng-tags-input@3.0.0` | both its CSS and JS asset paths move into `build/` |
| `ui-grid-draggable-rows` | `cdwv/ui-grid-draggable-rows#0.2.2` | `ui-grid-draggable-rows@0.3.3` | **the one forced version delta — see below** |

**The one forced version delta, recorded explicitly.** `ui-grid-draggable-rows` 0.2.2 **is not published**: the registry holds only 0.3.0, 0.3.1, 0.3.2 and 0.3.3, verified directly. The base-commit spec was an exact pin on a tag that has no registry counterpart, so *any* registry version is a forced minor bump; the manifest takes 0.3.3, the newest of the four published. This is the only version *movement* in the alias set, and it was forced rather than chosen.

**An alias takes the version the base commit resolved, not the version its range mentions.** `angular-ui-router`'s base spec was `#~0.2.15`, and reading `0.2.15` off that text is the mistake an earlier revision made. Bower read `~0.2.15` as a range and selected the highest matching tag, which the base `yarn.lock` records as commit `2b8d5241b4c631ca2aef079bb96690b213eff449`; `git ls-remote --tags` identifies that SHA as tag **0.2.18**. The alias therefore carries 0.2.18, and the choice is verified at the byte level rather than argued: `release/angular-ui-router.min.js` from `npm:angular-ui-router@0.2.18` is **md5-identical** (`0ef20b23d2e6ef018923e4addc5057a1`) to the same file in the base-resolved bower tree, while `@0.2.15` is a different file (`78c9456351a2c34dd5e01d59832d3956`, 30,439 B against 32,440 B) that would have shipped 2,001 fewer bytes of a **router** — the component every screen transition in the application depends on. The other eight aliases were re-checked the same way and each already carried the base-resolved version.

### Every changed resolution against the base commit's `yarn.lock`

R-1 governs "all manifests and POMs", and a lockfile is the manifest that decides what actually installs — so the churn between the base commit's `yarn.lock` and the committed `package-lock.json` is inventoried here in full rather than summarised. The comparison unit is the **set of resolved versions per package directory name**, which is immune to the two lockfiles' different hoisting rules: a package whose version set is identical on both sides is not listed, and every package whose set differs is listed below, with the cause it belongs to. The base lockfile carries **818** distinct names and the committed one **384**; **670** names differ, and every one of them falls into one of the eight causes below with **none unclassified**.

Regenerate it with the two lockfiles and no other input: parse `git show c8f6226105:acm-standard-applications/arkcase/src/main/webapp/resources/yarn.lock` for `version`/`resolved` pairs, parse `package-lock.json`'s `packages` map keyed on the directory name after the final `node_modules/`, and diff the version sets.

| Cause | Packages |
| --- | ---: |
| forced build-tool change (measured Node 20 failure or peer consequence) | 6 |
| retained top-level entry, range re-resolved by npm | 14 |
| top-level package deliberately removed as dead/unused | 22 |
| transitive dropped with a removed top-level package | 260 |
| transitive of a forced build-tool change | 39 |
| transitive shared by a forced and a retained tool | 58 |
| transitive of a retained tool, re-resolved by npm | 69 |
| transitive no longer required by any retained package | 202 |

The two causes that need an individual reason each — a forced build-tool change, or a top-level entry whose resolution moved — are tabulated first. The six that are consequences rather than decisions follow as complete name lists.

**Forced build-tool changes** — each one's reproduced failure is in the forced-change table earlier on this page

| Package | Base commit | Committed lockfile |
| --- | --- | --- |
| `grunt` | 0.4.5 | 1.6.3 |
| `grunt-cli` | 0.1.13 | 1.5.0 |
| `grunt-ng-annotate` | 1.0.1 | 4.0.0 |
| `grunt-sass` | 1.0.0 | 4.1.0 |
| `grunt-sync` | 0.6.2 | 0.8.2 |
| `sass` | - | 1.77.8 |

**Retained top-level entries whose resolution moved** — the spec text is the base commit's in every row; npm resolved the same range differently, or the entry is a registry alias whose bower counterpart carried no version at all (`0.0.0` in yarn's record)

| Package | Base commit | Committed lockfile |
| --- | --- | --- |
| `@bower_components/angular-translate` | 0.0.0 | 2.7.2 |
| `@bower_components/angular-translate-loader-partial` | 0.0.0 | 2.7.2 |
| `@bower_components/angular-ui-ace` | 0.0.0 | 0.2.3 |
| `@bower_components/angular-ui-router` | 0.0.0 | 0.2.18 |
| `@bower_components/components-font-awesome` | 0.0.0 | 4.4.0 |
| `@bower_components/ng-file-upload` | 0.0.0 | 7.0.17 |
| `@bower_components/ng-file-upload-shim` | 0.0.0 | 7.0.17 |
| `@bower_components/ng-tags-input` | 0.0.0 | 3.0.0 |
| `@bower_components/ui-grid-draggable-rows` | 0.0.0 | 0.3.3 |
| `angular-moment-picker` | - | 0.10.2 |
| `bootbox` | 4.4.0,5.5.1 | 4.4.0 |
| `glob` | 3.1.21,3.2.11,4.3.5,4.5.3,5.0.15,6.0.4,7.1.6 | 3.2.11,4.3.5,5.0.15,7.1.7,7.2.3 |
| `grunt-contrib-clean` | 2.0.0 | 2.0.1 |
| `lodash` | 0.9.2,2.2.1,2.4.2,3.10.1,3.7.0,4.17.20 | 2.4.2,3.10.1,3.7.0,4.18.1 |

Five of those rows would mislead without a sentence each:

- The nine `@bower_components/*` aliases read `0.0.0` on the base side because that is what yarn recorded for a bower tarball with no version in its manifest — the very reason those nine had to become registry aliases. The version on the right is the registry package's own, and for ten of the eleven files the pipeline loads from them the **bytes are identical** to the bower tarball at the base commit's SHA.
- `angular-moment-picker` reads `-` on the base side because the base commit's `yarn.lock` **has no entry for it at all**, although `package.json` declares it at the exact version `0.10.2`. That is a pre-existing staleness in the base lockfile, not drift: the committed lockfile pins precisely the declared version.
- `bootbox` loses its second copy. The base tree carried both the declared `4.4.0` (at the base SHA `cb756203`) and a transitively required `5.5.1` for `@bower_components/ngBootbox`'s `>=4.4.0`; npm satisfies that same range with the declared 4.4.0, so one duplicate disappears and the file the asset list loads is unchanged.
- `glob` and `lodash` list version *sets* because both exist several times over in both trees. The instance that matters is the root-hoisted one the Gruntfile's own `require` resolves, and it is unchanged in both cases — `glob` 5.0.15 and `lodash` 3.10.1, verified by resolving them through node in the installed tree. The other members are nested copies belonging to individual plugins.
- `grunt-contrib-clean` is the one row where a retained tool's own range genuinely resolved forward: the spec is the base commit's `^2.0.0` and npm takes the newest 2.0.x, which is 2.0.1. It is inventoried rather than pinned because the clean task deletes `assets/dist` before the pipeline writes it and contributes no shipped byte; an earlier revision of this page called it "2.0.0, unchanged", which was wrong.

**Top-level packages deliberately removed** (22) — the 22 removals R-4's no-dead-packages requirement asks for; fourteen are unreferenced bower assets and eight are dead build packages

`@bower_components/angular-slimscroll` 0.0.0→-, `@bower_components/angular-ui-event` 1.0.0→-, `@bower_components/angular-ui-indeterminate` 1.0.0→-, `@bower_components/angular-ui-mask` 1.8.7→-,
`@bower_components/angular-ui-scroll` 1.8.2→-, `@bower_components/angular-ui-scrollpoint` 2.1.1→-, `@bower_components/angular-ui-uploader` 1.4.1→-, `@bower_components/angular-ui-utils` 0.0.0→-,
`@bower_components/angular-ui-validate` 1.2.3→-, `@bower_components/font-awesome` 0.0.0→-, `@bower_components/html5shiv` 3.7.3→-, `@bower_components/pikaday` 1.8.2→-, `@bower_components/slimScroll`
1.3.8→-, `@bower_components/zeroclipboard` 2.3.0→-, `app-root-path` 1.0.0→-, `bower` 1.4.2→-, `grunt-karma` 0.12.2→-, `jasmine-core` 2.3.4→-, `karma` 0.13.22→-, `karma-jasmine` 0.3.8→-, `npm` 3.2.2→-,
`template` 0.15.0→-

**Transitives dropped with a removed top-level package** (260) — no longer reachable from any declared dependency; nothing chose these versions and nothing now installs them

`accepts` 1.3.3→-, `after` 0.8.2→-, `ansi-cyan` 0.1.1→-, `ansi-red` 0.1.1→-, `ansicolors` 0.2.1,0.3.2→-, `ansistyles` 0.1.3→-, `archy` 1.0.0→-, `arraybuffer.slice` 0.0.6→-, `asap` 2.0.6→-, `async-
helpers` 0.2.5→-, `async-some` 1.0.2→-, `backo2` 1.0.2→-, `base64-arraybuffer` 0.1.5→-, `base64id` 1.0.0→-, `batch` 0.5.3→-, `better-assert` 1.0.2→-, `binary` 0.3.0→-, `blob` 0.0.4→-, `bluebird`
2.11.0→-, `body-parser` 1.19.0→-, `bower-config` 0.6.2→-, `bower-endpoint-parser` 0.2.2→-, `bower-json` 0.4.0→-, `bower-logger` 0.2.2→-, `bower-registry-client` 0.3.0→-, `buffer-alloc` 1.2.0→-,
`buffer-alloc-unsafe` 1.1.0→-, `buffer-fill` 1.0.0→-, `buffers` 0.1.1→-, `builtins` 0.0.7→-, `callsite` 1.0.0→-, `cardinal` 0.4.4→-, `chainsaw` 0.1.0→-, `chmodr` 0.1.0→-, `chownr` 0.0.2,1.1.4→-, `cli-
color` 0.3.3→-, `cli-width` 1.1.1→-, `clone` 1.0.4→-, `clone-deep` 0.1.1→-, `cmd-shim` 2.0.2→-, `columnify` 1.5.4→-, `component-bind` 1.0.0→-, `component-inherit` 0.0.3→-, `config-cache` 5.0.1→-,
`config-chain` 1.1.12→-, `configstore` 0.3.2→-, `connect` 3.7.0→-, `content-type` 1.0.4→-, `cookie` 0.3.1→-, `core-js` 2.6.11→-, `custom-event` 1.0.1→-, `dashify` 0.1.0→-, `debuglog` 1.0.1→-,
`decompress-zip` 0.1.0→-, `deep-extend` 0.2.11,0.6.0→-, `defaults` 1.0.3→-, `defaults-deep` 0.2.4→-, `delimiter-regex` 1.3.1→-, `dezalgo` 1.0.3→-, `di` 0.0.1→-, `dom-serialize` 2.2.1→-, `duplexer`
0.1.2→-, `editor` 1.0.0→-, `ee-first` 1.1.1→-, `en-route` 0.5.0→-, `encodeurl` 1.0.2→-, `engine-cache` 0.12.2→-, `engine.io` 1.8.5→-, `engine.io-client` 1.8.5→-, `engine.io-parser` 1.3.2→-, `ent`
2.2.0→-, `es6-weak-map` 0.1.4→-, `escape-html` 1.0.3→-, `event-stream` 3.3.5→-, `eventemitter3` 4.0.7→-, `expand-braces` 0.1.2→-, `expander` 0.3.3→-, `export-files` 2.1.1→-, `falsey` 0.2.1→-, `file-
is-binary` 1.0.0→-, `filter-functions` 0.1.0→-, `finalhandler` 1.1.2→-, `follow-redirects` 1.13.0→-, `from` 0.1.7→-, `fs-constants` 1.0.0→-, `fs-vacuum` 1.2.10→-, `fs-write-stream-atomic` 1.0.10→-,
`fstream-ignore` 1.0.5→-, `fstream-npm` 1.0.7→-, `github` 0.2.4→-, `globby` 2.1.0→-, `got` 3.3.1→-, `gray-matter` 3.1.1→-, `handlebars` 2.0.0→-, `has-binary` 0.1.7→-, `has-cors` 1.1.0→-, `helper-
cache` 0.7.2→-, `http-proxy` 1.18.1→-, `iferr` 0.1.5→-, `imurmurhash` 0.1.4→-, `indexof` 0.0.1→-, `infinity-agent` 2.0.3→-, `init-package-json` 1.7.1→-, `inquirer` 0.8.0,0.8.5→-, `insight` 0.5.3→-,
`intersect` 0.0.3→-, `is-binary-buffer` 1.0.0→-, `is-npm` 1.0.0→-, `is-redirect` 1.0.0→-, `is-root` 1.0.0→-, `is-stream` 1.1.0→-, `is-whitespace` 0.3.0→-, `isbinaryfile` 3.0.3→-, `json-parse-better-
errors` 1.0.2→-, `json-parse-even-better-errors` 2.3.1→-, `junk` 1.0.3→-, `latest-version` 1.0.1→-, `layouts` 0.9.0→-, `lazy-chalk` 0.1.0→-, `lazy-globby` 0.1.1→-, `load-templates` 0.8.9→-, `loader-
cache` 0.4.0→-, `lockfile` 1.0.4→-, `lodash._basecallback` 3.3.1→-, `lodash._basedifference` 3.0.3→-, `lodash._baseflatten` 3.1.4→-, `lodash._baseindexof` 3.1.0→-, `lodash._baseisequal` 3.0.7→-,
`lodash._baseuniq` 3.0.3→-, `lodash._cacheindexof` 3.0.2→-, `lodash._createcache` 3.1.2→-, `lodash._createwrapper` 3.2.0→-, `lodash._isiterateecall` 3.0.9→-, `lodash._replaceholders` 3.0.0→-,
`lodash._root` 3.0.1→-, `lodash.bind` 3.1.0→-, `lodash.debounce` 3.1.1→-, `lodash.istypedarray` 3.0.6→-, `lodash.pairs` 3.0.1→-, `lodash.restparam` 3.6.1→-, `lodash.union` 3.1.0→-, `lodash.uniq`
3.2.2→-, `lodash.without` 3.2.1→-, `log4js` 0.6.38→-, `lowercase-keys` 1.0.1→-, `lru-queue` 0.1.0→-, `map-stream` 0.0.7→-, `media-typer` 0.3.0→-, `memoizee` 0.3.10→-, `middleware-utils` 0.1.4→-,
`mime` 1.6.0→-, `mixin-object` 0.1.1→-, `mkpath` 0.1.0→-, `mout` 0.11.1,0.9.1→-, `mute-stream` 0.0.4,0.0.8→-, `negotiator` 0.6.1→-, `nested-error-stacks` 1.0.2→-, `normalize-git-url` 3.0.2→-, `npm-
cache-filename` 1.0.2→-, `npm-install-checks` 2.0.1→-, `npm-normalize-package-bin` 1.0.1→-, `npm-package-arg` 4.0.2,4.2.1→-, `npm-registry-client` 6.5.1→-, `npm-user-validate` 0.1.5→-, `object-
component` 0.0.3→-, `object.reduce` 0.1.7→-, `on-finished` 2.3.0→-, `opener` 1.4.3→-, `opn` 1.0.2→-, `option-cache` 1.5.0→-, `options` 0.0.6→-, `os-name` 1.0.3→-, `osx-release` 1.1.0→-, `p-throttler`
0.1.1→-, `package-json` 1.2.0→-, `parsejson` 0.0.3→-, `parseqs` 0.0.5→-, `parser-front-matter` 1.6.4→-, `parseuri` 0.0.5→-, `parseurl` 1.3.3→-, `path-is-inside` 1.0.2→-, `path-to-regexp` 1.8.0→-,
`pause-stream` 0.0.11→-, `pick-from` 0.1.0→-, `plasma` 0.9.1→-, `plasma-cache` 0.2.2→-, `plugin-error` 0.1.2→-, `pluralize` 1.2.1→-, `prepend-http` 1.0.4→-, `promptly` 0.2.0→-, `promzard` 0.3.0→-,
`proto-list` 1.2.4→-, `q` 0.9.7,1.5.1→-, `rc` 1.2.8→-, `read` 1.0.7→-, `read-all-stream` 3.1.0→-, `read-installed` 4.0.3→-, `read-package-json` 2.0.13,2.1.2→-, `read-package-tree` 5.1.6→-, `readdir-
scoped-modules` 1.1.0→-, `readline2` 0.1.1→-, `realize-package-specifier` 3.0.3→-, `redeyed` 0.4.4→-, `registry-url` 3.1.0→-, `relative` 3.0.2→-, `request-progress` 0.3.1→-, `request-replay` 0.2.0→-,
`retry` 0.6.1→-, `rx` 2.5.3→-, `semver-diff` 2.1.0→-, `sha` 1.3.0→-, `shell-quote` 1.7.2→-, `slash` 1.0.0→-, `slide` 1.1.6→-, `socket.io` 1.7.4→-, `socket.io-adapter` 0.5.0→-, `socket.io-client`
1.7.4→-, `socket.io-parser` 2.3.1→-, `sorted-object` 1.0.0→-, `split` 1.0.1→-, `stream-combiner` 0.2.2→-, `string-length` 1.0.1→-, `stringify-object` 1.0.1→-, `strip-bom-string` 1.0.0→-, `tar-fs`
1.16.3→-, `tar-stream` 1.6.2→-, `text-table` 0.2.0→-, `throttleit` 0.0.2→-, `through` 2.3.8→-, `timed-out` 2.0.0→-, `timers-ext` 0.1.7→-, `tmp` 0.0.24,0.0.33→-, `to-arg` 1.1.0→-, `to-array` 0.1.4→-,
`to-buffer` 1.1.1→-, `to-flags` 0.1.0→-, `touch` 0.0.3→-, `traverse` 0.3.9→-, `trim-leading-lines` 0.1.1→-, `type-is` 1.6.18→-, `uid-number` 0.0.6→-, `ultron` 1.0.2→-, `umask` 1.1.0→-, `unique-
filename` 1.0.0→-, `unique-slug` 1.0.0→-, `update-notifier` 0.3.2→-, `user-home` 1.1.1→-, `useragent` 2.3.0→-, `util-extend` 1.0.3→-, `utils-merge` 1.0.1→-, `validate-npm-package-name` 2.2.2→-, `void-
elements` 2.0.1→-, `wcwidth` 1.0.1→-, `win-release` 1.1.1→-, `write-file-atomic` 1.1.4→-, `ws` 1.1.5→-, `wtf-8` 1.0.0→-, `xdg-basedir` 1.0.1→-, `xmlhttprequest-ssl` 1.5.3→-, `yeast` 0.1.2→-

**Transitives of a forced build-tool change** (39) — brought in, moved or dropped by one of the six forced changes above

`abbrev` 1.0.9,1.1.1→1.1.1, `argparse` 0.1.16,1.0.10→1.0.10, `array-each` -→1.0.1, `array-slice` 0.2.3→1.1.0, `colors` 0.6.2,1.4.0→1.1.2, `dateformat` 1.0.2-1.2.3→4.6.3, `esprima` 1.0.4,4.0.1→4.0.1,
`exit-x` -→0.2.2, `fined` -→1.2.0, `flagged-respawn` -→1.0.1, `for-own` 0.1.5→1.0.0, `getobject` 0.1.0→1.0.2, `grunt-known-options` -→2.0.0, `grunt-legacy-log` 0.1.3→3.0.1, `grunt-legacy-log-utils`
0.1.1→2.1.3, `grunt-legacy-util` 0.2.0→2.0.2, `iconv-lite` 0.2.11,0.4.24→0.6.3, `immutable` -→4.3.9, `interpret` -→1.1.0, `is-absolute` 0.1.7→1.0.0, `is-plain-object` 0.1.0,2.0.4→2.0.4, `is-relative`
0.1.3→1.0.0, `is-unc-path` -→1.0.0, `isobject` 1.0.2,2.1.0,3.0.1→3.0.1, `js-yaml` 2.0.5,3.14.0→3.15.1, `liftup` -→3.0.1, `make-iterator` -→1.0.1, `nopt` 1.0.10,3.0.6→5.0.0, `object.defaults` -→1.1.0,
`object.map` -→1.0.1, `parse-filepath` -→1.0.2, `path-root` -→0.1.1, `path-root-regex` -→0.1.2, `rechoir` -→0.7.1, `source-map-js` -→1.2.1, `sprintf-js` 1.0.3→1.0.3,1.1.3, `unc-path-regex` -→0.1.2,
`underscore.string` 2.2.1,2.3.3,2.4.0→3.3.6, `v8flags` -→4.0.1

**Transitives shared by a forced and a retained tool** (58) — reachable from both a forced change and a retained tool, so the resolution npm picks satisfies both ranges

`ansi-regex` 0.2.1,1.1.1,2.1.1,3.0.0→0.2.1,2.1.1, `ansi-styles` 1.1.0,2.2.1→1.1.0,2.2.1,4.3.0, `anymatch` 1.3.2→3.1.3, `async` 0.1.22,0.2.10,0.9.2,1.5.2,2.6.3→1.5.2,2.6.4,3.2.6, `async-each`
0.1.6,1.0.3→0.1.6, `balanced-match` 1.0.0→1.0.2, `binary-extensions` 1.13.1→2.3.0, `brace-expansion` 1.1.11→1.1.18, `braces` 0.1.5,1.8.5,2.3.2→3.0.3, `chalk` 0.5.1,1.1.3→0.5.1,1.1.3,4.1.2, `chokidar`
0.12.6,1.7.0→0.12.6,3.6.0, `color-convert` -→2.0.1, `color-name` -→1.1.4, `core-util-is` 1.0.2→1.0.3, `detect-file` -→1.0.0, `es-errors` -→1.3.0, `expand-tilde` -→2.0.2, `fill-range`
2.2.4,4.0.0→7.1.1, `findup-sync` 0.1.3,0.2.1→0.2.1,4.0.0,5.0.0, `fsevents` 0.3.8,1.2.13→0.3.8,2.3.3, `function-bind` 1.1.1→1.1.2, `glob-parent` 2.0.0→5.1.2, `global-modules` -→1.0.0, `global-prefix`
-→1.0.2, `graceful-fs` 1.2.3,2.0.3,3.0.12,4.1.15,4.2.4→2.0.3,4.2.11, `has-flag` -→4.0.0, `hasown` -→2.0.4, `homedir-polyfill` -→1.0.3, `inherits` 1.0.2,2.0.3,2.0.4→2.0.4, `ini` 1.3.5→1.3.8, `is-
binary-path` 1.0.1→2.1.0, `is-core-module` 2.1.0→2.16.2, `is-extglob` 1.0.0→2.1.1, `is-glob` 2.0.1→4.0.3, `is-number` 0.1.1,2.1.0,3.0.0,4.0.0→7.0.0, `kind-of`
0.1.2,1.1.0,2.0.1,3.2.2,4.0.0,5.1.0,6.0.3→3.2.2,6.0.3, `lru-cache` 2.3.1,2.7.0,2.7.3,4.1.5→2.7.3, `micromatch` 2.3.11,3.1.10→4.0.8, `minimatch`
0.2.14,0.3.0,1.0.0,2.0.10,3.0.4→0.2.14,0.3.0,2.0.10,3.0.8,3.1.5, `minimist` 0.0.10,0.0.8,1.2.5→0.0.10,1.2.8, `nan` 2.14.2→2.28.0, `normalize-path` 2.1.1→3.0.0, `once` 1.3.3,1.4.0→1.4.0, `optimist`
0.3.7,0.6.1→0.6.1, `parse-passwd` -→1.0.0, `path-parse` 1.0.6→1.0.7, `picomatch` -→2.3.2, `readable-stream` 1.0.34,1.1.13,1.1.14,2.3.7→1.0.34,1.1.14,2.3.8, `readdirp` 1.3.0,2.2.1→1.3.0,3.6.0,
`resolve` 0.3.1,1.19.0→1.22.12, `resolve-dir` -→1.0.1, `rimraf` 2.2.8,2.4.5,2.7.1→2.7.1, `source-map` 0.1.43,0.4.4,0.5.7→0.4.4,0.5.7, `strip-ansi` 0.3.0,2.0.1,3.0.1,4.0.0→0.3.0,3.0.1, `supports-color`
0.2.0,2.0.0→0.2.0,2.0.0,7.2.0, `supports-preserve-symlinks-flag` -→1.0.0, `to-regex-range` 2.1.1→5.0.1, `which` 1.0.9,1.1.2,1.3.1→1.3.1,2.0.2

**Transitives of a retained tool, re-resolved by npm** (69) — the retained tool's own range is unchanged; npm's resolver picked a different member of it than yarn had

`@types/angular` 1.8.0→1.8.9, `angular` 1.5.11,1.8.2→1.5.11,1.8.3, `angular-sanitize` 1.8.2→1.8.3, `angular-translate` -→2.7.2, `bootstrap` 4.5.3→3.4.1, `buffer-from` 1.1.1→1.1.2, `bufferutil`
4.0.2→4.1.0, `bytes` 1.0.0,3.1.0→1.0.0, `call-bind-apply-helpers` -→1.0.2, `call-bound` -→1.0.4, `camelcase` 1.2.1,2.1.1,3.0.0→1.2.1,2.1.1, `cliui` 2.1.0,3.2.0→2.1.0, `d` 0.1.1,1.0.1→1.0.2, `debug`
2.2.0,2.3.3,2.6.9,3.2.7→2.6.9,3.2.7, `domelementtype` 1.3.1,2.0.2→1.3.1,2.3.0, `dunder-proto` -→1.0.1, `end-of-stream` 1.4.4→1.4.5, `entities` 1.0.0,2.1.0→1.0.0,2.2.0, `error-ex` 1.3.2→1.3.4, `es-
define-property` -→1.0.1, `es-object-atoms` -→1.1.2, `es5-ext` 0.10.53→0.10.64, `es6-iterator` 0.1.3,2.0.3→2.0.3, `es6-symbol` 2.0.1,3.1.3→3.1.4, `esniff` -→2.0.1, `ext` 1.4.0→1.7.0, `faye-websocket`
0.10.0,0.11.3→0.10.0,0.11.4, `get-intrinsic` 1.0.1→1.3.0, `get-proto` -→1.0.1, `globule` 1.3.2→1.3.4, `gopd` -→1.2.0, `has-symbols` 1.0.1→1.1.0, `hosted-git-info` 2.1.5,2.8.8→2.8.9, `http-parser-js`
0.5.2→0.5.10, `jquery` 3.5.1→4.0.0, `json3` 3.3.2,3.3.3→3.3.3, `lazy-cache` 0.1.0,0.2.7,1.0.4,2.0.2→1.0.4, `math-intrinsics` -→1.1.0, `moment` 2.10.6,2.29.1→2.10.6,2.30.1, `ms`
0.7.1,0.7.2,2.0.0,2.1.2→2.0.0,2.1.3, `next-tick` 0.2.2,1.0.0,1.1.0→1.1.0, `node-gyp-build` 4.2.3→4.8.4, `normalize-package-data` 2.3.8,2.5.0→2.5.0, `object-assign` 2.1.1,3.0.0,4.1.0,4.1.1→4.1.1,
`object-inspect` -→1.13.4, `pump` 1.0.3,2.0.1→2.0.1, `qs` 2.3.3,6.5.2,6.7.0,6.9.4→6.15.3, `raw-body` 1.1.7,2.4.0→1.1.7, `repeat-string` 0.2.2,1.6.1→1.6.1, `semver` 2.3.2,4.3.6,5.0.3,5.3.0,5.7.1→5.7.2,
`side-channel` -→1.1.1, `side-channel-list` -→1.0.1, `side-channel-map` -→1.0.1, `side-channel-weakmap` -→1.0.2, `signal-exit` 3.0.3→3.0.7, `spdx-correct` 1.0.2,3.1.1→3.2.0, `spdx-exceptions`
2.3.0→2.5.0, `spdx-license-ids` 1.2.2,3.0.6→3.0.23, `stream-shift` 1.0.1→1.0.3, `strip-json-comments` 1.0.4,2.0.1→1.0.4, `through2` 0.6.5,2.0.5→2.0.5, `type` 1.2.0,2.1.0→2.7.3, `uglify-js`
2.3.6,2.8.29→2.8.29, `url-parse` 1.4.7→1.5.10, `utf-8-validate` 5.0.3→5.0.10, `validate-npm-package-license` 2.0.0,3.0.4→3.0.4, `websocket` 1.0.32→1.0.35, `websocket-driver` 0.7.4→0.7.5, `yargs`
3.10.0,7.1.1→3.10.0

**Transitives no longer required by any retained package** (202) — present in the base tree and reachable from nothing in the committed one

`ajv` 6.12.6→-, `ansi` 0.3.1→-, `ansi-wrap` 0.1.0→-, `ansi-yellow` 0.1.1→-, `aproba` 1.0.4,1.2.0→-, `are-we-there-yet` 1.0.6,1.1.5→-, `arr-diff` 1.1.0,2.0.0,4.0.0→-, `arr-flatten` 1.1.0→-, `arr-union`
2.1.0,3.1.0→-, `array-index` 1.0.0→-, `array-unique` 0.2.1,0.3.2→-, `asn1` 0.1.11,0.2.4→-, `assert-plus` 0.1.5,1.0.0→-, `assign-symbols` 1.0.0→-, `async-foreach` 0.1.3→-, `asynckit` 0.4.0→-, `atob`
2.1.2→-, `aws-sign2` 0.5.0,0.7.0→-, `aws4` 1.11.0→-, `base` 0.11.2→-, `bcrypt-pbkdf` 1.0.2→-, `bindings` 1.5.0→-, `bl` 0.9.5,1.2.3→-, `block-stream` 0.0.9→-, `boom` 0.4.2,2.10.1→-, `builtin-modules`
1.1.1→-, `cache-base` 1.0.1→-, `call-bind` 1.0.0→-, `caseless` 0.12.0,0.8.0,0.9.0→-, `class-utils` 0.3.6→-, `code-point-at` 1.1.0→-, `coffee-script` 1.3.3→-, `collection-visit` 1.0.0→-, `combined-
stream` 0.0.7,1.0.8→-, `component-emitter` 1.1.2,1.2.1,1.3.0→-, `console-control-strings` 1.1.0→-, `copy-descriptor` 0.1.1→-, `cross-spawn` 3.0.1→-, `cryptiles` 0.2.2,2.0.5→-, `ctype` 0.5.3→-,
`dashdash` 1.14.1→-, `decode-uri-component` 0.2.0→-, `define-properties` 1.1.3→-, `define-property` 0.2.5,1.0.0,2.0.2→-, `delayed-stream` 0.0.5,1.0.0→-, `delegates` 1.0.0→-, `depd` 1.1.2→-, `each-
async` 1.1.1→-, `ecc-jsbn` 0.1.2→-, `expand-brackets` 0.1.5,2.1.4→-, `expand-range` 0.1.1,1.8.2→-, `extend-shallow` 1.1.4,2.0.1,3.0.2→-, `extglob` 0.3.2,2.0.4→-, `extsprintf` 1.3.0,1.4.0→-, `fast-
deep-equal` 3.1.3→-, `fast-json-stable-stringify` 2.1.0→-, `file-uri-to-path` 1.0.0→-, `filename-regex` 2.0.1→-, `forever-agent` 0.5.2,0.6.1→-, `form-data` 0.2.0,2.3.3→-, `fragment-cache` 0.2.1→-,
`fstream` 1.0.12→-, `gauge` 1.2.7,2.7.4→-, `get-caller-file` 1.0.3→-, `get-value` 1.3.1,2.0.6→-, `getpass` 0.1.7→-, `glob-base` 0.3.0→-, `har-schema` 2.0.0→-, `har-validator` 5.1.5→-, `has` 1.0.3→-,
`has-unicode` 1.0.1,2.0.1→-, `has-value` 0.2.1,0.3.1,1.0.0→-, `has-values` 0.1.4,1.0.0→-, `hawk` 1.1.1,2.3.1→-, `hoek` 0.9.1,2.16.3→-, `http-errors` 1.7.2→-, `http-signature` 0.10.1,1.2.0→-, `in-
publish` 2.0.1→-, `invert-kv` 1.0.0→-, `is-accessor-descriptor` 0.1.6,1.0.0→-, `is-builtin-module` 1.0.0→-, `is-data-descriptor` 0.1.4,1.0.0→-, `is-descriptor` 0.1.6,1.0.2→-, `is-dotfile` 1.0.3→-,
`is-equal-shallow` 0.1.3→-, `is-extendable` 0.1.1,1.0.1→-, `is-fullwidth-code-point` 1.0.0,2.0.0→-, `is-posix-bracket` 0.1.1→-, `is-primitive` 2.0.0→-, `isstream` 0.1.2→-, `js-base64` 2.6.4→-, `jsbn`
0.1.1→-, `json-schema` 0.2.3→-, `json-schema-traverse` 0.4.1→-, `json-stringify-safe` 5.0.1→-, `jsprim` 1.4.1→-, `lcid` 1.0.0→-, `lodash._arraycopy` 3.0.0→-, `lodash._arrayeach` 3.0.0→-,
`lodash._baseassign` 3.2.0→-, `lodash._baseclone` 3.3.0→-, `lodash._basecopy` 3.0.1→-, `lodash._basefor` 3.0.3→-, `lodash._bindcallback` 3.0.1→-, `lodash._getnative` 3.9.1→-, `lodash.assign` 4.2.0→-,
`lodash.clonedeep` 3.0.2,4.5.0→-, `lodash.isarguments` 3.1.0→-, `lodash.isarray` 3.0.4→-, `lodash.keys` 3.1.2→-, `lodash.pad` 4.5.1→-, `lodash.padend` 4.6.1→-, `lodash.padstart` 4.6.1→-, `map-visit`
1.0.0→-, `math-random` 1.0.4→-, `mime-db` 1.12.0,1.44.0→-, `mime-types` 1.0.2,2.0.14,2.1.27→-, `mixin-deep` 1.3.2→-, `mkdirp` 0.3.5,0.5.0,0.5.5→-, `nanomatch` 1.2.13→-, `natives` 1.1.6→-, `node-gyp`
2.0.2,3.8.0→-, `node-sass` 3.13.1→-, `node-uuid` 1.4.8→-, `noncharacters` 1.1.0→-, `npmlog` 1.2.1,4.1.2→-, `number-is-nan` 1.0.1→-, `oauth-sign` 0.5.0,0.6.0,0.9.0→-, `object-copy` 0.1.0→-, `object-
keys` 1.1.1→-, `object-visit` 1.0.1→-, `object.assign` 4.1.2→-, `object.omit` 1.1.0,2.0.1→-, `onetime` 1.1.0→-, `os-homedir` 1.0.2→-, `os-locale` 1.4.0→-, `os-tmpdir` 1.0.2→-, `osenv` 0.0.3,0.1.5→-,
`parse-glob` 3.0.4→-, `pascalcase` 0.1.1→-, `path-array` 1.0.1→-, `performance-now` 2.1.0→-, `popper.js` 1.16.1→-, `posix-character-classes` 0.1.1→-, `preserve` 0.2.0→-, `promised-io` 0.3.5→-,
`pseudomap` 1.0.2→-, `psl` 1.8.0→-, `punycode` 2.1.1→-, `randomatic` 3.1.1→-, `regex-cache` 0.4.4→-, `regex-not` 1.0.2→-, `remove-trailing-separator` 1.1.0→-, `repeat-element` 1.1.3→-, `request`
2.51.0,2.53.0,2.88.2→-, `require-directory` 2.1.1→-, `require-main-filename` 1.0.1→-, `resolve-url` 0.2.1→-, `ret` 0.1.15→-, `safe-regex` 1.1.0→-, `sass-graph` 2.2.6→-, `scss-tokenizer` 0.2.3→-, `set-
blocking` 2.0.0→-, `set-getter` 0.1.0→-, `set-immediate-shim` 1.0.1→-, `set-value` 0.2.0,2.0.1→-, `setprototypeof` 1.1.1→-, `snapdragon` 0.8.2→-, `snapdragon-node` 2.1.1→-, `snapdragon-util` 3.0.1→-,
`sntp` 0.2.4,1.0.9→-, `source-map-resolve` 0.5.3→-, `source-map-url` 0.4.0→-, `spdx` 0.4.3→-, `split-string` 3.1.0→-, `sshpk` 1.16.1→-, `static-extend` 0.1.2→-, `statuses` 1.5.0→-, `string-width`
1.0.2,2.1.1→-, `stringstream` 0.0.6→-, `tar` 1.0.3,2.1.1,2.2.2→-, `to-object-path` 0.3.0→-, `to-regex` 3.0.2→-, `toidentifier` 1.0.0→-, `tough-cookie` 0.12.1,2.5.0,4.0.0→-, `tunnel-agent`
0.4.3,0.6.0→-, `tweetnacl` 0.14.5→-, `underscore` 1.7.0→-, `union-value` 1.0.1→-, `unpipe` 1.0.0→-, `unset-value` 1.0.0→-, `uri-js` 4.4.0→-, `urix` 0.1.0→-, `use` 3.1.1→-, `uuid` 2.0.3,3.4.0→-,
`verror` 1.10.0→-, `which-module` 1.0.0→-, `wide-align` 1.1.3→-, `wrap-ansi` 2.1.0→-, `y18n` 3.2.1→-, `yallist` 2.1.2→-, `yargs-parser` 5.0.0-security.0→-

**What this table is evidence of, and what it is not.** Every row is a consequence of one of five decisions taken earlier on this page — six forced build-tool changes, twenty-two dead-package removals, nine registry aliases, four base-fidelity pins and one spec-form change — plus npm's resolver behaving differently from yarn's inside ranges neither this migration nor the base commit pinned. It is not evidence that each of the 670 was individually chosen; the ones that were chosen are the twenty in the first two tables, and those are the rows a reviewer should read. What it does establish is that no changed resolution is unaccounted for, which is the claim R-1 actually asks a lockfile to support.

**The bundled asset contract is a separate and stronger claim.** Of everything in the tables above, only the packages `config/env/all.js` loads reach a browser, and those are governed by the 53 base-commit SHAs and the nine alias byte comparisons recorded earlier — not by this churn table. `grunt-contrib-clean` resolving 2.0.1 where yarn had 2.0.0, for instance, changes which implementation of a directory delete runs during the build and changes no shipped byte.

### The 53 GitHub-sourced specs

**49 of the 53 are a pure syntax rewrite**: `#<range>` → `#semver:<range>`, same owner, same repository, same range — verified mechanically by taking each migrated value, deleting the seven characters `semver:`, and comparing the result against the base-commit value. On those 49, no range was restated or normalised and no `v` prefix was stripped.

Four are not a pure syntax rewrite, and each one is here because the pure rewrite **broke the other half of the same instruction** — "the same resolved commits", "zero version movement". They are named up front rather than buried, because a reader diffing this manifest against the base commit will find exactly these four and no others:

| Entry | Base-commit spec | Delivered spec | Why it is not the mechanical form |
| --- | --- | --- | --- |
| `@bower_components/ace-builds` | `ajaxorg/ace-builds#^1` | `ajaxorg/ace-builds#semver:1.4.12` | `#semver:^1` resolves to today's newest 1.x — **1.44.0** (`184177de`) — where the base `yarn.lock` recorded **1.4.12** (`53be4234`). The pin resolves to that exact commit, and `1.4.12` **is** the tag name of it |
| `@bower_components/angular-dynamic-locale` | `lgalfaso/angular-dynamic-locale#^0.1.32` | `…#semver:0.1.37` | Same mechanism at a smaller scale: `^0.1.32` resolves to **0.1.38** (`fcf9c40d`) against the base's **0.1.37** (`dbefe31b`) |
| `@bower_components/angular-ui-router` | `angular-ui/angular-ui-router-bower#~0.2.15` | `npm:angular-ui-router@0.2.18` | The bower repository publishes no manifest, so an alias is unavoidable (see [the nine registry aliases](#the-nine-registry-aliases)) — but the alias must carry the version the base **resolved**, not the version its range text mentions. `~0.2.15` resolved to bower tag **0.2.18** (`2b8d5241`), and `git ls-remote` confirms that SHA is tag `0.2.18`. Proof at the byte level: `release/angular-ui-router.min.js` from `npm:angular-ui-router@0.2.18` is **md5-identical** (`0ef20b23…`) to the file in the base-resolved bower tree, while `@0.2.15` differs (`78c94563…`, 30,439 B against 32,440 B) |
| `@bower_components/multi-download` | `sindresorhus/multi-download#~2.0.0` | `https://codeload.github.com/sindresorhus/multi-download/tar.gz/af749d945646b8d737d5af587a60cb43c1640cb8` | The git spec resolves to the **right commit** and still ships the **wrong tree**: npm packs a git dependency through the package's own `files` allowlist, and `multi-download` 2.0.1 declares `"files": ["index.js"]`, so the repository's checked-in `browser.js` — the browserify bundle that defines the `multiDownload` global — is not installed at all. The tarball form fetches the same commit as an immutable archive, which is what yarn did at the base commit (`yarn.lock` records that identical codeload URL), ships `browser.js`, and additionally gives npm an `integrity` hash to record where the git form had none |

**Measured result of those four: 53 of 53 GitHub-sourced coordinates in the committed lockfile resolve to exactly the commit the base `yarn.lock` recorded.** Before them it was 51 of 53. The lockfile change was surgical — the tree still holds 451 entries with none added or removed, and exactly three package versions moved.

The root cause is semantic rather than environmental: npm treats everything after `#` as a **literal git committish**, while bower treated it as a **semver range** with v-prefix normalisation. That is why `git checkout 1.4.14` fails when the repository's tag is `v1.4.14`. npm's `semver:` committish prefix restores the original meaning exactly.

**What the rewrite resolves to, measured against the base commit rather than asserted.** The base commit's `yarn.lock` recorded a resolved commit for every one of these dependencies, so the two sets can be compared directly: with the four pinned specs below in place, **all 53 resolve to the identical SHA the base commit recorded** — AngularJS at `63133dad`, bootbox at `cb756203`, angular-pdfjs-viewer at `dd7240e7`, and so on through the list. Forty-nine of the 53 need nothing but the syntax rewrite to get there.

Three of those 53 are worth naming, because a reader who checks the tag set will wonder how a range that looks unsatisfiable resolved at all. npm selects the tag whose **name** satisfies the range and reports the version from the package's own manifest, which in these three repositories is stale: `revolunet/angular-google-analytics#semver:1.1.8` resolves to tag `1.1.8` (`3b1e2cfe…`, manifest says 1.1.7); `legalthings/angular-pdfjs-viewer#semver:^0.8.1` resolves to tag `v0.8.1` (`dd7240e7…`, manifest says 1.0.0); and `legalthings/pdf.js-viewer#semver:^1.6.211` resolves to tag `v1.6.211` (`283ee830…`, manifest says 0.1.0). Each is the same commit the base-commit lockfile pinned, so the apparent mismatch is a stale manifest rather than a resolution problem.

**The four that are pinned instead of mechanically rewritten, and why.** Four of the 53 could not be delivered as a pure syntax rewrite without moving the vendor assets the pipeline ships, so each is pinned to the resolution the base commit's own `yarn.lock` recorded. With those four in place, **all 53 git-sourced coordinates resolve to exactly the base commit's SHA** — 53 of 53, verified by parsing that lockfile in full.

| Entry | Delivered spec | Base-commit resolution | What the pure rewrite did instead |
| --- | --- | --- | --- |
| `@bower_components/ace-builds` | `ajaxorg/ace-builds#semver:1.4.12` | 1.4.12 (`53be4234…`) | `#semver:^1` resolved 1.44.0 (`184177de…`), a 475,029-byte `ace.js` against the base commit's 370,746 |
| `@bower_components/angular-dynamic-locale` | `lgalfaso/angular-dynamic-locale#semver:0.1.37` | 0.1.37 (`dbefe31b…`) | `#semver:^0.1.32` resolved 0.1.38 (`fcf9c40d…`), 3,231 bytes against 3,259 |
| `@bower_components/angular-ui-router` | `npm:angular-ui-router@0.2.18` | `2b8d5241…`, whose `bower.json` declares 0.2.18 | the alias had been written `@0.2.15`, a 30,439-byte bundle against the base commit's 32,440 |
| `@bower_components/multi-download` | `https://codeload.github.com/sindresorhus/multi-download/tar.gz/af749d945646b8d737d5af587a60cb43c1640cb8` | `af749d94…` | the git form resolves the right commit but npm packs it through the package's own `"files": ["index.js"]` allowlist, so **`browser.js` never lands on disk** — and `config/env/all.js` loads exactly that file |

The `multi-download` case is the one that matters at runtime rather than at the byte level: with the git form, `node_modules/@bower_components/multi-download/browser.js` is absent, the Grunt asset walk drops it from `home.html`, and the deployed application loses the multi-file download helper without any build error. A direct commit tarball is not a version change — the SHA is the base commit's — it is the only spec form under which npm extracts the whole archive.

**The decision this reverses, stated so the record is not read as ever-consistent.** An earlier revision delivered all four as pure rewrites and defended the drift with the plan's own published artifact sizes, which the loose resolutions reproduce exactly. That argument was tested and inverted: a control build of the loose specs on this runner emits `vendors.min.js` at 4,096,775 bytes and `home.html` at 125,970 across 865 tags — the plan's figures to the byte — which establishes that the plan's reference build resolved these specs forward too, not that the drift is harmless. Objective B4 and R-7 both make the base commit's asset set the contract, so the four specs are pinned and two pipeline outputs move: `vendors.min.js` to **3,997,009** and `home.html` to **126,099** across **866** tags. The delta is attributed to the byte in [Smoke evidence](smoke-evidence.md).

**A fidelity check stronger than a version comparison, applied to the nine registry aliases.** For every file `config/env/all.js` loads from an aliased package, the installed copy was md5-compared against the base commit's bower tarball at the SHA `yarn.lock` names: **ten of the eleven files are byte-identical**, including angular-ui-router's minified bundle. The single exception is `ui-grid-draggable-rows/js/draggable-rows.js` — 8,645 bytes at the base commit's 0.2.2 against 11,794 at the registry's 0.3.3 — which is the forced delta recorded above, since 0.2.2 was never published.

#### The three restatements that are inert, and stay mechanical

`angular-google-analytics`, `angular-pdfjs-viewer` and `pdf.js-viewer` were also restated in an intermediate revision — to `semver:<=1.1.8`, `semver:<=1.0.0` and `semver:<=1.6.211`. Those three restatements are **withdrawn and stay withdrawn**, on measured grounds: each mechanical form already resolves to the **identical commit** the base `yarn.lock` recorded (`3b1e2cfe`, `dd7240e7`, `283ee830`), so restating them changes nothing except the diff. **R-1** forbids a change without a reason, and "no reason" is exactly what a no-op restatement has. This is the boundary the four pins above sit on the other side of: a spec is restated **only** where the mechanical form provably lands on a different commit or a different tree, never for uniformity.

#### What the four pins cost, in bytes rather than in reassurance

Each pin was measured at its consuming path, not at its version number, and the effect on the emitted bundles is fully attributed:

| Input | Delivered (base-resolved) | Mechanical form | Effect on `vendors.min.js` |
| --- | ---: | ---: | ---: |
| `ace-builds/src-min-noconflict/ace.js` | 370,746 B | 475,029 B | **−104,283** |
| `angular-dynamic-locale/dist/tmhDynamicLocale.min.js` | 3,259 B | 3,231 B | **+28** |
| `angular-ui-router/release/angular-ui-router.min.js` | 32,440 B | 30,439 B (`@0.2.15`) | **+2,001** |
| `multi-download/browser.js` | 2,487 B present | absent | **+2,488** (the file plus its concatenation separator) |

Those four terms sum to **−99,766**, and the measured difference between the two builds' `vendors.min.js` is **3,997,009 − 4,096,775 = −99,766** — the arithmetic closes to the byte, with nothing unattributed. The rendered `home.html` gains the **129-byte** `<script>` line for `browser.js`, taking it to 126,099 B across **866** tags. Both figures, and the full emitted set, are in [Smoke evidence](smoke-evidence.md).

The `+2,001` row is worth a sentence of its own, because it closes an open question rather than merely reporting a number: the smoke record previously disclosed a 2,001-byte over-prediction in its base-resolved comparison that it could not attribute. That residual was the `angular-ui-router` alias, sitting one patch line below the version the base commit resolved. With the alias corrected it is accounted for, and no unexplained residual remains in either direction.

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
| `grunt-contrib-clean` | **2.0.1** | loads — **upgrade withdrawn**, spec held at `^2.0.0`; npm resolves the newest 2.0.x, where the base commit's yarn tree had 2.0.0. See the lockfile-churn section for why that is inventoried rather than pinned |
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
| `engines` | `{ "yarn": ">= 1.0.0" }` | `{ "node": ">=20.19.0 <21", "npm": ">=10" }` | Per **R-4**, this is what **declares** the supported runtime instead of accommodating an old one, and the yarn-only declaration is gone. A declaration alone is not enforcement, though — see the `.npmrc` row below |
| `.npmrc` | absent | `engine-strict=true` | This is what turns the `engines` block from advice into a precondition. npm's default is `engine-strict=false`, under which an out-of-range runtime prints an `EBADENGINE` warning and **installs anyway** — so a Node 6/8-era or Node 22+ runtime could still produce a `node_modules` tree and a bundle, which is precisely the outcome **R-4** exists to prevent. Measured: with this file present, `npm ci --ignore-scripts` on Node v22.23.2 / npm 11.18.0 exits **1** with `npm error code EBADENGINE … Required: {"node":">=20.19.0 <21","npm":">=10"} Actual: {"node":"v22.23.2","npm":"11.18.0"}`, and **no `--engine-strict` flag was passed** — the file alone holds the gate. npm reads it as project configuration for whichever directory the install resolves to, so the same rule applies to a developer run, the CI job and the deploy-time install in `~/.arkcase/tmp`, which is why it is also staged through `filesToCopyFromArchive`. Deliberately **not** set here: `ignore-scripts`, which must stay on the command line so it cannot also suppress the `prebuild` hook |
| `scripts` | `{ }` — empty | `prebuild`, `build`, `lint`, `sync-dev`, `merge-config`, `test` | `npm run build` is a validation item and had **no target at all** before. Each of the five maps to a task that really exists: `build` → the Grunt `default` chain, `lint` → `lint`, `sync-dev` → `sync-dev`, `merge-config` → `updateModulesConfig`; `prebuild` writes the generated profiles module. Nothing beyond those five is declared |
| `grunt` key | in **both** `dependencies` and `devDependencies` | one entry, in `devDependencies` | De-duplicated. The two occurrences also carried different ranges, so the duplication was not even self-consistent |

**A sixth script, beyond the plan's five.** The specification enumerates five scripts (§0.4.3: `prebuild`, `build`, `lint`, `sync-dev`, `merge-config`); the delivered manifest carries a sixth, `"test": "node --test scripts/"`. It is recorded here rather than left to be discovered because it is a scope addition, small as it is. It exists because this change set adds a Node test file, `scripts/ensure-profiles.test.js`, covering the prebuild helper the same specification requires — and a test file with no runner entry point is a test file nobody runs. It uses node's own built-in test runner, so it adds **no dependency**: `node --test` is a Node 18+ feature and the declared `engines` floor is 20.19.0. It is not wired into `prebuild`, `build` or any validation item, so no gate's behaviour changes by its presence. Measured: `npm test` reports 11 tests, 11 pass, 0 fail.

**A `test` script is also the one place the frontend has a runner at all.** The base commit declared `karma`, `karma-jasmine` and `jasmine-core`, but no karma target existed in the Gruntfile and no karma configuration file existed anywhere, so those three were removed as dead packages (see [The 22 removals](#the-22-removals)). Nothing in this change set restores a browser-test capability, and this script should not be mistaken for one — it runs one Node module's unit tests, not the AngularJS application's.

Every install of this manifest — developer, CI and deploy-time — must pass **`--ignore-scripts`**, and the reason is reproduced rather than asserted. npm prepares a git dependency by installing that repository's own devDependencies and running its lifecycle scripts, and `@bower_components/angular-xeditable` (`vitalets/angular-xeditable#semver:0.9.0`) declares `prepublish: bower update` with a devDependency set that reaches `grunt-jsdoc` → an old `jsdom` → **`contextify`**, a native module abandoned in 2015. Its node-gyp build cannot compile against modern V8. Measured on Node v20.20.2 / npm 10.8.2 against the committed lockfile:

```text
npm ci                        -> exit 1
npm error code 1
npm error git dep preparation failed
npm error npm error gyp ERR! cwd /root/.npm/_cacache/tmp/git-clone.../node_modules/contextify
npm error npm error gyp ERR! not ok

npm ci --ignore-scripts       -> exit 0   (added 447 packages, and audited 448 packages)
```

Skipping those scripts is the correct semantics rather than a workaround: these are prebuilt asset repositories with checked-in distribution directories, and their lifecycle scripts produce nothing the Grunt pipeline consumes. It is passed **on the command line at each invocation point** and deliberately **not** in the `.npmrc`, because `ignore-scripts` set as project configuration would also suppress the `prebuild` hook that `npm run build` depends on to write the generated profiles module.

### The committed lockfile

`package-lock.json` is **created** at **lockfileVersion 3**, and `yarn.lock` — 275,865 bytes — is **deleted**. The lockfile is the precondition for `npm ci`, which could not run at all before: there was no `package-lock.json` and no `npm-shrinkwrap.json` anywhere in the repository.

Measured composition of the committed lockfile: **451** `packages` entries — 1 root project plus 450 dependencies — of which **397** resolve to `registry.npmjs.org` tarballs, **52** to `git+ssh://git@github.com/…` coordinates and **1** to a `codeload.github.com` commit tarball. **398** entries carry an `integrity` hash — the 397 registry entries plus the commit tarball — and all **53** GitHub-sourced coordinates are pinned to a **full 40-character commit SHA**; none is a floating branch or tag. The word `yarn` does not appear anywhere in the file.

> The lockfile **must be produced by a real `npm install`**, never by `--package-lock-only`. That flag computes a dependency tree without fetching tarballs or running lifecycle scripts, and it therefore hides three of the failures this migration had to solve: the native lifecycle script, the last bower-only repository, and the peer conflict that only strict validation rejects. An earlier analysis using it concluded the lockfile problem was solved when it was not.

The yarn removal also reaches the **deploy path**, without which the migration would be cosmetic — the deployed application would still shell out to yarn at webapp startup:

- The install command in `spring-web-ark-angular-starter.xml` becomes `npm ci --ignore-scripts --engine-strict`, dropping the `--ignore-engines` flag that was **actively suppressing engine enforcement**. The three yarn-only flags beside it — `--skip-integrity-check`, `--no-progress`, `--non-interactive` — are dropped rather than translated, because `npm ci` is non-interactive and validates integrity from the lockfile by design. Two flags are carried instead: `--ignore-scripts`, for the reproduced `contextify` reason above (a plain `npm ci` exits 1 at git-dependency preparation, the copier turns a non-zero install into a `RuntimeException`, and the webapp then refuses to deploy); and `--engine-strict`, which replaces the dropped `--ignore-engines` with its exact opposite so a deployment host on the wrong Node version fails the install instead of assembling a webapp with it. The staged `.npmrc` carries the same setting, so the rule survives a hand-run install from the temp folder.
- `yarn.lock` becomes `package-lock.json` in the same file's `filesToCopyFromArchive` list, and `.npmrc` is added to it so the engine gate reaches the temp-folder install. `AngularResourceCopier` copies that list **before** running the install and its post-install prune preserves everything it copied, so no Java change was needed for the new file.
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
- **A git client is required, and this is measured rather than assumed.** 52 of the 53 GitHub-sourced dependencies are recorded in the lockfile as `git+ssh://git@github.com/…` URLs pinned to a full commit SHA — that is how npm normalises a GitHub coordinate even when the spec is written with https. An earlier revision of this page claimed that the SHA pinning lets npm fetch them as codeload tarballs so that neither git nor an SSH key is needed. **That claim is false and is withdrawn.** Tested directly: `npm ci --ignore-scripts` against this committed lockfile, with a warm npm cache and a `PATH` containing node, npm, npx, sh, bash, env, tar, gzip and timeout but **no git**, fails with exit **254** and `npm error code ENOENT / npm error syscall spawn git / npm error path git / npm error enoent An unknown git error occurred`. The one exception is `multi-download`, whose spec is an explicit `codeload.github.com` tarball URL and needs no git.
- **So the transport is a prerequisite, not an implementation detail**, and it is exactly what the migration plan specifies: `npm ci` needs git on the path plus **either** SSH reachability to `github.com` **or** the `git config --global url."https://github.com/".insteadOf` rewrite rules that map the ssh forms onto https. Provisioning it belongs to the **host or build image, not to this repository** — ship a deploy key for `git@github.com`, or the rewrite rules. `.gitlab-ci.yml` records it as an infrastructure precondition of the runner image alongside the JDK 17 / Node 20 requirement, `README.md` and [the developer setup guide](../setup.md) state it for a developer machine, and the deployed application configures nothing on the host itself. The validation runs on this checkout succeeded **with** four such rewrite rules configured globally.

## The four-way `javax.annotation` overlap, measured and left alone

Three of the four reinstated EE artifacts land on a classpath that had no other supplier of their packages. The fourth does not, and the in-POM note beside `javax.annotation-api` points here for the measurement.

`WEB-INF/lib` of the assembled JDK 17 WAR carries **exactly one** `jaxb-api` (2.3.1), **one** `jaxb-runtime` (2.3.9) and **one** `javax.activation` (1.2.0) — the exclusions on those two declarations are what guarantee it. It carries **four** suppliers of the `javax.annotation` packages:

| Jar | How it arrives | Introduced by |
| --- | --- | --- |
| `javax.annotation-api-1.3.2` | Declared in the root POM's global `<dependencies>` | **This migration** |
| `tomcat-annotations-api-9.0.35` | `tomcat-catalina:9.0.35` ← `acm-service-ecm` | Pre-existing |
| `jsr250-api-1.0` | `javax.enterprise:cdi-api:1.0` ← `acm-configuration` | Pre-existing |
| `jakarta.annotation-api-1.3.5` | `spring-boot-starter:2.4.0` ← `camel-spring-boot-starter:3.7.0` ← `acm-camel-context-manager` | Pre-existing |

**Why no exclusion was added, measured rather than assumed.** The question that matters for a duplicate API jar is whether classpath order can change which member set wins. It cannot here, because three of the four are member-identical. Comparing the jars directly with `javap`:

- `javax.annotation-api-1.3.2`, `tomcat-annotations-api-9.0.35` and `jakarta.annotation-api-1.3.5` each publish the **same 15** `javax.annotation` types, and the same **7-member** `javax.annotation.Resource` including `lookup()`.
- `jsr250-api-1.0` publishes **11** of those types — a strict subset — and a **6-member** `Resource` with no `lookup()` and a raw `Class type()`.

So the only divergent shape is `jsr250-api`'s, it was already on the base commit's classpath, and this migration neither adds it nor changes its position. What the migration adds is a fourth jar that is member-identical to two suppliers already present. There is no reachable behaviour in which its arrival changes a resolution outcome, which is precisely the difference from `jaxb-api` and the activation artifacts — there, a second copy at a *different version* was a real possibility, which is why those declarations carry exclusions and this one does not.

**Why that decides it under R-1.** R-1 admits a dependency change only with a specific reproduced Java 17 or Node 20 failure behind it. Adding three exclusions here would be a dependency change with **no reproduced failure at all**: the full reactor builds, the configured suite is green, and the WAR deploys with all four jars present. Tidiness is not a reason R-1 accepts — the same standard that withdrew nine Maven candidates. So the overlap is recorded and left exactly as it is.

**The recommended follow-up, for whoever owns the classpath rather than this migration.** `jsr250-api-1.0` is the one worth removing, and not because of the overlap: it arrives through `javax.enterprise:cdi-api:1.0`, a CDI API this application does not use, and it is the only supplier whose `Resource` lacks `lookup()`. Excluding it would leave three identical suppliers and one fewer unused API jar. That belongs in a dependency-hygiene change with its own build-and-deploy verification, not in a compatibility migration.

## The Maven advisory and support-lifecycle position

The frontend graph has [a published advisory position](known-issues.md#the-npm-advisory-position); the Maven set had none, which left R-1's auditable record without an owner or an expiry for the one thing a version table cannot express — that some of these versions will never receive another patch. This section supplies it, in the same shape.

**The versions are compliant and are not in question here.** Spring 6 and Spring Boot are explicit exclusions of this migration, so staying inside 5.3.x and 5.4.x is what the specification requires, and the `javax` namespace is likewise mandated rather than chosen. Nothing below argues for a different version. What is recorded is the accepted risk that follows from the mandated ones.

| Artifact | Delivered | Lifecycle position | Consequence |
| --- | --- | --- | --- |
| `org.springframework:spring-*` | 5.3.39 | Terminal release of the 5.3 line. 5.3.x is past its OSS support window; further fixes for that line are commercial-only | Any future Spring CVE affecting 5.3.x will have no free patch. The remedy is Spring 6, which this migration excludes, so it is a replatform decision rather than a bump |
| `org.springframework.security:spring-security-*` | 5.4.11 | Terminal release of the 5.4 line, and **an improvement on the base commit's 5.4.2** — nine patch releases of accumulated fixes | Same as above. Worth stating that this line moved *forward* on security, not sideways; holding 5.4.x is also what keeps the external configuration's `spring-security-5.4.xsd` references valid |
| `javax.xml.bind:jaxb-api` | 2.3.1 | Terminal in the `javax` namespace; the successor is `jakarta.xml.bind-api`, which this migration forbids | Permanent, never-to-be-patched WAR surface |
| `org.glassfish.jaxb:jaxb-runtime` | 2.3.9 | Last 2.3.x; 3.x and 4.x are jakarta-namespaced | Same. This is the largest of the four in attack surface, because it is a runtime rather than an API jar |
| `javax.annotation:javax.annotation-api` | 1.3.2 | Terminal, full stop — 1.3.2 is the final release the coordinate will ever have | Same |
| `com.sun.activation:javax.activation` | 1.2.0 | The coordinate's only release | Same |
| `org.easymock:easymock` | 4.3 | Last 4.x | **Test scope only.** It is never packaged, so it adds no deployed surface; recorded for completeness rather than as risk |

**What the four reinstated `javax` artifacts actually add.** They are the migration's own contribution to this position, so they are not softened: JEP 320 removed these modules, the specification forbids their jakarta successors, and the only remaining suppliers are these terminal `javax`-namespaced jars. That is four permanently unpatchable jars added to the WAR, in exchange for 137 import statements staying byte-identical. The trade is the one the plan chose; the cost is stated here so it is not discovered later.

**Compensating controls already in force.** Every version is centralised in the root POM, so the whole surface is a single-file audit rather than a hunt across 145 POMs. The reinstated surface is kept `javax`-only by explicit exclusions, so no second, different-version copy of `javax/xml/bind` or `javax/activation` can arrive through a transitive path. And two of the four are API-only jars, whose exposure is annotation and interface metadata rather than parsing logic.

**Verification of the version claims — the review's disclosed limit is closed.** The review that raised this gap could not re-verify the "latest patch of the line" and "last 4.x" claims, because `web_search` returned nothing in its environment and `~/.m2` caches no `maven-metadata.xml`. Direct registry access was available for this record, and all seven were checked against `maven-metadata.xml` on `repo1.maven.org`:

| Coordinate | Claim | Result |
| --- | --- | --- |
| `spring-core` | 5.3.39 is the newest 5.3.x | **Confirmed** — 40 releases in the 5.3 line, 5.3.39 highest |
| `spring-security-core` | 5.4.11 is the newest 5.4.x | **Confirmed** — 12 releases in the 5.4 line, 5.4.11 highest |
| `easymock` | 4.3 is the last 4.x | **Confirmed** — 6 releases in the 4 line, 4.3 highest |
| `jaxb-api` | 2.3.1 is the newest 2.3.x | **Confirmed** — 3 releases in the 2.3 line. A later `2.4.0-b180830.0359` exists but is a milestone build, not a release |
| `jaxb-runtime` | 2.3.9 is the last `javax`-namespace release | **Confirmed** — 14 releases in the 2.3 line, 2.3.9 highest; the absolute latest is 4.0.9, which is jakarta |
| `javax.annotation-api` | terminal at 1.3.2 | **Confirmed** — 1.3.2 is the coordinate's absolute latest across 8 releases |
| `com.sun.activation:javax.activation` | 1.2.0 is the only release | **Confirmed** — exactly one version published |

**Owner and review date.** This position is **unowned as delivered**, and that is the gap R-1 cares about rather than the versions themselves. It needs a named owner — the same owner who holds the [npm advisory decision](known-issues.md#the-npm-advisory-position), since both resolve to the same question about how long a frozen stack is carried — and a review date no later than **the next dependency-affecting release of this application**, whichever comes first with any of: a published CVE against Spring 5.3.x, a published CVE against a `javax`-namespace JAXB artifact, or a decision to move to Spring 6. Until an owner accepts it, the accepted risk in this section is recorded but not agreed.

**Decision required:** accept the terminal Spring lines and the four terminal `javax` artifacts for production with a named owner and the expiry above, or schedule the jakarta and Spring 6 migration that retires all six together. The two cannot be separated — Spring 6 requires the jakarta namespace — so this is one decision, not two.

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
| Reactor | 142 modules; 145 POMs; **79** modules with test sources (76 at the base commit, plus `acm-services/acm-service-convert-file`, `acm-user-interface/ark-angular-starter` and `acm-web`), of which 66 emit a surefire report |
| Java sources | **3,055** main and **407** test — one main source added (the LDAP provider loader) and **five test sources added, none edited and none removed**, so the base commit's 402 test files are all still present and all still byte-identical |
| Maven change set | 4 dependencies added; 5 dependency versions moved (3 found by the build and unit suite, 2 by deployment); 4 build plugins moved; 9 candidates withdrawn |
| Removed EE APIs reinstated | 137 `javax.xml.bind` import lines in 84 tracked Java sources (82 main, 2 test) across 21 Maven modules; 4 `javax.annotation` lines in 4 files; 8 `javax.activation` lines in 6 files; zero JAX-WS-family imports. Counted with `git grep -c '^import <package>' -- '*.java'` |
| Frontend change set | 108 → 86 dependencies + 1 devDependency; 6 forced package changes; 22 removals; 9 aliases; 53 GitHub-sourced specs; 19 unchanged, decomposing as **12** withdrawn candidates (8 probe-cleared build plugins + 4 Node-API packages) and **7** that were never candidates |
| Committed lockfile | `lockfileVersion` 3; 451 entries (397 registry, 52 git, 1 pinned codeload tarball); every GitHub coordinate at a full commit SHA and matching the base `yarn.lock` 53 of 53; `yarn.lock` deleted (275,865 bytes) |
| Gruntfile | unchanged — zero-byte diff |
| Module-access directives | **8 test-scope and none in production** — 8 in the surefire `argLine`, 2 of those repeated in failsafe's, 10 configuration lines in the root POM and nowhere else. ArkCase's published `JAVA_OPTS` grants no module access. One runtime observation about what a container's own launcher supplies is held open in [the add-opens exceptions record](add-opens-exceptions.md#an-unreconciled-runtime-observation-not-a-production-grant) |
| Static audit | 7 hits before, **0** after, in both main and test sources |
| CI | image `1.0.2` → `2.0.0`; 4 removals of a JVM flag JDK 14 deleted |

## Honest disclosures

Collected in one place so that none of them has to be discovered by cross-reading.

- **Nothing here rests on third-party commentary.** No upgrade guide, forum answer or vendor page is cited anywhere in this inventory; every claim rests on registry metadata, artifact inspection, the committed files, or a command that was executed and whose output is quoted.
- **Two of the five version moves were invisible to the build and the unit suite, and an earlier version of this page therefore recorded EclipseLink as exonerated.** It was not. Deploying the artifact and logging in proved that EclipseLink's repackaged ASM cannot read release-17 bytecode and that Spring LDAP 2.3.3 cannot be class-initialised on Java 17 at all. Both are inventoried above with their reproductions; the JPA runtime itself still does not move. The general lesson is recorded rather than smoothed over: a green reactor build and a green unit suite are **not** sufficient evidence that a runtime migration works.
- **`ui-grid-draggable-rows` moved versions, and the move was forced.** The base-commit pin 0.2.2 was never published. The registry's lowest available release is 0.3.0, not 0.3.3; the manifest takes 0.3.3, the newest of the four published. An earlier note that called 0.3.3 "the lowest available" is corrected here.
- **Four of the 53 GitHub-sourced coordinates are not the literal mechanical rewrite, and an earlier revision of this page argued the opposite.** It shipped `ace-builds#semver:^1` and `angular-dynamic-locale#semver:^0.1.32` as floating ranges resolving forward to 1.44.0 and 0.1.38, aliased `angular-ui-router` from its range *text* to 0.2.15 rather than from what it *resolved* to, and left `multi-download` as a git spec that omits `browser.js` — then recorded all four as inherent to the mapping. That was wrong on the mapping's own terms: the same instruction requires "the same resolved commits" and "zero version movement", and a spec form that satisfies the syntax while breaking the resolution satisfies the lesser half. All four now carry the base-resolved value, **53 of 53** coordinates match the base `yarn.lock`, and the three genuinely inert restatements stay withdrawn under R-1.
- **`multi-download`'s `browser.js` was missing from an earlier revision of this change set, and that was a live defect rather than a documentation item.** npm applies the package's own `"files": ["index.js"]` allowlist to a git dependency where yarn extracted the whole repository tarball, so the asset path did not resolve, `vendors.min.js` carried no `multiDownload` definition, and the bulk-download actions in `services/resource/multi-download.client.service.js`, `services/ecm/ecm-multi-download.client.service.js` and the FOIA and privacy queue paths would have called an undefined global. Registering it under **R-6** was the wrong disposition — it is not a base-commit defect but one the package-manager switch introduced, so R-6 never applied — and the pinned codeload tarball restores the base-commit tree. The emitted bundle now contains the UMD global assignment `g.multiDownload = f()` and `home.html` renders **866** script tags.
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
| [Module-access exceptions](add-opens-exceptions.md) | The eight test-scope directives, each attributed to the pinned library and the exact stack frame that demanded it; the certification that production launch configuration grants nothing; and the unreconciled runtime observation it holds open |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative test totals, the two class-level exclusions and their collateral cost |
| [Static audit](static-audit.md) | The audit command, the seven classified hits before and the zero after |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour, including the withdrawals summarised here |
| [Known issues](known-issues.md) | Pre-existing defects documented and deliberately not fixed |
| [Smoke evidence](smoke-evidence.md) | The baseline-then-migrated smoke capture and the reduced-local-stack rationale |
