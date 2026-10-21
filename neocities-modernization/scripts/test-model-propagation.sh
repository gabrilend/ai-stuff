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

# {{{ no model named: there is no default (owner, 2026-10-21)
# With no --model and nothing on the notepad, the resolver refuses and names
# the server's models. It used to return the server entry's own model (nomic).
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "" >/dev/null
NO_MODEL_ERR="$(resolve 2>&1)"
check "no model named -> refused" "$(printf '%s' "$NO_MODEL_ERR" | grep -c 'no embedding model named')" "1"
check "the refusal lists the server's models" "$(printf '%s' "$NO_MODEL_ERR" | grep -c 'embeddinggemma-2')" "1"
check "no server entry names a model of its own" "$(luajit -e "
    local c = dofile('${DIR}/config.lua')
    local n = 0
    for _, s in ipairs(c.inference_servers) do if s.model then n = n + 1 end end
    io.write(n)
")" "0"
# }}}

# {{{ an explicit --model propagates to the no-argument resolution, fresh process
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "propagation-probe:1b"
check "get_selected_model honors override" "$(resolve)" "propagation-probe:1b"
# The caches live on disk under assets/embeddings/, not in the RAM tier: /dev/shm
# is emptied at logout on this host, so a RAM cache cost a ~20-minute rebuild
# every session (see the note above embeddings_dir in libs/utils.lua). This
# check had kept the RAM path after that reversal.
check "embeddings_dir(nil) keys off override" \
    "$(resolve_dir)" "${DIR}/assets/embeddings/propagation-probe_1b"
# }}}


# {{{ notepad is rewritten, not appended: a prior run's choice cannot leak in
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "first-run:9b"
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "second-run:9b"
check "second write overwrites first" "$(resolve)" "second-run:9b"
occurrences="$(grep -c "first-run" "${DIR}/tmp/shared-memory/run-overrides.lua" || true)"
check "no stale value from prior run remains" "$occurrences" "0"
# }}}

# {{{ the server run.sh starts itself loads the run's model, not the default
# When no server is reachable, run.sh launches one. It used to pass only the
# server name, so the server loaded config.lua's default GGUF while the run
# filed the vectors under --model's directory: one model's vectors wearing
# another's label. Two halves are checked: run.sh hands the model over, and
# the launcher turns that model name into the right file.
autostart_line="$(grep -E '^\s*START_ARGS=\(' "${DIR}/run.sh")"
case "$autostart_line" in
    *'--model=$MODEL_NAME'*) passes_model="yes" ;;
    *) passes_model="no" ;;
esac
check "run.sh's server auto-start passes --model" "$passes_model" "yes"
# The same resolution start-llamacpp-server.sh performs for --model=NAME.
resolved_gguf="$(luajit -e "
    package.path = '${DIR}/libs/?.lua;' .. package.path
    local inf = require('inference-server-config'); inf.set_project_root('${DIR}')
    inf.set_selected_server('local')
    inf.set_selected_model('embeddinggemma-2')
    io.write(inf.get_selected_model_config().model_path)
")"
check "--model=embeddinggemma-2 resolves to its own GGUF" \
    "$resolved_gguf" "assets/models/embeddinggemma-2-Q8_0.gguf"
# }}}

# {{{ each server's GPU flags reach the launcher, and only that server's
# The start script reads lines 5+ of its config resolution as launch_flags.
# local is a GTX 1080 Ti and states --flash-attn off; the remote server has
# a different GPU and must not inherit that.
resolve_flags() {  # resolve_flags <server> <model> (a model is required: no default)
    bash -c "source <(sed -n '/^# {{{ resolve_server_config/,/^# }}}/p' '${DIR}/scripts/start-llamacpp-server.sh')
        DIR='${DIR}'; SERVER_NAME='$1'; MODEL_OVERRIDE='$2'
        resolve_server_config" | sed -n '5,$p' | tr '\n' ' ' | sed 's/ $//'
}
check "local server passes its GPU flags" "$(resolve_flags local embeddinggemma-2)" "--flash-attn off"
check "remote server gets no local GPU flags" "$(resolve_flags gpu-server nomic-embed-text-v1.5)" ""
# }}}

# Leave the notepad clean (no override) so a later manual run is not surprised.
"${DIR}/scripts/write-run-overrides" "${DIR}" --model "" >/dev/null

echo ""
echo "Result: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ]
