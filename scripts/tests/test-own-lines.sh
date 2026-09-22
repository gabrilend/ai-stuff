#!/usr/bin/env bash
#
# test-own-lines.sh
#
# Checks the three pieces of "commit only your own lines" together, in a
# scratch git repository: the edit ledger (record-own-edits and
# claim-own-change), the staging tool (stage-own-changes), and the commit gate
# (refuse-foreign-lines).
#
# The scene it builds: a repository where this session and "someone else" have
# both edited files since the last commit. This session's edits are fed to the
# ledger hook exactly as Claude Code would feed them after an edit, a new file,
# and a shell command that reported a diff; the other person's edits are made
# behind the ledger's back. Then it checks that the staging tool stages only
# this session's lines -- in the right places, even when a skipped change
# above them shifts the line numbers -- that the commit gate lets that index
# through, and that it refuses once a foreign line is staged.
#
# The ledger lives in RAM under a session id made up for the test, and is
# removed afterwards along with the scratch repository.
#
# Exit 0 when everything behaves, 1 otherwise.
#
# Usage: test-own-lines.sh [scripts-directory]

set -uo pipefail

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
SCRATCH="/tmp/claude-1000/f1-tests/own-lines-$$"
REPO="${SCRATCH}/repo"
SESSION="own-lines-test-$$"
LEDGER_DIR="/dev/shm/claude-own-edits/${SESSION}"
TOKEN="${SCRATCH}/token-commit"
export CLAUDE_CODE_SESSION_ID="${SESSION}"
trap 'rm -rf "${SCRATCH}" "${LEDGER_DIR}"' EXIT

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

# {{{ record()
# Feeds one tool result to the ledger hook, as Claude Code would after a tool
# call. Arguments: tool name, then a jq expression building the rest.
record() {
    local tool="$1" body="$2"
    local input
    input="$(jq -n --arg s "${SESSION}" --arg t "${tool}" --arg repo "${REPO}" \
        "{session_id: \$s, tool_name: \$t} + (${body})")"
    "${DIR}/record-own-edits" "${DIR}" <<< "${input}"
}
# }}}

# {{{ gate_verdict()
# Asks the commit gate about a command run from a directory; prints
# "refused" or "allowed". The reason is kept in a file, since the verdict is
# read through a command substitution, which cannot set variables outside it.
REASON_FILE="${SCRATCH}/last-reason"
gate_verdict() {
    local command="$1" cwd="$2"
    local input out
    input="$(jq -n --arg s "${SESSION}" --arg c "${command}" --arg cwd "${cwd}" \
        '{session_id: $s, cwd: $cwd, tool_name: "Bash", tool_input: {command: $c}}')"
    out="$("${DIR}/refuse-foreign-lines" "${TOKEN}" "${DIR}" <<< "${input}")"
    jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<< "${out:-{\}}" > "${REASON_FILE}"
    if [ "$(jq -r '.hookSpecificOutput.permissionDecision // ""' <<< "${out:-{\}}")" = "deny" ]; then
        printf 'refused'
    else
        printf 'allowed'
    fi
}
# }}}

printf '\nSetting up the scratch repository\n'
mkdir -p "${REPO}"
git -C "${REPO}" init -q
git -C "${REPO}" config user.name "test"
git -C "${REPO}" config user.email "test@example.invalid"
printf 'line1\nline2\nline3\nline4\nline5\n' > "${REPO}/a.lua"
printf 'b1\nb2\n' > "${REPO}/b.lua"
printf 'c1\nc2\nc3\n' > "${REPO}/c.lua"
printf -- '-- comment one\nkeep\n' > "${REPO}/d.lua"
printf 'f1\nf2\nf3\n' > "${REPO}/f.lua"
printf 'g1\ng2\ng3\ng4\ng5\ng6\ng7\ng8\ng9\n' > "${REPO}/g.lua"
mkdir -p "${REPO}/proj/src" "${REPO}/proj/llm-transcripts"
printf 's1\n' > "${REPO}/proj/src/e.lua"
printf 'first transcript\n' > "${REPO}/proj/llm-transcripts/t.md"
git -C "${REPO}" add -A
git -C "${REPO}" commit -q -m base
check "scratch repository has a first commit" "$(git -C "${REPO}" rev-parse -q --verify HEAD > /dev/null && echo yes || echo no)"

printf '\nThis session edits, and the ledger hook takes notes\n'
# a.lua: an edit tool changes line 2 and appends a line
printf 'line1\nown-2\nline3\nline4\nline5\nown-6\n' > "${REPO}/a.lua"
record Edit '{tool_input: {file_path: ($repo + "/a.lua")},
  tool_response: {structuredPatch: [
    {oldStart: 1, oldLines: 3, newStart: 1, newLines: 3, lines: [" line1", "-line2", "+own-2", " line3"]},
    {oldStart: 5, oldLines: 1, newStart: 5, newLines: 2, lines: [" line5", "+own-6"]}]}}'
