# 070-what-can-be-measured

Every reading a test may take of a world, and every claim it may make about one.

## What it is for

Before this file, "how far has the leading body come" was written out in three places:
in [the window's](069-the-proving-ground.info.md) readout, in a Lua string inside a
shell script, and in whichever test happened to want it. All three said front-minus-back
and all three were free to stop agreeing, silently, on the day one of them learned to
skip the dead and the others did not.

The duplication is the smaller half. The larger half is that **a test that computes its
own numbers cannot be contradicted by the world.** It measures whatever it decided to
measure, and if that is subtly the wrong thing, nothing in the project is in a position
to say so.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `reading` | *(table)* | Every named reading. Each has `label`, `format` and `of(world)`. |
| `readout` | *(table)* | Named groups of readings, for printing several together. |
| `take(world, names)` | a list, or a readout's name | Rows of `{name, label, value, text}`. |
| `line(world, names)` | | The same readings as one line of text. |
| `claim` | *(table)* | Every comparison a test may make. |
| `fold(world, names, summary)` | | The summary, with this tick folded in. |
| `readings_named(rows)` | claim rows | Which readings those rows are about. |
| `judge(world, row)` | | Whether the claim holds now, and why not. |
| `judge_over(summary, row)` | | Whether it held at every tick of a run. |

## The readings

| Name | What it is |
| --- | --- |
| `tick` | The world's own clock. |
| `alive` | Every living body: wave bodies, strays, tower guards, monsters. |
| `bodies` | Living bodies that belong to a formation. |
| `strays` | Living bodies in no formation — the things an army has to get past. |
| `front` / `back` | How far along its lane the leading and trailing formed body has come. |
| `depth` | The road the formed bodies are spread over. |
| `going_round` | How many had this tick's step moved out of somebody else. |
| `straight_through` | How many walked where they meant to. |
| `closest_approach` | The narrowest gap between any two living bodies, **skin to skin**. Zero is touching exactly; negative is somebody inside somebody. |
| `overlaps` | How many pairs are standing inside each other. Should be nought at every tick of every test. |
| `widest_offset` | How far off its lane's centre line the most sideways body has got. |
| `off_the_road` | How many are outside their own lane, measured against that lane's own width. |

The last four walk every pair or every body, which is fine for the dozen bodies an arena
holds and expensive on a whole match. That is the caller's choice: a reading is only
taken when a test names it.

## A claim is a row, and it has a side

A claim is a reading, a comparison and a number — `{"overlaps", "equals", 0}`. A test
that could write an arbitrary predicate could write one that passes for the wrong reason,
and nothing outside the test would be able to tell.

Each comparison also says **which end of a run's history it has to be asked about**.
`at_least` fails at the lowest the reading ever got; `at_most` at the highest; `equals`,
`within` and `between` are two-sided and are asked about both.

**That is here because judging only the last tick missed everything.** Two columns of
allied troops walked into each other, briefly stood inside one another, squeezed past and
arrived at opposite ends of the road — and a check taken at the end of the run reported a
field with nobody overlapping anybody, which was true and told the reader the opposite of
what had happened.

| Comparison | Says |
| --- | --- |
| `at_least <n>` | never below |
| `at_most <n>` | never above |
| `equals <n>` | exactly, throughout |
| `within <n> <tolerance>` | near enough, for anything that came out of arithmetic on positions |
| `between <low> <high>` | inside a band |

## Adding one

A row. It takes the world and returns a number, and that contract is deliberately
narrow: a reading that returned a table would need a caller who knew its shape, and then
the knowledge is back out in the callers where it started.
