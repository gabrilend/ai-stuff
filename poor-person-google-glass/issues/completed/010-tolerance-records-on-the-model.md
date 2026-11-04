# 010 — Tolerance records on the model

**Phase:** 0 — Tools
**Blocked by:** 005, 009
**Related documents:** docs/tolerances.md, docs/joints.md

## Current Behavior
Built: input/materials.lua (six materials); `src/024-writing-lua-data.lua`
(the writer moved out of 022, now shared), `025-materials.lua`,
`026-finding-joints.lua`, `027-joint-records.lua`, `028-joints.lua` and the
`joints` script; `input/calculations/joint-gap-under-heat.lua` (the general
calculation); the viewer's marks, `j` and the joints view; tests in
`src/029-the-joint-tests.test.lua`. Records exist for the crown sketch
(materials and two joints filled in as an example: the glass light pipes
on the nylon band fail, pressing in when warm; the panel arm and panel
pass), the light pipe, the glasses and the described crown (all empty
spots).

Decided while building: an empty spot is written out ("" / "unassigned" /
-1), never left missing, so it can be seen; measures are rounded to 6
figures, the file being read and edited by people; a worked answer carries
a signature of what it depended on, so the viewer shows a joint changed
since as waiting, not with an old verdict; the joints program finds its
code beside itself, so it can work on any folder holding a project's data
(found when the end-to-end test ran it on a small project in RAM).

Open question 15 (docs/open-questions.md) asks whether the models should
name each piece separately, since a joint between grouped parts is coarse;
that is a question for the models, and this tool works either way.

## Intended Behavior
The owner: "can we update the model viewer to be able to keep records of
those tolerances? We should have an empty spot for each piece that
interacts with another piece, and we can put an equation in there and have
input values to the math function be derived from the structure of the
object and it's predetermined material fundamentals."

- **Materials** (input/materials.lua): each a name and its fundamentals —
  expansion with heat, density, stiffness, refractive index where it has
  one — each a value with its tolerance and source, in the same shape as a
  calculation's inputs.
- **Joint records** (input/joints/MODEL.lua), one file per model:
  - `materials`: each part's material name — an empty spot ("unassigned")
    for every part until filled;
  - `joints`: one entry per pair of parts that touch or nearly touch,
    found from the geometry: what was measured (`found`) and an empty spot
    for an `equation` (a calculation's name from input/calculations/) and
    its `inputs`, each bound to a structure measure (`structure.gap`), a
    material fundamental of one side (`a.expansion`, `b.expansion`), or a
    plain number.
  - Finding again never overwrites what a person wrote: new pairs are
    added empty, measurements refreshed, and a pair no longer found is
    kept, marked as no longer found.
- **Structure measures** per joint: the gap between the two parts' surfaces
  (zero when touching), where they come closest, the direction across the
  contact, how far each part reaches along that direction, and how large
  the contact is.
- **Working out**: every filled joint is worked out with 009's engine, the
  bound inputs' nominal values replaced by the structure and material
  values (a material's tolerance replaces the calculation's).
- **The viewer** reads the records and their results and marks every joint
  on the model: grey empty, gold written but not worked out, green pass,
  red fail, each labelled with its two parts; `j` shows or hides them, and
  a "joints" view shows them in pictures.

## Suggested Implementation Steps
1. docs/joints.md (the record format); input/materials.lua.
2. src: materials and their checks; reading and writing Lua data; finding
   joints (closest distance from each part's corners to the other's
   triangles, through a grid so only nearby triangles are tried); joint
   records (merge); working out joints.
3. `joints` script: find, then work out, then report.
4. A general calculation: how a gap between two parts changes with heat.
5. Viewer: markers, `j`, the joints view.
6. Tests: two boxes a known distance apart give that gap; touching faces
   give zero; refinding keeps a written equation; a filled joint works out
   with the material's values.
