--[[
Test: JASS Lexer Keywords, Identifiers, and Operators (304b)

Tests the lexer's ability to recognize:
- All 30 JASS keywords
- Identifiers (variables, functions, types)
- Operators (arithmetic, comparison, logical)
- Punctuation (parentheses, brackets, commas)
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

-- {{{ assert helpers
local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", msg or "assertion failed",
            tostring(expected), tostring(actual)))
    end
end

local function assert_token(token, expected_type, expected_value, msg)
    assert_eq(expected_type, token.type, (msg or "") .. " type")
    if expected_value then
        assert_eq(expected_value, token.value, (msg or "") .. " value")
    end
end
-- }}}

print("=== JASS Lexer Keywords, Identifiers, Operators Tests ===\n")

-- {{{ Keyword tests
print("-- Keywords --")

test("function keyword", function()
    local tokens = lexer.tokenize("function")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.FUNCTION, "function")
end)

test("all 30 keywords recognized", function()
    local keywords = {
        {"function", TOKEN.FUNCTION},
        {"endfunction", TOKEN.ENDFUNCTION},
        {"takes", TOKEN.TAKES},
        {"returns", TOKEN.RETURNS},
        {"nothing", TOKEN.NOTHING},
        {"globals", TOKEN.GLOBALS},
        {"endglobals", TOKEN.ENDGLOBALS},
        {"local", TOKEN.LOCAL},
        {"set", TOKEN.SET},
        {"call", TOKEN.CALL},
        {"if", TOKEN.IF},
        {"then", TOKEN.THEN},
        {"else", TOKEN.ELSE},
        {"elseif", TOKEN.ELSEIF},
        {"endif", TOKEN.ENDIF},
        {"loop", TOKEN.LOOP},
        {"endloop", TOKEN.ENDLOOP},
        {"exitwhen", TOKEN.EXITWHEN},
        {"return", TOKEN.RETURN},
        {"constant", TOKEN.CONSTANT},
        {"native", TOKEN.NATIVE},
        {"type", TOKEN.TYPE},
        {"extends", TOKEN.EXTENDS},
        {"array", TOKEN.ARRAY},
        {"and", TOKEN.AND},
        {"or", TOKEN.OR},
        {"not", TOKEN.NOT},
        {"true", TOKEN.TRUE},
        {"false", TOKEN.FALSE},
        {"null", TOKEN.NULL},
    }

    for _, kw in ipairs(keywords) do
        local tokens = lexer.tokenize(kw[1])
        assert_token(tokens[1], kw[2], kw[1], kw[1])
    end
end)

test("keywords are case-sensitive (lowercase only)", function()
    -- Uppercase versions should be identifiers, not keywords
    local tokens = lexer.tokenize("Function FUNCTION")
    assert_eq(3, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "Function", "Function")
    assert_token(tokens[2], TOKEN.IDENTIFIER, "FUNCTION", "FUNCTION")
end)

test("keyword-like prefixes are identifiers", function()
    -- "functions" is not "function", it's an identifier
    local tokens = lexer.tokenize("functions ifs returns2")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "functions")
    assert_token(tokens[2], TOKEN.IDENTIFIER, "ifs")
    assert_token(tokens[3], TOKEN.IDENTIFIER, "returns2")
end)
-- }}}

-- {{{ Identifier tests
print("\n-- Identifiers --")

test("simple identifier", function()
    local tokens = lexer.tokenize("myVar")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "myVar")
end)

test("identifier starting with underscore", function()
    local tokens = lexer.tokenize("_privateVar")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "_privateVar")
end)

test("identifier with digits", function()
    local tokens = lexer.tokenize("var123")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "var123")
end)

test("identifier with underscores and digits", function()
    local tokens = lexer.tokenize("my_var_2")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "my_var_2")
end)

test("multiple identifiers separated by whitespace", function()
    local tokens = lexer.tokenize("foo bar baz")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "foo")
    assert_token(tokens[2], TOKEN.IDENTIFIER, "bar")
    assert_token(tokens[3], TOKEN.IDENTIFIER, "baz")
end)

test("single letter identifier", function()
    local tokens = lexer.tokenize("x")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "x")
end)

test("single underscore identifier", function()
    local tokens = lexer.tokenize("_")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "_")
end)

test("identifier position tracking", function()
    local tokens = lexer.tokenize("   foo")
    assert_eq(1, tokens[1].line, "line")
    assert_eq(4, tokens[1].col, "col")
end)
-- }}}

