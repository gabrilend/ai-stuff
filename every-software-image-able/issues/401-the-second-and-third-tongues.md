# 401 — The second and third tongues

## Current behavior

**In progress. A whole thought is now assembly end to end on the second
architecture, and every score agrees with the first bit for bit. The third
architecture is not begun, and neither are the hands.**

**All eleven routines are written for the second architecture, and every one
is proved bit-identical to the first on a real ARM machine** -- 279 of 279
values, and 133 of 133 normalisation values, on 2026-08-03.

It was ten for a while, and the missing one was the fast matrix product --
the routine that provides all of the speed, absent from a port that was
reported as finished. Nothing said so. The list of what was still missing
was a hand-kept table that had been emptied when the port felt done, and the
check that was meant to notice compared the count against a literal ten. The
stale table and the stale check agreed with each other.

Both are gone. The port is now asked what it has, the first tongue is asked
what it has, and the difference is worked out rather than remembered. The
exact product and the fast one are held to **different** recorded answers,
because they sum in different orders on purpose and requiring them to agree
would be requiring the fast one to stop being what it is.

**And they are now proved correct together, which is the harder claim.** The
conducting is written in this tongue too (`src/108`) -- the layer walk, the
head walk, and every pointer handed to a kernel -- so a whole forward pass
runs on a real ARM machine with nothing readable left in the loop. Over the
fixture model and its four-token prompt, all 192 scores match what the first
architecture's own conducting produced, as integers, on 2026-08-03.

That is a different statement from the one above it. A piece can be right
alone and be handed the wrong thing by the piece before it, and the first
architecture learned exactly that: composing nine kernels that each passed
found a disagreement of four parts in a thousand million, at the second token
only, and the defect was in the reference rather than the assembly.

**The same payload also carries a conducting that is wrong on purpose**, and
is required to disagree with it. The feedforward's two projections are handed
to each other's kernels -- same shapes, nothing faults, every kernel still
correct, and only who-is-given-what changed. It moved all 192 scores. Without
that, a run reporting agreement everywhere would be indistinguishable from a
payload comparing something against itself.

The wide matrix kernel is checked the hard way here as well: the whole prompt
is run again through it and required to give the identical answer. A
difference of one bit anywhere compounds through every tensor and every layer
before it reaches a score, which makes a whole pass a far stronger test of it
than any single call.

That includes the exponential, which is comparable at all only because this
project specified its own as a polynomial rather than borrowing the host
library. Everything above it -- the softmax and the gate -- calls it, so an
exponential that differed between architectures would have made every
softmax in the engine incomparable.

The wide one deliberately does not use the instruction that sums a whole
vector in one step, for the same reason the first tongue does not: that
answer differs in the last bit, which makes it a different specification
rather than a better implementation of this one.

**What is not covered: the hands.** Everything above the arithmetic and the
conducting is still first-tongue only -- the sampler, the tokenizer, the
thinking loop, and every one of the hands. This is where the port stops being
a translation, because **x86 reaches devices through a separate address space
with its own instructions and this architecture has no such thing** --
everything here is memory-mapped. The hand that touches ports exists in one
form on one machine and collapses into ordinary memory access on the other
two, so the catalogue of hands is genuinely not identical across machines.
That is survivable only because the machine reads its catalogue rather than
being told it, and it means the instruction (`301`) must not assume any
particular hand exists.

**The third architecture is not begun, and three of its ground rules are now
measured rather than guessed.**

**Its branches cannot be written as branches.** Confirmed again on
2026-08-03: with relaxation and compressed instructions both switched off, a
conditional branch to a label in the same file still leaves a relocation
behind, and the extracted bytes encode a branch to the instruction's own
address. With no linker, every loop becomes a silent infinite one. All
control flow goes through the word emitter (`054`), which is why that tool
was built.

