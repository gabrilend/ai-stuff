#!/usr/bin/env bash
# test-menu-screen.sh -- drives a small real menu in a pretend terminal and
# checks what it drew.  (neocities-modernization issue 10-070.)
#
# Pins two things the owner saw go wrong in run.sh's menu, and the select
# item's dropdown (scripts issue 017):
#   - A label with box characters (└─) drew as unreadable glyphs when the
#     line was highlighted or dimmed: the screen stored one BYTE per cell, and
#     a styled cell is sent with a colour code in front, which cut each
#     three-byte character apart.
#   - An option disabled by a rule marked "skip" is passed over by up/down
#     (a per-stage "force" option while "force all" is on).
#   - A select item shows its choice closed, opens into a box of options on
#     space, keeps j/k inside the box while open, chooses on space, keeps
#     its value on escape, refuses a disabled option with its reason, jumps
#     by first letter, cycles with h/l when closed, reaches the command
#     preview, fetches a dynamic list when opened, scrolls a long list, and
#     opens upward when there is no room below.
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

# A radio list (one choice) with nothing chosen, like run.sh's embedding
# model and inference server lists.
cat > "$WORK/radio.sh" <<EOF
#!/usr/bin/env bash
LIBS_DIR="$LIBS_DIR"
source "\$LIBS_DIR/lua-menu.sh"
menu_init
menu_set_title "Radio test" "keys are typed by the test"
menu_add_section "model" "single" "Model"
menu_add_item "model" "m1" "alpha" "checkbox" "0" "first" "" "--model alpha"
menu_add_item "model" "m2" "bravo" "checkbox" "0" "second" "" "--model bravo"
menu_add_item "model" "m3" "charlie" "checkbox" "0" "third" "" "--model charlie"
menu_add_item "model" "m4" "delta" "checkbox" "0" "fourth" "" "--model delta"
menu_run
EOF
chmod +x "$WORK/radio.sh"

# {{{ the select menus (issue 017)
# A fixed list with a disabled option, a list fetched by a command, and a
# command preview; the chosen values are written out after the menu ends.
cat > "$WORK/select.sh" <<EOF
#!/usr/bin/env bash
LIBS_DIR="$LIBS_DIR"
source "\$LIBS_DIR/lua-menu.sh"
menu_init
menu_set_title "Select test" "keys are typed by the test"
menu_add_section "settings" "multi" "Settings"
menu_add_item "settings" "server" "Server" "select" "" "which server" "" "--server"
menu_set_item_options "server" "gpu|GPU Server|the card in the tower" "alt|GPU Server Alt|the second card" \\
    "local|Local|this machine" "off|Offline||switched off for the night"
menu_add_item "settings" "after" "After" "checkbox" "0" "the next item" "" "--after"
menu_add_item "settings" "pick" "Pick" "select_dynamic" "" "a fetched list" "" "--pick"
menu_set_item_options_command "pick" "printf 'one|One\\ntwo|Two\\n'"
menu_add_section "preview" "multi" "Command"
menu_add_item "preview" "cmd" "" "text" "" "the command"
menu_set_command_config "./run.sh" "cmd"
menu_run
printf '%s %s\\n' "\${MENU_VALUES[server]}" "\${MENU_VALUES[pick]:-unset}" > "$WORK/\${VALUES_NAME:-values}"
EOF
chmod +x "$WORK/select.sh"

# Fifteen options, and a select below fifteen checkboxes (no room under it).
cat > "$WORK/long.sh" <<EOF
#!/usr/bin/env bash
LIBS_DIR="$LIBS_DIR"
source "\$LIBS_DIR/lua-menu.sh"
menu_init
menu_set_title "Long test" "keys are typed by the test"
menu_add_section "many" "multi" "Many"
for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15; do
    menu_add_item "many" "box\$n" "box \$n" "checkbox" "0" "" "" "--box\$n"
done
menu_add_item "many" "num" "Number" "select" "" "a long list" "" "--num"
menu_set_item_options "num" n01 n02 n03 n04 n05 n06 n07 n08 n09 n10 n11 n12 n13 n14 n15
menu_run
printf '%s\\n' "\${MENU_VALUES[num]}" > "$WORK/\${VALUES_NAME:-values}"
EOF
chmod +x "$WORK/long.sh"
# }}}

# {{{ run_menu <name> <keys...>
# Types each key KEY_DELAY seconds apart (default one) after the menu has had
# time to draw, then q to leave; prints the replayed final screen. A select
# menu is left with ctrl+c, which quits without drawing again, so the screen
# is the one the last key drew, an open dropdown included (q would close it
# first). The menu script is chosen by the name's first word: radio, select,
# long, else the stage menu.
run_menu() {
    local name="$1"; shift
    local script_file="$WORK/menu.sh" quit="q"
    case "$name" in
        radio*) script_file="$WORK/radio.sh" ;;
        select*) script_file="$WORK/select.sh"; quit=$'\003' ;;
        long*) script_file="$WORK/long.sh"; quit=$'\003' ;;
    esac
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep "${KEY_DELAY:-1}"; done
        printf '%s' "$quit"; sleep 1
    } | timeout 30 script -qfc "stty rows 30 cols 100; VALUES_NAME=$name.values $script_file" "$WORK/$name.log" >/dev/null 2>&1
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

