# Project Research Summary

**Project:** librechat_ynh — Milestone v1.1: CI Validation
**Domain:** YunoHost packaging-v2 package CI (package_check + GitHub Actions lint)
**Researched:** 2026-09-18/19
**Confidence:** HIGH (core package_check behavior verified against official docs; GH-Actions specifics MEDIUM)

## Executive Summary

librechat_ynh is an existing YunoHost packaging-v2 app package (v1.0 shipped, live-verified) wrapping LibreChat — a Node.js app with MongoDB 7.0, Meilisearch, and a heavy frontend build. Milestone v1.1 is about CI validation, not features: get local package_check green and add a GitHub Actions lint workflow. The critical scoping insight, verified across three research files: **the official YunoHost CI (`ci-apps.yunohost.org` / `ci-apps-dev`) runs package_check server-side via yunorunner once the app is cataloged, and no official public package (example_ynh, nextcloud, hedgedoc) ships a package_check GitHub workflow.** Hosted GH runners are Docker-based and cannot run Incus/LXC with dnsmasq/btrfs requirements — attempting full package_check there is an explicit anti-feature for this milestone.

The recommended approach: (1) run `package_linter` locally first — it's pure Python ≥3.11, works anywhere including this Windows dev box, and is the cheapest source of findings; (2) add a minimal `tests.toml` (currently **absent**, the primary new file package_check needs — mainly to supply the non-default `admin_email` arg, plus curl smoke-tests and one `test_upgrade_from.<sha>` entry); (3) stand up a local Linux Incus environment (WSL2 is NOT viable for Incus — budget a Linux VM/box) and run the full package_check suite; (4) fix everything it finds iteratively (that IS the milestone work); (5) add a lightweight `.github/workflows` lint job (package_linter + TOML schema + shellcheck) so hosted CI covers the fast static layer while official YNH infra covers the full suite later via catalog submission.

Key risks: package_check is stricter than the live install (exercises subpath, reinstall-after-remove, private install, upgrade-from-commit — paths v1.0 never touched); flaky multi-hundred-MB network fetches per test iteration (GitHub tarball, npm, Meilisearch binary, Mongo apt repo) produce intermittent reds that aren't regressions; and secrets-leak vectors in install-script prints (admin passwords, env contents) into public CI logs. All three have documented preventions: bisect with `-i`/interactive mode, add bounded retries, and audit `ynh_print`/`set -x` output.

## Key Findings

### Recommended Stack

STACK.md content (v1.0-era) remains valid and largely untouched by this milestone — v1.1 adds validation tooling, not runtime tech. Relevant elements for v1.1:

- **package_check** (YunoHost/package_check) — official validator; requires LXD/Incus + btrfs + `lynx jq btrfs-progs`; local run via `./package_check.sh <app_path>` with `-e` interactive mode for bisecting failures. Auto-runs manifest/install/remove/reinstall/private/upgrade/backup tests; reads `tests.toml`.
- **package_linter** (YunoHost/package_linter) — pure Python ≥3.11 static analyzer; runs locally AND on hosted runners; zero errors = quality level 5 floor, zero warnings also = level 7 eligibility.
- **tests.toml** (`test_format = 1.0`, schema header `#:schema https://raw.githubusercontent.com/YunoHost/apps/main/schemas/tests.v1.schema.json`) — the test contract file; must supply `args.admin_email` (manifest's text arg isn't auto-guessable).
- **Incus/LXD on a dedicated Linux host** — environment for local package_check runs; `incus admin init --minimal`, btrfs/zfs storage, `lxc remote add yunohost https://repo.yunohost.org/incus`. Hosted GH runners and WSL2 are **not** viable for this.
- **GitHub Actions (hosted)** — lint-only scope: package_linter, TOML/tests.toml schema validation, shellcheck on `scripts/*`. Runs fine on `ubuntu-latest` in minutes.

No changes to the runtime stack (Node 22/24 via `[resources.nodejs]`, MongoDB 7.0 via `ynh_install_mongo`, Meilisearch native binary, nginx, systemd) are anticipated unless package_check findings demand them.

### Expected Features

**Must have (table stakes for this milestone):**
- `tests.toml` created (absent at repo state `e834aea`) — minimal, schema-valid, supplying `args.admin_email`; mostly-empty is correct since package_check auto-deduces tests from the manifest
- Run real package_check locally to completion (single clean full suite archived as POLS-01 verification)
- Fix all package_check findings to zero failures — install root, install subpath, private install, reinstall-after-remove, remove, backup/restore all pass
- package_linter clean (no errors)
- GitHub Actions lint workflow (linter + shellcheck + TOML check) — added AFTER local findings fixed so it starts green

