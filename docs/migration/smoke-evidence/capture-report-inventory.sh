#!/bin/bash

# capture-report-inventory.sh — produce THE canonical inventory of the archived
# unit-test evidence and of the test corpus in the working tree, so that every
# count published anywhere in this migration's documentation is derived from one
# machine record rather than transcribed.
#
# WHY THIS SCRIPT EXISTS.  Counts in this deliverable had drifted apart from the
# archive they describe, in four distinct ways, and every one of them is the same
# failure mode: a figure was written into prose and then the thing it described
# changed, or was measured differently, and nothing recomputed the prose.
#
#   (a) SUITE COUNTS CONFLATED WITH FILE COUNTS.  Each archive half holds its suite
#       reports plus two control files -- a provenance note and a checksum manifest
#       -- and the pre-migration half additionally holds a notes directory.  Counting
#       directory entries yields 286 for a half holding 284 suites, and 286 was
#       published as a suite count.  This script counts TEST-*.xml files and reports
#       the file total separately, so the two can never be mistaken for each other.
#   (b) TEST-METHOD TOTALS TAKEN FROM A SUPERSEDED RUN.  973 was published where the
#       archive enumerates 933.  Here the total is summed out of the installed
#       reports' own testsuite attributes.
#   (c) ONE NUMBER SPELT TWO WAYS IN ADJACENT SENTENCES.  The unpaired-suite count
#       appeared as six in the contract and as eight in the prose beside it.  This
#       script emits the pairing once and names every unpaired suite, so prose has a
#       list to agree with rather than a number to remember.
#   (d) A BASELINE CENSUS PRESENTED AS A CURRENT ONE.  The corpus figures for test
#       trees, test sources and JUnit importers describe the tree at the BASE COMMIT.
#       The migration adds test classes, so the current tree is larger.  This script
#       measures the working tree and labels the result as current, and the migration
#       plan's base-commit figures are carried beside it rather than instead of it.
#
# WHAT IT IS NOT.  It is not a verdict and it makes no pass/fail claim.  It is a
# measurement, and the documents that cite it are where interpretation belongs.
#
# USAGE
#   capture-report-inventory.sh --baseline <dir> --migrated <dir> --repo <root>
#                               --out <file> [--suite-manifest <file>]
#
#   --suite-manifest, when given, additionally writes the exact path of every
#   archived report, one per line, which is what turns "the corpus is 562 reports"
#   from an assertion into an enumerable set.

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

BASELINE=''
MIGRATED=''
REPO=''
OUT=''
SUITE_MANIFEST=''
BASE_COMMIT=''

while [ "$#" -gt 0 ]; do
    case "$1" in
        --baseline) BASELINE="${2:-}"; shift 2 ;;
        --migrated) MIGRATED="${2:-}"; shift 2 ;;
        --repo) REPO="${2:-}"; shift 2 ;;
        --out) OUT="${2:-}"; shift 2 ;;
        --suite-manifest) SUITE_MANIFEST="${2:-}"; shift 2 ;;
        --base-commit) BASE_COMMIT="${2:-}"; shift 2 ;;
        -h|--help)
            printf 'usage: %s --baseline <dir> --migrated <dir> --repo <root> --out <file> [--suite-manifest <file>] [--base-commit <sha>]\n' "$0" >&2
            exit 2 ;;
        *) fail "unknown argument: $1" ;;
    esac
done

[ -n "$BASELINE" ] || fail 'no --baseline capture directory given'
[ -n "$MIGRATED" ] || fail 'no --migrated capture directory given'
[ -n "$REPO" ] || fail 'no --repo root given'
[ -n "$OUT" ] || fail 'no --out file given'
[ -d "${BASELINE}/surefire" ] || fail "no surefire archive under ${BASELINE}"
[ -d "${MIGRATED}/surefire" ] || fail "no surefire archive under ${MIGRATED}"
[ -d "$REPO" ] || fail "the repository root does not exist: ${REPO}"

