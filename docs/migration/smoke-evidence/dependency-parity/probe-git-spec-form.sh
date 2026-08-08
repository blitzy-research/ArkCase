#!/bin/bash
#
# probe-git-spec-form.sh — re-measure, one entry at a time, whether each frontend Git
# dependency that is expressed as a commit-archive URL could instead be expressed in the
# prescribed  owner/repo#<40-hex commit>  form.
#
# WHY THIS EXISTS
#   The migration plan prescribes exactly one representation for the 76 Git dependencies in
#   the frontend manifest: owner/repo followed by an exact 40-character commit.  Fifty-eight
#   use it.  The remaining eighteen use a commit-archive URL that carries the identical
#   commit in its path, and a reviewer is entitled to ask whether that is a necessity or a
#   preference.  A rule applied to a group is not a justification for any member of it, so
#   this script settles it per entry, by execution, and writes down what npm actually did.
#
#   It replaces an argument with a measurement.  Nothing here is inferred: every verdict
#   below comes from an npm exit status and, where npm succeeded, from comparing the files
#   the two representations actually deliver.
#
# WHAT IT MEASURES, AND WHY BOTH HALVES ARE NEEDED
#   1. RESOLUTION.  For each entry, declare that single dependency in the prescribed form in
#      an otherwise empty project and run  npm install --package-lock-only.  An entry that
#      cannot resolve cannot use the form, and the reason npm gives is recorded verbatim.
#   2. DELIVERED BYTES.  An entry that DOES resolve is not thereby safe.  Resolving a Git
#      specification makes npm clone, prepare and pack the repository, and packing applies
#      the cloned manifest's own file allowlist and its own generated output — so the tree
#      npm delivers can differ from the commit the specification pins.  For every entry that
#      resolves, this script performs a full install of BOTH representations and compares the
#      delivered file sets and the digests of the files the frozen asset layout names.
#
#   Half 1 alone would report those entries as convertible.  They are not.
#
# SCOPE FENCE
#   Read-only with respect to the repository.  It reads the manifest and the asset-layout
#   configuration, and writes everything else into a staging directory the caller names.  It
#   never writes into the repository, never installs anything globally, and changes no
#   dependency.  Running it cannot damage the evidence it exists to let a reader check.
#
# USAGE
#   docs/migration/smoke-evidence/dependency-parity/probe-git-spec-form.sh [staging-directory]
#
#   Requires Node 20 with npm 10 on PATH and network access to the registry and to GitHub.
#   Default staging directory: a fresh mktemp -d, whose path is printed.
#
# READ THE RESULT TOGETHER WITH
#   git-spec-form-probe.txt                        the recorded output of a real run
#   docs/migration/dependency-change-inventory.md  the per-entry record this evidence backs
#   docs/migration/ambiguity-resolutions.md        entry 3, the decision and its alternatives

set -u

STAGE="${1:-$(mktemp -d)}"
mkdir -p "$STAGE" || exit 2

# Locate the repository root from this script's own position, so the script works from any
# working directory and hard-codes no absolute path.
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../../.." && pwd)"
FE="${REPO_ROOT}/acm-standard-applications/arkcase/src/main/webapp/resources"
MANIFEST="${FE}/package.json"
ASSETS="${FE}/config/env/all.js"

[ -f "$MANIFEST" ] || { printf 'manifest not found: %s\n' "$MANIFEST" >&2; exit 2; }
[ -f "$ASSETS" ]   || { printf 'asset configuration not found: %s\n' "$ASSETS" >&2; exit 2; }

REPORT="${STAGE}/git-spec-form-probe.txt"

{
    printf 'probing whether the commit-archive entries could take the prescribed owner/repo#<commit> form\n'
    printf '=====================================================================================\n\n'
    printf 'PROVENANCE\n'
    printf '  node          %s\n' "$(node --version 2>&1)"
    printf '  npm           %s\n' "$(npm --version 2>&1)"
    printf '  manifest      acm-standard-applications/arkcase/src/main/webapp/resources/package.json\n'
    printf '  asset layout  acm-standard-applications/arkcase/src/main/webapp/resources/config/env/all.js\n'
    printf '  probe         one dependency per otherwise empty project, prescribed form,\n'
    printf '                npm install --package-lock-only; then a full install of BOTH forms\n'
    printf '                for every entry that resolves\n\n'
} > "$REPORT"

# Extract the commit-archive entries out of the manifest with a JSON parser rather than by
# pattern-matching the file, so a reformatted manifest cannot change what is probed.
node -e '
const fs = require("fs");
const deps = JSON.parse(fs.readFileSync(process.argv[1], "utf8")).dependencies || {};
const re = /^https:\/\/codeload\.github\.com\/([^\/]+)\/([^\/]+)\/tar\.gz\/([0-9a-f]{40})$/;
for (const [key, spec] of Object.entries(deps)) {
    const m = re.exec(spec);
    if (m) process.stdout.write([key, m[1] + "/" + m[2], m[3]].join("\t") + "\n");
}
' "$MANIFEST" > "${STAGE}/entries.tsv"

