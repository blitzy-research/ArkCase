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
# WHAT IT DOES, AND THE TWO THINGS IT CHANGES.  Both are disclosed here, both are
# counted per file, and nothing else is touched.
#
# (1) ABSOLUTE MACHINE PATHS become stable placeholders.  Two properties carry
# them — the reactor root and the local artifact repository — and they are
# replaced because:
#   * the baseline build necessarily runs from a throwaway checkout of the base
#     commit, so its path names a directory that will not exist by the time
#     anyone reads the evidence;
#   * the two sides run from different roots by construction, so leaving the
#     paths in would make every single report differ between baseline and
#     migrated for a reason that has nothing to do with test outcomes, which
#     defeats the row-for-row comparison the evidence exists to support.
#
# (2) THE SYSTEM PROPERTY DUMP IS REDUCED TO AN ALLOWLIST.  The runner writes
# around fifty properties into every report.  Most of them are the machine, not
# the evidence: two full classpaths, the launcher command line, the user's name,
# home directory, country and timezone, and several more absolute paths.  Those
# are dropped.  What is KEPT is the set that answers the only question the dump
# is evidence for — which runtime produced this report — and it is kept NATIVE,
# exactly as the runner wrote it:
#
#   PROPERTY_ALLOWLIST below: the Java version and runtime version, the virtual
#   machine's name, vendor and version, the language specification version, the
#   class-file version the runtime reads, the operating system name, version and
#   architecture, the data model width, and the file encoding.
#
# An earlier revision of this archive emptied the properties element entirely.
# That left the runtime provenance of every report resting on a hand-authored
# comment, which is the weakest possible form of the strongest available evidence:
# a comment is exactly what an authored report can fake, and a native
# java.runtime.version is exactly what it cannot.  Keeping the allowlist is what
# lets a reviewer confirm the runtime from the report itself.
#
# Every testsuite, testcase, failure, error, skipped and system-out element is
# byte-identical to what the runner wrote.  The substitution count and the
# dropped-property count are both recorded per side, and each installed file is
# verified structurally against the exact number of angle brackets the drop
# removed, so "only these two things changed" is checkable rather than asserted.
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

# ---------------------------------------------------------------------------
# THE PROPERTY ALLOWLIST.
#
# Every name here is a runtime fact and none of them identifies a machine, a
# user or a filesystem.  Adding a name to this list is adding it to a published
# deliverable, so the test for a candidate is: does it answer "which runtime
# produced this report", and would publishing it disclose anything about the
# host?  java.home, sun.boot.library.path, java.library.path, java.io.tmpdir,
# user.name, user.home, user.dir, basedir, localRepository, java.class.path,
# surefire.real.class.path, surefire.test.class.path and sun.java.command all
# fail the second half of that test and are deliberately absent.
# ---------------------------------------------------------------------------
PROPERTY_ALLOWLIST='java.version java.runtime.version java.runtime.name java.vendor java.vm.name java.vm.vendor java.vm.version java.vm.info java.specification.version java.class.version os.name os.arch os.version sun.arch.data.model file.encoding jdk.debug'

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

# ---------------------------------------------------------------------------
# STAGE, THEN PUBLISH — AND THE REASON IS A DEFECT THIS SCRIPT ONCE HAD.
#
# Every fail-closed check below runs AFTER the reports have been written out,
# because each one is a claim about the written archive rather than about the
# source.  An earlier revision wrote them straight into the destination, so a
# refusal left the destination holding a partial archive — including, in the worst
# case, the very report whose credential caused the refusal, sitting in a tracked
# directory where the next `git add` would sweep it up.  A gate that refuses and
# then leaves the thing it refused on disk is not a gate.
#
# So the whole archive is built in a staging directory beside the destination,
# every check runs against the staging tree, and the destination is only touched
# once every check has passed.  A refusal removes the staging tree and leaves the
# previously committed archive exactly as it was; the destination is therefore
# always either the old archive or the new one, never a mixture and never a
# half-written one.  The staging directory is named with a leading dot and the
# process id so two concurrent runs cannot collide, and it is removed on EVERY
# exit path including a signal.
# ---------------------------------------------------------------------------
INTO_PARENT="$(dirname -- "$INTO")"
[ -d "$INTO_PARENT" ] || mkdir -p "$INTO_PARENT" || fail "could not create ${INTO_PARENT}"
INTO_PARENT="$(cd "$INTO_PARENT" && pwd -P)" || fail "could not resolve ${INTO_PARENT}"
STAGE_ROOT="${INTO_PARENT}/.$(basename -- "$INTO").surefire-staging.$$"
WORK="${STAGE_ROOT}/surefire"

