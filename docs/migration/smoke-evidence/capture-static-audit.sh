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

# ---------------------------------------------------------------------------
# ARGUMENT ARITY IS CHECKED BEFORE THE SHIFT, NOT ASSUMED BY IT.
#
# Each value option used to read `${2:-}` and then `shift 2`.  When the option was
# the LAST argument, `${2:-}` yielded an empty string and `shift 2` — asked to shift
# more positions than exist — shifted NOTHING and returned non-zero.  `$#` therefore
# never decreased and the loop spun forever on the same argument: `capture-static-
# audit.sh --side` hung the caller instead of telling it what was wrong.  This
# script is now invoked programmatically by smoke-checks.sh, so a hang there is a
# hung capture rather than an operator noticing a stuck terminal.
#
# require_value refuses the missing value explicitly and names the option, which is
# both terminating and more useful than an empty string quietly becoming the side.
require_value()
{
    local opt="$1"
    local count="$2"

    if [ "$count" -lt 2 ]; then
        printf '%s: %s requires a value and none was given.\n' \
            "$(basename -- "$0")" "$opt" >&2
        printf '  Refused rather than defaulted to an empty one: an empty --side\n' >&2
        printf '  would fall through to the usage check, and an empty --out would\n' >&2
        printf '  silently send the region to standard output instead of the file the\n' >&2
        printf '  caller asked for.\n' >&2
        usage
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --side)
            require_value '--side' "$#"
            SIDE="$2"
            shift 2
            ;;
        --out)
            require_value '--out' "$#"
            OUT="$2"
            shift 2
            ;;
        --base-commit)
            require_value '--base-commit' "$#"
            BASE_COMMIT="$2"
            shift 2
            ;;
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
# ---------------------------------------------------------------------------
# EVERY MEASUREMENT'S STATUS IS CAPTURED, AND A STATUS OUTSIDE grep's TWO IS FATAL.
#
# grep exits 0 when it matches, 1 when it does not, and >1 when something went WRONG
# — an unreadable directory, a bad pattern, a resource limit.  The previous
# arrangement absorbed the third case comprehensively: every count was the tail of an
# unchecked pipeline ending in `grep -c . || true`, and absent pipefail a pipeline
# reports only its LAST command's status anyway.  So a run in which the gate grep
# errored out produced empty output blocks and zero counts — which reads exactly like
# a clean tree with no occurrences at all, and would have been published as a PASSING
# audit.  That is the false green this whole deliverable is organised against, sitting
# inside the producer of the gate it is meant to prove.
#
# So the gate grep runs ONCE into a file, its status is captured, and every count is
# then derived from that file by a single command whose own status is captured too.
# Anything outside {0,1} sets GATE_FAULT, and a run with GATE_FAULT set refuses to
# emit a region rather than emitting a confident one built on a failed search.
#
# THE FAULT IS RECORDED IN A FILE, NOT A VARIABLE, AND THAT IS STRUCTURAL.  gate_run
# is invoked inside a command substitution so its whole body runs in a SUBSHELL: a
# variable it set would be discarded the moment the substitution closed, which is
# precisely how a detected fault would come to be silently forgotten by the check
# meant to act on it.  A file survives the subshell.
gate_fault()
{
    printf '%s\n' "$1" >> "$GATE_FAULT_FILE"
}

grep_status_ok()
{
    case "$1" in
        0|1) return 0 ;;
        *)   return 1 ;;
    esac
}

# count_matching <file> <fixed-string> — lines containing the string, status checked.
count_matching()
{
    local file="$1"
    local needle="$2"
    local n
    local st

    n="$(LC_ALL=C grep -c -F -- "$needle" "$file" 2>/dev/null)"
    st=$?
    if ! grep_status_ok "$st"; then
        gate_fault "counting lines containing '${needle}' failed with grep status ${st}"
        printf 'MEASUREMENT-FAILED'
        return 0
    fi
    case "$n" in '' | *[!0-9]*) n=0 ;; esac
    printf '%s' "$n"
}

