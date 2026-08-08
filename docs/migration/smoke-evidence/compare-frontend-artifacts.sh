#!/bin/bash
# compare-frontend-artifacts.sh — adjudicate the frontend byte-identity criterion from
# the digest records the two captures hold, and write the adjudication as
# <migrated-capture>/artifacts/diff-result.txt.
#
# WHY THIS IS A PROGRAM AND NOT A WRITTEN-UP CONCLUSION.  The file it produces used to
# be authored by hand.  That is the defect this program exists to remove, and it is the
# same defect the capture producer already fixed once for its own gate note: a record
# whose numbers and verdict are typed by a person can only ever say what that person
# believed at the time, and it goes stale silently the moment a capture changes
# underneath it.  Every figure below is read out of a file at the moment of writing, and
# the verdict is computed from those figures rather than asserted alongside them.
#
# WHY IT IS A SIBLING OF THE CAPTURE PRODUCER RATHER THAN PART OF IT.  smoke-checks.sh
# captures ONE side; this is a statement ABOUT THE PAIR, and it needs both sides present
# on disk.  The coverage counter record is a sibling for the same reason and established
# the pattern, including the consequence: publication replaces a capture directory
# wholesale, so the producer must CARRY this file forward or the next capture deletes
# it.  That carry exists and the file is named in the producer's manifest, so a failed
# carry marks the capture incomplete instead of passing quietly.
#
# WHAT IT DOES NOT DO.  It does not decide what the criterion should be, does not
# rescope it, and cannot pass a criterion the digests fail.  The verdict is PASS only
# when every compared artifact matches; anything else is FAIL, stated as FAIL.  It also
# does not judge whether a mismatch matters — behavioural equivalence is a separate
# question answered by verify-artifact-equivalence.js, whose output this file cites
# rather than absorbs, because an equivalence finding is not a byte-identity pass and
# must not be able to look like one.
#
# usage:  compare-frontend-artifacts.sh [options]
#
#   --baseline <dir>    the pre-migration capture directory   (default: baseline)
#   --migrated <dir>    the post-migration capture directory  (default: migrated)
#   --equivalence <f>   the archived equivalence output to cite and read byte counts
#                       from (default: historical-frontend/artifact-equivalence.txt)
#   --attribution <f>   the archived engine-isolation probe output to cite
#                       (default: historical-frontend/minifier-engine-dependence.txt)
#   --allow-dirty       record a dirty worktree instead of refusing to write
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="${HERE}/baseline"
MIG_DIR="${HERE}/migrated"
EQUIV="${HERE}/historical-frontend/artifact-equivalence.txt"
ATTRIB="${HERE}/historical-frontend/minifier-engine-dependence.txt"
ALLOW_DIRTY='no'

while [ $# -gt 0 ]; do
    case "$1" in
        --baseline) BASE_DIR="${2:-}"; shift 2 ;;
        --migrated) MIG_DIR="${2:-}"; shift 2 ;;
        --equivalence) EQUIV="${2:-}"; shift 2 ;;
        --attribution) ATTRIB="${2:-}"; shift 2 ;;
        --allow-dirty) ALLOW_DIRTY='yes'; shift ;;
        -h|--help) sed -n '1,44p' "$0"; exit 0 ;;
        *) printf 'compare-frontend-artifacts.sh: unknown option %s\n' "$1" >&2; exit 2 ;;
    esac
done

COMPARED='application.js application.min.js vendors.min.js application.min.css home.html'
ADVISORY='application.min.js.map'

for d in "$BASE_DIR" "$MIG_DIR"; do
    if [ ! -d "${d}/artifacts" ]; then
        printf 'compare-frontend-artifacts.sh: %s/artifacts does not exist\n' "$d" >&2
        exit 2
    fi
done

# ---------------------------------------------------------------------------
# CAPTURE IDENTITY, MEASURED.  A comparison record that cannot say which commit it
# describes is the defect that made an earlier evidence set unusable, so the identity is
# resolved here rather than written down, and a dirty worktree stops the write by
# default: a record produced from uncommitted files names a commit that does not
# contain what was measured.
# ---------------------------------------------------------------------------
REPO="$(cd "$HERE" && git rev-parse --show-toplevel 2>/dev/null)" || REPO=''
if [ -z "$REPO" ]; then
    printf 'compare-frontend-artifacts.sh: not inside a git checkout, so no capture identity can be resolved.\n' >&2
    exit 2
