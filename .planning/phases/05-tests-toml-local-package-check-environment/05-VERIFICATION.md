---
phase: 05-tests-toml-local-package-check-environment
verified: 2026-09-20T15:30:00Z
status: passed
score: 13/13 must-haves verified
re_verification: false
human_verification:
  - test: "Re-run `doc/PACKAGE_CHECK.md` from scratch on a fresh Hyper-V Debian 12 VM"
    expected: "The documented steps (VM provisioning -> `sudo bash scripts/setup_pc_env.sh <user>` -> `incus admin init` -> suite run) reproduce the environment (btrfs_pool, incusbr0, yunohost remote) with no undocumented steps"
    why_human: "Reproducibility-from-scratch requires a fresh VM and a human operator; cannot be re-run programmatically in this environment (the original VM at 192.168.1.83 is user-provisioned)."
  - test: "Visually inspect the package_check terminal output / Test_results.log for readability"
    expected: "Colored terminal summary is human-readable; the de-ANSI'd capture faithfully represents the run"
    why_human: "Rendering/color fidelity is a visual property."
---

# Phase 5: tests.toml + Local package_check Environment — Verification Report

**Phase Goal:** The package has a schema-valid `tests.toml` (supplying install args like `admin_email`, optional curl smoke-tests and one `test_upgrade_from` entry) and a reproducible local Linux environment (dedicated Hyper-V Debian 12 VM + Incus + btrfs, documented) that can run the full `package_check` suite end-to-end.
**Verified:** 2026-09-20T15:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

Phase 5's bar is **"suite starts and completes — findings allowed, crashes not."** Zero failures is Phase 6 (POLS-01) and is explicitly out of scope here. The 5 test FAILs are expected findings and are NOT grounds for phase failure.

### Observable Truths (Success Criteria)

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `tests.toml` exists with `test_format = 1.0` + `#:schema` header; package_check parses it and installs proceed with `admin_email` supplied — no `exclude` misuse | ✓ VERIFIED | `tests.toml` L1 `#:schema`, L3 `test_format = 1.0`, L13 `args.admin_email`. `tests-dryrun.txt` shows the parser deducing 6 tests with `install_args=...&admin_email=package_checker@example.com`. Grep confirms `exclude` absent, `only =` absent. |
| 2 | Following the documented setup doc, user can run `package_check` locally on the Hyper-V Debian 12 VM and see the full suite start and complete (findings allowed, crashes not) | ✓ VERIFIED | `Test_results.log` L208 "Global working time for all tests: 4 minutes, 5 seconds", L210 `PACKAGE_CHECK_EXIT: 0`, no `Critical:` abort. All 6 deduced tests resolved: package_linter SUCCESS; install.root/backup_restore/upgrade/upgrade.05e3d5b/change_url FAIL (findings). Duplicate confirmed in `package_check-full.log`. |
| 3 | Environment setup on the Hyper-V Debian 12 VM host (Incus init, btrfs, `lynx jq btrfs-progs`, yunohost remote) is documented and reproducible by re-running the doc from scratch | ✓ VERIFIED | `doc/PACKAGE_CHECK.md` (210 lines) documents Hyper-V Gen2 provisioning, second disk, SSH, `setup_pc_env.sh`, `incus admin init`, tmux/nohup/ServerAliveInterval, log retrieval. `scripts/setup_pc_env.sh` idempotent (guards at L52/90/94/102/112), installs `lynx jq btrfs-progs`, Zabbly repo, btrfs_pool, yunohost remote, clones package_check. `env-sanity.txt` proves the provisioned state. Repro-from-scratch flagged for human. |

