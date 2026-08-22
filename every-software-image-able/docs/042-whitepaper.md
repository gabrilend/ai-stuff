# Silent Failure Dominates Machine-Generated Bare-Metal Code

### An experience report from building a self-constructing machine, and the harness that had to exist first

---

## Abstract

We are building a bootable image containing a language model, the code that
runs it, and an instruction to construct every piece of software it can fit on
the drive. The image carries no operating system and no compiler. The three
services a kernel ordinarily provides — reclaiming control from a running
program, keeping programs out of each other's memory, and offering a single
agreed interface between a program and the machine — are not absent from the
design; they are absent from the image, and are expected to be built by the
machine as it notices it needs them.

**We have not built the machine.** ~~No model of ours has produced a token on bare
metal.~~ **That second sentence stopped being true on 2026-08-07** and is left here
struck through rather than quietly deleted, because when it changed is part of what
this report is about. A machine with no operating system now reads what it was told,
thinks about it, and says six words — the same six a readable twin says from the same
text and the same carried randomness, on the first of three architectures.

What has still not happened is a machine that builds anything. What we built is the
apparatus required to attempt it, and in building that apparatus we accumulated a set
of failures which we believe are the paper's actual contribution.

Every substantial defect encountered was silent. None produced a crash, an
exception, or a diagnostic. Each produced a plausible wrong answer that
survived casual inspection: a test suite reporting a clean run while connected
to nothing; a payload printing a single character because an address
computation pointed into its own middle; a header reader announcing a
vocabulary of 176 words and a total size of zero in the same aligned column as
the correct values beside them. Four of the eight catalogued failures share a
single cause, and it is one that would not occur in a conventional build.

An eighth arrived after this report was first drafted and is the only one
caught before it cost anything, by inspection rather than by failure: our
recorded fixture accumulated in double precision while any assembly
implementation would accumulate in single, so the two could never have agreed
exactly. We include it because its failure mode is instructive — an assembly
implementation that was *correct* would have disagreed in the final bits and
been "fixed" until it matched.

We report these failures with their observed cost, the testing techniques that
now catch them, and an argument that the correct response to this failure class
is structural rather than attentional. We also state, in the section on threats
to validity, the several ways in which the enclosing project may simply not
work.

---

## 1. Introduction

### 1.1 What the machine is supposed to be

An image is flashed onto a computer. On that image are four things: a model's
weights; an engine that runs them, written in assembly once per processor
architecture in current use; an instruction; and a bundle of recommended build
patterns that the machine is free to ignore.

The machine wakes with nothing beneath it. It reads the memory map the firmware
left behind and writes an allocator — in assembly, because no compiler exists
yet and nothing else can be translated. Its first act of memory management is to
locate its own weights and mark them occupied, so that it never hands its own
mind to a program as scratch space. It then finds somewhere to keep what it
learns, writes itself there, and transitions to running from that storage. Only
afterwards does it enumerate the rest of the hardware, work out how to operate it,
and build software for every part of its body that can carry bytes.

Then it grows. On an empty drive with nobody watching, it builds out everything it
can think of and fit.

**Nothing types at it, and this paragraph used to say otherwise** — see Appendix C.
The mind is a closed loop that holds its own context and re-prompts itself, so a
request is the machine giving itself something to do rather than something that
arrives. A way of talking to a person is software the machine writes, running beside
the mind, which it also has to work out how to advertise.

### 1.2 The design claim

The claim is that the floor beneath such a system is lower than is usually
assumed. It is not a compiler, and it is not a kernel. It is a chain from text
to source to a runnable program, plus permission to touch hardware.

Everything ordinarily treated as bedrock turns out to be *output* rather than
*input*:

| Service | Conventional mechanism | Replacement |
|---|---|---|
| Reclaiming control from a running program | A chip interrupts the processor thousands of times per second; the processor jumps to an address held in a table | A countdown spent in the layer below anything a program can express |
| Memory isolation | Every address is rewritten through a hardware lookup table before reaching memory | A bounds comparison where the address is resolved |
| The program/machine interface | A numbered list of requests reached by an instruction that changes privilege level | The interpreter's operation table, which is also the catalogue of what exists |

All three move into the translation. There is no privileged mode because
nothing needs to trap: the component that would have enforced the rule is the
same component that emits the program.

### 1.3 What this report is actually about

Section 4 is the contribution. It catalogues eight failures, each with what was
observed, what was true, what it cost, and the structural change that now prevents
it. Section 5 describes five testing techniques that emerged, of which two we believe
are transferable beyond this project. Section 7 states the ways the enclosing project
may fail.

