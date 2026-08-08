#!/usr/bin/env bash
#
# Re-query the authoritative package-advisory services and fail when their
# current answers or the lockfile-derived SBOM differ from the reviewed corpus.

set -euo pipefail

fail()
{
    printf 'verify-advisory-corpus: %s\n' "$*" >&2
    exit 1
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPOSITORY_ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)
BASELINE_DATE=${BASELINE_DATE:-2026-08-07}

# --offline runs every check that needs no network: corpus integrity against the SHA-256
# manifest, and the two triage producers whose published output the disclosure pages quote.
# It exists because the full run re-queries the advisory services, so in an air-gapped
# validation environment the triage consistency of the pages could not be checked at all --
# and an unrunnable gate is indistinguishable from a passing one.
OFFLINE_ONLY=no
if [ "${1:-}" = '--offline' ]; then
    OFFLINE_ONLY=yes
    shift
fi

CURRENT_DIR=${1:-"$REPOSITORY_ROOT/target/advisory-corpus-current"}
MANIFEST="$SCRIPT_DIR/${BASELINE_DATE}-sha256-manifest.txt"

[[ "$BASELINE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
    fail "BASELINE_DATE must use YYYY-MM-DD"
[[ -f "$MANIFEST" ]] || fail "reviewed corpus manifest is missing: $MANIFEST"

(
    cd "$SCRIPT_DIR"
    sha256sum --check "${BASELINE_DATE}-sha256-manifest.txt"
)

# The disclosure pages state derived figures -- advisory counts, carried/entered positions,
# served-versus-build classification -- and each is published by a producer beside this
# script.  Re-run both and require them to agree with what is committed.  A drifted triage is
# a page making a claim the corpus no longer supports, which is the failure these gates exist
# to catch, so the comparison is byte-for-byte against the committed authority.
verify_triage()
{
    # $1 producer, $2 published authority, $3 extra producer args (may be empty)
    local producer="$1" published="$2"
    shift 2
    [[ -x "$SCRIPT_DIR/$producer" ]] || fail "triage producer is missing or not executable: $producer"
    [[ -f "$SCRIPT_DIR/$published" ]] || fail "published triage is missing: $published"

    if ! "$SCRIPT_DIR/$producer" "$@" >/dev/null; then
        fail "triage producer failed: $producer (see its own output for the reason)"
    fi
    printf 'Triage reproduced: %s\n' "$published"
}

# The two producers stamp the time they ran, under different key names, so the comparison is
# over the substantive body with any stamp line removed.  Filtering only one key name silently
# compared a stamp against a stamp and reported drift where there was none.
triage_body()
{
    grep -vE '^(generated-at|written-at)' "$1"
}

TRIAGE_BACKUP_DIR="$(mktemp -d)"
cp -- "$SCRIPT_DIR/advisory-triage.txt" "$TRIAGE_BACKUP_DIR/" 2>/dev/null || true
cp -- "$SCRIPT_DIR/frontend-advisory-triage.txt" "$TRIAGE_BACKUP_DIR/" 2>/dev/null || true

check_triage_body_unchanged()
{
    # $1 published file name.  Compares the committed body -- everything except the
    # generation stamp -- against the body the producer has just written.
    local name="$1"
    if [[ -f "$TRIAGE_BACKUP_DIR/$name" ]]; then
        if ! diff <(triage_body "$TRIAGE_BACKUP_DIR/$name") \
                  <(triage_body "$SCRIPT_DIR/$name") >/dev/null; then
            fail "regenerating $name changed its content: the disclosure pages quote figures the corpus no longer produces"
        fi
        printf 'Triage body unchanged on regeneration: %s\n' "$name"
    fi
}

verify_triage triage-advisory-corpus.sh advisory-triage.txt
check_triage_body_unchanged advisory-triage.txt
verify_triage triage-frontend-corpus.sh frontend-advisory-triage.txt
check_triage_body_unchanged frontend-advisory-triage.txt

if [[ "$OFFLINE_ONLY" == yes ]]; then
    printf 'Offline advisory verification passed at %s (corpus integrity and both triages).\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    exit 0
fi

if [[ -e "$CURRENT_DIR" ]]; then
    [[ -d "$CURRENT_DIR" ]] ||
        fail "verification output path is not a directory: $CURRENT_DIR"
    [[ -z "$(find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] ||
        fail "verification output directory is not empty: $CURRENT_DIR"
else
    mkdir -p "$CURRENT_DIR"
fi
"$SCRIPT_DIR/capture-advisory-corpus.sh" "$BASELINE_DATE" "$CURRENT_DIR"

for suffix in \
    npm-audit.json \
    frontend-sbom.cdx.json \
    maven-osv-queries.json \
    maven-osv-response.json \
    maven-osv-advisories.json
do
    reviewed="$SCRIPT_DIR/${BASELINE_DATE}-$suffix"
    current="$CURRENT_DIR/${BASELINE_DATE}-$suffix"
    if ! cmp -s "$reviewed" "$current"; then
        fail "authoritative advisory or SBOM result changed: $suffix"
    fi
done

BASELINE_DATE="$BASELINE_DATE" SCRIPT_DIR="$SCRIPT_DIR" CURRENT_DIR="$CURRENT_DIR" \
python3 <<'PY'
import json
import os
from pathlib import Path

baseline_date = os.environ["BASELINE_DATE"]
script_dir = Path(os.environ["SCRIPT_DIR"])
current_dir = Path(os.environ["CURRENT_DIR"])
filename = f"{baseline_date}-capture-metadata.json"

with (script_dir / filename).open(encoding="utf-8") as handle:
    reviewed = json.load(handle)
with (current_dir / filename).open(encoding="utf-8") as handle:
    current = json.load(handle)

# Tool patch versions may differ between trusted CI-image revisions. Every
# security result, source input and normalised SBOM property must still match.
reviewed.pop("toolchain", None)
current.pop("toolchain", None)
if reviewed != current:
    raise SystemExit("capture metadata differs from the reviewed corpus")

counts = reviewed["npmAudit"]["vulnerabilityCounts"]
print(
    "Verified npm advisories: "
    f"{counts['total']} total "
    f"({counts['critical']} critical, {counts['high']} high, "
    f"{counts['moderate']} moderate, {counts['low']} low)"
)
print(
    "Verified Maven OSV corpus: "
    f"{reviewed['mavenOsv']['coordinateCount']} coordinates, "
    f"{reviewed['mavenOsv']['affectedCoordinateCount']} affected, "
    f"{reviewed['mavenOsv']['advisoryCount']} unique advisories"
)
print(
    "Verified CycloneDX SBOM: "
    f"{reviewed['sbom']['componentCount']} components, "
    f"{reviewed['sbom']['dependencyEntryCount']} dependency entries"
)
PY

printf 'Advisory and SBOM verification passed at %s.\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"