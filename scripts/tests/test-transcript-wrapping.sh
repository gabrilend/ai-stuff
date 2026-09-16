#!/bin/bash
# test-transcript-wrapping.sh - proves the transcript formatter wraps prose to
# 80 columns, pushes the assistant's prose to the right edge while leaving the
# user's against the left, and corrupts no structure doing either.
#
# In general terms: feeds the exporter one hand-made session whose reply
# contains every troublesome shape - a paragraph opening with **bold**, a long
# bullet item, a fenced code block, a table row, and plain prose - plus a long
# user question, then checks that prose wrapped, that the two speakers ended up
# on opposite sides of the page, and that code and tables came through
# untouched. Uses the fixture seam from issue 020; nothing under ~/.claude is
# read or written.
#
# ON THE HANGING INDENT. An earlier version of this file asserted that a
# wrapped bullet's continuation began with exactly two spaces, so it sat under
# the item's text. That is still true of the user's prose. It cannot be true of
# the assistant's any more: right-justification (issue 027) positions every
# line by its right edge, so a ragged-left edge and a fixed hanging indent are
# two different pictures and only one can be on the page. The assertion moved
# to the user side rather than being deleted, because the behaviour it guards
# still exists there.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

EXPORTER="$DIR/scripts/backup-conversations"
SCRATCH="${TMPDIR:-/tmp}/transcript-wrap-test-$$"

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

# -- {{{ build_and_export
function build_and_export() {
    local project_dir="$SCRATCH/fake-project"
    local sessions_root="$SCRATCH/sessions"
    local dashed
    dashed="-$(echo "$project_dir" | sed 's|^/||' | tr '/' '-')"
    mkdir -p "$project_dir" "$sessions_root/$dashed"

    cat > "$sessions_root/$dashed/44444444-4444-4444-4444-444444444444.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-07-22T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Show me every shape, and let this question itself run well past the eighty character limit so that the wrapping of a user turn can be observed too.\n\n- A user bullet whose tail also runs past the eighty character limit and therefore needs a userhangingmarker to stay readable as one item."}}
{"type":"assistant","timestamp":"2026-07-22T10:00:05.000Z","message":{"role":"assistant","model":"claude-test-1","content":[{"type":"text","text":"**A bold opener paragraph** that runs well past the eighty character limit because it keeps adding words about nothing in particular at considerable length.\n\n- **First bullet** with a very long tail that also runs past the eighty character limit and therefore needs a hangingindentmarker to stay readable as one item.\n\n```\nthis_is_code_with_a_deliberately_long_line_that_must_never_be_wrapped_by_the_formatter_no_matter_how_long_it_grows\n```\n\n| column one | column two | a table row stretching far beyond eighty characters that must stay intact |\n\nA plain closing paragraph that similarly exceeds the eighty character limit and therefore must be wrapped into several lines of tidy prose."}]}}
EOF

    TRANSCRIPT=$(CLAUDE_SESSIONS_ROOT="$sessions_root" "$EXPORTER" "$project_dir" > /dev/null && cat "$project_dir/llm-transcripts/jul-22-26.md")
}
# }}}

# -- {{{ test_only_structure_exceeds_width
function test_only_structure_exceeds_width() {
    # The only lines allowed past 80 are the code line and the table row.
    # Padding must never push anything over the edge it is measuring from.
    local offenders
    offenders=$(echo "$TRANSCRIPT" | awk 'length > 80' | grep -cv "this_is_code\|column one")
    check "only code and table lines exceed 80 (other offenders: $offenders)" \
        "$([ "$offenders" = 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_assistant_prose_is_right_aligned
function test_assistant_prose_is_right_aligned() {
    # The bold opener is the assistant's; it must carry leading padding and
    # end flush with column 80. Checking the right edge is the real assertion -
    # leading spaces alone would also be satisfied by an accidental indent.
    local line width
    line=$(echo "$TRANSCRIPT" | grep '\*\*A bold opener paragraph\*\*' | head -1)
    width=${#line}
    local ok=no
    if [ -n "$line" ] && [ "$width" = 80 ] && [[ "$line" == " "* ]]; then
        ok=yes
    fi
    check "assistant prose pushed to the right edge (width: $width)" "$ok"
}
# }}}

# -- {{{ test_user_prose_stays_left
function test_user_prose_stays_left() {
    # The user's own words must not move. Both the paragraph and the bullet
    # start at column zero.
    local ok=no
    if echo "$TRANSCRIPT" | grep -q "^Show me every shape" \
        && echo "$TRANSCRIPT" | grep -q "^- A user bullet"; then
        ok=yes
    fi
    check "user prose stays against the left margin" "$ok"
}
# }}}

# -- {{{ test_user_bullet_hanging_indent
function test_user_bullet_hanging_indent() {
    # On the user's side, where nothing is repositioned, a wrapped bullet's
    # continuation still sits under the item's text at exactly two spaces.
    local ok=no
    if echo "$TRANSCRIPT" | grep -q "^  [^ ].*userhangingmarker\|^  userhangingmarker"; then
        ok=yes
    fi
    check "user bullet keeps its two-space hanging indent" "$ok"
}
# }}}

# -- {{{ test_assistant_bullet_marker_survives
function test_assistant_bullet_marker_survives() {
    # Right-justification repositions the line but must not eat the marker
    # that makes it a list item in the first place.
    local ok=no
    if echo "$TRANSCRIPT" | grep -q "^ *- \*\*First bullet\*\*"; then
        ok=yes
    fi
    check "assistant bullet keeps its list marker after being moved" "$ok"
}
# }}}

# -- {{{ test_code_and_table_untouched
function test_code_and_table_untouched() {
    # Structure whose meaning is its column position is never padded.
    local code_lines table_lines
    code_lines=$(echo "$TRANSCRIPT" | grep -c "^this_is_code_with_a_deliberately_long_line")
    table_lines=$(echo "$TRANSCRIPT" | grep -c "^| column one | column two |")
    check "code block line intact, unwrapped and unmoved (found: $code_lines)" \
        "$([ "$code_lines" = 1 ] && echo yes || echo no)"
    check "table row intact, unwrapped and unmoved (found: $table_lines)" \
        "$([ "$table_lines" = 1 ] && echo yes || echo no)"
}
# }}}

echo "transcript wrapping test suite"
build_and_export
test_only_structure_exceeds_width
test_assistant_prose_is_right_aligned
test_user_prose_stays_left
test_user_bullet_hanging_indent
test_assistant_bullet_marker_survives
test_code_and_table_untouched
rm -rf "$SCRATCH"
echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ] || exit 1
exit 0
