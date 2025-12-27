# 012: Abstract Issue Manager Library

## Current Behavior

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
