#!/usr/bin/env bash
# test-menu-screen.sh -- drives a small real menu in a pretend terminal and
# checks what it drew.  (neocities-modernization issue 10-070.)
#
# Pins two things the owner saw go wrong in run.sh's menu:
#   - A label with box characters (└─) drew as unreadable glyphs when the
#     line was highlighted or dimmed: the screen stored one BYTE per cell, and
#     a styled cell is sent with a colour code in front, which cut each
#     three-byte character apart.
#   - An option disabled by a rule marked "skip" is passed over by up/down
#     (a per-stage "force" option while "force all" is on).
#
# How: `script` gives the menu a real terminal (sized with stty), keys are
# typed on a timer, the session is recorded, and test-menu-screen-replay.lua
# rebuilds the final screen from the recording.
#
# Needs `script` (util-linux) and luajit.  Takes about 20 seconds.
# Usage: bash scripts/libs/test-menu-screen.sh [libs-dir]

LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
if [ -n "${1:-}" ]; then
    LIBS_DIR="$1"
fi
WORK="$(mktemp -d /tmp/test-menu-screen-XXXXXX)"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ the menu under test
# A stand-in for run.sh's stage list: a global switch, a stage, its per-stage
# option (disabled with "skip" while the switch is on), the next stage.
cat > "$WORK/menu.sh" <<EOF
#!/usr/bin/env bash
LIBS_DIR="$LIBS_DIR"
source "\$LIBS_DIR/lua-menu.sh"
menu_init
menu_set_title "Screen test" "keys are typed by the test"
menu_add_section "stages" "multi" "Stages"
menu_add_item "stages" "all" "Force ALL" "checkbox" "0" "switch" "" "--all"
menu_add_item "stages" "one" "1. First" "checkbox" "1" "first stage" "" "--one"
menu_add_item "stages" "one_force" "    └─ Force regenerate" "checkbox" "0" "per stage" "" "--one-force"
menu_add_item "stages" "two" "2. Second" "checkbox" "1" "second stage" "" "--two"
menu_add_dependency "one_force" "all" "1" "true" "Disabled: all is on" "orange" "skip"
menu_run
EOF
chmod +x "$WORK/menu.sh"
# }}}

# {{{ run_menu <name> <keys...>
# Types each key one second apart after the menu has had time to draw, then
# q to leave; prints the replayed final screen.
run_menu() {
    local name="$1"; shift
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep 1; done
        printf 'q'; sleep 1
    } | timeout 20 script -qfc "stty rows 30 cols 100; $WORK/menu.sh" "$WORK/$name.log" >/dev/null 2>&1
    luajit "$LIBS_DIR/test-menu-screen-replay.lua" "$WORK/$name.log" 30 100 > "$WORK/$name.screen"
}
# }}}

# The cursor line starts with ">" right after the item number column.
cursor_line() { grep -m1 '>' "$WORK/$1.screen" | sed 's/.*>//'; }

# {{{ highlighted box characters stay whole
run_menu highlight j j     # Force ALL -> 1. First -> the └─ option
check "cursor is on the per-stage option" "$(cursor_line highlight)" "[ ]     └─ Force regenerate"
check "no character cut apart by a colour code" \
    "$(LC_ALL=C grep -a -c $'\xe2\x1b\|\xe2\x94\x1b' "$WORK/highlight.log")" "0"
# }}}

# {{{ a disabled option marked "skip" is passed over
run_menu skip ' ' j j      # turn Force ALL on, then down twice
check "down skips the disabled option: cursor on 2. Second" "$(cursor_line skip)" "[*] 2. Second"
check "the dimmed option still draws its box characters" \
    "$(grep -c '\[o\]     └─ Force regenerate' "$WORK/skip.screen")" "1"
# }}}

rm -rf "$WORK"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
