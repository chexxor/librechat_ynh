# Phase 7: GitHub Actions Lint Workflow - Research

**Researched:** 2026-09-20
**Domain:** GitHub Actions (hosted `ubuntu-latest`) + YunoHost static lint tooling (`package_linter`, `shellcheck`, TOML/schema validation)
**Confidence:** HIGH (worked against the actual schema URL reachable from this dev box, the repo's `manifest.toml`/`tests.toml`/`scripts/*`, and Phase 4's `scripts/run_lint.sh` native invocation now being ported to a CI context)

## Summary

Phase 7 wraps the repo's **already-clean static layer** in a lint-only GitHub Actions workflow (GHCI-01). Every check Phase 7 runs is one the repo already passes locally — Phase 4 proved `package_linter` clean-to-the-accepted-bar, `tests.toml` is schema-valid (Phase 5), and the shell scripts are the Phase 6-verified versions. The workflow therefore starts green; it **adds no new checking power**, only a mechanism to re-run the static layer on each push/PR with an explicit timeout.

The research establishes the concrete mechanics for three parallel jobs and one hard boundary.

## Facets

### 1. `package_linter` (job `package-linter`)
- Tool: `YunoHost/package_linter`, invoked the same way as `scripts/run_lint.sh` but CI-native (no WSL).
- Setup: `git clone --depth 1 https://github.com/YunoHost/package_linter /tmp/pl` then `pip install -r /tmp/pl/requirements.txt` (Python 3.12 via `actions/setup-python`).
- Run from linter cwd (its `.apps` cache path is cwd-relative): `python /tmp/pl/package_linter.py "$GITHUB_WORKSPACE"`.
- **Assert on the text-mode exit code.** The `--json` mode *always* exits 0 (documented in `run_lint.sh:43`) — never use it as the pass gate.
- Known safe behavior confirmed in this repo: with the phase-4-accepted state, text mode exits clean; the 1 critical + 2 errors in the JSON are documented out-of-scope catalog exemptions and do **not** drive a non-zero text exit.
- Network: the linter's catalog checks contact YunoHost upstreams; hosted runners have outbound connectivity, so `AppCatalog.*` checks enumerate normally (and are exempted, not deleted).

### 2. `shellcheck` (job `shellcheck`)
- Install from the official Ubuntu repo: `sudo apt-get update && sudo apt-get install -y shellcheck` (no third-party action; pin by apt lock not needed for a greens-only job).
- Run: `shellcheck scripts/_common.sh scripts/install scripts/remove scripts/upgrade scripts/backup scripts/restore` (all `scripts/*`).
- **Required exclusions:** `SC1090` (can't follow non-constant source) and `SC1091` (can't follow external source) — the scripts `source` YunoHost helpers (`_common.sh`, `ynh_*`, the app's `_common.sh`) that are not present on the runner. These are structural, not defects.
- Keep all other checks enabled; a clean pass over the Phase 6 scripts is expected (they are the already-linted-and-verified production scripts).

### 3. TOML / schema validation (job `toml-schema`)
- Python 3.12 gives stdlib `tomllib` (≥3.11). Parse `manifest.toml` and `tests.toml` for syntax.
- Schema-validate `tests.toml` against its declared schema. The URL is confirmed reachable (verified from this repo's dev box):
  `https://raw.githubusercontent.com/YunoHost/apps/main/schemas/tests.v1.schema.json`
  fetched at workflow runtime and applied with `jsonschema`.
- `manifest.toml` is `packaging_format = 2` (v2 manifest, line 1). Syntax + the v1 tests schema are validated; a full v2 manifest schema URL is **not** required to satisfy GHCI-01 ("TOML/schema validation" for the test file) — note it as an optional future extension, not a blocker.
- A tiny helper `scripts/lint_toml.py` keeps the YAML lean and testable locally (single source of truth for the parse+schema logic).

### 4. Hard boundary — NO `package_check`, NO container build (job set is final)
- A hosted-runner `package_check` is a research-confirmed **anti-feature** (this repo's ROADMAP/REQUIREMENTS/PROJECT "Out of Scope"): it needs privileged LXC/Incus + btrfs, conflicts with Docker, and the LibreChat frontend build OOMs on 7GB runners. The full local suite runs on the Phase 5 Hyper-V VM instead.
- The workflow therefore has **exactly three lint jobs** and nothing else. No `package_check`, no container build, no `GHCI-02` self-hosted-runner wiring (future milestone).

### 5. Triggers & security (green + safe surface)
- `on: push` + `on: pull_request`. Explicitly **no `pull_request_target`** (surprise-surface vector, ROADMAP success criterion 3).
- Top-level `permissions: contents: read` (least privilege). No secrets required; no write permissions.

## Recommendation

Ship a single `.github/workflows/lint.yml` with 3 parallel jobs (`package-linter`, `shellcheck`, `toml-schema`), each with `timeout-minutes: 10`, running the above commands. Add `scripts/lint_toml.py` and — if useful — a `scripts/run_ci_checks.sh` mirror for local parity. Because the repo already passes every check, the workflow is expected green on first push. Commit the planning docs (CONTEXT/RESEARCH/PLAN/SUMMARY) alongside the workflow per the repo's `commit_docs` convention.

---

*Phase: 07-github-actions-lint-workflow*
*Researched: 2026-09-20*
