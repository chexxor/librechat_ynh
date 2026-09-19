# Pitfalls Research

**Domain:** Adding CI validation (package_check + GitHub Actions) to an existing YunoHost package (librechat_ynh — native LibreChat build, MongoDB 7.0, Meilisearch, packaging v2)
**Researched:** 2026-09-18
**Confidence:** HIGH on package_check behavior (verified against official README/current example_ynh tests.toml); MEDIUM on GH Actions limits (official GitHub docs / well-established community knowledge)

## Critical Pitfalls

### Pitfall 1: Assuming GitHub-hosted Actions can run the full package_check suite for this app

**What goes wrong:**
package_check runs every test (install root, install subpath, reinstall, private install, upgrade, backup/restore, change_url) inside an LXD/Incus container against a full YunoHost instance. For librechat_ynh each install means: source download + frontend build (`npm ci` + build, minutes), MongoDB install, Meilisearch binary fetch. A full suite can be many times that. Running it on a GitHub-hosted runner means either: the 6-hour job limit gets hit, nested-virtualization problems (LXD inside runner), or 2-core/7GB free runners thrashing during the frontend build (Node builds of this size regularly OOM on 7GB).

**Why it happens:**
People see that other YunoHost apps "have CI" and assume the same workflow works by copy-pasting a job into `.github/workflows/`. But the official YunoHost app CI (package_linter + full package_check across bookworm/trixie, amd64) is run by **YunoHost's own CI infrastructure** triggered when the app is registered in the official `YunoHost/apps` catalog — not by GH Actions. GitHub's `consistency_check.yml` in the apps repo only validates catalog metadata.

**How to avoid:**
Split responsibilities:
1. **GitHub Actions:** run only what fits — `package_linter` (fast, pure Python, no container), TOML/schema validation of tests.toml, shellcheck/clomonitor-style hygiene. Minutes, safe.
2. **Full package_check:** run on the official YunoHost CI (via catalog listing) and/or on a **self-hosted runner** where Incus/LXD works (bare metal or a VM with nested virtualization allowed, btrfs storage, ample disk — mongo + node + build artifacts per test iteration easily exceeds 20–30GB with container snapshotting).
3. Iterate locally with `./package_check.sh /path/to/app -e` (interactive-on-errors) before declaring success.

**Warning signs:**
- GH workflow run that goes "queued" forever or dies at `lxc launch` / `incus admin init`.
- Job killed around the 6:00:00 mark, or OOM during `npm run build`.
- Disk full errors (`btrfs-progs` needed, snapshots accumulate per test).

**Phase to address:** Phase 1 of the CI milestone — define *where* each test runs before writing any workflow file.

---

### Pitfall 2: package_check is stricter than a live install — the app "works on my server" but fails CI

**What goes wrong:**
The v1.0 package was live-verified on a real server. package_check still fails because it exercises scenarios a manual install never hits: install at subpath (`domain.tld/foobar`) and change back, install-to-install-root reinstall, private install, install with different args, *reinstall after remove*, and upgrade from arbitrary historical commits. Common concrete failures for this package type:
- Anything hardcoding `/` as the URL base (backend or nginx location regexes) fails the subpath test.
- `change_url` doesn't exist yet (v1 skipped it) — CI wants it if the manifest advertises it; if it doesn't, ensure the test isn't implied.
- Sources re-fetch during *each* install test — a flaky upstream download fails the whole suite.

**Why it happens:**
Live verification covers one happy path. package_check's whole purpose is to hit the other paths. Also its container is pristine (no DNS caches, no warm npm registry, no personal tweaks) so timing/latency assumptions differ.

**How to avoid:**
- Read `Test_results.log` failures one test at a time; run with `-i` (interactive) to bisect.
- Check `python3 lib/parse_tests_toml.py .planning/../app/ | jq` locally to see exactly which tests package_check will run *before* running it.
- Make every network fetch (GitHub tarball, npm, Meilisearch binary, Mongo apt repo) retry-tolerant or pre-pinned — see Pitfall 6.