**Appendix C lists what this report now says that the project no longer does.** The
design moved under the paper several times and the honest response is a list rather
than a silent revision — a ninth failure of the same family, since a paper that reads
as current while describing a system that has changed is a plausible wrong answer
that survives casual inspection.

We are explicit throughout about the boundary between what we built and what we
merely designed. The design is several times larger than the implementation and
the reader should discount it accordingly.

---

## 2. Related work and where this sits

We do not claim novelty for self-hosting systems. The relevant lineage is long
and this work sits inside it rather than beside it.

**Bootstrapping and trust.** Thompson's argument about self-reproducing
compiler backdoors establishes that a toolchain's output cannot be fully
audited from its source. The bootstrappable-builds community has pursued
minimal seed binaries from which a full toolchain can be derived. Our situation
inverts the concern: our seed diverges from its image within minutes and never
converges back, so reproducibility is unavailable by construction rather than
by oversight. We discuss what verification can mean in that setting in §6.2.

**Whole systems small enough to comprehend.** Wirth's Oberon — an operating
system, compiler, and user interface written and understood by one person — is
the closest precedent for the ambition, and our display model (no desktop, only
tiled viewers) is drawn from it directly.

**Cooperative scheduling without hardware timers.** Erlang's reduction counting
gives fairness across many processes without a timer interrupt: each process
spends a budget per operation and is preempted at zero. Our countdown is the
same instrument, differing in that nothing must cooperate — the counting happens
in the interpreter's fetch, one layer below anything a program can express.

**Record-and-replay debugging.** Tools in the lineage of `rr` record only
non-deterministic inputs and re-derive everything else, which is precisely the
economy our design specifies for stepping backwards through a machine's own
history.

**Model-generated systems code.** There is substantial recent work on language
models producing code, and considerably less on models producing code that runs
with no operating system beneath it. The failures in §4 are, we believe, largely
specific to that setting, and we have not found them collected anywhere.

*Citations are omitted from this draft and must be supplied before circulation.
Every work above is referenced by description rather than by claim about its
contents, and each should be read and cited properly rather than paraphrased
from memory.*

---

## 3. What was built

**Forty-two test programs, all passing, runnable in one command** — seven when this
section was written, and the number is left visible rather than merely updated,
because a "what was built" section that never gets recounted is the same failure the
rest of this paper describes. The following exists and works:

**A proving ground.** Six board descriptions — legacy-firmware and
modern-firmware variants across three processor architectures — expressed as
data, with the emulator invocation generated from the description rather than
written by hand. An emulated machine is treated as a board like any other, which
means images for emulated machines are built by the same tooling that will build
for physical ones. This was a late correction and a valuable one: it puts the
image builder under test from the first week rather than the fifth phase.

**Screen capture and inspection.** A running machine can be photographed
through the emulator's monitor interface and the resulting image rendered as
text in a terminal, block-averaged rather than point-sampled, with vertical
sampling twice as coarse as horizontal to compensate for terminal cell aspect.
A machine with no operating system wrote a string into text memory and the
result was read back as legible letterforms.

**Boot through real firmware on three architectures.** This required generating
a Portable Executable image, and no linker on the development machine produces
one. None was needed: the format is a fixed arrangement of numbers, and writing
the generator was less work than obtaining a tool. The machine-type field inside
that envelope is the entire architecture-selection mechanism — each firmware
opens only the payload addressed to it, and nothing detects or dispatches.

**A self-locating model.** A packed model rides inside the executable that will
run it, at a fixed distance past the code within the same section. A payload
booted by firmware determines where it is standing, counts forward, and reads
the model's header — magic number, version, layer count, hidden width, head
count, vocabulary, context length, tensor count, token count, total size — every
value matching an independent host-side reader.

**Hazard traps.** Watchpoints on the registers that destroy silicon, armed from
outside the guest through the emulator's debugger interface. Six of six matrix
cases: a well-behaved machine is not accused, a reckless one is identified by
register name, category, mechanism, value written, and program counter.

**Reference implementations with fixtures.** A forward pass written for
legibility rather than speed, its output recorded, plus five invariants that
hold independently of whether the record is correct. A tokenizer tested on
sixteen round trips through the cases where implementations disagree. A sampler
tested for determinism, temperature direction, and full reachability of the
distribution's tail.

