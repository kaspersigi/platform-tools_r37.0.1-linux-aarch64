#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/.." && pwd -P)"
# shellcheck source=../sources.lock
source "$project_root/sources.lock"

build_dir="$project_root/build"
dist_dir="$project_root/dist"
package_dir="$dist_dir/platform-tools"
reference_dir="$project_root/sources/reference/platform-tools"

rm -rf -- "$package_dir"
mkdir -p "$package_dir/lib64"

install -m 0755 "$build_dir/android-tools/vendor/adb" "$package_dir/adb"
install -m 0755 "$build_dir/android-tools/vendor/fastboot" "$package_dir/fastboot"
install -m 0755 "$build_dir/android-tools/vendor/make_f2fs" "$package_dir/make_f2fs"
install -m 0755 "$build_dir/android-tools/vendor/make_f2fs_casefold" "$package_dir/make_f2fs_casefold"
install -m 0755 "$build_dir/android-tools/vendor/mke2fs.android" "$package_dir/mke2fs"
install -m 0755 "$build_dir/extra/etc1tool" "$package_dir/etc1tool"
install -m 0755 "$build_dir/extra/hprof-conv" "$package_dir/hprof-conv"
install -m 0755 "$build_dir/extra/sqlite3" "$package_dir/sqlite3"

install -m 0644 "$reference_dir/NOTICE.txt" "$package_dir/NOTICE.txt"
install -m 0644 "$reference_dir/mke2fs.conf" "$package_dir/mke2fs.conf"
install -m 0644 "$reference_dir/source.properties" "$package_dir/source.properties"

install -m 0755 "$build_dir/extra/libc++.so" "$package_dir/lib64/libc++.so"

sed \
    -e "s/@MAJOR@/${PLATFORM_TOOLS_PACKAGE_VERSION%%.*}/" \
    -e "s/@MINOR@/$(cut -d. -f2 <<< "$PLATFORM_TOOLS_PACKAGE_VERSION")/" \
    -e "s/@MICRO@/${PLATFORM_TOOLS_PACKAGE_VERSION##*.}/" \
    "$project_root/scripts/package.xml.in" > "$package_dir/package.xml"
chmod 0644 "$package_dir/package.xml"
chmod 0755 "$package_dir" "$package_dir/lib64"

archive="$dist_dir/platform-tools_r${PLATFORM_TOOLS_PACKAGE_VERSION}-linux.zip"
rm -f -- "$archive"
(
    cd "$dist_dir"
    export LC_ALL=C
    export TZ=UTC
    find platform-tools -exec touch -h -d '2008-01-01 00:00:00 UTC' {} +
    find platform-tools -print | sort | \
        zip -q -9 -X "$(basename -- "$archive")" -@
)

python3 -B "$project_root/scripts/check-zip-metadata.py" "$archive"

(
    cd "$dist_dir"
    sha256sum "$(basename -- "$archive")" > "$(basename -- "$archive").sha256"
)
echo "$archive"
