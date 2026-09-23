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

## v1.1 CI Validation (Shipped: 2026-09-20)

**Phases completed:** 4 phases, 13 plans
**Git range:** 2026-09-19 → 2026-09-20

**Key accomplishments:**
- Phase 4: `package_linter` zero locally-fixable errors on the Windows dev box; 5 out-of-scope catalog items documented
- Phase 5: schema-valid `tests.toml` (CI-01) + reproducible Hyper-V Debian 12 VM/Incus/btrfs environment (CI-02)
- Phase 6: all install-blocking bugs fixed; single clean full-suite run archived as POLS-01 (exit 0, 4/4 in-scope SUCCESS); `change_url` + `upgrade.05e3d5b` exempt by design
- Phase 7: lint-only GitHub Actions workflow green (GHCI-01) — `package_linter` + shellcheck + TOML/schema on ubuntu-latest

**Known Gaps:** full `package_check` NOT in hosted CI (anti-feature, research-locked); `change_url` (POLS-02) and multi-instance (POLS-03) deferred to v2.

---

