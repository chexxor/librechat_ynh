---
phase: 04-lint-baseline
plan: 01
subsystem: infra
tags: [package_linter, wsl2, uv, python312, gitattributes, lint-baseline, yunohost]

# Dependency graph
requires: []
provides:
  - "scripts/run_lint.sh — deterministic WSL2 linter runner (uv/venv/text+JSON artifacts)"
  - ".gitattributes — LF pinning for scripts/text, binary marking for images"
  - "lint-baseline.txt / lint-baseline.json — archived before-fix baseline artifacts"
  - "04-SCOPE-EXEMPTIONS.md — auditable zero-error invariant with out-of-scope findings"
affects: [04-lint-baseline plans 02-04, phase-05-ci-validation, phase-06-package-check, phase-07-ci-workflow]

# Tech tracking
tech-stack:
  added: [uv, Python 3.12 (WSL2 venv), package_linter (main), WSL2 Ubuntu, .gitattributes LF policy]
  patterns: ["linter-as-test-suite: deterministic run + archived artifact + JSON assertion", "idempotent WSL2 provisioning in a committed bash wrapper"]

key-files:
  created:
    - scripts/run_lint.sh
    - .gitattributes
    - .planning/phases/04-lint-baseline/lint-baseline.txt
    - .planning/phases/04-lint-baseline/lint-baseline.json
    - .planning/phases/04-lint-baseline/04-SCOPE-EXEMPTIONS.md
  modified: []

key-decisions:
  - "Zero-error invariant defined as (critical ∪ error) \\ exempted == ∅, with 5 documented out-of-scope findings"
  - "Linter must run under WSL2 with POSIX /mnt/c path and uv-provisioned Python 3.12; /tmp/pl clone never committed"
  - "Baseline captured before any fix as the audit trail for the final zero-error claim"

patterns-established:
  - "Wave 0 wrapper pattern: one command (scripts/run_lint.sh) provisions tooling and writes both text and --json artifacts; later tasks verify by re-invoking it"
  - "Scope-exemption record pattern: every deliberately-unfixed finding has a reason and an unblocking change"
  - "LF pinning via .gitattributes to prevent CRLF drift under core.autocrlf=true"

requirements-completed: [LINT-01]

# Metrics
duration: 2min
completed: 2026-09-19
---

# Phase 4 Plan 01: Lint Baseline Scaffolding Summary

**Deterministic WSL2 linter runner (`scripts/run_lint.sh`) plus `.gitattributes` LF pinning, archived before-fix baseline artifacts, and an auditable scope-exemption record defining the zero-error invariant**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-09-19T21:10:59Z
- **Completed:** 2026-09-19T21:12:25Z
- **Tasks:** 3
- **Files modified:** 5 created (0 modified)

## Accomplishments
- Created `scripts/run_lint.sh` — a deterministic, idempotent WSL2 wrapper that provisions `uv`, Python 3.12, the linter clone, and its venv, then runs `package_linter` twice (text + `--json`) against the POSIX `/mnt/c/...` path with `PYTHONUTF8=1`.
- Captured the before-fix baseline: **1 critical, 2 errors, 9 warnings, 7 infos** — an exact match to the 04-RESEARCH.md empirical totals.
- Pinned LF line endings via `.gitattributes`; `git ls-files --eol scripts/` confirms all 7 script files are `i/lf w/lf` with no CRLF entries.
- Wrote `04-SCOPE-EXEMPTIONS.md` defining `zero_errors_assertion = (critical ∪ error) \ exempted == ∅` with all 5 out-of-scope findings documented and reasoned.
- Repo stays clean: the `/tmp/pl` clone and venv do not appear in `git status`.

## task Commits

Each task was committed atomically:

1. **task 1: Deterministic linter wrapper script** - `790c2b2` (feat)
2. **task 2: Pin LF line endings via .gitattributes** - `075ee6f` (chore)
3. **task 3: Write the scope-exemption decision record** - `7fc3353` (docs)

**Plan metadata:** _(docs commit appended below)_

## Files Created/Modified
- `scripts/run_lint.sh` - Deterministic linter runner: idempotent uv/Python 3.12/venv/linter provisioning, text + `--json` artifacts, always completes.
- `.gitattributes` - Pins LF for `scripts/*`, `*.sh`, `manifest.toml`, text; marks images binary.
- `.planning/phases/04-lint-baseline/lint-baseline.txt` - Archived before-fix text artifact (57 lines, ends with `exit_code=1`).
- `.planning/phases/04-lint-baseline/lint-baseline.json` - Archived before-fix JSON: 1 critical, 2 errors, 9 warnings, 7 infos.
- `.planning/phases/04-lint-baseline/04-SCOPE-EXEMPTIONS.md` - Zero-error invariant definition + 5 exempted findings with reasons/unblockers.

## Decisions Made
- **Zero-error invariant narrowed to locally-fixable findings.** `zero_errors_assertion = (critical ∪ error) \ exempted == ∅`. Catalog-dependent findings (`AppCatalog.is_in_catalog`, `state_is_working`, `has_category`) and `Configurations.tests_toml` are exempted with explicit reasons and unblocking work (future catalog PR; Phase 5/CI-01).
- **WebSocket headers deliberately retained.** The `Upgrade`/`Connection` nginx redundancy warning is permanently exempted because LibreChat requires them for WebSockets/SSE; the 4 plain proxy headers are still removed in Plan 03.
- **Linter runs only under WSL2.** Bare Windows/Git Bash is confirmed broken (`subprocess(shell=True)` → `cmd.exe`); `/tmp/pl` and its venv are never committed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- **PowerShell/bash quoting artifact (non-blocking).** When running the Task 2 automated verify through `wsl -e bash -lc '... ! ...'`, the outer PowerShell layer mangled the negated-grep expression, producing a spurious `w/crlf: No such file or directory` message. Re-ran the check with an explicit `if grep ...; then ... fi` form, which confirmed `VERIFY_OK_NO_CRLF`. The intended check passed.

## User Setup Required

None - no external service configuration required. The first `scripts/run_lint.sh` run provisions `uv`, Python 3.12, and the linter clone automatically.

## Next Phase Readiness
- Wave 0 scaffolding complete: Plans 02–04 can now verify against `scripts/run_lint.sh` as the phase's test suite (Nyquist sample after every task).
- Baseline artifacts are archived and committed, providing the audit trail for the final zero-error claim.
- Baseline totals match research exactly (1 critical, 2 errors, 9 warnings, 7 infos), so no linter-drift note is required.
- `04-SCOPE-EXEMPTIONS.md` will be re-checked by Plan 04 after the final run to confirm every remaining finding is exempted.

---
*Phase: 04-lint-baseline*
*Completed: 2026-09-19*

## Self-Check: PASSED

All 5 deliverable files exist (run_lint.sh, .gitattributes, lint-baseline.txt, lint-baseline.json, 04-SCOPE-EXEMPTIONS.md); all 3 task commits (`790c2b2`, `075ee6f`, `7fc3353`) present in `git log`.
