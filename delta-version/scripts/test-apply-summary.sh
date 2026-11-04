#!/bin/bash
# test-apply-summary.sh - proves apply-summary.sh adds a conversation's entry
# to its folder's table of contents and a summary block to the transcript,
# both replaced rather than doubled on a rerun, and renames the transcript
# only when the configuration turns renames on and the shared rulebook
# accepts the new name.
#
# In general terms: a pretend transcript folder in a small git repository in
# a RAM folder, records written the way summarize-transcript.lua writes them,
# and the real shared rulebook (scripts/libs/transcript-discovery.sh). For
# the rename path a copy of the rulebook that accepts slug names stands in
# for the change the scripts project has yet to make. Exercises issue 056c.
#
# Usage: test-apply-summary.sh [--dir MONOREPO]   (KEEP=1 keeps the folder)

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/apply-summary.sh"
SCRATCH="$DIR/delta-version/tmp/shared-memory/apply-summary-test"
SEPARATOR="--------------------------------------------------------------------------------"

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

# -- {{{ same / has_line / lacks_line
function same() { if [ "$1" = "$2" ]; then echo yes; else echo no; fi; }
function has_line() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
function lacks_line() { if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi; }
# }}}

# -- {{{ g
function g() { git -c user.name=Tester -c user.email=tester@example.com "$@"; }
# }}}

# -- {{{ write_transcript
function write_transcript() {
    # FILE, conversation id.
    {
        echo "# Conversation Summary: $2"
        echo ""
        echo "Generated on: 2026-11-02 12:00:00"
        echo ""
        echo "$SEPARATOR"
        echo ""
        echo "### User Request 1"
        echo ""
        echo "Build the parser."
        echo ""
        echo "$SEPARATOR"
        echo ""
        echo "### Assistant Response 1"
        echo ""
        echo "Built."
        echo ""
        echo "$SEPARATOR"
    } > "$1"
}
# }}}

# -- {{{ write_record
function write_record() {
    # FILE, conversation id, title, slug, blurb.
    printf 'transcript-summary v1\nconversation: %s\nsource: x\ntitle: %s\nslug: %s\nslices: 1\nlevels: 0\n\n## Blurb\n%s\n\n## Summary\nThe summary.\n' \
        "$2" "$3" "$4" "$5" > "$1"
}
# }}}

# -- {{{ write_config
function write_config() {
    # inline_blurb and rename values.
    printf '[apply]\ntable_of_contents=table-of-contents.md\ninline_blurb=%s\nrename=%s\n' "$1" "$2" > "$CONFIG"
}
# }}}