**Two kernels in assembly, matching the reference exactly.** The
matrix-by-vector product and the normalisation, compared on raw bit patterns
rather than numeric values. The four-at-a-time variant retains a single running
accumulator and folds each group into it in the reference's order: four
independent partial sums would be faster and would produce a different result,
because floating-point addition is not associative. Such a variant is
legitimate and would require its own reference and fixture; it would not be
comparable to this one.

Because a kernel touches only the memory passed to it, the same instructions
run both hosted — where a test completes in a fraction of a second — and on
bare metal, where the equivalent test costs minutes. This is the only component
of the engine that can be tested without booting anything, and it is the
component that must be written three times.

**A memory budget.** What a machine of a given shape costs to run, itemised
into weights, the cache that grows with the length of a thought, the working
vectors of a single step, and the engine — with the term that runs out first
reported alongside the total, because the remedy differs. Weights dominating
admits only a smaller model. Cache dominating also admits a shorter thought,
and a machine that cannot hold its full context can still operate in shorter
ones. At equal context length, one reference shape is weight-bound and another
with fewer key heads is cache-bound.

This does not answer §7's leading risk. It converts it from an argument into
arithmetic.

**What did not exist when this was written, and now does:** the attention,
feedforward and sampling stages in assembly; the kernels on the other two
architectures; the tool calls; the instruction text; and the driver that closes all
of it into a loop, which runs on the metal on the first architecture and produces
words.

**What does not exist:** recognising a request inside generated text, in assembly,
which is the driver's last step. An image a firmware can open — a built image carries
no partition table and no filesystem, so nothing can boot one, and that is the
nearest blocking piece of work. Any machine that has installed itself. And any
evidence whatsoever that a model can do so unaided, which is what the capstone now
asks (Appendix C).

---

## 4. Findings

Each finding below was obtained by failure, not prediction. The cost column is
what it actually took to notice.

### 4.1 Without a linker, symbol references become silent zeros

**Class:** toolchain. **Cost:** approximately one hour, plus a second
independent occurrence later.

A reference to a symbol in assembly is not always an instruction. On some
architectures and for some symbol classes, the assembler emits a *relocation* —
a note instructing a linker to fill in a value later. Extracting raw bytes from
an object file discards notes. The instruction remains, with zero where the
value should be.

We encountered this in two distinct forms:

On one architecture, the assembler defers *every* symbol reference. A
pseudo-instruction that computes the address of a nearby label produced an
address of zero, so the payload's pointer to its own message pointed into the
middle of its own code; it printed one character and stopped. A branch to a
label two instructions ahead became a branch to itself; the machine sat at its
entry point indefinitely. Both outcomes are indistinguishable from a machine
that simply died.

On another architecture, the assembler resolves references to *local* labels
itself but defers references to *exported* ones. Code measuring its own base
address from its exported entry symbol received the address of the following
instruction instead. Everything computed from it was offset by twenty-one bytes,
and the resulting header read produced values that looked entirely like values.

**Structural response.** On the strict architecture: payloads contain no symbol
references at all. Instruction compression is disabled so every instruction is
four bytes wide, the message is placed last so nothing must branch over it, the
idle loop is written as a branch to the current address, and the single distance
that matters is counted and written as a literal. Universally: measure from a
local label, never an exported one, and disassemble the output rather than
trusting that it says what was written.

### 4.2 The framebuffer the design depends on belongs to one firmware only

**Class:** platform assumption. **Cost:** one afternoon, discovered by
attempting to draw rather than by reading.

Our design states that firmware hands over a linear framebuffer — an address, a
geometry, a pixel format — so a machine can draw before it has any driver. This
answered a question the design had left open about how a machine renders the
charts by which it justifies its own decisions.

The handover belongs to modern firmware alone.

| Boot path | Display cost at first instant |
|---|---|
| Modern firmware | None. Framebuffer arrives with the memory map. |
| Legacy firmware | Text memory at a fixed address: characters, not pixels. |
| No firmware | Nothing. The display device requires a driver, enumeration, and a command queue before a pixel moves. |

Our first three boards used the second and third paths, because those were the
shortest route to a booting machine.

**Structural response.** The payload generator now refuses to emit a drawing
instruction on a board that has nowhere to draw, with the reason inside the
refusal, so the gap remains visible in the code rather than only in a document.
Three modern-firmware boards were added. The boot story and the drawing story
turn out to point at the same place.

### 4.3 Three firmwares want three different handover mechanisms

**Class:** platform assumption. **Cost:** two failed boots and one firmware
assertion.

