#!/bin/bash

# {{{ State Daemon
# A background service that holds key-value state in RAM.
# Other scripts can query/set state via named pipes or the client mode.
# Uses FIFO pipes for IPC - lightweight and bash-native.
#
# Usage:
#   state-daemon.sh start     # Start daemon in background
#   state-daemon.sh stop      # Stop running daemon
#   state-daemon.sh status    # Check if daemon is running
#   state-daemon.sh get KEY   # Get value for key
#   state-daemon.sh set KEY VALUE  # Set key to value
#   state-daemon.sh del KEY   # Delete key
#   state-daemon.sh list      # List all keys
#   state-daemon.sh dump      # Dump all key=value pairs
#   state-daemon.sh clear     # Clear all state
#   state-daemon.sh watch     # Show every key, refreshed until a key is pressed
#   state-daemon.sh -I        # Menu: browse keys, set, delete, clear, watch
# }}}

DIR="${STATE_DAEMON_DIR:-/tmp/state-daemon}"
if [ -n "$1" ] && [ -d "$1" ]; then
    DIR="$1"
    shift
fi

# {{{ Configuration
SOCKET_DIR="$DIR"
REQUEST_PIPE="$SOCKET_DIR/request.fifo"
RESPONSE_DIR="$SOCKET_DIR/responses"
PID_FILE="$SOCKET_DIR/daemon.pid"
STATE_FILE="$SOCKET_DIR/state.dat"  # Backup on shutdown
LOG_FILE="$SOCKET_DIR/daemon.log"
# }}}

# {{{ ensure_dirs
ensure_dirs() {
    mkdir -p "$SOCKET_DIR" "$RESPONSE_DIR"
    chmod 700 "$SOCKET_DIR"
}
# }}}

