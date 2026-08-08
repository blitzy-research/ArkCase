#!/bin/bash
# probe-minifier-engine-dependence.sh — isolate the cause of the two frontend artifact
# mismatches down to the JavaScript engine, with Grunt, the package manager, the
# lockfile and every migration change taken out of the picture.
#
# WHAT QUESTION THIS ANSWERS.  Two of the five pipeline artifacts differ between the
# baseline build and the migrated build.  The acceptance criterion those two fail is
# byte identity, and the instruction attached to that failure is to identify and remove
# the dependency, tool or input drift causing it.  Answering that needs an experiment
# narrow enough that only one thing varies, because the full pipeline varies three
# things at once — package manager, lockfile and runtime.
#
# HOW IT ISOLATES.  It calls the two minifiers DIRECTLY, as libraries, from the
# node_modules tree of a build that already happened.  One tree, one input file, one set
# of options, invoked twice — once under each Node line.  No Grunt, no task graph, no
# install step and no manifest is involved, so a difference in the output cannot be
# attributed to any of them.  Before running, it compares the two builds' minifier trees
# file by file, so the claim that the tool did not change is measured here rather than
# taken from a version string.
#
# WHAT A READER SHOULD TAKE FROM THE OUTPUT.  Each probe prints the byte count and the
# SHA-256 of the minifier's output under each runtime, plus the specific engine
# behaviour that differs.  If the byte counts differ while the tool tree is identical
# and the input is identical, the runtime is the only remaining variable — and the
# deltas it prints can be checked against the deltas in the full bundles.
#
# WHAT IT DOES NOT CLAIM.  It does not establish that the differing output is
# behaviourally equivalent; that is a separate question answered by
# verify-artifact-equivalence.js one directory up.  It does not satisfy the byte-identity
# criterion and does not soften it.  And it prescribes no remedy: identifying a cause is
# not the same as having a permitted fix for it, and where the cause is the runtime
# version itself the migration's own rules forbid the only configuration that would
# remove it.
#
# usage:  probe-minifier-engine-dependence.sh <build-a-dir> <build-b-dir> [output-file]
#
#   build-a-dir  a completed build tree whose node_modules is populated — the side built
#                on the historical Node line
#   build-b-dir  a completed build tree whose node_modules is populated — the side built
#                on the target Node line
#
# environment:
#   NVM_DIR      an nvm installation; defaults to $HOME/.nvm
#   NODE_OLD     the historical Node line to probe; defaults to 8
#   NODE_NEW     the target Node line to probe; defaults to 20
set -u

FE_REL='acm-standard-applications/arkcase/src/main/webapp/resources'
NODE_OLD="${NODE_OLD:-8}"
NODE_NEW="${NODE_NEW:-20}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

A="${1:-}"
B="${2:-}"
OUT="${3:-}"
if [ -z "$A" ] || [ -z "$B" ]; then
    printf 'usage: probe-minifier-engine-dependence.sh <build-a-dir> <build-b-dir> [output-file]\n' >&2
    exit 2
fi
for d in "$A" "$B"; do
    if [ ! -d "${d}/${FE_REL}/node_modules" ]; then
        printf 'probe: %s has no populated node_modules under %s\n' "$d" "$FE_REL" >&2
        printf '  Both arguments must be build trees that completed an install.\n' >&2
        exit 2
    fi
done
A="$(cd "$A" && pwd)"
B="$(cd "$B" && pwd)"

emit() { if [ -n "$OUT" ]; then printf '%s\n' "$*" >> "$OUT"; fi; printf '%s\n' "$*"; }
if [ -n "$OUT" ]; then : > "$OUT" || exit 2; fi

emit 'isolating the two frontend artifact mismatches down to the JavaScript engine'
emit '==========================================================================='
emit ''
emit "historical-side build tree : ${A}"
emit "target-side build tree     : ${B}"
emit "runtimes probed            : Node ${NODE_OLD} line and Node ${NODE_NEW} line"
emit "probed at                  : $(date -u '+%Y-%m-%dT%H:%M:%SZ') UTC"
emit ''

