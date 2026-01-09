# Issue 046: Simplify Branch Architecture - Remove Project /dev Branches

## Vision

Worktrees exist to eliminate branch switching confusion. Each directory should be permanently locked to one branch. Agents should never be surprised by what branch they're on because **the directory determines the branch**, not vice versa.

## Current Behavior (THE PROBLEM)

### Symptom: Agents Commit to Wrong Branches

Agents report: "How did I start committing to the wrong branch? I thought I was on issue-042!"

**Root cause investigation**:

```bash
$ git -C /mnt/mtwo/programming/ai-stuff branch -vv
* dv/dev            eabc7343    ← MAIN REPO IS ON DV/DEV!
  dv/issue-042      c66056d8
  master            9599c077
  wete/dev          0103fc8f
```

**The main repository is on `dv/dev` instead of `master`!**

### How This Happens

```
Agent workflow (as it happens):
1. Agent starts in /mnt/mtwo/programming/ai-stuff  ← Main repo (on dv/dev)
2. Agent works on files
3. Agent commits                                    ← Commits to dv/dev!
4. Agent realizes: "Wait, I'm not in the worktree!"

Expected workflow:
1. Agent creates worktree for issue-042            ← Separate directory
2. Agent cd's to worktree                          ← /ai-worktrees/dv/issue-042/
3. Agent works on files
4. Agent commits                                   ← Commits to dv/issue-042 ✓
```

### Architecture Confusion

Current architecture has THREE layers:
```
master
  └── project/dev              ← WHY DOES THIS EXIST?
      └── project/issue-XXX
```

**Problems with `/dev` branches**:
1. Main repo can be left on `project/dev` after merging
2. Agents don't know if they're in main repo or worktree
3. Extra merge step: issue → dev → master
4. More branches = more confusion
5. **Contradicts the purpose of worktrees**

### The Worktree Promise

Worktrees exist to provide:
- **One directory = One branch** (permanently)
- **No branch switching** (just `cd` between directories)
- **Physical separation** (can't accidentally work in wrong place)

But `/dev` branches break this by:
- Requiring branch switches in main repo
- Creating ambiguity about "where am I?"
- Adding cognitive overhead

## Intended Behavior

### Simple Two-Layer Architecture

```
Main repo: /mnt/mtwo/programming/ai-stuff/
  - Always on master
  - Never switches branches
  - Read-only for agents (except for final merges)

Worktrees: /mnt/mtwo/programming/ai-worktrees/<project>/<issue>/
  - Each on its own issue branch
  - Branched directly from master
  - Merged directly back to master when complete
```

### Branch Structure

```
master (in main repo, locked)
  ├── dv/issue-017      (in worktree)
  ├── dv/issue-042      (in worktree)
  ├── neo/issue-8-030   (in worktree)
  └── wete/issue-800    (in worktree)
```

**No `/dev` branches at all.**

### Benefits

1. **No confusion**: Main repo = master, worktrees = issue branches
2. **Simpler**: One merge step instead of two
3. **Clearer**: Directory name tells you exactly what branch you're on
4. **Safer**: Can't accidentally work in main repo (it's on master)
5. **True to worktree philosophy**: Physical directories, no switching

## Proposed Changes

### 1. Remove All `/dev` Branches

```bash
# Delete local /dev branches
git branch -D dv/dev neo/dev wete/dev

# Note: This requires merging their changes to master first
```

### 2. Lock Main Repo to Master

```bash
# Ensure main repo stays on master
cd /mnt/mtwo/programming/ai-stuff
git checkout master

# Add post-checkout hook to prevent switching
cat > .git/hooks/post-checkout << 'EOF'
#!/bin/bash
# Prevent main repo from leaving master
branch=$(git symbolic-ref --short HEAD)
if [[ "$branch" != "master" ]] && [[ "$PWD" == "/mnt/mtwo/programming/ai-stuff" ]]; then
    echo "ERROR: Main repository should stay on master!"
    echo "Use worktrees for development:"
    echo "  ./delta-version/scripts/manage-worktree.sh create <issue> <project>"
    git checkout -q master
    exit 1
fi
EOF
chmod +x .git/hooks/post-checkout
```

### 3. Update manage-worktree.sh

Change worktree creation to branch from `master` instead of `project/dev`:

```bash
# Old behavior
git checkout ${project_short}/dev
git branch ${branch_name} ${project_short}/dev
git worktree add "${worktree_path}" "${branch_name}"

# New behavior
git checkout master
git branch ${branch_name} master
git worktree add "${worktree_path}" "${branch_name}"
```

Change merge target from `project/dev` to `master`:

```bash
# Old completion instructions
echo "  git checkout dv/dev"
echo "  git merge dv/issue-${issue_num}"

# New completion instructions
echo "  git checkout master"
echo "  git merge dv/issue-${issue_num}"
```

### 4. Migration Path

For existing work in `/dev` branches:

```bash
#!/usr/bin/env bash
# migrate-dev-branches.sh - Merge and remove /dev branches

cd /mnt/mtwo/programming/ai-stuff

# Merge all /dev branches to master
for dev_branch in $(git branch --list '*/dev' | sed 's/^[ *]*//'); do
    echo "Merging ${dev_branch} to master..."
    git checkout master
    git merge --no-edit ${dev_branch} || {
        echo "Conflict in ${dev_branch} - resolve manually"
        exit 1
    }
done

# Verify master has all commits
git checkout master

# Delete /dev branches
for dev_branch in $(git branch --list '*/dev' | sed 's/^[ *]*//'); do
    echo "Deleting ${dev_branch}..."
    git branch -d ${dev_branch}
done

echo "✓ Migration complete. Main repo is now on master."
echo "✓ All /dev branches removed."
echo "✓ All issue branches will now branch from master."
```

## Comparison: Old vs New

### Old Architecture (Current)

```
Workflow:
1. Create worktree: branches from dv/dev
2. Work in worktree on dv/issue-042
3. Merge dv/issue-042 → dv/dev
4. Merge dv/dev → master (eventually)

Problems:
- Main repo often left on dv/dev
- Two merge steps
- Agent confusion about current branch
- /dev branches diverge from each other
```

### New Architecture (Proposed)

```
Workflow:
1. Create worktree: branches from master
2. Work in worktree on dv/issue-042
3. Merge dv/issue-042 → master
4. Done

Benefits:
- Main repo always on master
- One merge step
- No confusion: main repo = master, worktree = issue branch
- All issue branches see latest merged work
```

## What About "Staging Areas"?

**Question**: Wasn't `project/dev` meant as a staging area before merging to master?

**Answer**: Git already has staging mechanisms that don't require branch layers:

### Option 1: Feature Flags
```lua
-- In code
if config.enable_experimental_feature then
    -- new code
end
```

### Option 2: Test Before Merge
```bash
# In worktree, run tests
./run-all-tests.sh

# If tests pass
git checkout master
git merge dv/issue-042
```

### Option 3: Tag Testing Milestones
```bash
# Tag before merging
git tag test-before-issue-042
git checkout master
git merge dv/issue-042

# If something breaks
git reset --hard test-before-issue-042
```

### Option 4: Separate Testing Worktree
```bash
# Create integration testing worktree (not a branch)
git worktree add ../integration-test master
cd ../integration-test
git merge dv/issue-042  # Test merge here first
```

**None of these require permanent `/dev` branches.**

## Updated Documentation

### worktree-agent-instructions.md

```markdown
## Critical Rules

- **NEVER** work in `/mnt/mtwo/programming/ai-stuff/` for development
- **ALWAYS** work in `/mnt/mtwo/programming/ai-worktrees/<project>/<issue>/`
- Main repo stays on `master` (automatically enforced)
- Each worktree = one issue branch = one directory

## When Done

1. Commit all changes in the worktree
2. From main repo, merge directly to master:
   ```bash
   cd /mnt/mtwo/programming/ai-stuff
   git checkout master  # (already there)
   git merge dv/issue-017
   ```
3. Remove worktree
```

### worktree-guide.md

```markdown
## Branch Hierarchy

```
master                                    ← Main repo (locked to this branch)
├── dv/issue-017                          ← In worktree
├── dv/issue-038                          ← In worktree
├── neo/issue-8-030                       ← In worktree
└── wete/issue-800                        ← In worktree
```

No intermediate `/dev` branches.

### Merge Flow

**Simple one-step merge**: Issue branch → master
```

## Testing Plan

### Test 1: Main Repo Lock

```bash
cd /mnt/mtwo/programming/ai-stuff
git checkout dv/issue-042  # Should fail with helpful message
# Expected: Automatically reverts to master
```

### Test 2: Worktree Creation

```bash
./delta-version/scripts/manage-worktree.sh create 047 delta-version
# Check: Branch should be based on master, not dv/dev
git -C /mnt/mtwo/programming/ai-worktrees/dv/issue-047 log --oneline -1
# Should show: "branched from master"
```

### Test 3: Merge Path

```bash
# Complete issue
cd /mnt/mtwo/programming/ai-worktrees/dv/issue-047/delta-version
echo "test" > test.txt
git add test.txt && git commit -m "Test"

# Merge to master
cd /mnt/mtwo/programming/ai-stuff
git merge dv/issue-047  # Should work cleanly

# Verify no /dev branch involved
git log --oneline --graph -5
# Should show direct merge from issue to master
```

