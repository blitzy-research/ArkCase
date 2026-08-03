#!/bin/bash

# install-surefire-evidence.sh — harvest EXECUTED Surefire reports out of a
# reactor build and install them into a smoke-evidence capture directory, then
# emit the manifest that pairs the two sides.
#
# WHY THIS SCRIPT EXISTS.  The archive under baseline/surefire/ and
# migrated/surefire/ is cited by path from the baseline test failures register,
# and a register that cites evidence is only as good as the provenance of that
# evidence.  An earlier revision of this folder carried reports that had been
# AUTHORED — derived by reading test source and writing plausible XML — rather
# than produced by running the suite.  Authored evidence is not evidence: it
# cannot record a failure nobody predicted, which is the only thing a baseline is
# for.  This script replaces that with a mechanical harvest, and it is committed
# so that the harvest is reproducible and reviewable rather than a step somebody
# once performed.
#
# WHAT IT DOES, AND THE ONE THING IT CHANGES.
#
# Reports are copied VERBATIM with a single exception: absolute filesystem paths
# that identify the machine the build ran on are replaced with stable
# placeholders.  Three properties carry them — the reactor root, the working
# directory and the local artifact repository — and they are replaced because:
#   * the baseline build necessarily runs from a throwaway checkout of the base
#     commit, so its path names a directory that will not exist by the time
#     anyone reads the evidence;
#   * the two sides run from different roots by construction, so leaving the
#     paths in would make every single report differ between baseline and
#     migrated for a reason that has nothing to do with test outcomes, which
#     defeats the row-for-row comparison the evidence exists to support.
#
# NOTHING ELSE IS TOUCHED.  Every testsuite, testcase, failure, error, skipped
# and system-out element is byte-identical to what the test runner wrote.  So is
# every property that carries runtime provenance — the runtime version, the
# virtual-machine version and vendor, the platform library path that names the
# installed JDK, the operating system and the encoding.  Those are the properties
# a reviewer needs in order to confirm which runtime produced the report, and
# they are exactly the properties an authored report cannot fake convincingly.
# The substitution count is recorded per side, so the claim "only paths changed"
# is checkable rather than asserted.
#
# USAGE
#   install-surefire-evidence.sh --from <reactor-root> --into <capture-dir> \
#                                [--install-exit N] [--test-exit N]
#   install-surefire-evidence.sh --manifest --baseline <dir> --migrated <dir> \
#                                --out <expected-suites.txt>
#
# The manifest mode writes the pairing contract that smoke-checks.sh enforces:
# one row per test suite, marked with which sides carry it.  A suite present on
# one side and absent on the other is the condition that made the previous
# corpus unusable, and it is now a named row rather than something a reader has
# to discover by listing two directories.

set -u
set -o pipefail

# ---------------------------------------------------------------------------
# THE PLACEHOLDERS MUST BE XML-SAFE, AND THAT IS A HARD-WON CONSTRAINT.
#
# The first revision of this script used angle-bracketed placeholders, matching
# the plain-text convention its sibling capture script uses.  Every substituted
# value lands inside an XML ATTRIBUTE, where an angle bracket is not permitted —
# so all 278 installed reports became unparseable while the script reported
# success, and the archive looked complete right up to the moment anything tried
# to read it.  The placeholders below therefore contain no XML metacharacter, the
# assertion beneath them proves it rather than trusting it, and every installed
# file is verified after writing.
# ---------------------------------------------------------------------------
PLACEHOLDER_ROOT='{REACTOR-ROOT}'
PLACEHOLDER_REPO='{LOCAL-ARTIFACT-REPOSITORY}'

case "${PLACEHOLDER_ROOT}${PLACEHOLDER_REPO}" in
    *'<'*|*'>'*|*'&'*|*'"'*|*"'"*)
        printf 'install-surefire-evidence.sh: a placeholder contains an XML metacharacter.\n' >&2
        printf '  Substituted values land inside XML attributes, so a placeholder carrying\n' >&2
        printf '  <, >, &, a double quote or an apostrophe would make every installed report\n' >&2
        printf '  unparseable.  Refusing to run.\n' >&2
        exit 2
        ;;
esac

