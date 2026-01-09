# Issue 045: Multi-Agent Branch Synchronization Architecture

---

## ⚠️ SUPERSEDED BY ISSUE 046

**Status**: CLOSED - Superseded by simpler solution
**Date**: 2026-01-08
**Superseded by**: Issue 046 (Simplify Branch Architecture)

**Reason**: This issue proposed adding a synchronization script to keep project `/dev` branches in sync. However, Issue 046 implemented a simpler solution: removing `/dev` branches entirely. By having issue branches merge directly to master, the synchronization problem disappears completely.

**Implementation**: All `/dev` branches have been merged to master and deleted. The main repository is now locked to the master branch via git hook. This eliminates:
- Branch confusion (agents committing to wrong branches)
- Duplicate work (agents can't see each other's changes)
- Branch divergence (no more isolated branch islands)

See Issue 046 for the implemented solution.

---

## Original Vision (Archived)

Multiple AI agents working in parallel across different projects should be able to see each other's completed work to avoid duplicate effort, conflicting changes, and branch divergence. The git branch architecture must support both parallel development and proper integration.

## Current Behavior (PROBLEMS)

### 1. Branch Divergence

The current architecture creates isolated "branch islands":

```
Current State (2026-01-08):
* eabc7343 (dv/dev)      Fix: Add authorship-tool...
*   67e4d39d             Merge branch 'master' into dv/dev
|\
* | c66056d8 (dv/issue-042)
| | * 0103fc8f (wete/dev) Fix load balancing...
| | * 3234ab88           Fix: Add authorship-tool... [DUPLICATE!]
| |/
| * 0f6db22a (master)    Update worktree documentation...
|/
* dc8ee3fe (origin/master)
```

**Problem**:
- `dv/dev` is 3 commits ahead of `master`
- `wete/dev` is 4 commits ahead of `master`
- They've completely diverged from each other

### 2. Duplicate Work

Evidence from git log:
- `dv/dev` commit `eabc7343`: "Fix: Add authorship-tool to manage-worktree.sh valid projects"
- `wete/dev` commit `3234ab88`: "Fix: Add authorship-tool to manage-worktree.sh valid projects"

**Two agents independently made the same fix** because they couldn't see each other's work.

### 3. Missing Files Across Projects

```bash
$ git diff --stat dv/dev wete/dev
delta-version/issues/043-issue-initialization-workflow.md    |  470 ---------
delta-version/scripts/check-utilities.sh                     | 1013 --------------------
delta-version/scripts/initialize-issue.sh                    |  462 ---------
world-edit-to-execute/docs/render-threading-v2.md            |   57 +-
world-edit-to-execute/issues/110-object-data-parsers.md      |  moved
```

**Files created by Agent A (working on dv/issue-042) are invisible to Agent B (working on wete/issue-XXX).**

### 4. Workflow Gap

Current workflow:
```
1. Agent A: master → dv/dev → dv/issue-042 → merge to dv/dev
2. Agent B: master → wete/dev → wete/issue-123 → merge to wete/dev

MISSING STEP: No mechanism to sync dv/dev and wete/dev back to master
```

Result: Changes never propagate between projects.

### 5. Conflicting Shared File Changes

Both projects may modify:
- `delta-version/scripts/*` (shared utilities)
- `delta-version/issues/*` (infrastructure issues)
- `delta-version/docs/*` (documentation)
- Root-level files (`.gitignore`, etc.)

Without synchronization, these changes conflict when eventually merged.

## Intended Behavior

Agents should be able to:
1. Work in parallel without blocking each other
2. See completed work from other agents within reasonable time
3. Avoid duplicate effort on shared infrastructure
4. Merge changes without massive conflicts

## Root Cause Analysis

The architecture was designed with this hierarchy:
```
master
  ├── dv/dev
  │   ├── dv/issue-041
  │   ├── dv/issue-042
  │   └── dv/issue-043
  ├── wete/dev
  │   ├── wete/issue-110
  │   └── wete/issue-123
  └── neo/dev
      └── neo/issue-008
```

**The problem**: `project/dev` branches were intended as integration points **within each project**, but there's **no integration point across projects**.

## Proposed Solutions

