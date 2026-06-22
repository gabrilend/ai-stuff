#!/bin/bash
# build-cuda.sh — Install or refresh the project's CUDA toolkit into libs/cuda/.
#
# DEFAULT: downloads CUDA 12.9 from NVIDIA and runs the runfile installer with
# --toolkitpath=libs/cuda so the toolkit lands directly in the project tree.
# No sudo needed, nothing touches /usr/local/. CUDA 12.9 was chosen because:
#   - it's the last 12.x release that supports Pascal (sm_61, GTX 1080 Ti),
#   - and officially supports gcc up to 14.x, matching modern rolling distros.
#   CUDA 13.0+ would solve gcc compatibility but dropped Pascal entirely.
#
# OPTIONAL: --from-ollama copies /mnt/mtwo/programs/ollama/local/cuda (CUDA 12.6)
# instead. Older and needs -allow-unsupported-compiler at build time, but
# avoids the 5 GB download if Ollama is already installed locally.
#
# All paths are idempotent — re-running is safe. The local CUDA version is
# detected via nvcc --version and the install is skipped if it already
# matches what we'd download.

set -euo pipefail

# {{{ usage()
usage() {
    cat <<'EOF'
build-cuda.sh — Install or refresh the project's CUDA toolkit.

USAGE:
  ./scripts/build-cuda.sh [OPTIONS] [DIR]

OPTIONS:
  --help, -h         Show this help.
  --force, -f        Remove libs/cuda/ before installing (clean re-install).
  --from-ollama      Use Ollama's bundled CUDA (12.6) instead of downloading
                     CUDA 12.9 from NVIDIA. Older but no download needed.

ARGUMENTS:
  DIR                Path to the project root.
                     Defaults to /home/ritz/programming/ai-stuff/words-pdf.

ENVIRONMENT:
  FORCE=1            Same as --force.
  KEEP_INSTALLER=1   Don't delete the downloaded runfile (default: keep).

BEHAVIOR:
  DEFAULT (downloading CUDA 12.9 from NVIDIA):
    1. If libs/cuda/ already contains CUDA 12.9, exit (nothing to do).
    2. Otherwise download cuda_12.9.0_575.51.03_linux.run (~5 GB) to
       ${DIR}/tmp/downloads/ if not already present.
    3. Run the runfile installer with --toolkitpath=${DIR}/libs/cuda
       (--toolkit, no driver, no sudo, nothing under /usr/local/).
    4. Print env-setup instructions.

  --from-ollama:
    Rsync /mnt/mtwo/programs/ollama/local/cuda/ → ${DIR}/libs/cuda/.
    Uses whatever CUDA version Ollama bundles (currently 12.6).
    No download needed.

REQUIREMENTS:
  - NVIDIA driver already installed (nvidia-smi must work)
  - rsync (only when using --from-ollama)
  - ~12 GB free disk (~5 GB runfile + ~7 GB libs/cuda)
EOF
}
# }}}

# {{{ arg parsing
FORCE="${FORCE:-0}"
FROM_OLLAMA=0
DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --force|-f)
            FORCE=1
            shift
            ;;
        --from-ollama)
            FROM_OLLAMA=1
            shift
            ;;
        --*)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
        *)
            if [ -z "${DIR}" ]; then
                DIR="$1"
            else
                echo "Unexpected extra argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done
DIR="${DIR:-/home/ritz/programming/ai-stuff/words-pdf}"
# }}}

# {{{ constants
OLLAMA_CUDA="/mnt/mtwo/programs/ollama/local/cuda"
LOCAL_CUDA="${DIR}/libs/cuda"

# CUDA 12.9 install constants (DEFAULT path)
CUDA_VERSION="12.9.0"
CUDA_DRIVER_MIN="575.51.03"
CUDA_INSTALLER_URL="https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_${CUDA_DRIVER_MIN}_linux.run"
DOWNLOAD_DIR="${DIR}/tmp/downloads"
INSTALLER_PATH="${DOWNLOAD_DIR}/cuda_${CUDA_VERSION}_linux.run"
# The runfile self-extracts (5.5 GB compressed → ~7-9 GB uncompressed) into
# its --tmpdir before running the actual installer. tmp/ is a symlink to
# /tmp (tmpfs, RAM-backed) which on a 16 GB tmpfs runs out of headroom
# once the .run file is already sitting there. So extraction goes to a
# disk-backed dir in the project root; we wipe it on success. NVIDIA's
# installer reports the tmpfs-full case as "Extraction failed / not enough
# space" even when the underlying disk has tens of GB free, which is
# misleading enough to be worth this comment.
EXTRACT_DIR="${DIR}/.cuda-install-tmp"
KEEP_INSTALLER="${KEEP_INSTALLER:-1}"

# Required version string (the digits we expect nvcc --version to report)
REQUIRED_VERSION_STRING="12.9"
# }}}