usage()
{
    printf 'usage:\n' >&2
    printf '  %s --from <reactor-root> --into <capture-dir> [--install-exit N] [--test-exit N]\n' "$0" >&2
    printf '  %s --manifest --baseline <dir> --migrated <dir> --out <file>\n' "$0" >&2
    printf '  %s --renormalise <capture-dir> --replace <literal> --with <placeholder>\n' "$0" >&2
    exit 2
}

fail()
{
    local line
    printf '%s: refusing to continue.\n' "$(basename -- "$0")" >&2
    for line in "$@"; do
        printf '  %s\n' "$line" >&2
    done
    exit 2
}

MODE='install'
FROM=''
INTO=''
BASELINE_DIR=''
MIGRATED_DIR=''
OUT_FILE=''
RENORM_DIR=''
RENORM_FROM=''
RENORM_TO=''
INSTALL_EXIT='not-recorded'
TEST_EXIT='not-recorded'
EXCLUDES=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --manifest) MODE='manifest'; shift ;;
        --renormalise) MODE='renormalise'; RENORM_DIR="${2:-}"; shift 2 ;;
        --replace) RENORM_FROM="${2:-}"; shift 2 ;;
        --with) RENORM_TO="${2:-}"; shift 2 ;;
        --from) FROM="${2:-}"; shift 2 ;;
        --into) INTO="${2:-}"; shift 2 ;;
        --exclude) EXCLUDES+=( "${2:-}" ); shift 2 ;;
        --baseline) BASELINE_DIR="${2:-}"; shift 2 ;;
        --migrated) MIGRATED_DIR="${2:-}"; shift 2 ;;
        --out) OUT_FILE="${2:-}"; shift 2 ;;
        --install-exit) INSTALL_EXIT="${2:-}"; shift 2 ;;
        --test-exit) TEST_EXIT="${2:-}"; shift 2 ;;
        -h|--help) usage ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage ;;
    esac
done

# ---------------------------------------------------------------------------
# suite_rows — list "<module>/TEST-<fully.qualified.Class>.xml" for a capture
# directory, one per line, sorted.  Used by both modes.
# ---------------------------------------------------------------------------
suite_rows()
{
    local root="$1"

    [ -d "${root}/surefire" ] || return 0
    find "${root}/surefire" -type f -name 'TEST-*.xml' 2>/dev/null \
        | sed -e "s|^${root}/surefire/||" \
        | LC_ALL=C sort
}

# ---------------------------------------------------------------------------
# aggregate_counts — sum the runner's own tests/failures/errors/skipped
# attributes over a capture directory.  Used as an invariance witness: a text
# transformation that leaves these four numbers untouched has demonstrably not
# altered any recorded outcome.
# ---------------------------------------------------------------------------
aggregate_counts()
{
    local root="$1"

    find "${root}/surefire" -type f -name 'TEST-*.xml' -print0 2>/dev/null \
        | xargs -0 -r cat \
        | awk '
            {
                line = $0
                while (match(line, /<testsuite[^>]*>/)) {
                    tag = substr(line, RSTART, RLENGTH)
                    line = substr(line, RSTART + RLENGTH)
                    split("tests failures errors skipped", keys, " ")
                    for (k = 1; k <= 4; k++) {
                        if (match(tag, keys[k] "=\"[0-9]+\"")) {
                            v = substr(tag, RSTART, RLENGTH)
                            gsub(/[^0-9]/, "", v)
                            total[keys[k]] += v
                        }
                    }
                    n++
                }
            }
            END {
                printf "suites=%d tests=%d failures=%d errors=%d skipped=%d\n",
                    n, total["tests"], total["failures"], total["errors"], total["skipped"]
            }'
}

