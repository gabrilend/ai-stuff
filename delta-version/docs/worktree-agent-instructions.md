# Git Worktree Instructions for AI Agents

**Read this before starting work on an issue in its own worktree.**

A worktree is a second checkout of the same repository in another folder,
sharing one `.git` store. Every worktree `manage-worktree.sh` makes starts
from `origin/main`, freshly fetched: either detached, or on a `claude/` or
`feature/` branch you name. Work goes back to `main` through a pull request.
There are no `/dev` branches, and the script never makes one.

Most work does not need a worktree: work on main in the main tree, stage
only your own lines with `stage-own-changes`, and commit the index (see the
issue-lifecycle skill and `scripts/issues/032-commit-only-your-own-lines.md`).

Every command below uses absolute paths and `git -C <folder>`. None of them
changes the shell's working directory: the working directory belongs to the
person at the terminal, and the directory-change gate refuses `cd`. Give
tools the folder instead.

## Quick Reference

| Action | Command |
|--------|---------|
| List worktrees | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh list` |
| Create (detached) | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh create <issue-num> <project>` |
| Create on a branch | `... create <issue-num> <project> --branch claude/<name>` |
| Get path | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh path <issue-num> <project>` |
| Check status | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh status` |
| Remove worktree | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh remove <issue-num> <project>` |

**Projects**: any top-level directory of the repository.

## Before Starting Work

1. Check whether a worktree exists for the issue:
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh list
   ```

2. If not, create one. Name a branch if the work will be pushed:
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh create 017 delta-version --branch claude/017-keywords
   ```

3. Ask for its folder once, and use that folder in every later command:
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh path 017 delta-version
   ```
   Then edit files by their absolute path inside that folder, and run git
   as `git -C <that folder> ...`.

## Rules

- Branches are `claude/<name>` or `feature/<name>`; never a `/dev` branch.
- Create worktrees for root issues (`041`), not sub-issues (`041a`, `041b`);
  sub-issues are worked in their root issue's worktree.
- Commit the way the house gates require everywhere: stage only your own
  lines, commit the index. The gates apply inside a worktree exactly as they
  do in the main checkout.
- Don't commit on a detached worktree you mean to keep: `remove` refuses to
  drop commits no branch holds, but put them on a branch
  (`git -C <worktree> switch -c claude/<name>`) before you rely on them.

## When Done

1. Commit your work in the worktree (`git -C <worktree folder> ...`).
2. Push the branch and open a pull request against `main`:
   ```bash
   git -C <worktree folder> push -u origin claude/017-keywords
   ```
3. Remove the worktree (its branch is kept):
   ```bash
   /mnt/mtwo/programming/ai-stuff/delta-version/scripts/manage-worktree.sh remove 017 delta-version
   ```

## Claude Code's own worktrees

Claude Code can also give a helper agent a throwaway worktree of its own
(the agent tool's worktree isolation), created and cleaned up by the harness.
That is the simpler choice for a short, self-contained task: nothing to
create or remove by hand. Use `manage-worktree.sh` when the work should live
on a named branch that outlasts one session and goes to `main` by pull
request.

## Full Documentation

See [worktree-guide.md](worktree-guide.md) for complete documentation.
