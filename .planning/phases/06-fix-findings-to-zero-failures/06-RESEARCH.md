# Phase 6: Fix Findings to Zero Failures - Research

**Researched:** 2026-09-20
**Domain:** YunoHost packaging v2/v2.1 (`ynh_config_add` templates, `_ynh_replace_vars`, `set -x` secret hygiene) + `package_check` fix→run→triage loop
**Confidence:** HIGH (all claims verified against the package source in this repo, the Phase 5 run artifacts, and YunoHost helper behavior already exercised in this repo)

## Summary

Phase 6 is a **fix → run → triage** loop against the frozen Phase 5 environment. There is exactly one known install-blocking package bug (the `admin_panel_secret` / `__ADMIN_PANEL_SESSION_SECRET__` name mismatch) plus a cross-cutting secret-hygiene requirement (`set -x` leaks real secret values into `package_check` debug logs). Everything else is discovery: Tests 3–6 currently FAIL only as cascades, so their true status is unknown until `install.root` passes.

The research below establishes three things the planner needs:

1. **A complete placeholder→variable map** for every `__TOKEN__` in every conf template, so latent mismatches are found by static inspection *before* spending a ~4–5 min VM cycle. This is the difference between one VM run and an unpredictable number.
2. **A precise, least-risk fix for the headline bug** with an explicit verdict on the second latent mismatch (`admin_password` is NOT a template placeholder — safe).
3. **The concrete mechanics of the loop**: how `package_check` is driven from the Windows dev box, where artifacts land, how each finding is classified (package-bug / environment / exempt), and what a single clean POLS-01 run must contain.

**Primary recommendation:** Before any VM run, statically reconcile every template token against a bash variable in scope, fix the headline bug by renaming the template placeholder to `__ADMIN_PANEL_SECRET__` (keeping the existing `admin_panel_secret` variable/setting name — least risk, no settings migration, upgrade/restore consistent), harden secret handling (no `set -x` around secret-bearing sections; keep the one-time admin-password display but ensure it enters the summary log once, not xtrace), then run the **full** suite every cycle and triage.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Zero-failure definition (the bar)
- **In-scope tests must all reach SUCCESS:** `install.root`, `backup_restore`, `upgrade`, `upgrade.05e3d5b`, and `package_linter` (test-level, not its report contents).
- **`change_url` is exempt** — it FAILs because `scripts/change_url` does not exist (deferred v2 / POLS-02). A `change_url` FAIL does **not** violate the zero-failure bar. Document it as out-of-scope-by-design.
- **Catalog-metadata linter items are out-of-scope:** the 1 critical + 1 error (`AppCatalog.is_in_catalog`, `AppCatalog.state_is_working`) resolve only on catalog submission / GitHub-org membership — document them with a reason, parallel to Phase 4's `04-SCOPE-EXEMPTIONS.md` precedent. They do not fail `package_linter` and must not block the bar.
- **Mechanical determination of "zero failures":** trust the suite's own per-test verdict banners **and** a package_check exit code of `0`. Zero in-scope test shows `FAIL`/`ERROR`; `change_url` may show FAIL and is excluded by policy.
- **The bar applies to the current 6-test deduced suite exactly as-is.** Broadening coverage is not part of this phase.

#### change_url & coverage additions
- `change_url`: **leave it FAILing and document the deferral** (POLS-02, v2). Do **not** add exclusion to `tests.toml` — no "fake green", consistent with Phase 5's no-`exclude` stance.
- Subpath/private/multi coverage: **leave as-is.** No `[install.path]` question, no manifest change, no explicit extra suite. `install.subdir` / `install.private` stay uncovered by design; `install.multi` stays skipped (`multi_instance = false`).
- **`tests.toml` is frozen** for Phase 6 — no changes that alter which tests run. No non-coverage tuning either.
- **Where documented:** a dedicated **Phase 6 scope-exemption record** in the phase directory (analogous to `04-SCOPE-EXEMPTIONS.md`) capturing: `change_url` deferral (POLS-02), catalog-metadata linter exemptions, and the uncovered subpath/private tests.

