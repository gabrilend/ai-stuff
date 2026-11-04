#!/bin/bash
# test-list-projects.sh - proves list-projects.sh lists projects by the
# shared rules, with its own features unchanged.
#
# In general terms: list-projects.sh no longer holds the rules for which
# folders are projects; it asks the shared library
# (scripts/libs/project-discovery.lua). This test builds a folder of
# would-be projects in RAM and checks that list-projects.sh agrees with the
# library exactly, that its output formats, inverse listing and external
# directories still work, and that it stops plainly when the library is
# missing.
#
# Usage: test-list-projects.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/list-projects.sh"
LIBRARY="$DIR/scripts/libs/project-discovery.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/list-projects-test"

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

# -- {{{ same
function same() {
    if [ "$1" = "$2" ]; then echo yes; else echo no; fi
}
# }}}

# -- {{{ has_line
function has_line() {
    if grep -qxF -- "$2" <<< "$1"; then echo yes; else echo no; fi
}
# }}}

# -- {{{ lacks_line
function lacks_line() {
    if grep -qxF -- "$2" <<< "$1"; then echo no; else echo yes; fi
}
# }}}

# -- {{{ lp
function lp() {
    # The tool, with its configuration pointed at the scratch folder so the
    # real external-directory list is never read.
    DELTA_CONFIG_DIR="$CONFIG" timeout 60 bash "$TOOL" "$@" 2> /dev/null
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    BASE="$SCRATCH/base"
    EXTERNAL="$SCRATCH/elsewhere"
    CONFIG="$SCRATCH/config"

    # Projects by points: src/ alone is 50; issues/ + README.md is 55.
    mkdir -p "$BASE/zeta/src" "$BASE/alpha/src" "$BASE/mid/issues"
    echo "# mid" > "$BASE/mid/README.md"
    # Not projects: 40 points (issues/ alone), and skipped names that would
    # otherwise score.
    mkdir -p "$BASE/low/issues" "$BASE/libs/src" "$BASE/backup/src" "$BASE/.storage_x/src"
    # The base folder itself scores as a project; it must not list itself.
    mkdir -p "$BASE/src"
    # A folder of projects elsewhere, named in the external configuration.
    mkdir -p "$EXTERNAL/outside/src" "$EXTERNAL/plain"
    mkdir -p "$CONFIG"
    printf '[external_directories]\nelsewhere=%s\n\n[settings]\ninclude_in_default_listings=true\n' \
        "$EXTERNAL" > "$CONFIG/external-projects.conf"
}
# }}}

# -- {{{ test_agreement
function test_agreement() {
    local listed library
    listed=$(lp --abs-paths --exclude-external "$BASE")
    library=$(luajit "$LIBRARY" scan "$BASE" | cut -f1)
    check "list-projects lists exactly what the shared library lists" "$(same "$listed" "$library")"
    check "projects come out sorted by name" \
        "$(same "$(lp --names --exclude-external "$BASE" | tr '\n' ' ')" "alpha mid zeta ")"
    check "a folder under the threshold is not a project" \
        "$(lacks_line "$(lp --names --exclude-external "$BASE")" "low")"
    check "skipped names are not projects even when they score" \
        "$(same "$(lp --names --exclude-external "$BASE" | grep -cE '^(libs|backup|\.storage_x)$')" "0")"
    check "the base folder never lists itself" \
        "$(lacks_line "$listed" "$BASE")"
}
# }}}

# -- {{{ test_formats
function test_formats() {
    check "--rel-paths gives paths relative to DIR" \
        "$(has_line "$(DIR="$SCRATCH" lp --rel-paths --exclude-external "$BASE")" "base/alpha")"
    check "--format csv has a header and one row per project" \
        "$(same "$(lp --format csv --exclude-external "$BASE" | wc -l | tr -d ' ')" "4")"
    check "--format json names each project" \
        "$(same "$(lp --format json --exclude-external "$BASE" | grep -c '"name"')" "3")"
}
# }}}

# -- {{{ test_inverse
function test_inverse() {
    local inverse
    inverse=$(lp --inverse --names "$BASE")
    check "--inverse lists the folder under the threshold" "$(has_line "$inverse" "low")"
    check "--inverse lists the skipped names" "$(has_line "$inverse" "libs")"
    check "--inverse lists the base's own src/" "$(has_line "$inverse" "src")"
    check "--inverse leaves the projects out" "$(lacks_line "$inverse" "alpha")"
    check "--inverse does not list the base folder" "$(lacks_line "$inverse" "base")"
}
# }}}

# -- {{{ test_external
function test_external() {
    local all
    all=$(DIR="$BASE" lp --names)
    check "the default listing includes external projects" "$(has_line "$all" "outside")"
    check "external folders are judged by the same rules" "$(lacks_line "$all" "plain")"
    check "--external-only lists only them" \
        "$(same "$(DIR="$BASE" lp --external-only --names)" "outside")"
}
# }}}

# -- {{{ test_library_missing
function test_library_missing() {
    PROJECT_DISCOVERY_SH="$SCRATCH/nowhere.sh" bash "$TOOL" --names "$BASE" > /dev/null 2>&1
    check "a missing shared library stops it with status 2" "$(same "$?" "2")"
    check "sourcing it defines the listing functions without running" \
        "$(same "$(bash -c "source '$TOOL' && type -t get_project_list_for_integration")" "function")"
}
# }}}

# -- {{{ main
function main() {
    if [ ! -f "$LIBRARY" ]; then
        echo "the shared library scripts/libs/project-discovery.lua is missing" >&2
        exit 2
    fi
    build_fixture
    echo "list-projects.sh"
    test_agreement
    test_formats
    test_inverse
    test_external
    test_library_missing
    rm -rf "$SCRATCH"
    echo ""
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
