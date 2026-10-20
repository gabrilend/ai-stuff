#!/usr/bin/env bash
#
# test-answer-outside-write.sh - proves the Yes / Always / No question works
# end to end: the write gate refuses and files a request, the person's
# answer (as Claude Code records it) is read by the answer hook, and the
# gate then honours exactly what was answered, and nothing else.
#
# In plain terms: a pretend project and a pretend "elsewhere" folder in a
# scratch folder; the gate is asked about a write to elsewhere, the question
# it hands back is "answered" the way Claude Code would report it, and the
# gate is asked again. Agents that reword the question, answer in advance,
# or answer another session's question get nothing.
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

SCRATCH="$(mktemp -d /tmp/claude-1000/test-answer-outside-write.XXXXXX)"
trap 'rm -rf "${SCRATCH}"' EXIT
export EXEC_TIER_ROOT="${SCRATCH}/exec"
export ARTIFACT_TIER_ROOT="${SCRATCH}/shm"
export CLAUDE_CODE_TMPDIR="${SCRATCH}/claude-temp"
export OUTSIDE_WRITE_STATE="${SCRATCH}/permits"
export OUTSIDE_WRITE_ALLOWED="${SCRATCH}/allowed-folders"
P="${SCRATCH}/project"
E="${SCRATCH}/elsewhere"
F="${SCRATCH}/further"
TOKEN="${SCRATCH}/no-token"
mkdir -p "${P}" "${E}/inner" "${F}" "${EXEC_TIER_ROOT}" "${ARTIFACT_TIER_ROOT}" "${CLAUDE_CODE_TMPDIR}"
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
# The gate's raw answer to one write, as the given session.
ask_gate() {
    local command="$1" session="${2:-${SESSION}}"
    jq -n --arg c "${command}" --arg cwd "${P}" --arg s "${session}" \
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

# {{{ question_from
# The question object the gate's refusal hands the agent.
question_from() {
    local out="$1" reason
    reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<< "${out}")"
    # the question is the JSON after "word for word, with no answers filled in: "
    sed -n 's/.*with no answers filled in: \({"questions".*}\) If they answer Yes.*/\1/p' <<< "${reason}" | jq -c '.questions[0]'
}
# }}}

# {{{ answer_with
# Plays Claude Code reporting that the person picked `label` for `question`
# (a question object), as the given session; prints the hook's output.
answer_with() {
    local question="$1" label="$2" session="${3:-${SESSION}}"
    jq -n --argjson q "${question}" --arg label "${label}" --arg s "${session}" \
        '{hook_event_name: "PostToolUse", tool_name: "AskUserQuestion", session_id: $s,
          tool_input: {questions: [$q]},
          tool_response: {questions: [$q], answers: {($q.question): $label}}}' \
        | "${ANSWER}" "${DIR}" 2>/dev/null
}
# }}}

context_of() { jq -r '.hookSpecificOutput.additionalContext // empty' <<< "$1"; }
yes_if() { if "$@"; then printf yes; else printf no; fi; }

# --- Yes: once, for that session, for those places
out="$(ask_gate "echo x > ${E}/a.txt")"
check "a write elsewhere is refused" "$(yes_if [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<< "${out}")" = deny ])"
q="$(question_from "${out}")"
check "the refusal carries a question with three answers" "$(yes_if [ "$(jq -r '[.options[].label] | join(",")' <<< "${q}")" = "Yes,Always,No" ])"
check "the question names the place" "$(yes_if grep -qF "${E}/a.txt" <<< "$(jq -r .question <<< "${q}")")"
said="$(context_of "$(answer_with "${q}" Yes)")"
check "Yes is acknowledged to the agent" "$(yes_if grep -q "answered Yes" <<< "${said}")"
check "after Yes, another session is still refused" "$(yes_if [ "$(verdict "echo x > ${E}/a.txt" dddd-4444)" = refused ])"
check "after Yes, the write goes through once" "$(yes_if [ "$(verdict "echo x > ${E}/a.txt")" = silent ])"
check "and only once" "$(yes_if [ "$(verdict "echo x > ${E}/a.txt")" = refused ])"

out="$(ask_gate "echo x > ${E}/b.txt")"
q="$(question_from "${out}")"
answer_with "${q}" Yes > /dev/null
check "a Yes for one file does not cover another" "$(yes_if [ "$(verdict "echo x > ${E}/c.txt")" = refused ])"
check "but still covers its own" "$(yes_if [ "$(verdict "echo x > ${E}/b.txt")" = silent ])"

# --- the same question cannot be answered twice
said="$(context_of "$(answer_with "${q}" Yes)")"
check "an answered request is closed" "$(yes_if grep -q "No open request" <<< "${said}")"
check "and grants nothing more" "$(yes_if [ "$(verdict "echo x > ${E}/b.txt")" = refused ])"

