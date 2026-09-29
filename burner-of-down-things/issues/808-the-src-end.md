# 808 — The .src end

Source files as assets, *language and version printed at first line of each source-code file*. Written by a model through the hands, checked by the language's own parser ([067](../docs/067-datapath-the-studio.md)).

## Current Behavior

The machine builds whole designs from blueprints; nothing writes one source file to order.

## Intended Behavior

- A canvas `source{ language = "lua", version = "LuaJIT 2.1", purpose = "…", prompt = "…" }`.
- A new turn kind, `source`, writing one file, confined to it; told the house coding rules and the look of comments.
- The first line is checked to name the language and version, in that language's comment form; the file is checked by the language's own parser (`luajit -bl`, `cc -fsyntax-only`, `bash -n`, `node --check` where node starts).
- A table of languages: comment form, file extension, parser command. Adding a language is adding a row.

## Suggested Implementation Steps

1. The language table and the first-line check. **Test:** a Lua file whose first line is `-- lua 5.1 (LuaJIT 2.1)` passes; one without it is refused.
2. The turn kind, with the stand-in. **Test:** a stand-in writes a file; the parser check runs; a file that does not parse is sent back once with the parser's words.

## Blocked by

- 802
