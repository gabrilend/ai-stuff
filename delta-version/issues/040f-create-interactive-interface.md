# Issue 040f: Create Interactive Review Interface

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: Medium
- **Type**: Implementation
- **Dependencies**: 040b (API Layer), 040c (Revision Engine), 040e (Validation System)
- **Blocks**: None (final sub-issue)

## Current Behavior
Users must manually edit CLAUDE.md when they want to add or modify guidelines. There is no interface for:
- Reviewing proposed guidelines
- Approving or rejecting proposals
- Viewing proposal history
- Managing conflicts

## Intended Behavior
Create an interactive TUI (Terminal User Interface) that allows users to:
1. View pending proposals with context
2. Approve, reject, or modify proposals
3. Resolve conflicts between guidelines
4. Browse guideline history
5. Trigger health checks and reports

## Interface Design

### Main Menu

```
╔══════════════════════════════════════════════════════════════════╗
║                    CLAUDE.md Revision Manager                    ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  [P] Pending Proposals (3)                                       ║
║  [G] Browse Guidelines                                           ║
║  [H] View History                                                ║
║  [C] Check Health                                                ║
║  [S] System Status                                               ║
║  [Q] Quit                                                        ║
║                                                                  ║
║  Last activity: 2 proposals approved today                       ║
║  Guidelines: 56 active, 4 deprecated                             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Proposal Review Screen

```
╔══════════════════════════════════════════════════════════════════╗
║  Proposal Review                                          [1/3]  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  PROPOSED GUIDELINE:                                             ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │ "Use dispatch tables instead of switch statements when     │  ║
║  │  there are more than 3 cases"                              │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  SOURCE: User correction (session 2025-12-29 14:30)              ║
║  CONFIDENCE: High (explicit instruction)                         ║
║  CATEGORY: coding_conventions                                    ║
║                                                                  ║
║  ⚠ CONFLICT DETECTED:                                            ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │ Existing [g053]: "whenever multiple IF-ELSE statements     │  ║
║  │ or switch statements are used, try converting to a         │  ║
║  │ dispatch table"                                            │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║  Severity: Similar (85% overlap)                                 ║
║  Suggestion: Keep existing (broader scope)                       ║
║                                                                  ║
║  [A] Approve  [R] Reject  [M] Modify  [S] Skip  [?] More Info    ║
╚══════════════════════════════════════════════════════════════════╝
```

### Guideline Browser

```
╔══════════════════════════════════════════════════════════════════╗
║  Guidelines Browser                              [Filter: All]   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  CODING CONVENTIONS (23)                                         ║
║  ├─ g001: All scripts should run from any directory         ○   ║
║  ├─ g002: All functions should use vimfolds                  ○   ║
║  ├─ g003: Prefer Lua with LuaJIT syntax                      ○   ║
║  ├─ g053: Use dispatch tables for conditionals               ○   ║
║  └─ ...                                                          ║
║                                                                  ║
║  WORKFLOW (12)                                                   ║
║  ├─ g010: For every change, create an issue file first       ○   ║
║  ├─ g011: After completing issue, git commit                 ○   ║
║  └─ ...                                                          ║
║                                                                  ║
║  PHILOSOPHY (8)                                                  ║
║  ├─ g045: Interest is in software design, not product        ○   ║
║  └─ ...                                                          ║
║                                                                  ║
║  [↑↓] Navigate  [Enter] View  [/] Search  [F] Filter  [Q] Back   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Guideline Detail View

```
╔══════════════════════════════════════════════════════════════════╗
║  Guideline Detail                                         g002   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  CONTENT:                                                        ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │ "all functions should use vimfolds to collapse             │  ║
║  │ functionality. They should open with a comment that has    │  ║
║  │ the comment symbol, then the name of the function..."      │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  METADATA:                                                       ║
║    Added: 2024-11-15 (User)                                      ║
║    Category: coding_conventions                                  ║
║    Status: Established                                           ║
║    Last reviewed: 2025-01-10                                     ║
║                                                                  ║
║  HISTORY:                                                        ║
║    • 2024-11-15 - Created (user direct entry)                    ║
║    • 2024-12-01 - Clarified example syntax                       ║
║    • 2025-01-10 - Reviewed, confirmed                            ║
║                                                                  ║
║  RELATED:                                                        ║
║    g001 (script structure), g015 (comment style)                 ║
║                                                                  ║
║  [E] Edit  [D] Deprecate  [H] Full History  [Q] Back             ║
╚══════════════════════════════════════════════════════════════════╝
```

### Conflict Resolution Screen