**Its vector hardware is absent on the processor its board names.** Measured,
not assumed: a bare probe that executes one vector-configuring instruction
and then says so gets no further on the `rv64` processor `032` specifies.
So the fast matrix product cannot be a vector kernel on this architecture
without changing which machines the seed runs on.

**And where the hardware does exist, it is switched off.** The same probe,
on a processor built with vectors, still fails -- until the vector unit is
enabled through a machine-mode control register first. That is a privilege
question rather than an instruction-set one, and it depends on what level
the firmware hands over at, which differs between the three firmwares this
project already knows hand over three different ways.

The consequence is a decision this ticket has to make rather than discover
later: **on RISC-V the fast product should be four totals kept in ordinary
registers rather than in a vector register.** Same second specification, same
lane assignment, same final combining order, so it stays comparable to the
first architecture's fast kernel bit for bit -- and it needs no extension, no
privilege, and no negotiation with firmware. A genuinely vectorised one can
follow later, for chips that have the hardware, as a fourth kernel rather
than as a replacement.

**The harness works and the shape of it is right.** The host cannot test
these by calling them -- it does not speak this language -- so `src/100`
records what the FIRST tongue produces, bakes those exact bit patterns into a
payload alongside the second tongue kernels (`src/101`), boots a real ARM
machine, and has it compare its own results **as integers**, so nothing
rounds and "close" cannot happen.

The whole-pass check (`src/109`, `src/110`) is the same shape one level up:
the entire model is carried as raw words, the scores come from the first
architecture's own conducting, and the comparison is again between integers.
The weights are never turned into text and back at any point, which is the
defect `107` exists because of, avoided by not doing the thing.

It also makes the reference vouch for itself before trusting it. A first
architecture that had quietly regressed would otherwise silently become the
standard the second one is measured against, and a matching pair of wrong
answers reads exactly like a working port.

**Where it stands: every answer agrees, bit for bit, on a real ARM
machine.** The matrix product plain, the matrix product four at a time, and
the normalisation all reproduce the first architecture exactly -- which is
the claim no tolerance can make, and the reason the exact specification is
worth keeping even now that the fast one is what runs.

**The disagreement that was reported earlier was the harness, not the
port.** It carried 256 numbers of test data of which 3 were distinct,
because the conversion from a number to its exact bits silently began
returning the same answer once its loop went hot. The machine computed
correctly over wrong numbers and was very nearly recorded as broken. See
`notes/023`; the shared conversion is now `src/107` and carries its own
hot-loop check, and this test runs that check before trusting its own
inputs.

## Six errors on the way here, and what each taught

**One: the first instruction must be ours.** Firmware enters at offset zero,
so emitting the kernels first meant the machine entered the matrix product
with the firmware registers as arguments -- which happened to mean "no rows",
so it returned immediately, and the firmware, handed control back, carried on
booting to its own shell. Nothing failed and nothing was reported.

**Two: there is nowhere writable inside the payload.** Firmware that honours
section rights maps the code read-only, so a results buffer in `.text` faults
on some machines and not others. It lives on the stack now, which is the same
lesson `033` learned for its memory map.

**Three: a CALL to an exported name is a note for a linker.** The kernels
carry `.globl` because the hosted build needs them exported to load the
library. Every call into them left a relocation; extraction dropped it; the
branch offset stayed zero; and a call whose offset is zero is a call to
ITSELF. The machine printed its first mark and span forever -- no fault, no
exception, no dump, because firmware never regained control.

This is the third appearance of one trap, and the rule is now stated to cover
all three (`notes/023`): nothing in a payload may REFER to an exported name
-- not read from it, not jump to it, not call it. A file that needs its
exports for a hosted build has them stripped by the payload that embeds it.

**Four, and it was not mine: the RAM disk was full.** An unrelated project
had filled `/dev/shm` to capacity, so the extraction step wrote a truncated
binary -- exactly 4096 bytes of a 7988-byte program, a round number that is
the signature of a write cut off midway. The machine booted half a program,
ran off the end of it, and took a synchronous exception that the firmware
handler asserted on.

