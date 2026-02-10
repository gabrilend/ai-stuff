# Issue 048: Issue Phase Detection Utility

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: Medium
**Created**: 2026-02-10
**Related**: Issue 047 (README Table of Contents Generator)

---

## Current Behavior

The phase detection logic for issue files is embedded directly within `generate-readme-toc.lua`. This logic:
- Parses issue filenames to determine their phase number
- Supports two conventions: dash-separated (`10-001`) and numeric prefix (`047`)
- Is not reusable by other scripts that might need phase information

Other potential consumers of phase detection:
- Issue management scripts (`manage-issues.sh`)
- Progress tracking utilities
- Batch issue operations
- Statistics and reporting tools

---

## Intended Behavior

A standalone utility script that:

1. **Accepts input**: Single issue file, directory of issues, or stdin list
2. **Detects phase**: Using the established conventions
3. **Outputs mapping**: Issue ID → Phase number in configurable formats

### CLI Interface

```bash
# Single file
./scripts/detect-issue-phase.lua issues/047-readme-toc.md
# Output: 047:0

# Directory
./scripts/detect-issue-phase.lua issues/
# Output: list of issue:phase pairs

# With format options
./scripts/detect-issue-phase.lua --format=csv issues/
./scripts/detect-issue-phase.lua --format=table issues/
./scripts/detect-issue-phase.lua --format=json issues/

# Filter by phase
./scripts/detect-issue-phase.lua --phase=1 issues/
# Output: only phase 1 issues

# Stdin support
echo "101-feature.md" | ./scripts/detect-issue-phase.lua --stdin
```

### Output Formats

**Simple (default)** - stdout-friendly `ID:PHASE` format:
```
001:0
047:0
101:1
501:5
10-001:10
```

**CSV** - for spreadsheet import:
```csv
issue_id,phase,filename,status
001,0,001-prepare-repository.md,active
047,0,047-readme-toc.md,completed
```

**Table** - human-readable aligned output:
```
Issue ID  Phase  Filename                              Status
--------  -----  ------------------------------------  ---------
001       0      001-prepare-repository.md             active
047       0      047-readme-toc.md                     completed
101       1      101-module-loading.md                 active
```

**JSON** - for programmatic consumption:
```json
[
  {"id": "001", "phase": 0, "filename": "001-prepare-repository.md", "status": "active"},
  {"id": "047", "phase": 0, "filename": "047-readme-toc.md", "status": "completed"}
]
```

---

## Suggested Implementation Steps

### 1. Create Script Skeleton

```lua
#!/usr/bin/env luajit
-- detect-issue-phase.lua - Detect phase numbers from issue filenames
--
-- Parses issue filenames to determine their phase number using established
-- conventions: dash-separated (P-NNN) and numeric prefix (PNN).

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
if arg[1] and arg[1]:match("^%-%-dir=") then
    DIR = arg[1]:match("^%-%-dir=(.+)$")
    table.remove(arg, 1)
end
-- }}}

-- {{{ Configuration
local config = {
    format = "simple",  -- simple, csv, table, json
    include_completed = true,
    filter_phase = nil,  -- nil means all phases
    stdin_mode = false,
}
-- }}}
```

### 2. Extract Phase Detection Logic

Move `get_issue_phase()` from `generate-readme-toc.lua` into a shared module or duplicate with identical logic:

```lua
-- {{{ get_issue_phase
-- Determines the phase number from an issue ID
--
-- Supports two naming conventions:
--   1. Dash-separated: P-NNN-desc.md (e.g., "10-001" = phase 10, issue 1)
--   2. Numeric prefix: PNN-desc.md (e.g., "047" = phase 0, issue 47)
--
-- For numeric prefix format: first digit = phase, last two digits = issue
local function get_issue_phase(issue_id)
    -- First check for dash-separated format: "10-001" or "1-005"
    local explicit_phase = issue_id:match("^(%d+)%-")
    if explicit_phase then
        local after_dash = issue_id:match("^%d+%-(%d)")
        if after_dash then
            return tonumber(explicit_phase)
        end
    end

    -- Extract just the numeric part (strip trailing letters for sub-issues)
    local num_part = issue_id:match("^(%d+)")
    if not num_part then return nil end

    local num = tonumber(num_part)
    if not num then return nil end

    -- Numeric prefix format: first digit = phase, last two digits = issue
    return math.floor(num / 100)
end
-- }}}
```

