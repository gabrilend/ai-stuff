#!/usr/bin/env bash
# test-menu-clipboard.sh -- proves the menu's copy key cannot hang the
# script that ran the menu, and that the copy reaches both clipboards.
#
# Why: menus are run as  answer=$(luajit menu-runner.lua ...)  and a $(...)
# waits for every process holding its output pipe.  The clipboard tool stays
# running after a copy (it serves the text to whoever pastes), and it used to
# inherit that pipe, so the calling script hung after the menu closed; and
# Ctrl+C, the way out, killed the tool and the copied text with it.
# (neocities-modernization issue 10-070.)
#
# Needs a graphical session (DISPLAY or WAYLAND_DISPLAY) and xclip, xsel or
# wl-copy.  Without one it says so and fails: a skipped check is not a pass.
#
# Usage: bash scripts/libs/test-menu-clipboard.sh [libs-dir]

LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
if [ -n "${1:-}" ]; then
    LIBS_DIR="$1"
fi

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "  FAIL - no graphical session (DISPLAY/WAYLAND_DISPLAY unset); nothing to copy to"
    exit 1
fi

# {{{ read_selection <clipboard|primary>
read_selection() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null; then
        if [ "$1" = primary ]; then timeout 3 wl-paste --primary --no-newline
        else timeout 3 wl-paste --no-newline; fi
    elif command -v xclip >/dev/null; then
        timeout 3 xclip -o -selection "$1"
    else
        timeout 3 xsel --"$1" --output
    fi
}
# }}}

TEXT="menu-clipboard-test-$$"

# A stand-in for the menu screen: copy, print an answer, exit -- read the way
# lua-menu.sh reads the real one, with $(...).  That inner $(...) runs inside
# a bash that timeout ends after 10 seconds, so if the bug ever returns this
# test fails at 10 seconds instead of hanging on the same pipe it checks.
START=$(date +%s%N)
ANSWER=$(timeout 10 bash -c '
    answer=$(luajit -e "
        package.path = \"$1/?.lua;\" .. package.path
        local menu = require(\"menu\")
        local ok, err = menu.copy_to_clipboard(\"$2\")
        print(ok and \"copied\" or (\"failed: \" .. tostring(err)))
    ")
    echo "$answer"
' _ "$LIBS_DIR" "$TEXT")
ELAPSED_MS=$(( ($(date +%s%N) - START) / 1000000 ))

check "the copy reports success" "$ANSWER" "copied"
check "\$(...) returns within two seconds (took ${ELAPSED_MS} ms)" \
    "$([ "$ELAPSED_MS" -lt 2000 ] && echo yes || echo no)" "yes"
check "Ctrl+V clipboard holds the text" "$(read_selection clipboard)" "$TEXT"
check "middle-click selection holds the text" "$(read_selection primary)" "$TEXT"

echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
