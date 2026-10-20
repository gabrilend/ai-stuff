#!/usr/bin/env bash
#
# test-refuse-outside-writes.sh - proves the shell-write gate refuses a
# command that writes outside the session's folder, and stays silent for one
# that writes only inside it (leaving Claude Code's classifier to judge).
#
# In plain terms: builds a pretend project with its RAM scratch rooms in a
# scratch folder, then hands the gate one shell command at a time, as Claude
# Code would before running it, and checks the answer: "refused", or
# "silent". The gate must never answer "allow" -- that would skip the
# classifier -- so any allow is a failure. The cases live in this file, not
# typed at a prompt, since the live gate would refuse the bad ones.
#
# Usage:
#   tests/test-refuse-outside-writes.sh [scripts-dir]
#
# Exits 0 when every case passes, 1 otherwise, naming each failure.

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

GATE="${DIR}/harness-hooks/refuse-outside-writes"

SCRATCH="$(mktemp -d /tmp/claude-1000/test-refuse-outside-writes.XXXXXX)"
trap 'rm -rf "${SCRATCH}"' EXIT
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
# Claude Code's temp root, stood in the scratch folder: this session's
# scratchpad (aaaa-1111, the id every case below carries) and another's
export CLAUDE_CODE_TMPDIR="${SCRATCH}/claude-temp"
OWN_PAD="${CLAUDE_CODE_TMPDIR}/-some-project/aaaa-1111/scratchpad"
OTHER_PAD="${CLAUDE_CODE_TMPDIR}/-some-project/bbbb-2222/scratchpad"
mkdir -p "${OWN_PAD}" "${OTHER_PAD}"
P="${SCRATCH}/projects/alpha"
OTHER="${SCRATCH}/projects/beta"
TOKEN="${SCRATCH}/token"
mkdir -p "${P}/src" "${OTHER}" "${EXEC_TIER_ROOT}/alpha/tmp" "${ARTIFACT_TIER_ROOT}/alpha" "${ARTIFACT_TIER_ROOT}/beta"
ln -s "${EXEC_TIER_ROOT}/alpha" "${P}/tmp"
ln -s "${ARTIFACT_TIER_ROOT}/alpha" "${EXEC_TIER_ROOT}/alpha/shared-memory"
ln -s "${P}" "${SCRATCH}/alpha-by-another-name"

PASSED=0
FAILED=0

# {{{ answer_of
# Feeds one command to the gate from the session folder ${P} (or ASK_CWD)
# and prints "refused", "silent", "warned", or "ALLOWED" (always wrong).
answer_of() {
    local command="$1"
    local input out decision
    input="$(printf '%s' "${command}" | jq -Rs --arg cwd "${ASK_CWD:-${P}}" \
        '{tool_name: "Bash", tool_input: {command: .}, cwd: $cwd, session_id: "aaaa-1111"}')"
    out="$("${GATE}" "${TOKEN}" "${DIR}" <<< "${input}" 2>/dev/null)"
    if [ -z "${out}" ]; then printf 'silent'; return; fi
    decision="$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<< "${out}")"
    case "${decision}" in
        deny)  printf 'refused' ;;
        allow) printf 'ALLOWED' ;;
        *)     printf 'warned' ;;
    esac
}
# }}}

# {{{ expect
expect() {
    local want="$1" command="$2"
    local got
    got="$(answer_of "${command}")"
    if [ "${got}" = "${want}" ]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL: %s (wanted %s, got %s)\n' "${command}" "${want}" "${got}"
    fi
}
# }}}

O="${OTHER}/file"

# nothing written: silent
expect silent "ls ${OTHER}"
expect silent "cat ${OTHER}/x | grep y"
expect silent "sed -n 1p ${O}"
expect silent "find ${OTHER} -name '*.lua'"
expect silent "echo hi 2>&1"
expect silent "make >&2"
expect silent "grep x <<< \"> ${O}\""
expect silent "echo '> ${O}'"

# redirections
expect refused "echo hi > ${O}"
expect refused "echo hi >> ${O}"
expect refused "echo hi &> ${O}"
expect refused "echo hi >| ${O}"
expect silent  "echo hi > ${P}/out.txt"
expect silent  "echo hi > src/out.txt"
expect silent  "echo hi > /dev/null"
expect silent  "echo hi 2>/dev/null >/dev/stderr"
expect refused "echo hi > ../beta/file"
expect refused "echo hi > src/../../beta/file"

