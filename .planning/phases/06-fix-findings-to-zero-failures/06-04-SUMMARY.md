---
phase: 06-fix-findings-to-zero-failures
plan: 04
subsystem: infra
tags: [yunohost, package_check, meilisearch, mongodb, systemd, shell]

requires:
  - phase: 06-01
    provides: headline secret-token fix + xtrace guards + scope/triage records
  - phase: 05
    provides: runnable package_check environment + valid tests.toml
provides:
  - Iterative fix→run→triage loop resolving every install-blocking package bug
  - "test verdicts green for package_linter, install.root, backup_restore, upgrade"
affects: [06-05, 07]
tech-stack:
  added: []
  patterns:
    - "fix→run→triage loop: full package_check suite every cycle, quote log evidence, bucket each finding"
    - "isolated in-container reproduction (incus launch + strace) to root-cause a service failure without burning a 15-min cycle"
key-files:
  created:
    - .planning/phases/06-fix-findings-to-zero-failures/triage/triage-log.md
    - .planning/phases/06-fix-findings-to-zero-failures/cycles/
  modified:
    - conf/librechat.env
    - conf/nginx.conf
    - conf/meilisearch.service
    - scripts/_common.sh
    - scripts/install
    - scripts/upgrade
    - scripts/backup
    - scripts/restore

key-decisions:
  - "upgrade.05e3d5b exempted out-of-scope-by-design (user decision at checkpoint): v1.0 artifact predates Phase 4 manifest fix"
  - "meilisearch failure root-caused as dumps/ created in unwritable CWD -> WorkingDirectory=__DATA_DIR__"
  - "restore must recreate the mongo user with the persisted db_pwd (mongodump excludes users)"
  - "cycle logs redacted of real admin/mongo passwords before commit"

patterns-established:
  - "Pre-create runtime dirs owned by $app (logs, meilisearch) because ProtectSystem=full blocks creation at runtime"
  - "Read persisted settings (db_pwd) and pass them into mongo helpers so operations are idempotent"

requirements-completed: [POLS-01]

duration: ~13 cycles (~4-21 min each)
completed: 2026-09-20
---

# Phase 6 Plan 04: Fix Loop to Zero In-Scope Failures Summary

**Thirteen fix→run→triage cycles resolved every install-blocking package bug — secret-token mismatch, nginx duplicate directives, dotenv loading, `db_pwd` key, meilisearch CWD, and restore-time mongo user — turning 4 in-scope tests green.**

## Performance

- **Duration:** 13 cycles over ~6 hours wall-clock
- **Completed:** 2026-09-20
- **Tasks:** fix loop + triage
- **Files modified:** 8 package files + planning records

## Accomplishments
- Fixed the headline `admin_panel_secret` / `__ADMIN_PANEL_SESSION_SECRET__` mismatch that aborted every install
- Fixed cascading install bugs: literal `__VAR__` token in env header comment, duplicate nginx proxy directives, `MONGO_URI` not loaded for `create-user.js`, wrong mongo password setting key (`mongopwd` → `db_pwd`)
- Root-caused the persistent meilisearch `Permission denied (os error 13)` to `dumps/` being created in an unwritable CWD, via an isolated in-container strace reproduction
- Fixed restore-time `Authentication failed` by recreating the mongo user with the persisted `db_pwd`
- All 4 in-scope tests (`package_linter`, `install.root`, `backup_restore`, `upgrade`) green by cycle 13

## Key Fix Commits

1. `57d2ef6` — reconcile admin panel secret token (headline)
2. `d48cfd0` — guard secret handling against xtrace + log redaction tool
3. `ccc5623` — remove literal `__VAR__` token from env header comment
4. `f1242c9` — remove duplicate nginx proxy_http_version directives
5. `9ce46fc` — load librechat.env before create-user.js
6. `f01a3c5` — read mongo password from `db_pwd` setting key
7. `3107b60` — idempotent mongo password on upgrade; drop bad ynh_systemctl flag
8. `2da500f` — pre-create meilisearch data dir in install
9. `a05ca07` — drop ProtectHome from meilisearch unit
10. `fe84e10` — set meilisearch `WorkingDirectory` to data dir (the real fix)
11. `1be66f5` — recreate mongo user with persisted `db_pwd` on restore

## Decisions Made
- `upgrade.05e3d5b` exempted out-of-scope-by-design per user checkpoint (v1.0 artifact predates the Phase 4 manifest schema fix; uninstallable on modern YunoHost)
- Revised zero-failure bar = 4 in-scope tests
- Cycle diagnostic logs redacted of real admin/mongo passwords

## Deviations from Plan
- The fix loop ran **13 cycles** rather than the handful anticipated, because each cycle revealed one new install-blocking bug. All were in-scope package defects (fix-per-doctrine), not scope creep.

## Issues Encountered
- VM NIC flapped between `192.168.1.83`/`.85` mid-run in several cycles; `eth0-watchdog.service` restored it each time (environmental, no code change, no retry needed).

## Next Phase Readiness
- Phase 6 Plan 05 archives the single clean run as POLS-01.

---
*Phase: 06-fix-findings-to-zero-failures*
*Completed: 2026-09-20*
