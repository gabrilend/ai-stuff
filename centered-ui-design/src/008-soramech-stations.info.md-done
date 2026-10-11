<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 008-soramech-stations

The soramech engine (Lua route): a station runs when every input slot holds a value; pool stations become tasks taken first come, first served by workers.

| Offers | Takes | Gives |
|---|---|---|
| `new_map(pool)` | anything with push(table) | an empty map |
| `add_station(map, description)` | name, box, slot_count, where ("pool" or "here"), on_ready (for "here"), static | the station's index; refuses an unknown "where" |
| `deliver(map, station, slot, value)` | | true if the delivery made the station run |
