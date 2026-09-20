---
phase: 04-lint-baseline
plan: 02
subsystem: infra
tags: [yunohost, packaging-v2, manifest, lint, helpers, nodejs]

# Dependency graph
requires:
  - phase: 04-lint-baseline
    provides: linter runner (scripts/run_lint.sh) + baseline artifacts from Plan 01
provides:
  - schema-valid v2 manifest (nested pattern.regexp, format="whatever", init_main_permission)
  - scripts free of deprecated packaging-v2/v2.1 helpers
  - backup script free of ynh_script_progression
affects: [04-lint-baseline, 05, 06, 07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Manifest pattern regexp as nested TOML object ([install.X.pattern] regexp=...)"
    - "main permission chosen at install time via [install.init_main_permission] question"
    - "Deprecated-helper comments must NOT name the helper literally (linter greps for ynh_\\w+)"

key-files:
  created: []
  modified:
    - manifest.toml
    - scripts/install
    - scripts/remove
    - scripts/upgrade
    - scripts/backup
    - scripts/restore
    - .planning/phases/04-lint-baseline/lint-baseline.txt
    - .planning/phases/04-lint-baseline/lint-baseline.json

key-decisions:
  - "main permission warning resolved with [install.init_main_permission] group question (not allowed= on resources.permissions) — canonical example_ynh pattern"
  - "Node.js teardown/install left entirely to the v2 core [resources.nodejs] resource; no manual helper calls"
  - "Deprecated-helper explanatory comments must describe the helper, never spell its name — the linter's grep matches comments too"

patterns-established:
  - "Verification via WSL + /tmp/pl/.venv/bin/python (3.12) — system python3 is 3.8 and lacks tomllib"

requirements-completed: [LINT-01]

# Metrics
duration: 3min
completed: 2026-09-19
---

# Phase 4 Plan 2: Manifest + Deprecated Helper Fixes Summary

**Schema-valid v2 manifest (nested `pattern.regexp`, `format="whatever"`, `init_main_permission`) and scripts purged of deprecated v2/v2.1 helpers, verified by a full linter rerun**

## Performance

- **Duration:** 3 min
- **Started:** 2026-09-19T21:13:47Z
- **Completed:** 2026-09-19T21:16:46Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Fixed all 2 manifest schema violations: `pattern_regexp` → nested `[install.admin_email.pattern]` with `regexp` key; `meilisearch` source `format` `"script"` → `"whatever"`
- Resolved the `resource_consistency` main-permission warning via an `[install.init_main_permission]` group question
- Removed all 5 `ynh_abort_if_errors` calls, plus deprecated `ynh_nodejs_install` (restore) and `ynh_nodejs_remove` (remove) — Node is now fully core-managed via the `[resources.nodejs]` resource
- Replaced all 4 `ynh_script_progression` calls in `scripts/backup` with `ynh_print_info`
- Replaced the `your-username` maintainer placeholder with a GitHub-style handle + TODO comment
- Full linter rerun: `manifest`, `install`, `remove`, `upgrade`, `backup`, `restore` all report ✔ — every task-2 target warning is gone

## task Commits

Each task was committed atomically:

1. **task 1: Fix manifest schema violations, permissions warning, and maintainer placeholder** - `48a3614` (fix)
2. **task 2: Remove deprecated helpers and fix backup progression** - `571baa3` (fix)

**Plan metadata:** `435e607` (docs: complete plan)

## Files Created/Modified
- `manifest.toml` - nested pattern object, `format = "whatever"`, `init_main_permission` question, maintainer handle
- `scripts/install` - removed `ynh_abort_if_errors`
- `scripts/remove` - removed `ynh_abort_if_errors` + `ynh_nodejs_remove`; comment reworded to avoid the literal helper name
- `scripts/upgrade` - removed `ynh_abort_if_errors`
- `scripts/backup` - removed `ynh_abort_if_errors`; 4× `ynh_script_progression` → `ynh_print_info`
- `scripts/restore` - removed `ynh_abort_if_errors` + `ynh_nodejs_install`; dropped orphan `nodejs_version` var, added resource note
- `.planning/phases/04-lint-baseline/lint-baseline.{txt,json}` - refreshed after each task

## Decisions Made
- Used the `init_main_permission` install question rather than `allowed` on `resources.permissions.main` (canonical pattern; user chooses at install time).
- Removed the orphaned `nodejs_version="${nodejs_version:-24}"` assignment in restore since it existed only to feed the deprecated helper; the manifest resource supplies the version.
- Left remaining linter findings (catalog, tests.toml, change_url, README, systemd hardening, nginx headers) untouched — all documented as out-of-scope-by-design in 04-SCOPE-EXEMPTIONS.md.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Explanatory comment re-triggered the deprecated-helper warning**
- **Found during:** task 2 (Remove deprecated helpers and fix backup progression)
- **Issue:** The plan's suggested replacement comment in `scripts/remove` spelled the literal string `ynh_nodejs_remove`. The linter's `helpers_deprecated_in_v2p1` check runs `grep -IhEro 'ynh_\w+'` over the scripts — it matches the token in comments, not just live calls — so the warning persisted after the call was deleted.
- **Fix:** Reworded the comment to describe the deprecated helper without naming it ("Do NOT call the deprecated helpers-v2.1 nodejs removal helper").
- **Files modified:** scripts/remove
- **Verification:** Full linter rerun shows `scripts/remove` ✔ and the `ynh_nodejs_remove` warning absent.
- **Committed in:** 571baa3 (task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for correctness — the plan's literal comment text would have left the target warning unfixed. No scope creep.

## Issues Encountered
- PowerShell→WSL quoting kept mangling inline `python -c` / single-quoted grep one-liners; resolved by writing small temp scripts (`verify_manifest.py`, `verify_scripts.sh`, `grep_helpers.sh`) under the pre-approved temp dir and running those via `wsl -e bash`.

## User Setup Required

None - no external service configuration required. NOTE: `manifest.toml` carries a `# TODO: set to the real GitHub username` marker on `maintainers = ["alex-the-user"]` — must be replaced before catalog submission.

## Next Phase Readiness
- All locally-fixable Phase 4 findings are fixed; remaining linter output is exclusively the documented out-of-scope set.
- Ready for the remaining Phase 4 plans (baseline archival / zero-error confirmation).

---
*Phase: 04-lint-baseline*
*Completed: 2026-09-19*

## Self-Check: PASSED

- All modified files exist on disk: manifest.toml, scripts/{install,remove,upgrade,backup,restore}, 04-02-SUMMARY.md
- Task commits present in git history: `48a3614`, `571baa3`
