#!/bin/bash
# test-generate-readme-toc.sh - proves the README table of contents files
# issues under the phase the shared issue-name reader gives them.
#
# In general terms: a source file can carry a "phase N issue files" divider,
# and the generated README lists that phase's issues after it. Which phase an
# issue is in now comes from scripts/libs/issue-names.lua, the same reader
# the progress dashboard and the validator use. This test builds a project in
# a RAM scratch folder whose issues come in every shape and place the reader
# knows, generates the README with --dry-run, and checks each phase's list.
# Exercises the leftover named when issue 048 was closed.
#
# Usage: test-generate-readme-toc.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/generate-readme-toc.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/readme-toc-test"

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

# -- {{{ section
function section() {
    # The lines of one "#### Phase N Issues" block of the generated README.
    awk -v head="#### Phase $1 Issues" '
        $0 == head { inside = 1; next }
        inside && /^#### / { exit }
        inside && /^\| / && !/^\| ID / { print }
    ' <<< "$README"
}
# }}}

# -- {{{ holds
function holds() {
    # Answers yes when the phase's block holds a row with this text.
    if section "$1" | grep -qF -- "$2"; then echo yes; else echo no; fi
}
# }}}

# -- {{{ lacks
function lacks() {
    if section "$1" | grep -qF -- "$2"; then echo no; else echo yes; fi
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    PROJECT="$SCRATCH/project"

    local p="$PROJECT"
    mkdir -p "$p/src" "$p/issues/completed" "$p/issues/phase-1" "$p/issues/superseded"
    {
        echo "-- 001-main.lua - the story begins"
        echo "-- ============================= phase 0 issue files ============================="
        echo "-- ============================= phase 1 issue files ============================="
        echo "-- ============================= phase 10 issue files ============================"
    } > "$p/src/001-main.lua"

    echo "# Issue 001: First thing" > "$p/issues/001-first-thing.md"
    echo "# Issue 047: Later thing" > "$p/issues/047-later-thing.md"
    echo "# Issue 012: Done thing" > "$p/issues/completed/012-done-thing.md"
    # named as phase 0, filed by hand in phase-1/: the folder wins
    echo "# Issue 023: Moved thing" > "$p/issues/phase-1/023-moved-thing.md"
    echo "# Issue 101: Phase one thing" > "$p/issues/101-phase-one-thing.md"
    echo "# Issue 102a: A sub-issue" > "$p/issues/102a-a-sub-issue.md"
    echo "# Issue 102: Its parent" > "$p/issues/102-its-parent.md"
    # dashed shape: phase 10, issue 004
    echo "# Issue 10-004: Dashed thing" > "$p/issues/10-004-dashed-thing.md"
    # retired: set aside, not listed
    echo "# Issue 005: Old idea" > "$p/issues/superseded/005-old-idea.md"
    # not issues at all
    echo "progress" > "$p/issues/progress.md"
    echo "# Priorities" > "$p/issues/PRIORITY.md"
}
# }}}

# -- {{{ test_phases
function test_phases() {
    check "phase 0 lists an open issue" "$(holds 0 "[First thing]")"
    check "phase 0 lists a completed issue as completed" \
        "$(holds 0 "[Done thing](issues/completed/012-done-thing.md) | ✅ Completed")"
    check "a phase-1/ folder outranks the name's phase 0" "$(lacks 0 "Moved thing")"
    check "... and lists it under phase 1" "$(holds 1 "[Moved thing]")"
    check "phase 1 lists 101" "$(holds 1 "[Phase one thing]")"
    check "a dashed name is read (10-004 is phase 10)" "$(holds 10 "| 10-004 | [Dashed thing]")"
    check "the old rule's phase 0 does not take the dashed issue" "$(lacks 0 "Dashed thing")"
    check "a retired issue is not listed" "$(lacks 0 "Old idea")"
    check "progress and priority files are not issues" \
        "$(if grep -qE 'PRIORITY|progress\.md' <<< "$README"; then echo no; else echo yes; fi)"
    check "phase 0 rows are in issue order" \
        "$(if [ "$(section 0 | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')" = "001 012 047 " ]; then echo yes; else echo no; fi)"
    check "a parent comes before its sub-issue" \
        "$(if [ "$(section 1 | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')" = "101 102 102a 023 " ]; then echo yes; else echo no; fi)"
}
# }}}

# -- {{{ test_no_issues_dir
function test_no_issues_dir() {
    rm -rf "$PROJECT/issues"
    README=$(luajit "$TOOL" "$PROJECT" --dry-run 2> /dev/null)
    check "a project with no issues/ says each phase has none" \
        "$(if grep -qF "_No phase 0 issues found._" <<< "$README"; then echo yes; else echo no; fi)"
}
# }}}

# -- {{{ main
function main() {
    build_fixture
    README=$(luajit "$TOOL" "$PROJECT" --dry-run 2> /dev/null)
    echo "generate-readme-toc.lua"
    test_phases
    test_no_issues_dir
    rm -rf "$SCRATCH"
    echo ""
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
