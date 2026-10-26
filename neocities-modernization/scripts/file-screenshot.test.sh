#!/usr/bin/env bash
# file-screenshot.test.sh -- pictures are filed in order with notes that say
# what changed between them.
#
# Builds a small git project in RAM with one source file and a config.lua,
# files a picture, edits the source and a setting, files another, and checks
# the numbers (001, 002), the copies, the notes' sections, and that the
# second notes file names the edited source file and the setting's line
# before and after.
#
# Usage:  scripts/file-screenshot.test.sh [DIR]
DIR="${1:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
TOOL="$DIR/scripts/file-screenshot"
P="$DIR/tmp/shared-memory/file-screenshot-test"
passed=0
failed=0
# {{{ check
check() {
    if [ "$2" = "$3" ]; then passed=$((passed + 1)); echo "  ok   $1"
    else failed=$((failed + 1)); echo "  FAIL $1 -- got [$2] want [$3]"; fi
}
# }}}
rm -rf "$P"
mkdir -p "$P/src"
echo 'print("one")' > "$P/src/a.lua"
printf 'return {\n    size = 80,\n}\n' > "$P/config.lua"
printf 'picture' > "$P/shot.png"
git -C "$P" init -q
git -C "$P" add src/a.lua config.lua
git -C "$P" -c user.email=t@t -c user.name=t commit -q -m first

out=$("$TOOL" "$P" "$P/shot.png" first-look --made-by "a test")
check "the first picture is 001" "$(basename "$out")" "001-first-look.png"
check "it is copied" "$(cat "$P/development-history/001-first-look.png")" "picture"
check "its notes say how it was made" "$(grep -c '^- How: a test$' "$P/development-history/001-first-look.info.md")" "1"
check "its notes have the sections a person writes" \
    "$(grep -c '^## What it shows$\|^## The story so far$' "$P/development-history/001-first-look.info.md")" "2"

echo 'print("two")' > "$P/src/a.lua"
printf 'return {\n    size = 84,\n}\n' > "$P/config.lua"
out=$("$TOOL" "$P" "$P/shot.png" second-look)
N2="$P/development-history/002-second-look.info.md"
check "the next picture is 002" "$(basename "$out")" "002-second-look.png"
check "its notes name the changed source file" "$(grep -c 'changed src/a.lua' "$N2")" "1"
check "and the setting before" "$(grep -c '^-     size = 80,$' "$N2")" "1"
check "and after" "$(grep -c '^+     size = 84,$' "$N2")" "1"
check "a bad name is refused" "$("$TOOL" "$P" "$P/shot.png" 'bad name' >/dev/null 2>&1; echo $?)" "1"

rm -rf "$P"
echo
echo "passed $passed, failed $failed"
[ "$failed" = 0 ]
