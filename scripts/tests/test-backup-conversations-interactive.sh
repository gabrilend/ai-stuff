#!/usr/bin/env bash
# test-backup-conversations-interactive.sh -- checks backup-conversations' -I
# menu (issue 014, phase 4) and the command-line pieces it runs: --newest,
# -o/--output, and the scratch tiers' overridable roots.
#
# Nothing real is touched. Claude's session store is a scratch copy
# (CLAUDE_SESSIONS_ROOT) holding two projects, plus a session folder whose
# project is gone; the toolchain folder is a scratch one (SCRIPTS_DIR) whose
# scratch tiers are made under the scratch folder too (EXEC_TIER_ROOT and
# ARTIFACT_TIER_ROOT).
#
# The menu is driven in a pretend terminal (`script`, 46x100, keys typed one
# second apart). Its items, top to bottom, opened on proj-one:
#    1 Back up every conversation   2 Back up the newest conversation
#    3 proj-one (2)   4 proj-two (1)
#    5 The project's own folder   6 Another folder...   7 Go
# G jumps to Go. The menu reopens with the cursor on item 1; the preview
# panel follows the cursor, so a check of it moves onto a project first.
#
# Needs `script` (util-linux), lua, luajit and jq. Takes about a minute.
# Usage: bash scripts/tests/test-backup-conversations-interactive.sh [scripts-dir]

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
EXPORTER="$DIR/backup-conversations"
WORK="$(mktemp -d /tmp/test-backup-conversations-menu-XXXXXX)"

# {{{ scratch toolchain folder, tiers and session store
mkdir -p "$WORK/scripts" "$WORK/exec" "$WORK/shm" "$WORK/sessions"
ln -s "$DIR/libs" "$WORK/scripts/libs"
ln -s "$DIR/transcript-patches" "$WORK/scripts/transcript-patches"
export SCRIPTS_DIR="$WORK/scripts"
export EXEC_TIER_ROOT="$WORK/exec"
export ARTIFACT_TIER_ROOT="$WORK/shm"
export CLAUDE_SESSIONS_ROOT="$WORK/sessions"
unset CLAUDE_PROJECT_DIR
REAL_LOG="/dev/shm/ai-stuff-scripts/backup-conversations.log"
real_log_size() { stat -c %s "$REAL_LOG" 2>/dev/null || echo none; }
REAL_LOG_BEFORE="$(real_log_size)"
# }}}

# {{{ conversation <project> <id> <day> <words>: one short conversation log
# The folder name is the one Claude Code gives a path (every character that
# is not a letter or digit becomes a dash), written out here rather than
# borrowed from the script under test. The log's time is set to the day, so
# "newest" is well defined.
conversation() {
    local project="$1" id="$2" day="$3" words="$4" folder
    folder="$WORK/sessions/$(printf '%s' "$project" | sed 's/[^A-Za-z0-9]/-/g')"
    mkdir -p "$folder"
    cat > "$folder/$id.jsonl" <<EOF
{"type":"user","timestamp":"2026-${day}T10:00:00.000Z","uuid":"u-$id","cwd":"$project","message":{"role":"user","content":"How many $words are there?"}}
{"type":"assistant","timestamp":"2026-${day}T10:00:05.000Z","cwd":"$project","message":{"role":"assistant","model":"claude-opus-5-5","content":[{"type":"text","text":"There are seven $words."}]}}
EOF
    touch -d "2026-${day} 10:00:05" "$folder/$id.jsonl"
}
# }}}

# {{{ projects
mkdir -p "$WORK/proj-one" "$WORK/proj-two" "$WORK/empty-proj"
conversation "$WORK/proj-one" "aaaaaaaa-1111-1111-1111-111111111111" "10-01" "apples"
conversation "$WORK/proj-one" "bbbbbbbb-2222-2222-2222-222222222222" "10-02" "pears"
conversation "$WORK/proj-two" "cccccccc-3333-3333-3333-333333333333" "09-03" "plums"
conversation "$WORK/gone-proj" "dddddddd-4444-4444-4444-444444444444" "10-05" "figs"
# }}}

pass=0; fail=0
# {{{ check
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

