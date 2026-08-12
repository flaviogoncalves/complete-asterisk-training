#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Export the lab VM as a distributable OVA.
#
# Run on the HOST (works in Git Bash on Windows, or on macOS/Linux) after you
# have run build/prepare-for-export.sh inside the VM and powered it off.
#
#   ./export-ova.sh [vm-name] [version]
#   ./export-ova.sh asterisk-lab 1.0
#
# Produces asterisk-lab-base-<version>.ova and its SHA-256.
# ---------------------------------------------------------------------------
set -euo pipefail

VM="${1:-asterisk-lab}"
VERSION="${2:-1.0}"
OUT="asterisk-lab-base-${VERSION}.ova"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mError: %s\033[0m\n' "$*" >&2; exit 1; }

# VBoxManage is not on PATH by default on Windows.
VBM="$(command -v VBoxManage 2>/dev/null || true)"
[[ -n "${VBM}" ]] || for c in \
    "/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" \
    "/Applications/VirtualBox.app/Contents/MacOS/VBoxManage"; do
    [[ -x "$c" ]] && VBM="$c" && break
done
[[ -n "${VBM}" ]] || die "VBoxManage not found. Install VirtualBox or put it on PATH."

"${VBM}" showvminfo "${VM}" >/dev/null 2>&1 || die "no VM named '${VM}'"

state="$("${VBM}" showvminfo "${VM}" --machinereadable | sed -n 's/^VMState="\(.*\)"/\1/p')"
[[ "${state}" == "poweroff" ]] || die "VM is '${state}'. Shut it down first (sudo poweroff)."

# ---------------------------------------------------------------------------
log "Checking the VM is configured the way the labs describe"
info="$("${VBM}" showvminfo "${VM}" --machinereadable)"
nic1="$(sed -n 's/^nic1="\(.*\)"/\1/p' <<<"${info}")"
mem="$(sed -n 's/^memory=\(.*\)/\1/p' <<<"${info}")"
cpus="$(sed -n 's/^cpus=\(.*\)/\1/p' <<<"${info}")"

# Bridged is what Lab 0 tells the student to set, but the adapter NAME is
# specific to the machine that built the image and will not exist on theirs.
# Exporting as NAT avoids a VM that refuses to start on import; Lab 0 Step 3
# has them switch it to Bridged and pick their own adapter.
if [[ "${nic1}" != "nat" ]]; then
    log "Setting adapter 1 to NAT for export (Lab 0 Step 3 switches it to Bridged)"
    "${VBM}" modifyvm "${VM}" --nic1 nat
fi
echo "    memory: ${mem} MB, cpus: ${cpus}"
[[ "${mem}" -ge 2048 ]] || echo "    ! only ${mem} MB — Lab 1's build wants 4096"

# ---------------------------------------------------------------------------
log "Compacting the virtual disk"
# The controller is not always SATA. A VM imported from a cloud image uses
# SCSI, and matching only "SATA-0-0" silently skipped compaction and shipped
# a larger OVA than necessary — with a warning that is easy to scroll past.
disk="$(awk -F'"' '/^"(SATA|SCSI|IDE|NVMe)-[0-9]+-[0-9]+"=".*[.]vdi"$/ {print $4; exit}' <<<"${info}")"
[[ -n "${disk}" ]] || disk="$(awk -F'"' '/[.]vdi"$/ {print $4; exit}' <<<"${info}")"
if [[ -n "${disk}" && -f "${disk}" ]]; then
    before="$(du -m "${disk}" 2>/dev/null | cut -f1)"
    "${VBM}" modifymedium disk "${disk}" --compact
    after="$(du -m "${disk}" 2>/dev/null | cut -f1)"
    echo "    ${before} MB -> ${after} MB"
else
    echo "    ! could not locate the disk file; skipping compaction"
    echo "    ! did you run build/prepare-for-export.sh inside the VM?"
fi

# ---------------------------------------------------------------------------
log "Exporting ${OUT}"
rm -f "${OUT}"
"${VBM}" export "${VM}" \
    --output "${OUT}" \
    --ovf20 \
    --options manifest \
    --vsys 0 \
    --product "Asterisk Lab" \
    --producturl "https://voip.school" \
    --vendor "VoIP School" \
    --version "${VERSION}" \
    --description "Ubuntu 24.04 LTS with Asterisk 22.10.0 build dependencies and source. Asterisk is NOT installed - that is Lab 1."

# ---------------------------------------------------------------------------
log "Result"
size="$(du -m "${OUT}" | cut -f1)"
sha="$(sha256sum "${OUT}" | cut -d' ' -f1)"

printf '    file    %s\n    size    %s MB\n    sha256  %s\n' "${OUT}" "${size}" "${sha}"
printf '%s  %s\n' "${sha}" "${OUT}" > "${OUT}.sha256"

cat <<EOF

Upload it (S3 API endpoint — needs an R2 API token, not a browser):

    export AWS_ACCESS_KEY_ID=...        # from Cloudflare > R2 > API tokens
    export AWS_SECRET_ACCESS_KEY=...
    aws s3 cp ${OUT} s3://courses/ \
        --endpoint-url https://caef7c33730937961aafc2a49a849e32.r2.cloudflarestorage.com

    # or with rclone (provider = Cloudflare, same endpoint):
    rclone copy ${OUT} r2:courses/ --progress

Then give students a PUBLIC url. The endpoint above is NOT one — it answers
"InvalidArgument: Authorization" to an unsigned request. Either:

  a) Cloudflare > R2 > courses > Settings > Public access > Allow
     -> you get https://pub-<hash>.r2.dev/${OUT}
  b) bind a custom domain (e.g. labs.voip.school) to the bucket
     -> https://labs.voip.school/${OUT}

Put that public URL into labs/lab0-build-machine.md, replacing the
"DOWNLOAD URL GOES HERE" comment. The hash below is already in the lab.

    ${OUT}
    ${sha}

EOF
