#!/usr/bin/env bash
# D001-libedit.sh — the line editor that turns mGBA's debugger into something usable.
#
# WHAT IT BUYS:  mGBA compiles its command line debugger only when it can find this.
#                Without it the debugger still exists over the network as a GDB stub,
#                but the interactive one — breakpoints, register dumps, memory reads
#                typed straight at the emulator — is left out of the build entirely.
# WHY WE CARE:   link cable work is mostly a question about what the serial registers
#                hold at a given instant, which is precisely what that debugger reads.
# NEEDS:         a curses library for terminal handling; this machine has ncursesw.
# DISTRIBUTED:   as a dated tarball, not a git repository, so the version is written
#                down here rather than fetched as a branch. Bump it deliberately.

LIBEDIT_VERSION="20260512-3.1"
LIBEDIT_URL="https://www.thrysoee.dk/editline/libedit-${LIBEDIT_VERSION}.tar.gz"

# {{{ dep_D001_libedit_present()
dep_D001_libedit_present() {
    pkg-config --exists libedit
}
# }}}

# {{{ dep_D001_libedit_fetch()
# The stamp file is what makes a second run cheap: the tarball is only downloaded and
# unpacked when the version written above is not the version already sitting there,
# so update can be run as often as you like without re-downloading anything.
dep_D001_libedit_fetch() {
    local dir="${LIBS_SOURCE}/libedit"
    local stamp="${dir}/.fetched-version"
    if [[ -f "${stamp}" && "$(cat "${stamp}")" == "${LIBEDIT_VERSION}" ]]; then
        echo "libs: libedit source is already at ${LIBEDIT_VERSION}"
        return 0
    fi
    local tarball="${LIBS_SOURCE}/libedit-${LIBEDIT_VERSION}.tar.gz"
    curl -fsSL -o "${tarball}" "${LIBEDIT_URL}"
    rm -rf "${dir}"
    mkdir -p "${dir}"
    # --strip-components=1 drops the libedit-<version> wrapper folder, so the source
    # always sits at the same path no matter which version was downloaded.
    tar -xzf "${tarball}" -C "${dir}" --strip-components=1
    rm -f "${tarball}"
    printf '%s\n' "${LIBEDIT_VERSION}" > "${stamp}"
}
# }}}

# {{{ dep_D001_libedit_build()
# Built out-of-tree in a build/ subdirectory, the same discipline the emulator itself
# gets: configure writes nothing into the unpacked source, so a failed build can be
# thrown away by deleting one directory rather than re-downloading the tarball.
#
# Shared rather than static, and that is a deliberate choice for every library here:
# a shared library records the libraries it needs inside itself, so the linker finds
# ncursesw through libedit without anyone having to name it. A static one would hand
# the emulator's link step a pile of undefined symbols and no clue where they live.
dep_D001_libedit_build() {
    local dir="${LIBS_SOURCE}/libedit"
    mkdir -p "${dir}/build"
    (
        cd "${dir}/build"
        ../configure --prefix="${LIBS_PREFIX}" --enable-shared --disable-static
        make -j"$(nproc)"
        make install
    )
}
# }}}
