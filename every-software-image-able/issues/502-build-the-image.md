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
