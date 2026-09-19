# Architecture Patterns

**Project:** librechat_ynh — CI validation (v1.1)
**Researched:** 2026-09-18
**Mode:** Project research — how CI integrates with the EXISTING package repo

## Current Repo State (verified)

File-by-file inspection of the repo at `HEAD = e834aea`:

| Existing file/dir | Status | Notes for CI |
|---|---|---|
| `manifest.toml` | ✅ exists, packaging v2 | Install args: `domain` (type=domain) + `admin_email` (type=text, regex-pattern). **`admin_email` is NOT auto-guessable by package_check → tests.toml must supply it.** `multi_instance = false` declared with inline comment. `yunohost = ">= 12.1.40"`, helpers 2.1. |
| `scripts/install` | ✅ ~200+ lines | Calls `ynh_install_mongo`, `ynh_setup_source` (main + meilisearch→`/usr/bin`), `ynh_mongo_setup_db` |
| `scripts/remove` | ✅ 84 lines | |
| `scripts/backup` / `restore` | ✅ 60 / 78 lines | mongodump round-trip |
| `scripts/upgrade` | ✅ 81 lines | |
| `scripts/_common.sh` | ✅ 184 lines | `mongo_version` etc. |
| `conf/` | ✅ env, librechat.yaml, 2 systemd units, nginx.conf | |
| `config_panel.toml` | ❌ absent | Fine — explicitly out of scope (PROJECT.md) |
| **`tests.toml`** | ❌ **ABSENT** | This is the primary new file package_check needs |
| **`.github/`** | ❌ **ABSENT** | No workflows; GH Actions must be added from scratch |
| `doc/description.md`-style assets | ✅ `doc/DESCRIPTION.md` | Used by YNH catalog linter |

## Recommended Architecture

```
librechat_ynh/
├── manifest.toml            (minor edits, see below)
├── tests.toml               NEW — test-args + test-type gate for package_check
├── .github/
│   └── workflows/
│       ├── package_check.yml       NEW — runs package_check on ubuntu runner
│       └── lint-and-format.yml     NEW (optional) — ynh linters / manifest lint
├── scripts/                 (edits driven by package_check findings)
└── conf/                    (unchanged)
```

### Component Boundaries

| Component | Responsibility | Feeds / Consumes |
|-----------|---------------|------------------|
| `tests.toml` | Declares args package_check substitutes at install; declares which test types (manifest, install, backup, remove, upgrade) run; can exclude via `exclude = [...]` | Read by package_check both locally and in GH CI |
| `.github/workflows/package_check.yml` | Checks out repo + package_check, runs `package_check.sh --list`/full run on the checkout, uploads report artifact | Exits non-zero on failure → red build |
| `package_check` (external, cloned at CI time) | Boots YunoHost test container (`--lxc` locally) and executes the full lifecycle using `manifest.toml` + `tests.toml` | Modifies nothing in repo; findings cause script edits |
| Official YunoHost app CI (apps.yunohost.org) | Separate — once the app is submitted to the catalog, YunoHost's infra runs its own package_check automatically. Local workflow is pre-merge gate, not a replacement | — |

## CI Integration Details

### 1. `tests.toml` (new) — package_check's test contract

Package check reads `tests.toml` at the package root. Key declarations mapped to THIS manifest:

```toml
test_format = 1.0

[default]
    # Required by scripts/install — provide placeholder secrets/emails
    preinstall = """
    # package_check env tweaks if needed
    """
    args.admin_email = "admin@example.com"
    args.domain = "domain.tld"            # package_check handles domain arg itself, but be explicit

    test_upgrade_from.<id>.name = "v1.0 (0.8.8-rc3~ynh1)"   # enables upgrade test from tagged ancestor
    #   (only when a prior packaged version exists on a branch/URL — optional for v1.1, HIGH-value later)
```

Test-coverage implications from manifest declarations:

| Manifest declaration | package_check behavior | Needed action |
|---|---|---|
| `multi_instance = false` | Skips double-install test | Nothing |
| `install.admin_email` (text arg) | Would block/prompt → install test fails without args | Must set `args.admin_email` in tests.toml |
| `ram.build = "2G"` | package_check enforces RAM budget; build (npm ci + vite build) is heavy | Keep 2G honest or bump; likely fine |
| `resources.nodejs` version 24 | Helpers install Node from nodesource inside test container | Nothing (ymh helpers 2.1 handles it) |
| Meilisearch `/usr/bin` write | Install happens inside LXC/docker as root — allowed | Nothing |
| `ynh_install_mongo` (MongoDB 7.0 apt repo) | Adds extra install time; package_check timeout for install is generous (default ~10 min default? tired not verified — watch for timeout-on-slow-runner findings) | Flag: Mongo + npm build may push install past default timeouts → consider `--timeout`, or accept a LENGTHY warn |
| `data_dir` + mongodump backup | backup/restore test type covers it | Declare nothing special |

Tests to enable (types package_check runs when files exist): **manifest, install, remove, backup, restore, upgrade**. All script files exist → all test types can run day one.

### 2. `package_check.yml` (new)

Two sane patterns; recommend B for this repo:

**A. Debian package / container:** clone `YunoHost/package_check`, `--container` mode. Works on plain ubuntu runners, no ynh server needed.

**B. Official reusable workflow (simplest, current):** the YunoHost community standard is a thin workflow that clones package_check and runs it in container mode on every push/PR, saving the HTML/text report as an artifact and failing the job on any ERROR-level finding. Keep it minimal — a ~30-line workflow:

```yaml
name: package_check
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }      # upgrade-from tests may need ancestors
      - name: Run package_check
        run: |
          git clone --depth=1 https://github.com/YunoHost/package_check
          package_check/package_check.sh --container --branch="$BR" .
        env: { BR: ${{ github.ref_name }} }
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: report, path: tests-URL-*.txt }   # capture whatever report name is produced
```

(Low-confidence details: exact flag names and artifact paths should be confirmed against the package_check README during implementation — the repo has good docs.)

### 3. What gets MODIFIED instead of added

Expect package_check findings (not failures) to map to script edits. Predicted, based on manifest content — each is a LOW→MEDIUM-confidence hypothesis to be resolved by actually running CI:

- `manifest.toml`: inline trailing comments on values (e.g. `multi_instance = false # ...`, `main.default = 3080  # ...`) — packaging linter has historically flagged comments on non-string lines; may need comment removal above the key.
- `manifest.toml` `maintainers = ["your-username"]` placeholder → catalog lint would flag; fix to real github handle.
- `scripts/install`: package_check's clean-room LXC will likely surface (a) Mongo GPG/timeouts, (b) `unrun`/postinstall ordering, (c) missing `ynh_script_progression` in every block (linter nag).
- `scripts/upgrade`: package_check upgrade test only runs if `test_upgrade_from` declared — decide whether v1.1 includes it (optional).
- `check_process` (legacy pre-v2 file): NOT needed; tests.toml supersedes it.

## Build Order

1. **Run package_check locally first (no repo changes)** — get the real finding list before editing anything. This is the milestone's core deliverable anyway. Deps: none.
2. **Add `tests.toml`** — required for any run to be meaningful (it must supply `admin_email`). Depends: step 1 confirms arg names.
3. **Fix findings in manifest/scripts** — iterate pack → local run until clean. Depends: 1–2.
4. **Add `.github/workflows/package_check.yml`** — mirror green local state. Depends: 3 (don't CI a red package; but adding workflow early is also fine as it just shows red — order is stylistic).
5. **(Optional) add test_upgrade_from entry** once a v1.0 tag exists on the repo — enables the upgrade test type in CI. Depends: 3.
6. **(Optional) lint workflow** (`lint-and-format.yml`) — cheap addition, non-blocking.

Dependency chain: tests.toml MUST precede CI green; script fixes are iterative with each run.

## Sources

- YunoHost packaging v2 docs — https://doc.yunohost.org/packaging_v2 (tests.toml grammar, `test_format = 1.0`)
- package_check repo — https://github.com/YunoHost/package_check (runner modes, flags — verify at implementation time)
- Existing-app patterns — https://github.com/YunoHost-Apps (manifest/tests.toml integration examples)
- Repo inspection (HIGH confidence): all "exists/absent" claims verified locally
