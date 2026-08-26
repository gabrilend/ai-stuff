# 303 — The whole alphabet at once

## Current behavior

Done. `src/031-make-them-all.lua`:

```
luajit src/031-make-them-all.lua --grade 1
luajit src/031-make-them-all.lua --frequent 500
luajit src/031-make-them-all.lua --all
```

**Workers are started by opening a pipe to each and waited for by reading each
pipe to its end.** No shell backgrounding, no chained commands, no polling — a
pipe cannot reach its end until the process writing it has finished, so reading
one is the wait.

**The report found the gaps it was built to find, on its first real run.** Ten
of the five hundred commonest characters could not be made, and they had one
cause between them: their meaning-bearing half was a piece with no entry. Three
of them shared the jade radical. Three more failed on a left-hand form of the
bank radical that has a *different Unicode number* from the one that stands
alone and looks identical — the lists held one of the two. Fixed in `023` and
`024`; all five hundred now succeed, and across the whole archive the characters
that match no world dropped from a hundred and twenty-three to thirty-five.

**How many workers is now `307`'s business**, because taking every core drove
the processor to the top of its thermal range.

## Intended behavior

**Every character in a chosen set, made in parallel, with a report at the end
that says what happened to all of them.**

This is the point of the project. Everything before it makes one recipe. This
makes all of them, and makes them without a person choosing which — which is the
difference between a demonstration and a learning material.

### Selection

The queries people actually have (`102` supplies the fields):

| | |
|---|---|
| `--grade 1` | what a six-year-old learns |
| `--jlpt 5` | the beginner exam's list |
| `--frequent 500` | the five hundred commonest in newspapers |
| `--chars 木火水` | these ones |
| `--all` | everything the join produced |

### Parallelism

**The work is split across processes, not threads.** Every character is
independent, shares nothing with any other, and writes only into its own
directory — there is no shared state to protect and no result to combine. Under
those conditions a process is a thread that cannot corrupt anything, and each one
gets its own interpreter.

A shard is a worker index and a worker count, and a worker takes the characters
whose position in the sorted set is congruent to its index. Sorted, so shards are
stable across runs; strided rather than blocked, so a shard that happens to
contain many complex characters is not one worker's problem.

The count defaults to the machine's processor count. Sequential batch processing
here would be leaving the machine mostly idle for the length of the whole
archive.

### The report

Written at the end and it is not decoration — it is the only view anyone has of
what a six-thousand-character run did:

- how many were asked for, made, and failed, with every failure named
- the biome distribution, which reveals a thin trigger list (`204`)
- the components that could not be glossed, by frequency, which is the work
  queue for the lexicon (`203`)
- characters whose archives disagreed about stroke count (`102`)
- total bytes written, and the time it took

**Every one of those is a fallback or a gap being announced.** A run that
silently produced five thousand images out of six thousand asked for is a run
that looks like a success.

## Suggested implementation steps

1. **`src/031-make-them-all.lua`** — selection, sharding, the spawn, the report.

2. **A worker reports back through a file in `tmp/shared-memory/`**, one per
   shard, which is RAM. The parent reads them once the workers exit. Parsing the
   children's standard output would mean interleaved writes and a parser for a
   format nobody designed.

3. **A failed character fails alone.** One malformed path must not end the run —
   it is recorded with its reason and the batch continues. A run that stops on
   character four hundred of six thousand has wasted the four hundred.

4. **Test with a small set at a worker count above one**, checking that every
   requested character produced a directory, that the shards partitioned the set
   exactly, and that the report's counts add up to the request. The partition test
   is the one that matters: an off-by-one in the stride silently drops or
   duplicates a character, and with six thousand of them nobody would see it.

## Related

`302` — the unit of work. `102` — the selectors. `docs/006` — why this is the
point of the phase.
