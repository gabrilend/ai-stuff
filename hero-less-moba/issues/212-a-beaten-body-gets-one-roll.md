# 212 — A Beaten Body Gets One Roll

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 211d, 210 |
| Blocks | — |
| Reads | [combat and damage](../docs/006-combat-and-damage.md), [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

A body fights until its health reaches zero and then it dies. It never withdraws,
never breaks, and never chooses anything. Losing a fight and dying in a fight are
the same event.

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

## Related documents and tools

- [Combat and damage](../docs/006-combat-and-damage.md)
- [Damage is buffered, then applied](205-damage-is-buffered-then-applied.md), which
  is what lets a dying body still land a blow
- [A death decays before it is final](210-a-death-decays-before-it-is-final.md) — a
  body that runs is a body that did not die, and the two mechanics meet here
- [211d](211d-marching-speed-is-not-running-speed.md), the only thing running is for
