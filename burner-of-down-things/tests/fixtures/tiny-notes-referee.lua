-- tiny-notes-referee.lua
--
-- The workflows a careful referee turn would write from the tiny-notes
-- blueprint as it stands in a case (issue 506): end-to-end scripts that use
-- the notes program the way a person would — typing commands, reading what
-- it prints, looking in its notes file — and never its internals. Each
-- change a fixture request made to the blueprint (found by the marker text
-- the amended issue holds) changes what the workflows expect, the way a
-- referee reading the amended blueprint would.
--
-- Returns function(blueprint_now) -> { [workflow file name] = text }, where
-- blueprint_now maps issue id -> the issue file's text in the case.

local PROLOGUE = table.concat({
    "set -u",
    "NOTES_FILE=$(mktemp -u); export NOTES_FILE",
    "trap 'rm -f \"$NOTES_FILE\"' EXIT",
    "fail() { echo \"FAIL: $*\"; exit 1; }",
    "notes() { luajit notes.lua \"$@\"; }",
    "",
}, "\n")

-- {{{ local function header
local function header(covers, what)
    return "#!/usr/bin/env bash\n# covers: " .. covers .. "\n# " .. what .. "\n" .. PROLOGUE
end
-- }}}

return function(blueprint_now)
    local count = blueprint_now["301"]:find("N notes", 1, true) ~= nil
    local hash = blueprint_now["201"]:find("with its # mark", 1, true) ~= nil
    local file_header = blueprint_now["101"]:find("# notes v1", 1, true) ~= nil
    local w = {}

    w["01-add-and-list.sh"] = header("101 103 201 301", "A person adds two notes and lists them.") .. table.concat({
        'notes add buy milk | grep -qx "added 1" || fail "the first add did not say added 1"',
        'notes add call back | grep -qx "added 2" || fail "the second add did not say added 2"',
        'out=$(notes list) || fail "list exited non-zero"',
        [[echo "$out" | grep -qE '^ +1  [0-9]{4}-[0-9]{2}-[0-9]{2}  buy milk$' || fail "note 1 is not shown as id, date, text: $out"]],
        [[echo "$out" | grep -qE '^ +2  [0-9]{4}-[0-9]{2}-[0-9]{2}  call back$' || fail "note 2 is not shown: $out"]],
        [[first=$(echo "$out" | grep -n 'buy milk' | cut -d: -f1); second=$(echo "$out" | grep -n 'call back' | cut -d: -f1)]],
        '[ "$first" -lt "$second" ] || fail "notes are not listed in the order they were added"',
        count and [[echo "$out" | tail -n 1 | grep -qx "2 notes" || fail "the list does not end with '2 notes': $out"]] or "",
        "echo ok", "",
    }, "\n")

    w["02-tags.sh"] = header("102 201 301", "A person tags notes and lists by tag, in any case.") .. table.concat({
        [[notes add buy milk '#Home' '#errands' '#home' > /dev/null || fail "add exited non-zero"]],
        'notes add fix the bike > /dev/null || fail "add exited non-zero"',
        'out=$(notes list) || fail "list exited non-zero"',
        hash and [[echo "$out" | grep -qF '[#home #errands]' || fail "tags are not shown once each, lower-cased, with their # marks: $out"]]
            or [[echo "$out" | grep -qF '[home errands]' || fail "tags are not shown once each, lower-cased, in brackets: $out"]],
        [[echo "$out" | grep 'fix the bike' | grep -qF '[' && fail "a note with no tags shows brackets: $out"]],
        [[tagged=$(notes list '#HOME') || fail "list by tag exited non-zero"]],
        [[echo "$tagged" | grep -qF 'buy milk' || fail "listing by #HOME misses the tagged note: $tagged"]],
        [[echo "$tagged" | grep -qF 'fix the bike' && fail "listing by #HOME shows an untagged note: $tagged"]],
        count and [[echo "$tagged" | tail -n 1 | grep -qx "1 note" || fail "one note is not counted as '1 note': $tagged"]] or "",
        "echo ok", "",
    }, "\n")

    w["03-find.sh"] = header("202 301", "A person finds notes by a word, in any case.") .. table.concat({
        'notes add fix the bike chain > /dev/null || fail "add exited non-zero"',
        'notes add buy milk > /dev/null || fail "add exited non-zero"',
        'found=$(notes find CHAIN) || fail "find exited non-zero"',
        [[echo "$found" | grep -qF 'fix the bike chain' || fail "find CHAIN misses the note: $found"]],
        [[echo "$found" | grep -qF 'buy milk' && fail "find CHAIN shows a note without the word: $found"]],
        "echo ok", "",
    }, "\n")

    w["04-notes-last.sh"] = header("101 201 301", "A person's notes are kept between runs, in a file they can read.") .. table.concat({
        'out=$(notes list) || fail "list of an empty notebook exited non-zero"',
        [[echo "$out" | grep -qF '(no notes)' || fail "an empty notebook does not say (no notes): $out"]],
        'notes add remember this > /dev/null || fail "add exited non-zero"',
        [[notes list | grep -qF 'remember this' || fail "the note is not there on the next run"]],
        [[grep -qF 'remember this' "$NOTES_FILE" || fail "the note is not in the notes file"]],
        file_header and [[head -n 1 "$NOTES_FILE" | grep -qx '# notes v1' || fail "the notes file does not start with '# notes v1'"]] or "",
        "echo ok", "",
    }, "\n")

    w["05-usage.sh"] = header("301", "A person types something the program does not know.") .. table.concat({
        'out=$(notes frobnicate); status=$?',
        '[ "$status" -eq 1 ] || fail "an unknown command exits $status, not 1"',
        [[echo "$out" | grep -qi 'usage' || fail "an unknown command prints no usage: $out"]],
        "echo ok", "",
    }, "\n")

    return w
end
