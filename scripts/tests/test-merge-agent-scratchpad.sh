#!/usr/bin/env bash
#
# test-merge-agent-scratchpad.sh - proves the session-end hook carries a
# session's scratchpad into its project's RAM room, and leaves it alone when
# there is nowhere to carry it.
#
# In plain terms: builds a pretend Claude Code temp folder and a pretend
# project with its RAM rooms, all in a scratch folder, then tells the hook a
# session ended, and looks at where the files went.
#
# Usage:
#   tests/test-merge-agent-scratchpad.sh [scripts-dir]
#
# Exits 0 when every case passes, 1 otherwise, naming each failure.

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

HOOK="${DIR}/harness-hooks/merge-agent-scratchpad"

SCRATCH="$(mktemp -d /tmp/claude-1000/test-merge-agent-scratchpad.XXXXXX)"
trap 'rm -rf "${SCRATCH}"' EXIT
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
export CLAUDE_CODE_TMPDIR="${SCRATCH}/claude-temp"
P="${SCRATCH}/projects/alpha"
mkdir -p "${P}" "${SCRATCH}/projects/no-link" "${EXEC_TIER_ROOT}/alpha" "${ARTIFACT_TIER_ROOT}/alpha"
ln -s "${EXEC_TIER_ROOT}/alpha" "${P}/tmp"
ln -s "${ARTIFACT_TIER_ROOT}/alpha" "${EXEC_TIER_ROOT}/alpha/shared-memory"

PASSED=0
FAILED=0

# {{{ check
check() {
    local label="$1" result="$2"
    if [ "${result}" = yes ]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL: %s\n' "${label}"
    fi
}
# }}}

# {{{ end_session
# Tells the hook a session ended in a folder; prints the hook's exit code.
end_session() {
    local session="$1" cwd="$2"
    jq -n --arg s "${session}" --arg c "${cwd}" '{hook_event_name: "SessionEnd", session_id: $s, cwd: $c}' \
        | "${HOOK}" "${DIR}" 2>> "${SCRATCH}/hook-stderr.log"
    printf '%s' "$?"
}
# }}}

pad_of() { printf '%s' "${CLAUDE_CODE_TMPDIR}/-projects-alpha/$1/scratchpad"; }
yes_if() { if "$@"; then printf yes; else printf no; fi; }

# a session with files: they move into the project's room
mkdir -p "$(pad_of s-one)/sub"
printf 'a\n' > "$(pad_of s-one)/notes.md"
printf 'b\n' > "$(pad_of s-one)/sub/deep.txt"
code="$(end_session s-one "${P}")"
check "exits 0 after a move" "$(yes_if [ "${code}" = 0 ])"
check "the files arrive" "$(yes_if [ -f "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/s-one/notes.md" ])"
check "folders inside come along" "$(yes_if [ -f "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/s-one/sub/deep.txt" ])"
check "the scratchpad is gone" "$(yes_if [ ! -e "$(pad_of s-one)" ])"

# a resumed session ending again: merged, newer file wins, older kept
mkdir -p "$(pad_of s-one)"
printf 'newer\n' > "$(pad_of s-one)/notes.md"
printf 'c\n' > "$(pad_of s-one)/second.txt"
end_session s-one "${P}" > /dev/null
check "a second ending merges" "$(yes_if [ -f "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/s-one/second.txt" ])"
check "and keeps what came before" "$(yes_if [ -f "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/s-one/sub/deep.txt" ])"
check "a file of the same name is the newer one" "$(yes_if grep -q newer "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/s-one/notes.md")"

# another session's scratchpad is never touched
mkdir -p "$(pad_of s-other)"
printf 'x\n' > "$(pad_of s-other)/theirs"
mkdir -p "$(pad_of s-two)"
printf 'y\n' > "$(pad_of s-two)/mine"
end_session s-two "${P}" > /dev/null
check "another session's scratchpad stays" "$(yes_if [ -f "$(pad_of s-other)/theirs" ])"

# a folder with no tmp link: left where it is
mkdir -p "$(pad_of s-three)"
printf 'z\n' > "$(pad_of s-three)/kept"
code="$(end_session s-three "${SCRATCH}/projects/no-link")"
check "no link: exits 0" "$(yes_if [ "${code}" = 0 ])"
check "no link: the scratchpad stays" "$(yes_if [ -f "$(pad_of s-three)/kept" ])"

# an empty scratchpad, or none: nothing happens
mkdir -p "$(pad_of s-empty)"
end_session s-empty "${P}" > /dev/null
check "an empty scratchpad makes no folder" "$(yes_if [ ! -e "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/s-empty" ])"
code="$(end_session s-never "${P}")"
check "no scratchpad at all: exits 0" "$(yes_if [ "${code}" = 0 ])"

# an id that is not one Claude Code would give finds nothing
code="$(end_session '../..' "${P}")"
check "a crafted id: exits 0" "$(yes_if [ "${code}" = 0 ])"
check "a crafted id: nothing moved" "$(yes_if [ -f "$(pad_of s-other)/theirs" ])"

# a copy that cannot be made: exit 1, scratchpad left whole
mkdir -p "$(pad_of s-stuck)"
printf 'w\n' > "$(pad_of s-stuck)/precious"
mkdir -p "${EXEC_TIER_ROOT}/alpha/agent-scratchpads"
printf 'not a folder\n' > "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/s-stuck"
code="$(end_session s-stuck "${P}")"
check "a failed copy exits 1" "$(yes_if [ "${code}" = 1 ])"
check "and leaves the scratchpad whole" "$(yes_if [ -f "$(pad_of s-stuck)/precious" ])"

printf '%s passed, %s failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
