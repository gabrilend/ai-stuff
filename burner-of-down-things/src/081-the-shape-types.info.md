# 081-the-shape-types.lua

The closed list of shape types (docs/068), and recognisers for the three
scalar types (issue 902a) and the three structured ones (902b). The
remaining five plus `unknown` (902c) extend the same `recognise()`
dispatch.

| Function | In | Out |
|---|---|---|
| `recognise(bytes)` | a parcel file's bytes | tried in order: `"image"` (the PNG signature exactly, and `IHDR` as the first chunk), `"clip"` (`ftyp` at bytes 5-8 of an MP4, or `GIF87a`/`GIF89a`), `"table"` (a Lua data file returning a table, run sandboxed), then `"integer-array"`, `"number-array"`, `"text"`; `nil` when none match (902c tries next) |
| `TYPES` | | the closed list of every shape type's name |
| `TABLE_INSTRUCTION_LIMIT` | | how many Lua instructions a table file may take to build its table (1,000,000) |

The `table` sandbox: an empty environment, precompiled bytecode refused
unread, JIT off, an instruction limit, and string methods out of reach
while the file runs — loaded as data, never run for effect.
