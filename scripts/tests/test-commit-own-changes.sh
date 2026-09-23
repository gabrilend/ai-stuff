#!/usr/bin/env bash
#
# test-commit-own-changes.sh
#
# Proves that commit-own-changes commits exactly one session's own lines,
# never touches the staging area other sessions share except to keep it in
# step with what it committed, and never writes the files on disk -- including
# when two sessions edit the same file and commit at the same moment.
#
# The scenes, each in a fresh scratch git repository under /tmp/claude-1000/p/:
#   - two sessions change different lines of one file and commit, in both
#     orders: two commits, each with only its own lines, nothing reverted;
#   - the same, both committing at once, twenty times over;
#   - two sessions changed the same line: the commit stops and changes nothing;
#   - someone hand-staged a change to a file being committed: their staged
#     change survives on top of the commit, or is left alone with a warning
#     when it overlaps;
#   - another file's staged entry is untouched; the working tree is untouched;
#   - new, deleted and renamed files; nothing to commit; every changed
#     transcript rides along, whoever's conversation it is, even outside a
#     path limit, even alone, and a transcript renamed by the exporter
#     carries its deletion with it;
#   - a branch other than main; the branch moved by someone else mid-commit;
#   - stage-own-changes previews and writes nothing;
#   - the commit gate turns plain git commit away and lets this route through.
#
# A session's ledger is written directly in the ledger's format (see
# libs/own-lines-ledger.lua) under a made-up session id, in RAM, and removed
# afterwards with the scratch repositories.
#
# Exit 0 when everything behaves, 1 otherwise.
#
# Usage: test-commit-own-changes.sh [scripts-directory]

set -uo pipefail

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
SCRATCH="/tmp/claude-1000/p/commit-own-changes-$$"
SESSIONS="${SCRATCH}/sessions"
S1="coc-one-$$"
S2="coc-two-$$"
LEDGER_ROOT="/dev/shm/claude-own-edits"
TOKEN="${SCRATCH}/token-commit"
trap 'rm -rf "${SCRATCH}" "${LEDGER_ROOT}/${S1}" "${LEDGER_ROOT}/${S2}"' EXIT
mkdir -p "${SCRATCH}" "${SESSIONS}"

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

# {{{ yes_if()
# Prints yes when the command succeeds, no otherwise.
yes_if() { if "$@" > /dev/null; then printf yes; else printf no; fi; }
# }}}

# {{{ absent()
# Prints yes when a commit has no such file. cat-file -e says so only through
# its exit status, printing nothing either way.
absent() { if git -C "${REPO}" cat-file -e "$1"; then printf no; else printf yes; fi; }
# }}}

# {{{ claim()
# Appends one ledger record for a session: kind (+, -, W), file, line text.
claim() {
    local session="$1" kind="$2" file="$3" text="${4:-}"
    mkdir -p -m 700 "${LEDGER_ROOT}/${session}"
    printf '%s\t%s\t%s\n' "${kind}" "$(realpath -m "${file}")" "${text}" >> "${LEDGER_ROOT}/${session}/ledger.tsv"
}
# }}}

# {{{ reset_ledgers()
reset_ledgers() { rm -rf "${LEDGER_ROOT:?}/${S1}" "${LEDGER_ROOT:?}/${S2}"; }
# }}}

# {{{ coc()
# Runs commit-own-changes as a session. Output goes to a file named after the
# session, the exit status is returned.
coc() {
    local session="$1"; shift
    CLAUDE_CODE_SESSION_ID="${session}" CLAUDE_SESSIONS_ROOT="${SESSIONS}" \
        "${DIR}/commit-own-changes" "$@" --scripts-dir "${DIR}" > "${SCRATCH}/out-${session}" 2>&1
}
# }}}

