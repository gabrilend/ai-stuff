#!/usr/bin/env bash
# component-orchestrator.sh -- the component orchestrator, for shell scripts.
# Source it, register components, then start, stop or check them. Each call
# runs libs/component-orchestrator.lua, which keeps what is running in the
# project's state folder, so a later script (or a later run of this one) can
# stop what an earlier one started. (Issue 013.)
#
#   source /path/to/scripts/libs/component-orchestrator.sh
#   orch_init "/path/to/project"
#   orch_register "daemon" "target/release/daemon" 8080
#   orch_register "client" "target/release/client" "" "daemon"
#   orch_start_all
#   orch_status_all
#   orch_stop_all
#
# State folder: <project>/tmp/orchestrator/, or $ORCH_STATE_DIR when set.
# Registrations are written to components.tsv there, one line each:
# name <TAB> port <TAB> dependencies <TAB> command.

ORCH_LIBS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCH_PROJECT_DIR=""

# {{{ orch_init
# orch_init <project-dir>: where commands run from and state is kept.
orch_init() {
    ORCH_PROJECT_DIR="${1:?orch_init needs a project folder}"
    export ORCH_STATE_DIR="${ORCH_STATE_DIR:-$ORCH_PROJECT_DIR/tmp/orchestrator}"
    mkdir -p "$ORCH_STATE_DIR"
}
# }}}

# {{{ orch_register
# orch_register <name> <command> [port] [dependencies, comma-separated]
# Registering a name again replaces its line.
orch_register() {
    local name="${1:?orch_register needs a name}" command="${2:?orch_register needs a command}"
    local port="${3:--}" deps="${4:--}"
    [[ -z "$port" ]] && port="-"
    [[ -z "$deps" ]] && deps="-"
    if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "orch_register: a name is letters, digits, '.', '_' or '-': $name" >&2
        return 1
    fi
    local file="$ORCH_STATE_DIR/components.tsv"
    touch "$file"
    local kept
    kept="$(awk -F'\t' -v n="$name" '$1 != n' "$file")"
    {
        [[ -n "$kept" ]] && printf '%s\n' "$kept"
        printf '%s\t%s\t%s\t%s\n' "$name" "$port" "$deps" "$command"
    } > "$file.new" && mv -f "$file.new" "$file"
}
# }}}

# {{{ orch_run
# Runs the Lua orchestrator on this project with the given command words.
orch_run() {
    luajit "$ORCH_LIBS_DIR/component-orchestrator.lua" "$ORCH_PROJECT_DIR" "$@"
}
# }}}

# {{{ lifecycle
orch_start()      { orch_run start "${1:?orch_start needs a name}"; }
orch_stop()       { orch_run stop "${1:?orch_stop needs a name}"; }
orch_health()     { orch_run health "${1:?orch_health needs a name}"; }
orch_start_all()  { orch_run start-all; }
orch_stop_all()   { orch_run stop-all; }
orch_status_all() { orch_run status; }
# }}}
