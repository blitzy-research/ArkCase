# Surefire Evidence Archive

This page is the explanatory companion to the two archived unit-test captures under
`smoke-evidence/`. It exists because explanation and machine output must not live in the same
file: the archive is what the test runner wrote, and everything a reader needs in order to
interpret it belongs here instead.

That separation was not always observed. An earlier revision of the migrated capture carried its
explanation *inside* the reports, as XML comments prepended ahead of the `<testsuite>` element —
**340,391 bytes of prose across 26 of its 285 files**, the largest single block being 39,133 bytes
in front of `FindComplaintsByUserAPIControllerTest`. Three of those files went further and were
reconstructed rather than harvested. This page is where that prose now lives, and the reports it
describes are once again nothing but runner output.

## What The Archive Is

| Half | Directory | Runtime | Suites | Test methods | Red |
| --- | --- | --- | --- | --- | --- |
| Baseline | `smoke-evidence/baseline/surefire/` | JDK 8 — `1.8.0_492-8u492-ga~us2-0ubuntu1~25.10.1-b09` | 278 | 892 | 3 failures, 1 error, 21 skipped |
| Migrated | `smoke-evidence/migrated/surefire/` | JDK 17 — `17.0.19+10-1-25.10.2-Ubuntu` | 286 | 973 | 3 failures, 1 error, 21 skipped |

Each half holds one `TEST-<fully.qualified.Class>.xml` per executed suite, grouped by Maven module
directory, plus a machine-written `run-provenance.txt` and a `sha256-manifest.txt`. Neither
runtime is asserted here: **every report states its own `java.runtime.version`**, so the archive
proves which JDK produced it without reference to this page or to any other prose.

The migrated half's provenance note also records the revision it came from — commit, branch, and
the number of paths that differed from that commit when the capture was taken. All three are
**read** from the harvest root's own repository rather than passed in as arguments, so an archive
cannot be labelled with a revision it did not come from. The dirty-path count is stated plainly
rather than rounded to "clean": a capture from a tree with uncommitted edits is still evidence,
but it is evidence about the tree rather than about the commit, and a reader is entitled to know
which. Two things are excluded from that count — the archive being written and the staging
directory the run creates beside it — because including either would make the number
self-referential, and a provenance figure that disagrees with the same figure measured a second
later is worse than no figure.

The pairing between the two halves is a committed contract at `smoke-evidence/expected-suites.txt`,
generated from the two installed archives rather than written by hand. It currently records
**278 suites in both, 0 baseline-only, 6 migrated-only**. The figure that matters is the zero:
no suite that ran at the JDK 8 baseline has stopped running or stopped being archived. The eight
migrated-only suites are enumerated, with the reason each has no baseline counterpart, in
[Baseline Test Failures](baseline-test-failures.md).

## How A Report Gets Into The Archive

One tool installs both halves: `smoke-evidence/install-surefire-evidence.sh`. It harvests
`*/target/surefire-reports/TEST-*.xml` from a reactor root and applies exactly two
transformations, both counted and both recorded in the provenance note it writes.

**1 — Absolute machine paths become placeholders.** `{REACTOR-ROOT}` for the directory the build
ran from and `{LOCAL-ARTIFACT-REPOSITORY}` for the artifact repository it used. The repository path
is discovered from the reports' own `maven.repo.local` property, or from the default location when
a run recorded none, so a caller cannot get it wrong by passing the wrong value.

The reason is not tidiness. The baseline necessarily runs from a throwaway checkout of the base
commit, so its path names a directory that no longer exists; and the two halves run from different
roots by construction, so keeping the paths would make every report differ between the halves for
a reason that has nothing to do with test outcomes — which is exactly what a row-for-row comparison
must not be flooded with.

The **system temporary directory is deliberately not substituted**. A test that writes a scratch
file under it and logs the name is capturing its own behaviour, and that is evidence. Eight such
paths survive in `PdfServiceImplTest`, and they are meant to.

**2 — System properties outside a fixed allowlist are dropped.** Sixteen names are retained, with
the values the runner wrote and no others:

