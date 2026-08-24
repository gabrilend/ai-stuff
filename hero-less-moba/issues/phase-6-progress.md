# Phase 6 Progress — The Surge and the Challenge

**The goal:** everything that is not normal gameplay, and the thing that ends the
match.

A match has **five phases**, and the differences between them are the shape of
the whole game:

| | Normal | Siege-surge | Challenge | The calm | Over |
| --- | --- | --- | --- | --- | --- |
| Spawn | waves, long interval | **a stream, one per lane, one shared timer** | waves, normal interval | **nothing; everyone walks home** | nothing |
| Target | own lane | own lane | **the centre, all three** | — | — |
| Upgrades | placed | **the whole chest dealt across the three** | placed, by spawning lane | re-placed freely | frozen |
| Towers | shoot, can fall, spawn guards | **shoot, cannot fall, spawn nothing** | as normal | as normal | — |
| Chest grows on | wipes, tower kills | **nothing** | wipes, tower kills, the monster | — | — |

| Issue | | Status |
| --- | --- | --- |
| 601 | The phase table | not started |
| 602 | The surge turns waves into a stream | not started |
| 603 | The chest, dealt across the three | not started |
| 605 | Boons, and the calm they are chosen in | not started |
| 606 | What walks out of the middle | not started |
| 607 | Every lane spawns into the center | not started |
| 608 | The deadline is the walk | not started |

*(604 was the no-repeat-lane rule. It was cut as arbitrary and the file removed;
see the roadmap's list of what is deliberately absent.)*

**Blocking:** nothing.

**Carry into the work:**

- **A surge does not take your upgrades. It deals them.** All three lanes spawn
  on one shared timer, and the whole chest is split across the three new bodies
  each time, starting at a random lane so the short share rotates. Nothing is
  lost — **it makes a team incoherent**, and it flattens the lanes perfectly.
- **Nothing at all is earned during a surge.** Towers are invulnerable, so no
  tower reward; no discrete waves, so no wipes.
- **Guard production moves to the base** during a surge and joins the stream.
- **A boon is payment for slaying a monster, not for surviving a surge**, chosen
  one per player from three, in **the calm** — a phase where nothing spawns and
  every soldier walks home. It happens **twice**, never after the Golem.
- **The calm resets the frontlines to nothing**, so a match has three fresh
  starts: territory resets, stone and chest do not. Push depths need a **full
  recompute** at its end.
- **Three fixed named challenges**: the Pillar Orc, the Field Dragon, the
  **Eternal Golem** — two of each, one per team. The Golem cannot be killed;
  damage removes speed and it recovers rapidly. It advances until a library
  falls, and **that is what bounds a match.** It pays nothing.
- **Challenges use waves, not the stream.** The lull is what lets a monster
  lurch.

**Still open:** A8c (one team's monster dying long before the other's), B2, B8,
B9 (numbers).

**Demo:** not yet built.
