#!/bin/bash
# build-llamacpp.sh — Clone, update, and compile llama.cpp into libs/llama.cpp/
#
# Idempotent: skips rebuild when upstream HEAD hasn't moved and the binary
# is newer than the latest commit. Refuses to update if the local repo has
# unstaged changes (caller must explicitly clean up). Detects broken
# half-clones (.git exists but HEAD is invalid) and bails with a clear
# instruction rather than silently corrupting state.

set -euo pipefail

# {{{ usage()
usage() {
    cat <<'EOF'
build-llamacpp.sh — Clone, update, and compile llama.cpp into libs/llama.cpp/

USAGE:
  ./scripts/build-llamacpp.sh [DIR]

ARGUMENTS:
  DIR                Path to the project root.
                     Defaults to /home/ritz/programming/ai-stuff/words-pdf.

ENVIRONMENT:
  CUDA=0             Build CPU-only (default: CUDA=1, build with CUDA).
  BUILD_JOBS=N       Cap cmake parallel jobs (default: 8, capped at $(nproc)).
                     8 is chosen so the CPU doesn't pin all cores at 100% and
                     cook itself in summer heat. Bump it on cooler days or
                     beefier rigs.

EXAMPLES:
  ./scripts/build-llamacpp.sh                       # default project, CUDA on
  ./scripts/build-llamacpp.sh /path/to/other/proj   # override project
  CUDA=0 ./scripts/build-llamacpp.sh                # CPU-only
  BUILD_JOBS=16 ./scripts/build-llamacpp.sh         # more cores, hotter

BEHAVIOR:
  - On first run, clones https://github.com/ggerganov/llama.cpp into
    DIR/libs/llama.cpp and builds the llama-server binary.
  - On subsequent runs, fetches upstream and compares local HEAD vs remote.
    If HEAD has moved, fast-forward pulls and rebuilds. If HEAD is current
    and the binary is newer than the latest commit, exits without rebuilding.
  - Bails (without modifying state) if:
      * The local repo has uncommitted modifications
      * The .git directory exists but lacks a valid HEAD reference (left
        over from an interrupted clone). Solution: remove the directory and
        re-run.
EOF
}
# }}}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

DIR="${1:-/home/ritz/programming/ai-stuff/words-pdf}"
LLAMACPP_DIR="${DIR}/libs/llama.cpp"
LLAMACPP_REPO="https://github.com/ggerganov/llama.cpp.git"
LLAMACPP_BIN="${LLAMACPP_DIR}/build/bin/llama-server"
CUDA="${CUDA:-1}"
# Default to 8 jobs to keep the CPU from running all cores at 100% — at peak
# parallelism the package compiles fast but the box overheats in summer.
# Capped at $(nproc) so we never request more workers than the machine has.
# Override with BUILD_JOBS=N when the weather (or thermals) allow.
BUILD_JOBS_DEFAULT=8
NPROC=$(nproc)
if [ "${BUILD_JOBS_DEFAULT}" -gt "${NPROC}" ]; then
    BUILD_JOBS_DEFAULT="${NPROC}"
fi
BUILD_JOBS="${BUILD_JOBS:-${BUILD_JOBS_DEFAULT}}"

# {{{ verify_repo_or_bail()
# Confirms that LLAMACPP_DIR is a healthy git repo with a valid HEAD.
# If .git exists but HEAD is broken (interrupted clone), bails with
# a clear "rm -rf this and re-run" message rather than silently breaking.
verify_repo_or_bail() {
    cd "${LLAMACPP_DIR}"
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ ${LLAMACPP_DIR}/.git exists but isn't a valid git repo." >&2
        echo "   Probably an interrupted clone. To fix:" >&2
        echo "     rm -rf ${LLAMACPP_DIR}" >&2
        echo "   Then re-run this script for a fresh clone." >&2
        exit 1
    fi
    if ! git rev-parse --verify HEAD > /dev/null 2>&1; then
        echo "❌ ${LLAMACPP_DIR} has no valid HEAD (interrupted clone or corruption)." >&2
        echo "   To fix:" >&2
        echo "     rm -rf ${LLAMACPP_DIR}" >&2
        echo "   Then re-run this script for a fresh clone." >&2
        exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "❌ ${LLAMACPP_DIR} has uncommitted local modifications." >&2
        echo "   Refusing to update. Either commit/stash them or remove the directory." >&2
        exit 1
    fi
}
# }}}

