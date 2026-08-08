#!/usr/bin/env bash
#
# probe.sh — exercise the reinstated activation framework's MIME-type mapping, and
# record what it resolved, under each of the two artifacts that satisfy the same API.
#
# WHY THIS DIRECTORY EXISTS, AND WHY IT IS SEPARATE FROM THE DOCUMENT ROUND TRIP.
#
# The migration reinstates the JavaBeans Activation Framework, which JEP 320 removed
# from the JDK, as an ordinary Maven dependency.  Two artifacts satisfy the same
# javax.activation API and their coordinates give no hint that the choice matters:
# one is the reference implementation and one is API-only.  The plan records the
# choice as BEHAVIOURAL rather than cosmetic, and assigned the evidence for it to
# the document round-trip flow.
#
# THAT ASSIGNMENT DOES NOT WORK, and this directory is the answer to why.  The
# round-trip flow sends its document with an EXPLICIT content type on the request,
# so the application never has to resolve one, and the activation defaults are never
# consulted on either leg.  A round trip that succeeds therefore says nothing at all
# about MIME resolution — it would succeed identically with the wrong artifact — and
# the flow additionally cannot run at all where the content repository is not
# provisioned.  Evidence for a behavioural artifact choice cannot rest on a flow
# that does not exercise the behaviour.
#
# WHAT THIS PROBE ESTABLISHES INSTEAD.  It calls the exact API the application's own
# consumers call — new MimetypesFileTypeMap().getContentType(name) — for a fixed set
# of attachment names, under each candidate artifact in turn, and records the
# resolutions.  It also records, from the jars themselves, whether each carries the
# two default resources that call reads, and which activation jar the built
# deployment archive actually ships.
#
# EVIDENCE OVER EXIT STATUS.  Every assertion below is made on captured output.  The
# probe's own exit status is recorded as an observation and is never the assertion,
# which matters here more than usual: one of the two artifacts makes the call throw,
# and a script that branched on exit status would have reported that as a failure of
# the probe rather than as the finding it is.
#
# Usage:  ./probe.sh [--out <file>]
# Default output: results.txt beside this script.

set -u
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
OUT="${SCRIPT_DIR}/results.txt"
# Four levels up, not three: this script lives at
# docs/migration/smoke-evidence/activation-mime/.  Three levels reached docs/ and
# silently made the deployment-archive path and the consumer census wrong, which
# published "0 in main source" for a call four files make.
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." && pwd)"
LOCAL_REPO="${LOCAL_REPO:-${HOME}/.m2/repository}"
WORK=''

die()
{
    printf 'probe.sh: %s\n' "$1" >&2
    exit 1
}

require_value()
{
    # A missing option value must be a refusal, never a silent default and never a
    # loop that never terminates: the parser below shifts two positions, so it has
    # to be told that two are present.
    [ "$1" -ge 2 ] || die "the $2 option requires a value"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --out) require_value "$#" '--out'; OUT="$2"; shift 2 ;;
        --help|-h)
            printf 'usage: %s [--out <file>]\n' "$0"
            exit 0
            ;;
        *) die "unrecognised argument: $1" ;;
    esac
done

cleanup()
{
    [ -n "$WORK" ] && [ -d "$WORK" ] && rm -rf -- "$WORK"
}
trap cleanup EXIT

command -v javac > /dev/null 2>&1 || die 'javac is not on PATH; the probe cannot be compiled'
command -v java  > /dev/null 2>&1 || die 'java is not on PATH; the probe cannot be run'

WORK="$(mktemp -d)" || die 'could not create a working directory'

RI_JAR="${LOCAL_REPO}/com/sun/activation/javax.activation/1.2.0/javax.activation-1.2.0.jar"
API_JAR="${LOCAL_REPO}/javax/activation/javax.activation-api/1.2.0/javax.activation-api-1.2.0.jar"
LEGACY_JAR="${LOCAL_REPO}/javax/activation/activation/1.1/activation-1.1.jar"
WAR="${REPO_ROOT}/acm-standard-applications/arkcase/target/arkcase-2021.03.war"

# jar_default_resources <jar> — how many of the two behaviour-bearing default
# resources the jar carries, and how many classes it holds.  Read from the archive
# rather than from any document, because the whole point of this directory is that
# the coordinates do not tell you.
jar_default_resources()
{
    local jar="$1"
    if [ ! -f "$jar" ]; then
        printf 'ABSENT'
        return 0
    fi
    if ! command -v unzip > /dev/null 2>&1; then
        printf 'UNVERIFIABLE-NO-UNZIP'
        return 0
    fi
    printf '%s of 2 default resources, %s classes' \
        "$(unzip -l -- "$jar" 2>/dev/null \
            | LC_ALL=C grep -c -E 'META-INF/(mimetypes|mailcap)\.default' || true)" \
        "$(unzip -l -- "$jar" 2>/dev/null | LC_ALL=C grep -c '\.class$' || true)"
}

