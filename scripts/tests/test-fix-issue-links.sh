#!/usr/bin/env bash
#
# test-fix-issue-links.sh - proves fix-issue-links makes issue files agree about
# their dependencies without misplacing anything.
#
# In plain terms: builds a pretend project whose issues write their links in
# every shape found on disk (heading sections, bold labels, bullets, table rows,
# and no link field at all), each pair telling only half of a dependency. It
# runs the fixer, then asks validate-issues whether any one-sided link is left.
# A clean answer also proves the trickiest placement rule: a new "Blocks" line
# dropped inside a "## Dependencies" section would be read back as a dependency
# and the checker would complain. Nothing outside the scratch folder is touched.
#
# Usage:
#   tests/test-fix-issue-links.sh [scripts-dir]
#
# Exits 0 when every case passes, 1 otherwise, naming each failure.

DIR="/mnt/mtwo/programming/ai-stuff/scripts"
if [ $# -ge 1 ]; then
    DIR="$1"
fi

set -o nounset
set -o pipefail

FIXER="${DIR}/fix-issue-links"
CHECKER="${DIR}/validate-issues"

SCRATCH="$(mktemp -d /tmp/claude-1000/test-fix-issue-links.XXXXXX)"
PROJECT="${SCRATCH}/project"
ISSUES="${PROJECT}/issues"
mkdir -p "${ISSUES}/completed"

PASSED=0
FAILED=0

# {{{ pass / fail
pass() { PASSED=$((PASSED + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf '  FAIL  %s\n' "$1"; }
# }}}

# {{{ check
# check <description> <command...>: passes when the command succeeds.
check() {
    local description="$1"
    shift
    if "$@"; then pass "${description}"; else fail "${description}"; fi
}
# }}}

# {{{ write_issue
# write_issue <relative path> <link text>: an issue with the three required
# sections and the given link text (may be empty) after them.
write_issue() {
    local path="${ISSUES}/$1"
    printf '# %s\n\n## Current Behavior\n\nx\n\n## Intended Behavior\n\ny\n\n## Suggested Implementation Steps\n\n1. z\n%s' \
        "$1" "$2" > "${path}"
}
# }}}

# {{{ the pretend project
# A progress file tells the name reader that "1-001" is phase 1, issue 001.
printf '# Phase 1 progress\n' > "${ISSUES}/1-progress.md"

# heading neighbour: 1-001 must gain a Blocks section of its own, not a bullet
# inside its Dependencies section
write_issue 1-001-heading-neighbour.md $'\n## Dependencies\n\n- nothing yet\n\n## Notes\n\nprose\n'
write_issue 1-002-names-heading-one.md $'\n- **Blocked by**: 1-001\n'

# bold neighbour: 1-003 gains a bold Blocks line, with a blank line before it
write_issue 1-003-bold-neighbour.md $'\n**Blocked By**: nothing in this project\n'
write_issue 1-004-names-bold-one.md $'\n- **Dependencies**: 1-003\n'

# existing field in the right direction: the number is appended to it
write_issue 1-005-has-blocks.md $'\n- **Blocks**: 1-006 (a reason)\n'
write_issue 1-006-blocked.md $'\n- **Blocked by**: 1-005\n'
write_issue 1-007-also-blocked.md $'\n- **Blocked by**: 1-005\n'

# no link field at all: a section at the end of the file
write_issue 1-008-no-fields.md ''
write_issue 1-009-table.md $'\n| Field | Value |\n|---|---|\n| Blocked by | 1-008 |\n'

# the reverse direction into a heading section: 1-011 gains "- 1-010"
write_issue 1-010-blocks-heading-one.md $'\n- **Blocks**: 1-011\n'
write_issue 1-011-dependency-heading.md $'\n## Dependencies\n\n- 1-001\n'
# (1-011 also names 1-001, so 1-001 must list 1-011 too)

# a completed issue: left alone unless asked
write_issue completed/1-012-done.md ''
write_issue 1-013-blocked-by-done.md $'\n- **Blocked by**: 1-012\n'
# }}}

COMPLETED_BEFORE="$(md5sum "${ISSUES}/completed/1-012-done.md")"
TREE_BEFORE="$(cat "${ISSUES}"/*.md | md5sum)"

# {{{ preview changes nothing
"${FIXER}" "${PROJECT}" > "${SCRATCH}/preview.txt"
PREVIEW_STATUS=$?
check "preview exits 1 when there are edits to make" test "${PREVIEW_STATUS}" -eq 1
check "preview writes nothing" test "$(cat "${ISSUES}"/*.md | md5sum)" = "${TREE_BEFORE}"
# }}}

# {{{ write, then the checker finds no one-sided link in an open issue
"${FIXER}" "${PROJECT}" --write > "${SCRATCH}/write.txt"
"${CHECKER}" "${PROJECT}" > "${SCRATCH}/after.txt"
LEFT="$(grep -v '^completed/' "${SCRATCH}/after.txt" | grep -E 'does not (list|name)')"
check "no one-sided link left in an open issue" test -z "${LEFT}"
[ -n "${LEFT}" ] && printf '%s\n' "${LEFT}"
# }}}

# {{{ placement details
check "heading neighbour gained its own Blocks heading" \
    grep -q '^## Blocks$' "${ISSUES}/1-001-heading-neighbour.md"
check "bold Blocks line has a blank line before it" \
    grep -B1 '^\*\*Blocks\*\*: 1-004$' "${ISSUES}/1-003-bold-neighbour.md" -q
check "blank line really precedes the bold line" \
    test "$(grep -B1 '^\*\*Blocks\*\*: 1-004$' "${ISSUES}/1-003-bold-neighbour.md" | head -1)" = ""
check "existing Blocks field was appended to" \
    grep -q '^- \*\*Blocks\*\*: 1-006 (a reason), 1-007$' "${ISSUES}/1-005-has-blocks.md"
check "file with no field gained a section at the end" \
    test "$(tail -1 "${ISSUES}/1-008-no-fields.md")" = "- 1-009"
check "dependency heading section gained the blocker" \
    grep -q '^- 1-010$' "${ISSUES}/1-011-dependency-heading.md"
check "completed issue left untouched" \
    test "$(md5sum "${ISSUES}/completed/1-012-done.md")" = "${COMPLETED_BEFORE}"
# }}}

# {{{ a second run finds nothing to do
"${FIXER}" "${PROJECT}" > "${SCRATCH}/again.txt"
check "second run finds nothing to fix" grep -q 'no one-sided links to fix' "${SCRATCH}/again.txt"
# }}}

rm -rf "${SCRATCH}"
printf 'passed %d, failed %d\n' "${PASSED}" "${FAILED}"
[ "${FAILED}" -eq 0 ]
