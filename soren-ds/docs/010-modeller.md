# Modeller

An on-device 3D modeller. The user places vertex points on a 3D
grid by moving the cursor through the grid and pinning a vertex
where they want one. Vertices group into faces. Faces get colors
and roughness values through the radial menu, the same input
mechanism the editor and the paint program use. Finished models
save to the SD card as their own kind of soramech-readable file.

The modeller does not ship at launch. It sits past the four launch
apps in the development cycle, because the things it depends on
have to land first.

## What it depends on

- **The filesystem.** Models save to the SD card the same way
  drawings and program text save. This arrives in phase 4.
- **The soramech runtime.** A model is a small soramech map of
  vertex boxes connected by face wires. Merging two models — for
  equipment, for lego-style construction, for joining a sword to a
  hand — is a graph operation on the two maps. The runtime that
  makes graph operations safe and fast is phase 5.
- **The compositor.** The modeller draws to both screens at once —
  perspective view on one, an inspector on the other. Phase 6.
- **The radial menu.** Already provided by the editor in phase 8.
- **Memory protection.** The modeller is the kind of app where
  the user routinely makes the program do things its author never
  imagined. Protection-only MMU mode (phase 9) keeps a wild merge
  from corrupting the kernel.

Because of those dependencies, the modeller lives in phase 10 —
the first phase after the launch system is complete. Phase 10 is
the first place we can build a launch-quality app that requires
features from every preceding phase.

## What it does

A **vertex** is a point in a 3D grid. The grid is the canvas the
user moves the cursor through; the cursor is positioned by the
analog stick and confirmed with a face button. Vertices the user
places stay; the grid keeps showing where they could place more.

A **face** is the triangle formed by three connected vertices, or
the quad formed by four. Faces have a color and a roughness value,
chosen from the radial menu. The user taps a face to select it and
the radial menu becomes the face's editor: D-pad direction picks a
color category, face button picks the specific color; another
mode picks roughness the same way. Vertices themselves are not
colored — they have no surface to color.

A **model** is a collection of connected vertices and faces, saved
as a single soramech map. Loading a model materializes the map.
Saving exports it.

## Merging models

Two models merge by joining their maps. The user picks two anchor
vertices, one on each model, and asks for a merge. The result is
a single map whose vertices and faces are the union of the two
input maps with the anchors identified as the same point.

Two questions arise during the merge, with the user controlling
which way each goes:

- **Interior vertices.** When two models join — a hand holding a
  sword, a helmet on a head — some vertices end up inside the
  combined shape, never visible from outside. The user can ask
  the merge to drop those interior vertices (saving memory) or
  keep them (so the models can separate later without losing
  detail).
- **Interior faces.** Faces with both their owning models entirely
  on the same side of them are also interior. Same choice.

The merge is reversible if interior detail was kept. The merge is
final if interior detail was dropped. The user chooses each time.

## The fifth app and the platform

This document exists at the same time as the four launch apps so a
reader sees the shape of the platform from both sides: the four
apps that ship, and the fifth app that proves the platform can
host things the original architects didn't ship. If a fifth app
this complex can be built using only the phases-1-through-9
primitives, the architecture is doing its job. If it can't, the
architecture is missing something we should know about before
phase 10 starts.

The seed of this idea lives in `notes/3c-model` in its original
form. This doc is the formal specification grown out of that note;
the note itself is preserved as the artistic record of the idea.
