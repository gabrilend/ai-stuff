---
name: soramech editor cross-ported to Apple IIds
phase: 12
status: pending
blockedBy: [1104]
---

# 1201 — soramech editor cross-ported

Soramech's editor — gabrilend's preferred development environment —
runs on the bare-metal Apple IIds as a first-class application.
This is the moment the device becomes self-hosting: you can write
new Apple IIds programs without a separate development machine.

## current behavior

Soramech's editor runs on whatever host gabrilend uses for soramech
development. It is not available on the RG DS.

## intended behavior

- Soramech's editor is ported to run as a native Apple IIds
  application:
  - Uses the Apple IIds Toolbox (Window Manager, Event Manager,
    etc.) for its UI.
  - Uses the threading primitives for any background work
    (parser, syntax highlighting, autocomplete).
  - Reads / writes files via the shared filesystem (so source
    code is visible on both screens, and a single project can
    span the two-IIds workspace).
- The editor's feature set is at least feature-parity with
  soramech's desktop / handheld version. Specific features
  (chord-keyboard handling, region commands, etc.) come along
  in the port.
- The editor's primary language target is **ARM assembly** —
  it's what Apple IIds programs are written in. Syntax
  highlighting, error markers, completion are all
  ARM-assembly-aware.

## suggested implementation steps

1. Wait for issue 1104 (the Toolbox port) — the editor depends
   on it heavily.
2. Read soramech's editor source. Catalog its dependencies and
   features.
3. Replace platform-specific dependencies with Apple IIds
   equivalents:
   - soramech's UI primitives → Apple IIds Toolbox
   - soramech's filesystem layer → Apple IIds File Manager
   - soramech's keyboard handling → Apple IIds Event Manager
     plus the radial-keyboard input
4. Port the editor's core logic (text buffer, parsing, syntax
   highlighting) — this is mostly platform-independent and
   ports cleanly.
5. Test on the device: load a sample ARM assembly file, edit it,
   save it.

## related documents

- `notes/vision/000-vision.md` — in-device programming section
- `issues/1104-iigs-toolbox-arm.md` — the dependency
- Soramech editor source (external)

## known design questions

- Soramech's editor may have features specific to soramech's
  threading-as-language-feature model (the language spec system
  we're explicitly not lifting). Those features have no
  meaning in Apple IIds and are removed in the port.
- Should there be a single-instance or dual-instance editor (one
  per screen)? Both — but the dual-instance case is two
  coordinated pair-programs (per the spanning rule), where one
  screen is the source code and the other is, say, the
  disassembly / debugger view.

## notes

- This is the issue that closes the development loop. After it,
  the device is self-hosting.
