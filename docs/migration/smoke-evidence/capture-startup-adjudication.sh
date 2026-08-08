#!/bin/bash
# capture-startup-adjudication.sh — adjudicate the deployment-and-startup gate from the
# startup regions the two captures hold, and write the two derived records of that gate:
#
#   <side>/startup/error-scan.txt   the error census over that side's regions, plus the
#                                   disposition of every distinct error-severity shape
#   <side>/startup/startup.status   the region manifest and the computed gate outcome
#
# WHY THIS IS A PROGRAM AND NOT TWO WRITTEN-UP CONCLUSIONS.  Both files it produces used
# to be authored by hand, and they were the last two files in this evidence tree that
# were.  That is the defect this program exists to remove, and it is the same defect the
# capture producer removed for its own gate note and the frontend adjudicator removed for
# the byte-identity verdict: a record whose counts, censuses and verdict are typed by a
# person can only say what that person believed at the time, and it goes stale silently
# the moment a capture changes underneath it.  Worse here than elsewhere, because
# publication replaces a capture directory WHOLESALE — so an authored file inside one is
# not merely stale-prone, it is deleted by the next capture with nothing to notice.
#
# Every figure below is read out of a region file at the moment of writing, and the gate
# outcome is COMPUTED from those figures rather than asserted alongside them.
#
# WHY IT IS A SIBLING OF THE CAPTURE PRODUCER RATHER THAN PART OF IT.  smoke-checks.sh
# captures ONE side.  The central question of this gate — is any error shape attributable
# to the migration — is a statement about the PAIR, answerable only with both sides on
# disk, exactly as the frontend byte-identity verdict is.  So this follows that
# established pattern, including its consequence: the producer must CARRY these two files
# forward or the next publication deletes them, and both are named in its manifest so a
# failed carry marks the capture incomplete instead of passing quietly.
#
# WHAT IT DOES NOT DO.  It does not decide what the gate should be and cannot pass a gate
# the evidence fails.  It does not author a disposition: a disposition is a claim about
# WHY an error occurs, which no program can derive from a log line, so each one is read
# from a committed ledger that cites its own evidence, and a shape with no ledger entry
# fails the gate rather than being described as unexplained.  The distinction matters:
# "unexplained" is a word an authored file can contain indefinitely; an undisposed shape
# here is a non-zero exit status.
#
# usage:  capture-startup-adjudication.sh [options]
#
#   --baseline <dir>      the pre-migration capture directory   (default: baseline)
#   --migrated <dir>      the post-migration capture directory  (default: migrated)
#   --dispositions <file> the committed disposition ledger
#                         (default: startup-error-dispositions.txt)
#   --war <file>          the packaged application to check for the three newly created
#                         frontend files.  Absence is recorded as unavailable, never as a
#                         failure: a build output does not survive the next clean build,
#                         and this record must stay re-derivable after it is gone
#   --allow-dirty         record a dirty worktree instead of refusing to write
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="${HERE}/baseline"
MIG_DIR="${HERE}/migrated"
LEDGER="${HERE}/startup-error-dispositions.txt"
WAR_PATH="${HERE}/../../../acm-standard-applications/arkcase/target/arkcase-2021.03.war"
ALLOW_DIRTY='no'

while [ $# -gt 0 ]; do
    case "$1" in
        --baseline) BASE_DIR="${2:-}"; shift 2 ;;
        --migrated) MIG_DIR="${2:-}"; shift 2 ;;
        --dispositions) LEDGER="${2:-}"; shift 2 ;;
        --war) WAR_PATH="${2:-}"; shift 2 ;;
        --allow-dirty) ALLOW_DIRTY='yes'; shift ;;
        -h|--help) sed -n '1,48p' "$0"; exit 0 ;;
        *) printf 'capture-startup-adjudication.sh: unknown option %s\n' "$1" >&2; exit 2 ;;
    esac
done

# The region set, in the order the manifest lists them.  MANDATORY is the producer's own
# classification and is re-read from each file rather than restated here.
REGIONS='catalina.out.log spring-context.log jpa-init.log reflection-scan.log
workflow-engine-init.log ldap-context-source.log messaging-init.log frontend-build.log
readiness-poll.log errors.log'

SIG_PATTERN='ERROR|SEVERE|Exception|Caused by|NoClassDefFoundError|IllegalAccessError|NoSuchMethodError'
SEV_PATTERN='\[ERROR\]|\[SEVERE\]|^SEVERE:|[[:space:]]SEVERE[[:space:]]'

for d in "$BASE_DIR" "$MIG_DIR"; do
    if [ ! -d "${d}/startup" ]; then
        printf 'capture-startup-adjudication.sh: %s/startup does not exist\n' "$d" >&2
        exit 2
    fi
done
if [ ! -f "$LEDGER" ]; then
    printf 'capture-startup-adjudication.sh: the disposition ledger is missing: %s\n' "$LEDGER" >&2
    printf '  Refused rather than writing a scan with every shape undisposed.\n' >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# CAPTURE IDENTITY, MEASURED.  A gate record that cannot say which commit it describes is
# the defect that made an earlier evidence set unusable, so the identity is resolved here
# rather than written down, and a dirty worktree stops the write by default.
# ---------------------------------------------------------------------------
REPO="$(cd "$HERE" && git rev-parse --show-toplevel 2>/dev/null)" || REPO=''
if [ -z "$REPO" ]; then
    printf 'capture-startup-adjudication.sh: not inside a git checkout, so no capture identity can be resolved.\n' >&2
    exit 2
