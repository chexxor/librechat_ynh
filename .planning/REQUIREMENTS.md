# Requirements: LibreChat YunoHost Package

**Defined:** 2026-09-18
**Core Value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Package Skeleton

- [ ] **SKEL-01**: `manifest.toml` (packaging v2) validates with correct YunoHost schema
- [ ] **SKEL-02**: App declares correct apt/binary sources with pinned versions (Node 22, libvips42, MongoDB 7.x, Meilisearch)
- [ ] **SKEL-03**: App runs under dedicated `$app` system user
- [ ] **SKEL-04**: `sso = false`, `ldap = false` declared in `[integration]`
- [ ] **SKEL-05**: Source tarballs pinned with sha256 integrity checks

### Install

- [ ] **INST-01**: Script downloads LibreChat source from GitHub (pinned tag)
- [ ] **INST-02**: Script builds LibreChat frontend + API (npm ci + npm run build)
- [ ] **INST-03**: Build workarounds applied: `allow-remote=true` for xlsx, `npm install --no-save unrun`, npm `.cache` stripped post-build
- [ ] **INST-04**: MongoDB installed via `ynh_install_mongo` (namespaced instance)
- [ ] **INST-05**: Meilisearch installed as native per-arch binary with systemd unit
- [ ] **INST-06**: nginx reverse-proxy configured with WebSocket + SSE support (proxy_buffering off, upgrade headers)
- [ ] **INST-07**: LibreChat systemd service created and enabled (starts on boot)
- [ ] **INST-08**: Initial admin user created via `npm run create-user` with `$admin` email + random password
- [ ] **INST-09**: HTTPS provisioned transparently via YunoHost's Let's Encrypt
- [ ] **INST-10**: `yunohost app install librechat` returns a working, reachable LibreChat web UI

### Upgrade

- [ ] **UPGR-01**: Script rebuilds LibreChat from updated source
- [ ] **UPGR-02**: User config (`librechat.env`, `librechat.yaml`) preserved via config merge (never overwritten)
- [ ] **UPGR-03**: MongoDB data preserved across upgrades
- [ ] **UPGR-04**: Meilisearch data preserved across upgrades
- [ ] **UPGR-05**: `yunohost app upgrade librechat` completes without data loss or config loss

### Remove

- [ ] **RMV-01**: Script stops and disables systemd services
- [ ] **RMV-02**: Script removes namespaced MongoDB database only (never calls `ynh_remove_mongo` — safe for shared instances)
- [ ] **RMV-03**: Script removes Meilisearch binary and data
- [ ] **RMV-04**: Script removes app data directory and nginx config
- [ ] **RMV-05**: `yunohost app remove librechat` cleans up without breaking other YunoHost apps

### Backup & Restore

- [ ] **BACK-01**: Backup produces consistent MongoDB dump via `ynh_mongo_dump_db` (not raw volume copy)
- [ ] **BACK-02**: Backup includes app config, data directory, and Meilisearch data
- [ ] **BACK-03**: Restore re-downloads Meilisearch binary, restores MongoDB via `ynh_mongo_restore_db`
- [ ] **BACK-04**: Restore restores app config, nginx config, and service state
- [ ] **BACK-05**: `yunohost app restore librechat` returns a working app post-restore

### Configuration & Provider Support

- [ ] **CONF-01**: All major LLM providers configurable out of the box (OpenAI, Anthropic, Ollama, OpenRouter)
- [ ] **CONF-02**: `librechat.env` template with secrets placeholder (preserved on upgrade)
- [ ] **CONF-03**: `librechat.yaml` template with provider config (preserved on upgrade)
- [ ] **CONF-04**: Install questions for essential config values (admin email for notifications, etc.)

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
| SKEL-01 | | Pending |
| SKEL-02 | | Pending |
| SKEL-03 | | Pending |
| SKEL-04 | | Pending |
| SKEL-05 | | Pending |
| INST-01 | | Pending |
| INST-02 | | Pending |
| INST-03 | | Pending |
| INST-04 | | Pending |
| INST-05 | | Pending |
| INST-06 | | Pending |
| INST-07 | | Pending |
| INST-08 | | Pending |
| INST-09 | | Pending |
| INST-10 | | Pending |
| UPGR-01 | | Pending |
| UPGR-02 | | Pending |
| UPGR-03 | | Pending |
| UPGR-04 | | Pending |
| UPGR-05 | | Pending |
| RMV-01 | | Pending |
| RMV-02 | | Pending |
| RMV-03 | | Pending |
| RMV-04 | | Pending |
| RMV-05 | | Pending |
| BACK-01 | | Pending |
| BACK-02 | | Pending |
| BACK-03 | | Pending |
| BACK-04 | | Pending |
| BACK-05 | | Pending |
| CONF-01 | | Pending |
| CONF-02 | | Pending |
| CONF-03 | | Pending |
| CONF-04 | | Pending |

**Coverage:**
- v1 requirements: 34 total
- Mapped to phases: 0
- Unmapped: 34 ⚠️

---
*Requirements defined: 2026-09-18*
*Last updated: 2026-09-18 after initial definition*
