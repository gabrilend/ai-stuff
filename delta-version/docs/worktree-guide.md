# Git Worktree Guide

A worktree is a second working directory on the same repository. This
project's worktrees all **start from the remote's main** (`origin/main`) and
their work goes back to `main` through a pull request. There are no
per-project `/dev` branches, and nothing depends on a hook in the main
repository (decided in issue 046, 2026-11-02).

Work on main in the main tree is still the everyday way to work: parallel
sessions there are kept apart at commit time by the line ledger and its
commit gate (`scripts/issues/032-commit-only-your-own-lines.md`). Reach for a
worktree when a piece of work needs a checkout of its own, for example to
build a branch for a pull request while the main tree stays as it is.

> **For AI agents:** the examples below `cd` into folders, which is how a
> person at a terminal works. An agent cannot: the directory-change gate
> refuses `cd`, because the shell's working directory belongs to the person.
> Use the same commands with absolute paths and `git -C <folder>` instead;
> [worktree-agent-instructions.md](worktree-agent-instructions.md) spells
> every step out that way.

## Directory Structure

```
/mnt/mtwo/programming/
    ├── ai-stuff/                     ← main repository
    └── ai-worktrees/                 ← worktree root (outside the repository)
        ├── dv/issue-017/             ← a whole-repository checkout
        │   ├── delta-version/
        │   └── ...
        ├── neo/issue-8-030/
        └── authorship-tool/issue-1/
```

Three projects keep the short folder names they had before (`dv`, `neo`,
`wete`) so older worktrees are still found; every other project uses its own
directory name.

## What a Worktree Starts From

| How it is made                                   | Checked out as                          |
|--------------------------------------------------|-----------------------------------------|
| `create <issue> <project>`                       | detached HEAD at `origin/main`          |
| `create <issue> <project> --branch claude/<x>`   | new branch from `origin/main`, no upstream |
| `create <issue> <project> --branch feature/<x>`  | new branch from `origin/main`, no upstream |
| `--branch` naming a branch that already exists   | that branch, where it stands            |

`create` fetches `origin main` first, so the worktree starts from what is
really on the remote, not from a local `main` that may be behind. If the
fetch fails it stops; `--no-fetch` uses the copy you already have.

Branch names must be `claude/<name>` or `feature/<name>`. A name whose last
part is `dev` is refused, as is anything else (`main`, `dv/issue-017`, ...).

## Commands

```bash
./scripts/manage-worktree.sh create 017 delta-version
./scripts/manage-worktree.sh create 017 delta-version --branch claude/017-keywords
./scripts/manage-worktree.sh path 017 delta-version
# → /mnt/mtwo/programming/ai-worktrees/dv/issue-017/delta-version
./scripts/manage-worktree.sh list [project]
./scripts/manage-worktree.sh status
./scripts/manage-worktree.sh remove 017 delta-version [--force]
```

`status` shows, for each worktree, its branch or detached commit, how many
commits it has that are not on `origin/main`, and its uncommitted changes.

`remove` refuses when the worktree has uncommitted changes, and when it is
detached and holds commits that no branch holds (they would be lost). It
never deletes a branch. `--force` removes the worktree anyway.

A project is any top-level directory of the repository; there is no list to
keep up to date.

## Workflow

1. **Create the worktree**, on a branch if the work will be pushed:
   ```bash
   ./delta-version/scripts/manage-worktree.sh create 017 delta-version --branch claude/017-keywords
   ```
2. **Work and commit** in `$(manage-worktree.sh path 017 delta-version)`.
3. **Push the branch and open a pull request** against `main`:
   ```bash
   git push -u origin claude/017-keywords
   ```
4. **Remove the worktree** once the work is pushed:
   ```bash
   ./delta-version/scripts/manage-worktree.sh remove 017 delta-version
   ```

A detached worktree is for looking, testing or throwaway work. If you commit
in one and want to keep it, put it on a branch first:
`git switch -c claude/<name>`.

## Root Issues vs Sub-Issues

Make worktrees for **root issues** only (`041`), not their sub-issues
(`041a`, `041b`). Work through the sub-issues in the root issue's worktree,
one commit each, prefixed with the sub-issue number:

```bash
git commit -m "Issue 041a: Implement worktree creation script"
git commit -m "Issue 041b: Add cleanup and removal logic"
```

`initialize-issue.sh` follows this rule itself: for a sub-issue it reuses,
or makes, the root issue's worktree.

## Troubleshooting

### "Worktree has uncommitted changes"

Commit them (on a branch), or discard them with `remove --force`.

### "Detached worktree has N commit(s) no branch holds"

```bash
git -C <worktree> switch -c claude/<name>   # keep them on a branch
./scripts/manage-worktree.sh remove <issue> <project>
```

### "Worktree already exists"

Use it, or remove it first. If its folder was deleted by hand, clear git's
record of it with `git worktree prune`.

### "Could not fetch origin main"

The remote could not be reached. Try again, or pass `--no-fetch` to start
from the `origin/main` you already have.

## Environment Variables

| Variable       | Default                              | Description              |
|----------------|--------------------------------------|--------------------------|
| DIR            | /mnt/mtwo/programming/ai-stuff       | main repository path     |
| WORKTREE_ROOT  | /mnt/mtwo/programming/ai-worktrees   | worktree storage path    |
| REMOTE         | origin                               | remote to start from     |
| MAIN_BRANCH    | main                                 | branch to start from     |

## Related Documents

- [Issue 046: Simplify Branch Architecture](../issues/completed/046-simplify-branch-architecture.md)
- [Issue 041: Git Worktree Multi-Agent Architecture](../issues/completed/041-git-worktree-multi-agent-architecture.md)
- [Development Guide](development-guide.md)