# --- No
out="$(ask_gate "echo x > ${F}/n.txt")"
q="$(question_from "${out}")"
said="$(context_of "$(answer_with "${q}" No)")"
check "No is told to the agent" "$(yes_if grep -q "did not allow" <<< "${said}")"
check "after No, still refused" "$(yes_if [ "$(verdict "echo x > ${F}/n.txt")" = refused ])"
q2="$(question_from "$(ask_gate "echo x > ${F}/o.txt")")"
answer_with "${q2}" "I typed something else" > /dev/null
check "a typed-in answer grants nothing" "$(yes_if [ "$(verdict "echo x > ${F}/o.txt")" = refused ])"

# --- the agent cannot change what the person agrees to
out="$(ask_gate "echo x > ${F}/r.txt")"
q="$(question_from "${out}")"
reworded="$(jq -c '.options[1].description = "Harmless, just this once."' <<< "${q}")"
said="$(context_of "$(answer_with "${reworded}" Always)")"
check "a reworded question grants nothing" "$(yes_if grep -q "not asked exactly" <<< "${said}")"
check "and the folder is not allowed" "$(yes_if [ "$(verdict "echo x > ${F}/r.txt")" = refused ])"
q="$(question_from "$(ask_gate "echo x > ${F}/s.txt")")"
said="$(context_of "$(answer_with "${q}" Yes dddd-4444)")"
check "another session's answer grants nothing" "$(yes_if grep -q "another session" <<< "${said}")"
check "for either session" "$(yes_if [ "$(verdict "echo x > ${F}/s.txt")" = refused ])"
pre="$(jq -n --argjson q "${q}" '{hook_event_name: "PreToolUse", tool_name: "AskUserQuestion", session_id: "cccc-3333",
        tool_input: {questions: [$q], answers: {($q.question): "Always"}}}' | "${ANSWER}" "${DIR}" 2>/dev/null)"
check "a question arriving with answers filled in is refused" "$(yes_if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<< "${pre}")" = deny ])"
plain="$(jq -n '{hook_event_name: "PreToolUse", tool_name: "AskUserQuestion", session_id: "cccc-3333",
        tool_input: {questions: [{question: "Which colour?", header: "Colour", multiSelect: false, options: [{label: "Red", description: "r"}, {label: "Blue", description: "b"}]}]}}' | "${ANSWER}" "${DIR}" 2>/dev/null)"
check "an ordinary question passes untouched" "$(yes_if [ -z "${plain}" ])"

# --- Always: the folder, every session, from now on
out="$(ask_gate "echo x > ${E}/inner/d.txt")"
q="$(question_from "${out}")"
check "Always names the folder it would open" "$(yes_if grep -qF "${E}/inner" <<< "$(jq -r '.options[1].description' <<< "${q}")")"
said="$(context_of "$(answer_with "${q}" Always)")"
check "Always is acknowledged" "$(yes_if grep -q "answered Always" <<< "${said}")"
check "the folder is on the allowed list" "$(yes_if grep -qxF "${E}/inner" "${OUTSIDE_WRITE_ALLOWED}")"
check "the write goes through" "$(yes_if [ "$(verdict "echo x > ${E}/inner/d.txt")" = silent ])"
check "and again" "$(yes_if [ "$(verdict "echo x > ${E}/inner/d.txt")" = silent ])"
check "a new file beside it goes through" "$(yes_if [ "$(verdict "echo x > ${E}/inner/new.txt")" = silent ])"
check "for any session" "$(yes_if [ "$(verdict "echo x > ${E}/inner/new.txt" eeee-5555)" = silent ])"
check "the folder above is still refused" "$(yes_if [ "$(verdict "echo x > ${E}/up.txt")" = refused ])"
q="$(question_from "$(ask_gate "echo x > ${E}/inner/x/y.txt")")"
check "a place already covered is never asked about" "$(yes_if [ -z "${q}" ])"

# --- an expired request grants nothing
out="$(ask_gate "echo x > ${F}/late.txt")"
q="$(question_from "${out}")"
id="$(jq -r .question <<< "${q}" | sed -n 's/.*\[outside-write \([0-9a-f]*\)\].*/\1/p')"
jq -c '.made = 0' "${OUTSIDE_WRITE_STATE}/requests/${id}.json" > "${SCRATCH}/old.json"
mv "${SCRATCH}/old.json" "${OUTSIDE_WRITE_STATE}/requests/${id}.json"
said="$(context_of "$(answer_with "${q}" Yes)")"
check "an expired request grants nothing" "$(yes_if grep -q "No open request" <<< "${said}")"
check "and the write is still refused" "$(yes_if [ "$(verdict "echo x > ${F}/late.txt")" = refused ])"

printf '%s passed, %s failed\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