-- {{{ Two-character operator tests
print("\n-- Two-character operators --")

test("equals operator (==)", function()
    local tokens = lexer.tokenize("==")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.EQUALS, "==")
end)

test("not equals operator (!=)", function()
    local tokens = lexer.tokenize("!=")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.NOT_EQUALS, "!=")
end)

test("less equals operator (<=)", function()
    local tokens = lexer.tokenize("<=")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.LESS_EQUALS, "<=")
end)

test("greater equals operator (>=)", function()
    local tokens = lexer.tokenize(">=")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.GREATER_EQUALS, ">=")
end)

test("two-char ops distinguished from single-char", function()
    -- "==" should be EQUALS, not two ASSIGN tokens
    local tokens = lexer.tokenize("== = ==")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.EQUALS, "==")
    assert_token(tokens[2], TOKEN.ASSIGN, "=")
    assert_token(tokens[3], TOKEN.EQUALS, "==")
end)
-- }}}

-- {{{ Single-character operator tests
print("\n-- Single-character operators --")

test("plus operator", function()
    local tokens = lexer.tokenize("+")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.PLUS, "+")
end)

test("minus operator", function()
    local tokens = lexer.tokenize("-")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.MINUS, "-")
end)

test("star operator", function()
    local tokens = lexer.tokenize("*")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.STAR, "*")
end)

test("slash operator (not comment)", function()
    -- Single slash should be SLASH, not trigger comment
    local tokens = lexer.tokenize("/ x")
    assert_eq(3, #tokens, "token count")
    assert_token(tokens[1], TOKEN.SLASH, "/")
    assert_token(tokens[2], TOKEN.IDENTIFIER, "x")
end)

test("assign operator", function()
    local tokens = lexer.tokenize("=")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.ASSIGN, "=")
end)

test("less than operator", function()
    local tokens = lexer.tokenize("<")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.LESS, "<")
end)

test("greater than operator", function()
    local tokens = lexer.tokenize(">")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.GREATER, ">")
end)

test("all single-char operators together", function()
    local tokens = lexer.tokenize("+ - * / = < >")
    assert_eq(8, #tokens, "token count")
    assert_token(tokens[1], TOKEN.PLUS)
    assert_token(tokens[2], TOKEN.MINUS)
    assert_token(tokens[3], TOKEN.STAR)
    assert_token(tokens[4], TOKEN.SLASH)
    assert_token(tokens[5], TOKEN.ASSIGN)
    assert_token(tokens[6], TOKEN.LESS)
    assert_token(tokens[7], TOKEN.GREATER)
end)
-- }}}

-- {{{ Punctuation tests
print("\n-- Punctuation --")

test("left parenthesis", function()
    local tokens = lexer.tokenize("(")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.LPAREN, "(")
end)

test("right parenthesis", function()
    local tokens = lexer.tokenize(")")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.RPAREN, ")")
end)

test("left bracket", function()
    local tokens = lexer.tokenize("[")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.LBRACKET, "[")
end)

test("right bracket", function()
    local tokens = lexer.tokenize("]")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.RBRACKET, "]")
end)

test("comma", function()
    local tokens = lexer.tokenize(",")
    assert_eq(2, #tokens, "token count")
    assert_token(tokens[1], TOKEN.COMMA, ",")
end)

test("all punctuation together", function()
    local tokens = lexer.tokenize("( ) [ ] ,")
    assert_eq(6, #tokens, "token count")
    assert_token(tokens[1], TOKEN.LPAREN)
    assert_token(tokens[2], TOKEN.RPAREN)
    assert_token(tokens[3], TOKEN.LBRACKET)
    assert_token(tokens[4], TOKEN.RBRACKET)
    assert_token(tokens[5], TOKEN.COMMA)
end)
-- }}}

