#!/usr/bin/env bash
#
# Gate the canonical review-findings manifest.
#
# WHY THIS EXISTS.  The manifest's whole value is that it is COMPLETE: a finding missing from
# it is a finding answered by silence, which is exactly what the traceability finding it
# answers was about.  Completeness cannot be established by reading a long page, so it is
# asserted here.  The gate also enforces the one property the page must never be able to
# publish -- a deferral with no cited authority, which would be an omission dressed as a
# decision.
#
# It reads only committed files, needs no network, and modifies nothing.

set -euo pipefail

require_value()
{
    if [ "$2" -lt 2 ]; then
        printf 'verify-findings-disposition.sh: %s requires a value and none was given.\n' "$1" >&2
        exit 2
    fi
}

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOCS="$(cd -- "${HERE}/.." && pwd)"
PAGE="${DOCS}/review-findings-disposition.md"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --page) require_value '--page' "$#"; PAGE="$2"; shift 2 ;;
        -h|--help) printf 'usage: verify-findings-disposition.sh [--page FILE]\n'; exit 0 ;;
        *) printf 'verify-findings-disposition.sh: unrecognised argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[ -f "$PAGE" ] || { printf 'verify-findings-disposition.sh: manifest is missing: %s\n' "$PAGE" >&2; exit 2; }

fail=0
note() { printf '  %-58s %s\n' "$1" "$2"; }
bad()  { printf 'FAIL  %s\n' "$1" >&2; fail=1; }

# ---- 1. every identifier the review raised is present exactly once ----------------------
expected=$(
    for i in 1 2 3 4 5 6 7 8;                 do printf 'C-0%s\n' "$i"; done
    for i in $(seq -w 1 27);                  do printf 'M-%s\n' "$i"; done
    for i in $(seq -w 1 10);                  do printf 'N-%s\n' "$i"; done
    printf 'I-01\n'
)
missing=0; dupes=0
while read -r id; do
    n=$(grep -cE "^### ${id} — " "$PAGE" || true)
    [ "$n" -eq 0 ] && { bad "identifier absent from the manifest: $id"; missing=$((missing+1)); }
    [ "$n" -gt 1 ] && { bad "identifier appears $n times: $id"; dupes=$((dupes+1)); }
done <<< "$expected"
total=$(printf '%s\n' "$expected" | wc -l | tr -d ' ')
sections=$(grep -cE '^### (C-0[1-8]|M-[0-2][0-9]|N-[0-1][0-9]|I-01) — ' "$PAGE" || true)
note "identifiers expected" "$total"
note "sections present" "$sections"
[ "$sections" = "$total" ] || bad "section count $sections does not equal the expected $total"

# ---- 2. the severity split must be the review's own -------------------------------------
for pair in "Critical:8" "Major:27" "Minor:10" "Info:1"; do
    sev=${pair%%:*}; want=${pair##*:}
    got=$(grep -cE "^### [A-Z]-[0-9]+ — ${sev} — " "$PAGE" || true)
    note "severity ${sev}" "$got (expected $want)"
    [ "$got" = "$want" ] || bad "severity $sev is $got, expected $want"
done

# ---- 3. accounting table must agree with the sections it summarises ---------------------
for pair in "RESOLVED:Resolved in this change set" "PARTIAL:Partially resolved" "DEFERRED:Deferred with a cited authority"; do
    tok=${pair%%:*}; label=${pair##*:}
    secs=$(grep -cE "^### [A-Z]-[0-9]+ — [A-Za-z]+ — (\*\*)?${tok}(\*\*)?$" "$PAGE" || true)
    tbl=$(awk -F'|' -v l="$label" 'index($2,l){ gsub(/[^0-9]/,"",$3); print $3 }' "$PAGE" | head -1)
    note "$tok sections vs accounting table" "$secs vs ${tbl:-none}"
    [ -n "$tbl" ] || { bad "accounting table has no row for $label"; continue; }
    [ "$secs" = "$tbl" ] || bad "$tok: $secs sections but the accounting table says $tbl"
done

# ---- 4. THE LOAD-BEARING CHECK: no deferral without a cited authority -------------------
# Every finding section must carry an Authority paragraph.  A DEFERRED or PARTIAL row whose
# authority is empty or generic is the failure this gate exists to catch, so the authority
# text must also name a plan clause, a rule, or an explicit measurement.
uncited=0
while read -r id; do
    block=$(awk -v id="### ${id} — " 'index($0,id){f=1} f&&/^### /&&!index($0,id){exit} f' "$PAGE")
    [ -n "$block" ] || continue
    auth=$(printf '%s\n' "$block" | grep -A1 '^\*\*Authority for this disposition\.\*\*' || true)
    if [ -z "$auth" ]; then bad "$id has no Authority paragraph"; uncited=$((uncited+1)); continue; fi
    if ! printf '%s\n' "$auth" | grep -qE 'AAP [0-9]|R-[0-9T]|Resolved|measured|base commit|byte-identical'; then
        bad "$id cites no plan clause, rule or measurement"; uncited=$((uncited+1))
    fi
    printf '%s\n' "$block" | grep -q '^\*\*What a human must do\.\*\*' \
        || bad "$id does not state what a human must do"
done <<< "$expected"
note "findings with no cited authority" "$uncited"

# ---- 5. the manifest must not explain a deferred defect away ----------------------------
# Scoped to the finding sections.  Scanning the whole page made the check trip on the
# Verification section's own instruction to confirm that no row explains a defect away --
# a gate cannot be pointed at the text that describes it.
FINDINGS_ONLY=$(awk '/^## Every finding$/{f=1;next} /^## Consolidated ratification register$/{f=0} f' "$PAGE")
for phrase in 'not a real' 'harmless' 'no impact' 'nothing to do here' 'not exploitable'; do
    if printf '%s\n' "$FINDINGS_ONLY" | grep -qi "$phrase"; then
        bad "a finding section contains an explaining-away phrase: '$phrase'"
    fi
done

if [ "$fail" -ne 0 ]; then
    printf 'verify-findings-disposition.sh: the manifest does not hold.\n' >&2
    exit 1
fi
printf 'verify-findings-disposition.sh: manifest holds -- %s findings, all identifiers present,\n' "$total"
printf '  severity split matches the review, accounting agrees with the sections, and every\n'
printf '  finding cites an authority and names a human action.\n'
exit 0
