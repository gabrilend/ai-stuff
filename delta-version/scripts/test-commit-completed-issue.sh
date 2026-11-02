#!/bin/bash
# test-commit-completed-issue.sh - proves commit-completed-issue.sh closes an
# issue in one commit or changes nothing.
#
# In general terms: builds small scratch repositories in RAM, each holding a
# project or two with issue files and progress files, and closes issues in
# them: by hand (no session) and as a Claude Code session (a made-up session
# id with its own line ledger, committing through the shared
# commit-own-changes). It checks that one commit holds exactly the move and
# the progress record; that the record lands in the right progress file and
# under the right heading; that someone else's staged or unstaged work stays
# out; and that a refusal -- a missing section, no progress file, a refusing
# commit hook -- leaves every file exactly as it was.
# Exercises the success criteria of issue 055.
#
# Usage: test-commit-completed-issue.sh [monorepo]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ -n "${1:-}" ] && DIR="$1"

TOOL="$DIR/delta-version/scripts/commit-completed-issue.sh"
SCRATCH="$DIR/delta-version/tmp/shared-memory/commit-completed-issue-test"
SESSION="cci-test-$$"
LEDGER_ROOT="/dev/shm/claude-own-edits"
REPO=""

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
    if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi
}
# }}}

# -- {{{ same
function same() {
    [ "$1" = "$2" ]
}
# }}}

# -- {{{ write_issue
function write_issue() {
    # An issue with all three required sections, titled as the house does.
    local path="$1" title="$2"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
# $title

## Current Behavior
Nothing.

## Intended Behavior
Something.

## Suggested Implementation Steps
1. Do it.
EOF
}
# }}}

# -- {{{ new_repo
function new_repo() {
    # A repository holding two projects:
    #   flat/    issues 001 and 002, issues/progress.md with a Completed list
    #   phased/  phase 1 and 2 issues, a progress file for each phase
    # plus notes.txt, a file outside any project.
    REPO="$SCRATCH/$1"
    rm -rf "$REPO"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b main
    git -C "$REPO" config user.name "test"
    git -C "$REPO" config user.email "test@example.invalid"

    write_issue "$REPO/flat/issues/001-first-thing.md" "Issue 001: The first thing"
    write_issue "$REPO/flat/issues/002-second-thing.md" "Issue 002: The second thing"
    mkdir -p "$REPO/flat/issues/completed"
    cat > "$REPO/flat/issues/progress.md" <<'EOF'
# Flat progress

## In Progress
- **Issue 001**: The first thing

## Completed Issues
- **Issue 000**: The setup (2026-01-01)

## Notes
Free text.
EOF

    write_issue "$REPO/phased/issues/101-a-start.md" "101 — a start"
    write_issue "$REPO/phased/issues/201-a-middle.md" "201 — a middle"
    write_issue "$REPO/phased/issues/202-another-middle.md" "202 — another middle"
    printf '# Phase 1\n\n## Completed Issues\n- 100 the ground — completed 2026-01-01\n' \
        > "$REPO/phased/issues/phase-1-progress.md"
    printf '# Phase 2\n\nNothing done yet.\n' > "$REPO/phased/issues/phase-2-progress.md"

    printf 'n1\nn2\n' > "$REPO/notes.txt"
    git -C "$REPO" add -A
    git -C "$REPO" commit -q -m base
    rm -rf "${LEDGER_ROOT:?}/$SESSION"
}
# }}}

# -- {{{ tree_sum
function tree_sum() {
    # Every file's content and modified time, and the staging area: if this
    # is unchanged, nothing was changed.
    (
        cd "$REPO" || exit
        find . -path ./.git -prune -o -type f -printf '%p %T@\n' | sort
        find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 sha256sum
        git ls-files -s
        git rev-parse HEAD
    ) | sha256sum
}
# }}}

# -- {{{ close_by_hand
function close_by_hand() {
    # Runs the tool with no session; output in OUT, status in STATUS.
    OUT=$(env -u CLAUDE_CODE_SESSION_ID "$TOOL" "$@" --dir "$DIR" 2>&1)
    STATUS=$?
}
# }}}

