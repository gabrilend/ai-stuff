# The Safe Opcode Format (the "bytecode")

The bytes that cross the wire are a stream of **opcodes**. Each opcode is one data
operation on an in-RAM arena. This document is the authority on the format; the
encoder and interpreter must match it exactly, and it changes only alongside them.

## The one rule that makes it safe

The opcode set is **total over the RAM arena and nothing else.** Every opcode's
entire effect is "change some bytes in a region we own." There is deliberately:

- no jump, call, branch, or loop opcode,
- no eval / exec / run opcode,
- no syscall / open-file / open-socket opcode,
- no opcode that carries or dereferences a host memory address.

So a hostile stream can fill your arena with garbage, resize your regions, or
delete them. It **cannot** make your CPU run its bytes, and it cannot reach one
byte outside the arena — because no opcode in the vocabulary can express either
thing. Safety here is the *absence* of capability, not a guard bolted on top.

## Why this is also universal

The wire format is **address-free and endian-fixed**:

- All integers are little-endian, fixed width (`u8`/`u16`/`u32`). No native ints,
  no pointers, no host addresses ever travel on the wire.
- Regions are named by string, and written by *offset within the region* — never
  by absolute memory address.

Because nothing machine-specific is on the wire, an opcode stream means the same
thing on any operating environment or system: a 64-bit Linux host, a bare-metal
board with a fixed physical RAM range, a WASM module's linear memory. Each end
maps names+offsets onto whatever RAM it actually owns. That mapping is the only
OS-specific part, and it lives *below* the wire, not on it.

## Primitive encodings

| type   | encoding                                             |
|--------|------------------------------------------------------|
| `u8`   | 1 byte                                               |
| `u16`  | 2 bytes, little-endian                               |
| `u32`  | 4 bytes, little-endian                               |
| `str`  | `u16` length, then that many bytes (names, meta)     |
| `blob` | `u32` length, then that many bytes (region contents) |

## The opcodes (format v0)

| byte   | name            | operands                          | effect                                             |
|--------|-----------------|-----------------------------------|----------------------------------------------------|
| `0x00` | `OP_NOP`        | —                                 | nothing                                            |
| `0x01` | `OP_FILE_ALLOC` | `name:str  size:u32`              | reserve a named region of `size` bytes in the arena|
| `0x02` | `OP_FILE_WRITE` | `name:str  offset:u32  data:blob` | write `data` at `offset` in the region (the direct-RAM poke; bounds-checked) |
| `0x03` | `OP_FILE_TRUNCATE` | `name:str  newsize:u32`        | resize the region to `newsize`                     |
| `0x04` | `OP_FILE_DELETE`| `name:str`                        | free the region                                    |
| `0x05` | `OP_FILE_META`  | `name:str  key:str  value:str`    | set a handling/`direction` metadata field          |
| `0xFF` | `OP_END`        | —                                 | end of message (optional marker)                   |

Transferring a whole file is just `OP_FILE_ALLOC name,size` followed by
`OP_FILE_WRITE name,0,contents` — "put a file" expressed as memory operations,
which keeps the model honest: it is all writes into RAM.

## Validation the interpreter must perform (errors, never fallbacks)

1. **Unknown opcode byte → hard error.** No "skip the byte and continue"; an
   unrecognized opcode means the stream is not something we understand, and
   guessing is how injection bugs are born.
2. **Every length field is checked against the bytes actually remaining.** A `str`
   or `blob` that claims more bytes than are present → error, never an over-read.
3. **Every `OP_FILE_WRITE` is bounds-checked**: `offset + len(data)` must fit
   inside the named region, and the region inside the arena. Out of bounds → error.
4. **Names are validated** (no empty names; no path separators or `..`, so that a
   future disk-backed arena cannot be walked out of). Defense in depth even while
   the arena is pure RAM.

The interpreter dispatches each opcode through a table (opcode byte → handler
function), not a chain of if/else — see `docs/architecture-overview.md`. Adding an
opcode is adding a table entry and a doc row here; the two are one change.
