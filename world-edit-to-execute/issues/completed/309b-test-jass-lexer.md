# Issue 309b: Test JASS Lexer

**Phase:** 3 - Logic Layer
**Type:** Test
**Priority:** High
**Dependencies:** 304-build-jass-lexer
**Parent Issue:** 309-phase-3-integration-test

---

## Current Behavior

The JASS lexer (304) is implemented but has no comprehensive test suite
verifying all token types and edge cases.

---

## Intended Behavior

A comprehensive test suite for the JASS lexer covering:
- All token types (keywords, operators, literals)
- Edge cases (empty input, comments, whitespace)
- Error handling for invalid tokens
- Line/column tracking accuracy

```bash
# Run lexer tests
luajit src/tests/test_309b_lexer.lua

# Expected output:
# === Keyword Tests ===
#   [PASS] function keyword
#   [PASS] endfunction keyword
#   ...
# === Literal Tests ===
#   [PASS] Integer literal
#   [PASS] Real literal
#   ...
# === Edge Case Tests ===
#   [PASS] Empty input
#   [PASS] Comments ignored
#   ...
# ALL TESTS PASSED
```

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```lua
   #!/usr/bin/env luajit
   -- {{{ test_309b_lexer.lua
   -- Comprehensive tests for JASS lexer
   -- Run from project root: luajit src/tests/test_309b_lexer.lua

   local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
   package.path = DIR .. "/src/?.lua;" .. package.path

   local lexer = require("jass.lexer")
   local TOKEN = lexer.TOKEN
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

   -- Helper: get first token from input
   local function first_token(input)
       local tokens = lexer.tokenize(input)
       return tokens and tokens[1]
   end

   -- Helper: check token type
   local function is_token_type(input, expected_type)
       local tok = first_token(input)
       return tok and tok.type == expected_type
   end

   -- Helper: check token value
   local function token_value(input)
       local tok = first_token(input)
       return tok and tok.value
   end
   -- }}}
   ```

3. **Test keywords**
   ```lua
   -- {{{ Keyword Tests
   test_section("Keyword Tests")

   local keywords = {
       {"function", TOKEN.FUNCTION},
       {"endfunction", TOKEN.ENDFUNCTION},
       {"takes", TOKEN.TAKES},
       {"returns", TOKEN.RETURNS},
       {"nothing", TOKEN.NOTHING},
       {"globals", TOKEN.GLOBALS},
       {"endglobals", TOKEN.ENDGLOBALS},
       {"local", TOKEN.LOCAL},
       {"constant", TOKEN.CONSTANT},
       {"native", TOKEN.NATIVE},
       {"type", TOKEN.TYPE},
       {"extends", TOKEN.EXTENDS},
       {"array", TOKEN.ARRAY},
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
       {"debug", TOKEN.DEBUG},
       {"and", TOKEN.AND},
       {"or", TOKEN.OR},
       {"not", TOKEN.NOT},
       {"true", TOKEN.TRUE},
       {"false", TOKEN.FALSE},
       {"null", TOKEN.NULL},
   }

   for _, kw in ipairs(keywords) do
       local input, expected = kw[1], kw[2]
       test(input .. " keyword", is_token_type(input, expected))
   end

   -- Case sensitivity (JASS keywords are case-insensitive)
   test("FUNCTION uppercase", is_token_type("FUNCTION", TOKEN.FUNCTION))
   test("Function mixed case", is_token_type("Function", TOKEN.FUNCTION))
   -- }}}
   ```

4. **Test operators and punctuation**
   ```lua
   -- {{{ Operator Tests
   test_section("Operator Tests")

   local operators = {
       {"+", TOKEN.PLUS},
       {"-", TOKEN.MINUS},
       {"*", TOKEN.STAR},
       {"/", TOKEN.SLASH},
       {"=", TOKEN.EQUALS},
       {"==", TOKEN.EQUAL_EQUAL},
       {"!=", TOKEN.BANG_EQUAL},
       {"<", TOKEN.LESS},
       {"<=", TOKEN.LESS_EQUAL},
       {">", TOKEN.GREATER},
       {">=", TOKEN.GREATER_EQUAL},
       {"(", TOKEN.LPAREN},
       {")", TOKEN.RPAREN},
       {"[", TOKEN.LBRACKET},
       {"]", TOKEN.RBRACKET},
       {",", TOKEN.COMMA},
   }

   for _, op in ipairs(operators) do
       local input, expected = op[1], op[2]
       test("Operator " .. input, is_token_type(input, expected))
   end
   -- }}}
   ```

