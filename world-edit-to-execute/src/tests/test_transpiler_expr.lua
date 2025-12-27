--[[
JASS Transpiler Expression Tests

Tests for issue 306d - expression transpilation:
- Literal transpilation (integer, real, boolean, string, null, fourcc)
- Identifier transpilation
- Binary expression transpilation (operators, string concat)
- Unary expression transpilation
- Function call expression transpilation (user and native)
- Array access transpilation
- Function reference transpilation
]]

package.path = package.path .. ";src/?.lua;src/?/init.lua"

local lexer = require("jass.lexer")
local parser = require("jass.parser")
local transpiler = require("jass.transpiler")

local tests_run = 0
local tests_passed = 0

-- {{{ assert_eq
local function assert_eq(actual, expected, msg)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", msg or "assertion failed"))
        print(string.format("  expected: %s", tostring(expected)))
        print(string.format("  actual: %s", tostring(actual)))
        return false
    end
end
-- }}}

-- {{{ assert_contains
local function assert_contains(str, substring, msg)
    tests_run = tests_run + 1
    if str and str:find(substring, 1, true) then
        tests_passed = tests_passed + 1
        return true
    else
        print(string.format("FAIL: %s", msg or "string should contain substring"))
        print(string.format("  looking for: %s", tostring(substring)))
        print(string.format("  in string: %s", tostring(str):sub(1, 300)))
        return false
    end
end
-- }}}

-- {{{ parse_and_transpile
local function parse_and_transpile(source)
    local tokens = lexer.tokenize(source)
    local ast, parse_errors = parser.parse(tokens)
    if #parse_errors > 0 then
        print("Parse errors:")
        for _, e in ipairs(parse_errors) do
            print("  " .. parser.format_error(e))
        end
    end
    local output, transpile_errors = transpiler.transpile(ast)
    return output, transpile_errors, ast
end
-- }}}

-- {{{ create_context
-- Create a minimal transpilation context for direct testing
local function create_context()
    return transpiler._create_context()
end
-- }}}

print("=== JASS Transpiler Expression Tests ===\n")

-- ============================================================================
-- Helper Function Tests
-- ============================================================================

print("--- Helper Function Tests ---")

-- {{{ test: escape_string basic
do
    local result = transpiler._escape_string("hello")
    assert_eq(result, '"hello"', "escape_string basic")
end
-- }}}

-- {{{ test: escape_string with newline
do
    local result = transpiler._escape_string("hello\nworld")
    assert_eq(result, '"hello\\nworld"', "escape_string with newline")
end
-- }}}

-- {{{ test: escape_string with quotes
do
    local result = transpiler._escape_string('say "hi"')
    assert_eq(result, '"say \\"hi\\""', "escape_string with quotes")
end
-- }}}

-- {{{ test: escape_string with tab
do
    local result = transpiler._escape_string("a\tb")
    assert_eq(result, '"a\\tb"', "escape_string with tab")
end
-- }}}

-- {{{ test: escape_string with backslash
do
    local result = transpiler._escape_string("a\\b")
    assert_eq(result, '"a\\\\b"', "escape_string with backslash")
end
-- }}}

-- {{{ test: escape_string nil
do
    local result = transpiler._escape_string(nil)
    assert_eq(result, '""', "escape_string nil returns empty")
end
-- }}}

-- {{{ test: fourcc_to_int 'hfoo'
do
    local result = transpiler._fourcc_to_int("hfoo")
    -- h=104, f=102, o=111, o=111
    -- 104*16777216 + 102*65536 + 111*256 + 111 = 1751543663
    assert_eq(result, 1751543663, "fourcc_to_int hfoo")
end
-- }}}

-- {{{ test: fourcc_to_int 'hpea'
do
    local result = transpiler._fourcc_to_int("hpea")
    -- h=104, p=112, e=101, a=97
    -- 104*16777216 + 112*65536 + 101*256 + 97 = 1752196449
    assert_eq(result, 1752196449, "fourcc_to_int hpea")
end
-- }}}

-- {{{ test: fourcc_to_int nil
do
    local result = transpiler._fourcc_to_int(nil)
    assert_eq(result, 0, "fourcc_to_int nil returns 0")
end
-- }}}

-- {{{ test: fourcc_to_int wrong length
do
    local result = transpiler._fourcc_to_int("abc")
    assert_eq(result, 0, "fourcc_to_int wrong length returns 0")
end
-- }}}

-- ============================================================================
-- Literal Transpilation Tests
-- ============================================================================

