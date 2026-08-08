#!/bin/bash

# compare-flow-status.sh — compare the two captures' per-flow .status records RECORD BY
# RECORD, and publish the result as a generated record that fails closed on a difference.
#
# WHY THIS EXISTS, STATED PLAINLY BECAUSE IT DUPLICATES PART OF A LARGER PRODUCER.
#
# migrated/comparison.txt is the whole-capture adjudication, and it carries a per-flow
# ".status" row.  For flow 1 that row reads "match  flow-1-login.status: 5 record(s)
# agree".  The two files it describes now hold ELEVEN records each and disagree on three
# of them: the granted-authority count, the digest of the authority set and the ordered
# authority set itself.  So the row is not wrong about a comparison it performed; it is a
# comparison performed against an EARLIER five-record capture and never recomputed.  A
# reader who trusts it is told that the authorisation result agreed when the recorded
# authorisation results differ.
#
# The larger producer provides a mode for exactly this repair — recompute the adjudication
# from both captures on disk, touching nothing else — and that mode cannot run.  Four
# independent defects were found in it while trying:
#   * a sanitiser self-test asserting on control bytes its probe never contained, which
#     refused EVERY mode of that script on EVERY host from the commit that introduced it
#     (fixed);
#   * three positive redaction assertions whose fixtures were likewise absent (fixed);
#   * a constant interpolated some six thousand lines before its assignment, fatal under
#     `set -u` (fixed);
#   * and symbols that are used but never defined anywhere in the file — the function
#     capture_side_token and the variables SMOKE_CONTRACT_STARTUP_FILES and
#     SMOKE_CONTRACT_NOTES — together with a scratch area that is removed before the
#     comparison writer runs, so the writer reports success and leaves the previous file
#     in place.  Those remain, and they are registered as defects rather than left
#     unstated.
#
# This script therefore computes the ONE measurement the stale row misreports, over all
# eight flows rather than only the one that differs, and it is deliberately small enough
# to read end to end.  It supersedes nothing: comparison.txt keeps its own rows, and the
# register says which of them this record replaces and why.
#
# WHAT IT ASSERTS, AND WHAT IT REFUSES
#   * Every record of every .status file present on either side is accounted for exactly
#     once, as AGREE, DIFFER, ONLY-IN-MIGRATED or ONLY-IN-BASELINE.
#   * A record whose value differs is printed with BOTH values, so the difference is a
#     readable fact rather than a count.
#   * It exits non-zero when any record differs or is unpaired, and when either side has
#     no .status file at all.  A producer that reports success over an absent input is how
#     a gap becomes invisible.
#   * It publishes by renaming a completed staging file over the target, so a reader sees
#     the previous record or this one and never a half-written mixture.
#
# usage:
#   compare-flow-status.sh [--baseline <dir>] [--migrated <dir>] [--out <file>]
#
# Defaults are the two capture directories beside this script and
# migrated/flow-status-comparison.txt.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"
BASE_DIR="${HERE}/baseline"
MIG_DIR="${HERE}/migrated"
OUT=''

require_value()
{
    if [ "$2" -lt 2 ]; then
        printf 'compare-flow-status.sh: %s requires a value and none was given.\n' "$1" >&2
        printf '  Refused rather than defaulted to an empty one: an empty path would send\n' >&2
        printf '  this producer at the wrong target.\n' >&2
        exit 2
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --baseline) require_value '--baseline' "$#"; BASE_DIR="$2"; shift 2 ;;
        --migrated) require_value '--migrated' "$#"; MIG_DIR="$2"; shift 2 ;;
        --out)      require_value '--out' "$#";      OUT="$2";      shift 2 ;;
        -h|--help)  sed -n '1,56p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          printf 'compare-flow-status.sh: unknown option %s\n' "$1" >&2; exit 2 ;;
    esac
done

[ -n "$OUT" ] || OUT="${MIG_DIR}/flow-status-comparison.txt"

for d in "$BASE_DIR" "$MIG_DIR"; do
    if [ ! -d "$d" ]; then
        printf 'compare-flow-status.sh: %s is not a readable directory.\n' "$d" >&2
        exit 2
    fi
done

STATUS_FILES="$( { ls -1 "$BASE_DIR" "$MIG_DIR" 2>/dev/null || true; } \
    | grep -E '^flow-[0-9]+-[a-z0-9-]+\.status$' | LC_ALL=C sort -u )"

