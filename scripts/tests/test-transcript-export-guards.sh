#!/bin/bash
# test-transcript-export-guards.sh - proves the exporter's guards and its
# two kinds of idempotency.
#
# In general terms: builds a throwaway fake project and a fake sessions root,
# feeds the exporter three hand-made session logs - a complete exchange, an
# empty "husk" session with a stale transcript to retire, and a log that ends
# with an unanswered user message - and checks the exporter writes the right
# files, retires the right files, and warns loudly where it must.
#
# It then runs the exporter twice more over the same fixtures for the two
# halves of idempotency: a conversation nobody added a word to is left
# entirely alone - same bytes, same inode - while one that really grew is
# still written out. Getting the first half wrong is not visible in any
# single transcript; it shows up as every file in a project going dirty
# again after every assistant turn.
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

# -- {{{ test_rerun_of_unchanged_conversation_touches_nothing
# The Stop hook fires after every assistant turn, so the overwhelming majority
# of exports find every conversation exactly as they left it. Such a run has to
# be a true no-op - not a rewrite that happens to carry the same prose under a
# fresh "Generated on:" stamp. That distinction is invisible to a reader and
# very visible to git: the rewrite version re-dirtied every transcript in a
# project seconds after each commit, and buried real transcript growth under
# one-line stamp diffs.
#
# The inode is the honest witness here. A rewrite arrives by mv, which replaces
# the file and mints a new inode; leaving the file alone keeps the old one. The
# mtime cannot tell the two apart, because the rewrite path immediately stamps
# the mtime back from the conversation's last message either way.
function test_rerun_of_unchanged_conversation_touches_nothing() {
    local f="$PROJECT_DIR/llm-transcripts/jul-20-26.md"
    local before_sum before_inode
    before_sum=$(md5sum < "$f")
    before_inode=$(stat -c %i "$f")

    # A full second, so a rewrite cannot hide inside the stamp's one-second
    # resolution and pass this test by coincidence.
    sleep 1
    run_exporter

    local after_sum after_inode
    after_sum=$(md5sum < "$f")
    after_inode=$(stat -c %i "$f")

    check "re-run: unchanged transcript is byte-identical, stamp included" \
        "$([ "$before_sum" = "$after_sum" ] && echo yes || echo no)"
    check "re-run: unchanged transcript is the same file, not a replacement" \
        "$([ "$before_inode" = "$after_inode" ] && echo yes || echo no)"

    local reported=no
    if echo "$EXPORT_OUTPUT" | grep -q "^Unchanged: .*jul-20-26\.md$"; then
        reported=yes
    fi
    check "re-run: the no-op is reported as Unchanged" "$reported"
}
# }}}

# -- {{{ test_grown_conversation_is_still_rewritten
# The mirror image, and the reason the check above is a content comparison
# rather than a blanket "never rewrite": a conversation that really did grow
# must still be written out. Same session, same calendar day, so the same file
# name - only the prose is longer.
function test_grown_conversation_is_still_rewritten() {
    cat >> "$SESSION_DIR/11111111-1111-1111-1111-111111111111.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-07-20T10:05:00.000Z","uuid":"u2","message":{"role":"user","content":"And below the sky?"}}
{"type":"assistant","timestamp":"2026-07-20T10:05:04.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Everything else, mostly."}]}}
EOF
    run_exporter

    local f="$PROJECT_DIR/llm-transcripts/jul-20-26.md"
    local ok=no
    if [ -f "$f" ] && grep -q "Everything else, mostly." "$f"; then
        ok=yes
    fi
    check "growth: the new exchange reaches the transcript" "$ok"

    local rewritten=no
    if echo "$EXPORT_OUTPUT" | grep -q "^Created: .*jul-20-26\.md$"; then
        rewritten=yes
    fi
    check "growth: the skip does not fire on a changed conversation" "$rewritten"
}
# }}}

# -- {{{ test_skipped_transcript_still_gets_its_mtime_repaired
# Skipping leaves a file's contents alone, but its timestamp is a projection of
# the session log in exactly the way its name is, and gets enforced on every
# run regardless. Without that, a file whose mtime a checkout or a copy had
# scrambled would keep the wrong date forever - the content check would skip
# past it every time - and mtime is the signal the sibling tools sort the
# corpus by.
#
# The assertion is "back to what the writing path set", deliberately not an
# absolute clock reading: the parser reads the log's UTC fields verbatim for
# both the filename date and the mtime, so the two always agree with each
# other while sitting an offset away from local wall time. That trade is
# recorded at to_date_string() in libs/conversation-parser.lua, and this test
# has no business re-litigating it. Runs last, so the log has settled at the
# growth test's final message.
function test_skipped_transcript_still_gets_its_mtime_repaired() {
    local f="$PROJECT_DIR/llm-transcripts/jul-20-26.md"
    local want_sum want_mtime
    want_sum=$(md5sum < "$f")
    want_mtime=$(stat -c %Y "$f")

    touch -d "2001-01-01 00:00:00" "$f"
    run_exporter

    local got_mtime after_sum
    got_mtime=$(stat -c %Y "$f")
    after_sum=$(md5sum < "$f")

    check "skip: a scrambled mtime is re-derived from the session log" \
        "$([ "$want_mtime" = "$got_mtime" ] && echo yes || echo no)"
    check "skip: repairing the mtime leaves the contents untouched" \
        "$([ "$want_sum" = "$after_sum" ] && echo yes || echo no)"
}
# }}}

echo "transcript export guard test suite"
build_fixtures
run_exporter
test_complete_exchange_exports_reply
test_husk_writes_nothing_and_retires_claim
test_race_shape_surrenders_loudly_but_exports

# The idempotency pair below needs more than one pass, so each runs the
# exporter itself rather than sharing the single run above. Order matters:
# the no-op check must see the corpus before the growth check extends it.
test_rerun_of_unchanged_conversation_touches_nothing
test_grown_conversation_is_still_rewritten
test_skipped_transcript_still_gets_its_mtime_repaired
rm -rf "$SCRATCH"
echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ] || exit 1
exit 0
