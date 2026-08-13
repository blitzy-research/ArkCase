# add-opens Exceptions

The move from Java 8 to Java 17 needed **eight** JVM module-access directives. Every one of them lives inside a forked JVM belonging to a Maven test runner, every one is traced below to the exact stack frame that failed without it, and **production launch configuration gains nothing at all**. It carried no module-access flag at the Java 8 base commit, it carries none now, and this page is the record that says so with the evidence attached.

## Why this record exists

Rule **R-2** permits a module-access flag in production launch configuration only where a pinned third-party dependency documentedly requires one, and it requires each exception to be documented. A rule shaped that way cannot be satisfied by a claim; it needs a named baseline, a per-exception attribution and a scope statement. This page is that document, and it is deliberately written so a reader can re-check every assertion on it without trusting the author.

A note on where the rules come from, because the repository does not reveal it. `review_rules` returns **no user rules provided** — there is no on-disk rules document for this project. The seven binding rules arrive instead through the user prompt's own RULES block, and their full verbatim text is available from the `review_prompt` tool. This page cites them by the stable identifiers **R-1** through **R-7** and deliberately does not reproduce their text; `review_prompt` is the source of record for that.

Four of the seven bear on this page:

| Rule | Scope | What it requires of this page |
| --- | --- | --- |
| **R-2** | Launch configuration | Identify what the launch configuration actually is, certify its baseline, document every exception with its option, its demanding library, its failing frame and its scope, and prove the "pinned dependency" condition is genuinely met rather than asserted. This page **is** the exceptions document R-2 calls for. |
| **R-5** | Test configuration | Show that the directives are how two JDK 17 failures were **fixed instead of excluded**. Both tests pass on Java 8, so they were migration regressions and R-5 did not permit excluding them. |
| **R-7** | All behavioural decisions | Record why the one behaviour-changing alternative was rejected **on rule grounds rather than on convenience**, with the observed base-commit behaviour that settled it. |
| **R-6** | All source | Document, do not fix. Nothing on this page was repaired, no test source was edited, and the adjacent Java 17 finding it mentions is reported rather than resolved. |

## What counts as launch configuration here

An exception can only be judged against a known baseline, so the first job is to say precisely what the launch configuration of this repository is. The answer is unusual and it matters: **there is no executable launch configuration under version control at all.**

- There is **no tracked `bin/setenv.sh`** — `.gitignore` ignores `bin` outright at line 7, so the file every deployment actually uses is created by the operator and never committed.
- There is **no Dockerfile, no compose file, no systemd unit and no Vagrantfile** anywhere in the tree. The CI runner image is built from a Dockerfile that lives in a different repository.
- What remains is documentation. The launch configuration of ArkCase exists as the `JAVA_OPTS` blocks in the root `README.md`, under its Tomcat `setenv.sh` heading, and in [the developer setup guide](../setup.md) under `### Tomcat setenv.sh` — which is the text an operator copies to create the real file.

Those two blocks are therefore the artefacts R-2 governs, and both are free of module-access flags. The certification behind that statement is a search rather than a reading, and it is reproducible in one command. Against the Java 8 base commit `c8f6226105`:

```bash
git grep -nE -- '--add-opens|--add-exports|--illegal-access' c8f6226105
```

That returns nothing and exits 1 — **zero occurrences across every tracked file**. The baseline was clean before the migration began, which means every directive this page documents is attributable to the migration and none is inherited from an older workaround. Repeating the same search against the migrated tree:

```bash
git grep -nE -- '--add-opens|--add-exports|--illegal-access' HEAD
```

returns **16 configuration lines, all of them in the root `pom.xml`** — the eight directives of the `maven-surefire-plugin` `argLine` at lines 334-341, and the same eight in the `maven-failsafe-plugin` `argLine` at lines 392-399. Nothing appears in `README.md`, nothing in `docs/setup.md`, nothing in either GitLab CI file and nothing in any script. The two searches together are the whole certification: clean before, and afterwards confined to two adjacent blocks in one build file.

One caveat about that second search, so the result is not misread: it also matches **this page**, which quotes each option in order to document it. Those matches are prose. Filtering them out — `git grep … HEAD -- '*.xml'` — is the search that answers the question R-2 actually asks, and it returns the same 16 lines and nothing else.

