# Phase 6 — Triage Log (fix → run → triage loop)

This log records every full-suite cycle of Phase 6 and classifies each finding into exactly
one bucket. It is the audit trail for the zero-in-scope-failures claim (POLS-01).

**Doctrine (locked, from 06-CONTEXT.md):**
- Fix all package bugs that block an in-scope test, however many iterations it takes.
- **Full suite every cycle** — no targeted single-test re-runs.
- The final POLS-01 archive must be a **single clean full-suite run** — never a composite of per-test retries.

## In-scope tests

`install.root`, `backup_restore`, `upgrade`, `upgrade.05e3d5b`, `package_linter`.
`change_url` is **exempt** (see `06-SCOPE-EXEMPTIONS.md`).

## Buckets

1. **Package bug (in-scope)** — FAIL/ERROR on an in-scope test → **FIX** (this drives the loop).
2. **Exempt** — `change_url` (POLS-02) or catalog-metadata linter items → **DOCUMENT only** (never fix in Phase 6).
3. **Environment/harness** — a concrete external cause that is not a package defect (apt/CDN/DNS timeout, SSH drop, NIC flap, `imgkit` renderer abort) → **DOCUMENT / optionally re-run**; not a package finding.
4. **Flake** — FAIL with a concrete external cause quoted from the log **AND** passes on re-run **with NO code change** → **DIAGNOSTIC only** (not POLS-01 evidence).

### Flake-vs-regression rule (locked)

```
For a FAIL on an in-scope test:
  1. Search the log for a concrete external cause.
     If NONE -> REGRESSION. Fix it.
  2. If an external cause is present: re-run the FULL suite with NO code change
     (max 2 re-runs total). Pass -> FLAKE. Fail -> REGRESSION.
  Quote the external cause for any flake claim. No cause in the log -> regression.
Environment/harness tweaks (DHCP pinning, watchdog) are permissible between runs but MUST be noted.
```

---

<!-- Per-cycle sections are appended below during execution. -->

## Cycle 0 — 2026-09-20 (Phase 5 baseline, not a Phase 6 run)

- **Source:** `.planning/phases/05-tests-toml-local-package-check-environment/` findings run (4m5s, exit 0).
- **Code state (git rev):** pre-Phase-6.
- **Test verdicts:** `install.root=FAIL`, `backup_restore=FAIL (cascade)`, `upgrade=FAIL (cascade)`, `upgrade.05e3d5b=FAIL (cascade)`, `package_linter=SUCCESS`, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `Variable $admin_panel_session_secret wasn't initialized when trying to replace __ADMIN_PANEL_SESSION_SECRET__` | install.root | Package bug | `Test_results.log:146-148`, `full_log_0.log` | FIX (Plan 06-01 headline) |
  | Cascaded install failure | backup_restore / upgrade / upgrade.05e3d5b | Package bug (cascade) | "All installs failed…" / "Instance is not running" | Re-triage after install.root passes |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |
  | `AppCatalog.is_in_catalog` / `state_is_working` | package_linter | Exempt | Catalog metadata | Document |
  | `imgkit` ModuleNotFoundError (summary renderer) | harness | Environment | `results_0.json` traceback | Document, do not chase |

- **Flake-vs-regression:** no external cause for the install failure — REGRESSION (now fixed in Plan 06-01).

## Cycle 1 — 2026-09-20

- **Run:** `cd ~/package_check && ./package_check.sh ~/librechat_ynh` (VM `alex@192.168.1.83`), duration **4m10s**, exit 0, Global summary printed.
- **Code state (git rev):** `629f7bb` (14 commits after the Phase 5 baseline; includes the Wave-1 headline fix + xtrace guards).
- **Test verdicts:** `install.root=FAIL`, `backup_restore=FAIL (cascade)`, `upgrade=FAIL (cascade)`, `upgrade.05e3d5b=FAIL (cascade)`, `package_linter=SUCCESS`, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `Variable $var wasn't initialized when trying to replace __VAR__ in /var/www/librechat/librechat.env` | install.root | Package bug | `cycles/cycle-1/package_check-full.log:150-151`, `full_log_0.log` | FIX — the env header comment contained a literal `__VAR__`, which `_ynh_replace_vars` parsed as a placeholder token |
  | Cascaded install failure | backup_restore / upgrade / upgrade.05e3d5b | Package bug (cascade) | "Instance is not running" | Re-triage after install.root passes |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |
  | `AppCatalog.is_in_catalog` / `state_is_working` | package_linter | Exempt | Catalog metadata (linter SUCCESS) | Document |
  | `imgkit` summary renderer (`results_0.json` = traceback) | harness | Environment | `results_0.json` 182 bytes | Document; verdicts read from the run log |

