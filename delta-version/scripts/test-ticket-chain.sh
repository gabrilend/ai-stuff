#!/bin/bash
# test-ticket-chain.sh - the test suite for the whole ticket distribution
# chain (issues 016-020), and the checks none of its parts make alone.
#
# In general terms: each part of the chain has its own test (the keyword
# engine, project discovery, distribution, the menu). This script runs them
# all and gives one result, then adds the checks that only make sense for the
# chain as shipped:
#
#   * every keyword in config/ticket-keywords.conf fills in a real project,
#     with sample parameters for the ones that take them, and the parameter
#     keywords give the values the fixture predicts;
#   * every template in templates/tickets/ uses only usable keywords and fills
#     without a failure;
#   * a dry run across many projects (60 by default) finds every one ready
#     and stays inside a time limit.
#
# Everything runs against scratch monorepos in a RAM folder; nothing in the
# real tree is written. Exercises issue 021.
#
# Usage: test-ticket-chain.sh [--dir MONOREPO] [--projects N] [--only-chain]
#   --projects N    projects in the scale check (default 60)
#   --only-chain    skip the parts' own tests; run only the checks above

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCALE=60
PARTS=yes
while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DIR="$2"; shift 2 ;;
        --projects) SCALE="$2"; shift 2 ;;
        --only-chain) PARTS=no; shift ;;
        *) echo "usage: test-ticket-chain.sh [--dir MONOREPO] [--projects N] [--only-chain]" >&2; exit 2 ;;
    esac
done

DELTA="$DIR/delta-version"
SCRIPTS="$DELTA/scripts"
SCRATCH="$DELTA/tmp/shared-memory/ticket-chain-test"
# Seconds the scale check may take, per project.
SECONDS_PER_PROJECT=2

# The chain's own tests, in the order the chain runs.
PART_TESTS=(test-process-template.sh test-discover-projects.sh test-distribute-ticket.sh
            test-ticket-menu.sh test-ticket-hook.sh)

# Sample parameters for each keyword that takes some, and what each gives in
# the fixture project. A keyword added to the configuration without a line
# here fails the check, so the list keeps up.
declare -A SAMPLE=(
    [function_usage]="main,lua"        [file_search]="main,src,5"
    [grep_count]="return,lua"          [file_list]="lua,src"
    [recent_files]="30,lua"            [todo_count]="TODO,lua"
    [file_commits]="src/main.lua,3"    [dependency_usage]="util,lua"
)
declare -A EXPECT=(
    [function_usage]="1"               [grep_count]="3"
    [recent_files]="2"
    [todo_count]="1"                   [dependency_usage]="1"
)

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

# -- {{{ same / has_line / lacks_line
function same() { if [ "$1" = "$2" ]; then echo yes; else echo no; fi; }
function has_line() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
function lacks_line() { if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi; }
# }}}

# -- {{{ commit_all
function commit_all() {
    git -C "$1" init -q
    git -C "$1" add -A
    git -C "$1" -c user.name=t -c user.email=t@example.invalid commit -q -m "fixture"
}
# }}}

# -- {{{ build_scratch
function build_scratch() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DELTA" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")

    # One project with something for every keyword to find.
    PROJECT="$SCRATCH/sample"
    mkdir -p "$PROJECT/src" "$PROJECT/issues/completed" "$PROJECT/docs" "$PROJECT/libs"
    cat > "$PROJECT/src/main.lua" <<'LUA'
local util = require("util")
function main() return util.go() end -- TODO: arguments
LUA
    printf 'local M = {}\nfunction M.go() return 1 end\nreturn M\n' > "$PROJECT/src/util.lua"
    echo "# Sample" > "$PROJECT/README.md"
    echo "# Guide" > "$PROJECT/docs/guide.md"
    echo "# Issue 101: open" > "$PROJECT/issues/101-open.md"
    echo "# Issue 102: done" > "$PROJECT/issues/completed/102-done.md"
    commit_all "$PROJECT"
}
# }}}

# -- {{{ test_parts
function test_parts() {
    local name out code
    for name in "${PART_TESTS[@]}"; do
        # Every part takes the monorepo from DIR (their arguments differ).
        out=$(DIR="$DIR" timeout 600 bash "$SCRIPTS/$name" 2>&1)
        code=$?
        check "$name: $(tail -1 <<< "$out")" "$(same "$code" 0)"
        [ "$code" -eq 0 ] || grep -F "FAIL -" <<< "$out" | sed 's/^/        /'
    done
}
# }}}