**Should have (differentiators, cheap wins):**
- `[default.curl_tests]` smoke test (SPA serves 200; assert stable content, not upstream-rewordable strings)
- One valid `test_upgrade_from.<sha>` entry pinned to a known-good v1.0-era commit
- Low-cost linter-warning fixes (`doc/` assets, maintainer field) toward level 7

**Defer (v2+ / later milestones):**
- `change_url` script (level 7 demands it, but it's scoped as a separate v2 item — still expected from package_check level-7 ambitions)
- Self-hosted GH runner running full package_check
- Catalog submission PR → official YNH CI automation
- Multi-instance, ARM64, Redis

### Architecture Approach

v1.1 touches the existing repo minimally: one new file (`tests.toml`) and one new directory (`.github/workflows/` with a lint workflow). Everything else is *modified* — manifest.toml and scripts/ edits driven by package_check findings. The repo state was verified file-by-file: all lifecycle scripts exist (install/remove/backup/restore/upgrade), `doc/DESCRIPTION.md` exists, `config_panel.toml` is absent (fine, out of scope), `tests.toml` and `.github/` are the two gaps.

**Major components:**
1. `tests.toml` — declares args package_check can't deduce (`admin_email`), curl smoke-tests, upgrade-from commits; read by package_check locally and by YNH's official CI
2. `.github/workflows/lint.yml` — hosted-runner-safe static checks only (linter, schema, shellcheck); NO package_check job
3. Package edits (manifest.toml, scripts/*) — iterative fixes until the local suite is green; findings, not failures, map to these changes

### Critical Pitfalls

1. **Full package_check on hosted GH runners** — needs LXC/Incus + dnsmasq:53 + btrfs; runners thrash/OOM on LibreChat's frontend build and 6h-limit out. Avoid entirely: Actions = lint-only; PC = local Linux env now, official YNH CI after catalog submission. *(Confirmed anti-feature per project context.)*
2. **package_check stricter than live install** — v1.0's live verification covers one happy path; CI hits subpath/reinstall/private/upgrade-from-commit. Treat every unexpected failure as a real finding; bisect with `-i`; dump the parsed test list (`parse_tests_toml.py`) before running.
3. **tests.toml mistakes** — missing `test_format = 1.0`/schema header, redundant args the manifest already defaults, `exclude = [...]` to fake green CI (explicitly discouraged, caps quality, flags review). Start from example_ynh's tests.toml verbatim; write minimal, only after knowing which args fail.
4. **Flaky network downloads per test iteration** — every test re-installs from scratch (~6+ installs of GitHub tarballs, npm, Meilisearch, Mongo apt). Add bounded retries; keep sha256-pinned sources; re-run the single failing test before suspecting code.
5. **Secrets in public CI logs** — admin credentials/env contents echoed via `ynh_print` or `set -x` land in `Test_results.log` and public GH logs. Audit all prints; GH masks only `secrets.*` literals.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Recon & Local Validation Baseline
**Rationale:** Cheapest validation first; establishes the real finding list before any file is written. Also determines *where* each test runs (pitfall 1 scoping).
**Delivers:** package_linter run results; parsed test-deduction dump (which test IDs will run); confirmed local Incus environment plan (Linux VM decision, since dev box is Windows and WSL2 is not viable for Incus).
**Addresses:** "Run package_linter locally" + "env setup" from FEATURES.md MVP steps 1 & 3.
**Avoids:** Writing a broken `tests.toml` blind (pitfall 3); assuming hosted runners can do more than lint (pitfalls 1, 5).

### Phase 2: tests.toml + package_check Environment
**Rationale:** `tests.toml` must exist (supplying `admin_email`) before any run is meaningful; the Incus environment is the long-lead item and can be set up in parallel.
**Delivers:** Schema-valid minimal `tests.toml` (example_ynh-derived); a dedicated Linux host with Incus + btrfs capable of running the full suite; first real package_check run log.
**Addresses:** tests.toml (table stakes), curl_tests (should-have, optional here).
**Avoids:** Incus/Docker networking conflicts (pitfall 4) via dedicated VM, `--minimal` init, `lynx jq btrfs-progs` installed up front.

### Phase 3: Fix Findings to Zero Failures
**Rationale:** This is the actual milestone work — iterative, unknown-scope, depends on Phases 1–2.
**Delivers:** Local package_check suite fully green (subpath, private install, reinstall-after-remove, backup/restore all pass); hardened network-fetch retries; audited `ynh_print`/`set -x` (no secrets in logs).
**Addresses:** "Fix all findings" + curl smoke-tests + optionally one `test_upgrade_from` entry.
**Avoids:** Pitfalls 2, 6, 7; the `exclude = [...]` temptation; conflating network flakes with regressions.
**Watch-out-fors:** manifest inline trailing comments may need reformatting for the linter; `maintainers` placeholder must become a real handle; mongo apt repo + npm build may push install near container timeouts.

### Phase 4: GitHub Actions Lint Workflow Green
**Rationale:** Last, so it lands green instead of red; small, low-risk, durable.
**Delivers:** `.github/workflows/lint.yml` (package_linter + tests.toml/manifest TOML-schema check + shellcheck on scripts), kept to hosted-runner-safe jobs (<~10 min, <4 GB), explicit job timeout, no `pull_request_target`.
**Addresses:** The milestone's GH Actions deliverable — lint layer only.
**Avoids:** Pitfalls 1 & 5 (no build jobs, no package_check on hosted runners); secrets/log-size gotchas.

### Phase Ordering Rationale
- Linter first because it needs zero infra and shapes everything after; tests.toml before a "meaningful" PC run because `admin_email` must be supplied; findings-fix before the GH workflow so it starts green; the workflow last because it's optional glue.
- Phase 2's environment work is the bottleneck (Linux host acquisition, Incus setup) — flag it as long-lead.
- Dependency chain from research: Local Incus env → package_check runs → findings fixed → Actions lint mirrors green. Full PC in Actions is structurally impossible on hosted runners — sequencing reflects that split.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Exact package_check invocation flags, report file names, and Incus init details were MEDIUM-confidence (including a partially speculative `--container` workflow sketch in ARCHITECTURE.md that the anti-feature ruling overrides) — verify against the latest package_check/Incus docs while setting up the environment.
- **Phase 3:** Unknown-scope findings; expect per-finding micro-research (e.g., NGINX subpath handling for the LibreChat SPA, backup restore edge cases under pristine volumes).
- **Optional change_url work:** if pulled into v1.1 due to level-7 pressure, it needs its own research iteration (not covered in depth by these files).

Phases with standard patterns (skip research-phase):
- **Phase 4:** GH Actions lint workflow is a well-trodden ~30-line pattern (checkout + clone linter + run + upload artifact).
- **Phase 1:** package_linter and test-deduction dumps are documented single commands.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | package_linter/package_check behavior verified against official repos; runtime stack unchanged from v1.0 |
| Features | HIGH (core) / MEDIUM (GH specifics) | Table stakes verified from official docs & repo trees; community self-hosted-runner recipes flagged LOW/MEDIUM |
| Architecture | HIGH on repo state (inspected locally) / LOW on workflow sketch | File existence claims verified at HEAD; the ARCHITECTURE.md package_check.yml example has unverifiable flag names and conflicts with the anti-feature ruling — discard that sketch |
| Pitfalls | HIGH | PC behavior from official README; GH runner limits are stable official policy |

**Overall confidence:** HIGH — the milestone is well-bounded and the core chief uncertainty (what package_check will actually flag) resolves in Phase 2/3 by construction.

### Gaps to Address

- **Exact package_check CLI flags / report filenames:** verify from the package_check README during Phase 2 implementation (docs are good; don't trust the workflow sketch's flags).
- **Local Incus host availability:** the Windows dev box cannot run this workflow — resolve whether the user has a Linux VM/VPS before planning Phase 2; this is the milestone's biggest logistical dependency.
- **change_url status:** absence will surface in package_check level-7 ambitions; decide explicitly whether it's v1.1 or v2 (research suggests deferring, but note PC will report it untestable).
- **Upgrade-from commit validity:** confirm the v1.0-era commit SHA referenced in `test_upgrade_from` actually installs clean before adding the entry.

## Sources

### Primary (HIGH confidence)
- YunoHost/package_check README — LXD/Incus requirements, tests.toml syntax, test IDs, docker conflicts (fetched 2026-09-18)
- YunoHost/doc — "Testing your app" / "Publishing your app" (levels 0–8, yunorunner CIs, `!testme`, weekly bot level PR)
- YunoHost/example_ynh — tests.toml sample, change_url script, absence of CI workflows
- YunoHost/package_linter README — Python ≥3.11 analyzer scope
- YunoHost/apps repo — official CI architecture; GH Actions only handles catalog consistency
- Local repo inspection at HEAD `e834aea` — file-by-file existence verification

### Secondary (MEDIUM confidence)
- Wekan_ynh and YunoHost-Apps patterns (v1.0-era stack research; unchanged)
- GitHub official docs on hosted runner specs / 6h job limit / log-size caps
- linuxcontainers.org Incus/Docker networking conflict workarounds

### Tertiary (LOW confidence)
- Community self-hosted-GH-Actions package_check recipes — not directly verified; do not imitate
- ARCHITECTURE.md's `package_check.yml --container` workflow sketch — superseded by anti-feature ruling; exact flags unverified

---
*Research completed: 2026-09-19*
*Ready for roadmap: yes*