# {{{ new_repo()
# A fresh repository on main with notes.md (ten lines) and other.txt.
new_repo() {
    REPO="${SCRATCH}/$1"
    rm -rf "${REPO}"
    mkdir -p "${REPO}"
    git -C "${REPO}" init -q -b main
    git -C "${REPO}" config user.name "test"
    git -C "${REPO}" config user.email "test@example.invalid"
    seq -f 'line%g' 1 10 > "${REPO}/notes.md"
    printf 'o1\no2\n' > "${REPO}/other.txt"
    git -C "${REPO}" add -A
    git -C "${REPO}" commit -q -m base
    reset_ledgers
}
# }}}

# {{{ tree_sum()
# A checksum of every file in the working tree, .git excluded.
tree_sum() {
    find "${REPO}" -path "${REPO}/.git" -prune -o -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum
}
# }}}

# {{{ set_line()
# Replaces line n of a file with text.
set_line() { sed -i "$2s/.*/$3/" "$1"; }
# }}}

# {{{ changed_lines()
# The added and removed lines a commit makes to one file, one per line.
changed_lines() {
    git -C "${REPO}" show --format= -U0 "$1" -- "$2" | grep -E '^[+-][^+-]' | sort | tr '\n' ' '
}
# }}}

printf '\nTwo sessions, one file, session 1 commits first\n'
new_repo order12
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
set_line "${REPO}/notes.md" 9 B9; claim "${S2}" - "${REPO}/notes.md" line9; claim "${S2}" + "${REPO}/notes.md" B9
before="$(tree_sum)"
coc "${S1}" "${REPO}" -m "session one"; s1=$?
coc "${S2}" "${REPO}" -m "session two"; s2=$?
check "both commits succeed" "$( [ $s1 = 0 ] && [ $s2 = 0 ] && echo yes || echo no)"
check "two new commits on main" "$( [ "$(git -C "${REPO}" rev-list --count main)" = 3 ] && echo yes || echo no)"
check "session 1's commit holds only its own line" "$( [ "$(changed_lines main~1 notes.md)" = "+A1 -line1 " ] && echo yes || echo no)"
check "session 2's commit holds only its own line" "$( [ "$(changed_lines main notes.md)" = "+B9 -line9 " ] && echo yes || echo no)"
check "the committed file equals the file on disk (nothing reverted)" "$(yes_if diff -q <(git -C "${REPO}" show main:notes.md) "${REPO}/notes.md")"
check "the working tree was not written" "$( [ "$(tree_sum)" = "${before}" ] && echo yes || echo no)"
check "the shared staging area matches the new commit" "$(yes_if git -C "${REPO}" diff --cached --quiet)"
check "git status shows nothing left over" "$( [ -z "$(git -C "${REPO}" status --porcelain)" ] && echo yes || echo no)"

printf '\nTwo sessions, one file, session 2 commits first\n'
new_repo order21
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
set_line "${REPO}/notes.md" 9 B9; claim "${S2}" - "${REPO}/notes.md" line9; claim "${S2}" + "${REPO}/notes.md" B9
coc "${S2}" "${REPO}" -m "session two"; s2=$?
coc "${S1}" "${REPO}" -m "session one"; s1=$?
check "both commits succeed" "$( [ $s1 = 0 ] && [ $s2 = 0 ] && echo yes || echo no)"
check "session 2's commit holds only its own line" "$( [ "$(changed_lines main~1 notes.md)" = "+B9 -line9 " ] && echo yes || echo no)"
check "session 1's commit holds only its own line" "$( [ "$(changed_lines main notes.md)" = "+A1 -line1 " ] && echo yes || echo no)"
check "the committed file equals the file on disk" "$(yes_if diff -q <(git -C "${REPO}" show main:notes.md) "${REPO}/notes.md")"

