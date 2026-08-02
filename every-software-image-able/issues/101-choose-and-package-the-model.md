# 101 — Choose and package the model

## Current behavior

No model is chosen and no layout is defined. The design documents say "a model"
and stop there.

## Intended behavior

A specific model, at a specific precision, laid out on the image at a known
offset, behind a header that describes itself completely enough that the engine
can find every tensor without a filesystem, a loader library, or any code that
knows the model's name.

Self-description is the requirement doing the work here. At the moment the engine
starts there is no filesystem, no allocator, and no operating system — there is a
block of bytes at a known offset and nothing else. Everything the engine needs to
know about the shape of what it is holding has to be in those bytes.

## Suggested implementation steps

1. Fix the budget first, because it decides the model rather than the reverse.
   Three numbers: how much drive the image may occupy, how much memory the target
   boards have, and how slow a first token is tolerable. `docs/010` names the
   engine as the thing that must work before anything else; a model that does not
   fit is not a candidate however good it is.
2. Choose the precision. Lower precision costs quality and buys both size and
   speed, and the arithmetic in `103` is simpler for some formats than others —
   pick with that issue open beside this one.
3. Define the header. At minimum: a magic number, a format version, the model's
   dimensions, the vocabulary, and a table of tensors giving each one's name,
   shape, precision, and byte offset. Offsets are from the start of the blob, not
   from the start of the image, so the blob can be moved without rewriting it.
4. Write the packer — a tool that takes weights in whatever form they are
   published and produces this layout. It runs on a development machine, not on
   the seed.
5. Write the reader as a separate program that validates a packed blob and prints
   what it found. Generation and viewing stay separate.
6. Round-trip test: pack, read back, compare every tensor byte for byte.

## Blocks

`102`, `103`, `105`. Nothing can be loaded, multiplied, or run until the layout
exists.

## Blocked by

Nothing. This is the first ticket in the project.

## Related documents

`docs/010-datapath-the-mind.md` — what ships on the chip, and why the engine
cannot be built by the machine.
