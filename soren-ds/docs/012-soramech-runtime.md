# The runtime — the Soren DS subset

Below the waterline, Soren DS is a small C kernel. Above it, everything
is a program made of boxes. `003-threading-model.md` describes the
engine that runs one. This document describes what sits on top: how a
box gets to exist, how a program gets written down, how it gets written
back out again, and how the two halves of the device meet.

The design is the one built and measured in
`/home/ritz/programming/ai-playground/minimal-soramech/`, narrowed to
fit a handheld. Where the two differ, it is because a handheld's
constraints differ and the difference is stated — and **one difference is
still undecided**: the parent deleted its catalogue entirely, leaning on
a symbol table every process on a workstation already carries, and this
device is the operating system and has no such table. See
`../issues/phase-3-progress.md`.

## Two halves that meet in one table

```
   the C half                                the written half
   ──────────                                ────────────────
   box sources                               map files
   compiled, typed, checked                  text, names, arrows
        │                                          │
        │  read by the generator                   │  read by the loader
        ▼                                          ▼
   ┌───────────────────────────────────────────────────────┐
   │                     the catalogue                     │
   │   name │ call site │ each input's type and size │     │
   │        │ return type and size │ exact task size       │
   └───────────────────────────────────────────────────────┘
```

**The catalogue is the only place both halves are described**, and it is
derived entirely from the C, which is what actually runs. A map file
therefore never mentions a type: the loader knows both ends of every
wire already, and a file that declared them would be a second source of
truth able to disagree with the first — always losing, because the
compiler enforces the C and nothing enforces the file.

**A wire is legal when both sides count the same number of bytes.**
Nothing else is consulted. Names ride along for the message — *"returns
a colour, slot takes a point — 16 bytes against 12"* — but the decision
is one number against another, because that number is what the engine
actually runs on: cells are that wide, a delivery copies that many, a
task is allocated for exactly that.

The cost is stated rather than discovered: **two types of the same width
are interchangeable, silently and completely.** A 32-bit float into a
32-bit integer slot arrives as a very large integer, with no error
anywhere. Two structs with the same fields in a different order wire and
scramble. What is bought is that C somebody already had goes through
unchanged, and that nobody ever writes a box that takes one type,
returns another, and does nothing.

**The generator is a C program with no dependency on the engine.** That
is what lets the device call it — a build tool written in a scripting
language is a build tool forever, and phase 4 needs the same parser
reachable at runtime. A second parser would eventually disagree with the
first about what a box is.

## What we keep and what we cut

| kept | why |
|---|---|
| the map model — boxes, wires, one firing rule | it is the whole idea |
| ways of choosing an exit | pure routing; nothing about them needs a desktop |
| a map placed inside a map | without it, any program past a dozen stations stops being readable |
| the compile pipeline | on-device authoring is impossible without it |
| old code outliving the boxes that used it | what makes rebuilding safe under a running app |

| cut | why |
|---|---|
| boxes written in Lua or Bash | C only at launch. The kernel hosts no other language. |
| wires that cross languages | one language means one representation, no tagging per value |
| the on-disk transcript | the storage is small and write-precious. In RAM, in debug builds. |
| the pull path | nothing is ever pulled. See below. |

**There is no pull path**, and it is worth naming because the parent
project had one. Nothing reaches upstream to produce a value on demand;
every value arrives because something pushed it. What used to be pulled
is now written into a fixed-value port by an ordinary arrow, and writing
one runs the readiness check on its station. The cost is that no value
is ever fresh at the instant it is used — a box that needs the current
time asks for the current time inside itself.

## How a box gets to exist

**A box is a C function.** Not a function plus a description of it —
just the function. The generator reads the box sources, emits one call
site per box, and emits the catalogue with every size as a `sizeof`
expression the compiler computes. Nothing is written down twice, so
nothing can disagree.

Two paths produce a box, and the catalogue cannot tell them apart:

| path | when |
|---|---|
| compiled into the kernel image | the launch library, and everything phases 3 through 8 ship |
| compiled on the device | anything somebody writes at the touchscreen (phase 4) |

The static path is a bootstrap, not the end state. As more of the system
moves up into programs — the compositor, the input router, eventually
the drivers — the C bottom keeps shrinking and the on-device tree keeps
growing.

## How a program gets written down

One text file, line-oriented, first word dispatching. It is the parent
project's format, not a narrowed one — the two were never far apart, and
everything this format has that an earlier draft of it lacked was paid for
by somebody running into the thing it prevents.

