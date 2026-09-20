# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-19)

**Core value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.
**Current focus:** Phase 5 - tests.toml + Local package_check Environment (v1.1 CI Validation)

## Current Position

Milestone: v1.1 CI Validation (phases 4-7)
Phase: 5 of 7 (tests.toml + Local package_check Environment)
**Current Plan:** 05-03 complete (all 3 Phase 5 plans complete)
**Total Plans in Phase:** 3
**Status:** Phase 5 plans complete - execution done, phase verification pending (orchestrator handles phase completion)
Last activity: 2026-09-20 - 05-03 finalized: Task 5 checkpoint:human-verify APPROVED by user; 05-03-SUMMARY.md written (CI-02), ROADMAP 3/3.

**Progress:** [##########] 100%

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
| v1.1 Phase 05 | 3 | 3 | ~12min |

## Accumulated Context

### Decisions

Decisions logged in PROJECT.md Key Decisions table. Recent for v1.1:

- [Research]: GH Actions = lint-only; full package_check on hosted runners is an anti-feature (Incus/btrfs requirements + OOM). Official YNH CI covers the full suite after catalog submission.
- [Research]: Phase order - linter first (zero infra), then tests.toml + local PC env, then fix-findings iteration, GH workflow last so it starts green.
- [Research]: `tests.toml` must supply `args.admin_email`; never use `exclude` to fake green CI.
- [Phase 04]: Zero-error invariant defined as (critical union error) minus exempted == empty; 5 out-of-scope findings documented in 04-SCOPE-EXEMPTIONS.md
- [Phase 04]: Main permission warning fixed via [install.init_main_permission] group question (canonical example_ynh pattern), not allowed= on resources.permissions
- [Phase 04]: nginx WS headers (proxy_http_version + Upgrade + Connection) deliberately retained over include proxy_params_no_auth; only the 4 plain Host/X-Real-IP/X-Forwarded-* headers removed
- [Phase 04]: README must contain readme_generator marker + dash.yunohost.org/integration/{id}.svg (literal linter greps), not arbitrary shields.io badges
- [Phase 04]: Canonical lint-baseline record is the lint-before-fix.*/lint-after-fix.* pair (text + JSON each); runner scratch lint-baseline.* left on disk but non-canonical
- [Phase 04]: Scope-adjusted zero-error accepted: post-fix JSON retains exactly 1 critical + 2 errors + 2 warnings, all documented exemptions in 04-SCOPE-EXEMPTIONS.md; LINT-01 closed
- [Phase 05]: tests.toml uses test_upgrade_from.05e3d5b (0.8.8-rc3~ynh2) not 116691c - the latter is manifest-only with no scripts/ and not installable
- [Phase 05]: args.admin_email supplied in [default]; no exclude block and no only=[...] on [default] - change_url expected to fail and is a Phase 6 finding (POLS-02 deferred)
- [Phase 05]: package_check host = dedicated Hyper-V Debian 12 VM; Incus from the Zabbly lts-7.0 repo (no native incus on bookworm); btrfs pool on a dedicated second disk (not a dir-backed minimal pool) for fast CoW snapshots
- [Phase 05]: scripts/setup_pc_env.sh is idempotent and BTRFS_DISK-overridable; interactive `incus admin init` documented rather than automated, with the script repointing the default profile root device at btrfs_pool
- [Phase 05]: Full suite completed cleanly (4m5s, exit 0, no Critical abort/crash/timeout) - Phase 5 "starts and completes" bar MET. 6/6 tests resolved: package_linter SUCCESS; install.root FAIL (root cause); backup_restore/upgrade/upgrade.05e3d5b/change_url cascaded FAILs from the install failure
- [Phase 05]: Phase 6 headline fix = admin_panel_secret vs __ADMIN_PANEL_SESSION_SECRET__ name mismatch in scripts/_common.sh + conf/librechat.env - aborts every install inside _ynh_replace_vars
- [Phase 05]: install.subdir/install.private/install.multi did NOT run (no [install.path] question, parser never auto-generates private, multi_instance=false) - Phase 6 may need them added explicitly if POLS-01 requires coverage
- [Phase 05]: Test_results.log is a synthesized de-ANSI'd stdout capture (upstream package_check emits only full_log_0.log/results_0.json/summary_0.png); provenance documented in the artifact header
- [Phase 05]: eth0-watchdog.service on the VM fixed the BLOCKER #1/#2 mid-run drops; IP is DHCP on the host External switch (.85 -> .83) rather than the doc's static IP
- [Phase 05]: 05-03 complete and Task 5 checkpoint APPROVED by the user - full suite ran to completion (6/6 resolved, 4m5s, exit 0, no Critical abort/crash/timeout), findings archived, CI-02 Phase 5 bar met; Phase 5 evidence kept distinct from Phase 6 zero-failure (POLS-01)
- [Phase 05/06]: Phase 6 headline fix = install.root FAILS on the admin_panel_session_secret bug - scripts/_common.sh generates/persists `admin_panel_secret` but conf/librechat.env substitutes `__ADMIN_PANEL_SESSION_SECRET__` (lowercased by _ynh_replace_vars to the never-set `$admin_panel_session_secret`); fixing it unblocks install.root and the cascading backup_restore/upgrade/upgrade.05e3d5b/change_url tests

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: Host decided = dedicated Hyper-V Debian 12 VM + Incus + btrfs (WSL2 ruled out). VM provisioning is a one-time USER step in 05-03 - OpenCode cannot create the VM; requires SSH reachability from Windows (setup script + walkthrough are ready).
- [Phase 6]: package_check is stricter than the live v1.0 install (subpath, private, reinstall, upgrade-from-commit paths never exercised) - expect unknown-scope findings.
- [Phase 5 BLOCKER #1 - 2026-09-20, RESOLVED]: 05-03 Task 3 first attempt: container ynh-appci-bookworm-amd64-stable-test-0 launched; package_linter crashed on missing host jsonschema (auto-fixed by installing python3-{jsonschema,packaging,pyparsing,six,toml}); also installed tmux + python3-toml for the parser, and `incus image copy yunohost:91abc4fc4c43 local: --alias yunohost-bookworm-stable-appci` for the upstream image-alias mismatch. VM at 192.168.1.85 went OFFLINE mid-run after `./package_check.sh -s` (force-stop) hung. RESOLVED by the eth0-watchdog + wired External switch.
- [Phase 5 BLOCKER #2 - 2026-09-20, RESOLVED]: VM went offline again mid-run (same hard-offline pattern). RESOLVED: eth0-watchdog.service (active+enabled) auto-uplinks eth0 + re-runs dhclient every 20s; the 2026-09-20 full run completed with the VM stable throughout. IP is DHCP (.85 -> .83) on the host External switch.
- [Phase 5 - 2026-09-20, RESOLVED]: 05-03 Task 5 checkpoint:human-verify APPROVED by the user - suite completed (findings allowed), doc reproduces the environment with no undocumented steps, and Phase 5 evidence is distinct from Phase 6.
- [Phase 6 - 2026-09-20, NEW]: install.root FAILS on a genuine package bug - `Variable $admin_panel_session_secret wasn't initialized when trying to replace __ADMIN_PANEL_SESSION_SECRET__ in /var/www/librechat/librechat.env`. scripts/_common.sh generates/persists `admin_panel_secret` while conf/librechat.env substitutes `__ADMIN_PANEL_SESSION_SECRET__`. Blocking prerequisite for POLS-01.
- [Phase 6 - 2026-09-20, NEW]: install.subdir/install.private/install.multi did not run (no [install.path] question, parser never auto-generates private, multi_instance=false) - add explicitly if POLS-01 requires that coverage.
- [Phase 5/6 - 2026-09-20, NEW]: 8 reproducibility gaps recorded in 05-FINDINGS.md section 5 (python3-toml, linter Python deps, tmux, ethtool, image-alias workaround, eth0 watchdog, DHCP instability, imgkit) - fold into doc/PACKAGE_CHECK.md and scripts/setup_pc_env.sh.

## Session Continuity

**Last session:** 2026-09-20T21:00:00Z
**Stopped at:** 05-03 complete and approved - full-suite findings run plan finalized (SUMMARY written, ROADMAP 3/3); Phase 5 execution done, phase verification pending per orchestrator
**Resume file:** None
