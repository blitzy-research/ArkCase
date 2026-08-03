# Frontend Dependency Security

## Why this page exists

The Java 17 and Node 20 migration reproduces the frontend dependency graph **exactly**. That is the point of it: every one of the 76 Git dependencies is pinned to the immutable commit that Yarn had resolved, so the libraries the browser receives after the migration are byte-for-byte the libraries it received before it. The five build artifacts are required to be byte-identical, and they are.

The unavoidable consequence is that the graph's **age** is reproduced along with its content. This page measures that exposure honestly, records what was remediated inside the migration's own rules, and states what remains, why it remains, and what has to happen next. It exists because a reproducible graph with known vulnerabilities in it is a security position that must be *stated*, not one that may be left implicit in a lockfile.

Everything below was measured with `npm audit` on the committed lockfile, on Node 20.20.2 with npm 10.8.2, and every count is reproducible with the commands in the last section.

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

- **The startup build no longer trusts its own workspace.** `AngularResourceCopier` deletes every package-manager run-control file and every stale file from the staging folder *before* npm runs, forces npm's user and global configuration to a path it never creates, and sets the registry explicitly — so a compromised or planted configuration file cannot redirect an install, and a file left behind by a previous dependency's install script is gone before the next install reads it.
- **The runtime is enforced, not declared.** The same class asks the Node.js and npm launchers for their own versions and refuses to install unless the majors are the ones the committed lockfile was produced with. npm treats a manifest `engines` field as advisory; this check is not advisory and cannot be switched off.
- **Every write is contained and refuses to follow a link.** Copies into the staging and deployment folders are proven to resolve inside their folder and are opened with `NOFOLLOW_LINKS`, so a package that plants a symbolic link during installation cannot make the assembly write outside the tree.

The install itself is also fully determined by an immutable lockfile: `npm ci` resolves nothing at install time, so the graph cannot silently acquire a *new* vulnerable version between two deployments.

## Remediation plan

Sequenced so that each step is verifiable before the next begins. Steps 1 and 2 are outside this migration's rules and belong to a follow-on change; the migration's job was to establish the reproducible baseline they need.

1. **Group B, tooling.** Advance the Grunt pipeline to the versions npm names above, in one change set whose acceptance criterion is a **diff of the five build artifacts against the digests recorded here**. Expect the minifier changes to alter `application.min.js` and `application.min.css`; that is acceptable in a change set whose stated purpose is a tooling upgrade, and it is exactly why it must not be folded into a behaviour-preserving migration. Re-run `npm audit` and record the new totals on this page.
2. **Group A, served libraries.** This is a frontend framework programme, not a dependency bump: AngularJS 1.x has no patched release. Treat it as such and scope it deliberately. `crypto-js` and `sockjs-client` should be pulled forward from it and handled first, because both are reachable and both have a published later line — `crypto-js` 4.2.0 fixes the Critical PBKDF2 finding directly.
3. **Deployed surface.** The assembled deployment currently carries the complete `node_modules` tree, because `config/env/all.js` and two application source files resolve runtime paths inside it. Narrowing the deployment to only the referenced package subtrees is a worthwhile reduction, but it requires enumerating those paths exhaustively and is a change to a property list the migration plan freezes; it is recorded here rather than attempted.
4. **Duplicate installs.** The registry copies `node_modules/angular` 1.8.2, `node_modules/jquery` 3.5.1 and `node_modules/moment` 2.29.1 sit alongside the `@bower_components` copies that the asset layout actually uses (`angular` 1.4.14, `jquery` 2.1.4, `moment` 2.10.6). **Verified: the only non-`@bower_components` package roots referenced by `config/env/all.js` are `angular-aria`, `angular-bootstrap-contextmenu`, `angular-bootstrap-nav-tree`, `angular-moment-picker` and `bootbox`, and the only `node_modules` paths in application source point at `@bower_components/videogular-themes-default` and `@bower_components/pdf.js-viewer`.** That makes the three registry copies look unreferenced, and removing them would drop their advisories. They were **not** removed here, because "no path references it" is a weaker proof than the one used for the five packages above — an AngularJS module could resolve one lazily, and a peer dependency could require it — and a weaker proof is not enough to change a served library's graph. Confirm by exhaustive reference analysis, then remove.
5. **Continuous measurement.** Add `npm audit` to the pipeline as a reporting step with a recorded baseline, so the totals on this page are re-measured rather than re-asserted, and so a *new* advisory is distinguishable from an accepted one.

## Risk acceptance

The 71 remaining advisories are **accepted for this change set**, on these terms:

- The acceptance is scoped to the migration. It is not an assessment that the graph is safe; it is a statement that reproducing it exactly was the migration's requirement and that changing it was forbidden by four separate rules named above.
- The residual exposure is predominantly **XSS and prototype pollution in an end-of-life browser framework**, plus **weak key derivation in `crypto-js`** and a **superseded SockJS client**. The first requires a framework programme; the second and third have published later lines and should be taken first.
- No advisory was silenced, suppressed or excluded from the audit. There is no `.npmrc` audit-level override and no `npm audit` allowlist in this repository; the numbers above are the raw output.
- **24 of the remaining direct findings have no upstream fix at all**, which is the condition the review's own resolution anticipated when it asked for exceptions to be documented where no fix exists.

## Reproducing every figure on this page

```bash
cd acm-standard-applications/arkcase/src/main/webapp/resources
nvm use 20                       # Node 20.20.2, npm 10.8.2

npm ci                           # restores exactly 401 packages from the committed lockfile
npm audit                        # 71 advisories: 15 critical, 26 high, 27 moderate, 3 low
npm audit --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["metadata"])'

npm run build                    # the unchanged Grunt default task graph
sha256sum assets/dist/application.js assets/dist/application.min.js \
          assets/dist/vendors.min.js assets/dist/application.min.css home.html
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