printf '\nBoth sessions commit at the same moment, twenty times\n'
new_repo simultaneous
ok_rounds=0
prev1="line2"; prev2="line8"
for round in $(seq 1 20); do
    set_line "${REPO}/notes.md" 2 "s1r${round}"; claim "${S1}" - "${REPO}/notes.md" "${prev1}"; claim "${S1}" + "${REPO}/notes.md" "s1r${round}"
    set_line "${REPO}/notes.md" 8 "s2r${round}"; claim "${S2}" - "${REPO}/notes.md" "${prev2}"; claim "${S2}" + "${REPO}/notes.md" "s2r${round}"
    start="$(git -C "${REPO}" rev-parse main)"
    coc "${S1}" "${REPO}" -m "one ${round}" & p1=$!
    coc "${S2}" "${REPO}" -m "two ${round}" & p2=$!
    wait $p1; r1=$?; wait $p2; r2=$?
    good=yes
    [ $r1 = 0 ] && [ $r2 = 0 ] || good=no
    [ "$(git -C "${REPO}" rev-list --count "${start}..main")" = 2 ] || good=no
    diff -q <(git -C "${REPO}" show main:notes.md) "${REPO}/notes.md" > /dev/null || good=no
    # each of the round's two commits changes exactly one line, its own
    for c in main main~1; do
        lines="$(changed_lines "$c" notes.md)"
        subject="$(git -C "${REPO}" log -1 --format=%s "$c")"
        case "${subject}" in
            "one ${round}") [ "${lines}" = "+s1r${round} -${prev1} " ] || good=no ;;
            "two ${round}") [ "${lines}" = "+s2r${round} -${prev2} " ] || good=no ;;
            *) good=no ;;
        esac
    done
    [ "${good}" = yes ] && ok_rounds=$((ok_rounds + 1))
    prev1="s1r${round}"; prev2="s2r${round}"
done
check "all 20 rounds: both commits land, each with only its own line, nothing lost (${ok_rounds}/20)" \
    "$( [ ${ok_rounds} = 20 ] && echo yes || echo no)"
check "the shared staging area ends in step with main" "$(yes_if git -C "${REPO}" diff --cached --quiet)"

printf '\nTwo sessions changed the same line\n'
new_repo overlap
set_line "${REPO}/notes.md" 5 one; claim "${S1}" - "${REPO}/notes.md" line5; claim "${S1}" + "${REPO}/notes.md" one
set_line "${REPO}/notes.md" 5 two; claim "${S2}" - "${REPO}/notes.md" one; claim "${S2}" + "${REPO}/notes.md" two
head_before="$(git -C "${REPO}" rev-parse main)"; index_before="$(git -C "${REPO}" ls-files -s | sha256sum)"
coc "${S2}" "${REPO}" -m "session two"; s2=$?
check "the commit stops" "$( [ $s2 = 1 ] && echo yes || echo no)"
check "the message names the file and line" "$(yes_if grep -q 'notes.md:5' "${SCRATCH}/out-${S2}")"
check "nothing was committed" "$( [ "$(git -C "${REPO}" rev-parse main)" = "${head_before}" ] && echo yes || echo no)"
check "the shared staging area is untouched" "$( [ "$(git -C "${REPO}" ls-files -s | sha256sum)" = "${index_before}" ] && echo yes || echo no)"

printf '\nSomeone hand-staged another part of the file being committed\n'
new_repo handstaged
set_line "${REPO}/notes.md" 10 P10; git -C "${REPO}" add notes.md
printf 'o1\nforeign-o2\n' > "${REPO}/other.txt"; git -C "${REPO}" add other.txt
other_entry="$(git -C "${REPO}" ls-files -s other.txt)"
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
before="$(tree_sum)"
coc "${S1}" "${REPO}" -m "session one"; s1=$?
check "the commit succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "the commit holds only this session's line, not the staged one" "$( [ "$(changed_lines main notes.md)" = "+A1 -line1 " ] && echo yes || echo no)"
check "their staged change survives on top of the commit" \
    "$( [ "$(git -C "${REPO}" diff --cached -U0 -- notes.md | grep -E '^[+-][^+-]' | sort | tr '\n' ' ')" = "+P10 -line10 " ] && echo yes || echo no)"
check "the report says the staged change was kept" "$(yes_if grep -q 'kept staged' "${SCRATCH}/out-${S1}")"
check "another file's staged entry is untouched" "$( [ "$(git -C "${REPO}" ls-files -s other.txt)" = "${other_entry}" ] && echo yes || echo no)"
check "the working tree was not written" "$( [ "$(tree_sum)" = "${before}" ] && echo yes || echo no)"

