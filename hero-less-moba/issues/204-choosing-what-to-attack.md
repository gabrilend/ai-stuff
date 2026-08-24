# 204 — Choosing What to Attack

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 105, 201 |
| Blocks | 203, 302, 606 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

Soldiers walk past each other without noticing.

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

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- The `tie` stream from issue 105
