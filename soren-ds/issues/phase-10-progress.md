# Phase 10 progress — The modeller

Phase 10 ships the first post-launch app — the modeller — as the
proof that the platform built across phases 1 through 9 hosts
applications the architects didn't pre-bake. The modeller's
design lives at `docs/010-modeller.md`. By the end of the phase,
the user can place vertices on a 3D grid through the perspective
view on one screen and an inspector on the other; form those
vertices into triangle and quad faces; color and roughen faces
through the radial menu; save models to `/models/` as their own
kind of soramech map; load saved models; and merge two models
into a third with control over interior detail.

The modeller is the first app that uses encapsulated sub-maps
(305) for actual application logic. Each model is a sub-map of
vertex boxes wired by face wires; merging two models is a graph
union with anchor vertex identification. The launch system's
encapsulation splicer flattens models the same way it flattens
any other sub-map.

## The story of the phase

1. `1001-vertex-grid-representation.md` — the data structure
   that holds a 3D point cloud anchored to a grid.
2. `1002-cursor-and-vertex-placement.md` — move the cursor
   through the grid with the analog stick; place vertices with
   a face button.
3. `1003-face-formation.md` — select three or four placed
   vertices and form them into a face.
4. `1004-face-color-and-roughness.md` — radial-menu picks for
   each face's appearance properties.
5. `1005-model-persistence.md` — save a model as a soramech
   map under `/models/`.
6. `1006-model-loading.md` — load a saved model back into the
   modeller's working state.
7. `1007-model-merge.md` — graph union of two models with
   anchor vertex identification.
8. `1008-interior-detail-options.md` — at merge time, drop
   interior vertices and faces (saving memory) or keep them
   (allowing reversibility).
9. `1009-modeller-ui-perspective-and-inspector.md` — render
   the perspective view on one screen, the inspector on the
   other.
10. `1010-modeller-drawer-and-integration.md` — drawer
    options, inter-app exits to the files app and the
    programming environment.
11. `1011-phase-10-demo.md` — build a small model, color it,
    save it, merge it with a second, observe the platform
    hosting it.

## Completed issues

None yet.

## Open issues

All of 1001 through 1011.

## Phase demo

`issues/completed/demos/phase-10/run.sh` will exist once the
phase closes. The user builds a small five-vertex pyramid model
from a blank grid, colors its four triangular faces, saves the
model, builds a second cube model, merges the two by anchoring
the pyramid's apex to the cube's top face, drops interior
detail, and verifies the merged model loads back cleanly. The
script verifies the saved files' structure and the merge result.
