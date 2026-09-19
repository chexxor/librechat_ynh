# Milestones

## v1.0 LibreChat YunoHost Package (Shipped: 2026-09-19)

**Phases completed:** 3 phases, 7 plans
**Git range:** `116691c..29cb3a2` · 47 files changed, +5,664 lines · 2026-09-17 → 2026-09-19

**Key accomplishments:**
- Valid YNH packaging v2 manifest + full config templates (nginx WebSocket/SSE, systemd, env, yaml)
- One-command install: LibreChat source build with AUR workarounds, MongoDB 7.0 (namespaced), native Meilisearch binary, admin user, HTTPS
- Gap closure: pinned sha256 sources, sandbox-safe systemd units (ReadWritePaths), `multi_instance=false`
- Safe remove with MongoDB-namespaced teardown (shared-instance safe)
- Backup/restore: declare-then-dump `mongodump` + full-restore script; live round-trip verified
- Config-preserving upgrade (regen-and-merge helper); live `yunohost app upgrade` user-verified

**Known Gaps:** None — all 34 v1 requirements shipped (see milestones/v1.0-REQUIREMENTS.md).

---

