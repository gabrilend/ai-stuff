#!/bin/bash
# stand-in-model.sh - start and stop the stand-in chat model for a test.
#
# Source it, then:
#   stand_in_start SCRATCH-DIR   builds server.c into SCRATCH-DIR, starts it on
#                                a free loopback port with brain.lua, and
#                                exports INFERENCE_CHAT_HOST (which
#                                llama-chat-client.lua honours) and
#                                AISTUFF_ROOT (where dkjson lives)
#   stand_in_stop                stops it
#
# Nothing is downloaded and no model runs: brain.lua answers each task by a
# fixed rule (see its header). Needs gcc and luajit.

STAND_IN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAND_IN_PID=""

# -- {{{ stand_in_start
function stand_in_start() {
    local scratch="$1" port_file
    mkdir -p "$scratch"
    gcc -O2 -o "$scratch/stand-in-server" "$STAND_IN_DIR/server.c" || return 1
    port_file="$scratch/stand-in-port"
    rm -f "$port_file"
    export AISTUFF_ROOT="${AISTUFF_ROOT:-$(cd "$STAND_IN_DIR/../../../.." && pwd)}"
    "$scratch/stand-in-server" 0 "luajit $STAND_IN_DIR/brain.lua" > "$port_file" 2>/dev/null &
    STAND_IN_PID=$!
    local tries=0
    while [ ! -s "$port_file" ] && [ $tries -lt 50 ]; do
        sleep 0.1
        tries=$((tries + 1))
    done
    [ -s "$port_file" ] || { stand_in_stop; return 1; }
    export INFERENCE_CHAT_HOST="127.0.0.1:$(head -1 "$port_file")"
}
# }}}

# -- {{{ stand_in_stop
function stand_in_stop() {
    if [ -n "$STAND_IN_PID" ]; then
        kill "$STAND_IN_PID" 2>/dev/null
        wait "$STAND_IN_PID" 2>/dev/null
        STAND_IN_PID=""
    fi
}
# }}}
