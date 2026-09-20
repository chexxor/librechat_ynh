---
phase: 05-tests-toml-local-package-check-environment
plan: 03
subsystem: testing
tags: [package_check, yunohost, hyper-v, debian-12, incus, btrfs, ci, full-suite-run, findings]

# Dependency graph
requires:
  - phase: 05-tests-toml-local-package-check-environment
    provides: tests.toml (05-01) — the CI-01 deliverable whose deduced suite this run exercised
  - phase: 05-tests-toml-local-package-check-environment
    provides: scripts/setup_pc_env.sh + doc/PACKAGE_CHECK.md (05-02) — the host provisioning path used to build the VM
provides:
  - "Phase 5 findings run archived: Test_results.log, package_check-full.log, full_log_0.log, results_0.json, tests.toml"
  - "Human-readable findings + Phase 6 handoff (05-FINDINGS.md)"
  - "Proof that the documented environment drives a complete end-to-end package_check run (CI-02 Phase 5 bar)"
  - "Root-cause finding: admin_panel_session_secret variable-name mismatch aborts every install"
affects: [06-fix-findings, POLS-01, phase-7-gh-actions]

# Tech tracking
tech-stack:
  added: [package_check full suite, package_linter at runtime]
  patterns:
    - "Long runs decoupled from SSH via tmux/nohup + tee; poll and retrieve logs (never foreground)"
    - "Expected findings (change_url, linter catalog metadata) labeled distinct from crashes/timeouts"
    - "Phase 5 findings evidence deliberately kept separate from Phase 6 zero-failure (POLS-01) archive"

key-files:
  created:
    - .planning/phases/05-tests-toml-local-package-check-environment/Test_results.log
    - .planning/phases/05-tests-toml-local-package-check-environment/package_check-full.log
    - .planning/phases/05-tests-toml-local-package-check-environment/full_log_0.log
    - .planning/phases/05-tests-toml-local-package-check-environment/results_0.json
    - .planning/phases/05-tests-toml-local-package-check-environment/tests.toml
    - .planning/phases/05-tests-toml-local-package-check-environment/05-FINDINGS.md
    - .planning/phases/05-tests-toml-local-package-check-environment/env-sanity.txt
  modified: []

key-decisions:
  - "Phase 5 bar is 'starts and completes' (findings allowed); 6/6 tests resolved, exit 0, no Critical abort/crash/timeout — CI-02 Phase 5 bar MET"
  - "install.root FAIL is a genuine package bug (uninitialized $admin_panel_session_secret vs __ADMIN_PANEL_SESSION_SECRET__), not environmental — single root cause of the failing run"
  - "backup_restore/upgrade/upgrade.05e3d5b/change_url FAILs are cascades from the install failure, not four independent defects"
  - "package_linter reports 1 critical + 1 error but they are catalog-metadata only (app not in YunoHost catalog yet) and do NOT fail the linter test"
  - "install.subdir/install.private/install.multi did not run (no [install.path] question; parser never auto-generates private; multi_instance=false) — Phase 6 may add them explicitly if POLS-01 requires coverage"
  - "Test_results.log is a synthesized de-ANSI'd stdout capture; upstream package_check emits full_log_0.log/results_0.json/summary_0.png — provenance recorded in the artifact header"
  - "8 reproducibility gaps recorded in 05-FINDINGS.md section 5 to fold into doc/PACKAGE_CHECK.md (python3-toml, linter Python deps, tmux, ethtool, image-alias workaround, eth0 watchdog, DHCP instability, imgkit)"
  - "VM mid-run drops (BLOCKER #1/#2) resolved by wired External switch + eth0-watchdog.service; run re-attempted and completed with the VM stable"

patterns-established:
  - "Decouple long package_check runs from SSH (tmux + tee to a log) and poll; retrieve logs in the clone root"
  - "Honest triage: separate expected findings from crashes and from cascade failures so Phase 6 fixes the root cause first"

requirements-completed: [CI-02]

# Metrics
duration: 8min
completed: 2026-09-20
---

# Phase 5 Plan 3: Full-Suite package_check Findings Run Summary

**Full package_check suite ran to completion on the Hyper-V Debian 12 VM (6/6 test types resolved, exit 0, no crash/timeout, 4m5s) and pinpointed the install-blocking `admin_panel_session_secret` bug as the single root cause for Phase 6.**

## Performance

- **Duration:** ~8 min (this finalize segment; the run itself was 4m5s of Global working time)
- **Started:** 2026-09-20 (Task 2/3 runs earlier in the day; finalization after Task 5 approval)
- **Completed:** 2026-09-20
- **Tasks:** 5 (Tasks 1-4 executed earlier; Task 5 checkpoint approved by the user)
- **Files modified:** 7 created (run artifacts + findings + sanity capture)

## Accomplishments

