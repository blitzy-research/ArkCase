#!/usr/bin/env bash
#
# Derive the complete frontend advisory triage from the committed npm audit and the frozen
# asset contract, and publish it as a plain-text authority.
#
# WHY THIS EXISTS.  docs/migration/frontend-dependency-security.md previously reported a
# single figure of 101 "advisories" and enumerated only a selection of the Critical and High
# packages by hand.  Both were wrong in a way a reader could not detect: 101 is npm's count
# of vulnerable PACKAGE NODES, not of advisories -- there are 122 distinct advisories -- and
# a hand-written selection cannot be shown to be complete.  This script computes both counts
# and the full enumeration from the committed corpus so the page states derived figures.
#
# WHAT "REACHES THE BROWSER" MEANS HERE, since it is the column an owner acts on.  A package
# is served when the audit places it under node_modules/@bower_components/ AND its directory
# name appears in one of the literal node_modules/... paths that config/env/all.js resolves.
# That contract is frozen by the migration plan (R-T6), so the classification is a lookup
# against a fixed file rather than a judgement.
#
# It reads only committed inputs and needs no network.  It publishes atomically -- staged,
# checked, then renamed -- so a failed run leaves the previous authority byte-identical
# rather than truncated, and it fails closed when the emitted rows do not account for the
# audit's own severity counts.

set -euo pipefail

require_value()
{
    # $1 option name, $2 the caller's remaining argument count including the option itself.
    # Without this an option given no value consumed the next option as its value, or -- with
    # "${2:-}" and shift 2 -- shifted past the end and re-parsed forever.
    if [ "$2" -lt 2 ]; then
        printf 'triage-frontend-corpus.sh: %s requires a value and none was given.\n' "$1" >&2
        exit 2
    fi
}

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${HERE}/../../../.." && pwd)"
AUDIT="${HERE}/2026-08-07-npm-audit.json"
ALLJS="${ROOT}/acm-standard-applications/arkcase/src/main/webapp/resources/config/env/all.js"
OUT="${HERE}/frontend-advisory-triage.txt"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --audit) require_value '--audit' "$#"; AUDIT="$2"; shift 2 ;;
        --all-js) require_value '--all-js' "$#"; ALLJS="$2"; shift 2 ;;
        --out)   require_value '--out' "$#";   OUT="$2";   shift 2 ;;
        -h|--help)
            printf 'usage: triage-frontend-corpus.sh [--audit F] [--all-js F] [--out F]\n'; exit 0 ;;
        *) printf 'triage-frontend-corpus.sh: unrecognised argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

for f in "$AUDIT" "$ALLJS"; do
    [ -f "$f" ] || { printf 'triage-frontend-corpus.sh: required input is missing: %s\n' "$f" >&2; exit 2; }
done

STAGE="${OUT}.$$.staging"
trap 'rm -f -- "$STAGE"' EXIT

set +e
AUDIT="$AUDIT" ALLJS="$ALLJS" python3 - > "$STAGE" <<'PYEOF'
import json, os, re, collections, datetime

audit = json.load(open(os.environ['AUDIT']))
alljs = open(os.environ['ALLJS'], encoding='utf-8', errors='replace').read()
served_keys = set(re.findall(r'node_modules/@bower_components/([A-Za-z0-9._@-]+)', alljs))
vulns = audit['vulnerabilities']
meta = audit.get('metadata', {}).get('vulnerabilities', {})

advisories = {}
for name, x in vulns.items():
    for via in x.get('via', []):
        if isinstance(via, dict) and via.get('source') is not None:
            advisories[via['source']] = via.get('severity')

def classify(name, x):
    """Served / installed-not-referenced / build-time, decided on the INSTALL DIRECTORY.

    The directory a package installs into is not always its npm name, and matching on the
    name silently misclassifies when they differ in case.  The real case: npm calls the
    package 'chart.js', it installs as '@bower_components/Chart.js', and config/env/all.js
    references 'node_modules/@bower_components/Chart.js/Chart.min.js'.  Comparing the npm
    name against the directory names in all.js therefore reported a SERVED package as
    build-time only.  Deriving the directory from the audit's own nodes list removes the
    mismatch, because that is the same string the asset contract uses.
    """
    bower_dirs = [n.split('@bower_components/', 1)[1].split('/', 1)[0]
                  for n in (x.get('nodes') or []) if '@bower_components/' in n]
    if any(d in served_keys for d in bower_dirs): return 'served'
    if bower_dirs: return 'installed-not-referenced'
    return 'build-time'

def fixtext(x):
    fa = x.get('fixAvailable')
    if fa is False: return 'none published'
    if fa is True: return 'available'
    if isinstance(fa, dict):
        return '%s@%s%s' % (fa.get('name'), fa.get('version'),
                            ' (semver-major)' if fa.get('isSemVerMajor') else '')
    return 'unknown'

rows = []
for name, x in vulns.items():
    rows.append(dict(name=name, sev=x.get('severity'), rng=str(x.get('range')),
                     cls=classify(name, x), fix=fixtext(x), direct=bool(x.get('isDirect'))))
order = {'critical': 0, 'high': 1, 'moderate': 2, 'low': 3}
rows.sort(key=lambda r: (order.get(r['sev'], 9), r['name']))

