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
if [[ ! -f "$reference_archive" ]]; then
    echo "Downloading the Google Linux x86_64 reference package..."
    curl --fail --location --retry 3 --output "$reference_archive" "$REFERENCE_URL"
fi
printf '%s  %s\n' "$REFERENCE_SHA256" "$reference_archive" | sha256sum --check --status || {
    echo "error: reference Platform-Tools archive checksum mismatch" >&2
    exit 1
}

reference_dir="$sources_dir/reference"
if [[ ! -f "$reference_dir/platform-tools/source.properties" ]]; then
    mkdir -p "$reference_dir"
    unzip -q "$reference_archive" -d "$reference_dir"
fi

expected_revision="Pkg.Revision=$PLATFORM_TOOLS_PACKAGE_VERSION"
grep -Fxq "$expected_revision" "$reference_dir/platform-tools/source.properties" || {
    echo "error: reference package does not report $expected_revision" >&2
    exit 1
}

echo "Pinned source trees and reference metadata are ready."

