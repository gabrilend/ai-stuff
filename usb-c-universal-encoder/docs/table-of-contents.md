# Documentation — Table of Contents

The tree of documents for the USB-C Universal Encoder. Source files and issue
files are not listed here (only `docs/`, `notes/`, and similar prose); the source
carries its own ordering via indexed filenames, and issues live under `issues/`.

## notes/
- `notes/vision` — the original vision: any data into a USB-C datapath, received
  safely on the other end, everything a file in RAM, TCP-style.
- `notes/roadmap.md` — the phases (functionality clusters), foundational first.

## docs/
- `docs/architecture-overview.md` — the whole system in one picture: the wire
  carries data operations, never code; only a small interpreter runs, and all it
  can do is mutate a RAM arena. Includes the universality argument.
- `docs/datapath-file-transfer.md` — **datapath doc** tracing one file end to end,
  datasource → store → encoder → frame → link → USB → interpreter → store →
  consumer. The reference every layer must agree with.
- `docs/transport-design.md` — why the USB-C wire uses **raw bulk endpoints**
  (FunctionFS on the device, libusb on the host) rather than USB networking or
  serial, and how each end moves bytes.
- `docs/safe-opcode-format.md` — the "bytecode": the exact opcode set, its
  primitive encodings, the security argument (safety = absence of capability), and
  why the address-free wire format is portable across any OS.
- `docs/mount-as-filesystem.md` — how a USB-C peer is mounted under `/mnt/` via
  FUSE, the VFS-operation → opcode mapping, the mount safety options that keep the
  no-execution promise, and local vs peer mode.
- `docs/delivery-self-installing-cable.md` — how the cable carries and installs its
  own software: the packager, the one-command self-installer, why there is no silent
  autorun (BadUSB), and how dependencies are reported rather than hidden.

## The phases (functionality clusters)

Named here so the documentation and the roadmap agree. These organize related
functionality; they are not a schedule.

1. **Phase 1 — The RAM data core.** The arena, the file directory over it, the safe
   opcode format, the encoder, the interpreter, and a loopback round-trip demo.
2. **Phase 2 — Framing & the link.** Length+checksum frames and the one small
   `link` interface (loopback / pipe backends).
3. **Phase 3 — USB device (gadget).** FunctionFS descriptors + bulk endpoint I/O.
4. **Phase 4 — USB host.** libusb via LuaJIT FFI, bulk transfer.
5. **Phase 5 — Handling interface & demos.** File `direction` metadata routed to
   consumers, datasources, and the phase demos as deliverables.
6. **Phase 6 — Mount USB-C links as filesystems.** A connected peer appears under
   `/mnt/` via FUSE; `cp`/`ls`/`cat`/`rm` are the interface, mounted no-exec.
7. **Phase 7 — Delivery: the self-installing cable.** The cable bears the software;
   plug it in and it runs in place or installs with one explicit command.

---
Whenever a document is added here, add it to the tree above. Numbers and
statistics belong in validators/reporters that can be run, not written into prose
that goes stale.
