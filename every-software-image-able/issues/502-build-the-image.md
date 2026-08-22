# 502 — Build the image

## Current behavior

**Reopened on 2026-08-04. The builder is right and has never been handed an
engine.**

Everything below this paragraph holds. The builder lays down five regions in
the order the firmware meets them -- the waking code, the engine, the model,
the text, the carried randomness -- each starting on a block boundary,
because a medium is written in blocks and a region straddling one cannot be
replaced alone. It checks the offsets it writes against the offsets the
engine will look for, and refuses to build when they disagree.

**The engine's bytes arrive as a parameter, and one caller supplies that
parameter: a test, passing two thousand copies of the letter E.** So the seam
between the builder and the engine is checked against a placeholder, which
means the check is real and has never been exercised against anything that
would run.

Nothing here is wrong. The builder does not know what an engine is and should
not; the engine is somebody else's output. But this ticket cannot be called
finished while the only image it has ever produced contains no engine, because
what it produces is the thing `503` puts on a card and `601` switches on.

**This closes again when `107` hands it real bytes** and the layout check
becomes a check between two things that both exist.

## Fixed 2026-08-22 — the image is a medium now, and firmware opens it

**A firmware has opened what this builder produces, on all three
architectures.** `141` wraps the laid-out regions into a partition table, a
FAT16 partition, and the boot file at the path the board description already
names; `142` checks it three ways and the third is the one that counts.

The other two are worth keeping because the third is slow. Tools written by
people with no stake in this being right read the partition table and the
filesystem and agree with them. And the checksum a partition table makes of
itself is checked against a published answer before anything else here is
trusted — which caught this file's own first version, written with addition
where the algorithm needs exclusive-or. That produced a plausible number for
every input and the wrong one for all of them, and a table whose check fails is
ignored **in silence**.

**The third architecture disproved a claim made from the first.** The medium
writer originally refused long filenames, with a comment saying every path a
firmware looks for fits the eight-and-three naming FAT has always had. The
RISC-V path is `EFI/BOOT/BOOTRISCV64.EFI` — eleven characters in the stem. It is
the same mistake this project has already written down about assembly, arriving
in a filesystem: one machine looked at, and generalised from.

**And the smallest image is megabytes now**, because a FAT16 filesystem is only
FAT16 above about four thousand clusters. The floor comes from the format rather
than from anything chosen here, and the flasher's tests were carrying pretend
cards smaller than the smallest real image.

**And a thinking machine has booted off one.** The driver's whole payload — the
routine a bare machine enters, with a model riding inside it — was wrapped in a
medium and handed to firmware, which found the partition table, mounted the
filesystem, opened the file and ran it. The machine reached first light, found
every one of its own weights, divided its memory, built its word tables from the
model it carries, thought, and said six words.

`140` goes down that road permanently now rather than the synthesised-directory
one, so the emulated road and the card road are the same road for the machine
test as well as for this ticket's own.

## Found 2026-08-22 — there are three layouts and the builder's is the unread one

Asked why the builder is handed two thousand copies of a letter where an engine
should be, and the answer turned out to be worse than "nobody wired it up".

**Three arrangements of the same five things exist here.** `029` puts an appended
blob a fixed distance past the code, and the machine finds it by measuring from
where it stands. `140` divided that blob into model, text and randomness — inside
a **test**, where nothing else could reach it. And this builder lays five regions
down at block boundaries, in a different order, with different alignment.

The first two are what boots. **Nothing has ever read the third.** It is correct
and it describes a machine nobody built.

**And the seam check compares two copies of a belief rather than a belief against
a fact.** Its own comment says the expectations should be taken from the engine's
own layout description "rather than written again here, because two copies of an
agreement are two things that can drift" — and `090` writes them again anyway, by
hand. That is why it has passed for months while describing an arrangement
nothing implements.

**First half done.** The real layout is written down once now, in `143`, and both
the machine test and anything else can read it from there. Proved byte-identical
the only way that means anything: a computer with no operating system boots, finds
its own weights at those offsets, thinks, and says the same six words.

