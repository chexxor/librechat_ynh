# Stack Research

**Domain:** YunoHost native app package wrapping LibreChat (Node.js + MongoDB + Meilisearch)
**Researched:** 2026-09-18
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| YunoHost packaging format | v2 (manifest.toml) | App package definition | Standard since YNH 11.1 (2023). Handles resources (sources, nodejs, apt, ports, system_user, install_dir, permissions) automatically. Migrated from v1 bash helpers. Used by all modern YNH packages. |
| YunoHost helpers version | 2.1 | Bash helper functions | Latest stable. Provides `ynh_install_mongo`, `ynh_mongo_setup_db`, `ynh_setup_source`, `ynh_config_add_systemd`, `ynh_config_add_nginx`, `ynh_systemctl`. |
| Node.js | 22 LTS (via `[resources.nodejs]`) | LibreChat runtime | LibreChat `.nvmrc` specifies `24.16.0` (Node 24 as of latest rc). But Node 22 is the LTS line for Debian Bookworm compatibility through YunoHost's n version manager. Use `version = "22"` in manifest resources -- YNH resolves to latest 22.x actual version. If LibreChat upstream mandates Node 24, bump to `version = "24"`. |
| MongoDB | 7.0 (via `ynh_install_mongo`) | LibreChat database | Debian Bookworm does not ship MongoDB (SSPL licensing). YunoHost provides `ynh_install_mongo` helper which pulls from MongoDB upstream repo. Wekan uses mongo_version="8.0"; for LibreChat, MongoDB 7.0 is the latest confirmed compatible. |
| Meilisearch | latest v1.x | LibreChat search indexing | Install as native per-arch binary from GitHub releases via `[resources.sources]`. No YNH helper exists -- manual binary install into `/usr/bin/meilisearch` + custom systemd unit. |
| nginx (YNH-managed) | as provided by YNH | Reverse proxy for HTTP/WS/SSE | YunoHost manages nginx globally. App provides `conf/nginx.conf` template with proxy_pass to local port. Must set `proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade";` for WebSocket and `proxy_buffering off;` for SSE streaming. |
| systemd (YNH-integrated) | as provided by Debian | Service management for LibreChat and Meilisearch | YNH provides `ynh_config_add_systemd` helper to install a unit from template. Use hardened sandboxing (NoNewPrivileges, PrivateTmp, ProtectSystem=full). Meilisearch gets separate unit. |
| LibreChat | v0.8.8-rc3 (current) | Upstream app | Source from GitHub via `[resources.sources.main]`. Build requires `npm ci` + frontend build via turbo/turborepo. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `libvips42` | Debian Bookworm | Native dep for `sharp` (image processing) | Required by LibreChat's image handling. Install via `[resources.apt]`. |
| `build-essential` | Debian Bookworm | Native build tools (gcc, make) | Required for `npm ci` on native addons. Install via `[resources.apt]`. |
| `python3` | Debian Bookworm | Required by some npm native modules | May be needed for node-gyp rebuilds. Install via `[resources.apt]`. |
| `pnpm` | as bundled by npm | Package manager (alternative) | Not needed for LibreChat -- it uses npm workspaces with turbo. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `package_check` | YunoHost app CI testing | Official tool to validate package. `yunohost app check` |
| `ynh-dev` | YunoHost development environment | LXC-based dev environment for testing packages |
| `sha256sum` | Compute checksums for sources | Required to populate `sha256` fields in manifest.toml |

## Installation

