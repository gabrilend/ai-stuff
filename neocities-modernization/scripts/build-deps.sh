#!/bin/bash
# scripts/build-deps.sh
# Downloads CUDA and llama.cpp source into the RAM-backed tmp/ tree, builds
# llama.cpp there, then installs the finished binaries + shared libraries
# into libs/ so the project owns a clean, disk-backed copy. Replaces the
# system-installed Ollama daemon as the embedding backend per issue 10-049.
#
# CUDA install: download CUDA 12.9 from NVIDIA (~5 GB) into tmp/downloads/
# and install via the runfile installer DIRECTLY into libs/cuda/ using
# --toolkitpath. No sudo required — nothing touches /usr/local or /var/log.
# CUDA 12.9 was chosen because it is the most recent toolkit that still
# supports Pascal (sm_61, the 1080 Ti) AND officially supports gcc up to
# 14.x — so no -allow-unsupported-compiler workaround is needed on
# rolling-distro hosts running gcc 14.
#
# CUDA 13.0+ would solve gcc compatibility officially but dropped Pascal
# entirely, so this project is pinned to the 12.x line for as long as it
# cares about the 1080 Ti. Ollama's bundled CUDA was tried as a download-
# free shortcut, but its bundled libs are built without Pascal in the arch
# list, so the binaries do not actually run on the 1080 Ti even though the
# toolkit metadata says they should. Removed in favor of the one path that
# is known to work end-to-end.
#
# llama.cpp source/build live in tmp/llamacpp-src/ (RAM-backed), and the
# install step copies only the finished bin/, lib/, and include/ into
# libs/llama.cpp/ via "cmake --install --prefix". This way disk holds the
# ~100 MB of artifacts that need to persist, and RAM absorbs the 1–3 GB of
# build churn.
#
# Usage:
#   ./scripts/build-deps.sh                  # Build into the default project DIR
#   ./scripts/build-deps.sh /custom/dir      # Build into a different project DIR
#   ./scripts/build-deps.sh --clean          # Wipe tmp source AND libs install
#   ./scripts/build-deps.sh --no-model       # Skip the GGUF model download
#   ./scripts/build-deps.sh --skip-cuda      # Trust whatever CUDA is already present
#   ./scripts/build-deps.sh --force-cuda     # Wipe libs/cuda/ before installing
#   ./scripts/build-deps.sh --help           # Show this message
#
# Environment:
#   BUILD_JOBS=N                             # Parallel cmake build jobs (default: 8)
#                                            # Lower this if the host CPU is overheating.
#
# What this gives you on success:
#   $DIR/libs/cuda/                  — the CUDA toolkit (nvcc, libcudart, etc.)
#   $DIR/libs/llama.cpp/bin/         — llama-server, llama-cli, llama-embedding
#   $DIR/libs/llama.cpp/lib/         — libllama.so, libggml*.so
#   $DIR/tmp/llamacpp-src/           — RAM-backed clone + build (ephemeral)
#   $DIR/assets/models/<model>.gguf  — the embedding model file
#   A smoke-tested working install ready for the 10-049 migration.

# {{{ Hard-coded project directory
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
# }}}

# {{{ Pinned versions
# llama.cpp pinned to a known-good tag rather than tracking master, so a
# future upstream change does not silently break the build. Bump this
# field after testing.
LLAMACPP_VERSION="b4404"

# Model to download. The basename matches what config.lua's local server
# entry's model_path expects; updating one without the other would mismatch.
# Q8_0 (8-bit) is the chosen quantization for Pascal-class GPUs (GTX 1080 Ti,
# sm_61): NVIDIA gutted FP16 throughput on consumer Pascals to ~1/64 of FP32,
# so an FP16 GGUF either runs in software-emulated FP16 (slow) or upcasts to
# FP32 (loses the size benefit). Q8_0 stores weights at 8-bit but the GPU
# compute path stays FP32, which Pascal handles at full rate. Quality loss
# vs FP16 is negligible for embedding tasks. Switch to Q4_K_M for smaller
# memory footprint or Q5_K_M for a balance, if VRAM ever gets tight.
MODEL_REPO="nomic-ai/nomic-embed-text-v1.5-GGUF"
MODEL_FILE="nomic-embed-text-v1.5.Q8_0.gguf"
MODEL_URL="https://huggingface.co/${MODEL_REPO}/resolve/main/${MODEL_FILE}"

# CUDA 12.9 install constants. 12.9 was chosen because it is the last 12.x
# release that supports Pascal (sm_61, the 1080 Ti) AND officially supports
# gcc up to 14.x. CUDA 13.0+ drops Pascal entirely. libs/cuda must contain a
# matching toolkit version or it gets reinstalled. The prefix is used
# string-wise: nvcc reporting "12.9.41" matches the "12.9" prefix.
REQUIRED_CUDA_PREFIX="12.9"
CUDA_VERSION="12.9.0"
CUDA_DRIVER_MIN="575.51.03"
CUDA_INSTALLER_URL="https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_${CUDA_DRIVER_MIN}_linux.run"

