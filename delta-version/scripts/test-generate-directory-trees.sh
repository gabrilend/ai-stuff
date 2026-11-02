#!/bin/bash
# test-generate-directory-trees.sh - proves generate-directory-trees.lua keeps
# its promises.
#
# In general terms: builds a pretend monorepo in RAM -- a git repository with
# a delta-version folder whose generator and project lister are the real ones
# (linked, not copied), a shared scripts/ folder, and two small projects with
# ignored, untracked, deleted, deep and crowded corners -- plus a second
# pretend monorepo with no git at all, and runs the generator against them.
# It checks: the master file has a marked section per project and one for the
# shared scripts; only files git would keep are listed; deep folders and
# crowded folders are counted rather than listed; each project's file is cut
# from the master and lists the shared scripts; a re-run on a later day
# rewrites nothing unless a map changed; and the options do what they say.
# Exercises the acceptance criteria of issue 044.
#
# Usage: test-generate-directory-trees.sh [monorepo]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ -n "${1:-}" ] && DIR="$1"

REAL_SCRIPTS="$DIR/delta-version/scripts"
SCRATCH="$DIR/delta-version/tmp/shared-memory/directory-trees-test"
ROOT="$SCRATCH/root"
PLAIN="$SCRATCH/plain"
MASTER="$SCRATCH/master.txt"

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

# -- {{{ lacks
function lacks() {
    ! grep -qF -- "$1" "$2"
}
# }}}

# -- {{{ absent
function absent() {
    # True when the text on stdin has no match for the pattern.
    ! grep -qE -- "$1"
}
# }}}

# -- {{{ has
function has() {
    grep -qF -- "$1" "$2"
}
# }}}

# -- {{{ same
function same() {
    [ "$1" = "$2" ]
}
# }}}

# -- {{{ make_monorepo
function make_monorepo() {
    # A monorepo at $1: delta-version with the real tools linked in, a shared
    # scripts/ folder, and the projects alpha and beta.
    local root="$1"
    mkdir -p "$root/delta-version/scripts" "$root/delta-version/issues" "$root/scripts"
    ln -s "$REAL_SCRIPTS/generate-directory-trees.lua" "$root/delta-version/scripts/generate-directory-trees.lua"
    ln -s "$REAL_SCRIPTS/list-projects.sh" "$root/delta-version/scripts/list-projects.sh"
    printf '# delta-version\n' > "$root/delta-version/README.md"

    # Shared scripts: two runnable ones with headers of the two house shapes,
    # and things that are not to be listed.
    printf '#!/bin/bash\n# tidy.sh - Sweeps the floor of a project.\n#\n# More words.\necho\n' > "$root/scripts/tidy.sh"
    printf '#!/usr/bin/env luajit\n--\n-- count-things\n--\n-- Counts the things in a project,\n-- one by one.\nprint(1)\n' > "$root/scripts/count-things"
    printf '#!/bin/bash\n# test-tidy.sh - tests\n' > "$root/scripts/test-tidy.sh"
    printf '#!/bin/bash\n# not runnable\n' > "$root/scripts/idle.sh"
    printf '# notes\n' > "$root/scripts/README.md"
    mkdir -p "$root/scripts/libs"
    ln -s libs "$root/scripts/tmp"
    chmod +x "$root/scripts/tidy.sh" "$root/scripts/count-things" "$root/scripts/test-tidy.sh" "$root/scripts/README.md"

    # alpha: ignored build output, a deep folder, a crowded folder.
    mkdir -p "$root/alpha/src/one/two/three/four/five/six" "$root/alpha/logs" "$root/alpha/build" "$root/alpha/issues"
    printf '# alpha\n' > "$root/alpha/README.md"
    printf 'build/\n' > "$root/alpha/.gitignore"
    printf 'print(1)\n' > "$root/alpha/src/main.lua"
    printf 'deep\n' > "$root/alpha/src/one/two/three/four/five/six/bottom.txt"
    local n
    for n in $(seq -w 1 30); do printf '%s\n' "$n" > "$root/alpha/logs/log-$n.txt"; done
    printf 'binary\n' > "$root/alpha/build/out.bin"
    printf 'soon gone\n' > "$root/alpha/src/doomed.lua"

    # beta: small.
    mkdir -p "$root/beta/issues" "$root/beta/docs"
    printf '# beta\n' > "$root/beta/README.md"
    printf 'words\n' > "$root/beta/docs/guide.md"
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$ROOT" "$PLAIN"

    make_monorepo "$ROOT"
    git -C "$ROOT" init -q -b main
    git -C "$ROOT" add -A
    git -C "$ROOT" -c user.name=t -c user.email=t@example.invalid commit -q -m base
    # After the commit: one tracked file deleted, one new file not yet added.
    rm "$ROOT/alpha/src/doomed.lua"
    printf 'new\n' > "$ROOT/alpha/src/fresh.lua"

    make_monorepo "$PLAIN"
}
# }}}