```bash
# No npm install -- this is a YunoHost package, not a JS project.
# The package is installed via:
yunohost app install /path/to/librechat_ynh

# Or from the catalog:
yunohost app install librechat
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Native (non-Docker) install | Docker-in-a-package | Never for this project. The explicit goal is to avoid Docker. Docker-in-a-package is contentious in YNH community, loses integration benefits, and hits Docker Hub rate limits in CI. |
| YNH helpers v2.1 | v2.0 helpers | Always use v2.1. The v2.0 helpers are legacy. v2.1 includes better MongoDB/Redis integration and the newer `ynh_config_add_*` pattern. |
| YNH-hat managed mongo | Manual MongoDB repo setup | Always use `ynh_install_mongo`. It handles repo setup, key management, service integration. Manual setup would duplicate YNH core logic. |
| npm (LibreChat's default) | bun | LibreChat ships support for both npm (primary) and bun (experimental). Use npm because it's the supported package manager for the release. YNH provides Node.js via n not bun. |
| Source build from GitHub tag | Prebuilt Docker images | No Docker per project scope. Must build from source. Use `[resources.sources.main]` with `autoupdate.strategy = "latest_github_tag"`. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Docker / Docker Compose | Project requirement: native install. Docker-in-package is contentious in YNH community, loss of integration, CI rate limits. | Native Node.js process under systemd |
| YNH packaging v1 (manifest.json) | Legacy format. YunoHost 11.1+ requires v2 for new packages. No resources system. | manifest.toml (packaging_format = 2) |
| Built-in MongoDB from Debian | Doesn't exist in Bookworm due to SSPL licensing. | `ynh_install_mongo` helper |
| Node.js from Debian apt (nodejs package) | Version too old (Debian ships ancient Node). YNH n manager provides proper versioning. | `[resources.nodejs]` in manifest |
| `yarn` as package manager | LibreChat uses npm workspaces + turbo. Yarn not needed and adds complexity. | Standard `npm ci` + `npm run build` |
| Separate Redis for basic install | LibreChat can work without Redis for single-instance setups. Redis is optional for multi-tab stream resume. | Skip Redis for MVP; document as optional enhancement |

## Stack Patterns by Variant

**If LibreChat upstream requires Node >22:**
- Use `[resources.nodejs] version = "24"` instead of `"22"`
- Because LibreChat `.nvmrc` specifies `24.16.0` for the current release
- Verify during each upgrade

**If MongoDB 7.0 is not available via `ynh_install_mongo`:**
- Check if Wekan's `mongo_version="8.0"` pattern works for LibreChat
- Because upstream MongoDB repo may drop older versions
- Pin version in `_common.sh` as `mongo_version="8.0"` and test

**If Meilisearch binary releases change naming pattern:**
- Update `autoupdate.asset` regex in manifest.toml
- Because GitHub release asset names may change with Meilisearch versions

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| YunoHost | >= 12.x | Latest YunoHost. ynh_install_mongo helper is available. |
| Debian | Bookworm (12) | Only supported Debian for latest YunoHost. |
| MongoDB | 7.0 (via upstream repo) | Installed via `ynh_install_mongo`. Separate from Debian apt. |
| Node.js | 22 or 24 (via YNH n) | YNH uses `n` version manager, not apt. |
| LibreChat | v0.7.8+ | Requires Node 20+. Current v0.8.8-rc3 requires 24.16.0. |
| Meilisearch | v1.x | Latest stable from GitHub releases. |
| libvips | 8.14 (libvips42 in Bookworm) | Required by sharp npm module. |

## Sources

- [YunoHost Packaging Documentation (manifest.toml)](https://yunohost.org/en/dev/packaging/manifest) — HIGH confidence (official docs)
- [YunoHost App Resources Documentation](https://yunohost.org/en/dev/packaging/resources) — HIGH confidence (official docs)
- [YunoHost App Scripts Documentation](https://yunohost.org/en/dev/packaging/scripts/) — HIGH confidence (official docs)
- [YunoHost Helpers v2.1 Documentation (MongoDB helpers)](https://yunohost.org/en/dev/packaging/scripts/helpers_v2.1) — HIGH confidence (official docs)
- [Wekan YunoHost Package (reference implementation)](https://github.com/YunoHost-Apps/wekan_ynh) — MEDIUM confidence (established YNH app with MongoDB + Node.js)
- [Wekan manifest.toml](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/manifest.toml) — HIGH confidence (official YNH app)
- [Wekan install script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/install) — HIGH confidence (verified pattern)
- [Wekan systemd unit](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/conf/systemd.service) — HIGH confidence (hardened sandboxing pattern)
- [LibreChat repository](https://github.com/danny-avila/LibreChat) — HIGH confidence (upstream source)
- [LibreChat .nvmrc](https://raw.githubusercontent.com/danny-avila/LibreChat/main/.nvmrc) — HIGH confidence (upstream Node version requirement)
- [LibreChat package.json](https://raw.githubusercontent.com/danny-avila/LibreChat/main/package.json) — HIGH confidence (build scripts and dependencies)
- [MyDrive YunoHost manifest](https://raw.githubusercontent.com/YunoHost-Apps/mydrive_ynh/master/manifest.toml) — MEDIUM confidence (another MongoDB-using YNH app)

---
*Stack research for: LibreChat YunoHost Package*
*Researched: 2026-09-18*
