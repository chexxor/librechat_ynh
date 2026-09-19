---
phase: 01-foundation-install
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
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
autonomous: true
requirements:
  - SKEL-01
  - SKEL-02
  - SKEL-03
  - SKEL-04
  - SKEL-05
  - CONF-01
  - CONF-02
  - CONF-03
  - CONF-04
  - INST-06
  - INST-07
  - INST-09

must_haves:
  truths:
    - "Package has a valid manifest.toml that declares all required resources"
    - "nginx template includes WebSocket upgrade headers and SSE buffering off"
    - "systemd service templates exist for both LibreChat and Meilisearch"
    - "librechat.env template has all secrets placeholders (MONGO_URI, JWT_SECRET, etc.)"
    - "librechat.yaml template has provider config blocks for OpenAI, Anthropic, Ollama, OpenRouter"
    - "manifest.toml has admin email install question"
    - "Source tarballs are pinned with sha256 integrity"
    - "Upgrade/remove/backup/restore script stubs exist"
  artifacts:
    - path: "manifest.toml"
      provides: "Package definition with resources, install questions, upstream info"
      min_lines: 60
    - path: "conf/nginx.conf"
      provides: "nginx reverse proxy template with WebSocket + SSE support"
      contains: "proxy_set_header Upgrade"
    - path: "conf/librechat.service"
      provides: "Hardened systemd unit for LibreChat"
      contains: "EnvironmentFile="
    - path: "conf/meilisearch.service"
      provides: "Systemd unit for Meilisearch"
      contains: "ExecStart="
    - path: "conf/librechat.env"
      provides: "Environment template with secret placeholders"
      contains: "MONGO_URI"
    - path: "conf/librechat.yaml"
      provides: "Provider config template"
      contains: "openAI"
    - path: "doc/DESCRIPTION.md"
      provides: "App description for YNH catalog"
      min_lines: 5
    - path: "doc/ADMIN.md"
      provides: "Admin documentation for YNH catalog"
      min_lines: 10
  key_links:
    - from: "manifest.toml"
      to: "conf/nginx.conf"
      via: "resources.apt sources that nginx depends on"
    - from: "conf/librechat.env"
      to: "conf/librechat.service"
      via: "EnvironmentFile directive references the env template"
    - from: "manifest.toml"
      to: "conf/*"
      via: "Standard YNH conf/ directory convention"
---

<objective>
Create the entire YunoHost package skeleton: manifest.toml, all configuration templates (nginx, systemd, env, yaml), documentation stubs, and lifecycle script stubs.

**Purpose:** Establish the file structure every YunoHost app needs before any logic can run. The manifest declares resources (Node.js, MongoDB, Meilisearch sources, apt deps, ports, system user), install questions (domain, admin email), and upstream metadata. Templates define how services wire together. Script stubs exist so YNH can find them.
**Output:** A valid YunoHost packaging v2 directory structure that `yunohost app install` can begin processing.
</objective>

<execution_context>
@~\.config\opencode/get-shit-done/workflows/execute-plan.md
@~\.config\opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-foundation-install/01-RESEARCH.md
</context>

<tasks>

<task type="auto">
  <name>task 1: Create manifest.toml with all resources, install questions, and sources</name>
  <files>manifest.toml</files>
  <action>
    Create `manifest.toml` at the project root following the YunoHost packaging v2 format. Must include:

    1. **Package metadata:**
       - `packaging_format = 2`
       - `id = "librechat"`, `name = "LibreChat"`
       - `description.en`: "Multi-provider LLM chat UI (OpenAI, Anthropic, Ollama, OpenRouter, ...)"
       - `version = "0.8.8-rc3~ynh1"`
       - maintainers list with placeholder username
       - `[upstream]` with license MIT, website, code URL

    2. **Integration section:**
       - `yunohost = ">= 12.1.40"`
       - `helpers_version = "2.1"`
       - `architectures = ["amd64", "arm64"]`
       - `multi_instance = true`
       - `ldap = false` and `sso = false` (locked decision from CONTEXT.md)
       - `disk = "50M"`, `ram.build = "2G"`, `ram.runtime = "500M"`

    3. **Install questions:**
       - `[install.domain]`: type = "domain" (standard YNH domain prompt)
       - `[install.admin_email]`: type = "text", ask.en = "Enter the admin email address for notifications", example = "admin@example.com", pattern_regexp for email validation
       - No other install questions. LLM API keys NOT prompted during install (per CONTEXT.md locked decision)

    4. **Resources section:**
       - `[resources.sources.main]`: GitHub tarball URL for v0.8.8-rc3, sha256 = "FILL_ME" placeholder (computed at build time), `in_subdir = true`, `autoupdate.strategy = "latest_github_tag"`
       - `[resources.sources.meilisearch]`: amd64.url and arm64.url pointing to Meilisearch v1.53.2 GitHub releases, sha256 values per RESEARCH.md, `format = "script"`, `extract = false`, `rename = "meilisearch"`, `autoupdate.strategy = "latest_github_release"` with asset patterns
       - `[resources.apt]`: packages = ["libvips42", "build-essential", "python3"]
       - `[resources.ports]`: main.default = 3080
       - `[resources.system_user]`: allow_email = true (needed for sending admin password email)
       - `[resources.install_dir]` (empty — uses default)
       - `[resources.permissions]`: main.url = "/", admin.allowed = "admins"
       - `[resources.nodejs]`: version = "24" (per RESEARCH — upstream .nvmrc is 24.16.0; use "24" not "22")

    **SHA256 placeholder:** Set `sha256 = "FILL_ME"` for main source. This is a computed-at-build-time value documented in the AUR workarounds.

    Use the exact manifest structure from RESEARCH.md as the authoritative template. Do NOT deviate from the verified Wekan-derived pattern.
  </action>
  <verify>node ~\.config\opencode/get-shit-done/bin/gsd-tools.cjs frontmatter validate "manifest.toml" --schema ynh-manifest 2&gt;&amp1 || echo "No YNH validator available — verify manually"</verify>
  <done>manifest.toml exists with all required sections: metadata, integration, install, resources, permissions. Node version is "24", Meilisearch sources are dual-arch, admin email install question exists, ldap/sso are false.</done>
