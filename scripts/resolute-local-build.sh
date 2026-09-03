#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/.." && pwd -P)"
jobs="${JOBS:-$(nproc)}"

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ALLOW_UNSUPPORTED_HOST:-0}" != "1" ]] && {
    [[ "${ID:-}" != "ubuntu" ]] ||
    [[ "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}" != "resolute" ]];
}; then
    echo "error: this build is fixed to Ubuntu 26.04 (Resolute)" >&2
    exit 1
fi

JOBS="$jobs" "$script_dir/fetch-sources.sh"
JOBS="$jobs" "$script_dir/build-platform-tools.sh"
"$script_dir/assemble-platform-tools.sh"
"$script_dir/validate-platform-tools.sh"

echo "Build complete: $project_root/dist"
