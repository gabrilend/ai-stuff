#!/usr/bin/env bash
# phase-a-demo.sh - shows the Phase A tools at work on one project (issue A07).
#
# Runs each infrastructure tool against a project and prints what it says:
# the progress dashboard (A02), the issue validator (A04), the documentation
# index check (A05), the commit history by phase (A01) and the list of tests
# the test runner would run (A03). Everything is read-only: the commit history
# is written to a temporary folder, shown and removed; the test runner only
# lists; the index check reports. So the demo can be pointed at any project.
#
# Usage:
#   phase-a-demo.sh [PROJECT_DIR]   every tool (default: the scripts folder)
#   phase-a-demo.sh -I [PROJECT_DIR]
#                                   pick which tools to show
#   phase-a-demo.sh -h | --help

# {{{ local DIR
# The project shown when none is given; override with the first argument.
DIR="/home/ritz/programming/ai-stuff/scripts"
# Where the tools live: two folders up from this file (scripts/issues/completed/demos).
TOOLS="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../.." && pwd)"
# }}}

INTERACTIVE=false
case "${1:-}" in
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -I|--interactive) INTERACTIVE=true; shift ;;
esac
[ -n "${1:-}" ] && DIR="$1"
if [ ! -d "${DIR}/issues" ]; then
    echo "phase-a-demo: no issues/ folder in ${DIR}" >&2
    exit 2
fi

# {{{ banner / section
banner() {
    echo "═══════════════════════════════════════════════════════════"
    printf '%*s\n' $(( (59 + ${#1}) / 2 )) "$1"
    echo "═══════════════════════════════════════════════════════════"
}
section() {
    echo
    echo "$1"
    echo "───────────────────────────────────────────────────────────"
}
# }}}

# {{{ the five tools
show_dashboard() {
    section "1. Progress Dashboard (A02)"
    luajit "${TOOLS}/progress-dashboard.lua" "${DIR}" -t
}

show_validator() {
    section "2. Issue Validator (A04)"
    luajit "${TOOLS}/validate-issues" "${DIR}"
}

show_toc() {
    section "3. Documentation Index (A05)"
    if [ -d "${DIR}/docs" ]; then
        luajit "${TOOLS}/update-toc" "${DIR}"
    else
        echo "(no docs/ folder)"
    fi
}

show_history() {
    section "4. Commit History by Phase (A01)"
    local out
    out="$(mktemp -d "${TMPDIR:-/tmp}/phase-a-demo.XXXXXX")"
    if bash "${TOOLS}/git-history.sh" -d "${DIR}" -a -o "${out}" > /dev/null; then
        local file
        for file in "${out}"/phase-*-commits.md; do
            [ -e "${file}" ] || continue
            printf '%s: %s\n' "$(basename "${file}" -commits.md)" \
                "$(grep -m1 '^Total:' "${file}")"
            grep '^## \[' "${file}" | head -3 | sed 's/^## /    /'
        done
    else
        echo "(not a git repository, or no issues to read phases from)"
    fi
    rm -r -- "${out}"
}

show_runner() {
    section "5. Test Runner (A03): what it would run"
    bash "${TOOLS}/test-runner.sh" "${DIR}" --list
}
# }}}

# {{{ choose
# -I: which tools to show, by number; all of them by default.
choose() {
    local answer
    echo "1 dashboard  2 validator  3 documentation index  4 commit history  5 test runner" >&2
    read -r -p "Show which (e.g. 1 3 5, Enter for all): " answer
    echo "${answer:-1 2 3 4 5}"
}
# }}}

WHICH="1 2 3 4 5"
$INTERACTIVE && WHICH="$(choose)"

banner "PHASE A: INFRASTRUCTURE TOOLS DEMO"
echo "Project: ${DIR}"
for n in ${WHICH}; do
    case "${n}" in
        1) show_dashboard ;;
        2) show_validator ;;
        3) show_toc ;;
        4) show_history ;;
        5) show_runner ;;
    esac
done
echo
banner "DEMO COMPLETE"
exit 0
