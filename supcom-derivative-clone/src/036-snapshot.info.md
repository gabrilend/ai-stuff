# 036-snapshot

Fingerprints, copies, and records the world.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Three things, all reading the world's own layout (`world.layout`) and nothing
else.

**The hash** folds, in order: the tick; then for every group in layout order its
bookkeeping scalars, a pool's stack of released ids, and each field's rows in
use (a pool to its `top`, a queue to its `count`, anything else whole); then
every counter's period, increment and next firing. Foreign arrays are folded as
the thirty-two-bit words of their memory, so a double is the two words of its
bit pattern and two doubles a bit apart hash differently. Both target machines
are little-endian, so the words agree. Text folds as its length and bytes. The
fold is `rotate_left(hash xor word, 13) * 5 + 0xe6546b64`, wrapped to 32 bits,
starting from `0x5eed5eed`.

**The copy** copies every group's bookkeeping and arrays and every counter; the
field, the rules, the parameters and the layout are never written during a match
and are shared. A copy records nothing.

**The replay** is a text log. The snapshot row fingerprints the world every
`fingerprint_every` ticks (a rule, ten by default, which the world's
parameters may set to anything from one), keeping it as `world.fingerprint` and
`world.fingerprint_tick`; while a log is being written each fingerprint goes into
it. A runner that queues a log's commands into a fresh world made the same way
and compares fingerprints at the logged ticks has replayed the match, and the
first mismatch names its tick.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `hash(world)` | a world or a copy | a whole number from 0 to 2^32 - 1 |
| `copy(world)` | a world | a snapshot in the same layout |
| `stamp(world)` | a world | a 32-bit fingerprint of the allocation parameters and every rule, keys sorted at every level |
| `record(world, path, commands)` | a world; a file path; the commands module, to write what is already queued | nothing; writes the header, and every queued command, and sets `world.record_path` |
| `note_command(world, command)` | a world being recorded; a command table | nothing; the door's hook, one command line |
| `snapshot_pass(world)` | a world | nothing; the tick's last row |
| `replay(path)` | a log's path | `{seed, stamp, rate, every, commands, hashes}`, `commands` the command tables in accepted order and `hashes` the `{tick, hash}` pairs in order; refuses another format, or a line that is none of these, naming the file and line |

## Data structures it owns

The log's lines:

    supcom-derivative-clone replay 1
    seed <seed>
    stamp <eight hex digits>
    rate <ticks per second>
    every <ticks between fingerprints>
    command tick=<t> verb=<name> team=<n> player=<n> <argument>=<value> ...
    hash <tick> <eight hex digits>

The first five lines are the header, in that order. Command lines follow in the
order the door accepted them, arguments sorted by name, numbers written with
seventeen significant digits so they read back to the same bits. A hash line is
the fingerprint the snapshot row took during that tick.
