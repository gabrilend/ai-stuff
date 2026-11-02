#!/bin/bash
# test-check-utilities.sh - proves the project audits in check-utilities.sh
# keep their promises.
#
# In general terms: builds a pretend monorepo in RAM -- a delta-version folder
# whose checker is the real one (linked, not copied), the real shared
# validators beside it, a handful of small projects each wrong in one way, and
# a pretend store of Claude Code conversation records -- then runs the checker
# against it and checks what it reports: issue files are judged by the shared
# validator and every finding counted; a project with conversations on record
# but no exported transcripts is named; a misfiled transcript is named; quiet
# projects stay quiet; the retired --tui-audit flag is refused; and
# --all-projects scans the monorepo the checker lives in.
# Exercises the success criteria of issue 042a.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ -n "${1:-}" ] && DIR="$1"

REAL_SCRIPTS="$DIR/delta-version/scripts"
SCRATCH="$DIR/delta-version/tmp/shared-memory/check-utilities-test"
ROOT="$SCRATCH/root"
ALIAS="$SCRATCH/alias"
SESSIONS="$SCRATCH/sessions"
CHECKER="$ROOT/delta-version/scripts/check-utilities.sh"

# Three conversation ids: one on record for the good project, one whose record
# says "bad-issues" but whose export sits in "misfiled", and one on record for
# the projects that never exported anything.
ID_GOOD="11111111-1111-4111-8111-111111111111"
ID_ELSEWHERE="22222222-2222-4222-8222-222222222222"
ID_UNEXPORTED="33333333-3333-4333-8333-333333333333"

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

# -- {{{ yes_if
function yes_if() {
    # "yes" when the command given succeeds, "no" otherwise.
    if "$@"; then echo yes; else echo no; fi
}
# }}}

# -- {{{ key_for
function key_for() {
    # The record-folder name Claude Code uses for a project's folder, taken
    # from its real path: the scratch space is itself reached through the
    # tmp/ symlink, so this also proves the checker resolves symlinks.
    local real
    real="$(cd "$1" && pwd -P)"
    printf '%s' "$real" | sed 's|[^A-Za-z0-9-]|-|g'
}
# }}}

# -- {{{ write_issue
function write_issue() {
    # An issue file with all three required sections.
    cat > "$1" <<'EOF'
# Issue: a thing

## Current Behavior
Nothing.

## Intended Behavior
Something.

## Suggested Implementation Steps
1. Do it.
EOF
}
# }}}

# -- {{{ write_transcript
function write_transcript() {
    # An export whose first line carries its conversation id, as the
    # exporter writes it.
    printf '# Conversation Summary: %s\n\nhello\n' "$2" > "$1"
}
# }}}