printf '\nSomeone hand-staged a change that overlaps the commit\n'
new_repo handoverlap
set_line "${REPO}/notes.md" 3 P3; git -C "${REPO}" add notes.md
set_line "${REPO}/notes.md" 3 S3; claim "${S1}" - "${REPO}/notes.md" line3; claim "${S1}" + "${REPO}/notes.md" S3
staged_before="$(git -C "${REPO}" ls-files -s notes.md)"
coc "${S1}" "${REPO}" -m "session one"; s1=$?
check "the commit succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "their staged entry is left exactly as it was" "$( [ "$(git -C "${REPO}" ls-files -s notes.md)" = "${staged_before}" ] && echo yes || echo no)"
check "and the report warns about it" "$(yes_if grep -q 'WARNING.*notes.md' "${SCRATCH}/out-${S1}")"

printf '\nNew, deleted and renamed files\n'
new_repo files
printf 'n1\nn2\n' > "${REPO}/new.md"; claim "${S1}" + "${REPO}/new.md" n1; claim "${S1}" + "${REPO}/new.md" n2
git -C "${REPO}" mv -f other.txt renamed.txt; git -C "${REPO}" reset -q
claim "${S1}" W "${REPO}/other.txt"; claim "${S1}" W "${REPO}/renamed.txt"
printf 'x\n' > "${REPO}/gone.md"; git -C "${REPO}" add gone.md; git -C "${REPO}" commit -q -m "add gone"
rm "${REPO}/gone.md"; claim "${S1}" W "${REPO}/gone.md"
printf 'foreign new\n' > "${REPO}/stranger.md"
coc "${S1}" "${REPO}" -m "files"; s1=$?
names="$(git -C "${REPO}" show --format= --name-status main | sort | tr '\n' ' ')"
check "the commit succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "the new file written by this session is committed" "$(yes_if git -C "${REPO}" cat-file -e main:new.md)"
check "the rename lands as a delete and an add" "$(yes_if git -C "${REPO}" cat-file -e main:renamed.txt)"
check "the old name is gone" "$(absent main:other.txt)"
check "the deleted file is deleted" "$(absent main:gone.md)"
check "a new file nobody claimed is left out" "$(absent main:stranger.md)"
check "git status afterwards shows only the stranger" "$( [ "$(git -C "${REPO}" status --porcelain)" = "?? stranger.md" ] && echo yes || echo no)"

printf '\nNothing to commit\n'
new_repo nothing
coc "${S1}" "${REPO}" -m "empty"; s1=$?
check "exits 1" "$( [ $s1 = 1 ] && echo yes || echo no)"
check "says there is nothing of this session's" "$(yes_if grep -q "nothing of this session's" "${SCRATCH}/out-${S1}")"
printf 'foreign\n' >> "${REPO}/notes.md"
coc "${S1}" "${REPO}" -m "empty"; s1=$?
check "only someone else's change: still nothing, still exit 1" "$( [ $s1 = 1 ] && [ "$(git -C "${REPO}" rev-list --count main)" = 1 ] && echo yes || echo no)"

printf '\nEvery changed transcript rides along, whoever\x27s it is\n'
new_repo transcripts
mkdir -p "${REPO}/proj/llm-transcripts" "${SESSIONS}/-proj/${S1}/subagents"
: > "${SESSIONS}/-proj/${S1}/subagents/agent-abc123.jsonl"
printf '# Conversation Summary: %s\n\nmine\n' "${S1}" > "${REPO}/proj/llm-transcripts/sep-1-26.md"
printf '# Conversation Summary: agent-abc123\n\nmy helper\n' > "${REPO}/proj/llm-transcripts/sep-1-26_agent-1.md"
printf '# Conversation Summary: someone-else\n\ntheirs\n' > "${REPO}/proj/llm-transcripts/sep-1-26_other.md"
printf '# Conversation Summary: %s\n\nat the root\n' "${S1}" > "${REPO}/root-transcript.md"
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
coc "${S1}" "${REPO}" -m "with transcripts"; s1=$?
check "the commit succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "this session's transcript rides along" "$(yes_if git -C "${REPO}" cat-file -e main:proj/llm-transcripts/sep-1-26.md)"
check "its helper's transcript rides along" "$(yes_if git -C "${REPO}" cat-file -e main:proj/llm-transcripts/sep-1-26_agent-1.md)"
check "another conversation's transcript rides along too" "$(yes_if git -C "${REPO}" cat-file -e main:proj/llm-transcripts/sep-1-26_other.md)"
check "the report tells this conversation's from another's" "$(yes_if grep -q 'sep-1-26_other.md (another conversation)' "${SCRATCH}/out-${S1}")"
check "a file outside llm-transcripts/ is never taken for a transcript" "$(absent main:root-transcript.md)"

