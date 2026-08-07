#!/bin/bash

# capture-static-audit.sh — run the migration's static audit gate and emit the
# MACHINE-CAPTURED region of a static-audit capture file.
#
# WHY THIS SCRIPT EXISTS.  The captures under baseline/static-audit.txt and
# migrated/static-audit.txt each carried a PRODUCED-BY field, and the migrated one
# named smoke-checks.sh — a harness that owns eight scripted smoke flows and does
# not write, and never wrote, a file of that name.  The file said so itself a few
# lines further down, which is worse rather than better: a header field that a
# reader trusts, contradicted by prose a reader may not reach.  Evidence whose
# stated producer does not produce it is not evidence of anything, however
# accurate its contents happen to be.
#
# So the producer now exists, is committed beside the captures, and every figure
# in the machine-captured region of either capture comes out of it.  A reviewer
# runs it and diffs.
#
# WHAT IT PRODUCES, AND WHAT IT DELIBERATELY DOES NOT.  It emits the region that
# can be measured: the toolchain, the gate commands verbatim, the raw captured
# output of each between explicit delimiters, every count, and the exit statuses.
# It does NOT emit the analysis that follows in the committed captures — the
# classification of the seven baseline occurrences, the two-direction argument
# about the gate being textual, or the per-occurrence remediation record.  That
# material is reasoning about the capture rather than the capture, and a script
# that printed 300 lines of prose from a heredoc would let a reader believe the
# reasoning had been measured too.  The committed captures therefore separate the
# two regions explicitly and say which is which.
#
# USAGE
#   capture-static-audit.sh --side after  [--out <file>]
#   capture-static-audit.sh --side before --base-commit <sha> [--out <file>]
#
# --side after   runs the gate against the working tree, which on a migrated
#                branch is the after capture.
# --side before  materialises the named commit into a scratch directory OUTSIDE
#                the working tree and runs the gate there.
#
# THE SCRATCH DIRECTORY MUST SIT OUTSIDE THE WORKING TREE, and this is not a
# stylistic preference.  The gate recurses from the repository root and its
# --include filter cannot tell a historical copy from live source.  Extract the
# base commit into a subdirectory of the checkout and the AFTER capture rediscovers
# those files: the before-side count where zero is expected, on a tree that is in
# fact fully migrated.  mktemp is used for exactly this reason, and the extraction
# is removed as soon as it has been read.

set -u

SIDE=''
OUT=''
BASE_COMMIT=''

# The gate, verbatim as the migration requirements state it.  Held in one variable
# so that the pattern printed in the capture and the pattern actually executed
# cannot drift apart — a capture that prints one command and runs another is the
# defect this script exists to have removed.
GATE_PATTERN='sun.misc\|com.sun.'
GATE_PATTERN_ESCAPED='sun\.misc\|com\.sun\.'

usage()
{
    printf 'usage:\n' >&2
    printf '  %s --side after  [--out <file>]\n' "$0" >&2
    printf '  %s --side before --base-commit <sha> [--out <file>]\n' "$0" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --side) SIDE="${2:-}"; shift 2 ;;
        --out) OUT="${2:-}"; shift 2 ;;
        --base-commit) BASE_COMMIT="${2:-}"; shift 2 ;;
        -h|--help) usage ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage ;;
    esac
done

case "$SIDE" in
    after) ;;
    before)
        [ -n "$BASE_COMMIT" ] || {
            printf '%s: --side before requires --base-commit\n' "$(basename -- "$0")" >&2
            usage
        }
        ;;
    *) usage ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf '%s: not inside a git working tree\n' "$(basename -- "$0")" >&2
    exit 2
}