**Score:** 3/3 success criteria (truths) verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `tests.toml` (repo root) | test_format 1.0, #:schema header, args.admin_email, test_upgrade_from.05e3d5b.name, [default.curl_tests] with 3 home.* keys; NO exclude/only=/private suite | ✓ VERIFIED | 27 lines. All required patterns present; forbidden patterns absent. LF-only (CR=0). md5 `4cdd83e3b8e13b08c3aac8e5e79ab07d` matches the VM/run and phase-dir copy. |
| `scripts/setup_pc_env.sh` | Idempotent, Zabbly Incus repo, btrfs_pool, yunohost remote, package_check clone; LF-only | ✓ VERIFIED | 128 lines, substantive, no TODO/stub anti-patterns. All 7 steps present with idempotency guards. LF-only (CR=0). |
| `doc/PACKAGE_CHECK.md` | ≥60 lines; Hyper-V/Debian 12/second disk/SSH/setup_pc_env.sh/package_check.sh/Test_results.log/Zabbly/incus admin init/tmux\|nohup\|ServerAliveInterval | ✓ VERIFIED | 210 lines. All 13 required terms present (btrfs 11×, Hyper-V 4×, SSH 8×, etc.). "second virtual disk" at L43. |
| `.planning/REQUIREMENTS.md` CI-02 amended | Hyper-V, not WSL2 | ✓ VERIFIED | CI-02 reads "dedicated Hyper-V Debian 12 VM + Incus + btrfs". Zero WSL occurrences in REQUIREMENTS.md. |
| `.planning/ROADMAP.md` Phase 5 goal + criteria | Mention Hyper-V; no WSL2 in Phase 5 section; Phase 4 WSL2 preserved | ✓ VERIFIED | Phase 5 section (L45-57) has Hyper-V in goal + criteria 2 & 3, zero WSL2. Phase 4 criteria (L35) WSL2 mention preserved. |
| `05-03` phase artifacts: env-sanity.txt, tests-deduction.json, tests-dryrun.txt, Test_results.log, package_check-full.log, full_log_0.log, results_0.json, tests.toml, 05-FINDINGS.md | All present | ✓ VERIFIED (1 info) | All 9 present. `results_0.json` contains the `analyze_test_results.py` imgkit `ModuleNotFoundError` traceback rather than a machine-readable summary — documented deviation (Test_results.log L24-29, 05-FINDINGS.md). Completion evidence comes from Test_results.log + full_log_0.log, so truth 2 is unaffected. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `tests.toml` | `manifest.toml` | `args.admin_email` supplies the no-default `[install.admin_email]` arg | ✓ WIRED | `tests.toml` L13; dry-run install args include `admin_email=package_checker@example.com`; run L128 passes it to `yunohost app install`. |
| `tests.toml` | commit `05e3d5b` | `test_upgrade_from.05e3d5b` git ref checked out | ✓ WIRED | `tests.toml` L20; dry-run emits TEST_UPGRADE test_arg `05e3d5b` (tests-dryrun.txt L41). |
| `doc/PACKAGE_CHECK.md` | `scripts/setup_pc_env.sh` | doc instructs running the script as the in-VM setup step | ✓ WIRED | doc L75/78 commands; setup_pc_env.sh referenced 5×. |
| `doc/PACKAGE_CHECK.md` | `package_check` | doc gives exact suite command + log retrieval | ✓ WIRED | doc L124 `./package_check.sh ~/librechat_ynh`; package_check.sh 3×; log retrieval L173-186. |
| `05-03 run` | `tests.toml` | package_check consumes repo-root tests.toml | ✓ WIRED | Run's deduced 6-suite matches tests.toml; `env-sanity.txt` L102 records the identical md5 on the VM. |
| `05-03 run` | `scripts/setup_pc_env.sh` | run happened on a host provisioned by the 05-02 path | ✓ WIRED | `env-sanity.txt` proves btrfs_pool/incusbr0/yunohost remote/package_check clone exactly as the script provisions; 05-FINDINGS.md "Environment deviations" records path. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| CI-01 | 05-01 | `tests.toml` suite with `test_format = 1.0`, args (e.g. `admin_email`), documented syntax (no `exclude` misuse) | ✓ SATISFIED | tests.toml verified; parser dry-run deduces exactly `package_linter, install.root, backup_restore, upgrade, upgrade.05e3d5b, change_url`; no `exclude`. |
| CI-02 | 05-02, 05-03 | Run `package_check` locally from dedicated Hyper-V Debian 12 VM + Incus + btrfs (documented, reproducible) | ✓ SATISFIED | setup script + doc + env-sanity + completed suite run (exit 0, global summary). REQUIREMENTS.md marks CI-02 Complete. |

**Orphaned requirements:** None. Phase 5 maps only CI-01 and CI-02 in REQUIREMENTS.md; both are claimed by plans and accounted for.

### Deduced Suite Verification (crux check)

`tests-deduction.json` and `tests-dryrun.txt` both confirm **exactly** 6 tests:
`package_linter, install.root, backup_restore, upgrade, upgrade.05e3d5b, change_url`.
**No** `install.subdir`, `install.private`, or `install.multi`. This matches the required deduction precisely.

`Test_results.log` confirms all 6 actually ran to a verdict (`--- SUCCESS ---` ×1, `--- FAIL ---` ×5) and the run terminated with the global summary + exit 0. This is a *completed* run with findings, not a crash/timeout.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `results_0.json` (phase dir) | 1-4 | `ModuleNotFoundError: No module named 'imgkit'` (renderer traceback, not summary JSON) | ℹ️ Info | The `analyze_test_results.py` renderer could not run; `results_0.json` holds a traceback. Completion evidence is fully covered by `Test_results.log` + `package_check-full.log`. Documented in Test_results.log L24-29 and 05-FINDINGS.md. No effect on Phase 5 goal. |
| `scripts/setup_pc_env.sh` | — | No TODO/FIXME/placeholder/empty-impl anti-patterns | — | Clean. |
| `tests.toml` | 9, 8 | Comment mentions "private suite"/"install.subdir" | ℹ️ Info | Explanatory comments only; not active keys. Not a stub. |

No 🛑 blocker or ⚠️ warning anti-patterns found.

### Human Verification Required

1. **Reproducibility from scratch** — Re-run `doc/PACKAGE_CHECK.md` on a fresh Hyper-V Debian 12 VM and confirm the environment (btrfs_pool, incusbr0, yunohost remote, package_check clone) reproduces with no undocumented steps. Cannot be automated (needs a fresh user-provisioned VM).
2. **Visual log inspection** — Confirm the de-ANSI'd `Test_results.log` faithfully represents the terminal run and is human-readable.

### Gaps Summary

**No gaps.** All 3 success criteria, all 6 required artifacts, and all 6 key links verify. Both requirement IDs (CI-01, CI-02) are accounted for with implementation evidence. The documented deviations (`imgkit` missing renderer dependency; captured `Test_results.log` reconstructed from package_check verdict banners) do not undermine the crux evidence: package_check completed 6/6 deduced suites with a Global summary and `PACKAGE_CHECK_EXIT: 0`, with no `Critical:` abort.

The 5 test FAILs are **expected Phase 5 findings** (root cause: uninitialized `$admin_panel_session_secret` in `scripts/install`, which blocks install and cascades to backup/restore/upgrade/change_url). Zero failures is Phase 6 / POLS-01 and was explicitly out of scope for this phase.

---

_Verified: 2026-09-20T15:30:00Z_
_Verifier: OpenCode (gsd-verifier)_
