#!/usr/bin/env bash
# audit-orphan-files.test.sh -- proves the orphan auditor tells a used module
# from an unused one in each of the ways this project's files reach each
# other. It builds a throwaway project in RAM (a few one-line modules, a
# script, a test, a demo, a git index so the auditor can list them), runs the
# real auditor, and checks each verdict.
#
# Pins: a module a script loads is alive, and so is a module it loads in turn;
# a module named only in Lua written inside a shell script is alive; a module
# named only by its test, only by a demo, or only in a comment is reported;
# two modules that name only each other are reported as a dead cluster; a
# module whose name is a prefix of another's ("util" vs "util-extra") is not
# confused with it.
#
# Run: bash scripts/audit-orphan-files.test.sh [project-dir]

set -u
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi

"${DIR}/scripts/ensure-tmp-symlink" "${DIR}" >/dev/null
SCRATCH="${DIR}/tmp/shared-memory/audit-orphan-files-test"
rm -rf "${SCRATCH}"
mkdir -p "${SCRATCH}/src" "${SCRATCH}/libs" "${SCRATCH}/scripts" "${SCRATCH}/demos"

pass=0; fail=0
# {{{ in_list / not_listed
# in_list <label> <heading-fragment> <module>: the module appears under the
# heading containing the fragment. not_listed <label> <module>: it appears
# nowhere in the orphan lists.
in_list() {
    if awk -v h="$2" -v m="  $3" '
        /^[A-Z]/ { inside = index($0, h) > 0 }
        inside && $0 == m { found = 1 }
        END { exit !found }' "${SCRATCH}/report.txt"; then
        pass=$((pass+1)); echo "  ok   - $1"
    else
        fail=$((fail+1)); echo "  FAIL - $1"
    fi
}
not_listed() {
    if sed '/^Scripts nothing else calls/,$d' "${SCRATCH}/report.txt" | grep -q -x "  $2"; then
        fail=$((fail+1)); echo "  FAIL - $1"
    else
        pass=$((pass+1)); echo "  ok   - $1"
    fi
}
# }}}

# {{{ the throwaway project
w() { printf '%s\n' "$2" > "${SCRATCH}/$1"; }
w scripts/run-it        'luajit src/entry.lua'
w scripts/shell-lua.sh  'luajit -e "local m = require(\"inline-only\")"'
w src/entry.lua         'local u = require("util"); local d = require("deep")'
w libs/util.lua         'return {}'
w libs/util-extra.lua   'return {}'
w src/deep.lua          'return {}'
w src/inline-only.lua   'return {}'
w src/tested-only.lua   'return {}'
w src/test-tested-only.lua 'require("tested-only")'
w src/demo-only.lua     'return {}'
w demos/1-demo.sh       'luajit src/demo-only.lua'
w src/comment-only.lua  'return {}'
w src/mentions.lua      '-- comment-only is described here, never loaded'
w src/cluster-a.lua     'require("cluster-b")'
w src/cluster-b.lua     'require("cluster-a")'
git -C "${SCRATCH}" init -q
git -C "${SCRATCH}" add -A
# }}}

"${DIR}/scripts/audit-orphan-files" "${SCRATCH}" > "${SCRATCH}/report.txt"
status=$?
if [ "${status}" -eq 1 ]; then pass=$((pass+1)); echo "  ok   - exits 1 when orphans exist"
else fail=$((fail+1)); echo "  FAIL - exit status ${status}, want 1"; fi

not_listed "a module a script runs is alive"                 src/entry.lua
not_listed "a module loaded by a live module is alive"       src/deep.lua
not_listed "a module named in Lua inside a shell script is alive" src/inline-only.lua
not_listed "util is not mistaken for util-extra"             libs/util.lua
in_list    "a module named by nothing is reported"           "Named by nothing"   libs/util-extra.lua
in_list    "a module named only by its test is reported"     "only by tests"      src/tested-only.lua
in_list    "a module named only by a demo is reported"       "only by demos"      src/demo-only.lua
in_list    "a module named only in a comment is reported"    "Named by nothing"   src/comment-only.lua
in_list    "two modules naming only each other: first"       "dead cluster"       src/cluster-a.lua
in_list    "two modules naming only each other: second"      "dead cluster"       src/cluster-b.lua

rm -rf "${SCRATCH}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