```
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

No types, because the catalogue has them. No buffer sizes, because ports
grow on their own. No grammar and no nesting. `305-the-map-file.md` is
the whole of it; four things are worth having here.

**The first word is always a keyword and the second is always a name**, so
no word is reserved and the format can gain a keyword later without taking
a name away from a map somebody already wrote. The kind is that first word:
`station`, `comparator`, `iterator`.

**A box address names the file its function is in.** `boxes/text.c:say`,
never `say`. Two box sources may each define a `read`, so a bare name is a
name in a namespace nobody wrote down — and **on this device that is not a
tidiness argument**: a box compiled at the touchscreen has to say which
file it came from, or a program's description says nothing about what the
program is made of and cannot be rebuilt from. Every path is relative to
the file it is written in and nothing is searched for; a shortcut line
gives a long path a short name, standing in for the first segment of an
address.

**Every wire is written at both ends.** `greeting` says its port zero
feeds `shout`, and `shout` says its port zero is fed by `greeting`.
Reading one station then tells the whole truth about that station, where
one-ended arrows mean scanning the file for every line that names it. At
run time the wire still exists once — the second declaration is checked
and dropped, because delivery only ever asks where a value goes.

**A `$` on a port line is a door**, which is the next section.

**`include` compiles a file whether or not a station places anything from
it**, and that is how the launch library works: boxes compiled into the
kernel image, placed later by name, by a map, needing no compiler at the
moment of placing. Without it a program handed a description naming a box
it does not hold has to reach for a toolchain to serve a decision already
made at build time.

**The loader is a caller, not a mechanism.** It turns each line into one
of the three operations the engine already exposes — place a station,
configure a port, draw a wire — which are the same three a person calls
while editing a running program. There is no state a file can reach that
a person cannot, and none a person can reach that a file cannot.

**Then somebody says the program is finished.** That is a fourth act and
it is separate on purpose: the `$` numbering can only be checked once
every line has been read, and so can everything else that is a fact about
a whole program rather than a line. It is **repeatable** — a station added
to a running program is checked and started by the next call, and one
already started is not started twice — which is why editing a running
program and loading a file end the same way.

## How a program runs

```
   place every station        nothing runs yet
        │
   draw every arrow           nothing runs yet
        │
   write the fixed values ──→ ✦ running
