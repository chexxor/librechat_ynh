---
phase: 02-remove-backup-restore
plan: 02
subsystem: backup-restore
tags: [bash, yunohost-helpers, mongodb, mongodump, meilisearch, systemd]

# Dependency graph
requires:
  - phase: 02-remove-backup-restore plan 01
    provides: data_dir resource declaration, scripts/remove full lifecycle, remove checkpoint approval
  - phase: 01-setup
    provides: install scripts, systemd unit templates, _common.sh globals (mongo_version)
provides:
  - scripts/backup — declare-then-dump backup with explicit stop/restart
  - scripts/restore — full recovery script with idempotent dependency re-provisioning
  - Round-trip capability: backup → remove → restore preserves mongo data, meili index, config
affects: [03-next-phase, backup-restore docs, maintenance workflows]

# Tech tracking
tech-stack:
  added: []
  patterns: [declare-then-dump order (Wekan pattern), cwd-relative ./dump.bson archive sweep, unit regeneration from templates instead of restoring unit files, unconditional idempotent re-provisioning helpers]

key-files:
  created: []
  modified: [scripts/backup, scripts/restore]

key-decisions:
  - "Backup declares files BEFORE stopping services (declaration-then-dump) so YNH core has the full map fenced in"
  - "mongodump streams to ./dump.bson with NO absolute path — YNH core stages cwd and sweeps the file into the archive"
  - "Both services explicitly stopped for dump coherence and explicitly restarted (meili first) at backup end — do not rely on core restart"
  - "systemd units regenerated from conf/ templates on restore (fresh secret injection), never restored from archive"
  - "/usr/bin/meilisearch binary not included in archive — re-downloaded via ynh_setup_source per-arch sha256"
  - "mongorestore runs unconditionally (no existence branch); dependencies re-provisioned idempotently unconditionally"
  - "Node re-provisioning guarded with fallback nodejs_version=24 matching manifest [resources.nodejs]"
  - "Services start LAST on restore (meili → app → nginx reload) to avoid LibreChat writing before mongorestore"

patterns-established:
  - "Special cwd context in backup/restore: source ../settings/scripts/_common.sh (differs from install)"
  - "Unit regeneration from templates + yunohost service add registration on restore"

requirements-completed: [BACK-01, BACK-02, BACK-03, BACK-04, BACK-05]

# Metrics
duration: "(unfinished — pending live verification; sessions ~10min total)"
completed: 2026-09-18
---

# Phase 02 Plan 02: Backup & Restore Scripts Summary

**scripts/backup (declare→stop→mongodump→restart) and scripts/restore (archive + mongorestore + meilisearch re-download + unit regeneration + ordered startup), pending live round-trip verification**

## Performance

- **Duration:** ~10 min automated work (task 3 checkpoint not yet executed live)
- **Completed:** 2026-09-18
- **Tasks:** 2 of 2 auto tasks complete; task 3 checkpoint auto-advanced (workflow.auto_advance=true)
- **Files modified:** 2

## Accomplishments
- scripts/backup: declares install_dir, data_dir, nginx conf; stops librechat + meilisearch for coherence; streams mongodump to ./dump.bson (Wekan-exact cwd pattern); explicitly restarts meili→app so backup is non-destructive
- scripts/restore: re-provisions MongoDB (ynh_install_mongo, no-args form) and Node (fallback 24) idempotently; restores all declared paths; unconditional mongorestore from stdin; re-downloads meilisearch binary via ynh_setup_source (per-arch sha256); regenerates both systemd units from templates; registers services with yunohost service add; starts meili→app→nginx reload LAST

## task Commits

Each task was committed atomically:

1. **task 1: Implement scripts/backup (stop, dump, declare, restart)** - `d80a648` (feat)
2. **task 2: Implement scripts/restore (full recovery with dependency re-provisioning)** - `7105682` (feat)
3. **task 3: Live round-trip verification (checkpoint:human-verify)** - auto-advanced, not executed live

**Plan metadata:** see docs commit (this plan's final commit)

## Files Created/Modified
- `scripts/backup` - Declare-then-dump backup with service stop/restart (~75 lines)
- `scripts/restore` - Full recovery script with dependency re-provisioning (~100 lines)

## Decisions Made
See key-decisions frontmatter. All follow 02-RESEARCH.md patterns exactly (Wekan backup form, restore with re-provisioning, unit regeneration over archive restore of units).

## Deviations from Plan

### Checkpoint handling (not a code deviation)
- **Task 3 checkpoint (human-verify)**: auto-advanced via `workflow.auto_advance=true` — no live server round-trip was executed. **Live verification (backup → remove → restore with data intact) is PENDING and must be performed manually by the user on a live YunoHost test server** using the steps documented in the plan's task 3 <how-to-verify>. No live verification results were fabricated.

## Issues Encountered
- None in automated work. Live round-trip verification is deferred (see above).

## User Setup Required

**Manual live verification needed.** On a live YunoHost test server, execute the round-trip steps from the plan (task 3): backup with app staying up, remove, restore, then confirm working UI + preserved chat history/users/meili index + other Mongo apps unaffected (RMV-05).

## Next Phase Readiness
- Backup/restore code paths complete; remove lifecycle from plan 02-01 complete
- Blocker: live round-trip proof (phase success criteria #2–4) still pending human execution on a test server
- Ready for phase 03 (config upgrade merge) once code; recommend running live verification before/alongside phase 3

---
*Phase: 02-remove-backup-restore*
*Completed: 2026-09-18*

## Self-Check: PASSED

- `scripts/backup` and `scripts/restore` exist and pass `bash -n`
- Commits verified: `d80a648` (feat 02-02 backup), `7105682` (feat 02-02 restore) via `git log --grep="02-02"`
- Key-link greps verified: `../settings/scripts/_common.sh` in both scripts; `ynh_mongo_dump_db ... > ./dump.bson` in backup; `ynh_mongo_restore_db ... < ./dump.bson`, `ynh_restore_everything`, `source_id=meilisearch`, both `.service` templates, `action=start` ordering in restore
- Live round-trip verification (task 3): **PENDING** — deferred; no results fabricated
