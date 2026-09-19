# Phase 2: Remove + Backup/Restore - Research

**Researched:** 2026-09-18
**Domain:** YunoHost packaging v2 lifecycle scripts (remove, backup, restore) for a Node.js + MongoDB + Meilisearch app
**Confidence:** HIGH

## Summary

Phase 2 fills in the three stub scripts (`scripts/remove`, `scripts/backup`, `scripts/restore`) that Phase 1 committed as placeholders. All required bash helpers exist in YunoHost helpers v2.1 and were verified against the auto-generated helpers documentation (YunoHost 12.1.41.1, doc generated 2026-09-03): `ynh_mongo_remove_db`, `ynh_mongo_dump_db`, `ynh_mongo_restore_db`, `ynh_backup`, `ynh_restore`, `ynh_restore_everything`, `ynh_config_remove_systemd`, `ynh_config_remove_nginx`, `ynh_nodejs_remove`, and `ynh_nodejs_install`. The Wekan_ynh package (MongoDB + Node, single-instance-per-mongo share) remains the canonical reference implementation and its remove/backup/restore scripts were fetched and verified line-by-line; patterns map 1:1 to this package.

There are two design decisions the planner must make, both resolvable from research: (1) **restore source strategy** — recommend restoring `$install_dir` from the backup archive (Wekan pattern) rather than re-downloading + re-building LibreChat, which makes restore fast and deterministic at the cost of a large archive; and (2) **meilisearch unit on restore** — recommend regenerating from the `conf/meilisearch.service` template (fresh `__MEILI_MASTER_KEY__` injection) rather than restoring the unit file from the archive.

One **latent Phase 1 issue surfaces directly in Phase 2 scope**: `manifest.toml` does not declare `[resources.data_dir]`, yet both systemd templates reference `__DATA_DIR__` (meilisearch `--db-path __DATA_DIR__/meilisearch`, `ReadWritePaths=__DATA_DIR__`). In packaging v2, `$data_dir`/`__DATA_DIR__` only exists as a core concept if `[resources.data_dir]` is declared. This must be resolved (one-line manifest fix) because it determines where the Meilisearch data lives and thus what backup covers. Phase 1 verification survived static checks, but this has never been validated live and could be a silent install bug.

**Primary recommendation:** Fill the three stubs following the Wekan pattern exactly (mongo helpers, `../settings/scripts/_common.sh` sourcing for backup/restore), fix the `[resources.data_dir]` manifest gap first, stop both services before dumping/removing, and always `ynh_mongo_remove_db` / never `ynh_remove_mongo`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RMV-01 | Stop and disable systemd services | `ynh_systemctl --action=stop` for both services; `ynh_config_remove_systemd` (removes + stops unit); `yunohost service remove $app` and `meilisearch` (Wekan remove, verified) |
| RMV-02 | Remove namespaced MongoDB DB only | `ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name` (helpers v2.1, verified). NEVER `ynh_remove_mongo` — it removes the global MongoDB service integration for all apps |
| RMV-03 | Remove Meilisearch binary and data | `rm /usr/bin/meilisearch` (installed by our package, single-instance confirmed); `ynh_safe_rm "$data_dir/meilisearch"` |
| RMV-04 | Remove app data dir and nginx config | `ynh_config_remove_nginx`; `ynh_safe_rm "$install_dir"`; `ynh_nodejs_remove` (ref-counted by helper — only removes if no other app uses Node 24) |
| RMV-05 | Remove breaks no other YunoHost apps | Guaranteed by RMV-02 (no `ynh_remove_mongo`), `ynh_nodejs_remove` ref-counting, and nginx/systemd removal being `$app`-scoped |
| BACK-01 | Consistent MongoDB dump | `ynh_mongo_dump_db --database=$db_name > ./dump.bson` (cwd of backup script = the archive staging dir; Wekan-verified). Stop app+meili first to quiesce writes |
| BACK-02 | Backup includes config, data, meili data | `ynh_backup "$install_dir"` (contains librechat.env/yaml), `ynh_backup "$data_dir"` (meili index), `ynh_backup` nginx conf. Do NOT backup `/usr/bin/meilisearch` — re-download in restore |
| BACK-03 | Restore re-downloads meili binary, `ynh_mongo_restore_db` | `ynh_setup_source --dest_dir=/usr/bin --source_id=meilisearch` + `chmod +x`; `ynh_mongo_restore_db --database=$db_name < ./dump.bson` (verified signatures) |
| BACK-04 | Restore restores config, nginx, service state | `ynh_restore_everything`; regenerate both systemd units from templates; `yunohost service add` x2; `ynh_config_add` for env/yaml if regenerating instead of archive restore |
| BACK-05 | Restore returns working app | Start order meili → app (same as install Step 9); `ynh_systemctl --service=nginx --action=reload`; settings (secrets, mongopwd, db_name) are restored automatically by YNH core from the app settings dump — restore script reads them back with `ynh_app_setting_get` |
</phase_requirements>

