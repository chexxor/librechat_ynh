# POLS-01 Live Verification — Run Metadata

**Phase:** 6 — Fix Findings to Zero Failures
**Requirement:** POLS-01 (`package_check` full suite runs to completion with **zero failures**)
**Archived:** 2026-09-20

## Provenance

| Field | Value |
|-------|-------|
| Date/time (end) | 2026-09-20, 01:57:41 UTC (container clock; host ~20:57 local) |
| Host | `alex@192.168.1.83` — Hyper-V Gen 2 VM, Debian 12 (bookworm) |
| Container | `ynh-appci-bookworm-amd64-stable-test-0` (YunoHost 12.1.41.2 / moulinette 12.1.4 / ssowat 12.1.1) |
| Incus | 7.0.1 (Zabbly `lts-7.0`); `btrfs_pool` |
| package_check ref | `f7d32ca` |
| Package git rev | `1be66f5` (`main`) — **no code change during this run** |
| Command | `cd ~/package_check && ./package_check.sh ~/librechat_ynh` (tmux) |
| Duration | **20 minutes, 45 seconds** |
| `PACKAGE_CHECK_EXIT` | **0** |
| Completion | Global summary printed; no `Critical:` abort, no crash, no timeout |

## Per-test verdicts

| # | Test | Verdict | Note |
|---|------|---------|------|
| 1 | `package_linter` | **SUCCESS** | Reports 1 warning + 3 improvements; the catalog criticals/errors are exempt (see `06-SCOPE-EXEMPTIONS.md`) and do not fail the test |
| 2 | `install.root` | **SUCCESS** | |
| 3 | `backup_restore` | **SUCCESS** | Fixed in cycle 12 (restore re-creates the mongo user with the persisted `db_pwd`) |
| 4 | `upgrade` (same version) | **SUCCESS** | |
| 5 | `upgrade.05e3d5b` | fail — **EXEMPT** | The v1.0 release artifact predates the Phase 4 manifest schema fix and is not installable on modern YunoHost; deferred until a post-fix release (see `06-SCOPE-EXEMPTIONS.md`) |
| 6 | `change_url` | fail — **EXEMPT** | `scripts/change_url` does not exist; deferred to v2 / POLS-02 (see `06-SCOPE-EXEMPTIONS.md`) |

**In-scope zero-failure bar (4 tests): `package_linter`, `install.root`, `backup_restore`, `upgrade` — ALL SUCCESS.**

## Zero-failure invariant satisfied

```
in_scope_tests = { package_linter, install.root, backup_restore, upgrade }
- every in_scope test shows SUCCESS in the suite's per-test verdict banners ✓
- package_check exit code == 0 ✓
- run completed with a Global summary (no Critical abort / crash / timeout) ✓
```

## Flake-vs-regression note

- This is a **single clean run** — not a composite of per-test retries.
- **No package code changed** during or immediately before this run (`1be66f5` on the VM at run time).
- The VM NIC flapped between IPs during earlier cycles; this run completed without a mid-run drop. No environment tweak was applied between the last code change and this run.

## Secret hygiene / redaction

- `scripts/restore` and the secret-handling helpers are run under xtrace guards, so only the **intentional end-of-install admin-password display** leaks into the logs. All other generated secrets (jwt, admin_panel_secret, meili master key, mongo password) were verified **absent** from this run's logs.
- The archived logs in this directory are **redacted**: the two admin passwords are replaced with `***REDACTED***`. See `REDACTION-REPORT.txt` (`REDACTION OK: 0 residual secret matches`).
- Raw (unredacted) logs are **not committed** — they live only on the VM under `~/pc_run_cycle13.log` and `~/package_check/full_log_0.log`.

## Artifact provenance note

`Test_results.log` is a **synthesized de-ANSI'd capture** of the `tee`'d run stdout (`~/pc_run_cycle13.log`). Upstream `package_check` does not emit this filename; it emits `full_log_0.log` / `results_0.json` / `summary_0.png`. The synthesized file is provided for readability; `package_check-full.log` is the verbatim raw capture, and `full_log_0.log` is the upstream debug log.

## Evidence separation

This is **Phase 6's own** single clean run and is the POLS-01 live-verification artifact. The Phase 5 findings run (`.planning/phases/05-…/05-FINDINGS.md`, `Test_results.log`) is deliberately kept separate and is **not** a zero-failure claim.

---

*Phase: 06-fix-findings-to-zero-failures*
*POLS-01 archived: 2026-09-20*