# Transcripts are decided by whose conversation they are, never line by line.
# The ledger can still hold partial records of transcript lines -- a backup run
# from a shell command reports its file diff, and the ledger hook records it --
# and before 2026-09-22 those partial records made the session's own
# transcript look tangled, so the whole commit stopped.
printf '\nA partial ledger record inside a transcript does not tangle it\n'
new_repo transcript-partial
mkdir -p "${REPO}/proj/llm-transcripts" "${SESSIONS}/-proj/${S1}/subagents"
printf '# Conversation Summary: %s\n\nfirst\n' "${S1}" > "${REPO}/proj/llm-transcripts/sep-2-26.md"
printf '# Conversation Summary: someone-else\n\ntheirs\n' > "${REPO}/proj/llm-transcripts/sep-2-26_other.md"
git -C "${REPO}" add -A && git -C "${REPO}" commit -q -m "transcripts exist"
printf 'second, written by the backup hook\nthird, seen by the ledger\n' >> "${REPO}/proj/llm-transcripts/sep-2-26.md"
printf 'their next line\n' >> "${REPO}/proj/llm-transcripts/sep-2-26_other.md"
claim "${S1}" + "${REPO}/proj/llm-transcripts/sep-2-26.md" "third, seen by the ledger"
claim "${S1}" + "${REPO}/proj/llm-transcripts/sep-2-26_other.md" "their next line"
set_line "${REPO}/notes.md" 1 B1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" B1
coc "${S1}" "${REPO}" -m "partial transcript records"; s1=$?
check "the commit succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "this session's transcript is committed whole" "$(yes_if git -C "${REPO}" grep -q 'second, written by the backup hook' main -- proj/llm-transcripts/sep-2-26.md)"
check "another conversation's transcript is committed whole, ledger record or not" "$(yes_if git -C "${REPO}" grep -q 'their next line' main -- proj/llm-transcripts/sep-2-26_other.md)"

# The case that changed the rule (kiln, 2026-09-23): a session committed,
# talked on, and quit, so its transcript grew after its last commit. A later
# session with nothing else of its own to commit must still be able to carry
# it, and a small commit limited to one file must carry it too.
printf '\nA transcript left behind by a finished session is carried\n'
new_repo transcript-left-behind
mkdir -p "${REPO}/proj/llm-transcripts" "${REPO}/other-proj/llm-transcripts"
printf '# Conversation Summary: finished-session\n\nfirst\n' > "${REPO}/proj/llm-transcripts/sep-22-26.md"
git -C "${REPO}" add -A && git -C "${REPO}" commit -q -m "yesterday's transcript as it was"
printf 'the last words, after its last commit\n' >> "${REPO}/proj/llm-transcripts/sep-22-26.md"
coc "${S1}" "${REPO}" -m "transcripts catch up"; s1=$?
check "a commit of transcripts alone succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "the finished session's last words are committed" "$(yes_if git -C "${REPO}" grep -q 'the last words' main -- proj/llm-transcripts/sep-22-26.md)"
printf '# Conversation Summary: third-session\n\nelsewhere\n' > "${REPO}/other-proj/llm-transcripts/sep-23-26.md"
set_line "${REPO}/notes.md" 1 C1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" C1
coc "${S1}" "${REPO}" -m "notes only" -- notes.md; s1=$?
check "a commit limited to one file succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "it carries a changed transcript outside the limit" "$(yes_if git -C "${REPO}" cat-file -e main:other-proj/llm-transcripts/sep-23-26.md)"

