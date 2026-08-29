# 208 — The Network Validator

| | |
| --- | --- |
| Phase | 2 — The Cage |
| Blocked by | 201, 202, 203 |
| Blocks | 309, 310 |
| Reads | [the fence network](../docs/004-the-fence-network.md) |
| Open questions | — |

## Current behavior

A network can be loaded. Nothing checks whether it makes sense.

## Intended behavior

A program that walks a fence network and reports every way it is malformed. It
**reads and reports; it never repairs** — a validator that quietly fixes things
hides the tracing mistake that caused them, and the mistake will be repeated.

It runs on every save in the tracing tool and as part of the test run.

### What it refuses

| Fault | Why it is impossible or wrong |
| --- | --- |
| an edge named by three or more blocks | cannot happen in a plane; a street has two sides |
| an edge named by no block | stranded — traced and then orphaned |
| a block whose loop does not close | walking it does not return to the start; it will fill and hit-test wrongly |
| a block whose loop crosses itself | usually a direction flag wrong on one edge |
| a block with no name | unreachable by search, and unnameable in the tome |
| a vertex used as an endpoint by one edge and as an interior point by another | two streets disagree about whether they meet — see [202](202-junctions-and-shape-points-are-derived.md) |
| two vertices closer than the snap radius at native zoom | almost always a mis-snap rather than an intention |

### The last one is the important one

The others are structural and would eventually announce themselves. **A near-miss
snap does not.** It produces a network that looks completely correct on screen —
two hairlines a pixel apart down one lane — while the blocks either side are not
neighbours and never will be.

That is the failure mode that costs a day of retracing to find, and it is the
reason this validator exists rather than being left to a later phase.

### The report

Named places, not indices. "Tanner's Row and Fishgate do not meet along the west
lane" is actionable; "block 417, edge 2201" is a lookup task. Where a place has no
name yet, say where it is on the painting.

## Suggested implementation steps

1. Build the edge-to-blocks index from [203](203-adjacency-is-a-shared-edge.md) and
   check the counts.
2. Walk each loop, honouring direction flags; assert it returns to its start.
3. Check for self-crossing by testing each pair of non-adjacent segments in the
   loop — blocks have few edges, so the simple test is fine.
4. Use the vertex-to-edges index from [202](202-junctions-and-shape-points-are-derived.md)
   for the endpoint-versus-interior conflict.
5. For near-duplicate vertices, bucket by a coarse grid so this stays linear
   rather than comparing every vertex to every other.
6. Exit non-zero when anything is found, so it can fail a build.
7. Test each fault by deliberately breaking a copy of the fixture network one way
   at a time and asserting the right complaint comes out.

## Related documents and tools

- [The fence network](../docs/004-the-fence-network.md)
- [The tracing tool](../docs/005-the-tracing-tool.md)
