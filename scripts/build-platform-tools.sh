#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/.." && pwd -P)"
sources_dir="$project_root/sources"
build_dir="$project_root/build"
jobs="${JOBS:-$(nproc)}"

[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || {
    echo "error: JOBS must be a positive integer" >&2
    exit 2
}

target_root="${TARGET_ROOT:-}"
if [[ -z "$target_root" ]]; then
    if [[ -f /usr/lib/aarch64-linux-gnu/libbrotlicommon.a ]]; then
        target_root=/
    elif [[ -f "$project_root/.cache/sysroot/usr/lib/aarch64-linux-gnu/libbrotlicommon.a" ]]; then
        target_root="$project_root/.cache/sysroot"
    else
        echo "error: arm64 development libraries are missing; run scripts/resolute-install-deps.sh" >&2
        exit 1
    fi
fi
target_libdir="$target_root/usr/lib/aarch64-linux-gnu"
if [[ "$target_root" == "/" ]]; then
    target_libdir=/usr/lib/aarch64-linux-gnu
fi

protoc="${PROTOC:-/usr/bin/protoc}"
if [[ ! -x "$protoc" && -x "$project_root/.cache/host-tools/usr/bin/protoc" ]]; then
    protoc="$project_root/.cache/host-tools/usr/bin/protoc"
fi
[[ -x "$protoc" ]] || {
    echo "error: host protoc is missing; run scripts/resolute-install-deps.sh" >&2
    exit 1
}

apply_once() {
    local repository="$1"
    local patch_file="$2"

    if git -C "$repository" apply --check "$patch_file" >/dev/null 2>&1; then
        git -C "$repository" apply "$patch_file"
    elif git -C "$repository" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
        :
    else
        echo "error: patch cannot be applied cleanly: $patch_file" >&2
        exit 1
    fi
}

android_tools="$sources_dir/android-tools"
[[ -f "$android_tools/CMakeLists.txt" ]] || {
    echo "error: sources are missing; run scripts/fetch-sources.sh first" >&2
    exit 1
}

# Apply the standalone build helper's compatibility patches without allowing
# CMake to mutate Git history with `git am` on every reconfiguration. A marker
# is needed because later patches in a series can touch the context needed to
# reverse-check an earlier patch.
patch_marker="$android_tools/.platform-tools-aarch64-patches-applied"
patch_fingerprint="$({
    sha256sum "$project_root/patches/android-tools-aarch64.patch" | cut -d' ' -f1
    find "$android_tools/patches" -mindepth 2 -maxdepth 2 -type f -name '*.patch' \
        -print0 | sort -z | xargs -0 sha256sum | cut -d' ' -f1
} | sha256sum | cut -d' ' -f1)"
if [[ ! -f "$patch_marker" ]]; then
    while IFS= read -r -d '' patch_file; do
        component="$(basename -- "$(dirname -- "$patch_file")")"
        apply_once "$android_tools/vendor/$component" "$patch_file"
    done < <(find "$android_tools/patches" -mindepth 2 -maxdepth 2 -type f -name '*.patch' -print0 | sort -z)
    apply_once "$android_tools" "$project_root/patches/android-tools-aarch64.patch"
    printf '%s\n' "$patch_fingerprint" > "$patch_marker"
elif [[ "$(cat "$patch_marker")" != "$patch_fingerprint" ]]; then
    echo "error: source patch set changed after it was applied" >&2
    echo "       remove $android_tools and run scripts/fetch-sources.sh again" >&2
    exit 1
fi

mkdir -p "$build_dir/android-tools" "$build_dir/extra"

common_c_flags="-O2 -g0 -ffunction-sections -fdata-sections"
gtest_headers="$android_tools/vendor/boringssl/third_party/googletest/googletest/include"
common_cxx_flags="$common_c_flags -I$gtest_headers -static-libstdc++ -static-libgcc"
common_link_flags="-Wl,--gc-sections -static-libstdc++ -static-libgcc"

cmake -S "$android_tools" -B "$build_dir/android-tools" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$project_root/cmake/aarch64-linux-gnu.cmake" \
    -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$project_root/cmake/static-zlib.cmake" \
    -DPT_TARGET_ROOT="$target_root" \
    -DProtobuf_PROTOC_EXECUTABLE="$protoc" \
    "-Dpkgcfg_lib_libbrotlicommon_brotlicommon:FILEPATH=$target_libdir/libbrotlicommon.a" \
    "-Dpkgcfg_lib_libbrotlidec_brotlidec:FILEPATH=$target_libdir/libbrotlidec.a" \
    "-Dpkgcfg_lib_libbrotlienc_brotlienc:FILEPATH=$target_libdir/libbrotlienc.a" \
    "-Dpkgcfg_lib_liblz4_lz4:FILEPATH=$target_libdir/liblz4.a" \
    "-Dpkgcfg_lib_liblz4_xxhash:FILEPATH=$target_libdir/libxxhash.a" \
    "-Dpkgcfg_lib_libpcre2-8_pcre2-8:FILEPATH=$target_libdir/libpcre2-8.a" \
    "-Dpkgcfg_lib_libzstd_zstd:FILEPATH=$target_libdir/libzstd.a" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS_RELEASE="$common_c_flags -DNDEBUG" \
    -DCMAKE_CXX_FLAGS_RELEASE="$common_cxx_flags -DNDEBUG" \
    -DCMAKE_EXE_LINKER_FLAGS="$common_link_flags" \
    -DANDROID_TOOLS_PATCH_VENDOR=OFF \
    -DANDROID_TOOLS_USE_BUNDLED_FMT=ON \
    -DANDROID_TOOLS_USE_BUNDLED_LIBUSB=ON \
    -DANDROID_TOOLS_LIBUSB_ENABLE_UDEV=OFF \
    -DANDROID_TOOLS_ADB_ENABLE_MDNS=OFF \
    -DProtobuf_USE_STATIC_LIBS=ON

