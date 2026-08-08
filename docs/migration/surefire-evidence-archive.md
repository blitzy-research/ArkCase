# Surefire Evidence Archive

This page is the explanatory companion to the two archived unit-test captures under
`smoke-evidence/`. It exists because explanation and machine output must not live in the same
file: the archive is what the test runner wrote, and everything a reader needs in order to
interpret it belongs here instead.

That separation was not always observed, and the scale of the lapse is stated here as a measurement
rather than as an impression. Two successive revisions carried their explanation *inside* the reports,
as XML comments ahead of the `<testsuite>` element. Prose is measured below as the total size of the
XML comment nodes themselves, `<!--` through `-->` inclusive, which is the one definition a reader can
reproduce without guessing what was counted:

| Revision | Reports | Carrying authored comments | Prose bytes | Largest single block |
|----------|---------|---------------------------|-------------|----------------------|
| `c24e049e28` | 285 | 26 | 348,821 | 39,131 in `FindComplaintsByUserAPIControllerTest` |
| `0e13c8620d` (the revision this checkpoint replaced) | 284 | 8 | 32,482 | 9,433 in `SmtpServiceTest` |

Counting both halves of the archive, the revision this checkpoint replaced had **ten reports that were
no longer purely runner output**: the eight migrated reports above, one further migrated report
(`FolderDocumentCountAPIControllerTest`) that had been edited without leaving a comment behind, and one
baseline report (`EcmFileServiceImplTest`) that carried a comment of its own. **All ten are now clean on
both sides**, which is checkable in one line:

```bash
grep -l '<!--' docs/migration/smoke-evidence/{baseline,migrated}/surefire/*/TEST-*.xml | wc -l   # 0
```

This page is where that prose now lives, and the reports it describes are once again nothing but runner
output. A gate in the installer now refuses to publish an archive in which any report contains a
comment, so the lapse cannot recur silently.

## What The Archive Is

Every figure in this table is read out of the installed archive rather than transcribed, and
`smoke-evidence/report-inventory.txt` is the machine record that produces it.

| Half | Directory | Runtime | Suites | Test methods | Red |
| --- | --- | --- | --- | --- | --- |
| Baseline | `smoke-evidence/baseline/surefire/` | JDK 8 — `1.8.0_492-8u492-ga~us2-0ubuntu1~25.10.1-b09` | 278 | 892 | 3 failures, 1 error, 21 skipped |
| Migrated | `smoke-evidence/migrated/surefire/` | JDK 17 — `17.0.19+10-1-25.10.2-Ubuntu` | 279 | 893 | 3 failures, 1 error, 21 skipped |
**A counting hazard, stated once so no figure on this page repeats it.** Each half's directory holds
its suite reports *plus* two control files — `run-provenance.txt` and `sha256-manifest.txt` — and both
halves additionally hold a `notes/` directory. Counting directory entries therefore yields more than
the suite count, and an earlier revision of this page published a suite figure arrived at that way.
**Suite counts on this page count `TEST-*.xml` files and nothing else**: 278 baseline and 279
migrated are numbers of suites, the directory holds more files than that, and the two are never used
interchangeably.

Each half holds one `TEST-<fully.qualified.Class>.xml` per executed suite, grouped by Maven module
directory, plus a machine-written `run-provenance.txt`, a `sha256-manifest.txt` and a `notes/`
directory. Neither runtime is asserted here: **every report states its own `java.runtime.version`**,
so the archive proves which JDK produced it without reference to this page or to any other prose.

The three files under the two `notes/` directories are the archive's only authored prose, and they
sit **beside** the module directories, never inside one — a module directory admits report XML and
nothing else. None of the three is covered by a `sha256-manifest.txt`: the reports are the evidence
and are digest-bound, while the notes are reading guidance about them and carry no figure that is
not re-derivable from the reports. `notes/report-reading-notes.txt` in each half holds the
per-report disclosures a reader needs in order to cite particular reports correctly;
`baseline/surefire/notes/property-allowlist-line-continuation.txt` registers one pre-existing
defect in the property-dump filter.

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

### Five producers name different commits, and that is not five captures

This archive is one of five independent producers of migration evidence, and each records the
commit **its own** producer ran at: this archive's `run-provenance.txt`, the smoke capture's
`notes/capture-provenance.txt`, the startup gate's `startup/startup.status`, the frontend
adjudication's `artifacts/diff-result.txt`, and the before-and-after experiments' own provenance
blocks. They necessarily run at different times — two of them cannot run at all until both capture
sides are on disk — so they name different commits, and a reader meeting several hashes is entitled
to ask whether the evidence describes one state of the repository or several.

