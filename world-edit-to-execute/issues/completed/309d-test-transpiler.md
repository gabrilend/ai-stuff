# Issue 309d: Test JASS-to-Lua Transpiler

**Phase:** 3 - Logic Layer
**Type:** Test
**Priority:** High
**Dependencies:** 304-build-jass-lexer, 305-build-jass-parser, 306-create-jass-lua-transpiler
**Parent Issue:** 309-phase-3-integration-test

---

## Current Behavior

The JASS-to-Lua transpiler (306) is implemented but has no comprehensive test
suite verifying correct transpilation of all language constructs.

---

## Intended Behavior

A comprehensive test suite for the transpiler covering:
- All statement types generate valid Lua
- Expression transpilation with correct semantics
- Generated code is loadable by Lua/LuaJIT
- Semantic equivalence (transpiled code behaves correctly)

```bash
# Run transpiler tests
luajit src/tests/test_309d_transpiler.lua

# Expected output:
# === Statement Transpilation ===
#   [PASS] SET statement
#   [PASS] CALL statement
#   [PASS] IF/THEN/ELSE
#   ...
# === Expression Transpilation ===
#   [PASS] Binary operators
#   [PASS] Function calls
#   ...
# === Lua Validity ===
#   [PASS] All outputs load without error
#   ...
# ALL TESTS PASSED
```

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```lua
   #!/usr/bin/env luajit
   -- {{{ test_309d_transpiler.lua
   -- Comprehensive tests for JASS-to-Lua transpiler
   -- Run from project root: luajit src/tests/test_309d_transpiler.lua

   local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. package.path

   local lexer = require("jass.lexer")
   local parser = require("jass.parser")
   local transpiler = require("jass.transpiler")
   -- }}}
   ```

2. **Implement test utilities**
   ```lua
   -- {{{ Test utilities
   local test_count = 0
   local pass_count = 0
   local fail_count = 0

   local function test(name, condition, msg)
       test_count = test_count + 1
       if condition then
           pass_count = pass_count + 1
           print("  [PASS] " .. name)
       else
           fail_count = fail_count + 1
           print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
       end
   end

   local function test_section(name)
       print("\n=== " .. name .. " ===")
   end

   -- Helper: transpile JASS source to Lua
   local function transpile(jass_source)
       local tokens = lexer.tokenize(jass_source)
       if not tokens then return nil, "Lexer failed" end

       local ast = parser.parse(tokens)
       if not ast then return nil, "Parser failed" end

       local lua_code = transpiler.transpile(ast)
       return lua_code
   end

   -- Helper: check if generated Lua is loadable
   local function is_valid_lua(lua_code)
       local fn, err = loadstring(lua_code)
       return fn ~= nil, err
   end

   -- Helper: transpile and verify loadable
   local function transpile_valid(jass_source)
       local lua_code, err = transpile(jass_source)
       if not lua_code then return false, err end
       return is_valid_lua(lua_code)
   end

   -- Helper: check if output contains expected pattern
   local function output_contains(jass_source, pattern)
       local lua_code = transpile(jass_source)
       return lua_code and lua_code:match(pattern) ~= nil
   end
   -- }}}
   ```

3. **Test SET statement transpilation**
   ```lua
   -- {{{ SET Statement Tests
   test_section("SET Statement Transpilation")

   -- Simple assignment
   local source = [[
   function Test takes nothing returns nothing
       local integer x
       set x = 5
   endfunction
   ]]
   test("SET simple", transpile_valid(source))
   test("SET generates assignment", output_contains(source, "x%s*=%s*5"))

   -- Array assignment
   source = [[
   function Test takes nothing returns nothing
       local integer array arr
       set arr[0] = 10
   endfunction
   ]]
   test("SET array", transpile_valid(source))
   test("SET array indexing", output_contains(source, "arr%["))

   -- SET with expression
   source = [[
   function Test takes nothing returns nothing
       local integer x
       local integer y
       set x = y + 1 * 2
   endfunction
   ]]
   test("SET expression", transpile_valid(source))
   -- }}}
   ```

