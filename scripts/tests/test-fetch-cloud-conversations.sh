#!/bin/bash
# test-fetch-cloud-conversations.sh - proves the cloud fetcher brings cloud
# sessions home and hands them to the transcript toolchain (issue 051).
#
# In general terms: stands a fake cloud in for the real one (a small script
# that answers each address from a folder of prepared answers), points the
# fetcher at a throwaway sign-in and a throwaway sessions store, and checks:
#
#   - the session listing is followed across pages;
#   - a session's log is read page by page from its first event, under the
#     cse_ form of its id, and arrives oldest first, one event per line;
#   - a session the paged feed does not know is read from the older one-shot
#     feed instead;
#   - a session is filed under the project its repository is mapped to, and
#     under the default project otherwise;
#   - each fetched log becomes a transcript in that project's llm-transcripts/;
#   - a second run with nothing new changes nothing and exports nothing;
#   - a session that grew is fetched again and re-exported;
#   - the token reaches the cloud only inside the header file, never as an
#     argument, and the header file is gone when the run ends;
#   - an export that fails stops the run and names the session;
#   - an expired sign-in, a refused sign-in and a missing sign-in each stop the
#     run with a message that says what to do.
#
# Nothing under ~/.claude is read or written, and nothing leaves this computer.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

FETCHER="$DIR/scripts/fetch-cloud-conversations"
SCRATCH="${TMPDIR:-/tmp}/fetch-cloud-conversations-test-$$"

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

# -- {{{ yes_if
# "yes" when the command succeeds, "no" otherwise, for check's second argument.
function yes_if() {
    if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi
}
# }}}

# -- {{{ session_folder_name
# Written out independently so the test does not borrow the code it tests.
function session_folder_name() {
    printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'
}
# }}}

# -- {{{ answer
# Prepare the fake cloud's answer to one address: a status and a body.
function answer() {
    local url="$1" status="$2" body="$3"
    local key
    key=$(printf '%s' "$url" | md5sum | cut -c1-16)
    printf '%s\n' "$status" > "$CLOUD/$key.status"
    printf '%s\n' "$body" > "$CLOUD/$key.body"
}
# }}}

# -- {{{ build_fake_cloud
# The fake cloud is a script run as `<it> <url> <header-file> <body-out>`. It
# records each call (the arguments, and whether the header file carried the
# token) and answers from the prepared folder; an address it was not told
# about answers 599, so a wrong address shows up as a failed run.
function build_fake_cloud() {
    CLOUD="$SCRATCH/cloud"
    mkdir -p "$CLOUD"
    FAKE="$SCRATCH/fake-cloud"
    cat > "$FAKE" <<'EOF'
#!/bin/bash
url="$1" headers="$2" out="$3"
printf '%s\n' "$*" >> "$CLOUD/calls"
if grep -q "^Authorization: Bearer $EXPECTED_TOKEN\$" "$headers" \
   && grep -q '^x-organization-uuid: org-1234$' "$headers" \
   && grep -q '^anthropic-beta: ccr-byoc-2025-07-29$' "$headers"; then
    echo signed >> "$CLOUD/signed"
fi
printf '%s\n' "$headers" > "$CLOUD/last-header-file"
key=$(printf '%s' "$url" | md5sum | cut -c1-16)
if [ -f "$CLOUD/$key.status" ]; then
    cp "$CLOUD/$key.body" "$out"
    cat "$CLOUD/$key.status" | tr -d '\n'
else
    printf '{"error":"unknown address %s"}' "$url" > "$out"
    printf '599'
fi
EOF
    chmod +x "$FAKE"
}
# }}}

