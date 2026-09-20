# Roadmap: LibreChat YunoHost Package

## Milestones

- ✅ **v1.0 Package** - Phases 1-3 (shipped 2026-09-19)
- 🚧 **v1.1 CI Validation** - Phases 4-7 (in progress)

<details>
<summary>✅ v1.0 Package (Phases 1-3) - SHIPPED 2026-09-19</summary>

Phases 1-3 delivered the complete lifecycle package: install, remove, backup/restore, and config-preserving upgrade — 34/34 v1 requirements met, live-verified on a real YunoHost server. See MILESTONES.md for the summary.

</details>

### 🚧 v1.1 CI Validation (In Progress)

**Milestone Goal:** Package passes YunoHost `package_check` with zero failures (POLS-01 archived as live verification), `package_linter` reports zero errors, and a lint-only GitHub Actions workflow is green.

**Phase Numbering:**
- Integer phases (4, 5, 6, 7): Planned milestone work
- Decimal phases (4.1, 5.1...): Urgent insertions via `/gsd-insert-phase`

- [ ] **Phase 4: Lint Baseline** - package_linter runs clean on the Windows dev box; establishes the cheapest source of findings before any infra work
- [x] **Phase 5: tests.toml + Local package_check Environment** - Schema-valid tests.toml exists and a reproducible Hyper-V Debian 12 VM + Incus + btrfs Linux environment runs the full package_check suite (completed 2026-09-20)
- [ ] **Phase 6: Fix Findings to Zero Failures** - Iterative fixes until the full package_check suite completes with zero failures; clean run archived as POLS-01 verification
- [ ] **Phase 7: GitHub Actions Lint Workflow** - Lint-only workflow on hosted runners, added last so it starts green

## Phase Details

### Phase 4: Lint Baseline
**Goal**: The package passes YunoHost `package_linter` with zero errors, verified on the Windows-capable Python environment — establishing the real finding list before any environment or CI work.
**Depends on**: Nothing (first phase of v1.1; v1.0 shipped)
**Requirements**: LINT-01
**Success Criteria** (what must be TRUE):
  1. User can run `package_linter` locally from the Windows dev box (WSL2, uv-Python 3.12, no separate Linux host needed) and it reports zero **locally-fixable** errors on the package
  2. Known warnings are fixed (8 of 9) or explicitly documented as out-of-scope-by-design with a reason (catalog category — requires an out-of-scope catalog submission PR); the exempted criticals/errors (`AppCatalog.is_in_catalog`, `AppCatalog.state_is_working`, `Configurations.tests_toml`) are each documented with a reason in `.planning/phases/04-lint-baseline/04-SCOPE-EXEMPTIONS.md`
  3. A lint baseline output is archived (before + after artifacts) showing the zero-locally-fixable-error result, and the user has explicitly confirmed the scope-adjusted interpretation
**Plans**: 4 plans
Plans:
- [ ] 04-01-PLAN.md — Wave 0 scaffold: `scripts/run_lint.sh` runner, `.gitattributes` LF pinning, baseline artifacts, scope-exemption record
- [ ] 04-02-PLAN.md — Manifest + script fixes: 2 schema violations, deprecated helpers, backup progression, init_main_permission, maintainers
- [ ] 04-03-PLAN.md — Config/docs modernization: nginx header removal (WS retained), README regeneration
- [ ] 04-04-PLAN.md — Final zero-error proof, before/after artifacts, exemption reconciliation, user checkpoint

