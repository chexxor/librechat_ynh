#!/bin/bash
# scripts/setup_pc_env.sh
#
# Provision the local package_check host for the LibreChat YunoHost package.
#
# Run this INSIDE the dedicated Hyper-V Debian 12 VM, with sudo:
#
#     sudo bash scripts/setup_pc_env.sh <user>
#     BTRFS_DISK=/dev/sdc sudo -E bash scripts/setup_pc_env.sh <user>
#
# It is IDEMPOTENT: every mutation is guarded, so a second run is a safe
# no-op/repair. The full human walkthrough (Hyper-V VM provisioning -> in-VM
# setup -> running the suite -> retrieving logs) lives in doc/PACKAGE_CHECK.md.
#
# Env overrides:
#   BTRFS_DISK  block device for the btrfs storage pool (default: /dev/sdb).
#               Incus uses partition "${BTRFS_DISK}1"; create it with fdisk first.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root: sudo bash scripts/setup_pc_env.sh <user>" >&2
    exit 1
fi

TARGET_USER="${SUDO_USER:-${1:?usage: setup_pc_env.sh <user>}}"
BTRFS_DISK="${BTRFS_DISK:-/dev/sdb}"

echo "==> Provisioning package_check host for user '${TARGET_USER}' (btrfs disk ${BTRFS_DISK})"

# ---------------------------------------------------------------------------
# 1. Base dependencies.
#    package_check's assert_we_have_all_dependencies() fails without lynx, jq
#    and pip3; btrfs-progs is required to create the btrfs pool below.
# ---------------------------------------------------------------------------
apt-get update
apt-get install -y curl ca-certificates lynx jq python3 python3-pip git btrfs-progs

# ---------------------------------------------------------------------------
# 2. Incus via the Zabbly APT repository.
#    RESEARCH CORRECTION: Debian 12 (bookworm) has NO native `incus` package --
#    native packages begin with Debian 13 (trixie). A bare `apt install incus`
#    on bookworm fails with "Unable to locate package incus", so we add the
#    Zabbly repo for the lts-7.0 channel (chosen for reproducibility).
#
#    Expected signing key fingerprint:
#        4EFC 5906 96CB 15B8 7C73 A3AD 82CC 8797 C838 DCFD
#
#    (Alternative, comment only: on Debian 13 trixie the native `incus` package
#    would make this whole block unnecessary. The locked host decision is
#    Debian 12, so we keep Zabbly here.)
# ---------------------------------------------------------------------------
if ! command -v incus >/dev/null; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc

    cat > /etc/apt/sources.list.d/zabbly-incus-lts-7.0.sources <<EOF
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/lts-7.0
Suites: $(. /etc/os-release && echo "${VERSION_CODENAME}")
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF

    apt-get update
    apt-get install -y incus
else
    echo "==> Incus already installed, skipping Zabbly repo setup"
fi

# ---------------------------------------------------------------------------
# 3. Group membership. Applies at NEXT LOGIN: run `newgrp incus-admin` or
#    re-SSH (or reboot) before using incus without sudo.
# ---------------------------------------------------------------------------
usermod -aG incus-admin "${TARGET_USER}"
echo "==> Added ${TARGET_USER} to incus-admin. Re-login (newgrp incus-admin or re-SSH) to apply."

# ---------------------------------------------------------------------------
# 4. btrfs storage pool on the dedicated second disk.
#    Why btrfs and not `dir`: package_check relies on fast copy-on-write
#    snapshots between test phases, which the dir driver cannot provide. This
#    is why we do NOT use minimal/non-interactive init (loop-backed dir pool).
#    Create partition "${BTRFS_DISK}1" with fdisk before running; Incus formats
#    it. A fresh `incus admin init` may create a dir-backed default pool -- that
#    is fine, because we repoint the root device at btrfs_pool below.
#    Per the upstream README, remove the default root device first, then create
#    the pool and repoint the default profile's root device at it.
# ---------------------------------------------------------------------------
if ! incus storage list --format csv | cut -d, -f1 | grep -qx btrfs_pool; then
    incus profile device remove default root 2>/dev/null || true
    incus storage create btrfs_pool btrfs source="${BTRFS_DISK}1"
    incus profile device add default root disk path=/ pool=btrfs_pool
else
    echo "==> Storage pool 'btrfs_pool' already exists, skipping"
fi

# ---------------------------------------------------------------------------
# 5. YunoHost container image remote (package_check's set_incus_remote does
#    this too, but doing it here makes the host self-contained and idempotent).
# ---------------------------------------------------------------------------
if incus remote list -f json | jq -e '.yunohost' >/dev/null 2>&1; then
    echo "==> Incus remote 'yunohost' already configured, skipping"
else
    incus remote add yunohost https://repo.yunohost.org/incus --protocol simplestreams --public
fi

# ---------------------------------------------------------------------------
# 6. Clone package_check as the target user (logs/locks are relative to the
#    clone root, so keep the default ~/package_check location).
# ---------------------------------------------------------------------------
if [[ ! -d "/home/${TARGET_USER}/package_check" ]]; then
    sudo -u "${TARGET_USER}" git clone https://github.com/YunoHost/package_check "/home/${TARGET_USER}/package_check"
else
    echo "==> ~/package_check already cloned, skipping"
fi

# ---------------------------------------------------------------------------
# 7. Notes on things the script deliberately does not do.
# ---------------------------------------------------------------------------
# `incus admin init` is interactive. Run it yourself and pick a managed bridge
# so the incusbr0 interface (dnsmasq on port 53) exists -- package_check's
# check_incus_setup warns if incusbr0 is absent.
if ! ip a 2>/dev/null | grep -q incusbr0; then
    echo "==> NOTE: incusbr0 not found. Run 'incus admin init' (accept the managed bridge)."
fi

echo "==> Done. Next: log out/in for incus-admin, then run 'incus admin init' if not already done."
