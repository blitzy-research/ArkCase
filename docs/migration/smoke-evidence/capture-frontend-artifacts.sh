#!/bin/bash
# capture-frontend-artifacts.sh — build the MIGRATED frontend the way the migration's
# own acceptance step builds it, from a clean extraction of a commit, and print the
# digests of the five pipeline artifacts.
#
# WHY A SEPARATE PROGRAM FROM THE HISTORICAL CAPTURE.  Its sibling
# historical-frontend/capture-historical-frontend.sh builds the base-commit tree with
# the superseded package manager, parameterised by Node line.  This one builds the
# committed tree with the package manager the migration moved to, restoring from the
# committed lockfile.  Keeping them apart is deliberate: the install command, the
# lockfile and the build entry point are all different, and one program with a mode
# switch would obscure exactly the differences the comparison is about.
#
# WHAT IT REPRODUCES.  The acceptance step for the frontend is
#
#     nvm use 20; git clean -xfd <frontend> && cd <frontend> && npm ci && npm run build
#
# and this script performs the same three things on a tree extracted with git archive,
# which is a stronger form of the clean step than `git clean` — an extraction cannot
# retain an untracked file at all, so nothing the build needs can survive by accident.
# That matters here: the pipeline requires a generated configuration module that was
# untracked at the base commit, and committing it is one of exactly two pre-existing
# conditions this migration repaired rather than documented.
#
# WHAT IS NOT ASSERTED.  Exit status is not the result and is not treated as one. The
# pipeline sets its forced-execution option, so a failing task still exits zero; the
# artifacts and their digests are the evidence, and both statuses are recorded beside
# them so a reader can see that they were not relied on.
#
# usage:  capture-frontend-artifacts.sh [staging-directory]
#
# environment:
#   NVM_DIR   an nvm installation; defaults to $HOME/.nvm
#   BUILD_REF the commit to extract; defaults to HEAD of the checkout this lives in
#   NODE_LINE the Node major line to build on; defaults to 20, the migration target
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
FE_REL='acm-standard-applications/arkcase/src/main/webapp/resources'
NODE_LINE="${NODE_LINE:-20}"

REPO="$(cd "$HERE" && git rev-parse --show-toplevel 2>/dev/null)" || REPO=''
if [ -z "$REPO" ]; then
    printf 'capture-frontend-artifacts.sh: not inside a git repository.\n' >&2
    printf '  The tree is extracted with git archive, so the script has to run from a\n' >&2
    printf '  checkout that contains the commit being built.\n' >&2
    exit 2
fi

BUILD_REF="${BUILD_REF:-HEAD}"
BUILD_SHA="$(git -C "$REPO" rev-parse --verify "${BUILD_REF}^{commit}" 2>/dev/null)" || {
    printf 'capture-frontend-artifacts.sh: %s is not a commit in %s\n' "$BUILD_REF" "$REPO" >&2
    exit 2
}

STAGE="${1:-}"
if [ -z "$STAGE" ]; then
    STAGE="$(mktemp -d "${TMPDIR:-/tmp}/arkcase-migrated-frontend.XXXXXX")" || exit 2
fi
mkdir -p "$STAGE" || exit 2
STAGE="$(cd "$STAGE" && pwd)"
printf 'staging directory: %s\n' "$STAGE"

export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
if [ ! -s "${NVM_DIR}/nvm.sh" ]; then
    printf 'capture-frontend-artifacts.sh: no nvm at %s\n' "$NVM_DIR" >&2
    printf '  The acceptance step selects the runtime with nvm, so the capture does too.\n' >&2
    exit 2
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh" > /dev/null
nvm use "$NODE_LINE" > /dev/null 2>&1 \
    || { nvm install "$NODE_LINE" > /dev/null 2>&1 && nvm use "$NODE_LINE" > /dev/null 2>&1; }
if ! node --version 2>/dev/null | grep -q "^v${NODE_LINE}\."; then
    printf 'capture-frontend-artifacts.sh: node is %s, not the v%s line.\n' \
        "$(node --version 2>/dev/null || echo 'unavailable')" "$NODE_LINE" >&2
    printf '  A build on the wrong runtime answers a different question than the one asked.\n' >&2
    exit 2
fi
export CI=true

{
    printf '=== runtime this capture built on ===\n'
    printf 'requested-node-line: %s\n' "$NODE_LINE"
    node --version
    npm --version
    printf 'tree-built: %s\n' "$BUILD_SHA"
    printf 'package-manager: npm, restoring from the committed lockfile\n'
} > "${STAGE}/toolchain.txt" 2>&1

git -C "$REPO" archive "$BUILD_SHA" "$FE_REL" | tar -x -C "$STAGE" || exit 2
FE="${STAGE}/${FE_REL}"
[ -d "$FE" ] || { printf 'extraction produced no %s\n' "$FE" >&2; exit 2; }

cd "$FE" || exit 2

# The two files the acceptance step depends on being TRACKED are asserted here rather
# than created.  An extraction carries only tracked content, so if either is missing
# the build cannot start — and a capture that quietly wrote them itself would hide the
# very condition the migration had to repair.
for needed in package-lock.json profiles.js; do
    if [ ! -f "$needed" ]; then
        printf 'capture-frontend-artifacts.sh: %s is not tracked at %s\n' "$needed" "$BUILD_SHA" >&2
        printf '  The acceptance step deletes every untracked file before installing, so a\n' >&2
        printf '  build input that is not committed cannot survive it.  Refusing to fabricate\n' >&2
        printf '  it here: that would hide the condition instead of recording it.\n' >&2
        exit 2
    fi
done

npm ci > "${STAGE}/install.log" 2>&1
printf 'install-exit=%s\n' "$?" > "${STAGE}/install.status"

npm run build > "${STAGE}/build.log" 2>&1
printf 'build-exit=%s\n' "$?" > "${STAGE}/build.status"

{
    printf '=== artifact digests, committed tree built with npm ci on the Node %s line ===\n' "$NODE_LINE"
    for f in assets/dist/application.js assets/dist/application.min.js \
             assets/dist/vendors.min.js assets/dist/application.min.css home.html
    do
        if [ -f "$f" ]; then
            printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"
        else
            printf '%-64s  %s (ABSENT)\n' 'MISSING' "$f"
        fi
    done
    printf '=== the advisory source map, digested but outside the five ===\n'
    if [ -f assets/dist/application.min.js.map ]; then
        printf '%s  %s\n' "$(sha256sum assets/dist/application.min.js.map | cut -d' ' -f1)" \
            'assets/dist/application.min.js.map'
    else
        printf '%-64s  %s (ABSENT)\n' 'MISSING' 'assets/dist/application.min.js.map'
    fi
    printf '=== cache-busted names produced ===\n'
    ls -1 assets/dist/ 2>/dev/null
} | tee "${STAGE}/artifacts.txt"

printf '\nlogs, status files and the staged tree are under %s\n' "$STAGE"
printf 'exit statuses are recorded in install.status and build.status and are NOT the result:\n'
printf 'the pipeline forces past task failures, so the digests above are the evidence.\n'
printf 'done\n' > "${STAGE}/COMPLETE"
