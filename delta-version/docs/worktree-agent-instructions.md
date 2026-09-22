# Git Worktree Instructions for AI Agents

> **Deprecated (2026-09-22).** Do not start new work in a worktree. Work on
> `master` in the main tree, stage only your own lines with
> `stage-own-changes`, and commit the index (see the issue-lifecycle skill
> and `scripts/issues/032-commit-only-your-own-lines.md`). If you find an
> existing worktree, its results are to be migrated into the main tree --
> compare its commits against master first, since most such work has
> already landed there -- and the worktree then removed.

**Read this before starting work on an issue in its own worktree.**

A worktree is a second checkout of the same repository in another folder,
on its own branch, sharing one `.git` store. Two agents in two worktrees can
edit the same project without touching each other's files; their work meets
again when a branch is merged.

Every command below uses absolute paths and `git -C <folder>`. None of them
changes the shell's working directory: the working directory belongs to the
person at the terminal, and the directory-change gate refuses `cd`. Give
tools the folder instead.

## Quick Reference

| Action | Command |
|--------|---------|
| List worktrees | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh list` |
| Create worktree | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh create <issue-num> <project>` |
| Get path | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh path <issue-num> <project>` |
| Check status | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh status` |
| Remove worktree | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh remove <issue-num> <project>` |

**Projects the script knows**: its list is written into `manage-worktree.sh`
itself; run it with no arguments to see the current list. A project not on
it needs adding there first.

## Before Starting Work

1. Check whether a worktree exists for the issue:
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh list
   ```

2. If not, create one:
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh create 017 delta-version
   ```

3. Ask for its folder once, and use that folder in every later command:
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh path 017 delta-version
   ```
   Then edit files by their absolute path inside that folder, and run git
   as `git -C <that folder> ...`.

## Rules

- Do development in `/mnt/mtwo/programming/ai-worktrees/<project-short>/<issue>/`,
  not in `/mnt/mtwo/programming/ai-stuff/`.
- The main repository is held on `master` by a post-checkout hook.
- Create worktrees for root issues (`041`), not sub-issues (`041a`, `041b`);
  sub-issues are worked in their root issue's worktree.
- Commit the way the house gates require everywhere: stage only your own
  lines, commit the index. The gates apply inside a worktree exactly as they
  do in the main checkout.

## When Done

1. Commit your work in the worktree (`git -C <worktree folder> ...`).
2. Merge into master from the main checkout, without moving there:
   ```bash
   git -C /mnt/mtwo/programming/ai-stuff merge dv/issue-017
   ```
3. Remove the worktree:
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh remove 017 delta-version
   ```

## Claude Code's own worktrees

Claude Code can also give a helper agent a throwaway worktree of its own
(the agent tool's worktree isolation), created and cleaned up by the harness.
That is the simpler choice for a short, self-contained task: nothing to
create or remove by hand. Use `manage-worktree.sh` when the work should
live on a named issue branch (`dv/issue-017`) that outlasts one session and
gets merged deliberately.

## Full Documentation

See [worktree-guide.md](worktree-guide.md) for complete documentation.
