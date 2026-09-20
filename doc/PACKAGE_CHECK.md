# Running `package_check` locally (Hyper-V Debian 12 + Incus + btrfs)

This document is the complete, reproducible walkthrough for running the YunoHost
[`package_check`](https://github.com/YunoHost/package_check) suite against this
LibreChat package on a local Linux host. Re-running it from scratch on a fresh
VM must reproduce the environment with no undocumented steps.

For the automated part of the in-VM setup, see [`scripts/setup_pc_env.sh`](../scripts/setup_pc_env.sh).

---

## 1. What this is and why

`package_check` is YunoHost's integration harness. It is built around **Incus
system containers** with **btrfs snapshots**: for every test type it boots a
fresh `yunohost:bookworm-stable-appci` container, installs the app, and
snapshots/restores between phases. It also relies on a host **network bridge
(`incusbr0`) whose managed dnsmasq owns port 53** for the containers. It does not
have a "just use a VM per test" mode — Incus (or LXD) is mandatory.

The real host for this project is a **dedicated Hyper-V Debian 12 VM**. **WSL2 is
ruled out**: the WSL2 kernel here is a stale 5.10 placeholder with no reliable
nested Incus/btrfs, and snap-based LXD does not work in WSL. Isolating the host
into a disposable VM also keeps the Incus daemon, the `incusbr0` bridge/dnsmasq,
the btrfs pool, and container disk churn away from the Windows dev box and the
existing YunoHost VPS (no Docker/libvirt port-53 conflicts).

**Phase 5 bar:** the full suite must **start and complete** — findings are
allowed, crashes/timeouts are not. Reaching **zero failures** is a separate,
later goal (Phase 6 / POLS-01).

---

## 2. One-time VM provisioning (user steps)

These steps are performed once by a human. Everything after is driven over SSH.

1. **Create a Hyper-V Generation 2 VM** (Windows Hyper-V Manager → New →
   Virtual Machine). Generation 2 is required for the modern boot path.
2. **Attach the Debian 12 (bookworm) netinst ISO** and install Debian 12.
3. **Enable the OpenSSH server** during the Debian installer's "software
   selection" step (or `apt install openssh-server` afterwards).
4. **Add a second virtual disk** for the btrfs storage pool. Do *not* put the
   pool on the OS disk — the dedicated disk makes the setup disposable and
   reproducible. Size it **40–60 GB**.
5. **Configure networking with a host-only / internal switch and a static IP**
   so the Windows dev box can reach the VM. The VM must **own port 53** and the
   bridge itself — do not run Docker or libvirt inside this VM.
6. **Recommended sizing:** **8 GB RAM**, **4 vCPU**, **60 GB OS disk** +
   **40–60 GB btrfs disk**. (The frontend `turbo build` and MongoDB apt install
   are heavy; undersizing causes OOM/swap thrash. Record the actual values you
   used here if you deviate.)

**SSH reachability from the Windows dev box** uses the existing `id_rsa` key:

```powershell
# Confirm the key is reachable and the VM answers:
ssh -i $env:USERPROFILE\.ssh\id_rsa <user>@<static-ip> "uname -a && lsblk"
```

`<user>` and `<static-ip>` are environment-specific; substitute your own.

---

## 3. In-VM setup

Run the setup script with sudo. It installs the base dependencies, adds the
Zabbly repository for Incus (Debian 12 has **no native `incus` package** — native
packages only begin with Debian 13, so the channel used is **`lts-7.0`** from
Zabbly), creates the btrfs pool, adds the YunoHost image remote, and clones
`package_check`:

```bash
# On the VM, from a checkout of this repo:
sudo bash scripts/setup_pc_env.sh <user>

# If the btrfs disk is not /dev/sdb, override it:
BTRFS_DISK=/dev/sdc sudo -E bash scripts/setup_pc_env.sh <user>
```

The script is **idempotent** — re-running it is a safe no-op/repair.

**Initialize Incus.** `incus admin init` is interactive; run it and accept the
**managed bridge** so `incusbr0` exists. If you initialized non-interactively,
the script still fixes the storage situation, because it creates/repoints the
default profile's root device at `btrfs_pool` (a non-interactive init otherwise
leaves you with a slow, dir-backed pool that defeats snapshot performance):

```bash
incus admin init
```

**Re-login for the `incus-admin` group.** Group membership applies at the next
login:

```bash
newgrp incus-admin     # or just re-SSH / reboot
```

**Sanity checks** before running the suite:

```bash
ss -lunp | grep :53        # the Incus managed dnsmasq must own port 53
ip a | grep incusbr0       # the managed bridge must exist
incus storage list         # the pool's DRIVER must show "btrfs", not "dir"
incus remote list          # must include the "yunohost" remote
```

