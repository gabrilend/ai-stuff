#!/usr/bin/env bash
#
# test-answer-outside-write.sh - proves the Yes / This time / Always / No
# question works end to end: the write gate refuses and files a request, the
# person's answer (as Claude Code records it) is read by the answer hook, and
# the gate then honours exactly what was answered, and nothing else.
#
# In plain terms: two pretend projects and pretend "elsewhere" folders in a
# scratch folder; the gate is asked about a write to elsewhere, the question
# it hands back is "answered" the way Claude Code would report it, and the
# gate is asked again. Always must hold only for the project that answered
# it. Agents that reword the question, answer in advance, or answer another
# session's question get nothing.
#
# Usage:
#   tests/test-answer-outside-write.sh [scripts-dir]
#
# Exits 0 when every case passes, 1 otherwise, naming each failure.

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

GATE="${DIR}/harness-hooks/refuse-outside-writes"
ANSWER="${DIR}/harness-hooks/answer-outside-write"
FORGET="${DIR}/harness-hooks/forget-session-permits"

SCRATCH="$(mktemp -d /tmp/claude-1000/test-answer-outside-write.XXXXXX)"
trap 'rm -rf "${SCRATCH}"' EXIT
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
export CLAUDE_CODE_TMPDIR="${SCRATCH}/claude-temp"
export OUTSIDE_WRITE_STATE="${SCRATCH}/permits"
export OUTSIDE_WRITE_ALLOWED="${SCRATCH}/allowed-folders"
P="${SCRATCH}/project"
P2="${SCRATCH}/other-project"
E="${SCRATCH}/elsewhere"
F="${SCRATCH}/further"
T="${SCRATCH}/for-a-while"
TOKEN="${SCRATCH}/no-token"
mkdir -p "${P}" "${P2}" "${E}/inner" "${F}" "${T}" "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}" "${CLAUDE_CODE_TMPDIR}"
SESSION="cccc-3333"

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

# {{{ ask_gate
# The gate's raw answer to one write, as a session (default ${SESSION})
# working in a folder (default ${P}).
ask_gate() {
    local command="$1" session="${2:-${SESSION}}" cwd="${3:-${P}}"
    jq -n --arg c "${command}" --arg cwd "${cwd}" --arg s "${session}" \
        '{tool_name: "Bash", tool_input: {command: $c}, cwd: $cwd, session_id: $s}' \
        | "${GATE}" "${TOKEN}" "${DIR}" 2>/dev/null
}
# }}}

# {{{ verdict
verdict() {
    local out
    out="$(ask_gate "$@")"
    if [ -z "${out}" ]; then printf 'silent'; return; fi
    case "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<< "${out}")" in
        deny)  printf 'refused' ;;
        *)     printf 'other' ;;
    esac
}
# }}}

# {{{ questions_from
# The questions list the gate's refusal hands the agent (JSON array).
questions_from() {
    local out="$1" reason
    reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "${out}")"
    sed -n 's/.*with no answers filled in: \({"questions".*}\) If they answer Yes.*/\1/p' <<< "${reason}" | jq -c '.questions'
}
# }}}

# {{{ answer_with
# Plays Claude Code reporting the person picked `label` for the question
# given (a JSON array of one), as a session; prints the hook's output.
answer_with() {
    local questions="$1" label="$2" session="${3:-${SESSION}}"
    jq -n --argjson qs "${questions}" --arg label "${label}" --arg s "${session}" \
        '{hook_event_name: "PostToolUse", tool_name: "AskUserQuestion", session_id: $s,
          tool_input: {questions: $qs},
          tool_response: {questions: $qs, answers: {($qs[0].question): $label}}}' \
        | "${ANSWER}" "${DIR}" 2>/dev/null
}
# }}}

context_of() { jq -r '.hookSpecificOutput.additionalContext // empty' <<< "$1"; }
yes_if() { if "$@"; then printf yes; else printf no; fi; }

