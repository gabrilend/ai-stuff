# Issue 309: Phase 3 Integration Test

**Phase:** 3 - Logic Layer
**Type:** Test
**Priority:** High
**Dependencies:** 301-308 (all Phase 3 issues)

---

## Current Behavior

No integration test for the trigger and JASS system. Individual components
may work but full pipeline is unverified.

---

## Intended Behavior

A comprehensive integration test that verifies:
- Trigger file parsing (wtg, wct, j)
- JASS lexing and parsing
- JASS-to-Lua transpilation
- Trigger runtime execution
- Event dispatch and handling

---

## Suggested Implementation Steps

1. **Create integration test suite**
   ```
   src/tests/
   └── phase3_test.lua      (this issue)
   ```

2. **Test trigger file parsing**
   ```lua
   local function test_trigger_parsing()
       local archive = mpq.open(TEST_MAP)

       -- Test wtg parsing
       if archive:has("war3map.wtg") then
           local wtg_data = archive:extract("war3map.wtg")
           local wtg = require("parsers.wtg")
           local triggers, err = wtg.parse(wtg_data)
           assert(triggers, "wtg parse failed: " .. tostring(err))
           print("  Parsed " .. #triggers.triggers .. " triggers")
           print("  Parsed " .. #triggers.variables .. " variables")
       end

       -- Test wct parsing
       if archive:has("war3map.wct") then
           local wct_data = archive:extract("war3map.wct")
           local wct = require("parsers.wct")
           local custom, err = wct.parse(wct_data)
           assert(custom, "wct parse failed: " .. tostring(err))
           local custom_count = 0
           for _, text in pairs(custom.triggers) do
               if text then custom_count = custom_count + 1 end
           end
           print("  Parsed " .. custom_count .. " custom text triggers")
       end

       -- Test j extraction
       if archive:has("war3map.j") then
           local j_data = archive:extract("war3map.j")
           local j = require("parsers.j")
           local script, err = j.extract(j_data)
           assert(script, "j extract failed: " .. tostring(err))
           print("  Extracted " .. #script.raw .. " bytes of JASS")
           print("  Found " .. #script.sections.functions .. " functions")
       end

       archive:close()
   end
   ```

3. **Test JASS lexer**
   ```lua
   local function test_jass_lexer()
       local lexer = require("jass.lexer")

       -- Test basic tokenization
       local tokens = lexer.tokenize([[
           function Test takes nothing returns nothing
               local integer i = 0
               set i = i + 1
               call BJDebugMsg("Hello")
           endfunction
       ]])

       assert(#tokens > 0, "No tokens produced")
       assert(tokens[1].type == lexer.TOKEN.FUNCTION, "Expected FUNCTION token")

       -- Test all token types
       local test_cases = {
           { input = "123", expected = "INTEGER" },
           { input = "1.5", expected = "REAL" },
           { input = '"hello"', expected = "STRING" },
           { input = "'hfoo'", expected = "RAWCODE" },
           { input = "true", expected = "TRUE" },
           { input = "null", expected = "NULL" },
       }

       for _, tc in ipairs(test_cases) do
           local toks = lexer.tokenize(tc.input)
           assert(toks[1].type == lexer.TOKEN[tc.expected],
               "Expected " .. tc.expected .. " for '" .. tc.input .. "'")
       end

       print("  Lexer tests passed")
   end
   ```

4. **Test JASS parser**
   ```lua
   local function test_jass_parser()
       local lexer = require("jass.lexer")
       local parser = require("jass.parser")

       local source = [[
           globals
               integer udg_Count = 0
               unit array udg_Units
           endglobals

           function Trig_Init_Actions takes nothing returns nothing
               local integer i
               set i = 0
               loop
                   exitwhen i >= 10
                   set udg_Count = udg_Count + 1
                   set i = i + 1
               endloop
               if udg_Count > 5 then
                   call BJDebugMsg("Count is high")
               endif
           endfunction
       ]]

       local tokens = lexer.tokenize(source)
       local ast, errors = parser.parse(tokens)

       assert(ast, "Parse failed")
       assert(#errors == 0, "Parse errors: " .. table.concat(errors, ", "))

       -- Verify structure
       assert(ast.type == parser.AST.PROGRAM, "Expected PROGRAM node")

       local has_globals = false
       local has_function = false
       for _, decl in ipairs(ast.declarations) do
           if decl.type == parser.AST.GLOBAL_BLOCK then has_globals = true end
           if decl.type == parser.AST.FUNCTION_DEF then has_function = true end
       end

       assert(has_globals, "Missing globals block")
       assert(has_function, "Missing function definition")

       print("  Parser tests passed")
   end
   ```