-- {{{ Combined tests (realistic JASS code)
print("\n-- Combined (realistic JASS) --")

test("function declaration", function()
    local tokens = lexer.tokenize("function MyFunc takes nothing returns nothing")
    -- function, MyFunc, takes, nothing, returns, nothing, EOF = 7 tokens
    assert_eq(7, #tokens, "token count")
    assert_token(tokens[1], TOKEN.FUNCTION)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "MyFunc")
    assert_token(tokens[3], TOKEN.TAKES)
    assert_token(tokens[4], TOKEN.NOTHING)
    assert_token(tokens[5], TOKEN.RETURNS)
    assert_token(tokens[6], TOKEN.NOTHING)
end)

test("variable assignment", function()
    local tokens = lexer.tokenize("set x = y")
    assert_eq(5, #tokens, "token count")
    assert_token(tokens[1], TOKEN.SET)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "x")
    assert_token(tokens[3], TOKEN.ASSIGN)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "y")
end)

test("function call", function()
    local tokens = lexer.tokenize("call DoSomething(a, b)")
    assert_eq(8, #tokens, "token count")
    assert_token(tokens[1], TOKEN.CALL)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "DoSomething")
    assert_token(tokens[3], TOKEN.LPAREN)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "a")
    assert_token(tokens[5], TOKEN.COMMA)
    assert_token(tokens[6], TOKEN.IDENTIFIER, "b")
    assert_token(tokens[7], TOKEN.RPAREN)
end)

test("array access", function()
    local tokens = lexer.tokenize("arr[i]")
    assert_eq(5, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "arr")
    assert_token(tokens[2], TOKEN.LBRACKET)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "i")
    assert_token(tokens[4], TOKEN.RBRACKET)
end)

test("comparison expression", function()
    local tokens = lexer.tokenize("x <= y and y >= z")
    assert_eq(8, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "x")
    assert_token(tokens[2], TOKEN.LESS_EQUALS)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "y")
    assert_token(tokens[4], TOKEN.AND)
    assert_token(tokens[5], TOKEN.IDENTIFIER, "y")
    assert_token(tokens[6], TOKEN.GREATER_EQUALS)
    assert_token(tokens[7], TOKEN.IDENTIFIER, "z")
end)

test("arithmetic expression", function()
    local tokens = lexer.tokenize("a + b * c - d / e")
    assert_eq(10, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "a")
    assert_token(tokens[2], TOKEN.PLUS)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "b")
    assert_token(tokens[4], TOKEN.STAR)
    assert_token(tokens[5], TOKEN.IDENTIFIER, "c")
    assert_token(tokens[6], TOKEN.MINUS)
    assert_token(tokens[7], TOKEN.IDENTIFIER, "d")
    assert_token(tokens[8], TOKEN.SLASH)
    assert_token(tokens[9], TOKEN.IDENTIFIER, "e")
end)

test("if statement", function()
    local tokens = lexer.tokenize("if x == y then\nendif")
    assert_eq(8, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IF)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "x")
    assert_token(tokens[3], TOKEN.EQUALS)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "y")
    assert_token(tokens[5], TOKEN.THEN)
    assert_token(tokens[6], TOKEN.NEWLINE)
    assert_token(tokens[7], TOKEN.ENDIF)
end)

test("loop with exitwhen", function()
    local tokens = lexer.tokenize("loop\nexitwhen x\nendloop")
    assert_eq(7, #tokens, "token count")
    assert_token(tokens[1], TOKEN.LOOP)
    assert_token(tokens[2], TOKEN.NEWLINE)
    assert_token(tokens[3], TOKEN.EXITWHEN)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "x")
    assert_token(tokens[5], TOKEN.NEWLINE)
    assert_token(tokens[6], TOKEN.ENDLOOP)
end)

test("boolean operators", function()
    local tokens = lexer.tokenize("not a or b and c")
    -- not, a, or, b, and, c, EOF = 7 tokens
    assert_eq(7, #tokens, "token count")
    assert_token(tokens[1], TOKEN.NOT)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "a")
    assert_token(tokens[3], TOKEN.OR)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "b")
    assert_token(tokens[5], TOKEN.AND)
    assert_token(tokens[6], TOKEN.IDENTIFIER, "c")
end)

test("true, false, null literals", function()
    local tokens = lexer.tokenize("true false null")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.TRUE, "true")
    assert_token(tokens[2], TOKEN.FALSE, "false")
    assert_token(tokens[3], TOKEN.NULL, "null")
end)

test("globals block", function()
    local tokens = lexer.tokenize("globals\nendglobals")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.GLOBALS)
    assert_token(tokens[2], TOKEN.NEWLINE)
    assert_token(tokens[3], TOKEN.ENDGLOBALS)
end)

test("type definition", function()
    local tokens = lexer.tokenize("type mytype extends handle")
    assert_eq(5, #tokens, "token count")
    assert_token(tokens[1], TOKEN.TYPE)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "mytype")
    assert_token(tokens[3], TOKEN.EXTENDS)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "handle")
end)

test("constant and array", function()
    local tokens = lexer.tokenize("constant integer array")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.CONSTANT)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "integer")
    assert_token(tokens[3], TOKEN.ARRAY)
end)

