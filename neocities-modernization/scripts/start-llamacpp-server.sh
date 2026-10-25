#!/bin/bash
# scripts/start-llamacpp-server.sh
# Launches the project-local llama.cpp embedding server. Reads which server
# (host, port, model file) to launch from config.lua's inference_servers
# via libs/inference-server-config.lua, sets up the CUDA runtime on
# LD_LIBRARY_PATH so the binary's dlopen of libcudart succeeds, then
# starts llama-server with --embedding so the OpenAI-compatible
# /v1/embeddings endpoint is active. Verifies the server is responsive
# via /health before declaring success.
#
# Usage:
#   ./scripts/start-llamacpp-server.sh                # Default server from config.lua
#   ./scripts/start-llamacpp-server.sh --server=NAME  # Specific server entry
#   ./scripts/start-llamacpp-server.sh /custom/dir    # Override project DIR
#   ./scripts/start-llamacpp-server.sh --help         # Show this message
#
# Replaces the old Ollama launcher (removed 2026-10-22) as the embedding-backend launcher
# per issue 10-049. The on-disk binary at libs/llama.cpp/bin/llama-server
# is produced by scripts/build-deps.sh; if it is missing, run that script
# first.

# {{{ Hard-coded project directory and default state
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
SERVER_NAME=""
MODEL_OVERRIDE=""
# }}}

# {{{ Color codes
C_GREEN="\033[92m"
C_BLUE="\033[94m"
C_RED="\033[91m"
C_YELLOW="\033[93m"
C_RESET="\033[0m"
# }}}

# {{{ parse_arguments
# Recognized flags:
#   --server=NAME : override the default_inference_server from config
#   --model=NAME  : required; the model to serve, one of that server's
#                   available_models (loads its GGUF). There is no default.
#   /path/to/dir  : override the project DIR (positional)
parse_arguments() {
    for arg in "$@"; do
        case "$arg" in
            --server=*)
                SERVER_NAME="${arg#*=}"
                ;;
            --model=*)
                # The model to serve (one of the server's available_models):
                # its GGUF is loaded. Required -- config.lua names no default
                # model (2026-10-21); the library refuses a run without one.
                MODEL_OVERRIDE="${arg#*=}"
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
                DIR="$arg"
                ;;
        esac
    done
}
# }}}

# {{{ resolve_server_config
# Asks libs/inference-server-config.lua to resolve the chosen server (default
# or --server=NAME override) and prints to stdout, one per line: host, port,
# model_path (relative to DIR), the model identifier, the model's
# vision_projector (relative to DIR, or "-" for a model without one), and then
# each word of the server's launch_flags (zero or more lines). Errors from the
# module (typoed --server, missing default) propagate to stderr verbatim.
# Running the module in a subprocess keeps the parent shell free of any
# stray Lua state and lets us capture exactly the fields we want.
resolve_server_config() {
    local server_override=""
    if [ -n "$SERVER_NAME" ]; then
        server_override="inference.set_selected_server('${SERVER_NAME}')"
    fi
    local model_override=""
    if [ -n "$MODEL_OVERRIDE" ]; then
        model_override="inference.set_selected_model('${MODEL_OVERRIDE}')"
    fi
    luajit -e "
        package.path = '${DIR}/libs/?.lua;' .. package.path
        local inference = require('inference-server-config')
        inference.set_project_root('${DIR}')
        ${server_override}
        ${model_override}
        local server = inference.get_selected_server()
        -- Resolve the GGUF for the model named with --model (there is no
        -- default; the library refuses a run without one).
        local mc = inference.get_selected_model_config()
        if not mc.model_path then
            error('inference-server-config: model \"' .. tostring(mc.model)
                .. '\" on server \"' .. server.name .. '\" has no model_path; add it '
                .. 'to that model in available_models')
        end
        print(server.host)
        print(server.port)
        print(mc.model_path)
        print(mc.model)
        -- Issue 9-013: the picture-reading add-on, when this model has one
        print(mc.vision_projector or '-')
        -- One word per line so a flag and its value stay separate words in
        -- the shell array they are read into.
        for _, word in ipairs(server.launch_flags or {}) do
            print(word)
        end
    "
}
# }}}