## User Constraints (carried from Phase 1 / STATE.md — no phase-2 CONTEXT.md exists)

No `02-*-CONTEXT.md` exists for this phase (no user discussion was held for Phase 2). Locked decisions that carry over from Phase 1 and constrain Phase 2:

- **multi_instance = false** for v1 (manifest) — single Meilisearch wiring. Backup/restore may assume exactly one install named `librechat` (and thus one meilisearch service with that status), but scripts must still be generic `$app`-based wherever cheap.
- **mongo_version = "7.0"** global in `_common.sh; admin password / secrets persist in app settings; `db_pwd` read back from `mongopwd` setting.
- **No user-level discussion for Phase 2** — OpenCode has discretion on the two restore-strategy decisions flagged below (both have clear best-practice recommendations from the Wekan reference).

## Standard Stack

### Core (YunoHost helpers v2.1 — all existence+signatures verified against official docs)

| Helper | Signature | Purpose | Source |
|--------|-----------|---------|--------|
| `ynh_mongo_remove_db` | `--db_user= --db_name=` | Remove the app's namespaced DB + user. THE ONLY mongo removal helper allowed | helpers v2.1 doc |
| `ynh_mongo_remove_db` vs `ynh_remove_mongo` | `ynh_remove_mongo` removes the **global** MongoDB service integration → breaks other apps | Forbidden in remove script | helpers v2.1 doc |
| `ynh_mongo_dump_db` | `--database=`, emits mongodump to stdout | Consistent logical MongoDB backup | helpers v2.1 doc (`ynh_mongo_dump_db --database=wekan > ./dump.bson`) |
| `ynh_mongo_restore_db` | `--database=`, reads dump from stdin | Restore from dump | helpers v2.1 doc (`ynh_mongo_restore_db --database=wekan < ./dump.bson`) |
| `ynh_mongo_database_exists` | `--database=`, exit 1 if missing | Restore guard (skip/short-circuit if DB already exists) | helpers v2.1 doc |
| `ynh_install_mongo` | no args; version from `$mongo_version` global | Re-provision MongoDB server in restore if absent (idempotent) | helpers v2.1 doc |
| `ynh_backup` | `ynh_backup /path` | **Declares** a path to backup (does NOT copy — YNH core collects afterwards). NB: child paths of `$data_dir` are is not auto-excluded from full backups (only from safety-backup-before-upgrade and if `do_not_backup_data`=1) | helpers v2.1 doc |
| `ynh_restore` | `ynh_restore "/etc/nginx/conf.d/$domain.d/$app.conf"` | Restore a single declared path | helpers v2.1 doc |
| `ynh_restore_everything` | no args | Restore all declared paths from the archive | helpers v2.1 doc |
| `ynh_config_remove_systemd` | `[--service=]` ($app default) | Disable/stop-and-remove a unit | helpers v2.1 doc |
| `ynh_config_remove_nginx` | no args | Remove `/etc/nginx/conf.d/$domain.d/$app.conf` | helpers v2.1 doc |
| `ynh_nodejs_remove` | no args | Remove this app's Node version if no other app uses it (ref-counts across apps) | helpers v2.1 doc |
| `ynh_nodejs_install` | no args; version from `$nodejs_version` global | Re-provision Node in restore if missing | helpers v2.1 doc |
| `yunohost service remove`/`add` | CLI | Register/deregister service in YNH monitoring; needed for both `$app` and `meilisearch` | helpers v2.1 doc/Wekan |
| `ynh_safe_rm` | `ynh_safe_rm path` | Refuses disastrous rm targets — use for data/install dirs | helpers v2.1 doc |

### Reference implementation (verified live)

| Source | Role |
|--------|------|
| `YunoHost-Apps/wekan_ynh` `scripts/remove` | Canonical: service remove → remove systemd → remove nginx → `ynh_mongo_remove_db` (with `#ynh_remove_mongo` commented as a "do-not-call" marker) |
| `YunoHost-Apps/wekan_ynh` `scripts/backup` | Canonical: `ynh_backup "$install_dir"`, nginx conf, systemd unit, then `ynh_mongo_dump_db --database=$app > ./dump.bson`; sources `_common.sh` via `source ../settings/scripts/_common.sh` |
| `YunoHost-Apps/wekan_ynh` `scripts/restore` | Canonical: `ynh_restore "$install_dir"` → `ynh_install_mongo` + `ynh_mongo_restore_db < ./dump.bson` → restore nginx → restore unit + `systemctl enable` → `yunohost service add` → start → `nginx reload` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Restore `$install_dir` from archive (Wekan pattern) | Re-run `ynh_setup_source` + `librechat_build()` in restore | Rebuild in restore makes tiny backups but restore takes 10-30 min and can fail (build env changes); archive-restore is minutes and deterministic. **Choose archive-restore** — the build artifacts (`node_modules`, `dist/`) are reproducible but rebuilding on restore is pointless risk |
| Restore systemd unit from archive | Regenerate unit from `conf/*.service` template with `ynh_config_add_systemd` | Regeneration is preferred: templates stay single source of truth, `__MEILI_MASTER_KEY__`/`__DATA_DIR__` are re-injected from settings, no stale hardcoded values |
| Backup meili index files raw (`ynh_backup "$data_dir"`) | Also run a meili export | Raw copy of Meili's LMDB dir is acceptable when meilisearch is stopped (archive coherent because service is stopped first). Meilisearch docs recommend snapshot/dump for live backups — we sidestep by stopping the service. No extra machinery needed for MVP |