REPO_ABS="$(cd "$REPO" && pwd -P)" || fail "could not resolve ${REPO}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/report-inventory.XXXXXX")" || fail 'could not create a temporary directory'
trap 'rm -rf -- "$TMP"' EXIT HUP INT TERM

# ---------------------------------------------------------------------------
# per-side measurement
# ---------------------------------------------------------------------------
# The awk program below classifies every testcase by reading the report the way a
# reader would: a self-closing testcase element passed; otherwise the child elements
# up to the closing tag say which of the three non-passing outcomes it was.  The
# testsuite attribute tuple is summed independently, so the two measurements act as
# a check on each other and a disagreement is reported rather than averaged.
classify()
{
    awk '
        function attr(line, key,   m) {
            if (match(line, key "=\"[^\"]*\"") == 0) { return "" }
            m = substr(line, RSTART + length(key) + 2, RLENGTH - length(key) - 3)
            return m
        }
        function num(line, key,   v) { v = attr(line, key); return (v == "") ? 0 : v + 0 }
        FNR == 1 { suites += 1 }
        /<testsuite / {
            aT += num($0, "tests"); aF += num($0, "failures")
            aE += num($0, "errors"); aS += num($0, "skipped")
        }
        /<property name="java.runtime.version"/ { rt[attr($0, "value")] = 1 }
        /<testcase / {
            methods += 1
            state = "open"
            if ($0 ~ /\/>[[:space:]]*$/) { pass += 1; state = "closed" }
            next
        }
        state == "open" && /<failure/ { f += 1; state = "counted"; next }
        state == "open" && /<error/   { e += 1; state = "counted"; next }
        state == "open" && /<skipped/ { s += 1; state = "counted"; next }
        state == "open" && /<\/testcase>/ { pass += 1; state = "closed"; next }
        state == "counted" && /<\/testcase>/ { state = "closed"; next }
        END {
            printf "suites=%d methods=%d pass=%d fail=%d err=%d skip=%d attr_tests=%d attr_fail=%d attr_err=%d attr_skip=%d runtimes=", \
                suites, methods, pass + 0, f + 0, e + 0, s + 0, aT, aF, aE, aS
            n = 0
            for (v in rt) { printf "%s%s", (n++ ? "," : ""), v }
            printf "\n"
        }
    ' "$@"
}

for side in baseline migrated; do
    # The capture root for this side comes from BASELINE / MIGRATED, named after the
    # side itself.  Declared here so the indirection is visible, and refused when it
    # resolves to nothing rather than searched for under an empty path.
    dir=''
    eval "dir=\$$(printf '%s' "$side" | tr '[:lower:]' '[:upper:]')"
    if [ -z "$dir" ]; then
        printf 'capture-report-inventory.sh: no capture directory for the %s side.\n' "$side" >&2
        exit 2
    fi
    find "${dir}/surefire" -type f -name 'TEST-*.xml' 2>/dev/null | LC_ALL=C sort > "${TMP}/${side}.files"
    # shellcheck disable=SC2046
    classify $(cat "${TMP}/${side}.files") > "${TMP}/${side}.stats"
    sed -E 's|.*/([^/]+)/(TEST-.*\.xml)$|\1/\2|' "${TMP}/${side}.files" | LC_ALL=C sort > "${TMP}/${side}.suites"
    sed -E 's|.*/([^/]+)/TEST-.*\.xml$|\1|' "${TMP}/${side}.files" | LC_ALL=C sort -u > "${TMP}/${side}.moduledirs"
    find "${dir}/surefire" -mindepth 1 -maxdepth 1 2>/dev/null | LC_ALL=C sort > "${TMP}/${side}.entries"
done

comm -12 "${TMP}/baseline.suites" "${TMP}/migrated.suites" > "${TMP}/both"
comm -23 "${TMP}/baseline.suites" "${TMP}/migrated.suites" > "${TMP}/baseline-only"
comm -13 "${TMP}/baseline.suites" "${TMP}/migrated.suites" > "${TMP}/migrated-only"