# Max host gcc that CUDA 12.9's nvcc accepts without -allow-unsupported-compiler.
# Hardcoded because dynamic detection adds complexity for marginal benefit;
# update when bumping the toolkit version. (CUDA 12.6 was here too, removed
# along with the Ollama path — see issue 10-049 for why.)
CUDA_12_9_MAX_GCC=14

# Cap on parallel build jobs for cmake --build. Defaults to 8 so the host
# CPU does not redline its thermal budget during summer; override with
# BUILD_JOBS=N before invoking the script if you have a colder machine and
# want maximum throughput (e.g. BUILD_JOBS=16 ./scripts/build-deps.sh).
BUILD_JOBS="${BUILD_JOBS:-8}"
# }}}

# {{{ Color codes for human-readable output
# $'...' is bash's ANSI-C quoting — it interprets \033 to the real ESC byte
# at definition time so both `echo -e` AND `cat <<EOF` heredocs render the
# escape correctly. The earlier "\033[92m" form was a literal 5-char string
# that echo -e expanded but heredocs printed verbatim, producing the visible
# "\033[92m" in print_env_summary's banner.
C_GREEN=$'\033[92m'
C_BLUE=$'\033[94m'
C_RED=$'\033[91m'
C_YELLOW=$'\033[93m'
C_RESET=$'\033[0m'
# }}}

# {{{ parse_arguments
parse_arguments() {
    CLEAN_BUILD=0
    SKIP_MODEL=0
    SKIP_CUDA=0
    FORCE_CUDA=0

    for arg in "$@"; do
        case "$arg" in
            --clean)
                CLEAN_BUILD=1
                ;;
            --no-model)
                SKIP_MODEL=1
                ;;
            --skip-cuda)
                # Trust whatever the operator already set up. Useful when
                # iterating on the llama.cpp build itself.
                SKIP_CUDA=1
                ;;
            --force-cuda)
                # Wipe libs/cuda before re-installing — useful when the
                # previous install is partial or the wrong version.
                FORCE_CUDA=1
                ;;
            --help|-h)
                sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
                exit 0
                ;;
            -*)
                echo -e "${C_RED}Unknown option: $arg${C_RESET}" >&2
                echo "Run with --help for usage." >&2
                exit 1
                ;;
            *)
                # First positional argument is the project directory.
                DIR="$arg"
                ;;
        esac
    done

    # Derived paths — must come after DIR is finalized.
    LOCAL_CUDA="${DIR}/libs/cuda"
    DOWNLOAD_DIR="${DIR}/tmp/downloads"
    CUDA_INSTALLER_PATH="${DOWNLOAD_DIR}/cuda_${CUDA_VERSION}_linux.run"
    # llama.cpp paths: clone + build live in RAM-backed tmp/, the cmake
    # install step copies the finished bin/lib/include into the disk-backed
    # libs/llama.cpp. Wiping tmp/ between runs is safe — we'll re-clone.
    LLAMACPP_SRC_DIR="${DIR}/tmp/llamacpp-src"
    LLAMACPP_INSTALL_DIR="${DIR}/libs/llama.cpp"
}
# }}}

# {{{ get_nvcc_version
# Returns the version string an nvcc binary reports (e.g. "12.6.77"), or
# empty if the path does not point to a working nvcc. Used both to validate
# the install we already have, and to decide which gcc-compat flags to set.
get_nvcc_version() {
    local nvcc_path="$1"
    if [ ! -x "$nvcc_path" ]; then
        echo ""
        return
    fi
    "$nvcc_path" --version 2>/dev/null | grep -oP 'V\K[\d.]+' | head -1
}
# }}}

# {{{ get_nvcc_major_minor
# Returns just the "12.6" or "12.9" prefix of an nvcc version string. Used to
# decide which max-gcc constant applies, since point releases (.77, .41, etc)
# never affect host-compiler support.
get_nvcc_major_minor() {
    local nvcc_path="$1"
    local full_ver
    full_ver=$(get_nvcc_version "$nvcc_path")
    if [ -z "$full_ver" ]; then
        echo ""
        return
    fi
    echo "$full_ver" | cut -d. -f1-2
}
# }}}

# {{{ detect_cuda_arch
# Asks nvidia-smi what the local GPU's compute capability is and returns it
# without the dot (e.g. "61" for the 1080 Ti's 6.1). We use this to target
# cmake at exactly the architecture we will actually run on, instead of
# relying on cmake's default arch list (which in CUDA 12.6+ may or may not
# include Pascal sm_61, since Pascal is officially deprecated).
detect_cuda_arch() {
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo ""
        return
    fi
    nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null \
        | head -1 | tr -d '. \n'
}
# }}}

# {{{ host_gcc_major
# Returns the host gcc's major version number (e.g. "14" for gcc 14.2.1).
host_gcc_major() {
    gcc -dumpfullversion 2>/dev/null | cut -d. -f1
}
# }}}

