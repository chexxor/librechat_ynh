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