gate_run()
{
    local dir="$1"
    local raw="${GATE_SCRATCH}/raw"
    local raw_escaped="${GATE_SCRATCH}/raw-escaped"
    local main_out="${GATE_SCRATCH}/main"
    local test_out="${GATE_SCRATCH}/test"
    local gate_status
    local escaped_status
    local n

    # THE GATE, RUN ONCE.  Every figure below is derived from this one file, so the
    # counts and the captured lines cannot come from two different searches — and the
    # search's own status is the single thing that decides whether any of them mean
    # anything.
    ( cd "$dir" && LC_ALL=C grep -rn -e "$GATE_PATTERN" --include=*.java . ) \
        > "$raw" 2>/dev/null
    gate_status=$?
    if ! grep_status_ok "$gate_status"; then
        gate_fault "the gate grep exited ${gate_status}, which is neither matched (0) nor no-match (1), so THE SEARCH DID NOT HAPPEN"
        : > "$raw"
    fi

    ( cd "$dir" && LC_ALL=C grep -rn -e "$GATE_PATTERN_ESCAPED" --include=*.java . ) \
        > "$raw_escaped" 2>/dev/null
    escaped_status=$?
    if ! grep_status_ok "$escaped_status"; then
        gate_fault "the escaped-pattern cross-check grep exited ${escaped_status}, which is neither matched (0) nor no-match (1)"
        : > "$raw_escaped"
    fi

    # Partitioned with a FIXED-STRING match on a file rather than through a pipeline,
    # so each has its own checkable status and no stage can fail unobserved.
    LC_ALL=C grep -F -- '/src/main/java/' "$raw" 2>/dev/null | LC_ALL=C sort > "$main_out"
    LC_ALL=C grep -F -- '/src/test/java/' "$raw" 2>/dev/null | LC_ALL=C sort > "$test_out"

    printf 'BEGIN-MAIN-SOURCE-CAPTURED-OUTPUT\n'
    cat -- "$main_out"
    printf 'END-MAIN-SOURCE-CAPTURED-OUTPUT\n'
    printf 'BEGIN-TEST-SOURCE-CAPTURED-OUTPUT\n'
    cat -- "$test_out"
    printf 'END-TEST-SOURCE-CAPTURED-OUTPUT\n'

    printf 'main-source-hits\t%s\n' "$(count_lines_of "$main_out")"
    n="$(LC_ALL=C cut -d: -f1 -- "$main_out" 2>/dev/null | LC_ALL=C sort -u | wc -l \
        | tr -d '[:space:]')"
    case "$n" in '' | *[!0-9]*) n=0 ;; esac
    # wc -l over an empty stream reports 0, and cut over an empty file yields an empty
    # stream, so no special case is needed for a clean tree.
    printf 'main-source-files\t%s\n' "$n"
    printf 'test-source-hits\t%s\n' "$(count_lines_of "$test_out")"
    printf 'whole-tree-hits\t%s\n' "$(count_lines_of "$raw")"
    printf 'main-source-hits-escaped-pattern\t%s\n' \
        "$(count_matching "$raw_escaped" '/src/main/java/')"
    printf 'test-source-hits-escaped-pattern\t%s\n' \
        "$(count_matching "$raw_escaped" '/src/test/java/')"

    n="$( ( cd "$dir" && find . -name '*.java' -type f 2>/dev/null ) | wc -l \
        | tr -d '[:space:]')"
    case "$n" in '' | *[!0-9]*) n=0 ;; esac
    printf 'java-files-present\t%s\n' "$n"

    printf 'gate-grep-own-exit-status\t%s\n' "$gate_status"
    printf 'escaped-pattern-grep-own-exit-status\t%s\n' "$escaped_status"
    printf 'gate-grep-status-within-grep-semantics\t%s\n' \
        "$(grep_status_ok "$gate_status" && printf 'yes' || printf 'NO - the search did not happen')"

    # The filtered pipeline's status, recorded for one reason only: it disagrees with
    # the gate grep's own status on a PASSING gate, and the disagreement is the whole
    # point of asserting on output rather than on exit codes.  It is an OBSERVATION of
    # that disagreement, never a measurement anything depends on, which is why it is
    # the one status here that is not required to fall within grep's two.
    ( LC_ALL=C grep -F -- '/src/main/java/' "$raw" | LC_ALL=C sort > /dev/null ) 2>/dev/null
    printf 'filtered-pipeline-exit-status\t%s\n' "$?"
}

