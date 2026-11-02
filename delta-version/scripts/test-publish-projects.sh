#!/bin/bash
# test-publish-projects.sh - proves publish-projects.sh pushes only what the
# configuration lists, and only when pushing is turned on.
#
# In general terms: this builds a pretend monorepo and a pretend extra root in
# a RAM folder. The extra root holds projects in every situation: listed with
# commits waiting, not listed, listed "off", listed but with no upstream,
# listed but not a git repository, and listed but living inside another
# repository. Each git project's "remote" is a bare repository in the same
# folder, so a push can be checked by reading the bare repository's branch.
# Nothing leaves the RAM folder. It also checks the Public column that
# reconstruct-history.sh --scan now shows. Exercises issue 039.
#
# Usage: test-publish-projects.sh [--dir MONOREPO]   (KEEP=1 keeps the folder)

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

SCRATCH="$DIR/delta-version/tmp/shared-memory/publish-projects-test"
REAL_SCRIPTS="$DIR/delta-version/scripts"

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

# -- {{{ g
function g() {
    # git with a fixed identity, so commits work on any machine.
    git -c user.name=Tester -c user.email=tester@example.com -c init.defaultBranch=main "$@"
}
# }}}

# -- {{{ make_project
function make_project() {
    # A folder list-projects.sh accepts as a project (it has src/).
    mkdir -p "$1/src"
    echo "print(1)" > "$1/src/main.lua"
}
# }}}

# -- {{{ make_tracked_project
function make_tracked_project() {
    # A project that is its own repository, tracking main on a bare remote,
    # with WAITING commits made after the remote was last updated.
    local project="$1" waiting="$2" bare="$SCRATCH/remotes/$(basename "$1").git" i
    make_project "$project"
    g init -q "$project"
    g -C "$project" add -A
    g -C "$project" commit -q -m "first"
    g init -q --bare "$bare"
    g -C "$project" remote add origin "$bare"
    g -C "$project" push -q -u origin main 2> /dev/null
    for ((i = 1; i <= waiting; i++)); do
        echo "change $i" >> "$project/src/main.lua"
        g -C "$project" commit -q -am "change $i"
    done
}
# }}}

# -- {{{ remote_head
function remote_head() { git --git-dir="$SCRATCH/remotes/$1.git" rev-parse main 2> /dev/null; }
function local_head() { git -C "$FAR/$1" rev-parse HEAD; }
# }}}

# -- {{{ write_config
function write_config() {
    # The fixture's external-projects.conf; $1 is push's value.
    cat > "$MONO/delta-version/config/external-projects.conf" << EOF
[external_directories]
far=$FAR
busy=$BUSY

[publishable]
far/listed=on
far/off-listed=off
far/no-upstream=on
far/plain=yes
busy/inner=on

[publishing]
push=$1
EOF
}
# }}}