# The exporter renames a transcript when its conversation crosses midnight
# (one day's name becomes a date range). The old name's deletion rides along
# with the new name, so the rename lands in one commit.
printf '\nA transcript renamed by the exporter carries its deletion\n'
new_repo transcript-renamed
mkdir -p "${REPO}/proj/llm-transcripts"
printf '# Conversation Summary: crossing-midnight\n\nday one\n' > "${REPO}/proj/llm-transcripts/sep-22-26.md"
git -C "${REPO}" add -A && git -C "${REPO}" commit -q -m "one day's transcript"
git -C "${REPO}" --no-optional-locks show main:proj/llm-transcripts/sep-22-26.md > "${REPO}/proj/llm-transcripts/sep-22-26-through-sep-23-26.md"
printf 'day two\n' >> "${REPO}/proj/llm-transcripts/sep-22-26-through-sep-23-26.md"
rm "${REPO}/proj/llm-transcripts/sep-22-26.md"
coc "${S1}" "${REPO}" -m "the rename"; s1=$?
check "the commit succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "the new name is committed" "$(yes_if git -C "${REPO}" cat-file -e main:proj/llm-transcripts/sep-22-26-through-sep-23-26.md)"
check "the old name's deletion is committed" "$(absent main:proj/llm-transcripts/sep-22-26.md)"
check "the report says the old one is gone" "$(yes_if grep -q 'sep-22-26.md (gone from disk' "${SCRATCH}/out-${S1}")"
check "nothing is left uncommitted" "$( [ -z "$(git -C "${REPO}" status --porcelain)" ] && echo yes || echo no)"

printf '\nCommitting in small pieces with -- <paths>\n'
new_repo pieces
mkdir -p "${REPO}/docs"
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
printf 'd1\n' > "${REPO}/docs/guide.md"; claim "${S1}" + "${REPO}/docs/guide.md" d1
coc "${S1}" "${REPO}" -m "notes only" -- notes.md; s1=$?
check "a commit limited to one file succeeds" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "it holds only that file" "$( [ "$(git -C "${REPO}" show --format= --name-only main)" = "notes.md" ] && echo yes || echo no)"
check "the other file waits, still uncommitted" "$(absent main:docs/guide.md)"
coc "${S1}" "${REPO}" -m "the docs" -- docs/; s1=$?
check "a commit limited to a folder picks up the rest" "$( [ $s1 = 0 ] && [ "$(git -C "${REPO}" show --format= --name-only main)" = "docs/guide.md" ] && echo yes || echo no)"
coc "${S1}" "${REPO}" -m "nothing left" -- other.txt; s1=$?
check "a limit with nothing of this session's in it commits nothing" "$( [ $s1 = 1 ] && echo yes || echo no)"

printf '\nA branch other than main\n'
new_repo branch
git -C "${REPO}" checkout -q -b feature
main_before="$(git -C "${REPO}" rev-parse main)"
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
coc "${S1}" "${REPO}" -m "on feature"; s1=$?
check "the commit lands on feature" "$( [ $s1 = 0 ] && [ "$(git -C "${REPO}" log -1 --format=%s feature)" = "on feature" ] && echo yes || echo no)"
check "main is untouched" "$( [ "$(git -C "${REPO}" rev-parse main)" = "${main_before}" ] && echo yes || echo no)"

