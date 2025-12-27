--[[
Test: JASS Parser Infrastructure (305a)

Tests the foundational parser module:
- Parser state creation
- Token inspection helpers (at_end, peek, previous, check, check_any)
- Token consumption helpers (advance, match, match_any, consume)
- Error reporting (error_at, error_at_current, format_error)
- Error recovery (synchronize)
- AST node creation (make_node)
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

local function assert_nil(value, msg)
    if value ~= nil then
        error(msg or "expected nil")
    end
end
-- }}}

-- {{{ helper: tokenize and create parser state
local function make_state(source)
    local tokens = lexer.tokenize(source)
    return parser.create_state(tokens)
end
-- }}}

print("=== JASS Parser Infrastructure Tests ===\n")

-- {{{ AST node type tests
print("-- AST node types --")

test("AST table has top-level types", function()
    assert_eq("PROGRAM", AST.PROGRAM)
    assert_eq("TYPE_DEF", AST.TYPE_DEF)
    assert_eq("GLOBAL_BLOCK", AST.GLOBAL_BLOCK)
    assert_eq("VAR_DECL", AST.VAR_DECL)
    assert_eq("NATIVE_DECL", AST.NATIVE_DECL)
    assert_eq("FUNCTION_DEF", AST.FUNCTION_DEF)
end)

test("AST table has statement types", function()
    assert_eq("SET_STMT", AST.SET_STMT)
    assert_eq("CALL_STMT", AST.CALL_STMT)
    assert_eq("IF_STMT", AST.IF_STMT)
    assert_eq("LOOP_STMT", AST.LOOP_STMT)
    assert_eq("EXITWHEN_STMT", AST.EXITWHEN_STMT)
    assert_eq("RETURN_STMT", AST.RETURN_STMT)
    assert_eq("LOCAL_DECL", AST.LOCAL_DECL)
end)

test("AST table has expression types", function()
    assert_eq("BINARY_EXPR", AST.BINARY_EXPR)
    assert_eq("UNARY_EXPR", AST.UNARY_EXPR)
    assert_eq("CALL_EXPR", AST.CALL_EXPR)
    assert_eq("ARRAY_ACCESS", AST.ARRAY_ACCESS)
    assert_eq("IDENTIFIER", AST.IDENTIFIER)
    assert_eq("LITERAL", AST.LITERAL)
    assert_eq("FUNCTION_REF", AST.FUNCTION_REF)
end)
-- }}}

