# bsd0.lua

Applies one entry from a Warcraft III patch program: a whole new file, or a
Blizzard "BSD0" binary diff against the old file. Needs LuaJIT.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `read_header(entry)` | the entry's bytes (string) | `{kind, old_crc, old_size, new_size}` (integers), or `nil` and an error |
| `apply(entry, old)` | the entry's bytes; the old file's bytes (string; `nil` for whole files) | the new file's bytes (string), or `nil` and an error |
| `crc32(bytes)` | string | unsigned integer |

## Data

| Name | Value | Meaning |
|------|-------|---------|
| `KIND_WHOLE` | `0x01` | the whole new file follows the header |
| `KIND_DIFF` | `0x04` | a run-length-packed BSDIFF40 diff follows |

## Entry format (24-byte header, little-endian)

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint16 | header size, 24 |
| 2 | uint8 | 0x04 on every entry seen |
| 3 | uint8 | kind |
| 4 | uint32 | CRC32 of the old file (0 for whole files) |
| 8 | uint32 | old file size |
| 12 | uint32 | new file size |
| 16 | uint64 | Windows FILETIME |

Refuses a diff whose old file doesn't have the named CRC32 and size, a result
of the wrong size, and unknown kinds. An uncompressed diff payload hasn't been
seen yet and is refused until one is.

Ported in part from StormLib's `SFilePatchArchives.cpp` (MIT).
