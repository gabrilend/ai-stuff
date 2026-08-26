# 108 -- A world writes itself down

**Phase:** 1, the world holds still
**Blocked by:** [107](107-the-validator-refuses-to-guess.md)
**Blocks:** [306](306-the-command-log-is-the-replay.md), rollback in phase 3,
phase 8's generator output, and every session that ever ends.
**Documents:** [the world and its tick](../docs/004-the-world-and-its-tick.md),
[the turn is a transaction](../docs/019-the-turn-is-a-transaction.md)

## Current behaviour

Nothing exists.

## Intended behaviour

Write a world to a file; read it back; get something byte-identical.

Because every reference in the world is an index and nothing is a pointer, this is
almost the whole job: write a header, then write each block's bytes. There is no
per-type serialiser, no pointer translation, and no graph walk. That is the payoff
of [102](102-the-world-is-flat-arrays.md), and it is worth stating plainly because
it looks like luck and is not.

### This is a long-lived format, and that changes everything about it

**The world persists between sessions.** A session ends by writing the world out,
and the next one loads it. The tavern the players burned down is still burned next
week.

That single decision turns this file from a debugging convenience into a format
with obligations that never go away:

- **Every file carries a version, and a mismatch is refused in words** naming both
  versions. Not "failed to load" -- a sentence saying which version the file is and
  which this build speaks.
- **Every change to a record's shape needs a migration.** Adding one field to the
  thing record in phase 6 means writing a converter for every world file anybody
  already has. That cost is paid on every future change to the data model, forever.
- **The migration path is a chain, not a special case per pair.** Version 3 to
  version 7 is four converters run in sequence, not a converter written for that
  particular jump. Otherwise the number of converters grows as the square of the
  number of versions.

**The version story has to be in this file from the beginning.** It cannot be
added later, because the first world file saved without one is the first world
file that cannot be migrated. This is the whole reason this issue is not simply
"write some bytes".

### Rollback wants it fast, not just correct

Phase 3 takes a snapshot at the head of every turn and keeps a ring of them. That
makes writing a world something that happens constantly during play rather than
once at the end, so the in-memory snapshot path should not go through the file
writer's field-by-field encoding. Two paths, same data:

| Path | Used for | Shape |
| --- | --- | --- |
| **In-memory snapshot** | Rollback's ring | Copy the blocks. No encoding, no endianness, no field walk. It never leaves this process. |
| **File** | Between sessions, and generator output | Field by field, little-endian, versioned. |

Keeping them separate is what lets the fast one stay a memcpy.

### The header

| Field | Type | Meaning |
| --- | --- | --- |
| `magic` | `uint32_t` | Fixed. A file not beginning with it is refused immediately. |
| `version` | `uint32_t` | Format version. Mismatch refused in words naming both. |
| `scale` | `uint32_t` | The fixed-point scale from [101](101-the-arithmetic-is-integers.md), so a world written at a different scale is refused rather than silently misread. |
| per-block counts | `uint32_t` each | How many records in each block. |
| `hash` | `uint64_t` | Over everything after the header. The same hash [307](307-the-world-hashes-itself.md) uses for determinism checking -- one function, two uses. |

### Endianness and padding

Both are ways this quietly breaks between machines.

**Padding:** records are written field by field, never by dumping the struct, so
that a compiler's choice of padding never reaches the file. Dumping the struct is
faster and is how a file becomes unreadable on the next compiler.

**Endianness:** the file is little-endian and a big-endian reader swaps. This costs
nothing on any machine anybody will run this on, and removes a category of bug.

## Suggested implementation steps

1. Write the header, then a writer and a reader per block, field by field.
2. Build the version machinery **now**: a version constant, a refusal that names
   both versions, and an empty chain of converters with the place for the first one
   already visible. An empty chain that exists is a chain somebody will extend; a
   chain that does not exist is a chain somebody will work around.
3. Write the in-memory snapshot path separately, as a block copy.
4. Run the validator from [107](107-the-validator-refuses-to-guess.md) after every
   read, always. A file that parsed is not a file that is valid.
5. Refuse a truncated file by comparing bytes-remaining against the header's counts
   before reading anything, rather than discovering it partway through.
6. Write the companion `.info.md`.
7. Test the round trip: generate, write, read, write again, compare byte for byte.
   That test is the specification and it is what the phase 1 demo shows.
8. Test refusal: wrong magic, wrong version, wrong scale, truncated, corrupted body
   behind a good header.
9. Test the snapshot path against the file path -- snapshot a world, write both to
   files, and assert they describe the same world. Two paths that can disagree will.
