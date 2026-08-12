#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Run this INSIDE the lab VM, as the last thing before you shut it down and
# export it. It makes the machine safe and small to distribute.
#
#   sudo ./prepare-for-export.sh
#   sudo poweroff
#
# Then export from the host with build/export-ova.sh.
# ---------------------------------------------------------------------------
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run me with sudo." >&2; exit 1; }

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Identity that must NOT be shared between copies
# ---------------------------------------------------------------------------
# Every student boots a clone of this disk. Anything unique baked in here stops
# being unique the moment it is copied.

log "Clearing SSH host keys"
# Otherwise every lab machine in the world presents the same host key, and each
# student's ssh client happily accepts a machine it has never seen. They are
# regenerated automatically on first boot.
rm -f /etc/ssh/ssh_host_*
cat > /etc/systemd/system/regenerate-ssh-host-keys.service <<'UNIT'
[Unit]
Description=Regenerate SSH host keys on first boot
ConditionPathExistsGlob=!/etc/ssh/ssh_host_*_key
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl enable regenerate-ssh-host-keys.service

log "Clearing the machine ID"
# systemd generates a new one at boot when the file is empty. If it is left in
# place, cloned machines can collide on a DHCP server that keys leases off it —
# students would take each other's IP addresses.
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

log "Clearing the lab TLS certificate"
# Regenerated at boot by lab-certs.service against whatever address DHCP gives
# this machine. Shipping one would mean every lab shares a private key.
rm -f /etc/asterisk/keys/asterisk.pem /etc/asterisk/keys/asterisk.key

# ---------------------------------------------------------------------------
# 2. History and logs
# ---------------------------------------------------------------------------
log "Clearing logs and shell history"
journalctl --rotate --quiet 2>/dev/null || true
journalctl --vacuum-time=1s --quiet 2>/dev/null || true
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
rm -f /root/.bash_history /home/*/.bash_history
rm -rf /root/.cache /home/*/.cache
# Netplan can persist the MAC of the build machine's NIC, which then fails to
# match on the student's hardware and leaves them with no network.
rm -f /etc/netplan/50-cloud-init.yaml.bak /etc/udev/rules.d/70-persistent-net.rules

# ---------------------------------------------------------------------------
# 3. Size
# ---------------------------------------------------------------------------
log "Removing package caches"
apt-get clean
rm -rf /var/lib/apt/lists/*
# The tarball is unpacked already; the archive is dead weight.
rm -f /usr/src/asterisk-*.tar.gz

log "Zeroing free space (this takes a few minutes and is worth it)"
# A virtual disk keeps every block ever written, including deleted files. The
# exported image carries all of it unless the free space is overwritten with
# zeroes first, which compress away to nothing. This is typically the
# difference between a 2 GB download and a 1 GB one.
fstrim -av 2>/dev/null || true
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

log "Done. Now: sudo poweroff — then export from the host."