5. **Test transpiler**
   ```lua
   local function test_transpiler()
       local lexer = require("jass.lexer")
       local parser = require("jass.parser")
       local transpiler = require("jass.transpiler")

       local source = [[
           function Add takes integer a, integer b returns integer
               return a + b
           endfunction
       ]]

       local tokens = lexer.tokenize(source)
       local ast = parser.parse(tokens)
       local lua_code, errors = transpiler.transpile(ast)

       assert(lua_code, "Transpile failed")
       assert(#errors == 0, "Transpile errors")

       -- Verify output is valid Lua
       local fn, err = load(lua_code)
       assert(fn, "Generated Lua is invalid: " .. tostring(err))

       print("  Transpiler tests passed")
       print("  Generated Lua:")
       for line in lua_code:gmatch("[^\n]+") do
           print("    " .. line)
       end
   end
   ```

6. **Test trigger runtime**
   ```lua
   local function test_trigger_runtime()
       local runtime = require("runtime")

       -- Create a trigger
       local trigger = runtime.CreateTrigger()
       assert(trigger, "Failed to create trigger")

       -- Track execution
       local condition_called = false
       local action_called = false

       -- Add condition
       runtime.TriggerAddCondition(trigger, runtime.Condition(function()
           condition_called = true
           return true
       end))

       -- Add action
       runtime.TriggerAddAction(trigger, function()
           action_called = true
       end)

       -- Manually fire trigger
       runtime.TriggerExecute(trigger)

       assert(action_called, "Action not called")

       -- Test condition blocking
       action_called = false
       runtime.TriggerAddCondition(trigger, runtime.Condition(function()
           return false  -- Block execution
       end))

       runtime.TriggerExecute(trigger)
       -- Action should NOT be called because condition returned false

       runtime.DestroyTrigger(trigger)
       print("  Runtime tests passed")
   end
   ```

7. **Test event dispatch**
   ```lua
   local function test_event_dispatch()
       local runtime = require("runtime")
       local events = require("runtime.events")

       local fired_count = 0

       -- Create trigger with timer event
       local trigger = runtime.CreateTrigger()
       runtime.TriggerRegisterTimerEvent(trigger, 0.1, false)
       runtime.TriggerAddAction(trigger, function()
           fired_count = fired_count + 1
       end)

       -- Simulate time passing
       for i = 1, 10 do
           events.update_timers(0.05)  -- 50ms per tick
       end

       assert(fired_count >= 1, "Timer event did not fire")

       runtime.DestroyTrigger(trigger)
       print("  Event dispatch tests passed")
   end
   ```

8. **Create phase demo**
   ```
   issues/completed/demos/
   └── phase3_demo.lua      (visual demonstration)
   ```

---

## Technical Notes

### Test Coverage Goals

| Component | Coverage Target |
|-----------|-----------------|
| wtg parser | All trigger types, nested ECAs |
| wct parser | Custom text, header comment |
| j extractor | Section identification |
| Lexer | All token types, edge cases |
| Parser | All grammar constructs |
| Transpiler | All statement/expression types |
| Runtime | Trigger lifecycle |
| Events | Timer, region, unit events |

### Test Maps

Use maps with varied trigger complexity:
- Simple melee maps (few triggers)
- Custom maps (many GUI triggers)
- JASS-heavy maps (custom text triggers)

### Error Handling Tests

Verify graceful handling of:
- Malformed trigger files
- Invalid JASS syntax
- Runtime errors in triggers

---

## Related Documents

- issues/completed/demos/phase3_demo.lua (to be created)
- issues/108-phase-1-integration-test.md (similar structure)
- issues/208-phase-2-integration-test.md (similar structure)

---

## Acceptance Criteria

- [ ] All Phase 3 parsers work on test maps
- [ ] JASS lexer handles all token types
- [ ] JASS parser produces valid AST
- [ ] Transpiler generates valid Lua
- [ ] Trigger runtime executes correctly
- [ ] Event system dispatches events
- [ ] Timers fire at correct intervals
- [ ] Full pipeline test (parse → lex → parse → transpile → run)
- [ ] Demo script shows working triggers

---

## Notes

This integration test validates the complete trigger pipeline:

```
war3map.wtg ──┐
war3map.wct ──┼──► Trigger Data ──► Display/Analysis
war3map.j  ──┘         │
                       ▼
              Lexer ──► Parser ──► Transpiler ──► Lua Code
                                                     │
                                                     ▼
                                    Runtime ◄── Event System
```

The demo should show:
1. Parsing trigger files from a real map
2. Lexing/parsing JASS code
3. Transpiling to Lua
4. Creating and executing triggers
5. Timer events firing

This proves the Logic Layer is functional before proceeding to Phase 4.

Reference: [Phase 1 Integration Test](issues/completed/108-phase-1-integration-test.md)
