#!/bin/bash
# test-todone-similarity.sh - proves todone-similarity.lua groups component
# names by spelling, synonyms, likely typos and (when asked) the model, gives
# each member the right confidence, and merges nothing the model is unsure of.
#
# In general terms: a hand-written todone.lua JSON file stands for what four
# projects plan. The model questions go to the stand-in server
# (libs/stand-in-model/) run with a small brain written here, which answers
# yes, maybe, no or an error by fixed rules; the shared brain.lua is left
# alone. A second stand-in, with the shared brain, shows what happens when
# the answer is not a yes, no or maybe. Exercises issue 053b, tiers 1-4.
#
# Usage: test-todone-similarity.sh [--dir MONOREPO]   (KEEP=1 keeps the scratch)

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/todone-similarity.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/todone-similarity-test"

PASS=0
FAIL=0
PAIR_PID=""

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

# -- {{{ same / has_line / lacks_line / matches
function same() { if [ "$1" = "$2" ]; then echo yes; else echo no; fi; }
function has_line() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
function lacks_line() { if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi; }
function matches() { if grep -qE -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
# }}}

# -- {{{ run
function run() {
    # Sets OUT (standard output), ERR (standard error) and CODE.
    OUT=$(timeout 60 luajit "$TOOL" --synonyms="$SCRATCH/synonyms.conf" "$@" 2> "$SCRATCH/err")
    CODE=$?
    ERR=$(cat "$SCRATCH/err")
}
# }}}

# -- {{{ jq_lua
function jq_lua() {
    # Evaluates a Lua expression over the JSON in OUT, with the result in `d`.
    AISTUFF_ROOT="$AISTUFF_ROOT" luajit -e "
        package.path = os.getenv('AISTUFF_ROOT') .. '/libs/lua/?.lua;' .. package.path
        local d = require('dkjson').decode(io.read('*a'))
        local function member(c, n) for _, m in ipairs(c.members) do if m.name == n then return m end end return nil end
        local function cluster(n) for _, c in ipairs(d.clusters) do if c.canonical_name == n then return c end end return nil end
        print($1)" <<< "$OUT"
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")

    printf 'threadpool = worker pool\ntui framework = terminal ui\n' > "$SCRATCH/synonyms.conf"
    cat > "$SCRATCH/found.json" <<'EOF'
{ "projects": 4, "minimum": 2, "shared": [], "failed": [],
  "each": [
    { "project": "alpha", "components": ["threadpool", "tui framework", "json parser", "task executor"] },
    { "project": "beta",  "components": ["Thread-Pool", "worker pool", "terminal ui", "jsonparsr"] },
    { "project": "gamma", "components": ["thredpool", "task queue", "memory cache", "image cache", "gui"] },
    { "project": "delta", "components": ["http client"] }
  ] }
EOF
    cat > "$SCRATCH/pair-brain.lua" <<'EOF'
local root = os.getenv("AISTUFF_ROOT")
package.path = root .. "/libs/lua/?.lua;" .. package.path
local json = require("dkjson")
local request = json.decode(io.read("*a")) or {}
local user = ""
for _, m in ipairs(request.messages or {}) do if m.role == "user" then user = m.content end end
local function reply(text) io.write(json.encode({ choices = { { message = { content = text } } } })) end
if user:find("fail me", 1, true) then io.write(json.encode({ error = { message = "asked to fail" } }))
elseif user:find("executor", 1, true) and user:find("task queue", 1, true) then reply("Yes.")
elseif user:find("cache", 1, true) then reply("maybe")
else reply("no") end
EOF

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
    PLAIN_HOST="$INFERENCE_CHAT_HOST"
    "$SCRATCH/model/stand-in-server" 0 "luajit $SCRATCH/pair-brain.lua" > "$SCRATCH/pair-port" 2>/dev/null &
    PAIR_PID=$!
    local tries=0
    while [ ! -s "$SCRATCH/pair-port" ] && [ $tries -lt 50 ]; do sleep 0.1; tries=$((tries + 1)); done
    [ -s "$SCRATCH/pair-port" ] || { echo "could not start the pair stand-in"; stop_all; exit 1; }
    PAIR_HOST="127.0.0.1:$(head -1 "$SCRATCH/pair-port")"
    export INFERENCE_CHAT_HOST="$PAIR_HOST"
}
# }}}

# -- {{{ stop_all
function stop_all() {
    stand_in_stop
    if [ -n "$PAIR_PID" ]; then kill "$PAIR_PID" 2>/dev/null; wait "$PAIR_PID" 2>/dev/null; fi
}
# }}}

# -- {{{ test_tiers
function test_tiers() {
    run "$SCRATCH/found.json" --max-tier=1 --json
    check "tier 1: Thread-Pool and threadpool are one name" \
        "$(same "$(jq_lua 'd.analysis_stats.tier1_matches .. " " .. tostring(cluster("threadpool") ~= nil)')" "1 true")"
    check "tier 1 alone: worker pool stays apart" "$(same "$(jq_lua '#cluster("threadpool").members')" 1)"

    run "$SCRATCH/found.json" --max-tier=2 --json
    check "tier 2: a synonym joins at 0.95" \
        "$(same "$(jq_lua 'member(cluster("threadpool"), "worker pool").confidence')" 0.95)"
    check "tier 2: the cluster is named by the synonym line's first name" \
        "$(same "$(jq_lua 'cluster("tui framework").members[2].name')" "terminal ui")"
    check "tier 2 alone: a typo stays apart" "$(same "$(jq_lua 'tostring(cluster("json parser"))')" nil)"

    run "$SCRATCH/found.json" --json
    check "the default is tier 3 and asks no model" "$(same "$(jq_lua 'd.analysis_stats.tier4_queries')" 0)"
    check "tier 3: a one-letter typo joins at 0.8" \
        "$(same "$(jq_lua 'member(cluster("threadpool"), "thredpool").confidence')" 0.8)"
    check "... marked tier 3" "$(same "$(jq_lua 'member(cluster("threadpool"), "thredpool").tier')" 3)"
    check "tier 3: jsonparsr ~ json parser" "$(same "$(jq_lua 'member(cluster("json parser"), "jsonparsr").tier')" 3)"
    check "tier 3 leaves short names alone (gui is not tui)" \
        "$(same "$(jq_lua 'tostring(cluster("gui"))')" nil)"
    check "the first member is the name most projects plan, at 1.0" \
        "$(same "$(jq_lua 'cluster("threadpool").members[1].name .. " " .. cluster("threadpool").members[1].confidence')" "threadpool 1")"
    check "a cluster counts its projects and is a library candidate" \
        "$(same "$(jq_lua 'cluster("threadpool").total_projects .. " " .. tostring(cluster("threadpool").library_candidate)')" "3 true")"
    check "a name only one project plans is unclustered, with the reason" \
        "$(same "$(jq_lua 'd.unclustered[#d.unclustered].name .. ": " .. d.unclustered[1].reason')" "http client: no similar components found")"
}
# }}}

# -- {{{ test_model
function test_model() {
    run "$SCRATCH/found.json" --max-tier=4 --json
    check "tier 4 exits 0 when every answer is clear" "$(same "$CODE" 0)"
    check "tier 4 asks only about uncertain pairs (shared word, inside, near)" \
        "$(same "$(jq_lua 'd.analysis_stats.tier4_queries')" 2)"
    check "tier 4: a yes joins at 0.85" \
        "$(same "$(jq_lua 'member(cluster("task executor"), "task queue").confidence')" 0.85)"
    check "tier 4: a maybe is not merged" "$(same "$(jq_lua 'tostring(cluster("memory cache"))')" nil)"
    check "... but listed as uncertain at 0.5" \
        "$(same "$(jq_lua 'd.uncertain[1].a .. "~" .. d.uncertain[1].b .. " " .. d.uncertain[1].answer .. " " .. d.uncertain[1].confidence')" "memory cache~image cache maybe 0.5")"

    run "$SCRATCH/found.json" --max-tier=4
    check "the text report shows a member's confidence and tier" \
        "$(matches "$OUT" "^      task queue +0\.85  tier 4  gamma$")"
    check "... and the uncertain pairs for a person to judge" "$(has_line "$OUT" "memory cache ~ image cache: maybe")"
    check "... and the counts by tier" "$(has_line "$OUT" "(tier 1: 1, tier 2: 2, tier 3: 2, tier 4: 1 of 2 asked)")"

    run "$SCRATCH/found.json" --max-tier=4 --max-asks=1
    check "--max-asks stops the questions and lists the rest" \
        "$(has_line "$OUT" "memory cache ~ image cache: not asked: --max-asks reached")"

    INFERENCE_CHAT_HOST="$PLAIN_HOST" run "$SCRATCH/found.json" --max-tier=4
    check "an answer that is not yes, no or maybe merges nothing" "$(has_line "$OUT" "task executor ~ task queue: unclear answer")"
    check "... and exits 1" "$(same "$CODE" 1)"

    INFERENCE_CHAT_HOST=127.0.0.1:1 run "$SCRATCH/found.json" --max-tier=4
    check "with the model gone, the first pair is named" "$(has_line "$OUT" "task executor ~ task queue: unreachable")"
    check "... and the rest are not asked" \
        "$(has_line "$OUT" "memory cache ~ image cache: not asked: the model could not be reached")"
    check "... and tiers 1-3 still stand" "$(matches "$OUT" "^      thredpool +0\.80  tier 3")"

    sed 's/"http client"/"http client", "fail me pool"/' "$SCRATCH/found.json" > "$SCRATCH/fail.json"
    run "$SCRATCH/fail.json" --max-tier=4
    check "a model error on one pair is listed and the exit status is 1" \
        "$(if grep -q "fail me pool: server error" <<< "$OUT" && [ "$CODE" = 1 ]; then echo yes; else echo no; fi)"
    check "... and the other pairs are still asked" "$(has_line "$OUT" "memory cache ~ image cache: maybe")"
}
# }}}

# -- {{{ test_input
function test_input() {
    run - --json < "$SCRATCH/found.json"
    check "- reads standard input" "$(same "$(jq_lua 'd.analysis_stats.total_components')" 13)"
    printf '{"shared": [{"name": "threadpool", "projects": ["a", "b"]}]}' > "$SCRATCH/shared.json"
    run "$SCRATCH/shared.json"
    check "without --each, the shared list is used and the report says what is missing" \
        "$(has_line "$OUT" "run todone.lua with --each")"
    printf 'not json' > "$SCRATCH/bad.json"
    run "$SCRATCH/bad.json"
    check "input that is not todone's JSON is a usage error" "$(same "$CODE" 2)"
    run "$SCRATCH/found.json" --max-tier=5
    check "--max-tier takes 1 to 4" "$(same "$CODE" 2)"
    run
    check "no input is a usage error" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "todone-similarity.lua with stand-in models, scratch in $SCRATCH"
    test_tiers
    test_model
    test_input
    stop_all
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
