---
phase: 02-remove-backup-restore
verified: 2026-09-18T00:00:00Z
status: human_needed
score: 9/9 static must-haves verified; 4 live outcome criteria pending human round-trip
human_verification:
  - test: "Backup: yunohost app backup librechat on live server; confirm app reachable after, archive contains dump.bson, install_dir, data_dir, nginx conf"
    expected: "Backup succeeds non-destructively; services running afterwards; archive inspection shows all declared paths + dump.bson"
    why_human: "Requires live YunoHost server; no server exists in this environment"
  - test: "Remove: yunohost app remove librechat; confirm units gone, other MongoDB apps' DBs intact in mongosh"
    expected: "Clean removal; namespaced DB gone; other Mongo apps unaffected (RMV-05)"
    why_human: "Requires live server with genuinely shared MongoDB + other apps"
  - test: "Restore: yunohost app restore librechat <archive>"
    expected: "Working LibreChat UI at domain over HTTPS; both services 'running'"
    why_human: "Requires live server"
  - test: "Data round-trip: seed a chat message + user before backup, verify present after restore"
    expected: "Chat history and user accounts preserved (BACK-05, success criterion 4)"
    why_human: "Requires live server"
---

# Phase 2: Remove + Backup/Restore — Verification Report

**Phase Goal:** `yunohost app remove`, `yunohost app backup`, and `yunohost app restore` all work correctly — remove is safe for shared MongoDB, backup produces consistent snapshots, restore fully recovers the app.
**Verified:** 2026-09-18
**Status:** human_needed (all static/code verification passed; live round-trip explicitly deferred and evidenced as pending)
**Re-verification:** No — initial verification

## Context

This is a YunoHost package with **no live YunoHost server** in this environment. Success criteria 1–4 are live-server behaviors. Plan 02-02's task 3 checkpoint (`checkpoint:human-verify`) was auto-advanced via `workflow.auto_advance=true` and is honestly documented as PENDING in 02-02-SUMMARY.md ("No live verification results were fabricated") and in REQUIREMENTS.md (RMV = Complete, BACK-* = Pending). Static verification below confirms the code implements all planned patterns correctly.

## Goal Achievement

### Observable Truths (must_haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Remove stops both services and deregisters from YNH monitoring | ✓ VERIFIED (static) | scripts/remove:23–36 — guarded `ynh_systemctl stop` x2, if-guarded `yunohost service remove` x2 |
| 2 | Remove deletes only namespaced MongoDB DB+user; other apps untouched | ✓ VERIFIED (static) | scripts/remove:56–69 — db_name from settings, `db_user=$db_name`, `ynh_mongo_remove_db --db_user=... --db_name=...`; NO live call to `ynh_remove_mongo` (grep: only comment forbidding it, line 66) |
| 3 | Remove cleans nginx, systemd units, meilisearch binary, Node (ref-counted) | ✓ VERIFIED (static) | scripts/remove:41–49 (units+nginx), 76 (`ynh_nodejs_remove`), 82–84 (binary, tolerant) |
| 4 | data_dir crashloop risk fixed — manifest declares `[resources.data_dir]` | ✓ VERIFIED (static) | manifest.toml:69; `__DATA_DIR__` used in conf/librechat.service:30 and conf/meilisearch.service:9,18 |
| 5 | Backup produces archive with mongodump, install_dir, data_dir, nginx conf; app left running | ✓ VERIFIED (static) | scripts/backup:36–42 (three ynh_backup declarations), :66 (`ynh_mongo_dump_db --database=$db_name > ./dump.bson`, cwd pattern exact), :75–76 (explicit restart meili→app) |
| 6 | Restore fully recovers Mongo data, config, meili, nginx, units, service state | ✓ VERIFIED (static) | scripts/restore:42 (`ynh_install_mongo` no-arg, uses `mongo_version="7.0"` from _common.sh:17), :50 `ynh_restore_everything`, :58 `ynh_mongo_restore_db --database=$db_name < ./dump.bson`, :67 node fallback 24, :76–77 meili re-download via source_id, :85–90 unit regeneration + `yunohost service add` x2, :97–99 start LAST meili→app→nginx reload |
| 7 | Round-trip preserves chat history, users, meili index | ⏳ PENDING | Requires live backup→remove→restore; checkpoint auto-advanced, evidenced pending in 02-02-SUMMARY.md |

**Score:** 6/6 static truths verified; 1 live truth pending (round-trip / success criteria 1–4 umbrella)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `manifest.toml` | `[resources.data_dir]` declaration | ✓ VERIFIED | Line 69 |
| `scripts/remove` | Full lifecycle, ≥30 lines | ✓ VERIFIED | 97 lines, `bash -n` clean |
| `scripts/backup` | Declare-then-dump, explicit stop/restart, ≥25 lines | ✓ VERIFIED | 78 lines, `bash -n` clean |
| `scripts/restore` | Full recovery w/ re-provisioning, ≥40 lines | ✓ VERIFIED | 101 lines, `bash -n` clean |