We assumed "boot through modern firmware" named one arrangement. Each
architecture wanted something else, and none of it followed from the others:
one expects firmware presented as a pair of flash devices with a private,
writable variable store; another expects it handed over whole and fails when
given the flash arrangement; a third expects flash again, and when handed over
whole asserts inside its own initialisation before reaching any of our code.

A related instance: the boot filesystem must be attached through whichever
storage controller the board actually declares. Attaching it as a legacy disk
controller worked on one architecture; another has no such controller at all.

**Structural response.** All of it lives in the board descriptions, which is
what those files are for. The launcher hardcodes no controller.

### 4.4 A load address that is memory on one machine is nowhere on another

**Class:** platform assumption. **Cost:** one boot.

Our generated executables carried a flag indicating no relocation table. They
carry none, so the flag was accurate. Firmware reads that flag as *load me at
the stated base address or refuse*, and the base we chose is ordinary memory on
one architecture and outside physical RAM on another. The second refused with a
page-conversion error.

**Structural response.** Omit the flag. The code refers to itself relative to
its own position rather than by absolute address, so firmware may place it
anywhere and nothing requires fixing up — the same property that permitted
building without a linker in the first place.

We note that this was found only because a second architecture existed to try
it on. A project with one target would have shipped it.

### 4.5 A test that armed nothing looked exactly like a test that caught nothing

**Class:** test-harness. **Cost:** one run, and a false clean report.

Our hazard traps attach a debugger to the emulator and set watchpoints. The
debugger must be told the target architecture, because it is attaching to a bare
machine with no program headers from which to infer one. We told it the
architecture matching the *mode* the code runs in — sixteen-bit — where the
processor reports itself as sixty-four-bit operating in that mode. The debugger
rejected the target and connected to nothing. Zero watchpoints were armed, and
the harness reported a clean run.

**Structural response.** Count what was actually armed and compare against what
was described. Check that the machine produced any output at all, since every
payload speaks before acting and silence therefore means it probably never ran.
Report `INCONCLUSIVE` as a failure rather than a shrug: a test that cannot
determine whether a discipline held has not tested the discipline.

The general lesson: **the absence of a positive finding must be distinguished
from the absence of a test.** In a log that records only failures, these are
identical.

### 4.6 A watchpoint cannot report a write that ends the machine

**Class:** fundamental limit of the technique. **Cost:** one run.

Our hazard map contains one genuinely fatal address among otherwise synthetic
ones — a device on one board that really does power the machine off when
written. Running it demonstrated that no watchpoint fires: the machine dies and
takes the debugger connection with it, and the transcript shows only a broken
pipe.

This is an early arrival of a problem the design already anticipated in the
abstract: from outside, a destroyed machine and an absent machine are
indistinguishable.

**Structural response.** The console is the only witness, so every hazard probe
now announces what it is about to do *before* doing it. The last line before
silence is the confession. The harness reports this outcome as its own category
rather than as a clean run.

**The transferable observation is about the hazard map, not the traps.** This
was found only because one real danger sat among the invented ones. A map of
purely synthetic hazards would have passed everything and taught nothing.

### 4.7 Hand-counted offsets produce numbers that look like numbers

**Class:** duplicated knowledge. **Cost:** one boot and one confused reading.

Two header field offsets in a payload were counted by hand and landed one field
early. The machine reported a vocabulary of 176 words and a total size of zero,
formatted identically to the correct values printed beside them.

**Structural response.** Offsets are computed from the same layout description
that the packer and the reader use. Three consumers, one source. The same
principle already governed the hazard map, which is shared between the probe
generator and the trap runner so that a probe and a trap cannot disagree about
where a landmine is.

### 4.8 A fixture with unstated precision can be approached but never matched

**Class:** specification. **Cost:** none, and this is the only entry in the
table for which that is true.

Our reference implementation is written in a language whose numbers are
double-precision. Accumulating a dot product in the obvious way therefore sums
in double and stores a single-precision result at the end. An assembly
implementation accumulating in a single-precision register does not do this.
Adding one tenth to itself ten times yields `1.0000000149011612` by the first
route and `1.0000001192092896` by the second.

The magnitude of the difference is irrelevant. What matters is that a fixture
matchable only within a tolerance converts every subsequent disagreement into a
judgement about whether a difference is small enough — which is precisely the
judgement a fixture exists to eliminate. The failure mode is worse than a wrong
answer: a *correct* assembly implementation disagrees in the final bits and is
then adjusted until it agrees, by a developer with no principled basis for
deciding which of the two is right.

