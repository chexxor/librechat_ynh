# LibreChat YunoHost Package

## What This Is

A YunoHost app package that installs LibreChat — a free, open-source, self-hosted multi-provider LLM chat UI (OpenAI, Anthropic, Ollama, OpenRouter, and more) — on a YunoHost server. The package is a native (non-Docker) install: it sources LibreChat from GitHub, builds the frontend + API with Node, manages MongoDB and Meilisearch, and wires everything into YunoHost's nginx, systemd, and backup/restore tooling.

Target user: self-hosters running YunoHost who want a one-command `yunohost app install librechat` to get a ChatGPT-like LLM UI with YunoHost-native HTTPS, reverse-proxy, upgrades, and backups.

## Core Value

**One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.** If everything else fails, this install-and-run path must work.

## Requirements

### Validated

- ✓ `yunohost app install librechat` returns a working, reachable LibreChat web UI — v1.0
- ✓ LibreChat backend (Node API) starts under systemd — v1.0 (units sandbox-safe via ReadWritePaths)
- ✓ MongoDB integrated via `ynh_install_mongo` (namespaced instance, v7.0) — v1.0
- ✓ Meilisearch installed as native per-arch binary under systemd — v1.0
- ✓ nginx reverse-proxy with WebSocket + SSE support (proxy_buffering off) — v1.0
- ✓ HTTPS via YunoHost Let's Encrypt — v1.0
- ✓ `manifest.toml` (packaging v2) validates; sources pinned with sha256 — v1.0
- ✓ All major LLM providers configurable out of the box (OpenAI, Anthropic, Ollama, OpenRouter) — v1.0
- ✓ `yunohost app upgrade` works, preserves `librechat.env` and `librechat.yaml` — v1.0 (live-verified, ~ynh2)
- ✓ Safe remove, shared-MongoDB safe — v1.0
- ✓ Backup/restore round-trip consistent (`mongodump`) — v1.0 (live-verified)
- ✓ Initial admin user created at install — v1.0

### Active

- [ ] Package passes YunoHost app CI (`package_check`) — v2 (POLS-01)
- [ ] `change_url` script — v2 (POLS-02)
- [ ] Multi-instance support — v2 (POLS-03, requires per-app Meilisearch wiring)
- [ ] ARM64 support — v2 (POLS-04)

### Out of Scope

- **Docker-in-a-package install** — Native install is the explicit goal; user runs YunoHost to avoid Docker (still valid)
- **SSO / LDAP integration** — LibreChat does not support LDAP/SAML upstream (updated reasoning)
- **Multi-domain / virtual-host fan-out** — Single domain per install is sufficient
- **Config panel in YNH webadmin** — LibreChat has its own config system (`librechat.yaml`)
- **Database management UI** — User can install mongo-express separately
- **Redis integration** — Not required for default single-server mode

## Current Milestone: v1.1 CI Validation

**Goal:** Package passes YunoHost `package_check` with zero failures and all identified findings fixed.

**Target features:**
- Run `package_check` against the package and fix all failures
- Archive clean CI result as live verification of POLS-01

## Current State

**Shipped: v1.0** (2026-09-19) — complete lifecycle package: install, remove, backup/restore, and config-preserving upgrade, all live-verified on a real YunoHost server. 34/34 v1 requirements met; 47 files, ~5,700 lines added. LibreChat pinned to v0.8.8-rc3 (sha256), Node 24, MongoDB 7.0.

**v1.1 progress:** Phase 4 (Lint Baseline) complete — `package_linter` runs deterministically from the Windows dev box via WSL2 (`scripts/run_lint.sh`), locally-fixable errors reduced to zero, 8 of 9 warnings fixed, before/after baseline archived with 5 documented scope exemptions. Next: Phase 5 (tests.toml + local `package_check` environment).

**Known debt for next milestone:** `package_check` CI not yet run; multi-instance blocked by single-instance Meilisearch wiring; future upstream releases require the established bump flow (tag → sha256 pin → `~ynhN` bump).

## Next Milestone Goals

To be defined via `/gsd-new-milestone`. Deferred: `change_url` (POLS-02), multi-instance (POLS-03), ARM64 (POLS-04), admin-credential install question.

<details>
<summary>v1.0 pre-release planning context (original project framing)</summary>

