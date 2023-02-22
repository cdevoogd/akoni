#!/usr/bin/env bash
set -euo pipefail

FONT_VERSION=1.0.0
IOSEVKA_VERSION="19.0.1"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_BUILD_PLANS="$PROJECT_ROOT/private-build-plans.toml"
OUTPUT_DIR="$PROJECT_ROOT/generated"
BASE_OUTPUT_DIR="$OUTPUT_DIR/base"
PATCHED_OUTPUT_DIR="$OUTPUT_DIR/patched"
HINTED_TTF_DIR="$BASE_OUTPUT_DIR/akoni/ttf"

RELEASE_DIR="$PROJECT_ROOT/dist"
BASE_RELEASE_ZIP="$RELEASE_DIR/akoni-$FONT_VERSION.zip"
PATCH_RELEASE_ZIP="$RELEASE_DIR/akoni-nerd-font-$FONT_VERSION.zip"
PATCH_WINDOWS_RELEASE_ZIP="$RELEASE_DIR/akoni-nerd-font-windows-compatible-$FONT_VERSION.zip"

CONCURRENT_JOBS="$(nproc)"
BUILD_BASE_FONT="true"
PATCH_FONT="true"
CREATE_BASE_ARCHIVE="true"
CREATE_PATCH_ARCHIVE="true"

log() {
    local cyan='\033[0;36m'
    local reset='\033[0m'
    printf "%b%s%b\n" "$cyan" "$1" "$reset"
}

logerr() {
    local red='\033[0;31m'
    local reset='\033[0m'
    printf "%bERROR:%b %s\n" 1>&2 "$red" "$reset" "$1"
}

print_usage() {
    echo "USAGE:"
    echo "  $0 [OPTIONS]"
    echo
    echo "OPTIONS:"
    echo " -h, --help       Print out this help message and exit."
    echo " -j, --jobs num   Set the number of concurrent jobs used to build the base version of the"
    echo "                  font. By default, this will be the number of threads available on your"
    echo "                  CPU ($(nproc)) which will push it to its peak."
    echo " --base-only      Only generate the base version font."
    echo " --patch-only     Only generated the patched version of the font. The base version must"
    echo "                  have been generated previously."
    echo " --archive-only   Only regenerated the archive/release files. The base and patched"
    echo "                  versions of the font must have been generated previously."
}

handle_missing_arg() {
    echo "Missing argument: $1"
    print_usage
    exit 1
}

parse_arguments() {
    while [ $# -ne 0 ] && [ "$1" != "" ]; do
        case $1 in
        -h | --help)
            print_usage
            exit
            ;;
        -j | --jobs)
            shift
            if [[ $# -eq 0 ]]; then handle_missing_arg "job count"; fi
            if ! [[ $1 =~ ^[0-9]+$ ]]; then
                logerr "$1 is not a number"
                print_usage
                exit 1
            fi
            CONCURRENT_JOBS=$1
            ;;
        --base-only)
            PATCH_FONT="false"
            CREATE_PATCH_ARCHIVE="false"
            ;;
        --patch-only)
            BUILD_BASE_FONT="false"
            CREATE_BASE_ARCHIVE="false"
            ;;
        --archive-only)
            BUILD_BASE_FONT="false"
            PATCH_FONT="false"
            ;;
        *)
            print_usage
            exit 1
            ;;
        esac
        shift
    done
}

check_dependencies() {
    check_available() {
        if ! command -v "$1" &> /dev/null; then
            logerr "The '$1' command is required but not available"
            exit 1
        fi
    }

    if [[ "$CREATE_BASE_ARCHIVE" == "true" ]] || [[ "$CREATE_PATCH_ARCHIVE" == "true" ]]; then
        check_available "zip"
        check_available "unzip"
    fi
}