# -- {{{ close_as_session
function close_as_session() {
    OUT=$(CLAUDE_CODE_SESSION_ID="$SESSION" CLAUDE_SESSIONS_ROOT="$SCRATCH/sessions" \
          "$TOOL" "$@" --dir "$DIR" 2>&1)
    STATUS=$?
}
# }}}

# -- {{{ commits
function commits() {
    git -C "$REPO" rev-list --count HEAD
}
# }}}

# -- {{{ changed_paths
function changed_paths() {
    # The paths the last commit touches, with their change kind, one line.
    git -C "$REPO" show --format= --name-status --no-renames HEAD | sort | tr '\t\n' '  '
}
# }}}

# -- {{{ added_lines
function added_lines() {
    git -C "$REPO" show --format= -U0 HEAD -- "$1" | grep -E '^\+[^+]' | tr '\n' '|'
}
# }}}

# -- {{{ staged_not_committed
function staged_not_committed() {
    # notes.txt is staged with its third line, and the commit does not have it.
    same "$(git -C "$REPO" diff --cached --name-only)" "notes.txt" &&
        same "$(git -C "$REPO" show HEAD:notes.txt)" "$(printf 'n1\nn2')"
}
# }}}

# -- {{{ test_by_hand
function test_by_hand() {
    echo "closing by hand"
    new_repo by-hand
    # Someone else's work: a staged change and an unstaged one.
    printf 'n1\nn2\nstaged\n' > "$REPO/notes.txt"
    git -C "$REPO" add notes.txt
    printf 'x\n' >> "$REPO/flat/issues/002-second-thing.md"
    touch -d '2026-03-04 05:06:07' "$REPO/flat/issues/001-first-thing.md"
    local before_mtime
    before_mtime=$(stat -c %Y "$REPO/flat/issues/001-first-thing.md")

    close_by_hand "$REPO/flat/issues/001-first-thing.md"
    check "exit 0"                                       "$(yes_if same "$STATUS" 0)"
    check "one new commit"                               "$(yes_if same "$(commits)" 2)"
    check "it holds the move and the progress file, nothing else" \
        "$(yes_if same "$(changed_paths)" "A flat/issues/completed/001-first-thing.md D flat/issues/001-first-thing.md M flat/issues/progress.md ")"
    check "the record is the title under Completed Issues, in the list's style" \
        "$(yes_if same "$(added_lines flat/issues/progress.md)" "+- **Issue 001**: The first thing ($(date +%Y-%m-%d))|")"
    check "it lands at the end of that list, before the next heading" \
        "$(yes_if grep -qzP 'Issue 000\*\*: The setup \(2026-01-01\)\n- \*\*Issue 001\*\*: The first thing \([0-9-]+\)\n\n## Notes' "$REPO/flat/issues/progress.md")"
    check "the moved file keeps its modified date" \
        "$(yes_if same "$(stat -c %Y "$REPO/flat/issues/completed/001-first-thing.md")" "$before_mtime")"
    check "the commit subject is the issue's title" \
        "$(yes_if same "$(git -C "$REPO" log -1 --format=%s)" "The first thing")"
    check "someone's staged change is still staged, not committed" \
        "$(yes_if staged_not_committed)"
    check "someone's unstaged change is still unstaged" \
        "$(yes_if same "$(git -C "$REPO" status --porcelain -- flat/issues/002-second-thing.md)" " M flat/issues/002-second-thing.md")"
    check "the closed paths are clean" \
        "$(yes_if same "$(git -C "$REPO" status --porcelain -- flat/issues/completed flat/issues/progress.md flat/issues/001-first-thing.md)" "")"

    echo "a message file"
    printf 'Closing the second thing\n\nBecause it is done.\n' > "$SCRATCH/message"
    git -C "$REPO" checkout -q -- flat/issues/002-second-thing.md
    close_by_hand "$REPO/flat/issues/002-second-thing.md" "$SCRATCH/message"
    check "the given message is used" \
        "$(yes_if same "$(git -C "$REPO" log -1 --format=%B | head -1)" "Closing the second thing")"
}
# }}}

