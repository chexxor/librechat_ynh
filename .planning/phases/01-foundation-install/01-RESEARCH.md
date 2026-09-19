# Phase 1: Foundation + Install — Research

**Researched:** 2026-09-18
**Domain:** YunoHost native app package (format v2) wrapping LibreChat (Node.js + MongoDB + Meilisearch)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Admin email** — Prompts user during install for admin email (standard YunoHost pattern). Not auto-derived from YNH admin.
- **Admin password** — Generated as a strong random password during install. Shown at end of install output AND emailed to the admin email address. User can change it later in LibreChat account settings.
- **LLM API keys** — NOT requested during install. User configures provider keys in `librechat.yaml` after install.
- **Domain / path** — Standard YunoHost domain prompt only. App installs at root path (`/`). No sub-path support for v1.

### OpenCode's Discretion
- Exact random password generation method (length, character set)
- Email template / wording for the password email
- Install question ID naming convention in manifest
- Whether to show the admin email confirmation prompt as optional or required
- Default domain selection logic (first domain or prompt always)

### Deferred Ideas (OUT OF SCOPE)
- Provider API key prompting during install
- Sub-path install support
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SKEL-01 | `manifest.toml` (packaging v2) validates with correct YunoHost schema | See "Manifest Structure" section |
| SKEL-02 | App declares correct apt/binary sources with pinned versions (Node 22, libvips42, MongoDB 7.x, Meilisearch) | See "manifest.toml Resources" section |
| SKEL-03 | App runs under dedicated `$app` system user | `[resources.system_user]` handles this automatically |
| SKEL-04 | `sso = false`, `ldap = false` declared in `[integration]` | Confirmed in Wekan manifest pattern |
| SKEL-05 | Source tarballs pinned with sha256 integrity checks | `[resources.sources]` with sha256 — must compute at build time |
| INST-01 | Script downloads LibreChat source from GitHub (pinned tag) | `ynh_setup_source` with `[resources.sources.main]` pointing to GitHub tarball |
| INST-02 | Script builds LibreChat frontend + API (npm ci + npm run build) | See "Build Workarounds" section |
| INST-03 | Build workarounds applied: `allow-remote=true` for xlsx, `npm install --no-save unrun`, npm `.cache` stripped post-build | See "Build Workarounds" section |
| INST-04 | MongoDB installed via `ynh_install_mongo` (namespaced instance) | See "MongoDB Setup" section |
| INST-05 | Meilisearch installed as native per-arch binary with systemd unit | See "Meilisearch Setup" section |
| INST-06 | nginx reverse-proxy configured with WebSocket + SSE support | See "Nginx Template" section |
| INST-07 | LibreChat systemd service created and enabled | See "Systemd Service File" section |
| INST-08 | Initial admin user created via `npm run create-user` with `$admin` email + random password | See "Initial Admin User Creation" section |
| INST-09 | HTTPS provisioned transparently via YunoHost's Let's Encrypt | Automatic — YNH manages certs for all nginx configs |
| INST-10 | `yunohost app install librechat` returns a working, reachable LibreChat web UI | End-to-end test required after install |
| CONF-01 | All major LLM providers configurable (OpenAI, Anthropic, Ollama, OpenRouter) | Template `librechat.yaml` with comment placeholders |
| CONF-02 | `librechat.env` template with secrets placeholder | See "Config Templates" section |
| CONF-03 | `librechat.yaml` template with provider config | See "Config Templates" section |
| CONF-04 | Install questions for essential config values (admin email) | See "Install Questions" section |
</phase_requirements>

## Summary

This phase delivers `yunohost app install librechat` — a one-command install that produces a working, reachable LibreChat web UI behind HTTPS. The package follows the standard YunoHost packaging v2 format (manifest.toml) with three services: LibreChat (Node.js API + React SPA), MongoDB (namespaced via `ynh_install_mongo`), and Meilisearch (native binary, manual systemd unit). The install script orchestrates: source download → npm build (with AUR-proven workarounds) → MongoDB setup → Meilisearch install → config templates → systemd service → nginx proxy → admin user creation.

The Wekan YunoHost package is the proven reference — it handles the same MongoDB + Node.js stack with tested patterns for `ynh_install_mongo`, `ynh_mongo_setup_db`, hardened systemd, and nginx templates. The AUR LibreChat package documents three critical build issues (xlsx CDN tarball, `unrun` missing resolution, npm cache bloat) with confirmed workarounds.

**Primary recommendation:** Follow the Wekan YunoHost package structure exactly for manifest.toml, scripts, and helpers. Apply AUR build workarounds in a dedicated `librechat_build()` helper function in `_common.sh`.

## Standard Stack

