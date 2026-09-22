# libs/issue-names.lua

The shared reader of issue-file names. `progress-dashboard.lua` and
`validate-issues` both load it, so they cannot disagree about which phase an
issue is in or whether it is done.

Load with `dofile("/home/ritz/programming/ai-stuff/scripts/libs/issue-names.lua")`.

## Functions

**scan(project_dir)** → issues, report
Reads every file under `<project_dir>/issues`. Raises an error if that folder is
missing.
- `issues`: list of tables, one per issue file:
  - `path` (string, absolute), `rel` (string, relative to issues/), `filename`
  - `shape` (string: "compact" 522-x, "dashed" 9-007-x, "lettered" A04-x)
  - `id` (string, e.g. "522", "1102c", "9-007", "A04")
  - `phase` (string or nil when the name has no valid phase; a `phase-N/`
    folder overrides the name), `name_phase` (string or nil, what the name
    alone says — used for numbering), `number` (string of digits)
  - `index` (string, sub-issue letter or "")
  - `descr` (string, the part after the id)
  - `status` (string: "open", "completed", "retired", "unknown")
  - `folder` (string, first folder under issues/, "" for top level)
  - `has_extension` (boolean, false when the file lacks `.md`)
- `report`: what could not be placed:
  - `width` (integer, digits a compact name spends on the issue number)
  - `has_compact`, `width_confirmed` (booleans)
  - `known_phases` (set: phase string → true, from progress files and phase-N/ folders)
  - `ambiguous`, `unknown_locations`, `phases_without_evidence`,
    `folder_disagreements` (lists of strings)
  - `skipped` (integer, files under issues/ that are not issues)

**split_name(filename)** → table or nil
Reads one name's shape without project context. Returns nil for files that are
not issue-shaped (README.md, progress files).

**phase_of_compact(digits, width)** → phase, number (or nil, nil)
Splits compact digits. Nil when too short or when the phase part would start
with a zero.

**format_id(shape, phase, number, width)** → string
Writes an id in the given shape: compact 5, 23, 2 → "523".

**phase_sort_key(phase)** → string
Sorts numeric phases numerically, before lettered ones.

**location_status** (table)
Folder name → status. Extend it when a project invents a new folder.
