---
name: on-device debugger
phase: 12
status: pending
blockedBy: [1201, 1202]
---

# 1203 — on-device debugger

A debugger that runs on the bare-metal Apple IIds. Programs being
written in the soramech editor can be debugged on the device.

## current behavior

No debugging facilities exist on-device. Bugs in Apple IIds
programs are diagnosed by reading source carefully or by printing
state via `printf`-equivalents.

## intended behavior

- A debugger application (or a debugger mode of the editor):
  - Loads a program with its symbol table.
  - Sets breakpoints by line or address.
  - Steps instruction-by-instruction or line-by-line.
  - Inspects registers, memory, the call stack.
  - Continues, restarts, kills.
- The debugger uses the Apple IIds threading model: the debuggee
  runs as a separate task; the debugger task suspends / resumes
  it.
- Two-screen friendly: source code on screen A, register / memory
  view on screen B; both communicate via the broker IPC.
- The debugger is itself written in ARM assembly.

## suggested implementation steps

1. Design the debug-info format produced by the assembler /
   linker (issue 1202).
2. Implement the debugger backend: an Apple IIds task that owns
   the debuggee task's state and reads / writes its registers
   and memory.
3. Implement the debugger UI: integrated into the soramech editor
   (issue 1201) or as a sibling application.
4. Implement common debugger features: breakpoint, step, watch,
   evaluate.
5. Test by debugging a deliberately broken sample program.

## related documents

- `issues/1201-soramech-editor-port.md`,
  `issues/1202-on-device-assembly-toolchain.md` — the
  prerequisites

## known design questions

- Breakpoint mechanism: trap instructions are the natural ARM
  approach. The debugger inserts a trap at the breakpoint
  address; the kernel's trap handler reroutes to the debugger.
- Watchpoints: ARM has hardware watchpoint registers. Use them.
- Debugging the kernel itself (the broker-as-kernel from issue
  1106) is hard — the debugger runs on top of the kernel.
  Out of scope for phase 12; develop separately as a follow-up.

## notes

- The debugger is what makes the on-device development loop
  *complete*. Editor + assembler + debugger = a self-hosting
  development environment for ARM assembly.
