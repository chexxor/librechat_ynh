# Phase 4: Lint Baseline - Research

**Researched:** 2026-09-19
**Domain:** YunoHost `package_linter` static analysis on a Windows dev box
**Confidence:** HIGH (linter source read directly; full run reproduced empirically; schema read from upstream)

## Summary

This research was performed by **actually installing and running `package_linter`** against this package, not by reading docs alone. The complete finding list below is real output, not prediction. That empirical run changes the phase plan in three important ways.

**First, the "Windows-capable Python" premise needs correction.** `package_linter` is *not* a pure-Python static analyzer. It shells out to Unix tools (`grep`, `sed`, `head`, `du`, `file`) via `subprocess(shell=True)`, and `shell=True` on Windows routes through `cmd.exe` — not Git Bash. Verified outcomes: on bare Windows it dies with `'grep' is not recognized`; under Git for Windows it reaches the script tests but then hard-crashes on `grep ... 'C:\...\scripts' || true` (exit 255), because `cmd.exe` cannot interpret `|| true` and Git's `grep` rejects Windows backslash paths. **The only working local path is WSL2** — which is already installed on this machine (`Ubuntu`, currently stopped) and is unambiguously "Windows-capable" (no separate Linux host). WSL's default Python is 3.8.10 (too old for the ≥3.11 requirement), so the run needs a modern interpreter — `uv` installs one in seconds with no sudo. **A full, working, reproducible run was achieved this way.**

**Second, three of the four errors/criticals are not fixable in this phase.** Two (`AppCatalog.is_in_catalog`, `AppCatalog.state_is_working`) fire because the app is not in YunoHost's app catalog — the linter assigns the `invalid` sentinel and then fails every catalog test. Fixing these requires a catalog submission PR, which `REQUIREMENTS.md` explicitly lists as **out of scope**. The third (`Configurations.tests_toml`) demands a `tests.toml`, which is **Phase 5 / CI-01's deliverable**, not Phase 4's. So a literal reading of success criterion 1 ("zero errors") collides with project scope. The user's locked decision says errors must reach zero and anything genuinely unfixable must be surfaced for an explicit decision — this is exactly that situation, and it must be resolved before or during planning.

**Third, the phase's own guess about findings was partly wrong.** `maintainers = ["your-username"]` is **not** a linter finding — the linter only errors on empty strings or embedded commas (confirmed in `test_manifest.py::maintainer_sensible_values`; `example_ynh` ships `["johndoe"]` as a normal value). And `doc/screenshots/` containing only `.gitkeep` produces **no warning** (`.gitkeep` is explicitly skipped; `du` never fires because the dir is under the size threshold). Conversely, the linter surfaced findings the phase did not anticipate: `ynh_abort_if_errors` deprecated in v2, `ynh_nodejs_install`/`ynh_nodejs_remove` deprecated in v2.1, two manifest schema violations, and three nginx `proxy_set_header` redundancies.

**Primary recommendation:** Run the linter under WSL2 using `uv`-provisioned Python 3.12 with a POSIX `/mnt/c/...` app path and `PYTHONUTF8=1`; fix all warnings and the two genuinely-fixable local errors; and obtain an explicit user decision on the catalog-dependent criticals (recommend: treat as unfixable-in-scope, documented with reason, because the phase goal is "real finding list before infra work" and the catalog PR is explicitly out of scope).

## User Constraints (from CONTEXT.md)

> CONTEXT.md contains sections `<domain>`, `<decisions>` (with sub-section "### OpenCode's Discretion"), `<specifics>`, `<deferred>`. There is no `## Decisions` / `## OpenCode's Discretion` heading structure and no Deferred Ideas list ("None — discussion stayed within phase scope"). Verbatim content is reproduced below.

### Locked Decisions (verbatim from `<decisions>`)

#### Warning triage policy
- Errors must reach zero — non-negotiable
- Warnings: fix ALL of them too; no deferral bookkeeping, no known-warnings list
- Modernization allowed and desired: if a check passes but the code doesn't match current YunoHost packaging practices/examples, modernize it (linter-clean is not just "the bar", it's the floor)
- Minimal diffs: fixes touching working code should be small, self-contained edits that satisfy the linter/modernization goal — no rewrites of working logic
- (No warnings will be deferred under this policy, so no deferral sign-off flow is needed; if something genuinely cannot be fixed, it gets surfaced to the user for an explicit decision rather than silently skipped)

