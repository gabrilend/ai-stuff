#!/usr/bin/env bash
# test-lua-menu-multistate.sh
# Checks that lua-menu.sh hands a multistate item its list of states, so the
# Lua menu has something to cycle through (issue 058). Before, the list was
# always sent empty: the item showed "<[]>" and h/l/space did nothing useful.
#
# Two ways of giving the states are accepted, and both are checked:
#   menu.sh's      value "text,json,yaml:json"
#   the README's   value "info", description "debug,info,warn"
# The first half reads what menu_add_item stored; the second types keys into
# a real menu in a pretend terminal (`script`) and reads back the values the
# menu returned.
#
# Usage: bash test-lua-menu-multistate.sh [scripts-dir]

SCRIPTS_DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    SCRIPTS_DIR="$1"
fi
SCRIPTS_DIR="$(cd "$SCRIPTS_DIR" && pwd)"
LIBS_DIR="$SCRIPTS_DIR/libs"

mkdir -p /tmp/claude-1000
T="$(mktemp -d /tmp/claude-1000/lua-menu-multistate.XXXXXX)"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ what menu_add_item stores
stored() { # stored <value> <description> -> "default|states"
    bash -c '
        source "$1/lua-menu.sh"
        menu_init
        menu_add_section s multi S
        menu_add_item s it Item multistate "$2" "$3"
        printf "%s|%s\n" "${MENU_VALUES[it]}" "${MENU_ITEM_CONFIGS[it]}"
    ' _ "$LIBS_DIR" "$1" "$2"
}
echo "what menu_add_item stores"
check "menu.sh form: states and default" "$(stored "text,json,yaml:json" "Format")" "json|text,json,yaml"
check "menu.sh form without a default: the first state" "$(stored "x,y,z" "Pick one")" "x|x,y,z"
check "README form: states from the description" "$(stored "info" "debug,info,warn")" "info|debug,info,warn"
check "README form needs the value among the states" "$(stored "trace" "debug,info,warn")" "trace|trace"
check "an ordinary description is not taken for states" "$(stored "solo" "one thing, then another")" "solo|solo"
check "a single state cycles onto itself" "$(stored "solo" "")" "solo|solo"
check "the states reach the menu's JSON" \
    "$(bash -c 'source "$1/lua-menu.sh"; menu_init; menu_add_section s multi S
                menu_add_item s it Item multistate "a,b:b" "d"; _menu_build_json' _ "$LIBS_DIR" \
       | grep -o '"config":"a,b"' | head -1)" '"config":"a,b"'
# }}}

# {{{ the menu itself
cat > "$T/menu.sh" <<EOF
#!/usr/bin/env bash
source "$LIBS_DIR/lua-menu.sh"
menu_init
menu_set_title "Multistate test" "keys are typed by the test"
menu_add_section "opts" "multi" "Options"
menu_add_item "opts" "format" "Format" "multistate" "text,json,yaml:json" "Output format"
menu_add_item "opts" "level" "Level" "multistate" "info" "debug,info,warn"
menu_add_section "actions" "single" "Actions"
menu_add_item "actions" "run" "Run" "action" "" "Run it" "r"
if menu_run; then
    echo "format=\$(menu_get_value format) level=\$(menu_get_value level)" > "$T/values"
else
    echo "quit" > "$T/values"
fi
EOF
chmod +x "$T/menu.sh"

run_menu() { # run_menu <name> <keys...>
    local name="$1"; shift
    rm -f "$T/values"
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep 1; done
        sleep 2
    } | timeout 30 script -qfc "stty rows 30 cols 100; $T/menu.sh" "$T/$name.log" >/dev/null 2>&1
    cat "$T/values" 2>/dev/null
}

if command -v script >/dev/null && command -v luajit >/dev/null; then
    echo "the menu"
    check "untouched, each item keeps its default" "$(run_menu plain r r)" "format=json level=info"
    check "l cycles forward" "$(run_menu forward l r r)" "format=yaml level=info"
    check "l past the last state wraps to the first" "$(run_menu wrap l l r r)" "format=text level=info"
    check "h cycles backward, README form too" "$(run_menu back j h r r)" "format=json level=debug"
    check "space cycles like l" "$(run_menu space j ' ' ' ' r r)" "format=json level=debug"
else
    echo "the menu: not run here, needs script and luajit"
fi
# }}}

[ -n "${KEEP:-}" ] && echo "kept $T" || rm -rf "$T"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