That question is answered by measurement rather than by this paragraph.
`smoke-evidence/verify-evidence-identities.sh` collects every commit cited anywhere under
`docs/migration/`, full or abbreviated, labelled or not; resolves each one; and reports its
reachability from the head and the number of files **outside `docs/`** that differ between it and
the head. It writes `smoke-evidence/identity-index.txt` and is **fail-closed on the property that
separates a good citation from a bad one**: it exits non-zero if any cited identity fails to resolve
or resolves ambiguously. The current index records **17 cited commits, every one resolving and none
ambiguous**, alongside one blob — content identity, which is stronger than a revision because it
names the bytes rather than a tree containing them — verified as a blob rather than failed for not
being a commit.

**Reachability and the non-documentation difference are reported per commit rather than folded into
that verdict, and the shape of the delivery is why.** This work is delivered as one consolidated
commit, so the intermediate states the five producers ran at are not ancestors of the commit that
carries their output. The index measures that directly: **9 of the 17 cited commits are reachable
from the delivered head and 8 are not**, and the non-documentation difference is nowhere zero — 8
files at the smallest, 21 for most of the rows, and 5127 for the single pre-migration revision a
sibling document cites for line anchors. Both of those follow mechanically from consolidating the
history, so requiring either would make this gate fail on every delivered tree, which would tell a
reader nothing about the evidence. What the gate does still refuse to let past is the failure mode
that matters: a hash transcribed wrongly, invented outright, or abbreviated so far that it names two
objects. A reader wanting an anchor that lives inside the published history should use the declared
base commit `c8f6226105c28c2743281d26bf21ad73f7bb7f26`, which the index records as reachable and
whose 62-file non-documentation difference against the head **is** the migration change set this
archive exists to measure.

The pairing between the two halves is a committed contract at `smoke-evidence/expected-suites.txt`,
generated from the two installed archives rather than written by hand. It currently records
**278 suites in both, 0 baseline-only, 1 migrated-only**. The figure that matters is the zero:
no suite that ran at the JDK 8 baseline has stopped running or stopped being archived. The single
migrated-only suite is enumerated, with the reason it has no baseline counterpart, in
[Baseline Test Failures](baseline-test-failures.md).

**That figure was 6 before this checkpoint, and the drop is a scope correction rather than a lost
suite.** Five of the six were reports for test classes the migration had added outside the plan's
enumerated file list — four LDAP context-source tests and one Angular wiring test. Those classes are
removed, so the suites no longer exist to archive on either side, and the archive's own generator
reports the new figure rather than being told it.

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
whole of each report from `</properties>` onward — for all 279, not for a sample.

## The Gates That Refuse Rather Than Warn

Nine checks run, and each one aborts instead of reporting a problem and shipping anyway. Six run
against the staged archive at install time; three were added after a review found that a write-time
check, however strict, cannot see what happens to an archive afterwards.

- **A dirty working tree is refused outright.** An earlier revision of this archive recorded
  *"7 path(s) OUTSIDE this archive differed from the commit above"* as a footnote and was then read
  as evidence about a commit, which it was not. The harvester now refuses to run against a dirty
  tree, and `--allow-dirty` is the deliberate opt-in: it proceeds, and it enumerates **every**
  differing path with the blob hash of its working-tree content, so the state the run saw can be
  reconstructed exactly rather than counted.
- **The harvest commit must resolve in this repository.** The commit is looked up with
  `git cat-file -e` and the answer is recorded either way. An earlier revision named a commit this
  repository does not contain — provenance that reads as authoritative and cannot be checked is
  worse than none, because a reader has no way to tell which of the two it is holding.
- **Destination collision.** Two source reports that would install to the same path mean two runs
  are being merged, which produces an archive that looks plausible and is worthless. A nested
  throwaway checkout of the base commit is the obvious way this happens, and `--exclude` is how it
  is prevented; this actually occurred during development, and the count check caught it.
- **Every report must state its own `java.runtime.version` AND its own `java.class.version`.** A
  report that cannot say which runtime produced it is not evidence about a runtime migration, and
  the class-file version is the property that actually distinguishes the two runtimes this evidence
  compares — 52.0 against 61.0 is the whole migration in one attribute. Only the first of the two
  was checked before, and a register consequently published a 284-of-284 class-version count the
  archive did not support.
