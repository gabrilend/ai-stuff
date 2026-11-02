#!/usr/bin/env bash
#
# test-commit-exit-status.sh
#
# Proves that commit-own-changes reads the exit status of the commands it
# runs the same way under LuaJIT and under Lua 5.2 and later.
#
# Why this exists. The two interpreters answer "how did that command end?" in
# different shapes. LuaJIT's os.execute returns the bare wait status, a number
# (0, or 256 for exit 1), and closing a LuaJIT io.popen pipe says true
# whatever the command did; Lua 5.4 returns true/nil, "exit", code from both.
# Code written for one shape read the other silently wrong: under LuaJIT the
# tool exited 1 after a commit that worked, took a commit hook that refused
# as passed, ran hooks that did not exist, and could report a commit git had
# refused to record. Nothing failed loudly, which is why it needs a test.
#
# Each interpreter, in turn:
#   - the library alone: exit_status, run and run_quiet on a success, a plain
#     failure and a kill by signal, with output (NUL bytes included) intact;
#   - a commit that works exits 0 and lands;
#   - a commit git refuses to record (its branch is locked) exits non-zero,
#     says nothing was committed, and leaves the branch where it was;
#   - a pre-commit hook that refuses stops the commit, exits non-zero, and is
#     reported as having failed;
#   - with no hooks at all, none is reported as run.
#
# Each scene runs in a scratch repository under /tmp; the session's ledger is
# written in RAM under a made-up session id and removed afterwards.
#
# Usage: test-commit-exit-status.sh [scripts-directory]

set -uo pipefail

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/test-commit-exit-status-XXXXXX")"
SESSION="coc-status-$$"
LEDGER_ROOT="/dev/shm/claude-own-edits"
trap 'rm -rf "${SCRATCH}" "${LEDGER_ROOT:?}/${SESSION}"' EXIT

failures=0
checked=0

# {{{ check()
check() {
    local description="$1" result="$2"
    checked=$((checked + 1))
    if [ "${result}" = "yes" ]; then
        printf '  ok       %s\n' "${description}"
    else
        printf '  FAILED   %s\n' "${description}"
        failures=$((failures + 1))
    fi
}
# }}}

# {{{ new_repo()
# A fresh repository on main with notes.md, and one line of it changed by
# this session, as the ledger records it.
new_repo() {
    REPO="${SCRATCH}/$1"
    mkdir -p "${REPO}"
    git -C "${REPO}" init -q -b main
    git -C "${REPO}" config user.name "test"
    git -C "${REPO}" config user.email "test@example.invalid"
    seq -f 'line%g' 1 5 > "${REPO}/notes.md"
    git -C "${REPO}" add -A
    git -C "${REPO}" commit -q -m base
    rm -rf "${LEDGER_ROOT:?}/${SESSION}"
    mkdir -p -m 700 "${LEDGER_ROOT}/${SESSION}"
    sed -i '1s/.*/mine/' "${REPO}/notes.md"
    printf '%s\t%s\t%s\n' - "$(realpath "${REPO}/notes.md")" line1 + "$(realpath "${REPO}/notes.md")" mine \
        >> "${LEDGER_ROOT}/${SESSION}/ledger.tsv"
}
# }}}

# {{{ coc()
# Runs commit-own-changes under the interpreter being tested. Output goes to
# out.txt beside the repository; the exit status is returned.
coc() {
    CLAUDE_CODE_SESSION_ID="${SESSION}" CLAUDE_SESSIONS_ROOT="${SCRATCH}/sessions" \
        "${LUA}" "${DIR}/commit-own-changes" --scripts-dir "${DIR}" "${REPO}" "$@" \
        > "${REPO}.out" 2>&1
}
# }}}

for LUA in luajit lua5.4; do
    if ! command -v "${LUA}" > /dev/null; then
        check "${LUA} is installed" no
        continue
    fi
    printf '\nUnder %s\n' "${LUA}"

    # {{{ the library alone
    lib="$("${LUA}" - "${DIR}" <<'EOF'
package.path = arg[1] .. "/libs/?.lua;" .. package.path
local p = require("own-changes-patch")
local function say(...) io.write(table.concat({...}, " "), "\n") end
say("exit", p.exit_status(os.execute("true")), p.exit_status(os.execute("exit 3")),
    p.exit_status(os.execute("kill -9 $$")))