-- {{{ create_state tests
print("\n-- create_state --")

test("create_state creates valid state", function()
    local state = make_state("x")
    assert_eq(1, state.pos, "initial position")
    assert_eq(0, #state.errors, "no errors")
    assert_true(#state.tokens > 0, "has tokens")
end)

test("state has tokens array", function()
    local state = make_state("foo bar")
    assert_eq(3, #state.tokens, "token count (foo, bar, EOF)")
end)
-- }}}

-- {{{ at_end tests
print("\n-- at_end --")

test("at_end false at start", function()
    local state = make_state("x")
    assert_false(parser.at_end(state))
end)

test("at_end true after consuming all", function()
    local state = make_state("x")
    parser.advance(state)  -- consume 'x'
    assert_true(parser.at_end(state))
end)

test("at_end true on EOF token", function()
    local tokens = lexer.tokenize("")  -- just EOF
    local state = parser.create_state(tokens)
    assert_true(parser.at_end(state))
end)
-- }}}

-- {{{ peek tests
print("\n-- peek --")

test("peek returns current token", function()
    local state = make_state("foo")
    local token = parser.peek(state)
    assert_eq(TOKEN.IDENTIFIER, token.type)
    assert_eq("foo", token.value)
end)

test("peek doesn't advance", function()
    local state = make_state("foo")
    parser.peek(state)
    parser.peek(state)
    assert_eq(1, state.pos, "position unchanged")
end)
-- }}}

-- {{{ peek_next tests
print("\n-- peek_next --")

test("peek_next returns next token", function()
    local state = make_state("foo bar")
    local next_token = parser.peek_next(state)
    assert_eq(TOKEN.IDENTIFIER, next_token.type)
    assert_eq("bar", next_token.value)
end)

test("peek_next returns nil at end", function()
    local state = make_state("x")
    parser.advance(state)  -- now at EOF
    assert_nil(parser.peek_next(state))
end)
-- }}}

-- {{{ previous tests
print("\n-- previous --")

test("previous returns consumed token", function()
    local state = make_state("foo bar")
    parser.advance(state)  -- consume 'foo'
    local prev = parser.previous(state)
    assert_eq(TOKEN.IDENTIFIER, prev.type)
    assert_eq("foo", prev.value)
end)
-- }}}

-- {{{ check tests
print("\n-- check --")

test("check returns true for matching type", function()
    local state = make_state("function")
    assert_true(parser.check(state, TOKEN.FUNCTION))
end)

test("check returns false for non-matching type", function()
    local state = make_state("function")
    assert_false(parser.check(state, TOKEN.IF))
end)

test("check returns false at end", function()
    local state = make_state("")
    assert_false(parser.check(state, TOKEN.FUNCTION))
end)

test("check doesn't consume token", function()
    local state = make_state("function")
    parser.check(state, TOKEN.FUNCTION)
    assert_eq(1, state.pos, "position unchanged")
end)
-- }}}

-- {{{ check_any tests
print("\n-- check_any --")

test("check_any returns true for first match", function()
    local state = make_state("if")
    assert_true(parser.check_any(state, TOKEN.IF, TOKEN.ELSE, TOKEN.ENDIF))
end)

test("check_any returns true for middle match", function()
    local state = make_state("else")
    assert_true(parser.check_any(state, TOKEN.IF, TOKEN.ELSE, TOKEN.ENDIF))
end)

test("check_any returns false for no match", function()
    local state = make_state("loop")
    assert_false(parser.check_any(state, TOKEN.IF, TOKEN.ELSE, TOKEN.ENDIF))
end)
-- }}}

-- {{{ advance tests
print("\n-- advance --")

test("advance returns consumed token", function()
    local state = make_state("foo")
    local token = parser.advance(state)
    assert_eq(TOKEN.IDENTIFIER, token.type)
    assert_eq("foo", token.value)
end)

test("advance increments position", function()
    local state = make_state("foo bar")
    assert_eq(1, state.pos)
    parser.advance(state)
    assert_eq(2, state.pos)
end)

test("advance doesn't go past end", function()
    local state = make_state("x")
    parser.advance(state)  -- consume 'x'
    parser.advance(state)  -- at EOF, shouldn't crash
    assert_true(state.pos <= #state.tokens + 1)
end)
-- }}}

-- {{{ match tests
print("\n-- match --")

test("match returns true and advances on match", function()
    local state = make_state("function")
    assert_true(parser.match(state, TOKEN.FUNCTION))
    assert_eq(2, state.pos, "position advanced")
end)

test("match returns false and doesn't advance on mismatch", function()
    local state = make_state("function")
    assert_false(parser.match(state, TOKEN.IF))
    assert_eq(1, state.pos, "position unchanged")
end)
-- }}}

-- {{{ match_any tests
print("\n-- match_any --")

test("match_any returns true for matching type", function()
    local state = make_state("if")
    assert_true(parser.match_any(state, TOKEN.IF, TOKEN.ELSE))
    assert_eq(2, state.pos, "position advanced")
end)

test("match_any returns false for no match", function()
    local state = make_state("loop")
    assert_false(parser.match_any(state, TOKEN.IF, TOKEN.ELSE))
    assert_eq(1, state.pos, "position unchanged")
end)
-- }}}

-- {{{ consume tests
print("\n-- consume --")

test("consume returns token on match", function()
    local state = make_state("function foo")
    local token = parser.consume(state, TOKEN.FUNCTION, "Expected function")
    assert_eq(TOKEN.FUNCTION, token.type)
    assert_eq(2, state.pos, "position advanced")
end)

test("consume returns nil and records error on mismatch", function()
    local state = make_state("if")
    local token = parser.consume(state, TOKEN.FUNCTION, "Expected function")
    assert_nil(token)
    assert_eq(1, #state.errors, "error recorded")
    assert_eq("Expected function", state.errors[1].message)
end)

test("consume error has location info", function()
    local state = make_state("   if")  -- 'if' at column 4
    parser.consume(state, TOKEN.FUNCTION, "Expected function")
    assert_eq(1, state.errors[1].line)
    assert_eq(4, state.errors[1].col)
end)
-- }}}

-- {{{ error_at tests
print("\n-- error_at --")

test("error_at records error with message", function()
    local state = make_state("x")
    local token = parser.peek(state)
    parser.error_at(state, token, "test error")
    assert_eq(1, #state.errors)
    assert_eq("test error", state.errors[1].message)
end)

test("error_at records token info", function()
    local state = make_state("foo")
    local token = parser.peek(state)
    parser.error_at(state, token, "error")
    assert_eq(TOKEN.IDENTIFIER, state.errors[1].token_type)
    assert_eq("foo", state.errors[1].token_value)
end)
-- }}}

-- {{{ error_at_current tests
print("\n-- error_at_current --")

test("error_at_current uses current token", function()
    local state = make_state("foo bar")
    parser.advance(state)  -- now at 'bar'
    parser.error_at_current(state, "error at bar")
    assert_eq("bar", state.errors[1].token_value)
end)
-- }}}

-- {{{ error_at_previous tests
print("\n-- error_at_previous --")

test("error_at_previous uses previous token", function()
    local state = make_state("foo bar")
    parser.advance(state)  -- consume 'foo'
    parser.error_at_previous(state, "error at foo")
    assert_eq("foo", state.errors[1].token_value)
end)
-- }}}

-- {{{ format_error tests
print("\n-- format_error --")

test("format_error produces readable output", function()
    local err = {message = "test", line = 5, col = 10}
    local formatted = parser.format_error(err)
    assert_true(formatted:find("Line 5"), "contains line")
    assert_true(formatted:find("Column 10"), "contains column")
    assert_true(formatted:find("test"), "contains message")
end)
-- }}}

-- {{{ has_errors tests
print("\n-- has_errors --")

test("has_errors false initially", function()
    local state = make_state("x")
    assert_false(parser.has_errors(state))
end)

test("has_errors true after error", function()
    local state = make_state("x")
    parser.error_at_current(state, "error")
    assert_true(parser.has_errors(state))
end)
-- }}}

-- {{{ get_errors tests
print("\n-- get_errors --")

test("get_errors returns formatted errors", function()
    local state = make_state("x")
    parser.error_at_current(state, "first error")
    parser.error_at_current(state, "second error")
    local errors = parser.get_errors(state)
    assert_eq(2, #errors)
    assert_true(errors[1]:find("first error"))
    assert_true(errors[2]:find("second error"))
end)
-- }}}

-- {{{ synchronize tests
print("\n-- synchronize --")

test("synchronize stops at function keyword", function()
    local state = make_state("x y z function foo")
    parser.synchronize(state)
    assert_eq(TOKEN.FUNCTION, parser.peek(state).type)
end)

test("synchronize stops at set keyword", function()
    local state = make_state("x y set foo")
    parser.synchronize(state)
    assert_eq(TOKEN.SET, parser.peek(state).type)
end)

test("synchronize stops at if keyword", function()
    local state = make_state("x if y")
    parser.synchronize(state)
    assert_eq(TOKEN.IF, parser.peek(state).type)
end)

test("synchronize stops at loop keyword", function()
    local state = make_state("x loop y")
    parser.synchronize(state)
    assert_eq(TOKEN.LOOP, parser.peek(state).type)
end)

test("synchronize stops at end of file", function()
    local state = make_state("x y z")
    parser.synchronize(state)
    assert_true(parser.at_end(state))
end)

test("synchronize handles endfunction", function()
    local state = make_state("x endfunction")
    parser.synchronize(state)
    assert_eq(TOKEN.ENDFUNCTION, parser.peek(state).type)
end)

test("synchronize handles globals", function()
    local state = make_state("x globals")
    parser.synchronize(state)
    assert_eq(TOKEN.GLOBALS, parser.peek(state).type)
end)
-- }}}

-- {{{ skip_newlines tests
print("\n-- skip_newlines --")

test("skip_newlines skips single newline", function()
    local state = make_state("x\ny")
    parser.advance(state)  -- consume 'x'
    parser.skip_newlines(state)
    assert_eq(TOKEN.IDENTIFIER, parser.peek(state).type)
    assert_eq("y", parser.peek(state).value)
end)

test("skip_newlines skips multiple newlines", function()
    local state = make_state("x\n\n\ny")
    parser.advance(state)  -- consume 'x'
    parser.skip_newlines(state)
    assert_eq("y", parser.peek(state).value)
end)

test("skip_newlines skips comments too", function()
    local state = make_state("x\n// comment\ny")
    parser.advance(state)  -- consume 'x'
    parser.skip_newlines(state)
    assert_eq("y", parser.peek(state).value)
end)

test("skip_newlines does nothing if no newlines", function()
    local state = make_state("x y")
    parser.advance(state)  -- consume 'x'
    local pos = state.pos
    parser.skip_newlines(state)
    assert_eq(pos, state.pos)
end)
-- }}}

-- {{{ make_node tests
print("\n-- make_node --")

test("make_node creates node with type", function()
    local node = parser.make_node(AST.FUNCTION_DEF, nil)
    assert_eq(AST.FUNCTION_DEF, node.type)
end)

test("make_node copies location from token", function()
    local state = make_state("   foo")  -- foo at column 4
    local token = parser.peek(state)
    local node = parser.make_node(AST.IDENTIFIER, token)
    assert_eq(1, node.line)
    assert_eq(4, node.col)
end)

test("make_node handles nil token", function()
    local node = parser.make_node(AST.PROGRAM, nil)
    assert_eq(0, node.line)
    assert_eq(0, node.col)
end)
-- }}}

-- {{{ Integration tests
print("\n-- Integration (realistic scenarios) --")

test("parsing pattern: match keyword then consume identifier", function()
    local state = make_state("function MyFunc")
    assert_true(parser.match(state, TOKEN.FUNCTION))
    local name = parser.consume(state, TOKEN.IDENTIFIER, "Expected function name")
    assert_eq("MyFunc", name.value)
end)

test("parsing pattern: error recovery", function()
    local state = make_state("bad bad bad function good")
    -- Simulate failed parse, then synchronize
    parser.error_at_current(state, "parse error")
    parser.synchronize(state)
    -- Now at 'function' keyword
    assert_true(parser.match(state, TOKEN.FUNCTION))
    assert_eq("good", parser.peek(state).value)
end)

test("parsing pattern: skip newlines in block", function()
    local state = make_state("function foo\n\nendfunction")
    parser.match(state, TOKEN.FUNCTION)
    parser.advance(state)  -- 'foo'
    parser.skip_newlines(state)
    assert_true(parser.check(state, TOKEN.ENDFUNCTION))
end)

test("multiple errors can be accumulated", function()
    local state = make_state("x y z")
    parser.error_at_current(state, "first")
    parser.advance(state)
    parser.error_at_current(state, "second")
    parser.advance(state)
    parser.error_at_current(state, "third")
    assert_eq(3, #state.errors)
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
