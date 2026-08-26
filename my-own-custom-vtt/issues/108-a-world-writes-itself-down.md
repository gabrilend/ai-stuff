# 108 -- A world writes itself down

**Phase:** 1, the world holds still
**Blocked by:** [107](107-the-validator-refuses-to-guess.md)
**Blocks:** [306](306-the-command-log-is-the-replay.md), and phase 8's generator
output.
**Documents:** [the world and its tick](../docs/004-the-world-and-its-tick.md)
**Open questions:** [1.2](../docs/016-open-questions.md) -- does anything persist
between sessions? If yes, this format becomes long-lived and needs a versioning
story it does not currently have.

## Current behaviour

Nothing exists.

## Intended behaviour

Write a world to a file; read it back; get something byte-identical.

Because every reference in the world is an index and nothing is a pointer, this
is almost the whole job: write a header, then write each block's bytes. There is
no per-type serialiser, no pointer translation, and no graph walk.

That is the payoff of the decision in
[102](102-the-world-is-flat-arrays.md), and it is worth stating plainly because
it is the sort of thing that looks like luck and is not.

### The header

| Field | Type | Meaning |
| --- | --- | --- |
| `magic` | `uint32_t` | Fixed. A file that does not begin with it is refused immediately. |
| `version` | `uint32_t` | Format version. A mismatch is refused in words naming both versions. |
| `scale` | `uint32_t` | The fixed-point scale from [101](101-the-arithmetic-is-integers.md). Written down so that a world made under a different scale is refused rather than silently misread. |
| per-block counts | `uint32_t` each | How many records in each block. |
| `hash` | `uint64_t` | Over everything after the header. |

### Endianness and padding

Both are ways this quietly breaks between machines.

**Padding:** the records are written field by field, not by dumping the struct,
so that a compiler's choice of padding never reaches the file. Dumping the struct
is faster and is how a file becomes unreadable on the next compiler.

**Endianness:** the file is little-endian, and a big-endian reader swaps. This
costs nothing on every machine anybody will run this on and removes a category of
bug from the list.

### The hash is the same hash the tick uses

The world hash that [307](307-the-world-hashes-itself.md) computes for determinism
checking is the same function used here. One hash, two uses: "did this file
survive the disk" and "did this replay reproduce the session".

## Suggested implementation steps

1. Write the header, then a writer and a reader per block, field by field.
2. Run the validator from [107](107-the-validator-refuses-to-guess.md) after
   reading, always. A file that parsed is not a file that is valid.
3. Refuse a truncated file by comparing bytes-remaining against the counts in the
   header before reading anything, rather than discovering it partway through.
4. Write the companion `.info.md`.
5. Test the round trip: generate a world, write, read, write again, compare the
   two files byte for byte. That test is the entire specification of this file
   and it is the one the phase 1 demo shows.
6. Test refusal: wrong magic, wrong version, wrong scale, truncated, corrupted
   body with a good header.