# {{{ cleanup
cleanup() {
    echo "[$(date '+%H:%M:%S')] Daemon shutting down..." >> "$LOG_FILE"

    # Save state to file before exit
    # save_state is called within daemon context where STATE is available

    rm -f "$REQUEST_PIPE"
    rm -f "$PID_FILE"
    rm -rf "$RESPONSE_DIR"/*

    exit 0
}
# }}}

# {{{ daemon_loop
daemon_loop() {
    # Associative array for state storage
    # This lives in RAM for the lifetime of the daemon process
    declare -A STATE

    # Load state from file if exists (persistence across restarts)
    if [ -f "$STATE_FILE" ]; then
        while IFS='=' read -r key value; do
            [ -n "$key" ] && STATE["$key"]="$value"
        done < "$STATE_FILE"
        echo "[$(date '+%H:%M:%S')] Loaded $(echo ${#STATE[@]}) keys from state file" >> "$LOG_FILE"
    fi

    # Create request pipe. If that fails there is nothing to listen on, and
    # the read loop below would spin on the missing pipe for ever, filling
    # the log; so give up instead, and start_daemon reports the failure.
    rm -f "$REQUEST_PIPE"
    if ! mkfifo "$REQUEST_PIPE" || ! chmod 600 "$REQUEST_PIPE"; then
        echo "[$(date '+%H:%M:%S')] Cannot create $REQUEST_PIPE; not starting" >> "$LOG_FILE"
        exit 1
    fi

    echo "[$(date '+%H:%M:%S')] Daemon started, listening on $REQUEST_PIPE" >> "$LOG_FILE"
    echo $$ > "$PID_FILE"

    # {{{ save_state_to_file
    save_state_to_file() {
        > "$STATE_FILE"
        for key in "${!STATE[@]}"; do
            echo "${key}=${STATE[$key]}" >> "$STATE_FILE"
        done
    }
    # }}}

    # Handle shutdown gracefully
    trap 'save_state_to_file; cleanup' SIGTERM SIGINT SIGHUP

    # Main loop - read commands from pipe
    while true; do
        # Open pipe for reading (blocks until writer connects)
        if read -r line < "$REQUEST_PIPE"; then
            # Parse command: RESPONSE_ID CMD [ARGS...]
            read -r response_id cmd args <<< "$line"
            response_pipe="$RESPONSE_DIR/$response_id"

            case "$cmd" in
                GET)
                    key="$args"
                    if [ -n "${STATE[$key]+isset}" ]; then
                        echo "OK:${STATE[$key]}" > "$response_pipe"
                    else
                        echo "ERR:key_not_found" > "$response_pipe"
                    fi
                    ;;
                SET)
                    key="${args%% *}"
                    value="${args#* }"
                    STATE["$key"]="$value"
                    echo "OK:set" > "$response_pipe"
                    echo "[$(date '+%H:%M:%S')] SET $key = $value" >> "$LOG_FILE"
                    ;;
                DEL)
                    key="$args"
                    if [ -n "${STATE[$key]+isset}" ]; then
                        unset STATE["$key"]
                        echo "OK:deleted" > "$response_pipe"
                        echo "[$(date '+%H:%M:%S')] DEL $key" >> "$LOG_FILE"
                    else
                        echo "ERR:key_not_found" > "$response_pipe"
                    fi
                    ;;
                LIST)
                    result=""
                    for key in "${!STATE[@]}"; do
                        result="${result}${key}\n"
                    done
                    echo -e "OK:${result}" > "$response_pipe"
                    ;;
                DUMP)
                    result=""
                    for key in "${!STATE[@]}"; do
                        result="${result}${key}=${STATE[$key]}\n"
                    done
                    echo -e "OK:${result}" > "$response_pipe"
                    ;;
                CLEAR)
                    STATE=()
                    echo "OK:cleared" > "$response_pipe"
                    echo "[$(date '+%H:%M:%S')] CLEAR all state" >> "$LOG_FILE"
                    ;;
                PING)
                    echo "OK:pong" > "$response_pipe"
                    ;;
                SAVE)
                    save_state_to_file
                    echo "OK:saved" > "$response_pipe"
                    echo "[$(date '+%H:%M:%S')] SAVE to disk" >> "$LOG_FILE"
                    ;;
                COUNT)
                    echo "OK:${#STATE[@]}" > "$response_pipe"
                    ;;
                SHUTDOWN)
                    echo "OK:shutting_down" > "$response_pipe"
                    save_state_to_file
                    cleanup
                    ;;
                *)
                    echo "ERR:unknown_command" > "$response_pipe"
                    ;;
            esac
        fi
    done
}
# }}}

# {{{ send_command
send_command() {
    local cmd="$1"
    local args="$2"

    # Check if daemon is running
    if [ ! -p "$REQUEST_PIPE" ]; then
        echo "ERR:daemon_not_running"
        return 1
    fi

    # Generate unique response ID
    local response_id="$$_$(date +%s%N)"
    local response_pipe="$RESPONSE_DIR/$response_id"

    # Create response pipe
    mkfifo "$response_pipe" 2>/dev/null
    chmod 600 "$response_pipe"

    # Send command (with timeout to prevent blocking)
    echo "$response_id $cmd $args" > "$REQUEST_PIPE" &
    local send_pid=$!

    # Wait for response with timeout
    local timeout=5
    local result=""

    # Read response
    if timeout "$timeout" cat "$response_pipe" 2>/dev/null; then
        :
    else
        echo "ERR:timeout"
    fi

    # Cleanup
    rm -f "$response_pipe"
    wait $send_pid 2>/dev/null
}
# }}}

# {{{ start_daemon
start_daemon() {
    ensure_dirs

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Daemon already running (PID $pid)"
            return 1
        fi
        rm -f "$PID_FILE"
    fi

    # Start daemon in background. The folder goes with it: the daemon is a
    # new run of this script, and without it the daemon would fall back on
    # the default folder while this client talks to the one it was given.
    STATE_DAEMON_DIR="$DIR" nohup bash "$0" _daemon >> "$LOG_FILE" 2>&1 &
    local daemon_pid=$!

    # Started means listening: the request pipe exists and the daemon has
    # written its PID file. Wait up to two seconds for both.
    local tries=0
    while (( tries < 20 )); do
        if ! kill -0 "$daemon_pid" 2>/dev/null; then
            break
        fi
        if [ -p "$REQUEST_PIPE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$daemon_pid" ]; then
            echo "Daemon started (PID $daemon_pid)"
            echo "Socket: $REQUEST_PIPE"
            return 0
        fi
        sleep 0.1
        tries=$((tries + 1))
    done

    kill "$daemon_pid" 2>/dev/null
    echo "Failed to start daemon (see $LOG_FILE)"
    return 1
}
# }}}

# {{{ stop_daemon
stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            # Send shutdown command first (graceful)
            send_command "SHUTDOWN" "" >/dev/null 2>&1
            sleep 0.5

            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                sleep 0.2
            fi

            echo "Daemon stopped"
            return 0
        fi
    fi

    echo "Daemon not running"
    return 1
}
# }}}

# {{{ check_status
check_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Daemon running (PID $pid)"
            echo "Socket: $REQUEST_PIPE"

            # Try to get count
            local count_result=$(send_command "COUNT" "")
            if [[ "$count_result" == OK:* ]]; then
                echo "Keys stored: ${count_result#OK:}"
            fi
            return 0
        fi
    fi

    echo "Daemon not running"
    return 1
}
# }}}

# {{{ daemon_running
# Whether the daemon named in the PID file is alive.
daemon_running() {
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null)"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}
# }}}

# {{{ dump_pairs
# Every key=value pair, sorted by key, one per line. Fails when the daemon
# does not answer.
dump_pairs() {
    local result
    result=$(send_command "DUMP" "")
    [[ "$result" == OK:* ]] || return 1
    echo -e "${result#OK:}" | sed '/^$/d' | sort
}
# }}}

# {{{ watch_mode
# Redraws every key and value every <interval> seconds (default 2) until a
# key is pressed. With no terminal on standard input it keeps redrawing on
# the interval until it is stopped (Ctrl-C, or kill), rather than spinning.
watch_mode() {
    local interval="${1:-2}" key rc
    while true; do
        printf '\033[H\033[2J'
        echo "State daemon in $DIR    $(date '+%H:%M:%S')    (any key stops watching)"
        echo ""
        if daemon_running; then
            dump_pairs || echo "(the daemon did not answer)"
        else
            echo "Daemon not running"
        fi
        read -rsn1 -t "$interval" key
        rc=$?
        if [ "$rc" -eq 0 ]; then
            break
        elif [ "$rc" -le 128 ]; then
            # end of input rather than a timeout: wait out the interval here
            sleep "$interval"
        fi
    done
}
# }}}

# {{{ interactive_mode
# A menu over the daemon (issue 014, phase 3). It lists every key with its
# value; a "Do" list picks what Go does: refresh, set a key, delete the
# checked keys, clear all, watch, or stop the daemon (or start it, when it is
# not running). After each step the menu opens again with fresh values; q
# leaves. Setting a key asks for the key and value at a plain prompt, since
# the menu has no free-text field.
interactive_mode() {
    local libs_dir
    libs_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs"
    if [ ! -f "$libs_dir/lua-menu.sh" ]; then
        echo "No menu library at $libs_dir/lua-menu.sh" >&2
        return 1
    fi
    # shellcheck source=libs/lua-menu.sh
    source "$libs_dir/lua-menu.sh"

    local -a pairs=() keys=()
    local i pair key value label choice item note=""
    while true; do
        menu_init
        menu_add_section "todo" "single" "Do"
        if daemon_running; then
            mapfile -t pairs < <(dump_pairs)
            keys=()
            menu_set_title "State Daemon" "${note:-$DIR: ${#pairs[@]} key(s)}"
            menu_add_item "todo" "do_refresh" "Refresh" "checkbox" "1" "Read the keys again"
            menu_add_item "todo" "do_set" "Set a key" "checkbox" "0" "Asks for a key and a value once the menu closes"
            menu_add_item "todo" "do_delete" "Delete the checked keys" "checkbox" "0" "Check keys below with space first"
            menu_add_item "todo" "do_clear" "Clear all keys" "checkbox" "0" "Asks before clearing"
            menu_add_item "todo" "do_watch" "Watch" "checkbox" "0" "Every key, redrawn every 2 seconds until a key is pressed"
            menu_add_item "todo" "do_stop" "Stop the daemon" "checkbox" "0" "Saves its state to disk first"
            menu_add_section "keys" "multi" "Keys (space checks one for deleting)"
            if [ ${#pairs[@]} -eq 0 ]; then
                menu_add_item "keys" "no_keys" "(no keys yet)" "checkbox" "0" "Choose 'Set a key' to add one"
                menu_disable_item "no_keys"
            fi
            for i in "${!pairs[@]}"; do
                pair="${pairs[$i]}"
                key="${pair%%=*}"
                value="${pair#*=}"
                keys+=("$key")
                label="$key = $value"
                (( ${#label} > 60 )) && label="${label:0:57}..."
                menu_add_item "keys" "key_$i" "$label" "checkbox" "0" "$key = $value"
            done
            menu_set_section_max_visible "keys" 10
        else
            menu_set_title "State Daemon" "${note:-$DIR: daemon not running}"
            menu_add_item "todo" "do_start" "Start the daemon" "checkbox" "1" "Starts it in $DIR"
        fi
        menu_add_section "go" "multi" "Actions"
        menu_add_item "go" "go" "Go" "action" "" "Do what is chosen above"

        menu_run || return 0
        note=""

        choice=""
        for item in do_refresh do_set do_delete do_clear do_watch do_stop do_start; do
            if [ "${MENU_VALUES[$item]:-0}" = "1" ]; then
                choice="$item"
                break
            fi
        done

        case "$choice" in
            do_start)
                start_daemon > /dev/null || note="The daemon did not start; see $LOG_FILE"
                ;;
            do_set)
                read -r -p "Key (no spaces): " key
                if [[ -z "$key" || "$key" == *[[:space:]=]* ]]; then
                    note="Not set: a key is one word with no '='"
                else
                    read -r -p "Value for $key: " value
                    if [[ "$(send_command "SET" "$key $value")" == OK:* ]]; then
                        note="Set $key"
                    else
                        note="Could not set $key"
                    fi
                fi
                ;;
            do_delete)
                local deleted=0
                for i in "${!keys[@]}"; do
                    if [ "${MENU_VALUES[key_$i]:-0}" = "1" ]; then
                        [[ "$(send_command "DEL" "${keys[$i]}")" == OK:* ]] && deleted=$((deleted + 1))
                    fi
                done
                if [ "$deleted" -eq 0 ]; then
                    note="Nothing deleted: check keys with space first"
                else
                    note="Deleted $deleted key(s)"
                fi
                ;;
            do_clear)
                read -r -p "Clear all ${#keys[@]} key(s)? [y/N] " value
                if [[ "$value" == [yY]* ]]; then
                    send_command "CLEAR" "" > /dev/null
                    note="Cleared"
                else
                    note="Not cleared"
                fi
                ;;
            do_watch)
                watch_mode 2
                ;;
            do_stop)
                stop_daemon > /dev/null
                ;;
        esac
    done
}
# }}}

# {{{ usage
usage() {
    cat << 'EOF'
State Daemon - In-memory key-value store for shell scripts

Usage:
  state-daemon.sh [DIR] <command> [args...]

Commands:
  start           Start the daemon in background
  stop            Stop the running daemon
  status          Check daemon status and key count

  get KEY         Get value for key (prints value or error)
  set KEY VALUE   Set key to value
  del KEY         Delete key

  list            List all keys (one per line)
  dump            Dump all key=value pairs
  count           Get number of stored keys
  clear           Delete all keys

  save            Force save state to disk
  ping            Health check

  watch [SECS]    Show every key, redrawn every SECS seconds (default 2),
                  until a key is pressed
  -I              Menu: browse keys with their values; set, delete, clear,
                  watch, start or stop

Options:
  DIR             Override state directory (default: /tmp/state-daemon)
                  Can also set STATE_DAEMON_DIR environment variable

Examples:
  # Start daemon
  state-daemon.sh start

  # Store and retrieve values
  state-daemon.sh set project_name "world-edit"
  state-daemon.sh set current_phase 1
  state-daemon.sh get project_name

  # Use from another script
  value=$(state-daemon.sh get current_phase)
  if [[ "$value" == OK:* ]]; then
      phase="${value#OK:}"
      echo "Current phase: $phase"
  fi

  # List all state
  state-daemon.sh dump

  # Stop daemon (saves state to disk)
  state-daemon.sh stop

State persists across daemon restarts via /tmp/state-daemon/state.dat
EOF
}
# }}}

# {{{ main
case "$1" in
    _daemon)
        # Internal: run daemon loop
        daemon_loop
        ;;
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    status)
        check_status
        ;;
    get)
        result=$(send_command "GET" "$2")
        if [[ "$result" == OK:* ]]; then
            echo "${result#OK:}"
        else
            echo "$result" >&2
            exit 1
        fi
        ;;
    set)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 set KEY VALUE" >&2
            exit 1
        fi
        result=$(send_command "SET" "$2 $3")
        [[ "$result" == OK:* ]] || { echo "$result" >&2; exit 1; }
        ;;
    del)
        result=$(send_command "DEL" "$2")
        [[ "$result" == OK:* ]] || { echo "$result" >&2; exit 1; }
        ;;
    list)
        result=$(send_command "LIST" "")
        if [[ "$result" == OK:* ]]; then
            echo -e "${result#OK:}"
        else
            echo "$result" >&2
            exit 1
        fi
        ;;
    dump)
        result=$(send_command "DUMP" "")
        if [[ "$result" == OK:* ]]; then
            echo -e "${result#OK:}"
        else
            echo "$result" >&2
            exit 1
        fi
        ;;
    count)
        result=$(send_command "COUNT" "")
        if [[ "$result" == OK:* ]]; then
            echo "${result#OK:}"
        else
            echo "$result" >&2
            exit 1
        fi
        ;;
    clear)
        result=$(send_command "CLEAR" "")
        [[ "$result" == OK:* ]] || { echo "$result" >&2; exit 1; }
        echo "State cleared"
        ;;
    save)
        result=$(send_command "SAVE" "")
        [[ "$result" == OK:* ]] && echo "State saved to disk"
        ;;
    watch)
        watch_mode "${2:-2}"
        ;;
    -I|--interactive|interactive)
        interactive_mode
        ;;
    ping)
        result=$(send_command "PING" "")
        if [[ "$result" == OK:pong ]]; then
            echo "Daemon is alive"
        else
            echo "No response" >&2
            exit 1
        fi
        ;;
    -h|--help|help)
        usage
        ;;
    "")
        usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Run '$0 --help' for usage" >&2
        exit 1
        ;;
esac
# }}}
