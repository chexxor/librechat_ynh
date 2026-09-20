---
phase: 05-tests-toml-local-package-check-environment
plan: 01
subsystem: testing
tags: [yunohost, package_check, tests.toml, ci, toml, parser-validation]

# Dependency graph
requires:
  - phase: 04-lint-baseline
    provides: clean lint baseline so environmental package_check findings aren't confused with static ones
provides:
  - "tests.toml (test_format = 1.0) supplying args.admin_email, one test_upgrade_from.05e3d5b entry, and a [default.curl_tests] smoke-test"
  - "Archived parser deduction proving the auto-deduced default suite shape"
  - "Archived harness dry-run proving package_check accepts the file with no parser exception"
affects: [05-03-full-suite-run, phase-6-fix-findings, ghci-01-workflow]

# Tech tracking
tech-stack:
  added: [package_check, package_linter]
  patterns:
    - "tests.toml schema v1 (YunoHost packaging v2) as the contract package_check reads"
    - "Install args injected via [default].args.<question> when manifest has no default"
    - "Upgrade-from-previous-version pinned to a git ref via test_upgrade_from.<sha>.name"

key-files:
  created:
    - tests.toml
    - .planning/phases/05-tests-toml-local-package-check-environment/tests-deduction.json
    - .planning/phases/05-tests-toml-local-package-check-environment/tests-dryrun.txt
  modified: []

key-decisions:
  - "Use commit 05e3d5b (0.8.8-rc3~ynh2) as test_upgrade_from target, not 116691c (0.8.8-rc3~ynh1): the latter is a manifest-only skeleton with no scripts/ and is not installable"
  - "Supply args.admin_email in [default] because manifest's admin_email has no default; otherwise every install test aborts with 'Missing install arg admin_email ?'"
  - "No exclude block and no only = [...] on [default]: change_url is expected to fail at runtime (no scripts/change_url) and is a Phase 6 finding (POLS-02 deferred)"
  - "Harness dry-run needs the container backend on PATH even with -D; WSL2 cannot run Incus/LXD, so stubs were used only to satisfy the dependency assertion (documented deviation)"

patterns-established:
  - "Validate tests.toml in two stages: fast parser deduction (parse_tests_toml.py) then harness dry-run (package_check.sh -D)"
  - "Archive both validation outputs in the phase dir as the CI-01 acceptance record"

requirements-completed: [CI-01]

# Metrics
duration: 12min
completed: 2026-09-19
---

# Phase 5 Plan 1: tests.toml + parser/dry-run validation Summary

**Schema-valid `tests.toml` (test_format = 1.0) that package_check's parser accepts, deducing exactly `package_linter, install.root, backup_restore, upgrade, upgrade.05e3d5b, change_url` with `admin_email` supplied to every install test.**

## Performance

- **Duration:** ~12 min (this resumed session; Task 1 was completed in the prior run)
- **Started:** 2026-09-19T23:37:50Z (Task 1 commit time, prior run)
- **Completed:** 2026-09-19T23:48:43Z
- **Tasks:** 2
- **Files modified:** 3 created (tests.toml + 2 archived validation artifacts)

## Accomplishments
- Authored `tests.toml` at repo root with the `#:schema` v1 header, `test_format = 1.0`, `args.admin_email`, a single `test_upgrade_from.05e3d5b` entry, and one `[default.curl_tests]` block (`home.path="/"`, `expect_return_code=200`, `auto_test_assets=true`).
- Validated against `package_check`'s own parser: `parse_tests_toml.py` deduces exactly the research-corrected suite with no `install.subdir`/`install.private`/`install.multi`, and `admin_email=package_checker@example.com` supplied to all six suites.
- Ran the harness dry-run (`./package_check.sh -D`): exits 0, prints the full test JSON, and raises no `"'only' is not allowed on the default test suite"` exception.
- Archived both outputs in the phase directory as the CI-01 acceptance record.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author tests.toml per the locked contents and research corrections** - `a5ca363` (feat)
2. **Task 2: Validate tests.toml against package_check's parser and dry-run** - `3a5966d` (test)

**Plan metadata:** (pending - committed with docs: complete plan)

## Files Created/Modified
- `tests.toml` - package_check v1 test configuration: install args, upgrade-from ref, curl smoke-tests
- `.planning/phases/05-tests-toml-local-package-check-environment/tests-deduction.json` - parser deduction of the `default` suite (6 test IDs + install args)
- `.planning/phases/05-tests-toml-local-package-check-environment/tests-dryrun.txt` - `package_check.sh -D` output (6 canonical test JSON objects, exit 0)