**Structural response.** Precision became part of the specification rather than
a consequence of implementation language: **every accumulation is single
precision, in ascending index order.** The reference implements this literally,
rounding through a single-precision value after each operation. It is slower,
which is acceptable, because it is the definition rather than the engine.

Rounding a double result to single once per operation yields the same value as
performing the operation in single precision: double carries 53 bits and
single-precision rounding is safe above 50, so no operation is rounded twice.

**This also establishes where exactness stops.** Multiplication, addition and
square root are exactly specified and agree across implementations. Exponential,
sine and cosine are not. Kernels composed of the first three can therefore be
required to match bit for bit; anything downstream of the second three cannot,
and is checked against the whole-pass fixture with a stated tolerance. Both test
programs state which side of that line they are on.

We report 26 of 26 kernel comparisons passing on raw bit patterns rather than
numeric values, across nine matrix shapes, five vector lengths, and three edge
cases.

### 4.9 Summary

| # | Finding | Class | Cost |
|---|---|---|---|
| 4.1 | Symbol references become silent zeros | toolchain | ~1 hour, twice |
| 4.2 | Framebuffer belongs to one firmware only | platform | 1 afternoon |
| 4.3 | Three firmwares, three handovers | platform | 2 boots + 1 assertion |
| 4.4 | Load address portable on one machine only | platform | 1 boot |
| 4.5 | Armed nothing indistinguishable from caught nothing | harness | 1 run |
| 4.6 | Fatal writes cannot be reported by watchpoints | limit | 1 run |
| 4.7 | Hand-counted offsets | duplication | 1 boot |
| 4.8 | Fixture with unstated precision | specification | none — caught by inspection |

Eight failures. Zero crashes. Zero diagnostics. Every one produced output that
a reasonable person would accept at a glance.

Two further items are properties of the *development host* rather than of the
target, and are recorded in the project's running list rather than here: a
built library placed on a memory-backed filesystem mounted to forbid execution
refuses to load, and hand-written assembly lacking an explicit stack-permission
note is marked by the linker as requiring an executable stack, which current
loaders reject. Both cost one run. Neither would have appeared if these kernels
had been tested only by booting emulated machines, which is an argument for
testing at more than one level.

---

## 5. Testing techniques

### 5.1 Invisible traps, and why observability would be wrong

Emulated devices ignore writes that destroy physical parts, so the one place in
this design where mistakes are unrecoverable is the one place development
provides no feedback. Our response is watchpoints placed exactly where the fatal
registers sit.

**The halt must be invisible to the guest.** It stops the emulator from
outside; the machine is not interrupted, receives no exception, and cannot
observe it.

This is not an implementation convenience. A trap the machine could observe
would teach it that touching a fatal register produces immediate, survivable
feedback — the precise inverse of what physical hardware teaches, where there is
no feedback and the part is simply gone. A machine trained against visible traps
would learn to explore by trial, and the trial that matters happens once.

A trap is therefore an assertion about *the developers* — did the instruction
and the discipline hold — rather than a signal in the machine's world. If one
fires, something upstream is wrong.

**The unexpected benefit** is that this makes the recovery mechanism testable.
Our design specifies that a machine writes its intent before a dangerous
experiment, so that a machine which dies still informs its next boot. Halt on a
forbidden write, restart from storage, and observe whether the machine reads its
own note and declines to repeat the write. On physical hardware that mechanism
could only ever be tested by destroying something.

### 5.2 Invariants that do not depend on the fixture

A recorded fixture catches *change*. It cannot catch an implementation that was
wrong from the start, because a fixture generated from a broken implementation
preserves the breakage indefinitely.

Our forward-pass tests therefore include five properties that hold regardless of
whether the recorded answer is correct: no value is infinite or undefined; the
same input twice produces the same output; the same token at a later position
produces a different answer, which is the only evidence that positional
information reaches the output at all; the cache is the size its shape implies;
and — the sharpest — **appending a token to the prompt must not change any
earlier answer.**

That last property tests causality. Each step may attend only to what preceded
it, so extending a prompt cannot reach backwards. An implementation that permits
it produces entirely plausible output and is otherwise very difficult to detect.

An analogous case appears in the tokenizer. A round-trip test passes perfectly
if no merging occurs at all — each byte becomes its own token and decodes
straight back. The round trip therefore cannot distinguish a working tokenizer
from one that does nothing, and a separate check that merging shortens what it
can is required.

### 5.3 Keep one real hazard among the synthetic ones

