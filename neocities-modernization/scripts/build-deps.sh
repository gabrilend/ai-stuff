#!/bin/bash
# scripts/build-deps.sh
# Downloads and builds llama.cpp locally in the project's libs/ directory.
# Replaces the system-installed Ollama daemon as the embedding backend per
# issue 10-049. Builds with CUDA support so the GTX 1080 Ti can accelerate
# inference; downloads the configured embedding model as a GGUF file so the
# server has something to serve out of the box.
#
# Usage:
#   ./scripts/build-deps.sh              # Build into the default project DIR
#   ./scripts/build-deps.sh /custom/dir  # Build into a different project DIR
#   ./scripts/build-deps.sh --clean      # Remove existing build and rebuild
#   ./scripts/build-deps.sh --no-model   # Skip the GGUF model download
#   ./scripts/build-deps.sh --help       # Show this message
#
# What this gives you on success:
#   $DIR/libs/llama.cpp/             — the cloned source tree
#   $DIR/libs/llama.cpp/build/bin/   — llama-server, llama-cli, llama-embedding
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
# entry expects after the 10-049 migration; updating one without the other
# would mismatch.
MODEL_REPO="nomic-ai/nomic-embed-text-v1.5-GGUF"
MODEL_FILE="nomic-embed-text-v1.5.f16.gguf"
MODEL_URL="https://huggingface.co/${MODEL_REPO}/resolve/main/${MODEL_FILE}"
# }}}

# {{{ Color codes for human-readable output
C_GREEN="\033[92m"
C_BLUE="\033[94m"
C_RED="\033[91m"
C_YELLOW="\033[93m"
C_RESET="\033[0m"
# }}}

# {{{ parse_arguments
parse_arguments() {
    CLEAN_BUILD=0
    SKIP_MODEL=0

    for arg in "$@"; do
        case "$arg" in
            --clean)
                CLEAN_BUILD=1
                ;;
            --no-model)
                SKIP_MODEL=1
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
}
# }}}

# {{{ check_requirements
# Verifies the build tools and CUDA toolkit are available before we
# attempt to clone or compile anything. Failing fast here is better
# than failing 10 minutes into a build with a confusing CUDA error.
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

    # CUDA's nvcc is the linchpin — if this is missing, the CUDA build
    # will not work and we should fall back to a CPU build OR error.
    if ! command -v nvcc >/dev/null 2>&1; then
        echo -e "  ${C_RED}MISSING${C_RESET}  nvcc — CUDA toolkit not on PATH"
        echo -e "  ${C_YELLOW}HINT${C_RESET}     install with: sudo apt install nvidia-cuda-toolkit"
        echo -e "  ${C_YELLOW}HINT${C_RESET}     or add /usr/local/cuda/bin to PATH"
        missing=1
    else
        local nvcc_ver
        nvcc_ver=$(nvcc --version | grep -oP 'release \K[0-9.]+' | head -n1)
        echo -e "  ${C_GREEN}found${C_RESET}    nvcc (release $nvcc_ver)"
    fi

    # GCC version compatibility: modern CUDA (12.x) requires gcc <= 13;
    # CUDA 13 supports up to gcc 14. The system's distro gcc may be
    # newer than that. Surface clearly if there is a mismatch.
    local gcc_major
    gcc_major=$(gcc -dumpversion | cut -d. -f1)
    echo -e "  ${C_GREEN}found${C_RESET}    gcc major version $gcc_major"
    if [ "$gcc_major" -gt 14 ]; then
        echo -e "  ${C_YELLOW}WARN${C_RESET}     gcc $gcc_major may be newer than the installed CUDA supports."
        echo -e "  ${C_YELLOW}HINT${C_RESET}     if the build fails with CUDA host-compiler errors,"
        echo -e "  ${C_YELLOW}HINT${C_RESET}     install gcc-13 or gcc-14 alongside and pass it via CC/CXX."
    fi

    if [ "$missing" -ne 0 ]; then
        echo -e "${C_RED}== Prerequisites missing — aborting ==${C_RESET}" >&2
        exit 1
    fi
}
# }}}

# {{{ ensure_directories
# Create the destination directories with mkdir -p. tmp/ is symlinked
# to a RAM-backed location for ephemeral working files.
ensure_directories() {
    mkdir -p "${DIR}/libs"
    mkdir -p "${DIR}/assets/models"
    "${DIR}/scripts/ensure-tmp-symlink" "${DIR}" 2>/dev/null || mkdir -p "${DIR}/tmp"
}
# }}}

