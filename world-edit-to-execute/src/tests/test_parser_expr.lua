--[[
Test: JASS Parser Expression Parsing (305c)

Tests expression parsing with operator precedence:
- Primary expressions (literals, identifiers, parens, function refs)
- Unary operators (-, not) with right-associativity
- Binary operators with correct precedence
- Left-associativity of binary operators
- Function calls and array access
- can_start_expression helper
]]

package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local lexer = require("jass.lexer")
local parser = require("jass.parser")
local TOKEN = lexer.TOKEN
local AST = parser.AST

local tests_run = 0
local tests_passed = 0

-- {{{ test helper
local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print(string.format("  [PASS] %s", name))
    else
        print(string.format("  [FAIL] %s: %s", name, err))
    end
end
-- }}}

-- {{{ assert helpers
local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", msg or "assertion failed",
            tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "expected true")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "expected false")
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "expected non-nil")
    end
end
-- }}}

-- {{{ helper: parse expression from source
local function parse_expr(source)
    local tokens = lexer.tokenize(source)
    local state = parser.create_state(tokens)
    return parser.parse_expression(state), state
end
-- }}}

print("=== JASS Parser Expression Tests ===\n")

-- {{{ Primary expression tests
print("-- Primary expressions --")

test("identifier", function()
    local expr = parse_expr("foo")
    assert_eq(AST.IDENTIFIER, expr.type)
    assert_eq("foo", expr.name)
end)

test("boolean true", function()
    local expr = parse_expr("true")
    assert_eq(AST.LITERAL, expr.type)
    assert_eq("boolean", expr.literal_type)
    assert_eq(true, expr.value)
end)

test("boolean false", function()
    local expr = parse_expr("false")
    assert_eq(AST.LITERAL, expr.type)
    assert_eq("boolean", expr.literal_type)
    assert_eq(false, expr.value)
end)

test("null literal", function()
    local expr = parse_expr("null")
    assert_eq(AST.LITERAL, expr.type)
    assert_eq("null", expr.literal_type)
    assert_eq(nil, expr.value)
end)

test("parenthesized expression", function()
    local expr = parse_expr("(foo)")
    assert_eq(AST.IDENTIFIER, expr.type)
    assert_eq("foo", expr.name)
end)

test("nested parentheses", function()
    local expr = parse_expr("((foo))")
    assert_eq(AST.IDENTIFIER, expr.type)
    assert_eq("foo", expr.name)
end)

test("function reference", function()
    local expr = parse_expr("function MyFunc")
    assert_eq(AST.FUNCTION_REF, expr.type)
    assert_eq("MyFunc", expr.name)
end)
-- }}}

-- {{{ Unary operator tests
print("\n-- Unary operators --")

test("unary minus", function()
    local expr = parse_expr("-foo")
    assert_eq(AST.UNARY_EXPR, expr.type)
    assert_eq("-", expr.operator)
    assert_eq(AST.IDENTIFIER, expr.operand.type)
    assert_eq("foo", expr.operand.name)
end)

test("unary not", function()
    local expr = parse_expr("not foo")
    assert_eq(AST.UNARY_EXPR, expr.type)
    assert_eq("not", expr.operator)
    assert_eq(AST.IDENTIFIER, expr.operand.type)
end)

test("chained unary minus (right-associative)", function()
    -- --x should be -(-x)
    local expr = parse_expr("--foo")
    assert_eq(AST.UNARY_EXPR, expr.type)
    assert_eq("-", expr.operator)
    assert_eq(AST.UNARY_EXPR, expr.operand.type)
    assert_eq("-", expr.operand.operator)
    assert_eq("foo", expr.operand.operand.name)
end)

test("chained not (right-associative)", function()
    local expr = parse_expr("not not foo")
    assert_eq(AST.UNARY_EXPR, expr.type)
    assert_eq("not", expr.operator)
    assert_eq(AST.UNARY_EXPR, expr.operand.type)
    assert_eq("not", expr.operand.operator)
end)

test("unary minus with parentheses", function()
    local expr = parse_expr("-(foo)")
    assert_eq(AST.UNARY_EXPR, expr.type)
    assert_eq("-", expr.operator)
    assert_eq(AST.IDENTIFIER, expr.operand.type)
end)
-- }}}