### Core Technologies

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| YunoHost packaging format | v2 (manifest.toml) | App package definition | Standard since YNH 11.1. Used by all modern YNH packages (Wekan, MyDrive, etc.). |
| YunoHost helpers | 2.1 | Bash helper functions | Latest stable. Provides `ynh_install_mongo`, `ynh_mongo_setup_db`, `ynh_setup_source`, `ynh_config_add_systemd`, `ynh_config_add_nginx`, `ynh_systemctl`. |
| Node.js | 24 (via `[resources.nodejs]`) | LibreChat runtime | Upstream `.nvmrc` currently specifies `24.16.0` (verified 2026-09-18). YNH uses `n` version manager. Set `version = "24"` in manifest resources. |
| MongoDB | 7.0 (via `ynh_install_mongo`) | LibreChat database | Debian Bookworm doesn't ship MongoDB (SSPL licensing). `ynh_install_mongo` pulls from MongoDB upstream repo. Wekan successfully uses `mongo_version="8.0"` — for LibreChat, start with 7.0, test compatibility. |
| Meilisearch | v1.53.2 (latest) | LibreChat search indexing | Install as native per-arch binary from GitHub releases. No YNH helper exists. Download via `[resources.sources.meilisearch]` with `extract = false`, move binary to `/usr/bin/meilisearch`. |
| nginx (YNH-managed) | as provided by YNH | Reverse proxy, TLS termination | App provides `conf/nginx.conf` template with proxy_pass to local port. |
| systemd (YNH-integrated) | as provided by Debian | Service management x2 (LibreChat + Meilisearch) | Two unit templates: `conf/librechat.service` and `conf/meilisearch.service`. |
| LibreChat | v0.8.8-rc3 (current pre-release) | Upstream app | Source from GitHub tag tarball via `[resources.sources.main]`. Build via `npm ci` + `npx turbo run build`. Latest stable release is v0.7.8 but current active version is v0.8.8-rc3. |

### Supporting Libraries

| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| `libvips42` | Bookworm | Native dep for `sharp` (image processing) | Required by LibreChat's image handling. Install via `[resources.apt]`. |
| `build-essential` | Bookworm | Native build tools (gcc, make) | Required for `npm ci` on native addons. Install via `[resources.apt]`. |
| `python3` | Bookworm | Required by some npm native modules | May be needed for node-gyp rebuilds. Include as precaution. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Node 24 via `[resources.nodejs]` | Node 22 | Upstream `.nvmrc` says `24.16.0`. Node 22 may not build. Must match upstream. |
| MongoDB via `ynh_install_mongo` | Manual upstream repo setup | `ynh_install_mongo` is the standard YNH pattern (used by Wekan, MyDrive). Manual setup duplicates YNH core logic. |
| Meilisearch binary via `[resources.sources]` | Meilisearch .deb package | .deb exists but may not support all architectures as cleanly. Binary is simpler for `extract = false` in sources. |
| `npm ci` + `turbo run build` | `bun` (experimental) | LibreChat supports both. npm is the primary, YNH provides Node.js via n. bun is experimental upstream. |

**Installation (the package itself, not npm packages):**
```bash
# The package lives in a Git repo and is installed via:
yunohost app install /path/to/librechat_ynh

# Or once in catalog:
yunohost app install librechat
```

## Architecture Patterns

### Recommended Project Structure
```
librechat_ynh/
├── manifest.toml
├── scripts/
│   ├── _common.sh           # librechat_build() helper with AUR workarounds
│   ├── install              # Source → build → mongo → meili → systemd → nginx → admin user
│   ├── upgrade              # Rebuild + config merge (skipped in Phase 1, template only)
│   ├── remove               # Namespaced cleanup (skipped in Phase 1, template only)
│   ├── backup               # mongodump (skipped in Phase 1, template only)
│   └── restore              # Re-download meili binary (skipped in Phase 1, template only)
├── conf/
│   ├── nginx.conf           # WebSocket + SSE proxy config
│   ├── librechat.service    # Hardened systemd unit
│   ├── meilisearch.service  # Simple systemd unit for native binary
│   ├── librechat.env        # Secrets template (preserved on upgrade)
│   └── librechat.yaml       # Provider config template (preserved on upgrade)
└── doc/
    ├── DESCRIPTION.md
    ├── ADMIN.md
    └── screenshots/
```

### Install Script Flow (Order of Operations)
```
1. ynh_script_init
2. ynh_script_progression "Installing dependencies..."
   → ynh_install_mongo  (sets up MongoDB globally)
3. ynh_script_progression "Setting up source files..."
   → ynh_setup_source --dest_dir="$install_dir"  (LibreChat source)
   → ynh_setup_source --dest_dir="/usr/bin" --source_id="meilisearch"  (Meilisearch binary)
4. ynh_script_progression "Creating MongoDB database..."
   → db_name=$(ynh_sanitize_dbid --db_name=$app)
   → db_user=$db_name
   → ynh_app_setting_set --key=db_name --value=$db_name
   → ynh_mongo_setup_db --db_user=$db_user --db_name=$db_name
5. ynh_script_progression "Building LibreChat..."
   → pushd $install_dir
   → npm config set allow-remote true
   → npm ci
   → npm install --no-save unrun
   → npx turbo run build --no-daemon
   → rm -rf .npm/_cacache/  (strip cache bloat)
   → popd
6. ynh_script_progression "Adding configuration files..."
   → ynh_config_add --template="librechat.env" --destination="$install_dir/librechat.env"
   → ynh_config_add --template="librechat.yaml" --destination="$install_dir/librechat.yaml"
7. ynh_script_progression "Configuring nginx..."
   → ynh_config_add_nginx
8. ynh_script_progression "Configuring systemd..."
   → ynh_config_add_systemd --template="librechat.service"
   → ynh_config_add_systemd --template="meilisearch.service" --service="meilisearch"
   → yunohost service add $app --description="LibreChat daemon" --log="/var/log/$app/$app.log"
   → yunohost service add meilisearch --description="Meilisearch search engine" --log="/var/log/meilisearch/meilisearch.log"
9. ynh_script_progression "Starting services..."
   → ynh_systemctl --service="meilisearch" --action="start"
   → ynh_systemctl --service=$app --action="start"
10. ynh_script_progression "Creating admin user..."
    → Generate random password via ynh_string_random --length=24
    → ynh_exec_as_app node config/create-user.js "$admin_email" "Admin" "admin" "$admin_password"
11. ynh_script_progression "Sending admin email..."
    → Send email with password (via ynh_send_email_to_admin or custom)
```

