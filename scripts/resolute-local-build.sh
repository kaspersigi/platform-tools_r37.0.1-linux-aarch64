#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/.." && pwd -P)"
host_jobs="$(nproc)"
if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    jobs="${JOBS:-$host_jobs}"
else
    if [[ ${JOBS+x} == x && "$JOBS" != "$host_jobs" ]]; then
        echo "error: local builds must use all $host_jobs processors reported by nproc" >&2
        echo "       JOBS is reserved for GitHub Actions resource limits" >&2
        exit 2
    fi
    jobs="$host_jobs"
fi
build_dir="$project_root/build"
clean="${CLEAN:-0}"

[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || {
    echo "error: JOBS must be a positive integer" >&2
    exit 2
}
[[ "$clean" == "0" || "$clean" == "1" ]] || {
    echo "error: CLEAN must be 0 or 1" >&2
    exit 2
}

# shellcheck disable=SC1091
[[ -r /etc/os-release ]] || {
    echo "error: cannot identify the host because /etc/os-release is unavailable" >&2
    exit 1
}
source /etc/os-release
if [[ "${ALLOW_UNSUPPORTED_HOST:-0}" != "1" ]] && {
    [[ "${ID:-}" != "ubuntu" ]] ||
    [[ "${VERSION_ID:-}" != "26.04" ]] ||
    [[ "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}" != "resolute" ]];
}; then
    echo "error: this build is fixed to Ubuntu 26.04 (Resolute)" >&2
    exit 1
fi

python3 -B "$project_root/tests/source_state_test.py"

if [[ "$clean" == "1" ]]; then
    echo "Removing generated sources, build trees, and packages..."
    rm -rf -- "$project_root/sources" "$build_dir" "$project_root/dist"
fi

JOBS="$jobs" "$script_dir/fetch-sources.sh"
JOBS="$jobs" "$script_dir/build-platform-tools.sh"
"$script_dir/assemble-platform-tools.sh"
"$script_dir/validate-platform-tools.sh"

archive="$project_root/dist/platform-tools_r37.0.1-linux.zip"
checksum="$archive.sha256"
(cd "$project_root/dist" && sha256sum --check "$(basename -- "$checksum")")
unzip -tq "$archive"
archive_probe="$(mktemp -d "$build_dir/archive-validation.XXXXXX")"
cleanup_archive_probe() {
    rm -rf -- "$archive_probe"
}
trap cleanup_archive_probe EXIT
unzip -q "$archive" -d "$archive_probe"
mapfile -d '' -t archive_roots < <(
    find "$archive_probe" -mindepth 1 -maxdepth 1 -print0
)
if (( ${#archive_roots[@]} != 1 )) ||
   [[ "${archive_roots[0]}" != "$archive_probe/platform-tools" ]] ||
   [[ ! -d "$archive_probe/platform-tools" ]] ||
   [[ -L "$archive_probe/platform-tools" ]]; then
    echo "error: archive must contain exactly one top-level platform-tools/ directory" >&2
    exit 1
fi
PYTHONDONTWRITEBYTECODE=1 python3 "$script_dir/compare-extracted-tree.py" \
    "$project_root/dist/platform-tools" "$archive_probe/platform-tools"
cleanup_archive_probe
trap - EXIT

echo "Build complete: $project_root/dist"
