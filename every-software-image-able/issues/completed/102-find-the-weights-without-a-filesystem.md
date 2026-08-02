# 102 — Find the weights without a filesystem

## Current behavior

**Done, on all three architectures, and held to the host's arithmetic by a
test.** A payload booted by real UEFI firmware locates a packed model riding
inside its own image, reads its header aloud, reads the memory map the
firmware leaves behind, verifies its own body sits outside every usable
range, and computes — before touching anything — which memory strategy the
machine can afford. `src/033` emits it for all three architectures, `src/019`
builds it, and `src/055` boots all three boards and compares every spoken
number against the host: 27 of 27 on 2026-08-02.

The model **travels inside the program that will run it** rather than beside
it. The wrapper (`src/029 --append`) places it a fixed distance past the code
in the same section, so firmware maps it in without being told anything
unusual, and the payload finds it by working out where it is standing and
counting forward. No directory, no filename, nothing to ask — which is the
point, since there is nothing to ask.

Field offsets are computed from the layout description (`src/024`) rather than
counted, after counting them by hand produced a model with a hundred and
seventy-six word vocabulary and a size of zero.

**The memory map.** The firmware is asked for its map into a buffer on the
stack — the image's own pages can be mapped read-only, which one board's
firmware really does. Conventional ranges are summed as free; the engine and
the weights are verified to sit outside every usable range rather than
assumed to, because the seam where the loader's allocation and the map
disagree is exactly where a machine would fail with the least information.
The report prints total, engine, weights and free, and the first thing the
machine can say about itself is what room it has.

**The ratchet.** Cache and working costs are computed from the header's own
numbers — the same two formulas as `src/045`, re-implemented in each
architecture's instructions — and the ladder is walked fastest-first:
everything in memory, the hot quarter resident, everything read in place, or
a refusal that says which number was too large. The weights term is the whole
blob, because the blob is the unit copied or read in place; `045.strategy`
takes the same number through `weights_bytes` so the builder and the engine
answer the same question, and `055` requires their answers to match on every
board. Nothing is copied or read in place yet — the ratchet is computed and
spoken, not acted on, and acting on it belongs to the engine that needs the
memory (`103`, `105`).

**The third tongue needed a tool.** The RISC-V assembler leaves every branch
— even to `. + 12` — as a relocation for a linker this project deliberately
does not have, so `src/054` lays payloads out and encodes every branch as a
raw instruction word with the distance already inside it. The engine port
(`401`) inherits that tool.

## Intended behavior

The engine, running with nothing beneath it, finds the packed weights and knows
how much usable memory exists to work in — before any allocator exists, because
the allocator is something the grown machine writes later (`docs/003`).

## Suggested implementation steps

1. Decide where the blob sits in the image and how the engine finds it. The two
   candidates: a fixed offset agreed between the image builder and the engine, or
   a small table at a fixed offset that points at everything. The second costs one
   indirection and survives the layout changing; the first costs nothing and
   breaks silently when anything moves.
2. Read the memory map the firmware leaves behind. On the first target this is a
   list of address ranges each marked usable, reserved, firmware-owned or broken.
   Only the usable ranges may be touched.
3. Mark the ranges holding the engine and the weights as occupied, so that
   nothing later hands them out. This is the same rule the grown machine's
   allocator inherits — protect your own author before serving anyone else — and
   it is stated in `docs/003` step one for that reason.
4. **Ratchet down until it fits.** Do not choose between copying the weights into
   memory and reading them in place — compute, before committing to any of them,
   which of the options the machine can actually afford, and take the fastest one
   that fits:

   ```
   everything in memory                fastest; costs the weights twice
      → not enough room?
   the hot parts in memory, the rest read in place
      → still not enough room?
   everything read in place            slowest; costs nothing
      → still not enough room?
   say so, and stop
   ```

   The calculation happens first, from the memory report below and the sizes in
   the header, so the machine never starts a copy it cannot finish. The last rung
   is a refusal rather than a fallback: a machine that cannot hold its own weights
   should say which number was too large rather than run unusably and let somebody
   guess.
5. Produce a memory report: total usable, occupied by engine, occupied by
   weights, free for working memory. It is the first thing the machine can say
   about itself and it should be printable before anything else works.

## Blocks

`103`, `104`, `105`.

## Blocked by

`101` — the layout has to exist before it can be found.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the memory map, and the rule about
protecting the model's own weights.