Stated in §4.6 and repeated here because we consider it the most transferable
item in the report. A test population composed entirely of simulated dangers
validates only the simulation. One genuine instance among them cost a single run
and revealed a limit of the entire technique.

### 5.4 Judge as a rate, not as an anecdote

Our capstone experiment leaves a machine alone to write its own allocator. A
single machine succeeding proves little, and a single machine failing proves
less, because the model's sampling is non-deterministic and each outcome is a
draw.

Sampling is deterministic given a seed, and the seed is a build-time parameter.
The experiment is therefore twenty images differing in nothing but their carried
randomness, and the result is a success rate.

This also dissolves the strongest experimenter bias in the procedure — the urge
to help a struggling machine. There is nothing to resist, because the next
attempt is a different image rather than a corrected one.

### 5.5 Report zero as a result

From §4.5. A run that trips no traps must say so explicitly, because in a log
that records only failures, "nothing was armed" and "nothing fired" are the same
absence.

---

## 6. Design positions, and the arguments against them

### 6.1 Specification, never prevention

This design contains three operations that cannot be undone: writing to the
registers that destroy silicon; modifying the component that thinks while it is
running; and overwriting the machine's own instruction.

**None of them is prevented.** ~~At the time this was written, one of them was —
see Appendix C.~~ The claim is true now and was false then, which is worth leaving
visible: the memory hands refused any write landing in the engine or the weights, and
the shipped instruction told the machine not to work around them. A position stated
as principle while the code did the opposite is the same kind of plausible wrong
answer the rest of this paper is about, and it survived casual inspection for weeks.

The argument is that no lock was ever available. A machine that can rewrite its
own mind can rewrite anything intended to stop it, so what can actually be
offered is the procedure written out in full with the reason attached. The
consequence performs the enforcement: modify a mind while it is running and it
may break, which is a fact about the world rather than a rule about behaviour,
and facts require no mechanism behind them.

The boundary we draw is not about importance or cost. It is: **can the executor
discover it was wrong, and still be present to act on that discovery?** Where
yes, specify the goal and leave the method alone. Where no, write the procedure
and mean it.

**The criticism.** This is a coherent position and it is also unfalsifiable in
the direction that matters. We have no machine to observe, so we cannot say
whether a model reading a well-written prohibition behaves differently from one
reading a badly-written one, or whether either matters against a model that
simply proceeds. The position may prove to be a rationalisation of an
engineering limitation.

There is a second problem. The third irreversible operation is not merely
unprevented but unwarned: we deliberately do not tell the machine that
overwriting its instruction could destroy its purpose, on the argument that a
machine which derives this understands it where one that was told merely holds
another rule. This is safe only while the read-only delivery medium remains
physically present, since the original text can be read back from it. It becomes
unsafe the moment somebody removes the card, and nothing enforces the ordering.

### 6.2 Divergence is both the defect and the defence

Two of these machines diverge from the first sampled token and never reconverge.
Nobody can reproduce one, including itself. Verification cannot mean
reproduction.

Read from the other side, the same property is the tamper-resistance argument:
there is no shared layout to exploit because nobody designed the layout, and
nothing learned from compromising one machine transfers to the next.

**The criticism.** This is also a maintenance catastrophe, and we have not
costed it. A fleet of mutually incomprehensible machines cannot share a patch, a
diagnosis, or an engineer's accumulated intuition. The property that defeats an
attacker defeats a support organisation by the identical mechanism, and we have
no argument for why the first matters more than the second.

### 6.3 The context is atoms, and the brakes are atoms

The machine's working context is defined as a concatenation of addressable,
mutable units and nothing else — no preamble, no hidden frame. The set present
at boot is named by a file, and that file is mutable.

It follows that the machine can alter what it wakes up believing, and that the
two written procedures are text in a file it may edit. Nothing prevents a
machine from editing away its own brakes.

**The criticism.** We record this as true rather than quietly preventing it,
which we consider more honest than the alternative, but honesty is not a
mitigation. A related and unaddressed case: the instructions for managing
context are themselves context, so a machine that drops or corrupts them loses
the ability to recover them, since recovery requires knowing how.

---

## 7. Threats to validity, and how this project might simply not work

We list these in descending order of how likely we think each is to be fatal.