-- {{{ Binary operator tests - basic
print("\n-- Binary operators (basic) --")

test("addition", function()
    local expr = parse_expr("a + b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("+", expr.operator)
    assert_eq("a", expr.left.name)
    assert_eq("b", expr.right.name)
end)

test("subtraction", function()
    local expr = parse_expr("a - b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("-", expr.operator)
end)

test("multiplication", function()
    local expr = parse_expr("a * b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("*", expr.operator)
end)

test("division", function()
    local expr = parse_expr("a / b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("/", expr.operator)
end)

test("equality", function()
    local expr = parse_expr("a == b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("==", expr.operator)
end)

test("not equals", function()
    local expr = parse_expr("a != b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("!=", expr.operator)
end)

test("less than", function()
    local expr = parse_expr("a < b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("<", expr.operator)
end)

test("less equals", function()
    local expr = parse_expr("a <= b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("<=", expr.operator)
end)

test("greater than", function()
    local expr = parse_expr("a > b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq(">", expr.operator)
end)

test("greater equals", function()
    local expr = parse_expr("a >= b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq(">=", expr.operator)
end)

test("and operator", function()
    local expr = parse_expr("a and b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("and", expr.operator)
end)

test("or operator", function()
    local expr = parse_expr("a or b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("or", expr.operator)
end)
-- }}}

-- {{{ Precedence tests
print("\n-- Operator precedence --")

test("* binds tighter than +", function()
    -- a + b * c should be a + (b * c)
    local expr = parse_expr("a + b * c")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("+", expr.operator)
    assert_eq("a", expr.left.name)
    assert_eq(AST.BINARY_EXPR, expr.right.type)
    assert_eq("*", expr.right.operator)
end)

test("+ binds tighter than comparison", function()
    -- a < b + c should be a < (b + c)
    local expr = parse_expr("a < b + c")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("<", expr.operator)
    assert_eq("a", expr.left.name)
    assert_eq("+", expr.right.operator)
end)

test("comparison binds tighter than and", function()
    -- a and b < c should be a and (b < c)
    local expr = parse_expr("a and b < c")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("and", expr.operator)
    assert_eq("a", expr.left.name)
    assert_eq("<", expr.right.operator)
end)

test("and binds tighter than or", function()
    -- a or b and c should be a or (b and c)
    local expr = parse_expr("a or b and c")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("or", expr.operator)
    assert_eq("a", expr.left.name)
    assert_eq("and", expr.right.operator)
end)

test("unary minus binds tighter than *", function()
    -- -a * b should be (-a) * b
    local expr = parse_expr("-a * b")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("*", expr.operator)
    assert_eq(AST.UNARY_EXPR, expr.left.type)
    assert_eq("-", expr.left.operator)
end)

test("complex precedence: a + b * c < d and e or f", function()
    -- Should be: ((a + (b * c)) < d) and e) or f
    -- Actually: (((a + (b * c)) < d) and e) or f
    local expr = parse_expr("a + b * c < d and e or f")
    assert_eq("or", expr.operator)
    assert_eq("f", expr.right.name)
    assert_eq("and", expr.left.operator)
end)

test("parentheses override precedence", function()
    -- (a + b) * c should be (a + b) * c
    local expr = parse_expr("(a + b) * c")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("*", expr.operator)
    assert_eq(AST.BINARY_EXPR, expr.left.type)
    assert_eq("+", expr.left.operator)
end)
-- }}}

-- {{{ Left-associativity tests
print("\n-- Left-associativity --")

test("a + b + c is (a + b) + c", function()
    local expr = parse_expr("a + b + c")
    assert_eq(AST.BINARY_EXPR, expr.type)
    assert_eq("+", expr.operator)
    assert_eq("c", expr.right.name)
    assert_eq(AST.BINARY_EXPR, expr.left.type)
    assert_eq("+", expr.left.operator)
    assert_eq("a", expr.left.left.name)
    assert_eq("b", expr.left.right.name)
end)

test("a * b * c is (a * b) * c", function()
    local expr = parse_expr("a * b * c")
    assert_eq("*", expr.operator)
    assert_eq("c", expr.right.name)
    assert_eq("*", expr.left.operator)
end)

test("a - b - c is (a - b) - c", function()
    local expr = parse_expr("a - b - c")
    assert_eq("-", expr.operator)
    assert_eq("c", expr.right.name)
    assert_eq("-", expr.left.operator)
end)

test("a < b < c is (a < b) < c", function()
    local expr = parse_expr("a < b < c")
    assert_eq("<", expr.operator)
    assert_eq("c", expr.right.name)
    assert_eq("<", expr.left.operator)
end)

test("a and b and c is (a and b) and c", function()
    local expr = parse_expr("a and b and c")
    assert_eq("and", expr.operator)
    assert_eq("c", expr.right.name)
    assert_eq("and", expr.left.operator)
end)

test("a or b or c is (a or b) or c", function()
    local expr = parse_expr("a or b or c")
    assert_eq("or", expr.operator)
    assert_eq("c", expr.right.name)
    assert_eq("or", expr.left.operator)
end)
-- }}}

-- {{{ Function call tests
print("\n-- Function calls --")

test("function call no args", function()
    local expr = parse_expr("foo()")
    assert_eq(AST.CALL_EXPR, expr.type)
    assert_eq(AST.IDENTIFIER, expr.callee.type)
    assert_eq("foo", expr.callee.name)
    assert_eq(0, #expr.arguments)
end)

test("function call one arg", function()
    local expr = parse_expr("foo(a)")
    assert_eq(AST.CALL_EXPR, expr.type)
    assert_eq(1, #expr.arguments)
    assert_eq("a", expr.arguments[1].name)
end)

test("function call multiple args", function()
    local expr = parse_expr("foo(a, b, c)")
    assert_eq(AST.CALL_EXPR, expr.type)
    assert_eq(3, #expr.arguments)
    assert_eq("a", expr.arguments[1].name)
    assert_eq("b", expr.arguments[2].name)
    assert_eq("c", expr.arguments[3].name)
end)

test("function call with expression args", function()
    local expr = parse_expr("foo(a + b, c * d)")
    assert_eq(AST.CALL_EXPR, expr.type)
    assert_eq(2, #expr.arguments)
    assert_eq("+", expr.arguments[1].operator)
    assert_eq("*", expr.arguments[2].operator)
end)

test("nested function calls", function()
    local expr = parse_expr("foo(bar(x))")
    assert_eq(AST.CALL_EXPR, expr.type)
    assert_eq(1, #expr.arguments)
    assert_eq(AST.CALL_EXPR, expr.arguments[1].type)
    assert_eq("bar", expr.arguments[1].callee.name)
end)

test("chained function calls", function()
    -- This is unusual in JASS but parser handles it
    local expr = parse_expr("foo()()")
    assert_eq(AST.CALL_EXPR, expr.type)
    assert_eq(AST.CALL_EXPR, expr.callee.type)
end)
-- }}}

-- {{{ Array access tests
print("\n-- Array access --")

test("simple array access", function()
    local expr = parse_expr("arr[i]")
    assert_eq(AST.ARRAY_ACCESS, expr.type)
    assert_eq(AST.IDENTIFIER, expr.array.type)
    assert_eq("arr", expr.array.name)
    assert_eq(AST.IDENTIFIER, expr.index.type)
    assert_eq("i", expr.index.name)
end)

test("array access with expression index", function()
    local expr = parse_expr("arr[i + j]")
    assert_eq(AST.ARRAY_ACCESS, expr.type)
    assert_eq(AST.BINARY_EXPR, expr.index.type)
    assert_eq("+", expr.index.operator)
end)

test("chained array access", function()
    local expr = parse_expr("arr[i][j]")
    assert_eq(AST.ARRAY_ACCESS, expr.type)
    assert_eq(AST.ARRAY_ACCESS, expr.array.type)
end)

test("array access then function call", function()
    local expr = parse_expr("arr[i]()")
    assert_eq(AST.CALL_EXPR, expr.type)
    assert_eq(AST.ARRAY_ACCESS, expr.callee.type)
end)

test("function call then array access", function()
    local expr = parse_expr("foo()[i]")
    assert_eq(AST.ARRAY_ACCESS, expr.type)
    assert_eq(AST.CALL_EXPR, expr.array.type)
end)
-- }}}

-- {{{ Mixed expression tests
print("\n-- Mixed expressions --")

test("unary in binary expression", function()
    local expr = parse_expr("a + -b")
    assert_eq("+", expr.operator)
    assert_eq(AST.UNARY_EXPR, expr.right.type)
    assert_eq("-", expr.right.operator)
end)

test("function call in binary expression", function()
    local expr = parse_expr("foo(a) + bar(b)")
    assert_eq("+", expr.operator)
    assert_eq(AST.CALL_EXPR, expr.left.type)
    assert_eq(AST.CALL_EXPR, expr.right.type)
end)

test("array access in comparison", function()
    local expr = parse_expr("arr[i] < arr[j]")
    assert_eq("<", expr.operator)
    assert_eq(AST.ARRAY_ACCESS, expr.left.type)
    assert_eq(AST.ARRAY_ACCESS, expr.right.type)
end)

test("complex expression: foo(a + b) * arr[c and d]", function()
    local expr = parse_expr("foo(a + b) * arr[c and d]")
    assert_eq("*", expr.operator)
    assert_eq(AST.CALL_EXPR, expr.left.type)
    assert_eq(AST.ARRAY_ACCESS, expr.right.type)
end)

test("not with comparison", function()
    local expr = parse_expr("not a == b")
    -- "not a == b" parses as "(not a) == b" due to precedence
    assert_eq("==", expr.operator)
    assert_eq(AST.UNARY_EXPR, expr.left.type)
    assert_eq("not", expr.left.operator)
end)
-- }}}

-- {{{ can_start_expression tests
print("\n-- can_start_expression --")

test("can_start_expression true for identifier", function()
    local tokens = lexer.tokenize("foo")
    local state = parser.create_state(tokens)
    assert_true(parser.can_start_expression(state))
end)

test("can_start_expression true for minus", function()
    local tokens = lexer.tokenize("-foo")
    local state = parser.create_state(tokens)
    assert_true(parser.can_start_expression(state))
end)

test("can_start_expression true for not", function()
    local tokens = lexer.tokenize("not foo")
    local state = parser.create_state(tokens)
    assert_true(parser.can_start_expression(state))
end)

test("can_start_expression true for true", function()
    local tokens = lexer.tokenize("true")
    local state = parser.create_state(tokens)
    assert_true(parser.can_start_expression(state))
end)

test("can_start_expression true for lparen", function()
    local tokens = lexer.tokenize("(foo)")
    local state = parser.create_state(tokens)
    assert_true(parser.can_start_expression(state))
end)

test("can_start_expression true for function keyword", function()
    local tokens = lexer.tokenize("function Foo")
    local state = parser.create_state(tokens)
    assert_true(parser.can_start_expression(state))
end)

test("can_start_expression false for set keyword", function()
    local tokens = lexer.tokenize("set x")
    local state = parser.create_state(tokens)
    assert_false(parser.can_start_expression(state))
end)

test("can_start_expression false for newline", function()
    local tokens = lexer.tokenize("\n")
    local state = parser.create_state(tokens)
    assert_false(parser.can_start_expression(state))
end)
-- }}}

-- {{{ Error handling tests
print("\n-- Error handling --")

test("missing closing paren records error", function()
    local tokens = lexer.tokenize("(foo")
    local state = parser.create_state(tokens)
    local expr = parser.parse_expression(state)
    assert_true(#state.errors > 0, "should have errors")
    assert_true(state.errors[1].message:find("Expected ')'"), "error message")
end)

test("missing closing bracket records error", function()
    local tokens = lexer.tokenize("arr[i")
    local state = parser.create_state(tokens)
    local expr = parser.parse_expression(state)
    assert_true(#state.errors > 0, "should have errors")
end)

test("unexpected token records error", function()
    local tokens = lexer.tokenize("set")  -- set can't start expression
    local state = parser.create_state(tokens)
    local expr = parser.parse_expression(state)
    assert_true(#state.errors > 0, "should have errors")
end)
-- }}}

-- {{{ Summary
print("\n=== Results ===")
print(string.format("Passed: %d/%d", tests_passed, tests_run))

if tests_passed == tests_run then
    print("\nAll tests passed!")
    os.exit(0)
else
    print("\nSome tests failed.")
    os.exit(1)
end
-- }}}
