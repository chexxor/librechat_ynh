---
phase: 03-upgrade
plan: 02
subsystem: infra
tags: [yunohost, manifest, ynh_setup_source, upgrade, librechat]

# Dependency graph
requires:
  - phase: 03-upgrade (plan 01)
    provides: upgrade script with config merge helper (librechat_regen_and_merge_configs)
provides:
  - manifest.toml pinned to v0.8.8-rc3 with sha256, version bumped to 0.8.8-rc3~ynh2
  - User-confirmed live `yunohost app upgrade librechat` round-trip (UPGR-05)
affects: [future-upgrade-releases, packaging-releases]

# Tech tracking
tech-stack:
  added: []
  patterns: [sha256-pinned source upgrades, ~ynhN version bump for upgrade triggers]

key-files:
  created: []
  modified: [manifest.toml]

key-decisions:
  - "Re-pinned same tag v0.8.8-rc3 (no newer upstream stable); bump validated via ~ynh1 → ~ynh2 version change"
  - "sha256 identical to prior pin (691cfe63…) since tag is unchanged; pin retained per SKEL-05"

patterns-established:
  - "Upgrade bump flow: fetch latest tag → pin url+sha256 → bump ~ynhN +1"

requirements-completed: [UPGR-05]

# Metrics
duration: N/A (verification-only continuation)
completed: 2026-09-18
---

# Phase 3 Plan 2: Manifest Bump + Live Upgrade Summary

**Manifest bumped to 0.8.8-rc3~ynh2 with sha256-pinned source; live `yunohost app upgrade librechat` verified end-to-end on the user's test server with all user state preserved.**

## Performance

- **Duration:** deferred to human verification window (task 2 was manual)
- **Started:** 2026-09-18
- **Completed:** 2026-09-18
- **Tasks:** 2
- **Files modified:** 1 (manifest.toml)

## Accomplishments
- manifest.toml source pinned to v0.8.8-rc3 tarball with valid sha256; package version bumped `0.8.8-rc3~ynh1` → `~ynh2` so YunoHost treats it as a real upgrade
- `[resources.nodejs]` confirmed matching upstream `.nvmrc` (24) — no change needed
- LIVE UPGRADE VERIFIED (user-confirmed "approved"): upgrade completed without errors, user config/env keys preserved, JWT secrets not rotated, librechat.yaml not clobbered, MongoDB chat data intact, npm cache stripped, UI reachable

## Task Commits

1. **Task 1: Bump manifest to new source tag + version** - `05e3d5b` (chore)
2. **Task 2: Live upgrade verification** - user-verified checkpoint (no code changes; no commit)

**Plan metadata:** see final docs commit.

## Files Created/Modified
- `manifest.toml` - version = "0.8.8-rc3~ynh2", [resources.sources.main] pinned url + sha256

## Decisions Made
- Upstream latest release is still v0.8.8-rc3 (no stable release newer exists), so the source tag and sha256 were re-pinned **unchanged** (identical sha256 `691cfe63aa4301d1c28821405a84b9725679fa0f4dbde0054d24bd80591c67d4`; `.nvmrc` still 24). Per the plan's fallback rule, the bump flow was still validated — the effective package change is `0.8.8-rc3~ynh1` → `0.8.8-rc3~ynh2`, which is sufficient for YunoHost to run the upgrade path.
- Live upgrade approval is user-confirmed (checkpoint:human-verify passed).

## Deviations from Plan

None - plan executed exactly as written (task 1 applied the plan's documented fallback for no-newer-tag; task 2 was verification-only).

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 3 complete: upgrade script tested in fixtures (03-01) and now proven live (03-02)
- No blockers; packaging ready for release tagging
- Future upstream releases: repeat the bump flow (tag fetch → url/sha256 pin → ~ynhN bump) and re-run live verification

---
*Phase: 03-upgrade*
*Completed: 2026-09-18*

## Self-Check: PASSED
- SUMMARY.md exists on disk
- Commit 05e3d5b (manifest bump) verified
- Plan metadata commit e848eba verified
- Verified: 2026-09-18 22:35
