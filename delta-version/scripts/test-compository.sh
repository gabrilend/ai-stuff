#!/bin/bash
# test-compository.sh - proves the compository keeps its promises.
#
# In general terms: builds a pretend computer (a few small repositories, some
# the owner's, one someone else's, one empty) and a pretend flash drive, both
# in RAM, then runs the compository against them and checks it: it will not
# write to an unmarked drive; it copies only the owner's repositories,
# nested ones included; a second run changes nothing; new work on the
# computer is played forward onto the drive; and work done on the drive
# itself -- a commit, or an unsaved edit -- is never overwritten.
# Exercises the success criteria of issue 061.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/compository.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/compository-test"
SOURCE="$SCRATCH/computer"
DRIVE="$SCRATCH/drive"
LIST="$SCRATCH/list.lua"

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

# -- {{{ commit_as
function commit_as() {
    # A commit under a chosen author, without touching anyone's git config.
    local repository="$1" email="$2" message="$3"
    git -C "$repository" -c user.name=fixture -c user.email="$email" \
        commit --quiet --allow-empty -m "$message"
}
# }}}

# -- {{{ compository
function compository() {
    luajit "$TOOL" --dir="$DIR/delta-version" --list-file="$LIST" "$@"
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SOURCE" "$DRIVE" "$SCRATCH/unmarked"

    git init --quiet -b main "$SOURCE/mine"
    printf 'nested/\n' > "$SOURCE/mine/.gitignore"
    git -C "$SOURCE/mine" add .gitignore
    commit_as "$SOURCE/mine" gabrilend@gmail.com "first"

    git init --quiet -b main "$SOURCE/mine/nested"
    commit_as "$SOURCE/mine/nested" gabrilend@gmail.com "nested first"

    git init --quiet -b main "$SOURCE/theirs"
    commit_as "$SOURCE/theirs" someone@example.com "not ours"

    git init --quiet -b main "$SOURCE/empty"

    cat > "$LIST" <<EOF
return {
    repositories = {
        roots = { "$SOURCE" },
        owner_emails = { "gabrilend@gmail.com" },
        never_enter = { "node_modules", "libs", ".git" },
        exclude = {},
    },
    selected = {},
}
EOF
}
# }}}

# -- {{{ head_of
function head_of() { git -C "$1" rev-parse HEAD 2>/dev/null; }
# }}}

build_fixture
echo "compository"

compository --drive="$SCRATCH/unmarked" > /dev/null 2>&1
check "an unmarked drive is refused" "$([ $? -eq 1 ] && echo yes || echo no)"
check "an unmarked drive is left empty" "$([ -z "$(ls -A "$SCRATCH/unmarked")" ] && echo yes || echo no)"

compository --init="$DRIVE" > /dev/null 2>&1
check "--init writes the marker" "$([ -f "$DRIVE/.compository" ] && echo yes || echo no)"

compository --drive="$DRIVE" > /dev/null 2>&1
check "the first run succeeds" "$([ $? -eq 0 ] && echo yes || echo no)"
check "the owner's repository is cloned" "$([ "$(head_of "$DRIVE/compository/mine")" = "$(head_of "$SOURCE/mine")" ] && echo yes || echo no)"
check "a nested repository is cloned inside its parent's copy" "$([ "$(head_of "$DRIVE/compository/mine/nested")" = "$(head_of "$SOURCE/mine/nested")" ] && echo yes || echo no)"
check "someone else's repository is not carried" "$([ ! -e "$DRIVE/compository/theirs" ] && echo yes || echo no)"
check "an empty repository is not carried" "$([ ! -e "$DRIVE/compository/empty" ] && echo yes || echo no)"
check "the copy's upstream is the computer's folder" "$([ "$(git -C "$DRIVE/compository/mine" remote get-url origin)" = "$SOURCE/mine" ] && echo yes || echo no)"

