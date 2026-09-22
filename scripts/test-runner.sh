#!/usr/bin/env bash
# test-runner.sh
#
# Finds every test a project keeps and runs them all at once, then says which
# passed and which failed. Point it at a project folder and it needs nothing
# else: the tests are found by where they live and what they are called, run
# side by side on every core, and each one's full output is kept in RAM for
# reading afterwards. Exit 0 when everything passed, 1 when anything failed,
# 2 when there was nothing to run -- so it can sit at the end of a build.
#
# WHAT COUNTS AS A TEST
#
#   src/tests/test_*.lua, src/tests/test-*.lua,
#   tests/test_*.lua,     tests/test-*.lua       run with luajit
#   test-* / test_* in the project root, tests/ or src/tests/
#     that is executable, or ends in .sh         run as a program
#   check-* in the project root that is executable
#                                                a read-only check that
#                                                exits 1 on a fault
#
# Anything ending in -done is skipped: that suffix is the house marker for a
# retired file kept for one commit. This runner never runs itself.
#
# Why check-* counts: the house writes its verifiers as read-only reporters
# that exit 1 when something is wrong (check-transcripts-are-filed-right is
# the first). A check that nobody runs finds nothing, and "tests are cheap,
# run them during the build" covers them as much as it covers unit tests.
#
# Why there is no Lua 5.4 fallback: the house language is LuaJIT and 5.4
# syntax is not allowed, so a test that only passes under 5.4 is a failing
# test. If luajit is missing the run stops and says so.
#
# Where the output goes: <project>/tmp/shared-memory/test-runner/, the RAM
# artifact tier, which is (re)built first by libs/ensure-ram-tiers.
#
# Usage:
#   test-runner.sh [project-dir] [options]
#
# Options:
#   -f, --filter <text>   only tests whose path contains <text>
#   -j, --jobs <n>        how many tests run at once (default: every core)
#   -t, --timeout <n>     seconds before a test is stopped (default: 120)
#   -l, --list            print what would run, and run nothing
#   -v, --verbose         print every test's output, not only failures'
#   -q, --quiet           print only the summary
#   --json <file>         also write the results as JSON
#   -h, --help            this text
#
# The project directory defaults to the shared scripts folder, where this file
# lives, so running it with no arguments tests the scripts themselves.

set -euo pipefail

DIR="/home/ritz/programming/ai-stuff/scripts"
RUNNER_HOME="/home/ritz/programming/ai-stuff/scripts"

# {{{ configuration
FILTER=""
JOBS="$(nproc)"
TIMEOUT=120
LIST_ONLY=false
VERBOSE=false
QUIET=false
JSON_FILE=""
# }}}

# {{{ colours
# Colour only when a person is watching; piped output stays plain.
if [[ -t 1 ]]; then
    RED=$'\033[0;31m' GREEN=$'\033[0;32m' BOLD=$'\033[1m' NC=$'\033[0m'
else
    RED="" GREEN="" BOLD="" NC=""
fi
# }}}

# {{{ show_help
show_help() {
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}
# }}}

# {{{ parse_args
parse_args() {
    # A first argument that does not start with a dash is the project folder.
    if [[ $# -gt 0 && "$1" != -* ]]; then
        DIR="$1"
        shift
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--filter)  FILTER="$2"; shift 2 ;;
            -j|--jobs)    JOBS="$2"; shift 2 ;;
            -t|--timeout) TIMEOUT="$2"; shift 2 ;;
            -l|--list)    LIST_ONLY=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet)   QUIET=true; shift ;;
            --json)       JSON_FILE="$2"; shift 2 ;;
            -h|--help)    show_help; exit 0 ;;
            *) echo "test-runner: unknown option: $1" >&2; exit 2 ;;
        esac
    done
    if [[ ! -d "$DIR" ]]; then
        echo "test-runner: not a folder: $DIR" >&2
        exit 2
    fi
    DIR="$(realpath "$DIR")"
}
# }}}

# {{{ discover_tests
# Prints one line per test: "<kind><TAB><path>", kind being lua or program.
discover_tests() {
    local self
    self="$(readlink -f "${BASH_SOURCE[0]}")"
    local folder path name
    for folder in "$DIR/src/tests" "$DIR/tests"; do
        [[ -d "$folder" ]] || continue
        for path in "$folder"/test_*.lua "$folder"/test-*.lua; do
            [[ -f "$path" ]] && printf 'lua\t%s\n' "$path"
        done
    done
    for folder in "$DIR" "$DIR/tests" "$DIR/src/tests"; do
        [[ -d "$folder" ]] || continue
        for path in "$folder"/test-* "$folder"/test_*; do
            [[ -f "$path" ]] || continue
            name="${path##*/}"
            [[ "$name" == *.lua || "$name" == *-done || "$name" == *.md ]] && continue
            [[ "$(readlink -f "$path")" == "$self" ]] && continue
            if [[ -x "$path" || "$name" == *.sh ]]; then
                printf 'program\t%s\n' "$path"
            fi
        done
    done
    for path in "$DIR"/check-*; do
        [[ -f "$path" && -x "$path" ]] || continue
        name="${path##*/}"
        [[ "$name" == *-done ]] && continue
        printf 'program\t%s\n' "$path"
    done
}
# }}}

