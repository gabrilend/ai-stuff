# 062-embedding-index-tools — info

The embedding index's checker and git hooks (issue 502).

    scripts/check-embedding-index          # exit 0 usable, 1 not, with why
    scripts/install-index-hooks [--remove]

| Function | Meaning |
|---|---|
| `check(root)` | true and one line, or false and the problems: 060's `check` against the checkout's commit and the files at it |
| `hooks(root, { remove })` | adds (or removes) this project's marked block in `post-commit`, `post-merge` and `post-checkout`; one line per hook |
| `block(root, hook)` | the three marked lines |
| `hooks_folder(root)` | the repository's hooks folder, as `git rev-parse --git-path hooks` names it |

A block runs `scripts/build-embedding-index --hook NAME "$@"` in the
background. It goes beside what a hook already does, before a last `exit`
line; installing twice changes nothing; `--remove` takes out only this
project's block, and removes a hook that held nothing else.
