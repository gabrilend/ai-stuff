#!/bin/bash
# test-transcript-patches.sh - proves that deliberate edits to transcripts
# survive re-export, that a patch which no longer fits stops the export instead
# of being skipped, and that the unedited original can always be remade.
#
# In general terms: builds a throwaway repository with a project, a fake copy
# of Claude's session store, and per-conversation patch folders, then checks:
#
#   - the literal-text library counts and replaces exactly;
#   - a text patch (find / replace / about) replaces every occurrence, byte for
#     byte (a final newline in find is part of the match), recognises text
#     that already carries it, and turns stale - an error, file untouched -
#     when neither its find nor its replace text is there;
#   - a replacement that contains its own find text can be applied twice
#     without growing, and a deletion counts as applied once its text is gone;
#   - a patch folder belongs to one conversation and leaves the others alone,
#     and a malformed folder is an error, not a silent omission;
#   - an id patch translates quoted commit ids, twice is the same as once,
#     and one whose ids are neither old nor new in the text is stale;
#   - the exporter applies patches on every export, reports an unchanged
#     patched conversation as unchanged, and refuses to overwrite a patched
#     transcript when a patch goes stale;
#   - "original" remakes the unpatched rendering and never writes over the
#     transcript; "verify" re-renders, re-patches and matches;
#   - "new" records find and replace byte for byte, numbered, and refuses a
#     find that does not occur;
#   - "translate-ids" writes an id patch per conversation that quotes old ids,
#     skips excluded conversations, reuses its folder on a rerun, and checks
#     raw + patches against each transcript.
#
# Nothing under ~/.claude is touched: everything points at the fixtures
# through CLAUDE_SESSIONS_ROOT and the TRANSCRIPT_PATCHES_* overrides.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/scripts/transcript-patches"
EXPORTER="$DIR/scripts/backup-conversations"
EXACT="$DIR/scripts/libs/exact-text.lua"
SCRATCH="${TMPDIR:-/tmp}/transcript-patches-test-$$"

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
# "yes" when the command succeeds, "no" otherwise; keeps the checks one line.
function yes_if() {
    if "$@"; then echo yes; else echo no; fi
}
# }}}

# -- {{{ tp
# Run the tool against this checkout.
function tp() {
    luajit "$TOOL" --dir="$DIR/scripts" "$@"
}
# }}}

# -- {{{ transcript_fixture
# A minimal transcript with the header the tools read the conversation id from.
function transcript_fixture() {
    local path="$1" id="$2" body="$3"
    printf '# Conversation Summary: %s\n\nGenerated on: 2026-09-22 10:00:00\n\n%s\n' "$id" "$body" > "$path"
}
# }}}

# -- {{{ text_patch
# Write a text patch folder: text_patch <folder> <find> <replace> [reason]
function text_patch() {
    mkdir -p "$1"
    printf '%s' "$2" > "$1/find"
    printf '%s' "$3" > "$1/replace"
    printf '2026-09-22 %s\n' "${4:-a test edit}" > "$1/about"
}
# }}}

# -- {{{ apply_copy
# Apply a conversation's patches to a copy of a file; prints the exit status.
function apply_copy() {
    local tdir="$1" conv="$2" src="$3" dst="$4"
    cp "$src" "$dst"
    local status=0
    tp apply "$tdir" "$conv" "$dst" > /dev/null 2> "$dst.err" || status=$?
    echo "$status"
}
# }}}

