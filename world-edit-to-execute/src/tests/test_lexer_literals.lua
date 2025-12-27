--[[
Test: JASS Lexer Literals (304c)

Tests literal tokenization:
- Integer literals (decimal, hex 0x, hex $, octal)
- Real literals (standard, leading dot, trailing dot)
- String literals (with escape sequences)
- Rawcode literals (4-character codes)
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

local function assert_token(tokens, index, expected_type, expected_value)
    local t = tokens[index]
    if not t then
        error(string.format("token %d: expected %s but no token found", index, expected_type))
    end
    if t.type ~= expected_type then
        error(string.format("token %d: expected type %s, got %s", index, expected_type, t.type))
    end
    if expected_value and t.value ~= expected_value then
        error(string.format("token %d: expected value '%s', got '%s'", index, expected_value, t.value))
    end
end

local function assert_error_contains(fn, substring)
    local ok, err = pcall(fn)
    if ok then
        error("expected error but function succeeded")
    end
    if not string.find(err, substring, 1, true) then
        error(string.format("expected error containing '%s', got: %s", substring, err))
    end
end
-- }}}

print("=== JASS Lexer Literals Tests (304c) ===\n")

-- {{{ Integer literals - decimal
print("-- Integer literals (decimal) --")

test("single digit", function()
    local tokens = lexer.tokenize("0")
    assert_token(tokens, 1, TOKEN.INTEGER, "0")
end)

test("multi-digit integer", function()
    local tokens = lexer.tokenize("12345")
    assert_token(tokens, 1, TOKEN.INTEGER, "12345")
end)

test("large integer", function()
    local tokens = lexer.tokenize("999999999")
    assert_token(tokens, 1, TOKEN.INTEGER, "999999999")
end)

test("multiple integers", function()
    local tokens = lexer.tokenize("1 2 3")
    assert_token(tokens, 1, TOKEN.INTEGER, "1")
    assert_token(tokens, 2, TOKEN.INTEGER, "2")
    assert_token(tokens, 3, TOKEN.INTEGER, "3")
end)
-- }}}

-- {{{ Integer literals - hexadecimal 0x
print("\n-- Integer literals (hex 0x) --")

test("hex 0x lowercase", function()
    local tokens = lexer.tokenize("0x1f")
    assert_token(tokens, 1, TOKEN.INTEGER, "0x1f")
end)

test("hex 0X uppercase prefix", function()
    local tokens = lexer.tokenize("0X1F")
    assert_token(tokens, 1, TOKEN.INTEGER, "0X1F")
end)

test("hex 0x mixed case digits", function()
    local tokens = lexer.tokenize("0xAbCdEf")
    assert_token(tokens, 1, TOKEN.INTEGER, "0xAbCdEf")
end)

test("hex 0x zero value", function()
    local tokens = lexer.tokenize("0x0")
    assert_token(tokens, 1, TOKEN.INTEGER, "0x0")
end)

test("hex 0x long value", function()
    local tokens = lexer.tokenize("0xFFFFFFFF")
    assert_token(tokens, 1, TOKEN.INTEGER, "0xFFFFFFFF")
end)

test("hex 0x with no digits errors", function()
    assert_error_contains(function()
        lexer.tokenize("0x")
    end, "expected digits after '0x'")
end)

test("hex 0x followed by non-hex errors", function()
    assert_error_contains(function()
        lexer.tokenize("0xG")
    end, "expected digits after '0x'")
end)
-- }}}

-- {{{ Integer literals - hexadecimal $
print("\n-- Integer literals (hex $) --")

test("hex $ prefix", function()
    local tokens = lexer.tokenize("$1F")
    assert_token(tokens, 1, TOKEN.INTEGER, "$1F")
end)

test("hex $ lowercase", function()
    local tokens = lexer.tokenize("$ff")
    assert_token(tokens, 1, TOKEN.INTEGER, "$ff")
end)

test("hex $ long value", function()
    local tokens = lexer.tokenize("$DEADBEEF")
    assert_token(tokens, 1, TOKEN.INTEGER, "$DEADBEEF")
end)

test("hex $ with no digits errors", function()
    assert_error_contains(function()
        lexer.tokenize("$")
    end, "expected digits after '$'")
end)
-- }}}