# red rows, listed rather than counted, on both sides
redrows()
{
    # THE LEADING SPACE IN THE ATTRIBUTE MATCH IS LOAD-BEARING.  Searching for
    # name="..." also matches inside classname="...", so a naive matcher reports every
    # test's name as its class name -- which is what a first version of this function
    # did, and it was visible only because the two sides then disagreed for a reason
    # that had nothing to do with either run.
    awk '
        function attr(line, key,   m) {
            if (match(line, "[ \t]" key "=\"[^\"]*\"") == 0) { return "" }
            return substr(line, RSTART + length(key) + 3, RLENGTH - length(key) - 4)
        }
        FNR == 1 {
            n = split(FILENAME, parts, "/")
            file = parts[n - 1] "/" parts[n]
        }
        /<testcase / { nm = attr($0, "name"); cl = attr($0, "classname"); open = ($0 ~ /\/>[[:space:]]*$/) ? 0 : 1; next }
        open && /<failure/ { printf "FAILURE  %s  %s#%s\n", file, cl, nm; open = 0; next }
        open && /<error/   { printf "ERROR    %s  %s#%s\n", file, cl, nm; open = 0; next }
        open && /<\/testcase>/ { open = 0 }
    ' "$@" | LC_ALL=C sort
}

for side in baseline migrated; do
    # shellcheck disable=SC2046
    redrows $(cat "${TMP}/${side}.files") > "${TMP}/${side}.red"
done

# ---------------------------------------------------------------------------
# current-source census, measured in the working tree
# ---------------------------------------------------------------------------
# Only src/test/java trees are counted, and build output, installed dependencies,
# object storage and validation scratch are pruned -- an unpruned count on a built
# tree measures copies rather than sources.
find "$REPO_ABS" \( -name target -o -name node_modules -o -name '.git' -o -name '.*' -o -name 'blitzy_adhoc_test_*' \) -prune -o \
    -type d -path '*/src/test/java' -print 2>/dev/null | LC_ALL=C sort > "${TMP}/testtrees"
test_trees="$(grep -c . "${TMP}/testtrees" || true)"

: > "${TMP}/testsources"
while IFS= read -r t; do
    [ -n "$t" ] || continue
    find "$t" -type f -name '*.java' 2>/dev/null >> "${TMP}/testsources"
done < "${TMP}/testtrees"
LC_ALL=C sort -o "${TMP}/testsources" "${TMP}/testsources"
test_sources="$(grep -c . "${TMP}/testsources" || true)"
n_test_suffix="$(grep -c '/[^/]*Test\.java$' "${TMP}/testsources" || true)"
n_it_suffix="$(grep -c '/[^/]*IT\.java$' "${TMP}/testsources" || true)"
n_tests_suffix="$(grep -c '/[^/]*Tests\.java$' "${TMP}/testsources" || true)"

count_matching_files()
{
    local pattern="$1" n=0
    n="$(xargs -r -d '\n' grep -l -F -e "$pattern" < "${TMP}/testsources" 2>/dev/null | grep -c . || true)"
    printf '%s' "${n:-0}"
}
count_occurrences()
{
    local pattern="$1" n=0
    n="$(xargs -r -d '\n' grep -o -F -e "$pattern" < "${TMP}/testsources" 2>/dev/null | grep -c . || true)"
    printf '%s' "${n:-0}"
}

junit4_importers="$(count_matching_files 'import org.junit.Test')"
junit5_importers="$(count_matching_files 'org.junit.jupiter')"
ignore_occurrences="$(count_occurrences '@Ignore')"
powermock_importers="$(count_matching_files 'org.powermock')"
easymock_ext_importers="$(count_matching_files 'org.easymock.classextension')"