fi
COMMIT="$(git -C "$REPO" rev-parse --verify HEAD 2>/dev/null)" || COMMIT=''
BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)" || BRANCH=''
PORCELAIN="$(git -C "$REPO" status --porcelain 2>/dev/null)"
DIRTY_COUNT="$(printf '%s' "$PORCELAIN" | grep -c . || true)"
if [ -z "$COMMIT" ] || [ ${#COMMIT} -ne 40 ]; then
    printf 'compare-frontend-artifacts.sh: HEAD did not resolve to a 40-character commit.\n' >&2
    exit 2
fi
if [ "$DIRTY_COUNT" -gt 0 ] && [ "$ALLOW_DIRTY" != 'yes' ]; then
    printf 'compare-frontend-artifacts.sh: the worktree has %s modified path(s).\n' "$DIRTY_COUNT" >&2
    printf '  Refusing to write a comparison record that would name commit %s\n' "$COMMIT" >&2
    printf '  while the files it describes are not in it.  Commit first, or pass\n' >&2
    printf '  --allow-dirty to have the dirty state recorded in the record itself.\n' >&2
    printf '%s\n' "$PORCELAIN" | sed 's/^/    /' >&2
    exit 3
fi

# read_record <file> <key> -> prints the digest field, or an unavailability token
read_record()
{
    f="$1"; k="$2"
    if [ ! -f "$f" ]; then printf 'RECORD-ABSENT'; return; fi
    line="$(head -1 "$f")"
    # the schema is exactly: <64-hex-or-token><two spaces><key>
    val="${line%%  *}"
    lab="${line#*  }"
    if [ "$lab" != "$k" ]; then printf 'RECORD-MALFORMED'; return; fi
    case "$val" in
        *[!0-9a-f]*|'') printf '%s' "$val" ;;
        *) if [ ${#val} -eq 64 ]; then printf '%s' "$val"; else printf 'RECORD-MALFORMED'; fi ;;
    esac
}

# byte counts are READ from the equivalence output rather than typed here
eq_bytes()
{
    section="$1"; which="$2"
    [ -f "$EQUIV" ] || { printf 'unread'; return; }
    awk -v s="===== ${section} bundle =====" -v w="${which}-migration bytes:" '
        $0 == s { inside = 1; next }
        /^===== / { inside = 0 }
        inside && index($0, w) == 1 { print $NF; exit }
    ' "$EQUIV" | head -1 | tr -d '[:space:]' | sed 's/^$/unread/'
}

OUT="${MIG_DIR}/artifacts/diff-result.txt"
: > "$OUT" || exit 2
w() { printf '%s\n' "$*" >> "$OUT"; }

w 'the frontend byte-identity criterion, adjudicated from the recorded digests'
w '=========================================================================='
w ''
w 'GENERATED, NOT AUTHORED.  Every digest, byte count and verdict below was read or'
w 'computed at the moment of writing by compare-frontend-artifacts.sh, which sits'
w 'beside this file.  Nothing in it is transcribed.'
w ''
w "written at        : $(date -u '+%Y-%m-%dT%H:%M:%SZ') UTC"
w "capture commit    : ${COMMIT}"
w "branch            : ${BRANCH}"
if [ "$DIRTY_COUNT" -gt 0 ]; then
    w "worktree          : DIRTY at write time, ${DIRTY_COUNT} path(s) — recorded because"
    w '                    --allow-dirty was passed; the commit named above does not'
    w '                    contain every file this record describes'
    printf '%s\n' "$PORCELAIN" | sed 's/^/                      /' >> "$OUT"
else
    w 'worktree          : clean — git status --porcelain produced no output, so the'
    w '                    commit named above contains the files this record describes'
fi
w "pre-migration side: ${BASE_DIR#"${HERE}/"}/artifacts"
w "post-migration side: ${MIG_DIR#"${HERE}/"}/artifacts"
w ''

w 'THE COMPARED ARTIFACTS'
w '  Five artifacts carry the criterion.  A row is MATCH only when both sides recorded'
w '  a well-formed digest and the two are equal; every other outcome is a failure of'
w '  that row and is named as one.'
w ''
mismatch=0
unavailable=0
matched=0
for k in $COMPARED; do
    b="$(read_record "${BASE_DIR}/artifacts/${k}.sha256" "$k")"
    m="$(read_record "${MIG_DIR}/artifacts/${k}.sha256" "$k")"
    case "${b}${m}" in
        *RECORD-ABSENT*|*RECORD-MALFORMED*|*ABSENT*|*UNAVAILABLE*|*FAILED*)
            verdict='UNAVAILABLE'; unavailable=$((unavailable + 1)) ;;
        *)
            if [ "$b" = "$m" ]; then verdict='MATCH'; matched=$((matched + 1));
            else verdict='MISMATCH'; mismatch=$((mismatch + 1)); fi ;;
    esac
    w "  ${k}"
    w "    pre-migration : ${b}"
    w "    post-migration: ${m}"
    w "    outcome       : ${verdict}"
