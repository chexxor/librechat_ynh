# Phase 7: GitHub Actions Lint Workflow - Context

**Gathered:** 2026-09-22
**Status:** Ready for planning

<domain>
## Phase Boundary

A lint-only GitHub Actions workflow (`.github/workflows/*.yml`) that runs on push/PR against `ubuntu-latest` and is green. It runs three fast static checks: `package_linter`, `shellcheck` on `scripts/*`, and TOML/schema validation (`tests.toml` + `manifest.toml`). **NO** `package_check`, **NO** container build — hosted-runner anti-feature. This phase delivers the workflow file and a green run; it does not add new lint checks or fix findings (those are Phases 4–6).

</domain>

<decisions>
## Implementation Decisions

### Linter provisioning on CI
- Provision `package_linter` with **inline workflow steps** — do NOT reuse `scripts/run_lint.sh` (it is WSL2/uv-specific and hardcodes `/mnt/c/...` paths) and do NOT use a prebuilt container image or marketplace action.
- Steps: `git clone` (or `actions/checkout`) the `YunoHost/package_linter` repo, set up Python, install its `requirements.txt`, run `package_linter.py` against the checked-out package.
- **Pin the linter repo to a commit SHA** (with a comment naming the version/date). Rationale: the workflow's purpose is to start and stay green; a floating `main` could redden the build with no change to this repo. Manual bump when newer checks are wanted.
- Python **3.12** via `actions/setup-python` — matches the locally verified interpreter and does not drift with the runner image.
- Run **all three checks**: `package_linter` + `shellcheck` on `scripts/*` + TOML/schema validation (`tests.toml`, `manifest.toml`).

### OpenCode's Discretion
- Exact workflow/job structure, step naming, and whether checks run as one job or separate jobs.
- Trigger event details (which push branches, `pull_request` config) and workflow/job naming.
- How the TOML/schema validation is performed (tooling choice).
- How shellcheck is installed/invoked and its severity flags.
- Timeout values, concurrency, artifact retention — subject to the roadmap's ~10 min cap and "no package_check" constraint.

</decisions>

<specifics>
## Specific Ideas

- The workflow should start green, per roadmap: Phase 7 lands last, after local findings (Phases 4–6) are fixed.
- Anti-feature is explicit: nothing may attempt a container build or `package_check` run.
- Safe `pull_request`-style triggers only — no `pull_request_target` surprise surface (roadmap success criterion 3).

</specifics>

<deferred>
## Deferred Ideas

- **GHCI-02** — self-hosted runner running full `package_check` on GitHub (only if lint-only proves insufficient). Already tracked in REQUIREMENTS.md; explicitly out of scope for this phase.

</deferred>

---

*Phase: 07-github-actions-lint-workflow*
*Context gathered: 2026-09-22*