W = print
W('complete frontend advisory triage of the committed npm audit')
W('===========================================================')
W('')
W('GENERATED, NOT AUTHORED, by docs/migration/smoke-evidence/advisory-corpus/triage-frontend-corpus.sh.')
W('Inputs are the committed audit and the frozen asset contract config/env/all.js.  No network')
W('query is made and no risk judgement is recorded here.')
W('')
W('generated-at (UTC) : %s' % datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
W('')
W('===== totals =====')
pkg = collections.Counter(r['sev'] for r in rows)
adv = collections.Counter(advisories.values())
W('vulnerable-package-nodes                    : %d' % len(rows))
W('  by-severity                               : critical=%d high=%d moderate=%d low=%d'
  % (pkg['critical'], pkg['high'], pkg['moderate'], pkg['low']))
W('distinct-advisories                         : %d' % len(advisories))
W('  by-severity                               : critical=%d high=%d moderate=%d low=%d'
  % (adv['critical'], adv['high'], adv['moderate'], adv['low']))
W('packages-with-no-fix-at-any-version         : %d' % sum(1 for r in rows if r['fix'] == 'none published'))
W('packages-with-a-fix-reported                : %d' % sum(1 for r in rows if r['fix'] != 'none published'))
cls = collections.Counter(r['cls'] for r in rows)
W('reaches-the-browser (served)                : %d' % cls['served'])
W('build-time-only                             : %d' % cls['build-time'])
W('installed-under-bower-not-referenced        : %d' % cls['installed-not-referenced'])
W('')
W("npm's own metadata.vulnerabilities.total    : %s" % meta.get('total'))
W('')
W('The first count and the third are different measures and are both reported because an')
W('earlier revision of the disclosure page reported the first while labelling it the second.')
W('npm propagates severity up the dependency chain, so one Critical advisory deep in the')
W('graph marks every package above it Critical -- which is why there are more Critical')
W('packages than Critical advisories.')
W('')
critical_high = [r for r in rows if r['sev'] in ('critical', 'high')]
served_ch = [r for r in critical_high if r['cls'] == 'served']
W('critical-or-high-packages                   : %d' % len(critical_high))
W('  of those, served to the browser           : %d' % len(served_ch))
W('  of those served, with no fix published    : %d' % sum(1 for r in served_ch if r['fix'] == 'none published'))
W('')
if served_ch:
    W('SERVED Critical/High packages -- the only rows where an upgrade changes the served')
    W('application and therefore the built bundles:')
    for r in served_ch:
        W('  %-9s %-22s range=%-24s fix=%s' % (r['sev'], r['name'], r['rng'][:24], r['fix']))
    W('')
W('===== rows, severity then name =====')
W('')
for r in rows:
    W('%-9s %s%s' % (r['sev'], r['name'], '  (direct dependency)' if r['direct'] else ''))
    W('  affected-range   : %s' % r['rng'])
    W('  reaches-browser  : %s' % {'served': 'yes -- named in config/env/all.js',
                                   'installed-not-referenced': 'no -- under @bower_components but not in the asset globs',
                                   'build-time': 'no -- build-time only'}[r['cls']])
    W('  upstream-fix     : %s' % r['fix'])
    W('')
PYEOF
status=$?
set -e

if [ "$status" -ne 0 ] || [ ! -s "$STAGE" ]; then
    rm -f -- "$STAGE"
    printf 'triage-frontend-corpus.sh: the triage was not produced; %s is untouched.\n' "$OUT" >&2
    exit "$status"
fi

# Fail closed: the emitted rows must account for the audit's own package count and severity
# split.  A triage that silently covers a subset is the defect this script exists to prevent.
audit_total="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["vulnerabilities"]))' "$AUDIT")"
table_total="$(awk -F': *' '/^vulnerable-package-nodes /{ print $2 }' "$STAGE")"
row_total="$(grep -cE '^(critical|high|moderate|low) +[^ ]' "$STAGE" || true)"

if [ "$table_total" != "$audit_total" ] || [ "$row_total" != "$audit_total" ]; then
    rm -f -- "$STAGE"
    printf 'triage-frontend-corpus.sh: FAIL CLOSED -- the triage does not cover the audit.\n' >&2
    printf '  vulnerable packages in audit : %s\n' "$audit_total" >&2
    printf '  total reported               : %s\n' "$table_total" >&2
    printf '  rows emitted                 : %s\n' "$row_total" >&2
    printf '  %s is untouched.\n' "$OUT" >&2
    exit 1
fi

if [ -L "$OUT" ] || { [ -e "$OUT" ] && [ ! -f "$OUT" ]; }; then
    rm -f -- "$STAGE"
    printf 'triage-frontend-corpus.sh: refusing to publish over %s: it is not a plain file.\n' "$OUT" >&2
    exit 2
fi
if ! mv -f -- "$STAGE" "$OUT"; then
    rm -f -- "$STAGE"
    printf 'triage-frontend-corpus.sh: could not move the staged triage into place at %s.\n' "$OUT" >&2
    exit 2
fi

printf 'triage-frontend-corpus.sh: wrote %s\n' "$OUT"
printf '  %s vulnerable packages, %s rows emitted, all accounted for\n' "$audit_total" "$row_total"
printf '  distinct advisories: %s | served Critical/High: %s\n' \
    "$(awk -F': *' '/^distinct-advisories /{ print $2 }' "$OUT")" \
    "$(awk -F': *' '/of those, served to the browser /{ print $2 }' "$OUT")"
exit 0
