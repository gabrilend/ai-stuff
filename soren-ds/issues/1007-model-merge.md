# 1007 — Model merge

## Current behavior

Models save and load (1005, 1006) but cannot yet combine — a
sword model and a hand model are two separate files, not one
hand-holding-a-sword model.

## Intended behavior

The drawer's "merge with..." option lets the user pick a second
model and identify which vertex of each model serves as the
shared anchor point. The flow:

1. The user opens the merge sub-flow from the drawer.
2. The user picks the second model from a file picker; the
   second model loads alongside the current one as an
   auxiliary working set (rendered translucently in the
   perspective view so the user can see both).
3. The user moves the cursor to a vertex on the current model
   and presses `A` to anchor.
4. The user moves the cursor to a vertex on the auxiliary
   model and presses `A` again to anchor.
5. The user picks "commit merge" from the drawer.

The commit:

- Translates every vertex on the auxiliary model by the
  offset between its anchor and the current model's anchor.
- Adds the translated auxiliary vertices to the current
  model's grid. If two vertices end up at the same coords
  (the anchor pair, by construction), the auxiliary's vertex
  is dropped and any face referencing it is rewired to the
  current model's vertex.
- Adds the auxiliary's faces to the current model's face list.

This is graph union with one vertex identified. The
encapsulation splicer (305) does the same operation when one
soramech map encapsulates another with an external port; the
modeller uses the same logic on its own data.

Optionally, before commit, the user opens the interior detail
options (1008) to choose whether interior vertices and faces
get culled.

## Suggested implementation steps

1. `model_load_auxiliary(name)` — loads a second model
   alongside the working set.
2. `anchor_select(vertex)` — marks a vertex as an anchor.
3. `merge_commit()` — translation, vertex-merge,
   face-translation, optional culling.
4. Auxiliary-model rendering in the perspective view.

## Related documents

- `docs/010-modeller.md` — merging models section.

## Blocked by

1003, 1006, 1008.

## Blocks

1011.
