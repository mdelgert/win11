#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Prepare a Windows 11 ISO for unattended Proxmox installation.
#
# What this script does:
#   1. Installs wget and xorriso if they are missing.
#   2. Downloads the Microsoft Windows ISO if it is missing.
#   3. Rebuilds the ISO using Microsoft's efisys_noprompt.bin.
#   4. Produces an ISO that boots directly into Windows Setup
#      without "Press any key to boot from CD/DVD".
#
# Change only WINDOWS_URL when updating to a newer Windows ISO.
# The source filename is derived automatically from the URL.
# ============================================================

WINDOWS_URL="https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso"
ISO_DIR="/mnt/pve/downloads/template/iso"
SOURCE_ISO="$ISO_DIR/${WINDOWS_URL##*/}"
OUTPUT_ISO="$ISO_DIR/windows11-noprompt.iso"

WORK_DIR="$(mktemp -d)"
MOUNT_DIR="$(mktemp -d)"

cleanup() {
    mountpoint -q "$MOUNT_DIR" 2>/dev/null && umount "$MOUNT_DIR" || true
    rm -rf "$WORK_DIR" "$MOUNT_DIR"
}
trap cleanup EXIT

# Must run as root.
[[ $EUID -eq 0 ]] || {
    echo "Run this script as root."
    exit 1
}

# Install required tools only if missing.
missing=()
command -v wget >/dev/null 2>&1 || missing+=(wget)
command -v xorriso >/dev/null 2>&1 || missing+=(xorriso)

if ((${#missing[@]})); then
    apt-get update
    apt-get install -y "${missing[@]}"
fi

# Make sure the Proxmox ISO directory exists.
[[ -d "$ISO_DIR" ]] || {
    echo "ISO directory not found: $ISO_DIR"
    exit 1
}

# Download the original Microsoft ISO if needed.
if [[ ! -f "$SOURCE_ISO" ]]; then
    echo "Downloading Windows ISO..."
    wget -c "$WINDOWS_URL" -O "$SOURCE_ISO"
else
    echo "Windows ISO already exists:"
    echo "  $SOURCE_ISO"
fi

# Stop if the no-prompt ISO already exists.
if [[ -f "$OUTPUT_ISO" ]]; then
    echo "No-prompt ISO already exists:"
    echo "  $OUTPUT_ISO"
    exit 0
fi

echo "Mounting Windows ISO..."
mount -o loop,ro "$SOURCE_ISO" "$MOUNT_DIR"

echo "Copying ISO contents..."
cp -a "$MOUNT_DIR"/. "$WORK_DIR"/

umount "$MOUNT_DIR"

# Verify the Microsoft no-prompt UEFI boot image exists.
NOPROMPT="$WORK_DIR/efi/microsoft/boot/efisys_noprompt.bin"

[[ -f "$NOPROMPT" ]] || {
    echo "efisys_noprompt.bin was not found in the Windows ISO."
    exit 1
}

echo "Building no-prompt Windows ISO..."

xorriso -as mkisofs \
    -iso-level 3 \
    -J \
    -joliet-long \
    -R \
    -V "WIN11" \
    -b boot/etfsboot.com \
    -no-emul-boot \
    -boot-load-size 8 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e efi/microsoft/boot/efisys_noprompt.bin \
    -no-emul-boot \
    -o "$OUTPUT_ISO" \
    "$WORK_DIR"

echo
echo "Done."
echo "Use this ISO in Proxmox:"
echo "  $OUTPUT_ISO"