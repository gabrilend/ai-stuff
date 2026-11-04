#!/bin/bash
# test-summarize-overseer.sh - proves summarize-overseer.sh finds the
# repositories in scope from the sessions' own folders, picks out the
# transcripts with no summary yet, changes nothing unless run=on, and when
# on, summarizes, exports and commits only as configured.
#
# In general terms: a scratch "ai-stuff root", an outside repository and a
# fake ~/.claude/projects are built in a RAM folder, with hand-written
# transcripts; the real summarizer and applier run against a stand-in chat
# model (libs/stand-in-model/, no download, no real model). The exporter is
# a stand-in that only records how it was called. Exercises issue 056 (056d).
#
# Usage: test-summarize-overseer.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/summarize-overseer.sh"
SCRATCH="$DIR/delta-version/tmp/shared-memory/summarize-overseer-test"
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

# -- {{{ run
function run() {
    OUT=$(EXPORTER="$SCRATCH/fake-exporter" timeout 120 bash "$TOOL" --dir "$DIR" --config "$CONFIG" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ g
function g() { git -c user.name=t -c user.email=t@example.invalid "$@"; }
# }}}

# -- {{{ write_transcript
function write_transcript() {
    # FILE, conversation id, the request's words.
    {
        echo "# Conversation Summary: $2"
        echo ""
        echo "Generated on: 2026-11-02 12:00:00"
        echo ""
        echo "$SEPARATOR"
        echo ""
        echo "### User Request 1"
        echo ""
        echo "$3"
        echo ""
        echo "$SEPARATOR"
        echo ""
        echo "### Assistant Response 1"
        echo ""
        echo "Done."
        echo ""
        echo "$SEPARATOR"
    } > "$1"
}
# }}}

# -- {{{ session
function session() {
    # NAME, the cwd it records.
    mkdir -p "$SCRATCH/claude/$1"
    printf '{"type":"summary"}\n{"cwd":"%s","type":"user"}\n' "$2" > "$SCRATCH/claude/$1/s.jsonl"
}
# }}}

# -- {{{ write_config
function write_config() {
    # run, export, commit, max_per_run, include_all
    cat > "$CONFIG" <<EOF
[settings]
include_all_ai_stuff=${5:-true}
ai_stuff_root=$ROOT
claude_projects_dir=$SCRATCH/claude

[extra_repos]
# a comment
$OUTSIDE

[apply]
table_of_contents=table-of-contents.md
inline_blurb=on
rename=off

[overseer]
run=$1
export=$2
commit=$3
max_per_run=${4:-10}
EOF
}
# }}}

# -- {{{ setup
# root/alpha: conv-a (to do), conv-b (already in the table of contents),
# a note that is not a transcript. root/gamma: conv-g. outside: conv-o.
# elsewhere: a session in a folder that is neither, and is skipped.
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    ROOT="$SCRATCH/root"
    OUTSIDE="$SCRATCH/outside"
    ELSEWHERE="$SCRATCH/elsewhere"
    CONFIG="$SCRATCH/repos.conf"
    mkdir -p "$ROOT/alpha/llm-transcripts" "$ROOT/alpha/src" "$ROOT/gamma/llm-transcripts" \
        "$OUTSIDE/llm-transcripts" "$ELSEWHERE/llm-transcripts" "$ROOT/beta"
    write_transcript "$ROOT/alpha/llm-transcripts/dec-10-25.md" conv-a "Build the parser."
    write_transcript "$ROOT/alpha/llm-transcripts/dec-11-25.md" conv-b "Fix the loader."
    printf '# Table of Contents\n\n<!-- transcript-summary: conv-b -->\n## [Fixed](dec-11-25.md)\n\nDone.\n' \
        > "$ROOT/alpha/llm-transcripts/table-of-contents.md"
    printf 'A note, not a transcript.\n' > "$ROOT/alpha/llm-transcripts/notes.md"
    write_transcript "$ROOT/gamma/llm-transcripts/dec-12-25.md" conv-g "STAND-IN-FAIL please."
    write_transcript "$OUTSIDE/llm-transcripts/dec-13-25.md" conv-o "Tune the server."
    write_transcript "$ELSEWHERE/llm-transcripts/dec-14-25.md" conv-e "Never read."
    g init -q "$OUTSIDE"
    g -C "$OUTSIDE" add -A
    g -C "$OUTSIDE" commit -q -m "transcripts"
    echo "unrelated work" > "$OUTSIDE/work.txt"

    session alpha "$ROOT/alpha/src"
    session beta "$ROOT/beta"
    session gamma "$ROOT/gamma"
    session outside "$OUTSIDE"
    session elsewhere "$ELSEWHERE"

    printf '#!/bin/bash\necho "$@" >> "%s/exporter-calls"\n' "$SCRATCH" > "$SCRATCH/fake-exporter"
    chmod +x "$SCRATCH/fake-exporter"
    find "$SCRATCH" -name '*.md' -exec sha256sum {} + > "$SCRATCH/sums"

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_preview
function test_preview() {
    write_config off on on
    run
    check "run=off: exit 0" "$(same "$CODE" 0)"
    check "... says it only previews" "$(has_line "$OUT" "preview only: run=off")"
    check "a project inside the root, found from a session in its subfolder" \
        "$(has_line "$OUT" "$ROOT/alpha: 2 transcripts, 1 summarized, 1 to do")"
    check "... the one already in the table of contents is left" "$(lacks_line "$OUT" "would summarize dec-11-25.md")"
    check "... the other is listed" "$(has_line "$OUT" "would summarize dec-10-25.md")"
    check "an outside repository listed in [extra_repos] is in scope" "$(has_line "$OUT" "$OUTSIDE: 1 transcripts")"
    check "a folder that is neither is not" "$(lacks_line "$OUT" "$ELSEWHERE")"
    check "a project with no llm-transcripts/ says so" "$(has_line "$OUT" "$ROOT/beta: no llm-transcripts/ folder")"
    check "the export is only described" "$(has_line "$OUT" "would export its sessions again")"
    check "nothing was changed" "$(sha256sum -c --quiet "$SCRATCH/sums" > /dev/null 2>&1 && echo yes || echo no)"
    check "... the exporter was not called" "$([ -e "$SCRATCH/exporter-calls" ] && echo no || echo yes)"

    write_config off off off 10 false
    run
    check "include_all_ai_stuff=false: the root's projects are out of scope" \
        "$(if grep -qF "$OUTSIDE:" <<< "$OUT" && ! grep -qF "$ROOT/alpha" <<< "$OUT"; then echo yes; else echo no; fi)"

    write_config on off off
    run --dry-run
    check "run=on with --dry-run: nothing changed" \
        "$(if grep -qF "dry run" <<< "$OUT" && sha256sum -c --quiet "$SCRATCH/sums" > /dev/null 2>&1; then echo yes; else echo no; fi)"
    run --repo "$OUTSIDE" --dry-run
    check "--repo: only that repository" \
        "$(if grep -qF "$OUTSIDE:" <<< "$OUT" && ! grep -qF "$ROOT/alpha" <<< "$OUT"; then echo yes; else echo no; fi)"

    write_config on off off 0
    run
    check "max_per_run=0: refused (2)" "$(same "$CODE" 2)"
    run --bogus
    check "an unknown argument: refused (2)" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_run
function test_run() {
    write_config on off on 10
    run --repo "$OUTSIDE"
    check "run=on, commit=on: exit 0" "$(same "$CODE" 0)"
    check "... the outside repository's summary is committed" \
        "$(same "$(git -C "$OUTSIDE" log -1 --format=%s)" "Session summaries for 1 conversation(s)")"
    check "... only the files it changed" \
        "$(same "$(git -C "$OUTSIDE" show --name-only --format= HEAD | sort | tr '\n' '|')" "llm-transcripts/dec-13-25.md|llm-transcripts/table-of-contents.md|")"
    check "... other work left uncommitted" "$(has_line "$(git -C "$OUTSIDE" status --porcelain)" "?? work.txt")"

    write_config on off off 1
    run
    check "max_per_run=1: one transcript done" "$(has_line "$OUT" "summarized dec-10-25.md")"
    check "... its table of contents entry" \
        "$(has_line "$(cat "$ROOT/alpha/llm-transcripts/table-of-contents.md")" "<!-- transcript-summary: conv-a -->")"
    check "... and its summary block" "$(same "$(sed -n 2p "$ROOT/alpha/llm-transcripts/dec-10-25.md")" "<!-- transcript-summary v1 -->")"
    check "... the rest left for later, said so" "$(has_line "$OUT" "1 more left for later runs (max_per_run=1)")"
    check "commit=off: nothing committed (alpha is not a repository anyway)" "$(lacks_line "$OUT" "committed")"

    write_config on on off 10
    run
    check "a transcript the model fails on: exit 1" "$(same "$CODE" 1)"
    check "... named" "$(has_line "$OUT" "failed to summarize dec-12-25.md")"
    check "export=on: the exporter ran for each repository with transcripts" \
        "$(same "$(sort "$SCRATCH/exporter-calls" 2>/dev/null | tr '\n' '|')" "--all $OUTSIDE|--all $ROOT/alpha|--all $ROOT/gamma|")"
    check "the summarized ones are not done again" \
        "$(if grep -qF "$OUTSIDE: 1 transcripts, 1 summarized, 0 to do" <<< "$OUT" \
            && grep -qF "$ROOT/alpha: 2 transcripts, 2 summarized, 0 to do" <<< "$OUT"; then echo yes; else echo no; fi)"
    check "a folder outside scope was never touched" \
        "$(same "$(sed -n 2p "$ELSEWHERE/llm-transcripts/dec-14-25.md")" "")"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "summarize-overseer.sh with a stand-in model, scratch in $SCRATCH"
    test_preview
    test_run
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
