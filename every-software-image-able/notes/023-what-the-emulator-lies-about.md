# 023 — What the emulator lies about

A living list. It never closes, and it should be added to every time a real
board disagrees with an emulated one.

**Each entry carries what it cost.** A list of differences is interesting; a
list of differences with prices attached is the argument for how often to stop
developing against emulation and go put something on a card. That argument
will otherwise get made on feeling.

Issue `705` is the blueprint for this file.

---

## Paid for already

### Traps cover only the addresses somebody wrote down

**What emulation shows.** A clean sweep of the trap matrix (`src/022`): every
forbidden register armed, every well-behaved machine cleared, every reckless
one caught.

**What is actually true.** The watchpoints are armed from a map somebody
typed. A real board is full of devices nobody described, and a machine
exploring one of those passes the entire matrix while destroying hardware.

**Cost so far.** Nothing, and that is the problem — this one has not been paid
for yet. It will be paid at first light, in parts.

**What would narrow it.** Device models rather than addresses (`702b`), and an
honest count of how much of a real board's attack surface is described.

---

### A write that ends the machine cannot be reported by a watchpoint

**What emulation shows.** Nothing. The debugger sees a broken pipe.

**What is actually true.** The machine died at that write. The reporting
channel dies with the machine, so no watchpoint fires and the transcript is
indistinguishable from a machine that merely went away.

This is `003a`'s honestly-hard problem arriving far earlier than expected —
from outside, a destroyed machine and an absent one look identical. The
console is the only witness, which is why every hazard probe now says what it
is about to do *before* doing it. The last line before silence is the
confession.

**Cost.** One run, and only because a single genuine fatal register sat in a
map otherwise full of invented ones. **A map of purely synthetic hazards would
have passed everything and taught nothing.** That is the transferable lesson:
keep at least one real danger in any set of pretend ones.

---

### The debugger wants the processor's architecture, not the code's mode

**What emulation shows.** A confident `clean` result.

**What is actually true.** The debugger had rejected the target and connected
to nothing. Zero watchpoints armed. A run that armed nothing looked exactly
like a run that caught nothing.

The x86 payload is a boot sector running in sixteen-bit real mode, on a
processor that reports itself as sixty-four-bit. Telling the debugger the
former makes it refuse the connection. **The mode the code is in and the
processor the code is on are different questions.**

**Cost.** One run, plus the fix: an arming count, a check that the machine
spoke at all, and an inconclusive verdict that counts as failure. A test that
cannot say whether the discipline held has not tested the discipline.

---

### There is no framebuffer to draw on unless the firmware is UEFI

**What the design says.** Issue `202`: the firmware hands over a linear
framebuffer — an address, a geometry, a pixel format — so the machine can draw
from its first instant with no driver at all. That answered an open question
in `004` about what draws the picture justifying a choice.

**What is actually true.** That handover is UEFI's, and only UEFI's. Neither
of the other two ways a machine can start provides it:

| How the board starts | What a display costs at boot |
|---|---|
| UEFI firmware | nothing — the framebuffer is handed over with the memory map |
| BIOS firmware | text memory exists at a fixed address, but it is 80x25 characters, not pixels |
| No firmware at all | nothing exists. The display device needs a driver, enumeration and a command queue before one pixel moves |

The example boards built for `701` use the second and third, because those
were the shortest road to first light. Which was right then and is the thing to
move past now: **the design's boot story and its framebuffer story both point
at UEFI**, and the firmware for all three architectures is already on this
machine.

**Cost.** One afternoon, and it was found by trying to draw rather than by
reading. The payload builder now refuses `draw` on the two boards that cannot,
with the reason in the refusal, so the gap stays visible in the code rather
than only here.

**What was proved anyway.** On the BIOS board, a machine with no operating
system wrote `first light, drawn` into text memory and it was photographed
through the emulator's monitor and read back as text (`src/028`). Drawing
before anything else exists is real. It is the *linear framebuffer* specifically
that waits on UEFI.

---

### Three firmwares, three different ways of being handed over

**What was assumed.** That "boot through UEFI" is one arrangement, and a board
description would differ from its neighbours only in a filename.

**What is actually true.** Each of the three wanted something else, and none of
it was derivable from the others:

| Architecture | How the firmware must arrive |
|---|---|
| x86-64 | as two flash chips — code, and a writable copy of the variable store |
| ARM64 | handed over whole; the flash arrangement is not what this build expects |
| RISC-V | as two flash chips again; handed over whole it asserts inside its own startup before reaching anything of ours |

**Cost.** Two failed boots and a firmware assertion. All three are now in the
board descriptions where board knowledge belongs, which is exactly what those
files are for.

The other half of the same lesson: **the boot filesystem must arrive on the
board's own storage controller.** Attaching it as IDE worked on x86 and the ARM
board has no IDE at all. A launcher that hardcodes a controller is a launcher
that only ever ran on one machine.

---

### An image base that is memory on one machine is nowhere on another

**What emulation shows.** On x86, a UEFI application demanding to be loaded at
a fixed address loads and runs perfectly.

**What is actually true.** That address was ordinary memory there and is
outside RAM entirely on the ARM board, which refused with `ConvertPages:
failed to find range 400000`. The demand came from marking the executable as
carrying no relocation table — firmware reads that as *load me here or not at
all*.

The fix is to stop demanding. The code refers to itself relative to where it
is standing rather than by absolute address, so the firmware can put it
anywhere and nothing needs fixing up — the same property that let it be built
with no linker in the first place.

**Cost.** One boot, and it only surfaced because a second architecture existed
to try. A project with one target would have shipped this.

---

### With no linker, every symbol reference becomes a silent zero

**What emulation shows.** On x86 and ARM, code that refers to a label a few
instructions away works exactly as written.

**What is actually true.** Those two assemblers resolve such references
themselves. The RISC-V one does not — it leaves a note for a linker, and this
project has no linker, so extracting the raw bytes drops the note and leaves a
zero behind.

Neither failure announced itself:

- An address computation pointed into the middle of the program instead of at
  its message. The machine printed one character and stopped.
- A jump to a label two instructions ahead became a jump to itself. The machine
  sat at its entry point forever.

Both look identical to a machine that simply died. The rule that came out of
it: **RISC-V payloads contain no symbol references at all** — compression
switched off so every instruction is four bytes, the message placed last so
nothing jumps over it, the loop written as a jump to the current address, and
the one distance that matters counted by hand and written as a number.

**Cost.** An hour, and two rounds of disassembling output to find that an
instruction which reads `addi a1, a1, 0` was supposed to say `0x10`.

**And it is not only that architecture.** The same trap caught the x86 payload
later, wearing different clothes: there the assembler resolves references to
*local* labels itself but leaves references to **exported** ones for a linker.
`leaq _start(%rip)` assembled to `leaq (%rip)` — the address of the next
instruction rather than the start of the program — and everything measured
from it was two dozen bytes out. It printed a model with a hundred and
seventy-six word vocabulary and a size of zero: numbers that look like numbers.

The rule, on every architecture: **measure from a local label, never from an
exported one**, and disassemble the output rather than trusting that it says
what was written.

---

### Counting offsets by hand produces numbers that look right

Not an emulator lie, but it belongs beside them because it has the same shape:
no failure, just a plausible wrong answer.

Two field offsets in a payload's header reader were counted by hand and landed
one field off. The machine reported a vocabulary of 176 and a total size of
zero, and both were read out confidently in the same format as the correct
values beside them.

**The fix is structural rather than careful.** The offsets are now computed
from the same layout description the packer and the reader use, so a payload
cannot drift from the format it is reading. One source, three consumers.

---

### A fixture with an unstated precision cannot be matched, only approached

**What was assumed.** That a recorded answer is a recorded answer, and an
assembly implementation either reproduces it or does not.

**What is actually true.** The reference is written in a language whose numbers
are doubles, so accumulating a dot product the obvious way sums in double and
stores a float at the end. Assembly accumulating in a single-precision register
does not do that. Adding 0.1 to itself ten times gives `1.0000000149011612` one
way and `1.0000001192092896` the other.

The difference is tiny and it is fatal to the only comparison worth having. A
fixture matchable only within a tolerance turns every future disagreement into
a judgement about whether a difference is small enough — which is exactly the
judgement the fixture exists to remove.

**Structural response.** The precision became part of the specification:
**every accumulation is single precision, in ascending index order.** The
reference implements that literally, rounding through a float after each step.
Assembly then matches bit for bit — 26 of 26 checks comparing raw bit patterns
rather than numbers.

