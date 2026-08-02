# 502 — Build the image

## Current behavior

The recipe and the board description exist as text. Nothing turns them into
something a card can hold.

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