- Ran the full `package_check` suite once end-to-end on the user-provisioned `alex@192.168.1.83` VM (Hyper-V Gen 2 Debian 12 bookworm; 4 vCPU / 7.8 GiB RAM / 40 GB btrfs + 30 GB OS) with the deduced suite `package_linter, install.root, backup_restore, upgrade, upgrade.05e3d5b, change_url`.
- Confirmed the Phase 5 bar: **6/6 test types resolved, `PACKAGE_CHECK_EXIT: 0`, no `Critical:` abort, no crash, no timeout** — the environment and `tests.toml` genuinely drive a complete run.
- Archived the findings run in the phase dir (`Test_results.log`, `package_check-full.log`, `full_log_0.log`, `results_0.json`, exact `tests.toml`) and wrote `05-FINDINGS.md` as the Phase 6 handoff.
- Triaged results honestly: `package_linter` SUCCESS; `install.root` FAIL = **genuine package bug**; Tests 3-6 FAIL = cascades, not independent defects; `change_url` additionally expected (no `scripts/change_url`, POLS-02 deferred).
- Identified the headline Phase 6 fix: `scripts/_common.sh` generates/persists `admin_panel_secret`, but `conf/librechat.env` substitutes `__ADMIN_PANEL_SESSION_SECRET__` (lowercased by `_ynh_replace_vars` to the never-set `$admin_panel_session_secret`) — aborts every install.
- User approved the Task 5 reproducibility gate: suite completed, the doc reproduces the environment with no undocumented steps, and Phase 5 evidence is distinct from Phase 6.

## Task Commits

Each task was committed atomically:

1. **task 2: Provision the in-VM environment and copy the package over SSH** - `c963811` (chore)
2. **task 3: Record VM-offline blocker for full-suite run** - `a686a26` (docs)
3. **task 3: Record second VM-offline blocker blocking full-suite rerun** - `df864ef` (docs)
4. **task 3: Run full package_check suite once and archive findings logs** - `aa51ba0` (test)
5. **task 4: Write 05-FINDINGS.md and hand off findings to Phase 6** - `793f8ca` (docs)
6. **task 3-4 state: Update STATE/ROADMAP for Tasks 3-4 complete, Task 5 gate pending** - `64996d5` (docs)

**Plan metadata:** pending (docs: complete full-suite findings run plan)

## Files Created/Modified

- `.planning/phases/05-tests-toml-local-package-check-environment/Test_results.log` - de-ANSI'd stdout capture ending in the Global summary (Phase 5 evidence)
- `.planning/phases/05-tests-toml-local-package-check-environment/package_check-full.log` - raw `tee` capture of the run, verbatim
- `.planning/phases/05-tests-toml-local-package-check-environment/full_log_0.log` - package_check full debug log (authoritative per-test detail)
- `.planning/phases/05-tests-toml-local-package-check-environment/results_0.json` - currently the `imgkit` ModuleNotFoundError traceback (renderer aborted)
- `.planning/phases/05-tests-toml-local-package-check-environment/tests.toml` - exact copy used (md5 `4cdd83e3b8e13b08c3aac8e5e79ab07d`)
- `.planning/phases/05-tests-toml-local-package-check-environment/05-FINDINGS.md` - human-readable findings + Phase 6 handoff
- `.planning/phases/05-tests-toml-local-package-check-environment/env-sanity.txt` - in-VM environment sanity capture

## Decisions Made

- **Phase 5 bar met, findings allowed.** 6/6 resolved + exit 0 + no crash/timeout is success for Phase 5; zero failures is deferred to Phase 6/POLS-01.
- **The install failure is a package bug, not an environment problem.** Root cause is the variable-name mismatch, worth a single Phase 6 fix that unblocks Tests 3-6.
- **Tests 3-6 are cascades.** Their FAIL verdicts must not be read as four independent package defects.
- **`package_linter` passed.** Its 1 critical + 1 error are catalog-metadata (not in YunoHost catalog yet) and are non-fatal for the linter test.
- **Coverage gap flagged for Phase 6.** `install.subdir`/`install.private`/`install.multi` never ran; add explicitly if POLS-01 needs them.
- **Evidence separation honored.** The Phase 5 findings run is not a zero-failure claim; Phase 6 archives its own POLS-01 run.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Installed host Python/dependency packages required by package_check**
- **Found during:** task 3 (first suite attempt)
- **Issue:** `parse_tests_toml.py` needed `python3-toml`; `package_linter` crashed on missing `jsonschema`; the long run needs `tmux`; the NIC watchdog needs `ethtool`.
- **Fix:** Installed `python3-toml`, `python3-{jsonschema,packaging,pyparsing,six}`, `tmux`, `ethtool` host-side on the VM.
- **Files modified:** VM packages only (no repo files).
- **Verification:** Suite then launched and completed.
- **Committed in:** `aa51ba0` (task 3 commit — artifacts only; environment fixes are outside the repo)

