#!/usr/bin/env bash
# build-stormlib.sh
#
# Builds StormLib, the open-source library for Blizzard's MPQ archives, from
# its source code at one pinned release, and puts the finished library where
# the project's Lua code can load it.
#
# In plain terms: MPQ is the container format Warcraft III and World of
# Warcraft keep their files in. The project's own reader handles map archives;
# StormLib handles every archive Blizzard ever made (patches, expansions,
# WoW's data). This script fetches StormLib's source at a fixed version,
# compiles it, and copies out the one file the project needs. The source
# folder is a throwaway: delete it and the script fetches it again. The only
# thing kept in git is the name of the pinned version, in libs/stormlib/PINNED.
#
# Usage:
#   build-stormlib.sh [DIR]                 build the pinned version (no-op if already built)
#   build-stormlib.sh [DIR] --update TAG    move the pin to TAG, then rebuild
#   build-stormlib.sh [DIR] --licences      list the licence files of StormLib and what it bundles
#   build-stormlib.sh --help
#
# DIR is the project root; it defaults to the path below.
#
# Issue: issues/112a-stormlib-build-and-update-script.md

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; then
    DIR="$1"
    shift
fi

REPO_URL="https://github.com/ladislav-zezula/StormLib"
LIB_DIR="${DIR}/libs/stormlib"
SOURCE_DIR="${LIB_DIR}/source"
BUILD_DIR="${LIB_DIR}/build"
OUT_DIR="${LIB_DIR}/lib"
PIN_FILE="${LIB_DIR}/PINNED"
STAMP_FILE="${OUT_DIR}/.built-from"

# {{{ usage
usage() {
    sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
}
# }}}

# {{{ read_pin
# The pinned tag lives in one committed file, so upgrading is a one-line,
# reviewable change. A missing pin file is an error, not a default.
read_pin() {
    if [ ! -f "${PIN_FILE}" ]; then
        echo "error: no pin file at ${PIN_FILE}; run with --update <tag> first" >&2
        exit 1
    fi
    tr -d '[:space:]' < "${PIN_FILE}"
}
# }}}

# {{{ fetch_source
# Clone once, then check out the pinned tag. A source tree left at another tag
# is moved to the pin; local edits in it are not expected (it is a build
# artefact) and git will refuse the checkout if any exist.
fetch_source() {
    local tag="$1"
    if [ ! -d "${SOURCE_DIR}/.git" ]; then
        mkdir -p "${LIB_DIR}"
        git clone --quiet "${REPO_URL}" "${SOURCE_DIR}"
    fi
    git -C "${SOURCE_DIR}" fetch --quiet --tags
    git -C "${SOURCE_DIR}" checkout --quiet "tags/${tag}"
}
# }}}

# {{{ build_library
# A shared library, so LuaJIT's FFI can load it. The bundled zlib and bzip2 are
# not forced: the system copies are used when present, and the licence listing
# says which were used.
build_library() {
    local tag="$1"
    cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DSTORM_BUILD_TESTS=OFF > "${BUILD_DIR}.configure.log" 2>&1 || {
        echo "error: cmake configure failed; see ${BUILD_DIR}.configure.log" >&2
        exit 1
    }
    cmake --build "${BUILD_DIR}" --parallel "$(nproc)" > "${BUILD_DIR}.build.log" 2>&1 || {
        echo "error: build failed; see ${BUILD_DIR}.build.log" >&2
        exit 1
    }
    mkdir -p "${OUT_DIR}"
    local built
    built="$(find "${BUILD_DIR}" -maxdepth 2 -name 'libstorm.so*' -type f | head -n 1)"
    if [ -z "${built}" ]; then
        echo "error: build finished but no libstorm.so was produced" >&2
        exit 1
    fi
    cp "${built}" "${OUT_DIR}/libstorm.so"
    echo "${tag}" > "${STAMP_FILE}"
    echo "built StormLib ${tag} -> ${OUT_DIR}/libstorm.so"
}
# }}}

# {{{ list_licences
list_licences() {
    if [ ! -d "${SOURCE_DIR}" ]; then
        echo "error: no source at ${SOURCE_DIR}; build first" >&2
        exit 1
    fi
    find "${SOURCE_DIR}" -maxdepth 3 -iname 'licen[cs]e*' -o -maxdepth 3 -iname 'copying*' | sort
}
# }}}

# {{{ main
main() {
    case "${1:-}" in
        --help|-h)
            usage
            ;;
        --licences|--licenses)
            list_licences
            ;;
        --update)
            if [ -z "${2:-}" ]; then
                echo "error: --update needs a tag, e.g. v9.40" >&2
                exit 1
            fi
            mkdir -p "${LIB_DIR}"
            echo "$2" > "${PIN_FILE}"
            fetch_source "$2"
            build_library "$2"
            ;;
        "")
            local tag
            tag="$(read_pin)"
            if [ -f "${STAMP_FILE}" ] && [ "$(cat "${STAMP_FILE}")" = "${tag}" ] && [ -f "${OUT_DIR}/libstorm.so" ]; then
                echo "StormLib ${tag} already built at ${OUT_DIR}/libstorm.so"
                exit 0
            fi
            fetch_source "${tag}"
            build_library "${tag}"
            ;;
        *)
            echo "error: unknown option $1 (try --help)" >&2
            exit 1
            ;;
    esac
}
# }}}

main "$@"
