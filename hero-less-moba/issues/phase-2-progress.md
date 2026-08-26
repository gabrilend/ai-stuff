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
| 209 | The thread pool slices the tick | not started |

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

**209 is not started.** The tick runs on one thread. Nothing in the design is in the
way of slicing it; it simply has not been needed at prototype body counts, where a
match runs at roughly eighty times real time.
