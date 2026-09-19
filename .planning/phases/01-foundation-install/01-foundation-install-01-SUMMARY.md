---
phase: 01-foundation-install
plan: 01
subsystem: yunohost-package-skeleton
tags: [manifest, nginx, systemd, env, yaml, docs, stubs]
requires: []
provides:
  - "Valid YNH packaging v2 manifest.toml"
  - "nginx/systemd/env/yaml configuration templates"
  - "Catalog doc stubs and lifecycle script stubs"
affects: [02-install-script]
tech-stack:
  added: []
  patterns:
    - "YNH packaging v2 manifest.toml (Wekan-derived structure)"
    - "__VAR__ template placeholders for ynh_config_add"
key-files:
  created:
    - manifest.toml
    - conf/nginx.conf
    - conf/librechat.service
    - conf/meilisearch.service
    - conf/librechat.env
    - conf/librechat.yaml
    - doc/DESCRIPTION.md
    - doc/ADMIN.md
    - doc/screenshots/.gitkeep
    - scripts/upgrade
    - scripts/remove
    - scripts/backup
    - scripts/restore
  modified: []
decisions:
  - "Node 24 in manifest (matches upstream .nvmrc 24.16.0), overriding earlier STATE note that said start with 22"
  - "main source sha256 = FILL_ME placeholder, computed at build time"
duration: ~10 min
completed: 2026-09-18
---

# Phase 1 Plan 1: YunoHost Package Skeleton Summary

**One-liner:** Full YNH packaging v2 skeleton — manifest with Node 24/Meilisearch/action sources, hardened systemd units, WebSocket+SSE-ready nginx template, secrets env template, 4-provider yaml template, and lifecycle script stubs.

## Tasks Completed

| Task | Description | Commit | Files |
| ---- | ----------- | ------ | ----- |
| 1 | manifest.toml with resources, install questions, sources | 116691c | manifest.toml |
| 2 | All 5 config templates | dbcef08 | conf/nginx.conf, conf/librechat.service, conf/meilisearch.service, conf/librechat.env, conf/librechat.yaml |
| 3 | Doc stubs, script stubs, .gitkeep | 7fab9a1 | doc/*, scripts/{upgrade,remove,backup,restore} |

## Verification Results

- manifest.toml: packaging v2, Node 24, dual-arch Meilisearch v1.53.2 sources with sha256, admin_email install question, ldap/sso = false, permissions, ports 3080, system_user allow_email. ✅
- nginx.conf: `proxy_set_header Upgrade`, `proxy_buffering off`, `__PATH__`/`__PORT__` variables, explanatory comment. ✅
- librechat.service: `EnvironmentFile=__INSTALL_DIR__/librechat.env`, full hardened sandboxing + capability denials from RESEARCH.md. ✅
- meilisearch.service: ExecStart with master key/db-path templates, basic hardening. ✅
- librechat.env: MONGO_URI (DB_USER/DB_PWD/DB_NAME), SEARCH=false, JWT, admin panel secret placeholders. ✅
- librechat.yaml: openAI, anthropic, ollama (no key needed), openRouter blocks, commented registration section. ✅
- All 4 script stubs: bash shebang, helpers source, ynh_abort_if_errors, progression messages. ✅
- doc/DESCRIPTION.md, doc/ADMIN.md written with substantive content. ✅

## Deviations from Plan

None — plan executed exactly as written. Note: STATE.md previously suggested "start with Node 22"; the plan and RESEARCH.md explicitly require Node 24 (upstream .nvmrc), which was followed.

## Self-Check: PASSED