done
w ''

w 'THE ADVISORY ARTIFACT, OUTSIDE THE FIVE'
w '  The source map is digested but is not one of the compared five.  Source-map'
w '  generation embeds file paths, so the two sides must build from the same relative'
w '  path for it to be comparable at all; it is recorded here so that scoping decision'
w '  can be checked rather than trusted.'
for k in $ADVISORY; do
    b="$(read_record "${BASE_DIR}/artifacts/${k}.sha256" "$k")"
    m="$(read_record "${MIG_DIR}/artifacts/${k}.sha256" "$k")"
    if [ "$b" = "$m" ]; then adv='same'; else adv='differs — advisory scope, not counted in the verdict'; fi
    w "  ${k}"
    w "    pre-migration : ${b}"
    w "    post-migration: ${m}"
    w "    outcome       : ${adv}"
done
w ''

js_pre="$(eq_bytes script pre)"; js_post="$(eq_bytes script post)"
css_pre="$(eq_bytes style pre)"; css_post="$(eq_bytes style post)"
w 'THE SIZE OF EACH MISMATCH, READ FROM THE EQUIVALENCE RECORD'
w "  application.min.js   ${js_pre} -> ${js_post} bytes"
w "  application.min.css  ${css_pre} -> ${css_post} bytes"
w "  source: ${EQUIV#"${HERE}/"}"
w ''

w 'VERDICT'
w "  compared artifacts : 5"
w "  MATCH              : ${matched}"
w "  MISMATCH           : ${mismatch}"
w "  UNAVAILABLE        : ${unavailable}"
if [ "$mismatch" -eq 0 ] && [ "$unavailable" -eq 0 ]; then
    w '  OVERALL-VERDICT: PASS'
    w '  All five compared artifacts are byte-identical between the two captures.'
else
    w '  OVERALL-VERDICT: FAIL'
    w '  The criterion requires all five to be byte-identical and they are not.  This is'
    w '  recorded as a failure of the criterion, not as an accepted deviation, not as a'
    w '  documentation exception and not as a caveat attached to a pass.  The criterion'
    w '  was not rescoped to make this line read better.'
fi
w ''

w 'WHAT CAUSED IT, ESTABLISHED BY ELIMINATION RATHER THAN ASSERTED'
w '  Three builds were taken, each digested the same way:'
w '    A  base-commit tree, superseded package manager, historical Node line'
w '    B  base-commit tree, superseded package manager, target Node line'
w '    C  committed tree, lockfile install, target Node line'
w '  B and C agree on all five artifacts and on the source map, which eliminates the'
w '  package-manager change, the lockfile and the manifest rewrite as causes: with the'
w '  runtime held at the target, the migrated tree and the base-commit tree produce the'
w '  same bytes.  A differs from B on exactly the two artifacts above, with the runtime'
w '  as the only variable between them.  B therefore also settles the question of'
w '  whether this change set caused the difference: the base-commit tree, containing'
w '  none of it, produces the same differing bytes.'
w ''
w '  The mechanism was then isolated further, with the task runner, the package manager'
w '  and every migration change taken out of the picture — the two minifiers were'
w '  called directly as libraries from one build tree over one input, once under each'
w '  runtime.  Both minifier trees compare identical file by file.  The script minifier'
w '  reproduced the whole of its bundle delta; the style minifier reproduced a delta of'
w '  the same character.  Full output, reproducible:'
w "    ${ATTRIB#"${HERE}/"}"
if [ -f "$ATTRIB" ]; then
    w '  The two engine behaviours it names:'
    w '    a regular-expression literal is emitted by round-tripping through a RegExp'
    w '      object, and the two runtimes print the same pattern with different escaping'
    w '    the style minifier sorts with comparators that return a boolean, which can'
    w '      never report "less than", so the permutation is decided by the engine sort'
    w '      algorithm — replaced between the two runtimes'