# the RAM rooms, by every name
expect silent  "echo hi > tmp/shared-memory/run.log"
expect silent  "echo hi > ${ARTIFACT_TIER_ROOT}/alpha/run.log"
expect silent  "echo hi > ${EXEC_TIER_ROOT}/alpha/tmp/x.lua"
expect refused "echo hi > ${ARTIFACT_TIER_ROOT}/beta/run.log"
expect refused "echo hi > ${ARTIFACT_TIER_ROOT}/alpha-other/run.log"

# the session's folder by another name
expect silent  "echo hi > ${SCRATCH}/alpha-by-another-name/x"

# commands that write
expect refused "sed -i s/a/b/ ${O}"
expect refused "sed -i.bak -e s/a/b/ ${O}"
expect refused "sed --in-place=.bak s/a/b/ ${O}"
expect refused "sed -ni s/a/b/p ${O}"
expect silent  "sed -i s/a/b/ src/x.lua"
expect silent  "sed s/a/b/ ${O}"
expect refused "perl -pi -e s/a/b/ ${O}"
expect silent  "perl -Mstrict -e 'print 1' ${O}"
expect refused "printf x | tee ${O}"
expect refused "tee -a ${O} < src/x"
expect refused "cp src/x ${O}"
expect silent  "cp ${O} src/x"
expect refused "cp -t ${OTHER} src/x"
expect refused "mv ${O} src/x"
expect refused "mv src/x ${O}"
expect silent  "mv src/x src/y"
expect refused "rm -rf ${OTHER}"
expect silent  "rm -rf src/old tmp/shared-memory/old.log"
expect refused "touch ${O}"
expect refused "mkdir -p ${OTHER}/new"
expect refused "chmod +x ${O}"
expect silent  "chmod +x src/run"
expect refused "ln -s src/x ${O}"
expect refused "install -m 755 src/x ${O}"
expect refused "truncate -s 0 ${O}"
expect refused "dd if=/dev/zero of=${O} bs=1 count=1"
expect refused "curl -o ${O} https://example.com"
expect refused "wget -O ${O} https://example.com"
expect refused "tar czf ${O} src"
expect silent  "tar czf src.tgz src"
expect refused "tar xzf src.tgz -C ${OTHER}"
expect refused "unzip a.zip -d ${OTHER}"
expect refused "find ${OTHER} -name '*.o' -delete"
expect silent  "find src -name '*.o' -delete"
expect refused "rsync -a src/ ${OTHER}/"
expect silent  "rsync -a src/ host:/elsewhere/"

# wrappers and nesting
expect refused "sudo rm ${O}"
expect refused "FOO=1 timeout 5 rm ${O}"
expect refused "if true; then rm ${O}; fi"
expect refused "bash -c 'echo x > ${O}'"
expect refused "eval \"rm ${O}\""
expect refused "echo \$(rm ${O})"
expect refused "cat <<EOF > ${O}
body
EOF"
expect silent  "cat <<EOF > src/notes
rm ${O}
EOF"

# variables
expect refused "F=${O}; echo x > \$F"
expect silent  "F=src/x; echo x > \"\${F}\""
expect refused "echo x > \$NOT_SET_ANYWHERE_REALLY/x"
expect refused "echo x > \$(mktemp)"
expect refused "echo x > ~/elsewhere"
HOME="${P}" expect silent "echo x > ~/src/x"

# the session folder decides; a subfolder has no rooms
ASK_CWD="${P}/src" expect refused "echo x > ${P}/tmp/shared-memory/run.log"
ASK_CWD="${P}/src" expect silent  "echo x > ${P}/src/x"

# the one-time permission
touch "${TOKEN}"
expect silent "rm ${O}"
if [ -e "${TOKEN}" ]; then
    FAILED=$((FAILED + 1)); printf 'FAIL: the permission was not spent\n'
else
    PASSED=$((PASSED + 1))
fi
expect refused "rm ${O}"
touch "${TOKEN}"
expect silent "ls"
if [ -e "${TOKEN}" ]; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1)); printf 'FAIL: a command writing nothing spent the permission\n'
fi
rm -f "${TOKEN}"

# the refusal names the place and the way through
input="$(jq -n --arg cwd "${P}" --arg c "rm ${O}" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $cwd}')"
reason="$("${GATE}" "${TOKEN}" "${DIR}" <<< "${input}" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
if grep -qF "${O}" <<< "${reason}" && grep -qF "touch ${TOKEN}" <<< "${reason}"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1)); printf 'FAIL: the refusal does not name the place and the token: %s\n' "${reason}"
fi

