# Issue 309c: Test JASS Parser

**Phase:** 3 - Logic Layer
**Type:** Test
**Priority:** High
**Dependencies:** 304-build-jass-lexer, 305-build-jass-parser
**Parent Issue:** 309-phase-3-integration-test

---

## Current Behavior

The JASS parser (305) is implemented but has no integration test suite
verifying all grammar constructs and AST generation.

---

## Intended Behavior

A comprehensive test suite for the JASS parser covering:
- All declaration types (type, globals, native, function)
- All statement types (set, call, if, loop, exitwhen, return)
- Expression parsing with correct precedence
- AST structure validation
- Error recovery and reporting

```bash
# Run parser tests
luajit src/tests/test_309c_parser.lua

# Expected output:
# === Declaration Tests ===
#   [PASS] Type declaration
#   [PASS] Globals block
#   ...
# === Statement Tests ===
#   [PASS] Set statement
#   [PASS] If-elseif-else
#   ...
# === Expression Tests ===
#   [PASS] Operator precedence
#   ...
# ALL TESTS PASSED
```

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```lua
   #!/usr/bin/env luajit
   -- {{{ test_309c_parser.lua
   -- Comprehensive tests for JASS parser
   -- Run from project root: luajit src/tests/test_309c_parser.lua

   local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. package.path

   local lexer = require("jass.lexer")
   local parser = require("jass.parser")
   local AST = parser.AST
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

   -- Helper: parse JASS source
   local function parse(source)
       local tokens = lexer.tokenize(source)
       local ast, errors = parser.parse(tokens)
       return ast, errors
   end

   -- Helper: get first declaration
   local function first_decl(source)
       local ast = parse(source)
       return ast and ast.declarations and ast.declarations[1]
   end

   -- Helper: parse expression in return statement
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
   -- }}}
   ```

3. **Test type declarations**
   ```lua
   -- {{{ Type Declaration Tests
   test_section("Type Declaration Tests")

   local decl = first_decl("type unitid extends handle")
   test("Type decl parsed", decl ~= nil)
   test("Type decl type", decl and decl.type == AST.TYPE_DEF)
   test("Type name", decl and decl.name == "unitid")
   test("Type extends", decl and decl.extends == "handle")

   -- Multiple type declarations
   local ast = parse([[
type unit extends handle
type item extends handle
type effect extends handle
]])
   test("Multiple types", ast and #ast.declarations == 3)
   -- }}}
   ```

4. **Test globals block**
   ```lua
   -- {{{ Globals Block Tests
   test_section("Globals Block Tests")

   local ast = parse([[
globals
    integer foo
    real bar = 3.14
    constant integer MAX = 100
    string array names
endglobals
]])

   local globals = ast and ast.declarations[1]
   test("Globals parsed", globals ~= nil)
   test("Globals type", globals and globals.type == AST.GLOBAL_BLOCK)
   test("Four variables", globals and globals.variables and #globals.variables == 4)

   if globals and globals.variables then
       local v1 = globals.variables[1]
       local v2 = globals.variables[2]
       local v3 = globals.variables[3]
       local v4 = globals.variables[4]

       test("Var 1 name", v1.name == "foo")
       test("Var 1 type", v1.var_type == "integer")
       test("Var 1 no init", v1.initializer == nil)

       test("Var 2 has init", v2.initializer ~= nil)

       test("Var 3 constant", v3.is_constant == true)

       test("Var 4 array", v4.is_array == true)
   end
   -- }}}
   ```

5. **Test native declarations**
   ```lua
   -- {{{ Native Declaration Tests
   test_section("Native Declaration Tests")

   local decl = first_decl([[
native CreateUnit takes player p, integer id, real x, real y, real f returns unit
]])

   test("Native parsed", decl ~= nil)
   test("Native type", decl and decl.type == AST.NATIVE_DECL)
   test("Native name", decl and decl.name == "CreateUnit")
   test("Native params", decl and decl.params and #decl.params == 5)
   test("Native returns", decl and decl.return_type == "unit")

   -- Constant native
   decl = first_decl("constant native GetHandleId takes handle h returns integer")
   test("Constant native", decl and decl.is_constant == true)

   -- Native with nothing
   decl = first_decl("native DoNothing takes nothing returns nothing")
   test("Takes nothing", decl and #decl.params == 0)
   test("Returns nothing", decl and decl.return_type == "nothing")
   -- }}}
   ```