# -- {{{ test_exact_text
function test_exact_text() {
    echo "literal text library"
    local out
    out=$(luajit -e "
        local x = dofile('$EXACT')
        assert(x.count('a.b a.b axb', 'a.b') == 2)
        local r, n = x.replace_exactly('a.b a.b', 'a.b', '50%', 2)
        assert(r == '50% 50%' and n == 2)
        local bad, found = x.replace_exactly('a.b a.b', 'a.b', 'z', 3)
        assert(bad == nil and found == 2)
        print('ok')")
    check "count is literal, replace needs the exact count, % is not special" "$([ "$out" = ok ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_text_patches
function test_text_patches() {
    echo "text patches"
    local tdir="$SCRATCH/plain/llm-transcripts"
    local conv=conv-one
    mkdir -p "$tdir"
    text_patch "$tdir/.patches/$conv/001-fix-name" "Old Name" "New Name"
    transcript_fixture "$SCRATCH/raw.md" "$conv" "Old Name here, and Old Name there."

    apply_copy "$tdir" "$conv" "$SCRATCH/raw.md" "$SCRATCH/work.md" > /dev/null
    check "every occurrence is replaced" "$(yes_if grep -q 'New Name here, and New Name there' "$SCRATCH/work.md")"
    apply_copy "$tdir" "$conv" "$SCRATCH/work.md" "$SCRATCH/again.md" > /dev/null
    check "text that already carries it is left alone" "$(yes_if cmp -s "$SCRATCH/work.md" "$SCRATCH/again.md")"

    transcript_fixture "$SCRATCH/other.md" conv-two "Old Name stays."
    apply_copy "$tdir" conv-two "$SCRATCH/other.md" "$SCRATCH/other-work.md" > /dev/null
    check "a patch for one conversation leaves another alone" "$(yes_if cmp -s "$SCRATCH/other.md" "$SCRATCH/other-work.md")"

    transcript_fixture "$SCRATCH/stale.md" "$conv" "Neither name is here any more."
    local status
    status=$(apply_copy "$tdir" "$conv" "$SCRATCH/stale.md" "$SCRATCH/stale-work.md")
    check "a stale patch is an error" "$([ "$status" -ne 0 ] && echo yes || echo no)"
    check "the error names the patch" "$(yes_if grep -q '001-fix-name is stale' "$SCRATCH/stale-work.md.err")"
    check "a stale patch leaves the file untouched" "$(yes_if cmp -s "$SCRATCH/stale.md" "$SCRATCH/stale-work.md")"

    mkdir -p "$tdir/.patches/$conv/002-broken"
    printf 'x' > "$tdir/.patches/$conv/002-broken/find"
    printf '2026-09-22 no replace file\n' > "$tdir/.patches/$conv/002-broken/about"
    status=$(apply_copy "$tdir" "$conv" "$SCRATCH/raw.md" "$SCRATCH/broken.md")
    check "a malformed patch folder is an error, not an omission" \
        "$([ "$status" -ne 0 ] && grep -q 'must hold either' "$SCRATCH/broken.md.err" && echo yes || echo no)"
    rm -r "$tdir/.patches/$conv/002-broken"

    # Byte for byte: a find with a final newline only matches at a line end.
    local nl=conv-nl
    text_patch "$tdir/.patches/$nl/001-line" $'tail\n' $'TAIL\n'
    transcript_fixture "$SCRATCH/nl.md" "$nl" $'tail\nmid tail here'
    apply_copy "$tdir" "$nl" "$SCRATCH/nl.md" "$SCRATCH/nl-work.md" > /dev/null
    check "a final newline in find is part of the match" \
        "$(yes_if sh -c "grep -q '^TAIL\$' '$SCRATCH/nl-work.md' && grep -q 'mid tail here' '$SCRATCH/nl-work.md'")"

    # A replacement containing its find text must not grow when re-applied.
    local grow=conv-grow
    text_patch "$tdir/.patches/$grow/001-extend" "Section A" "Section A (revised)"
    transcript_fixture "$SCRATCH/grow.md" "$grow" "Section A and Section A."
    apply_copy "$tdir" "$grow" "$SCRATCH/grow.md" "$SCRATCH/grow1.md" > /dev/null
    apply_copy "$tdir" "$grow" "$SCRATCH/grow1.md" "$SCRATCH/grow2.md" > /dev/null
    check "a replacement containing its find applies once, however often it is run" \
        "$(yes_if sh -c "cmp -s '$SCRATCH/grow1.md' '$SCRATCH/grow2.md' && grep -q 'Section A (revised) and Section A (revised)\.' '$SCRATCH/grow1.md'")"

    # A deletion: once its text is gone, it counts as applied.
    local del=conv-del
    text_patch "$tdir/.patches/$del/001-drop" " [noise]" ""
    transcript_fixture "$SCRATCH/del.md" "$del" "keep [noise] this"
    apply_copy "$tdir" "$del" "$SCRATCH/del.md" "$SCRATCH/del1.md" > /dev/null
    status=$(apply_copy "$tdir" "$del" "$SCRATCH/del1.md" "$SCRATCH/del2.md")
    check "a deletion applies, then counts as applied" \
        "$([ "$status" -eq 0 ] && grep -q '^keep this$' "$SCRATCH/del2.md" && echo yes || echo no)"
}
# }}}

# -- {{{ make_repo
# A repository with two commits, and a map from the first to the second.
function make_repo() {
    REPO="$SCRATCH/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
    OLD_ID=$(git -C "$REPO" rev-parse HEAD)
    git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m second
    NEW_ID=$(git -C "$REPO" rev-parse HEAD)
    printf '%s %s\n' "$OLD_ID" "$NEW_ID" > "$REPO/ids.map"
}
# }}}

# -- {{{ test_id_patches
function test_id_patches() {
    echo "id patches"
    local tdir="$REPO/proj/llm-transcripts"
    mkdir -p "$tdir/.patches/conv-x/001-ids"
    cp "$REPO/ids.map" "$tdir/.patches/conv-x/001-ids/ids"
    printf '2026-09-22 ids moved\n' > "$tdir/.patches/conv-x/001-ids/about"
    local f="$tdir/t.md"
    transcript_fixture "$f" conv-x "See commit ${OLD_ID:0:8} for details."
    tp apply "$tdir" conv-x "$f" > /dev/null
    check "a quoted old id becomes the new one, same length" "$(yes_if grep -q "See commit ${NEW_ID:0:8} for details" "$f")"
    cp "$f" "$SCRATCH/translated.md"
    tp apply "$tdir" conv-x "$f" > /dev/null
    check "translating twice changes nothing" "$(yes_if cmp -s "$f" "$SCRATCH/translated.md")"
    check "list reports it as applied" "$(yes_if sh -c "luajit '$TOOL' --dir='$DIR/scripts' list '$f' | grep -q '001-ids .* applied'")"
    transcript_fixture "$SCRATCH/noids.md" conv-x "No commit ids at all."
    local status=0
    tp apply "$tdir" conv-x "$SCRATCH/noids.md" > /dev/null 2>&1 || status=$?
    check "an id patch with neither old nor new ids in the text is stale" "$([ "$status" -ne 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ fixture_session
# A session log for a project: fixture_session <project> <id> <reply text>
function fixture_session() {
    local project="$1" id="$2" reply="$3"
    local folder="$SESSIONS/$(printf '%s' "$project" | sed 's/[^A-Za-z0-9]/-/g')"
    mkdir -p "$folder"
    jq -nc '{"type":"user","timestamp":"2026-09-01T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"Tell me."}}' > "$folder/$id.jsonl"
    jq -nc --arg t "$reply" '{"type":"assistant","timestamp":"2026-09-01T10:00:05.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":$t}]}}' >> "$folder/$id.jsonl"
}
# }}}

# -- {{{ test_exporter
function test_exporter() {
    echo "exporter integration"
    local project="$REPO/exported"
    mkdir -p "$project/llm-transcripts"
    local id="cccccccc-3333-3333-3333-333333333333"
    fixture_session "$project" "$id" "It is called WRONGWORD in the notes."
    text_patch "$project/llm-transcripts/.patches/$id/001-word" "WRONGWORD" "RIGHTWORD" "the word was misheard"
    local run_env=(env CLAUDE_SESSIONS_ROOT="$SESSIONS" SCRIPTS_DIR="$DIR/scripts")

    "${run_env[@]}" "$EXPORTER" --session "$id" "$project" > "$SCRATCH/export1.out" 2>&1
    local file
    file=$(ls "$project"/llm-transcripts/*.md | head -1)
    check "the export carries the patch" "$(yes_if grep -q 'called RIGHTWORD in the notes' "$file")"
    check "the export says which patch it applied" "$(yes_if grep -q 'patched .*001-word' "$SCRATCH/export1.out")"

    "${run_env[@]}" "$EXPORTER" --session "$id" "$project" > "$SCRATCH/export2.out" 2>&1
    check "a patched conversation that has not moved reads as unchanged" "$(yes_if grep -q '^Unchanged:' "$SCRATCH/export2.out")"

    "${run_env[@]}" luajit "$TOOL" --dir="$DIR/scripts" original "$file" "$SCRATCH/original.md" > /dev/null
    check "original remakes the unpatched rendering" "$(yes_if grep -q 'called WRONGWORD in the notes' "$SCRATCH/original.md")"
    local status=0
    "${run_env[@]}" luajit "$TOOL" --dir="$DIR/scripts" original "$file" "$file" > /dev/null 2>&1 || status=$?
    check "original refuses to write over the transcript" "$([ "$status" -ne 0 ] && grep -q RIGHTWORD "$file" && echo yes || echo no)"
    local verified=no
    if "${run_env[@]}" luajit "$TOOL" --dir="$DIR/scripts" verify "$file" > "$SCRATCH/verify.out" 2>&1; then
        verified=yes
    else
        sed 's/^/        /' "$SCRATCH/verify.out"
    fi
    check "verify re-renders, re-patches and matches" "$verified"

    cp "$file" "$SCRATCH/before-stale.md"
    printf 'SOMETHING ELSE' > "$project/llm-transcripts/.patches/$id/001-word/find"
    printf 'ALSO ABSENT' > "$project/llm-transcripts/.patches/$id/001-word/replace"
    status=0
    "${run_env[@]}" "$EXPORTER" --session "$id" "$project" > "$SCRATCH/export3.out" 2>&1 || status=$?
    check "a stale patch fails the export" "$([ "$status" -ne 0 ] && echo yes || echo no)"
    check "a stale patch leaves the patched transcript on disk" "$(yes_if cmp -s "$file" "$SCRATCH/before-stale.md")"
    rm -r "$project/llm-transcripts/.patches/$id/001-word"
}
# }}}

# -- {{{ test_new
function test_new() {
    echo "recording a patch"
    local tdir="$SCRATCH/scaffold/llm-transcripts"
    mkdir -p "$tdir"
    transcript_fixture "$tdir/one.md" conv-new $'line a\n]] tricky ]=] text\nline c'
    printf '\n]] tricky ]=] text' > "$SCRATCH/find.txt"
    printf '\n]] fixed ]=] text' > "$SCRATCH/replace.txt"
    tp new --for conv-new --name tricky-line --reason "Fix the tricky line" \
        --find "$SCRATCH/find.txt" --replace "$SCRATCH/replace.txt" "$tdir" > "$SCRATCH/new.out"
    local made="$tdir/.patches/conv-new/001-tricky-line"
    check "new writes a numbered folder" "$([ -d "$made" ] && echo yes || echo no)"
    check "find and replace are copied byte for byte" \
        "$(yes_if sh -c "cmp -s '$SCRATCH/find.txt' '$made/find' && cmp -s '$SCRATCH/replace.txt' '$made/replace'")"
    tp apply "$tdir" conv-new "$tdir/one.md" > /dev/null
    check "the recorded patch applies (leading newline, brackets)" "$(yes_if grep -q '^\]\] fixed \]=\] text$' "$tdir/one.md")"
    printf 'not in the transcript' > "$SCRATCH/absent.txt"
    local status=0
    tp new --for conv-new --name nope --reason "x" --find "$SCRATCH/absent.txt" --replace "$SCRATCH/replace.txt" "$tdir" > /dev/null 2>&1 || status=$?
    check "new refuses a find that does not occur" "$([ "$status" -ne 0 ] && [ ! -d "$tdir/.patches/conv-new/002-nope" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_translate_ids
function test_translate_ids() {
    echo "id-patch generator"
    local project="$REPO/gen"
    mkdir -p "$project/llm-transcripts"
    local quoting="dddddddd-4444-4444-4444-444444444444"
    local plain="eeeeeeee-5555-5555-5555-555555555555"
    local skipped="ffffffff-6666-6666-6666-666666666666"
    fixture_session "$project" "$quoting" "The fix landed in ${OLD_ID:0:9}."
    fixture_session "$project" "$plain" "No ids here."
    fixture_session "$project" "$skipped" "This one quotes ${OLD_ID:0:9} on purpose."
    local run_env=(env CLAUDE_SESSIONS_ROOT="$SESSIONS" SCRIPTS_DIR="$DIR/scripts")
    local id
    for id in "$quoting" "$plain" "$skipped"; do
        "${run_env[@]}" "$EXPORTER" --session "$id" "$project" > /dev/null 2>&1
    done
    # The exported files still quote the old id, so the generator's check is
    # expected to report the quoting one as a mismatch until it is re-exported.
    printf '# test exclusions\n%s  # tells the story on purpose\n' "$skipped" > "$SCRATCH/exclude"
    local gen_env=(env CLAUDE_SESSIONS_ROOT="$SESSIONS" TRANSCRIPT_PATCHES_MAP="$REPO/ids.map" TRANSCRIPT_PATCHES_EXCLUDE="$SCRATCH/exclude")
    "${gen_env[@]}" luajit "$TOOL" --dir="$DIR/scripts" translate-ids "$project" > "$SCRATCH/gen1.out" 2>&1
    local patch_dir="$project/llm-transcripts/.patches/$quoting/001-commit-ids-after-history-graft"
    check "a conversation quoting an old id gets an id patch" "$([ -f "$patch_dir/ids" ] && echo yes || echo no)"
    check "the patch lists exactly that id" "$(yes_if grep -qx "$OLD_ID $NEW_ID" "$patch_dir/ids")"
    check "a conversation with no old ids gets none" "$([ ! -d "$project/llm-transcripts/.patches/$plain" ] && echo yes || echo no)"
    check "an excluded conversation gets none" "$([ ! -d "$project/llm-transcripts/.patches/$skipped" ] && echo yes || echo no)"
    check "the summary counts one patched, one plain, one excluded" \
        "$(yes_if grep -q '3 transcript(s): 1 patched, 1 with no old ids, 0 frozen .*, 1 excluded' "$SCRATCH/gen1.out")"
    check "a file on disk without the patch is reported as a mismatch" "$(yes_if grep -q 'MISMATCH' "$SCRATCH/gen1.out")"

    "${run_env[@]}" "$EXPORTER" --session "$quoting" "$project" > /dev/null 2>&1
    local status=0
    "${gen_env[@]}" luajit "$TOOL" --dir="$DIR/scripts" translate-ids "$project" > "$SCRATCH/gen2.out" 2>&1 || status=$?
    check "after re-export, raw + patches matches every file" \
        "$([ "$status" -eq 0 ] && grep -q 'matches the file on disk: 2 of 2' "$SCRATCH/gen2.out" && echo yes || echo no)"
    check "a rerun reuses the same patch folder" \
        "$([ "$(ls "$project/llm-transcripts/.patches/$quoting")" = 001-commit-ids-after-history-graft ] && echo yes || echo no)"
}
# }}}

mkdir -p "$SCRATCH"
SESSIONS="$SCRATCH/sessions"
test_exact_text
test_text_patches
make_repo
test_id_patches
test_exporter
test_new
test_translate_ids
rm -rf "$SCRATCH"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
