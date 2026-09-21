# Requirements: LibreChat YunoHost Package — v1.1 CI Validation

**Defined:** 2026-09-19
**Core Value:** One command installs a working LibreChat (API + MongoDB + Meilisearch) natively on YunoHost with a valid nginx proxy, a functioning systemd service, and reliable backup/restore.

## v1.1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Local CI

- [ ] **CI-01**: `tests.toml` test suite exists with `test_format = 1.0`, supplies install args (e.g. `args.admin_email`), and follows documented syntax (no `exclude` misuse)
- [x] **CI-02**: User can run `package_check` locally from a dedicated Hyper-V Debian 12 VM + Incus + btrfs environment (setup documented and reproducible)
- [x] **POLS-01**: `package_check` full suite runs to completion with **zero failures**; all findings fixed (install root/subpath/private/reinstall/backup-restore/upgrade). Live-verified 2026-09-20 (exit 0, all 4 in-scope tests SUCCESS); `change_url` and `upgrade.05e3d5b` exempt out-of-scope-by-design (see `06-SCOPE-EXEMPTIONS.md`)

### Static Linting

- [x] **LINT-01**: YunoHost `package_linter` reports zero errors on the package (run on Windows-capable Python, no Linux host needed)

### GitHub Actions

- [ ] **GHCI-01**: Lint-only workflow runs on push/PR and is green — `package_linter` + shellcheck + TOML validation on `ubuntu-latest` (fast; no container build)

## v2 Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Packaging polish

- **POLS-02**: `change_url` script implemented
- **POLS-03**: Multi-instance support (requires per-app Meilisearch wiring)
- **POLS-04**: ARM64 support (Raspberry Pi)
- **POLS-05**: Install question for admin credentials instead of random generation
- **GHCI-02**: Self-hosted runner running full package_check on GitHub (only if lint-only proves insufficient)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Full package_check in GitHub Actions hosted runners | Research-confirmed anti-feature: requires privileged LXC/Incus + btrfs, conflicts with Docker; LibreChat frontend build OOMs on 7GB runners. Official YNH catalog CI runs on YunoHost's own infrastructure instead |
| Catalog submission PR | Separate process; zero-failure local run is the prerequisite (do after this milestone if desired) |
| `change_url`, multi-instance, ARM64 | Deferred v2 items (POLS-02/03/04) — keep milestone scoped to CI |
| Docker-based install for CI simplification | Native install is the explicit package goal |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LINT-01 | Phase 4 | Complete |
| CI-01 | Phase 5 | Pending |
| CI-02 | Phase 5 | Complete |
| POLS-01 | Phase 6 | Complete |
| GHCI-01 | Phase 7 | Pending |

**Coverage:**
- v1.1 requirements: 5 total
- Mapped to phases: 5 ✓
- Unmapped: 0

---
*Requirements defined: 2026-09-19*
*Last updated: 2026-09-19 after initial definition*
