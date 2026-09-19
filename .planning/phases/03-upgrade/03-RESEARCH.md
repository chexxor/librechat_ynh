---
phase: 03-upgrade
date: 2026-09-18
method: inline research (prior-phase research + verified YNH v2 helpers knowledge)
---

# Phase 3 Research: Upgrade

## What already exists (from Phases 1–2)

- `librechat_build()` in `scripts/_common.sh` — npm ci + unrun workaround + turbo build + `.npm` cache strip (UPGR-01/UPGR-05 handled by reuse)
- Config written at install to `$install_dir/librechat.env` (chmod 600, all values from app settings) and `$install_dir/librechat.yaml` (user-editable provider config)
- Secrets persisted in app settings: `jwt_secret`, `jwt_refresh_secret`, `admin_panel_secret`, `meili_master_key`, `mongopwd`, `db_name`
- `mongo_version="7.0"` global in `_common.sh`; meilisearch binary at `/usr/bin/meilisearch` via `ynh_setup_source --source_id=meilisearch`
- data_dir resource: meilisearch index lives under `$data_dir/meilisearch` (`--db-path`), survives source replacement
- backup/restore complete and idempotent — upgrade does NOT need its own backup (YNH core does a safety backup automatically before `app upgrade`)

## Verified YNH v2 upgrade patterns

- `[Wekan upgrade script](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/upgrade)` — canonical pattern: `ynh_setup_source --dest_dir="$install_dir" --keep="<files>"` then rebuild, then regen services.
- `ynh_setup_source --keep="librechat.env librechat.yaml"` preserves those files when replacing the source tree (relative to dest_dir). `data_dir` is outside `$install_dir` so meili data is never touched.
- Std upgrade flow: setup source (keep configs) → idempotent DB provision (ynh_mongo_setup_db is safe for an existing db/user; read back `mongopwd`) → build → regen env/yaml (merge semantics) → nginx + systemd regen → restart meili then app.
- Never recreate admin user or regenerate secrets on upgrade (install-time only; values come back from settings).
- Manifest source bump on upgrade: update `[resources.sources.main] url/sha256` to new tag, bump `version = "X~ynhN+1"`; sha256 computable via `curl -sL url | sha256sum`.

## Config merge strategy (Phase 3 open concern — resolved here)

- **librechat.env**: template keys are all managed (secrets/port/db resolved from settings). Strategy: regenerate template to `$install_dir/librechat.env.new`, then merge: managed keys take the regenerated value; any KEY in the user's existing env that is NOT in the template is preserved verbatim (user-added keys appended). Never overwrite existing values. Result overwrites the old file atomically, re-chmod 600.
- **librechat.yaml**: user's API keys live here; values must never be overwritten. Strategy: preserve file verbatim. Template "new keys" are commented-out examples only (no active keys). Merge = append commented template sections whose top-level key (e.g. `endpoints:`, `registration:`) is absent from the user's file as an active top-level key. If yaml missing (bizarre state), regenerate full template.

## Pitfalls

1. Forgetting `--keep` → ynh_setup_source wipes `$install_dir` and deletes env/yaml (this is the #1 classic upgrade bug).
2. Regenerating `.env` wholesale → user-added keys vanish (the "never overwritten" test).
3. Creating a NEW admin user on upgrade → duplicate admin; must not re-run create-user.
4. `librechat_build` must run as app user via `ynh_exec_as_app` — already in `_common.sh`; do not duplicate.
5. Node version: manifest `[resources.nodejs]` = 24 matches upstream `.nvmrc` today; on tag bump verify .nvmrc still 24 (document, verified in plan 02).
6. Services must restart LAST (meili → app) after files are in final state; regen rules (nginx/systemd) before restart.

## Validation Architecture

| Requirement | Validation | Type |
|---|---|---|
| UPGR-01 rebuild from new source | `bash -n scripts/upgrade`; grep build call; live upgrade | auto + live |
| UPGR-02 config merge | bash dry merge test on fixture files; grep for `--keep` | auto + live |
| UPGR-03 mongo preserved | grep: no db drop, db_pwd read-back present; live chat history survives | auto + live |
| UPGR-04 meili preserved | data_dir untouched by source setup; live search still returns results | auto + live |
| UPGR-05 end-to-end | full `yunohost app upgrade librechat` | live (checkpoint) |