- **Progress vs Cycle 0:** the original `__ADMIN_PANEL_SESSION_SECRET__` error is GONE — the headline fix worked. A NEW token bug surfaced: the literal `__VAR__` in the `conf/librechat.env` header comment.
- **Flake-vs-regression:** the `__VAR__` failure has no external cause — REGRESSION. Fixed in the same cycle turn.
- **Fix applied:** rewrote the `conf/librechat.env` header comment to avoid any literal `__TOKEN__`-shaped text. Full-suite re-run required (cycle 2).

---

## Cycle 2 — 2026-09-20

- **Run:** VM full suite, duration **4m30s**, exit 0, Global summary printed.
- **Code state (git rev):** `ccc5623` (includes the cycle-1 `__VAR__` fix).
- **Test verdicts:** `install.root=FAIL`, `backup_restore=FAIL (cascade)`, `upgrade=FAIL (cascade)`, `upgrade.05e3d5b=FAIL (cascade)`, `package_linter=SUCCESS`, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `nginx: "proxy_http_version" directive is duplicate in /etc/nginx/proxy_params_no_auth:12` → nginx reload fails → install aborts | install.root | Package bug | `cycles/cycle-2/package_check-full.log` (error at 150334), `full_log_0.log` | FIX — remove the duplicated `proxy_http_version`/`Upgrade`/`Connection` directives from `conf/nginx.conf`; `proxy_params_no_auth` already supplies them |
  | Cascaded install failure | backup_restore / upgrade / upgrade.05e3d5b | Package bug (cascade) | "Instance is not running" | Re-triage after install.root passes |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |
  | `imgkit` summary renderer | harness | Environment | `results_0.json` | Document |

- **Progress vs Cycle 1:** the `__VAR__` token error is GONE. New bug: nginx duplicate directive. Install now reaches nginx configuration (much further than before).
- **Flake-vs-regression:** the duplicate directive is deterministic — REGRESSION. Fixed in the same cycle turn.
- **Fix applied:** `conf/nginx.conf` — removed `proxy_http_version 1.1;`, `proxy_set_header Upgrade ...`, `proxy_set_header Connection ...` (all supplied by `include proxy_params_no_auth`). Kept `proxy_buffering off` / `proxy_cache off` (SSE, not in the include).
- **Note (supersedes Phase 4):** 04-SCOPE-EXEMPTIONS.md exempted the `Upgrade`/`Connection` linter warning on the condition that `proxy_params_no_auth` be "proven to supply WS headers". The live run now proves it (the include supplies `proxy_http_version 1.1` + `Upgrade` + `Connection`). Removing the duplicates resolves the warning AND the fatal duplication. Phase 4's historical record is left as-is; this triage log is the authoritative supersession.

---

## Cycle 3 — 2026-09-20

- **Run:** VM full suite, duration **4m29s**, exit 0, Global summary printed.
- **Code state (git rev):** `f1242c9` (includes the cycle-2 nginx fix).
- **Test verdicts:** `install.root=FAIL`, `backup_restore=FAIL (cascade)`, `upgrade=FAIL (cascade)`, `upgrade.05e3d5b=FAIL (cascade)`, `package_linter=SUCCESS`, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `Error: Please define the MONGO_URI environment variable` (thrown in `/var/www/librechat/api/db/connect.js:11`) during **Step 10 — Creating admin user** | install.root | Package bug | `cycles/cycle-3/package_check-full.log:155,167,176` | FIX — `librechat_create_admin_user` must load `librechat.env` before running `create-user.js` |
  | Cascaded install failure | backup_restore / upgrade / upgrade.05e3d5b | Package bug (cascade) | "All installs failed…" | Re-triage after install.root passes |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |
  | `imgkit` summary renderer | harness | Environment | `results_0.json` | Document |

