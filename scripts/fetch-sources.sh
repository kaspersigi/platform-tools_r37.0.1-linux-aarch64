#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/.." && pwd -P)"
# shellcheck source=../sources.lock
source "$project_root/sources.lock"

sources_dir="$project_root/sources"
cache_dir="$project_root/.cache"
mkdir -p "$sources_dir" "$cache_dir"

clone_pinned() {
    local name="$1"
    local url="$2"
    local commit="$3"
    local destination="$sources_dir/$name"

    if [[ ! -d "$destination/.git" ]]; then
        echo "Cloning $name..."
        git clone --filter=blob:none --no-checkout "$url" "$destination"
        git -C "$destination" fetch --depth=1 origin "$commit"
        git -C "$destination" checkout --detach "$commit"
    fi

    local actual
    actual="$(git -C "$destination" rev-parse HEAD)"
    if [[ "$actual" != "$commit" ]]; then
        echo "error: $name is at $actual, expected $commit" >&2
        echo "       remove $destination and run this script again" >&2
        exit 1
    fi
}

clone_pinned android-tools "$ANDROID_TOOLS_URL" "$ANDROID_TOOLS_COMMIT"
clone_pinned development "$DEVELOPMENT_URL" "$DEVELOPMENT_COMMIT"
clone_pinned dalvik "$DALVIK_URL" "$DALVIK_COMMIT"
clone_pinned frameworks-native "$FRAMEWORKS_NATIVE_URL" "$FRAMEWORKS_NATIVE_COMMIT"
clone_pinned sqlite "$SQLITE_URL" "$SQLITE_COMMIT"

echo "Initializing pinned android-tools submodules..."
git -C "$sources_dir/android-tools" submodule update --init --depth=1

reference_archive="$cache_dir/platform-tools_r${PLATFORM_TOOLS_PACKAGE_VERSION}-linux.zip"
reference_checksum="$REFERENCE_SHA256  $reference_archive"
if [[ -f "$reference_archive" ]] &&
   ! printf '%s\n' "$reference_checksum" | sha256sum --check --status; then
    echo "Discarding cached reference archive with an invalid checksum."
    rm -f -- "$reference_archive"
fi

if [[ ! -f "$reference_archive" ]]; then
    echo "Downloading the Google Linux x86_64 reference package..."
    temporary_reference_archive="${reference_archive}.part"
    rm -f -- "$temporary_reference_archive"
    if ! curl --fail --location --retry 3 --retry-all-errors \
        --connect-timeout 30 --output "$temporary_reference_archive" \
        "$REFERENCE_URL"; then
        rm -f -- "$temporary_reference_archive"
        echo "error: failed to download the reference Platform-Tools archive" >&2
        exit 1
    fi
    if ! printf '%s  %s\n' "$REFERENCE_SHA256" "$temporary_reference_archive" |
        sha256sum --check --status; then
        rm -f -- "$temporary_reference_archive"
        echo "error: downloaded reference Platform-Tools archive checksum mismatch" >&2
        exit 1
    fi
    mv -- "$temporary_reference_archive" "$reference_archive"
fi
printf '%s\n' "$reference_checksum" | sha256sum --check --status || {
    echo "error: reference Platform-Tools archive checksum mismatch" >&2
    exit 1
}

reference_dir="$sources_dir/reference"
temporary_reference="$(mktemp -d "$sources_dir/.reference.XXXXXX")"
cleanup_reference() {
    rm -rf -- "$temporary_reference"
}
trap cleanup_reference EXIT
unzip -q "$reference_archive" -d "$temporary_reference"

expected_revision="Pkg.Revision=$PLATFORM_TOOLS_PACKAGE_VERSION"
grep -Fxq "$expected_revision" \
    "$temporary_reference/platform-tools/source.properties" || {
    echo "error: reference package does not report $expected_revision" >&2
    exit 1
}
rm -rf -- "$reference_dir"
mv -- "$temporary_reference" "$reference_dir"
temporary_reference=
trap - EXIT

echo "Pinned source trees and reference metadata are ready."
