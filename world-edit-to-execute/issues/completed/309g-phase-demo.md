# Issue 309g: Phase Demo

**Phase:** 3 - Logic Layer
**Type:** Demo
**Priority:** Medium
**Parent:** 309-phase-3-integration-test
**Dependencies:** 309a-309f (all Phase 3 tests must pass)

---

## Current Behavior

No visual demonstration exists for Phase 3 functionality. The trigger and JASS
pipeline is untested as an integrated system, and there is no entry point for
the phase demo runner (`./run-demo.sh 3`).

---

## Intended Behavior

A comprehensive Phase 3 demo script that:
- Demonstrates the complete trigger pipeline visually
- Shows JASS lexing, parsing, and transpilation
- Executes transpiled Lua code
- Fires timer events and shows trigger execution
- Integrates with the phase demo runner
- Produces clear, informative terminal output

---

## Suggested Implementation Steps

1. **Create demo script**
   ```
   issues/completed/demos/
   └── phase3_demo.lua
   ```

2. **Create bash runner**
   ```
   issues/completed/demos/
   └── run_phase3.sh
   ```

3. **Implement demo header and setup**
   ```lua
   #!/usr/bin/env luajit
   -- Phase 3 Demo: Logic Layer - Triggers and JASS
   -- Demonstrates the complete trigger pipeline from parsing to execution.

   local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

   -- {{{ print_header
   local function print_header(title)
       local width = 60
       local padding = string.rep("=", width)
       print()
       print(padding)
       print(string.format("  %s", title))
       print(padding)
       print()
   end
   -- }}}

   -- {{{ print_section
   local function print_section(title)
       print()
       print(string.format("--- %s ---", title))
       print()
   end
   -- }}}
   ```

4. **Demonstrate JASS lexing**
   ```lua
   -- {{{ demo_lexer
   local function demo_lexer()
       print_section("JASS Lexer")

       local lexer = require("jass.lexer")

       local source = [[
   function AddNumbers takes integer a, integer b returns integer
       return a + b
   endfunction
   ]]

       print("Source code:")
       print("  " .. source:gsub("\n", "\n  "))

       local tokens = lexer.tokenize(source)

       print(string.format("Produced %d tokens:", #tokens))
       print()

       -- Show first 15 tokens
       local count = math.min(15, #tokens)
       for i = 1, count do
           local t = tokens[i]
           local value = t.value or ""
           if #value > 20 then value = value:sub(1, 17) .. "..." end
           print(string.format("  [%2d] %-15s %s", i, t.type, value))
       end

       if #tokens > count then
           print(string.format("  ... and %d more tokens", #tokens - count))
       end

       return tokens
   end
   -- }}}
   ```

5. **Demonstrate JASS parsing**
   ```lua
   -- {{{ demo_parser
   local function demo_parser()
       print_section("JASS Parser")

       local lexer = require("jass.lexer")
       local parser = require("jass.parser")

       local source = [[
   globals
       integer udg_Score = 0
   endglobals

   function IncrementScore takes integer amount returns nothing
       set udg_Score = udg_Score + amount
       if udg_Score > 100 then
           call BJDebugMsg("High score!")
       endif
   endfunction
   ]]

       print("Source code:")
       for line in source:gmatch("[^\n]+") do
           print("  " .. line)
       end
       print()

       local tokens = lexer.tokenize(source)
       local ast, errors = parser.parse(tokens)

       if #errors > 0 then
           print("Parse errors:")
           for _, err in ipairs(errors) do
               print("  " .. parser.format_error(err))
           end
           return nil
       end

       print("AST Structure:")
       print(string.format("  Root: %s", ast.type))
       print(string.format("  Declarations: %d", #ast.declarations))

       for i, decl in ipairs(ast.declarations) do
           print(string.format("    [%d] %s", i, decl.type))
           if decl.type == parser.AST.FUNCTION_DEF then
               print(string.format("        name: %s", decl.name))
               print(string.format("        params: %d", #decl.params))
               print(string.format("        statements: %d", #decl.body))
           elseif decl.type == parser.AST.GLOBAL_BLOCK then
               print(string.format("        variables: %d", #decl.variables))
           end
       end

       return ast
   end
   -- }}}
   ```

