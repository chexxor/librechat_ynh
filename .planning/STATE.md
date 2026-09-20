# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-19)

**Core value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.
**Current focus:** Phase 5 — tests.toml + Local package_check Environment (v1.1 CI Validation)

## Current Position

Milestone: v1.1 CI Validation (phases 4-7)
Phase: 5 of 7 (tests.toml + Local package_check Environment)
**Current Plan:** Not started
**Total Plans in Phase:** 0
**Status:** Ready to plan
Last activity: 2026-09-20 — Completed 04-04-PLAN.md (Phase 4 lint baseline complete; LINT-01 closed)

**Progress:** [███░░░░░░░] 25%

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: Local Incus host availability — research flags WSL2 as NOT viable for Incus; confirm the user's Linux VM/VPS setup during Phase 5 planning (milestone's biggest logistical dependency).
- [Phase 6]: package_check is stricter than the live v1.0 install (subpath, private, reinstall, upgrade-from-commit paths never exercised) — expect unknown-scope findings.

## Session Continuity

**Last session:** 2026-09-20T02:30:00.000Z
**Stopped at:** Phase 4 complete (LINT-01 closed), ready to plan Phase 5
**Resume file:** None
