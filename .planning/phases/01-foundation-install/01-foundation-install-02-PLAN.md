---
phase: 01-foundation-install
plan: 02
type: execute
wave: 2
depends_on:
  - 01-foundation-install-01
files_modified:
  - scripts/_common.sh
  - scripts/install
autonomous: false
requirements:
  - INST-01
  - INST-02
  - INST-03
  - INST-04
  - INST-05
  - INST-08
  - INST-10

must_haves:
  truths:
    - "Install script downloads LibreChat source from GitHub (pinned tag)"
    - "MongoDB is installed via ynh_install_mongo with namespaced database"
    - "Meilisearch binary is downloaded and installed to /usr/bin/"
    - "LibreChat npm build completes with AUR workarounds (allow-remote, unrun, cache strip)"
    - "nginx config is added via ynh_config_add_nginx"
    - "Both systemd services (librechat, meilisearch) are created and started"
    - "Admin user is created via LibreChat's create-user.js with random password"
    - "Admin email is sent with password details"
    - "Install output shows the admin password"
  artifacts:
    - path: "scripts/_common.sh"
      provides: "Shared helpers: librechat_build(), mongo_version, secrets generation"
      min_lines: 40
    - path: "scripts/install"
      provides: "Full install orchestration script"
      min_lines: 100
  key_links:
    - from: "scripts/install"
      to: "ynh_install_mongo"
      via: "MongoDB setup step"
    - from: "scripts/install"
      to: "conf/librechat.env"
      via: "ynh_config_add template=librechat.env"
    - from: "scripts/install"
      to: "conf/nginx.conf"
      via: "ynh_config_add_nginx"
    - from: "scripts/install"
      to: "conf/librechat.service"
      via: "ynh_config_add_systemd"
---

<objective>
Create the full install script (scripts/install) and shared helpers (scripts/_common.sh) that orchestrate: source download, MongoDB setup, Meilisearch binary install, LibreChat npm build (with AUR workarounds), config templating, nginx/systemd setup, admin user creation, and password email delivery.

