# Issue A02: Phase Progress Dashboard

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** High
**Dependencies:** None

---

## Current Behavior

Project progress is tracked manually in `issues/progress.md`. No automated
tool exists to scan issues and generate statistics or visualizations.

---

## Intended Behavior

A project-abstract dashboard tool that:
- Scans issue directories for status information
- Generates progress statistics per phase
- Creates ASCII visualizations (progress bars, tables)
- Outputs both terminal display and markdown reports
- Works across any project following the issue naming convention

---

## Suggested Implementation Steps

1. **Create shared script**
   ```
   /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua
   ```
   Symlinked into projects as `src/cli/progress-dashboard.lua`

2. **Define configuration interface**
   ```lua
   local config = {
       project_dir = "",           -- Project root
       issues_dir = "issues",      -- Relative path to issues
       completed_dir = "issues/completed",
       phase_pattern = "^(%w)(%d+)",  -- Match phase letter/number + issue ID

       -- Status detection patterns
       status_patterns = {
           completed = "%*%*Completed%*%*",
           in_progress = "In Progress",
           pending = "Pending",
       },
   }
   ```

3. **Implement issue scanner**
   ```lua
   -- {{{ scan_issues
   local function scan_issues(issues_dir)
       local issues = {}

       for file in lfs.dir(issues_dir) do
           if file:match("%.md$") then
               local issue = parse_issue_file(issues_dir .. "/" .. file)
               if issue then
                   issues[#issues + 1] = issue
               end
           end
       end

       return issues
   end
   -- }}}
   ```

4. **Implement status detection**
   ```lua
   -- {{{ detect_status
   local function detect_status(content)
       -- Check acceptance criteria completion
       local total_criteria = 0
       local completed_criteria = 0

       for line in content:gmatch("[^\n]+") do
           if line:match("^%- %[.%]") then
               total_criteria = total_criteria + 1
               if line:match("^%- %[x%]") or line:match("^%- %[X%]") then
                   completed_criteria = completed_criteria + 1
               end
           end
       end

       -- Check explicit status in header
       if content:match("%*%*Status:%*%* Completed") then
           return "completed", completed_criteria, total_criteria
       end

       -- Infer from acceptance criteria
       if total_criteria > 0 and completed_criteria == total_criteria then
           return "completed", completed_criteria, total_criteria
       elseif completed_criteria > 0 then
           return "in_progress", completed_criteria, total_criteria
       else
           return "pending", completed_criteria, total_criteria
       end
   end
   -- }}}
   ```

5. **Implement phase grouping**
   ```lua
   -- {{{ group_by_phase
   local function group_by_phase(issues)
       local phases = {}

       for _, issue in ipairs(issues) do
           local phase = issue.phase or "unknown"
           phases[phase] = phases[phase] or {
               issues = {},
               completed = 0,
               in_progress = 0,
               pending = 0,
               total_criteria = 0,
               completed_criteria = 0,
           }

           table.insert(phases[phase].issues, issue)
           phases[phase][issue.status] = phases[phase][issue.status] + 1
           phases[phase].total_criteria = phases[phase].total_criteria + issue.total_criteria
           phases[phase].completed_criteria = phases[phase].completed_criteria + issue.completed_criteria
       end

       return phases
   end
   -- }}}
   ```

6. **Implement ASCII progress bar**
   ```lua
   -- {{{ progress_bar
   local function progress_bar(completed, total, width)
       width = width or 30
       local ratio = total > 0 and (completed / total) or 0
       local filled = math.floor(ratio * width)
       local empty = width - filled

       return string.format("[%s%s] %d/%d (%.0f%%)",
           string.rep("█", filled),
           string.rep("░", empty),
           completed, total,
           ratio * 100)
   end
   -- }}}
   ```

7. **Implement terminal output**
   ```lua
   -- {{{ render_terminal
   local function render_terminal(phases)
       print("╔════════════════════════════════════════════════════════════╗")
       print("║              PROJECT PROGRESS DASHBOARD                    ║")
       print("╠════════════════════════════════════════════════════════════╣")

       for phase_id, phase in pairs(phases) do
           local total = #phase.issues
           local done = phase.completed

           print(string.format("║ Phase %s: %s", phase_id,
               progress_bar(done, total, 40)))
           print(string.format("║   Issues: %d done, %d in progress, %d pending",
               phase.completed, phase.in_progress, phase.pending))

           if phase.total_criteria > 0 then
               print(string.format("║   Criteria: %s",
                   progress_bar(phase.completed_criteria, phase.total_criteria, 30)))
           end
       end

       print("╚════════════════════════════════════════════════════════════╝")
   end
   -- }}}
   ```