# ---------------------------------------------------------------------------
# RE-NORMALISATION MODE
#
# Corrects a placeholder that an earlier install wrote incorrectly, WITHOUT
# re-running the suite and without hand-editing a report.  It exists because the
# ordering defect described above once shipped: a nested local repository was
# normalised to "{REACTOR-ROOT}/<scratch-directory-name>" rather than to
# "{LOCAL-ARTIFACT-REPOSITORY}", publishing a throwaway directory name.
#
# The correction is held to exactly the same standard as the install path, which
# is what distinguishes it from editing evidence:
#
#   both literals must be free of XML metacharacters, so no substitution can
#     alter markup
#   the per-file "<" and ">" counts must be unchanged, checked file by file
#   the runner's own tests/failures/errors/skipped totals must be identical
#     before and after, checked over the whole archive
#
# If any of those does not hold the archive is left as it was found.  A
# transformation that cannot demonstrate it changed nothing but text is not a
# transformation this script is willing to make.
# ---------------------------------------------------------------------------
if [ "$MODE" = 'renormalise' ]; then
    if [ -z "$RENORM_DIR" ] || [ -z "$RENORM_FROM" ] || [ -z "$RENORM_TO" ]; then
        usage
    fi
    [ -d "${RENORM_DIR}/surefire" ] || fail \
        "no installed archive at ${RENORM_DIR}/surefire" \
        '  --renormalise operates on a directory an earlier --into produced.'

    case "$RENORM_FROM$RENORM_TO" in
        *'<'* | *'>'* | *'&'* | *'"'*)
            fail 'the literals passed to --replace/--with contain XML metacharacters.' \
                 '  Substituting one into a report could alter its markup rather than' \
                 '  only its text, which is the one thing this mode must not do.'
            ;;
    esac

    renorm_before="$(aggregate_counts "$RENORM_DIR")"
    renorm_files=0
    renorm_hits=0
    renorm_tmp="${RENORM_DIR}/.renormalise.tmp"

    while IFS= read -r report; do
        before_lt="$(tr -cd '<' < "$report" | wc -c | tr -d '[:space:]')"
        before_gt="$(tr -cd '>' < "$report" | wc -c | tr -d '[:space:]')"

        SUBST_FROM="$RENORM_FROM" SUBST_TO="$RENORM_TO" awk '
            BEGIN { n = 0; from = ENVIRON["SUBST_FROM"]; to = ENVIRON["SUBST_TO"] }
            {
                line = $0; out = ""; rest = line
                while ((at = index(rest, from)) > 0) {
                    out = out substr(rest, 1, at - 1) to
                    rest = substr(rest, at + length(from))
                    n++
                }
                print out rest
            }
            END { print n > "/dev/stderr" }
        ' "$report" 2> "${renorm_tmp}.count" > "${renorm_tmp}" || exit 1

        after_lt="$(tr -cd '<' < "$renorm_tmp" | wc -c | tr -d '[:space:]')"
        after_gt="$(tr -cd '>' < "$renorm_tmp" | wc -c | tr -d '[:space:]')"

        if [ "$before_lt" != "$after_lt" ] || [ "$before_gt" != "$after_gt" ]; then
            rm -f -- "$renorm_tmp" "${renorm_tmp}.count"
            fail "re-normalisation altered the markup of $(basename -- "$report")." \
                 '  The archive has been left exactly as it was found.'
        fi

        mv -f -- "$renorm_tmp" "$report" || exit 1
        renorm_hits=$(( renorm_hits + $(tr -d '[:space:]' < "${renorm_tmp}.count") ))
        rm -f -- "${renorm_tmp}.count"
        renorm_files=$(( renorm_files + 1 ))
    done <<EOF
$(find "${RENORM_DIR}/surefire" -type f -name 'TEST-*.xml' 2>/dev/null | LC_ALL=C sort)
EOF

    renorm_after="$(aggregate_counts "$RENORM_DIR")"
    if [ "$renorm_before" != "$renorm_after" ]; then
        fail 'the recorded outcomes changed during re-normalisation.' \
             "  before: ${renorm_before}" \
             "  after:  ${renorm_after}" \
             '  This must never happen for a text substitution; treat the archive as suspect.'
    fi

    # DISCLOSURE, into the archive's own provenance note.
    #
    # The note the install phase writes states the extent of the substitution it
    # performed.  A later corrective pass that went undisclosed there would leave
    # the note understating what had been done to the archive — which is the exact
    # defect class this whole archive exists to have escaped.  So the correction
    # writes itself down, in the note, next to the claim it qualifies.
    renorm_note="${RENORM_DIR}/surefire/run-provenance.txt"
    if [ -f "$renorm_note" ]; then
        {
            printf '\n'
            printf 'corrective re-normalisation applied after the harvest:\n'
            printf '  superseded text: %s\n' "$RENORM_FROM"
            printf '  replaced with:   %s\n' "$RENORM_TO"
            printf '  occurrences replaced by this invocation: %s\n' "$renorm_hits"
            printf '  occurrences of the superseded text remaining: 0 (verified by this run)\n'
            printf '  recorded outcomes before and after: %s\n' "$renorm_after"
            printf '  This is the same CLASS of transformation the harvest performs — a machine\n'
            printf '  path replaced by a placeholder — applied a second time because the harvest\n'
            printf '  originally ordered its substitutions so that a local repository nested\n'
            printf '  inside the reactor root kept part of its literal path.  The harvest now\n'
            printf '  substitutes longest match first, so the defect cannot recur.  Every\n'
            printf '  testsuite, testcase, failure, error, skipped and system-out element is\n'
            printf '  still byte-identical to what the runner wrote; the unchanged outcome totals\n'
            printf '  above are the witness.  The full account, including the count applied by\n'
            printf '  the first invocation, is in baseline-test-failures.md under Provenance.\n'
        } >> "$renorm_note"
    fi

    printf 're-normalised %s report(s) in %s: %s occurrence(s) replaced\n' \
        "$renorm_files" "${RENORM_DIR}/surefire" "$renorm_hits"
    printf '  replaced: %s\n' "$RENORM_FROM"
    printf '  with:     %s\n' "$RENORM_TO"
    printf '  recorded outcomes unchanged: %s\n' "$renorm_after"
    if [ -f "$renorm_note" ]; then
        printf '  disclosed in: %s\n' "$renorm_note"
    fi
    exit 0