local out, ok = p.run({ "sh", "-c", "echo said; exit 4" })
say("run-fail", tostring(ok), out == "said\n" and "intact" or ("[" .. out .. "]"))
out, ok = p.run({ "true" })
say("run-ok", tostring(ok), out == "" and "empty" or ("[" .. out .. "]"))
local err
out, ok, err = p.run_quiet({ "sh", "-c", "printf 'a\\0b\\0'; echo warn >&2; exit 0" })
say("quiet-ok", tostring(ok), out == "a\0b\0" and "intact" or "mangled", err == "warn\n" and "apart" or "mixed")
out, ok = p.run_quiet({ "test", "-x", "/nonexistent/hook" })
say("quiet-fail", tostring(ok))
EOF
)"
    check "exit_status reads success, exit 3 and a kill as 0, 3, 137" \
        "$(grep -qx 'exit 0 3 137' <<< "${lib}" && echo yes || echo no)"
    check "run: a command that exits 4 is a failure, its output intact" \
        "$(grep -qx 'run-fail false intact' <<< "${lib}" && echo yes || echo no)"
    check "run: a command that exits 0 is a success" \
        "$(grep -qx 'run-ok true empty' <<< "${lib}" && echo yes || echo no)"
    check "run_quiet: NUL-separated output survives, errors kept apart" \
        "$(grep -qx 'quiet-ok true intact apart' <<< "${lib}" && echo yes || echo no)"
    check "run_quiet: a test that fails is a failure" \
        "$(grep -qx 'quiet-fail false' <<< "${lib}" && echo yes || echo no)"
    # }}}

    # {{{ a commit that works
    new_repo "${LUA}-works"
    before="$(git -C "${REPO}" rev-parse main)"
    coc -m "works"; status=$?
    check "a commit that works exits 0" "$( [ ${status} = 0 ] && echo yes || echo no)"
    check "...and lands on main" "$( [ "$(git -C "${REPO}" rev-parse main)" != "${before}" ] \
        && [ "$(git -C "${REPO}" log -1 --format=%s main)" = works ] && echo yes || echo no)"
    check "...and no hook is reported, there being none" \
        "$(grep -q 'hook' "${REPO}.out" && echo no || echo yes)"
    # }}}

    # {{{ a commit git refuses to record
    # The branch's lock file is held, as by another git, so moving the branch
    # fails every time it is tried.
    new_repo "${LUA}-locked"
    before="$(git -C "${REPO}" rev-parse main)"
    : > "${REPO}/.git/refs/heads/main.lock"
    coc -m "locked out"; status=$?
    rm -f "${REPO}/.git/refs/heads/main.lock"
    check "a commit git refuses to record exits non-zero" "$( [ ${status} != 0 ] && echo yes || echo no)"
    check "...says nothing was committed" \
        "$(grep -q 'nothing committed' "${REPO}.out" && ! grep -q 'committed [0-9a-f]' "${REPO}.out" && echo yes || echo no)"
    check "...and main has not moved" "$( [ "$(git -C "${REPO}" rev-parse main)" = "${before}" ] && echo yes || echo no)"
    # }}}

    # {{{ a hook that refuses
    new_repo "${LUA}-refused"
    hooks="$(git -C "${REPO}" rev-parse --absolute-git-dir)/hooks"
    mkdir -p "${hooks}"
    printf '#!/bin/sh\necho "pre-commit says no"\nexit 1\n' > "${hooks}/pre-commit"
    chmod +x "${hooks}/pre-commit"
    before="$(git -C "${REPO}" rev-parse main)"
    coc -m "refused"; status=$?
    check "a refusing pre-commit stops the commit with a non-zero exit" \
        "$( [ ${status} != 0 ] && [ "$(git -C "${REPO}" rev-parse main)" = "${before}" ] && echo yes || echo no)"
    check "...and is reported as failed, not passed" \
        "$(grep -q 'pre-commit FAILED' "${REPO}.out" && ! grep -q 'pre-commit passed' "${REPO}.out" && echo yes || echo no)"
    # }}}
done

printf '\n%d checks, %d failures\n' "${checked}" "${failures}"
[ "${failures}" -eq 0 ]
