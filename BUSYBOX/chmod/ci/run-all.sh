#!/bin/sh
# One-shot: fetch, build (x86 in CentOS 7.5 container, aarch64/mips64el
# cross), verify byte-identical, smoke test. Needs docker and curl.
set -eu
CI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOP=$(CDPATH= cd -- "$CI/../../.." && pwd)
step() { printf '\n==== %s ====\n' "$1"; }

step "fetch toolchains"
sh "$CI/fetch.sh"

step "build CentOS 7.5 image"
docker build -q -t vtchmod-centos75 -f "$CI/Dockerfile.centos75" "$CI"

step "build vtchmod32 / vtchmod64 / vtchmod64_musl"
mkdir -p "$CI/out"
docker run --rm -v "$TOP:/src:ro" -v "$CI/dl:/dl:ro" -v "$CI/out:/out" \
    vtchmod-centos75 bash /src/BUSYBOX/chmod/ci/build-x86.sh
# results are written as root inside the container; hand them back
docker run --rm -v "$CI/out:/out" vtchmod-centos75 chown -R "$(id -u):$(id -g)" /out

step "build vtchmodaa64 / vtchmodm64e"
sh "$CI/build-cross.sh"

step "verify against committed"
sh "$CI/verify.sh"

step "smoke test"
sh "$CI/test.sh"
