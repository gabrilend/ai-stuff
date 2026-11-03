#!/bin/bash
# test-todone-roadmap.sh - proves todone-roadmap.lua orders shared
# components so nothing comes before what it needs, scores them by the
# issue's formula, names cycles, and never writes over a file.
#
# In general terms: a hand-written todone.lua report and component facts go
# in, and the build order comes out. One run goes end to end: todone.lua
# reads two small projects through a stand-in chat model
# (libs/stand-in-model/, no download, no real model) and its report is piped
# straight in. Exercises issue 053 (053c).
#
# Usage: test-todone-roadmap.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/todone-roadmap.lua"
TODONE="$DIR/delta-version/scripts/todone.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/todone-roadmap-test"

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

# -- {{{ run
function run() {
    OUT=$(timeout 60 luajit "$TOOL" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ flat
# The JSON in $OUT on one line, spaces squeezed, for matching objects.
function flat() { tr -d '\n' <<< "$OUT" | tr -s ' '; }
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")

    cat > "$SCRATCH/todone.json" <<'EOF'
{"projects":4,"minimum":2,"failed":[],"shared":[
 {"name":"threadpool","projects":["alpha","beta","gamma"]},
 {"name":"llm client","projects":["beta","gamma"]},
 {"name":"json parser","projects":["alpha","gamma"]}]}
EOF
    # llm client needs an http client (shared by nobody) and the threadpool;
    # the http client needs the json parser. "chat client" is a synonym of
    # "llm client" in config/component-synonyms.conf.
    cat > "$SCRATCH/components.conf" <<'EOF'
# facts for the test
llm client: needs http client, Thread-Pool
chat client: complexity high
http_client: needs json parser
threadpool: complexity high
threadpool: home libs/lua/threadpool
EOF
    cp "$SCRATCH/components.conf" "$SCRATCH/cycle.conf"
    echo "json parser: needs llm client" >> "$SCRATCH/cycle.conf"
    printf 'threadpool: wants nothing\n' > "$SCRATCH/bad.conf"
    printf 'threadpool: complexity enormous\n' > "$SCRATCH/bad-size.conf"

    mkdir -p "$SCRATCH/m/alpha/issues" "$SCRATCH/m/beta/issues"
    printf '# Issue 101: Build a Thread-Pool\n' > "$SCRATCH/m/alpha/issues/101-pool.md"
    printf '# Issue 201: threadpool tuning\n' > "$SCRATCH/m/beta/issues/201-tuning.md"

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_order
function test_order() {
    run "$SCRATCH/todone.json" --components="$SCRATCH/components.conf" --json
    check "a report and facts: exit 0" "$(same "$CODE" 0)"
    local text
    text=$(flat)
    check "phase 1 holds what needs nothing, higher priority first" \
        "$(has_line "$text" '"number":1, "components":[{ "name":"threadpool"')"
    check "... the json parser too" \
        "$(grep -o '"number":1, "components":.*"number":2' <<< "$text" | grep -qF '"name":"json parser"' && echo yes || echo no)"
    check "a need no project shares is still built, before what needs it" \
        "$(has_line "$text" '"number":2, "components":[{ "name":"http client", "used_by":[], "needs":["json parser"]')"
    check "the llm client comes last, after both its needs" \
        "$(has_line "$text" '"number":3, "components":[{ "name":"llm client"')"
    check "needs are matched by spelling (Thread-Pool, http_client)" \
        "$(has_line "$text" '"needs":["http client","threadpool"]')"
    check "a synonym's facts apply (chat client is the llm client: high)" \
        "$(has_line "$text" '"name":"llm client", "used_by":["beta","gamma"], "needs":["http client","threadpool"], "priority":29')"
    check "priority is usage x 2 + dependents x 1.5 + hours x 0.5 (threadpool: 6 + 1.5 + 25)" \
        "$(has_line "$text" '"priority":32.5, "dependents":1')"
    check "effort: built once, hours + 2 a project, against hours x projects" \
        "$(has_line "$text" '"alone_hours":150, "shared_hours":56, "saved_hours":94')"
    check "... totalled" "$(has_line "$text" '"effort":{ "alone_hours":290, "shared_hours":154, "saved_hours":136 }')"
    check "a missing complexity is a marked guess" "$(has_line "$text" '"complexity":"medium", "complexity_guessed":true')"
    check "each project waits on its components, and is ready after the last one's phase" \
        "$(has_line "$text" '"project":"beta", "waits_on":["threadpool","llm client"], "ready_after":3')"

    run "$SCRATCH/todone.json" --components="$SCRATCH/components.conf"
    check "Markdown: the phases as tables" "$(has_line "$OUT" "## Shared phase 3")"
    check "... the home where one is given" "$(has_line "$OUT" '| threadpool (`libs/lua/threadpool`) | alpha, beta, gamma | - | 32.5 | 56 / 150 |')"
    check "... the guesses marked" "$(has_line "$OUT" "| 24 / 40* |")"
    check "... and each project's wait" "$(has_line "$OUT" "- **alpha**: threadpool, json parser (all built by the end of shared phase 1)")"
}
# }}}

# -- {{{ test_cycles
function test_cycles() {
    run "$SCRATCH/todone.json" --components="$SCRATCH/cycle.conf"
    check "a cycle: still a roadmap (0)" "$(same "$CODE" 0)"
    check "... the cycle named" "$(has_line "$OUT" "llm client needs http client needs json parser needs llm client")"
    check "... its members left out of the order" "$(lacks_line "$OUT" "## Shared phase 2")"
    check "... what is clear of it still ordered" "$(has_line "$OUT" "## Shared phase 1")"
    check "... and each project told what is stuck" "$(has_line "$OUT" "- **alpha**: threadpool (all built by the end of shared phase 1); and json parser, caught in a cycle")"
}
# }}}

# -- {{{ test_refusals
function test_refusals() {
    run "$SCRATCH/todone.json" --components="$SCRATCH/bad.conf"
    check "a facts line of an unknown kind: refused by line number (1)" \
        "$(if [ "$CODE" = 1 ] && grep -qF "bad.conf line 1" <<< "$OUT"; then echo yes; else echo no; fi)"
    run "$SCRATCH/todone.json" --components="$SCRATCH/bad-size.conf"
    check "an unknown complexity: refused (1)" "$(same "$CODE" 1)"
    run "$SCRATCH/components.conf"
    check "input that is not todone's report: refused (1)" "$(same "$CODE" 1)"
    run "$SCRATCH/todone.json" --components="$SCRATCH/none.conf"
    check "--components that does not exist: refused (1)" "$(same "$CODE" 1)"
    run
    check "no input named: refused (2)" "$(same "$CODE" 2)"

    echo '{"projects":3,"shared":[]}' > "$SCRATCH/empty.json"
    run "$SCRATCH/empty.json"
    check "nothing shared: said plainly (0)" \
        "$(if [ "$CODE" = 0 ] && grep -qF "nothing to order" <<< "$OUT"; then echo yes; else echo no; fi)"

    run "$SCRATCH/todone.json" --components="$SCRATCH/components.conf" --out="$SCRATCH/roadmap.md"
    check "--out saves it" "$(has_line "$(cat "$SCRATCH/roadmap.md")" "## Shared phase 1")"
    run "$SCRATCH/todone.json" --out="$SCRATCH/roadmap.md"
    check "--out never replaces a file (1)" "$(same "$CODE" 1)"
}
# }}}

# -- {{{ test_end_to_end
function test_end_to_end() {
    OUT=$(timeout 60 luajit "$TODONE" "$SCRATCH/m/alpha" "$SCRATCH/m/beta" --json 2>/dev/null \
        | timeout 60 luajit "$TOOL" - --components="$SCRATCH/components.conf" 2>&1)
    check "todone.lua --json piped in: the threadpool both plan, in phase 1" \
        "$(has_line "$OUT" '| threadpool (`libs/lua/threadpool`) | alpha, beta | - |')"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "todone-roadmap.lua, scratch in $SCRATCH"
    test_order
    test_cycles
    test_refusals
    test_end_to_end
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