(All 4 artifacts: exists ✓, substantive ✓, wired ✓ — wired via sourced helpers and _common.sh.)

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| scripts/remove | scripts/_common.sh | mongo_version global + mongo helpers | ✓ WIRED | `ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name` (line 69); remove sources /usr/share helpers; _common.sh provides `mongo_version="7.0"` |
| scripts/backup | scripts/_common.sh | `source ../settings/scripts/_common.sh` | ✓ WIRED | Line 11 — exact pattern |
| scripts/backup | ynh_mongo_dump_db | `--database=$db_name > ./dump.bson` | ✓ WIRED | Line 66 — exact no-absolute-path Wekan form |
| scripts/restore | ynh_mongo_restore_db | `--database=$db_name < ./dump.bson` | ✓ WIRED | Line 58 — unconditional |
| scripts/restore | ynh_setup_source | `--dest_dir=/usr/bin --source_id=meilisearch` | ✓ WIRED | Line 76 + chmod 77 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| RMV-01 | 02-01 | Stops/disables systemd services | ✓ SATISFIED (static) | scripts/remove:23–43 |
| RMV-02 | 02-01 | Namespaced MongoDB DB only, never ynh_remove_mongo | ✓ SATISFIED (static) | scripts/remove:69; no live `ynh_remove_mongo` call |
| RMV-03 | 02-01 | Removes Meilisearch binary and data | ✓ SATISFIED (static) | scripts/remove:82–84, 95 (`ynh_safe_rm "$data_dir/meilisearch"`) |
| RMV-04 | 02-01 | Removes app data dir and nginx config | ✓ SATISFIED (static) | scripts/remove:49; install_dir/data_dir left to YNH core (`--purge`), documented lines 87–93 |
| RMV-05 | 02-01 | Remove breaks no other YunoHost apps | ⏳ PENDING LIVE | Static guarantees in place (no ynh_remove_mongo, ref-counted ynh_nodejs_remove, $app-scoped teardown); live proof deferred |
| BACK-01 | 02-02 | Consistent mongodump via ynh_mongo_dump_db | ✓ SATISFIED (static) | scripts/backup:56–66 (stop→dump, exact form) |
| BACK-02 | 02-02 | Backup includes config, data dir, meili data | ✓ SATISFIED (static) | scripts/backup:36–42 |
| BACK-03 | 02-02 | Restore re-downloads meili binary, ynh_mongo_restore_db | ✓ SATISFIED (static) | scripts/restore:58, 76–77 |
| BACK-04 | 02-02 | Restore restores config, nginx, service state | ✓ SATISFIED (static) | scripts/restore:50, 85–90, 97–99 |
| BACK-05 | 02-02 | Restore returns working app | ⏳ PENDING LIVE | Code complete; live round-trip pending (evidenced in 02-02-SUMMARY.md). REQUIREMENTS.md correctly marks BACK-01..05 as "Pending" pending live proof |

No orphaned requirements: REQUIREMENTS.md phase 2 mapping = exactly RMV-01..05 + BACK-01..05, all claimed by plans.

Committed artifacts verified in summaries: a91d250, 3a54707, d80a648, 7105682.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | — | No TODO/FIXME/placeholder/stub patterns in scripts/ | — | — |

`bash -n` passes for remove, backup, restore. No forbidden helper calls. All tolerances (|| true, if-guards) per plan.

### Human Verification Required — Live Round-Trip (from 02-02-PLAN task 3)

1. Ensure app running; seed test chat message + user.
2. `yunohost app backup librechat` → app reachable after; archive contains dump.bson + install_dir + data_dir + nginx conf.
3. `yunohost app remove librechat` → clean stop/removal; other Mongo apps' DBs intact in mongosh (RMV-05).
4. `yunohost app restore librechat <archive>` → UI reachable, login works, seeded chat message/user present (BACK-05), both services "running".

### Gaps Summary

No code gaps. All four scripts + manifest fix are fully implemented, syntactically valid, follow the researched Wekan-verified patterns exactly, and every key link is statically wired. The remaining uncertainty is purely dynamic/live behavior: backup coherence, restore recovery, shared-MongoDB safety, and data round-trip integrity. The deferral is honestly tracked (02-02-SUMMARY "PENDING", REQUIREMENTS.md BACK-* = Pending, RMV-05 live note). Phase outcome requires the human round-trip on a live YunoHost test server before full "passed" status.
