#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Asterisk Lab VM — provisioning
#
# Turns a clean Ubuntu 24.04 LTS server into the course lab machine.
#
# Two stages, because the course teaches the Asterisk install as a lab and the
# student must actually perform it:
#
#   sudo ./provision.sh base     Ubuntu + build dependencies + lab tooling +
#                                the Asterisk source unpacked in /usr/src, but
#                                NOT built. This is the image students receive.
#                                Lab 1 is them running ./configure && make.
#
#   sudo ./provision.sh full     base, then build and install Asterisk and
#                                deploy the lab configuration. Used to produce
#                                the reference VM, and as the escape hatch for
#                                a student whose build fails (`lab rescue`).
#
# Shipping `base` is deliberate. Lessons 0.6 and 0.7 teach ./configure,
# menuselect, make and make install; a VM with Asterisk already on it would
# make those lessons something the student reads but never does. What `base`
# removes is only the part with nothing to teach: installing the OS, resolving
# dependencies, and downloading a tarball that may fail twenty minutes in.
#
# Idempotent: safe to re-run. `full` skips the build if the pinned version is
# already installed.
# ---------------------------------------------------------------------------
set -euo pipefail

STAGE="${1:-full}"
case "${STAGE}" in
    base|full) ;;
    *) echo "Usage: $0 [base|full]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lab.env
source "${HERE}/lab.env"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }

[[ $EUID -eq 0 ]] || { echo "Run me with sudo." >&2; exit 1; }

if ! grep -q 'VERSION_ID="24.04"' /etc/os-release 2>/dev/null; then
    warn "This lab is built and tested on Ubuntu 24.04 LTS. Continuing anyway."
fi

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
log "Installing build dependencies and lab tooling"
apt-get update -qq

# Build dependencies for Asterisk. We use bundled jansson and pjproject so the
# PJSIP stack is version-matched to Asterisk and we need fewer apt packages.
# libsrtp2-dev is required for SRTP (the TLS/SRTP lab).
apt-get install -y --no-install-recommends \
    build-essential wget curl ca-certificates pkg-config subversion gettext-base \
    libedit-dev libxml2-dev libsqlite3-dev uuid-dev libssl-dev \
    libsrtp2-dev libcurl4-openssl-dev libncurses-dev libjansson-dev \
    unixodbc unixodbc-dev odbc-mariadb

# Tooling the labs use. Installed up front so no lab ever begins with "first,
# install a tool" — that is where students stall.
#   sngrep       - the SIP capture tool used all through the SIP labs
#   sip-tester   - provides sipp, for headless call generation
#   tcpdump      - packet capture for the troubleshooting labs
#   fail2ban     - the brute-force lab
#   mariadb      - CDR/ODBC lab
#   jq           - reading ARI JSON responses
apt-get install -y --no-install-recommends \
    sngrep sip-tester tcpdump fail2ban mariadb-server jq \
    iptables-persistent netcat-openbsd python3 python3-websockets vim less

