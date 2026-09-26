# 004 — Datapath: the survey

Before any model reads the source, the machine reads it itself. The survey is
what can be known without judgment: which files exist, what language each is
in, how big, and which file includes which. It is the map every later turn is
handed, and the list the blueprint's coverage is checked against.

```
  source folder
       │ walk (skip .git, cases, tmp, build output, anything in .gitignore-like skip table)
       ▼
  list of paths ──split into slices──► worker threads, one per core
                                          │ each reads its files:
                                          │   extension → language, role
                                          │   count lines and bytes
                                          │   scan text for include lines → links
                                          ▼
                                 rows and links, gathered in path order
                                          │
               ┌──────────────────────────┼──────────────────────────┐
               ▼                          ▼                          ▼
      survey/files.tsv            survey/links.tsv          survey/summary.txt
```

## The walk

A directory listing, recursively, following no symbolic links (a link can
leave the source or loop). Skipped by name: `.git`, `node_modules`, `tmp`,
`build`, `target`, `dist`, `__pycache__`, `llm-transcripts`. The skip list is
a table in the survey's source, one row per name with the reason.

| Decision | What each path leads to |
|---|---|
| A path is a symbolic link | Recorded as a row with role `link` and not followed |
| A file cannot be opened | The survey stops and names it. A survey that silently leaves files out would let the blueprint miss them |
| The source has more than the file limit (default 20 000) | Refused, with the count. The person can raise the limit; the machine will not quietly sample |

## The language table

One row per extension: language, role, and the pattern that finds an include
line. Adding a language is adding a row.

| Extensions | Language | Role | Include pattern finds |
|---|---|---|---|
| `.lua` | lua | code | `require "x"`, `require("x")`, `dofile("x")` |
| `.c` `.h` | c | code | `#include "x"` (the angle-bracket form is recorded as outside) |
| `.sh` `.bash` | shell | code | `source x`, `. x` |
| `.py` | python | code | `import x`, `from x import` |
| `.js` `.mjs` `.ts` | javascript | code | `import … from "x"`, `require("x")` |
| `.md` `.txt` | markdown | doc | none |
| `.json` `.tsv` `.csv` `.toml` `.yaml` | data | data | none |
| `Makefile` `CMakeLists.txt` | build | build | none |
| anything with a NUL in its first 8 KiB | binary | binary | none |

A file with no known extension whose first line starts with `#!` takes its
language from the interpreter named there.

## Resolving a link

The name as written is turned into candidate paths, in order, and the first
that exists in the source wins: relative to the including file, then relative
to the source root; for Lua, dots become slashes and `.lua` is tried; for C,
the name as-is. A name that resolves nowhere is recorded with `inside = no`:
it is a dependency outside the source (a system library, a package).

## Parallel reading

> never ever do batch processing on a single thread.

The path list is cut into as many slices as the machine has hardware threads
(from the thread library, effil). Each worker thread reads its slice and
returns its rows as one tab-separated string, since only strings and plain
tables cross between threads. The gatherer joins them and sorts by path, so
the output is identical however many threads ran.

## The summary

`survey/summary.txt` is the viewing side, written from the two tables and
nothing else: counts by language and role, the largest files, the files most
linked to (the likely foundations), the files that link out but are never
linked to (the likely entry points), and every outside dependency by name.

The survey's generation and its viewing are separate modules: one writes the
tables, the other reads them. The summary can be rebuilt from the tables at
any time without walking the source again.
