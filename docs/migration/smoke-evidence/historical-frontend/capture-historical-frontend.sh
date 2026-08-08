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
#   NVM_DIR    an nvm installation; defaults to $HOME/.nvm
#   BASE_REF   the commit to extract; defaults to the base commit of the migration
#   NODE_LINE  the Node major line to build on; defaults to 8, the historical line
#
# WHY NODE_LINE EXISTS, AND WHY IT MATTERS MORE THAN IT LOOKS.  Two of the five
# artifacts differ between the historical build and the migrated one, and the whole
# weight of the attribution rests on a THIRD build that holds the runtime constant
# while varying only the package manager, the lockfile and the specification form:
#
#   A  base-commit tree, yarn,          Node  8   NODE_LINE=8   (the default)
#   B  base-commit tree, yarn,          Node 20   NODE_LINE=20
#   C  migrated tree,    npm ci,        Node 20   capture-frontend-artifacts.sh
#
# B and C agreeing on all five artifacts is what eliminates the package-manager
# change, the lockfile and the manifest rewrite as causes and leaves the runtime as
# the only remaining variable.  An earlier revision of this evidence performed build B
# but committed no program that reproduces it, so the single most load-bearing step in
# the attribution was the one step a reader could not repeat.  One parameter fixes
# that: the same program produces A and B, so they differ in the runtime and in
# nothing else -- which is exactly the claim being made.
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
NODE_LINE="${NODE_LINE:-8}"
case "$NODE_LINE" in
    ''|*[!0-9]*)
        printf 'capture-historical-frontend.sh: NODE_LINE must be a Node major line, got %s\n' "$NODE_LINE" >&2
        exit 2 ;;
esac
nvm use "$NODE_LINE" > /dev/null 2>&1 \
    || { nvm install "$NODE_LINE" > /dev/null 2>&1 && nvm use "$NODE_LINE" > /dev/null 2>&1; }
if ! node --version 2>/dev/null | grep -q "^v${NODE_LINE}\."; then
    printf 'capture-historical-frontend.sh: node is %s, not the v%s line.\n' \
        "$(node --version 2>/dev/null || echo 'unavailable')" "$NODE_LINE" >&2
    printf '  The runtime is the variable this capture exists to isolate, so building on\n' >&2
    printf '  a runtime other than the one asked for would silently answer a different\n' >&2
    printf '  question than the one the caller posed.\n' >&2
    exit 2
fi
export CI=true

{
    printf '=== runtime this capture built on ===\n'
    printf 'requested-node-line: %s\n' "$NODE_LINE"
    node --version
    npm --version
    printf 'tree-built: %s (base commit of the migration unless BASE_REF was overridden)\n' "$BASE_REF"
    printf 'package-manager: yarn, the one the base commit used\n'
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

# config/config.js requires ./../profiles, which is not tracked at the base commit; the
# deployed runtime writes it.  The build cannot start without it, so something has to
# supply it here.
#
# IT IS COPIED FROM THE TRACKED FILE RATHER THAN WRITTEN FROM A LITERAL, AND THAT IS THE
# WHOLE POINT.  profiles.js is a behaviour-bearing INPUT: config/config.js requires it and
# uses what it exports to add and remove entries from the asset lists the pipeline
# concatenates.  A comparison of two builds is only a comparison if their inputs are the
# same, and an earlier revision of this script wrote  profiles: [ 'custom' ]  from a literal
# while the migrated side built against the tracked default, whose array is EMPTY.  Two
# builds with two different values for a behaviour-bearing input do not isolate the runtime;
# they vary two things and attribute the result to one.  Copying the tracked file makes the
# input identical on both sides by construction, and its digest is recorded below so the
# claim is checkable rather than asserted.
#
# Using the migrated tree's tracked file to build the base-commit tree is not a
# contamination of the baseline: the base commit has no profiles.js at all, so ANY content
# used here is supplied by the harness rather than taken from that commit.  Given that, the
# only defensible choice is the content the other side of the comparison uses.
TRACKED_PROFILES="${REPO}/${FE_REL}/profiles.js"
if [ ! -f "$TRACKED_PROFILES" ]; then
    printf 'capture-historical-frontend.sh: no tracked profiles.js at %s\n' "$TRACKED_PROFILES" >&2
    printf '  It is the behaviour-bearing build input both sides must share.  Without it this\n' >&2
    printf '  capture would have to invent one, and the comparison would vary two things.\n' >&2
    exit 2
fi
cp "$TRACKED_PROFILES" profiles.js

# Every behaviour-bearing input of this build, recorded with its digest where it has one, so
# that the two sides of the comparison can be shown to have received the same inputs instead
# of being assumed to have.  The migrated side records the same fields under
# notes/frontend-comparison-provenance.txt.
{
    echo "=== behaviour-bearing build inputs, historical side ==="
    printf 'profiles-js-sha256: %s\n'   "$(sha256sum profiles.js   | cut -d' ' -f1)"
    printf 'profiles-js-bytes: %s\n'    "$(wc -c < profiles.js | tr -d ' ')"
    printf 'profiles-js-source: the tracked %s of the migrated tree, copied verbatim\n' "${FE_REL}/profiles.js"
    printf 'manifest-sha256: %s\n'      "$(sha256sum package.json  | cut -d' ' -f1)"
    printf 'lockfile-name: yarn.lock\n'
    printf 'lockfile-sha256: %s\n'      "$(sha256sum yarn.lock     | cut -d' ' -f1)"
    printf 'gruntfile-sha256: %s\n'     "$(sha256sum Gruntfile.js  | cut -d' ' -f1)"
    printf 'asset-config-sha256: %s\n'  "$(sha256sum config/env/all.js | cut -d' ' -f1)"
    printf 'NODE_ENV: %s\n'             "${NODE_ENV-(unset)}"
    printf 'NODE_APP_INSTANCE: %s\n'    "${NODE_APP_INSTANCE-(unset)}"
    printf 'build-working-directory: %s\n' "$(pwd)"
    printf 'build-relative-path-within-tree: %s\n' "$FE_REL"
    printf 'dist-directory-clean-before-build: %s\n' \
        "$( [ -e assets/dist ] && echo 'no - assets/dist existed' || echo 'yes - assets/dist absent' )"
} | tee "${STAGE}/build-inputs.txt"

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
    printf '=== artifact digests, base-commit tree built with yarn on the Node %s line ===\n' "$NODE_LINE"
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

if [ "$NODE_LINE" = '8' ]; then
    printf '\ncompare the table above against %s\n' "${HERE}/artifact-digests-node8.txt"
else
    printf '\ncompare the table above against %s\n' "${HERE}/artifact-digests-node20-basecommit-yarn.txt"
fi
printf 'logs, status files and the staged tree are under %s\n' "$STAGE"
printf 'done\n' > "${STAGE}/COMPLETE"
