# 053-commander-table

Commanders, the colours their bodies pay in, and the heroes they may buy.

## What it is for

**A commander is not a body on the map.** No avatar, no health bar, nothing to
kill. It is four things: a **captain**, a **proportion**, a **bounty**, and a
**roster**.

Melee and ranged bodies are identical for every commander in the game — a knight
and a barbarian are the same body with different art. So adding a commander is
choosing proportions, colours and a signature, not balancing three new stat blocks.

## Exports

| Name | Meaning |
| --- | --- |
| `colour` | The resource kinds, each with a hue **and a shape**. |
| `ceiling` | The die ladder: how much of one colour a wallet may hold, by rung. |
| `rung_interval` | Ticks between rungs. |
| `commander` | The commanders: captain, melee share, bounty ratio, roster. |
| `hero_cost` | What each hero costs, as a **vector of colours**. |
| `ability` | Every ability, as a (condition, effect, cooldown) triple. |

## Never encode meaning in hue alone

Each colour has its own **display shape** as well as its own hue — pips, a bar, a
script stroke, a card, a block, a ring. Written down as an accessibility
requirement and worth reading as a design principle. Somebody who cannot tell red
from green can still tell pips from a card.

## The ladder, and what it limits

A wallet's ceiling climbs d4 → d6 → d8 → d10 → d12 and stops. **Income arriving at
a full colour is lost** — not stored, not carried, not converted.

That is the limiter on the hero economy, and it deliberately limits **hoarding**
rather than how many heroes may be alive. There is no cap on heroes at all.

The ladder climbs on the match clock rather than on anything a player does, so both
sides climb together and nobody can out-bank anybody.

## A pair of commanders defines an economy

`bounty` is which colours a commander's bodies carry. **You farm what the enemy
fields**, so their commander selection decides what you can afford — a loop this
design did not previously have, and the reason a hero's cost is a vector rather
than a price.

Which creates a trap the catalogue now warns about in place. The first draft had
both commanders paying might and neither paying wit, which made two of the five
heroes on one of their own rosters **impossible** to buy in any match — not rare,
not expensive: never, with no refusal to read, because nobody could get far enough
to be refused. [The invariants](../tests/051-the-invariants.info.md) now assert that
the colours in circulation can pay for the rosters on offer.

## Abilities are pairings, not code

An ability is a triple assembled from a condition table and an effect table, so a
new hero is usually a new pairing. That matters because a hero has **no manual
control at all**, so its entire personality is the predicate that decides when its
ability fires — and two heroes with identical stats and different conditions are two
genuinely different purchases.
