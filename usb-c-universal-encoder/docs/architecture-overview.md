# Architecture Overview

One sentence: **the wire carries data operations, never code, and the only thing
that ever executes is a small interpreter that applies those operations to a file
store held in RAM.**

That single design choice is where the "no arbitrary code execution" promise in
the vision comes from. It is not enforced by a sandbox bolted on afterward; it is
structural. The instruction set has no verb that runs anything.

## The layers, bottom (foundational) to top

```
  datasource (sensor / text / encoding / any bytes)
        |
        v
  [1] RAM arena + directory .. a real contiguous byte block we own; files are
        |                       named regions poked directly at offsets
        |
        v
  [2] safe opcode format ..... the "bytecode": FILE_PUT/APPEND/TRUNCATE/DELETE/META
        |                       — and nothing that can run code
        |
   [3] encoder  <----- separated from ----->  [4] interpreter
   (data generation)                          (data consumption, dispatch table)
        |                                            ^
        v                                            |
  [5] framing + link ......... length + checksum frames over one small interface
        |                                            |
        v                                            |
  [6] USB device (FunctionFS)  <--- USB-C wire --->  [7] USB host (libusb)
        (bulk OUT / bulk IN endpoints)
```

## Why each layer exists

- **[1] RAM arena + directory** — the vision says "everything is a file, stored in
  RAM," and universality demands we modify the actual RAM locations ourselves. So
  the store is a flat, pre-allocated, contiguous byte **arena** we own (a real
  `uint8_t*` via LuaJIT FFI), and a **directory** maps file names to regions inside
  it. Files are poked directly at byte offsets — no OS filesystem in the path. The
  store is pure data and pure mutation: no transport, no rendering. It is the one
  thing every other layer agrees on. See `docs/datapath-file-transfer.md`.

- **[2] safe opcode format** — a file operation, encoded as bytes. The complete
  opcode list and the exact security argument live in `docs/safe-opcode-format.md`.
  The important property: the set is *total over the file store and nothing else*.

- **[3] encoder / [4] interpreter** — kept in separate files on purpose (data
  generation is written and debugged apart from data viewing/consumption, so a bug
  is trapped on one side of the wire). The interpreter dispatches each opcode
  through a table (opcode number → handler), never a chain of if/else.

- **[5] framing + link** — an opcode stream is just bytes; to cross a real channel
  it gets wrapped in frames (length + checksum) so a truncated or corrupt frame is
  a hard error instead of a silent misread. The `link` interface hides whether the
  channel is an in-process loopback, an OS pipe, or a USB endpoint pair.

- **[6] USB device / [7] USB host** — the two ends of the USB-C wire. Both run the
  exact same framing + opcode stack; only the bottom "move these bytes" primitive
  differs (FunctionFS bulk endpoints on the device, libusb bulk transfers on the
  host). See `docs/transport-design.md` for why raw bulk endpoints were chosen over
  USB networking or serial.

## What runs, and what does not

The only executable code is *ours*: the store, the encoder, the interpreter, the
framing, the USB glue. The bytes that arrive from the other end are *never* run.
They are read by the interpreter, validated, and turned into file mutations. A
hostile peer can fill your RAM store with garbage or delete your files; it cannot
make your CPU execute its bytes, because there is no opcode that would.

## Universal by construction

The system must work in any operating environment or system. It does, because the
only two things the data core needs from its host are:

1. **A block of RAM it can write to.** Under an OS that is a malloc'd FFI buffer;
   on bare metal it is a fixed physical address range; in WASM it is linear memory.
   The arena does not care which — it is "some bytes we own."
2. **A way to move bytes in and out** — the `link` interface. That is a loopback,
   an OS pipe, or a USB bulk endpoint pair, chosen at the edge.

Everything between those two — arena, directory, opcodes, encoder, interpreter,
framing — is portable code with no OS dependency, and the wire format carries no
host addresses, so the two ends need not share an OS, a word size, or an endianness.
"Modify the actual RAM locations, without the OS in the path" is honored *and* kept
safe: the pokes are direct, but bounded to the arena we own (see the security
argument in `docs/safe-opcode-format.md`), so it is not a DMA-attack primitive.