---

## 4. Running the suite (SSH-driven from Windows)

Sync the package to the VM and point `package_check` at it:

```powershell
$vm = "<user>@<static-ip>"
ssh -i $env:USERPROFILE\.ssh\id_rsa $vm "rm -rf ~/librechat_ynh && mkdir -p ~/librechat_ynh"
scp -r -i $env:USERPROFILE\.ssh\id_rsa .\* "${vm}:~/librechat_ynh/"
```

```bash
# On the VM, from the package_check clone root:
cd ~/package_check
./package_check.sh ~/librechat_ynh
```

**This run is long.** Expect **1–3 hours**: every install test performs a full
LibreChat install (MongoDB apt repo + `npm ci` + `turbo build`), and there are
multiple install tests. **`package_check` has no timeout knob of its own** —
duration is bounded only by YunoHost's own operation timeouts, the network, and
your SSH session. Therefore:

- Run it under **`tmux`/`nohup`**, or use **`ssh -o ServerAliveInterval=30`** so
  the session does not drop mid-run.
- **Tee to a log** so you can inspect progress and keep a copy:

```bash
cd ~/package_check
tmux new -s pc
./package_check.sh ~/librechat_ynh 2>&1 | tee ~/pc_run.log
```

Useful flags:

- `-D` / `--dry-run` — print the deduced test JSON and exit (no containers).
  Ideal for validating `tests.toml` before a full run.
- `-s` / `--force-stop` — clean up a stale `pcheck-0.lock` / leftover container
  from a previous aborted run.

**Deduced suite for this package** (from `tests.toml` + manifest auto-deduction):

```
package_linter, install.root, backup_restore, upgrade, upgrade.05e3d5b, change_url
```

Notes:

- `install.subdir` does **not** run: LibreChat has no `[install.path]` question,
  so it is treated as a full-domain app (domain root only).
- `install.private` does **not** run: the parser never auto-generates it.
- `change_url` **is** generated for webapps and **is expected to fail** until
  the `change_url` script exists (v2 / POLS-02). This is a Phase 6 finding.
- `upgrade.05e3d5b` is the upgrade-from test targeting the last installable
  released version (`v1.0`, version `0.8.8-rc3~ynh2`).

---

## 5. Retrieving logs

The result files are written in the **`package_check` clone root**, *not* in the
app directory:

```bash
ls -l ~/package_check/Test_results.log   # the summary log (colored text) — archive this
ls -l ~/package_check/full_log_0.log     # full debug log
ls -l ~/package_check/results_0.json     # machine-readable summary
```

Copy them back to the phase directory on Windows:

```powershell
$vm = "<user>@<static-ip>"
$dir = ".\.planning\phases\05-tests-toml-local-package-check-environment"
scp "${vm}:~/package_check/Test_results.log" "$dir\Test_results.log"
scp "${vm}:~/pc_run.log" "$dir\package_check-full.log"
```

**Telling a completed run from a crash/timeout:** a completed run prints a
**Global level summary** at the end of `Test_results.log` and exits cleanly. A
crash or timeout instead shows a `Critical:` abort line and no Global summary.
For Phase 5 you need the former (findings inside the summary are fine).

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Missing install arg admin_email ?` on every install test | `admin_email` has no manifest default | It must be supplied in `tests.toml` (`args.admin_email`) |
| `E: Unable to locate package incus` | Debian 12 has no native `incus` | Use the Zabbly repo (handled by `scripts/setup_pc_env.sh`) |
| Containers get no DNS / bridge missing | Something else already owns port 53 | Check `ss -lunp \| grep :53`; keep Docker/libvirt out of the VM; run `incus admin init` to create `incusbr0` |
| Snapshots are extremely slow; `incus storage list` shows `dir` | Initialized with a non-interactive dir-backed pool | Create/repoint the pool at `btrfs_pool` (the setup script does this) |
| SSH `Broken pipe` mid-run | Long install vs. idle SSH session | Use `tmux`/`nohup` or `ssh -o ServerAliveInterval=30`; tee to a log |
| `Package linter: fail` | `package_check` runs the linter as test #1; Phase 4's catalog criticals/errors are known exemptions | Expected Phase 5 finding (Phase 6 owns it) |
| `Change URL: fail` | No `scripts/change_url` | Expected; deferred to v2 (POLS-02) |
| `pcheck-0.lock` / leftover container blocks a run | Previous run aborted | `./package_check.sh -s` (force-stop) |

---

*See also: `05-RESEARCH.md` in `.planning/phases/05-tests-toml-local-package-check-environment/` for the source-derived details behind every step above.*
