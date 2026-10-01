#!/usr/bin/env bash
#
# test-adopt-left-behind.sh
#
# Checks that a session can take ownership of work another session left
# uncommitted, and then commit it through the normal route -- without taking
# lines a still-working session holds (issue 032b).
#
# The scene: a scratch repository where three sessions have been at work.
#   - a finished session, whose ledger is gone (as after a reboot): it changed
#     a line, wrote a new file, and deleted a file
#   - a live session, whose ledger is still in RAM: it changed another line in
#     the same file as the finished one
#   - an ended session whose ledger survived: it changed a file of its own
# This session then adopts, commits, and checks that the commit carries the
# finished session's work and not the live session's, and that naming the
# ended session with --from lets its work through too. Ledgers are made up for
# the test under invented session ids and removed afterwards, with the
# scratch repository.
#
# Exit 0 when everything behaves, 1 otherwise.
#
# Usage: test-adopt-left-behind.sh [scripts-directory]

set -uo pipefail

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
SCRATCH="/tmp/claude-1000/f1-tests/adopt-$$"
REPO="${SCRATCH}/repo"
OWN="adopt-test-own-$$"
LIVE="adopt-test-live-$$"
ENDED="adopt-test-ended-$$"
LEDGERS="/dev/shm/claude-own-edits"
export CLAUDE_CODE_SESSION_ID="${OWN}"
export CLAUDE_SESSIONS_ROOT="${SCRATCH}/sessions"
trap 'rm -rf "${SCRATCH}" "${LEDGERS}/${OWN}" "${LEDGERS}/${LIVE}" "${LEDGERS}/${ENDED}"' EXIT

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

# {{{ write_ledger()
# Writes one made-up session's ledger: session id, then records as
# "kind<TAB>file-in-repo<TAB>text" lines on standard input.
write_ledger() {
    local session="$1"
    mkdir -p -m 700 "${LEDGERS}/${session}"
    local kind file text
    while IFS=$'\t' read -r kind file text; do
        printf '%s\t%s\t%s\n' "${kind}" "$(realpath -m "${REPO}/${file}")" "${text}" >> "${LEDGERS}/${session}/ledger.tsv"
    done
}
# }}}

# {{{ adopt()
adopt() {
    "${DIR}/adopt-left-behind-changes" "${REPO}" --scripts-dir "${DIR}" "$@"
}
# }}}

printf '\nSetting up the scratch repository\n'
mkdir -p "${REPO}/proj/llm-transcripts" "${SCRATCH}/sessions"
git -C "${REPO}" init -q
git -C "${REPO}" config user.name "test"
git -C "${REPO}" config user.email "test@example.invalid"
printf 'a1\na2\na3\na4\na5\n' > "${REPO}/a.lua"
printf 'b1\nb2\n' > "${REPO}/b.lua"
printf 'e1\n' > "${REPO}/e.lua"
printf 'first transcript\n' > "${REPO}/proj/llm-transcripts/t.md"
git -C "${REPO}" add -A
git -C "${REPO}" commit -q -m base
check "scratch repository has a first commit" "$(git -C "${REPO}" rev-parse -q --verify HEAD > /dev/null && echo yes || echo no)"

printf '\nThree sessions leave work behind\n'
# finished session (no ledger): a2 changed, n.lua new, b.lua deleted
# live session (ledger in RAM): a4 changed, in the same file
printf 'a1\ngone-a2\na3\nlive-a4\na5\n' > "${REPO}/a.lua"
printf 'n1\nn2\n' > "${REPO}/n.lua"
rm "${REPO}/b.lua"
printf -- '-\ta.lua\ta4\n+\ta.lua\tlive-a4\n' | write_ledger "${LIVE}"
# ended session (ledger survived): e1 changed
printf 'ended-e1\n' > "${REPO}/e.lua"
printf -- '-\te.lua\te1\n+\te.lua\tended-e1\n' | write_ledger "${ENDED}"
# a transcript changed too; it rides along on its own and is never adopted
printf 'first transcript\nmore\n' > "${REPO}/proj/llm-transcripts/t.md"

printf '\nAdoption needs a named scope\n'
adopt > "${SCRATCH}/no-path.out" 2>&1
check "no path after -- is an error" "$([ $? -ne 0 ] && echo yes || echo no)"
check "the error says to name what to adopt" "$(grep -q 'name what to adopt' "${SCRATCH}/no-path.out" && echo yes || echo no)"

printf '\nA dry run writes nothing\n'
adopt --dry-run -- . > "${SCRATCH}/dry.out" 2>&1
check "dry run succeeds" "$([ $? -eq 0 ] && echo yes || echo no)"
check "dry run leaves this session without a ledger" "$([ ! -e "${LEDGERS}/${OWN}/ledger.tsv" ] && echo yes || echo no)"
check "dry run reports the finished session's line" "$(grep -q 'adopted  a.lua  +1 -1' "${SCRATCH}/dry.out" && echo yes || echo no)"

