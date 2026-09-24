#!/usr/bin/env bash
# build-dependencies.sh — compile the project's third-party libraries from source
#
# In plain terms: some jobs need libraries this project doesn't write itself
# (today, StormLib, which opens Blizzard's MPQ archives). This script walks
# through them one by one: fetch the source at a pinned version, compile it,
# and install the result inside the project, in deps/, so nothing is installed
# system-wide. Each library's licence notices are kept beside it in
# deps/licenses/<name>/ for the release review. Re-running skips anything
# already built at its pinned version.
#
# Usage:
#   scripts/build-dependencies.sh [DIR] [options]
#
#   DIR                      project root (default: the path below)
#   --only NAME              build just one dependency
#   --force                  rebuild even if already built
#   --list                   show each dependency, its pinned version, and whether it's built
#   --list-tags NAME         list the release tags upstream offers for NAME, newest last
#   --latest NAME            pin NAME to its newest release tag, then build it
#   --pin NAME TAG           pin NAME to TAG, then build it
#   --help
#
# Pins live in deps/versions (one "name tag" per line; tracked in git), so an
# upgrade is a one-line, reviewable change. Build folders live in .build-tmp/
# and are disposable.
#
# ---------------------------------------------------------------------------
# What this script does, top to bottom:
#
#   PHASE 1 — Toolchain
#     • Check that git, cmake, make and a C/C++ compiler exist.
#
#   PHASE 2 — Dependencies, in order
#     • stormlib — MPQ archive library (MIT). Built as a shared library,
#       linked against the system's zlib and bzip2, installed to
#       deps/stormlib/lib/libstorm.so. Used by src/mpq/stormlib.lua.
#
#   SUMMARY
#     • Print what was built, where, and which licence files were kept.
# ---------------------------------------------------------------------------
#
# Issue: issues/112a-stormlib-build-and-update-script.md

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ $# -ge 1 ] && [ "${1#-}" = "$1" ]; then
    DIR="$1"
    shift
fi

DEPS="${DIR}/deps"
BUILD="${DIR}/.build-tmp"
VERSIONS="${DEPS}/versions"

# Every dependency this script knows, in build order. Adding one means adding
# its name here and a build_<name> function below.
DEPENDENCIES=(stormlib)

# Where each dependency's source comes from.
declare -A REPO_URL=(
    [stormlib]="https://github.com/ladislav-zezula/StormLib"
)

FORCE=false
ONLY=""

# {{{ say
say() { printf '  %s\n' "$*"; }
err() { printf '  error: %s\n' "$*" >&2; }
# }}}

# {{{ usage
usage() {
    sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'
}
# }}}

# {{{ pinned_tag
# The tag pinned for a dependency. No pin is an error: a build must never
# silently fall back to "whatever upstream has today".
pinned_tag() {
    local name="$1"
    local tag
    tag="$(awk -v n="$name" '$1 == n { print $2 }' "${VERSIONS}" 2>/dev/null || true)"
    if [ -z "${tag}" ]; then
        err "no pinned version for ${name} in ${VERSIONS}; use --pin ${name} TAG or --latest ${name}"
        exit 1
    fi
    echo "${tag}"
}
# }}}

# {{{ set_pin
set_pin() {
    local name="$1"
    local tag="$2"
    mkdir -p "${DEPS}"
    touch "${VERSIONS}"
    local rest
    rest="$(awk -v n="$name" '$1 != n' "${VERSIONS}")"
    printf '%s\n%s %s\n' "${rest}" "${name}" "${tag}" | sed '/^$/d' | sort > "${VERSIONS}"
    say "pinned ${name} to ${tag}"
}
# }}}

# {{{ list_tags
# Release tags upstream offers, oldest first (version order), newest last.
list_tags() {
    local name="$1"
    git ls-remote --tags --refs "${REPO_URL[$name]}" \
        | sed 's#.*refs/tags/##' \
        | sort -V
}
# }}}

# {{{ latest_tag
latest_tag() {
    list_tags "$1" | tail -n 1
}
# }}}

# {{{ check_toolchain
check_toolchain() {
    local tool
    for tool in git cmake make cc c++; do
        if ! command -v "${tool}" > /dev/null; then
            err "missing tool: ${tool}"
            exit 1
        fi
    done
}
# }}}

# {{{ fetch_source
# A clone kept in .build-tmp/<name>/source, moved to the pinned tag. It is a
# build artefact: deleting it is always safe.
fetch_source() {
    local name="$1"
    local tag="$2"
    local src="${BUILD}/${name}/source"
    if [ ! -d "${src}/.git" ]; then
        mkdir -p "${BUILD}/${name}"
        git clone --quiet "${REPO_URL[$name]}" "${src}"
    fi
    git -C "${src}" fetch --quiet --tags
    git -C "${src}" checkout --quiet "tags/${tag}"
}
# }}}