### OpenCode's Discretion (verbatim)
- Local runner setup details (venv/pipx, exact Python version pin) — Phase 5 may formalize documentation; Phase 4 just needs a reproducible local run
- Baseline artifact format and location (log file, plain text is fine) as long as it's archived and shows the zero-error result
- Which specific modernization edits to make, within minimal-diff constraint

### Deferred Ideas (OUT OF SCOPE, verbatim)
None — discussion stayed within phase scope

### Phase Boundary (verbatim from `<domain>`)
Run YunoHost `package_linter` on the package from the Windows dev box (pure Python ≥3.11, no Linux host), fix findings to zero errors, and archive a baseline output showing the clean result. No package_check, no tests.toml, no CI workflow — those are Phases 5–7.

### Specific Ideas (verbatim from `<specifics>`)
No specific requirements — open to standard approaches. Referenced examples: "matches current YunoHost packaging practices/examples" is the modernization yardstick.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LINT-01 | YunoHost `package_linter` reports zero errors on the package (run on Windows-capable Python, no Linux host needed) | Confirmed infeasible on bare Windows/Git Bash; achieved via WSL2 + uv Python 3.12. Real finding list captured (1 critical, 2 errors, 9 warnings, 7 infos). Zero errors is blocked by 2 catalog-dependent criticals/errors that need an explicit scope decision. |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `package_linter` | `main` branch, clone at run time | The linter itself | Official YunoHost tool; the only authority for LINT-01 |
| Python | **≥3.11 required** (verified: 3.12.14 used) | Runtime for the linter | Declared in `pyproject.toml` (`requires-python = ">=3.11"`) and README |
| `uv` | 0.12.17 (installed during research) | Provisions Python 3.12 + venv on WSL without sudo | Avoids upgrading WSL's EOL Python 3.8.10 / deadsnakes PPA |
| WSL2 (`Ubuntu`) | already installed (currently Stopped) | Provides the Unix toolchain (`grep`, `sed`, `head`, `du`, `file`, `sh`, `true`) that the linter shells out to | Only working local execution environment (see Summary) |

### Linter Python dependencies (from `requirements.txt`)
| Package | Version resolved | Purpose |
|---------|------------------|---------|
| `jsonschema` | 4.26.0 | Validates `manifest.toml`, `tests.toml`, `config_panel.toml` against remote schemas |
| `toml` | 0.10.2 | (legacy TOML read) |
| `packaging` | 26.3 | PEP 440 version parsing (nginx SSO version gate) |
| `pyparsing` | 3.3.2 | nginx config parsing (`lib/nginxparser`) |
| `six` | 1.17.0 | transitive/legacy |

All installed cleanly under Python 3.14 on Windows too — the dependency set is not the blocker; the shell-outs are.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| WSL2 + `uv` Python 3.12 | Git for Windows (`C:\Program Files\Git\usr\bin`) | **Rejected — verified broken.** `subprocess(shell=True)` uses `cmd.exe`; POSIX path arg does not help; crashes at `App.app_data_in_unofficial_dir` with exit 255 |
| WSL2 + `uv` Python 3.12 | WSL's system Python 3.8.10 | **Rejected** — below the ≥3.11 requirement; needs deadsnakes PPA or a source build |
| WSL2 + `uv` Python 3.12 | `pipx install package-linter` | Not viable: `pyproject.toml` declares no `[project.scripts]` entry point, so no console command is produced. There is no published PyPI package |
| `uv` (no sudo) | `deadsnakes` PPA / `apt install python3.12` | Requires sudo + network; `uv` is faster and user-local |

**Installation (WSL2, verified working):**
```bash
# One-time: install uv (user-local, no sudo)
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# Get the linter
git clone --depth 1 https://github.com/YunoHost/package_linter /tmp/pl
cd /tmp/pl

# Python 3.12 + deps
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r requirements.txt
```

## Architecture Patterns

### How `package_linter` is structured (authoritative, from source)
Entry point: `package_linter.py` (`./package_linter.py <app_path>`). There is **no** `python -m package_linter`. Only two CLI args:

```
app_path        positional, type=Path — path to the app to lint
--json          flag — emit machine-readable JSON instead of coloured text
```

