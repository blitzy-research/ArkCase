# Smoke Evidence

This page records the validation capture for both tracks of the Java 17 and Node 20 migration: what was executed, what it produced, and precisely which items the reduced local stack prevented from being executed at all. It is one of the four artifacts the migration's Deliver list names explicitly. Three of the five validation gates pass on measured evidence; **two are constrained rather than passing**, and the whole value of this page rests on saying so in plain language before making the strongest honest argument available for them.

## Where the rules come from

A note on provenance, because it is not discoverable from the repository. `review_rules` returns **no user rules provided**; there is no on-disk rules document for this project. The seven binding rules arrive instead through the user prompt's own RULES block, and their full verbatim text is available from the `review_prompt` tool. This page cites them by the stable identifiers **R-1** through **R-7** and deliberately does not reproduce their text — `review_prompt` is the source of record for that.

Four of the seven govern this page:

| Rule | Scope | What it requires of this page |
| --- | --- | --- |
| **R-7** | All behavioural decisions | **Primary for this page's method.** The capture is taken against the baseline build first and then replayed against the migrated build, and the page must state which flows that was actually possible for rather than implying it was possible for all of them. R-7 is also why the frontend fidelity argument takes the shape it does. |
| **R-4** | Frontend toolchain | The page must supply the **proof**, not the assertion, that the frontend genuinely runs on Node 20: exact runtime versions, exact commands, exit codes, the package count, the elapsed time and the emitted artifact set. R-4 is satisfied by evidence, and this is where that evidence lives. |
| **R-6** | All source | The residual warnings observed during these runs are **expected output, not failures**, and nothing is fixed to silence them. They are recorded here so a future reader does not mistake them for regressions. |
| **R-1** | All manifests and POMs | The contract-preservation argument for the three unreachable services rests entirely on every client library **version** being unchanged. That is a claim about the dependency set, so the versions are named and the reasoning is deferred to the inventory rather than restated. |

