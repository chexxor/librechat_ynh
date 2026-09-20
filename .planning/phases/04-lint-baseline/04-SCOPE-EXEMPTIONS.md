# Phase 4 — Scope Exemptions (Out-of-Scope Findings)

**Created:** 2026-09-19 (Plan 04-01, Wave 0)
**Status:** Reconciled by Plan 04-04 against the actual post-fix run (`lint-after-fix.json`).

## Purpose

This file defines the phase's zero-error invariant so that the final "zero errors"
claim in Phase 4 is **honest and auditable**. Some findings emitted by
`package_linter` cannot be fixed within Phase 4's scope. Rather than silently
skipping them (which the locked warning-triage policy forbids), each is named
here with a concrete reason and the change that would unblock it.

## Zero-Error Invariant

```
zero_errors_assertion = (critical ∪ error) \ exempted == ∅
```

That is: **zero locally-fixable errors**, minus the documented out-of-scope
findings listed below. The catalog-dependent findings fire solely because the app
is not yet in YunoHost's app catalog, and `tests.toml` is a later phase's
deliverable — both are explicitly out of Phase 4's scope.

## Exempted Findings

| Finding | Bucket | Reason exempt | Unblocked by |
|---|---|---|---|
| `AppCatalog.is_in_catalog` | critical | Catalog submission PR is explicitly out of scope (REQUIREMENTS.md Out of Scope table). Linter treats any uncatalogued app as `invalid` and fails every catalog test. | A future catalog submission PR (post-milestone) |
| `AppCatalog.state_is_working` | error | Same root cause as `is_in_catalog` — sentinel `state="notworking"` for uncatalogued apps. | Same catalog PR |
| `AppCatalog.has_category` | warning | Same root cause — no catalog category without catalog membership. | Same catalog PR |
| `Configurations.tests_toml` | error | `tests.toml` is Phase 5 / CI-01's deliverable; 04-CONTEXT.md phase boundary explicitly says "no tests.toml" in Phase 4. | Phase 5 (CI-01) |
| `Configurations.tests_nginx_reverse_proxy_params_and_sso_consistency` (Upgrade/Connection variant) | warning | Deliberately retained: LibreChat requires `proxy_http_version 1.1` + `Upgrade` + `Connection` for WebSockets/SSE. Never trade a working feature for a linter warning (locked decision 3). The 4 plain `Host`/`X-Real-IP`/`X-Forwarded-*` headers ARE removed in Plan 03. | N/A — permanent design decision (revisit only if `proxy_params_no_auth` is proven to supply WS headers) |

**Exempted count: 1 critical, 2 errors, 1 warning.**

## Not Exempted — Fixed in This Phase

The remaining findings are in scope and are fixed by Plans 02–04. They are listed
here so the full accounting is visible:

### Manifest schema violations (2, reported in the `info` bucket via `validate_schema`)
- `pattern_regexp` unexpected key under `install.admin_email` — replaced with the
  `[install.admin_email.pattern] regexp = ...` object form.
- `format = "script"` invalid enum under `resources.sources.meilisearch` —
  replaced with `format = "whatever"` (+ `extract = false`).

### Warnings (8, all fixed — no deferral per locked policy)
- `Manifest.resource_consistency` — add `init_main_permission` question (or
  define `allowed` for the main permission).
- `Script.progression_in_backup` — replace `ynh_script_progression` with
  `ynh_print_info` in `scripts/backup`.
- `App.badges_in_readme` — regenerate README via the official readme_generator.
- `App.helpers_deprecated_in_v2` ×3 — remove `ynh_abort_if_errors`,
  `ynh_nodejs_install`, `ynh_nodejs_remove` (deprecated in packaging v2/v2.1).
- `Configurations.tests_nginx_reverse_proxy_params_and_sso_consistency` ×2 —
  remove the 4 redundant `Host`/`X-Real-IP`/`X-Forwarded-*` headers. (The
  `Upgrade`/`Connection` variant is exempted above.)

**Locally-fixable-and-fixed count: 2 schema violations + 8 warnings.**

## Baseline Totals

### Before any fix (Plan 04-01, archived as `lint-before-fix.json`)

| Bucket | Count |
|---|---|
| critical | 1 |
| error | 2 |
| warning | 9 |
| info | 7 |

**Exempted count: 1 critical, 2 errors, 1 warning.**
**Locally-fixable-and-fixed count: 2 schema violations + 8 warnings.**

### After all fixes (Plan 04-04, archived as `lint-after-fix.json`)

| Bucket | Count | Delta |
|---|---|---|
| critical | 1 | 0 (the catalog exemption) |
| error | 2 | 0 (catalog + tests.toml exemptions) |
| warning | 2 | −7 (8 warnings fixed; 1 dropped from the before-fix info bucket) |
| info | 5 | −2 (both manifest schema violations resolved) |

Post-fix findings (actual, reconciled):
`critical = ["AppCatalog.is_in_catalog"]`,
`error = ["Configurations.tests_toml", "AppCatalog.state_is_working"]`,
`warning = ["AppCatalog.has_category",
"Configurations.tests_nginx_reverse_proxy_params_and_sso_consistency"]`.

Every remaining critical/error/warning appears in the Exempted table above — no
orphan exemptions, no unexplained findings. `App.badges_in_readme` did not
reappear (README regeneration in Plan 03 cleared it). `Configurations.tests_toml`
and `AppCatalog.state_is_working` remain as documented (`error` bucket), and
`AppCatalog.is_in_catalog` remains as documented (`critical` bucket).

The locally-fixable invariant `(critical ∪ error) \ exempted == ∅` holds — see
the `LOCALLY-FIXABLE-ERRORS-ZERO` assertion in the Plan 04-04 automated verify.