fi
COMMIT="$(git -C "$REPO" rev-parse --verify HEAD 2>/dev/null)" || COMMIT=''
BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)" || BRANCH=''
PORCELAIN="$(git -C "$REPO" status --porcelain 2>/dev/null)"
DIRTY_COUNT="$(printf '%s' "$PORCELAIN" | grep -c . || true)"
if [ -z "$COMMIT" ] || [ ${#COMMIT} -ne 40 ]; then
    printf 'capture-startup-adjudication.sh: HEAD did not resolve to a 40-character commit.\n' >&2
    exit 2
fi
if [ "$DIRTY_COUNT" -gt 0 ] && [ "$ALLOW_DIRTY" != 'yes' ]; then
    printf 'capture-startup-adjudication.sh: the worktree has %s modified path(s).\n' "$DIRTY_COUNT" >&2
    printf '  Refusing to write a gate record that would name commit %s\n' "$COMMIT" >&2
    printf '  while the files it describes are not in it.  Commit first, or pass\n' >&2
    printf '  --allow-dirty to have the dirty state recorded in the record itself.\n' >&2
    printf '%s\n' "$PORCELAIN" | sed 's/^/    /' >&2
    exit 3
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/arkcase-startup-adj.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT INT TERM
WROTE_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ---------------------------------------------------------------------------
# THE COMPARISON NORMALISER, DEFINED ONCE AND PUBLISHED VERBATIM.
#
# Two error lines describe the same behaviour when they differ only in scheduling and
# identity detail: which pool thread ran the work, which ordinal a worker carried, which
# identifier a broker or a route assigned, which line of a source file a frame pointed at.
# A comparison that treated those as behaviour would report a shape as present on one side
# only because a thread pool handed the work to worker 3 rather than worker 1 — which is
# exactly what a first attempt at this comparison did, on two shapes, in both directions.
#
# So the comparison key strips them, and the rule is PUBLISHED in both records it writes
# so that a reader can re-derive the key rather than trust it.  What it does NOT strip is
# the whole behaviour-bearing content: the severity marker, the logger name, the exception
# type, the message text, the result code, and the object or path the message names.
#
# NORMALISER-RULES is the human statement; norm_stream is the executable one.  They are
# kept adjacent deliberately: a rule stated but not applied, or applied but not stated,
# is the failure mode this pairing exists to prevent.
# ---------------------------------------------------------------------------
norm_stream()
{
    sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' \
        -e 's/^[0-9][0-9]*-[A-Za-z][A-Za-z][A-Za-z]-[0-9][0-9]* [0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9]*/<TIMESTAMP>/' \
        -e 's/^[0-9][0-9]*-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9],[0-9]*/<TIMESTAMP>/' \
        -e 's/<TIMESTAMP>,[0-9][0-9]*/<TIMESTAMP>/g' \
        -e 's/[0-9][0-9]*-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9][.,0-9]*Z*/<TIMESTAMP>/g' \
        -e 's/^[[:space:]][[:space:]]*//' \
        -e 's/ ~\[[^]]*\]//g' \
        -e 's/thread #[0-9][0-9]*/thread #<N>/g' \
        -e 's/(camel-[0-9][0-9]*)/(camel-<N>)/g' \
        -e 's/_Worker-[0-9][0-9]*/_Worker-<N>/g' \
        -e 's/channelExecutor-[0-9][0-9]*/channelExecutor-<N>/g' \
        -e 's/task-scheduler-[0-9][0-9]*/task-scheduler-<N>/g' \
        -e 's/auditorExecutor-[0-9][0-9]*/auditorExecutor-<N>/g' \
        -e 's/pool-[0-9][0-9]*-thread-[0-9][0-9]*/pool-<N>-thread-<N>/g' \
        -e 's/Lambda\$[0-9][0-9]*\/0x[0-9a-f]*/Lambda$<N>\/0x<ADDR>/g' \
        -e 's/[Ee]xchange[Ii]d: [0-9A-Fa-f][0-9A-Fa-f-]*/exchangeId: <ID>/g' \
        -e 's/[Mm]essage[Ii]d: [0-9A-Fa-f][0-9A-Fa-f-]*/messageId: <ID>/g' \
        -e 's/Exchange\[[0-9A-Fa-f][0-9A-Fa-f-]*\]/Exchange[<ID>]/g' \
        -e 's/id=[0-9a-f][0-9a-f-]*/id=<UUID>/g' \
        -e 's/[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}/<UUID>/g' \
        -e 's/timestamp=[0-9]\{10,\}/timestamp=<EPOCH-MS>/g' \
        -e 's/@[0-9a-f][0-9a-f]*/@<HASH>/g' \
        -e 's/([0-9]\{6,\})/(<SESSION>)/g' \
        -e 's/\.java:[0-9][0-9]*)/.java)/g' \
        -e 's/\[[0-9][0-9,]*\] milliseconds/[<MS>] milliseconds/g' \
        -e 's/in \[[0-9][0-9,]*\] ms/in [<MS>] ms/g' \
        -e "s|${REPO}[^ )\"']*|<PATH>|g" \
        -e 's|/tmp/[^ )"'"'"']*|<PATH>|g'
}

# The severity classes are exempted from the 200-character cap deliberately: the exception
# type and the message text of an error ARE the behaviour-bearing content of this record,
# and capping them would truncate the very text a disposition is matched against.
cap_stream()
{
    awk '
        /\[ERROR\]|\[SEVERE\]|^SEVERE:/ { print; next }
        length($0) > 200 { print substr($0, 1, 200) " <TRUNCATED-AT-200>"; next }
        { print }
    '
}

# region_body <dir> <name> — the lines between the two region delimiters, and nothing else.
region_body()
{
    sed -n '/^----- region -----$/,/^----- end region -----$/p' "${1}/startup/${2}" 2>/dev/null \
        | sed -e '1d' -e '$d'
}

# region_field <dir> <name> <key> — the value of a header field, or a token.
region_field()
{
    local v
    v="$(awk -v k="${3}: " 'index($0, k) == 1 { sub(/^[^:]*: /, ""); print; exit }' \
        "${1}/startup/${2}" 2>/dev/null)"
    [ -n "$v" ] && printf '%s' "$v" || printf 'FIELD-ABSENT'
}

# count_matches — a match count that is always ONE integer on ONE line.
#
# grep -c already prints 0 when it matches nothing and merely EXITS non-zero, so the
# obvious-looking "grep -c ... || printf 0" appends a second zero and yields the
# two-line value "0\n0".  Every integer test that value reached then failed with a
# syntax error rather than comparing anything — silently, in a subshell, inside a
# gate row.  Routing every count through here removes the whole class.
count_matches()
{
    local n
    n="$(grep -c "$@" 2>/dev/null)" || true
    n="$(printf '%s' "$n" | tr -d '[:space:]')"
    case "$n" in
        ''|*[!0-9]*) printf '0' ;;
        *) printf '%s' "$n" ;;
    esac
}

# ---------------------------------------------------------------------------
# PASS 1 — READ EACH SIDE, VERIFY EVERY REGION AGAINST ITS OWN HEADER, AND BUILD THE
# CENSUS FILES.  The verification is not ceremonial: the header's matched-lines is the
# figure every downstream count is stated against, and a file whose body no longer
# contains that many lines has been edited after it was produced.  That is precisely the
# defect the review found in the test-report archive, so it is checked here by counting
# rather than trusted.
# ---------------------------------------------------------------------------
INTEGRITY_FAULTS=0
: > "${TMP}/integrity"

