#!/bin/bash
# test-discover-projects.sh - proves discover-projects.lua picks the right
# projects for a ticket.
#
# In general terms: the script asks the census which directories are
# projects, works out what each is written in from the files git tracks, and
# filters them. This test builds a small monorepo in a RAM scratch folder,
# with a vendored library, generated output, a symbolic link to a pipe and a
# history with one recent commit, and checks every filter, profile and error
# against it. Exercises issue 018.
#
# Usage: test-discover-projects.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/discover-projects.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/discover-projects-test"

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

# -- {{{ same
function same() {
    # Answers yes when the two texts are identical.
    if [ "$1" = "$2" ]; then echo yes; else echo no; fi
}
# }}}

# -- {{{ has_line
function has_line() {
    # Answers yes when the text holds the fixed string.
    if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi
}
# }}}

# -- {{{ lacks_line
function lacks_line() {
    if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi
}
# }}}

# -- {{{ status_is
function status_is() {
    # Runs the tool and answers yes when it exits with the given status.
    local want="$1"; shift
    timeout 30 luajit "$TOOL" --dir="$FIXTURE" --config="$CONF" "$@" > /dev/null 2>&1
    same "$?" "$want"
}
# }}}

# -- {{{ discover
function discover() {
    timeout 30 luajit "$TOOL" --dir="$FIXTURE" --config="$CONF" "$@" 2> /dev/null
}
# }}}

# -- {{{ names
function names() {
    # The chosen names on one line, for comparing.
    discover "$@" | tr '\n' ' ' | sed 's/ $//'
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    FIXTURE="$SCRATCH/monorepo"
    CONF="$SCRATCH/discovery.conf"

    local f="$FIXTURE"
    mkdir -p "$f/delta-version" "$f/alpha/src" "$f/alpha/issues" \
             "$f/beta/src" "$f/beta/libs/vendored" "$f/gamma" \
             "$f/games/g1/output" "$f/libs"

    # alpha: Lua with one C file, issue-tracked, a Makefile, a symbolic link
    # to one of its own files (must not count twice) and one to a pipe
    # (must not be opened: reading it would wait forever).
    echo "return 1" > "$f/alpha/src/a.lua"
    echo "return 2" > "$f/alpha/src/b.lua"
    echo "int x;" > "$f/alpha/src/c.c"
    echo "# Issue 001" > "$f/alpha/issues/001-first.md"
    echo "all:" > "$f/alpha/Makefile"
    ln -s src/a.lua "$f/alpha/alias.lua"
    mkfifo "$SCRATCH/pipe"
    ln -s "$SCRATCH/pipe" "$f/alpha/pipe"

    # beta: C, with an extensionless bash script and a vendored Lua library
    # that is someone else's code.
    echo "int y;" > "$f/beta/src/x.c"
    echo "int z;" > "$f/beta/src/z.c"
    echo "#define Y" > "$f/beta/src/y.h"
    printf '#!/usr/bin/env bash\necho run\n' > "$f/beta/run"
    local n
    for n in 1 2 3 4; do echo "return $n" > "$f/beta/libs/vendored/v$n.lua"; done

    # gamma: only a vision document.
    echo "an idea" > "$f/gamma/vision"

    # games/g1: one Lua file of its own, and generated C under output/.
    echo "print(1)" > "$f/games/g1/main.lua"
    for n in 1 2 3 4 5; do echo "int g$n;" > "$f/games/g1/output/gen$n.c"; done

    # libs/ at the top is furniture, not a project.
    echo "int lib;" > "$f/libs/thing.c"

    git -C "$f" init -q
    git -C "$f" add -A
    GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" \
        git -C "$f" -c user.name=t -c user.email=t@example.invalid commit -q -m "old"
    # Recent work: beta's own source, and only generated output in games/g1.
    echo "int y2;" >> "$f/beta/src/x.c"
    echo "int g9;" >> "$f/games/g1/output/gen1.c"
    git -C "$f" -c user.name=t -c user.email=t@example.invalid commit -q -am "new"

    cat > "$CONF" <<'CONF'
# test profiles
[lua-building]
description = Lua projects still being built
language = lua
state = building

[with-make]
has = Makefile
CONF
}
# }}}

# -- {{{ test_discovery
function test_discovery() {
    local all
    all=$(names)
    check "every project is listed, shelf projects by full path" \
        "$(same "$all" "alpha beta delta-version games/g1 gamma")"
    check "top-level libs/ is furniture, not a project" "$(lacks_line "$all" "libs")"
    check "--paths prints absolute paths" \
        "$(has_line "$(discover --paths)" "$FIXTURE/games/g1")"
}
# }}}