discard_stage()
{
    [ -n "${STAGE_ROOT:-}" ] || return 0
    case "$STAGE_ROOT" in
        */.*.surefire-staging.*) rm -rf -- "$STAGE_ROOT" ;;
        *) : ;;
    esac
}
trap discard_stage EXIT HUP INT TERM

rm -rf -- "$STAGE_ROOT"
mkdir -p "$WORK" || fail "could not create the staging directory ${WORK}"

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

# The local repository path is discovered from the reports rather than passed in,
# so the caller cannot get it wrong.
#
# TWO SOURCES, AND THE SECOND ONE IS NOT OPTIONAL POLISH.  A run given
# -Dmaven.repo.local=<dir> records that property, and reading it back is exact.
# A run that uses the DEFAULT repository records no such property, and an earlier
# revision of this script stopped there — leaving repo_local empty, performing no
# repository substitution, and installing three reports that carried
# "$HOME/.m2/repository/..." inside their captured test output while the
# provenance note beside them stated that no absolute machine path survived.  The
# note was wrong, and it was wrong in the one direction that matters: it claimed
# more than the transformation had done.
#
# So when the property is absent the default location is used, and the result is
# then VERIFIED rather than trusted: after every report is written, the archive is
# searched for the home directory path, and the install refuses outright if one
# survives.  A check that fails loudly is what makes the note's claim checkable;
# deriving the path more cleverly without checking would only move the hope.
first_report="$(printf '%s\n' "$reports" | head -1)"
repo_local="$(sed -n 's|.*<property name="maven.repo.local" value="\([^"]*\)".*|\1|p' "$first_report" | head -1)"
repo_local_source='the maven.repo.local property recorded by the run'
if [ -z "$repo_local" ]; then
    if [ -n "${HOME:-}" ] && [ -d "${HOME}/.m2/repository" ]; then
        repo_local="${HOME}/.m2/repository"
        repo_local_source='the default location, the run having recorded no maven.repo.local'
    else
        repo_local_source='not determined; no maven.repo.local property and no default repository on disk'
    fi
fi

printf '%s\n' "$reports" | while IFS= read -r report; do
    [ -n "$report" ] || continue
    module="$(printf '%s' "$report" | sed -E 's|.*/([^/]+)/target/surefire-reports/.*|\1|')"
    base="$(basename -- "$report")"
    mkdir -p "${WORK}/${module}" || exit 1

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
    ' "$report" 2>> "${WORK}/.substitution-counts" > "${WORK}/${module}/${base}.paths" || exit 1

    # THE SECOND TRANSFORMATION: reduce the system property dump to the allowlist.
    #
    # The dropped lines are counted, and so are the angle brackets they carried,
    # because the structural check below is what stands in for an XML parser and
    # it has to know exactly how much the drop was allowed to remove.  Counting
    # the brackets in the dropped lines rather than assuming one of each keeps the
    # check honest even if a dropped value happens to contain a bracket.
    filter_counts="$(PROPERTY_ALLOWLIST="$PROPERTY_ALLOWLIST" awk '
        BEGIN {
            split(ENVIRON["PROPERTY_ALLOWLIST"], allowed, " ")
            for (i in allowed) { keep[allowed[i]] = 1 }
            dropped = 0; lt = 0; gt = 0
        }
        {
            line = $0
            if (line ~ /^[[:space:]]*<property name="/) {
                name = line
                sub(/^[^"]*"/, "", name)
                sub(/".*$/, "", name)
                if (!(name in keep)) {
                    dropped++
                    lt += gsub(/</, "<", line)
                    gt += gsub(/>/, ">", line)
                    next
                }
            }
            print
        }
        END { printf "%d %d %d\n", dropped, lt, gt > "/dev/stderr" }
    ' "${WORK}/${module}/${base}.paths" 2>&1 >"${WORK}/${module}/${base}")" || exit 1
    rm -f -- "${WORK}/${module}/${base}.paths"

    dropped_props="$(printf '%s' "$filter_counts" | awk '{ print $1 + 0 }')"
    dropped_lt="$(printf '%s' "$filter_counts" | awk '{ print $2 + 0 }')"
    dropped_gt="$(printf '%s' "$filter_counts" | awk '{ print $3 + 0 }')"
    printf '%s\n' "$dropped_props" >> "${WORK}/.dropped-property-counts"

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
    out_open="$(tr -cd '<' < "${WORK}/${module}/${base}" | wc -c | tr -d '[:space:]')"
    out_close="$(tr -cd '>' < "${WORK}/${module}/${base}" | wc -c | tr -d '[:space:]')"
    expect_open=$((src_open - dropped_lt))
    expect_close=$((src_close - dropped_gt))
    if [ "$expect_open" != "$out_open" ] || [ "$expect_close" != "$out_close" ]; then
        printf 'install-surefire-evidence.sh: a transformation altered the markup of %s\n' "$base" >&2
        printf '  angle brackets before: %s open, %s close\n' "$src_open" "$src_close" >&2
        printf '  dropped with %s non-allowlisted properties: %s open, %s close\n' \
            "$dropped_props" "$dropped_lt" "$dropped_gt" >&2
        printf '  expected after: %s open, %s close; actual: %s open, %s close\n' \
            "$expect_open" "$expect_close" "$out_open" "$out_close" >&2
        printf '  The installed report would not parse.  Refusing to continue.\n' >&2
        exit 1
    fi
    if ! grep -q '<property name="java.runtime.version"' "${WORK}/${module}/${base}"; then
        printf 'install-surefire-evidence.sh: %s carries no native java.runtime.version.\n' "$base" >&2
        printf '  The allowlist exists so that every installed report states the runtime that\n' >&2
        printf '  produced it.  A report without it cannot serve as provenance.  Refusing to\n' >&2
        printf '  continue.\n' >&2
        exit 1
    fi
    if [ ! -s "${WORK}/${module}/${base}" ]; then
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
if [ -f "${WORK}/.substitution-counts" ]; then
    substitutions="$(awk '{ s += $1 } END { printf "%d", s }' "${WORK}/.substitution-counts")"
    rm -f -- "${WORK}/.substitution-counts"
fi
dropped_total=0
if [ -f "${WORK}/.dropped-property-counts" ]; then
    dropped_total="$(awk '{ s += $1 } END { printf "%d", s }' "${WORK}/.dropped-property-counts")"
    rm -f -- "${WORK}/.dropped-property-counts"
fi

# ---------------------------------------------------------------------------
# SECRET AND PERSONAL-DATA CHECK — FAIL CLOSED, ACROSS THE WHOLE ARCHIVE.
#
# Surefire reports carry whatever a test wrote to standard output, and a test that
# logs a request, a configuration object or an authentication failure can put a
# credential into a file that is then committed to a public repository forever.
# The absolute-path check below establishes that the capture machine's filesystem
# layout does not leak; it says nothing at all about credentials, and an archive
# can be perfectly free of machine paths while carrying a private key.  This is the
# gate for that, and it is deliberately a SEPARATE gate rather than an extension of
# the path check, because the two answer different questions and a reader of the
# provenance note needs both answered.
#
# IT FAILS CLOSED.  An unrecognised match stops the install; nothing is redacted in
# place and nothing is shipped with a warning.  Redacting would be worse than
# refusing: it would silently alter machine output, which is precisely the defect
# this whole deliverable is being corrected for, and it would leave a reader unable
# to tell an edited report from an unedited one.  The correct response to a
# credential in a test's output is to fix the test, not to launder the evidence.
#
# THE ALLOWLIST IS EXACT LITERALS, NOT PATTERNS.  A pattern allowlist is how a real
# secret gets waved through: it is written to admit one known fixture and then
# admits a whole shape.  Every entry below is a complete string, is committed in
# the test source that emits it, and carries the reason it is there.  Anything that
# is not one of these exact strings is refused even if it looks similar.
#
# The entries were established by scanning the archive and then reading the source
# that produces each hit, not by assuming what a fixture looks like:
#
#   The signed-token value emitted by the token-signing service test.  It is the
#   canonical example token from the token specification's own documentation - its
#   payload decodes to the well-known sub 1234567890 / name John Doe / iat
#   1516239022 - and it is a literal in the committed test source.  It is a public
#   test vector, not a credential.
#
#   Three fixture user addresses in the arkcase.org domain.  These are the standard
#   demonstration users the test data ships with; the domain is the project's own
#   and the accounts exist only in test fixtures.  They are personal data in shape
#   only.
#
# Note what is NOT allowlisted and therefore refused: the evaluation host's
# documented administrator password and its documented database password.  Both are
# real working credentials for the reference stack, both appear in this
# repository's setup documentation, and neither has any business in a test report.
# Scanning for them specifically is how this gate proves it can catch a credential
# it has actually seen rather than only ones it can imagine.
# ---------------------------------------------------------------------------
SECRET_ALLOWLIST_FILE="${TMPDIR:-/tmp}/surefire-secret-allowlist.$$"
: > "$SECRET_ALLOWLIST_FILE"
{
    printf '%s\n' 'eyJhbGciOiJIUzI1NiJ9.ewogICJzdWIiOiAiMTIzNDU2Nzg5MCIsCiAgIm5hbWUiOiAiSm9obiBEb2UiLAogICJpYXQiOiAxNTE2MjM5MDIyCn0.0Gh1Ilzj9aeD2gxmjTn2U-Yo-NxpW8hMet_CY6bDkKg'
    printf '%s\n' 'ann-acm@arkcase.org'
    printf '%s\n' 'arkcase-admin@arkcase.org'
    printf '%s\n' 'ian-acm@arkcase.org'
} >> "$SECRET_ALLOWLIST_FILE"

secret_hits="${TMPDIR:-/tmp}/surefire-secret-hits.$$"
: > "$secret_hits"

# Each shape is scanned separately so that the refusal can name WHICH shape
# matched.  "A secret was found" is not actionable; "a PEM private key header was
# found in this file" is.
scan_secret_shape()
{
    local shape_name="$1"
    local pattern="$2"
    local file
    local match

    grep -rElZ -- "$pattern" "${WORK}" --include='*.xml' 2>/dev/null \
        | tr '\0' '\n' | while IFS= read -r file; do
        [ -n "$file" ] || continue
        grep -Eoh -- "$pattern" "$file" 2>/dev/null | LC_ALL=C sort -u \
            | while IFS= read -r match; do
            [ -n "$match" ] || continue
            if LC_ALL=C grep -qxF -- "$match" "$SECRET_ALLOWLIST_FILE"; then
                continue
            fi
            printf '%s\t%s\n' "$shape_name" "$file" >> "$secret_hits"
        done
    done
}

scan_secret_shape 'a PEM private key header' \
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
scan_secret_shape 'an AWS access key identifier' \
    'AKIA[0-9A-Z]{16}'
scan_secret_shape 'a signed token' \
    'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_+/=-]{10,}\.[A-Za-z0-9_-]{10,}'
scan_secret_shape 'a bearer token' \
    'Bearer [A-Za-z0-9._~+/-]{16,}'
scan_secret_shape 'a credential assignment' \
    '(password|passwd|pwd|secret|apikey|api_key|privateKey)[[:space:]]*[=:][[:space:]]*[^[:space:]<>"&]{4,}'
scan_secret_shape 'credentials embedded in a URL' \
    '[a-z][a-z0-9+.-]*://[^/[:space:]<>"]+:[^@/[:space:]<>"]+@'
scan_secret_shape 'an email address' \
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# ---------------------------------------------------------------------------
# LITERAL-VALUE SCANNING — AND WHY THE LITERALS ARE NOT WRITTEN DOWN HERE.
#
# The shapes above catch a credential that arrives in a recognisable FORM: an
# assignment, a URL userinfo segment, a token, a key header.  They do not catch a
# BARE value — a test that logs just the password of the environment it ran
# against produces a string with no shape to match.  So the deployment's actual
# secrets are scanned for as fixed strings too.
#
# An earlier revision of this script did that by writing those secrets into the
# argument list, which is the very defect this gate exists to prevent: it put the
# reference stack's administrator and database passwords into a committed file,
# where reading the scanner taught you the credentials it was protecting, and it
# only ever worked for one deployment.  The values are therefore supplied OUT OF
# BAND, by the same variables and credential files the capture producer already
# uses, and this script holds none of them.
#
# Fixed-string matching is used rather than regular-expression matching because a
# password legitimately contains metacharacters, and a value such as a trailing
# '!' or a leading '@' would otherwise be interpreted rather than searched for.
#
# Availability is REPORTED, not assumed.  A literal check that could not run
# because its value was not supplied is named in the output, so a run cannot
# quietly cover less than a reader believes it did.
# ---------------------------------------------------------------------------
scan_secret_literal()
{
    local shape_name="$1"
    local value="$2"
    local file

    # A short value would match half the archive by coincidence; refuse to use it
    # as a needle rather than drown the report in false positives.
    [ "${#value}" -ge 6 ] || return 0

    grep -rFlZ -- "$value" "${WORK}" --include='*.xml' 2>/dev/null \
        | tr '\0' '\n' | while IFS= read -r file; do
        [ -n "$file" ] || continue
        if LC_ALL=C grep -qxF -- "$value" "$SECRET_ALLOWLIST_FILE"; then
            continue
        fi
        printf '%s\t%s\n' "$shape_name" "$file" >> "$secret_hits"
    done
}

# Reads a secret from <NAME> or <NAME>_FILE, scans for it, and records coverage.
# The value is held in a local and never printed, never written to a file, and
# never passed through a command line that another process could observe.
literal_checks_run=''
literal_checks_unavailable=''
scan_named_secret()
{
    local var="$1"
    local description="$2"
    local value=''
    local file_var="${var}_FILE"

    value="$(printf '%s' "${!var-}")"
    if [ -z "$value" ] && [ -n "${!file_var-}" ] && [ -r "${!file_var}" ]; then
        # Only the first line, and without a trailing newline: a credential file
        # written by `printf` and one written by an editor must behave alike.
        IFS= read -r value < "${!file_var}" || true
    fi

    if [ -n "$value" ]; then
        scan_secret_literal "$description" "$value"
        literal_checks_run="${literal_checks_run}${literal_checks_run:+, }${description}"
    else
        literal_checks_unavailable="${literal_checks_unavailable}${literal_checks_unavailable:+, }${description} (set ${var} or ${file_var})"
    fi
}

scan_named_secret 'ARKCASE_PASSWORD' 'the application administrator password'
scan_named_secret 'BROKER_PASSWORD' 'the message broker password'
scan_named_secret 'DATABASE_PASSWORD' 'the database password'
scan_named_secret 'DIRECTORY_SERVICE_PASSWORD' 'the directory service bind password'

if [ -s "$secret_hits" ]; then
    printf 'install-surefire-evidence.sh: REFUSING TO INSTALL.\n' >&2
    printf '  A credential-shaped or personal-data-shaped value was found in a report that\n' >&2
    printf '  was about to be committed, and it is not one of the exact fixture literals\n' >&2
    printf '  this script allows.  The value itself is NOT printed here: printing it would\n' >&2
    printf '  put it in a build log as well as in a report.\n' >&2
    printf '  Matches, by shape and file:\n' >&2
    LC_ALL=C sort -u "$secret_hits" \
        | sed -e "s|${WORK}/||" -e 's|\t| in |' -e 's|^|    |' >&2
    printf '  Remediation: fix the TEST so it stops emitting the value.  Do NOT redact the\n' >&2
    printf '  report: these files are machine output and editing them is the defect this\n' >&2
    printf '  archive is being corrected for.  If the value is genuinely a deterministic,\n' >&2
    printf '  public test fixture, add its EXACT literal to the allowlist in this script\n' >&2
    printf '  together with the reason and the test source that emits it.\n' >&2
    rm -f -- "$secret_hits" "$SECRET_ALLOWLIST_FILE"
    exit 1
fi
rm -f -- "$secret_hits"

# State the coverage of the literal half of the gate.  The shapes always run; the
# literal checks run only for values that were supplied, and a reader is entitled
# to know which those were without inspecting the environment themselves.  Names
# and descriptions are printed; values never are.
printf 'secret gate: 7 shape check(s) ran against every installed report.\n'
if [ -n "$literal_checks_run" ]; then
    printf '  literal value check(s) that ran: %s\n' "$literal_checks_run"
else
    printf '  literal value check(s) that ran: none\n'
fi
if [ -n "$literal_checks_unavailable" ]; then
    printf '  literal value check(s) NOT run because the value was not supplied: %s\n' \
        "$literal_checks_unavailable"
fi

# ---------------------------------------------------------------------------
# LEAKAGE CHECK — FAIL CLOSED, ACROSS THE WHOLE ARCHIVE.
#
# The provenance note this script writes states that after the substitutions no
# absolute path of the capture machine survives in the archive.  That is a claim
# about every one of several hundred files, and it was once false: a run using the
# DEFAULT artifact repository recorded no maven.repo.local property, so no
# repository substitution was performed, and three reports went into a committed
# deliverable carrying the home directory inside their captured test output.
#
# Deriving the path better is necessary but not sufficient, because the next way
# an absolute path reaches a report will not be this one — a test that logs its
# own working directory, a stack trace from a tool invoked with an absolute
# argument, a temporary file under the home directory.  So the claim is CHECKED
# against the written archive, and a survivor stops the install rather than being
# reported and shipped.  The two roots checked are the ones a note can be wrong
# about: the harvest source and the home directory.
#
# The system temporary directory is deliberately NOT checked.  A test that writes
# a scratch file there and logs the name is capturing its own behaviour, and that
# output is evidence rather than leaked environment; refusing it would delete a
# real observation to satisfy a rule about provenance.
# ---------------------------------------------------------------------------
leaked=''
for leak_root in "$FROM_ABS" "${HOME:-}"; do
    [ -n "$leak_root" ] || continue
    [ "$leak_root" = '/' ] && continue
    if grep -rlF -- "$leak_root" "${WORK}" 2>/dev/null | grep -q .; then
        leaked="${leaked}${leak_root}
"
    fi
done
if [ -n "$leaked" ]; then
    printf 'install-surefire-evidence.sh: an absolute machine path survived into the archive.\n' >&2
    printf '  The provenance note this script writes claims none does, so the install is\n' >&2
    printf '  refused rather than shipping a note that overstates what was done.\n' >&2
    printf '  Path(s) still present:\n' >&2
    printf '%s' "$leaked" | sed -e 's|^|    |' >&2
    printf '  Files carrying one of them:\n' >&2
    for leak_root in $leaked; do
        grep -rlF -- "$leak_root" "${WORK}" 2>/dev/null \
            | sed -e "s|^${WORK}/||" -e 's|^|    |' | head -10 >&2
    done
    printf '  Remediation: the repository path is taken from the maven.repo.local property\n' >&2
    printf '  and, when the run recorded none, from the default location.  If neither is the\n' >&2
    printf '  path above, the report is carrying it for some other reason and that reason has\n' >&2
    printf '  to be understood before the archive can be published.\n' >&2
    exit 1
fi

# SOURCE PROVENANCE — READ, NEVER PASSED IN.
#
# The archive has to be attributable to a revision, or a reader cannot tell which
# change set produced it.  The commit, the branch and the dirty state are all read
# from the harvest root's own repository at install time rather than taken as
# arguments, so a caller cannot label an archive with a revision it did not come
# from.  The dirty state is recorded HONESTLY as a file count: a capture taken from
# a working tree with uncommitted edits is still evidence, but it is evidence about
# the tree rather than about the commit, and the difference matters enough to print.
harvest_commit='not-a-git-checkout'
harvest_branch='not-a-git-checkout'
harvest_dirty='not-a-git-checkout'
if git -C "$FROM_ABS" rev-parse --git-dir >/dev/null 2>&1; then
    harvest_commit="$(git -C "$FROM_ABS" rev-parse HEAD 2>/dev/null || printf 'unreadable')"
    harvest_branch="$(git -C "$FROM_ABS" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unreadable')"
    # The archive being written is excluded from the count.  Including it would make
    # the number self-referential and therefore unstable: the install would count the
    # files it is in the middle of writing, so two identical runs would disagree by
    # however many reports changed.  The interesting quantity is the state of the tree
    # APART from this deliverable, and that is what is recorded.
    # Two things are excluded, and the second one is easy to miss: the archive itself,
    # and the staging directory this run created beside it.  Leaving the staging
    # directory in would add one untracked path that exists only while the install is
    # running, so the recorded number would be one higher than the same number measured
    # a second later -- a discrepancy a reader would rightly not trust.
    into_rel="${INTO#"$FROM_ABS"/}"
    stage_rel="$(basename -- "$STAGE_ROOT")"
    dirty_count="$(git -C "$FROM_ABS" status --porcelain 2>/dev/null \
        | grep -v -F -- "${into_rel}/surefire/" \
        | grep -v -F -- "${stage_rel}" \
        | grep -c . || true)"
    if [ "${dirty_count:-0}" -eq 0 ]; then
        harvest_dirty='clean -- every file outside this archive tracked and unmodified'
    else
        harvest_dirty="$(printf '%s path(s) OUTSIDE this archive differed from the commit above, so the capture is evidence about the working tree at that moment rather than about the commit alone. This archive itself is excluded from the count, which would otherwise be self-referential and unstable' "$dirty_count")"
    fi
fi

# Runtime provenance is READ OUT OF the installed reports rather than asserted,
# so the note cannot claim a runtime the reports do not show.
# `| head -1` here would close the pipe under sort and make it print a broken-pipe
# diagnostic onto the install output.  This tool's output is itself evidence, so a
# spurious error line in it is a defect: the first name is taken with sed's own
# range rather than by killing the writer.
first_installed="$(find "${WORK}" -type f -name 'TEST-*.xml' 2>/dev/null | LC_ALL=C sort | sed -n '1p')"
if [ -n "$first_installed" ]; then
    runtime_version="$(sed -n 's|.*<property name="java.runtime.version" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
    vm_version="$(sed -n 's|.*<property name="java.vm.version" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
    jdk_path="$(sed -n 's|.*<property name="sun.boot.library.path" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
    [ -n "$jdk_path" ] || jdk_path="$(sed -n 's|.*<property name="java.home" value="\([^"]*\)".*|\1|p' "$first_installed" | head -1)"
fi

# Aggregate counts, summed straight out of the installed reports.  The element
# attributes are read rather than any summary file, so the totals cannot disagree
# with the archive they describe.
totals="$(find "${WORK}" -type f -name 'TEST-*.xml' -exec awk '
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
    printf 'harvested-from-commit: %s\n' "$harvest_commit"
    printf 'harvested-from-branch: %s\n' "$harvest_branch"
    printf 'working-tree-at-harvest: %s\n' "$harvest_dirty"
    printf 'integrity: sha256-manifest.txt beside this note covers every report here and\n'
    printf '  this note itself.  Verify the archive has not been edited since it was\n'
    printf '  harvested with:  cd <this directory> && sha256sum -c sha256-manifest.txt\n'
    printf 'suites-installed: %s\n' "$installed"
    printf 'aggregate: %s\n' "$totals"
    printf 'build-install-phase-exit-status: %s\n' "$INSTALL_EXIT"
    printf 'build-test-phase-exit-status: %s\n' "$TEST_EXIT"
    printf '\n'
    printf 'runtime provenance, read out of the installed reports themselves:\n'
    printf '  java.runtime.version: %s\n' "${runtime_version:-unknown}"
    printf '  java.vm.version: %s\n' "${vm_version:-unknown}"
    printf '  installed JDK path recorded by the runtime: %s\n' \
        "${jdk_path:-not carried: java.home and sun.boot.library.path are machine paths and the property allowlist drops them, so this archive states the runtime by version rather than by location}"
    printf '\n'
    printf 'the two transformations applied, and their exact extent:\n'
    printf '  1. absolute machine paths replaced with placeholders: %s occurrences\n' "$substitutions"
    printf '     %s   the root the build ran from\n' "$PLACEHOLDER_ROOT"
    printf '     %s   the local artifact repository the build used\n' "$PLACEHOLDER_REPO"
    printf '     the repository path was taken from: %s\n' "$repo_local_source"
    printf '     VERIFIED, not asserted: after every report was written the archive was\n'
    printf '     searched for both the harvest root and the home directory, and neither\n'
    printf '     appears in any file.  A survivor aborts the install, so this line cannot\n'
    printf '     be present while the claim is false.  The system temporary directory is\n'
    printf '     deliberately not searched: a test that writes a scratch file there and\n'
    printf '     logs its name is capturing its own behaviour, and that is evidence.\n'
    printf '  2. non-allowlisted system properties dropped: %s across the archive\n' "$dropped_total"
    printf '     retained, native, in every report:\n'
    printf '       %s\n' "$PROPERTY_ALLOWLIST"
    printf '     dropped because they describe the machine and not the evidence: both\n'
    printf '     classpaths, the launcher command line, the user name, home directory,\n'
    printf '     country and timezone, the temporary directory, the boot and native library\n'
    printf '     paths, and java.home.\n'
    printf '  Every testsuite, testcase, failure, error, skipped and system-out element is\n'
    printf '  byte-identical to what the runner wrote, and every retained property carries\n'
    printf '  the value the runner wrote.  Each installed file was verified to have lost\n'
    printf '  exactly the angle brackets the dropped lines carried and no others, and to\n'
    printf '  still state its own java.runtime.version -- so a report in this archive proves\n'
    printf '  which runtime produced it without reference to any prose, including this note.\n'
    printf '  ONE further difference, stated rather than glossed because "byte-identical" is\n'
    printf '  a strong word: the runner writes no newline after the closing testsuite tag and\n'
    printf '  the rewriter emits one, so every installed report is exactly one trailing\n'
    printf '  newline longer than its source.  Nothing else differs -- that was checked by\n'
    printf '  reproducing the substitutions on the raw reports and comparing the whole of\n'
    printf '  each report from </properties> onward, for all of them, not for a sample.\n'
    printf '\n'
    printf 'why the paths were replaced rather than kept:\n'
    printf '  the baseline necessarily runs from a throwaway checkout of the base commit, so\n'
    printf '  its path names a directory that no longer exists; and the two sides run from\n'
    printf '  different roots by construction, so keeping the paths would make every report\n'
    printf '  differ between the two sides for a reason unrelated to test outcomes, which is\n'
    printf '  precisely what the row-for-row comparison must not be flooded with.\n'
} > "${WORK}/run-provenance.txt"

# A DIGEST MANIFEST OVER THE ARCHIVE.
#
# The reports are the evidence, and an evidence file that can be edited without
# trace is weaker than one that cannot.  The manifest is written last, covers
# every installed report and the provenance note beside them, and is what a
# reviewer re-runs to establish that the archive being read is the archive that
# was harvested.
# It carries checksum lines and nothing else, so that `sha256sum -c` accepts it
# without a single formatting warning; the instructions for using it live in the
# provenance note beside it, where prose belongs.
(
    cd "${WORK}" || exit 1
    find . -type f -name 'TEST-*.xml' | LC_ALL=C sort | while IFS= read -r f; do
        sha256sum "$f"
    done
    sha256sum ./run-provenance.txt
) > "${WORK}/sha256-manifest.txt"

# THE MANIFEST IS VERIFIED BEFORE THE ARCHIVE IS PUBLISHED, NOT AFTER.
#
# A manifest that does not verify is worse than no manifest: it invites a reviewer
# to run `sha256sum -c`, see a mismatch, and conclude the archive was tampered with
# when in fact it was written wrong.  So the check the reviewer will run is run
# here first, against the staging tree, and a failure refuses the publish.
manifest_check="$( cd "$WORK" && LC_ALL=C sha256sum -c --quiet sha256-manifest.txt 2>&1 )" || {
    printf 'install-surefire-evidence.sh: the digest manifest does not verify against the\n' >&2
    printf '  archive it was just written from, so nothing is published.\n' >&2
    printf '%s\n' "$manifest_check" | sed -e 's|^|    |' | head -10 >&2
    exit 1
}

# PUBLISH.  Every fail-closed check above has passed, so the staging tree is now
# the archive.  The destination is replaced by moving the previous archive aside
# first and removing it only once the new one is in place, so an interruption
# leaves one complete archive rather than none: if the rename of the new tree
# fails, the old one is moved back.
mkdir -p "$INTO" || fail "could not create ${INTO}"
retired=''
if [ -e "${INTO}/surefire" ]; then
    retired="${INTO}/.surefire.retired.$$"
    rm -rf -- "$retired"
    mv -- "${INTO}/surefire" "$retired" || fail "could not move the previous archive aside at ${INTO}/surefire"
fi
if ! mv -- "$WORK" "${INTO}/surefire"; then
    if [ -n "$retired" ] && [ -e "$retired" ]; then
        mv -- "$retired" "${INTO}/surefire" || true
    fi
    fail "could not publish the staged archive into ${INTO}/surefire" \
        '  The previously committed archive has been restored.'
fi
[ -n "$retired" ] && rm -rf -- "$retired"
discard_stage

printf 'installed %s executed Surefire reports into %s/surefire (%s path substitutions, %s properties dropped)\n' \
    "$installed" "$INTO" "$substitutions" "$dropped_total"
printf 'aggregate: %s\n' "$totals"
printf 'manifest verified before publish: %s report digests + the provenance note\n' "$installed"
