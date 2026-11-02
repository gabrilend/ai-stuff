#!/bin/bash
# test-transcript-prompts.sh - proves that every exported transcript gets a
# prompts file beside it holding only the person's requests, one per line,
# built from the PATCHED transcript so a redaction always applies to it
# (issue 002).
#
# In general terms: builds a throwaway project and a fake copy of Claude's
# session store, runs the exporter on it, and checks:
#
#   - the export writes llm-transcripts/prompts/<transcript name>.txt;
#   - line N is request N, and a request's own line breaks and backslashes
#     are escaped so it stays one line, and unescape gives back the
#     transcript's text byte for byte;
#   - a patch that redacted words in a request redacts them in the prompts
#     file too, and the words from the session log are nowhere in it;
#   - an export that changes nothing leaves the prompts file untouched;
#   - a transcript renamed because the conversation went on to a later day
#     takes its prompts file with it: the old one is gone, the new one holds
#     the new request;
#   - a helper's transcript (agent-... header) gets no prompts file;
#   - --dir fills in a transcript that has none and removes a prompts file
#     whose transcript is gone; --print writes to standard output only;
#   - a transcript whose request numbers skip is refused, not half written.
#
# Nothing under ~/.claude is touched: the exporter reads the fixtures through
# CLAUDE_SESSIONS_ROOT.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/scripts/transcript-prompts"
EXPORTER="$DIR/scripts/backup-conversations"
SCRATCH="${TMPDIR:-/tmp}/transcript-prompts-test-$$"
SESSIONS="$SCRATCH/sessions"
# The rule line the exporter puts before every "### " heading.
RULE=$(printf '%.0s-' $(seq 80))

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

# -- {{{ session_folder
# Where the fake session store keeps a project's logs.
function session_folder() {
    printf '%s/%s\n' "$SESSIONS" "$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g')"
}
# }}}

