#!/bin/bash
# test-phase-a-integration.sh - proves that the Phase A tools work together on
# one project, the way a piece of work moves through them (issue A07).
#
# The tools: git-history.sh (A01), progress-dashboard.lua (A02), test-runner.sh
# (A03), validate-issues (A04) and update-toc (A05). The parser coverage report
# (A06) went back to world-edit-to-execute, where its maps are, so it is not
# here.
#
# In general terms: builds a throwaway project in a git repository -- issues in
# two phases with progress files, a docs/ folder with its table of contents,
# one test -- and checks:
#
#   - every tool is in this checkout, runnable, and answers --help;
#   - the libraries load and offer what the tools call: issue-names.lua and
#     table-of-contents.lua, progress-dashboard.lua through dofile (from a
#     script elsewhere), git-history.sh sourced without running;
#   - the tools load their libraries from the checkout they live in, not the
#     house path, so this test tests this checkout;
#   - on the fresh project every tool agrees there is nothing wrong: the
#     dashboard counts the same issues the validator checks, and the
#     validator's next free id follows them;
#   - one piece of work done the house way (the issue moved to completed/, a
#     document written, committed in plain English) shows up in every tool:
#     the dashboard counts it done, git-history files the commit under its
#     phase, update-toc notices the unlisted document and --write lists it,
#     and the validator still counts the completed id as used;
#   - a broken link between issues is the validator's finding and nobody
#     else's; a failing test turns the runner's exit status, and nothing else;
#   - the demo script runs every tool read-only against the project;
#   - the whole run takes under ten seconds.
#
# Nothing outside the scratch folder is written: the test runner's RAM tiers
# are pointed into it through EXEC_TIER_ROOT and ARTIFACT_TIER_ROOT.
#
# Usage: test-phase-a-integration.sh [scripts-directory]

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/test-phase-a.XXXXXX")"
PROJ="${SCRATCH}/proj"
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
mkdir -p "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}"

PASS=0
FAIL=0
START=${SECONDS}

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

# -- {{{ yes_if / status_is
function yes_if() {
    if "$@"; then echo yes; else echo no; fi
}

# "yes" when the command exits with the given status; its output goes to the
# file named in OUT (or nowhere).
function status_is() {
    local want="$1"; shift
    local got=0
    "$@" > "${OUT:-/dev/null}" 2>&1 || got=$?
    [ "$got" = "$want" ] && echo yes || echo no
}
# }}}

# -- {{{ the tools, run from this checkout
function dashboard() { luajit "${DIR}/progress-dashboard.lua" "$@"; }
function validate() { luajit "${DIR}/validate-issues" "$@"; }
function toc() { luajit "${DIR}/update-toc" "$@"; }
function history() { bash "${DIR}/git-history.sh" "$@"; }
function runner() { bash "${DIR}/test-runner.sh" "$@"; }
function commit() { git -C "${PROJ}" add -A && git -C "${PROJ}" -c user.name=t -c user.email=t@t commit -qm "$1"; }
# }}}

# -- {{{ issue_file
# An issue in the house shape: issue_file <path> <id> <title> <dependencies>
function issue_file() {
    printf '# Issue %s: %s\n\n**Phase:** %s\n**Dependencies:** %s\n\n---\n\n## Current Behavior\n\nNot there yet.\n\n## Intended Behavior\n\nThere.\n\n## Suggested Implementation Steps\n\n1. Build it.\n' \
        "$2" "$3" "${2%%-*}" "$4" > "$1"
}
# }}}

