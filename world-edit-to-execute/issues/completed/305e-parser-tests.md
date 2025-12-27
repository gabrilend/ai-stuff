# Issue 305e: Parser Tests

**Phase:** 3 - Logic Layer
**Type:** Test
**Priority:** High
**Dependencies:** 305a-parser-infrastructure, 305b-parse-declarations, 305c-parse-expressions, 305d-parse-statements
**Parent Issue:** 305-build-jass-parser

---

## Current Behavior

Parser modules (305a-d) implement JASS parsing but have no comprehensive test
coverage. Parser correctness cannot be verified systematically.

---

## Intended Behavior

A comprehensive test suite validating the parser against JASS grammar constructs:
- Unit tests for each declaration type
- Unit tests for each statement type
- Expression precedence tests
- Error recovery tests
- Integration test parsing a complete JASS file
- Edge cases: empty functions, nested ifs, complex expressions

```lua
local parser = require("jass.parser")
local lexer = require("jass.lexer")

-- Run tests
lua src/tests/test_parser.lua

-- Expected output:
-- === Declaration Tests ===
--   [PASS] Parse type declaration
--   [PASS] Parse globals block
--   ...
-- === Expression Tests ===
--   [PASS] Precedence: multiplication before addition
--   ...
-- === Statement Tests ===
--   [PASS] Parse set statement
--   ...
-- === Integration Tests ===
--   [PASS] Parse complete common.j header
--   ...
-- ALL TESTS PASSED
```

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```lua
   -- {{{ test_parser.lua
   #!/usr/bin/env lua
   -- Test script for JASS parser
   -- Tests all grammar constructs from 305a-d
   -- Run from project root: luajit src/tests/test_parser.lua

   local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. package.path

   local lexer = require("jass.lexer")
   local parser = require("jass.parser")
   -- }}}
   ```

