#!/usr/bin/env bash
# D003-jsonc.sh — the JSON reader that lets mGBA's scripts keep data between runs.
#
# WHAT IT BUYS:  mGBA has a Lua scripting engine, and this machine already has LuaJIT,
#                so scripting is already compiled in. What is missing without this
#                library is the storage half of it: the part that lets a script save
#                a table and find it again next time the emulator starts.
# WHY WE CARE:   a link cable is two machines agreeing about timing, and the way you
#                learn what they agreed on is by recording it. A script that can write
#                what it saw to a file is the cheapest instrument available here.
# NEEDS:         nothing outside a C compiler.
# PINNED:        to a release tag, same reasoning as the others — the build should not
#                change underneath you because somebody pushed to a branch overnight.
#
# The directory it unpacks into is spelled without the hyphen, because these files are
# reached through shell function names and a hyphen cannot appear in one. The library
# upstream calls itself json-c; here it answers to jsonc.

JSONC_TAG="json-c-0.19-20260627"
JSONC_URL="https://github.com/json-c/json-c.git"

# {{{ dep_D003_jsonc_present()
dep_D003_jsonc_present() {
    pkg-config --exists json-c
}
# }}}

# {{{ dep_D003_jsonc_fetch()
dep_D003_jsonc_fetch() {
    local dir="${LIBS_SOURCE}/jsonc"
    if [[ ! -d "${dir}/.git" ]]; then
        git clone "${JSONC_URL}" "${dir}"
    fi
    git -C "${dir}" fetch --tags --quiet origin
    git -C "${dir}" reset --hard "${JSONC_TAG}" --quiet
}
# }}}

# {{{ dep_D003_jsonc_build()
# Warnings are demoted from errors here. json-c compiles clean against the compiler it
# was released with, and turns anything new that compiler learns to complain about
# into a failed build — a library refusing to compile over a warning about its own
# code is not a problem this project can fix, and not one worth stopping for.
dep_D003_jsonc_build() {
    local dir="${LIBS_SOURCE}/jsonc"
    cmake -S "${dir}" -B "${dir}/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX="${LIBS_PREFIX}" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_TESTING=OFF \
        -DDISABLE_WERROR=ON
    cmake --build "${dir}/build" --parallel
    cmake --install "${dir}/build"
}
# }}}