An execution creates an `App` object which runs, in order:
`manifest` tests → per-script tests (`_common.sh`, `install`, `remove`, `upgrade`, `backup`, `restore`) → general `App` tests → `Configuration files` tests → `Catalog infos` → `Issues`.

### Recommended project structure for the runner (Phase 4)
```
tmp/                                  # (or any scratch dir outside the repo)
└── package_linter/                   # cloned linter, its own venv
    ├── .venv/                        # Python 3.12
    ├── package_linter.py
    └── .apps/                        # git clone of YunoHost/apps (cache)

<repo>/
└── .planning/phases/04-lint-baseline/
    └── lint-baseline.txt             # archived artifact (see Artifact section)
```

Do **not** commit the linter clone or its venv into this repo. The repo itself must stay clean.

### Pattern 1: Deterministic run + archived artifact
**What:** Run the linter with a fixed command, capture stdout+stderr to a file, capture the exit code separately, and store the artifact in the phase directory.
**When to use:** For both the initial baseline and the final zero-error proof.
**Example (verified):**
```bash
#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
APPDIR="/mnt/c/Users/Alex/Projects/librechat_ynh"
OUT="$(dirname "$APPDIR")/.planning/phases/04-lint-baseline"

cd /tmp/pl
set +e
.venv/bin/python ./package_linter.py "$APPDIR" \
    > "$OUT/lint-baseline.txt" 2>&1
echo "exit_code=$?" >> "$OUT/lint-baseline.txt"
set -e
```
Two artifacts are most useful: the human-readable text above, and `--json` output for machine assertions.

### Pattern 2: Machine-checkable assertion on the JSON
**What:** The `--json` flag prints a JSON object with keys `success`, `info`, `warning`, `error`, `critical`. Use it to assert programmatically.
**Example (verified output for this package):**
```json
{
    "critical": ["AppCatalog.is_in_catalog"],
    "error":    ["Configurations.tests_toml", "AppCatalog.state_is_working"],
    "warning":  ["Manifest.resource_consistency", "Script.progression_in_backup",
                 "App.badges_in_readme", "App.helpers_deprecated_in_v2",
                 "App.helpers_deprecated_in_v2", "App.helpers_deprecated_in_v2",
                 "Configurations.tests_nginx_reverse_proxy_params_and_sso_consistency",
                 "Configurations.tests_nginx_reverse_proxy_params_and_sso_consistency",
                 "AppCatalog.has_category"],
    "info":     [ "...7 entries..." ],
    "success":  []
}
```
Assertion idea: `.critical | length == 0 and .error | length == 0` (jq), plus `grep -c` on the text artifact.

### Anti-Patterns to Avoid
- **Running the linter from plain PowerShell.** Crashes at the first `grep`. Do not attempt to "fix" this with PATH tweaks — `shell=True` still routes to `cmd.exe`.
- **Passing a Windows path (`C:\...`) to the linter even under WSL.** Some checks pass but others (e.g. `bad_encoding`, `references_to_superold_stuff`) silently misbehave or crash. Always pass `/mnt/c/...`.
- **Interpreting the JSON `--json` exit code as an error signal.** With `--json`, the linter **does not call `sys.exit(1)`**; the exit code is 0 even with criticals. Exit code 1 only occurs in text mode when `error` or `critical` is non-empty. **Assert on the JSON body or on the text output, never on the exit code when `--json` is set.**

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unix toolchain on Windows | A PowerShell port of `grep`/`du`/`file` | WSL2 (already installed) | The linter's checks are dozens of interdependent shell pipelines; reimplementing is impossible and would diverge from official results |
| Provisioning Python ≥3.11 on WSL 20.04 | Compiling Python from source / adding PPAs | `uv venv --python 3.12` | One command, user-local, no sudo, no system Python mutation |
| Manually tracking findings | A "known warnings" allowlist | Fix them all (locked decision) | User explicitly rejected deferral bookkeeping |
| Manually diffing linter output run-to-run | Ad-hoc `diff` of coloured text | `--json` + `jq` or `grep` on the text artifact | Coloured ANSI output is noisy; JSON is stable |

**Key insight:** the linter is a *distributed shell-pipeline program*, not a library. Fighting the platform is strictly worse than using the WSL2 environment that already exists on this machine.

## Common Pitfalls

