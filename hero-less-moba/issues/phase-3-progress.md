# Phase 3 Progress — Things That Stand and Hold

**The goal:** stone. Towers that shoot and commit, guards that make the ground
around a tower dangerous, a base that is one open room, and a library whose fall
ends the match. After this phase a game can be won.

**Ends with:** a match that plays itself to completion — one side wins on a
seeded coin-flip's worth of asymmetry, and the report says which lane did it.

| Issue | | Status |
| --- | --- | --- |
| 301 | A structure is a record with health | not started |
| 302 | A tower picks a target and keeps it | not started |
| 303 | Towers put guards on the ground | not started |
| 304 | Guards are leashed | not started |
| 305 | The base is one open room | not started |
| 306 | Felling a tower pays three | not started |
| 307 | The library ends the game | not started |

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
