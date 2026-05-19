---
name: on-device assembly toolchain
phase: 12
status: pending
blockedBy: [1104]
---

# 1202 — on-device assembly toolchain

An ARM assembler and linker that run on the bare-metal Apple IIds
itself. Source files edited in the soramech editor (issue 1201)
can be assembled and linked into runnable programs without leaving
the device.

## current behavior

ARM assembly source is built on the development host using cross-
compilers, then transferred to the device. The device cannot
build its own programs.

## intended behavior

- A native ARM assembler runs as an Apple IIds application:
  - Reads source files via the File Manager.
  - Produces object files in a documented format.
  - Reports errors via the editor (issue 1201) integration.
- A linker (also native) combines object files into executables:
  - Resolves symbols.
  - Lays out memory.
  - Emits the executable in Apple IIds's native binary format.
- The toolchain is reasonably fast — assembling a 1000-line file
  in under 1 second on the 2 GHz A55.
- The toolchain is itself written in ARM assembly (per the
  bare-metal-core memory: ARM assembly is the only language).

## suggested implementation steps

1. Design the object file format. Apple IIds's native binary
   format — same as what the Toolbox loader (issue 1104)
   loads.
2. Implement the assembler. Parse ARM assembly per the standard
   ARM v8-A grammar. Emit machine code.
3. Implement the linker. Resolve relocations. Lay out segments.
4. Provide a command-line interface usable from the editor.
5. Self-host: build the assembler with itself, build the linker
   with itself. Confirm the produced binaries are identical to
   the bootstrap versions (modulo timestamps).

## related documents

- `issues/1201-soramech-editor-port.md` — the editor that calls
  this toolchain
- `issues/1104-iigs-toolbox-arm.md` — the runtime that loads the
  produced binaries

## known design questions

- ARM v8-A is a big instruction set. The on-device assembler
  doesn't need to support every esoteric instruction — focus on
  the subset Apple IIds programs actually use. Document the
  supported subset.
- Self-hosting is a milestone but not strictly required for
  phase 12. The toolchain can be developed cross-compiled
  initially, then ported.

## notes

- A self-hosting toolchain is a classic systems milestone — once
  achieved, the project's identity as a self-contained ecosystem
  is locked in. Bonus points.