if [ -z "$STATUS_FILES" ]; then
    printf 'compare-flow-status.sh: neither capture holds a flow-<n>-<slug>.status file.\n' >&2
    printf '  baseline: %s\n  migrated: %s\n' "$BASE_DIR" "$MIG_DIR" >&2
    printf '  Refused: a comparison over no input is not a comparison.\n' >&2
    exit 2
fi

HEAD_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf 'not-a-git-checkout')"
PORCELAIN="$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null || true)"
DIRTY_COUNT="$(printf '%s' "$PORCELAIN" | grep -c . || true)"

STAGE="${OUT}.$$.staging"
rm -f -- "$STAGE"

flows=0
records=0
agree=0
differ=0
only_mig=0
only_base=0

{
    printf 'per-flow .status records, compared record by record\n'
    printf '===================================================\n'
    printf '\n'
    printf 'GENERATED, NOT AUTHORED, by docs/migration/smoke-evidence/compare-flow-status.sh.\n'
    printf 'Every row below is a comparison of two lines that exist in two files on disk at the\n'
    printf 'moment of writing.  Nothing in it is transcribed and no verdict is asserted beyond\n'
    printf 'the rows themselves.\n'
    printf '\n'
    printf 'written-at              : %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'head-commit             : %s\n' "$HEAD_COMMIT"
    if [ "$DIRTY_COUNT" -gt 0 ]; then
        printf 'worktree-at-write-time  : %s path(s) differ from that commit, so this record\n' "$DIRTY_COUNT"
        printf '                          describes a working tree rather than a commit\n'
    else
        printf 'worktree-at-write-time  : clean -- the commit above contains the files compared\n'
    fi
    printf 'pre-migration side      : %s\n' "${BASE_DIR#"${REPO_ROOT}/"}"
    printf 'post-migration side     : %s\n' "${MIG_DIR#"${REPO_ROOT}/"}"
    printf '\n'
    printf 'WHY THIS RECORD EXISTS.  The whole-capture adjudication beside it reports one\n'
    printf 'aggregate row per flow .status file, and its flow-1 row was computed against an\n'
    printf 'earlier five-record capture: it reads "5 record(s) agree" for two files that now\n'
    printf 'hold eleven records each and disagree on three.  The mode provided for recomputing\n'
    printf 'it cannot run; the reasons are enumerated at the head of this script and registered\n'
    printf 'as defects.  This record states the current per-record position instead of leaving\n'
    printf 'the stale one as the only answer.\n'
    printf '\n'
    printf 'A DIFFERENCE HERE IS NOT AUTOMATICALLY A MIGRATION REGRESSION, and this record does\n'
    printf 'not claim it is.  It states what the two captures recorded.  Attribution -- whether\n'
    printf 'a difference comes from the runtime under test or from the fixture the two runs were\n'
    printf 'pointed at -- belongs in the ambiguity register, which cites this file.\n'
    printf '\n'

    for f in $STATUS_FILES; do
        flows=$((flows + 1))
        b="${BASE_DIR}/${f}"
        m="${MIG_DIR}/${f}"
        printf '===== %s =====\n' "$f"
        if [ ! -f "$b" ]; then
            printf '  ABSENT-IN-BASELINE  the pre-migration capture holds no such file\n'
        fi
        if [ ! -f "$m" ]; then
            printf '  ABSENT-IN-MIGRATED  the post-migration capture holds no such file\n'
        fi

        keys="$( { [ -f "$b" ] && cut -d= -f1 "$b"; [ -f "$m" ] && cut -d= -f1 "$m"; } \
            2>/dev/null | grep -E '.' | LC_ALL=C sort -u )"

        for k in $keys; do
            records=$((records + 1))
            bv=''
            mv=''
            has_b='no'
            has_m='no'
            if [ -f "$b" ] && LC_ALL=C grep -q "^${k}=" "$b"; then
                bv="$(LC_ALL=C grep -m1 "^${k}=" "$b" | cut -d= -f2-)"
                has_b='yes'
            fi
            if [ -f "$m" ] && LC_ALL=C grep -q "^${k}=" "$m"; then
                mv="$(LC_ALL=C grep -m1 "^${k}=" "$m" | cut -d= -f2-)"
                has_m='yes'
            fi

            if [ "$has_b" = 'yes' ] && [ "$has_m" = 'no' ]; then
                only_base=$((only_base + 1))
                printf '  ONLY-IN-BASELINE  %s\n' "$k"
                printf '                      baseline: %s\n' "$bv"
            elif [ "$has_b" = 'no' ] && [ "$has_m" = 'yes' ]; then
                only_mig=$((only_mig + 1))
                printf '  ONLY-IN-MIGRATED  %s\n' "$k"
                printf '                      migrated: %s\n' "$mv"
            elif [ "$bv" = "$mv" ]; then
                agree=$((agree + 1))
                printf '  AGREE             %s\n' "$k"
            else
                differ=$((differ + 1))
                printf '  DIFFER            %s\n' "$k"
                printf '                      baseline: %s\n' "$bv"
                printf '                      migrated: %s\n' "$mv"
            fi
        done
        printf '\n'
    done

    printf '===== totals =====\n'
    printf 'flow-status-files-compared : %s\n' "$flows"
    printf 'records-accounted-for      : %s\n' "$records"
    printf 'records-agreeing           : %s\n' "$agree"
    printf 'records-differing          : %s\n' "$differ"
    printf 'records-only-in-migrated   : %s\n' "$only_mig"
    printf 'records-only-in-baseline   : %s\n' "$only_base"
    printf 'accounting-adds-up         : %s\n' \
        "$( [ "$((agree + differ + only_mig + only_base))" -eq "$records" ] && printf 'yes' || printf 'NO -- a record was counted twice or not at all' )"
} > "$STAGE"

