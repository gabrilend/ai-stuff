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

1. **A new skill, or canvas-and-paintbrush rewritten into this studio's
   manual?** She leans rewritten. What it would change:

   **Gained by rewriting**
   - One skill instead of two, so an assistant asked to "make a gif" or
     "build a studio" lands in one place and never reads two that disagree.
   - Every example becomes a real score this studio renders and its tests
     check, instead of advice about an imagined one.
   - The real file names replace "a tool like the gif generator".

   **Lost by rewriting, unless kept as a section**
   - The general recipe for building a *different* studio: one that makes
     sound (.wav), vector pictures (.svg) or tiles. Three projects read it
     for exactly that: `burner-of-down-things` (its studio datapath),
     `supcom-derivative-clone` (issue 610, a tileset raised by a tool) and
     `kanji-learning-image-generator`, which built the pool from it. A manual
     for this studio would not tell them how to build theirs.
   - The skill's trigger: it is found today by "make it output something I
     can look at" or "build me a tool like the gif generator but for this".
     A manual triggers on "make a gif".

   **The middle way**: rewrite it as this studio's manual, and keep the
   general recipe as its closing part, "building a studio of your own", with
   this studio as the worked example all the way through. That keeps the
   three projects' reading and gains everything above.
