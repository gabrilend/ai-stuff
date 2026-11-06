# 808 — The .src end

Source files as assets, *language and version printed at first line of each source-code file*. Written by a model through the hands, checked by the language's own parser ([067](../docs/067-datapath-the-studio.md)).

## Current Behavior

Step 1 is built: `src/153-the-source-end.lua` holds the table of
languages (comment form, extension, parser command), the first-line
check, the language's own parser run over a file, and the `.src`
paintbrush `source{ language, version, purpose, prompt }`, read through
the wall (802) with its document generated as `docs/paintbrush-src.md`.
Checked by `tests/154-checking-the-source-end.lua`. Step 2, the `source`
turn kind that writes the file, is not built, so nothing yet writes one
source file to order.

## Intended Behavior

- A canvas `source{ language = "lua", version = "LuaJIT 2.1", purpose = "…", prompt = "…" }`.
- A new turn kind, `source`, writing one file, confined to it; told the house coding rules and the look of comments.
- The first line is checked to name the language and version, in that language's comment form; the file is checked by the language's own parser (`luajit -bl`, `cc -fsyntax-only`, `bash -n`).
- A table of languages: comment form, file extension, parser command. Adding a language is adding a row.

## Suggested Implementation Steps

1. The language table and the first-line check. **Test:** a Lua file whose first line is `-- lua 5.1 (LuaJIT 2.1)` passes; one without it is refused. Done.
2. The turn kind, with the stand-in. **Test:** a stand-in writes a file; the parser check runs; a file that does not parse is sent back once with the parser's words.

## Decisions

- The language table is its own (153), not rows added to 027: 027 decides
  what a file already is from its name and first bytes; this one says
  how a file to be written is marked and checked. Rows: lua, c, bash,
  each with a parser that is already on the owner's machine.
- 2026-11-02, decided by Ritz: no javascript row. The project writes no
  JavaScript (the owner's rule), so the row, its `node --check` parser and
  its test cases were removed; a language is still added by adding a row.
- The first line is `<comment> <language> <version text>`, the language
  named by its row's own name; with a canvas, the line must also contain
  the canvas's `version` (so `-- lua 5.1 (LuaJIT 2.1)` meets
  `version = "LuaJIT 2.1"`). A shell file's first line is that comment,
  not a `#!` line: it is run as `bash file`.
- A parser that is not installed is a refusal naming it, never a pass.
- A file's ending must match its language's extension.
- A `.src` canvas is one `canvas{}` (category `source`) and one
  `source{}`, both required, through the same wall as the `.png` end; the
  wall's required-word check was made general for it.
- Step 2 waits: the turn kind runs through the turn pool (039), whose
  threads (effil) are not on this machine, so its check could not run
  here; it is left for a machine where the turn pool runs.

## Blocked by

- 802