write_status=$?
if [ "$write_status" -ne 0 ]; then
    rm -f -- "$STAGE"
    printf 'compare-flow-status.sh: the record was not written completely, so %s was left untouched.\n' \
        "$OUT" >&2
    exit "$write_status"
fi

if [ -L "$OUT" ] || { [ -e "$OUT" ] && [ ! -f "$OUT" ]; }; then
    rm -f -- "$STAGE"
    printf 'compare-flow-status.sh: refusing to publish over %s: it is not a plain file.\n' "$OUT" >&2
    exit 2
fi
if ! mv -f -- "$STAGE" "$OUT"; then
    rm -f -- "$STAGE"
    printf 'compare-flow-status.sh: could not move the staged record into place at %s.\n' "$OUT" >&2
    printf '  The previous file, if any, is untouched.\n' >&2
    exit 2
fi

# The counters are re-read from the published record rather than carried out of the
# subshell above, because the brace group ran in this shell but a reader can only check
# what the file says.  The exit status is decided from the file, so the status and the
# record can never disagree.
pub_differ="$(LC_ALL=C awk -F': *' '/^records-differing /{ print $2 }' "$OUT")"
pub_only_m="$(LC_ALL=C awk -F': *' '/^records-only-in-migrated /{ print $2 }' "$OUT")"
pub_only_b="$(LC_ALL=C awk -F': *' '/^records-only-in-baseline /{ print $2 }' "$OUT")"
pub_adds="$(LC_ALL=C awk -F': *' '/^accounting-adds-up /{ print $2 }' "$OUT")"

printf 'compare-flow-status.sh: wrote %s\n' "$OUT"
printf '  differing=%s only-in-migrated=%s only-in-baseline=%s accounting=%s\n' \
    "$pub_differ" "$pub_only_m" "$pub_only_b" "$pub_adds"

if [ "$pub_adds" != 'yes' ]; then
    printf 'compare-flow-status.sh: FAIL CLOSED -- the record does not account for every\n' >&2
    printf '  record exactly once, so it cannot be read as a complete comparison.\n' >&2
    exit 1
fi
if [ "$pub_differ" -ne 0 ] || [ "$pub_only_m" -ne 0 ] || [ "$pub_only_b" -ne 0 ]; then
    printf 'compare-flow-status.sh: the two captures do NOT agree on every record.\n' >&2
    printf '  %s differing, %s only in the migrated capture, %s only in the baseline one.\n' \
        "$pub_differ" "$pub_only_m" "$pub_only_b" >&2
    printf '  The record names each one with both values.  Non-zero because a producer that\n' >&2
    printf '  exits zero over a disagreement lets the disagreement pass unnoticed.\n' >&2
    exit 1
fi

printf 'compare-flow-status.sh: every record of every compared flow agrees.\n'
exit 0
