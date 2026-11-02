#!/usr/bin/env bash
# manage-worktree.sh - Create and manage git worktrees that work from main
#
# Every worktree starts from the remote's main (origin/main by default), never
# from a local branch that may be behind. It is checked out either detached,
# or on a claude/ or feature/ branch the caller names. There are no per-project
# /dev branches any more and this script never creates one; work goes back to
# main through a pull request. Nothing here depends on a post-checkout hook in
# the main repository.
#
# Usage:
#   manage-worktree.sh create <issue> <project> [--branch NAME] [--no-fetch]
#   manage-worktree.sh remove <issue> <project> [--force]
#   manage-worktree.sh list [project]
#   manage-worktree.sh status
#   manage-worktree.sh path <issue> <project>
#
# The create/path/remove arguments are the ones initialize-issue.sh passes,
# so that caller keeps working unchanged (it gets a detached worktree).

set -euo pipefail

# -- {{{ COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
# }}}

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
WORKTREE_ROOT="${WORKTREE_ROOT:-/mnt/mtwo/programming/ai-worktrees}"
REMOTE="${REMOTE:-origin}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"

# Set by option parsing in main().
OPT_BRANCH=""
OPT_FETCH=true
OPT_FORCE=false
# }}}

# -- {{{ log
log() {
    echo -e "${CYAN}[INFO]${NC} $*" >&2
}
# }}}

# -- {{{ error
error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}
# }}}

# -- {{{ base_ref
base_ref() {
    echo "$REMOTE/$MAIN_BRANCH"
}
# }}}

# -- {{{ get_short_project_name
get_short_project_name() {
    # Short names keep the paths of worktrees made before this rewrite
    # findable; any other project uses its own directory name.
    local project="$1"
    case "$project" in
        delta-version) echo "dv" ;;
        neocities-modernization) echo "neo" ;;
        world-edit-to-execute) echo "wete" ;;
        *) echo "$project" ;;
    esac
}
# }}}

# -- {{{ validate_issue
validate_issue() {
    # An issue number, optionally with one letter for a sub-issue (042a).
    local issue_num="$1"
    if [[ ! "$issue_num" =~ ^[0-9]+[a-z]?$ ]]; then
        error "Invalid issue number: $issue_num (expected digits, e.g. 017 or 042a)"
        return 1
    fi
}
# }}}