**2. [Rule 3 - Blocking] Image-alias workaround for the yunohost simplestreams remote**
- **Found during:** task 3 (container launch)
- **Issue:** The upstream `yunohost:bookworm-stable-appci` alias did not resolve consistently from the simplestreams remote.
- **Fix:** `incus image copy yunohost:91abc4fc4c43 local: --alias yunohost-bookworm-stable-appci` for deterministic container launch.
- **Files modified:** VM Incus image store only.
- **Verification:** Container launched deterministically.
- **Committed in:** `aa51ba0` (task 3 commit)

**3. [Rule 3 - Blocking] eth0 NIC-flap mitigation to keep the VM online through the run**
- **Found during:** task 3 (BLOCKER #1/#2 — VM dropped mid-run)
- **Issue:** eth0 went DOWN mid-install and never recovered; two prior runs were aborted by the VM going hard-offline.
- **Fix:** Moved the VM to the wired External switch, set up SSH, and installed an active+enabled `eth0-watchdog.service` that auto-uplinks eth0 and re-runs `dhclient` every 20 s. Run re-attempted and completed with the VM stable throughout.
- **Files modified:** VM systemd unit only.
- **Verification:** 2026-09-20 full run completed with no eth0 drop.
- **Committed in:** `aa51ba0` / `df864ef` (task 3 commits)

**4. [Rule 3 - Blocking] Documented harness renderer gap (`imgkit`) without blocking the run**
- **Found during:** task 3 (summary render)
- **Issue:** `lib/analyze_test_results.py` aborted with `ModuleNotFoundError: No module named 'imgkit'`, so it did not render the pass/fail table or populate `results_0.json`.
- **Fix:** Did not block the run — the per-test verdicts come from `package_check.sh` itself and are in the run log; documented as an environmental deviation (`results_0.json` unusable without it).
- **Files modified:** none.
- **Verification:** Terminal verdict banners present for all 6 tests; Global summary printed.
- **Committed in:** `aa51ba0` / `793f8ca` (findings documentation)

---

**Total deviations:** 4 auto-fixed (all Rule 3 - Blocking; environment/harness only)
**Impact on plan:** All fixes were necessary to make the run happen and are recorded as reproducibility gaps in `05-FINDINGS.md` section 5 for the doc/setup-script follow-up. No repo scope creep; no `exclude`/`only`/private-suite content was added.

## Issues Encountered

Two failed runs occurred before the successful one, both caused by **`eth0` dropping mid-run** (a Hyper-V NIC link flap): the VM went hard-offline mid-install and `package_check.sh -s` (force-stop) hung on the first crashed run. Two blockers were logged (`a686a26`, `df864ef`). The root fix was environmental, not package-related:

- Switched the VM's virtual NIC to the **wired External switch** and established SSH connectivity, and
- Added an active+enabled `eth0-watchdog.service` on the VM that auto-uplinks `eth0` and re-runs `dhclient` every 20 s if the NIC flaps.

This is why the run was re-attempted: the 2026-09-20 full run completed with the VM stable for the entire 4m5s run. Side effect observed: the VM's IP is DHCP on the External switch (changed `.85` -> `.83`) rather than the doc's specified static IP — recorded as a reproducibility gap. No test crashed or timed out in the successful run.

## User Setup Required

The one-time Hyper-V Debian 12 VM provisioning was a user step (Task 1) and is complete; no further user setup is required for Phase 5. Reproducibility gaps that should be folded into `doc/PACKAGE_CHECK.md` / `scripts/setup_pc_env.sh` are listed in `05-FINDINGS.md` section 5.

## Next Phase Readiness

- **CI-02 satisfied at the Phase 5 bar:** following the documented setup, the full suite started and completed with findings allowed — no crashes or timeouts; the findings run is archived and handed off.
- **Phase 6 entry point is clear:** fix the `admin_panel_secret` / `admin_panel_session_secret` / `__ADMIN_PANEL_SESSION_SECRET__` mismatch first; then re-run and re-triage Tests 3-6 (currently cascades), and decide on `change_url` and subpath/private coverage.
- **Blockers:** none open. Both VM-offline blockers are RESOLVED (wired External switch + eth0-watchdog).
- Phase 5 evidence is deliberately distinct from the future Phase 6 zero-failure (POLS-01) archive.

---
*Phase: 05-tests-toml-local-package-check-environment*
*Completed: 2026-09-20*

## Self-Check: PASSED

- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/Test_results.log
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/package_check-full.log
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/full_log_0.log
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/results_0.json
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/tests.toml
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/05-FINDINGS.md
- FOUND: .planning/phases/05-tests-toml-local-package-check-environment/env-sanity.txt
- FOUND: commit c963811 (task 2)
- FOUND: commit aa51ba0 (task 3)
- FOUND: commit 793f8ca (task 4)