# {{{ require_rsync()
require_rsync() {
    if ! command -v rsync &>/dev/null; then
        echo "❌ rsync not found — required for syncing CUDA to libs/cuda." >&2
        echo "   On Void: sudo xbps-install rsync" >&2
        exit 1
    fi
}
# }}}

# {{{ get_nvcc_version()
# Returns nvcc's reported version (e.g. "12.6.77" or "12.9.41"), or empty
# if the path doesn't have a working nvcc.
get_nvcc_version() {
    local nvcc_path="$1"
    if [ ! -x "${nvcc_path}" ]; then
        echo ""
        return
    fi
    "${nvcc_path}" --version 2>/dev/null | grep -oP 'V\K[\d.]+' | head -1
}
# }}}

# {{{ check_driver_or_bail()
check_driver_or_bail() {
    if ! command -v nvidia-smi &>/dev/null; then
        echo "❌ nvidia-smi not found — no NVIDIA driver detected." >&2
        echo "   Install the NVIDIA driver before running this script." >&2
        exit 1
    fi
    local driver_ver
    driver_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    echo "📍 NVIDIA driver: ${driver_ver} (CUDA ${CUDA_VERSION} requires >= ${CUDA_DRIVER_MIN})"
}
# }}}

# {{{ force_clean()
force_clean() {
    if [ "${FORCE}" = "1" ] && [ -d "${LOCAL_CUDA}" ]; then
        echo "🗑️  FORCE: removing existing ${LOCAL_CUDA} for clean install"
        rm -rf "${LOCAL_CUDA}"
    fi
}
# }}}

# {{{ already_have_required_cuda()
# True if libs/cuda already has the required CUDA version.
already_have_required_cuda() {
    local local_ver
    local_ver=$(get_nvcc_version "${LOCAL_CUDA}/bin/nvcc")
    if [[ "${local_ver}" == ${REQUIRED_VERSION_STRING}* ]]; then
        echo "✨ libs/cuda already has CUDA ${local_ver} (matches required ${REQUIRED_VERSION_STRING}.x); nothing to do"
        echo "   Use --force to re-install."
        return 0
    fi
    return 1
}
# }}}

# {{{ sync_from_ollama()
# --from-ollama path: rsync Ollama's bundled CUDA into libs/cuda.
sync_from_ollama() {
    require_rsync
    if [ ! -d "${OLLAMA_CUDA}" ] || [ ! -x "${OLLAMA_CUDA}/bin/nvcc" ]; then
        echo "❌ --from-ollama requested but Ollama's bundled CUDA isn't at ${OLLAMA_CUDA}" >&2
        exit 1
    fi
    mkdir -p "${DIR}/libs"
    local ollama_ver
    ollama_ver=$(get_nvcc_version "${OLLAMA_CUDA}/bin/nvcc")
    echo "📦 Source: Ollama's bundled CUDA at ${OLLAMA_CUDA} (version ${ollama_ver})"
    echo "⚠️  Ollama bundles CUDA ${ollama_ver}, NOT ${REQUIRED_VERSION_STRING}.x."
    echo "   Build with this will need -allow-unsupported-compiler for gcc 14."
    [ -d "${LOCAL_CUDA}" ] || mkdir -p "${LOCAL_CUDA}"
    rsync -ah --delete --info=stats2 "${OLLAMA_CUDA}/" "${LOCAL_CUDA}/"
    echo "✅ Synced to ${LOCAL_CUDA}"
}
# }}}

# {{{ download_installer()
download_installer() {
    mkdir -p "${DOWNLOAD_DIR}"
    if [ -f "${INSTALLER_PATH}" ]; then
        local size_mb
        size_mb=$(du -m "${INSTALLER_PATH}" | cut -f1)
        echo "✨ Installer already at ${INSTALLER_PATH} (${size_mb} MB)"
        return
    fi
    echo "📦 Downloading CUDA ${CUDA_VERSION} installer (~5 GB)..."
    echo "   ${CUDA_INSTALLER_URL}"
    wget -O "${INSTALLER_PATH}" "${CUDA_INSTALLER_URL}"
}
# }}}