cmake --build "$build_dir/android-tools" --parallel "$jobs" --target \
    adb fastboot make_f2fs make_f2fs_casefold mke2fs.android

echo "Building etc1tool..."
aarch64-linux-gnu-g++ \
    $common_cxx_flags \
    -I"$sources_dir/frameworks-native/opengl/include" \
    "$sources_dir/development/tools/etc1tool/etc1tool.cpp" \
    "$sources_dir/frameworks-native/opengl/libs/ETC1/etc1.cpp" \
    "$target_libdir/libpng.a" \
    "$target_libdir/libz.a" \
    -lm -pthread -ldl \
    -Wl,--gc-sections \
    -o "$build_dir/extra/etc1tool"

echo "Building hprof-conv..."
aarch64-linux-gnu-gcc \
    $common_c_flags -Wall -Werror -static-libgcc \
    "$sources_dir/dalvik/tools/hprof-conv/HprofConv.c" \
    -Wl,--gc-sections \
    -o "$build_dir/extra/hprof-conv"

echo "Building sqlite3 3.50.6..."
sqlite_dir="$sources_dir/sqlite/dist/sqlite-autoconf-3500600"
sqlite_flags=(
    -DNDEBUG=1
    -DNO_ANDROID_FUNCS=1
    -DHAVE_USLEEP=1
    -DHAVE_POSIX_FALLOCATE=1
    -DSQLITE_HAVE_ISNAN
    -DSQLITE_DEFAULT_JOURNAL_SIZE_LIMIT=1048576
    -DSQLITE_THREADSAFE=2
    -DSQLITE_TEMP_STORE=3
    -DSQLITE_POWERSAFE_OVERWRITE=1
    -DSQLITE_DEFAULT_FILE_FORMAT=4
    -DSQLITE_DEFAULT_AUTOVACUUM=1
    -DSQLITE_ENABLE_DBSTAT_VTAB
    -DSQLITE_ENABLE_MEMORY_MANAGEMENT=1
    -DSQLITE_ENABLE_FTS3
    -DSQLITE_ENABLE_FTS3_BACKWARDS
    -DSQLITE_ENABLE_FTS4
    -DSQLITE_OMIT_BUILTIN_TEST
    -DSQLITE_OMIT_COMPILEOPTION_DIAGS
    -DSQLITE_OMIT_LOAD_EXTENSION
    -DSQLITE_DEFAULT_FILE_PERMISSIONS=0600
    -DSQLITE_SECURE_DELETE
    -DSQLITE_ENABLE_BATCH_ATOMIC_WRITE
    -DSQLITE_DEFAULT_LEGACY_ALTER_TABLE
    -DSQLITE_ALLOW_ROWID_IN_VIEW
    -DSQLITE_ENABLE_BYTECODE_VTAB
)
aarch64-linux-gnu-gcc \
    $common_c_flags "${sqlite_flags[@]}" \
    "$sqlite_dir/shell.c" "$sqlite_dir/sqlite3.c" \
    -lm -pthread -ldl -Wl,--gc-sections \
    -o "$build_dir/extra/sqlite3"

libcxx_archive="$target_libdir/libc++.a"
[[ -f "$libcxx_archive" ]] || {
    echo "error: LLVM 22 arm64 libc++.a is missing; run scripts/resolute-install-deps.sh" >&2
    exit 1
}
echo "Building a self-contained LLVM libc++ runtime..."
aarch64-linux-gnu-g++ \
    -shared -Wl,-soname,libc++.so \
    -Wl,--whole-archive "$libcxx_archive" -Wl,--no-whole-archive \
    -static-libgcc -ldl -pthread -lm \
    -o "$build_dir/extra/libc++.so"

aarch64-linux-gnu-strip \
    "$build_dir/android-tools/vendor/adb" \
    "$build_dir/android-tools/vendor/fastboot" \
    "$build_dir/android-tools/vendor/make_f2fs" \
    "$build_dir/android-tools/vendor/make_f2fs_casefold" \
    "$build_dir/android-tools/vendor/mke2fs.android" \
    "$build_dir/extra/etc1tool" \
    "$build_dir/extra/hprof-conv" \
    "$build_dir/extra/libc++.so" \
    "$build_dir/extra/sqlite3"

echo "All eight Platform-Tools executables were built for AArch64."