```
╔══════════════════════════════════════════════════════════════════╗
║  Conflict Resolution                                             ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  CONFLICT TYPE: Direct Contradiction                             ║
║                                                                  ║
║  EXISTING [g015]:                    PROPOSED:                   ║
║  ┌─────────────────────────┐        ┌─────────────────────────┐  ║
║  │ "Use tabs for           │   VS   │ "Use 2 spaces for       │  ║
║  │  indentation"           │        │  indentation in Lua"    │  ║
║  └─────────────────────────┘        └─────────────────────────┘  ║
║                                                                  ║
║  RESOLUTION OPTIONS:                                             ║
║                                                                  ║
║  [1] Replace existing with proposed                              ║
║      → g015 will be deprecated, new guideline takes its place    ║
║                                                                  ║
║  [2] Keep existing, reject proposal                              ║
║      → Proposal will be recorded but not applied                 ║
║                                                                  ║
║  [3] Scope both guidelines                                       ║
║      → "Use tabs" for general, "2 spaces" for specific context   ║
║                                                                  ║
║  [4] Merge into single guideline                                 ║
║      → Combine with clear exception clause                       ║
║                                                                  ║
║  [C] Custom resolution  [?] View context  [Q] Defer              ║
╚══════════════════════════════════════════════════════════════════╝
```

### Health Check Screen

```
╔══════════════════════════════════════════════════════════════════╗
║  Guideline Health Check                        Last run: 14:35   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  SUMMARY:                                                        ║
║    Total guidelines: 56                                          ║
║    Healthy: 48 (86%)                                             ║
║    Warnings: 5 (9%)                                              ║
║    Critical: 3 (5%)                                              ║
║                                                                  ║
║  ISSUES FOUND:                                                   ║
║                                                                  ║
║  ⚠ g007: Stale (not reviewed in 200 days)                        ║
║  ⚠ g023: Low compliance (violated 8 times this month)            ║
║  ⚠ g031: Vague wording ("stuff", "things")                       ║
║  ✗ g015 ↔ g048: Unresolved conflict                              ║
║  ✗ g029: Contradicts itself (exception in same sentence)         ║
║  ✗ g041: Deprecated but still referenced by g045                 ║
║                                                                  ║
║  [1-6] View issue  [F] Fix all auto-fixable  [R] Refresh  [Q]    ║
╚══════════════════════════════════════════════════════════════════╝
```

## Implementation Architecture

```lua
-- {{{ TUI Module Structure
--
-- src/tui/
-- ├── main.lua           -- Entry point, main loop
-- ├── screen.lua         -- Screen buffer and rendering
-- ├── input.lua          -- Keyboard input handling
-- ├── components/
-- │   ├── menu.lua       -- Menu component
-- │   ├── list.lua       -- Scrollable list
-- │   ├── box.lua        -- Bordered box
-- │   ├── dialog.lua     -- Modal dialogs
-- │   └── status.lua     -- Status bar
-- └── screens/
--     ├── main_menu.lua  -- Main menu screen
--     ├── proposals.lua  -- Proposal review
--     ├── browser.lua    -- Guideline browser
--     ├── detail.lua     -- Guideline detail
--     ├── conflict.lua   -- Conflict resolution
--     └── health.lua     -- Health check
-- }}}
```

## Core TUI Components

### Screen Manager

```lua
-- {{{ Screen manager
local Screen = {}

function Screen.new(width, height)
    return {
        width = width or 80,
        height = height or 24,
        buffer = {},
        dirty = true
    }
end

-- {{{ function Screen:clear
function Screen:clear()
    self.buffer = {}
    for y = 1, self.height do
        self.buffer[y] = string.rep(" ", self.width)
    end
    self.dirty = true
end
-- }}}

-- {{{ function Screen:draw_box
function Screen:draw_box(x, y, w, h, title)
    -- Top border
    self:set(x, y, "╔" .. string.rep("═", w-2) .. "╗")

    -- Title if provided
    if title then
        local title_pos = x + math.floor((w - #title) / 2)
        self:set(title_pos, y, title)
    end

    -- Sides
    for row = y+1, y+h-2 do
        self:set(x, row, "║")
        self:set(x+w-1, row, "║")
    end

    -- Bottom border
    self:set(x, y+h-1, "╚" .. string.rep("═", w-2) .. "╝")
end
-- }}}

-- {{{ function Screen:render
function Screen:render()
    if not self.dirty then return end

    -- Clear terminal
    io.write("\27[2J\27[H")

    -- Write buffer
    for y, line in ipairs(self.buffer) do
        io.write(line .. "\n")
    end

    self.dirty = false
end
-- }}}

return Screen
-- }}}
```

### Input Handler