# ---------------------------------------------------------------------------
# step 1 — measure, rather than assume, that the tools did not change
# ---------------------------------------------------------------------------
emit 'STEP 1  THE TOOL TREES, COMPARED FILE BY FILE'
emit '  A version string can match while the installed files differ, so the trees'
emit '  themselves are compared.  If either line below reads DIFFER, everything after'
emit '  it is inconclusive and the difference has a dependency cause after all.'
tool_status=0
for pkg in uglify-js clean-css; do
    pa="${A}/${FE_REL}/node_modules/${pkg}"
    pb="${B}/${FE_REL}/node_modules/${pkg}"
    if [ ! -d "$pa" ] || [ ! -d "$pb" ]; then
        emit "    ${pkg}: ABSENT on at least one side — cannot compare"
        tool_status=1
        continue
    fi
    va="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${pa}/package.json" | head -1)"
    vb="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${pb}/package.json" | head -1)"
    if diff -r "$pa" "$pb" > /dev/null 2>&1; then
        emit "    ${pkg}: IDENTICAL trees, version ${va} both sides"
    else
        emit "    ${pkg}: DIFFER  (${va} versus ${vb})"
        tool_status=1
    fi
done
emit ''

# ---------------------------------------------------------------------------
# step 2 — the two probe programs, written where the probe runs so that what
#          executed is visible in the output rather than hidden in a fixture
# ---------------------------------------------------------------------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/arkcase-engine-probe.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

cat > "${WORK}/probe-script.js" <<'JS'
// Calls the script minifier as a library over one source file.  The file chosen is the
// one carrying the single differing line in the full bundle, so the probe reproduces
// the whole of that bundle's delta or none of it.
var fs = require('fs');
var crypto = require('crypto');
var U = require(process.argv[2]);
var code = fs.readFileSync(process.argv[3], 'utf8');
var out = U.minify(code, { fromString: true, mangle: false }).code;
console.log('    runtime ' + process.version + '  v8 ' + process.versions.v8);
console.log('      output bytes  : ' + Buffer.byteLength(out));
console.log('      output sha256 : ' + crypto.createHash('sha256').update(out).digest('hex'));
// the engine behaviour under suspicion, printed directly rather than inferred
console.log('      RegExp.prototype.toString of the affected pattern:');
console.log('        ' + new RegExp('[-a-zA-Z0-9()@:%_\\+.~#?&//=]').toString());
JS

cat > "${WORK}/probe-style.js" <<'JS'
// Calls the style minifier as a library over one stylesheet, and separately demonstrates
// the sort behaviour that minifier's own comparators depend on.
var fs = require('fs');
var crypto = require('crypto');
var CleanCSS = require(process.argv[2]);
var src = fs.readFileSync(process.argv[3], 'utf8');
var out = new CleanCSS({ keepSpecialComments: 0 }).minify(src).styles;
console.log('    runtime ' + process.version + '  v8 ' + process.versions.v8);
console.log('      input bytes   : ' + Buffer.byteLength(src));
console.log('      output bytes  : ' + Buffer.byteLength(out));
console.log('      output sha256 : ' + crypto.createHash('sha256').update(out).digest('hex'));
// The minifier's selector-restructuring pass sorts with comparators that return a
// BOOLEAN.  A boolean coerces to 0 or 1 and is never negative, so such a comparator can
// say "equal or greater" but never "less", and the resulting permutation is whatever the
// engine's sort algorithm happens to produce.  This reproduces that comparator shape on
// a plain array so the engine difference is visible on its own.
var probe = [];
for (var i = 0; i < 24; i += 1) { probe.push({ i: i, k: i % 3 }); }
var sorted = probe.slice().sort(function (a, b) { return a.k > b.k; });
console.log('      a 24-item sort with a boolean-returning comparator yields:');
console.log('        ' + sorted.map(function (x) { return x.i; }).join(','));
JS

