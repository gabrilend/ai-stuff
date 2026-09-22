#!/bin/bash
# test-transcript-patches.sh - proves that deliberate edits to transcripts
# survive re-export, that a patch which no longer fits stops the export instead
# of being skipped, and that the unedited original can always be remade.
#
# In general terms: builds a throwaway repository with a project, a fake copy
# of Claude's session store, and a few patch files, then checks:
#
#   - the literal-text library counts and replaces exactly, and refuses a
#     wrong count;
#   - a replace patch applies to a fresh rendering, recognises a file that
#     already carries it, and turns stale (an error, file untouched) when the
#     text it was written against changes;
#   - a commit-map patch translates quoted commit ids, and translating twice
#     changes nothing;
#   - a patch for one conversation leaves the others alone, and a malformed
#     patch is an error, not a silent omission;
#   - the exporter applies patches on every export, reports an unchanged
#     patched conversation as unchanged, and refuses to overwrite a patched
#     transcript when a patch goes stale;
#   - "original" remakes the unpatched rendering and never writes over the
#     transcript; "verify" re-renders, re-patches and matches;
#   - "new" scaffolds a patch whose text round-trips exactly, including a
#     leading newline and a closing long-bracket.
#
# Nothing under ~/.claude is touched: everything points at the fixtures
# through CLAUDE_SESSIONS_ROOT.

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

