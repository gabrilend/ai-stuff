#!/usr/bin/env bash
# migrate-dev-branches.sh - Merge and remove project /dev branches
#
# Merges all project/dev branches to master and removes them, simplifying
# the branch architecture to eliminate branch confusion and accidental commits.

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_ROOT="$(dirname "$DIR")"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# -- {{{ save_current_state
save_current_state() {
    echo -e "${CYAN}Saving current state...${NC}"

    mkdir -p "${DIR}/tmp"

    git -C "$REPO_ROOT" branch --list '*/dev' > "${DIR}/tmp/dev-branches-before.txt"
    git -C "$REPO_ROOT" log --all --oneline --graph -30 > "${DIR}/tmp/git-graph-before.txt"
    git -C "$REPO_ROOT" branch -vv > "${DIR}/tmp/all-branches-before.txt"

    echo -e "${GREEN}✓ State saved to ${DIR}/tmp/${NC}"
    echo "  - dev-branches-before.txt"
    echo "  - git-graph-before.txt"
    echo "  - all-branches-before.txt"
}
# }}}

# -- {{{ check_worktrees
check_worktrees() {
    echo
    echo -e "${CYAN}Checking for active worktrees...${NC}"

    local worktrees=$(git -C "$REPO_ROOT" worktree list | grep -v "^$REPO_ROOT" | wc -l)

    if [[ $worktrees -gt 0 ]]; then
        echo -e "${YELLOW}Warning: Found $worktrees active worktrees${NC}"
        git -C "$REPO_ROOT" worktree list
        echo
        echo "These will continue to work after migration."
    else
        echo -e "${GREEN}✓ No active worktrees${NC}"
    fi
}
# }}}

# -- {{{ merge_dev_branches
merge_dev_branches() {
    echo
    echo -e "${BOLD}Merging /dev branches to master${NC}"
    echo "=================================="
    echo

    cd "$REPO_ROOT" || return 1

    # Get all /dev branches
    local dev_branches=($(git branch --list '*/dev' | sed 's/^[ *]*//'))

    if [[ ${#dev_branches[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ No /dev branches found${NC}"
        return 0
    fi

    echo "Found ${#dev_branches[@]} dev branches: ${dev_branches[@]}"
    echo

    # Ensure we're on master
    git checkout master || {
        echo -e "${RED}✗ Failed to checkout master${NC}"
        return 1
    }

    # Merge each /dev branch
    for dev_branch in "${dev_branches[@]}"; do
        echo -e "${CYAN}Merging ${dev_branch}...${NC}"

        # Check if branch has commits not in master
        local ahead=$(git rev-list --count master..${dev_branch} 2>/dev/null)

        if [[ $ahead -eq 0 ]]; then
            echo -e "${GREEN}✓ ${dev_branch} has no new commits, skipping${NC}"
            continue
        fi

        echo "  ${dev_branch} is $ahead commits ahead of master"

        # Attempt merge
        git merge --no-edit ${dev_branch} || {
            echo
            echo -e "${RED}✗ CONFLICT merging ${dev_branch}${NC}"
            echo
            echo "To resolve:"
            echo "  1. Fix conflicts in the files listed above"
            echo "  2. git add <resolved-files>"
            echo "  3. git merge --continue"
            echo "  4. Re-run this script"
            echo
            return 1
        }

        echo -e "${GREEN}✓ Merged ${dev_branch} to master${NC}"
        echo
    done

    echo -e "${GREEN}✓ All /dev branches merged to master${NC}"
    return 0
}
# }}}

# -- {{{ delete_dev_branches
delete_dev_branches() {
    echo
    echo -e "${BOLD}Deleting /dev branches${NC}"
    echo "======================"
    echo

    cd "$REPO_ROOT" || return 1

    # Get all /dev branches
    local dev_branches=($(git branch --list '*/dev' | sed 's/^[ *]*//'))

    if [[ ${#dev_branches[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ No /dev branches to delete${NC}"
        return 0
    fi

    for dev_branch in "${dev_branches[@]}"; do
        echo -e "${CYAN}Deleting ${dev_branch}...${NC}"

        git branch -d ${dev_branch} || {
            echo -e "${YELLOW}Warning: Could not delete ${dev_branch} (use -D to force)${NC}"
            echo -n "Force delete ${dev_branch}? [y/N]: "
            read -r response

            if [[ "$response" =~ ^[Yy]$ ]]; then
                git branch -D ${dev_branch}
                echo -e "${GREEN}✓ Force deleted ${dev_branch}${NC}"
            else
                echo "Skipped ${dev_branch}"
            fi
        }
    done

    echo
    echo -e "${GREEN}✓ /dev branches deleted${NC}"
    return 0
}
# }}}

# -- {{{ verify_migration
verify_migration() {
    echo
    echo -e "${BOLD}Verification${NC}"
    echo "============"
    echo

    cd "$REPO_ROOT" || return 1

    # Check current branch
    local current_branch=$(git symbolic-ref --short HEAD)
    echo -e "Current branch: ${GREEN}${current_branch}${NC}"

    if [[ "$current_branch" != "master" ]]; then
        echo -e "${YELLOW}Warning: Not on master${NC}"
    fi

    # Check for remaining /dev branches
    local remaining_dev=$(git branch --list '*/dev' | wc -l)

    if [[ $remaining_dev -eq 0 ]]; then
        echo -e "${GREEN}✓ No /dev branches remain${NC}"
    else
        echo -e "${YELLOW}Warning: Found ${remaining_dev} remaining /dev branches${NC}"
        git branch --list '*/dev'
    fi

    # Show issue branches
    echo
    echo "Remaining issue branches:"
    git branch --list '*/issue-*' | head -10

    echo
    echo -e "${GREEN}✓ Migration verification complete${NC}"
}
# }}}

# -- {{{ main
main() {
    echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║    Project /dev Branch Migration Script             ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
    echo
    echo "This script will:"
    echo "  1. Save current branch state"
    echo "  2. Merge all project/dev branches to master"
    echo "  3. Delete all project/dev branches"
    echo "  4. Verify the migration"
    echo
    echo -e "${YELLOW}Note: This operation is mostly reversible via git reflog${NC}"
    echo
    echo -n "Continue? [y/N]: "
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Migration cancelled"
        exit 0
    fi

    echo

    # Execute migration steps
    save_current_state || exit 1
    check_worktrees || exit 1
    merge_dev_branches || exit 1
    delete_dev_branches || exit 1
    verify_migration || exit 1

    echo
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Migration complete!${NC}"
    echo
    echo "Main repository is now on master (locked)."
    echo "All issue branches will now branch from master."
    echo
    echo "Next steps:"
    echo "  1. Review git log to verify merges"
    echo "  2. Commit any changes to scripts/documentation"
    echo "  3. Continue development in worktrees"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
}
# }}}

main "$@"
