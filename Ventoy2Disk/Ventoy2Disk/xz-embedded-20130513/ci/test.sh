#!/bin/sh
# Smoke test on the host: xz -> xzminidec -> cmp, for the non-x86 binaries
# under qemu-user (the x86 ones are already tested inside the container by
# build.sh). Skips a binary, with a message, if qemu-user-static is missing.
set -eu
CI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=$CI/out
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
seq 1 200000 > "$t/in"; xz -c "$t/in" > "$t/in.xz"
fail=0
for pair in "xzminidecaa64 qemu-aarch64-static" "xzminidecm64e qemu-mips64el-static"; do
    set -- $pair
    if ! command -v "$2" >/dev/null; then echo "skip $1: $2 not installed"; continue; fi
    if "$2" "$OUT/$1" < "$t/in.xz" | cmp -s - "$t/in"; then echo "smoke $1: ok"
    else echo "smoke $1: FAILED"; fail=1; fi
done
exit "$fail"
