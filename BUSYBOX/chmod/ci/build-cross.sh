#!/bin/sh
# aarch64 (Bootlin uClibc 2020.08) and mips64el (ventoy/musl-cross-make gcc 7.3.0)
# cross builds, run on a plain x86_64 Linux host. No container needed.
set -eu
CI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DL=$CI/dl; OUT=$CI/out; WORK=$CI/work
SRC_C=$CI/../vtchmod.c
mkdir -p "$OUT" "$WORK"

AA=$WORK/aarch64--uclibc--stable-2020.08-1
MIPS=$WORK/mips64el-linux-musl-gcc730
if [ ! -x "$AA/bin/aarch64-linux-gcc" ]; then
    tar -C "$WORK" -xf "$DL/aarch64--uclibc--stable-2020.08-1.tar.bz2"
fi
if [ ! -x "$MIPS/bin/mips64el-linux-musl-gcc" ]; then
    rm -rf "$WORK/output"
    tar -C "$WORK" -xf "$DL/mips64el-linux-musl-gcc730.tar.bz2"
    mv "$WORK/output" "$MIPS"
fi
PATH=$AA/bin:$MIPS/bin:$PATH
export PATH

tmp=$(mktemp -d); cp "$SRC_C" "$tmp/"; cd "$tmp"
echo "=== aarch64: $(aarch64-linux-gcc --version | head -1) ==="
aarch64-linux-gcc -Os -static vtchmod.c -o "$OUT/vtchmodaa64"
aarch64-linux-strip --strip-all "$OUT/vtchmodaa64"
echo "=== mips64el: $(mips64el-linux-musl-gcc --version | head -1) ==="
mips64el-linux-musl-gcc -mips64r2 -mabi=64 -Os -static vtchmod.c -o "$OUT/vtchmodm64e"
mips64el-linux-musl-strip --strip-all "$OUT/vtchmodm64e"
chmod 755 "$OUT/vtchmodaa64" "$OUT/vtchmodm64e"
cd /; rm -rf "$tmp"
sha256sum "$OUT/vtchmodaa64" "$OUT/vtchmodm64e"
