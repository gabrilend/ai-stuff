# 904 — A Scene Exists Only Where Something Changed

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 903 |
| Blocks | — |
| Reads | [the scene](../docs/010-the-scene.md) |
| Open questions | — |

## Current behavior

Every actor in every block at every hour forms a gathering, and every gathering
could become a scene. That is an unusable number of records and an unpayable number
of narrations.

## Intended behavior

**A scene exists where something changed.** A gathering that moves no axis and
strikes no spark produced nothing, needs no record, and gets no words.

The test is free, because [903](903-what-changed-is-computed-first.md) has already
computed `changed` by the time the question is asked. If it is empty and no spark
occurred, the gathering is discarded.

### Most of the city produces nothing, and that is correct

Most hours in most blocks will move nothing at all. That is not a shortfall in the
simulation — it is what an ordinary day is, and the vision insists on ordinary:

> right now, people just sorta live their lives. there's no great war, no pending
> disaster. life is normal

A design that manufactured a scene per gathering would be claiming something
happened everywhere, all the time, which is the opposite of what this city is.

### It also bounds the cost of the words

Narration is the only expensive thing in this project — see
[907](907-the-narrator-is-a-viewer.md) and question 20 on where it runs. This rule
is what keeps that cost proportional to how much actually happened rather than to
the size of the city times the hours in a day.

### What it costs

A person's day contains long stretches with no record at all. Anything that wants
to show "what somebody did today" cannot read it off the scenes, because most of
the day left none. Whereabouts already answers that question — see
[703](703-whereabouts-is-a-function.md) — so nothing needs the gaps filled, but
somebody will eventually be tempted to fill them.

## Suggested implementation steps

1. After the arithmetic, discard any gathering with an empty `changed` and no
   spark. Do not build a record for it.
2. Report the proportion of gatherings that survive, per day, so the ratio is a
   measured number rather than an assumption.
3. Never emit an empty scene as a placeholder. A missing scene is a nothing that
   happened, not a gap to be filled.
4. Test that a city of closed actors in closed rooms produces zero scenes across a
   full day.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [903 — what changed is computed first](903-what-changed-is-computed-first.md)
- [703 — whereabouts is a function](703-whereabouts-is-a-function.md) — what answers the day's gaps instead
