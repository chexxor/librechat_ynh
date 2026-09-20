# Phase 5 Findings — package_check findings run (CI-02 evidence)

**Phase 5 bar: the full suite STARTS and COMPLETES — findings are allowed, crashes/timeouts are not.**
This document is the human-readable summary of that run and the handoff to Phase 6. It does **not**
claim zero failures — zero failures is Phase 6 / POLS-01, and Phase 5 vs Phase 6 evidence stay distinct.

---

## 1. Run metadata

| Field | Value |
|-------|-------|
| Date | 2026-09-20 |
| Run window | 19:55:38Z → 19:59:35Z (Global working time **4 minutes, 5 seconds**) |
| Host | `alex@192.168.1.83` — Hyper-V Generation 2 VM, Debian 12 (bookworm), kernel 6.1.0-53-amd64 |
| VM sizing | 4 vCPU / **7.8 GiB RAM** / 40 GB btrfs disk + 30 GB OS disk (+976 MB swap) |
| Incus | **7.0.1** (client + server), Zabbly `lts-7.0` channel |
| Storage pool | `btrfs_pool` driver **btrfs** (on `/dev/sda1`) — confirmed, not `dir` |
| Network bridge | `incusbr0` (managed dnsmasq owns :53) |
| YunoHost container | `yunohost:bookworm-stable-appci` → `yunohost 12.1.41.2` / `moulinette 12.1.4` / `ssowat 12.1.1` |
| package_check ref | `f7d32ca` ("Format Python code with Black", 2026-05-25) |
| Package under test | `~/librechat_ynh` on the VM; `tests.toml` md5 `4cdd83e3b8e13b08c3aac8e5e79ab07d` |
| Completion | **Completed cleanly** — `PACKAGE_CHECK_EXIT: 0`, Global summary printed, **no `Critical:` abort, no crash, no timeout** |
| VM stability | Stayed online for the whole run. First successful full run — prior attempts (BLOCKER #1/#2) lost the VM mid-install; the new `eth0-watchdog.service` + wired External switch fixed it. |

## 2. Deduced suite actually run

package_check **completed 6 of 6** deduced test types:

```
package_linter, install.root, backup_restore, upgrade, upgrade.05e3d5b, change_url
```

Explicitly **not** run (expected — corrects an earlier CONTEXT/ROADMAP assumption):

- **`install.subdir`** — LibreChat has **no `[install.path]` question**, so package_check treats it as a
  full-domain/domain-root app and does **not** generate `install.subdir`.
- **`install.private`** — the parser **never auto-generates** a private-install suite.
- **`install.multi`** — skipped because `multi_instance = false` in `manifest.toml`.

Consequence for Phase 6: if POLS-01 requires subpath or private-install coverage, it must be added
**explicitly** via `[install.path]` (manifest) or an explicit extra suite — nothing auto-generates them today.

## 3. Per-test results

| # | Test | Result | Reason |
|---|------|--------|--------|
| 1 | `package_linter` | **SUCCESS** | Linter ran and passed. It *reports* 1 critical + 1 error but they are **catalog-metadata** findings (`AppCatalog.is_in_catalog`, `AppCatalog.state_is_working`) — the app is simply not in YunoHost's catalog yet. Also 2 warnings (`AppCatalog.has_category`, nginx reverse-proxy params) and 5 info (`App.change_url_script`, systemd hardening ×2, nginx params, `is_in_github_org`). These do not fail the linter test. |
| 2 | `install.root` | **FAIL** | **Genuine package bug (Phase 6 fix).** Install reached "Adding configuration files…" after a full MongoDB apt + `npm ci` + `turbo build`, then aborted: `Variable $admin_panel_session_secret wasn't initialized when trying to replace __ADMIN_PANEL_SESSION_SECRET__ in /var/www/librechat/librechat.env`. Duration 3m11s; peak RAM 2535 MB. |
| 3 | `backup_restore` | **FAIL** | **Blocked, not independently broken:** "All installs failed, therefore the following tests cannot be performed… / Instance is not running." Cascades from Test 2. |
| 4 | `upgrade` (same version) | **FAIL** | Same cascade from Test 2 (no successful install to upgrade). |
| 5 | `upgrade.05e3d5b` (from `v1.0` / `0.8.8-rc3~ynh2`) | **FAIL** | Same cascade from Test 2. |
| 6 | `change_url` | **FAIL** | Same cascade from Test 2 — **and** there is no `scripts/change_url` anyway (expected, deferred to v2 / POLS-02). |

**Expected vs unexpected:**

- `change_url` fail — **expected** (no `scripts/change_url`; v2 / POLS-02 deferred).
- `package_linter` — **passed**; the catalog criticals/errors are metadata-only and non-fatal here.
- `install.root` fail — **unexpected but real**: a package-code bug, not an environment/crash issue. It is
  the single root cause that also (transitively) fails Tests 3–6.
- Tests 3–6 "FAIL" verdicts should **not** be read as four independent package defects in Phase 6; fixing
  Test 2's install bug is the prerequisite to exercising them.

### Headline Phase 6 fix: `admin_panel_session_secret` vs `admin_panel_secret`

A variable-name mismatch makes **every install abort**:

- `scripts/_common.sh:66-67` generates the secret as `admin_panel_secret` and persists it as the setting
  key `admin_panel_secret`.
- `_common.sh:127,131` reads it back as `admin_panel_secret` (consistent with itself).
- `conf/librechat.env:26` uses the placeholder `__ADMIN_PANEL_SESSION_SECRET__`, which YunoHost's
  `_ynh_replace_vars` lowercases to `$admin_panel_session_secret` — **never set anywhere**.

Result: `ynh_config_add --template="librechat.env"` dies inside `_ynh_replace_vars`. Phase 6 must align the
three names (either rename the variable/setting to `admin_panel_session_secret`, or change the template
placeholder to `__ADMIN_PANEL_SECRET__`). A second latent mismatch to check in Phase 6:
`admin_password` is generated (`_common.sh:73-74`) and used by `scripts/install:124`, but is **not** a
template placeholder — verify it is not also referenced by a `__…__` token.

## 4. Crash / timeout check

**No test crashed. No test timed out. No `Critical:` abort. The suite completed and exited 0.**

- Global summary was printed: `Global working time for all tests: 4 minutes, 5 seconds`.
- Every deduced test type reached a verdict banner (`--- SUCCESS ---` / `--- FAIL ---`).
- The VM stayed reachable for the entire run (watchdog active; no eth0 drop).
- The only non-package anomaly was **harness-side, cosmetic**: `lib/analyze_test_results.py` (the summary
  renderer) aborted with `ModuleNotFoundError: No module named 'imgkit'`, so it did not render the
  pass/fail table or populate `results_0.json`. This did **not** affect the run itself (the per-test
  verdicts are emitted by `package_check.sh` and appear in the run log). Classified **environmental**,
  not a package bug — see §5.

## 5. Artifacts

All in `.planning/phases/05-tests-toml-local-package-check-environment/`:

| Artifact | What it is |
|----------|------------|
| `Test_results.log` | Readable run log (de-ANSI'd stdout capture) ending in the Global summary. **Note:** upstream `package_check` does not emit this filename; the header inside records the provenance. |
| `package_check-full.log` | Raw `tee` capture of the run (`~/pc_run.log`), verbatim. |
| `full_log_0.log` | package_check full debug log (187 KB) — the authoritative per-test detail. |
| `results_0.json` | Currently the `imgkit` ModuleNotFoundError traceback (harness renderer aborted before writing JSON). |
| `tests.toml` | Exact copy of the `tests.toml` used (md5 `4cdd83e3b8e13b08c3aac8e5e79ab07d`). |
| `tests-deduction.json` | Parser deduction (05-01) proving the 6-test suite + install args. |
| `tests-dryrun.txt` | `package_check.sh -D` dry-run output (05-01). |
| `env-sanity.txt` | In-VM environment sanity capture (05-02/Task 2). |
| `doc/PACKAGE_CHECK.md` | The reproducible walkthrough for rebuilding this environment. |

### Environment deviations from `doc/PACKAGE_CHECK.md` + `scripts/setup_pc_env.sh` (reproducibility gaps — Phase 6/doc follow-up)

These steps were required to make the run happen but are **not** in the doc/setup script as written. They
must be folded into `doc/PACKAGE_CHECK.md` (and, where sensible, `scripts/setup_pc_env.sh`) so the doc
alone reproduces the environment:

1. **`python3-toml`** — required by package_check's `lib/parse_tests_toml.py` parser. Not installed by the setup script.
2. **Linter Python deps: `python3-jsonschema`, `python3-packaging`, `python3-pyparsing`, `python3-six`** —
   `package_linter` crashed on missing `jsonschema` on the first attempt; these must be installed host-side.
3. **`tmux`** — the doc recommends `tmux`/`nohup` for the long run but the setup script does not install it.
4. **`ethtool`** — used by the NIC watchdog (below).
5. **Image-alias workaround:**
   `incus image copy yunohost:91abc4fc4c43 local: --alias yunohost-bookworm-stable-appci`
   The upstream `yunohost:bookworm-stable-appci` alias does not resolve consistently from the
   simplestreams remote; copying the pinned fingerprint `91abc4fc4c43` to a local alias makes
   package_check's container launch deterministic.
6. **`eth0-watchdog.service` (NIC-flap mitigation)** — an active+enabled systemd unit on the VM that
   auto-uplinks `eth0` and re-runs `dhclient` every 20 s if the NIC flaps. This directly addresses the two
   prior mid-run VM drops (BLOCKER #1/#2) where eth0 went DOWN and never recovered. **Recommend promoting
   this to the doc as a recommended hardening step.**
7. **DHCP IP instability on the host's External switch** — the VM's IP changed from `192.168.1.85` to
   `192.168.1.83` between attempts (host External wired switch hands out DHCP). The doc specifies a
   **static IP**; in practice a DHCP lease was used. A real static IP (or a DHCP reservation) should be
   pinned so the SSH target is stable across runs.
8. **Harness summary renderer (`imgkit`)** — `results_0.json` is unusable without it. Optional for the
   Phase 5 bar (the run log carries the verdicts) but worth documenting; upstream expects
   `pip install imgkit` + `wkhtmltopdf` (`apt install wkhtmltopdf optipng`).

Also worth noting for the doc: `package_check.sh -s` (force-stop) **hung** on the first crashed run and
coincided with the VM going offline; the reliable cleanup is `./package_check.sh -s` followed by
`pkill -f package_check.sh` and removing `~/package_check/pcheck-*.lock` outright.

## 6. Phase 6 handoff

To reach **zero failures (POLS-01)**:

1. **Fix the install-blocking bug** — reconcile `admin_panel_secret` / `admin_panel_session_secret` /
   `__ADMIN_PANEL_SESSION_SECRET__` across `scripts/_common.sh`, `scripts/install` and
   `conf/librechat.env`. This is the single highest-value fix: it unblocks `install.root` and the three
   cascading tests (`backup_restore`, `upgrade`, `upgrade.05e3d5b`).
2. **Re-run and re-triage** Tests 3–6 once install succeeds — their current FAILs are cascades, so their
   true status is unknown until Test 2 passes.
3. **`change_url`** — expected to remain a finding until `scripts/change_url` exists (deferred to v2 /
   POLS-02); confirm whether POLS-01's zero-failure target tolerates this or requires the script.
4. **Decide subpath / private coverage** — nothing auto-generates `install.subdir` / `install.private`; add
   explicitly if POLS-01 requires it.
5. **Consider the linter's catalog items** — `AppCatalog.is_in_catalog` / `state_is_working` /
   `has_category` resolve only after catalog submission / GitHub-org membership; document if these are
   accepted as out-of-scope (they currently do **not** fail `package_linter`).

**Evidence separation:** Phase 6 must archive its **own** zero-failure `package_check` run as POLS-01. This
Phase 5 findings run is deliberately kept separate and is **not** a zero-failure claim.

---

*Phase: 05-tests-toml-local-package-check-environment*
*Run archived: 2026-09-20*
