# discover-projects.lua

## Overview

Chooses the projects a ticket should go to. It is the project-discovery step
of the ticket distribution chain (issue 018), built on top of what already
existed rather than beside it:

| Question | Answered by |
|----------|-------------|
| Which directories are projects? Which are furniture, shelves or copies? | `census-projects.lua` (this script asks it) |
| What state is each project in, and how many issues does it have? | `census-projects.lua` |
| Which projects live outside the repository? | `list-projects.sh --external-only` |
| What is each project written in? | **this script** |
| Which projects should this ticket go to? | **this script** |

## Classification

Languages are counted from the files git tracks, one file at a time, and the
language with the most files is the project's dominant one (`none` when it has
no code at all, like a vision document). Left out:

- tracked symbolic links: a link is a second name for a file counted
  elsewhere, and opening one can reach anything (one in this repository
  points at a serial device, which would hang the run);
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
| `--language=lua,c` | are mainly written in one of these |
| `--uses=bash` | track at least one file in one of these |
| `--state=tracked,building` | are in one of these census states |
| `--has=PATH` (repeatable) | hold this path |
| `--active-days=N` | had a tracked file change in the last N days |
| `--only=a,b` / `--exclude=a,b` | are / are not named |
| `--profile=NAME` | match a named set of the above from `config/project-discovery.conf` |

Command-line options apply on top of a profile: a list option replaces the
profile's, and `--has` adds to it. Names that cannot match anything (an
unknown language, state, project or profile) are errors, so a typo does not
look like an empty answer.

There is no relevance score. A project is chosen because it matched each
filter, and `--table` shows the facts it matched on.

## Output

`--names` (default), `--paths`, `--table`, `--json`, `--list-profiles`.

Exit status: 0 when projects were chosen, 1 when none matched, 2 for a usage
or configuration error.

## Examples

    discover-projects.lua --profile=code-style-lua --table
    discover-projects.lua --uses=bash --state=tracked --paths
    discover-projects.lua --has=Makefile --exclude=games/old-thing --json

## Tests

`scripts/test-discover-projects.sh [--dir MONOREPO]` builds a small monorepo in
RAM (vendored code, generated output, a link to a pipe, one recent commit) and
checks every filter, profile and error against it.
