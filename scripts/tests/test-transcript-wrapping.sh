#!/bin/bash
# test-transcript-wrapping.sh - proves the transcript formatter wraps prose at
# 80 columns without corrupting structure.
#
# In general terms: feeds the exporter one hand-made session whose reply
# contains every troublesome shape - a paragraph opening with **bold**, a long
# bullet item, a fenced code block, a table row, and plain prose - then checks
# that prose wrapped, lists got hanging indents, and code and tables came
# through untouched. Uses the fixture seam from issue 020; nothing under
# ~/.claude is read or written.

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
{"type":"user","timestamp":"2026-07-22T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Show me every shape."}}
{"type":"assistant","timestamp":"2026-07-22T10:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"**A bold opener paragraph** that runs well past the eighty character limit because it keeps adding words about nothing in particular at considerable length.\n\n- **First bullet** with a very long tail that also runs past the eighty character limit and therefore needs a hangingindentmarker to stay readable as one item.\n\n```\nthis_is_code_with_a_deliberately_long_line_that_must_never_be_wrapped_by_the_formatter_no_matter_how_long_it_grows\n```\n\n| column one | column two | a table row stretching far beyond eighty characters that must stay intact |\n\nA plain closing paragraph that similarly exceeds the eighty character limit and therefore must be wrapped into several lines of tidy prose."}]}}
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

# -- {{{ test_bold_opener_wraps
function test_bold_opener_wraps() {
    # Wrapping is deterministic for a fixed sentence, so the continuation
    # line's first words are a stable assertion target.
    local ok=no
    if echo "$TRANSCRIPT" | grep -q "^\*\*A bold opener paragraph\*\*" \
        && echo "$TRANSCRIPT" | grep -q "^because it keeps"; then
        ok=yes
    fi
    check "bold-opening paragraph wrapped into plain continuations" "$ok"
}
# }}}

# -- {{{ test_bullet_hanging_indent
function test_bullet_hanging_indent() {
    # The bullet's continuation must start with exactly two spaces (the width
    # of "- ") so it reads as part of the same item.
    local ok=no
    if echo "$TRANSCRIPT" | grep -q "^- \*\*First bullet\*\*" \
        && echo "$TRANSCRIPT" | grep -q "^  [^ ].*hangingindentmarker\|^  hangingindentmarker"; then
        ok=yes
    fi
    check "bullet wraps with a two-space hanging indent" "$ok"
}
# }}}

# -- {{{ test_code_and_table_untouched
function test_code_and_table_untouched() {
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
test_bold_opener_wraps
test_bullet_hanging_indent
test_code_and_table_untouched
rm -rf "$SCRATCH"
echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ] || exit 1
exit 0
