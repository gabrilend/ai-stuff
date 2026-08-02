# 703 — Watch what it wrote

## Current behavior

When code the machine produced misbehaves, there is nothing to look at. No source
file, no symbols, no names — and before `202` works, nothing to print with either.

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