### 3. Implement Input Handling

```lua
-- {{{ parse_issue_filename
local function parse_issue_filename(filepath)
    local filename = filepath:match("([^/]+)$") or filepath
    local issue_id, description = filename:match("^(%d+[a-z]?)%-(.+)%.md$")

    -- Try dash-separated format
    if not issue_id then
        issue_id, description = filename:match("^(%d+%-%d+[a-z]?)%-(.+)%.md$")
    end

    if not issue_id then return nil end

    local is_completed = filepath:match("/completed/") ~= nil

    return {
        id = issue_id,
        phase = get_issue_phase(issue_id),
        filename = filename,
        path = filepath,
        description = description,
        status = is_completed and "completed" or "active",
    }
end
-- }}}

-- {{{ discover_issues
local function discover_issues(path)
    local issues = {}

    -- Check if path is a file or directory
    local handle = io.popen(string.format("test -f %q && echo file || echo dir", path))
    local path_type = handle:read("*a"):gsub("%s+", "")
    handle:close()

    if path_type == "file" then
        local issue = parse_issue_filename(path)
        if issue then table.insert(issues, issue) end
    else
        -- Directory: find all .md files with numeric prefixes
        local cmd = string.format(
            "find %q -name '[0-9]*.md' -type f 2>/dev/null",
            path
        )
        handle = io.popen(cmd)
        for line in handle:lines() do
            local issue = parse_issue_filename(line)
            if issue then
                -- Apply phase filter if set
                if not config.filter_phase or issue.phase == config.filter_phase then
                    table.insert(issues, issue)
                end
            end
        end
        handle:close()
    end

    -- Sort by phase, then by ID
    table.sort(issues, function(a, b)
        if a.phase ~= b.phase then
            return a.phase < b.phase
        end
        return a.id < b.id
    end)

    return issues
end
-- }}}
```

### 4. Implement Output Formatters

```lua
-- {{{ format_simple
local function format_simple(issues)
    local lines = {}
    for _, issue in ipairs(issues) do
        table.insert(lines, string.format("%s:%d", issue.id, issue.phase))
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ format_csv
local function format_csv(issues)
    local lines = {"issue_id,phase,filename,status"}
    for _, issue in ipairs(issues) do
        table.insert(lines, string.format("%s,%d,%s,%s",
            issue.id, issue.phase, issue.filename, issue.status))
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ format_table
local function format_table(issues)
    -- Calculate column widths
    local id_width = 8
    local phase_width = 5
    local file_width = 36
    local status_width = 9

    for _, issue in ipairs(issues) do
        id_width = math.max(id_width, #issue.id)
        file_width = math.max(file_width, #issue.filename)
    end

    local lines = {}
    local header = string.format("%-" .. id_width .. "s  %-" .. phase_width .. "s  %-" .. file_width .. "s  %s",
        "Issue ID", "Phase", "Filename", "Status")
    local separator = string.rep("-", id_width) .. "  " ..
                      string.rep("-", phase_width) .. "  " ..
                      string.rep("-", file_width) .. "  " ..
                      string.rep("-", status_width)

    table.insert(lines, header)
    table.insert(lines, separator)

    for _, issue in ipairs(issues) do
        table.insert(lines, string.format("%-" .. id_width .. "s  %-" .. phase_width .. "d  %-" .. file_width .. "s  %s",
            issue.id, issue.phase, issue.filename, issue.status))
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ format_json
local function format_json(issues)
    local items = {}
    for _, issue in ipairs(issues) do
        table.insert(items, string.format(
            '  {"id": "%s", "phase": %d, "filename": "%s", "status": "%s"}',
            issue.id, issue.phase, issue.filename, issue.status))
    end
    return "[\n" .. table.concat(items, ",\n") .. "\n]"
end
-- }}}
```

