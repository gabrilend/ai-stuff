# 131-find-tensors — info

Locating every tensor in a packed model, on a bare machine, in all three tongues. The first piece of the driver (issue 107).

The engine needs to be handed the address of every table of weights before it can think. Hosted, a program asks the operating system to map a file and gets pointers back. On a bare machine there is no operating system, no file and no map -- there is a run of bytes somewhere in memory, and this walks it.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `131-find-tensors.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/131-find-tensors.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.HEADER_AT and M.ENTRY_AT` | computed from the format, not written |
| `M.x86_64(format)` | int64_t find_tensors(const uint8_t *blob, const void **out, int64_t wanted) |
| `M.aarch64(format)` | blob x0, out x1, wanted x2. Same returns. |
| `M.riscv64(p, format)` | blob a0, out a1, wanted a2. Same returns. |
| `M.expected_order(shape, shapes_module)` | The order the packer writes tensors in, as names, so a test can check that walking by index lands where walking by name would. |

### In more detail

**`M.HEADER_AT and M.ENTRY_AT`**

Asked rather than transcribed. The offsets below are the difference
between reading a model and reading noise, and a hand-copied number that
drifts by four produces a machine that thinks confidently about nothing.

**`M.x86_64(format)`**

int64_t find_tensors(const uint8_t *blob, const void **out, int64_t wanted)

blob rdi, out rsi, wanted rdx. Returns how many were written, or minus one
if the model holds fewer than were asked for, or minus two if any of them
claims bytes past the end of the blob.

The refusals are distinct numbers rather than one, because they mean
different things to whoever is reading a serial port: the first is a model
that does not match the engine, the second is a truncated one.

**`M.riscv64(p, format)`**

blob a0, out a1, wanted a2. Same returns.

Emitted into a counted program, because this assembler leaves a note for a
linker on a branch to a label in its own file and there is none to answer
it (054).

**`M.expected_order(shape, shapes_module)`**

The order the packer writes tensors in, as names, so a test can check that
walking by index lands where walking by name would.

This is the dependency the routines above rest on, made checkable. It
returns what `034` decides rather than a second opinion about it.

## Why this is the piece to write first

It is the one whose failure is silence. An address computed slightly wrong does not produce an error: it produces a number, which the arithmetic multiplies happily, and the machine thinks something that means nothing. Or it points into the engine's own instructions, and the next thing that writes there stops the machine permanently. Nothing above it is watching, because this project has nothing above it.

## By index, not by name

Every entry in the model carries a thirty-two byte name, and matching those in assembly would mean string comparison in the one routine that must not be clever. It is not needed: the packer writes the tensors in a fixed order that `034` decides -- what a token means, then the carried turns, then nine per layer, then the two at the end -- so the third tensor of the fourth layer is at an index arithmetic can find.

## What it refuses

A model claiming fewer tensors than were asked for, and a tensor whose bytes run past the end of the blob. Both are cheap to check here and impossible to notice later: the first hands back an address that was never written, and the second hands back one that is off the end of everything.

## Why the header's sixty-four bit fields are read in halves

Three of them sit at offsets that are not multiples of eight -- the header grew by four-byte counts and eight-byte offsets in whatever order made sense to a reader, and nothing ever needed them aligned before, because the host reads them with a language that does not care.

## Worth knowing

That is a real dependency and it is worth stating plainly rather than discovering: **if the packing order ever changes, this reads the wrong tensors and says nothing.** The order is checked against the names in the test rather than trusted, which is the only place the names are read at all.

A processor may or may not care, and that is the problem. The first architecture loads an unaligned eight bytes without comment. The other two are permitted to fault on it, and whether they do depends on a bit the FIRMWARE sets before handing over -- so the same instructions can work on one board and raise an exception with no handler on another of the same kind. This project has met that shape of difference before and writes it down rather than discovering it: `notes/023`.

Measured, so the claim is not louder than the evidence: the boards here tolerate it, and this was changed on principle rather than after a fault. Both halves are loaded as four bytes each and joined. It costs one instruction and removes the dependency on what firmware decided.

## Where it sits

**Belongs to** `107`.

**Checked by** `132-test-find-tensors`, `136-test-fill-the-plan`, `140-test-the-driver`.

