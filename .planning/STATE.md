# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-19)

**Core value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.
**Current focus:** Phase 5 — tests.toml + Local package_check Environment (v1.1 CI Validation)

## Current Position

Milestone: v1.1 CI Validation (phases 4-7)
Phase: 5 of 7 (tests.toml + Local package_check Environment)
**Current Plan:** 05-02 (05-01 complete)
**Total Plans in Phase:** 3
**Status:** In progress
Last activity: 2026-09-19 — Completed 05-01-PLAN.md (tests.toml authored and parser/dry-run validated; CI-01 closed)

**Progress:** [████░░░░░░] 40%

## Performance Metrics

**Velocity:**
- Total plans completed: 7 (v1.0)
- Average duration: n/a (not tracked)
- Total execution time: n/a

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| v1.0 (1-3) | 7 | 7 | - |
| v1.1 Phase 04 | 4 | 4 | ~2.3min |

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table. Recent for v1.1:

- [Research]: GH Actions = lint-only; full package_check on hosted runners is an anti-feature (Incus/btrfs requirements + OOM). Official YNH CI covers the full suite after catalog submission.
- [Research]: Phase order — linter first (zero infra), then tests.toml + local PC env, then fix-findings iteration, GH workflow last so it starts green.
- [Research]: `tests.toml` must supply `args.admin_email`; never use `exclude` to fake green CI.
- [Phase 04]: Zero-error invariant defined as (critical union error) minus exempted == empty; 5 out-of-scope findings documented in 04-SCOPE-EXEMPTIONS.md
- [Phase 04]: Main permission warning fixed via [install.init_main_permission] group question (canonical example_ynh pattern), not allowed= on resources.permissions
- [Phase 04]: nginx WS headers (proxy_http_version + Upgrade + Connection) deliberately retained over include proxy_params_no_auth; only the 4 plain Host/X-Real-IP/X-Forwarded-* headers removed
- [Phase 04]: README must contain readme_generator marker + dash.yunohost.org/integration/{id}.svg (literal linter greps), not arbitrary shields.io badges
- [Phase 04]: Canonical lint-baseline record is the lint-before-fix.*/lint-after-fix.* pair (text + JSON each); runner scratch lint-baseline.* left on disk but non-canonical
- [Phase 04]: Scope-adjusted zero-error accepted: post-fix JSON retains exactly 1 critical + 2 errors + 2 warnings, all documented exemptions in 04-SCOPE-EXEMPTIONS.md; LINT-01 closed
- [Phase 05]: tests.toml uses test_upgrade_from.05e3d5b (0.8.8-rc3~ynh2) not 116691c — the latter is manifest-only with no scripts/ and not installable
- [Phase 05]: args.admin_email supplied in [default]; no exclude block and no only=[...] on [default] — change_url expected to fail and is a Phase 6 finding (POLS-02 deferred)

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: Local Incus host availability — research flags WSL2 as NOT viable for Incus; confirm the user's Linux VM/VPS setup during Phase 5 planning (milestone's biggest logistical dependency).
- [Phase 6]: package_check is stricter than the live v1.0 install (subpath, private, reinstall, upgrade-from-commit paths never exercised) — expect unknown-scope findings.

## Session Continuity

**Last session:** 2026-09-20T04:19:35.679Z
**Stopped at:** Phase 5 context gathered
**Resume file:** .planning/phases/05-tests-toml-local-package-check-environment/05-CONTEXT.md