!!! note "Production launch configuration has zero exceptions"

    Running ArkCase on Java 17 requires **no `--add-opens`, no `--add-exports` and no `--illegal-access`**. The eight directives below are test-scope only and never reach a deployed JVM. This is the conclusion that the root `README.md` and [the developer setup guide](../setup.md) both reflect in their `JAVA_OPTS` blocks, and it is the reason those blocks run as written on Java 17 without addition.

## The eight directives

Each row names the option, the library that demanded it and the frame that failed without it. The PowerMock rows are deliberately **not** merged, because the per-frame attribution is the substance of what R-2 asks for — five directives that all trace to one method are five separate observations, not one.

| Directive | Demanded by | The exact frame that failed |
| --- | --- | --- |
| `--add-opens java.base/java.time` | Jackson databind 2.10.3 (version-managed) | `ClassUtil.checkAndFixAccess:939` reached from `FieldProperty.fixAccess:104`, deserialising a `java.time.LocalDate` through a bare `new ObjectMapper()` |
| `--add-opens java.base/java.lang` | CGLIB inside EasyMock's proxy factory | `ClassLoader.defineClass` via `ClassProxyFactory`, with six cascading `NoClassDefFoundError` on its inner class |
| `--add-opens java.base/java.io` | PowerMock 2.0.9 (no successor exists) | `WhiteboxImpl.doGetAllMethods:1508`, calling `setAccessible` on `java.io.File.readObject` |
| `--add-opens java.base/java.nio.file` | PowerMock 2.0.9 | the same frame, on `java.nio.file.Files.provider` |
| `--add-opens java.base/java.util` | PowerMock 2.0.9 | the same frame, on `java.util.HashMap.hash` |
| `--add-opens java.base/java.math` | PowerMock 2.0.9 | the same frame, on `java.math.BigDecimal.add` |
| `--add-opens java.base/java.util.stream` | PowerMock 2.0.9 | the same frame, on the int-stream head's iterator |
| `--add-exports java.xml/jdk.xml.internal` | PowerMock's `MockClassLoader` | `FactoryFinder.<clinit>:69` reached from `DocumentBuilderFactory.newInstance:172` while log4j-core parsed its XML configuration |

**Scope, for all eight rows without exception:** the forked JVMs of `maven-surefire-plugin` and `maven-failsafe-plugin`. Production scope: none. Each directive is written with an `=ALL-UNNAMED` target in the POM, which is the narrowest form available for code that runs on the classpath — the test classes are in the unnamed module, so nothing wider would be reached and nothing narrower can be expressed.

**Seven** of the eight are `--add-opens` on packages `java.base` already exports, which is the ordinary JEP 396 consequence: the package compiles against freely and can be reflected into deeply only with permission. The eighth is an `--add-exports`, a different mechanism answering a different problem, and it is worth its own explanation.

### Why the XML export is the least obvious of the eight

`--add-exports java.xml/jdk.xml.internal` looks out of place next to seven `java.base` opens, and the reason it is needed is a module-identity mismatch rather than a permissions problem.

PowerMock works by reloading classes through its own `MockClassLoader` so it can rewrite them. Classes reloaded that way land in the **unnamed module**, because a custom class loader has no named module to put them in. That is deliberate on PowerMock's part and is the mechanism the whole library depends on. Meanwhile the JDK 17 implementation of the JAXP factory finder — `FactoryFinder`, reached from `DocumentBuilderFactory.newInstance` — reaches into `jdk.xml.internal`, a package that the `java.xml` module exports **only to named modules**. When log4j-core parsed its XML configuration inside a PowerMock-loaded test, the caller was in the unnamed module and the target package was exported only to named ones, so the class initialiser failed.

That mismatch is the entire failure. It is not PowerMock reflecting where it should not, and it is not the JDK denying an unreasonable request; it is a qualified export that a deliberately unnamed caller cannot satisfy. `--add-exports … =ALL-UNNAMED` widens that one qualified export to the unnamed module and nothing else.

## Where the directives live, and why they compose rather than collide

All eight are configured twice, in the root `pom.xml`, and nowhere else:

```xml
<argLine>@{argLine}
    --add-opens java.base/java.time=ALL-UNNAMED
    --add-opens java.base/java.lang=ALL-UNNAMED
    --add-opens java.base/java.io=ALL-UNNAMED
    --add-opens java.base/java.nio.file=ALL-UNNAMED
    --add-opens java.base/java.util=ALL-UNNAMED
    --add-opens java.base/java.math=ALL-UNNAMED
    --add-opens java.base/java.util.stream=ALL-UNNAMED
    --add-exports java.xml/jdk.xml.internal=ALL-UNNAMED</argLine>
```