### _common.sh Structure
```bash
#!/bin/bash

# COMMON VARIABLES
mongo_version="7.0"

# CUSTOM HELPERS
librechat_build() {
    pushd "$install_dir"
    # AUR workaround 1: xlsx CDN tarball
    npm config set allow-remote true
    
    # Install dependencies
    ynh_exec_as_app npm ci
    
    # AUR workaround 2: unrun missing resolution
    ynh_exec_as_app npm install --no-save unrun
    
    # Build via turbo (no daemon for CI compatibility)
    ynh_exec_as_app npx turbo run build --no-daemon
    
    # AUR workaround 3: strip npm cache bloat
    rm -rf "$install_dir/.npm"
    popd
}
```

### Manifest Structure
```toml
packaging_format = 2

id = "librechat"
name = "LibreChat"
description.en = "Multi-provider chat UI for LLMs (OpenAI, Anthropic, Ollama, ...)"

version = "0.8.8-rc3~ynh1"

maintainers = ["your-username"]

[upstream]
license = "MIT"
website = "https://librechat.ai"
code = "https://github.com/danny-avila/LibreChat"

[integration]
yunohost = ">= 12.1.40"
helpers_version = "2.1"
architectures = ["amd64", "arm64"]
multi_instance = true

ldap = false
sso = false

disk = "50M"
ram.build = "2G"
ram.runtime = "500M"

[install]
    [install.domain]
    type = "domain"
    
    [install.admin_email]
    type = "text"
    ask.en = "Enter the admin email address for notifications"
    example = "admin@example.com"
    pattern_regexp = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

[resources]
    [resources.sources.main]
    url = "https://github.com/danny-avila/LibreChat/archive/refs/tags/v0.8.8-rc3.tar.gz"
    sha256 = "FILL_ME"  # Compute at build time
    in_subdir = true
    autoupdate.strategy = "latest_github_tag"
    
    [resources.sources.meilisearch]
    amd64.url = "https://github.com/meilisearch/meilisearch/releases/download/v1.53.2/meilisearch-linux-amd64"
    amd64.sha256 = "6c00019a887813ccbce54eec52718c9343bf4234383871146c67c76b1d2646cd"
    arm64.url = "https://github.com/meilisearch/meilisearch/releases/download/v1.53.2/meilisearch-linux-aarch64"
    arm64.sha256 = "12a38c387953e61807a5a0deb64e4bf52def38e49872c7963949a7d4d41a2117"
    format = "script"    # Binary, not an archive — no extraction
    extract = false
    rename = "meilisearch"
    autoupdate.strategy = "latest_github_release"
    autoupdate.asset.amd64 = "meilisearch-linux-amd64$"
    autoupdate.asset.arm64 = "meilisearch-linux-aarch64$"
    
    [resources.apt]
    packages = ["libvips42", "build-essential", "python3"]
    
    [resources.ports]
    main.default = 3080  # LibreChat default port
    
    [resources.system_user]
    allow_email = true   # Needed for sending admin password email
    
    [resources.install_dir]
    
    [resources.permissions]
    main.url = "/"
    admin.allowed = "admins"
    
    [resources.nodejs]
    version = "24"  # Must match upstream .nvmrc (24.16.0 as of 2026-09-18)
```

### Anti-Patterns to Avoid
- **Custom password generation that doesn't use `ynh_string_random`:** YNH provides a standard helper. Use `admin_password=$(ynh_string_random --length=24)`.
- **Calling `ynh_remove_mongo` in any script:** Destroys shared MongoDB for all apps. Use ONLY `ynh_mongo_remove_db`.
- **Hardcoding port 3080 in nginx:** Use `__PORT__` template variable which resolves to the YNH-booked port.
- **Using `npm run build` without `--no-daemon`:** turbo daemon causes CI timeouts. Always use `--no-daemon`.
- **Setting `SEARCH=true` and `MEILI_MASTER_KEY` in template:** The env template should have search disabled by default. User enables it.

## Build Workarounds

Three confirmed issues from the AUR LibreChat package that must be handled in the install script:

### Issue 1: xlsx CDN Tarball Blocked by npm
**What:** The `xlsx` npm package tries to download a CDN binary tarball during install. npm's default config blocks this.
**Fix:** Set `npm config set allow-remote true` before `npm ci` runs.
**Alternative:** Use `--ignore-scripts` but this may break other native module builds.

### Issue 2: `unrun` Missing from npm ci Resolution
**What:** The `unrun` package is a transitive dependency that `npm ci` can't resolve because it's not in the lockfile in some versions.
**Fix:** Run `npm install --no-save unrun` after `npm ci` but before the frontend build step.
**Note:** The exact version needed is not specified in AUR. We install latest compatible version — it's a dev dependency only.

### Issue 3: npm Cache Bloat in App Tree
**What:** `.npm/_cacache/` can grow to 500MB+ inside the install directory.
**Fix:** Add `rm -rf "$install_dir/.npm"` after successful build.

### Confirmed Order of Operations
```bash
# Correct build sequence:
npm config set allow-remote true
npm ci                              # Clean install from lockfile
npm install --no-save unrun         # AUR workaround: missing resolution
npx turbo run build --no-daemon     # Build all workspaces
rm -rf "$install_dir/.npm"          # Strip cache bloat
```

## MongoDB Setup

