# Frontend Dependency Security

## Why this page exists

The Java 17 and Node 20 migration reproduces the frontend dependency graph **exactly**. That is the point of it: every one of the 76 Git dependencies is pinned to the immutable commit that Yarn had resolved, so the libraries the browser receives after the migration are byte-for-byte the libraries it received before it. The five build artifacts are required to be byte-identical, and they are.

The unavoidable consequence is that the graph's **age** is reproduced along with its content. This page measures that exposure honestly, records what was remediated inside the migration's own rules, and states what remains, why it remains, and what has to happen next. It exists because a reproducible graph with known vulnerabilities in it is a security position that must be *stated*, not one that may be left implicit in a lockfile.

Everything below was measured on **August 7, 2026** with `npm audit` on the committed lockfile, on Node 20.20.2 with npm 10.8.2. The complete npm and OSV responses, the lockfile-derived SBOM, their integrity manifest and the commands that reproduce them are committed with the migration evidence.

## Measured position

| | Before this page's remediation | After | Change |
| --- | ---: | ---: | ---: |
| Critical advisories | 30 | **15** | −15 (−50%) |
| High | 42 | **26** | −16 (−38%) |
| Moderate | 31 | **27** | −4 |
| Low | 4 | **3** | −1 |
| **Total advisories** | **107** | **71** | **−36 (−34%)** |
| Installed packages | 780 | **401** | **−379 (−49%)** |
| Direct dependencies carrying an advisory | 40 | **37** | −3 |

Half the installed tree, and half the Critical findings, were dead weight.

## Dated advisory corpus and continuous gate

The August 7, 2026 capture queried the npm registry and OSV.dev directly. It reproduced the 71 frontend advisories above, generated a CycloneDX 1.5 SBOM with **399 components and 400 dependency entries**, and queried the **57 Maven coordinates governed by migration-changed versions**. OSV reported **11 affected coordinates and 40 unique advisories** in that bounded Maven set. The Maven result is deliberately not described as a whole-reactor scan; unchanged coordinates are outside this capture's stated scope.

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

npm emits a wall-clock timestamp and a random serial UUID in each generated SBOM. The capture script makes only those two fields deterministic: the timestamp is the explicit capture date at midnight UTC, and the serial is UUIDv5 over the capture date and committed lockfile digest. Two independent captures for August 7 produced byte-identical JSON documents and manifests.

The `verify_dependency_security` CI job runs before the build on every pipeline. It checks the committed manifest, re-queries both authoritative advisory sources, regenerates and normalises the SBOM, and requires the five security payloads plus all non-tool metadata to match the reviewed corpus exactly. A new, withdrawn or modified advisory, a changed package graph, an unavailable advisory service, or an SBOM difference therefore fails the pipeline and requires a dated corpus refresh and security review. The inherited image guard independently prevents that job from running in an image whose digest, signature, SPDX SBOM, SLSA provenance or required toolchain has not been configured and bound to the executing subject.

## What was remediated, and why it was permitted

Five declared dependencies were removed: `karma`, `karma-jasmine`, `jasmine-core`, `grunt-karma` and `template`.

They were **not** removed because they carry advisories. Removing a package because it has a CVE would be a dependency change without a Node 20 compatibility reason, which **R-1** places out of scope, and for a served library it would also change the bundle bytes, which the byte-identical artifact criterion forbids. They were removed because they are **vendored dead packages, which R-4 forbids independently of any advisory** — the same rule, and the same evidentiary standard, that the migration already applied to `bower`.

The evidence for each, verified at the working tree rather than assumed:

| Package | Advisory | Proof it is dead |
| --- | --- | --- |
| `karma` | Critical | No Karma configuration file exists anywhere in the tree; **zero `*.spec.js` files**; `Gruntfile.js` declares no `karma` task; no registered task references it |
| `grunt-karma` | Critical | The Grunt plugin that would invoke Karma. `load-grunt-tasks` loads it and nothing ever calls it — there is no `karma` key in the Gruntfile's task configuration |
| `template` | Critical | No `require('template')` anywhere outside `node_modules`; no reference in `Gruntfile.js`, `config/**`, any application source file or any template; the lockfile shows the project root as its **only** dependent. Home-page rendering uses Nunjucks, required directly at `Gruntfile.js:L9`, which is retained |
| `karma-jasmine` | — | The Karma adapter for Jasmine; no consumer once the runner is gone, and no configuration of its own |
| `jasmine-core` | — | The assertion library the absent specs would have used; zero references outside `package.json` |

