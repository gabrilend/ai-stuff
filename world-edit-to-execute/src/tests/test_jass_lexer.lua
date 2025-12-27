--[[
Test: JASS Lexer Comprehensive Test Suite (304d)

This is the master test runner for the JASS lexer.
It includes:
- Edge case tests
- Integration tests with real JASS code patterns
- Fixture file validation
- Performance tests
- Real war3map.j content validation (if available)

Run from project root: lua src/tests/test_jass_lexer.lua
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local lexer = require("jass.lexer")
local TOKEN = lexer.TOKEN

local tests_run = 0
local tests_passed = 0
local tests_failed = 0

-- {{{ test helper
local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print(string.format("  [PASS] %s", name))
    else
        tests_failed = tests_failed + 1
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

local function find_token_type(tokens, token_type)
    for i, t in ipairs(tokens) do
        if t.type == token_type then
            return i, t
        end
    end
    return nil
end

local function count_token_type(tokens, token_type)
    local count = 0
    for _, t in ipairs(tokens) do
        if t.type == token_type then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ read_fixture
local function read_fixture(name)
    local path = DIR .. "/src/tests/fixtures/jass/" .. name
    local f = io.open(path, "r")
    if not f then
        return nil, "Cannot open fixture: " .. path
    end
    local content = f:read("*a")
    f:close()
    return content
end
-- }}}

print("=== JASS Lexer Comprehensive Test Suite (304d) ===\n")

-- {{{ Edge case tests
local function test_edge_cases()
    print("-- Edge Cases --")

    test("empty input returns only EOF", function()
        local tokens = lexer.tokenize("")
        assert_eq(1, #tokens, "token count")
        assert_token(tokens, 1, TOKEN.EOF)
    end)

    test("whitespace-only returns only EOF", function()
        local tokens = lexer.tokenize("   \t\t\r\r   ")
        assert_eq(1, #tokens, "token count")
        assert_token(tokens, 1, TOKEN.EOF)
    end)

    test("only newlines", function()
        local tokens = lexer.tokenize("\n\n\n")
        assert_eq(4, #tokens, "token count: 3 NEWLINE + EOF")
        assert_token(tokens, 1, TOKEN.NEWLINE)
        assert_token(tokens, 2, TOKEN.NEWLINE)
        assert_token(tokens, 3, TOKEN.NEWLINE)
        assert_token(tokens, 4, TOKEN.EOF)
    end)

    test("operators without spaces", function()
        local tokens = lexer.tokenize("a+b-c*d/e")
        assert_eq(10, #tokens, "5 identifiers + 4 operators + EOF")
        assert_token(tokens, 1, TOKEN.IDENTIFIER, "a")
        assert_token(tokens, 2, TOKEN.PLUS)
        assert_token(tokens, 3, TOKEN.IDENTIFIER, "b")
        assert_token(tokens, 4, TOKEN.MINUS)
        assert_token(tokens, 5, TOKEN.IDENTIFIER, "c")
    end)

    test("keywords as identifier prefixes", function()
        -- "functionName" should be IDENTIFIER, not FUNCTION
        local tokens = lexer.tokenize("functionName")
        assert_token(tokens, 1, TOKEN.IDENTIFIER, "functionName")
    end)

    test("identifier after keyword", function()
        local tokens = lexer.tokenize("if condition")
        assert_token(tokens, 1, TOKEN.IF)
        assert_token(tokens, 2, TOKEN.IDENTIFIER, "condition")
    end)

    test("very long identifier", function()
        local long_id = string.rep("a", 1000)
        local tokens = lexer.tokenize(long_id)
        assert_token(tokens, 1, TOKEN.IDENTIFIER, long_id)
    end)

    test("single underscore is valid identifier", function()
        local tokens = lexer.tokenize("_")
        assert_token(tokens, 1, TOKEN.IDENTIFIER, "_")
    end)

    test("many consecutive underscores", function()
        local tokens = lexer.tokenize("___")
        assert_token(tokens, 1, TOKEN.IDENTIFIER, "___")
    end)

    test("adjacent literals and operators", function()
        local tokens = lexer.tokenize("1+2*3")
        assert_token(tokens, 1, TOKEN.INTEGER, "1")
        assert_token(tokens, 2, TOKEN.PLUS)
        assert_token(tokens, 3, TOKEN.INTEGER, "2")
        assert_token(tokens, 4, TOKEN.STAR)
        assert_token(tokens, 5, TOKEN.INTEGER, "3")
    end)

    test("nested parentheses", function()
        local tokens = lexer.tokenize("((a))")
        assert_token(tokens, 1, TOKEN.LPAREN)
        assert_token(tokens, 2, TOKEN.LPAREN)
        assert_token(tokens, 3, TOKEN.IDENTIFIER, "a")
        assert_token(tokens, 4, TOKEN.RPAREN)
        assert_token(tokens, 5, TOKEN.RPAREN)
    end)

    test("array indexing", function()
        local tokens = lexer.tokenize("arr[i]")
        assert_token(tokens, 1, TOKEN.IDENTIFIER, "arr")
        assert_token(tokens, 2, TOKEN.LBRACKET)
        assert_token(tokens, 3, TOKEN.IDENTIFIER, "i")
        assert_token(tokens, 4, TOKEN.RBRACKET)
    end)

    test("mixed tabs and spaces", function()
        local tokens = lexer.tokenize("\t  \t  x")
        assert_token(tokens, 1, TOKEN.IDENTIFIER, "x")
    end)

    test("CRLF line endings", function()
        local tokens = lexer.tokenize("a\r\nb")
        assert_token(tokens, 1, TOKEN.IDENTIFIER, "a")
        assert_token(tokens, 2, TOKEN.NEWLINE)
        assert_token(tokens, 3, TOKEN.IDENTIFIER, "b")
    end)

    test("single slash is division, not comment", function()
        local tokens = lexer.tokenize("a / b")
        assert_token(tokens, 2, TOKEN.SLASH)
    end)

    test("double equals vs single equals", function()
        local tokens = lexer.tokenize("= == = ==")
        assert_token(tokens, 1, TOKEN.ASSIGN)
        assert_token(tokens, 2, TOKEN.EQUALS)
        assert_token(tokens, 3, TOKEN.ASSIGN)
        assert_token(tokens, 4, TOKEN.EQUALS)
    end)

    test("less than vs less equals", function()
        local tokens = lexer.tokenize("< <= < <=")
        assert_token(tokens, 1, TOKEN.LESS)
        assert_token(tokens, 2, TOKEN.LESS_EQUALS)
        assert_token(tokens, 3, TOKEN.LESS)
        assert_token(tokens, 4, TOKEN.LESS_EQUALS)
    end)

    test("greater than vs greater equals", function()
        local tokens = lexer.tokenize("> >= > >=")
        assert_token(tokens, 1, TOKEN.GREATER)
        assert_token(tokens, 2, TOKEN.GREATER_EQUALS)
        assert_token(tokens, 3, TOKEN.GREATER)
        assert_token(tokens, 4, TOKEN.GREATER_EQUALS)
    end)

    test("not equals", function()
        local tokens = lexer.tokenize("!=")
        assert_token(tokens, 1, TOKEN.NOT_EQUALS)
    end)
end
-- }}}

-- {{{ Error message tests
local function test_error_messages()
    print("\n-- Error Messages --")

    test("unknown character with line/column", function()
        assert_error_contains(function()
            lexer.tokenize("@")
        end, "line 1")
    end)

    test("unknown character after newlines", function()
        assert_error_contains(function()
            lexer.tokenize("\n\n@")
        end, "line 3")
    end)

    test("unterminated string", function()
        assert_error_contains(function()
            lexer.tokenize('"hello')
        end, "Unterminated string")
    end)

    test("unterminated string with line info", function()
        local ok, err = pcall(function()
            lexer.tokenize('"hello')
        end)
        assert_eq(false, ok, "should error")
        assert(err:find("line"), "should mention line")
    end)

    test("invalid rawcode (too short)", function()
        assert_error_contains(function()
            lexer.tokenize("'abc'")
        end, "4 character")
    end)

    test("unterminated rawcode", function()
        assert_error_contains(function()
            lexer.tokenize("'hfoo")
        end, "closing quote")
    end)

    test("hex literal with no digits", function()
        assert_error_contains(function()
            lexer.tokenize("0x")
        end, "expected digits")
    end)

    test("$ hex with no digits", function()
        assert_error_contains(function()
            lexer.tokenize("$")
        end, "expected digits")
    end)
end
-- }}}

-- {{{ Line and column tracking tests
local function test_position_tracking()
    print("\n-- Position Tracking --")

    test("first token at line 1, column 1", function()
        local tokens = lexer.tokenize("hello")
        assert_eq(1, tokens[1].line, "line")
        assert_eq(1, tokens[1].col, "column")
    end)

    test("token after whitespace", function()
        local tokens = lexer.tokenize("    hello")
        assert_eq(1, tokens[1].line, "line")
        assert_eq(5, tokens[1].col, "column")
    end)

    test("tokens on multiple lines", function()
        local tokens = lexer.tokenize("a\nb\nc")
        assert_eq(1, tokens[1].line, "a line")
        assert_eq(2, tokens[3].line, "b line")
        assert_eq(3, tokens[5].line, "c line")
    end)

    test("column resets after newline", function()
        local tokens = lexer.tokenize("abcd\nxy")
        assert_eq(1, tokens[1].col, "first token col")
        assert_eq(1, tokens[3].col, "token after newline col")
    end)

    test("EOF position", function()
        local tokens = lexer.tokenize("x\n")
        local eof = tokens[#tokens]
        assert_token(tokens, #tokens, TOKEN.EOF)
        assert_eq(2, eof.line, "EOF line")
        assert_eq(1, eof.col, "EOF col")
    end)
end
-- }}}

-- {{{ Integration tests - real JASS patterns
local function test_integration()
    print("\n-- Integration: Real JASS Patterns --")

    test("function declaration", function()
        local code = [[
function MyFunc takes integer x returns boolean
    return x > 0
endfunction
]]
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.FUNCTION)
        assert_token(tokens, 2, TOKEN.IDENTIFIER, "MyFunc")
        assert_token(tokens, 3, TOKEN.TAKES)
        assert_token(tokens, 4, TOKEN.IDENTIFIER, "integer")
        assert_token(tokens, 5, TOKEN.IDENTIFIER, "x")
        assert_token(tokens, 6, TOKEN.RETURNS)
        assert_token(tokens, 7, TOKEN.IDENTIFIER, "boolean")
        assert(find_token_type(tokens, TOKEN.ENDFUNCTION), "should have endfunction")
    end)

    test("globals block", function()
        local code = [[
globals
    integer myVar = 5
    constant real PI = 3.14
endglobals
]]
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.GLOBALS)
        assert(find_token_type(tokens, TOKEN.CONSTANT), "should have constant")
        assert(find_token_type(tokens, TOKEN.ENDGLOBALS), "should have endglobals")
    end)

    test("if-elseif-else-endif", function()
        local code = [[
if x > 0 then
    set y = 1
elseif x < 0 then
    set y = -1
else
    set y = 0
endif
]]
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.IF)
        assert(find_token_type(tokens, TOKEN.THEN), "should have then")
        assert(find_token_type(tokens, TOKEN.ELSEIF), "should have elseif")
        assert(find_token_type(tokens, TOKEN.ELSE), "should have else")
        assert(find_token_type(tokens, TOKEN.ENDIF), "should have endif")
    end)

    test("loop with exitwhen", function()
        local code = [[
loop
    exitwhen i > 10
    set i = i + 1
endloop
]]
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.LOOP)
        assert(find_token_type(tokens, TOKEN.EXITWHEN), "should have exitwhen")
        assert(find_token_type(tokens, TOKEN.ENDLOOP), "should have endloop")
    end)

    test("local variable declaration", function()
        local code = "local integer x = 5"
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.LOCAL)
        assert_token(tokens, 2, TOKEN.IDENTIFIER, "integer")
        assert_token(tokens, 3, TOKEN.IDENTIFIER, "x")
        assert_token(tokens, 4, TOKEN.ASSIGN)
        assert_token(tokens, 5, TOKEN.INTEGER, "5")
    end)

    test("function call", function()
        local code = "call DisplayTextToPlayer(Player(0), 0.0, 0.0, \"Hello\")"
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.CALL)
        assert_token(tokens, 2, TOKEN.IDENTIFIER, "DisplayTextToPlayer")
        assert_token(tokens, 3, TOKEN.LPAREN)
        assert(find_token_type(tokens, TOKEN.STRING), "should have string")
    end)

    test("native declaration", function()
        local code = "native CreateUnit takes player p, integer id, real x, real y, real face returns unit"
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.NATIVE)
        assert_token(tokens, 2, TOKEN.IDENTIFIER, "CreateUnit")
        assert_token(tokens, 3, TOKEN.TAKES)
    end)

    test("type declaration", function()
        local code = "type player extends handle"
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.TYPE)
        assert_token(tokens, 2, TOKEN.IDENTIFIER, "player")
        assert_token(tokens, 3, TOKEN.EXTENDS)
        assert_token(tokens, 4, TOKEN.IDENTIFIER, "handle")
    end)

    test("array declaration and access", function()
        local code = [[
integer array myArray
set myArray[0] = 10
]]
        local tokens = lexer.tokenize(code)
        assert(find_token_type(tokens, TOKEN.ARRAY), "should have array")
        assert(find_token_type(tokens, TOKEN.LBRACKET), "should have [")
        assert(find_token_type(tokens, TOKEN.RBRACKET), "should have ]")
    end)

    test("boolean operators", function()
        local code = "if a and b or not c then"
        local tokens = lexer.tokenize(code)
        assert(find_token_type(tokens, TOKEN.AND), "should have and")
        assert(find_token_type(tokens, TOKEN.OR), "should have or")
        assert(find_token_type(tokens, TOKEN.NOT), "should have not")
    end)

    test("boolean literals", function()
        local code = "set x = true\nset y = false"
        local tokens = lexer.tokenize(code)
        assert(find_token_type(tokens, TOKEN.TRUE), "should have true")
        assert(find_token_type(tokens, TOKEN.FALSE), "should have false")
    end)

    test("null literal", function()
        local code = "set x = null"
        local tokens = lexer.tokenize(code)
        assert(find_token_type(tokens, TOKEN.NULL), "should have null")
    end)

    test("rawcode in function call", function()
        local code = "call CreateUnit(p, 'hfoo', 0.0, 0.0, 270.0)"
        local tokens = lexer.tokenize(code)
        local i = find_token_type(tokens, TOKEN.RAWCODE)
        assert(i, "should have rawcode")
        assert_eq("hfoo", tokens[i].value, "rawcode value")
    end)

    test("comment before code", function()
        local code = [[
// This is a comment
set x = 5
]]
        local tokens = lexer.tokenize(code)
        assert_token(tokens, 1, TOKEN.COMMENT)
        assert(find_token_type(tokens, TOKEN.SET), "should have set")
    end)

    test("inline comment", function()
        local code = "set x = 5 // assign value"
        local tokens = lexer.tokenize(code)
        local comment_i = find_token_type(tokens, TOKEN.COMMENT)
        assert(comment_i, "should have comment")
        assert(comment_i > 1, "comment should be after code")
    end)
end
-- }}}