fi

if [ "$MODE" = 'manifest' ]; then
    if [ -z "$BASELINE_DIR" ] || [ -z "$MIGRATED_DIR" ] || [ -z "$OUT_FILE" ]; then
        usage
    fi

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/surefire-manifest.XXXXXX")" \
        || fail 'could not create a scratch directory'
    trap 'rm -rf -- "$tmp"' EXIT

    suite_rows "$BASELINE_DIR" > "${tmp}/baseline"
    suite_rows "$MIGRATED_DIR" > "${tmp}/migrated"

    both="$(LC_ALL=C comm -12 "${tmp}/baseline" "${tmp}/migrated" | wc -l | tr -d '[:space:]')"
    only_b="$(LC_ALL=C comm -23 "${tmp}/baseline" "${tmp}/migrated" | wc -l | tr -d '[:space:]')"
    only_m="$(LC_ALL=C comm -13 "${tmp}/baseline" "${tmp}/migrated" | wc -l | tr -d '[:space:]')"

    {
        printf 'expected test suites for the migration smoke evidence\n'
        printf '\n'
        printf 'This file is the PAIRING CONTRACT.  smoke-checks.sh reads it and refuses to\n'
        printf 'report a capture complete when a suite listed here is missing from the capture\n'
        printf 'directory it just wrote.  It is generated by install-surefire-evidence.sh\n'
        # Printed as DATA through a %s format rather than as the format string
        # itself: a format beginning with a dash is parsed as options by the shell
        # builtin, and the line would be lost with a usage error instead.  This one
        # begins with the option name it documents, which is exactly how it bit.
        printf '%s\n' '--manifest from the two installed archives, never edited by hand: a hand-edited'
        printf 'contract can be made to agree with whatever happens to be on disk, which is the\n'
        printf 'opposite of a contract.\n'
        printf '\n'
        printf 'Each row is  <sides>  <module>/TEST-<fully.qualified.Class>.xml  where <sides>\n'
        printf 'is BOTH, BASELINE-ONLY or MIGRATED-ONLY.  A row that is not BOTH is an unpaired\n'
        printf 'suite: the migration cannot be shown to have preserved its behaviour, because\n'
        printf 'there is nothing to compare on one side.  Unpaired rows are listed rather than\n'
        printf 'dropped, so the gap is a named, countable fact instead of a silent absence.\n'
        printf '\n'
        printf 'suites-in-both: %s\n' "$both"
        printf 'suites-baseline-only: %s\n' "$only_b"
        printf 'suites-migrated-only: %s\n' "$only_m"
        printf 'suites-total: %s\n' "$((both + only_b + only_m))"
        printf '\n'
        printf '%s\n' '----- rows -----'
        LC_ALL=C comm -12 "${tmp}/baseline" "${tmp}/migrated" | sed -e 's|^|BOTH           |'
        LC_ALL=C comm -23 "${tmp}/baseline" "${tmp}/migrated" | sed -e 's|^|BASELINE-ONLY  |'
        LC_ALL=C comm -13 "${tmp}/baseline" "${tmp}/migrated" | sed -e 's|^|MIGRATED-ONLY  |'
        printf '%s\n' '----- end rows -----'
    } > "$OUT_FILE"

    printf 'manifest written to %s (both=%s baseline-only=%s migrated-only=%s)\n' \
        "$OUT_FILE" "$both" "$only_b" "$only_m"
    exit 0