- **Every report must carry the time attribute the runner writes on its testsuite element.** This is
  the structural fingerprint an authored report cannot supply and does not think to fake. It is
  present in every baseline and every migrated report — 278 and 279 as the archives now stand, 284 on
  the migrated side when this check was written — and was absent from exactly the four that had been
  substituted, which is what makes it the discriminating check.
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

  Run against the committed archive, the gate passes: **7 shape checks over all 279 reports, exit 0**,
  with the administrator-password and database-password literal checks also supplied and clean. The
  two remaining literal checks — the broker and directory-service bind passwords — are named as not
  run rather than silently skipped, which is the whole point of the coverage line.

  **A sixth gate was added at this checkpoint, and it is the one that closes an authenticity defect
  rather than a leak.** The install now refuses to publish an archive in which any report contains an
  XML comment. The runner writes none, so a comment can only have been authored — and a previous
  revision of this archive carried hand-written provenance prose inside nine reports while the note
  beside them stated that nothing had been authored. The gate refuses rather than strips, so the
  operator moves the prose to where prose belongs instead of having it silently discarded.

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
- `sha256-manifest.txt` carries checksum lines and no prose, and it verifies.

The third bullet was **temporarily false and has been made true again**; the episode is recorded
below under *A Later Revision Broke This, And What Restored It*, because a claim that was falsified
and then repaired is worth more to a reader than one that only ever appears to have held.

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
it in generated, verified form: `baseline/env/toolchain.txt` names the base commit alongside the
producer digest and the repository state observed at capture time, and
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

## When The Migrated Half Was Harvested, And Why Three Times

The migrated archive has been harvested three times. Only the third is committed, and each
replacement is stated rather than left to be inferred from a timestamp, because an archive whose
history is unexplained is an archive a reader has to take on trust.

**Harvest 1 → 2.** After the first harvest, five methods across two of the Mockito-rewritten test
classes gained `@SuppressWarnings("try")` — the narrow suppression that removes the
`auto-closeable resource … is never referenced` warnings those rewrites introduced. That left an
archive taken from source that had since been edited. A compile-time annotation cannot change what a
test does, but the archive's whole claim is that it is evidence about *the tree being committed*, so
the suite was re-run at the then-final tree and the archive reinstalled from that run's raw output.

All five are still in the tree and this checkpoint did not touch them:
`CalendarEntityHandlerTest` lines 230 and 332, and `AcmObjectLockServiceImplTest` lines 142, 185 and
223. **A previous revision of this section said six methods across three classes, and that was never
true of any commit** — the annotation has stood at five sites in two files since it was introduced,
which `git grep -c 'SuppressWarnings("try")' <rev> -- '*.java'` confirms at every revision from that
commit to this one. The figure is corrected here rather than quietly dropped, because a roll-up that
overstates its own scope is the same defect as one that understates it.

One nearby method might be expected to carry the suppression and deliberately does not.
`QueuePropertyFileChangeWatcherTest` closes its construction mock in an explicit `finally` block
rather than through try-with-resources, so no warning is raised there and nothing needs suppressing.
That shape was chosen at this checkpoint precisely so the count would not have to grow.

**Harvest 2 → 3, this checkpoint.** Two things about the second harvest made it stale, and one of
them made it inadmissible.

- *Stale.* Six source files changed after it: three test classes whose added assertions were removed,
  one test class that gained the scoped static log-manager mock, the LDAP context source, and its
  Spring configuration. Five test classes created outside the plan's file list were deleted
  altogether, so the second harvest archived five suites that no longer exist.
