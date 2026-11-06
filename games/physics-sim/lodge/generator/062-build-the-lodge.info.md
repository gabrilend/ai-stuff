# 062-build-the-lodge.lua

Builds the lodge: turns the hand-written rooms in `lodge/pages/` into pages
in `docs/HTML/lodge/`. Usually run through `lodge/build`, which makes the
output and scratch folders first (this program never creates a folder).

## As a command

`luajit lodge/generator/062-build-the-lodge.lua [DIR]`

- `DIR`: the project folder (string); defaults to the hard-coded
  physics-sim path.
- Prints the counts, writes `tmp/shared-memory/lodge-build.log`, and writes
  `lodge/output/goodbye` as its last act. Exits 1, printing every problem,
  when anything is refused; nothing is written then except the log.

## As a module

`local lodge = dofile(".../062-build-the-lodge.lua")`

### lodge.build(options) → report

`options` (table):

| field | type | default | meaning |
|-------|------|---------|---------|
| `root` | string | required | the project folder; issues are looked up under `root/issues` |
| `pages_dir` | string | `root/lodge/pages` | where the rooms are |
| `out_dir` | string | `root/docs/HTML/lodge` | where the pages go; must exist |

`report` (table):

| field | type | meaning |
|-------|------|---------|
| `rooms` | number | rooms built |
| `links` | number | links and pictures resolved (first pass) |
| `backlinks` | number | distinct "pointed at from" entries |
| `pictures` | number | figures drawn |
| `out_dir` | string | where the pages went |

Raises a string error listing every problem: a room with no stylesheet, a
line shape outside the subset, a dead link (file, room, section, issue).

## What a room is

A pair in `lodge/pages/`: `NNN-name.md` (the words) and `NNN-name.css` (that
room's own stylesheet, copied beside the built page). Rooms are ordered by
their index; the first is the lodge's front door, and `index.html` points at
it.

## What a room may contain

Headings `#` to `###`, paragraphs, `-`/`*` and `1.` lists (continuation
lines indented), tables (second row must be the rule), fenced code, `>`
quotes (an empty `>` line breaks a paragraph inside the quote), `---` rules,
a picture alone on a line `![caption](path)`, and inline code, `**bold**`,
`*emphasis*`, `[label](target)`. Anything else stops the build.

## Links

- `NNN-name.md` or `NNN-name.md#section`: another room; a section must be a
  heading anchor in that room (lower case, non-letters to hyphens).
- `#section`: this room.
- `https://...`: passed through unchecked.
- anything else: a path relative to `lodge/pages/` that must exist; it is
  rewritten relative to the output folder.
- "issue 606", "issues 901, 902 and 903", "issues 221a to 221e" in prose:
  each number linked to its file in `issues/` or `issues/completed/`.

A link from one room to another records an arrival. Each section that
arrivals point at ends with a "Pointed at from" list; arrivals for a room as
a whole are listed at its foot. Each entry links back to the block id
(`b1`, `b2`, ...) of the paragraph the link sits in.

## Tests

`063-test-the-lodge.lua`, run by `lodge/build --test`.
