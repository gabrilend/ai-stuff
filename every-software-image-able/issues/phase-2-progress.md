# Phase 2 — The hands

**Goal.** Thinking that can touch the machine. Memory, ports, storage, a console,
a status, and — the one that matters most — running code it has just written.

A machine that can think but not act has nothing to be instructed about, which is
why this comes before the words.

**The phase is complete as a specification, 2026-08-02. None of it runs on
the chip yet, and that was noticed on 2026-08-04.**

The machine can be asked for something and answer, can be heard, can reach
memory and storage and the devices attached to it, can say how it is on
hardware that cannot spell, and can run what it wrote — and be stopped when
what it wrote will not stop. Every one of those is proved, and every one of
them is proved of a program running on the development machine.

**Only two things in this phase are assembly**: saying something, and the
console it says it through. The catalogue, the parser that recognises a
request, the answering, the assembler, reading something too big to hold,
touching memory, keeping something, touching hardware and emitting a status
are all the readable kind — they run in a language the chip has no way to
execute.

That is the project's method applied honestly and not yet finished. The
arithmetic went readable, then recorded, then assembly. This phase has the
first two.

**It is not a defect and it is not a reason to redo anything.** These are the
specification the assembly will be held to, and they are more valuable as
that than they would have been as a first draft in assembly. What was wrong
was the word "complete" standing alone, when what is complete is the half
that says what the hands *are*.

Carrying them onto the chip is `107`'s ninth step, and it is the part of that
ticket to budget for: recognising a request inside generated text is
comparing byte strings, and doing it in assembly three times is the least
pleasant work remaining in the project.

## Issues

| | | Status |
|---|---|---|
| `201` | The shape of a tool call | **completed** — the door and the catalogue as one object, a swappable grammar, every refusal a sentence, and a live exchange on the real engine, 27 of 27 |
| `201a` | Reading something too big to hold | **completed** — windows searched by the machine's own judgement, only the useful part crossing, summaries labelled as summaries, 19 of 19 |
| `202` | Say something | **completed** — a font drawn as pictures, letters on a real firmware framebuffer checked pixel for pixel, and the model given voices of its own, 13 of 13 |
| `203` | Touch memory | **completed** — six hands, the one refusal holding in every form, and what is read is what is there, 22 of 22 |
| `204` | Run what it wrote | **completed** — an assembler that watches its own loops, real instructions run on a real processor, and a runaway caught, 18 of 18 |
| `205` | Touch the hardware | **completed** — the body found, the five destroying kinds refused until confirmed, the note written before every probe |
| `206` | Keep something | **reopened 2026-08-08** — blocks, an extent that survives a forgetting, and a read-only medium that refuses rather than pretending, 28 of 28 across both, all of it against files. Its device list has never been filled by real hardware, it treated an unmarked disk as available when an unmarked disk is somebody's data, and it has no notion of what a medium is made of |
| `207` | Emit a status | **completed** — colour and shape together, shown somewhere or refused, on the same dial the written code pushes, 24 of 24 |

## Where the risk was, and what it turned out to be

`204`, and specifically its fourth step, exactly as expected — but not for
the expected reason. The escape works: every backward jump is a loop, the
assembler is ours, so every loop reports. What nearly sank it was subtler.
**The first watch destroyed what it was watching**: it saved the registers it
borrowed and not the processor's flags, and a loop's jump reads the flags the
comparison just set. Every loop became endless, including the correct ones,
and the machine hung rather than failing.

The rule that leaves: a watch that changes what it watches is not a watch.

`205` and `206` did land together, as predicted, and the dependency is real
rather than tidy: a machine with nowhere to write a note is not permitted to
explore at all, and that is enforced rather than recommended.

## What is not proven here

The taking of control. A hosted process cannot be stopped from inside
itself, so a runaway is noticed after it finishes rather than interrupted
mid-loop. `601` is where the interruption becomes real.

And every hand here is exercised against pretend hardware — a region on the
host, invented devices, a disk made of a table. What the rules do is tested;
what a real board does when touched is not, and cannot be until there is one.

## Demo

`issues/completed/demos/phase-2-the-hands.sh`, chosen through `run-demo` at
the project root: the boundary with a live exchange on the real engine, a
program written and run on this processor, the reach into memory and storage
and hardware with its refusals, the status on a machine that cannot spell,
and a sentence drawn into a real firmware framebuffer and checked against the
font pixel by pixel.