# the file tools: the path they name
# {{{ tool_answer
tool_answer() {
    local tool="$1" field="$2" path="$3"
    local out
    out="$(jq -n --arg cwd "${ASK_CWD:-${P}}" --arg tool "${tool}" --arg field "${field}" --arg path "${path}" \
        '{tool_name: $tool, tool_input: {($field): $path}, cwd: $cwd, session_id: "aaaa-1111"}' | "${GATE}" "${TOKEN}" "${DIR}" 2>/dev/null)"
    if [ -z "${out}" ]; then printf 'silent'; return; fi
    case "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<< "${out}")" in
        deny)  printf 'refused' ;;
        allow) printf 'ALLOWED' ;;
        *)     printf 'warned' ;;
    esac
}
# }}}
# {{{ expect_tool
expect_tool() {
    local want="$1" tool="$2" field="$3" path="$4"
    local got
    got="$(tool_answer "${tool}" "${field}" "${path}")"
    if [ "${got}" = "${want}" ]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        printf 'FAIL: %s %s (wanted %s, got %s)\n' "${tool}" "${path}" "${want}" "${got}"
    fi
}
# }}}
expect_tool refused Edit         file_path     "${O}"
expect_tool refused Write        file_path     "${O}"
expect_tool refused MultiEdit    file_path     "${O}"
expect_tool refused NotebookEdit notebook_path "${OTHER}/n.ipynb"
expect_tool silent  Write        file_path     "${P}/src/new.lua"
expect_tool refused Edit         file_path     "src/x.lua"
expect_tool refused Write        file_path     "~/.claude/skills/x/SKILL.md"
expect_tool refused Write        file_path     "../../../../home/elsewhere/x"
expect_tool silent  Write        file_path     "${P}/tmp/shared-memory/run.log"
expect_tool silent  Write        file_path     "${EXEC_TIER_ROOT}/alpha/agent-scratchpads/x"
expect_tool refused Write        file_path     "${ARTIFACT_TIER_ROOT}/beta/x"
expect_tool silent  Read         file_path     "${O}"
expect_tool silent  Grep         path          "${OTHER}"
expect_tool silent  Glob         path          "${OTHER}"
expect_tool silent  Write        content       "no path given"

# Claude Code's scratchpad: this session's own, and nobody else's
expect silent  "echo x > ${OWN_PAD}/notes.txt"
expect silent  "mkdir -p ${OWN_PAD}/deeper/still"
expect refused "echo x > ${OTHER_PAD}/notes.txt"
expect refused "echo x > ${CLAUDE_CODE_TMPDIR}/-some-project/aaaa-1111/tasks/x"
expect_tool silent  Write file_path "${OWN_PAD}/plan.md"
expect_tool refused Write file_path "${OTHER_PAD}/plan.md"
# Claude Code makes the scratchpad on first use, so a write into one not
# made yet must pass (found live: a mkdir into a fresh scratchpad refused)
expect silent  "mkdir -p ${CLAUDE_CODE_TMPDIR}/-a-fresh-slug/aaaa-1111/scratchpad/new"
expect_tool silent  Write file_path "${CLAUDE_CODE_TMPDIR}/-a-fresh-slug/aaaa-1111/scratchpad/plan.md"
expect refused "echo x > ${CLAUDE_CODE_TMPDIR}/-a-fresh-slug/aaaa-1111/scratchpad-not/x"
expect refused "echo x > ${CLAUDE_CODE_TMPDIR}/aaaa-1111/scratchpad/x"

# a place that cannot be pinned down is refused even with a permission
# waiting, and the permission is kept for a write it can cover
touch "${TOKEN}"
expect_tool refused Write file_path "~/.claude/settings.json"
expect_tool refused Edit  file_path "relative/file"
expect refused "echo x > \$UNSET_SOMEWHERE_ELSE/x"
if [ -e "${TOKEN}" ]; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1)); printf 'FAIL: an unplaceable write spent the permission\n'
fi
expect_tool silent Write file_path "${O}"
if [ -e "${TOKEN}" ]; then
    FAILED=$((FAILED + 1)); printf 'FAIL: the kept permission did not cover an absolute path\n'
else
    PASSED=$((PASSED + 1))
fi

# input it cannot read is announced
ASK_CWD="relative" expect warned "rm ${O}"
out="$(printf 'not json' | "${GATE}" "${TOKEN}" "${DIR}" 2>/dev/null)"
if [ -n "$(jq -r '.systemMessage // empty' <<< "${out}")" ]; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1)); printf 'FAIL: unreadable input was not announced (got %s)\n' "${out}"
fi

printf '%s passed, %s failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
