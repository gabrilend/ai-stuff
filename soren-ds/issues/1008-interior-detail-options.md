# 1008 — Interior detail options

## Current behavior

The merge (1007) joins two models into one but always keeps
every vertex and every face. For models that are large or that
will never be split apart, the interior detail wastes memory
and rendering cycles. The modeller doc calls for the user to
choose between dropping and keeping interior detail at merge
time.

## Intended behavior

Before committing a merge, the user picks one of two interior
detail policies from the drawer:

- **Drop interior.** After translation but before commit, the
  merge sweeps the combined geometry looking for vertices and
  faces enclosed by faces of both source models. An enclosed
  vertex is one whose every adjacent face has its outward
  normal pointing into the other model's interior. Drop them.
  An enclosed face is one with the same property at the face
  level. Drop them.
- **Keep interior.** No sweep, no drop. The combined model
  retains every detail and can be split back into two by
  inverse-translation (a future feature; the launch system
  doesn't implement split, only the structural support).

The sweep is a per-vertex normal check: for each vertex on the
auxiliary model's surface, raycast outward from the vertex along
its normal; if every ray strikes a face of the *current* model
before hitting open space, the vertex is interior. Same for
faces.

The sweep is O(V × F) for V auxiliary vertices and F current
faces; on launch's 32 × 32 × 32 grid with a model of a few
hundred vertices, this completes in under a second on the
device's CPU.

The choice the user makes persists with the merged model — if
they save the merged result, the saved metadata records which
policy was applied, so a future load knows whether interior
detail was preserved or already culled.

## Suggested implementation steps

1. The interior-drop sweep — raycast-based detection.
2. The merge UI choice: drawer radial menu with two options.
3. Metadata field on saved models recording the policy.
4. The "kept interior" flag exposed in the inspector (1009) so
   the user can see at a glance whether a model is splittable.

## Related documents

- `docs/010-modeller.md` — interior vertices/faces section.

## Blocked by

1007.

## Blocks

1011.