printf '\nThe branch moves while the commit is being built\n'
new_repo moved
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
mover="${SCRATCH}/mover.sh"
cat > "${mover}" <<EOF
#!/usr/bin/env bash
# moves main once, by plumbing, as a commit made some other way would
[ -e "${SCRATCH}/moved-once" ] && exit 0
touch "${SCRATCH}/moved-once"
blob=\$(printf 'o1\nsomeone-else\n' | git -C "${REPO}" hash-object -w --stdin)
idx="${SCRATCH}/mover-index"
GIT_INDEX_FILE="\${idx}" git -C "${REPO}" read-tree main
GIT_INDEX_FILE="\${idx}" git -C "${REPO}" update-index --cacheinfo 100644,\${blob},other.txt
tree=\$(GIT_INDEX_FILE="\${idx}" git -C "${REPO}" write-tree)
c=\$(git -C "${REPO}" commit-tree "\${tree}" -p main -m "someone else")
git -C "${REPO}" update-ref refs/heads/main "\${c}"
EOF
chmod +x "${mover}"
COMMIT_OWN_CHANGES_TEST_BEFORE_SWAP="${mover}" coc "${S1}" "${REPO}" -m "after the move"; s1=$?
check "the commit succeeds after rebuilding" "$( [ $s1 = 0 ] && echo yes || echo no)"
check "it says it retried" "$(yes_if grep -q 'retried' "${SCRATCH}/out-${S1}")"
check "it sits on top of the other commit" "$( [ "$(git -C "${REPO}" log -1 --format=%s main~1)" = "someone else" ] && echo yes || echo no)"
check "both changes are in main" "$( git -C "${REPO}" show main:other.txt | grep -q someone-else && git -C "${REPO}" show main:notes.md | grep -qx A1 && echo yes || echo no)"
check "and its own commit holds only its own line" "$( [ "$(changed_lines main notes.md)" = "+A1 -line1 " ] && [ -z "$(git -C "${REPO}" show --format= --name-only main -- other.txt)" ] && echo yes || echo no)"

printf '\nstage-own-changes previews and writes nothing\n'
new_repo preview
set_line "${REPO}/notes.md" 1 A1; claim "${S1}" - "${REPO}/notes.md" line1; claim "${S1}" + "${REPO}/notes.md" A1
index_before="$(git -C "${REPO}" ls-files -s | sha256sum)"
preview="$(CLAUDE_CODE_SESSION_ID="${S1}" CLAUDE_SESSIONS_ROOT="${SESSIONS}" "${DIR}/stage-own-changes" "${REPO}" --scripts-dir "${DIR}" 2>&1)"
check "the preview names the file it would commit" "$(yes_if grep -q 'ours .*notes.md (1 of 1' <<< "${preview}")"
check "the shared staging area is untouched" "$( [ "$(git -C "${REPO}" ls-files -s | sha256sum)" = "${index_before}" ] && echo yes || echo no)"
check "nothing was committed" "$( [ "$(git -C "${REPO}" rev-list --count main)" = 1 ] && echo yes || echo no)"

printf '\nThe commit gate\n'
# {{{ gate_verdict()
gate_verdict() {
    local input out
    input="$(jq -n --arg c "$1" '{session_id: "x", cwd: "/tmp", tool_name: "Bash", tool_input: {command: $c}}')"
    out="$("${DIR}/refuse-foreign-lines" "${TOKEN}" "${DIR}" <<< "${input}")"
    printf '%s' "${out}" > "${SCRATCH}/gate-out"
    if [ "$(jq -r '.hookSpecificOutput.permissionDecision // ""' <<< "${out:-{\}}")" = deny ]; then printf refused; else printf allowed; fi
}
# }}}
check "a plain git commit is refused" "$( [ "$(gate_verdict 'git -C /repo commit -F -')" = refused ] && echo yes || echo no)"
check "the refusal points at commit-own-changes" "$(yes_if grep -q 'commit-own-changes' "${SCRATCH}/gate-out")"
check "git commit --amend is refused" "$( [ "$(gate_verdict 'git commit --amend -m x')" = refused ] && echo yes || echo no)"
check "commit-own-changes is allowed" "$( [ "$(gate_verdict "commit-own-changes /repo -F - <<'EOF'
Stop using git commit -a
EOF")" = allowed ] && echo yes || echo no)"
check "git commit --dry-run is allowed" "$( [ "$(gate_verdict 'git commit --dry-run')" = allowed ] && echo yes || echo no)"

printf '\n%s checks, %s failures\n' "${checked}" "${failures}"
[ "${failures}" -eq 0 ] || exit 1
exit 0
