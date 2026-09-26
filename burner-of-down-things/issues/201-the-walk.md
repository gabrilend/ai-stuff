# 201 — The walk

Listing every file in a source folder, with the skip table
([004](../docs/004-datapath-the-survey.md)).

## Current Behavior

Nothing reads a source.

## Intended Behavior

- Given a source folder, returns every file path under it, relative to it,
  sorted, and every symbolic link as its own entry, not followed.
- The listing is taken with one `find` process (`-P`, printing type and
  path, NUL-separated) read through a pipe, since LuaJIT has no directory
  reader of its own; the result is parsed in Lua.
- The skip table: one row per folder name (`.git`, `node_modules`, `tmp`,
  `build`, `target`, `dist`, `__pycache__`, `llm-transcripts`, `cases`) with
  its reason. Skipped folders are pruned in the `find` call, not filtered
  afterwards, so their contents are never listed.
- The file limit (default 20 000) refuses a larger source, with the count.

| Decision | What each path leads to |
|---|---|
| `find` exits non-zero (unreadable folder) | The walk stops, naming what find reported |
| Over the limit | Refused with the count; the limit is a setting on the case |

## Suggested Implementation Steps

1. The walk. **Test:** on a fixture folder with a skipped folder, a link and
   nested files: exactly the expected list, links marked.
2. **Test:** a file name with spaces and a newline survives.

## Blocked by

- 101
