#!/bin/bash
# test-backup-conversations-sessions.sh - proves the conversation backup finds
# every conversation it should, exports only what it is asked to, and fails
# out loud when it cannot.
#
# In general terms: builds a throwaway project and a fake copy of Claude's
# session store, then runs the backup against it the way Claude Code does
# after every reply (the "Stop hook", which names one conversation) and the
# way a person does by hand (a sweep of the whole project). It checks:
#
#   - helper-agent ("subagent") conversations, which Claude now files one
#     folder deeper than it used to, are found and saved (issue 025);
#   - a forked helper's orders and replies reach its transcript, not just an
#     empty header;
#   - a project whose path has a dot in it is found (Claude turns the dot into
#     a dash, and the old lookup did not);
#   - the hook exports only the conversation it was told about;
#   - two exports of the same conversation at the same moment still produce
#     exactly one file;
#   - every failure - no session folder, garbled hook input, a log the parser
#     cannot read - ends in a non-zero exit and a message, and a failed lookup
#     leaves no empty llm-transcripts/ folder behind.
#
# Nothing under ~/.claude is touched: the backup is pointed at the fixtures
# through CLAUDE_SESSIONS_ROOT.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

EXPORTER="$DIR/scripts/backup-conversations"
SCRATCH="${TMPDIR:-/tmp}/backup-conversations-sessions-test-$$"

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

# -- {{{ session_folder_name
# The folder name Claude Code gives a project path: every character that is
# not a letter or digit becomes a dash. Written out independently here so the
# test does not borrow the code it is testing.
function session_folder_name() {
    printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}
# }}}

