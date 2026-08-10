#!/usr/bin/env bash
# D002-libzip.sh — real zip archive support, in place of the cut-down copy mGBA carries.
#
# WHAT IT BUYS:  mGBA can open a ROM straight out of a .zip either way, but without
#                this it falls back to minizip, a small reader bundled in its own
#                source tree. libzip is the fuller implementation and is what upstream
#                prefers when it is available — writing archives, not only reading.
# WHY WE CARE:   less about the emulator and more about the fallback: the vendored
#                reader is upstream quietly working around a missing library, and a
#                fallback nobody notices is a difference between our build and a
#                distribution's that will eventually explain a bug the hard way.
# NEEDS:         zlib, which this machine already has.
# PINNED:        to a release tag rather than tracking the main branch, so two people
#                running install on different days compile the same library.

LIBZIP_TAG="v1.11.4"
LIBZIP_URL="https://github.com/nih-at/libzip.git"

# {{{ dep_D002_libzip_present()
dep_D002_libzip_present() {
    pkg-config --exists libzip
}
# }}}

# {{{ dep_D002_libzip_fetch()
# Clone once, then fetch and hard-reset onto the pinned tag. The reset is what makes
# this safe to run repeatedly — whatever state the tree was left in, it ends up at
# exactly the tag named above rather than merged with it.
dep_D002_libzip_fetch() {
    local dir="${LIBS_SOURCE}/libzip"
    if [[ ! -d "${dir}/.git" ]]; then
        git clone "${LIBZIP_URL}" "${dir}"
    fi
    git -C "${dir}" fetch --tags --quiet origin
    git -C "${dir}" reset --hard "${LIBZIP_TAG}" --quiet
}
# }}}

# {{{ dep_D002_libzip_build()
# Every optional cipher and compressor is switched off on purpose. libzip will happily
# link bzip2, lzma, zstd and three different TLS libraries if it finds them, and each
# one becomes something the emulator now needs at runtime for a feature nothing in a
# Game Boy Advance ROM will ever use. What is left is the zlib path, which is the one
# mGBA actually exercises. Tools, tests and examples are off for the same reason.
dep_D002_libzip_build() {
    local dir="${LIBS_SOURCE}/libzip"
    cmake -S "${dir}" -B "${dir}/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX="${LIBS_PREFIX}" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DBUILD_SHARED_LIBS=ON \
        -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF \
        -DENABLE_OPENSSL=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF \
        -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
    cmake --build "${dir}/build" --parallel
    cmake --install "${dir}/build"
}
# }}}