### 5. Update generate-readme-toc.lua

After creating the utility, modify `generate-readme-toc.lua` to use the shared logic:

**Option A**: Import as module
```lua
local phase_detector = dofile(DIR .. "/scripts/libs/phase-detector.lua")
-- Replace inline get_issue_phase with:
local phase = phase_detector.get_issue_phase(issue_id)
```

**Option B**: Call as subprocess (for complete isolation)
```lua
local function get_issue_phase_external(issue_id)
    local cmd = string.format("%s/scripts/detect-issue-phase.lua --format=simple %q 2>/dev/null",
        DIR, issue_id)
    local handle = io.popen(cmd)
    local result = handle:read("*a"):gsub("%s+", "")
    handle:close()
    local phase = result:match(":(%d+)$")
    return phase and tonumber(phase) or nil
end
```

**Option C**: Extract to shared library (recommended)
Create `scripts/libs/phase-detector.lua` with the core logic, then both scripts import it.

---

## CLI Options

```
Usage: detect-issue-phase.lua [OPTIONS] [PATH...]

Detect phase numbers from issue filenames.

OPTIONS:
    --format=FORMAT     Output format: simple, csv, table, json (default: simple)
    --phase=N           Filter to only show issues from phase N
    --stdin             Read issue filenames from stdin (one per line)
    --completed-only    Only show completed issues
    --active-only       Only show active issues
    --dir=PATH          Override delta-version directory path
    -h, --help          Show this help

EXAMPLES:
    detect-issue-phase.lua issues/047-readme-toc.md
        Output: 047:0

    detect-issue-phase.lua --format=table issues/
        Show all issues in table format

    detect-issue-phase.lua --phase=1 --format=csv issues/
        Export phase 1 issues as CSV

    ls issues/*.md | detect-issue-phase.lua --stdin
        Process filenames from stdin
```

---

## File Locations

- **New Script**: `delta-version/scripts/detect-issue-phase.lua`
- **Shared Library** (optional): `delta-version/scripts/libs/phase-detector.lua`
- **Modified**: `delta-version/scripts/generate-readme-toc.lua` (to use shared logic)

---

## Acceptance Criteria

- [ ] Script accepts single file, directory, or stdin input
- [ ] Correctly detects phases for both naming conventions
- [ ] Outputs in simple, CSV, table, and JSON formats
- [ ] Supports phase filtering (`--phase=N`)
- [ ] Handles sub-issues (e.g., `101a`, `10-001b`)
- [ ] Distinguishes active vs completed issues
- [ ] `generate-readme-toc.lua` updated to use shared logic
- [ ] Works on any project in the monorepo
- [ ] Uses vim folds per CLAUDE.md conventions

---

## Metadata

- **Priority**: Medium
- **Complexity**: Low-Medium
- **Dependencies**: Issue 047 (provides the logic to extract)
- **Related**: Issue 023 (project discovery), Issue 030 (issue management)

---

## Notes

This follows the DRY principle - the phase detection logic is currently duplicated conceptually in how we think about issue organization across projects. Extracting it into a utility:

1. Makes the logic testable in isolation
2. Enables other tools to query phase information
3. Documents the phase conventions in executable form
4. Provides a foundation for phase-based batch operations

The simple `ID:PHASE` output format is designed to be easily grep-able and pipe-able:
```bash
# Find all phase 5 issues
./detect-issue-phase.lua issues/ | grep ':5$'

# Count issues per phase
./detect-issue-phase.lua issues/ | cut -d: -f2 | sort | uniq -c
```