**Purpose:** Make `yunohost app install librechat` work end-to-end. This is the highest-risk script — it coordinates build tools, databases, system services, and YNH helpers. Every other lifecycle script derives from the patterns established here.
**Output:** A working install that, after completion, serves a reachable LibreChat web UI behind HTTPS with admin login.
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
@.planning/phases/01-foundation-install/01-foundation-install-01-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>task 1: Create _common.sh with librechat_build() helper and shared variables</name>
  <files>scripts/_common.sh</files>
  <action>
    Create `scripts/_common.sh` following the patterns from RESEARCH.md:

    1. **Common variables:**
       - `mongo_version="7.0"` (start with 7.0 per research; Wekan uses 8.0 but we test 7.0 first)

    2. **`librechat_build()` function:**
       Must implement the exact order of operations from RESEARCH.md:
       - `pushd "$install_dir"`
       - `npm config set allow-remote true` (AUR workaround #1: xlsx CDN tarball blocked by npm)
       - `ynh_exec_as_app npm ci` (clean install from lockfile)
       - `ynh_exec_as_app npm install --no-save unrun` (AUR workaround #2: missing from npm ci resolution)
       - `ynh_exec_as_app npx turbo run build --no-daemon` (build with --no-daemon to prevent CI timeout)
       - `rm -rf "$install_dir/.npm"` (AUR workaround #3: strip npm cache bloat)
       - `popd`

       **Why these workarounds:** See RESEARCH.md "Build Workarounds" section. The xlsx CDN tarball is blocked by npm's default config; `unrun` is a transitive dep not in the lockfile; npm cache can grow to 500MB+.

    3. **`librechat_generate_secrets()` function:**
       Generates and stores all secrets using `ynh_string_random`:
       - `jwt_secret=$(ynh_string_random --length=64)`
       - `jwt_refresh_secret=$(ynh_string_random --length=64)`
       - `admin_panel_secret=$(ynh_string_random --length=64)`
       - `meili_master_key=$(ynh_string_random --length=32)`
       - `admin_password=$(ynh_string_random --length=24)` (24 chars per CONTEXT.md locked decision)
       - Store each via `ynh_app_setting_set`

    4. **`librechat_create_admin_user()` function:**
       - Arguments: `$admin_email`, `$admin_password`
       - `pushd "$install_dir"`
       - `ynh_exec_as_app node config/create-user.js "$admin_email" "Admin" "admin" "$admin_password" --email-verified=true`
       - `popd`
       - Must run AFTER MongoDB is set up (database must exist) but BEFORE LibreChat service starts

    5. **Source:** `source /usr/share/yunohost/helpers`
  </action>
  <verify>Test-Path -LiteralPath "scripts/_common.sh"; Select-String -Path "scripts/_common.sh" -Pattern "librechat_build" | Select-Object -First 1; Select-String -Path "scripts/_common.sh" -Pattern "allow-remote" | Select-Object -First 1; Select-String -Path "scripts/_common.sh" -Pattern "unrun" | Select-Object -First 1</verify>
  <done>_common.sh exists with librechat_build() containing all 3 AUR workarounds, librechat_generate_secrets() using ynh_string_random, and librechat_create_admin_user(). mongo_version="7.0" set.</done>
</task>

<task type="auto">
  <name>task 2: Create scripts/install with full install orchestration</name>
  <files>scripts/install</files>
  <action>
    Create `scripts/install` following the exact flow and patterns from RESEARCH.md "Full Install Script Pattern":

    1. **Header:** `#!/bin/bash`, `source _common.sh`, `source /usr/share/yunohost/helpers`, `ynh_abort_if_errors`

    2. **Step 1 — Install dependencies:**
       - `ynh_script_progression "Installing dependencies..."`
       - `ynh_install_mongo` (pulls MongoDB from upstream repo, version controlled by `$mongo_version`)
       - **Do NOT** manually install MongoDB apt repo — `ynh_install_mongo` handles everything (per "Don't Hand-Roll" guidance)

    3. **Step 2 — Set up source files:**
       - `ynh_script_progression "Setting up source files..."`
       - `ynh_setup_source --dest_dir="$install_dir"` (downloads LibreChat source from GitHub)
       - `ynh_setup_source --dest_dir="/usr/bin" --source_id="meilisearch"` (downloads Meilisearch binary)
       - `chmod +x /usr/bin/meilisearch`

    4. **Step 3 — Create MongoDB database:**
       - `db_name=$(ynh_sanitize_dbid --db_name=$app)`
       - `db_user=$db_name`
       - `ynh_app_setting_set --key=db_name --value=$db_name`
       - `ynh_mongo_setup_db --db_user=$db_user --db_name=$db_name`
       - `db_pwd=$(ynh_app_setting_get --key=mongopwd)` (read back the generated password for template)

    5. **Step 4 — Generate secrets:**
       - Call `librechat_generate_secrets()` from _common.sh

    6. **Step 5 — Build LibreChat:**
       - `ynh_script_progression "Building LibreChat..."`
       - Call `librechat_build()` from _common.sh

    7. **Step 6 — Add configuration files:**
       - `ynh_script_progression "Adding configuration files..."`
       - IMPORTANT: Before calling ynh_config_add, ensure ALL template variables are in shell scope:
         - `$jwt_secret`, `$jwt_refresh_secret`, `$admin_panel_secret` (from generate secrets step)
         - `$db_name`, `$db_user`, `$db_pwd` (from MongoDB step)
         - `$meili_master_key` (from generate secrets step)
       - `ynh_config_add --template="librechat.env" --destination="$install_dir/librechat.env"`
       - `ynh_config_add --template="librechat.yaml" --destination="$install_dir/librechat.yaml"`

    8. **Step 7 — Configure nginx:**
       - `ynh_script_progression "Configuring nginx..."`
       - `ynh_config_add_nginx`

    9. **Step 8 — Configure systemd:**
       - `ynh_script_progression "Configuring systemd services..."`
       - `ynh_config_add_systemd --template="librechat.service"`
       - `ynh_config_add_systemd --template="meilisearch.service" --service="meilisearch"`
       - `yunohost service add $app --description="LibreChat daemon" --log="/var/log/$app/$app.log"`
       - `yunohost service add meilisearch --description="Meilisearch search engine" --log="/var/log/meilisearch/meilisearch.log"`

    10. **Step 9 — Start services:**
        - `ynh_script_progression "Starting services..."`
        - `ynh_systemctl --service="meilisearch" --action="start"`
        - Wait briefly or use ynh_systemctl wait option, then:
        - `ynh_systemctl --service=$app --action="start"`

    11. **Step 10 — Create admin user:**
        - `ynh_script_progression "Creating admin user..."`
        - Call `librechat_create_admin_user "$admin_email" "$admin_password"` 
        - This runs AFTER MongoDB is set up and AFTER build is done. Uses direct MongoDB access, NOT the LibreChat service (so service state doesn't matter).

    12. **Step 11 — Send admin password email:**
        - `ynh_script_progression "Sending admin email..."`
        - Use `mail` command with message body containing:
          - Admin email address
          - Admin password
          - Login URL (https://$domain/)
          - Instructions: "After logging in, configure your LLM provider API keys in librechat.yaml"
        - Also `ynh_print_info "Admin password: $admin_password"` (shown at end of install output)
        - Password delivery is redundant: both screen output AND email (per CONTEXT.md locked decision)

    13. **Step 12 — Completion:**
        - `ynh_script_progression "Installation of $app completed"`

    **CRITICAL implementation notes:**
    - Use `__PORT__` template variable everywhere, NOT hardcoded 3080
    - Template variables (__FOO__) are only resolved if corresponding bash variable `$foo` is in scope at `ynh_config_add` call time
    - Never call `ynh_remove_mongo` anywhere
    - Use `ynh_exec_as_app` for npm commands, not bare npm (runs as $app user)
    - The `templates` parameter in `ynh_config_add` and `ynh_config_add_systemd` refers to the filename in `conf/` without path
  </action>
  <verify>Test-Path -LiteralPath "scripts/install"; Select-String -Path "scripts/install" -Pattern "ynh_install_mongo" | Select-Object -First 1; Select-String -Path "scripts/install" -Pattern "librechat_build" | Select-Object -First 1; Select-String -Path "scripts/install" -Pattern "create-user" | Select-Object -First 1; Select-String -Path "scripts/install" -Pattern "mail -s" | Select-Object -First 1</verify>
  <done>scripts/install exists with all 12 steps implementing the exact flow from RESEARCH.md. Has MongoDB setup, build with AUR workarounds, config templating, nginx/systemd config, admin user creation, and password email.</done>
</task>

</tasks>

<verification>
1. Script `scripts/_common.sh` has all 3 helper functions (librechat_build, librechat_generate_secrets, librechat_create_admin_user)
2. Script `scripts/install` has all 12 steps in correct order
3. librechat_build() contains all 3 AUR workarounds (allow-remote, unrun, .npm cleanup)
4. Install script calls ynh_install_mongo before MongoDB database setup
5. Admin password uses ynh_string_random --length=24 (per CONTEXT.md)
6. Password is BOTH printed via ynh_print_info AND emailed
7. No hardcoded port 3080 — uses __PORT__ template variable
8. Both systemd services are registered with yunohost service add
</verification>

<success_criteria>
- [ ] `scripts/_common.sh` exists with librechat_build(), librechat_generate_secrets(), librechat_create_admin_user()
- [ ] `scripts/install` exists with complete 12-step install flow
- [ ] ALL 3 AUR build workarounds applied in librechat_build()
- [ ] Install script deploys all services: MongoDB (ynh_install_mongo), Meilisearch (binary), nginx (ynh_config_add_nginx), systemd (ynh_config_add_systemd x2)
- [ ] Admin user created via LibreChat's create-user.js with random password
- [ ] Password delivered via both screen output (ynh_print_info) and email
- [ ] All template variables in scope before ynh_config_add calls
- [ ] Config templates rendered via ynh_config_add (not manually cp'd)
- [ ] npm cache stripped after build (rm -rf "$install_dir/.npm")
</success_criteria>

<output>
After completion, create `.planning/phases/01-foundation-install/01-foundation-install-02-SUMMARY.md`
</output>