# {{{ radio list with nothing chosen: l chooses the entry under the cursor
# The chosen entry draws as (*), the others as ( ).
chosen() { grep -o '(\*) [a-z]*' "$WORK/$1.screen" | sed 's/(\*) //' | tr '\n' ' ' | sed 's/ $//'; }
run_menu radio-l j j j l     # cursor to delta, then l
check "l on an empty radio list chooses the entry under the cursor" "$(chosen radio-l)" "delta"
run_menu radio-h j h         # cursor to bravo, then h
check "h on an empty radio list chooses nothing" "$(chosen radio-h)" ""
run_menu radio-lj j l l      # choose bravo with l, then l again steps on
check "once chosen, l steps to the next entry" "$(chosen radio-lj)" "charlie"
# }}}

# {{{ select items (issue 017)
ESC=$'\033'
values() { cat "$WORK/$1.values" 2>/dev/null; }
# Keys come faster here; the menu reads each one whole either way.
KEY_DELAY=0.6

run_menu select-closed
check "a fixed list starts on its first option, shown closed" \
    "$(grep -c 'Server: \[GPU Server ▼\]' "$WORK/select-closed.screen")" "1"
check "an unopened dynamic list shows (none)" "$(grep -c 'Pick: \[(none) ▼\]' "$WORK/select-closed.screen")" "1"
check "the command preview carries the first option" "$(grep -c '\./run\.sh --server gpu' "$WORK/select-closed.screen")" "1"

run_menu select-open ' '
check "space opens a box under the item" "$(grep -c 'Server: ┌' "$WORK/select-open.screen")" "1"
check "the chosen option is marked" "$(grep -c '│ ● GPU Server  ' "$WORK/select-open.screen")" "1"
check "every option is listed" "$(grep -cE '│   (GPU Server Alt|Local|Offline) ' "$WORK/select-open.screen")" "3"
check "the option under the cursor is described" "$(grep -c 'the card in the tower' "$WORK/select-open.screen")" "1"
check "the box is drawn over the rows below the item" "$(grep -c 'After │ ● GPU Server ' "$WORK/select-open.screen")" "1"

run_menu select-choose ' ' j ' '
check "j moves inside the box, space chooses" "$(values select-choose)" "alt unset"
check "the closed item shows the new choice" "$(grep -c 'Server: \[GPU Server Alt ▼\]' "$WORK/select-choose.screen")" "1"
check "the command preview follows" "$(grep -c '\./run\.sh --server alt' "$WORK/select-choose.screen")" "1"

run_menu select-cancel ' ' j "$ESC"
check "escape closes the box and keeps the value" "$(values select-cancel)" "gpu unset"
check "after escape the box is gone" "$(grep -c '┌' "$WORK/select-cancel.screen")" "0"

run_menu select-disabled ' ' j j j ' '
check "a disabled option is refused" "$(values select-disabled)" "gpu unset"
check "with its reason" "$(grep -c 'Unavailable: switched off for the night' "$WORK/select-disabled.screen")" "1"
check "and the box stays open" "$(grep -c 'Server: ┌' "$WORK/select-disabled.screen")" "1"

run_menu select-jump ' ' L ' '
check "a letter jumps to the option starting with it" "$(values select-jump)" "local unset"
run_menu select-jump-g ' ' j g ' '
check "g is a jump letter inside the box, not go-to-top" "$(values select-jump-g)" "gpu unset"

run_menu select-cycle l l l
check "l on a closed item cycles, passing over the disabled option" "$(values select-cycle)" "gpu unset"
run_menu select-cycle-back h
check "h cycles backwards, passing over the disabled option" "$(values select-cycle-back)" "local unset"

run_menu select-dynamic j j ' ' j ' '
check "a dynamic list is fetched when opened and chosen from" "$(values select-dynamic)" "gpu two"
check "the closed item shows the fetched label" "$(grep -c 'Pick: \[Two ▼\]' "$WORK/select-dynamic.screen")" "1"

KEY_DELAY=0.3
run_menu long-scroll G ' ' j j j j j j j j j j j j
check "a long list opens upward when there is no room below" "$(grep -c 'Number: └' "$WORK/long-scroll.screen")" "1"
check "it shows ten options at a time" "$(grep -cE '│ [ ●] n[0-9]{2} ' "$WORK/long-scroll.screen")" "10"
check "scrolled to keep the cursor in view" "$(grep -cE '│   n13 ' "$WORK/long-scroll.screen")" "1"
check "the first option has scrolled out" "$(grep -cE '│ ● n01 ' "$WORK/long-scroll.screen")" "0"
check "a scrollbar in the box's right border" "$(grep -cE '│ [ ●] n[0-9]{2} [█░]' "$WORK/long-scroll.screen")" "10"
check "its thumb is part of it, not all" "$(grep -cE 'n[0-9]{2} █' "$WORK/long-scroll.screen")" "6"
run_menu long-choose G ' ' j j j j j j j j j j j j ' '
check "and the option scrolled to is chosen" "$(values long-choose)" "n13"
KEY_DELAY=1
# }}}

rm -rf "$WORK"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
