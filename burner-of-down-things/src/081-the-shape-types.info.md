# 081-the-shape-types.lua

The closed list of shape types (docs/068), and a recogniser for every one:
the three scalar types (issue 902a), the three structured ones (902b), and
the remaining five (902c). Anything none of them match is `unknown`,
never a guess.

| Function | In | Out |
|---|---|---|
| `recognise(bytes, path)` | a parcel file's bytes; its path when known (needed for `source` and an executable `program`) | tried in order: `"image"` (the PNG signature exactly, and `IHDR` as the first chunk), `"clip"` (`ftyp` at bytes 5-8 of an MP4, or `GIF87a`/`GIF89a`), `"table"` (a Lua data file returning a table, run sandboxed), `"program"` (a `#!` line, or an executable file), `"request"` (a first line that is a well-formed tag, 079), `"finding"` (a `## ` heading and a `Mechanism: ` line, 085's form), `"results"` (a well-formed JSON object or array, as 037 writes result.json), `"source"` (027 gives its name the role `code`), then `"integer-array"`, `"number-array"`, `"text"`; else `"unknown"` — and an empty or space-only file is `"unknown"` too |
| `recognise_file(file)` | a parcel file (`{name, path}`) or a path | `recognise` on its bytes and path |
| `TYPES` | | the closed list of every shape type's name (`unknown` is not one: it says none matched) |
| `UNKNOWN` | | `"unknown"` |
| `TABLE_INSTRUCTION_LIMIT` | | how many Lua instructions a table file may take to build its table (1,000,000) |

The `table` sandbox: an empty environment, precompiled bytecode refused
unread, JIT off, an instruction limit, and string methods out of reach
while the file runs — loaded as data, never run for effect. JSON is read
by a strict checker (RFC 8259: no trailing commas, no leading zeros, only
the legal escapes), nesting at most 200 deep; it builds nothing.