# -- {{{ transcript_fixture
# A minimal transcript with the header the tools read the conversation id from.
function transcript_fixture() {
    local path="$1" id="$2" body="$3"
    printf '# Conversation Summary: %s\n\nGenerated on: 2026-09-22 10:00:00\n\n%s\n' "$id" "$body" > "$path"
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

# -- {{{ test_replace_patch
function test_replace_patch() {
    echo "replace patches"
    local tdir="$SCRATCH/plain/llm-transcripts"
    mkdir -p "$tdir/.patches"
    cat > "$tdir/.patches/001-fix-name.lua" <<'EOF'
return {
   id = "001", date = "2026-09-22", reason = "the old name was wrong",
   applies_to = { "conv-one" }, kind = "replace", count = 2,
   old = "Old Name", new = "New Name",
}
EOF
    transcript_fixture "$SCRATCH/raw.md" conv-one "Old Name here, and Old Name there."
    cp "$SCRATCH/raw.md" "$SCRATCH/work.md"
    luajit "$TOOL" --dir="$DIR/scripts" apply "$tdir" conv-one "$SCRATCH/work.md" > /dev/null
    check "applies to a fresh rendering" "$(yes_if grep -q 'New Name here, and New Name there' "$SCRATCH/work.md")"

    cp "$SCRATCH/work.md" "$SCRATCH/again.md"
    luajit "$TOOL" --dir="$DIR/scripts" apply "$tdir" conv-one "$SCRATCH/again.md" > /dev/null
    check "applying to a file that already carries it changes nothing" "$(yes_if cmp -s "$SCRATCH/work.md" "$SCRATCH/again.md")"

    transcript_fixture "$SCRATCH/other.md" conv-two "Old Name stays."
    cp "$SCRATCH/other.md" "$SCRATCH/other-work.md"
    luajit "$TOOL" --dir="$DIR/scripts" apply "$tdir" conv-two "$SCRATCH/other-work.md" > /dev/null
    check "a patch for one conversation leaves another alone" "$(yes_if cmp -s "$SCRATCH/other.md" "$SCRATCH/other-work.md")"

    transcript_fixture "$SCRATCH/stale.md" conv-one "Old Name only once now."
    cp "$SCRATCH/stale.md" "$SCRATCH/stale-work.md"
    local status=0
    luajit "$TOOL" --dir="$DIR/scripts" apply "$tdir" conv-one "$SCRATCH/stale-work.md" > /dev/null 2> "$SCRATCH/stale.err" || status=$?
    check "a stale patch is an error" "$([ "$status" -ne 0 ] && echo yes || echo no)"
    check "the error names the patch" "$(yes_if grep -q '001-fix-name.lua is stale' "$SCRATCH/stale.err")"
    check "a stale patch leaves the file untouched" "$(yes_if cmp -s "$SCRATCH/stale.md" "$SCRATCH/stale-work.md")"

    cat > "$tdir/.patches/002-broken.lua" <<'EOF'
return { id = "003", date = "2026-09-22", reason = "id disagrees with name", applies_to = "all", kind = "replace", count = 1, old = "x", new = "y" }
EOF
    status=0
    luajit "$TOOL" --dir="$DIR/scripts" apply "$tdir" conv-one "$SCRATCH/work.md" > /dev/null 2> "$SCRATCH/broken.err" || status=$?
    check "a malformed patch is an error, not an omission" "$([ "$status" -ne 0 ] && grep -q 'says id 003' "$SCRATCH/broken.err" && echo yes || echo no)"
    rm -f "$tdir/.patches/002-broken.lua"
}
# }}}

# -- {{{ test_commit_map_patch
function test_commit_map_patch() {
    echo "commit-map patches"
    local repo="$SCRATCH/repo"
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m first
    local old_id new_id
    old_id=$(git -C "$repo" rev-parse HEAD)
    git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m second
    new_id=$(git -C "$repo" rev-parse HEAD)
    mkdir -p "$repo/.transcript-patches" "$repo/proj/llm-transcripts"
    printf '%s %s\n' "$old_id" "$new_id" > "$repo/ids.map"
    cat > "$repo/.transcript-patches/001-ids.lua" <<'EOF'
return { id = "001", date = "2026-09-22", reason = "ids moved", applies_to = "all", kind = "commit-map", map = "ids.map" }
EOF
    local f="$repo/proj/llm-transcripts/t.md"
    transcript_fixture "$f" conv-x "See commit ${old_id:0:8} for details."
    luajit "$TOOL" --dir="$DIR/scripts" apply "$repo/proj/llm-transcripts" conv-x "$f" > /dev/null
    check "a quoted old id becomes the new one, same length" "$(yes_if grep -q "See commit ${new_id:0:8} for details" "$f")"
    cp "$f" "$SCRATCH/translated.md"
    luajit "$TOOL" --dir="$DIR/scripts" apply "$repo/proj/llm-transcripts" conv-x "$f" > /dev/null
    check "translating twice changes nothing" "$(yes_if cmp -s "$f" "$SCRATCH/translated.md")"
    check "list reports the repository-wide patch as applied" \
        "$(yes_if sh -c "luajit '$TOOL' --dir='$DIR/scripts' list '$f' | grep -q 'repository 001.*applied'")"
}
# }}}

# -- {{{ test_exporter
# The whole path: a session log, the exporter, a repository-wide patch.
function test_exporter() {
    echo "exporter integration"
    local repo="$SCRATCH/repo"
    local project="$repo/exported"
    mkdir -p "$project"
    local sessions="$SCRATCH/sessions"
    local folder="$sessions/$(printf '%s' "$project" | sed 's/[^A-Za-z0-9]/-/g')"
    mkdir -p "$folder"
    local id="cccccccc-3333-3333-3333-333333333333"
    cat > "$folder/$id.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-09-01T10:00:00.000Z","uuid":"u1","message":{"role":"user","content":"What is the placeholder called?"}}
{"type":"assistant","timestamp":"2026-09-01T10:00:05.000Z","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"It is called WRONGWORD in the notes."}]}}
EOF
    cat > "$repo/.transcript-patches/002-word.lua" <<'EOF'
return { id = "002", date = "2026-09-22", reason = "the word was misheard", applies_to = "all", kind = "replace", count = 1, old = "WRONGWORD", new = "RIGHTWORD" }
EOF
    local run_env=(env CLAUDE_SESSIONS_ROOT="$sessions" SCRIPTS_DIR="$DIR/scripts")
    "${run_env[@]}" "$EXPORTER" --session "$id" "$project" > "$SCRATCH/export1.out" 2>&1
    local file
    file=$(ls "$project"/llm-transcripts/*.md 2>&1 | head -1)
    check "the export carries the patch" "$(yes_if grep -q 'called RIGHTWORD in the notes' "$file")"
    check "the export says which patch it applied" "$(yes_if grep -q 'patched .*repository 002' "$SCRATCH/export1.out")"

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
    sed -i 's/count = 1/count = 2/' "$repo/.transcript-patches/002-word.lua"
    status=0
    "${run_env[@]}" "$EXPORTER" --session "$id" "$project" > "$SCRATCH/export3.out" 2>&1 || status=$?
    check "a stale patch fails the export" "$([ "$status" -ne 0 ] && echo yes || echo no)"
    check "a stale patch leaves the patched transcript on disk" "$(yes_if cmp -s "$file" "$SCRATCH/before-stale.md")"
    sed -i 's/count = 2/count = 1/' "$repo/.transcript-patches/002-word.lua"
}
# }}}

# -- {{{ test_new
function test_new() {
    echo "scaffolding a patch"
    local tdir="$SCRATCH/scaffold/llm-transcripts"
    mkdir -p "$tdir"
    transcript_fixture "$tdir/one.md" conv-new "line a
]] tricky ]=] text
line c"
    printf '\n]] tricky ]=] text' > "$SCRATCH/old.txt"
    printf '\n]] fixed ]=] text' > "$SCRATCH/new.txt"
    luajit "$TOOL" --dir="$DIR/scripts" new --for conv-new --reason "Fix the tricky line" \
        --old "$SCRATCH/old.txt" --new "$SCRATCH/new.txt" "$tdir" > "$SCRATCH/new.out"
    local made
    made=$(ls "$tdir"/.patches/001-*.lua 2>&1 | head -1)
    check "new writes a numbered patch" "$([ -f "$made" ] && echo yes || echo no)"
    check "its count was measured from the transcript" "$(yes_if grep -q 'count      = 1' "$made")"
    luajit "$TOOL" --dir="$DIR/scripts" apply "$tdir" conv-new "$tdir/one.md" > /dev/null
    check "the scaffolded text round-trips (leading newline, long brackets)" "$(yes_if grep -q '^\]\] fixed \]=\] text$' "$tdir/one.md")"
}
# }}}

mkdir -p "$SCRATCH"
test_exact_text
test_replace_patch
test_commit_map_patch
test_exporter
test_new
rm -rf "$SCRATCH"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
