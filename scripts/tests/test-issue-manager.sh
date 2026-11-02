#!/usr/bin/env bash
#
# test-issue-manager.sh
#
# Proves that libs/issue-manager.lua and its bash face number, list, write,
# complete, check and search issue files the way the house does, and refuse
# the moves that would damage a project's issues (issue 012).
#
# In general terms: it builds a small project of issue files in a scratch
# folder -- compact, dashed and lettered names, a completed one, a retired
# one -- then drives every operation through the bash functions and checks
# the files on disk afterwards.
#
# Usage: test-issue-manager.sh [scripts-directory]

set -uo pipefail

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
P="$(mktemp -d "${TMPDIR:-/tmp}/test-issue-manager-XXXXXX")"
trap 'rm -rf "${P}"' EXIT

failures=0
checked=0

# {{{ check()
check() {
    local description="$1" result="$2"
    checked=$((checked + 1))
    if [ "${result}" = "yes" ]; then
        printf '  ok       %s\n' "${description}"
    else
        printf '  FAILED   %s\n' "${description}"
        failures=$((failures + 1))
    fi
}
# }}}

# {{{ same()
same() {
    if [ "$1" = "$2" ]; then printf yes; else printf 'no\n    got:  %s\n    want: %s' "$1" "$2"; fi
}
# }}}

# {{{ the project
FULL=$'# Issue\n\n## Current Behavior\nx\n## Intended Behavior\ny\n## Suggested Implementation Steps\nz\n'
mkdir -p "${P}/issues/completed" "${P}/issues/superseded"
printf '%s' "${FULL}" > "${P}/issues/301-first-thing.md"
printf '%s' "${FULL}" > "${P}/issues/302-second-thing.md"
printf '%s' "${FULL}" > "${P}/issues/completed/303-done-thing.md"
printf '%s' "${FULL}" > "${P}/issues/superseded/309-abandoned-plan.md"
printf '%s' "${FULL}" > "${P}/issues/A04-lettered-tool.md"
printf '# no sections, but the word zebra\n' > "${P}/issues/304-half-written.md"
: > "${P}/issues/phase-3-progress.md"
# }}}

# shellcheck source=/dev/null
source "${DIR}/libs/issue-manager.sh"

printf '\nStarting\n'
issue_init "${P}/nowhere" 2> /dev/null; status=$?
check "a project with no issues/ is refused" "$( [ ${status} != 0 ] && echo yes || echo no)"
issue_init "${P}"; status=$?
check "a project with issues/ is taken" "$( [ ${status} = 0 ] && echo yes || echo no)"

printf '\nNumbering\n'
check "the next id follows the highest, retired ones included" "$(same "$(issue_get_next_id 3)" 310)"
check "a lettered phase keeps its shape" "$(same "$(issue_get_next_id A)" A05)"
check "a phase with no issues starts at 1 in the project's shape" "$(same "$(issue_get_next_id 5)" 501)"

printf '\nListing\n'
check "everything, sorted by phase then id" "$(same "$(issue_list | cut -f1 | tr '\n' ' ')" \
    "301 302 303 304 309 A04 ")"
check "open issues of phase 3" "$(same "$(issue_list open 3 | cut -f1 | tr '\n' ' ')" "301 302 304 ")"
check "completed issues, with their path" "$(same "$(issue_list completed)" \
    "$(printf '303\t3\tcompleted\tcompleted/303-done-thing.md')")"
check "a path by id" "$(same "$(issue_path A04)" "${P}/issues/A04-lettered-tool.md")"

printf '\nWriting a new issue\n'
id="$(issue_get_next_id 3)"
path="$(issue_create "${id}" "new-feature" < /dev/null)"; status=$?
check "an empty input gets the template, never an empty file" \
    "$( [ ${status} = 0 ] && [ "${path}" = "${P}/issues/310-new-feature.md" ] \
        && grep -q '^# Issue 310: New feature$' "${path}" && echo yes || echo no)"