- **Progress vs Cycle 2:** nginx duplicate-directive error GONE (install now configures nginx, starts services, and reaches admin-user creation). Root cause of the new failure: `config/create-user.js` → `api/db/connect.js` calls `require('dotenv').config()`, which loads a file literally named `.env`; our managed file is `librechat.env`, so `MONGO_URI` is unset and connect.js throws.
- **Flake-vs-regression:** deterministic — REGRESSION. Fixed in the same cycle turn.
- **Fix applied:** `librechat_create_admin_user` now runs `bash -c 'set -a; . ./librechat.env; set +a; exec node config/create-user.js "$@"'` as `$app` in `$install_dir`, so the app-owned env file (chmod 600) is sourced into node's environment.

---

## Cycle 4 — 2026-09-20

- **Run:** VM full suite, duration **4m31s**, exit 0, Global summary printed.
- **Code state (git rev):** `9ce46fc` (includes the cycle-3 env-sourcing fix).
- **Test verdicts:** `install.root=FAIL`, `backup_restore=FAIL (cascade)`, `upgrade=FAIL (cascade)`, `upgrade.05e3d5b=FAIL (cascade)`, `package_linter=SUCCESS`, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `MongoServerError: Authentication failed` (code 18) during **Step 10 — Creating admin user** | install.root | Package bug | `cycles/cycle-4/package_check-full.log:152` | FIX — the Mongo password was read from the wrong setting key |
  | Cascaded install failure | backup_restore / upgrade / upgrade.05e3d5b | Package bug (cascade) | "All installs failed…" | Re-triage after install.root passes |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |
  | `imgkit` summary renderer | harness | Environment | `results_0.json` | Document |

- **Progress vs Cycle 3:** the `MONGO_URI unset` error is GONE (env now loads into the create-user process). New failure: Mongo auth rejected.
- **Root cause:** YunoHost helpers v2.1 `ynh_mongo_setup_db` stores the generated password under the setting key **`db_pwd`** (verified against `/usr/share/yunohost/helpers.v2.1.d/mongodb` in a container), but our scripts read **`mongopwd`** — a key that is never set. So `MONGO_URI` had an empty password → auth failed. `mongopwd` does not appear anywhere in `/usr/share/yunohost/`.
- **Flake-vs-regression:** deterministic — REGRESSION. Fixed in the same cycle turn.
- **Fix applied:** replaced `ynh_app_setting_get --key=mongopwd` with `--key=db_pwd` in `scripts/install`, `scripts/upgrade`, and `scripts/_common.sh` (3 sites; 0 `mongopwd` references remain in `scripts/`).

---

## Cycle 5 — 2026-09-20

- **Run:** VM full suite, duration **4m43s**, exit 0, Global summary printed.
- **Code state (git rev):** `f01a3c5` (includes the cycle-4 `db_pwd` fix).
- **Test verdicts:** `install.root=FAIL (harness)`, `backup_restore=FAIL (cascade)`, `upgrade=FAIL (cascade)`, `upgrade.05e3d5b=FAIL (cascade)`, `package_linter=SUCCESS`, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | **Package install SUCCEEDED** (`Installation completed`, admin password displayed, admin user created) | install.root | — (milestone) | `cycles/cycle-5/package_check-full.log:151268,151881` | None — the package install path is now correct end-to-end |
  | `ModuleNotFoundError: No module named 'bs4'` in `lib/curl_tests.py:8` (harness post-install URL/asset validation) | install.root | Environment/harness | `cycles/cycle-5/package_check-full.log:162` | FIX ENV — install `beautifulsoup4` (+ `lxml`, `imgkit`) from `package_check/requirements.txt`; these were never installed by `setup_pc_env.sh` |
  | Cascaded install failure | backup_restore / upgrade / upgrade.05e3d5b | Package bug (cascade) | "All installs failed…" | Re-triage after install.root passes (install now succeeds → cascades should clear next cycle) |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |

- **Progress vs Cycle 4:** MongoDB auth error GONE. **The package now installs successfully** — the `curl_tests` post-install validation is the only remaining blocker on `install.root`, and it is a harness dependency gap, not a package defect.
- **Environment fix (permitted, noted per locked rule):** `pip3 install --break-system-packages --user beautifulsoup4 lxml imgkit` on the VM. `package_check/requirements.txt` lists `toml pycurl beautifulsoup4 lxml imgkit`; `setup_pc_env.sh` only installed `python3-toml` (and the linter deps), missing `beautifulsoup4`/`lxml`/`imgkit`. This supersedes/completes the Phase 5 `imgkit` gap (#8 in 05-FINDINGS.md §5).
- **Flake-vs-regression:** the `bs4` failure is a deterministic environment gap (no package code involved) — fixed by installing the missing dependency; the run after the *package* code (`db_pwd`) change is cycle 5, and the harness fix is a no-package-change environment tweak.

---

## Cycle 6 — 2026-09-20

- **Run:** VM full suite, duration **5m43s**, exit 0, Global summary printed.
- **Code state (git rev):** `4915d3a` (no package change since cycle 5; harness `bs4`/`lxml`/`imgkit` installed on the VM).
- **Test verdicts:** `install.root=FAIL`, `backup_restore=FAIL (cascade)`, `upgrade=FAIL (cascade)`, `upgrade.05e3d5b=FAIL (cascade)`, `package_linter=SUCCESS`, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | Install succeeds; service running; `Server listening at http://localhost:3080`; but URL check gets **502 Bad Gateway** (expected 200) | install.root | Package bug | `cycles/cycle-6/package_check-full.log` (`Code: 502`, expected 200) | FIX — `HOST=localhost` binds `::1`; nginx proxies `127.0.0.1` → refused |
  | `warn: [credentials] No configured value was found for CREDS_KEY, CREDS_IV … temp` | install.root | Info (non-fatal) | node log | Document; LibreChat generates temp credentials — not a failure |
  | `Outdated Config version: 1.1.1 / Latest version: 1.3.16` | install.root | Info (non-fatal) | node log | Document; informational from `librechat.yaml` version |
  | Cascaded install failure | backup_restore / upgrade / upgrade.05e3d5b | Package bug (cascade) | "All installs failed…" | Re-triage after install.root passes |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |

- **Progress vs Cycle 5:** the `bs4` harness error is GONE (curl_tests now execute). **Install fully succeeds** and the app is live; the only failure is the HTTP-level 502.
- **Root cause (verified):** on the container/VM, `getent hosts localhost` resolves **`::1` first**, then `127.0.0.1`. Node's `listen(port, 'localhost')` binds the first result (`::1`, IPv6). nginx's `proxy_pass http://127.0.0.1:__PORT__` targets IPv4 → connection refused → 502.
- **Flake-vs-regression:** deterministic — REGRESSION. Fixed in the same cycle turn.
- **Fix applied:** `conf/librechat.env` `HOST=localhost` → `HOST=127.0.0.1`, so the bind matches the nginx proxy target.

---

## Cycle 7 — 2026-09-20

- **Run:** VM full suite, duration **14m26s**, exit 0, Global summary printed.
- **Code state (git rev):** `cc4bec2` (includes the cycle-6 `HOST` fix).
- **Test verdicts:** `install.root=`**`SUCCESS`** ✓, `backup_restore=FAIL`, `upgrade=FAIL`, `upgrade.05e3d5b=FAIL`, `package_linter=SUCCESS` ✓, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | **`install.root` SUCCESS** — package installs and serves 200 | install.root | — (milestone) | `cycles/cycle-7/package_check-full.log:267` | None |
  | `WARNING Invalid argument: --wait_until_running` → `Failed to collect files to be backed up` | backup_restore | Package bug | `cycles/cycle-7/full_log_0.log:5523`, `package_check-full.log:283-285` | FIX — `ynh_systemctl` (helpers v2.1) has no `--wait_until_running` arg |
  | `Failed to start server: Authentication failed` after upgrade — `ynh_mongo_setup_db` regenerated a new `db_pwd` while the Mongo user kept the old password | upgrade | Package bug | `cycles/cycle-7/full_log_0.log:3963-4041` (new password `Xz4HWdji…` stored) | FIX — pass the persisted `db_pwd` into `ynh_mongo_setup_db` on upgrade |
  | Cascaded upgrade-from-old failure | upgrade.05e3d5b | Package bug (cascade from Test 4) | install/upgrade machinery | Re-triage after upgrade passes |
  | No `scripts/change_url` | change_url | Exempt | Definitional | Document (POLS-02) |

- **Progress vs Cycle 6:** the 502 error is GONE. **`install.root` now passes** — the original goal of unblocking install is fully achieved. Tests 3–5 executed for the first time (no more "All installs failed" cascade for install).
- **Root causes (both verified from `full_log_0.log`):**
  1. **backup/restore:** `ynh_systemctl --service=meilisearch --action=start --wait_until_running --timeout=300` → the v2.1 helper rejects `--wait_until_running` and the backup aborts. (`scripts/backup:73`, `scripts/restore:95`.)
  2. **upgrade:** `ynh_mongo_setup_db` with no `--db_pwd` generates a NEW password (`Xz4HWdjiYym83AxJp54QD4EQ`), stores it as the `db_pwd` setting, and calls `db.createUser` — which fails because the user exists, leaving the real password at the original value. The env then contains the new (wrong) password → auth failure.
- **Flake-vs-regression:** both deterministic — REGRESSIONS. Fixed in the same cycle turn.
- **Fixes applied:**
  - `scripts/upgrade`: read persisted `db_pwd` BEFORE `ynh_mongo_setup_db` and pass `--db_pwd="$db_pwd"` (idempotent; session/secret consistency preserved).
  - `scripts/backup`, `scripts/restore`: dropped the unsupported `--wait_until_running --timeout=300` from the meilisearch start (kept `--action=start`).

---

## Cycle 8 — 2026-09-20

- **Run:** VM full suite, duration **12m30s**, exit 0, Global summary printed. (VM NIC flapped mid-run and the IP moved `.83`→`.85`; `eth0-watchdog` restored it and the run still completed — environmental, noted, no code change.)
- **Code state (git rev):** `3107b60` (includes the cycle-7 mongo/systemctl fixes).
- **Test verdicts:** `install.root=`**`SUCCESS`** ✓, `backup_restore=FAIL`, `upgrade=`**`SUCCESS`** ✓, `upgrade.05e3d5b=FAIL`, `package_linter=SUCCESS` ✓, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `upgrade` SUCCESS — mongo idempotency fix worked | upgrade | — (milestone) | `cycles/cycle-8/package_check-full.log:482` | None |
  | `meilisearch: error: unexpected value 'true' for '--no-analytics'` → service fails to start → `Failed to collect files to be backed up` | backup_restore | Package bug | `cycles/cycle-8/package_check-full.log:1921-1938,2525` | FIX — meilisearch v1.53.2 wants `--no-analytics` with no value |
  | `fatal: not a git repository … Failed to checkout commit 05e3d5b` | upgrade.05e3d5b | Environment (sync method) | `cycles/cycle-8/package_check-full.log:497` | FIX ENV — the app dir on the VM must be a git clone (package_check checks out the old commit) |
  | `The app 'librechat' doesn't support URL modification yet` | change_url | Exempt | `cycles/cycle-8/package_check-full.log:515` | Document (POLS-02) |

- **Progress vs Cycle 7:** `upgrade` (same-version) now passes. Remaining: `backup_restore` (meilisearch flag bug) and `upgrade.05e3d5b` (git-repo sync requirement).
- **Flake-vs-regression:** the meilisearch flag bug is deterministic — REGRESSION. The git-repo message is a deterministic harness requirement (not a package defect). The mid-run IP flap is an external cause; the run completed anyway so no retry was needed.
- **Fixes applied:**
  - `conf/meilisearch.service`: `--no-analytics=true` → `--no-analytics`.
  - Environment: sync the package to the VM as a real git clone so `git checkout 05e3d5b` works (see next cycle).

---

## Cycle 9 — 2026-09-20

- **Run:** VM full suite (git clone at `e336a6d`), duration **14m11s**, exit 0, Global summary printed. (VM NIC flapped again mid-run `.85`→`.83`; watchdog restored it; run completed — environmental, no code change.)
- **Code state (git rev):** `e336a6d` (includes the cycle-8 meilisearch flag fix) + real git clone on the VM.
- **Test verdicts:** `install.root=`**`SUCCESS`** ✓, `backup_restore=FAIL`, `upgrade=`**`SUCCESS`** ✓, `upgrade.05e3d5b=FAIL`, `package_linter=SUCCESS` ✓, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `meilisearch: error=Permission denied (os error 13)` — service fails to start on backup restart → `Failed to collect files` | backup_restore | Package bug | `cycles/cycle-9/package_check-full.log:288-350` | FIX — install must pre-create `$data_dir/meilisearch` (owned by `$app`); otherwise `ReadWritePaths` cannot grant write access under `ProtectSystem=full` |
  | `While parsing manifest: pattern_regexp extra fields not permitted` on the OLD commit | upgrade.05e3d5b | **BLOCKER — conflicts with frozen tests.toml** | `cycles/cycle-9/package_check-full.log:518` | The `test_upgrade_from.05e3d5b` target's manifest predates Phase 4's schema fix; it is not installable on modern YunoHost. Escalated (see checkpoint). |
  | `The app 'librechat' doesn't support URL modification yet` | change_url | Exempt | `cycles/cycle-9/package_check-full.log:536` | Document (POLS-02) |

- **Progress vs Cycle 8:** the `--no-analytics=true` error is GONE (meilisearch flag fix worked). The git-checkout error is GONE (real clone). New meilisearch failure is a data-dir permission issue. `upgrade` (same-version) passes again.
- **Flake-vs-regression:** the meilisearch permission error is deterministic — REGRESSION. The `05e3d5b` manifest parse error is deterministic and definitionally about the old commit's content (not our current package).
- **Fixes applied:** `scripts/install` pre-creates `$data_dir/meilisearch` owned by `$app` (mirrors the existing `$install_dir/logs` pattern).

---

## CHECKPOINT RESOLVED — 2026-09-20 (user decision)

**Decision (Option A):** `upgrade.05e3d5b` is **out-of-scope-by-design**. The v1.0 release artifact
(commit `05e3d5b` / `0.8.8-rc3~ynh2`) predates the Phase 4 manifest schema fix (`48a3614`) and cannot
install on YunoHost >= 12.1.40 (`pattern_regexp extra fields not permitted`); no genuine released
artifact predating the fix is installable. Upgrade-from coverage is deferred until a post-fix release
is tagged. `tests.toml` stays frozen.

**Revised zero-failure bar:** 4 in-scope tests — `package_linter`, `install.root`, `backup_restore`,
`upgrade` (same version). Exempt: `change_url` (POLS-02) and `upgrade.05e3d5b` (uninstallable ancestor).

Recorded in `06-SCOPE-EXEMPTIONS.md` and `06-CONTEXT.md` (resolved note). Continue cycles until the 4
in-scope tests are all SUCCESS in a single clean full-suite run.

---

## Cycle 10 — 2026-09-20

- **Run:** VM full suite, duration **15m14s**, exit 0, Global summary printed.
- **Code state (git rev):** `d9c7537` (cycle-9 data-dir pre-create included; ProtectHome fix NOT yet applied).
- **Test verdicts:** `install.root=SUCCESS` ✓, `backup_restore=FAIL`, `upgrade=SUCCESS` ✓, `upgrade.05e3d5b=FAIL (exempt)`, `package_linter=SUCCESS` ✓, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `meilisearch: error=Permission denied (os error 13)` at service start → `Failed to collect files to be backed up` | backup_restore | Package bug | `cycles/cycle-10/package_check-full.log:364-385` | FIX — candidate: remove `ProtectHome=yes` from the unit (hides `/home`) |
  | `pattern_regexp extra fields not permitted` on the old commit | upgrade.05e3d5b | Exempt | `cycles/cycle-10/package_check-full.log:493-496` | Document (see CHECKPOINT RESOLVED) |
  | `The app 'librechat' doesn't support URL modification yet` | change_url | Exempt | `cycles/cycle-10/package_check-full.log:534` | Document (POLS-02) |

- **Progress:** 3/4 in-scope green after this cycle (`backup_restore` is the last blocker).
- **Flake-vs-regression:** deterministic — REGRESSION.
- **Fix applied:** removed `ProtectHome=yes` from `conf/meilisearch.service` (commit `a05ca07`).

## Cycle 11 — 2026-09-20

- **Run:** VM full suite, duration **14m50s**, exit 0, Global summary printed.
- **Code state (git rev):** `a05ca07` (ProtectHome removal included).
- **Test verdicts:** `install.root=SUCCESS` ✓, `backup_restore=FAIL`, `upgrade=SUCCESS` ✓, `upgrade.05e3d5b=FAIL (exempt)`, `package_linter=SUCCESS` ✓, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `meilisearch: error=Permission denied (os error 13)` STILL occurs at service start | backup_restore | Package bug | `cycles/cycle-11/package_check-full.log` | ProtHome was NOT the cause. Root-caused by an isolated in-container reproduction (below). |
  | `pattern_regexp extra fields not permitted` | upgrade.05e3d5b | Exempt | full_log | Document |
  | URL modification unsupported | change_url | Exempt | full_log | Document |

- **Root cause (proven by controlled repro, `meilitest2` container):** Meilisearch v1.53.2 creates its `dumps/` directory **relative to the process CWD**. The unit set no `WorkingDirectory`, so CWD = `/` — unwritable by the `librechat` user → `EACCES` → service dies. `strace` showed `mkdir("dumps/", 0777) = -1 EACCES` and `openat("./config.toml") = -1 EACCES`. Running as **root** (writable `/`) worked; running as `librechat` failed on **every** db-path (`/home/yunohost.app/...`, `/var/lib/...`), proving the data dir was never the problem. Adding `WorkingDirectory=<writable dir>` made the hardened unit (`ProtectSystem=full` + `ReadWritePaths`) start `active`.
- **Flake-vs-regression:** deterministic — REGRESSION.
- **Fix applied:** `conf/meilisearch.service` — added `WorkingDirectory=__DATA_DIR__` (commit `fe84e10`). Also keeps the earlier `ProtectHome` removal (harmless, correct).

## Cycle 12 — 2026-09-20

- **Run:** VM full suite, duration **14m50s**, exit 0, Global summary printed. (VM NIC flapped `.83`→`.85` mid-run; `eth0-watchdog` restored it; run completed. Environmental, no code change.)
- **Code state (git rev):** `fe84e10` (WorkingDirectory fix included).
- **Test verdicts:** `install.root=SUCCESS` ✓, `backup_restore=FAIL`, `upgrade=SUCCESS` ✓, `upgrade.05e3d5b=FAIL (exempt)`, `package_linter=SUCCESS` ✓, `change_url=FAIL (exempt)`.
- **Findings table:**

  | Finding | Test | Bucket | Evidence | Action |
  |---|---|---|---|---|
  | `Failed to start server: Authentication failed.` after restore (LibreChat → Mongo) | backup_restore | Package bug | `cycles/cycle-12/package_check-full.log:355,369,428,442` | FIX — restore must recreate the mongo user |
  | URL modification unsupported | change_url | Exempt | full_log | Document |

- **Progress:** the meilisearch `Permission denied` error is **GONE** (0 occurrences) — WorkingDirectory fix worked. Backup now completes; the remaining failure is post-restore LibreChat Mongo auth.
- **Root cause:** `mongodump --db` (via `ynh_mongo_dump_db`) does **not** dump database users. On restore to a fresh MongoDB the app user is absent, so the restored `librechat.env` credentials are rejected. (Same class as the cycle-7 upgrade password bug.)
- **Flake-vs-regression:** deterministic — REGRESSION.
- **Fix applied:** `scripts/restore` — read the persisted `db_pwd` setting and call `ynh_mongo_setup_db --db_pwd="$db_pwd"` (idempotent) before `ynh_mongo_restore_db` (commit `1be66f5`).

---

*Phase: 06-fix-findings-to-zero-failures*
