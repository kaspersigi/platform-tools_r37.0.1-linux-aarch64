#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

usage() {
    cat <<'EOF'
Install dependencies for the Linux AArch64 Platform-Tools cross build.

Usage:
  ./scripts/resolute-install-deps.sh

The supported host is Ubuntu 26.04 (Resolute) amd64. Set
ALLOW_UNSUPPORTED_HOST=1 only for intentional experiments.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi
(( $# == 0 )) || { usage >&2; exit 2; }

allow_unsupported_host="${ALLOW_UNSUPPORTED_HOST:-0}"
[[ "$allow_unsupported_host" == "0" || "$allow_unsupported_host" == "1" ]] || {
    echo "error: ALLOW_UNSUPPORTED_HOST must be 0 or 1" >&2
    exit 2
}

# shellcheck disable=SC1091
source /etc/os-release
if [[ "$allow_unsupported_host" != "1" ]] && {
    [[ "${ID:-}" != "ubuntu" ]] ||
    [[ "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}" != "resolute" ]] ||
    [[ "$(dpkg --print-architecture)" != "amd64" ]];
}; then
    echo "error: expected Ubuntu 26.04 (Resolute) amd64; detected ${PRETTY_NAME:-unknown} $(dpkg --print-architecture)" >&2
    exit 1
fi

if (( EUID == 0 )); then
    sudo_command=()
else
    command -v sudo >/dev/null 2>&1 || {
        echo "error: sudo is required" >&2
        exit 1
    }
    sudo_command=(sudo)
fi

host_packages=(
    binutils-aarch64-linux-gnu
    ca-certificates
    cmake
    curl
    file
    g++-aarch64-linux-gnu
    gcc-aarch64-linux-gnu
    git
    ninja-build
    pkg-config
    protobuf-compiler
    python3
    qemu-user-binfmt
    unzip
    zip
)

arm64_packages=(
    libc++-22-dev:arm64
    libc++abi-22-dev:arm64
    libbrotli-dev:arm64
    liblz4-dev:arm64
    libpcre2-dev:arm64
    libpng-dev:arm64
    libprotobuf-dev:arm64
    libzstd-dev:arm64
    zlib1g-dev:arm64
)

echo "Installing amd64 host build tools..."
"${sudo_command[@]}" apt-get update
"${sudo_command[@]}" apt-get install -y --no-install-recommends "${host_packages[@]}"

if ! dpkg --print-foreign-architectures | grep -Fxq arm64; then
    "${sudo_command[@]}" dpkg --add-architecture arm64
fi

# Ubuntu's amd64 archive does not carry arm64 packages. Use the official Ports
# archive for the foreign architecture without permanently rewriting the
# machine's existing apt sources.
ports_sources="$(mktemp)"
trap 'rm -f -- "$ports_sources"' EXIT
cat > "$ports_sources" <<'EOF'
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: resolute resolute-updates resolute-backports resolute-security
Components: main restricted universe multiverse
Architectures: arm64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

ports_options=(
    -o APT::Architectures=arm64
    -o "Dir::Etc::sourcelist=$ports_sources"
    -o Dir::Etc::sourceparts=-
)

echo "Installing arm64 cross-build libraries from Ubuntu Ports..."
"${sudo_command[@]}" apt-get update "${ports_options[@]}"
"${sudo_command[@]}" apt-get install -y --no-install-recommends \
    "${ports_options[@]}" "${arm64_packages[@]}"
trap - EXIT
rm -f -- "$ports_sources"
echo "Dependencies installed. Run ./scripts/resolute-local-build.sh next."