check "the template passes validate-issues" "$(issue_validate 310 > /dev/null && echo yes || echo no)"
path="$(issue_create 311 "given-body" <<'BODY'
## Current Behavior
the body I wrote
## Intended Behavior
b
## Suggested Implementation Steps
c
BODY
)"
check "a body on standard input is written as given" \
    "$(grep -q 'the body I wrote' "${path}" && ! grep -q '^# Issue' "${path}" && echo yes || echo no)"
check "the numbering moves on" "$(same "$(issue_get_next_id 3)" 312)"
path="$(issue_create 302a "a-sub-issue" < /dev/null)"
check "a sub-issue id is accepted" "$( [ -f "${P}/issues/302a-a-sub-issue.md" ] && echo yes || echo no)"

err="$(issue_create 301 "again" < /dev/null 2>&1)"; status=$?
check "an id already claimed is refused, naming the file" \
    "$( [ ${status} = 1 ] && grep -q '301-first-thing.md' <<< "${err}" && echo yes || echo no)"
issue_create 309 "reuse-a-retired-id" < /dev/null > /dev/null 2>&1; status=$?
check "a retired file's id may be used again" "$( [ ${status} = 0 ] && echo yes || echo no)"
issue_create 320 "Bad_Name" < /dev/null > /dev/null 2>&1; status=$?
check "a name that is not lower-case words joined by dashes is refused" "$( [ ${status} = 1 ] && echo yes || echo no)"
issue_create "x1" "fine-name" < /dev/null > /dev/null 2>&1; status=$?
check "something that is not an issue id is refused" "$( [ ${status} = 1 ] && echo yes || echo no)"

printf '\nChecking\n'
out="$(issue_validate 304)"; status=$?
check "an issue missing its sections fails, saying which" \
    "$( [ ${status} = 1 ] && grep -q 'missing section: Intended Behavior' <<< "${out}" && echo yes || echo no)"
check "a well-formed one passes" "$(issue_validate 301 > /dev/null && echo yes || echo no)"

printf '\nCompleting\n'
path="$(issue_complete 301)"; status=$?
check "an open issue moves into completed/, keeping its name" \
    "$( [ ${status} = 0 ] && [ -f "${P}/issues/completed/301-first-thing.md" ] \
        && [ ! -e "${P}/issues/301-first-thing.md" ] && echo yes || echo no)"
check "...and lists as completed" "$(same "$(issue_list completed | cut -f1 | tr '\n' ' ')" "301 303 ")"
issue_complete 301 > /dev/null 2>&1; status=$?
check "completing it twice is refused" "$( [ ${status} = 1 ] && echo yes || echo no)"
issue_complete 399 > /dev/null 2>&1; status=$?
check "completing an issue that does not exist is refused" "$( [ ${status} = 1 ] && echo yes || echo no)"
printf '%s' "${FULL}" > "${P}/issues/completed/302-second-thing.md"
before="$(cat "${P}/issues/302-second-thing.md")"
err="$(issue_complete 302 2>&1)"; status=$?
check "two files claiming one id stop the move, and both stay" \
    "$( [ ${status} = 1 ] && grep -q 'more than one file' <<< "${err}" \
        && [ "$(cat "${P}/issues/302-second-thing.md")" = "${before}" ] && echo yes || echo no)"
rm "${P}/issues/completed/302-second-thing.md"

printf '\nSearching\n'
check "finds a line by its words, case ignored, with file and line number" "$(same \
    "$(issue_search ZEBRA no)" "304-half-written.md:1: # no sections, but the word zebra")"
check "every word must be on the line" "$(same "$(issue_search zebra giraffe)" "")"

printf '\nThe numbering agrees with validate-issues\n'
check "validate-issues --next and issue_get_next_id give the same id" "$(same \
    "$(luajit "${DIR}/validate-issues" "${P}" --next 3)" "$(issue_get_next_id 3)")"

printf '\n%d checks, %d failures\n' "${checked}" "${failures}"
[ "${failures}" -eq 0 ]
