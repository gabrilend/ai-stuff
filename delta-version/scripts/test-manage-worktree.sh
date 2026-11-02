#!/bin/bash
# test-manage-worktree.sh - proves manage-worktree.sh works from main only.
#
# In general terms: worktrees must start from what is really on the remote's
# main, either detached or on a claude/ or feature/ branch the caller names,
# and the script must never make a per-project /dev branch again. This test
# builds a throwaway "remote" and a clone of it in a scratch folder in RAM and
# runs the script against those, never against the real repository. Exercises
# the decision recorded in issue 046.
#
# Usage: test-manage-worktree.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/manage-worktree.sh"
SCRATCH="$DIR/delta-version/tmp/shared-memory/manage-worktree-test"

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

# -- {{{ yes_if
function yes_if() {
    # Runs a command and answers yes or no by its exit status.
    if "$@" > /dev/null 2>&1; then echo yes; else echo no; fi
}
# }}}

# -- {{{ fails
function fails() {
    # The opposite of yes_if's test: the command must exit non-zero.
    if "$@" > /dev/null 2>&1; then return 1; else return 0; fi
}
# }}}

# -- {{{ absent
function absent() {
    [ ! -e "$1" ]
}
# }}}

# -- {{{ same
function same() {
    [ "$1" = "$2" ]
}
# }}}

# -- {{{ mw
function mw() {
    # The tool under test, aimed at the scratch clone.
    DIR="$REPO" WORKTREE_ROOT="$WT" "$TOOL" "$@"
}
# }}}

# -- {{{ git_q
function git_q() {
    git -c user.name=test -c user.email=test@example.invalid "$@"
}
# }}}

# -- {{{ advance_origin
function advance_origin() {
    # Lands one more commit on the remote's main from a second clone, so the
    # scratch clone's own copy falls behind until it fetches.
    local note="$1"
    echo "$note" >> "$PUSHER/delta-version/notes.txt"
    git_q -C "$PUSHER" commit -q -am "$note"
    git -C "$PUSHER" -c push.negotiate=false push -q origin main
    git -C "$PUSHER" rev-parse HEAD
}
# }}}

# -- {{{ prepare_fixture
function prepare_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    # Real paths, so they compare equal to what git worktree list prints.
    SCRATCH=$(realpath "$SCRATCH")
    ORIGIN="$SCRATCH/origin.git"
    REPO="$SCRATCH/repo"
    PUSHER="$SCRATCH/pusher"
    WT="$SCRATCH/worktrees"

    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$PUSHER" 2> /dev/null
    git -C "$PUSHER" checkout -q -b main
    mkdir -p "$PUSHER/delta-version" "$PUSHER/authorship-tool"
    echo "first" > "$PUSHER/delta-version/notes.txt"
    echo "tool" > "$PUSHER/authorship-tool/readme"
    git -C "$PUSHER" add -A
    git_q -C "$PUSHER" commit -q -m "first"
    git -C "$PUSHER" -c push.negotiate=false push -q -u origin main
    git clone -q "$ORIGIN" "$REPO"
}
# }}}

# -- {{{ test_detached_from_fetched_main
function test_detached_from_fetched_main() {
    local old_main new_tip wt="$WT/dv/issue-017"
    old_main=$(git -C "$REPO" rev-parse main)
    new_tip=$(advance_origin "second")

    check "create with no options succeeds" "$(yes_if mw create 017 delta-version)"
    check "worktree directory exists" "$(yes_if test -d "$wt/delta-version")"
    check "worktree HEAD is detached" \
        "$(yes_if fails git -C "$wt" symbolic-ref -q HEAD)"
    check "worktree starts at the freshly fetched origin/main" \
        "$(yes_if same "$(git -C "$wt" rev-parse HEAD)" "$new_tip")"
    check "the clone's own main was left where it was" \
        "$(yes_if same "$(git -C "$REPO" rev-parse main)" "$old_main")"
    check "path prints the project directory inside the worktree" \
        "$(yes_if same "$(mw path 017 delta-version 2> /dev/null)" "$wt/delta-version")"
    check "a second create for the same issue is refused" \
        "$(yes_if fails mw create 017 delta-version)"
}
# }}}

