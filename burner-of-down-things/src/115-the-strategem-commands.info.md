# 115-the-strategem-commands.lua

The `strategems` row of the command table (docs/012): `machine strategems`
runs 111's `draft_due` over the project's `output/story/lessons.md` and its
`strategems/` folder, printing each new draft (which also goes under
"waiting" in the goodbye, for the person), each draft given new examples,
and each kept strategem met again. Works on the project, not a case
(`needs_case = false`). It never promotes: that is
`scripts/116-promote-strategem.lua`, run by the person.