# -- {{{ validate_project
validate_project() {
    # A project is any top-level directory of the repository. This replaces
    # the old hard-coded list, which refused projects nobody had added to it.
    local project="$1"
    if [[ -z "$project" || "$project" == */* || "$project" == .* ]]; then
        error "Invalid project name: '$project'"
        return 1
    fi
    if [[ ! -d "$DIR/$project" ]]; then
        error "No such project: $project (no directory $DIR/$project)"
        return 1
    fi
}
# }}}

# -- {{{ validate_branch
validate_branch() {
    # Only claude/<name> and feature/<name>, and never a dev branch: the
    # per-project /dev branches are retired and must not come back.
    local branch="$1"
    if [[ ! "$branch" =~ ^(claude|feature)/[A-Za-z0-9._/-]+$ ]]; then
        error "Branch must be claude/<name> or feature/<name>: $branch"
        return 1
    fi
    if [[ "${branch##*/}" == "dev" ]]; then
        error "Refusing a dev branch ($branch): work goes to $MAIN_BRANCH through a pull request"
        return 1
    fi
    if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
        error "Not a valid git branch name: $branch"
        return 1
    fi
}
# }}}

# -- {{{ get_worktree_path
get_worktree_path() {
    local issue_num="$1"
    local project="$2"
    echo "$WORKTREE_ROOT/$(get_short_project_name "$project")/issue-$issue_num"
}
# }}}

# -- {{{ fetch_main
fetch_main() {
    # Bring the remote's main up to date so the worktree starts from what is
    # really on main. A failed fetch stops here rather than quietly building
    # on a stale copy; --no-fetch is the explicit way to work offline.
    if $OPT_FETCH; then
        log "Fetching $REMOTE $MAIN_BRANCH"
        if ! git -C "$DIR" fetch --quiet "$REMOTE" "$MAIN_BRANCH"; then
            error "Could not fetch $REMOTE $MAIN_BRANCH (use --no-fetch to use the copy you have)"
            return 1
        fi
    fi
    if ! git -C "$DIR" rev-parse --verify --quiet "$(base_ref)^{commit}" >/dev/null; then
        error "$(base_ref) does not exist in $DIR"
        return 1
    fi
}
# }}}

# -- {{{ cmd_create
cmd_create() {
    local issue_num="${1:-}"
    local project="${2:-}"

    if [[ -z "$issue_num" || -z "$project" ]]; then
        error "Usage: $0 create <issue-number> <project> [--branch NAME] [--no-fetch]"
        return 1
    fi

    validate_issue "$issue_num" || return 1
    validate_project "$project" || return 1
    if [[ -n "$OPT_BRANCH" ]]; then
        validate_branch "$OPT_BRANCH" || return 1
    fi

    local worktree_path
    worktree_path=$(get_worktree_path "$issue_num" "$project")
    if [[ -e "$worktree_path" ]]; then
        error "Worktree already exists: $worktree_path"
        error "Use 'remove' first if you want to recreate it"
        return 1
    fi

    fetch_main || return 1
    mkdir -p "$(dirname "$worktree_path")"

    local base
    base=$(base_ref)
    if [[ -z "$OPT_BRANCH" ]]; then
        log "Creating detached worktree at $base"
        git -C "$DIR" worktree add --quiet --detach "$worktree_path" "$base"
    elif git -C "$DIR" rev-parse --verify --quiet "refs/heads/$OPT_BRANCH" >/dev/null; then
        log "Branch $OPT_BRANCH already exists, checking it out"
        git -C "$DIR" worktree add --quiet "$worktree_path" "$OPT_BRANCH"
    else
        # --no-track: the new branch must not push to or pull from main.
        log "Creating branch $OPT_BRANCH from $base"
        git -C "$DIR" worktree add --quiet --no-track -b "$OPT_BRANCH" "$worktree_path" "$base"
    fi

    log "Worktree created: $worktree_path"
}
# }}}

# -- {{{ unreachable_commits
unreachable_commits() {
    # Counts commits on a worktree's HEAD that no branch, tag or remote ref
    # holds -- the work that would be lost if a detached worktree went away.
    local wt="$1"
    git -C "$wt" rev-list --count HEAD --not --branches --tags --remotes 2>/dev/null || echo 0
}
# }}}

# -- {{{ cmd_remove
cmd_remove() {
    local issue_num="${1:-}"
    local project="${2:-}"

    if [[ -z "$issue_num" || -z "$project" ]]; then
        error "Usage: $0 remove <issue-number> <project> [--force]"
        return 1
    fi

    validate_issue "$issue_num" || return 1
    validate_project "$project" || return 1

    local worktree_path
    worktree_path=$(get_worktree_path "$issue_num" "$project")
    if [[ ! -d "$worktree_path" ]]; then
        error "Worktree does not exist: $worktree_path"
        return 1
    fi

    local branch
    branch=$(git -C "$worktree_path" branch --show-current 2>/dev/null || true)

    if ! $OPT_FORCE; then
        if [[ -n "$(git -C "$worktree_path" status --porcelain 2>/dev/null)" ]]; then
            error "Worktree has uncommitted changes (commit them, or use --force to discard):"
            git -C "$worktree_path" status --short >&2
            return 1
        fi
        if [[ -z "$branch" ]]; then
            local lost
            lost=$(unreachable_commits "$worktree_path")
            if [[ "$lost" -gt 0 ]]; then
                error "Detached worktree has $lost commit(s) no branch holds."
                error "Put them on a branch first (git -C $worktree_path switch -c claude/<name>), or use --force to discard."
                return 1
            fi
        fi
    fi

    log "Removing worktree: $worktree_path"
    if $OPT_FORCE; then
        git -C "$DIR" worktree remove --force "$worktree_path"
    else
        git -C "$DIR" worktree remove "$worktree_path"
    fi

    echo -e "${GREEN}Worktree removed:${NC} $worktree_path"
    if [[ -n "$branch" ]]; then
        echo -e "The branch '${CYAN}$branch${NC}' still exists; it is not deleted."
    fi
}
# }}}

# -- {{{ each_worktree
each_worktree() {
    # Prints "path<TAB>head" for every linked worktree (not the main tree),
    # head being the branch name or "detached at <short sha>".
    local main_tree path="" head="" line
    main_tree=$(git -C "$DIR" rev-parse --show-toplevel)
    while IFS= read -r line; do
        case "$line" in
            "worktree "*) path="${line#worktree }"; head="" ;;
            "HEAD "*) head="detached at ${line#HEAD }"; head="${head:0:20}" ;;
            "branch "*) head="${line#branch refs/heads/}" ;;
            "")
                if [[ -n "$path" && "$path" != "$main_tree" ]]; then
                    printf '%s\t%s\n' "$path" "$head"
                fi
                path=""
                ;;
        esac
    done < <(git -C "$DIR" worktree list --porcelain; echo)
}
# }}}

# -- {{{ cmd_list
cmd_list() {
    local project="${1:-}"
    local prefix=""

    if [[ -n "$project" ]]; then
        validate_project "$project" || return 1
        prefix="$WORKTREE_ROOT/$(get_short_project_name "$project")/"
    fi

    echo -e "${GREEN}Active Worktrees${NC}"
    echo "================"
    local found=false path head
    while IFS=$'\t' read -r path head; do
        [[ -z "$prefix" || "$path" == "$prefix"* ]] || continue
        printf '  %-50s %s\n' "$path" "$head"
        found=true
    done < <(each_worktree)
    $found || echo "  (none${project:+ for $project})"
}
# }}}

