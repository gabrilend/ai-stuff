#!/bin/bash
# test-discover-projects.sh - proves discover-projects.lua picks the right
# projects for a ticket.
#
# In general terms: the script asks the shared project-discovery library
# which folders are projects and what kind each is, asks the census for each
# one's state, counts the languages each uses from the files git tracks, and
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

# -- {{{ yes_or_no
function yes_or_no() {
    if "$@" > /dev/null 2>&1; then echo yes; else echo no; fi
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

    local f="$FIXTURE" n
    mkdir -p "$f/alpha/src" "$f/alpha/issues" "$f/beta/src" "$f/beta/libs/vendored" \
             "$f/docsy/issues" "$f/docsy/output" "$f/gamma" "$f/games/g1/src" "$f/libs/src"

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

    # beta: C, with an extensionless shell script and a vendored Lua library
    # that is someone else's code.
    echo "int y;" > "$f/beta/src/x.c"
    echo "int z;" > "$f/beta/src/z.c"
    echo "#define Y" > "$f/beta/src/y.h"
    printf '#!/usr/bin/env bash\necho run\n' > "$f/beta/run"
    for n in 1 2 3 4; do echo "return $n" > "$f/beta/libs/vendored/v$n.lua"; done

    # docsy: issues and a README, no code of its own; only generated C.
    echo "# Issue 001" > "$f/docsy/issues/001-plan.md"
    echo "# docsy" > "$f/docsy/README.md"
    for n in 1 2 3 4 5; do echo "int g$n;" > "$f/docsy/output/gen$n.c"; done

    # Not projects: a vision with no marks, a shelf whose project sits one
    # level down, and top-level libs/, which is skipped by name.
    echo "an idea" > "$f/gamma/vision"
    echo "print(1)" > "$f/games/g1/src/main.lua"
    echo "int lib;" > "$f/libs/src/thing.c"

    git -C "$f" init -q
    git -C "$f" add -A
    GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" \
        git -C "$f" -c user.name=t -c user.email=t@example.invalid commit -q -m "old"
    # Recent work: beta's own source, and only generated output in docsy.
    echo "int y2;" >> "$f/beta/src/x.c"
    echo "int g9;" >> "$f/docsy/output/gen1.c"
    git -C "$f" -c user.name=t -c user.email=t@example.invalid commit -q -am "new"

    cat > "$CONF" <<'CONF'
# test profiles
[c-building]
description = C projects still being built
language = c
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
    check "the library's projects are listed" "$(same "$all" "alpha beta docsy")"
    check "the library's list is the one used (same as its own scan)" \
        "$(same "$all" "$(luajit "$DIR/scripts/libs/project-discovery.lua" scan "$FIXTURE" | cut -f2 | tr '\n' ' ' | sed 's/ $//')")"
    check "a folder with no project marks is not a project" "$(lacks_line "$all" "gamma")"
    check "top-level libs/ is skipped by name" "$(lacks_line "$all" "libs")"
    check "--paths prints absolute paths" \
        "$(has_line "$(discover --paths)" "$FIXTURE/beta")"
}
# }}}

# -- {{{ test_classification
function test_classification() {
    local table json
    table=$(discover --table)
    check "the table gives alpha's kind, state, files and issues" \
        "$(yes_or_no grep -Eq '^alpha +tracked +lua +3 +0/1 done' <<< "$table")"
    check "the table gives beta's kind as c" \
        "$(yes_or_no grep -Eq '^beta +building +c +4 ' <<< "$table")"
    check "a project with no code of its own has kind unknown and no files" \
        "$(yes_or_no grep -Eq '^docsy +tracked +unknown +0 ' <<< "$table")"

    json=$(discover --json)
    check "the symbolic link to a file is not counted twice (alpha: lua 2)" \
        "$(has_line "$json" '"languages": { "c": 1, "lua": 2 }')"
    check "an extensionless script is read by its #! line (beta: shell 1)" \
        "$(has_line "$json" '"languages": { "c": 3, "shell": 1 }')"
    check "vendored libs/ inside a project are not its own code" \
        "$(lacks_line "$(grep '"name": "beta"' <<< "$json")" '"lua"')"
    check "generated output/ is not counted (docsy: none)" \
        "$(has_line "$(grep '"name": "docsy"' <<< "$json")" '"languages": {  }')"
    check "the JSON carries the library's score" \
        "$(has_line "$(grep '"name": "alpha"' <<< "$json")" '"score": 115')"
    check "the JSON gives the count" "$(has_line "$json" '"count": 3,')"
}
# }}}