</task>

<task type="auto">
  <name>task 2: Create all configuration templates (nginx, systemd x2, env, yaml)</name>
  <files>
    conf/nginx.conf
    conf/librechat.service
    conf/meilisearch.service
    conf/librechat.env
    conf/librechat.yaml
  </files>
  <action>
    Create exactly these 5 files in `conf/`:

    ### conf/nginx.conf
    - `location __PATH__/ {` block proxying to `http://127.0.0.1:__PORT__`
    - CRITICAL WebSocket headers: `proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade";`
    - CRITICAL SSE support: `proxy_buffering off; proxy_cache off;`
    - Standard proxy headers: Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto
    - `include proxy_params_no_auth;`
    - `client_max_body_size 100M;`
    - Use `__PATH__` and `__PORT__` template variables (not hardcoded values)
    - Add comment explaining why WebSocket/SSE headers are required (per Pitfall 4 / RESEARCH.md)

    ### conf/librechat.service
    - `Description=LibreChat: multi-provider LLM chat UI`
    - `Wants=mongod.service meilisearch.service`
    - `After=network.target mongod.service meilisearch.service`
    - `Type=simple`, `User=__APP__`, `Group=__APP__`
    - `EnvironmentFile=__INSTALL_DIR__/librechat.env`
    - `WorkingDirectory=__INSTALL_DIR__/`
    - `ExecStart=__NODEJS_DIR__/node api/server/index.js` (note: api/server/index.js — verify path; LibreChat's entry point may be different)
    - `Restart=on-failure`, `RestartSec=10`
    - Hardened sandboxing (Wekan pattern): NoNewPrivileges=yes, PrivateTmp=yes, PrivateDevices=yes, RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK, ProtectSystem=full, ProtectHome=yes, plus all CapabilityBoundingSet denials from RESEARCH.md
    - `WantedBy=multi-user.target`

    ### conf/meilisearch.service
    - `Description=Meilisearch search engine for __APP__`
    - `After=network.target`
    - `Type=simple`, `User=__APP__`, `Group=__APP__`
    - `ExecStart=/usr/bin/meilisearch --http-addr 127.0.0.1:7700 --master-key __MEILI_MASTER_KEY__ --db-path __DATA_DIR__/meilisearch --no-analytics=true`
    - `Restart=on-failure`
    - Basic hardening: NoNewPrivileges=yes, PrivateTmp=yes, ProtectSystem=full, ProtectHome=yes
    - `WantedBy=multi-user.target`

    ### conf/librechat.env
    - CRITICAL: Use __VAR__ template placeholders (YNH pattern — replaced by ynh_config_add)
    - HOST=localhost, PORT=__PORT__, DOMAIN_CLIENT=https://__DOMAIN__, DOMAIN_SERVER=https://__DOMAIN__, TRUST_PROXY=1
    - MONGO_URI=mongodb://__DB_USER__:__DB_PWD__@127.0.0.1:27017/__DB_NAME__
    - SEARCH=false (disabled by default), MEILI_HOST=http://127.0.0.1:7700, MEILI_MASTER_KEY=__MEILI_MASTER_KEY__, MEILI_NO_ANALYTICS=true
    - JWT_SECRET=__JWT_SECRET__, JWT_REFRESH_SECRET=__JWT_REFRESH_SECRET__
    - ADMIN_PANEL_SESSION_SECRET=__ADMIN_PANEL_SESSION_SECRET__
    - ALLOW_REGISTRATION=false (start closed)
    - DEBUG_LOGGING=true, LOG_TO_FILE=true
    - NODE_ENV=production

    ### conf/librechat.yaml
    - Comment header: "# LibreChat Provider Configuration\n# Add your API keys below. This file is preserved on upgrade."
    - `version: 1.1.1`
    - Commented-out endpoint blocks for: openAI, anthropic, ollama (with comment "Not needed for local Ollama"), openRouter
    - Each block has `apiKey` field with placeholder comment showing expected key location
    - OpenAI shows model default: ["gpt-4o", "gpt-4o-mini"]
    - Anthropic shows model default: ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"]
    - Registration customization section commented out: socialLogins, allowedDomains
  </action>
  <verify>Test-Path -LiteralPath "conf/nginx.conf"; Test-Path -LiteralPath "conf/librechat.service"; Test-Path -LiteralPath "conf/meilisearch.service"; Test-Path -LiteralPath "conf/librechat.env"; Test-Path -LiteralPath "conf/librechat.yaml"; Select-String -Path "conf/nginx.conf" -Pattern "proxy_set_header Upgrade" | Select-Object -First 1; Select-String -Path "conf/librechat.env" -Pattern "MONGO_URI" | Select-Object -First 1</verify>
  <done>All 5 config templates exist with correct content. nginx.conf has WebSocket + SSE headers. librechat.service has hardened sandboxing. librechat.env has all secret placeholders. librechat.yaml has all 4 provider blocks.</done>
</task>

<task type="auto">
  <name>task 3: Create doc/ stubs, script stubs, and .gitkeep</name>
  <files>
    doc/DESCRIPTION.md
    doc/ADMIN.md
    doc/screenshots/.gitkeep
    scripts/upgrade
    scripts/remove
    scripts/backup
    scripts/restore
  </files>
  <action>
    ### doc/DESCRIPTION.md
    Write a description explaining what LibreChat is (multi-provider LLM chat UI), what the YNH package provides (one-command install with MongoDB + Meilisearch), and link to upstream librechat.ai.

    ### doc/ADMIN.md
    Write admin documentation covering:
    - How to configure LLM providers after install (edit librechat.yaml)
    - How to find the admin password (install output + email)
    - How to manage users via LibreChat's web admin panel
    - Notes on MongoDB and Meilisearch management
    - Where to find logs (/var/log/librechat/)
    - How to enable search (set SEARCH=true and MEILI_MASTER_KEY in librechat.env)
    
    ### doc/screenshots/.gitkeep
    Empty placeholder file so the screenshots directory exists.

    ### scripts/upgrade, scripts/remove, scripts/backup, scripts/restore
    Each must be a valid bash script:
    - `#!/bin/bash` shebang
    - `# SOURCE COMMON` comment placeholder
    - `source /usr/share/yunohost/helpers`
    - `# AUTO-GENERATED STUB — implemented in Phase 2/3` comment
    - `ynh_script_progression "..."` placeholder message
    - `ynh_abort_if_errors`
    - Exit with `ynh_script_progression "done"` message

    Make each stub executable (chmod +x on unix, but on Windows just add proper shebang).
    The install script is NOT created here — it's the major task in Plan 02.
  </action>
  <verify>Test-Path -LiteralPath "doc/DESCRIPTION.md"; Test-Path -LiteralPath "doc/ADMIN.md"; Test-Path -LiteralPath "doc/screenshots/.gitkeep"; Test-Path -LiteralPath "scripts/upgrade"; Test-Path -LiteralPath "scripts/remove"; Test-Path -LiteralPath "scripts/backup"; Test-Path -LiteralPath "scripts/restore"; Select-String -Path "scripts/upgrade" -Pattern "#!/bin/bash" | Select-Object -First 1</verify>
  <done>All doc and script stub files exist. scripts/ are valid bash with shebang and ynh_script_progression calls.</done>
</task>

</tasks>

<verification>
1. `manifest.toml` validates as a complete YNH packaging v2 manifest
2. All 5 conf/ templates are well-formed with correct template variable syntax (__VAR__)
3. nginx.conf contains both WebSocket upgrade headers and proxy_buffering off
4. librechat.service references librechat.env as EnvironmentFile
5. librechat.yaml contains all 4 provider blocks (openAI, anthropic, ollama, openRouter)
6. All script stubs have shebang lines and basic ynh structure
7. doc/ files exist with meaningful content
</verification>

<success_criteria>
- [ ] `manifest.toml` exists with: 19 requirement IDs covered (SKEL-01 through SKEL-05, CONF-01 through CONF-04, INST-06, INST-07, INST-09)
- [ ] Package declares: Node 24 via [resources.nodejs], MongoDB via mongo_version global in _common.sh (next plan), Meilisearch via [resources.sources.meilisearch], apt deps (libvips42, build-essential, python3)
- [ ] nginx template has WebSocket upgrade headers and SSE buffering off
- [ ] Both systemd service templates exist (librechat.service with hardened sandboxing, meilisearch.service)
- [ ] librechat.env template with all secret placeholders present
- [ ] librechat.yaml template with all 4 provider blocks
- [ ] Admin email install question exists in manifest.toml
- [ ] Source tarballs pinned with sha256 (main placeholder, meilisearch computed)
- [ ] ldap=false, sso=false declared in [integration]
- [ ] Upgrade/remove/backup/restore script stubs exist
- [ ] doc/DESCRIPTION.md and doc/ADMIN.md exist
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation-install/01-foundation-install-01-SUMMARY.md`
</output>
