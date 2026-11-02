# publish-projects.sh

Shows which projects outside the main ai-stuff folder would be pushed, and
pushes them only when the configuration turns pushing on. Built for issue 039.

## What it reads

`config/external-projects.conf`, the same file `list-projects.sh` reads
(issue 024). Three sections matter:

| Section | Holds |
|---|---|
| `[external_directories]` | `name=/absolute/path`: each extra root that holds projects. A relative path is skipped with a warning. |
| `[publishable]` | `root_name/project_folder=on`: the only projects that may be pushed. `on`, `yes`, `true` and `1` all count. Anything else, or no line at all, keeps the project local. |
| `[publishing]` | `push=off` (the default) previews. `push=on` pushes. |

Projects are found the way `list-projects.sh` finds them: folders directly
under a root that look like projects (a `src/`, an `issues/`, a build file).
Projects in the main folder are never handled here; they are published with
the monorepo.

## What it prints, per project

| Situation | Line |
|---|---|
| not listed, or listed with anything but on | `kept local: not listed as publishable`, plus a note when commits are waiting, which are never pushed from here |
| listed, not a git repository | nothing to push |
| listed, but inside another repository | skipped: pushing would push the enclosing repository |
| listed, not on a branch | nothing to push |
| listed, branch tracks no remote | nothing to push |
| listed, up to date | matches its upstream as of the last fetch |
| listed, commits waiting | `would push N commit(s):` and the command, or, with `push=on`, the push and its result |

The push is always `git -C PROJECT push REMOTE BRANCH:UPSTREAM-BRANCH`, the
branch's own configured upstream. Nothing is fetched, so counts are as fresh
as the project's last fetch.

## Options and exit status

    publish-projects.sh [--dir MONOREPO] [--config-dir DIR] [--help]

`--dir` reads `MONOREPO/delta-version/config/`; `--config-dir` (or the
`DELTA_CONFIG_DIR` environment variable, as for `list-projects.sh`) names the
folder directly. Exit 0 when every push asked for succeeded, or none was
asked for; 1 when a push failed; 2 on a usage error.

## Shared pieces

- `libs/publishable.sh` holds the reading of the configuration and
  `project_publishable PATH`, which prints `main`, `yes` or `no`.
- `reconstruct-history.sh --scan` uses it for its **Public** column.

## Tests

`test-publish-projects.sh [--dir MONOREPO]` builds a pretend monorepo and two
extra roots in the RAM folder, with a bare repository standing in for each
remote, and checks every row of the table above, a real push with `push=on`,
a failed push, a relative root, a missing configuration file, and the scan's
Public column. 29 checks. `KEEP=1` keeps the folder.

## Why not the original plan

Issue 039 first asked for a whole-filesystem search for `ai-stuff` folders,
an opt-out exclusion list and two-way symlinks. The decision (2026-11-02)
took listed roots instead of a search, so no disk is scanned. Pushing is
opt-in, so a forgotten project stays private. There are no symlinks, so no
tool can follow one out of the repository.
