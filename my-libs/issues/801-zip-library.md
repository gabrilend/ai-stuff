# Issue 801: Zip Library — a packer and a metered reader, shared

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Dependencies:** None (moves rao-chat's issue 216e code here)

---

## Current Behavior

rao-chat (issue 216e) has its own zip packer and reader:
`src/attachments/203-inflate.lua`, `204-zip-reader.lua`, `205-zip-writer.lua`.
They run on LuaJIT only: they use its C bridge (FFI) for byte buffers,
`mkdir`, `chmod` and `utime`, and its `bit` library.

rmail still unpacks with the system `unzip`, with its zip-bomb and link
defences wrapped around that program (rmail #404a, #327), and packs with
the system `zip`. rmail usually runs on plain Lua 5.4 (its own install
builds 5.4.7), which has neither FFI nor `bit`.

## Intended Behavior

The owner (2026-09-30), asked whether rmail and rao-chat should share one
zip reader and packer in my-libs: *"yes please"*.

`my-libs/zip/` holds the library, which runs unchanged on LuaJIT and on Lua
5.3/5.4:

- `src/zip-compat.lua`: the only place the two interpreters differ.
  - bit operations: LuaJIT's `bit`, or 5.3+'s own operators, built from
    source strings with `load`, so this file still parses on LuaJIT;
  - results are brought to unsigned 32 bits wherever they are compared;
  - a byte window: an FFI `uint8_t` array, or a plain table;
  - making folders, and setting permissions and times: FFI calls
    (`mkdir`, `chmod`, `utimes`), or `mkdir`, `chmod` and `touch` run
    through the shell.
- `src/zip-inflate.lua`: stored and deflated entries under a meter, as
  216e built it. The sink now receives a Lua string, so it is the same on
  both interpreters.
- `src/zip-reader.lua`, `src/zip-writer.lua`: as 216e built them.
  - The reader has one new option, `exact`. When true (rao-chat), the
    total must equal the agreed size. When false (rmail, whose senders
    declare `du -sb` sizes, which are not exact), the agreed size is only
    an upper bound.
  - The meter holds every entry to its own claimed size either way.
- `tests/test-zip.lua`: 216e's checks, standalone (no project kit), run by
  `tests/run-tests` under every interpreter present (luajit, lua5.4).
- Each project carries a copy in its `libs/` folder, made by `install-into`
  and checked by `check-copy` in its tests. A link would not survive rmail
  being installed on another machine. Both projects therefore run
  identical code.

Known limit: the packer lists trees with GNU `find -printf`, so it does not
run on macOS or BSD (rmail #384).

## Suggested Implementation Steps

1. Write `zip-compat.lua`. Move the three files, renamed, onto it: no FFI
   or `bit` outside the compatibility layer.
2. Port 216e's test to run standalone. Run it under luajit and lua5.4.
3. Write the info notes and a README for the library; update my-libs'
   README and progress.
4. rao-chat: a copy in `libs/`, requires renamed, its own files removed, its
   runner runs the library's test (rao-chat 216e is updated).
5. rmail: a copy in `libs/`. Received contact zips and phone uploads are
   unpacked by the reader, which replaces `unzip`, the `zipinfo` link
   check and the `unzip -p | head -c` size count. Packing by the writer
   replaces `zip` (rmail issue filed there). rmail's tests are run.