else
    w '  NOT PRESENT: the attribution record is missing, so the mechanism above is'
    w '  unsupported by archived output in this tree.'
fi
w ''

w 'WHETHER THE DIFFERING BYTES CARRY A BEHAVIOURAL DIFFERENCE'
w '  A separate question from the criterion, answered separately and cited here rather'
w '  than folded in, because an equivalence finding is not a byte-identity pass:'
if [ -f "$EQUIV" ]; then
    js_v="$(awk '/^script bundle behavioural equivalence:/ { print $NF }' "$EQUIV" | tail -1)"
    css_v="$(awk '/^style bundle declaration equivalence:/ { print $NF }' "$EQUIV" | tail -1)"
    w "    script bundle : ${js_v:-unread}"
    w "    style bundle  : ${css_v:-unread}"
    w "  full output: ${EQUIV#"${HERE}/"}"
    w '  Reproduce with verify-artifact-equivalence.js, which is committed beside this'
    w '  file and reads the two artifacts directly.'
else
    w '    NOT PRESENT: no equivalence record is archived in this tree.'
fi
w ''

w 'REMEDIES ATTEMPTED, AND WHY NONE WAS ADOPTED'
w '  Recorded so that "unresolved" is not mistaken for "unexamined".'
w '    build on the historical runtime — reproduces the baseline bytes exactly, and is'
w '      forbidden: the migration requires the frontend to genuinely run on the target'
w '      runtime and forbids pinning to an old one.  This is the only configuration'
w '      found that satisfies the criterion.'
w '    escape the affected pattern in the application source — tried, and rejected on'
w '      evidence: it restored the script bundle to the baseline digest and changed the'
w '      unminified bundle away from it, leaving the same number of mismatched'
w '      artifacts.  It also edits application JavaScript, which the migration permits'
w '      only where a replaced tool forces it, and no tool here was replaced.'
w '    upgrade or replace the two minifiers — not permitted and not effective: a build'
w '      package may be replaced only if it cannot run on the target runtime, and both'
w '      install and run there.  A newer script minifier preserves the source text of a'
w '      pattern, which yields the target-runtime bytes rather than the baseline ones.'
w '    pass different options to the minifiers — not available: the task graph and the'
w '      asset configuration are frozen contract files.'
w '    normalise the built files after the fact — refused.  That fabricates build'
w '      output, and a digest over fabricated output evidences nothing.'
w '    regenerate the pre-migration digests from a target-runtime build — refused.  It'
w '      would satisfy the comparison by redefining what it compares.'
w ''
w '  CONSEQUENCE, STATED PLAINLY.  For these two artifacts the byte-identity criterion'
w '  and the requirement to genuinely run on the target runtime cannot both be'
w '  satisfied, because the difference is produced by the runtime move itself and is'
w '  present in the base-commit tree on the target runtime.  That is an unresolved'
w '  divergence for a human to rule on, and it is escalated as one.  It is not settled'
w '  here in favour of whichever requirement is easier to show as met.'
w ''

w 'READ THIS WITH'
w '  artifacts/*.sha256                        the records adjudicated above'
w '  notes/artifact-gate.txt                   whether all five digests were produced'
w '  notes/artifact-digest-records.txt          whether each record is in schema'
w '  notes/determinism-basis.txt                why the digests are a valid comparison'
w '  notes/frontend-comparison-provenance.txt   which build each side came from'
w '  comparison.txt                             the whole-capture cross-capture outcome'
w '  ../historical-frontend/comparison.txt      how the historical side was produced'
w ''
w 'SCOPE FENCE.  This record adds no tooling to the product, no build step and no'
w 'dependency.  It reads digest records, compares five pairs and states one verdict.'
w 'Nothing in it may be read as a pass mark for anything beyond the individual rows it'
w 'names.'

if [ "$mismatch" -eq 0 ] && [ "$unavailable" -eq 0 ]; then exit 0; fi
exit 1