# c.lua: own change on line 2, right next to the other person's on line 3
printf 'c1\nown-c2\nforeign-c3\n' > "${REPO}/c.lua"
record Edit '{tool_input: {file_path: ($repo + "/c.lua")},
  tool_response: {structuredPatch: [{oldStart: 1, oldLines: 2, newStart: 1, newLines: 2, lines: [" c1", "-c2", "+own-c2"]}]}}'
# d.lua: removing a Lua comment and adding a line of pluses -- lines that look
# like diff file headers once marked, which a careless reader mistakes
printf 'keep\n++ plus\n' > "${REPO}/d.lua"
record Edit '{tool_input: {file_path: ($repo + "/d.lua")},
  tool_response: {structuredPatch: [{oldStart: 1, oldLines: 2, newStart: 1, newLines: 2, lines: ["--- comment one", " keep", "+++ plus"]}]}}'
# g.lua: two own changes with a foreign deletion between them, so the second
# own change must be renumbered when the foreign one is skipped
printf 'g1\nown-g2a\nown-g2b\ng3\ng4\ng5\ng6\ng7\nown-g8\ng9\n' > "${REPO}/g.lua"
record Edit '{tool_input: {file_path: ($repo + "/g.lua")},
  tool_response: {structuredPatch: [
    {oldStart: 2, oldLines: 1, newStart: 2, newLines: 2, lines: ["-g2", "+own-g2a", "+own-g2b"]},
    {oldStart: 8, oldLines: 1, newStart: 8, newLines: 1, lines: ["-g8", "+own-g8"]}]}}'
# new.lua: a new file from the write tool
printf 'n1\nn2\n' > "${REPO}/new.lua"
record Write '{tool_input: {file_path: ($repo + "/new.lua"), content: "n1\nn2\n"}, tool_response: {type: "create"}}'
# f.lua: a shell command whose file diff the harness reported
printf 'f1\nf2\nbash-f3\n' > "${REPO}/f.lua"
record Bash '{tool_input: {command: "sed -i s/f3/bash-f3/ f.lua"},
  tool_response: {stdout: "", stderr: "", bashEditDiff: {files: [{filePath: ($repo + "/f.lua"),
    hunks: [{oldStart: 3, oldLines: 1, newStart: 3, newLines: 1, lines: ["-f3", "+bash-f3"]}]}],
    moreFiles: 0, changedFiles: [($repo + "/f.lua")]}}}' > /dev/null
# a shell command that changed a file without a diff: the hook says so
notes="$(record Bash '{tool_input: {command: "generate"}, tool_response: {stdout: "", bashEditDiff: {files: [], moreFiles: 0, changedFiles: [($repo + "/gen.txt")]}}}')"
check "a file changed without a diff is named to the model" \
    "$(jq -r '.hookSpecificOutput.additionalContext // ""' <<< "${notes}" | grep -q 'gen.txt' && echo yes || echo no)"
# gen.txt: produced by that command, then claimed out loud
printf 'generated\n' > "${REPO}/gen.txt"
claimed="$("${DIR}/claim-own-change" "${REPO}/gen.txt" --scripts-dir "${DIR}")"
check "claim-own-change says what it claimed" "$(grep -q 'gen.txt' <<< "${claimed}" && echo yes || echo no)"
# proj/src/e.lua: an own edit inside a project that keeps transcripts
printf 's1\nown-s2\n' > "${REPO}/proj/src/e.lua"
record Edit '{tool_input: {file_path: ($repo + "/proj/src/e.lua")},
  tool_response: {structuredPatch: [{oldStart: 1, oldLines: 1, newStart: 1, newLines: 2, lines: [" s1", "+own-s2"]}]}}'
printf 'second transcript line\n' >> "${REPO}/proj/llm-transcripts/t.md"
check "the ledger exists in RAM" "$( [ -s "${LEDGER_DIR}/ledger.tsv" ] && echo yes || echo no)"

printf '\nSomeone else edits the same files, behind the ledger\x27s back\n'
sed -i 's/^line4$/foreign-4/' "${REPO}/a.lua"
sed -i 's/^b1$/foreign-b1/' "${REPO}/b.lua"
# the foreign deletion of g5, between this session's two g.lua changes
sed -i '/^g5$/d' "${REPO}/g.lua"
check "the foreign deletion of g5 is in the working tree" "$(grep -qx g5 "${REPO}/g.lua" && echo no || echo yes)"
check "the working tree holds both sessions' edits" \
    "$(grep -q foreign-4 "${REPO}/a.lua" && grep -q own-2 "${REPO}/a.lua" && echo yes || echo no)"

