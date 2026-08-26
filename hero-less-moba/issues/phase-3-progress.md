# Phase 3 Progress — Things That Stand and Hold

**The goal:** stone. Towers that shoot and commit, guards that make the ground
around a tower dangerous, a base that is one open room, and a library whose fall
ends the match. After this phase a game can be won.

**Ends with:** a match that plays itself to completion — one side wins on a
seeded coin-flip's worth of asymmetry, and the report says which lane did it.

| Issue | | Status |
| --- | --- | --- |
| 301 | A structure is a record with health | built |
| 302 | A tower picks a target and keeps it | built |
| 303 | Towers put guards on the ground | built |
| 304 | Guards are leashed | built |
| 305 | The base is one open room | geometry built, shared patrol not |
| 306 | Felling a tower pays three | built |
| 307 | The library ends the game | built |

**Blocking:** nothing, though **A4 is not really decided.** The vision's sentence
puts "will move to attack" and "the range on their arrows" in one clause; issue
305 implements both readings — unleashed base guards, and base towers whose plain
radius reaches one lane mouth. Defensible, and not a decision.

**Carry into the work:**

- **A guard is stamped with its tower's stone upgrades**, so slotting into stone
  buys bodies as well as arrows. What stops that dominating is leashing — a stone
  upgrade buys a better wall, never a step forward. If leashing is ever loosened,
  that is the rule that breaks first.
- **Stone upgrades survive the stone.** `tower_mask` is never cleared by a tower
  dying; there is no code path from tower-felled into the mask rebuild.

**Demo:** not yet built.

## Where the prototype got to

Towers stand, shoot the nearest body in range and keep that target while it lives;
guards patrol on a leash and refuse to acquire while walking home; felling a tower
kills its guards and pays three separate draws; and a library at zero health ends
the match on that tick, with both libraries falling in one buffered pass recorded
as a draw rather than resolved by team number.

**The command radius and its inversion are in.** A tower replaces guards only while
no enemy stands inside the circle, the timer is held rather than reset while the
ground is contested, and the circle is drawn for both teams.

**305 is the gap.** The base's geometry is built — three base towers at the lane
mouths, a library behind them, and the base towers inherit every lane's stone. But
its guards are leashed to their own tower like any other guard, so a base is three
short corridors rather than **one open room**, and guards do not cross it to answer
an invasion from another lane. That is the issue's actual subject and it is not
built.