- *Inadmissible.* Eight of its reports carried hand-authored XML comments — provenance prose written
  into the runner's own output — while `run-provenance.txt` beside them stated in its first paragraph
  that the reports "were not authored, not derived from test source, and not reconstructed from a
  build log". The prose was not false. The defect is that a reader could no longer tell which bytes
  came from the runner, which is precisely the property this archive exists to have. A ninth migrated
  report, `FolderDocumentCountAPIControllerTest`, had been edited without leaving a comment behind,
  and a tenth affected report sat in the baseline half. And the note recorded a
  `harvested-from-commit` value naming a revision produced in a scratch clone whose history was never
  published, so no branch in this repository reaches it and the archive could not be tied to any tree a
  reader could inspect. The hash itself is deliberately not reproduced here: an identity nobody can
  resolve is not evidence, and every hash this deliverable does print is required to **resolve** —
  which is what `smoke-evidence/verify-evidence-identities.sh` enforces and
  `smoke-evidence/identity-index.txt` records, alongside a reachability column it reports rather than
  requires. The distinction is the whole point of the defect: an invented hash resolves to nothing at
  all, whereas a real producer commit that a consolidated delivery leaves outside the delivered
  commit's ancestry resolves perfectly and simply is not an ancestor. The third harvest's own values
  are measured, not asserted:

  ```bash
  for side in baseline migrated; do
      c=$(sed -n 's/^harvested-from-commit: //p' \
          docs/migration/smoke-evidence/$side/surefire/run-provenance.txt)
      git cat-file -e "$c^{commit}" || { echo "$side DOES-NOT-RESOLVE"; continue; }
      if git merge-base --is-ancestor "$c" HEAD
          then echo "$side $c resolves, reachable"
          else echo "$side $c resolves, NOT-REACHABLE (consolidated delivery)"
      fi
  done
  ```

  Both resolve. The baseline half names the declared base commit, which is reachable; the migrated
  half names an evidence commit that the consolidated delivery leaves unreachable. Neither is the
  defect this entry closed — that one resolved to nothing whatsoever.

The third harvest replaces it wholesale, from a full `mvn clean install -DskipTests` followed by
`mvn -fae test` on JDK 17, and it fixes all four problems at once. It is measured, not asserted:

- **279 suites, 893 tests, 3 failures, 1 error, 21 skipped** — the installer's own aggregate,
  reproducible with the commands in the next section.
- **`harvested-from-commit: d9f2dc0f7da1267d23bb5387ccac115f5667d3c3`**, which resolves, and
  **`working-tree-at-harvest: clean`** — every file outside the archive tracked and unmodified, so
  this archive is evidence about a commit rather than about a working tree.
- **Zero XML comments** in any of the 279 reports, enforced by the new gate rather than by inspection.
- The four red outcomes are the same four the baseline register carries: three failing methods in
  `FileDownloadAPIControllerTest` and one erroring method in `FolderCompressorTest`. **No failure in
  this run lacks a baseline register row**, which is the zero-regressions statement expressed as a
  comparison rather than as a claim.

**The harvest commit and the delivered commit are not the same commit, and the difference is documentation only.** `run-provenance.txt` records the commit the suite actually ran at, which is the only honest thing for it to record; work on this page and on the registers beside it continued afterwards. So that a reader does not have to take the distinction on trust, it is stated as a check rather than as a reassurance — no file outside `docs/` differs between the two:

```bash
git diff --name-only $(sed -n 's/^harvested-from-commit: //p' \
  docs/migration/smoke-evidence/migrated/surefire/run-provenance.txt) \
  -- . ':(exclude)docs/**' | wc -l          # 0
```

A zero there is the property that matters: the archive is evidence about the delivered *source*, and the delivered source is byte-for-byte the source that produced it. Had that count been non-zero the archive would have had to be harvested again, which is what happened twice already.

**The baseline half was not re-harvested and cannot be**, for the reason set out in the section above;
its one annotated report was corrected in place instead, by a committed mode of the installer that
removes XML comments, proves the four aggregate counts unchanged, re-parses every document, rewrites
the digest manifest and writes the correction into the provenance note beside the claim it qualifies.
That correction is disclosed there in full: **1 report, 1 comment removed, 0 remaining, aggregate
`suites=278 tests=892 failures=3 errors=1 skipped=21` before and after.**

One finding from the harvest-comparison exercise is worth keeping because it is a trap rather than a
number. A comparison initially reported a suite whose test-method set had changed completely. It had
not: `com.armedia.acm.plugins.casefile.service.CaseFileNextPossibleQueuesBusinessRuleTest` exists in
**both** `acm-case-file-plugin` and `acm-foia`, and keying reports by fully qualified class name
silently collapses the two into one. Reports in this archive are addressed by
`<module>/TEST-<class>.xml` for that reason, and any comparison over them must key on the module too.

Two honest harvests of an unchanged suite do not produce identical bytes, and nothing in this archive
pretends otherwise: the per-test elapsed-time attributes, the wall-clock timestamps inside captured
stdout, the durations the code under test prints about itself and Mockito's per-JVM random mock
class-name suffix all move between runs. None of that is evidence about an outcome, and none of it is
edited out — a harvest is installed as the runner wrote it.

## The Read-Time Audit, And Why A Write-Time Check Was Not Enough