This package wraps a real application with multiple backing services:

- **LibreChat** (Node/React SPA + API) — current target release `v0.7.8`
- **MongoDB** — required by LibreChat. Debian does not ship MongoDB (SSPL licensing). YunoHost provides `ynh_install_mongo` helper (used by Wekan, MyDrive, etc.)
- **Meilisearch** — optional for some LibreChat LLM capabilities; install as native per-arch binary

**AUR (Arch Linux) package lessons identified in early planning** (all evaluated/solved during v1.0):

- `xlsx` CDN tarball blocked by npm → `allow-remote=true` in build
- `unrun` missing from `npm ci` resolution → `npm install --no-save unrun`
- `libvips` (sharp) native dependency → pinned libvips42 source
- Config overwrite on upgrade → regen-and-merge strategy
- npm `.cache` bloat in the app tree → stripped post-build

</details>

## Context

- **Tech stack**: Debian Bookworm + YunoHost packaging v2; LibreChat via GitHub source (pinned tag v0.8.8-rc3), Node 24 (upstream `.nvmrc`), native MongoDB 7.0 (`ynh_install_mongo`), native Meilisearch binary. No Docker.
- **Security**: Source tarballs pinned with sha256; app runs under dedicated `$app` system user; `librechat.env` chmod 600; systemd units survive `ProtectSystem=full`
- **Data locality**: All app data in `/home/yunohost.app/librechat/` (`[resources.data_dir]`); backup via consistent logical dump (`mongodump`, cwd-relative)
- **Upgrade safety**: `librechat.env` merge = fresh template + append-only user keys; `librechat.yaml` never overwritten (only missing active keys appended as commented sections)
- **Licensing**: MongoDB SSPL — accepted via official `ynh_install_mongo` helper precedent
- **Compatibility**: Valid YunoHost app for catalog (single domain, own auth, native install, `sso = false`)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Native install, no Docker | User runs YunoHost to avoid Docker; Docker-in-a-package is contentious | ✓ Good — v1.0 shipped native |
| Use YunoHost `ynh_install_mongo` for MongoDB | Debian ships no Mongo (SSPL); helper is official precedent | ✓ Good — namespaced instance works; shared-safe remove |
| `sso = false`, `ldap = false` in `[integration]` | LibreChat ships its own account system | ✓ Good |
| Config merge (never overwrite) on upgrade | AUR lesson — native rebuilds must not destroy user secrets | ✓ Good — regen-and-merge verified live |
| Backup via `mongodump` not raw volume copy | Raw copy is inconsistent while DB is live | ✓ Good — round-trip verified |
| nginx proxy with WebSocket + SSE (buffering off) | LibreChat streams LLM responses and uses WS | ✓ Good |
| Run app as `$app` system user via env-sourcing wrapper | AUR pattern; avoids root, isolates Node process | ✓ Good |
| Node 24 (not 22) per upstream `.nvmrc` | Matches LibreChat v0.8.8-rc3 runtime | ✓ Good |
| `multi_instance=false` for v1 | Single-instance Meilisearch wiring retained; per-app wiring deferred | ⚠️ Revisit — needed for POLS-03 |
| Declare `[resources.data_dir]`, ynh_safe_rm guards meilisearch subdir | Core-managed data dir; tolerant cleanup | ✓ Good |
| Upgrade validated via `~ynhN` bump on same tag | No newer upstream stable at milestone time | — Pending real upstream bump |
| Lint baseline via WSL2 + uv Python 3.12 (`scripts/run_lint.sh`) | Linter shells out to POSIX tools; must run under WSL, not bare Windows | ✓ Good — deterministic runner, baseline archived |
| Zero-error invariant = `(critical ∪ error) \ documented-exemptions == ∅` | Catalog PR + `tests.toml` are out of Phase 4 scope; honest auditable claim over fake-green | ✓ Good — 5 exemptions documented in 04-SCOPE-EXEMPTIONS.md |
| nginx WS headers retained over `proxy_params_no_auth` alone | LibreChat WebSockets/SSE require `proxy_http_version 1.1` + `Upgrade` + `Connection` | ✓ Good — permanent design exception |

---
*Last updated: 2026-09-20 after Phase 4 (Lint Baseline) transition*