# -- {{{ build_fixtures
function build_fixtures() {
    SESSIONS_ROOT="$SCRATCH/sessions"

    # A project with a dot in its path, as .config/nvim has.
    PROJECT_DIR="$SCRATCH/dot.project"
    mkdir -p "$PROJECT_DIR"
    SESSION_FOLDER="$SESSIONS_ROOT/$(session_folder_name "$PROJECT_DIR")"
    mkdir -p "$SESSION_FOLDER"

    MAIN_ID="aaaaaaaa-1111-1111-1111-111111111111"
    OTHER_ID="bbbbbbbb-2222-2222-2222-222222222222"

    # The conversation the hook will be told about.
    cat > "$SESSION_FOLDER/$MAIN_ID.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-09-01T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Please review the skills."}}
{"type":"assistant","timestamp":"2026-09-01T10:00:05.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"Sending a reviewer now."}]}}
EOF

    # A different conversation in the same project, same day. The hook must
    # leave it alone; the sweep must export it.
    cat > "$SESSION_FOLDER/$OTHER_ID.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-09-01T12:00:00.000Z","uuid":"u1","message":{"role":"user","content":"An unrelated afternoon question."}}
{"type":"assistant","timestamp":"2026-09-01T12:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"An unrelated afternoon answer."}]}}
EOF

    # A helper spawned by the main conversation, in the current nested layout.
    mkdir -p "$SESSION_FOLDER/$MAIN_ID/subagents"
    cat > "$SESSION_FOLDER/$MAIN_ID/subagents/agent-a1b2c3.jsonl" <<'EOF'
{"type":"user","isSidechain":true,"agentId":"a1b2c3","timestamp":"2026-09-01T10:00:06.000Z","uuid":"s1","message":{"role":"user","content":"READ-ONLY review of the skills."}}
{"type":"assistant","isSidechain":true,"agentId":"a1b2c3","timestamp":"2026-09-01T10:03:00.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"The skills are reviewed; nothing was changed."}]}}
EOF

    # A forked helper: its log points back at the parent instead of repeating
    # the parent's history, and its orders arrive riding on a tool result.
    cat > "$SESSION_FOLDER/$MAIN_ID/subagents/agent-f0f0f0.jsonl" <<'EOF'
{"type":"fork-context-ref","agentId":"f0f0f0","parentSessionId":"aaaaaaaa-1111-1111-1111-111111111111","contextLength":12}
{"type":"assistant","isSidechain":true,"agentId":"f0f0f0","timestamp":"2026-09-01T10:04:00.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"tool_use","id":"toolu_1","name":"Agent","input":{"prompt":"x"}}]}}
{"type":"user","isSidechain":true,"agentId":"f0f0f0","timestamp":"2026-09-01T10:04:01.000Z","uuid":"f1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"Fork started"},{"type":"text","text":"<fork-boilerplate>You are a worker fork.</fork-boilerplate>\n\nYour directive: fix the backup hook."}]}}
{"type":"assistant","isSidechain":true,"agentId":"f0f0f0","timestamp":"2026-09-01T10:05:00.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"The backup hook is fixed."}]}}
EOF
}
# }}}

# -- {{{ hook_input
# The JSON record Claude Code hands a Stop hook, for a given session.
function hook_input() {
    local id="$1"
    printf '{"session_id":"%s","transcript_path":"%s/%s.jsonl","cwd":"%s","hook_event_name":"Stop","stop_hook_active":false}\n' \
        "$id" "$SESSION_FOLDER" "$id" "$PROJECT_DIR"
}
# }}}

# -- {{{ run_hook
function run_hook() {
    HOOK_OUTPUT=$(hook_input "$1" | CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" \
        CLAUDE_PROJECT_DIR="$PROJECT_DIR" "$EXPORTER" --hook 2>&1)
    HOOK_STATUS=$?
}
# }}}

# -- {{{ transcript_claiming
# The transcript in the project whose header claims a conversation id, if any.
function transcript_claiming() {
    grep -lx "# Conversation Summary: $1" "$PROJECT_DIR/llm-transcripts"/*.md 2>&1 | grep -v 'No such file' | head -1
}
# }}}

# -- {{{ test_hook_exports_named_session_and_its_helpers
function test_hook_exports_named_session_and_its_helpers() {
    run_hook "$MAIN_ID"
    check "hook: exits cleanly (status $HOOK_STATUS)" \
        "$([ "$HOOK_STATUS" = 0 ] && echo yes || echo no)"

    local main_file helper_file fork_file other_file
    main_file=$(transcript_claiming "$MAIN_ID")
    helper_file=$(transcript_claiming "agent-a1b2c3")
    fork_file=$(transcript_claiming "agent-f0f0f0")
    other_file=$(transcript_claiming "$OTHER_ID")

    check "hook: the named conversation claims the bare date name ($(basename "$main_file"))" \
        "$([ "$(basename "$main_file")" = "sep-1-26.md" ] && echo yes || echo no)"
    check "hook: the nested helper conversation is saved ($(basename "$helper_file"))" \
        "$([ -n "$helper_file" ] && grep -q "nothing was changed" "$helper_file" && echo yes || echo no)"
    check "hook: the fork's directive reaches its transcript" \
        "$([ -n "$fork_file" ] && grep -q "Your directive: fix the backup hook." "$fork_file" && echo yes || echo no)"
    check "hook: the fork's reply reaches its transcript" \
        "$([ -n "$fork_file" ] && grep -q "The backup hook is fixed." "$fork_file" && echo yes || echo no)"
    check "hook: the harness's fork boilerplate is left out" \
        "$([ -n "$fork_file" ] && ! grep -q "worker fork" "$fork_file" && echo yes || echo no)"
    check "hook: a conversation the hook was not told about is left alone" \
        "$([ -z "$other_file" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_sweep_exports_everything_and_counts_helpers
function test_sweep_exports_everything_and_counts_helpers() {
    local out status
    out=$(CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" "$EXPORTER" "$PROJECT_DIR" 2>&1)
    status=$?
    check "sweep: exits cleanly (status $status)" \
        "$([ "$status" = 0 ] && echo yes || echo no)"
    check "sweep: reports the helper logs it found" \
        "$(echo "$out" | grep -q "2 conversation(s), 2 helper-agent log(s)" && echo yes || echo no)"
    check "sweep: the other conversation is exported too" \
        "$([ -n "$(transcript_claiming "$OTHER_ID")" ] && echo yes || echo no)"

    local count
    count=$(ls "$PROJECT_DIR/llm-transcripts"/*.md | wc -l)
    check "sweep: one file per conversation, no duplicates ($count)" \
        "$([ "$count" = 4 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_simultaneous_exports_make_one_file
# Two sessions stopping at the same moment both run the hook. Without the
# lock, both could see a name as free and both take it.
function test_simultaneous_exports_make_one_file() {
    local project="$SCRATCH/race-project"
    mkdir -p "$project"
    local folder="$SESSIONS_ROOT/$(session_folder_name "$project")"
    mkdir -p "$folder"
    cp "$SESSION_FOLDER/$MAIN_ID.jsonl" "$folder/$MAIN_ID.jsonl"
    local input
    input=$(printf '{"session_id":"%s","transcript_path":"%s/%s.jsonl"}' "$MAIN_ID" "$folder" "$MAIN_ID")

    local i
    for i in 1 2 3 4; do
        printf '%s\n' "$input" | CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" \
            CLAUDE_PROJECT_DIR="$project" "$EXPORTER" --hook > "$SCRATCH/race-$i.out" 2>&1 &
    done
    wait

    local count
    count=$(ls "$project/llm-transcripts"/*.md | wc -l)
    check "race: four simultaneous exports leave exactly one file ($count)" \
        "$([ "$count" = 1 ] && echo yes || echo no)"
    local leftovers
    leftovers=$(ls -A "$project/llm-transcripts" | grep -c '^\.transcript-' || true)
    check "race: no temp files left behind ($leftovers)" \
        "$([ "$leftovers" = 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_missing_session_folder_fails_loudly
function test_missing_session_folder_fails_loudly() {
    local stranger="$SCRATCH/never-used-with-claude"
    mkdir -p "$stranger"
    local out status
    out=$(CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" "$EXPORTER" "$stranger" 2>&1)
    status=$?
    check "missing session folder: non-zero exit (status $status)" \
        "$([ "$status" != 0 ] && echo yes || echo no)"
    check "missing session folder: says what it looked for" \
        "$(echo "$out" | grep -q "no session folder" && echo yes || echo no)"
    check "missing session folder: no empty llm-transcripts/ left behind" \
        "$([ ! -e "$stranger/llm-transcripts" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_garbled_hook_input_fails_loudly
function test_garbled_hook_input_fails_loudly() {
    local out status
    out=$(printf 'this is not json\n' | CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" \
        CLAUDE_PROJECT_DIR="$PROJECT_DIR" "$EXPORTER" --hook 2>&1)
    status=$?
    check "garbled hook input: non-zero exit (status $status)" \
        "$([ "$status" != 0 ] && echo yes || echo no)"
    # Exit code 2 would tell Claude Code to refuse to stop and keep working.
    check "garbled hook input: never exit 2, which would block stopping" \
        "$([ "$status" != 2 ] && echo yes || echo no)"
    check "garbled hook input: says the input had no session" \
        "$(echo "$out" | grep -q "no session_id" && echo yes || echo no)"
}
# }}}

# -- {{{ test_unreadable_log_fails_but_others_still_export
function test_unreadable_log_fails_but_others_still_export() {
    local project="$SCRATCH/unreadable-project"
    mkdir -p "$project"
    local folder="$SESSIONS_ROOT/$(session_folder_name "$project")"
    mkdir -p "$folder"
    cp "$SESSION_FOLDER/$OTHER_ID.jsonl" "$folder/$OTHER_ID.jsonl"
    cp "$SESSION_FOLDER/$MAIN_ID.jsonl" "$folder/$MAIN_ID.jsonl"
    chmod 000 "$folder/$MAIN_ID.jsonl"

    local out status
    out=$(CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" "$EXPORTER" "$project" 2>&1)
    status=$?
    chmod 600 "$folder/$MAIN_ID.jsonl"

    check "unreadable log: non-zero exit (status $status)" \
        "$([ "$status" != 0 ] && echo yes || echo no)"
    check "unreadable log: the failure is named" \
        "$(echo "$out" | grep -q "parser failed on .*$MAIN_ID" && echo yes || echo no)"
    check "unreadable log: the readable conversation is still exported" \
        "$(grep -lqx "# Conversation Summary: $OTHER_ID" "$project/llm-transcripts"/*.md && echo yes || echo no)"
}
# }}}

# -- {{{ test_linked_project_is_found_under_the_spelling_it_started_with
# A project reached through a symlink - or moved and linked back, as the Claude
# Code program folder was on 2026-09-22 - has its sessions filed under the
# link's spelling, while its real path spells a folder that does not exist.
# Before the fix both the hook and the sweep looked only under the real
# spelling, so every export for such a session failed.
function test_linked_project_is_found_under_the_spelling_it_started_with() {
    local real="$SCRATCH/moved-home/linked.project"
    local link="$SCRATCH/old-home"
    mkdir -p "$real" "$SCRATCH/moved-home"
    ln -s "$SCRATCH/moved-home" "$link"
    local link_spelling="$link/linked.project"
    local folder="$SESSIONS_ROOT/$(session_folder_name "$link_spelling")"
    local id="cccccccc-3333-3333-3333-333333333333"
    mkdir -p "$folder"
    cat > "$folder/$id.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-09-02T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Move the folder and link it back."}}
{"type":"assistant","timestamp":"2026-09-02T10:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Moved and linked."}]}}
EOF

    # The hook, told the real path as its project (what Claude Code reports
    # once the folder has moved) and the log's true location.
    local out status
    out=$(printf '{"session_id":"%s","transcript_path":"%s/%s.jsonl","cwd":"%s","hook_event_name":"Stop"}\n' \
            "$id" "$folder" "$id" "$real" \
        | CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" CLAUDE_PROJECT_DIR="$real" "$EXPORTER" --hook 2>&1)
    status=$?
    check "linked: the hook exports a session filed under the link's spelling (status $status)" \
        "$([ "$status" = 0 ] && grep -q "Moved and linked." "$real/llm-transcripts"/*.md && echo yes || echo no)"

    # The sweep, given the link spelling, finds the same folder.
    rm -rf "$real/llm-transcripts"
    out=$(CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" "$EXPORTER" "$link_spelling" 2>&1)
    status=$?
    check "linked: the sweep finds the session folder under the spelling it was given (status $status)" \
        "$([ "$status" = 0 ] && grep -q "Moved and linked." "$real/llm-transcripts"/*.md && echo yes || echo no)"
}
# }}}

echo "backup-conversations session-selection test suite"
build_fixtures
test_hook_exports_named_session_and_its_helpers
test_sweep_exports_everything_and_counts_helpers
test_linked_project_is_found_under_the_spelling_it_started_with
test_simultaneous_exports_make_one_file
test_missing_session_folder_fails_loudly
test_garbled_hook_input_fails_loudly
test_unreadable_log_fails_but_others_still_export
rm -rf "$SCRATCH"
echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ] || exit 1
exit 0
