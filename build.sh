#!/usr/bin/env bash
set -euo pipefail

IOSEVKA_VERSION="19.0.1"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_BUILD_PLANS="$PROJECT_ROOT/private-build-plans.toml"
OUTPUT_DIR="$PROJECT_ROOT/dist"
BASE_OUTPUT_DIR="$OUTPUT_DIR/base"

log() {
    local cyan='\033[0;36m'
    local reset='\033[0m'
    printf "%b%s%b\n" "$cyan" "$1" "$reset"
}

logerr() {
    local red='\033[0;31m'
    local reset='\033[0m'
    printf "%b%s%b\n" 1>&2 "$red" "$1" "$reset"
}

check_dependencies() {
    available() { command -v "$1" &> /dev/null; }

    if ! available "zip"; then
        logerr "The 'zip' command is required but not available"
        exit 1
    fi

    if ! available "unzip"; then
        logerr "The 'unzip' command is required but not available"
        exit 1
    fi
}

prepare_build() {
    log "Cleaning up the output directory ($OUTPUT_DIR)"
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$BASE_OUTPUT_DIR"
}

# Build the font using the Docker image provided by https://github.com/avivace/iosevka-docker
build_font() {
    log "Building the base font"
    docker run \
        --rm \
        --tty \
        --interactive \
        --env FONT_VERSION="$IOSEVKA_VERSION" \
        --volume "$CUSTOM_BUILD_PLANS":/build/private-build-plans.toml \
        --volume "$BASE_OUTPUT_DIR":/build/dist \
        avivace/iosevka-build ttf::akoni
    echo ""
}

main() {
    check_dependencies
    prepare_build
    build_font
}

main "$@"
