# Roadmap — USB-C Universal Encoder

The vision (see `notes/vision`): put *any* data into a USB-C datapath and receive
it on the other end, with no risk of arbitrary code execution, because the thing
crossing the wire is never *code* — it is a stream of **data operations** applied
to an in-RAM file store. Everything is a file. The far end consumes or rewrites
those files and sends them back, TCP-style.

The phases below are **clusters of functionality**, not a schedule. Lower phases
are more foundational — higher phases build on them. It is expected and fine for
a late-completed issue to belong to phase 1.

**Universality is a first-class goal.** The core must run in *any* operating
environment or system, ideally by modifying the actual RAM locations itself rather
than going through OS file services. The store is therefore a flat byte **arena**
we own — a real contiguous block of memory we poke directly — and the wire format
is address-free, so it means the same thing on a 64-bit Linux host, a bare-metal
board with a fixed physical RAM range, or a WASM module's linear memory. The only
OS-specific glue lives at the edges (how you obtain the RAM, how you move bytes),
never in the data core. See `docs/safe-opcode-format.md` for why direct-RAM writes
stay safe (every write is bounds-checked into the owned arena — the wire never
carries a host address, so this is not a DMA-attack primitive).

---

## Phase 1 — The RAM data core

The heart of the system, and the part that needs no USB hardware to build or
test. If this phase is correct, the wire is "just plumbing."

- A flat RAM **arena**: a real, pre-allocated, contiguous block of memory we own,
  written and read directly at byte offsets (via LuaJIT FFI, an actual `uint8_t*`),
  with a region allocator (alloc / free / resize). This is the "modify the actual
  RAM locations" substrate, and it needs no OS filesystem.
- A **file directory** over the arena: files are named regions, each with metadata
  (including the `direction` field that says how the far end should handle it). The
  friendly "everything is a file" API, backed by raw memory.
- The **safe opcode format** ("bytecode"): a fixed, tiny instruction set whose
  *only* effect is mutating the file store. There is deliberately **no run / eval
  / jump / syscall opcode**. This absence is the security guarantee.
- A **data-generation** side (encode a store, or a set of changes, into an opcode
  byte stream) and, kept strictly separate, a **data-consumption** side (apply an
  opcode byte stream to a store via a dispatch table).
- A capstone loopback demo: a file made in store A crosses an opcode stream and
  reappears, byte-identical, in store B — with no code ever having run.

## Phase 2 — Framing & the link

Make an opcode stream survive an unreliable byte channel, and hide the channel
behind one small interface so the USB layers can be swapped in later.

- Length-delimited frames with a checksum, so a partial or corrupt frame is an
  error, never a silent mis-read.
- A `link` interface (`send(bytes)` / `recv() -> bytes`) with in-process loopback
  and OS-pipe / socketpair backends for development on a single machine.
- Back-pressure and flow control between a fast producer and a slow consumer.

## Phase 3 — USB device (the gadget)

The end that pretends to be a USB device.

- FunctionFS: a userspace program writes USB descriptors to `ep0`, then reads the
  bulk-OUT endpoint and writes the bulk-IN endpoint.
- Bridge those two endpoints to the Phase-2 `link` interface.
- Runs on a gadget-capable board (configfs must be available — it is *not* on the
  current dev machine, confirmed at scaffold time).

## Phase 4 — USB host

The end that drives the device.

- libusb via LuaJIT FFI: enumerate, open, claim the interface, bulk transfer.
- Bridge the bulk endpoints to the same Phase-2 `link` interface, so host and
  device run the identical framing + opcode stack.

## Phase 5 — Handling interface & demos

The user-facing layer the vision describes: "click a button, assign directions
for how a file should be handled, fill it with whatever datasource you want."

- File `direction` / handling metadata routed to consumers (a dispatch table from
  a file's declared handling to the code that consumes it).
- Datasources: sensor data, text, generated encodings — anything that fills a file.
- The phase demos, treated as part of the deliverable, not just dev artifacts.

---

Issues are derived from these phases in `issues/`. Statistics about progress are
not hardcoded here — run the progress reporter (to be added) rather than trust a
number written in prose that will go stale.
