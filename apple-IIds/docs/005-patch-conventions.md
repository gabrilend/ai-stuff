---
name: patch conventions
status: draft (planning phase, 2026-05-19)
---

# patch conventions

This project modifies upstream code we do not own: GSplus's C source,
Apple's released GS/OS assembly source, and eventually the IIgs Toolbox
ROM. We **never** fork upstream into our tree. We keep upstream pristine
and modify it through numbered, paired apply/unapply patches.

This document defines:

- where patches live
- how they are named
- the apply/unapply discipline (this is load-bearing — read it twice)
- when each kind of patch is applied during a build

## layout

Patches live under `patches/` at the project root. Each feature that
modifies upstream code gets a shared numeric prefix. The flat layout
(rather than per-feature subdirectories) was chosen deliberately so
that each layer's patches can be applied at a different stage of the
build, picked up from a single directory by file-name pattern.

```
patches/
├── 050-shared-clipboard.gsplus.patch    (diff against libs/gsplus/)
├── 050-shared-clipboard.gsos.s.patch    (diff against libs/gsos-src/)
├── 060-input-routing.gsplus.patch
└── 060-input-routing.gsos.s.patch
```

Broker code is **ours** — not upstream — and lives at `src/broker/`. It
is edited directly, not patched. When a feature touches the broker too,
the broker side is a normal `.lua` module **named with the same prefix**:

```
src/broker/050-shared-clipboard.lua
src/broker/060-input-routing.lua
```

A complete cross-surface feature is therefore grep-able by its number
across `patches/` and `src/broker/`.

## naming

`NNN-feature-name.layer.patch` where `layer` is one of:

- `gsplus` — unified diff against GSplus C source
- `gsos.s` — unified diff against GS/OS assembly source
- `tbox` — bytes patch against the Toolbox ROM (rare; phase 8+ only)

Broker-side files are `NNN-feature-name.lua` (or `.c` / `.h` if any of
the broker grows into C) under `src/broker/`.

## the apply / unapply discipline

This is the central rule: **upstream trees stay pristine between build
stages**. Patches apply only inside the narrow window when the relevant
tool is operating on that source, and are reverted immediately
afterward. A developer who opens `libs/gsplus/` between builds sees
upstream code, never our modifications.

The reasons:

- **Easy upstream upgrades.** When GSplus releases a new version, we
  drop in the new source and re-apply our patches. No three-way merge
  against a forked tree.
- **The diff IS the changelist.** A reader who wants to know what we've
  done to GSplus reads `patches/*.gsplus.patch` directly. They do not
  have to diff our `libs/gsplus/` against the upstream URL.
- **No accidental commits of patched code.** Git tracks the patches,
  not the patched-source state.
- **Stage isolation.** Working on the broker does not require the
  GSplus tree to be in any particular state. Working on GSplus does
  not require the GS/OS tree to be patched. Each layer's source can
  be worked on independently because between stages it's pristine.

The build pipeline therefore looks like:

```
GS/OS stage:
  apply  patches/*.gsos.s.patch
  assemble GS/OS  →  link  →  package as .2mg
  revert patches/*.gsos.s.patch

GSplus stage:
  apply  patches/*.gsplus.patch
  cross-compile GSplus to aarch64
  revert patches/*.gsplus.patch

Broker stage:
  no patches needed (broker code is ours, edited directly)
  build / bundle src/broker/

ROM stage (phase 8+ only):
  apply  patches/*.tbox  to a COPY of the ROM image
  save the patched copy alongside the pristine original
  the original assets/rom/iigs.rom is never modified

Bundle stage:
  combine GS/OS .2mg, GSplus binary, broker code, patched ROM (if any)
  into tmp/build/  →  deploy
```

If a stage exits with patches still applied (a crash, an interrupted
build, a Ctrl-C), the next invocation must detect the inconsistent
state and clean it up before proceeding. A sentinel file in `tmp/`
written when patches are applied and removed when they're reverted
makes this detectable.

## working on patched code (interactive mode)

For interactive development — when you want to hack on GSplus source
in your editor for hours, not seconds — `develop.sh` (to be written in
issue 102) keeps patches applied for the duration of the session:

```
develop.sh gsplus       # apply all *.gsplus.patch, stay applied
develop.sh gsos         # apply all *.gsos.s.patch, stay applied
develop.sh freeze       # diff current source state, write back into patches/*
develop.sh revert       # un-apply, restore pristine upstream
```

`freeze` is the critical operation: after editing patched source,
running `freeze` captures the new diff and writes it back to the
appropriate `patches/*.patch` file. Then `revert` returns the upstream
tree to pristine.

**The discipline: never commit upstream trees with patches applied.**
The sentinel check in `build.sh` enforces this for builds; a git
pre-commit hook (added in a later phase) will enforce it for commits.

## numbering

Numbers count up from 001. Skips are fine; gaps for future patches in
a related cluster are encouraged. The convention is:

- `0NN` — clipboard, IPC, scrap manager work
- `1NN` — input routing, ADB, event manager work
- `2NN` — framebuffer, QuickDraw, video work
- `3NN` — file manager, disk management work
- `4NN` — sound, Ensoniq work
- ... and so on

These ranges are advisory. The numeric prefix's only hard job is to
couple the cross-surface files of a single feature.
