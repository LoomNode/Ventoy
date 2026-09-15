# Reproducible build for `vtchmod*`

`vtchmod.c` is compiled five times by `../build.sh`, once per CPU Ventoy
boots on. The scripts here rebuild all five with the same toolchains the
committed binaries were built with, then `cmp` the result against the
files in git. Every one is byte-identical.

| binary          | toolchain                                                        | ran on hardware       |
|-----------------|------------------------------------------------------------------|-----------------------|
| vtchmod32       | CentOS 7.5.1804, gcc 4.8.5-28, dietlibc 0.34 (fefe tarball)      | x86_64                |
| vtchmod64       | same                                                             | x86_64                |
| vtchmod64_musl  | same container, musl 1.2.1                                       | x86_64                |
| vtchmodaa64     | Bootlin `aarch64--uclibc--stable-2020.08-1` (gcc 9.3.0)          | Raspberry Pi 5        |
| vtchmodm64e     | `ventoy/musl-cross-make` release `output.tar.bz2` (gcc 7.3.0)    | qemu-user only        |

These are the toolchains listed in `DOC/BuildVentoyFromSource.txt`. The
only thing that matters for a hash match and is easy to get wrong:
Debian/Ubuntu ship `dietlibc 0.34~cvs20160606`, a later CVS snapshot whose
startup code differs. The fefe `dietlibc-0.34.tar.xz` release is required.

## Run it

```sh
sh BUSYBOX/chmod/ci/run-all.sh
```

or step by step:

```sh
sh ci/fetch.sh                      # downloads + verifies the 4 tarballs into ci/dl
docker build -t vtchmod-centos75 -f ci/Dockerfile.centos75 ci
docker run --rm -v "$PWD:/src:ro" -v "$PWD/ci/dl:/dl:ro" -v "$PWD/ci/out:/out" \
    vtchmod-centos75 bash /src/ci/build-x86.sh
sh ci/build-cross.sh                # aarch64 + mips64el, no container needed
sh ci/verify.sh                     # cmp against committed + the IMG/cpio_* copies, exit 1 on any mismatch
sh ci/test.sh                       # smoke tests (qemu-user-static for non-x86 if present)
```

`.github/workflows/build-vtchmod.yml` runs exactly this.