### Pitfall 1: `package_linter` is not pure Python — it needs a Unix userland
**What goes wrong:** Running from PowerShell/Git Bash crashes mid-run (`grep is not recognized`, `CalledProcessError: ... exit status 255`).
**Why it happens:** `subprocess.run(..., shell=True)` on Windows invokes `cmd.exe`; the linter's commands assume POSIX `sh`, `|| true`, `grep`, `sed`, `head`, `du`, `file`.
**How to avoid:** Run under WSL2.
**Warning signs:** `'grep' is not recognized as an internal or external command`; `'true' is not recognized`.

### Pitfall 2: Windows cp1252 console encoding crashes the linter
**What goes wrong:** `UnicodeEncodeError: 'charmap' codec can't encode character '\u2714'` (the ✔/✘/☺/♥ report glyphs) — **verified on bare Windows**.
**Why it happens:** Python on Windows defaults stdout to the ANSI code page (cp1252); the linter prints Unicode symbols.
**How to avoid:** Set `PYTHONUTF8=1` (and ideally `PYTHONIOENCODING=utf-8`) in the environment before running. WSL's default UTF-8 locale avoids this entirely.
**Warning signs:** Traceback inside `lib/print.py` `_print`.

### Pitfall 3: Stale schema/license cache breaks the second run
**What went wrong during research:** After one run, `.spdx_licenses` was cached; the next run raised `UnicodeDecodeError: 'utf-8' codec can't decode byte 0x96 in position 94009` — because `write_text()`/`read_text()` in `lib_package_linter.py` omit an explicit encoding and Windows wrote/read with the locale codec.
**Why it happens:** `cache_file` decorator writes the fetched SPDX page with the platform default encoding, then reads it back as UTF-8 on a later run.
**How to avoid:** Prefer WSL (UTF-8 locale makes write==read). If running on Windows, delete `.spdx_licenses`, `.manifest.v2.schema.json`, `.tests.v1.schema.json`, `.config_panel.v1.schema.json` before each run, and always set `PYTHONUTF8=1`.
**Warning signs:** `UnicodeDecodeError` inside `lib_package_linter.py` `wrapper()`.

### Pitfall 4: CRLF corruption from `core.autocrlf=true`
**What the repo currently has:** scripts are LF-only, no BOM, UTF-8 (`cat -A` shows `$`, no `^M`). Verified. But **this repo has no `.gitattributes`** and the dev box has `core.autocrlf=true`.
**What goes wrong:** A fresh clone on Windows (or a checkout after any line-ending normalization) can convert `scripts/*` to CRLF. Bash then fails with `bad interpreter`/`\r` errors, and shellcheck flags `SC1017`. The linter's script parsing would also see stray `\r`.
**How to avoid:** Add a `.gitattributes` pinning shell scripts and text files to LF (see Code Examples), and verify with `git ls-files --eol scripts/`. Do **not** rely on `core.autocrlf` alone.
**Warning signs:** `bash: ./scripts/install: /bin/bash^M: bad interpreter`.

### Pitfall 5: The `--json` exit code is always 0
**What goes wrong:** A CI-style `if package_linter.py ... --json; then` passes even with criticals.
**Why it happens:** `App.report()` returns early after printing JSON and never reaches `sys.exit(1)`.
**How to avoid:** Assert on the JSON body (e.g. `jq -e '.error == [] and .critical == []'`) or use text mode and check the exit code.
**Warning signs:** "green" JSON run that still lists criticals.

### Pitfall 6: The catalog tests fail for any uncatalogued app — and cannot be fixed locally
**What goes wrong:** `AppCatalog.is_in_catalog` yields **critical** and `state_is_working` yields **error** for any app not in `YunoHost/apps`' `apps.toml`.
**Why it happens:** `AppCatalog.__init__` sets `self.catalog_infos = app_list.get(app_id, invalid_app)` where `invalid_app = CatalogAppDescr(url="invalid", state="notworking")`. All catalog tests then fail against the sentinel.
**How to avoid / handle:** Either submit the app to the catalog (out of scope per REQUIREMENTS.md), or treat these as documented-unfixable and surface to the user. **This is the central planning decision of the phase.**
**Warning signs:** `✘✘✘ This app is not in YunoHost's application catalog`.