## Architecture Patterns

### Phase 2 files (all currently stubs)

```
scripts/
├── remove      # fill: stop/deregister/uninstall order below
├── backup      # fill: declare paths + mongo dump
├── restore     # fill: restore everything + re-provision deps
└── _common.sh  # add mongo restore/db helpers only if needed (probably unchanged)
```

### Pattern 1: Remove order (Wekan-verified, adapted for app+meilisearch)

```bash
# scripts/remove
#!/bin/bash
#=================================================
# REMOVE SERVICE INTEGRATION IN YUNOHOST
#=================================================

# Stop the services first so nothing writes during removal
ynh_systemctl --service=$app --action=stop || true
ynh_systemctl --service=meilisearch --action=stop || true

# Deregister from YNH service monitoring
if ynh_hide_warnings yunohost service status $app >/dev/null; then
    yunohost service remove $app
fi
if ynh_hide_warnings yunohost service status meilisearch >/dev/null; then
    yunohost service remove meilisearch
fi

# Remove systemd units (also stops/disables)
ynh_config_remove_systemd
ynh_config_remove_systemd --service=meilisearch

# Remove nginx config
ynh_config_remove_nginx

# Remove ONLY the namespaced Mongo db + user (RMV-02)
# NEVER call ynh_remove_mongo — it removes the shared MongoDB service integration
ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name

# Remove this app's Node install if no other app uses Node 24
ynh_nodejs_remove

# Remove meilisearch binary + log handling (our package owns /usr/bin/meilisearch)
rm -f /usr/bin/meilisearch

# NOTE: $install_dir / $data_dir are removed by the YunoHost core after the
# script returns (with --purge for data_dir). Do not rm them here unless
# using ynh_safe_rm for package-owned paths the core does not own.
```