# ---------------------------------------------------------------------------
# gate_run <dir> — the gate and its cross-checks, run in <dir>, printing a
# fixed set of "key<TAB>value" lines plus the two raw output blocks.
#
# Every count is MEASURED here.  None is passed in, defaulted, or reconciled
# against an expectation: a capture that knows the answer before it looks is a
# specification with a shell prompt drawn on it.
# ---------------------------------------------------------------------------
gate_run()
{
    local dir="$1"
    local main_out test_out

    main_out="$(cd "$dir" && grep -rn "$GATE_PATTERN" --include=*.java . 2>/dev/null \
        | grep "/src/main/java/" | sort)"
    local main_gate_status
    ( cd "$dir" && grep -rn "$GATE_PATTERN" --include=*.java . >/dev/null 2>&1 )
    main_gate_status=$?

    test_out="$(cd "$dir" && grep -rn "$GATE_PATTERN" --include=*.java . 2>/dev/null \
        | grep "/src/test/java/" | sort)"

    printf 'BEGIN-MAIN-SOURCE-CAPTURED-OUTPUT\n'
    [ -n "$main_out" ] && printf '%s\n' "$main_out"
    printf 'END-MAIN-SOURCE-CAPTURED-OUTPUT\n'
    printf 'BEGIN-TEST-SOURCE-CAPTURED-OUTPUT\n'
    [ -n "$test_out" ] && printf '%s\n' "$test_out"
    printf 'END-TEST-SOURCE-CAPTURED-OUTPUT\n'

    printf 'main-source-hits\t%s\n' \
        "$(printf '%s' "$main_out" | grep -c . || true)"
    printf 'main-source-files\t%s\n' \
        "$(printf '%s\n' "$main_out" | grep . | cut -d: -f1 | sort -u | grep -c . || true)"
    printf 'test-source-hits\t%s\n' \
        "$(printf '%s' "$test_out" | grep -c . || true)"
    printf 'whole-tree-hits\t%s\n' \
        "$(cd "$dir" && grep -rn "$GATE_PATTERN" --include=*.java . 2>/dev/null | grep -c . || true)"
    printf 'main-source-hits-escaped-pattern\t%s\n' \
        "$(cd "$dir" && grep -rn "$GATE_PATTERN_ESCAPED" --include=*.java . 2>/dev/null \
            | grep -c "/src/main/java/" || true)"
    printf 'test-source-hits-escaped-pattern\t%s\n' \
        "$(cd "$dir" && grep -rn "$GATE_PATTERN_ESCAPED" --include=*.java . 2>/dev/null \
            | grep -c "/src/test/java/" || true)"
    printf 'java-files-present\t%s\n' \
        "$(cd "$dir" && find . -name '*.java' -type f 2>/dev/null | grep -c . || true)"
    printf 'gate-grep-own-exit-status\t%s\n' "$main_gate_status"

    # The filtered pipeline's status, recorded separately and for one reason only:
    # it disagrees with the line above on a PASSING gate, and the disagreement is
    # the whole point of asserting on output rather than on exit codes.
    ( cd "$dir" && grep -rn "$GATE_PATTERN" --include=*.java . 2>/dev/null \
        | grep "/src/main/java/" | sort >/dev/null )
    printf 'filtered-pipeline-exit-status\t%s\n' "$?"
}