5. **Test literals**
   ```lua
   -- {{{ Literal Tests
   test_section("Literal Tests")

   -- Integer literals
   test("Integer 0", is_token_type("0", TOKEN.INTEGER))
   test("Integer 123", is_token_type("123", TOKEN.INTEGER))
   test("Integer value", token_value("42") == 42)
   test("Hex integer", is_token_type("0x1F", TOKEN.INTEGER))
   test("Hex value", token_value("0xFF") == 255)
   test("Octal integer", is_token_type("0777", TOKEN.INTEGER))

   -- Real literals
   test("Real 3.14", is_token_type("3.14", TOKEN.REAL))
   test("Real .5", is_token_type(".5", TOKEN.REAL))
   test("Real 5.", is_token_type("5.", TOKEN.REAL))
   test("Real value", math.abs(token_value("3.14") - 3.14) < 0.001)

   -- String literals
   test("String basic", is_token_type('"hello"', TOKEN.STRING))
   test("String value", token_value('"hello"') == "hello")
   test("String empty", token_value('""') == "")
   test("String escape", token_value('"a\\nb"') == "a\nb")
   test("String with quotes", token_value('"say \\"hi\\""') == 'say "hi"')

   -- Rawcode (FourCC) literals
   test("Rawcode basic", is_token_type("'hfoo'", TOKEN.RAWCODE))
   test("Rawcode value type", type(token_value("'hfoo'")) == "string" or
                              type(token_value("'hfoo'")) == "number")

   -- Boolean literals
   test("Boolean true", is_token_type("true", TOKEN.TRUE))
   test("Boolean false", is_token_type("false", TOKEN.FALSE))

   -- Null literal
   test("Null literal", is_token_type("null", TOKEN.NULL))
   -- }}}
   ```

6. **Test identifiers**
   ```lua
   -- {{{ Identifier Tests
   test_section("Identifier Tests")

   test("Simple identifier", is_token_type("myVar", TOKEN.IDENTIFIER))
   test("Underscore start", is_token_type("_hidden", TOKEN.IDENTIFIER))
   test("Mixed case", is_token_type("MyVariable", TOKEN.IDENTIFIER))
   test("With numbers", is_token_type("unit1", TOKEN.IDENTIFIER))
   test("Underscore in middle", is_token_type("my_var", TOKEN.IDENTIFIER))

   -- Identifier value preservation
   test("Identifier value", token_value("myVar") == "myVar")
   test("Case preserved", token_value("MyVar") == "MyVar")

   -- Not identifiers
   test("Number start not id", not is_token_type("1unit", TOKEN.IDENTIFIER))
   -- }}}
   ```

7. **Test comments**
   ```lua
   -- {{{ Comment Tests
   test_section("Comment Tests")

   -- Single-line comments
   local tokens = lexer.tokenize("x // comment\ny")
   test("Line comment ignored", #tokens == 2)  -- x and y only

   tokens = lexer.tokenize("// full line comment\nx")
   test("Full line comment", #tokens == 1 and tokens[1].value == "x")

   -- Comments don't affect next token
   tokens = lexer.tokenize("x // comment")
   test("Comment at end", #tokens == 1)

   -- Multiple comments
   tokens = lexer.tokenize("// a\n// b\nx")
   test("Multiple comments", #tokens == 1)
   -- }}}
   ```

8. **Test whitespace handling**
   ```lua
   -- {{{ Whitespace Tests
   test_section("Whitespace Tests")

   -- Spaces
   local tokens = lexer.tokenize("  x  y  ")
   test("Spaces ignored", #tokens == 2)

   -- Tabs
   tokens = lexer.tokenize("\tx\t")
   test("Tabs ignored", #tokens == 1)

   -- Newlines (significant for line tracking)
   tokens = lexer.tokenize("x\ny")
   test("Newlines separate", #tokens == 2)

   -- Mixed whitespace
   tokens = lexer.tokenize("  \t\n  x  \t\n  ")
   test("Mixed whitespace", #tokens == 1)
   -- }}}
   ```

9. **Test line/column tracking**
   ```lua
   -- {{{ Position Tests
   test_section("Position Tests")

   local source = "x\ny\nz"
   local tokens = lexer.tokenize(source)

   test("First token line", tokens[1].line == 1)
   test("Second token line", tokens[2].line == 2)
   test("Third token line", tokens[3].line == 3)

   source = "abc def"
   tokens = lexer.tokenize(source)
   test("First token column", tokens[1].column == 1)
   test("Second token column", tokens[2].column == 5)

   -- After comment
   source = "x // comment\ny"
   tokens = lexer.tokenize(source)
   test("After comment line", tokens[2].line == 2)
   -- }}}
   ```