read_side()
{
    local side="$1" dir="$2" r declared derived body mand
    : > "${TMP}/${side}.regions"
    : > "${TMP}/${side}.sig"
    : > "${TMP}/${side}.sev"

    for r in $REGIONS; do
        if [ ! -f "${dir}/startup/${r}" ]; then
            printf '%s: region file absent: startup/%s\n' "$side" "$r" >> "${TMP}/integrity"
            INTEGRITY_FAULTS=$((INTEGRITY_FAULTS + 1))
            printf '%s\t%s\t%s\t%s\t%s\n' "$r" 'ABSENT' 'ABSENT' 'ABSENT' 'ABSENT' \
                >> "${TMP}/${side}.regions"
            continue
        fi
        body="${TMP}/${side}.${r}.body"
        region_body "$dir" "$r" > "$body"
        derived="$(wc -l < "$body" | tr -d '[:space:]')"
        declared="$(region_field "$dir" "$r" 'matched-lines')"
        mand="$(region_field "$dir" "$r" 'region-mandatory')"

        if [ "$declared" != "$derived" ]; then
            printf '%s: startup/%s declares matched-lines %s but its body holds %s line(s)\n' \
                "$side" "$r" "$declared" "$derived" >> "${TMP}/integrity"
            INTEGRITY_FAULTS=$((INTEGRITY_FAULTS + 1))
        fi
        if [ "$mand" = 'yes' ] && [ "$derived" -eq 0 ]; then
            printf '%s: startup/%s is mandatory and its body is empty\n' \
                "$side" "$r" >> "${TMP}/integrity"
            INTEGRITY_FAULTS=$((INTEGRITY_FAULTS + 1))
        fi

        printf '%s\t%s\t%s\t%s\t%s\n' "$r" "$mand" "$declared" "$derived" \
            "$(count_matches -E -i -e "$SIG_PATTERN" "$body")" \
            >> "${TMP}/${side}.regions"
    done

    # The census is taken over catalina.out.log ALONE, and that is a deliberate narrowing
    # to a SUPERSET rather than a widening to a union.  That region is the extracted boot
    # window verbatim; every other region is mined out of the same window, so no line
    # reachable through a mined region is unreachable here, while scanning all ten would
    # count a line once per region that happened to match it.
    if [ -f "${TMP}/${side}.catalina.out.log.body" ]; then
        grep -E -i -e "$SIG_PATTERN" "${TMP}/${side}.catalina.out.log.body" 2>/dev/null \
            | norm_stream | cap_stream > "${TMP}/${side}.sig" || true
        grep -E -e "$SEV_PATTERN" "${TMP}/${side}.catalina.out.log.body" 2>/dev/null \
            | norm_stream | cap_stream > "${TMP}/${side}.sev" || true
    fi
    LC_ALL=C sort "${TMP}/${side}.sig" | uniq -c | sed 's/^ *//' \
        | LC_ALL=C sort -k1,1nr -k2 > "${TMP}/${side}.sig.census"
    LC_ALL=C sort -u "${TMP}/${side}.sev" > "${TMP}/${side}.sev.keys"
    LC_ALL=C sort "${TMP}/${side}.sev" | uniq -c | sed 's/^ *//' \
        | LC_ALL=C sort -k1,1nr -k2 > "${TMP}/${side}.sev.census"
    LC_ALL=C sort -u "${TMP}/${side}.sig" > "${TMP}/${side}.sig.keys"
}

read_side base "$BASE_DIR"
read_side mig "$MIG_DIR"

# ---------------------------------------------------------------------------
# PASS 2 — THE PAIR COMPARISON.  A shape present on both sides cannot have been
# introduced by the change set; a shape present only on the pre-migration side was
# REMOVED by it; only a shape present only on the post-migration side can be attributable
# to it, and that is the one condition that fails this gate.
# ---------------------------------------------------------------------------
comm -23 "${TMP}/mig.sev.keys" "${TMP}/base.sev.keys" > "${TMP}/sev.mig-only"
comm -13 "${TMP}/mig.sev.keys" "${TMP}/base.sev.keys" > "${TMP}/sev.base-only"
comm -12 "${TMP}/mig.sev.keys" "${TMP}/base.sev.keys" > "${TMP}/sev.both"
comm -23 "${TMP}/mig.sig.keys" "${TMP}/base.sig.keys" > "${TMP}/sig.mig-only"
comm -13 "${TMP}/mig.sig.keys" "${TMP}/base.sig.keys" > "${TMP}/sig.base-only"

N_SEV_MIG_ONLY="$(wc -l < "${TMP}/sev.mig-only" | tr -d '[:space:]')"
N_SEV_BASE_ONLY="$(wc -l < "${TMP}/sev.base-only" | tr -d '[:space:]')"
N_SEV_BOTH="$(wc -l < "${TMP}/sev.both" | tr -d '[:space:]')"
N_SIG_MIG_ONLY="$(wc -l < "${TMP}/sig.mig-only" | tr -d '[:space:]')"
N_SIG_BASE_ONLY="$(wc -l < "${TMP}/sig.base-only" | tr -d '[:space:]')"

# ---------------------------------------------------------------------------
# PASS 3 — DISPOSITIONS.  The ledger is TAB-separated: match-substring, classification,
# evidence citation.  A shape is disposed by the FIRST ledger row whose match-substring
# occurs in it, so a row is a claim about a family of lines rather than about one line,
# and the row's own evidence citation travels with it into both records.
# ---------------------------------------------------------------------------
# The shape is handed to awk through the ENVIRONMENT, never through -v.  An assignment
# made with -v is escape-processed, and these shapes routinely contain a backslash — the
# route error handler logs a literal "\--> New exception" — so -v would silently rewrite
# the text being matched and the ledger lookup would miss the very family it was written
# for.  ENVIRON is not escape-processed.
dispose()
{
    SHAPE="$1" awk -F'\t' '
        /^[[:space:]]*#/ || NF < 3 { next }
        { if (index(ENVIRON["SHAPE"], $1) > 0) { printf "%s\t%s\t%s", $2, $3, $1; found = 1; exit } }
        END { if (!found) printf "UNDISPOSED\tno ledger row matches this shape\t-" }
    ' "$LEDGER"
}

LC_ALL=C sort -u "${TMP}/mig.sev.keys" "${TMP}/base.sev.keys" > "${TMP}/sev.all"
: > "${TMP}/dispositions"
UNDISPOSED=0
while IFS= read -r shape; do
    [ -n "$shape" ] || continue
    d="$(dispose "$shape")"
    cls="${d%%	*}"
    rest="${d#*	}"
    ev="${rest%%	*}"
    key="${rest#*	}"
    on_mig='no'; on_base='no'
    grep -qxF -- "$shape" "${TMP}/mig.sev.keys" && on_mig='yes'
    grep -qxF -- "$shape" "${TMP}/base.sev.keys" && on_base='yes'
    case "$cls" in UNDISPOSED) UNDISPOSED=$((UNDISPOSED + 1)) ;; esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$on_mig" "$on_base" "$cls" "$ev" "$key" "$shape" \
        >> "${TMP}/dispositions"
done < "${TMP}/sev.all"
N_SHAPES_ALL="$(wc -l < "${TMP}/sev.all" | tr -d '[:space:]')"

# ---------------------------------------------------------------------------
# PASS 4 — THE PROCESS-DEFINITION OBSERVATION, WHICH THE REVIEW FOUND UNOBSERVED.
#
# Observed from the engine's OWN log rather than declared: the application's deployer
# reports the classpath patterns it scanned, names every resource it found, and the
# engine's own deployer then reports every resource it processed into a definition.  All
# three are inside the archived region, so the figure is re-derivable from the evidence
# by a reader with no database and no running stack.
#
# The reconciliation is mechanical for the same reason: the pattern list is PARSED out of
# the deployer's own line and matched against the repository's tracked main-source
# resources, so the expected set is derived from what the application said it looked for
# rather than from what a person believed it looked for.
# ---------------------------------------------------------------------------
procdef_observe()
{
    local side="$1" body="${TMP}/${1}.workflow-engine-init.log.body"
    if [ ! -f "$body" ]; then printf '0\t0\tREGION-ABSENT'; return; fi
    local found processed patterns
    found="$(count_matches -E -e 'Found resource \[' "$body")"
    processed="$(count_matches -E -e 'BpmnDeployer - Processing resource ' "$body")"
    patterns="$(grep -o -E 'Scanning for resources matching \[[^]]*\]' "$body" 2>/dev/null \
        | head -1 | sed -e 's/^Scanning for resources matching \[//' -e 's/\]$//')"
    [ -n "$patterns" ] || patterns='PATTERN-NOT-LOGGED'
    printf '%s\t%s\t%s' "$found" "$processed" "$patterns"
}

