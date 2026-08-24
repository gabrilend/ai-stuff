# 805 — A Full Match, End to End

| | |
| --- | --- |
| Phase | 8 — Six Players |
| Blocked by | 307, 509, 608, 704, 705, 801, 802, 803, 804 |
| Blocks | — |
| Reads | [what this game is](../docs/001-what-this-game-is.md), [roadmap](../docs/019-roadmap.md) |
| Open questions | all of them |

## Current behavior

Every system has been built and tested on its own, and several have been watched
running together. **Nobody has played a whole match.** There is no evidence that
the eight phases hold up simultaneously, under six people, on six machines, for
the length of a real game.

## Intended behavior

Six people, two teams of three, one match from lobby to library, played on
separate machines, watched through the real viewer, recorded as a replay, and
replayed afterward to an identical result.

Every system in every phase, at once, doing its actual job.

## What it has to demonstrate

Not that the code runs. That each of the eight phases produced something that is
still doing work when everything else is also running:

| Phase | What must be visible in the match |
| --- | --- |
| 1 | The replay reproduces the match exactly. The world hash matches at every tick, on every machine. |
| 2 | Frontlines that form, hold, break, and move. Soldiers that look like they are deciding rather than colliding. |
| 3 | Towers that kill things, guards that make the ground around them dangerous, and a library that ends it. |
| 4 | Three people arguing over one chest, with locks and objections doing the arguing. |
| 5 | Two economies visibly separate — a player who spent everything on heroes and a player who never did. |
| 6 | Three surges that visibly changed the shape of the match, and three challenges that were frightening. |
| 7 | A player who was never told the rules working out that upgrades take a wave to move, by watching one crawl. |
| 8 | Six machines that never disagreed. |

## The one that matters

> **Did the frontline move?**

The whole project is an answer to a question the vision asks in its first
paragraph: take a lane-pusher, subtract the heroes, and you get soldiers meeting
in the middle and barely moving the frontlines at all. Everything built here —
the shared chest, the two economies, the surge that takes the board apart three
times — exists to unstick that.

If six people play a full match and the lanes sit at the midpoint the whole way
through, then the design is wrong, and the right response is an issue file, not a
patch.

## Suggested implementation steps

1. Play it. Record it. Replay it.
2. Write down what happened, in prose, in `notes/`. Not metrics — issue 804 has
   metrics. What it felt like, what people said out loud, what they tried to do
   and could not, and which rule they had to be told because no refusal ever
   explained it.
3. Turn every one of those into an issue file or a line in the balance ledger.
4. Update the phase-8 progress file and every phase demo, since the demos are
   part of what this project delivers and a match that revealed something should
   change what they show.
5. Go back to [open questions](../docs/020-open-questions.md) and settle
   everything the match answered. Several of them can only be answered by playing.

## Related documents and tools

- [What this game is](../docs/001-what-this-game-is.md)
- [The roadmap](../docs/019-roadmap.md)
- [Open questions](../docs/020-open-questions.md)
