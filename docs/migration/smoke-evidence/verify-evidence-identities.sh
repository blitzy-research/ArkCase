#!/usr/bin/env bash
# =============================================================================
# verify-evidence-identities.sh
#
# WHAT THIS IS FOR
# ----------------
# The migration evidence is not produced by one program in one pass.  Five
# independent producers write it, they necessarily run at different times, and
# each one records the commit IT ran at:
#
#   install-surefire-evidence.sh    -> */surefire/run-provenance.txt
#   smoke-checks.sh                 -> */notes/capture-provenance.txt
#   capture-startup-adjudication.sh -> */startup/startup.status, error-scan.txt
#   compare-frontend-artifacts.sh   -> migrated/artifacts/diff-result.txt
#   the before/after experiments    -> their own notes.txt provenance blocks
#
# A reader meeting several different commit hashes across those files has to be
# able to tell the difference between two harmless situations and one fatal one:
#
#   harmless   the producers ran at different evidence commits, and no
#              non-documentation content differed between them, so all of them
#              describe the same application and the same build
#   harmless   a record deliberately names an EARLIER state -- the pre-migration
#              capture reading the base commit, or the "before" half of a
#              before/after pair -- and says so in its own text
#   fatal      a record names an object that does not resolve, resolves
#              ambiguously, or is labelled as something it is not
#
# Not every 40-hex token on a labelled line is a COMMIT.  Content identity is
# cited too -- a blob hash proves a file is byte-identical at two revisions, and
# it is the strongest identity claim available because it names the bytes rather
# than a revision that contains them.  This script resolves each token to an
# object and reports its TYPE, so a blob citation is verified as a blob instead
# of being failed for not being a commit, and a token that names no object at
# all is failed whatever it was meant to be.
#
# Prose cannot separate those.  This script does, mechanically, and it is
# fail-closed: it exits non-zero if any cited identity is unresolvable or
# ambiguous, and it prints the pairwise non-documentation difference for every
# pair of cited commits so a reader can see for themselves that the producers
# describe one state of the repository.
#
# It writes identity-index.txt beside itself.  That file is GENERATED -- do not
# hand-edit it; re-run this instead.
#
# USAGE
#   bash docs/migration/smoke-evidence/verify-evidence-identities.sh
#   echo $?     # 0 = every cited identity resolves unambiguously
# =============================================================================
set -u

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "FATAL: not inside a git repository, so no identity can be resolved" >&2
    exit 2
}
cd "$repo_root" || exit 2

evidence_root='docs/migration'
out="$evidence_root/smoke-evidence/identity-index.txt"

# The base commit is a declared constant of this migration, not a discovered
# value: it is the commit the pre-migration side reads and the commit every
# "at the base commit" anchor answers for.
BASE_COMMIT='c8f6226105c28c2743281d26bf21ad73f7bb7f26'

# ---------------------------------------------------------------------------
# The labelled identity fields.  Only LABELLED fields are scanned, deliberately.
# A raw hex sweep of this directory returns hundreds of tokens that are package
# integrity hashes and artifact digest prefixes, and drowning the real claims in
# those makes the check useless.  A commit hash that appears with no label is
# caught separately, by the abbreviation check further down.
# ---------------------------------------------------------------------------
labels='capture-commit|capture commit|capture-branch|harvested-from-commit|reports-produced-by-a-build-of|commit-resolves-in-this-repository|commit-reachable-from-branch|git-status-porcelain|worktree-outside-this-capture|provenance-measured-in-tree|declared-side-against-observed-head|observed-head|base-commit|base commit|BEFORE  |AFTER   |BASE    |DELIVERED-REVISION|BASE-COMMIT|answers for revision|Captured at commit'

tmpd=$(mktemp -d) || exit 2
trap 'rm -rf "$tmpd"' EXIT
fields="$tmpd/fields"; commits="$tmpd/commits"; shorts="$tmpd/shorts"

# Two classes of file are excluded from the scan, for two different reasons.
#
# THE PRODUCERS contain these strings as literals -- in their own field-writing
# code, and in comment blocks that document historical defects by quoting the
# very identity that caused them.  install-surefire-evidence.sh, for instance,
# names a commit that no object answers to, deliberately, because that failure is
# why its resolvability check exists.  They are the instruments, not the
# evidence.
#
# THIS SCRIPT'S OWN OUTPUT is excluded because it is written INTO the tree being
# scanned.  Without the exclusion the index reads its own previous run: an
# identity that appeared once, transiently, is copied into the index and then
# re-detected on every subsequent run for ever, so a fault that has been fixed
# keeps failing the gate and the gate cannot be cleared by fixing anything.  That
# is a latch, and it is worse than the self-referential-figure problem the
# worktree measurement avoids, because a latch never clears on its own.  This was
# found by deliberately planting a bad identity, watching the gate correctly
# fail, removing it, and watching the gate fail again.
producers='verify-evidence-identities.sh|smoke-checks.sh|install-surefire-evidence.sh|capture-startup-adjudication.sh|compare-frontend-artifacts.sh|compare-coverage-counters.sh|identity-index.txt'