### Option A: Periodic Synchronization (Recommended)

**Workflow**:
```
1. Agent completes issue-042 in dv/issue-042
2. Merge to dv/dev: git merge dv/issue-042
3. **NEW**: Sync to master: git checkout master && git merge dv/dev
4. **NEW**: Sync other projects: git checkout wete/dev && git merge master
```

**Pros**:
- Preserves project/dev branches as integration layers
- Changes propagate across all projects
- Agents can see each other's work after sync

**Cons**:
- Requires explicit sync step
- Possible merge conflicts during sync
- More complex workflow

**Sync Frequency**: After each completed issue, or daily

### Option B: Direct-to-Master

**Workflow**:
```
1. Branch from master: master → project/issue-042
2. Complete work in worktree
3. Merge directly to master: git checkout master && git merge project/issue-042
4. Remove project/dev branches entirely
```

**Pros**:
- Simple linear history
- All changes immediately visible
- No synchronization needed

**Cons**:
- Loses project-level integration testing
- Master can become unstable
- No project-specific staging area

### Option C: Integration Branch

**Workflow**:
```
1. Create single integration branch: integration
2. All project/dev branches merge to integration
3. Agents branch from integration instead of master
4. Periodic integration → master merges
```

**Pros**:
- Centralized integration point
- Master stays stable
- Projects can still have dev branches

**Cons**:
- Adds another layer
- More complex
- Integration branch can accumulate conflicts

### Option D: Rebase Strategy

**Workflow**:
```
1. Before merging, rebase on master: git rebase master
2. Force project/dev to track master: git rebase master project/dev
3. Keep project/dev branches in sync with master
```

**Pros**:
- Linear history
- No merge commits
- Always up-to-date

**Cons**:
- Rewriting history is dangerous with multiple agents
- Can lose work if done incorrectly
- Conflicts during rebase

## Recommended Solution: Option A with Automation

Implement Option A with a script that automates synchronization:

### Implementation: `sync-branches.sh`

