#!/bin/bash

#==============================================
# LibreChat YunoHost — common variables and helpers
# Sourced by every lifecycle script (install, upgrade, etc.)
#
# Source: /usr/share/yunohost/helpers is sourced by the calling scripts
# AFTER this file (helpers must exist for ynh_* functions used at call time).
#==============================================

#----------------------------------------------
# Common variables
#----------------------------------------------

# MongoDB version to install via ynh_install_mongo (helpers v2.1 uses
# the $mongo_version global instead of a --mongo_version flag).
mongo_version="7.0"

#----------------------------------------------
# Personal helper: build LibreChat from source
#
# Applies the three AUR-proven build workarounds (see research notes):
#   1. allow-remote=true  — the xlsx CDN tarball is blocked by npm's
#      default config; this permits remote fetch of that dependency.
#   2. unrun, --no-save   — a transitive dependency that npm ci does
#      not resolve from the lockfile; must be installed explicitly.
#   3. rm -rf .npm        — npm cache can grow to 500MB+ inside
#      install_dir; strip it after the build to save disk.
#----------------------------------------------
librechat_build() {
    pushd "$install_dir"

    # AUR workaround #1: allow npm to fetch the xlsx CDN tarball
    npm config set allow-remote true

    # Clean install from lockfile (runs as the $app system user)
    ynh_exec_as_app npm ci

    # AUR workaround #2: 'unrun' is missing from npm ci resolution
    ynh_exec_as_app npm install --no-save unrun

    # Build all workspaces (--no-daemon prevents turbo CI timeouts)
    ynh_exec_as_app npx turbo run build --no-daemon

    # AUR workaround #3: strip npm cache bloat from install_dir
    rm -rf "$install_dir/.npm"

    popd
}

#----------------------------------------------
# Personal helper: generate and store all secrets
#
# Uses ynh_string_random and persists each value via ynh_app_setting_set
# so that upgrade scripts can read them back. Populates shell variables:
#   jwt_secret, jwt_refresh_secret, admin_panel_secret,
#   meili_master_key, admin_password
#----------------------------------------------
librechat_generate_secrets() {
    jwt_secret=$(ynh_string_random --length=64)
    ynh_app_setting_set --key=jwt_secret --value="$jwt_secret"

    jwt_refresh_secret=$(ynh_string_random --length=64)
    ynh_app_setting_set --key=jwt_refresh_secret --value="$jwt_refresh_secret"

    admin_panel_secret=$(ynh_string_random --length=64)
    ynh_app_setting_set --key=admin_panel_secret --value="$admin_panel_secret"

    meili_master_key=$(ynh_string_random --length=32)
    ynh_app_setting_set --key=meili_master_key --value="$meili_master_key"

    # 24 chars per locked decision (CONTEXT.md)
    admin_password=$(ynh_string_random --length=24)
    ynh_app_setting_set --key=admin_password --value="$admin_password"
}

#----------------------------------------------
# Personal helper: create the initial admin user
#
# Arguments:
#   $1 — admin email
#   $2 — admin password
#
# IMPORTANT: must run AFTER MongoDB is set up (the database/user must
# exist, but direct MongoDB access is used — NOT the LibreChat HTTP
# service, so the service does not need to be running yet) and BEFORE
# the LibreChat service is handed to the user.
#----------------------------------------------
librechat_create_admin_user() {
    local admin_email="$1"
    local admin_password="$2"

    pushd "$install_dir"
    ynh_exec_as_app node config/create-user.js "$admin_email" "Admin" "admin" "$admin_password" --email-verified=true
    popd
}

