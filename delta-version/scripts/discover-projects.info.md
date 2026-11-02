# discover-projects.lua

## Overview

Chooses the projects a ticket should go to. It is the project-discovery step
of the ticket distribution chain (issue 018), built on what already exists
rather than beside it:

| Question | Answered by |
|----------|-------------|
| Which folders are projects? What kind is each (lua, c, node, ...)? | `scripts/libs/project-discovery.lua`, the shared library (loaded, not copied) |
| What state is each project in, and how many issues does it have? | `census-projects.lua` (asked for its JSON) |
| Which projects live outside the repository? | `list-projects.sh --external-only` |
| Which languages does each project use, and how much? | **this script** |
| Which projects should this ticket go to? | **this script** |

The library holds the only copy of the rules for what a project is (the
rules `list-projects.sh` has always used: top-level folders scoring 50 or
more for `src/`, `issues/`, a Makefile and so on). On the monorepo it lists
41 projects. The census counts more (86), because it also opens shelves like
`games/` and counts vision-only folders; that wider count is for the README,
not for sending tickets. A project the census does not list gets state
`unknown`.

## Languages

The project's **kind** is the library's: its build file, or else the source
kind it holds most of in the folder and `src/`. `--language` filters on it.

The **languages used** are counted here, across the whole project, from the
files git tracks, in the library's vocabulary (its `EXTENSIONS` table: lua,
c, c++, rust, go, python, node, shell, zig). `--uses` filters on them. Left
out:

- tracked symbolic links: a link is a second name for a file counted
  elsewhere, and opening one can reach anything (Wine's `dosdevices` links in
  `links-awakening/` point at serial ports and disks, and the first run hung
  on one);
- vendored code inside a project: `libs/`, `vendor/`, `node_modules/`,
  `external/`, `third_party/`;
- materials, as the census defines them: `input/`, `output/`, `docs/HTML/`,
  `llm-transcripts/`.

A file with no extension is classified by its `#!` line, reading only its
first 128 bytes.

## Selection

Every filter given must match. A list option matches any one of its items.

| Option | Chooses projects that |
|--------|-----------------------|
| `--language=lua,c` | are of one of these kinds |
| `--uses=shell` | track at least one file of one of these kinds |
| `--state=tracked,building` | are in one of these census states |
| `--has=PATH` (repeatable) | hold this path |
| `--active-days=N` | had a tracked file change in the last N days |
| `--only=a,b` / `--exclude=a,b` | are / are not named |
| `--profile=NAME` | match a named set of the above from `config/project-discovery.conf` |

Command-line options apply on top of a profile: a list option replaces the
profile's, and `--has` adds to it. Names that cannot match anything (a kind
the library does not name, an unknown state, project or profile) are errors,
so a typo does not look like an empty answer.

There is no relevance score. A project is chosen because it matched each
filter, and `--table` shows the facts it matched on.

## Output

`--names` (default), `--paths`, `--table`, `--json`, `--list-profiles`.

Exit status: 0 when projects were chosen, 1 when none matched, 2 for a usage
or configuration error.

## Examples

    discover-projects.lua --profile=code-style-lua --table
    discover-projects.lua --uses=shell --state=tracked --paths
    discover-projects.lua --has=Makefile --exclude=old-thing --json

## Tests

`scripts/test-discover-projects.sh [--dir MONOREPO]` builds a small monorepo in
RAM (vendored code, generated output, a link to a pipe, one recent commit) and
checks every filter, profile and error against it.