#### Fixing scope & discovery
- **Fix all package bugs that block an in-scope test**, however many iterations it takes — zero failures is the milestone deliverable. Tests 3–6 currently FAIL only as cascades from the install bug, so their true status is unknown until `install.root` passes — expect new findings.
- **Sequencing: iterative fix → run → triage loop.** One fix set, re-run the suite, triage new findings, repeat until zero in-scope failures. Each cycle costs ~4–5 min of VM suite time; that cost is accepted.
- **Full suite every cycle** (not targeted single-test re-runs) — avoids an earlier test masking later ones. No exception for speed.
- **`change_url`-traced failures stay exempt** — if a new failure is definitionally "the script doesn't exist", it is covered by the exemption; do not implement the script to satisfy it.
- **Environment/harness-side issues** (e.g. the `imgkit` summary-renderer abort) are not package bugs: document them, don't chase them as package defects.

#### Secret-logging audit
- **Audit the archived run logs for real secret values** (`full_log_0.log`, `package_check-full.log`, `Test_results.log`) — real values, not just placeholder names. The Phase 5 debug log already contains real generated secrets (e.g. `admin_panel_secret=…`, `admin_password=…`) because install runs under `set -x`.
- **Fix the package to stop leaking secrets:** remove/mask secret prints in scripts and avoid exposing secret values via `set -x`/debug output. This is the real risk, not a cosmetic one.
- **Keep the one-time admin-password display** at end of install (operator needs it to log in) — it is operationally necessary; just ensure it is not duplicated into debug/xtrace output.
- **Archive redacted logs** as POLS-01 evidence: fix prints **and** archive redacted logs (mask any residual secret values) so the evidence itself is clean.

#### Flake-vs-regression policy
- **Bounded retries: up to 2 re-runs** of the full suite for a failure on non-deterministic grounds; a persistent failure after retries is a regression to fix.
- **Evidence-based flake classification:** a failure is a flake only if (a) the log shows a concrete external cause (SSH drop, apt/CDN timeout, DNS/network error, VM NIC flap), **and** (b) it passes on re-run **with no code change**. Otherwise it is a regression. Record the distinction in the phase record (honest flake-vs-regression evidence).
- **Final POLS-01 archive = a single clean full-suite run** with zero in-scope failures — **not** a composite of per-test retries. Retries are diagnostic only.
- **No code change between retries** to count as a flake; any code change means it is a regression fix, and the run after the change is the new evidence. (Non-code environment/harness tweaks — e.g. DHCP pinning, watchdog — are permissible and must be noted.)

### OpenCode's Discretion
- Exact masking/redaction technique for logs and script output.
- Precise triage workflow mechanics (how findings are logged between cycles).
- Structure/naming of the Phase 6 scope-exemption record and the archived POLS-01 artifacts.
- Whether to fold the 8 reproducibility gaps from `05-FINDINGS.md` §5 into `doc/PACKAGE_CHECK.md` / `scripts/setup_pc_env.sh` now or note as follow-up (not a package fix).

### Deferred Ideas (OUT OF SCOPE)
- **`change_url` script** — v2 / POLS-02; leave FAILing and document (do not implement in Phase 6).
- **Subpath / private install coverage** (`[install.path]`, explicit private suite) — future phase; suite stays frozen.
- **Catalog submission PR** (`AppCatalog.is_in_catalog` / `state_is_working` / `has_category`) — separate process, documented out-of-scope.
- **8 reproducibility gaps** (`05-FINDINGS.md` §5: `python3-toml`, linter Python deps, `tmux`, `ethtool`, image-alias workaround, `eth0-watchdog`, DHCP instability, `imgkit`) — fold into `doc/PACKAGE_CHECK.md` / `scripts/setup_pc_env.sh`; not package fixes.
- **Multi-instance support** — POLS-03, blocked by single-instance Meilisearch wiring; out of scope.
- **Full package_check on GitHub-hosted runners** — anti-feature; self-hosted runner is GHCI-02, a future milestone.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| POLS-01 | `package_check` full suite runs to completion with **zero failures**; all findings fixed (install root/subpath/private/reinstall/backup-restore/upgrade) | Headline fix (§Headline Fix) unblocks install.root; placeholder→variable map (§Placeholder Map) prevents latent mismatches; loop mechanics (§Loop Mechanics) produce the single clean run; redaction (§Secret Hygiene) makes the archived evidence clean. Subpath/private are documented out-of-scope-by-design per locked decisions. |