**Second half done 2026-08-22, and the decision was the obvious one.** The
executable envelope is a library now as well as a command, so nothing has to
start a process to reach the one piece of the boot path that could only be
reached that way. The builder lays out what the machine reads — code first, then
everything it thinks with at the distance past the code that `029` owns — and
its check derives the expectations from those same two descriptions rather than
from numbers typed out a second time.

The five-region arrangement is gone. Keeping a correct description of a machine
nobody built is how this survived unnoticed.

> the entire point of tests is that they test the system that we're using. They
> don't run in a vacuum using their own code, they should use the system.

Which is what the tests do now. `140` reads the layout from the description
rather than working it out again; `090` derives what it expects from the same
place. One dataflow, and everything on it is the thing that ships.

**Superseded — kept for the reasoning.** What this said before it was done: For this
builder to produce something that runs, it has to lay out what the machine
actually reads — the code, then the blob at `029`'s distance — and be wrapped in
the executable envelope `029` makes. That envelope is a script rather than a
library, so either it becomes one or this builder shells out to it. Either way
the five-region layout goes, because it is a description of an arrangement
nothing implements, and keeping a correct description of a machine nobody built
is how this survived unnoticed.

**What is still open in this ticket** is the older blocker: the engine's bytes
arrive as a parameter and one caller supplies it, a test passing two thousand
copies of the letter E. A firmware now opens the medium and runs the file inside
it. Whether that file is a machine is a different claim and `107` still owns it.

---

**Found on 2026-08-08, and larger than the blocker above: the image this builder
produces cannot be booted by any firmware.** It lays down five regions at block
boundaries and writes nothing else -- no partition table, no filesystem, no file.
UEFI firmware opens **one file on a FAT filesystem** at an architecture-specific
path, and there is no such file in a built image.

Nothing noticed because the seam this builder checks is the one against the
*engine*: it compares the offsets it writes against the offsets the engine looks
for, and both are right. **The engine is not what has to find the first byte.**
The firmware is, and it was never asked. Meanwhile the emulated boards boot from
a directory the emulator synthesises into a filesystem (`018`), so the image this
builder produces has never been the thing under test -- `notes/023`.

**So this ticket's near work is a medium something can boot from**: a partition
table, a FAT partition, and the waking code written into it at the path the board
description already names. That is strictly more than "hand it real engine
bytes," and it is now the piece standing between here and `601`.

**Everything else rides inside that one file, and that is not a compromise.**
Firmware loads the boot file whole before the first instruction runs, so a model
riding inside it is simply in memory when the machine wakes -- which is what the
payload does today and what said six words on 2026-08-07. No table of contents,
no block numbers, no reading. `docs/008` question 23 answers how regions get
found when they stop riding along; `107b` records when that is, and it is
arithmetic rather than judgement: `045` chooses a strategy per model and board,
and the sentence that opens that work is **"the hot parts in memory, the rest
read in place."** Until a build selects a partial strategy, riding inside is
fewer moving parts doing the same job.

**Which gives this builder a refusal worth writing.** It already refuses a model
that does not fit at all, with the three numbers said out loud. It should equally
refuse to build a riding-inside image when the strategy chosen is a partial one,
because that image would boot, load a fraction of its weights, and think with
whatever the rest of memory happened to contain. That turns "somebody must
remember which arrangement this model needs" into something the build says.

**The prepared tokenizer tables ride along too.** `docs/008` question 24 moved
their preparation to build time, so the four arrays ship rather than being
rebuilt at every boot. Inside the one file they need no new machinery at all --
just the layout written down where formats are described, since the builder and
`137` now have to agree about it.

---

**Done, and tested** -- `src/089`, checked by `src/090`, 34 of 34 on
2026-08-02.

Recipe and board in; the image, the manifest and the identity out -- three
files, never only the image, because an image alone is a pile of bytes nobody
can account for. The identity is computed from the manifest, so the same
recipe, board and components arrive at the same number. It is a plain rolling
hash rather than a cryptographic one, and says so: nothing here defends
against a constructed collision, and using a stronger name for it would be
the more dishonest choice.

