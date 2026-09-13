# 305 — The map file

## Current behavior

**A program can only be built by calling into the engine, so it exists
only while the device is on.**

Phase 2's three operations — place a station, configure a port, draw a
wire — are enough to build anything. They are not enough to *keep*
anything. Nothing can be written down, read back, edited, or sent to
somebody else.

An earlier draft of this issue said the parent project's format was a
directory of files, one per box, designed for a machine with a
filesystem and a text editor, and that a device with a touchscreen
wanted something else. **The first half of that was never true and the
second half did not need it to be.** The parent's format is one
line-oriented text file as well. The two designs were never far apart,
and this issue now takes the parent's, because everything it has that
this draft lacked was paid for by somebody running into the thing it
prevents.

## Intended behavior

**One text file. Line-oriented. The first word says what the line is.**

```
   # the greeting map                  ← comment, to end of line

   boxes = boxes/                      ← a short name for a place

   station greeting (boxes/text.c:constant)
     in 0 = "world"                    ← a port holding a fixed value
     out 0 - shout.0                   ← an arrow, from this end

   station shout (boxes/text.c:to_upper)
     in 0 - greeting.0                 ← the same arrow, from that end
     out 0 - speak.0

   station speak (boxes/text.c:say)
     in 0 - shout.0
     out 0 - 0$                        ← result 0 leaves the program here
```

That is a whole program.

| line | means |
|---|---|
| `name = path` | a short name standing in for the first segment of an address |
| `include path` | compile this file, or every `.c` directly in this directory, whether or not a station places a box from it |
| `station name (file:function)` | place a station running that function, sending its result to every wired exit |
| `comparator name (file:function)` | the same, but it asks less / equal / greater against its last port and takes exit 0, 1 or 2 |
| `iterator name (file:function)` | the same, but it takes its wired exits in turn |
| `in N - station.port` | port *N* is fed by that station's output port |
| `in N - ` | port *N* has no source yet, so the station can never run |
| `in N = value` | port *N* holds a fixed value rather than a queue |
| `in N x64` | port *N*'s queue starts 64 cells deep rather than the default |
| `in N - N$` | port *N* is the program's argument *N* |
| `out N - station.port` | port *N* delivers there |
| `out N - N$` | port *N* is the program's result *N* |
| `# anything` | a comment, to the end of the line, unless it sits inside a quoted string |

**The first word is always a keyword and the second is always a name**,
so no word is reserved. A station called `in` is written `station in
(f.c:keep)` and is not a special case. That rule is what lets the format
gain a keyword later without taking a name away from a map somebody
already wrote.

**Indentation means nothing.** The `in` and `out` lines belong to the
station line above them because of where they sit in the file, not
because of their leading spaces — a file that has been reflowed or
pasted still reads.

### The five things this takes from the parent that the earlier draft did not have

**The kind is the first word, not a column.** `station`, `comparator`,
`iterator`. Writing it rather than working it out is the same decision
the earlier draft made for the same reason — a comparator is inferable
from having one more input port than its function has parameters, and
then forgetting the threshold line silently demotes it to a plain
station that routes everything one way. What changed is only where the
word sits, and it sits first so that every line announces itself.

**A box address names the file its function is in.** `boxes/text.c:say`,
not `say`. A bare name is a name in a namespace nobody wrote down: two
box sources may each define a `read`. **This matters more here than it
does on a workstation**, because of what phase 4 is: a box compiled at
the touchscreen has to say which file it came from, or the description
of a program says nothing about what the program is made of and cannot
be rebuilt from.

**Every path is relative to the file it is written in**, and nothing is
searched for. A shortcut line gives a long path a short name, standing in
for the first segment of an address — so `boxes` covers
`boxes/text.c:say` and a shortcut whose whole path is one file covers
`curves:rotate`, one rule and not two. A trailing slash means nothing,
the way it means nothing to a shell. A name declared twice, a name with
`:` or `/` in it, and a shortcut line after the first station are each
refused naming the line.

**Every wire is written at both ends.** `greeting` says its port zero
feeds `shout`, and `shout` says its port zero is fed by `greeting`.
Reading one station then tells the whole truth about that station, where
one-ended arrows mean scanning the file for every line that names it.
The loader refuses when the two ends disagree, and tells four mistakes
apart because they are four different things to have done: an arrow with
no receiving end, a receiving end with no arrow, two ends naming
different ports, and a source naming a station the file does not declare.
At run time a wire still exists once — the second declaration is checked
and dropped, because delivery only ever asks where a value goes.

**A door is a port, not a station.** `0$` on an `in` line says the
outside delivers argument zero here; on an `out` line it says result
zero leaves here. This replaces the earlier draft's `way in` and `way
out` station lines, and 309 carries what it buys — chiefly that **an
argument stops costing a station**.

### What it keeps from the earlier draft, unchanged

**No types anywhere.** Both ends of every wire are known without the
file saying (303). A file that declared them would be a second source of
truth, always the wrong one.

**No buffer sizes required.** Ports grow on their own (208), so `x64` is
an exception somebody writes when they know better, not a field to fill
in.

**Names, not numbers.** A map is read by people, and *"shout →
speak.0"* is a message somebody can act on.

**A port is a queue unless a line says otherwise**, and only exceptions
are written.

**An unconfigured port is written down.** Writing the running program
back out has to say what is actually there, so a half-built program
produces a faithful file that reads back into the same half-built
program. Leaving the port out makes the file quietly lie; refusing to
write the file makes the tool useless exactly when somebody is mid-edit
and most wants to see what they have.

### A braced value may cross lines

```
   in 0 = {
       1.5,
       2.5,
       3.5
   }
```

While the braces are open the reader keeps taking lines and drops each
one's leading whitespace, so a continuation is the same line still being
assembled and the keyword rule is untouched. A file ending with braces
still open is refused, naming the line that opened them. A line too long
to hold is refused rather than split.

### `include`, and why a handheld wants it

```
   include boxes/               every .c directly in that directory
   include boxes/text.c         that file
```

**It takes no name and no `=`, because nothing refers to it again.** A
shortcut renames a place so an address can be short; `include` says what
to compile. Two lines because they are two decisions.

What it buys is **a program that can grow without a compiler** — and
that is the launch library's whole story on this device. A box compiled
into the kernel image but placed by no station in any map can still be
placed later, at run time, by name, needing nothing but the program
itself. Without it, a program handed a description naming a box it does
not hold has to reach for a compiler, which means the image carries a
toolchain to serve a decision that was already made at build time.

**A directory means every `.c` directly in it, not a tree.** A nested
directory is another `include` line, written by somebody who meant it.
Descending would make one line's meaning depend on a directory listing
somebody else controls.

### One consequence, which touches an open question

**The catalogue is keyed by an address rather than a bare name.** The
file now says `boxes/text.c:say` where it used to say `say`, so what the
loader hands the catalogue to look up is the whole address. That is a
one-column change and not a design change, but it sits next to a larger
undecided question — whether this device keeps a catalogue at all, given
that the parent deleted its own by leaning on a symbol table this device
has not got. See `phase-3-progress.md`.

## Suggested implementation steps

1. The reader: line-oriented, first word dispatching, producing a
   description and constructing nothing. Building from that description
   is 306.
2. Every malformed line stops the read naming the file, the line
   number, and what was expected there.
3. Comments, which the format needs and which are easy to leave out
   until something wants to write a derived fact into a file it
   generated. The walk that finds a comment counts braces and tracks
   quotes in one pass, so the two cannot disagree about where a string
   begins.
4. **The address resolver**, which turns a box address into the path of
   the file holding it: apply the shortcuts to the first segment, join
   what is left to the directory the description lives in unless it is
   already absolute, collapse doubled slashes. One function, because
   every caller that resolves an address must agree with every other —
   the parent had two that did not, and the symptom was a description
   that one accepted and the other refused naming a file it could not
   find.
5. **Both ends of every wire**, and the four ways they can disagree told
   apart, with all of them collected before any is reported.
6. A reference file exercising every line form, kept as test material.
7. Tests for each malformed shape, each asserting the message.

## Open questions

- *Where does a map file live before there is a filesystem?* Phase 3
  ships before phase 4, so the first maps are text compiled into the
  kernel image. That works and it means the demo's map is a string
  constant, which is fine and slightly absurd. Phase 4 makes it a path.
- *What is a path relative to, when the description is a string constant
  in the kernel image?* The rule is that paths are relative to the file
  the description sits in, and a string constant sits in no file. The
  parent hit the same wall from the other side: a description handed to a
  running program has no home either, and its answer was to give the text
  a home — copy it somewhere, put the sources it names beside it, and
  resolve against that. Before phase 4 there is nowhere to copy it to.
  **Undecided**, and it needs deciding before the phase 3 demo, because
  the demo's map is exactly this case.
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
- [309 — The two doors](309-the-two-doors.md), which the `$` marks exist
  for
- [212 — Maps built by hand](212-maps-built-by-hand.md), the operations
  the loader will call
- [409 — Compiling a box on the device](409-compile-pipeline.md), which
  is why a box address has to name its file
- `docs/012-soramech-runtime.md`, which describes the same format for a
  reader who is not holding this issue
- The parent's own `docs/008-map-file-format.md`, in
  `/home/ritz/programming/ai-playground/minimal-soramech/`, which is
  where each of these rules was argued out and where a refusal's exact
  wording lives