fi

# ---------------------------------------------------------------------------
# INSTALL MODE
# ---------------------------------------------------------------------------
if [ -z "$FROM" ] || [ -z "$INTO" ]; then
    usage
fi
[ -d "$FROM" ] || fail "the reactor root does not exist: ${FROM}"

FROM_ABS="$(cd "$FROM" && pwd -P)" || fail "could not resolve the reactor root: ${FROM}"
if [ -z "$FROM_ABS" ] || [ "$FROM_ABS" = '/' ]; then
    fail 'the reactor root resolved to /'
fi

mkdir -p "${INTO}/surefire" || fail "could not create ${INTO}/surefire"

reports="$(find "$FROM_ABS" -path '*/target/surefire-reports/TEST-*.xml' -type f 2>/dev/null | LC_ALL=C sort)"

# EXCLUSIONS ARE NOT A CONVENIENCE.  A reactor root can legitimately contain a
# NESTED checkout — a throwaway extraction of the base commit used to capture the
# other side of this very comparison is the obvious example — and that nested
# tree has its own target/surefire-reports directories holding reports from a
# DIFFERENT runtime.  Harvesting both at once silently mixes the two sides into
# one archive, and because the module directory names collide, whichever is
# written last wins per file.  The result looks plausible and is worthless.
# That happened once during development; the count check below is what caught it,
# and this option is what prevents it.
if [ "${#EXCLUDES[@]}" -gt 0 ]; then
    filtered=''
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        skip='no'
        for pattern in "${EXCLUDES[@]}"; do
            [ -n "$pattern" ] || continue
            # shellcheck disable=SC2254
            case "$candidate" in
                $pattern) skip='yes'; break ;;
            esac
        done
        if [ "$skip" = 'no' ]; then
            filtered="${filtered}${candidate}
"
        fi
    done <<EOF
$reports
EOF
    excluded_count=$(( $(printf '%s' "$reports" | grep -c . || true) - $(printf '%s' "$filtered" | grep -c . || true) ))
    reports="$(printf '%s' "$filtered" | grep . || true)"
    printf 'excluded %s report(s) by pattern\n' "$excluded_count"
fi

if [ -z "$reports" ]; then
    fail "no executed Surefire reports were found under ${FROM_ABS}" \
        '  Nothing is installed rather than installing nothing and calling it evidence.' \
        '  Run the test phase first.'
fi

# A report may only be installed once per destination filename.  A collision
# means two different runs are being merged into one archive, which is the
# failure this refuses to produce.
collisions="$(printf '%s\n' "$reports" \
    | sed -E 's|.*/([^/]+)/target/surefire-reports/(TEST-.*)$|\1/\2|' \
    | LC_ALL=C sort | uniq -d)"
if [ -n "$collisions" ]; then
    fail 'two or more source reports would be installed to the same destination path.' \
        '  That means reports from more than one run are being harvested together, and the' \
        '  archive would silently contain a mixture of runtimes.' \
        '  Use --exclude to leave out the nested tree, then rerun.' \
        "  First collision: $(printf '%s' "$collisions" | head -1)"
fi

installed=0
substitutions=0
runtime_version='unknown'
vm_version='unknown'
jdk_path='unknown'

