# The runtime — the Soren DS subset

Below the waterline, Soren DS is a small C kernel. Above it, everything
is a program made of boxes. `003-threading-model.md` describes the
engine that runs one. This document describes what sits on top: how a
box gets to exist, how a program gets written down, and how the two
halves of the device meet.

The design is the one built and measured in
`/home/ritz/programming/ai-playground/minimal-soramech/`, narrowed to
fit a handheld.

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

## What we keep and what we cut

| kept | why |
|---|---|
| the map model — boxes, wires, one firing rule | it is the whole idea |
| ways of choosing an exit | pure routing; nothing about them needs a desktop |
| a map placed inside a map | without it, any program past a dozen stations stops being readable |
| the compile pipeline | on-device authoring is impossible without it |
| generations of a box coexisting | what makes rebuilding safe under a running app |

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

One text file, line-oriented, first word dispatching.

```
   greeting   constant      plain          ← name, box, how it picks an exit
   shout      to-upper      plain
   speak      say           plain

   in greeting.0 = "world"                 ← a port holding a fixed value

   out greeting.0 -> shout.0               ← an arrow
   out shout.0    -> speak.0
```

No types, because the catalogue has them. No buffer sizes, because ports
grow on their own. No grammar and no nesting.

**The loader is a caller, not a mechanism.** It turns each line into one
of the three operations the engine already exposes — place a station,
configure a port, draw a wire — which are the same three a person calls
while editing a running program. There is no state a file can reach that
a person cannot, and none a person can reach that a file cannot.

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

## Rebuilding a box while it is running

This is what makes on-device authoring safe under live apps.

| step | what happens |
|---|---|
| 1 | somebody saves an edited box source |
| 2 | the pipeline compiles it and produces a new call site |
| 3 | every station running that box has its call pointer replaced, one atomic store each |
| 4 | tasks already built still carry the old pointer, and finish on old code |
| 5 | the old code is released once no task built before the swap can still exist |

**Step 5 needs no reference counting.** A task is built, run, and freed
inside one pass of a worker's loop, so once every core has passed
through its loop after the swap, nothing anywhere still holds the old
pointer. One counter per core and one comparison — the same shape as
releasing an old destination array after rewiring, and worth being the
same code.

Nothing in the launch system uses this. The four apps ship running boxes
compiled into the image. It matters first in the authoring loop: edit,
save, see the change, without any app losing what it was holding.

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
| 4 | the filesystem under map files, the compile pipeline, the artifact tree |
| 5 | the polled input programs, fed by the engine's own idle wake |
| 6 | the display surfaces this speaks to, and the editor that calls the loader's operations directly |
| 9 | the memory protection that turns a stray write from silent corruption into a trap |

`013-background-app-lifecycle.md` describes how a running program is
parked without being killed, and what wakes it.