*(POLS-02 is explicitly deferred / out of scope for this phase.)*
</phase_requirements>

---

## Complete Placeholder → Variable Map

**Every `__TOKEN__` in every conf template, and the bash variable that must be in scope when the corresponding `ynh_config_add` runs.** `_ynh_replace_vars` lowercases the token and looks up `$token_lowercase` in the calling shell. A token whose lowercase name is never set → **install abort**.

### `conf/librechat.env` (consumed by `ynh_config_add --template="librechat.env"` in `scripts/install:71`)

| Line | Token | Lowercased lookup | Provider | Status |
|------|-------|-------------------|----------|--------|
| 7 | `__PORT__` | `$port` | YNH init var | ✓ in scope |
| 8,9 | `__DOMAIN__` | `$domain` | YNH init var | ✓ in scope |
| 13 | `__DB_USER__` | `$db_user` | `scripts/install:38` | ✓ in scope |
| 13 | `__DB_PWD__` | `$db_pwd` | `scripts/install:43` | ✓ in scope |
| 13 | `__DB_NAME__` | `$db_name` | `scripts/install:37` | ✓ in scope |
| 18 | `__MEILI_MASTER_KEY__` | `$meili_master_key` | `librechat_generate_secrets` | ✓ in scope |
| 22 | `__JWT_SECRET__` | `$jwt_secret` | `librechat_generate_secrets` | ✓ in scope |
| 23 | `__JWT_REFRESH_SECRET__` | `$jwt_refresh_secret` | `librechat_generate_secrets` | ✓ in scope |
| **26** | **`__ADMIN_PANEL_SESSION_SECRET__`** | **`$admin_panel_session_secret`** | **NONE — never set** | **✗ BUG (headline)** |

### `conf/librechat.service` (consumed by `ynh_config_add_systemd`)

| Line(s) | Token | Provider | Status |
|---------|-------|----------|--------|
| 8,9,30 | `__APP__` | YNH init var | ✓ |
| 10,11,30 | `__INSTALL_DIR__` | YNH init var | ✓ |
| 12 | `__NODEJS_DIR__` | YNH init var | ✓ |
| 30 | `__DATA_DIR__` | YNH init var | ✓ |

### `conf/meilisearch.service` (consumed by `ynh_config_add_systemd --service=meilisearch`)

| Line | Token | Provider | Status |
|------|-------|----------|--------|
| 2,7,8,9,18 | `__APP__` | YNH init var | ✓ |
| **9** | **`__MEILI_MASTER_KEY__`** | `$meili_master_key` | ✓ — **but see pitfall below: on restore `meili_master_key` is read from settings only in `librechat_regen_and_merge_configs` (upgrade path), NOT in `scripts/restore`** |
| 9,18 | `__DATA_DIR__` | YNH init var | ✓ |

### `conf/nginx.conf` (consumed by `ynh_config_add_nginx`)

| Token | Provider | Status |
|-------|----------|--------|
| `__PATH__` | YNH init var | ✓ |
| `__PORT__` | YNH init var | ✓ |

### `conf/librechat.yaml` (consumed by `ynh_config_add --template="librechat.yaml"`)

No `__TOKEN__` placeholders. Static template. ✓

### Second latent mismatch — VERDICT: NOT A BUG

