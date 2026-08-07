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
CURRENT_DIR=${1:-"$REPOSITORY_ROOT/target/advisory-corpus-current"}
MANIFEST="$SCRIPT_DIR/${BASELINE_DATE}-sha256-manifest.txt"

[[ "$BASELINE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
    fail "BASELINE_DATE must use YYYY-MM-DD"
[[ -f "$MANIFEST" ]] || fail "reviewed corpus manifest is missing: $MANIFEST"

(
    cd "$SCRIPT_DIR"
    sha256sum --check "${BASELINE_DATE}-sha256-manifest.txt"
)

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