# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-19)

**Core value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.
**Current focus:** Phase 3 — Upgrade

## Current Position

Phase: 3 of 3 (Upgrade) — COMPLETE
Plan: All plans complete (03-01 executed 2026-09-18: commits fe50d98, ba94ac6; 03-02 executed 2026-09-18: manifest bump 05e3d5b + user-approved live upgrade)
Status: Phase 3 complete — all 3 phases done; ready for release/final wrap
Last activity: 2026-09-18 — 03-02 completed (live upgrade user-verified)

Progress: [██████████] 100% (7 of 7 plans: 3×01, 2×02, 2×03)

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: ~8m
- Total execution time: ~50m

**Recent Trend:**
- Last 5 plans: —
- Trend: —
| Phase 01 P01 | 10m | 3 tasks | 13 files |
| Phase 01 P02 | 8m | 2 tasks | 2 files |
| Phase 01 P02 | 8m | 2 tasks | 2 files |
| Phase 01 P03 | 6m | 4 tasks | 4 files |
| Phase 02 P01 | 4m | 2 tasks | 2 files |
| Phase 02 P02 | 10m | 2 tasks | 2 files |
| Phase 03 P01 | 6m | 2 tasks | 2 files |
| Phase 03 P02 | verification window | 1 code task | 1 file |

## Accumulated Context

### Decisions

- Node version: 24 — matches upstream `.nvmrc` (24.16.0), confirmed in Phase 1 Plan 01
- MongoDB version: 7.0 — start with 7.0 per research, test compatibility
- mongo_version=7.0 declared as global in _common.sh (helpers v2.1 style)
- Admin password: 24 chars via ynh_string_random, stored in app settings
- db_pwd read back from `mongopwd` app setting for .env template
- librechat.env deployed with chmod 600 (contains JWT/DB secrets)
- [Phase 01]: Node 24 in manifest per upstream .nvmrc; main source sha256 computed at build
- Key decisions logged in PROJECT.md Key Decisions table
- [Phase 01]: Node 24 in manifest per upstream .nvmrc; main source sha256 computed at build
- [Phase 01]: mongo_version=7.0 global in _common.sh; admin password 24-char via ynh_string_random; db_pwd read back from mongopwd setting
- [Phase 01]: multi_instance=false for v1 to match single-instance Meilisearch wiring (gap closure option-b); per-app wiring deferred
- [Phase 02]: [resources.data_dir] declared with no subdir config — meilisearch creates its own db-path dir
- [Phase 02]: remove uses ynh_mongo_remove_db (db_user=db_name from settings), never ynh_remove_mongo — protects shared MongoDB
- [Phase 02]: install_dir/data_dir teardown left to YNH core; ynh_safe_rm guards package-owned data_dir/meilisearch subdir
- [Phase 03]: env merge = regenerate fresh template, append only user-added keys absent from it (managed keys always fresh); yaml never overwritten — only commented template sections for missing active top-level keys appended
- [Phase 03]: upstream latest release still v0.8.8-rc3, so 03-02 re-pinned same tag/sha256 unchanged; package bumped ~ynh1 → ~ynh2 to validate upgrade flow
- [Phase 03]: live upgrade user-confirmed — config/env/yaml/mongo/meili preserved, JWT not rotated, npm cache stripped, UI reachable

### Pending Todos

- Future upstream release: re-run bump flow (tag → url/sha256 pin → ~ynhN bump) + live verification

### Blockers/Concerns

- **Phase 1:** AUR build issues need workarounds (xlsx `allow-remote=true`, `unrun` missing, npm cache bloat)
- **Phase 1:** nginx config MUST include WebSocket upgrade headers and proxy_buffering off — silent failure otherwise
- ~~**Phase 3:** live upgrade (03-02) not yet run~~ — RESOLVED 2026-09-18 (user-approved live upgrade)

## Session Continuity

Last session: 2026-09-18
Stopped at: Completed 03-02-PLAN.md (phase 3 complete; manifest bump 05e3d5b, live upgrade user-approved)
Resume file: None
