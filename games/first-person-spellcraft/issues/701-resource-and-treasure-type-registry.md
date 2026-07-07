# 701 — Resource & Treasure Type Registry

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** nothing inside Phase 7 (this is the taproot of the economy).
> **Blocks:** 702 (stockpile), 703 (templates), 704 (production), 705 (market).
> **Concern:** data generation (simulation). No UI here.

The foundation the whole settlement economy rests on: a single place that
*defines* the kinds of treasure and resource that exist, and — for each kind —
what it does. Everything downstream (the stockpile that counts them, the markets
that spend them, the workshops that make goods out of them) reaches into this
registry instead of hardcoding its own idea of "what a gem is."

## Current Behavior

None of this exists yet. There is no notion of a resource, a treasure kind, or a
resource type anywhere in the project. The vision names four treasure kinds —
gold, gems, resource notes, and trial logs — but nothing represents them.

## Intended Behavior

A **resource-type registry**: a dispatch table keyed by resource-type id, where
each entry is a small behavior record describing one kind of treasure or
resource. The four the vision fixes, and the design intent behind each:

- **Gold** — generic currency, and *deliberately abundant*. The vision says
  "so much gold that it's hard to consider what's most valuable." Gold is the
  glut; it should be plentiful enough that spending it is rarely the interesting
  decision. It pays for ordinary market goods, not the prized capabilities.
- **Gems** — scarce. The vision: "when the NPC finds gems, they can request
  things from the markets." Gems gate the good requests (magic items, rituals).
- **Resource notes** — claims on materials / promissory notes found in vaults;
  they let a returning character request material capabilities from ashore.
- **Trial logs** — records of a party's demonstrated capability (the same kind
  of "what did they prove they can do" signal the Dungeon Master and the
  provinces care about). They unlock capability requests that gold cannot buy.

Each resource-type record answers, by table lookup rather than branching:

- its display name and a one-line description (for the UI and companion
  dialogue),
- whether it is fungible / stackable (gold stacks into one number; a specific
  trial log may be a distinct item),
- how it tends to be *found in vaults* (a hook Phase 5's treasure generation can
  consult, so the "what's in this vault" logic lives with the resource, not
  scattered),
- what **classes of request** it is allowed to pay for (this is what makes gems
  gate rituals while gold only buys market goods).

Because "what does this resource do" is a per-kind behavior, it is a **dispatch
table keyed by resource-type id**, never an if/else ladder over kind. Adding a
fifth resource later is adding one row.

## Suggested Implementation Steps

1. Decide the resource-type id set (start with the vision's four). Write them as
   the keys of the registry table.
2. For each id, author its behavior record: display name, description,
   fungible/stackable flag, vault-find hook, and the set of request-classes it
   may pay for.
3. Expose one **look-up-a-resource-type** entrypoint that other modules call to
   reach a resource's behavior — this is the single seam; nothing downstream
   should read the table directly.
4. Put the *tunable* parts (how abundant gold is, relative vault-find weights)
   behind a tuning/config value read at load, not a hardcoded literal — see the
   validator note below.
5. Write the corresponding `.info.md` describing each usable entrypoint as a
   black box, and a small validator that lists every registered resource-type
   and its request-classes, so the docs never need to restate the list.

## Files (proposed, by role)

Index prefixes are assigned from `.file-index-counter` at creation time; named
here by role only.

- an `economy/resource-types` module (the registry table + the look-up
  entrypoint) and its `.info.md`.
- a `economy/resource-types` validator/lister utility that prints the current
  registry.

## Statistics / tuning

No counts are fixed in this document beyond the vision's four kinds. Gold's
abundance and vault-find weights are tuning knobs; when turned, record them in
`docs/balance-updates.md` with the reason.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  the resource registry is the "701" box feeding every other stage.
- Consumed by 702 (stockpile balances are keyed by these ids), 703 (templates
  price requests in these), 704 (production inputs/outputs are these), 705
  (markets spend these).