# -- {{{ test_manage_issues
function test_manage_issues() {
    echo "manage-issues.sh complete goes through the wrapper"
    new_repo manage
    OUT=$(env -u CLAUDE_CODE_SESSION_ID DIR="$DIR/delta-version" \
          "$DIR/delta-version/scripts/manage-issues.sh" complete "$REPO/flat/issues/001-first-thing.md" 2>&1)
    STATUS=$?
    check "exit 0"                                      "$(yes_if same "$STATUS" 0)"
    check "one commit holding the move and the record" \
        "$(yes_if same "$(changed_paths)" "A flat/issues/completed/001-first-thing.md D flat/issues/001-first-thing.md M flat/issues/progress.md ")"
}
# }}}

# -- {{{ test_phases
function test_phases() {
    echo "progress files by phase"
    new_repo phases
    close_by_hand "$REPO/phased/issues/201-a-middle.md"
    check "a phase 2 issue is recorded in phase-2-progress.md" \
        "$(yes_if same "$(changed_paths)" "A phased/issues/completed/201-a-middle.md D phased/issues/201-a-middle.md M phased/issues/phase-2-progress.md ")"
    check "which had no Completed heading, and gains one at its end" \
        "$(yes_if grep -qzP 'Nothing done yet\.\n\n## Completed Issues\n- 201 a middle — completed [0-9-]+\n$' "$REPO/phased/issues/phase-2-progress.md")"
    close_by_hand "$REPO/phased/issues/101-a-start.md"
    check "a phase 1 issue goes to phase-1-progress.md, in that list's style" \
        "$(yes_if same "$(added_lines phased/issues/phase-1-progress.md)" "+- 101 a start — completed $(date +%Y-%m-%d)|")"

    rm "$REPO/phased/issues/phase-2-progress.md"
    git -C "$REPO" commit -q -am "no phase 2 progress"
    local before
    before=$(tree_sum)
    close_by_hand "$REPO/phased/issues/202-another-middle.md"
    check "with no progress file at all, it refuses"    "$(yes_if same "$STATUS" 1)"
    check "and says why"                                "$(yes_if grep -q "no progress file" <<< "$OUT")"
    check "and nothing changed"                         "$(yes_if same "$(tree_sum)" "$before")"
}
# }}}

# -- {{{ test_refusals
function test_refusals() {
    echo "refusals change nothing"
    new_repo refusals
    printf '# Issue 002: no sections\n\nJust words.\n' > "$REPO/flat/issues/002-second-thing.md"
    git -C "$REPO" commit -q -am "a broken issue"
    local before
    before=$(tree_sum)
    close_by_hand "$REPO/flat/issues/002-second-thing.md"
    check "an issue missing its sections is refused"    "$(yes_if same "$STATUS" 1)"
    check "naming the missing sections"                 "$(yes_if grep -q "missing section: Intended Behavior" <<< "$OUT")"
    check "and nothing changed"                         "$(yes_if same "$(tree_sum)" "$before")"

    close_by_hand "$REPO/flat/issues/001-first-thing.md" --dry-run
    check "a dry run says what it would do"             "$(yes_if grep -q "would move" <<< "$OUT")"
    check "and changes nothing"                         "$(yes_if same "$(tree_sum)" "$before")"

    cp "$REPO/flat/issues/001-first-thing.md" "$REPO/flat/issues/completed/001-first-thing.md"
    git -C "$REPO" add -A && git -C "$REPO" commit -q -m "a copy already completed"
    before=$(tree_sum)
    close_by_hand "$REPO/flat/issues/completed/001-first-thing.md"
    check "an issue already in completed/ is refused"   "$(yes_if same "$STATUS" 1)"
    close_by_hand "$REPO/flat/issues/001-first-thing.md"
    check "so is one whose completed/ name is taken"    "$(yes_if grep -q "already exists" <<< "$OUT")"
    check "and nothing changed"                         "$(yes_if same "$(tree_sum)" "$before")"

    echo "a refusing commit hook puts everything back"
    new_repo hook
    printf '#!/bin/sh\necho "hook says no" >&2\nexit 1\n' > "$REPO/.git/hooks/pre-commit"
    chmod +x "$REPO/.git/hooks/pre-commit"
    printf 'n1\nn2\nstaged\n' > "$REPO/notes.txt"
    git -C "$REPO" add notes.txt
    before=$(tree_sum)
    close_by_hand "$REPO/flat/issues/001-first-thing.md"
    check "the closing fails"                           "$(yes_if same "$STATUS" 1)"
    check "no commit was made"                          "$(yes_if same "$(commits)" 1)"
    check "every file, date and staged entry is as it was" "$(yes_if same "$(tree_sum)" "$before")"
}
# }}}

