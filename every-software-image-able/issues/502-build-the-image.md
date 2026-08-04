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

## Blocks

`503`.

## Blocked by

`501`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the three ways an image could be made.
