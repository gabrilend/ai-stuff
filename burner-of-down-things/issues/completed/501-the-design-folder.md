# 501 — The design folder

Laying out `design/` as a house project, the first time a case builds
([007](../docs/007-datapath-the-design.md), *the design folder*).

## Current Behavior

Built as `src/048-the-design-folder.lua`. The skeleton tool names a project's second scratch tier after the folder too, so the machine makes both doors — `design/tmp` into `/tmp/burner-of-down-things/cases/<key>` and its `shared-memory` into `/dev/shm/burner-of-down-things/cases/<key>` — before running the tool, which honours doors that exist. `<key>` is the case name plus 8 hex characters of the SHA-256 of the case folder's path, so same-named cases in different places never share scratch space. The check kit removes those spaces when a check ends. Checked by tests/052.

## Intended Behavior

- **Lay out** (case): if `design/src` does not exist, makes the design's
  `tmp` link to `/tmp/burner-of-down-things/cases/<case>/` (creating that
  folder), then runs the house init tool with `--skeleton-only` on
  `design/`, then writes `design/README` naming the case and the ledger head
  hash at that moment.
- The first layout writes `output/first-build` telling the person that
  acceptance commands written by a model will be run in the design folder
  ([010](../docs/010-open-questions.md), question 3).

| Decision | What each path leads to |
|---|---|
| The house init tool is missing | Refused, naming its path |
| `design/src` exists | Nothing is done: layout happens once |

## Suggested Implementation Steps

1. **Test:** after layout, the design has the house folders, a `tmp` link to
   the case's own scratch folder, and the README.
2. **Test:** a second layout changes nothing.

## Blocked by

- 105