8. **Implement markdown output**
   ```lua
   -- {{{ render_markdown
   local function render_markdown(phases)
       local lines = {}
       lines[#lines + 1] = "# Project Progress Dashboard"
       lines[#lines + 1] = ""
       lines[#lines + 1] = "Generated: " .. os.date("%Y-%m-%d %H:%M")
       lines[#lines + 1] = ""

       -- Summary table
       lines[#lines + 1] = "| Phase | Status | Issues | Criteria |"
       lines[#lines + 1] = "|-------|--------|--------|----------|"

       for phase_id, phase in pairs(phases) do
           local issue_pct = #phase.issues > 0 and
               math.floor(phase.completed / #phase.issues * 100) or 0
           local criteria_pct = phase.total_criteria > 0 and
               math.floor(phase.completed_criteria / phase.total_criteria * 100) or 0

           lines[#lines + 1] = string.format("| %s | %d/%d (%d%%) | %d/%d (%d%%) |",
               phase_id, phase.completed, #phase.issues, issue_pct,
               phase.completed_criteria, phase.total_criteria, criteria_pct)
       end

       return table.concat(lines, "\n")
   end
   -- }}}
   ```

9. **Add CLI interface**
   ```lua
   -- Modes:
   -- -t, --terminal      Terminal output (default)
   -- -m, --markdown      Markdown output
   -- -j, --json          JSON output
   -- -p, --phase X       Show only specific phase
   -- -v, --verbose       Show individual issues
   -- -I, --interactive   TUI mode
   ```

---

## Library Design

```lua
-- As CLI
-- lua progress-dashboard.lua -t

-- As library
local dashboard = require("progress-dashboard")
dashboard.init("/path/to/project")

local phases = dashboard.scan()
local stats = dashboard.get_stats(phases)
local output = dashboard.render_terminal(phases)

-- Or for specific phase
local phase2 = dashboard.get_phase(phases, "2")
```

### Exported Functions

| Function | Description |
|----------|-------------|
| `dashboard.init(dir)` | Initialize with project directory |
| `dashboard.scan()` | Scan and return all issues grouped by phase |
| `dashboard.get_phase(phases, id)` | Get specific phase data |
| `dashboard.get_stats(phases)` | Get aggregate statistics |
| `dashboard.render_terminal(phases)` | Render ASCII dashboard |
| `dashboard.render_markdown(phases)` | Render markdown report |
| `dashboard.render_json(phases)` | Render JSON data |

---

## Output Example (Terminal)

```
╔════════════════════════════════════════════════════════════╗
║              PROJECT PROGRESS DASHBOARD                    ║
╠════════════════════════════════════════════════════════════╣
║ Phase 0: [████████████████████████████████████████] 18/18 (100%)
║   Issues: 18 done, 0 in progress, 0 pending
║   Criteria: [████████████████████████████████] 45/45 (100%)
╠────────────────────────────────────────────────────────────╣
║ Phase 1: [████████████████████████████████████████] 12/12 (100%)
║   Issues: 12 done, 0 in progress, 0 pending
║   Criteria: [████████████████████████████████] 38/38 (100%)
╠────────────────────────────────────────────────────────────╣
║ Phase 2: [███████████████░░░░░░░░░░░░░░░░░░░░░░░░░] 3/8 (38%)
║   Issues: 3 done, 0 in progress, 5 pending
║   Criteria: [██████████░░░░░░░░░░░░░░░░░░░░░░] 27/85 (32%)
╚════════════════════════════════════════════════════════════╝
```

---

## Related Documents

- issues/progress.md (manual progress tracking)
- /home/ritz/programming/ai-stuff/scripts/ (shared scripts)
- Issue A04 (issue validator - complementary tool)

---

## Acceptance Criteria

- [ ] Script lives in shared scripts directory
- [ ] Symlink created in project src/cli/
- [ ] Scans issue files for status
- [ ] Detects completion from acceptance criteria
- [ ] Groups issues by phase
- [ ] Generates ASCII progress visualization
- [ ] Supports terminal, markdown, and JSON output
- [ ] Works as both CLI and library
- [ ] Project-abstract configuration
- [ ] Interactive mode with TUI

---

## Notes

This tool provides quick visibility into project state. It complements
the manual progress.md file - could potentially auto-update it.

Consider caching scan results for large projects, with file modification
time checks for invalidation.
