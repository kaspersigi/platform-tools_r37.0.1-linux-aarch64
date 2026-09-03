#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/.." && pwd -P)"
candidate="${1:-$project_root/dist/platform-tools}"
reference="${REFERENCE_DIR:-/mnt/develop/android/sdk/platform-tools}"
official_reference="$project_root/sources/reference/platform-tools"

fail() {
    echo "error: $*" >&2
    exit 1
}

[[ -d "$candidate" ]] || fail "candidate directory is missing: $candidate"

expected_entries=(
    NOTICE.txt
    adb
    etc1tool
    fastboot
    hprof-conv
    lib64
    lib64/libc++.so
    make_f2fs
    make_f2fs_casefold
    mke2fs
    mke2fs.conf
    package.xml
    source.properties
    sqlite3
)

candidate_list="$(mktemp)"
reference_list="$(mktemp)"
trap 'rm -f -- "$candidate_list" "$reference_list"' EXIT
find "$candidate" -mindepth 1 -printf '%P\n' | LC_ALL=C sort > "$candidate_list"
printf '%s\n' "${expected_entries[@]}" | LC_ALL=C sort > "$reference_list"
diff -u "$reference_list" "$candidate_list" || fail "candidate entry list is not complete"

if [[ -d "$reference" ]]; then
    find "$reference" -mindepth 1 -printf '%P\n' | LC_ALL=C sort > "$reference_list"
    diff -u "$reference_list" "$candidate_list" || fail "candidate and local x86_64 reference entries differ"
fi

for name in NOTICE.txt mke2fs.conf source.properties; do
    cmp -s "$official_reference/$name" "$candidate/$name" || \
        fail "$name differs from the checksum-pinned Google reference"
done

for name in adb etc1tool fastboot hprof-conv make_f2fs make_f2fs_casefold mke2fs sqlite3 lib64/libc++.so; do
    [[ "$(stat -c '%a' "$candidate/$name")" == "755" ]] || fail "$name mode is not 0755"
done
for name in NOTICE.txt mke2fs.conf package.xml source.properties; do
    [[ "$(stat -c '%a' "$candidate/$name")" == "644" ]] || fail "$name mode is not 0644"
done
[[ "$(stat -c '%a' "$candidate/lib64")" == "755" ]] || fail "lib64 mode is not 0755"

executables=(adb etc1tool fastboot hprof-conv make_f2fs make_f2fs_casefold mke2fs sqlite3)
for name in "${executables[@]}"; do
    [[ -x "$candidate/$name" ]] || fail "$name is not executable"
    readelf -h "$candidate/$name" | grep -Eq 'Machine:.*AArch64' || fail "$name is not AArch64"

    while IFS= read -r dependency; do
        case "$dependency" in
            libc.so.6|libdl.so.2|libgcc_s.so.1|libm.so.6|libpthread.so.0|librt.so.1|ld-linux-aarch64.so.1) ;;
            *) fail "$name depends on unpackaged shared library $dependency" ;;
        esac
    done < <(readelf -d "$candidate/$name" | sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p')
done
readelf -h "$candidate/lib64/libc++.so" | grep -Eq 'Machine:.*AArch64' || fail "libc++.so is not AArch64"
while IFS= read -r dependency; do
    case "$dependency" in
        libc.so.6|libdl.so.2|libgcc_s.so.1|libm.so.6|libpthread.so.0|librt.so.1|ld-linux-aarch64.so.1) ;;
        *) fail "libc++.so depends on unpackaged shared library $dependency" ;;
    esac
done < <(readelf -d "$candidate/lib64/libc++.so" | sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p')
nm -D --defined-only "$candidate/lib64/libc++.so" | grep -q '_ZNSt3__1' || \
    fail "libc++.so exports no libc++ symbols"

grep -Fxq 'Pkg.Revision=37.0.1' "$candidate/source.properties" || fail "unexpected package revision"

if command -v qemu-aarch64 >/dev/null 2>&1; then
    qemu_root="${TARGET_ROOT:-}"
    if [[ -z "$qemu_root" ]]; then
        if [[ -e /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1 ]]; then
            qemu_root=/usr/aarch64-linux-gnu
        else
            qemu_root="$project_root/.cache/sysroot"
        fi
    fi
    qemu=(qemu-aarch64 -L "$qemu_root")
    "${qemu[@]}" "$candidate/adb" version
    "${qemu[@]}" "$candidate/fastboot" --version
    "${qemu[@]}" "$candidate/sqlite3" --version
    "${qemu[@]}" "$candidate/mke2fs" -V 2>&1 | head -n 2
    "${qemu[@]}" "$candidate/make_f2fs" -V
    "${qemu[@]}" "$candidate/make_f2fs_casefold" -V

    set +e
    etc1_help="$("${qemu[@]}" "$candidate/etc1tool" --help 2>&1)"
    etc1_status=$?
    hprof_help="$("${qemu[@]}" "$candidate/hprof-conv" 2>&1)"
    hprof_status=$?
    set -e
    [[ "$etc1_status" == "1" && "$etc1_help" == *"--encodeNoHeader"* ]] || \
        fail "etc1tool help smoke test failed"
    [[ "$hprof_status" == "2" && "$hprof_help" == *"infile outfile"* ]] || \
        fail "hprof-conv help smoke test failed"
fi

echo "Validated complete Platform-Tools 37.0.1 layout and AArch64 ELF architecture."
