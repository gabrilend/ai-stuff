<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 010 (tolerance records on the model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 027-joint-records

A model's joint records (input/joints/MODEL.lua, format docs/joints.md): made, merged without losing what a person wrote, read.

| Offers | Takes | Gives |
|---|---|---|
| `merge(existing, model, shape, found, contact_distance)` | existing records or nil; found joints (026) | merged records; counts { added, refreshed, lost } |
| `write(project_dir, record, measures, material_names)` | | writes the file with a header saying what may be written where |
| `read(project_dir, model)` | | the records, or nil |
| `signature(record, joint)` | | a text standing for everything the joint's answer depends on (stale answers are recognised by it) |
| `path(project_dir, model)`, `model_name(file)` | | the records' path; "crown-sketch" from ".../crown-sketch.gltf" |
