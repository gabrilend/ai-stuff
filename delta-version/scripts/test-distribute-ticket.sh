#!/bin/bash
# test-distribute-ticket.sh - proves distribute-ticket.lua files one ticket
# template as a numbered issue in each chosen project, and can take it back.
#
# In general terms: the tool asks discover-projects which projects to file
# into, asks the shared issue-name reader for each one's phase and
# validate-issues for its next number, fills the template with the keyword
# engine, and writes the ticket. This test builds a small monorepo in a RAM
# scratch folder (two issue-tracked projects in different phases, one with no
# issues/ folder and one with its own keyword file) and checks the dry run,
# writing, the re-run guard, the ledger, undo and every refusal. The ledger
# is kept in the scratch folder, so the real assets/ file is never touched.
# Exercises issue 019.
#
# Usage: test-distribute-ticket.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/distribute-ticket.lua"
REAL_LEDGER="$DIR/delta-version/assets/ticket-distributions.tsv"
SCRATCH="$DIR/delta-version/tmp/shared-memory/distribute-ticket-test"

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
    if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi
}
# }}}

# -- {{{ lacks_line
function lacks_line() {
    if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi
}
# }}}

# -- {{{ is_file / no_file
function is_file() { if [ -f "$1" ]; then echo yes; else echo no; fi; }
function no_file() { if [ -e "$1" ]; then echo no; else echo yes; fi; }
# }}}

# -- {{{ run
function run() {
    # Runs the tool on the fixture with the scratch ledger; sets OUT and CODE.
    OUT=$(timeout 60 luajit "$TOOL" --dir="$FIXTURE" --ledger="$LEDGER" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    FIXTURE="$SCRATCH/monorepo"
    LEDGER="$SCRATCH/ledger.tsv"
    TEMPLATE="$SCRATCH/add-test-runner.md"
    NOTED="$SCRATCH/noted.md"

    local f="$FIXTURE"
    mkdir -p "$f/alpha/src" "$f/alpha/issues" "$f/alpha/config" \
             "$f/docsy/src" "$f/docsy/issues/completed" "$f/beta/src"

    # alpha: phase 1 is open, so its current phase is 1 and the next is 102.
    # It has its own keyword file, layered over delta-version's.
    echo "return 1" > "$f/alpha/src/a.lua"
    echo "# Issue 101: first" > "$f/alpha/issues/101-first.md"
    echo "# Issue 201: later" > "$f/alpha/issues/201-later.md"
    printf '[custom_keywords]\nowner_note=echo alpha-note\n' > "$f/alpha/config/ticket-keywords.conf"

    # docsy: phase 1 is done, phase 2 is open, so its current phase is 2.
    echo "return 2" > "$f/docsy/src/d.lua"
    echo "# Issue 101: done" > "$f/docsy/issues/completed/101-done.md"
    echo "# Issue 201: open" > "$f/docsy/issues/201-open.md"

    # beta: a project with no issues/ folder.
    echo "int b;" > "$f/beta/src/b.c"

    git -C "$f" init -q
    git -C "$f" add -A
    git -C "$f" -c user.name=t -c user.email=t@example.invalid commit -q -m "fixture"

    cat > "$TEMPLATE" <<'TEMPLATE'
# Add a Test Runner

Project: ][project_name[]
Ticket: ][ticket_id[]
TEMPLATE
    cat > "$NOTED" <<'TEMPLATE'
# Noted ticket

Note: ][owner_note[]
TEMPLATE
}
# }}}

# -- {{{ test_refusals
function test_refusals() {
    run "$TEMPLATE" --phase=1
    check "no targets: refused (every project is never the default)" "$(same "$CODE" 2)"
    run "$TEMPLATE" --projects=alpha
    check "no --phase: refused" "$(same "$CODE" 2)"
    run "$TEMPLATE" --phase=one --projects=alpha
    check "a --phase that is not a phase: refused" "$(same "$CODE" 2)"
    run "$TEMPLATE" --phase=1 --projects=alpha --slug="Bad Slug"
    check "a --slug with spaces or capitals: refused" "$(same "$CODE" 2)"
    run "$TEMPLATE" --phase=1 --projects=alpha --frobnicate
    check "an unknown option: refused" "$(same "$CODE" 2)"
    run "$SCRATCH/missing.md" --phase=1 --projects=alpha
    check "a template that cannot be read: refused" "$(same "$CODE" 2)"
    run "$TEMPLATE" --phase=1 --projects=nosuch
    check "filters that choose no project: refused" "$(same "$CODE" 2)"
    run "$TEMPLATE" --phase=1 --projects=alpha --show=alpha --write
    check "--show with --write: refused" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_dry_run
function test_dry_run() {
    run "$TEMPLATE" --phase=current --projects=alpha,beta,docsy
    check "dry run: alpha would get 102 in its current phase 1" \
        "$(has_line "$OUT" "would write issues/102-add-a-test-runner.md (phase 1)")"
    check "dry run: docsy would get 202 in its current phase 2" \
        "$(has_line "$OUT" "would write issues/202-add-a-test-runner.md (phase 2)")"
    check "dry run: a project with no issues/ is skipped and says why" \
        "$(has_line "$OUT" "no issues/ folder (add --create-issues")"
    check "dry run: a skipped project makes the exit status 1" "$(same "$CODE" 1)"
    check "dry run: nothing is written" "$(no_file "$FIXTURE/alpha/issues/102-add-a-test-runner.md")"
    check "dry run: no ledger is made" "$(no_file "$LEDGER")"

    run "$TEMPLATE" --phase=3 --projects=alpha
    check "--phase=N files into that phase (alpha: 301)" \
        "$(has_line "$OUT" "would write issues/301-add-a-test-runner.md (phase 3)")"
    check "every project ready: exit status 0" "$(same "$CODE" 0)"

    run "$TEMPLATE" --phase=1 --projects=alpha --slug=runner
    check "--slug names the file" "$(has_line "$OUT" "issues/102-runner.md")"

    run "$TEMPLATE" --phase=current --projects=beta --create-issues
    check "--create-issues: a project with no issues/ would start at 101" \
        "$(has_line "$OUT" "would write issues/101-add-a-test-runner.md (phase 1)")"
    check "--create-issues dry run: no folder is made" "$(no_file "$FIXTURE/beta/issues")"
}
# }}}

# -- {{{ test_show
function test_show() {
    run "$TEMPLATE" --phase=current --projects=alpha,docsy --show=docsy
    check "--show prints the ticket with the project's own facts" \
        "$(has_line "$OUT" "Project: docsy")"
    check "--show fills the ticket's own number" "$(has_line "$OUT" "Ticket: 202")"
    check "the ticket ends with the marker line" \
        "$(has_line "$OUT" "<!-- ticket-template: add-test-runner.md, distributed ")"
    run "$TEMPLATE" --phase=current --projects=alpha --show=docsy
    check "--show of a project the filters did not choose: refused" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_keywords
function test_keywords() {
    run "$NOTED" --phase=1 --projects=alpha --show=alpha
    check "a project's own keyword file is layered in (alpha-note)" \
        "$(has_line "$OUT" "Note: alpha-note")"
    run "$NOTED" --phase=1 --projects=docsy --write
    check "a keyword that cannot be filled: the project is skipped and named" \
        "$(has_line "$OUT" "keyword owner_note could not be filled")"
    check "... and nothing half-filled is written" \
        "$(same "$(ls "$FIXTURE/docsy/issues" | tr '\n' ' ')" "201-open.md completed ")"
    run "$NOTED" --phase=1 --projects=docsy --show=docsy --error-mode=placeholder
    check "--error-mode=placeholder keeps the unfilled keyword visible instead" \
        "$(same "$CODE" 0)"
}
# }}}

# -- {{{ test_write
function test_write() {
    local real_before
    real_before=$(stat -c %Y "$REAL_LEDGER" 2>/dev/null || echo none)

    run "$TEMPLATE" --phase=current --projects=alpha,docsy --write
    check "--write: exit status 0 when every project got it" "$(same "$CODE" 0)"
    check "--write: alpha's ticket is written" "$(is_file "$FIXTURE/alpha/issues/102-add-a-test-runner.md")"
    check "--write: docsy's ticket is written" "$(is_file "$FIXTURE/docsy/issues/202-add-a-test-runner.md")"
    check "the written ticket holds the project's name" \
        "$(has_line "$(cat "$FIXTURE/alpha/issues/102-add-a-test-runner.md")" "Project: alpha")"
    DIST=$(grep -o 'D-[0-9]\{8\}-[0-9]\{6\}' <<< "$OUT" | head -1)
    check "the run names its distribution id" "$(same "${DIST:0:2}" "D-")"

    local ledger
    ledger=$(cat "$LEDGER" 2>/dev/null)
    check "the ledger starts with its header" \
        "$(same "$(head -1 <<< "$ledger")" "$(printf 'date\tdistribution\ttemplate\tproject\tfile\tsha256\tstatus')")"
    check "the ledger has one row per written ticket" "$(same "$(grep -c "$DIST" <<< "$ledger")" 2)"
    local sum
    sum=$(sha256sum "$FIXTURE/alpha/issues/102-add-a-test-runner.md" | cut -d' ' -f1)
    check "the ledger row carries the ticket's checksum" \
        "$(has_line "$ledger" "$(printf 'alpha\tissues/102-add-a-test-runner.md\t%s\twritten' "$sum")")"
    check "the real ledger in assets/ was not touched" \
        "$(same "$(stat -c %Y "$REAL_LEDGER" 2>/dev/null || echo none)" "$real_before")"

    run "$TEMPLATE" --phase=current --projects=alpha,docsy --write
    check "a re-run skips projects that already have this template" \
        "$(has_line "$OUT" "already filed as issues/102-add-a-test-runner.md")"
    check "... and writes nothing new" "$(no_file "$FIXTURE/alpha/issues/103-add-a-test-runner.md")"
    run "$TEMPLATE" --phase=current --projects=alpha --again
    check "--again files it once more, at the next number" \
        "$(has_line "$OUT" "would write issues/103-add-a-test-runner.md")"

    run "$TEMPLATE" --phase=current --projects=beta --create-issues --write
    check "--create-issues --write gives beta issues/ and issues/completed/" \
        "$(if [ -d "$FIXTURE/beta/issues/completed" ]; then echo yes; else echo no; fi)"
    check "... and files the ticket there" "$(is_file "$FIXTURE/beta/issues/101-add-a-test-runner.md")"
}
# }}}

# -- {{{ test_undo
function test_undo() {
    run --undo=yesterday
    check "--undo with something that is not a distribution id: refused" "$(same "$CODE" 2)"
    run --undo=D-19990101-000000
    check "--undo of a distribution the ledger lacks: refused" "$(same "$CODE" 2)"
    run --undo="$DIST" "$TEMPLATE"
    check "--undo with a template: refused" "$(same "$CODE" 2)"

    echo "Someone's note." >> "$FIXTURE/docsy/issues/202-add-a-test-runner.md"
    run --undo="$DIST"
    check "--undo dry run: the unedited ticket would be removed" \
        "$(has_line "$OUT" "would remove issues/102-add-a-test-runner.md")"
    check "--undo dry run: the edited ticket is kept and named" \
        "$(has_line "$OUT" "kept issues/202-add-a-test-runner.md: edited since it was written")"
    check "--undo dry run: nothing is removed" "$(is_file "$FIXTURE/alpha/issues/102-add-a-test-runner.md")"
    check "--undo with a kept ticket: exit status 1" "$(same "$CODE" 1)"

    run --undo="$DIST" --write
    check "--undo --write removes the unedited ticket" \
        "$(no_file "$FIXTURE/alpha/issues/102-add-a-test-runner.md")"
    check "--undo --write leaves the edited one" "$(is_file "$FIXTURE/docsy/issues/202-add-a-test-runner.md")"
    check "the ledger records what was undone" \
        "$(has_line "$(cat "$LEDGER")" "$(printf 'alpha\tissues/102-add-a-test-runner.md')")"
    check "... as an undone row" "$(same "$(grep -c "$(printf '\tundone$')" "$LEDGER")" 1)"
    run --undo="$DIST" --write
    check "a second undo does not count the removed ticket again" \
        "$(lacks_line "$OUT" "102-add-a-test-runner.md")"
}
# }}}

# -- {{{ main
function main() {
    build_fixture
    echo "distribute-ticket.lua against a scratch monorepo in $SCRATCH"
    test_refusals
    test_dry_run
    test_show
    test_keywords
    test_write
    test_undo
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
