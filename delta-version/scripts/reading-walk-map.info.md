# reading-walk-map.lua — info

Turns a project into a **map of stops**: one stop per function, datastructure
or prose passage, in the order the project is meant to be read. Data only; the
walk is `reading-walk.lua`. Built for issue 065 (065a, 065b, 065c).

## Use

| | |
|---|---|
| `reading-walk-map.lua <project>` | build the map; print a report of what is described, what is not, what has a recorded reason |
| `--src=FOLDER` | read another source folder than `src/` |
| `--out=FILE` | write the map there instead of `delta-version/tmp/shared-memory/reading-walk/<project>.map.lua` |
| `--workers=N` | how many worker processes per pass (default: CPU count) |
| `--dir=PATH` | delta-version's home (its RAM tier holds the scratch space) |

## How it finds things

- **Stops**: every fold marker (`-- {{{ title`, or `//`, `#` by file type).
  A title that is a name (`M.flatten(path)`, `local function split()`,
  `MAX_DEPTH -- note`) is a function or datastructure; any other title is a
  prose **passage**, a stop with no uses.
- **Reading order**: file names sorted; zero-padded index numbers sort as they
  read.
- **Description**: the file's `.info.md` page (`### \`name()\`` section, else a
  `| \`name()\` | text |` row); without one, the comment under the marker,
  marked "source comment" so the missing page entry shows.
- **Uses**: words of every non-comment source line looked up in a table of
  stop names. A local's uses count only in its own file; an exported one's
  count elsewhere only after a dot or colon.
- **Recorded reasons**: comment paragraphs inside the stop, and issue-file
  paragraphs naming it, that hold a marker phrase ("rather than", "instead
  of", "decided against", "because", ...). Nothing else; nothing invented.
- **Chapter**: the commit that first added the stop's file
  (`git log --diff-filter=A`), or "not yet in history".

Two parallel passes: stops per source file, then uses and reasons over
source and issue files.

## The map (a Lua data file returning one table)

| Field | Type | |
|---|---|---|
| project | string | absolute path of the mapped project |
| project_name | string | its folder name |
| source_folder | string | `src` unless `--src` |
| built | string | date and time |
| stops | list of stop | in reading order |

A **stop**:

| Field | Type | |
|---|---|---|
| index | integer | position in the walk |
| name | string | `M.flatten`, `split`, or a passage's heading |
| short | string | last part of the name (`flatten`); empty for a passage |
| title | string | the whole fold-marker title |
| kind | string | `function`, `datastructure` or `passage` |
| exported | boolean | the name has a dot or colon |
| file | string | path relative to the project |
| line, end_line, definition_line | integer | marker line, closing marker line, first code line |
| description | string | see above |
| description_source | string | `info.md`, `source comment` or `none` |
| summary | string | the description's first sentence (≤ 240 characters) |
| uses | list of { file string, line integer, text string } | |
| alternatives | list of { source string, line integer, text string } | recorded reasons |
| chapter | { date string, subject string } | |

Tests: `test-reading-walk.sh`.
