# Feature Landscape

**Domain:** CI validation for a YunoHost packaging-v2 app package (package_check + GitHub Actions)
**Researched:** 2026-09-18/19
**Overall confidence:** HIGH (core mechanics verified against official docs/repos; GitHub-Actions specifics MEDIUM)

## Context: How YunoHost CI Actually Works

This is critical for scoping. Verified from official docs (doc.yunohost.org "Testing your app" / "Publishing your app") and the `YunoHost/package_check` repo README:

- **The "official CI" (`ci-apps.yunohost.org`) and "dev CI" (`ci-apps-dev.yunohost.org`) run package_check server-side via `yunorunner`.** Jobs auto-trigger on commits to an app's default branch (once the app is listed in `YunoHost/apps`' `apps.toml`). YunoHost-Apps org members can comment `!testme` on a PR to trigger dev-CI jobs with public results.
- **Quality level (0–8) is computed by package_check**, not set manually. The yunohost-bot opens a weekly PR (Friday) updating `apps.toml` levels from official-CI results.
- **Apps' own GitHub Actions workflows are NOT the standard mechanism.** `example_ynh` and major official apps (nextcloud, hedgedoc) ship **no package_check workflow** — package_check needs LXC/Incus with network/dnsmasq privileges, which standard GitHub-hosted runners (Docker-based, no nested Incus) cannot properly run. It also conflicts with Docker (workarounds documented by linuxcontainers.org).
- Therefore "GitHub Actions CI" for a YNH package realistically means: (a) fast static checks (package_linter, toml/shell bins) on hosted runners, and (b) full package_check either locally (Incus on own machine) or via a self-hosted runner later.

## Table Stakes

What a catalog-quality packaging-v2 package needs. Missing = CI failures / catalog quality cap.

| Feature | Why Expected | Complexity | Notes / Dependencies |
|---------|--------------|------------|----------------------|
| `tests.toml` (test_format = 1.0) | Package_check reads it to know what to test; example_ynh ships one; catalog lint expects the schema header `#:schema .../tests.v1.schema.json` | Low | Mostly empty is correct — CI auto-deduces tests from manifest. No cwd in repo yet → must be created |
| Manifest-driven default scenarios: install root, install subpath, private install, remove, reinstall, upgrade-same-version, backup/restore | These are auto-run by package_check from manifest; level 1–4 floor. LibreChat is multi_instance=false with its own auth (`sso=false`), so `install.multi` should be excluded or will simply be deduced off | Low | Mostly "already built" (v1.0 live-verified). Fix what CI finds, don't re-engineer |
| Package_linter clean (no errors; ideally no warnings for level 7) | Level 5 requires zero linter errors; level 7 requires zero warnings. Runs as pure Python ≥3.11 — runnable locally AND on hosted GitHub runners | Low | Run it locally NOW before any CI wiring — cheapest validation |
| `change_url` script | Level 7 "all tests succeeded" includes `change_url`; it's a standard v2 lifecycle script. Explicit v2 goal (POLS-02). Without it, package_check reports change_url as untestable/failed | Medium–High | New script; must move domain/path/permissions, re-run regen-conf (nginx, SSOwat), keep Mongo/Meili/Node untouched. Monaco: test with actual re-install |
| Curl smoke-tests in `tests.toml` (`[default.curl_tests]`) | Validates the install actually serves the app (no 404/502, expected `<title>`/content). This is how CI verifies a React SPA like LibreChat boots | Low | e.g. `home.path = "/"`, `home.expect_return_code = 200` (+ maybe `expect_content` on `/` SPA HTML). Auto_test_assets covers CSS/JS when no explicit tests |
| `test_upgrade_from.<sha>` entries | Level 7 requires upgrades from past commits to pass. Our repo has ~ynh2 history; declare at least one prior commit (its sha in a **community-reachable** state) with name/args | Low | Note: commit must be installable from the same git remote; our locally-known bump commits should work |
| Run real package_check locally (Incus/LXD) | Core deliverable: "passes package_check with zero failures". Needs: Linux host, Incus or LXD + btrfs, `lxc remote add yunohost https://repo.yunohost.org/incus`, clone package_check, `./package_check.sh librechat_ynh` | Medium | Cannot run on the Windows dev box directly — needs WSL2 or a Linux box/VM; Incus conflicts with Docker networks (documented workarounds). Budget a session for environment setup |
| Fix all findings package_check surfaces | Unknown until run. Typical findings for native-build apps: temp-dir usage, curl-ability of assets, SSOwart permission assumptions, restore edge cases, systemd hardening blocking something in the clean container | Medium | The actual work of the milestone. Zero-failure target = POLS-01 |

## Differentiators

