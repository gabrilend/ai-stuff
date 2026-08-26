# 908 -- The phase nine demo

**Phase:** 9, the sprite studio
**Blocked by:** every other issue in phase 9.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` offers phases 1 through 8.

## Intended behaviour

### What it shows

**A batch generated**, with the pool's counts per category.

**The tiers and their provenance** — how many machine, how many a person's, and
the agreement rate between them where both exist.

**The dial moved, with its cost reported first.** Raise one category's floor and
print the surviving count at both settings, before applying it. Then show the
output getting more alike, which is the variety being spent.

**Both algorithms.** Run the same batch under A and under B and print the two
resulting pools side by side. Neither counts as built until both are shown
working.

**A sprite re-tiered from a live session** — the thing that makes B a tabletop
idea rather than a gallery idea. Mid-play, through the same command door as
everything else, without stopping.

**And the honesty:** say that the machine grader is a heuristic and roughly what
it measures. Report the human-rated fraction, and say plainly if it is below the
anchor.

### The artifact itself

Write a few sprites out where somebody can open them, and say where. An SVG that
animates in a browser is the whole point of the format choice, and a demo that
only prints numbers about it has hidden the deliverable.

## Suggested implementation steps

1. Generate a batch across several categories, deterministically.
2. Print the pool summary.
3. Show the floor being raised, cost first.
4. Run both algorithms and compare.
5. Re-tier one during a running session.
6. Write sample sprites to the RAM tier and print the paths.
7. Confirm `./run-phase-demo 9`.
