# Filesystem Tapestry — Documentation Table of Contents

The tree of every document in `docs/` and `notes/`. Source files and issue files
are not listed here (they have their own homes: `src/*.info.md` for code,
`issues/` for tickets).

```
filesystem-tapestry/
├── notes/
│   └── vision ................... What the tapestry is and why it exists.
│                                  The spindle-into-tapestry metaphor; the three
│                                  walks; policy-based similarity; the two halves.
│
└── docs/
    ├── table-of-contents.md ..... This file.
    ├── roadmap.md ............... Phases as clusters of functionality. Phase 1
    │                              (the thread), Phase 2 (the meaning), Phase 3
    │                              (the loom). Design invariants.
    └── datapath-catalog.md ...... One file's journey from disk to viewer. The
                                   catalog record shape, the generation/viewing
                                   boundary, the field reference table.
```

## Phase index

- **Phase 1 — The Thread.** Catalog of dates + chronological walk + media
  dispatch. The runnable spine.
- **Phase 2 — The Meaning.** Policy descriptions, embeddings, and the
  similar/different orderings that ride on them.
- **Phase 3 — The Loom.** Static HTML surfacing, incremental re-scan,
  cross-drive dedup.

## Where to read next

- New here? Read `notes/vision`.
- Want to know how data moves? Read `docs/datapath-catalog.md`.
- Want to know what is built vs. planned? Read `docs/roadmap.md`, then run
  `scripts/validate.sh --stats` for live numbers.
