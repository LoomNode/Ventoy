#!/bin/sh
# Byte-compare every rebuilt binary in ci/out against the committed one,
# then against the copies build.sh installs into the cpio trees
# (BLOB_List.md: "Same with ./BUSYBOX/chmod/<name>, check the file hash to confirm").
# Pass a subset of names to check only those (the CI jobs build in halves).
set -eu
CI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOP=$(CDPATH= cd -- "$CI/../../.." && pwd)
OUT=$CI/out
[ $# -gt 0 ] || set -- vtchmod32 vtchmod64 vtchmod64_musl vtchmodaa64 vtchmodm64e
fail=0

copy_of() {
    case "$1" in
        vtchmodaa64) echo "IMG/cpio_arm64/ventoy/busybox/$1" ;;
        vtchmodm64e) echo "IMG/cpio_mips64/ventoy/busybox/$1" ;;
        *)           echo "IMG/cpio_x86/ventoy/busybox/$1" ;;
    esac
}

printf '%-16s %-8s %s\n' binary result sha256
for n in "$@"; do
    if [ ! -f "$OUT/$n" ]; then
        printf '%-16s %-8s %s\n' "$n" MISSING -; fail=1; continue
    fi
    new=$(sha256sum "$OUT/$n" | cut -d' ' -f1)
    if cmp -s "$CI/../$n" "$OUT/$n"; then
        printf '%-16s %-8s %s\n' "$n" MATCH "$new"
    else
        old=$(sha256sum "$CI/../$n" | cut -d' ' -f1)
        printf '%-16s %-8s rebuilt %s\n%-16s %-8s committed %s\n' "$n" DIFF "$new" '' '' "$old"; fail=1
    fi
    copy=$(copy_of "$n")
    if [ ! -f "$TOP/$copy" ]; then
        printf '%-16s %-8s %s\n' '' MISSING "$copy"; fail=1
    elif cmp -s "$TOP/$copy" "$OUT/$n"; then
        printf '%-16s %-8s %s\n' '' MATCH "$copy"
    else
        printf '%-16s %-8s %s\n' '' DIFF "$copy"; fail=1
    fi
done
[ "$fail" -eq 0 ] && echo "verify: all identical" || echo "verify: FAILED"
exit "$fail"