-- {{{ Integer literals - octal
print("\n-- Integer literals (octal) --")

test("octal captured as integer", function()
    -- Lexer captures as INTEGER, parser/evaluator interprets octal
    local tokens = lexer.tokenize("017")
    assert_token(tokens, 1, TOKEN.INTEGER, "017")
end)

test("octal 0777", function()
    local tokens = lexer.tokenize("0777")
    assert_token(tokens, 1, TOKEN.INTEGER, "0777")
end)
-- }}}

-- {{{ Real literals - standard
print("\n-- Real literals (standard) --")

test("real 1.5", function()
    local tokens = lexer.tokenize("1.5")
    assert_token(tokens, 1, TOKEN.REAL, "1.5")
end)

test("real 123.456", function()
    local tokens = lexer.tokenize("123.456")
    assert_token(tokens, 1, TOKEN.REAL, "123.456")
end)

test("real 0.0", function()
    local tokens = lexer.tokenize("0.0")
    assert_token(tokens, 1, TOKEN.REAL, "0.0")
end)

test("real with many decimals", function()
    local tokens = lexer.tokenize("3.14159265")
    assert_token(tokens, 1, TOKEN.REAL, "3.14159265")
end)
-- }}}

-- {{{ Real literals - leading dot
print("\n-- Real literals (leading dot) --")

test("real .5", function()
    local tokens = lexer.tokenize(".5")
    assert_token(tokens, 1, TOKEN.REAL, ".5")
end)

test("real .123", function()
    local tokens = lexer.tokenize(".123")
    assert_token(tokens, 1, TOKEN.REAL, ".123")
end)

test("real .0", function()
    local tokens = lexer.tokenize(".0")
    assert_token(tokens, 1, TOKEN.REAL, ".0")
end)

test("lone dot errors", function()
    assert_error_contains(function()
        lexer.tokenize(".")
    end, "Unexpected character '.'")
end)

test("dot followed by non-digit errors", function()
    assert_error_contains(function()
        lexer.tokenize(".x")
    end, "Unexpected character '.'")
end)
-- }}}

-- {{{ Real literals - trailing dot
print("\n-- Real literals (trailing dot) --")

test("real 1.", function()
    local tokens = lexer.tokenize("1.")
    assert_token(tokens, 1, TOKEN.REAL, "1.")
end)

test("real 123.", function()
    local tokens = lexer.tokenize("123.")
    assert_token(tokens, 1, TOKEN.REAL, "123.")
end)

test("real 0.", function()
    local tokens = lexer.tokenize("0.")
    assert_token(tokens, 1, TOKEN.REAL, "0.")
end)
-- }}}

-- {{{ String literals
print("\n-- String literals --")

test("simple string", function()
    local tokens = lexer.tokenize('"hello"')
    assert_token(tokens, 1, TOKEN.STRING, "hello")
end)

test("empty string", function()
    local tokens = lexer.tokenize('""')
    assert_token(tokens, 1, TOKEN.STRING, "")
end)

test("string with spaces", function()
    local tokens = lexer.tokenize('"hello world"')
    assert_token(tokens, 1, TOKEN.STRING, "hello world")
end)

test("string with numbers", function()
    local tokens = lexer.tokenize('"test123"')
    assert_token(tokens, 1, TOKEN.STRING, "test123")
end)

test("escape \\n", function()
    local tokens = lexer.tokenize('"line1\\nline2"')
    assert_token(tokens, 1, TOKEN.STRING, "line1\nline2")
end)

test("escape \\r", function()
    local tokens = lexer.tokenize('"a\\rb"')
    assert_token(tokens, 1, TOKEN.STRING, "a\rb")
end)

test("escape \\t", function()
    local tokens = lexer.tokenize('"a\\tb"')
    assert_token(tokens, 1, TOKEN.STRING, "a\tb")
end)

test("escape \\\\", function()
    local tokens = lexer.tokenize('"a\\\\b"')
    assert_token(tokens, 1, TOKEN.STRING, "a\\b")
end)

test("escape \\\"", function()
    local tokens = lexer.tokenize('"say \\"hello\\""')
    assert_token(tokens, 1, TOKEN.STRING, 'say "hello"')
end)

test("unknown escape preserved", function()
    local tokens = lexer.tokenize('"\\x"')
    assert_token(tokens, 1, TOKEN.STRING, "\\x")
end)

test("unterminated string errors", function()
    assert_error_contains(function()
        lexer.tokenize('"hello')
    end, "Unterminated string")
end)

test("string with newline errors", function()
    assert_error_contains(function()
        lexer.tokenize('"hello\nworld"')
    end, "Unterminated string")
end)
-- }}}

