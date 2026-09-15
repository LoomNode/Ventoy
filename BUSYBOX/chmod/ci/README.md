# Reproducible build for `vtchmod*`

`vtchmod.c` is compiled five times by `../build.sh`, once per CPU Ventoy
boots on. The scripts here rebuild all five with the same toolchains the
committed binaries were built with, then `cmp` the result against the
files in git. Every one is byte-identical.

| binary          | toolchain                                                        | smoke test in CI |
|-----------------|------------------------------------------------------------------|------------------|
| vtchmod32       | CentOS 7.5.1804, gcc 4.8.5-28, dietlibc 0.34 (fefe tarball)      | native           |
| vtchmod64       | same                                                             | native           |
| vtchmod64_musl  | same container, musl 1.2.1                                       | native           |
| vtchmodaa64     | Bootlin `aarch64--uclibc--stable-2020.08-1` (gcc 9.3.0)          | qemu-user-static |
| vtchmodm64e     | `ventoy/musl-cross-make` release `output.tar.bz2` (gcc 7.3.0)    | qemu-user-static |

These are the toolchains listed in `DOC/BuildVentoyFromSource.txt`. The
only thing that matters for a hash match and is easy to get wrong:
Debian/Ubuntu ship `dietlibc 0.34~cvs20160606`, a later CVS snapshot whose
startup code differs. The fefe `dietlibc-0.34.tar.xz` release is required.

Known fragility: fefe.de no longer serves that tarball and no distro
mirror carries it, so `fetch.sh` falls back to the Wayback Machine. The
`ventoy/musl-cross-make` toolchain is a `latest` release tag. Both are
pinned by SHA-256 in `SHA256SUMS`, so if either upstream changes or goes
away the build fails loudly rather than producing different bytes.

## Run it

```sh
sh BUSYBOX/chmod/ci/run-all.sh
```

or step by step, from the repository root:

```sh
CI=BUSYBOX/chmod/ci
sh $CI/fetch.sh                     # download + verify the 4 tarballs into $CI/dl (or name a subset)
docker build -t vtchmod-centos75 -f $CI/Dockerfile.centos75 $CI
docker run --rm -v "$PWD:/src:ro" -v "$PWD/$CI/dl:/dl:ro" -v "$PWD/$CI/out:/out" \
    vtchmod-centos75 bash /src/$CI/build-x86.sh
docker run --rm -v "$PWD/$CI/out:/out" vtchmod-centos75 chown -R "$(id -u):$(id -g)" /out
sh $CI/build-cross.sh               # aarch64 + mips64el, no container needed
sh $CI/verify.sh                    # cmp against committed + the IMG/cpio_* copies, exit 1 on any mismatch
sh $CI/test.sh                      # smoke tests; non-x86 need qemu-user-static, skipped otherwise
```

`.github/workflows/build-vtchmod.yml` runs exactly this.
