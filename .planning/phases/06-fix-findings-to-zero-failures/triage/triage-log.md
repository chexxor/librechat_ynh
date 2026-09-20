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

---

*Phase: 06-fix-findings-to-zero-failures*
