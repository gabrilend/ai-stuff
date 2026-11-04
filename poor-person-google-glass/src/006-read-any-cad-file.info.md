<!-- written by Claude (Opus 5.5), 2026-10-10, for phase 0 (the CAD viewer): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 006-read-any-cad-file

One door for every format (issue 005): the file's ending picks the reader from a dispatch table.

| Offers | Takes | Gives |
|---|---|---|
| `read(path)` | a file path (string) | shape (with path and bytes_on_disk added), seconds spent reading (number); raises on an ending with no reader, naming those that have one |
| `READERS` | | { stl, obj, gltf, glb = reader function } |
| `endings()` | | sorted list of readable endings |
| `read_bytes(path)` | | the whole file as a string; raises if it cannot be opened |
