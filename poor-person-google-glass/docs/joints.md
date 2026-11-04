<!-- Made by Claude (Opus 5.5), 2026-10-10, for issue 010, as the contract for joint records: src/027 reads and writes this shape. -->
# Joint records

Every pair of parts in a model that touch or nearly touch is a **joint**.
Each joint has a record: what was measured from the model, and an empty
spot for the calculation that says whether the joint works. The records for
a model live in `input/joints/MODEL.lua` (MODEL is the model's name, e.g.
`crown-sketch`), made and refreshed by `./joints find MODEL-FILE`, filled in
by a person, worked out by `./joints work MODEL-FILE`, and shown by the
viewer (`j` marks them; the `joints` view photographs them).

## The file

```lua
return {
    model = "crown-sketch",
    millimetres_per_unit = 1,   -- the model's unit in mm; -1 (an empty
                                -- spot) when the model does not say
    contact_distance = 2.4,     -- in model units: parts closer than this
                                -- are a joint
    materials = {               -- each part's material; "unassigned" is
        ["band"] = "nylon-pa12",    -- an empty spot
        ["panel arm"] = "unassigned",
    },
    joints = {
        {
            a = "band", b = "panel arm",       -- the two parts
            found = {                          -- measured; refreshed by find
                gap = 0,                       -- surface to surface (units)
                contact_point = { x, y, z },   -- where they come closest
                normal = { x, y, z },          -- across the contact, a to b
                reach_a = 8, reach_b = 64,     -- each part's extent along it
                contact_size = 6,              -- largest extent of the
                                               -- touching zone
                still_found = true,            -- false if no longer close
            },
            equation = "",                     -- the empty spot: a
                                               -- calculation's name from
                                               -- input/calculations/
            inputs = {                         -- that calculation's inputs:
                -- gap = "structure.gap",      --   a structure measure (mm)
                -- expansion_a = "a.expansion",--   a material fundamental
                -- temperature = 30,           --   a plain number
            },
            note = "",                         -- anything a person adds
        },
    },
}
```

Structure measures (`structure.NAME`), converted to millimetres: `gap`,
`reach_a`, `reach_b`, `contact_size`. Material fundamentals (`a.NAME`,
`b.NAME`): whatever input/materials.lua gives that material — `expansion`,
`density`, `stiffness`, `index`. A bound input takes the bound value as its
nominal; a material value brings its own tolerance; a structure measure
keeps the calculation's tolerance. Inputs not bound keep the calculation's
own values.

An empty spot is written as `""` (equation, note), `"unassigned"` (a
material) or `-1` (millimetres_per_unit), never left out: a missing field
would not appear in the file, and an empty spot has to be seen to be filled.
`input/calculations/joint-gap-under-heat.lua` is a general calculation made
to be bound to any joint (the gap, both reaches, both expansions).

Finding again never removes a record or changes what a person wrote
(`equation`, `inputs`, `note`, `materials`): it adds new joints with empty
spots, refreshes `found`, and marks a joint no longer close with
`still_found = false`.

## What the viewer shows
| Mark | Meaning |
|---|---|
| grey | empty: no equation yet |
| gold | an equation, not yet worked out (or worked out before the record changed) |
| green | worked out, every limit passes in the worst case |
| red | worked out, some limit fails in the worst case |
