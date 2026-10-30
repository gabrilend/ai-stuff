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
   manual? — ANSWERED 2026-10-30: two skills.** Her words:

   > the canvas-and-paintbrush tool is slightly different than the gif
   > generator, the canvas-and-paintbrush is for creating the tools of
   > creation while the gif generator is one example of creating a tool
   > that paints for us based on what we say.

   So `gif-studio` stays its own skill, and canvas-and-paintbrush gains
   only the pointer changes listed under What Happened. What she named as
   missing (the ear: plain speech into the studio's words) is issue 704.
   The weighing as it stood before her answer:

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

## What Happened

Built 2026-10-30 on top of 701e. `./test-shape-films` is 311 of 311 (11
new checks).

- **The skill (step 1).** `skills/gif-studio/SKILL.md` in the ai-stuff
  repository, beside `skills/upstream-patch-system/`. It was written from
  `docs/score-format.md`, `docs/shape-format.md`, `docs/card-format.md`
  and the tools' own usage lines. It covers: what the studio is and where
  its contracts are; a score of strokes; a shape scene; a mixed score with
  a stroke following a shape; what to do when the wall refuses (with a
  real refusal, 2D and 3D mistakes together); rendering; looking; rating
  and the pool; the house rules; and a closing pointer to
  `canvas-and-paintbrush` for building a different studio.
- **The skill can't drift (step 2).** `src/057-skill-examples-test.lua`
  films every example the skill shows, checks its refused score is
  refused word for word, and checks every project file and `./tool` it
  names exists. Examples are fenced blocks labelled `lua score`, `lua
  scene` and `lua refused`.
- **Found along the way.** The many-hands renderer
  (`src/028-parallel.lua`) didn't know about 701d's second space, so a
  mixed score sent to it would have filmed its strokes and dropped its
  shapes. It now refuses such a score with a pointer to `./run`; giving
  two-space scores many hands is future work.
- **canvas-and-paintbrush (step 3) is not done.** It lives at
  `~/.claude/skills/canvas-and-paintbrush/` on her machine, outside the
  repository, and the copy in the burner's September transcript is older
  than hers. The changes, ready to make there:
  1. After its opening paragraphs, a "worked example" paragraph: *This
     recipe's worked example is the gif studio (`gif-generator`, and the
     `gif-studio` skill for using it). Its wall is `src/024-compile.lua`
     and `src/049-shape-wall.lua`, its encoder `src/004-gif.lua`, its
     reader `src/040-gif-decode.lua`, its cards `src/055-cards.lua`. A
     pool built elsewhere: `kanji-learning-image-generator/src/045` to
     `048`.*
  2. Under "Choosing the artifact", after "Reject any format needing a
     dependency you would not otherwise have": *A shared encoder the house
     owns counts as your own: gif-generator's encoder, decoder, palette
     and PNG writer are copied into a project's `libs/` by `install-into`
     and kept honest by `check-copy`. A third party's does not.*
  3. Where it names "a tool like the gif generator" (`:15`, `:80`), the
     real project name and the `gif-studio` skill.

Open question 1 (a new skill, or canvas-and-paintbrush rewritten) is
still hers. What's built is the "new skill" shape, which keeps the
general recipe where the three projects read it. Under the middle way,
`gif-studio`'s text becomes canvas-and-paintbrush's first part and the
recipe its closing part; the test would point at that file instead.
