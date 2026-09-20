# Phase 5: tests.toml + Local package_check Environment - Context

**Gathered:** 2026-09-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver two things: (1) a schema-valid `tests.toml` at the package root that lets `package_check` install and exercise LibreChat (install args supplied, one upgrade-from ancestor, curl smoke-tests), and (2) a reproducible local Linux environment that can run the full `package_check` suite end-to-end, documented so it can be rebuilt from scratch. The first full run must **start and complete** (findings allowed, crashes not) — fixing findings to zero failures is Phase 6. No script fixes, no GitHub Actions workflow (Phase 7).

</domain>

<decisions>
## Implementation Decisions

### Incus / package_check host
- `package_check` is built around **Incus (or LXD) system containers** with **btrfs** snapshots and a host network bridge owning **dnsmasq on port 53** — it does not have a "just use a VM" mode. This is why Incus is required: each of ~7 test types boots a fresh YunoHost container.
- Host = **dedicated local Hyper-V VM**, Debian 12, with a **dedicated second virtual disk for the btrfs storage pool**. This isolates all host-level side effects (Incus daemon, `incusbr0` bridge / dnsmasq:53, btrfs pool, container disk churn) away from the Windows dev box and the existing YNH VPS.
- **Rationale:** avoids the documented Docker/libvirt conflicts and the fragile WSL2 nested-kernel path (WSL2 kernel here is a stale 5.10 placeholder; snap-based LXD doesn't work in WSL). The VM is disposable and reproducible.
- **Access model:** VM created once by the user; OpenCode drives `package_check` **over SSH from Windows** (existing `id_rsa` key, host-only/internal switch static IP). OpenCode cannot provision a VM from scratch or use cloud credentials — provisioning is a one-time user step, everything after is driven by OpenCode.
- **VM provisioning recipe (user-run, documented):** Hyper-V Gen 2, Debian 12 netinst ISO, second virtual disk for btrfs, OpenSSH server enabled, host-only/internal switch + static IP.
- **Roadmap wording:** REQUIREMENTS.md CI-02 and ROADMAP.md Success Criteria 3 currently say "WSL2" — **amend to match the real host** (Hyper-V Debian 12 VM + Incus + btrfs). The success criterion is "reproducible local Linux environment," not literally WSL2. Do this in Phase 5 execution.

### tests.toml contents
- `test_format = 1.0` plus the documented schema header comment (`#:schema .../tests.v1.schema.json`), matching `example_ynh`.
- **Install args:** supply `args.admin_email` (manifest `admin_email` is a text arg with no auto-guessable value — package_check must be given it). `domain`, `path`, `is_public`, `admin`, `password` are auto-filled by package_check.
- **No `exclude` block** — trust package_check's manifest auto-deduction. `install.multi` is auto-skipped because `multi_instance = false`; `install.root`, `install.subdir`, `install.private`, `backup_restore`, `upgrade` all run. No "fake green" exclusions.
- **Curl smoke-test:** one `[default.curl_tests]` block — `home.path = "/"`, `expect_return_code = 200`, `auto_test_assets = true` (verifies SPA HTML serves and its first CSS/JS assets load). No `logged_on_sso` tests because `sso = false` (LibreChat has its own auth).
- **Upgrade-from:** one `test_upgrade_from.<sha>` entry targeting the **v1.0 release commit (`0.8.8-rc3~ynh1`)** — the tagged ancestor. Enables the upgrade-from-previous-version test. Name it descriptively (e.g. "v1.0 (0.8.8-rc3~ynh1)").

### Setup documentation
- **Two artifacts, both committed in the package repo:**
  - `scripts/setup_pc_env.sh` — executable setup: install `lynx jq btrfs-progs`, install Incus, `incus admin init`, create btrfs storage pool on the dedicated disk, add the `yunohost` remote, clone `package_check`.
  - `doc/PACKAGE_CHECK.md` — human walkthrough covering VM provisioning (Hyper-V + Debian 12 ISO + second disk + SSH), then the in-VM setup, then how to run the suite.
- **Audience:** project-specific (Windows dev box + Hyper-V VM + SSH from Windows), including the one-time VM provisioning steps. "Reproducible from scratch by re-running the doc" must literally hold and be verifiable.

### First run scope & artifacts
- Run the **full suite once** (install.root / install.subdir / install.private, remove, reinstall, backup_restore, upgrade-from-v1.0) and confirm every test type **completes without crashing or timing out**. Findings are expected and recorded for Phase 6.
- **Archive the Phase 5 findings run** in the phase dir (copy `Test_results.log` from the VM, plus `tests.toml` and a reference to the setup doc). Phase 6 separately archives its zero-failure run as POLS-01 — Phase 5 and Phase 6 evidence stay distinct.
- Watch for install timeout: MongoDB apt repo + `npm ci` + `turbo build` make install long; if the suite needs a raised timeout, document it (not a Phase 6 fix).

### OpenCode's Discretion
- Exact tests.toml comments/structure within the documented schema.
- Precise setup script internals (idempotency checks, ordering) as long as it reproduces cleanly.
- VM resource sizing within reason (CPU/RAM/disk) for the build load.
- How the Phase 5 run log is stored/named in the phase dir.

</decisions>

<specifics>
## Specific Ideas

- Incus must own the network bridge — the VM must have nothing else using port 53 or a conflicting bridge (the reason to isolate rather than reuse the dev box/VPS).
- "Full suite start and complete — findings allowed, crashes not" is the Phase 5 bar; zero-failures is explicitly Phase 6 (POLS-01).
- `python3 lib/parse_tests_toml.py /path/to/app/ | jq` is available in the package_check repo to validate tests.toml parsing before a full run.

</specifics>

<deferred>
## Deferred Ideas

- **Changing CI-02/roadmap wording from WSL2 to the Hyper-V VM host** — handled as part of Phase 5 execution, not a new phase; noted so REQUIREMENTS/ROADMAP are edited and stay consistent.
- Full `package_check` on GitHub-hosted runners — already out of scope (anti-feature); self-hosted runner is GHCI-02, a future milestone.
- `change_url` script — package_check level 7 will flag it; explicitly v2 (POLS-02), not Phase 5/6.

</deferred>

---

*Phase: 05-tests-toml-local-package-check-environment*
*Context gathered: 2026-09-20*
