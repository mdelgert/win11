#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Create Windows 11 VM
#
# Requires these ISOs in the "downloads" Proxmox storage:
#
#   windows11-noprompt.iso
#   unattend.iso
#
# The Windows disk is first in the boot order.
#
# First boot:
#   ide0 is empty -> falls through to ide2 -> Windows Setup
#
# After Windows installs:
#   ide0 is bootable -> Windows starts normally
#
# This is important because windows11-noprompt.iso does NOT
# require a key press when booting from the CD.
# ============================================================

VMID=190
VMNAME="vm-win1"

CORES=2
SOCKETS=1
MEMORY=16384
BALLOON=2048

VM_STORAGE="local-lvm"

# Proxmox qm allocation syntax expects GiB here.
# Example: local-lvm:300 creates a 300 GiB disk.
DISK_SIZE=300

ISO_STORAGE="downloads"
WINDOWS_ISO="windows11-noprompt.iso"
UNATTEND_ISO="unattend.iso"

BRIDGE="vmbr0"
MACHINE="pc-q35-11.0+pve2"


# Must run as root.
if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root."
    exit 1
fi


# Do not overwrite an existing VM.
if qm status "$VMID" >/dev/null 2>&1; then
    echo "VM $VMID already exists."
    exit 1
fi


echo "Creating VM $VMID ($VMNAME)..."

# ============================================================
# Base VM
# ============================================================

qm create "$VMID" \
    --name "$VMNAME" \
    --ostype win11 \
    --machine "$MACHINE" \
    --bios ovmf \
    --cpu host \
    --cores "$CORES" \
    --sockets "$SOCKETS" \
    --memory "$MEMORY" \
    --balloon "$BALLOON" \
    --numa 0 \
    --agent 1 \
    --scsihw virtio-scsi-single \
    --net0 "e1000,bridge=${BRIDGE},firewall=1"


# ============================================================
# EFI / Secure Boot
#
# Created first -> vm-190-disk-0
# ============================================================

qm set "$VMID" \
    --efidisk0 "${VM_STORAGE}:0,efitype=4m,ms-cert=2023k,pre-enrolled-keys=1"


# ============================================================
# Main Windows disk
#
# Created second -> vm-190-disk-1
#
# IMPORTANT:
# Use local-lvm:300, not local-lvm:300G.
# ============================================================

qm set "$VMID" \
    --ide0 "${VM_STORAGE}:${DISK_SIZE},discard=on,ssd=1"


# ============================================================
# TPM 2.0
#
# Created third -> vm-190-disk-2
# ============================================================

qm set "$VMID" \
    --tpmstate0 "${VM_STORAGE}:0,version=v2.0"


# ============================================================
# Unattended installation ISO
# ============================================================

qm set "$VMID" \
    --ide1 "${ISO_STORAGE}:iso/${UNATTEND_ISO},media=cdrom"


# ============================================================
# Windows installation ISO
# ============================================================

qm set "$VMID" \
    --ide2 "${ISO_STORAGE}:iso/${WINDOWS_ISO},media=cdrom"


# ============================================================
# Boot order
#
# ide0 = Windows disk
# ide2 = Windows installer
# net0 = Network
# ide1 = Unattend ISO
#
# Keep ide0 FIRST.
#
# On initial boot the disk is empty, so UEFI falls through to
# the installer. Once Windows is installed, subsequent reboots
# boot from ide0 instead of restarting the installer.
# ============================================================

qm set "$VMID" \
    --boot "order=ide0;ide2;net0;ide1"


# ============================================================
# Finished
# ============================================================

echo
echo "VM created successfully:"
echo
qm config "$VMID"

# echo
# echo "Start installation with:"
# echo "  qm start $VMID"

echo
echo "Starting VM $VMID..."
qm start "$VMID"

echo
echo "VM status:"
qm status "$VMID"