The install path verified every report as it wrote it, and it refused any report that could not
state its own runtime. It still shipped an archive containing four that could not — because they were
not written by it. They were **substituted afterwards**: 284 reports on disk, 280 carrying a native
`java.runtime.version`, and four replaced with hand-authored summaries whose own comments said their
test names were transcribed from source and their property dumps deliberately omitted, sitting beside
a provenance note that claimed every element was runner-byte-identical. No write-time gate can see
that, because by the time it happens the writing is over.

```
install-surefire-evidence.sh --audit docs/migration/smoke-evidence/migrated
```

Audit mode inspects an archive that already exists and asserts, over every installed report, a native
`java.runtime.version`, a native `java.class.version`, the runner's testsuite `time` attribute, a
`properties` element, non-emptiness, and a verifying checksum manifest. It exits non-zero and names
every failing file.

One design note, because the first draft of this check was wrong in a way worth recording. It searched
the prose for phrases like *"transcribed from"* and *"re-derived"*, and it failed twice over: it
accused two perfectly native reports whose explanatory comments happened to use those words, and it
would have been satisfied by an authored report that simply did not mention its own origin. A prose
check tests what a report **says**. The structural check tests what the runner **writes** — which is
the thing an author omits without noticing.

Run against the current archives, audit mode reports **279** inspected for the migrated half and 278
for the baseline half, with zero failures of any kind on either side.

## A Later Revision Broke This, And What Restored It

Everything above describes the archive as the installer produces it. A revision committed after that
description was written **edited ten report files by hand**, and the two claims this page makes most
insistently — zero XML comments, and provenance carried natively rather than in a comment — were false
for those ten from that moment until they were restored. The episode is recorded here rather than
erased, because the manifests were regenerated over the edited files, which meant `sha256sum -c`
authenticated the alteration instead of the run.

**What was done to them**, split by what the diff that damaged them actually shows rather than by how
they looked:

| Damage | Files | Consequence |
|---|---|---|
| An authored provenance comment prepended; report body untouched | 5 — one under `baseline/`, four under `migrated/` | The two claims above became false. Nothing outcome-bearing was lost. |
| Runner-written content replaced or truncated by authored text | 5, all under `migrated/surefire/acm-service-ecm/` | Two lost their entire native property block, so they no longer stated the runtime that produced them. Two lost runner attributes and `system-out`/`system-err` content, including a complete stack trace and a validator banner. One lost its only `testcase` element while its `testsuite` element went on declaring `tests="1"`. |

**What restored them.** All ten are byte-recoverable from commit `fc44276779`, whose tree carries both
archives in the form the installer installed them, and which — unlike the hash the migrated
`run-provenance.txt` used to name — is a real commit object: `git cat-file -e fc44276779^{commit}`
succeeds. The five comment-only files were restored by deleting the comment block, and the result was
compared against that source byte for byte and length for length *before* being written. The five
replaced files were restored whole, because there was no authored text to peel off — the authored text
was the file body.

**And a commit alone was not treated as sufficient.** Recovering bytes from a commit proves they were
once committed, not that a runner wrote them. So the five restored files were checked against a live
invocation of the runner on this host, on Java 17:

```bash
mvn -o -pl acm-services/acm-service-ecm,acm-services/acm-service-email-smtp test \
    -Dmaven.test.failure.ignore=true -Djacoco.haltOnFailure=false
```

It reported `BUILD SUCCESS`, and for all five the recovered report and the fresh report agree exactly
on the `tests`/`failures`/`errors`/`skipped` tuple, on the full set of `testcase` names, and on the
count of `system-out` and `system-err` elements. The only difference is the property count — 52 and 53
native against the 16 the allowlist retains — which is the documented normalisation, not a discrepancy.

**The state of both archives now, measured rather than asserted:**

| | Baseline | Migrated |
|---|---|---|
| reports | 278 | 279 |
| carrying a native `java.runtime.version` | 278 | 279 |
| carrying a native `java.class.version` | 278 | 279 |
| carrying any XML comment | 0 | 0 |
| prose bytes ahead of any `<testsuite>` | 0 | 0 |
| aggregate | `tests=892 failures=3 errors=1 skipped=21` | `tests=893 failures=3 errors=1 skipped=21` |
| `sha256-manifest.txt` entries | 283 = 278 reports + `run-provenance.txt` + 4 notes | 283 = 279 reports + `run-provenance.txt` + 3 notes |

