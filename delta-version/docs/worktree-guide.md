# Git Worktree Guide for Multi-Agent Development

This guide explains how to use git worktrees for parallel development, enabling multiple AI agents to work on the same project simultaneously without conflicts.

## Overview

Git worktrees allow you to have multiple working directories connected to the same repository. Each worktree has its own branch checked out, so agents can work independently without overwriting each other's uncommitted changes.

### Why Worktrees?

The traditional git workflow has a limitation: only ONE branch can be checked out per working directory. This breaks when:
- Agent A is working on issue-038 with uncommitted changes
- Agent B checks out issue-016 in the same directory
- Agent A's work is overwritten or causes conflicts

Worktrees solve this by giving each issue its own directory with its own branch.

## Directory Structure

```
/mnt/mtwo/programming/
    ├── ai-stuff/                         ← Main repo (master branch)
    │   ├── .git/                          ← Shared git repository
    │   ├── delta-version/
    │   ├── neocities-modernization/
    │   └── world-edit-to-execute/
    │
    └── ai-worktrees/                      ← Worktree root (outside main repo)
        ├── dv/                            ← delta-version worktrees
        │   ├── issue-017/                 ← Full repo copy on dv/issue-017 branch
        │   │   ├── delta-version/
        │   │   ├── neocities-modernization/
        │   │   └── world-edit-to-execute/
        │   └── issue-038/
        ├── neo/                           ← neocities-modernization worktrees
        │   └── issue-8-030/
        └── wete/                          ← world-edit-to-execute worktrees
            └── issue-800/
```

## Branch Hierarchy

```
master                                    ← Stable, merged at phase completion
├── dv/dev                                ← delta-version development branch
│   ├── dv/issue-017                      ← Issue branch (in worktree)
│   └── dv/issue-038                      ← Issue branch (in worktree)
├── neo/dev                               ← neocities-modernization dev branch
│   └── neo/issue-8-030
└── wete/dev                              ← world-edit-to-execute dev branch
    └── wete/issue-800
```

### Merge Flow

1. **Issue → Project Dev**: When an issue is complete, merge to the project's dev branch
2. **Project Dev → Master**: When a phase is complete, merge dev branch to master

## Using the Management Script

The worktree management script is located at:
```
/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh
```

### Commands

#### Create a Worktree

```bash
./scripts/manage-worktree.sh create <issue-number> <project>

# Examples:
./scripts/manage-worktree.sh create 017 delta-version
./scripts/manage-worktree.sh create 8-030 neocities-modernization
./scripts/manage-worktree.sh create 800 world-edit-to-execute
```

This creates:
- A new branch: `dv/issue-017` (branched from `dv/dev`)
- A new directory: `/mnt/mtwo/programming/ai-worktrees/dv/issue-017/`

#### List Active Worktrees

```bash
# List all worktrees
./scripts/manage-worktree.sh list

# List worktrees for a specific project
./scripts/manage-worktree.sh list delta-version
```

#### Check Worktree Status

```bash
./scripts/manage-worktree.sh status
```

Shows all active worktrees with uncommitted change counts.

#### Get Worktree Path

```bash
./scripts/manage-worktree.sh path 017 delta-version
# Output: /mnt/mtwo/programming/ai-worktrees/dv/issue-017/delta-version
```

#### Remove a Worktree

```bash
./scripts/manage-worktree.sh remove 017 delta-version
```

**Note**: This will fail if there are uncommitted changes. Commit or stash first.

## Workflow for AI Agents

### Starting Work on an Issue

1. **Check if worktree exists**:
   ```bash
   cd /mnt/mtwo/programming/ai-stuff
   ./delta-version/scripts/manage-worktree.sh list
   ```

2. **Create worktree if needed**:
   ```bash
   ./delta-version/scripts/manage-worktree.sh create 017 delta-version
   ```

3. **Navigate to the worktree**:
   ```bash
   cd $(./delta-version/scripts/manage-worktree.sh path 017 delta-version)
   # Now in: /mnt/mtwo/programming/ai-worktrees/dv/issue-017/delta-version/
   ```

4. **Work normally**: Edit files, run tests, etc.

5. **Commit frequently**:
   ```bash
   git add -A
   git commit -m "Description of changes"
   ```

### Completing an Issue

1. **Ensure all changes are committed** in the worktree

2. **From the main repository**, merge issue to project dev:
   ```bash
   cd /mnt/mtwo/programming/ai-stuff
   git checkout dv/dev
   git merge dv/issue-017
   ```

3. **Remove the worktree**:
   ```bash
   ./delta-version/scripts/manage-worktree.sh remove 017 delta-version
   ```

4. **Optionally delete the branch**:
   ```bash
   git branch -d dv/issue-017
   ```

### Completing a Phase

When all issues in a phase are merged to the project dev branch:

1. **Merge dev to master**:
   ```bash
   cd /mnt/mtwo/programming/ai-stuff
   git checkout master
   git merge dv/dev
   ```

2. **Optionally tag the release**:
   ```bash
   git tag delta-version-phase-4
   ```

3. **Return to dev branch for continued work**:
   ```bash
   git checkout dv/dev
   ```

## Project Short Names

| Full Name                   | Short Name | Dev Branch  |
|-----------------------------|------------|-------------|
| delta-version               | dv         | dv/dev      |
| neocities-modernization     | neo        | neo/dev     |
| world-edit-to-execute       | wete       | wete/dev    |

## Important Rules

### DO:
- Always work in a worktree, never directly in the main repo for issue work
- Commit frequently to preserve work
- Check `manage-worktree.sh status` before major operations
- Merge completed issues to the project dev branch promptly

### DON'T:
- Checkout branches directly in `/mnt/mtwo/programming/ai-stuff/` for development
- Leave worktrees with uncommitted changes for extended periods
- Create worktrees for the same issue multiple times (remove first)
- Merge issue branches directly to master (go through project dev branch)

## Troubleshooting

### "Worktree has uncommitted changes"

The remove command won't delete a worktree with uncommitted changes:
```bash
# Option 1: Commit the changes
cd /mnt/mtwo/programming/ai-worktrees/dv/issue-017
git add -A && git commit -m "Final changes"

# Option 2: Stash the changes
git stash

# Option 3: Discard changes (caution!)
git checkout -- .
```

### "Worktree already exists"

Either the worktree exists and you should use it, or a previous worktree wasn't cleaned up:
```bash
# Check status
./scripts/manage-worktree.sh status

# If stale, force prune
git worktree prune
```

### Merge Conflicts

Resolve in the main repo after merging:
```bash
cd /mnt/mtwo/programming/ai-stuff
git checkout dv/dev
git merge dv/issue-017
# If conflicts:
#   1. Edit conflicting files
#   2. git add <resolved-files>
#   3. git commit
```

## Environment Variables

The script supports these environment variables for customization:

| Variable       | Default                                  | Description           |
|----------------|------------------------------------------|-----------------------|
| DIR            | /mnt/mtwo/programming/ai-stuff           | Main repository path  |
| WORKTREE_ROOT  | /mnt/mtwo/programming/ai-worktrees       | Worktree storage path |

## Related Documents

- [Issue 041: Git Worktree Multi-Agent Architecture](../issues/041-git-worktree-multi-agent-architecture.md)
- [Development Guide](development-guide.md)
- [Issue 005: Configure Branch Isolation](../issues/005-configure-branch-isolation.md)