MIG_PD="$(procdef_observe mig)";   MIG_FOUND="${MIG_PD%%	*}"; MIG_PD_R="${MIG_PD#*	}"
MIG_PROC="${MIG_PD_R%%	*}";       MIG_PATTERNS="${MIG_PD_R#*	}"
BASE_PD="$(procdef_observe base)"; BASE_FOUND="${BASE_PD%%	*}"; BASE_PD_R="${BASE_PD#*	}"
BASE_PROC="${BASE_PD_R%%	*}";     BASE_PATTERNS="${BASE_PD_R#*	}"

# Enumerate the tracked main-source resources the observed patterns select.  Each pattern
# has the form classpath*:/activiti/<glob>.bpmn20.xml; the glob is matched against the
# BASENAME of every tracked file whose path carries the same resource directory under a
# main source root, because that is exactly the set the classpath scan can see in the WAR.
: > "${TMP}/expected-bpmn"
EXPECTED_BASIS='not-derived'
if [ "$MIG_PATTERNS" != 'PATTERN-NOT-LOGGED' ]; then
    EXPECTED_BASIS="parsed from the deployer's own logged pattern list"
    git -C "$REPO" ls-files > "${TMP}/tracked" 2>/dev/null || : > "${TMP}/tracked"
    # printf with a trailing newline, NOT without one: tr would otherwise emit a final
    # line carrying no delimiter, read would return non-zero on it, and the loop body
    # would never run for the LAST pattern.  That is not hypothetical — it silently
    # dropped the fifth of five patterns, the enumeration came back one short of the
    # engine's own total, and the reconciliation row failed.  The gate caught it.
    printf '%s\n' "$MIG_PATTERNS" | tr ',' '\n' | while IFS= read -r pat; do
        rel="${pat#classpath*:}"
        rel="${rel#/}"
        dir="${rel%/*}"
        glob="${rel##*/}"
        [ -n "$glob" ] || continue
        while IFS= read -r f; do
            case "$f" in
                */src/main/resources/"$dir"/*) ;;
                *) continue ;;
            esac
            b="${f##*/}"
            # shellcheck disable=SC2254
            case "$b" in
                $glob) printf '%s\n' "$f" ;;
            esac
        done < "${TMP}/tracked"
    done | LC_ALL=C sort -u > "${TMP}/expected-bpmn"
fi
N_EXPECTED="$(wc -l < "${TMP}/expected-bpmn" | tr -d '[:space:]')"

# ---------------------------------------------------------------------------
# PASS 4b — THE REMAINING PASS CONDITIONS AAP 0.9.4 NAMES BY NAME.
#
# The gate is not only about error shapes.  Its headline condition is that the deployment
# REACHES READY STATE, and it separately names the aspect auto-proxy configuration and the
# three newly created frontend files inside the packaged application.  Each is observed
# here from the archived regions or from the artifact itself, because a gate that declared
# PASS while silently covering only part of what it cites would be the same defect in a
# new place.
#
# The packaged-application check is UNAVAILABLE-tolerant on purpose.  The regions are
# re-derivable from an archived log for as long as the archive exists, whereas a build
# output is not: it is deleted by the next clean build.  Failing the gate because a WAR is
# no longer on disk months later would make this record un-reproducible, so its absence is
# recorded as unavailable and the row is not counted against the gate.
# ---------------------------------------------------------------------------
side_has()
{
    # side_has <side> <region> <extended-regex>  ->  yes | no
    local body="${TMP}/${1}.${2}.body"
    [ -f "$body" ] || { printf 'no'; return; }
    if grep -q -E -e "$3" "$body" 2>/dev/null; then printf 'yes'; else printf 'no'; fi
}
MIG_READY="$(side_has mig readiness-poll.log 'Server startup in')"
BASE_READY="$(side_has base readiness-poll.log 'Server startup in')"
MIG_CTX="$(side_has mig spring-context.log 'Root WebApplicationContext initialized in')"
BASE_CTX="$(side_has base spring-context.log 'Root WebApplicationContext initialized in')"

# The three files the change set creates in the frontend tree, which AAP 0.9.4 requires to
# be present inside the packaged application.  Checked against the WAR when one is on disk.
WAR_NEW_FILES='package-lock.json .nvmrc profiles.js'
WAR_STATUS='UNAVAILABLE'
WAR_DETAIL='no packaged application was found on disk, so this was not observed'
if [ -f "$WAR_PATH" ]; then
    WAR_LIST="${TMP}/war-list"
    if python3 - "$WAR_PATH" > "$WAR_LIST" 2>/dev/null <<'PYWAR'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    for n in z.namelist():
        print(n)
PYWAR
    then
        WAR_MISSING=''
        for f in $WAR_NEW_FILES; do
            grep -q -E "(^|/)resources/${f}$" "$WAR_LIST" \
                || WAR_MISSING="${WAR_MISSING} ${f}"
        done
        if [ -z "$WAR_MISSING" ]; then
            WAR_STATUS='PRESENT'
            WAR_DETAIL="all three are inside $(basename "$WAR_PATH"), which holds $(wc -l < "$WAR_LIST" | tr -d '[:space:]') entries"
        else
            WAR_STATUS='MISSING'
            WAR_DETAIL="absent from $(basename "$WAR_PATH"):${WAR_MISSING}"
        fi
    else
        WAR_DETAIL="a packaged application is at ${WAR_PATH} but its entry list could not be read"
    fi
fi

# The aspect surface, counted from the repository rather than asserted.  Spring does not
# log advisor or proxy creation at informational severity, so the OBSERVATION that
# discharges this condition is the context reaching full initialisation: the aspect beans
# and the auto-proxy post-processor are part of that context, and a failure to create an
# advisor or to proxy a target aborts the refresh rather than degrading quietly.  The
# counts below say how large the surface is that initialisation covered.
ASPECT_CLASSES="$(git -C "$REPO" grep -l -E '^[[:space:]]*@Aspect' -- '*/src/main/java/*.java' 2>/dev/null | wc -l | tr -d '[:space:]')"
AUTOPROXY_FILES="$(git -C "$REPO" grep -l -E 'aspectj-autoproxy' -- '*/src/main/resources/*' 2>/dev/null | wc -l | tr -d '[:space:]')"