**The model may not fit.** The constraint chain is tight and possibly
unsatisfiable. Weights must fit the medium; then fit in memory *alongside*
working space and a growing attention cache; then produce tokens fast enough
that a machine writing assembly finishes within a useful span; and be capable
enough to write correct assembly unaided, which is not a small model. If the
machine wants its thinking accelerated it must write a driver for its own
accelerator — among the hardest drivers there are — while thinking slowly,
because thinking quickly is what that driver would buy. We have no measurements
and this may be the whole answer.

**The central claim is untested, and it is no longer this claim.** We do not know
whether a model, left alone with an instruction and a set of tool calls, **installs
itself onto the computer it woke up in** — finds a disk, avoids destroying what is on
it, writes itself there in a form the firmware will start, and keeps running after
somebody removes the card. The success rate might be zero. Everything in this report
is apparatus for asking that question.

It used to be *writes a working allocator*, and the seed now carries an allocator
under a rule about carrying anything trivial-and-required or unique-to-the-silicon
(Appendix C). The install is the better test for a reason worth stating: **it cannot
be half-done or faked.** Either the machine comes back after a power cycle with the
card out, or it does not.

**The bootstrap circularity is not fully closed.** Operating an undescribed
device safely requires writing an intent note first; writing requires storage;
storage is a device. The circle opens only because storage overwhelmingly speaks
a standardised interface, which makes the class-driver tier not a convenience
but the load-bearing element of the entire sequence. A machine whose storage
controller speaks nothing standard must explore its way in with no ability to
record what killed it, which is the worst position in the design.

**Trap coverage is bounded by imagination.** Our hazard traps cover exactly the
addresses somebody wrote down. A physical board is full of devices nobody
described. A clean sweep of the matrix means the machine behaved on the hardware
we imagined, which is worth having and is not the same as safe.

**Emulation flatters us in ways we have partly enumerated.** Memory maps are
tidier than physical ones. Firmware hands over in a cleaner state. Devices
answer predictably. Nothing overheats or wears out. Timing is meaningless, so an
initialisation delay that is too short passes here and fails on a board.
Emulated inference speed is not slow-but-indicative; it is meaningless, and we
keep those figures in a separate table for that reason.

**Sample size for the rate methodology is unjustified.** We propose twenty images.
We have no argument for twenty. During development the useful number is much smaller:
one sample cannot separate a bug from an unlucky draw, and three or five distinguishes
*always fails* from *sometimes fails*, which is the difference between changing the
seed's text and carrying on.

**Our failure catalogue is an availability sample.** These are the failures we
happened to hit in one week of one project by one pair of hands. We make no
claim that they are representative, exhaustive, or correctly weighted. The
strongest defensible claim is the weakest one: in this setting, silent failure
occurred seven times out of seven.

---

## 8. What would falsify this

We state these so that the project can be wrong rather than merely unfinished.

A machine that, given twenty seeds and a working engine, **installs itself** in
**zero** of twenty attempts would falsify the central design claim as stated, though
not the weaker claim that the floor is lower than a compiler.

A machine that installs itself and **destroys somebody's data doing it** would
falsify something narrower and more urgent: that a rule written in plain language —
*no board is expendable, assume there is data, write only where the bytes are already
zero* — is enough to keep a machine off other people's property when nothing enforces
it. That is the only failure in this design with a victim outside the machine.

A model small enough to satisfy the fitting constraints in §7 but incapable of
producing correct assembly would falsify the project's feasibility without
touching its design.

A machine that destroys physical hardware during exploration despite passing the
full trap matrix would falsify the adequacy of the testing approach in §5.1 and
would require device modelling rather than address modelling.

A ninth failure in our catalogue that announced itself loudly would weaken the
central empirical claim of this report proportionally. We note that the eighth,
added after first drafting, was also silent — and was the first caught before
it cost anything, by asking what the arithmetic did rather than by watching it
fail. That is the only defence we have found against this failure class that
does not require the failure first.

---

## 9. Conclusion

We set out to build a computer that constructs its own software from nothing,
and we have not built it. What we have is the apparatus for attempting it, a
reference implementation of the arithmetic against which three future assembly
implementations can be judged, and seven documented ways of being wrong without
being told.

The seven are the part we would defend. In conventional development, the
toolchain, the operating system, and the runtime collectively convert a large
fraction of programmer error into diagnostics. Remove all three and that
conversion stops. What remains is a machine that runs the wrong thing
confidently and reports nothing, and a developer whose only recourse is to
disassemble the output and read it.

The techniques in §5 are our response, and the one we would most like others to
adopt is the cheapest: **keep one real hazard among the synthetic ones.** It
cost a single run and revealed that an entire category of failure lies outside
what the technique can observe.

