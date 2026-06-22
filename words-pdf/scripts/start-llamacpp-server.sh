#!/bin/bash
# start-llamacpp-server.sh — Launch the project's llama.cpp inference servers.
#
# Two modes:
#   - Foreground (default): blocks with logs streaming to the terminal AND
#     to per-server log files. Ctrl+C cleanly stops both servers.
#   - Background (--background): launches each server detached, writes its
#     PID to tmp/llamacpp-<label>.pid, waits for readiness, exits 0. ./run
#     uses this mode and reads the PID files on its own EXIT trap to kill
#     the servers when the PDF pipeline finishes (or errors out).
#
# llama-server is single-model per process, so we run two instances (issue 025):
# one bound to nomic-embed-text v1.5 for /v1/embeddings, one bound to
# Qwen3-8B for /v1/chat/completions. Both serve on 192.168.1.100 (the LAN
# IP this box is reachable at) on adjacent ports.
#
# Idempotent against an already-running server: if either port is already
# answering /v1/models, the script does not relaunch it. In foreground
# mode it tails the existing log; in background mode it skips without
# writing a PID file (so the caller's cleanup never touches a server it
# didn't start).
#
# Readiness is checked against /v1/models — GET /api/tags will NOT work,
# llama-server doesn't expose Ollama's URL surface.

set -euo pipefail

# {{{ usage()
usage() {
    cat <<'EOF'
start-llamacpp-server.sh — Run the embedding + chat llama-server instances.

USAGE:
  ./scripts/start-llamacpp-server.sh [--background] [DIR]

OPTIONS:
  --help, -h     Show this help.
  --background   Launch detached, write PID files, exit 0 once both servers
                 are ready. Used by ./run.

ARGUMENTS:
  DIR            Path to the project root.
                 Defaults to /home/ritz/programming/ai-stuff/words-pdf.

DEFAULT BEHAVIOR (foreground):
  Starts two llama-server instances (one per model) bound to 192.168.1.100:
    - Embedding server on port 20165 (nomic-embed-text v1.5 Q8_0, --embeddings)
    - Chat server      on port 20166 (Qwen3-8B Q4_K_M)
  Each server's output streams to the terminal AND to a log file:
    - DIR/tmp/logs/llamacpp-embed.log
    - DIR/tmp/logs/llamacpp-chat.log
  Blocks until you Ctrl+C; signal handling kills both servers cleanly.

  If a port is already serving /v1/models, the script tails that server's
  log instead of relaunching.

BACKGROUND BEHAVIOR (--background):
  Launches each non-running server detached from the controlling terminal,
  records its PID to:
    - DIR/tmp/llamacpp-embed.pid
    - DIR/tmp/llamacpp-chat.pid
  Waits for /v1/models on each port, then exits 0. The caller is
  responsible for killing the PIDs when done.

  Already-running servers are skipped without writing a PID file — the
  caller must not kill a server it did not start.

REQUIREMENTS:
  - libs/llama.cpp/build/bin/llama-server   (built by scripts/build-llamacpp.sh)
  - models/nomic-embed-text-v1.5.Q8_0.gguf
  - models/Qwen3-8B-Q4_K_M.gguf
  - libs/cuda/lib64/                         (added to LD_LIBRARY_PATH)
EOF
}
# }}}

# {{{ arg parsing
BACKGROUND=0
DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --background)
            BACKGROUND=1
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
LLAMA_BIN="${DIR}/libs/llama.cpp/build/bin/llama-server"
CUDA_LIB="${DIR}/libs/cuda/lib64"

HOST_IP="192.168.1.100"

EMBED_PORT=20165
EMBED_MODEL="${DIR}/models/nomic-embed-text-v1.5.Q8_0.gguf"
EMBED_ALIAS="nomic-embed-text:v1.5"
EMBED_CTX=8192
# Embedding mode requires the WHOLE input to fit in one batch — there is
# no chunking like there is for chat generation. The default ubatch (512)
# rejects any input longer than 512 tokens with "input too large to
# process. increase the physical batch size." Setting both --batch-size
# and --ubatch-size to the context size lets poems up to ctx_size tokens
# through. nomic-embed-text v1.5 was trained at 2048 tokens; inputs over
# 2048 get truncated by the model (degraded similarity), but the server
# itself no longer errors on them.
EMBED_BATCH=8192
EMBED_LOG="${DIR}/tmp/logs/llamacpp-embed.log"
EMBED_PID_FILE="${DIR}/tmp/llamacpp-embed.pid"

CHAT_PORT=20166
CHAT_MODEL="${DIR}/models/Qwen3-8B-Q4_K_M.gguf"
CHAT_ALIAS="Qwen3-8B"
# 16K leaves room for the spacebar-continuation mode in web-server.lua,
# which accumulates lines into one growing prompt. 80-char-per-line
# responses on top, so most sessions never approach the limit.
CHAT_CTX=16384
CHAT_LOG="${DIR}/tmp/logs/llamacpp-chat.log"
CHAT_PID_FILE="${DIR}/tmp/llamacpp-chat.pid"

