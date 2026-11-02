#!/bin/bash
# test-ticket-menu.sh - proves ticket-menu.sh turns the menu's choices into
# the right distribute-ticket.lua run, and writes nothing without a yes.
#
# In general terms: the menu screen itself belongs to the shared Lua menu
# library, which has its own tests. This test loads ticket-menu.sh's
# functions without opening the screen, fills the menu from a scratch
# monorepo in a RAM folder, sets the values a person would tick, and checks
# the command line it builds, the preview, the yes/no before writing, the
# history and the undo. Exercises issue 020.
#
# Usage: test-ticket-menu.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"
MONOREPO="$DIR"

MENU="$MONOREPO/delta-version/scripts/ticket-menu.sh"
SCRATCH="$MONOREPO/delta-version/tmp/shared-memory/ticket-menu-test"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    local label="$1" ok="$2"
    if [ "$ok" = "yes" ]; then
        echo "  ok   - $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $label"
        FAIL=$((FAIL + 1))
    fi
}
# }}}

# -- {{{ same / has_line / is_file / no_file
function same() { if [ "$1" = "$2" ]; then echo yes; else echo no; fi; }
function has_line() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
function is_file() { if [ -f "$1" ]; then echo yes; else echo no; fi; }
function no_file() { if [ -e "$1" ]; then echo no; else echo yes; fi; }
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$MONOREPO/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$MONOREPO/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    FIXTURE="$SCRATCH/monorepo"

    local f="$FIXTURE"
    mkdir -p "$f/alpha/src" "$f/alpha/issues" "$f/beta/src" "$f/beta/issues" \
             "$f/nofolder/src" "$SCRATCH/templates"
    echo "return 1" > "$f/alpha/src/a.lua"
    echo "# Issue 101" > "$f/alpha/issues/101-first.md"
    echo "return 2" > "$f/beta/src/b.lua"
    echo "# Issue 201" > "$f/beta/issues/201-open.md"
    echo "int n;" > "$f/nofolder/src/n.c"
    git -C "$f" init -q
    git -C "$f" add -A
    git -C "$f" -c user.name=t -c user.email=t@example.invalid commit -q -m "fixture"

    printf '# First Template\n\nFor ][project_name[]\n' > "$SCRATCH/templates/aaa-first.md"
    printf '# Second Template\n\nAlso ][project_name[]\n' > "$SCRATCH/templates/bbb-second.md"
}
# }}}

# ticket-menu.sh's functions, with no screen. Loaded at the top level, as the
# menu library's tables must be (inside a function they would be local).
source "$MENU"

# -- {{{ load_menu
function load_menu() {
    # Points the menu's functions at the fixture.
    DIR="$FIXTURE"
    TEMPLATES="$SCRATCH/templates"
    LEDGER="$SCRATCH/ledger.tsv"
}
# }}}

# -- {{{ tick
function tick() {
    # Ticks the project with this name in the menu.
    local index
    for index in "${!PROJECT_NAMES[@]}"; do
        [ "${PROJECT_NAMES[$index]}" = "$1" ] && menu_set_value "p$index" 1
    done
}
# }}}

# -- {{{ choose
function choose() {
    # Ticks one step under "Do" (a single-choice section).
    local action
    for action in "${ACTIONS[@]}"; do menu_set_value "$action" 0; done
    menu_set_value "$1" 1
}
# }}}