# -- {{{ build_fixtures
function build_fixtures() {
    API="https://cloud.test"
    TOKEN="tok-SECRET-0001"

    # A throwaway sign-in, shaped like the one Claude Code keeps.
    CREDENTIALS="$SCRATCH/credentials.json"
    ACCOUNT="$SCRATCH/account.json"
    printf '{"claudeAiOauth":{"accessToken":"%s","expiresAt":%s}}\n' \
        "$TOKEN" "$(( ($(date +%s) + 3600) * 1000 ))" > "$CREDENTIALS"
    printf '{"oauthAccount":{"organizationUuid":"org-1234"}}\n' > "$ACCOUNT"

    # Two projects: the default one for unmapped sessions, and one a
    # repository is mapped to. A dot in the path checks the folder naming.
    HOME_PROJECT="$SCRATCH/home.ritz"
    MAPPED_PROJECT="$SCRATCH/programming/ai-stuff"
    mkdir -p "$HOME_PROJECT" "$MAPPED_PROJECT"
    MAP="$SCRATCH/cloud-session-projects"
    printf '# repository   project\nai-stuff   %s\n' "$MAPPED_PROJECT" > "$MAP"

    STORE="$SCRATCH/cloud-projects"

    # The listing, in two pages.
    answer "$API/v1/sessions?limit=100" 200 \
        '{"data":[{"id":"session_01AAAA","title":"Grocery list","created_at":"2026-11-01T10:00:00Z","updated_at":"2026-11-01T10:05:00Z","session_context":{"sources":[]}}],"has_more":true,"first_id":"session_01AAAA","last_id":"session_01AAAA"}'
    answer "$API/v1/sessions?limit=100&after_id=session_01AAAA" 200 \
        '{"data":[{"id":"session_01BBBB","title":"Fix the exporter","created_at":"2026-10-31T09:00:00Z","updated_at":"2026-10-31T09:30:00Z","session_context":{"sources":[{"type":"git_repository","url":"https://github.com/gabrilend/ai-stuff.git"}]}}],"has_more":false,"first_id":"session_01BBBB","last_id":"session_01BBBB"}'

    # Session A: two pages of the paged feed. Its second page holds a row
    # with no payload, which must be skipped.
    A_FEED="$API/v1/code/sessions/cse_01AAAA/teleport-events"
    answer "$A_FEED?limit=1000&from_first_event=true" 200 \
        '{"data":[{"payload":{"type":"user","timestamp":"2026-11-01T10:00:00.000Z","uuid":"a1","message":{"role":"user","content":"What goes on the grocery list?"}}}],"next_cursor":"c2"}'
    answer "$A_FEED?limit=1000&cursor=c2" 200 \
        '{"data":[{"payload":null},{"payload":{"type":"assistant","timestamp":"2026-11-01T10:00:05.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"Bread, cheese and blackberries."}]}}}],"next_cursor":null}'

    # Session B: the paged feed does not know it; the one-shot feed does.
    answer "$API/v1/code/sessions/cse_01BBBB/teleport-events?limit=1000&from_first_event=true" 404 '{"error":"not found"}'
    answer "$API/v1/session_ingress/session/session_01BBBB" 200 \
        '{"loglines":[{"type":"user","timestamp":"2026-10-31T09:00:00.000Z","uuid":"b1","message":{"role":"user","content":"Why does the exporter skip cloud sessions?"}},{"type":"assistant","timestamp":"2026-10-31T09:00:05.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"They never reach this computer."}]}}]}'
}
# }}}

# -- {{{ run_fetcher
# Run the fetcher against the fakes. Output goes to $SCRATCH/out and err.
function run_fetcher() {
    CLOUD="$CLOUD" EXPECTED_TOKEN="$TOKEN" \
    SCRIPTS_DIR="${TEST_SCRIPTS_DIR:-$DIR/scripts}" \
    CLAUDE_CLOUD_API="$API" \
    CLAUDE_CREDENTIALS_FILE="$CREDENTIALS" \
    CLAUDE_ACCOUNT_FILE="$ACCOUNT" \
    CLOUD_SESSIONS_ROOT="$STORE" \
    CLOUD_TRANSCRIPT_PROJECT="$HOME_PROJECT" \
    CLOUD_SESSION_PROJECTS="$MAP" \
    CLOUD_HTTP_GET="$FAKE" \
        "$FETCHER" "$@" > "$SCRATCH/out" 2> "$SCRATCH/err"
}
# }}}