6. **Test function definitions**
   ```lua
   -- {{{ Function Definition Tests
   test_section("Function Definition Tests")

   local decl = first_decl([[
function Add takes integer a, integer b returns integer
    local integer sum
    set sum = a + b
    return sum
endfunction
]])

   test("Function parsed", decl ~= nil)
   test("Function type", decl and decl.type == AST.FUNCTION_DEF)
   test("Function name", decl and decl.name == "Add")
   test("Two params", decl and decl.params and #decl.params == 2)
   test("Has locals", decl and decl.locals and #decl.locals == 1)
   test("Has body", decl and decl.body and #decl.body == 2)

   -- Empty function
   decl = first_decl([[
function Empty takes nothing returns nothing
endfunction
]])
   test("Empty function", decl and #decl.body == 0)

   -- Function with multiple locals
   decl = first_decl([[
function Multi takes nothing returns nothing
    local integer a = 0
    local real b
    local unit array c
endfunction
]])
   test("Multiple locals", decl and #decl.locals == 3)
   -- }}}
   ```

7. **Test statements**
   ```lua
   -- {{{ Statement Tests
   test_section("Statement Tests")

   -- SET statement
   local decl = first_decl([[
function test takes nothing returns nothing
    set x = 5
    set arr[i] = 10
endfunction
]])
   test("Set statements", decl and #decl.body == 2)
   test("Set type", decl and decl.body[1].type == AST.SET_STMT)
   test("Array set has index", decl and decl.body[2].index ~= nil)

   -- CALL statement
   decl = first_decl([[
function test takes nothing returns nothing
    call DoNothing()
    call Print(a, b, c)
endfunction
]])
   test("Call statements", decl and #decl.body == 2)
   test("Call type", decl and decl.body[1].type == AST.CALL_STMT)
   test("Call with args", decl and decl.body[2].arguments and #decl.body[2].arguments == 3)

   -- IF statement
   decl = first_decl([[
function test takes nothing returns nothing
    if a > 0 then
        set x = 1
    endif
endfunction
]])
   local if_stmt = decl and decl.body[1]
   test("If statement", if_stmt and if_stmt.type == AST.IF_STMT)
   test("If condition", if_stmt and if_stmt.condition ~= nil)
   test("If then branch", if_stmt and if_stmt.then_branch and #if_stmt.then_branch == 1)

   -- IF-ELSEIF-ELSE
   decl = first_decl([[
function test takes nothing returns nothing
    if a > 0 then
        set x = 1
    elseif a < 0 then
        set x = -1
    else
        set x = 0
    endif
endfunction
]])
   if_stmt = decl and decl.body[1]
   test("Has elseif", if_stmt and if_stmt.elseif_branches and #if_stmt.elseif_branches == 1)
   test("Has else", if_stmt and if_stmt.else_branch and #if_stmt.else_branch == 1)

   -- LOOP statement
   decl = first_decl([[
function test takes nothing returns nothing
    loop
        set i = i + 1
        exitwhen i >= 10
    endloop
endfunction
]])
   local loop_stmt = decl and decl.body[1]
   test("Loop statement", loop_stmt and loop_stmt.type == AST.LOOP_STMT)
   test("Loop body", loop_stmt and loop_stmt.body and #loop_stmt.body == 2)
   test("Exitwhen in loop", loop_stmt and loop_stmt.body[2].type == AST.EXITWHEN_STMT)

   -- RETURN statement
   decl = first_decl([[
function test takes nothing returns integer
    return 42
endfunction
]])
   test("Return with value", decl and decl.body[1].value ~= nil)

   decl = first_decl([[
function test takes nothing returns nothing
    return
endfunction
]])
   test("Return without value", decl and decl.body[1].value == nil)
   -- }}}
   ```