# ---------------------------------------------------------------------------
# 1b. Staging — needed by both stages
# ---------------------------------------------------------------------------
# Everything here exists in the student image too, because Lab 1 depends on it:
# it copies the service unit from /opt/lab and can fall back to `lab rescue`.
stage_common() {
    log "Staging lab files in /opt/lab"
    mkdir -p /opt/lab
    install -m 0644 "${HERE}/lab.env" /opt/lab/lab.env

    # The unit Lab 1 copies into place, and that the Deployment and Operations
    # section takes apart line by line. Staged rather than installed: in the
    # student image there is no Asterisk yet for it to start.
    cat > /opt/lab/asterisk.service <<'UNIT'
[Unit]
Description=Asterisk PBX
Documentation=man:asterisk(8)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=asterisk
Group=asterisk

# Creates /run/asterisk owned by asterisk:asterisk on every start, and removes
# it on stop. Without this, Asterisk starts, logs "Asterisk Ready", and reports
# active (running) — but cannot create its control socket in the root-owned
# /run/asterisk, so `asterisk -rx` fails with "Unable to connect to remote
# asterisk". A running PBX with an unusable CLI, and nothing in the status
# output to say why. /run is tmpfs, so this must be recreated at every boot;
# a one-off mkdir would work until the first reboot and then stop working.
RuntimeDirectory=asterisk
RuntimeDirectoryMode=0750

ExecStart=/usr/sbin/asterisk -f -U asterisk -G asterisk
ExecReload=/usr/sbin/asterisk -rx 'core reload'
Restart=on-failure
RestartSec=5
# Needed to bind SIP's low ports and to raise RTP thread priority as non-root.
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_SYS_NICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_SYS_NICE
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

    # Worked examples the labs copy from, rather than retyping into a heredoc.
    if [[ -d "${HERE}/examples" ]]; then
        mkdir -p /opt/lab/examples
        install -m 0644 "${HERE}"/examples/* /opt/lab/examples/
    fi

    install -m 0755 "${HERE}/bin/lab"      /usr/local/bin/lab
    install -m 0755 "${HERE}/bin/motd-lab" /etc/update-motd.d/99-lab
    # Ubuntu's stock banner is noise next to the lab's own.
    chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true

    hostnamectl set-hostname "${LAB_HOSTNAME}" 2>/dev/null || true

    # --- keep the guest kernel alive -----------------------------------------
    # The kernel loads raid0/1/10/456 and raid6_pq on this image even though the
    # VM has a single virtual disk and no RAID of any kind — every one of them
    # sits there with zero users. raid6_pq benchmarks its vector codepaths at
    # load time and faults inside an AVX routine under VirtualBox, which hangs
    # boot in initramfs with a kernel BUG at raid6_choose_gen.
    #
    # The other cure is masking AVX per-VM with `VBoxManage setextradata`, but
    # that is host-side configuration and is NOT carried inside an exported OVA
    # — every student would have to run it by hand before first boot. Doing it
    # in the image means the appliance simply works.
    if [[ ! -f /etc/modprobe.d/blacklist-raid.conf ]]; then
        log "Blacklisting unused RAID modules (they crash the guest under VirtualBox)"
        cat > /etc/modprobe.d/blacklist-raid.conf <<'MODS'
# This lab VM has one virtual disk and no RAID. These modules are never used,
# and raid6_pq's load-time benchmark faults under VirtualBox's CPU emulation.
blacklist raid6_pq
blacklist async_raid6_recov
blacklist raid456
blacklist raid10
blacklist raid1
blacklist raid0
blacklist md_mod
MODS
        # Only ship modules this hardware actually needs, and rebuild so the
        # blacklist applies to the initramfs too — that is where it crashed.
        sed -i 's/^MODULES=.*/MODULES=dep/' /etc/initramfs-tools/initramfs.conf
        update-initramfs -u >/dev/null 2>&1 || warn "update-initramfs failed"
    fi

    # --- network ------------------------------------------------------------
    # Nothing to configure. The adapter is bridged and takes an address from
    # the network's own DHCP, which is what the cloud image already does. No
    # fixed address is written anywhere, deliberately — see lab.env.

    # --- TLS certificate ----------------------------------------------------
    # The certificate has to name the address the browser will actually use,
    # and with DHCP that is not known until the machine boots on the student's
    # network. So it is generated at every boot, and regenerated whenever the
    # address changes. Without this the WebRTC lab fails with a certificate
    # error that reads, wrongly, as "WebRTC is broken".
    log "Installing the boot-time certificate refresh"
    cat > /etc/systemd/system/lab-certs.service <<'UNIT'
[Unit]
Description=Refresh the Asterisk lab TLS certificate for the current IP
After=network-online.target
Wants=network-online.target
Before=asterisk.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lab certs
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
    systemctl enable lab-certs.service 2>/dev/null || true
}

stage_common

