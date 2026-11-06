# Issue 118: The Binary Readers Check There Are Enough Bytes

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** the compatibility layer (`src/compat.lua`, Phase 1)
**Tracks:** known debt D-3 in `issues/CRITICAL-PATH.md`
**Status:** Completed 2026-11-02

---

## Current Behavior

Every map-file parser reads numbers through the `unpack_*` readers in
`src/compat.lua`. They take two paths. On Lua 5.3 and later they call
`string.unpack`, which refuses data that is too short with "data string
too short", without saying where. On LuaJIT, the path the engine runs, they
take four bytes (or two, or eight) with `string.byte` and add them up
without checking there are that many. A file that is cut short then fails
on arithmetic with a missing value ("attempt to perform arithmetic on
local 'b3' (a nil value)"), which names the wrong cause and no position.

The critical path records this as debt D-3: "check the length and raise an
error that says the file is truncated and where."

## Intended Behavior

Every reader, on both paths, checks the data holds the bytes it is about to
read. A short read raises the same error on both:

```
src/parsers/w3e.lua:123: truncated data: a uint32 at byte 1201 needs 4 bytes, but the data is 1203 bytes long
```

The error is reported at the line of the parser that called the reader, so
it says which file was being read. A read that fits is unchanged: same
value, same next position.

## Suggested Implementation Steps

1. A local `need(data, pos, count, what)` in `compat.lua` that raises at
   level 3 (the reader's caller) when `pos + count - 1` passes the end.
2. Call it first in each of the twelve readers (six per path), after the
   default position is filled in.
3. Leave negative positions (counted from the end, which `string.unpack`
   accepts) to the reader as before.
4. A test that runs every reader on known bytes, at the data's end, and one
   byte short, on LuaJIT and on Lua 5.4.
5. Take D-3 off the critical path's known debt.

## Acceptance Criteria

- [x] Each of the six readers, on LuaJIT and on Lua 5.3+, fails a short
      read with "truncated data", the reader, the byte, the bytes needed and
      the data's length
- [x] The error names the calling parser's file and line
- [x] Reads that fit return the same values and positions as before
- [x] The full test suite passes as before
- [x] D-3 is removed from `issues/CRITICAL-PATH.md`

## Notes

- Every short read already failed before this change, on both paths; only
  the message changes, so no parser that catches errors behaves
  differently.
- The check costs one string-length comparison a read.

## Implementation Notes

**Date:** 2026-11-02

- **`src/compat.lua`:** `need()` added under Binary unpacking, called by
  all twelve readers. The file's header comment describes the error.
- **`src/tests/test_compat.lua`** (31 tests): each reader reads known
  bytes (including a negative int32, an int16 of -32768, a float of -3.5
  and a double of 3.0) to the right value and next position, reads the
  data's last bytes, and fails one byte short and past the end with the
  named error at the test's own line. Under LuaJIT the test runs itself
  again under `lua5.4`, so both paths are checked in one run. Against the
  old `compat.lua` it fails 19 of 31.
- **Full suite:** every test that passed before still passes. The one
  that failed before, `test_net_hosted`, still does: it needs the `effil`
  threading library from the owner's machine.

### Decisions made while building

1. **The error is raised at level 3**, the parser's line, not at
   `compat.lua`'s own line: the parser's line says which file was cut
   short, which is what the person reading the error needs. A parser that
   reads in a tail call (`return compat.unpack_uint32(...)`) leaves no frame
   of its own, so the error then points one call further out.
2. **Both paths check, not only LuaJIT's.** `string.unpack` already
   refused short data, but its message didn't say where; one message on
   both keeps the tests and the person reading the error the same on
   either Lua.
