# Git Worktree Instructions for AI Agents

**Read this before starting work on any issue.**

## Quick Reference

| Action | Command |
|--------|---------|
| List worktrees | `./delta-version/scripts/manage-worktree.sh list` |
| Create worktree | `./delta-version/scripts/manage-worktree.sh create <issue-num> <project>` |
| Get path | `./delta-version/scripts/manage-worktree.sh path <issue-num> <project>` |
| Check status | `./delta-version/scripts/manage-worktree.sh status` |
| Remove worktree | `./delta-version/scripts/manage-worktree.sh remove <issue-num> <project>` |

**Projects**: `delta-version`, `neocities-modernization`, `world-edit-to-execute`

## Before Starting Work

1. Check if a worktree exists for your issue:
   ```bash
   cd /mnt/mtwo/programming/ai-stuff
   ./delta-version/scripts/manage-worktree.sh list
   ```

2. If not, create one:
   ```bash
   ./delta-version/scripts/manage-worktree.sh create 017 delta-version
   ```

3. Work in the worktree, NOT the main repo:
   ```bash
   cd $(./delta-version/scripts/manage-worktree.sh path 017 delta-version)
   ```

## Critical Rules

- **NEVER** checkout branches in `/mnt/mtwo/programming/ai-stuff/` for development
- **ALWAYS** work in `/mnt/mtwo/programming/ai-worktrees/<project-short>/<issue>/`
- **COMMIT FREQUENTLY** to preserve work
- The main repo stays on `master` branch

## When Done

1. Commit all changes in the worktree
2. From main repo, merge to project dev branch:
   ```bash
   cd /mnt/mtwo/programming/ai-stuff
   git checkout dv/dev
   git merge dv/issue-017
   ```
3. Remove worktree: `./delta-version/scripts/manage-worktree.sh remove 017 delta-version`

## Full Documentation

See [worktree-guide.md](worktree-guide.md) for complete documentation.
