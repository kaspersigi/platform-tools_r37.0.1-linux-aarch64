# Android SDK Platform-Tools for Linux AArch64

This project rebuilds the current Android SDK Platform-Tools package for a
GNU/Linux AArch64 host. The release archive contains the same paths as the
locally installed Google Linux x86_64 package at
`/mnt/develop/android/sdk/platform-tools`; only the host binaries and host
runtime architecture change.

## Version boundary

- Google binary package used as the layout and metadata reference: **37.0.1**
  (`37.0.1-15733141`).
- Newest public AOSP release source line: **37.0.0**, from
  `android17-release`.
- Output: `dist/platform-tools_r37.0.1-linux.zip`.

Google has not published a Linux AArch64 Platform-Tools binary package, and the
public AOSP branch does not yet contain the private 37.0.1 build identity.
Accordingly this is a community AArch64 reconstruction, not an official Google
37.0.1 binary. `sources.lock` records every source commit and keeps this
distinction explicit.

## Build on Ubuntu 26.04

```bash
./scripts/resolute-install-deps.sh
./scripts/resolute-local-build.sh
```

The dependency script enables Ubuntu's `arm64` multiarch repository, selects
Ubuntu Ports for that architecture, and installs the AArch64 development
libraries used by the cross build. The build
script downloads pinned sources and the checksum-pinned Google x86_64 package,
builds all eight executables, assembles the SDK directory, verifies the exact
entry inventory, checks every ELF machine, rejects unpackaged shared-library
dependencies, and runs smoke tests under QEMU when available.

Local builds use `nproc` parallel jobs by default. Set `JOBS` explicitly to
override that value. GitHub Actions uses four jobs to stay within the resource
limits of the free hosted runner.

The generated archive contains:

```text
platform-tools/
├── NOTICE.txt
├── adb
├── etc1tool
├── fastboot
├── hprof-conv
├── lib64/libc++.so
├── make_f2fs
├── make_f2fs_casefold
├── mke2fs
├── mke2fs.conf
├── package.xml
├── source.properties
└── sqlite3
```

ADB's optional Rust mDNS backend is currently disabled in the standalone
cross-build. USB ADB, direct TCP ADB, pairing commands, fastboot, filesystem
tools, ETC1 conversion, HPROF conversion, and SQLite are built. This limitation
is intentional and is not hidden behind a false official build number.

The packaged `lib64/libc++.so` is linked from Ubuntu 26.04's LLVM 22 AArch64
static runtime and includes its C++ ABI implementation. It has no dependency
on an unpackaged `libc++abi.so` or `libunwind.so`.

## Sources

The executable sources come from Android Open Source Project repositories. The
standalone CMake integration is pinned from `nmeum/android-tools`, whose
submodules point at the matching AOSP repositories. Google’s 37.0.1 Linux zip
is used only for `NOTICE.txt`, `mke2fs.conf`, `source.properties`, and the
reference path inventory; none of its x86_64 ELF files are copied into the
AArch64 result.

## CI and releases

`.github/workflows/release.yml` builds on `ubuntu-26.04`. Every run uploads the
zip and checksum as workflow artifacts. A pushed `v*` tag also creates a GitHub
release and uploads those files.
