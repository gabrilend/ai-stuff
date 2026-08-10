# Table of Contents — Xonotic Turning Radius

A laptop keyboard layout for Xonotic, delivered as reversible patches against an
upstream tree that is never forked.

```
xonotic-turning-radius/
│
├── notes/
│   └── 000-vision.md ................ the problem (a laptop has no thumb or pinky
│                                      buttons), the mirrored two-hand layout, the
│                                      three turning behaviors, the mode switch,
│                                      and the original words it started from
│
├── docs/
│   ├── 001-open-questions.md ........ every fork in the design that is still
│   │                                  open, with the mechanism behind each, so
│   │                                  none of them reads as settled
│   ├── 002-datapath-the-input-path.md  a trace from keypress to view angle
│   │                                  through both source trees, with file and
│   │                                  line references; concludes which layer can
│   │                                  host which behavior
│   ├── table-of-contents.md ......... this file
│   ├── balance-updates.md ........... append-only record of tuned numbers —
│   │                                  turn rates, thresholds, windows — and why
│   │                                  each was changed
│   ├── patches/
│   │   └── patch-registry.md ........ GENERATED from patch script headers;
│   │                                  never hand-edited
│   └── HTML/ ........................ browsable rendering of all documentation
│
├── issues/ .......................... blueprints, phase by phase
│   └── completed/
│       └── demos/ ................... one runnable demonstration per phase
│
├── patches/ ......................... THE SOURCE OF TRUTH: apply/unapply pairs
├── scripts/ ......................... the machinery that drives them
├── source/ .......................... the cloned upstream — gitignored, disposable
└── tmp/ ............................. symlink to RAM-backed scratch
```

## Phases

The phases group functionality, not calendar time. A late issue may well belong
to phase one.

**Phase 1 — The patch machine.** The apply/unapply component shape, the
orchestrator, the generator, the round-trip verifier, the registry generator, and
the clone/reset lever. Nothing Xonotic-specific. This exists first because
everything after it is expressed as one of its components.

**Phase 2 — The layout.** The laptop bind file and the collisions it has to
clear. Pure configuration, no code. Reaches a playable state on stock binaries
with none of the turning mechanics present.

**Phase 3 — The mode switch.** The laptop-mode button, its one-slot undo, and the
label that reports what it will do next. Menu game code, modelled on the existing
reset-all button.

**Phase 4 — The turning mechanic.** Press timing (which neither layer currently
keeps), the acceleration curve, tap quantization, and the double-tap gestures.
The one phase that requires a layer decision.

**Phase 5 — Delivery.** Packaging, the audit pass against a newer upstream, and
the demonstration that shows the layout being played rather than described.

## Reading order

The vision first, then the datapath — the datapath is what turns the vision's
three wishes into three separately-located pieces of work. The open questions
are the reason no phase past the second can be called finished yet.

## Numbers

No tuned constant is quoted in prose anywhere in this documentation. Turn rates,
tap thresholds and gesture windows live in `docs/balance-updates.md` as an
append-only record, and in the patch scripts as the values actually applied.
Documentation that quotes a number goes stale the first time the number is
tuned, and a stale number reads exactly like a current one.