# How long to wait for /v1/models to respond after starting a server.
# Cold-loading a Q4 8B model from disk on the 1080 Ti takes ~5-15s; 60s
# is generous enough that a failure here is a real failure, not flake.
READY_TIMEOUT=60

# In foreground mode, the script supervises the children directly and the
# signal trap walks this list to kill them on Ctrl+C.
declare -a CHILD_PIDS=()
# }}}

# {{{ preflight()
# Bails before launching anything if the binary or models aren't where
# the script expects. A missing model gives a cleaner error here than the
# "failed to load" llama-server would produce thirty seconds in.
preflight() {
    # tmp/ is a symlink into /tmp/words-pdf which gets wiped on reboot;
    # ensure-tmp-symlink materialises the target dir before any writes.
    "${DIR}/scripts/ensure-tmp-symlink" "${DIR}"
    mkdir -p "${DIR}/tmp/logs"
    if [ ! -x "${LLAMA_BIN}" ]; then
        echo "❌ ${LLAMA_BIN} not found or not executable." >&2
        echo "   Run ./scripts/build-llamacpp.sh first." >&2
        exit 1
    fi
    if [ ! -f "${EMBED_MODEL}" ]; then
        echo "❌ Embedding model not found at ${EMBED_MODEL}" >&2
        exit 1
    fi
    if [ ! -f "${CHAT_MODEL}" ]; then
        echo "❌ Chat model not found at ${CHAT_MODEL}" >&2
        exit 1
    fi
}
# }}}

# {{{ port_responding(port)
# True if HTTP GET to /v1/models on this port returns 200. Used both as
# the skip-if-already-running check and as the readiness probe after launch.
port_responding() {
    local port="$1"
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 \
        "http://${HOST_IP}:${port}/v1/models" || echo "000")
    [ "${code}" = "200" ]
}
# }}}

# {{{ wait_for_ready(port, label)
# Poll /v1/models once per second until it returns 200 or READY_TIMEOUT
# elapses. The label is used purely for log lines so the operator knows
# which server is taking its time. Returns 0 on success, 1 on timeout.
wait_for_ready() {
    local port="$1" label="$2"
    local elapsed=0
    while [ "${elapsed}" -lt "${READY_TIMEOUT}" ]; do
        if port_responding "${port}"; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        if [ $((elapsed % 5)) -eq 0 ]; then
            echo "   ...waiting for ${label} (${elapsed}s elapsed)"
        fi
    done
    return 1
}
# }}}

# {{{ start_one_foreground(label, port, model, alias, ctx, log, [extra_args...])
# Launch a llama-server in the background of THIS shell, with stdout+stderr
# split: one copy to the per-server log file, one copy prefixed with
# [label] and printed to the terminal. Records the server PID in
# CHILD_PIDS so the EXIT/INT trap can reap it.
#
# If the port is already up, attach a `tail -F` to that server's log
# instead, so the operator still gets a unified live view in this
# terminal. Killing the tail on shutdown is harmless.
#
# Note on PID capture: with `cmd > >(tee | sed) 2>&1 &`, the process
# substitution is a sibling of cmd, not a wrapper around it; $! refers
# to cmd (llama-server), which is exactly the process we want to kill on
# Ctrl+C. The tee/sed pipeline exits automatically when its input closes.
start_one_foreground() {
    local label="$1" port="$2" model="$3" alias="$4" ctx="$5" log="$6"
    shift 6
    local prefix
    prefix=$(printf '[%-5s]' "${label}")

    if port_responding "${port}"; then
        echo "✓ ${label} server already running on ${HOST_IP}:${port}; tailing its log"
        ( exec tail -F -n 0 "${log}" | "${DIR}/scripts/llama-log-filter.sh" "${label}" ) &
        CHILD_PIDS+=("$!")
        return 0
    fi

    : > "${log}"  # truncate previous run's log so the tee output starts fresh
    echo "🚀 Starting ${label} server on ${HOST_IP}:${port} (model: ${alias})"
    LD_LIBRARY_PATH="${CUDA_LIB}:${LD_LIBRARY_PATH:-}" \
        "${LLAMA_BIN}" \
            --host "${HOST_IP}" \
            --port "${port}" \
            --model "${model}" \
            --alias "${alias}" \
            --ctx-size "${ctx}" \
            --n-gpu-layers 99 \
            -lv 1 \
            "$@" \
        > >(tee "${log}" | "${DIR}/scripts/llama-log-filter.sh" "${label}") 2>&1 &
    CHILD_PIDS+=("$!")
}
# }}}

