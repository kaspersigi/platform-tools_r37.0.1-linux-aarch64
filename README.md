# Android SDK Platform-Tools for Linux AArch64

This project rebuilds Android SDK Platform-Tools 37.0.1 for a GNU/Linux
AArch64 host. The release archive contains the same paths as the
locally installed Google Linux x86_64 package at
`/mnt/develop/android/sdk/platform-tools`; only the host binaries and host
runtime architecture change.

## Version boundary

- Google binary package used as the layout and metadata reference: **37.0.1**
  (`37.0.1-15733141`).
- Public AOSP release source line used by this project: **37.0.0**, from
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
builds all eight executables, assembles the Platform-Tools directory, verifies
the exact entry inventory, checks every ELF machine, rejects unpackaged
shared-library dependencies, verifies and directly loads the component-local
libc++ runtime, and runs smoke tests under QEMU when required.

Project policy requires every local build and validation run to use all
processors reported by `nproc`. Do not set `JOBS=4` locally to imitate the
hosted workflow; both the unified and component build entries reject a
different local `JOBS` value.
`JOBS` is reserved for CI, and GitHub Actions explicitly sets `JOBS=4` to
stay within the resource limits of the free hosted runner.

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
on an unpackaged `libgcc_s.so.1`, `libc++abi.so`, or `libunwind.so`; validation
applies the same `libgcc_s.so.1` rejection to every packaged executable.

## Repository dependencies

This repository is an independently buildable producer of the Platform-Tools
archive. It does not depend on the Android SDK assembly repository.

- Its upstream inputs are the pinned public AOSP 37.0.0 source line and
  Google's checksum-pinned 37.0.1 Linux x86_64 archive. The Google archive is
  used only as the package-layout and metadata reference.
- Its release output, `platform-tools_r37.0.1-linux.zip`, is a downstream input
  of [`kaspersigi/android-sdk-linux-aarch64`](https://github.com/kaspersigi/android-sdk-linux-aarch64).
  The SDK installs it as `platform-tools/` without rebuilding these programs.
- The SDK resolves this repository's latest published full GitHub Release and
  verifies the ZIP against the `.sha256` asset from that same Release. Local
  builds and source commits without a published Release are not selected.
- Release tags such as `v1.0.0` identify revisions of this repository's build
  scripts. They do not change the locked Platform-Tools package/source boundary
  of 37.0.1/37.0.0.

After changing this project, publish and validate a new Platform-Tools Release
first. The next SDK build selects it automatically as the latest Release; no
SDK source change is needed unless the repository, asset name, or component
source version changes.

## Sources

The executable sources come from Android Open Source Project repositories. The
standalone CMake integration is pinned from `nmeum/android-tools`, whose
submodules point at the matching AOSP repositories. Google’s 37.0.1 Linux zip
is used only for `NOTICE.txt`, `mke2fs.conf`, `source.properties`, and the
reference path inventory; none of its x86_64 ELF files are copied into the
AArch64 result.

## CI and releases

`.github/workflows/release.yml` builds on `ubuntu-26.04`. Every run verifies
that the ZIP extracts to the exact assembled tree, then uploads the ZIP and
checksum as workflow artifacts. A pushed `v*` tag also creates a GitHub Release
and uploads those files.

## License

Repository-owned code is licensed under the Apache License 2.0; see
[`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). Upstream components retain their
original licenses and notices in their corresponding source and package paths.
