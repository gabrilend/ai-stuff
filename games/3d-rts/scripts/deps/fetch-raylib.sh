#!/usr/bin/env bash
# fetch-raylib.sh — Ensure the vendored raylib source is at the pinned
# version listed in libs/sources.
#
# What it does in plain words: looks up the version we *want* (from
# libs/sources), looks up the version we *have* (from
# libs/raylib/.installed-version), and reconciles the two by cloning
# or checking out the wanted tag. After a successful fetch, records
# a hash of the source tree so a later step can detect manual edits
# to vendored files.
#
# Can be invoked from any directory. Pass an alternate project root
# as the first argument to operate on a different copy.

set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/3d-rts}"
shift || true

LIB_NAME="raylib"
LIB_DIR="${DIR}/libs/${LIB_NAME}"
SOURCES_FILE="${DIR}/libs/sources"
INSTALLED_VERSION_FILE="${LIB_DIR}/.installed-version"
INSTALLED_HASH_FILE="${LIB_DIR}/.installed-hash"

# {{{ read_pinned_version()
# Pulls the wanted version + URL out of libs/sources for the named
# library. Tab/space separated; comments and blank lines skipped.
# Echoes "<version>\t<url>".
read_pinned_version() {
	local name="$1"
	awk -v target="${name}" '
		/^[[:space:]]*#/ { next }
		NF == 0          { next }
		$1 == target     { print $2 "\t" $4; exit }
	' "${SOURCES_FILE}"
}
# }}}

# {{{ hash_sources()
# Stable SHA-256 of the source tree. Sort by path so the result is
# independent of filesystem traversal order.
hash_sources() {
	local target="$1"
	(cd "${target}" && find src -type f \( -name '*.c' -o -name '*.h' \) -print0 \
	   | LC_ALL=C sort -z \
	   | xargs -0 sha256sum \
	   | sha256sum \
	   | cut -d' ' -f1)
}
# }}}

PINNED_INFO=$(read_pinned_version "${LIB_NAME}")
if [[ -z "${PINNED_INFO}" ]]; then
	echo "fetch-raylib: ${LIB_NAME} not listed in ${SOURCES_FILE}" >&2
	exit 1
fi
PINNED_VERSION=$(echo -e "${PINNED_INFO}" | cut -f1)
PINNED_URL=$(echo -e "${PINNED_INFO}" | cut -f2)

INSTALLED_VERSION=""
if [[ -f "${INSTALLED_VERSION_FILE}" ]]; then
	INSTALLED_VERSION=$(cat "${INSTALLED_VERSION_FILE}")
fi

if [[ "${INSTALLED_VERSION}" == "${PINNED_VERSION}" && -d "${LIB_DIR}/.git" ]]; then
	echo "fetch-raylib: already at ${PINNED_VERSION}, skipping fetch."
	exit 0
fi

echo "fetch-raylib: want ${PINNED_VERSION}, have '${INSTALLED_VERSION:-none}' — fetching."

if [[ ! -d "${LIB_DIR}/.git" ]]; then
	# First-time clone. --depth 1 because we never need history;
	# branch is the tag itself, which is what GitHub serves on
	# tag-named refs.
	rm -rf "${LIB_DIR}"
	git clone --depth 1 --branch "${PINNED_VERSION}" "${PINNED_URL}" "${LIB_DIR}"
else
	# Existing checkout — fetch the requested tag and check it out.
	# Refresh tags in case upstream rewrote them (rare, but cheap).
	git -C "${LIB_DIR}" fetch --depth 1 origin "tag" "${PINNED_VERSION}" --tags --force
	git -C "${LIB_DIR}" checkout --detach "tags/${PINNED_VERSION}"
fi

echo "${PINNED_VERSION}" > "${INSTALLED_VERSION_FILE}"

SRC_HASH=$(hash_sources "${LIB_DIR}")
echo "${SRC_HASH}" > "${INSTALLED_HASH_FILE}"

echo "fetch-raylib: installed ${PINNED_VERSION} (source hash ${SRC_HASH})"