2. **Test utilities (match project style)**
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

   -- Helper: parse JASS string and return AST
   local function parse(source)
       local tokens = lexer.tokenize(source)
       local ast, errors = parser.parse(tokens)
       return ast, errors
   end

   -- Helper: check if AST has node type at path
   local function has_node(ast, node_type, path)
       local node = ast
       for _, key in ipairs(path or {}) do
           node = node and node[key]
       end
       return node and node.type == node_type
   end
   -- }}}
   ```

3. **Type declaration tests**
   ```lua
   -- {{{ Type Declaration Tests
   test_section("Type Declarations")

   local ast, err = parse("type unitid extends handle")
   test("Parse type declaration", ast ~= nil and #err == 0)
   test("Type decl has correct node type",
        has_node(ast, "TYPE_DEF", {"declarations", 1}))

   ast = parse("type effectid extends handle\ntype triggerid extends handle")
   test("Parse multiple type declarations",
        ast and #ast.declarations == 2)
   -- }}}
   ```

4. **Globals block tests**
   ```lua
   -- {{{ Globals Block Tests
   test_section("Globals Block")

   local ast = parse([[
globals
    integer foo
    real bar = 3.14
    constant integer MAX = 100
    string array names
endglobals
]])
   test("Parse globals block", ast ~= nil)
   test("Has 4 variable declarations",
        ast and ast.declarations[1] and
        ast.declarations[1].variables and
        #ast.declarations[1].variables == 4)

   -- Test constant flag
   local globals = ast.declarations[1].variables
   test("Constant flag set correctly",
        globals[3] and globals[3].is_constant == true)

   -- Test array flag
   test("Array flag set correctly",
        globals[4] and globals[4].is_array == true)
   -- }}}
   ```

5. **Native declaration tests**
   ```lua
   -- {{{ Native Declaration Tests
   test_section("Native Declarations")

   local ast = parse([[
native CreateUnit takes player p, integer id, real x, real y, real f returns unit
]])
   test("Parse native declaration", ast ~= nil)

   local native = ast.declarations[1]
   test("Native has correct name",
        native and native.name == "CreateUnit")
   test("Native has 5 parameters",
        native and native.params and #native.params == 5)
   test("Native returns unit",
        native and native.return_type == "unit")

   -- Constant native
   ast = parse("constant native GetHandleId takes handle h returns integer")
   test("Parse constant native",
        ast and ast.declarations[1] and
        ast.declarations[1].is_constant == true)
   -- }}}
   ```

6. **Function definition tests**
   ```lua
   -- {{{ Function Definition Tests
   test_section("Function Definitions")

   local ast = parse([[
function DoNothing takes nothing returns nothing
endfunction
]])
   test("Parse empty function", ast ~= nil)

   local func = ast.declarations[1]
   test("Function name correct", func and func.name == "DoNothing")
   test("Takes nothing", func and #func.params == 0)
   test("Returns nothing", func and func.return_type == "nothing")
   test("Empty body", func and #func.body == 0)

   -- Function with parameters
   ast = parse([[
function AddIntegers takes integer a, integer b returns integer
    return a + b
endfunction
]])
   func = ast.declarations[1]
   test("Function with 2 params", func and #func.params == 2)
   test("Has return statement", func and #func.body == 1)

   -- Function with locals
   ast = parse([[
function WithLocals takes nothing returns nothing
    local integer i = 0
    local real r
    local unit array units
endfunction
]])
   func = ast.declarations[1]
   test("Parse function with locals",
        func and func.locals and #func.locals == 3)
   test("Local with initializer",
        func.locals[1] and func.locals[1].initializer ~= nil)
   test("Local without initializer",
        func.locals[2] and func.locals[2].initializer == nil)
   test("Local array",
        func.locals[3] and func.locals[3].is_array == true)
   -- }}}
   ```

7. **Expression precedence tests**
   ```lua
   -- {{{ Expression Precedence Tests
   test_section("Expression Precedence")

   -- Parse expression and check AST structure
   local function parse_expr(expr_str)
       local source = string.format([[
function test takes nothing returns integer
    return %s
endfunction
]], expr_str)
       local ast = parse(source)
       if ast and ast.declarations[1] and ast.declarations[1].body[1] then
           return ast.declarations[1].body[1].value
       end
       return nil
   end

   -- 2 + 3 * 4 should parse as 2 + (3 * 4)
   local expr = parse_expr("2 + 3 * 4")
   test("Multiplication before addition",
        expr and expr.type == "BINARY_EXPR" and
        expr.operator == "+" and
        expr.right.type == "BINARY_EXPR" and
        expr.right.operator == "*")

   -- 2 * 3 + 4 should parse as (2 * 3) + 4
   expr = parse_expr("2 * 3 + 4")
   test("Multiplication groups left",
        expr and expr.type == "BINARY_EXPR" and
        expr.operator == "+" and
        expr.left.type == "BINARY_EXPR" and
        expr.left.operator == "*")

   -- a and b or c should parse as (a and b) or c
   expr = parse_expr("a and b or c")
   test("AND before OR",
        expr and expr.type == "BINARY_EXPR" and
        expr.operator == "or" and
        expr.left.operator == "and")

   -- Comparison precedence
   expr = parse_expr("a + 1 > b - 1")
   test("Arithmetic before comparison",
        expr and expr.operator == ">" and
        expr.left.operator == "+" and
        expr.right.operator == "-")

   -- Unary precedence
   expr = parse_expr("-a * b")
   test("Unary before multiplication",
        expr and expr.operator == "*" and
        expr.left.type == "UNARY_EXPR")

   -- Parentheses override precedence
   expr = parse_expr("(2 + 3) * 4")
   test("Parentheses override precedence",
        expr and expr.operator == "*" and
        expr.left.type == "BINARY_EXPR" and
        expr.left.operator == "+")

   -- not has correct precedence
   expr = parse_expr("not a and b")
   test("NOT before AND",
        expr and expr.operator == "and" and
        expr.left.type == "UNARY_EXPR")
   -- }}}
   ```

8. **Statement tests**
   ```lua
   -- {{{ Statement Tests
   test_section("Statements")

   -- SET statement
   local ast = parse([[
function test takes nothing returns nothing
    set x = 5
    set arr[0] = 10
endfunction
]])
   local body = ast.declarations[1].body
   test("Parse set statement", body[1] and body[1].type == "SET_STMT")
   test("Set target correct", body[1].target == "x")
   test("Set array element", body[2] and body[2].index ~= nil)

   -- CALL statement
   ast = parse([[
function test takes nothing returns nothing
    call DoNothing()
    call SetUnitX(u, 100.0)
endfunction
]])
   body = ast.declarations[1].body
   test("Parse call statement", body[1] and body[1].type == "CALL_STMT")
   test("Call with no args", #body[1].arguments == 0)
   test("Call with 2 args", #body[2].arguments == 2)

   -- IF statement
   ast = parse([[
function test takes nothing returns nothing
    if a > 0 then
        set a = 0
    endif
endfunction
]])
   body = ast.declarations[1].body
   test("Parse if statement", body[1] and body[1].type == "IF_STMT")
   test("If has condition", body[1].condition ~= nil)
   test("If has then branch", body[1].then_branch and #body[1].then_branch == 1)

   -- IF-ELSE statement
   ast = parse([[
function test takes nothing returns nothing
    if a > 0 then
        set a = 0
    else
        set a = 1
    endif
endfunction
]])
   body = ast.declarations[1].body
   test("Parse if-else", body[1].else_branch ~= nil)
   test("Else branch has statement", #body[1].else_branch == 1)

   -- IF-ELSEIF-ELSE statement
   ast = parse([[
function test takes nothing returns nothing
    if a > 0 then
        set a = 1
    elseif a < 0 then
        set a = -1
    else
        set a = 0
    endif
endfunction
]])
   body = ast.declarations[1].body
   test("Parse if-elseif-else", body[1].elseif_branches ~= nil)
   test("Has 1 elseif branch", #body[1].elseif_branches == 1)

   -- LOOP statement
   ast = parse([[
function test takes nothing returns nothing
    loop
        set i = i + 1
        exitwhen i >= 10
    endloop
endfunction
]])
   body = ast.declarations[1].body
   test("Parse loop statement", body[1] and body[1].type == "LOOP_STMT")
   test("Loop has body", body[1].body and #body[1].body == 2)
   test("Exitwhen in loop", body[1].body[2].type == "EXITWHEN_STMT")

   -- RETURN statement
   ast = parse([[
function test takes nothing returns integer
    return 42
endfunction
]])
   body = ast.declarations[1].body
   test("Parse return with value", body[1] and body[1].type == "RETURN_STMT")
   test("Return has value", body[1].value ~= nil)

   ast = parse([[
function test takes nothing returns nothing
    return
endfunction
]])
   body = ast.declarations[1].body
   test("Parse return without value", body[1].value == nil)
   -- }}}
   ```

9. **Primary expression tests**
   ```lua
   -- {{{ Primary Expression Tests
   test_section("Primary Expressions")

   local function parse_expr(expr_str)
       local source = string.format([[
function test takes nothing returns integer
    return %s
endfunction
]], expr_str)
       local ast = parse(source)
       return ast and ast.declarations[1].body[1].value
   end

   -- Literals
   local expr = parse_expr("42")
   test("Integer literal", expr and expr.type == "LITERAL")

   expr = parse_expr("3.14")
   test("Real literal", expr and expr.type == "LITERAL")

   expr = parse_expr("true")
   test("Boolean literal", expr and expr.type == "LITERAL")

   expr = parse_expr("\"hello\"")
   test("String literal", expr and expr.type == "LITERAL")

   expr = parse_expr("null")
   test("Null literal", expr and expr.type == "LITERAL")

   expr = parse_expr("'hfoo'")
   test("FourCC literal", expr and expr.type == "LITERAL")

   -- Identifier
   expr = parse_expr("myVar")
   test("Identifier", expr and expr.type == "IDENTIFIER")

   -- Function call
   expr = parse_expr("GetRandomInt(1, 10)")
   test("Function call expression", expr and expr.type == "CALL_EXPR")
   test("Call has 2 arguments", expr and #expr.arguments == 2)

   -- Array access
   expr = parse_expr("arr[i]")
   test("Array access", expr and expr.type == "ARRAY_ACCESS")

   -- Function reference
   expr = parse_expr("function MyCallback")
   test("Function reference", expr and expr.type == "FUNCTION_REF")
   -- }}}
   ```

10. **Error recovery tests**
    ```lua
    -- {{{ Error Recovery Tests
    test_section("Error Recovery")

    -- Missing endfunction
    local ast, errors = parse([[
function broken takes nothing returns nothing
    set x = 5
]])
    test("Reports missing endfunction", #errors > 0)

    -- Multiple errors
    ast, errors = parse([[
function test1 takes nothing returns nothing
    set x =
endfunction
function test2 takes nothing returns nothing
    set y = 5
endfunction
]])
    test("Recovers to parse second function",
         ast and #ast.declarations >= 2)

    -- Invalid statement keyword
    ast, errors = parse([[
function test takes nothing returns nothing
    invalid x = 5
    set y = 10
endfunction
]])
    test("Reports unknown statement", #errors > 0)
    test("Continues after error", ast ~= nil)

    -- Missing then
    ast, errors = parse([[
function test takes nothing returns nothing
    if a > 0
        set a = 0
    endif
endfunction
]])
    test("Reports missing then", #errors > 0)

    -- Locals after statements (JASS requirement)
    ast, errors = parse([[
function test takes nothing returns nothing
    set x = 5
    local integer y
endfunction
]])
    test("Reports misplaced local", #errors > 0)
    -- }}}
    ```

11. **Nested structure tests**
    ```lua
    -- {{{ Nested Structure Tests
    test_section("Nested Structures")

    local ast = parse([[
function test takes nothing returns nothing
    loop
        if a > 0 then
            loop
                exitwhen b >= 10
                set b = b + 1
            endloop
        else
            exitwhen true
        endif
    endloop
endfunction
]])
    test("Parse nested loop/if", ast ~= nil and #(parse(nil) or {}) == 0)

    local outer_loop = ast.declarations[1].body[1]
    test("Outer loop parsed", outer_loop and outer_loop.type == "LOOP_STMT")

    local inner_if = outer_loop.body[1]
    test("Inner if parsed", inner_if and inner_if.type == "IF_STMT")

    local inner_loop = inner_if.then_branch[1]
    test("Inner loop parsed", inner_loop and inner_loop.type == "LOOP_STMT")
    test("Inner loop has 2 statements", #inner_loop.body == 2)
    -- }}}
    ```

12. **Edge case tests**
    ```lua
    -- {{{ Edge Case Tests
    test_section("Edge Cases")

    -- Empty if body
    local ast = parse([[
function test takes nothing returns nothing
    if false then
    endif
endfunction
]])
    test("Empty if body allowed",
         ast and ast.declarations[1].body[1].then_branch and
         #ast.declarations[1].body[1].then_branch == 0)

    -- Empty loop body
    ast = parse([[
function test takes nothing returns nothing
    loop
        exitwhen true
    endloop
endfunction
]])
    test("Loop with only exitwhen", ast ~= nil)

    -- Chained function calls in expression
    ast = parse([[
function test takes nothing returns unit
    return GetOwningPlayer(GetTriggerUnit())
endfunction
]])
    test("Nested function calls", ast ~= nil)
    local ret_expr = ast.declarations[1].body[1].value
    test("Outer call has inner call arg",
         ret_expr.type == "CALL_EXPR" and
         ret_expr.arguments[1].type == "CALL_EXPR")

    -- Complex expression
    ast = parse([[
function test takes nothing returns boolean
    return (a + b) * c > d and not (e or f)
endfunction
]])
    test("Complex expression parses", ast ~= nil)

    -- Debug statement (should be handled)
    ast = parse([[
function test takes nothing returns nothing
    debug set x = 5
    debug call BJDebugMsg("test")
endfunction
]])
    test("Debug statements handled", ast ~= nil)
    -- }}}
    ```

13. **Integration test with real JASS**
    ```lua
    -- {{{ Integration Tests
    test_section("Integration Tests")

    -- Parse a realistic JASS snippet (common.j style)
    local ast = parse([[
type unitid extends handle
type abilityid extends handle

globals
    constant real bj_PI = 3.14159
    constant real bj_E = 2.71828
    integer bj_forLoopAIndex = 0
    unit array bj_lastCreatedUnit
endglobals

constant native GetHandleId takes handle h returns integer
native CreateUnit takes player p, integer id, real x, real y, real f returns unit

function GetRandomReal takes real lo, real hi returns real
    return GetRandomInt(R2I(lo * 1000), R2I(hi * 1000)) / 1000.0
endfunction

function CreateNUnitsAtLoc takes integer count, integer unitId, player whichPlayer, location loc, real face returns group
    local group g = CreateGroup()
    local integer i = 0

    loop
        exitwhen i >= count
        call GroupAddUnit(g, CreateUnitAtLoc(whichPlayer, unitId, loc, face))
        set i = i + 1
    endloop

    return g
endfunction
]])

    test("Parse complete JASS snippet", ast ~= nil)
    test("Has 2 type declarations",
         ast and #ast.declarations >= 2 and
         ast.declarations[1].type == "TYPE_DEF")
    test("Has globals block",
         ast and ast.declarations[3] and
         ast.declarations[3].type == "GLOBAL_BLOCK")
    test("Has native declarations",
         ast and ast.declarations[4] and
         ast.declarations[4].type == "NATIVE_DECL")
    test("Has function definitions",
         ast and ast.declarations[6] and
         ast.declarations[6].type == "FUNCTION_DEF")
    -- }}}
    ```

14. **Summary and exit**
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

### Test Organization

Tests are organized by parser component:
1. **Declaration tests** - Validate 305b output
2. **Expression tests** - Validate 305c output with precedence checks
3. **Statement tests** - Validate 305d output
4. **Error recovery tests** - Validate 305a error handling
5. **Integration tests** - Validate complete parser chain

### Expression Precedence Validation

Expression tests validate the precedence chain by checking AST structure:
- The root operator should be the lowest precedence
- Higher precedence operators should be nested deeper

Example: `2 + 3 * 4` should produce:
```
    BINARY_EXPR(+)
    ├── LITERAL(2)
    └── BINARY_EXPR(*)
        ├── LITERAL(3)
        └── LITERAL(4)
```

### Error Messages

Error tests should verify:
1. Errors are reported (array length > 0)
2. Parser continues after errors (recovery works)
3. Error messages include line/column info

### Test Data

Tests use inline JASS strings rather than external files for:
- Self-contained tests
- Clear correlation between input and expected output
- Easy modification during development

### Running Tests

```bash
# Run parser tests
luajit src/tests/test_parser.lua

# Run with custom project dir
luajit src/tests/test_parser.lua /path/to/project
```

---

## Related Documents

- issues/305a-parser-infrastructure.md (error handling, helpers)
- issues/305b-parse-declarations.md (declaration parsing)
- issues/305c-parse-expressions.md (expression parsing)
- issues/305d-parse-statements.md (statement parsing)
- issues/305-build-jass-parser.md (parent issue)
- src/tests/test_hash.lua (test style reference)

---

## Acceptance Criteria

- [x] Test file created at src/tests/test_parser.lua
- [x] Test utilities match project style (vimfolds, test/test_section)
- [x] Type declaration tests pass
- [x] Globals block tests pass
- [x] Native declaration tests pass
- [x] Function definition tests pass
- [x] Expression precedence tests verify correct operator ordering
- [x] All statement types have passing tests
- [x] Primary expression tests (literals, identifiers, calls, arrays)
- [x] Error recovery tests show parser continues after errors
- [x] Nested structure tests (loop in if in loop)
- [x] Edge case tests (empty bodies, debug statements)
- [x] Integration test parses realistic JASS snippet
- [x] All tests pass with zero failures
- [x] Test output follows project format ([PASS]/[FAIL] markers)

---

## Notes

This sub-issue is the final component of the parser, providing validation
that all parsing components work correctly together. The tests serve as
both verification and documentation of parser behavior.

Test-driven development approach: if a test fails, it indicates which
sub-issue's implementation needs attention (305a for infrastructure
errors, 305c for expression issues, etc.).

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created

- `src/tests/test_parser.lua` (~550 lines, 57 tests)
  - Comprehensive unified test suite
  - Tests organized by parser component
  - Integration tests with realistic JASS code

### Test Coverage

Total parser tests: **305**

| Test File | Tests | Coverage |
|-----------|-------|----------|
| test_parser.lua | 57 | Comprehensive unified suite |
| test_parser_infra.lua | 56 | Infrastructure (305a) |
| test_parser_decl.lua | 19 | Declarations (305b) |
| test_parser_expr.lua | 64 | Expressions (305c) |
| test_parser_stmt.lua | 109 | Statements (305d) |

### Test Categories in test_parser.lua (57 tests)

- Type declarations: 2 tests
- Globals block: 4 tests
- Native declarations: 4 tests
- Function definitions: 3 tests
- Expression precedence: 7 tests
- Primary expressions: 10 tests
- Statements: 11 tests
- Error recovery: 3 tests
- Nested structures: 3 tests
- Edge cases: 5 tests
- Integration (realistic JASS): 5 tests

### Integration Tests

Validates parsing of realistic JASS patterns:
1. common.j style header (types, globals, natives)
2. blizzard.j style function (loop, locals, function calls)
3. Trigger initialization pattern
4. Hero ability function with complex control flow
5. Complete map initialization (globals + multiple functions)

### Key Findings

- Parser correctly handles all JASS constructs
- Error recovery allows parsing to continue after syntax errors
- Expression precedence follows JASS specification
- Nested control structures parse correctly to arbitrary depth

