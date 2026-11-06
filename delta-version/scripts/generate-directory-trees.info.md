# generate-directory-trees.lua

Draws a map of every project's folders and files, collects the maps into one
master file, and gives each project its own copy as `DIRECTORY_STRUCTURE.txt`,
with the monorepo's shared scripts listed underneath. Design: issue 044.

## Usage

    generate-directory-trees.lua [options]

| option | meaning |
| --- | --- |
| `--dir=PATH` | the delta-version folder; the monorepo is its parent (default `/mnt/mtwo/programming/ai-stuff/delta-version`) |
| `--project=NAME` | only this project; may be repeated |
| `--no-files` | folders only |
| `--max-depth=N` | folder levels listed below the project (default 5); a folder one level deeper is shown as `name/  (N files)` |
| `--max-entries=N` | files listed per folder before `… and N more files` (default 25; 0 lists all) |
| `--no-gitignore` | every file on disk, ignored ones included |
| `--dry-run` | write the master file only; no project file is written |
| `--master=PATH` | where the master file goes (default `<dir>/assets/master-directory-structure.txt`) |

A value may follow `=` or come as the next argument. Exit 0 when everything was
written, 1 on an error (an unknown project, an unwritable file), 2 for bad
arguments.

## What it lists

- **Projects**: what `list-projects.sh --exclude-external` finds in the
  monorepo, plus delta-version itself (the lister leaves it out as tooling,
  but its folders deserve a map too). External project folders are left out:
  they are not in this repository.
- **Files**: in a git work tree, `git ls-files --cached --others
  --exclude-standard` less files deleted from disk -- what git would keep, so
  build output, scratch space and anything ignored never appears. Outside git
  (or with `--no-gitignore`), every file on disk except `.git/`. A project's
  own `DIRECTORY_STRUCTURE.txt` is never listed in itself.
- **Shared scripts**: the runnable files directly in `<monorepo>/scripts/` and
  `delta-version/scripts/` (tests, `.md` files and links to folders left out),
  each with the first sentence of its opening comment, a leading `name - `
  taken off, cut at 72 characters.

## The master file

    # Monorepo Directory Structure
    ...
    ][ alpha ][

    alpha/
    ├── src/
    │   └── main.lua
    └── README.md

    Listed from: git ls-files (respects .gitignore)

    ][ shared-monorepo-utilities ][
    ...

Each section opens with a marker line `][ name ][` (match it with
`^\]\[ (.*) \]\[$`). The project files are cut out of the master file by
these markers rather than built separately, so the master file is the one
source.

## The project files

`<project>/DIRECTORY_STRUCTURE.txt`: the project's tree, the shared scripts,
the paths it was made from and the command that remakes it. A file whose map
is unchanged is not rewritten -- the `Generated:` date alone never makes a new
version to commit.

## Tests

`test-generate-directory-trees.sh [monorepo]` builds a pretend monorepo in RAM
(a git one and one without git) with the real generator and lister linked in,
and checks the master's sections, what is and is not listed, the depth and
crowding limits, the cut-out project files, the unchanged-map rule, and every
option.