**Source:** Wekan remove script (verified 2026-09-18) + helpers v2.1 doc.

### Pattern 2: Backup script (declare-then-dump)

```bash
# scripts/backup  — NOTE the special _common.sh path!
source ../settings/scripts/_common.sh
source /usr/share/yunohost/helpers

ynh_print_info "Declaring files to be backed up..."

ynh_backup "$install_dir"                                # build + librechat.env/yaml
ynh_backup "$data_dir"                                   # meilisearch index
ynh_backup "/etc/nginx/conf.d/$domain.d/$app.conf"
# systemd units intentionally NOT backed up — restore regenerates from conf/ templates

# Stop services so the dump + meili files are coherent
ynh_systemctl --service=$app --action=stop
ynh_systemctl --service=meilisearch --action=stop

ynh_print_info "Backing up the MongoDB database..."
ynh_mongo_dump_db --database=$db_name > ./dump.bson

# Restart services so backup is non-destructive? NO — YunoHost starts the
# app's services again after backup completes. Verify this assumption live:
# if backup leaves services stopped, add explicit starts after the dump.
```

**Source:** Wekan backup script (verified); helper behavior `ynh_backup` = "declares only" per official docs.

### Pattern 3: Restore script

```bash
# scripts/restore — also sources ../settings/scripts/_common.sh
source ../settings/scripts/_common.sh
source /usr/share/yunohost/helpers

# Read persisted settings (YNH core restores settings.json automatically)
db_name=$(ynh_app_setting_get --key=db_name)
db_user=$db_name

# MongoDB server (idempotent; mongo_version global from _common.sh)
ynh_install_mongo

# Restore all declared paths (install_dir, data_dir, nginx conf)
ynh_restore_everything

# Restore Mongo data
if ynh_mongo_database_exists --database=$db_name; then
    ynh_mongo_restore_db --database=$db_name < ./dump.bson
else
    ynh_mongo_restore_db --database=$db_name < ./dump.bson
fi

# Re-provision Node (idempotent if already installed)
nodejs_version="24"    # or read from settings if Phase 1 stored it
ynh_nodejs_install

# Re-download meilisearch binary (NOT in the backup archive)
ynh_setup_source --dest_dir=/usr/bin --source_id=meilisearch
chmod +x /usr/bin/meilisearch

# Regenerate systemd units from templates (fresh secret/path injection)
ynh_config_add_systemd --template="librechat.service"
ynh_config_add_systemd --template="meilisearch.service" --service="meilisearch"
systemctl daemon-reload

# Deregister/re-register in YNH monitoring
yunohost service add $app --description="LibreChat daemon" --log="/var/log/$app/$app.log"
yunohost service add meilisearch --description="Meilisearch search engine" --log="/var/log/meilisearch/meilisearch.log"

# Start: meili first (mirrors install Step 9)
ynh_systemctl --service=meilisearch --action=start
ynh_systemctl --service=$app --action=start
ynh_systemctl --service=nginx --action=reload
```

**Source:** Wekan restore script (verified 2026-09-18) + helpers v2.1 docs.

### Anti-Patterns to Avoid