# {{{ clone_or_update()
# Returns 0 if no update happened (skip-rebuild candidate),
# returns 1 if source was updated (rebuild required).
clone_or_update() {
    if [ -d "${LLAMACPP_DIR}/.git" ]; then
        verify_repo_or_bail
        cd "${LLAMACPP_DIR}"
        local LOCAL_HEAD REMOTE_HEAD
        LOCAL_HEAD=$(git rev-parse HEAD)
        echo "📍 Local llama.cpp at ${LOCAL_HEAD}"
        echo "🔄 Fetching upstream..."
        git fetch origin master --quiet
        REMOTE_HEAD=$(git rev-parse origin/master)
        if [ "${LOCAL_HEAD}" = "${REMOTE_HEAD}" ]; then
            echo "✅ Already at latest upstream commit"
            return 0
        fi
        echo "⬇️  Updating ${LOCAL_HEAD} → ${REMOTE_HEAD}"
        git pull --ff-only origin master
        return 1
    fi
    if [ -e "${LLAMACPP_DIR}" ]; then
        echo "❌ ${LLAMACPP_DIR} exists but isn't a git checkout." >&2
        echo "   Remove it and re-run for a clean clone." >&2
        exit 1
    fi
    echo "📦 Cloning llama.cpp into ${LLAMACPP_DIR}..."
    mkdir -p "${DIR}/libs"
    git clone "${LLAMACPP_REPO}" "${LLAMACPP_DIR}"
    return 1
}
# }}}

# {{{ binary_is_current()
# True if the existing binary's mtime is newer than the latest commit time.
# False if missing or older than source.
binary_is_current() {
    if [ ! -x "${LLAMACPP_BIN}" ]; then
        return 1
    fi
    cd "${LLAMACPP_DIR}"
    local HEAD_TIME BIN_TIME
    HEAD_TIME=$(git log -1 --format=%ct HEAD)
    BIN_TIME=$(stat -c %Y "${LLAMACPP_BIN}")
    if [ "${BIN_TIME}" -ge "${HEAD_TIME}" ]; then
        return 0
    fi
    return 1
}
# }}}

# {{{ detect_cuda_arch()
# Asks nvidia-smi what the local GPU's compute capability is and returns it
# in sm_XX form (just the digits, e.g. "61" for the 1080 Ti's 6.1). Used to
# target cmake at exactly the architecture we'll run on, instead of relying
# on cmake's default arch list (which in CUDA 12.6 may or may not include
# Pascal sm_61 since Pascal is officially deprecated).
detect_cuda_arch() {
    if ! command -v nvidia-smi &>/dev/null; then
        echo ""
        return
    fi
    nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null \
        | head -1 | tr -d '. \n'
}
# }}}

# {{{ host_gcc_major()
# Returns the host gcc's major version number (e.g. "14" for gcc 14.2.1).
# Used to detect when the system gcc is newer than the CUDA toolkit's
# supported list — in which case we need -allow-unsupported-compiler.
host_gcc_major() {
    gcc -dumpfullversion 2>/dev/null | cut -d. -f1
}
# }}}

# Max gcc version officially supported by the installed CUDA toolkit.
# CUDA 12.6 (Ollama's bundle) supports gcc up to 13.
# CUDA 12.9 (the version build-cuda.sh installs by default) supports gcc up to 14.
# CUDA 13.x supports gcc up to 15 but drops Pascal sm_61 entirely.
# Hardcoded because dynamic detection adds complexity for marginal benefit;
# update this constant when bumping the toolkit version. If the host gcc is
# newer than this, we add -allow-unsupported-compiler to nvcc's flags as a
# best-effort workaround (often works for llama.cpp specifically, but the
# real fix is to install a matching CUDA version).
CUDA_MAX_SUPPORTED_GCC=14