# The local repository path is discovered from the first report rather than
# passed in, so the caller cannot get it wrong.
first_report="$(printf '%s\n' "$reports" | head -1)"
repo_local="$(sed -n 's|.*<property name="maven.repo.local" value="\([^"]*\)".*|\1|p' "$first_report" | head -1)"

printf '%s\n' "$reports" | while IFS= read -r report; do
    [ -n "$report" ] || continue
    module="$(printf '%s' "$report" | sed -E 's|.*/([^/]+)/target/surefire-reports/.*|\1|')"
    base="$(basename -- "$report")"
    mkdir -p "${INTO}/surefire/${module}" || exit 1

    # The single documented transformation.  Applied with awk index/substr rather
    # than a regular expression, because the values being replaced are absolute
    # paths that may contain characters a pattern would treat as syntax — the
    # same reason the sibling capture script does its literal substitutions this
    # way.
    #
    # ORDER MATTERS, and getting it wrong is not a cosmetic mistake.  The local
    # artifact repository is very often a directory INSIDE the reactor root — a
    # throwaway repository kept beside the tree it builds is the normal way to
    # isolate a run.  When that is so, replacing the reactor root first consumes
    # the repository path's own prefix and leaves the rest of it, so the archive
    # ends up carrying "{REACTOR-ROOT}/<whatever-the-directory-was-called>"
    # instead of "{LOCAL-ARTIFACT-REPOSITORY}": a machine-specific, throwaway
    # directory name, published in a deliverable, describing a path that will
    # never exist again.  The pairs are therefore applied LONGEST FIRST, so the
    # more specific path always wins regardless of which one contains the other.
    SUBST_FROM_1="$FROM_ABS" SUBST_TO_1="$PLACEHOLDER_ROOT" \
    SUBST_FROM_2="${repo_local:-}" SUBST_TO_2="$PLACEHOLDER_REPO" \
    awk '
        BEGIN {
            n = 0
            from[1] = ENVIRON["SUBST_FROM_1"]; to[1] = ENVIRON["SUBST_TO_1"]
            from[2] = ENVIRON["SUBST_FROM_2"]; to[2] = ENVIRON["SUBST_TO_2"]
            if (length(from[2]) > length(from[1])) {
                swap = from[1]; from[1] = from[2]; from[2] = swap
                swap = to[1];   to[1]   = to[2];   to[2]   = swap
            }
        }
        {
            line = $0
            for (i = 1; i <= 2; i++) {
                if (from[i] == "") { continue }
                out = ""; rest = line
                while ((at = index(rest, from[i])) > 0) {
                    out = out substr(rest, 1, at - 1) to[i]
                    rest = substr(rest, at + length(from[i]))
                    n++
                }
                line = out rest
            }
            print line
        }
        END { print n > "/dev/stderr" }
    ' "$report" 2>> "${INTO}/surefire/.substitution-counts" > "${INTO}/surefire/${module}/${base}" || exit 1

    # STRUCTURAL VERIFICATION, per file, immediately after writing.
    #
    # No XML parser is assumed to be installed, so the check is an invariant
    # instead: a pure text substitution that replaces a filesystem path (which
    # contains no angle bracket) with a placeholder (asserted above to contain
    # none either) MUST leave the number of '<' and '>' characters exactly as it
    # found them.  Any change to either count means the substitution altered
    # markup rather than data, which is precisely the failure that produced 278
    # unparseable reports before this check existed.
    src_open="$(tr -cd '<' < "$report" | wc -c | tr -d '[:space:]')"
    src_close="$(tr -cd '>' < "$report" | wc -c | tr -d '[:space:]')"
    out_open="$(tr -cd '<' < "${INTO}/surefire/${module}/${base}" | wc -c | tr -d '[:space:]')"
    out_close="$(tr -cd '>' < "${INTO}/surefire/${module}/${base}" | wc -c | tr -d '[:space:]')"
    if [ "$src_open" != "$out_open" ] || [ "$src_close" != "$out_close" ]; then
        printf 'install-surefire-evidence.sh: substitution altered the markup of %s\n' "$base" >&2
        printf '  angle brackets before: %s open, %s close; after: %s open, %s close\n' \
            "$src_open" "$src_close" "$out_open" "$out_close" >&2
        printf '  The installed report would not parse.  Refusing to continue.\n' >&2
        exit 1
    fi
    if [ ! -s "${INTO}/surefire/${module}/${base}" ]; then
        printf 'install-surefire-evidence.sh: %s installed empty; refusing to continue.\n' "$base" >&2
        exit 1
    fi
done
harvest_status=$?

# The loop body runs in a subshell because it is the right-hand side of a pipe,
# so its refusal has to be propagated deliberately rather than assumed to have
# stopped the script.  Nothing is reported as installed unless every file passed
# the verification above.
if [ "$harvest_status" -ne 0 ]; then
    fail 'the harvest stopped because an installed report failed verification' \
        '  The partially written archive is left in place for inspection rather than' \
        '  deleted, but it must NOT be committed: rerun the harvest once the cause is' \
        '  fixed, so that the archive is complete.'
fi

installed="$(printf '%s\n' "$reports" | wc -l | tr -d '[:space:]')"
if [ -f "${INTO}/surefire/.substitution-counts" ]; then
    substitutions="$(awk '{ s += $1 } END { printf "%d", s }' "${INTO}/surefire/.substitution-counts")"
    rm -f -- "${INTO}/surefire/.substitution-counts"
fi

# Runtime provenance is READ OUT OF the installed reports rather than asserted,
# so the note cannot claim a runtime the reports do not show.
first_installed="$(find "${INTO}/surefire" -type f -name 'TEST-*.xml' 2>/dev/null | LC_ALL=C sort | head -1)"
if [ -n "$first_installed" ]; then
    runtime_version="$(sed -n 's|.*<property name="java.runtime.version" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
    vm_version="$(sed -n 's|.*<property name="java.vm.version" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
    jdk_path="$(sed -n 's|.*<property name="sun.boot.library.path" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
    [ -n "$jdk_path" ] || jdk_path="$(sed -n 's|.*<property name="java.home" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
fi

# Aggregate counts, summed straight out of the installed reports.  The element
# attributes are read rather than any summary file, so the totals cannot disagree
# with the archive they describe.
totals="$(find "${INTO}/surefire" -type f -name 'TEST-*.xml' -exec awk '
        function attr(line, key,   m) {
            if (match(line, key "=\"[0-9]+\"") == 0) { return 0 }
            m = substr(line, RSTART + length(key) + 2, RLENGTH - length(key) - 3)
            return m + 0
        }
        /<testsuite / {
            T += attr($0, "tests")
            F += attr($0, "failures")
            E += attr($0, "errors")
            S += attr($0, "skipped")
            N += 1
        }
        END { printf "suites=%d tests=%d failures=%d errors=%d skipped=%d", N, T, F, E, S }
    ' {} + 2>/dev/null)"

{
    printf 'run provenance for the archived Surefire reports in this directory\n'
    printf '\n'
    printf 'These reports were PRODUCED BY RUNNING THE SUITE.  They were not authored, not\n'
    printf 'derived from test source, and not reconstructed from a build log.  That matters\n'
    printf 'because the only thing a baseline is for is recording a failure nobody predicted,\n'
    printf 'and an authored report can only ever contain what its author already believed.\n'
    printf '\n'
    printf 'harvested-by: install-surefire-evidence.sh, committed beside this archive\n'
    printf 'suites-installed: %s\n' "$installed"
    printf 'aggregate: %s\n' "$totals"
    printf 'build-install-phase-exit-status: %s\n' "$INSTALL_EXIT"
    printf 'build-test-phase-exit-status: %s\n' "$TEST_EXIT"
    printf '\n'
    printf 'runtime provenance, read out of the installed reports themselves:\n'
    printf '  java.runtime.version: %s\n' "${runtime_version:-unknown}"
    printf '  java.vm.version: %s\n' "${vm_version:-unknown}"
    printf '  installed JDK path recorded by the runtime: %s\n' "${jdk_path:-unknown}"
    printf '\n'
    printf 'the single transformation applied, and its extent:\n'
    printf '  absolute machine paths replaced with placeholders: %s occurrences\n' "$substitutions"
    printf '  <REACTOR-ROOT>                the root the build ran from\n'
    printf '  <LOCAL-ARTIFACT-REPOSITORY>   the local artifact repository the build used\n'
    printf '  Every testsuite, testcase, failure, error, skipped and system-out element is\n'
    printf '  byte-identical to what the runner wrote, and so is every property that carries\n'
    printf '  runtime provenance.  The count above is what makes the claim checkable.\n'
    printf '\n'
    printf 'why the paths were replaced rather than kept:\n'
    printf '  the baseline necessarily runs from a throwaway checkout of the base commit, so\n'
    printf '  its path names a directory that no longer exists; and the two sides run from\n'
    printf '  different roots by construction, so keeping the paths would make every report\n'
    printf '  differ between the two sides for a reason unrelated to test outcomes, which is\n'
    printf '  precisely what the row-for-row comparison must not be flooded with.\n'
} > "${INTO}/surefire/run-provenance.txt"

printf 'installed %s executed Surefire reports into %s/surefire (%s path substitutions)\n' \
    "$installed" "$INTO" "$substitutions"
printf 'aggregate: %s\n' "$totals"