# ---------------------------------------------------------------------------
# 2. Asterisk
# ---------------------------------------------------------------------------
SRC="/usr/src/asterisk-${ASTERISK_VERSION}"

# The source is always staged, in both modes. In `base` this is what the
# student finds waiting for them — Lab 1 begins at `cd /usr/src/asterisk-22.10.0`
# with the download already done, so a slow or broken network cannot end the
# lab before it starts.
if [[ ! -d "${SRC}" ]]; then
    log "Fetching the Asterisk ${ASTERISK_VERSION} source"
    # Use releases/, NOT the top-level asterisk/ directory.
    #
    # The top-level directory only ever holds the newest point release. When
    # 22.10.1 shipped, .../asterisk/asterisk-22.10.0.tar.gz became a 404 and
    # every build pinned to 22.10.0 broke overnight — which is exactly what
    # happened to the Docker lab this replaces. releases/ keeps every version
    # permanently, so a pin stays valid.
    url="https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz"
    if ! wget -q -O "/usr/src/asterisk-${ASTERISK_VERSION}.tar.gz" "${url}"; then
        rm -f "/usr/src/asterisk-${ASTERISK_VERSION}.tar.gz"
        warn "Could not download ${url}"
        warn "Check that ASTERISK_VERSION=${ASTERISK_VERSION} in lab.env still exists:"
        warn "  curl -s https://downloads.asterisk.org/pub/telephony/asterisk/releases/ | grep asterisk-22"
        exit 1
    fi
    tar xzf "/usr/src/asterisk-${ASTERISK_VERSION}.tar.gz" -C /usr/src
    rm -f "/usr/src/asterisk-${ASTERISK_VERSION}.tar.gz"
fi
# Left owned by root. Lab 1 builds with sudo throughout — `make install` needs
# root anyway, and a half-sudo build leaves root-owned objects in a tree the
# student then cannot clean, which fails confusingly on the second attempt.

if [[ "${STAGE}" == "base" ]]; then
    log "Stage 'base' complete — Asterisk source staged in ${SRC}, not built"
    log "This is the student image. Lab 1 is where Asterisk gets installed."
    exit 0
fi

installed_version=""
if command -v asterisk >/dev/null 2>&1; then
    installed_version="$(asterisk -V 2>/dev/null | awk '{print $2}')"
fi

if [[ "${installed_version}" == "${ASTERISK_VERSION}" ]]; then
    log "Asterisk ${ASTERISK_VERSION} already installed — skipping build"
else
    log "Building Asterisk ${ASTERISK_VERSION} from source (this is the slow part)"
    cd "${SRC}"
    ./configure --with-jansson-bundled --with-pjproject-bundled --with-srtp
    make menuselect.makeopts

    # res_srtp + res_http_websocket: the TLS/SRTP and WebRTC labs.
    # res_odbc + cdr_adaptive_odbc: the CDR-to-database lab.
    # app_macro is deprecated; we deliberately leave it off — the dialplan
    # labs use Gosub, which is what Asterisk 22 expects.
    menuselect/menuselect \
        --enable res_srtp \
        --enable res_http_websocket \
        --enable res_odbc \
        --enable cdr_adaptive_odbc \
        --enable res_ari \
        --enable res_ari_applications \
        --enable CORE-SOUNDS-EN-ULAW \
        --enable EXTRA-SOUNDS-EN-ULAW \
        menuselect.makeopts

    make -j"$(nproc)"
    make install
    # Lessons 0.6 and 0.7 teach `make samples` as step 8 of the install. It
    # writes the stock configs into /etc/asterisk; the lab configuration is
    # laid over the top of them further down, so the order here matters.
    make samples
    make install-logrotate
    ldconfig
    log "Asterisk $(asterisk -V) installed"
fi