printf '\nAdopting takes what nobody holds\n'
adopt -- . > "${SCRATCH}/adopt.out" 2>&1
check "adoption succeeds" "$([ $? -eq 0 ] && echo yes || echo no)"
OWN_LEDGER="${LEDGERS}/${OWN}/ledger.tsv"
check "the finished session's added line is now ours" "$(grep -q $'^+\t.*/a.lua\tgone-a2$' "${OWN_LEDGER}" && echo yes || echo no)"
check "the finished session's removed line is now ours" "$(grep -q $'^-\t.*/a.lua\ta2$' "${OWN_LEDGER}" && echo yes || echo no)"
check "the live session's line is not ours" "$(grep -q 'live-a4' "${OWN_LEDGER}" && echo no || echo yes)"
check "the ended session's line is not ours yet" "$(grep -q 'ended-e1' "${OWN_LEDGER}" && echo no || echo yes)"
check "the new file is claimed whole" "$(grep -q $'^W\t.*/n.lua\t$' "${OWN_LEDGER}" && echo yes || echo no)"
check "the deleted file's lines are ours" "$(grep -q $'^-\t.*/b.lua\tb2$' "${OWN_LEDGER}" && echo yes || echo no)"
check "the transcript is not adopted" "$(grep -q 't.md' "${OWN_LEDGER}" && echo no || echo yes)"
check "the report names the live session as holder" "$(grep -q "held     2 line(s) by session ${LIVE}" "${SCRATCH}/adopt.out" && echo yes || echo no)"
check "a file whose every line is held is reported as left" "$(grep -q 'left     e.lua  every changed line is held' "${SCRATCH}/adopt.out" && echo yes || echo no)"
check "the report says how to take held lines" "$(grep -q -- '--from <session>' "${SCRATCH}/adopt.out" && echo yes || echo no)"

printf '\nThe normal commit route commits the adopted work\n'
"${DIR}/commit-own-changes" "${REPO}" -m "adopted work" --scripts-dir "${DIR}" > "${SCRATCH}/commit.out" 2>&1
check "commit succeeds" "$([ $? -eq 0 ] && echo yes || echo no)"
COMMITTED_A="$(git -C "${REPO}" show HEAD:a.lua)"
check "the commit carries the finished session's line" "$(grep -qx 'gone-a2' <<< "${COMMITTED_A}" && echo yes || echo no)"
check "the commit leaves the live session's line out" "$(grep -qx 'a4' <<< "${COMMITTED_A}" && echo yes || echo no)"
check "the commit carries the new file" "$(git -C "${REPO}" cat-file -e HEAD:n.lua && echo yes || echo no)"
check "the commit carries the deletion" "$([ -z "$(git -C "${REPO}" ls-tree --name-only HEAD b.lua)" ] && echo yes || echo no)"
check "the commit leaves the ended session's file alone" "$([ "$(git -C "${REPO}" show HEAD:e.lua)" = "e1" ] && echo yes || echo no)"
check "the live session's line is still on disk" "$(grep -qx 'live-a4' "${REPO}/a.lua" && echo yes || echo no)"

printf '\nNaming an ended session takes its lines too\n'
adopt --from "${ENDED}" -- e.lua > "${SCRATCH}/from.out" 2>&1
check "adoption with --from succeeds" "$([ $? -eq 0 ] && echo yes || echo no)"
check "the ended session's line is now ours" "$(grep -q 'ended-e1' "${OWN_LEDGER}" && echo yes || echo no)"
"${DIR}/commit-own-changes" "${REPO}" -m "ended session's work" --scripts-dir "${DIR}" > "${SCRATCH}/commit2.out" 2>&1
check "second commit succeeds" "$([ $? -eq 0 ] && echo yes || echo no)"
check "the second commit carries the ended session's line" "$([ "$(git -C "${REPO}" show HEAD:e.lua)" = "ended-e1" ] && echo yes || echo no)"
check "the live session's line is still uncommitted" "$(git -C "${REPO}" show HEAD:a.lua | grep -qx 'a4' && echo yes || echo no)"

printf '\nThe gate points at adoption\n'
GATE_INPUT="$(jq -n --arg s "${OWN}" --arg cwd "${REPO}" '{session_id: $s, cwd: $cwd, tool_name: "Bash", tool_input: {command: "git commit -m x"}}')"
GATE_OUT="$("${DIR}/refuse-foreign-lines" "${SCRATCH}/no-token" "${DIR}" <<< "${GATE_INPUT}")"
check "the refusal names adopt-left-behind-changes" "$(grep -q 'adopt-left-behind-changes' <<< "${GATE_OUT}" && echo yes || echo no)"

if [ "${failures}" -ne 0 ]; then
    printf '\nWhat adoption and the commits wrote:\n'
    cat "${SCRATCH}/adopt.out" "${SCRATCH}/commit.out" "${SCRATCH}/from.out" "${SCRATCH}/commit2.out"
fi
printf '\n%s checks, %s failures\n' "${checked}" "${failures}"
[ "${failures}" -eq 0 ] || exit 1
exit 0
