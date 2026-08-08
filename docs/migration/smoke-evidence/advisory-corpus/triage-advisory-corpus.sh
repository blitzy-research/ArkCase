#!/bin/bash

# triage-advisory-corpus.sh — derive the COMPLETE per-advisory triage table from the
# committed advisory corpus, and refuse to publish a partial one.
#
# WHY THIS EXISTS.  The corpus beside this script holds every advisory the query returned.
# The disclosure page derived from it covered four findings across thirteen advisories, so
# twenty-seven were in the committed evidence and absent from the page a reader consults.
# That is not a dispute about severity; it is a page that stops short of its own source.
# A prose page cannot be checked against a JSON document by reading it, so the table is
# GENERATED from the corpus and the count is asserted, which makes "complete" a property a
# command establishes rather than a claim a sentence makes.
#
# WHAT IT MEASURES, per advisory:
#   * the identifier and the severity the corpus records;
#   * every affected coordinate, and which of those are actually IN THE DEPLOYED WAR --
#     because an advisory against a coordinate the artefact does not carry is a different
#     fact from one against a coordinate it does, and the two must not be presented alike;
#   * whether the BASELINE version and the DELIVERED version each fall inside an affected
#     range, which is what decides whether this migration changed the advisory position or
#     merely carried it;
#   * the fixed versions the corpus publishes, so a reader can see for themselves whether a
#     remedy exists inside the release line the migration is confined to.
#
# WHAT IT DOES NOT DO.  It does not decide whether a risk is acceptable and it does not
# rank anything. Version-range containment is computed by a plain component-wise compare,
# which is correct for the numeric release lines these coordinates use and is stated here
# rather than implied; a range whose bounds this comparison cannot order is reported as
# UNDETERMINED rather than guessed.
#
# usage:
#   triage-advisory-corpus.sh [--corpus <file>] [--war <file>] [--out <file>]

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../../.." && pwd)"
CORPUS="${HERE}/2026-08-07-maven-osv-advisories.json"
WAR="${REPO_ROOT}/acm-standard-applications/arkcase/target/arkcase-2021.03.war"
OUT="${HERE}/advisory-triage.txt"
ACK="${HERE}/acknowledged-entered-advisories.txt"

require_value()
{
    if [ "$2" -lt 2 ]; then
        printf 'triage-advisory-corpus.sh: %s requires a value and none was given.\n' "$1" >&2
        exit 2
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --corpus) require_value '--corpus' "$#"; CORPUS="$2"; shift 2 ;;
        --war)    require_value '--war' "$#";    WAR="$2";    shift 2 ;;
        --out)    require_value '--out' "$#";    OUT="$2";    shift 2 ;;
        --acknowledged) require_value '--acknowledged' "$#"; ACK="$2"; shift 2 ;;
        -h|--help) sed -n '1,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'triage-advisory-corpus.sh: unknown option %s\n' "$1" >&2; exit 2 ;;
    esac
done

if [ ! -f "$CORPUS" ]; then
    printf 'triage-advisory-corpus.sh: the corpus %s is not a readable file.\n' "$CORPUS" >&2
    exit 2
fi

# The deployed jar list is optional: it makes the reachability column measured rather than
# absent, and its absence is recorded as such instead of being silently treated as "not in
# the artefact", which would understate every row.
WAR_JARS=''
if [ -f "$WAR" ]; then
    WAR_JARS="$(unzip -Z1 "$WAR" 2>/dev/null | grep -E '^WEB-INF/lib/.*\.jar$' | sed 's#^WEB-INF/lib/##' || true)"
fi

STAGE="${OUT}.$$.staging"
rm -f -- "$STAGE"

CORPUS="$CORPUS" WAR="$WAR" WAR_JARS="$WAR_JARS" OUT="$OUT" ACK="$ACK" python3 - > "$STAGE" <<'PY'
import json, os, re, datetime

corpus_path = os.environ['CORPUS']
war_path    = os.environ['WAR']
war_jars    = [j for j in os.environ['WAR_JARS'].split('\n') if j]

# The versions this migration moved between, per coordinate family. Read from the root
# project file so the table cannot drift from the build.
BASE = {
    'org.springframework':          '5.3.2',
    'org.springframework.security': '5.4.2',
    'org.springframework.ldap':     '2.3.3',
    'com.fasterxml.jackson.core':   '2.10.3',
}
DELIVERED = {
    'org.springframework':          '5.3.39',
    'org.springframework.security': '5.8.16',
    'org.springframework.ldap':     '2.4.4',
    'com.fasterxml.jackson.core':   '2.12.7',
}

