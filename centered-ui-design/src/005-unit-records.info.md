<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 005-unit-records

Units (16 floats, 64 bytes) and cuboids (12 floats, 48 bytes) in shared memory, readable unchanged by the ceramic workers (020's structs match) and the graphics card.

Unit: A = r, angle, heading, length; B = width, owner, level, phase (walking); C = speed_r, speed_angle, order_kind, named; D = job, target, wants, carrying. Cuboid: A = r, angle, height, size; B = color, state, claimant, carrier; C = timer, slot, appearances, turn.

| Offers | Gives |
|---|---|
| `records_at(pointer)`, `cuboids_at(pointer)` | ffi arrays over raw memory, indexed from 0 |
| `copy_record(destination, source)` | a unit record copied whole |
| `RECORD_BYTES`, `CUBOID_BYTES`, `VERTEX_FORMAT`, `CUBOID_VERTEX_FORMAT` | sizes; the matching LÖVE vertex formats |
| `JOB_IDLE/FETCHING/CARRYING`, `CUBE_LYING/CARRIED/DELIVERED` | what the job and state numbers mean |