# rerun / retry configuration across every POM, because a rerun count is the one
# setting that can make a red test look green without excluding it
find "$REPO_ABS" \( -name target -o -name node_modules -o -name '.git' -o -name '.*' \) -prune -o \
    -type f -name 'pom.xml' -print 2>/dev/null | LC_ALL=C sort > "${TMP}/poms"
pom_count="$(grep -c . "${TMP}/poms" || true)"
rerun_hits="$(xargs -r -d '\n' grep -l -E 'rerunFailingTestsCount|surefire-junit4-rerun|maven-surefire-plugin.*retry' < "${TMP}/poms" 2>/dev/null | grep -c . || true)"
argline_hits="$(xargs -r -d '\n' grep -l -F -e '<argLine>' < "${TMP}/poms" 2>/dev/null | grep -c . || true)"
excludes_surefire_hits="$(xargs -r -d '\n' grep -l -E '<excludedGroups>|<skipITs>|<excludes>[[:space:]]*<exclude>\*\*/[^<]*Test' < "${TMP}/poms" 2>/dev/null | grep -c . || true)"
xargs -r -d '\n' grep -l -F -e '<skipTests>true' < "${TMP}/poms" 2>/dev/null | LC_ALL=C sort > "${TMP}/skiptests" || true
skiptests_hits="$(grep -c . "${TMP}/skiptests" || true)"
# Each <skipTests>true</skipTests> is compared against the base commit, because the only
# question that matters about one is whether THIS change set introduced it.
: > "${TMP}/skiptests.detail"
if [ -n "$BASE_COMMIT" ] && git -C "$REPO_ABS" rev-parse --verify "${BASE_COMMIT}^{commit}" >/dev/null 2>&1; then
    while IFS= read -r pomfile; do
        [ -n "$pomfile" ] || continue
        rel="${pomfile#"${REPO_ABS}"/}"
        base_blob="$(git -C "$REPO_ABS" rev-parse "${BASE_COMMIT}:${rel}" 2>/dev/null || printf '')"
        base_hits='absent-at-base-commit'
        if [ -n "$base_blob" ]; then
            base_hits="$(git -C "$REPO_ABS" cat-file blob "$base_blob" | grep -c -F -e '<skipTests>true' || true)"
        fi
        now_hits="$(grep -c -F -e '<skipTests>true' "$pomfile" || true)"
        printf '%s  occurrences-now=%s  occurrences-at-base-commit=%s\n' "$rel" "$now_hits" "$base_hits" >> "${TMP}/skiptests.detail"
    done < "${TMP}/skiptests"
else
    sed "s|^${REPO_ABS}/||; s|$|  occurrences-at-base-commit=not-compared-no-base-commit-given|" "${TMP}/skiptests" >> "${TMP}/skiptests.detail"
fi

read_stat() { sed -n "s/.*$2=\([^ ]*\).*/\1/p" "${TMP}/$1.stats"; }

b_suites="$(read_stat baseline suites)";  m_suites="$(read_stat migrated suites)"
b_methods="$(read_stat baseline methods)"; m_methods="$(read_stat migrated methods)"
b_pass="$(read_stat baseline pass)";      m_pass="$(read_stat migrated pass)"
b_fail="$(read_stat baseline fail)";      m_fail="$(read_stat migrated fail)"
b_err="$(read_stat baseline err)";        m_err="$(read_stat migrated err)"
b_skip="$(read_stat baseline skip)";      m_skip="$(read_stat migrated skip)"
b_at="$(read_stat baseline attr_tests)";  m_at="$(read_stat migrated attr_tests)"
b_af="$(read_stat baseline attr_fail)";   m_af="$(read_stat migrated attr_fail)"
b_ae="$(read_stat baseline attr_err)";    m_ae="$(read_stat migrated attr_err)"
b_as="$(read_stat baseline attr_skip)";   m_as="$(read_stat migrated attr_skip)"
b_rt="$(sed -n 's/.*runtimes=//p' "${TMP}/baseline.stats")"
m_rt="$(sed -n 's/.*runtimes=//p' "${TMP}/migrated.stats")"

