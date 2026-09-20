# Phase 5: tests.toml + Local package_check Environment - Research

**Researched:** 2026-09-20
**Domain:** YunoHost `package_check` CI harness, `tests.toml` v1 schema, Incus + btrfs host setup on Debian 12, SSH-driven remote execution from Windows
**Confidence:** HIGH (upstream source read directly: package_check `main`, tests.v1.schema.json, example_ynh tests.toml; repo git history inspected; Incus docs fetched)

## Summary

This research was performed by reading the **actual upstream `package_check` source** (`package_check.sh`, `lib/parse_tests_toml.py`, `lib/common.sh`, `lib/tests.sh`, `lib/tests_coordination.sh`, `lib/lxc.sh`, `lib/build_base_lxc.sh`, `lib/curl_tests.py`, `lib/default_install_args.py`, `lib/analyze_test_results.py`), the **actual `tests.v1.schema.json`**, `example_ynh`'s `tests.toml`, and this repo's git history — not by reading secondary docs.

**Four findings materially change the phase plan:**

1. **The `test_upgrade_from` target named in CONTEXT.md is wrong and must be corrected.** CONTEXT.md says to target "the v1.0 release commit (`0.8.8-rc3~ynh1`)". In reality: version `0.8.8-rc3~ynh1` existed **only at commit `116691c`**, which is a manifest-only skeleton with **no `scripts/` directory at all** — it cannot be installed, so package_check's upgrade-from test would `git checkout` it, attempt install, and fail before testing the upgrade. The last actually-installable release is version `0.8.8-rc3~ynh2` at commit **`05e3d5b`** (it has all six lifecycle scripts). The git tag `v1.0` points to `6ea5f8a`, a **docs-only milestone commit** (also version `0.8.8-rc3~ynh2`). The correct target is therefore `05e3d5b` (or `6ea5f8a`, which is byte-identical in `scripts/` and `manifest.toml`). The key must be a lowercase hex SHA prefix because the schema pattern is `^[a-z0-9_]*$` and `tests_coordination.sh` does `git checkout --force <key>`. `0.8.8-rc3~ynh1` contains `~` and `.` and is not a valid key or git ref in this repo.

2. **The auto-deduced test suite is much smaller than CONTEXT.md/ROADMAP assume.** `generate_test_list_base()` emits, per suite: `package_linter`, `install.root` (always for webapps), `install.subdir` **only if `is_full_domain_app` is False**, `install.multi` **only if `multi_instance` is true**, `backup_restore`, `upgrade`, `upgrade.<sha>` per `test_upgrade_from`, and `change_url` (for webapps). Critically:
   - **`install.private` is NEVER auto-generated** by the parser. It is not in the yield list at all. It can only run if explicitly listed in an additional suite's `only = [...]`. CONTEXT.md's "no `exclude` block → install.private runs" premise is false — it will not run under this package's tests.toml unless deliberately added.
   - **`install.subdir` will NOT run either**, because LibreChat's manifest has **no `[install.path]` question** (`is_full_domain_app = "domain" in args and "path" not in args` → True → subdir test suppressed). LibreChat installs at the domain root only.
   - `install.multi` will not run (`multi_instance = false`).
   - `change_url` **will** be auto-generated for the suite, but `scripts/change_url` does not exist. `TEST_CHANGE_URL` installs then calls `yunohost app change-url`; expect a failure finding (this is Phase 6 scope, POLS-02 deferred — but Phase 5 must acknowledge the test exists and is expected to fail).
   - **Net auto-deduced suite:** `package_linter`, `install.root`, `backup_restore`, `upgrade` (same version), `upgrade.05e3d5b` (from `test_upgrade_from`), `change_url`.

3. **Debian 12 (bookworm) requires the Zabbly APT repository to install Incus.** Debian 12 has no native `incus` package; native packages only begin with Debian 13 (trixie). Since the locked host decision is **Debian 12**, `scripts/setup_pc_env.sh` must add the Zabbly repo (`https://pkgs.zabbly.com/incus/lts-7.0` or `stable`, signed by `/etc/apt/keyrings/zabbly.asc`). Using `apt install incus` on bookworm without the repo will fail.

4. **package_check has no per-test timeout of its own.** There is no `timeout`/`alarm` wrap around `_RUN_YUNOHOST_CMD`; the only `timeout` calls are `timeout 30` around `lxc stop`. Install duration is bounded only by YunoHost's own operation timeouts and network. CONTRACT/CONTEXT's "watch for install timeout" is therefore about YunoHost core limits and SSH session duration, not a package_check knob. Note package_check's `TEST_LAUNCHER` runs `break_before_continue`, which for non-interactive runs is a no-op.

**Primary recommendation:** Write `tests.toml` with `test_format = 1.0`, the schema header, `args.admin_email = "package_checker@example.com"` (or similar), one `[default.curl_tests]` block with `home.path="/"`, `expect_return_code=200`, `auto_test_assets=true`; a single `test_upgrade_from.05e3d5b.name = "v1.0 (0.8.8-rc3~ynh2)"`; no `exclude`. Validate locally with `python3 lib/parse_tests_toml.py <app> | jq` and `package_check.sh -D` (dry-run). Then build the Debian 12 + Zabbly Incus host, `incus admin init`, create the btrfs pool on the second disk, add the yunohost remote, and run the suite over SSH, archiving `Test_results.log`.

## User Constraints (from CONTEXT.md)

> CONTEXT.md uses `<domain>`, `<decisions>` (with nested "### OpenCode's Discretion"), `<specifics>`, `<deferred>`. There is no top-level `## Decisions` / `## OpenCode's Discretion` heading. Verbatim content is reproduced below; where reality diverges from CONTEXT.md, the divergence is flagged in this research and in the planning notes.

### Locked Decisions (verbatim from `<decisions>`)

