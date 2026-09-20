# Phase 6: Fix Findings to Zero Failures - Context

**Gathered:** 2026-09-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix package bugs until the full local `package_check` suite shows **zero failures** across its in-scope tests, then archive that single clean run as live verification of POLS-01. The phase is an **iterative fix → run → triage loop** on the environment from Phase 5. No new capabilities (no `change_url` script — v2/POLS-02), no suite expansion (no `[install.path]` / subpath / private coverage), no GitHub Actions workflow (Phase 7). The suite is frozen at the 6 deduced tests.

</domain>

<decisions>
## Implementation Decisions

### Zero-failure definition (the bar)
- **In-scope tests must all reach SUCCESS:** `install.root`, `backup_restore`, `upgrade`, `upgrade.05e3d5b`, and `package_linter` (test-level, not its report contents).
- **`change_url` is exempt** — it FAILs because `scripts/change_url` does not exist (deferred v2 / POLS-02). A `change_url` FAIL does **not** violate the zero-failure bar. Document it as out-of-scope-by-design.
- **Catalog-metadata linter items are out-of-scope:** the 1 critical + 1 error (`AppCatalog.is_in_catalog`, `AppCatalog.state_is_working`) resolve only on catalog submission / GitHub-org membership — document them with a reason, parallel to Phase 4's `04-SCOPE-EXEMPTIONS.md` precedent. They do not fail `package_linter` and must not block the bar.
- **Mechanical determination of "zero failures":** trust the suite's own per-test verdict banners **and** a package_check exit code of `0`. Zero in-scope test shows `FAIL`/`ERROR`; `change_url` may show FAIL and is excluded by policy.
- **The bar applies to the current 6-test deduced suite exactly as-is.** Broadening coverage is not part of this phase.

### change_url & coverage additions
- `change_url`: **leave it FAILing and document the deferral** (POLS-02, v2). Do **not** add exclusion to `tests.toml` — no "fake green", consistent with Phase 5's no-`exclude` stance.
- Subpath/private/multi coverage: **leave as-is.** No `[install.path]` question, no manifest change, no explicit extra suite. `install.subdir` / `install.private` stay uncovered by design; `install.multi` stays skipped (`multi_instance = false`).
- **`tests.toml` is frozen** for Phase 6 — no changes that alter which tests run. No non-coverage tuning either.
- **Where documented:** a dedicated **Phase 6 scope-exemption record** in the phase directory (analogous to `04-SCOPE-EXEMPTIONS.md`) capturing: `change_url` deferral (POLS-02), catalog-metadata linter exemptions, and the uncovered subpath/private tests.

### Fixing scope & discovery
- **Fix all package bugs that block an in-scope test**, however many iterations it takes — zero failures is the milestone deliverable. Tests 3–6 currently FAIL only as cascades from the install bug, so their true status is unknown until `install.root` passes — expect new findings.
- **Sequencing: iterative fix → run → triage loop.** One fix set, re-run the suite, triage new findings, repeat until zero in-scope failures. Each cycle costs ~4–5 min of VM suite time; that cost is accepted.
- **Full suite every cycle** (not targeted single-test re-runs) — avoids an earlier test masking later ones. No exception for speed.
- **`change_url`-traced failures stay exempt** — if a new failure is definitionally "the script doesn't exist", it is covered by the exemption; do not implement the script to satisfy it.
- **Environment/harness-side issues** (e.g. the `imgkit` summary-renderer abort) are not package bugs: document them, don't chase them as package defects.

### Secret-logging audit
- **Audit the archived run logs for real secret values** (`full_log_0.log`, `package_check-full.log`, `Test_results.log`) — real values, not just placeholder names. The Phase 5 debug log already contains real generated secrets (e.g. `admin_panel_secret=…`, `admin_password=…`) because install runs under `set -x`.
- **Fix the package to stop leaking secrets:** remove/mask secret prints in scripts and avoid exposing secret values via `set -x`/debug output. This is the real risk, not a cosmetic one.
- **Keep the one-time admin-password display** at end of install (operator needs it to log in) — it is operationally necessary; just ensure it is not duplicated into debug/xtrace output.
- **Archive redacted logs** as POLS-01 evidence: fix prints **and** archive redacted logs (mask any residual secret values) so the evidence itself is clean.

### Flake-vs-regression policy
- **Bounded retries: up to 2 re-runs** of the full suite for a failure on non-deterministic grounds; a persistent failure after retries is a regression to fix.
- **Evidence-based flake classification:** a failure is a flake only if (a) the log shows a concrete external cause (SSH drop, apt/CDN timeout, DNS/network error, VM NIC flap), **and** (b) it passes on re-run **with no code change**. Otherwise it is a regression. Record the distinction in the phase record (honest flake-vs-regression evidence).
- **Final POLS-01 archive = a single clean full-suite run** with zero in-scope failures — **not** a composite of per-test retries. Retries are diagnostic only.
- **No code change between retries** to count as a flake; any code change means it is a regression fix, and the run after the change is the new evidence. (Non-code environment/harness tweaks — e.g. DHCP pinning, watchdog — are permissible and must be noted.)

### OpenCode's Discretion
- Exact masking/redaction technique for logs and script output.
- Precise triage workflow mechanics (how findings are logged between cycles).
- Structure/naming of the Phase 6 scope-exemption record and the archived POLS-01 artifacts.
- Whether to fold the 8 reproducibility gaps from `05-FINDINGS.md` §5 into `doc/PACKAGE_CHECK.md` / `scripts/setup_pc_env.sh` now or note as follow-up (not a package fix).

</decisions>

<specifics>
## Specific Ideas

- The headline fix: reconcile `scripts/_common.sh` (generates/persists `admin_panel_secret`) with `conf/librechat.env:26` (`__ADMIN_PANEL_SESSION_SECRET__`, which `_ynh_replace_vars` lowercases to the never-set `$admin_panel_session_secret`). A second latent mismatch to verify: `admin_password` is generated (`_common.sh:73-74`) and used by `scripts/install:124`, but is **not** a template placeholder — confirm no `__…__` token references it.
- "Zero failures" means zero **in-scope** failures — `change_url` FAIL is tolerated by explicit policy, documented in the phase exemption record.
- POLS-01 evidence must be a **single clean run**, and its archive must be **redacted** of secret values.
- Phase 5 evidence (`05-FINDINGS.md`, `Test_results.log`, `package_check-full.log`) is deliberately separate and is **not** a zero-failure claim — Phase 6 archives its **own** run.

</specifics>

<deferred>
## Deferred Ideas

- **`change_url` script** — v2 / POLS-02; leave FAILing and document (do not implement in Phase 6).
- **Subpath / private install coverage** (`[install.path]`, explicit private suite) — future phase; suite stays frozen.
- **Catalog submission PR** (`AppCatalog.is_in_catalog` / `state_is_working` / `has_category`) — separate process, documented out-of-scope.
- **8 reproducibility gaps** (`05-FINDINGS.md` §5: `python3-toml`, linter Python deps, `tmux`, `ethtool`, image-alias workaround, `eth0-watchdog`, DHCP instability, `imgkit`) — fold into `doc/PACKAGE_CHECK.md` / `scripts/setup_pc_env.sh`; not package fixes.
- **Multi-instance support** — POLS-03, blocked by single-instance Meilisearch wiring; out of scope.
- **Full package_check on GitHub-hosted runners** — anti-feature; self-hosted runner is GHCI-02, a future milestone.

</deferred>

---

*Phase: 06-fix-findings-to-zero-failures*
*Context gathered: 2026-09-20*
