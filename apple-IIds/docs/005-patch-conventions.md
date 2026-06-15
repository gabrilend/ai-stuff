---
name: patch conventions
status: draft (planning phase, 2026-05-19)
---

# patch conventions

This project modifies upstream code and assets we do not own: GSplus's
C source, the user-supplied GS/OS `.2mg` disk image, and eventually the
IIgs Toolbox ROM. We **never** fork upstream into our tree. We keep
upstream pristine and modify it through numbered, paired apply/unapply
patches. We do **not** rebuild GS/OS from source; Apple never officially
released GS/OS source, so the disk-image surface is binary-patched and
new functionality is added as injected drivers / CDevs we author.

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
├── 050-shared-clipboard.gsos.bin.patch  (byte patch against the user-supplied .2mg)
├── 060-input-routing.gsplus.patch
└── 060-input-routing.gsos.bin.patch
```

New OS-level functionality we *author* (not patch) lives at
`src/gsos-addons/NNN-feature-name/` as 65C816 assembly source for
Device Manager drivers, CDevs, and startup files. The build assembles
these and the disk-image stage adds the resulting binaries onto the
patched copy of the user's `.2mg`.

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
- `gsos.bin` — byte patch against a working copy of the user-supplied
  GS/OS `.2mg` disk image (binary patch; the user's original `.2mg` is
  never modified — every build operates on a copy)
- `tbox` — byte patch against a working copy of the Toolbox ROM (rare;
  phase 8+ only; user's original ROM is never modified)

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
GSplus stage:
  apply  patches/*.gsplus.patch    (to libs/gsplus/)
  cross-compile GSplus to aarch64
  revert patches/*.gsplus.patch

GS/OS addon stage:
  assemble src/gsos-addons/*/*.s with the 65C816 cross-assembler
  produce one binary file per addon (Device Manager driver, CDev, etc.)

GS/OS disk-image stage:
  copy the user-supplied assets/disks/gsos-boot.2mg to tmp/build/
  apply patches/*.gsos.bin.patch to the COPY (never the user's original)
  inject the assembled addons onto the disk image (via cadius/cppo or
  similar disk-image tooling) at well-known paths

Broker stage:
  no patches needed (broker code is ours, edited directly)
  build / bundle src/broker/

ROM stage (phase 8+ only):
  copy the user-supplied assets/rom/iigs.rom to tmp/build/
  apply patches/*.tbox.patch to the COPY (never the user's original)

Bundle stage:
  combine the patched .2mg, GSplus binary, broker code, patched ROM (if
  any) into tmp/build/  →  emit manifest  →  deploy
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
develop.sh freeze       # diff current source state, write back into patches/*
develop.sh revert       # un-apply, restore pristine upstream
```

`develop.sh gsos` is intentionally **not** provided: the `gsos.bin`
patches are byte-level edits to a binary disk image and have no
text-editor workflow. Author them with a hex editor against a copy
in `tmp/` and capture the diff with a small helper script.

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