# {{{ check_requirements
# Verifies the build tools are available before we attempt anything serious.
# Unlike previous versions of this script, a missing nvcc is NOT fatal here —
# build_cuda() will install one. We only bail on truly required upstream
# tools (compilers, build system, downloader).
check_requirements() {
    echo -e "${C_BLUE}== Checking prerequisites ==${C_RESET}"
    local missing=0

    for tool in git cmake make curl gcc g++; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "  ${C_RED}MISSING${C_RESET}  $tool"
            missing=1
        else
            echo -e "  ${C_GREEN}found${C_RESET}    $tool ($(command -v "$tool"))"
        fi
    done

    # nvidia-smi (the driver) is required regardless of CUDA install path.
    # We can install the toolkit, but we cannot install the kernel driver
    # from a userspace script.
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo -e "  ${C_RED}MISSING${C_RESET}  nvidia-smi — NVIDIA driver not installed"
        echo -e "  ${C_YELLOW}HINT${C_RESET}     install the NVIDIA driver via your distro's mechanism"
        echo -e "  ${C_YELLOW}HINT${C_RESET}     CUDA toolkit needs driver >= ${CUDA_DRIVER_MIN}"
        missing=1
    else
        local driver_ver gpu_name compute_cap
        driver_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
        compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
        echo -e "  ${C_GREEN}found${C_RESET}    nvidia driver $driver_ver ($gpu_name, sm_$(echo "$compute_cap" | tr -d '.'))"
    fi

    local gcc_major
    gcc_major=$(host_gcc_major)
    echo -e "  ${C_GREEN}found${C_RESET}    gcc major version $gcc_major"

    # Don't bail on missing nvcc — build_cuda will install it. Just report.
    local local_nvcc="${LOCAL_CUDA}/bin/nvcc"
    if [ -x "$local_nvcc" ]; then
        local ver
        ver=$(get_nvcc_version "$local_nvcc")
        echo -e "  ${C_GREEN}found${C_RESET}    project nvcc $ver at libs/cuda/"
    elif command -v nvcc >/dev/null 2>&1; then
        local ver
        ver=$(nvcc --version | grep -oP 'release \K[0-9.]+' | head -n1)
        echo -e "  ${C_YELLOW}note${C_RESET}     system nvcc $ver on PATH (will install fresh into libs/cuda/)"
    else
        echo -e "  ${C_YELLOW}note${C_RESET}     no nvcc found — build_cuda will install one"
    fi

    if [ "$missing" -ne 0 ]; then
        echo -e "${C_RED}== Prerequisites missing — aborting ==${C_RESET}" >&2
        exit 1
    fi
}
# }}}

# {{{ ensure_directories
# Create the destination directories with mkdir -p. tmp/ is symlinked
# to a RAM-backed location for ephemeral working files (per the project's
# convention of keeping intermediate state out of the disk-backed tree).
ensure_directories() {
    mkdir -p "${DIR}/libs"
    mkdir -p "${DIR}/assets/models"
    "${DIR}/scripts/ensure-tmp-symlink" "${DIR}" 2>/dev/null || mkdir -p "${DIR}/tmp"
    mkdir -p "$DOWNLOAD_DIR"
}
# }}}

# {{{ already_have_libs_cuda
# True if libs/cuda already has a CUDA install matching REQUIRED_CUDA_PREFIX
# (e.g. "12.9"). A mismatched version triggers a reinstall, since the script
# now has exactly one supported toolkit version and a hybrid layout would
# silently break the build. Caller decides what to do with the answer.
already_have_libs_cuda() {
    local ver
    ver=$(get_nvcc_version "${LOCAL_CUDA}/bin/nvcc")
    if [ -z "$ver" ]; then
        return 1
    fi

    case "$ver" in
        ${REQUIRED_CUDA_PREFIX}*)
            echo -e "  ${C_GREEN}existing${C_RESET} libs/cuda has CUDA $ver (matches required ${REQUIRED_CUDA_PREFIX}.x)"
            return 0
            ;;
        *)
            # install_cuda_runfile wipes libs/cuda before writing the new
            # toolkit so we don't end up with a hybrid version layout.
            echo -e "  ${C_YELLOW}upgrade${C_RESET}  libs/cuda has CUDA $ver but ${REQUIRED_CUDA_PREFIX}.x is required — reinstalling"
            return 1
            ;;
    esac
}
# }}}

# {{{ force_clean_libs_cuda
# --force-cuda wipes libs/cuda before installing, in case the previous
# install is corrupt or the wrong version.
force_clean_libs_cuda() {
    if [ "$FORCE_CUDA" -eq 1 ] && [ -d "$LOCAL_CUDA" ]; then
        echo -e "${C_YELLOW}== --force-cuda: removing existing libs/cuda ==${C_RESET}"
        rm -rf "$LOCAL_CUDA"
    fi
}
# }}}