emit()
{
    printf 'STATIC AUDIT GATE - MACHINE-CAPTURED REGION\n'
    printf '%s\n' '================================================================================'
    printf '\n'
    printf 'Everything between this heading and the END-OF-MACHINE-CAPTURED-REGION marker\n'
    printf 'was emitted by capture-static-audit.sh.  No figure in it was typed, copied from\n'
    printf 'a specification, or reconciled against an expectation: each was measured by the\n'
    printf 'command printed immediately above it, at generation time, on the toolchain\n'
    printf 'recorded below.  Anything AFTER that marker in the committed capture file is\n'
    printf 'authored analysis and says so.\n'
    printf '\n'
    printf 'CAPTURE-SIDE: %s\n' "$SIDE"
    printf 'PRODUCED-BY: docs/migration/smoke-evidence/capture-static-audit.sh\n'
    printf 'PRODUCED-BY-INVOCATION: %s\n' "$INVOCATION"
    printf 'BASE-COMMIT: %s\n' "${BASE_COMMIT:-c8f6226105}"
    printf 'capture-toolchain-grep: %s\n' "$(grep --version 2>/dev/null | head -1)"
    printf 'capture-toolchain-jdk: %s\n' \
        "$(java -version 2>&1 | head -1 | sed -e 's/^[[:space:]]*//')"
    printf '\n'
    printf 'THE GATE, VERBATIM AS THE MIGRATION REQUIREMENTS STATE IT\n'
    printf '%s\n' '--------------------------------------------------------------------------------'
    printf '\n'
    printf '    grep -rn "%s" --include=*.java <main source>\n' "$GATE_PATTERN"
    printf '\n'
    printf 'Main source and test source are distinguished by filtering the recursive run\n'
    printf 'from the repository root, which is the form verified to work at the base commit:\n'
    printf '\n'
    printf '    grep -rn "%s" --include=*.java . | grep "/src/main/java/"\n' "$GATE_PATTERN"
    printf '    grep -rn "%s" --include=*.java . | grep "/src/test/java/"\n' "$GATE_PATTERN"
    printf '\n'
    printf 'Both are run with a trailing sort below, so the captured line order is the\n'
    printf "tool's own and is stable between runs rather than filesystem-dependent.\\n"
    printf '\n'

    printf 'CAPTURE A - MAIN SOURCE\n'
    printf '%s\n' '--------------------------------------------------------------------------------'
    printf '\n'
    printf 'command: grep -rn "%s" --include=*.java . | grep "/src/main/java/" | sort\n' "$GATE_PATTERN"
    printf '\n'
    printf 'begin-captured-output\n'
    printf '%s' "$MAIN_BLOCK"
    printf 'end-captured-output\n'
    printf '\n'
    printf 'MAIN-SOURCE-HITS: %s\n' "$(field main-source-hits)"
    printf 'MAIN-SOURCE-FILES: %s\n' "$(field main-source-files)"
    printf '\n'
    printf 'command: grep -rn "%s" --include=*.java . | wc -l\n' "$GATE_PATTERN"
    printf 'WHOLE-TREE-HITS: %s\n' "$(field whole-tree-hits)"
    printf '\n'
    printf 'command: grep -rn "%s" --include=*.java . | grep -c "/src/main/java/"\n' "$GATE_PATTERN_ESCAPED"
    printf 'MAIN-SOURCE-HITS-ESCAPED-PATTERN: %s\n' "$(field main-source-hits-escaped-pattern)"
    printf '\n'
    printf 'java-files-present-on-this-tree: %s\n' "$(field java-files-present)"
    printf '\n'
    printf 'exit-status-of-the-gate-grep-on-its-own: %s\n' "$(field gate-grep-own-exit-status)"
    printf 'exit-status-of-the-filtered-pipeline-as-run: %s\n' "$(field filtered-pipeline-exit-status)"
    printf 'exit-status-role: ADDITIONAL OBSERVATION ONLY.  grep reports status 1 when it\n'
    printf '  matches nothing, so on a passing run of this gate a non-zero status from the\n'
    printf '  gate grep is the EXPECTED signal rather than a failure; and absent pipefail a\n'
    printf '  pipeline reports only its last command status, so the filtered form reports 0\n'
    printf '  on a passing gate and would report 0 on a FAILING one too.  Read either as a\n'
    printf '  verdict and you get the wrong answer.  The assertion rests on the captured\n'
    printf '  output above and the measured counts, and on nothing else.\n'
    printf '\n'

    printf 'CAPTURE B - TEST SOURCE\n'
    printf '%s\n' '--------------------------------------------------------------------------------'
    printf '\n'
    printf 'command: grep -rn "%s" --include=*.java . | grep "/src/test/java/" | sort\n' "$GATE_PATTERN"
    printf '\n'
    printf 'begin-captured-output\n'
    printf '%s' "$TEST_BLOCK"
    printf 'end-captured-output\n'
    printf '\n'
    printf 'TEST-SOURCE-HITS: %s\n' "$(field test-source-hits)"
    printf '\n'
    printf 'command: grep -rn "%s" --include=*.java . | grep -c "/src/test/java/"\n' "$GATE_PATTERN_ESCAPED"
    printf 'TEST-SOURCE-HITS-ESCAPED-PATTERN: %s\n' "$(field test-source-hits-escaped-pattern)"
    printf '\n'

    if [ "$SIDE" = 'after' ]; then
        printf 'BEFORE-SIDE CROSS-CHECK, MEASURED FROM THE BASE COMMIT WITHOUT EXTRACTION\n'
        printf '%s\n' '--------------------------------------------------------------------------------'
        printf '\n'
        printf 'This cross-check needs no extraction at all, which is exactly why it is here:\n'
        printf 'it is independent of the scratch-directory step the before capture depends on.\n'
        printf 'It reports the before-side counts with a commit-prefixed path form instead of\n'
        printf 'the leading-dot form an extracted run produces.\n'
        printf '\n'
        printf 'command: git grep -n "%s" %s -- %s | grep -c "/src/main/java/"\n' \
            "$GATE_PATTERN" "${BASE_COMMIT:-c8f6226105}" "'*.java'"
        printf 'MAIN-SOURCE-HITS-BEFORE-VIA-GIT-GREP: %s\n' "$GITGREP_MAIN"
        printf '\n'
        printf 'command: git grep -n "%s" %s -- %s | grep "/src/main/java/" | cut -d: -f2 | sort -u | wc -l\n' \
            "$GATE_PATTERN" "${BASE_COMMIT:-c8f6226105}" "'*.java'"
        printf 'MAIN-SOURCE-FILES-BEFORE-VIA-GIT-GREP: %s\n' "$GITGREP_FILES"
        printf '\n'
        printf 'command: git grep -n "%s" %s -- %s | grep -c "/src/test/java/"\n' \
            "$GATE_PATTERN" "${BASE_COMMIT:-c8f6226105}" "'*.java'"
        printf 'TEST-SOURCE-HITS-BEFORE-VIA-GIT-GREP: %s\n' "$GITGREP_TEST"
        printf '\n'
        printf 'command: git grep -n "%s" %s -- %s | grep -c .\n' \
            "$GATE_PATTERN" "${BASE_COMMIT:-c8f6226105}" "'*.java'"
        printf 'WHOLE-TREE-HITS-BEFORE-VIA-GIT-GREP: %s\n' "$GITGREP_ALL"
        printf '\n'
        printf 'The before-side lines themselves are NOT reproduced here.  The sibling capture\n'
        printf 'in the baseline directory is their archive, and duplicating them would make\n'
        printf 'the content diff between the two files harder to read rather than easier.  They\n'
        printf 'are referenced by file and line in the authored region below.\n'
        printf '\n'
        printf 'per-file distribution at the base commit, measured:\n'
        printf '%s\n' "$GITGREP_DIST"
        printf '\n'
    fi

    printf 'END-OF-MACHINE-CAPTURED-REGION\n'
}

