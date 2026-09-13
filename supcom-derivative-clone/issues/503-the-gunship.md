# 503 — The gunship

| | |
| --- | --- |
| Phase | 5 — The Big Things |
| Blocked by | 402, 501 |
| Blocks | — |
| Reads | [enforcers and experimentals](../docs/009-enforcers-and-experimentals.md) |
| Open questions | none |

## Current behavior

Nothing. Every air unit goes to the cloud through issue 402, and an air factory
refuses a pattern by that issue's rule. Issue 501 puts a gunship row in the
catalogue with nowhere to fly. `tests/023-the-big-things.lua` asserts that a
gunship emitted from an air factory with a pattern follows the pattern and never
enters the cloud, and that its single hit is the largest in the catalogue.

## Intended behavior

"Take damage — everyone can build a powerful gunship." The gunship is the one
plane that is not part of the air war. It **ignores the cloud** and flies a
**pattern** like a tank, at flight height, firing at what it sees with the
largest single hit in the game, and holds at the end of the pattern like a tank
does. It is a tank that crosses dunes instead of climbing them, and the price
of that is that every anti-air gun with a sightline shoots it the whole way.

That needs one change to issue 402's rule. Whether an air factory's placement
may carry a pattern was decided by domain; it is now decided by **what the line
builds**. Each catalogue row gets a `flies_pattern` flag. A line whose kinds
all go to the cloud refuses a pattern; a line containing any kind that flies a
pattern requires one; a line that mixes the two is refused at the line
catalogue's validation, because one factory cannot both have and not have a
drawing in the sand. The first-mission table in the emit pass reads the flag:
air with the flag set starts on leg one with mission `pattern-flight`; air
without it starts `to-cloud`.

`pattern-flight` is a new row in the `MISSIONS` table. It walks legs exactly as
`movement` walks them for a land unit — the same function, called with the
plane's row — with the altitude set through `domains` each step. At the last
point it holds. It is never `in-cloud`, never `defensive`, never answers a
report; it is not in the swarm and the round pass never sees it.

Its cost leans on energy, a thousand of it, by issue 501's rule. Its damage is
the catalogue's largest and its falloff is the tank's shape, so that a gunship
at the far side of the field is a nuisance and a gunship overhead is a
catastrophe, which is the pattern it maximises.

## Suggested implementation steps

1. Add `flies_pattern` (integer flag) to the catalogue rows; set it for the
   gunship only.
2. In `factories`' placement validator, replace the domain test from issue 402
   with the three-way rule on the line's kinds, refusing by name in each case.
   Extend the line catalogue's validator to refuse a mixed line.
3. In the emit pass's `FIRST_MISSION` table, key the air entry on the flag.
4. Add the `pattern-flight` row to `the-cloud`'s `MISSIONS`, calling the
   leg-walking function from `movement` and the altitude from `domains`.
5. Confirm the round pass, the posture step, and `answer_reports` only ever
   consider planes whose mission is `in-cloud` — they do by construction, but the
   test should assert the gunship is never counted.
6. Write the test's assertions: the pattern is followed, the cloud is never
   entered, the hit is the largest.
7. Update the companions of `factories`, `the-cloud`, and the catalogue.

## Related documents and tools

- [Enforcers and experimentals](../docs/009-enforcers-and-experimentals.md)
- [The cloud](../docs/007-the-cloud.md) — the missions table
- [Factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
- `tests/023-the-big-things.lua`

## Still open

- Whether a gunship should be a targeting candidate for enemy interceptors —
  planes fighting a plane that is not in the air war. No, for now: only guns
  shoot it.
- Whether the gunship's hold at the end of its pattern should be a circle over
  the point or a hover. A hover is the working ruling; it is a position, and
  positions are cheap.
