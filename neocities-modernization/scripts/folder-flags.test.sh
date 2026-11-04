#!/usr/bin/env bash
# folder-flags.test.sh -- every program's folders are named by flags (Issue 10-076).
# Run: bash scripts/folder-flags.test.sh [--dir PATH]
#
# What it checks (for a CEO): every program in the project is told where the
# project is with --dir, and the build's stored data (the assets) with
# --assets. A word typed on its own -- usually a flag that lost its dashes --
# stops the program at once and is named, instead of quietly becoming the
# project folder. A library loaded by another program takes that program's
# --dir. No folder is assumed when none is named. And the project's checker
# (scripts/check-folder-flags) finds no program that reads its folder any
# other way, so a new one cannot slip back to the old way.
#
# How: run.sh is run in its plan-only mode (--dry-run, stage 4, which needs no
# values), so nothing is built; the child programs and the shared parsers are
# run directly with the words a build would hand them.
#
# Why it exists: 2026-11-02, "wordcloud-poems 64" (dashes missing) made "64"
# the project folder, and the build stopped on a missing library under
# "64/scripts/" -- an error that named neither the word nor the flag.

# --help: print the header above and exit, before any work (libs/script-help.sh)
source "$(dirname "$(readlink -f "$0")")/../libs/script-help.sh"
script_help "$0" "$@"

set -u
# The project folder: --dir PATH, or the path below; a stray word on the
# command line stops the script (libs/project-dir.sh, Issue 10-076).
source "$(dirname "$(readlink -f "$0")")/../libs/project-dir.sh"
project_dir_read "/mnt/mtwo/programming/ai-stuff/neocities-modernization" "" "$@"

"${DIR}/scripts/ensure-tmp-symlink" --dir "${DIR}" >/dev/null || {
    echo "FATAL: could not materialize tmp/ -- cannot test"; exit 2
}

