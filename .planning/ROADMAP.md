# Roadmap: LibreChat YunoHost Package

## Milestones

- ✅ **v1.0 Package** — Phases 1-3 (shipped 2026-09-19)
- ✅ **v1.1 CI Validation** — Phases 4-7 (shipped 2026-09-20)

## Phases

<details>
<summary>✅ v1.0 Package (Phases 1-3) — SHIPPED 2026-09-19</summary>

Phases 1-3 delivered the complete lifecycle package: install, remove, backup/restore, and config-preserving upgrade — 34/34 v1 requirements met, live-verified on a real YunoHost server. See MILESTONES.md for the summary.

</details>

<details>
<summary>✅ v1.1 CI Validation (Phases 4-7) — SHIPPED 2026-09-20</summary>

**Milestone Goal:** Package passes YunoHost `package_check` with zero in-scope failures (POLS-01 archived as live verification), `package_linter` reports zero locally-fixable errors, and a lint-only GitHub Actions workflow is green.

- [x] **Phase 4: Lint Baseline** — `package_linter` clean via WSL2 + uv Python 3.12; baseline archived with 5 documented scope exemptions (completed 2026-09-20)
- [x] **Phase 5: tests.toml + Local package_check Environment** — Schema-valid `tests.toml` + reproducible Hyper-V Debian 12 VM + Incus + btrfs environment runs the full suite (completed 2026-09-20)
- [x] **Phase 6: Fix Findings to Zero Failures** — All install-blocking bugs fixed; single clean full-suite run archived as POLS-01 (exit 0, 4/4 in-scope SUCCESS) (completed 2026-09-20)
- [x] **Phase 7: GitHub Actions Lint Workflow** — Lint-only workflow green on `ubuntu-latest` (`package_linter` + shellcheck + TOML/schema) (completed 2026-09-20)

Full phase details: `.planning/milestones/v1.1-ROADMAP.md`.

</details>

### 📋 v2 (Planned)

- [ ] Phase 8+: to be defined via `/gsd-new-milestone`
- Deferred candidates: `change_url` (POLS-02), multi-instance (POLS-03), ARM64 (POLS-04), admin-credential install question (POLS-05), catalog submission PR, optional GHCI-02 self-hosted `package_check`

## Progress

**Execution Order:** define v2 via `/gsd-new-milestone`

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-09-19 |
| 2. App Delivery | v1.0 | 2/2 | Complete | 2026-09-19 |
| 3. Lifecycle & Polish | v1.0 | 2/2 | Complete | 2026-09-19 |
| 4. Lint Baseline | v1.1 | 4/4 | Complete | 2026-09-20 |
| 5. tests.toml + PC Environment | v1.1 | 3/3 | Complete | 2026-09-20 |
| 6. Fix Findings to Zero | v1.1 | 5/5 | Complete | 2026-09-20 |
| 7. GH Actions Lint Workflow | v1.1 | 1/1 | Complete | 2026-09-20 |

*v1.0 plan counts approximate the shipped milestone summary (3 phases, 7 plans). v1.1: 4 phases, 13 plans.*
