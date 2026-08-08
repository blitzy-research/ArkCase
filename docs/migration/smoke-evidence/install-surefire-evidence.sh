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
    printf '        [--source-commit <sha>] [--source-repo <path>] [--allow-dirty] [--exclude <pattern>]\n' >&2
    printf '        [--reports-produced-at <sha>] [--evidence-prefix <path-prefix>]\n' >&2
    printf '  %s --manifest --baseline <dir> --migrated <dir> --out <file>\n' "$0" >&2
    printf '  %s --renormalise <capture-dir> --replace <literal> --with <placeholder>\n' "$0" >&2
    printf '\n' >&2
    printf 'capture identity, in install mode:\n' >&2
    printf '  A harvest root that is a git checkout supplies its own commit, branch and worktree\n' >&2
    printf '  state, and the harvest REFUSES to run from a dirty worktree unless --allow-dirty is\n' >&2
    printf '  given, because evidence attributed to a commit whose tree was not the tree that ran\n' >&2
    printf '  is evidence about nothing.  A harvest root extracted from a commit rather than\n' >&2
    printf '  checked out from one -- which is how the pre-migration side is necessarily produced --\n' >&2
    printf '  carries no repository of its own, so --source-commit names the commit and\n' >&2
    printf '  --source-repo names the repository to verify it against.  That pairing is PROVED\n' >&2
    printf '  rather than trusted: every blob of the named commit is compared against the file of\n' >&2
    printf '  the same path in the harvest root, and a single mismatch refuses the harvest.\n' >&2
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
SOURCE_COMMIT=''
SOURCE_REPO=''
REPORTS_PRODUCED_AT=''
EVIDENCE_PREFIX='docs/migration/'
ALLOW_DIRTY='no'
EXCLUDES=()
AUDIT_DIR=''
# A dirty worktree is refused by DEFAULT.  A review established that the previous
# archive recorded "7 path(s) OUTSIDE this archive differed" as a footnote and was
# then read as evidence about a commit, which it was not.  Counting a dirty path is
# not the same as accounting for it, so the choice is now explicit: either the tree
# is clean, or --allow-dirty is passed and every differing path is enumerated with
# its blob hash so a reader can reconstruct exactly what the run saw.
ALLOW_DIRTY='no'

# ---------------------------------------------------------------------------
# ARGUMENT ARITY IS CHECKED BEFORE THE SHIFT, NOT ASSUMED BY IT.
#
# Every one of the eleven value options read `${2:-}` and then `shift 2`.  When the
# option was the LAST argument, `${2:-}` yielded an empty string and `shift 2` — asked
# to shift past the end — shifted NOTHING and returned non-zero.  `$#` therefore never
# decreased and the loop spun forever on the same argument, so `--into` with a
# forgotten path HUNG instead of saying so.  Worse for two of them: an empty --from or
# --into would have fallen through to the mode checks below with a value that reads as
# "not supplied", so the diagnosis pointed at the wrong thing even when it terminated.
require_value()
{
    local opt="$1"
    local count="$2"

    if [ "$count" -lt 2 ]; then
        printf '%s: %s requires a value and none was given.\n' \
            "$(basename -- "$0")" "$opt" >&2
        printf '  Refused rather than accepted as empty: an empty value here is not the\n' >&2
        printf '  same thing as an unsupplied option, and treating them alike sent the\n' >&2
        printf '  diagnosis to the wrong place.\n' >&2
        usage
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --manifest) MODE='manifest'; shift ;;
        --audit)         require_value '--audit' "$#";         MODE='audit'; AUDIT_DIR="$2"; shift 2 ;;
        --allow-dirty)   ALLOW_DIRTY='yes'; shift ;;
        --renormalise)
            require_value '--renormalise' "$#"; MODE='renormalise'; RENORM_DIR="$2"; shift 2 ;;
        --replace)       require_value '--replace' "$#";       RENORM_FROM="$2"; shift 2 ;;
        --with)          require_value '--with' "$#";          RENORM_TO="$2"; shift 2 ;;
        --from)          require_value '--from' "$#";          FROM="$2"; shift 2 ;;
        --into)          require_value '--into' "$#";          INTO="$2"; shift 2 ;;
        --exclude)       require_value '--exclude' "$#";       EXCLUDES+=( "$2" ); shift 2 ;;
        --baseline)      require_value '--baseline' "$#";      BASELINE_DIR="$2"; shift 2 ;;
        --migrated)      require_value '--migrated' "$#";      MIGRATED_DIR="$2"; shift 2 ;;
        --out)           require_value '--out' "$#";           OUT_FILE="$2"; shift 2 ;;
        --install-exit)  require_value '--install-exit' "$#";  INSTALL_EXIT="$2"; shift 2 ;;
        --test-exit)     require_value '--test-exit' "$#";     TEST_EXIT="$2"; shift 2 ;;
        --source-commit) require_value '--source-commit' "$#"; SOURCE_COMMIT="$2"; shift 2 ;;
        --source-repo)   require_value '--source-repo' "$#";   SOURCE_REPO="$2"; shift 2 ;;
        --reports-produced-at)
            require_value '--reports-produced-at' "$#"; REPORTS_PRODUCED_AT="$2"; shift 2 ;;
        --evidence-prefix)
            require_value '--evidence-prefix' "$#"; EVIDENCE_PREFIX="$2"; shift 2 ;;
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

    # THE PREFIX IS STRIPPED BY WALKING FROM INSIDE, NOT BY A REGEX BUILT FROM A PATH.
    #
    # This used to interpolate the capture root into a sed expression:
    # `sed -e "s|^${root}/surefire/||"`.  A path is DATA and a sed script is a PROGRAM,
    # and every regex metacharacter a path may legally contain changes the meaning of
    # the program it lands in — a dot matches any character, so a neighbouring
    # directory could have its prefix stripped too; a `|` closes the expression's own
    # delimiter and a `[` opens a bracket expression, either of which makes the script
    # malformed so that sed exits without printing.  The output would then be EMPTY,
    # and empty is not an error here: the pairing check would read it as "this capture
    # archives no suites" and report all several hundred as missing from a directory
    # that in fact holds every one of them.
    #
    # Walking from inside the directory removes the interpolation entirely.  find emits
    # a leading `./`, which is a fixed two characters, so stripping it needs no
    # knowledge of the path at all.
    ( cd "${root}/surefire" 2>/dev/null && find . -type f -name 'TEST-*.xml' 2>/dev/null ) \
        | sed -e 's|^\./||' \
        | LC_ALL=C sort
}

# ---------------------------------------------------------------------------
# aggregate_counts — sum the runner's own tests/failures/errors/skipped
# attributes over a capture directory.  Used as an invariance witness: a text
# transformation that leaves these four numbers untouched has demonstrably not
# altered any recorded outcome.
# ---------------------------------------------------------------------------
# Split into two so that the same measurement can be taken of a capture ROOT (which is
# what every existing caller has) and of a bare SUREFIRE DIRECTORY (which is what the
# re-normalisation staging copy is).  One implementation, two entry points, so the
# invariance witness measured before a transformation and the one measured after cannot
# be computed two different ways.
aggregate_counts()
{
    aggregate_counts_dir "${1}/surefire"
}

