---
phase: 06-fix-findings-to-zero-failures
plan: 03
subsystem: infra
tags: [yunohost, package_check, triage, pols-01, regression]
requires:
  - phase: 06-01
    provides: headline secret-token fix + conf-token sweep
  - phase: 06-02
    provides: xtrace guards + redaction tool
provides:
  - Cycle-1 full-suite run artifacts (Test_results.log, package_check-full.log, full_log_0.log)
  - Cycle-1 triage entries with buckets and quoted evidence
  - Prioritized remaining in-scope bug list (the `conf/librechat.env` literal `__VAR__` token)
affects: [06-04]
tech_stack:
  added: []
  patterns: ["full-suite-every-cycle triage loop", "flake-vs-regression rule (no external cause => regression)"]
key_files:
  created:
    - .planning/phases/06-fix-findings-to-zero-failures/cycles/cycle-1/Test_results.log
    - .planning/phases/06-fix-findings-to-zero-failures/cycles/cycle-1/package_check-full.log
    - .planning/phases/06-fix-findings-to-zero-failures/cycles/cycle-1/full_log_0.log
  modified:
    - .planning/phases/06-fix-findings-to-zero-failures/triage/triage-log.md
key_decisions:
  - "Wave-1 headline fix confirmed working; a new token regression surfaced and was fixed in the same cycle turn"
  - "Cascaded install failures are re-triaged only after install.root passes (not counted as independent bugs)"
patterns_established:
  - "One full-suite cycle per fix iteration; every non-SUCCESS verdict bucketed with quoted log evidence"
requirements-completed: [POLS-01]
duration: ~4 min run + triage
completed: 2026-09-20
---

# Phase 6 Plan 03: Cycle-1 full-suite run + triage

**First post-Wave-1 full `package_check` cycle (4m10s, exit 0): the headline `__ADMIN_PANEL_SESSION_SECRET__` error is gone — install advances past it, exposing a new literal `__VAR__` token regression in `conf/librechat.env`.**

> Backfilled 2026-09-22 from `triage/triage-log.md` (Cycle 1 section) and the archived `cycles/cycle-1/` artifacts, so Phase 6's plan/summary counts reconcile at milestone completion.

## Performance

- **Duration:** 4m10s run + triage
- **Completed:** 2026-09-20
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** triage log

## Accomplishments

- Drove one full `package_check` cycle on the Hyper-V Debian 12 VM (rev `629f7bb`, 14 commits after the Phase 5 baseline; includes the Wave-1 headline fix + xtrace guards). Run completed with a Global summary, exit 0.
- Retrieved cycle-1 artifacts (`Test_results.log`, `package_check-full.log`, `full_log_0.log`) into `cycles/cycle-1/`.
- Triaged all 6 test verdicts into the four buckets with quoted evidence.
- Confirmed the Wave-1 headline fix worked: the original `__ADMIN_PANEL_SESSION_SECRET__` variable error is GONE.
- Identified the next actionable in-scope bug: a literal `__VAR__` inside the `conf/librechat.env` header comment, which `_ynh_replace_vars` parsed as a placeholder token. Fixed in the same cycle turn.

## Per-Test Verdicts (Cycle 1)

| Test | Verdict | Bucket |
|------|---------|--------|
| package_linter | SUCCESS | — |
| install.root | FAIL | Package bug (literal `__VAR__` token) |
| backup_restore | FAIL | Package bug (cascade) |
| upgrade | FAIL | Package bug (cascade) |
| upgrade.05e3d5b | FAIL | Package bug (cascade) |
| change_url | FAIL | Exempt (POLS-02) |

## Decisions Made

- The `__VAR__` failure has no external cause in the log → **REGRESSION**, not a flake; fixed immediately.
- Cascaded install failures (tests 3–6) are blocked by `install.root` and are re-triaged only after it passes — not treated as independent bugs.

## Deviations from Plan

None. The plan's `<output>` required this SUMMARY at completion; it was not written during the original run and is backfilled here to reconcile Phase 6's plan/summary counts.

## Issues Encountered

- `imgkit` summary-renderer `ModuleNotFoundError` left `results_0.json` as a 182-byte traceback; verdicts were read from the run log instead. Classified harness/environment and documented (resolved later in cycle 5 by installing the missing `package_check/requirements.txt` deps).

## Next Phase Readiness

- Pre Wave-2 fix loop: one actionable in-scope bug (the `__VAR__` token) plus cascaded failures pending `install.root`. Plan 06-04 (Wave 3 fix loop) continues cycles until the 4 in-scope tests are green.

---
*Phase: 06-fix-findings-to-zero-failures*
*Completed: 2026-09-20 (backfilled 2026-09-22)*
