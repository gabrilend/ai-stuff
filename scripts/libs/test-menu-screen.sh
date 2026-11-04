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
#   - The bash menu (menu.sh) keeps every item on its own row after the
#     cursor moves (scripts issue 004): its footer used to end the screen's
#     last row with a newline, which scrolled the screen up one row, so each
#     incremental update landed one row below the item it redrew.
#   - A bash menu taller than the screen scrolls inside its own box (scripts
#     round-3 viewport): the header and footer stay put, the list shows a
#     window around the cursor, and a scrollbar in the last column says where
#     the window is. Checked at 40 rows with 40 items in two sections.
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

# {{{ the bash menu (issue 004)
# The pure-bash menu.sh, used where LuaJIT is missing: four items, nothing else.
cat > "$WORK/bash-menu.sh" <<EOF
#!/usr/bin/env bash
LIBS_DIR="$LIBS_DIR"
for lib in tui checkbox multistate input menu; do source "\$LIBS_DIR/\$lib.sh"; done
tui_init
menu_init
menu_set_title "Bash menu test" "keys are typed by the test"
menu_add_section "letters" "multi" "Letters"
menu_add_item "letters" "a" "Alpha" "checkbox" "0" "first"
menu_add_item "letters" "b" "Bravo" "checkbox" "0" "second"
menu_add_item "letters" "c" "Charlie" "checkbox" "0" "third"
menu_add_item "letters" "d" "Delta" "checkbox" "0" "fourth"
menu_run
tui_cleanup
EOF
chmod +x "$WORK/bash-menu.sh"

# A bash menu taller than its screen: 30 letters and 10 numbers, 46 lines of
# list in all, shown at 40 rows where the list has 28 rows to draw in.
{
    printf '#!/usr/bin/env bash\nLIBS_DIR="%s"\n' "$LIBS_DIR"
    printf 'for lib in tui checkbox multistate input menu; do source "$LIBS_DIR/$lib.sh"; done\n'
    printf 'tui_init\nmenu_init\nmenu_set_title "Bash tall menu" "keys are typed by the test"\n'
    printf 'menu_add_section "letters" "multi" "Letters"\n'
    for i in $(seq -w 1 30); do
        printf 'menu_add_item "letters" "l%s" "L%s" "checkbox" "0" "letter %s"\n' "$i" "$i" "$i"
    done
    printf 'menu_add_section "numbers" "multi" "Numbers"\n'
    for i in $(seq -w 1 10); do
        printf 'menu_add_item "numbers" "n%s" "N%s" "checkbox" "0" "number %s"\n' "$i" "$i" "$i"
    done
    printf 'menu_run\ntui_cleanup\n'
} > "$WORK/bash-tall.sh"
chmod +x "$WORK/bash-tall.sh"
# }}}

# {{{ run_menu <name> <keys...>
# Types each key KEY_DELAY seconds apart (default one) after the menu has had
# time to draw, then q to leave; prints the replayed final screen. The pretend
# terminal is ROWS rows tall (default 30) and 100 columns wide.
run_menu() {
    local name="$1"; shift
    local script_file="$WORK/menu.sh"
    case "$name" in
        radio*) script_file="$WORK/radio.sh" ;;
        bash-tall*) script_file="$WORK/bash-tall.sh" ;;
        bash*) script_file="$WORK/bash-menu.sh" ;;
    esac
    local rows="${ROWS:-30}"
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep "${KEY_DELAY:-1}"; done
        printf 'q'; sleep 1
    } | timeout 40 script -qfc "stty rows $rows cols 100; $script_file" "$WORK/$name.log" >/dev/null 2>&1
    luajit "$LIBS_DIR/test-menu-screen-replay.lua" "$WORK/$name.log" "$rows" 100 > "$WORK/$name.screen"
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

# {{{ the bash menu keeps items in place (issue 004)
# The item lines, as the screen shows them; the replay scrolls the way a
# terminal does, so a screen that scrolled under the menu shows here as items
# written over their neighbours.
items_of() { grep -E '^[0-9]( |▸)\[' "$WORK/$1.screen" | sed 's/\[[^]]*\] //'; }
run_menu bash-down j j
check "after two moves each item is drawn once, in order, the cursor on the third" \
    "$(items_of bash-down | tr '\n' '|')" "1 Alpha|2 Bravo|3▸Charlie|4 Delta|"
