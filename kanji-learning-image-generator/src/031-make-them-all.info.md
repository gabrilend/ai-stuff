# 031-make-them-all — info

Every character in a chosen set, made at once, with a report at the end that says what happened to all of them.

For a general: this is the point of the project. Everything before it makes one recipe. This makes all of them, and makes them without a person choosing which -- which is the whole difference between a demonstration and a learning material.

Add --out DIR to put the set somewhere other than the RAM scratch area.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `031-make-them-all.lua` and
run the sweep again.*

## Invocation

```
luajit src/031-make-them-all.lua --grade 1
luajit src/031-make-them-all.lua --jlpt 5 --workers 8
luajit src/031-make-them-all.lua --frequent 500
luajit src/031-make-them-all.lua --chars 木火水
luajit src/031-make-them-all.lua --all
luajit src/031-make-them-all.lua --phrase 時間=time,an hour
luajit src/031-make-them-all.lua --phrases
```

## What it offers

| | |
|---|---|
| `M.processors(settings)` | How many workers this machine should run. |
| `M.shard(chosen, index, howmany)` | One worker's share of the set. |
| `M.work(chosen, store, settings, options)` | One worker's actual job: make its characters, write down what happened. |
| `M.write_shard_report(report, path)` | A worker's findings, as flat lines for the parent to read. |
| `M.read_shard_reports(paths)` | Every worker's findings, added up. |
| `M.describe(total, elapsed, out_dir, settings)` | The run, as lines of text. |

### `M.processors(settings)`

How many workers this machine should run.

Not simply how many processors it has. Taking every core is what makes a machine unresponsive while a batch runs and holds the processor at the top of its thermal range for as long as the run takes -- and the last two cores buy far more comfort than they buy speed. `031a` works out the number and explains the reserve.

### `M.shard(chosen, index, howmany)`

One worker's share of the set.

Strided rather than blocked: taking every nth character means a worker that happens to draw several very crowded characters does not become the one everybody else waits for. Blocks would hand one worker a run of neighbouring characters, and neighbouring characters are related, so their costs are related too.

### `M.work(chosen, store, settings, options)`

One worker's actual job: make its characters, write down what happened.

A character that fails, fails alone. One malformed path must not end a run -- it is recorded with its reason and the batch goes on. A run that stops on character four hundred of six thousand has wasted the four hundred.

### `M.write_shard_report(report, path)`

A worker's findings, as flat lines for the parent to read.

Through a file rather than through what the worker prints, because several workers printing at once interleave, and parsing that would mean writing a parser for a format nobody designed. The file lives in the RAM tier.

### `M.describe(total, elapsed, out_dir, settings)`

The run, as lines of text.

Not decoration. This is the only view anybody has of what a run over six thousand characters did, and every line of it is a gap being announced -- a run that quietly produced five thousand images out of six thousand asked for is a run that looks like a success.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `shell_quote(text)` |  |
| `selection_arguments(options)` | The part of this run's command line that says which characters. |
| `main(argv)` |  |

## Where it sits

Used by `032-a-gallery-you-can-page`.
