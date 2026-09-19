---
phase: 02-remove-backup-restore
plan: 01
subsystem: infra
tags: [yunohost, manifest, remove-lifecycle, mongodb, systemd, meilisearch, nodejs]

# Dependency graph
requires:
  - phase: 01-foundation-install
    provides: manifest with nodejs/mongo resources, systemd templates using __DATA_DIR__, _common.sh with mongo_version global, db_name app setting
provides:
  - "[resources.data_dir] declaration in manifest.toml (enables __DATA_DIR__ substitution + core-managed data dir)"
  - "Full scripts/remove lifecycle: services stopped, deregistered, systemd/nginx removed, namespaced-only MongoDB teardown, ref-counted Node removal, meilisearch binary cleanup"
affects: [03-backup-restore, live-server-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: [Wekan_ynh-verified remove order, tolerant remove-after-failed-install guards, settings-driven db_name/db_user]

key-files:
  created: []
  modified:
    - manifest.toml
    - scripts/remove

key-decisions:
  - "Declare [resources.data_dir] with no subdir config — meilisearch creates its own db-path dir at runtime"
  - "Remove uses ynh_mongo_remove_db with db_name from settings (db_user=db_name); NEVER ynh_remove_mongo to protect shared MongoDB"
  - "install_dir/data_dir removal left to YNH core; ynh_safe_rm guards the package-owned data_dir/meilisearch subdir"

patterns-established:
  - "Tolerant removal: all stop/deregister steps guarded with || true or if-guards so remove-after-failed-install never errors"

requirements-completed: [RMV-01, RMV-02, RMV-03, RMV-04, RMV-05]

# Metrics
duration: 4min
completed: 2026-09-18
---

# Phase 2 Plan 01: Remove Lifecycle Summary

**Declared the latent `[resources.data_dir]` manifest gap (fixes `__DATA_DIR__` substitution/crashloop risk) and implemented the full Wekan-pattern `scripts/remove` that stops everything, deregisters monitoring, and tears down only this app's namespaced MongoDB database — safe for shared MongoDB.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-09-18T21:27:20-05:00
- **Completed:** 2026-09-18T21:31-05:00
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- manifest.toml declares `[resources.data_dir]`, eliminating the risk that both systemd templates render an empty `__DATA_DIR__` and meilisearch crashloops with a missing db-path
- scripts/remove fully implements RMV-01..05 in the Wekan-verified order: stop services → deregister monitoring → remove systemd units → remove nginx → namespaced MongoDB removal → ref-counted Node removal → meilisearch binary cleanup
- Removal is tolerant of partially-installed state (remove-after-failed-install never errors)

## Task Commits

1. **Task 1: Declare [resources.data_dir] in manifest.toml** - `a91d250` (fix)
2. **Task 2: Implement scripts/remove** - `3a54707` (feat)

## Files Created/Modified
- `manifest.toml` - Added `[resources.data_dir]` section after `[resources.install_dir]`
- `scripts/remove` - Stub replaced with 96-line full remove lifecycle (90 insertions)

## Decisions Made
- `[resources.data_dir]` declared with no subdirectory config; the runtime helpers create `$data_dir/meilisearch` paths and meilisearch creates its own db-path dir
- db_name is read explicitly from app settings (`db_user` is not a stored setting — `db_user=$db_name` per YNH mongo naming), avoiding Pitfall 5
- Package-owned `data_dir/meilisearch` subdir is removed with `ynh_safe_rm` (RMV-03 wording exception); the data_dir itself is left to the YNH core

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Live-server verification of removal (mongosh shows other-app DBs intact) is deferred to Plan 02's checkpoint per plan verification notes
- Ready for 02-02 (backup/restore scripts)

---
*Phase: 02-remove-backup-restore*
*Completed: 2026-09-18*

## Self-Check: PASSED

- manifest.toml modified: FOUND
- scripts/remove (96 lines): FOUND
- Commit a91d250: FOUND
- Commit 3a54707: FOUND