# {{{ download_cuda_installer
download_cuda_installer() {
    if [ -f "$CUDA_INSTALLER_PATH" ]; then
        local size_mb
        size_mb=$(du -m "$CUDA_INSTALLER_PATH" | cut -f1)
        echo -e "  ${C_GREEN}cached${C_RESET}   installer already at $CUDA_INSTALLER_PATH (${size_mb} MB)"
        return
    fi
    echo -e "${C_BLUE}== Downloading CUDA $CUDA_VERSION installer (~5 GB) ==${C_RESET}"
    echo -e "  url: $CUDA_INSTALLER_URL"
    curl -L --fail --progress-bar -o "$CUDA_INSTALLER_PATH" "$CUDA_INSTALLER_URL" || {
        echo -e "${C_RED}CUDA installer download failed.${C_RESET}" >&2
        rm -f "$CUDA_INSTALLER_PATH"
        exit 1
    }
}
# }}}

# {{{ install_cuda_runfile
# Runs the .run installer with --toolkit and --toolkitpath pointing at the
# project-local libs/cuda/. Because the install target is user-writable, no
# sudo is required — nothing lands in /usr/local. The CUDA 12.9 installer
# writes its internal log to a hardcoded /var/log/cuda-installer.log (which
# fails silently as non-root) and exposes NO flag to redirect it, so we
# instead capture the installer's stdout+stderr to a project-local log
# file via shell redirection. That covers most failure modes (bad flags,
# missing toolkit components, permission issues on the install path).
install_cuda_runfile() {
    # Clear the target so the install starts from an empty prefix.
    # Leftover files from a previous, different toolkit version would
    # otherwise coexist with the new install and produce a hybrid layout.
    rm -rf "$LOCAL_CUDA"
    mkdir -p "$LOCAL_CUDA"

    local log_file="${DIR}/tmp/cuda-installer-output.log"

    echo -e "${C_BLUE}== Installing CUDA $CUDA_VERSION toolkit into libs/cuda (no sudo) ==${C_RESET}"
    echo -e "  prefix:  $LOCAL_CUDA"
    echo -e "  log:     $log_file (installer stdout+stderr; --tmpdir keeps work in tmp/)"
    sh "$CUDA_INSTALLER_PATH" --silent --toolkit \
        --toolkitpath="$LOCAL_CUDA" \
        --no-opengl-libs \
        --no-man-page \
        --tmpdir="${DIR}/tmp" \
        > "$log_file" 2>&1 || {
        echo -e "${C_RED}CUDA installer failed.${C_RESET}" >&2
        echo -e "  ${C_YELLOW}HINT${C_RESET}  check $log_file for the installer's output" >&2
        exit 1
    }

    if [ ! -x "${LOCAL_CUDA}/bin/nvcc" ]; then
        echo -e "${C_RED}Installer completed but nvcc not at ${LOCAL_CUDA}/bin/nvcc${C_RESET}" >&2
        echo -e "  ${C_YELLOW}HINT${C_RESET}  check $log_file for what went wrong" >&2
        exit 1
    fi
    echo -e "${C_GREEN}CUDA $CUDA_VERSION installed at $LOCAL_CUDA${C_RESET}"

    patch_cuda_headers
}
# }}}

# {{{ patch_cuda_headers
# CUDA 12.9.0's math_functions.h declares sinpi/sinpif/cospi/cospif WITHOUT
# noexcept(true), while glibc 2.40+ declares the same functions WITH it via
# __MATHCALL_VEC. nvcc rejects the exception-specification mismatch, breaking
# every CUDA compilation on hosts with modern glibc. CUDA 12.9.1+ ships with
# the noexcept already in place; this function applies the same patch to the
# 12.9.0 headers so the user does not have to re-download to fix the build.
#
# The substitution is gated on /noexcept/! so re-running it is a no-op —
# already-patched lines do not get a second noexcept appended.
patch_cuda_headers() {
    local header="${LOCAL_CUDA}/targets/x86_64-linux/include/crt/math_functions.h"
    if [ ! -f "$header" ]; then
        echo -e "  ${C_YELLOW}WARN${C_RESET}     math_functions.h not at expected path — skipping noexcept patch"
        return
    fi

    sed -i -E '/noexcept/!{
        /^extern __DEVICE_FUNCTIONS_DECL__ __device_builtin__ .* (sinpi|cospi|sinpif|cospif)\(.*\);$/s/;$/ noexcept(true);/
    }' "$header"

    echo -e "  ${C_GREEN}patched${C_RESET}  math_functions.h: added noexcept(true) to sinpi/cospi/sinpif/cospif"
}
# }}}

# {{{ build_cuda
# Top-level CUDA install entry point. Resolves between three states:
#   - --skip-cuda set:           trust the operator, do nothing
#   - libs/cuda already correct: do nothing (version-prefix match)
#   - otherwise:                 download CUDA 12.9 from NVIDIA, install
#                                directly into libs/cuda/ with no sudo
build_cuda() {
    if [ "$SKIP_CUDA" -eq 1 ]; then
        echo -e "${C_YELLOW}== --skip-cuda set — trusting existing CUDA setup ==${C_RESET}"
        return
    fi

    force_clean_libs_cuda

    if already_have_libs_cuda; then
        return
    fi

    download_cuda_installer
    install_cuda_runfile

    # Final sanity check — the install path must have produced a working nvcc.
    if [ ! -x "${LOCAL_CUDA}/bin/nvcc" ]; then
        echo -e "${C_RED}CUDA install completed but libs/cuda/bin/nvcc is missing${C_RESET}" >&2
        exit 1
    fi
}
# }}}

