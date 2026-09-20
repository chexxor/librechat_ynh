# Phase 4: Lint Baseline - Context

**Gathered:** 2026-09-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Run YunoHost `package_linter` on the package from the Windows dev box (pure Python ≥3.11, no Linux host), fix findings to zero errors, and archive a baseline output showing the clean result. No package_check, no tests.toml, no CI workflow — those are Phases 5–7.

</domain>

<decisions>
## Implementation Decisions

### Warning triage policy
- Errors must reach zero — non-negotiable
- Warnings: fix ALL of them too; no deferral bookkeeping, no known-warnings list
- Modernization allowed and desired: if a check passes but the code doesn't match current YunoHost packaging practices/examples, modernize it (linter-clean is not just "the bar", it's the floor)
- Minimal diffs: fixes touching working code should be small, self-contained edits that satisfy the linter/modernization goal — no rewrites of working logic
- (No warnings will be deferred under this policy, so no deferral sign-off flow is needed; if something genuinely cannot be fixed, it gets surfaced to the user for an explicit decision rather than silently skipped)

### OpenCode's Discretion
- Local runner setup details (venv/pipx, exact Python version pin) — Phase 5 may formalize documentation; Phase 4 just needs a reproducible local run
- Baseline artifact format and location (log file, plain text is fine) as long as it's archived and shows the zero-error result
- Which specific modernization edits to make, within minimal-diff constraint

</decisions>

### Scope resolution (post-research, user-approved 2026-09-19)
- **Zero-error definition = "zero locally-fixable errors"** (Option A). Fix the 2 manifest schema violations and all 9 warnings. The catalog-dependent findings (`AppCatalog.is_in_catalog` critical, `AppCatalog.state_is_working` error, `AppCatalog.has_category` warning) and `Configurations.tests_toml` error are documented as OUT-OF-SCOPE-BY-DESIGN in the baseline artifact, each with a reason:
  - Catalog findings: catalog submission PR is explicitly out of scope (REQUIREMENTS.md Out of Scope table).
  - `tests_toml` error: `tests.toml` is Phase 5 / CI-01's deliverable; CONTEXT phase boundary says "no tests.toml" in Phase 4.
- **"Windows-capable" = WSL2** (already installed on this machine). Bare Windows / Git Bash verified broken (linter shells out to grep/sed/du/file via cmd.exe). WSL2 is not "another Linux host" — it runs on the dev box.
- **nginx headers (Option A):** REMOVE the 4 plain proxy_set_header lines (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) — supplied by `include proxy_params_no_auth`. KEEP `proxy_http_version 1.1`, `Upgrade`, and `Connection` with an inline comment explaining they are deliberately retained for LibreChat WebSockets (accept resident warning, documented). Never trade a working feature for a linter warning.
- **`maintainers` placeholder:** NOT a linter finding, but fix it anyway as hygiene/modernization (use a real GitHub username).
- **Real finding list (empirical): 1 critical, 2 errors, 9 warnings, 7 infos.** See 04-RESEARCH.md.

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Referenced examples: "matches current YunoHost packaging practices/examples" is the modernization yardstick.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-lint-baseline*
*Context gathered: 2026-09-19*