# ---------------------------------------------------------------------------
# PASS 5 — THE GATE.  Every condition is a measured figure compared to a required one.
# ---------------------------------------------------------------------------
: > "${TMP}/gate"
gate_row()
{
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "${TMP}/gate"
}
MIG_SEV_LINES="$(wc -l < "${TMP}/mig.sev" | tr -d '[:space:]')"
BASE_SEV_LINES="$(wc -l < "${TMP}/base.sev" | tr -d '[:space:]')"
MIG_SEVERE="$(count_matches -E -e '\[SEVERE\]|^SEVERE:' "${TMP}/mig.sev")"
BASE_SEVERE="$(count_matches -E -e '\[SEVERE\]|^SEVERE:' "${TMP}/base.sev")"
MIG_BOOTS="$(region_field "$MIG_DIR" catalina.out.log 'window-boots-present-in-source')"
BASE_BOOTS="$(region_field "$BASE_DIR" catalina.out.log 'window-boots-present-in-source')"
MIG_TRUNC="$(grep -c '^capture-truncated: yes$' "${MIG_DIR}"/startup/*.log 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"
BASE_TRUNC="$(grep -c '^capture-truncated: yes$' "${BASE_DIR}"/startup/*.log 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')"

gate_row 'severity-scan-input-volume' 'reported, not gated' \
    "migrated ${MIG_SEV_LINES} line(s), pre-migration ${BASE_SEV_LINES} line(s)" 'REPORTED'
gate_row 'region-integrity' '0 fault(s)' "${INTEGRITY_FAULTS} fault(s)" \
    "$([ "$INTEGRITY_FAULTS" -eq 0 ] && echo PASS || echo FAIL)"
gate_row 'no-region-truncated' '0 on each side' "migrated ${MIG_TRUNC}, pre-migration ${BASE_TRUNC}" \
    "$([ "${MIG_TRUNC:-0}" -eq 0 ] && [ "${BASE_TRUNC:-0}" -eq 0 ] && echo PASS || echo FAIL)"
gate_row 'exactly-one-boot-in-each-source' '1 on each side' \
    "migrated ${MIG_BOOTS}, pre-migration ${BASE_BOOTS}" \
    "$([ "$MIG_BOOTS" = '1' ] && [ "$BASE_BOOTS" = '1' ] && echo PASS || echo FAIL)"
gate_row 'severe-severity-lines' '0 on each side' \
    "migrated ${MIG_SEVERE}, pre-migration ${BASE_SEVERE}" \
    "$([ "${MIG_SEVERE:-0}" -eq 0 ] && [ "${BASE_SEVERE:-0}" -eq 0 ] && echo PASS || echo FAIL)"
gate_row 'migration-attributable-error-shapes' '0' "${N_SEV_MIG_ONLY}" \
    "$([ "$N_SEV_MIG_ONLY" -eq 0 ] && echo PASS || echo FAIL)"
gate_row 'undisposed-error-shapes' '0' "${UNDISPOSED} of ${N_SHAPES_ALL}" \
    "$([ "$UNDISPOSED" -eq 0 ] && echo PASS || echo FAIL)"
gate_row 'process-definitions-observed' '>0 and equal on both sides' \
    "migrated ${MIG_PROC}, pre-migration ${BASE_PROC}" \
    "$([ "${MIG_PROC:-0}" -gt 0 ] && [ "$MIG_PROC" = "$BASE_PROC" ] && echo PASS || echo FAIL)"
gate_row 'container-reported-startup-complete' 'yes on each side' \
    "migrated ${MIG_READY}, pre-migration ${BASE_READY}" \
    "$([ "$MIG_READY" = 'yes' ] && [ "$BASE_READY" = 'yes' ] && echo PASS || echo FAIL)"
gate_row 'spring-context-initialised' 'yes on each side' \
    "migrated ${MIG_CTX}, pre-migration ${BASE_CTX}" \
    "$([ "$MIG_CTX" = 'yes' ] && [ "$BASE_CTX" = 'yes' ] && echo PASS || echo FAIL)"
gate_row 'war-carries-the-three-new-frontend-files' 'PRESENT, or UNAVAILABLE' \
    "${WAR_STATUS}" \
    "$([ "$WAR_STATUS" = 'MISSING' ] && echo FAIL || echo PASS)"
gate_row 'definitions-reconcile-to-tracked-set' "${N_EXPECTED} (derived)" \
    "migrated ${MIG_PROC} processed, ${MIG_FOUND} found" \
    "$([ "${MIG_PROC:-0}" = "${N_EXPECTED}" ] && [ "${MIG_FOUND:-0}" = "${N_EXPECTED}" ] && echo PASS || echo FAIL)"

GATE_FAILS="$(awk -F'\t' '$4 == "FAIL"' "${TMP}/gate" | wc -l | tr -d '[:space:]')"
if [ "$GATE_FAILS" -eq 0 ]; then GATE='PASS'; else GATE='FAIL'; fi

# ---------------------------------------------------------------------------
# WRITE.  Both sides receive the SAME field names in the SAME order and the same region
# selection, so a recursive diff between the two capture directories reports differences
# in VALUES rather than in structure.  The two fields that legitimately differ are the
# runtime and the side.
# ---------------------------------------------------------------------------
identity_block()
{
    w "written-at: ${WROTE_AT}"
    w "capture-commit: ${COMMIT}"
    w "branch: ${BRANCH}"
    if [ "$DIRTY_COUNT" -gt 0 ]; then
        w "worktree-at-write-time: DIRTY, ${DIRTY_COUNT} path(s); --allow-dirty was passed, so"
        w '  the commit named above does not contain every file this record describes'
        printf '%s\n' "$PORCELAIN" | sed 's/^/    /' >> "$OUT"
    else
        w 'worktree-at-write-time: clean — git status --porcelain produced no output, so the'
        w '  commit named above contains the files this record describes'
    fi
    w 'what-the-commit-field-means: the commit whose CONTENT this record was computed from,'
    w '  which is the commit holding the region files it read.  This record is necessarily'
    w '  written afterwards and therefore lands in a SUCCESSOR commit; a record cannot'
    w '  contain the hash of the commit that contains it.  The clean-worktree assertion'
    w '  above is what makes the field meaningful rather than decorative: it establishes'
    w '  that the regions this record describes were committed, unmodified, at that'
    w '  revision.  Stating a hash without that assertion is what made an earlier'
    w '  evidence set unusable.'
}

write_error_scan()
{
    local side="$1" dir="$2" runtime="$3" label="$4" peer="$5"
    OUT="${dir}/startup/error-scan.txt"
    : > "$OUT" || exit 2

    w 'capture: the error census over this side'"'"'s archived startup regions, and the'
    w '  disposition of every distinct error-severity shape in it'
    w "runtime: ${runtime}"
    w "capture-side: ${label}"
    w 'produced-by: docs/migration/smoke-evidence/capture-startup-adjudication.sh'
    w 'GENERATED-NOT-AUTHORED: every count, census line, comparison and disposition below'
    w '  was read or computed at the moment of writing from the region files in this'
    w '  directory.  Nothing in it is transcribed, and no sentence in it can go stale'
    w '  independently of the evidence it describes.  This file replaced an authored one:'
    w '  the authored version could say a shape was UNEXPLAINED indefinitely, whereas an'
    w '  undisposed shape here is a FAIL row in the gate and a non-zero exit status.'
    identity_block
    w "source: the ten startup regions in ${dir##*/}/startup/"
    w "comparison-side: ${peer}"
    w ''
    w 'SCOPE OF THE CENSUS'
    w '  The census is taken over catalina.out.log alone, which is the extracted boot'
    w '  window VERBATIM.  Every other region in this directory is mined out of that same'
    w '  window, so no line reachable through a mined region is unreachable here — the'
    w '  scope is a superset of the union, not a subset of it.  Scanning all ten would'
    w '  instead count one line once per region that matched it.  Per-region signature'
    w '  counts are published below as a cross-check, and this file does not scan itself.'
    w "  signature-pattern: ${SIG_PATTERN}"
    w "  severity-pattern: ${SEV_PATTERN}"
    w '  pattern-flags: grep -E for the severity pass, grep -E -i for the signature pass'
    w ''
    w 'WINDOW THIS CENSUS DESCRIBES'
    w "  window-source: $(region_field "$dir" catalina.out.log 'window-source')"
    w "  window-source-sha256: $(region_field "$dir" catalina.out.log 'window-source-sha256')"
    w "  window-sha256: $(region_field "$dir" catalina.out.log 'window-sha256')"
    w "  window-lines: $(region_field "$dir" catalina.out.log 'window-lines')"
    w "  boots-present-in-source: $(region_field "$dir" catalina.out.log 'window-boots-present-in-source')"
    w ''
    w 'PER-REGION ACCOUNTING'
    w '  Every region is listed, including the ones whose bodies contain no signature at'
    w '  all, so a region that matched nothing is visibly accounted for rather than'
    w '  missing.  derived-body-lines is COUNTED here between the two region delimiters'
    w '  and compared against the figure the region itself declares; a disagreement means'
    w '  the file was edited after it was produced and is reported as an integrity fault.'
    w ''
    printf '  %-26s %-10s %10s %10s %10s %s\n' 'region' 'mandatory' 'declared' 'derived' \
        'signature' 'agree' >> "$OUT"
    while IFS="$(printf '\t')" read -r r mand declared derived sig; do
        printf '  %-26s %-10s %10s %10s %10s %s\n' "$r" "$mand" "$declared" "$derived" "$sig" \
            "$([ "$declared" = "$derived" ] && echo yes || echo NO)" >> "$OUT"
    done < "${TMP}/${side}.regions"
    w ''
    w "  signature-matching-lines-in-window: $(wc -l < "${TMP}/${side}.sig" | tr -d '[:space:]')"
    w "  distinct-normalised-signature-lines: $(wc -l < "${TMP}/${side}.sig.keys" | tr -d '[:space:]')"
    w "  error-or-severe-severity-lines: $(wc -l < "${TMP}/${side}.sev" | tr -d '[:space:]')"
    w "  distinct-error-severity-shapes: $(wc -l < "${TMP}/${side}.sev.keys" | tr -d '[:space:]')"
    w "  severe-severity-lines: $(count_matches -E -e '\[SEVERE\]|^SEVERE:' "${TMP}/${side}.sev")"
    w ''
    w 'COMPARISON KEY — HOW TWO LINES ARE JUDGED TO DESCRIBE THE SAME BEHAVIOUR'
    w '  Published so a reader can re-derive a key rather than trust one.  Two lines'
    w '  describe the same behaviour when they differ only in scheduling and identity'
    w '  detail, so the key removes: terminal colour sequences; the leading timestamp in'
    w '  either of the two forms this log carries; leading indentation on stack frames;'
    w '  the runtime build tag appended to a frame; pool thread and worker ordinals for'
    w '  every executor in this application; route-assigned exchange and message'
    w '  identifiers; universally-unique identifiers; millisecond epochs; object identity'
    w '  hashes; generated lambda class names and addresses; persistence session'
    w '  identifiers; the line number inside a stack frame; measured durations; and'
    w '  absolute paths, to <PATH>.'
    w '  It removes NOTHING behaviour-bearing: the severity marker, the logger name, the'
    w '  exception type, the whole message text, the result code, and the object or path'
    w '  the message names all survive verbatim.'
    w '  This rule exists because a first attempt without it reported two shapes as'
    w '  present on one side only, in both directions, purely because a thread pool had'
    w '  handed the work to a different worker ordinal.'
    w '  Every line EXCEPT an error- or severe-severity line is capped at 200 characters'
    w '  and marked <TRUNCATED-AT-200>.  The severity classes are exempt deliberately:'
    w '  their message text is what a disposition is matched against.'
    w '  The scan is line-oriented, so a stack trace contributes only those of its own'
    w '  lines that themselves carry a signature — its header, its Caused by lines, and'
    w '  any frame whose class name carries one.  No frame is followed and nothing'
    w '  matched is dropped.'
    w ''
    w 'REDACTION CHECK, MEASURED RATHER THAN ASSUMED'
    local leak
    leak="$(count_matches -E -i -e 'password|passwd|secret|token=|_auth|://[^/ ]*:[^/ @]*@' \
        "${TMP}/${side}.sig")"
    w "  credential-shaped-lines-in-census: ${leak}"
    if [ "${leak:-0}" -eq 0 ]; then
        w '  Nothing required redaction, and that is a measurement over the census block'
        w '  below rather than an assumption.  The check is not ceremonial: a failure'
        w '  message routinely echoes the endpoint it failed on, and a stack frame can'
        w '  carry the same text.'
    else
        w '  A credential-shaped line reached the census.  The producer sanitises every'
        w '  region before writing it, so this indicates a shape the sanitiser does not'
        w '  cover and MUST be resolved before this evidence is published.'
    fi
    w ''
    w '----- BEGIN CENSUS -----'
    cat "${TMP}/${side}.sig.census" >> "$OUT"
    w '----- END CENSUS -----'
    w ''
    w 'ERROR-SEVERITY SHAPES ON THIS SIDE, WITH THEIR DISPOSITION'
    w '  present-on-both means the shape occurs on the pre-migration side too, so the'
    w '  change set cannot have introduced it.  removed-by-migration means it occurs only'
    w '  on the pre-migration side.  attributable-to-migration means it occurs only after'
    w '  the change set, and is the one outcome that fails this gate.'
    w '  The classification and evidence of each row come from the committed ledger'
    w '  docs/migration/smoke-evidence/startup-error-dispositions.txt, matched by the'
    w '  substring shown.  A shape no ledger row matches is UNDISPOSED and fails the gate.'
    w ''
    local n=0 onm onb cls ev key shape
    while IFS="$(printf '\t')" read -r onm onb cls ev key shape; do
        case "$side" in
            mig)  [ "$onm" = 'yes' ] || continue ;;
            base) [ "$onb" = 'yes' ] || continue ;;
        esac
        n=$((n + 1))
        w ''
        w "  [${n}] shape:"
        printf '        %s\n' "$shape" >> "$OUT"
        w "      occurrences-this-side: $(count_matches -x -F -e "$shape" "${TMP}/${side}.sev")"
        w "      present-on-migrated-side: ${onm}"
        w "      present-on-pre-migration-side: ${onb}"
        if [ "$onm" = 'yes' ] && [ "$onb" = 'yes' ]; then
            w '      pair-status: present-on-both — not attributable to the change set'
        elif [ "$onm" = 'yes' ]; then
            w '      pair-status: ATTRIBUTABLE-TO-MIGRATION — present only after the change set'
        else
            w '      pair-status: removed-by-migration — present only before the change set'
        fi
        w "      classification: ${cls}"
        w "      evidence: ${ev}"
        w "      ledger-match: ${key}"
    done < "${TMP}/dispositions"
    if [ "$n" -eq 0 ]; then
        w '  none — this side carries no error-severity line at all.'
    fi
    w ''
    w 'WHY THIS FILE REPORTS A RESULT AND NEVER AN EXIT STATUS FOR THE SCAN ITSELF'
    w '  grep exits non-zero when it finds nothing, so an exit status would read the'
    w '  cleanest possible scan as a failure and the noisiest as a success.  The gate'
    w '  outcome computed in startup.status beside this file is the assertion; this file'
    w '  is the census the assertion is computed from.'
}

write_status()
{
    local side="$1" dir="$2" runtime="$3" label="$4" peer="$5"
    local pd_found pd_proc pd_pat
    case "$side" in
        mig)  pd_found="$MIG_FOUND";  pd_proc="$MIG_PROC";  pd_pat="$MIG_PATTERNS" ;;
        base) pd_found="$BASE_FOUND"; pd_proc="$BASE_PROC"; pd_pat="$BASE_PATTERNS" ;;
    esac
    OUT="${dir}/startup/startup.status"
    : > "$OUT" || exit 2

    w 'capture: the deployment-and-startup gate for this side, adjudicated from the'
    w '  archived startup regions in this directory'
    w "runtime: ${runtime}"
    w "capture-side: ${label}"
    w 'produced-by: docs/migration/smoke-evidence/capture-startup-adjudication.sh'
    w 'GENERATED-NOT-AUTHORED: every region row, count and gate row below was read or'
    w '  computed at the moment of writing.  The gate outcome is COMPUTED from the rows'
    w '  and cannot be set independently of them, which is the property the authored'
    w '  version of this file lacked.'
    identity_block
    w "source: the ten startup regions in ${dir##*/}/startup/"
    w "comparison-side: ${peer}"
    w "gate: AAP 0.9.4 — deployment reaches ready state with no migration-attributable"
    w '  ERROR entry, and the process engine'"'"'s loaded definition total observed'
    w ''
    w "GATE-OUTCOME: ${GATE}"
    w "  This outcome is shared by both sides, because its central condition is a"
    w '  statement about the PAIR: an error shape is attributable to the migration only'
    w '  if it is absent before it and present after.  A per-side verdict could not'
    w '  express that and would invite the two sides to disagree.'
    w ''
    printf '  %-40s %-28s %-34s %s\n' 'condition' 'required' 'measured' 'outcome' >> "$OUT"
    while IFS="$(printf '\t')" read -r cond req meas res; do
        printf '  %-40s %-28s %-34s %s\n' "$cond" "$req" "$meas" "$res" >> "$OUT"
    done < "${TMP}/gate"
    w ''
    w "  conditions-failing: ${GATE_FAILS}"
    w ''
    w 'REGION MANIFEST'
    w '  The ten region files this directory holds, each with the classification it'
    w '  declares for itself and the body line count COUNTED here between its delimiters.'
    w '  errors.log is the one region that is not mandatory, and the reason is the'
    w '  opposite of the others: there, an empty body is the good outcome.'
    w ''
    printf '  %-26s %-10s %10s %10s %10s %s\n' 'region' 'mandatory' 'declared' 'derived' \
        'signature' 'agree' >> "$OUT"
    while IFS="$(printf '\t')" read -r r mand declared derived sig; do
        printf '  %-26s %-10s %10s %10s %10s %s\n' "$r" "$mand" "$declared" "$derived" "$sig" \
            "$([ "$declared" = "$derived" ] && echo yes || echo NO)" >> "$OUT"
    done < "${TMP}/${side}.regions"
    w ''
    w '  Two further files sit in this directory and are NOT regions: error-scan.txt, the'
    w '  census this status is computed against, and this file.  Neither scans itself.'
    if [ "$INTEGRITY_FAULTS" -gt 0 ]; then
        w ''
        w 'REGION INTEGRITY FAULTS'
        sed 's/^/  /' "${TMP}/integrity" >> "$OUT"
    fi
    w ''
    w 'ERROR CENSUS AND THE PAIR COMPARISON'
    w "  error-or-severe-severity-lines-this-side: $(wc -l < "${TMP}/${side}.sev" | tr -d '[:space:]')"
    w "  distinct-error-severity-shapes-this-side: $(wc -l < "${TMP}/${side}.sev.keys" | tr -d '[:space:]')"
    w "  severe-severity-lines-this-side: $(count_matches -E -e '\[SEVERE\]|^SEVERE:' "${TMP}/${side}.sev")"
    w "  shapes-present-on-both-sides: ${N_SEV_BOTH}"
    w "  shapes-present-only-after-the-change-set: ${N_SEV_MIG_ONLY}"
    w "  shapes-present-only-before-the-change-set: ${N_SEV_BASE_ONLY}"
    w "  shapes-undisposed: ${UNDISPOSED} of ${N_SHAPES_ALL}"
    w ''
    w '  At the signature level, which is broader than the severity level because it also'
    w '  matches exception and stack-frame lines carrying no severity marker of their own:'
    w "  signature-shapes-present-only-after-the-change-set: ${N_SIG_MIG_ONLY}"
    w "  signature-shapes-present-only-before-the-change-set: ${N_SIG_BASE_ONLY}"
    local sline sd scls sev_txt
    if [ "$N_SIG_MIG_ONLY" -gt 0 ]; then
        w '  the post-migration-only signature shapes, listed rather than counted, each'
        w '  with whatever the ledger says about it:'
        while IFS= read -r sline; do
            [ -n "$sline" ] || continue
            sd="$(dispose "$sline")"; scls="${sd%%	*}"; sev_txt="${sd#*	}"; sev_txt="${sev_txt%%	*}"
            printf '    %s\n' "$sline" >> "$OUT"
            printf '      classification: %s\n' "$scls" >> "$OUT"
            printf '      evidence: %s\n' "$sev_txt" >> "$OUT"
        done < "${TMP}/sig.mig-only"
    fi
    if [ "$N_SIG_BASE_ONLY" -gt 0 ]; then
        w '  the pre-migration-only signature shapes, listed rather than counted, each'
        w '  with whatever the ledger says about it:'
        while IFS= read -r sline; do
            [ -n "$sline" ] || continue
            sd="$(dispose "$sline")"; scls="${sd%%	*}"; sev_txt="${sd#*	}"; sev_txt="${sev_txt%%	*}"
            printf '    %s\n' "$sline" >> "$OUT"
            printf '      classification: %s\n' "$scls" >> "$OUT"
            printf '      evidence: %s\n' "$sev_txt" >> "$OUT"
        done < "${TMP}/sig.base-only"
    fi
    w '  A signature-only difference does not fail this gate and is not silently dropped'
    w '  either: it is listed above so a reader can see what it is.  The gate turns on'
    w '  SEVERITY, because a line the application chose to log at error severity is the'
    w '  thing AAP 0.9.4 speaks about, while an exception name inside an informational'
    w '  line is not.'
    w ''
    w '  WHY THE COMPARISON IS OVER SHAPES AND NOT OVER COUNTS.  Several of these shapes'
    w '  come from scheduled jobs that fire on a fixed cadence, so how many times one'
    w '  appears is a function of how long the window happened to be rather than of'
    w '  anything the change set did.  Two windows of different lengths would therefore'
    w '  differ in multiplicity while describing identical behaviour, and a count-based'
    w '  comparison would report that as a regression.  Per-side occurrence counts are'
    w '  still published, per shape, in error-scan.txt beside this file — they are'
    w '  informative and they are simply not what the gate turns on.'
    w ''
    w 'PROCESS-DEFINITION TOTAL, OBSERVED'
    w '  The review recorded this figure as unobserved.  It is observed here from the'
    w '  engine'"'"'s own log, inside the archived region, so it is re-derivable by a reader'
    w '  with no database and no running stack:'
    w "  scan-patterns-the-deployer-reported: ${pd_pat}"
    w "  resources-the-application-deployer-found: ${pd_found}"
    w "  resources-the-engine-deployer-processed-into-definitions: ${pd_proc}"
    w "  observed-on-the-other-side: $([ "$side" = 'mig' ] && printf '%s' "$BASE_PROC" || printf '%s' "$MIG_PROC")"
    w ''
    w '  RECONCILIATION TO THE TRACKED SET, DERIVED RATHER THAN ASSERTED.  The pattern'
    w '  list above is parsed out of the deployer'"'"'s own line and matched against the'
    w '  repository'"'"'s tracked main-source resources, so the expected set comes from what'
    w '  the application said it looked for rather than from what a person believed:'
    w "  expected-set-basis: ${EXPECTED_BASIS}"
    w "  tracked-main-source-resources-the-patterns-select: ${N_EXPECTED}"
    if [ "$N_EXPECTED" -gt 0 ]; then
        sed 's/^/    /' "${TMP}/expected-bpmn" >> "$OUT"
    fi
    w '  A tracked resource that matches a pattern but lies under a TEST resource root is'
    w '  correctly absent from the deployed set and from the count above, because the'
    w '  classpath scan runs against the packaged application rather than the repository.'
    w '  Resources outside these patterns belong to the extension applications that'
    w '  deploy their own processes and are not part of this deployment'"'"'s total.'
    w ''
    w 'THE OTHER TWO CONDITIONS AAP 0.9.4 NAMES, OBSERVED'
    w '  The packaged application and the three frontend files the change set creates:'
    w "  packaged-application: ${WAR_PATH##*/}"
    w "  three-new-frontend-files: ${WAR_STATUS} — ${WAR_DETAIL}"
    w '  The three are the committed lockfile, the runtime version pin and the generated'
    w '  configuration module.  No packaging descriptor change was needed for them, because'
    w '  no project file in this reactor declares a packaging exclusion or a web-resource'
    w '  override, so their absence would indicate a genuine packaging fault rather than a'
    w '  missing exclusion edit.  UNAVAILABLE is not a failure and is not counted as one: a'
    w '  build output is deleted by the next clean build, whereas the regions this record is'
    w '  otherwise computed from remain re-derivable from the archive indefinitely.'
    w ''
    w '  The aspect auto-proxy configuration:'
    w "  aspect-classes-in-tracked-main-source: ${ASPECT_CLASSES}"
    w "  tracked-main-resource-files-enabling-aspect-auto-proxying: ${AUTOPROXY_FILES}"
    w "  root-context-reached-full-initialisation: migrated ${MIG_CTX}, pre-migration ${BASE_CTX}"
    w '  WHAT DISCHARGES THIS CONDITION, AND WHAT DOES NOT.  The framework does not log'
    w '  advisor or proxy creation at informational severity, and this deployment logs the'
    w '  framework at informational severity, so there is no per-aspect line to point at and'
    w '  saying otherwise would be an invention.  What IS observed is stronger than a count'
    w '  of log lines: the aspect beans and the auto-proxy post-processor are members of the'
    w '  root context, and a failure to build an advisor or to proxy a target aborts the'
    w '  context refresh rather than degrading quietly.  The context reaching full'
    w '  initialisation on BOTH runtimes is therefore the observation, and the two counts'
    w '  above state how large the surface is that it covered.  This is the practical'
    w '  confirmation of the migration analysis that left the aspect library unchanged.'
    w ''
    w 'WHAT THIS FILE IS NOT'
    w '  It is not a behavioural verdict on the eight flows; those carry their own'
    w '  per-flow records and their own comparison.  It is not a claim that the'
    w '  environment is complete: a service the reference stack does not provide shows up'
    w '  as an error shape present on BOTH sides, which is exactly how it should read.'
    w '  And it is never an exit status of a grep — see error-scan.txt beside it.'
}