# {{{ install_runfile_to_local()
# Runs the runfile installer directly against libs/cuda/ via --toolkitpath.
# No sudo, nothing under /usr/local/. The flags chosen:
#   --silent              non-interactive (also accepts the EULA)
#   --toolkit             just the toolkit, no driver
#   --toolkitpath=PATH    where the toolkit lands (libs/cuda)
#   --defaultroot=PATH    where any symlinks/wrappers go (same place; keeps
#                         the installer from trying to write /usr/local/cuda)
#   --no-opengl-libs      we don't need them for compute work
#   --no-man-page         skip man pages (would try to write under /usr too)
#   --override            skip the "host gcc unsupported" hard-bail; we
#                         compensate for new gcc with -allow-unsupported-
#                         compiler at cmake time in build-llamacpp.sh
#   --tmpdir=PATH         where the installer extracts itself; pointed at
#                         a disk-backed .cuda-install-tmp/ in the project
#                         root (NOT tmp/, which is tmpfs and too small —
#                         see the EXTRACT_DIR comment above)
install_runfile_to_local() {
    mkdir -p "${LOCAL_CUDA}" "${EXTRACT_DIR}"
    # Always wipe the scratch dir — it can hold ~7-9 GB of extracted
    # installer payload that's useless once the toolkit is in libs/cuda/.
    # A trap covers success, failure, and Ctrl+C alike, so we never leak
    # the dir on a half-finished install. The trap is set just before the
    # installer runs (so a failure inside the trap itself doesn't fire
    # before EXTRACT_DIR even exists).
    trap 'echo "🗑️  Removing extraction scratch at ${EXTRACT_DIR}"; rm -rf "${EXTRACT_DIR}"' EXIT
    echo "🔧 Installing CUDA ${CUDA_VERSION} toolkit into ${LOCAL_CUDA} (no sudo)..."
    echo "   Extraction scratch: ${EXTRACT_DIR}"
    sh "${INSTALLER_PATH}" \
        --silent \
        --toolkit \
        --toolkitpath="${LOCAL_CUDA}" \
        --defaultroot="${LOCAL_CUDA}" \
        --no-opengl-libs \
        --no-man-page \
        --override \
        --tmpdir="${EXTRACT_DIR}"
    if [ ! -x "${LOCAL_CUDA}/bin/nvcc" ]; then
        echo "❌ Installer completed but nvcc not found at ${LOCAL_CUDA}/bin/nvcc" >&2
        echo "   Look for an installer log under ${LOCAL_CUDA}/ or ${EXTRACT_DIR}/." >&2
        exit 1
    fi
    echo "✅ CUDA ${CUDA_VERSION} installed to ${LOCAL_CUDA}"
    patch_math_header_for_glibc
    if [ "${KEEP_INSTALLER}" != "1" ]; then
        echo "🗑️  Removing installer at ${INSTALLER_PATH}"
        rm -f "${INSTALLER_PATH}"
    fi
}
# }}}

# {{{ patch_math_header_for_glibc()
# CUDA 12.9's crt/math_functions.h declares sinpi/cospi/sinpif/cospif WITHOUT
# the __THROW attribute that every other math function in the same file uses
# (sin, cos, sqrt, etc. all have it). Recent glibc (2.41+) declares those
# four functions with noexcept(true). nvcc's C++ frontend sees a no-throw-
# spec decl from CUDA followed by a noexcept(true) decl from glibc and
# reports "exception specification is incompatible".
#
# The fix is one character per line: add __THROW to match the rest of the
# file. We do it here, post-install, so a fresh libs/cuda/ never trips the
# next CUDA-using build. Idempotent: the sed skips lines that already have
# __THROW, so re-running this script is safe.
#
# When NVIDIA ships a fixed math_functions.h upstream this function becomes
# a no-op (the pattern just won't match any unpatched lines).
patch_math_header_for_glibc() {
    local math_header="${LOCAL_CUDA}/targets/x86_64-linux/include/crt/math_functions.h"
    if [ ! -f "${math_header}" ]; then
        echo "⚠️  Expected ${math_header} not found; skipping glibc-compat patch" >&2
        return
    fi
    echo "🩹 Patching ${math_header##*/} to add __THROW to sinpi/cospi/sinpif/cospif"
    sed -i -E \
        '/^extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ (double|float)[[:space:]]+(sinpi|cospi|sinpif|cospif)\(/ { /__THROW/!s/;[[:space:]]*$/ __THROW;/ }' \
        "${math_header}"
}
# }}}

# {{{ print_env_instructions()
print_env_instructions() {
    cat <<EOF
═══════════════════════════════════════════════════════════════════════
CUDA toolkit ready at ${LOCAL_CUDA}

For PERMANENT use, add these lines to ~/.bashrc (or your shell rc):
  export PATH="${LOCAL_CUDA}/bin:\$PATH"
  export LD_LIBRARY_PATH="${LOCAL_CUDA}/lib64:\$LD_LIBRARY_PATH"
Then \`source ~/.bashrc\` or open a new terminal, and verify with:
  nvcc --version

For a ONE-OFF llama.cpp build without touching your rc:
  CUDAToolkit_ROOT="${LOCAL_CUDA}" ./scripts/build-llamacpp.sh
═══════════════════════════════════════════════════════════════════════
EOF
}
# }}}

# {{{ main()
force_clean

if [ "${FROM_OLLAMA}" = "1" ]; then
    sync_from_ollama
    print_env_instructions
    exit 0
fi

if already_have_required_cuda; then
    print_env_instructions
    exit 0
fi

check_driver_or_bail
download_installer
install_runfile_to_local
print_env_instructions
# }}}
