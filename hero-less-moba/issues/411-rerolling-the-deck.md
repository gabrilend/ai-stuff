# 411 — Rerolling the Deck

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 106, 402, 403, 502 |
| Blocks | 703, 803 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

A reroll trades a stone for the next card off the deck, priced in two colours. It
does not add an upgrade, which is why it is the only thing personal resource can do to
the chest and why resource can never buy one outright.

## Intended behavior

**A player spends personal resource to send one of their team's upgrades to the
bottom of the deck and immediately draw the next card.** A new verb,
`reroll_upgrade`, taking an instance id.

1. Check affordability and that the instance is not locked by another player.
   Refuse loudly with a reason if either fails.
2. Deduct the cost.
3. Append the instance's **kind** to that team's own tail of the deck.
4. Destroy the instance.
5. Read the kind at the team's `deck_index`, append a new instance unplaced,
   advance the index by one.
6. Raise `upgrade_rerolled { team, player, kind_out, kind_in }`.

**The other team's deck is untouched.** Both read the same base sequence at their
own index, so the two agree until somebody pays to break them — and the
divergence afterwards is exactly the record of who paid what.

**You pay into the dark.** The next card is not shown. A reroll is a gamble, and
it is the one place in a design that has systematically removed luck where luck
is deliberately put back.

**The price is flat, roughly the cheapest hero on a roster.** Define it against a
catalogue entry rather than a bare number, so it tracks hero pricing
automatically.

Why this is the only exchange between the two economies, why it is deliberately a
bad deal, and what "certainty-for-heroes" means, is in
[the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) and
[commanders and personal resource](../docs/011-commanders-and-personal-resource.md).

## Suggested implementation steps

1. Write the deck as a flat array of kind ids, generated at match start from the
   catalogue weights via the `deck` stream, long enough that no match reaches the
   end. Give each team an index and a tail.
2. Write the verb handler and add it to the command dispatch table in issue 106.
3. Put the cost in the catalogue, defined against the cheap hero.
4. **Show what is being given up, clearly. Show nothing at all about what is
   coming** — no card back, no hint, no rarity, no count of what remains. Anything
   that lets a player narrow the next card partially reintroduces deck-farming at
   a fraction of the information.
5. Refuse during a siege-surge, like everything else that touches the chest.
6. Write a test that rerolling advances only the rerolling team's index and
   leaves the other team's sequence identical.
7. Write a test that a rerolled kind reappears at that team's tail and can be
   drawn again much later.
8. Have the headless runner report **rerolls per player against heroes fielded
   per player**. The tradeoff between them is the whole feature and nobody has
   looked at it yet.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) — the shared
  deck and why it exists
- [Commanders and personal resource](../docs/011-commanders-and-personal-resource.md)
  — the two economies and the one place they touch

## Still open

**A flat price against a rising ceiling means rerolling gets cheaper in real
terms as a match runs**, so late chests end up better shaped than early ones.
Probably right — with a shared deck, late rerolling is the main way two teams
holding the same cards end up holding different ones — but it is a curve nobody
chose deliberately. Recorded as A16c; issue 804 should watch it.

**Can you reroll a placed instance, or only an unplaced one?** Working ruling:
either, subject to the lock check. A rerolled placed instance leaves its
replacement in the same slot — though whether that replacement then has to serve
a transit wave is a question this raises against issue 404.

**Does this worsen the hero snowball?** A winning team earns more, so it can both
field more heroes *and* reroll more. Recorded against C3.
