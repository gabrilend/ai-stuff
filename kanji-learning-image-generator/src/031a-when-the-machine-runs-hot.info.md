# 031a-when-the-machine-runs-hot — info

Reads the processor's temperature and rests when it is climbing.

For a general: making six thousand pictures is several minutes of every core on the machine at full load, and sustained full load is what heats a chip. Nothing here is going to damage anything -- a processor throttles itself long before that, and the limits it reports have that margin built in -- but heat is wear, and wear is worth not spending for no reason.

Three things are done about it and only the last is really about heat. Leaving cores free keeps the machine usable. Asking politely means anything else on the machine goes first. And resting between characters when the temperature climbs is a duty cycle, which genuinely lowers the sustained temperature rather than moving it somewhere else: brief regular idleness is how a chip sheds what it has built up.

Numbered to sit beside `031` rather than after it, because it is that file's governor and not a step of its own.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `031a-when-the-machine-runs-hot.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.rest(seconds)` | Stop running for a while. |
| `M.source()` | Where this machine says how hot it is, or nil. |
| `M.temperature()` | How hot the processor is, in degrees, or nil. |
| `M.workers(settings)` | How many workers to run, and why that many. |
| `M.governor(settings)` | Something to call between units of work that rests when the machine is hot. |
| `M.nice_prefix(settings)` | The words that put a worker at the back of the queue. |

### `M.source()`

Where this machine says how hot it is, or nil.

The kernel exposes thermal zones under a known path, and the useful one is not reliably the first -- a laptop may report its battery and its wireless card alongside its processor. The zone is found by what it says it is.

Looked for once. A machine with no thermal zone is not going to grow one during a run, and checking every few seconds would be its own small waste.

### `M.temperature()`

How hot the processor is, in degrees, or nil.

The kernel reports thousandths of a degree.

### `M.workers(settings)`

How many workers to run, and why that many.

Processors minus a reserve, under a ceiling, never below one. Taking every core is what makes a machine unresponsive while a batch runs, and the last two cores buy far more comfort than they buy speed.

### `M.governor(settings)`

Something to call between units of work that rests when the machine is hot.

Returns nil when this machine will not say how hot it is. That is deliberate: resting on a fixed schedule to guard against a temperature nobody measured is a slower run bought for nothing, and doing it silently would be worse than not doing it at all.

### `M.nice_prefix(settings)`

The words that put a worker at the back of the queue.

This does not make the machine cooler -- a busy core is a busy core -- but it means a run that is heating the processor never also makes the machine feel broken to whoever is using it.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `self.consider()` | One unit of work has finished. Rest if the machine wants it. |
| `self.report()` |  |
| `main(argv)` | Run directly, this just says what it can see. |

## Where it sits

Used by `031-make-them-all`, `035-test-the-machine`, `044-run-the-pictures`.