# {{{ clone_llamacpp
# Clone llama.cpp at the pinned version, or refresh if it already exists.
# Pinning to a tag keeps the build reproducible across sessions.
clone_llamacpp() {
    local repo_dir="${DIR}/libs/llama.cpp"

    if [ "$CLEAN_BUILD" -eq 1 ] && [ -d "$repo_dir" ]; then
        echo -e "${C_BLUE}== Cleaning existing llama.cpp checkout ==${C_RESET}"
        rm -rf "$repo_dir"
    fi

    if [ -d "$repo_dir" ]; then
        echo -e "${C_BLUE}== Updating llama.cpp checkout ==${C_RESET}"
        git -C "$repo_dir" fetch --tags --depth=1 origin "$LLAMACPP_VERSION" || {
            echo -e "${C_RED}Failed to fetch llama.cpp tag $LLAMACPP_VERSION${C_RESET}" >&2
            exit 1
        }
        git -C "$repo_dir" checkout "$LLAMACPP_VERSION" || {
            echo -e "${C_RED}Failed to checkout llama.cpp $LLAMACPP_VERSION${C_RESET}" >&2
            exit 1
        }
    else
        echo -e "${C_BLUE}== Cloning llama.cpp (tag $LLAMACPP_VERSION) ==${C_RESET}"
        git clone --depth=1 --branch "$LLAMACPP_VERSION" \
            https://github.com/ggml-org/llama.cpp.git "$repo_dir" || {
            echo -e "${C_RED}Clone failed. Check network and tag validity.${C_RESET}" >&2
            exit 1
        }
    fi

    echo -e "${C_GREEN}llama.cpp ready at $repo_dir${C_RESET}"
}
# }}}

# {{{ build_llamacpp
# Configure and build llama.cpp with CUDA support. Outputs land in
# libs/llama.cpp/build/bin/. The configure step picks up gcc/nvcc from
# PATH; if the host gcc is too new, the operator can override via env:
#   CC=gcc-13 CXX=g++-13 ./scripts/build-deps.sh
build_llamacpp() {
    local repo_dir="${DIR}/libs/llama.cpp"
    local build_dir="${repo_dir}/build"

    if [ "$CLEAN_BUILD" -eq 1 ] && [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi

    mkdir -p "$build_dir"
    cd "$build_dir"

    echo -e "${C_BLUE}== Configuring llama.cpp (CUDA enabled) ==${C_RESET}"
    cmake .. \
        -DGGML_CUDA=ON \
        -DGGML_NATIVE=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=ON || {
        echo -e "${C_RED}CMake configure failed.${C_RESET}" >&2
        echo -e "${C_YELLOW}Common causes:${C_RESET}" >&2
        echo -e "  - gcc too new for installed CUDA (set CC/CXX to an older gcc)" >&2
        echo -e "  - CUDA samples or toolkit components missing" >&2
        echo -e "  - Vulkan headers conflicting (not actually used by this build)" >&2
        exit 1
    }

    echo -e "${C_BLUE}== Building llama.cpp ==${C_RESET}"
    local jobs
    jobs=$(nproc 2>/dev/null || echo 4)
    cmake --build . --config Release -j "$jobs" || {
        echo -e "${C_RED}Build failed.${C_RESET}" >&2
        exit 1
    }

    # Verify the binaries we care about actually got built.
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
        exit 1
    fi

    echo -e "${C_GREEN}llama.cpp built successfully${C_RESET}"
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

    local server_bin="${DIR}/libs/llama.cpp/build/bin/llama-server"
    local model_path="${DIR}/assets/models/${MODEL_FILE}"
    local port=18080  # Non-default to avoid collision with any running server
    local log="${DIR}/tmp/llamacpp-smoketest.log"

    echo -e "${C_BLUE}== Smoke testing llama-server ==${C_RESET}"
    "$server_bin" \
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

# {{{ main
main() {
    parse_arguments "$@"
    check_requirements
    ensure_directories
    clone_llamacpp
    build_llamacpp
    download_model
    smoke_test

    echo
    echo -e "${C_GREEN}===============================================================${C_RESET}"
    echo -e "${C_GREEN}  build-deps.sh complete${C_RESET}"
    echo -e "${C_GREEN}===============================================================${C_RESET}"
    echo "  Binaries: $DIR/libs/llama.cpp/build/bin/"
    echo "  Model:    $DIR/assets/models/$MODEL_FILE"
    echo
    echo "  Next step: 10-049 migration (replace Ollama callers with llama.cpp)"
    echo
}
# }}}

main "$@"

# vim: set foldmethod=marker:
