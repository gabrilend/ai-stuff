# 603 — The Chest, Dealt Across the Three

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 105, 402, 412, 601, 602 |
| Blocks | 605 |
| Reads | [the siege-surge](../docs/014-the-siege-surge.md), [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

A siege-surge changes how soldiers spawn and leaves every placement exactly where
it was.

## Intended behavior

**While a surge runs, upgrades cannot be placed, moved, or withdrawn.**

Instead, at every spawn the team's **entire chest is dealt out across the three
new bodies** — one per lane, all three spawning on the same timer, like a hand of
cards.

*Settled; see [open questions](../docs/020-open-questions.md), A6 and A6b.*

### The deal

1. Pick a **random starting lane** from that team's `surge` stream.
2. Walk the chest in random order, handing each upgrade to the next lane's body
   in rotation — starting lane, next, next, back to the first — until every
   upgrade has been dealt.
3. Spawn the three bodies with what they were dealt, plus every boon
   unconditionally.

Each body ends up with ⌊N/3⌋ or ⌈N/3⌉ upgrades. **Every upgrade you own is on
the field at every instant**, and no two of the three carry the same one.

The **random starting lane** is not decoration. When the chest does not divide by
three, one body gets one fewer — and starting the deal at a random lane each time
means **which lane comes up short rotates**, rather than the top lane being
permanently a little poorer than the others for the whole surge. That is a real
fairness bug avoided by one call into a stream.

### What this does to a team

It does not make you weaker. Nothing is lost, nothing is held back, and your full
chest is walking down the map at all times. **It makes you incoherent.**

The three upgrades that worked together in the top lane are all still on the
field — on three different soldiers, in three different lanes, never in the same
place again until the surge ends. What the surge takes from you is not strength;
it is the *arrangement*, which is the only thing in this game a team actually
built.

It also **flattens the lanes perfectly.** Every lane receives a third of
everything, so during a surge no lane is special: the careful asymmetry a team
spent the match constructing is replaced by an even smear. A team that had
stacked one lane suddenly has three mediocre ones.

And it is self-balancing in a way a flat penalty is not. A team with twelve
upgrades has a great deal disturbed by being dealt out three ways; a team with
three has each of them on a body and almost nothing disturbed. **The surge
disrupts in proportion to how much there was to disrupt.**

### When the surge ends

Every upgrade is dumped into the chest, unplaced, doing nothing. The scramble to
re-place them happens under the challenge, with a monster walking.

## Suggested implementation steps

1. Add the `surge` stream, per team, to the stream table from issue 105. It
   supplies both the deal order and the starting lane, and advances several times
   a second while a surge runs — far more than any other, which is precisely why
   it must not be shared.
2. Make the surge spawner emit **all three lanes on one timer**, as a group. The
   deal is only possible because the three bodies exist at the same instant, so
   this is a prerequisite rather than an optimisation.
3. Write the deal: shuffle the instance array into a scratch buffer using the
   stream, pick a starting lane, walk and rotate. Preallocate the scratch buffer;
   this runs several times a second.
4. OR every boon into all three afterwards, unconditionally.
5. Nothing is refused during a surge — placement stays open in every phase (F12). Confirm that
   and `reroll_upgrade` during phase 2, with a reason code that says why. Players
   will try, and being told "not during a surge" is the only way they learn it.
6. Write the surge-end dump: every instance to `slot_kind = 0`, locks released,
   objections cleared, boons skipped.
7. Write a test that the union of the three bodies' masks at any spawn equals the
   team's whole chest, exactly, with no duplicates.
8. Write a test that over many spawns each lane comes up short about equally
   often when the chest size is not divisible by three.

## Related documents and tools

- [The siege-surge](../docs/014-the-siege-surge.md)
- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)

## Still open

Nothing blocking. The one number is the stream's spawn interval, which belongs to
issue 602.
