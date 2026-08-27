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
| 601 | The phase table | built |
| 602 | The surge turns waves into a stream | built |
| 603 | The chest, dealt across the three | built |
| 605 | Boons, and the calm they are chosen in | built, offers not curated |
| 606 | What walks out of the middle | built |
| 607 | Every lane spawns into the center | built |
| 608 | The deadline is the walk | built |

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
  **one per player from two offered**, in **the calm** — a phase where nothing
  spawns and every soldier walks home. It happens **twice**, never after the
  Golem: two per player, six per three-player team. A boon reaches every body the
  team fields, heroes included.
- **The surge takes nothing.** It reads everything a team owns, wherever it sits,
  and deals it across the bodies spawning each instant. Placements are never
  disturbed and players may rearrange freely throughout — what they are arranging
  is the challenge that follows, not the surge.
- **Towers fire at bare catalogue values during a surge**, and so do the guards
  already standing, since guards read through their tower.
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

## Where the prototype got to

**The phase's ending is reproduced, and it is the one that matters most: a match
now finishes.** Left entirely alone, from one seed, a match runs three surges and
three challenges and terminates at about thirteen minutes because the Golem arrived.
Asserted as a test, along with the arc it got there through — a bare "did it stop"
check would pass on a lucky push and prove nothing.

The surge is a stream on one shared timer, so bodies come in threes and the whole
holding is dealt across them from a random start. **Nothing is taken to do it**, and
a test asserts that too: the slots hold exactly what they held. The chest cannot grow
for the duration, and that falls out rather than being enforced — a stream body
belongs to no wave, "wiped" is a statement about a group, and towers are unkillable.

The challenge funnels every lane's production into the middle while a funnelled body
keeps its **own** lane's upgrades, so investing in the top lane still means something
during one. Push depth is ignored outright. The monsters are a third team, hostile to
everything including each other, assigned to the team whose base they walk at — and
the boon goes to that team whoever landed the blow.

The calm empties the map, refunds the heroes that survived, and offers each player
two boons.

**There is no fallback here any more, and there is none anywhere else either.** A
boon still unchosen when the calm ends **stays on offer**, indefinitely. Nothing is
taken for anybody.

The alternative that looked best was worse in an instructive way: taking it but
allowing a later swap makes *never choosing* the correct play — let the timer run
out, watch how the match develops, then swap into whatever turned out to matter. A
rule that rewards not answering teaches an awkward, bent way of playing. Letting it
lapse punishes a team for one player looking away.

Being slow costs you the use of the boon in the meantime and costs your team
nothing. You are only ever hurting yourself.

**605 is thin.** Boons are drawn at random from a flat list of six. The design wants
offers that are worth choosing between, which is a curation problem rather than a
mechanism one.

**The monsters needed tripling.** At their first numbers they died in thirteen seconds
— an interruption rather than a challenge. The figure to tune against is not health
but the walk: the midpoint of the centre lane is forty seconds from a library, so a
monster that dies at thirty has got three quarters of the way. See balance-updates.
