# Issue A07: Phase A Integration Test

**Phase:** A - Infrastructure Tools
**Type:** Test
**Priority:** Low
**Dependencies:** A01-A06 (all Phase A issues)

---

## Current Behavior

No integration test exists for Phase A infrastructure tools.

---

## Intended Behavior

A comprehensive integration test that:
- Verifies all Phase A tools are installed and functional
- Tests cross-tool interactions
- Validates library interfaces work correctly
- Produces a demo showing all tools in action

---

## Suggested Implementation Steps

1. **Create integration test**
   ```
   src/tests/phase_a_test.lua
   ```

2. **Test tool availability**
   ```lua
   -- {{{ test_tool_availability
   local function test_tool_availability()
       local tools = {
           { name = "git-history", path = "src/cli/git-history.sh" },
           { name = "progress-dashboard", path = "src/cli/progress-dashboard.lua" },
           { name = "test-runner", path = "src/cli/test-runner.sh" },
           { name = "issue-validator", path = "src/cli/issue-validator.sh" },
           { name = "update-toc", path = "src/cli/update-toc.lua" },
           { name = "parser-coverage", path = "src/cli/parser-coverage.lua" },
       }

       for _, tool in ipairs(tools) do
           local full_path = DIR .. "/" .. tool.path
           assert(file_exists(full_path), "Tool not found: " .. tool.name)

           -- Check symlink target exists
           local target = resolve_symlink(full_path)
           if target then
               assert(file_exists(target), "Symlink target missing: " .. tool.name)
           end
       end

       print("All tools available: PASS")
   end
   -- }}}
   ```

3. **Test library imports**
   ```lua
   -- {{{ test_library_imports
   local function test_library_imports()
       -- Lua tools should be requireable
       local ok, dashboard = pcall(require, "progress-dashboard")
       assert(ok, "Cannot require progress-dashboard")
       assert(type(dashboard.scan) == "function", "Missing scan function")

       local ok, toc = pcall(require, "update-toc")
       assert(ok, "Cannot require update-toc")
       assert(type(toc.generate) == "function", "Missing generate function")

       print("Library imports: PASS")
   end
   -- }}}
   ```

4. **Test progress dashboard**
   ```lua
   -- {{{ test_progress_dashboard
   local function test_progress_dashboard()
       local dashboard = require("progress-dashboard")
       dashboard.init(DIR)

       local phases = dashboard.scan()
       assert(phases, "Scan returned nil")

       -- Should find at least Phase 0, 1, 2, A
       local phase_count = 0
       for _ in pairs(phases) do
           phase_count = phase_count + 1
       end
       assert(phase_count >= 4, "Expected at least 4 phases, got " .. phase_count)

       -- Test rendering
       local output = dashboard.render_terminal(phases)
       assert(output and #output > 0, "Empty terminal output")

       print("Progress dashboard: PASS")
   end
   -- }}}
   ```

5. **Test issue validator**
   ```lua
   -- {{{ test_issue_validator
   local function test_issue_validator()
       -- Create a valid test issue
       local valid_issue = [[
   # Issue TEST: Test Issue

   **Phase:** A
   **Type:** Test
   **Priority:** Low
   **Dependencies:** None

   ---

   ## Current Behavior

   Test current behavior.

   ---

   ## Intended Behavior

   Test intended behavior.

   ---

   ## Suggested Implementation Steps

   1. Step one

   ---

   ## Acceptance Criteria

   - [ ] Criterion one
   - [ ] Criterion two
   ]]

       -- Write to temp file
       local temp_file = os.tmpname()
       local f = io.open(temp_file, "w")
       f:write(valid_issue)
       f:close()

       -- Validate
       local result = os.execute("./src/cli/issue-validator.sh -f " .. temp_file)
       os.remove(temp_file)

       assert(result == 0, "Valid issue failed validation")
       print("Issue validator: PASS")
   end
   -- }}}
   ```

