# 202 — The language table

Deciding each file's language and role
([004](../docs/004-datapath-the-survey.md), *the language table*).

## Current Behavior

Built as `src/027-the-language-table.lua`. C++ (`.cpp .cc .cxx .hpp .hh`, scanned like C), assembly (`.S` through the C preprocessor), CMake, HTML, CSS, SQL, linker scripts and common binary extensions were added once real sources (kiln, AzerothCore) showed them. Extensions are matched as written first, so `.S` and `.s` differ. Checked by tests/032.

## Intended Behavior

- One table keyed by extension (and by whole name, for `Makefile` and
  `CMakeLists.txt`), each row: language, role, and the name of its include
  scanner (or none).
- A second table keyed by interpreter name for `#!` lines (`lua`, `luajit`,
  `bash`, `sh`, `python3`, `node`).
- Classify (path, first 8 KiB of the file): whole-name row, else extension
  row, else a NUL byte means `binary`, else a `#!` line's interpreter, else
  `other` with role `data`.

## Suggested Implementation Steps

1. The tables and classify. **Test:** one fixture per row, plus a
   no-extension script with `#!/usr/bin/env luajit`, and a binary.

## Blocked by

None.