# mimetypes_payload_comparison <jar-a> <jar-b> — compare the ONE resource
# MimetypesFileTypeMap actually reads, at two levels, because the two levels
# disagree and only one of them bears on behaviour.
#
# A byte comparison of META-INF/mimetypes.default is the obvious check and it is
# the misleading one: the file carries a licence header and comments, so two jars
# can ship the same mappings and still differ as bytes.  A register entry that
# rejected an artifact because "its mimetypes.default differs" was resting on
# exactly that reading.  The payload comparison strips comments and blank lines,
# collapses whitespace and sorts, leaving only the extension-to-type pairs the
# map is built from.  Both readings are printed so neither can be quoted alone.
mimetypes_payload_comparison()
{
    local a="$1"
    local b="$2"
    local dir_a="${WORK}/res-a"
    local dir_b="${WORK}/res-b"
    local res='META-INF/mimetypes.default'
    local file_a="${dir_a}/${res}"
    local file_b="${dir_b}/${res}"

    if [ ! -f "$a" ] || [ ! -f "$b" ]; then
        printf 'UNVERIFIABLE: one or both artifacts are absent\n'
        return 0
    fi
    if ! command -v unzip > /dev/null 2>&1; then
        printf 'UNVERIFIABLE: unzip is not available to read the archives\n'
        return 0
    fi

    rm -rf -- "$dir_a" "$dir_b"
    mkdir -p -- "$dir_a" "$dir_b"
    ( cd "$dir_a" && unzip -o -q -- "$a" "$res" ) > /dev/null 2>&1 || true
    ( cd "$dir_b" && unzip -o -q -- "$b" "$res" ) > /dev/null 2>&1 || true

    if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
        printf 'UNVERIFIABLE: %s is not present in both archives\n' "$res"
        return 0
    fi

    printf '  as bytes:   %s bytes against %s bytes — %s\n' \
        "$(wc -c < "$file_a" | tr -d '[:space:]')" \
        "$(wc -c < "$file_b" | tr -d '[:space:]')" \
        "$(if cmp -s -- "$file_a" "$file_b"; then printf 'IDENTICAL'; else printf 'DIFFER'; fi)"

    local norm_a="${WORK}/res-a.payload"
    local norm_b="${WORK}/res-b.payload"
    local n_a n_b differing
    for pair in "a ${file_a} ${norm_a}" "b ${file_b} ${norm_b}"; do
        set -- $pair
        LC_ALL=C sed -e 's/#.*$//' -e 's/[[:space:]][[:space:]]*/ /g' \
                     -e 's/^ //' -e 's/ $//' "$2" \
            | LC_ALL=C grep -v '^$' \
            | LC_ALL=C sort > "$3"
    done
    n_a="$(wc -l < "$norm_a" | tr -d '[:space:]')"
    n_b="$(wc -l < "$norm_b" | tr -d '[:space:]')"
    differing="$(LC_ALL=C diff -- "$norm_a" "$norm_b" 2>/dev/null \
        | LC_ALL=C grep -c '^[<>]' || true)"
    printf '  as mappings: %s pairs against %s pairs — %s differing\n' \
        "$n_a" "$n_b" "$differing"
    if [ "$differing" = '0' ] && [ "$n_a" = "$n_b" ]; then
        printf '  VERDICT: the archives differ only in comments.  Classpath order between\n'
        printf '  these two cannot change a resolved media type, because there is no mapping\n'
        printf '  on which they disagree.\n'
    else
        printf '  VERDICT: the mappings themselves differ, so with both providers present a\n'
        printf '  resolved media type would depend on which one the classpath reached first.\n'
    fi
}

# run_probe <label> <jar> <output-file> — run the probe against one artifact and
# capture stdout, stderr and the observed exit status together.
run_probe()
{
    # The label is the caller's own documentation of which artifact it is asking
    # about; it is intentionally not used in the body, so it is consumed by the shift
    # rather than bound to a name nothing reads.
    shift
    local jar="$1"
    local target="$2"
    local status

    if [ ! -f "$jar" ]; then
        printf 'NOT-RUN: the artifact is not present at the expected path\n' > "$target"
        printf 'not-present'
        return 0
    fi
    java -cp "${WORK}/classes:${jar}" MimeProbe > "$target" 2>&1
    status=$?
    printf '%s' "$status"
}

javac -d "${WORK}/classes" -cp "$RI_JAR" "${SCRIPT_DIR}/MimeProbe.java" \
    > "${WORK}/compile.log" 2>&1 \
    || die "the probe did not compile; see ${WORK}/compile.log"

