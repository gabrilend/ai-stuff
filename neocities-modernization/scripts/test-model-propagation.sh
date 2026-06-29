#!/usr/bin/env bash
# test-model-propagation.sh -- pins the fix for the silent-model-fallback bug.
# Run: bash scripts/test-model-propagation.sh
#
# The bug: run.sh launches a fresh luajit per stage, and a --model override only
# reached the stages run.sh explicitly threaded it through; the HTML, word-cloud
# and word-page stages resolved the model via get_selected_model() /
# embeddings_dir() with no argument and so silently reverted to config.lua's
# default. The fix records the run's --model on a notepad in RAM
# (tmp/run-overrides.lua) that the resolver consults. These checks lock in that
# (a) an override propagates to the no-argument resolution every stage uses, in a
# fresh process; (b) no override falls back to config.lua; (c) the notepad is
# rewritten (never appended) so a previous run's choice cannot leak in.

set -u
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

"${DIR}/scripts/ensure-tmp-symlink" "${DIR}" >/dev/null || {
    echo "FATAL: could not materialize tmp/ -- cannot test"; exit 2
}

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ resolve(): what a brand-new stage process sees as the selected model
# Each call is its own luajit process, exactly like a real pipeline stage, so a
# stale module cache cannot mask a propagation failure.
resolve() {
    luajit -e "
        package.path = '${DIR}/libs/?.lua;${DIR}/src/?.lua;' .. package.path
        local inf = require('inference-server-config')
        inf.set_project_root('${DIR}')
        io.write(inf.get_selected_model())
    "
}
resolve_dir() {  # the no-argument embeddings_dir() that stages 9/10 actually call
    luajit -e "
        package.path = '${DIR}/libs/?.lua;${DIR}/src/?.lua;' .. package.path
        local u = require('utils'); u.init_assets_root({'${DIR}'})
        io.write(u.embeddings_dir())
    "
}
# }}}

# {{{ config default (the value a no-override run must fall back to)
CONFIG_DEFAULT="$(luajit -e "
    package.path = '${DIR}/libs/?.lua;' .. package.path
    local inf = require('inference-server-config'); inf.set_project_root('${DIR}')
    io.write(inf.get_selected_model())
")"
# Read straight from config.lua independently, so this test does not depend on
# the very resolver it is checking to define "correct".
CONFIG_RAW="$(luajit -e "
    local c = dofile('${DIR}/config.lua')
    -- inference_servers is an array of {name=...}; the default is selected by name.
    for _, s in ipairs(c.inference_servers) do
        if s.name == c.default_inference_server then io.write(s.model); break end
    end
")"
check "resolver default == config.lua default" "$CONFIG_DEFAULT" "$CONFIG_RAW"
# }}}

# {{{ an explicit --model propagates to the no-argument resolution, fresh process
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "propagation-probe:1b"
check "get_selected_model honors override" "$(resolve)" "propagation-probe:1b"
check "embeddings_dir(nil) keys off override" \
    "$(resolve_dir)" "${DIR}/tmp/cache/embeddings/propagation-probe_1b"
# }}}

# {{{ no --model falls back to config.lua (override absent, not a hardcoded value)
"${DIR}/scripts/write-run-overrides" "${DIR}" --model ""
check "no override -> config default" "$(resolve)" "$CONFIG_RAW"
# }}}

# {{{ notepad is rewritten, not appended: a prior run's choice cannot leak in
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "first-run:9b"
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "second-run:9b"
check "second write overwrites first" "$(resolve)" "second-run:9b"
occurrences="$(grep -c "first-run" "${DIR}/tmp/run-overrides.lua" || true)"
check "no stale value from prior run remains" "$occurrences" "0"
# }}}

# Leave the notepad clean (no override) so a later manual run is not surprised.
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "" >/dev/null

echo ""
echo "Result: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
