#!/usr/bin/env bash
# test-vision-viewer.sh
# Checks vision-viewer (issue 005a) and sync-visions.sh's -I hand-off
# against a pretend monorepo in a scratch folder.  The menu checks type keys
# into a pretend terminal with `script` and read the screen back with
# libs/test-menu-screen-replay.lua; $PAGER is cat so the chosen document
# lands in the output.
#
# Usage: bash test-vision-viewer.sh [scripts-dir]

SCRIPTS_DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    SCRIPTS_DIR="$1"
fi
SCRIPTS_DIR="$(cd "$SCRIPTS_DIR" && pwd)"
VIEWER="$SCRIPTS_DIR/vision-viewer"
SYNC="$SCRIPTS_DIR/sync-visions.sh"

mkdir -p /tmp/claude-1000
T="$(mktemp -d /tmp/claude-1000/vision-viewer.XXXXXX)"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
has() { # has <label> <file> <fixed text>
    if grep -qF -- "$3" "$2"; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: [$3] not in $2"; tail -15 "$2" | sed 's/^/        /'; fi
}

# {{{ the pretend monorepo
M="$T/mono"
mkdir -p "$M/alpha/notes" "$M/beta" "$M/games/gamma/notes" "$M/delta/notes"
printf 'Alpha builds bridges.\nIt likes rivers.\n' > "$M/alpha/notes/vision"
printf 'Beta grows gardens.\n' > "$M/beta/vision.md"
printf 'Gamma plays games about RIVERS.\n' > "$M/games/gamma/notes/vision"
printf 'Delta, second thoughts.\n' > "$M/delta/notes/vision-second"
OUT="$T/visions"
# }}}

echo "sync-visions.sh makes the links the viewer reads"
DIR= bash "$SYNC" -q -o "$OUT" "$M" > "$T/sync.out" 2>&1
check "sync exits 0" "$?" "0"
check "one link per document" "$(ls "$OUT" | tr '\n' ' ')" "alpha beta delta-second games-gamma "

echo "a folder given without -o gets its own scripts/visions"
mkdir -p "$M/scripts"
DIR= bash "$SYNC" -q "$M" > "$T/sync2.out" 2>&1
check "links land under the named monorepo" "$(ls "$M/scripts/visions" 2>/dev/null | wc -l | tr -d ' ')" "4"

echo "headless"
bash "$VIEWER" --visions "$OUT" > "$T/list.out" 2>&1
check "no options lists them" "$(tr '\n' ' ' < "$T/list.out")" "alpha beta delta-second games-gamma "
bash "$VIEWER" --view beta --visions "$OUT" > "$T/view.out" 2>&1
check "--view prints the document" "$(cat "$T/view.out")" "Beta grows gardens."
bash "$VIEWER" -v game --visions "$OUT" > "$T/prefix.out" 2>&1
check "the start of a name is enough when only one name starts so" "$(cat "$T/prefix.out")" "Gamma plays games about RIVERS."
mkdir -p "$T/two"; ln -s "$M/alpha/notes/vision" "$T/two/alpha"; ln -s "$M/beta/vision.md" "$T/two/alphabet"
bash "$VIEWER" -v alp --visions "$T/two" > "$T/ambig.out" 2>&1
check "two names starting so is an error" "$?" "1"
has "and both are named" "$T/ambig.out" "could be any of: alpha alphabet"
bash "$VIEWER" -v alpha --visions "$T/two" > "$T/exact.out" 2>&1
check "an exact name wins over a longer one" "$(head -1 "$T/exact.out")" "Alpha builds bridges."
bash "$VIEWER" -v zeta --visions "$OUT" > "$T/none.out" 2>&1
check "an unknown name is an error" "$?" "1"
bash "$VIEWER" -s rivers --visions "$OUT" > "$T/search.out" 2>&1
check "--search finds the documents with the word, any case" "$(tr '\n' ' ' < "$T/search.out")" "alpha games-gamma "
bash "$VIEWER" -s volcano --visions "$OUT" > "$T/nosearch.out" 2>&1
check "a search that finds nothing exits 1" "$?" "1"
bash "$VIEWER" --visions "$T/nowhere" > "$T/nofolder.out" 2>&1
check "a missing folder is an error" "$?" "1"
has "that says to run sync-visions.sh" "$T/nofolder.out" "run sync-visions.sh first"
ln -s "$T/gone" "$OUT/zz-gone"
bash "$VIEWER" --visions "$OUT" > "$T/dangling.out" 2> "$T/dangling.err"
check "a broken link is left out of the list" "$(tr '\n' ' ' < "$T/dangling.out")" "alpha beta delta-second games-gamma "
has "and reported" "$T/dangling.err" "zz-gone points at"
rm "$OUT/zz-gone"
bash "$VIEWER" --bogus > "$T/bogus.out" 2>&1
check "an unknown option is an error" "$?" "1"

# {{{ the menu
# run_menu <name> <command> -- <keys...>
run_menu() {
    local name="$1" cmd="$2"; shift 3
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep 1; done
        sleep 2
    } | timeout 30 script -qfc "stty rows 40 cols 120; PAGER=cat $cmd > '$T/$name.out' 2>&1; echo \$? > '$T/$name.rc'" "$T/$name.log" >/dev/null 2>&1
    luajit "$SCRIPTS_DIR/libs/test-menu-screen-replay.lua" "$T/$name.log" 40 120 > "$T/$name.screen"
}

if command -v script >/dev/null && command -v luajit >/dev/null; then
    echo "the menu"
    # Down to the second entry, choose it with l, then v jumps to View and
    # v again views.
    run_menu pick "bash '$VIEWER' -I --visions '$OUT'" -- j l v v
    check "menu exits 0" "$(cat "$T/pick.rc")" "0"
    check "the chosen document is paged" "$(cat "$T/pick.out")" "Beta grows gardens."

    run_menu quit "bash '$VIEWER' -I --visions '$OUT'" -- q
    check "quitting exits 0" "$(cat "$T/quit.rc")" "0"
    check "and pages nothing" "$(cat "$T/quit.out")" ""
    has "the highlighted document shows below the list" "$T/quit.screen" "Alpha builds bridges."

    run_menu search "bash '$VIEWER' -I -s rivers --visions '$OUT'" -- q
    has "-I with --search shows only the matches" "$T/search.screen" "2 containing \"rivers\""

    rm -rf "$OUT"
    run_menu sync "DIR= bash '$SYNC' -q -I -o '$OUT' '$M'" -- l v v
    check "sync-visions -I syncs, then opens the viewer" "$(tail -2 "$T/sync.out")" "Alpha builds bridges.
It likes rivers."
else
    echo "the menu: not run here, needs script and luajit"
fi
# }}}

[ -n "${KEEP:-}" ] && echo "kept $T" || rm -rf "$T"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