# {{{ build_llamacpp()
build_llamacpp() {
    cd "${LLAMACPP_DIR}"
    mkdir -p build
    cd build
    local CMAKE_FLAGS=("-DLLAMA_CURL=OFF")
    if [ "${CUDA}" = "1" ]; then
        CMAKE_FLAGS+=("-DGGML_CUDA=ON")
        # Prefer the project-local CUDA at libs/cuda/ (installed by
        # scripts/build-cuda.sh). Pointing cmake at it via CUDAToolkit_ROOT
        # means we don't need the user's shell PATH/LD_LIBRARY_PATH already
        # configured — the build can succeed before they've sourced anything.
        # If neither libs/cuda nor an env override is present, cmake falls
        # back to its usual auto-detection (PATH, /usr/local/cuda*, etc.)
        local LOCAL_CUDA="${DIR}/libs/cuda"
        if [ -z "${CUDAToolkit_ROOT:-}" ] && [ -x "${LOCAL_CUDA}/bin/nvcc" ]; then
            echo "📍 Using project-local CUDA at ${LOCAL_CUDA}"
            CMAKE_FLAGS+=("-DCUDAToolkit_ROOT=${LOCAL_CUDA}")
            export PATH="${LOCAL_CUDA}/bin:${PATH}"
            export LD_LIBRARY_PATH="${LOCAL_CUDA}/lib64:${LD_LIBRARY_PATH:-}"
        elif [ -n "${CUDAToolkit_ROOT:-}" ]; then
            echo "📍 Using CUDAToolkit_ROOT=${CUDAToolkit_ROOT}"
            CMAKE_FLAGS+=("-DCUDAToolkit_ROOT=${CUDAToolkit_ROOT}")
        fi
        # Target the actual GPU's architecture explicitly. Avoids cmake's
        # default "compile for everything" which is slow, AND ensures Pascal
        # sm_61 gets included even though it's deprecated in CUDA 12.6+.
        # Override with CMAKE_CUDA_ARCHITECTURES=... env var if needed
        # (e.g. cross-compiling for a different target GPU).
        if [ -z "${CMAKE_CUDA_ARCHITECTURES:-}" ]; then
            local detected_arch
            detected_arch=$(detect_cuda_arch)
            if [ -n "${detected_arch}" ]; then
                echo "📍 Detected GPU compute capability: sm_${detected_arch}"
                CMAKE_FLAGS+=("-DCMAKE_CUDA_ARCHITECTURES=${detected_arch}")
            else
                echo "⚠️  Could not auto-detect GPU compute capability; letting cmake pick defaults"
            fi
        else
            echo "📍 Using CMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}"
            CMAKE_FLAGS+=("-DCMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}")
        fi
        # If host gcc is newer than CUDA's supported list, add the override
        # flag. CUDA 12.6's nvcc only knows about gcc <= 13; gcc 14+ on
        # rolling distros (Void, Arch) trips a hard #error in host_config.h
        # without -allow-unsupported-compiler. For llama.cpp's CUDA code
        # this combo is the documented community recipe, not a hack.
        # CUDA 13.0+ would solve this officially but dropped Pascal sm_61,
        # so we're locked into the 12.x line for as long as we want the
        # 1080 Ti to actually run the compiled binary.
        local gcc_major
        gcc_major=$(host_gcc_major)
        if [ -n "${gcc_major}" ] && [ "${gcc_major}" -gt "${CUDA_MAX_SUPPORTED_GCC}" ]; then
            echo "📍 Host gcc ${gcc_major} > CUDA's supported max (${CUDA_MAX_SUPPORTED_GCC}); adding -allow-unsupported-compiler"
            CMAKE_FLAGS+=("-DCMAKE_CUDA_FLAGS=-allow-unsupported-compiler")
        fi
        echo "🔨 Configuring with CUDA support..."
    else
        echo "🔨 Configuring CPU-only..."
    fi
    cmake .. "${CMAKE_FLAGS[@]}"
    echo "🔨 Building with ${BUILD_JOBS} parallel jobs (this takes a while on first build)..."
    cmake --build . --config Release -j "${BUILD_JOBS}"
}
# }}}

# {{{ main()
if clone_or_update; then
    if binary_is_current; then
        echo "✨ Binary present and current at ${LLAMACPP_BIN}, skipping build"
        exit 0
    fi
    echo "⚠️  Binary missing or older than source; rebuilding"
fi

build_llamacpp

if [ -x "${LLAMACPP_BIN}" ]; then
    echo "✅ Built: ${LLAMACPP_BIN}"
else
    echo "❌ Build completed but binary not found at expected path" >&2
    exit 1
fi
# }}}
