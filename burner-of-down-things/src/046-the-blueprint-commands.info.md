# 046-the-blueprint-commands.lua

Command rows `describe <case>` (outline if not yet outlined, then describe
every issue, then print the graph) and `graph <case>`. Lends two helpers to
later phases: `outline_rows(project, case, options)` (the outline, planning
it first if needed) and `marks(case)` (id → described, describe-failed,
built or build-failed, from the ledger).