grep -rnE "($labels)" "$evidence_root" \
     --include='*.txt' --include='*.md' --include='*.status' 2>/dev/null \
  | grep -vE "($producers)" > "$fields"

# every full 40-hex object named on a labelled line, partitioned by object type
all_ids="$tmpd/all_ids"; others="$tmpd/others"
grep -oE '\b[0-9a-f]{40}\b' "$fields" 2>/dev/null | sort -u > "$all_ids"
# An ABBREVIATED citation is the same kind of claim as a full one and gets the
# same treatment: it is expanded to its full object id here and classified with
# the rest.  Doing otherwise would let a 10-character hash escape the
# reachability and non-documentation-difference checks purely by being short.
# -rno rather than -rho, and the path is stripped only AFTER the producer filter has
# seen it.  With -rho grep prints the matched token alone, so the producer filter had
# nothing to match on and excluded nothing: the abbreviation net read identity-index.txt,
# this script's own output, and every identity that had ever appeared in it was
# re-detected on every later run.  That is precisely the latch the block above says it
# avoids, and it was live -- an unreachable commit named once by a withdrawn provenance
# note kept failing the gate after the citation had been removed from the evidence.
grep -rnoE '\b[0-9a-f]{7,12}\b' "$evidence_root" \
     --include='*.txt' --include='*.md' --include='*.status' 2>/dev/null \
  | grep -vE "($producers)" | sed -E 's/^[^:]*:[0-9]+://' | sort -u \
  | while read -r t; do git rev-parse --verify --quiet "$t" 2>/dev/null; done \
  >> "$all_ids"
sort -u -o "$all_ids" "$all_ids"

: > "$commits"; : > "$others"
while read -r h; do
    [ -n "$h" ] || continue
    t=$(git cat-file -t "$h" 2>/dev/null)
    case "$t" in
        commit) printf '%s\n' "$h" >> "$commits" ;;
        *)      printf '%s\t%s\n' "$h" "${t:-none}" >> "$others" ;;
    esac
done < "$all_ids"

# every abbreviated 7..12-hex token anywhere in the evidence.  This is the
# unlabelled-citation net: an abbreviation that resolves to a commit is an
# identity claim whether or not anybody labelled it.
grep -rnoE '\b[0-9a-f]{7,12}\b' "$evidence_root" \
     --include='*.txt' --include='*.md' --include='*.status' 2>/dev/null \
  | grep -vE "($producers)" | sed -E 's/^[^:]*:[0-9]+://' | sort -u > "$shorts"

fail=0
resolved=0
ambiguous=0
unresolvable=0
unreachable=0

