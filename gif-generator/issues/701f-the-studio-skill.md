# 701f — the studio skill

Part of 701. Depends on: 701d, 701e. Blocks: 701g.

## Current Behavior

`~/.claude/skills/canvas-and-paintbrush/SKILL.md` (650 lines) and its
`reference.md` describe how to *build* a studio: extract a closed vocabulary,
write the wall, own the encoder (`:239-246`), prove it by round trip
(`:248-255`), keep maker and viewer apart (`:267-285`), keep and rate every
artifact (`:289-519`). It names this project only in passing (`:15`, `:80`)
and says to reject borrowed encoders (`:116-117`). Nothing describes how to
*use* this studio once it exists.

## Intended Behavior

One skill an assistant loads to make pictures with this studio:

- the two vocabularies and the two spaces, with one small example of each
  and one mixed score;
- how to render (the run command, seeds, workers), where films land, and
  how to view them;
- how to rate, and how the pool and tiers are read back;
- what to do when the wall refuses a score: read every line, take the
  suggested word, never work around the wall.

`canvas-and-paintbrush` points here as its worked example, names the real
files (`src/024-compile.lua` for the wall, `src/004-gif.lua` for the
encoder, kanji's `045` to `048` for a pool built elsewhere), and counts a
house-owned shared encoder as "your own", unlike a third party's.

## Suggested Implementation Steps

1. Write the skill from the vocabulary tables and the docs, not from memory,
   so its examples are scores the wall accepts.
2. Add a check to this project's tests that renders every example in the
   skill, so the skill cannot drift from the studio.
3. Update `canvas-and-paintbrush` as above.

## Open Questions

1. A new skill beside `canvas-and-paintbrush`, or `canvas-and-paintbrush`
   rewritten into this studio's manual? (Same as 701's first question.)