# {{{ run_one
# Runs a single test in the background slot it was given and records
# "<exit code> <seconds>" in <out>.status, full output in <out>.log.
run_one() {
    local kind="$1" path="$2" out="$3"
    local start end code=0
    start="$(date +%s.%N)"
    if [[ "$kind" == lua ]]; then
        timeout "$TIMEOUT" luajit "$path" >"$out.log" 2>&1 || code=$?
    elif [[ -x "$path" ]]; then
        timeout "$TIMEOUT" "$path" >"$out.log" 2>&1 || code=$?
    else
        timeout "$TIMEOUT" bash "$path" >"$out.log" 2>&1 || code=$?
    fi
    end="$(date +%s.%N)"
    if [[ $code -eq 124 ]]; then
        printf '\n[test-runner] stopped after %ss\n' "$TIMEOUT" >>"$out.log"
    fi
    printf '%s %s\n' "$code" "$(awk -v a="$start" -v b="$end" 'BEGIN{printf "%.2f", b-a}')" >"$out.status"
}
# }}}

# {{{ json_escape
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}
# }}}

# {{{ main
main() {
    parse_args "$@"

    local -a kinds=() paths=()
    local kind path
    while IFS=$'\t' read -r kind path; do
        [[ -z "$path" ]] && continue
        if [[ -n "$FILTER" && "$path" != *"$FILTER"* ]]; then
            continue
        fi
        kinds+=("$kind")
        paths+=("$path")
    done < <(discover_tests)

    if [[ ${#paths[@]} -eq 0 ]]; then
        echo "test-runner: no tests found in $DIR" >&2
        exit 2
    fi

    if $LIST_ONLY; then
        local i
        for i in "${!paths[@]}"; do
            printf '%-8s %s\n' "${kinds[$i]}" "${paths[$i]#"$DIR"/}"
        done
        exit 0
    fi

    if [[ " ${kinds[*]} " == *" lua "* ]] && ! command -v luajit >/dev/null; then
        echo "test-runner: luajit is not installed, and Lua tests are only valid under luajit" >&2
        exit 2
    fi

    # The RAM artifact tier holds every test's output. Build it first; a
    # runner that cannot write its logs has nothing to report from.
    # shellcheck source=libs/ensure-ram-tiers
    source "${RUNNER_HOME}/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR" || exit 2
    local run_dir="$DIR/tmp/shared-memory/test-runner/$(date +%Y%m%d-%H%M%S)-$$"
    mkdir -p "$run_dir"

    $QUIET || printf '%sRunning %d tests in %s, %d at a time%s\n\n' \
        "$BOLD" "${#paths[@]}" "$DIR" "$JOBS" "$NC"

    # Start every test as a background job, never more than JOBS at once.
    local i running
    for i in "${!paths[@]}"; do
        while true; do
            running="$(jobs -rp | wc -l)"
            [[ $running -lt $JOBS ]] && break
            wait -n || true
        done
        run_one "${kinds[$i]}" "${paths[$i]}" "$run_dir/$i" &
    done
    wait || true

    # Report in discovery order, so two runs of the same suite read the same.
    local passed=0 failed=0 code secs rel
    local -a failed_list=()
    local json_rows=""
    for i in "${!paths[@]}"; do
        read -r code secs <"$run_dir/$i.status"
        rel="${paths[$i]#"$DIR"/}"
        if [[ $code -eq 0 ]]; then
            passed=$((passed + 1))
            $QUIET || printf '  %sPASS%s  %6ss  %s\n' "$GREEN" "$NC" "$secs" "$rel"
            if $VERBOSE; then sed 's/^/        /' "$run_dir/$i.log"; fi
        else
            failed=$((failed + 1))
            failed_list+=("$rel")
            $QUIET || printf '  %sFAIL%s  %6ss  %s  (exit %s)\n' "$RED" "$NC" "$secs" "$rel" "$code"
            if ! $QUIET; then tail -n 15 "$run_dir/$i.log" | sed 's/^/        /'; fi
        fi
        json_rows+="${json_rows:+,}{\"test\":\"$(json_escape "$rel")\",\"exit\":$code,\"seconds\":$secs,\"log\":\"$(json_escape "$run_dir/$i.log")\"}"
    done

    printf '\n%s%d passed, %d failed%s   (full output: %s)\n' "$BOLD" "$passed" "$failed" "$NC" "$run_dir"
    for rel in "${failed_list[@]}"; do
        printf '  failed: %s\n' "$rel"
    done

    if [[ -n "$JSON_FILE" ]]; then
        printf '{"project":"%s","passed":%d,"failed":%d,"tests":[%s]}\n' \
            "$(json_escape "$DIR")" "$passed" "$failed" "$json_rows" >"$JSON_FILE"
    fi

    [[ $failed -eq 0 ]]
}
# }}}

main "$@"
