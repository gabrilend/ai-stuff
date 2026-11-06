# 012: Abstract Issue Manager Library

## Current Behavior

**Built 2026-11-02** (see *What Happened*): `libs/issue-manager.lua` and
`libs/issue-manager.sh` exist. What follows is how things stood before.

Issue management is implemented in `delta-version/scripts/manage-issues.sh`. This includes:
- `get_next_issue_id()` - Sequential ID generation
- `list_issues()` - Issue listing with status filtering
- `display_issue_line()` - Formatted issue display
- Issue creation, validation, and completion workflows

This functionality complements `issue-splitter.sh` but cannot be shared.

## Intended Behavior

A reusable library `libs/issue-manager.sh` (and Lua equivalent) that provides:
- `issue_init(project_dir)` - Initialize with project
- `issue_get_next_id([phase])` - Get next sequential ID
- `issue_list([status], [phase])` - List issues with filters
- `issue_create(id, name, content)` - Create new issue file
- `issue_complete(id)` - Move to completed directory
- `issue_validate(id)` - Check issue file structure
- `issue_search(query)` - Search issue content

## Suggested Implementation Steps

1. Read `delta-version/scripts/manage-issues.sh` thoroughly
2. Identify core patterns vs project-specific logic
3. Create `libs/issue-manager.sh` with generic interface
4. Ensure compatibility with phase-based naming (301-name, 302a-sub)
5. Add Lua port `libs/issue-manager.lua`
6. Integrate with `issue-splitter.sh` for sub-issue creation
7. Write test script `libs/test-issue-manager.sh`
8. Add TUI integration for interactive issue browsing

## Source Scripts

- `../delta-version/scripts/manage-issues.sh` (primary source)
- `./issue-splitter.sh` (related, potential consumer)
- `./progress-dashboard.lua` (related, reads issues)

## API Design

```bash
# Bash usage
source libs/issue-manager.sh
issue_init "/path/to/project"

# Get next ID for phase 3
next_id=$(issue_get_next_id 3)  # Returns "308" if 307 exists

# Create issue
issue_create "$next_id" "implement-feature" <<EOF
# Current Behavior
...

# Intended Behavior
...
EOF

# List all phase 3 issues
issue_list "all" "3"

# Complete an issue
issue_complete "305"
```

```lua
-- Lua usage
local issues = require("libs/issue-manager")
issues.init("/path/to/project")

local next_id = issues.get_next_id(3)
issues.create(next_id, "implement-feature", {
    current = "...",
    intended = "...",
    steps = {"Step 1", "Step 2"}
})

for _, issue in ipairs(issues.list({phase = 3})) do
    print(issue.id, issue.name, issue.status)
end
```

## Related Documents

- `README.md` - Scripts documentation
- `issue-splitter.sh` - Issue analysis tool
- `progress-dashboard.lua` - Issue statistics

## What Happened

Built on 2026-11-02:

- `libs/issue-manager.lua` -- `init`, `next_id`, `list`, `find`, `create`,
  `complete`, `validate`, `search`, `template`; runnable as a command.
- `libs/issue-manager.sh` -- this issue's bash API (`issue_init`,
  `issue_get_next_id`, `issue_list`, `issue_create`, `issue_complete`,
  `issue_validate`, `issue_search`, plus `issue_path`), running the Lua.
- `libs/issue-manager.info.md`; `tests/test-issue-manager.sh` (28 checks).

**Decisions made while building it:**

- *Built on what exists, not on manage-issues.sh.* Since this issue was
  written, `libs/issue-names.lua` became the shared reader of issue names (it
  handles compact, dashed and lettered ids, phase-N/ folders and completed/
  status) and `validate-issues` the shared checker. Lifting
  manage-issues.sh's own versions would have made a third opinion. So
  `next_free_ids` moved from `validate-issues` into `issue-names.lua` (as
  `next_free_ids`, `dominant_shape` and `next_id`), both tools now number by
  it, and `validate` runs `validate-issues --file`.
- *One implementation*: the bash face runs the Lua, for the reason given in
  010 -- two copies of a rulebook drift.
- *No git.* `issue_complete` renames the file; it does not `git mv`, because
  that writes the staging area every session in the repository shares (the
  problem issue 032 solved). The commit route sees the move on disk.
- *create* refuses a taken id, a badly formed name, or anything that does
  not read back as an issue id, but does not insist on the next free id: a
  sub-issue or a deliberate gap is the author's call. A retired file's id
  may be reused. An empty body gets the template, never an empty file.
- *search* is plain words, all on one line, case ignored -- not a pattern
  language to learn.
- Shape ties in numbering now break alphabetically instead of by Lua table
  order, so `--next` cannot change between runs on a project split evenly
  between two shapes.
- *Found and fixed on the way:* `validate-issues` missed a required heading
  on the very first line of a file (it looked for headings after a
  newline). A check for it is in `tests/test_validate-issues.lua`.
  `validate-issues` also now loads `issue-names.lua` from beside itself, so a
  checkout tests its own copy.
- *Not done:* step 6 (issue-splitter.sh creating sub-issues through this)
  and step 8 (a TUI browser) -- each is a change to its consumer, worth its
  own issue.