test("native declaration", function()
    local tokens = lexer.tokenize("native GetUnitX takes unit returns real")
    assert_eq(7, #tokens, "token count")
    assert_token(tokens[1], TOKEN.NATIVE)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "GetUnitX")
    assert_token(tokens[3], TOKEN.TAKES)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "unit")
    assert_token(tokens[5], TOKEN.RETURNS)
    assert_token(tokens[6], TOKEN.IDENTIFIER, "real")
end)
-- }}}

-- {{{ Edge cases
print("\n-- Edge cases --")

test("operators without whitespace", function()
    local tokens = lexer.tokenize("a+b")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "a")
    assert_token(tokens[2], TOKEN.PLUS)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "b")
end)

test("comparison without whitespace", function()
    local tokens = lexer.tokenize("x==y")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "x")
    assert_token(tokens[2], TOKEN.EQUALS)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "y")
end)

test("nested parentheses", function()
    local tokens = lexer.tokenize("((a))")
    assert_eq(6, #tokens, "token count")
    assert_token(tokens[1], TOKEN.LPAREN)
    assert_token(tokens[2], TOKEN.LPAREN)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "a")
    assert_token(tokens[4], TOKEN.RPAREN)
    assert_token(tokens[5], TOKEN.RPAREN)
end)

test("mixed operators and punctuation", function()
    local tokens = lexer.tokenize("f(a+b,c-d)")
    assert_eq(11, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "f")
    assert_token(tokens[2], TOKEN.LPAREN)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "a")
    assert_token(tokens[4], TOKEN.PLUS)
    assert_token(tokens[5], TOKEN.IDENTIFIER, "b")
    assert_token(tokens[6], TOKEN.COMMA)
    assert_token(tokens[7], TOKEN.IDENTIFIER, "c")
    assert_token(tokens[8], TOKEN.MINUS)
    assert_token(tokens[9], TOKEN.IDENTIFIER, "d")
    assert_token(tokens[10], TOKEN.RPAREN)
end)

test("comment after code on same line", function()
    local tokens = lexer.tokenize("set x = y // assign y to x")
    assert_eq(6, #tokens, "token count")
    assert_token(tokens[1], TOKEN.SET)
    assert_token(tokens[2], TOKEN.IDENTIFIER, "x")
    assert_token(tokens[3], TOKEN.ASSIGN)
    assert_token(tokens[4], TOKEN.IDENTIFIER, "y")
    assert_token(tokens[5], TOKEN.COMMENT, " assign y to x")
end)

test("slash followed by non-slash", function()
    -- "/" followed by something other than "/" should be SLASH, not start comment
    local tokens = lexer.tokenize("a/b")
    assert_eq(4, #tokens, "token count")
    assert_token(tokens[1], TOKEN.IDENTIFIER, "a")
    assert_token(tokens[2], TOKEN.SLASH)
    assert_token(tokens[3], TOKEN.IDENTIFIER, "b")
end)
-- }}}

-- {{{ Internal helper tests
print("\n-- Internal helpers --")

test("is_alpha recognizes letters", function()
    local is_alpha = lexer._internal.is_alpha
    assert_eq(true, is_alpha("a"), "lowercase a")
    assert_eq(true, is_alpha("z"), "lowercase z")
    assert_eq(true, is_alpha("A"), "uppercase A")
    assert_eq(true, is_alpha("Z"), "uppercase Z")
    assert_eq(true, is_alpha("_"), "underscore")
end)

test("is_alpha rejects non-letters", function()
    local is_alpha = lexer._internal.is_alpha
    assert_eq(false, is_alpha("0"), "digit")
    assert_eq(false, is_alpha("+"), "operator")
    assert_eq(false, is_alpha(" "), "space")
    assert_eq(false, is_alpha(nil), "nil")
end)

test("is_digit recognizes digits", function()
    local is_digit = lexer._internal.is_digit
    assert_eq(true, is_digit("0"), "zero")
    assert_eq(true, is_digit("5"), "five")
    assert_eq(true, is_digit("9"), "nine")
end)

test("is_digit rejects non-digits", function()
    local is_digit = lexer._internal.is_digit
    assert_eq(false, is_digit("a"), "letter")
    assert_eq(false, is_digit("_"), "underscore")
    assert_eq(false, is_digit(nil), "nil")
end)

test("is_alnum combines alpha and digit", function()
    local is_alnum = lexer._internal.is_alnum
    assert_eq(true, is_alnum("a"), "letter")
    assert_eq(true, is_alnum("5"), "digit")
    assert_eq(true, is_alnum("_"), "underscore")
    assert_eq(false, is_alnum("+"), "operator")
    assert_eq(false, is_alnum(nil), "nil")
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