# -- {{{ test_keywords
function test_keywords() {
    local list template line name params out err code
    list=$(luajit "$SCRIPTS/process-template.lua" --dir="$DELTA" --list 2>&1)
    check "the shipped keyword file lists its keywords" "$(has_line "$list" "][project_name[]")"

    # A template using every keyword once, one per line as "name=value".
    template="$SCRATCH/every-keyword.md"
    : > "$template"
    while read -r line; do
        name=$(sed -n 's/^\]\[\([a-z_0-9]*\)\[.*$/\1/p' <<< "$line")
        [ -z "$name" ] && continue
        if [[ "$line" == *"[p1"* ]]; then
            params="${SAMPLE[$name]}"
            check "keyword $name has sample parameters in this test" "$([ -n "$params" ] && echo yes || echo no)"
            [ -n "$params" ] && echo "$name=][$name[$params][]" >> "$template"
        else
            echo "$name=][$name[]" >> "$template"
        fi
    done < <(sed 's/^ *//' <<< "$list" | grep '^\]\[')

    out=$(luajit "$SCRIPTS/process-template.lua" "$template" "$PROJECT" --dir="$DELTA" \
          --error-mode=fail 2> "$SCRATCH/keyword-errors")
    code=$?
    err=$(cat "$SCRATCH/keyword-errors")
    check "every shipped keyword fills in a real project (fail mode, exit 0)" "$(same "$code" 0)"
    [ "$code" -eq 0 ] || sed 's/^/        /' <<< "$err"
    check "... with $(wc -l < "$template") keywords tried" \
        "$([ "$(wc -l < "$template")" -ge 50 ] && echo yes || echo no)"

    # What the parameter keywords give is predictable in the fixture.
    for name in "${!EXPECT[@]}"; do
        check "$name[${SAMPLE[$name]}] gives ${EXPECT[$name]}" \
            "$(same "$(grep "^$name=" <<< "$out" | cut -d= -f2-)" "${EXPECT[$name]}")"
    done
    check "file_list[lua,src] gives both files, comma-separated" \
        "$(same "$(grep '^file_list=' <<< "$out" | cut -d= -f2- | tr -d ' ' | tr ',' '\n' | sort | paste -sd,)" "main.lua,util.lua")"
    check "project_name is the project's folder" "$(same "$(grep '^project_name=' <<< "$out")" "project_name=sample")"
    check "file_commits names the fixture's commit" "$(has_line "$(grep -A3 '^file_commits=' <<< "$out")" "fixture")"
    check "file_search finds main in src/" "$(has_line "$(grep -A3 '^file_search=' <<< "$out")" "src/main.lua:2:")"
}
# }}}

# -- {{{ test_templates
function test_templates() {
    local template out code count=0
    for template in "$DELTA"/templates/tickets/*.md; do
        [ -f "$template" ] || continue
        count=$((count + 1))
        out=$(luajit "$SCRIPTS/process-template.lua" --dir="$DELTA" --check "$template" 2>&1)
        check "template $(basename "$template") uses only usable keywords" "$(same "$?" 0)"
        luajit "$SCRIPTS/process-template.lua" "$template" "$PROJECT" --dir="$DELTA" \
            --error-mode=fail > /dev/null 2>&1
        check "template $(basename "$template") fills without a failure" "$(same "$?" 0)"
    done
    check "templates/tickets/ holds at least one template" "$([ "$count" -gt 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_scale
function test_scale() {
    local many="$SCRATCH/many" n name out code start took limit
    for n in $(seq -w 1 "$SCALE"); do
        name="project-$n"
        mkdir -p "$many/$name/src" "$many/$name/issues"
        echo "return $n" > "$many/$name/src/main.lua"
        echo "# Issue 101: first" > "$many/$name/issues/101-first.md"
    done
    commit_all "$many"
    printf '# Scale Check\n\n][project_name[] has ][lua_files[] Lua files.\n' > "$SCRATCH/scale.md"

    start=$(date +%s)
    out=$(timeout 900 luajit "$SCRIPTS/distribute-ticket.lua" "$SCRATCH/scale.md" --phase=current \
          --language=lua --dir="$many" --ledger="$SCRATCH/scale-ledger.tsv" 2>&1)
    code=$?
    took=$(( $(date +%s) - start ))
    limit=$(( SCALE * SECONDS_PER_PROJECT ))
    check "a dry run across $SCALE projects finds all ready" \
        "$(has_line "$out" "$SCALE project(s) chosen, $SCALE ready, 0 skipped")"
    check "... and exits 0" "$(same "$code" 0)"
    check "... in ${took}s (limit ${limit}s)" "$([ "$took" -le "$limit" ] && echo yes || echo no)"
    check "... writing nothing" "$(if [ -e "$many/project-01/issues/102-scale-check.md" ] || [ -e "$SCRATCH/scale-ledger.tsv" ]; then echo no; else echo yes; fi)"
}
# }}}

# -- {{{ main
function main() {
    build_scratch
    echo "ticket distribution chain, scratch in $SCRATCH"
    if [ "$PARTS" = "yes" ]; then
        echo "-- the parts' own tests"
        test_parts
    fi
    echo "-- every shipped keyword"
    test_keywords
    echo "-- every shipped template"
    test_templates
    echo "-- scale"
    test_scale
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