### How ynh_install_mongo Works
Declare `mongo_version="7.0"` in `_common.sh` as a global variable. Then in install:
```bash
ynh_install_mongo
```
This installs MongoDB from the upstream MongoDB apt repository (handles repo setup, GPG keys, service integration). MongoDB runs as a global service on the system.

### Namespaced Database Creation
```bash
db_name=$(ynh_sanitize_dbid --db_name=$app)
db_user=$db_name
ynh_app_setting_set --key=db_name --value=$db_name
ynh_mongo_setup_db --db_user=$db_user --db_name=$db_name
# After this, $db_pwd is available with the generated password
# The password is also stored as "mongopwd" in app settings
```

### MONGO_URI Format for LibreChat
LibreChat expects:
```
MONGO_URI=mongodb://127.0.0.1:27017/librechat
```
OR with auth (what `ynh_mongo_setup_db` creates):
```
MONGO_URI=mongodb://$db_user:$db_pwd@127.0.0.1:27017/$db_name
```

The env template should use `$db_user` and `$db_pwd` via template variables. **However**, `ynh_config_add` does NOT automatically expose mongo db_pwd as a template variable — it must be set explicitly.

### Key Detail: Template Variables for MongoDB
The `ynh_config_add` helper replaces patterns like `__FOO__` with bash variable `$foo`. For MongoDB secrets:
```bash
# In install script, after ynh_mongo_setup_db:
db_pwd=$(ynh_app_setting_get --key=mongopwd)
# Then template variables __DB_NAME__, __DB_USER__, __DB_PWD__ are resolved
```
But these vars are NOT automatically passed to `ynh_config_add`. They must be defined in shell scope.

**Recommendation:** After `ynh_mongo_setup_db`, also do:
```bash
# Read back the MongoDB password from settings (ynh_mongo_setup_db stores it)
db_pwd=$(ynh_app_setting_get --key=mongopwd)
```

## Meilisearch Setup

### Binary Installation Pattern (No YNH Helper Exists)

**Source declaration** in manifest.toml (see above for `[resources.sources.meilisearch]`). The binary is downloaded from GitHub releases as a static binary: `format = "script"`, `extract = false`.

**In install script:**
```bash
# Sources resource auto-downloads to cache
# ynh_setup_source with source_id="meilisearch" moves it to dest_dir
ynh_setup_source --dest_dir="/usr/bin" --source_id="meilisearch"
chmod +x /usr/bin/meilisearch
```

**Env vars for LibreChat:**
```
MEILI_HOST=http://127.0.0.1:7700
MEILI_MASTER_KEY=<generated-random-key>
MEILI_NO_ANALYTICS=true
```

### Generating MEILI_MASTER_KEY
```bash
meili_master_key=$(ynh_string_random --length=32)
ynh_app_setting_set --key=meili_master_key --value=$meili_master_key
```

### Meilisearch Systemd Unit (`conf/meilisearch.service`)
```systemd
[Unit]
Description=Meilisearch search engine for __APP__
After=network.target

[Service]
Type=simple
User=__APP__
Group=__APP__
ExecStart=/usr/bin/meilisearch \
    --http-addr 127.0.0.1:7700 \
    --master-key __MEILI_MASTER_KEY__ \
    --db-path __DATA_DIR__/meilisearch \
    --no-analytics=true
Restart=on-failure

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes

[Install]
WantedBy=multi-user.target
```

**IMPORTANT:** Meilisearch's default data directory is `./data.ms` relative to working directory. The `--db-path` flag must point to `__DATA_DIR__/meilisearch` so data persists across upgrades.

## Nginx Template

### Required Config (`conf/nginx.conf`)
```nginx
location __PATH__/ {

  proxy_pass http://127.0.0.1:__PORT__;
  
  # WebSocket support (required for LibreChat real-time features)
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  
  # SSE streaming support (required for LLM response streaming)
  proxy_buffering off;
  proxy_cache off;
  
  # Standard proxy headers
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  
  include proxy_params_no_auth;
  
  client_max_body_size 100M;
}
```

