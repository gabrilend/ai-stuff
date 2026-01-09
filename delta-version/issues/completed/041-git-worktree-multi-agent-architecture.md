# Issue 041: Git Worktree Multi-Agent Architecture

## Current Behavior

All development happens directly on the `master` branch in a single working directory (`/mnt/mtwo/programming/ai-stuff/`). This works for single-agent workflows but breaks when multiple AI agents attempt to work simultaneously:

1. Git can only have ONE branch checked out per working directory
2. If Agent A is on `issue-038` and Agent B checks out `issue-016`, Agent A's uncommitted work is overwritten
3. No isolation between parallel workstreams

## Intended Behavior

Implement a **git worktree** based architecture that enables:

1. **Parallel agent work**: Up to 5 agents working on the same project simultaneously
2. **Issue branch isolation**: Each issue gets its own working directory
3. **Clean merge workflow**: Issue → Project Branch → Master (at phase completion)
4. **Agent-friendly documentation**: Clear instructions in CLAUDE.md for agents to follow

## Architecture

### Directory Structure

```
/mnt/mtwo/programming/
    ├── ai-stuff/                         ← Main repo (master branch)
    │   ├── .git/                          ← Shared git repository
    │   ├── delta-version/
    │   ├── neocities-modernization/
    │   └── world-edit-to-execute/
    │
    └── ai-worktrees/                      ← Worktree root (outside main repo)
        ├── delta-version/                 ← Per-project worktree directory
        │   ├── issue-017-keyword-engine/  ← One worktree per issue
        │   │   └── (full repo copy)
        │   └── issue-036-history-viewer/
        ├── neocities/
        │   └── issue-8-030-example/
        └── world-edit/
            └── issue-800-threadpool/
```

### Branch Hierarchy

```
master                                    ← Stable, merged at phase completion
├── delta-version/dev                     ← Project development branch
│   ├── delta-version/issue-017           ← Issue branch (in worktree)
│   └── delta-version/issue-038           ← Issue branch (in worktree)
├── neocities/dev
│   └── neocities/issue-8-030
└── world-edit/dev
    └── world-edit/issue-800
```

### Workflow

#### Starting Work on an Issue

```bash
# 1. Create worktree for the issue
cd /mnt/mtwo/programming/ai-stuff
./delta-version/scripts/manage-worktree.sh create 017 delta-version

# This creates:
# - Branch: delta-version/issue-017
# - Worktree: /mnt/mtwo/programming/ai-worktrees/delta-version/issue-017/

# 2. Agent works in the worktree directory
cd /mnt/mtwo/programming/ai-worktrees/delta-version/issue-017/delta-version/
# ... make changes, commits ...
```

#### Completing an Issue

```bash
# 1. From main repo, merge issue to project dev branch
cd /mnt/mtwo/programming/ai-stuff
git checkout delta-version/dev
git merge delta-version/issue-017

# 2. Remove the worktree
./delta-version/scripts/manage-worktree.sh remove 017 delta-version

# 3. Delete the issue branch (optional)
git branch -d delta-version/issue-017
```

#### Completing a Phase

```bash
# 1. Merge project dev branch to master
git checkout master
git merge delta-version/dev

# 2. Optionally tag the release
git tag delta-version-phase-4

# 3. Continue development on dev branch
git checkout delta-version/dev
```

## Suggested Implementation Steps

### 1. Create Worktree Management Script

```bash
#!/usr/bin/env bash
# manage-worktree.sh - Create and manage git worktrees for parallel development
#
# Provides isolated working directories for each issue, enabling multiple
# AI agents to work on the same project simultaneously.

set -euo pipefail

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
WORKTREE_ROOT="/mnt/mtwo/programming/ai-worktrees"

# Commands:
#   create <issue-number> <project>   Create worktree for issue
#   remove <issue-number> <project>   Remove worktree
#   list [project]                    List active worktrees
#   status                            Show all worktrees with git status
```

### 2. Create Project Development Branches

```bash
# One-time setup for each project
git checkout -b delta-version/dev master
git checkout -b neocities/dev master
git checkout -b world-edit/dev master
git checkout master
```

### 3. Update CLAUDE.md

Add instructions for agents:
- Always check if working in a worktree
- Read worktree docs before committing
- Follow merge workflow

### 4. Create Worktree Documentation

Document in `docs/worktree-guide.md`:
- When to create worktrees
- Directory structure
- Commit and merge workflow
- Cleanup procedures

## Implementation Tasks

### Task 1: Infrastructure Setup
- [ ] Create worktree root directory: `/mnt/mtwo/programming/ai-worktrees/`
- [ ] Create project dev branches (delta-version/dev, etc.)
- [ ] Verify worktree functionality works with current repo

### Task 2: Management Script
- [ ] Create `scripts/manage-worktree.sh`
- [ ] Implement `create` command
- [ ] Implement `remove` command
- [ ] Implement `list` command
- [ ] Implement `status` command
- [ ] Add validation and error handling

### Task 3: Documentation
- [ ] Create `docs/worktree-guide.md`
- [ ] Update `docs/table-of-contents.md`
- [ ] Add worktree section to CLAUDE.md

### Task 4: Testing
- [ ] Test creating worktree for delta-version issue
- [ ] Test parallel worktrees (2 issues simultaneously)
- [ ] Test merge workflow (issue → dev → master)
- [ ] Test cleanup and removal

## Agent Instructions (for CLAUDE.md)

```markdown
## Git Worktree Workflow

When starting work on an issue:
1. Check if a worktree already exists: `./scripts/manage-worktree.sh list`
2. If not, create one: `./scripts/manage-worktree.sh create <issue-num> <project>`
3. Work in the worktree directory, NOT the main repo
4. Commit frequently to the issue branch
5. When complete, merge to project dev branch from main repo

IMPORTANT:
- The main repo (/mnt/mtwo/programming/ai-stuff/) stays on master
- All development happens in worktrees (/mnt/mtwo/programming/ai-worktrees/)
- Never checkout branches in the main repo for development work
```

## Related Documents

- Issue 005: Configure Branch Isolation
- docs/development-guide.md
- .claude/CLAUDE.md

## Metadata

- **Priority**: High
- **Complexity**: Medium
- **Estimated Time**: 2-3 hours
- **Dependencies**: None
- **Blocks**: Multi-agent parallel development workflows
- **Status**: Ready for implementation

## Success Criteria

- [ ] Worktree management script functional
- [ ] Can create/remove worktrees via script
- [ ] Project dev branches exist (delta-version/dev, etc.)
- [ ] Documentation complete in docs/worktree-guide.md
- [ ] CLAUDE.md updated with agent instructions
- [ ] Tested with 2 parallel worktrees
- [ ] Merge workflow verified (issue → dev → master)