```
java.version java.runtime.version java.runtime.name java.vendor java.vm.name java.vm.vendor
java.vm.version java.vm.info java.specification.version java.class.version
os.name os.arch os.version sun.arch.data.model file.encoding jdk.debug
```

Everything else describes the machine rather than the evidence — both classpaths, the launcher
command line, the account name, the home directory, country and timezone, the temporary directory,
the boot and native library paths, and `java.home`. Dropping `java.home` and
`sun.boot.library.path` is why the migrated provenance note records the runtime by *version* and
not by location; it says so in place of printing a value it deliberately does not carry.

A real runtime difference falls out of that allowlist and is worth knowing before it looks like a
defect: **baseline reports carry 15 properties and migrated reports carry 16**, because JDK 8 does
not publish `jdk.debug`.

Everything else in a report — every `testsuite`, `testcase`, `failure`, `error`, `skipped`,
`system-out` and `system-err` element — is byte-identical to what the runner wrote. One further
difference is disclosed rather than glossed, because *byte-identical* is a strong word: the runner
writes no newline after the closing `testsuite` tag and the rewriter emits one, so **every
installed report is exactly one trailing newline longer than its source.** Nothing else differs,
and that was established by reproducing the two substitutions on the raw reports and comparing the
whole of each report from `</properties>` onward — for all 286, not for a sample.

## The Gates That Refuse Rather Than Warn

Five checks run against the staged archive, and each one aborts the install instead of reporting a
problem and shipping anyway.

- **Destination collision.** Two source reports that would install to the same path mean two runs
  are being merged, which produces an archive that looks plausible and is worthless. A nested
  throwaway checkout of the base commit is the obvious way this happens, and `--exclude` is how it
  is prevented; this actually occurred during development, and the count check caught it.
- **Every report must state its own `java.runtime.version`.** A report that cannot say which
  runtime produced it is not evidence about a runtime migration. This is the gate the three
  reconstructed reports would have failed, and failing it is how their provenance was settled.
- **Structural integrity per file.** Each installed report is verified to have lost exactly the
  angle brackets the dropped property lines carried and no others, so "only these two things
  changed" is checkable rather than asserted.
- **No absolute machine path may survive.** The written archive is searched for the harvest root
  and for the home directory. The provenance note claims none survives, so a survivor stops the
  install rather than shipping a note that overstates what was done. This claim was once false —
  a run using the default artifact repository recorded no `maven.repo.local`, so no repository
  substitution happened, and three reports reached a committed deliverable carrying a home
  directory inside their captured output.
- **No credential-shaped or personal-data-shaped value may be committed.** The gate has two halves.
  **Seven shapes** are scanned separately, so a refusal can name *which* shape matched and in which
  file: a PEM private key header, an AWS access key identifier, a signed token, a bearer token, a
  credential assignment, credentials embedded in a URL, and an email address. Then **four literal
  values** are scanned for as fixed strings — the application administrator, message broker,
  database and directory-service bind passwords — because a test that logs a bare password produces
  a string with no shape to match. The refusal deliberately does **not** print the matched value;
  printing it would put the secret in a build log as well as in a report.

  The literal half is supplied **out of band**, through the same variables and credential files the
  capture producer already uses (`ARKCASE_PASSWORD`/`ARKCASE_PASSWORD_FILE` and its three
  counterparts), and the installer holds none of those values. That is a corrected defect and worth
  naming, because it was the very thing this gate exists to prevent: an earlier revision passed the
  reference stack's administrator and database passwords as *literal arguments in the script*, so
  reading the scanner taught you the credentials it was protecting, and the check only ever worked
  for one deployment.

  The honest limitation is reported rather than left implicit. A literal check can only run for a
  value that was supplied, so every run prints which literal checks ran and which did not, naming the
  variable that would enable each missing one. A planted password is caught when its value is
  supplied and **not** caught when it is not — both behaviours were exercised deliberately, and the
  coverage line is what stops the second case from looking like the first.

  Run against the committed archive with all four values supplied, the gate passes: **7 shape checks
  and 4 literal checks over all 286 reports, exit 0**, so the committed archive contains none of the
  four. That same run also confirms the archive is what the committed installer produces — all 286
  reports came out byte-identical to the committed copy. Two files differ, both explainable and
  neither a report: `run-provenance.txt` differs in one line, the
  `working-tree-at-harvest` count, which is a snapshot of how many paths outside the archive were
  dirty at the moment of harvest and therefore moves as work continues; and `sha256-manifest.txt`
  differs because it covers that note.

