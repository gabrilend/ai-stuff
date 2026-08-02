# 703 — Watch what it wrote

## Current behavior

**Done, and tested** -- `src/094`, checked by `src/096`, 19 of 19 on
2026-08-02.

Attaching a debugger was never the hard part; the trap runner already did it.
The hard part is that the code under inspection was produced at runtime by
the model, so there is no file, no symbols and no names, and a debugger can
say only that it is at an address.

**The requirement this ticket put back on `204` is met rather than assumed.**
The machine writes its own bookkeeping into guest memory in a layout declared
once as data -- which programs it built, where each went, how long each is,
and the text each was made from. Nothing inside the machine needs it in that
shape; a tool outside does, and that makes it a contract with something that
lives outside the machine.

A tool with nothing to ask finds it by scanning for a number nothing else
would plausibly be, then walks the records using a stride read from the
record itself rather than assumed -- so a machine that has grown and changed
its own bookkeeping can still be walked by a tool built before it changed.

The answer the ticket exists for: an address becomes "you are thirty-two
bytes into the thing it called the thing that finds disks, of four hundred",
with the text it was made from beside it. Where to break is exactly what the
machine built, so that list is the ledger rather than a second one that could
drift.

**It does not pretend to know which line.** The assembler inserts a watch at
every loop back-edge, so the instruction count and the line count drift
apart, and the tool says nothing rather than guessing -- which is checked.

## Intended behavior

The emulated machine can be stopped from outside and its registers and memory
read, so that assembly nobody wrote by hand can be stepped through one instruction
at a time.

## Suggested implementation steps

1. Attach a debugger to the emulator and confirm the basics: stop, step, read a
   register, read memory, set a breakpoint at an address.
2. Solve the naming problem. The code under inspection was produced at runtime by
   a model, so there is nothing to load symbols from. What exists is the pairing
   kept by `204` — the text the model wrote beside the bytes it became — and
   something has to turn that into "you are at instruction eleven of the thing it
   called the allocator."
3. **Which puts a requirement back on `204`: the machine's own bookkeeping has to
   be readable from outside.** A debugger attached to the emulator sees raw guest
   memory, so the layout of the structure pairing text with bytes — and the memory
   map, and the list of arenas — is part of a contract with a tool that lives
   outside the machine, even though nothing inside the machine needs it to be.
   Fix those layouts and write them down, or every debugging session begins by
   working out where things are.
3. Provide a way to break at the moment the machine hands control to code it just
   produced. That transition is where the interesting failures are, and it happens
   at an address nobody knew in advance.
4. Show the machine's own working memory in a readable form: the memory map from
   `102`, the ranges marked occupied, the arenas handed out. A dump of hexadecimal
   is not this.
5. Keep this usable by a person under stress. It is the tool reached for when
   something incomprehensible has happened, which is the worst moment to be
   learning it.

## Blocks

Nothing formally. In practice, the debugging of `204`, `601` and `602`.

## Blocked by

`701`, and `204` for the text-and-bytes pairing.

## Related documents

`docs/012-datapath-the-proving-ground.md`.
