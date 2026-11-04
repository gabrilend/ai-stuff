# libs/guide-room.lua — info

A guide's two dated ledgers (made public, kept to itself) and its changes
ledger, inside its room. Issue 065e. Writes; does not decide who may — the
room's ownership does that.

| | |
|---|---|
| `M.open(room_dir)` | a room record `{ dir string }`; refuses a missing folder |
| `M.make_public(room, path, note)` | lists a file of the room as shared, with a one-line note |
| `M.keep(room, path)` | lists a file as kept to itself (known to exist, not shared) |
| `M.record_change(room, path, kind)` | dates an `edit` or `extension` of a listed file |
| `M.read(room, ledger)` | entries of `public`, `private` or `changes`: `{ written string, path string, note string, field_count integer, line integer }` |
| `M.check(room)` | list of problem strings; empty means in order |
| `M.now()` | the time stamp used; replaceable (tests stand in a clock) |
| `M.ledger_files` | ledger name → `{ file string, fields integer }` |

## Ledger files (tab-separated, one entry per line)

| File | Fields |
|---|---|
| made-public.ledger | written, path, note |
| kept-to-itself.ledger | written, path |
| changes.ledger | when, path, `edit` or `extension` |

Times are `YYYY-MM-DDTHH:MM:SS` (sort as they read). Paths are relative to
the room, never absolute, never `..`, never holding a tab or line break.

## Rules `M.check` holds

Each line has its fields; each time is well formed and not earlier than the
line before; each path names a real file in the room; each change is an edit
or extension of a file already listed public or kept.