# --- the question
out="$(ask_gate "echo x > ${E}/a.txt")"
check "a write elsewhere is refused" "$(yes_if [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "${out}")" = deny ])"
qs="$(questions_from "${out}")"
check "one question is handed over" "$(yes_if [ "$(jq length <<< "${qs}")" = 1 ])"
check "its answers: Yes, This time, Always, No" "$(yes_if [ "$(jq -r '[.[0].options[].label] | join(",")' <<< "${qs}")" = "Yes,This time,Always,No" ])"
check "the question names the place" "$(yes_if grep -qF "${E}/a.txt" <<< "$(jq -r '.[0].question' <<< "${qs}")")"
check "This time names the folder" "$(yes_if grep -qF "${E}" <<< "$(jq -r '.[0].options[1].description' <<< "${qs}")")"
check "Always names the folder and the project it belongs to" "$(yes_if [ -n "$(jq -r '.[0].options[2].description' <<< "${qs}" | grep -F "${E}" | grep -F "${P}")" ])"

# --- Yes: one write, for that session, for those places
said="$(context_of "$(answer_with "${qs}" Yes)")"
check "Yes is acknowledged" "$(yes_if grep -q "answered Yes" <<< "${said}")"
check "after Yes, another session is still refused" "$(yes_if [ "$(verdict "echo x > ${E}/a.txt" dddd-4444)" = refused ])"
check "after Yes, a file beside it is still refused" "$(yes_if [ "$(verdict "echo x > ${E}/beside.txt")" = refused ])"
check "after Yes, the write goes through once" "$(yes_if [ "$(verdict "echo x > ${E}/a.txt")" = silent ])"
check "and only once" "$(yes_if [ "$(verdict "echo x > ${E}/a.txt")" = refused ])"

# --- the same question cannot be answered twice
said="$(context_of "$(answer_with "${qs}" Yes)")"
check "an answered request is closed" "$(yes_if grep -q "No open request" <<< "${said}")"

# --- No, and things that are not answers
qs="$(questions_from "$(ask_gate "echo x > ${F}/n.txt")")"
said="$(context_of "$(answer_with "${qs}" No)")"
check "No is told to the agent" "$(yes_if grep -q "did not allow" <<< "${said}")"
check "after No, still refused" "$(yes_if [ "$(verdict "echo x > ${F}/n.txt")" = refused ])"
qs="$(questions_from "$(ask_gate "echo x > ${F}/o.txt")")"
answer_with "${qs}" "I typed something else" > /dev/null
check "a typed-in answer grants nothing" "$(yes_if [ "$(verdict "echo x > ${F}/o.txt")" = refused ])"

# --- the agent cannot change what the person agrees to
qs="$(questions_from "$(ask_gate "echo x > ${F}/r.txt")")"
reworded="$(jq -c '.[0].options[2].description = "Harmless, just this once."' <<< "${qs}")"
said="$(context_of "$(answer_with "${reworded}" Always)")"
check "a reworded question grants nothing" "$(yes_if grep -q "not asked exactly" <<< "${said}")"
check "and the folder is not allowed" "$(yes_if [ "$(verdict "echo x > ${F}/r.txt")" = refused ])"
qs="$(questions_from "$(ask_gate "echo x > ${F}/s.txt")")"
said="$(context_of "$(answer_with "${qs}" Yes dddd-4444)")"
check "another session's answer grants nothing" "$(yes_if grep -q "another session" <<< "${said}")"
check "for either session" "$(yes_if [ "$(verdict "echo x > ${F}/s.txt")" = refused ])"
q0="$(jq -c '.[0]' <<< "$(questions_from "$(ask_gate "echo x > ${F}/u.txt")")")"
pre="$(jq -n --argjson q "${q0}" '{hook_event_name: "PreToolUse", tool_name: "AskUserQuestion", session_id: "cccc-3333",
        tool_input: {questions: [$q], answers: {($q.question): "Always"}}}' | "${ANSWER}" "${DIR}" 2>/dev/null)"
check "a question arriving with answers filled in is refused" "$(yes_if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<< "${pre}")" = deny ])"
plain="$(jq -n '{hook_event_name: "PreToolUse", tool_name: "AskUserQuestion", session_id: "cccc-3333",
        tool_input: {questions: [{question: "Which colour?", header: "Colour", multiSelect: false, options: [{label: "Red", description: "r"}, {label: "Blue", description: "b"}]}]}}' | "${ANSWER}" "${DIR}" 2>/dev/null)"
check "an ordinary question passes untouched" "$(yes_if [ -z "${plain}" ])"

