# 1007 -- Handing it to a friend

**Phase:** 10, the engraving
**Blocked by:** [1006](1006-intentionally-fragile.md)
**Blocks:** [1009](1009-the-phase-ten-demo.md)
**Documents:** [the record log is an engraving](../docs/018-the-record-log-is-an-engraving.md)

## Current behaviour

**Done.** `./share-engraving`, with the project root hard-coded and overridable as
the first argument.

| Mode | Does |
| --- | --- |
| `<engraving> <destination>` | validates, then copies |
| `--print <engraving>` | validates, then prints, so it can be piped or pasted with no file at the other end |
| `--list` | every engraving there is, each named by its animal — and marked DAMAGED if it no longer reads |

It builds the reader from source if there is not one, because a script that
validates with a stale binary is a script that blesses a broken file.

It **refuses to overwrite**. A record log that gets overwritten is a record log
that is gone, and this format cannot be repaired.

The listing runs the reader on every file rather than listing filenames, because a
listing that cannot tell a carving from a damaged one is not answering the only
question worth asking.

## Intended behaviour

A third script, pointing sideways rather than in either direction of the pair.

**It hands an engraving to somebody else.** This is a small thing to build and it
is the reason the format is text and the reason it is one file: the whole record
of a session is something you can paste to a friend, and they can look at it
before they run anything, because it is a picture of a dragon with numbers in it.

### What it does

| Step | Why |
| --- | --- |
| Reads the engraving and refuses a damaged one. | Handing somebody a broken carving wastes both people's time, and the reader already knows how to tell. |
| Copies it somewhere durable. | The RAM tier is the wrong place for the one artifact meant to outlive the machine. |
| Prints it to standard output on request. | So it can be piped, pasted, or dropped into a message without a file ever existing. |

### It is the answer to the fragility

A format that cannot be repaired needs to be easy to copy. That is the trade, and
the script is the other half of it.

## Suggested implementation steps

1. A shell script, taking an engraving and a destination, with the project root
   hard-coded and overridable as an argument.
2. Validate before copying, by running the reader.
3. A mode that prints rather than copies.
4. A mode that lists the engravings that exist.
