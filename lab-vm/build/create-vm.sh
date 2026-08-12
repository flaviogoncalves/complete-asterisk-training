#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Create the lab VM in VirtualBox and install Ubuntu 24.04 into it unattended.
#
#   ./create-vm.sh /path/to/ubuntu-24.04.4-live-server-amd64.iso [vm-name]
#
# Produces a VM matching what Lab 0 Path B tells students to build by hand, so
# the image we ship and the machine they build themselves are the same thing.
#
# The install runs over NAT, because it needs the internet and NAT always
# works. Lab 0 Step 3 switches the adapter to Bridged — and so does the
# --bridge flag here, once the install has finished.
# ---------------------------------------------------------------------------
set -euo pipefail

ISO="${1:?usage: create-vm.sh <ubuntu-iso> [vm-name]}"
VM="${2:-asterisk-lab}"
RAM=4096
CPUS=2
DISK_MB=20480

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mError: %s\033[0m\n' "$*" >&2; exit 1; }

VBM="$(command -v VBoxManage 2>/dev/null || true)"
[[ -n "${VBM}" ]] || for c in \
    "/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" \
    "/Applications/VirtualBox.app/Contents/MacOS/VBoxManage"; do
    [[ -x "$c" ]] && VBM="$c" && break
done
[[ -n "${VBM}" ]] || die "VBoxManage not found"
[[ -f "${ISO}" ]] || die "ISO not found: ${ISO}"

# Windows VBoxManage needs a Windows-style path.
iso_arg="${ISO}"
case "$(uname -s)" in MINGW*|MSYS*) iso_arg="$(cygpath -w "${ISO}")" ;; esac

if "${VBM}" showvminfo "${VM}" >/dev/null 2>&1; then
    die "a VM named '${VM}' already exists. Remove it first:
    ${VBM} unregistervm '${VM}' --delete"
fi

# ---------------------------------------------------------------------------
log "Creating ${VM} (${RAM} MB, ${CPUS} vCPU, ${DISK_MB} MB disk)"
"${VBM}" createvm --name "${VM}" --ostype Ubuntu24_LTS_64 --register

# nic1 = NAT for the install. Switched to bridged at the end.
# The RAM and CPU count are what Lab 0 asks for; the Asterisk build in Lab 1
# is the reason. Less than 2 GB and `make -j` gets OOM-killed.
"${VBM}" modifyvm "${VM}" \
    --memory "${RAM}" --cpus "${CPUS}" \
    --nic1 nat \
    --nic-type1 virtio \
    --paravirt-provider kvm \
    --audio-driver none \
    --graphicscontroller vmsvga --vram 16 \
    --boot1 dvd --boot2 disk --boot3 none --boot4 none \
    --rtcuseutc on

# --paravirt-provider kvm gives the Linux guest a paravirtualised clock and
# scheduling hints, instead of leaving VirtualBox to autodetect. Timekeeping is
# exactly the subsystem an RCU stall complains about — this lab produced one
# ("rcu_preempt self-detected stall on CPU", ncpus=2) under sustained SIP load,
# so vCPU count alone does not save you. Pair it with VirtualBox 7.2 or newer.
#
# --nic-type1 virtio is not cosmetic. VirtualBox's default for a Linux guest is
# 82540EM (emulated Intel e1000), and this lab reliably kernel-panicked on it —
# "Fatal exception in interrupt" after ~25 minutes, taking the whole VM down
# mid-lab with nothing in the Asterisk logs to explain it. virtio-net is
# paravirtualised, faster, and does not do that.

vmdir="$("${VBM}" showvminfo "${VM}" --machinereadable | sed -n 's/^CfgFile="\(.*\)"/\1/p')"
vmdir="$(dirname "${vmdir}")"
disk="${vmdir}/${VM}.vdi"

"${VBM}" createmedium disk --filename "${disk}" --size "${DISK_MB}" --format VDI
"${VBM}" storagectl "${VM}" --name SATA --add sata --controller IntelAhci --portcount 2
"${VBM}" storageattach "${VM}" --storagectl SATA --port 0 --device 0 --type hdd --medium "${disk}"

# ---------------------------------------------------------------------------
log "Preparing the unattended install"
# VirtualBox generates the Ubuntu autoinstall answer file itself, so there is
# no cloud-init seed ISO to build — which is what makes this work identically
# on Windows, macOS and Linux with nothing installed but VirtualBox.
#
# --hostname must contain a dot or VirtualBox rejects it.
"${VBM}" unattended install "${VM}" \
    --iso="${iso_arg}" \
    --user=lab \
    --password=lab \
    --full-user-name="Lab User" \
    --hostname="asterisk-lab.lab" \
    --locale=en_US \
    --country=US \
    --time-zone=UTC \
    --install-additions \
    --post-install-command="apt-get update; apt-get install -y openssh-server git; systemctl enable --now ssh" \
    --start-vm=headless

log "Installing — this takes 10 to 20 minutes"
echo "    Watch with:  ${VBM} controlvm ${VM} screenshotpng /tmp/vm.png"
echo "    Or attach a window:  VirtualBoxVM --startvm ${VM}"

# The VM powers itself off when the install finishes.
waited=0
while [[ "$("${VBM}" showvminfo "${VM}" --machinereadable | sed -n 's/^VMState="\(.*\)"/\1/p')" != "poweroff" ]]; do
    sleep 20
    waited=$((waited + 20))
    printf '\r    %d:%02d elapsed' $((waited / 60)) $((waited % 60))
    [[ ${waited} -gt 3600 ]] && die "install did not finish within an hour"
done
printf '\n'

log "Install finished. Switching adapter 1 to Bridged."
# Pick the first bridgeable interface that is actually up.
bridge="$("${VBM}" list bridgedifs \
    | awk '/^Name:/{name=substr($0,index($0,$2))} /^Status: *Up/{if(name!=""){print name; exit}}')"
if [[ -n "${bridge}" ]]; then
    "${VBM}" modifyvm "${VM}" --nic1 bridged --bridge-adapter1 "${bridge}"
    echo "    bridged to: ${bridge}"
else
    echo "    ! no interface is up; left on NAT. Set it by hand before testing."
fi

cat <<EOF

Done. Next:

    ${VBM} startvm ${VM} --type headless
    # log in as lab / lab, then:
    #   git clone https://github.com/flaviogoncalves/asterisk-guide.git
    #   sudo ./asterisk-guide/lab-vm/provision.sh base

EOF