#----------------------------------------------
# Personal helper: regenerate + merge config files (upgrade)
#
# Strategy (see phase 03 research):
#   - librechat.env: regenerate the managed template, then append any
#     user-added KEY=... lines from the old file whose key is absent
#     from the fresh template. Managed keys always take the fresh value
#     (fixes stale port/URI). Old file replaced atomically; chmod 600.
#   - librechat.yaml: NEVER overwrite user content. If present, keep it
#     verbatim and only append commented template sections for top-level
#     keys the user hasn't defined actively. If missing, full template.
#
# IMPORTANT: must be called with all template variables in bash scope:
#   $app, $install_dir, $port, $domain, $db_name, $db_user, $db_pwd
#   and all secrets (jwt_secret, jwt_refresh_secret,
#   admin_panel_secret, meili_master_key) — read back from settings
#   inside this helper.
#
# Do NOT re-run librechat_generate_secrets here (would rotate secrets
# and invalidate user sessions — upgrade never regenerates).
#----------------------------------------------
librechat_regen_and_merge_configs() {
    local librechat_env="$install_dir/librechat.env"
    local librechat_yaml="$install_dir/librechat.yaml"

    # 1. Read back persisted values FIRST
    db_pwd=$(ynh_app_setting_get --key=mongopwd)
    jwt_secret=$(ynh_app_setting_get --key=jwt_secret)
    jwt_refresh_secret=$(ynh_app_setting_get --key=jwt_refresh_secret)
    admin_panel_secret=$(ynh_app_setting_get --key=admin_panel_secret)
    meili_master_key=$(ynh_app_setting_get --key=meili_master_key)

    # Missing settings indicate a corrupted install — abort loudly.
    for setting_var in db_pwd jwt_secret jwt_refresh_secret admin_panel_secret meili_master_key; do
        if [ -z "${!setting_var}" ]; then
            ynh_die "App setting '$setting_var' is missing — cannot regenerate configs (corrupted install?)"
        fi
    done

    # 2. librechat.env: regenerate fresh template, merge user-added keys
    local env_new="$librechat_env.new"
    ynh_config_add --template="librechat.env" --destination="$env_new"

    if [ ! -s "$env_new" ]; then
        ynh_die "Failed to generate $librechat_env template — refusing to overwrite config with nothing"
    fi

    if [ -s "$librechat_env" ]; then
        # For every KEY in the old file absent from the fresh template,
        # append the old line verbatim (user-added keys preserved).
        while IFS= read -r line; do
            local key="${line%%=*}"
            [ -z "$key" ] && continue
            if ! grep -q "^${key}=" "$env_new"; then
                ynh_print_info "Preserving user-added env key: $key"
                printf '%s\n' "$line" >> "$env_new"
            fi
        done < <(grep -v '^\s*#' "$librechat_env" | grep -v '^\s*$')
    fi

    mv -f "$env_new" "$librechat_env"
    chown $app:$app "$librechat_env"
    chmod 600 "$librechat_env"

    # 3. librechat.yaml: preserve user file; append missing commented sections
    if [ -s "$librechat_yaml" ]; then
        ynh_print_info "librechat.yaml exists — preserving user configuration verbatim"

        local yaml_new="$install_dir/librechat.yaml.new"
        ynh_config_add --template="librechat.yaml" --destination="$yaml_new"

        if [ ! -s "$yaml_new" ]; then
            rm -f "$yaml_new"
            ynh_die "Failed to generate $librechat_yaml template — refusing to proceed"
        fi

        # Active (non-comment, non-empty) top-level keys in each file
        local user_keys template_keys
        user_keys=$(grep -v '^\s*#' "$librechat_yaml" | grep -v '^\s*$' | sed 's/^\([^# ]\{1,\}\):.*/\1/' | sort -u)
        template_keys=$(grep -v '^\s*#' "$yaml_new" | grep -v '^\s*$' | sed 's/^\([^# ]\{1,\}\):.*/\1/' | sort -u)

        local append=false
        local tkey
        while IFS= read -r tline; do
            # Top-level section start: non-indented, non-comment "key:" line
            if [[ "$tline" =~ ^[A-Za-z0-9_-]+: ]] && [[ "$tline" != \#* ]]; then
                tkey="${tline%%:*}"
                tkey="${tkey%%[[:space:]]*}"
                if printf '%s\n' $user_keys | grep -qx "$tkey"; then
                    append=false
                    continue
                else
                    append=true
                    ynh_print_info "Appending commented template section: $tkey"
                fi
            elif [[ "$tline" == \#* ]]; then
                # Comments only appended when inside an appended section
                [ "$append" = true ] || continue
            fi
            if [ "$append" = true ]; then
                printf '%s\n' "$tline" >> "$librechat_yaml"
            fi
        done < "$yaml_new"

        rm -f "$yaml_new"
        chown $app:$app "$librechat_yaml"
        chmod 644 "$librechat_yaml"
        ynh_print_info "librechat.yaml: appended commented template sections for missing keys only"
    else
        # Missing yaml (bizarre state) — regenerate full template
        ynh_config_add --template="librechat.yaml" --destination="$librechat_yaml"
        chown $app:$app "$librechat_yaml"
        chmod 644 "$librechat_yaml"
        ynh_print_info "librechat.yaml was missing — regenerated full template"
    fi

    ynh_print_info "Config regeneration/merge complete (managed env keys fresh; user keys preserved)"
}