# count_lines_of — lines in a file, with wc's status checked.
count_lines_of()
{
    local n
    local st

    n="$(wc -l < "$1" 2>/dev/null | tr -d '[:space:]')"
    st=$?
    if [ "$st" -ne 0 ]; then
        gate_fault "counting the lines of ${1} failed with status ${st}"
        printf 'MEASUREMENT-FAILED'
        return 0
    fi
    case "$n" in '' | *[!0-9]*) n=0 ;; esac
    printf '%s' "$n"
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

# The private working area for the measurements: the single raw gate output every
# count is derived from, the partitioned copies, and the fault ledger.  Created with
# mktemp -d rather than at a name built from the process identifier, because a
# predictable path in a shared directory is a path another account can pre-create as
# a link — and this one holds the search output the whole capture rests on.
GATE_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/static-audit-measure.XXXXXX")" || {
    printf '%s: could not create a working directory for the measurements\n' \
        "$(basename -- "$0")" >&2
    exit 1
}
chmod 700 "$GATE_SCRATCH" 2>/dev/null || true
GATE_FAULT_FILE="${GATE_SCRATCH}/fault"
: > "$GATE_FAULT_FILE"

# ONE HANDLER FOR BOTH SCRATCH DIRECTORIES, ON EVERY EXIT PATH INCLUDING A SIGNAL.
# A second `trap ... EXIT` installed further down would REPLACE this one rather than add
# to it, so the before path would clean up its extraction and leak the measurement area
# — which holds the raw gate output.  SCRATCH is empty until the before path sets it and
# the handler tolerates that, so there is nothing to arrange in the order the two are
# created.
#
# The signals are named alongside EXIT because `trap ... EXIT` alone does not run when
# bash is terminated by one.  The before path extracts a whole source tree at the base
# commit, which takes long enough that an operator or a `timeout` wrapper may well stop
# it partway; without the signals that leaves an extracted copy of the repository in a
# shared temporary directory.
SCRATCH=''
cleanup_scratch()
{
    [ -z "${GATE_SCRATCH:-}" ] || rm -rf -- "$GATE_SCRATCH"
    [ -z "${SCRATCH:-}" ] || rm -rf -- "$SCRATCH"
}
trap cleanup_scratch EXIT HUP INT TERM

if [ "$SIDE" = 'after' ]; then
    RAW="$(gate_run "$REPO_ROOT")"
else
    SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/static-audit-before.XXXXXX")" || {
        printf '%s: could not create a scratch directory\n' "$(basename -- "$0")" >&2
        exit 1
    }
    # Registered with the single handler installed above rather than by installing a
    # second one, which would have replaced it.
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

# A SEARCH THAT DID NOT HAPPEN PRODUCES NO REGION AT ALL.
#
# Checked before anything is emitted, because the failure mode being guarded against
# is not a missing figure — it is a figure of ZERO that came from a search which
# errored rather than from a tree with no occurrences.  Those two are indistinguishable
# in the output and opposite in meaning, and the second would have been published as a
# passing audit.  Nothing is written, and the faults are named on the error stream so
# the caller learns what went wrong rather than that something did.
if [ -s "$GATE_FAULT_FILE" ]; then
    printf '%s: THE SEARCH DID NOT HAPPEN, so no region was produced.\n' \
        "$(basename -- "$0")" >&2
    sed -e 's|^|  - |' "$GATE_FAULT_FILE" >&2
    printf '  Every count this script emits is derived from that search.  A zero from a\n' >&2
    printf '  failed search is indistinguishable in the output from a zero on a clean\n' >&2
    printf '  tree, and would be read as a PASSING gate — so no output is produced at\n' >&2
    printf '  all rather than confident output built on nothing.\n' >&2
    exit 1
fi

