# 804 — Ten Thousand Matches Overnight

| | |
| --- | --- |
| Phase | 8 — Six Players |
| Blocked by | 108, 209, 403, 405, 803 |
| Blocks | 805 |
| Reads | [the shape of the code](../docs/018-the-shape-of-the-code.md), [roadmap](../docs/019-roadmap.md) |
| Open questions | B11 — does the frontline actually move |

## Current behavior

Balance is a set of numbers somebody guessed, and the only evidence about them is
however many matches a person has had the patience to watch.

## Intended behavior

A batch runner that plays thousands of matches with no window open, varying seed,
bot strategy, and catalogue values, and writes one line per match into a table
that can be read in the morning.

This is what the whole generator-viewer split was for. It is only possible
because the simulation opens no window, reads no keyboard, and is a pure function
of seed and commands — and it is the moment that separation stops being a
principle and starts being the reason a question can be answered at all.

**The question it exists to answer:**

> Does the frontline actually move?

The vision's premise is that a subtracted lane-pusher stalemates. Nothing in any
of this documentation proves that upgrades, heroes, and surges are enough to
unstick it. The phase-2 demo shows the stalemate; the phase-4 demo shows it
broken in one hand-arranged case. This issue is where it is shown to be broken in
general, or where the design is found to be wrong — and if it is wrong, no amount
of tuning fixes it and that is worth knowing early.

The measures that answer it, per match:

- **Frontline displacement over time**, per lane. A match where all three lanes
  sit at milestone 4 the whole way through is the failure.
- **Time to first tower, first base breach, and match end.** A distribution, not
  an average — a design that produces either twelve-minute stomps or
  ninety-minute grinds and nothing between is a broken design with a fine
  average.
- **Upgrades drawn per team**, broken down by source, and the gap between the
  winning and losing team's counts. This measures the snowball the surge is
  supposed to brake.
- **Frontline position immediately before and after each surge.** Does a surge
  actually reset a lopsided match, or merely delay it?
- **Challenge failures.** How often a monster reaches a library, and whether it
  correlates with anything a player could have done differently.
- **Win rate by bot strategy.** Whether the strategies the design promises are
  actually distinct.

## Suggested implementation steps

1. Write the batch runner over the headless runner, one match per worker, with a
   pool of single-threaded simulations rather than one many-threaded simulation.
   The work is embarrassingly parallel at the match level, which is the right
   granularity here.
2. Write the parameter sweep: seed, strategy pairing, and any catalogue value.
3. Write one machine-readable line per match, and **a separate viewer for the
   table**. Same separation again: the runner produces data, the report views it.
4. Write the specific reports listed above, each as its own small tool.
5. Feed every conclusion into `docs/balance-updates.md` with the reason and what
   was observed. Numbers changed without a recorded reason are numbers that will
   be changed back by somebody who does not know why they moved.

## Related documents and tools

- [The shape of the code](../docs/018-the-shape-of-the-code.md)
- `docs/balance-updates.md`
- [Open questions](../docs/020-open-questions.md), Group B — this issue is how
  most of that group gets answered

## Still open

Every unanswered number in Group B is an input to this runner, which means this
issue cannot start until they have provisional values — and its output is what
makes them final. The first run's job is not to find the right numbers; it is to
find out whether the design has a right set of numbers at all.
