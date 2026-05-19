# table of contents

A tree-hierarchy index of all documentation and notes in this project.
Source code and issue files are not listed here; see `issues/` and `src/`
for those. The eventual HTML rendering at `docs/HTML/` will mirror this
tree with clickable cross-references between every page.

```
apple-IIds/
├── notes/
│   └── vision/
│       └── 000-vision.md ............ the project's reason for existing
│
├── docs/
│   ├── 000-table-of-contents.md ..... this file
│   ├── 001-architecture-overview.md . three-layer Option C architecture
│   ├── 002-hardware-target.md ....... Anbernic RG DS specs (pinned 2026-05-19)
│   ├── 003-input-system.md .......... radial dual-stick keyboard + touch + stylus
│   ├── 004-roadmap.md ............... phases of development (1 → 12+, staging → bare-metal)
│   ├── 005-patch-conventions.md ..... apply/unapply discipline for upstream code
│   ├── 006-soramech-thread-pool-report.md . research note on soramech threading (snapshot 2026-05-19)
│   └── balance-updates.md ........... append-only log of knob-turning (not yet started)
│
└── issues/
    ├── phase-1-progress.md .......... live status of phase 1
    ├── 101-..., 102-..., ..., 106-..., 120-... phase 1 issue files
    ├── pending/ ..................... drafted but not started
    └── completed/ ................... immutable, completed issues
```

## marker conventions

Documents in this project may carry one of the following markers in their
header or in a section heading:

- **pending soramech** — the section describes behavior that depends on
  the threading primitives being developed at
  `/home/ritz/programs/sora/soramech/`. Re-read and validate the section
  once that upstream work stabilizes.
- **draft** — the document is in planning state; numbers and decisions
  inside it are not yet load-bearing.
- **provisional** — a decision has been made but is expected to change
  after the first hardware test.
- **pinned** — a decision has been made and a specific external thing
  (model, version, vendor) is now locked in.