# -- {{{ test_no_fetch
function test_no_fetch() {
    local known newer wt="$WT/dv/issue-018"
    known=$(git -C "$REPO" rev-parse origin/main)
    newer=$(advance_origin "third")
    check "create --no-fetch succeeds" "$(yes_if mw create 018 delta-version --no-fetch)"
    check "--no-fetch uses the origin/main already known" \
        "$(yes_if same "$(git -C "$wt" rev-parse HEAD)" "$known")"
    check "--no-fetch did not pick up the newer remote commit" \
        "$(yes_if fails same "$(git -C "$wt" rev-parse HEAD)" "$newer")"
}
# }}}

# -- {{{ test_named_branches
function test_named_branches() {
    local tip
    tip=$(git -C "$REPO" ls-remote origin refs/heads/main | cut -f1)

    check "create --branch claude/019-thing succeeds" \
        "$(yes_if mw create 019 delta-version --branch claude/019-thing)"
    check "worktree is on claude/019-thing" \
        "$(yes_if same "$(git -C "$WT/dv/issue-019" branch --show-current)" "claude/019-thing")"
    check "claude/019-thing starts at origin/main" \
        "$(yes_if same "$(git -C "$REPO" rev-parse claude/019-thing)" "$tip")"
    check "claude/019-thing has no upstream (it never tracks main)" \
        "$(yes_if fails git -C "$REPO" rev-parse --abbrev-ref 'claude/019-thing@{upstream}')"

    check "create --branch=feature/020-other succeeds" \
        "$(yes_if mw create 020 delta-version --branch=feature/020-other)"
    check "worktree is on feature/020-other" \
        "$(yes_if same "$(git -C "$WT/dv/issue-020" branch --show-current)" "feature/020-other")"

    # An existing branch is reused where it stands, not reset to main.
    local first
    first=$(git -C "$REPO" rev-list --max-parents=0 origin/main)
    git -C "$REPO" branch claude/021-reuse "$first"
    check "create --branch on an existing branch succeeds" \
        "$(yes_if mw create 021 delta-version --branch claude/021-reuse --no-fetch)"
    check "an existing branch is checked out where it stands" \
        "$(yes_if same "$(git -C "$WT/dv/issue-021" rev-parse HEAD)" "$first")"
}
# }}}

# -- {{{ test_refused_branches
function test_refused_branches() {
    local name
    for name in claude/dev feature/dev dv/dev delta-version/dev main \
                some-branch claude/ "claude/has space" claude/a..b; do
        check "branch '$name' is refused" \
            "$(yes_if fails mw create 030 delta-version --branch "$name" --no-fetch)"
    done
    check "no worktree was left behind by the refusals" \
        "$(yes_if absent "$WT/dv/issue-030")"
    check "no */dev branch exists anywhere in the clone" \
        "$(yes_if same "$(git -C "$REPO" for-each-ref --format='%(refname)' 'refs/heads/**/dev' refs/heads/dev)" "")"
    check "--branch with a command other than create is refused" \
        "$(yes_if fails mw path 017 delta-version --branch claude/x)"
    check "an unknown option is refused" \
        "$(yes_if fails mw create 031 delta-version --sideways)"
}
# }}}

# -- {{{ test_projects_and_issues
function test_projects_and_issues() {
    # authorship-tool was missing from the old hard-coded list.
    check "a project only the repository knows about is accepted" \
        "$(yes_if mw create 1 authorship-tool --no-fetch)"
    check "its worktree uses the project's own name as the folder" \
        "$(yes_if same "$(mw path 1 authorship-tool 2> /dev/null)" "$WT/authorship-tool/issue-1/authorship-tool")"
    check "an unknown project is refused" \
        "$(yes_if fails mw create 1 no-such-project --no-fetch)"
    check "a project name that climbs out is refused" \
        "$(yes_if fails mw create 1 ../repo --no-fetch)"
    check "a sub-issue number like 042a is accepted" \
        "$(yes_if mw create 042a delta-version --no-fetch)"
    check "a non-number issue is refused" \
        "$(yes_if fails mw create abc delta-version --no-fetch)"
}
# }}}