total="$(wc -l < "${STAGE}/entries.tsv" | tr -d ' ')"
printf 'ENTRIES PROBED: %s\n\n' "$total" >> "$REPORT"

resolved_count=0
blocked_count=0
differing_count=0
convertible_count=0

while IFS="$(printf '\t')" read -r key repo commit; do
    [ -n "${key:-}" ] || continue
    safe="$(printf '%s' "$key" | tr -c 'A-Za-z0-9._-' '_')"

    # ---- half 1: can the prescribed form resolve at all? ----
    plain_dir="${STAGE}/resolve/${safe}"
    rm -rf "$plain_dir"; mkdir -p "$plain_dir"
    node -e '
const fs = require("fs");
fs.writeFileSync(process.argv[1], JSON.stringify({
    name: "git-spec-form-probe", version: "1.0.0", private: true,
    dependencies: { [process.argv[2]]: process.argv[3] + "#" + process.argv[4] }
}));
' "${plain_dir}/package.json" "$key" "$repo" "$commit"
    ( cd "$plain_dir" && npm install --package-lock-only --no-audit --no-fund ) \
        > "${plain_dir}/npm.log" 2>&1
    plain_status=$?

    reason="$(LC_ALL=C grep -m1 -oE 'Could not read package.json|git dep preparation failed' \
        "${plain_dir}/npm.log" 2>/dev/null)"

    if [ "$plain_status" -ne 0 ]; then
        blocked_count=$((blocked_count + 1))
        printf '%-52s BLOCKED   exit %-4s %s\n' "$key" "$plain_status" "${reason:-see npm.log}" >> "$REPORT"
        continue
    fi

    resolved_count=$((resolved_count + 1))

    # ---- half 2: does it deliver the pinned bytes? ----
    # A full install of each representation, then a comparison of the delivered file sets and
    # of the digests of the paths the frozen asset layout names for this package.
    verdict='SAME-BYTES'
    detail=''
    for form in plain archive; do
        d="${STAGE}/install/${safe}.${form}"
        rm -rf "$d"; mkdir -p "$d"
        if [ "$form" = plain ]; then spec="${repo}#${commit}"
        else spec="https://codeload.github.com/${repo}/tar.gz/${commit}"; fi
        node -e '
const fs = require("fs");
fs.writeFileSync(process.argv[1], JSON.stringify({
    name: "git-spec-form-probe", version: "1.0.0", private: true,
    dependencies: { [process.argv[2]]: process.argv[3] }
}));
' "${d}/package.json" "$key" "$spec"
        ( cd "$d" && npm install --no-audit --no-fund ) > "${d}/npm.log" 2>&1
        ( cd "${d}/node_modules/${key}" 2>/dev/null \
            && find . -type f ! -path './node_modules/*' -print0 \
               | LC_ALL=C sort -z | xargs -0 -r sha256sum ) > "${d}/tree.sha256" 2>/dev/null
    done

    if ! cmp -s "${STAGE}/install/${safe}.plain/tree.sha256" \
                "${STAGE}/install/${safe}.archive/tree.sha256"; then
        verdict='DIFFERENT-BYTES'
        differing_count=$((differing_count + 1))
        # Name the asset-layout paths this affects, because a difference the frozen layout
        # never reads would be a different finding from one it does.
        detail="$(node -e '
const fs = require("fs");
const key = process.argv[2];
const text = fs.readFileSync(process.argv[1], "utf8");
const re = new RegExp("node_modules/" + key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "/[^\x27\x22]+", "g");
const hits = Array.from(new Set(text.match(re) || []));
process.stdout.write(hits.length ? hits.join(" ") : "(no literal asset path names this package)");
' "$ASSETS" "$key")"
    else
        convertible_count=$((convertible_count + 1))
    fi

    printf '%-52s RESOLVES  %s\n' "$key" "$verdict" >> "$REPORT"
    [ -n "$detail" ] && printf '%-52s   asset paths affected: %s\n' '' "$detail" >> "$REPORT"
done < "${STAGE}/entries.tsv"

{
    printf '\nTALLY\n'
    printf '  entries probed                                  %s\n' "$total"
    printf '  cannot resolve in the prescribed form            %s\n' "$blocked_count"
    printf '  resolve, but deliver different bytes             %s\n' "$differing_count"
    printf '  resolve AND deliver identical bytes              %s\n' "$convertible_count"
    printf '\n'
    printf 'READING THE TALLY.  Only the last line counts as convertible.  An entry that\n'
    printf 'resolves while delivering different bytes is not convertible: the asset layout\n'
    printf 'names literal installed paths, so a changed or missing file reaches the built\n'
    printf 'bundles while the build still exits zero.\n'
    printf '\nStaging directory retained for inspection: %s\n' "$STAGE"
} >> "$REPORT"

cat "$REPORT"
printf '\nreport written to %s\n' "$REPORT"