printf '\nstage-own-changes stages only this session\x27s lines\n'
stage_report="$("${DIR}/stage-own-changes" "${REPO}" --scripts-dir "${DIR}" 2>&1)"
stage_status=$?
printf '%s\n' "${stage_report}" | sed 's/^/    | /'
check "the staging tool succeeded" "$( [ "${stage_status}" -eq 0 ] && echo yes || echo no)"
staged="$(git -C "${REPO}" diff --cached)"
check "own line added in a.lua is staged" "$(grep -q '^+own-2$' <<< "${staged}" && grep -q '^+own-6$' <<< "${staged}" && echo yes || echo no)"
check "the foreign line in a.lua is not staged" "$(grep -q 'foreign-4' <<< "${staged}" && echo no || echo yes)"
check "b.lua (only foreign lines) is not staged" "$(git -C "${REPO}" diff --cached --name-only | grep -qx 'b.lua' && echo no || echo yes)"
check "c.lua (own line touching a foreign one) is left out" "$(git -C "${REPO}" diff --cached --name-only | grep -qx 'c.lua' && echo no || echo yes)"
check "the mixed block is reported by file and line" "$(grep -q 'c.lua:2 (mixed)' <<< "${stage_report}" && echo yes || echo no)"
check "a removed '-- comment' and an added '++ plus' line are staged" \
    "$(git -C "${REPO}" show :d.lua | tr '\n' '|' | grep -qx 'keep|++ plus|' && echo yes || echo no)"
check "g.lua's second own change landed on the right line after the skipped one" \
    "$(git -C "${REPO}" show :g.lua | diff -q - <(printf 'g1\nown-g2a\nown-g2b\ng3\ng4\ng5\ng6\ng7\nown-g8\ng9\n') > /dev/null && echo yes || echo no)"
check "a new file written by this session is staged" "$(git -C "${REPO}" diff --cached --name-only | grep -qx 'new.lua' && echo yes || echo no)"
check "a file changed by a shell command with a diff is staged" "$(git -C "${REPO}" show :f.lua | grep -qx 'bash-f3' && echo yes || echo no)"
check "a claimed generated file is staged" "$(git -C "${REPO}" diff --cached --name-only | grep -qx 'gen.txt' && echo yes || echo no)"
check "the project's transcripts ride along" "$(git -C "${REPO}" diff --cached --name-only | grep -qx 'proj/llm-transcripts/t.md' && echo yes || echo no)"
check "the working tree still holds the foreign edits" "$(grep -q foreign-4 "${REPO}/a.lua" && echo yes || echo no)"

printf '\nThe commit gate\n'
check "an index of only this session's lines is allowed" \
    "$( [ "$(gate_verdict 'git commit -m own' "${REPO}")" = "allowed" ] && echo yes || echo no)"
check "the same, named with -C from another directory" \
    "$( [ "$(gate_verdict "git -C ${REPO} commit -F -" "/tmp")" = "allowed" ] && echo yes || echo no)"
git -C "${REPO}" commit -q -m "own work"
check "the commit carries own lines in place and leaves the foreign ones out" \
    "$(git -C "${REPO}" show HEAD:a.lua | tr '\n' '|' | grep -qx 'line1|own-2|line3|line4|line5|own-6|' && echo yes || echo no)"

git -C "${REPO}" add b.lua
check "a staged foreign line is refused" \
    "$( [ "$(gate_verdict 'git commit -m more' "${REPO}")" = "refused" ] && echo yes || echo no)"
check "the refusal names the file and line" "$(grep -q 'b.lua:1 + foreign-b1' "${REASON_FILE}" && echo yes || echo no)"
check "the refusal says not to unstage someone else's work without asking" "$(grep -q 'ask' "${REASON_FILE}" && echo yes || echo no)"
check "the gate reads the repository named by -C, not the current one" \
    "$( [ "$(gate_verdict "git -C ${REPO} commit -m more" "/tmp")" = "refused" ] && echo yes || echo no)"
check "an unrelated command on a foreign index is not the gate's business" \
    "$( [ "$(gate_verdict 'git status' "${REPO}")" = "allowed" ] && echo yes || echo no)"
touch "${TOKEN}"
check "a token lets that commit through once" \
    "$( [ "$(gate_verdict 'git commit -m more' "${REPO}")" = "allowed" ] && [ ! -e "${TOKEN}" ] && echo yes || echo no)"
check "and only once" \
    "$( [ "$(gate_verdict 'git commit -m more' "${REPO}")" = "refused" ] && echo yes || echo no)"
git -C "${REPO}" restore --staged b.lua
check "once the foreign line is unstaged, the commit is allowed again" \
    "$( [ "$(gate_verdict 'git commit -m more' "${REPO}")" = "allowed" ] && echo yes || echo no)"
check "rewording the last commit is allowed" \
    "$( [ "$(gate_verdict 'git commit --amend --only -F -' "${REPO}")" = "allowed" ] && echo yes || echo no)"

printf '\n%s checks, %s failures\n' "${checked}" "${failures}"
[ "${failures}" -eq 0 ] || exit 1
exit 0
