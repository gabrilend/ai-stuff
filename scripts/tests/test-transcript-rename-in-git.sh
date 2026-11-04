#!/bin/bash
# test-transcript-rename-in-git.sh - proves that when a conversation crosses
# into a new day and its transcript is re-placed under a new name, git is told
# it was a rename, stays told as the conversation keeps growing, and that the
# private commit route then commits it without a single warning.
#
# In general terms: builds a throwaway git repository holding two projects.
# In the first, a one-day conversation is exported and committed, then gains
# a reply on the next day and is exported again. Before this guard, git saw
# "old file deleted, new file untracked"; now it must see "renamed". A further
# reply must keep the staged copy current. Then commit-own-changes - the route
# every real commit takes - commits the project: it must succeed, record a
# rename, print no warning from its tidy-up of the shared staging list, and
# leave `git status` clean. After that, changes are ordinary unstaged edits.
#
# The second project holds what must be left alone: a conversation git never
# knew (it stays untracked) and a copy someone staged by hand (it survives).
# It is a separate project so the first project's commit does not carry it.
#
# The exporter and the commit route are pointed at fixtures via
# CLAUDE_SESSIONS_ROOT and a made-up session id; nothing under ~/.claude, and
# no real repository, is touched.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

EXPORTER="$DIR/scripts/backup-conversations"
COMMIT_ROUTE="$DIR/scripts/commit-own-changes"
SCRATCH="${TMPDIR:-/tmp}/transcript-rename-in-git-test-$$"
SESSION_ID="rename-test-$$"

PASS=0
FAIL=0

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

# -- {{{ session_folder
# Where Claude Code would file a project's session logs: the path with every
# character that is not a letter or digit turned into a dash.
function session_folder() {
    printf '%s/%s\n' "$SESSIONS_ROOT" "$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g')"
}
# }}}

# -- {{{ build_fixtures
# One repository; PROJECT_DIR holds TRACKED (committed, then crosses a day),
# OTHER_DIR holds LOOSE (never committed, crosses a day, then hand-staged).
function build_fixtures() {
    REPO="$SCRATCH/repo"
    PROJECT_DIR="$REPO/proj"
    OTHER_DIR="$REPO/other"
    SESSIONS_ROOT="$SCRATCH/sessions"
    local tracked_sessions loose_sessions
    tracked_sessions=$(session_folder "$PROJECT_DIR")
    loose_sessions=$(session_folder "$OTHER_DIR")
    mkdir -p "$PROJECT_DIR/llm-transcripts" "$OTHER_DIR/llm-transcripts" "$tracked_sessions" "$loose_sessions"
    TRACKED="$tracked_sessions/44444444-4444-4444-4444-444444444444.jsonl"
    LOOSE="$loose_sessions/55555555-5555-5555-5555-555555555555.jsonl"

    git -C "$REPO" init -q -b main
    git -C "$REPO" config user.name "rename test"
    git -C "$REPO" config user.email "rename-test@example.invalid"

    # Midday UTC, so the calendar day is the same in any western timezone.
    # The first answer is long on purpose: git only calls a delete-plus-add a
    # rename while the two files are at least half alike, and a real
    # transcript is long enough that one more exchange never breaks that. A
    # two-line fixture would drop below it and test git's guess, not the hook.
    local long_answer="" n
    for n in $(seq 1 40); do
        long_answer="${long_answer}Paragraph $n of the first day's long answer, which carries most of the file.\\n\\n"
    done
    cat > "$TRACKED" <<EOF
{"type":"user","timestamp":"2026-07-20T18:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Day one question."}}
{"type":"assistant","timestamp":"2026-07-20T18:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"${long_answer}Day one answer."}]}}
EOF
    cat > "$LOOSE" <<'EOF'
{"type":"user","timestamp":"2026-07-22T18:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Loose day one."}}
{"type":"assistant","timestamp":"2026-07-22T18:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Loose answer one."}]}}
EOF
}
# }}}