```bash
#!/usr/bin/env bash
# sync-branches.sh - Synchronize project dev branches via master
#
# Ensures all project dev branches stay synchronized by routing changes
# through master as a central integration point.

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/..\" && pwd)}"
REPO_ROOT="$(dirname "$DIR")"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# -- {{{ sync_to_master
sync_to_master() {
    local project_dev="$1"

    echo -e "${YELLOW}Syncing ${project_dev} to master...${NC}"

    # Check if there are commits to sync
    local ahead=$(git rev-list --count master..${project_dev} 2>/dev/null)

    if [[ $ahead -eq 0 ]]; then
        echo -e "${GREEN}✓ ${project_dev} is up to date with master${NC}"
        return 0
    fi

    echo "  ${project_dev} is $ahead commits ahead of master"

    # Merge to master
    git checkout master || return 1
    git merge --no-edit ${project_dev} || {
        echo -e "${RED}✗ Conflict merging ${project_dev} to master${NC}"
        echo "  Resolve conflicts manually and run: git merge --continue"
        return 1
    }

    echo -e "${GREEN}✓ Merged ${project_dev} to master${NC}"
    return 0
}
# }}}

# -- {{{ sync_from_master
sync_from_master() {
    local project_dev="$1"

    echo -e "${YELLOW}Syncing master to ${project_dev}...${NC}"

    # Check if there are commits to pull
    local behind=$(git rev-list --count ${project_dev}..master 2>/dev/null)

    if [[ $behind -eq 0 ]]; then
        echo -e "${GREEN}✓ ${project_dev} is up to date with master${NC}"
        return 0
    fi

    echo "  ${project_dev} is $behind commits behind master"

    # Merge from master
    git checkout ${project_dev} || return 1
    git merge --no-edit master || {
        echo -e "${RED}✗ Conflict merging master to ${project_dev}${NC}"
        echo "  Resolve conflicts manually and run: git merge --continue"
        return 1
    }

    echo -e "${GREEN}✓ Merged master to ${project_dev}${NC}"
    return 0
}
# }}}

# -- {{{ sync_all_projects
sync_all_projects() {
    echo "Git Branch Synchronization"
    echo "=========================="
    echo

    cd "$REPO_ROOT" || return 1

    # Get all project dev branches
    local project_devs=($(git branch --list '*/dev' | sed 's/^[ *]*//' | tr '\n' ' '))

    if [[ ${#project_devs[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No project dev branches found${NC}"
        return 0
    fi

    echo "Found project branches: ${project_devs[@]}"
    echo

    # Phase 1: Sync all project/dev branches TO master
    echo "Phase 1: Collecting changes to master"
    echo "--------------------------------------"
    for project_dev in "${project_devs[@]}"; do
        sync_to_master "$project_dev" || return 1
    done

    echo

    # Phase 2: Sync master TO all project/dev branches
    echo "Phase 2: Distributing changes from master"
    echo "------------------------------------------"
    for project_dev in "${project_devs[@]}"; do
        sync_from_master "$project_dev" || return 1
    done

    echo
    echo -e "${GREEN}✓ All branches synchronized${NC}"
}
# }}}

# -- {{{ main
main() {
    local mode="${1:-all}"

    case "$mode" in
        all)
            sync_all_projects
            ;;
        to-master)
            if [[ -z "$2" ]]; then
                echo "Usage: sync-branches.sh to-master <project/dev>"
                exit 1
            fi
            sync_to_master "$2"
            ;;
        from-master)
            if [[ -z "$2" ]]; then
                echo "Usage: sync-branches.sh from-master <project/dev>"
                exit 1
            fi
            sync_from_master "$2"
            ;;
        *)
            cat <<EOF
Usage: sync-branches.sh [COMMAND] [OPTIONS]

COMMANDS:
    all                 Sync all project dev branches (default)
    to-master <branch>  Sync specific project/dev to master
    from-master <branch> Sync master to specific project/dev

EXAMPLES:
    sync-branches.sh
        Synchronize all project dev branches

    sync-branches.sh to-master dv/dev
        Merge dv/dev into master

    sync-branches.sh from-master wete/dev
        Merge master into wete/dev

WORKFLOW:
    1. Agent completes work in project/issue-XXX
    2. Merges to project/dev
    3. Run sync-branches.sh to propagate changes
    4. All agents now see the changes
EOF
            exit 0
            ;;
    esac
}
# }}}

main "$@"
```

## Updated Workflow with Synchronization

### For Each Completed Issue

```bash
# 1. Complete work in worktree
cd /mnt/mtwo/programming/ai-worktrees/dv/issue-042/delta-version
git add .
git commit -m "Issue 042: Complete utility health checker"

# 2. Merge to project dev branch
cd /mnt/mtwo/programming/ai-stuff
git checkout dv/dev
git merge dv/issue-042

# 3. NEW STEP: Synchronize all branches
./delta-version/scripts/sync-branches.sh

# 4. Remove worktree
./delta-version/scripts/manage-worktree.sh remove 042 delta-version
```

### Automated in initialize-issue.sh

Update `initialize-issue.sh` completion instructions to include sync step.

## Additional Safeguards

### 1. Pre-Branch Sync Check

Before creating new worktree, sync from master:

```bash
# In manage-worktree.sh create command
git checkout ${project_short}/dev
git merge master --ff-only || {
    echo "Warning: Cannot fast-forward. Run sync-branches.sh first"
    exit 1
}
```

### 2. Sync Monitoring

Add to `check-utilities.sh`:

```bash
# Check for diverged branches
check_branch_divergence() {
    for dev_branch in $(git branch --list '*/dev'); do
        local behind=$(git rev-list --count ${dev_branch}..master)
        local ahead=$(git rev-list --count master..${dev_branch})

        if [[ $ahead -gt 5 ]] || [[ $behind -gt 5 ]]; then
            echo "WARNING: ${dev_branch} is $ahead ahead, $behind behind master"
            echo "  Run: ./delta-version/scripts/sync-branches.sh"
        fi
    done
}
```

### 3. Commit Hook Integration

Create post-merge hook to suggest syncing:

```bash
# .git/hooks/post-merge
#!/bin/bash
branch=$(git symbolic-ref --short HEAD)

if [[ $branch =~ /dev$ ]]; then
    echo "✓ Merged to ${branch}"
    echo "Consider syncing: ./delta-version/scripts/sync-branches.sh"
fi
```

