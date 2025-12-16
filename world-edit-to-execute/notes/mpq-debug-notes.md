# MPQ Debug Scripts

Debug scripts for tracking down the file extraction issue in Issue 102d.

## Scripts (in tmp/)

1. `debug-offset.lua` - Tests the offset reading with fixed 1-based indexing
2. `debug-extract.lua` - Runs the full extraction test (TODO)

Run with: `lua5.3 tmp/debug-offset.lua`

## Issue Being Debugged

File extraction returns 0 bytes. The suspected issue was an off-by-one error
in the offset calculations (mixing 1-based Lua positions with 0-based MPQ offsets).

## Fix Applied

Changed `extract.lua` to use `absolute_offset` directly without adding 1,
since it's already a 1-based Lua position.

## Note

The tmp/ directory should be compressed at each major release version.