-- {{{ Rawcode literals
print("\n-- Rawcode literals --")

test("rawcode hfoo", function()
    local tokens = lexer.tokenize("'hfoo'")
    assert_token(tokens, 1, TOKEN.RAWCODE, "hfoo")
end)

test("rawcode AHbz", function()
    local tokens = lexer.tokenize("'AHbz'")
    assert_token(tokens, 1, TOKEN.RAWCODE, "AHbz")
end)

test("rawcode A000", function()
    local tokens = lexer.tokenize("'A000'")
    assert_token(tokens, 1, TOKEN.RAWCODE, "A000")
end)

test("rawcode with symbols", function()
    local tokens = lexer.tokenize("'A!@#'")
    assert_token(tokens, 1, TOKEN.RAWCODE, "A!@#")
end)

test("rawcode too short errors", function()
    assert_error_contains(function()
        lexer.tokenize("'abc'")
    end, "expected 4 characters")
end)

test("rawcode empty errors", function()
    assert_error_contains(function()
        lexer.tokenize("''")
    end, "expected 4 characters")
end)

test("rawcode unterminated errors", function()
    assert_error_contains(function()
        lexer.tokenize("'hfoo")
    end, "expected closing quote")
end)

test("rawcode with newline errors", function()
    assert_error_contains(function()
        lexer.tokenize("'hf\noo'")
    end, "Unterminated rawcode")
end)
-- }}}

-- {{{ is_hex_digit helper
print("\n-- is_hex_digit helper --")

test("is_hex_digit exported", function()
    local is_hex = lexer._internal.is_hex_digit
    assert(is_hex, "is_hex_digit not exported")
    assert_eq(true, is_hex("0"), "0")
    assert_eq(true, is_hex("9"), "9")
    assert_eq(true, is_hex("a"), "a")
    assert_eq(true, is_hex("f"), "f")
    assert_eq(true, is_hex("A"), "A")
    assert_eq(true, is_hex("F"), "F")
    assert_eq(false, is_hex("g"), "g")
    assert_eq(false, is_hex("G"), "G")
    assert_eq(false, is_hex(nil), "nil")
end)
-- }}}

-- {{{ Mixed literals in expressions
print("\n-- Mixed literals in expressions --")

test("expression with multiple literal types", function()
    local tokens = lexer.tokenize('x = 10 + .5 * "test"')
    assert_token(tokens, 1, TOKEN.IDENTIFIER, "x")
    assert_token(tokens, 2, TOKEN.ASSIGN, "=")
    assert_token(tokens, 3, TOKEN.INTEGER, "10")
    assert_token(tokens, 4, TOKEN.PLUS, "+")
    assert_token(tokens, 5, TOKEN.REAL, ".5")
    assert_token(tokens, 6, TOKEN.STAR, "*")
    assert_token(tokens, 7, TOKEN.STRING, "test")
end)

test("rawcode in function call", function()
    local tokens = lexer.tokenize("CreateUnit('hfoo', 0, 0)")
    assert_token(tokens, 1, TOKEN.IDENTIFIER, "CreateUnit")
    assert_token(tokens, 2, TOKEN.LPAREN)
    assert_token(tokens, 3, TOKEN.RAWCODE, "hfoo")
    assert_token(tokens, 4, TOKEN.COMMA)
    assert_token(tokens, 5, TOKEN.INTEGER, "0")
end)

test("hex in comparison", function()
    local tokens = lexer.tokenize("if x == 0xFF then")
    assert_token(tokens, 1, TOKEN.IF)
    assert_token(tokens, 2, TOKEN.IDENTIFIER, "x")
    assert_token(tokens, 3, TOKEN.EQUALS)
    assert_token(tokens, 4, TOKEN.INTEGER, "0xFF")
    assert_token(tokens, 5, TOKEN.THEN)
end)
-- }}}

-- {{{ Summary
print("\n=== Summary ===")
print(string.format("Tests passed: %d/%d", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print("Some tests failed!")
    os.exit(1)
end
-- }}}