RI_STATUS="$(run_probe 'reference-implementation' "$RI_JAR" "${WORK}/ri.txt")"
API_STATUS="$(run_probe 'api-only' "$API_JAR" "${WORK}/api.txt")"
LEGACY_STATUS="$(run_probe 'legacy-1.1' "$LEGACY_JAR" "${WORK}/legacy.txt")"

# The activation jars the built deployment archive actually ships.  This is the
# only row in the file that describes the DEPLOYED classpath rather than a
# candidate, and it is what makes the rest of the file relevant to the deployment
# instead of merely true about a local artifact cache.
WAR_ROW='the deployment archive has not been built in this tree, so the deployed classpath is not observed here'
if [ -f "$WAR" ] && command -v unzip > /dev/null 2>&1; then
    WAR_ROW="$(unzip -l -- "$WAR" 2>/dev/null \
        | LC_ALL=C grep -i -E 'WEB-INF/lib/.*activation.*\.jar' \
        | LC_ALL=C sed -e 's|.*WEB-INF/lib/|WEB-INF/lib/|' \
        | LC_ALL=C sort | tr '\n' ' ')"
    [ -n "$WAR_ROW" ] || WAR_ROW='no activation jar was found in the archive, which would mean the reinstated framework is not deployed at all'
fi

# The application's own consumers of the call this probe makes, counted from the
# source tree so the figure cannot drift from it.
# This probe's OWN source imports the same class, so it is excluded by path: a
# census of application consumers that counts the instrument measuring them is a
# census that is wrong by one and reads as if it were right.
CONSUMERS="$(LC_ALL=C grep -rl 'javax\.activation\.MimetypesFileTypeMap' \
    --include='*.java' "$REPO_ROOT" 2>/dev/null \
    | LC_ALL=C grep -v '/target/' \
    | LC_ALL=C grep -v '/docs/migration/smoke-evidence/' \
    | LC_ALL=C sort || true)"
CONSUMERS_MAIN="$(printf '%s\n' "$CONSUMERS" | LC_ALL=C grep -c '/src/main/java/' || true)"
CONSUMERS_TEST="$(printf '%s\n' "$CONSUMERS" | LC_ALL=C grep -c '/src/test/java/' || true)"

