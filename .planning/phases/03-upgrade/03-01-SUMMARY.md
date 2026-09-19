---
phase: 03-upgrade
plan: 01
subsystem: infra
tags: [yunohost, bash, librechat, mongodb, meilisearch, upgrade, config-merge]

# Dependency graph
requires:
  - phase: 01-foundation-install
    provides: librechat_build helper, secrets persisted in app settings, templates, systemd/nginx conf
  - phase: 02-remove-backup-restore
    provides: idempotent provisioning discipline, ynh_mongo_remove_db patterns
provides:
  - scripts/upgrade — full config-preserving upgrade orchestration
  - librechat_regen_and_merge_configs helper in scripts/_common.sh
affects: [03-live-upgrade, future version bumps]

# Tech tracking
tech-stack:
  added: []
  patterns: [regen-and-merge config strategy, --keep on ynh_setup_source, idempotent provisioning]

key-files:
  created: []
  modified:
    - scripts/_common.sh
    - scripts/upgrade

key-decisions:
  - "librechat.env merge: regenerate template fresh, append only user-added keys not present in template (managed keys always fresh)"
  - "librechat.yaml never overwritten: only commented template sections for missing active top-level keys are appended"
  - "Appended template sections for missing keys include active key lines + indented sub-lines (e.g. version:, registration:)"

patterns-established:
  - "Upgrade pattern: deps → source (--keep) → idempotent mongo → build → config merge → regen rules → restart (meili then app)"

requirements-completed: [UPGR-01, UPGR-02, UPGR-03, UPGR-04]

# Metrics
duration: 6min
completed: 2026-09-18
---

# Phase 3 Plan 01: Upgrade Script Summary

**Full upgrade orchestration with --keep config preservation and regen-and-merge strategy: managed env keys fresh, user-added keys verbatim, librechat.yaml never overwritten**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-18T22:11:42Z
- **Completed:** 2026-09-18T22:17Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `librechat_regen_and_merge_configs()` to `scripts/_common.sh`: reads back all secrets/db_pwd from app settings (ynh_die on missing), regenerates librechat.env keeping user-added keys, preserves librechat.yaml verbatim while appending commented template sections for missing top-level keys
- Replaced the `scripts/upgrade` stub with the full orchestration: idempotent deps → `ynh_setup_source --keep="librechat.env librechat.yaml"` → idempotent mongo re-provision (never drops) → `librechat_build` → config merge → nginx/systemd regen → restart meili then app
- No admin-user recreation, no secret regeneration, no password mail on upgrade

## task Commits

Each task was committed atomically:

1. **task 1: Config merge helper in _common.sh** - `fe50d98` (feat)
2. **task 2: Full upgrade script** - `ba94ac6` (feat)

## Files Created/Modified
- `scripts/_common.sh` - Added librechat_regen_and_merge_configs helper (~119 lines)
- `scripts/upgrade` - Full upgrade script replacing the auto-generated stub

## Decisions Made
- Env merge: fresh template wins for managed keys (fixes stale port/URI); only keys absent from the fresh template are appended from the old file
- Yaml merge implemented as line-level scan: track current top-level template section, append whole section only when its active top-level key (version:, registration:, endpoints:, ...) is absent from the user's file as an active key
- No `ynh_store_file_checksum` / backup_file diff helpers — explicit merge logic per research doc

## Deviations from Plan

None - plan executed exactly as written.

**Test method deviation (harness only):** the plan's "bash dry merge test on fixture files" was executed with an ad-hoc stubbed-yuno-helpers fixture test in a temp dir (11/11 assertions pass: fresh managed values, user keys preserved verbatim, missing-setting death, yaml-missing regeneration, no .new leftovers). The fixture harness itself lives outside the repo (Windows msys limitations for chown/stat).

## Issues Encountered
- Git-bash fixture quirks (CRLF glob matching with `$2` empty expansion, chmod reported as 644 on msys) cost debugging time but were harness-side, not helper bugs — verified via `bash -x` traces

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Ready for 03-02 (live upgrade verification via `yunohost app upgrade librechat`)
- Static verify gates all pass: bash -n clean on both scripts; `--keep` present; librechat_build called; mongopwd read-back present; no create-user/generate_secrets/mail calls; `.npm` cache strip still inside librechat_build

---
*Phase: 03-upgrade*
*Completed: 2026-09-18*

## Self-Check: PASSED
- scripts/_common.sh FOUND, scripts/upgrade FOUND
- Commits fe50d98, ba94ac6 present in git log