# -- {{{ run
function run() {
    OUT=$(DIR="$DIR" bash "$TOOL" "$@" --config "$CONFIG" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH/repo/project/llm-transcripts" "$SCRATCH/accepting/libs"
    SCRATCH=$(realpath "$SCRATCH")
    REPO="$SCRATCH/repo"
    FOLDER="$REPO/project/llm-transcripts"
    CONFIG="$SCRATCH/summary.conf"
    write_transcript "$FOLDER/dec-10-25.md" "conv-a"
    write_transcript "$FOLDER/dec-11-25.md" "conv-b"
    printf '# Conversation Summary: conv-c\n\nSee [the earlier one](dec-10-25.md).\n' > "$FOLDER/dec-12-25.md"
    printf 'Notes mention dec-10-25.md by name.\n' > "$REPO/notes.md"
    g init -q "$REPO"
    g -C "$REPO" add -A
    g -C "$REPO" commit -q -m "transcripts"
    write_record "$SCRATCH/a.record" conv-a "Built the parser." built-the-parser "We built the parser and its tests."
    write_record "$SCRATCH/b.record" conv-b "Fixed the loader." fixed-the-loader "We fixed the loader."
    # The rulebook as the scripts project would widen it: slug names count.
    cp "$DIR/scripts/libs/transcript-discovery.sh" "$SCRATCH/accepting/libs/"
    cat >> "$SCRATCH/accepting/libs/transcript-discovery.sh" << 'EOF'
transcript_is_new_format() {
   [[ "$(basename "$1")" =~ ^([a-z0-9]+-)*[a-z]{3}-[0-9]{1,2}-[0-9]{2}(-through-[a-z]{3}-[0-9]{1,2}-[0-9]{2})?(_agent-[0-9]+)?\.md$ ]]
}
EOF
}
# }}}

# -- {{{ test_defaults
function test_defaults() {
    write_config on off
    run "$FOLDER/dec-10-25.md" "$SCRATCH/a.record"
    local toc="$FOLDER/table-of-contents.md"
    check "a summary applies (exit 0)" "$(same "$CODE" 0)"
    check "the table of contents is created" "$(same "$(head -1 "$toc")" "# Table of Contents")"
    check "its entry links the title to the transcript" "$(has_line "$(cat "$toc")" "## [Built the parser.](dec-10-25.md)")"
    check "... with the paragraph" "$(has_line "$(cat "$toc")" "We built the parser and its tests.")"
    check "the header line stays first" "$(same "$(head -1 "$FOLDER/dec-10-25.md")" "# Conversation Summary: conv-a")"
    check "the summary block follows it" "$(same "$(sed -n 2,4p "$FOLDER/dec-10-25.md" | tr '\n' '|')" "<!-- transcript-summary v1 -->|## Session Summary|We built the parser and its tests.|")"
    check "the conversation itself is untouched" "$(has_line "$(cat "$FOLDER/dec-10-25.md")" "Build the parser.")"
    check "with renames off the name is kept" "$([ -f "$FOLDER/dec-10-25.md" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_rerun
function test_rerun() {
    write_record "$SCRATCH/a2.record" conv-a "Built the parser again." built-the-parser-again "A newer paragraph."
    run "$FOLDER/dec-10-25.md" "$SCRATCH/a2.record"
    run "$FOLDER/dec-11-25.md" "$SCRATCH/b.record"
    run "$FOLDER/dec-10-25.md" "$SCRATCH/a2.record"
    local toc
    toc=$(cat "$FOLDER/table-of-contents.md")
    check "a rerun leaves one entry per conversation" \
        "$(same "$(grep -c '^<!-- transcript-summary: ' <<< "$toc")" 2)"
    check "... with the newer title and paragraph" "$(has_line "$toc" "## [Built the parser again.](dec-10-25.md)")"
    check "... and not the older ones" "$(lacks_line "$toc" "We built the parser and its tests.")"
    check "the other conversation's entry survives" "$(has_line "$toc" "## [Fixed the loader.](dec-11-25.md)")"
    check "a rerun leaves one summary block in the transcript" \
        "$(same "$(grep -c '^<!-- transcript-summary v1 -->$' "$FOLDER/dec-10-25.md")" 1)"
    check "... holding the newer paragraph" "$(same "$(sed -n 4p "$FOLDER/dec-10-25.md")" "A newer paragraph.")"
}
# }}}

# -- {{{ test_inline_off_and_dry_run
function test_inline_off_and_dry_run() {
    local before
    write_config off off
    write_transcript "$SCRATCH/plain.md" conv-p
    write_record "$SCRATCH/p.record" conv-p "Plain." plain "Plain paragraph."
    cp "$SCRATCH/plain.md" "$FOLDER/jan-1-26.md"
    run "$FOLDER/jan-1-26.md" "$SCRATCH/p.record"
    check "with inline_blurb off the transcript is untouched" "$(same "$(md5sum < "$FOLDER/jan-1-26.md")" "$(md5sum < "$SCRATCH/plain.md")")"
    check "... and the table of contents still gets the entry" "$(has_line "$(cat "$FOLDER/table-of-contents.md")" "## [Plain.](jan-1-26.md)")"
    write_config on on
    before=$(cd "$FOLDER" && md5sum ./* | sort)
    run "$FOLDER/dec-11-25.md" "$SCRATCH/b.record" --dry-run
    check "a dry run says what it would do" "$(has_line "$OUT" "would update the entry in")"
    check "... and changes nothing" "$(same "$(cd "$FOLDER" && md5sum ./* | sort)" "$before")"
}
# }}}

# -- {{{ test_rename_held_back
function test_rename_held_back() {
    write_config on on
    run "$FOLDER/dec-11-25.md" "$SCRATCH/b.record"
    check "with renames on but the rulebook unchanged, the run still succeeds" "$(same "$CODE" 0)"
    check "... the rename is held back" "$(has_line "$OUT" "rename held back")"
    check "... and the file keeps its name" "$([ -f "$FOLDER/dec-11-25.md" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_rename
function test_rename() {
    write_config on on
    OUT=$(SCRIPTS_DIR="$SCRATCH/accepting" DIR="$DIR" bash "$TOOL" "$FOLDER/dec-10-25.md" "$SCRATCH/a2.record" --config "$CONFIG" 2>&1)
    CODE=$?
    local new="$FOLDER/built-the-parser-again-dec-10-25.md"
    check "with renames on and an accepting rulebook, the transcript is renamed" \
        "$([ -f "$new" ] && [ ! -e "$FOLDER/dec-10-25.md" ] && echo yes || echo no)"
    check "... with git mv, so git sees a rename" \
        "$(g -C "$REPO" status --short | grep -q '^R. project/llm-transcripts/dec-10-25.md -> project/llm-transcripts/built-the-parser-again-dec-10-25.md' && echo yes || echo no)"
    check "the table of contents links the new name" \
        "$(has_line "$(cat "$FOLDER/table-of-contents.md")" "## [Built the parser again.](built-the-parser-again-dec-10-25.md)")"
    check "a link from another transcript in the folder follows it" \
        "$(has_line "$(cat "$FOLDER/dec-12-25.md")" "(built-the-parser-again-dec-10-25.md)")"
    check "a mention outside the folder is listed, not edited" \
        "$(has_line "$OUT" "still mentions the old name (not edited): notes.md")"
    check "... and left as it was" "$(has_line "$(cat "$REPO/notes.md")" "dec-10-25.md by name")"
    OUT=$(SCRIPTS_DIR="$SCRATCH/accepting" DIR="$DIR" bash "$TOOL" "$new" "$SCRATCH/a2.record" --config "$CONFIG" 2>&1)
    check "a renamed transcript is not renamed twice" "$([ -f "$new" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_refusals
function test_refusals() {
    write_config on off
    run "$FOLDER/dec-11-25.md" "$SCRATCH/a2.record"
    check "a record for another conversation is refused (exit 2)" "$(same "$CODE" 2)"
    check "... and says which" "$(has_line "$OUT" "the record is for conversation 'conv-a', the transcript is 'conv-b'")"
    run "$REPO/notes.md" "$SCRATCH/b.record"
    check "a file with no conversation header is refused" "$(same "$CODE" 2)"
    printf 'not a record\n' > "$SCRATCH/bad.record"
    run "$FOLDER/dec-11-25.md" "$SCRATCH/bad.record"
    check "a file that is not a record is refused" "$(same "$CODE" 2)"
    write_record "$SCRATCH/slug.record" conv-b "Title." "Bad Slug" "Paragraph."
    run "$FOLDER/dec-11-25.md" "$SCRATCH/slug.record"
    check "a slug that is not lowercase words is refused" "$(same "$CODE" 2)"
    run "$FOLDER/dec-11-25.md"
    check "a missing record argument is a usage error" "$(same "$CODE" 2)"
}
# }}}

setup
echo "apply-summary"
test_defaults
test_rerun
test_inline_off_and_dry_run
test_rename_held_back
test_rename
test_refusals
[ "${KEEP:-}" ] || rm -rf "${SCRATCH:?}"
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