aggregate_counts_dir()
{
    local root="$1"

    find "${root}" -type f -name 'TEST-*.xml' -print0 2>/dev/null \
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
# ---------------------------------------------------------------------------
# AUDIT MODE — re-verify an archive that is ALREADY ON DISK.
#
# WHY THIS MODE EXISTS, stated plainly because it exists to close a hole this
# script itself left open.  The install path verifies every report as it writes
# it, and it refuses a report that cannot state its own runtime.  What it could
# not do was notice a report REPLACED AFTERWARDS.  A review found exactly that:
# an archive of 284 reports in which 280 carried a native java.runtime.version and
# four had been substituted with hand-authored summaries whose own comments said
# their test names were "transcribed from source" and their property dumps
# "deliberately omitted" -- while the provenance note beside them still claimed
# every element was runner-byte-identical.  A write-time check cannot see that; a
# read-time check can, and this is it.
#
# Three things are asserted over every installed report, and all three are
# fail-closed:
#   1. a native java.runtime.version AND a native java.class.version.  The second
#      is the one that pins the class-file generation the runtime reads, and it was
#      absent from the write-time check.
#   2. the runner's own STRUCTURAL fingerprint.  A first draft of this check
#      searched the prose for phrases like "transcribed from" and "re-derived", and
#      it was wrong twice over: it accused two perfectly native reports whose
#      commentary happened to use those words, and it would have been satisfied by
#      an authored report that simply did not mention its own origin.  A prose
#      check tests what a report SAYS.  What matters is what the runner WRITES and
#      an author omits: a time attribute on the testsuite element and a properties
#      element.  Both are present in every one of the 278 baseline and 280 genuine
#      migrated reports and absent from exactly the four substituted ones, which is
#      what makes this the discriminating check rather than a keyword filter.
#   3. the sha256 manifest verifies, if one is present.
# ---------------------------------------------------------------------------
if [ "$MODE" = 'audit' ]; then
    [ -n "$AUDIT_DIR" ] || usage
    [ -d "${AUDIT_DIR}/surefire" ] || fail \
        "no installed archive at ${AUDIT_DIR}/surefire" \
        '  Audit mode inspects an archive that already exists; it does not create one.'

    audit_total=0
    audit_no_runtime=0
    audit_no_classversion=0
    audit_not_runner=0
    audit_empty=0
    audit_failures=''
    while IFS= read -r report; do
        [ -n "$report" ] || continue
        audit_total=$((audit_total + 1))
        if [ ! -s "$report" ]; then
            audit_empty=$((audit_empty + 1))
            audit_failures="${audit_failures}  EMPTY            ${report}
"
            continue
        fi
        if ! grep -q '<property name="java.runtime.version" value="' "$report"; then
            audit_no_runtime=$((audit_no_runtime + 1))
            audit_failures="${audit_failures}  NO-RUNTIME       ${report}
"
        fi
        if ! grep -q '<property name="java.class.version" value="' "$report"; then
            audit_no_classversion=$((audit_no_classversion + 1))
            audit_failures="${audit_failures}  NO-CLASS-VERSION ${report}
"
        fi
        if ! grep -o '<testsuite[^>]*>' "$report" | grep -q 'time="'; then
            audit_not_runner=$((audit_not_runner + 1))
            audit_failures="${audit_failures}  NO-RUNNER-TIME   ${report}
"
        elif ! grep -q '<properties>' "$report"; then
            audit_not_runner=$((audit_not_runner + 1))
            audit_failures="${audit_failures}  NO-PROPERTIES    ${report}
"
        fi
    done <<EOF
$(find "${AUDIT_DIR}/surefire" -type f -name 'TEST-*.xml' 2>/dev/null | LC_ALL=C sort)
EOF

    audit_manifest='absent'
    if [ -f "${AUDIT_DIR}/surefire/sha256-manifest.txt" ]; then
        if command -v sha256sum >/dev/null 2>&1; then
            if ( cd "${AUDIT_DIR}/surefire" \
                    && sha256sum -c sha256-manifest.txt >/dev/null 2>&1 ); then
                audit_manifest='verifies'
            else
                audit_manifest='DOES NOT VERIFY'
            fi
        else
            audit_manifest='not checked -- no sha256sum on this host'
        fi
    fi

    printf 'surefire archive audit: %s\n' "$AUDIT_DIR"
    printf '  reports inspected                        : %s\n' "$audit_total"
    printf '  without a native java.runtime.version    : %s\n' "$audit_no_runtime"
    printf '  without a native java.class.version      : %s\n' "$audit_no_classversion"
    printf '  lacking the runner structural fingerprint: %s\n' "$audit_not_runner"
    printf '  installed empty                          : %s\n' "$audit_empty"
    printf '  sha256-manifest.txt                      : %s\n' "$audit_manifest"
    if [ -n "$audit_failures" ]; then
        printf '\nfailing reports:\n%s' "$audit_failures"
    fi
    if [ "$audit_total" -eq 0 ] \
            || [ "$audit_no_runtime" -ne 0 ] \
            || [ "$audit_no_classversion" -ne 0 ] \
            || [ "$audit_not_runner" -ne 0 ] \
            || [ "$audit_empty" -ne 0 ] \
            || [ "$audit_manifest" = 'DOES NOT VERIFY' ]; then
        printf '\nAUDIT FAILED.  This archive cannot be cited as runner-produced evidence.\n' >&2
        exit 1
    fi
    printf '\nAUDIT PASSED.  Every installed report states its own runtime and class-file\n'
    printf 'version natively and carries the runner structural fingerprint -- a testsuite\n'
    printf 'time attribute and a properties element -- and the manifest state is reported\n'
    printf 'above.\n'
    exit 0
fi

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

    # ---------------------------------------------------------------------------
    # THE TRANSFORMATION IS APPLIED TO A COPY AND SWAPPED IN WHOLE.
    #
    # It used to rewrite each report IN PLACE, one `mv` at a time, from a fixed
    # `.renormalise.tmp` inside the archive itself.  Three things follow from that, and
    # the archive is the one artefact in this deliverable that cannot be regenerated:
    #
    #   * PARTIAL APPLICATION.  Any failure part way through — the markup check
    #     tripping on report 200 of 284, a full filesystem, an interrupt — left some
    #     reports transformed and the rest not.  The message even claimed "the archive
    #     has been left exactly as it was found", which by then was false for every
    #     report already renamed over.
    #   * A MANIFEST THAT MATCHES NEITHER STATE.  sha256-manifest.txt covers every
    #     report.  Rewriting reports without regenerating it leaves the archive failing
    #     its own integrity check, and a half-applied run leaves it failing in a way
    #     that cannot be told apart from corruption.
    #   * A PREDICTABLE TEMPORARY PATH inside the published tree, which is also the one
    #     path a reader would never think to look for.
    #
    # So: the whole surefire subtree is copied to a staging sibling, transformed there,
    # verified there, its manifest regenerated and checked there, and only then swapped
    # in by rename with the original moved aside first.  A failure at any point leaves
    # the published archive byte-identical, and there is no state in which the archive
    # is half-transformed.
    renorm_before="$(aggregate_counts "$RENORM_DIR")"
    renorm_files=0
    renorm_hits=0

    renorm_live="${RENORM_DIR}/surefire"
    renorm_stage="${RENORM_DIR}/.surefire.renormalise-$$"
    renorm_aside="${RENORM_DIR}/.surefire.superseded-$$"
    renorm_scratch="$(mktemp -d "${TMPDIR:-/tmp}/surefire-renorm.XXXXXX")" || \
        fail 'could not create a working directory for the re-normalisation.'
    chmod 700 "$renorm_scratch" 2>/dev/null || true
    renorm_tmp="${renorm_scratch}/report"

    # THE STAGING AREAS ARE REMOVED ON EVERY EXIT PATH, INCLUDING A SIGNAL.
    #
    # Every failure path below removes them explicitly, but a signal reaches none of
    # those paths, and the consequence is worse here than a stray temporary directory:
    # the staging copy lives INSIDE the evidence tree, so a run stopped partway leaves an
    # untracked `.surefire.renormalise-<pid>` beside the archive, and the guard a few
    # lines down then refuses every future run because it finds that leftover.  One
    # interrupted run would otherwise block re-normalisation until someone removed the
    # directory by hand.
    #
    # The handler names only the two staging paths and the scratch directory.  It never
    # names the live archive, and after the successful rename the staging path no longer
    # exists, so the handler is a no-op on the success path.
    renorm_discard()
    {
        [ -z "${renorm_scratch:-}" ] || rm -rf -- "$renorm_scratch"
        case "${renorm_stage:-}" in
            */.surefire.renormalise-*) rm -rf -- "$renorm_stage" ;;
            *) : ;;
        esac
    }
    trap renorm_discard EXIT HUP INT TERM

    if [ -e "$renorm_stage" ] || [ -e "$renorm_aside" ]; then
        rm -rf -- "$renorm_scratch"
        fail "a previous re-normalisation left ${renorm_stage} or ${renorm_aside} behind." \
             '  They are not removed automatically: one of them may hold the only intact' \
             '  copy of the archive.  Inspect them, then move or remove them by hand.'
    fi

    if ! cp -a -- "$renorm_live" "$renorm_stage"; then
        rm -rf -- "$renorm_scratch" "$renorm_stage"
        fail 'could not copy the archive into a staging directory.' \
             '  The published archive has not been touched.'
    fi

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
            rm -rf -- "$renorm_scratch" "$renorm_stage"
            fail "re-normalisation altered the markup of $(basename -- "$report")." \
                 '  The published archive has been left exactly as it was found: the' \
                 '  transformation was applied to a staging copy, which has been removed.' \
                 '  Nothing was renamed into place.'
        fi

        mv -f -- "$renorm_tmp" "$report" || exit 1
        renorm_hits=$(( renorm_hits + $(tr -d '[:space:]' < "${renorm_tmp}.count") ))
        rm -f -- "${renorm_tmp}.count"
        renorm_files=$(( renorm_files + 1 ))
    done <<EOF
$(find "$renorm_stage" -type f -name 'TEST-*.xml' 2>/dev/null | LC_ALL=C sort)
EOF

    # The invariance witness is measured on the STAGING copy against the live archive,
    # so a discrepancy is caught while the published tree is still untouched.
    renorm_after="$(aggregate_counts_dir "$renorm_stage")"
    if [ "$renorm_before" != "$renorm_after" ]; then
        rm -rf -- "$renorm_scratch" "$renorm_stage"
        fail 'the recorded outcomes changed during re-normalisation.' \
             "  before: ${renorm_before}" \
             "  after:  ${renorm_after}" \
             '  This must never happen for a text substitution; treat the transformation' \
             '  as suspect.  The published archive has not been touched and the staging' \
             '  copy has been removed.'
    fi

    # DISCLOSURE, into the archive's own provenance note — WRITTEN INTO THE STAGING
    # COPY, BEFORE THE MANIFEST IS REGENERATED.
    #
    # Ordering, not tidiness.  Appending the disclosure to the PUBLISHED note after the
    # swap changes a file the manifest already covers, so the archive fails its own
    # integrity check the moment it is published — measured: sha256sum -c reported
    # run-provenance.txt as FAILED on an archive that was otherwise perfectly
    # transformed, and smoke-checks.sh refuses to publish a capture whose archive
    # manifest does not verify.  Writing it here means the manifest is generated over
    # the archive's FINAL bytes, including this note.
    #
    # The note the install phase writes states the extent of the substitution it
    # performed.  A later corrective pass that went undisclosed there would leave
    # the note understating what had been done to the archive — which is the exact
    # defect class this whole archive exists to have escaped.  So the correction
    # writes itself down, in the note, next to the claim it qualifies.
    renorm_note="${renorm_stage}/run-provenance.txt"
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

    # THE MANIFEST IS REGENERATED AND VERIFIED IN THE STAGING COPY.
    #
    # Every report's digest has changed, so the manifest the install phase wrote no
    # longer describes the archive.  Regenerating it is not optional bookkeeping: the
    # manifest is what publish_capture in smoke-checks.sh checks the carry against, and
    # an archive whose own manifest fails now REFUSES publication there.  It is verified
    # immediately, in the staging copy, so a manifest that does not describe its own
    # directory never reaches the published tree.
    # THE NEW MANIFEST IS BUILT OUTSIDE THE DIRECTORY IT DESCRIBES.
    #
    # Writing it to a `.new` file inside the staging copy and then renaming it looks
    # tidier and is wrong: the shell creates the redirection target BEFORE the pipeline
    # runs, so `find` — walking the same directory in that very pipeline — enumerates
    # the half-written manifest it is in the middle of producing.  Measured: the
    # manifest then listed `sha256-manifest.txt.new`, a file that no longer existed by
    # the time anything verified it, and the verification failed on an archive that was
    # in fact perfectly transformed.  Building it in the scratch directory removes the
    # race rather than narrowing it.
    if ! ( cd "$renorm_stage" \
            && find . -type f ! -name 'sha256-manifest.txt' -print \
                | LC_ALL=C sort \
                | sed -e 's|^\./||' \
                | tr '\n' '\0' \
                | xargs -0 -r sha256sum -- > "${renorm_scratch}/manifest" ) \
        || ! mv -f -- "${renorm_scratch}/manifest" "${renorm_stage}/sha256-manifest.txt"
    then
        rm -rf -- "$renorm_scratch" "$renorm_stage"
        fail 'could not regenerate the checksum manifest for the re-normalised archive.' \
             '  The published archive has not been touched.'
    fi
    if ! ( cd "$renorm_stage" && LC_ALL=C sha256sum -c --quiet sha256-manifest.txt ) \
        > "${renorm_scratch}/verify" 2>&1
    then
        printf '%s\n' '--- manifest verification output ---' >&2
        sed -e 's|^|  |' "${renorm_scratch}/verify" >&2
        rm -rf -- "$renorm_scratch" "$renorm_stage"
        fail 'the regenerated manifest does not verify against the re-normalised archive.' \
             '  The published archive has not been touched.'
    fi

    # THE SWAP.  Two renames within one directory, so a reader sees the old archive or
    # the new one and never a mixture.  The original is moved aside first and removed
    # only once the replacement is in place, so a failure at either step leaves an
    # intact archive somewhere and says where.
    if ! mv -- "$renorm_live" "$renorm_aside"; then
        rm -rf -- "$renorm_scratch" "$renorm_stage"
        fail 'could not move the published archive aside.' \
             '  It has not been touched and the staging copy has been removed.'
    fi
    if ! mv -- "$renorm_stage" "$renorm_live"; then
        mv -- "$renorm_aside" "$renorm_live" 2>/dev/null || true
        rm -rf -- "$renorm_scratch"
        fail 'could not move the re-normalised archive into place.' \
             "  The original was restored from ${renorm_aside} if possible; if that" \
             '  failed it is still there and must be moved back by hand.' \
             "  The re-normalised copy is at ${renorm_stage}."
    fi
    rm -rf -- "$renorm_aside" "$renorm_scratch"

    printf 're-normalised %s report(s) in %s: %s occurrence(s) replaced\n' \
        "$renorm_files" "${RENORM_DIR}/surefire" "$renorm_hits"
    printf '  replaced: %s\n' "$RENORM_FROM"
    printf '  with:     %s\n' "$RENORM_TO"
    printf '  recorded outcomes unchanged: %s\n' "$renorm_after"
    # Reported at its PUBLISHED path, not the staging path the note was written into.
    # The staging directory is gone by now — it became the archive — so naming it would
    # point an operator at something that no longer exists.
    if [ -f "${renorm_live}/run-provenance.txt" ]; then
        printf '  disclosed in: %s\n' "${renorm_live}/run-provenance.txt"
    fi
    printf '  checksum manifest regenerated and verified over the re-normalised archive\n'
    printf '  swapped into place by rename; the previous archive was moved aside first and\n'
    printf '  removed only once the replacement was in place\n'
    exit 0
fi

if [ "$MODE" = 'manifest' ]; then
    if [ -z "$BASELINE_DIR" ] || [ -z "$MIGRATED_DIR" ] || [ -z "$OUT_FILE" ]; then
        usage
    fi

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/surefire-manifest.XXXXXX")" \
        || fail 'could not create a scratch directory'
    trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM

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
    } > "${OUT_FILE}.$$.staging"
    manifest_status=$?

    # FAIL CLOSED, AND PUBLISH ATOMICALLY.
    #
    # This mode used to redirect straight at the contract and exit zero whatever it had
    # counted.  Point it at a directory that holds no reports -- which is what happens when
    # a caller passes the surefire subdirectory instead of the capture directory, an easy
    # mistake because both spellings look right -- and it replaced a 284-row pairing
    # contract with a 0-row one and reported success.  A contract that lists nothing is
    # satisfied by any capture, so the very check it exists to perform silently stops
    # happening.  A contract with no suites is refused, and the previous one is left in
    # place; a partially written one is never published, because publication is a single
    # rename of a completed staging file.
    if [ "$manifest_status" -ne 0 ]; then
        rm -f -- "${OUT_FILE}.$$.staging"
        printf '%s: the manifest was not written completely, so %s was left untouched.\n' \
            "$(basename -- "$0")" "$OUT_FILE" >&2
        exit "$manifest_status"
    fi
    if [ "$((both + only_b + only_m))" -eq 0 ]; then
        rm -f -- "${OUT_FILE}.$$.staging"
        printf '%s: refusing to write a pairing contract with no suites in it.\n' \
            "$(basename -- "$0")" >&2
        printf '  baseline: %s\n' "$BASELINE_DIR" >&2
        printf '  migrated: %s\n' "$MIGRATED_DIR" >&2
        printf '  Neither side yielded a TEST-<class>.xml report.  Each argument must name a\n' >&2
        printf '  CAPTURE directory -- the one that CONTAINS surefire/ -- and not the surefire\n' >&2
        printf '  directory itself.  %s is untouched.\n' "$OUT_FILE" >&2
        exit 2
    fi
    if [ -L "$OUT_FILE" ] || { [ -e "$OUT_FILE" ] && [ ! -f "$OUT_FILE" ]; }; then
        rm -f -- "${OUT_FILE}.$$.staging"
        printf '%s: refusing to publish over %s: it is not a plain file.\n' \
            "$(basename -- "$0")" "$OUT_FILE" >&2
        exit 2
    fi
    if ! mv -f -- "${OUT_FILE}.$$.staging" "$OUT_FILE"; then
        rm -f -- "${OUT_FILE}.$$.staging"
        printf '%s: could not move the staged manifest into place at %s.\n' \
            "$(basename -- "$0")" "$OUT_FILE" >&2
        printf '  The previous file, if any, is untouched.\n' >&2
        exit 2
    fi

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
    # The secret scratch directory goes with the staging tree.  It is created later, once
    # the allowlist needle is known, and is removed explicitly on the paths that reach
    # the end of the run — but a failure or a signal in between would otherwise leave a
    # mode-700 directory holding that needle in a shared temporary area.  Naming it here
    # means one handler covers both, and it is empty until the secret scan starts.
    if [ -n "${SECRET_SCRATCH:-}" ]; then
        case "$SECRET_SCRATCH" in
            */surefire-secret.*) rm -rf -- "$SECRET_SCRATCH" ;;
            *) : ;;
        esac
    fi
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
    # java.class.version is checked alongside the runtime version because it is the
    # property that pins the class-file generation the runtime reads -- 52.0 against
    # 61.0 is the whole migration in one attribute -- and the previous revision of
    # this check looked only at the runtime version.  A published register cited a
    # 284-of-284 class-version count the archive did not support, and a write-time
    # check that never looked at the property is why nothing objected.
    if ! grep -q '<property name="java.class.version"' "${WORK}/${module}/${base}"; then
        printf 'install-surefire-evidence.sh: %s carries no native java.class.version.\n' "$base" >&2
        printf '  Refusing to continue: the class-file version is the property that\n' >&2
        printf '  distinguishes the two runtimes this evidence compares.\n' >&2
        exit 1
    fi
    if ! grep -o '<testsuite[^>]*>' "${WORK}/${module}/${base}" | grep -q 'time="'; then
        printf 'install-surefire-evidence.sh: %s has no time attribute on its testsuite.\n' "$base" >&2
        printf '  The runner always writes one.  Its absence means the file being installed is\n' >&2
        printf '  not runner output.  Refusing to continue.\n' >&2
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
# strip_work_prefix — make a path under the archive relative, without a regex.
#
# THE SAME DEFECT AS suite_rows, IN TWO DIAGNOSTIC MESSAGES.  Both interpolated the
# archive path into a sed expression — `sed -e "s|^${WORK}/||"` — so every regex
# metacharacter a temporary path may contain changed the program's meaning, and a `|`
# would have made it malformed so that sed printed nothing at all.  These two sites are
# less consequential than suite_rows because they only shorten a path in a refusal
# message, but the failure is the same and so is the remedy: strip a known prefix with
# parameter expansion, which treats the prefix as the DATA it is.
strip_work_prefix()
{
    local line

    while IFS= read -r line; do
        printf '%s\n' "${line#"${WORK}"/}"
    done
}

# ---------------------------------------------------------------------------
# THE TWO LEDGERS LIVE IN A PRIVATE DIRECTORY, NOT AT A PREDICTABLE NAME.
#
# Both were built as `${TMPDIR:-/tmp}/surefire-secret-...$$`.  A process identifier is
# not a secret and it is not unpredictable — it is readable from the process table and
# it recycles — so in a shared /tmp any other account could pre-create either path as a
# symbolic link and have this script write through it, or replace the allowlist between
# its creation and its use.  The allowlist is the file that decides which matches are
# WAIVED, so an attacker who controls it controls whether the credential scan finds
# anything: adding one line to it makes a real secret in the archive pass silently.
#
# mktemp -d gives a name that cannot be guessed and a directory that can be made
# owner-only, so neither file is reachable by another account at all.
SECRET_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/surefire-secret.XXXXXX")" || {
    printf '%s: could not create a private directory for the credential scan\n' \
        "$(basename -- "$0")" >&2
    exit 1
}
chmod 700 "$SECRET_SCRATCH" 2>/dev/null || true
SECRET_ALLOWLIST_FILE="${SECRET_SCRATCH}/allowlist"
: > "$SECRET_ALLOWLIST_FILE"
chmod 600 "$SECRET_ALLOWLIST_FILE" 2>/dev/null || true
{
    printf '%s\n' 'eyJhbGciOiJIUzI1NiJ9.ewogICJzdWIiOiAiMTIzNDU2Nzg5MCIsCiAgIm5hbWUiOiAiSm9obiBEb2UiLAogICJpYXQiOiAxNTE2MjM5MDIyCn0.0Gh1Ilzj9aeD2gxmjTn2U-Yo-NxpW8hMet_CY6bDkKg'
    printf '%s\n' 'ann-acm@arkcase.org'
    printf '%s\n' 'arkcase-admin@arkcase.org'
    printf '%s\n' 'ian-acm@arkcase.org'
} >> "$SECRET_ALLOWLIST_FILE"

secret_hits="${SECRET_SCRATCH}/hits"
: > "$secret_hits"
chmod 600 "$secret_hits" 2>/dev/null || true

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

    # THE SECRET IS FED THROUGH STANDARD INPUT, NEVER THROUGH argv.
    #
    # This passed the value as a grep operand.  A command's arguments are world-readable
    # on this platform for as long as it runs — /proc/<pid>/cmdline, and every `ps` on
    # the host — so scanning the archive for a credential DISCLOSED that credential to
    # any unprivileged process watching, once per invocation, for every secret checked.
    # The comment a few lines below already promised the opposite: "never passed through
    # a command line that another process could observe".  It is now true.
    #
    # `-f -` makes grep read its patterns from standard input, so the value travels
    # through a pipe this process owns.  A here-string is used rather than a temporary
    # file because a file, however well permissioned, is a second place the secret
    # exists; the pipe leaves no artefact at all.
    LC_ALL=C grep -rFlZ -f - -- "${WORK}" --include='*.xml' 2>/dev/null <<< "$value" \
        | tr '\0' '\n' | while IFS= read -r file; do
        [ -n "$file" ] || continue
        if LC_ALL=C grep -qxF -f - -- "$SECRET_ALLOWLIST_FILE" <<< "$value"; then
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
        | sed -e 's|\t| in |' | strip_work_prefix | sed -e 's|^|    |' >&2
    printf '  Remediation: fix the TEST so it stops emitting the value.  Do NOT redact the\n' >&2
    printf '  report: these files are machine output and editing them is the defect this\n' >&2
    printf '  archive is being corrected for.  If the value is genuinely a deterministic,\n' >&2
    printf '  public test fixture, add its EXACT literal to the allowlist in this script\n' >&2
    printf '  together with the reason and the test source that emits it.\n' >&2
    rm -rf -- "$SECRET_SCRATCH"
    exit 1
fi
rm -rf -- "$SECRET_SCRATCH"

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
            | strip_work_prefix | sed -e 's|^|    |' | head -10 >&2
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
#
# THREE DEFECTS THIS BLOCK NOW CLOSES, each of which actually occurred in this
# archive and each of which is the reason a line below exists.
#
#   (a) A RECORDED COMMIT NO BRANCH REACHED.  A previous revision of the migrated
#       note recorded a harvested-from-commit value that no branch in this repository
#       reaches, because the harvest ran from a scratch clone whose history was never
#       published.  The hash is not repeated here: it names nothing a reader can
#       inspect, and every identity this evidence prints is required to RESOLVE, which
#       verify-evidence-identities.sh enforces.  A commit is therefore now RESOLVED
#       against a repository and recorded as resolvable or not, and its relationship to
#       the head is recorded beside it -- reported rather than required, because a
#       consolidated delivery leaves the intermediate states the producers ran at outside
#       the delivered commit's ancestry by construction, whereas the defect this entry
#       closed resolved to no object at all.  The distinction is what stops an
#       unresolvable identity being published as though it were an anchor.
#   (b) A DIRTY TREE TREATED AS A FOOTNOTE.  Recording "7 paths differed" is honest
#       but useless: a reader cannot tell whether the seven were the change set under
#       test or an unrelated scratch file.  The harvest now REFUSES a dirty worktree
#       by default and records the exact porcelain lines when --allow-dirty is used,
#       so the state is either provably clean or fully enumerated.
#   (c) AN EXTRACTED TREE WITH NO IDENTITY AT ALL.  The pre-migration half must be
#       built from a tree extracted out of the base commit, which carries no
#       repository, so its note previously carried no commit field whatsoever.  It
#       now carries one that is PROVED: every blob of the named commit is hashed
#       against the file of the same path in the harvest root.
#
harvest_commit='not-a-git-checkout'
harvest_branch='not-a-git-checkout'
harvest_dirty='not-a-git-checkout'
harvest_porcelain='not-a-git-checkout'
harvest_commit_resolved='not-checked'
harvest_commit_reachable='not-checked'
harvest_tree_proof='not-applicable -- the harvest root is a git checkout, so its own HEAD is the identity'
identity_repo=''

# THE HARVEST ROOT COUNTS AS ITS OWN CHECKOUT ONLY IF IT *IS* THE TOPLEVEL.
# An extracted tree placed inside a checkout -- which is where a scratch extraction
# necessarily lives -- makes `rev-parse --git-dir` succeed, because git walks upwards
# and finds the ENCLOSING repository.  Taking that as "the harvest root is a git
# checkout" attributes the extracted tree to the enclosing checkout's HEAD and then
# judges its cleanliness by the enclosing checkout's status, which is wrong twice
# over: the identity belongs to a different commit, and the archive being written
# elsewhere in that checkout shows up as dirt.  Comparing the toplevel against the
# harvest root is the exact test.
from_toplevel="$(git -C "$FROM_ABS" rev-parse --show-toplevel 2>/dev/null || printf '')"
if [ -n "$from_toplevel" ] && [ "$from_toplevel" = "$FROM_ABS" ]; then
    identity_repo="$FROM_ABS"
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
    dirty_paths="$(git -C "$FROM_ABS" status --porcelain 2>/dev/null \
        | grep -v -F -- "${into_rel}/surefire/" \
        | grep -v -F -- "${stage_rel}" \
        | awk '{ print $NF }' || true)"
    dirty_count="$(printf '%s' "$dirty_paths" | grep -c . || true)"
    # THE COUNT IS SPLIT BY WHETHER A PATH COULD HAVE CHANGED THE RUN.
    #
    # A bare count of differing paths tells a reader that the tree was not the
    # commit and nothing more, which is the least useful true statement available:
    # it cannot distinguish a modified test class from a modified paragraph of
    # prose, and only one of those can move a test outcome.  So the paths are
    # classified.  Anything under documentation, the navigation file, the readme or
    # the pipeline definition cannot reach a compiler or a runner; everything else
    # is counted as able to, whether or not it did, because assuming otherwise is
    # how a real difference gets waved through.
    dirty_docs="$(printf '%s\n' "$dirty_paths" \
        | grep -c -E '^(docs/|README\.md|mkdocs\.yml|\.gitlab-ci)' || true)"
    dirty_code="$(printf '%s\n' "$dirty_paths" \
        | grep -c . || true)"
    dirty_lines="$(git -C "$FROM_ABS" status --porcelain 2>/dev/null \
        | grep -v -F -- "${into_rel}/surefire/" \
        | grep -v -F -- "${stage_rel}" || true)"
    if [ "${dirty_count:-0}" -eq 0 ]; then
        harvest_dirty='clean -- every file outside this archive tracked and unmodified'
        harvest_porcelain='empty -- git status --porcelain reported no line outside this archive'
    elif [ "$ALLOW_DIRTY" = 'yes' ]; then
        harvest_dirty="$(printf '%s path(s) OUTSIDE this archive differed from the commit above, of which %s cannot reach a compiler or a runner (documentation, the navigation file, the readme, the pipeline definition) and %s are counted as able to, so the capture is evidence about the working tree at that moment rather than about the commit alone. This archive itself is excluded from the count, which would otherwise be self-referential and unstable. The harvest was invoked with --allow-dirty, which is why it ran at all' "$dirty_count" "$dirty_docs" "$((dirty_code - dirty_docs))")"
        harvest_porcelain="$(printf '%s line(s), reproduced verbatim below so a reader can judge them rather than take a count on trust:\n%s' \
            "$dirty_count" "$(printf '%s\n' "$dirty_lines" | sed 's/^/    /')")"
    else
        fail 'the harvest root has uncommitted changes and no --allow-dirty was given' \
            '  Evidence attributed to a commit whose tree was NOT the tree that produced it is' \
            '  evidence about nothing, and a count of differing paths in a note is not a remedy:' \
            '  a reader cannot tell an unrelated scratch file from the change set under test.' \
            '  Commit the tree and re-run, or pass --allow-dirty to record the exact porcelain' \
            '  lines and accept that the archive describes a working tree rather than a commit.' \
            "  git status --porcelain reported ${dirty_count} line(s) outside this archive:" \
            "$(printf '%s\n' "$dirty_lines" | sed 's/^/    /')"
    fi
fi

# An extracted tree carries no repository, so the commit is named by the caller and
# then PROVED against one.  --source-repo defaults to the directory this script lives
# in, which is inside the repository that owns the archive.
if [ -n "$SOURCE_COMMIT" ]; then
    if [ -z "$SOURCE_REPO" ]; then
        SOURCE_REPO="$(cd "$(dirname -- "$0")" && pwd -P)"
    fi
    git -C "$SOURCE_REPO" rev-parse --git-dir >/dev/null 2>&1 \
        || fail "--source-repo is not a git repository: ${SOURCE_REPO}"
    full_sha="$(git -C "$SOURCE_REPO" rev-parse --verify "${SOURCE_COMMIT}^{commit}" 2>/dev/null)" \
        || fail "--source-commit does not resolve to a commit in ${SOURCE_REPO}: ${SOURCE_COMMIT}" \
                '  A capture cannot be anchored to an identity the published repository cannot' \
                '  produce.  That is the exact defect this check exists to prevent.'
    identity_repo="$SOURCE_REPO"
    harvest_commit="$full_sha"
    harvest_branch="$(git -C "$SOURCE_REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unreadable')"
    harvest_dirty='not-a-git-checkout -- this harvest root was EXTRACTED from the commit above rather than checked out, so it has no worktree state of its own; the tree proof below is what stands in its place'
    harvest_porcelain='not-applicable -- an extracted tree has no index and therefore no porcelain status; see tracked-tree-proof'

    # THE PROOF.  Every blob the commit records is hashed out of the harvest root and
    # compared to the blob id the commit names.  A missing file or a differing hash
    # refuses the harvest, so "this tree is that commit" is a measured statement.
    # Build outputs are untracked and therefore absent from ls-tree, so the presence
    # of target/ directories cannot perturb the comparison.
    proof_tmp="${STAGE_ROOT}.treeproof"
    mkdir -p "$proof_tmp" || fail "could not create ${proof_tmp}"
    git -C "$SOURCE_REPO" ls-tree -r "$full_sha" > "${proof_tmp}/lstree" 2>/dev/null \
        || fail "could not list the tree of ${full_sha}"
    # ls-tree emits "<mode> <type> <sha>\t<path>".  Symlinks (mode 120000) hash their
    # target text rather than file content, so they are counted and compared through
    # git's own hasher too, which handles them; only gitlinks (mode 160000) are
    # skipped, because a submodule pointer is not a blob in this tree.
    awk -F'\t' '$1 !~ /^160000/ { print $2 }' "${proof_tmp}/lstree" > "${proof_tmp}/paths"
    awk -F'\t' '$1 !~ /^160000/ { split($1, a, " "); print a[3] }' "${proof_tmp}/lstree" > "${proof_tmp}/want"
    proof_total="$(grep -c . "${proof_tmp}/paths" || true)"
    proof_missing=0
    : > "${proof_tmp}/abs"
    : > "${proof_tmp}/present"
    : > "${proof_tmp}/wantpresent"
    paste "${proof_tmp}/want" "${proof_tmp}/paths" > "${proof_tmp}/wantpath"
    while IFS="$(printf '\t')" read -r want p; do
        if [ -e "${FROM_ABS}/${p}" ]; then
            printf '%s/%s\n' "$FROM_ABS" "$p" >> "${proof_tmp}/abs"
            printf '%s\n' "$want" >> "${proof_tmp}/wantpresent"
            printf '%s\n' "$p" >> "${proof_tmp}/present"
        else
            proof_missing=$((proof_missing + 1))
        fi
    done < "${proof_tmp}/wantpath"
    # ABSOLUTE PATHS ARE MANDATORY HERE, AND THE REASON IS A TRAP WORTH NAMING.
    # `git hash-object --stdin-paths` resolves a RELATIVE path against the enclosing
    # repository's toplevel, NOT against the process working directory.  An extracted
    # tree that happens to sit inside a checkout -- which is exactly where a scratch
    # extraction lives -- therefore gets its paths silently resolved against the
    # CHECKOUT, so the proof would hash the migrated files and compare them to the base
    # commit's blobs.  It would then report hundreds of mismatches for a tree that is
    # in fact correct, and, far worse, it would report a MATCH for a checkout that
    # happened to be at the named commit while the extracted tree was something else
    # entirely.  Feeding absolute paths removes the ambiguity completely.
    if [ -s "${proof_tmp}/abs" ]; then
        git hash-object --stdin-paths < "${proof_tmp}/abs" > "${proof_tmp}/got" 2>/dev/null \
            || fail 'could not hash the harvest root against the named commit'
    else
        : > "${proof_tmp}/got"
    fi
    proof_diff="$(paste "${proof_tmp}/wantpresent" "${proof_tmp}/got" | awk '$1 != $2 { n += 1 } END { print n + 0 }')"
    paste "${proof_tmp}/present" "${proof_tmp}/wantpresent" "${proof_tmp}/got" \
        | awk -F'\t' '$2 != $3 { print $1 }' > "${proof_tmp}/differing"
    if [ "$proof_missing" -ne 0 ] || [ "$proof_diff" -ne 0 ]; then
        first_differing="$(sed -n '1,10p' "${proof_tmp}/differing" | sed 's/^/    /')"
        rm -rf -- "$proof_tmp"
        fail "the harvest root is NOT the tree of ${full_sha}" \
            "  blobs the commit records: ${proof_total}" \
            "  paths absent from the harvest root: ${proof_missing}" \
            "  paths present but differing in content: ${proof_diff}" \
            '  the first differing paths, up to ten:' \
            "$first_differing" \
            '  Refusing to attribute this archive to a commit whose tree it does not carry.'
    fi
    harvest_tree_proof="$(printf 'PROVED -- all %s blobs the commit records were hashed out of the harvest root with git hash-object and every one matched; 0 absent, 0 differing. Build output is untracked and therefore absent from the comparison by construction' "$proof_total")"
    rm -rf -- "$proof_tmp"
fi

# WHEN THE HARVEST COMMIT IS NOT THE COMMIT THAT PRODUCED THE REPORTS.
#
# A harvest reads reports that a build wrote earlier, and between the build and the
# harvest the tree can legitimately advance -- committing the previous half of the
# evidence, for instance, is exactly such an advance.  Recording only the harvest
# commit then overstates the link, and re-running the whole suite after every
# documentation commit is a treadmill that never terminates, because the commit that
# publishes the archive always comes after the harvest that produced it.
#
# So the producing commit is named and the RELATIONSHIP is proved instead: every path
# that differs between the producing commit and the harvest commit must lie under the
# declared evidence prefix.  If one does not, the reports describe a different reactor
# than the harvest commit carries and the harvest refuses.  That turns a hand-waved
# "nothing important changed" into a check with a list behind it.
reports_produced_at='same as the harvest commit above'
if [ -n "$REPORTS_PRODUCED_AT" ]; then
    prod_repo="${identity_repo:-}"
    [ -n "$prod_repo" ] || prod_repo="${SOURCE_REPO:-$(cd "$(dirname -- "$0")" && pwd -P)}"
    prod_sha="$(git -C "$prod_repo" rev-parse --verify "${REPORTS_PRODUCED_AT}^{commit}" 2>/dev/null)" \
        || fail "--reports-produced-at does not resolve to a commit in ${prod_repo}: ${REPORTS_PRODUCED_AT}"
    if [ "$prod_sha" = "$harvest_commit" ]; then
        reports_produced_at="$(printf '%s -- the same commit the harvest ran at' "$prod_sha")"
    else
        outside="$(git -C "$prod_repo" diff --name-only "$prod_sha" "$harvest_commit" 2>/dev/null \
            | grep -v -E "^${EVIDENCE_PREFIX}" || true)"
        outside_count="$(printf '%s' "$outside" | grep -c . || true)"
        if [ "${outside_count:-0}" -ne 0 ]; then
            fail "the reports were produced by a build of ${prod_sha}, but ${outside_count} path(s) outside ${EVIDENCE_PREFIX} differ between that commit and the harvest commit ${harvest_commit}" \
                '  These reports therefore describe a different reactor than the harvest commit carries.' \
                '  Re-run the suite at the harvest commit, or widen --evidence-prefix only if every' \
                '  differing path really is evidence rather than system under test.' \
                "$(printf '%s\n' "$outside" | sed -n '1,20p' | sed 's/^/    /')"
        fi
        changed_total="$(git -C "$prod_repo" diff --name-only "$prod_sha" "$harvest_commit" 2>/dev/null | grep -c . || true)"
        reports_produced_at="$(printf '%s -- a build of THAT commit wrote these reports; the harvest then ran at %s. PROVED SAFE: of the %s path(s) differing between the two, 0 lie outside %s, so the reactor source these reports describe is the reactor source the harvest commit carries' \
            "$prod_sha" "$harvest_commit" "$changed_total" "$EVIDENCE_PREFIX")"
    fi
fi

# Resolvability and reachability of whatever identity was arrived at above.
if [ -n "$identity_repo" ] && [ "$harvest_commit" != 'not-a-git-checkout' ] && [ "$harvest_commit" != 'unreadable' ]; then
    if git -C "$identity_repo" cat-file -e "${harvest_commit}^{commit}" 2>/dev/null; then
        harvest_commit_resolved="yes -- ${harvest_commit} resolves to a commit object in the repository that owns this archive"
        # THE WORDING HERE IS CHOSEN TO STAY TRUE AS WORK CONTINUES.  An earlier version
        # recorded "it IS the head of <branch>", which is a claim that falsifies itself the
        # moment the next commit lands -- and the next commit is necessarily the one that
        # commits this very archive.  Reachability is the durable property: a commit that is
        # reachable from the branch stays reachable, whereas being the head does not.  The
        # head observed AT HARVEST TIME is recorded separately and labelled as such, because
        # a fact about a moment cannot go stale.
        branch_head="$(git -C "$identity_repo" rev-parse "$harvest_branch" 2>/dev/null || printf '')"
        if [ -z "$branch_head" ]; then
            harvest_commit_reachable="branch head unreadable, so reachability could not be established"
        elif [ "$branch_head" = "$harvest_commit" ] \
            || git -C "$identity_repo" merge-base --is-ancestor "$harvest_commit" "$branch_head" 2>/dev/null; then
            harvest_commit_reachable="yes -- reachable from ${harvest_branch}; that branch's head when this harvest ran was ${branch_head}, and later commits do not affect reachability"
        else
            harvest_commit_reachable="NO -- not reachable from ${harvest_branch}, whose head when this harvest ran was ${branch_head}"
        fi
    else
        harvest_commit_resolved="NO -- ${harvest_commit} does not resolve to a commit object; the identity is unusable"
        harvest_commit_reachable='NO -- an unresolvable identity cannot be reachable'
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
    printf 'commit-resolves-in-this-repository: %s\n' "$harvest_commit_resolved"
    printf 'commit-reachable-from-branch: %s\n' "$harvest_commit_reachable"
    printf 'working-tree-at-harvest: %s\n' "$harvest_dirty"
    printf 'git-status-porcelain-at-harvest: %s\n' "$harvest_porcelain"
    printf 'tracked-tree-proof: %s\n' "$harvest_tree_proof"
    printf 'reports-produced-by-a-build-of: %s\n' "$reports_produced_at"
    printf 'integrity: sha256-manifest.txt beside this note covers every file in this\n'
    printf '  archive -- every report, this note itself, and every file under notes/.\n'
    printf '  Verify the archive has not been edited since it was harvested with:\n'
    printf '    cd <this directory> && sha256sum -c sha256-manifest.txt\n'
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
    printf '  still state its own java.runtime.version, its own java.class.version and the\n'
    printf '  time attribute the runner wrote on its testsuite element -- so a report in this\n'
    printf '  archive proves which runtime produced it without reference to any prose,\n'
    printf '  including this note.  Re-verify the archive AFTER the fact, which is the check\n'
    printf '  this note cannot make for itself, with:\n'
    printf '    install-surefire-evidence.sh --audit <this capture directory>\n'
    printf '  That mode exists because a write-time check cannot see a report replaced\n'
    printf '  after the harvest, and four reports in an earlier revision of this archive\n'
    printf '  were replaced exactly that way.\n'
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

# NO AUTHORED NARRATIVE MAY REACH THE ARCHIVE — a fail-closed gate, run against the
# staging tree before anything is published.
#
# The runner writes no XML comment, so a comment in an installed report can only
# have been put there by a person.  A previous revision of this archive carried
# exactly that: nine reports with hand-written provenance prose inside them, while
# the note beside them stated that nothing had been authored.  The two are not
# reconcilable, and the damage is not the prose itself — it is that a reader can no
# longer tell which bytes came from the runner.  Prose about the archive belongs in
# the provenance note and in the register that cites it, never inside a report.
#
# The gate refuses rather than strips.  Stripping would silently discard something a
# person deliberately wrote, and it would leave the archive's digests disagreeing
# with whatever produced them; refusing leaves the operator to move the prose where
# it belongs.
authored_comment_hits="$(LC_ALL=C grep -rl -- '<!--' "${WORK}" --include='TEST-*.xml' 2>/dev/null | LC_ALL=C sort || true)"
if [ -n "$authored_comment_hits" ]; then
    printf 'install-surefire-evidence.sh: the staged archive carries XML comments, and the\n' >&2
    printf '  test runner writes none - so this content was authored.  Nothing is published.\n' >&2
    printf '%s\n' "$authored_comment_hits" | sed -e "s|^${WORK}/|    |" >&2
    printf '  Move the narrative into run-provenance.txt or into the register that cites\n' >&2
    printf '  this archive, and re-run the harvest.\n' >&2
    discard_stage
    exit 1
fi

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
# CARRY THE AUTHORED NOTES FORWARD, BEFORE the manifest is written so they are
# covered by it.
#
# notes/ holds the long-form records that belong to this archive and that this
# script does not produce: the relocated report provenance annotations, and the
# register of a harvest defect found on one side.  Publication below replaces
# <capture>/surefire WHOLESALE, which is what guarantees no report from an earlier
# harvest survives - and is also what would silently delete every one of those
# notes, because the staging tree never contained them.
#
# They are copied across here from the archive being replaced.  Only notes/ is
# carried, and a staged file is never overwritten, so this cannot become a general
# survival route for a stale report: a report lives in a module directory and no
# module directory is touched by this.
carried_notes=0
if [ -d "${INTO}/surefire/notes" ]; then
    mkdir -p "${WORK}/notes" || fail "could not create the notes directory in the staging tree"
    for note in "${INTO}"/surefire/notes/*; do
        [ -f "$note" ] || continue
        note_base="$(basename -- "$note")"
        if [ -e "${WORK}/notes/${note_base}" ]; then
            printf 'install-surefire-evidence.sh: not carrying notes/%s forward: this run wrote it.\n' \
                "$note_base" >&2
            continue
        fi
        cp -p -- "$note" "${WORK}/notes/${note_base}" || \
            fail "could not carry the authored note notes/${note_base} forward" \
                '  Refusing to publish an archive that would lose it.'
        carried_notes=$((carried_notes + 1))
    done
fi

# THE MANIFEST COVERS EVERY FILE IN THE ARCHIVE, not only the reports.
#
# An earlier revision covered the reports and the provenance note, which left the
# authored notes beside them uncovered - editable without trace in a directory
# whose whole purpose is that it cannot be.  Every file is covered now, which is
# also what lets the notes state that they are.
(
    cd "${WORK}" || exit 1
    find . -type f -name 'TEST-*.xml' | LC_ALL=C sort | while IFS= read -r f; do
        sha256sum "$f"
    done
    sha256sum ./run-provenance.txt
    find ./notes -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
        sha256sum "$f"
    done
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

# COMPANION MATERIAL IN THE DESTINATION IS CARRIED FORWARD, AND THIS IS A REPAIRED
# DEFECT.  Because publishing REPLACES the destination directory wholesale, anything
# committed beside the module directories was silently destroyed by the next harvest.
# That is exactly what happened to baseline/surefire/notes/, a committed explanatory
# note about the property allowlist: a harvest that adds nothing and removes a
# deliverable is a regression, and it left no diagnostic at all.  Directories the
# harvest does not itself write are therefore moved across from the retired archive.
# The two control files it DOES write -- the provenance note and the checksum
# manifest -- are deliberately not carried, because a stale one of either would
# describe a run that no longer exists.
carried_forward=0
if [ -n "$retired" ] && [ -d "$retired" ]; then
    for companion in "$retired"/*/; do
        [ -d "$companion" ] || continue
        cname="$(basename -- "$companion")"
        # A module directory is one the new archive also has; anything else is
        # companion material.  Reports are never carried: only directories the new
        # harvest did not produce at all.
        if [ ! -e "${INTO}/surefire/${cname}" ]; then
            if find "$companion" -type f -name 'TEST-*.xml' -print -quit 2>/dev/null | grep -q .; then
                printf 'install-surefire-evidence.sh: NOT carrying %s forward -- it holds report XML from the retired archive.\n' "$cname" >&2
                continue
            fi
            mv -- "$companion" "${INTO}/surefire/${cname}" \
                && carried_forward=$((carried_forward + 1))
        fi
    done
fi
[ -n "$retired" ] && rm -rf -- "$retired"
discard_stage

printf 'installed %s executed Surefire reports into %s/surefire (%s path substitutions, %s properties dropped)\n' \
    "$installed" "$INTO" "$substitutions" "$dropped_total"
printf 'aggregate: %s\n' "$totals"
printf 'manifest verified before publish: %s report digests + the provenance note\n' "$installed"
printf 'companion directories carried forward from the retired archive: %s\n' "$carried_forward"