# -- {{{ make_project
function make_project() {
    # A folder list-projects.sh recognises as a project (issues/ + README).
    mkdir -p "$ROOT/$1/issues/completed"
    printf '# %s\n' "$1" > "$ROOT/$1/README.md"
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$ROOT/delta-version/scripts" "$ROOT/scripts" "$SESSIONS"

    # The real checker and project lister, linked so the test runs the very
    # file under test; the real shared tools beside them.
    ln -s "$REAL_SCRIPTS/check-utilities.sh" "$ROOT/delta-version/scripts/check-utilities.sh"
    ln -s "$REAL_SCRIPTS/list-projects.sh"   "$ROOT/delta-version/scripts/list-projects.sh"
    ln -s "$DIR/scripts/validate-issues"     "$ROOT/scripts/validate-issues"
    ln -s "$DIR/scripts/check-transcripts-are-filed-right" \
          "$ROOT/scripts/check-transcripts-are-filed-right"

    # good: sound issues, a conversation on record, exported and filed right.
    make_project good
    write_issue "$ROOT/good/issues/001-a-thing.md"
    mkdir -p "$ROOT/good/llm-transcripts" "$SESSIONS/$(key_for "$ROOT/good")"
    write_transcript "$ROOT/good/llm-transcripts/jan-1-26.md" "$ID_GOOD"
    : > "$SESSIONS/$(key_for "$ROOT/good")/$ID_GOOD.jsonl"

    # bad-issues: one issue missing its sections, one with a bad name, and
    # twelve duplicate ids to push the report past its ten-line limit.
    make_project bad-issues
    printf '# Issue 001\n\nJust words.\n' > "$ROOT/bad-issues/issues/001-no-sections.md"
    write_issue "$ROOT/bad-issues/issues/002-Bad_Name.md"
    local n
    for n in 03 04 05 06 07 08 09 10 11 12 13 14; do
        write_issue "$ROOT/bad-issues/issues/0$n-first.md"
        write_issue "$ROOT/bad-issues/issues/completed/0$n-second.md"
    done
    mkdir -p "$SESSIONS/$(key_for "$ROOT/bad-issues")"
    : > "$SESSIONS/$(key_for "$ROOT/bad-issues")/$ID_ELSEWHERE.jsonl"
    mkdir -p "$ROOT/bad-issues/llm-transcripts"
    write_transcript "$ROOT/bad-issues/llm-transcripts/feb-1-26.md" "$ID_ELSEWHERE"

    # misfiled: holds an export whose conversation is on record elsewhere.
    make_project misfiled
    write_issue "$ROOT/misfiled/issues/001-a-thing.md"
    mkdir -p "$ROOT/misfiled/llm-transcripts"
    write_transcript "$ROOT/misfiled/llm-transcripts/mar-1-26.md" "$ID_ELSEWHERE"

    # unexported: a conversation on record, no llm-transcripts/ at all.
    make_project unexported
    write_issue "$ROOT/unexported/issues/001-a-thing.md"
    mkdir -p "$SESSIONS/$(key_for "$ROOT/unexported")"
    : > "$SESSIONS/$(key_for "$ROOT/unexported")/$ID_UNEXPORTED.jsonl"

    # empty-export: a conversation on record, llm-transcripts/ left empty.
    make_project empty-export
    write_issue "$ROOT/empty-export/issues/001-a-thing.md"
    mkdir -p "$ROOT/empty-export/llm-transcripts" "$SESSIONS/$(key_for "$ROOT/empty-export")"
    : > "$SESSIONS/$(key_for "$ROOT/empty-export")/$ID_UNEXPORTED.jsonl"

    # quiet: no conversations and no transcripts; nothing to say.
    make_project quiet
    write_issue "$ROOT/quiet/issues/001-a-thing.md"

    # no-issues: no issues/ folder; noted, not counted.
    mkdir -p "$ROOT/no-issues/src"
    printf '# no-issues\n' > "$ROOT/no-issues/README.md"

    # The whole monorepo reached through a second path, as /home/ritz/... and
    # /mnt/mtwo/... both reach the real one. Records stay keyed by the real
    # path.
    ln -s "$ROOT" "$ALIAS"
}
# }}}

# -- {{{ run_checker
function run_checker() {
    # Runs the checker with colours stripped; leaves the output in OUT and
    # the exit status in STATUS.
    local checker="$1"; shift
    OUT=$(CLAUDE_SESSIONS_ROOT="$SESSIONS" "$checker" "$@" 2>&1)
    STATUS=$?
    OUT=$(printf '%s\n' "$OUT" | sed 's/\x1b\[[0-9;]*m//g')
}
# }}}

# -- {{{ found_count
function found_count() {
    printf '%s\n' "$OUT" | sed -n 's/^ *Issues found: *//p'
}
# }}}

# -- {{{ has
function has() {
    printf '%s\n' "$OUT" | grep -qF -- "$1"
}
# }}}

# -- {{{ lacks
function lacks() {
    ! has "$1"
}
# }}}

# -- {{{ lacks_placeholder
function lacks_placeholder() {
    ! grep -q "not yet implemented" "$REAL_SCRIPTS/check-utilities.sh"
}
# }}}