# ---------------------------------------------------------------------------
# 3. Run Asterisk as its own user, under systemd
# ---------------------------------------------------------------------------
# The Docker lab ran Asterisk as PID 1 as root. Here it is a normal service,
# which is what production looks like — and what makes the systemd, iptables
# and fail2ban labs real instead of theoretical.
log "Creating the asterisk service account"
if ! id -u asterisk >/dev/null 2>&1; then
    adduser --system --group --home /var/lib/asterisk --no-create-home \
            --gecos "Asterisk PBX" asterisk
fi
usermod -aG audio,dialout asterisk 2>/dev/null || true

# The lab user needs to read/edit configs and use the CLI without sudo.
if id -u "${LAB_USER}" >/dev/null 2>&1; then
    usermod -aG asterisk "${LAB_USER}"
fi

for d in /var/lib/asterisk /var/log/asterisk /var/spool/asterisk \
         /var/run/asterisk /usr/lib/asterisk /etc/asterisk; do
    mkdir -p "$d"
    chown -R asterisk:asterisk "$d"
done
chmod -R g+w /etc/asterisk

log "Installing the systemd unit"
# The same file Lab 1 has the student copy — staged by stage_common, so the
# reference VM and the student's hand-built machine end up identical.
install -m 0644 /opt/lab/asterisk.service /etc/systemd/system/asterisk.service

# Asterisk's own init script would fight systemd for control of the service.
systemctl disable --now asterisk.init 2>/dev/null || true
rm -f /etc/init.d/asterisk
systemctl daemon-reload

# ---------------------------------------------------------------------------
# 4. Lab configuration
# ---------------------------------------------------------------------------
log "Installing the lab Asterisk configuration"

# Keep the pristine sample configs — the labs refer to them, and students who
# break something need something to compare against.
if [[ ! -d /etc/asterisk.samples ]]; then
    cp -a /etc/asterisk /etc/asterisk.samples
fi

# Configs are templates: ${EXT_A}, ${TRUNK_HOST} and friends come from lab.env,
# so credentials and addresses are defined exactly once in this repo.
#
# envsubst is restricted to the names defined in lab.env. Without that list it
# would also expand Asterisk's own dialplan variables — ${EXTEN}, ${CALLERID(num)}
# — into empty strings and quietly produce a broken dialplan.
LAB_VARS="$(sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/$\1/p' "${HERE}/lab.env" | tr '\n' ' ')"

shopt -s nullglob
for tpl in "${HERE}"/asterisk/etc/*.conf; do
    target="/etc/asterisk/$(basename "${tpl}")"
    envsubst "${LAB_VARS}" < "${tpl}" > "${target}"
    chown asterisk:asterisk "${target}"
done
shopt -u nullglob

# TLS material for the secure WebSocket the browser phone uses, and for the
# TLS/SRTP lab. Generated by `lab certs` against whatever address DHCP gave
# this machine — the same code path that runs on every boot, so the reference
# VM and a student's machine produce the certificate the same way.
/usr/local/bin/lab certs

# A snapshot of the known-good config, so `lab reset` can always put a student
# back to a working PBX instead of leaving them stuck.
rm -rf /opt/lab/baseline
mkdir -p /opt/lab/baseline
cp -a /etc/asterisk/. /opt/lab/baseline/

# Networking, the `lab` helper, the login banner and the staged service unit
# were all handled by stage_common() near the top — they are identical in both
# the student image and this reference build.

# ---------------------------------------------------------------------------
# 5. Start it
# ---------------------------------------------------------------------------
log "Enabling Asterisk"
systemctl enable asterisk
systemctl restart asterisk

# fail2ban ships enabled with an ssh jail; the Asterisk jail is switched on by
# the student during the security lab, not here.
systemctl disable --now fail2ban 2>/dev/null || true

sleep 3
if asterisk -rx 'core show version' 2>/dev/null | grep -q "${ASTERISK_VERSION}"; then
    log "Lab ready — Asterisk ${ASTERISK_VERSION} answering on ${LAB_IP}"
else
    warn "Asterisk did not answer the CLI. Check: journalctl -u asterisk -n 50"
    exit 1
fi
