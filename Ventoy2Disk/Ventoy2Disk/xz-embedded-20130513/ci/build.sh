#!/bin/bash
# Runs INSIDE the CentOS 7.5 container (see Dockerfile.centos75).
# Builds the five xzminidec* binaries with the repo's own ventoy_makefile*
# files, unmodified, the way DOC/BuildVentoyFromSource.txt 4.15-4.18 says
# (make -f <makefile>, then strip --strip-all).
#
# The tree is copied to /home/share/Ventoy/xz-embedded-20130513 first.
# That is the directory xzminidec64 was built in: dietlibc puts the build
# directory into the DWARF, and the build-id hashes it, so the path matters.
#
# SOURCE=legacy (default) overlays linux/lib/xz/xz_dec_lzma2.c with the
# version from commit 863eafd2c (before 1.0.58). The committed blobs were
# built from that source; see ci/README.md.
#   /src : Ventoy checkout (read-only)   /dl : tarballs   /out : results
set -euo pipefail
SRC=/src; DL=/dl; OUT=/out
SOURCE=${SOURCE:-legacy}
XZ_REL=Ventoy2Disk/Ventoy2Disk/xz-embedded-20130513
W=/home/share/Ventoy

echo "=== compiler ==="
rpm -q gcc

echo "=== dietlibc 0.34 via DOC/installdietlibc.sh ==="
t=$(mktemp -d); cp "$DL/dietlibc-0.34.tar.xz" "$t/"
( cd "$t" && bash "$SRC/DOC/installdietlibc.sh" >/dev/null 2>&1 )
rm -rf "$t"
ls /opt/diet32/bin/diet /opt/diet64/bin/diet >/dev/null

echo "=== musl 1.2.1 -> /usr/local/musl ==="
t=$(mktemp -d); tar -C "$t" -xf "$DL/musl-1.2.1.tar.gz"
( cd "$t"/musl-1.2.1 && ./configure --prefix=/usr/local/musl >/dev/null && make -j"$(nproc)" >/dev/null && make install >/dev/null )
rm -rf "$t"

echo "=== cross toolchains -> /opt ==="
tar -C /opt -xf "$DL/aarch64--uclibc--stable-2020.08-1.tar.bz2"
tar -C /opt -xf "$DL/mips64el-linux-musl-gcc730.tar.bz2"
mv /opt/output /opt/mips64el-linux-musl-gcc730
export PATH=$PATH:/opt/aarch64--uclibc--stable-2020.08-1/bin:/opt/mips64el-linux-musl-gcc730/bin
aarch64-linux-gcc --version | head -1
mips64el-linux-musl-gcc --version | head -1

echo "=== source tree at $W (SOURCE=$SOURCE) ==="
rm -rf "$W"; mkdir -p "$W"
cp -a "$SRC/$XZ_REL" "$W/xz-embedded-20130513"
rm -rf "$W/xz-embedded-20130513/ci"
if [ "$SOURCE" = legacy ]; then
    # commit 863eafd2c's linux/lib/xz/xz_dec_lzma2.c; see ci/README.md
    echo "0c00eef5622315e870046842e2cb1aa745d04a5be4e04590e780773240b4fc76  $SRC/$XZ_REL/ci/legacy/xz_dec_lzma2.c" | sha256sum -c -
    cp "$SRC/$XZ_REL/ci/legacy/xz_dec_lzma2.c" "$W/xz-embedded-20130513/linux/lib/xz/xz_dec_lzma2.c"
fi

echo "=== make -f ventoy_makefile* xzminidec, strip ==="
cd "$W/xz-embedded-20130513/userspace"
mkdir -p "$OUT"
build() {  # <makefile> <strip> <output name>
    rm -f ./*.o xzminidec bytetest buftest boottest
    make -f "$1" xzminidec
    "$2" --strip-all xzminidec
    cp xzminidec "$OUT/$3"
    printf '%-14s ' "$3"; readelf -p .comment "$OUT/$3" | sed -n 's/^ *\[ *0\] *//p' | head -1
}
build ventoy_makefile        strip                         xzminidec32
build ventoy_makefile64      strip                         xzminidec64
build ventoy_makefile64_musl strip                         xzminidec64_musl
build ventoy_makefileaa64    aarch64-linux-strip           xzminidecaa64
build ventoy_makefilem64e    mips64el-linux-musl-strip     xzminidecm64e

echo "=== native smoke test (x86 binaries) ==="
t=$(mktemp -d); seq 1 200000 > "$t/in"; xz -c "$t/in" > "$t/in.xz"
for n in xzminidec32 xzminidec64 xzminidec64_musl; do
    "$OUT/$n" < "$t/in.xz" | cmp - "$t/in" && echo "smoke $n: ok"
done
rm -rf "$t"