# {{{ setup_env
# Prepend libs/cuda to PATH and LD_LIBRARY_PATH so the llama-server binary
# finds nvcc tools (when invoked) and libcudart at dlopen time. The binary's
# own RPATH covers libs/llama.cpp/lib (built into the binary by build-deps.sh
# via -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'), so we do not need to add that
# directory explicitly.
#
# GGML_CUDA_FORCE_MMQ was tried 2026-06-20 and reverted. The hard-freeze
# symptom predated this flag, so MMQ wasn't the cause; forcing MMQ might
# just be picking a different-but-also-buggy CUDA kernel path on Pascal.
# Removed to use the default kernel selection (cuBLAS where applicable).
setup_env() {
    export PATH="${DIR}/libs/cuda/bin:${PATH}"
    export LD_LIBRARY_PATH="${DIR}/libs/cuda/lib64:${LD_LIBRARY_PATH:-}"
}
# }}}

# {{{ already_running
# Returns 0 if some server is already healthy at HOST:PORT — meaning we
# should not try to start a second one. Returns non-zero otherwise.
already_running() {
    # Must be genuinely SERVING (HTTP 200), not merely accepting connections: a
    # server still loading answers /health with 503, and curl -s exits 0 on that
    # too. Treating a 503 as "already running" would skip our start AND fail the
    # caller's readiness check. So compare the status code explicitly.
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "http://${HOST}:${PORT}/health" 2>/dev/null)
    [ "$code" = "200" ]
}
# }}}

# {{{ verify_artifacts
# Sanity-check that the things we need to actually run llama-server exist
# on disk before launching. Failing here with a clear "run build-deps.sh"
# message is friendlier than letting the operator debug a missing-binary
# error or a missing-model crash from the server's log.
verify_artifacts() {
    local server_bin="${DIR}/libs/llama.cpp/bin/llama-server"
    if [ ! -x "$server_bin" ]; then
        echo -e "${C_RED}llama-server not found at $server_bin${C_RESET}" >&2
        echo -e "  ${C_YELLOW}HINT${C_RESET}  run ./scripts/build-deps.sh to build llama.cpp" >&2
        exit 1
    fi

    local abs_model_path="${DIR}/${MODEL_PATH}"
    if [ ! -f "$abs_model_path" ]; then
        echo -e "${C_RED}Model file not found: $abs_model_path${C_RESET}" >&2
        echo -e "  ${C_YELLOW}HINT${C_RESET}  run ./scripts/build-deps.sh to download the GGUF" >&2
        exit 1
    fi
}
# }}}

