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
A headline sentence and the `| Project | Progress | % |` table, the same table
`--write-readme` splices into the README's appendix.

### `census-projects.lua --json` → JSON to standard output
`{ projects, tracked, building, vision, empty, completed, archived, total,
percent, list: [ { name, state, open, completed, archived, total, percent } ] }`.

### `census-projects.lua --conventions` → terminal table
How many projects keep each house convention: the RAM-tier `tmp/` symlink,
`input/` and `output/`, `desire/`, `llm-transcripts/`, `docs/HTML/`, the
`.file-index-counter`, and the total number of companion `.info.md` files.

### `census-projects.lua --write-readme` → rewrites the root README in place
Refreshes every figure between census markers in `README.md` and prints one
line per figure that changed (`slot  old -> new`). The new page is written to
a sibling file and renamed over the old, so it is never left half-written. Any
refusal (below) leaves the file byte-identical and exits 1.

### `census-projects.lua --check-readme` → report only
The same comparison, written nowhere. Exits 0 when every figure is current, 1
when any is stale, listing them.

### `census-projects.lua --say=N` → a number in words
`91` → `ninety-one`, `118` → `one hundred and eighteen`. 0 to 999; anything
larger is refused rather than printed as digits. Exists for the tests and for
anyone writing prose around a figure.

### Options, in any position
- `--dir=/path/to/delta-version` censuses a different checkout; the monorepo
  root is the parent of the given directory.
- `--readme=/path/to/file.md` splices a different file (the tests use copies).

## README slots

A figure the census owns is written between two invisible HTML comments:

    containing <!-- census:projects:words -->ninety-one<!-- /census --> projects

After `census:` comes the slot, then optionally `:` and a format. Block slots
sit on lines of their own and take no format.

| Slot | Kind | What it is |
|------|------|------------|
| `projects` | number | every project |
| `top_level` / `on_shelves` | number | projects at the repository's top / inside a shelf |
| `loose_ideas` | number | loose notes on shelves, not yet directories |
| `tracked` / `building` / `vision` / `empty` | number | projects in each state |
| `completed` / `issues` / `percent` / `shelved` | number | issue totals across tracked projects |
| `tmp_symlink` `input_dir` `output_dir` `desire_dir` `transcripts` `html_copy` `index_counter` `info_md` | number | house-convention counts, as `--conventions` prints |
| `human_written` / `machine_written` / `source_generated` / `docs_generated` | number | who wrote what, in characters, from `measure-authorship.lua --json` (issue 059): the owner's typing plus every `notes/`; the model's conversation text; the repository's own source; its docs including issue files |
| `field@project` | number | one project's `total`, `completed`, `open`, `archived` or `percent` |
| `empty_clause` | text | "one is an empty directory" / "two are empty directories" / "none is empty" |
| `active_table` | block | the busiest eleven projects of the last three months |
| `appendix_table` | block | every project, the loose ideas, the skipped furniture |

| Format | Writes 1259 / 91 as |
|--------|--------------|
| `digits` | `1,259` |
| `words` | `ninety-one` |
| `Words` | `Ninety-one` (sentence start) |
| `millions` | `9.7 million` (for figures that grow with every conversation) |
| `tenths` | `10.2` |
| `text` | (text slots only) |

Refused, with the file untouched: an unknown slot, an unknown format, a format
on a block slot, a project name that does not exist, a marker never closed,
and a project in the active table with no focus sentence.

## The Active Development table

- **Rank**: file changes git recorded inside each project over the last three
  months (one file changed in five commits counts five). A changed path is
  credited to the longest project directory it starts with, so a game on the
  `games/` shelf is not also credited to the shelf. A project's materials are
  not credited: `input/`, `output/`, generated `docs/HTML/`, and
  `llm-transcripts/` (the `activity_excluded` list in the configuration).
- **Focus**: one hand-written sentence per project, from
  `../assets/project-focus.lua`. Missing → refused, naming the project.
- **Issues**: the census's own completed/total.
- **Phases**: phases *defined*, from `../../scripts/progress-dashboard.lua`
  used as a library. If the dashboard has any warning about that project, the
  project's own progress files (`N-progress.md` / `phase-N-progress.md`) are
  counted instead, with a fallback notice on stderr, provided there are at
  least two (one tracker alone is no evidence of phases); otherwise the cell
  is "—" and a notice names the project and the warning.

## Commit gate

`hooks/pre-commit` (linked in as `.git/hooks/pre-commit`) runs
`--check-readme` against the *staged* README whenever README.md is in a
commit, and refuses the commit if any figure is stale. Commits that do not
include README.md are never checked.

## Tests

`test-census-projects.sh` works on copies in `/dev/shm/delta-version/census-test`:
number words at the edges, a stale copy fails the check, a rewrite converges,
each refusal leaves the file byte-identical, `--dir=` in either position, and
finally that the real front page is current.

## Related

- `list-projects.sh` — a project finder with a different rule: it scores a
  directory on what it contains and needs fifty points, so it misses a project
  whose only marker is an `issues/` folder, and excludes `delta-version` and
  `scripts` by name. This census does not use it
- `../../scripts/progress-dashboard.lua` — per-project, per-phase progress bars
