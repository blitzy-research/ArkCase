#!/usr/bin/env bash
#
# Capture the dependency-advisory evidence used by
# docs/migration/frontend-dependency-security.md.
#
# Usage:
#   ./capture-advisory-corpus.sh YYYY-MM-DD [OUTPUT_DIRECTORY]
#
# The capture date is explicit so that repeated runs for the same assessment
# produce the same CycloneDX metadata. Advisory services remain live data:
# rerunning on a later date can legitimately return a different corpus.

set -euo pipefail

fail()
{
    printf 'capture-advisory-corpus: %s\n' "$*" >&2
    exit 1
}

require_command()
{
    command -v "$1" >/dev/null 2>&1 || fail "required command is not available: $1"
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    fail "usage: $0 YYYY-MM-DD [OUTPUT_DIRECTORY]"
fi

CAPTURE_DATE=$1
[[ "$CAPTURE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
    fail "capture date must use YYYY-MM-DD"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPOSITORY_ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)
FRONTEND_DIR="$REPOSITORY_ROOT/acm-standard-applications/arkcase/src/main/webapp/resources"
OUTPUT_DIR=${2:-"$SCRIPT_DIR"}
PACKAGE_LOCK="$FRONTEND_DIR/package-lock.json"

[[ -f "$PACKAGE_LOCK" ]] || fail "committed frontend lockfile is missing: $PACKAGE_LOCK"
[[ -f "$REPOSITORY_ROOT/pom.xml" ]] || fail "root Maven POM is missing"

for command_name in curl npm node python3 sha256sum; do
    require_command "$command_name"
done

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$OUTPUT_DIR"

AUDIT_FILE="${CAPTURE_DATE}-npm-audit.json"
SBOM_FILE="${CAPTURE_DATE}-frontend-sbom.cdx.json"
OSV_QUERY_FILE="${CAPTURE_DATE}-maven-osv-queries.json"
OSV_RESPONSE_FILE="${CAPTURE_DATE}-maven-osv-response.json"
OSV_ADVISORY_FILE="${CAPTURE_DATE}-maven-osv-advisories.json"
METADATA_FILE="${CAPTURE_DATE}-capture-metadata.json"
MANIFEST_FILE="${CAPTURE_DATE}-sha256-manifest.txt"

set +e
(
    cd "$FRONTEND_DIR"
    npm audit --package-lock-only --json > "$WORK_DIR/npm-audit.raw.json"
)
AUDIT_STATUS=$?
set -e
if [[ $AUDIT_STATUS -ne 0 && $AUDIT_STATUS -ne 1 ]]; then
    fail "npm audit failed with unexpected exit status $AUDIT_STATUS"
fi

(
    cd "$FRONTEND_DIR"
    npm sbom --package-lock-only --sbom-format cyclonedx \
        --sbom-type application > "$WORK_DIR/frontend-sbom.raw.json"
)

CAPTURE_DATE="$CAPTURE_DATE" PACKAGE_LOCK="$PACKAGE_LOCK" WORK_DIR="$WORK_DIR" \
python3 <<'PY'
import hashlib
import json
import os
import uuid
from pathlib import Path

work_dir = Path(os.environ["WORK_DIR"])
capture_date = os.environ["CAPTURE_DATE"]
package_lock = Path(os.environ["PACKAGE_LOCK"])

with (work_dir / "npm-audit.raw.json").open(encoding="utf-8") as handle:
    audit = json.load(handle)
if audit.get("auditReportVersion") != 2:
    raise SystemExit("unsupported npm audit report version")
metadata = audit.get("metadata", {})
vulnerabilities = metadata.get("vulnerabilities", {})
if vulnerabilities.get("total") != len(audit.get("vulnerabilities", {})):
    raise SystemExit("npm audit vulnerability totals do not match the report body")
with (work_dir / "npm-audit.json").open("w", encoding="utf-8") as handle:
    json.dump(audit, handle, indent=2, sort_keys=True)
    handle.write("\n")

with (work_dir / "frontend-sbom.raw.json").open(encoding="utf-8") as handle:
    sbom = json.load(handle)
if sbom.get("bomFormat") != "CycloneDX" or sbom.get("specVersion") != "1.5":
    raise SystemExit("npm did not produce the required CycloneDX 1.5 SBOM")

lock_digest = hashlib.sha256(package_lock.read_bytes()).hexdigest()
sbom_metadata = sbom.setdefault("metadata", {})
sbom_metadata["timestamp"] = f"{capture_date}T00:00:00Z"
sbom["serialNumber"] = "urn:uuid:" + str(
    uuid.uuid5(
        uuid.NAMESPACE_URL,
        f"https://arkcase.example/evidence/frontend-sbom/{capture_date}/{lock_digest}",
    )
)
with (work_dir / "frontend-sbom.json").open("w", encoding="utf-8") as handle:
    json.dump(sbom, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

REPOSITORY_ROOT="$REPOSITORY_ROOT" WORK_DIR="$WORK_DIR" python3 <<'PY'
import json
import os
import re
import xml.etree.ElementTree as ET
from pathlib import Path

repository_root = Path(os.environ["REPOSITORY_ROOT"])
work_dir = Path(os.environ["WORK_DIR"])
namespace = {"m": "http://maven.apache.org/POM/4.0.0"}

# These are the migration-owned version properties whose resolved coordinates
# must be checked. The two literal plugin versions are added below.
migration_properties = {
    "accessors-smart.version",
    "asm.version",
    "drools.version",
    "easymock.version",
    "eclipselink-asm.version",
    "eclipselink-jpa.version",
    "fasterxml-jackson-core.version",
    "groovy.version",
    "jacoco.version",
    "javax-activation.version",
    "javax-annotation-api.version",
    "javax-json.version",
    "javax-persistence.version",
    "javax-ws-rs-api.version",
    "jaxb-api.version",
    "jaxb-runtime.version",
    "json-smart.version",
    "maven.surefire.plugin.version",
    "mockito.core.version",
    "nashorn-core.version",
    "org.mvel.version",
    "spring.ldap.version",
    "spring.security.version",
    "spring.version",
}

root_pom = ET.parse(repository_root / "pom.xml").getroot()
properties_node = root_pom.find("m:properties", namespace)
if properties_node is None:
    raise SystemExit("root POM has no properties section")
property_values = {
    child.tag.rsplit("}", 1)[-1]: (child.text or "").strip()
    for child in properties_node
}

coordinates = set()
for pom_path in repository_root.rglob("pom.xml"):
    if not pom_path.is_file():
        continue
    if {".git", "target", ".blitzy_runtime_w007", "node_modules"} & set(
        pom_path.parts
    ):
        continue
    try:
        pom_root = ET.parse(pom_path).getroot()
    except ET.ParseError as error:
        raise SystemExit(f"cannot parse {pom_path}: {error}") from error
    for element in pom_root.iter():
        kind = element.tag.rsplit("}", 1)[-1]
        if kind not in {"dependency", "plugin"}:
            continue
        fields = {
            child.tag.rsplit("}", 1)[-1]: (child.text or "").strip()
            for child in element
        }
        version = fields.get("version", "")
        property_match = re.fullmatch(r"\$\{([^}]+)}", version)
        if property_match is None or property_match.group(1) not in migration_properties:
            continue
        property_name = property_match.group(1)
        group_id = fields.get("groupId")
        if not group_id and kind == "plugin":
            group_id = "org.apache.maven.plugins"
        artifact_id = fields.get("artifactId")
        resolved_version = property_values.get(property_name)
        if group_id and artifact_id and resolved_version:
            coordinates.add((group_id, artifact_id, resolved_version))

coordinates.update(
    {
        ("org.apache.maven.plugins", "maven-compiler-plugin", "3.13.0"),
        ("org.apache.maven.plugins", "maven-war-plugin", "3.1.0"),
    }
)

queries = [
    {
        "package": {"ecosystem": "Maven", "name": f"{group_id}:{artifact_id}"},
        "version": version,
    }
    for group_id, artifact_id, version in sorted(coordinates)
]
if len(queries) != 57:
    raise SystemExit(
        f"expected 57 migration-owned Maven coordinates, found {len(queries)}"
    )
with (work_dir / "maven-osv-queries.json").open("w", encoding="utf-8") as handle:
    json.dump({"queries": queries}, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

curl --fail --silent --show-error --retry 3 --retry-all-errors \
    --header 'Content-Type: application/json' \
    --data-binary "@$WORK_DIR/maven-osv-queries.json" \
    https://api.osv.dev/v1/querybatch \
    --output "$WORK_DIR/maven-osv-response.raw.json"

WORK_DIR="$WORK_DIR" python3 <<'PY'
import json
import os
from pathlib import Path

work_dir = Path(os.environ["WORK_DIR"])
with (work_dir / "maven-osv-queries.json").open(encoding="utf-8") as handle:
    queries = json.load(handle)["queries"]
with (work_dir / "maven-osv-response.raw.json").open(encoding="utf-8") as handle:
    response = json.load(handle)
results = response.get("results", [])
if len(queries) != len(results):
    raise SystemExit(
        f"OSV returned {len(results)} results for {len(queries)} queries"
    )
with (work_dir / "maven-osv-response.json").open("w", encoding="utf-8") as handle:
    json.dump(response, handle, indent=2, sort_keys=True)
    handle.write("\n")

advisory_ids = sorted(
    {
        vulnerability["id"]
        for result in results
        for vulnerability in result.get("vulns", [])
    }
)
with (work_dir / "maven-osv-advisory-ids.txt").open(
    "w", encoding="utf-8"
) as handle:
    for advisory_id in advisory_ids:
        handle.write(advisory_id + "\n")
PY

mkdir -p "$WORK_DIR/osv-advisories"
while IFS= read -r advisory_id; do
    [[ "$advisory_id" =~ ^[A-Za-z0-9._-]+$ ]] ||
        fail "OSV returned an unsafe advisory identifier"
    curl --fail --silent --show-error --retry 3 --retry-all-errors \
        "https://api.osv.dev/v1/vulns/$advisory_id" \
        --output "$WORK_DIR/osv-advisories/$advisory_id.json"
done < "$WORK_DIR/maven-osv-advisory-ids.txt"

WORK_DIR="$WORK_DIR" python3 <<'PY'
import json
import os
from pathlib import Path

work_dir = Path(os.environ["WORK_DIR"])
advisories = []
for advisory_path in sorted((work_dir / "osv-advisories").glob("*.json")):
    with advisory_path.open(encoding="utf-8") as handle:
        advisory = json.load(handle)
    if advisory.get("id") != advisory_path.stem:
        raise SystemExit(f"OSV advisory identity mismatch: {advisory_path}")
    advisories.append(advisory)
with (work_dir / "maven-osv-advisories.json").open(
    "w", encoding="utf-8"
) as handle:
    json.dump({"advisories": advisories}, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

CAPTURE_DATE="$CAPTURE_DATE" REPOSITORY_ROOT="$REPOSITORY_ROOT" \
PACKAGE_LOCK="$PACKAGE_LOCK" WORK_DIR="$WORK_DIR" \
NODE_VERSION="$(node --version)" NPM_VERSION="$(npm --version)" \
PYTHON_VERSION="$(python3 --version 2>&1)" CURL_VERSION="$(curl --version | head -n 1)" \
python3 <<'PY'
import hashlib
import json
import os
from pathlib import Path

capture_date = os.environ["CAPTURE_DATE"]
repository_root = Path(os.environ["REPOSITORY_ROOT"])
package_lock = Path(os.environ["PACKAGE_LOCK"])
work_dir = Path(os.environ["WORK_DIR"])

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

pom_entries = []
for pom_path in sorted(repository_root.rglob("pom.xml")):
    if not pom_path.is_file():
        continue
    if {".git", "target", ".blitzy_runtime_w007", "node_modules"} & set(
        pom_path.parts
    ):
        continue
    relative_path = pom_path.relative_to(repository_root).as_posix()
    pom_entries.append(f"{relative_path}\0{sha256(pom_path)}\n")
pom_set_digest = hashlib.sha256("".join(pom_entries).encode("utf-8")).hexdigest()

with (work_dir / "npm-audit.json").open(encoding="utf-8") as handle:
    audit = json.load(handle)
with (work_dir / "frontend-sbom.json").open(encoding="utf-8") as handle:
    sbom = json.load(handle)
with (work_dir / "maven-osv-queries.json").open(encoding="utf-8") as handle:
    queries = json.load(handle)["queries"]
with (work_dir / "maven-osv-response.json").open(encoding="utf-8") as handle:
    results = json.load(handle)["results"]
with (work_dir / "maven-osv-advisories.json").open(encoding="utf-8") as handle:
    advisories = json.load(handle)["advisories"]

affected_coordinates = sum(bool(result.get("vulns")) for result in results)
metadata = {
    "captureDate": capture_date,
    "inputs": {
        "frontendPackageLockSha256": sha256(package_lock),
        "mavenPomCount": len(pom_entries),
        "mavenPomSetSha256": pom_set_digest,
    },
    "mavenOsv": {
        "advisoryCount": len(advisories),
        "affectedCoordinateCount": affected_coordinates,
        "coordinateCount": len(queries),
        "queryEndpoint": "https://api.osv.dev/v1/querybatch",
        "recordEndpoint": "https://api.osv.dev/v1/vulns/{id}",
    },
    "npmAudit": {
        "auditReportVersion": audit["auditReportVersion"],
        "dependencyCounts": audit["metadata"]["dependencies"],
        "vulnerabilityCounts": audit["metadata"]["vulnerabilities"],
    },
    "sbom": {
        "bomFormat": sbom["bomFormat"],
        "componentCount": len(sbom.get("components", [])),
        "dependencyEntryCount": len(sbom.get("dependencies", [])),
        "normalisation": {
            "serialNumber": "UUIDv5 of capture date and package-lock SHA-256",
            "timestamp": f"{capture_date}T00:00:00Z",
        },
        "serialNumber": sbom["serialNumber"],
        "specVersion": sbom["specVersion"],
    },
    "sources": {
        "npm": "npm registry audit endpoint selected by npm 10",
        "osv": "OSV.dev API",
    },
    "toolchain": {
        "curl": os.environ["CURL_VERSION"],
        "node": os.environ["NODE_VERSION"],
        "npm": os.environ["NPM_VERSION"],
        "python": os.environ["PYTHON_VERSION"],
    },
}
with (work_dir / "capture-metadata.json").open("w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

install -m 0644 "$WORK_DIR/npm-audit.json" "$OUTPUT_DIR/$AUDIT_FILE"
install -m 0644 "$WORK_DIR/frontend-sbom.json" "$OUTPUT_DIR/$SBOM_FILE"
install -m 0644 "$WORK_DIR/maven-osv-queries.json" "$OUTPUT_DIR/$OSV_QUERY_FILE"
install -m 0644 "$WORK_DIR/maven-osv-response.json" "$OUTPUT_DIR/$OSV_RESPONSE_FILE"
install -m 0644 "$WORK_DIR/maven-osv-advisories.json" "$OUTPUT_DIR/$OSV_ADVISORY_FILE"
install -m 0644 "$WORK_DIR/capture-metadata.json" "$OUTPUT_DIR/$METADATA_FILE"

(
    cd "$OUTPUT_DIR"
    sha256sum \
        "$AUDIT_FILE" \
        "$SBOM_FILE" \
        "$OSV_QUERY_FILE" \
        "$OSV_RESPONSE_FILE" \
        "$OSV_ADVISORY_FILE" \
        "$METADATA_FILE" > "$MANIFEST_FILE"
    sha256sum --check "$MANIFEST_FILE"
)

printf 'Captured advisory evidence in %s\n' "$OUTPUT_DIR"