4. **Test CALL statement transpilation**
   ```lua
   -- {{{ CALL Statement Tests
   test_section("CALL Statement Transpilation")

   -- Simple call
   local source = [[
   function DoNothing takes nothing returns nothing
   endfunction

   function Test takes nothing returns nothing
       call DoNothing()
   endfunction
   ]]
   test("CALL simple", transpile_valid(source))
   test("CALL generates call", output_contains(source, "DoNothing%(%)"))

   -- Call with arguments
   source = [[
   function Add takes integer a, integer b returns integer
       return a + b
   endfunction

   function Test takes nothing returns nothing
       call Add(1, 2)
   endfunction
   ]]
   test("CALL with args", transpile_valid(source))

   -- Nested calls
   source = [[
   function Inner takes nothing returns integer
       return 1
   endfunction

   function Outer takes integer x returns nothing
   endfunction

   function Test takes nothing returns nothing
       call Outer(Inner())
   endfunction
   ]]
   test("CALL nested", transpile_valid(source))
   -- }}}
   ```

5. **Test IF statement transpilation**
   ```lua
   -- {{{ IF Statement Tests
   test_section("IF Statement Transpilation")

   -- Simple if
   local source = [[
   function Test takes nothing returns nothing
       local boolean b
       if b then
       endif
   endfunction
   ]]
   test("IF simple", transpile_valid(source))
   test("IF generates if", output_contains(source, "if%s+"))

   -- If-else
   source = [[
   function Test takes nothing returns nothing
       local boolean b
       if b then
           set b = false
       else
           set b = true
       endif
   endfunction
   ]]
   test("IF-ELSE", transpile_valid(source))
   test("IF-ELSE generates else", output_contains(source, "else"))

   -- If-elseif-else
   source = [[
   function Test takes integer x returns integer
       if x == 1 then
           return 1
       elseif x == 2 then
           return 2
       else
           return 0
       endif
   endfunction
   ]]
   test("IF-ELSEIF-ELSE", transpile_valid(source))
   test("ELSEIF generates elseif", output_contains(source, "elseif"))

   -- Nested if
   source = [[
   function Test takes integer x returns integer
       if x > 0 then
           if x > 10 then
               return 10
           endif
           return x
       endif
       return 0
   endfunction
   ]]
   test("IF nested", transpile_valid(source))
   -- }}}
   ```

6. **Test LOOP statement transpilation**
   ```lua
   -- {{{ LOOP Statement Tests
   test_section("LOOP Statement Transpilation")

   -- Simple loop with exitwhen
   local source = [[
   function Test takes nothing returns nothing
       local integer i
       set i = 0
       loop
           exitwhen i >= 10
           set i = i + 1
       endloop
   endfunction
   ]]
   test("LOOP simple", transpile_valid(source))
   test("LOOP generates while", output_contains(source, "while"))
   test("EXITWHEN generates break", output_contains(source, "break"))

   -- Nested loops
   source = [[
   function Test takes nothing returns nothing
       local integer i
       local integer j
       set i = 0
       loop
           exitwhen i >= 5
           set j = 0
           loop
               exitwhen j >= 5
               set j = j + 1
           endloop
           set i = i + 1
       endloop
   endfunction
   ]]
   test("LOOP nested", transpile_valid(source))
   -- }}}
   ```

7. **Test RETURN statement transpilation**
   ```lua
   -- {{{ RETURN Statement Tests
   test_section("RETURN Statement Transpilation")

   -- Return nothing
   local source = [[
   function Test takes nothing returns nothing
       return
   endfunction
   ]]
   test("RETURN nothing", transpile_valid(source))
   test("RETURN generates return", output_contains(source, "return"))

   -- Return value
   source = [[
   function Test takes nothing returns integer
       return 42
   endfunction
   ]]
   test("RETURN value", transpile_valid(source))
   test("RETURN value correct", output_contains(source, "return%s+42"))

   -- Return expression
   source = [[
   function Test takes integer x returns integer
       return x * 2 + 1
   endfunction
   ]]
   test("RETURN expression", transpile_valid(source))
   -- }}}
   ```