Nice-to-have that lifts the package toward top-quality catalog level. None block the milestone goal.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| GitHub Actions lint workflow (hosted runner) | Fast PR feedback: checkout → clone package_linter → `python3 package_linter.py` (+ maybe taplo/tomlcheck on manifest.toml & tests.toml, shellcheck on scripts/*) | Low | Runs fine on `ubuntu-latest`. package_check itself cannot (needs Incus) — do not attempt full PC on hosted runners |
| Pinned `configs`/doc screenshots, `doc/` pages (ADMIN.md, DESCRIPTION.md) | Linter warnings; app-store presentation. example_ynh ships these | Low | Check linter warnings list; cheap wins for level 7 |
| Self-hosted runner running full package_check on push | GitHub-visible quality badge without waiting for official CI | High | Only viable via self-hosted runner + Incus infra. Defer — official CI covers it once cataloged |
| Community-org hosting (fork/mirror under YunoHost-Apps) | Level 6 by definition requires repo in YunoHost-Apps org | Low | Publisher decision, not code. Note as roadmap option when submitting catalog PR |
| App catalog submission PR (apps.toml in YunoHost/apps) | get app listed; official CI then runs automatically on every commit; weekly level updates via bot | Low (PR effort, review wait) | Out of scope for this milestone unless trivially adjacent; requires linter-clean + passing CI first |

## Anti-Features

Do NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Full package_check in a GitHub-hosted Actions workflow | Standard runners are Docker-based; Incus/LXC + dnsmasq:53 + btrfs snapshotting don't work there; tests take 30–60+ min | Run package_check locally (Incus); use Actions only for light lint |
| `exclude = [...]` of core tests to "make CI green" | Explicitly discouraged (README); masks real failures and caps quality level | Fix the actual script bugs CI finds |
| `preinstall =` bootstrapping hacks | Signals packaging problems; adds flaky CI deps | Keep LibreChat self-contained (Mongo/Meili already packaged) |
| Multi-instance / ARM64 work now | Blocked/deferred (POLS-03/04); `multi_instance=false` means install.multi simply won't run | Revisit in a later milestone with per-app Meilisearch wiring |
| Custom CI harness replacing package_check | Duplicates upstream logic; level comes only from official package_check | Contribute fixes to this repo; let YNH CI be the arbiter |
| Knob-tuning `manifest.toml` to dodge deduced tests | Suspicious pattern catalog reviewers catch | Keep manifest truthful |

## Feature Dependencies

```
tests.toml (curated)  →  "meaningful" CI runs (curl_checks, upgrade-from entries)
change_url script     →  change_url test passing  →  level ≥ 6/7 territory
package_linter clean  →  level 5+  &  catalog submission  →  official CI automation
Local Incus env       →  running package_check at all
Fix CI findings       →  "zero failures" = milestone goal (POLS-01)
Catalog PR            →  official CI / autolevels (future milestone)
```

## MVP Recommendation

Prioritize (order for roadmap):
1. **Run package_linter locally** (pure Python, works on any box) — cheapest, immediate findings list. Low complexity.
2. **Add tests.toml** (default suite, curl_checks, one `test_upgrade_from.<sha>` entry). Low complexity.
3. **Stand up package_check environment** (Incus + btrfs, WSL2/Linux VM because dev box is Windows) and run full suite. Medium complexity, likely the longest-lead item.
4. **Fix all findings** (install/upgrade/backup/change_url readiness varies; unknown scope). Medium complexity, the real milestone work.
5. **Add GitHub Actions lint workflow** (linter + shellcheck + TOML check) as the durable hosted CI. Low complexity — do after findings fixed so it starts green.
6. **Archive clean package_check result** as POLS-01 verification (milestone exit criterion).

Defer: full-PC GitHub workflow (needs self-hosted runner), catalog submission PR, change_url (if it proves larger than expected — it is scoped as its own v2 item, but expect package_check/level-7 to demand it), multi-instance, ARM64.

## Sources

- `YunoHost/package_check` README (features, tests.toml syntax, Incus/LXD setup) — HIGH
- `YunoHost/doc` → "Testing your app" & "Publishing your app" (levels 0–8 definitions, yunorunner CIs, `!testme`, bot weekly level PR) — HIGH
- `YunoHost/example_ynh` tree (tests.toml sample, scripts incl. change_url; no CI workflows) — HIGH
- `YunoHost/package_linter` README (Python ≥3.11 static analyzer) — HIGH
- Absence of package_check workflows in official apps (nextcloud, hedgedoc, example_ynh trees inspected) — HIGH
- Community-app self-hosted Actions recipes for package_check — LOW/MEDIUM (not directly verified; keep flagged)
