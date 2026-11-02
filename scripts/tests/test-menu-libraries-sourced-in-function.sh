#!/usr/bin/env bash
#
# test-menu-libraries-sourced-in-function.sh - proves the menu libraries keep
# their tables when they are sourced from inside a function.
#
# In plain terms: bash makes every "declare" inside a function local to that
# function, and a file sourced from a function runs inside it. So a library
# whose tables are made with plain "declare -A" loses them the moment the
# function that sourced it returns; the next "TABLE[name]=x" then makes an
# ordinary indexed array where every name counts as 0, and all entries land on
# top of each other. delta-version met this with lua-menu.sh. The libraries
# now use "declare -gA" / "declare -ga", which always make the global table.
#
# This test sources each library from inside a function, in a fresh bash, and
# checks that every table the library declares at its top level is still there
# afterwards with the right kind (the list is read from the library itself, so
# a table added later is covered too). Then it builds a two-section menu with
# lua-menu.sh and with menu.sh the same way and checks that the titles and
# items stay apart.
#
# Usage:
#   tests/test-menu-libraries-sourced-in-function.sh [scripts-dir]

DIR="/mnt/mtwo/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

LIBS="${DIR}/libs"
PASSED=0
FAILED=0

# {{{ pass / fail / check
pass() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }
check() {
    local description="$1"
    shift
    if "$@"; then pass "${description}"; else fail "${description}"; fi
}
# }}}

# {{{ tables_of
# Prints "<flag> <name>" for each table a library declares at its top level,
# flag being a or A, whether written "declare -A" or "declare -gA".
tables_of() {
    sed -nE 's/^declare -g?([aA])[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1 \2/p' "$1"
}
# }}}

# {{{ kept_after_function
# kept_after_function <library> <flag> <name>: in a fresh bash, source the
# library from inside a function, return, and check the table is still there
# and of the right kind.
kept_after_function() {
    local library="$1" flag="$2" name="$3" said
    said="$(bash -c '
        load() { source "$1" >/dev/null 2>&1; }
        load "$1"
        declare -p "$2" 2>/dev/null
    ' _ "${library}" "${name}")"
    [[ "${said}" == "declare -${flag}"*" ${name}"* ]] \
        || { printf '        (%s after return: %s)\n' "${name}" "${said:-gone}"; return 1; }
}
# }}}

printf '\nEvery top-level table survives the function that sourced it\n'
for library in lua-menu.sh menu.sh checkbox.sh multistate.sh; do
    count=0
    while read -r flag name; do
        count=$((count + 1))
        check "${library}: ${name} is still a -${flag} table" \
            kept_after_function "${LIBS}/${library}" "${flag}" "${name}"
    done < <(tables_of "${LIBS}/${library}")
    check "${library}: declares at least one table (the list was read)" test "${count}" -gt 0
done

printf '\nA lua-menu.sh menu built after a function sourced it\n'
json="$(bash -c '
    load() { source "$1/lua-menu.sh"; }
    load "$1"
    menu_init
    menu_set_title "Demo"
    menu_add_section opts single "Options"
    menu_add_item opts alpha "Alpha" checkbox 1 "first"
    menu_add_section more multi "More things"
    menu_add_item more bravo "Bravo" checkbox 0 "second"
    _menu_build_json
' _ "${LIBS}" 2>&1)"
check "no item is refused as a duplicate" \
    bash -c '! grep -q "Duplicate item_id" <<<"$1"' _ "${json}"
check "the first section keeps its own title" \
    bash -c 'grep -q "\"id\":\"opts\",\"title\":\"Options\"" <<<"$1"' _ "${json}"
check "the second section keeps its own title" \
    bash -c 'grep -q "\"id\":\"more\",\"title\":\"More things\"" <<<"$1"' _ "${json}"
check "both items reach the menu" \
    bash -c 'grep -q "\"Alpha\"" <<<"$1" && grep -q "\"Bravo\"" <<<"$1"' _ "${json}"

printf '\nA menu.sh menu built after a function sourced it\n'
said="$(bash -c '
    load() { source "$1/menu.sh"; }
    load "$1"
    menu_init
    menu_add_section opts single "Options"
    menu_add_item opts alpha "Alpha" checkbox
    menu_add_section more multi "More things"
    menu_add_item more bravo "Bravo" checkbox
    printf "%s|%s|%s|%s\n" "${MENU_SECTION_TITLES[opts]}" "${MENU_SECTION_TITLES[more]}" \
        "${MENU_SECTION_ITEMS[opts]}" "${MENU_SECTION_ITEMS[more]}"
' _ "${LIBS}" 2>&1 | tail -1)"
check "titles and items stay with their own sections" \
    test "${said}" = "Options|More things|alpha|bravo"

printf '\n%d passed, %d failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