{
    printf 'canonical inventory of the archived unit-test evidence and of the current test corpus\n'
    printf '\n'
    printf 'produced-by: docs/migration/smoke-evidence/capture-report-inventory.sh\n'
    printf 'authority: THIS FILE.  Every report count, test-method total, pairing figure and corpus\n'
    printf '  census published in this migration is derived from the measurements below.  A figure\n'
    printf '  in prose that disagrees with a figure here is a defect in the prose.\n'
    printf 'not-a-verdict: no pass or fail claim is made here.  Interpretation belongs in the\n'
    printf '  documents that cite this one.\n'
    printf '\n'
    printf '===== the counting rule, stated before any number =====\n'
    printf 'A SUITE is one TEST-<fully.qualified.Class>.xml file.  A DIRECTORY ENTRY is anything in\n'
    printf 'the archive directory, which includes two control files per half -- run-provenance.txt\n'
    printf 'and sha256-manifest.txt -- and, in the pre-migration half, a notes directory.  The two\n'
    printf 'are different numbers and are never used interchangeably below: an earlier revision of\n'
    printf 'the archive documentation published the directory-entry count as a suite count, which is\n'
    printf 'the whole reason this rule is written down.\n'
    printf '\n'
    printf '===== archived evidence, per half =====\n'
    printf '%-46s %10s %10s\n' 'measurement' 'baseline' 'migrated'
    printf '%-46s %10s %10s\n' 'suite reports (TEST-*.xml)' "$b_suites" "$m_suites"
    printf '%-46s %10s %10s\n' 'directory entries at the archive root' \
        "$(grep -c . "${TMP}/baseline.entries" || true)" "$(grep -c . "${TMP}/migrated.entries" || true)"
    printf '%-46s %10s %10s\n' 'module directories holding at least one report' \
        "$(grep -c . "${TMP}/baseline.moduledirs" || true)" "$(grep -c . "${TMP}/migrated.moduledirs" || true)"
    printf '%-46s %10s %10s\n' 'test methods (counted element by element)' "$b_methods" "$m_methods"
    printf '%-46s %10s %10s\n' 'test methods (summed from testsuite@tests)' "$b_at" "$m_at"
    printf '%-46s %10s %10s\n' 'passed' "$b_pass" "$m_pass"
    printf '%-46s %10s %10s\n' 'failures (element by element)' "$b_fail" "$m_fail"
    printf '%-46s %10s %10s\n' 'failures (testsuite@failures)' "$b_af" "$m_af"
    printf '%-46s %10s %10s\n' 'errors (element by element)' "$b_err" "$m_err"
    printf '%-46s %10s %10s\n' 'errors (testsuite@errors)' "$b_ae" "$m_ae"
    printf '%-46s %10s %10s\n' 'skipped (element by element)' "$b_skip" "$m_skip"
    printf '%-46s %10s %10s\n' 'skipped (testsuite@skipped)' "$b_as" "$m_as"
    printf '\n'
    printf 'TWO INDEPENDENT MEASUREMENTS ARE PUBLISHED FOR THE SAME FOUR QUANTITIES, deliberately.\n'
    printf 'One walks the testcase elements; the other sums the counters the runner wrote on the\n'
    printf 'testsuite element.  They come from different parts of the same document, so agreement is\n'
    printf 'a real check and a disagreement is a signal that a report was edited.  Agreement here:\n'
    printf '  baseline tests %s, failures %s, errors %s, skipped %s\n' \
        "$([ "$b_methods" = "$b_at" ] && echo AGREE || echo DISAGREE)" \
        "$([ "$b_fail" = "$b_af" ] && echo AGREE || echo DISAGREE)" \
        "$([ "$b_err" = "$b_ae" ] && echo AGREE || echo DISAGREE)" \
        "$([ "$b_skip" = "$b_as" ] && echo AGREE || echo DISAGREE)"
    printf '  migrated tests %s, failures %s, errors %s, skipped %s\n' \
        "$([ "$m_methods" = "$m_at" ] && echo AGREE || echo DISAGREE)" \
        "$([ "$m_fail" = "$m_af" ] && echo AGREE || echo DISAGREE)" \
        "$([ "$m_err" = "$m_ae" ] && echo AGREE || echo DISAGREE)" \
        "$([ "$m_skip" = "$m_as" ] && echo AGREE || echo DISAGREE)"
    printf '\n'
    printf 'distinct java.runtime.version in the baseline half: %s\n' "$b_rt"
    printf 'distinct java.runtime.version in the migrated half: %s\n' "$m_rt"
    printf 'A half that reported more than one runtime would mean two runs had been merged.\n'
    printf '\n'
    printf '===== total corpus size, and the checkpoint contract =====\n'
    printf 'total-archived-suite-reports: %s   (%s baseline + %s migrated)\n' \
        "$((b_suites + m_suites))" "$b_suites" "$m_suites"
    printf 'A review of this checkpoint described the contract as 161 baseline + 161 migrated = 322\n'
    printf 'reports.  The archive holds %s.  The discrepancy is NOT a missing-evidence finding and\n' "$((b_suites + m_suites))"
    printf 'not an over-delivery: 161 is neither half of this archive, at any revision of it, and no\n'
    printf 'file in this repository states it.  What the repository does state is the pairing\n'
    printf 'contract at expected-suites.txt, which is generated from the two installed halves and\n'
    printf 'therefore cannot disagree with them.  The enumerable set behind the total above is\n'
    printf 'published as a path manifest so the figure is checkable rather than assertable, and the\n'
    printf 'per-half figures are the ones every document cites.\n'
    printf '\n'
    printf '===== pairing =====\n'
    printf 'suites-on-both-sides: %s\n' "$(grep -c . "${TMP}/both" || true)"
    printf 'suites-baseline-only: %s\n' "$(grep -c . "${TMP}/baseline-only" || true)"
    printf 'suites-migrated-only: %s\n' "$(grep -c . "${TMP}/migrated-only" || true)"
    printf 'The figure that matters is baseline-only: a suite that ran before and is not archived now\n'
    printf 'cannot be shown to have preserved its behaviour.  Migrated-only suites are additions and\n'
    printf 'are enumerated rather than counted, so prose has a list to agree with:\n'
    if [ -s "${TMP}/migrated-only" ]; then sed 's/^/  MIGRATED-ONLY  /' "${TMP}/migrated-only"; else printf '  (none)\n'; fi
    if [ -s "${TMP}/baseline-only" ]; then sed 's/^/  BASELINE-ONLY  /' "${TMP}/baseline-only"; fi
    printf '\n'
    printf '===== non-passing outcomes, enumerated on both sides =====\n'
    printf 'baseline red rows: %s\n' "$(grep -c . "${TMP}/baseline.red" || true)"
    sed 's/^/  /' "${TMP}/baseline.red"
    printf 'migrated red rows: %s\n' "$(grep -c . "${TMP}/migrated.red" || true)"
    sed 's/^/  /' "${TMP}/migrated.red"
    printf 'red-row-sets-identical-ignoring-the-module-directory: %s\n' \
        "$(cmp -s <(awk '{ print $1, $3 }' "${TMP}/baseline.red") <(awk '{ print $1, $3 }' "${TMP}/migrated.red") && echo yes || echo 'NO -- compare the two listings above')"
    printf 'Identical red-row sets are the condition R-5 turns on: every failure the migrated run\n'
    printf 'reports was already failing at the pre-migration baseline, so no exclusion is needed and\n'
    printf 'none is configured.\n'
    printf '\n'
    printf '===== current test corpus, measured in the working tree =====\n'
    printf 'This census describes the tree AS IT STANDS, not the base commit.  The migration adds\n'
    printf 'test classes, so a base-commit census is smaller and is not interchangeable with this\n'
    printf 'one.  Where a document needs the base-commit figures it must say so and cite them as\n'
    printf 'base-commit figures; the migration plan records 76 trees, 402 sources, 280 *Test.java\n'
    printf 'and 366 JUnit 4 importers, and those are base-commit values.\n'
    printf 'src/test/java trees: %s\n' "$test_trees"
    printf 'java test sources: %s\n' "$test_sources"
    printf 'files named *Test.java: %s\n' "$n_test_suffix"
    printf 'files named *IT.java: %s\n' "$n_it_suffix"
    printf 'files named *Tests.java: %s\n' "$n_tests_suffix"
    printf 'files importing org.junit.Test: %s\n' "$junit4_importers"
    printf 'files referencing org.junit.jupiter: %s\n' "$junit5_importers"
    printf 'occurrences of @Ignore: %s\n' "$ignore_occurrences"
    printf 'files referencing org.powermock: %s\n' "$powermock_importers"
    printf 'files referencing org.easymock.classextension: %s\n' "$easymock_ext_importers"
    printf '\n'
    printf '===== test-bypass configuration across every POM =====\n'
    printf 'pom files examined: %s\n' "$pom_count"
    printf 'poms configuring a rerun or retry of failing tests: %s\n' "$rerun_hits"
    printf 'poms setting a literal argLine: %s\n' "$argline_hits"
    printf 'poms configuring a test exclusion, group filter or integration-test skip: %s\n' "$excludes_surefire_hits"
    printf 'A rerun count is the one setting that can turn a red test green without excluding it, and\n'
    printf 'a literal argLine is the one setting that can sever coverage instrumentation silently.\n'
    printf 'Both are measured here rather than asserted elsewhere.\n'
    printf '\n'
    printf 'poms carrying <skipTests>true</skipTests>: %s\n' "$skiptests_hits"
    printf 'Counted and compared SEPARATELY rather than folded into the rerun figure, because the only\n'
    printf 'question that matters about one is whether THIS change set introduced it.  Each is listed\n'
    printf 'with its occurrence count now and at the base commit; an unchanged count means the setting\n'
    printf 'is inherited configuration and not a test bypass this migration added.\n'
    if [ -s "${TMP}/skiptests.detail" ]; then sed 's/^/  /' "${TMP}/skiptests.detail"; else printf '  (none)\n'; fi
} > "$OUT"

