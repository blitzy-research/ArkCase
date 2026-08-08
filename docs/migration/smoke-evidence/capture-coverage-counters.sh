#!/bin/bash

# capture-coverage-counters.sh — archive the COVERAGE COUNTERS a unit-test run
# produced, tied to the execution data file they were computed from, together with
# the coverage check's own verdict.
#
# WHY THIS SCRIPT EXISTS, AND WHY THE EXISTING LIVENESS RECORD IS NOT ENOUGH.
#
# The sibling record jacoco-liveness.txt answers one question and answers it well:
# is the execution data non-empty, or did something sever the agent?  It answers it
# by measuring the size of every jacoco.exec on disk.  That is the right instrument
# for that question, because a severed run writes an EMPTY data file and a live run
# does not.
#
# It is the wrong instrument for a different question that reads deceptively like
# the same one: did the coverage the build measured actually clear the configured
# minimum?  A file size cannot answer that.  Eleven megabytes of execution data is
# consistent with any ratio whatsoever, including one below the minimum, and a
# reader who takes a byte total as a coverage figure has been given a number that
# does not mean what it appears to mean.
#
# The counters that DO answer it already exist.  The root aggregator binds the
# coverage plugin's report goal to the test phase, so every module that runs tests
# writes jacoco.xml and jacoco.csv beside its jacoco.exec.  Those files carry the
# class, method, line, branch, instruction and complexity counters, missed and
# covered, computed by the plugin from that exact execution data.  They were simply
# never archived.  This script archives them.
#
# THREE PROPERTIES OF THE OUTPUT THAT ARE DELIBERATE.
#
# (1) EVERY COUNTER IS TIED TO THE DIGEST OF THE EXECUTION DATA IT CAME FROM.  A
#     counter table and an exec digest published side by side, with nothing binding
#     them, can drift: the table can be regenerated from a later run while the
#     digest still describes an earlier one, and nothing in either file would show
#     it.  Each row below therefore carries the SHA-256 of the module's jacoco.exec
#     next to the counters read out of the report the plugin computed from it, so a
#     reader can tell whether two rows describe one run.
#
# (2) THE CHECK GOAL'S OWN WORDS ARE QUOTED, NOT SUMMARISED.  The plugin prints one
#     line per bundle it evaluated.  Those lines are extracted from the build log
#     verbatim and counted, because "the rule passed" asserted in prose is exactly
#     the claim a reader cannot check.
#
# (3) THE CONFIGURED MINIMUM IS READ OUT OF THE BUILD, NOT TYPED IN HERE.  The rule
#     the plugin evaluates takes its minimum from a property in the root aggregator.
#     This script reads that property from the POM it is pointed at, so the
#     comparison below cannot be made against a threshold the build does not use.
#
# USAGE
#   capture-coverage-counters.sh --from <reactor-root> --out <file>
#                               --build-log <file> --command-record <file>
#                               [--pom <root-pom>] [--label <text>]
#
#   --command-record is a file the build wrapper wrote containing the exact argument
#   vector of the test invocation, one argument per line.  It is required rather than
#   optional, and it is a FILE rather than a string, so that the command recorded
#   beside the counters is the one a program emitted and not one retyped afterwards.

set -u
set -o pipefail

fail()
{
    local line
    printf '%s: refusing to continue.\n' "$(basename -- "$0")" >&2
    for line in "$@"; do
        printf '  %s\n' "$line" >&2
    done
    exit 2
}

FROM=''
OUT=''
BUILD_LOG=''
COMMAND_RECORD=''
POM=''
LABEL=''