8. **Test expression transpilation**
   ```lua
   -- {{{ Expression Transpilation Tests
   test_section("Expression Transpilation")

   -- Arithmetic operators
   local source = [[
   function Test takes nothing returns integer
       return 1 + 2 - 3 * 4 / 2
   endfunction
   ]]
   test("Arithmetic operators", transpile_valid(source))

   -- Comparison operators
   source = [[
   function Test takes integer x returns boolean
       return x > 0 and x < 100
   endfunction
   ]]
   test("Comparison operators", transpile_valid(source))
   test("AND becomes and", output_contains(source, "%sand%s"))

   -- JASS != becomes Lua ~=
   source = [[
   function Test takes integer x returns boolean
       return x != 0
   endfunction
   ]]
   test("Not equal operator", transpile_valid(source))
   test("!= becomes ~=", output_contains(source, "~="))

   -- OR operator
   source = [[
   function Test takes boolean a, boolean b returns boolean
       return a or b
   endfunction
   ]]
   test("OR operator", transpile_valid(source))

   -- NOT operator
   source = [[
   function Test takes boolean a returns boolean
       return not a
   endfunction
   ]]
   test("NOT operator", transpile_valid(source))

   -- Parenthesized expressions
   source = [[
   function Test takes integer x returns integer
       return (x + 1) * (x - 1)
   endfunction
   ]]
   test("Parentheses", transpile_valid(source))

   -- String literals
   source = [[
   function Test takes nothing returns string
       return "hello world"
   endfunction
   ]]
   test("String literals", transpile_valid(source))

   -- Boolean literals
   source = [[
   function Test takes nothing returns boolean
       return true
   endfunction
   ]]
   test("Boolean true", transpile_valid(source))

   source = [[
   function Test takes nothing returns boolean
       return false
   endfunction
   ]]
   test("Boolean false", transpile_valid(source))

   -- Null literal
   source = [[
   function Test takes nothing returns handle
       return null
   endfunction
   ]]
   test("Null literal", transpile_valid(source))
   test("null becomes nil", output_contains(source, "nil"))
   -- }}}
   ```

9. **Test function declaration transpilation**
   ```lua
   -- {{{ Function Declaration Tests
   test_section("Function Declaration Transpilation")

   -- Function with no params
   local source = [[
   function NoParams takes nothing returns nothing
   endfunction
   ]]
   test("Function no params", transpile_valid(source))
   test("Function generates function", output_contains(source, "function%s+NoParams"))

   -- Function with params
   source = [[
   function WithParams takes integer a, real b, string c returns nothing
   endfunction
   ]]
   test("Function with params", transpile_valid(source))
   test("Params in signature", output_contains(source, "%(a,%s*b,%s*c%)"))

   -- Function with return type
   source = [[
   function GetValue takes nothing returns integer
       return 42
   endfunction
   ]]
   test("Function with return", transpile_valid(source))

   -- Multiple functions
   source = [[
   function First takes nothing returns nothing
   endfunction

   function Second takes nothing returns nothing
   endfunction
   ]]
   test("Multiple functions", transpile_valid(source))
   -- }}}
   ```

10. **Test globals transpilation**
    ```lua
    -- {{{ Globals Transpilation Tests
    test_section("Globals Transpilation")

    -- Simple global
    local source = [[
    globals
        integer MyGlobal = 0
    endglobals

    function Test takes nothing returns integer
        return MyGlobal
    endfunction
    ]]
    test("Global variable", transpile_valid(source))

    -- Constant global
    source = [[
    globals
        constant integer MAX_VALUE = 100
    endglobals

    function Test takes nothing returns integer
        return MAX_VALUE
    endfunction
    ]]
    test("Constant global", transpile_valid(source))

    -- Global array
    source = [[
    globals
        integer array MyArray
    endglobals

    function Test takes nothing returns integer
        return MyArray[0]
    endfunction
    ]]
    test("Global array", transpile_valid(source))

    -- Multiple globals
    source = [[
    globals
        integer a = 1
        integer b = 2
        integer c = 3
    endglobals
    ]]
    test("Multiple globals", transpile_valid(source))
    -- }}}
    ```

