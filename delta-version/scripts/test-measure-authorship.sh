#!/bin/bash
# test-measure-authorship.sh - proves the authorship measure counts the right
# things once.
#
# In general terms: this builds small made-up transcripts in RAM, each one
# written to test one counting rule, runs the measure on them, and checks the
# totals: the person's prose is theirs, a pasted error is set aside, messages
# the tool wrote are set aside, a prompt the model wrote is the machine's, a
# conversation saved twice is counted once, the fuller copy of an answer is
# the one counted, a common word like "continue" in two conversations counts
# twice, re-wrapping text changes nothing, pasted program output is set aside
# while sentences around it are kept, and splitting the work across many
# workers gives the same answer as one. It also builds a small git repository
# with one file per rule and checks that notes, source, documents and
# someone else's code each land in the right pile, and that untracked,
# generated and copied files are left out. Exercises the rules of issue 059.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

MEASURE="$DIR/delta-version/scripts/measure-authorship.lua"
FIXTURES="/dev/shm/delta-version/measure-authorship-test"
SEPARATOR="--------------------------------------------------------------------------------"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    # One line per assertion; failures keep going so a run reports everything.
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

# -- {{{ same
function same() {
    # "yes" when two values are equal, for check's second argument.
    [ "$1" = "$2" ] && echo yes || echo no
}
# }}}

# -- {{{ fresh_tree
function fresh_tree() {
    # A new, empty fixture repository; prints its path. Every case gets its
    # own, so one case's files never leak into another's totals.
    # It is also a git repository tracking one hidden placeholder, since the
    # measure reads the repository's tracked files as well as its transcripts
    # (a hidden file belongs to no pile, so transcript cases stay unaffected).
    local name="$1"
    rm -rf "${FIXTURES:?}/$name"
    mkdir -p "$FIXTURES/$name/project/llm-transcripts"
    git -C "$FIXTURES/$name" init -q
    : > "$FIXTURES/$name/.placeholder"
    git -C "$FIXTURES/$name" add .placeholder
    echo "$FIXTURES/$name"
}
# }}}

# -- {{{ conversation
function conversation() {
    # Writes a transcript in the exporter's shape. Arguments: file, session id,
    # then alternating "U:text" / "A:text" turns.
    local file="$1" session="$2"
    shift 2
    {
        echo "# Conversation Summary: $session"
        echo ""
        echo "Generated on: 2026-09-23 12:00:00"
        echo ""
        echo "$SEPARATOR"
        local number=0 turn
        for turn in "$@"; do
            echo ""
            if [ "${turn:0:2}" = "U:" ]; then
                number=$((number + 1))
                echo "### User Request $number"
            else
                echo "### Assistant Response $number"
            fi
            echo ""
            printf '%s\n' "${turn:2}"
            echo ""
            echo "$SEPARATOR"
        done
    } > "$file"
}
# }}}

# -- {{{ field
function field() {
    # One number from the measure's JSON for the tree given.
    local tree="$1" name="$2"
    luajit "$MEASURE" --json --dir="$tree" | sed -n "s/^  \"$name\": \\([0-9.]*\\),\\{0,1\\}$/\\1/p"
}
# }}}

# -- {{{ test_prose_is_human
function test_prose_is_human() {
    local tree
    tree=$(fresh_tree prose)
    # "How are you?" is 12 characters; "Fine, thanks." is 13.
    conversation "$tree/project/llm-transcripts/a.md" "s-prose" "U:How are you?" "A:Fine, thanks."
    check "typed prose is the person's" "$(same "$(field "$tree" human_characters)" 12)"
    check "the answer is the machine's" "$(same "$(field "$tree" machine_units)" 13)"
}
# }}}