6. **Demonstrate transpilation**
   ```lua
   -- {{{ demo_transpiler
   local function demo_transpiler()
       print_section("JASS-to-Lua Transpiler")

       local lexer = require("jass.lexer")
       local parser = require("jass.parser")
       local transpiler = require("jass.transpiler")

       local source = [[
   function Factorial takes integer n returns integer
       local integer result = 1
       local integer i = 1
       loop
           exitwhen i > n
           set result = result * i
           set i = i + 1
       endloop
       return result
   endfunction
   ]]

       print("JASS Source:")
       for line in source:gmatch("[^\n]+") do
           print("  " .. line)
       end
       print()

       local tokens = lexer.tokenize(source)
       local ast = parser.parse(tokens)
       local lua_code, errors = transpiler.transpile(ast)

       if #errors > 0 then
           print("Transpile errors:")
           for _, err in ipairs(errors) do
               print("  " .. err)
           end
           return nil
       end

       print("Generated Lua:")
       for line in lua_code:gmatch("[^\n]+") do
           print("  " .. line)
       end
       print()

       -- Execute the generated code
       print("Executing transpiled code...")
       local fn, err = load(lua_code)
       if fn then
           fn()  -- Define the function
           -- Now call it
           local result = Factorial(5)
           print(string.format("  Factorial(5) = %d", result))
       else
           print("  Load error: " .. tostring(err))
       end

       return lua_code
   end
   -- }}}
   ```

7. **Demonstrate trigger execution**
   ```lua
   -- {{{ demo_triggers
   local function demo_triggers()
       print_section("Trigger Runtime")

       local runtime = require("runtime")

       print("Creating trigger with condition and action...")

       local execution_log = {}

       local trigger = runtime.CreateTrigger()

       runtime.TriggerAddCondition(trigger, runtime.Condition(function()
           table.insert(execution_log, "Condition evaluated: true")
           return true
       end))

       runtime.TriggerAddAction(trigger, function()
           table.insert(execution_log, "Action executed!")
       end)

       print("  Trigger created")
       print()

       print("Manually executing trigger...")
       runtime.TriggerExecute(trigger)

       print("Execution log:")
       for _, entry in ipairs(execution_log) do
           print("  " .. entry)
       end

       runtime.DestroyTrigger(trigger)
       print()
       print("  Trigger destroyed")
   end
   -- }}}
   ```

8. **Demonstrate timer events**
   ```lua
   -- {{{ demo_timer_events
   local function demo_timer_events()
       print_section("Timer Events")

       local runtime = require("runtime")
       local events = require("runtime.events")

       local fire_times = {}

       local trigger = runtime.CreateTrigger()
       runtime.TriggerAddAction(trigger, function()
           table.insert(fire_times, #fire_times + 1)
       end)

       -- Register 100ms periodic timer
       print("Registering 100ms periodic timer...")
       runtime.TriggerRegisterTimerEvent(trigger, 0.1, true)

       print("Simulating 500ms of game time...")
       print()

       -- Simulate time in 50ms increments
       local total_time = 0
       for i = 1, 10 do
           events.update_timers(0.05)
           total_time = total_time + 0.05

           local fires = #fire_times
           local bar = string.rep("#", fires * 4)
           print(string.format("  t=%.2fs  fires=%d  %s", total_time, fires, bar))
       end

       print()
       print(string.format("Timer fired %d times in 500ms (expected: 5)", #fire_times))

       runtime.DestroyTrigger(trigger)
   end
   -- }}}
   ```

9. **Demonstrate full pipeline with map file**
   ```lua
   -- {{{ demo_full_pipeline
   local function demo_full_pipeline()
       print_section("Full Pipeline: Map File to Execution")

       local mpq = require("mpq")
       local j = require("parsers.j")
       local lexer = require("jass.lexer")
       local parser = require("jass.parser")

       -- Try to find a map with JASS
       local test_maps = {
           DIR .. "/assets/test_triggers.w3x",
           DIR .. "/assets/DAoW-2.1.w3x",
       }

       local archive, map_path
       for _, path in ipairs(test_maps) do
           local a = mpq.open(path)
           if a and a:has("war3map.j") then
               archive = a
               map_path = path
               break
           elseif a then
               a:close()
           end
       end

       if not archive then
           print("No test maps with war3map.j found.")
           print("Using synthetic JASS for demonstration.")
           print()

           -- Use synthetic JASS
           local synthetic = [[
   globals
       trigger gg_trg_Init = null
       integer udg_Count = 0
   endglobals

   function Trig_Init_Actions takes nothing returns nothing
       set udg_Count = udg_Count + 1
   endfunction

   function main takes nothing returns nothing
       call Trig_Init_Actions()
   endfunction

   function config takes nothing returns nothing
   endfunction
   ]]
           print("Synthetic JASS statistics:")
           local parsed = j.parse(synthetic)
           print(string.format("  Lines: %d", parsed.line_count))
           print(string.format("  Functions: %d", #parsed.functions))
           print(string.format("  Variables: %d", #parsed.variables))
           print(string.format("  Has main(): %s", parsed.has_main and "yes" or "no"))
           print(string.format("  Has config(): %s", parsed.has_config and "yes" or "no"))
           return
       end

       print(string.format("Loaded: %s", map_path:match("[^/]+$")))

       local jass_text = archive:extract("war3map.j")
       archive:close()

       local parsed = j.parse(jass_text)

       print()
       print("JASS Script Statistics:")
       print(string.format("  Size: %d bytes", #jass_text))
       print(string.format("  Lines: %d", parsed.line_count))
       print(string.format("  Functions: %d", #parsed.functions))
       print(string.format("  Variables: %d", #parsed.variables))
       print()

       print("Function types:")
       local type_counts = {}
       for _, func in ipairs(parsed.functions) do
           type_counts[func.type] = (type_counts[func.type] or 0) + 1
       end
       for type_name, count in pairs(type_counts) do
           print(string.format("  %-20s %d", type_name, count))
       end
   end
   -- }}}
   ```