## Testing Plan

### Test 1: Parallel Development

```bash
# Agent A
./manage-worktree.sh create 046 delta-version
cd /mnt/mtwo/programming/ai-worktrees/dv/issue-046/delta-version
echo "test" > test-a.txt
git add test-a.txt && git commit -m "Test A"
cd /mnt/mtwo/programming/ai-stuff
git checkout dv/dev && git merge dv/issue-046

# Agent B (before sync)
./manage-worktree.sh create 200 world-edit-to-execute
cd /mnt/mtwo/programming/ai-worktrees/wete/issue-200/world-edit-to-execute
ls -la ../../../ai-stuff/delta-version/  # Should NOT see test-a.txt

# Sync
cd /mnt/mtwo/programming/ai-stuff
./delta-version/scripts/sync-branches.sh

# Agent B (after sync)
cd /mnt/mtwo/programming/ai-worktrees/wete/issue-200
git pull  # Update worktree
ls -la ../../../ai-stuff/delta-version/  # Should NOW see test-a.txt
```

### Test 2: Conflict Resolution

```bash
# Agent A: Modify shared file
# Agent B: Modify same file
# Run sync and verify conflict detection
```

### Test 3: Cross-Project Dependencies

```bash
# Agent A creates delta-version utility
# Agent B immediately needs it in world-edit-to-execute
# Verify sync makes it available
```

## Impact Analysis

### Files to Create
- `delta-version/scripts/sync-branches.sh` (new)

### Files to Modify
- `delta-version/scripts/initialize-issue.sh` (add sync to completion steps)
- `delta-version/scripts/manage-worktree.sh` (add pre-branch sync check)
- `delta-version/scripts/check-utilities.sh` (add divergence monitoring)
- `delta-version/docs/worktree-agent-instructions.md` (document sync workflow)
- `delta-version/docs/worktree-guide.md` (explain synchronization)

## Migration Plan

### Phase 1: Fix Current Divergence

```bash
# Manual sync to resolve current state
cd /mnt/mtwo/programming/ai-stuff

# Sync dv/dev to master
git checkout master
git merge dv/dev

# Sync wete/dev to master
git merge wete/dev  # May have conflicts - resolve manually

# Sync master back to project branches
git checkout dv/dev
git merge master

git checkout wete/dev
git merge master
```

### Phase 2: Deploy sync-branches.sh

Create and test the synchronization script.

### Phase 3: Update Documentation

Update all references to workflow to include sync step.

### Phase 4: Automation

Integrate sync into issue completion workflow.

## Acceptance Criteria

- [ ] `sync-branches.sh` script created and tested
- [ ] All project/dev branches can sync to master without conflicts
- [ ] Master can sync back to all project/dev branches
- [ ] Duplicate work detection (test with authorship-tool example)
- [ ] Cross-project visibility (files created in one project visible in others)
- [ ] Conflict detection and clear error messages
- [ ] Documentation updated with sync workflow
- [ ] `initialize-issue.sh` includes sync in completion instructions
- [ ] `check-utilities.sh` monitors for divergence

## Metadata

- **Priority**: CRITICAL
- **Complexity**: Medium-High
- **Phase**: 1 (Foundation Infrastructure)
- **Dependencies**: None (fixes broken architecture)
- **Blocks**: All multi-agent development
- **Related Issues**:
  - Issue 041: Git Worktree Multi-Agent Architecture (created the architecture)
  - Issue 043: Issue Initialization Workflow (needs sync integration)

## Notes

This issue represents a **critical architectural flaw** discovered during multi-agent testing. The current branch architecture creates isolated development islands that prevent agents from collaborating effectively.

The recommended solution (Option A with automation) balances:
- **Isolation**: Agents can work independently in worktrees
- **Integration**: Changes propagate through master
- **Safety**: Conflicts are detected early
- **Simplicity**: Automated script handles complexity

Without this fix, agents will continue to:
- Duplicate each other's work
- Create conflicting changes
- Lack visibility into infrastructure improvements
- Accumulate technical debt through branch divergence

**This should be prioritized above new feature development.**