**Warning signs:**
- Install succeeded, very first CI failure is in `install.subdir` or `reinstall`.
- Tests pass individually but fail in suite order (leftover state between tests).

**Phase to address:** Phase 2 (fix findings) — but the parse dump belongs in Phase 1 recon.

---

### Pitfall 3: tests.toml syntax and semantic mistakes (format version, wrong keys, over-constraining)

**What goes wrong:**
The file must follow the v1 schema (`#:schema https://raw.githubusercontent.com/YunoHost/apps/main/schemas/tests.v1.schema.json`, `test_format = 1.0`). Common mistakes:
- Missing `test_format = 1.0` or using an old format → tests silently run "all defaults" or fail schema validation.
- Assuming a missing `tests.toml` breaks CI — it doesn't; tests are auto-deduced from the manifest. Adding a broken *partial* file is worse than none.
- Defining `args.*` for args that already have manifest defaults (docs explicitly say "you should NOT need this" for standard args like domain/path/admin/is_public) — redundant or conflicting values cause confusing failures.
- Setting `exclude = [...]` to silence failing tests ("you should NOT need this except if you really have a good reason") — this is a red flag in app review and masks real bugs.
- `change_url` test: declared implicitly when `change_url` script exists. Adding a trivial/broken change_url just to satisfy CI creates worse failures (the change_url test does a real change + curl checks).

