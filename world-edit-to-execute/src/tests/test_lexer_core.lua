--[[
Test: JASS Lexer Core Infrastructure (304a)

Tests the basic lexer functionality:
- Whitespace handling
- Comment recognition
- Newline token emission
- EOF token emission
- Position tracking
- Error handling for unknown characters
]]

package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local lexer = require("jass.lexer")
local TOKEN = lexer.TOKEN

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

-- {{{ assert helper
local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", msg or "assertion failed",
            tostring(expected), tostring(actual)))
    end
end
-- }}}

print("=== JASS Lexer Core Infrastructure Tests ===\n")

-- {{{ Empty input tests
print("-- Empty input --")

test("empty string returns only EOF", function()
    local tokens = lexer.tokenize("")
    assert_eq(1, #tokens, "token count")
    assert_eq(TOKEN.EOF, tokens[1].type, "token type")
end)

test("whitespace-only returns only EOF", function()
    local tokens = lexer.tokenize("   \t\t   ")
    assert_eq(1, #tokens, "token count")
    assert_eq(TOKEN.EOF, tokens[1].type, "token type")
end)
-- }}}

-- {{{ Newline tests
print("\n-- Newline handling --")

test("single newline emits NEWLINE token", function()
    local tokens = lexer.tokenize("\n")
    assert_eq(2, #tokens, "token count")
    assert_eq(TOKEN.NEWLINE, tokens[1].type, "first token type")
    assert_eq(TOKEN.EOF, tokens[2].type, "second token type")
end)

test("multiple newlines emit multiple NEWLINE tokens", function()
    local tokens = lexer.tokenize("\n\n\n")
    assert_eq(4, #tokens, "token count")
    assert_eq(TOKEN.NEWLINE, tokens[1].type, "token 1")
    assert_eq(TOKEN.NEWLINE, tokens[2].type, "token 2")
    assert_eq(TOKEN.NEWLINE, tokens[3].type, "token 3")
    assert_eq(TOKEN.EOF, tokens[4].type, "token 4")
end)

test("newline position tracking", function()
    local tokens = lexer.tokenize("\n\n")
    assert_eq(1, tokens[1].line, "first newline line")
    assert_eq(1, tokens[1].col, "first newline col")
    assert_eq(2, tokens[2].line, "second newline line")
    assert_eq(1, tokens[2].col, "second newline col")
end)
-- }}}

-- {{{ Comment tests
print("\n-- Comment handling --")

test("single comment", function()
    local tokens = lexer.tokenize("// hello world")
    assert_eq(2, #tokens, "token count")
    assert_eq(TOKEN.COMMENT, tokens[1].type, "token type")
    assert_eq(" hello world", tokens[1].value, "comment content")
end)

test("comment before newline", function()
    local tokens = lexer.tokenize("// comment\n")
    assert_eq(3, #tokens, "token count")
    assert_eq(TOKEN.COMMENT, tokens[1].type, "comment token")
    assert_eq(TOKEN.NEWLINE, tokens[2].type, "newline token")
    assert_eq(TOKEN.EOF, tokens[3].type, "eof token")
end)

test("multiple comments on different lines", function()
    local tokens = lexer.tokenize("// first\n// second\n")
    assert_eq(5, #tokens, "token count")
    assert_eq(TOKEN.COMMENT, tokens[1].type, "comment 1")
    assert_eq(" first", tokens[1].value, "comment 1 value")
    assert_eq(TOKEN.NEWLINE, tokens[2].type, "newline 1")
    assert_eq(TOKEN.COMMENT, tokens[3].type, "comment 2")
    assert_eq(" second", tokens[3].value, "comment 2 value")
end)

test("empty comment", function()
    local tokens = lexer.tokenize("//")
    assert_eq(2, #tokens, "token count")
    assert_eq(TOKEN.COMMENT, tokens[1].type, "token type")
    assert_eq("", tokens[1].value, "empty comment content")
end)

test("comment position tracking", function()
    local tokens = lexer.tokenize("   // hello")
    assert_eq(TOKEN.COMMENT, tokens[1].type, "token type")
    assert_eq(1, tokens[1].line, "line number")
    assert_eq(4, tokens[1].col, "column (after whitespace)")
end)
-- }}}

-- {{{ Whitespace tests
print("\n-- Whitespace handling --")

test("spaces between newlines are consumed", function()
    local tokens = lexer.tokenize("\n   \n")
    assert_eq(3, #tokens, "token count")
    assert_eq(TOKEN.NEWLINE, tokens[1].type, "first newline")
    assert_eq(TOKEN.NEWLINE, tokens[2].type, "second newline")
end)

test("tabs are consumed", function()
    local tokens = lexer.tokenize("\t\t\n")
    assert_eq(2, #tokens, "token count")
    assert_eq(TOKEN.NEWLINE, tokens[1].type, "newline")
end)

test("carriage returns are consumed", function()
    local tokens = lexer.tokenize("\r\n")
    assert_eq(2, #tokens, "token count")
    assert_eq(TOKEN.NEWLINE, tokens[1].type, "newline")
end)
-- }}}

-- {{{ Position tracking tests
print("\n-- Position tracking --")

test("line numbers increment after newlines", function()
    local tokens = lexer.tokenize("// line 1\n// line 2\n// line 3")
    assert_eq(1, tokens[1].line, "comment 1 line")
    assert_eq(2, tokens[3].line, "comment 2 line")
    assert_eq(3, tokens[5].line, "comment 3 line")
end)

test("column resets after newline", function()
    local tokens = lexer.tokenize("  // a\n  // b")
    assert_eq(3, tokens[1].col, "first comment col")
    assert_eq(3, tokens[3].col, "second comment col (reset after newline)")
end)

test("EOF position at end of input", function()
    local tokens = lexer.tokenize("// hi\n")
    local eof = tokens[#tokens]
    assert_eq(TOKEN.EOF, eof.type, "EOF type")
    assert_eq(2, eof.line, "EOF line")
    assert_eq(1, eof.col, "EOF col")
end)
-- }}}

-- {{{ Error handling tests
print("\n-- Error handling --")

test("unknown character throws error with position", function()
    local ok, err = pcall(function()
        lexer.tokenize("@")
    end)
    assert_eq(false, ok, "should throw error")
    assert(err:find("Unexpected character"), "error should mention unexpected character")
    assert(err:find("line 1"), "error should mention line")
    assert(err:find("column 1"), "error should mention column")
end)

test("unknown character after whitespace has correct position", function()
    local ok, err = pcall(function()
        lexer.tokenize("   @")
    end)
    assert_eq(false, ok, "should throw error")
    assert(err:find("column 4"), "error should show correct column")
end)

test("unknown character on line 2", function()
    local ok, err = pcall(function()
        lexer.tokenize("// ok\n@")
    end)
    assert_eq(false, ok, "should throw error")
    assert(err:find("line 2"), "error should show line 2")
end)
-- }}}

-- {{{ Internal helpers tests
print("\n-- Internal helpers --")

test("_internal.peek works", function()
    local state = lexer._internal.create_state("abc")
    assert_eq("a", lexer._internal.peek(state), "peek at pos 1")
    assert_eq("b", lexer._internal.peek(state, 1), "peek at pos 2")
    assert_eq("c", lexer._internal.peek(state, 2), "peek at pos 3")
    assert_eq(nil, lexer._internal.peek(state, 3), "peek beyond end")
end)

test("_internal.advance works", function()
    local state = lexer._internal.create_state("ab")
    assert_eq("a", lexer._internal.advance(state), "advance returns char")
    assert_eq(2, state.pos, "position incremented")
    assert_eq(2, state.col, "column incremented")
end)

test("_internal.advance tracks newlines", function()
    local state = lexer._internal.create_state("a\nb")
    lexer._internal.advance(state)  -- 'a'
    assert_eq(1, state.line, "still line 1")
    lexer._internal.advance(state)  -- '\n'
    assert_eq(2, state.line, "now line 2")
    assert_eq(1, state.col, "column reset")
end)

test("_internal.is_at_end works", function()
    local state = lexer._internal.create_state("a")
    assert_eq(false, lexer._internal.is_at_end(state), "not at end yet")
    lexer._internal.advance(state)
    assert_eq(true, lexer._internal.is_at_end(state), "at end now")
end)

test("_internal.add_token works", function()
    local state = lexer._internal.create_state("test")
    state.line = 5
    state.col = 10
    local token = lexer._internal.add_token(state, TOKEN.COMMENT, "hello", 5, 3)
    assert_eq(TOKEN.COMMENT, token.type, "token type")
    assert_eq("hello", token.value, "token value")
    assert_eq(5, token.line, "start line")
    assert_eq(3, token.col, "start col")
    assert_eq(1, #state.tokens, "token added to list")
end)
-- }}}

-- {{{ TOKEN table tests
print("\n-- TOKEN table --")

test("TOKEN table has all keywords", function()
    local keywords = {"FUNCTION", "ENDFUNCTION", "TAKES", "RETURNS", "NOTHING",
                      "GLOBALS", "ENDGLOBALS", "LOCAL", "SET", "CALL",
                      "IF", "THEN", "ELSE", "ELSEIF", "ENDIF",
                      "LOOP", "ENDLOOP", "EXITWHEN", "RETURN",
                      "CONSTANT", "NATIVE", "TYPE", "EXTENDS", "ARRAY",
                      "AND", "OR", "NOT", "TRUE", "FALSE", "NULL"}
    for _, kw in ipairs(keywords) do
        assert(TOKEN[kw], "TOKEN." .. kw .. " should exist")
    end
end)

test("TOKEN table has all operators", function()
    local ops = {"PLUS", "MINUS", "STAR", "SLASH",
                 "EQUALS", "NOT_EQUALS", "LESS", "LESS_EQUALS",
                 "GREATER", "GREATER_EQUALS", "ASSIGN"}
    for _, op in ipairs(ops) do
        assert(TOKEN[op], "TOKEN." .. op .. " should exist")
    end
end)

test("TOKEN table has all punctuation", function()
    local puncts = {"LPAREN", "RPAREN", "LBRACKET", "RBRACKET", "COMMA"}
    for _, p in ipairs(puncts) do
        assert(TOKEN[p], "TOKEN." .. p .. " should exist")
    end
end)

test("TOKEN table has special tokens", function()
    assert(TOKEN.NEWLINE, "NEWLINE")
    assert(TOKEN.COMMENT, "COMMENT")
    assert(TOKEN.EOF, "EOF")
    assert(TOKEN.IDENTIFIER, "IDENTIFIER")
    assert(TOKEN.INTEGER, "INTEGER")
    assert(TOKEN.REAL, "REAL")
    assert(TOKEN.STRING, "STRING")
    assert(TOKEN.RAWCODE, "RAWCODE")
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
