# Table of Contents

Everything in `docs/` and `notes/`, in reading order. Issue files are not listed
here; they are reached through [the roadmap](003-roadmap.md).

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers below are a reading order and not a
per-directory sequence.

```
graphene-factory/
│
├── notes/
│   └── vision ................................ Why this factory exists. The
│                                               seventy-five-thousand-to-one
│                                               copper problem, and the idea of
│                                               treating the copper as apparatus
│                                               rather than as stock.
│
├── docs/
│   ├── 000-what-this-factory-is.md ........... The whole plant in one read. What
│                                               a machine specification contains,
│                                               and why there is a slot in the
│                                               middle of the line with three
│                                               candidate machines for it.
│   ├── 001-the-material-walk.md .............. One pass from the gas bottle to a
│                                               cut sheet. Eleven stations, what
│                                               happens inside each at the level
│                                               of atoms, and what must be true
│                                               at every boundary.
│   ├── 002-the-invariant-ledger.md ........... All twenty-three conditions in one
│                                               table, with where each is made
│                                               true, where it is relied on, and
│                                               what breaks when it fails.
│   ├── 003-roadmap.md ........................ Seven phases, ordered by what
│                                               stands on what.
│   ├── 004-open-questions.md ................. Twelve things the design has
│                                               raised and not settled. Worked
│                                               through one at a time.
│   └── HTML/ ................................. Browsable cross-linked versions of
│                                               everything above. Not built yet.
│
├── issues/ ................................... Blueprints for building the
│                                               design, one per piece. Not written
│                                               yet — several depend on questions
│                                               that are still open.
│   └── completed/
│       └── demos/
│
├── assets/ ................................... Setpoint tables. The numbers the
│                                               documents point at rather than
│                                               quote, so they cannot go stale.
│                                               Empty until the three release
│                                               designs can be compared.
│
├── src/ ...................................... Empty on purpose. This is a paper
│   libs/                                       facility.
│
├── input/ .................................... What goes into the box.
├── output/ ................................... What comes back out. Goodbye is
│                                               written here last.
├── desire/ ................................... Notes on what should be better.
├── faith/ .................................... Expectation of boons.
├── strategems/ ............................... Data flow patterns that turned out
│                                               to work in more than one place.
│
└── tmp/ ...................................... Symlink to the RAM exec tier at
                                                /tmp/graphene-factory. Inside it,
                                                shared-memory/ points at
                                                /dev/shm/graphene-factory for
                                                logs and other ephemera.
```

## The shortest path in

Read [what this factory is](000-what-this-factory-is.md), then
[the material walk](001-the-material-walk.md). Those two carry the design.
Everything else is either a reference table for them or a plan to extend them.
