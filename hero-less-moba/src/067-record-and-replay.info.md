# 067-record-and-replay

Runs a match writing a replay, or plays one back and reports.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The third runner, alongside the headless one in `044-headless-runner` and the gate
in `063-the-gate`. Those answer "how did a match go" and "what does this exact
moment look like". This one answers a question neither can: **did the same match
happen twice.**

Two verbs in one file rather than two files, deliberately. The pair only means
anything together — a recorder nobody plays back is a recorder nobody knows is
broken, which is precisely the state the first version of the keyframe correction
was in for as long as it existed.

## Running it

```
./run-prototype record <path> [ticks]
./run-prototype replay <path>
```

Or directly, `luajit src/067-record-and-replay.lua record <path> [ticks]`.

Both default to `/dev/shm/hero-less-moba/match.replay`, which is the RAM tier — a
replay is an ephemeral artifact and does not belong in the repository.

## What it prints

`record` reports the size of what it wrote, in bytes and in bytes per second of
play, because that is the number anybody deciding whether to keep replays needs and
it is the one most likely to change. Also the tick count, the keyframe count, the
command count, and how the match ended.

`play` reports how many keyframes the simulation reproduced exactly, and if any
disagreed, the tick of the first disagreement and how far apart the two runs got in
world units. On one machine it should reproduce the whole match. The report exists
because on two machines it will not, and knowing whether "not exact" means half a
world unit or forty is the difference between floating-point noise and a different
match.

It **refuses** a replay whose rules stamp disagrees, rather than playing it anyway.
Playing it under changed numbers produces a match that diverges within seconds and
every symptom points at the replay system rather than at the catalogue somebody
edited. It also says out loud when a file has no ending record, which means whatever
was recording stopped without closing it.

## Exports

None. This is a program, not a module — it is run, and it prints. Everything it
does is in [the replay log](066-the-replay-log.info.md); this file is the two
sentences of arithmetic that turn a report into something a person reads, and the
verb dispatch table that picks which one to run.

## Related

- [The replay log](066-the-replay-log.info.md) — everything this drives
- [Snapshots and replays](../issues/107-snapshots-and-replays.md)
- `044-headless-runner` — the other runner with no window
- `063-the-gate` — the third, which holds a described world still
