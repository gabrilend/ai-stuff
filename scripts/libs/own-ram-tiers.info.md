# own-ram-tiers.lua

Finds the two RAM scratch rooms belonging to the folder a Claude Code session
runs in, as real places (links followed). Shared by
`harness-hooks/allow-own-ram-tiers` and `harness-hooks/refuse-outside-writes`
so the two cannot disagree (issues 042, 043).

Rooms: `<folder>/tmp` → `/tmp/<name>` (exec room) and
`/tmp/<name>/shared-memory` → `/dev/shm/<name>` (artifact room). Only the
session folder's own `tmp` link counts, never one above it; a room counts only
when it lies strictly below its RAM root; a dangling link names no room.
`EXEC_TIER_ROOT` and `ARTIFACT_TIER_ROOT` in the environment move the roots,
for tests only.

| function | takes | gives |
| --- | --- | --- |
| `rooms_of(cwd)` | absolute folder (string) | list of strings: none, the exec room, or both rooms |
| `real_place(path, must_exist)` | path (string), boolean | the real place (string), or nil; `must_exist` uses `realpath -e`, otherwise `-m` (a file not yet made is judged by its folder) |
| `is_inside(place, folder)` | two real places (strings) | true when `place` is `folder` or below it, compared up to a `/` |
