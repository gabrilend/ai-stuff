# 105 — The record arrays

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | [106](106-the-world-table.md), phase 3 entirely, phase 7 entirely |
| Blocked by | [104](104-the-string-run.md) |
| Related docs | [file formats](../docs/dominions-file-formats.md), [the reading](../docs/datapath-the-reading.md) |

## Current behavior

After the header's string run, a savegame is an undifferentiated stretch of
binary with readable names scattered through it. Nothing in the project can say
where one record ends and the next begins.

What is established: the tail of an orders file is a **fixed-stride array whose
only text field is a name**. The stride was measured rather than eyeballed —
and the measurement disagreed with the eyeball by three bytes, because raw zero
padding reveals as the capital letter `O` and a naive scan swallowed it into
every name. Across three savegames from different games and versions the same
stride appears, and in one game the pattern runs unbroken for forty-seven
consecutive records. The names recovered from the tail of a Pangaean save are
that nation's officers.

What is **not** established: which byte inside a record holds anything at all
besides the name.

## Intended behavior

A module that finds record arrays by measuring, reports what it found, and
refuses to interpret what it has not established.

### Finding an array

The method is the one that already worked, made into a tool rather than a
probe:

1. find every name-shaped string terminated by the separator
2. for each neighbouring pair, compute the gap between them once the earlier
   name's own length is subtracted
3. tally the gaps

A fixed-stride array shows up as one gap with a large count. Noise shows up as
a scatter of gaps each occurring once. The longest unbroken run at the dominant
gap is the array, and its first and last offsets bound it.

**This is a measurement, not a constant.** The stride is not written into the
source as a number. It is found per file, every time, and a file whose stride
disagrees with the collection's usual one is interesting rather than broken —
that is exactly how a format change in a new game version would announce
itself, and hard-coding the number is how it would instead announce itself as
silent corruption.

### What comes back

For each record: its offset, its length, its name, and **its raw bytes**.

The raw bytes are kept deliberately. Phase 7 will need to change fields inside
these records without disturbing what surrounds them, and the difference
experiments that establish where those fields live need the original bytes to
compare against. Keeping them costs memory and buys the whole of the hardest
phase.

### `unplaced` is the honest output

Everything between the string run and the record array — province records with
their doubled names and their event histories, and whatever else is in there —
is recognised as present and not understood.

It is returned as `unplaced`, with offsets and bytes, rather than dropped. This
costs a little memory and buys two things: the survey can report what fraction
of a file is currently understood, which is the only honest measure of progress
on this format; and when a field is worked out, the bytes to test it against
are already in hand rather than needing another pass over the collection.

## Suggested implementation steps

1. Write the name-shaped-string finder, with the padding ambiguity resolved
   explicitly and the resolution commented.
2. Write the gap tally and the dominant-gap selection. Return the whole tally,
   not just the winner — a file with two competing strides has two arrays, and
   flattening that to one number loses it.
3. Find the longest unbroken run at the dominant gap and bound it.
4. Slice the run into records, each with offset, length, name and raw bytes.
5. Mark everything outside the run as `unplaced`, in spans, with offsets.
6. Report the fraction of the file that fell into a recognised array.
7. Tests: the stride found in a known save matches the one found by hand; the
   names recovered from a Pangaean save are that nation's officers; running
   over the whole collection produces a stride per file, and the distribution of
   strides is reported rather than asserted; a file with no array says so
   instead of inventing one.
8. Write the accompanying information file.

## Relevant files

- the local savegame collection, in full — the distribution across a hundred
  files is the finding, not any single file
- the stride probe written during investigation, which is superseded by the
  test in step 7 and need not be preserved

## Open questions

- Are the names at the tail of every orders file commanders, or is that
  confirmed only for the Pangaean save where the names were recognisable? In one
  other game the tail names include words like *Whitewood* and *Butterfly*,
  which could as easily be provinces. This needs settling before anything calls
  the array a cast list.
- Province records also appear to be regular, but with the name stored twice.
  Whether they are fixed-stride is unmeasured — the event history attached to
  each one may make them variable-length.
- Do the strides differ between game versions? Two versions were sampled and
  agreed. That is two.
