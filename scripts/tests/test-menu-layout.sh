#!/usr/bin/env bash
# test-menu-layout.sh -- runs small real menus in a pretend terminal and
# checks where the header, the preview and the footer land (issue 059: the
# menu's hand-placed layout moves onto tui panels).
#
# The point being pinned: the body (sections, description, preview) runs
# right down to the footer's top line.  Before, the description stopped
# three rows above the screen's bottom whatever the footer's height, so a
# menu without a shortcuts line (a 2-row footer) lost a row of preview, and
# the last preview line never reached the footer.
#
# How: `script` gives the menu a real terminal (sized with stty), q is typed
# to leave, the session is recorded, and libs/test-menu-screen-replay.lua
# rebuilds the final screen from the recording.
#
# Needs `script` (util-linux) and luajit.  Takes about 10 seconds.
# Usage: bash scripts/tests/test-menu-layout.sh [scripts-dir]

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
LIBS_DIR="$DIR/libs"
ROWS=24
COLS=80
WORK="$(mktemp -d /tmp/test-menu-layout-XXXXXX)"

pass=0; fail=0
# {{{ check
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

# A preview file far longer than the screen, one numbered line each.
for i in $(seq 1 100); do echo "preview line $i"; done > "$WORK/long.txt"

# {{{ write_menu <name> <with-shortcut: 0|1>
# One section of two items; the first shows long.txt as its preview.  With
# a shortcut key on the second item the footer gains its shortcuts line.
write_menu() {
    local name="$1" shortcut=""
    [ "$2" = "1" ] && shortcut="r"
    cat > "$WORK/$name.sh" <<MENU
#!/usr/bin/env bash
LIBS_DIR="$LIBS_DIR"
source "\$LIBS_DIR/lua-menu.sh"
menu_init
menu_set_title "Layout test" "the preview should reach the footer"
menu_add_section "files" "multi" "Files"
menu_add_item "files" "long" "long.txt" "checkbox" "0" "a long file" "" ""
menu_add_item "files" "other" "Run" "action" "" "does nothing" "$shortcut" ""
menu_set_item_filepath "long" "$WORK/long.txt"
menu_add_content_source "item_file" "Preview" ""
menu_run
MENU
    chmod +x "$WORK/$name.sh"
}
# }}}

# {{{ run_menu <name>
# Lets the menu draw, types q, and prints the replayed final screen into
# $WORK/<name>.screen.
run_menu() {
    local name="$1"
    { sleep 2; printf 'q'; sleep 1; } |
        timeout 15 script -qfc "stty rows $ROWS cols $COLS; $WORK/$name.sh" "$WORK/$name.log" >/dev/null 2>&1
    luajit "$LIBS_DIR/test-menu-screen-replay.lua" "$WORK/$name.log" "$ROWS" "$COLS" all > "$WORK/$name.screen"
}
# }}}

# {{{ screen helpers
# line <name> <n>: screen row n.  row_of <name> <regex>: last row matching.
line() { sed -n "${2}p" "$WORK/$1.screen"; }
row_of() { grep -n -E "$2" "$WORK/$1.screen" | tail -1 | cut -d: -f1; }
# The footer's separator is the last ╠ line on the screen.
footer_top() { row_of "$1" '^╠'; }
# }}}

# {{{ without a shortcuts line: 2-row footer
write_menu plain 0
run_menu plain
check "plain: title drawn on row 2" "$(line plain 2 | grep -c 'Layout test')" "1"
check "plain: header separator on row 4" "$(line plain 4 | cut -c1-3)" "╠"
check "plain: footer separator on row $((ROWS-1))" "$(footer_top plain)" "$((ROWS-1))"
check "plain: help line on the last row" "$(line plain "$ROWS" | grep -c 'j/k:nav')" "1"
last=$(row_of plain 'preview line [0-9]+')
check "plain: last preview line sits right above the footer" "$last" "$(( $(footer_top plain) - 1 ))"
# }}}

# {{{ with a shortcuts line: 3-row footer
write_menu shortcut 1
run_menu shortcut
check "shortcut: footer separator on row $((ROWS-2))" "$(footer_top shortcut)" "$((ROWS-2))"
check "shortcut: help line on row $((ROWS-1))" "$(line shortcut "$((ROWS-1))" | grep -c 'j/k:nav')" "1"
check "shortcut: shortcuts line on the last row" "$(line shortcut "$ROWS" | grep -c 'r:run')" "1"
last=$(row_of shortcut 'preview line [0-9]+')
check "shortcut: last preview line sits right above the footer" "$last" "$(( $(footer_top shortcut) - 1 ))"
# }}}

[ -n "${KEEP:-}" ] && echo "kept $WORK" || rm -rf "${WORK:?}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
