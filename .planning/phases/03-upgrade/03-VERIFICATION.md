---
phase: 03-upgrade
verified: 2026-09-18T23:00:00Z
status: passed
score: 6/6 must-haves verified
---

# Phase 3: Upgrade — Verification Report

**Phase Goal:** `yunohost app upgrade librechat` rebuilds LibreChat from updated source, preserves all user configuration and data, and leaves a working app.
**Verified:** 2026-09-18
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `yunohost app upgrade librechat` rebuilds from new source tag and restarts services without manual intervention | ✓ VERIFIED | `scripts/upgrade` line 38: `ynh_setup_source --dest_dir="$install_dir"` (manifest source); line 66 `librechat_build`; lines 100–102 restart meilisearch then $app. User-confirmed live run (checkpoint "approved"). |
| 2 | User-customized `librechat.env` and `librechat.yaml` preserved verbatim; new keys merged in, existing values never overwritten | ✓ VERIFIED | `scripts/upgrade` line 38: `--keep="librechat.env librechat.yaml"`; `_common.sh` lines 119–215 (`librechat_regen_and_merge_configs`): env regenerated fresh + user-added keys appended verbatim (lines 145–156), yaml never overwritten — only commented template sections for missing active top-level keys appended (lines 163–205). Secrets read back from settings, never regenerated (lines 124–135). |
| 3 | MongoDB data and Meilisearch search indexes survive upgrade intact | ✓ VERIFIED | No db drop anywhere in `scripts/upgrade`; line 54 `ynh_mongo_setup_db` (creates-if-missing); meili binary only re-downloaded to `/usr/bin` (line 27), data dir untouched (comment lines 25–26). Live: chat data/search confirmed by user checkpoint. |
| 4 | Upgrade completes without npm `.cache` bloat in the app tree | ✓ VERIFIED | `librechat_build` in `_common.sh` retains `rm -rf .npm` cache strip (line 27 comment, function lines 30+); called at `scripts/upgrade:66`. Live check confirmed `.npm` absent. |

**Score:** 4/4 phase success criteria verified + 2/2 plan-level must-haves

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/upgrade` | Full upgrade orchestration | ✓ VERIFIED | 107 lines; contains `--keep="librechat.env librechat.yaml"`, `librechat_build`, `ynh_app_setting_get --key=mongopwd`; no `librechat_create_admin_user` / `librechat_generate_secrets` / mail calls |
| `scripts/_common.sh` | `librechat_regen_and_merge_configs` helper | ✓ VERIFIED | Defined at line 119, substantive (97 lines): settings read-back + ynh_die guards, env merge, yaml append-merge, chown/chmod finalization |
| `manifest.toml` | Pinned source tag + sha256, version bump | ✓ VERIFIED | `version = "0.8.8-rc3~ynh2"` (line 7), url pinned to v0.8.8-rc3 tarball with sha256 `691cfe63…` (lines 41–42), nodejs 24 = upstream .nvmrc (line 76). Re-pinned same tag/fallback per plan — bump flow validated (~ynh1→~ynh2). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scripts/upgrade` | `scripts/_common.sh` | `source _common.sh` + `librechat_build` + `librechat_regen_and_merge_configs` | WIRED | Source at line 12; both helpers called at lines 66, 75 |
| `scripts/upgrade` | settings | `ynh_app_setting_get --key=mongopwd` | WIRED | Line 57 (upgrade scope) + line 124 in merge helper |
| `manifest.toml [resources.sources.main]` | `scripts/upgrade` | `ynh_setup_source` | WIRED | setup_source consumes manifest source; version bump triggers YNH upgrade path |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| UPGR-01 | 03-01 | Script rebuilds LibreChat from updated source | ✓ SATISFIED | `ynh_setup_source` + `librechat_build` in `scripts/upgrade`; live run |
| UPGR-02 | 03-01 | User config preserved via merge (never overwritten) | ✓ SATISFIED | `--keep` + regen_and_merge helper; live: env user keys + yaml intact |
| UPGR-03 | 03-01 | MongoDB data preserved | ✓ SATISFIED | Idempotent setup_db, no drop; live: chat history survived |
| UPGR-04 | 03-01 | Meilisearch data preserved | ✓ SATISFIED | Data dir untouched by script; live check |
| UPGR-05 | 03-02 | `yunohost app upgrade librechat` completes without loss | ✓ SATISFIED (user-verified) | Live checkpoint "approved" on YunoHost test server |

All 5 phase requirement IDs accounted for — no orphans (REQUIREMENTS.md maps exactly UPGR-01..05 to Phase 3).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TODO/FIXME/placeholder/stub patterns in scripts/ or manifest | — | — |

### Human Verification Required

None outstanding. UPGR-05 live upgrade was verified by the user ("approved") on the live YunoHost test server: upgrade completed, user env keys preserved, JWT secrets not rotated, yaml not clobbered, MongoDB chat data intact, `.npm` cache absent, UI reachable.

### Gaps Summary

No gaps. All must-haves verified statically (scripts/upgrade, _common.sh, manifest.toml) and the end-to-end upgrade was user-verified live.

---

_Verified: 2026-09-18_
_Verifier: OpenCode (gsd-verifier)_