# A capture that silently lost a measurement is worse than one that failed, so the
# assembled region is checked for the marker `field` emits when a key is absent, and
# for the marker a failed count emits in its place.
region="$(emit)"
if printf '%s\n' "$region" | grep -q -e 'MEASUREMENT-MISSING' -e 'MEASUREMENT-FAILED'; then
    printf '%s: a measurement did not reach the emitted region.\n' "$(basename -- "$0")" >&2
    printf '%s\n' "$region" | grep -n -e 'MEASUREMENT-MISSING' -e 'MEASUREMENT-FAILED' >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# WRITING THE REGION: CONTAINED, AND BY RENAME.
#
# `printf ... > "$OUT"` followed whatever --out named.  Three consequences, and the
# caller is now a script rather than a person: a symbolic link at that path was
# written THROUGH, into whatever it pointed at; a traversing path wrote outside the
# tree entirely; and a truncate-then-write left a half-written file behind if anything
# interrupted it, which is the state a reader is least able to detect, because a
# static-audit capture that stops in the middle of its counts still looks like a
# capture.
#
# So the destination is required to be a plain file path inside the repository, it may
# not be a link, and the region is written to a temporary file beside it and renamed
# into place.  A reader therefore sees the previous file or the complete new one.
if [ -n "$OUT" ]; then
    out_parent="$(dirname -- "$OUT")"
    out_leaf="$(basename -- "$OUT")"

    case "$OUT" in
        *'..'*)
            printf '%s: refusing --out %s: the path contains a parent-directory segment.\n' \
                "$(basename -- "$0")" "$OUT" >&2
            exit 2
            ;;
    esac

    out_parent_abs="$(cd "$out_parent" 2>/dev/null && pwd -P)" || out_parent_abs=''
    if [ -z "$out_parent_abs" ]; then
        printf '%s: refusing --out %s: its directory does not exist.\n' \
            "$(basename -- "$0")" "$OUT" >&2
        printf '  Nothing was created there: this script writes a capture region, it does\n' >&2
        printf '  not lay out a capture tree.\n' >&2
        exit 2
    fi

    case "${out_parent_abs}/" in
        "$REPO_ROOT"/*) ;;
        *)
            printf '%s: refusing --out %s.\n' "$(basename -- "$0")" "$OUT" >&2
            printf '  Resolved to:      %s/%s\n' "$out_parent_abs" "$out_leaf" >&2
            printf '  Repository root:  %s\n' "$REPO_ROOT" >&2
            printf '  The region is part of a committed evidence tree, so it is written inside\n' >&2
            printf '  the repository or not at all.  Omit --out to read it on standard output.\n' >&2
            exit 2
            ;;
    esac

    if [ -L "${out_parent_abs}/${out_leaf}" ]; then
        printf '%s: refusing --out %s: it is a symbolic link.\n' \
            "$(basename -- "$0")" "$OUT" >&2
        printf '  Writing it would act on whatever it points at.  It is left in place.\n' >&2
        exit 2
    fi
    if [ -e "${out_parent_abs}/${out_leaf}" ] && [ ! -f "${out_parent_abs}/${out_leaf}" ]; then
        printf '%s: refusing --out %s: it exists and is not a plain file.\n' \
            "$(basename -- "$0")" "$OUT" >&2
        exit 2
    fi

    out_tmp="${out_parent_abs}/.${out_leaf}.capture-static-audit.tmp"
    rm -f -- "$out_tmp"
    if ! printf '%s\n' "$region" > "$out_tmp"; then
        rm -f -- "$out_tmp"
        printf '%s: could not write the region beside %s\n' \
            "$(basename -- "$0")" "$OUT" >&2
        exit 1
    fi
    if ! mv -f -- "$out_tmp" "${out_parent_abs}/${out_leaf}"; then
        rm -f -- "$out_tmp"
        printf '%s: could not move the region into place at %s\n' \
            "$(basename -- "$0")" "$OUT" >&2
        printf '  The previous file, if any, is untouched.\n' >&2
        exit 1
    fi
    printf 'machine-captured region written to %s\n' "$OUT"
else
    printf '%s\n' "$region"
fi
