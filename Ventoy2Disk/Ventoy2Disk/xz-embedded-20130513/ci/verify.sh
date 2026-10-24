#!/bin/sh
# Compares ci/out/<name> with the committed IMG/cpio_*/ventoy/busybox/<name>.
# Four binaries are gated: they match byte-for-byte when built from the
# pre-1.0.58 source (ci/legacy/). xzminidec32 is reported but not gated,
# because no build tried locally reproduces it (ci/README.md).
set -eu
CI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOP=$(CDPATH= cd -- "$CI/../../../.." && pwd)
OUT=$CI/out
X=Ventoy2Disk/Ventoy2Disk/xz-embedded-20130513
fail=0
printf '%-8s %-64s %s\n' result sha256 name

# name                 committed path
for pair in \
    "xzminidec32       IMG/cpio_x86/ventoy/busybox/xzminidec32" \
    "xzminidec64       IMG/cpio_x86/ventoy/busybox/xzminidec64" \
    "xzminidec64_musl  IMG/cpio_x86/ventoy/busybox/xzminidec64_musl" \
    "xzminidecaa64     IMG/cpio_arm64/ventoy/busybox/xzminidecaa64" \
    "xzminidecm64e     IMG/cpio_mips64/ventoy/busybox/xzminidecm64e"
do
    set -- $pair
    name=$1; path=$2
    h=$(sha256sum "$OUT/$name" | cut -d' ' -f1)
    if cmp -s "$TOP/$path" "$OUT/$name"; then
        printf '%-8s %-64s %s\n' MATCH "$h" "$path"
    elif [ "$name" = xzminidec32 ]; then
        printf '%-8s %-64s %s (not gated: see ci/README.md)\n' DIFF "$h" "$path"
    else
        printf '%-8s %-64s %s (committed %s)\n' DIFF "$h" "$path" "$(sha256sum "$TOP/$path" | cut -c1-12)"
        fail=1
    fi
done
[ "$fail" -eq 0 ] && echo "verify: gated binaries identical" || echo "verify: FAILED"
exit "$fail"