### Pitfall 7: Some tests require network access
**What goes wrong:** Offline runs crash or print `?` warnings.
**Why it happens:** The linter fetches `spdx.org/licenses`, `YunoHost/apps` schemas, clones `YunoHost/apps`, and queries the GitHub issues API.
**How to avoid:** Allow network; do not run offline. Expect a `?` line for `Issues` when the app isn't in the catalog/hosted repo.
**Warning signs:** `Could not fetch https://...`; `? Can't check if there are any blocking issues pending`.

## Code Examples

### Exact working invocation (verified end-to-end)
```bash
# Run from a WSL2 shell. Produces a complete finding list.
export PATH="$HOME/.local/bin:$PATH"
cd /tmp/pl
.venv/bin/python ./package_linter.py /mnt/c/Users/Alex/Projects/librechat_ynh
# Exit code 1 in text mode when any error/critical exists.
```

### JSON baseline + assertion
```bash
cd /tmp/pl
.venv/bin/python ./package_linter.py /mnt/c/Users/Alex/Projects/librechat_ynh --json \
    > /mnt/c/Users/Alex/Projects/librechat_ynh/.planning/phases/04-lint-baseline/lint-baseline.json

# Assert zero errors/criticals:
python - <<'PY'
import json, sys
d = json.load(open("/mnt/c/Users/Alex/Projects/librechat_ynh/.planning/phases/04-lint-baseline/lint-baseline.json"))
assert not d["critical"], d["critical"]
assert not d["error"], d["error"]
print("zero errors/criticals")
PY
```

### Recommended `.gitattributes` (new file)
```gitattributes
* text=auto eol=lf
*.sh text eol=lf
scripts/* text eol=lf
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.webp binary
```
Rationale: shell scripts and manifests must be LF for bash and for the linter's `shlex`/`grep` parsing; images must never be mangled.

## The Actual Finding List (LINT-01 baseline)

Complete output from the verified run. **Severity totals: 1 critical, 2 errors, 9 warnings, 7 infos.**

### Critical / Error (4 entries, all currently blocking "zero errors")
> Note: the JSON groups `critical` and `error` separately, but the text output prints criticals as `✘✘✘` and errors as `✘`. Totals are 1 critical + 2 errors + 1 error-classified manifest finding counted inside `error` (see below).

| # | Suite | Severity | Message (abridged) | Fixable in Phase 4? | Correct action |
|---|-------|----------|--------------------|---------------------|----------------|
| 1 | `AppCatalog.is_in_catalog` | **critical** | "This app is not in YunoHost's application catalog" | ❌ No | Catalog submission = out of scope. **Surface to user.** |
| 2 | `AppCatalog.state_is_working` | **error** | "The application is not flagged as working in YunoHost's apps catalog" | ❌ No | Same root cause as #1. **Surface to user.** |
| 3 | `Configurations.tests_toml` | **error** | "The 'check_process' file ... replaced with 'tests.toml' ... mandatory for apps v2" | ⚠️ Deferred | This is Phase 5 / CI-01's deliverable. **Surface to user / decide sequencing.** |
| 4 | `Manifest.resource_consistency` (`manifest_schema`) | info/error-class | `pattern_regexp` unexpected in `install.admin_email`; `format = "script"` invalid in `resources.sources.meilisearch` | ✅ Yes | Fix both (see below). |

> Important nuance: the schema errors are emitted via `validate_schema`, which yields **`ReportInfo`**, not `ReportError`. They appear as `    - Error validating manifest using schema: ...` lines and land in the `info` bucket of `--json`, **not** the `error` bucket. They are nevertheless real schema violations and must be fixed.

