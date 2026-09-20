# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-19)

**Core value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.
**Current focus:** Phase 5 — tests.toml + Local package_check Environment (v1.1 CI Validation)

## Current Position

Milestone: v1.1 CI Validation (phases 4-7)
Phase: 5 of 7 (tests.toml + Local package_check Environment)
**Current Plan:** 05-03 (05-01, 05-02 complete)
**Total Plans in Phase:** 3
**Status:** In progress
Last activity: 2026-09-20 — 05-03 Task 3 re-run attempted; VM went offline again mid-run (BLOCKER #2). Awaiting VM stabilization.

**Progress:** [█████████░] 93%

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
| v1.1 Phase 05 | 2 | 3 | ~12min |

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
- [Phase 05]: package_check host = dedicated Hyper-V Debian 12 VM; Incus from the Zabbly lts-7.0 repo (no native incus on bookworm); btrfs pool on a dedicated second disk (not a dir-backed minimal pool) for fast CoW snapshots
- [Phase 05]: scripts/setup_pc_env.sh is idempotent and BTRFS_DISK-overridable; interactive `incus admin init` documented rather than automated, with the script repointing the default profile root device at btrfs_pool

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 5]: Host decided = dedicated Hyper-V Debian 12 VM + Incus + btrfs (WSL2 ruled out). VM provisioning is a one-time USER step in 05-03 — OpenCode cannot create the VM; requires SSH reachability from Windows (setup script + walkthrough are ready).
- [Phase 6]: package_check is stricter than the live v1.0 install (subpath, private, reinstall, upgrade-from-commit paths never exercised) — expect unknown-scope findings.
- [Phase 5 BLOCKER #1 - 2026-09-20]: 05-03 Task 3 first attempt: container ynh-appci-bookworm-amd64-stable-test-0 launched; package_linter crashed on missing host jsonschema (auto-fixed by installing python3-{jsonschema,packaging,pyparsing,six,toml}); also installed tmux + python3-toml for the parser, and `incus image copy yunohost:91abc4fc4c43 local: --alias yunohost-bookworm-stable-appci` for the upstream image-alias mismatch. VM at 192.168.1.85 went OFFLINE mid-run after `./package_check.sh -s` (force-stop) hung.
- [Phase 5 BLOCKER #2 - 2026-09-20T14:31Z, ACTIVE]: VM came back online, rebooted fresh. Task 3 RE-RUN from scratch: dry-run `-D` confirmed exact suite (package_linter, install.root, backup_restore, upgrade, upgrade.05e3d5b, change_url); full run launched detached via `setsid nohup ~/pc_launch.sh` (pid 1028/1030) and reached "Launching new LXC ynh-appci-bookworm-amd64-stable-test-0". ~90s later the VM at 192.168.1.85 went OFFLINE AGAIN — ping returns "Destination host unreachable" from the gateway, no ARP/neighbor entry for .85, no repointed DHCP IP found on the subnet, SSH port 22 connection times out. Same hard-offline failure pattern as BLOCKER #1. Likely Hyper-V host/NIC/switch or DHCP-lease instability during the heavy install phase. Needs user to power the VM back on and stabilize its (DHCP) network (static IP per doc/PACKAGE_CHECK.md would prevent recurrence). Full suite must be RE-RUN from scratch again once the VM is back. No logs were retrieved (run did not complete).

## Session Continuity

**Last session:** 2026-09-20T14:31:06Z
**Stopped at:** 05-03 Task 3 blocked — VM offline again mid-run (BLOCKER #2)
**Resume file:** None
