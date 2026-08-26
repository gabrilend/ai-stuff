# 035-worldfile

A world, written down, in a format that has to last — because the world persists
between sessions, so the tavern the players burned down is still burned next
week.

That turns this from a debugging convenience into a format with permanent
obligations. **The version machinery is here from the first commit**, because the
first world saved without one is the first world that cannot be moved forward.

This is the slow, careful path. The fast path — the rollback ring's snapshot at
the head of every turn — is `world_copy` in `027-world`, which copies blocks and
encodes nothing, because it never leaves the process.

## The functions

| Function | In | Out | Notes |
| --- | --- | --- | --- |
| `worldfile_write` | world, `FILE *`, `*error` | 1 / 0 | Fields one at a time, little-endian. |
| `worldfile_read` | world, `FILE *`, `*error` | 1 / 0 | **Does not validate.** A file that parsed is not a file that is valid; the caller runs `world_validate` afterwards, always. |
| `world_hash` | world | `uint64_t` | One number for a whole world. |
| `worldfile_error_describe` | error, buffer, size | the buffer | |

## The header

magic (`VTTW`), version, the fixed-point scale, six block counts, the map extent,
the tick, and the hash.

The **scale** is written down so a world made at a different fixed-point scale is
refused rather than silently misread — every coordinate would be off by a factor
of a thousand and nothing about the file would look wrong.

## Fields, never structs

Records are written one field at a time, never by dumping the struct. Dumping is
faster and is how a file becomes unreadable on the next compiler, because
whatever padding the compiler chose would end up on the disk. Little-endian
explicitly, a byte at a time, so nothing assumes alignment and a big-endian
reader gets the same numbers rather than mirrored ones.

The two-room fixture is 864 bytes in memory and 972 on disk — the file is larger
precisely because of this.

## The converter chain

A file older than this build is walked forward **one version at a time**. Version
3 to version 7 is four converters in sequence, not a converter written for that
jump — otherwise the count grows as the square of the number of versions and
nobody writes the sixteenth one.

The chain is currently empty, and it exists anyway. An empty chain that is here
is a chain somebody will extend; a chain that is not here is a chain somebody
will work around.

A file **newer** than this build is refused, naming both versions. Never "failed
to load" — a version skew's worst symptom is a message that does not say which of
the two ends to change.

## The hash

FNV-1a over the same field walk the writer uses, so the two cannot drift about
what is in a world. Fed as explicit bytes, so two builds on different byte orders
agree.

**One hash, three uses**: did this file survive the disk, did this replay
reproduce the session, do two thread counts agree. Three separate functions could
disagree about what "the same world" means.

Padding is not hashed, for the same reason it is not written.