**How to avoid:**
- Start from the current `example_ynh` tests.toml verbatim, strip commented blocks.
- Only add `test_upgrade_from.<sha>` entries pointing to commits on the main branch with a known-good installs of prior versions — for this repo that means the ~ynh2-era commit; wrong SHAs (broken installs) make the *upgrade test itself* fail spuriously.
- Validate with the official linter and `parse_tests_toml.py` output.
- For this app consider `[default.curl_tests]` with `home.path = "/"`, `expect_content` on something stable (e.g., the SPA's title or `/api/...` health endpoint) — but pick content guaranteed stable across upstream releases, or CI breaks on every bump. Avoid `expect_title` matching on strings LibreChat devs may reword.

**Warning signs:**
- Schema errors from the linter on push.
- Tests running that reference args you thought you skipped.
- Upgrade test fails on a commit you never touched — tests.toml points at the wrong SHA.

**Phase to address:** Phase 2 (with the package_check fixes) — write minimal tests.toml only after knowing which test IDs fail.

---

### Pitfall 4: Docker/LXC/incus nesting and networking conflicts in the CI environment

**What goes wrong:**
package_check *requires* LXD or Incus. Documented conflicts: it needs dnsmasq on port 53 (conflicts with libvirt/LXC setups), it "will definitely conflict with Docker" (fixable with documented iptables workarounds from linuxcontainers.org), and btrfs kernel module access requires the *user be in the incus-admin/lxd group plus a reboot*. On a fresh VPS or the project dev box (note: this project lives on a Windows host; package_check must run on a Linux host anyway), people burn hours on: engine version mismatch (snap LXD path not in sudo's PATH — needs `/usr/local/bin` symlink per official README), wrong storage driver (non-CoW driver = painfully slow snapshot churn), or missing `lynx jq btrfs-progs` deps that make the failing-test output unreadable.

**How to avoid:**
- Dedicated Linux VM/host, Docker either absent or listening only on a user-defined bridge (official incus workaround).
- `incus admin init --minimal`, btrfs or zfs storage.
- Install `lynx jq btrfs-progs` up front so log output is usable.
- Architecture pinning: set `ARCH/DIST/YNH_BRANCH` in package_check's `config` file rather than flags each run.

**Warning signs:**
- `dnsmasq` errors, port 53 already bound.
- containers stuck in creation, network without WSL2-incompatible errors (WSL2 has no usable Incus for this flow — don't try).
- Tests mysteriously slow — CoW driver missing.

**Phase to address:** Phase 1 — environment setup before touching the package.

---

### Pitfall 5: GH Actions runner budget/type limits for the frontend build (if any build jobs go to hosted runners)

**What goes wrong:**
If the team opts for GH Actions workflows that build LibreChat (e.g., a smoke-build job, or trying package_check via a workflow): free hosted runners are 2 vCPU / 7 GB / ~14 GB SSD; job limit 6h; total free tier minutes ~2000/month for private repos (public repos get free unlimited *minutes* but still hit the per-job hardware wall). LibreChat's `npm ci` + prod build is multi-GB and multi-minute; pnpm/npm cache helps but Mongo + Node + a build in a container will not complete reliably. Also, Actions output log has a **size cap per job (~2 GB total silently accepted, log ~65 KB *per step line* truncated)** — verbose `npm install` output can flake log visibility, making debugging harder.

**Why it happens:**
Attempting to replicate the YunoHost official CI inside Actions, which it was never designed for.

**How to avoid:**
- Keep hosted-runner jobs to: linter, schema checks, maybe a lean `npm ci --dry-run`-style dependency sanity check with caching (`actions/setup-node` cache: npm).
- Anything that builds the real frontend or installs Mongo → self-hosted runner or the YunoHost infra.
- If caching source tarballs (upstream v0.8.8-rc3, Meilisearch binary): they're pinned-by-sha256 downloads, cheap to cache via `actions/cache` keyed on the manifest version string — but don't cache what the sha256 already de-dupes (it's one ~100MB fetch per run; caching adds complexity for marginal gain).

**Warning signs:**
- Job minutes burned at odd hours of the month.
- "Killed" exit codes on build steps → OOM, not a real bug.
- Log viewer truncation hiding the actual error line.

**Phase to address:** Phase 1 — scope the Actions workflow to hosted-runner-safe work.

---

### Pitfall 6: Flaky network downloads inside package_check turn intermittent CI failures into real debugging churn

**What goes wrong:**
Each package_check test iteration re-runs the install script from scratch: GitHub tarball fetch, npm registry, Meilisearch binary URL, MongoDB apt repo key/import. Any single transient network hiccup fails that test, and because the suite does ~6+ installs, flake probability is high — CI goes red on a commit that's perfectly fine. Worse: *intermittent* failures are the hardest to diagnose and waste milestone time fixing "bugs" that aren't.

**Why it happens:**
The package downloads several hundred MB through fresh container networks per test. npm specifically is known to stall; apt mirrors flap; GitHub downloads rate-limit.

**How to avoid:**
- Add bounded retries (e.g. `ynh_` helper retries where available, `--retry 3` on curl, apt `Acquire::Retries`) inside the install script where the helpers don't already do it.
- Keep the sha256-pinned-source discipline (already in v1) — never `latest` URLs that shift between runs.
- Never cache inside the *container* (each test is clean by design); accept some duplicated download cost, just make it retry.
- Don't conflate a network flake with a code regression: re-run the single failing test (`only =` in tests.toml or rerun with `-i`) before investigating code.

**Warning signs:**
- Same commit passes then fails; failures move across test IDs.
- Errors are `curl: (56)` / EAI timeouts / hash mismatch — not script logic errors.

**Phase to address:** Phase 2 — harden install-script network paths; must land before trusting CI as the regression gate.

---

### Pitfall 7: Leaking secrets into CI logs

**What goes wrong:**
package_check installs with **public, predictable test args** (it fills standard args itself), but the *app's own logs* are the leak vector here: LibreChat doesn't need provider API keys to install, but if install/env templates, `ynh_print` calls, or upgrade merge logic ever echo `librechat.env` contents (which will eventually contain users' real keys in production, or test-created admin passwords during CI), that lands in `Test_results.log` and in GH Action logs (which are visible to anyone on public repos and searchable). Admin user creation during install generates a password — if the script prints it "for debugging," it's now in the public log.

**How to avoid:**
- Audit every `ynh_print_*` / `set -x` source for values derived from `$librechat.env`, the admin credential file, or YAML config.
- Remember `set -x` echoes expansions — never wrap provisioning sections with it in CI, or scrub.
- Keep GH workflows that touch secrets on `concurrency` gated, minimal output; use job summaries instead of raw dumps.
- Note GH masks literals declared in secrets, but only if you use `secrets.*` — arbitrary values printed by app code get no masking.

**Warning signs:**
- `Test_results.log` containing base64/hex blobs, curl URLs with tokens, or the test password.
- Reviewers on apps.yunohost.org flagging logs.

**Phase to address:** Phase 2 — audit logging during fixes; also makes a good "looks done but isn't" checklist item in Phase 3 verification.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `exclude = [...]` in tests.toml to skip failing tests | CI goes green fast | Real regressions ship; flagged in official app review | Only documented, temporary, with a tracking issue — ideally never |
| Skipping tests.toml entirely (rely on auto-deduction) | Zero syntax risk | No curl-tests coverage; can't express upgrade-from commits | Acceptable at first; add curl_tests once install is stable |
| Running package_check only on the YunoHost official CI, no local runner | No infra cost | Slow feedback (hours per iteration during fix phase), noisy iteration | Only if local env is impossible; expect slow milestone |
| Copying another app's GitHub workflow verbatim | Workflow exists in 10 min | Fails in unpredictable ways (this app is heavier than the donor app) | Never as-is; adapt after scope decision |
| Caching npm/tarballs across CI runs keyed loosely | Faster runs | Stale caches mask upstream API changes | Cache npm with key on package-lock; avoid caching upstream tarball (sha256 pin suffices) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| package_check vs live install | Assuming live success transfers to CI | Treat CI as exercising paths live install never did (subpath, reinstall, private, upgrade-from-commit); run parse_tests_toml.py dump first |
| YunoHost official apps CI | Assuming GH Actions replaces it | Official CI is triggered via the `YunoHost/apps` catalog integration (community + official apps both); GH Actions is additional/local only |
| tests.toml + manifest | Declaring args the manifest defaults already provide | Only declare args with no sensible default; let CI fill domain/path/admin/is_public/password |
| curl_tests | Testing `expect_title` on upstream-reworded strings | Prefer `expect_content` on a stable endpoint or asset path (`/assets/vite-logo.svg`-style) with expected 200/3xx |
| GH Actions + Incus | Trying nested LXD on hosted runners | Self-hosted runner or local Linux host for package_check; GH runners do linter/schema only |
| mongodump/restore in CI | Backup test runs on container-fresh DB | Confirm dump path/cwd-relative behavior under test conditions; it was live-verified but test re-runs it against a *pristine* volume |
| Upstream bumps | Editing tests.toml curl expectations per release | Pin curl expectations to stable surfaces; version-agnostic assertions |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Snapshot/storage bloat in Incus from repeated test installs | Host disk fills mid-suite | btrfs/zfs pool, prune strategies, warn ~50GB+ free required | After several full-suite runs on any small VPS |
| Verbose `npm install` output into package_check log | `Test_results.log` becomes unusable / truncated | Reduce verbosity on install; keep last N lines on failure only | Immediately |
| Running full suite on every commit push while iterating | Days wasted | Run single test IDs locally during fixes; full suite once at the end | During the fix-fail-redo cycle |
| 2-core hosted runner builds | OOM kills, 15+ min builds | Do not attempt frontend build on hosted runners | First run |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Printing env/config values during install/upgrade | API keys / admin password in public CI logs | Audit ynh_print and `set -x`; mask, summarize, or omit |
| `pull_request_target` on workflows to "save secrets setup" | Fork PRs run with repo privileges | Use `pull_request` + scoped triggers; secrets not needed for this CI scope |
| Storing test credentials in repo | Looks harmless but sets precedent | package_check generates its own; nothing to store |
| Uploading full logs as GH artifacts without scrubbing | Secrets persist in artifact storage | Scrub or whitelist what's uploaded |

## UX Pitfalls (maintainer-facing DX here)

| Pitfall | Maintainer Impact | Better Approach |
|---------|-------------------|-----------------|
| CI red with un-actionable log tail | Hours lost in Test_results.log | `-e` interactive mode during debugging; document the triage command in README |
| Mixing CI-fix commits with feature commits | Hard to rebase against upstream bumps | CI fixes get own small PRs; keep `tests.toml` changes separate |
| Assuming green CI == catalog-ready | App review still has extra requirements | Check official linter rules and community app requirements alongside |

## "Looks Done But Isn't" Checklist

- [ ] **Package_check suite:** Often missing *reinstall after remove* and *change_url* coverage — verify `parse_tests_toml.py` dump lists all expected IDs and all pass locally
- [ ] **tests.toml:** Often missing schema line (`#:schema ...tests.v1.schema.json`) and `test_format = 1.0` — verify linter passes
- [ ] **GitHub workflow:** Often missing explicit job timeout + log size awareness — verify a deliberately-failing step surfaces its error in the last ~100 lines
- [ ] **curl_tests:** Often missing asset/JS+CSS coverage (`auto_test_assets`) which catches broken subpath builds
- [ ] **Upgrade test:** Often missing valid `test_upgrade_from.<sha>` pinned to actual known-good commits — verify the referenced commit installs
- [ ] **Secrets:** Often missing an audit of install-script prints — grep scripts for `ynh_print` of env-derived values
- [ ] **Network resilience:** Often missing retry logic on multi-MB upstream fetches — verify by simulating (at least, re-running the suite twice)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| GH-hosted job can't run package_check | LOW | Scope workflow down (linter only), move package_check to self-hosted/local |
| tests.toml causing false failures | LOW | Re-dump parsed tests, fix keys/schemas; fall back to file-removal (auto-deduction) temporarily |
| Flaky-network reds | LOW/MEDIUM | Add retries, rerun the failing test only; add `only =` entry for isolated iteration |
| Secrets leaked in public logs | MEDIUM | Rotate anything real (test creds are throwaway but admin-gen password flows should be reviewed); scrub artifacts |
| Host disk filled by Incus | MEDIUM | Delete stale snapshots/volumes, expand pool, rerun from scratch |
| Wrong upgrade-from SHA (broken historical install) | LOW | Replace `test_upgrade_from.<sha>` with a verified commit on main |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| GH Actions can't run full suite | Phase 1 (scope CI surfaces) | Workflow file contains only hosted-runner-safe jobs |
| package_check stricter than live | Phase 1 recon → Phase 2 fixes | parse_tests_toml dump reviewed; every test ID accounted for |
| tests.toml mistakes | Phase 2 | Linter + schema validation pass |
| Incus/LXC environment conflicts | Phase 1 (env setup) | Local package_check run completes one test end-to-end |
| GH runner time/memory limits | Phase 1 | Any hosted job < ~10 min and < 4GB peak |
| Flaky downloads | Phase 2 | Two consecutive full local package_check runs pass |
| Secrets in logs | Phase 2 + Phase 3 check | Grep install/upgrade scripts for risky prints; manual log read-through |

## Sources

- package_check official README (YunoHost/package_check, main branch) — LXD/Incus requirements, docker conflict, config file, test IDs, curl_tests properties (fetched 2026-09-18) — HIGH
- example_ynh tests.toml current schema/sample (YunoHost/example_ynh main) — format version, schema URL, "you should NOT need" guidance (fetched 2026-09-18) — HIGH
- YunoHost/apps repo workflows — official CI runs on YunoHost infra, GH Actions only handles catalog consistency checks (fetched 2026-09-18) — HIGH
- GitHub-hosted runner specs / 6h job limit / free minutes tiers — GH official docs, standard knowledge — MEDIUM (stable long-running policy)
- linuxcontainers.org Incus networking/docker conflict workarounds (linked from package_check README) — MEDIUM

---
*Pitfalls research for: adding CI validation to librechat_ynh*
*Researched: 2026-09-18*
