# 102 — Find the weights without a filesystem

## Current behavior

**The finding half works, on x86-64.** A payload booted by real UEFI firmware
locates a packed model riding inside its own image and reads its header aloud:
magic, version, layers, hidden size, heads, vocabulary, context, tensor count,
token count and total size — every one matching what the host-side reader says
about the same blob.

The model **travels inside the program that will run it** rather than beside
it. The wrapper (`src/029 --append`) places it a fixed distance past the code
in the same section, so firmware maps it in without being told anything
unusual, and the payload finds it by working out where it is standing and
counting forward. No directory, no filename, nothing to ask — which is the
point, since there is nothing to ask.

Field offsets are computed from the layout description (`src/024`) rather than
counted, after counting them by hand produced a model with a hundred and
seventy-six word vocabulary and a size of zero.

Still to do:

- The memory map. Nothing yet reads what firmware leaves behind, so nothing
  marks the engine and the weights as occupied, and nothing reports what is
  free.
- The ratchet. All three rungs are still undecided in practice because nothing
  yet needs the memory.
- The other two architectures. The routine must be written again in their own
  instructions, and the RISC-V one without a single symbol reference.

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
