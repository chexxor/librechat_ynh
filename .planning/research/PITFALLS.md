# Domain Pitfalls

**Domain:** YunoHost native app package wrapping LibreChat (Node.js + MongoDB + Meilisearch)
**Researched:** 2026-09-18

## Critical Pitfalls

### Pitfall 1: AUR Package Build Issues (xlsx, unrun, npm cache)
**What goes wrong:** LibreChat's build fails because `xlsx` tries to download a CDN tarball that npm blocks; `unrun` package is missing from `npm ci` resolution; npm `.cache` directory bloats the app tree.
**Why it happens:** LibreChat uses workspaces with turbo; some transitive dependencies have unusual install behavior.
**Consequences:** Build fails on clean CI; 100MB+ of npm cache accumulates in `/var/www/librechat/`.
**Prevention:** 
- Set `npm config set allow-remote=true` before build (or add `--ignore-scripts` workaround for xlsx).
- Run `npm install --no-save unrun` before the frontend build step.
- Pass `--prefer-offline` or add a post-build cleanup step to strip `.cache/` directories.

### Pitfall 2: MongoDB Shared Instance Conflicts
**What goes wrong:** Multiple YNH apps sharing a MongoDB instance. If `ynh_remove_mongo` (not `ynh_mongo_remove_db`) is called, it removes the MongoDB service integration for ALL apps.
**Why it happens:** `ynh_remove_mongo` is a global MongoDB service removal, not app-scoped.
**Consequences:** Removing LibreChat would break other MongoDB-using apps (Wekan, MyDrive). 
**Prevention:** Use ONLY `ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name` in the remove script. NEVER call `ynh_remove_mongo`. This is the established pattern in Wekan's remove script.

### Pitfall 3: Config Overwrite on Upgrade
**What goes wrong:** `ynh_setup_source --dest_dir="$install_dir" --full_replace=1` replaces all files, including user-modified config (`.env`, `librechat.yaml`).
**Why it happens:** The `--full_replace` flag removes previous sources before extracting new ones.
**Consequences:** User loses API keys, custom config, and provider settings on every upgrade.
**Prevention:** Use `--keep="librechat.env librechat.yaml"` to preserve config files. Additionaly, implement a `librechat_upgrade_config()` helper that merges only new keys from the template into existing user files without overwriting.