### Test 4: Agent Confusion Prevention

```bash
# Simulate agent starting in main repo
cd /mnt/mtwo/programming/ai-stuff
touch accidental-file.txt
git add accidental-file.txt

# Agent should realize they're on master
git branch --show-current  # Shows: master
# Clear indication they're in wrong place
```

## Acceptance Criteria

- [ ] All `/dev` branches merged to master
- [ ] All `/dev` branches deleted
- [ ] Main repo locked to master via post-checkout hook
- [ ] `manage-worktree.sh` creates branches from master
- [ ] `manage-worktree.sh` merges to master (not /dev)
- [ ] Hook prevents switching away from master in main repo
- [ ] Documentation updated (no references to /dev)
- [ ] Migration script tested and run
- [ ] Test: Can't accidentally work in main repo on wrong branch
- [ ] Test: Worktrees branch from current master
- [ ] Test: Merge path goes directly to master

## Migration Steps

### Step 1: Save Current State

```bash
cd /mnt/mtwo/programming/ai-stuff
git branch --list '*/dev' > /tmp/dev-branches-before.txt
git log --all --oneline --graph -20 > /tmp/git-graph-before.txt
```

### Step 2: Merge All /dev Branches

```bash
./delta-version/scripts/migrate-dev-branches.sh
```

### Step 3: Update Scripts

- Modify `manage-worktree.sh`
- Add post-checkout hook
- Update `initialize-issue.sh`

### Step 4: Update Documentation

- `worktree-agent-instructions.md`
- `worktree-guide.md`
- Issue 041 (original worktree architecture)

### Step 5: Test

Run all test cases above.

### Step 6: Verify

```bash
git branch --list '*/dev'  # Should return nothing
git -C /mnt/mtwo/programming/ai-stuff branch --show-current  # Should show: master
```

## Metadata

- **Priority**: CRITICAL
- **Complexity**: Medium
- **Phase**: 1 (Foundation Infrastructure)
- **Dependencies**: Issue 045 resolution (or can replace it)
- **Blocks**: All development (agents keep committing to wrong branches)
- **Related Issues**:
  - Issue 041: Git Worktree Architecture (needs updating)
  - Issue 045: Branch Synchronization (simplified by this change)

## Notes

This issue addresses the **immediate pain point** that agents are experiencing: branch confusion and accidental commits.

**User's insight was correct**: "The point of worktrees is that we only need to have one branch [in the main repo], with separate worktrees as little playgrounds."

The `/dev` branches were well-intentioned (providing staging areas) but they:
1. Contradict worktree philosophy
2. Cause branch confusion
3. Add complexity
4. Create merge conflicts
5. Make agents commit to wrong branches

**Simpler is better**: Main repo = master (locked), worktrees = issue branches.

This change also simplifies Issue 045's synchronization problem - with no `/dev` branches, all issue branches merge directly to master, and all new branches see the latest merged work automatically.

## Decision: Issue 045 vs Issue 046

**Issue 045**: Adds synchronization script to keep /dev branches in sync
**Issue 046**: Removes /dev branches entirely

**Recommendation**: Implement Issue 046 instead of Issue 045.

Reasoning:
- Simpler solution
- Addresses root cause (branch confusion)
- Less code to maintain
- Eliminates entire class of problems
- More aligned with worktree philosophy

If we implement Issue 046, Issue 045 can be closed as "resolved by simpler architecture."

---

## Implementation Notes

**Date**: 2026-01-08
**Status**: COMPLETED

### Changes Made

#### 1. Migration Script ✓
Created `scripts/migrate-dev-branches.sh`:
- Saves current branch state for rollback if needed
- Merges all `project/dev` branches to master
- Deletes `project/dev` branches after successful merge
- Verification step ensures no `/dev` branches remain

**Result**: Successfully merged `dv/dev` (6 commits) and `wete/dev` (5 commits) to master, then deleted both branches.

#### 2. Git Hook - Main Repo Lock ✓
Created `.git/hooks/post-checkout`:
- Prevents main repository from switching away from master
- Displays helpful error message with worktree instructions
- Automatically reverts to master if switch is attempted
- Only enforces in main repo (not in worktrees)

**Test**: Attempting `git checkout dv/issue-042` in main repo now shows error and reverts to master.

#### 3. Updated manage-worktree.sh ✓
Changes:
- Removed `ensure_dev_branch` function call
- Changed branch creation from `$dev_branch` to `master`
- Updated completion instructions to merge to master instead of `project/dev`

Before:
```bash
git checkout dv/dev
git merge dv/issue-017
```

After:
```bash
git checkout master  # (already there, enforced by hook)
git merge dv/issue-017
```