# -- {{{ test_classification
function test_classification() {
    local table json
    table=$(discover --table)
    check "the table names alpha's dominant language as lua" \
        "$(yes_or_no grep -Eq '^alpha +tracked +lua +3 +0/1 done' <<< "$table")"
    check "the table names beta's dominant language as c" \
        "$(yes_or_no grep -Eq '^beta +building +c +4 ' <<< "$table")"
    check "a vision-only project has no language" \
        "$(yes_or_no grep -Eq '^gamma +vision +none +0 ' <<< "$table")"

    json=$(discover --json)
    check "the symbolic link to a file is not counted twice (alpha: lua 2)" \
        "$(has_line "$json" '"languages": { "c": 1, "lua": 2 }')"
    check "an extensionless script is read by its #! line (beta: bash 1)" \
        "$(has_line "$json" '"languages": { "bash": 1, "c": 3 }')"
    check "vendored libs/ inside a project are not its own code" \
        "$(lacks_line "$(grep '"name": "beta"' <<< "$json")" '"lua"')"
    check "generated output/ is not counted (games/g1: lua 1 only)" \
        "$(has_line "$json" '"languages": { "lua": 1 }')"
    check "the JSON gives the count" "$(has_line "$json" '"count": 5,')"
}
# }}}

# -- {{{ yes_or_no
function yes_or_no() {
    if "$@" > /dev/null 2>&1; then echo yes; else echo no; fi
}
# }}}

# -- {{{ test_filters
function test_filters() {
    check "--language=c picks beta" "$(same "$(names --language=c)" "beta")"
    check "--language=lua,c picks alpha, beta and games/g1" \
        "$(same "$(names --language=lua,c)" "alpha beta games/g1")"
    check "--uses=bash picks the project with a script" "$(same "$(names --uses=bash)" "beta")"
    check "--uses=c includes a project where C is not dominant" \
        "$(same "$(names --uses=c)" "alpha beta")"
    check "--state=tracked picks the issue-tracked project" \
        "$(same "$(names --state=tracked)" "alpha")"
    check "--has=Makefile picks the project holding one" \
        "$(same "$(names --has=Makefile)" "alpha")"
    check "two --has must both hold" \
        "$(same "$(names --has=src --has=run)" "beta")"
    check "--active-days=30 picks the project changed recently" \
        "$(same "$(names --active-days=30)" "beta")"
    check "changing only generated output does not make a project active" \
        "$(lacks_line "$(names --active-days=30)" "games/g1")"
    check "--only and --exclude combine" \
        "$(same "$(names --only=alpha,gamma --exclude=gamma)" "alpha")"
    check "filters combine (all must match)" \
        "$(same "$(names --uses=lua --state=building)" "games/g1")"
    check "no match exits 1" "$(status_is 1 --language=rust)"
    check "a match exits 0" "$(status_is 0 --language=c)"
}
# }}}

# -- {{{ test_profiles
function test_profiles() {
    check "--list-profiles lists each profile with its description" \
        "$(has_line "$(discover --list-profiles)" "Lua projects still being built")"
    check "a profile applies its filters" \
        "$(same "$(names --profile=lua-building)" "games/g1")"
    check "a command-line list replaces the profile's" \
        "$(same "$(names --profile=lua-building --state=tracked,building)" "alpha games/g1")"
    check "a command-line --has adds to the profile's" \
        "$(same "$(names --profile=with-make --has=issues)" "alpha")"
    check "an unknown profile is an error (2)" "$(status_is 2 --profile=nope)"
    check "the shipped configuration's profiles all load" \
        "$(yes_or_no luajit "$TOOL" --dir="$FIXTURE" --list-profiles)"
}
# }}}

# -- {{{ test_errors
function test_errors() {
    check "an unknown option is an error (2)" "$(status_is 2 --sideways)"
    check "an unknown language is an error (2)" "$(status_is 2 --language=lau)"
    check "an unknown state is an error (2)" "$(status_is 2 --state=done)"
    check "--only naming no project is an error (2)" "$(status_is 2 --only=alpah)"
    check "--active-days must be a number (2)" "$(status_is 2 --active-days=soon)"
    check "--has may not climb out of the project (2)" "$(status_is 2 --has=../beta)"
    printf '[bad]\ncolour = red\n' > "$SCRATCH/bad.conf"
    luajit "$TOOL" --dir="$FIXTURE" --config="$SCRATCH/bad.conf" --profile=bad > /dev/null 2>&1
    check "a configuration with an unknown key is an error (2)" "$(same "$?" 2)"
    luajit "$TOOL" --dir="$SCRATCH" --config="$CONF" > /dev/null 2>&1
    check "a folder that is not a monorepo is an error (2)" "$(same "$?" 2)"
}
# }}}

# -- {{{ main
function main() {
    if [ ! -f "$TOOL" ]; then
        echo "discover-projects.lua not found at $TOOL" >&2
        exit 2
    fi
    build_fixture
    echo "discover-projects.lua"
    test_discovery
    test_classification
    test_filters
    test_profiles
    test_errors
    rm -rf "$SCRATCH"
    echo ""
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