# -- {{{ run_tests
function run_tests() {
    echo "issue standards"
    run_checker "$CHECKER" -q --issue-standards good quiet
    check "sound issue files give no findings"         "$(yes_if [ "$(found_count)" = 0 ])"
    check "and exit 0"                                 "$(yes_if [ "$STATUS" = 0 ])"

    run_checker "$CHECKER" --issue-standards bad-issues
    check "missing sections are reported"              "$(yes_if has "bad-issues: 001-no-sections.md: missing section")"
    check "a bad name is reported"                     "$(yes_if has "002-Bad_Name")"
    check "every finding is counted (2 + 12 ids)"      "$(yes_if [ "$(found_count)" -ge 14 ])"
    check "the report stops at ten lines and says so"  "$(yes_if has "more")"
    check "and points at the validator"                "$(yes_if has "see: $ROOT/scripts/validate-issues")"
    check "findings remaining exit 1"                  "$(yes_if [ "$STATUS" = 1 ])"

    run_checker "$CHECKER" --issue-standards no-issues
    check "no issues/ folder is noted"                 "$(yes_if has "no-issues: no issues/ folder")"
    check "and not counted"                            "$(yes_if [ "$(found_count)" = 0 ])"

    echo "transcripts"
    run_checker "$CHECKER" -q --transcripts good quiet
    check "exported and filed right gives no findings" "$(yes_if [ "$(found_count)" = 0 ])"

    run_checker "$CHECKER" --transcripts unexported
    check "conversations with no folder are named"     "$(yes_if has "unexported: 1 conversation(s) on record but no llm-transcripts/ folder")"
    check "and the exporter is suggested"              "$(yes_if has "claude-conversation-exporter.sh")"

    run_checker "$CHECKER" --transcripts empty-export
    check "an empty folder is named"                   "$(yes_if has "llm-transcripts/ is empty")"

    run_checker "$CHECKER" --transcripts misfiled
    check "a misfiled export is named"                 "$(yes_if has "misfiled: misfiled transcript mar-1-26.md")"
    check "and counted once"                           "$(yes_if [ "$(found_count)" = 1 ])"

    run_checker "$CHECKER" -q --transcripts unexported empty-export misfiled
    check "three projects, three findings"             "$(yes_if [ "$(found_count)" = 3 ])"
    check "nothing was created or moved"               "$(yes_if [ ! -e "$ROOT/unexported/llm-transcripts" ] && [ -f "$ROOT/misfiled/llm-transcripts/mar-1-26.md" ])"

    run_checker "$ALIAS/delta-version/scripts/check-utilities.sh" -q --transcripts unexported
    check "records are found through a symlinked root" "$(yes_if [ "$(found_count)" = 1 ])"

    OUT=$(CLAUDE_SESSIONS_ROOT="$SCRATCH/nowhere" "$CHECKER" --transcripts unexported 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    check "no record store means skipped, not failed"  "$(yes_if has "transcript check skipped")"

    echo "flags"
    run_checker "$CHECKER" --tui-audit good
    check "--tui-audit is refused"                     "$(yes_if has "unknown option --tui-audit")"
    check "with exit 1"                                "$(yes_if [ "$STATUS" = 1 ])"
    run_checker "$CHECKER" --help
    check "--tui-audit is gone from the help"          "$(yes_if lacks "tui-audit")"
    check "and the placeholder is gone"                "$(yes_if lacks_placeholder)"

    echo "all projects"
    run_checker "$CHECKER" --all-projects --issue-standards
    check "--all-projects scans the checker's own monorepo" \
        "$(yes_if has "Checking: bad-issues")"
    check "and finds every fixture project" \
        "$(yes_if has "Checking: good" && has "Checking: misfiled" && has "Checking: unexported")"
}
# }}}

build_fixture
run_tests
rm -rf "$SCRATCH"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