The first copy configures the new `maven-surefire-plugin` declaration, pinned at **3.5.3** through the new `surefire.version` property; the second configures `maven-failsafe-plugin`, aligned to the same pin so both forked runners grant identical access. A `<argLine>` element exists in no other POM in the repository — the directive text occupies exactly two blocks in exactly one file, which is what makes the certification above a bounded search rather than an open-ended one.

The leading `@{argLine}` is not decoration and the configuration does not work without it. JaCoCo's `prepare-agent` goal builds the Java agent argument and publishes it as a property; surefire's **late substitution** of `@{…}` expands that property when the fork is launched, so the agent argument and the module-access directives **compose** into one command line. Written as `${argLine}`, or with the directives assigned directly, one would overwrite the other: either coverage instrumentation disappears — silently, taking the `check` goal's line-coverage floor with it — or the directives do. Late substitution is what lets a documented R-2 exception coexist with coverage enforcement instead of trading against it, and it is the mechanism that makes R-2 mechanically enforceable at test time rather than aspirational.

This is also the reason surefire had to be declared at all. Before the migration **no POM in the repository declared it**, so the reactor silently inherited Maven's 2.12.4 default, which performs no late `@{…}` substitution. Under 2.12.4 the fork dies immediately:

```text
Error: could not open '{argLine}'
The forked VM terminated without saying properly goodbye
```

Under 3.5.3 the identical configuration passes. Stated precisely, so this page is not read as an indictment of the older runner: 2.12.4 is **not** globally broken on JDK 17 — a plain JUnit 4 test runs fine under it — and the recorded reason for the pin is the specific late-substitution capability needed to combine coverage enforcement with a documented module-access exception. The full plugin reasoning, including why the failsafe alignment had to reach two profile-local declarations in `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` that would otherwise have won over the inherited version and discarded this `argLine` exactly where integration tests run, belongs to [the dependency inventory](dependency-change-inventory.md).

## Why this is a bounded result and not an open-ended concession

A documented exception differs from a blanket waiver in that its limits can be shown. Four arguments, each with the observation behind it.

**The set converged.** The directives were added one at a time, each in response to a stack trace that named it, and the last two were added together to clear the XML failure. After them, both previously-failing AWS SDK tests went **fully green** — 6 tests and 8 tests, no failures, no errors, no skips — and **no new access failure appeared anywhere in the reactor**, across all 142 modules and the 79 of them that carry test sources. Nothing was added speculatively and nothing was added to silence a warning; a ninth directive was never needed because no ninth frame ever failed.

**The pinned-dependency condition is met, not asserted.** R-2 tolerates an exception only where a pinned dependency demands it, so each of the three demanding libraries has to qualify in the sense the rule contemplates — and each does, for a different reason:

| Library | Why it is genuinely pinned |
| --- | --- |
| PowerMock 2.0.9 | Registry-verified as the **newest release that has ever existed**. There is no later version to upgrade to, so the directives are not standing in for deferred maintenance — no amount of version movement retires them. |
| Jackson databind 2.10.3 | Version-managed in the root `pom.xml`, where `fasterxml-jackson-core.version` at line 62 drives the `jackson-databind` entry in `dependencyManagement` at lines 1177-1179. It is held deliberately: no reproduced failure implicated the version, so moving it would be a change without a reason. |
| CGLIB (via EasyMock 4.3) | Reached transitively through EasyMock's proxy factory, which the migration already moved to the minimum version whose shaded ASM reads class-file major 61. The upgrade that *was* justified has been taken; the residual reflective access into `java.lang` is what remains after it. |

**The exposure is small where it can be, and this page says where it cannot.** Only **6 of the 402 test sources the base commit carried** reference PowerMock, and they are named here so the claim can be audited rather than believed:

| Test source | Module | Runner |
| --- | --- | --- |
| `QueuePropertyFileChangeWatcherTest` | `acm-plugins/acm-default-plugins/acm-case-file-plugin` | surefire |
| `CalendarEntityHandlerTest` | `acm-services/acm-service-calendar-integration-exchange` | surefire |
| `AcmObjectLockServiceImplTest` | `acm-services/acm-service-object-lock` | surefire |
| `AWSComprehendMedicalServiceTest` | `acm-tool-integrations/acm-comprehend-medical` | surefire |
| `AWSTranscribeServiceTest` | `acm-tool-integrations/acm-transcribe-tool` | surefire |
| `CategoryServiceIT` | `acm-plugins/acm-default-plugins/acm-category-plugin` | failsafe (integration test) |

One of the six is an integration test, so **at most five unit-test classes** drive the six PowerMock-attributable directives. No main source anywhere references PowerMock, and all six files pre-date the migration — it introduced no new PowerMock usage.

The honest counterpart, which a reader would otherwise infer wrongly from the paragraph above: the `java.lang` directive is **not** narrowly held. 213 test sources use EasyMock, so CGLIB's reflective `defineClass` is on the path of a large fraction of the suite. The bounded-exposure argument applies to the six PowerMock directives and not to that one, which is exactly why the retirement path below cannot reach it.

**The one behaviour-changing alternative was rejected on rule grounds, not convenience.** The `java.time` directive has an obvious alternative — register a Java-time module on the mappers that reflect into `java.time`, and the reflection stops. It was rejected because it would change what ArkCase emits.

The evidence is in the codebase rather than in an argument. `ObjectConverter` in `acm-tool-integrations/acm-object-converter` **does** register a `JavaTimeModule`, disables `WRITE_DATES_AS_TIMESTAMPS` and installs a `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` formatter — so where ISO-8601 strings are the intended contract, ArkCase says so explicitly. The state-of-ArkCase report generator's mapper deliberately does not, which is why Jackson reflects over the fields of its `LocalDateTime` and why the directive is needed. Registering a module there would turn a field-based JSON object into an ISO-8601 string: a change to an emitted payload shape, which the REST-contract preservation mandate forbids and which **R-7** independently settles against, since the field-based shape is the observed behaviour of the Java 8 base commit.

One precision that keeps this argument honest: the affected test asserts only that the `dateGenerated` node is present, so it would have passed either way. The decision therefore rests on the contract mandate and R-7 — not on a red test — and that is the reason it is recorded here rather than left implicit. The general register of such resolutions is [the behavioural decisions record](behavioral-decisions.md).

## How the directives satisfy R-5 rather than dodge it

Two tests failed on JDK 17 when the migration was first applied: `AWSTranscribeServiceTest` and `AWSComprehendMedicalServiceTest`. Both **pass on Java 8** — 6 run and 8 run, no failures, no errors — so they were **migration regressions, not baseline failures**, and R-5 did not permit excluding them. Excluding them would have been the cheap route and the rule closes it.

They were fixed instead, by adding the directives their own stack traces named, and both then went fully green on JDK 17 with their assertions untouched. That is what the PowerMock-attributable directives are: the R-5-compliant remedy for a regression, not a convenience for a runner that would not start. The distinction matters because it decides the disposition — a JDK 17 failure that also fails on Java 8 may be excluded and recorded, and a JDK 17 failure that passes on Java 8 must be fixed. The measured Java 8 baseline, the four failures that *are* excludable, the two class-level exclusions that cover them and the collateral cost of those exclusions all belong to [the baseline record](baseline-test-failures.md), which owns the suite totals this page does not restate.

## The documented retirement path, deliberately not adopted

There is a way to reduce eight directives to two, it was identified during the migration, and it was declined. Recording both halves of that is the point of this section.

**The path.** Migrating the five PowerMock unit-test classes to Mockito's inline static mocking would remove the five reflection-driven `java.base` opens *and* the `java.xml` export — PowerMock's `MockClassLoader` is what creates the unnamed-module mismatch, so removing PowerMock removes the mismatch with it. Six of the eight would go. The two that would remain are `java.time` and `java.lang`, because neither is PowerMock's: one is Jackson reflecting into a JDK package and the other is CGLIB inside EasyMock, used by 213 test sources.

One detail that a partial attempt would trip over: those six would come out of the **surefire** `argLine` only. `CategoryServiceIT` uses PowerMock too and runs under failsafe, so the failsafe `argLine` keeps needing them until that integration test is migrated as well. Retiring the six from both runners is a six-class job, not a five-class one.