# {{{ keep_licences
# Copy every licence/copying/notice file from the source tree into
# deps/licenses/<name>/, keeping relative paths, so bundled third-party code
# (StormLib carries libtomcrypt, for example) keeps its notices too.
keep_licences() {
    local name="$1"
    local src="${BUILD}/${name}/source"
    local dest="${DEPS}/licenses/${name}"
    rm -rf "${dest}"
    mkdir -p "${dest}"
    local file
    while IFS= read -r file; do
        local rel="${file#${src}/}"
        mkdir -p "${dest}/$(dirname "${rel}")"
        cp "${file}" "${dest}/${rel}"
    done < <(find "${src}" -path "${src}/.git" -prune -o -type f \
        \( -iname 'licen[cs]e*' -o -iname 'copying*' -o -iname 'notice*' \) -print)
    say "kept $(find "${dest}" -type f | wc -l) licence file(s) in deps/licenses/${name}/"
}
# }}}

# {{{ build_stormlib
# Shared library, so LuaJIT's FFI can load it. System zlib and bzip2 are used
# when found (the configure log says which); libtomcrypt is compiled in from
# StormLib's own source.
build_stormlib() {
    local tag="$1"
    local src="${BUILD}/stormlib/source"
    local obj="${BUILD}/stormlib/build"
    local out="${DEPS}/stormlib/lib"
    cmake -S "${src}" -B "${obj}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DSTORM_BUILD_TESTS=OFF > "${BUILD}/stormlib/configure.log" 2>&1 || {
        err "cmake configure failed; see ${BUILD}/stormlib/configure.log"
        exit 1
    }
    cmake --build "${obj}" --parallel "$(nproc)" > "${BUILD}/stormlib/build.log" 2>&1 || {
        err "build failed; see ${BUILD}/stormlib/build.log"
        exit 1
    }
    local built
    built="$(find "${obj}" -maxdepth 2 -name 'libstorm.so*' -type f | head -n 1)"
    if [ -z "${built}" ]; then
        err "build finished but produced no libstorm.so"
        exit 1
    fi
    mkdir -p "${out}"
    cp "${built}" "${out}/libstorm.so"
    say "installed deps/stormlib/lib/libstorm.so"
}
# }}}

# {{{ build_one
# Fetch, build, install and keep licences for one dependency, unless it is
# already built at its pinned tag (the stamp file says which tag was built).
build_one() {
    local name="$1"
    local tag
    tag="$(pinned_tag "${name}")"
    local stamp="${DEPS}/${name}/.built-from"
    if [ "${FORCE}" = false ] && [ -f "${stamp}" ] && [ "$(cat "${stamp}")" = "${tag}" ]; then
        say "${name} ${tag}: already built"
        return
    fi
    say "${name} ${tag}: building"
    fetch_source "${name}" "${tag}"
    "build_${name}" "${tag}"
    keep_licences "${name}"
    mkdir -p "${DEPS}/${name}"
    echo "${tag}" > "${stamp}"
}
# }}}

# {{{ list_dependencies
list_dependencies() {
    local name
    for name in "${DEPENDENCIES[@]}"; do
        local tag stamp state
        tag="$(awk -v n="$name" '$1 == n { print $2 }' "${VERSIONS}" 2>/dev/null || true)"
        stamp="${DEPS}/${name}/.built-from"
        if [ -f "${stamp}" ]; then state="built from $(cat "${stamp}")"; else state="not built"; fi
        printf '  %-10s pinned: %-8s %s\n' "${name}" "${tag:-none}" "${state}"
    done
}
# }}}

# {{{ require_known
require_known() {
    local name="$1"
    if [ -z "${REPO_URL[$name]:-}" ]; then
        err "unknown dependency: ${name} (known: ${DEPENDENCIES[*]})"
        exit 1
    fi
}
# }}}

# {{{ main
main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) usage; exit 0 ;;
            --force) FORCE=true ;;
            --only) require_known "${2:-}"; ONLY="$2"; shift ;;
            --list) list_dependencies; exit 0 ;;
            --list-tags) require_known "${2:-}"; list_tags "$2"; exit 0 ;;
            --latest)
                require_known "${2:-}"
                set_pin "$2" "$(latest_tag "$2")"
                ONLY="$2"
                FORCE=true
                shift
                ;;
            --pin)
                require_known "${2:-}"
                if [ -z "${3:-}" ]; then err "--pin needs NAME TAG"; exit 1; fi
                set_pin "$2" "$3"
                ONLY="$2"
                FORCE=true
                shift 2
                ;;
            *) err "unknown option $1 (try --help)"; exit 1 ;;
        esac
        shift
    done

    echo "PHASE 1 — Toolchain"
    check_toolchain
    say "git, cmake, make, cc, c++ found"

    echo "PHASE 2 — Dependencies"
    local name
    for name in "${DEPENDENCIES[@]}"; do
        if [ -n "${ONLY}" ] && [ "${name}" != "${ONLY}" ]; then
            continue
        fi
        build_one "${name}"
    done

    echo "SUMMARY"
    list_dependencies
}
# }}}

main "$@"