#### Incus / package_check host
- `package_check` is built around **Incus (or LXD) system containers** with **btrfs** snapshots and a host network bridge owning **dnsmasq on port 53** — it does not have a "just use a VM" mode. This is why Incus is required: each of ~7 test types boots a fresh YunoHost container.
- Host = **dedicated local Hyper-V VM**, Debian 12, with a **dedicated second virtual disk for the btrfs storage pool**. This isolates all host-level side effects (Incus daemon, `incusbr0` bridge / dnsmasq:53, btrfs pool, container disk churn) away from the Windows dev box and the existing YNH VPS.
- **Rationale:** avoids the documented Docker/libvirt conflicts and the fragile WSL2 nested-kernel path (WSL2 kernel here is a stale 5.10 placeholder; snap-based LXD doesn't work in WSL). The VM is disposable and reproducible.
- **Access model:** VM created once by the user; OpenCode drives `package_check` **over SSH from Windows** (existing `id_rsa` key, host-only/internal switch static IP). OpenCode cannot provision a VM from scratch or use cloud credentials — provisioning is a one-time user step, everything after is driven by OpenCode.
- **VM provisioning recipe (user-run, documented):** Hyper-V Gen 2, Debian 12 netinst ISO, second virtual disk for btrfs, OpenSSH server enabled, host-only/internal switch + static IP.
- **Roadmap wording:** REQUIREMENTS.md CI-02 and ROADMAP.md Success Criteria 3 currently say "WSL2" — **amend to match the real host** (Hyper-V Debian 12 VM + Incus + btrfs). The success criterion is "reproducible local Linux environment," not literally WSL2. Do this in Phase 5 execution.

#### tests.toml contents
- `test_format = 1.0` plus the documented schema header comment (`#:schema .../tests.v1.schema.json`), matching `example_ynh`.
- **Install args:** supply `args.admin_email` (manifest `admin_email` is a text arg with no auto-guessable value — package_check must be given it). `domain`, `path`, `is_public`, `admin`, `password` are auto-filled by package_check.
- **No `exclude` block** — trust package_check's manifest auto-deduction. `install.multi` is auto-skipped because `multi_instance = false`; `install.root`, `install.subdir`, `install.private`, `backup_restore`, `upgrade` all run. No "fake green" exclusions.
- **Curl smoke-test:** one `[default.curl_tests]` block — `home.path = "/"`, `expect_return_code = 200`, `auto_test_assets = true` (verifies SPA HTML serves and its first CSS/JS assets load). No `logged_on_sso` tests because `sso = false` (LibreChat has its own auth).
- **Upgrade-from:** one `test_upgrade_from.<sha>` entry targeting the **v1.0 release commit (`0.8.8-rc3~ynh1`)** — the tagged ancestor. Enables the upgrade-from-previous-version test. Name it descriptively (e.g. "v1.0 (0.8.8-rc3~ynh1)").

#### Setup documentation
- **Two artifacts, both committed in the package repo:**
  - `scripts/setup_pc_env.sh` — executable setup: install `lynx jq btrfs-progs`, install Incus, `incus admin init`, create btrfs storage pool on the dedicated disk, add the `yunohost` remote, clone `package_check`.
  - `doc/PACKAGE_CHECK.md` — human walkthrough covering VM provisioning (Hyper-V + Debian 12 ISO + second disk + SSH), then the in-VM setup, then how to run the suite.
- **Audience:** project-specific (Windows dev box + Hyper-V VM + SSH from Windows), including the one-time VM provisioning steps. "Reproducible from scratch by re-running the doc" must literally hold and be verifiable.

#### First run scope & artifacts
- Run the **full suite once** (install.root / install.subdir / install.private, remove, reinstall, backup_restore, upgrade-from-v1.0) and confirm every test type **completes without crashing or timing out**. Findings are expected and recorded for Phase 6.
- **Archive the Phase 5 findings run** in the phase dir (copy `Test_results.log` from the VM, plus `tests.toml` and a reference to the setup doc). Phase 6 separately archives its zero-failure run as POLS-01 — Phase 5 and Phase 6 evidence stay distinct.
- Watch for install timeout: MongoDB apt repo + `npm ci` + `turbo build` make install long; if the suite needs a raised timeout, document it (not a Phase 6 fix).

### OpenCode's Discretion (verbatim)
- Exact tests.toml comments/structure within the documented schema.
- Precise setup script internals (idempotency checks, ordering) as long as it reproduces cleanly.
- VM resource sizing within reason (CPU/RAM/disk) for the build load.
- How the Phase 5 run log is stored/named in the phase dir.

### Deferred Ideas (OUT OF SCOPE, verbatim)
- **Changing CI-02/roadmap wording from WSL2 to the Hyper-V VM host** — handled as part of Phase 5 execution, not a new phase; noted so REQUIREMENTS/ROADMAP are edited and stay consistent.
- Full `package_check` on GitHub-hosted runners — already out of scope (anti-feature); self-hosted runner is GHCI-02, a future milestone.
- `change_url` script — package_check level 7 will flag it; explicitly v2 (POLS-02), not Phase 5/6.

### Specific Ideas (verbatim from `<specifics>`)
- Incus must own the network bridge — the VM must have nothing else using port 53 or a conflicting bridge (the reason to isolate rather than reuse the dev box/VPS).
- "Full suite start and complete — findings allowed, crashes not" is the Phase 5 bar; zero-failures is explicitly Phase 6 (POLS-01).
- `python3 lib/parse_tests_toml.py /path/to/app/ | jq` is available in the package_check repo to validate tests.toml parsing before a full run.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CI-01 | `tests.toml` test suite exists with `test_format = 1.0`, supplies install args (e.g. `args.admin_email`), and follows documented syntax (no `exclude` misuse) | Exact schema captured (`tests.v1.schema.json`); exact install-arg injection path (`parse_tests_toml.py` + `default_install_args.py`); `admin_email` confirmed to have no default and therefore must be supplied; validation command `python3 lib/parse_tests_toml.py <app> \| jq` and dry-run `package_check.sh -D` documented. |
| CI-02 | User can run `package_check` locally from a WSL2 environment (Incus + btrfs setup documented and reproducible) | **Amendment required:** real host is Hyper-V Debian 12 VM + Incus + btrfs (WSL2 ruled out in 04-RESEARCH). Full Debian 12 Incus install path (Zabbly repo) captured; `incus admin init` + btrfs pool on `/dev/sdb` sequence verified from upstream README + Incus docs; package_check deps (`lynx jq btrfs-progs`) and yunohost remote (`repo.yunohost.org/incus`, simplestreams) captured from `lib/common.sh`. SSH-driven workflow from Windows defined. |

</phase_requirements>

## Standard Stack

### Core
| Tool | Version / Ref | Purpose | Why Standard |
|------|---------------|---------|--------------|
| `package_check` | `main` branch, cloned at run time (self-upgrades via `git reset --hard origin/main`) | The CI harness that runs the whole suite | Official YunoHost tool; the only authority for POLS-01/CI-02 |
| `tests.toml` schema | v1 (`tests.v1.schema.json`), `test_format = 1.0` | Declares install args, curl tests, upgrade-from commits | `parse_tests_toml.py` **asserts `test_format == 1.0`** — any other value aborts |
| Incus | Zabbly `lts-7.0` or `stable` (Debian 12 has no native package) | System-container backend with btrfs snapshots | package_check requires Incus/LXD; autodetects `incus` binary first |
| Debian | 12 (bookworm), per locked decision | Host OS inside the Hyper-V VM | Matches `DIST=bookworm` default in `lib/common.sh` |
| YunoHost container image | `yunohost:bookworm-stable-appci` from `repo.yunohost.org/incus` | The preinstalled base container | `LXC_BASE="yunohost-$DIST-$YNH_BRANCH-appci"`; fetched automatically |
| Python 3 | system python3 on the VM | Runs `parse_tests_toml.py`, `curl_tests.py`, `analyze_test_results.py` | Declared dependency; also `pip3` |
| `btrfs-progs` | latest bookworm | btrfs pool + snapshots | `incus storage create ... btrfs` needs it; also a package_check dep |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `lynx` | package_check dependency (`assert_we_have_all_dependencies`) | Always (preflight fails without it) |
| `jq` | package_check dependency; parses container JSON, tests JSON | Always |
| `curl` | Used by `_LXC_START_AND_WAIT` internet check inside containers; also workflow convenience | Always on host/containers |
| `python3-pip` / `pip3` | package_check dependency | Always |
| `OpenSSH server` | Remote driving from Windows | On the VM (`openssh-server` during Debian install) |
| `wkhtmltopdf` + `optipng` (optional) | Enable package_check's PNG summary export | Optional — human convenience only |
| `git` | package_check self-upgrade + cloning the app | Always |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Zabbly Incus on Debian 12 | Debian 13 (trixie) native `incus` | **Simpler package install** (no third-party repo) but violates the locked "Debian 12" host decision. If the user is open to it, trixie removes the Zabbly dependency; flag as a checkpoint, not a silent change. |
| Zabbly `stable` | Zabbly `lts-7.0` | LTS is recommended for production/less churn; `stable` tracks latest. Either works — prefer `lts-7.0` for reproducibility. |
| Incus | LXD (snap) | **Rejected** — snap LXD is fragile on VMs and the repo's README documents extra PATH symlink steps. Incus is autodetected and preferred. |
| Hyper-V VM | WSL2 | **Rejected** (04-RESEARCH + CONTEXT) — stale WSL2 kernel, no nested Incus/btrfs reliability, snap LXD broken in WSL. |
| `test_upgrade_from.05e3d5b` | `test_upgrade_from.6ea5f8a` (the `v1.0` tag commit) | Functionally equivalent (`scripts/` + `manifest.toml` identical). `6ea5f8a` is the human-meaningful "v1.0" tag but also the repo's `origin/main`. Prefer `05e3d5b` (the actual version-bump commit, clearly "the released v1.0 package"). See Open Question 1. |

**Installation (host setup — target end state of `scripts/setup_pc_env.sh`):**
```bash
# On the Debian 12 VM, as root (or via sudo):
apt-get update
apt-get install -y curl ca-certificates lynx jq btrfs-progs python3 python3-pip git

# Incus on bookworm requires the Zabbly repo (NOT in Debian 12 main):
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
# Verify fingerprint: 4EFC 5906 96CB 15B8 7C73 A3AD 82CC 8797 C838 DCFD
sh -c 'cat <<EOF > /etc/apt/sources.list.d/zabbly-incus-lts-7.0.sources
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/lts-7.0
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF'
apt-get update && apt-get install -y incus

# Add the invoking user to the incus-admin group, then RE-LOGIN:
usermod -aG incus-admin "$SUDO_USER"   # or the target user
```

## Architecture Patterns

### How package_check actually works (authoritative, from source)

**Entry point:** `./package_check.sh <PACKAGE_PATH_OR_GIT_URL>`.
- Flags: `-b/--branch`, `-D/--dry-run` (prints test JSON and exits — ideal for validating tests.toml), `-i/--interactive`, `-e/--interactive-on-errors`, `-s/--force-stop`, `-r/--rebuild`, `-S/--storage-dir`, `-h`.
- Backend: `switch_lxc_incus()` autodetects — **if `incus` is on PATH it uses Incus; otherwise LXD**. Override with `YNHDEV_BACKEND=incus|lxd`.
- Config via `./config` file sourced by `lib/common.sh`: `ARCH=amd64`, `DIST=bookworm`, `YNH_BRANCH=stable`.
- Self-upgrades `package_check` itself on `main` before running.
- Clones `package_linter` into `./package_linter` and **runs it as the first test** (so Phase 4's lint result appears inside the package_check suite too).

**Test deduction** (`lib/parse_tests_toml.py` `generate_test_list_base`), per suite (`[default]` and any additional `[suite]`):
```
package_linter                        # always
install.root                          # always for a webapp
install.subdir                        # only if NOT is_full_domain_app
install.nourl                         # only if NOT a webapp
install.multi                         # only if multi_instance == true
backup_restore                        # always
upgrade                               # always (same version)
upgrade.<sha>                         # one per test_upgrade_from.<sha>
change_url                            # always for a webapp
```
`is_webapp` is detected by grepping `scripts/install` for `ynh_add_nginx_config|ynh_nginx_add_config|ynh_config_add_nginx` — this package **has `ynh_config_add_nginx`** → webapp = True.

**Argument injection** (`lib/tests.sh::_INSTALL_APP`): for each arg, package_check seeds defaults from `default_install_args.py`, then force-overrides `domain=$SUBDOMAIN`, `admin=$TEST_USER`, `is_public=1`, `init_main_permission=visitors`. Then it iterates **every `[install.*]` name in the manifest** and, if not already present, pulls its `default` from the manifest — and **calls `log_error "Missing install arg $ARG ?"` and returns 1 if a manifest arg has no default and is not supplied**. `admin_email` has no `default` → **`tests.toml` must supply it** or the install test fails immediately.

**Upgrade-from mechanics** (`lib/tests.sh::TEST_UPGRADE`): with a non-empty commit arg, package_check copies the (current) `$package_path` aside, `git checkout --force --quiet <commit>` inside the cloned app, installs **that** older version, then restores the current tree and runs `yunohost app upgrade`. Therefore **the commit key must exist in the cloned repo and must be installable**. Keys come from the TOML table name; schema restricts to `^[a-z0-9_]*$` (lowercase hex/underscore only).

### Recommended project structure (deliverables this phase)
```
<repo>/
├── tests.toml                                    # NEW — CI-01 deliverable
├── scripts/
│   └── setup_pc_env.sh                           # NEW — executable host setup (idempotent)
├── doc/
│   └── PACKAGE_CHECK.md                          # NEW — human walkthrough (VM → setup → run)
└── .planning/phases/05-tests-toml-local-package-check-environment/
    ├── 05-RESEARCH.md                            # this file
    ├── Test_results.log                          # NEW — archived findings run (copied from VM)
    └── tests.toml                                # NEW — copy of the tests.toml used for the run
```

### Pattern 1: `tests.toml` for this package (recommended content)
```toml
#:schema https://raw.githubusercontent.com/YunoHost/apps/main/schemas/tests.v1.schema.json

test_format = 1.0

[default]

    # LibreChat has no [install.path] question -> package_check auto-deduces only
    # install.root (not install.subdir). multi_instance=false -> no install.multi.
    # No 'exclude' needed.

    # admin_email is a text arg with no manifest default; package_check cannot
    # guess it, so it MUST be supplied here.
    args.admin_email = "package_checker@example.com"

    # ---------------------------------------------------------------------------
    # Upgrade from the last installable released version (0.8.8-rc3~ynh2).
    # NB: the schema key must match ^[a-z0-9_]*$ and be a valid git ref;
    # commit 05e3d5b is the version-bump commit with a full scripts/ tree.
    # ---------------------------------------------------------------------------
    test_upgrade_from.05e3d5b.name = "v1.0 (0.8.8-rc3~ynh2)"

    # ---------------------------------------------------------------------------
    # Curl smoke-tests: SPA HTML serves and its first CSS/JS assets load.
    # sso=false -> no logged_on_sso tests.
    # ---------------------------------------------------------------------------
    [default.curl_tests]
    home.path = "/"
    home.expect_return_code = 200
    home.auto_test_assets = true
```
> Note the table form `[default.curl_tests]` with dotted keys `home.path` etc. is how example_ynh and package_check's README express it. `curl_tests` is a sub-table of the suite, and `home` is an arbitrary test ID.

### Pattern 2: Validate tests.toml before any full run
```bash
# In the package_check clone, against the app dir (must have manifest.toml + tests.toml):
python3 lib/parse_tests_toml.py /path/to/librechat_ynh | jq
# Expect a JSON object keyed by suite ("default") with the deduced test IDs.
# 'default' must contain: package_linter, install.root, backup_restore, upgrade,
# upgrade.05e3d5b, change_url  (NOT install.subdir / install.private / install.multi).

# Dry-run the harness itself (prints the test JSON it would run, then exits):
./package_check.sh -D /path/to/librechat_ynh
```

### Pattern 3: SSH-driven workflow from Windows
```powershell
# From the repo root on Windows (id_rsa already provisioned):
$vm = "pcuser@192.168.100.10"   # host-only switch static IP (example)
# 1. Sync the package to the VM (package_check also accepts a git URL, but a local
#    path is simplest and matches the 'local dev' intent):
ssh $vm "rm -rf ~/librechat_ynh && mkdir -p ~/librechat_ynh"
scp -r -i $env:USERPROFILE\.ssh\id_rsa .\* "${vm}:~/librechat_ynh/"

# 2. Run the suite over SSH (long-running; use a keepalive; tee to a log on the VM):
ssh $vm "cd ~/package_check && ./package_check.sh ~/librechat_ynh 2>&1 | tee ~/pc_run.log"

# 3. Retrieve the log artifacts back to the phase dir:
scp "${vm}:~/package_check/Test_results.log" ".\.planning\phases\05-tests-toml-local-package-check-environment\Test_results.log"
scp "${vm}:~/pc_run.log" ".\.planning\phases\05-tests-toml-local-package-check-environment\package_check-full.log"
```
> `Test_results.log` is written in the **package_check working directory** (repo root of the clone), not in the app dir. Confirm with `ls ~/package_check/Test_results.log`.

### Anti-Patterns to Avoid
- **Putting a version string (e.g. `0.8.8-rc3~ynh1`) as a `test_upgrade_from` key.** The schema rejects `~`/`.`; the value is a *git ref* used with `git checkout`. Use a lowercase hex SHA.
- **Using `exclude` to silence auto-deduced tests.** CONTEXT explicitly bans it; it is "fake green".
- **Adding `only = [...]` to `[default]`.** `filter_test_list()` raises `Exception("'only' is not allowed on the default test suite")`.
- **Assuming `install.private` runs.** It is never auto-generated. If a private-install test is genuinely desired (Phase 6 lists "private install" in POLS-01), it must be added as a separate suite with `only = ["install.private"]` — but note the CONTEXT's stated contents do not include one, and Phase 5's bar is "suite starts and completes", not "all test types exist".
- **Running package_check from a directory other than its clone root.** Logs and lock files are relative (`./Test_results.log`, `./pcheck-0.lock`).
- **Forgetting to re-login after `usermod -aG incus-admin`.** Group membership applies at login; use `newgrp incus-admin` or re-SSH.
- **Running package_check while an existing container/lock exists.** `package_check.sh` refuses if `pcheck-0.lock` exists with a live PID; use `-s/--force-stop` to clean up.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YunoHost container provisioning per test | A custom script that boots YunoHost VMs | `package_check` + the `yunohost:bookworm-stable-appci` image | The harness handles snapshots, install args, witnesses, backup/restore paths |
| tests.toml parsing/validation | A bespoke TOML validator | `python3 lib/parse_tests_toml.py <app> \| jq` and `package_check.sh -D` | Authoritative; exactly what the CI uses |
| Incus install on Debian 12 | Downloading/compiling Incus source | Zabbly APT repo (`pkgs.zabbly.com/incus/lts-7.0`) | Clean, signed, maintained; native package absent on bookworm |
| btrfs pool creation | `mkfs.btrfs` + manual mount | `incus storage create btrfs_pool btrfs source=/dev/sdb1` + `incus profile device add` | Incus formats, mounts, and owns the pool; matches upstream README |
| DNS/DHCP for containers | Editing `/etc/hosts`/running a DNS server | Incus managed bridge (`incusbr0`, dnsmasq on :53) | Automatic; only conflict is another :53 listener (the isolation rationale) |
| Upgrade-from test scaffolding | Hand-running `yunohost app upgrade` on an old checkout | `test_upgrade_from.<sha>` | The harness does checkout → install old → upgrade → validate automatically |

**Key insight:** `package_check` is a full integration harness with snapshot orchestration and legacy-version handling; every attempt to reimplement a piece (container boot, args, upgrade checkout) diverges from the official pass/fail semantics that POLS-01 depends on.

## Common Pitfalls

### Pitfall 1: `test_upgrade_from` target is not installable
**What goes wrong:** The test checks out `0.8.8-rc3~ynh1`'s commit `116691c` (manifest only, no scripts), install fails, and the upgrade-from test reports failure — and worst, the failure is blamed on the current package rather than the target.
**Why it happens:** CONTEXT.md conflated a *version string* with an installable *release commit*.
**How to avoid:** Target `05e3d5b` (version `0.8.8-rc3~ynh2`, full `scripts/` tree). Optionally target `6ea5f8a` (the `v1.0` tag). Never `116691c`.
**Warning signs:** `Failed to checkout commit ...` or an install failure at the preliminary install phase of `TEST_UPGRADE` with `test_arg=116691c`.

### Pitfall 2: Missing `admin_email` default fails *every* install test
**What goes wrong:** `_INSTALL_APP` iterates manifest `[install.*]` names; `admin_email` has no `default`; package_check logs `Missing install arg admin_email ?` and returns 1 before installing.
**Why it happens:** `admin_email` is a free-text arg with `example` but no `default`.
**How to avoid:** Always supply `args.admin_email` in `tests.toml`.
**Warning signs:** `Missing install arg admin_email ?` in the log; all install tests fail identically.

### Pitfall 3: Debian 12 has no native Incus package
**What goes wrong:** `apt install incus` on bookworm → `E: Unable to locate package incus`.
**Why it happens:** Native Incus packages start with Debian 13 (trixie).
**How to avoid:** Add the Zabbly repo first (see Installation). Verify the key fingerprint.
**Warning signs:** Package not found; or unsigned-repo warnings if the key wasn't imported.

### Pitfall 4: dnsmasq on port 53 conflict
**What goes wrong:** `incus admin init` fails to create/start the bridge, or containers get no DNS.
**Why it happens:** A pre-existing DNS resolver (systemd-resolved, dnsmasq, another libvirt/Docker bridge) already owns :53.
**How to avoid:** Use the dedicated VM (no Docker/libvirt). Check `ss -lunp | grep :53` and `ip a | grep incusbr0` before init. `check_incus_setup` warns (not fatal) if `incusbr0` is absent.
**Warning signs:** `There is no 'incusbr0' interface... Did you ran 'incus admin init' ?`.

### Pitfall 5: btrfs pool on the wrong device / loop-backed fallback
**What goes wrong:** `incus admin init --minimal` creates a loop-backed `dir` pool (slow, no fast snapshots), defeating the whole point.
**Why it happens:** `--minimal` uses the `dir` driver; snapshots in package_check rely on fast CoW.
**How to avoid:** Create a dedicated btrfs pool on the second disk: `incus storage create btrfs_pool btrfs source=/dev/sdb1`, then repoint the default profile root device to it. Per upstream README: `incus profile device remove default root` before creating the pool, then `incus profile device add default root disk path=/ pool=btrfs_pool`.
**Warning signs:** `incus storage list` shows driver `dir`; extremely slow snapshots.

### Pitfall 6: `change_url` test will be generated and fail
**What goes wrong:** Parser auto-generates `change_url` for webapps; `scripts/change_url` does not exist. `TEST_CHANGE_URL` installs then calls `yunohost app change-url` → failure.
**Why it happens:** The parser does not check for the script's existence.
**How to avoid:** Accept it as an expected Phase 5 finding (Phase 6/POLS-02 scope); document it in the archived run. Do **not** add an `exclude` (banned).
**Warning signs:** `Change URL: fail` in the summary.

### Pitfall 7: package_check runs the linter as test #1 — catalog criticals will fail it
**What goes wrong:** `TEST_PACKAGE_LINTER` runs `package_linter.py --json` and its exit is the test result; the catalog critical/errors (documented Phase 4 exemptions) make this test fail.
**Why it happens:** Phase 4's zero-error invariant was scope-adjusted; package_check does not know about exemptions.
**How to avoid:** Expected Phase 5 finding; owned by Phase 6 (catalog submission is out of scope, but the linter test will remain red until then — this is a known, accepted finding).
**Warning signs:** `Package linter: fail` with the same 1 critical + 2 errors from Phase 4.

### Pitfall 8: Long installs / SSH session drops
**What goes wrong:** `npm ci` + `turbo build` + MongoDB apt take many minutes; SSH may disconnect, aborting the run.
**Why it happens:** No package_check timeout knob; only YunoHost core limits and the SSH client's own keepalive matter.
**How to avoid:** Run under `tmux`/`nohup` on the VM (or use `ssh -o ServerAliveInterval=30`), tee to a file, and poll. Size the VM generously (see Open Questions).
**Warning signs:** SSH `Broken pipe`; run dies mid-install; no `Test_results.log` update.

## Code Examples

### tests.toml (full recommended file)
See "Pattern 1" above. Verbatim-syntax checkpoints:
- `test_format = 1.0` (number, not string) — parser asserts equality.
- `[default]` suite must exist.
- `args.admin_email` is a *dotted key inside the suite table*.
- `test_upgrade_from.<sha>.name` is a *nested table*.
- `[default.curl_tests]` is a *sub-table*.

### Setup script skeleton (idempotent)
```bash
#!/bin/bash
# scripts/setup_pc_env.sh — provision the local package_check host (run IN the VM, with sudo)
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then echo "Run with sudo"; exit 1; fi
TARGET_USER="${SUDO_USER:-${1:?usage: setup_pc_env.sh <user>}}"
BTRFS_DISK="${BTRFS_DISK:-/dev/sdb}"

# 1. Base deps (package_check requires lynx jq python3 pip3; btrfs-progs for the pool)
apt-get update
apt-get install -y curl ca-certificates lynx jq python3 python3-pip git btrfs-progs

# 2. Incus via Zabbly (Debian 12 has no native incus). Idempotent.
if ! command -v incus >/dev/null; then
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
  cat > /etc/apt/sources.list.d/zabbly-incus-lts-7.0.sources <<EOF
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/lts-7.0
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF
  apt-get update && apt-get install -y incus
fi

# 3. Group membership (applies at next login)
usermod -aG incus-admin "$TARGET_USER"

# 4. btrfs pool on the dedicated disk (idempotent)
if ! incus storage list --format csv | cut -d, -f1 | grep -qx btrfs_pool; then
  incus profile device remove default root 2>/dev/null || true
  # Create a partition with fdisk first (upstream README); incus will format it.
  incus storage create btrfs_pool btrfs source="${BTRFS_DISK}1"
  incus profile device add default root disk path=/ pool=btrfs_pool
fi

# 5. yunohost image remote (package_check's set_incus_remote does this too; idempotent)
incus remote list -f json | jq -e '.yunohost' >/dev/null 2>&1 \
  || incus remote add yunohost https://repo.yunohost.org/incus --protocol simplestreams --public

# 6. Clone package_check (as the target user)
if [[ ! -d "/home/${TARGET_USER}/package_check" ]]; then
  sudo -u "$TARGET_USER" git clone https://github.com/YunoHost/package_check "/home/${TARGET_USER}/package_check"
fi
```
> `incus admin init` is interactive; on a fresh host it is simplest to run `incus admin init --minimal` **then** replace the storage pool as above, or run interactive init choosing btrfs. Document the chosen path in `doc/PACKAGE_CHECK.md`.

### Validation / result locations
```bash
# After a run, in the package_check clone:
ls -l Test_results.log           # the summary log (colored text) — archive this
ls -l full_log_0.log             # full debug log
ls -l results_0.json             # machine-readable summary (analyze_test_results.py output)
ls -l summary_0.png              # optional PNG (needs wkhtmltopdf+optipng)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `check_process` file | `tests.toml` (schema v1, `test_format = 1.0`) | packaging v2 | Mandatory; linter errors without it |
| LXD (snap) | Incus | ~2023+ | package_check autodetects `incus`; snap LXD has known VM friction |
| `incus admin init --minimal` default | Explicit btrfs pool on a dedicated disk | — | Fast CoW snapshots required for package_check performance |
| Debian 12 native Incus | Zabbly repo (bookworm); native only from trixie | Debian 13 release | Changes `setup_pc_env.sh`'s install step |
| `test_upgrade_from` on a version string | Commit SHA key | schema v1 | Keys are `^[a-z0-9_]*$` and used as git refs |

**Deprecated/outdated:**
- `check_process` → `tests.toml`.
- Snap LXD → Incus on VMs.
- WSL2 as the local host → dedicated Hyper-V VM (this phase's roadmap amendment).

## Open Questions

1. **Which commit should `test_upgrade_from` target — `05e3d5b` (last installable v1.0 package) or `6ea5f8a` (the `v1.0` tag)?**
   - What we know: both contain identical `scripts/` and `manifest.toml` (version `0.8.8-rc3~ynh2`). `05e3d5b` is the actual "bump to the shipped version" commit; `6ea5f8a` is the docs-only milestone tag and is also `origin/main`.
   - What's unclear: which the user prefers to name "v1.0".
   - Recommendation: **`05e3d5b`**, named "v1.0 (0.8.8-rc3~ynh2)". It is unambiguous as "the released package". Confirmed in this research (see git evidence below). Surface as a 1-line checkpoint in the plan, but proceed with `05e3d5b`.

2. **Does the user actually want `install.private` to run (POLS-01 mentions it), given the parser never auto-generates it?**
   - What we know: `install.private` is absent from `generate_test_list_base`; Phase 6's POLS-01 text lists "private install".
   - What's unclear: whether to add an extra suite `[private]  only = ["install.private"]  args.is_public = 0` now (Phase 5) or defer to Phase 6.
   - Recommendation: **Defer to Phase 6.** Phase 5's locked contents specify no `only`/extra suite and the bar is "starts and completes". Note the discrepancy in the plan so Phase 6 can add a private-install suite if desired. Also note `install.subdir` cannot run at all (no `[install.path]`).

3. **VM sizing for the build load.**
   - What we know: `ram.build = "2G"` in the manifest; LibreChat `turbo build` is heavy; package_check sets `limits.memory=80%` and `limits.cpu.allowance=80%` on containers.
   - What's unclear: exact Hyper-V allocation needed to avoid OOM/swap thrash.
   - Recommendation: **8 GB RAM, 4 vCPU, 60 GB OS disk + 40–60 GB btrfs disk** (discretionary per CONTEXT). Document actual values used in `doc/PACKAGE_CHECK.md` so it is reproducible.

4. **Should Incus be `stable` or `lts-7.0` from Zabbly?**
   - What we know: both exist for bookworm; LTS is recommended for production.
   - What's unclear: nothing material.
   - Recommendation: **`lts-7.0`** for reproducibility; document the choice.

5. **Roadmap/REQUIREMENTS wording amendment scope.**
   - What we know: `REQUIREMENTS.md` CI-02 and `ROADMAP.md` Phase 5 Success Criterion 3/Goal say "WSL2".
   - Recommendation: In Phase 5 execution, edit both to read "dedicated Hyper-V Debian 12 VM + Incus + btrfs (reproducible local Linux environment)". This is an explicit execution task, not a new phase (CONTEXT `<deferred>`).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `package_check` (`main`) — the harness *is* the test framework; no pytest/jest |
| Config file | `tests.toml` in the app root + optional `config` in the package_check clone (`ARCH`, `DIST`, `YNH_BRANCH`) |
| Quick run command | `python3 lib/parse_tests_toml.py <app> \| jq` (parses + deduces tests in ~1 s) |
| Full suite command | `./package_check.sh <app>` (from the package_check clone; expect tens of minutes) |
| Dry-run command | `./package_check.sh -D <app>` (prints the test JSON, no containers) |
| Estimated runtime | Full suite: long (multiple full installs; each LibreChat install runs MongoDB apt + `npm ci` + `turbo build`). Likely **1–3 hours**; the Phase 5 run only needs to start and complete. |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CI-01 | `tests.toml` parses and deduces the expected suite | contract | `python3 lib/parse_tests_toml.py <app> \| jq -e '."default".install.root and ."default".backup_restore and ."default"."upgrade.05e3d5b"'` | ❌ Wave 0 gap (`tests.toml` not created) |
| CI-01 | `admin_email` supplied so installs can proceed | contract | Inspect deduction: install args JSON contains `admin_email=...` (`package_check.sh -D`) | ❌ Wave 0 gap |
| CI-01 | `test_format == 1.0` and schema keys valid | unit | `jq`/`tomllib` check + `python3 -c "import toml;..."` | ❌ Wave 0 gap |
| CI-02 | Full suite **starts and completes** (findings allowed, no crash/timeout) | e2e | `./package_check.sh <app>` on the VM; assert `Test_results.log` ends with a Global level summary and no `Critical:`. | ❌ Wave 0 gap (VM + env not provisioned) |
| CI-02 | Environment setup is reproducible from scratch | manual-only (justified) | Re-run `scripts/setup_pc_env.sh` + `doc/PACKAGE_CHECK.md` on a fresh VM | ❌ Wave 0 gap |

> Justification for manual-only CI-02 reproducibility: the VM is user-provisioned (Hyper-V) and OpenCode cannot create it; verifying "reproducible from scratch" requires a human-provided fresh VM. The script and doc must therefore be written to be idempotent and self-checking, and the plan should include a user checkpoint that a clean run followed the doc without undocumented steps.

### Nyquist Sampling Rate
- **Minimum sample interval:** After creating/editing `tests.toml` → run `python3 lib/parse_tests_toml.py <app> | jq` **before** any container run (~1 s feedback).
- **After env setup:** `./package_check.sh -D <app>` (dry-run) to confirm the deduced test list with no containers.
- **Full suite trigger:** Once, at the end of the phase (the "starts and completes" run).
- **Phase-complete gate:** `tests.toml` parses cleanly **and** the full suite reached the Tests summary (Global level printed) with no `Critical:` abort **and** `Test_results.log` archived in the phase dir.
- **Estimated feedback latency per task:** ~1 s (parse) / ~seconds (dry-run) / hours (full suite). Plan tasks so only the final task pays the full-suite cost.

### Wave 0 Gaps (must be created before implementation)
- [ ] `tests.toml` — the CI-01 deliverable (also unblocks Phase 4's exempted `Configurations.tests_toml` finding on the next lint run).
- [ ] `scripts/setup_pc_env.sh` — idempotent host setup (Incus via Zabbly, btrfs pool, yunohost remote, package_check clone).
- [ ] `doc/PACKAGE_CHECK.md` — human walkthrough (Hyper-V VM provisioning → in-VM setup → run → retrieve logs).
- [ ] VM provisioned by the user (one-time) with SSH reachable from Windows — prerequisite for the full-suite task.
- [ ] `.planning/phases/05-.../Test_results.log` + `tests.toml` copy — archived run artifacts.
- [ ] Framework install: `package_check` clone + `lynx jq btrfs-progs python3 pip3` on the VM (one-time, not committed).
- [ ] Roadmap/REQUIREMENTS WSL2→Hyper-V amendment task (execution, not a new phase).

> This phase has **no conventional unit-test framework**. The harness *is* the test; the "tests" are: parse-with-`parse_tests_toml.py` (fast), dry-run `-D` (medium), and the full suite (slow, once). This is appropriate and mirrors Phase 4's linter-is-the-test pattern.

## Git Evidence (for the `test_upgrade_from` correction)

| Commit | Manifest `version` | Has `scripts/`? | Installable? | Notes |
|--------|---------------------|-----------------|--------------|-------|
| `116691c` | `0.8.8-rc3~ynh1` | **No** (manifest-only skeleton) | **No** | CONTEXT.md's named target — unusable |
| `05e3d5b` | `0.8.8-rc3~ynh2` | Yes (6 scripts) | **Yes** | Version-bump commit; **recommended target** |
| `6ea5f8a` | `0.8.8-rc3~ynh2` | Yes (identical) | Yes | The `v1.0` tag; docs-only milestone commit; `origin/main` |
| `669b880` (HEAD) | `0.8.8-rc3~ynh2` | Yes | Yes | Current main (post Phase 4) |

Verification commands used:
```bash
git show 116691c:manifest.toml | grep '^version'      # version = "0.8.8-rc3~ynh1"
git ls-tree -r --name-only 116691c | grep '^scripts/' # (empty)
git show 05e3d5b:manifest.toml | grep '^version'      # version = "0.8.8-rc3~ynh2"
git ls-tree -r --name-only 05e3d5b | grep '^scripts/' # 6 scripts
git show v1.0 --stat --format=fuller                  # tag -> 6ea5f8a
```

## Sources

### Primary (HIGH confidence)
- `github.com/YunoHost/package_check` @ `main` — read `README.md`, `package_check.sh`, `lib/parse_tests_toml.py`, `lib/common.sh`, `lib/tests.sh`, `lib/tests_coordination.sh`, `lib/lxc.sh`, `lib/build_base_lxc.sh`, `lib/curl_tests.py`, `lib/default_install_args.py`, `lib/analyze_test_results.py`. All deduction, arg-injection, upgrade, timeout, and log-file behavior derived from these.
- `raw.githubusercontent.com/YunoHost/apps/main/schemas/tests.v1.schema.json` — authoritative key names, `additionalProperties: false`, `install_args` pattern `^[a-z][a-z0-9_]*$`, `test_upgrade_from` key pattern `^[a-z0-9_]*$`, `curl_tests` properties. **This is the schema the planner must satisfy.**
- `raw.githubusercontent.com/YunoHost/example_ynh/master/tests.toml` — canonical structure/comment style, `#:schema` header, `[default.curl_tests]` usage.
- Incus official docs — `howto/initialize/` (interactive vs `--minimal` vs `--preseed`), `howto/storage_pools/` (`incus storage create btrfs_pool btrfs source=/dev/sdX`), `reference/network_bridge/` (dnsmasq on the managed bridge), `reference/storage_btrfs/` (CoW snapshots, `btrfs-progs` requirement), `installing/` (**Debian 12 → Zabbly; native from trixie**).
- `github.com/zabbly/incus` — exact APT repo setup, key fingerprint `4EFC 5906 96CB 15B8 7C73 A3AD 82CC 8797 C838 DCFD`, `bookworm` availability, `lts-6.0`/`lts-7.0`/`stable` channels.
- **This repo's git history** (local `git show`/`git log`) — confirmed the `0.8.8-rc3~ynh1` vs `0.8.8-rc3~ynh2` commit reality; `v1.0` → `6ea5f8a`; no `[install.path]`; no `scripts/change_url`.

### Secondary (MEDIUM confidence)
- package_check README "Using a btrfs storage pool" section (cross-checked against Incus official docs — consistent).

### Tertiary (LOW confidence)
- None required. Every load-bearing claim is source-derived or empirically verified against this repo's git history.

## Metadata

**Confidence breakdown:**
- tests.toml schema/structure: **HIGH** — read the actual schema JSON and parser source.
- package_check invocation/deps/logs: **HIGH** — read entry point, common.sh, tests.sh, lxc.sh directly.
- Incus on Debian 12: **HIGH** — official Incus install docs + Zabbly repo docs explicitly list bookworm and the third-party-repo requirement.
- btrfs pool commands: **HIGH** — upstream package_check README + Incus storage docs agree.
- `test_upgrade_from` target correction: **HIGH** — proven from local git objects.
- Auto-deduced suite (no `install.subdir`/`install.private`): **HIGH** — read `generate_test_list_base` and confirmed the manifest has no `[install.path]`.
- SSH workflow: **MEDIUM** — standard practice; exact IP/user are environment-specific and user-provided.

**Research date:** 2026-09-20
**Valid until:** ~2026-10-20 (30 days). `package_check` tracks `main` and self-updates; the tests.toml schema is stable (v1). Re-read `lib/parse_tests_toml.py` before finalizing if more than a month passes.
