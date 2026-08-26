# 1006 -- Intentionally fragile, and the argument for it

**Phase:** 10, the engraving
**Blocked by:** [1005](1005-the-reader-reads-the-picture.md)
**Blocks:** [1009](1009-the-phase-ten-demo.md)
**Documents:** [the record log is an engraving](../../docs/018-the-record-log-is-an-engraving.md)

## Current behaviour

**Done.** Every refusal in the reader carries a row, a column and a sentence.

| Refused | Named as |
| --- | --- |
| not an engraving | the marker, at line 1 |
| a format version this build does not know | the version, at line 1 |
| an alphabet that is neither | line 2, column 10 |
| no seed | line 3 |
| a file that ends before the carving | line 4 |
| a wall with a gap in it | no chamber closes there, so the cell it held is named as missing |
| a chamber with no label | its own line and column |
| a value that is not a number | the cell, the text, and where |
| a chamber wider than any a record has | its line and column |
| more chambers than a record has cells | where the extra one starts |

A hand-edit is refused: the demo inserts one digit into one cell and the reader
stops. There is no salvage pass, no best-effort read, and no "we recovered four of
the eight cells".

The visible half is shown rather than claimed — the demo prints the row before and
the row after the damage, so the walls that stopped meeting are on the page. That
is the argument: a corrupted binary file looks exactly like a good one until
something reads it, and a corrupted engraving looks corrupted from across the
room with nothing running.

The honest cost is accepted and stated: a record log that gets mangled is gone.
[1007](1007-handing-it-to-a-friend.md) is the other half of that trade.

## Intended behaviour

**Not robustly parsed. Not tolerant of whitespace drift. Not forgiving of a
hand-edit.** Every one of those is a decision, and each buys something specific.

### The art is a checksum you can see

If a value comes out the wrong width, the creature's proportions go wrong: the
wing bends, the ribs no longer meet, the tail runs long. A person notices
instantly, from across the room, without running anything.

A corrupted binary file looks exactly like a good one until something reads it. A
corrupted engraving **looks** corrupted.

This is the property the whole design is arranged around, and it has to be
demonstrated rather than claimed — see [1009](1009-the-phase-ten-demo.md), which
deliberately mangles one cell and shows the animal deform.

### It cannot be casually hand-edited

Which means it must be regenerated through the writer. That is *make the tool,
not the thing*, enforced by the artifact rather than by a rule somebody has to
remember.

### It stays precious

A format you can safely mangle is a format you mangle.

### The honest cost

A record log that gets mangled is a record log that is **gone**. There is no
recovery pass, no best-effort read, no "we salvaged four of the eight cells".
That is accepted, and it is what [1007](1007-handing-it-to-a-friend.md) is for.

### Every refusal is a sentence with a position in it

Fragile is not the same as unhelpful. A refusal names the row, the column, and
what was expected there — because the person reading it is going to go and look
at that spot in a text editor.

## Suggested implementation steps

1. Refuse on: a wall with a gap in it, a chamber that is not rectangular, a value
   that is not a number, a value wider than its chamber, an unknown marker, a
   mixed alphabet.
2. Every refusal carries a row, a column, and a sentence.
3. Test each refusal with a deliberately damaged engraving.
4. Test that a whitespace change anywhere in the carving is refused rather than
   absorbed.
