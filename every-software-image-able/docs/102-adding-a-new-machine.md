# 102 — Adding support for a machine that is not yet supported

Standard operating procedure. Follow it in order; each step is the ground the
next one stands on, and the order is not a preference.

The question this answers is: **somebody has a computer, and the seed does not
run on it. What has to be written?**

## First, decide which of three situations you are in

They cost wildly different amounts, and telling them apart takes five minutes
rather than a week.

| Situation | What is missing | Roughly what it costs |
|---|---|---|
| **A new board, familiar processor** | a description file, and nothing else | an afternoon |
| **A new processor in a family that already works** | possibly nothing; possibly one detection rule | an afternoon, or a day |
| **A new processor family** | an engine, written by hand, in that family's instructions | weeks, and it is the only situation that is real work |

Almost everything people call "porting" is the first row. The seed is generic
by construction; a board is a description of where things are.

## Situation one: a new board, familiar processor

The machine speaks an instruction set the seed already carries an engine for.
Nothing is compiled, nothing is written, and no code changes.

**Write a board description.** One file, sitting beside the others. It must
say:

- **which instruction set the processor speaks.** This is what decides which
  engine the image carries for it.
- **how the firmware finds something to start, and where it looks.** This is
  the load-bearing field. Nothing in the seed detects a processor and chooses
  an engine — each firmware finds only its own payload, in the place its own
  convention names, and that place is board knowledge. Some boot schemes carry
  the answer in themselves (a BIOS always reads the first sector) and are not
  made to repeat it; every other scheme must say.
- **which device carries bytes off the machine, and at what address.** This is
  the first and most important thing a new board needs, because everything
  that goes wrong afterwards is diagnosed through it. A board with no way to
  speak is a board nobody can help.
- **which storage controllers to expect.** The boot filesystem arrives on the
  board's own controller rather than a fixed one — a machine with no IDE at
  all will refuse a disk attached as IDE.
- **whether a display is handed over at boot**, and by what route.
- **where this description was transcribed from.** A transcription whose
  source is not named cannot be re-checked when a board revision lands.

**Then build for it and boot it.** The builder takes one recipe and one board
description, neither naming the other. If the board description is sound, an
image comes out. If the seed's own account of where things are disagrees with
where the builder put them, the build refuses — that disagreement is the one
that would otherwise make a machine fail at the earliest possible moment with
the least possible information.

**Confirm in this order**, because each answer makes the next question
meaningful:

1. Does the firmware start our payload at all? If not, the boot path in the
   description is wrong, and the symptom is a machine that boots to its own
   menu saying nothing.
2. Does anything arrive on the console? If not, the console address is wrong,
   and from here on you are debugging blind.
3. Does the machine find the model inside its own image and read its header
   aloud? If the numbers are wrong rather than absent, the layout is
   disagreeing rather than missing.
4. Does the memory report look like this board? Compare the free memory
   against what the board actually has.

## Situation two: a new processor in a family that works

The instruction set is one the seed knows, but this particular chip differs in
what it can do — which vector width it has, or whether it has vectors at all.

The baseline for each family is never detected, because it is what the family
guarantees, and asking a processor about a guarantee is how a detector gets a
wrong answer from a chip that answers oddly. Only the things above the
baseline are asked about.

**What to do:** add a level to the family's table saying what the wider
arrangement is and how to ask for it. Then prove the detection by **booting
two different processors and requiring the answers to differ.** A detection
run on one machine cannot show that it detects anything, and a payload that
always says the same thing passes any test that only asks whether it said
something plausible.

**If the chip is from a maker nothing was built against**, the machine stops
and says so rather than guessing — because the place the capability answers
come back in is that maker's own convention, so an unknown maker makes those
answers untrustworthy too.

## Situation three: a new processor family

This is the one that is real work, and it is the only situation where the seed
is not self-sufficient.

**Why it cannot be automated.** The model cannot think until an engine runs,
and writing an engine is thinking. A machine with no engine for its processor
cannot write itself one. So the engine is written by people, before that
machine ever exists, or that machine is never used.

**Write the arithmetic first**, because it is nearly all of the work and all
of the speed. There are ten small routines. Take them in this order:

1. The matrix product, plain. Everything else is easier once this is right.
2. The normalisation.
3. The four small ones — carrying a value forward, rotating pairs by a carried
   angle, scoring against remembered values, mixing them by weight.
4. The exponential. Fiddly, self-contained, and every constant is a bit
   pattern computed from the specification rather than typed.
5. The two that call the exponential. These are where every trap lives,
   because they are the only ones that make a call.
6. The fast versions. Budget these separately: the vector instruction sets of
   different families have nothing in common, and one family's may be a
   different shape of loop rather than a wider one — or absent from the
   silicon entirely.

**How you know each one is right.** Not by reading it. Record what the first
family's version produced for a set of shapes, carry those exact bit patterns
into a payload alongside the new version, boot a machine of the new kind, and
have it compare its own results **as whole numbers** — so nothing rounds
during the comparison and "close enough" cannot happen.

Multiplication, addition and square root are exactly specified and agree on
any conforming processor, so routines built only from those can be *required*
to match exactly. The exponential is not specified that way, so anything
downstream of it is held to a stated tolerance instead. That line is drawn
deliberately; do not move it to make a test pass.

**Then the hands, and expect one to change shape rather than detail.** One
family talks to devices through a separate address space reached by its own
instructions; the others have everything memory-mapped. So the hand that
touches ports exists in one form on one family and collapses into ordinary
memory access on the others. The catalogue of hands is therefore not identical
across machines — which is survivable because the machine reads its catalogue
rather than being told it, and which is why the instruction the machine wakes
up holding must never assume a particular hand exists.

## Three rules that apply to every situation

**Nothing in a payload may refer to an exported name.** Not read from it, not
jump to it, not call it. An assembler leaves a note for a linker whenever a
name is exported, this project has no linker, and extraction drops the note
and leaves a zero behind. A read of a zero-distance address points at itself;
a call to a zero-distance name calls itself and spins forever. This has been
met three times, on two families, wearing different clothes each time. A file
that needs its exports for a hosted build has them stripped by the payload
that embeds it.

**The first instruction has to be ours.** Firmware enters at the beginning of
the code, so whatever is emitted first is what runs.

**There is nowhere writable inside the payload.** Firmware that honours
section permissions maps the code read-only. Anything the machine writes to
goes on the stack.

## What to do when it does not work

The failure modes here are quiet ones. In rough order of how often they
happen:

| What you see | What it usually is |
|---|---|
| The machine boots to its own firmware menu | the payload was never started — wrong boot path, or the first instruction was not ours |
| Nothing on the console, ever | wrong console address, or the board has none |
| The machine speaks once and then goes silent | it wrote somewhere it may not, or called a name that resolved to itself |
| Numbers that look like numbers but are wrong | an offset counted by hand rather than computed from the shared description |
| It works, then stops much later | thermal or slow damage from an earlier write, presenting long after its cause |

Record every one of these in the list of what emulation hides, **with what it
cost**, whether or not the emulator was to blame. A list of differences is
interesting; a list with prices attached is the argument for how often to stop
developing against emulation and go put something on a card.