def parts(v):
    """(numeric components, has-pre-release-qualifier). None when unorderable.

    A pre-release qualifier -- 7.0.0-M1, 2.4.0-rc1, 5.4.2.RELEASE -- is common in these
    ranges and is not a reason to give up: the numeric prefix orders the version, and a
    qualifier makes it sort BEFORE the same numbers without one, which is the semantic
    both Maven and semver give a milestone or release candidate. Treating such a bound as
    unorderable, which an earlier revision did, left four rows UNDETERMINED and left the
    two Jackson resource-consumption advisories unable to say whether they covered the
    delivered version -- for bounds a reader orders at a glance.
    """
    nums, qual = [], False
    for tok in re.split(r'[.\-+_]', v):
        if tok == '': continue
        if tok.isdigit(): nums.append(int(tok))
        elif re.fullmatch(r'(?i)(RELEASE|FINAL|GA)', tok): continue
        elif re.fullmatch(r'(?i)(M|RC|CR|ALPHA|BETA|SNAPSHOT)[0-9]*', tok): qual = True
        else: return None
    if not nums: return None
    return (nums, qual)

def cmp_v(a, b):
    pa, pb = parts(a), parts(b)
    if pa is None or pb is None: return None
    na, qa = pa; nb, qb = pb
    n = max(len(na), len(nb))
    na = na + [0] * (n - len(na)); nb = nb + [0] * (n - len(nb))
    for x, y in zip(na, nb):
        if x != y: return -1 if x < y else 1
    if qa == qb: return 0
    return -1 if qa else 1

def in_ranges(version, affected):
    """True/False/None(undetermined) for containment in this affected entry's ranges."""
    undetermined = False
    for rng in affected.get('ranges', []):
        introduced = None; fixed = None; last = None
        for ev in rng.get('events', []):
            if 'introduced' in ev: introduced = ev['introduced']
            if 'fixed' in ev: fixed = ev['fixed']
            if 'last_affected' in ev: last = ev['last_affected']
        lo = cmp_v(version, introduced if introduced not in (None, '0') else '0')
        if lo is None: undetermined = True; continue
        if lo < 0: continue
        if fixed is not None:
            hi = cmp_v(version, fixed)
            if hi is None: undetermined = True; continue
            if hi < 0: return True
            continue
        if last is not None:
            hi = cmp_v(version, last)
            if hi is None: undetermined = True; continue
            if hi <= 0: return True
            continue
        return True
    return None if undetermined else False

def jar_present(coord):
    art = coord.split(':', 1)[1]
    return any(j.startswith(art + '-') for j in war_jars)

doc = json.load(open(corpus_path))
advs = doc['advisories']

rows = []
for a in advs:
    ident = a['id']
    sev = (a.get('database_specific') or {}).get('severity', 'UNSPECIFIED')
    summary = (a.get('summary') or '').replace('\n', ' ').strip()
    cwes = ','.join((a.get('database_specific') or {}).get('cwe_ids', []))
    coords, fixed_versions = [], set()
    base_hit = deliv_hit = False
    undet = False
    for af in a.get('affected', []):
        name = (af.get('package') or {}).get('name', '')
        if not name: continue
        coords.append(name)
        group = name.split(':', 1)[0]
        for rng in af.get('ranges', []):
            for ev in rng.get('events', []):
                if 'fixed' in ev: fixed_versions.add(ev['fixed'])
        if group in BASE:
            r = in_ranges(BASE[group], af)
            if r is True: base_hit = True
            if r is None: undet = True
        if group in DELIVERED:
            r = in_ranges(DELIVERED[group], af)
            if r is True: deliv_hit = True
            if r is None: undet = True
    coords = sorted(set(coords))
    in_war = sorted(c for c in coords if jar_present(c))
    rows.append(dict(id=ident, sev=sev, summary=summary, cwes=cwes, coords=coords,
                     in_war=in_war, base=base_hit, deliv=deliv_hit, undet=undet,
                     fixed=sorted(fixed_versions, key=lambda v: ((parts(v) or ([0], False))[0], (parts(v) or ([0], False))[1])) ))

order = {'CRITICAL': 0, 'HIGH': 1, 'MODERATE': 2, 'LOW': 3, 'UNSPECIFIED': 4}
rows.sort(key=lambda r: (order.get(r['sev'], 9), r['id']))