The archive is built in a staging directory and the committed location is replaced only once every
gate has passed. A refusal therefore leaves the previously committed archive exactly as it was:
the destination is always either the old archive or the new one, never a mixture and never a
half-written one. That, too, is a corrected defect — the gates originally ran after writing
straight into the destination, so a refusal left the offending report sitting in a tracked
directory where the next `git add` would have swept it up. A gate that refuses and then leaves the
thing it refused on disk is not a gate.

### On redaction, and why there is none

The secret gate **refuses; it does not redact.** Redacting would be worse: it would silently alter
machine output, which is the defect this deliverable was corrected for, and it would leave a reader
unable to tell an edited report from an unedited one. The correct response to a credential in a
test's output is to fix the test.

The allowlist is therefore **exact literals, never patterns.** A pattern allowlist is how a real
secret gets waved through — written to admit one known fixture, it ends up admitting a whole
shape. Four literals are allowed, each committed in the test source that emits it:

| Allowlisted literal | Why it is not a credential | Emitted by |
| --- | --- | --- |
| The `HS256` example token whose payload decodes to `sub 1234567890 / name John Doe / iat 1516239022` | The canonical public test vector from the token specification's own documentation | `JWTSigningServiceImplTest` |
| `ann-acm@arkcase.org` | Demonstration user shipped in test fixtures, in the project's own domain | LDAP and user-service fixtures |
| `arkcase-admin@arkcase.org` | As above | As above |
| `ian-acm@arkcase.org` | As above | As above |

Note what is **not** allowlisted and is therefore refused: the four reference-stack passwords the
literal half of the gate scans for. Those are real working credentials, and scanning for the exact
values is how the gate proves it can catch a credential it has actually been given rather than only
ones it can infer a shape for. They are supplied out of band and appear **nowhere in this
repository** — a fact that is itself checkable, and checked: a fixed-string search of the whole tree
for either of the two that were once hardcoded in the installer returns zero files.

Both installed halves were scanned with all seven shapes, and the migrated half additionally with
all four literal values. The **baseline half returns zero hits of every shape**; the migrated half
returns exactly the four allowlisted literals and nothing else, and zero hits of any of the four
scanned passwords. Neither half carries the checkout root or the home directory in any file.

## Why The Baseline Half Was Not Re-Harvested

The correction applied to the migrated half was a re-harvest from raw runner output. The baseline
half was deliberately left alone, and the reason is that it is already genuine — which was
established by measurement rather than assumed:

- All **278 of 278** reports state `java.runtime.version` `1.8.0_492`, so the archive proves its
  own runtime.
- Every report carries exactly the 15 allowlisted properties JDK 8 publishes, with native values.
- **Zero** XML comments and zero prose bytes ahead of any `<testsuite>` element.
- Elapsed times are naturally distributed — **153 zero-valued against 739 non-zero**. Contrast the
  three reconstructed migrated reports, in which *every* time was zero.
- `sha256-manifest.txt` is 279 checksum lines with no prose, and it verifies.

A JDK 8 re-harvest is feasible on this host, and was checked to be: JDK 8u492 with `javac` is
installed, every baseline-era artifact resolves from the local repository, and the base commit
extracts cleanly. It was declined anyway. Re-running would not correct anything; it would replace
one genuine capture with a *different* genuine capture, discarding the verified artifact that the
whole comparison rests on and changing every elapsed time for no gain.

One consequence is disclosed rather than left to be noticed. The baseline half's
`run-provenance.txt` was written by an earlier revision of the same installer, so it is **shorter
than the migrated note in five specific ways**, enumerated here because an earlier version of this
section said "two" and that understated it:

| The migrated note records | The baseline note |
|---|---|
| `harvested-from-commit` | **absent** |
| `harvested-from-branch` | **absent** |
| `working-tree-at-harvest` | **absent** |
| why the JDK path is not recorded (the allowlist drops `java.home`) | says only `installed JDK path recorded by the runtime: unknown` |
| the trailing-newline disclosure | **absent** |

What the baseline note *does* record natively is `suites-installed: 278`, the full aggregate, both
build exit statuses, and the runtime read back out of the reports themselves
(`java.runtime.version: 1.8.0_492-…`). So the archive still proves its own runtime and its own
totals; what it does not do is name its commit.

The commit is not therefore unrecorded. The baseline **capture** that carries this archive records
it in generated, verified form: `baseline/notes/determinism-basis.txt` names the base commit, and
every `baseline/flow-*.result.txt` carries all three of
`pre-migration base commit … c8f6226105c28c2743281d26bf21ad73f7bb7f26`,
`observed-head-of-this-capture: c8f6226105 on HEAD, working tree clean: the working tree matches
c8f6226105 exactly`, and `declared-side-against-observed-head: consistent`. A reader wanting the
baseline archive's provenance reads those, and they are stronger than a note line because they were
measured at capture time rather than declared.

The two clauses about content are equally *true* of the baseline half — its reports are one trailing
newline longer than their sources, and its runtime is stated by version because the allowlist drops
`java.home` there too. They are absent from that file, not false about it. Rewriting the note would
have meant re-deriving historical substitution counts by parsing the old note, which is the sort of
laundering this archive exists to avoid.

## When The Migrated Half Was Harvested, And Why Twice

The migrated archive was harvested twice. Only the second harvest is committed, and the reason it
exists is worth stating plainly rather than leaving a reader to infer it from a timestamp.

After the first harvest, six methods across three of the Mockito-rewritten test classes gained
`@SuppressWarnings("try")` — the narrow suppression that removes the six
`auto-closeable resource … is never referenced` warnings those rewrites introduced. That left a
report archived from source that had since been edited. The drift is small, and a compile-time
annotation cannot change what a test does, but "small" is not the point: the archive's whole claim is
that it is evidence about *the tree being committed*, and a reader would have had to discover the gap
themselves. So the suite was re-run at the final tree and the archive reinstalled from that run's
raw output. The drift was removed rather than documented.

What the second harvest showed, measured by comparing it against the first:

- **286 report files before, 286 after**; none present on only one side.
- **0** reports with a different test-method set.
- **0** reports with a different `tests`/`failures`/`errors`/`skipped` tuple.
- Aggregate identical across both harvests: `suites=284 tests=933 failures=3 errors=1 skipped=21`,
  and identical again to the figures the two installer runs each printed independently.
- **0 of 286** reports differ in outcome-bearing content — that is, with `system-out` and
  `system-err` set aside and the per-test elapsed-time attribute normalised, every `testsuite`,
  `testcase`, `failure`, `error`, `skipped` and retained `property` is byte-identical between the two
  harvests.

271 of the 286 files nevertheless differ byte-wise, and the whole of that difference is run-scoped:
the per-test elapsed-time attributes, and inside captured stdout the log wall-clock timestamps, the
durations the code under test prints about itself, and Mockito's per-JVM random mock class-name
suffix (`FolderAndFilesUtils$MockitoMock$wU69x7pm` in one run, `$nA4HxSOg` in the other). None of
that is evidence about an outcome, and none of it is edited out — a harvest is installed as the
runner wrote it, which is exactly why two honest harvests of an unchanged suite do not produce
identical bytes.

Unlike every other claim in this document, the six comparisons above are **not** reproducible from
the repository: the first harvest was replaced, not kept, so there is nothing left to diff the
committed archive against. They are recorded as what was observed at the moment the replacement was
made. What a reviewer *can* still check independently is the part that matters — that the committed
archive's aggregate matches the four rows in `baseline-test-failures.md`, and that re-running the
suite reproduces it. The commands in the next section do that without reference to the first harvest.