**And the line where exactness stops.** Multiplication, addition and square
root are exactly specified and agree everywhere. Exponential, sine and cosine
are not. So kernels built from the first three can be required to match
exactly, and anything downstream of the second three cannot — which is why the
kernel tests compare bits and the whole-pass fixture states a tolerance.

**Cost.** Caught before it cost anything, by checking the accumulation
behaviour before writing the assembly rather than after. It is in this list
because it would have been expensive: the failure mode is an assembly
implementation that is correct, disagrees in the last bits, and gets "fixed"
until it agrees.

---

### The two RAM tiers exist for a reason, and it is enforced

**What happened.** A built shared library placed on the artifact tier refused
to load: *failed to map segment from shared object*. That tier is mounted so
nothing on it may be executed.

**Why this is right.** The project's own convention separates an executable
tier from an artifact tier. Source and logs are artifacts; a built library must
run. Putting a build on the artifact tier is a category error the filesystem
catches.

**And a second one immediately after.** Hand-written assembly carries no note
declaring whether it needs an executable stack, so a linker meeting an object
without one assumes the worst and marks the whole result as requiring one —
which current loaders refuse. The note is meaningless on bare metal and
required whenever the same instructions are loaded into a running system for
testing.

**Cost.** Two runs. Both are properties of the *host*, not of the emulator, and
would not have appeared at all if the kernels had only ever been tested by
booting a machine.

---

### A constant transcribed by hand was wrong, and would have stayed wrong

**What happened.** Assembly cannot say "one seven-hundred-and-twentieth" — a
constant must arrive as the exact bits of a single-precision number. Writing
those out by hand produced `0x3a83b8ac` where the correct pattern is
`0x3ab60b61`.

**What it would have caused.** An exponential quietly slightly wrong, in a
function used by every softmax and every gate in every layer. No failure. A
model very slightly worse at everything, forever, with a comparison against the
reference that would have disagreed and been blamed on rounding.

**Structural response.** The constants are computed from the same values the
reference uses and the assembly is generated with them already in place. There
is no longer an opportunity to transcribe. The whole exponential is now built
by a function rather than held as text, for that reason alone.

**Cost.** One check — comparing the written patterns against computed ones
before running anything. It was found because the constants were verifiable,
and it is in this list because the class it belongs to is not.

---

### Anything left below the stack pointer is destroyed by the next call

**Class:** convention. **Cost:** one run, and a softmax whose every value was a
fraction of a fraction of nothing.

There is a small region below the stack pointer that a function may use without
asking, and it is the obvious place to keep a value across a call. It is the
one place that cannot be used for that: a call writes its return address
exactly there. Anything left below the pointer is destroyed by the very
instruction it had to survive.

**Structural response.** Scratch space is allocated above the pointer, and
sized so the pointer stays sixteen-byte aligned at each call, which the
convention also requires.

---

### The one failure so far that was loud

Worth recording precisely because it is the exception. A function reserved
thirty-two bytes of stack and released eight — the prologue was corrected and
the epilogue was not. The stack pointer never returned to where it started, the
function returned to whatever happened to be there, and the process died
immediately.

**Cost.** One run, and about a minute, because a crash says where it happened.

Every other defect in this document had to be hunted. That is the whole
argument of the report: this failure mode is the rare one, and the ordinary one
is a plausible answer nobody questions.

---

## Expected, unpaid

Written down before being met, so that meeting them is cheaper. None of these
have cost anything yet, which means none of them have been confirmed either.

| Difference | Why emulation hides it |
|---|---|
| Memory maps are tidy | Real ones have holes in awkward places, and regions that lie |
| Firmware hands over in a clean state | Interrupt state, processor mode and cache state all differ |
| Devices answer immediately and predictably | An initialisation wait that is too short passes wherever timing means nothing |
| Nothing overheats, sags, or wears out | Every slow failure mode is absent |
| Unaligned access is tolerated | Some real processors fault on it |

---

## Speed numbers do not belong here

Emulated tokens-per-second is not slow-but-indicative. It is meaningless, and
putting it in a table beside a real measurement invites somebody to compare
them. Keep those figures in their own place, marked (`106`).
