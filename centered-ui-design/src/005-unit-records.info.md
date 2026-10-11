<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 005-unit-records

One unit = 12 floats (48 bytes) in shared memory, readable by workers and by the graphics card unchanged.

Record: A = r, angle, heading, length; B = width, owner, level, phase; C = speed_r, speed_angle, order_kind, named. Header: front (0/1), step_seconds, step_number, unit_count.

| Offers | Gives |
|---|---|
| `records_at(pointer)`, `header_at(pointer)` | ffi arrays over raw memory, indexed from 0 |
| `copy_record(destination, source)` | field-for-field copy |
| `RECORD_BYTES`, `HEADER_BYTES`, `VERTEX_FORMAT` | sizes; the matching LÖVE vertex format (UnitA, UnitB, UnitC) |
