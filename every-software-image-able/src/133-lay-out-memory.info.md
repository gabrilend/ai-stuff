# 133-lay-out-memory — info

Deciding where everything a thought needs will sit, on a bare machine, with no allocator. The second piece of the driver (issue 107).

Running a model needs somewhere to put the cache of everything thought so far and eight working vectors. Hosted, a program asks for memory and is given some. Here there is nothing to ask. There is a run of memory the firmware said was usable, and this divides it up.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `133-lay-out-memory.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/133-lay-out-memory.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.REGIONS` | what a thought needs, and how large each is |
| `M.expected(shape)` | Where each region lands and how much room the lot needs, worked out on the host. |
| `M.header_offsets(format)` |  |
| `M.x86_64(format)` | blob rdi, room rsi, bytes rdx, out rcx. |
| `M.aarch64(format)` | blob x0, room x1, bytes x2, out x3. |
| `M.riscv64(p, format)` | blob a0, room a1, bytes a2, out a3. |

### In more detail

**`M.REGIONS`**

Order is layout. The sizes are expressions over the model's shape rather
than numbers, because the shape is read at run time -- and they are
written here once so that the host's answer and the machine's come from
one description.

`numbers` is how many single-precision values the region holds, given the
counts the header carries.

## Why it is a routine and not a table of constants

The sizes depend on the model, and the model is not known until the machine reads its own header. A layout compiled in would mean an image that carries one model, and the whole shape of this project is that the model is the operator's choice at build time.

## What goes wrong when this is wrong

and it is the reason this belongs in the seed rather than being left to the machine: two regions that overlap do not fault. The attention writes over the cache, the cache reads back what attention left, and the machine thinks something that is not wrong so much as unrelated. Nothing is reported, because nothing failed.

## So it refuses rather than trims

A machine given less room than the model needs is told the number it was short by, and stops. The alternative -- quietly using a shorter context, or overlapping two things that are rarely both live -- is how a machine ends up subtly wrong in a way that only appears under load.

## Every region starts on a sixteen-byte boundary

Not for speed: the vector loads in the fast arithmetic read sixteen bytes at a time, and on some processors an unaligned one of those faults rather than being slow. That is a difference between machines this project has already written down (`notes/023`) and it is cheaper to satisfy everywhere than to remember where it matters.

## Where it sits

**Belongs to** `107`.

**Checked by** `134-test-lay-out`, `136-test-fill-the-plan`, `140-test-the-driver`.