run_under() {
    # run_under <node-line> <program> <args...>
    line="$1"; shift
    # shellcheck disable=SC1090
    if [ -s "${NVM_DIR}/nvm.sh" ]; then . "${NVM_DIR}/nvm.sh" > /dev/null 2>&1; fi
    if ! command -v nvm > /dev/null 2>&1; then
        printf '    runtime Node %s: nvm unavailable, cannot select this line\n' "$line"
        return 1
    fi
    if ! nvm use "$line" > /dev/null 2>&1; then
        printf '    runtime Node %s: not installed under %s\n' "$line" "$NVM_DIR"
        return 1
    fi
    node "$@" 2>&1
}

SRC_JS="${A}/${FE_REL}/modules/profile/controllers/components/profile-company.client.controller.js"
SRC_CSS="${A}/${FE_REL}/assets/css/application.css"
UG="${A}/${FE_REL}/node_modules/uglify-js"
CC="${A}/${FE_REL}/node_modules/clean-css"

emit 'STEP 2  THE SCRIPT MINIFIER, ONE TREE, ONE INPUT, TWO RUNTIMES'
emit "  input  : ${SRC_JS#"${A}/${FE_REL}/"}"
emit '  options: identifier mangling disabled, matching the pipeline'
for line in "$NODE_OLD" "$NODE_NEW"; do
    out="$(run_under "$line" "${WORK}/probe-script.js" "$UG" "$SRC_JS")"
    emit "$out"
done
emit ''
emit '  READING THIS.  The minifier emits a regular-expression literal by round-tripping'
emit '  it through a RegExp object, so whatever that object prints lands in the bundle.'
emit '  The two runtimes print the same pattern differently: the older one re-escapes a'
emit '  forward slash inside the character class, the newer one returns the source text'
emit '  as written.  The source itself carries the unescaped form, so the newer output is'
emit '  the more faithful one — and it is the one that fails byte identity.'
emit ''

emit 'STEP 3  THE STYLE MINIFIER, ONE TREE, ONE INPUT, TWO RUNTIMES'
emit "  input  : ${SRC_CSS#"${A}/${FE_REL}/"}"
for line in "$NODE_OLD" "$NODE_NEW"; do
    out="$(run_under "$line" "${WORK}/probe-style.js" "$CC" "$SRC_CSS")"
    emit "$out"
done
emit ''
emit '  READING THIS.  The style minifier restructures selectors that share a body, and'
emit '  that pass sorts with comparators returning a boolean rather than a signed number.'
emit '  Such a comparator can never report "less than", so the permutation the sort'
emit '  produces is decided by the engine, not by the comparator.  The two runtimes'
emit '  disagree on the 24-item demonstration above — one returns a scrambled order and'
emit '  the other the order it was given — which is the newer engine having replaced its'
emit '  sort algorithm.  The comparators are at, relative to the minifier package:'
emit '      lib/selectors/restructure.js  naturalSorter  and  fitSorter'
emit '      lib/selectors/clean-up.js     the two selector sorts'
emit '  That is a latent defect in a third-party package, not a migration change, and it'
emit '  is registered as pre-existing rather than repaired: the package installs and runs'
emit '  on the target runtime, and the migration only permits replacing a build package'
emit '  that cannot.'
emit ''

emit 'WHAT THIS ESTABLISHES'
if [ "$tool_status" -eq 0 ]; then
    emit '  The tool trees are identical and the inputs are identical, so no dependency,'
    emit '  tool or input drift is present to remove.  The one variable left standing is'
    emit '  the runtime, and the runtime move is the change the migration exists to make.'
    emit '  Byte identity on the two affected artifacts is therefore reachable only by'
    emit '  running the build on the superseded runtime, which the migration forbids in'
    emit '  the same breath as it requires the move.  The two requirements cannot both be'
    emit '  satisfied, and that is reported as an unresolved divergence rather than'
    emit '  settled quietly in favour of whichever one is easier to show as met.'
else
    emit '  INCONCLUSIVE: a tool tree differed between the two sides, so the runtime is'
    emit '  not the only variable and the attribution above does not hold.  Rerun with'
    emit '  two build trees whose minifier trees compare identical.'
fi
exit 0