- **`ynh_remove_mongo` in remove** — removes global MongoDB service integration; breaks every other Mongo app on the server. Only `ynh_mongo_remove_db`. (Wekan even leaves a commented `#ynh_remove_mongo` showing the forbidden call.)
- **Raw `ynh_backup` of MongoDB data files** — data files copied live are inconsistent; corrupted restore. Use `ynh_mongo_dump_db`.
- **Backing up `/usr/bin/meilisearch`** — binaries installed under `/usr/bin` (`/usr/local`, etc.) aren't app-scoped and the archive path mapping for system binaries is fragile. Re-download in restore via `ynh_setup_source --source_id=meilisearch` (manifest carries per-arch URLs + sha256 already).
- **Trusting live-file backup of Meili LMDB while running** — LMDB mmap-of-files copied mid-write can corrupt. Stop meilisearch before `ynh_backup "$data_dir"`.
- **Forgetting `../settings/scripts/` source path** — in backup and restore, the script's cwd context differs from install; `_common.sh` is at `../settings/scripts/_common.sh`, not `scripts/_common.sh`. Wekan's backup/restore show this explicitly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MongoDB backup/restore/remove | Custom `mongodump`/`mongo shell` calls with hand-computed creds | `ynh_mongo_dump_db` / `ynh_mongo_restore_db` / `ynh_mongo_remove_db` | Helpers embed correct auth (mongopwd from app settings), escape db names, and handle version nuances |
| "Which files to back up" CSV/cache | Custom tar command | `ynh_backup` declaration pattern | The YNH core handles path mapping, exclusion, archive storage; raw tars break restore |
| Removing Node version safely | `rm -rf` on `$nodejs_dir` | `ynh_nodejs_remove` | Ref-counts Node versions across all YNH apps; removing on shared version would break others |
| Refusing dangerous rm targets | Bare `rm -rf` | `ynh_safe_rm` | Guards against wiping `/var`, `/home`, etc. on script bugs |
| Meilisearch binary re-download | curl + checksum spot-check | `ynh_setup_source --source_id=meilisearch` | Uses manifest per-arch URL+sha256, exactly like install Step 2 — zero code duplication |

**Key insight:** Every destructive phase-2 action maps to an existing v2.1 helper whose semantics were verified against the current (2026-09-03 generated) documentation. Hand-rolling any of them is strictly worse.

## Common Pitfalls

### Pitfall 1: `__DATA_DIR__` declared nowhere (latent Phase 1 gap — surfaces HERE)
**What goes wrong:** `manifest.toml` has no `[resources.data_dir]`, but `conf/meilisearch.service` and `conf/librechat.service` use `__DATA_DIR__`. In packaging v2, `$data_dir` is only a core-managed location if the resource is declared; the template substitution may render empty or the dir may never be created/chowned.
**Why it happens:** The Phase 1 gap was fixed for ReadWritePaths but the manifest declaration was never added; no live install has yet proven the substitution works.
**How to avoid:** Phase 2's first task should add `[resources.data_dir]` to `manifest.toml` (or confirm liv that the YNH core injects `__DATA_DIR__` anyway), then verify meili's db-path actually exists after install. This also fixes where backup must point (`$data_dir/meilisearch`).
**Warning signs:** meilisearch.service crashlooping with "db-path does not exist"; empty `__DATA_DIR__` string in the rendered unit file.

### Pitfall 2: Backup script cwd magic (`./dump.bson`)
**What goes wrong:** `ynh_mongo_dump_db --database=$db_name > ./dump.bson` appears to write to a random cwd; YNH core actually sets the backup script cwd to the archive staging dir and sweeps it into the archive.
**Why it happens:** Undocumented-but-standard pattern; works because cwd is managed by core.
**How to avoid:** Keep the exact Wekan form (`> ./dump.bson` at cwd, no absolute path). If testing manually outside YNH, the file lands wherever you run from — don't "fix" this by redirecting to a fixed path.
**Warning signs:** dump.bson not present in the archive contents (`yunohost backup list --archive file`).

### Pitfall 3: Services left stopped after backup
**What goes wrong:** Wekan's backup stops nothing (it dumps while live — fine for mongodump) but if we stop both services for coherence, YNH core may not restart them; the app stays down after backup.
**How to avoid:** Either (a) follow Wekan exactly and dump while running (mongodump gives a consistent snapshot even on a live db by design), or (b) stop-meili-first + explicitly re-start both services at the end of the backup script. Recommended: **(b)**, because LibreChat's MongoDB writes are small and infrequent and we want the meili files to be consistent too — but must include the explicit restarts.
**Warning signs:** App unreachable right after `yunohost app backup` completes.