The aggregate is **unchanged** by the restoration, which is the invariance witness: a text
transformation that leaves the four runner counters alone has demonstrably not altered a recorded
outcome. The three failures and one error are still the four rows in
[Baseline Test Failures](baseline-test-failures.md).

**The migrated figure moved from 284 / 933 to 279 / 893 for a separate reason, and it is a
withdrawal rather than a loss.** Five test classes created outside the file list the migration plan
authorises were withdrawn from the change set — the four Active Directory context-source tests and
the angular-starter wiring test — so the five archived reports that describe them were withdrawn with
them: a report for a class that exists nowhere in the tree is not evidence about this change set. The
four failure and error rows are untouched by the removal, no surviving report was edited, and both
`sha256-manifest.txt` files were regenerated over what remains and verify clean.
`migrated/surefire/run-provenance.txt` records the withdrawal in full alongside the as-harvested
284 / 933, and `smoke-evidence/<side>/notes/07-post-capture-supersession.txt` enumerates every figure
elsewhere in the capture that the withdrawal supersedes.

**Two structural changes came with the restoration**, both so the same failure cannot recur:

- The provenance the ten comments carried now lives in `surefire/notes/report-restoration.txt`, one
  per half, *outside* the runner XML.
- `sha256-manifest.txt` now covers everything under `notes/` as well as the reports and
  `run-provenance.txt`, and the installer was changed to generate it that way — so moving prose out of
  a manifested file did not make it editable without trace. On a fresh harvest the directory does not
  exist yet and contributes nothing, so a first-time install is unaffected.

**One published figure was wrong for a different reason and was corrected in the same pass.** This
page stated 286 migrated reports and 973 test methods in eight places, and eight migrated-only suites
in two more. Parsed from the archive at that time the figures were 284 reports, 933 test methods and
six migrated-only suites — which is what `migrated/surefire/run-provenance.txt`,
`migrated/notes/surefire-pairing.txt` and the commit message of the revision that introduced the error
had all been saying independently. The withdrawal described above then took the same three figures to
**279 reports, 893 test methods and one migrated-only suite**, the one being
`acm-service-data-update/TEST-com.armedia.acm.services.dataupdate.web.SolrReindexServiceTests.xml`.
The figures inside the capture that were computed before the withdrawal — in
`migrated/comparison.txt`, `migrated/notes/surefire-pairing.txt` and the MIRROR blocks — are left as
the run computed them and are enumerated with their superseding values in
`smoke-evidence/<side>/notes/07-post-capture-supersession.txt`, because editing a computed capture
artifact to agree with a later state of the tree is the defect this page spends most of its length
describing.

## Reconciling One Report End To End

Everything above is aggregate. This section reconciles ONE report field by field, because an archive
that only ever states totals cannot be checked at the level a reader actually doubts it. The report
chosen is `acm-foia/TEST-gov.foia.service.ResponseFolderServiceTest.xml`, and the procedure applies
unchanged to any of the other 283.

It is also here to answer a specific challenge. A review of this work reported that a required "FOIA
final report" deliverable did not exist at any commit, having searched the tree, file contents, object
history and every commit. That search found nothing because **no such document is specified**: the
required deliverables are the dependency-change inventory, the JDK-access exceptions register, the
smoke evidence tree and the static-audit capture, plus the baseline-failure, pre-existing-defect and
ambiguity registers — none of them FOIA-specific. What *does* exist, and what the challenge was
anchored on, is the FOIA module's Surefire **report**, present on both halves of this archive. Rather
than assert that, the reconciliation is set out below so the answer is checkable.

### The pair, measured

| Field | Baseline half | Migrated half |
| --- | --- | --- |
| Path | `baseline/surefire/acm-foia/TEST-gov.foia.service.ResponseFolderServiceTest.xml` | `migrated/surefire/acm-foia/TEST-gov.foia.service.ResponseFolderServiceTest.xml` |
| Size | 1318 bytes | 1548 bytes |
| Parses as XML | yes, root `<testsuite>` | yes, root `<testsuite>` |
| Suite name | `gov.foia.service.ResponseFolderServiceTest` | identical |
| tests / failures / errors / skipped | 2 / 0 / 0 / 0 | 2 / 0 / 0 / 0 |
| Test-case set | `testGetResponseFolder`, `testMissingResponseFolder` | identical set |
| `time` | 0.04 | 0.158 |
| Allowlisted properties present | 15 | 16 |
| `java.runtime.version` | `1.8.0_492-8u492-ga~us2-0ubuntu1~25.10.1-b09` | `17.0.19+10-1-25.10.2-Ubuntu` |
| `java.class.version` | 52.0 | 61.0 |
| XML comments | 0 | 0 |
| `version` attribute | absent | `3.0.2` |
| sha256 | `6b43741c6b693ad6e36798883421e37966e53bca1c37f15f99f1e9e6c3e3ff1f` | `a70bd9fafe62d14805634f8386b9d2255bc8354f134ec97ed6da75bb80720a89` |
| Manifest line | `baseline/surefire/sha256-manifest.txt` line 70 | `migrated/surefire/sha256-manifest.txt` line 70 |
| Pairing contract | `expected-suites.txt` line 91, classified `BOTH` | same line |
| Baseline-failure register | 0 references, correctly — the suite is green on both halves | same |