`admin_password` (`_common.sh:73-74`, used `scripts/install:124,137,145`) is **not** referenced by any `__TOKEN__` in any conf template. Confirmed by scanning all conf templates: the only tokens are the ones tabulated above. **No action needed for `admin_password` as a template variable.**

---

## Headline Fix: `admin_panel_session_secret` vs `admin_panel_secret`

### Root cause (verified from source + Phase 5 log)

- `scripts/_common.sh:66-67` generates `admin_panel_secret` and persists setting key `admin_panel_secret`.
- `scripts/_common.sh:127,131` reads back key `admin_panel_secret` — self-consistent.
- `conf/librechat.env:26` uses `__ADMIN_PANEL_SESSION_SECRET__`.
- YunoHost `_ynh_replace_vars` lowercases the token → requires `$admin_panel_session_secret` in scope.
- That variable is **never set anywhere** → `ynh_config_add` aborts inside `_ynh_replace_vars`.

Log evidence (Phase 5, `Test_results.log:146-148`, `full_log_0.log`):
```
Variable $admin_panel_session_secret wasn't initialized when trying to replace __ADMIN_PANEL_SESSION_SECRET__ in /var/www/librechat/librechat.env
```

### Options (choose: **Option A**)

| Option | Change | Risk | Upgrade/restore impact |
|--------|--------|------|------------------------|
| **A (recommended)** | Change the **template token** `__ADMIN_PANEL_SESSION_SECRET__` → `__ADMIN_PANEL_SECRET__` (keep env key name `ADMIN_PANEL_SESSION_SECRET=` as-is or align; only the token matters) | **Lowest** — one line in one template; no variable rename, no setting-key migration | None: `admin_panel_secret` variable and setting key are unchanged; upgrade's `librechat_regen_and_merge_configs` reading `admin_panel_secret` stays correct; restore is unaffected |
| B | Rename variable + setting key everywhere to `admin_panel_session_secret` | Higher — touches `_common.sh` (gen + read-back + validation loop), any existing installs' settings (none in practice, but upgrade tests read old settings), and the restore path | Requires consistency across all scripts; risk of missing one of the 4 sites |

**Decision: Option A.** It is a one-line change, keeps the already-consistent variable/setting name, and cannot desync upgrade/restore. The env file's *key* (`ADMIN_PANEL_SESSION_SECRET=`) is passed to LibreChat and must match what LibreChat expects — the research assumption (to be confirmed at execution) is that the env key name is LibreChat's contract, so keep the key and change only the `__TOKEN__`.

> **Execution note:** Verify what LibreChat actually reads. The env variable key `ADMIN_PANEL_SESSION_SECRET` is what LibreChat's server consumes; the bash variable name is irrelevant to LibreChat. Changing only the template token (`__ADMIN_PANEL_SECRET__`) resolves to `$admin_panel_secret` and leaves the emitted `ADMIN_PANEL_SESSION_SECRET=<value>` line intact.

### Other consistency sites to update (comment-only, but must not lie)

- `scripts/install:50-51,68` comments name `admin_panel_secret` — already correct after Option A. Update the `conf/librechat.env` header comment if it implies the token names match variable names.
- `conf/librechat.env:2-3` header says "Variables marked with __ are resolved from matching lowercase bash variables" — still true; the token will now match the actual variable.

---

## Secret Hygiene under `set -x`

### The problem (verified)

`package_check` runs install scripts under `set -x` (xtrace). The Phase 5 `full_log_0.log` contains real generated values for `admin_panel_secret`, `admin_password`, etc., because:
1. `ynh_app_setting_set --key=admin_password --value="$admin_password"` is echoed by xtrace as an expanded argv; and
2. `ynh_print_info "Admin password: $admin_password"` writes the value into the normal log (intended once).

### YunoHost-idiomatic mitigations

