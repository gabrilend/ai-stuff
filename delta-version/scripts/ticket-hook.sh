#!/bin/bash
# ticket-hook.sh - what the ticket post-commit hook runs (issue 022).
#
# When a commit adds or changes a ticket template in
# delta-version/templates/tickets/, this previews distributing it: for each
# such template that config/ticket-hooks.conf gives targets for, it runs
# distribute-ticket.lua as a dry run and prints the command that would file
# the tickets. It writes only when the configuration says "write = on",
# which is off as shipped. A template with no line in the configuration is
# named and left alone.
#
# It never stops a commit: a post-commit hook runs after the commit is made,
# and this script always exits 0 when run as the hook. Run it by hand with
# --check to get a real exit status (1 when the configuration has a problem).
#
# Usage: ticket-hook.sh [--commit REV] [--dir MONOREPO] [--config FILE] [--check]
#   --commit   the commit to look at (default HEAD)
#   --dir      the monorepo (default: the git top level of the current folder)
#   --config   default delta-version/config/ticket-hooks.conf
#   --check    only read the configuration and report on it

# {{{ DIR Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/distribute-ticket.lua"
CONFIG="${TICKET_HOOK_CONFIG:-$SCRIPT_DIR/../config/ticket-hooks.conf}"
TEMPLATE_FOLDER="delta-version/templates/tickets"
DIR=""
COMMIT="HEAD"
CHECK_ONLY=no
# }}}

# Options a configuration line may give; the hook itself decides --write,
# --dir, --ledger, --again and --undo.
ALLOWED_OPTIONS=" --projects --profile --language --uses --state --has --active-days --only --exclude --phase --slug --error-mode --create-issues "

declare -A TARGETS=()
WRITE=off
LEDGER=""
PROBLEMS=()

# -- {{{ say
function say() { echo "ticket-hook: $*"; }
# }}}

# -- {{{ read_config
function read_config() {
    # Fills WRITE, LEDGER and TARGETS; each bad line goes into PROBLEMS.
    local line key value number=0 token option
    if [ ! -f "$CONFIG" ]; then
        PROBLEMS+=("no configuration at $CONFIG")
        return
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        number=$((number + 1))
        line="${line%%#*}"
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        if [[ ! "$line" =~ ^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*$ ]]; then
            PROBLEMS+=("line $number: not \"name = value\"")
            continue
        fi
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        case "$key" in
            write)
                if [ "$value" = on ] || [ "$value" = off ]; then WRITE="$value"
                else PROBLEMS+=("line $number: write is on or off, not \"$value\""); fi ;;
            ledger)
                LEDGER="$value" ;;
            *.md)
                if [[ "$key" == */* ]]; then
                    PROBLEMS+=("line $number: name the template file only, not a path")
                    continue
                fi
                for token in $value; do
                    option="${token%%=*}"
                    if [[ ! "$token" =~ ^--[a-z-]+(=[A-Za-z0-9_,.-]+)?$ ]] \
                        || [[ "$ALLOWED_OPTIONS" != *" $option "* ]]; then
                        PROBLEMS+=("line $number: $token is not an option the hook passes on")
                        continue 2
                    fi
                done
                if [[ " $value" != *" --phase="* ]]; then
                    PROBLEMS+=("line $number: give --phase= (a number or current)")
                    continue
                fi
                TARGETS["$key"]="$value" ;;
            *)
                PROBLEMS+=("line $number: unknown setting $key") ;;
        esac
    done < "$CONFIG"
}
# }}}

# -- {{{ changed_templates
function changed_templates() {
    # Templates the commit added or changed, as file names.
    git -C "$DIR" diff-tree --root --no-commit-id --name-only --diff-filter=AM -r "$COMMIT" \
        -- "$TEMPLATE_FOLDER" 2>/dev/null | grep '\.md$' | while read -r path; do
        [ "$(dirname "$path")" = "$TEMPLATE_FOLDER" ] && basename "$path"
    done
}
# }}}

# -- {{{ quoted_command
function quoted_command() {
    # The command as one line someone can paste.
    local word out=""
    for word in "$@"; do out+="$(printf '%q' "$word") "; done
    echo "${out% }"
}
# }}}

# -- {{{ act_on
function act_on() {
    local name="$1" args=() token
    local template="$DIR/$TEMPLATE_FOLDER/$name"
    if [ -z "${TARGETS[$name]+set}" ]; then
        say "$name changed; no targets for it in $(basename "$CONFIG"), so nothing to preview"
        return
    fi
    for token in ${TARGETS[$name]}; do args+=("$token"); done
    args+=("--dir=$DIR")
    [ -n "$LEDGER" ] && args+=("--ledger=$LEDGER")

    say "$name changed; preview of filing it:"
    luajit "$TOOL" "$template" "${args[@]}" 2>&1 | sed 's/^/    /'
    if [ "$WRITE" = on ]; then
        say "write = on, so filing it now"
        luajit "$TOOL" "$template" "${args[@]}" --write 2>&1 | sed 's/^/    /'
    else
        say "to file it, run:"
        echo "    $(quoted_command luajit "$TOOL" "$template" "${args[@]}" --write)"
    fi
}
# }}}

# -- {{{ parse_arguments
function parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --commit) COMMIT="$2"; shift 2 ;;
            --dir) DIR="$2"; shift 2 ;;
            --config) CONFIG="$2"; shift 2 ;;
            --check) CHECK_ONLY=yes; shift ;;
            -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) say "unknown argument $1 (see --help)"; exit 2 ;;
        esac
    done
    [ -n "$DIR" ] || DIR="$(git rev-parse --show-toplevel 2>/dev/null)"
}
# }}}

# -- {{{ main
function main() {
    parse_arguments "$@"
    read_config
    local problem name
    for problem in "${PROBLEMS[@]}"; do say "configuration: $problem"; done

    if [ "$CHECK_ONLY" = yes ]; then
        say "write = $WRITE; ${#TARGETS[@]} template(s) with targets"
        [ ${#PROBLEMS[@]} -eq 0 ] && exit 0 || exit 1
    fi
    [ -n "$DIR" ] || exit 0
    while read -r name; do
        [ -n "$name" ] && act_on "$name"
    done < <(changed_templates)
    exit 0
}
# }}}

main "$@"
