# 103 -- A thing is one record

**Phase:** 1, the world holds still
**Blocked by:** [101](101-the-arithmetic-is-integers.md),
[102](102-the-world-is-flat-arrays.md)
**Blocks:** sight, motion, control, drawing -- everything that is about a body.
**Documents:** [a thing in the world](../../docs/005-a-thing-in-the-world.md)

## Current behaviour

Nothing exists.

## Intended behaviour

One record type for everything that stands in the space. A player's character, a
goblin, a coffee cup, a door leaf, a torch on a bracket, a tree.

The field table is in
[the document](../../docs/005-a-thing-in-the-world.md) and is not repeated here.
What this issue is about is the discipline around it:

**There is no second record type, and there will be pressure to add one.** The
pressure arrives as "props do not need a sight cone" or "doors are not really
creatures". Both are true and neither is a reason: a coffee cup with
`sight_range = 0` costs four bytes and buys the property that the code moving a
coffee cup *is* the code moving a goblin. That property is what makes the
tavern's commander in phase 6 require no new code at all.

If that unification is ever broken, it should be broken deliberately, with the
reason written down, and [008](../../docs/008-who-controls-what.md) revisited --
because the dial is built on top of this record being universal.

**Appearance is not in the record.** No name, no colour, no sprite. The server
can run a whole session without knowing that `kind = 7` is called a goblin.

**Game numbers are not in the record.** No hit points, no conditions. The `sheet`
field is an index into storage the ruleset owns and the server never reads.

## Suggested implementation steps

1. Define the record and the flag bits. Comment each flag with what the world is
   like when it is set *and* when it is clear -- particularly the two blocking
   bits, whose interesting cases are the ones where they disagree.
2. Write creation and destruction against the block from
   [102](102-the-world-is-flat-arrays.md). Destruction leaves a hole; decide now
   whether holes are compacted or reused, and write the reason down. Compaction
   moves indices, which every other block would have to be told about, so reuse
   is almost certainly correct.
3. Provide the small predicates -- does this block sight, is this mobile, does
   this see -- as inline functions rather than letting callers test bits by hand.
   A bit tested by hand in forty places is a bit that gets tested wrongly in one.
4. Write the companion `.info.md`.
5. Test: create, destroy, recreate, and assert that a destroyed index is not
   reachable from anything.

## Related

The universality claim is one of the project's stated beliefs -- see
[faith](../../faith/boons-expected). If it breaks, that file is where the breakage
gets recorded.