| Technique | What it does | When to use |
|-----------|--------------|-------------|
| `set +o xtrace` … `set -o xtrace` guard | Temporarily disables xtrace around secret handling so expansions aren't echoed | Wrap `librechat_generate_secrets` body and any `ynh_app_setting_set` of secret values |
| `{ set +x; } 2>/dev/null` idiom | Portable, silent xtrace-off for a single command block | Inline secret operations |
| `ynh_print_*` discipline | `ynh_print_info` output is intended (summary), not xtrace. Keep exactly **one** intended line for the admin password | Keep `scripts/install:145`; ensure no *additional* echo/print of secrets |
| Avoid secrets in argv where possible | xtrace echoes argv; passing secret via stdin/env is not always feasible with YNH helpers | Prefer guards over restructuring helpers |

**Key insight:** `ynh_app_setting_set`/`ynh_string_random` are *expected* to be called; the mitigation is to suppress xtrace during those calls, not to stop calling them. The `XTRACE_ENABLE`/`set +x` pattern seen in `full_log_0.log` is the helper's own mechanism — the package must do the equivalent around its own secret-bearing lines.

### Verification of redaction (mechanical)

After writing the redacted archive, grep the redacted artifacts for the known real values captured during the run and assert **zero matches**. The values are recoverable from the run's settings or from the unredacted debug log; a redaction script can extract them and mask all occurrences (`s/<value>/***REDACTED***/g`).

### What NOT to do