pass=0; fail=0
# {{{ check
# check <label> <condition-exit-status> [detail]
check() {
    if [ "$2" = "0" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1${3:+: $3}"; fi
}
# }}}

ASSETS="${DIR}/assets"
NOWHERE="${DIR}/tmp/shared-memory/folder-flags-test/no-such-project"

# {{{ run.sh: a bare word stops the run and is named
out=$("${DIR}/run.sh" --stage 4 --dry-run wordcloud-poems 64 2>&1)
status=$?
[ "$status" = "1" ]; check "a bare word stops run.sh with status 1" $? "status $status"
printf '%s' "$out" | grep -q "unexpected word on the command line: wordcloud-poems"
check "the error names the first stray word" $? "$out"
printf '%s' "$out" | grep -q "Pipeline stages to execute"
[ $? != 0 ]; check "no stage is planned after a stray word" $?
# }}}

# {{{ run.sh: --dir is the project folder, and reaches every child as --dir
out=$("${DIR}/run.sh" --dir "$NOWHERE" --stage 4 --dry-run 2>&1)
printf '%s' "$out" | grep -q "${NOWHERE}/scripts/stage-timing.sh"
check "--dir PATH becomes the project folder (its libraries are looked for there)" $? "$out"
out=$("${DIR}/run.sh" --dir="$DIR" --stage 4 --dry-run 2>&1)
printf '%s' "$out" | grep -q -- "src/main.lua --dir ${DIR} --validate-only"
check "--dir=PATH is the same, and the child is handed --dir" $? "$out"
# }}}

# {{{ run.sh: --assets reaches the child programs as --assets
out=$("${DIR}/run.sh" --stage 4 --dry-run --assets "$ASSETS" 2>&1)
printf '%s' "$out" | grep -q -- "--validate-only --assets ${ASSETS}"
check "--assets PATH is handed to the child programs as --assets" $? "$out"
# }}}

# {{{ the shared stage parsers (libs/utils.lua)
lua_check() {  # lua_check <label> <lua expression that must be true>
    luajit -e "
        package.path = '${DIR}/libs/?.lua;${DIR}/src/?.lua;' .. package.path
        local u = require('utils')
        os.exit(($2) and 0 or 1)
    " 2>/dev/null
    check "$1" $?
}
lua_check "the assets finder reads --assets PATH" \
    "u.parse_assets_dir({'--assets', '/a'}) == '/a'"
lua_check "the assets finder reads --assets=PATH" \
    "u.parse_assets_dir({'--assets=/a'}) == '/a'"
lua_check "the assets finder does not take --dir for the assets folder" \
    "u.parse_assets_dir({'--dir', '/p', '--assets', '/a'}) == '/a'"
lua_check "the stage parser reads the project folder from --dir, and skips the assets path" \
    "u.parse_cli_args({'--dir', '/proj', '--assets', '/a'}).dir_override == '/proj'"
lua_check "the stage parser stops on a bare word" \
    "not pcall(u.parse_cli_args, {'/proj'})"
lua_check "the menu parser reads --dir" \
    "select(2, u.parse_interactive_args({'-I', '--dir', '/p'})) == '/p'"
lua_check "the menu parser stops on a bare word" \
    "not pcall(u.parse_interactive_args, {'-I', '/p'})"
# }}}

# {{{ each child program run.sh starts stops on a bare word, naming it
# Each is given the project folder and a stray word; it must exit non-zero,
# name the word, and do no work.
for child in src/main.lua src/generate-gallery-pages.lua src/wordcloud-generator.lua src/generate-word-pages.lua src/picture-embeddings.lua; do
    out=$(timeout 60 luajit "${DIR}/${child}" --dir "$DIR" wordcloud-poems 2>&1)
    status=$?
    { [ "$status" != "0" ] && printf '%s' "$out" | grep -q "unexpected word on the command line: wordcloud-poems"; }
    check "${child} stops on a bare word and names it" $? "status $status: $(printf '%s' "$out" | head -3)"
done
out=$(timeout 60 "${DIR}/generate-embeddings.sh" --dir "$DIR" wordcloud-poems 2>&1)
status=$?
{ [ "$status" = "1" ] && printf '%s' "$out" | grep -q "unexpected word on the command line: wordcloud-poems"; }
check "generate-embeddings.sh stops on a bare word and names it" $? "status $status"
out=$(timeout 60 "${DIR}/generate-embeddings.sh" --dir "$DIR" --model=x 2>&1)
status=$?
{ [ "$status" = "1" ] && printf '%s' "$out" | grep -q -- "--assets=PATH is required"; }
check "generate-embeddings.sh assumes no assets folder" $? "status $status: $(printf '%s' "$out" | tail -2)"
# }}}

# {{{ a library loaded by another program takes that program's --dir
out=$(luajit -e "
    arg = { [0] = '/somewhere/else/a-parent-program.lua', '--threads', '4', '--dir', '/the/parent/folder', 'x' }
    local r = dofile('${DIR}/libs/project-dir.lua')
    local dir = r.read_if_run(arg, '${DIR}/src/flat-html-generator.lua', '/default')
    io.write(dir)
" 2>&1)
[ "$out" = "/the/parent/folder" ]
check "a loaded library takes its parent's --dir, and judges none of its parent's other words" $? "$out"
# }}}

# {{{ no folder is guessed: an unnamed assets folder is an error
out=$(luajit -e "
    package.path = '${DIR}/libs/?.lua;' .. package.path
    local cl = require('config-loader')
    local scratch = '${DIR}/tmp/shared-memory/folder-flags-test/no-assets-setting'
    os.execute('mkdir -p ' .. scratch)
    local f = assert(io.open(scratch .. '/config.lua', 'w')); f:write('return {}'); f:close()
    local u = require('utils')
    u.DIR = scratch
    cl.set_project_root(scratch)
    io.write(tostring(u.init_assets_root({})))
" 2>&1)
printf '%s' "$out" | grep -q "no assets directory named"
check "with no --assets and no config.lua setting, the assets folder is an error, not <project>/assets" $? "$out"
# }}}

# {{{ the project's checker: no program reads its folder any other way
out=$("${DIR}/scripts/check-folder-flags" --dir "$DIR" 2>&1)
status=$?
check "scripts/check-folder-flags finds every program reading --dir" "$status" "$(printf '%s' "$out" | tail -5)"
# }}}

rm -rf "${DIR}/tmp/shared-memory/folder-flags-test"
echo
echo "${pass} passed, ${fail} failed"
[ "$fail" = "0" ]