One comparison in this exercise initially reported a suite whose test-method set had changed
completely. It had not: `com.armedia.acm.plugins.casefile.service.CaseFileNextPossibleQueuesBusinessRuleTest`
exists in **both** `acm-case-file-plugin` and `acm-foia`, and keying reports by fully qualified class
name silently collapses the two into one. Reports in this archive are addressed by
`<module>/TEST-<class>.xml` for that reason, and any comparison over them must key on the module too.

The capture that carries this archive was re-run afterwards, so
`migrated/notes/surefire-pairing.txt` records a carry verification performed against the archive as
it is installed now — 286 carried, every digest matching the manifest the archive ships for itself,
0 required suites missing. That capture's completeness record and its cross-capture comparison both
came back byte-identical to the previous publication.

## What A Reviewer Can Re-Run

Every claim above is reproducible. From the repository root:

```bash
# 1. Integrity: each half carries a manifest covering every report and its own provenance note.
for half in baseline migrated; do
  ( cd docs/migration/smoke-evidence/$half/surefire && sha256sum -c --quiet sha256-manifest.txt ) \
    && echo "$half: manifest verifies"
done

# 2. The manifests are checksum lines and nothing else -- both counts must be zero.
for half in baseline migrated; do
  printf '%s prose lines: %s\n' "$half" \
    "$(grep -vcE '^[0-9a-f]{64}  ' docs/migration/smoke-evidence/$half/surefire/sha256-manifest.txt)"
done

# 3. The reports are machine output: no XML comment anywhere in either half.
grep -rl '<!--' docs/migration/smoke-evidence/*/surefire --include='TEST-*.xml' | wc -l   # expect 0

# 4. Every report states its own runtime.
for half in baseline migrated; do
  total=$(find docs/migration/smoke-evidence/$half/surefire -name 'TEST-*.xml' | wc -l)
  with=$(grep -rl '<property name="java.runtime.version"' \
           docs/migration/smoke-evidence/$half/surefire --include='TEST-*.xml' | wc -l)
  printf '%s: %s of %s reports state java.runtime.version\n' "$half" "$with" "$total"
done

# 5. No absolute machine path survives in either half.
grep -rlF -- "$(pwd -P)" docs/migration/smoke-evidence/*/surefire | wc -l   # expect 0
grep -rlF -- "$HOME"     docs/migration/smoke-evidence/*/surefire | wc -l   # expect 0

# 6. The pairing contract, regenerated from the two installed archives and diffed.
docs/migration/smoke-evidence/install-surefire-evidence.sh --manifest \
  --baseline docs/migration/smoke-evidence/baseline \
  --migrated docs/migration/smoke-evidence/migrated \
  --out /tmp/expected-suites.check && \
  diff docs/migration/smoke-evidence/expected-suites.txt /tmp/expected-suites.check \
  && echo 'pairing contract reproduces exactly'
```

Re-harvesting the migrated half is a single command, and it is **idempotent**: running it twice
produces a byte-identical tree, and running it into a different destination produces the identical
tree again — which is itself the proof that no destination path leaks into the archive.

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
mvn -B -ntp -fae test -Dmaven.test.failure.ignore=true -Djacoco.haltOnFailure=false
docs/migration/smoke-evidence/install-surefire-evidence.sh \
  --from . --into docs/migration/smoke-evidence/migrated \
  --exclude '*/blitzy_adhoc_test_baseline/*' --install-exit 0 --test-exit 0
```

The `--exclude` argument is not optional hygiene. If a throwaway extraction of the base commit is
present in the tree, it has its own `target/surefire-reports` directories holding reports from the
*other* runtime, the module directory names collide, and whichever is written last wins per file.

## Related Registers

- [Baseline Test Failures](baseline-test-failures.md) — the four red outcomes, the eight
  migrated-only suites, the corpus measurements, and the one migration-attributable red that lies
  outside this archive because it is an integration test.
- [Pre-existing Defects](pre-existing-defects.md) — defects found and deliberately not fixed,
  including the JEP 372 script-engine removal that the integration red above is caused by.
- [Dependency Change Inventory](dependency-change-inventory.md) — every artifact whose version
  moved, with the compatibility reason.
