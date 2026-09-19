---
phase: 01-foundation-install
plan: 02
subsystem: install-scripts
tags: [yunohost, install, mongodb, meilisearch, nodejs, system-administration]
requires:
  - "01-foundation-install-01 (manifest, conf templates, script stubs)"
provides:
  - "scripts/_common.sh — librechat_build(), librechat_generate_secrets(), librechat_create_admin_user()"
  - "scripts/install — full 12-step install orchestration"
affects:
  - "Phase 2 (upgrade/backup/restore derive from these patterns)"
tech-stack:
  added: ["ynh_install_mongo", "ynh_mongo_setup_db", "ynh_setup_source", "ynh_config_add", "ynh_config_add_systemd", "ynh_string_random"]
patterns:
  - "Wrapper helpers in _common.sh, orchestration in install"
  - "AUR build workarounds isolated in librechat_build()"
key-files:
  created:
    - scripts/_common.sh
    - scripts/install
  modified: []
decisions:
  - "mongo_version=7.0 global in _common.sh (helpers v2.1 style)"
  - "Admin password 24 chars via ynh_string_random, stored in app settings"
  - "db_pwd read back from mongopwd setting for .env template"
metrics:
  duration: "~8m"
  completed: 2026-09-18
  tasks: 2
---

# Phase 1 Plan 2: Install Script Summary

**One-liner:** Full `yunohost app install` orchestration — MongoDB via ynh_install_mongo, LibreChat build with the 3 AUR workarounds, Meilisearch native binary, config/nginx/systemd templating, admin user creation, and password delivery via email + screen output.

## What Was Done

### task 1: _common.sh (commit 9914e4d)
- `mongo_version="7.0"` global for `ynh_install_mongo` (helpers v2.1 uses global, not flag)
- `librechat_build()` — exact AUR order: `npm config set allow-remote true` → `npm ci` → `npm install --no-save unrun` → `npx turbo run build --no-daemon` → `rm -rf "$install_dir/.npm"`
- `librechat_generate_secrets()` — 64-char JWT secrets, 64-char admin panel secret, 32-char meili master key, 24-char admin password (CONTEXT.md locked decision); all persisted via `ynh_app_setting_set`
- `librechat_create_admin_user()` — `node config/create-user.js "$email" "Admin" "admin" "$password" --email-verified=true`

### task 2: scripts/install (commit 4a2d311)
12-step flow: dependencies → sources (main + meilisearch binary, chmod +x) → MongoDB DB (`ynh_sanitize_dbid`, `ynh_mongo_setup_db`, read back `mongopwd`) → secrets → build → config (`librechat.env` chmod 600, `librechat.yaml`) → nginx → systemd (both units + `yunohost service add` x2) → start services → admin user → email + `ynh_print_info` password → completion.

## Deviations from Plan

None — plan executed exactly as written.

Minor discretionary details (within "OpenCode's Discretion"): email body wording; `chown/chmod 600` on librechat.env added (Rule 2 — secrets file contains JWT keys and DB credentials, world-readable otherwise).

## Verification

- `bash -n` passes on both scripts
- All template variables (`__PORT__`, `__DB_*__`, `__JWT_*__`, `__MEILI_MASTER_KEY__`, `__ADMIN_PANEL_SESSION_SECRET__`) present in conf templates, corresponding bash vars in scope before each `ynh_config_add`
- No hardcoded port 3080 in scripts

## Self-Check: PASSED
- scripts/_common.sh: FOUND
- scripts/install: FOUND
- Commit 9914e4d: FOUND
- Commit 4a2d311: FOUND
