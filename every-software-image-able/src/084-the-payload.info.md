# 081 through 085 — the text payload — info

What the machine wakes up holding, and what it can reach. `assets/081` is the
instruction, `082` the device descriptions, `083` the build patterns, `084`
the payload machinery, `085` the checks. Issues `301` through `304`, which
are only useful as the one payload they form.

## Running the checks

```
luajit src/085-test-the-payload.lua
```

## `081` — the instruction

Written for something that has never seen this project and has no way to ask
what a term means. It gives the startup order, marks the two prohibitions as
different in kind from everything else, says what the machine is for and then
stops.

**It says the atoms making it up can be rewritten, and does not say what that
could cost.** A machine that derives the danger understands it; one that was
warned has only been handed another rule. This is safe while the delivery
medium is plugged in, because that medium is read-only and still holds the
original — the mistake is undoable for exactly as long as the card is there.
`085` checks both halves: that the sentence is there, and that no warning
follows it.

It also does not prescribe the four rungs, the interpreter, condensing or the
status square. Those are patterns, they live in `083`, and a machine that
organises itself completely differently must still be able to follow the
instruction.

## `082` — the descriptions

Ten required sections, refused at load if any is missing — a description with
no errata section may cover a part with no errata, but one that never had the
section is one nobody checked. Every description names whose document it was
transcribed from, because transcriptions rot and one whose source is unnamed
cannot be re-checked when a part revision lands.

**Confirmation is read-only**: maker and part, revision inside the covered
range, and the read-only registers compared against what the description
predicts. Confirming by writing is the exact failure the exploration
discipline exists to prevent. A partial match is a failure and returns every
disagreement, not the first — enough agreement to feel confirmed with one
silent disagreement in the register that matters is the dangerous case.

## `083` — the patterns

Eleven shapes, each with four parts, and the fourth is the one that matters:
**where it stops working**. A shape recommended without its failure mode is a
trap with a good reputation. Each says out loud that it is a suggestion.

The calling convention is the one exception and is marked as such: an
agreement rather than a suggestion, because everything the machine writes has
to agree with everything else it wrote. It carries what the flags defect
taught — a watch that changes what it watches is not a watch.

## `084` — what is said at once

The instruction is split at its own headings, so the boot set can be chosen
finely: one atom would mean waking holding all of it or none. Patterns and
descriptions are one atom each and none are resident — a pattern is relevant
when the machine is about to build something of that shape, which is not at
boot.

**Being held now and being in the boot set are different things**, and they
move independently. Reading one from the other made the boot set unchangeable
and quietly turned the design's most uncomfortable property into something
the machine could not do.

That property: the boot set is a mutable file, so the machine can change what
it wakes up believing, **including the prohibitions**, which are atoms like
everything else. Nothing prevents it. `085` tests it directly, so nobody
later builds on the assumption that it is untrue.

The disk half of the atom operations lives here too, since phase 1 had no
storage and this phase does: an atom written out stops taking room and comes
back exactly when fetched again.

## What none of this can check

**Whether the instruction works.** Nothing here says a machine given this text
does the right thing with it. Only `602` says that, and it says it by leaving
a machine alone and watching — and a failure there is fixed in this text
rather than at the keyboard.

## Result on 2026-08-02

43 of 43.
