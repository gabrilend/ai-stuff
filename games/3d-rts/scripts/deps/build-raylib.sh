#!/usr/bin/env bash
# build-raylib.sh — Build the vendored raylib if (and only if) the
# already-built archive does not match the currently-installed source.
#
# What it does in plain words: checks a small marker file recording
# the version + content hash of the last successful build. If either
# the version or the hash differs from what is currently installed,
# raylib's own makefile is invoked to rebuild libraylib.a; otherwise
# the script exits cleanly without touching anything.

set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/3d-rts}"
shift || true

LIB_DIR="${DIR}/libs/raylib"
INSTALLED_VERSION_FILE="${LIB_DIR}/.installed-version"
INSTALLED_HASH_FILE="${LIB_DIR}/.installed-hash"
BUILD_STAMP_FILE="${LIB_DIR}/build-stamp"
ARCHIVE_FILE="${LIB_DIR}/src/libraylib.a"

if [[ ! -d "${LIB_DIR}" ]]; then
	echo "build-raylib: ${LIB_DIR} does not exist — run fetch-raylib.sh first." >&2
	exit 1
fi
if [[ ! -f "${INSTALLED_VERSION_FILE}" ]]; then
	echo "build-raylib: install marker missing — fetch did not complete." >&2
	exit 1
fi

# {{{ hash_sources()
# Stable SHA-256 of the source tree. Recomputed *here* (at build time)
# rather than read from a stored value so that manual edits to
# vendored source files between fetch and build also trigger a
# rebuild — the user's "validate that nothing has changed" goal.
hash_sources() {
	local target="$1"
	(cd "${target}" && find src -type f \( -name '*.c' -o -name '*.h' \) -print0 \
	   | LC_ALL=C sort -z \
	   | xargs -0 sha256sum \
	   | sha256sum \
	   | cut -d' ' -f1)
}
# }}}

INSTALLED_VERSION=$(cat "${INSTALLED_VERSION_FILE}")
CURRENT_HASH=$(hash_sources "${LIB_DIR}")
WANTED_STAMP="${INSTALLED_VERSION}:${CURRENT_HASH}"

# Note any drift from the fetch-time hash. Not fatal — the rebuild
# below picks up whatever is currently on disk. The note only exists
# so a developer reading the build output knows their checkout has
# diverged from upstream.
if [[ -f "${INSTALLED_HASH_FILE}" ]]; then
	FETCHED_HASH=$(cat "${INSTALLED_HASH_FILE}")
	if [[ "${FETCHED_HASH}" != "${CURRENT_HASH}" ]]; then
		echo "build-raylib: NOTE — source has drifted from fetch-time hash."
		echo "  fetched ${FETCHED_HASH}"
		echo "  current ${CURRENT_HASH}"
	fi
fi

CURRENT_STAMP=""
if [[ -f "${BUILD_STAMP_FILE}" && -f "${ARCHIVE_FILE}" ]]; then
	CURRENT_STAMP=$(cat "${BUILD_STAMP_FILE}")
fi

if [[ "${CURRENT_STAMP}" == "${WANTED_STAMP}" ]]; then
	echo "build-raylib: archive is current (${INSTALLED_VERSION}), skipping build."
	exit 0
fi

echo "build-raylib: stamp '${CURRENT_STAMP:-none}' != wanted '${WANTED_STAMP}' — rebuilding."

# raylib ships its own Makefile under src/. PLATFORM=PLATFORM_DESKTOP is
# the target for X11 + OpenGL on Linux; raylib's makefile understands
# it and produces libraylib.a in the same directory.
make -C "${LIB_DIR}/src" PLATFORM=PLATFORM_DESKTOP RAYLIB_LIBTYPE=STATIC

echo "${WANTED_STAMP}" > "${BUILD_STAMP_FILE}"

echo "build-raylib: built ${ARCHIVE_FILE}"
