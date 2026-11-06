# 212 — A Beaten Body Gets One Roll

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 211d, 210 |
| Blocks | — |
| Reads | [combat and damage](../docs/006-combat-and-damage.md), [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none — the one it had is settled below |

## Current behavior

**Built.** A body brought to zero health or below is **beaten**, and rolls its own
`will` die once on its team's `will` stream. Five or more passes: it stays, lands one
blow on what it was fighting, and dies. Less fails: it keeps one point of health and
runs home at running pace, mends, and comes back with its roll spent. Guards and
monsters have no will to roll and simply die; nothing rolls twice.

*It used to be:* a body fought until its health reached zero and then it died. Losing
a fight and dying in a fight were the same event.

### What is built

- **The definition of beaten is H15's third answer**: health at zero or below. Terror
  joins the same test when the surge's morale attacks exist; there is no terror field
  until then. See the Settled section.
- **`will` on every archetype row**, copied to the body at birth: d6 ranged, d8 melee,
  d10 captains, d12 heroes, **0** for guards and monsters. `will_target` is 5. A body's
  `rolled` flag is set for the rest of its life the moment it rolls.
- **A `will` stream per team**, in the stream table, so one side's luck never depends
  on how many of the other side's bodies were beaten.
- **Passing** queues one last blow. The resolve pass lands every last blow after every
  ordinary blow of the tick, in the same pass, so a body beaten this tick still strikes
  what beat it. The blow is guaranteed — no cooldown, no reach, no line — on its target,
  else the stone it was hitting, else the nearest enemy within its reach. A last blow
  that beats somebody makes them roll in turn; it cannot run away, because nobody rolls
  twice. Raises a `stood` event.
- **Failing** leaves one point of health, clears its targets, sets `routed`, and puts
  the body into the recovering state. A routed body moves back down its lane at
  **running pace** — the `run` gait, read in exactly one place — and goes back in only
  once it has mended to nine tenths, not because the line needs it: it has broken.
  Raises a `routed` event. It is already out of its wave's formation budget, which only
  counts marching bodies.
- **The Golem takes no last blow**, because it takes no damage of any kind.

### What it did to a match

On the pinned seed, 630 bodies stood and 671 routed, against 1,758 deaths, in a match
that now ends at tick 12,736 rather than 14,484. **The first two monsters now die and
the third does not**, and the match runs the full arc of three surges and three
challenges: the two
invariants that had been failing on that arc pass, and so does the unchosen-boon check
that needed a calm to exist. That is this issue's own claim — big things die by the last
blows of what they beat — arriving in a whole match, and it bears on
[H19](../docs/020-open-questions.md).

## Intended behavior

*Settled; see [open questions](../docs/020-open-questions.md), H8. Recorded in the
terms it was given, because the sense of it is in the inversion:*

> Units run away when they are beaten and cannot continue — a will save, once,
> determines if they sacrifice themselves. A fail means they live to fight again. A
> success means they get one single hit on the enemy — through these means, any foe
> (save the eternal golem)'s demise may be achieved.

**A beaten body rolls once.** Not every tick, not each time it is hit. Once, at the
moment it is beaten, and the outcome stands.

| Outcome | What happens |
| --- | --- |
| **Fail** | It runs. At **running speed** — the only time anything in this game runs. It lives to fight again. |
| **Pass** | It stays, lands **one single hit**, and dies. |

### Note which way round it is

**Passing the save is what makes a body stay and die. Failing it is what lets it
live.**

That is not a slip and it should not be quietly corrected by anybody reading this
later. The save is not against fear. It is against self-preservation, and the thing
being resisted is the sensible choice. A body that holds itself together enough to
resist running is a body that spends itself.

### This is how big things die

A challenge monster is not brought down by a frontline out-damaging it. It is
brought down by **the accumulated last blows of everything it beat** — every body
that passed its save and spent itself on one strike.

Which means the third monster's deathlessness is a statement about scale rather than
about a number. The Eternal Golem is the one thing that cannot be killed this way,
and there is no other way.

It also means a wave that is losing is not wasted. A wave that breaks and dies
against a monster has still paid into its death, which is a different feeling from
watching a wave evaporate — and it is the mechanical reason a team that keeps
feeding a challenge eventually wins it.

### What "beaten and cannot continue" means

The condition needs a definition and it is the one thing here that is not yet
written. Candidates, and the shape of the answer matters more than the threshold:

- **health below a fraction of its maximum** — simple, and makes the roll happen
  at a predictable moment
- **health below what its current attacker deals in one swing** — "cannot continue"
  read literally: it is about to die whatever happens
- **its wave has lost the engagement** — a statement about the line rather than the
  body, which makes breaking a thing a formation does rather than a thing a soldier
  does

The second is the most faithful to the words. The third is the most interesting and
the most work.

### The roll itself

From a **named seeded stream**, per team, like everything else random here. A save
is a die roll against a number, and the commanders already deal in dice — the ladder
runs d4 through d12 — so the natural shape is a body's own die against a fixed
target rather than a bare probability.

## Suggested implementation steps

1. Define "beaten" and write the definition into the body's own state, so the
   condition is read once and stored rather than recomputed by everything that asks.
2. Add a `will` field to the archetype rows, and a per-body flag recording that the
   roll has happened, so it cannot happen twice.
3. Add the named stream. Document it in the tick's stream table.
4. On failing: set the body running — this is the only caller of running speed from
   [211d](211d-marching-speed-is-not-running-speed.md) — and give it a destination
   behind its own lines. Take it out of its wave's formation budget; it has left.
5. On passing: guarantee the single hit. It has to land even though the body is about
   to die, which means it goes through the **pending damage buffer** like everything
   else, and the body's own death is resolved in the same pass. The buffered design
   from issue 205 is what makes that expressible at all.
6. Test the thing this exists for: a monster that beats an entire wave should take
   the wave's worth of last blows, and enough waves should kill it. And the Golem,
   given the same, should not.

## Settled

**H15 — what "beaten" means.** The third of H15's three ways, and the one both H15 and
602's S1 argued for: below zero is beaten, and beaten is this roll. Zero itself counts,
as it always counted for dying.

**What a fail leaves.** One point of health. Enough to be a living body that a second
blow kills outright — it has spent its roll — and the least that is not a death.

**Where a routed body goes, and when it comes back.** Back down its own lane, the way a
wounded body already falls back, but running; and back in once mended to nine tenths,
whatever the line needs. A body that broke does not rejoin because it is wanted.

**Who rolls.** Wave bodies and heroes. A guard stands at its tower for its whole life
and has nowhere behind its lines to run to; a monster is what the last blows are for.

**The dice.** d6 ranged, d8 melee, d10 captains, d12 heroes against a target of 5 —
one in three, one in two, three in five, two in three. The shape follows the commanders'
ladder (d4 to d12); the numbers are a first guess for the balance ledger.

**Running pace is a gait, not a second speed field.** 211d asked for a second number on
each row; the pace table that arrived since (216c) made every gait a multiplier on a
body's own speed, so that nothing is ever handed speed. `run` is that table's fourth
gait, 1.6.

**Does a routed body still count?** It does, as every recovering body already does: it
holds its wave open and stands in the field. Whether it should is
[H17](../docs/020-open-questions.md), still open, and this issue does not answer it.

## Related documents and tools

- [Combat and damage](../docs/006-combat-and-damage.md)
- [Damage is buffered, then applied](205-damage-is-buffered-then-applied.md), which
  is what lets a dying body still land a blow
- [A death decays before it is final](210-a-death-decays-before-it-is-final.md) — a
  body that runs is a body that did not die, and the two mechanics meet here
- [211d](211d-marching-speed-is-not-running-speed.md), the only thing running is for