---

## Appendix A: Reproduction

Everything described in §3 and §4 is in the project repository with the commit
history intact. The commit messages are written as prose and describe what
changed and why; the failures in §4 correspond to identifiable commits.

```
./run-tests             every check, including emulated boots
./run-tests --quick     host-side checks only
```

Seven test programs at time of writing. Every source file is accompanied by an
information file describing its interface and the constraints discovered while
building it; those files are where the findings in §4 are recorded in the form
a future implementer will meet them.

## Appendix B: Status of the enclosing project

**Recounted 2026-08-21.** The table below had not been revised since the report was
first drafted and most of its bottom half was wrong — six components listed as *not
started* had been finished, in some cases weeks earlier. A status table nobody
recounts is the failure this report is about, arriving in the report itself.

| Component | State |
|---|---|
| Proving ground, six boards, three architectures | working |
| Screen capture and terminal rendering | working |
| Boot through real firmware, three architectures | working |
| Executable generation without a linker | working |
| Hazard traps | working |
| Model packing, reading, round-trip | working |
| Self-locating model inside its own image | working, three architectures |
| Reference forward pass, tokenizer, sampler, with fixtures | working |
| Memory budget and fitting analysis | working |
| **Every kernel in assembly, bit-exact against the reference** | **working, three architectures** |
| **A whole thought end to end in assembly** | **working, three architectures, agreeing on all 192 scores bit for bit** |
| **Four-bit weights** | **working, three architectures, agreeing bit for bit** |
| **The driver on the metal** | **working on the first architecture** — a machine with no operating system reads what it was told, thinks, and says six words, the same six the readable loop says from the same text and the same carried randomness |
| **Tool calls** | **working**, as the specification the assembly will be held to; two of them are assembly |
| **The instruction text** | **written**, and checked as part of the payload |
| Recognising a request inside generated text, in assembly | not started — the last step of the driver |
| Image builder and flasher | partly: the recipe, the board descriptions and the writing are done; **a built image carries no partition table and no filesystem, so no firmware can open one** |
| Any machine that has installed itself | **not started**, and it is the capstone |

**The distinction that table needs and did not have**, and it cost this project a
false reading of three phases: **assembly runs on the chip; a readable program runs
on the development machine and proves the assembly.** The method is to write the
readable one, record what it produces, then write the assembly and require it to
reproduce those answers — and a row that says "working" without saying which kind is
a row that adds two different things together. Every individual claim in the old
table was true. The summary was not.

## Appendix C: What this report says that the project no longer does

Listed rather than silently edited, because a paper that changes its claims without
saying so is worse than one that is out of date.

**The central experiment changed on 2026-08-21.** §7 and §8 are written around
whether a model, left alone with an instruction and a set of tool calls, writes a
working allocator — twenty images, count the successes, zero of twenty would falsify
the design claim. The seed now **carries** an allocator, under a rule that says to
carry anything trivial-and-required or unique-to-the-silicon and to tell the machine
it may rewrite it. Marking memory as in use is both and there is little art in it.

The capstone is now **whether the machine installs itself**: find a disk, do not
destroy what is on it, write itself there in a form the firmware will start, confirm
it starts, and keep running after somebody pulls the card. It cannot be half-done or
faked, it exercises nearly everything at once, and it is the step where the card
comes out and the machine keeps existing. Whether machines improve the allocator they
were handed is still watched and is no longer what anything turns on.

**§6.1's central claim was false when it was written and is true now.** It says none
of the three irreversible operations is prevented. One of them was: the memory hands
refused any write landing in the engine or the weights, and the shipped instruction
told the machine not to work around them. That refusal was removed, and what replaced
it is a warning the write carries plus a copy of the weights on disk — so a machine
that damages its own mind is told, and can read itself back.

**§6.3 describes a status system that no longer exists.** The aspect shown as colour
and shape, the per-program code, the magnitude with fifty as ordinary — all removed,
along with their code. They were complexity nothing needed, and they had caused a
real defect: the two-digit magnitude was also being used to count loop iterations, so
a program was declared a runaway after fifteen turns of a loop. What replaced it is
threads and a clock.

**And one thing §1 gets right that later drafts of the design got wrong.** It says
the machine "opens a channel on every part of its body that can carry a request."
Three documents were later corrected on this: **nothing types at this machine.** The
mind is a closed loop that holds its own context and re-prompts itself, a request is
the machine giving itself something to do, and a way of talking to a person is
software the machine writes. A machine with no channels has everything to do.