Reproducible in the plain sense, and tested both ways: the same inputs give
the same bytes and the same identity, and different inputs give a different
identity. No timestamps and no build paths leak in.

**The seam with `102` is checked by the build.** The builder lays things down
and the engine looks for them; if they disagree the machine fails at the
earliest possible moment with the least possible information. So the layout
is compared against what the engine expects before anything is written, and
a disagreement is refused there with that reason in the refusal.

The model is a parameter, and a model too large for the board being built for
is refused with the three numbers said out loud: what the medium holds, what
the board holds alongside working space, and that no arrangement of it runs.

The carried randomness is generated here from the seed the recipe names, and
the seed goes in the manifest -- same recipe and same seed gives the same
machine, exactly, which turns a strange failure into something reproducible
by handing somebody an image.

## Intended behavior

Recipe plus board description in, a flashable image out, along with a list of
everything that went into it and a number anyone can reproduce from the same
inputs.

## Suggested implementation steps

1. Resolve the recipe and the board description into a manifest naming every
   component and its version. The manifest is the honest account of what this
   image is; the image itself is a pile of bytes.
2. Hash the manifest, and let that be the image's identity. Someone with the same
   recipe, the same board description and the same components should arrive at the
   same number — which is the only kind of reproducibility this project has, and
   it stops mattering the moment the machine starts growing (`docs/008`,
   question 5).
3. Lay the medium out according to the board description: where the starting code
   goes, where the engines go, where the weights go, where the text payload goes.
   Offsets have to agree with what `102` expects, and that agreement should be
   checked by the build rather than by hope.
4. **Take the model as a parameter.** Which model an image carries is the
   operator's choice at build time, not a decision baked into this project
   (`101`). This is also where a model too large for the board being built for
   gets refused, with the three numbers said out loud: what the medium holds, what
   the board's memory holds alongside working space, and what the resulting speed
   will be.
5. **Generate the carried randomness.** Around a hundred kilobytes of random
   numbers, made at build time and baked in, which is where the machine's first
   randomness comes from (`104`). Record the seed that produced it in the
   manifest — same recipe and same seed gives the same machine, exactly, which
   turns a strange failure into something reproducible by handing somebody an
   image.
6. Emit three files: the image, the manifest, and the hash. Never only the image.
5. Support generating for a board whose description was supplied at build time
   rather than shipped — this is the middle rung of the ladder in `docs/003`, and
   it is the one that lets a single recipe reach machines nobody planned for.
6. Keep the build reproducible in the plain sense: same inputs, same output bytes.
   Timestamps and build paths leaking into the image are the usual reason this
   fails.
### Added by the 2026-08-08 finding

7. **Write a medium firmware can boot**: a partition table, a FAT partition, and
   the waking code written into it at the path the board description names. This
   is the piece whose absence made every image so far unbootable, and it is
   required no matter where the other regions eventually live.
8. **Ask the firmware, not the engine, whether the image is findable.** The
   existing seam check compares this builder's offsets against the engine's
   expectations and both were always right. Add the check that was missing: boot
   what was built. A test that produces an image and never asks a firmware to
   open it is the test that let this through.
9. **Let everything else ride inside the boot file** while the model fits, since
   firmware loads that file whole and the data is then simply in memory.
10. **Refuse to build a riding-inside image when `045` chose a partial
    strategy.** Such an image boots, loads a fraction of its weights, and thinks
    with whatever else was in memory -- a wrong answer with nothing to notice it.
    The builder already refuses a model that does not fit at all; this is the
    same refusal one rung up.
11. **Feed the boards a built image rather than a served directory.** `018` hands
    the emulator a host directory it synthesises into a filesystem, which is why
    none of this was caught. Booting what the builder produced makes the emulated
    path and the card path the same path.

## Blocks

`503`.

## Blocked by

`501`. And `107`, for the engine bytes that turn the layout check into a check
between two things that both exist.

Not blocked by `docs/008` question 23 any more. That answer stands for the day
regions stop riding inside the boot file, and `107b` records that the day is
chosen by arithmetic rather than by preference.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the three ways an image could be made.