w() { printf '%s\n' "$*" >> "$OUT"; }
OUT='/dev/null'

write_error_scan base "$BASE_DIR" 'JDK 8' 'baseline-pre-migration' "${MIG_DIR##*/}/startup/"
write_error_scan mig  "$MIG_DIR"  'Java 17' 'migrated-post-migration-replay' "${BASE_DIR##*/}/startup/"
write_status    base "$BASE_DIR" 'JDK 8' 'baseline-pre-migration' "${MIG_DIR##*/}/startup/"
write_status    mig  "$MIG_DIR"  'Java 17' 'migrated-post-migration-replay' "${BASE_DIR##*/}/startup/"

printf 'capture-startup-adjudication.sh: wrote\n'
for f in "${BASE_DIR}/startup/error-scan.txt" "${BASE_DIR}/startup/startup.status" \
         "${MIG_DIR}/startup/error-scan.txt" "${MIG_DIR}/startup/startup.status"; do
    printf '  %-70s %s bytes\n' "${f#"${HERE}/"}" "$(wc -c < "$f" | tr -d '[:space:]')"
done
printf 'capture-startup-adjudication.sh: GATE-OUTCOME %s (%s failing condition(s))\n' \
    "$GATE" "$GATE_FAILS"
awk -F'\t' -v OFS='  ' '{ printf "  %-42s %-30s %s\n", $1, $3, $4 }' "${TMP}/gate"
if [ "$GATE" = 'PASS' ]; then exit 0; fi
exit 1
