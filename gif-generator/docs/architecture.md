# Architecture — the shape of the machine

The gif-generator is a pipeline of six small machines. A description of
motion goes in one end; an animated .gif file comes out the other. No
diffusion models, no neural guesswork — every pixel is the deterministic
consequence of a particle that was somewhere, glowing.

This document is the map. Each stage has its own datapath document that
follows the bytes through it (see the table of contents).

## The pipeline, told as a story

1. **A score is read.** The score is a flat todo list of strokes —
   each one declarative call: at 0.0 seconds, lasting 2.0, an
   ember-colored arc from twelve o'clock to seven, fading in, eased
   like a brush stroke. Times speak in tenths of seconds; the list
   reads top-to-bottom in playing order because a canonical writer
   sorted it by time. It lives in `input/` as a sandboxed Lua file.
   The program's first act is to read it. (datapath: scene script)

2. **The score is compiled into a timeline.** Strokes become tracks:
   for any moment in time, the timeline can answer "where is every
   emitter, how strongly is it emitting, and how far along its
   journey is it?" Paths (arcs, lines, points, fill-regions), easing
   curves (slow-then-fast, linear), and fade envelopes (in, out,
   in-out, hold, flash) are the vocabulary here.
   (datapath: scene script)

3. **Particles are born, drift, and die.** Each frame-tick, every active
   emitter spawns particles at its current position on its path. A
   particle is a handful of numbers — position, velocity, age, hue —
   living in one big block of memory allocated up front. Physics is
   simple: drift, drag, a little jitter, and a fade curve toward death.
   (datapath: particle sim)

4. **Particles are splatted onto a canvas.** Each particle stamps a
   small radial glow — bright at the center, falling off toward the
   edge — onto a floating-point light-accumulation buffer. Glows *add*:
   where many particles crowd, the light saturates toward white-hot.
   The background stays black because nothing is ever drawn there.
   (datapath: rendering)

5. **Light becomes indexed color.** GIF files speak in palettes of at
   most 256 colors. Because we know our aesthetic — vibrant glows on
   black — we build the palette on purpose: ramps of each scene hue
   from near-black up through vivid to white-hot core. Each frame's
   accumulated light is tone-mapped and snapped to the nearest ramp
   entry. (datapath: rendering)

6. **Indexed frames become a .gif.** A GIF89a file is written by hand:
   header, palette, a looping instruction, then each frame LZW-
   compressed into sub-blocks. The format froze in 1989; it will not
   move while our back is turned. (datapath: gif encoding)

The last act of the program is to write the finished file — and a
goodbye — into `output/`.

## The porch (before stage 1, and outside the house)

The pipeline's front door only accepts scores. But a person
describing motion sometimes says the wrong word, or forgets how to
spell it, while describing the mechanism perfectly. So a **translator
sits on the porch**: plain-English `.prose` files in `input/` are read
to small local language models (llama.cpp, behind an orchestrator
whose cluster shape is its own business), and the model *paints* — one
grammar-constrained tool-call per stroke, so it physically cannot
misspell a vocabulary word; its only freedom is choosing among legal
readings. The collector orders arriving strokes by their declared
times and writes a canonical score. Three independent readings are
gathered; each is compiled, checked by the same validation wall as any
hand-written score, rendered as a small fast thumbnail, and offered
side by side for the person to pick. The chosen score enters through
the front door like any other. The pipeline never knows a model was
involved. (datapath: prose translation)

## Design decisions, and why

- **One language, one runtime (LuaJIT).** The simulation logic and the
  byte-level file encoding both live comfortably in LuaJIT: Lua tables
  for the choreography vocabulary, FFI-allocated flat arrays for the
  hot pixel and particle loops. No build step, no linker, no version
  skew. LuaJIT 2.1 is confirmed present on this system.

- **We write our own GIF encoder.** The encoder is a few hundred lines
  against a frozen specification. Owning it means the palette can be
  designed for glow-on-black instead of for photographs, and there is
  no dependency to go missing. The system's giflib (`libgif.so.7`)
  exists and was noted, but is deliberately not used — if our encoder
  breaks, we want a loud error in our own code, not a silent fallback
  into someone else's.

- **Everything is particles.** The vision asks for swept arcs, a line
  that fades in, and a triangle that fills slowly. All three are the
  same machine wearing different clothes: a point-emitter riding an
  arc, a line-shaped emitter field, an area-shaped emitter field whose
  coverage grows over time. One renderer, one aesthetic, no special
  cases.

- **Generation and viewing never touch.** The simulator and encoder
  produce artifacts (frames, gifs, stats). The viewer — an HTML gallery
  opened in a browser — only reads artifacts. Errors in one can never
  hide inside the other.

- **Memory first, then work.** The particle pool is allocated once, as
  parallel flat arrays (all the x-positions together, all the y-
  positions together, and so on) — friendly to the cache, and friendly
  to splitting across threads later, because a worker can own a span of
  indices with no pointer-chasing.

- **Determinism.** Every render seeds its random generator from the
  scene. The same scene file always produces byte-identical output,
  which makes tests honest and bugs reproducible.

- **Time is quantized twice, and we admit it.** The sim steps at a
  fixed tick equal to the frame interval. GIF frame delays are measured
  in hundredths of a second, so the default frame rate is 25 fps —
  exactly 4 hundredths per frame — rather than 30 fps, which the format
  cannot represent without drift.

- **Many hands, later.** Simulation is sequential in time (each frame's
  particles depend on the last), but rasterizing and compressing
  finished frames is embarrassingly parallel. The pipeline is designed
  so frame snapshots can be handed to worker threads (effil for Lua
  threads, or the house C threadpool over FFI) without redesign. That
  is a phase of its own.

- **The model lives on the porch, not in the house.** The prose
  translator is a client of the pipeline, never a component of it: it
  speaks HTTP to llama-server endpoints listed in a configuration
  file, emits candidate scene files, and submits them to the same
  validation wall as everyone else. Determinism of renders is
  untouched — a scene file plus a seed still yields identical bytes no
  matter who or what wrote the scene. Three independent readings are
  preferred over one refined guess: three perspectives, three
  understandings, and the person's taste does the choosing.

## What this project is not

- Not a natural-language parser — the *pipeline* never reads English.
  The scene vocabulary is designed so prose translates nearly
  word-for-word, and the porch's small local model does that literal
  translation when asked; but its output enters through the same door,
  faces the same wall, and earns no special trust.
- Not a general image library. It draws glowing particles on black.
  Vibrantly.