# -- {{{ test_list_and_status
function test_list_and_status() {
    local listing
    listing=$(mw list 2> /dev/null)
    check "list shows the detached worktree" \
        "$(yes_if grep -q "issue-017 .*detached at" <<< "$listing")"
    check "list shows the branch worktree by branch name" \
        "$(yes_if grep -q "claude/019-thing" <<< "$listing")"
    listing=$(mw list authorship-tool 2> /dev/null)
    check "list <project> shows that project's worktree" \
        "$(yes_if grep -q "authorship-tool/issue-1" <<< "$listing")"
    check "list <project> leaves other projects out" \
        "$(yes_if fails grep -q "issue-017" <<< "$listing")"
    check "status runs" "$(yes_if mw status)"
    check "status reports commits not on origin/main" \
        "$(yes_if grep -q "Commits not on origin/main" <<< "$(mw status 2> /dev/null)")"
}
# }}}

# -- {{{ test_remove
function test_remove() {
    check "removing a clean detached worktree succeeds" \
        "$(yes_if mw remove 018 delta-version)"
    check "its directory is gone" "$(yes_if absent "$WT/dv/issue-018")"

    echo "dirty" >> "$WT/dv/issue-017/delta-version/notes.txt"
    check "remove refuses uncommitted changes" \
        "$(yes_if fails mw remove 017 delta-version)"
    check "the dirty worktree is still there" "$(yes_if test -d "$WT/dv/issue-017")"
    check "remove --force removes it anyway" \
        "$(yes_if mw remove 017 delta-version --force)"
    check "the forced worktree is gone" "$(yes_if absent "$WT/dv/issue-017")"

    echo "orphan" >> "$WT/dv/issue-042a/delta-version/notes.txt"
    git_q -C "$WT/dv/issue-042a" commit -q -am "orphan"
    check "remove refuses a detached commit no branch holds" \
        "$(yes_if fails mw remove 042a delta-version)"
    check "remove --force discards it on request" \
        "$(yes_if mw remove 042a delta-version --force)"

    echo "kept" >> "$WT/dv/issue-019/delta-version/notes.txt"
    git_q -C "$WT/dv/issue-019" commit -q -am "kept"
    check "removing a branch worktree with commits succeeds (the branch holds them)" \
        "$(yes_if mw remove 019 delta-version)"
    check "the branch is kept after its worktree goes" \
        "$(yes_if git -C "$REPO" rev-parse --verify -q refs/heads/claude/019-thing)"
    check "removing a worktree that does not exist is refused" \
        "$(yes_if fails mw remove 099 delta-version)"
}
# }}}

# -- {{{ test_fetch_failure
function test_fetch_failure() {
    git -C "$REPO" remote set-url origin "$SCRATCH/nowhere.git"
    check "create stops when origin cannot be fetched" \
        "$(yes_if fails mw create 040 delta-version)"
    check "no worktree is made after a failed fetch" "$(yes_if absent "$WT/dv/issue-040")"
    check "--no-fetch still works offline" \
        "$(yes_if mw create 040 delta-version --no-fetch)"
}
# }}}

# -- {{{ test_no_hook_needed
function test_no_hook_needed() {
    check "the clone has no post-checkout hook to lean on" \
        "$(yes_if absent "$(git -C "$REPO" rev-parse --git-path hooks/post-checkout)")"
    check "after every create above, still no */dev branch in the clone" \
        "$(yes_if same "$(git -C "$REPO" for-each-ref --format='%(refname)' 'refs/heads/**/dev' refs/heads/dev)" "")"
}
# }}}

# -- {{{ main
function main() {
    if [ ! -x "$TOOL" ]; then
        echo "manage-worktree.sh not found or not executable at $TOOL" >&2
        exit 2
    fi
    prepare_fixture
    echo "manage-worktree.sh"
    test_detached_from_fetched_main
    test_no_fetch
    test_named_branches
    test_refused_branches
    test_projects_and_issues
    test_list_and_status
    test_remove
    test_fetch_failure
    test_no_hook_needed
    rm -rf "$SCRATCH"
    echo ""
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