# -- {{{ run_tool
function run_tool() {
    OUT=$(DIR="$MONO" bash "$MONO/delta-version/scripts/publish-projects.sh" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH/remotes"
    SCRATCH=$(realpath "$SCRATCH")
    MONO="$SCRATCH/mono"
    FAR="$SCRATCH/far"
    BUSY="$SCRATCH/busy"
    # The pretend monorepo borrows the real scripts through a symlink in the
    # RAM folder, so they read the fixture's config beside them.
    mkdir -p "$MONO/delta-version/config"
    ln -s "$REAL_SCRIPTS" "$MONO/delta-version/scripts"
    make_project "$MONO/home-project"
    make_tracked_project "$FAR/listed" 2
    make_tracked_project "$FAR/unlisted" 1
    make_tracked_project "$FAR/off-listed" 1
    make_project "$FAR/no-upstream"
    g init -q "$FAR/no-upstream"
    g -C "$FAR/no-upstream" add -A
    g -C "$FAR/no-upstream" commit -q -m "first"
    make_project "$FAR/plain"
    # busy/ is itself a repository; inner/ is a folder in it, not its own.
    make_project "$BUSY/inner"
    g init -q "$BUSY"
    g -C "$BUSY" add -A
    g -C "$BUSY" commit -q -m "busy"
    write_config off
}
# }}}

# -- {{{ test_preview
function test_preview() {
    local before_listed before_unlisted
    before_listed=$(remote_head listed)
    before_unlisted=$(remote_head unlisted)
    run_tool
    check "preview exits 0" "$(same "$CODE" 0)"
    check "preview says nothing is pushed until push is on" "$(has_line "$OUT" "Preview only.")"
    check "a listed project with waiting commits shows the count" \
        "$(has_line "$OUT" "would push 2 commit(s):")"
    check "... and the exact command" \
        "$(has_line "$OUT" "git -C $FAR/listed push origin main:main")"
    check "the preview pushed nothing" "$(same "$(remote_head listed)" "$before_listed")"
    check "an unlisted project is kept local" "$(has_line "$(grep -A2 'far/unlisted' <<< "$OUT")" "kept local: not listed as publishable")"
    check "... and its waiting commits are named as never pushed" \
        "$(has_line "$OUT" "note: 1 commit(s) for origin/main are never pushed from here")"
    check "a project listed as off is kept local" \
        "$(has_line "$(grep -A1 'far/off-listed' <<< "$OUT")" "kept local")"
    check "\"yes\" lists a project as well as \"on\"" \
        "$(has_line "$(grep -A1 'far/plain' <<< "$OUT")" "publishable, but not a git repository")"
    check "a listed project with no upstream has nothing to push" \
        "$(has_line "$OUT" "publishable, but branch main tracks no remote")"
    check "a project inside another repository is skipped" \
        "$(has_line "$OUT" "it lives inside another repository")"
    check "the main folder's projects are not handled here" "$(lacks_line "$OUT" "home-project")"
    check "the unlisted remote is untouched" "$(same "$(remote_head unlisted)" "$before_unlisted")"
}
# }}}

# -- {{{ test_push
function test_push() {
    local before_unlisted before_off
    before_unlisted=$(remote_head unlisted)
    before_off=$(remote_head off-listed)
    write_config on
    run_tool
    check "with push on, the run exits 0" "$(same "$CODE" 0)"
    check "with push on, the listed project is pushed" "$(same "$(remote_head listed)" "$(local_head listed)")"
    check "with push on, the unlisted project is still not pushed" \
        "$(same "$(remote_head unlisted)" "$before_unlisted")"
    check "with push on, the project listed off is still not pushed" \
        "$(same "$(remote_head off-listed)" "$before_off")"
    run_tool
    check "after the push the listed project is up to date" \
        "$(has_line "$OUT" "publishable; main matches origin/main as of the last fetch")"
}
# }}}

# -- {{{ test_failed_push
function test_failed_push() {
    echo "change again" >> "$FAR/listed/src/main.lua"
    g -C "$FAR/listed" commit -q -am "again"
    mv "$SCRATCH/remotes/listed.git" "$SCRATCH/remotes/listed.gone"
    run_tool
    check "a failed push exits 1" "$(same "$CODE" 1)"
    check "... and says so" "$(has_line "$OUT" "push FAILED")"
    mv "$SCRATCH/remotes/listed.gone" "$SCRATCH/remotes/listed.git"
    write_config off
}
# }}}

# -- {{{ test_configuration_edges
function test_configuration_edges() {
    printf '[external_directories]\nnear=relative/path\n' > "$MONO/delta-version/config/external-projects.conf"
    run_tool
    check "a relative root is skipped with a warning" "$(has_line "$OUT" "is not an absolute path; skipped")"
    check "with no usable root the tool says so" "$(has_line "$OUT" "No extra roots are configured")"
    check "... and exits 0" "$(same "$CODE" 0)"
    rm "$MONO/delta-version/config/external-projects.conf"
    run_tool
    check "with no configuration file nothing is pushed" "$(has_line "$OUT" "Preview only.")"
    run_tool --bogus
    check "an unknown option is a usage error" "$(same "$CODE" 2)"
    write_config off
}
# }}}

# -- {{{ test_scan_column
function test_scan_column() {
    local out
    out=$(DIR="$MONO" bash "$MONO/delta-version/scripts/reconstruct-history.sh" --scan 2>&1)
    check "the scan has a Public column" "$(has_line "$out" "Public")"
    check "the main folder's project is main" "$(same "$(awk '$1 == "home-project" {print $6}' <<< "$out")" "main")"
    check "a listed extra-root project is yes" "$(same "$(awk '$1 == "listed" {print $6}' <<< "$out")" "yes")"
    check "an unlisted extra-root project is no" "$(same "$(awk '$1 == "unlisted" {print $6}' <<< "$out")" "no")"
}
# }}}

setup
echo "publish-projects"
test_preview
test_push
test_failed_push
test_configuration_edges
test_scan_column
[ "${KEEP:-}" ] || rm -rf "${SCRATCH:?}"
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
