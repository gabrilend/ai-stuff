# 401 — The second and third tongues

## Current behavior

**In progress. Three of nine kernels written for the second tongue; the
harness that would prove them is built and does not yet report.**

**Written** (`src/099`): the matrix product plain, the matrix product four at
a time, and the normalisation — the three built only from multiplication,
addition and square root, which are the ones that CAN be required to match
exactly rather than closely. They assemble for the second architecture.

The wide one deliberately does not use the instruction that sums a whole
vector in one step, for the same reason the first tongue's does not: that
answer differs in the last bit, which makes it a different specification
rather than a better implementation of this one.

**Not written**: `exp_one`, `softmax`, `swiglu`, `rotate`,
`attention_scores`, `attention_mix`, `add_into` — named in `src/099` rather
than omitted, because a port that quietly covers less than the first looks
finished. The third tongue is not begun.

**The harness is the interesting half, and it is right in shape.** The host
cannot test these by calling them — it does not speak this language — so
`src/100` records what the FIRST tongue produces for a set of shapes, bakes
those exact bit patterns into a payload along with the second tongue's
kernels (`src/101`), boots a real ARM machine, and has it compare its own
results against them **as integers**, so nothing rounds and "close" cannot
happen. That is the right test and it is what the fixture in `103` was built
for.

**Where it stands:** the payload assembles, boots, and prints its greeting
through firmware. It then stops before its first progress mark, and the
report never arrives. Two defects were found and fixed on the way there, both
worth keeping:

- **The first instruction must be ours.** Firmware enters at offset zero, so
  emitting the kernels first meant the machine entered `matrix_vector_plain`
  with the firmware's registers as arguments — which happened to mean "no
  rows", so it returned immediately and the firmware carried on booting to
  its own shell. Nothing failed and nothing was reported.
- **There is nowhere writable inside the payload.** Firmware that honours
  section rights maps the code read-only, so a results buffer in `.text` is a
  crash on some machines and not others. It lives on the stack now, which is
  the same lesson `033` learned for its memory map.

The remaining failure is between the greeting and the first mark. The
generated assembly around that point reads correctly, which means the next
step is the debugger rather than the listing — `021` already attaches one,
and `703` now turns an address into a place. That is the tool this needs and
it did not exist when this ticket was written.

## Intended behavior

The engine written for each assembly language in modern use — three covers the
majority of machines — all three carried on the same chip.

## Suggested implementation steps

1. Port the arithmetic first, since it is nearly all of the work and all of the
   speed. The reference comparison built in `103` is what makes this tractable:
   each port is correct when it agrees with the same fixture the first one agreed
   with.
2. Be honest about which half is a translation and which is a rewrite. The plain
   version of the arithmetic ports almost mechanically. The fast version does not:
   the vector instruction sets on the three architectures have nothing in common,
   the register counts differ, and the extension that provides them is not even
   guaranteed to exist on RISC-V. Budget the fast half as three separate pieces of
   work rather than one done thrice.
3. Port the hands next, and expect one of them to change shape rather than
   detail. **x86 has a separate address space for talking to devices, reached by
   its own instructions; the other two do not** — everything there is
   memory-mapped. So the hand that touches ports exists in one form on one
   architecture and collapses into memory access on the others. The catalogue of
   hands is therefore not identical across machines, which is survivable because
   the machine reads its catalogue rather than being told it — but it means the
   instruction (`301`) must not assume any particular hand exists.
3. Keep the three implementations recognisably the same program. Where they must
   differ, say why in a comment beside the difference — a future reader needs to
   know whether a divergence is a necessity or an accident.
4. Do not attempt to share code between them by inventing an abstraction layer.
   There is no compiler here; a layer would have to be written three times as
   well, and would then be three things instead of one.
5. Measure each with `106` and keep the results side by side. The architectures
   will not perform alike and the difference decides which boards are viable.
6. Decide what happens for a processor outside the three. Bundling an engine for
   it before flashing, or working it out on arrival, are both acceptable; a
   machine that cannot think until somebody helps it is the one case where the
   seed is not self-sufficient, and it should be named rather than discovered.

## Blocks

`501`, and phase 6 on any board that is not the first target.

## Blocked by

All of phase 1, and phase 2 for the hands.

## Related documents

`docs/010-datapath-the-mind.md` — writing the same program three times as the
price of not having a compiler.