### Phase 5: tests.toml + Local package_check Environment
**Goal**: The package has a schema-valid `tests.toml` (supplying install args like `admin_email`, optional curl smoke-tests and one `test_upgrade_from` entry) and a reproducible local Linux environment (dedicated Hyper-V Debian 12 VM + Incus + btrfs, documented) that can run the full `package_check` suite end-to-end.
**Depends on**: Phase 4 (lint clean so environmental findings aren't confused with static ones)
**Requirements**: CI-01, CI-02
**Success Criteria** (what must be TRUE):
  1. `tests.toml` exists with `test_format = 1.0` and the documented schema header; package_check parses it without errors and installs proceed (argument `admin_email` supplied — no `exclude` misuse)
  2. User can, following a documented setup doc, run `package_check` locally from the Hyper-V Debian 12 VM environment against the package and see the full test suite start and complete (pass or fail — findings allowed, crashes not)
  3. The environment setup on the Hyper-V Debian 12 VM host (Incus init, btrfs, `lynx jq btrfs-progs`, yunohost remote) is documented and reproducible by re-running the doc from scratch
**Plans**: 3 plans
Plans:
- [x] 05-01-PLAN.md — `tests.toml` (CI-01): schema-valid, supplies `admin_email`, one `test_upgrade_from.05e3d5b` entry, curl smoke-tests; parse + dry-run validated
- [x] 05-02-PLAN.md — Host artifacts (CI-02): idempotent `scripts/setup_pc_env.sh`, `doc/PACKAGE_CHECK.md` walkthrough, and the ROADMAP/REQUIREMENTS host-wording amendment (Hyper-V)
- [ ] 05-03-PLAN.md — Full-suite run (CI-02): user-provisioned Hyper-V VM checkpoint, SSH-driven in-VM setup, one full `package_check` run archived in the phase dir — **Tasks 3-4 complete (run completed 4m5s, exit 0, findings archived); Task 5 checkpoint:human-verify AWAITING USER**

### Phase 6: Fix Findings to Zero Failures
**Goal**: The full local `package_check` suite — install root/subpath, private install, reinstall-after-remove, backup/restore, upgrade — completes with zero failures, and the clean run is archived as live verification of POLS-01. This is the milestone's core deliverable.
**Depends on**: Phase 5 (needs a runnable environment and a valid tests.toml)
**Requirements**: POLS-01
**Success Criteria** (what must be TRUE):
  1. A complete `package_check` run on the local environment shows zero failures across all lifecycle tests (root install, subpath install, private install, reinstall after remove, backup/restore, upgrade)
  2. The zero-failure run log (`Test_results.log` or equivalent) is archived in the repo/planning as POLS-01 v1.1 live verification
  3. Network flakiness is contained: a re-run of a previously failing test passes (bounded retries / honest flake-vs-regression distinction documented)
  4. No secrets (admin password, env contents) appear in package_check output logs — `ynh_print`/`set -x` output audited
**Plans**: TBD

### Phase 7: GitHub Actions Lint Workflow
**Goal**: A lint-only GitHub Actions workflow runs on push/PR against `ubuntu-latest` and is green — package_linter + shellcheck + TOML/schema validation. Fast static layer only; NO package_check on hosted runners (anti-feature).
**Depends on**: Phase 6 (lands after local findings are fixed so the workflow starts green)
**Requirements**: GHCI-01
**Success Criteria** (what must be TRUE):
  1. A pull request or push to the repo shows the lint workflow running and passing (green check) on `ubuntu-latest`
  2. The workflow completes in minutes (~10 min or less) with an explicit job timeout, running only lint-only jobs: package_linter, shellcheck on `scripts/*`, TOML/schema validation
  3. Nothing in the workflow attempts a container build or package_check run (hosted-runner anti-feature respected); safe `pull_request`-style triggers only (no `pull_request_target` surprise surface)
**Plans**: TBD

## Progress

**Execution Order:** 4 → 5 → 6 → 7 (decimal insertions between their surrounding integers)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-09-19 |
| 2. App Delivery | v1.0 | 2/2 | Complete | 2026-09-19 |
| 3. Lifecycle & Polish | v1.0 | 2/2 | Complete | 2026-09-19 |
| 4. Lint Baseline | 2/4 | In Progress|  | - |
| 5. tests.toml + PC Environment | 3/3 | Complete   | 2026-09-20 | - |
| 6. Fix Findings to Zero | v1.1 | 0/? | Not started | - |
| 7. GH Actions Lint Workflow | v1.1 | 0/? | Not started | - |

*Note: v1.0 plan counts approximate the shipped milestone summary (3 phases, 7 plans).*