**R-3** is not a governing rule for this page, but this page carries its executable proof — see [The compiler contract, proven by what is absent](#the-compiler-contract-proven-by-what-is-absent). **R-7** owns a general register of its own, [the behavioral decisions record](behavioral-decisions.md); this page owns only the observations the capture itself produced.

## How this capture was taken

Every figure below was read from a command's own output on a real toolchain. Nothing is estimated, and no log line is paraphrased into something the tool did not print.

| Runtime | Version | Role |
| --- | --- | --- |
| JDK | **17.0.20** (Eclipse Temurin) | The target runtime for the Track A capture |
| JDK | **1.8.0_502** | The Java 8 baseline runtime |
| Maven | **3.8.7** | Used on both sides, so the build tool is not a variable |
| Node.js | **v20.20.2** | The target runtime for the Track B capture |
| npm | **10.8.2** | Ships with Node 20; the lockfile is authored and validated by it |

!!! note "Two JDK patch pairs appear across this documentation set, and neither result depends on the patch level"
    An earlier capture taken while the migration was being designed used **JDK 17.0.19** and **JDK 1.8.0_492** and reached the same conclusions. Both pairs are therefore legitimate, and [the dependency inventory](dependency-change-inventory.md) records the same fact. Where a figure below was reproduced on the committed tree, the runtime that reproduced it is the 17.0.20 pair.

**Method, as R-7 requires it.** The Java 8 baseline was captured first, from an extracted pristine copy of the base commit `c8f6226105`, and the migrated capture was then replayed against the same checks. That ordering is what makes "matches baseline" a measurement rather than an assumption, and it is what allowed two JDK 17 test failures to be identified as migration regressions and fixed rather than excluded — see [the baseline record](baseline-test-failures.md). The ordering was honoured for **every flow the reduced stack can execute**; the flows it cannot execute are enumerated in [Deployment and smoke validation under the reduced local stack](#deployment-and-smoke-validation-under-the-reduced-local-stack) and are recorded there as constrained, not as passes.

**One disclosure about sources.** `web_search` returns no results in this environment, and fetches of vendor documentation return empty bodies. This was re-confirmed while writing this page. **No claim anywhere in this document rests on a search result.** Every figure comes from first-party registry metadata, inspection of published artifacts, or executable probes on the real toolchains above.

**Provenance of the figures, so the two kinds are not confused.** Some were reproduced directly on the committed tree while this page was written — the reactor size, the release-17 compiler line, the static-audit result, the frontend install and build with their full artifact set, and the zero-byte `Gruntfile.js` diff. Others are owned and measured by a sibling record and are restated here only far enough to make this page self-consistent: the suite totals belong to [the baseline record](baseline-test-failures.md), and the WAR's byte count to [the known-issues register](known-issues.md). Where a figure is a restatement, the owning record is named at the point of use.

## The five validation gates

| # | Gate | Command | Result |
| --- | --- | --- | --- |
| 1 | Backend builds and tests on JDK 17 | `mvn -B clean install -DskipTests` then `mvn -B test` | **PASS.** Install: exit 0, BUILD SUCCESS across the full **142-module** reactor. Test: exit 0, BUILD SUCCESS, **918 tests, 0 failures, 0 errors, 21 skipped** — every skip a pre-existing `@Ignore` |
| 2 | Frontend installs and builds on Node 20 from the committed lockfile | `npm ci --ignore-scripts` then `npm run build` | **PASS.** Install: exit 0, **432 packages added and 433 audited**, validated strictly against the committed lockfile. Build: exit 0, full Grunt `default` chain, with an **unmodified `Gruntfile.js`** |
| 3 | Static audit returns zero hits in main source | the extended-regex audit, given in full below | **PASS.** Zero hits in `src/main/java` **and** zero in `src/test/java`, down from **seven hits across five files** |
| 4 | Deployment reaches a ready state with startup logs free of migration-attributable errors | deploy the WAR and poll readiness | **CONSTRAINED** — the artifact is produced with its name and location unchanged, but the reference stack is reduced by the project setup instructions |
| 5 | Smoke flows match baseline | scripted capture against the baseline build, then replayed against the migrated build | **CONSTRAINED** — the login flow is exercisable; the three round-trip items depend on services the setup instructions legitimately skip |

!!! warning "Gates 4 and 5 are constrained, not passing"
    Do not read this page as a green report. The reduced local stack — described in full below — cannot reach Alfresco, Solr or Pentaho, so a live document round-trip, a live search round-trip and a live message transit **were not performed**. What is offered in their place is a contract-preservation argument plus the green unit suite, and that is a weaker form of evidence than an executed round-trip. It is stated as such everywhere it appears, including in the table above.

**The audit command.** It is run from the repository root and the `-E` is not optional, because the alternation is an extended-regex construct:

```bash
grep -rnE "sun\.misc|com\.sun\." --include=*.java
```

The regex contains a literal pipe. Inside a fenced block that needs no escaping; in a Markdown table cell the same character must be written `\|`, which is why this command is given in a block rather than in the results table above. The audit is owned in full by [the static audit](static-audit.md), including the classification of the seven original hits into the four kinds that each needed a different remedy.

**One operational addition, disclosed rather than hidden.** The frontend install must be run with **`--ignore-scripts`**. One git-sourced asset repository declares a `prepare` script that tries to build an ancient native module, and that build cannot compile on Node 20. Passing the flag is the correct semantics rather than a workaround: these are prebuilt asset repositories with checked-in distribution directories, and their prepare steps produce nothing the pipeline consumes. The flag is deliberately **not** set in the repository's `.npmrc`, because setting it there would also suppress the `prebuild` hook of `npm run build` and the generated profiles module would never be written.

## Track A evidence

### The artifact

The WAR is produced at `acm-standard-applications/arkcase/target/arkcase-2021.03.war` — **unchanged in name, coordinates and location** from what [the developer setup guide](../setup.md) describes, and produced by the same `mvn -DskipITs clean install` command that guide has always given. Its measured size is **277,014,616 bytes**, roughly 264 MB, against the Java 8 baseline WAR at **273,020,897 bytes**; the growth of about 4 MB is fully attributable to the reinstated `javax`-namespaced EE artifacts plus the Spring patch bumps.

!!! note "The WAR's exact byte count is not a stable figure, and should not be treated as one"
    Archive timestamps and the licence plugin's year stamp are embedded in the artifact, so the digits move between builds of identical source. The durable claims are the **path**, the **name** and the **magnitude** — all three unchanged. [The known-issues register](known-issues.md) owns this observation, and an earlier build of the same source measured 277,005,095 bytes, which is the same artifact and not a discrepancy in the change set.

### The compiler contract, proven by what is absent

The compiler reports release 17 directly. Reproduced on the committed tree, on JDK 17.0.20:

```text
[INFO] --- maven-compiler-plugin:3.13.0:compile (default-compile) @ acm-object-converter ---
[INFO] Compiling 13 source files with javac [debug deprecation release 17] to target/classes
[INFO] BUILD SUCCESS
```

Two things about those three lines carry more weight than their brevity suggests.

- The `bootstrap class path not set in conjunction with -source 8` warning that the **baseline** JDK 17 run emitted is **gone**. That absence is the executable proof for **R-3**: there is no release-8 escape hatch anywhere in the reactor, because the only compiler configuration in the repository now declares `maven.compiler.release=17` and the `source`/`target`/`compilerVersion` trio has been deleted rather than overridden. A rule of this kind is only enforceable if its violation would be visible, and this is what makes it visible.
- The module chosen is not arbitrary. `acm-tool-integrations/acm-object-converter` is the module that **failed first** on the pristine tree under JDK 17, with `package javax.xml.bind does not exist` across five files. Its clean compile is therefore simultaneously the release-17 proof and the proof that the reinstated EE artifacts reach every module by inheritance, with no module POM edited.

The reactor size was measured the same way rather than assumed: `mvn -o -B validate` on JDK 17.0.20 exits 0 with BUILD SUCCESS and reports exactly **142** modules.

### Test-count reconciliation

The authoritative totals belong to [the baseline record](baseline-test-failures.md), which measures them from surefire's own XML reports rather than from build-log text. They are restated here only far enough to make this page self-consistent:

| Configuration | Tests | Failures | Errors | Skipped |
| --- | --- | --- | --- | --- |
| No exclusions, failure-ignore enabled | 925 | 3 | 1 | 21 |
| Final configured run | **918** | **0** | **0** | 21 |

The difference is **exactly seven**, and it reads correctly from both directions: **925 − 918 = 7**, and **4 baseline failures + 3 incidentally-skipped passing siblings = 7**. Both readings agreeing is the check that the two class-level exclusions are doing precisely what is claimed for them and nothing more.

!!! warning "A zero-skip run is not reachable, and reporting one would be inaccurate"
    The configured run reports **21 skipped** tests. None of them are the seven above — the excluded classes do not run at all, so they are never counted as skipped. All 21 are pre-existing `@Ignore` annotations in unchanged baseline test sources, and removing them is forbidden by **R-5** and by the preserve-assertions mandate. Any statement of this suite as "0 skipped" is wrong; the root `pom.xml` carries the same warning at the exclusion block itself, so that no unsupported count is ever published from that configuration.

Two earlier figures are withdrawn rather than quietly replaced, because a reader who has seen them needs to know which value is authoritative. **893 is withdrawn** as a grep artifact — a count of matching text in build output, never a total any test runner reported. **The interim pair 780 and 773 is superseded** by the measured 925 and 918: it was captured before the change set added five new test classes to cover its own source edits, and before the 21 pre-existing skips were recognised. The invariant it was cited for is untouched and is the part that matters — **780 − 773 = 7**, decomposing as 4 + 3, exactly as 925 − 918 does. Only the absolute totals moved, and they moved because tests were **added**, never because any test was disabled.

### Two blockers that only a full clean build reveals

This is the page where that methodological point belongs, because both were found by running the whole thing rather than by reading it.

1. **The Spring patch bump stops the hand-written event multicaster compiling.** Spring 5.3.5 added two methods to the `ApplicationEventMulticaster` interface that `DistributiveEventMulticaster` implements by hand, so moving to 5.3.39 breaks `acm-web` at compile time. Earlier iterative runs resumed from later modules and never recompiled the owning module, so the failure stayed invisible through several apparently-successful iterations.
2. **The WAR plugin cannot load at all under a JDK-17-capable Maven.** `maven-war-plugin` 3.0.0 fails with an `Unable to load the mojo 'war' … ComponentLookupException` API incompatibility under Maven 3.8.7, and that surfaces only at final assembly — after nearly every module in the reactor has already built successfully, because the module that packages the WAR is one of the last to run.

The lesson is worth stating plainly: **an incremental or resumed build hides both of these.** A migration of this shape cannot be validated by a build that starts from a warm target directory, and neither blocker is discoverable by static analysis of the source at all.

## Track B evidence — artifact equality instead of visual review

### Why artifact equality is the right acceptance test here

There is **no design system to align to**. No component library is named in the requirements and none is present in the repository, the rendered application is AngularJS composed from `ui.bootstrap`, `ui.grid`, `xeditable`, `summernote` and `ngBootbox`, and a new frontend framework, TypeScript adoption and UI redesign are all explicitly excluded. The UI must therefore be preserved unchanged rather than improved, and no Figma frames or design tokens were supplied against which a visual comparison could even be scored.

What replaces visual review is the **emitted artifact set**. The pipeline contract that must not move is:

| Output | Produced by | Contract |
| --- | --- | --- |
| `assets/dist/application.js` | `ngAnnotate` | The annotated application bundle |
| `assets/dist/application.min.js` | `uglify` | Minified with `mangle : false` and `sourceMap : true`, so the map is emitted and **mangling stays disabled** |
| `assets/dist/vendors.min.js` | `concat` | The vendor bundle, concatenated from the vendor asset list |
| `assets/dist/application.min.css` | `cssmin` | The minified stylesheet |
| `home.html` | `renderHome` then `cacheBust` | Rendered from a nunjucks template, then cache-busted across `assets/dist/**` |

The `default` task chain that produces them is preserved verbatim — `loadConfig, clean, ngAnnotate, uglify, concat, cssmin, renderHome, cacheBust, copyToModulesConfigFolder` — and `Gruntfile.js` is **unchanged**. That last claim is measured rather than asserted: the diff of `Gruntfile.js` against the base commit is **0 bytes**.

### The install, measured

Reproduced on the committed tree with Node **v20.20.2** and npm **10.8.2**:

| Step | Command | Exit code | What it reported |
| --- | --- | --- | --- |
| Install | `npm ci --ignore-scripts` | **0** | `added 432 packages, and audited 433 packages`, in 65 s of wall clock on this runner |
| Build | `npm run build` | **0** | The full `default` chain, in 9 s, ending `Done, but with warnings.` |

The package count reconciles exactly against the committed lockfile, which is the check that `npm ci` really did validate strictly against it rather than resolving anything afresh:

- `package-lock.json` is at **lockfileVersion 3** and records **435** package entries.
- **Three** of those are optional and not installable on this platform — `fsevents` twice, both declared `"os": ["darwin"]`, and the optional `nan` that only the darwin `fsevents` needs.
- 435 − 3 = **432 installed**, which is npm's `added` figure, and 432 + the root project = **433 audited**. Both of npm's numbers are therefore fully accounted for.

The runtime is enforced rather than merely documented: `package.json` declares `engines` of `node >=20.19.0 <21` and `npm >=10`, and the repository's `.npmrc` sets `engine-strict=true`, so npm **refuses** an out-of-range runtime and exits non-zero instead of printing an `EBADENGINE` warning and continuing. That is what makes **R-4**'s "genuinely runs on Node 20" enforceable at every install path, including the deploy-time install. The manifest also carries 86 dependencies plus 1 devDependency, down from 108 dependencies at the base commit, and `yarn.lock` is deleted.

!!! note "Install duration is environment-dependent and is not a property of the change set"
    The 65 seconds above is what this runner took with a warmed npm cache; an earlier capture recorded **447 packages in 27 s**. Neither half of that older pair reproduces: the count does not, because the committed lockfile records 435 entries and cannot yield 447, and the timing cannot, because it is a property of the machine and the cache rather than of the change set. The durable, reproducible claims are the **exit code**, the **strict validation against the committed lockfile** and the **package count**, all three of which reconcile against the lockfile as shown above. Do not treat the seconds as a threshold.

Thirty deprecation warnings are printed during install — AngularJS, Bootstrap 3, nunjucks and others. They are informational, they are pre-existing properties of the pinned asset set, and none of them is fixed here: replacing a package to silence a deprecation notice would be a version change with no Node 20 compatibility reason behind it, which **R-1** forbids.

### The build, and the emitted artifact set

The full chain ran in order and each task reported its own work: `clean` cleaned 0 paths on a fresh tree, `ngAnnotate` annotated 1 file, `uglify` created 1 sourcemap and 1 file, `cssmin` reported `504.48 kB → 389.31 kB`, and `cacheBust` busted 1 file. The measured artifact set is:

| Artifact | Measured on the committed tree | Earlier recorded capture | Cache-busted twin |
| --- | --- | --- | --- |
| `assets/dist/application.js` | **4,264,064 B** | 4,264,064 B — identical | yes |
| `assets/dist/application.min.js` | **2,011,925 B** | 2,011,925 B — identical | yes |
| `assets/dist/application.min.js.map` | **1,474,109 B** | not separately recorded | yes |
| `assets/dist/application.min.css` | **389,426 B** | 389,426 B — identical | yes |
| `assets/dist/vendors.min.js` | **3,997,009 B** | 4,096,775 B — differs | yes |
| `home.html` | **126,099 B**, 866 script tags | 125,970 B, 865 script tags — differs | n/a |

Every one of the five files under `assets/dist/` has its cache-busted twin, and the source map is emitted with **mangling still disabled**, exactly as the unchanged `uglify` configuration specifies.

**Why two of those figures moved, stated rather than glossed.** The earlier capture predates the commit that re-pinned several `@bower_components/*` specs to restore base-commit fidelity — among them `ace-builds` from a floating `^1` range to `1.4.12`. The two artifacts that changed are exactly the two assembled from the **vendor asset lists**: `vendors.min.js` is a concatenation of that list, and `home.html`'s script tags are rendered from the same lists. The two artifacts whose bytes the **retained minifiers** produce, `application.min.js` and `application.min.css`, reproduce **digit for digit**. So the movement is attributable to a deliberate fidelity correction in the resolved vendor set, and not to the toolchain move or to either minifier.

### The decisive comparison: the minimal change set against a wider-upgrade variant

A wider-upgrade variant of the frontend change set was also built during the migration, and comparing the two is what settled the design. It cannot be re-measured here, because it is not the committed tree; the figures below are from that recorded comparison run.

| Artifact | Minimal set (adopted) | Wider-upgrade variant | Verdict |
| --- | --- | --- | --- |
| `assets/dist/application.js` | 4,264,064 B | 4,264,064 B | **Identical** |
| `assets/dist/vendors.min.js` | 4,096,775 B | 4,096,775 B | **Identical** |
| `home.html` | 125,970 B, 865 script tags | 125,970 B, 865 script tags | **Identical** |
| `assets/dist/application.min.js` | 2,011,925 B | 1,969,522 B | Differs — the wider variant swaps the JS minifier |
| `assets/dist/application.min.css` | 389,426 B | 396,363 B | Differs — the wider variant swaps the CSS minifier |

The three non-minified outputs are identical across both variants, and the only two that differ are the two a minifier produces. That is the whole argument for the minimal set: keeping `grunt-contrib-uglify` and `grunt-contrib-cssmin` at their original versions means **the shipped minified bytes are produced by the very tooling the Java 8 base commit declared**. Under both the outputs-stay-identical requirement and **R-7**'s base-commit tie-breaker, that is the strongest fidelity claim available — and it is the reason twelve candidate frontend upgrades were formally withdrawn rather than taken. [The dependency inventory](dependency-change-inventory.md) records each withdrawal with the probe result behind it.

!!! warning "The claim is identical tooling, not identical bytes versus Node 8"
    A byte-for-byte comparison against a **Node 8 baseline build was not possible.** The original toolchain cannot install on Node 20 at all — `grunt-sass` 1.0.0 pulls a `node-sass` whose native rebuild fails outright — and no Node 8 runtime was available to produce the other side of the comparison. So the fidelity claim on this page is precisely **identical tooling**: the minifiers that produced the shipped bytes are the versions the base-commit manifest declared. It is **not** a claim that the bytes were diffed against a Node 8 build, and it must not be read as one.

### The fresh-checkout path, and the one expected residual warning

The generated profiles manifest is emitted by the new prebuild helper with **exactly the content the Java assembler writes at deploy time**, so a bare checkout and a deployed WAR follow the same code path. Observed on this run:

```text
> ArkCaseFrontend@0.0.1 prebuild
> node scripts/ensure-profiles.js

ensure-profiles: created <frontend root>/profiles.js with profiles [ custom ].
```

The written file is `module.exports = { profiles: [ 'custom' ] };` — the assembler's own single-profile value, not an invented default.

One residual warning appears at the end of every bare-checkout build and is **expected output**:

```text
Running "copyToModulesConfigFolder" task
Warning: ENOENT: no such file or directory, open 'modules_config/config/modules.json' Used --force, continuing.

Done, but with warnings.
```

The directory it looks for is created at deploy time by the Java assembler, so it is legitimately absent from a bare checkout. The Gruntfile's own `force` option absorbs it and the build still **exits 0**. Under **R-6** it is documented and deliberately **not fixed** — silencing it would be a cosmetic change to a file this migration keeps at a zero-byte diff, and the deliberate contrast between this warning and the one condition that *was* fixed under the carve-out is recorded in [the known-issues register](known-issues.md).

A post-build `git status` shows three untracked, non-ignored generated paths — `assets/dist/`, `home.html` and `profiles.js`. That is pre-existing behaviour of the pipeline for two of the three, it blocks no gate, and it is a concrete reason staging must always be by explicit path.

## Deployment and smoke validation under the reduced local stack

This section is deliberately split into four categories, and **every item sits in exactly one of them**. The point of the split is that a reader can tell at a glance which claims rest on an executed round-trip and which rest on an argument.

### 1. What the reduced stack is

The project setup instructions deliberately reduce the reference stack. This is **given direction, not a shortfall discovered along the way**:

- **Alfresco, Solr and Pentaho are skipped.** They are not required for container startup or for login.
- **Active Directory is replaced by a local OpenLDAP directory server**, with the paged-and-sorted search overlay enabled because ArkCase's directory queries need it.
- **ActiveMQ runs over `tcp://` only.**
- No credentials for the omitted systems will ever be provided.

[The developer setup guide](../setup.md) describes the full reference VM, which hosts Solr, ActiveMQ, MySQL, Alfresco and Pentaho. Three of those five are absent from the local stack, and the two that remain — the message broker and the database — are present and reachable.

### 2. What is directly exercisable

These three are reachable with the local stack as reduced, and the reduced stack is sufficient for them. The word is deliberately **exercisable** rather than "exercised": what the reduced stack permits is stated here, and gate 4 stays CONSTRAINED regardless, because a readiness criterion evaluated against three absent services is not the criterion the gate names.

- **The assembled artifact and its deployment.** The WAR is produced at its unchanged path and can be deployed to a Tomcat 9 instance — started from a scratch directory rather than the repository root, because the workflow engine writes into the working directory.
- **Container startup with the migrated dependency set.** This is the item that would genuinely exercise the reinstated `javax`-namespaced EE artifacts at runtime rather than only at compile time, since the JAXB context, marshaller and unmarshaller are all used by the application and the JDK no longer supplies any of them.
- **The authenticated login flow** against the local directory server, performed through the **form-post endpoint** rather than the plain login path, which is the documented entry point for this stack.

### 3. What is verified by contract preservation rather than by a round-trip

The document round-trip, the search round-trip and the message transit fall here. The argument is not "nothing should have changed"; it is that **there is no mechanism by which this migration could alter wire behaviour on those three paths**, and it rests on three separate legs:

- **Every client library, and every client library version, is unchanged.** Each of the following was read from the root `pom.xml` at the base commit and again on the migrated tree, and compared:

| Service | Client and version | Unchanged? |
| --- | --- | --- |
| Solr | `org.apache.solr:solr-solrj` 7.6.0 | yes |
| ActiveMQ | 5.13.2 with JMS 1.1 | yes |
| MySQL / MariaDB | `mysql-connector-java` 8.0.16 and `mariadb-java-client` 2.2.6 | yes |
| Alfresco / CMIS | `chemistry-opencmis-client-impl` 1.1.0, **ATOMPUB** binding, with its runtime exclusions retained | yes |
| Pentaho | over HTTP through the report-plugin controllers and the HTTP proxy module — no dedicated client library | yes |
| Configuration server | a plain property file supplied through a JVM system property — **no Spring Cloud Config dependency exists in the reactor at all** | yes |

- **The configuration keys and the REST surface are unchanged.** No controller signature or request mapping is touched, and the RAML surface is frozen. The one serialization question the migration did face — Jackson's handling of Java time types — was deliberately resolved with a test-scope module-access directive precisely **because** the alternative would have changed response payloads from a field-based object to ISO-8601 strings. That decision is attributed in [the module-access exceptions record](add-opens-exceptions.md) and recorded as an R-7 resolution in [the behavioral decisions record](behavioral-decisions.md).
- **The 918 green unit tests exercise the client-facing service and controller layers of each integration.** They are not a substitute for a round-trip, and they are not offered as one; they are corroboration that the layers immediately behind each client still behave as their assertions require, with **no assertion modified anywhere** in the 402 base-commit test sources.

!!! warning "This is an argument, not an executed round-trip"
    No live document round-trip to Alfresco, no live search round-trip through Solr and no live report retrieval from Pentaho was performed. Contract preservation is genuinely strong evidence for a toolchain migration that changes no client and no endpoint, but it is evidence of a different kind, and anyone relying on this page for a production go/no-go should execute these three against a full stack before doing so.

### 4. What is documented as environment-constrained

The three live round-trips themselves. They are recorded here as **environment-constrained**, not as passes, and gates 4 and 5 are marked CONSTRAINED for exactly this reason and nowhere hedged into something warmer.

The **R-7** requirement to capture smoke checks against the baseline build first and then replay them is honoured for **every flow the reduced stack can execute** — the build, the artifact, container startup and the authenticated login. It cannot be honoured for a flow that neither side of the comparison can run, and no baseline figure is offered for the three round-trips, because none was measured.

### What must not be treated as a failure

Four things look like gaps and are not. Each is either explicitly out of scope by direction, or a finding the instructions require to be documented rather than fixed.

| Observation | Disposition |
| --- | --- |
| **No Active Directory endpoint** | Out of scope by direction. Authentication is validated against the local OpenLDAP server instead |
| **No ArkCase CA private key** | Out of scope by direction. It will never be provided, and no validation item depends on it |
| **No administrator credential is reproduced here** | Deliberate. This page names no password, no keystore or trust-store password, and no credential of any kind. [The developer setup guide](../setup.md) carries redacted placeholders and a hygiene note, and this page does not resolve, restate or work around them |
| **ActiveMQ's TLS transport does not work on Java 17** | A **known finding to document, not to fix, and not to fail setup for**. The broker is reached over `tcp://` in the local stack, and no broker URL exists anywhere in this repository to change — endpoints come from the external configuration bundle. It is registered in [the known-issues register](known-issues.md) |

## Definition of done

The migration is complete when all of the following hold **simultaneously**. Each is phrased so that it can be checked rather than judged.

- `mvn -B clean install -DskipTests` exits 0 across the full 142-module reactor on JDK 17, and the WAR is written at its unchanged path `acm-standard-applications/arkcase/target/arkcase-2021.03.war`.
- `mvn -B test` exits 0 with zero failures and zero errors, under **exactly two class-level exclusions and no other exclusion** — no added `@Ignore` annotation, no `testFailureIgnore`, no negation filter, and **no modified assertion anywhere** in the 402 base-commit test sources. The 21 reported skips are all pre-existing `@Ignore` annotations and are not moved.
- The static audit returns **zero hits in both main and test source**.
- `npm ci` validates cleanly against the committed `package-lock.json` and `npm run build` exits 0 on Node 20, emitting the full artifact set with an **unmodified `Gruntfile.js`**.
- The compiler reports **release 17** and no `-source 8` warning appears anywhere in the build log.
- Production launch configuration contains no `--add-opens`, no `--add-exports` and no `--illegal-access`, and every one of the eight test-scope directives is individually attributed in [the module-access exceptions record](add-opens-exceptions.md).
- All seven `docs/migration` pages exist **and are registered in the mkdocs navigation** — an unregistered page is an unpublished page, because the docs pipeline is techdocs-driven.
- `README.md` and [the developer setup guide](../setup.md) state Java 17, Maven 3.8+, Node 20 and npm 10 consistently, with yarn removed from the prerequisites.
- Both CI files start successfully under JDK 17, meaning the CMS class-unloading flag that JDK 14 removed is gone from all four of its locations.
- `yarn.lock` is deleted, `package-lock.json` is committed, and **no remaining file invokes yarn**. The only surviving mentions of the word are documentation and two regression tests that assert no yarn invocation and no engine-suppression flag survives in the deploy-time driver.

## Figures this page withdraws

Five figures circulated while this migration was planned and did not survive measurement. They are named rather than quietly corrected, because a reader who has seen them needs to know which value is authoritative and why.

| Earlier figure | Measured value | How it was measured |
| --- | --- | --- |
| 274 reactor modules | **142** | `mvn -o -B validate` on JDK 17.0.20 reports exactly 142 modules and exits 0. The repository holds only 145 POM files in total, three of them outside the reactor, so 274 was never reachable |
| 142 test-bearing modules | **79** | 142 is the size of the whole reactor, not the count of modules carrying test sources. Most reactor entries are aggregators or hold main sources only |
| 773 tests, 0 skipped | **918** tests, **21** skipped | Read from surefire's own XML reports. The earlier pair was captured before the change set added five test classes of its own and before the pre-existing `@Ignore` skips were recognised; the invariant it was cited for — a gap of exactly seven, decomposing as 4 + 3 — is unchanged. Owned by [the baseline record](baseline-test-failures.md) |
| WAR of 277,005,095 bytes | **277,014,616** bytes | Both are real counts of the same source; embedded archive timestamps and the licence plugin's year stamp move the digits between builds. Owned by [the known-issues register](known-issues.md) |
| 447 npm packages installed in 27 s | **432** added, **433** audited | npm's own install output, reconciled against the committed lockfile's 435 entries less the 3 that are optional and not installable on this platform. A 447 figure is unreachable from this lockfile; the 27 s was a property of the machine and its cache, not of the change set |

The static-audit count is the one planning figure that measurement **confirmed** rather than corrected: `git grep` at the base commit returns **seven hits across five files**, and zero in test source. An earlier statement of "four files" is wrong, and [the static audit](static-audit.md) carries that correction with the arithmetic that exposes it.

## What this record does not cover

**The suite totals and the exclusion accounting.** This page restates them only far enough to be self-consistent. They are measured and owned by [the baseline record](baseline-test-failures.md), together with the collateral cost of a class-level exclusion and the two alternatives rejected on evidence.

**Per-library attribution of the module-access directives.** The eight directives are counted here and certified as test-scope only; each one's demanding library and exact failing stack frame belongs to [the module-access exceptions record](add-opens-exceptions.md).

**Why each dependency moved.** Every version change, its reproduced failure and the candidates considered and withdrawn belong to [the dependency inventory](dependency-change-inventory.md). This page names versions only where a gate's evidence depends on one.

**The classification of the audit hits.** [The static audit](static-audit.md) owns the command, the classified before state and the complete set of import edits. This page publishes only the pass/fail result.

**Pre-existing defects.** Documented, not fixed, in [the known-issues register](known-issues.md) — including the two that produce the four baseline test failures and the frontend warning reproduced above.

**Ambiguities resolved against observed Java 8 behaviour.** Those are decisions rather than evidence and belong to [the behavioral decisions record](behavioral-decisions.md).

## Related records

| Record | What it owns |
| --- | --- |
| [Baseline test failures](baseline-test-failures.md) | The measured Java 8 baseline, the authoritative suite totals, the two class-level exclusions and their collateral cost |
| [Dependency change inventory](dependency-change-inventory.md) | Every dependency and plugin change with its reproduced reason, and every withdrawal |
| [Static audit](static-audit.md) | The audit command, its classified hits before, and the zero-hit result after |
| [add-opens exceptions](add-opens-exceptions.md) | The eight test-scope directives with per-library attribution, and the certification that production launch configuration has none |
| [Known issues](known-issues.md) | The pre-existing defects documented and deliberately not fixed |
| [Behavioural decisions](behavioral-decisions.md) | Every ambiguity resolved against observed Java 8 base-commit behaviour |
| [Developer setup](../setup.md) | The prerequisites, the backing-service set, the build command and the launch configuration |