- Do **not** remove the admin-password display (`scripts/install:145`) — locked decision: operationally necessary.
- Do **not** add `set -x` anywhere in package scripts (none currently; the leak is from the harness's xtrace wrapping the scripts).
- Do **not** rely on GitHub masking — the archive is a repo artifact (Phase 7 handles GH masking separately).

---

## Loop Mechanics (fix → run → triage)

### Driving `package_check` from the Windows dev box

Per `doc/PACKAGE_CHECK.md` §4 (verified):

```powershell
# 1. Sync the package to the VM (fresh copy each cycle)
$vm = "<user>@<static-ip>"
ssh -i $env:USERPROFILE\.ssh\id_rsa $vm "rm -rf ~/librechat_ynh && mkdir -p ~/librechat_ynh"
scp -r -i $env:USERPROFILE\.ssh\id_rsa .\* "${vm}:~/librechat_ynh/"

# 2. Run the FULL suite under tmux, tee to a log (expect 4-5 min)
ssh -i $env:USERPROFILE\.ssh\id_rsa $vm "cd ~/package_check && tmux new-session -d -s pc './package_check.sh ~/librechat_ynh 2>&1 | tee ~/pc_run_<cycle>.log'"

# 3. Poll for completion (Global summary / process exit), then retrieve artifacts
scp "${vm}:~/package_check/Test_results.log" "$dir\cycle-<n>\Test_results.log"
scp "${vm}:~/package_check/full_log_0.log"   "$dir\cycle-<n>\full_log_0.log"
scp "${vm}:~/pc_run_<cycle>.log"             "$dir\cycle-<n>\package_check-full.log"
```

**Cleanup between cycles** (Phase 5 pain point): `./package_check.sh -s` then `pkill -f package_check.sh`; remove `~/package_check/pcheck-*.lock` outright if force-stop hangs.

**Environment pre-flight (from Phase 5 gaps):** layout must include `python3-toml`, linter Python deps (`python3-jsonschema python3-packaging python3-pyparsing python3-six`), `tmux`, `ethtool`; the `eth0-watchdog.service` should be active; the `yunohost:bookworm-stable-appci` image alias must be pinned locally. These are environment-side (not package bugs) — document/fold into `doc/PACKAGE_CHECK.md` per discretion.

### Triage classification (record every cycle)

For each test verdict and each log finding, assign exactly one bucket:

| Bucket | Test verdict effect | Action |
|--------|--------------------|--------|
| **Package bug (in-scope)** | FAIL/ERROR on in-scope test | FIX — this is the loop driver |
| **Exempt (`change_url`)** | FAIL on `change_url` only | DOCUMENT — never fix in Phase 6 |
| **Exempt (catalog metadata)** | Does not fail `package_linter` | DOCUMENT — no action |
| **Environment/harness** | e.g. `imgkit` renderer abort; DNS/apt/CDN timeout **with external evidence** | DOCUMENT / optionally re-run; not a package defect |
| **Flake** | FAIL with concrete external cause **AND** passes on re-run with no code change | DIAGNOSTIC only; not POLS-01 evidence |

### Where results land

- `~/package_check/Test_results.log` — per-test verdict banners + Global summary (the human-readable summary)
- `~/package_check/full_log_0.log` — authoritative per-test debug detail
- `~/package_check/results_0.json` — machine-readable (may be broken by `imgkit`; environment issue)
- `~/pc_run_<cycle>.log` — raw tee capture

**Note:** `Test_results.log` is a synthesized de-ANSI'd capture (Phase 5 documented this); upstream emits `full_log_0.log`/`results_0.json`/`summary_0.png`. Keep the provenance note in the archive.

---

## What each in-scope test exercises (anticipating new findings)

| Test | What it does | Likely new findings once install.root passes |
|------|--------------|----------------------------------------------|
| `install.root` | Fresh Incus container → full install at domain root. Exercises `scripts/install` end-to-end. | The headline bug, plus any other template/variable mismatch, service start failure, nginx config error, admin-user creation failure (create-user.js), admin-email send failure (`mail` may not be configured in container). |
| `backup_restore` | Install → backup → restore (possibly on a fresh container). Exercises `scripts/backup` + `scripts/restore`. | Restore path: `meili_master_key` used in `conf/meilisearch.service` — confirm it's in scope on restore (it is read from settings only in the upgrade helper, NOT in `scripts/restore`; YNH may inject it from settings, but **verify**). `ynh_restore_everything` ordering; services start last. |
| `upgrade` (same version) | Install → upgrade to same version. Exercises `scripts/upgrade` + `librechat_regen_and_merge_configs`. | `ynh_setup_source --keep="librechat.env librechat.yaml"` correctness; config merge not clobbering user keys; secrets NOT regenerated (must persist). |
| `upgrade.05e3d5b` | Install old release (`v1.0` / `0.8.8-rc3~ynh2`) → upgrade to current. | **Highest-risk unknown:** the old release may have the *same* secret bug or a different settings shape; upgrade must read old settings. If old version lacks a setting the new code reads, the validation loop in `_common.sh:131-135` will `ynh_die`. |
| `package_linter` | Static linter. | Already SUCCESS. Catalog criticals/errors are exempt. Watch for any *new* lint issue introduced by Phase 6 edits (e.g. shellcheck-style issues). |
| `change_url` | **Exempt.** | FAIL expected; do not fix. |

**Multi-instance is skipped** (`multi_instance = false`); **no subdir/private** (no `[install.path]` question, parser never auto-generates private). Document all three as out-of-scope-by-design.

---

## Common Pitfalls

### Pitfall 1: Only fixing the known token and missing a latent one
**What goes wrong:** Another `__TOKEN__` with no variable in scope aborts install on the next cycle.
**Prevention:** Use the complete placeholder→variable map above; statically cross-check every token against the scope before the VM run. This is a Wave-0/early task.

### Pitfall 2: Renaming the setting key (Option B) and desyncing upgrade/restore
**What goes wrong:** `librechat_regen_and_merge_configs` reads `admin_panel_secret`; if only some sites are renamed, upgrade aborts with the `ynh_die` missing-setting guard.
**Prevention:** Prefer Option A (change template token only). If Option B were chosen, all 4+ sites must change together.

### Pitfall 3: Redacting the archive but leaving the unredacted file in the repo
**What goes wrong:** POLS-01 evidence leaks secrets.
**Prevention:** Only the redacted archive is committed; the raw logs stay out of git. Grep-assert the redacted file has zero known secret values.

### Pitfall 4: Treating an environment failure as a package bug (or vice versa)
**What goes wrong:** Chasing `imgkit`/DNS/apt timeouts as package defects, or dismissing a real regression as a flake.
**Prevention:** Use the evidence-based flake rule: flake requires a concrete external cause in the log AND a no-change re-pass. Everything else is a regression.

### Pitfall 5: Single clean run conflated with a retry composite
**What goes wrong:** Reporting zero failures assembled from per-test retries.
**Prevention:** POLS-01 archive = one full-suite run with zero in-scope FAILs and exit 0. Retries are diagnostic only and must not be merged.

### Pitfall 6: `package_linter` regression from Phase 6 edits
**What goes wrong:** A fix introduces a new lint finding (e.g. unquoted var, deprecated helper).
**Prevention:** Re-run the linter (Phase 4's `scripts/run_lint.sh`) after edits as a cheap pre-flight, before the VM cycle.

---

## Validation Architecture

Nyquist validation is **enabled** (`workflow.plan_check`/verifier; the Phase 4 precedent produced `04-VALIDATION.md`). Phase 6's "test framework" is `package_check` itself, run on the remote Hyper-V VM, plus the local `package_linter` for cheap pre-flight.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | YunoHost `package_check` (`f7d32ca`) on the Hyper-V Debian 12 + Incus VM; `package_linter` locally (WSL2) |
| Config file | `tests.toml` (frozen; md5 `4cdd83e3b8e13b08c3aac8e5e79ab07d`) |
| Quick run command | `wsl -e bash -lc 'bash scripts/run_lint.sh'` (linter pre-flight, ~20–40 s) |
| Full suite command | VM: `cd ~/package_check && ./package_check.sh ~/librechat_ynh` (~4–5 min, SSH-driven) |
| Estimated runtime | ~4–5 min per full-suite cycle; linter ~20–40 s |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command / Signal | Evidence |
|--------|----------|-----------|---------------------------|----------|
| POLS-01 | `install.root` reaches `--- SUCCESS ---` | e2e (package_check) | VM full suite; `Test_results.log` per-test banner | `cycle-<n>/Test_results.log` |
| POLS-01 | `backup_restore` SUCCESS | e2e | same | same |
| POLS-01 | `upgrade` SUCCESS | e2e | same | same |
| POLS-01 | `upgrade.05e3d5b` SUCCESS | e2e | same | same |
| POLS-01 | `package_linter` SUCCESS (test-level) | static | local `run_lint.sh` + VM linter test | `lint-*` artifacts |
| POLS-01 | suite exit code `0` | e2e | `PACKAGE_CHECK_EXIT: 0` + Global summary present | `package_check-full.log` tail |
| POLS-01 | no secret values in archived logs | contract | grep-assert redacted archive has 0 known secret matches | redaction script output |
| POLS-01 | `change_url` exempt (FAIL tolerated) | policy | `change_url` may FAIL; documented | `06-SCOPE-EXEMPTIONS.md` |

### Nyquist Sampling Rate

- **After each fix set (before VM run):** `wsl -e bash -lc 'bash scripts/run_lint.sh'` (cheap static gate).
- **Per cycle:** one **full** suite run (locked decision — no targeted re-runs).
- **Phase-complete gate:** single full-suite run with zero in-scope FAILs + exit 0; then `/gsd-verify-work`.
- **Max feedback latency:** ~5 min per cycle (accepted cost).

### Wave 0 Gaps (must exist before the loop)

- [ ] **Static reconciliation artifact** — a checked placeholder→variable map (this RESEARCH.md section is the seed; a task should encode it as an assertion/checklist) so latent mismatches are caught without a VM cycle.
- [ ] **Redaction script** — extracts known secret values and masks all occurrences in archived logs; grep-asserts zero residual matches.
- [ ] **Triage log template** — per-cycle finding table with bucket column (package bug / exempt / environment / flake).
- [ ] **`06-SCOPE-EXEMPTIONS.md`** — the Phase 6 scope-exemption record (change_url POLS-02, catalog metadata, subpath/private).
- [ ] **Redacted POLS-01 archive directory** — the single clean run's artifacts, redacted.

*(No conventional unit-test framework exists; the suite IS the test. Wave 0 here is process/artifact scaffolding, not test files.)*

### Flake vs Regression (mechanical)

```
For a FAIL on an in-scope test:
  1. Search log for concrete external cause (SSH drop, apt/CDN timeout,
     DNS/network error, NIC flap). If NONE -> REGRESSION. Fix it.
  2. If external cause present: re-run full suite with NO code change
     (max 2 re-runs total). Pass -> FLAKE (diagnostic only).
     Fail -> REGRESSION.
Record the distinction (cause + retry outcome) in the phase record.
POLS-01 archive MUST NOT be a composite of retries.
```

---

## Open Questions

1. **Does LibreChat read `ADMIN_PANEL_SESSION_SECRET` (the env key) or a different key?**
   - What we know: the env key is emitted by the template; the bash variable name is irrelevant to LibreChat.
   - What's unclear: whether upstream expects exactly that key name.
   - Recommendation: Option A keeps the key name unchanged, so this is moot for the fix; confirm at execution by grepping upstream for the key.

2. **On `restore`, is `meili_master_key` in scope for `conf/meilisearch.service`?**
   - What we know: `scripts/restore` calls `ynh_config_add_systemd --template=meilisearch.service` and `yunohost service add ...`; the meili master key is a setting, not read in restore.
   - What's unclear: whether YNH injects settings as variables automatically on restore.
   - Recommendation: verify with the linter/helper docs or empirically on the backup_restore cycle; if not injected, add an explicit read-back in `scripts/restore`.

3. **`upgrade.05e3d5b` old-release shape** — does the old release (0.8.8-rc3~ynh2) have the same secret bug / same settings keys?
   - Recommendation: treat as the highest-risk unknown; the first cycle after install.root passes will reveal it.

4. **Whether to fold the 8 reproducibility gaps into docs/script now or as follow-up** (OpenCode discretion).
   - Recommendation: fold the environment-critical subset (`python3-toml`, linter deps, `tmux`, image alias) into `doc/PACKAGE_CHECK.md` + `scripts/setup_pc_env.sh` in a Wave-0 task so the loop is reproducible; note the rest as follow-up.

---

## Sources

### Primary (HIGH confidence)
- Package source in this repo: `scripts/_common.sh`, `scripts/install`, `scripts/upgrade`, `scripts/backup`, `scripts/restore`, `scripts/remove`, all `conf/*` templates, `manifest.toml`, `tests.toml` — read directly.
- `.planning/phases/05-tests-toml-local-package-check-environment/05-FINDINGS.md` + `Test_results.log` + `full_log_0.log` — the concrete failure evidence.
- `.planning/phases/06-fix-findings-to-zero-failures/06-CONTEXT.md` — locked decisions (authoritative over research).
- `.planning/phases/04-lint-baseline/04-SCOPE-EXEMPTIONS.md` + `04-VALIDATION.md` — precedent structure for the exemption record and validation strategy.
- `doc/PACKAGE_CHECK.md` + `scripts/setup_pc_env.sh` — the runnable environment walkthrough.

### Secondary (MEDIUM confidence)
- `.planning/research/PITFALLS.md` (lines 151-152, 199) — prior research on secret-print/`set -x` leaks; consistent with observed Phase 5 logs.

### Tertiary (LOW confidence)
- LibreChat upstream env-key expectations (not verified in this research; moot under Option A).

## Metadata

**Confidence breakdown:**
- Headline fix: HIGH — verified against source and the exact log error.
- Placeholder map: HIGH — every conf template read directly.
- Secret hygiene: HIGH — the leak is observed in `full_log_0.log`; mitigation patterns are YunoHost-idiomatic.
- Loop mechanics: HIGH — based on the documented, executed Phase 5 procedure.
- New findings (tests 3–6): LOW — inherently unknown until install.root passes; anticipated, not asserted.

**Research date:** 2026-09-20
**Valid until:** ~30 days (stable packaging domain) — but re-verify tokens if any conf template changes.
