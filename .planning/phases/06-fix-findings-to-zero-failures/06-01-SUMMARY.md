---
phase: 06-fix-findings-to-zero-failures
plan: 01
subsystem: packaging
tags: [yunohost, template-tokens, admin-panel-secret, scope-exemptions, triage]
requires:
  - phase: 05
    provides: package_check environment and the findings run that pinpointed the install-blocking bug
provides:
  - Fixed conf/librechat.env token that resolves to the generated admin_panel_secret variable
  - Complete conf-token reconciliation against bash variable scope
  - Phase 6 scope-exemption record
  - Triage log template seeded with the Phase 5 baseline
affects: [06-03, 06-04, 06-05]
tech_stack:
  added: []
  patterns: [ynh_config_add token resolution, scope-exemption record precedent (Phase 4)]
key_files:
  created:
    - .planning/phases/06-fix-findings-to-zero-failures/06-SCOPE-EXEMPTIONS.md
    - .planning/phases/06-fix-findings-to-zero-failures/triage/triage-log.md
  modified:
    - conf/librechat.env
key_decisions:
  - "Option A: change the template token to __ADMIN_PANEL_SECRET__ (keep the admin_panel_secret variable/setting name) — one-line, no settings migration, upgrade/restore stay consistent"
  - "tests.toml stays frozen; no exclude; change_url left FAILing and documented"
patterns_established:
  - "Static token sweep before any VM cycle, so latent __TOKEN__ mismatches are caught without spending a run"
duration: ~10 min
completed: 2026-09-20
---

# Phase 6 Plan 01: Static groundwork — headline fix + token sweep + records

**Fixed the install-blocking `admin_panel_session_secret` token mismatch and pre-emptively reconciled every conf template token, then created the phase's scope-exemption record and triage log.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-09-20
- **Completed:** 2026-09-20
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- `conf/librechat.env:26` now uses `__ADMIN_PANEL_SECRET__` (resolves to the generated `$admin_panel_secret`); the emitted env key `ADMIN_PANEL_SESSION_SECRET=` is unchanged (LibreChat's contract).
- Verified no `__ADMIN_PANEL_SESSION_SECRET__` remains in `conf/` and every remaining token is in the known-good set (the full map is in `06-RESEARCH.md`). `admin_password` is confirmed NOT a template placeholder.
- Created `06-SCOPE-EXEMPTIONS.md` with the zero-failure invariant and 7 exempted/uncovered items.
- Created `triage/triage-log.md` with the four buckets, the flake rule, and the Phase 5 baseline as Cycle 0.

## Task Commits

1. **All three tasks:** `57d2ef6` — `fix(06-01): reconcile admin panel secret token and add scope/triage records`

## Files Created/Modified

- `conf/librechat.env` — token changed to `__ADMIN_PANEL_SECRET__`
- `.planning/phases/06-fix-findings-to-zero-failures/06-SCOPE-EXEMPTIONS.md` — created
- `.planning/phases/06-fix-findings-to-zero-failures/triage/triage-log.md` — created

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

Wave 1 static groundwork complete. Plans 06-03 (first VM cycle), 06-04 (fix loop), 06-05 (final archive) depend on this and on Plan 06-02's secret hygiene.
