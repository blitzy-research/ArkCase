#!/bin/bash
# Reproduce the HISTORICAL frontend build: the base-commit tree, built with the
# superseded package manager on the historical Node line, using exactly the install
# command the base-commit runtime wiring used, so the five pipeline artifacts can be
# compared against the migrated build.
#
# THIS SCRIPT WRITES NOTHING INTO THE COMMITTED EVIDENCE.  An earlier revision wrote
# its logs and its digest table straight into the directory it lives in, which meant
# running it destroyed the very capture it was committed to let a reader verify, and
# it also required the base-commit tree to have been extracted beside it by hand.  It
# now extracts the tree itself into a staging directory and writes everything there,
# printing the digest table to standard output.  A reproduction script that damages
# the evidence on being run is not a reproduction script.
#
# usage:  capture-historical-frontend.sh [staging-directory]
#   staging-directory  defaults to a fresh mkdtemp directory, whose path is printed.
#
# environment:
#   NVM_DIR   an nvm installation; defaults to $HOME/.nvm
#   BASE_REF  the commit to extract; defaults to the base commit of the migration
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
BASE_REF="${BASE_REF:-c8f6226105c28c2743281d26bf21ad73f7bb7f26}"
FE_REL='acm-standard-applications/arkcase/src/main/webapp/resources'

# The repository this script was committed into, found by walking up from its own
# location rather than assuming the caller's working directory.
REPO="$(cd "$HERE" && git rev-parse --show-toplevel 2>/dev/null)" || REPO=''
if [ -z "$REPO" ]; then
    printf 'capture-historical-frontend.sh: not inside a git repository.\n' >&2
    printf '  The base-commit tree is extracted with git archive, so the script has to\n' >&2
    printf '  run from a checkout that contains the base commit.\n' >&2
    exit 2
fi
if ! git -C "$REPO" cat-file -e "${BASE_REF}^{commit}" 2>/dev/null; then
    printf 'capture-historical-frontend.sh: %s is not a commit in %s\n' "$BASE_REF" "$REPO" >&2
    printf '  Set BASE_REF to the base commit of the migration, or fetch it.\n' >&2
    exit 2
fi

STAGE="${1:-}"
if [ -z "$STAGE" ]; then
    STAGE="$(mktemp -d "${TMPDIR:-/tmp}/arkcase-historical-frontend.XXXXXX")" || exit 2
fi
mkdir -p "$STAGE" || exit 2
STAGE="$(cd "$STAGE" && pwd)"
printf 'staging directory: %s\n' "$STAGE"

# NVM_DIR is honoured if the caller already exports it and defaults to the
# conventional per-user location otherwise, so this script does not hard-code the
# home directory of the machine that first ran it.  An absolute path baked into a
# reproduction script is the reason the script cannot be re-run anywhere else, which
# defeats the point of committing it beside the evidence.
export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
    printf 'capture-historical-frontend.sh: no nvm at %s\n' "$NVM_DIR" >&2
    printf '  Set NVM_DIR to an nvm installation, or install nvm, then rerun.\n' >&2
    printf '  The historical Node line has to come from somewhere: this capture is only\n' >&2
    printf '  meaningful if the build runs on the runtime the base commit used.\n' >&2
    exit 2
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh" > /dev/null
nvm use 8 > /dev/null 2>&1 || { nvm install 8 > /dev/null 2>&1 && nvm use 8 > /dev/null 2>&1; }
if ! node --version 2>/dev/null | grep -q '^v8\.'; then
    printf 'capture-historical-frontend.sh: node is %s, not the v8 line.\n' \
        "$(node --version 2>/dev/null || echo 'unavailable')" >&2
    printf '  Building on any other runtime would make this capture the same\n' >&2
    printf '  measurement as the migrated one, which is the gap it exists to close.\n' >&2
    exit 2
fi
export CI=true

{
    echo "=== historical runtime ==="
    node --version
    npm --version
} > "${STAGE}/toolchain.txt" 2>&1

# Only the frontend subtree is extracted: nothing else in the base commit
# participates in this build, and extracting 145 modules to read one directory
# would make the staging cost pointless.
git -C "$REPO" archive "$BASE_REF" "$FE_REL" | tar -x -C "$STAGE" || exit 2
FE="${STAGE}/${FE_REL}"
[ -d "$FE" ] || { printf 'extraction produced no %s\n' "$FE" >&2; exit 2; }

# The package manager the base commit used, at the version the capture recorded.
npm install -g yarn@1.22.22 > "${STAGE}/yarn-install.log" 2>&1
echo "yarn-bootstrap-exit=$?" >> "${STAGE}/toolchain.txt"
yarn --version >> "${STAGE}/toolchain.txt" 2>&1

cd "$FE" || exit 2

# config/config.js requires ./../profiles, which is not tracked at the base commit;
# the deployed runtime writes it.  Written here with exactly the content that writer
# emits, otherwise the build cannot start at all.  This is one of the two
# escape-clause invocations recorded in the pre-existing-defects register.
printf 'module.exports = { profiles: [ %s ] };' "'custom'" > profiles.js

yarn --skip-integrity-check --ignore-engines --no-progress --non-interactive install \
    > "${STAGE}/install.log" 2>&1
echo "install-exit=$?" > "${STAGE}/install.status"

./node_modules/.bin/grunt --no-color > "${STAGE}/build.log" 2>&1
echo "build-exit=$?" > "${STAGE}/build.status"

# The digest table goes to standard output as well as to the staging directory, so a
# reader can compare it against the committed artifact-digests-node8.txt by eye
# without opening anything.  Neither exit status above is treated as the result: the
# Gruntfile forces its way past task failures, so the artifacts are the evidence.
{
    echo "=== artifact digests, historical Node build ==="
    for f in assets/dist/application.js assets/dist/application.min.js \
             assets/dist/vendors.min.js assets/dist/application.min.css home.html
    do
        if [ -f "$f" ]; then
            printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"
        else
            printf '%-64s  %s (ABSENT)\n' 'MISSING' "$f"
        fi
    done
    echo "=== cache-busted names produced ==="
    ls -1 assets/dist/ 2>/dev/null
} | tee "${STAGE}/artifacts.txt"

printf '\ncompare the table above against %s\n' "${HERE}/artifact-digests-node8.txt"
printf 'logs, status files and the staged tree are under %s\n' "$STAGE"
echo done > "${STAGE}/COMPLETE"