### Pitfall 4: Restore fails if MongoDB/Node services not re-provisioned
**What goes wrong:** Restore runs on a machine where nothing is installed (or where the YNH core has torn packaging dirs down). Skipping `ynh_install_mongo`/`ynh_nodejs_install` leaves mongod.service or Node absent.
**How to avoid:** Both helpers are idempotent — always call them in restore, unconditionally.
**Warning signs:** `systemctl` "Unit mongod.service not found" after restore.

### Pitfall 5: Settings dependency in remove script
**What goes wrong:** `ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name` fails if `$db_user`/`$db_name` are undefined. On remove, YNH core restores the settings into scope automatically (v2 behavior) — but `$db_user` was never separately stored; the code in install computes `db_user=$db_name`.
**How to avoid:** In remove: `db_name=$(ynh_app_setting_get --key=db_name); db_user=$db_name` explicitly, with `ynh_app_setting_get` fallback sanity check + `ynh_die` if empty.
**Warning signs:** `ynh_mongo_remove_db` failing with empty `--db_user=`.

### Pitfall 6: Removing `/usr/bin/meilisearch` unconditionally
**What goes wrong:** Some other (non-multi-instance-wired for us, but system-wide) tooling could reference `/usr/bin/meilisearch`. Guard: only remove if we own it — for v1 the file only exists if this app installed it, and with `multi_instance=false` there is at most one. Simple ownership check via systemd unit existence or just `rm -f`. Acceptable to `rm -f`, but log the action.
**How to avoid:** `if [ -x /usr/bin/meilisearch ]; then rm -f /usr/bin/meilisearch; fi` — no error if missing (restore-after-remove-on-other-machine edge case).

### Pitfall 7: LibreChat will write during restore's mongorestore if services start early
**What goes wrong:** App or meilisearch starting before mongorestore finishes → new documents created on the empty db, then restore may conflict or merge unexpectedly.
**How to avoid:** Restore's service-start steps are last (Weaker pattern); never move them earlier. Do not rely on config-panel/etc.
**Warning signs:** duplicate user records after restore.

## Code Examples

### Exact DB cleanup in remove (credentials derived from app settings)
```bash
# Source: helpers v2.1 doc + Wekan scripts/remove
db_name=$(ynh_app_setting_get --key=db_name)
[ -n "$db_name" ] || ynh_die "Cannot find db_name app setting"
db_user=$db_name
ynh_mongo_remove_db --db_user=$db_user --db_name=$db_name
```

### MongoDB dump in backup
```bash
# Source: helpers v2.1 doc + Wekan scripts/backup
ynh_mongo_dump_db --database=$db_name > ./dump.bson
```

### MongoDB restore
```bash
# Source: helpers v2.1 doc + Wekan scripts/restore
ynh_install_mongo
ynh_mongo_restore_db --database=$db_name < ./dump.bson
```