6. **Test parser coverage**
   ```lua
   -- {{{ test_parser_coverage
   local function test_parser_coverage()
       local coverage = require("parser-coverage")
       coverage.init(DIR)

       -- Run against one test map
       local test_map = DIR .. "/assets/DAoW-2.1.w3x"
       local results = coverage.scan_map(test_map)

       assert(results, "Coverage scan returned nil")
       assert(results["war3map.w3i"], "Missing w3i result")

       print("Parser coverage: PASS")
   end
   -- }}}
   ```

7. **Test git history (if git available)**
   ```lua
   -- {{{ test_git_history
   local function test_git_history()
       -- Check if we're in a git repo
       local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
       local is_git = handle:read("*a"):match("true")
       handle:close()

       if not is_git then
           print("Git history: SKIP (not a git repo)")
           return
       end

       -- Run git-history in check mode
       local result = os.execute("./src/cli/git-history.sh --check")
       -- Should succeed even if no history files exist yet
       assert(result == 0 or result == 1, "Git history tool failed")

       print("Git history: PASS")
   end
   -- }}}
   ```

8. **Create visual demo**
   ```
   issues/completed/demos/phase_a_demo.sh
   ```

   ```bash
   #!/usr/bin/env bash
   # Phase A Infrastructure Tools Demo
   # Demonstrates all Phase A tools in action.

   set -e
   DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   cd "$DIR"

   echo "═══════════════════════════════════════════════════════════"
   echo "           PHASE A: INFRASTRUCTURE TOOLS DEMO              "
   echo "═══════════════════════════════════════════════════════════"
   echo ""

   echo "1. Progress Dashboard"
   echo "───────────────────────────────────────────────────────────"
   lua src/cli/progress-dashboard.lua -t
   echo ""

   echo "2. Issue Validator"
   echo "───────────────────────────────────────────────────────────"
   ./src/cli/issue-validator.sh -a -q
   echo ""

   echo "3. Test Runner (Phase 1 tests)"
   echo "───────────────────────────────────────────────────────────"
   ./src/cli/test-runner.sh -p 1 -q
   echo ""

   echo "4. Parser Coverage"
   echo "───────────────────────────────────────────────────────────"
   lua src/cli/parser-coverage.lua --matrix
   echo ""

   echo "5. Documentation Index"
   echo "───────────────────────────────────────────────────────────"
   lua src/cli/update-toc.lua --check
   echo ""

   echo "═══════════════════════════════════════════════════════════"
   echo "                    DEMO COMPLETE                          "
   echo "═══════════════════════════════════════════════════════════"
   ```

---

## Acceptance Criteria

- [ ] All Phase A tools exist and are accessible
- [ ] Symlinks point to valid targets
- [ ] Lua tools are requireable as libraries
- [ ] Progress dashboard scans and renders
- [ ] Issue validator validates correctly
- [ ] Parser coverage produces results
- [ ] Git history runs without error
- [ ] Documentation index generates
- [ ] Visual demo runs successfully
- [ ] All tests complete in under 10 seconds

---

## Test Coverage Matrix

| Tool | Available | Library | Functional |
|------|-----------|---------|------------|
| git-history (A01) | ✓ | N/A (bash) | ✓ |
| progress-dashboard (A02) | ✓ | ✓ | ✓ |
| test-runner (A03) | ✓ | N/A (bash) | ✓ |
| issue-validator (A04) | ✓ | N/A (bash) | ✓ |
| update-toc (A05) | ✓ | ✓ | ✓ |
| parser-coverage (A06) | ✓ | ✓ | ✓ |

---

## Related Documents

- Issues A01-A06 (individual tool specifications)
- issues/completed/demos/ (demo location)
- run-demo.sh (phase demo runner)

---

## Notes

The Phase A integration test validates that all infrastructure tools
work together. The demo script provides a visual showcase of
capabilities.

Consider adding this demo to the phase selector in run-demo.sh as
Phase A/Auxiliary.
