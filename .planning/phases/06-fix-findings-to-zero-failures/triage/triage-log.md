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
- **Note (supersedes Phase 4):** 04-SCOPE-EXEMPTIONS.md exempted the `Upgrade`/`Connection` linter warning on the condition that `proxy_params_no_auth` be "proven to supply WS headers". The live run now proves it: the include supplies `proxy_http_version 1.1` + `Upgrade` + `Connection`. The Phase 4 exemption is therefore resolved — the directives are removed, removing the warning AND the fatal duplication. Phase 4's historical record is left as-is; this triage log is the authoritative supersession.

---

*Phase: 06-fix-findings-to-zero-failures*
