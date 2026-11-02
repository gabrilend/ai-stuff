#!/bin/bash
# ticket-menu.sh - a menu for filing ticket templates into projects.
#
# Issue 020. The menu front end of the ticket distribution chain: pick a
# template, tick the projects, choose the phase, preview, then distribute.
# Every step is done by distribute-ticket.lua (issue 019); this script only
# builds its command line from the menu and asks before anything is written.
# The menu is the shared Lua menu (scripts/libs/lua-menu.sh), the one the
# house is moving its bash tools to.
#
# What the menu offers:
#   Template      one of the .md files in the templates folder; the preview
#                 panel shows the highlighted one
#   Projects      the projects discover-projects.lua lists; tick any number
#   Filing        the phase (0 = each project's current phase), whether to
#                 give a project without issues/ one, whether to file again
#                 where the template already was
#   Do            Preview (dry run), Distribute (dry run, then a yes/no
#                 before writing), History (the ledger, one line per
#                 distribution), Undo the last distribution (dry run, then a
#                 yes/no before removing)
#
# Usage: ticket-menu.sh [--dir MONOREPO] [--templates FOLDER] [--ledger FILE]
#   --templates   default delta-version/templates/tickets/
#   --ledger      default delta-version/assets/ticket-distributions.tsv
#
# Nothing is written without a "y" typed after the dry run is shown.

# {{{ DIR Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/distribute-ticket.lua"
DISCOVER="$SCRIPT_DIR/discover-projects.lua"
TEMPLATES="$SCRIPT_DIR/../templates/tickets"
LEDGER="$SCRIPT_DIR/../assets/ticket-distributions.tsv"
LIBS_DIR="$SCRIPT_DIR/../../scripts/libs"
# }}}

# The menu library is loaded here, at the top level: its tables are declared
# with declare -A, which inside a function would make them local to it.
# shellcheck source=../../scripts/libs/lua-menu.sh
source "$LIBS_DIR/lua-menu.sh" || exit 2

# The menu's lists, by item number.
TEMPLATE_PATHS=()
PROJECT_NAMES=()
ACTIONS=(preview distribute history undo)

