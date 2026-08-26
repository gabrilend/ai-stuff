# 802 — The line to the drives

Produces `src/057-storage-line-physical.md`.

## Current behavior

**Done.** `src/057-storage-line-physical.md` exists, opening with the sentence
that sets the standard for everything in it: after the load, no weight a face
reads comes from a drive.

The drive count is presented as a **deployment table with a load time attached**
rather than a requirement — sixteen a line gives tens of milliseconds, one a line
gives seconds, and against a machine that then runs for weeks the difference is
nothing.

Seven constraints. One of them failed and produced a real correction: **the lines
draw fifty-one watts while loading against a ten watt port allocation.** They do
not fit in the steady budget and should not have to; the budget now carries a
transient allowance, and both bursts that break the steady figure — a load, and a
pane — are judged as energies against thermal mass rather than powers against
coolant.

**No physical layer is named.** The blueprint says to adopt an existing standard
and does not say which, so the rate, the reach and the energy per bit are all
plausible rather than sourced.

**The controller is not designed** — the only piece of logic in this machine that
speaks somebody else's protocol.

## Intended behavior

**One storage line: its electrical layer, its cable, its fan-out to media, and the
aggregate the five or six of them produce.**

### What it is for, which bounds how good it needs to be

The storage lines exist to fill the core once. Thirty-five gigabytes at load, and
then nothing until the machine is power-cycled or the model is changed. **They are
not in the generation path at all** — every weight a face reads during a token
comes from the core, not from a drive.

That is the sentence the blueprint should open with, because it sets the standard.
A line that takes thirty milliseconds instead of six is a line nobody notices. A
line that costs an extra two hundred watts is one that everybody notices. **The
lines should be sized for cost and heat, not for speed.**

### The shape

A line is not one device. It is a fan-out: a controller on the port field, a
cable, and a shelf of drives. Sixteen drives at about sixteen gigabytes a second
gives two hundred and fifty-six per line; five populated lines give one and a
quarter terabytes a second and a thirty millisecond load.

The blueprint should show what happens with fewer: **eighty drives is a lot to ask
for**, and one drive per line — five drives total — gives a load of about seven
seconds, which is still nothing against a machine that then runs for weeks. The
drive count should be presented as a deployment choice with a load time attached,
not as a requirement.

### The electrical layer

Differential pairs on the port field's perimeter zone, through the via islands,
out to a connector. The blueprint must state the reach, the loss budget, and
whether retiming is needed, and it should prefer an existing standard over
inventing one — there is nothing about this link that is special enough to justify
a new physical layer, and an existing one comes with connectors, cables and test
equipment that exist.

### The one thing that is not ordinary

**Five lines, six slices.** A cube with an output tube has one fewer line than it
has faces. The sixth slice arrives over another line and is relayed through the
core, which costs a fifth more load time and nothing else. The blueprint must
specify that relay path, because it is the only case where a storage line's data
is destined for a face other than its own.

## Symbols this must publish

Pairs per line, rate per pair, line bandwidth. Drives per line and per drive rate.
Aggregate at each populated-line count. Load time against drive count. Reach, loss
budget, retiming requirement. Connector type. Relay path bandwidth and its cost.
Power per line.

## Constraints this must assert

- Aggregate line bandwidth times load time equals the resident model size from
  `1104`.
- Line bandwidth is under what the drives behind it can supply, so the line is not
  specified faster than it can ever run.
- Pair count fits the perimeter zone in `801`.
- Line power is within `301`'s port field allocation.
- Load time at the minimum sensible drive count is stated, and is under a stated
  ceiling.

## Suggested implementation steps

1. Open with the load-once argument, because it justifies every relaxation that
   follows.
2. Choose an existing physical layer rather than specifying one.
3. Present the drive count as a deployment table with load times.
4. Specify the relay path for the sixth slice.

## Blocks

`803`, `806`, `1302`.

## Blocked by

`801`, `1104`.

## Related documents

`004` for the first leg of a weight's journey. `008` entry 4.
