# Phase 13 — The Whole Cake: progress

**Integration, materials, the specification sheet, the handoff. Complete.**

| ticket | blueprint | state |
|---|---|---|
| `1301` | `087-system-integration` | done |
| `1302` | `088-bill-of-materials` | done |
| `1303` | `089-specification-sheet` | done |
| `1304` | `090-handoff-package` | done |

**Eighty-four blueprints. One thousand three hundred and seventy-five symbols.
Five hundred and thirty-two constraints. All of them hold and none is
unevaluated.**

## What the cost model says, which is not what was expected

The ticket for `1302` expected silicon area first, then yield, then bonding.

**Memory tiers dominate.** Two thirds of the silicon bill, and not the compute
dies. A tier is forty millimetres square — large enough that only about two thirds
come off a wafer good, so a third are scrapped before anything is assembled.

**Assembly yield came out smaller than the bare arithmetic threatens.** With
`082`'s test gates, `040`'s spare rows, the redundant tier and the spare
conductors in `051` and `063`, about nine cubes in ten survive being built from
known-good parts. Yield adds roughly a twelfth to the cost.

**The mitigations work**, which is why `C-088-4` now asserts that yield stays
*visible* rather than that it is large — so nobody removes one on the grounds it
is not costing anything.

And the ordering is the finding: **making the tiers smaller would save more than
any assembly improvement**, and nothing has been asked whether a tier has to be
one piece.

## Eight constraints written in the direction of alarm

A pattern that emerged rather than being planned. A constraint that will always
hold, asserted so a reader meets a number rather than a claim:

- twenty-four tiers with no redundancy lose more than one stack in seven
- the radial bonds with no spares fail more often than they work
- at the transistor's own voltage the machine would draw over a kiloampere
- at least four properties must be named untestable
- training every parameter is out of reach by an order of magnitude
- the machine loses on capacity against the accelerator it is compared with
- copper laminae would leave no usable margin against silicon fracture
- distributing one clock edge across a face costs a quarter of a cycle

## The weakness the capstone cannot fix

**The notation holds numbers and not lists.** So a seam register can count seams
and count constraints and **cannot verify that a given seam has a constraint on
it.** Five places in the project have that shape:

- `072`'s enumeration of where two faces interact, against `039`'s
- `077`'s count of exactly-specified operations
- `080`'s counters against its model terms
- `085`'s rungs against their pass criteria
- `087`'s own seam register

`C-087-5` holds the ceiling at five rather than fixing it. **Fixing it means the
notation growing a named set, and that is the largest single improvement
available to the instruments.**

## What is still open

Everything in `009`, and two things this phase added:

**`n_seam` is a hand count.** The number `087` most wants to derive and cannot,
made from the blocks-and-blocked-by graph in the tickets. If it is wrong,
`C-087-1` is checking a number against itself.

**The ownership table is missing** (`090`). Which blueprint a question goes to and
which open question bears on it — the part that makes the package usable by
somebody who did not write it. It wants generating from the tickets rather than
writing.
