#!/usr/bin/env bash
# script-help.test.sh -- every script answers --help, and answering does no work.
#
# Two checks for each script in scripts/, the project folder's own scripts,
# and the programs in src/ that can be run directly (they start with "#!";
# src/main.lua once ran the whole pipeline when asked for help) -- sourced
# libraries, tests and retired "-done" files left out:
#   1. it can answer: it calls libs/script-help (or handles --help itself);
#   2. only then, it is run with --help: it must print its header (three
#      lines or more) and exit 0 within 15 seconds.
# A script without a help call is reported and never run, so a new script
# cannot start its work here by accident (asking deploy-to-neocities for
# help once started hashing the site and listing the live one).
#
# Usage:  scripts/script-help.test.sh [--dir PATH]

# The project folder: --dir PATH, or the path below; a stray word on the
# command line stops the script (libs/project-dir.sh, Issue 10-076).
source "$(dirname "$(readlink -f "$0")")/../libs/project-dir.sh"
project_dir_read "/mnt/mtwo/programming/ai-stuff/neocities-modernization" "" "$@"
passed=0
failed=0

# {{{ check
check() {
    local name="$1" ok="$2" detail="$3"
    if [ "$ok" = 1 ]; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        echo "  FAIL - $name: $detail"
    fi
}
# }}}

for f in "$DIR"/scripts/* "$DIR"/*.sh "$DIR"/src/*.lua; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    case "$name" in
        *.md|*.test.sh|*-done|*.test.lua|*-test.lua) continue ;;
    esac
    head -c 2 "$f" | grep -q '#!' || continue
    head -c 600 "$f" | grep -q "sourced library" && continue

    if grep -q "script-help\|script_help" "$f" || grep -q -- '--help' "$f"; then
        check "$name can answer --help" 1 ""
        case "$(head -1 "$f")" in
            *lua*) out="$(timeout 15 luajit "$f" --help 2>&1)"; status=$? ;;
            *)     out="$(timeout 15 bash "$f" --help 2>&1)"; status=$? ;;
        esac
        lines="$(printf '%s\n' "$out" | wc -l)"
        if [ "$status" -eq 0 ] && [ "$lines" -ge 3 ]; then
            check "$name --help" 1 ""
        else
            check "$name --help" 0 "exit $status, $lines lines: $(printf '%s' "$out" | head -1)"
        fi
    else
        check "$name can answer --help" 0 "no help call (add the two lines from libs/script-help.lua or .sh)"
    fi
done

echo "passed $passed, failed $failed"
[ "$failed" -eq 0 ]