8. **Test expressions**
   ```lua
   -- {{{ Expression Tests
   test_section("Expression Tests")

   -- Literals
   local expr = parse_expr("42")
   test("Integer literal", expr and expr.type == AST.LITERAL)

   expr = parse_expr("3.14")
   test("Real literal", expr and expr.type == AST.LITERAL)

   expr = parse_expr("true")
   test("Boolean literal", expr and expr.type == AST.LITERAL)

   expr = parse_expr('"hello"')
   test("String literal", expr and expr.type == AST.LITERAL)

   expr = parse_expr("null")
   test("Null literal", expr and expr.type == AST.LITERAL)

   -- Identifiers
   expr = parse_expr("myVar")
   test("Identifier", expr and expr.type == AST.IDENTIFIER)

   -- Binary expressions
   expr = parse_expr("a + b")
   test("Binary add", expr and expr.type == AST.BINARY_EXPR)
   test("Add operator", expr and expr.operator == "+")

   -- Unary expressions
   expr = parse_expr("-x")
   test("Unary minus", expr and expr.type == AST.UNARY_EXPR)

   expr = parse_expr("not flag")
   test("Unary not", expr and expr.type == AST.UNARY_EXPR)

   -- Function call
   expr = parse_expr("GetValue(a, b)")
   test("Call expression", expr and expr.type == AST.CALL_EXPR)

   -- Array access
   expr = parse_expr("arr[i]")
   test("Array access", expr and expr.type == AST.ARRAY_ACCESS)

   -- Function reference
   expr = parse_expr("function MyCallback")
   test("Function reference", expr and expr.type == AST.FUNCTION_REF)

   -- Parenthesized
   expr = parse_expr("(a + b)")
   test("Parenthesized", expr and expr.type == AST.BINARY_EXPR)
   -- }}}
   ```

9. **Test operator precedence**
   ```lua
   -- {{{ Precedence Tests
   test_section("Operator Precedence Tests")

   -- Multiplication before addition: 2 + 3 * 4 = 2 + (3 * 4)
   local expr = parse_expr("2 + 3 * 4")
   test("Mul before add",
       expr and expr.type == AST.BINARY_EXPR and
       expr.operator == "+" and
       expr.right.operator == "*")

   -- Division before subtraction
   expr = parse_expr("10 - 6 / 2")
   test("Div before sub",
       expr and expr.operator == "-" and
       expr.right.operator == "/")

   -- AND before OR: a or b and c = a or (b and c)
   expr = parse_expr("a or b and c")
   test("AND before OR",
       expr and expr.operator == "or" and
       expr.right.operator == "and")

   -- Comparison before logical
   expr = parse_expr("a > 0 and b < 10")
   test("Compare before logical",
       expr and expr.operator == "and" and
       expr.left.operator == ">" and
       expr.right.operator == "<")

   -- Parentheses override precedence
   expr = parse_expr("(2 + 3) * 4")
   test("Parens override",
       expr and expr.operator == "*" and
       expr.left.operator == "+")

   -- Unary before binary
   expr = parse_expr("-a * b")
   test("Unary before mul",
       expr and expr.operator == "*" and
       expr.left.type == AST.UNARY_EXPR)
   -- }}}
   ```

10. **Test nested structures**
    ```lua
    -- {{{ Nested Structure Tests
    test_section("Nested Structure Tests")

    local ast = parse([[
function test takes nothing returns nothing
    if a then
        loop
            if b then
                set x = 1
            endif
            exitwhen true
        endloop
    else
        set x = 0
    endif
endfunction
]])

    local decl = ast and ast.declarations[1]
    local outer_if = decl and decl.body[1]
    test("Nested parsed", outer_if ~= nil)

    local inner_loop = outer_if and outer_if.then_branch[1]
    test("Loop in if", inner_loop and inner_loop.type == AST.LOOP_STMT)

    local inner_if = inner_loop and inner_loop.body[1]
    test("If in loop", inner_if and inner_if.type == AST.IF_STMT)
    -- }}}
    ```

11. **Test error handling**
    ```lua
    -- {{{ Error Handling Tests
    test_section("Error Handling Tests")

    -- Missing endfunction
    local ast, errors = parse([[
function broken takes nothing returns nothing
    set x = 5
]])
    test("Missing endfunction error", #errors > 0)

    -- Recovery: should still parse second function
    ast, errors = parse([[
function bad takes nothing returns nothing
    set x =
endfunction
function good takes nothing returns nothing
    set y = 1
endfunction
]])
    test("Error recovery", ast and #ast.declarations >= 1)

    -- Unknown statement
    ast, errors = parse([[
function test takes nothing returns nothing
    invalid x = 5
endfunction
]])
    test("Invalid statement error", #errors > 0)
    -- }}}
    ```