prepare_build() {
    if [[ "$BUILD_BASE_FONT" == "true" ]]; then
        log "Cleaning up the base output directory ($BASE_OUTPUT_DIR)"
        # The files created by the Docker image are owned by root
        sudo rm -rf "$BASE_OUTPUT_DIR"
        mkdir -p "$BASE_OUTPUT_DIR"
    fi

    if [[ "$PATCH_FONT" == "true" ]]; then
        log "Cleaning up the patch output directory ($PATCHED_OUTPUT_DIR)"
        rm -rf "$PATCHED_OUTPUT_DIR"
        mkdir -p "$PATCHED_OUTPUT_DIR"
    fi

    if [[ "$CREATE_BASE_ARCHIVE" == "true" ]]; then
        log "Cleaning up existing base font releases ($BASE_RELEASE_ZIP)"
        if [[ -f "$BASE_RELEASE_ZIP" ]]; then rm "$BASE_RELEASE_ZIP"; fi
    fi

    if [[ "$CREATE_PATCH_ARCHIVE" == "true" ]]; then
        log "Cleaning up existing patched font releases ($PATCH_RELEASE_ZIP)"
        if [[ -f "$PATCH_RELEASE_ZIP" ]]; then rm "$PATCH_RELEASE_ZIP"; fi
        log "Cleaning up existing patched font releases for Windows ($PATCH_WINDOWS_RELEASE_ZIP)"
        if [[ -f "$PATCH_WINDOWS_RELEASE_ZIP" ]]; then rm "$PATCH_WINDOWS_RELEASE_ZIP"; fi
    fi

    log "Ensuring the release directory exists ($RELEASE_DIR)"
    mkdir -p "$RELEASE_DIR"
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
        avivace/iosevka-build --jCmd="$CONCURRENT_JOBS" ttf::akoni
    echo ""
}

patch_font() {
    # https://github.com/ryanoasis/nerd-fonts#option-9-patch-your-own-font
    log "Patching..."
    docker run \
        --rm \
        --volume "$HINTED_TTF_DIR":/in \
        --volume "$PATCHED_OUTPUT_DIR":/out \
        nerdfonts/patcher --adjust-line-height --also-windows --careful --complete --makegroups
}

count_files() {
    local directory="$1"
    local files
    files=("$directory"/*)
    echo ${#files[@]}
}

check_patched_file_count() {
    local input_count
    local output_count
    input_count=$(count_files "$HINTED_TTF_DIR")
    output_count=$(count_files "$PATCHED_OUTPUT_DIR")
    expected_output_count=$(( 2 * input_count ))

    # Each input file should have a normal version and a windows compatible version
    if (( output_count != expected_output_count )); then
        logerr "Expected $expected_output_count patched files from $input_count input files but have $output_count"
        exit 1
    fi
}

get_files() {
    find "$1" -maxdepth 1
}

get_patched_files() {
    get_files "$PATCHED_OUTPUT_DIR"
}

to_zip() {
    # Junk paths places files at the root of the zip instead of copying the directory structure
    zip --junk-paths "$1" -@
}

create_base_font_release() {
    log "Creating zip archive for the base font: $BASE_RELEASE_ZIP"
    get_files "$HINTED_TTF_DIR" | to_zip "$BASE_RELEASE_ZIP"
}

create_patched_font_release() {
    # Find doesnt support lookarounds in regular expressions, so I'm using grep to filter for
    # the Windows files instead.
    log "Creating zip archive for the patched font: $PATCH_RELEASE_ZIP"
    get_patched_files | grep --invert-match 'Windows' | to_zip "$PATCH_RELEASE_ZIP"

    log "Creating zip archive for the Windows-compatible patched font ($PATCH_WINDOWS_RELEASE_ZIP)"
    get_patched_files | grep 'Windows' | to_zip "$PATCH_WINDOWS_RELEASE_ZIP"
}

main() {
    parse_arguments "$@"
    check_dependencies
    prepare_build

    if [[ "$BUILD_BASE_FONT" == "true" ]]; then
        build_font
    fi

    if [[ "$CREATE_BASE_ARCHIVE" == "true" ]]; then
        create_base_font_release
    fi

    if [[ "$PATCH_FONT" == "true" ]]; then
        # The font patcher docker image seems to return with an exit code of 1 no matter what (might
        # be a bug?). We are going to check if all the expected files are there and move on.
        patch_font || true
        check_patched_file_count
    fi

    if [[ "$CREATE_PATCH_ARCHIVE" == "true" ]]; then
        create_patched_font_release
    fi
}

main "$@"