# {{{ launch_server
# Start llama-server in the background with --embedding so the embedding
# endpoints are active. Output goes to LOG_FILE in the RAM-backed tmp/
# directory; SERVER_PID is captured so the operator can stop it cleanly.
launch_server() {
    local server_bin="${DIR}/libs/llama.cpp/bin/llama-server"
    local abs_model_path="${DIR}/${MODEL_PATH}"

    echo -e "${C_BLUE}Starting llama-server${C_RESET}"
    echo -e "  bin:    $server_bin"
    echo -e "  model:  $abs_model_path"
    echo -e "  host:   $HOST"
    echo -e "  port:   $PORT"
    echo -e "  log:    $LOG_FILE"

    # Explicit launch flags. These now mirror the known-good words-pdf launcher
    # (scripts/start-llamacpp-server.sh there), which runs the byte-identical
    # nomic-embed-text-v1.5.Q8_0 GGUF on the same machine without freezing.
    # Before this change the neocities launcher set none of the GPU/batch flags
    # and relied on llama-server's defaults — which diverge from the working
    # reference in three ways that matter:
    #
    #   --n-gpu-layers 99: offload ALL layers to the GPU. Without an explicit
    #                 value the default can leave the model PARTIALLY offloaded,
    #                 which shuttles tensors across PCIe every forward pass and
    #                 interleaves longer-lived GPU work with copies — more
    #                 opportunity to starve the display compositor on Pascal.
    #                 Full offload is the well-trodden path the reference uses.
    #   --ctx-size 8192 / --batch-size 8192 / --ubatch-size 8192:
    #                 embedding mode has no chunking — the WHOLE input must fit
    #                 in one ubatch. The default ubatch is 512 (~2048 chars), so
    #                 any poem longer than that was being REJECTED with "input
    #                 too large to process". 8192 tokens (~32k chars) lets all
    #                 but a couple of giant poems through. (nomic's own context
    #                 caps at 2048 tokens, so longer inputs are truncated by the
    #                 model — full-fidelity handling of those is a separate
    #                 chunk-and-average task, see issues/.)
    #   --parallel 1: cap concurrent request slots at 1. Each parallel slot
    #                 allocates its own KV cache, multiplying VRAM pressure
    #                 linearly. Also llama-server's default; set explicitly so a
    #                 future operator doesn't crank it up assuming it's free.
    #   --load-mode mmap+mlock : pin the model in RAM so the kernel cannot
    #                 swap parts of it back to disk under memory pressure. On
    #                 Pascal, swap-induced stuttering of forward passes can
    #                 extend a CUDA kernel's wall time past the display watchdog
    #                 timeout. Cost is the model's size in pinned RAM (140-310 MB
    #                 for the Q8_0 files here), cheap on a 31 GB host.
    #                 Was "--mlock" until llama.cpp b11476 removed that flag
    #                 (the server then refused to start); mmap+mlock is the
    #                 same pairing the old flag gave with mmap on by default.
    #
    # -lv 1 (verbose) is added ONLY under --debug (NEOCITIES_LOG_DIR set): it
    # emits per-request slot lines that are gold for diagnosing a freeze, but
    # noise during normal runs.
    local -a launch_flags=(
        -m "$abs_model_path"
        # Advertise the model under the name config.lua uses for it (e.g.
        # "embeddinggemma-300m"), not the GGUF filename. /v1/models then reports
        # that exact name, so callers that verify "is my model loaded?" by
        # matching the model name succeed -- without --alias the server reports
        # the .gguf path, and a name like embeddinggemma-300m fails to match
        # embeddinggemma-300M-Q8_0.gguf (the case differs), which read as the
        # model being absent even though it was loaded and serving fine.
        --alias "$MODEL"
        --embedding
        --host "$HOST"
        --port "$PORT"
        --n-gpu-layers 99
        --ctx-size 8192
        --batch-size 8192
        --ubatch-size 8192
        --parallel 1
        --load-mode mmap+mlock
    )
    if [ -n "${NEOCITIES_LOG_DIR:-}" ]; then
        launch_flags+=( -lv 1 )
    fi
    # Issue 9-013: a model with a vision projector loads it, so the same
    # server embeds pictures (Stage 6's picture step) as well as text.
    # "-": a text-only model; no projector is loaded.
    if [ "$VISION_PROJECTOR" != "-" ]; then
        local abs_projector="${DIR}/${VISION_PROJECTOR}"
        if [ ! -f "$abs_projector" ]; then
            echo -e "${C_RED}Vision projector not found: $abs_projector${C_RESET}" >&2
            exit 1
        fi
        launch_flags+=( --mmproj "$abs_projector" )
    fi
    # The server entry's launch_flags (config.lua) come last, so a GPU-specific
    # setting there can also override one of the shared flags above.
    launch_flags+=( "${SERVER_FLAGS[@]}" )

    # In --debug, pipe the server's stdout/stderr through fsync-logger so each
    # log line is committed to disk immediately (it survives a hard lock). The
    # process substitution is a SIBLING of llama-server, so $! still captures
    # llama-server's PID — exactly the process we health-check and kill. Outside
    # debug, the plain file redirect keeps things fast.
    if [ -n "${NEOCITIES_LOG_DIR:-}" ]; then
        "$server_bin" "${launch_flags[@]}" \
            > >("${DIR}/scripts/fsync-logger" --quiet "$LOG_FILE") 2>&1 &
    else
        "$server_bin" "${launch_flags[@]}" > "$LOG_FILE" 2>&1 &
    fi
    SERVER_PID=$!
    echo -e "  pid:    $SERVER_PID"
}
# }}}

# {{{ wait_for_ready
# Poll /health until the server responds or we hit the timeout. Returns 0
# on success, 1 on timeout. Using /health is the lightest "are you alive"
# probe the server exposes; /v1/models would also work but takes slightly
# longer to respond because it walks the loaded model list.
wait_for_ready() {
    # Model load + the warm-up empty run (large batch) can take well over 30s on
    # a busy GPU, so allow generous headroom.
    local max_wait=180
    local i=0
    while [ "$i" -lt "$max_wait" ]; do
        # CRITICAL: /health returns 503 while the model is still loading/warming
        # up and 200 only when it can actually serve. `curl -s` exits 0 even on
        # 503, so checking the exit code alone declares "ready" mid-warm-up and
        # the first real request then 503s (the bug this fixes). Inspect the
        # HTTP STATUS CODE and wait for a genuine 200.
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "http://${HOST}:${PORT}/health" 2>/dev/null)
        if [ "$code" = "200" ]; then
            return 0
        fi
        # A server that has already exited will never answer. Without this
        # check a refused flag (e.g. "invalid argument: --mlock") cost the full
        # three minutes before the error was shown.
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            return 2
        fi
        sleep 1
        i=$((i + 1))
    done
    return 1
}
# }}}

