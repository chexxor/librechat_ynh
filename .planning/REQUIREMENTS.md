# Requirements: LibreChat YunoHost Package

**Defined:** 2026-09-18
**Core Value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Package Skeleton

- [x] **SKEL-01**: `manifest.toml` (packaging v2) validates with correct YunoHost schema
- [x] **SKEL-02**: App declares correct apt/binary sources with pinned versions (Node 22, libvips42, MongoDB 7.x, Meilisearch)
- [x] **SKEL-03**: App runs under dedicated `$app` system user
- [x] **SKEL-04**: `sso = false`, `ldap = false` declared in `[integration]`
- [x] **SKEL-05**: Source tarballs pinned with sha256 integrity checks

### Install

- [x] **INST-01**: Script downloads LibreChat source from GitHub (pinned tag)
- [x] **INST-02**: Script builds LibreChat frontend + API (npm ci + npm run build)
- [x] **INST-03**: Build workarounds applied: `allow-remote=true` for xlsx, `npm install --no-save unrun`, npm `.cache` stripped post-build
- [x] **INST-04**: MongoDB installed via `ynh_install_mongo` (namespaced instance)
- [x] **INST-05**: Meilisearch installed as native per-arch binary with systemd unit
- [x] **INST-06**: nginx reverse-proxy configured with WebSocket + SSE support (proxy_buffering off, upgrade headers)
- [x] **INST-07**: LibreChat systemd service created and enabled (starts on boot)
- [x] **INST-08**: Initial admin user created via `npm run create-user` with `$admin` email + random password
- [x] **INST-09**: HTTPS provisioned transparently via YunoHost's Let's Encrypt
- [x] **INST-10**: `yunohost app install librechat` returns a working, reachable LibreChat web UI

### Upgrade

- [ ] **UPGR-01**: Script rebuilds LibreChat from updated source
- [ ] **UPGR-02**: User config (`librechat.env`, `librechat.yaml`) preserved via config merge (never overwritten)
- [ ] **UPGR-03**: MongoDB data preserved across upgrades
- [ ] **UPGR-04**: Meilisearch data preserved across upgrades
- [x] **UPGR-05**: `yunohost app upgrade librechat` completes without data loss or config loss

### Remove

- [x] **RMV-01**: Script stops and disables systemd services
- [x] **RMV-02**: Script removes namespaced MongoDB database only (never calls `ynh_remove_mongo` — safe for shared instances)
- [x] **RMV-03**: Script removes Meilisearch binary and data
- [x] **RMV-04**: Script removes app data directory and nginx config
- [x] **RMV-05**: `yunohost app remove librechat` cleans up without breaking other YunoHost apps

### Backup & Restore

- [ ] **BACK-01**: Backup produces consistent MongoDB dump via `ynh_mongo_dump_db` (not raw volume copy)
- [ ] **BACK-02**: Backup includes app config, data directory, and Meilisearch data
- [ ] **BACK-03**: Restore re-downloads Meilisearch binary, restores MongoDB via `ynh_mongo_restore_db`
- [ ] **BACK-04**: Restore restores app config, nginx config, and service state
- [ ] **BACK-05**: `yunohost app restore librechat` returns a working app post-restore

### Configuration & Provider Support

- [x] **CONF-01**: All major LLM providers configurable out of the box (OpenAI, Anthropic, Ollama, OpenRouter)
- [x] **CONF-02**: `librechat.env` template with secrets placeholder (preserved on upgrade)
- [x] **CONF-03**: `librechat.yaml` template with provider config (preserved on upgrade)
- [x] **CONF-04**: Install questions for essential config values (admin email for notifications, etc.)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Polish & CI

- **POLS-01**: Package passes YunoHost app CI (`package_check`)
- **POLS-02**: `change_url` script implemented
- **POLS-03**: Multi-instance support (multiple LibreChat installations on same server)
- **POLS-04**: ARM64 support (Raspberry Pi)
- **POLS-05**: Install question for admin credentials instead of random generation
- **POLS-06**: Multi-provider LLM support with all 20+ LibreChat-supported providers

## Out of Scope

| Feature | Reason |
|---------|--------|
| Docker-in-package install | Native install is explicit goal; user runs YunoHost to avoid Docker |
| SSO / LDAP integration | LibreChat does not support LDAP/SAML. Upstream would need changes |
| Multi-domain / virtual-host fan-out | Single domain per install is sufficient for v1 |
| Config panel in YNH webadmin | LibreChat already has its own config system (librechat.yaml). Dual maintenance burden |
| Database management UI | MongoDB admin is out of scope. User can install mongo-express separately |
| Redis integration | Not required for LibreChat's default single-server mode |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SKEL-01 | Phase 1 | Complete |
| SKEL-02 | Phase 1 | Complete |
| SKEL-03 | Phase 1 | Complete |
| SKEL-04 | Phase 1 | Complete |
| SKEL-05 | Phase 1 | Complete |
| INST-01 | Phase 1 | Complete |
| INST-02 | Phase 1 | Complete |
| INST-03 | Phase 1 | Complete |
| INST-04 | Phase 1 | Complete |
| INST-05 | Phase 1 | Complete |
| INST-06 | Phase 1 | Complete |
| INST-07 | Phase 1 | Complete |
| INST-08 | Phase 1 | Complete |
| INST-09 | Phase 1 | Complete |
| INST-10 | Phase 1 | Complete |
| UPGR-01 | Phase 3 | Complete |
| UPGR-02 | Phase 3 | Complete |
| UPGR-03 | Phase 3 | Complete |
| UPGR-04 | Phase 3 | Complete |
| UPGR-05 | Phase 3 | Complete |
| RMV-01 | Phase 2 | Complete |
| RMV-02 | Phase 2 | Complete |
| RMV-03 | Phase 2 | Complete |
| RMV-04 | Phase 2 | Complete |
| RMV-05 | Phase 2 | Complete |
| BACK-01 | Phase 2 | Complete |
| BACK-02 | Phase 2 | Complete |
| BACK-03 | Phase 2 | Complete |
| BACK-04 | Phase 2 | Complete |
| BACK-05 | Phase 2 | Complete |
| CONF-01 | Phase 1 | Complete |
| CONF-02 | Phase 1 | Complete |
| CONF-03 | Phase 1 | Complete |
| CONF-04 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 34 total
- Mapped to phases: 34
- Unmapped: 0 ✅

---
*Requirements defined: 2026-09-18*
*Last updated: 2026-09-18 after initial definition*
