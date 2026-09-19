# LibreChat YunoHost Package

## What This Is

A YunoHost app package that installs LibreChat — a free, open-source, self-hosted multi-provider LLM chat UI (OpenAI, Anthropic, Ollama, OpenRouter, and more) — on a YunoHost server. The package is a native (non-Docker) install: it sources LibreChat from GitHub, builds the frontend + API with Node, manages MongoDB and Meilisearch, and wires everything into YunoHost's nginx, systemd, and backup/restore tooling.

Target user: self-hosters running YunoHost who want a one-command `yunohost app install librechat` to get a ChatGPT-like LLM UI with YunoHost-native HTTPS, reverse-proxy, upgrades, and backups.

## Core Value

**One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.** If everything else fails, this install-and-run path must work.

## Requirements

### Validated

- ✓ `yunohost app backup librechat` produces a consistent backup (MongoDB via `mongodump`) — Phase 2
- ✓ `yunohost app restore librechat` restores app + data — Phase 2
- ✓ `yunohost app remove librechat` cleanly removes services, instance, and integration (shared-Mongo safe) — Phase 2

### Active

- [ ] Package installs LibreChat natively (no Docker) on latest YunoHost (Debian Bookworm)
- [ ] `yunohost app install librechat` returns a working, reachable LibreChat web UI
- [ ] LibreChat backend (Node API) starts under systemd and survives reboot
- [ ] MongoDB is installed and integrated via YunoHost's `ynh_install_mongo` (namespaced instance)
- [ ] Meilisearch is installed (native binary) and started under systemd
- [ ] YunoHost nginx reverse-proxies the app domain to LibreChat, with WebSocket + SSE (streaming) support
- [ ] HTTPS provisioned transparently via YunoHost's Let's Encrypt integration
- [ ] `yunohost app upgrade librechat` works and preserves user config (`librechat.env`, `librechat.yaml`)
- [ ] `manifest.toml` (packaging v2) validates and declares correct apt/binary sources with pinned versions
- [ ] All major LLM providers configurable out of the box (OpenAI, Anthropic, Ollama, OpenRouter, etc.)
- [ ] Package passes YunoHost app CI or has documented CI-blocking issue

### Out of Scope

- **Docker-in-a-package install** — Native install is the explicit goal; user runs YunoHost to avoid Docker
- **SSO / LDAP integration** — LibreChat ships its own account system; declare `sso = false` in `[integration]`
- **Multi-domain / virtual-host fan-out** — Single domain per install is sufficient for v1

## Context

This package wraps a real application with multiple backing services:

- **LibreChat** (Node/React SPA + API) — current target release `v0.7.8`
- **MongoDB** — required by LibreChat. Debian does not ship MongoDB (SSPL licensing). YunoHost provides `ynh_install_mongo` helper (used by Wekan, MyDrive, etc.)
- **Meilisearch** — optional for some LibreChat LLM capabilities; install as native per-arch binary

**AUR (Arch Linux) package lessons to evaluate during planning:**
- `xlsx` CDN tarball blocked by npm
- `unrun` missing from `npm ci` resolution
- `libvips` (sharp) native dependency
- Config overwrite on upgrade
- npm `.cache` bloat in the app tree
- Sysuser + env wrapper launcher

**Prior design work:** A prior design pass produced a concrete native package tree structure with `manifest.toml`, `scripts/`, `conf/`, and `doc/` directories that can inform the implementation.

## Constraints

- **Tech stack**: Debian Bookworm + YunoHost packaging v2; LibreChat via GitHub source (pinned tag), Node 22, native MongoDB (upstream repo), native Meilisearch binary. No Docker.
- **Security**: Source tarballs pinned with sha256; app runs under dedicated `$app` system user; nginx is YunoHost-managed
- **Data locality**: All app data in `/home/yunohost.app/librechat/`; backup via consistent logical dump (`mongodump`)
- **Upgrade safety**: User config (`.env` secrets, `librechat.yaml`) must be merged, never clobbered
- **Licensing**: MongoDB is SSPL — accepted because YunoHost core ships `ynh_install_mongo` helper for it (established precedent)
- **Compatibility**: Must remain valid YunoHost app for catalog (single domain, own auth, native install)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native install, no Docker | User runs YunoHost to avoid Docker; Docker-in-a-package is contentious | — Pending |
| Use YunoHost `ynh_install_mongo` for MongoDB | Debian ships no Mongo (SSPL); helper is official precedent | — Pending |
| `sso = false`, `ldap = false` in `[integration]` | LibreChat ships its own account system | — Pending |
| Config merge (never overwrite) on upgrade | AUR lesson — native rebuilds must not destroy user secrets | — Pending |
| Backup via `mongodump` not raw volume copy | Raw copy is inconsistent while DB is live | — Pending |
| nginx proxy with WebSocket + SSE (buffering off) | LibreChat streams LLM responses and uses WS | — Pending |
| Run app as `$app` system user via env-sourcing wrapper | AUR pattern; avoids root, isolates Node process | — Pending |

---
*Last updated: 2026-09-19 after Phase 2*