# {{{ detect_old_llamacpp_layout
# Earlier versions of this script kept llama.cpp's source checkout at
# libs/llama.cpp/ (with .git inside). The new layout puts source in tmp/
# and installs the finished bin/lib into libs/llama.cpp/. If the operator
# is upgrading without --clean, bail BEFORE the CUDA install step so they
# do not eat a 5 GB download just to hit the layout error after. With
# --clean we simply continue — clone_llamacpp will wipe libs/llama.cpp
# as part of its clean handler.
detect_old_llamacpp_layout() {
    if [ ! -d "${LLAMACPP_INSTALL_DIR}/.git" ]; then
        return 0
    fi
    if [ "$CLEAN_BUILD" -eq 1 ]; then
        return 0
    fi
    echo -e "${C_YELLOW}== Detected old layout: libs/llama.cpp/ contains a git checkout ==${C_RESET}" >&2
    echo -e "  The new layout uses libs/llama.cpp/ as an install prefix (bin/, lib/," >&2
    echo -e "  include/), with the source tree living in tmp/llamacpp-src/. Either" >&2
    echo -e "  re-run with --clean to wipe the old checkout, or delete it manually:" >&2
    echo -e "    rm -rf ${LLAMACPP_INSTALL_DIR}" >&2
    exit 1
}
# }}}

# {{{ clone_llamacpp
# Clone llama.cpp at the pinned version into the RAM-backed tmp/ tree, or
# refresh if it already exists. The clone is intentionally NOT under libs/
# anymore — only finished artifacts live there. Pinning to a tag keeps the
# build reproducible across sessions; the -c advice.detachedHead=false
# silences git's cosmetic warning that tagged checkouts produce detached HEAD.
clone_llamacpp() {
    if [ "$CLEAN_BUILD" -eq 1 ]; then
        if [ -d "$LLAMACPP_SRC_DIR" ]; then
            echo -e "${C_BLUE}== --clean: removing tmp/llamacpp-src ==${C_RESET}"
            rm -rf "$LLAMACPP_SRC_DIR"
        fi
        if [ -d "$LLAMACPP_INSTALL_DIR" ]; then
            echo -e "${C_BLUE}== --clean: removing libs/llama.cpp install ==${C_RESET}"
            rm -rf "$LLAMACPP_INSTALL_DIR"
        fi
    fi

    if [ -d "${LLAMACPP_SRC_DIR}/.git" ]; then
        echo -e "${C_BLUE}== Updating llama.cpp checkout in tmp/ ==${C_RESET}"
        git -C "$LLAMACPP_SRC_DIR" fetch --tags --depth=1 origin "$LLAMACPP_VERSION" || {
            echo -e "${C_RED}Failed to fetch llama.cpp tag $LLAMACPP_VERSION${C_RESET}" >&2
            exit 1
        }
        git -c advice.detachedHead=false -C "$LLAMACPP_SRC_DIR" checkout "$LLAMACPP_VERSION" || {
            echo -e "${C_RED}Failed to checkout llama.cpp $LLAMACPP_VERSION${C_RESET}" >&2
            exit 1
        }
    else
        # If something exists at LLAMACPP_SRC_DIR but it isn't a git checkout
        # (interrupted clone, leftover dir), clear it so the clone has a
        # clean target. tmp/ is RAM-backed so wiping is cheap.
        if [ -e "$LLAMACPP_SRC_DIR" ]; then
            rm -rf "$LLAMACPP_SRC_DIR"
        fi
        mkdir -p "$(dirname "$LLAMACPP_SRC_DIR")"
        echo -e "${C_BLUE}== Cloning llama.cpp (tag $LLAMACPP_VERSION) into tmp/ ==${C_RESET}"
        git -c advice.detachedHead=false clone --depth=1 --branch "$LLAMACPP_VERSION" \
            https://github.com/ggml-org/llama.cpp.git "$LLAMACPP_SRC_DIR" || {
            echo -e "${C_RED}Clone failed. Check network and tag validity.${C_RESET}" >&2
            exit 1
        }
    fi

    echo -e "${C_GREEN}llama.cpp source ready at $LLAMACPP_SRC_DIR${C_RESET}"
}
# }}}

