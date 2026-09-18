# Project Research Summary

**Project:** LibreChat YunoHost Package (librechat_ynh)
**Domain:** YunoHost native app package wrapping LibreChat (Node.js + MongoDB + Meilisearch)
**Researched:** 2026-09-18
**Confidence:** HIGH

## Executive Summary

LibreChat is an open-source ChatGPT alternative that proxies to multiple LLM providers (OpenAI, Anthropic, etc.) with conversation history, search, and multi-user support. The YunoHost ecosystem needs this as a native (Docker-free) package, following the established pattern used by Wekan and MyDrive — both MongoDB-backed Node.js apps packaged for YNH. The research confirms this is a well-trodden path: YunoHost provides official helpers for Node.js deployment (`[resources.nodejs]`), MongoDB setup (`ynh_install_mongo`), and systemd/nginx management (`ynh_config_add_systemd`, `ynh_config_add_nginx`), all of which map cleanly to LibreChat's architecture.

The recommended approach is a manifest.toml v2 package that orchestrates a multi-step install: source download from GitHub, `npm ci` + turbo build, MongoDB database/user creation, Meilisearch binary installation, hardened systemd service setup, and nginx reverse proxy with WebSocket/SSE support. The Wekan YNH package serves as a proven reference — it handles the same MongoDB + Node.js stack with tested patterns for namespaced database cleanup, mongodump-based backups, and config preservation on upgrade.

The **three key risks** are: (1) LibreChat's npm build has AUR-documented issues (`xlsx CDN tarball`, `unrun` missing resolution, npm cache bloat) that require workarounds; (2) MongoDB shared-instance conflicts — the remove script must never call `ynh_remove_mongo`, only app-scoped `ynh_mongo_remove_db`; (3) nginx misconfiguration will silently break WebSocket streaming and SSE responses. All three are preventable with known, tested solutions from the AUR LibreChat package and the Wekan YNH package.

## Key Findings

### Recommended Stack

The stack is a standard YunoHost native app pattern with three services: a Node.js runtime, a MongoDB database, and a Meilisearch search engine. YNH provides helpers for everything except Meilisearch, which requires manual binary installation. The Wekan YNH package is the nearest analog and directly confirms the MongoDB, systemd, and nginx patterns.

**Core technologies:**
- **YunoHost packaging format v2 (manifest.toml):** Standard since YNH 11.1. Handles resources (sources, nodejs, apt, ports, system_user) automatically. Required for new packages.
- **Node.js 22/24 LTS (via `[resources.nodejs]`):** LibreChat `.nvmrc` currently specifies Node 24. YNH uses the `n` version manager. Start with `version = "22"` but be prepared to bump to `"24"` — verify against upstream `.nvmrc` on each upgrade.
- **MongoDB 7.0 (via `ynh_install_mongo`):** Installed from upstream repo (Debian Bookworm doesn't ship MongoDB due to SSPL). Wekan uses `mongo_version="8.0"` successfully; start with 7.0 for LibreChat compatibility.
- **Meilisearch latest v1.x:** No YNH helper exists. Install as native binary from GitHub releases via `[resources.sources]` + custom systemd unit. Must be re-downloaded during restore.
- **nginx (YNH-managed):** Reverse proxy template must set `proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_buffering off;` — without these, chat streaming silently fails.
- **libvips42 / build-essential (apt):** Required for `sharp` native module compilation. Include both in `[resources.apt]`.

### Expected Features

**Must have (table stakes) — required for YNH catalog acceptance:**
- End-to-end `yunohost app install`: source download, npm build, MongoDB + Meilisearch setup, nginx + systemd configuration
- Working LibreChat web UI behind HTTPS with WebSocket/SSE streaming
- `yunohost app upgrade` that preserves user `.env` and `librechat.yaml` config (never overwrite)
- `yunohost app remove` that only removes app-scoped database (never `ynh_remove_mongo`)
- `yunohost app backup` using `ynh_mongo_dump_db` for consistent MongoDB snapshots
- `yunohost app restore` that re-installs Meilisearch binary and restores MongoDB
- Valid manifest.toml (packaging v2), dedicated system user, proper permissions

**Should have (competitive):**
- One-command install of LibreChat + MongoDB + Meilisearch (the whole point of the package)
- Native (Docker-free) install targeting low-RAM devices (Raspberry Pis, small VPSes)
- Auto-updating source URLs via `autoupdate.strategy = "latest_github_tag"` (reduces maintainer burden)
- Correct WebSocket + SSE nginx config out of the box (many self-hosters get this wrong)

**Defer (v2+):**
- SSO/LDAP integration — LibreChat has its own auth; YNH LDAP integration requires upstream changes. Declare `sso = false`, `ldap = false`.
- YNH config panel — LibreChat already has `librechat.yaml`. Wrapping adds maintenance burden.
- Multi-domain install — single domain per install is sufficient for v1.
- `change_url` script — most YNH apps ship this, but it's not critical for MVP.

### Architecture Approach

Three-service architecture: LibreChat (Node/Express API + React SPA) talks to MongoDB on port 27017 and Meilisearch on port 7700. All user traffic enters through YNH-managed nginx, which terminates TLS and proxies to LibreChat on a local port. Two systemd services run: `librechat.service` (hardened sandbox with NoNewPrivileges, PrivateTmp, ProtectSystem=full) and `meilisearch.service` (standalone binary). Data lives in three locations: `/var/www/librechat/` (application code), `/home/yunohost.app/librechat/` (user data), and `/var/log/librechat/` (logs).

**Major components:**
1. **nginx (YNH-managed)** — TLS termination, reverse proxy, WebSocket upgrade headers, SSE buffering disabled
2. **LibreChat API (Node/Express)** — LLM proxy, conversation management, auth, serves React SPA; communicates with MongoDB, Meilisearch, external LLM providers
3. **LibreChat UI (React SPA)** — Frontend served by API server on same origin
4. **MongoDB** — Conversation storage, user data, agent config (via `ynh_install_mongo` + `ynh_mongo_setup_db`)
5. **Meilisearch** — Message/conversation search index (native binary, custom systemd unit)

### Critical Pitfalls

1. **AUR Build Issues (xlsx CDN tarball, unrun missing, npm cache bloat):** LibreChat's turbo monorepo has three known build problems. Prevention: set `npm config set allow-remote=true`, run `npm install --no-save unrun` before frontend build, and clean `.npm/_cacache/` post-build to avoid 500MB+ cache bloat.

2. **Config Overwrite on Upgrade:** `ynh_setup_source --full_replace` wipes user `.env` and `librechat.yaml`. Prevention: use `--keep="librechat.env librechat.yaml"` and implement a merge helper that adds new keys without removing user customizations.

3. **WebSocket/SSE Silent Failure:** nginx default config breaks LibreChat streaming. Prevention: the nginx template MUST include `proxy_http_version 1.1`, upgrade headers, and `proxy_buffering off`. Without these, chat responses are blank with no error message.

4. **MongoDB Shared Instance Conflict:** Calling `ynh_remove_mongo` in the remove script destroys the global MongoDB service, breaking all other MongoDB-using YNH apps. Prevention: use ONLY `ynh_mongo_remove_db --db_user --db_name` to remove app-scoped database/user.

5. **Inconsistent MongoDB Backup:** Raw data directory copy produces corrupt snapshots. Prevention: always use `ynh_mongo_dump_db` during backup (Wekan pattern), never raw file backup.

## Implications for Roadmap

Based on research, the package can be built in 3 phases with clear dependency ordering:

### Phase 1: Package Skeleton + Install Script (Foundation)
**Rationale:** Everything depends on a working install. This is the highest-risk, most complex phase. It validates the stack (build from source, MongoDB setup, Meilisearch binary install) and establishes the YNH structure.
**Delivers:** `yunohost app install librechat` works end-to-end with MongoDB, nginx, hardened systemd service, and working LibreChat UI behind HTTPS.
**Addresses:** Table stake features: install, nginx with WebSocket/SSE, systemd service.
**Avoids:** Pitfalls 1 (AUR build — implement `librechat_build()` with xlsx/unrun workarounds), Pitfall 3 (WebSocket/SSE — include correct headers in nginx template), Pitfall 5 (sharp/libvips — include libvips42 in apt).
**Key decisions needed in this phase:**
- Node version: 22 vs 24 (check upstream `.nvmrc` at build time)
- MongoDB version: 7.0 vs 8.0 (Wekan uses 8.0, but test with LibreChat)
- Port assignment strategy (YNH auto-assignment vs fixed port)

### Phase 2: Remove + Backup/Restore Scripts
**Rationale:** These scripts share MongoDB interaction patterns and must be consistent with each other. Remove must not destroy shared MongoDB; backup must use `mongodump`, not raw copy; restore must re-download Meilisearch binary.
**Delivers:** `yunohost app remove` with safe MongoDB cleanup, `yunohost app backup` with consistent snapshots, `yunohost app restore` with full state recovery.
**Addresses:** Table stakes for YNH catalog acceptance (remove, backup, restore).
**Avoids:** Pitfall 2 (MongoDB shared instance — use only `ynh_mongo_remove_db`), Pitfall 4 (inconsistent backup — use `ynh_mongo_dump_db`), Meilisearch missing on restore (re-download binary).
**Depends on:** Phase 1 (must have working install to know the service layout).

### Phase 3: Upgrade Script + Config Merge
**Rationale:** Upgrade is the most user-facing script (users will run it repeatedly). It must preserve config, merge new keys, and clean up npm cache. This is the last phase because it depends on understanding the full install layout.
**Delivers:** `yunohost app upgrade` that rebuilds source, preserves `.env` and `librechat.yaml`, merges new config keys without overwriting, and cleans up npm cache post-build.
**Addresses:** Table stake: upgrade preserves config.
**Avoids:** Pitfall 2 (config overwrite — use `--keep` + merge helper), npm cache bloat (post-build cleanup).
**Depends on:** Phase 1 (source build), Phase 2 (MongoDB interaction patterns).

### Phase 4: Testing, Documentation, and Polish
**Rationale:** Final validation before catalog submission. Package must pass `package_check`, have complete documentation, and declare proper resource requirements.
**Delivers:** `tests.toml` with CI scenarios, `doc/DESCRIPTION.md`, `doc/ADMIN.md`, screenshots, proper `disk` and `ram.build` values in manifest.
**Addresses:** YNH catalog quality requirements.
**Depends on:** All prior phases for accurate documentation.

### Phase Ordering Rationale

- **Install must come first** because it's where all the complexity lives (build from source, three services, nginx config). Every other script derives from the install layout.
- **Remove and Backup/Restore are grouped** because they share MongoDB interaction patterns and must be tested together for consistency.
- **Upgrade is last** because it's the most mature script — it builds on install patterns, remove/backup knowledge, and requires understanding config merge.
- **Meilisearch integration is bundled into install** (not deferred) because the architecture treats it as a core component from day one. If it proves problematic, it can be made optional — but the install path should exist.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Install):** Needs research into `--no-save unrun` workaround specifics, `allow-remote=true` behavior, and whether Wekan's `mongo_version="8.0"` is compatible with LibreChat. Also verify upstream `.nvmrc` at implementation time.
- **Phase 3 (Upgrade):** Config merge strategy needs design — how to append new keys to `.env` and `librechat.yaml` without overwriting user values.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Remove/Backup/Restore):** These follow the Wekan patterns exactly. The MongoDB helpers (`ynh_mongo_remove_db`, `ynh_mongo_dump_db`) are well-documented with established YNH examples.
- **Phase 4 (Testing/Documentation):** Standard YNH package workflow. `package_check` and `tests.toml` format are well documented.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All stack choices verified against YunoHost official docs and Wekan reference implementation. Node version decision depends on upstream `.nvmrc` at build time. |
| Features | HIGH | Table stakes clearly defined by YNH catalog requirements. Anti-features have explicit rationale. Feature dependencies map cleanly to the install flow. |
| Architecture | HIGH | Component boundaries and data flow directly from LibreChat's architecture. YNH integration patterns verified against Wekan source. |
| Pitfalls | HIGH | All critical pitfalls have documented prevention strategies from AUR packages or Wekan source. No speculative pitfalls — each is reproduced in existing deployments. |