# -- {{{ test_build
function test_build() {
    TEMPLATES="$SCRATCH/empty"
    mkdir -p "$TEMPLATES"
    ticket_menu_build 2> /dev/null
    check "no templates: the menu refuses to open (status 2)" "$(same "$?" 2)"

    TEMPLATES="$SCRATCH/templates"
    ticket_menu_build
    check "the menu is built" "$(same "$?" 0)"
    check "every template is offered" "$(same "${#TEMPLATE_PATHS[@]}" 2)"
    check "every project discover-projects lists is offered" \
        "$(same "${PROJECT_NAMES[*]}" "alpha beta nofolder")"
    check "the first template is ticked to begin with" "$(same "$(menu_get_value t0)" 1)"
    check "no project is ticked to begin with" "$(same "$(menu_get_value p0)$(menu_get_value p1)" 00)"
    check "the template preview shows the template file" \
        "$(same "${MENU_ITEM_FILEPATHS[t1]}" "$SCRATCH/templates/bbb-second.md")"
    check "Preview is the step ticked to begin with" "$(same "$(ticket_menu_choice)" preview)"
    check "the menu's description is JSON the screen can read (5 sections)" \
        "$(if _menu_build_json | LUA_PATH="$MONOREPO/libs/lua/?.lua;;" luajit -e '
            local ok, t = pcall(require("dkjson").decode, io.read("*a"))
            os.exit(ok and type(t) == "table" and #t.sections == 5 and 0 or 1)'; then echo yes; else echo no; fi)"
}
# }}}

# -- {{{ test_args
function test_args() {
    local args
    ticket_menu_args > /dev/null 2>&1
    check "no project ticked: no command is built" "$(same "$?" 1)"

    tick alpha
    tick beta
    args=$(ticket_menu_args)
    check "the ticked template is the first argument" \
        "$(same "$(head -1 <<< "$args")" "$SCRATCH/templates/aaa-first.md")"
    check "phase 0 means each project's current phase" "$(has_line "$args" "--phase=current")"
    check "the ticked projects are named" "$(has_line "$args" "--projects=alpha,beta")"
    check "the menu's ledger is passed on" "$(has_line "$args" "--ledger=$SCRATCH/ledger.tsv")"

    menu_set_value phase 3
    menu_set_value again 1
    menu_set_value create_issues 1
    args=$(ticket_menu_args)
    check "a phase number is passed as that phase" "$(has_line "$args" "--phase=3")"
    check "File again becomes --again" "$(has_line "$args" "--again")"
    check "Give projects issues/ becomes --create-issues" "$(has_line "$args" "--create-issues")"
    menu_set_value phase 0
    menu_set_value again 0
    menu_set_value create_issues 0
}
# }}}

# -- {{{ test_act
function test_act() {
    local out
    choose preview
    out=$(ticket_menu_act < /dev/null 2>&1)
    check "Preview shows what alpha would get" "$(has_line "$out" "would write issues/102-first-template.md")"
    check "Preview writes nothing" "$(no_file "$FIXTURE/alpha/issues/102-first-template.md")"

    choose distribute
    out=$(echo n | ticket_menu_act 2>&1)
    check "Distribute shows the dry run first" "$(has_line "$out" "would write issues/202-first-template.md")"
    check "Distribute answered n writes nothing" "$(no_file "$FIXTURE/beta/issues/202-first-template.md")"
    check "... and says so" "$(has_line "$out" "Nothing written.")"

    out=$(ticket_menu_act < /dev/null 2>&1)
    check "Distribute with no answer at all writes nothing" "$(no_file "$FIXTURE/beta/issues/202-first-template.md")"

    out=$(echo y | ticket_menu_act 2>&1)
    check "Distribute answered y writes alpha's ticket" "$(is_file "$FIXTURE/alpha/issues/102-first-template.md")"
    check "... and beta's" "$(is_file "$FIXTURE/beta/issues/202-first-template.md")"
    check "... into the menu's ledger" "$(is_file "$SCRATCH/ledger.tsv")"

    choose history
    out=$(ticket_menu_act 2>&1)
    check "History lists the distribution with its counts" \
        "$(has_line "$out" "aaa-first.md")"
    check "... 2 written, 0 undone" "$(has_line "$out" "2 written, 0 undone")"

    choose undo
    out=$(echo n | ticket_menu_act 2>&1)
    check "Undo answered n removes nothing" "$(is_file "$FIXTURE/alpha/issues/102-first-template.md")"
    out=$(echo y | ticket_menu_act 2>&1)
    check "Undo answered y removes the last distribution's tickets" \
        "$(no_file "$FIXTURE/alpha/issues/102-first-template.md")"
    choose history
    out=$(ticket_menu_act 2>&1)
    check "History then shows them undone" "$(has_line "$out" "2 written, 2 undone")"
    choose undo
    out=$(echo y | ticket_menu_act 2>&1)
    check "Undo with nothing left to undo says so" "$(has_line "$out" "Nothing to undo.")"
}
# }}}

# -- {{{ main
function main() {
    build_fixture
    load_menu
    echo "ticket-menu.sh against a scratch monorepo in $SCRATCH"
    test_build
    test_args
    test_act
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
