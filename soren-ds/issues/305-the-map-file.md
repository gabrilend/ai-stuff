# 305 — The map file

## Current behavior

**A program can only be built by calling into the engine, so it exists
only while the device is on.**

Phase 2's three operations — place a station, configure a port, draw a
wire — are enough to build anything. They are not enough to *keep*
anything. Nothing can be written down, read back, edited, or sent to
somebody else.

The old plan was a directory of files, one per box, in the format the
parent project uses. That format was designed for a machine with a
filesystem, a text editor, and a screen; this device has a touchscreen
and 3 GB of RAM, and a person editing a map on it wants to see the
whole program at once.

## Intended behavior

**One text file. Line-oriented. The first word says what the line is.**

```
   # the greeting map                     ← comment, to end of line

   greeting   constant      plain         ← name, box, kind
   shout      to-upper      plain
   speak      debug-write   plain

   in greeting.0 = "world"                ← a port with a fixed value

   out greeting.0 -> shout.0              ← an arrow
   out shout.0    -> speak.0
```

That is a whole program. Three station lines, one port line, two
arrows.

| line | means |
|---|---|
| `name box kind` | place a station running that box, with that way of choosing an exit |
| `in station.port = value` | that port holds a fixed value rather than a queue |
| `in station.port = -` | that port has no source yet, so the station can never run |
| `out station.exit -> station.port` | an arrow |
| `# anything` | a comment, to the end of the line |

**No grammar, no nesting, no indentation that means anything.** Four
entries in a dispatch table. Indentation is for whoever is reading.

**No types anywhere.** The catalogue knows both ends of every wire
(303). A file that declared types would be a second source of truth,
and it would always be the wrong one.

**No buffer sizes anywhere.** Ports grow on their own (phase 2's 208),
so there is nothing to get right.

**Names, not numbers.** A map is read by people, and *"shout → speak.0"*
is an error message somebody can act on. The names cost one lookup
table while the file is being read.

**The kind is written rather than worked out.** A comparator could be
recognised by having one more input than its box has parameters — but
then forgetting the threshold line silently turns a comparator into a
plain station that sends everything one way. One word of redundancy
buys an error instead of a wrong answer.

**A port is a queue unless a line says otherwise.** Only the exceptions
are written, so an ordinary station has no `in` lines at all.

**An unconfigured port is written down**, and this matters more than it
looks. Writing the running program back out has to say what is actually
there, so that a half-built program produces a faithful file that reads
back into the same half-built program. Leaving the port out would make
the file quietly lie; refusing to write the file at all would make the
tool useless exactly when somebody is mid-edit and most wants to see
what they have.

## Suggested implementation steps

1. The reader: line-oriented, first word dispatching, producing a
   description and constructing nothing. Building from that description
   is 306.
2. Every malformed line stops the read naming the file, the line
   number, and what was expected there.
3. Comments, which the format needs and which are easy to leave out
   until something wants to write a derived fact into a file it
   generated.
4. A reference file exercising every line form, kept as test material.
5. Tests for each malformed shape, each asserting the message.

## Open questions

- *Where does a map file live before there is a filesystem?* Phase 3
  ships before phase 4, so the first maps are text compiled into the
  kernel image. That works and it means the demo's map is a string
  constant, which is fine and slightly absurd. Phase 4 makes it a path.
- *Does one file hold one program or many?* Since a map is only
  whichever stations are wired together, a file could hold several
  unrelated programs and nothing would object. Probably fine, probably
  worth a convention rather than a rule.
- *Is one flat file still right at a thousand stations?* It is right at
  ten and clearly wrong at ten thousand. Encapsulation (309) is the
  answer for the middle, and where the number sits wants finding out
  by writing real maps rather than by guessing here.

## Blocked by

Nothing — this is the shape 306 reads.

## Blocks

306, 307, 309, 312.

## Related

- [306 — The loader](306-the-loader.md), which builds from this
- [309 — A map that is one station on somebody else's canvas](309-a-map-that-is-one-station.md)
- [212 — Maps built by hand](212-maps-built-by-hand.md), the operations
  the loader will call
