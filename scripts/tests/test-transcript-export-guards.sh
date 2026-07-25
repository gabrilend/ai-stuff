#!/bin/bash
# test-transcript-export-guards.sh - proves the exporter's issue-020 guards.
#
# In general terms: builds a throwaway fake project and a fake sessions root,
# feeds the exporter three hand-made session logs - a complete exchange, an
# empty "husk" session with a stale transcript to retire, and a log that ends
# with an unanswered user message - and checks the exporter writes the right
# files, retires the right files, and warns loudly where it must.
#
# The exporter is pointed at the fixtures via CLAUDE_SESSIONS_ROOT, the
# environment seam added by issue 020; nothing under ~/.claude is touched.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

EXPORTER="$DIR/scripts/backup-conversations"
SCRATCH="${TMPDIR:-/tmp}/transcript-export-guard-test-$$"

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

# -- {{{ build_fixtures
function build_fixtures() {
    PROJECT_DIR="$SCRATCH/fake-project"
    SESSIONS_ROOT="$SCRATCH/sessions"
    local dashed
    dashed="-$(echo "$PROJECT_DIR" | sed 's|^/||' | tr '/' '-')"
    SESSION_DIR="$SESSIONS_ROOT/$dashed"
    mkdir -p "$PROJECT_DIR/llm-transcripts" "$SESSION_DIR"

    # Fixture 1: a complete one-exchange conversation. The final reply is on
    # disk, so the guard must stay quiet and the reply must be exported.
    cat > "$SESSION_DIR/11111111-1111-1111-1111-111111111111.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-07-20T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Hello there, what is up?"}}
{"type":"assistant","timestamp":"2026-07-20T10:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"The sky, mostly."}]}}
EOF

    # Fixture 2: a husk - titled, never spoken in, no timestamps anywhere.
    # Also pre-place a stale transcript claiming this conversation under an
    # arbitrary name, to prove retirement is keyed on the header, not the name.
    cat > "$SESSION_DIR/22222222-2222-2222-2222-222222222222.jsonl" <<'EOF'
{"type":"ai-title","aiTitle":"A session that never happened","sessionId":"22222222-2222-2222-2222-222222222222"}
EOF
    cat > "$PROJECT_DIR/llm-transcripts/some-old-husk-name.md" <<'EOF'
# Conversation Summary: 22222222-2222-2222-2222-222222222222

Generated on: 2026-07-10 12:00:00

--------------------------------------------------------------------------------
EOF

    # Fixture 3: the race shape - a user message with no reply after it. The
    # guard should retry, surrender loudly, and still export the file.
    cat > "$SESSION_DIR/33333333-3333-3333-3333-333333333333.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-07-21T09:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Are you there?"}}
EOF
}
# }}}

# -- {{{ run_exporter
function run_exporter() {
    EXPORT_OUTPUT=$(CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" "$EXPORTER" "$PROJECT_DIR")
}
# }}}

# -- {{{ test_complete_exchange_exports_reply
function test_complete_exchange_exports_reply() {
    local f="$PROJECT_DIR/llm-transcripts/jul-20-26.md"
    local ok=no
    if [ -f "$f" ] && grep -q "The sky, mostly." "$f"; then
        ok=yes
    fi
    check "complete exchange: transcript exists and contains the reply" "$ok"

    # Line-scoped on purpose: the whole-output glob would span from fixture
    # 1's id to fixture 3's legitimate warning and cry wolf.
    local quiet=yes
    if echo "$EXPORT_OUTPUT" | grep -q "11111111.*unanswered"; then
        quiet=no
    fi
    check "complete exchange: guard stays quiet" "$quiet"
}
# }}}

# -- {{{ test_husk_writes_nothing_and_retires_claim
function test_husk_writes_nothing_and_retires_claim() {
    local ok=yes
    [ -f "$PROJECT_DIR/llm-transcripts/some-old-husk-name.md" ] && ok=no
    check "husk: stale claim file was retired" "$ok"

    local warned=no
    case "$EXPORT_OUTPUT" in
        *"no messages in 22222222"*) warned=yes ;;
    esac
    check "husk: loud warning printed" "$warned"

    # No file anywhere may claim the husk conversation afterwards.
    local claims=0 f
    for f in "$PROJECT_DIR/llm-transcripts"/*.md; do
        [ -e "$f" ] || continue
        head -1 "$f" | grep -q "22222222" && claims=$((claims + 1))
    done
    check "husk: no transcript claims the conversation (claims: $claims)" \
        "$([ "$claims" = 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_race_shape_surrenders_loudly_but_exports
function test_race_shape_surrenders_loudly_but_exports() {
    local warned=no
    case "$EXPORT_OUTPUT" in
        *"33333333"*"unanswered user message"*) warned=yes ;;
    esac
    check "race shape: loud surrender line printed" "$warned"

    local f="$PROJECT_DIR/llm-transcripts/jul-21-26.md"
    local ok=no
    if [ -f "$f" ] && grep -q "Are you there?" "$f"; then
        ok=yes
    fi
    check "race shape: file still exported as-is" "$ok"
}
# }}}

echo "transcript export guard test suite"
build_fixtures
run_exporter
test_complete_exchange_exports_reply
test_husk_writes_nothing_and_retires_claim
test_race_shape_surrenders_loudly_but_exports
rm -rf "$SCRATCH"
echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ] || exit 1
exit 0
