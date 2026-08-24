# Phase 2 Progress — Things That Walk and Fight

**The goal:** the soldier. One record, one brain, one combat system, used by
everything that ever moves. With the heroes subtracted out there is no second
system to distract from a bad one, so this is the phase the game lives or dies by.

**Ends with:** two waves meeting in the middle of a lane and grinding to the
stalemate the vision describes. **Seeing the stalemate is the point** — it is the
problem statement, rendered, and phase 4's demo is the answer to it.

| Issue | | Status |
| --- | --- | --- |
| 201 | A soldier is one record | not started |
| 202 | Walking an edge of the graph | not started |
| 203 | The brain is five states | not started |
| 204 | Choosing what to attack | not started |
| 205 | Damage is buffered, then applied | not started |
| 206 | The frontline is a queue | not started |
| 207 | Waves spawn on a cadence | not started |
| 208 | A wave knows when it is gone | not started |
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