### Why These Headers Are Critical
- **`proxy_http_version 1.1`**: WebSocket requires HTTP/1.1 (HTTP/1.0 doesn't support upgrade mechanism)
- **`proxy_set_header Upgrade $http_upgrade`** and **`Connection "upgrade"`**: Tells nginx to perform the WebSocket handshake upgrade
- **`proxy_buffering off`**: Without this, SSE (Server-Sent Events) streams are buffered and the LLM response appears to hang — the user sees no output until the entire response is complete, which can be minutes
- **`proxy_cache off`**: Prevents nginx from caching streaming responses

**Without these, the chat appears completely broken** — requests seem to hang with no error message. This is the single most common LibreChat+nginx mistake.

## Systemd Service File

### LibreChat Service (`conf/librechat.service`)
```systemd
[Unit]
Description=LibreChat: multi-provider LLM chat UI
Wants=mongod.service meilisearch.service
After=network.target mongod.service meilisearch.service

[Service]
Type=simple
User=__APP__
Group=__APP__
EnvironmentFile=__INSTALL_DIR__/librechat.env
WorkingDirectory=__INSTALL_DIR__/
ExecStart=__NODEJS_DIR__/node api/server/index.js
Restart=on-failure
RestartSec=10

# Hardened sandboxing (Wekan pattern)
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK
RestrictNamespaces=yes
RestrictRealtime=yes
DevicePolicy=closed
ProtectClock=yes
ProtectHostname=yes
ProtectProc=invisible
ProtectSystem=full
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
LockPersonality=yes
SystemCallArchitectures=native

# Deny dangerous capabilities
CapabilityBoundingSet=~CAP_RAWIO CAP_MKNOD
CapabilityBoundingSet=~CAP_AUDIT_CONTROL CAP_AUDIT_READ CAP_AUDIT_WRITE
CapabilityBoundingSet=~CAP_SYS_BOOT CAP_SYS_TIME CAP_SYS_MODULE CAP_SYS_PACCT
CapabilityBoundingSet=~CAP_LEASE CAP_LINUX_IMMUTABLE CAP_IPC_LOCK
CapabilityBoundingSet=~CAP_BLOCK_SUSPEND CAP_WAKE_ALARM
CapabilityBoundingSet=~CAP_SYS_TTY_CONFIG
CapabilityBoundingSet=~CAP_MAC_ADMIN CAP_MAC_OVERRIDE
CapabilityBoundingSet=~CAP_NET_ADMIN CAP_NET_BROADCAST CAP_NET_RAW
CapabilityBoundingSet=~CAP_SYS_ADMIN CAP_SYS_PTRACE CAP_SYSLOG

[Install]
WantedBy=multi-user.target
```

### Key Detail: EnvironmentFile Sourcing
The `EnvironmentFile=__INSTALL_DIR__/librechat.env` directive means all variables in `librechat.env` are loaded into the service environment. LibreChat reads `MONGO_URI`, `MEILI_*`, `JWT_SECRET`, etc. from env vars. This is simpler than an env-sourcing wrapper script (though AUR uses a wrapper, the `EnvironmentFile` approach is cleaner for systemd).

### Adding Two Services in Install Script
```bash
# LibreChat service
ynh_config_add_systemd --template="librechat.service"

# Meilisearch service (must explicitly name the template and service)
ynh_config_add_systemd --template="meilisearch.service" --service="meilisearch"
```

### Registering Services with YunoHost
```bash
yunohost service add $app --description="LibreChat daemon" --log="/var/log/$app/$app.log"
yunohost service add meilisearch --description="Meilisearch search engine" --log="/var/log/meilisearch/meilisearch.log"
```

## Config Templates

### librechat.env Template (`conf/librechat.env`)
This must define the minimum environment variables LibreChat needs to start. Variables with `__XX__` are replaced by YNH template engine.

```
# Server
HOST=localhost
PORT=__PORT__
DOMAIN_CLIENT=https://__DOMAIN__
DOMAIN_SERVER=https://__DOMAIN__
TRUST_PROXY=1

# MongoDB
MONGO_URI=mongodb://__DB_USER__:__DB_PWD__@127.0.0.1:27017/__DB_NAME__

# Meilisearch (disabled by default — user must SEARCH=true and set MEILI_MASTER_KEY)
SEARCH=false
MEILI_HOST=http://127.0.0.1:7700
MEILI_MASTER_KEY=__MEILI_MASTER_KEY__
MEILI_NO_ANALYTICS=true

# JWT Secrets (generated during install)
JWT_SECRET=__JWT_SECRET__
JWT_REFRESH_SECRET=__JWT_REFRESH_SECRET__

# Admin panel session secret
ADMIN_PANEL_SESSION_SECRET=__ADMIN_PANEL_SESSION_SECRET__

# Registration (start closed, admin creates users)
ALLOW_REGISTRATION=false

# Logging
DEBUG_LOGGING=true
LOG_TO_FILE=true

# Node
NODE_ENV=production
```

### librechat.yaml Template (`conf/librechat.yaml`)
```yaml
# LibreChat Provider Configuration
# Add your API keys below. This file is preserved on upgrade.

version: 1.1.1

# === Provider Endpoints ===
# Uncomment and configure the providers you want to use.

# OpenAI
# endpoints:
#   openAI:
#     apiKey: "your-openai-api-key"
#     models:
#       default: ["gpt-4o", "gpt-4o-mini"]

# Anthropic
#   anthropic:
#     apiKey: "your-anthropic-api-key"
#     models:
#       default: ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"]

# Ollama (local)
#   ollama:
#     apiKey: ""  # Not needed for local Ollama

# OpenRouter
#   openRouter:
#     apiKey: "your-openrouter-api-key"

# Customization
# registration:
#   socialLogins: []
#   allowedDomains: []
```

### Generating Secrets During Install
```bash
# Generate secrets before calling ynh_config_add for librechat.env
jwt_secret=$(ynh_string_random --length=64)
jwt_refresh_secret=$(ynh_string_random --length=64)
admin_panel_secret=$(ynh_string_random --length=64)
meili_master_key=$(ynh_string_random --length=32)

# Store in app settings for persistence across upgrades
ynh_app_setting_set --key=jwt_secret --value=$jwt_secret
ynh_app_setting_set --key=jwt_refresh_secret --value=$jwt_refresh_secret
ynh_app_setting_set --key=admin_panel_secret --value=$admin_panel_secret
ynh_app_setting_set --key=meili_master_key --value=$meili_master_key
```

**IMPORTANT:** Template variables only work if the corresponding bash variable is in scope when `ynh_config_add` is called. The variable name in bash must match the template tag: `__JWT_SECRET__` ↔ `$jwt_secret` (lowercase).

## Initial Admin User Creation

### How LibreChat's create-user Works
```bash
# Usage from LibreChat root:
node config/create-user.js <email> <name> <username> [password] [--email-verified=false]

# Arguments:
#   email     - Required. Admin email address.
#   name      - Required. Display name (e.g., "Admin").
#   username  - Required. Login username (e.g., "admin").
#   password  - Optional (insecure to pass as arg). If omitted, prompts interactively.
#   --email-verified=true  - Default true. Set false to require email verification.

# For non-interactive use (our case):
echo "$password" | node config/create-user.js "$email" "Admin" "admin" --email-verified=true

# OR pass password as 4th argument (less secure but needed for headless):
node config/create-user.js "$email" "Admin" "admin" "$password" --email-verified=true
```

Source: https://github.com/danny-avila/LibreChat/blob/main/config/create-user.js

### In the Install Script (post-build, post-service)
```bash
# Generate admin password
admin_password=$(ynh_string_random --length=24)
ynh_app_setting_set --key=admin_password --value=$admin_password

# Must be run from install_dir as the app user
# The create-user script connects to MongoDB to create the user
pushd "$install_dir"
ynh_exec_as_app node config/create-user.js "$admin_email" "Admin" "admin" "$admin_password" --email-verified=true
popd
```

### When to Run create-user
The script MUST run AFTER:
1. MongoDB is set up (database exists and is accessible)
2. LibreChat build is complete (config/create-user.js exists)
3. But it does NOT need the LibreChat service to be running — it talks directly to MongoDB

### Password Delivery to User
- **Install output:** Print password at end with `ynh_script_progression` or `ynh_print_info`
- **Email:** Use YunoHost's mail system to email the admin. Since `[resources.system_user]` has `allow_email = true`, the app system user can send mail.

**Email command (standard YNH pattern):**
```bash
echo "Your LibreChat admin password is: $admin_password" \
  | mail -s "Your LibreChat admin account" "$admin_email"
```

## Install Questions in Manifest

### YNH Built-in Domain Question
```toml
[install.domain]
type = "domain"
```
This is handled automatically by YNH. The value is available as `$domain` in install scripts.

### Custom Admin Email Question
```toml
[install.admin_email]
type = "text"
ask.en = "Enter the admin email address for notifications"
example = "admin@example.com"
pattern_regexp = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
```

The value is available as `$admin_email` in install scripts (the key name after `install.` prefix).

### Question ID Convention (OpenCode's Discretion)
Use lower_case_with_underscores matching the variable name. The variable in scripts will be `$admin_email` matching the key `admin_email`. This is the standard YNH convention.

### Default Domain Selection (OpenCode's Discretion)
Standard YNH behavior: prompts user to select from available domains. This is acceptable — no need for auto-selection logic.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MongoDB installation | Manual repo setup, GPG import | `ynh_install_mongo` | Handles Bookworm compat, repo setup, service integration |
| MongoDB database/user creation | Direct mongo shell scripts | `ynh_mongo_setup_db` | Generates password, creates user, handles namespacing |
| nginx config generation | Manual file write | `ynh_config_add_nginx` | Integrates with YNH's ssl, domain, port management |
| systemd unit installation | Manual unit file copy + systemctl | `ynh_config_add_systemd` | Handles template replacement, enable, proper paths |
| Service start/wait | Raw systemctl | `ynh_systemctl` | Logs on failure, optional wait for startup |
| Source download/checksum | curl + sha256sum | `ynh_setup_source` | Handles cache, arch selection, integrity check |
| Random password generation | openssl rand, /dev/urandom | `ynh_string_random` | Standard YNH pattern, consistent length |
| Config file templating | sed replacements | `ynh_config_add` | __VAR__ template engine, checksum backup |

**Key insight:** YunoHost provides helpers for everything in this package except Meilisearch (which is a simple binary download+move) and the LibreChat build itself. Every helper is tested across hundreds of packages. The `ynh_install_mongo` helper is especially important — it handles the tricky MongoDB-on-Bookworm setup that caused issues in early Wekan packaging.

## Common Pitfalls

### Pitfall 1: WebSocket/SSE Silent Failure
**What goes wrong:** LibreChat streaming responses appear broken (no output, connection hangs). Users see blank responses.
**Why it happens:** Default nginx config doesn't set WebSocket upgrade headers or disable SSE buffering.
**How to avoid:** The nginx template MUST include `proxy_http_version 1.1`, `proxy_set_header Upgrade $http_upgrade`, `proxy_set_header Connection "upgrade"`, and `proxy_buffering off`.
**Warning signs:** nginx access log shows 200 responses but browser WebSocket connections are immediately closed.

### Pitfall 2: AUR Build Issues
**What goes wrong:** `npm ci` fails because xlsx can't download CDN tarball; `unrun` missing from lockfile; npm cache bloats to 500MB.
**Why it happens:** LibreChat's turbo monorepo has unusual transitive dependency behavior.
**How to avoid:** Apply three workarounds in `librechat_build()`: `npm config set allow-remote true`, `npm install --no-save unrun`, and `rm -rf .npm` post-build.
**Warning signs:** npm error about CDN tarball download; build succeeds but `du -sh .npm` is >100MB.

### Pitfall 3: Node Version Mismatch
**What goes wrong:** `npm ci` or build fails with cryptic errors related to engine requirements.
**Why it happens:** LibreChat's `.nvmrc` specifies `24.16.0` (Node 24). If YNH manifest specifies Node 22, the build may fail.
**How to avoid:** Set `[resources.nodejs] version = "24"` in manifest. Verify against upstream `.nvmrc` at each package upgrade.
**Warning signs:** npm error "Unsupported engine" during npm ci.

### Pitfall 4: MongoDB Connection Refused
**What goes wrong:** LibreChat starts but can't connect to MongoDB. `ENOTFOUND` or connection refused errors in logs.
**Why it happens:** MongoDB service isn't fully started when LibreChat tries to connect (race condition on first boot).
**How to avoid:** Set `Wants=mongod.service` and `After=mongod.service` in systemd unit. MongoDB is started by `ynh_install_mongo` as `mongod.service`.
**Warning signs:** LibreChat logs show `MongooseError: MongoTimeoutError` at startup.

### Pitfall 5: Config Overwrite on Upgrade
**What goes wrong:** After upgrade, all user API keys and settings are gone.
**Why it happens:** `ynh_setup_source --full_replace` wipes the directory before extracting new source.
**How to avoid:** This is a Phase 3 concern, but the install sets up the pattern: `librechat.env` and `librechat.yaml` are placed by `ynh_config_add`, and `ynh_setup_source` during upgrade must use `--keep="librechat.env librechat.yaml"`.
**Warning signs:** (Not applicable in Phase 1, but be aware for architecture.)

### Pitfall 6: `__PORT__` vs hardcoded port
**What goes wrong:** The app starts on port 3080, nginx proxies to 3080, but YNH booked a different port.
**Why it happens:** The port declared in `[resources.ports]` might differ from the actual booked port if 3080 was already in use.
**How to avoid:** Always use `__PORT__` in nginx.conf template. The `PORT` env var in `librechat.env` must use `__PORT__` too.
**Warning signs:** nginx returns 502 Bad Gateway.

## Code Examples

### Full Install Script Pattern (Wekan-based)
```bash
#!/bin/bash
source _common.sh
source /usr/share/yunohost/helpers

#=================================================
# INSTALL DEPENDENCIES
#=================================================
ynh_script_progression "Installing dependencies..."
ynh_install_mongo

#=================================================
# SET UP SOURCE FILES
#=================================================
ynh_script_progression "Setting up source files..."
ynh_setup_source --dest_dir="$install_dir"
ynh_setup_source --dest_dir="/usr/bin" --source_id="meilisearch"
chmod +x /usr/bin/meilisearch

#=================================================
# CREATE MONGODB DATABASE
#=================================================
ynh_script_progression "Creating MongoDB database..."
db_name=$(ynh_sanitize_dbid --db_name=$app)
db_user=$db_name
ynh_app_setting_set --key=db_name --value=$db_name
ynh_mongo_setup_db --db_user=$db_user --db_name=$db_name

# Read back MongoDB password for template variables
db_pwd=$(ynh_app_setting_get --key=mongopwd)

#=================================================
# GENERATE SECRETS
#=================================================
ynh_script_progression "Generating secrets..."
jwt_secret=$(ynh_string_random --length=64)
jwt_refresh_secret=$(ynh_string_random --length=64)
admin_panel_secret=$(ynh_string_random --length=64)
meili_master_key=$(ynh_string_random --length=32)
admin_password=$(ynh_string_random --length=24)

# Store for persistence
ynh_app_setting_set --key=jwt_secret --value=$jwt_secret
ynh_app_setting_set --key=jwt_refresh_secret --value=$jwt_refresh_secret
ynh_app_setting_set --key=admin_panel_secret --value=$admin_panel_secret
ynh_app_setting_set --key=meili_master_key --value=$meili_master_key
ynh_app_setting_set --key=admin_password --value=$admin_password

#=================================================
# BUILD APP
#=================================================
ynh_script_progression "Building LibreChat..."
librechat_build

#=================================================
# ADD CONFIGURATION FILES
#=================================================
ynh_script_progression "Adding configuration files..."
ynh_config_add --template="librechat.env" --destination="$install_dir/librechat.env"
ynh_config_add --template="librechat.yaml" --destination="$install_dir/librechat.yaml"

#=================================================
# NGINX CONFIGURATION
#=================================================
ynh_script_progression "Configuring nginx..."
ynh_config_add_nginx

#=================================================
# SYSTEMD CONFIGURATION
#=================================================
ynh_script_progression "Configuring systemd services..."
ynh_config_add_systemd --template="librechat.service"
ynh_config_add_systemd --template="meilisearch.service" --service="meilisearch"

yunohost service add $app --description="LibreChat daemon" --log="/var/log/$app/$app.log"
yunohost service add meilisearch --description="Meilisearch search engine" --log="/var/log/meilisearch/meilisearch.log"

#=================================================
# START SERVICES
#=================================================
ynh_script_progression "Starting services..."
ynh_systemctl --service="meilisearch" --action="start"
ynh_systemctl --service=$app --action="start"

#=================================================
# CREATE ADMIN USER
#=================================================
ynh_script_progression "Creating admin user..."
pushd "$install_dir"
ynh_exec_as_app node config/create-user.js "$admin_email" "Admin" "admin" "$admin_password" --email-verified=true
popd

#=================================================
# SEND ADMIN PASSWORD
#=================================================
ynh_script_progression "Sending admin email..."
echo "Your LibreChat admin account has been created.

Admin email: $admin_email
Admin password: $admin_password

You can log in at https://$domain/

After logging in, configure your LLM provider API keys in librechat.yaml
located at: $install_dir/librechat.yaml" \
  | mail -s "Your LibreChat admin account" "$admin_email"

ynh_print_info "Admin password: $admin_password"

#=================================================
# END OF SCRIPT
#=================================================
ynh_script_progression "Installation of $app completed"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| YNH packaging v1 (manifest.json) | v2 (manifest.toml) | YNH 11.1 (2023) | Resources system, auto-provisioning of ports/users/permissions |
| `ynh_install_mongo --mongo_version=...` | `mongo_version` global var | Helpers v2.1 | Must define `mongo_version` in `_common.sh` before calling helper |
| Wekan uses Node 22 | Wekan upgraded to Node 24 | Wekan PR 2025 | Wekan tracks upstream — confirms Node 24 is viable in YNH |
| LibreChat v0.7.8 | v0.8.8-rc3 | 2026-09-15 | Active development, release candidates include latest features |
| Meilisearch v1.12 | v1.53.2 | 2026-09-07 | Fast-moving project; use `latest_github_release` autoupdate strategy |

**Deprecated/outdated:**
- YNH packaging v1 (manifest.json): Don't use for new packages
- Old-style `ynh_install_mongo` with `--mongo_version` flag: Helpers v2.1 uses `$mongo_version` global instead
- Wekan's old Mongo version (3.2, 4.4): Bookworm compatibility requires 7.0+

## Open Questions

1. **MongoDB 7.0 vs 8.0 compatibility with LibreChat**
   - What we know: Wekan uses `mongo_version="8.0"` successfully. LibreChat's MongoDB driver is generally compatible with 7.x and 8.x.
   - What's unclear: Whether all LibreChat queries/indexes work on MongoDB 8.0 without issues.
   - Recommendation: Start with `mongo_version="7.0"` in `_common.sh`. Test during development. If 7.0 is not available from upstream repo, try 8.0.
   - **Needs verification during implementation.**

2. **`unrun` package version requirement**
   - What we know: AUR package requires `npm install --no-save unrun` as a workaround for missing resolution.
   - What's unclear: Exact version needed, and whether this is still needed in the latest LibreChat release (v0.8.8-rc3).
   - Recommendation: Run `npm install --no-save unrun` unconditionally in `librechat_build()`. It's harmless if already present.
   - **Needs verification during implementation.**

3. **Systemd service ordering with MongoDB**
   - What we know: LibreChat needs MongoDB to be running before it starts. `After=mongod.service` in systemd unit.
   - What's unclear: Whether `mongod.service` is exactly the name. Need to verify what `ynh_install_mongo` creates.
   - Recommendation: Use `Wants=mongod.service` and `After=network.target mongod.service`. Verify service name during testing.
   - **Needs verification during implementation.**

4. **Meilisearch `--db-path` default**
   - What we know: Meilisearch defaults to `./data.ms` relative to working directory. For systemd, working directory defaults to `/`.
   - What's unclear: Whether `--db-path __DATA_DIR__/meilisearch` works correctly with the user/group permissions.
   - Recommendation: Use `--db-path` flag. Ensure `__DATA_DIR__/meilisearch` directory exists and is owned by `__APP__` user.
   - **Needs verification during implementation.**

## Sources

### Primary (HIGH confidence)
- [YunoHost Packaging Documentation (manifest.toml)](https://yunohost.org/en/dev/packaging/manifest) — Verified manifest structure
- [YunoHost App Resources Documentation](https://yunohost.org/en/dev/packaging/resources) — Verified resources (sources, nodejs, apt, ports, system_user, install_dir, permissions)
- [YunoHost Helpers v2.1 Documentation](https://yunohost.org/en/dev/packaging/scripts/helpers_v2.1) — Verified MongoDB helpers, templating, systemd, nginx
- [Wekan YunoHost manifest.toml](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/manifest.toml) — Verified packaging v2 pattern
- [Wekan install script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/install) — Verified MongoDB + Node.js install pattern
- [Wekan systemd unit](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/conf/systemd.service) — Verified hardened sandboxing
- [Wekan nginx config](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/conf/nginx.conf) — Verified nginx template pattern
- [Wekan upgrade script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/upgrade) — Verified `--keep` config preservation pattern
- [LibreChat package.json](https://github.com/danny-avila/LibreChat/blob/main/package.json) — Verified build scripts, turbo usage, create-user command
- [LibreChat .nvmrc](https://raw.githubusercontent.com/danny-avila/LibreChat/main/.nvmrc) — Verified Node 24.16.0 requirement
- [LibreChat .env.example](https://raw.githubusercontent.com/danny-avila/LibreChat/main/.env.example) — Verified env var structure
- [LibreChat config/create-user.js](https://raw.githubusercontent.com/danny-avila/LibreChat/main/config/create-user.js) — Verified CLI args for user creation
- [Meilisearch v1.53.2 release assets](https://api.github.com/repos/meilisearch/meilisearch/releases/latest) — Verified binary download URLs and sha256

### Secondary (MEDIUM confidence)
- [AUR LibreChat Package (PKGBUILD)](https://aur.archlinux.org/packages/librechat) — Documented xlsx CDN tarball, unrun missing, npm cache bloat issues
- [MyDrive YunoHost manifest](https://raw.githubusercontent.com/YunoHost-Apps/mydrive_ynh/master/manifest.toml) — Another MongoDB-using YNH app (confirming patterns)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All choices verified against YunoHost official docs, Wekan reference implementation, and upstream LibreChat source.
- Architecture: HIGH — Wekan's proven patterns map directly to LibreChat's requirements. No speculative architecture — each component has a verified YNH integration pattern.
- Pitfalls: HIGH — AUR build issues have confirmed workarounds. nginx WebSocket/SSE issue is well-documented upstream. MongoDB namespacing is proven in Wekan.
- Meilisearch binary install: MEDIUM — The `[resources.sources]` with binary download is standard, but the exact systemd unit flags and `--db-path` behavior need testing.

**Research date:** 2026-09-18
**Valid until:** 7 days (LibreChat is fast-moving; Node version and build process may change with each release)
