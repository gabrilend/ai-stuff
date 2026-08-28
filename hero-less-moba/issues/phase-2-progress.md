# Phase 2 Progress — Things That Walk and Fight

**The goal:** the soldier. One record, one brain, one combat system, used by
everything that ever moves. With the heroes subtracted out there is no second
system to distract from a bad one, so this is the phase the game lives or dies by.

**Ends with:** two waves meeting in the middle of a lane and grinding to the
stalemate the vision describes. **Seeing the stalemate is the point** — it is the
problem statement, rendered, and phase 4's demo is the answer to it.

| Issue | | Status |
| --- | --- | --- |
| 201 | A soldier is one record | built |
| 202 | Walking an edge of the graph | built |
| 203 | The brain is five states | built |
| 204 | Choosing what to attack | built |
| 205 | Damage is buffered, then applied | built |
| 206 | The frontline is a queue | ranks built, lane width not — G3 |
| 207 | Waves spawn on a cadence | built |
| 208 | A wave knows when it is gone | built |
| 209 | The thread pool slices the tick | not started — H3 |
| 210 | A death decays before it is final | built |

**Blocking:** nothing.

**Carry into the work:**

- **Doubles are fine** — no fixed-point rewrite. Durations stay integer ticks.
- **A kill pays every player on the killing team**, so `last_hit_by` walks back
  to a team rather than to an owner.
- **The front rank is N abreast, not single file**, and the centre lane is wider
  than the sides. That is the only real difference between the three lanes and it
  makes the middle where a body-count advantage converts fastest.

**Demo:** not yet built.

## Where the prototype got to

The soldier is one record, one movement routine, one targeting routine, one attack
routine, and the brain is a dispatch table with a row per state. Waves spawn on a
cadence as a column — captain first, then melee, then ranged — and a wave notices
when it has been wiped without anything scanning every wave every tick.

**The phase's ending is reproduced.** Two waves meet in the middle of a lane and
grind to the stalemate the vision describes, and a headless match with nobody
placing anything runs twenty-two minutes without either side taking a base. Seeing
the stalemate was the point: it is the problem statement, rendered.

**206 is the gap.** Melee bodies form ranks and ranged bodies hold behind them at
their own reach, which is the half of the issue that reads correctly on screen. The
other half — how many bodies a lane's *width* lets stand abreast — is not built at
all, so the centre lane is wider only in the drawing. See G3, which also blocks B1.

**209 is not started, and the plan it was written with does not work.** The tick
runs on one thread. Nothing in the design is in the way of *slicing* it, and it has
not been needed at prototype body counts — a match runs at many times real time, and
the census in the headless report says the field holds hundreds of bodies, not
thousands.

But the mechanism the issue names is coroutines, and coroutines in Lua all run on
one core: they hand control to each other and never hold it at the same time. Over a
tick that is arithmetic from end to end and never waits for anything, that is a more
complicated way to take exactly as long. **Settled for now: the prototype is
single-threaded, and the coroutine pool is the shape of the idea rather than a
working parallelism.** When it needs to scale, the parts that matter move to a C
core. See H3.

**210 is built, and it changes what death is.** A body at zero health leaves the
field immediately and then **decays for two seconds**, holding its slot and every one
of its numbers, before anything about the death is made final. Nobody is paid, no
wave counter moves, no guard is replaced and no challenge ends until the decay runs
out.

The reason is a hole the replay log found: a body that died on one machine and did
not die on another can never be corrected, because the slot has been recycled and
there is nothing left to write onto. Deaths are the hinge everything hangs from —
health makes deaths, deaths make wipes, wipes make draws, draws make the chest — so
one soldier's difference puts a machine permanently out of step. Two seconds is two
reconciliation cycles, which is long enough for every machine to have had its say.

The cost is real and worth naming: **every consequence of a death lands two seconds
late**, uniformly, so it is a delay rather than a distortion. Paying immediately and
undoing it later was the alternative and it does not survive contact — a payment can
be unmade only if it has not been spent, and a chest draw that has already been
placed cannot be unmade at all.

The implementation is one number and one gate. `alive` is what everything in the
simulation already tests, so setting it to zero the instant a body falls is what
makes a decaying body stop fighting, stop being a target, stop holding a place in
the queue and stop counting toward push depth — with no change to any of those
passes. Which is the whole argument for having one flag everything agrees on.

It also happens to be the better thing to look at: a body that fades rather than
blinking out is the least artificial version of the moment, and the data behind the
fade is real rather than invented by the renderer.