# require_value — refuse an option that was given without its value.
#
# Every two-argument case below used to read its value as "${2:-}" and then `shift 2`.
# With the option last on the command line $# is 1, `shift 2` fails without shifting, and
# the loop re-reads the same argument forever: the producer hangs instead of failing, so a
# caller that mistypes an invocation gets no evidence, no error and no exit. Validating the
# arity before the shift turns that into one bounded refusal.
# publish_atomically — rename a fully written staging file over the target.
#
# The authority below used to be produced by redirecting a brace group straight at its
# final path, which truncates that path before the first byte is written. A reader that
# opened the file while the producer was still running, or after it died partway, saw a
# half-written authority indistinguishable from a complete one. Staging beside the target
# and renaming makes publication all-or-nothing: same directory, so the rename is atomic,
# and on any failure the previous file is left exactly as it was. This is the idiom
# capture-static-audit.sh already uses.
publish_atomically()
{
    stage="$1"
    target="$2"

    if [ ! -f "$stage" ]; then
        printf '%s: nothing was staged for %s, so nothing was published.\n' \
            "$(basename -- "$0")" "$target" >&2
        return 1
    fi
    if [ -L "$target" ]; then
        rm -f -- "$stage"
        printf '%s: refusing to publish over %s: it is a symbolic link.\n' \
            "$(basename -- "$0")" "$target" >&2
        return 1
    fi
    if [ -e "$target" ] && [ ! -f "$target" ]; then
        rm -f -- "$stage"
        printf '%s: refusing to publish over %s: it is not a plain file.\n' \
            "$(basename -- "$0")" "$target" >&2
        return 1
    fi
    if ! mv -f -- "$stage" "$target"; then
        rm -f -- "$stage"
        printf '%s: could not move the staged record into place at %s.\n' \
            "$(basename -- "$0")" "$target" >&2
        printf '  The previous file, if any, is untouched.\n' >&2
        return 1
    fi
    return 0
}

require_value()
{
    if [ "$2" -lt 2 ]; then
        printf 'capture-coverage-counters.sh: %s requires a value and none was given.\n' "$1" >&2
        printf '  Refused rather than defaulted to an empty one: an empty path would send\n' >&2
        printf '  this producer at the wrong target, and an empty selector would fall\n' >&2
        printf '  through to a later check that cannot tell "absent" from "empty".\n' >&2
        exit 2
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --from) require_value '--from' "$#"; FROM="$2"; shift 2 ;;
        --out) require_value '--out' "$#"; OUT="$2"; shift 2 ;;
        --build-log) require_value '--build-log' "$#"; BUILD_LOG="$2"; shift 2 ;;
        --command-record) require_value '--command-record' "$#"; COMMAND_RECORD="$2"; shift 2 ;;
        --pom) require_value '--pom' "$#"; POM="$2"; shift 2 ;;
        --label) require_value '--label' "$#"; LABEL="$2"; shift 2 ;;
        -h|--help)
            printf 'usage: %s --from <reactor-root> --out <file> --build-log <file> --command-record <file> [--pom <root-pom>] [--label <text>]\n' "$0" >&2
            exit 2 ;;
        *) fail "unknown argument: $1" ;;
    esac
done

[ -n "$FROM" ] || fail 'no --from reactor root given'
[ -d "$FROM" ] || fail "the reactor root does not exist: ${FROM}"
[ -n "$OUT" ] || fail 'no --out file given'
[ -n "$BUILD_LOG" ] || fail 'no --build-log given'
[ -f "$BUILD_LOG" ] || fail "the build log does not exist: ${BUILD_LOG}"
[ -n "$COMMAND_RECORD" ] || fail 'no --command-record given' \
    '  The exact test invocation must be archived beside the counters.  A coverage' \
    '  figure obtained with the check goal overridden on the command line is a' \
    '  different claim from one obtained with the configured behaviour in force, and' \
    '  a reader cannot tell them apart without the command.'
[ -f "$COMMAND_RECORD" ] || fail "the command record does not exist: ${COMMAND_RECORD}"

FROM_ABS="$(cd "$FROM" && pwd -P)" || fail "could not resolve ${FROM}"
[ -n "$POM" ] || POM="${FROM_ABS}/pom.xml"
[ -f "$POM" ] || fail "the root POM does not exist: ${POM}"

# The configured minimum, read from the build rather than restated here.
MINIMUM="$(sed -n 's|.*<code\.coverage\.minimum>\([^<]*\)</code\.coverage\.minimum>.*|\1|p' "$POM" | head -1)"
[ -n "$MINIMUM" ] || fail "could not read code.coverage.minimum from ${POM}" \
    '  Without the configured threshold there is nothing to compare the measured' \
    '  ratio against, and inventing one here would defeat the purpose of the record.'
