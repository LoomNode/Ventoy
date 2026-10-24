# Reproducible build for `xzminidec*`

`ventoy_makefile`, `ventoy_makefile64`, `ventoy_makefile64_musl`,
`ventoy_makefileaa64` and `ventoy_makefilem64e` build `xzminidec` from the
xz-embedded userspace. `DOC/BuildVentoyFromSource.txt` 4.15–4.18 gives the
commands. These scripts run those makefiles, unmodified, inside a container
with the toolchains the doc lists, then compare the output with the blobs in
`IMG/cpio_*/ventoy/busybox/`.

| binary           | toolchain                                                 | gated | smoke test |
|------------------|-----------------------------------------------------------|-------|------------|
| xzminidec32      | CentOS 7.5.1804, gcc 4.8.5-28, dietlibc 0.34, `-m32`      | no    | native     |
| xzminidec64      | same toolchain, dietlibc 0.34 (`/opt/diet64`)             | yes   | native     |
| xzminidec64_musl | same container, musl 1.2.1                                | yes   | native     |
| xzminidecaa64    | Bootlin `aarch64--uclibc--stable-2020.08-1` (gcc 9.3.0)   | yes   | qemu-user  |
| xzminidecm64e    | `ventoy/musl-cross-make` release (gcc 7.3.0)              | yes   | qemu-user  |

## Why the legacy source

The committed blobs were built from the xz-embedded source before commit
`32602a79a` (1.0.58, 2021-11-06). That commit added `(uint32_t)` casts to
`linux/lib/xz/xz_dec_lzma2.c`. The casts don't change behaviour on 32-bit,
but they change the 64-bit code. With the current source the four gated
binaries differ from the committed ones. `build.sh` therefore overlays that
one file with the version from `863eafd2c`, stored in `legacy/` and pinned
by SHA-256. Nothing else changes. Use `SOURCE=current` to build the
unmodified tree. That mode is not gated.

## Why the build path

dietlibc puts its build directory into the DWARF, and the GNU build-id
hashes the DWARF. The build-id is part of the file, so the output depends on
the path. `build.sh` copies the tree to `/home/share/Ventoy/xz-embedded-20130513`,
the directory `xzminidec64` was built in. It was the only path tried that
reproduces that blob.

## Why xzminidec32 is not gated

Nothing local reproduces the committed `xzminidec32`. Its code matches
across every layout and flag set tried, but the build-id never does. The
notes list about 7,200 real builds plus the oracle runs, with no match.
The build directory is probably a path the maintainer knows and nobody
else has. The CI still builds it, runs its smoke test and reports the
result. Asking the maintainer for the April 2020 32-bit build command
would settle it.

## Run it

```sh
sh Ventoy2Disk/Ventoy2Disk/xz-embedded-20130513/ci/run-all.sh
```

That runs `fetch.sh` (downloads and checks the tarballs into `ci/dl`),
`docker build`, `build.sh` in the container (writes `ci/out/`), `verify.sh`
(exit 1 if a gated binary differs), and `test.sh`. The workflow is
`.github/workflows/build-xzminidec.yml`.
