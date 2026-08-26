# Table of Contents

Every document in `docs/` and `notes/`. Source files and issue tickets are not
listed here; the source is reached through `docs/035-a-walkthrough.md` and the
tickets through `docs/006-roadmap.md`.

File indices count upward across the whole project rather than per directory, so
the files can be read in order as one story: what this is, where the data comes
from, how the trick works, then the machine that does it. The highest index in
use is kept in `.file-index-counter` at the project root.

```
kanji-learning-image-generator/
├── notes/
│   └── vision ....................... the page it started from
│
├── docs/
│   ├── table-of-contents.md ......... this file
│   ├── 001-what-this-makes.md ....... a picture that is the character, and what is refused
│   │
│   ├── 002-datapath-the-two-archives.md  strokes from one file, meanings from another
│   ├── 003-datapath-the-structure-field.md  the grey image the illusion rides on
│   ├── 004-datapath-the-scene-grammar.md  which piece is a subject, which is only a sound
│   ├── 005-datapath-the-workflow.md .. the ComfyUI graph, in the two shapes it accepts
│   │
│   ├── 006-roadmap.md ............... three phases; parts, not dates
│   ├── 007-open-questions.md ........ every question, closed and open, in one place
│   ├── 035-a-walkthrough.md ......... the things a person can run, and what each does
│   ├── balance-updates.md ........... every knob turned, and why
│   └── HTML/ ........................ all of this, cross-linked; built, never edited
│
├── src/ ............................. the machine
├── libs/ ............................ external code
├── assets/ .......................... the two archives; fetched, not committed
│
├── issues/ .......................... tickets; blueprints for building this
│   ├── phase-N-progress.md .......... where each phase stands
│   └── completed/
│       └── demos/ ................... one runnable demonstration per completed phase
│
├── input/ ........................... what the programs read at startup
├── output/ .......................... what they return, ending in goodbye
├── desire/ .......................... notes on what should be better
├── faith/ ........................... expectations of boons and blessings
├── strategems/ ...................... dataflow patterns that worked more than once
├── llm-transcripts/ ................. the dialogue this was built out of
│
├── run-demo ......................... asks which phase to show, and shows it
└── run-tests ........................ every test in the project
```

## The three phases, as sections of the machine

Phases group functionality, not time. The last thing built in this project may
well belong to phase 1.

**Phase 1 — The Ink.** Bytes into geometry into pixels. XML scanning, the two
archive readers, the record they join into, the SVG path language, curve
flattening, the raster surface, PNG, JSON. Nothing here knows what a kanji means.

**Phase 2 — The Meaning.** A record into a scene. Stroke measurement, the
structure field, the component lexicon, the biome and subject grammar, the prompt,
the stroke-order arrows. Nothing here knows what ComfyUI is.

**Phase 3 — The Machine.** A scene into a file somebody can run. The node graph
and its catalogue, the workflow, the whole set in parallel, the gallery, this
documentation as a website, the demonstrations.
