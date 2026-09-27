# What every measured number means

Every number on the metrics pages comes from a test or a demo program
run on the laptop twin (issue 200), written by the program as it ran and
gathered when the pages were built. None is typed in by hand. To get
current numbers, run `scripts/build-docs --measure`, which runs every
test and every demo first; `scripts/test-twin` alone refreshes the test
numbers.

**These are laptop numbers.** The twin runs the same engine code the
kernel runs, but on a laptop's cores, caches and operating system. A
ratio (four cores against one, a cost against a unit of work) travels to
the device far better than an absolute time does, and every section
below says which kind of number it is. The device's own numbers wait on
issues 201 and 202.

Each section: what the number is, how it is measured, what a healthy
value looks like, and what it says about the design.

## Memory each core owns

The page allocator (issue 203) gives every core its own stripes of the
page bitmap — one cache line of bitmap, 512 pages, per stripe — so
allocating never meets another core.

### Allocate-and-free cost {#stripes-pair-cost}

The time for one page to be allocated and freed again, measured by
`twin/tests/048-test-memory-each-core-owns.c` twice: with one core
allocating and three idle, then with all four allocating at once. It is
an absolute laptop time; its use is the comparison between the two
numbers, which is the next entry.

### Four cores against one {#stripes-contention}

The four-core cost per pair divided by the one-core cost. **1.0 means
nothing is shared**: four cores allocating at once each pay exactly what
one pays alone, which is the whole promise of striping. A number well
above 1 would mean two cores' bitmap bits were landing in one cache line
(false sharing) — the stripe width would be wrong, and issue 203 says
the measurement is how that would be found.

### Pages handed back {#stripes-foreign-free}

Pages freed by a core that did not own them, routed home through the
owner's returns list rather than written into the owner's bitmap line.
The churn test hands a quarter of its pages to a neighbour on purpose, so
this number being large is the path being exercised, not a problem. The
companion number is pages freed by their own owner, which need no hand-back.

### Stripes taken after startup {#stripes-taking}

Stripes an owner claimed from the unowned pool because its own ran dry.
Each owner starts with a quarter of the pool dealt out; a busy run that
takes more is the on-demand half of issue 203's answer at work. Zero in a
short test is normal.

### The churn {#stripes-churn}

The whole allocator test's wall time and total allocations, for
orientation rather than judgement.

## The task ring

One ring of task pointers shared by every core, under a ticket spin lock
(issue 204). It is the single most contended thing in the engine by
construction, which is why issue 204 asked for it to be measured before
anybody redesigned it.

### Push and pop cost {#ring-cost}

`049-test-task-ring.c`: four cores each push and pop 250,000 times at
once; the number is wall time per push-and-pop. A laptop time; compare
across runs, not with the device.

### Most tasks waiting {#ring-high-water}

The deepest the ring got during a run. In the ring test it is a measure
of how far producers ran ahead of consumers; in the endurance demo
(below) it is the answer to "is the program falling behind?" — a
high-water mark that keeps climbing over a long run is a program the
cores cannot keep up with.

### Doublings {#ring-growth}

How many times the ring replaced itself with one twice the size. It
starts at eight slots, so a handful of doublings is normal on first use;
the number should then stay put.

## Workers and the run loop

### Spread across cores {#workers-spread}

In `051-test-workers-and-delivery.c`, 2,000 heavy runs are queued at
once and every core takes some. The number is the least-busy core's runs
divided by the busiest core's. **1.0 is perfectly even.** Anything above
about 0.5 means no core is starving; a much lower number with work
waiting would mean the ring or the waking is unfair (issue 205 says the
worker knows nothing about boxes precisely so that it cannot be).

### Throughput of heavy runs {#workers-throughput}

Runs per second of a box doing 20,000 rounds of mixing work — work-bound,
so it mostly measures the laptop.

### Parking between values {#workers-parking}

Values are fed 5 ms apart; the number is how many times a core parked
per value. It must be at least one: a core that never parks between
values 5 ms apart is spinning, which is the battery-draining behaviour
issue 206 exists to prevent.

## Ports and stations

### Starting depth {#ports-depth}

How many 8-byte values one port page holds: a port starts as deep as one
page, as issue 208 proposed, rather than at a fixed ten.

### Growth under imbalance {#ports-growth}

A two-input station fed 5,000 values on one side and none on the other:
the pages its port added. The test checks the number exactly against
the imbalance (values waiting ÷ values per page, minus the first page),
because a port that keeps growing is a signal — one input fed faster
than its sibling — and the count has to be trustworthy to be a signal.

