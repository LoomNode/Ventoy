#!/bin/bash
# Runs INSIDE the CentOS 7.5 container (see Dockerfile.centos75).
# Builds dietlibc 0.34 (x86_64 + i386) and musl 1.2.1 the way Ventoy's
# DOC/BuildVentoyFromSource.txt lays them out, then runs the exact compile
# lines from ../build.sh.
#   /src : Ventoy checkout (read-only)   /dl : tarballs   /out : results
set -euo pipefail
SRC=${SRC:-/src}
DL=${DL:-/dl}
OUT=${OUT:-/out}
SRC_C=$SRC/BUSYBOX/chmod/vtchmod.c

echo "=== compiler ==="
rpm -q gcc
gcc --version | head -1

echo "=== dietlibc 0.34 -> /opt/diet64, /opt/diet32 ==="
srcdir=$(mktemp -d)
tar -C "$srcdir" -xf "$DL/dietlibc-0.34.tar.xz"
root=$(echo "$srcdir"/dietlibc-*)
make -C "$root" -j"$(nproc)" >/dev/null
make -C "$root" -j"$(nproc)" i386 >/dev/null

# diet's `make install` refuses to install the wrapper for a non-native
# ARCH, so lay out the two prefixes by hand and link the wrapper ourselves.
install_diet() {
    obj=$1; prefix=$2; lib=$prefix/lib-${obj#bin-}
    install -d "$prefix/bin" "$lib"
    install -m 644 "$root/$obj/start.o" "$root/$obj/dyn_start.o" "$root/$obj/dyn_stop.o" "$lib/"
    install -m 644 "$root/$obj/dietlibc.a" "$lib/libc.a"
    for a in libm libpthread librpc liblatin1 libcompat libcrypt; do
        [ -f "$root/$obj/$a.a" ] && install -m 644 "$root/$obj/$a.a" "$lib/"
    done
    ( cd "$root" && tar cf - include ) | ( cd "$prefix" && tar xf - )
    gcc -D__dietlibc__ -I "$root" -isystem "$root/include" -pipe -nostdinc -D_REENTRANT -Os \
        -nostdlib -o "$prefix/bin/diet" \
        "$root/bin-x86_64/start.o" "$root/bin-x86_64/dyn_start.o" "$root/diet.c" \
        "$root/bin-x86_64/dietlibc.a" "$root/bin-x86_64/dyn_stop.o" \
        -DDIETHOME="\"$prefix\"" -DVERSION='"dietlibc-0.34"' -DINSTALLVERSION -lgcc
}
install_diet bin-x86_64 /opt/diet64
install_diet bin-i386   /opt/diet32
rm -rf "$srcdir"

echo "=== musl 1.2.1 -> /usr/local/musl ==="
srcdir=$(mktemp -d)
tar -C "$srcdir" -xf "$DL/musl-1.2.1.tar.gz"
( cd "$srcdir"/musl-1.2.1 && ./configure --prefix=/usr/local/musl >/dev/null && make -j"$(nproc)" >/dev/null && make install >/dev/null )
rm -rf "$srcdir"

echo "=== vtchmod (lines from BUSYBOX/chmod/build.sh) ==="
mkdir -p "$OUT"
work=$(mktemp -d); cp "$SRC_C" "$work/"; cd "$work"
DIETHOME=/opt/diet32 /opt/diet32/bin/diet gcc -Os -m32 vtchmod.c -o "$OUT/vtchmod32"
DIETHOME=/opt/diet64 /opt/diet64/bin/diet gcc -Os      vtchmod.c -o "$OUT/vtchmod64"
gcc -specs /usr/local/musl/lib/musl-gcc.specs -Os -static vtchmod.c -o "$OUT/vtchmod64_musl"
strip --strip-all "$OUT/vtchmod64_musl"
chmod 755 "$OUT"/vtchmod32 "$OUT"/vtchmod64 "$OUT"/vtchmod64_musl
cd /; rm -rf "$work"

for n in vtchmod32 vtchmod64 vtchmod64_musl; do
    printf '%-16s ' "$n"; readelf -p .comment "$OUT/$n" | sed -n 's/^ *\[ *0\] *//p'
done
sha256sum "$OUT"/vtchmod32 "$OUT"/vtchmod64 "$OUT"/vtchmod64_musl