# {{{ helpers
count_md() { find "$1" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l; }
has_words() { cat "$1"/*.md 2>/dev/null | grep -c "seven $2"; }
# drive <name> <project> <keys...>: the menu on <project>, keys, then q
drive() {
    local name="$1" project="$2"; shift 2
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep 1; done
        printf 'q'; sleep 1
    } | timeout 90 script -qfc "stty rows 46 cols 100; bash $EXPORTER -I $project" "$WORK/$name.log" >/dev/null 2>&1
}
screen() { luajit "$DIR/libs/test-menu-screen-replay.lua" "$WORK/$1.log" 46 100; }
# }}}

# {{{ the command line: --newest and -o
bash "$EXPORTER" --newest "$WORK/proj-one" > /dev/null 2>&1
check "--newest exports one conversation" "$(count_md "$WORK/proj-one/llm-transcripts")" "1"
check "the newest one" "$(has_words "$WORK/proj-one/llm-transcripts" pears)" "1"
bash "$EXPORTER" --all "$WORK/proj-one" -o "$WORK/out-cli" > /dev/null 2>&1
check "-o sends a sweep to the named folder" "$(count_md "$WORK/out-cli")" "2"
check "and not to the project's own" "$(count_md "$WORK/proj-one/llm-transcripts")" "1"
check "the scratch tiers are made under the given roots" \
    "$(readlink "$WORK/scripts/tmp")" "$WORK/exec/ai-stuff-scripts"
check "and the log goes there" "$([ -s "$WORK/shm/ai-stuff-scripts/backup-conversations.log" ] && echo yes || echo no)" "yes"
rm -rf "${WORK:?}/proj-one/llm-transcripts"
# }}}

# {{{ the menu: back up every conversation of the named project
drive all "$WORK/proj-one" G $'\r' j j
check "Go backs up every conversation" "$(count_md "$WORK/proj-one/llm-transcripts")" "2"
check "the menu comes back and says so" \
    "$(screen all | grep -c 'Backed up proj-one: Exported 2 log(s), 0 failure(s).')" "1"
check "the projects are listed with their counts" \
    "$(screen all | grep -cE 'proj-one \(2\)|proj-two \(1\)')" "2"
check "a project that is gone is not offered" "$(screen all | grep -c 'gone-proj')" "0"
check "the panel shows the project's newest transcript" "$(screen all | grep -c 'Conversation Summary: bbbbbbbb')" "1"
# }}}

# {{{ the menu: only the newest
rm -rf "${WORK:?}/proj-one/llm-transcripts"
drive newest "$WORK/proj-one" j ' ' G $'\r'
check "the newest conversation alone is backed up" "$(count_md "$WORK/proj-one/llm-transcripts")" "1"
check "and it is the newest" "$(has_words "$WORK/proj-one/llm-transcripts" pears)" "1"
# }}}

# {{{ the menu: another project
drive other "$WORK/proj-one" j j j ' ' G $'\r'
check "choosing proj-two backs it up" "$(has_words "$WORK/proj-two/llm-transcripts" plums)" "1"
check "and leaves proj-one alone" "$(count_md "$WORK/proj-one/llm-transcripts")" "1"
# }}}

# {{{ the menu: another folder, typed
drive archive "$WORK/proj-one" j j j j j ' ' G $'\r' "$WORK/archive"$'\r'
check "a typed folder gets the transcripts" "$(count_md "$WORK/archive")" "2"
check "the project's own folder gets none" "$(count_md "$WORK/proj-one/llm-transcripts")" "1"
check "the menu offers the typed folder next time" "$(screen archive | grep -cE "\(\*\) $WORK/archive[[:space:]]*$")" "1"
# }}}

# {{{ the menu: a folder Claude has no conversations for
drive empty "$WORK/empty-proj" G $'\r'
check "a named folder with no conversations is still shown" "$(screen empty | grep -c 'empty-proj (none on record)')" "1"
check "and Go says why nothing was done" "$(screen empty | grep -c 'Failed: Claude has no session folder')" "1"
check "nothing is made in it" "$(find "$WORK/empty-proj" -mindepth 1 | wc -l)" "0"
# }}}

check "the real scratch log is not written to" "$(real_log_size)" "$REAL_LOG_BEFORE"

rm -rf "${WORK:?}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