```lua
-- {{{ Input handler
local Input = {}

-- {{{ function Input.get_key
function Input.get_key()
    -- Set terminal to raw mode
    os.execute("stty raw -echo 2>/dev/null")

    local char = io.read(1)

    -- Restore terminal
    os.execute("stty -raw echo 2>/dev/null")

    -- Handle escape sequences
    if char == "\27" then
        local seq = io.read(2)
        if seq == "[A" then return "up" end
        if seq == "[B" then return "down" end
        if seq == "[C" then return "right" end
        if seq == "[D" then return "left" end
    end

    return char
end
-- }}}

-- {{{ function Input.confirm
function Input.confirm(prompt)
    io.write(prompt .. " [y/N] ")
    local response = io.read("*l")
    return response:lower() == "y"
end
-- }}}

return Input
-- }}}
```

### Proposal List Component

```lua
-- {{{ Proposal list component
local ProposalList = {}

function ProposalList.new(proposals)
    return {
        proposals = proposals,
        selected = 1,
        scroll = 0
    }
end

-- {{{ function ProposalList:render
function ProposalList:render(screen, x, y, w, h)
    local visible = h - 2  -- Account for borders

    for i = 1, visible do
        local idx = self.scroll + i
        local proposal = self.proposals[idx]

        if proposal then
            local prefix = (idx == self.selected) and "►" or " "
            local status_icon = proposal.has_conflict and "⚠" or "○"

            local text = string.format("%s %s %s",
                prefix,
                status_icon,
                truncate(proposal.content, w - 6)
            )

            screen:set(x, y + i, text)
        end
    end
end
-- }}}

-- {{{ function ProposalList:handle_input
function ProposalList:handle_input(key)
    if key == "up" and self.selected > 1 then
        self.selected = self.selected - 1
        if self.selected <= self.scroll then
            self.scroll = self.scroll - 1
        end
    elseif key == "down" and self.selected < #self.proposals then
        self.selected = self.selected + 1
        -- Handle scroll
    elseif key == "\r" or key == "\n" then
        return "select", self.proposals[self.selected]
    end
    return nil
end
-- }}}

return ProposalList
-- }}}
```

## Workflow: Approve a Proposal

```lua
-- {{{ Approval workflow
function approve_proposal(proposal_id)
    -- 1. Load proposal
    local proposal = load_proposal(proposal_id)
    if not proposal then
        return {success = false, error = "Proposal not found"}
    end

    -- 2. Run validation
    local validation = validate_proposal(proposal)
    if #validation.conflicts > 0 then
        -- Show conflict resolution screen
        local resolution = show_conflict_screen(validation.conflicts)
        if resolution.action == "cancel" then
            return {success = false, error = "Cancelled by user"}
        end
        apply_resolution(resolution)
    end

    -- 3. Apply revision
    local revision = revision_engine.insert({
        content = proposal.content,
        category = proposal.category,
        proposal_id = proposal.id
    })

    -- 4. Update proposal status
    update_proposal_status(proposal.id, "approved", revision.id)

    -- 5. Log to history
    history.append_revision(revision)

    return {success = true, revision_id = revision.id}
end
-- }}}
```

## Keyboard Shortcuts

| Context | Key | Action |
|---------|-----|--------|
| Global | `q` | Quit / Go back |
| Global | `?` | Help |
| Global | `/` | Search |
| Menu | `1-9` | Quick select |
| List | `↑↓` | Navigate |
| List | `Enter` | Select |
| List | `j/k` | Vim-style navigate |
| Proposal | `a` | Approve |
| Proposal | `r` | Reject |
| Proposal | `m` | Modify |
| Proposal | `s` | Skip |
| Detail | `e` | Edit |
| Detail | `d` | Deprecate |
| Detail | `h` | History |

## Suggested Implementation Steps

1. **Set up TUI framework** (`src/tui/`)
   - Screen buffer management
   - Input handling (raw mode)
   - Box drawing components

2. **Build core components** (`src/tui/components/`)
   - Menu component
   - List component (scrollable)
   - Dialog component (modal)
   - Status bar

3. **Implement screens** (`src/tui/screens/`)
   - Main menu
   - Proposal review
   - Guideline browser
   - Detail view

4. **Add approval workflow**
   - Integrate with revision engine
   - Handle conflicts inline
   - Update history

5. **Build conflict resolution**
   - Side-by-side comparison
   - Resolution options
   - Custom resolution entry

6. **Add health check screen**
   - Integrate with validation system
   - Display issues with actions
   - Auto-fix capability

7. **Create CLI wrapper** (`scripts/claudemd-tui`)
   - Entry point script
   - Configuration options
   - Help text

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [Issue 040b](./040b-build-api-layer.md) - API this interface uses
- [Issue 040c](./040c-implement-revision-engine.md) - Revision operations
- [Issue 040e](./040e-build-validation-system.md) - Validation displayed here

## Notes
- Use TUI library from `~/programming/ai-stuff/my-libs/` if available
- Consider ncurses binding for more advanced features
- Keep interface responsive (async operations where possible)
- Support both arrow keys and vim-style navigation
- Ensure terminal restore on any exit (including errors)