report=$(compository --drive="$DRIVE" 2>&1)
check "a second run succeeds" "$([ $? -eq 0 ] && echo yes || echo no)"
check "a second run reports everything current" "$([ "$(printf '%s\n' "$report" | grep -c '^  current')" = 2 ] && echo yes || echo no)"

commit_as "$SOURCE/mine" gabrilend@gmail.com "second"
report=$(compository --drive="$DRIVE" 2>&1)
check "new work on the computer is played forward" "$([ "$(head_of "$DRIVE/compository/mine")" = "$(head_of "$SOURCE/mine")" ] && echo yes || echo no)"
check "the report says it advanced" "$(printf '%s\n' "$report" | grep -q '^  advanced *mine ' && echo yes || echo no)"

commit_as "$DRIVE/compository/mine" gabrilend@gmail.com "written on the drive"
drive_commit=$(head_of "$DRIVE/compository/mine")
commit_as "$SOURCE/mine" gabrilend@gmail.com "third"
compository --drive="$DRIVE" > /dev/null 2>&1
check "a drive with its own commits makes the run fail" "$([ $? -eq 1 ] && echo yes || echo no)"
check "the drive's own commit is left in place" "$([ "$(head_of "$DRIVE/compository/mine")" = "$drive_commit" ] && echo yes || echo no)"

printf 'edit\n' > "$DRIVE/compository/mine/nested/unsaved.txt"
git -C "$DRIVE/compository/mine/nested" add unsaved.txt
commit_as "$SOURCE/mine/nested" gabrilend@gmail.com "nested second"
nested_before=$(head_of "$DRIVE/compository/mine/nested")
report=$(compository --drive="$DRIVE" 2>&1)
check "uncommitted work on the drive is refused" "$(printf '%s\n' "$report" | grep -q '^  refused *mine/nested .*uncommitted' && echo yes || echo no)"
check "uncommitted work on the drive is left in place" "$([ -f "$DRIVE/compository/mine/nested/unsaved.txt" ] && [ "$(head_of "$DRIVE/compository/mine/nested")" = "$nested_before" ] && echo yes || echo no)"

# -- selected items: gathered into their own repository, then carried like
# any other. The tool commits under whatever git identity is in force; the
# test fixes it to the owner's so the gathered repository counts as theirs.
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=gabrilend@gmail.com
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=gabrilend@gmail.com
mkdir -p "$SOURCE/notes"
printf 'first thought\n' > "$SOURCE/notes/vision"
sed -i 's|selected = {},|selected = { "notes/vision" }, selected_repository = "'"$SOURCE"'/selected",|' "$LIST"
rm -f "$DRIVE/compository/mine/nested/unsaved.txt"
git -C "$DRIVE/compository/mine/nested" reset --quiet --hard

compository --drive="$DRIVE" > /dev/null 2>&1
check "the selected items are gathered into a repository" "$([ -f "$SOURCE/selected/notes/vision" ] && echo yes || echo no)"
check "the gathered repository is carried to the drive" "$([ -f "$DRIVE/compository/selected/notes/vision" ] && echo yes || echo no)"
commits_before=$(git -C "$SOURCE/selected" rev-list --count HEAD)
compository --drive="$DRIVE" > /dev/null 2>&1
check "unchanged selected items make no new commit" "$([ "$(git -C "$SOURCE/selected" rev-list --count HEAD)" = "$commits_before" ] && echo yes || echo no)"
printf 'second thought\n' >> "$SOURCE/notes/vision"
compository --drive="$DRIVE" > /dev/null 2>&1
check "a changed selected item plays forward onto the drive" "$(grep -q 'second thought' "$DRIVE/compository/selected/notes/vision" && echo yes || echo no)"
sed -i 's|"notes/vision"|"notes/missing"|' "$LIST"
compository --drive="$DRIVE" > /dev/null 2>&1
check "a selected item that does not exist stops the run" "$([ $? -eq 1 ] && echo yes || echo no)"

rm -rf "$SCRATCH"
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
