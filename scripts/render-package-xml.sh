#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/.." && pwd -P)"
# shellcheck source=../sources.lock
source "$project_root/sources.lock"

if (( $# != 1 )); then
    echo "usage: $0 OUTPUT" >&2
    exit 2
fi
if [[ ! "$PLATFORM_TOOLS_PACKAGE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: invalid Platform-Tools package version: $PLATFORM_TOOLS_PACKAGE_VERSION" >&2
    exit 1
fi

IFS=. read -r major minor micro <<< "$PLATFORM_TOOLS_PACKAGE_VERSION"
sed \
    -e "s/@MAJOR@/$major/" \
    -e "s/@MINOR@/$minor/" \
    -e "s/@MICRO@/$micro/" \
    "$project_root/scripts/package.xml.in" > "$1"