```

**There is no fourth step.** Writing a fixed value runs the ordinary
readiness check on its station; a station whose inputs are all fixed
values is ready the moment the last one lands. So the writes that finish
building a program are the writes that set it going. No entry-station
list, no submit call, nothing that has to be told what goes first.

**Nothing polls, ever.** The readiness check runs as the tail of a
write, on exactly one station — the one just written to. A station whose
inputs have not changed cannot have become ready.

**A program ends because it was asked to.** Running out of work is not
an ending on a handheld; it means the user has not pressed anything yet.
The tail of a pipeline is a station whose input has no source, so it can
never become ready and costs nothing while it waits. Parking releases
its buffers back to the allocator with a checksum remembered, so
restarting resumes in place if nobody needed the pages and rebuilds
loudly if somebody did.

**A loop is not an error.** A box cannot remember anything between calls
— two cores can be inside it at once — so routing an output back around
to an input is the only way a program carries state. Counting to ten is
a loop. There is no cycle detection and there must not be.

## A program's outside

**A door is a port, not a station.** A mark on an input port says the
outside delivers argument *N* here; a mark on an output port says result
*N* leaves here. No station is special, and no station has to exist for an
argument to.

| a marked input port | a marked output port |
|---|---|
| the outside delivers argument *N* here | result *N* leaves here |
| a station holding one may check or reshape what arrives — by choice, not by mechanism | and may shape results for whoever receives them |

**An argument costs nothing.** This is why the mark is on the port. A
designated *station* means every argument pays for a station running the
identity function — a station record, a mutex, a ring buffer, and per
value a task allocated, a dispatch through the pool, a call that returns
its own argument, a readiness check and a second delivery — all to move a
value one hop for no reason. Four cores and 3 GB is exactly the machine
where that is worth not paying.

**Which argument a port is, is stated rather than positional.** The mark
carries a number chosen by whoever wrote the line, so reordering every
line in the file changes nothing. A gap or a repeat is refused when the
program is brought up, which a scheme taking the order from wherever the
stations happened to sit in the table cannot even detect — moving two
lines in a sub-program would silently swap two of the parent's arguments.

**Being an argument slot is derived, not stored**: a port is one when it
is marked and nothing feeds it. A port both marked and wired is fed both
ways and simply is not one. Nothing is stored, so nothing can go stale,
and there is no bookkeeping at the moment an enclosing program wires in.

**A station may hold ports of both kinds**, which was a mistake only
while the mark sat on the station, because a station is one thing and a
port is a smaller one.

The only behaviour a mark adds is at the result end: when nothing is
wired beyond a marked output port, values are **held** rather than
discarded. Everywhere else an exit wired to nothing discards, which is
right for an unwired comparator branch and wrong for a program's results.

**A map is a box.** Once a program has doors, placing one inside another
is wiring to those two stations — no splicing, no flattening pass, no
renaming a sub-program's stations into a parent's namespace, and nothing
that has to detect when a sub-program is finished. The parent cannot
tell whether the thing behind the port is a graph or a C function, and
has no reason to care.

**Several arguments are several marked ports**, which need not sit on one
station. What stays true is at the exit: a box returns one value, so a
station has one output port, so several results are several marked output
ports. Faking several returns with a struct that something downstream
takes apart means writing a function to satisfy the engine, which is what
nobody adopting this should ever have to do. Fan-out is free and
separate: one marked port's value feeds as many interior stations as you
wire it to.

**Two values arriving at two ports of one station are not a pair.** A
station with an object port and a colour port, fed by two callers, may
pair the first caller's object with the second caller's colour. Values may
leave a port in a different order than they arrived, so correspondence
across two ports is certainly not promised. **Anything that must arrive
as a unit is one struct on one port** — which the engine supports all
the way down, since the generator emits a field table per struct and the
reader lays out brace text using offsets the compiler computed.

## Writing a box while the program runs

This is what makes on-device authoring possible, and the shape of it is
not what an earlier draft of this document said.

**A station's box cannot be changed.** A station is one placement of one
box, and its input ports were sized from that box's parameter widths when
it was placed — they may be holding values right now. Storing a different
function over the top means the next run hands those bytes to something
expecting a different shape, and there is no moment at which that is safe.

**A station can be removed, though, and its place reused.** Reclaiming an
index looks like it must mean either a hole every walk learns to skip or a
renumbering that invalidates every wire at once. It means neither, because
of where a wire lives: **a wire exists only as a destination record on
some station's output port.** Cut every wire that names the station — one
walk, because there is nowhere else for one to be — and nothing stale
survives to be followed, so no wire needs a generation tag and delivery
pays nothing for the possibility. The parts then go to the same scrapyard
an old destination array goes to, and the same per-core sweep frees them.

So replacing a box is:

| step | what happens |
|---|---|
| 1 | somebody saves an edited box source |
| 2 | the generator runs over it — the same generator, which is why it is a C program |
| 3 | a compiler turns that into loadable code; **there is no version of this that skips the compiler**, because sizes and offsets are what the engine runs on and only a compiler computes them |
| 4 | a row is added to the catalogue, which grows by adding a block rather than by moving what is there |
| 5 | a **new station** is placed running the new box, and the arrows are moved to it as one batch |
| 6 | the old station is **removed**, and its place is available to whatever is added next |

**Arrows move in batches**, and that matters most here. Attach one arrow
into the new station and values start arriving; attach the next a moment
later and it has already missed everything the first one got.

**Step 6 used to leave the old station standing, unwired.** Three things
came of changing it: the table stops growing by one dead station per edit,
on a device whose whole purpose is being edited while it runs; the page of
code the old box lived in becomes reclaimable rather than reachable
forever; and a program written back out no longer carries a dead station
per save, so its shape stops drifting from what somebody wrote.

Values in the old station's ports go with it, and so does any value
already in flight toward it — which is what this engine does with any
value that has nowhere to go. Somebody who wants them to survive an edit
wires the old station's output somewhere that keeps them and removes it
after they drain.

The *no source* state is still what parks a program and what a failing box
uses to take itself out of service. Those want a station that stops running
and **stays**, which is a different thing from one that goes away.

**A box arriving late asks nothing the type system cannot answer.** It
reports the width of each input and of its output, by the same `sizeof`
the compiler computes for every other box. So it introduces no new kind
of error — two same-width structs with different layouts already wire at
build time, and a box compiled later only makes that likelier, not
different.

**Unloading the old code** waits until no core can still be inside it.
Each core keeps a private counter bumped at the start and end of a whole
task, so it reads odd while inside one and even while not; retiring code
files it with a snapshot of all four; a later sweep frees it once every
core reads even or differs from its snapshot. A core with nothing to do
is asleep and therefore even, so an idle device does not stall the
sweep. This is the same mechanism that reclaims an old destination array
after rewiring, and it is deliberately one mechanism rather than two.

Nothing in the launch system uses any of this. The four apps ship boxes
compiled into the image. It matters first in the authoring loop: write a
box, place it, wire it in, watch it run — without the device restarting
and without anything else losing what it was holding.

## How a program gets written back out

**What a running program writes down is everything needed to build it
again.** Two things: a map file, and a directory of C beside it named
after the map, holding the source of every box its stations place.

```
   drawing.map
   drawing.functions/
       shapes.c
       smooth.c