# {{{ start_one_background(label, port, model, alias, ctx, log, pid_file, [extra_args...])
# Launch detached, redirect output to the log file only (no terminal
# duplication; the caller's stdout is the lua pipeline), and write the
# server PID to pid_file so the caller's EXIT trap can kill it.
#
# Skips without writing a PID file if the port is already serving — the
# caller must not assume ownership of a server it did not start, because
# the user may have a standalone foreground instance running.
#
# `setsid` puts the server in its own session, severing the controlling-
# terminal link. Without it, when ./run later exits and its shell sends
# SIGHUP, the server would die before the EXIT trap got a chance to
# kill it cleanly with SIGTERM — sometimes leaving it half-shut-down on
# the GPU. With setsid, only the explicit kill from the trap terminates it.
start_one_background() {
    local label="$1" port="$2" model="$3" alias="$4" ctx="$5" log="$6" pid_file="$7"
    shift 7

    if port_responding "${port}"; then
        echo "✓ ${label} server already running on ${HOST_IP}:${port}; not relaunching"
        return 0
    fi

    : > "${log}"
    echo "🚀 Starting ${label} server on ${HOST_IP}:${port} (model: ${alias})"
    setsid env \
        LD_LIBRARY_PATH="${CUDA_LIB}:${LD_LIBRARY_PATH:-}" \
        "${LLAMA_BIN}" \
            --host "${HOST_IP}" \
            --port "${port}" \
            --model "${model}" \
            --alias "${alias}" \
            --ctx-size "${ctx}" \
            --n-gpu-layers 99 \
            -lv 1 \
            "$@" \
        > "${log}" 2>&1 < /dev/null &
    echo "$!" > "${pid_file}"
}
# }}}

# {{{ on_signal()
# Foreground-mode cleanup. Bash forwards SIGINT to children in the same
# process group, so most of the cleanup happens for free. The explicit
# kill here is belt-and-suspenders for any child that ended up in a
# separate group (process-substitution pipelines do).
on_signal() {
    echo ""
    echo "🛑 Shutting down llama-server instances..."
    for pid in "${CHILD_PIDS[@]:-}"; do
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null || true
        fi
    done
}
# }}}

# {{{ main()
preflight

if [ "${BACKGROUND}" = "1" ]; then
    # Background mode: launch, wait for readiness, exit. PIDs end up in
    # the per-server pid files for the caller's trap to kill later.
    echo "════════════════════════════════════════════════════════════════"
    echo "▶  llama.cpp inference servers (background launch)"
    echo "════════════════════════════════════════════════════════════════"

    start_one_background embed "${EMBED_PORT}" "${EMBED_MODEL}" "${EMBED_ALIAS}" \
        "${EMBED_CTX}" "${EMBED_LOG}" "${EMBED_PID_FILE}" \
        --embeddings --batch-size "${EMBED_BATCH}" --ubatch-size "${EMBED_BATCH}"
    start_one_background chat  "${CHAT_PORT}"  "${CHAT_MODEL}"  "${CHAT_ALIAS}" \
        "${CHAT_CTX}"  "${CHAT_LOG}"  "${CHAT_PID_FILE}"

    if ! wait_for_ready "${EMBED_PORT}" "embedding server"; then
        echo "❌ embedding server did not come ready within ${READY_TIMEOUT}s" >&2
        echo "   See ${EMBED_LOG}" >&2
        exit 1
    fi
    if ! wait_for_ready "${CHAT_PORT}" "chat server"; then
        echo "❌ chat server did not come ready within ${READY_TIMEOUT}s" >&2
        echo "   See ${CHAT_LOG}" >&2
        exit 1
    fi
    echo "✅ Both servers ready (PIDs written to tmp/llamacpp-*.pid)"
    exit 0
fi

# Foreground mode (default).
echo "════════════════════════════════════════════════════════════════"
echo "▶  llama.cpp inference servers (foreground; Ctrl+C to stop)"
echo "════════════════════════════════════════════════════════════════"

# The trap is installed before any launches so a failure between the two
# start_one calls still tears down whichever process is already alive.
trap on_signal INT TERM EXIT

start_one_foreground embed "${EMBED_PORT}" "${EMBED_MODEL}" "${EMBED_ALIAS}" \
    "${EMBED_CTX}" "${EMBED_LOG}" \
    --embeddings --batch-size "${EMBED_BATCH}" --ubatch-size "${EMBED_BATCH}"
start_one_foreground chat  "${CHAT_PORT}"  "${CHAT_MODEL}"  "${CHAT_ALIAS}" \
    "${CHAT_CTX}"  "${CHAT_LOG}"

# Readiness probes are best-effort in foreground mode; if either fails,
# surface it and keep the servers up so the operator can read the log
# output and decide whether to retry or kill.
if ! port_responding "${EMBED_PORT}"; then
    wait_for_ready "${EMBED_PORT}" "embedding server" \
        || echo "⚠️  embedding server still not ready after ${READY_TIMEOUT}s"
fi
if ! port_responding "${CHAT_PORT}"; then
    wait_for_ready "${CHAT_PORT}" "chat server" \
        || echo "⚠️  chat server still not ready after ${READY_TIMEOUT}s"
fi

echo "════════════════════════════════════════════════════════════════"
echo "✅ Both servers reachable; logs streaming below. Ctrl+C to stop."
echo "════════════════════════════════════════════════════════════════"

# Block until every child exits (signal-driven cleanup uses the trap).
# `wait` without args waits for all background jobs of this shell.
wait
# }}}
