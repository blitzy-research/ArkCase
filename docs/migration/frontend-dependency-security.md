# Frontend Dependency Security

## Why this page exists

The Java 17 and Node 20 migration reproduces the frontend dependency graph **exactly**. That is the point of it: every one of the 76 Git dependencies is pinned to the immutable commit that Yarn had resolved, so the libraries the browser receives after the migration are byte-for-byte the libraries it received before it.

The unavoidable consequence is that the graph's **age** is reproduced along with its content. This page measures that exposure honestly, records what the migration's own rules permitted it to change, and states what remains, why it remains, and what has to happen next. It exists because a reproducible graph with known vulnerabilities in it is a security position that must be *stated*, not one that may be left implicit in a lockfile.

Everything below was measured on **August 7, 2026** with `npm audit` on the committed lockfile, on Node 20.20.2 with npm 10.8.2. The complete npm and OSV responses, the lockfile-derived SBOM, their integrity manifest and the commands that reproduce them are committed with the migration evidence.

> **Correction notice.** An earlier revision of this page described a remediation that removed five packages and reported the resulting smaller graph — 71 advisories over 401 packages — as the delivered position. That is **not** the delivered position, and the numbers below replace it. The five packages are present in the committed manifest, deliberately, for the reason given in [What the migration's rules permitted](#what-the-migrations-rules-permitted-and-what-they-did-not). The advisory corpus that accompanied the earlier text was captured against a lockfile whose SHA-256 was `d8eca866…`; the committed lockfile is `6506f9b8…`. The corpus in this repository has been **re-captured against the committed lockfile** and every figure on this page now comes from that capture. The earlier revision also asserted that all five build artifacts are byte-identical between runtimes; three of the five are, and the two that are not are recorded in [Ambiguity Resolutions](ambiguity-resolutions.md) §6a and as entry 13 of [Pre-existing Defects](pre-existing-defects.md).

## Measured position

Measured against the committed lockfile, SHA-256 `6506f9b84d8000f9a349c4ebb87bbb14f79295774555e2707324fd92ce55b302`:

| | Committed graph |
| --- | ---: |
| Critical advisories | **30** |
| High | **36** |
| Moderate | **31** |
| Low | **4** |
| **Total advisories** | **101** |
| Installed packages (production) | **780** |
| Installed packages (all scopes) | **801** |
| Lockfile package entries | **802** |
| Direct dependencies carrying an advisory | **40** |
| Direct dependencies declared | **105** production, **1** development |

This is a large number and the page does not soften it. What matters for reading it correctly is that it is almost entirely **inherited**, not created: the graph is the base commit's graph with three packages removed, and the removals are the three the migration plan authorises. There is no version in this table that the migration chose; every version is the one Yarn had already resolved, now pinned to the commit that Yarn resolved it to.

## Dated advisory corpus and continuous gate

The August 7, 2026 capture queried the npm registry and OSV.dev directly. It reproduced the 101 frontend advisories above, generated a CycloneDX 1.5 SBOM with **801 components and 802 dependency entries**, and queried the **57 Maven coordinates governed by migration-changed versions**. OSV reported **11 affected coordinates and 40 unique advisories** in that bounded Maven set. The Maven result is deliberately not described as a whole-reactor scan; unchanged coordinates are outside this capture's stated scope.

| Evidence | Purpose |
| --- | --- |
| [Capture metadata](smoke-evidence/advisory-corpus/2026-08-07-capture-metadata.json) | Source-input digests, tool versions, counts and SBOM normalisation record |
| [npm audit response](smoke-evidence/advisory-corpus/2026-08-07-npm-audit.json) | Complete advisory response for the committed frontend lockfile |
| [CycloneDX SBOM](smoke-evidence/advisory-corpus/2026-08-07-frontend-sbom.cdx.json) | Lockfile-derived component and dependency graph |
| [Maven OSV queries](smoke-evidence/advisory-corpus/2026-08-07-maven-osv-queries.json) | The exact 57 Maven package/version queries |
| [Maven OSV batch response](smoke-evidence/advisory-corpus/2026-08-07-maven-osv-response.json) | Coordinate-to-advisory result set |
| [Maven OSV advisory records](smoke-evidence/advisory-corpus/2026-08-07-maven-osv-advisories.json) | Complete records for the 40 unique advisory identifiers |
| [SHA-256 manifest](smoke-evidence/advisory-corpus/2026-08-07-sha256-manifest.txt) | Integrity check for every captured JSON document |
| [Capture](smoke-evidence/advisory-corpus/capture-advisory-corpus.sh) and [verification](smoke-evidence/advisory-corpus/verify-advisory-corpus.sh) scripts | Reproducible acquisition and fail-closed comparison |

The SHA-256 manifest is an integrity record, not a claimed signature. Dependency assurance uses approved live access to the authoritative npm and OSV services and fails closed when either cannot be queried. The CI image is a separate subject: its guard requires an operator-verified signature, SPDX SBOM and SLSA provenance bound to the executing digest.

Canonicalisation is required for two captures of one unchanged graph to compare equal, and it took two attempts to get right. npm emits a wall-clock timestamp and a random serial UUID in each generated SBOM: the capture script sets the timestamp to the explicit capture date at midnight UTC and derives the serial as UUIDv5 over the capture date and the committed lockfile digest. `npm audit` is **also** not byte-deterministic, which the first revision of this page did not know when it claimed two captures produce byte-identical documents.

The nondeterminism is narrow and was measured precisely. Two captures of one unchanged lockfile disagree about which of two advisory-carrying packages owns a shared downstream effect: one run attributes `template` to `config-cache`, the other to `option-cache`, and `config-cache`'s `fixAvailable` flips between the fix-target object and a bare `true` as that edge moves. **Nothing else differs**, and that was established by comparing the two captures field by field rather than assumed: the 101 advisory names, every severity, every version range, every `isDirect`, every `nodes` list, every `via` list, the union of affected packages (63 packages, `template` among them on both sides), the set of 12 fix targets, and all dependency and severity totals in `metadata` are identical.

The second revision of this page said the script sorts `effects` and `via` and that this settled it. **It did not, and that claim is withdrawn.** The difference is set membership, not ordering, so sorting cannot remove it; the gate still failed on an unchanged graph, which is how the incompleteness was caught. The attribution is now hoisted to document level, where it is deterministic: `effects` becomes a document-wide sorted union under a `blitzyCanonicalisedAttribution` key, per-finding `fixAvailable` is reduced to the boolean it is actually used as, and the fix-target details are retained as a document-wide sorted set. `via` is still sorted, because ordering genuinely is all that varies there.

This remains canonicalisation of a nondeterministic field rather than suppression of a difference, and the security meaning is retained in full: a newly affected package changes the union, a new or withdrawn advisory changes the names, a changed severity or range changes the finding, and a fix that stops being available changes the boolean or the target set. Each of those still fails the gate. Replacing the corpus under the corrected canonicalisation was verified not to move the recorded posture — advisory names, severities, ranges, `nodes`, fix availability, the effects union, the fix-target set and all totals compare equal to the previously committed corpus, and only `npm-audit.json`'s digest changed in the manifest. With the hoist in place, two independent captures for August 7 produce byte-identical results across **all seven** files, verified by running the capture twice into separate directories and comparing every file.

**The verification gate exists as a committed, working script and is NOT yet wired into CI.** This is stated plainly because an earlier revision of this page described a `verify_dependency_security` CI job that does not exist. `.gitlab-ci.yml` declares `build_backend_develop`, `deploy_server`, `deploy_backend_core_dev`, `deploy_backend_foia_dev`, `start_security_scan` and `security_scan_results`, and no job by that or any equivalent name invokes `verify-advisory-corpus.sh`.

What does exist, and what an operator can rely on today:

- `verify-advisory-corpus.sh` in the evidence directory. It checks the committed SHA-256 manifest, re-queries both authoritative advisory services, regenerates and normalises the SBOM, and fails closed unless the five security payloads and all non-tool capture metadata match the reviewed corpus exactly. It was run against the committed corpus and **passes**, reporting 101 advisories, 57 Maven coordinates with 11 affected and 40 unique advisories, and an 801-component SBOM. A new, withdrawn or modified advisory, a changed package graph, or an unavailable advisory service makes it exit non-zero.
- The toolchain guard in `.gitlab-ci.yml`'s `default.before_script`, which every job inherits. It enforces the Java, Node, npm and Maven versions the graph was resolved with, and refuses a build image that is not registry-qualified and digest-pinned. It does not query advisory services.
- `start_security_scan` and `security_scan_results`, which drive an external scanning service on a separate schedule from the build.

Wiring the verification script into the pipeline is a one-job change and a **prerequisite that has not been performed**. Until it is, the corpus is a dated, reproducible, reviewed snapshot rather than a continuously enforced gate, and this page claims nothing stronger.

## What the migration's rules permitted, and what they did not

**Three** declared dependencies were removed, and they are the three the migration plan enumerates: `grunt-sass`, the vendored `npm`, and `bower`.

| Package | Why the plan authorises removing it |
| --- | --- |
| `grunt-sass` | Its transitive native Sass compiler cannot build on Node 20 — the only install failure among eighteen legacy packages tested. Removal rather than replacement is output-neutral: `Gruntfile.js` declares no Sass task at all, and the CSS asset globs consume only compiled `.css`, so the 16 tracked `.scss` files are never read by the pipeline |
| `npm` | A seven-major-version-old package manager vendored inside the project's own dependency graph. Retaining it means the frontend is not genuinely running on npm 10, which **R-4** forbids |
| `bower` | Dead tooling: no `bower.json` and no `.bowerrc` exist anywhere in the tree, and no task invokes it. The `@bower_components` key prefix is a historical naming artifact, not evidence of Bower being used |

### Why `karma`, `karma-jasmine`, `jasmine-core`, `grunt-karma` and `template` are still here

They are dead — that part of the earlier analysis was correct and still holds. No Karma configuration file exists anywhere in the tree, there are **zero `*.spec.js` files**, `Gruntfile.js` declares no `karma` task, nothing calls `require('template')` outside `node_modules`, and the lockfile records the project root as `template`'s only dependent. Three of the five carry Critical advisories: `karma`, `grunt-karma` and `template`.

They are nonetheless retained, and the reason is precedence rather than a change of mind about the evidence.

The migration plan is frozen, and §0.5.2 enumerates the Node-side removals exhaustively: `grunt-sass`, `npm`, `bower`. It does not authorise a fourth, a fifth or an eighth. **R-1** requires every dependency change to carry a specific Java 17 or Node 20 compatibility reason, and these five have none — they install and resolve on Node 20 without complaint. The earlier revision of this page argued that **R-4**'s prohibition on vendored dead packages supplies the missing justification independently of R-1. That argument is not unreasonable, and it is why the removal was attempted; but a register cannot widen the scope the plan fixes. Where this page's own reasoning and the frozen plan disagree, the plan governs, and the plan's Node-removal list is closed. Removing them is correct work for a follow-up change with its own authorisation, not work this migration may absorb.

Two consequences follow, and both are stated rather than left to inference:

- **The graph is larger than it needs to be, and this page's numbers reflect that.** 802 lockfile entries rather than the ~400 the removal would have produced, and 30 Critical advisories rather than 15. The difference is entirely dead build tooling that the browser never receives and that no task executes; it is not additional exposure in served code. It is nonetheless real exposure, because these packages are installed on the deployment host and their install lifecycle scripts run there — see Group B below.
- **The removal, when it is authorised, is provably output-neutral.** That was measured while the removal was in place: the 65 distinct package roots `config/env/all.js` resolves paths under have **zero intersection** with the 379 packages the removal drops, and the same check against the Gruntfile's own top-level requires — `fs-extra`, `glob`, `homedir`, `load-grunt-tasks`, `lodash`, `nunjucks` — also returns zero. Whoever picks the work up does not need to re-derive that.

### What is verified about the committed graph

Measured at the working tree rather than assumed:

- **The lockfile is valid and exactly pinned.** `lockfileVersion` is 3, `npm ci` restores from it, and there is no `#semver:` range in either the manifest or the lockfile. All **76** Git-resolved direct dependencies carry an exact 40-character commit: **58** in the `owner/repo#<sha>` form and **18** in the codeload tarball form that embeds the same commit in its path. The remaining 29 direct entries are ordinary registry ranges, as they were at the base commit.
- **Dependency keys are preserved.** Every key `config/env/all.js` resolves a path under is present and unrenamed, and the install topology is unflattened — which is what **R-T6** protects. Measured in the committed file: **87** literal `node_modules/` path references resolving under **65** distinct package roots.
- **The runtime contract is declared.** `engines` is `{"node": ">=20 <21", "npm": ">=10 <11"}` and `scripts.build` is `grunt`, so `npm ci && npm run build` is the documented and working entry point.

## What remains: 101 advisories, triaged

The remaining advisories fall into two groups that need to be read differently.

### Group A — libraries the browser receives (behaviour-bearing)

These are concatenated into `vendors.min.js` or loaded directly by the application, from the `@bower_components/*` Git pins. Upgrading any of them changes the bundle bytes and therefore the application's behaviour, which is precisely what this refactor is defined not to do.

| Severity | Package | Version installed | Nature | Upstream fix |
| --- | --- | --- | --- | --- |
| Critical | `crypto-js` | 3.1.9 | npm's advisory is about PBKDF2 (CWE-327, CWE-328, CWE-916, CVSS 9.1). The path this application actually reaches is **not** PBKDF2 — see below | none for this line; fixed in 4.2.0 |
| Critical | `sockjs-client` | 1.1.2 | advisory covers 1.0.0-beta.4 – 1.1.5 | none published for this line |
| High | `handsontable`, `chart.js`, `angular-chart.js`, `moment`, `angular-moment` | as pinned | ReDoS, prototype pollution, path traversal in `moment.locale` | none published |
| Moderate | `angular`, `angular-sanitize`, `angular-cache`, `angular-ui-bootstrap`, `angular-ui-grid`, `angular-ui-scroll`, `angular-xeditable`, `angular-moment-picker`, `jquery`, `bootstrap`, `bootbox`, `ngbootbox`, `summernote`, `videogular` and its four companion packages | as pinned | predominantly XSS and prototype pollution (CWE-79, CWE-1321) | **AngularJS 1.x is end-of-life; `angular` reports the advisory range as `*`, meaning no fixed version exists at all** |

Two of these are reachable in ordinary use and are named explicitly rather than left implicit: the `crypto-js` encryption path, and the SockJS WebSocket connection.

**The `crypto-js` reachability, stated precisely, because an earlier revision of this page described it wrongly.** That revision called it "the AES/PBKDF2 path" and characterised the exposure as a low PBKDF2 iteration count, following npm's advisory title. The advisory is accurate about `crypto-js`; it is not what this application does. The only application file that references `CryptoJS` is `services/common/util.client.service.js`, whose `encryptString` at `:795-805` calls `CryptoJS.AES.encrypt(string, passphrase)` with a **string** passphrase. That overload never touches PBKDF2. It runs OpenSSL's `EVP_BytesToKey`, whose defaults in this version are visible in the installed package at `node_modules/@bower_components/crypto-js/evpkdf.js:38-40` — `keySize: 128/32`, `hasher: MD5`, `iterations: 1`. One iteration of MD5. The salt comes from `WordArray.random`, which in 3.1.9 derives from `Math.random()` (`core.js:318`, `:323`) rather than a cryptographic source. The cipher is AES-CBC with no authentication tag.

Three further properties make the reachable path materially worse than the advisory suggests, and all three are pre-existing application behaviour rather than library behaviour:

- **It fails open to plaintext.** `encryptString` returns its input unchanged when `passphrase` is falsy, and its `catch` logs `"Error on encryption, returning plain query string"` and then also returns the input unchanged. There is no path on which a caller learns that encryption did not happen.
- **What it protects is an authenticated session ticket.** `modules/.../snowbound-viewer.client.service.js` builds `buildSnowboundUrl` by concatenating `ecmFileId`, `acm_ticket`, `userid`, `userFullName`, `caseNumber`, `documentName`, `parentObjectId`, `parentObjectType` and `selectedIds` into one string, passing it to `encryptString` with the passphrase read from `ecm.viewer.snowbound.encryptionKey`, and placing the result in a URL as `?documentId=<ciphertext>&refreshCacheTimestamp=<epoch-ms>`.
- **The result travels in a URL.** URLs are logged by proxies, retained in browser history and, for the document viewer, carried into an iframe — so when the fail-open branch is taken, the session ticket is in cleartext in all of those places.

This is registered as a security defect in [Pre-existing Defects](pre-existing-defects.md) rather than repaired here: the file is application JavaScript, which the migration's exclusion list freezes, and `crypto-js` 4.2.0 is not a drop-in for a served library under the byte-identical artifact criterion. Recording it accurately is the obligation this page can discharge.

**Why they are not upgraded here.** Four independent reasons, each a rule rather than a preference:

1. **R-1** — a dependency change requires a specific Java 17 or Node 20 compatibility reason. None of these has one; they all install and run on Node 20.
2. **The byte-identical artifact criterion** — the migration's strongest available behavioural evidence for the frontend is artifact comparison, because there is no automated behavioural test to fall back on: the frontend contains **zero spec files**. Upgrading a concatenated library changes the bundles by construction, which would destroy that evidence outright. The criterion is not fully met as it stands — three of the five artifacts are byte-identical across runtimes and two are not, recorded in [Ambiguity Resolutions](ambiguity-resolutions.md) §6a — and that is precisely why no further variance may be introduced on top of it.
3. **R-T6** — the asset-layout contract is immutable. `config/env/all.js` resolves literal paths inside these packages; several point at specific built files whose names and locations differ between major versions.
4. **AngularJS 1.x is end-of-life.** Most of Group A consists of AngularJS and its ecosystem. There is no patched version to move to. Remediating this group is not a dependency bump; it is a framework migration — and a new frontend framework is on the migration's explicit exclusion list.

### Group B — build-time tooling (not served to the browser)

These run under Node during the assembly and are never sent to a client. They are still real exposure, because they execute in the deployment host's Tomcat process at startup and read the project tree.

| Severity | Package | Upstream fix npm reports |
| --- | --- | --- |
| Critical | `grunt` | `grunt@1.6.3` |
| Critical | `grunt-ng-annotate` | `grunt-ng-annotate@4.0.0` |
| Critical | `lodash` (the Gruntfile's own) | via `grunt@1.6.3` |
| High | `grunt-contrib-watch` | `grunt-contrib-watch@0.4.4` |
| High | `load-grunt-tasks` | `load-grunt-tasks@3.5.2` |
| High | `nunjucks` | `nunjucks@3.2.4` |
| Moderate | `grunt-cli` | `grunt-cli@1.5.0` |
| Moderate | `grunt-contrib-uglify` | `grunt-contrib-uglify@5.2.2` |
| Moderate | `grunt-contrib-csslint` | `grunt-contrib-csslint@2.0.0` |
| Moderate | `grunt-contrib-jshint` | available |
| Low | `grunt-contrib-cssmin` | `grunt-contrib-cssmin@5.0.0` |

**Why they are not upgraded here.** Group B is where a fix *is* published for almost every entry, so the reason has to be stated precisely rather than borrowed from Group A. `grunt-contrib-uglify` is the minifier and `grunt-contrib-cssmin` the CSS minifier: advancing either from the 0.9/0.12 line to the 5.x line replaces the underlying compressor outright, which changes the produced bytes and fails the byte-identical criterion — the same reason the migration removed the Sass toolchain rather than replacing it. `grunt` 0.4.5 → 1.6.3 is a task-runner major change that alters plugin loading and option handling for every plugin in the pipeline. `nunjucks` 1.x → 3.x changes template semantics, including autoescape defaults, and `home.tpl.html` is rendered through it. Every one of these is a change with a **behavioural** consequence and **no Node 20 compatibility justification** — and Grunt 0.4.5 was verified during the migration to both install *and execute* on Node 20, which is exactly why **R-1** kept it where it is.

Group B is nevertheless the group that should be remediated first, because it is the one where remediation is possible at all.

## Compensating controls — what actually exists, and what does not

An earlier revision of this page described three controls in `AngularResourceCopier`: an allowlisted child environment, mandatory launcher and version verification with watchdogs, and handle-relative writes with no-follow opens and containment checks. **None of them is in the delivered code.** They were implemented in an earlier revision of this change set, which grew the file from 593 lines to 1,864, and that work was withdrawn as outside the scope AAP §0.4.1 fixes for this file — which authorises one change, the keep-list predicate that names the lockfile. The claims were left behind when the code was removed. They are retracted here.

What the delivered copier actually does, verified by reading it, is recorded as entry 58 of [Pre-existing Defects](pre-existing-defects.md): the install runs before the stale-file sweep rather than after it; the child process inherits Tomcat's entire environment; there is no watchdog, so there is no timeout; the launcher is resolved from `PATH` and never asked its version; and the file walks follow symbolic links while one deletion result is discarded. Every one of those is base-commit behaviour, unchanged by this migration — but "unchanged" is not "mitigated", and this page previously said mitigated.

So the honest statement of compensating controls is a short one:

- **The install is lockfile-determined.** `npm ci` selects no package version outside `package-lock.json`, and every Git dependency is pinned to an immutable commit, so the graph cannot silently acquire a different version between two deployments. This is a genuine control and it is the one the migration added.
- **The toolchain is pinned where the build runs in CI.** `.gitlab-ci.yml`'s inherited `before_script` refuses a build image that is not registry-qualified and digest-pinned, and enforces the Java, Node, npm and Maven versions the lockfile was resolved with. It governs CI only; it says nothing about the deployment host, where the startup build also runs.
- **`engines` is declared** as `{"node": ">=20 <21", "npm": ">=10 <11"}`. This is advisory: npm warns rather than refuses unless `engine-strict` is set, and nothing in the delivered copier enforces it.

What is **not** in place, stated so no reader plans around it: no environment allowlisting, no execution timeout, no launcher pinning or version interrogation at deployment time, and no symlink or containment protection on the startup build's file operations. The exposure those would narrow is the exposure Group B describes, and the architectural fix — moving the install and pipeline out of Tomcat startup into the Maven build — is the recommendation recorded with entry 58.

## Owner-authorised remediation programme

QA finding C-1 and the AAP's §0.8.5 execution-evidence authority establish this as a separate security programme rather than an unreviewed extension of the behaviour-preserving runtime migration. The accountable role is the **ArkCase release-security evidence owner**. The frontend build owner, application-platform owner and Java platform owner deliver the workstreams below; release governance maps those roles to named people and target releases in its controlled change record. That staffing record is intentionally not embedded in source control, but the sequence, gates and evidence contract are.

**Programme status: AUTHORISED.** This section is the governed execution contract required by C-1, not advice awaiting later ratification. The current migration does not perform the programme's behaviour-changing upgrades; it establishes the owner, ordering, entry gate, completion evidence and explicit boundary that make those follow-on changes reviewable.

The sequence is mandatory: build tooling is remediated before served libraries, and no stage may be closed merely because installation succeeds.

| Stage | Accountable delivery role | Work | Completion and revalidation gate |
| --- | --- | --- | --- |
| 0 — continuous evidence | Release-security evidence owner | **Partly delivered, and the gap is the wiring.** Delivered: `verify-advisory-corpus.sh`, which re-queries npm and OSV, regenerates and normalises the CycloneDX SBOM, and fails closed unless every security payload and all non-tool capture metadata match the reviewed corpus — verified passing against the committed corpus. **Not delivered:** any CI job that invokes it. Adding one job that runs it before the build is the outstanding work in this stage. | Once wired, a successful pipeline must print the image and evidence identifiers and pass the advisory/SBOM comparison, and any source or graph drift must require a new dated corpus, an updated triage and explicit owner review before the build proceeds. Until then the script is run by hand and its result recorded on this page. |
| 1 — Group B build tooling | Frontend build owner | Upgrade Grunt, its CLI, annotation, minification, lint, watch and template toolchain as one isolated change set, using the fixed versions reported in the current npm response as the starting floor rather than applying an unbounded automated rewrite. | Two clean builds from the new lockfile must be byte-identical to each other; all five required artifacts must exist; every difference from the migration digests must be explained and reviewed; `npm audit` and the SBOM must be recaptured; the Grunt task graph, generated `home.html`, source maps and startup assembly tests must pass. No Critical or High Group B advisory may remain without a separately recorded, time-bounded owner exception. |
| 2 — remove startup-time installation | Application-platform owner | Move dependency installation and asset generation into the trusted CI build, package the reviewed outputs in the WAR, and reduce or remove the deployed `node_modules` tree after exhaustively replacing runtime path dependencies. Tomcat startup must not contact a package registry. | A clean WAR build must succeed with network access disabled during deployment; the five frontend artifacts and every configured asset path must resolve; two WARs from the same inputs must match; startup evidence must show no npm or Grunt child process; module tests and the runtime smoke flows must pass. |
| 3 — Group A served libraries | Frontend product owner | Remediate reachable Critical packages first (`crypto-js`, then `sockjs-client`), then replace the end-of-life AngularJS ecosystem and its jQuery/Bootstrap/Moment/Summernote integrations as a governed frontend programme. | Add browser-level tests before changing the served graph. Re-run login/session/authority, ACL-filtered views, generated-number, workflow and queue-transition flows; run content-security and XSS regression cases; recapture audit/SBOM evidence. No Critical or High served-library advisory may remain without a separately recorded, time-bounded owner exception. |
| 4 — migration-owned Maven coordinates | Java platform owner | Triage the 40 OSV records attached to the 11 affected migration-owned coordinates for reachability and vendor-supported fixes. Implement required upgrades in separate, bounded change sets rather than silently broadening this migration. | For every record, retain a reachability/fix verdict; run the full reactor and affected module suites; repeat the runtime security flows; regenerate the OSV corpus. This gate covers only the 57 recorded coordinates and must not be represented as a whole-reactor result. |

### Exclusions from this migration

These are named boundaries of the current migration, not permission to omit them from the programme above:

- **No advisory-driven version advance is folded into the runtime migration.** R-1 permits a dependency change here only for a demonstrated target-runtime compatibility reason, and the five byte-identical frontend artifacts are a mandatory migration acceptance criterion.
- **No frontend framework replacement is folded into this migration.** AngularJS replacement changes application behaviour and belongs to programme stage 3 with browser-level tests.
- **No frozen asset-layout property is changed here.** Removing startup installation or narrowing the deployed package tree changes the R-T6 layout contract and belongs to programme stage 2 with exhaustive path and WAR validation.
- **The Maven corpus is bounded.** It covers the 57 coordinates whose versions changed under this migration; unchanged reactor dependencies and operating-system/container packages require their own inventory and scanner.
- **No advisory is suppressed to make a gate pass.** Automated force-upgrade, audit-level overrides, vulnerability allowlists without an owner and expiry, and count-only acceptance are prohibited.

The deployed surface still deserves specific work inside stage 2. The assembled deployment currently carries the complete `node_modules` tree because `config/env/all.js` and two application source files resolve runtime paths inside it. The registry copies `node_modules/angular` 1.8.2, `node_modules/jquery` 3.5.1 and `node_modules/moment` 2.29.1 also sit beside the older `@bower_components` copies used by the asset layout. Current reference analysis finds no direct configured path to those three registry copies, but an AngularJS module or peer dependency may resolve one lazily. Exhaustive runtime and package-resolution evidence is therefore required before they can be removed.

## Risk acceptance

The 101 advisories are **accepted for this change set**, on these terms:

- The accountable role is the ArkCase release-security evidence owner, and the acceptance is scoped to this behaviour-preserving migration. It is not an assessment that the graph is safe; it is the bounded bridge into the separately authorised programme above.
- The residual exposure is predominantly **XSS and prototype pollution in an end-of-life browser framework**, plus the **`crypto-js` encryption path described above** — which is an MD5, one-iteration key derivation with a `Math.random` salt and a fail-open branch, not merely a weak PBKDF2 count — and a **superseded SockJS client**. The first requires a framework programme; the second and third have published later lines and should be taken first.
- No advisory was silenced, suppressed or excluded from the audit. There is no `.npmrc` audit-level override and no `npm audit` allowlist in this repository; the numbers above are the raw output.
- As of August 7, 2026, **26 of the 40 direct findings have no npm-reported fix**; the other 14 require a deliberate toolchain or application change. Lack of a published fix does not close a finding: it determines whether the owner must replace, isolate or time-bound the affected capability.
- **A share of this total is dead build tooling that the plan does not yet authorise removing.** Three of the five packages named earlier carry Critical advisories, and the graph they pull is roughly half the installed tree. That subtotal is not additional exposure in served code, and it is the cheapest reduction available to the follow-up change.
- **The re-measurement is reproducible but not yet continuous.** `verify-advisory-corpus.sh` fails closed on any advisory or graph drift and passes against the committed corpus today, but no CI job invokes it. Until one does, this snapshot is refreshed by running that script, not by the pipeline, and any claim that the build blocks on drift would be false.

## Reproducing every figure and gate

```bash
cd acm-standard-applications/arkcase/src/main/webapp/resources
nvm use 20                       # Node 20.20.2, npm 10.8.2

npm ci                           # restores the committed lockfile: 780 production packages,
                                 # 801 across all scopes, from 802 lockfile entries
npm audit                        # 101 advisories: 30 critical, 36 high, 31 moderate, 4 low
npm audit --package-lock-only --json |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata"])'

npm run build                    # the unchanged Grunt default task graph
sha256sum assets/dist/application.js assets/dist/application.min.js \
          assets/dist/vendors.min.js assets/dist/application.min.css home.html
```

From the repository root, verify the committed corpus and re-query the authoritative services into an empty temporary directory:

```bash
(
  cd docs/migration/smoke-evidence/advisory-corpus
  sha256sum --check 2026-08-07-sha256-manifest.txt
)

CURRENT_CORPUS="$(mktemp -d)"
docs/migration/smoke-evidence/advisory-corpus/verify-advisory-corpus.sh \
  "$CURRENT_CORPUS"
rm -rf "$CURRENT_CORPUS"
```

To create a reviewed replacement snapshot, pass its explicit UTC date to the capture script, inspect every difference, then update the date named by `verify-advisory-corpus.sh`:

```bash
NEW_CORPUS="$(mktemp -d)"
docs/migration/smoke-evidence/advisory-corpus/capture-advisory-corpus.sh \
  2026-08-07 "$NEW_CORPUS"
(
  cd "$NEW_CORPUS"
  sha256sum --check 2026-08-07-sha256-manifest.txt
)
rm -rf "$NEW_CORPUS"
```

Artifact digests recorded when this page was written, and unchanged across the removal of the five dead packages:

```text
3c0aeb4d2b02dc740e733e5ed89c87bf0d229cc19489ee0f023c04af611391b8  assets/dist/application.js
c1a4cb56e4b644c4d6e356698a222f9de2b57dc0114eec86d93323e0a9b41dc2  assets/dist/application.min.js
70187246b480eebb6f920732ce84356fb719b2db9694c10ed20388ff6f5e3be4  assets/dist/vendors.min.js
04228704205f51db7eac073b0001c87e54473f372865a031b910b989c8891ea1  assets/dist/application.min.css
43c5eb7d7735fc2894f0665cf0238cbf3e097baeb1b13c6c39fc5a1078b7c7a9  home.html
```

The source-map caveat recorded elsewhere in this tree applies to `application.min.js.map` and to it alone: it embeds file paths, so it is comparable only between builds run from the same relative path. None of the five artifacts above is affected.
