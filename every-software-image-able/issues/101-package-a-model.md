# 101 — Package a model, whichever one

## Current behavior

No layout is defined for the weights, and no tool produces one.

## Intended behavior

A packing format, and a tool that puts **any** suitable model into it. The model
is not chosen here — it is chosen by whoever builds an image, using the build
utility (`502`). Different images carry different models; that is a parameter,
not a decision baked into the project.

The format has to be self-describing, because at the moment the engine starts
there is no filesystem, no allocator and no operating system. There is a block of
bytes at a known offset. Everything about the shape of what is being held has to
be inside those bytes.

## Suggested implementation steps

1. Define the header: a magic number, a format version, the model's dimensions —
   layers, heads, head width, hidden size, vocabulary — and a table naming every
   tensor with its shape, precision and byte offset. Offsets are measured from the
   start of the blob rather than the start of the image, so the blob can move
   without being rewritten.
2. Support more than one precision, and record which is in use per tensor. This
   is not only a size decision: it reaches into `103`, because sixteen-bit floats
   and plain eight-bit integers keep the inner loop simple, while block-quantised
   formats where a group of weights shares a scale factor are much smaller and
   require a dequantise step inside the hottest loop in the machine. The format
   should permit both; the engine decides which it supports.
3. **Pack the tokenizer table alongside the weights.** The vocabulary and the
   ranked merge rules are not in the weights and cannot be derived from them — the
   model works in integers and nothing in it says which string each integer is.
   They are published beside the model and they travel with it. The code that uses
   them is `105a`.
4. Write the packer, in LuaJIT with shell around it, taking published weights and
   producing this layout. It runs on a development machine, never on the seed.
5. Write the reader as a separate program that validates a packed blob and prints
   what it found. Generation and viewing stay separate.
6. Round-trip test: pack, read back, compare every tensor byte for byte.

## Where the budget check lives

Not here. The build utility (`502`) is what knows the target board, and it is
where a model too large for the board it is being built for should be refused —
with the three numbers said out loud: what the medium holds, what the board's
memory holds alongside working space, and what the resulting speed will be.

## Blocks

`102`, `103`, `105`, `105a`.

## Blocked by

Nothing.

## Related documents

`docs/010-datapath-the-mind.md` — what ships on the chip.
