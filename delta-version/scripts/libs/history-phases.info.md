# history-phases.lua

A project's commits read from git, and where its history breaks into
phases. Shared by `roadmap-from-history.lua` (051b) and
`issues-from-history.lua` (051c). No model is involved.

```lua
local phases_lib = require("history-phases")
local commits, phases = phases_lib.phases("soren-ds", { max_phases = 8, gap_days = 14 })
if not commits then error(phases) end   -- outside git, or no commits
```

- **`commits`**: every commit touching the folder, oldest first, merges left
  out. Each has `hash` (7 characters), `time`, `date`, `subject`, `files`,
  `lines` and `paths` (`{ path, lines }`, relative to the folder).
- **`phases`**: each has `number`, `commits`, `from`, `to`, `first`,
  `last`, `areas`, `accomplishments` (its five largest commits),
  `starts_because`, `subjects` (its commits), and a plain `name` and
  `description`.

A phase starts at a scored break: a quiet spell (3), a version or release in
the commit before (3), a README update in the commit before (1), a large
commit (1), the first commit in a new folder (1). A break needs 2. The
strongest are kept, with no phase under three commits. The weights are in
`M.config`.
