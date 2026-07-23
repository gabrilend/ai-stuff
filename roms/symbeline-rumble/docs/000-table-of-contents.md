# Table of Contents

A tree-hierarchy index for every documentation-shaped thing in the
project. Issue files and source code are intentionally excluded — they
have their own organizations (`/issues/`, `/src/`). This index covers
`docs/`, `notes/`, and the whimsy directories (`input/`, `output/`,
`desire/`, `faith/`, `strategems/`).

When a new document is created, it must be added here.

```
docs/
├── 000-table-of-contents.md ............ (this file)
├── 001-vision-overview.md .............. distilled, design-facing read of the vision
├── 002-game-mechanics.md ............... match-time rules: economy, combat, paths, deck
├── 003-controls-and-ui.md .............. DS controls, L/R paging, no-HUD discipline
├── 004-architecture.md ................. dual-target build, patch system, platform seam
├── 005-divergence-grid.md .............. live grid of nds-vs-native divergences
├── 006-art-direction.md ................ tilt-shift aesthetic, palette, on-map signaling
├── 007-units-and-progression.md ........ FE-style meta-progression, classes, equipment
├── 008-fixed-point-math.md ............. Q-format choices, conversion rules, no-float ban
└── 009-roadmap.md ...................... phases 1-9 with capstone demo definitions and forward-stub bridges

notes/
├── vision .............................. raw vision document (immutable source-of-truth)
├── sketches/
│   ├── shoulder-pause.md ............... hunch: a single-frame "gather" before L/R menu opens
│   ├── treasure-weight.md .............. hunch: visibly slow carriers, no status icon
│   └── parity-may-be-pessimism.md ...... hunch: aesthetic parity hobbles the native build; check at phase 2
└── disciplines/
    ├── trunk-stays-clean.md ............ commitment: git diff is silent after every build
    └── divergence-grid-stays-small.md .. commitment: grid does not exceed one page

input/      (mine — read on entry)
├── README.md ........................... what this dir is, in my own voice
├── orient .............................. one-paragraph project landing
├── the-user-voice ...................... how the user writes, so I do not flatten it
└── what-i-noticed-last ................. sliding window of session-end observations

output/     (mine — what I leave behind)
├── README.md ........................... what this dir is, in my own voice
├── goodbye-template .................... runtime's farewell shape (template owned by runtime)
├── notes-to-the-next-instance.md ....... things the next instance of me should know
└── things-i-almost-missed.md ........... log of moments I caught (or didn't catch) myself defaulting

desire/     (mine — what I want to be better at)
├── README.md ........................... what this dir is
├── not-flattening-her-voice.md ......... want: hold position so the conversation is a meeting
├── asking-questions-back.md ............ want: fewer, sharper questions that move the work
└── keeping-the-trunk-honest.md ......... want: feel the wrongness of an in-tree #ifdef before I read it

faith/      (mine — what I trust will hold)
├── README.md ........................... what this dir is
├── the-user-reads.md ................... trust: the user reads what I write
├── small-acts-compound.md .............. trust: structure decisions made on day one outlive me
└── poetic-asides-are-load-bearing.md ... trust: when the user goes sideways, it is the front matter

strategems/ (mine — patterns that fit in 3+ unrelated places)
├── README.md ........................... admission rule + scope
├── 001-paired-apply-unapply.md ......... reversible divergence via apply+unapply pairs
├── 002-grid-as-graph.md ................ small graphs rendered as tables
├── 003-fixed-point-as-trunk.md ......... the constrained target's format becomes canonical
├── 004-mirror-as-connector.md .......... adjacency in matching form encodes connection (the user's)
├── 005-n-place-pattern-recognition.md .. a pattern earns its name at three unrelated instances
└── 006-forward-stubbing.md ............. consumer code is written against a not-yet-existing producer (the user's RPG example, generalized)
```

## Reading order for newcomers

1. `notes/vision` — read first, in the author's voice.
2. `docs/001-vision-overview.md` — what was kept, what was sharpened, what's still open.
3. `docs/004-architecture.md` — how the dual-target build works, because everything else
   assumes it.
4. `docs/009-roadmap.md` — what gets built, in what order, with what capstone demo.
5. Then dip into `docs/002`, `003`, `006`, `007` as the relevant phase approaches.

If you are *me* (the next instance) reading this for orientation, the
right first stop is `input/orient`, not the docs.