# {{{ main
main() {
    parse_arguments "$@"
    "${DIR}/scripts/ensure-tmp-symlink" "${DIR}" 2>/dev/null
    # run.sh's --debug exports NEOCITIES_LOG_DIR pointing at durable disk
    # (output/debug-logs) so the server log survives the reboot a hard GPU
    # lock forces. Default stays in the RAM-backed tmp/. The PID file stays in
    # tmp regardless: it is runtime state, and run.sh's cleanup_inference_server
    # reads it from tmp/.
    LOG_DIR="${NEOCITIES_LOG_DIR:-${DIR}/tmp}"
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/llamacpp-server.log"

    echo -e "${C_BLUE}=================================${C_RESET}"
    echo -e "${C_BLUE}  llama.cpp Embedding Server${C_RESET}"
    echo -e "${C_BLUE}=================================${C_RESET}"

    local config
    config=$(resolve_server_config) || exit 1
    HOST=$(echo "$config" | sed -n 1p)
    PORT=$(echo "$config" | sed -n 2p)
    MODEL_PATH=$(echo "$config" | sed -n 3p)
    MODEL=$(echo "$config" | sed -n 4p)
    VISION_PROJECTOR=$(echo "$config" | sed -n 5p)
    # Lines 6 onward: this server's own GPU flags from config.lua.
    local server_flags_text
    server_flags_text=$(echo "$config" | sed -n '6,$p')
    SERVER_FLAGS=()
    if [ -n "$server_flags_text" ]; then
        # Present: the server entry states flags for its GPU; pass them on.
        # Absent: llama-server's own defaults stand for anything not set below.
        mapfile -t SERVER_FLAGS <<< "$server_flags_text"
    fi

    if [ -n "$SERVER_NAME" ]; then
        echo -e "  ${C_GREEN}server${C_RESET}: $SERVER_NAME (--server override)"
    fi
    echo -e "  ${C_GREEN}model${C_RESET}:  $MODEL"
    if [ "${#SERVER_FLAGS[@]}" -gt 0 ]; then
        # Shown so the operator sees which GPU-specific choices are in force.
        echo -e "  ${C_GREEN}gpu flags${C_RESET}: ${SERVER_FLAGS[*]}"
    fi

    setup_env
    verify_artifacts

    if already_running; then
        echo -e "${C_GREEN}✓ llama-server is already running at ${HOST}:${PORT}${C_RESET}"
        exit 0
    fi

    launch_server
    local ready_status=0
    wait_for_ready || ready_status=$?
    if [ "$ready_status" -ne 0 ]; then
        # 2: the process exited during startup (usually a refused flag or a
        #    model file it cannot read) -- the log's last lines say which.
        # 1: still running but never became ready within the wait.
        if [ "$ready_status" -eq 2 ]; then
            echo -e "${C_RED}llama-server exited during startup${C_RESET}" >&2
        else
            echo -e "${C_RED}llama-server did not become ready within 180 seconds${C_RESET}" >&2
        fi
        echo -e "  Last 20 lines of log ($LOG_FILE):" >&2
        tail -n 20 "$LOG_FILE" >&2
        kill "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null
        exit 1
    fi

    # Persist the PID so other processes (run.sh's auto-start cleanup, or
    # a manual operator using `kill $(cat tmp/shared-memory/llamacpp-server.pid)`)
    # can find the server later. The PID file is overwritten on each start.
    local pid_file="${DIR}/tmp/shared-memory/llamacpp-server.pid"
    echo "$SERVER_PID" > "$pid_file"

    echo -e "${C_GREEN}✅ llama-server ready at http://${HOST}:${PORT}${C_RESET}"
    echo
    echo -e "${C_BLUE}🔧 Service management:${C_RESET}"
    echo "  • Logs:    tail -f $LOG_FILE"
    echo "  • Stop:    kill \$(cat $pid_file)    # PID: $SERVER_PID"
    echo "  • Status:  curl -s http://${HOST}:${PORT}/health"
    echo
    echo -e "${C_GREEN}🚀 Ready for embedding requests at http://${HOST}:${PORT}/v1/embeddings${C_RESET}"
}
# }}}

main "$@"

# vim: set foldmethod=marker:
