#!/bin/bash
# restore-frontend-artifact-records.sh — write one capture side's frontend artifact digest records
# from a measured authority, validate every record on read-back, and FAIL CLOSED on an absent one.
#
# WHY THIS PROGRAM EXISTS.  The five digest records are the only behavioural evidence the frontend
# track has: the frontend tree contains no spec files, so a byte comparison of the built assets is
# all there is.  A consolidation run of the capture producer was taken against a tree whose build
# outputs had been cleaned, and its digest() helper does exactly what it says it does for a missing
# file — it writes the token ABSENT.  Ten records were overwritten that way while the gate note, the
# completeness verdict, the cross-capture comparison and the adjudication record all still carried
# the measured values.  Four records said the digests were produced; ten said they did not exist.
#
# The capture producer cannot repair that, and must not: it writes what it measures, and it cannot
# measure a build that no longer exists on disk.  Restoring a measurement is a different operation
# from taking one, so it gets its own program, with the properties the failure showed were missing:
#
#   FAIL CLOSED.  A required artifact whose authority carries no well-formed digest stops the run
#     with a non-zero status and NOTHING is written.  There is no path through this script that
#     records ABSENT.  Identical absence on two sides compares equal, so evidence that passes when
#     absent is worse than no evidence at all — it is trusted.
#   SCHEMA PINNED AT THE POINT OF WRITING AND CHECKED ON READ-BACK.  Records are written as
#     "<64 lower-case hex><two spaces><artifact key>", and every record is read back off disk and
#     re-validated before this script reports success.  A hand-edited or path-qualified record is
#     then a detected condition rather than an invisible one.
#   AUTHORITY NAMED IN THE OUTPUT.  Each record set states the file its digests came from and that
#     file's own SHA-256, so a reader can re-derive the records rather than believe them.
#
# WHAT AN AUTHORITY IS.  A committed measurement: a file holding lines of the form
# "<64 hex><whitespace><path or key>", produced by a real build.  The two used for this deliverable
# are historical-frontend/artifact-digests-node8.txt (the pre-migration build, taken on the
# historical Node line, which cannot be re-taken because that deployment cannot be rebuilt from this
# tree) and historical-frontend/artifact-digests-node20.txt (the migrated build, which CAN be
# re-taken and was: capture-frontend-artifacts.sh reproduces all six digests from a clean extraction).
#
# WHAT IT DELIBERATELY DOES NOT TOUCH.  notes/artifact-gate.txt, notes/completeness.txt,
# notes/manifest.txt and comparison.txt are capture records.  Their statements about the digests were
# TRUE when they were written and became false only because the records beneath them were
# overwritten; restoring the records makes them true again, so editing them would replace a measured
# observation with an authored one for no gain.  The adjudication record is regenerated separately by
# compare-frontend-artifacts.sh, which computes it from the records this script writes.
#
# usage:  restore-frontend-artifact-records.sh --side <baseline|migrated> --authority <file> [options]
#
#   --side <name>        the capture side to write; also the default capture directory name
#   --authority <file>   the measured digest record to read, as described above
#   --capture <dir>      the capture directory to write into  (default: <this dir>/<side>)
#   --runtime <text>     the runtime the authority was measured on, recorded verbatim
#   --verify-only        validate the records already on disk and write nothing
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
FE_REL='acm-standard-applications/arkcase/src/main/webapp/resources'

SIDE=''
AUTHORITY=''
CAPTURE=''
RUNTIME=''
VERIFY_ONLY='no'

while [ $# -gt 0 ]; do
    case "$1" in
        --side) SIDE="${2:-}"; shift 2 ;;
        --authority) AUTHORITY="${2:-}"; shift 2 ;;
        --capture) CAPTURE="${2:-}"; shift 2 ;;
        --runtime) RUNTIME="${2:-}"; shift 2 ;;
        --verify-only) VERIFY_ONLY='yes'; shift ;;
        -h|--help) sed -n '1,52p' "$0"; exit 0 ;;
        *) printf 'restore-frontend-artifact-records.sh: unknown option %s\n' "$1" >&2; exit 2 ;;
    esac
done

case "$SIDE" in
    baseline|migrated) ;;
    *) printf 'restore-frontend-artifact-records.sh: --side must be baseline or migrated\n' >&2; exit 2 ;;
esac

[ -n "$CAPTURE" ] || CAPTURE="${HERE}/${SIDE}"
[ -d "$CAPTURE" ] || { printf 'restore-frontend-artifact-records.sh: no capture directory %s\n' "$CAPTURE" >&2; exit 2; }

