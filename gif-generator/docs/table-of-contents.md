# Table of Contents

## The phases (clusters of functionality, not a schedule)

1. **The canvas and the file** — light buffer, tone-mapping, glow
   palette, handwritten GIF89a encoder.
2. **Particle life** — preallocated pool, emitters, physics, additive
   glow splatting.
3. **Choreography** — clock-face paths, easings, timeline tracks,
   growing fill-regions.
4. **The scene language** — declarative scene scripts, the compiler and
   its validation wall, the command-line runner, the HTML gallery.
5. **Many hands** — threaded rasterize-and-encode pipeline, the render
   statistics utility.
6. **The listening porch** — prose files translated to scene scripts
   by small local models (llama.cpp cluster), grammar-constrained to
   the vocabulary, three readings offered, the person picks.

## Documents

```
notes/
└── vision ................ the founding description: particle-drawn
                            motion, glowing on black, out to .gif

docs/
├── table-of-contents.md .. this file
├── architecture.md ....... the six-stage pipeline and the design
│                           decisions that shape it
├── roadmap.md ............ the five phases and their issues
├── datapath-scene-script.md
│                           scene file → compiled timeline (the
│                           vocabulary, the clock-face convention,
│                           the validation wall)
├── datapath-particle-sim.md
│                           timeline → particle states (the pool,
│                           one tick in order, frame snapshots)
├── datapath-rendering.md . snapshot → indexed frame (light buffer,
│                           splatting, tone-mapping, the palette)
├── datapath-gif-encoding.md
│                           indexed frames → .gif bytes (blocks,
│                           LZW, round-trip verification)
└── datapath-prose-translation.md
                            prose file → scene script (the porch:
                            grammar-constrained local models, three
                            readings, the person picks)

strategems/
└── pipeline-of-snapshots . the producer-snapshot-workers pattern,
                            recorded for reuse
```

Conventions: source files carry a project-wide reading-order index in
their names, tracked by the hidden `.file-index-counter` at the project
root (it holds the next unused index; take it, then increment it).
Every source file gets a sibling `.info.md` describing its usable
surface. Ephemeral logs go to `tmp/shared-memory/` (RAM); executable
scratch to `tmp/` (also RAM, exec-permitted tier).