The two outcome rows are the ones that carry the migration claim: the same two test methods, the same
zero failures and zero errors, executed once on class file version 52 and once on 61.

### Rolling that report up to the archive totals

| Scope | Baseline | Migrated |
| --- | --- | --- |
| `acm-foia` suites | 10 | 10 |
| `acm-foia` tests / failures / errors / skipped | 56 / 0 / 0 / 14 | 56 / 0 / 0 / 14 |
| Whole archive suites | 278 | 279 |
| Whole archive tests / failures / errors / skipped | 892 / 3 / 1 / 21 | 893 / 3 / 1 / 21 |
| Manifest entries | 283 = 278 reports + `run-provenance.txt` + 4 notes | 283 = 279 reports + `run-provenance.txt` + 3 notes |
| `sha256sum -c` | 283 OK, 0 FAILED | 283 OK, 0 FAILED |

The `acm-foia` module rolls up **identically on both halves** — same suite count, same test count, same
skip count, zero red either side — so the module the challenge was anchored on is one of the module
level parities this archive establishes rather than one of its gaps. The whole-archive rows re-derive
the published 278/892 and 279/893 exactly.

The manifest arithmetic is stated because the entry counts and the report counts deliberately differ:
each manifest also covers its own provenance note and every file under `notes/`, and the two halves
carry a different number of notes — four on the baseline side and three on the migrated one — which is
why both manifests happen to hold 283 entries over two different report counts. A reader comparing 283
against 278 without that line would read a discrepancy where there is none.

### One archive-wide asymmetry this reconciliation surfaced, and its cause

The `version` attribute is absent from **all 278** baseline reports and present as `version="3.0.2"` on
**all 279** migrated ones. Nothing above this section documented it, and it is documented here because
the honest reading is the opposite of alarming.

At the base commit **zero of the 145 POMs declared `maven-surefire-plugin`**, so unit tests ran on
whatever version Maven implicitly bound, and that version's report schema carries no `version`
attribute. The change set pins the plugin — `maven.surefire.plugin.version` at `pom.xml:196`, consumed
at `pom.xml:439` for Surefire and at `pom.xml:479` so Failsafe forks identically — and the pinned
version's schema does carry one. The attribute is therefore the visible trace of the pin having taken
effect, on every report, and its uniformity on each side is what makes it a property of the toolchain
rather than of any one suite.

`3.0.2` is the **report schema** version, not the plugin version. Reading it as a plugin version would
contradict the pin it is evidence of.

The neighbouring property-count asymmetry, 15 against 16, has a different cause and is already recorded
above: the allowlist holds 16 names, JDK 8 does not publish `jdk.debug`, and neither half carries a
property outside the allowlist.

### Re-running this reconciliation

```bash
cd docs/migration/smoke-evidence
REL=acm-foia/TEST-gov.foia.service.ResponseFolderServiceTest.xml

# 1. Both halves hold it, both parse, neither carries a comment, each states its own runtime.
python3 - <<'EOF'
import xml.etree.ElementTree as ET
for half in ('baseline','migrated'):
    p=f"{half}/surefire/acm-foia/TEST-gov.foia.service.ResponseFolderServiceTest.xml"
    r=ET.parse(p).getroot()
    pr={e.get('name'):e.get('value') for e in r.iter('property')}
    print(half, r.get('tests'), r.get('failures'), r.get('errors'), r.get('skipped'),
          'version='+str(r.get('version')), 'props='+str(len(pr)),
          pr['java.runtime.version'], 'class='+pr['java.class.version'],
          'comments='+str(open(p,'rb').read().count(b'<!--')))
EOF

# 2. The digest in each manifest is the digest of the file on disk.
for half in baseline migrated; do
  ( cd "$half/surefire" && grep "$REL" sha256-manifest.txt | sha256sum -c - )
done

# 3. The pairing contract classifies it, and the failure register does not.
grep -n "$REL" expected-suites.txt
grep -c ResponseFolderServiceTest ../baseline-test-failures.md    # expect 0

# 4. The archive-wide asymmetry, and that it is uniform rather than sporadic.
for half in baseline migrated; do
  printf '%s: reports=%s with-version-attr=%s\n' "$half" \
    "$(find $half/surefire -name '*.xml' | wc -l)" \
    "$(grep -l 'version="3.0.2"' $half/surefire/*/*.xml 2>/dev/null | wc -l)"
done
```

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

