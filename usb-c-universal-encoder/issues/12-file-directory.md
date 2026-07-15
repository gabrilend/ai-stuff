# 12 — File directory over the arena

The friendly "everything is a file" API, backed by the raw memory of issue 11.

## Current behavior

Not yet implemented. Issue 11 (the arena) provides raw regions but no names,
metadata, or file semantics.

## Intended behavior

- A file is a **named region** of the arena plus a metadata table.
- Create/replace a file by name from a byte string (allocates a region, writes the
  bytes into it directly).
- Append to, truncate, read, and delete a file by name.
- Per-file metadata as string key→value; the reserved key `direction` records how
  the far end should handle the file (from the vision: "assign directions for how
  that file should be handled").
- Query API only, no rendering: `exists(name)`, `stat(name)` (size, meta, seq),
  `list()` (names, deterministically ordered), `count()`. A monotonic sequence
  counter orders writes without any wall-clock (portable, deterministic in tests).
- Missing-file reads are **errors**, not nil returns — callers use `exists` when
  absence is a legitimate branch.
- Name validation rejects empty names and path-traversal (`/`, `..`) so a future
  disk-backed arena cannot be walked out of.

## Suggested implementation steps

1. `src/01-file-directory.lua`: wraps an arena instance; holds `files[name] =
   {offset, size, meta, seq}`.
2. Route every content mutation through the arena's allocator + direct writes; the
   directory never copies bytes into a Lua string for storage — the bytes live in
   the arena.
3. Keep data *generation/mutation* here; keep *viewing/rendering* out (that is a
   separate viewer, added with the demo in issue 16).
4. Tests in `tests/01-file-directory-test.lua`: create/read/append/truncate/delete,
   metadata set/get, list ordering, traversal names rejected, missing-file read
   raises.

## Related documents and tools

- Blocks on issue 11. Feeds issues 14 (encoder) and 15 (interpreter).
- `docs/datapath-file-transfer.md` (the store node), `src/01-file-directory.info.md`.