# -- {{{ generate
function generate() {
    # Runs the generator for the pretend monorepo at $1; output in OUT,
    # status in STATUS.
    local root="$1"; shift
    OUT=$(luajit "$root/delta-version/scripts/generate-directory-trees.lua" \
          --dir="$root/delta-version" --master="$MASTER" "$@" 2>&1)
    STATUS=$?
}
# }}}

# -- {{{ section
function section() {
    # One section of the master file, without its marker.
    awk -v want="][ $1 ][" '
        $0 == want { on = 1; next }
        /^\]\[ .* \]\[$/ { on = 0 }
        on' "$MASTER"
}
# }}}

# -- {{{ tree_in_file
function tree_in_file() {
    # The tree part of a project's file: from its first line ("name/") up to
    # the blank line before the shared section.
    awk '/^## Project Structure$/ { on = 1; getline; next } on && /^$/ { exit } on' "$1"
}
# }}}

# -- {{{ tree_in_master
function tree_in_master() {
    section "$1" | awk 'NF == 0 && seen { exit } NF { seen = 1; print }'
}
# }}}

# -- {{{ run_tests
function run_tests() {
    echo "the master file"
    generate "$ROOT" --dry-run
    check "exit 0"                                         "$(yes_if same "$STATUS" 0)"
    check "a marked section per project"                   "$(yes_if has "][ alpha ][" "$MASTER")"
    check "beta too"                                       "$(yes_if has "][ beta ][" "$MASTER")"
    check "and delta-version, which the lister leaves out" "$(yes_if has "][ delta-version ][" "$MASTER")"
    check "and one for the shared scripts"                 "$(yes_if has "][ shared-monorepo-utilities ][" "$MASTER")"
    check "a dry run writes no project file"               "$(yes_if [ ! -e "$ROOT/alpha/DIRECTORY_STRUCTURE.txt" ])"

    local alpha
    alpha=$(section alpha)
    check "tracked files are listed"                       "$(yes_if grep -q "main.lua" <<< "$alpha")"
    check "new files git would keep are listed"            "$(yes_if grep -q "fresh.lua" <<< "$alpha")"
    check "ignored files are not"                          "$(yes_if absent "out.bin" <<< "$alpha")"
    check "nor files deleted from disk"                    "$(yes_if absent "doomed.lua" <<< "$alpha")"
    check "folders come before files, drawn as a tree" \
        "$(yes_if grep -qzP 'alpha/\n├── logs/\n' <<< "$alpha")"
    check "a crowded folder shows 25 files and counts the rest" \
        "$(yes_if grep -q "└── … and 5 more files" <<< "$alpha")"
    check "a folder past the depth limit is counted" \
        "$(yes_if grep -q "five/  (1 file)" <<< "$alpha")"
    check "says how the files were found"                  "$(yes_if grep -q "Listed from: git ls-files" <<< "$alpha")"

    local shared
    shared=$(section shared-monorepo-utilities)
    check "shared scripts are listed with what they do" \
        "$(yes_if grep -q "tidy.sh *- Sweeps the floor of a project." <<< "$shared")"
    check "a description wrapped over lines is joined" \
        "$(yes_if grep -q "count-things *- Counts the things in a project, one by one." <<< "$shared")"
    check "tests, unrunnable files, notes and folder links are not" \
        "$(yes_if absent "test-tidy|idle.sh|README|tmp" <<< "$(grep -E '^(├|└)' <<< "$shared")")"
    check "delta-version's own scripts are listed" \
        "$(yes_if grep -q "generate-directory-trees.lua" <<< "$shared")"

    echo "distribution"
    generate "$ROOT"
    local file="$ROOT/alpha/DIRECTORY_STRUCTURE.txt"
    check "exit 0"                                         "$(yes_if same "$STATUS" 0)"
    check "each project gets its file"                     "$(yes_if [ -f "$file" ] && [ -f "$ROOT/beta/DIRECTORY_STRUCTURE.txt" ])"
    check "delta-version too"                              "$(yes_if [ -f "$ROOT/delta-version/DIRECTORY_STRUCTURE.txt" ])"
    check "its tree is the master's section, cut by the markers" \
        "$(yes_if same "$(tree_in_file "$file")" "$(tree_in_master alpha)")"
    check "with the shared scripts underneath"             "$(yes_if has "Sweeps the floor of a project." "$file")"
    check "and how to regenerate it"                       "$(yes_if has "--project=alpha" "$file")"
    check "the shared scripts are not a project file"      "$(yes_if [ ! -e "$ROOT/scripts/DIRECTORY_STRUCTURE.txt" ])"

    echo "re-running"
    sed -i 's/^Generated: .*/Generated: 2000-01-01/' "$file"
    touch -d '2000-01-01' "$file"
    local before
    before=$(stat -c %Y "$file")
    generate "$ROOT"
    check "the map does not list itself"                   "$(yes_if absent "DIRECTORY_STRUCTURE" <<< "$(tree_in_file "$file")")"
    check "an unchanged map is not rewritten, only the date would differ" \
        "$(yes_if same "$(stat -c %Y "$file")" "$before")"
    check "and the run says so"                            "$(yes_if grep -q "0 project files written" <<< "$OUT")"
    printf 'more\n' > "$ROOT/alpha/src/another.lua"
    generate "$ROOT"
    check "a changed map is rewritten"                     "$(yes_if has "another.lua" "$file")"
    check "with today's date"                              "$(yes_if has "Generated: $(date +%Y-%m-%d)" "$file")"
    check "and only that project's file"                   "$(yes_if grep -q "1 project file written" <<< "$OUT")"

    echo "options"
    generate "$ROOT" --dry-run --project=beta
    check "--project limits the master to that project"    "$(yes_if lacks "][ alpha ][" "$MASTER")"
    check "and keeps the shared section"                   "$(yes_if has "][ shared-monorepo-utilities ][" "$MASTER")"
    generate "$ROOT" --dry-run --project nosuch
    check "an unknown project is an error"                 "$(yes_if same "$STATUS" 1)"
    generate "$ROOT" --dry-run --project=alpha --no-files
    check "--no-files lists folders only"                  "$(yes_if absent "main.lua" <<< "$(section alpha)")"
    check "the folders are still there"                    "$(yes_if grep -q "src/" <<< "$(section alpha)")"
    generate "$ROOT" --dry-run --project=alpha --no-gitignore
    check "--no-gitignore lists ignored files too"         "$(yes_if grep -q "out.bin" <<< "$(section alpha)")"
    generate "$ROOT" --dry-run --project=alpha --max-entries=0 --max-depth 9
    check "--max-entries=0 lists every file"               "$(yes_if grep -q "log-30.txt" <<< "$(section alpha)")"
    check "--max-depth reaches deeper"                     "$(yes_if grep -q "bottom.txt" <<< "$(section alpha)")"
    generate "$ROOT" --max-depth=x
    check "a bad number is refused with exit 2"            "$(yes_if same "$STATUS" 2)"
    generate "$ROOT" --frobnicate
    check "an unknown option is refused with exit 2"       "$(yes_if same "$STATUS" 2)"

    echo "no git"
    generate "$PLAIN" --dry-run --project=alpha
    check "a monorepo without git still gets a map"        "$(yes_if grep -q "main.lua" <<< "$(section alpha)")"
    check "and says it listed every file on disk"          "$(yes_if grep -q "not in a git repository" <<< "$(section alpha)")"
}
# }}}

build_fixture
run_tests
rm -rf "$SCRATCH"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
