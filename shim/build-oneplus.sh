#!/bin/bash
# Build the OnePlus 3 (oneplus3) shim: start.S + pixel.c + pstore.c + console.c, wrapped in
# a stock-style v0 boot.img by tools/mkboot-v0.sh.
# A PAYLOAD (tools/mkpayload.py, or tools/mkstub-payload.py with
# out/oneplus/stub.bin) is appended to the Image at _end (see pixel.c).
# Usage: [WDT_SECS=120] shim/build-pixel.sh STOCK_BOOT.img [PAYLOAD]   -> shim/out/oneplus-boot.img
# WDT_SECS: APSS watchdog bite after the jump (0 = off; see pixel.c).
set -euo pipefail
stock=$(realpath "$1")
payload=${2:+$(realpath "$2")}
cd "$(dirname "$0")"
X=aarch64-linux-gnu-
command -v ${X}gcc >/dev/null || X=aarch64-elf-	# macOS Homebrew
CFLAGS="-O2 -ffreestanding -nostdlib -fno-pic -mgeneral-regs-only -mstrict-align -fno-stack-protector -Wall -Wextra -DSWEET_ONEPLUS3 -DWDT_SECS=${WDT_SECS:-120}"
mkdir -p out/oneplus
for f in start.S pixel.c pstore.c console.c fdt.c loader.c; do
	${X}gcc $CFLAGS -c $f -o out/oneplus/${f%.*}.o
done
# No relocation pass at runtime: only start.o's image_size may be absolute.
abs=$(${X}readelf -r out/oneplus/pixel.o out/oneplus/pstore.o out/oneplus/console.o out/oneplus/fdt.o out/oneplus/loader.o | grep -c ABS64 || true)
[ "$abs" = 0 ] || { echo "error: $abs absolute relocations in C objects" >&2; exit 1; }
${X}gcc $CFLAGS -static -T shim.ld -Wl,--build-id=none -Wl,--no-warn-rwx-segments -Wl,-N \
	out/oneplus/start.o out/oneplus/pixel.o out/oneplus/pstore.o out/oneplus/console.o out/oneplus/fdt.o out/oneplus/loader.o -o out/oneplus/shim.elf
${X}objcopy -O binary out/oneplus/shim.elf out/oneplus/Image
size=$(${X}nm out/oneplus/shim.elf | awk '$3=="_end"{print $1}')
truncate -s $((16#$size)) out/oneplus/Image
[ -z "$payload" ] || cat "$payload" >> out/oneplus/Image
../tools/mkboot-v0.sh "$stock" out/oneplus/Image out/oneplus-boot.img
# Loader test "kernel" (shim/stub.c), same link rules.
${X}gcc $CFLAGS -c stub.c -o out/oneplus/stub.o
${X}gcc $CFLAGS -static -T shim.ld -Wl,--build-id=none -Wl,--no-warn-rwx-segments -Wl,-N \
	out/oneplus/stub.o out/oneplus/pstore.o -o out/oneplus/stub.elf
${X}objcopy -O binary out/oneplus/stub.elf out/oneplus/stub.bin
size=$(${X}nm out/oneplus/stub.elf | awk '$3=="_end"{print $1}')
truncate -s $((16#$size)) out/oneplus/stub.bin