# -- {{{ claim
function claim() {
    # One ledger record for the test session, in the ledger's own format.
    mkdir -p -m 700 "$LEDGER_ROOT/$SESSION"
    printf '%s\t%s\t%s\n' "$1" "$(realpath -m "$2")" "$3" >> "$LEDGER_ROOT/$SESSION/ledger.tsv"
}
# }}}

# -- {{{ test_session
function test_session() {
    echo "closing as a Claude Code session"
    new_repo session
    mkdir -p "$SCRATCH/sessions"
    # This session's own earlier work: one line it wrote in the issue's
    # project, claimed in its ledger.
    sed -i 's/^Free text\.$/Free text.\nA note this session wrote./' "$REPO/flat/issues/progress.md"
    claim + "$REPO/flat/issues/progress.md" "A note this session wrote."
    # Someone else's unclaimed lines: one in the progress file, one elsewhere.
    sed -i 's/^## In Progress$/## In Progress\n- someone else is working on 009/' "$REPO/flat/issues/progress.md"
    printf 'n1\nn2\nforeign\n' > "$REPO/notes.txt"

    close_as_session "$REPO/flat/issues/001-first-thing.md"
    check "exit 0"                                      "$(yes_if same "$STATUS" 0)"
    check "one new commit"                              "$(yes_if same "$(commits)" 2)"
    check "it holds the move and the progress file" \
        "$(yes_if same "$(changed_paths)" "A flat/issues/completed/001-first-thing.md D flat/issues/001-first-thing.md M flat/issues/progress.md ")"
    local added
    added=$(added_lines flat/issues/progress.md)
    check "the record is committed" \
        "$(yes_if grep -q "Issue 001\*\*: The first thing" <<< "$added")"
    check "so is the session's own earlier line" \
        "$(yes_if grep -q "A note this session wrote" <<< "$added")"
    check "someone else's line in the progress file stays out" \
        "$(yes_if same "$(grep -c "someone else" <<< "$added")" 0)"
    check "and is still on disk"                        "$(yes_if grep -q "someone else is working on 009" "$REPO/flat/issues/progress.md")"
    check "someone else's file stays out"               "$(yes_if same "$(git -C "$REPO" show HEAD:notes.txt)" "$(printf 'n1\nn2')")"
    check "the move was claimed in the ledger" \
        "$(yes_if grep -q "^W	.*completed/001-first-thing.md" "$LEDGER_ROOT/$SESSION/ledger.tsv")"

    echo "a session's closing that commit-own-changes refuses puts everything back"
    new_repo session-detached
    # commit-own-changes will not commit on a detached HEAD.
    git -C "$REPO" checkout -q --detach
    local before
    before=$(tree_sum)
    close_as_session "$REPO/flat/issues/001-first-thing.md"
    check "the closing fails"                           "$(yes_if same "$STATUS" 1)"
    check "no commit was made"                          "$(yes_if same "$(commits)" 1)"
    check "every file, date and staged entry is as it was" "$(yes_if same "$(tree_sum)" "$before")"
}
# }}}

source "$DIR/scripts/libs/ensure-ram-tiers"
ensure_ram_tiers "$DIR/delta-version" || exit 1
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"

test_by_hand
test_manage_issues
test_phases
test_refusals
test_session

rm -rf "$SCRATCH" "${LEDGER_ROOT:?}/$SESSION"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
