# Phase 7: GitHub Actions Lint Workflow - Context

**Gathered:** 2026-09-20
**Status:** Ready for planning (advance from Phase 6 via `/gsd-next`)

<domain>
## Phase Boundary

Deliver **GHCI-01**: a lint-only GitHub Actions workflow on `ubuntu-latest` that runs on push/PR and is green. It layers **static checks only** — `package_linter`, `shellcheck` on `scripts/*`, and TOML/schema validation — with an explicit job timeout, and **must not** attempt a container build or a `package_check` run (hosted-runner anti-feature, research-locked). The phase lands **after** Phase 6 so the workflow starts green against an already-verified package. No `package_check` in CI by design; full local coverage stays on the Phase 5 Hyper-V VM.

</domain>

<decisions>
## Implementation Decisions

### Scope of lint checks (the green bar)
- **`package_linter`** on the repo root — static YunoHost linting of `manifest.toml` + `scripts/*`. Must stay at the **phase-4-accepted bar** (locally-fixable errors = zero; 1 critical + 2 errors remain only as documented out-of-scope catalog items from `04-SCOPE-EXEMPTIONS.md`; they do **not** make `package_linter` exit non-zero).
- **`shellcheck`** on `scripts/*` — run with `-x` off and **exclude SC1090/SC1091** (cannot-follow-external-source) since the scripts `source` YunoHost helpers (`_common.sh`, `ynh_*`) that are not present in the runner. Optional/diagnostic severity may still surface; the bar is a **clean pass** with a documented exclude set.
- **TOML/schema validation** — parse `manifest.toml` (PY3.11+ `tomllib`) and validate `tests.toml` against its declared **tests.v1 schema** JSON fetched from the YunoHost schema URL. This catches schema drift in the artifact that `tests.toml`'s `#:schema` comment references.
- **Job timeout** — every job gets an explicit `timeout-minutes` (~10) so the workflow cannot hang the queue (ROADMAP success criterion 2).
- **No container build, no `package_check`** anywhere in the workflow; hosted-runner anti-feature respected (ROADMAP success criterion 3). `pull_request` + `push` triggers only — **no** `pull_request_target` (safe-surface requirement).

### Workflow structure
- **Three parallel jobs** (`package-linter`, `shellcheck`, `toml-schema`) — each independently green so a single failure is root-causable; smallest artifact that still proves the whole static layer.
- **Triggers:** `push` (all branches) + `pull_request`. `permissions: contents: read` at top level (least privilege). No third-party action beyond the official `actions/checkout`/`setup-python` and a pinned shellcheck action or `apt-get install shellcheck`.
- **Determinism:** pin Python 3.12, clone `package_linter` at `HEAD` (cache not required for a ~minute job), no environment-dependent path assumptions (use `$GITHUB_WORKSPACE`).

### What is NOT in scope
- **`package_check` on hosted runners** (GHCI-02 self-hosted-runner is a future milestone; the hosted-runner variant is a research-confirmed anti-feature). Do not design for it.
- **Fixing linter findings** — Phase 7 only *runs* the static layer green; any *new* zero-error regression discovered is a finding to note, not a fix loop here (that belongs to a re-run of Phase 4-style work).
- **Shellcheck strictness creep** — do not chase every SC-prefix warning to "zero warnings"; the bar is a clean job pass with a documented, justified exclude set (SC1090/SC1091).

### Evidence / verification
- Green workflow on a push/PR is the proof (ROADMAP success criterion 1). On this repo that means the workflow file is committed on `main` and — where a remote runner is available — a push shows green. Local equivalent: each job's commands run green in a shell before commit (documented in the plan + summary).
- The workflow YAML is the artifact; no extra run-log archive is required for a static lint workflow (contrast Phase 6's POLS-01 run log).

</decisions>

<specifics>
## Specific Ideas

- A single `lint.yml` with 3 jobs is enough; avoid one mega-job so failures are isolated.
- `shellcheck`: `sudo apt-get update && sudo apt-get install -y shellcheck` (official repo, no third-party action), then `shellcheck -x scripts/*.sh` — verify whether `-x` is needed given `_common.sh` sourcing. Exclude `SC1090,SC1091` (external source follow) with `-e`. Keep any other excludes minimal and justified in code comments.
- TOML job: `python -c` one-liners using stdlib `tomllib` for `manifest.toml` + `tests.toml` syntax; then `jsonschema` against the fetched `tests.v1.schema.json` for schema-level validation of `tests.toml`.
- `package_linter` job: mirror `scripts/run_lint.sh`'s invocation but CI-native (no WSL): clone `package_linter`, `pip install -r requirements.txt`, run `python package_linter.py "$GITHUB_WORKSPACE"`. Assert on the **text-mode** exit code only (the `--json` mode always exits 0 — known linter behavior already documented in `run_lint.sh`).
- `manifest.toml` schema validation beyond syntax is **not** attempted — the authoritative v1 app-manifest schema is fetched from the YunoHost schema URL only if a stable URL is confirmed at implementation time; otherwise fall back to syntax + the `tests.toml` schema (catalog schema availability is a research output, not a blocker).

</specifics>

<deferred>
## Deferred Ideas

- **GHCI-02**: self-hosted runner executing full `package_check` — future milestone, only if lint-only proves insufficient (REQUIREMENTS.md).
- **Catalog submission PR** — separate process; resolves the `AppCatalog.*` linter exemptions.
- **Zero-warning shellcheck** — not a goal; a clean job pass with a justified exclude set is sufficient.
- **Local Windows lint dev** — already covered by Phase 4's `scripts/run_lint.sh` + WSL; Phase 7 adds the hosted-runner static layer.

</deferred>

---

*Phase: 07-github-actions-lint-workflow*
*Context gathered: 2026-09-20 (advanced via /gsd-next from Phase 6)*