# {{{ build_llamacpp
# Configure and build llama.cpp with CUDA support. Build artifacts go to
# tmp/llamacpp-src/build/ (RAM-backed) — only the install step copies
# finished products into libs/. Three GPU-specific decisions happen here:
#   1. CUDAToolkit_ROOT points at libs/cuda/ so cmake never touches the
#      host PATH or LD_LIBRARY_PATH. The build is hermetic from CUDA's
#      perspective.
#   2. CMAKE_CUDA_ARCHITECTURES is set to the detected GPU's compute
#      capability (sm_61 for the 1080 Ti). This both speeds up the build
#      and guarantees Pascal stays in the compiled arch list — modern
#      CUDA defaults silently drop it.
#   3. If the host gcc is newer than CUDA 12.9's supported max (14), add
#      -allow-unsupported-compiler so nvcc skips its host-compiler gate.
#      Not needed for gcc 14 or older; meant as a forward-compat hedge
#      against rolling distros that may bump gcc to 15+ before we bump
#      CUDA (CUDA 13 is not an option as long as we want Pascal).
build_llamacpp() {
    local build_dir="${LLAMACPP_SRC_DIR}/build"

    # CMAKE_INSTALL_PREFIX is baked into the configure step so a later
    # `cmake --install` lays artifacts under libs/llama.cpp/. Re-running
    # without --clean keeps incremental compile state in the tmp/ build
    # tree, which is the fastest iteration loop.
    if [ "$CLEAN_BUILD" -eq 1 ] && [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi

    mkdir -p "$build_dir"
    cd "$build_dir"

    # LLAMA_BUILD_EXAMPLES MUST be ON: at tag b4404 the binaries we want
    # (llama-server, llama-cli, llama-embedding) all live under examples/.
    # The root CMakeLists.txt only descends into examples/ when this flag
    # is set, so turning it off silently produces a build with the shared
    # libs but no binaries. LLAMA_BUILD_SERVER is a sub-flag specifically
    # for examples/server, redundant when LLAMA_BUILD_EXAMPLES=ON but kept
    # explicit for self-documenting intent.
    local cmake_flags=(
        -DGGML_CUDA=ON
        -DGGML_NATIVE=ON
        -DLLAMA_BUILD_TESTS=OFF
        -DLLAMA_BUILD_EXAMPLES=ON
        -DLLAMA_BUILD_SERVER=ON
        -DLLAMA_CURL=OFF
        -DCMAKE_INSTALL_PREFIX="${LLAMACPP_INSTALL_DIR}"
        # Force lib/ over lib64/. cmake's GNUInstallDirs picks lib64/ on
        # Void/RHEL/SUSE conventions and lib/ on Debian/Arch — which means
        # our hardcoded RPATH "$ORIGIN/../lib" would resolve to the wrong
        # directory on lib64 distros and llama-server would fail to dlopen
        # libllama.so. Forcing lib/ unconditionally keeps the install
        # layout portable regardless of host distro.
        -DCMAKE_INSTALL_LIBDIR=lib
        # Set the binary RPATH so installed binaries find their .so
        # neighbors without needing LD_LIBRARY_PATH set at run time.
        -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    )

    # Point cmake at libs/cuda directly. This is the single source of
    # truth for "which CUDA does this build use".
    if [ -x "${LOCAL_CUDA}/bin/nvcc" ]; then
        echo -e "${C_BLUE}== Using project-local CUDA at $LOCAL_CUDA ==${C_RESET}"
        cmake_flags+=("-DCUDAToolkit_ROOT=${LOCAL_CUDA}")
        export PATH="${LOCAL_CUDA}/bin:${PATH}"
        export LD_LIBRARY_PATH="${LOCAL_CUDA}/lib64:${LD_LIBRARY_PATH:-}"
    else
        echo -e "${C_YELLOW}== No libs/cuda — cmake will auto-detect (system PATH, /usr/local/cuda*) ==${C_RESET}"
    fi

    # Target the detected GPU's compute capability explicitly. The
    # CMAKE_CUDA_ARCHITECTURES environment variable wins if the operator
    # set it (useful for cross-compiling to a different GPU).
    if [ -z "${CMAKE_CUDA_ARCHITECTURES:-}" ]; then
        local arch
        arch=$(detect_cuda_arch)
        if [ -n "$arch" ]; then
            echo -e "  ${C_GREEN}arch${C_RESET}     targeting sm_$arch (detected from nvidia-smi)"
            cmake_flags+=("-DCMAKE_CUDA_ARCHITECTURES=${arch}")
        else
            echo -e "  ${C_YELLOW}arch${C_RESET}     could not detect GPU — letting cmake pick defaults"
        fi
    else
        echo -e "  ${C_BLUE}arch${C_RESET}     using CMAKE_CUDA_ARCHITECTURES=$CMAKE_CUDA_ARCHITECTURES from env"
        cmake_flags+=("-DCMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}")
    fi

    # CUDA 12.9 officially supports gcc up to 14. If the host gcc is
    # newer, add -allow-unsupported-compiler so nvcc skips its host-
    # compiler gate. With the project pinned to CUDA 12.9, the only way
    # this fires is on a host that bumped to gcc 15+ since the script
    # was last tested. The fallback else covers --skip-cuda paths where
    # cuda_mm is empty or a version we don't have a max_gcc for.
    local cuda_mm gcc_major
    cuda_mm=$(get_nvcc_major_minor "${LOCAL_CUDA}/bin/nvcc")
    gcc_major=$(host_gcc_major)
    if [ "$cuda_mm" = "12.9" ] && [ -n "$gcc_major" ]; then
        if [ "$gcc_major" -gt "$CUDA_12_9_MAX_GCC" ]; then
            echo -e "  ${C_YELLOW}gcc${C_RESET}      host gcc $gcc_major > CUDA $cuda_mm max ($CUDA_12_9_MAX_GCC); adding -allow-unsupported-compiler"
            cmake_flags+=("-DCMAKE_CUDA_FLAGS=-allow-unsupported-compiler")
        else
            echo -e "  ${C_GREEN}gcc${C_RESET}      host gcc $gcc_major within CUDA $cuda_mm supported range (<= $CUDA_12_9_MAX_GCC)"
        fi
    fi

    echo -e "${C_BLUE}== Configuring llama.cpp ==${C_RESET}"
    cmake .. "${cmake_flags[@]}" || {
        echo -e "${C_RED}CMake configure failed.${C_RESET}" >&2
        echo -e "${C_YELLOW}Likely causes (given the script's current path):${C_RESET}" >&2
        echo -e "  - libs/cuda/ is incomplete (an interrupted install) — try --force-cuda" >&2
        echo -e "  - CMAKE_CUDA_ARCHITECTURES env override targets an arch this CUDA does not support" >&2
        echo -e "  - llama.cpp upstream renamed a CMake variable since tag $LLAMACPP_VERSION (we pin to that tag)" >&2
        echo -e "  - host gcc bumped past CUDA's max — update CUDA_12_*_MAX_GCC constants in this script" >&2
        exit 1
    }

    echo -e "${C_BLUE}== Building llama.cpp ==${C_RESET}"
    echo -e "  ${C_GREEN}jobs${C_RESET}     using $BUILD_JOBS parallel build jobs (override with BUILD_JOBS=N)"
    cmake --build . --config Release -j "$BUILD_JOBS" || {
        echo -e "${C_RED}Build failed.${C_RESET}" >&2
        exit 1
    }

    # Verify the binaries we care about actually got built (still in the
    # tmp/ build tree at this point — install_llamacpp copies them out).
    local missing=0
    for bin in llama-server llama-cli llama-embedding; do
        if [ ! -x "$build_dir/bin/$bin" ]; then
            echo -e "  ${C_RED}MISSING${C_RESET}  $bin"
            missing=1
        else
            echo -e "  ${C_GREEN}built${C_RESET}    $bin"
        fi
    done

    if [ "$missing" -ne 0 ]; then
        echo -e "${C_RED}Some binaries are missing. The CMake build flags may have skipped them.${C_RESET}" >&2
        echo -e "  ${C_YELLOW}HINT${C_RESET}  at this llama.cpp tag, llama-server / llama-cli / llama-embedding" >&2
        echo -e "  ${C_YELLOW}     ${C_RESET}  live under examples/, so LLAMA_BUILD_EXAMPLES=ON is required." >&2
        echo -e "  ${C_YELLOW}     ${C_RESET}  Upstream may have moved them to tools/ in a newer tag." >&2
        exit 1
    fi

    echo -e "${C_GREEN}llama.cpp built successfully in tmp/${C_RESET}"
}
# }}}

# {{{ install_llamacpp
# Copy finished binaries + shared libraries + headers from the RAM-backed
# tmp/ build tree into the disk-backed libs/llama.cpp/ install prefix via
# `cmake --install`. This is the step where artifacts "move from RAM to
# disk" — the tmp/ source and build trees can be wiped after this without
# affecting the project's ability to run llama-server.
install_llamacpp() {
    local build_dir="${LLAMACPP_SRC_DIR}/build"

    echo -e "${C_BLUE}== Installing llama.cpp artifacts to $LLAMACPP_INSTALL_DIR ==${C_RESET}"
    cmake --install "$build_dir" --config Release || {
        echo -e "${C_RED}cmake --install failed.${C_RESET}" >&2
        exit 1
    }

    # Confirm the install actually produced the binaries we expect at the
    # final on-disk location. Catches the case where llama.cpp's install
    # rules changed shape between versions and our flags aren't matching.
    local missing=0
    for bin in llama-server llama-cli llama-embedding; do
        if [ ! -x "${LLAMACPP_INSTALL_DIR}/bin/$bin" ]; then
            echo -e "  ${C_RED}MISSING${C_RESET}  ${LLAMACPP_INSTALL_DIR}/bin/$bin"
            missing=1
        else
            echo -e "  ${C_GREEN}installed${C_RESET} bin/$bin"
        fi
    done

    if [ "$missing" -ne 0 ]; then
        echo -e "${C_RED}cmake --install completed but expected binaries are missing.${C_RESET}" >&2
        exit 1
    fi

    echo -e "${C_GREEN}llama.cpp installed at $LLAMACPP_INSTALL_DIR${C_RESET}"
}
# }}}

# {{{ download_model
# Pull the configured GGUF model file from HuggingFace if it is not
# already present. The download is around 280 MB at f16 precision and
# typically takes ~30 seconds on a residential connection. Skip with
# --no-model when iterating on the build itself.
download_model() {
    if [ "$SKIP_MODEL" -eq 1 ]; then
        echo -e "${C_YELLOW}== Skipping model download (--no-model) ==${C_RESET}"
        return
    fi

    local model_path="${DIR}/assets/models/${MODEL_FILE}"

    if [ -f "$model_path" ]; then
        local size
        size=$(stat -c '%s' "$model_path")
        if [ "$size" -gt 100000000 ]; then
            echo -e "${C_GREEN}Model already present: $model_path ($((size / 1024 / 1024)) MB)${C_RESET}"
            return
        fi
        echo -e "${C_YELLOW}Existing model file is suspiciously small ($size bytes); re-downloading.${C_RESET}"
        rm -f "$model_path"
    fi

    echo -e "${C_BLUE}== Downloading $MODEL_FILE from HuggingFace ==${C_RESET}"
    echo -e "  URL: $MODEL_URL"
    curl -L --fail --progress-bar -o "$model_path" "$MODEL_URL" || {
        echo -e "${C_RED}Download failed.${C_RESET}" >&2
        rm -f "$model_path"
        exit 1
    }

    echo -e "${C_GREEN}Model saved to $model_path${C_RESET}"
}
# }}}

# {{{ smoke_test
# Launch the server briefly, ping it for one embedding, kill it. This
# catches obvious "the build linked but does not actually run" failures
# before the operator wires the pipeline against it.
smoke_test() {
    if [ "$SKIP_MODEL" -eq 1 ]; then
        echo -e "${C_YELLOW}== Skipping smoke test (model not downloaded) ==${C_RESET}"
        return
    fi

    local server_bin="${LLAMACPP_INSTALL_DIR}/bin/llama-server"
    local model_path="${DIR}/assets/models/${MODEL_FILE}"
    local port=18080  # Non-default to avoid collision with any running server
    local log="${DIR}/tmp/llamacpp-smoketest.log"

    # The server binary needs CUDA runtime libs at load time. The install
    # also bakes $ORIGIN/../lib into the binary RPATH so llama.cpp's own
    # libs (libllama.so, libggml*.so) resolve. We set LD_LIBRARY_PATH for
    # the CUDA runtime specifically — libs/cuda is not under the binary's
    # RPATH search.
    local smoke_ld_path="${LOCAL_CUDA}/lib64:${LD_LIBRARY_PATH:-}"

    echo -e "${C_BLUE}== Smoke testing llama-server ==${C_RESET}"
    LD_LIBRARY_PATH="$smoke_ld_path" "$server_bin" \
        -m "$model_path" \
        --embedding \
        --host 127.0.0.1 \
        --port "$port" \
        > "$log" 2>&1 &
    local pid=$!

    # Wait up to 30 s for the server to become responsive.
    local i=0
    while [ "$i" -lt 30 ]; do
        if curl -s --max-time 1 "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
            break
        fi
        sleep 1
        i=$((i + 1))
    done

    if [ "$i" -ge 30 ]; then
        echo -e "${C_RED}Server did not become responsive within 30 s${C_RESET}" >&2
        echo "Last 20 lines of server log ($log):" >&2
        tail -n 20 "$log" >&2
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        exit 1
    fi

    local response
    response=$(curl -s --max-time 10 "http://127.0.0.1:$port/v1/embeddings" \
        -H 'Content-Type: application/json' \
        -d '{"model": "nomic-embed-text", "input": "clustering: hello world"}')

    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null

    if echo "$response" | grep -q '"embedding"'; then
        echo -e "${C_GREEN}Smoke test passed — server returned a valid embedding.${C_RESET}"
    else
        echo -e "${C_RED}Smoke test failed — unexpected response:${C_RESET}" >&2
        echo "$response" >&2
        exit 1
    fi
}
# }}}

# {{{ print_env_summary
# Final friendly summary so the operator knows what env vars to set if they
# want to invoke llama-server / nvcc by hand outside this script. The build
# script handles its own env internally, but downstream tools need the hint.
print_env_summary() {
    cat <<EOF

${C_GREEN}===============================================================${C_RESET}
${C_GREEN}  build-deps.sh complete${C_RESET}
${C_GREEN}===============================================================${C_RESET}
  CUDA:     ${LOCAL_CUDA}
  Binaries: ${LLAMACPP_INSTALL_DIR}/bin/
  Libs:     ${LLAMACPP_INSTALL_DIR}/lib/
  Source:   ${LLAMACPP_SRC_DIR} (RAM-backed; wipes on reboot)
  Model:    ${DIR}/assets/models/${MODEL_FILE}

  To use libs/cuda's nvcc/cuda-runtime from your shell, add to ~/.bashrc:
    export PATH="${LOCAL_CUDA}/bin:\$PATH"
    export LD_LIBRARY_PATH="${LOCAL_CUDA}/lib64:\$LD_LIBRARY_PATH"
EOF
}
# }}}

# {{{ main
main() {
    parse_arguments "$@"
    check_requirements
    # Bail BEFORE the CUDA install step if libs/llama.cpp/.git exists and
    # --clean was not passed — saves the operator from eating a 5 GB CUDA
    # download just to discover their old layout blocks the install.
    detect_old_llamacpp_layout
    ensure_directories
    build_cuda
    clone_llamacpp
    build_llamacpp
    install_llamacpp
    download_model
    smoke_test
    print_env_summary
}
# }}}

main "$@"

# vim: set foldmethod=marker:
