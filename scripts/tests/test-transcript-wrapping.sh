#!/bin/bash
# test-transcript-wrapping.sh - proves the transcript formatter wraps prose at
# 80 columns without corrupting structure, and without repositioning anything.
#
# In general terms: feeds the exporter one hand-made session whose reply
# contains every troublesome shape - a paragraph opening with **bold**, a long
# bullet item, a fenced code block, a table row, and plain prose - plus a long
# user question, then checks that prose wrapped, that lists got hanging
# indents, that code and tables came through untouched, and that nothing
# acquired a left margin it was not written with. Uses the fixture seam from
# issue 020; nothing under ~/.claude is read or written.
#
# ON THE LEFT MARGIN. For a short while the assistant's prose was padded on the
# left so its right edge landed at column 80, to put the two speakers on
# opposite sides of the page. That was withdrawn: in markdown four or more
# leading spaces means *code block*, so every renderer showed the padded prose
# as a monospace box. The deeper objection is that alignment is a property of a
# VIEW and the transcript is DATA, and putting one in the other is the mistake
# rather than the rendering being unlucky. These assertions therefore check
# that nothing is padded - the absence is the feature.

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
    local offenders
    offenders=$(echo "$TRANSCRIPT" | awk 'length > 80' | grep -cv "this_is_code\|column one")
    check "only code and table lines exceed 80 (other offenders: $offenders)" \
        "$([ "$offenders" = 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_nothing_is_padded
function test_nothing_is_padded() {
    # No line may begin with four or more spaces unless it was authored that
    # way, because that is the threshold at which markdown starts reading prose
    # as a code block. The fixture contains no indented code, so any such line
    # is padding that should not be there.
    local padded
    padded=$(echo "$TRANSCRIPT" | grep -c "^    ")
    check "no line acquired a left margin (padded lines: $padded)" \
        "$([ "$padded" = 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_both_speakers_start_at_the_margin
function test_both_speakers_start_at_the_margin() {
    # The user's paragraph and bullet, and the assistant's, all begin at
    # column zero. Who is speaking is said by the heading above them.
    local ok=no
    if echo "$TRANSCRIPT" | grep -q "^Show me every shape" \
        && echo "$TRANSCRIPT" | grep -q "^- A user bullet" \
        && echo "$TRANSCRIPT" | grep -q "^\*\*A bold opener paragraph\*\*" \
        && echo "$TRANSCRIPT" | grep -q "^- \*\*First bullet\*\*"; then
        ok=yes
    fi
    check "both speakers' prose starts at the left margin" "$ok"
}
# }}}

# -- {{{ test_bold_opener_wraps
function test_bold_opener_wraps() {
    # Wrapping is deterministic for a fixed sentence, so the continuation
    # line's first words are a stable assertion target.
    local ok=no
    if echo "$TRANSCRIPT" | grep -q "^because it keeps"; then
        ok=yes
    fi
    check "bold-opening paragraph wrapped into plain continuations" "$ok"
}
# }}}

# -- {{{ test_hanging_indents_survive
function test_hanging_indents_survive() {
    # A wrapped bullet's continuation sits under the item's text at exactly two
    # spaces, the width of "- ". This works for both speakers again now that
    # nothing is repositioned; while the assistant's prose was being padded it
    # could only be true of the user's.
    local user_ok=no assistant_ok=no
    echo "$TRANSCRIPT" | grep -q "^  [^ ].*userhangingmarker\|^  userhangingmarker" \
        && user_ok=yes
    echo "$TRANSCRIPT" | grep -q "^  [^ ].*hangingindentmarker\|^  hangingindentmarker" \
        && assistant_ok=yes
    check "user bullet keeps its two-space hanging indent" "$user_ok"
    check "assistant bullet keeps its two-space hanging indent" "$assistant_ok"
}
# }}}

# -- {{{ test_code_and_table_untouched
function test_code_and_table_untouched() {
    # Structure whose meaning is its column position passes through verbatim.
    local code_lines table_lines
    code_lines=$(echo "$TRANSCRIPT" | grep -c "^this_is_code_with_a_deliberately_long_line")
    table_lines=$(echo "$TRANSCRIPT" | grep -c "^| column one | column two |")
    check "code block line intact and unwrapped (found: $code_lines)" \
        "$([ "$code_lines" = 1 ] && echo yes || echo no)"
    check "table row intact and unwrapped (found: $table_lines)" \
        "$([ "$table_lines" = 1 ] && echo yes || echo no)"
}
# }}}

echo "transcript wrapping test suite"
build_and_export
test_only_structure_exceeds_width
test_nothing_is_padded
test_both_speakers_start_at_the_margin
test_bold_opener_wraps
test_hanging_indents_survive
test_code_and_table_untouched
rm -rf "$SCRATCH"
echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ] || exit 1
exit 0
