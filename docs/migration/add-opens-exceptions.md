# add-opens Exceptions

The move from Java 8 to Java 17 needed **eight** module-access directives, all of them in the build. **Production launch configuration carries none**, exactly as it carried none at the Java 8 base commit.

The eight live inside forked JVMs belonging to the Maven test runners, and each is traced below to the exact stack frame that failed without it. Surefire receives all eight; failsafe receives two.

Two production paths that *would* have needed a flag were found and closed in application code instead — the FOIA and SAR portal submission providers, which read their payload with a bare `ObjectMapper` over models carrying `java.time` properties — preserving the Java 8 request contract exactly. [Their measured before-and-after is below](#the-production-counterpart-of-this-directive-closed-in-code-rather-than-by-a-flag).

One measured runtime observation remains **unreconciled with R-2 and is escalated rather than published as guidance**: a stock Tomcat 9 launcher exports `--add-opens=java.base/java.lang=ALL-UNNAMED` of its own accord, and with that export neutralised the root context does not initialise. [What was measured, and what a human must decide](#an-unreconciled-runtime-observation-not-a-production-grant) records it as an open item. It is deliberately **not** written here as an instruction to add a flag anywhere.

### Read the runtime exception as an accepted risk, not as a closed question

A security review of this migration raised the runtime open as a finding in its own right, and it is right to: "Tomcat supplies it" explains why no line is added to `setenv.sh`, but it does not make the exposure smaller. So the position is stated here without softening, because a reader deciding whether to run this application is entitled to it:

- **The repository's own launch configuration grants nothing.** That is verifiable and is verified below. It is the part of R-2 this migration controls, and it holds absolutely.
- **The running application nevertheless depends on `java.base/java.lang` being open to the unnamed module.** `ALL-UNNAMED` is not targeted at the demanding library: it opens the JDK's most sensitive package to *every* jar on the classpath — 639 of them in this WAR — for the lifetime of the process. Reflection into `java.lang` internals is a common step in deserialisation and classloader attack chains, so the open widens what a foothold elsewhere in the application can reach.
- **Nothing in this migration's permitted scope retires it.** The demand belongs to Drools 7.34.0.Final and the Groovy it carries, both pinned; moving off them changes rule-evaluation behaviour, which the preservation mandate forbids and which no reproduced Java 17 failure justifies. Upgrading was tried as the first option wherever it worked — spring-ldap below is exactly that case — and it does not work here.
- **What that leaves is a decision, not a fix.** Either the open is accepted for this deployment, with an owner and a review date, or the rules/scripting stack is replanned as work of its own. This page cannot make that choice; it can only make sure nobody makes it by accident. The corresponding entry is in [the known-issues register](known-issues.md#the-runtime-module-access-open), and the migration plan's own statement that production carries *zero* exceptions is, read strictly, one exception out.

## Why this record exists

Rule **R-2** permits a module-access flag in production launch configuration only where a pinned third-party dependency documentedly requires one, and it requires each exception to be documented. A rule shaped that way cannot be satisfied by a claim; it needs a named baseline, a per-exception attribution and a scope statement. This page is that document, and it is deliberately written so a reader can re-check every assertion on it without trusting the author.

The migration's seven binding constraints are summarised once, in [the behavioural-decisions record](behavioral-decisions.md#the-constraints-this-migration-works-under), and cited here by the identifiers used across this set. Four bear on this page:

| Constraint | What it requires of this page |
| --- | --- |
| **R-2** — no production module-access flags except where a pinned dependency documentedly requires one | Identify what the launch configuration actually is, certify its baseline, document every exception with its option, its demanding library, its failing frame and its scope, and prove the "pinned dependency" condition is genuinely met rather than asserted. This page **is** that exceptions document. |
| **R-5** — exclusions limited to baseline failures | Show that the directives are how two JDK 17 failures were **fixed instead of excluded**. Both tests pass on Java 8, so they were migration regressions and excluding them was not permitted. |
| **R-7** — Java 8 base-commit behaviour is the tie-breaker | Record why the one behaviour-changing alternative was rejected **on rule grounds rather than on convenience**, with the observed base-commit behaviour that settled it. |
| **R-6** — pre-existing bugs are documented, not fixed | Nothing on this page was repaired, no test source was edited, and the adjacent Java 17 finding it mentions is reported rather than resolved. |

## What counts as launch configuration here

An exception can only be judged against a known baseline, so the first job is to say precisely what the launch configuration of this repository is. The answer is unusual and it matters: **there is no executable launch configuration under version control at all.**

- There is **no tracked `bin/setenv.sh`** — `.gitignore` ignores `bin` outright at line 7, so the file every deployment actually uses is created by the operator and never committed.
- There is **no Dockerfile, no compose file, no systemd unit and no Vagrantfile** anywhere in the tree. The CI runner image is built from a Dockerfile that lives in a different repository.
- What remains is documentation. The launch configuration of ArkCase exists as the `JAVA_OPTS` blocks in the root `README.md`, under its Tomcat `setenv.sh` heading, and in [the developer setup guide](../setup.md) under `### Tomcat setenv.sh` — which is the text an operator copies to create the real file.

Those two blocks are therefore the artefacts R-2 governs, and both are free of module-access flags. The certification behind that statement is a search rather than a reading, and it is reproducible in three commands whose exact filters matter — an unfiltered search over a repository that *documents* these options necessarily matches the documentation too, so the filter is the whole point.

**One: the baseline was clean.** Against the Java 8 base commit `c8f6226105`:

```bash
git grep -nE -- '--add-opens|--add-exports|--illegal-access' c8f6226105
```

returns nothing and exits 1 — **zero occurrences across every tracked file**. Every directive this page documents is therefore attributable to the migration, and none is inherited from an older workaround.

**Two: where the directives actually live.** The question R-2 asks is about configuration, so the search is filtered to it:

```bash
git grep -nE -- '--add-opens|--add-exports|--illegal-access' HEAD -- 'pom.xml'
```

returns **10 lines, all in the root `pom.xml`** — the eight directives of the `maven-surefire-plugin` `argLine` and the **two** of them the `maven-failsafe-plugin` `argLine` narrows to. **No other tracked configuration file matches at all**: not `README.md`, not [the developer setup guide](../setup.md), not either GitLab CI file, not a script, and not a single Java source. **10 is the number to reconcile against**, and it is the only configuration figure this page uses.

**Three: the unfiltered count, stated so that it cannot be mistaken for a finding.** The same search with no path filter at all:

```bash
git grep -nE -- '--add-opens|--add-exports|--illegal-access' HEAD
```

matches in exactly three kinds of place, and separating them is the whole point of running it:

| Where the unfiltered search matches | What they are |
| --- | --- |
| `pom.xml` | **10 lines. Configuration** — the eight directives of the `maven-surefire-plugin` `argLine`, and two of them repeated in the `maven-failsafe-plugin` `argLine`. The only configuration lines in the repository that grant module access |
| `docs/migration/*.md` | Prose. Every option is quoted in order to be documented, most of it on this page; the count moves whenever this documentation set is edited and is deliberately not pinned here |
| `README.md` and [the developer setup guide](../setup.md) | **1 line each. Prose, and specifically the *opposite* of a grant**: each is the sentence instructing that `JAVA_OPTS` stay free of `--add-opens`, `--add-exports` and `--illegal-access`, and that the test runners' directives must not be copied into a server |

Only the first row is configuration; every other match is documentation about configuration, and none of them is a production launch flag.

No **configuration** match exists anywhere but that one file: nothing in either GitLab CI file, nothing in any other POM among the 145, nothing in any script, and nothing in a `JAVA_OPTS` or `CATALINA_OPTS` line — the single match in `README.md` and the single one in [the developer setup guide](../setup.md) are the sentences that forbid adding one. Restricting the search to build files —

```bash
git grep -nE -- '--add-opens|--add-exports|--illegal-access' HEAD -- '*.xml'
```

— is therefore the form that answers the question R-2 actually asks, and it returns **those 10 `pom.xml` lines and nothing else**: eight inside the `maven-surefire-plugin` `<argLine>` and two inside the `maven-failsafe-plugin` `<argLine>`, the two blocks sitting adjacent in the root POM's `<build><plugins>` section. The two searches together are the whole certification: clean before, and afterwards confined to two adjacent blocks in one build file.

That 8-and-2 asymmetry is deliberate and is the subject of [Why the failsafe grant is narrower than the surefire grant](#why-the-failsafe-grant-is-narrower-than-the-surefire-grant) below. An earlier revision granted all eight to both runners, which mirrored access that no executable integration test asks for — least privilege is the rule, and mirroring is not the same as justifying.

Two notes on reproducing these numbers, because a slightly different search returns a different count and the difference is not a discrepancy.

- **Keep the leading `--`.** Searching for the bare word `add-opens` also matches the *filename* of this page wherever it is cited: once in `README.md`, once in `docs/setup.md`, and twice in `pom.xml` itself, where comments above each `argLine` point the reader here. Those four are cross-references to this document, not flags. The `README.md` and `docs/setup.md` matches in particular are the sentences that state **no** module-access flag is required in production — the opposite of an exception, and they sit immediately below `JAVA_OPTS` blocks that were read line by line and contain none.
- **The count is of the migrated tree, and the number is 10.** Run the same search against a working tree that still carries the earlier all-eight failsafe grant and the build-file figure is 16; that variant is not what is committed, and no table on this page reports it.

| File | Lines | What they are |
| --- | ---: | --- |
| `docs/migration/add-opens-exceptions.md` | 33 | This page: the eight directives, the runtime exception, the certification commands and the retirement path |
| `pom.xml` | **10** | **The only configuration that grants access** — eight directives in the surefire `argLine`, two of them repeated in failsafe's |
| `docs/migration/smoke-evidence.md` | 3 | The two-run launch-configuration measurement |
| `docs/migration/dependency-change-inventory.md` | 3 | The refused `--add-exports` alternative for Spring LDAP |
| `docs/migration/behavioral-decisions.md` | 6 | The R-7 resolutions that chose a directive over a behaviour change, the refused production `add-exports`, and the measured runtime exception |
| `docs/migration/known-issues.md`, `docs/setup.md`, `README.md` | 1 each | Operator guidance and one register entry |

The `-- '*.xml'` filter is what makes the search answer the question R-2 actually asks — *does any configuration grant this access?* — rather than the question of which pages talk about it.

!!! note "What the searches above do and do not prove"

    They prove that **no file in this repository grants module access outside the two test-runner `argLine`s** — not the documented `JAVA_OPTS` blocks, not the CI files, not a script. They do **not** prove that the running application needs no such access, because the servlet container supplies some of its own. That is a separate question, it was measured, and the measurement does not reconcile with R-2: it is recorded as an open item in [an unreconciled runtime observation](#an-unreconciled-runtime-observation-not-a-production-grant) below rather than resolved on this page.

## An unreconciled runtime observation, not a production grant

R-2 permits no module-access flag in production launch configuration unless a pinned dependency documentedly requires one, and ArkCase's published launch configuration grants none. A measurement taken during this migration sits uneasily beside that, and it is recorded here as an **open item for the plan owner** rather than turned into operational guidance: on Java 17 the root Spring context does not initialise unless `java.base/java.lang` is open, and on a stock Tomcat 9 it is open because **the container's own launcher opens it**, not because ArkCase asks for anything.

Nothing in this repository was changed on the strength of this measurement, no flag was added anywhere, and neither the README nor the developer setup guide tells an operator to add one. What follows is what was observed, stated so it can be re-checked.

This was established by deploying the migrated WAR twice to the same Tomcat 9.0.120 instance and changing nothing but the launcher:

| Run | Module-access flags reaching the JVM | Outcome |
| --- | --- | --- |
| Stock `catalina.sh` (Tomcat 9.0.120) | The **seven** `--add-opens` that Tomcat's own launcher exports through the `JDK_JAVA_OPTIONS` environment variable on Java 9 and later, at lines 334-340 under its comment *"Add the JAVA 9 specific start-up parameters required by Tomcat"* — `java.base/java.lang`, `java.lang.invoke`, `java.lang.reflect`, `java.io`, `java.util`, `java.util.concurrent`, and `java.rmi/sun.rmi.transport` | Root context initialises. `Deployment of web application archive [.../arkcase.war] has finished in [279,807] ms`, `Server startup in [279939] milliseconds`, zero `InaccessibleObjectException`; `POST /arkcase/login_post` answers 302 to `home.html#!/welcome`, `home.html` 200 and `GET /api/v1/users/info` 200 with the authenticated identity payload |
| Tomcat's own `org.apache.catalina.startup.Bootstrap` command line replayed verbatim with `unset JDK_JAVA_OPTIONS` — same `CATALINA_HOME`, same `CATALINA_BASE`, same `setenv.sh`, same WAR | **none** — verified from `/proc/<pid>/environ` and the process argument list: no `--add-opens`, no `--add-exports`, no `--illegal-access` | **Root context fails.** Three `InaccessibleObjectException` of two distinct kinds; `SEVERE One or more listeners failed to start`, `Context [/arkcase] startup failed due to previous errors`; `login`, `home.html`, `login_post` and the REST API all answer 404 |

Because Tomcat passes those seven through the environment rather than on the command line, a `ps` inspection of a healthy instance shows **no** module-access flag — which is why this measurement reads `/proc/<pid>/environ` as well. Do not conclude from a process listing that the JVM is flag-free.

The two demands, each traced to the frame that raised it:

| Option | Demanded by | The exact frame |
| --- | --- | --- |
| `--add-opens java.base/java.lang` | **Drools 7.34.0.Final** — pinned by `<drools.version>` in the root POM, and on the mandatory startup path because the application compiles its business rules during context initialisation | `org.drools.core.rule.builder.dialect.asm.ClassGenerator.<clinit>` (`ClassGenerator.java:71`) calls `setAccessible` on `java.lang.ClassLoader.defineClass`, reached through `InvokerGenerator.createStubGenerator:49` ← `ASMEvalStubBuilder.createEvalBytecode:39` ← `AbstractASMEvalBuilder.buildEval:99` ← `RuleBuilder.build:107`. Without the open: `InaccessibleObjectException: Unable to make protected final java.lang.Class java.lang.ClassLoader.defineClass(java.lang.String,byte[],int,int) throws java.lang.ClassFormatError accessible: module java.base does not "opens java.lang"` |
| `--add-opens java.base/java.lang` (same option, second demander) | **Groovy 1.8.6** — `groovy-all-1.8.6.jar`, declared at compile scope in `acm-services/acm-service-search/pom.xml` since before this migration with the comment *"this entry is needed for IDEA v12"*, and reached by the **AWS SDK for Java 1.11.775** | `org.codehaus.groovy.reflection.CachedClass$3$1.run` (`CachedClass.java:86`) calls `setAccessible` on `java.lang.Object.finalize()`, reached through `MetaClassRegistryImpl.<init>` ← `GroovySystem.<clinit>` ← `Class.forName` in `com.amazonaws.util.VersionInfoUtils.groovyVersion:208`, which the SDK calls only to compose its user-agent string, on the path `EC2ResourceFetcher.<clinit>` ← `InstanceProfileCredentialsProvider.<init>` ← `AWSComprehendMedicalCredentialsProviderChain.<init>:46` ← `AWSComprehendMedicalServiceImpl.init:75`. Without the open: `InaccessibleObjectException: Unable to make protected void java.lang.Object.finalize() throws java.lang.Throwable accessible: module java.base does not "opens java.lang"` |

Both demanders satisfy R-2's condition literally: each is a pinned third-party dependency, and each demand is reproduced here with the frame that raised it.

**Why neither demand can be retired inside this migration, stated as an argument rather than an assertion.** The two are independent, so removing one does not help. Drools would have to move to a release that no longer reflects into `ClassLoader.defineClass`, and the rules engine is what evaluates ArkCase's data-access and participant business rules, whose permission-evaluation outcomes the migration is required to preserve; it is also not among the compatibility-blocking libraries this migration may move, because nothing about it fails on Java 17 once the container's own open is present. The Groovy demand is the more tempting of the two, because Groovy is reached only by an AWS user-agent probe and sits on the classpath because of a legacy IDE-support declaration — but it is base-commit content that no Java 17 failure implicates, so R-1 and R-6 both put it out of scope, and removing it would not make a flag-free launcher succeed while the Drools demand stands. The measured conclusion is therefore that the exception is irreducible here: retiring it needs a separately authorised change to the rules and scripting stack, carrying rule-evaluation regression coverage of its own.

**Why this is recorded as unreconciled rather than as an exception.** On the supported container the observation is inert: Tomcat 9 exports the open from `bin/catalina.sh` before the JVM starts, so an operator following [the developer setup guide](../setup.md) needs no action and the published `JAVA_OPTS` block correctly adds nothing. What is *not* settled is any launcher that is not Tomcat's — a plain `java -jar` wrapper, a hand-rolled container entrypoint, or a servlet container that does not export it. R-2 governs published launch configuration, and this record will not publish a flag instruction for that case on its own authority.

**What a human must decide.** Either (a) ratify a documented R-2 exception naming `--add-opens=java.base/java.lang=ALL-UNNAMED`, its two demanders and the launcher scope it applies to, at which point this section becomes that exception and the operator-facing documents can carry it; or (b) restate the supported deployment target as Tomcat 9 only, so that no non-Tomcat launcher is in scope and no exception is needed. Until one of those happens the position published in `README.md` and [the developer setup guide](../setup.md) stands unchanged: **grant nothing**. The other six opens Tomcat sets are the container's own business and ArkCase does not depend on them being present.

**One production flag was refused rather than accepted.** Spring LDAP 2.3.3 could have been made to work with `--add-exports=java.naming/com.sun.jndi.ldap=ALL-UNNAMED`, because its `AbstractContextSource` holds a class literal on the encapsulated JDK LDAP context factory. R-2 requires an upgrade wherever an upgrade suffices, so the dependency moved to 2.3.4.RELEASE — which resolves that factory by name — and the flag was not added. The reproduction and version measurement are in [the dependency inventory](dependency-change-inventory.md), and the same substitution inside ArkCase's own context source is in [the static audit](static-audit.md).

## The eight test-scope directives

Each row names the option, the library that demanded it and the frame that failed without it. The PowerMock rows are deliberately **not** merged, because the per-frame attribution is the substance of what R-2 asks for — five directives that all trace to one method are five separate observations, not one.

| Directive | Demanded by | The exact frame that failed |
| --- | --- | --- |
| `--add-opens java.base/java.time` | Jackson databind 2.10.3 (version-managed) | `InaccessibleObjectException: Unable to make field private final int java.time.LocalDate.year accessible` from `ClassUtil.checkAndFixAccess` via `FieldProperty.fixAccess`, in `GetConsultationAPIControllerTest` at lines 161, 201 and 238, each a bare `new ObjectMapper().readValue(json, Consultation.class)` over a model carrying `LocalDate responseDueDate` |
| `--add-opens java.base/java.lang` | CGLIB inside EasyMock's proxy factory | `ClassLoader.defineClass` via `ClassProxyFactory`, with six cascading `NoClassDefFoundError` on its inner class |
| `--add-opens java.base/java.io` | PowerMock 2.0.9 (no successor exists) | `WhiteboxImpl.doGetAllMethods:1508`, calling `setAccessible` on `java.io.File.readObject` |
| `--add-opens java.base/java.nio.file` | PowerMock 2.0.9 | the same frame, on `java.nio.file.Files.provider` |
| `--add-opens java.base/java.util` | PowerMock 2.0.9 | the same frame, on `java.util.HashMap.hash` |
| `--add-opens java.base/java.math` | PowerMock 2.0.9 | the same frame, on `java.math.BigDecimal.add` |
| `--add-opens java.base/java.util.stream` | PowerMock 2.0.9 | the same frame, on the int-stream head's iterator |
| `--add-exports java.xml/jdk.xml.internal` | PowerMock's `MockClassLoader` | `FactoryFinder.<clinit>:69` reached from `DocumentBuilderFactory.newInstance:172` while log4j-core parsed its XML configuration |

**Scope:** the forked JVM of `maven-surefire-plugin` for all eight; the forked JVM of `maven-failsafe-plugin` for the first two only. Production scope: **none**, for all eight, without exception. Each directive is written with an `=ALL-UNNAMED` target in the POM, which is the narrowest form available for code that runs on the classpath — the test classes are in the unnamed module, so nothing wider would be reached and nothing narrower can be expressed.

**Seven** of the eight are `--add-opens` on packages `java.base` already exports, which is the ordinary JEP 396 consequence: the package compiles against freely and can be reflected into deeply only with permission. The eighth is an `--add-exports`, a different mechanism answering a different problem, and it is worth its own explanation.

### Why the failsafe grant is narrower than the surefire grant

Surefire receives all eight directives. Failsafe receives **two**:

```xml
<argLine>@{argLine}
    --add-opens java.base/java.time=ALL-UNNAMED
    --add-opens java.base/java.lang=ALL-UNNAMED</argLine>
```

R-2 asks for each exception to be *documented*, and an exception documented only as "the same as the other runner" is not documented — it is copied. Applying the rule properly means asking, per runner, which directive an executable test in that runner actually demands:

| Directive | Does an executable integration test demand it? | Granted to failsafe |
| --- | --- | --- |
| `java.base/java.time` | **Yes.** Jackson databind reflects into `java.time` fields through any bare `ObjectMapper`, which the Spring-context integration tests reach | yes |
| `java.base/java.lang` | **Yes.** CGLIB, through both EasyMock's `ClassProxyFactory` and the Spring proxying that every `@ContextConfiguration` integration test performs | yes |
| `java.base/java.io`, `java.nio.file`, `java.util`, `java.math`, `java.util.stream` | **No.** All five trace to `WhiteboxImpl.doGetAllMethods` calling `setAccessible`, which is PowerMock. The reactor's only PowerMock integration test, `CategoryServiceIT`, is `@Ignore`d | no |
| `java.xml/jdk.xml.internal` | **No.** It traces to PowerMock's `MockClassLoader` reloading `javax.*` into an unnamed module — again reachable only through the one disabled class | no |

The two granted directives are not asserted, they were exercised. Running the failsafe lane under exactly this narrowed `argLine`:

| Probe | Result |
| --- | --- |
| `PropertyFileManagerIT` in `acm-tool-integrations/acm-files-property-file-manager` | **3 tests, 0 failures** |
| `SpringContextHolderIT` in `acm-tool-integrations/acm-spring-context-holder` | **3 tests, 0 failures**, with a full Spring context |
| `AcmEncryptablePropertyUtilsImplIT` in `acm-tool-integrations/acm-encryption` | **2 tests, 0 failures**, exercising real key material |
| `@{argLine}` composition | the JaCoCo agent argument and the two directives composed correctly in the failsafe fork, exactly as they do for surefire |

Those three classes are the **entire hermetic subset** of the 86 integration-test classes — the only ones that need no external service — so this is not a sample of the lane, it is all of the lane that can run here. One command covers them: `mvn -o -B -pl acm-tool-integrations/acm-files-property-file-manager,acm-tool-integrations/acm-encryption,acm-tool-integrations/acm-spring-context-holder verify`, which exits 0 with **8 integration tests green** and the `jacoco:check` goal of `verify` passing alongside them. No `InaccessibleObjectException` and no `IllegalAccessError` appeared in any probe, or anywhere in the unit suite.

!!! warning "Restore condition — this narrowing has a maintenance obligation"

    If `CategoryServiceIT` is ever re-enabled, or any new `*IT` class starts using PowerMock, the six PowerMock directives must be copied across from the surefire `argLine` to the failsafe one. The root `pom.xml` carries this instruction at the failsafe `argLine` itself, so it is not discoverable only from this page.

### Why the XML export is the least obvious of the eight

`--add-exports java.xml/jdk.xml.internal` looks out of place next to seven `java.base` opens, and the reason it is needed is a module-identity mismatch rather than a permissions problem.

PowerMock works by reloading classes through its own `MockClassLoader` so it can rewrite them. Classes reloaded that way land in the **unnamed module**, because a custom class loader has no named module to put them in. That is deliberate on PowerMock's part and is the mechanism the whole library depends on.

The package on the other side of the failure is not exported at all. `java --describe-module java.xml` on JDK 17.0.20 lists it as `contains jdk.xml.internal`, with no `exports` line — qualified or otherwise:

```bash
java --describe-module java.xml | grep jdk.xml.internal
# contains jdk.xml.internal
```

`jdk.xml.internal` is therefore reachable only from **inside** `java.xml`, which is exactly how the JDK's own JAXP code uses it: `FactoryFinder`, reached from `DocumentBuilderFactory.newInstance`, is itself a `java.xml` class, so its access to that package is same-module access and needs no export. The failure appears only because PowerMock **reloads `FactoryFinder` into the unnamed module**. The reloaded copy is no longer part of `java.xml`, so its reference to a package that `java.xml` does not export cannot be satisfied, and the class initialiser fails.

That is the entire mismatch, and it is worth naming precisely: it is not PowerMock reflecting where it should not, and it is not the JDK denying an unreasonable request. It is a class that lost its module identity by being reloaded. `--add-exports java.xml/jdk.xml.internal=ALL-UNNAMED` restores exactly the access the original class had, to the unnamed module and nothing else.

## Where the directives live, and why they compose rather than collide

The directive text occupies **two `argLine` blocks in the root `pom.xml` and nowhere else** — eight directives in one and two in the other, ten lines in total. The surefire block, at the `maven-surefire-plugin` declaration pinned to **3.5.3** through the new `surefire.version` property:

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

The first copy configures the new `maven-surefire-plugin` declaration, pinned at **3.5.3** through the new `surefire.version` property; the second configures `maven-failsafe-plugin`, which stays at the base commit's **2.17**, held in the `failsafe.version` property so the two `coreBuild` profiles that also declare failsafe consume the same value. A `<argLine>` element exists in no other POM in the repository — the directive text occupies exactly two blocks in exactly one file, which is what makes the certification above a bounded search rather than an open-ended one.

One clarification, because this page must not lend the failsafe configuration a reason it does not have: **failsafe 2.17 was never a blocker, so it was not moved.** Probed directly on a real reactor integration test on JDK 17 with Maven 3.8.7, failsafe 2.17 loads, expands `@{argLine}` — the forked command line carries the JaCoCo agent argument in full and no literal `@{argLine}` — and passes both module-access directives through to the fork. Since no failure is attributable to it, R-1 forbids the version change, and it was reverted to 2.17 after having briefly been aligned to the surefire pin. Only the **surefire** side of this configuration answers a reproduced failure. [The dependency inventory](dependency-change-inventory.md) carries the probe.

"One pin for both forked runners, in every module" is a claim about the whole reactor, so it is worth stating how it is held. It was briefly false in both directions at once: the root declaration had been aligned to `${surefire.version}`, while two profile-local declarations — in `acm-standard-applications/acm-foia/pom.xml` and `acm-standard-applications/acm-privacy/pom.xml` — hardcoded `2.17` inside a `coreBuild` profile and won over the inherited version wherever that profile activated, which would have discarded this `argLine` exactly where integration tests run. Both halves are now held from one place: the root POM declares `<failsafe.version>2.17</failsafe.version>` beside the surefire pin, and every failsafe declaration in the repository — the root's and both profile-local ones — consumes it, so no module can diverge and no version moved. The reproducible checks are `grep -rn "<version>2.17</version>" --include=pom.xml .` (no matches, because no declaration hardcodes a version any more) and, under `-DcoreBuild=true`, `help:effective-pom` reporting failsafe **2.17** in both plugin blocks of those modules.

The leading `@{argLine}` is not decoration and the configuration does not work without it. JaCoCo's `prepare-agent` goal builds the Java agent argument and publishes it as a property; surefire's **late substitution** of `@{…}` expands that property when the fork is launched, so the agent argument and the module-access directives **compose** into one command line. Written as `${argLine}`, or with the directives assigned directly, one would overwrite the other: either coverage instrumentation disappears — silently, taking the `check` goal's line-coverage floor with it — or the directives do. Late substitution is what lets a documented R-2 exception coexist with coverage enforcement instead of trading against it, and it is the mechanism that makes R-2 mechanically enforceable at test time rather than aspirational.

This is also the reason surefire had to be declared at all. Before the migration **no POM in the repository declared it**, so the reactor silently inherited Maven's 2.12.4 default, which performs no late `@{…}` substitution. Under 2.12.4 the fork dies immediately:

```text
Error: could not open '{argLine}'
The forked VM terminated without saying properly goodbye
```

Under 3.5.3 the identical configuration passes. Stated precisely, so this page is not read as an indictment of the older runner: 2.12.4 is **not** globally broken on JDK 17 — a plain JUnit 4 test runs fine under it — and the recorded reason for the pin is the specific late-substitution capability needed to combine coverage enforcement with a documented module-access exception. The full plugin reasoning belongs to [the dependency inventory](dependency-change-inventory.md).

## Why this is a bounded result and not an open-ended concession

A documented exception differs from a blanket waiver in that its limits can be shown. Four arguments, each with the observation behind it.

**The set converged.** The directives were added one at a time, each in response to a stack trace that named it, and the last two were added together to clear the XML failure. After them, both previously-failing AWS SDK tests went **fully green** — 6 tests and 8 tests, no failures, no errors, no skips — and **no new access failure appeared anywhere in the reactor**, across all 142 modules and the 76 of them that carry test sources. Nothing was added speculatively and nothing was added to silence a warning; a ninth directive was never needed because no ninth frame ever failed.

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

And that last row is load-bearing for the failsafe grant, because `CategoryServiceIT` is **`@Ignore`d at the base commit** and remains so: the entire class is skipped. So the reactor contains **no executable integration test that uses PowerMock at all**, which is why the six PowerMock directives are granted to surefire and withheld from failsafe.

The honest counterpart, which a reader would otherwise infer wrongly from the paragraph above: the `java.lang` directive is **not** narrowly held. 211 test sources use EasyMock, so CGLIB's reflective `defineClass` is on the path of a large fraction of the suite. The bounded-exposure argument applies to the six PowerMock directives and not to that one, which is exactly why the retirement path below cannot reach it.

**The one behaviour-changing alternative was rejected on rule grounds, not convenience.** The `java.time` directive has an obvious alternative — register a Java-time module on the mappers that reflect into `java.time`, and the reflection stops. It was rejected because it would change what ArkCase emits.

The evidence is in the codebase rather than in an argument. `ObjectConverter` in `acm-tool-integrations/acm-object-converter` **does** register a `JavaTimeModule`, disables `WRITE_DATES_AS_TIMESTAMPS` and installs a `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` formatter — so where ISO-8601 strings are the intended contract, ArkCase says so explicitly. The consultation controller test deliberately does not: it deserialises a controller response with a bare `new ObjectMapper()`, which is why Jackson reflects over the fields of the model's `LocalDate` and why the directive is needed. Registering a module there would turn a field-based JSON object into an ISO-8601 string: a change to an accepted and emitted payload shape, which the REST-contract preservation mandate forbids and which **R-7** independently settles against, since the field-based shape is the observed behaviour of the Java 8 base commit.

**The attribution is proven by removal, not inferred.** Deleting the single `java.time` line from the surefire `argLine` and re-running `acm-plugins/acm-default-plugins/acm-consultation-plugin` produces `Tests run: 30, Failures: 0, Errors: 3` and `BUILD FAILURE`, with all three errors reading `InaccessibleObjectException: Unable to make field private final int java.time.LocalDate.year accessible: module java.base does not "opens java.time" to unnamed module`. Restoring the line returns the same module to `Tests run: 30, Failures: 0, Errors: 0` and `BUILD SUCCESS`. The directive is therefore demanded by a test that exists in the final suite, and its removal is not available as a simplification.

### The production counterpart of this directive, closed in code rather than by a flag

The same Jackson-over-`java.time` reflection is reachable in **production**, not only in tests: `FOIAPortalRequestServiceProvider.submitRequest` and `SARPortalRequestServiceProvider.submitRequest` read the portal payload with a bare `new ObjectMapper()`, and the models behind them carry `java.time` properties — `PortalFOIARequest.recordSearchDateFrom` and `recordSearchDateTo`, `PortalSubjectAccessRequest.signatureDate`, and `PortalPersonDTO.dateOfBirth` reached twice through the subject and the requester. On Java 17 the SAR path failed for **every** payload, including payloads carrying no date at all, because the refusal happens while the deserialiser is being built; the exception is unchecked, so it escaped the provider's `catch (IOException)` and surfaced as a bare server error on `POST /api/v1|latest/service/portalgateway/{portalId}/requests`.

That path was closed **in application code, with no production flag**, and this is the reason the certification above remains true rather than merely unexamined. Each provider now builds its mapper through a private `portalRequestMapper()` that registers a module refusing `java.time` values outright instead of binding them reflectively. The measured result on JDK 17.0.20, driven through the real providers with the create service replaced by a recording subclass:

| Payload | Java 8 base commit | Java 17 before | Java 17 after |
| --- | --- | --- | --- |
| No date, or explicit `null` dates | Accepted, field `null` | **Uncaught `InaccessibleObjectException`** (SAR) | Accepted, field `null` |
| Any date value (ISO string, field object, epoch number) | `InvalidDefinitionException` → `PortalRequestServiceException` | **Uncaught `InaccessibleObjectException`** (SAR) | `InvalidDefinitionException` → `PortalRequestServiceException` |

Two alternatives were rejected on evidence rather than taste. Opening `java.base/java.time` in `JAVA_OPTS` would have worked and is exactly what R-2 forbids. Disabling Jackson's `CAN_OVERRIDE_ACCESS_MODIFIERS` on those two mappers — a one-line change — was probed against the real model classes and **does not fix it**: the SAR path still throws `InaccessibleObjectException` on JDK 17. The full reasoning, including why the accepted request shape was deliberately not widened to ISO-8601 strings, is in [the behavioural decisions record](behavioral-decisions.md).

One precision that keeps the test-scope argument honest: the deserialisation the `java.time` directive covers in the suite is asserted on, so its removal really does turn the suite red, as the removal experiment above shows. The general register of such resolutions is [the behavioural decisions record](behavioral-decisions.md).

## How the directives satisfy R-5 rather than dodge it

Two tests failed on JDK 17 when the migration was first applied: `AWSTranscribeServiceTest` and `AWSComprehendMedicalServiceTest`. Both **pass on Java 8** — 6 run and 8 run, no failures, no errors — so they were **migration regressions, not baseline failures**, and R-5 did not permit excluding them. Excluding them would have been the cheap route and the rule closes it.

They were fixed instead, by adding the directives their own stack traces named, and both then went fully green on JDK 17 with their assertions untouched. That is what the PowerMock-attributable directives are: the R-5-compliant remedy for a regression, not a convenience for a runner that would not start. The distinction matters because it decides the disposition — a JDK 17 failure that also fails on Java 8 may be excluded and recorded, and a JDK 17 failure that passes on Java 8 must be fixed. The measured Java 8 baseline, the four failures that *are* excludable, the two class-level exclusions that cover them and the collateral cost of those exclusions all belong to [the baseline record](baseline-test-failures.md), which owns the suite totals this page does not restate.

## The documented retirement path, deliberately not adopted

There is a way to reduce the eight test-scope directives to two, it was identified during the migration, and it was declined. It does not touch the unreconciled runtime observation above, which arises in the rules engine rather than in any test. Recording both halves of that is the point of this section.

**The path.** Migrating the five PowerMock unit-test classes to Mockito's inline static mocking would remove the five reflection-driven `java.base` opens *and* the `java.xml` export — PowerMock's `MockClassLoader` is what creates the unnamed-module mismatch, so removing PowerMock removes the mismatch with it. Six of the eight would go. The two that would remain are `java.time` and `java.lang`, because neither is PowerMock's: one is Jackson reflecting into a JDK package and the other is CGLIB inside EasyMock, used by 211 test sources.

One detail that a partial attempt would trip over: those six sit in the **surefire** `argLine` only, so retiring them is a surefire-side edit and the failsafe `argLine` is unaffected. But `CategoryServiceIT` uses PowerMock too, and the restore condition recorded at the failsafe `argLine` would then still be live — so leaving that class behind would leave a PowerMock integration test whose directives are neither granted nor retired. Doing the job properly is a six-class migration, not a five-class one.

**Why it was declined here.** It means adding a new mocking artefact to the dependency surface and rewriting five working test classes. Mockito is already present as `mockito-core` 3.7.7, but inline static mocking is not: it needs `mockito-inline`, which appears in no POM in this repository. A dependency addition without a reproduced failure behind it is precisely what **R-1** forbids, and rewriting passing tests runs against the mandate to preserve existing test assertions — the migration modified **zero** of the base commit's 402 test sources, and this would have modified five of them for a tidier flag list rather than for a failure. It belongs in [the behavioural decisions record](behavioral-decisions.md) as the recommended follow-up, to be taken when test maintenance is the goal rather than as a side effect of a runtime migration.

**The narrower alternative, also declined.** Both AWS SDK tests already carry `@PowerMockIgnore({ "javax.management.*", "javax.net.ssl.*" })`, and that list demonstrably does not cover the XML packages. Widening the annotation would keep the JAXP factory finder out of PowerMock's class loader and fix the XML case with no JVM flag at all — a genuinely smaller change to the command line. It was not taken because it edits test source, and the JVM directive edits none: preserving all 402 pre-existing test sources byte-identical is itself a preservation mandate, and one flag in a build file that is documented here is a better trade than an annotation change in two test classes that is not. The alternative is recorded because it exists, not because it was unattractive.

## The published launch configuration was exercised, not only searched

Everything above certifies the *absence* of production flags in the tree by searching it. That is necessary but not sufficient, so the published configuration was also run. Stated precisely, because the two sections must not be read as contradicting each other: what was exercised is `JAVA_OPTS` **as published**, on the **supported container**, and Tomcat's own launcher opened `java.base/java.lang` underneath it — which is exactly the observation held open above. This section is therefore evidence that the published block needs no addition on Tomcat 9; it is not evidence that the application needs no such access at all.

The migrated WAR was deployed to Tomcat 9.0.120 on JDK 17 with a `JAVA_OPTS` containing **no `add-opens`, no `add-exports` and no `illegal-access`** — only the IPv4 preference, the timezone, the keystore and trust-store settings, the active Spring profile, the configuration-server property file and the heap sizes. Measured on that instance:

| Check | Result |
| --- | --- |
| Root application context refresh | completes; `Server startup in [279939] milliseconds` |
| `SEVERE` entries after the newest context initialisation | **0** |
| `IllegalAccessError` / `InaccessibleObjectException` anywhere in the startup | **0** |
| `NoClassDefFoundError` / `ClassNotFoundException` | **0** |
| Authentication | `POST /arkcase/login_post` → **302** to `home.html#!/welcome`; `/api/v1/users/info` → **200** |

The result separates the two `java.base` directives cleanly, which is why the test-scope confinement holds for one of them outright:

- **`java.time` was open to nobody in this run** — neither `JAVA_OPTS` nor Tomcat's launcher supplies it — and the application started and served an authenticated request regardless. Nothing in the *application* needs it; only tests that deserialise a `java.time` field with a bare `ObjectMapper` do, and the two production paths that would have needed it were closed in code instead.
- **`java.lang` was open, supplied by the container**, so this run says nothing about whether the application could start without it. The neutralised-launcher run above says it could not. That is the open item, not a settled exception.

The CGLIB asymmetry is worth naming separately: Spring's AOP proxies are visible throughout the startup log, and Spring 5.3.39's CGLIB defines proxies through a supported mechanism, so the runtime proxying does not itself demand the grant that EasyMock's `ClassProxyFactory` needs in tests.

**One honest caveat about how this was reached.** The first deployment attempt did fail, and it is worth recording because the error looks like a missing flag and is not one: the launch script was still pinned to Java 8 from the baseline capture, so the JVM rejected the migrated bytecode with `UnsupportedClassVersionError … class file version 61.0`. The remedy was to point `JAVA_HOME` at JDK 17 — **not** to add a flag. Two genuine Java 17 defects were then found and fixed at their root cause in dependency versions rather than papered over with module-access grants; both are attributed in [the dependency change inventory](dependency-change-inventory.md), and the spring-ldap one is directly relevant here, because granting `java.naming/com.sun.jndi.ldap` in production would have been the lazy alternative to taking the upstream patch. R-2 is the reason it was not.

## What this means for deployment

For anyone deploying ArkCase on Java 17, the operative statement is short:

- **Add nothing.** The `JAVA_OPTS` block published in the README and in the developer setup guide runs as written on Java 17 and grants no module access. Do not add `--add-opens`, `--add-exports` or `--illegal-access`, and do not add the six other opens Tomcat sets — they belong to the container, not to ArkCase.
- **Deploy on Tomcat 9, the supported container.** A launcher that is not Tomcat's is not covered by a published exception, because there is none: the measurement bearing on that case, and the decision it is waiting on, are in [an unreconciled runtime observation](#an-unreconciled-runtime-observation-not-a-production-grant). Escalate rather than improvise a flag.
- **The eight test directives are a build-time concern only.** They exist in the surefire and failsafe configurations, they apply to forked test JVMs, and they never reach a deployed process. Copying them into a server's launch configuration would widen access for no benefit and would put the deployment outside what R-2 permits.
- **The artefact is unchanged.** The build still assembles `acm-standard-applications/arkcase/target/arkcase-2021.03.war` at the same coordinates and the same path; nothing about deployment mechanics moves with this migration.

One adjacent Java 17 finding is worth knowing so it is not mistaken for a missing flag. **ActiveMQ's TLS transport does not work on Java 17**, so on this stack the broker is addressed over `tcp://` rather than `ssl://`. It is documented and deliberately **not fixed**, on direction, and it is not a module-access problem — no `--add-opens` would help and none is offered. It is also not a repository change: no broker URL exists anywhere in this repository, since endpoints come from the external configuration bundle, so the finding lives in [the known-issues record](known-issues.md) and the remedy is a configuration choice made outside this tree.

That workaround is **not** a licence to run an unprotected broker, and this page will not read as one. `tcp://` carries JMS credentials and message payloads in clear text, so a deployment that uses it must compensate at other layers:

- **Confine the broker to a trusted network.** Bind it to a private interface or loopback, keep it off any routable or shared segment, and restrict `61616` (and the console port) to the application hosts with host and network firewall rules or security groups.
- **Keep authentication and authorization on.** Plaintext transport does not imply an open broker: keep the broker's authentication plugin enabled with per-application credentials, and keep destination-level authorization so a compromised client cannot read queues that are not its own.
- **Encrypt at another layer where the segment is not trustworthy.** A TLS-terminating proxy, an SSH tunnel, a VPN or a service-mesh mTLS sidecar all move the ciphertext boundary off the JVM that cannot negotiate it, and none of them requires the broker's own TLS transport.
- **Treat it as time-limited.** Record it as an accepted risk with an owner, and revisit when the broker version that fixes TLS on Java 17 can be adopted; the pin is what forces the workaround, so lifting the pin is what retires it.

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
