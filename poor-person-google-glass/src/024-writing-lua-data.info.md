<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 010 (tolerance records on the model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 024-writing-lua-data

Lua tables written as Lua source, the same way every time (keys sorted, lists in order, whole numbers plain, others with 17 significant figures), for results files and joint records.

| Offers | Takes | Gives |
|---|---|---|
| `serialise(value)` | numbers, strings, booleans, tables of them | Lua source text; refuses functions |
| `write_file(path, header, value)` | header: comment lines | writes "header, return value" |
| `read_file(path)` | | the file's value, or nil if there is no file; raises if it is not readable Lua |
