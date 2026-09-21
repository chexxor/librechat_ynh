# Phase 6 — Scope Exemptions (Out-of-Scope-by-Design Findings)

**Created:** 2026-09-20 (Plan 06-01, Wave 1)
**Status:** Authoritative for Phase 6's zero-failure claim. Kept in sync with triage cycles.

## Purpose

This file defines the phase's **zero-failure invariant** so that the final "zero failures"
claim for POLS-01 is **honest and auditable**. Some findings emitted by `package_check`
cannot be resolved within Phase 6's scope. Rather than silently skipping them (which would
be "fake green"), each is named here with a concrete reason and the change that would unblock it.

This mirrors the Phase 4 precedent (`.planning/phases/04-lint-baseline/04-SCOPE-EXEMPTIONS.md`).

## Zero-Failure Invariant

```
in_scope_tests = { package_linter, install.root, backup_restore, upgrade }
zero_failures_assertion =
    (every test in in_scope_tests shows SUCCESS in the suite's per-test verdict banners)
    AND (package_check exit code == 0)
    AND (the run completed with a Global summary — no Critical abort, crash, or timeout)
```

`change_url` and `upgrade.05e3d5b` are **excluded from the in-scope set by policy**
(see the Exempted Findings table below). Their FAILs do not violate the invariant.
Catalog-metadata linter items do not fail `package_linter` and are likewise excluded.

> **Note (resolved during execution, 2026-09-20):** The bar was originally set to 5 in-scope
> tests including `upgrade.05e3d5b`. Live execution proved that target uninstallable on modern
> YunoHost (its release predates the Phase 4 manifest fix). Per the user's decision at the
> Phase 6 execution checkpoint, `upgrade.05e3d5b` is exempted out-of-scope-by-design and the
> bar is **4 in-scope tests**. `tests.toml` is unchanged.

## Exempted Findings

| Finding | Bucket | Reason exempt | Unblocked by |
|---|---|---|---|
| `change_url` FAIL | test (exempt) | `scripts/change_url` does not exist. Deferred to v2 / POLS-02 (REQUIREMENTS.md v2). A `change_url`-traced failure is definitionally "the script doesn't exist". | Implementing `scripts/change_url` (POLS-02, out of Phase 6 scope) |
| `AppCatalog.is_in_catalog` | linter critical | Catalog submission PR is explicitly out of scope (REQUIREMENTS.md Out of Scope). Linter treats an uncatalogued app as `invalid`. | A future catalog submission PR (post-milestone) |
| `AppCatalog.state_is_working` | linter error | Same root cause as `is_in_catalog` — sentinel `state="notworking"` for uncatalogued apps. | Same catalog PR |
| `AppCatalog.has_category` | linter warning | Same root cause — no catalog category without catalog membership. | Same catalog PR |
| `upgrade.05e3d5b` FAIL | test (exempt) | The v1.0 release artifact (commit `05e3d5b` / `0.8.8-rc3~ynh2`) predates the Phase 4 manifest schema fix (`48a3614`) and cannot install on YunoHost >= 12.1.40 (`pattern_regexp extra fields not permitted`). No genuine released artifact predating the fix is installable. Upgrade-from coverage is deferred until a post-fix release is tagged. `tests.toml` stays frozen. | Tagging a post-manifest-fix release and re-targeting `test_upgrade_from` (future phase) |
| Uncovered `install.subdir` | coverage | LibreChat has no `[install.path]` question; package_check treats it as a full-domain/domain-root app and does not generate `install.subdir`. | Adding `[install.path]` (future phase; suite frozen for Phase 6) |
| Uncovered `install.private` | coverage | The parser never auto-generates a private-install suite. | An explicit extra suite (future phase; suite frozen for Phase 6) |
| Skipped `install.multi` | coverage | `multi_instance = false` in `manifest.toml` (single-instance Meilisearch wiring). | POLS-03 (multi-instance support) |

**Exempted: 2 tests (`change_url`, `upgrade.05e3d5b`), 1 critical + 1 error + 1 warning (catalog metadata), 3 uncovered test types.**

## Not Exempted — Fixed in This Phase

In-scope package bugs are recorded and fixed through the fix→run→triage loop (see
`triage/triage-log.md`). The headline fix (Plan 06-01) is the `admin_panel_secret` /
`__ADMIN_PANEL_SESSION_SECRET__` token mismatch that aborted `install.root` and cascaded to
`backup_restore`, `upgrade`, and `upgrade.05e3d5b`.

## Policy Notes

- **No `exclude` in `tests.toml`** (never use `exclude` to fake green). `tests.toml` is frozen for Phase 6.
- **`change_url` is left FAILing** and documented here — not suppressed, not "fixed" by adding the script.
- **Catalog items are documented**, not worked around.

## Evidence Separation

Phase 6 archives its **own** single clean `package_check` run as POLS-01 live verification
(`pols-01-evidence/`). The Phase 5 findings run (`.planning/phases/05-…/05-FINDINGS.md`,
`Test_results.log`) is deliberately kept separate and is **not** a zero-failure claim.

---

*Phase: 06-fix-findings-to-zero-failures*
