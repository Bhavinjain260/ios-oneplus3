#!/bin/bash
# Build the OnePlus 3 boot image from the assembled payload.
# Mirrors shim/build-pixel.sh; the only delta is the page size and
# base address of the OP3 stock boot.img header (Android boot image
# v2 with 4096-byte page size, kernel load address 0x80080000).
#
# Usage: WDT_SECS=0 shim/build-oneplus.sh STOCK_BOOT.img payload
#
# The output is shim/out/oneplus3-boot.img, ready for `fastboot boot`.
# Nothing is flashed - `fastboot boot` is temporary, exactly as on
# the Pixel 1.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
mkdir -p "$OUT_DIR"

if [ "$#" -lt 2 ]; then
    echo "usage: $0 STOCK_BOOT.img payload" >&2
    exit 1
fi
STOCK="$1"
PAYLOAD="$2"

# Unpack the stock boot image to get the header (page size, base address,
# cmdline, etc.). The mkbootimg tool is the standard Android one.
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
python3 "$SCRIPT_DIR/../tools/unpack_bootv2.py" "$STOCK" "$TMP/unpacked"

# Re-pack: same header, but the kernel section is the payload + the
# original ramdisk (OP3's stock recovery ramdisk is tiny and harmless;
# the shim does not use it). The second-stage bootloader (XNU) is the
# payload itself.
python3 "$SCRIPT_DIR/../tools/mkbootimg.py" \
    --kernel "$PAYLOAD" \
    --ramdisk "$TMP/unpacked/ramdisk" \
    --second "$TMP/unpacked/second" \
    --dtbo "$TMP/unpacked/dtbo" \
    --pagesize "$(jq -r .pagesize "$TMP/unpacked/header.json")" \
    --base "$(jq -r .base "$TMP/unpacked/header.json")" \
    --cmdline "$(jq -r .cmdline "$TMP/unpacked/header.json")" \
    -o "$OUT_DIR/oneplus3-boot.img"

echo "wrote $OUT_DIR/oneplus3-boot.img ($(stat -c%s "$OUT_DIR/oneplus3-boot.img") bytes)"