# The five artifacts the byte-identity criterion ranges over, in the order the adjudication record
# reports them, and the one advisory artifact outside that set.
#
# The source map is NOT one of the compared five and is not counted in the verdict: it embeds file
# paths, so the two sides must build from the same relative path for it to be comparable at all.
# That scoping split is the one the scope note and the gate note already state and it is reproduced
# here rather than reopened.
#
# It does nevertheless get a per-side RECORD, and the reason is worth stating because an earlier
# revision of this program deliberately withheld one.  The adjudication record reports the map so
# that the scoping decision "can be checked rather than trusted" -- its own words -- and it reads the
# per-side record file to do it.  With no record it printed RECORD-ABSENT on both sides, so the one
# thing that paragraph exists to let a reader check was the one thing they could not.  Excluding an
# artifact from a comparison is a scoping decision; refusing to record its measured digest is an
# evidence gap wearing that decision's clothes.  Both sides carried this record before the
# consolidation run overwrote it, the digest is measured and four-way corroborated, so it is
# restored with the other five and marked advisory in the note instead of being omitted.
COMPARED='application.js application.min.js vendors.min.js application.min.css home.html'
ADVISORY='application.min.js.map'
ALL_RECORDS="${COMPARED} ${ADVISORY}"

digest_of()
{
    if command -v sha256sum > /dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    else
        shasum -a 256 -- "$1" | awk '{print $1}'
    fi
}

# well_formed — a record's digest field must be exactly 64 lower-case hexadecimal characters.  Any
# other value, including every token the capture producer writes for a condition it could not
# measure, is refused here rather than carried forward as if it were a measurement.
well_formed()
{
    case "$1" in
        *[!0-9a-f]* | '') return 1 ;;
        *) [ "${#1}" -eq 64 ] ;;
    esac
}

# authority_digest — the digest the authority records for one artifact key, matched on the BASE NAME
# so that a record written as "assets/dist/application.min.js" and one written as
# "application.min.js" resolve to the same key.  Prints nothing when the key is absent.
authority_digest()
{
    local key="$1"
    awk -v key="$key" '
        {
            for (i = 1; i <= NF; i++)
            {
                if ($i ~ /^[0-9a-f]{64}$/)
                {
                    hash = $i
                    label = $(i + 1)
                    sub(/^.*\//, "", label)
                    if (label == key)
                    {
                        print hash
                        exit
                    }
                }
            }
        }
    ' "$AUTHORITY"
}

RECORD_DIR="${CAPTURE}/artifacts"
NOTE_DIR="${CAPTURE}/notes"

# ---------------------------------------------------------------------------
# READ-BACK VALIDATION.  Used by both modes, so --verify-only exercises the identical check the
# write path finishes with rather than a second implementation of it.
# ---------------------------------------------------------------------------
validate_records()
{
    local checked=0 ok=0 bad=0 absent=0 key file line hash label
    VALIDATION_DETAIL=''

    for key in $ALL_RECORDS; do
        file="${RECORD_DIR}/${key}.sha256"
        checked=$((checked + 1))

        if [ ! -f "$file" ]; then
            bad=$((bad + 1))
            VALIDATION_DETAIL="${VALIDATION_DETAIL}  MISSING    artifacts/${key}.sha256  no record file
"
            continue
        fi

        if [ "$(wc -l < "$file" | tr -d '[:space:]')" != '1' ]; then
            bad=$((bad + 1))
            VALIDATION_DETAIL="${VALIDATION_DETAIL}  MALFORMED  artifacts/${key}.sha256  a record is exactly one line
"
            continue
        fi

        line="$(head -n 1 "$file")"
        hash="$(printf '%s' "$line" | awk '{print $1}')"
        label="$(printf '%s' "$line" | awk '{print $2}')"

        if [ "$hash" = 'ABSENT' ] || [ "$hash" = 'DIGEST-FAILED' ] || [ "$hash" = 'DIGEST-TOOL-UNAVAILABLE' ]; then
            absent=$((absent + 1))
            VALIDATION_DETAIL="${VALIDATION_DETAIL}  ABSENT     artifacts/${key}.sha256  ${hash}
"
        elif ! well_formed "$hash"; then
            bad=$((bad + 1))
            VALIDATION_DETAIL="${VALIDATION_DETAIL}  MALFORMED  artifacts/${key}.sha256  ${hash}
"
        elif [ "$label" != "$key" ]; then
            bad=$((bad + 1))
            VALIDATION_DETAIL="${VALIDATION_DETAIL}  MISLABELLED artifacts/${key}.sha256  labelled ${label}
"
        else
            ok=$((ok + 1))
            VALIDATION_DETAIL="${VALIDATION_DETAIL}  OK         artifacts/${key}.sha256  ${hash}
"
        fi
    done

    VALIDATION_CHECKED="$checked"
    VALIDATION_OK="$ok"
    VALIDATION_BAD="$bad"
    VALIDATION_ABSENT="$absent"
}

if [ "$VERIFY_ONLY" = 'yes' ]; then
    validate_records
    printf 'side: %s\ncapture: %s\nrecords-checked: %s\nrecords-wellformed: %s\nrecords-absent: %s\nrecords-malformed: %s\n' \
        "$SIDE" "$CAPTURE" "$VALIDATION_CHECKED" "$VALIDATION_OK" "$VALIDATION_ABSENT" "$VALIDATION_BAD"
    printf '%s' "$VALIDATION_DETAIL"
    if [ "$VALIDATION_ABSENT" -ne 0 ] || [ "$VALIDATION_BAD" -ne 0 ]; then
        printf 'VERDICT: FAILED CLOSED — %s absent and %s malformed record(s)\n' "$VALIDATION_ABSENT" "$VALIDATION_BAD"
        exit 3
    fi
    printf 'VERDICT: PASSED — every record carries a well-formed, correctly labelled digest\n'
    exit 0
fi

[ -n "$AUTHORITY" ] || { printf 'restore-frontend-artifact-records.sh: --authority is required when writing\n' >&2; exit 2; }
[ -f "$AUTHORITY" ] || { printf 'restore-frontend-artifact-records.sh: no authority file %s\n' "$AUTHORITY" >&2; exit 2; }

# ---------------------------------------------------------------------------
# FAIL CLOSED BEFORE WRITING ANYTHING.  Every required digest is resolved first, and the run stops
# on the first one the authority cannot supply.  Resolving up front rather than as each record is
# written is what makes the outcome all-or-nothing: a half-written record set is a capture that
# looks measured on some rows and not on others, which is the condition this program exists to end.
# ---------------------------------------------------------------------------
RESOLVED=''
for key in $ALL_RECORDS; do
    hash="$(authority_digest "$key")"
    if ! well_formed "${hash:-}"; then
        printf 'restore-frontend-artifact-records.sh: %s carries no well-formed digest for %s\n' \
            "$AUTHORITY" "$key" >&2
        printf '  Nothing was written.  Take the measurement rather than recording its absence:\n' >&2
        printf '    capture-frontend-artifacts.sh                       (migrated side)\n' >&2
        printf '    historical-frontend/capture-historical-frontend.sh  (pre-migration side)\n' >&2
        exit 3
    fi
    RESOLVED="${RESOLVED}${key} ${hash}
"
done

resolved_digest()
{
    printf '%s' "$RESOLVED" | awk -v key="$1" '$1 == key { print $2; exit }'
}

mkdir -p "$RECORD_DIR" "$NOTE_DIR" || exit 2

for key in $ALL_RECORDS; do
    printf '%s  %s\n' "$(resolved_digest "$key")" "$key" > "${RECORD_DIR}/${key}.sha256" || exit 2
done

validate_records
if [ "$VALIDATION_OK" -ne "$VALIDATION_CHECKED" ]; then
    printf 'restore-frontend-artifact-records.sh: read-back validation failed after writing.\n' >&2
    printf '%s' "$VALIDATION_DETAIL" >&2
    exit 3
fi

AUTHORITY_SHA="$(digest_of "$AUTHORITY")"
AUTHORITY_REL="${AUTHORITY#"${HERE}"/}"
WRITTEN_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ---------------------------------------------------------------------------
# notes/artifact-digest-records.txt — the per-record outcome the gate note points at.
# ---------------------------------------------------------------------------
{
    printf 'digest record schema validation\n\n'
    printf 'records-checked: %s\n' "$VALIDATION_CHECKED"
    printf 'records-wellformed: %s\n' "$VALIDATION_OK"
    printf 'records-absent-but-wellformed: %s\n' "$VALIDATION_ABSENT"
    printf 'records-malformed: %s\n\n' "$VALIDATION_BAD"
    printf 'produced-by: docs/migration/smoke-evidence/restore-frontend-artifact-records.sh\n'
    printf 'written-at: %s\n' "$WRITTEN_AT"
    printf 'authority: %s\n' "$AUTHORITY_REL"
    printf 'authority-sha256: %s\n' "$AUTHORITY_SHA"
    [ -n "$RUNTIME" ] && printf 'authority-measured-on: %s\n' "$RUNTIME"
    printf '\n'
    printf 'required schema, one line per file, two spaces between the fields:\n'
    printf '  <64 lower-case hex>  followed by the artifact KEY, which is the record\n'
    printf '  file name with ".sha256" removed.  No path, no third field, no second line.\n'
    printf '  This program cannot write any other value: a digest it cannot resolve stops\n'
    printf '  the run with a non-zero status and leaves every record untouched.\n\n'
    printf 'per-record outcome, read back off disk after writing:\n'
    printf '%s' "$VALIDATION_DETAIL"
    printf '\nthe advisory source map is RECORDED like the other five but is NOT one of the\n'
    printf '  compared five and is not counted in the verdict, because it embeds file paths and\n'
    printf '  is only comparable when both sides build from the same relative path.  It is\n'
    printf '  recorded so that the adjudication record can print its measured digest, which is\n'
    printf '  what lets a reader CHECK that scoping decision instead of taking it on trust:\n'
    printf '  %s  %s\n' "$(resolved_digest "$ADVISORY")" "$ADVISORY"
    printf '\nwhy the schema is validated on READ-BACK rather than trusted at the point of\n'
    printf '  writing.  Records committed by an earlier revision of this deliverable carried\n'
    printf '  a path-qualified label that no producer could emit, which proved they had been\n'
    printf '  edited after capture, and nothing in the reader looked at the label at all.\n'
    printf '  Two captures whose records label the same artefact differently cannot be\n'
    printf '  compared by key.  The label is now asserted, so an edited record is a\n'
    printf '  detected condition instead of an invisible one.\n'
    printf '\na malformed record is NOT the same as an absent one: absence means the artefact\n'
    printf '  was not built and the remedy is to build it, whereas malformation means the\n'
    printf '  record cannot be trusted and the remedy is to re-capture it.  This program\n'
    printf '  refuses both.\n'
} > "${NOTE_DIR}/artifact-digest-records.txt" || exit 2

# ---------------------------------------------------------------------------
# notes/determinism-basis.txt — why a byte comparison is a valid comparison at all, measured from
# the frozen pipeline configuration rather than recited from it.
# ---------------------------------------------------------------------------
REPO="$(cd "$HERE" && git rev-parse --show-toplevel 2>/dev/null)" || REPO=''
GRUNTFILE="${REPO:+${REPO}/}${FE_REL}/Gruntfile.js"
ALLJS="${REPO:+${REPO}/}${FE_REL}/config/env/all.js"

anchor()
{
    if [ -f "$2" ]; then
        grep -n -- "$1" "$2" 2>/dev/null | head -n 1 | cut -d: -f1
    fi
}

GRUNT_NGANNOTATE="$(anchor 'ngAnnotate :' "$GRUNTFILE")"
GRUNT_UGLIFY="$(anchor 'uglify :' "$GRUNTFILE")"
GRUNT_CONCAT="$(anchor 'concat :' "$GRUNTFILE")"
GRUNT_CSSMIN="$(anchor 'cssmin :' "$GRUNTFILE")"
GRUNT_CACHEBUST="$(anchor 'cacheBust:' "$GRUNTFILE")"
GRUNT_MANGLE="$(anchor 'mangle : false' "$GRUNTFILE")"
GRUNT_SOURCEMAP="$(anchor 'sourceMap : true' "$GRUNTFILE")"
GRUNT_CLEAN="$(anchor "clean: \[ 'assets/dist' \]" "$GRUNTFILE")"
GRUNT_FORCE="$(anchor "grunt.option('force', true)" "$GRUNTFILE")"
GRUNT_DEFAULT="$(anchor "registerTask('default'" "$GRUNTFILE")"
ALLJS_HOME="$(anchor 'home.html' "$ALLJS")"

{
    printf 'why the five frontend artifact digests are a valid behavioural comparison\n\n'
    printf 'produced-by: docs/migration/smoke-evidence/restore-frontend-artifact-records.sh\n'
    printf 'written-at: %s\n' "$WRITTEN_AT"
    printf 'measured-from: %s and %s in the working tree at the moment of writing.  Every\n' \
        "${FE_REL}/Gruntfile.js" 'config/env/all.js'
    printf '  line number below was located by searching those files, not transcribed, so a\n'
    printf '  reader who finds a different line has found a changed pipeline rather than a\n'
    printf '  stale note.  Both files are frozen contract files in this change set.\n\n'
    printf 'compared artifacts, each traced to the Grunt target that produces it:\n'
    printf '  application.js       ngAnnotate target,        Gruntfile.js:%s\n' "${GRUNT_NGANNOTATE:-not-found}"
    printf '  application.min.js   uglify target,            Gruntfile.js:%s\n' "${GRUNT_UGLIFY:-not-found}"
    printf '  vendors.min.js       concat target,            Gruntfile.js:%s\n' "${GRUNT_CONCAT:-not-found}"
    printf '  application.min.css  cssmin target,            Gruntfile.js:%s\n' "${GRUNT_CSSMIN:-not-found}"
    printf '  home.html            renderHome (config/env/all.js:%s) then rewritten in\n' "${ALLJS_HOME:-not-found}"
    printf '                       place by cacheBust,       Gruntfile.js:%s\n\n' "${GRUNT_CACHEBUST:-not-found}"
    printf 'determinism basis:\n'
    printf '  cache busting is content-hash based (Gruntfile.js:%s) with no timestamp,\n' "${GRUNT_CACHEBUST:-not-found}"
    printf '    banner or date injection\n'
    printf '  minification runs with identifier mangling disabled (Gruntfile.js:%s)\n' "${GRUNT_MANGLE:-not-found}"
    printf '  the dist directory is wiped first (Gruntfile.js:%s), so a stale artefact\n' "${GRUNT_CLEAN:-not-found}"
    printf '    cannot masquerade as a match\n'
    printf '  the task graph is unchanged (Gruntfile.js:%s), so both runs produce the same\n' "${GRUNT_DEFAULT:-not-found}"
    printf '    five artifact names by construction\n\n'
    printf 'honest caveat: source-map generation is enabled (Gruntfile.js:%s) and a source\n' "${GRUNT_SOURCEMAP:-not-found}"
    printf '  map embeds file paths, so the comparison build must run from the same relative\n'
    printf '  path.  If it cannot, application.min.js.map differs while the JavaScript\n'
    printf '  bundles do not; the map is then excluded from the byte comparison and the five\n'
    printf '  artifacts above remain in scope.  The map is digested anyway, and its value is\n'
    printf '  carried in the adjudication record, so the caveat can be checked rather than\n'
    printf '  trusted.\n\n'
    printf 'why this comparison carries so much weight: the frontend tree contains no spec\n'
    printf '  files at all, so there is no automated behavioural test to fall back on.  These\n'
    printf '  digests are the strongest available evidence, which is also why exit codes of\n'
    printf '  the BUILD cannot be relied on: the build is configured to force its way past\n'
    printf '  task failures (Gruntfile.js:%s), so a broken build can exit zero.\n\n' "${GRUNT_FORCE:-not-found}"
    printf 'and why an ABSENT digest is a failure rather than a row.  The four dist artifacts\n'
    printf '  and home.html are build outputs and are not tracked in version control, so a\n'
    printf '  capture taken without a completed frontend build has nothing to digest.  Two\n'
    printf '  such captures compare byte-identical and the comparison then reports the\n'
    printf '  frontend unchanged when it was never built.  Identical absence is not identity\n'
    printf '  of behaviour.  The program that wrote these records cannot record ABSENT at\n'
    printf '  all: it resolves every required digest before writing anything and stops with a\n'
    printf '  non-zero status if one is missing.  Re-check at any time with\n'
    printf '    restore-frontend-artifact-records.sh --side %s --verify-only\n' "$SIDE"
} > "${NOTE_DIR}/determinism-basis.txt" || exit 2

printf 'side: %s\n' "$SIDE"
printf 'capture: %s\n' "$CAPTURE"
printf 'authority: %s (sha256 %s)\n' "$AUTHORITY_REL" "$AUTHORITY_SHA"
printf 'records written and re-validated: %s of %s\n' "$VALIDATION_OK" "$VALIDATION_CHECKED"
printf '%s' "$VALIDATION_DETAIL"
printf 'advisory (recorded, outside the compared five): %s  %s\n' "$(resolved_digest "$ADVISORY")" "$ADVISORY"
printf 'notes written: notes/artifact-digest-records.txt, notes/determinism-basis.txt\n'
exit 0