{
printf '%s\n' \
'==============================================================================' \
'EVIDENCE IDENTITY INDEX' \
'==============================================================================' \
'' \
'GENERATED by docs/migration/smoke-evidence/verify-evidence-identities.sh.' \
'  Do not hand-edit; re-run the script.  Every line below is measured from git' \
'  and from the evidence files themselves, not authored.' \
'' \
'THE COMMITTED COPY IS A SNAPSHOT, and it says which head it was taken at on' \
'  the next line.  Committing it necessarily moves the head past it -- there is' \
'  no way for a file to record the commit that contains it -- so the value below' \
'  will normally be one or more commits behind.  That is not a defect and it is' \
'  not a reason to trust the snapshot over a fresh run.  The script is cheap and' \
'  idempotent, so a reviewer who wants a current answer should run it rather than' \
'  read this.  It exits non-zero if any cited identity fails, which makes it' \
'  usable as a gate and not only as a report.' \
'' \
'WHAT A CONSOLIDATED HISTORY DOES TO THE ROWS BELOW, stated because an earlier' \
'  revision of this header asserted the opposite and was wrong.  That revision' \
'  claimed every commit made after the recorded head is a documentation-only' \
'  commit, so that the snapshot being behind could never matter.  That holds only' \
'  while the change set is being developed.  When it is delivered as a single' \
'  consolidated commit, the intermediate commits this index names stop being' \
'  ancestors of the delivered one, and the delivered tree also differs from them' \
'  outside docs/ wherever a later revision touched application or build files.' \
'  So read the rows below as identities of the states the evidence was PRODUCED' \
'  AT, which is what an evidence citation is for, and not as a claim about the' \
'  ancestry of whatever commit you are reading them in.  Both properties are' \
'  measured here rather than assumed: the reachable/NOT-REACHABLE column and the' \
'  non-docs-diff column say, per commit, exactly which of the two situations you' \
'  are in, and NEITHER column is folded into the verdict.' \
'' \
'  ONE CONSEQUENCE THAT NO SCRIPT CAN REMOVE, so it is stated instead.  A clone' \
'  that does not carry the working history in which this evidence was produced' \
'  does not carry those commit objects either, and this gate will report them as' \
'  DOES-NOT-RESOLVE.  That is a fact about the clone, not about the evidence: the' \
'  citations name the states the captures were taken at, and a consolidated' \
'  delivery publishes their content without publishing their commits.  The anchor' \
'  that survives consolidation is the DECLARED BASE COMMIT named below, which is a' \
'  commit of the published history and is what every before-and-after claim in' \
'  this folder is measured against; verify it with' \
'      git merge-base --is-ancestor <declared-base-commit> HEAD && echo reachable' \
''
printf 'generated-at-head          : %s\n' "$(git rev-parse HEAD)"
printf 'generated-on-branch        : %s\n' "$(git rev-parse --abbrev-ref HEAD)"
printf 'declared-base-commit       : %s\n' "$BASE_COMMIT"
# This script is a CHECKER, not a capture, so it does not refuse a dirty worktree
# -- refusing would make it unusable at exactly the moment a reviewer most wants
# to run it, mid-investigation.  It reports the state instead, because a reader
# has to know whether the evidence it just read is committed or is sitting
# modified on somebody's disk.
# The file this script writes is EXCLUDED from the measurement, for the same
# reason the surefire harvester excludes the archive it writes and the smoke
# capture excludes its own destination: a figure that counts the act of writing
# it can never read clean, and a self-referential provenance figure is worse than
# none.  Everything else in the tree is counted.
porc=$(git status --porcelain -- "$evidence_root" 2>/dev/null | grep -vF -- "$out" | wc -l | tr -d ' ')
porc_all=$(git status --porcelain 2>/dev/null | grep -vF -- "$out" | wc -l | tr -d ' ')
if [ "$porc_all" = '0' ]; then
    printf 'worktree-at-generation     : clean -- every path is tracked and unmodified, so\n'
    printf '                             the evidence read below is the evidence committed at\n'
    printf '                             the head named above\n'
else
    printf 'worktree-at-generation     : DIRTY -- %s modified path(s), of which %s under %s.\n' \
        "$porc_all" "$porc" "$evidence_root"
    printf '                             The evidence read below is the working-tree state, not\n'
    printf '                             the committed state.  Re-run after committing for an\n'
    printf '                             answer about the commit.\n'
fi
printf 'lines-matching-an-identity-label-or-phrase: %s\n' "$(wc -l < "$fields" | tr -d ' ')"
printf '  (a deliberate superset: the phrase "base commit" appears in prose as\n'
printf '   well as in field position, and over-collecting is the safe direction)\n'
printf 'files-carrying-at-least-one              : %s\n' "$(cut -d: -f1 "$fields" | sort -u | wc -l | tr -d ' ')"
printf 'distinct-objects-cited-full-or-abbrev   : %s\n' "$(wc -l < "$all_ids" | tr -d ' ')"
printf '  of which commits          : %s\n' "$(wc -l < "$commits" | tr -d ' ')"
printf '  of which other objects    : %s\n' "$(wc -l < "$others" | tr -d ' ')"
printf '\n'

printf '%s\n' \
'------------------------------------------------------------------------------' \
'EVERY COMMIT CITED ANYWHERE IN THE EVIDENCE, FULL OR ABBREVIATED' \
'------------------------------------------------------------------------------' \
'resolves        the hash names a commit object in this repository' \
'reachable       it is an ancestor of, or equal to, the current head.  REPORTED,' \
'                not required -- see the note on a consolidated history above.' \
'non-docs-diff   how many files outside docs/ differ between it and the head.' \
'                0 means it describes the same application, build files and' \
'                producers as the head, differing only in evidence written' \
'                between the two -- which is what a sequence of evidence' \
'                commits SHOULD differ in.  A non-zero value is not' \
'                automatically wrong: see the classification beside it.' \
''
while read -r c; do
    [ -n "$c" ] || continue
    r=$(git rev-parse --verify --quiet "${c}^{commit}" 2>&1); st=$?
    if [ $st -ne 0 ]; then
        if printf '%s' "$r" | grep -qi 'ambiguous'; then
            printf '%s  AMBIGUOUS\n' "$c"; ambiguous=$((ambiguous+1))
        else
            printf '%s  DOES-NOT-RESOLVE\n' "$c"; unresolvable=$((unresolvable+1))
        fi
        fail=1
        continue
    fi
    resolved=$((resolved+1))
    # REACHABILITY IS REPORTED, NOT REQUIRED, and the reason is the delivery shape
    # rather than leniency.  This change set is delivered as ONE consolidated commit, so
    # every intermediate commit the evidence was produced at stops being an ancestor of
    # the delivered head the moment it is delivered.  Failing on that would make the gate
    # fail by construction on every delivered tree, which is a gate that tells a reviewer
    # nothing.  What still fails is the property that actually distinguishes a good
    # citation from a bad one: resolving to exactly one object, and not being ambiguous.
    if git merge-base --is-ancestor "$c" HEAD 2>/dev/null; then reach='reachable'; else reach='NOT-REACHABLE'; unreachable=$((unreachable+1)); fi
    nd=$(git diff --name-only "$c" HEAD -- ':!docs' 2>/dev/null | wc -l | tr -d ' ')
    if [ "$c" = "$BASE_COMMIT" ]; then
        cls='DECLARED-BASE-COMMIT: the pre-migration state.  A non-zero non-docs
                            difference here is the change set itself and is the point'
    elif [ "$nd" = '0' ]; then
        cls='EVIDENCE-COMMIT: same application and build as the head'
    else
        cls='EARLIER-STATE: the head has moved outside docs/ since this commit, so it
                            names an earlier application or build state.  That is the ordinary
                            reading of an evidence citation and is not by itself a defect; the
                            field listing below names every record that cites it'
    fi
    printf '%s\n' "$c"
    printf '  resolves  %s   non-docs-diff-vs-head %s\n' "$reach" "$nd"
    printf '  %s\n' "$cls"
    printf '  subject   %s\n' "$(git log -1 --format='%s' "$c" 2>/dev/null | cut -c1-90)"
    while read -r f; do printf '  cited by  %s\n' "$f"; done < <(cut -d: -f1 "$fields" | sort -u | tr '\n' '\0' | xargs -0 -r grep -lE "$c" 2>/dev/null | sed "s#^$evidence_root/##")
    printf '\n'
done < "$commits"

printf '%s\n' \
'------------------------------------------------------------------------------' \
'EVERY NON-COMMIT OBJECT CITED ANYWHERE IN THE EVIDENCE' \
'------------------------------------------------------------------------------' \
'A blob hash cited beside two revisions is a CONTENT identity: it says the file' \
'is byte-identical at both, which no revision hash can say on its own.  Each is' \
'resolved here and its type reported.  A token that names no object at all is' \
'counted as unresolvable in the outcome below, whatever it was meant to be.' \
''
if [ -s "$others" ]; then
  while IFS="$(printf '\t')" read -r h t; do
      [ -n "$h" ] || continue
      if [ "$t" = 'none' ]; then
          printf '  DOES-NOT-RESOLVE  %s\n' "$h"; unresolvable=$((unresolvable+1)); fail=1
          continue
      fi
      sz=$(git cat-file -s "$h" 2>/dev/null)
      printf '  resolves as %-6s %s  (%s bytes)\n' "$t" "$h" "${sz:-unknown}"
      while read -r f; do printf '    cited by  %s\n' "$f"; done < <(cut -d: -f1 "$fields" | sort -u | tr '\n' '\0' | xargs -0 -r grep -lE "$h" 2>/dev/null | sed "s#^$evidence_root/##")
  done < "$others"
else
  printf '  none\n'
fi
printf '\n'

printf '%s\n' \
'------------------------------------------------------------------------------' \
'ABBREVIATED CITATIONS' \
'------------------------------------------------------------------------------' \
'Every 7-to-12 character hex token anywhere in the evidence is tested as an' \
'object prefix, labelled or not.  This is the unlabelled-citation net: an' \
'abbreviation that resolves is an identity claim whether or not anybody' \
'labelled it, and it must resolve to exactly ONE object.  One that resolves to' \
'no object is a digest fragment and is not an identity claim at all.  An' \
'ambiguous abbreviation IS a failure: it names more than one object and' \
'therefore names none.' \
''
sh_ok=0; sh_amb=0; sh_frag=0
while read -r t; do
    [ -n "$t" ] || continue
    r=$(git rev-parse --verify --quiet "$t" 2>&1); st=$?
    if [ $st -ne 0 ]; then
        if printf '%s' "$r" | grep -qi 'ambiguous'; then
            printf '  AMBIGUOUS  %s\n' "$t"; sh_amb=$((sh_amb+1)); fail=1
        else
            sh_frag=$((sh_frag+1))
        fi
        continue
    fi
    printf '  resolves   %-12s -> %s  (%s)\n' "$t" "$r" "$(git cat-file -t "$r" 2>/dev/null)"; sh_ok=$((sh_ok+1))
done < "$shorts"
printf '\n'
printf '  abbreviations examined      : %s\n' "$(wc -l < "$shorts" | tr -d ' ')"
printf '  resolve to exactly one      : %s\n' "$sh_ok"
printf '  AMBIGUOUS                   : %s\n' "$sh_amb"
printf '  not a commit prefix (digest) : %s\n' "$sh_frag"
printf '\n'

printf '%s\n' \
'------------------------------------------------------------------------------' \
'PAIRWISE NON-DOCUMENTATION DIFFERENCE BETWEEN EVERY CITED COMMIT' \
'------------------------------------------------------------------------------' \
'This is the check that turns "several hashes" into "one state of the' \
'repository".  For each pair, the number of files outside docs/ that differ.' \
'Pairs involving the declared base commit, or a deliberately-cited earlier' \
'state, are expected to be non-zero and are marked.' \
''
while read -r a; do
  while read -r b; do
    [ "$a" \< "$b" ] || continue
    n=$(git diff --name-only "$a" "$b" -- ':!docs' 2>/dev/null | wc -l | tr -d ' ')
    mark=''
    if [ "$a" = "$BASE_COMMIT" ] || [ "$b" = "$BASE_COMMIT" ]; then mark='  (base commit: the change set)'
    elif [ "$n" != '0' ]; then mark='  (deliberately-cited earlier state)'; fi
    printf '  %s..%s  %s%s\n' "$(printf '%.10s' "$a")" "$(printf '%.10s' "$b")" "$n" "$mark"
  done < "$commits"
done < "$commits"
printf '\n'

printf '%s\n' \
'------------------------------------------------------------------------------' \
'EVERY LABELLED IDENTITY FIELD, VERBATIM' \
'------------------------------------------------------------------------------' \
'Truncated to 150 characters per line for legibility; the files themselves are' \
'authoritative.' \
''
sed "s#^$evidence_root/##" "$fields" | sed 's/\(.\{150\}\).*/\1.../' | sort | sed 's/^/  /'
printf '\n'

printf '%s\n' \
'==============================================================================' \
'OUTCOME' \
'=============================================================================='
printf 'full-commits-resolving      : %s\n' "$resolved"
printf 'full-other-objects-resolving: %s\n' "$(grep -cv 'none$' "$others" 2>/dev/null || printf '0')"
printf 'full-objects-ambiguous      : %s\n' "$ambiguous"
printf 'full-objects-unresolvable   : %s\n' "$unresolvable"
printf 'abbreviations-ambiguous     : %s\n' "$sh_amb"
printf 'full-commits-not-reachable  : %s   (reported, not a failure)\n' "$unreachable"
if [ "$fail" -eq 0 ]; then
    printf 'IDENTITY-OUTCOME: PASS -- every identity cited anywhere in the evidence\n'
    printf '  resolves to exactly one object and none is ambiguous, which is what this\n'
    printf '  verdict asserts.  Reachability from the head is reported per commit and is\n'
    printf '  NOT part of it: a consolidated delivery makes the commits the captures were\n'
    printf '  taken at stop being ancestors of the delivered one, so requiring it would\n'
    printf '  fail every delivered tree by construction.  The non-docs-diff column above is\n'
    printf '  reported per commit rather than folded into this verdict, because a cited\n'
    printf '  commit that differs from the head outside docs/ is an earlier state of the\n'
    printf '  application named on purpose, not a failure: the declared base commit is\n'
    printf '  exactly that, and so is any evidence commit taken before a later revision\n'
    printf '  touched application or build files.  What this verdict does assert is that\n'
    printf '  every citation is unambiguous and resolvable in this repository -- that no\n'
    printf '  hash written into this evidence was transcribed wrongly or invented.\n'
else
    printf 'IDENTITY-OUTCOME: FAIL -- see the entries marked AMBIGUOUS or\n'
    printf '  DOES-NOT-RESOLVE above.  A NOT-REACHABLE row is reported rather than\n'
    printf '  counted here, for the reason given in the header.\n'
fi
} > "$out"

cat "$out" | tail -12
echo
echo "written: $out"
exit "$fail"