# -- {{{ ticket_menu_build
function ticket_menu_build() {
    # Fills the menu from the templates folder and the project list.
    # Returns 2 when there is no template or no project to offer.
    TEMPLATE_PATHS=()
    PROJECT_NAMES=()
    local path name index

    for path in "$TEMPLATES"/*.md; do
        [ -f "$path" ] && TEMPLATE_PATHS+=("$path")
    done
    if [ ${#TEMPLATE_PATHS[@]} -eq 0 ]; then
        echo "ticket-menu: no templates (*.md) in $TEMPLATES" >&2
        return 2
    fi
    mapfile -t PROJECT_NAMES < <(luajit "$DISCOVER" --dir="$DIR" --names 2>/dev/null)
    if [ ${#PROJECT_NAMES[@]} -eq 0 ]; then
        echo "ticket-menu: discover-projects.lua found no projects under $DIR" >&2
        return 2
    fi

    menu_init
    menu_set_title "Ticket Distribution" "File one template into many projects"

    menu_add_section "template" "single" "Template"
    for index in "${!TEMPLATE_PATHS[@]}"; do
        path="${TEMPLATE_PATHS[$index]}"
        menu_add_item "template" "t$index" "$(basename "$path" .md)" "checkbox" \
            "$([ "$index" -eq 0 ] && echo 1 || echo 0)" "Use this template"
        menu_set_item_filepath "t$index" "$path"
    done

    menu_add_section "projects" "list" "Projects"
    menu_set_section_max_visible "projects" 12
    for index in "${!PROJECT_NAMES[@]}"; do
        name="${PROJECT_NAMES[$index]}"
        menu_add_item "projects" "p$index" "$name" "checkbox" "0" "File the ticket in $name"
    done

    menu_add_section "filing" "multi" "Filing"
    menu_add_item "filing" "phase" "Phase (0 = current)" "flag" "0:2" \
        "0 files into each project's lowest phase with open issues; a number files into that phase"
    menu_add_item "filing" "create_issues" "Give projects issues/" "checkbox" "0" \
        "A project with no issues/ folder gets one; otherwise it is skipped"
    menu_add_item "filing" "again" "File again" "checkbox" "0" \
        "File it even where this template was already filed"

    menu_add_section "do" "single" "Do"
    menu_add_item "do" "preview" "Preview" "checkbox" "1" "Show what each project would get; write nothing"
    menu_add_item "do" "distribute" "Distribute" "checkbox" "0" "Preview, then write after you type y"
    menu_add_item "do" "history" "History" "checkbox" "0" "List past distributions from the ledger"
    menu_add_item "do" "undo" "Undo last" "checkbox" "0" \
        "Remove the last distribution's unedited tickets, after you type y"

    menu_add_section "go" "single" "Run"
    menu_add_item "go" "run" "Go" "action" "" "Do the chosen step" "x"
    return 0
}
# }}}

# -- {{{ ticket_menu_choice
function ticket_menu_choice() {
    # The ticked step under "Do".
    local action
    for action in "${ACTIONS[@]}"; do
        if [ "$(menu_get_value "$action")" = "1" ]; then echo "$action"; return; fi
    done
    echo preview
}
# }}}

# -- {{{ ticket_menu_args
function ticket_menu_args() {
    # distribute-ticket.lua's arguments for the menu's choices, one per line.
    # Returns 1, with a reason on stderr, when no template or project is ticked.
    local index template="" projects="" phase
    for index in "${!TEMPLATE_PATHS[@]}"; do
        [ "$(menu_get_value "t$index")" = "1" ] && template="${TEMPLATE_PATHS[$index]}"
    done
    for index in "${!PROJECT_NAMES[@]}"; do
        if [ "$(menu_get_value "p$index")" = "1" ]; then
            projects="${projects:+$projects,}${PROJECT_NAMES[$index]}"
        fi
    done
    if [ -z "$template" ]; then echo "ticket-menu: tick a template" >&2; return 1; fi
    if [ -z "$projects" ]; then echo "ticket-menu: tick at least one project" >&2; return 1; fi

    phase="$(menu_get_value phase)"
    phase="${phase:-0}"
    phase=$((10#$phase))
    [ "$phase" -eq 0 ] && phase=current

    echo "$template"
    echo "--phase=$phase"
    echo "--projects=$projects"
    [ "$(menu_get_value create_issues)" = "1" ] && echo "--create-issues"
    [ "$(menu_get_value again)" = "1" ] && echo "--again"
    echo "--dir=$DIR"
    echo "--ledger=$LEDGER"
}
# }}}

# -- {{{ confirm
function confirm() {
    # Answers yes only to y or yes typed on standard input.
    local answer
    read -r -p "$1 [y/N] " answer || return 1
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}
# }}}

# -- {{{ ticket_menu_history
function ticket_menu_history() {
    # One line per distribution: its id, date, template and ticket counts.
    if [ ! -f "$LEDGER" ]; then
        echo "No distributions yet ($LEDGER does not exist)."
        return 0
    fi
    awk -F'\t' 'NR > 1 {
        if (!($2 in seen)) { seen[$2] = 1; order[++n] = $2; date[$2] = $1; template[$2] = $3 }
        if ($7 == "written") written[$2]++
        if ($7 == "undone") undone[$2]++
    }
    END {
        if (n == 0) { print "No distributions yet."; exit }
        for (i = 1; i <= n; i++) {
            d = order[i]
            printf "%-20s %s  %-28s %d written, %d undone\n", d, date[d], template[d], written[d], undone[d]
        }
    }' "$LEDGER"
}
# }}}

# -- {{{ last_distribution
function last_distribution() {
    # The newest distribution in the ledger with a ticket not yet undone.
    [ -f "$LEDGER" ] || return 1
    awk -F'\t' 'NR > 1 {
        key = $2 FS $4 FS $5
        if ($7 == "written") { live[key] = 1; dist[key] = $2; order[++n] = key }
        if ($7 == "undone") delete live[key]
    }
    END { for (i = n; i >= 1; i--) if (order[i] in live) { print dist[order[i]]; exit } }' "$LEDGER"
}
# }}}

# -- {{{ ticket_menu_act
function ticket_menu_act() {
    # Does the ticked step. Returns the tool's exit status (0, 1 or 2), or 1
    # when the menu's choices are incomplete or the answer was no.
    local action args code dist
    action="$(ticket_menu_choice)"
    case "$action" in
        history)
            ticket_menu_history
            return 0 ;;
        undo)
            dist="$(last_distribution)"
            if [ -z "$dist" ]; then echo "Nothing to undo."; return 1; fi
            luajit "$TOOL" --undo="$dist" --dir="$DIR" --ledger="$LEDGER"
            code=$?
            [ "$code" -eq 2 ] && return 2
            confirm "Remove these tickets?" || { echo "Nothing removed."; return 1; }
            luajit "$TOOL" --undo="$dist" --write --dir="$DIR" --ledger="$LEDGER"
            return $? ;;
    esac

    mapfile -t args < <(ticket_menu_args)
    [ ${#args[@]} -eq 0 ] && return 1
    luajit "$TOOL" "${args[@]}"
    code=$?
    [ "$action" = "preview" ] && return "$code"
    [ "$code" -eq 2 ] && return 2

    # Distribute: the dry run above is what the yes is for.
    confirm "Write these tickets?" || { echo "Nothing written."; return 1; }
    luajit "$TOOL" "${args[@]}" --write
}
# }}}

# -- {{{ parse_arguments
function parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dir) DIR="$2"; shift 2 ;;
            --templates) TEMPLATES="$2"; shift 2 ;;
            --ledger) LEDGER="$2"; shift 2 ;;
            -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
            *) echo "ticket-menu: unknown argument $1 (see --help)" >&2; exit 2 ;;
        esac
    done
}
# }}}

# -- {{{ main
function main() {
    parse_arguments "$@"
    ticket_menu_build || exit 2
    while menu_run; do
        echo
        ticket_menu_act
        echo
        read -r -p "Enter returns to the menu, q quits: " again || break
        [ "$again" = "q" ] && break
    done
}
# }}}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