### Places in the table {#stations-table}

Places in the station table at the end of the station test, free ones
included. For orientation.

### The scrapyard {#scrapyard}

Retired things (replaced wire lists, removed stations) that the sweep has
freed, and those still waiting for every core to move past them. Waiting
items at the end of a test are ones retired by the last few calls; a
number that grows without bound over a long run would be a leak.

## The claim

### Pairs per second {#claim-throughput}

Four cores spray 200,000 values into both inputs of one adder; the
number is complete pairs claimed and run per second. The test around it
checks the property that matters more than the speed: runs equal
complete pairs exactly, and none is left sitting unrun.

### Checks handed over {#claim-merging}

The fraction of readiness checks a core handed to another core already
checking the same station (issue 209's addition, which closes a
lost-set race). A high fraction under a hammering test is expected; it
is the mechanism working, with nobody waiting.

## The endurance run

`twin/programs/059-endurance.c` (issue 215), run for a number of seconds
on four cores and on one by the phase 2 demo. Each value fans out to one
chain of 24 increment stations per core and back to a counting sink;
halfway through the whole program is parked and restarted; a box refuses
a value and is put back into service; one station is fed unevenly.

### Runs per second {#endurance-throughput}

Box runs completed per second across the whole program. Engine-bound:
the boxes do almost nothing, so this is the engine's own speed on the
laptop.

### Four cores against one {#endurance-speedup}

Four-core runs per second divided by one-core runs per second. **Four
would be perfect scaling.** The measured number is about two, which is
the answer to issue 204's first open question: with every run going
through one shared ring, the ring's lock is the ceiling on engine-bound
work. Work-bound programs (boxes that do real work per run) scale much
further, because they touch the ring less often per unit of work. The
coarseness calculator on the metrics page shows the trade.

### What one run costs {#endurance-run-cost}

Core time per run of a box that does nothing at all (a chain of `pass`
boxes), and core time per round of `chew`'s mixing work. The first is the
engine's price for one run; the second is a unit of real work to
measure it against.

### How coarse a box should be {#endurance-coarseness}

The first divided by the second: how many rounds of real work a box must
do per run before the work costs as much as the engine does. **This is
the design rule issue 215 was built to produce**: a box doing less work
than this per run spends more of its time being scheduled than working,
and should be merged with its neighbour. The two arrangement times (the
same total work as one big box, and as 64 small ones) are shown beside
it.

### The arithmetic {#endurance-arithmetic}

Values pumped in, and whether the sink's count and sum matched the
closed-form expectation exactly — every value arrives once per chain,
plus 24 from the chain, minus exactly the values the picky box refused.
A count too low is a lost value; too high a doubled one; right count and
wrong sum a torn copy. These must be true, every run.

### Spread across cores {#endurance-spread}

As for the workers test, over the whole endurance run.

### Growth under imbalance {#endurance-growth}

Pages added by the station fed four values on one input for every one on
the other; checked against the number of unmatched values waiting.

### Memory after warm-up {#endurance-memory}

Free pages lost between a quarter of the way through and the end. The
uneven station is made to hold unmatched values on purpose, so its pages
are allowed for; beyond that, a number that keeps growing with the
length of the run is a leak.

### Ring depth {#endurance-ring}

The ring's high-water mark over the run.

### Draining {#endurance-drain}

Time for everything in flight to finish after the pump stopped.

### The verdict {#endurance-verdict}

Every check above passed.

## Choosing an exit

### Random, against even {#kinds-random}

40,000 values through a random station with four exits; the number is
the largest distance of any exit's share from an even quarter, in
percent. A few percent is expected chance; a large number would be a
biased picker (issue 308).

### Spread, against a slow destination {#kinds-spread}

Values through a spread station with one slow destination and one quick
one; the number is the quick one's share. Above one half means spread
sees the slow one falling behind — which, as issue 308 now records, it
only did once it counted queued runs as well as waiting values.

## A program written down

### The nine scenes {#written-down-scenes}

The phase 3 demo (issue 312): each scene passes or fails — the round trip,
the catalogue refusal, both ends of a wire, the wire check, all problems
at once, the counter, every exit kind, a map inside a map, and a box
taking itself out.

## Tests

### Test results {#tests-results}

Every test program under `twin/tests/`, its checks passed and failed, as
of the last `scripts/test-twin`. Each test's own page (from the source
reference) says what it checks, in its opening description.
