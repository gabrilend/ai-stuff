# census-projects.lua

## Overview

Counts the monorepo. Lists every project in it, tallies the issues each one has
filed, and prints the result as a terminal summary, as the markdown tables the
root README carries, or as JSON. Exists so that the README's figures are
regenerated rather than retyped.

Every project is listed, not only the ones with issue tracking. A directory
holding nothing but a `vision` document is a project here — the repository's own
epigraph says a project does not have to be more than a series of documents —
and leaving those out made the repository look smaller and tidier than it is.

Projects nested inside a shelf — a game under `games/`, a study under
`game-design/`, a device under `roms/`, a subproject under
`symbeline-realms/subprojects/` — are listed under their full path. A shelf may
also hold loose notes beside its directories; each is an idea written down and
not yet given a directory of its own, and they are counted rather than ignored.

## What counts as an issue

A name that opens with an identifier containing a digit and ends at a dash:
`301-feature.md`, `522a-sub-issue.md`, `A02-lettered-phase.md`. It may be a
markdown file or a directory, since early projects kept an issue as a folder of
pages; such a directory counts once and is not descended into. Phase progress
trackers, demo runners, and loose notes are not issues.

## The four project states

| State | What it means |
|-------|---------------|
| tracked | has issue files, so the completed figure means something |
| building | has source or documents, no issues filed yet |
| vision | a vision document and little else: an intention, not yet work |
| empty | a directory with nothing in it, reported so it gets noticed |

## The three issue states

| State | Where it lives | What it claims |
|-------|----------------|----------------|
| open | `issues/`, or a `phase-n/` folder under it | not yet done |
| completed | `issues/completed/` or `issues/done/`, any depth | finished |
| archived | `issues/archive/` or `issues/superseded/` | set aside or overtaken, not finished |

Archived issues are counted and reported separately, never folded into the
completed figure, so that shelving a retired mode cannot inflate a percentage.

## What is skipped

Repository furniture: `libs/` (shared third-party code), `notes/`, `ideas/`,
`skills/`, `llm-transcripts/`, and `docker-scripts/`. These are real directories
that are not projects. The skip list is printed every run rather than being
silently applied, so a new arrival in that category gets noticed and argued with.

A project's own `issues/` is read at its root or under `src/`, and nowhere else,
which is what keeps a generated copy of a project sitting in an `output/`
directory from being counted twice.

## External Functions

This is a program rather than a library; it is run, not required. Its behaviour
is selected by one argument.

### `census-projects.lua` → terminal summary
Project and issue totals, then a line per project — a fraction and a percentage
for a tracked one, its state in words for the rest — then the loose ideas on each
shelf, then the directories skipped as furniture.

### `census-projects.lua --markdown` → markdown to standard output
A headline sentence and the `| Project | Progress | % |` table the root README
carries in two places.

### `census-projects.lua --json` → JSON to standard output
`{ projects, tracked, building, vision, empty, completed, archived, total,
percent, list: [ { name, state, open, completed, archived, total, percent } ] }`.

### `census-projects.lua --conventions` → terminal table
How many projects keep each house convention: the RAM-tier `tmp/` symlink,
`input/` and `output/`, `desire/`, `llm-transcripts/`, `docs/HTML/`, the
`.file-index-counter`, and the total number of companion `.info.md` files.

### `census-projects.lua --dir=/path/to/delta-version`
Censuses a different checkout. The monorepo root is taken to be the parent of
the given directory. Must be the first argument, before the mode.

## Related

- `list-projects.sh` — a project finder with a different rule: it scores a
  directory on what it contains and needs fifty points, so it misses a project
  whose only marker is an `issues/` folder, and excludes `delta-version` and
  `scripts` by name. This census does not use it
- `../../scripts/progress-dashboard.lua` — per-project, per-phase progress bars
