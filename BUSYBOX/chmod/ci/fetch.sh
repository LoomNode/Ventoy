#!/bin/sh
# Download toolchain/libc tarballs into ci/dl and verify SHA-256.
# Usage: fetch.sh [name...]   (default: all four). Skips anything already
# present with the right hash.
set -eu
CI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DL=$CI/dl
mkdir -p "$DL"
[ $# -gt 0 ] || set -- dietlibc-0.34.tar.xz musl-1.2.1.tar.gz \
    aarch64--uclibc--stable-2020.08-1.tar.bz2 mips64el-linux-musl-gcc730.tar.bz2

wanted() { case " $WANT " in *" $1 "*) return 0 ;; esac; return 1; }
WANT=$*

get() {
    name=$1; shift
    wanted "$name" || return 0
    if [ -f "$DL/$name" ] && (cd "$DL" && grep " $name\$" "$CI/SHA256SUMS" | sha256sum -c --quiet - 2>/dev/null); then
        echo "fetch: $name ok (cached)"
        return 0
    fi
    for url in "$@"; do
        echo "fetch: $name <- $url"
        if curl -fL --retry 3 --connect-timeout 20 -o "$DL/$name.part" "$url"; then
            mv "$DL/$name.part" "$DL/$name"
            if (cd "$DL" && grep " $name\$" "$CI/SHA256SUMS" | sha256sum -c --quiet -); then
                return 0
            fi
            echo "fetch: $name hash mismatch from $url" >&2
            rm -f "$DL/$name"
        fi
        rm -f "$DL/$name.part"
    done
    echo "fetch: could not get $name" >&2
    return 1
}

# fefe.de no longer serves the 0.34 release; the Wayback copy hashes identically.
get dietlibc-0.34.tar.xz \
    'https://www.fefe.de/dietlibc/dietlibc-0.34.tar.xz' \
    'https://web.archive.org/web/20160314123456id_/https://www.fefe.de/dietlibc/dietlibc-0.34.tar.xz'
get musl-1.2.1.tar.gz \
    'https://musl.libc.org/releases/musl-1.2.1.tar.gz'
get aarch64--uclibc--stable-2020.08-1.tar.bz2 \
    'https://toolchains.bootlin.com/downloads/releases/toolchains/aarch64/tarballs/aarch64--uclibc--stable-2020.08-1.tar.bz2'
get mips64el-linux-musl-gcc730.tar.bz2 \
    'https://github.com/ventoy/musl-cross-make/releases/download/latest/output.tar.bz2'

echo "fetch: verified: $WANT"
