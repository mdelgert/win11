#!/usr/bin/env bash

set -euo pipefail

# Script to download the latest Windows 11 ISO for Proxmox
WIN11_URL="https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso"
OUTPUT_DIR="./isos"
mkdir -p "$OUTPUT_DIR"

echo "Downloading Windows 11 ISO..."
curl -L -o "$OUTPUT_DIR/Win11.iso" "$WIN11_URL"
echo "Download complete: $OUTPUT_DIR/Win11.iso"