### Proof the removal changed nothing observable

This is the part that matters, because "it should be safe" is not evidence.

- **The five build artifacts are byte-identical.** `npm ci && npm run build` was executed on the graph before the removal and again on the graph after it, and the SHA-256 digests of `assets/dist/application.js`, `assets/dist/application.min.js`, `assets/dist/vendors.min.js`, `assets/dist/application.min.css` and `home.html` are the same in both runs.
- **No dependency resolved differently.** Comparing the lockfile before and after: **379 packages removed, 0 added, and 0 with a changed `version` or `resolved` value.** Nothing outside the removed subtrees moved, so the reproducibility guarantee the migration exists to establish is untouched.
- **Nothing the asset layout needs was removed.** The 65 distinct package roots that `config/env/all.js` resolves paths under were checked against the 379 removals: **zero intersection.** The same check against the Gruntfile's own top-level requires — `fs-extra`, `glob`, `homedir`, `load-grunt-tasks`, `lodash`, `nunjucks` — also returns zero.
- **The lockfile is still valid and still exactly pinned.** `lockfileVersion` remains 3, `npm ci` restores from it, there is no `#semver:` range in either the manifest or the lockfile, and all 77 Git-resolved entries still carry an exact 40-character commit — 58 in the `#<sha>` form and 19 in the codeload tarball form that embeds the same commit in its path, exactly the split that existed before.
- **Dependency keys were preserved.** Only five lines were deleted from `package.json`. Every remaining key, and their order, is unchanged — which matters because npm's own `uninstall` re-sorts the manifest alphabetically, and that reordering was reverted so the diff shows five deletions and nothing else.

## What remains: 71 advisories, triaged

The remaining advisories fall into two groups that need to be read differently.

### Group A — libraries the browser receives (behaviour-bearing)

These are concatenated into `vendors.min.js` or loaded directly by the application, from the `@bower_components/*` Git pins. Upgrading any of them changes the bundle bytes and therefore the application's behaviour, which is precisely what this refactor is defined not to do.

| Severity | Package | Version installed | Nature | Upstream fix |
| --- | --- | --- | --- | --- |
| Critical | `crypto-js` | 3.1.9 | PBKDF2 iteration count far below current practice (CWE-327, CWE-328) | none for this line; fixed in 4.2.0 |
| Critical | `sockjs-client` | 1.1.2 | advisory covers 1.0.0-beta.4 – 1.1.5 | none published for this line |
| High | `handsontable`, `chart.js`, `angular-chart.js`, `moment`, `angular-moment` | as pinned | ReDoS, prototype pollution, path traversal in `moment.locale` | none published |
| Moderate | `angular`, `angular-sanitize`, `angular-cache`, `angular-ui-bootstrap`, `angular-ui-grid`, `angular-ui-scroll`, `angular-xeditable`, `angular-moment-picker`, `jquery`, `bootstrap`, `bootbox`, `ngbootbox`, `summernote`, `videogular` and its four companion packages | as pinned | predominantly XSS and prototype pollution (CWE-79, CWE-1321) | **AngularJS 1.x is end-of-life; `angular` reports the advisory range as `*`, meaning no fixed version exists at all** |

Two of these are reachable in ordinary use and are named explicitly rather than left implicit: the `crypto-js` AES/PBKDF2 path, and the SockJS WebSocket connection.

**Why they are not upgraded here.** Four independent reasons, each a rule rather than a preference:

1. **R-1** — a dependency change requires a specific Java 17 or Node 20 compatibility reason. None of these has one; they all install and run on Node 20.
2. **The byte-identical artifact criterion** — the migration's strongest behavioural evidence for the frontend is that the five build artifacts do not change. Upgrading a concatenated library changes them by construction, and there is no automated behavioural test to fall back on: the frontend contains **zero spec files**.
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

## Compensating controls now in place

The exposure is not left unmitigated. Three controls introduced by this change set narrow it:

- **The startup build receives an allowlisted environment, not Tomcat's environment.** `AngularResourceCopier` starts from an empty child environment, constructs `PATH` from the verified Node launcher directory and configured system entries, and supplies only fixed npm/Git safety settings plus explicitly configured proxy or CA values. It rejects ambient Node, npm, Git, SSH, TLS-loader and credential-shaped variables; points npm and Git configuration at UUID-suffixed files that do not exist; disables system Git configuration and terminal prompting; and removes package-manager run-control files with checked deletion before npm executes. Host tokens, startup hooks and planted configuration therefore do not cross the process boundary.
- **The runtime and execution bounds are enforced, not declared.** The copier invokes the configured launchers, asks Node.js and npm for their own versions, and refuses to install unless their majors match the committed lockfile's toolchain. npm treats a manifest `engines` field as advisory; these checks are mandatory. Version probes and build commands also have finite watchdogs and exact-child process destruction, so an unresponsive registry or lifecycle script cannot hold Tomcat startup indefinitely.
- **Staging and deployment writes are handle-relative.** On filesystems that provide `SecureDirectoryStream`, cleanup, source opens, destination copies and link recreation stay relative to once-opened directory handles and reject symbolic-link traversal. The documented fallback uses no-follow opens, containment checks and parent-identity revalidation before a link is recreated. Failed deletion or changed parent identity aborts assembly instead of leaving stale executable content in place.

The install itself is also determined by an immutable lockfile: `npm ci` selects no package version outside `package-lock.json`, so the graph cannot silently acquire a different version between two deployments.

## Owner-authorised remediation programme

QA finding C-1 and the AAP's §0.8.5 execution-evidence authority establish this as a separate security programme rather than an unreviewed extension of the behaviour-preserving runtime migration. The accountable role is the **ArkCase release-security evidence owner**. The frontend build owner, application-platform owner and Java platform owner deliver the workstreams below; release governance maps those roles to named people and target releases in its controlled change record. That staffing record is intentionally not embedded in source control, but the sequence, gates and evidence contract are.

**Programme status: AUTHORISED.** This section is the governed execution contract required by C-1, not advice awaiting later ratification. The current migration does not perform the programme's behaviour-changing upgrades; it establishes the owner, ordering, entry gate, completion evidence and explicit boundary that make those follow-on changes reviewable.

The sequence is mandatory: build tooling is remediated before served libraries, and no stage may be closed merely because installation succeeds.

| Stage | Accountable delivery role | Work | Completion and revalidation gate |
| --- | --- | --- | --- |
| 0 — continuous evidence | Release-security evidence owner | **Delivered here:** run `verify_dependency_security` before every CI build; re-query npm and OSV; regenerate the CycloneDX SBOM; compare against the reviewed corpus; require the executing CI image's immutable identity and three evidence artifacts. | A successful pipeline must print the image/evidence identifiers and pass the advisory/SBOM comparison. Any source or graph drift requires a new dated corpus, an updated triage and explicit owner review before the build proceeds. |
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

The 71 remaining advisories are **accepted for this change set**, on these terms:

- The accountable role is the ArkCase release-security evidence owner, and the acceptance is scoped to this behaviour-preserving migration. It is not an assessment that the graph is safe; it is the bounded bridge into the separately authorised programme above.
- The residual exposure is predominantly **XSS and prototype pollution in an end-of-life browser framework**, plus **weak key derivation in `crypto-js`** and a **superseded SockJS client**. The first requires a framework programme; the second and third have published later lines and should be taken first.
- No advisory was silenced, suppressed or excluded from the audit. There is no `.npmrc` audit-level override and no `npm audit` allowlist in this repository; the numbers above are the raw output.
- As of August 7, 2026, **26 of the 37 remaining direct findings have no npm-reported fix**; the other 11 require a deliberate toolchain or application change. Lack of a published fix does not close a finding: it determines whether the owner must replace, isolate or time-bound the affected capability.
- The CI gate continuously re-measures the accepted corpus. Any advisory or graph drift invalidates this snapshot and blocks the build until the owner reviews and records the changed position.

## Reproducing every figure and gate

```bash
cd acm-standard-applications/arkcase/src/main/webapp/resources
nvm use 20                       # Node 20.20.2, npm 10.8.2

npm ci                           # restores exactly 401 packages from the committed lockfile
npm audit                        # 71 advisories: 15 critical, 26 high, 27 moderate, 3 low
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
