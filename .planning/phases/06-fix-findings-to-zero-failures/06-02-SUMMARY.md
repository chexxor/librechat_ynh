---
phase: 06-fix-findings-to-zero-failures
plan: 02
subsystem: packaging
tags: [yunohost, secret-hygiene, xtrace, set-x, redaction, pols-01-evidence]
requires:
  - phase: 05
    provides: the observed secret leak in full_log_0.log under set -x
provides:
  - xtrace guards around secret generation, secret read-back, and admin-user creation
  - A redaction+assertion tool for archived package_check logs
affects: [06-05]
tech_stack:
  added: []
  patterns: ["set +o xtrace / set -o xtrace scoped guard", "fixed-string redaction with awk + grep -F assertion"]
key_files:
  created:
    - scripts/redact_pc_logs.sh
  modified:
    - scripts/_common.sh
    - scripts/install
key_decisions:
  - "Guard xtrace narrowly around secret lines (do NOT blanket-disable xtrace)"
  - "Keep exactly one intended admin-password display (ynh_print_info) — operationally required"
  - "Redaction uses literal (non-regex) matching; assertion mode exits non-zero on residuals"
patterns_established:
  - "Every secret-bearing expansion is wrapped by a scoped xtrace guard that restores xtrace only if it was on"
duration: ~15 min
completed: 2026-09-20
---

# Phase 6 Plan 02: Secret hygiene — xtrace guards + redaction tool

**Stopped `set -x` from echoing generated secret values, and built the tool that makes the POLS-01 archive safe to commit.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-09-20
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `librechat_generate_secrets` and the secret read-back block of `librechat_regen_and_merge_configs` are wrapped in scoped xtrace guards (restore only if xtrace was previously on).
- `librechat_create_admin_user "$admin_email" "$admin_password"` is wrapped so the password argv is not xtrace-echoed.
- Exactly one intended admin-password display remains (`scripts/install`); the operator email heredoc is untouched.
- `scripts/redact_pc_logs.sh` redacts supplied secret values (literal match), supports `SECRETS_FILE`/`SECRET_VALUES`, `--assert-only`, is idempotent, and exits non-zero on residuals.

## Task Commits

1. **Both tasks:** `d48cfd0` — `fix(06-02): guard secret handling against xtrace and add log redaction tool`

## Verification

- `bash -n` clean for all three scripts.
- Redaction test: sample log → `admin_panel_secret=***REDACTED***`, `REDACTION OK: 0 residual secret matches`; assertion mode fails correctly on a dirty log; re-run is byte-identical (idempotent).

## Deviations from Plan

One mid-task correction: the first guard on `librechat_regen_and_merge_configs` prematurely closed the function; moved the xtrace restore + `return 0` to the true end of the function. Caught by `bash -n` before commit.

## Next Phase Readiness

Ready for the VM cycles. The final archive (Plan 06-05) uses `scripts/redact_pc_logs.sh`.