10. **Create main runner**
    ```lua
    -- {{{ main
    local function main()
        print_header("Phase 3 Demo: Logic Layer - Triggers and JASS")

        local demos = {
            { "JASS Lexer", demo_lexer },
            { "JASS Parser", demo_parser },
            { "JASS-to-Lua Transpiler", demo_transpiler },
            { "Trigger Runtime", demo_triggers },
            { "Timer Events", demo_timer_events },
            { "Full Pipeline", demo_full_pipeline },
        }

        local success_count = 0

        for _, demo in ipairs(demos) do
            local name, fn = demo[1], demo[2]
            local ok, err = pcall(fn)
            if ok then
                success_count = success_count + 1
            else
                print(string.format("ERROR in %s: %s", name, tostring(err)))
            end
        end

        print_header("Demo Complete")
        print(string.format("Demonstrated %d/%d components successfully.", success_count, #demos))
        print()
        print("Phase 3 establishes the Logic Layer:")
        print("  - Trigger file parsing (wtg, wct, j)")
        print("  - JASS lexing and parsing")
        print("  - JASS-to-Lua transpilation")
        print("  - Trigger creation and execution")
        print("  - Event dispatch with timers")
        print()
    end
    -- }}}

    main()
    ```

11. **Create bash runner script**
    ```bash
    #!/bin/bash
    # Phase 3 Demo Runner
    # Demonstrates the Logic Layer: Triggers and JASS

    DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

    echo "Running Phase 3 Demo..."
    echo

    luajit "${DIR}/issues/completed/demos/phase3_demo.lua"

    exit $?
    ```

12. **Update run-demo.sh**
    - Add Phase 3 option to the main demo selector
    - Set COMPLETED_PHASES=3

---

## Technical Notes

### Demo vs Test

The demo focuses on *visual demonstration* rather than pass/fail assertions.
It should produce interesting, readable output that shows the system working,
even if some features are incomplete.

### Graceful Degradation

If certain components aren't implemented yet, the demo should:
1. Print a clear message about what's missing
2. Continue with other demonstrations
3. Use synthetic/mock data where real data isn't available

### Output Formatting

Use consistent formatting throughout:
- Section headers with `---` separators
- Indentation for nested information
- Progress indicators for time-based demos
- Statistics and counts where meaningful

---

## Related Documents

- issues/309-phase-3-integration-test.md (parent issue)
- issues/309a-309f (prerequisite tests)
- issues/completed/demos/phase1_demo.lua (example structure)
- issues/completed/demos/phase2_demo.lua (example structure)
- run-demo.sh (phase demo selector)

---

## Acceptance Criteria

- [ ] Demo script created at issues/completed/demos/phase3_demo.lua
- [ ] Bash runner created at issues/completed/demos/run_phase3.sh
- [ ] Demonstrates JASS lexing with token output
- [ ] Demonstrates JASS parsing with AST structure
- [ ] Demonstrates JASS-to-Lua transpilation with executable output
- [ ] Demonstrates trigger creation and manual execution
- [ ] Demonstrates timer events with visual timeline
- [ ] Demonstrates full pipeline from map file (or synthetic data)
- [ ] Integrates with run-demo.sh (option 3)
- [ ] Runs without errors when Phase 3 is complete
- [ ] Produces clear, informative terminal output

---

## Notes

This demo serves as both a validation tool and a showcase of Phase 3 capabilities.
It should be runnable incrementally as components are completed - early runs will
show partial functionality, and the full demo works once all Phase 3 issues are done.

The demo should be visually engaging, showing the transformation of JASS code
through each stage of the pipeline, and demonstrating that triggers actually execute.