11. **Test local variable transpilation**
    ```lua
    -- {{{ Local Variable Tests
    test_section("Local Variable Transpilation")

    -- Simple local
    local source = [[
    function Test takes nothing returns nothing
        local integer x
    endfunction
    ]]
    test("Local declaration", transpile_valid(source))
    test("Local generates local", output_contains(source, "local%s+x"))

    -- Local with initializer
    source = [[
    function Test takes nothing returns nothing
        local integer x = 5
    endfunction
    ]]
    test("Local with init", transpile_valid(source))

    -- Local array
    source = [[
    function Test takes nothing returns nothing
        local integer array arr
    endfunction
    ]]
    test("Local array", transpile_valid(source))
    test("Array initialized", output_contains(source, "{}"))

    -- Multiple locals
    source = [[
    function Test takes nothing returns nothing
        local integer a
        local integer b
        local integer c
    endfunction
    ]]
    test("Multiple locals", transpile_valid(source))
    -- }}}
    ```

12. **Test native function handling**
    ```lua
    -- {{{ Native Function Tests
    test_section("Native Function Handling")

    -- Native call should use runtime prefix
    local source = [[
    function Test takes nothing returns nothing
        call DisplayTextToPlayer(null, 0, 0, "Hello")
    endfunction
    ]]
    local lua_code = transpile(source)
    test("Native call transpiles", lua_code ~= nil)
    -- Native should be prefixed with runtime module
    test("Native uses runtime", output_contains(source, "runtime%.") or
                                  output_contains(source, "_G%.") or
                                  lua_code:match("DisplayTextToPlayer"))

    -- Multiple natives
    source = [[
    function Test takes nothing returns nothing
        call CreateUnit(null, 'hfoo', 0, 0, 0)
        call RemoveUnit(null)
    endfunction
    ]]
    test("Multiple natives", transpile_valid(source))
    -- }}}
    ```

13. **Test semantic correctness with execution**
    ```lua
    -- {{{ Semantic Correctness Tests
    test_section("Semantic Correctness")

    -- Test that transpiled code actually works
    local source = [[
    function Add takes integer a, integer b returns integer
        return a + b
    endfunction
    ]]
    local lua_code = transpile(source)
    local valid, err = is_valid_lua(lua_code)
    test("Add function valid", valid, err)

    if valid then
        local fn = loadstring(lua_code)
        fn()  -- Execute to define the function
        -- The function should now be accessible
        local add_fn = _G.Add or rawget(_G, "Add")
        if add_fn then
            local result = add_fn(2, 3)
            test("Add function executes", result == 5,
                string.format("expected 5, got %s", tostring(result)))
        else
            test("Add function defined", false, "Function not found in globals")
        end
    end

    -- Test loop counting
    source = [[
    function CountTo takes integer n returns integer
        local integer i
        local integer sum
        set i = 0
        set sum = 0
        loop
            exitwhen i >= n
            set sum = sum + 1
            set i = i + 1
        endloop
        return sum
    endfunction
    ]]
    lua_code = transpile(source)
    valid = is_valid_lua(lua_code)
    test("CountTo valid", valid)

    if valid then
        local fn = loadstring(lua_code)
        fn()
        local count_fn = _G.CountTo or rawget(_G, "CountTo")
        if count_fn then
            local result = count_fn(5)
            test("CountTo executes", result == 5,
                string.format("expected 5, got %s", tostring(result)))
        else
            test("CountTo defined", false, "Function not found in globals")
        end
    end

    -- Test conditional logic
    source = [[
    function Max takes integer a, integer b returns integer
        if a > b then
            return a
        else
            return b
        endif
    endfunction
    ]]
    lua_code = transpile(source)
    valid = is_valid_lua(lua_code)
    test("Max valid", valid)

    if valid then
        local fn = loadstring(lua_code)
        fn()
        local max_fn = _G.Max or rawget(_G, "Max")
        if max_fn then
            test("Max(3,5)=5", max_fn(3, 5) == 5)
            test("Max(7,2)=7", max_fn(7, 2) == 7)
            test("Max(4,4)=4", max_fn(4, 4) == 4)
        else
            test("Max defined", false, "Function not found in globals")
        end
    end
    -- }}}
    ```

