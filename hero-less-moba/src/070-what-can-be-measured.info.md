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

### What a body is carrying and doing

| Name | What it is |
| --- | --- |
| `health` | Every point of health standing on the field, added up. |
| `wounded` | Living bodies carrying less than the health they were born with. The cheapest proof a blow landed. |
| `guards` | Living bodies that belong to a tower. |
| `heroes` | Living bodies somebody paid for out of a wallet. |
| `monsters` | Living bodies of the kind that walks out of the middle. |
| `walking` / `closing` / `fighting` / `leashing` / `dying` | The five built rows of the brain, one count each. They add up to the living. |
| `hurrying` | How many asked for the fastest gait **on the tick this was read** — a pace is chosen fresh every tick, so this is a state and not a tally. |
| `patterns` | How many different movement patterns placed a goal this tick. One row doing all the work means the others are decoration. |
| `carried` | Living bodies stamped at birth with at least one upgrade. |

### The waves, the stone and the two economies

| Name | What it is |
| --- | --- |
| `waves` | Wave records with anybody left alive in them. |
| `wipes` | Waves wiped out since the match began, both teams. **A tally, so it never falls.** |
| `towers` / `rubble` / `libraries` | Guard towers standing, guard towers fallen, libraries standing. |
| `stone_health` | Every point of health left in every standing structure. |
| `inside_stone` | Living bodies standing inside a building that is still up. **Should be nought**, for the same reason `overlaps` should be. |
| `guards_inside_stone` | The same, counting only the bodies a tower put out itself. |
| `aiming_towers` | Standing towers currently holding a target. Nought with bodies in reach is a tower that acquires nothing. |
| `armed_towers` | Standing towers shooting with at least one upgrade. The proof a tower's own copy of its lane's stone was rebuilt. |
| `chest` | Upgrades drawn and not yet placed, both teams. |
| `placed` | Upgrades sitting in any slot. **The sum of the three below.** |
| `in_lanes` / `in_stone` / `in_library` | The same count, split by which of the three places it is standing in. |
| `wallets` | Every point of personal resource every player holds, of every colour. |
| `bought` | Heroes paid for since the match began. A tally. |
| `phase` | 1 normal, 2 surge, 3 challenge, 4 calm, 5 over. |
| `winner` | Nought while the match runs; the winning team after; 3 for the double library. |

A reading that needs part of a world an arena does not build — the chest, the players,
the structures — refuses **by name**, saying which reading wanted what. An arena hangs
only the modules a test asked for, so the fix is nearly always one word in a `want` list,
and an error that blamed a line inside the catalogue would not say so.

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
| `ever_at_least <n>` | **reached it at least once** — judged at the highest the reading got |
| `ever_at_most <n>` | reached it at least once, from the other side |

The last two are the reached-it claims, and half of what a test wants to say needs them.
A thing that *happened* — a tower acquired a target, three movement patterns were in use
at once, a body was pushed out of somebody — is true at one tick and false at the others,
so asking it with `at_least` fails on tick nought, correctly and uselessly.

They still say nothing about **how long** something lasted or **what order** two things
happened in. That gap is open, and is written up on
[issue 111a](../issues/111a-every-mechanic-has-a-test.md).

## Adding one

A row. It takes the world and returns a number, and that contract is deliberately
narrow: a reading that returned a table would need a caller who knew its shape, and then
the knowledge is back out in the callers where it started.
