# LibreChat YunoHost Package

## What This Is

A [YunoHost](https://yunohost.org) app package that installs **LibreChat** — a free, open-source, self-hosted multi-provider LLM chat UI (OpenAI, Anthropic, Ollama, and more) — on a YunoHost server. The package is a **native (non-Docker)** install: it sources LibreChat from GitHub, builds the frontend + API with Node, manages MongoDB (via the upstream repo, since Debian does not ship it) and Meilisearch, and wires everything into YunoHost's nginx, systemd, and backup/restore tooling.

Target user: self-hosters who already run YunoHost and want a one-command `yunohost app install librechat` to get a ChatGPT-like LLM UI with YunoHost-native HTTPS, reverse-proxy, upgrades, and backups — without running their own Docker stack.

## Core Value

**One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.** If everything else fails, this install-and-run path must work.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Package installs LibreChat natively (no Docker) on a Debian/YunoHost server
- [ ] `yunohost app install librechat` returns a working, reachable LibreChat web UI
- [ ] LibreChat backend (Node API) starts under systemd and survives reboot
- [ ] MongoDB is installed and integrated via YunoHost's `ynh_install_mongo` (namespaced instance)
- [ ] Meilisearch is installed (native binary) and started under systemd
- [ ] YunoHost nginx reverse-proxies the app domain to LibreChat, with WebSocket + SSE (streaming) support
- [ ] HTTPS is provisioned transparently via YunoHost's Let's Encrypt integration
- [ ] `yunohost app upgrade librechat` works and **preserves user config** (`librechat.env`, `librechat.yaml`)
- [ ] `yunohost app backup librechat` produces a consistent backup (MongoDB via `mongodump`, not raw volume copy)
- [ ] `yunohost app restore librechat` restores app + data
- [ ] `yunohost app remove librechat` cleanly removes services, instance, and integration (shared-Mongo safe)
- [ ] `manifest.toml` (packaging v2) validates and declares correct apt/binary sources with pinned versions
- [ ] Package passes the YunoHost app CI (or has a documented, reproducible CI-blocking issue)

### Out of Scope

- **Docker-in-a-package install** — user runs YunoHost *to avoid Docker*; native install is the explicit goal
- **SSO / LDAP integration** — LibreChat ships its own account system; declare `sso = false` in `[integration]`
- **Multi-domain / virtual-host fan-out** — single domain per install is sufficient for v1

## Context

This package wraps a real world application with multiple backing services:

- **LibreChat** (Node/React SPA + API), current target release `v0.7.8` (package version `0.7.8~ynh1`)
- **MongoDB** — required by LibreChat. Debian does **not** ship MongoDB (relicensed AGPL → SSPL in 2018; OSI rejects SSPL). YunoHost provides the `ynh_install_mongo` helper (used by Wekan, MyDrive, mongo-express) which installs MongoDB from the upstream apt repo with a pinned version. Pin to a version confirmed for the target Debian release.
- **Meilisearch** — optional for some LibreChat LLM capabilities; install as a native per-arch binary under `.planning` `__DATA_DIR__` (`/home/yunohost.app/librechat/`).

**Prior design work (the idea document in this repo, `librechat yunohost package.json`):** A prior AI-assisted design pass produced a concrete native package tree:

```
librechat_ynh/
├── manifest.toml              # packaging v2; Node 22, libvips42, mongo 7.0, meilisearch binary sources
├── scripts/
│   ├── _common.sh             # build + config-merge helpers
│   ├── install                # sources → node → build → mongo → meili → systemd → nginx
│   ├── upgrade                # rebuild + config MERGE (never overwrite)
│   ├── remove                 # namespaced mongo cleanup, shared-instance safe
│   ├── backup                 # consistent mongodump
│   └── restore
├── conf/
│   ├── nginx.conf             # websocket + SSE-aware proxy (buffering off)
│   ├── librechat.service      # hardened systemd unit
│   ├── meilisearch.service
│   ├── librechat-server.sh    # env-sourcing wrapper (AUR pattern)
│   ├── librechat.env          # secrets template; preserved on upgrade
│   └── librechat.yaml         # config template; preserved on upgrade
└── doc/                       # architecture + AUR-lessons table + TODO
```

**AUR (Arch Linux) package lessons to incorporate** (each is a real, observed failure of native LibreChat builds):

| AUR issue | Fix to bake into this package |
|---|---|
| `xlsx` CDN tarball blocked by npm | `npm config set allow-remote true` during build |
| `unrun` missing from `npm ci` resolution | `npm install --no-save unrun` before frontend build |
| `libvips` (sharp) native dependency | declare `libvips42` in `[resources.apt]` |
| Config overwrite on upgrade | upgrade config-merge: append only new keys, preserve user file |
| npm `.cache` bloat in the app tree | strip `node_modules/.cache` post-build |
| Sysuser + env wrapper launcher | app runs as `$app` system user via `/usr/bin/$app-server` env-sourcing wrapper |

**Known unknowns / to verify before building:**
- Pinned versions: MongoDB 7.x support matrix for the target Debian release; Node 22 availability; Meilisearch per-arch binary URL + sha256
- Exact `ynh_install_mongo` helper signature against the user's actual YunoHost version
- sha256 of source tarballs (GitHub tag archive)
- Whether the build runs reliably in the YunoHost app CI sandbox
- A `config.svg` icon for the app store listing

## Constraints

- **Tech stack**: Debian + YunoHost packaging v2; LibreChat via GitHub source (pinned tag), Node 22, native MongoDB (upstream repo), native Meilisearch binary. No Docker.
- **Security / integrity**: Source tarballs pinned with sha256; app runs under a dedicated `$app` system user, not root; nginx is YunoHost-managed.
- **Data locality**: All app data in `/home/yunohost.app/librechat/`; backup must be a consistent logical dump (mongodump), not a raw bind-volume copy.
- **Upgrade safety**: User config (`.env` secrets, `librechat.yaml`) must be merged, never clobbered, on upgrade.
- **Licensing**: MongoDB is SSPL — accepted because YunoHost core ships the `ynh_install_mongo` helper for it (established precedent: Wekan, MyDrive). Note this in the package disclaimer.
- **Compatibility**: Must remain a valid YunoHost app for the catalog (single domain, own auth, native install).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native install, **no Docker** | User runs YunoHost to *avoid* Docker; Docker-in-a-package is contentious in the community | — Pending |
| Use YunoHost `ynh_install_mongo` for MongoDB | Debian ships no Mongo (SSPL); the helper is official precedent (Wekan, MyDrive) | — Pending |
| `sso = false`, `ldap = false` in `[integration]` | LibreChat ships its own account system | — Pending |
| Config merge (never overwrite) on upgrade | AUR lesson — native rebuilds must not destroy user secrets/config | — Pending |
| Backup via `mongodump` (logical) not raw volume copy | Raw volume copy is inconsistent while DB is live | — Pending |
| nginx proxy with WebSocket + SSE (buffering off) | LibreChat streams LLM responses and uses WS for some features | — Pending |
| Run app as `$app` system user via env-sourcing wrapper | AUR pattern; avoids root, isolates the Node process | — Pending |

---
*Last updated: 2026-09-17 after project initialization (--auto)*