# -- {{{ add_turn
# Append one request and its reply to a session log:
# add_turn <project> <id> <day> <request text> <reply text>
function add_turn() {
    local project="$1" id="$2" day="$3" request="$4" reply="$5"
    local folder
    folder=$(session_folder "$project")
    mkdir -p "$folder"
    jq -nc --arg t "$request" --arg ts "${day}T10:00:00.000Z" \
        '{"type":"user","timestamp":$ts,"uuid":"u","message":{"role":"user","content":$t}}' >> "$folder/$id.jsonl"
    jq -nc --arg t "$reply" --arg ts "${day}T10:00:05.000Z" \
        '{"type":"assistant","timestamp":$ts,"message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":$t}]}}' >> "$folder/$id.jsonl"
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

# -- {{{ export_one
# Run the exporter on one conversation; output goes to the named file.
function export_one() {
    local project="$1" id="$2" out="$3"
    env CLAUDE_SESSIONS_ROOT="$SESSIONS" SCRIPTS_DIR="$DIR/scripts" \
        "$EXPORTER" --session "$id" "$project" > "$out" 2>&1
}
# }}}

# -- {{{ write_helpers
# Two small Lua helpers the checks run, written into the scratch folder.
#   request.lua DIR FILE N  - request N's body as the transcript reader sees
#                              it, trimmed the way the prompts file trims it
#   line.lua DIR FILE N     - line N of a prompts file, unescaped by the
#                              tool's own unescape
#   escape.lua DIR          - "ok" when escape gives one line and unescape
#                              gives the text back, for awkward samples
function write_helpers() {
    cat > "$SCRATCH/request.lua" <<'LUA'
local reader = dofile(arg[1] .. "/transcript-site/transcript-reader.lua")
local f = io.open(arg[2], "rb"); local text = f:read("*a"); f:close()
for _, e in ipairs(reader.read(text).exchanges) do
    if e.kind == "user" and e.number == tonumber(arg[3]) then
        io.write((e.body:gsub("^%s*\n", ""):gsub("%s+$", "")))
    end
end
LUA
    cat > "$SCRATCH/line.lua" <<'LUA'
arg[0] = arg[1] .. "/as-a-library"
local tp = dofile(arg[1] .. "/transcript-prompts")
local i = 0
for line in io.lines(arg[2]) do
    i = i + 1
    if i == tonumber(arg[3]) then io.write(tp.unescape(line)) end
end
LUA
    cat > "$SCRATCH/escape.lua" <<'LUA'
arg[0] = arg[1] .. "/as-a-library"
local tp = dofile(arg[1] .. "/transcript-prompts")
local samples = { "plain", "two\nlines", "a \\n that is typed", "back\\slash\\", "cr\r\nlf", "\\\\\n\\" }
for _, s in ipairs(samples) do
    local e = tp.escape(s)
    if e:find("\n") or e:find("\r") or tp.unescape(e) ~= s then print("bad: " .. e); os.exit(1) end
end
print("ok")
LUA
}
# }}}

# -- {{{ test_escaping
function test_escaping() {
    echo "escaping"
    check "escape gives one line and unescape gives the text back" \
        "$([ "$(luajit "$SCRATCH/escape.lua" "$DIR/scripts")" = ok ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_exporter
function test_exporter() {
    echo "exporter"
    local project="$SCRATCH/proj"
    mkdir -p "$project/llm-transcripts"
    local id="dddddddd-4444-4444-4444-444444444444"
    add_turn "$project" "$id" 2026-09-01 "Please look at the build." "Looking."
    add_turn "$project" "$id" 2026-09-01 $'Two things:\nfirst the path C:\\temp\\n\nand then my SECRETWORD here.' "Done."
    add_turn "$project" "$id" 2026-09-01 "Thanks, that is all." "You are welcome."
    text_patch "$project/llm-transcripts/.patches/$id/001-redact" "SECRETWORD" "[redacted]" "not for the record"

    export_one "$project" "$id" "$SCRATCH/export1.out"
    local transcript prompts
    transcript=$(ls "$project"/llm-transcripts/*.md | head -1)
    prompts="$project/llm-transcripts/prompts/$(basename "$transcript" .md).txt"
    check "the export writes the prompts file beside the transcript" "$(yes_if test -f "$prompts")"
    check "the export says it wrote it" "$(yes_if grep -q 'created: .*/prompts/' "$SCRATCH/export1.out")"
    check "one line per request" "$([ "$(wc -l < "$prompts")" -eq 3 ] && echo yes || echo no)"
    check "line 1 is request 1" "$([ "$(sed -n 1p "$prompts")" = "Please look at the build." ] && echo yes || echo no)"
    check "line 3 is request 3" "$([ "$(sed -n 3p "$prompts")" = "Thanks, that is all." ] && echo yes || echo no)"
    local i same=yes
    for i in 1 2 3; do
        luajit "$SCRATCH/request.lua" "$DIR/scripts" "$transcript" "$i" > "$SCRATCH/want"
        luajit "$SCRATCH/line.lua" "$DIR/scripts" "$prompts" "$i" > "$SCRATCH/got"
        [ -s "$SCRATCH/want" ] && cmp -s "$SCRATCH/want" "$SCRATCH/got" || same=no
    done
    check "each line unescapes to the transcript's request byte for byte" "$same"
    check "a request's line breaks are written as \\n" "$(yes_if grep -q '^Two things:\\nfirst' "$prompts")"
    check "a request's backslashes are doubled" "$(yes_if grep -qF 'C:\\temp\\n' "$prompts")"
    check "the patch's redaction is in the prompts file" "$(yes_if grep -qF 'my [redacted] here' "$prompts")"
    check "the redacted words are nowhere in it" "$(yes_if sh -c "! grep -q SECRETWORD '$prompts'")"
    check "the redacted words are still in the session log (the test is honest)" \
        "$(yes_if grep -q SECRETWORD "$(session_folder "$project")/$id.jsonl")"

    touch -d '2020-01-01 00:00' "$prompts"
    export_one "$project" "$id" "$SCRATCH/export2.out"
    check "a second export reports the transcript unchanged" "$(yes_if grep -q '^Unchanged:' "$SCRATCH/export2.out")"
    check "and leaves the prompts file untouched" \
        "$([ "$(stat -c %Y "$prompts")" = "$(date -d '2020-01-01 00:00' +%s)" ] && echo yes || echo no)"

    rm "$prompts"
    export_one "$project" "$id" "$SCRATCH/export3.out"
    check "an unchanged export puts back a missing prompts file" "$(yes_if test -f "$prompts")"

    add_turn "$project" "$id" 2026-09-03 "One more, two days later." "Sure."
    export_one "$project" "$id" "$SCRATCH/export4.out"
    local renamed new_prompts
    renamed=$(ls "$project"/llm-transcripts/*.md | head -1)
    new_prompts="$project/llm-transcripts/prompts/$(basename "$renamed" .md).txt"
    check "the conversation going on to a later day renames the transcript" \
        "$([ "$renamed" != "$transcript" ] && [ ! -e "$transcript" ] && echo yes || echo no)"
    check "the old prompts file goes with the old name" "$(yes_if test ! -e "$prompts")"
    check "the new prompts file holds the new request as line 4" \
        "$([ "$(sed -n 4p "$new_prompts" 2>/dev/null)" = "One more, two days later." ] && echo yes || echo no)"
    check "only one prompts file is left" "$([ "$(ls "$project/llm-transcripts/prompts" | wc -l)" -eq 1 ] && echo yes || echo no)"

    TRANSCRIPTS="$project/llm-transcripts"
    LIVE_PROMPTS="$new_prompts"
}
# }}}

# -- {{{ test_by_hand
function test_by_hand() {
    echo "by hand"
    local helper="$TRANSCRIPTS/2026-09-05--helper.md"
    printf '# Conversation Summary: agent-abc123\n\nGenerated on: 2026-09-05 10:00:00\n\n%s\n\n### User Request 1\n\nWritten by the spawning model.\n\n%s\n' "$RULE" "$RULE" > "$helper"
    local frozen="$TRANSCRIPTS/2026-08-01--frozen.md"
    printf '# Conversation Summary: eeeeeeee-5555\n\nGenerated on: 2026-08-01 10:00:00\n\n%s\n\n### User Request 1\n\nAn old request.\n\n%s\n\n### Assistant Response 1\n\nAn old answer.\n\n%s\n\n### User Request 2\n\nIts second request.\n\n%s\n' "$RULE" "$RULE" "$RULE" "$RULE" > "$frozen"
    printf 'Not a transcript, just notes.\n' > "$TRANSCRIPTS/notes.md"
    mkdir -p "$TRANSCRIPTS/prompts"
    printf 'left behind\n' > "$TRANSCRIPTS/prompts/2026-07-01--gone.txt"
    printf 'kept\n' > "$TRANSCRIPTS/prompts/README"
    cp "$LIVE_PROMPTS" "$SCRATCH/live-before"

    local status=0
    luajit "$TOOL" --dir "$TRANSCRIPTS" > "$SCRATCH/dir.out" 2>&1 || status=$?
    check "--dir succeeds" "$([ "$status" -eq 0 ] && echo yes || echo no)"
    check "--dir fills in a transcript the exporter will not write again" \
        "$([ "$(cat "$TRANSCRIPTS/prompts/2026-08-01--frozen.txt" 2>/dev/null)" = $'An old request.\nIts second request.' ] && echo yes || echo no)"
    check "a helper's transcript gets no prompts file" "$(yes_if test ! -e "$TRANSCRIPTS/prompts/2026-09-05--helper.txt")"
    check "a .md that is not a transcript gets none" "$(yes_if test ! -e "$TRANSCRIPTS/prompts/notes.txt")"
    check "a prompts file whose transcript is gone is removed" "$(yes_if test ! -e "$TRANSCRIPTS/prompts/2026-07-01--gone.txt")"
    check "and --dir says so" "$(yes_if grep -q 'removed: .*2026-07-01--gone.txt' "$SCRATCH/dir.out")"
    check "anything else in prompts/ is left alone" "$(yes_if test -f "$TRANSCRIPTS/prompts/README")"
    check "an up-to-date prompts file is not rewritten" "$(yes_if cmp -s "$LIVE_PROMPTS" "$SCRATCH/live-before")"

    local printed
    printed=$(luajit "$TOOL" --print "$frozen")
    check "--print writes the lines to standard output" "$([ "$printed" = $'An old request.\nIts second request.' ] && echo yes || echo no)"

    local skipping="$SCRATCH/skipping.md"
    printf '# Conversation Summary: ffffffff-6666\n\n%s\n\n### User Request 1\n\nOne.\n\n%s\n\n### User Request 3\n\nThree.\n\n%s\n' "$RULE" "$RULE" "$RULE" > "$skipping"
    status=0
    luajit "$TOOL" "$skipping" > /dev/null 2> "$SCRATCH/skip.err" || status=$?
    check "request numbers that skip are refused with status 1" "$([ "$status" -eq 1 ] && echo yes || echo no)"
    check "and no prompts file is written for it" "$(yes_if test ! -e "$SCRATCH/prompts/skipping.txt")"

    status=0
    luajit "$TOOL" > /dev/null 2>&1 || status=$?
    check "no arguments is a usage error (2)" "$([ "$status" -eq 2 ] && echo yes || echo no)"
}
# }}}

mkdir -p "$SCRATCH"
write_helpers
test_escaping
test_exporter
test_by_hand
rm -rf "$SCRATCH"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
