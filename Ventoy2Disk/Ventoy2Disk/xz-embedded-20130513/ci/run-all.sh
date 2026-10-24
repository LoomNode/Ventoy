#!/bin/sh
# Local run of the whole job: fetch.sh, docker build, build.sh in the
# container, verify.sh, test.sh. Usage: sh ci/run-all.sh   (from the repo root or anywhere)
set -eu
CI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
R=$(CDPATH= cd -- "$CI/../../../.." && pwd)
cd "$CI"
sh fetch.sh
docker build -t xz-centos75 -f Dockerfile.centos75 .
mkdir -p out
docker run --rm -v "$R:/src:ro" -v "$CI/dl:/dl:ro" -v "$CI/out:/out" -e SOURCE=legacy \
    xz-centos75 bash /src/Ventoy2Disk/Ventoy2Disk/xz-embedded-20130513/ci/build.sh
sh verify.sh
sh test.sh
