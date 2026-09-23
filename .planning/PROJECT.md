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
- ✓ Schema-valid `tests.toml` supplies install args and drives a full `package_check` suite — v1.1 (CI-01, Phase 5)
- ✓ Reproducible local `package_check` environment (Hyper-V Debian 12 VM + Incus + btrfs) runs the full suite end-to-end — v1.1 (CI-02, Phase 5)
- ✓ `package_linter` reports zero locally-fixable errors (WSL2 + uv Python 3.12) — v1.1 (LINT-01, Phase 4)
- ✓ Full local `package_check` suite passes with zero in-scope failures; single clean run archived as POLS-01 live verification — v1.1 (POLS-01, Phase 6); `change_url` + `upgrade.05e3d5b` exempt by design
- ✓ Lint-only GitHub Actions workflow green on push/PR (`package_linter` + shellcheck + TOML/schema on ubuntu-latest) — v1.1 (GHCI-01, Phase 7)

### Active

- [ ] `change_url` script — v2 (POLS-02)
- [ ] Multi-instance support — v2 (POLS-03, requires per-app Meilisearch wiring)
- [ ] ARM64 support — v2 (POLS-04)
- [ ] Install question for admin credentials instead of random generation — v2 (POLS-05)
- [ ] Catalog submission PR (resolves `AppCatalog.*` lint exemptions) — v2
- [ ] Optional self-hosted-runner `package_check` on GitHub — v2 (GHCI-02, only if lint-only proves insufficient)

### Out of Scope

- **Docker-in-a-package install** — Native install is the explicit goal; user runs YunoHost to avoid Docker (still valid)
- **SSO / LDAP integration** — LibreChat does not support LDAP/SAML upstream (updated reasoning)
- **Multi-domain / virtual-host fan-out** — Single domain per install is sufficient
- **Config panel in YNH webadmin** — LibreChat has its own config system (`librechat.yaml`)
- **Database management UI** — User can install mongo-express separately
- **Redis integration** — Not required for default single-server mode

## Current Milestone: (none — v1.1 shipped)

**Next milestone:** to be defined via `/gsd-new-milestone`.

## Current State

**Shipped: v1.0** (2026-09-19) — complete lifecycle package: install, remove, backup/restore, and config-preserving upgrade, all live-verified on a real YunoHost server. 34/34 v1 requirements met; 47 files, ~5,700 lines added. LibreChat pinned to v0.8.8-rc3 (sha256), Node 24, MongoDB 7.0.

**Shipped: v1.1 CI Validation** (2026-09-20) — 4 phases, 13 plans. `package_linter` runs deterministically via WSL2 (`scripts/run_lint.sh`) with zero locally-fixable errors (5 catalog items exempt); schema-valid `tests.toml` + reproducible Hyper-V Debian 12 VM/Incus/btrfs environment; all install-blocking bugs fixed and a single clean full-suite `package_check` run archived as POLS-01 (exit 0, 4/4 in-scope SUCCESS, `change_url`/`upgrade.05e3d5b` exempt by design); lint-only GitHub Actions workflow green. See `.planning/MILESTONES.md` and `.planning/milestones/v1.1-*.md`.

**Known debt for next milestone:** full `package_check` is deliberately NOT in hosted CI (research-locked anti-feature — privileged LXC/Incus/btrfs conflicts with Docker; frontend build OOMs on 7GB runners). Multi-instance blocked by single-instance Meilisearch wiring. Future upstream releases require the established bump flow (tag → sha256 pin → `~ynhN` bump). Reproducibility gaps recorded in `05-FINDINGS.md` §5 should be folded into `doc/PACKAGE_CHECK.md` / `scripts/setup_pc_env.sh`.

## Next Milestone Goals

To be defined via `/gsd-new-milestone`. Deferred: `change_url` (POLS-02), multi-instance (POLS-03), ARM64 (POLS-04), admin-credential install question (POLS-05), catalog submission PR, optional GHCI-02.

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
| `tests.toml` upgrade-from pinned to commit `05e3d5b` (0.8.8-rc3~ynh2) not `116691c` | `116691c` is a manifest-only skeleton with no `scripts/` and is not installable | ✓ Good — suite parses and upgrade target is installable |
| package_check host = dedicated Hyper-V Debian 12 VM + Incus (Zabbly lts-7.0) + btrfs pool on a second disk | WSL2 ruled out (no nested Incus/btrfs); Incus has no native bookworm package; btrfs enables fast CoW snapshots | ✓ Good — full suite ran end-to-end on this host |
| Zero-failure bar scoped to 4 in-scope tests; `change_url` + `upgrade.05e3d5b` exempt by design | `05e3d5b` (v1.0 artifact) predates the Phase 4 manifest schema fix and cannot install on YNH ≥12.1.40; `change_url` is POLS-02 | ✓ Good — documented in 06-SCOPE-EXEMPTIONS.md |
| POLS-01 evidence = one clean full-suite run (cycle 13), not a retry composite; logs redacted | Honest live-verification claim; secrets must not be committed | ✓ Good — 20m45s run, exit 0, 0 residual secret matches |
| Mongo password read from setting key `db_pwd` (not `mongopwd`) | YNH helpers v2.1 `ynh_mongo_setup_db` stores it as `db_pwd`; `mongopwd` never set | ✓ Good — fixed install/upgrade/_common |
| `HOST=127.0.0.1` (not `localhost`) in `librechat.env` | Container resolves `localhost`→`::1` first; node binds IPv6 while nginx proxies IPv4 → 502 | ✓ Good — install.root passes |
| Meilisearch unit sets `WorkingDirectory=__DATA_DIR__` | v1.53.2 creates `dumps/` relative to CWD; with no CWD (=`/`) `librechat` user gets EACCES | ✓ Good — proven by controlled in-container repro |
| Restore recreates the Mongo user (`ynh_mongo_setup_db --db_pwd` before restore) | `mongodump --db` doesn't dump DB users; fresh Mongo rejects restored credentials | ✓ Good — backup_restore passes |
| CI workflow inline-provisions `package_linter` pinned to a commit SHA (Python 3.12 via setup-python) | Workflow must start/stay green; `run_lint.sh` is WSL2-specific; floating `main` could redden with no repo change | ✓ Good — GHCI-01 green |

---
*Last updated: 2026-09-23 after v1.1 CI Validation milestone*