14. **Test complete JASS program**
    ```lua
    -- {{{ Integration Tests
    test_section("Integration Tests")

    -- Complete program with globals, functions, control flow
    local source = [[
    globals
        integer GlobalCounter = 0
    endglobals

    function IncrementCounter takes nothing returns nothing
        set GlobalCounter = GlobalCounter + 1
    endfunction

    function GetCounter takes nothing returns integer
        return GlobalCounter
    endfunction

    function ResetCounter takes nothing returns nothing
        set GlobalCounter = 0
    endfunction

    function CountToN takes integer n returns integer
        local integer i
        set i = 0
        loop
            exitwhen i >= n
            call IncrementCounter()
            set i = i + 1
        endloop
        return GetCounter()
    endfunction
    ]]

    local lua_code = transpile(source)
    test("Complete program transpiles", lua_code ~= nil)

    local valid, err = is_valid_lua(lua_code)
    test("Complete program valid Lua", valid, err)

    if valid then
        -- Execute the transpiled code
        local fn = loadstring(lua_code)
        fn()

        -- Test the program behavior
        local reset = _G.ResetCounter
        local count = _G.CountToN
        local get = _G.GetCounter

        if reset and count and get then
            reset()
            test("Counter starts at 0", get() == 0)

            local result = count(10)
            test("CountToN(10) = 10", result == 10)
            test("GlobalCounter = 10", get() == 10)

            reset()
            test("Reset works", get() == 0)
        else
            test("All functions defined", false, "Some functions missing")
        end
    end
    -- }}}
    ```

15. **Summary and exit**
    ```lua
    -- {{{ Summary
    print("\n" .. string.rep("=", 50))
    print(string.format("Tests: %d passed, %d failed, %d total",
                        pass_count, fail_count, test_count))
    if fail_count > 0 then
        print("SOME TESTS FAILED")
        os.exit(1)
    else
        print("ALL TESTS PASSED")
        os.exit(0)
    end
    -- }}}
    ```

---

## Technical Notes

### Transpilation Mappings

| JASS Construct | Lua Equivalent |
|----------------|----------------|
| `set x = value` | `x = value` |
| `call func()` | `func()` |
| `if/then/endif` | `if/then/end` |
| `elseif` | `elseif` |
| `loop/endloop` | `while true do/end` |
| `exitwhen cond` | `if cond then break end` |
| `return` | `return` |
| `and` | `and` |
| `or` | `or` |
| `not` | `not` |
| `!=` | `~=` |
| `null` | `nil` |
| `local type var` | `local var` |
| `local type array arr` | `local arr = {}` |

### Native Function Handling

Native JASS functions (CreateUnit, DisplayTextToPlayer, etc.) should be:
1. Prefixed with runtime module reference, OR
2. Left as-is if runtime injects them into globals

The test checks that natives are handled (either prefixed or callable).

### Loadstring Validation

All generated Lua is validated with `loadstring()`:
- Ensures syntactically valid Lua
- Does not execute the code (just compiles)
- Returns nil and error message on failure

### Semantic Testing

Beyond syntax validity, tests execute the generated code:
- Define functions via loadstring + call
- Call transpiled functions with arguments
- Verify return values match expected behavior

---

## Related Documents

- issues/309-phase-3-integration-test.md (parent issue)
- issues/306-create-jass-lua-transpiler.md (transpiler implementation)
- issues/306a-transpiler-infrastructure.md (core transpiler)
- issues/306b-transpile-declarations.md (declarations)
- issues/306c-transpile-statements.md (statements)
- issues/306d-transpile-expressions.md (expressions)
- src/jass/transpiler.lua (implementation)

---

## Acceptance Criteria

- [ ] Test file created at src/tests/test_309d_transpiler.lua
- [ ] SET statement transpilation tested
- [ ] CALL statement transpilation tested
- [ ] IF/ELSEIF/ELSE transpilation tested
- [ ] LOOP/EXITWHEN transpilation tested
- [ ] RETURN statement transpilation tested
- [ ] Expression operators tested (arithmetic, comparison, logical)
- [ ] Function declarations tested
- [ ] Globals transpilation tested
- [ ] Local variables tested
- [ ] Native function handling verified
- [ ] Generated Lua passes loadstring validation
- [ ] Semantic correctness verified (functions execute correctly)
- [ ] Complete JASS program transpiles and runs
- [ ] All tests pass with zero failures

---

## Notes

The transpiler is the final compilation step before execution. Generated Lua
must be both syntactically valid AND semantically correct.

Tests verify:
1. Syntax - loadstring succeeds
2. Semantics - functions compute correct results
3. Completeness - all JASS constructs handled

The semantic tests execute transpiled code, so they also indirectly test
that the lexer and parser produce correct ASTs.