field()
{
    printf '%s\n' "$MEASUREMENTS" | awk -F'\t' -v k="$1" '$1 == k { print $2; found = 1 }
        END { if (!found) { print "MEASUREMENT-MISSING" } }'
}

INVOCATION="capture-static-audit.sh --side ${SIDE}"
[ -n "$BASE_COMMIT" ] && INVOCATION="${INVOCATION} --base-commit ${BASE_COMMIT}"

if [ "$SIDE" = 'after' ]; then
    RAW="$(gate_run "$REPO_ROOT")"
else
    SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/static-audit-before.XXXXXX")" || {
        printf '%s: could not create a scratch directory\n' "$(basename -- "$0")" >&2
        exit 1
    }
    trap 'rm -rf -- "$SCRATCH"' EXIT
    case "$SCRATCH" in
        "$REPO_ROOT"/*)
            printf '%s: the scratch directory landed inside the working tree.\n' "$(basename -- "$0")" >&2
            printf '  That is the one place it must not be: the after capture would rediscover\n' >&2
            printf '  the extracted historical files and report the before-side count on a fully\n' >&2
            printf '  migrated tree.  Point TMPDIR outside the checkout and rerun.\n' >&2
            exit 1
            ;;
    esac
    ( cd "$REPO_ROOT" && git archive "$BASE_COMMIT" ) \
        | tar -x -C "$SCRATCH" --wildcards '*.java' || {
        printf '%s: could not materialise %s\n' "$(basename -- "$0")" "$BASE_COMMIT" >&2
        exit 1
    }
    RAW="$(gate_run "$SCRATCH")"
fi

MAIN_BLOCK="$(printf '%s\n' "$RAW" \
    | sed -n '/^BEGIN-MAIN-SOURCE-CAPTURED-OUTPUT$/,/^END-MAIN-SOURCE-CAPTURED-OUTPUT$/p' \
    | sed -e '1d' -e '$d')"
[ -n "$MAIN_BLOCK" ] && MAIN_BLOCK="${MAIN_BLOCK}
"
TEST_BLOCK="$(printf '%s\n' "$RAW" \
    | sed -n '/^BEGIN-TEST-SOURCE-CAPTURED-OUTPUT$/,/^END-TEST-SOURCE-CAPTURED-OUTPUT$/p' \
    | sed -e '1d' -e '$d')"
[ -n "$TEST_BLOCK" ] && TEST_BLOCK="${TEST_BLOCK}
"
MEASUREMENTS="$(printf '%s\n' "$RAW" | grep -E "$(printf '\t')")"

GITGREP_MAIN=''
GITGREP_FILES=''
GITGREP_TEST=''
GITGREP_ALL=''
GITGREP_DIST=''
if [ "$SIDE" = 'after' ]; then
    bc="${BASE_COMMIT:-c8f6226105}"
    gg="$(cd "$REPO_ROOT" && git grep -n "$GATE_PATTERN" "$bc" -- '*.java' 2>/dev/null)"
    GITGREP_MAIN="$(printf '%s\n' "$gg" | grep -c "/src/main/java/" || true)"
    GITGREP_TEST="$(printf '%s\n' "$gg" | grep -c "/src/test/java/" || true)"
    GITGREP_ALL="$(printf '%s' "$gg" | grep -c . || true)"
    GITGREP_FILES="$(printf '%s\n' "$gg" | grep "/src/main/java/" | cut -d: -f2 \
        | sort -u | grep -c . || true)"
    GITGREP_DIST="$(printf '%s\n' "$gg" | grep "/src/main/java/" | cut -d: -f2 \
        | sed -e 's|.*/||' | sort | uniq -c | sort -rn | sed -e 's|^|  |')"
fi

# A capture that silently lost a measurement is worse than one that failed, so the
# assembled region is checked for the marker `field` emits when a key is absent.
region="$(emit)"
if printf '%s\n' "$region" | grep -q 'MEASUREMENT-MISSING'; then
    printf '%s: a measurement did not reach the emitted region.\n' "$(basename -- "$0")" >&2
    printf '%s\n' "$region" | grep -n 'MEASUREMENT-MISSING' >&2
    exit 1
fi

if [ -n "$OUT" ]; then
    printf '%s\n' "$region" > "$OUT" || exit 1
    printf 'machine-captured region written to %s\n' "$OUT"
else
    printf '%s\n' "$region"
fi
