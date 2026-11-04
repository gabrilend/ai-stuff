# Issue A12: Pictures That Move

**Phase:** A - Infrastructure Tools
**Type:** Tool (a see-in-3d step, and a page for choosing)
**Priority:** Medium
**Status:** Completed 2026-10-10
**Dependencies:** A09 (imagine: the image server), A10 (keeping pictures and the conversation); gif-generator's GIF encoder (`gif-generator/src/004-gif.lua`)

---

## Why this exists

> can we select some of the generated images to make gifs out of that we can
> use in the future? We could use the image as a "middle, beginning, or end
> state" and generate several inbetween iframes. the narrative description can
> describe the mechanism we want to show, and the updated images can be what
> slowly develops it. Then we string them together into a gif and display it in
> the LLM-transcripts HTML page. We can also use it for visualization input.

> this should be project agnostic, we should use the same standard patterns
> everywhere. The gifs that already exist do not use this mechanic, don't worry
> about them they're precious and beautiful and rare. This is a new tool.

Choosing the moments: "both" — by naming pictures in a command, and from a
page with beginning / middle / end buttons.

## Current Behavior

Built 2026-10-10 (`see-in-3d animate`, `see-in-3d choose`,
`scripts/libs/see-in-3d-animate.lua`; tests in `scripts/test-see-in-3d.sh`).
First run on the machine nearby: the hub at noon to the hub at dusk, 8 frames
going and 6 coming back (`--bounce`), 768 pixels, denoise 0.45 — a crowded
ring of tiny figures thinning into a few larger people on a disc warming to
orange; 1.5 MB, kept in delta-version and shown in the conversation. Its
fifth frame was then read back in as a picture and rendered from four sides:
the first reading made the frame's pale background an object three times the
disc's size, which the views showed at once; the second reading matched,
except for figures spaced evenly where the frame clusters them.

The story-site's films are a separate collection, chosen by meaning and never
generated, and are left as they are.

Decided: every frame uses one seed and a light repaint (denoise about 0.45),
so frames are pictures, not cross-fades, and do not flicker; frames are
compressed one per worker process with gif-generator's own encoder, untouched;
the palette is a median cut over the frames' own colours, because
gif-generator's palette is built for glowing shapes on black.

## Intended Behavior

`see-in-3d animate --from=A --to=B [--middle=M] --prompt="the mechanism"
[--frames=N] [--denoise=D] [server options as imagine]`:

1. The pictures are brought to one size and sent to the image server.
2. Each in-between frame blends the two ends' latents by a growing amount
   (LatentBlend, a core node) and is lightly repainted under the mechanism's
   description with one seed, so frames are pictures, not cross-fades, and do
   not flicker. With a middle, two runs: beginning to middle, middle to end.
3. The frames become a looping gif: a palette chosen for these frames
   (median cut over all of them) and gif-generator's own encoder.
4. Kept like every see-in-3d picture (A10): in the project's
   `mind/imagination-portraits/`, written into the conversation where it was
   made, shown on the story page. Any frame can be read back in as a picture
   for see-in-3d.

`see-in-3d choose [PROJECT]` writes a page of the project's kept pictures,
each with beginning / middle / end buttons, which composes the animate
command to copy. Making and choosing stay apart: the page only writes text.

## Suggested Implementation Steps

1. The between-workflow (pure, tested without a server).
2. Frames: request, fetch, decode (ImageMagick to raw pixels).
3. Palette by median cut; indexing; the gif through gif-generator's encoder;
   a round trip read by ImageMagick in the test.
4. Keeping a gif (the keep step learns a non-JPEG picture).
5. The choosing page.
6. A real run on the machine nearby, one frame read back in from four sides.
