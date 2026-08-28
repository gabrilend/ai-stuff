# 509 — Five Heroes for the First Commander

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 501, 503, 504 |
| Blocks | 803, 805 |
| Reads | [hero units](../docs/012-hero-units.md), [commanders and personal resource](../docs/011-commanders-and-personal-resource.md) |
| Open questions | none |

## Current behavior

Eleven heroes across two rosters of five, covering distinct jobs rather than three
grades of the same soldier: one that holds a line, one that kills a line, one that
kills stone, and healers.

## Intended behavior

One commander, fully realised, with **five** heroes. The vision says at least
three and ideally five; building the first one at five means the roster
machinery is exercised at its intended size rather than at its minimum.

The design rule for a roster: **cover distinct jobs, not three grades of the same
soldier.** A commander whose roster is small, medium, and large gives its player
one decision — how much to spend. A commander with distinct jobs gives them two:
how much, and for what. The second is a much better decision and it is the one
that makes a commander feel like a character rather than a price list.

The jobs the first roster should cover:

| Job | What it is for |
| --- | --- |
| **Holds a frontline** | High health, low damage, large personal space. Buys time in a lane that is losing. |
| **Kills a frontline** | Area damage. Turns a stacked enemy queue into a wipe, which is also an upgrade draw. |
| **Kills stone** | Extra damage to structures, poor against soldiers. The tool for actually taking a tower. |
| **Kills a hero** | High single-target damage. The answer to somebody else's purchase. |
| **Cheap and disposable** | Low price, low weight. What you buy when banking is not an option. |

Note that the second job feeds the upgrade economy directly: wiping a wave is how
a team draws, so a hero that turns a stalled queue into a wipe is buying upgrades
with personal resource — indirectly, through play, which is the only exchange
rate between the two economies that this design allows.

The fifth exists because income is now identical across a team — every kill the
team lands pays all three players equally — so no player is ever poorer than
their teammates, but a **losing team** is poorer than a winning one. The cheap
hero is what a team that is behind can still afford, and its price should be set
against what a losing team's income actually looks like rather than against a
solo player's.

## Suggested implementation steps

1. Write five hero archetypes into the unit catalogue with prices and abilities
   built from the two dispatch tables in issue 504.
2. Run the balance validator's combat-weight check on each; every one should land
   in the intended band despite the very different stat distributions.
3. Write the commander's resource name and its five-row roster.
4. Write a demo scenario per hero: the situation each is the right answer to,
   runnable headless, showing the outcome with and without it. These become part
   of the phase-5 demo.
5. Record the initial prices as the first real entry in the balance ledger, with
   a note on where they came from.

## Related documents and tools

- [Hero units](../docs/012-hero-units.md)
- [Commanders and personal resource](../docs/011-commanders-and-personal-resource.md)
- `docs/balance-updates.md`

## Still open

How many commanders in total, and may two teammates pick the same one? Building
the first roster around five distinct jobs suggests that a second commander
should reshuffle the jobs rather than reskin them — but that is a much larger
design job than it looks, and doing it badly gives every commander the same five
heroes with different names.