# -- {{{ cmd_status
cmd_status() {
    echo -e "${GREEN}Worktree Status${NC}"
    echo "==============="
    local found=false path head changes ahead
    while IFS=$'\t' read -r path head; do
        found=true
        changes=$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        ahead=$(git -C "$path" rev-list --count "$(base_ref)..HEAD" 2>/dev/null || echo "?")
        echo -e "  ${CYAN}$head${NC}"
        echo "    Path: $path"
        echo "    Commits not on $(base_ref): $ahead"
        if [[ "$changes" -gt 0 ]]; then
            echo -e "    Status: ${YELLOW}$changes uncommitted change(s)${NC}"
        else
            echo -e "    Status: ${GREEN}clean${NC}"
        fi
    done < <(each_worktree)
    $found || echo "  (no active worktrees)"
}
# }}}

# -- {{{ cmd_path
cmd_path() {
    local issue_num="${1:-}"
    local project="${2:-}"

    if [[ -z "$issue_num" || -z "$project" ]]; then
        error "Usage: $0 path <issue-number> <project>"
        return 1
    fi

    validate_issue "$issue_num" || return 1
    validate_project "$project" || return 1

    local worktree_path
    worktree_path=$(get_worktree_path "$issue_num" "$project")
    if [[ -d "$worktree_path" ]]; then
        echo "$worktree_path/$project"
    else
        error "Worktree does not exist: $worktree_path"
        return 1
    fi
}
# }}}

# -- {{{ show_help
show_help() {
    cat << EOF
Usage: manage-worktree.sh <command> [arguments] [options]

Make git worktrees that start from $REMOTE/$MAIN_BRANCH, for work that goes
back to $MAIN_BRANCH through a pull request.

Commands:
    create <issue> <project>   New worktree at $REMOTE/$MAIN_BRANCH (fetched first)
    remove <issue> <project>   Remove a worktree (keeps its branch)
    list [project]             List worktrees
    status                     Show each worktree's head, changes and commits
    path <issue> <project>     Print the worktree's project directory

Options:
    --branch NAME   (create) check out a claude/ or feature/ branch instead
                    of a detached HEAD; made from $REMOTE/$MAIN_BRANCH if new,
                    reused if it exists. Dev branches are refused.
    --no-fetch      (create) use the $REMOTE/$MAIN_BRANCH you already have
    --force         (remove) remove despite uncommitted changes or commits
                    that no branch holds

A project is any top-level directory of the repository.

Examples:
    manage-worktree.sh create 017 delta-version
    manage-worktree.sh create 017 delta-version --branch claude/017-keywords
    cd "\$(manage-worktree.sh path 017 delta-version)"
    manage-worktree.sh remove 017 delta-version

Workflow:
    1. create a worktree (on a claude/ or feature/ branch if you will push)
    2. work and commit in <worktree>/<project>/
    3. push the branch and open a pull request against $MAIN_BRANCH
    4. remove the worktree

Environment:
    DIR            main repository      (now: $DIR)
    WORKTREE_ROOT  worktree storage     (now: $WORKTREE_ROOT)
    REMOTE         remote to use        (now: $REMOTE)
    MAIN_BRANCH    branch to start from (now: $MAIN_BRANCH)
EOF
}
# }}}

# -- {{{ main
main() {
    local command="${1:-}"
    [[ $# -gt 0 ]] && shift

    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch)
                [[ $# -ge 2 ]] || { error "--branch needs a name"; exit 1; }
                OPT_BRANCH="$2"; shift 2 ;;
            --branch=*) OPT_BRANCH="${1#--branch=}"; shift ;;
            --no-fetch) OPT_FETCH=false; shift ;;
            --force|-f) OPT_FORCE=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            -*) error "Unknown option: $1"; exit 1 ;;
            *) args+=("$1"); shift ;;
        esac
    done

    if [[ -n "$OPT_BRANCH" && "$command" != "create" ]]; then
        error "--branch only applies to create"
        exit 1
    fi

    case "$command" in
        create)      cmd_create "${args[@]+"${args[@]}"}" ;;
        remove|rm)   cmd_remove "${args[@]+"${args[@]}"}" ;;
        list|ls)     cmd_list "${args[@]+"${args[@]}"}" ;;
        status|st)   cmd_status ;;
        path)        cmd_path "${args[@]+"${args[@]}"}" ;;
        -h|--help|help|"") show_help ;;
        *)
            error "Unknown command: $command"
            show_help >&2
            exit 1
            ;;
    esac
}
# }}}

main "$@"