12. **Test complete JASS file**
    ```lua
    -- {{{ Integration Tests
    test_section("Integration Tests")

    local ast, errors = parse([[
type unitid extends handle

globals
    integer count = 0
    unit array units
endglobals

constant native GetHandleId takes handle h returns integer
native CreateUnit takes player p, integer id, real x, real y, real f returns unit

function SpawnUnit takes player p, integer id returns unit
    local unit u
    set u = CreateUnit(p, id, 0.0, 0.0, 0.0)
    set count = count + 1
    set units[count] = u
    return u
endfunction

function Main takes nothing returns nothing
    local integer i = 0
    loop
        exitwhen i >= 10
        call SpawnUnit(Player(0), 'hfoo')
        set i = i + 1
    endloop
endfunction
]])

    test("Complete file parsed", ast ~= nil)
    test("No parse errors", #errors == 0)
    test("Has declarations", ast and #ast.declarations >= 5)

    -- Verify structure
    local has_type = false
    local has_globals = false
    local has_native = false
    local has_function = false

    for _, decl in ipairs(ast.declarations or {}) do
        if decl.type == AST.TYPE_DEF then has_type = true end
        if decl.type == AST.GLOBAL_BLOCK then has_globals = true end
        if decl.type == AST.NATIVE_DECL then has_native = true end
        if decl.type == AST.FUNCTION_DEF then has_function = true end
    end

    test("Has type def", has_type)
    test("Has globals", has_globals)
    test("Has native", has_native)
    test("Has function", has_function)
    -- }}}
    ```

13. **Summary and exit**
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

### AST Node Types

| Node Type | Description |
|-----------|-------------|
| PROGRAM | Root node with declarations array |
| TYPE_DEF | Type definition |
| GLOBAL_BLOCK | Globals block with variables |
| NATIVE_DECL | Native function declaration |
| FUNCTION_DEF | Function definition with body |
| SET_STMT | Assignment statement |
| CALL_STMT | Procedure call |
| IF_STMT | If/elseif/else |
| LOOP_STMT | Loop block |
| EXITWHEN_STMT | Loop exit condition |
| RETURN_STMT | Return statement |
| BINARY_EXPR | Binary operation |
| UNARY_EXPR | Unary operation |
| CALL_EXPR | Function call expression |
| ARRAY_ACCESS | Array indexing |
| IDENTIFIER | Variable reference |
| LITERAL | Constant value |
| FUNCTION_REF | Function reference |

### Operator Precedence (lowest to highest)

1. `or`
2. `and`
3. `not`
4. `==`, `!=`, `<`, `<=`, `>`, `>=`
5. `+`, `-`
6. `*`, `/`
7. unary `-`, `not`
8. function call, array access

---

## Related Documents

- issues/309-phase-3-integration-test.md (parent issue)
- issues/305-build-jass-parser.md (parser implementation)
- issues/309b-test-jass-lexer.md (lexer tests)
- issues/309d-test-transpiler.md (uses parser output)
- src/jass/parser.lua (implementation)

---

## Acceptance Criteria

- [ ] Test file created at src/tests/test_309c_parser.lua
- [ ] Type declarations tested
- [ ] Globals block tested (vars, arrays, constants, initializers)
- [ ] Native declarations tested (params, returns, constant)
- [ ] Function definitions tested (params, locals, body)
- [ ] All statement types tested (set, call, if, loop, return, exitwhen)
- [ ] All expression types tested (literals, identifiers, operators, calls)
- [ ] Operator precedence verified
- [ ] Nested structures parsed correctly
- [ ] Error reporting works
- [ ] Error recovery allows parsing to continue
- [ ] Complete JASS file parses correctly
- [ ] All tests pass with zero failures

---

## Notes

The parser is the heart of JASS processing. It transforms tokens into a
structured AST that the transpiler can work with.

Key testing areas:
1. **Correctness** - AST structure matches grammar
2. **Completeness** - All JASS constructs covered
3. **Precedence** - Operators group correctly
4. **Recovery** - Errors don't prevent further parsing

The AST constants (AST.FUNCTION_DEF, etc.) should be exported by the
parser module for use in tests and transpiler.