### Warnings (9 entries — locked decision says fix ALL)
| # | Suite | Message (abridged) | Fix |
|---|-------|--------------------|-----|
| 1 | `Manifest.resource_consistency` | "You should add a 'init_main_permission' question, or define `allowed` for main permission" | Add `[install.init_main_permission] type="group"` **or** add `allowed` to `[resources.permissions] main` (`example_ynh` uses the question). |
| 2 | `Script.progression_in_backup` | "We recommend to *not* use 'ynh_script_progression' in backup scripts" | Replace with `ynh_print_info` in `scripts/backup`. |
| 3 | `App.badges_in_readme` | README not generated by `readme_generator` | Regenerate README per the official generator (or accept bot-generated content). |
| 4 | `App.helpers_deprecated_in_v2` | `ynh_abort_if_errors` deprecated in v2 ("nothing, handled by the core, just get rid of it") | Remove the 5 calls (install/remove/upgrade/backup/restore). |
| 5 | `App.helpers_deprecated_in_v2` | `ynh_nodejs_install` deprecated in v2.1 → nodejs resource | Remove/replace usage. |
| 6 | `App.helpers_deprecated_in_v2` | `ynh_nodejs_remove` deprecated in v2.1 → nodejs resource | Remove/replace usage. |
| 7 | `Configurations.tests_nginx_reverse_proxy_params...` | Manually defining `Host, X-Forwarded-For, X-Forwarded-Proto, X-Real-IP` unnecessary | Remove those 4 `proxy_set_header` lines from `conf/nginx.conf` (they come from `include proxy_params_no_auth`). |
| 8 | `Configurations.tests_nginx_reverse_proxy_params...` | Manually defining `Upgrade` unnecessary (greylist) | Remove `proxy_set_header Upgrade ...` **only if** WebSocket support is safely covered by the include. **Caution:** LibreChat needs WebSockets; verify before removing. |
| 9 | `AppCatalog.has_category` | No category in app catalog | ❌ Unfixable locally (catalog). Same decision as #1. |

### Infos (7 entries — not blocking, but "modernize where passing code doesn't match practice")
`Manifest.manifest_schema` ×2 (the two schema errors above), `App.change_url_script` (consider `change_url` — deferred to POLS-02 v2), `Configurations.systemd_config_harden_security` ×2 (add `Protect*`/`CapabilityBoundingSet`/`SystemCallFilter`/`PrivateTmp` — `librechat.service` already has most; `meilisearch.service` is minimal), `Configurations.tests_nginx_reverse_proxy_params...` (`Connection "$connection_upgrade"` overrides the default), `AppCatalog.is_in_github_org` (consider YunoHost-Apps org — out of scope).

