# 701 — one studio, one canvas, two spaces

## Founding words

Spoken by gabrilend, 2026-10-01, after being shown that her art tools had
multiplied (this project, the shape films in `delta-version`, a viewer
beside them, and a skill describing studios in general):

> Alright we should merge these tools as you suggested into one skill file
> that describes how to use them, and the gif-generator project. We should
> pull them out of delta-version etc and put them there. The gif generator
> should be able to generate 2d images using it's limited vocabulary, and the
> 3d shape generation should be describable in an expanded 3d vocabulary. We
> should be able to paint both onto the same canvas, with 2d using
> screen-space coordinates and 3d using world-space coordinates.

Earlier the same day, asking why this project was not the one making the
films:

> why isn't the gif-generator used? Doesn't it generate gifs? Or does it do
> something else? ... I think we should try and coalesce our tooling a bit.

## Current Behavior

Two painters share one set of paints across two projects.

- **This project** turns a score of 2D strokes (`docs/score-format.md`) into
  a glowing particles-on-black GIF. The score is a closed, sandboxed
  vocabulary with a wall that reports every error at once with the nearest
  legal word (`src/024-compile.lua`). Its encoder is its own
  (`src/004-gif.lua`), its palette is seven glow hues
  (`src/002-palette.lua`). Phases 1 to 5 complete; phase 6 (prose to score)
  waits on a model cluster.
- **The shape films** live in `delta-version/scripts/readme-gallery/`
  (`delta-version` issue 060). A scene is a Lua table of meshes, motions,
  reactions and a camera, drawn by a 3D rasteriser (`raster.lua`, with
  `choreography.lua`, `meshes.lua`, `fluid.lua`). It is not sandboxed (some
  scenes use loops and `dofile`) and stops at the first error. It loads this
  project's encoder and palette by a path that climbs out of its own folder
  (`readme-gallery.lua:48`: `DIR .. "/../../../gif-generator/src"`). Its 34
  films are in `/home/ritz/pictures/shape-gifs/`; six are approved and
  locked by SHA-256 in `tests/approved-films.lua`.
- **The viewer** (`delta-version/scripts/gif-viewer/`, issue 062) is a LÖVE
  window showing those films, with the only complete GIF decoder in the
  house (`gif-decode.lua`).
- **The skill** `~/.claude/skills/canvas-and-paintbrush/` is a recipe for
  building such studios (closed vocabulary, owned encoder, every artifact kept
  and rated on five tiers). It names this project only as "a tool like the gif
  generator" and is followed in full only by `kanji-learning-image-generator`.
- Across the house there are five GIF decoders or walkers, two encoders (this
  one and kanji's), two PNG writers and three gallery viewers.

## Intended Behavior

**One project, this one, holding both painters, their viewer, and one set of
paints.**

- A **2D vocabulary**, as today: strokes in **screen space**, pixels from the
  top-left corner, y growing downward.
- A **3D vocabulary**, the shape films' words made a closed language with
  the same wall: meshes, motions, reactions, lights, ground and a camera, in
  **world space**, units around an origin, y growing upward, seen through the
  camera.
- **One canvas both paint onto.** A score opens one `canvas{}` and may hold
  any mix of 2D strokes and 3D shapes. The 3D layer is drawn through its
  camera into colour and depth; the 2D layer is drawn in pixels as light;
  the two are composed into one frame and quantised through the one palette
  into one GIF.
- **One encoder, one decoder, one palette**, each in one file, used by every
  part and by every test.
- **Every film kept and rated**: a card beside each, five tiers, as the
  skill describes; the viewer is where a person rates.
- **One skill** that says how to use this studio: how to write each
  vocabulary, how to mix them, how to render, view and rate.

## Sub-issues

| ID | Name | Depends on | What it does |
| --- | --- | --- | --- |
| 701a | bring-the-shape-films-home | None | moves the films' tool and the viewer into this project with their history, every path retargeted, every test passing, the six fingerprints unchanged |
| 701b | one-reader-one-writer | 701a | one encoder, one palette, one decoder, shared by every part and test |
| 701c | the-3d-vocabulary | 701a | the shape words as a closed, sandboxed language with the wall |
| 701d | one-canvas-two-spaces | 701b, 701c | a score may hold 2D and 3D together; the two layers composed into one frame |
| 701e | every-film-kept-and-rated | 701a, 701b | cards, five tiers, rating keys in the viewer |
| 701f | the-studio-skill | 701d, 701e | one skill describing how to use all of it |
| 701g | two-spaces-demo | 701d, 701e | the phase 7 demo (capstone) |

## Suggested Implementation Steps

Work the sub-issues in order: `701a → 701b → 701c → 701d → 701e → 701f →
701g`, with 701c and 701e free to run beside 701b once 701a lands. Across all
of them, one bar: **the six approved films re-film byte-identical** after
every step, and every test that passed before passes after. A step that
cannot meet that bar stops and says why, rather than re-approving new
fingerprints quietly.

## Related Documents and Tools

- `docs/score-format.md`, `docs/architecture.md`, `src/024-compile.lua`
- `delta-version/issues/060-readme-gallery-of-interacting-shapes.md`,
  `062-gif-viewer-window.md`, `064-a-gif-beside-every-message.md`
- `~/.claude/skills/canvas-and-paintbrush/SKILL.md`
- `kanji-learning-image-generator/src/045` to `048` (a built pool, tiers and
  cards; the pattern for 701e)

## Open Questions

1. **The skill: a new one, or canvas-and-paintbrush rewritten?** She leans
   rewritten. What each costs is in 701f; still to be settled.
2. **Do the films' and viewer's issues move? — ANSWERED. Yes; the gif
   beside every message does not.** Her words:

   > Probably move if they're related to the gif-generator. I think using the
   > gifs on the transcript website (what we're working on) should probably
   > be project specific. Maybe that means it goes into the skill file? Nah
   > it should go on the website's project, which is this one actually!

   So `delta-version` issues 060 (the shape films) and 062 (the viewer) come
   here with the code, in 701a. Issue 064 (a gif beside every message) goes
   to `double-diaper-dungeon`, whose website draws the transcripts, as its
   issue 10-007; 064 stays where it was written with a note saying so,
   because issues are added to and never deleted.
3. **Does kanji join? — ANSWERED. Separate for now, and learned from.** Her
   words: *"separate for now, but we can learn from it for this process."*
   Its pool, tiers and cards (`045` to `048`) are the worked example 701e
   reads before building, and its encoder stays its own.