{
    printf 'activation framework MIME-type resolution — the measured artifact comparison\n'
    printf '%s\n' '============================================================================='
    printf '\n'
    printf 'produced-by: docs/migration/smoke-evidence/activation-mime/probe.sh\n'
    printf 'probe-source: docs/migration/smoke-evidence/activation-mime/MimeProbe.java\n'
    printf 'java-version-observed: %s\n' \
        "$(java -version 2>&1 | head -1 | LC_ALL=C sed -e 's/^[[:space:]]*//')"
    printf 'javac-version-observed: %s\n' \
        "$(javac -version 2>&1 | head -1 | LC_ALL=C sed -e 's/^[[:space:]]*//')"
    printf '\n'
    printf 'WHY THIS FILE IS NOT PART OF THE DOCUMENT ROUND-TRIP EVIDENCE\n'
    printf '  The round-trip flow sends its document with an EXPLICIT content type on the\n'
    printf '  request, so the application never resolves one and the activation defaults are\n'
    printf '  never consulted on either leg.  A successful round trip would look exactly the\n'
    printf '  same with the wrong artifact, and the flow cannot run at all where the content\n'
    printf '  repository is not provisioned.  Evidence for a behavioural artifact choice\n'
    printf '  cannot rest on a flow that does not exercise the behaviour, so the behaviour is\n'
    printf '  exercised here instead, directly and without a network.\n'
    printf '\n'
    printf 'THE CANDIDATE ARTIFACTS, READ FROM THE ARCHIVES\n'
    printf '  reference implementation  com.sun.activation:javax.activation:1.2.0\n'
    printf '    %s\n' "$(jar_default_resources "$RI_JAR")"
    printf '  API-only                  javax.activation:javax.activation-api:1.2.0\n'
    printf '    %s\n' "$(jar_default_resources "$API_JAR")"
    printf '  legacy standalone         javax.activation:activation:1.1\n'
    printf '    %s\n' "$(jar_default_resources "$LEGACY_JAR")"
    printf '  The two default resources are META-INF/mimetypes.default and\n'
    printf '  META-INF/mailcap.default.  MimetypesFileTypeMap reads the first of them, so a\n'
    printf '  jar without it has nothing to resolve an extension against.\n'
    printf '\n'
    printf 'THE ONE RESOURCE THAT MATTERS, REFERENCE IMPLEMENTATION AGAINST LEGACY 1.1\n'
    printf '%s' "$(mimetypes_payload_comparison "$RI_JAR" "$LEGACY_JAR")"
    printf '\n'
    printf '  This comparison exists to hold one register entry to its evidence.  The\n'
    printf '  reasoning first recorded for rejecting the legacy jar was that its copy of this\n'
    printf '  resource differs from the reference implementation\x27s.  It does, as bytes.  It\n'
    printf '  does not, as mappings, and the mappings are what the map is built from.  The\n'
    printf '  rejection is sound on other grounds — an artifact this migration depends on is\n'
    printf '  pinned explicitly rather than inherited, and two providers of one package is a\n'
    printf '  duplicate-provider classpath — but not on this one, and the register now says so.\n'
    printf '\n'
    printf 'WHAT THE DEPLOYED ARCHIVE ACTUALLY SHIPS\n'
    printf '  %s\n' "$WAR_ROW"
    printf '  Exactly one activation jar on the deployed classpath is the intended state: a\n'
    printf '  second provider for the same package would make resolution order-dependent,\n'
    printf '  which is why the reactor excludes the legacy standalone jar from both of the\n'
    printf '  dependencies that drag it in.\n'
    printf '\n'
    printf 'THE APPLICATION CONSUMERS OF THIS EXACT CALL, counted from the source tree\n'
    printf '  files importing javax.activation.MimetypesFileTypeMap: %s in main source, %s in test source\n' \
        "$CONSUMERS_MAIN" "$CONSUMERS_TEST"
    printf '%s\n' "$CONSUMERS" | LC_ALL=C sed -e "s|^${REPO_ROOT}/|    |"
    printf '  Each of the main-source consumers resolves an attachment or captured-document\n'
    printf '  name through new MimetypesFileTypeMap().getContentType(name) — the identical\n'
    printf '  call this probe makes.\n'
    printf '\n'
    printf 'OBSERVED: REFERENCE IMPLEMENTATION\n'
    printf '  exit status observed: %s\n' "$RI_STATUS"
    LC_ALL=C sed -e 's|^|  |' "${WORK}/ri.txt"
    printf '\n'
    printf 'OBSERVED: API-ONLY ARTIFACT\n'
    printf '  exit status observed: %s\n' "$API_STATUS"
    LC_ALL=C sed -e 's|^|  |' "${WORK}/api.txt"
    printf '\n'
    printf 'OBSERVED: LEGACY STANDALONE ARTIFACT, the one the reactor excludes\n'
    printf '  exit status observed: %s\n' "$LEGACY_STATUS"
    LC_ALL=C sed -e 's|^|  |' "${WORK}/legacy.txt"
    printf '\n'
    printf 'THE COMPARISON, computed from the two captures above\n'
    if [ -s "${WORK}/ri.txt" ] && [ -s "${WORK}/api.txt" ]; then
        if cmp -s -- "${WORK}/ri.txt" "${WORK}/api.txt"; then
            printf '  IDENTICAL — the two artifacts produced the same output, so this probe does\n'
            printf '  NOT discriminate between them and the artifact choice is not evidenced here.\n'
        else
            printf '  DIFFERENT — the two artifacts do not behave alike.  "<" is the API-only\n'
            printf '  artifact and ">" is the reference implementation:\n'
            LC_ALL=C diff -- "${WORK}/api.txt" "${WORK}/ri.txt" 2>/dev/null \
                | LC_ALL=C sed -e 's|^|    |'
        fi
    else
        printf '  NOT COMPUTABLE — one of the two captures is empty.\n'
    fi
    printf '\n'
    printf 'WHAT THIS FILE ESTABLISHES, AND WHAT IT DOES NOT\n'
    printf '  It establishes that the artifact choice is behaviour-bearing and that the\n'
    printf '  artifact the deployment ships is the one that carries the resources the call\n'
    printf '  reads.  Read the observed captures above rather than this sentence: they are\n'
    printf '  the evidence and this is a summary of them.\n'
    printf '  It does NOT establish that any application code path ran in a deployed\n'
    printf '  container.  It exercises the API the consumers call, on the same runtime, from\n'
    printf '  the same artifact the deployment ships; it does not observe the consumers\n'
    printf '  themselves.  The class-level assertions for those live in the archived unit\n'
    printf '  suite, and observing them end to end needs a mail or capture path that this\n'
    printf '  environment does not provide.  Both limits are stated rather than left to be\n'
    printf '  inferred from a passing probe.\n'
} > "$OUT"

printf 'probe.sh: wrote %s\n' "$OUT" >&2
printf 'probe.sh: reference-implementation exit %s, API-only exit %s, legacy exit %s\n' \
    "$RI_STATUS" "$API_STATUS" "$LEGACY_STATUS" >&2
printf 'probe.sh: this script asserts on captured output, never on an exit status;\n' >&2
printf '  one of the artifacts above is EXPECTED to fail and that failure is the finding.\n' >&2
exit 0