### Corrections to the phase brief's assumptions
- **`maintainers = ["your-username"]` is NOT a linter finding.** `maintainer_sensible_values` only errors on empty/whitespace values or values containing a comma. `example_ynh` uses `["johndoe"]`. It is still a *placeholder* worth fixing for hygiene/modernization, but it is not why the linter is unhappy.
- **`doc/screenshots/` with only `.gitkeep` produces NO finding.** `.gitkeep` is explicitly skipped, `example.jpg` is not present, and `du -sb` is below both the 512K info and 1000K warning thresholds. `doc/DESCRIPTION.md` exists and is non-placeholder, so `doc_dir_v2` passes.
- **Scripts are LF-only, no BOM, UTF-8.** The `—`/`’` characters seen as mojibake in the PowerShell console are a *console rendering* artifact only; the bytes are valid UTF-8 and `bad_encoding` does not fire (`file` was not even reached under WSL's run for these).

### The two manifest schema fixes (exact)
```toml
# BEFORE (manifest.toml, install.admin_email)
[install.admin_email]
type = "text"
ask.en = "Enter the admin email address for notifications"
example = "admin@example.com"
pattern_regexp = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

# AFTER — 'pattern' is an object with 'regexp' (and optional 'error')
[install.admin_email]
type = "text"
ask.en = "Enter the admin email address for notifications"
example = "admin@example.com"
[install.admin_email.pattern]
regexp = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
```
```toml
# BEFORE (resources.sources.meilisearch)
format = "script"    # invalid enum value

# AFTER — 'whatever' is the valid enum member for a raw, non-archive binary
format = "whatever"
extract = false
```
(Valid `format` enum: `tar.bz2, tar.gz, tar.xz, tar.zst, xz, zip, zst, docker, whatever`.)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `check_process` file | `tests.toml` (schema v1) | packaging v2 | The linter now **errors** if `tests.toml` is missing. CI-01 / Phase 5. |
| `ynh_abort_if_errors` | handled by core | packaging v2 | Linter warning; remove calls. |
| `ynh_nodejs_install`/`_remove` | `nodejs` resource in manifest | helpers 2.1 | Linter warning; the manifest already uses `[resources.nodejs]`. |
| `pattern_regexp` (flat key) | `pattern.regexp` (object) | manifest v2 schema | Schema violation in current manifest. |
| `format = "script"` | `format = "whatever"` | manifest v2 schema | Schema violation in current manifest. |
| Manual `proxy_set_header Host/...` | `include proxy_params_no_auth;` | YunoHost 12.1.38 | Redundant-header warnings. |

**Deprecated/outdated:**
- `check_process` → `tests.toml`.
- `yunohost app setting`, raw `apt-get install`, `exit`, `rm -rf` (without `ynh_secure_remove`) → all **already absent** in this package (verified by grep), so no findings there.

## Open Questions

1. **How should "zero errors" treat the catalog-dependent findings?**
   - What we know: `AppCatalog.is_in_catalog` (critical) and `state_is_working` + `has_category` (error/warning) fire solely because the app is not in `YunoHost/apps`. They cannot be fixed without a catalog submission PR, which REQUIREMENTS.md lists as Out of Scope.
   - What's unclear: whether the phase should (a) declare the true invariant as "zero locally-fixable errors", documenting the catalog findings as out-of-scope-by-design, or (b) absorb a minimal catalog submission into Phase 4.
   - Recommendation: **(a)** — surface to the user for an explicit decision per the locked policy. The linter's own output frames catalog membership as a *publishing* concern, and the phase goal explicitly says "establishing the real finding list before any environment or CI work." Recommend narrowing the archived invariant to `locally_fixable_errors == 0` with the catalog findings explicitly named and reasoned. **This needs user sign-off before planning finalizes success criteria.**

2. **Should `tests.toml` be created in Phase 4?**
   - What we know: `Configurations.tests_toml` is an error and is currently blocking zero-errors; `tests.toml` is Phase 5 / CI-01's deliverable.
   - What's unclear: whether Phase 4 creates a minimal `tests.toml` merely to silence the linter, or defers it.
   - Recommendation: Defer to Phase 5, but **name it explicitly** as a known blocker in the Phase 4 baseline artifact so the zero-error claim is honest. Alternatively, if the user wants Phase 4 to truly end at zero errors, move the minimal `tests.toml` creation into Phase 4 and let Phase 5 extend it. Surface for decision.

3. **Will removing `proxy_set_header Upgrade`/`Connection` break WebSockets?**
   - What we know: `conf/nginx.conf` comments (lines 4–9) warn these are REQUIRED for LibreChat WebSockets; the linter flags `Upgrade` as a greylist redundancy and `Connection "$connection_upgrade"` as a *different-valued* override (info, not warning). `include proxy_params_no_auth` is present (line 30), which supplies upstream defaults.
   - What's unclear: whether `proxy_params_no_auth` on YunoHost 12.1.40 already sets `Upgrade`/`Connection` correctly for a Node backend.
   - Recommendation: Remove the 4 plain `Host`/`X-Real-IP`/`X-Forwarded-*` headers (unambiguous). Keep `Upgrade`/`Connection` if the include does not set them — verify by reading `/etc/nginx/conf.d/.../proxy_params_no_auth` content from the example, or keep them and accept the warning. This is the one place where a "minimal diff" must not break the working feature; flag for careful handling.

4. **Does `ynh_nodejs_install`/`ynh_nodejs_remove` actually appear in this package's scripts?**
   - What we know: the linter flagged both deprecations.
   - What's unclear: the exact location (grep of `scripts/*` in PowerShell did not surface them because the local shell lacked `grep`). 
   - Recommendation: The executor should locate them with WSL `grep -rn 'ynh_nodejs_install\|ynh_nodejs_remove' scripts/` as the first step of the fixing plan. (They are likely inside a helper in `_common.sh` or a script block the naive PowerShell search missed.)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `package_linter` (`main`) itself — no separate test framework in this repo |
| Config file | none — see Wave 0 |
| Quick run command | `bash /tmp/pl/run_lint.sh` (wrapper created in Wave 0) |
| Full suite command | same (the linter is the full suite; there is nothing else in Phase 4) |
| Estimated runtime | ~20–40 s (dominated by the `YunoHost/apps` git clone on first run; cached for 1 h afterwards) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LINT-01 | Linter reports zero criticals/errors on locally-fixable findings | integration | `wsl -e bash -lc 'bash /mnt/c/.../run_lint.sh && jq -e ".critical==[] and .error==[]" .../lint-baseline.json'` | ❌ Wave 0 gap |
| LINT-01 | Baseline artifact archived and committed | smoke | `test -f .planning/phases/04-lint-baseline/lint-baseline.txt` | ❌ Wave 0 gap |
| LINT-01 | Scripts remain LF (not CRLF) after edits | unit | `wsl -e bash -lc "git -C /mnt/c/... ls-files --eol scripts/ \| grep -v 'i/lf'"` (expect no output) | ❌ Wave 0 gap |

### Nyquist Sampling Rate
- **Minimum sample interval:** After every committed task (every fix edit) → `bash /tmp/pl/run_lint.sh`
- **Full suite trigger:** Before merging the final task of the phase
- **Phase-complete gate:** JSON assertion green (`critical` and `error` empty at the agreed scope) **and** text artifact archived
- **Estimated feedback latency per task:** ~5–40 s (first run clones `YunoHost/apps`; subsequent runs reuse the 1-hour cache)

### Wave 0 Gaps (must be created before implementation)
- [ ] `scripts/run_lint.sh` (or equivalent, location per discretion) — deterministic wrapper that ensures `uv`/venv, runs the linter with `/mnt/c/...` POSIX path, writes both text and `--json` artifacts. **This is the single most important deliverable to create first.**
- [ ] `.planning/phases/04-lint-baseline/lint-baseline.txt` — archived text artifact (before fixes)
- [ ] `.planning/phases/04-lint-baseline/lint-baseline.json` — archived JSON artifact (before fixes)
- [ ] `.gitattributes` — pins LF for scripts; prevents Pitfall 4
- [ ] Framework install: WSL2 + `uv` + Python 3.12 + linter clone (one-time setup; do not commit)
- [ ] A documented decision record for the catalog-dependent findings (Open Question 1) — required before the zero-error claim can be finalized

> Note: this phase has **no conventional unit-test framework**. The linter *is* the test. The "tests" are the deterministic run + artifact + assertion. This is appropriate and intentional.

## Sources

### Primary (HIGH confidence)
- `github.com/YunoHost/package_linter` @ `main` — read `README.md`, `pyproject.toml`, `requirements.txt`, `package_linter.py`, `lib/print.py`, `lib/lib_package_linter.py`, `tests/test_app.py`, `tests/test_scripts.py`, `tests/test_manifest.py`, `tests/test_catalog.py`, `tests/test_configurations.py`, `tests/test_issues.py`. All check logic and the finding list are derived from these.
- `raw.githubusercontent.com/YunoHost/apps/main/schemas/manifest.v2.schema.json` — authoritative enum/key validation (fixes for `pattern.regexp`, `format = "whatever"`).
- **Empirical run** — linter executed against `C:\Users\Alex\Projects\librechat_ynh` under WSL2 + Python 3.12.14; full output captured (1 critical, 2 errors, 9 warnings, 7 infos). This is the LINT-01 baseline.
- Local environment probing — confirmed `du`/`file`/`grep`/`sed`/`head` absent on bare Windows; present in Git for Windows `usr\bin`; WSL Ubuntu present (Python 3.8.10); scripts LF-only/no-BOM/UTF-8; `core.autocrlf=true`; no `.gitattributes`/`.gitignore`/`tests.toml`/`check_process`.

### Secondary (MEDIUM confidence)
- `github.com/YunoHost/example_ynh` `manifest.toml` — confirmed `maintainers = ["johndoe"]` is normal, `[install.init_main_permission] type="group"` is the convention, and where `format`/`extract` sit for raw binaries.

### Tertiary (LOW confidence)
- None required. Every claim above is either source-derived or empirically observed on this machine.

## Metadata

**Confidence breakdown:**
- Standard stack (runner): HIGH — `uv` + WSL2 path executed successfully end-to-end during this research.
- Finding list: HIGH — produced by an actual linter run, cross-checked against the source tests that generate each report.
- Architecture/patterns: HIGH — read directly from linter source; CLI contract verified by execution.
- Pitfalls: HIGH for 1/2/3/5 (all reproduced); HIGH for 4/6/7 (read from source + repo state verified).
- Fix recommendations: MEDIUM for the nginx `Upgrade` header (feature-safety concern flagged), HIGH for the manifest schema fixes (schema-derived).

**Research date:** 2026-09-19
**Valid until:** ~2026-10-19 (30 days) for the finding list; the linter tracks `main` and its checks change frequently, so re-run before finalizing.