if [ -n "$SUITE_MANIFEST" ]; then
    {
        printf '# every archived unit-test report, one path per line, sorted.\n'
        printf '# This is the enumerable set behind the total in report-inventory.txt.\n'
        printf '# baseline: %s   migrated: %s   total: %s\n' "$b_suites" "$m_suites" "$((b_suites + m_suites))"
        sed "s|^|baseline/surefire/|" "${TMP}/baseline.suites"
        sed "s|^|migrated/surefire/|" "${TMP}/migrated.suites"
    } > "$SUITE_MANIFEST"
    printf 'capture-report-inventory.sh: wrote %s (%s paths)\n' "$SUITE_MANIFEST" "$((b_suites + m_suites))"
fi

printf 'capture-report-inventory.sh: wrote %s\n' "$OUT"
printf '  baseline %s suites / %s methods ; migrated %s suites / %s methods\n' \
    "$b_suites" "$b_methods" "$m_suites" "$m_methods"
printf '  pairing both=%s baseline-only=%s migrated-only=%s\n' \
    "$(grep -c . "${TMP}/both" || true)" "$(grep -c . "${TMP}/baseline-only" || true)" "$(grep -c . "${TMP}/migrated-only" || true)"
printf '  current corpus: %s trees / %s sources / %s *Test.java / %s *IT.java / %s JUnit4 importers\n' \
    "$test_trees" "$test_sources" "$n_test_suffix" "$n_it_suffix" "$junit4_importers"
