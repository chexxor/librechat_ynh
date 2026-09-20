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