10. **Test complete JASS snippets**
    ```lua
    -- {{{ Integration Tests
    test_section("Integration Tests")

    local source = [[
    function Test takes integer x returns boolean
        local integer i = 0
        set i = x + 1
        if i > 10 then
            return true
        endif
        return false
    endfunction
    ]]

    local tokens = lexer.tokenize(source)
    test("Function tokenizes", #tokens > 0)

    -- Verify token sequence starts correctly
    test("Starts with function", tokens[1].type == TOKEN.FUNCTION)
    test("Has identifier", tokens[2].type == TOKEN.IDENTIFIER)
    test("Has takes", tokens[3].type == TOKEN.TAKES)

    -- Count specific tokens
    local keyword_count = 0
    local identifier_count = 0
    for _, tok in ipairs(tokens) do
        if tok.type == TOKEN.FUNCTION or tok.type == TOKEN.IF or
           tok.type == TOKEN.RETURN or tok.type == TOKEN.SET then
            keyword_count = keyword_count + 1
        elseif tok.type == TOKEN.IDENTIFIER then
            identifier_count = identifier_count + 1
        end
    end

    test("Has keywords", keyword_count >= 5)
    test("Has identifiers", identifier_count >= 5)
    -- }}}
    ```

11. **Test edge cases and errors**
    ```lua
    -- {{{ Edge Case Tests
    test_section("Edge Case Tests")

    -- Empty input
    local tokens = lexer.tokenize("")
    test("Empty input", tokens ~= nil and #tokens == 0)

    -- Whitespace only
    tokens = lexer.tokenize("   \n\t  ")
    test("Whitespace only", #tokens == 0)

    -- Unterminated string
    tokens = lexer.tokenize('"hello')
    test("Unterminated string handled", tokens ~= nil)
    -- May produce error token or partial token

    -- Invalid character
    tokens = lexer.tokenize("x @ y")
    test("Invalid character handled", tokens ~= nil)
    -- Should produce tokens for x and y, possibly error for @

    -- Very long identifier
    local long_id = string.rep("a", 1000)
    tokens = lexer.tokenize(long_id)
    test("Long identifier", #tokens == 1 and #tokens[1].value == 1000)

    -- Consecutive operators
    tokens = lexer.tokenize("a==b")
    test("Consecutive operators", #tokens == 3)

    -- Numbers with operators
    tokens = lexer.tokenize("1+2")
    test("Number op number", #tokens == 3)
    -- }}}
    ```

12. **Summary and exit**
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

### Token Types to Test

| Category | Tokens |
|----------|--------|
| Keywords | function, if, loop, set, call, return, etc. |
| Operators | +, -, *, /, ==, !=, <, <=, >, >= |
| Punctuation | (, ), [, ], , |
| Literals | INTEGER, REAL, STRING, RAWCODE, TRUE, FALSE, NULL |
| Identifiers | Variable and function names |

### JASS Lexer Specifics

- Keywords are case-insensitive
- Comments start with `//` and extend to end of line
- Strings use double quotes with backslash escapes
- Rawcodes use single quotes with exactly 4 characters
- Identifiers start with letter or underscore

### Error Handling

The lexer should not crash on invalid input. Instead:
- Return an ERROR token for unrecognized characters
- Return partial token for unterminated strings
- Continue lexing after errors when possible

---

## Related Documents

- issues/309-phase-3-integration-test.md (parent issue)
- issues/304-build-jass-lexer.md (lexer implementation)
- issues/309c-test-jass-parser.md (parser tests, uses lexer output)
- src/jass/lexer.lua (implementation)

---

## Acceptance Criteria

- [ ] Test file created at src/tests/test_309b_lexer.lua
- [ ] All keywords tested (30+ keywords)
- [ ] All operators tested (15+ operators)
- [ ] Integer literals tested (decimal, hex, octal)
- [ ] Real literals tested (various formats)
- [ ] String literals tested (escapes, empty, quotes)
- [ ] Rawcode literals tested
- [ ] Boolean and null literals tested
- [ ] Identifiers tested (valid and edge cases)
- [ ] Comments correctly ignored
- [ ] Whitespace correctly handled
- [ ] Line/column tracking verified
- [ ] Complete JASS snippet tokenizes correctly
- [ ] Edge cases don't crash lexer
- [ ] All tests pass with zero failures

---

## Notes

The lexer is the first stage of the JASS processing pipeline. It must be
rock-solid because the parser depends on correct tokenization.

Tests focus on:
1. Correctness - right token types for all inputs
2. Completeness - all JASS constructs covered
3. Robustness - handles errors gracefully
4. Accuracy - line/column tracking for error messages

The TOKEN constants should be exported by the lexer module for use in
tests and parser.

