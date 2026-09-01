# 204 — Choosing What to Attack

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 105, 201 |
| Blocks | 203, 302, 606 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

Ranked, cheapest test first: somebody already swinging at me, then the
lowest-health enemy in acquisition range, then a structure in weapon range, then
nothing. Lowest health rather than nearest, because bodies should finish things.

Ties are broken by the team's own tie stream with reservoir sampling, which advances
the stream a fixed number of times so a replay stays reproducible. A spatial grid
rebuilt each tick keeps the search from being every body asking every other.

**And rule 1 hardly ever fires**, which was not noticed until somebody watched a
fight. The tick only asks a body to choose when it has **no living target**, so a
body already swinging at somebody never re-enters the ranking at all. Rule 1
therefore only decides anything in the one tick after a target dies. A body locked
onto a wounded enemy will take a whole fight's worth of blows in the back from a
second enemy and never once look round.

## Intended behavior

Target selection, ranked, cheapest test first:

1. **An enemy soldier already attacking me.** Free to check — it is a field, not
   a search — and it is what makes a frontline hold together rather than
   scattering to chase.
2. **The nearest enemy soldier within acquisition range.**
3. **An enemy structure within weapon range.**
4. **Nothing.** Keep walking.

Structures rank **below** soldiers deliberately. A soldier that walks past a
defended tower to chew on the tower is a soldier that dies for free, and a
frontline made of those never moves — which is the exact failure this whole game
exists to fix.

### What makes a body look up

The ranking above decides *what* to hit. This decides *when it is asked* — and
without it the first rule is nearly dead, because a body with a living target is
never asked at all.

**A body looks up when it is struck by an enemy that has not struck it before.**
Not when it is struck — a body in a melee is struck constantly, and re-deciding on
every blow is the crowd-of-bodies-re-deciding-every-tick failure that the
only-if-you-have-nothing rule exists to prevent. The event is a *new* assailant,
which is the moment something has changed about the fight this body is in.

So each body remembers **the few enemies that have most recently hit it**, and an
attacker already in that memory passes without comment. A body being worked over by
the same three enemies settles down and keeps swinging; a body that picks up a
fourth from a direction nobody was covering looks round once.

The memory is **small and forgetful on purpose** — a handful of slots, oldest
overwritten. Remembering every enemy that ever hit it would mean a body that has
been through two fights never looks up again, which is the opposite failure and a
harder one to see. Forgetting also does something real: an enemy that hit you,
left, and came back **is** worth another look.

Each remembered attacker is held with its **generation**, because slots are
recycled. Without the stamp, a body would remember "id 57" and then ignore an
entirely different soldier that was later born into slot 57 — which is the same
class of bug the target's generation check exists to prevent, one step removed.

**It overrides the blocked-shot patience.** A body that had no line a moment ago and
is waiting a few ticks before looking again should not spend that wait being hit by
somebody new. Being struck is exactly the event that makes the wait wrong.

The look-up is a **flag set during the attacker sweep and read on the next tick**,
which is the same one-tick lag rule 1 already runs on — the sweep is where every
attacker-and-victim pair is already being visited, so noticing a new one there is
free rather than a second pass.

Exact ties are broken by the `tie` random stream, not by the lower slot index.
Two identical soldiers facing two identical enemies at identical distances should
not both pick the leftmost one every single time; that produces a frontline that
focuses in lockstep and looks mechanical. The stream is separate from every other
so that changing tie-breaking never perturbs the upgrade draw sequence.

The nearest-enemy search must not be a scan of every soldier on the map for every
soldier on the map. Soldiers are on lanes, and everything a soldier can reach is
within a short stretch of its own lane's path. **Bucket soldiers by lane and by
milestone**, and search two buckets. The search is then bounded by how many
bodies are in a few paces of lane, which is small and does not grow with match
length.

## Suggested implementation steps

1. Add `attacked_by` to the soldier record, written in the attack pass and read
   here. It is the cheapest good answer available.
2. Build the lane-and-milestone buckets once per tick, in the spawn pass, as a
   counting sort into a preallocated array. Not a hash table; hash iteration
   order is not stable and would break determinism.
3. Write the retarget pass over the buckets, sliced for the thread pool. It reads
   the world and writes only each soldier's own target fields.
4. Check the target's generation before every use. A recycled id must never
   silently address a stranger.
5. Write a test with two soldiers at equal distance from a third and assert the
   choice is stable for a given seed and varies across seeds.
6. Write a test that a soldier with a defended tower and an enemy soldier both in
   range picks the soldier.
7. Add the recent-attacker memory to the soldier record: a fixed handful of slots,
   each holding an attacker's id and the generation it had when it struck. Cleared
   when a body is born, like every other field.
8. In the attacker sweep, where every attacker-and-victim pair is already visited,
   compare the striker against the victim's memory. Absent means write it into the
   oldest slot and raise the victim's look-up flag.
9. In the retarget pass, treat a raised flag as a reason to choose even when the
   body has a living target. Clear it in the choosing, and let it skip the
   blocked-shot patience.
10. Write a test that a body already fighting one enemy switches its attention when
    a second enemy that has never hit it starts hitting it — and, in the same test,
    that a third blow from an enemy already in the memory does **not** make it look
    up, because the second half is the one that keeps this from being a body that
    re-decides every tick.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- The `tie` stream from issue 105
