# 307 — The Library Ends the Game

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 205, 301, 305 |
| Blocks | 608, 805 |
| Reads | [the base and the library](../docs/008-the-base-and-the-library.md) |
| Open questions | none |

## Current behavior

A library at zero health ends the match on that tick. Both libraries falling in
the same buffered pass is recorded as a draw rather than resolved by team number,
which happens in practice: two passive sides are mirrors and both Golems arrive
together.

## Intended behavior

**When a library's health reaches zero, the team that destroyed it wins, and the
match ends on that tick.** There is no second objective, no throne behind it, and
no comeback after it falls.

The library has about one and a half guard towers' worth of health, stored as a
ratio so that retuning towers retunes it automatically. It has no armour, attacks
nothing, and does not regenerate.

That ratio is smaller than players will expect, and the effect is deliberate: a
base breach is very close to a loss. Once the towers are down a team does not get
a long grinding defence of its core, it gets about one wave's worth of grace. A
game whose whole premise is *the frontline must move* cannot afford a fortress at
the end of it.

**If both libraries would fall on the same tick, the match is a draw.** This can
happen, because damage is buffered and resolved together. Picking a winner by
team number would mean team 1 wins ties forever — the kind of invisible asymmetry
that is only ever discovered by the player it kept beating.

The phase goes to 4 (over). Spawning stops, commands are refused, and the runner
writes its report. The snapshot keeps being produced so the viewer can show the
final state rather than freezing on whatever it last drew.

## Suggested implementation steps

1. Add the library-felled check to the resolve pass, alongside the tower one.
2. Check **both** libraries before declaring a winner, so a double fall is seen
   as a double fall rather than as whichever was checked first.
3. Set `world.phase = 5` — the over row — and record the winner, the tick, and
   the lane the killing blow came down.
4. Make the over row of the phase table refuse every command and spawn
   nothing, rather than each system testing for game-over separately.
5. Write a test that fells a library and asserts the match ends on that tick with
   the right winner.
6. Write a test that fells both on the same tick and asserts a draw.

## Related documents and tools

- [The base and the library](../docs/008-the-base-and-the-library.md)
- The phase table from issue 601

## Still open

**Is a library falling the only way a match can end?** There is no time limit, no
draw condition other than the simultaneous one, and no surrender. Three surges is
a finite structure, so a match that survives all three has no escalation left in
it and could in principle grind forever. Something probably needs to happen after
the third challenge, and nothing in the vision says what.