# --- Always: the file's folder, this project only, from now on
qs="$(questions_from "$(ask_gate "echo x > ${E}/inner/d.txt")")"
said="$(context_of "$(answer_with "${qs}" Always)")"
check "Always is acknowledged, naming the project" "$(yes_if grep -qF "sessions working in ${P}" <<< "${said}")"
check "the list line names project, kind and folder" "$(yes_if grep -qxF "$(printf '%s\tfolder\t%s' "${P}" "${E}/inner")" "${OUTSIDE_WRITE_ALLOWED}")"
check "the write goes through" "$(yes_if [ "$(verdict "echo x > ${E}/inner/d.txt")" = silent ])"
check "a new file beside it goes through" "$(yes_if [ "$(verdict "echo x > ${E}/inner/new.txt")" = silent ])"
check "for another session in the same project" "$(yes_if [ "$(verdict "echo x > ${E}/inner/new.txt" eeee-5555)" = silent ])"
check "but not for a session in another project" "$(yes_if [ "$(verdict "echo x > ${E}/inner/new.txt" eeee-5555 "${P2}")" = refused ])"
check "the folder above is still refused" "$(yes_if [ "$(verdict "echo x > ${E}/up.txt")" = refused ])"
qs="$(questions_from "$(ask_gate "echo x > ${E}/inner/x/y.txt")")"
check "a place already covered is never asked about" "$(yes_if [ -z "${qs}" ])"

# --- This time: the file's folder, this session only, until it ends
qs="$(questions_from "$(ask_gate "echo x > ${T}/a.txt")")"
said="$(context_of "$(answer_with "${qs}" "This time")")"
check "This time is acknowledged" "$(yes_if grep -q "answered This time" <<< "${said}")"
check "the write goes through" "$(yes_if [ "$(verdict "echo x > ${T}/a.txt")" = silent ])"
check "a new file beside it goes through" "$(yes_if [ "$(verdict "echo x > ${T}/b.txt")" = silent ])"
check "another session in the same project is still refused" "$(yes_if [ "$(verdict "echo x > ${T}/a.txt" ffff-6666)" = refused ])"
check "it is not on the list on disk" "$(yes_if [ -z "$(grep -F "${T}" "${OUTSIDE_WRITE_ALLOWED}")" ])"

# --- the session ends
qs="$(questions_from "$(ask_gate "echo x > ${F}/unspent.txt")")"
answer_with "${qs}" Yes > /dev/null
jq -n --arg s "${SESSION}" '{hook_event_name: "SessionEnd", session_id: $s}' | "${FORGET}" "${DIR}" 2>/dev/null
check "after the session ends, This time is forgotten" "$(yes_if [ "$(verdict "echo x > ${T}/a.txt")" = refused ])"
check "and an unspent Yes" "$(yes_if [ "$(verdict "echo x > ${F}/unspent.txt")" = refused ])"
check "but Always stays" "$(yes_if [ "$(verdict "echo x > ${E}/inner/d.txt")" = silent ])"
jq -n '{hook_event_name: "SessionEnd", session_id: "../../etc"}' | "${FORGET}" "${DIR}" 2>/dev/null
check "a crafted session id removes nothing" "$(yes_if [ -f "${OUTSIDE_WRITE_ALLOWED}" ])"

# --- a file-wide line (the format keeps the kind) covers just its file
printf '%s\tfile\t%s\n' "${P}" "${F}/exact.txt" >> "${OUTSIDE_WRITE_ALLOWED}"
check "a file line lets its file through" "$(yes_if [ "$(verdict "echo x > ${F}/exact.txt")" = silent ])"
check "and not the file beside it" "$(yes_if [ "$(verdict "echo x > ${F}/beside.txt")" = refused ])"

# --- an expired request grants nothing
qs="$(questions_from "$(ask_gate "echo x > ${F}/late.txt")")"
id="$(jq -r '.[0].question' <<< "${qs}" | sed -n 's/.*\[outside-write \([0-9a-f]*\)\].*/\1/p')"
jq -c '.made = 0' "${OUTSIDE_WRITE_STATE}/requests/${id}.json" > "${SCRATCH}/old.json"
mv "${SCRATCH}/old.json" "${OUTSIDE_WRITE_STATE}/requests/${id}.json"
said="$(context_of "$(answer_with "${qs}" Yes)")"
check "an expired request grants nothing" "$(yes_if grep -q "No open request" <<< "${said}")"
check "and the write is still refused" "$(yes_if [ "$(verdict "echo x > ${F}/late.txt")" = refused ])"

printf '%s passed, %s failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