# -- {{{ write_helpers
# Two small Lua scripts the checks run, written into the scratch folder.
#   count.lua DIR PHASE FIELD   one number from the dashboard's JSON on stdin
#   libs.lua DIR PROJECT        what the shared libraries offer, on one line
function write_helpers() {
    cat > "${SCRATCH}/count.lua" <<'LUA'
package.path = arg[1] .. "/../libs/lua/?.lua;" .. package.path
local data = require("dkjson").decode(io.read("*a"))
local phase = data and data.phases[arg[2]]
print(phase and phase[arg[3]] or "none")
LUA
    cat > "${SCRATCH}/libs.lua" <<'LUA'
local dir = arg[1]
local out = {}
local names = dofile(dir .. "/libs/issue-names.lua")
out[#out + 1] = "names.scan=" .. type(names.scan)
out[#out + 1] = "names.format_id=" .. type(names.format_id)
local toc = dofile(dir .. "/libs/table-of-contents.lua")
out[#out + 1] = "toc.check=" .. type(toc.check)
out[#out + 1] = "toc.tree=" .. type(toc.tree)
local dash = dofile(dir .. "/progress-dashboard.lua")
out[#out + 1] = "dash.collect=" .. type(dash.collect)
out[#out + 1] = "dash.render_terminal=" .. type(dash.render_terminal)
out[#out + 1] = "dash.phases=" .. type((dash.collect(arg[2])))
print(table.concat(out, " "))
LUA
}
# }}}

# -- {{{ phase_count
# One number from the dashboard's JSON: phase_count <phase> <field>
function phase_count() {
    dashboard "${PROJ}" -j 2>/dev/null | luajit "${SCRATCH}/count.lua" "${DIR}" "$1" "$2"
}
# }}}

# -- {{{ make_project
function make_project() {
    mkdir -p "${PROJ}/issues/completed" "${PROJ}/docs" "${PROJ}/tests"
    git -C "${PROJ}" init -q
    issue_file "${PROJ}/issues/1-001-first-thing.md" 1-001 "First thing" "None"
    issue_file "${PROJ}/issues/1-002-second-thing.md" 1-002 "Second thing" "1-001"
    issue_file "${PROJ}/issues/A01-a-tool.md" A01 "A tool" "None"
    printf '# Phase 1 Progress\n' > "${PROJ}/issues/phase-1-progress.md"
    printf '# Phase A Progress\n' > "${PROJ}/issues/phase-A-progress.md"
    printf '# Guide\n\nHow to use it.\n' > "${PROJ}/docs/guide.md"
    printf '# Table of Contents\n\n- [Guide](guide.md)\n' > "${PROJ}/docs/table-of-contents.md"
    printf '#!/bin/bash\nexit 0\n' > "${PROJ}/tests/test-ok.sh"
    chmod +x "${PROJ}/tests/test-ok.sh"
    printf 'tmp\n' > "${PROJ}/.gitignore"   # where the test runner keeps its tiers
    commit "The project starts with three issues, a guide and a test"
}
# }}}

# -- {{{ test_tools_present
function test_tools_present() {
    echo "the tools"
    local tool
    for tool in git-history.sh progress-dashboard.lua test-runner.sh validate-issues update-toc; do
        check "${tool} is in this checkout and executable" "$(yes_if test -x "${DIR}/${tool}")"
    done
    check "git-history.sh --help" "$(status_is 0 history --help)"
    check "progress-dashboard.lua --help" "$(status_is 0 dashboard --help)"
    check "test-runner.sh --help" "$(status_is 0 runner --help)"
    check "validate-issues --help" "$(status_is 0 validate --help)"
    check "update-toc --help" "$(status_is 0 toc --help)"
}
# }}}

# -- {{{ test_libraries
function test_libraries() {
    echo "the libraries"
    local report
    # run from the scratch folder, so the script loading the dashboard is
    # somewhere else than the dashboard
    report=$(cd "${SCRATCH}" && luajit "${SCRATCH}/libs.lua" "${DIR}" "${PROJ}" 2>&1)
    check "issue-names.lua offers scan and format_id" \
        "$(yes_if grep -q 'names.scan=function names.format_id=function' <<< "${report}")"
    check "table-of-contents.lua offers check and tree" \
        "$(yes_if grep -q 'toc.check=function toc.tree=function' <<< "${report}")"
    check "progress-dashboard.lua loads with dofile from a script elsewhere and collects" \
        "$(yes_if grep -q 'dash.collect=function dash.render_terminal=function dash.phases=table' <<< "${report}")"
    check "git-history.sh can be sourced without running, and offers its functions" \
        "$(yes_if bash -c "source '${DIR}/git-history.sh' && declare -F git_history_init git_history_get_phases > /dev/null")"
}
# }}}

# -- {{{ test_own_checkout
# A copy of the tools whose house path does not exist must still work: each
# tool reads its libraries from beside itself.
function test_own_checkout() {
    echo "libraries come from the checkout the tool lives in"
    local copy="${SCRATCH}/copy"
    mkdir -p "${copy}/libs"
    cp "${DIR}/progress-dashboard.lua" "${DIR}/validate-issues" "${DIR}/update-toc" "${DIR}/test-runner.sh" "${copy}/"
    # each library announces that the copy beside the tool was the one loaded
    printf 'io.stderr:write("LOADED-FROM-COPY\\n")\n' | cat - "${DIR}/libs/issue-names.lua" > "${copy}/libs/issue-names.lua"
    printf 'io.stderr:write("LOADED-FROM-COPY\\n")\n' | cat - "${DIR}/libs/table-of-contents.lua" > "${copy}/libs/table-of-contents.lua"
    printf 'echo LOADED-FROM-COPY >&2\n' | cat - "${DIR}/libs/ensure-ram-tiers" > "${copy}/libs/ensure-ram-tiers"
    check "progress-dashboard.lua reads issue-names.lua from beside itself" \
        "$(yes_if sh -c "luajit '${copy}/progress-dashboard.lua' '${PROJ}' -j 2>&1 | grep -q LOADED-FROM-COPY")"
    check "validate-issues reads issue-names.lua from beside itself" \
        "$(yes_if sh -c "luajit '${copy}/validate-issues' '${PROJ}' 2>&1 | grep -q LOADED-FROM-COPY")"
    check "update-toc reads table-of-contents.lua from beside itself" \
        "$(yes_if sh -c "luajit '${copy}/update-toc' '${PROJ}' 2>&1 | grep -q LOADED-FROM-COPY")"
    check "test-runner.sh reads its RAM-tier library from beside itself" \
        "$(yes_if sh -c "bash '${copy}/test-runner.sh' '${PROJ}' -q 2>&1 | grep -q LOADED-FROM-COPY")"
}
# }}}

# -- {{{ test_fresh_project
function test_fresh_project() {
    echo "a fresh project: every tool agrees nothing is wrong"
    check "the dashboard prints no warnings" "$(status_is 0 dashboard "${PROJ}")"
    check "it counts two phase 1 issues, none done" \
        "$([ "$(phase_count 1 total) $(phase_count 1 completed)" = "2 0" ] && echo yes || echo no)"
    check "and one phase A issue" "$([ "$(phase_count A total)" = 1 ] && echo yes || echo no)"
    check "the validator finds nothing" "$(OUT="${SCRATCH}/validate.out" status_is 0 validate "${PROJ}")"
    check "it checked the same three issues the dashboard counted" "$(yes_if grep -q '^3 issues, 0 findings' "${SCRATCH}/validate.out")"
    check "the next free phase 1 id follows them" "$([ "$(validate "${PROJ}" --next 1)" = 1-003 ] && echo yes || echo no)"
    check "update-toc finds every document listed" "$(status_is 0 toc "${PROJ}")"
    check "the test runner runs the project's test and passes" \
        "$(OUT="${SCRATCH}/runner1.out" status_is 0 runner "${PROJ}" -q)"
    check "it ran exactly one" "$(yes_if grep -q '1 passed, 0 failed' "${SCRATCH}/runner1.out")"
}
# }}}

# -- {{{ test_work_done
function test_work_done() {
    echo "one piece of work done the house way"
    git -C "${PROJ}" mv issues/1-001-first-thing.md issues/completed/
    printf '# Design\n\nWhy it is built this way.\n' > "${PROJ}/docs/design.md"
    commit "The first thing works, and its design is written down"

    check "the dashboard counts it done" "$([ "$(phase_count 1 completed)" = 1 ] && echo yes || echo no)"
    check "git-history writes a file per phase" \
        "$(OUT="${SCRATCH}/history.out" status_is 0 history -d "${PROJ}" -a -o "${SCRATCH}/history")"
    check "the commit that completed the issue is filed under phase 1" \
        "$(yes_if grep -q 'The first thing works' "${SCRATCH}/history/phase-1-commits.md")"
    check "and not under phase A" "$(yes_if sh -c "! grep -q 'The first thing works' '${SCRATCH}/history/phase-A-commits.md'")"
    check "update-toc notices the new document is unlisted" \
        "$(OUT="${SCRATCH}/toc.out" status_is 1 toc "${PROJ}")"
    check "and names it" "$(yes_if grep -q 'docs/design.md' "${SCRATCH}/toc.out")"
    check "--write lists it" "$(status_is 0 toc "${PROJ}" --write)"
    check "after which the check is clean" "$(status_is 0 toc "${PROJ}")"
    check "the completed id stays used: the next phase 1 id is still 1-003" \
        "$([ "$(validate "${PROJ}" --next 1)" = 1-003 ] && echo yes || echo no)"
    check "the dependency on a completed issue is not a finding" "$(status_is 0 validate "${PROJ}")"
}
# }}}

# -- {{{ test_faults_stay_with_their_tool
function test_faults_stay_with_their_tool() {
    echo "a fault is reported by the tool that owns it"
    issue_file "${PROJ}/issues/1-003-third-thing.md" 1-003 "Third thing" "1-009"
    check "a link to an issue with no file is the validator's finding" \
        "$(OUT="${SCRATCH}/validate2.out" status_is 1 validate "${PROJ}")"
    check "it names the missing id" "$(yes_if grep -q '1-009' "${SCRATCH}/validate2.out")"
    check "the dashboard still has nothing to warn about" "$(status_is 0 dashboard "${PROJ}")"
    check "and counts the new issue" "$([ "$(phase_count 1 total)" = 3 ] && echo yes || echo no)"
    rm "${PROJ}/issues/1-003-third-thing.md"

    printf '#!/bin/bash\necho "broken on purpose"\nexit 1\n' > "${PROJ}/tests/test-broken.sh"
    chmod +x "${PROJ}/tests/test-broken.sh"
    check "a failing test turns the runner's status" "$(OUT="${SCRATCH}/runner2.out" status_is 1 runner "${PROJ}" -q)"
    check "the runner names it" "$(yes_if grep -q 'test-broken.sh' "${SCRATCH}/runner2.out")"
    check "the validator does not care" "$(status_is 0 validate "${PROJ}")"
    rm "${PROJ}/tests/test-broken.sh"
}
# }}}

# -- {{{ test_demo
function test_demo() {
    echo "the demo"
    local demo="${DIR}/issues/completed/demos/phase-a-demo.sh"
    check "the demo script is there" "$(yes_if test -x "${demo}")"
    git -C "${PROJ}" status --porcelain > "${SCRATCH}/before"
    check "it runs every tool against the project" "$(OUT="${SCRATCH}/demo.out" status_is 0 bash "${demo}" "${PROJ}")"
    local section
    for section in "Progress Dashboard" "Issue Validator" "Documentation Index" "Commit History" "Test Runner"; do
        check "the demo shows: ${section}" "$(yes_if grep -q "${section}" "${SCRATCH}/demo.out")"
    done
    git -C "${PROJ}" status --porcelain > "${SCRATCH}/after"
    check "and changes nothing in the project" "$(yes_if cmp -s "${SCRATCH}/before" "${SCRATCH}/after")"
}
# }}}

write_helpers
make_project
test_tools_present
test_libraries
test_own_checkout
test_fresh_project
test_work_done
test_faults_stay_with_their_tool
test_demo
ELAPSED=$((SECONDS - START))
echo "time"
check "the whole run takes under ten seconds (${ELAPSED}s)" "$([ "${ELAPSED}" -lt 10 ] && echo yes || echo no)"
rm -rf "${SCRATCH}"

echo
echo "passed: ${PASS}  failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