# -- {{{ test_filters
function test_filters() {
    check "--language=c picks the C project" "$(same "$(names --language=c)" "beta")"
    check "--language=lua,c picks both" "$(same "$(names --language=lua,c)" "alpha beta")"
    check "--language=unknown picks the project with no code" \
        "$(same "$(names --language=unknown)" "docsy")"
    check "--uses=shell picks the project with a script" "$(same "$(names --uses=shell)" "beta")"
    check "--uses=c includes a project whose kind is not c" \
        "$(same "$(names --uses=c)" "alpha beta")"
    check "--state=tracked picks the issue-tracked projects" \
        "$(same "$(names --state=tracked)" "alpha docsy")"
    check "--has=Makefile picks the project holding one" \
        "$(same "$(names --has=Makefile)" "alpha")"
    check "two --has must both hold" \
        "$(same "$(names --has=src --has=run)" "beta")"
    check "--active-days=30 picks the project changed recently" \
        "$(same "$(names --active-days=30)" "beta")"
    check "changing only generated output does not make a project active" \
        "$(lacks_line "$(names --active-days=30)" "docsy")"
    check "--only and --exclude combine" \
        "$(same "$(names --only=alpha,docsy --exclude=docsy)" "alpha")"
    check "filters combine (all must match)" \
        "$(same "$(names --uses=lua --state=tracked)" "alpha")"
    check "no match exits 1" "$(status_is 1 --language=rust)"
    check "a match exits 0" "$(status_is 0 --language=c)"
}
# }}}

# -- {{{ test_profiles
function test_profiles() {
    check "--list-profiles lists each profile with its description" \
        "$(has_line "$(discover --list-profiles)" "C projects still being built")"
    check "a profile applies its filters" \
        "$(same "$(names --profile=c-building)" "beta")"
    check "a command-line list replaces the profile's" \
        "$(same "$(names --profile=c-building --language=lua,c --state=tracked,building)" "alpha beta")"
    check "a command-line --has adds to the profile's" \
        "$(same "$(names --profile=with-make --has=issues)" "alpha")"
    check "an unknown profile is an error (2)" "$(status_is 2 --profile=nope)"
    check "the shipped configuration's profiles all load" \
        "$(yes_or_no luajit "$TOOL" --dir="$FIXTURE" --list-profiles)"
    check "the shipped profiles use only kinds the library knows" \
        "$(yes_or_no luajit "$TOOL" --dir="$FIXTURE" --profile=shell-scripts)"
}
# }}}

# -- {{{ test_errors
function test_errors() {
    check "an unknown option is an error (2)" "$(status_is 2 --sideways)"
    check "a kind the library does not name is an error (2)" "$(status_is 2 --language=lau)"
    check "an old language name outside the library's vocabulary is an error (2)" \
        "$(status_is 2 --uses=bash)"
    check "an unknown state is an error (2)" "$(status_is 2 --state=done)"
    check "--only naming no project is an error (2)" "$(status_is 2 --only=alpah)"
    check "--active-days must be a number (2)" "$(status_is 2 --active-days=soon)"
    check "--has may not climb out of the project (2)" "$(status_is 2 --has=../beta)"
    printf '[bad]\ncolour = red\n' > "$SCRATCH/bad.conf"
    luajit "$TOOL" --dir="$FIXTURE" --config="$SCRATCH/bad.conf" --profile=bad > /dev/null 2>&1
    check "a configuration with an unknown key is an error (2)" "$(same "$?" 2)"
    luajit "$TOOL" --dir="$SCRATCH" --config="$CONF" > /dev/null 2>&1
    check "a folder that is not a repository is an error (2)" "$(same "$?" 2)"
}
# }}}

# -- {{{ main
function main() {
    if [ ! -f "$TOOL" ]; then
        echo "discover-projects.lua not found at $TOOL" >&2
        exit 2
    fi
    if [ ! -f "$DIR/scripts/libs/project-discovery.lua" ]; then
        echo "the shared library scripts/libs/project-discovery.lua is missing" >&2
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