# -- {{{ transcript_of
# The transcript file in a project whose header names this session.
function transcript_of() {
    grep -l "^# Conversation Summary: $2\$" "$1"/llm-transcripts/*.md 2>/dev/null | head -n 1
}
# }}}

function main() {
    [ -n "${KEEP:-}" ] || rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    build_fake_cloud
    build_fixtures

    local a_log="$STORE/$(session_folder_name "$HOME_PROJECT")/session_01AAAA.jsonl"
    local b_log="$STORE/$(session_folder_name "$MAPPED_PROJECT")/session_01BBBB.jsonl"

    echo "Listing"
    run_fetcher --list
    local status=$?
    check "--list succeeds" "$([ $status -eq 0 ] && echo yes || echo no)"
    check "--list shows both pages of sessions" \
        "$( [ "$(wc -l < "$SCRATCH/out")" -eq 2 ] && grep -q 'session_01BBBB' "$SCRATCH/out" && echo yes || echo no)"
    check "--list fetches no log" "$(yes_if bash -c "! grep -q teleport-events '$CLOUD/calls'")"

    echo "First run"
    : > "$CLOUD/calls"; : > "$CLOUD/signed"
    run_fetcher
    status=$?
    check "the run succeeds" "$([ $status -eq 0 ] && echo yes || echo no)"
    cp "$SCRATCH/err" "$SCRATCH/err.first"
    [ $status -eq 0 ] || sed 's/^/    /' "$SCRATCH/err"
    check "it reports two new sessions" "$(yes_if grep -q 'Cloud sessions: 2 new, 0 changed, 0 unchanged' "$SCRATCH/out")"
    check "an unmapped session is filed under the default project" "$(yes_if test -f "$a_log")"
    check "a mapped session is filed under its repository's project" "$(yes_if test -f "$b_log")"
    check "a paged log arrives whole, oldest first, payload-less rows skipped" \
        "$( [ "$(wc -l < "$a_log")" -eq 2 ] && [ "$(head -n1 "$a_log" | jq -r .uuid)" = a1 ] && echo yes || echo no)"
    check "a log the paged feed lacks is read from the one-shot feed" \
        "$( [ "$(wc -l < "$b_log")" -eq 2 ] && echo yes || echo no)"
    check "every call carried the sign-in in its header file" \
        "$( [ "$(wc -l < "$CLOUD/signed")" -eq "$(wc -l < "$CLOUD/calls")" ] && echo yes || echo no)"
    check "the token never appears in a call's arguments" "$(yes_if bash -c "! grep -q '$TOKEN' '$CLOUD/calls'")"
    check "the header file is gone after the run" "$(yes_if bash -c "! test -e \"\$(cat '$CLOUD/last-header-file')\"")"
    local a_md b_md
    a_md=$(transcript_of "$HOME_PROJECT" session_01AAAA)
    b_md=$(transcript_of "$MAPPED_PROJECT" session_01BBBB)
    check "the unmapped session became a transcript in its project" \
        "$( [ -n "$a_md" ] && grep -q 'blackberries' "$a_md" && echo yes || echo no)"
    check "the mapped session became a transcript in its project" \
        "$( [ -n "$b_md" ] && grep -q 'never reach this computer' "$b_md" && echo yes || echo no)"

    echo "Second run, nothing new"
    local a_before
    a_before=$(md5sum < "$a_md")
    touch -d '2000-01-01' "$a_md"
    run_fetcher
    check "it reports two unchanged sessions" "$(yes_if grep -q 'Cloud sessions: 0 new, 0 changed, 2 unchanged' "$SCRATCH/out")"
    check "the transcript was not exported again" \
        "$( [ "$(md5sum < "$a_md")" = "$a_before" ] && [ "$(stat -c %Y "$a_md")" -lt 1000000000 ] && echo yes || echo no)"

    echo "A session that grew"
    answer "$A_FEED?limit=1000&cursor=c2" 200 \
        '{"data":[{"payload":{"type":"assistant","timestamp":"2026-11-01T10:00:05.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"Bread, cheese and blackberries."}]}}}],"next_cursor":"c3"}'
    answer "$A_FEED?limit=1000&cursor=c3" 200 \
        '{"data":[{"payload":{"type":"user","timestamp":"2026-11-01T10:01:00.000Z","uuid":"a2","message":{"role":"user","content":"And eggs for hard boiling."}}},{"payload":{"type":"assistant","timestamp":"2026-11-01T10:01:05.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"Eggs are on the list."}]}}}],"next_cursor":""}'
    run_fetcher --session session_01AAAA
    check "--session fetches the one session and reports it changed" \
        "$(yes_if grep -q 'Cloud sessions: 0 new, 1 changed, 0 unchanged' "$SCRATCH/out")"
    a_md=$(transcript_of "$HOME_PROJECT" session_01AAAA)
    check "the grown session's transcript has the new turn" \
        "$( [ -n "$a_md" ] && grep -q 'Eggs are on the list' "$a_md" && echo yes || echo no)"

    echo "--fetch-only"
    rm -rf "$HOME_PROJECT/llm-transcripts" "$STORE"
    run_fetcher --fetch-only --limit 1
    check "--limit 1 looks at only the newest session" \
        "$(yes_if grep -q 'Cloud sessions: 1 new, 0 changed, 0 unchanged' "$SCRATCH/out")"
    check "--fetch-only writes the log" "$(yes_if test -f "$a_log")"
    check "--fetch-only writes no transcript" "$(yes_if test ! -e "$HOME_PROJECT/llm-transcripts")"

    echo "A failed export"
    local broken="$SCRATCH/broken-scripts"
    mkdir -p "$broken"
    printf '#!/bin/bash\nexit 1\n' > "$broken/backup-conversations"
    chmod +x "$broken/backup-conversations"
    rm -rf "$STORE"
    TEST_SCRIPTS_DIR="$broken" run_fetcher --limit 1
    status=$?
    check "an export that fails stops the run" "$([ $status -ne 0 ] && echo yes || echo no)"
    check "and says which session it was" "$(yes_if grep -q 'session_01AAAA: fetched, but backup-conversations could not export it' "$SCRATCH/err")"

    echo "Sign-in problems"
    printf '{"claudeAiOauth":{"accessToken":"%s","expiresAt":1000}}\n' "$TOKEN" > "$CREDENTIALS"
    local calls_before
    calls_before=$(wc -l < "$CLOUD/calls")
    run_fetcher --list
    status=$?
    check "an expired sign-in stops the run" "$([ $status -ne 0 ] && echo yes || echo no)"
    check "and says to start claude to refresh it" "$(yes_if grep -q 'expired; start `claude` once' "$SCRATCH/err")"
    check "and calls nothing" "$( [ "$(wc -l < "$CLOUD/calls")" -eq "$calls_before" ] && echo yes || echo no)"

    printf '{"claudeAiOauth":{"accessToken":"%s"}}\n' "$TOKEN" > "$CREDENTIALS"
    answer "$API/v1/sessions?limit=100" 401 '{"error":"bad token"}'
    run_fetcher --list
    status=$?
    check "a refused sign-in stops the run" "$([ $status -ne 0 ] && echo yes || echo no)"
    check "and says the sign-in was refused" "$(yes_if grep -q 'sign-in was refused (401)' "$SCRATCH/err")"

    rm -f "$CREDENTIALS"
    run_fetcher --list
    status=$?
    check "a missing sign-in stops the run" "$([ $status -ne 0 ] && echo yes || echo no)"
    check "and says to sign in" "$(yes_if grep -q 'no Claude Code sign-in' "$SCRATCH/err")"

    echo ""
    echo "$PASS passed, $FAIL failed"
    [ -n "${KEEP:-}" ] || rm -rf "$SCRATCH"
    [ "$FAIL" -eq 0 ]
}

main