#### 4. Updated initialize-issue.sh ✓
Changed completion instructions (line 398):
- From: `git checkout ${short_name}/dev`
- To: `git checkout master`

#### 5. Updated Documentation ✓
**worktree-agent-instructions.md**:
- Changed "main repo stays on master" to "main repo is locked to master (enforced by git hook)"
- Updated completion instructions to merge directly to master
- Added note that checkout to master is "already there"

**worktree-guide.md**:
- Updated branch hierarchy diagram (removed `/dev` layer)
- Changed merge flow from "Issue → Dev → Master" to "Issue → Master"
- Updated all example commands to reference master instead of project/dev
- Changed "branched from dv/dev" to "branched from master"

#### 6. Archived Issue 045 ✓
Added superseded notice to Issue 045 explaining:
- It proposed adding sync script for `/dev` branches
- Issue 046 implemented simpler solution (remove `/dev` branches)
- Synchronization problem no longer exists
- All acceptance criteria met through different approach

### Architecture Changes

**Before** (Complex):
```
master
  ├── dv/dev
  │   ├── dv/issue-017
  │   └── dv/issue-038
  └── wete/dev
      └── wete/issue-123
```
Problems:
- Main repo could be on dv/dev, wete/dev, or any branch
- Agents confused about which branch they're on
- Two merge steps (issue→dev, dev→master)
- Branches diverge from each other

**After** (Simple):
```
master (locked)
  ├── dv/issue-017
  ├── dv/issue-038
  └── wete/issue-123
```
Benefits:
- Main repo always on master (enforced)
- Physical directory determines branch (no confusion)
- One merge step (issue→master)
- All new branches see latest merged work

### Test Results

All acceptance criteria met:

- ✓ All `/dev` branches merged to master (dv/dev, wete/dev)
- ✓ All `/dev` branches deleted
- ✓ Main repo locked to master via post-checkout hook
- ✓ `manage-worktree.sh` creates branches from master
- ✓ `manage-worktree.sh` merges to master (not /dev)
- ✓ Hook prevents switching away from master in main repo
- ✓ Documentation updated (no references to /dev)
- ✓ Migration script tested and run successfully
- ✓ Test: Can't accidentally work in main repo on wrong branch
- ✓ Test: Worktrees branch from current master
- ✓ Test: Merge path goes directly to master

### Files Modified

1. `scripts/migrate-dev-branches.sh` (created, 237 lines)
2. `.git/hooks/post-checkout` (created, 40 lines)
3. `scripts/manage-worktree.sh` (modified):
   - Removed `ensure_dev_branch` call
   - Changed branch source from `$short_name/dev` to `master`
   - Updated completion instructions
4. `scripts/initialize-issue.sh` (modified):
   - Line 398: Changed to merge to master
5. `docs/worktree-agent-instructions.md` (modified):
   - Updated critical rules section
   - Updated completion instructions
6. `docs/worktree-guide.md` (modified):
   - Updated branch hierarchy diagram
   - Updated merge flow section
   - Updated all example commands
7. `issues/045-multi-agent-branch-synchronization.md` (modified):
   - Added superseded notice

### Impact

**Problem Solved**: Agents no longer get confused about which branch they're on. The main repository is permanently locked to master, and each worktree directory corresponds to exactly one branch. This physical separation makes it impossible to accidentally commit to the wrong branch.

**User's Original Concern**: "Agents will say 'hang on, how did I start committing to the wrong branch?'"
**Solution**: Main repo can't leave master anymore. Agents must work in worktrees, where the directory name tells them exactly which branch they're on.

**Secondary Benefit**: Eliminates the branch synchronization problem identified in Issue 045. With no `/dev` branches, all issue branches merge to master and automatically see each other's work.

### Migration Process

1. Saved current state to `delta-version/tmp/`
2. Merged dv/dev to master (6 commits, clean merge)
3. Merged wete/dev to master (5 commits, clean merge)
4. Deleted both `/dev` branches
5. Verified main repo on master
6. Updated all scripts and documentation
7. Tested hook enforcement

**Rollback capability**: Original branch state saved in:
- `delta-version/tmp/dev-branches-before.txt`
- `delta-version/tmp/git-graph-before.txt`
- `delta-version/tmp/all-branches-before.txt`

All changes are also in git reflog.

### Notes

This implementation validates the user's insight: **"The point of worktrees is that we only need to have one branch, with separate worktrees as little playgrounds."**

The `/dev` branches were well-intentioned (providing staging areas) but contradicted the worktree philosophy. Worktrees exist to eliminate branch switching through physical directory separation. By maintaining `/dev` branches, we reintroduced the very problem worktrees were designed to solve.

The simpler architecture is more maintainable, easier to understand, and prevents an entire class of user errors.