## Decisions Made
- **Upgrade target is `05e3d5b`, not `116691c`.** RESEARCH correction applied: `0.8.8-rc3~ynh1` (116691c) is a manifest-only skeleton with no `scripts/`, so it is not installable; `0.8.8-rc3~ynh2` at commit `05e3d5b` is the correct installable ancestor.
- **`args.admin_email` must be supplied.** The manifest's `admin_email` has no default and is not auto-fillable, so it is set to `package_checker@example.com` in `[default]`.
- **No `exclude`, no `only = [...]` on `[default]`.** `change_url` is auto-generated even though `scripts/change_url` does not exist; it will fail at runtime and is a Phase 6 finding (POLS-02 deferred), not something to silence.
- **One `test_upgrade_from` entry** keyed by the lowercase hex SHA prefix `05e3d5b` (schema key pattern `^[a-z0-9_]*$`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Provided missing `jq`, `lynx`, `lxc`, and `lxd` so the harness dry-run could execute**
- **Found during:** Task 2 (harness dry-run)
- **Issue:** `package_check.sh -D` calls `assert_we_have_all_dependencies`, which requires `lynx`, `jq`, `python3`, `pip3`, and the container backend (`lxc`/`lxd` when no `incus` is present). None of `jq`, `lynx`, `lxc`, `lxd` were installed, and `sudo` requires a password (no non-interactive install). The dry-run aborted before reaching the JSON dump.
- **Fix:** Installed a real static `jq` 1.7.1 binary into `~/.local/bin`, and placed minimal stub executables for `lynx`, `lxc`, and `lxd` (only existence-checked by the dependency assertion; in `-D` mode the container operations are never reached because `run_all_tests` exits right after dumping the test JSON). Also pointed `python3` at the existing Python 3.12 venv (`/tmp/pl/.venv`) because the parser uses PEP 585 generics (`dict[str, str]`) unsupported by the system Python 3.8.
- **Files modified:** `~/.local/bin/jq` (WSL), `~/.local/bin/lynx` (stub), `~/.local/bin/lxc` (stub), `~/.local/bin/lxd` (stub). No repo files affected; `package_check` clone lives in `/tmp/package_check` (not committed).
- **Verification:** Dry-run then exited 0, printed all six test JSON objects, and contained no forbidden exception.
- **Committed in:** `3a5966d` (task 2 commit — artifacts only; environment fixes are outside the repo)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The environment fixes were necessary only because this is a WSL2 host where Incus/LXD are not viable (per 05-RESEARCH.md). They affect the harness's dependency gate, not the parser validation, which is the CI-01 acceptance criterion. No scope creep in repo content.

## Issues Encountered
- The system `python3` (3.8) cannot run `parse_tests_toml.py` (PEP 585 generics). Resolved by using the Python 3.12 venv that already had `toml` installed.
- `install.root` does not appear as a literal string in the dry-run output; the suite is represented canonically as `{ "test_type": "TEST_INSTALL", "test_arg": "root" }`. The plan's loose grep was adapted to assert on that JSON shape.
- `package_check.sh -D` requires the container backend binary to exist even though it performs no container work. Documented as a deviation; this is relevant input for the Phase 5 environment doc (05-02) and full-suite run (05-03).

## User Setup Required
None - no external service configuration required. (The local package_check environment is planned in 05-02/05-03.)

## Next Phase Readiness
- CI-01 deliverable complete: `tests.toml` is accepted by package_check's parser and the harness dry-run.
- Ready for 05-02 (host artifacts: `scripts/setup_pc_env.sh`, `doc/PACKAGE_CHECK.md`, ROADMAP/REQUIREMENTS wording amendment).
- Known, intentional non-blocker: `change_url` will fail at runtime (no `scripts/change_url`) — Phase 6 / POLS-02.

---
*Phase: 05-tests-toml-local-package-check-environment*
*Completed: 2026-09-19*

## Self-Check: PASSED

- FOUND: tests.toml
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/tests-deduction.json
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/tests-dryrun.txt
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/05-01-SUMMARY.md
- FOUND: commit a5ca363 (Task 1)
- FOUND: commit 3a5966d (Task 2)