**Five: the stack pointer cannot be moved by an arbitrary number.** That
instruction takes a twelve-bit number, or a twelve-bit number shifted up by
twelve, and nothing in between -- so a workspace of 7376 bytes is a size it
cannot express and 8192 is. Loud, immediate, and cost nothing, which is what
an assembler refusing something is for. The rounding now happens where the
size is decided rather than where it is used.

**Six: a register read before saying something is a register the firmware has
destroyed.** Two of the payload's reported numbers were loaded into `x13`
before their labels were printed, and the console call overwrote them on its
way out -- the convention lets a called routine keep `x9` through `x15`. The
payload then reported what the firmware had left behind: eight, in the run
that found it, with nothing actually disagreeing at all.

It looked exactly like a real value, which is this project's oldest shape of
defect wearing new clothes. The counters survive the same calls only because
`x19` through `x28` are the ones a called routine must give back, and that
was luck of habit rather than a decision until now.

**And the diagnostic that lied.** For a while the evidence said the machine
stopped before its first mark. It had not; the shell command reading the log
printed only the remainder of the matched line, and everything after the
greeting sat on later lines. A bad reading of the evidence cost more than any
of the defects. The lesson is the project own: a tool that answers
confidently is worth checking before the thing it is reporting on.

## What a passing run is now required to include

A test that can only ever report agreement has not shown it would notice a
disagreement. So the whole-pass payload carries a conducting built wrong on
purpose and requires the machine to report that it differs.

The wrongness is chosen to be the exact class of defect this ticket exists to
catch, rather than something a compiler would refuse: the feedforward's two
projections are handed to each other's kernels. Both tensors are identically
shaped, so nothing reads outside anything and nothing faults; every kernel
still computes precisely what it is asked. Only who-is-given-what changed.

It moved all 192 scores. That number is the argument that the 192 agreements
beside it mean something.

## Intended behavior

The engine written for each assembly language in modern use — three covers the
majority of machines — all three carried on the same chip.

## Suggested implementation steps

1. Port the arithmetic first, since it is nearly all of the work and all of the
   speed. The reference comparison built in `103` is what makes this tractable:
   each port is correct when it agrees with the same fixture the first one agreed
   with.
2. Be honest about which half is a translation and which is a rewrite. The plain
   version of the arithmetic ports almost mechanically. The fast version does not:
   the vector instruction sets on the three architectures have nothing in common,
   the register counts differ, and the extension that provides them is not even
   guaranteed to exist on RISC-V. Budget the fast half as three separate pieces of
   work rather than one done thrice.
3. Port the hands next, and expect one of them to change shape rather than
   detail. **x86 has a separate address space for talking to devices, reached by
   its own instructions; the other two do not** — everything there is
   memory-mapped. So the hand that touches ports exists in one form on one
   architecture and collapses into memory access on the others. The catalogue of
   hands is therefore not identical across machines, which is survivable because
   the machine reads its catalogue rather than being told it — but it means the
   instruction (`301`) must not assume any particular hand exists.
3. Keep the three implementations recognisably the same program. Where they must
   differ, say why in a comment beside the difference — a future reader needs to
   know whether a divergence is a necessity or an accident.
4. Do not attempt to share code between them by inventing an abstraction layer.
   There is no compiler here; a layer would have to be written three times as
   well, and would then be three things instead of one.
5. Measure each with `106` and keep the results side by side. The architectures
   will not perform alike and the difference decides which boards are viable.
6. Decide what happens for a processor outside the three. Bundling an engine for
   it before flashing, or working it out on arrival, are both acceptable; a
   machine that cannot think until somebody helps it is the one case where the
   seed is not self-sufficient, and it should be named rather than discovered.

## Blocks

`501`, and phase 6 on any board that is not the first target.

## Blocked by

All of phase 1, and phase 2 for the hands.

## Related documents

`docs/010-datapath-the-mind.md` — writing the same program three times as the
price of not having a compiler.