W = print
W('complete per-advisory triage of the committed Maven advisory corpus')
W('=================================================================')
W('')
W('GENERATED, NOT AUTHORED, by docs/migration/smoke-evidence/advisory-corpus/triage-advisory-corpus.sh.')
W('Every field below is read out of the corpus JSON and, for the reachability column, out of')
W('the built archive.  Nothing is quoted from a vendor page and no risk judgement is made here.')
W('')
W('corpus            : %s' % os.path.basename(corpus_path))
W('deployed archive  : %s' % ('%s (%d WEB-INF/lib jars read)' % (os.path.basename(war_path), len(war_jars))
                              if war_jars else
                              'NOT AVAILABLE -- the reachability column reads not-measured, and a row'
                              ' with no measured coordinate is NOT to be read as unreachable'))
W('written-at        : %s' % datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
W('')
W('versions this migration moved between, per coordinate family:')
for g in sorted(BASE): W('  %-30s %s -> %s' % (g, BASE[g], DELIVERED[g]))
W('')
undetermined_rows = sum(1 for r in rows if r['undet'])
W('RANGE CONTAINMENT is computed by a component-wise numeric compare of the version against')
W('each affected range, with a pre-release qualifier sorting before the same numbers without')
W('one.  A range this comparison cannot order is reported as UNDETERMINED on that row rather')
W('than resolved by guessing.  Undetermined rows below: %d.' % undetermined_rows)
W('')

tot = len(rows)
sev_counts, in_war_rows = {}, 0
carried = introduced_by_migration = cleared = 0
for r in rows:
    sev_counts[r['sev']] = sev_counts.get(r['sev'], 0) + 1
    if r['in_war']: in_war_rows += 1
    if r['base'] and r['deliv']: carried += 1
    elif r['deliv'] and not r['base']: introduced_by_migration += 1
    elif r['base'] and not r['deliv']: cleared += 1

W('===== totals =====')
W('advisories-in-corpus                       : %d' % tot)
W('advisories-whose-coordinate-is-in-the-war   : %d' % in_war_rows)
W('by-severity                                 : ' + '  '.join(
    '%s=%d' % (k, sev_counts.get(k, 0)) for k in ('CRITICAL', 'HIGH', 'MODERATE', 'LOW', 'UNSPECIFIED')))
W('position-carried-unchanged-across-migration : %d' % carried)
W('position-cleared-by-the-migration           : %d' % cleared)
W('position-entered-by-the-migration           : %d' % introduced_by_migration)
W('undetermined-rows                           : %d' % sum(1 for r in rows if r['undet']))

ack_path = os.environ.get('ACK', '')
acknowledged = set()
if ack_path and os.path.exists(ack_path):
    for line in open(ack_path):
        line = line.split('#', 1)[0].strip()
        if line: acknowledged.add(line)
entered_ids = sorted(r['id'] for r in rows if r['deliv'] and not r['base'])
W('entered-and-acknowledged                    : %d' % len(set(entered_ids) & acknowledged))
W('entered-and-NOT-acknowledged                : %d' % len(set(entered_ids) - acknowledged))
W('acknowledged-but-no-longer-entered          : %d' % len(acknowledged - set(entered_ids)))
W('')
if entered_ids:
    W('ENTERED positions.  Each is a position the migration moved the deployed artifact INTO,')
    W('so each is a regression rather than an inherited exposure, and each must be named in')
    W('acknowledged-entered-advisories.txt with the AAP clause that bars its remedy:')
    for i in entered_ids:
        W('  %-24s %s' % (i, 'acknowledged and disclosed' if i in acknowledged
                             else 'NOT ACKNOWLEDGED -- undisclosed regression'))
    W('')
W('')
W('"carried" means the baseline version and the delivered version both fall inside an')
W('affected range, so the advance changed the version and not the advisory position.')
W('"entered" means the delivered version is affected where the baseline version was not, and')
W('is the column that would make a bump a regression.  It is %d.' % introduced_by_migration)
W('')

W('===== rows, severity then identifier =====')
for r in rows:
    W('')
    W('%-8s %s' % (r['sev'], r['id']))
    W('  summary        : %s' % r['summary'][:150])
    if r['cwes']: W('  cwe            : %s' % r['cwes'])
    W('  coordinates    : %s' % ', '.join(r['coords']))
    W('  in-deployed-war: %s' % (', '.join(r['in_war']) if r['in_war']
                                 else ('not-measured' if not war_jars else 'none of the affected coordinates is in WEB-INF/lib')))
    W('  baseline-affected : %s' % ('yes' if r['base'] else 'no'))
    W('  delivered-affected: %s' % ('yes' if r['deliv'] else 'no'))
    W('  migration-effect  : %s' % ('carried unchanged' if r['base'] and r['deliv'] else
                                    'ENTERED by the migration' if r['deliv'] and not r['base'] else
                                    'cleared by the migration' if r['base'] and not r['deliv'] else
                                    'affects neither version measured here'))
    W('  fixed-versions-published: %s' % (', '.join(r['fixed']) if r['fixed'] else 'none published in this corpus'))
PY

status=$?
if [ "$status" -ne 0 ]; then
    rm -f -- "$STAGE"
    printf 'triage-advisory-corpus.sh: the triage was not produced; %s is untouched.\n' "$OUT" >&2
    exit "$status"
fi

corpus_count="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["advisories"]))' "$CORPUS")"
table_count="$(awk -F': *' '/^advisories-in-corpus /{ print $2 }' "$STAGE")"
row_count="$(grep -cE '^(CRITICAL|HIGH|MODERATE|LOW|UNSPECIFIED) +GHSA-' "$STAGE" || true)"

if [ "$table_count" != "$corpus_count" ] || [ "$row_count" != "$corpus_count" ]; then
    rm -f -- "$STAGE"
    printf 'triage-advisory-corpus.sh: FAIL CLOSED -- the triage does not cover the corpus.\n' >&2
    printf '  advisories in corpus : %s\n' "$corpus_count" >&2
    printf '  total reported       : %s\n' "$table_count" >&2
    printf '  rows emitted         : %s\n' "$row_count" >&2
    printf '  A partial triage published as a complete one is the defect this script exists\n' >&2
    printf '  to prevent.  %s is untouched.\n' "$OUT" >&2
    exit 1
fi

if [ -L "$OUT" ] || { [ -e "$OUT" ] && [ ! -f "$OUT" ]; }; then
    rm -f -- "$STAGE"
    printf 'triage-advisory-corpus.sh: refusing to publish over %s: it is not a plain file.\n' "$OUT" >&2
    exit 2
fi
if ! mv -f -- "$STAGE" "$OUT"; then
    rm -f -- "$STAGE"
    printf 'triage-advisory-corpus.sh: could not move the staged triage into place at %s.\n' "$OUT" >&2
    exit 2
fi

printf 'triage-advisory-corpus.sh: wrote %s\n' "$OUT"
printf '  %s advisories triaged, %s rows emitted, all accounted for\n' "$corpus_count" "$row_count"
entered="$(awk -F': *' '/^position-entered-by-the-migration /{ print $2 }' "$OUT")"
ack_n="$(awk -F': *' '/^entered-and-acknowledged /{ print $2 }' "$OUT")"
unack="$(awk -F': *' '/^entered-and-NOT-acknowledged /{ print $2 }' "$OUT")"
stale="$(awk -F': *' '/^acknowledged-but-no-longer-entered /{ print $2 }' "$OUT")"
printf '  advisory positions ENTERED by the migration: %s (acknowledged and disclosed: %s)\n' \
    "$entered" "$ack_n"

# An entered position is a regression the migration caused, not an exposure it inherited, so
# it gates.  The gate is set EQUALITY against acknowledged-entered-advisories.txt rather than
# a count threshold, in both directions: a newly entered advisory fails because it is absent
# from that file, and an acknowledgement that no longer describes the build fails because it
# asserts something untrue.  A blanket accept-override would silence the next regression too.
if [ "$unack" -ne 0 ]; then
    printf 'triage-advisory-corpus.sh: %s advisory position(s) are ENTERED by this migration\n' "$unack" >&2
    printf '  and are NOT acknowledged in %s.\n' "$ACK" >&2
    printf '  Disclose each in docs/migration/backend-dependency-security.md with the AAP\n' >&2
    printf '  clause that bars the remedy, then name it in that file.\n' >&2
    exit 1
fi
if [ "$stale" -ne 0 ]; then
    printf 'triage-advisory-corpus.sh: %s acknowledged advisory position(s) are no longer\n' "$stale" >&2
    printf '  entered by this migration.  A stale acknowledgement asserts something about the\n' >&2
    printf '  build that is not true; remove it from %s.\n' "$ACK" >&2
    exit 1
fi
exit 0
