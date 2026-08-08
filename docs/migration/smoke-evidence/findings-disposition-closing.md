## Verification

This page is checkable in both directions and its own verifier is committed beside it. Run from the repository root:

```bash
bash docs/migration/smoke-evidence/verify-findings-disposition.sh
```

It must exit `0`. It asserts that all **46** identifiers are present exactly once, that the severity split is 8 / 27 / 10 / 1, that the disposition counts in the accounting table equal the dispositions in the sections below them, and that **every** deferred or partial finding names an authority — a deferral with no citation is the one failure this page must not be able to publish.

Then confirm the two claims that carry the most weight, by measuring rather than reading:

```bash
grep -cE '^### (C-0[1-8]|M-[0-2][0-9]|N-[0-1][0-9]|I-01) ' docs/migration/review-findings-disposition.md
grep -c 'DEFERRED\|PARTIAL\|RESOLVED' docs/migration/review-findings-disposition.md
awk -F': *' '/^vulnerable-package-nodes /{ print $2 }' \
  docs/migration/smoke-evidence/advisory-corpus/frontend-advisory-triage.txt
```

The first must print `46`. The third must print `101`, which is the figure the C-08 row above depends on, read out of the generated triage rather than out of this page.

- Confirm by reading that **no row describes a deferred finding as harmless**. Several are real security defects that are not fixed; the rows say so. A row that explained a defect away rather than citing the clause that bars the fix would be the failure this page exists to prevent.
- Confirm that **every RESOLVED row names evidence rather than an intention**, and that the three PARTIAL rows each state precisely which half is done and which half needs a decision.

## Related pages

- [Pre-existing Defects](pre-existing-defects.md) — the detailed register for every inherited defect, including the ten entries added for findings that previously had no register row
- [Dependency Change Inventory](dependency-change-inventory.md) — every dependency change with its compatibility reason, and the deviations table this page counts
- [Backend Dependency Security](backend-dependency-security.md) — all 40 Maven advisories, including the one this migration entered
- [Frontend Dependency Security](frontend-dependency-security.md) — all 101 vulnerable packages, the 66 Critical and High, and the nine governed exceptions
- [Baseline Test Failures](baseline-test-failures.md) — the authority any test exclusion must cite
- [Ambiguity Resolutions](ambiguity-resolutions.md) — where baseline behaviour was the tie-breaker