# 3. The reports are machine output.  The migrated half carries NO XML comment at all; the
#    baseline half carries exactly one, on EcmFileServiceImplTest, and it is prose ABOUT a native
#    report rather than a substitute for one -- that report carries its full native property dump,
#    and the audit in check 6 passes on it.  A comment is not what makes a report authored; a
#    missing property dump and a missing runner time attribute are, which is what check 7 tests.
grep -rl '<!--' docs/migration/smoke-evidence/migrated/surefire --include='TEST-*.xml' | wc -l  # 0
grep -rl '<!--' docs/migration/smoke-evidence/baseline/surefire --include='TEST-*.xml' | wc -l  # 1

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

# 7. THE READ-TIME AUDIT.  This is the one check that can catch a report replaced after the
#    harvest, and it is the check whose absence let four authored summaries into an earlier
#    revision of the migrated half.  Both halves must exit zero.
for half in baseline migrated; do
  docs/migration/smoke-evidence/install-surefire-evidence.sh \
    --audit docs/migration/smoke-evidence/$half
done
```

Re-harvesting the migrated half is a single command, and it is **idempotent**: running it twice
produces a byte-identical tree, and running it into a different destination produces the identical
tree again — which is itself the proof that no destination path leaks into the archive.

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
mvn -B -ntp -fae test -Dmaven.test.failure.ignore=true -Djacoco.haltOnFailure=false
docs/migration/smoke-evidence/install-surefire-evidence.sh \
  --from . --into docs/migration/smoke-evidence/migrated \
  --exclude '*/.blitzy-scratch/*' --install-exit 0 --test-exit 0
```

The `--exclude` argument is not optional hygiene. If a throwaway extraction of the base commit is
present in the tree, it has its own `target/surefire-reports` directories holding reports from the
*other* runtime, the module directory names collide, and whichever is written last wins per file.
The pattern must name wherever that extraction actually lives.

Two things about that command are worth knowing before running it, because both will stop it:

- **The harvest refuses a dirty worktree.** It will refuse immediately after any build, because the
  license-header plugin rewrites six tracked Java files during every build. Restore them with
  `git checkout -- <the six paths>` and the harvest proceeds; the six are named in the migration
  setup notes and the refusal prints them.
- **The pre-migration half needs its identity supplied and proved**, because its harvest root is
  extracted rather than checked out:

```bash
git archive c8f6226105 | tar -x -C /tmp/baseline-tree
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
( cd /tmp/baseline-tree \
  && mvn -B -ntp clean install -DskipTests -Dmaven.repo.local=/tmp/baseline-repo \
  && mvn -B -ntp -fae test -Dmaven.test.failure.ignore=true -Djacoco.haltOnFailure=false \
        -Dmaven.repo.local=/tmp/baseline-repo )
# the build rewrote six license headers in the extracted tree too; restore them or the
# tree proof will refuse, naming exactly which paths differ
docs/migration/smoke-evidence/install-surefire-evidence.sh \
  --from /tmp/baseline-tree --into docs/migration/smoke-evidence/baseline \
  --source-commit c8f6226105 --source-repo . --install-exit 0 --test-exit 0
```

## Related Registers

- [Baseline Test Failures](baseline-test-failures.md) — the four red outcomes, the six
  migrated-only suites, the corpus measurements, and the one migration-attributable red that lies
  outside this archive because it is an integration test.
- [Pre-existing Defects](pre-existing-defects.md) — defects found and deliberately not fixed,
  including the JEP 372 script-engine removal that the integration red above is caused by.
- [Dependency Change Inventory](dependency-change-inventory.md) — every artifact whose version
  moved, with the compatibility reason.