print("--- Literal Transpilation Tests ---")

-- {{{ test: integer literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "integer", value = 42}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "42", "integer literal")
end
-- }}}

-- {{{ test: negative integer literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "integer", value = -100}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "-100", "negative integer literal")
end
-- }}}

-- {{{ test: real literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "real", value = 3.14}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "3.14", "real literal")
end
-- }}}

-- {{{ test: real literal whole number
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "real", value = 5}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "5.0", "real literal adds decimal")
end
-- }}}

-- {{{ test: boolean true literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "boolean", value = true}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "true", "boolean true literal")
end
-- }}}

-- {{{ test: boolean false literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "boolean", value = false}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "false", "boolean false literal")
end
-- }}}

-- {{{ test: string literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "string", value = "hello world"}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, '"hello world"', "string literal")
end
-- }}}

-- {{{ test: null literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "null", value = nil}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "nil", "null literal")
end
-- }}}

-- {{{ test: fourcc literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "fourcc", value = "hfoo"}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "1751543663", "fourcc literal")
end
-- }}}

-- {{{ test: rawcode literal
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "rawcode", value = "hpea"}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "1752196449", "rawcode literal")
end
-- }}}

-- {{{ test: unknown literal type
do
    local ctx = create_context()
    local node = {type = "LITERAL", literal_type = "unknown_type", value = "x"}
    local result = transpiler._transpile_literal(ctx, node)
    assert_eq(result, "nil", "unknown literal type returns nil")
    assert_eq(#ctx.errors, 1, "unknown literal type logs error")
end
-- }}}

-- ============================================================================
-- Binary Expression Tests
-- ============================================================================

print("--- Binary Expression Tests ---")

-- {{{ test: addition
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "+",
        left = {type = "IDENTIFIER", name = "a"},
        right = {type = "IDENTIFIER", name = "b"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(a + b)", "binary addition")
end
-- }}}

-- {{{ test: subtraction
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "-",
        left = {type = "IDENTIFIER", name = "x"},
        right = {type = "LITERAL", literal_type = "integer", value = 1}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(x - 1)", "binary subtraction")
end
-- }}}

-- {{{ test: multiplication
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "*",
        left = {type = "IDENTIFIER", name = "a"},
        right = {type = "IDENTIFIER", name = "b"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(a * b)", "binary multiplication")
end
-- }}}

-- {{{ test: division
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "/",
        left = {type = "IDENTIFIER", name = "x"},
        right = {type = "LITERAL", literal_type = "integer", value = 2}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(x / 2)", "binary division")
end
-- }}}

-- {{{ test: equality
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "==",
        left = {type = "IDENTIFIER", name = "a"},
        right = {type = "IDENTIFIER", name = "b"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(a == b)", "binary equality")
end
-- }}}

-- {{{ test: inequality (JASS != becomes Lua ~=)
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "!=",
        left = {type = "IDENTIFIER", name = "a"},
        right = {type = "IDENTIFIER", name = "b"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(a ~= b)", "binary inequality != becomes ~=")
end
-- }}}

-- {{{ test: less than
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "<",
        left = {type = "IDENTIFIER", name = "x"},
        right = {type = "LITERAL", literal_type = "integer", value = 10}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(x < 10)", "binary less than")
end
-- }}}

-- {{{ test: less than or equal
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "<=",
        left = {type = "IDENTIFIER", name = "x"},
        right = {type = "LITERAL", literal_type = "integer", value = 10}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(x <= 10)", "binary less than or equal")
end
-- }}}

-- {{{ test: greater than
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = ">",
        left = {type = "IDENTIFIER", name = "x"},
        right = {type = "LITERAL", literal_type = "integer", value = 0}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(x > 0)", "binary greater than")
end
-- }}}

-- {{{ test: greater than or equal
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = ">=",
        left = {type = "IDENTIFIER", name = "y"},
        right = {type = "LITERAL", literal_type = "integer", value = 5}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(y >= 5)", "binary greater than or equal")
end
-- }}}

-- {{{ test: logical and
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "and",
        left = {type = "IDENTIFIER", name = "a"},
        right = {type = "IDENTIFIER", name = "b"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(a and b)", "binary logical and")
end
-- }}}

-- {{{ test: logical or
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "or",
        left = {type = "IDENTIFIER", name = "a"},
        right = {type = "IDENTIFIER", name = "b"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(a or b)", "binary logical or")
end
-- }}}

-- {{{ test: string concatenation with left string literal
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "+",
        left = {type = "LITERAL", literal_type = "string", value = "hello"},
        right = {type = "IDENTIFIER", name = "name"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, '("hello" .. name)', "string concat with left literal")
end
-- }}}

-- {{{ test: string concatenation with right string literal
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "+",
        left = {type = "IDENTIFIER", name = "prefix"},
        right = {type = "LITERAL", literal_type = "string", value = ".txt"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, '(prefix .. ".txt")', "string concat with right literal")
end
-- }}}

-- {{{ test: unknown operator
do
    local ctx = create_context()
    local node = {
        type = "BINARY_EXPR",
        operator = "???",
        left = {type = "IDENTIFIER", name = "a"},
        right = {type = "IDENTIFIER", name = "b"}
    }
    local result = transpiler._transpile_binary(ctx, node)
    assert_eq(result, "(a ??? b)", "unknown operator passes through")
    assert_eq(#ctx.errors, 1, "unknown operator logs error")
end
-- }}}

-- ============================================================================
-- Unary Expression Tests
-- ============================================================================

print("--- Unary Expression Tests ---")

-- {{{ test: unary minus
do
    local ctx = create_context()
    local node = {
        type = "UNARY_EXPR",
        operator = "-",
        operand = {type = "IDENTIFIER", name = "x"}
    }
    local result = transpiler._transpile_unary(ctx, node)
    assert_eq(result, "(-x)", "unary minus")
end
-- }}}

-- {{{ test: unary minus on literal
do
    local ctx = create_context()
    local node = {
        type = "UNARY_EXPR",
        operator = "-",
        operand = {type = "LITERAL", literal_type = "integer", value = 5}
    }
    local result = transpiler._transpile_unary(ctx, node)
    assert_eq(result, "(-5)", "unary minus on literal")
end
-- }}}

-- {{{ test: unary not
do
    local ctx = create_context()
    local node = {
        type = "UNARY_EXPR",
        operator = "not",
        operand = {type = "IDENTIFIER", name = "flag"}
    }
    local result = transpiler._transpile_unary(ctx, node)
    assert_eq(result, "(not flag)", "unary not")
end
-- }}}

-- {{{ test: unary not on expression
do
    local ctx = create_context()
    local node = {
        type = "UNARY_EXPR",
        operator = "not",
        operand = {
            type = "BINARY_EXPR",
            operator = "==",
            left = {type = "IDENTIFIER", name = "a"},
            right = {type = "IDENTIFIER", name = "b"}
        }
    }
    local result = transpiler._transpile_unary(ctx, node)
    assert_eq(result, "(not (a == b))", "unary not on expression")
end
-- }}}

-- {{{ test: unknown unary operator
do
    local ctx = create_context()
    local node = {
        type = "UNARY_EXPR",
        operator = "~",
        operand = {type = "IDENTIFIER", name = "x"}
    }
    local result = transpiler._transpile_unary(ctx, node)
    assert_eq(result, "x", "unknown unary operator returns operand")
    assert_eq(#ctx.errors, 1, "unknown unary operator logs error")
end
-- }}}

-- ============================================================================
-- Function Call Expression Tests
-- ============================================================================

print("--- Function Call Expression Tests ---")

-- {{{ test: user function call no args
do
    local ctx = create_context()
    ctx.functions["MyFunc"] = {params = {}, return_type = "nothing"}
    local node = {
        type = "CALL_EXPR",
        callee = {type = "IDENTIFIER", name = "MyFunc"},
        arguments = {}
    }
    local result = transpiler._transpile_call_expr(ctx, node)
    assert_eq(result, "MyFunc()", "user function call no args")
end
-- }}}

-- {{{ test: user function call with args
do
    local ctx = create_context()
    ctx.functions["Add"] = {params = {}, return_type = "integer"}
    local node = {
        type = "CALL_EXPR",
        callee = {type = "IDENTIFIER", name = "Add"},
        arguments = {
            {type = "IDENTIFIER", name = "a"},
            {type = "IDENTIFIER", name = "b"}
        }
    }
    local result = transpiler._transpile_call_expr(ctx, node)
    assert_eq(result, "Add(a, b)", "user function call with args")
end
-- }}}

-- {{{ test: native function call (prefixed with runtime.)
do
    local ctx = create_context()
    ctx.natives["GetRandomInt"] = {params = {}, return_type = "integer"}
    local node = {
        type = "CALL_EXPR",
        callee = {type = "IDENTIFIER", name = "GetRandomInt"},
        arguments = {
            {type = "LITERAL", literal_type = "integer", value = 1},
            {type = "LITERAL", literal_type = "integer", value = 10}
        }
    }
    local result = transpiler._transpile_call_expr(ctx, node)
    assert_eq(result, "runtime.GetRandomInt(1, 10)", "native call prefixed with runtime.")
end
-- }}}

-- {{{ test: native function call no args
do
    local ctx = create_context()
    ctx.natives["GetLocalPlayer"] = {params = {}, return_type = "player"}
    local node = {
        type = "CALL_EXPR",
        callee = {type = "IDENTIFIER", name = "GetLocalPlayer"},
        arguments = {}
    }
    local result = transpiler._transpile_call_expr(ctx, node)
    assert_eq(result, "runtime.GetLocalPlayer()", "native call no args")
end
-- }}}

-- {{{ test: nested function calls
do
    local ctx = create_context()
    ctx.natives["CreateUnit"] = {params = {}, return_type = "unit"}
    ctx.natives["Player"] = {params = {}, return_type = "player"}
    local node = {
        type = "CALL_EXPR",
        callee = {type = "IDENTIFIER", name = "CreateUnit"},
        arguments = {
            {
                type = "CALL_EXPR",
                callee = {type = "IDENTIFIER", name = "Player"},
                arguments = {{type = "LITERAL", literal_type = "integer", value = 0}}
            },
            {type = "LITERAL", literal_type = "rawcode", value = "hfoo"}
        }
    }
    local result = transpiler._transpile_call_expr(ctx, node)
    assert_eq(result, "runtime.CreateUnit(runtime.Player(0), 1751543663)", "nested function calls")
end
-- }}}

-- ============================================================================
-- Array Access Tests
-- ============================================================================

print("--- Array Access Tests ---")

-- {{{ test: simple array access
do
    local ctx = create_context()
    local node = {
        type = "ARRAY_ACCESS",
        array = {type = "IDENTIFIER", name = "arr"},
        index = {type = "LITERAL", literal_type = "integer", value = 0}
    }
    local result = transpiler._transpile_array_access(ctx, node)
    assert_eq(result, "arr[0]", "simple array access")
end
-- }}}

-- {{{ test: array access with variable index
do
    local ctx = create_context()
    local node = {
        type = "ARRAY_ACCESS",
        array = {type = "IDENTIFIER", name = "data"},
        index = {type = "IDENTIFIER", name = "i"}
    }
    local result = transpiler._transpile_array_access(ctx, node)
    assert_eq(result, "data[i]", "array access with variable index")
end
-- }}}

-- {{{ test: array access with expression index
do
    local ctx = create_context()
    local node = {
        type = "ARRAY_ACCESS",
        array = {type = "IDENTIFIER", name = "arr"},
        index = {
            type = "BINARY_EXPR",
            operator = "+",
            left = {type = "IDENTIFIER", name = "i"},
            right = {type = "LITERAL", literal_type = "integer", value = 1}
        }
    }
    local result = transpiler._transpile_array_access(ctx, node)
    assert_eq(result, "arr[(i + 1)]", "array access with expression index")
end
-- }}}

-- ============================================================================
-- Main Expression Dispatcher Tests
-- ============================================================================

print("--- Main Expression Dispatcher Tests ---")

-- {{{ test: identifier expression
do
    local ctx = create_context()
    local node = {type = "IDENTIFIER", name = "myVar"}
    local result = transpiler._transpile_expr(ctx, node)
    assert_eq(result, "myVar", "identifier expression")
end
-- }}}

-- {{{ test: function reference expression
do
    local ctx = create_context()
    local node = {type = "FUNCTION_REF", name = "MyCallback"}
    local result = transpiler._transpile_expr(ctx, node)
    assert_eq(result, "MyCallback", "function reference expression")
end
-- }}}

-- {{{ test: nil node
do
    local ctx = create_context()
    local result = transpiler._transpile_expr(ctx, nil)
    assert_eq(result, "nil", "nil node returns nil")
    assert_eq(#ctx.errors, 1, "nil node logs error")
end
-- }}}

-- {{{ test: unknown expression type
do
    local ctx = create_context()
    local node = {type = "UNKNOWN_TYPE", value = "x"}
    local result = transpiler._transpile_expr(ctx, node)
    assert_eq(result, "nil", "unknown type returns nil")
    assert_eq(#ctx.errors, 1, "unknown type logs error")
end
-- }}}

-- ============================================================================
-- Integration Tests - Full Source Transpilation
-- ============================================================================

print("--- Integration Tests ---")

-- {{{ test: global with integer initializer
do
    local output = parse_and_transpile([[
globals
    integer x = 42
endglobals
]])
    assert_contains(output, "local x = 42", "global with integer initializer")
end
-- }}}

-- {{{ test: global with real initializer
do
    local output = parse_and_transpile([[
globals
    real pi = 3.14
endglobals
]])
    assert_contains(output, "local pi = 3.14", "global with real initializer")
end
-- }}}

-- {{{ test: global with string initializer
do
    local output = parse_and_transpile([[
globals
    string msg = "hello"
endglobals
]])
    assert_contains(output, 'local msg = "hello"', "global with string initializer")
end
-- }}}

-- {{{ test: global with boolean initializer
do
    local output = parse_and_transpile([[
globals
    boolean flag = true
endglobals
]])
    assert_contains(output, "local flag = true", "global with boolean initializer")
end
-- }}}

-- {{{ test: function with expression body
do
    local output = parse_and_transpile([[
function Add takes integer a, integer b returns integer
    return a + b
endfunction
]])
    -- Note: return statement transpilation is still a stub in 306c
    -- We're testing that expression parsing doesn't break the transpile
    assert_contains(output, "local function Add(a, b)", "function with expression parses")
end
-- }}}

-- {{{ test: local with expression initializer
do
    local output = parse_and_transpile([[
function Test takes nothing returns nothing
    local integer x = 5 + 3
endfunction
]])
    assert_contains(output, "local x = (5 + 3)", "local with binary expression initializer")
end
-- }}}

-- {{{ test: complex binary expression
do
    local output = parse_and_transpile([[
globals
    integer result = 1 + 2 * 3
endglobals
]])
    -- Parser handles precedence, transpiler wraps in parens
    assert_contains(output, "local result =", "complex expression transpiles")
end
-- }}}

-- {{{ test: comparison in local initializer
do
    local output = parse_and_transpile([[
function Test takes nothing returns nothing
    local boolean b = x != 0
endfunction
]])
    assert_contains(output, "~=", "!= becomes ~= in transpiled output")
end
-- }}}

-- ============================================================================
-- Nested Expression Tests
-- ============================================================================

print("--- Nested Expression Tests ---")

-- {{{ test: nested binary expressions
do
    local ctx = create_context()
    -- (a + b) * c
    local node = {
        type = "BINARY_EXPR",
        operator = "*",
        left = {
            type = "BINARY_EXPR",
            operator = "+",
            left = {type = "IDENTIFIER", name = "a"},
            right = {type = "IDENTIFIER", name = "b"}
        },
        right = {type = "IDENTIFIER", name = "c"}
    }
    local result = transpiler._transpile_expr(ctx, node)
    assert_eq(result, "((a + b) * c)", "nested binary expressions")
end
-- }}}

-- {{{ test: deeply nested expressions
do
    local ctx = create_context()
    -- not (a == b and c != d)
    local node = {
        type = "UNARY_EXPR",
        operator = "not",
        operand = {
            type = "BINARY_EXPR",
            operator = "and",
            left = {
                type = "BINARY_EXPR",
                operator = "==",
                left = {type = "IDENTIFIER", name = "a"},
                right = {type = "IDENTIFIER", name = "b"}
            },
            right = {
                type = "BINARY_EXPR",
                operator = "!=",
                left = {type = "IDENTIFIER", name = "c"},
                right = {type = "IDENTIFIER", name = "d"}
            }
        }
    }
    local result = transpiler._transpile_expr(ctx, node)
    assert_eq(result, "(not ((a == b) and (c ~= d)))", "deeply nested expressions")
end
-- }}}

-- {{{ test: function call with expression arguments
do
    local ctx = create_context()
    ctx.natives["Print"] = {params = {}, return_type = "nothing"}
    local node = {
        type = "CALL_EXPR",
        callee = {type = "IDENTIFIER", name = "Print"},
        arguments = {
            {
                type = "BINARY_EXPR",
                operator = "+",
                left = {type = "LITERAL", literal_type = "string", value = "Value: "},
                right = {type = "IDENTIFIER", name = "x"}
            }
        }
    }
    local result = transpiler._transpile_expr(ctx, node)
    assert_eq(result, 'runtime.Print(("Value: " .. x))', "function call with string concat")
end
-- }}}

-- ============================================================================
-- Summary
-- ============================================================================

print("")
print(string.format("=== Results: %d/%d tests passed ===", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print(string.format("FAILED: %d tests failed", tests_run - tests_passed))
    os.exit(1)
end