JACOCO_VERSION="$(sed -n 's|.*<jacoco\.version>\([^<]*\)</jacoco\.version>.*|\1|p' "$POM" | head -1)"
[ -n "$JACOCO_VERSION" ] || JACOCO_VERSION='unreadable'

# counter_value <report-level-fragment> <TYPE> <missed|covered>
counter_value()
{
    printf '%s' "$1" \
        | tr '>' '\n' \
        | sed -n "s|.*<counter type=\"$2\" .*$3=\"\([0-9]*\)\".*|\1|p" \
        | head -1
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/coverage-counters.XXXXXX")" || fail 'could not create a temporary directory'
trap 'rm -rf -- "$TMP"' EXIT HUP INT TERM

# DOT-DIRECTORIES ARE PRUNED, AND THAT IS NOT A TIDINESS MEASURE.  A reactor root
# can legitimately contain a NESTED extraction of another commit — the throwaway
# tree the pre-migration side is necessarily built in is the obvious example — and
# that tree has its own target/jacoco-reports directories holding execution data
# from a DIFFERENT runtime.  Scanning both at once doubles every count and averages
# two runtimes into one ratio, which looks plausible and is worthless.  That
# happened once while this script was being written: the migrated scan reported 137
# execution data files where the reactor has 69, because it had swept up the
# pre-migration tree sitting in a dotted scratch directory beside it.  No build
# output in this reactor lives under a dotted directory, so pruning them is exact.
find "$FROM_ABS" -name '.*' -type d -prune -o -type f -path '*/target/jacoco-reports/jacoco.exec' -print 2>/dev/null \
    | LC_ALL=C sort > "${TMP}/execs"
exec_total="$(grep -c . "${TMP}/execs" || true)"
[ "${exec_total:-0}" -gt 0 ] || fail "no jacoco.exec found under ${FROM_ABS}" \
    '  Either the test phase did not run, or the coverage agent never attached.  An' \
    '  empty counter archive would misrepresent both.'

exec_nonempty=0
exec_empty=0
exec_bytes_total=0
reports_found=0
reports_missing=0
multi_session=0
below_minimum=0
sum_class_m=0;  sum_class_c=0
sum_method_m=0; sum_method_c=0
sum_line_m=0;   sum_line_c=0
sum_branch_m=0; sum_branch_c=0
sum_instr_m=0;  sum_instr_c=0

: > "${TMP}/rows"
: > "${TMP}/gaps"

while IFS= read -r execfile; do
    module_rel="${execfile#"${FROM_ABS}"/}"
    module_rel="${module_rel%/target/jacoco-reports/jacoco.exec}"
    bytes="$(wc -c < "$execfile" | tr -d '[:space:]')"
    digest="$(sha256sum "$execfile" | awk '{ print $1 }')"
    exec_bytes_total=$((exec_bytes_total + bytes))
    if [ "$bytes" -gt 0 ]; then
        exec_nonempty=$((exec_nonempty + 1))
    else
        exec_empty=$((exec_empty + 1))
    fi

    xml="$(dirname -- "$execfile")/jacoco-output-unit-test/jacoco.xml"
    csv="$(dirname -- "$execfile")/jacoco-output-unit-test/jacoco.csv"
    if [ ! -f "$xml" ]; then
        reports_missing=$((reports_missing + 1))
        printf '%s  NO-REPORT  exec-bytes=%s  exec-sha256=%s\n' "$module_rel" "$bytes" "$digest" >> "${TMP}/gaps"
        continue
    fi
    reports_found=$((reports_found + 1))

    # HOW MANY RUNS THIS EXECUTION DATA DESCRIBES, AND WHY IT IS MEASURED.
    # The coverage agent appends by default, so running the test phase twice leaves ONE
    # exec file containing TWO sessions and roughly twice the bytes.  The counters barely
    # move -- it is the same suite -- so the accumulation is invisible in every figure
    # except the byte total, and a byte total that has silently doubled is exactly the
    # kind of irreconcilable number that made an earlier coverage record untrustworthy.
    # The report the plugin writes records one sessioninfo element per session, so the
    # question is answerable exactly rather than by inference.
    sessions="$(grep -o '<sessioninfo' "$xml" | grep -c . || true)"
    [ -n "$sessions" ] || sessions=0
    if [ "$sessions" -gt 1 ]; then
        multi_session=$((multi_session + 1))
    fi

    if grep -q '</package>' "$xml"; then
        tailpart="$(sed 's|.*</package>||' "$xml")"
    else
        tailpart="$(cat "$xml")"
    fi

    cm="$(counter_value "$tailpart" CLASS missed)";        cc="$(counter_value "$tailpart" CLASS covered)"
    mm="$(counter_value "$tailpart" METHOD missed)";       mc="$(counter_value "$tailpart" METHOD covered)"
    lm="$(counter_value "$tailpart" LINE missed)";         lc="$(counter_value "$tailpart" LINE covered)"
    bm="$(counter_value "$tailpart" BRANCH missed)";       bc="$(counter_value "$tailpart" BRANCH covered)"
    im="$(counter_value "$tailpart" INSTRUCTION missed)";  ic="$(counter_value "$tailpart" INSTRUCTION covered)"
    : "${cm:=0}" "${cc:=0}" "${mm:=0}" "${mc:=0}" "${lm:=0}" "${lc:=0}" "${bm:=0}" "${bc:=0}" "${im:=0}" "${ic:=0}"

    sum_class_m=$((sum_class_m + cm));   sum_class_c=$((sum_class_c + cc))
    sum_method_m=$((sum_method_m + mm)); sum_method_c=$((sum_method_c + mc))
    sum_line_m=$((sum_line_m + lm));     sum_line_c=$((sum_line_c + lc))
    sum_branch_m=$((sum_branch_m + bm)); sum_branch_c=$((sum_branch_c + bc))
    sum_instr_m=$((sum_instr_m + im));   sum_instr_c=$((sum_instr_c + ic))

    line_total=$((lm + lc))
    if [ "$line_total" -gt 0 ]; then
        ratio="$(awk -v c="$lc" -v t="$line_total" 'BEGIN { printf "%.5f", c / t }')"
        verdict="$(awk -v r="$ratio" -v m="$MINIMUM" 'BEGIN { print (r + 0 >= m + 0) ? "AT-OR-ABOVE-MINIMUM" : "BELOW-MINIMUM" }')"
        [ "$verdict" = 'BELOW-MINIMUM' ] && below_minimum=$((below_minimum + 1))
    else
        ratio='n/a'
        verdict='NO-LINES-ANALYSED'
    fi

    csv_digest='absent'
    [ -f "$csv" ] && csv_digest="$(sha256sum "$csv" | awk '{ print $1 }')"

    {
        printf 'module: %s\n' "$module_rel"
        printf '  exec-bytes: %s\n' "$bytes"
        printf '  exec-sha256: %s\n' "$digest"
        printf '  sessions-in-execution-data: %s\n' "$sessions"
        printf '  report-xml-sha256: %s\n' "$(sha256sum "$xml" | awk '{ print $1 }')"
        printf '  report-csv-sha256: %s\n' "$csv_digest"
        printf '  CLASS       missed=%-7s covered=%s\n' "$cm" "$cc"
        printf '  METHOD      missed=%-7s covered=%s\n' "$mm" "$mc"
        printf '  LINE        missed=%-7s covered=%s\n' "$lm" "$lc"
        printf '  BRANCH      missed=%-7s covered=%s\n' "$bm" "$bc"
        printf '  INSTRUCTION missed=%-7s covered=%s\n' "$im" "$ic"
        printf '  line-covered-ratio: %s   against configured minimum %s   %s\n' "$ratio" "$MINIMUM" "$verdict"
    } >> "${TMP}/rows"
done < "${TMP}/execs"

grep -F 'All coverage checks have been met' "$BUILD_LOG" > "${TMP}/check-met" 2>/dev/null || true
grep -F 'Rule violated' "$BUILD_LOG" > "${TMP}/check-violated" 2>/dev/null || true
grep -F 'Coverage checks have not been met' "$BUILD_LOG" > "${TMP}/check-failed" 2>/dev/null || true
grep -F 'Analyzed bundle' "$BUILD_LOG" > "${TMP}/check-bundles" 2>/dev/null || true
met_count="$(grep -c . "${TMP}/check-met" || true)"
violated_count="$(grep -c . "${TMP}/check-violated" || true)"
failed_count="$(grep -c . "${TMP}/check-failed" || true)"
bundle_count="$(grep -c . "${TMP}/check-bundles" || true)"

halt_override='absent -- the invocation did not set jacoco.haltOnFailure, so the plugin default governed'
if grep -q -- '-Djacoco.haltOnFailure=' "$COMMAND_RECORD"; then
    halt_override="present -- the invocation carried $(grep -o -- '-Djacoco\.haltOnFailure=[^ ]*' "$COMMAND_RECORD" | head -1)"
fi

ratio_of()
{
    awk -v m="$1" -v c="$2" 'BEGIN { t = m + c; if (t == 0) { print "n/a" } else { printf "%.5f", c / t } }'
}

{
    printf 'coverage counters and check verdict\n'
    printf '\n'
    printf 'produced-by: docs/migration/smoke-evidence/capture-coverage-counters.sh\n'
    printf 'capture-label: %s\n' "${LABEL:-unlabelled}"
    printf 'reactor-root-scanned: the root this capture was pointed at; absolute paths are\n'
    printf '  deliberately not published here, and every module below is named by its path\n'
    printf '  RELATIVE to that root so the two sides of the comparison line up\n'
    printf 'coverage-plugin-version: %s   read from the POM, not asserted here\n' "$JACOCO_VERSION"
    printf 'configured-minimum: %s   read from code.coverage.minimum in the POM this capture was pointed at\n' "$MINIMUM"
    printf 'rule-under-evaluation: element BUNDLE, counter LINE, value COVEREDRATIO, minimum as above\n'
    printf '\n'
    printf 'WHAT THIS RECORD PROVES THAT A BYTE TOTAL CANNOT.  Execution-data size proves the\n'
    printf 'agent attached.  The counters below prove what the attached agent MEASURED, and\n'
    printf 'the ratio on each row is computed from that module report by the same arithmetic\n'
    printf 'the rule uses.  Both facts are needed: without the first a ratio could have been\n'
    printf 'computed over an empty data set, and without the second a live data set says\n'
    printf 'nothing about whether the minimum was cleared.\n'
    printf '\n'
    printf 'THE COUNTERS ARE BOUND TO THE DATA THEY CAME FROM.  Every row carries the SHA-256\n'
    printf 'of the module jacoco.exec alongside the digests of the report files computed from\n'
    printf 'it.  A counter table published without that binding can be regenerated from a\n'
    printf 'later run while an older digest sits beside it, and nothing in either would show\n'
    printf 'it; these rows cannot drift apart from their source without the digests changing.\n'
    printf '\n'
    printf '===== the invocation, as a program recorded it =====\n'
    printf 'The argument vector below was written by the shell that ran the build, one\n'
    printf 'argument per line.  It is archived because the check goal can be overridden from\n'
    printf 'the command line, and a coverage verdict obtained under an override is a different\n'
    printf 'claim from one obtained under the configured behaviour.\n'
    sed 's/^/  /' "$COMMAND_RECORD"
    printf 'halt-on-failure-override-in-invocation: %s\n' "$halt_override"
    printf 'plugin-default-for-haltOnFailure: true -- the goal descriptor of the pinned\n'
    printf '  coverage plugin declares default-value="true" for haltOnFailure and its check\n'
    printf '  goal raises a build failure when a rule is violated.  So a coverage shortfall\n'
    printf '  DOES fail the build unless an invocation overrides it, and a commented-out\n'
    printf '  override in the POM leaves the failing behaviour in force rather than removing\n'
    printf '  it.  This is stated because the opposite was once recorded here, and the two\n'
    printf '  readings lead to opposite conclusions about what a passing build means.\n'
    printf '\n'
    printf '===== execution data =====\n'
    printf 'execution-data-files-found: %s\n' "$exec_total"
    printf 'execution-data-files-non-empty: %s\n' "$exec_nonempty"
    printf 'execution-data-files-empty: %s\n' "$exec_empty"
    printf 'execution-data-total-bytes: %s\n' "$exec_bytes_total"
    printf 'module-reports-found: %s\n' "$reports_found"
    printf 'module-reports-absent: %s\n' "$reports_missing"
    printf 'modules-whose-execution-data-carries-more-than-one-session: %s\n' "$multi_session"
    printf 'A module with more than one session has accumulated data from more than one test\n'
    printf 'phase, because the coverage agent appends by default.  The counters barely move when\n'
    printf 'that happens -- it is the same suite -- so the accumulation shows up only in the byte\n'
    printf 'total, which is precisely the kind of unexplainable number that made an earlier\n'
    printf 'coverage record impossible to reconcile.  Zero here means every figure below describes\n'
    printf 'exactly one run of the suite.\n'
    printf '\n'
    printf '===== aggregate counters, summed over every module report above =====\n'
    printf 'CLASS       missed=%-8s covered=%-8s covered-ratio=%s\n' "$sum_class_m"  "$sum_class_c"  "$(ratio_of "$sum_class_m" "$sum_class_c")"
    printf 'METHOD      missed=%-8s covered=%-8s covered-ratio=%s\n' "$sum_method_m" "$sum_method_c" "$(ratio_of "$sum_method_m" "$sum_method_c")"
    printf 'LINE        missed=%-8s covered=%-8s covered-ratio=%s\n' "$sum_line_m"   "$sum_line_c"   "$(ratio_of "$sum_line_m" "$sum_line_c")"
    printf 'BRANCH      missed=%-8s covered=%-8s covered-ratio=%s\n' "$sum_branch_m" "$sum_branch_c" "$(ratio_of "$sum_branch_m" "$sum_branch_c")"
    printf 'INSTRUCTION missed=%-8s covered=%-8s covered-ratio=%s\n' "$sum_instr_m"  "$sum_instr_c"  "$(ratio_of "$sum_instr_m" "$sum_instr_c")"
    printf '\n'
    printf 'modules-with-line-ratio-below-configured-minimum: %s\n' "$below_minimum"
    printf 'NOTE ON THE AGGREGATE.  The rule the build evaluates is BUNDLE-scoped, so it is\n'
    printf 'applied once per module and never to the sum.  The aggregate above is therefore a\n'
    printf 'summary for a reader and NOT the quantity the rule tested; the per-module verdicts\n'
    printf 'are, and the count of modules below the minimum is the figure that corresponds to\n'
    printf 'the rule.  Both are published so neither can be mistaken for the other.\n'
    printf '\n'
    printf '===== the check goal, in its own words =====\n'
    printf 'lines-reading-Analyzed-bundle: %s   counted as they appear; the report goal and the\n' "$bundle_count"
    printf '  check goal each announce the bundle they analysed, so this figure is roughly twice\n'
    printf '  the module count by construction and is NOT a module count\n'
    printf 'lines-reading-All-coverage-checks-have-been-met: %s\n' "$met_count"
    printf 'lines-reading-Rule-violated: %s\n' "$violated_count"
    printf 'lines-reading-Coverage-checks-have-not-been-met: %s\n' "$failed_count"
    if [ "${violated_count:-0}" -gt 0 ] || [ "${failed_count:-0}" -gt 0 ]; then
        printf '\nevery violation line, verbatim:\n'
        sed 's/^/  /' "${TMP}/check-violated"
        sed 's/^/  /' "${TMP}/check-failed"
    else
        printf 'no violation line of either shape appears in the build log.\n'
    fi
    printf '\n'
    if [ "${reports_missing:-0}" -gt 0 ]; then
        printf '===== modules whose execution data has no matching report =====\n'
        printf 'Listed rather than dropped: a module that produced coverage data but no report\n'
        printf 'cannot contribute counters, and silently omitting it would make the aggregate\n'
        printf 'above describe fewer modules than the execution-data count implies.\n'
        sed 's/^/  /' "${TMP}/gaps"
        printf '\n'
    fi
    printf '===== per-module counters, one block per module, sorted by module path =====\n'
    cat "${TMP}/rows"
} > "${OUT}.$$.staging"
publish_status=$?
if [ "$publish_status" -ne 0 ]; then
    rm -f -- "${OUT}.$$.staging"
    printf '%s: the record was not written completely, so %s was left untouched.\n' \
        "$(basename -- "$0")" "$OUT" >&2
    exit "$publish_status"
fi
publish_atomically "${OUT}.$$.staging" "$OUT" || exit 1

printf 'capture-coverage-counters.sh: wrote %s\n' "$OUT"
printf '  execution data: %s found, %s non-empty, %s bytes\n' "$exec_total" "$exec_nonempty" "$exec_bytes_total"
printf '  aggregate LINE: missed=%s covered=%s ratio=%s against minimum %s\n' \
    "$sum_line_m" "$sum_line_c" "$(ratio_of "$sum_line_m" "$sum_line_c")" "$MINIMUM"
printf '  modules below the configured minimum: %s\n' "$below_minimum"
printf '  check goal: %s met, %s violated, %s failed\n' "$met_count" "$violated_count" "$failed_count"

# ---------------------------------------------------------------------------
# FAIL CLOSED ON THE THREE CONDITIONS THAT MAKE THIS RECORD UNUSABLE AS EVIDENCE.
#
# This producer used to end here, so it exited zero whatever it had found: an empty
# execution-data set, a module whose data produced no report, and an invocation that
# overrode the coverage check all left a written record and a success status. A record
# that says "instrumentation was not live" while its producer reports success is worse
# than no record, because a caller that only reads the exit status is told the opposite
# of what the file says.
#
# The record is still written in every case - the measurements are what a reader needs -
# and only the status changes. COVERAGE_EVIDENCE_ACCEPT_OVERRIDE=yes acknowledges the
# third condition explicitly for a caller that genuinely wants counters from an
# overridden run; it cannot suppress the first two, which are not a matter of intent.
# ---------------------------------------------------------------------------
evidence_status=0

if [ "${exec_nonempty:-0}" -eq 0 ]; then
    printf '%s: FAIL CLOSED -- no module produced non-empty coverage execution data,\n' \
        "$(basename -- "$0")" >&2
    printf '  so every counter in %s was computed over an empty data set.\n' "$OUT" >&2
    evidence_status=1
fi

if [ "${reports_missing:-0}" -gt 0 ]; then
    printf '%s: FAIL CLOSED -- %s module(s) produced coverage execution data but no\n' \
        "$(basename -- "$0")" "$reports_missing" >&2
    printf '  report, so the aggregate in %s describes fewer modules than the execution\n' "$OUT" >&2
    printf '  data implies.  The affected modules are listed in the record.\n' >&2
    evidence_status=1
fi

case "$halt_override" in
    present*)
        if [ "${COVERAGE_EVIDENCE_ACCEPT_OVERRIDE:-no}" = 'yes' ]; then
            printf '%s: the invocation overrode the coverage check and the caller\n' \
                "$(basename -- "$0")" >&2
            printf '  acknowledged it with COVERAGE_EVIDENCE_ACCEPT_OVERRIDE=yes.  The override is\n' >&2
            printf '  recorded in %s either way.\n' "$OUT" >&2
        else
            printf '%s: FAIL CLOSED -- %s\n' "$(basename -- "$0")" "$halt_override" >&2
            printf '  A coverage verdict obtained under an override is a different claim from one\n' >&2
            printf '  obtained under the configured behaviour, so this producer will not report\n' >&2
            printf '  success for it.  Re-run the build without the override, or set\n' >&2
            printf '  COVERAGE_EVIDENCE_ACCEPT_OVERRIDE=yes to acknowledge it deliberately.\n' >&2
            evidence_status=1
        fi
        ;;
esac

exit "$evidence_status"
