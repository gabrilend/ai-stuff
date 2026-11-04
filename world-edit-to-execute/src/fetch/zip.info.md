# zip.lua

Reads a `.zip` (issue 603: a model posted with its textures is stored as
it came and read from).

| Function | Takes | Gives |
|----------|-------|-------|
| `zip.open(bytes)` | the archive | `{entries = {{name, size, compressed, method, crc}}}`; raises on a missing end record, a damaged file list or an encrypted entry |
| `z:find(name)` | a name | the entry, matched without regard to case or slashes |
| `z:read(name or entry)` | a name or entry | the bytes, or nil when absent; raises on another compression method, a wrong size or a failed CRC |
| `zip.crc32(s)` | bytes | the CRC-32 |

Stored (0) and deflated (8) entries are read; deflate is the monorepo's
own inflate (kanji-learning-image-generator), as `parsers/png.lua` uses.