**Overall confidence:** HIGH

### Gaps to Address

- **Node version ambiguity:** Upstream `.nvmrc` specifies Node 24, but YNH typically targets Node 22 for Bookworm compatibility. Must verify at implementation time. Resolution: test both, use `"24"` if LibreChat build requires it, fall back to `"22"` if stable.
- **MongoDB 7.0 vs 8.0:** Wekan successfully uses `mongo_version="8.0"`. Need to test LibreChat against 8.0. Resolution: start with 7.0 per research, verify in Phase 1 testing.
- **`unrun` workaround specifics:** AUR mentions `npm install --no-save unrun` is needed but exact version not specified. Resolution: implement and test in Phase 1.
- **Meilisearch version pinning:** Using "latest v1.x" is vague. Need to pin a specific version or implement a version check. Resolution: pin to latest GitHub release at packaging time, update during upgrades.

## Sources

### Primary (HIGH confidence)
- [YunoHost Packaging Documentation (manifest.toml)](https://yunohost.org/en/dev/packaging/manifest) — Core packaging format
- [YunoHost App Resources Documentation](https://yunohost.org/en/dev/packaging/resources) — Node.js, MongoDB, apt resource declarations
- [YunoHost Helpers v2.1 (MongoDB helpers)](https://yunohost.org/en/dev/packaging/scripts/helpers_v2.1) — `ynh_install_mongo`, `ynh_mongo_setup_db`, `ynh_mongo_remove_db`
- [Wekan Install Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/install) — Verified MongoDB + Node.js pattern
- [Wekan Remove Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/remove) — Namespaced MongoDB cleanup pattern
- [Wekan Backup Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/backup) — mongodump backup pattern
- [Wekan Restore Script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/restore) — MongoDB restore pattern
- [Wekan systemd Unit](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/conf/systemd.service) — Hardened sandboxing pattern
- [LibreChat Repository](https://github.com/danny-avila/LibreChat) — Upstream source
- [LibreChat .nvmrc](https://raw.githubusercontent.com/danny-avila/LibreChat/main/.nvmrc) — Node version requirement
- [LibreChat package.json](https://raw.githubusercontent.com/danny-avila/LibreChat/main/package.json) — Build scripts and dependencies

### Secondary (MEDIUM confidence)
- [AUR LibreChat Package (PKGBUILD)](https://aur.archlinux.org/packages/librechat) — Documented build issues (xlsx, unrun, npm cache)
- [MyDrive YunoHost manifest](https://raw.githubusercontent.com/YunoHost-Apps/mydrive_ynh/master/manifest.toml) — Another MongoDB-using YNH app (confirming patterns)

---
*Research completed: 2026-09-18*
*Ready for roadmap: yes*
