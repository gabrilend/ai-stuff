# 103 — The header without the file

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | [107](107-the-survey.md), and anything that needs a turn number |
| Blocked by | [102](102-seeing-through-the-disguise.md) |
| Related docs | [file formats](../docs/dominions-file-formats.md) |

## Current behavior

Nothing reads a Dominions header. The turn number, the game version and the
file's own identity as a Dominions file are all sitting in the first sixteen
bytes of every savegame file and none of them are readable by this project.

## Intended behavior

Four questions, answered from the first sixteen bytes, without reading the rest
of the file.

| Question | Field | Returns |
|---|---|---|
| Is this a Dominions file? | the `DOM` signature at a fixed offset, stored plainly | yes or no |
| What version wrote it? | version × 100, little-endian | `{major, minor}` |
| What turn is it on? | little-endian integer | a number |
| Which kind of file is it? | the filename | world state, turn, or orders |

The signature is validated **before** any offset is trusted. A file that is not
a Dominions file is refused, not misread — every other field in this table is
read from a fixed position, and fixed positions in a file of the wrong kind
produce numbers that look real.

### Why "without reading the rest" is a requirement and not a nicety

The turn number lives in the first handful of bytes. The files it lives in run
to millions of bytes each, and there are over a hundred savegames in the local
collection.

Answering "what turn is each of these games on" by reading whole files means
reading gigabytes to print a column of small integers. Answering it by reading
sixteen bytes each means the survey finishes while you are still looking at it.
So the reader has two entrances: a header read that opens, takes a few bytes,
and closes; and a full read that is separate, explicit, and expensive.

### Refusing rather than defaulting

There are three distinct situations and they must stay distinct:

| Situation | Answer |
|---|---|
| a started game | a turn number |
| a savegame awaiting pretender submissions | no world state file, therefore no turn — a legitimate condition |
| a damaged or truncated file | an error naming what was wrong |

None of them is "turn zero", which is not a thing that exists. A reader that
returns zero for the second and third cases has destroyed the difference
between a game that has not begun and a file that is broken.

## Suggested implementation steps

1. Read the first sixteen bytes. One `io.open`, one bounded read, one close.
2. Check the signature. Refuse with a stated reason if it is absent.
3. Read the version and turn as little-endian integers at their offsets, and
   comment each offset with how it was established.
4. Convert the version to major and minor, and do not hide the fact that it
   records the version that last *wrote* the file rather than the one that
   created the game.
5. Classify the file by its name — world state, turn, orders — since nothing
   found so far inside a turn file identifies its nation.
6. Tests, run against the whole local collection: every started save yields a
   turn in a plausible range; every version recovered is a real published
   Dominions version; older saves report older versions; a pretender file
   reports turn zero and is classified as such; a `.map` file is refused.
7. Write the accompanying information file.

## Relevant files

- the local savegame collection — a hundred-odd folders spanning several
  versions, which is the only test worth having here
- `dom6fileformats.pdf` in the Dominions folder, which covers the map format
  and says nothing about savegames — worth knowing so nobody looks twice

## Open questions

- Bytes `0x06` to `0x09` are consistent across observed files and unexplained.
  They may be a build identifier or a checksum. Not needed yet; worth naming so
  the gap is visible.
