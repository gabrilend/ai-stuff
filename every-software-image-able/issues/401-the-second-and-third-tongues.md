# 401 — The second and third tongues

## Current behavior

The engine runs on one architecture. Most computers are not that architecture.

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