### Pitfall 4: WebSocket/SSE Not Working Behind nginx
**What goes wrong:** LibreChat streaming responses appear broken (no output, connection hangs). Users see blank responses from LLM providers.
**Why it happens:** Default nginx config doesn't buffer SSE/handle WebSocket upgrade headers.
**Consequences:** Core feature (LLM chat) is completely non-functional.
**Prevention:** nginx config MUST include:
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_buffering off;
proxy_cache off;
```

### Pitfall 5: Node.js Native Module Build Failure (sharp/libvips)
**What goes wrong:** `npm ci` fails because `sharp` tries to download a prebuilt binary or compile from source, requiring `libvips`.
**Why it happens:** LibreChat uses `sharp` for image processing. Without `libvips` system package, the npm build fails.
**Consequences:** Complete build failure during install.
**Prevention:** Include `libvips42` in `[resources.apt] packages`. Also include `build-essential` for native module compilation as fallback.

## Moderate Pitfalls

### Pitfall 1: Node Version Mismatch
**What goes wrong:** LibreChat runs fine after install but crashes after an upstream release bumps minimum Node version.
**Why it happens:** LibreChat moves fast (Node 24 already in `.nvmrc`). YNH pinning can go stale.
**Prevention:** Bump `[resources.nodejs] version` during each package upgrade. Test against the LibreChat `.nvmrc`.

### Pitfall 2: Inconsistent Backup Without mongodump
**What goes wrong:** Backup captures raw MongoDB data files while the database is live, producing an inconsistent snapshot.
**Why it happens:** Raw file copy (`ynh_backup "$data_dir"`) doesn't account for in-flight writes.
**Consequences:** Restore produces a corrupt database.
**Prevention:** Use `ynh_mongo_dump_db --database=$app > ./dump.bson` during backup, not raw directory copy. This is the standard Wekan pattern.

### Pitfall 3: Meilisearch Binary Missing on Restore
**What goes wrong:** After restore, Meilisearch service fails because the binary is gone but the service unit expects it.
**Why it happens:** Meilisearch is installed from a downloaded source (not apt). The binary lives in `/usr/bin/` which is not included in backup.
**Consequences:** Search feature completely broken after restore.
**Prevention:** Re-download and install the Meilisearch binary during the restore script, before starting the service.

### Pitfall 4: npm Cache Bloat
**What goes wrong:** `.npm/_cacache/` can grow to 500MB+ inside the install directory.
**Why it happens:** npm caches every package during install. In YNH context, cached packages aren't reused across upgrades.
**Consequences:** Wastes disk space. Could cause restore to take excessive space.
**Prevention:** Add `rm -rf "$install_dir/.npm"` after successful build in install and upgrade scripts.

## Minor Pitfalls

### Pitfall 1: Service Fails to Start After Install (Port Conflict)
**What goes wrong:** The app port assigned by YNH (`$port`) conflicts with an existing service.
**Why it happens:** YNH port booking system usually handles this, but LibreChat also has default port config in its `.env`.
**Prevention:** Ensure the generated `.env` uses `$port` and LibreChat's config reads the PORT env var.

### Pitfall 2: Large Download Size for Source
**What goes wrong:** `ynh_setup_source` downloads the full LibreChat tarball (~30-50MB compressed) before showing progress.
**Why it happens:** The source tarball includes all dependencies, node_modules, and built artifacts if using a release tarball. Source tarballs from GitHub tags are smaller but still substantial.
**Prevention:** Use GitHub source tarballs (not release artifacts). Declare realistic `disk` and `ram.build` values in manifest.

### Pitfall 3: YNH CI Timeout on Build
**What goes wrong:** `package_check` CI times out because LibreChat's npm build takes >30 minutes on low-powered hardware.
**Why it happens:** Turbo monorepo build + native module compilation is resource-intensive.
**Prevention:** Document expected build time. Consider declaring `ram.build = "2G"` in manifest. Use `--no-daemon` flag for turbo in CI.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Install (build) | AUR build issues (xlsx, unrun, npm cache) | Implement `librechat_build()` custom helper with workarounds |
| Install (MongoDB) | MongoDB repo unavailable for Bookworm | Pin compatible version; Wekan uses 8.0 successfully |
| nginx config | WebSocket/SSE silent failure | Include upgrade headers + buffering-off in template |
| Upgrade config | User config overwrite | Use `--keep` flag + merge helper, never clobber |
| Backup | Inconsistent MongoDB data | Always use `ynh_mongo_dump_db`, not raw copy |
| Remove | Breaking other Mongo apps | Only `ynh_mongo_remove_db`, never `ynh_remove_mongo` |
| Restore | Missing Meilisearch binary | Re-download binary during restore script |

## Sources

- [Wekan YunoHost Package (remove script)](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/remove) — HIGH confidence (verified pattern for namespaced mongo cleanup)
- [Wekan YunoHost Package (backup script)](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/backup) — HIGH confidence (verified mongodump pattern)
- [Wekan YunoHost Package (upgrade script)](https://raw.githubusercontent.com/YunoHost-Apps/wekan_ynh/master/scripts/upgrade) — HIGH confidence (verified config preservation with `--keep`)
- [AUR LibreChat Package (PKGBUILD)](https://aur.archlinux.org/packages/librechat) — MEDIUM confidence (documented xlsx, unrun, npm cache issues)
- [LibreChat package.json](https://raw.githubusercontent.com/danny-avila/LibreChat/main/package.json) — HIGH confidence (confirms npm + turbo build)

---
*Pitfalls research for: LibreChat YunoHost Package*
*Researched: 2026-09-18*