-- {{{ Fixture file tests
local function test_fixtures()
    print("\n-- Fixture Files --")

    test("keywords.j tokenizes without error", function()
        local content, err = read_fixture("keywords.j")
        if not content then
            print("    [SKIP] " .. err)
            return
        end
        local tokens = lexer.tokenize(content)
        assert(#tokens > 10, "should have many tokens")

        -- Count keyword tokens
        local keyword_count = 0
        for _, t in ipairs(tokens) do
            if t.type ~= TOKEN.IDENTIFIER and t.type ~= TOKEN.NEWLINE
               and t.type ~= TOKEN.COMMENT and t.type ~= TOKEN.EOF then
                keyword_count = keyword_count + 1
            end
        end
        print(string.format("    Found %d keyword tokens", keyword_count))
    end)

    test("operators.j tokenizes without error", function()
        local content, err = read_fixture("operators.j")
        if not content then
            print("    [SKIP] " .. err)
            return
        end
        local tokens = lexer.tokenize(content)
        assert(#tokens > 10, "should have many tokens")

        -- Verify operator types present
        local ops = {TOKEN.PLUS, TOKEN.MINUS, TOKEN.STAR, TOKEN.SLASH,
                     TOKEN.EQUALS, TOKEN.NOT_EQUALS, TOKEN.LESS, TOKEN.GREATER,
                     TOKEN.ASSIGN, TOKEN.LPAREN, TOKEN.RPAREN,
                     TOKEN.LBRACKET, TOKEN.RBRACKET, TOKEN.COMMA}
        for _, op in ipairs(ops) do
            assert(find_token_type(tokens, op), "missing operator: " .. op)
        end
    end)

    test("literals.j tokenizes without error", function()
        local content, err = read_fixture("literals.j")
        if not content then
            print("    [SKIP] " .. err)
            return
        end
        local tokens = lexer.tokenize(content)
        assert(#tokens > 10, "should have many tokens")

        -- Verify literal types present
        assert(find_token_type(tokens, TOKEN.INTEGER), "missing INTEGER")
        assert(find_token_type(tokens, TOKEN.REAL), "missing REAL")
        assert(find_token_type(tokens, TOKEN.STRING), "missing STRING")
        assert(find_token_type(tokens, TOKEN.RAWCODE), "missing RAWCODE")
    end)

    test("comments.j tokenizes without error", function()
        local content, err = read_fixture("comments.j")
        if not content then
            print("    [SKIP] " .. err)
            return
        end
        local tokens = lexer.tokenize(content)
        local comment_count = count_token_type(tokens, TOKEN.COMMENT)
        assert(comment_count > 5, "should have several comments, got " .. comment_count)
        print(string.format("    Found %d comments", comment_count))
    end)

    test("edge_cases.j tokenizes without error", function()
        local content, err = read_fixture("edge_cases.j")
        if not content then
            print("    [SKIP] " .. err)
            return
        end
        local tokens = lexer.tokenize(content)
        assert(#tokens > 20, "should have many tokens")

        -- Check that keywords-as-prefixes are identifiers
        local found_functionName = false
        for _, t in ipairs(tokens) do
            if t.type == TOKEN.IDENTIFIER and t.value == "functionName" then
                found_functionName = true
                break
            end
        end
        assert(found_functionName, "functionName should be IDENTIFIER")
    end)

    test("real_script.j tokenizes without error", function()
        local content, err = read_fixture("real_script.j")
        if not content then
            print("    [SKIP] " .. err)
            return
        end
        local tokens = lexer.tokenize(content)
        assert(#tokens > 100, "should have many tokens")

        -- Verify key structural tokens
        assert(find_token_type(tokens, TOKEN.GLOBALS), "missing globals")
        assert(find_token_type(tokens, TOKEN.ENDGLOBALS), "missing endglobals")
        assert(find_token_type(tokens, TOKEN.FUNCTION), "missing function")
        assert(find_token_type(tokens, TOKEN.ENDFUNCTION), "missing endfunction")
        assert(find_token_type(tokens, TOKEN.NATIVE), "missing native")
        assert(find_token_type(tokens, TOKEN.TYPE), "missing type")

        print(string.format("    Tokenized %d bytes into %d tokens", #content, #tokens))
    end)
end
-- }}}

-- {{{ Performance tests
local function test_performance()
    print("\n-- Performance --")

    test("50k lines in < 5 seconds", function()
        -- Generate ~50k lines of JASS-like code
        local lines = {}
        for i = 1, 50000 do
            lines[i] = string.format("set var%d = %d", i, i)
        end
        local code = table.concat(lines, "\n")

        local start_time = os.clock()
        local tokens = lexer.tokenize(code)
        local elapsed = os.clock() - start_time

        print(string.format("    Tokenized %d lines (%d tokens) in %.3f seconds",
            50000, #tokens, elapsed))

        assert(elapsed < 5, "Too slow: " .. elapsed .. " seconds")
    end)

    test("large function tokenizes efficiently", function()
        -- Generate a large function with many statements
        local lines = {"function LargeFunc takes nothing returns nothing"}
        for i = 1, 10000 do
            lines[#lines + 1] = string.format("    local integer var%d = %d", i, i)
        end
        lines[#lines + 1] = "endfunction"
        local code = table.concat(lines, "\n")

        local start_time = os.clock()
        local tokens = lexer.tokenize(code)
        local elapsed = os.clock() - start_time

        print(string.format("    Large function: %d lines, %d tokens, %.3f seconds",
            #lines, #tokens, elapsed))

        assert(elapsed < 2, "Too slow: " .. elapsed .. " seconds")
    end)

    test("many small strings", function()
        -- Generate many string literals
        local lines = {}
        for i = 1, 10000 do
            lines[i] = string.format('set str%d = "string number %d"', i, i)
        end
        local code = table.concat(lines, "\n")

        local start_time = os.clock()
        local tokens = lexer.tokenize(code)
        local elapsed = os.clock() - start_time

        print(string.format("    String test: %d lines, %d tokens, %.3f seconds",
            10000, #tokens, elapsed))

        assert(elapsed < 2, "Too slow: " .. elapsed .. " seconds")
    end)

    test("deeply nested expressions", function()
        -- Generate deeply nested parentheses
        local depth = 100
        local code = string.rep("(", depth) .. "x" .. string.rep(")", depth)

        local start_time = os.clock()
        local tokens = lexer.tokenize(code)
        local elapsed = os.clock() - start_time

        assert_eq(depth * 2 + 2, #tokens, "token count")  -- ( * depth + x + ) * depth + EOF
        print(string.format("    Nested %d deep: %d tokens, %.4f seconds", depth, #tokens, elapsed))
    end)
end
-- }}}

-- {{{ Real war3map.j test
local function test_real_map_script()
    print("\n-- Real war3map.j (if available) --")

    test("tokenize extracted war3map.j", function()
        -- Check multiple possible locations for a real war3map.j
        local paths = {
            DIR .. "/src/tests/fixtures/jass/war3map.j",
            DIR .. "/output/war3map.j",
            DIR .. "/tmp/war3map.j",
        }

        local content = nil
        local used_path = nil
        for _, path in ipairs(paths) do
            local f = io.open(path, "r")
            if f then
                content = f:read("*a")
                f:close()
                used_path = path
                break
            end
        end

        if not content then
            print("    [SKIP] No war3map.j found at: " .. table.concat(paths, ", "))
            return
        end

        local start_time = os.clock()
        local tokens = lexer.tokenize(content)
        local elapsed = os.clock() - start_time

        -- Basic sanity checks
        assert(#tokens > 100, "Expected substantial token count")
        assert_token(tokens, #tokens, TOKEN.EOF)

        print(string.format("    File: %s", used_path))
        print(string.format("    Tokenized %d bytes into %d tokens in %.3f seconds",
            #content, #tokens, elapsed))

        -- Count some interesting statistics
        local stats = {
            functions = count_token_type(tokens, TOKEN.FUNCTION),
            natives = count_token_type(tokens, TOKEN.NATIVE),
            strings = count_token_type(tokens, TOKEN.STRING),
            rawcodes = count_token_type(tokens, TOKEN.RAWCODE),
            comments = count_token_type(tokens, TOKEN.COMMENT),
        }
        print(string.format("    Stats: %d functions, %d natives, %d strings, %d rawcodes, %d comments",
            stats.functions, stats.natives, stats.strings, stats.rawcodes, stats.comments))
    end)
end
-- }}}

-- {{{ Main
local function main()
    test_edge_cases()
    test_error_messages()
    test_position_tracking()
    test_integration()
    test_fixtures()
    test_performance()
    test_real_map_script()

    print("\n=== Summary ===")
    print(string.format("Tests passed: %d/%d", tests_passed, tests_run))

    if tests_failed > 0 then
        print(string.format("Tests failed: %d", tests_failed))
        print("SOME TESTS FAILED")
        os.exit(1)
    else
        print("All tests passed!")
        os.exit(0)
    end
end

main()
-- }}}