# -- {{{ test_pasted_log_set_aside
function test_pasted_log_set_aside() {
    local tree
    tree=$(fresh_tree pasted)
    local log
    log=$(printf 'Traceback (most recent call last):\n  File "run.py", line 3, in <module>\nKeyError: x')
    conversation "$tree/project/llm-transcripts/a.md" "s-paste" \
        "U:$(printf 'It broke like this:\n\n%s\n\nWhy?' "$log")" "A:Because."
    # "It broke like this:" (19) and "Why?" (4) are the person's.
    check "prose around a pasted traceback is the person's" "$(same "$(field "$tree" human_characters)" 23)"
    local excluded
    excluded=$(field "$tree" excluded_paste_characters)
    check "the traceback itself is set aside" "$([ "${excluded:-0}" -gt 50 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_wrapped_log_tail_set_aside
function test_wrapped_log_tail_set_aside() {
    # The exporter re-wraps a long log line and sets its pieces apart with
    # blank lines; the tail pieces look like nothing on their own.
    local tree
    tree=$(fresh_tree wrapped)
    conversation "$tree/project/llm-transcripts/a.md" "s-wrap" \
        "U:$(printf 'Ollama says this:\n\ntime=2026-06-19T01:02:12 level=ERROR source=server.go:424 msg="llama\n\nrunner terminated"\n\nAny idea?')" "A:Yes."
    check "a re-wrapped log's tail is set aside with it" \
        "$(same "$(field "$tree" human_characters)" $((17 + 9)))"
}
# }}}

# -- {{{ test_system_turns_set_aside
function test_system_turns_set_aside() {
    local tree
    tree=$(fresh_tree system)
    conversation "$tree/project/llm-transcripts/a.md" "s-system" \
        "U:<local-command-stdout>compacted</local-command-stdout>" "A:ok" \
        "U:Base directory for this skill: /somewhere" "A:ok" \
        "U:Hi." "A:ok"
    check "tool-generated turns are not the person's" "$(same "$(field "$tree" human_characters)" 3)"
    local system
    system=$(field "$tree" system_characters)
    check "tool-generated turns are counted as set aside" "$([ "${system:-0}" -gt 60 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_owners_greeting_is_human
function test_owners_greeting_is_human() {
    # The owner answered (issue 059): only they type "Hello computer, all is
    # well." -- in a live session or in a `<date>_agent-<n>.md` run with an
    # ordinary session id alike. The file name is not evidence of a script.
    local tree
    tree=$(fresh_tree greeting)
    conversation "$tree/project/llm-transcripts/a.md" "s-live" \
        "U:Hello computer, all is well. Split this." "A:ok"
    conversation "$tree/project/llm-transcripts/a_agent-2.md" "0f0f0f0f-0000-4000-8000-000000000000" \
        "U:Hello computer, all is well. Plan issue 12." "A:ok"
    # 40 + 43 characters, nothing set aside.
    check "the owner's greeting is the owner's, live or in an agent-named file" \
        "$(same "$(field "$tree" human_characters)" $((40 + 43)))"
    check "and nothing of it is set aside" "$(same "$(field "$tree" system_characters)" 0)"
}
# }}}

# -- {{{ test_model_written_prompts
function test_model_written_prompts() {
    local tree
    tree=$(fresh_tree model-prompts)
    # A sub-agent's prompt was written by the main model; the session id
    # "agent-…" is the evidence, whatever the file is called.
    conversation "$tree/project/llm-transcripts/d_agent-1.md" "agent-abc123" "U:Search the tree." "A:Found it."
    # A compaction summary is the model's own writing, even in a main session.
    conversation "$tree/project/llm-transcripts/d.md" "s-main" \
        "U:This session is being continued from a previous conversation. Summary." "A:Resuming."
    check "no model-written prompt is the person's" "$(same "$(field "$tree" human_characters)" 0)"
    # "Search the tree." 16 + "Found it." 9 + summary 70 + "Resuming." 9
    check "sub-agent prompts and compaction summaries are the machine's" \
        "$(same "$(field "$tree" machine_units)" $((16 + 9 + 70 + 9)))"
}
# }}}

# -- {{{ test_copies_counted_once
function test_copies_counted_once() {
    local tree
    tree=$(fresh_tree copies)
    conversation "$tree/project/llm-transcripts/day.md" "s-copy" "U:Build the thing." "A:Built."
    mkdir -p "$tree/other/llm-transcripts"
    # The same session, saved into another project's folder.
    conversation "$tree/other/llm-transcripts/range.md" "s-copy" "U:Build the thing." "A:Built."
    check "a conversation saved twice counts once (person)" "$(same "$(field "$tree" human_characters)" 16)"
    check "a conversation saved twice counts once (machine)" "$(same "$(field "$tree" machine_units)" 6)"
    check "both copies were seen" "$(same "$(field "$tree" turn_copies_seen)" 2)"
}
# }}}

# -- {{{ test_fuller_answer_wins
function test_fuller_answer_wins() {
    local tree
    tree=$(fresh_tree fuller)
    conversation "$tree/project/llm-transcripts/compact.md" "s-full" "U:Write it." "A:Written."
    conversation "$tree/project/llm-transcripts/complete.md" "s-full" "U:Write it." "A:Written, and here is all of it."
    check "the fuller rendering of an answer is the one counted" \
        "$(same "$(field "$tree" machine_units)" 31)"
}
# }}}

# -- {{{ test_common_words_in_two_conversations
function test_common_words_in_two_conversations() {
    local tree
    tree=$(fresh_tree common)
    conversation "$tree/project/llm-transcripts/a.md" "s-one" "U:Fix the parser." "A:ok" "U:continue" "A:ok"
    conversation "$tree/project/llm-transcripts/b.md" "s-two" "U:Draw the map." "A:ok" "U:continue" "A:ok"
    # 15 + 8 + 13 + 8: "continue" is counted in each conversation.
    check "\"continue\" in two conversations counts twice" \
        "$(same "$(field "$tree" human_characters)" $((15 + 8 + 13 + 8)))"
}
# }}}

# -- {{{ test_rewrapping_is_neutral
function test_rewrapping_is_neutral() {
    local tree_a tree_b
    tree_a=$(fresh_tree wrap-a)
    tree_b=$(fresh_tree wrap-b)
    conversation "$tree_a/project/llm-transcripts/a.md" "s-w" \
        "U:one two three four five six seven eight nine ten" "A:ok"
    conversation "$tree_b/project/llm-transcripts/a.md" "s-w" \
        "U:$(printf 'one two three four\nfive six seven\neight nine ten')" "A:ok"
    check "re-wrapped text counts the same" \
        "$(same "$(field "$tree_a" human_characters)" "$(field "$tree_b" human_characters)")"
    check "and keys as the same turn" \
        "$(same "$(field "$tree_a" turns_counted)" "$(field "$tree_b" turns_counted)")"
}
# }}}

# -- {{{ test_heading_ends_a_turn
function test_heading_ends_a_turn() {
    # The recursive exports start an embedded conversation right after the
    # last answer, with no separator; the answer must stop at the heading.
    local tree
    tree=$(fresh_tree heading)
    {
        echo "### User Request 1"
        echo ""
        echo "Hi."
        echo ""
        echo "$SEPARATOR"
        echo "### Assistant Response 1"
        echo ""
        echo "Hello."
        echo "## 📜 Conversation 2: something-else.md"
        echo "Material between conversations that nobody said."
    } > "$tree/project/llm-transcripts/a.md"
    check "a conversation heading ends the answer before it" "$(same "$(field "$tree" machine_units)" 6)"
}
# }}}

# -- {{{ chars
function chars() {
    # The measure's character rule, for working out what a test expects:
    # each run of whitespace is one space, none at the ends.
    printf '%s' "$1" | tr -s ' \n\t' '   ' | sed -e 's/^ //' -e 's/ $//' | tr -d '\n' | wc -m
}
# }}}

# -- {{{ test_pasted_program_output_set_aside
function test_pasted_program_output_set_aside() {
    # The owner: pasted program output ideally is not theirs. A box-drawn
    # report, a progress bar and the model's words quoted back are set aside;
    # the lead-in and the question stay the person's.
    local tree
    tree=$(fresh_tree program-output)
    conversation "$tree/project/llm-transcripts/a.md" "s-output" \
        "U:$(printf "Here's the report:\n\n┌──────┐\n│ ok   │\n└──────┘\n\n[=====>    ] 50%% (5/10 done)\n\n> the model said this\n> and then this\n\nWhy is the bar stuck?")" "A:ok"
    check "program output is set aside, the lead-in and question are kept" \
        "$(same "$(field "$tree" human_characters)" $(( $(chars "Here's the report:") + $(chars "Why is the bar stuck?") )))"
}
# }}}

# -- {{{ test_sentences_with_output_words_stay_human
function test_sentences_with_output_words_stay_human() {
    # The other direction: a sentence that mentions a path, a percentage or
    # an emoji is still someone talking.
    local tree text
    tree=$(fresh_tree sentences)
    text="Please look at src/main.lua and tell me what the ✅ means, since it shows 50% twice."
    conversation "$tree/project/llm-transcripts/a.md" "s-sentence" "U:$text" "A:ok" \
        "U:$(printf 'I tried this:\n\n$ ./run\n\nand then I thought about it for a long while and changed my mind.')" "A:ok"
    check "sentences mentioning paths, percentages and emoji are the person's" \
        "$(same "$(field "$tree" human_characters)" $(( $(chars "$text") + $(chars "I tried this:") + $(chars "and then I thought about it for a long while and changed my mind.") )))"
}
# }}}

# -- {{{ put
function put() {
    # Writes one file into a fixture repository, creating its folders.
    local tree="$1" path="$2" content="$3"
    mkdir -p "$(dirname "$tree/$path")"
    printf '%s' "$content" > "$tree/$path"
}
# }}}

# -- {{{ build_repository_fixture
function build_repository_fixture() {
    # A small git repository with one file per rule. Prints its path.
    local tree
    tree=$(fresh_tree repository)
    git -C "$tree" init -q
    # conversation: the transcript half needs one
    conversation "$tree/project/llm-transcripts/t.md" "s-repo" "U:Hello." "A:Hi."
    # notes (the person's), including notes kept as a project's input
    put "$tree" "notes/idea.txt" "my note"
    put "$tree" "project/input/notes/poem" "a poem"
    # source: an extension, a #! script, a project's own libs/, the owner's notice
    put "$tree" "project/src/a.lua" "print(1)"
    put "$tree" "project/src/copy.lua" "print(1)"
    put "$tree" "project/tool" "$(printf '#!/bin/sh\necho hi')"
    put "$tree" "project/libs/own.lua" "local x = 2"
    put "$tree" "project/src/owner.lua" "$(printf -- '-- Copyright (C) 2026 gabrilend\nreturn 3')"
    # docs: markdown anywhere, .txt under docs/, an .info.md, the root README
    put "$tree" "project/docs/x.md" "doc x"
    put "$tree" "project/issues/101-x.md" "issue"
    put "$tree" "project/src/a.info.md" "info"
    put "$tree" "README.md" "top"
    put "$tree" "project/docs/y.txt" "text"
    # left out
    put "$tree" "project/data" "just data"
    put "$tree" "project/data.txt" "loose text"
    put "$tree" "project/docs/HTML/page.html" "<p>generated</p>"
    put "$tree" "project/input/in.lua" "input()"
    put "$tree" "project/output/out.lua" "output()"
    put "$tree" "project/archive/old.lua" "old()"
    put "$tree" "project/design.bak.md" "old design"
    put "$tree" "project/docs/convo.md" "$(printf '# Pack\n\n### User Request 1\n\nhi\n\n### Assistant Response 1\n\nhello')"
    printf 'int\0binary;' > "$tree/project/src/bin.c"
    # vendored: a foreign licence, the top-level libs/, a foreign header,
    # a package manager's folder, a saved web page
    put "$tree" "vend/LICENSE" "$(printf 'MIT License\n\nCopyright (c) 2020 Someone Else\n\nPermission is hereby granted')"
    put "$tree" "vend/lib.c" "int v;"
    put "$tree" "libs/x.lua" "x"
    put "$tree" "project/src/dk.lua" "$(printf -- '-- Copyright (C) 2010 David Kolf\nreturn 4')"
    put "$tree" "project/luarocks/r.lua" "r"
    put "$tree" "project/docs/Page.html" "<html>saved</html>"
    put "$tree" "project/docs/Page_files/p.js" "var p;"
    git -C "$tree" add -A
    # untracked: must not count
    put "$tree" "project/src/untracked.lua" "untracked()"
    echo "$tree"
}
# }}}

# -- {{{ test_repository_piles
function test_repository_piles() {
    local tree json
    tree=$(build_repository_fixture)
    json=$(luajit "$MEASURE" --json --dir="$tree")
    local notes docs source vendored human_total
    notes=$(( $(chars "my note") + $(chars "a poem") ))
    source=$(( $(chars "print(1)") + $(chars "$(printf '#!/bin/sh\necho hi')") + $(chars "local x = 2") + $(chars "$(printf -- '-- Copyright (C) 2026 gabrilend\nreturn 3')") ))
    docs=$(( $(chars "doc x") + $(chars "issue") + $(chars "info") + $(chars "top") + $(chars "text") ))
    # every text file under a vendored folder counts there, its licence too
    vendored=$(( $(chars "$(printf 'MIT License\n\nCopyright (c) 2020 Someone Else\n\nPermission is hereby granted')") + $(chars "int v;") + $(chars "x") + $(chars "$(printf -- '-- Copyright (C) 2010 David Kolf\nreturn 4')") + $(chars "r") + $(chars "<html>saved</html>") + $(chars "var p;") ))
    human_total=$(( $(chars "Hello.") + notes ))
    check "notes are counted, including notes kept under input/" "$(same "$(field "$tree" notes_characters)" "$notes")"
    check "source: extensions, #! scripts, own libs/, the owner's notice; one copy of a duplicate" \
        "$(same "$(field "$tree" source_characters)" "$source")"
    check "docs: markdown, .txt under docs/, .info.md, README; not generated HTML, .bak or conversations" \
        "$(same "$(field "$tree" docs_characters)" "$docs")"
    check "vendored: foreign licence, top-level libs/, foreign header, luarocks, saved page" \
        "$(same "$(field "$tree" vendored_characters)" "$vendored")"
    check "human-written total is typed text plus notes" "$(same "$(field "$tree" human_written_total)" "$human_total")"
    check "machine-written total is the model's transcript text" \
        "$(same "$(field "$tree" machine_written_total)" "$(chars "Hi.")")"
    check "the duplicate was seen and counted once" "$(same "$(field "$tree" repo_duplicate_files)" 1)"
}
# }}}

# -- {{{ test_workers_agree
function test_workers_agree() {
    local tree one many
    tree="$FIXTURES/common"
    one=$(luajit "$MEASURE" --json --workers=1 --dir="$tree")
    many=$(luajit "$MEASURE" --json --workers=3 --dir="$tree")
    check "one worker and three workers agree" "$(same "$one" "$many")"
    # the repository walk too, where copies must land in the same pile
    # whichever worker finishes first
    tree="$FIXTURES/repository"
    one=$(luajit "$MEASURE" --json --workers=1 --dir="$tree")
    many=$(luajit "$MEASURE" --json --workers=5 --dir="$tree")
    check "one worker and five agree on the repository walk" "$(same "$one" "$many")"
}
# }}}

mkdir -p "$FIXTURES"
echo "measure-authorship"
test_prose_is_human
test_pasted_log_set_aside
test_wrapped_log_tail_set_aside
test_system_turns_set_aside
test_owners_greeting_is_human
test_model_written_prompts
test_copies_counted_once
test_fuller_answer_wins
test_common_words_in_two_conversations
test_rewrapping_is_neutral
test_heading_ends_a_turn
test_pasted_program_output_set_aside
test_sentences_with_output_words_stay_human
test_repository_piles
test_workers_agree
[ "${KEEP_FIXTURES:-}" ] || rm -rf "${FIXTURES:?}"
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
