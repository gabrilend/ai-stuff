#!/bin/bash
# test-transcript-summary-block.sh - the exporter lives with delta-version's
# summary applier (delta-version issue 056c).
#
# The applier writes a summary block under a transcript's header line and,
# when configured, renames the file to "<slug>-<date>.md". Before this, the
# exporter undid both: the block made an unchanged conversation look changed,
# so the file was rewritten without it, and the slug name was re-derived back
# to "<date>.md". This checks the three rules that stop that:
#   - the shared rulebook accepts "<words>-<date>.md" names;
#   - the content fingerprint steps over the block (and only a whole block);
#   - a claim's words survive a re-export, with only the date re-derived.
#
# The exporter is pointed at hand-made session logs via CLAUDE_SESSIONS_ROOT;
# nothing under ~/.claude is touched. Usage:
#   SCRIPTS_DIR=<scripts> bash test-transcript-summary-block.sh [--dir <monorepo>]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

EXPORTER="$DIR/scripts/backup-conversations"
mkdir -p /tmp/claude-1000
SCRATCH="$(mktemp -d /tmp/claude-1000/summary-block.XXXXXX)"
source "$DIR/scripts/libs/transcript-discovery.sh"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    local label="$1" got="$2" want="$3"
    if [ "$got" = "$want" ]; then
        echo "  ok   - $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $label: got [$got] want [$want]"
        FAIL=$((FAIL + 1))
    fi
}
# }}}

# -- {{{ add_block
# Writes a summary block the way apply-summary.sh does: under line 1,
# replacing any block already there.
function add_block() {
    local file="$1" blurb="$2" tmp="$1.tmp"
    awk -v marker="$TRANSCRIPT_SUMMARY_MARKER" -v sep="$TRANSCRIPT_SUMMARY_END" -v blurb="$blurb" '
        NR == 1 { print; print marker; print "## Session Summary"; print blurb; print ""; print sep; next }
        NR == 2 && $0 == marker { skipping = 1; next }
        skipping { if ($0 == sep) skipping = 0; next }
        { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}
# }}}

# -- {{{ is_new
function is_new() { transcript_is_new_format "$1" && echo yes || echo no; }
# }}}

echo "transcript summary block test suite"

echo "the rulebook's names"
check "a bare date" "$(is_new jul-20-26.md)" "yes"
check "a slug before the date" "$(is_new talk-about-the-sky-jul-20-26.md)" "yes"
check "a slug before a span with a collision mark" "$(is_new sky-jul-20-26-through-jul-21-26_agent-2.md)" "yes"
check "digits in the slug" "$(is_new rgpl-v2-jul-20-26.md)" "yes"
check "capitals are not a slug" "$(is_new Sky-jul-20-26.md)" "no"
check "a doubled dash is not a slug" "$(is_new sky--jul-20-26.md)" "no"
check "a name with no date" "$(is_new talk-about-the-sky.md)" "no"
check "not markdown" "$(is_new sky-jul-20-26.txt)" "no"
check "words of a slug name" "$(transcript_name_words sky-talk-jul-20-26_agent-1.md)" "sky-talk"
check "words of a slug before a span" "$(transcript_name_words sky-jul-20-26-through-jul-21-26.md)" "sky"
check "a bare span has no words" "$(transcript_name_words jul-20-26-through-jul-21-26.md)" ""
check "a name with no date has no words" "$(transcript_name_words some-old-name.md)" ""

echo "the fingerprint"
PLAIN="$SCRATCH/plain.md"
printf '# Conversation Summary: abc\n\nGenerated on: 2026-07-20 10:00:00\n\n%s\n\nhello\n' "$TRANSCRIPT_SUMMARY_END" > "$PLAIN"
cp "$PLAIN" "$SCRATCH/one.md"; add_block "$SCRATCH/one.md" "A talk about the sky."
cp "$PLAIN" "$SCRATCH/two.md"; add_block "$SCRATCH/two.md" "Another summary entirely."
check "a summary block does not change the fingerprint" \
    "$(transcript_body_fingerprint "$SCRATCH/one.md")" "$(transcript_body_fingerprint "$PLAIN")"
check "nor does replacing it" \
    "$(transcript_body_fingerprint "$SCRATCH/two.md")" "$(transcript_body_fingerprint "$SCRATCH/one.md")"
printf '# Conversation Summary: abc\n%s\n## Session Summary\nnever closed\n' "$TRANSCRIPT_SUMMARY_MARKER" > "$SCRATCH/open.md"
printf '# Conversation Summary: abc\n' > "$SCRATCH/header-only.md"
check "a block with no end counts as text" \
    "$(transcript_same_content "$SCRATCH/open.md" "$SCRATCH/header-only.md" && echo same || echo differs)" "differs"
printf '# Conversation Summary: abc\n\n%s\n## Session Summary\nx\n\n%s\nhello\n' "$TRANSCRIPT_SUMMARY_MARKER" "$TRANSCRIPT_SUMMARY_END" > "$SCRATCH/late.md"
check "a marker anywhere but line 2 counts as text" \
    "$(transcript_same_content "$SCRATCH/late.md" "$PLAIN" && echo same || echo differs)" "differs"
printf 'changed\n' >> "$SCRATCH/one.md"
check "a real change under the block still counts" \
    "$(transcript_same_content "$SCRATCH/one.md" "$PLAIN" && echo same || echo differs)" "differs"

echo "the exporter"
PROJECT_DIR="$SCRATCH/fake-project"
SESSIONS_ROOT="$SCRATCH/sessions"
SESSION_DIR="$SESSIONS_ROOT/$(echo "$PROJECT_DIR" | sed 's|[^a-zA-Z0-9]|-|g')"
TDIR="$PROJECT_DIR/llm-transcripts"
LOG="$SESSION_DIR/11111111-1111-1111-1111-111111111111.jsonl"
mkdir -p "$TDIR" "$SESSION_DIR"
cat > "$LOG" <<'EOF'
{"type":"user","timestamp":"2026-07-20T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Hello there, what is up?"}}
{"type":"assistant","timestamp":"2026-07-20T10:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"The sky, mostly."}]}}
EOF
run() { CLAUDE_SESSIONS_ROOT="$SESSIONS_ROOT" "$EXPORTER" "$PROJECT_DIR" 2>&1; }
listing() { ls "$TDIR" | tr '\n' ' '; }

run > /dev/null
check "first export takes the date name" "$(listing)" "jul-20-26.md "

# What apply-summary.sh does: a block, then the slug rename.
add_block "$TDIR/jul-20-26.md" "A short talk about the sky."
mv "$TDIR/jul-20-26.md" "$TDIR/talk-about-the-sky-jul-20-26.md"
before=$(md5sum < "$TDIR/talk-about-the-sky-jul-20-26.md")
out=$(run)
check "re-export keeps the slug name" "$(listing)" "talk-about-the-sky-jul-20-26.md "
check "re-export reports the summarised file as unchanged" \
    "$(printf '%s\n' "$out" | grep -c '^Unchanged: ')" "1"
check "and leaves it byte for byte, block included" \
    "$(md5sum < "$TDIR/talk-about-the-sky-jul-20-26.md")" "$before"

# The conversation grows on the same day: rewritten in place under its slug.
cat >> "$LOG" <<'EOF'
{"type":"user","timestamp":"2026-07-20T11:00:00.000Z","uuid":"u2","message":{"role":"user","content":"And below it?"}}
{"type":"assistant","timestamp":"2026-07-20T11:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"The ground."}]}}
EOF
run > /dev/null
check "a grown conversation keeps its slug" "$(listing)" "talk-about-the-sky-jul-20-26.md "
check "and carries the new exchange" "$(grep -c 'The ground.' "$TDIR/talk-about-the-sky-jul-20-26.md")" "1"

# It runs into the next day: the date part is re-derived, the slug stays.
cat >> "$LOG" <<'EOF'
{"type":"user","timestamp":"2026-07-21T09:00:00.000Z","uuid":"u3","message":{"role":"user","content":"Good morning."}}
{"type":"assistant","timestamp":"2026-07-21T09:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Morning."}]}}
EOF
run > /dev/null
check "a longer span renames the date part only" "$(listing)" "talk-about-the-sky-jul-20-26-through-jul-21-26.md "

rm -rf "$SCRATCH"
echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