run_menu bash-updown j j k
check "and moving back up redraws them in place" \
    "$(items_of bash-updown | tr '\n' '|')" "1 Alpha|2▸Bravo|3 Charlie|4 Delta|"
# }}}

# {{{ a bash menu taller than the screen scrolls inside its box
# The list window is the rows between the header's ╠ line and the
# description's ── line; at 40 rows it has 28. `script` adds a trailer that
# scrolls the finished screen up, so everything is found relative to those
# lines rather than by row number.
body_of()    { awk '/^╠/ && !on && !done { on = 1; next } on && /^─/ { on = 0; done = 1 } on' "$WORK/$1.screen"; }
tall_items() { body_of "$1" | grep -E '^[0-9*]( |▸)\[' | grep -oE '[LN][0-9]{2}' | tr '\n' ' ' | sed 's/ $//'; }
tall_cursor(){ body_of "$1" | grep '▸' | grep -oE '[LN][0-9]{2}'; }
bar_end()    { # bar_end <name> <body row>: the scrollbar character ending that row
    local line; line="$(body_of "$1" | sed -n "$2p" | sed 's/ *$//')"
    case "$line" in *█) printf '█' ;; *│) printf '│' ;; *) printf '?' ;; esac
}
letters() { local i out=""; for i in $(seq -w "$1" "$2"); do out="$out L$i"; done; printf '%s' "${out# }"; }
numbers() { local i out=""; for i in $(seq -w "$1" "$2"); do out="$out N$i"; done; printf '%s' "${out# }"; }

ROWS=40 run_menu bash-tall-start
check "a tall menu draws its list in a 28-row window at 40 rows" \
    "$(body_of bash-tall-start | wc -l)" "28"
check "the window opens on the first 26 letters, cursor on the first" \
    "$(tall_items bash-tall-start)|$(tall_cursor bash-tall-start)" "$(letters 01 26)|L01"
check "the section title is in the window" \
    "$(body_of bash-tall-start | grep -c '^  Letters')" "1"
check "the description and the footer follow the window, in that order" \
    "$(grep -nE '^  letter 01|\[q\] Quit' "$WORK/bash-tall-start.screen" | cut -d: -f2- | grep -oE 'letter 01|Quit' | tr '\n' ' ')" "letter 01 Quit "
check "the scrollbar's thumb is at the top: first row █, last row │" \
    "$(bar_end bash-tall-start 1)$(bar_end bash-tall-start 28)" "█│"

ROWS=40 KEY_DELAY=0.2 run_menu bash-tall-step j j j j j j j j j j j j j j j j j j j j j j j j j j
check "stepping past the last row scrolls one line: L01-L27, cursor on L27" \
    "$(tall_items bash-tall-step)|$(tall_cursor bash-tall-step)" "$(letters 01 27)|L27"

ROWS=40 run_menu bash-tall-bottom G
check "G scrolls to the end: L16-L30 then the numbers, cursor on N10" \
    "$(tall_items bash-tall-bottom)|$(tall_cursor bash-tall-bottom)" "$(letters 16 30) $(numbers 01 10)|N10"
check "the second section's title is in the window" \
    "$(body_of bash-tall-bottom | grep -c '^  Numbers')" "1"
check "the scrollbar's thumb is at the bottom: first row │, last row █" \
    "$(bar_end bash-tall-bottom 1)$(bar_end bash-tall-bottom 28)" "│█"

ROWS=40 run_menu bash-tall-top G g
check "g scrolls back to the top, title and all" \
    "$(tall_items bash-tall-top)|$(tall_cursor bash-tall-top)|$(body_of bash-tall-top | grep -c '^  Letters')" \
    "$(letters 01 26)|L01|1"

check "a menu that fits draws no scrollbar" \
    "$(grep -cE '(█|│) *$' "$WORK/bash-down.screen")" "0"
# }}}

rm -rf "$WORK"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