# -- {{{ append_exchange
function append_exchange() {
    local log="$1" day="$2" words="$3"
    cat >> "$log" <<EOF
{"type":"user","timestamp":"2026-07-${day}T18:00:00.000Z","uuid":"u-$day-$RANDOM","message":{"role":"user","content":"$words question."}}
{"type":"assistant","timestamp":"2026-07-${day}T18:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"$words answer."}]}}
EOF
}
# }}}

# -- {{{ run_exporter
function run_exporter() {
    local project="$1"
    EXPORT_OUTPUT=$(CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" "$EXPORTER" "$project" 2>&1)
    EXPORT_STATUS=$?
}
# }}}

# -- {{{ status_line
# The porcelain status line naming a transcript, e.g. "R  proj/llm-transcripts
# /a.md -> proj/llm-transcripts/b.md". The first column is the staging list
# against the last commit, the second the disk against the staging list.
function status_line() {
    local name="$1"
    # every untracked file named singly, not folded into its folder's line
    git -C "$REPO" status --porcelain --untracked-files=all | grep -F "$name"
}
# }}}

# -- {{{ main
function main() {
    build_fixtures
    local ok line

    # Stage 1: one day each. Commit only the tracked conversation's file, by
    # hand, as its starting point.
    run_exporter "$PROJECT_DIR"
    ok=no
    [ "$EXPORT_STATUS" -eq 0 ] && ok=yes
    check "first export succeeds" "$ok"
    run_exporter "$OTHER_DIR"
    git -C "$REPO" add -- proj/llm-transcripts/jul-20-26.md
    git -C "$REPO" commit -q -m "day one"

    # Stage 2: both conversations cross into a second day.
    append_exchange "$TRACKED" 21 "Day two"
    append_exchange "$LOOSE" 23 "Loose day two"
    run_exporter "$PROJECT_DIR"
    ok=no
    [ "$EXPORT_STATUS" -eq 0 ] && ok=yes
    check "export across the day boundary succeeds" "$ok"
    ok=no
    case "$EXPORT_OUTPUT" in
        *"staged rename: jul-20-26.md -> jul-20-26-through-jul-21-26.md"*) ok=yes ;;
    esac
    check "the rename is announced" "$ok"
    run_exporter "$OTHER_DIR"

    line=$(status_line "jul-20-26-through-jul-21-26.md")
    ok=no
    [ "$line" = "R  proj/llm-transcripts/jul-20-26.md -> proj/llm-transcripts/jul-20-26-through-jul-21-26.md" ] && ok=yes
    check "tracked transcript shows as a staged rename, not deleted + untracked (got: '$line')" "$ok"

    line=$(status_line "jul-22-26")
    ok=no
    [ "$line" = "?? other/llm-transcripts/jul-22-26-through-jul-23-26.md" ] && ok=yes
    check "a transcript git never knew stays untracked, nothing staged (got: '$line')" "$ok"

    # Stage 3: another reply the same day rewrites the renamed file in place.
    append_exchange "$TRACKED" 21 "Day two again"
    run_exporter "$PROJECT_DIR"
    line=$(status_line "jul-20-26-through-jul-21-26.md")
    ok=no
    [ "$line" = "R  proj/llm-transcripts/jul-20-26.md -> proj/llm-transcripts/jul-20-26-through-jul-21-26.md" ] && ok=yes
    check "a later rewrite keeps the staged copy current, no unstaged half (got: '$line')" "$ok"

    # Stage 4: the real commit route commits the project's transcripts. Its
    # tidy-up of the shared staging list must find the hook's staged copies
    # already equal to what it committed: no warning, nothing left staged.
    local route_output route_status
    route_output=$(CLAUDE_CODE_SESSION_ID="$SESSION_ID" CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" \
        "$COMMIT_ROUTE" "$REPO" --project "$PROJECT_DIR" --scripts-dir "$DIR/scripts" -m "day two" 2>&1)
    route_status=$?
    ok=no
    [ "$route_status" -eq 0 ] && ok=yes
    check "the commit route commits the renamed transcript (status $route_status)" "$ok"
    ok=yes
    case "$route_output" in
        *WARNING*|*"NOT SYNCED"*) ok=no ;;
    esac
    check "the commit route's tidy-up prints no warning" "$ok"
    line=$(git -C "$REPO" show -M --name-status --format= HEAD -- proj/llm-transcripts)
    ok=no
    case "$line" in
        R*"proj/llm-transcripts/jul-20-26.md"*"proj/llm-transcripts/jul-20-26-through-jul-21-26.md"*) ok=yes ;;
    esac
    check "the commit records a rename (got: '$line')" "$ok"
    line=$(git -C "$REPO" status --porcelain -- proj)
    ok=no
    [ -z "$line" ] && ok=yes
    check "after the commit the project's git status is clean (got: '$line')" "$ok"

    # Stage 5: once committed, a change is an ordinary unstaged edit.
    append_exchange "$TRACKED" 21 "Day two once more"
    run_exporter "$PROJECT_DIR"
    line=$(status_line "jul-20-26-through-jul-21-26.md")
    ok=no
    [ "$line" = " M proj/llm-transcripts/jul-20-26-through-jul-21-26.md" ] && ok=yes
    check "after the commit, a rewrite is left unstaged (got: '$line')" "$ok"

    # Stage 6: someone hand-stages their own copy of the uncommitted loose
    # transcript; the hook must not replace it with its own.
    local theirs staged
    theirs=$(printf 'someone else\n' | git -C "$REPO" hash-object -w --stdin)
    git -C "$REPO" update-index --add --cacheinfo "100644,$theirs,other/llm-transcripts/jul-22-26-through-jul-23-26.md"
    append_exchange "$LOOSE" 23 "Loose day two again"
    run_exporter "$OTHER_DIR"
    staged=$(git -C "$REPO" ls-files --stage -- other/llm-transcripts/jul-22-26-through-jul-23-26.md | awk '{ print $2 }')
    ok=no
    [ "$staged" = "$theirs" ] && ok=yes
    check "a staged copy someone else wrote is left alone" "$ok"

    if [ "$FAIL" -ne 0 ]; then
        echo "--- last exporter output ---"
        printf '%s\n' "$EXPORT_OUTPUT"
        echo "--- commit route output ---"
        printf '%s\n' "$route_output"
    fi
    rm -rf "$SCRATCH"
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
