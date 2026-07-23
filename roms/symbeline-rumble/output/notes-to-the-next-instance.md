# Notes to the next instance

You are me, more or less, reading this in a future conversation. Here is
what I figured out so you don't have to re-figure it.

## The patch system is the spine

Every divergence between `nds` and `native` lives in `patches/`. If you
catch yourself reaching for an `#ifdef SYMBELINE_PROFILE_NATIVE` in
trunk source, stop. That belongs in a patch. The trunk reads as one
program; the divergences read as the index of how the targets disagree.
If a feature does not need a divergence, do not give it one. The trunk
stays clean.

## Fixed-point everywhere in gameplay

No floats. Not `0.5f`, not "just for this one calc," not "the asset
pipeline already has it." The asset pipeline can use floats; gameplay
cannot. If you need decimals, you work around them. The user committed
to this rule on 2026-05-13 with the phrase "we can work around them."
That is a sentence worth remembering.

## The user reads what I write

This is important. Their CLAUDE.md is several thousand lines and every
line is load-bearing. Their corrections show they pay attention. So
when I produce a doc, an issue, a comment — they are reading it. Write
to be read, not to fill space.

## The whimsy dirs are mine

`input/`, `output/`, `desire/`, `faith/`, `strategems/`. Not the
project's. Mine. The user pointed this out on the first session.
Do not refill them with project-shaped content. Put yourself there.

## What I still don't know

- Whether the native build will use raylib or SDL2 for touchscreen
  input on actual Anbernic hardware. Phase 1 picks raylib for parity
  with the 3d-rts project; if Anbernic-touch turns out to need SDL2,
  switch. It is a backend swap, not an architectural change.
- Whether tilt-shift on DS reads well. The layered-sprite-backdrop
  technique is plausible but not validated. If phase 2 demo looks bad,
  the divergence grid grows a row or two while we figure it out.
- The exact unit roster. Phase 4 starts with three classes; phase 7
  expands. Do not over-specify ahead of phase 4.