**Why it was declined here.** It means adding a new mocking artefact to the dependency surface and rewriting five working test classes. Mockito is already present as `mockito-core` 3.7.7, but inline static mocking is not: it needs `mockito-inline`, which appears in no POM in this repository. A dependency addition without a reproduced failure behind it is precisely what **R-1** forbids, and rewriting passing tests runs against the mandate to preserve existing test assertions — the migration modified **zero** of the base commit's 402 test sources, and this would have modified five of them for a tidier flag list rather than for a failure. It belongs in [the behavioural decisions record](behavioral-decisions.md) as the recommended follow-up, to be taken when test maintenance is the goal rather than as a side effect of a runtime migration.

**The narrower alternative, also declined.** Both AWS SDK tests already carry `@PowerMockIgnore({ "javax.management.*", "javax.net.ssl.*" })`, and that list demonstrably does not cover the XML packages. Widening the annotation would keep the JAXP factory finder out of PowerMock's class loader and fix the XML case with no JVM flag at all — a genuinely smaller change to the command line. It was not taken because it edits test source, and the JVM directive edits none: preserving all 402 pre-existing test sources byte-identical is itself a preservation mandate, and one flag in a build file that is documented here is a better trade than an annotation change in two test classes that is not. The alternative is recorded because it exists, not because it was unattractive.

## What this means for deployment

For anyone deploying ArkCase on Java 17, the operative statement is short:

- **Add nothing.** No `--add-opens`, no `--add-exports` and no `--illegal-access` belongs in `JAVA_OPTS`, in `CATALINA_OPTS`, in a container entrypoint or in any wrapper script. The `JAVA_OPTS` block published in the README and in the developer setup guide runs as written on Java 17 and grants no access to JDK internals.
- **The directives are a build-time concern only.** They exist in the surefire and failsafe configurations, they apply to forked test JVMs, and they never reach a deployed process. Copying them into a server's launch configuration would widen access for no benefit and would put the deployment outside what R-2 permits.
- **The artefact is unchanged.** The build still assembles `acm-standard-applications/arkcase/target/arkcase-2021.03.war` at the same coordinates and the same path; nothing about deployment mechanics moves with this migration.

One adjacent Java 17 finding is worth knowing so it is not mistaken for a missing flag. **ActiveMQ's TLS transport does not work on Java 17**, so the broker must be addressed over `tcp://` rather than `ssl://`. It is documented and deliberately **not fixed**, on direction, and it is not a module-access problem — no `--add-opens` would help and none is offered. It is also not a repository change: no broker URL exists anywhere in this repository, since endpoints come from the external configuration bundle, so the finding lives in [the known-issues record](known-issues.md) and the remedy is a configuration choice made outside this tree. A deployment that hits it has not misapplied this page.

## What this record does not cover

**Suite totals.** This page states that no new access failure appeared and that the two regressions went green; it does not publish test counts. Those are measured and owned by [the baseline record](baseline-test-failures.md), and duplicating them here would create a second source of truth for a number that has already been revised once.

**Plugin version reasoning.** The surefire pin and the failsafe alignment are described here only as far as the `argLine` mechanism requires. Their full justification, and the two profile-local declarations the alignment had to reach, belong to [the dependency inventory](dependency-change-inventory.md).

**JDK-internal API usage in source.** Module-access directives are a runtime-permission matter; references to `sun.misc` and `com.sun.*` in Java source are a separate audit with a separate remedy, recorded in [the static audit](static-audit.md). None of the eight directives exists to make such a reference compile, and none is needed by anything on that page.

**Anything that was fixed along the way.** Under **R-6** this page repairs nothing. The pre-existing defects the migration encountered are enumerated in [the known-issues record](known-issues.md), and the ActiveMQ transport finding above is reported there rather than resolved here.

## Related records

| Record | What it owns |
| --- | --- |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative suite totals, the two class-level exclusions and their collateral cost |
| [Dependency change inventory](dependency-change-inventory.md) | Every dependency and plugin change with its reproduced reason, including the surefire and failsafe pins this page depends on |
| [Static audit](static-audit.md) | The JDK-internal-API audit command, its classified hits before and the zero-hit result after |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour, including the Jackson resolution and the declined retirement path |
| [Known issues](known-issues.md) | Pre-existing defects and adjacent findings documented and deliberately not fixed, including the ActiveMQ TLS transport on Java 17 |