### Meilisearch binary re-download in restore (mirrors install Step 2)
```bash
# Source: verified pattern from scripts/install, helper behavior identical in restore context
ynh_setup_source --dest_dir=/usr/bin --source_id="meilisearch"
chmod +x /usr/bin/meilisearch
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| v1 `ynh_mongo_setup_db --db_user x --db_name y --db_pwd z` + manual dump scripts | v2.1 helpers with `$mongo_version` global and settings-managed passwords | helpers v2.1 (YNH 11.1+) | Mongo helpers take globals; this package already conforms |
| Backup whole install dir (huge) | Same (Wekan still does it; no mainstream YNH app rebuilds during restore) | still current | Archive can be large; acceptable for MVP |

**Deprecated/outdated:** Wekan's restore shows `ynh_install_mongo --mongo_version=$mongo_version` (legacy flag form). Current v2.1 docs say `ynh_install_mongo` takes no args and reads `$mongo_version` global ours already sets — use the global form.

## Open Questions

1. **Does `__DATA_DIR__` resolve without `[resources.data_dir]` in manifest.toml?**
   - What we know: helpers v2.1 docs describe data_dir as tied to the resource; both units reference `__DATA_DIR__`; no live install has validated this.
   - Recommendation: Treat as the first Phase 2 task — declare `[resources.data_dir]` explicitly (idempotent even if core already handles it), and add a live verification step that meilisearch's db-path exists post-install. If it's confirmed harmless, the declaration cost is one line.

2. **Does YNH core restart app services after `yunohost app backup`?**
   - What we know: Wekan's backup stops nothing and dumps live. Our recommended variant stops services mid-backup.
   - Recommendation: If planner adopts stop-dump-restart, include explicit re-starts at the end of `scripts/backup`; mark live-test as human verification item. If planner prefers' Wekan-exact (dump live, meili files raw), drop the stop entirely but back up meili data live (risk of LMDB inconsistency — mitigate by mentioning in admin docs).
   - Recommended: **stop + restart with explicit starts** (coherence > non-transactional edge case).

3. **nodejs_version persistence**: `librechat_build()` reads `$nodejs_version` — it's set by YNH core from resources, not by us? On restore, this global may be empty if the resources step didn't re-provision.
   - Recommendation: Add `ynh_app_setting_set --key=nodejs_version --value="24"`? Actually — v2 helpers derive `$nodejs_version` from the `[resources.nodejs]` manifest section; the restore script runs within the app package context (manifest is available). MEDIUM confidence. Recommend: set `nodejs_version="24"` as a script-level fallback in `restore` before `ynh_nodejs_install`, mirroring the `mongo_version` pattern in `_common.sh`.
   - Confidence: LOW — needs live backup+restore test to confirm.

## Sources

### Primary (HIGH confidence)
- [YunoHost App helpers v2.1 documentation](https://yunohost.org/en/dev/packaging/scripts/helpers_v2.1) — fetched 2026-09-18; doc header says auto-generated 03/09/2026 on YunoHost 12.1.41.1. Verified all mongo helpers' exact signatures, `ynh_backup` semantics (declare-only; data_dir safety-backup exclusions), `ynh_restore`, `ynh_restore_everything`.
- [Wekan_ynh scripts/remove](https://github.com/YunoHost-Apps/wekan_ynh/blob/master/scripts/remove) — fetched 2026-09-18, exact copy reviewed. Confirms only `ynh_mongo_remove_db`, `ynh_config_remove_systemd`, `ynh_config_remove_nginx` order and the prohibited-`ynh_remove_mongo` marker.
- [Wekan_ynh scripts/backup](https://github.com/YunoHost-Apps/wekan_ynh/blob/master/scripts/backup) — fetched 2026-09-18. Confirms `../settings/scripts/_common.sh` sourcing, `ynh_backup` declaration list, `> ./dump.bson` redirect pattern.
- [Wekan_ynh scripts/restore](https://github.com/YunoHost-Apps/wekan_ynh/blob/master/scripts/restore) — fetched 2026-09-18. Confirms install_mongo → restore_everything → restore mongodump → restore configs → systemctl enable → `yunohost service add` → start → nginx reload.

### Secondary (MEDIUM confidence)
- [YunoHost packaging manifests documentation](https://yunohost.org/en/dev/packaging/manifest) (from project STACK.md, previously verified in Phase 1) — for `[resources.data_dir]` existence question, marked as needing planner confirmation.

### Tertiary (LOW confidence)
- Wekan restore's legacy `ynh_install_mongo --mongo_version=...` flag form (contradicts current v2.1 doc that takes no args) — use the global form documented in v2.1.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every helper signature verified against 2026-09-03-generated official docs; reference scripts fetched verbatim.
- Architecture: HIGH — patterns directly copied from verified references, adapted for app+meilisearch.
- Pitfalls: HIGH (documented pitfalls) / MEDIUM (specific gotchas like data_dir substitution, cwd magic — flagged as open questions for live verification).

**Research date:** 2026-09-18
**Valid until:** ~30 days (helpers v2.1 surface is stable; meilisearch version 1.53.2 pinned in manifest is unaffected by this phase)
