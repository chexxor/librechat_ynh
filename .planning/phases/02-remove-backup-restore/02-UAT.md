---
status: testing
phase: 02-remove-backup-restore
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md]
started: 2026-09-18T21:52:02-05:00
updated: 2026-09-18T21:52:02-05:00
---

## Current Test

number: 1
name: Remove the app cleanly
expected: |
  On a live YunoHost test server with Phase 1 install working: run `yunohost app remove librechat`. Expect clean removal — librechat and meilisearch services stop and their systemd units are gone (`systemctl list-units 'librechat*' 'meilisearch'` shows nothing), `yunohost service status` no longer lists them, nginx config removed. Other MongoDB apps on the server keep working and their DBs are intact in `mongosh` (this app's namespaced DB was removed, nothing else).
awaiting: user response

## Tests

### 1. Remove the app cleanly
expected: `yunohost app remove librechat` stops librechat + meilisearch, deregisters both from YNH monitoring, removes units and nginx config, deletes only this app's namespaced MongoDB database — other Mongo apps unaffected (RMV-01..05)
result: [pending]

### 2. Backup produces a consistent archive
expected: `yunohost app backup librechat` succeeds and the app is still running/reachable right afterwards; archive (`yunohost backup list` / `yunohost backup display <archive>`) contains install_dir, data_dir (meilisearch index), nginx conf, and dump.bson (BACK-01, BACK-02)
result: [pending]

### 3. Restore recovers a fully working app
expected: `yunohost app restore librechat <archive>` completes and produces a working LibreChat UI at the domain via HTTPS — MongoDB data restored, meilisearch re-provisioned and running, nginx config back, both services "running" (BACK-03, BACK-04)
result: [pending]

### 4. Round-trip preserves data
expected: After backup → remove → restore, log in as admin and find the chat message/user created before the remove still present; Meilisearch index intact; no data loss (BACK-05, success criterion 4)
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0

## Gaps

[none yet]