```

**Every station line addresses its box inside that directory**, so the
addresses in what a program wrote are relative to what a program wrote,
the same way any description's paths are relative to itself. The directory
takes the map's name rather than being called `functions`, so two saved
programs in one place cannot take each other's code.

**A box compiled into the kernel image and a box compiled at the
touchscreen are written out identically.** By the time a program is
written down, the difference between them is a fact about how the program
came to be rather than about what it is, and a file saying what a program
*is* should not record it. This is also the only way the second kind can
be written down at all: a box compiled while the device was running lives
wherever that compile put it, and nothing about that location will still be
true next boot — but the directory gives it a file that exists, because
saving just wrote it.

**A source is written out when a station places one of its boxes, and not
otherwise.** A device holding a launch library of forty boxes and a program
placing three writes out the files holding those three. The unit is the
file rather than the function, and it has to be: a box's source may need a
struct, a helper, or an include sitting beside it, and a file cut down to
one function is a file that may not compile. Basenames are kept, because
somebody opening a saved program wants to see `shapes.c`; two sources
sharing a basename are told apart by a number before the extension.

**Why this shape matters on this device specifically.** A program saved
any other way is a description *plus* a running system that already holds
the code — which is fine until the thing you want is to hand somebody your
program, or to open next year what you drew today, or to recover after a
box you were editing stopped compiling. Written this way, what is on the
SD card is the program, and rebuilding it needs the generator and a
compiler (phase 4) and nothing that knows anything about the system that
wrote it.

**There is also a text-only form**, which writes the map and no sources,
with each address exactly as its station holds it. That is the right thing
when what you want is to look at the shape of a running program — the
transcript, the editor's view — and the wrong thing to call saving.

## What the parent ships as one command, and what that means here

The parent project's whole toolchain is one executable, `serac`, that
carries the engine's own source inside it as text. Hand it a description
and it reads which C files the description names, emits the construction
code, assembles the header, the engine, that code and a `main` as one
piece of text in memory, and hands the text to a C compiler down a pipe —
writing nothing to disk but the program. The machine it runs on needs a C
compiler and nothing else.

**This device is not that shape and the reason is worth stating.** There is
no `main` to emit, no host toolchain to invoke, and no filesystem to write
a program into at phase 3. What transfers is the property rather than the
program: **nothing is written down twice, and nothing is written to disk
that does not have to be.** The generator being a C program with no
dependency on the engine is the same decision from the same reasoning, and
it is what lets phase 4 reach the same parser at runtime.

What is worth borrowing when phase 4 arrives is the concatenation trick. An
`#include` is a filesystem lookup, so a header that exists only inside a
running image forces a directory to exist somewhere with a copy of it in
it. Putting the header's text in front of the body's and deleting the line
that included it puts the same declarations in scope by the same rule with
no file involved — which on a device with 3 GB of RAM and a
write-precious card is the difference between compiling a box and
maintaining a private copy of the kernel's headers on storage.

## How a program produces visible output

Each app composes a program ending in display-surface boxes. A
display-surface box is a sink — a box that returns nothing — which hands
its input bytes to the compositor as the new contents of a named
surface. The surface marks itself dirty, the compositor's damage scan
copies pixels into the right screen's framebuffer, and scan-out makes
them visible.

Apps never call the compositor. They draw an arrow to a box that does.
Same shape as the filesystem boxes: a program expresses intent as
wiring, and the boxes at the edges turn it into kernel work.

## What the device remembers

| always | in debug builds |
|---|---|
| one error slot per station — the kind, a count, one detail word | the same, plus a timestamp |
| the first occurrence of each error, out the serial line | a rolling ring of recent events, dumped on a crash |
| | a saved return point before every box call, so a fault can name its station and remove it |

**Errors are counted in place, never appended.** The same failure a
million times is one slot reading a million — not a million records, not
a growing buffer that eventually becomes the actual problem.

**A box that cannot continue takes itself out of service.** Its inputs
are set to no source, so it can never become ready. Nothing is deleted;
the hole is visible when the running program is written back out. Then
somebody writes the box better and wires it back.

## What's next

| phase | what it adds here |
|---|---|
| 3 | the generator, the map file, the loader, ways of choosing an exit, maps inside maps |
| 4 | the filesystem under map files, the generator and a compiler running on the device, and the sweep that frees code nobody placed |
| 5 | the polled input programs, fed by the engine's own idle wake |
| 6 | the display surfaces this speaks to, and the editor that calls the loader's operations directly |
| 9 | the memory protection that turns a stray write from silent corruption into a trap |

`013-background-app-lifecycle.md` describes how a running program is
parked without being killed, and what wakes it.
