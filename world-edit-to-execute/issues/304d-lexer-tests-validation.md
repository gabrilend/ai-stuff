# Issue 304d: Lexer Tests and Validation

**Phase:** 3 - Logic Layer
**Type:** Testing
**Priority:** High
**Parent:** 304-build-jass-lexer
**Dependencies:** 304a-lexer-core-infrastructure, 304b-lexer-keywords-identifiers-operators, 304c-lexer-literals

---

## Current Behavior

The JASS lexer components (304a, 304b, 304c) exist but lack comprehensive testing.
No validation that the lexer correctly handles real-world JASS code or edge cases.

---

## Intended Behavior

A comprehensive test suite that validates:

1. **Unit tests** - Each token type individually
2. **Integration tests** - Real JASS code fragments
3. **Edge cases** - Empty input, malformed input, boundary conditions
4. **Error handling** - Clear messages with line/column
5. **Performance** - Handle large files (50k+ lines) efficiently
6. **Real-world validation** - Test against actual war3map.j content

---

## Suggested Implementation Steps

1. **Create test file structure**
   ```
   src/tests/
   └── test_jass_lexer.lua

   src/tests/fixtures/
   └── jass/
       ├── keywords.j         # All keywords
       ├── operators.j        # All operators
       ├── literals.j         # Number/string/rawcode samples
       ├── comments.j         # Comment variations
       ├── edge_cases.j       # Tricky inputs
       └── real_script.j      # Extracted from actual map
   ```

2. **Implement test harness**
   ```lua
   -- {{{ test harness
   local lexer = require("jass.lexer")
   local TOKEN = lexer.TOKEN

   local tests_run = 0
   local tests_passed = 0
   local tests_failed = 0

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

   local function assert_eq(expected, actual, msg)
       if expected ~= actual then
           error(string.format("%s: expected %s, got %s",
               msg or "Assertion failed",
               tostring(expected),
               tostring(actual)))
       end
   end

   local function assert_token(token, expected_type, expected_value)
       assert_eq(expected_type, token.type, "Token type mismatch")
       if expected_value then
           assert_eq(expected_value, token.value, "Token value mismatch")
       end
   end
   -- }}}
   ```

3. **Write keyword tests**
   ```lua
   -- {{{ test_keywords
   local function test_keywords()
       print("Testing keywords...")

       test("function keyword", function()
           local tokens = lexer.tokenize("function")
           assert_eq(2, #tokens)  -- FUNCTION + EOF
           assert_token(tokens[1], TOKEN.FUNCTION, "function")
       end)

       test("all keywords", function()
           local keywords = {
               "function", "endfunction", "takes", "returns", "nothing",
               "globals", "endglobals", "local", "set", "call",
               "if", "then", "else", "elseif", "endif",
               "loop", "endloop", "exitwhen", "return",
               "constant", "native", "type", "extends", "array",
               "and", "or", "not", "true", "false", "null"
           }
           for _, kw in ipairs(keywords) do
               local tokens = lexer.tokenize(kw)
               assert_eq(2, #tokens, "Expected 2 tokens for: " .. kw)
               -- Token type should match uppercase keyword
               assert_eq(kw:upper(), tokens[1].type,
                   "Keyword type mismatch for: " .. kw)
           end
       end)

       test("case sensitivity", function()
           local tokens = lexer.tokenize("Function FUNCTION function")
           assert_token(tokens[1], TOKEN.IDENTIFIER, "Function")
           assert_token(tokens[2], TOKEN.IDENTIFIER, "FUNCTION")
           assert_token(tokens[3], TOKEN.FUNCTION, "function")
       end)
   end
   -- }}}
   ```

4. **Write identifier tests**
   ```lua
   -- {{{ test_identifiers
   local function test_identifiers()
       print("Testing identifiers...")

       test("simple identifier", function()
           local tokens = lexer.tokenize("myVar")
           assert_token(tokens[1], TOKEN.IDENTIFIER, "myVar")
       end)

       test("underscore start", function()
           local tokens = lexer.tokenize("_private")
           assert_token(tokens[1], TOKEN.IDENTIFIER, "_private")
       end)

       test("with numbers", function()
           local tokens = lexer.tokenize("var123")
           assert_token(tokens[1], TOKEN.IDENTIFIER, "var123")
       end)

       test("underscore and numbers", function()
           local tokens = lexer.tokenize("_test_123_abc")
           assert_token(tokens[1], TOKEN.IDENTIFIER, "_test_123_abc")
       end)

       test("single letter", function()
           local tokens = lexer.tokenize("x")
           assert_token(tokens[1], TOKEN.IDENTIFIER, "x")
       end)

       test("single underscore", function()
           local tokens = lexer.tokenize("_")
           assert_token(tokens[1], TOKEN.IDENTIFIER, "_")
       end)
   end
   -- }}}
   ```

5. **Write operator tests**
   ```lua
   -- {{{ test_operators
   local function test_operators()
       print("Testing operators...")

       test("arithmetic operators", function()
           local tokens = lexer.tokenize("+ - * /")
           assert_token(tokens[1], TOKEN.PLUS)
           assert_token(tokens[2], TOKEN.MINUS)
           assert_token(tokens[3], TOKEN.STAR)
           assert_token(tokens[4], TOKEN.SLASH)
       end)

       test("comparison operators", function()
           local tokens = lexer.tokenize("== != < <= > >=")
           assert_token(tokens[1], TOKEN.EQUALS)
           assert_token(tokens[2], TOKEN.NOT_EQUALS)
           assert_token(tokens[3], TOKEN.LESS)
           assert_token(tokens[4], TOKEN.LESS_EQUALS)
           assert_token(tokens[5], TOKEN.GREATER)
           assert_token(tokens[6], TOKEN.GREATER_EQUALS)
       end)

       test("assignment", function()
           local tokens = lexer.tokenize("=")
           assert_token(tokens[1], TOKEN.ASSIGN)
       end)

       test("equals vs assign", function()
           local tokens = lexer.tokenize("= ==")
           assert_token(tokens[1], TOKEN.ASSIGN)
           assert_token(tokens[2], TOKEN.EQUALS)
       end)

       test("operators without spaces", function()
           local tokens = lexer.tokenize("a+b*c")
           assert_token(tokens[1], TOKEN.IDENTIFIER)
           assert_token(tokens[2], TOKEN.PLUS)
           assert_token(tokens[3], TOKEN.IDENTIFIER)
           assert_token(tokens[4], TOKEN.STAR)
           assert_token(tokens[5], TOKEN.IDENTIFIER)
       end)
   end
   -- }}}
   ```

6. **Write literal tests**
   ```lua
   -- {{{ test_literals
   local function test_literals()
       print("Testing literals...")

       -- Integers
       test("decimal integer", function()
           local tokens = lexer.tokenize("123")
           assert_token(tokens[1], TOKEN.INTEGER, "123")
       end)

       test("zero", function()
           local tokens = lexer.tokenize("0")
           assert_token(tokens[1], TOKEN.INTEGER, "0")
       end)

       test("hex 0x prefix", function()
           local tokens = lexer.tokenize("0x1F")
           assert_token(tokens[1], TOKEN.INTEGER, "0x1F")
       end)

       test("hex $ prefix", function()
           local tokens = lexer.tokenize("$FF")
           assert_token(tokens[1], TOKEN.INTEGER, "$FF")
       end)

       -- Reals
       test("real standard", function()
           local tokens = lexer.tokenize("1.5")
           assert_token(tokens[1], TOKEN.REAL, "1.5")
       end)

       test("real leading dot", function()
           local tokens = lexer.tokenize(".5")
           assert_token(tokens[1], TOKEN.REAL, ".5")
       end)

       test("real trailing dot", function()
           local tokens = lexer.tokenize("1.")
           assert_token(tokens[1], TOKEN.REAL, "1.")
       end)

       -- Strings
       test("simple string", function()
           local tokens = lexer.tokenize('"hello"')
           assert_token(tokens[1], TOKEN.STRING, "hello")
       end)

       test("empty string", function()
           local tokens = lexer.tokenize('""')
           assert_token(tokens[1], TOKEN.STRING, "")
       end)

       test("string escapes", function()
           local tokens = lexer.tokenize('"line1\\nline2"')
           assert_token(tokens[1], TOKEN.STRING, "line1\nline2")
       end)

       -- Rawcodes
       test("rawcode", function()
           local tokens = lexer.tokenize("'hfoo'")
           assert_token(tokens[1], TOKEN.RAWCODE, "hfoo")
       end)

       test("rawcode uppercase", function()
           local tokens = lexer.tokenize("'AHbz'")
           assert_token(tokens[1], TOKEN.RAWCODE, "AHbz")
       end)
   end
   -- }}}
   ```

7. **Write comment tests**
   ```lua
   -- {{{ test_comments
   local function test_comments()
       print("Testing comments...")

       test("single line comment", function()
           local tokens = lexer.tokenize("// this is a comment")
           assert_token(tokens[1], TOKEN.COMMENT)
       end)

       test("comment preserves content", function()
           local tokens = lexer.tokenize("// hello world")
           assert_eq(" hello world", tokens[1].value)
       end)

       test("code then comment", function()
           local tokens = lexer.tokenize("set x = 1 // assign")
           -- Should have: SET, IDENTIFIER, ASSIGN, INTEGER, COMMENT, EOF
           assert_token(tokens[1], TOKEN.SET)
           assert_token(tokens[5], TOKEN.COMMENT)
       end)

       test("slash not comment", function()
           local tokens = lexer.tokenize("a / b")
           assert_token(tokens[2], TOKEN.SLASH)
       end)
   end
   -- }}}
   ```

8. **Write edge case tests**
   ```lua
   -- {{{ test_edge_cases
   local function test_edge_cases()
       print("Testing edge cases...")

       test("empty input", function()
           local tokens = lexer.tokenize("")
           assert_eq(1, #tokens)
           assert_token(tokens[1], TOKEN.EOF)
       end)

       test("only whitespace", function()
           local tokens = lexer.tokenize("   \t\t   ")
           assert_eq(1, #tokens)
           assert_token(tokens[1], TOKEN.EOF)
       end)

       test("only newlines", function()
           local tokens = lexer.tokenize("\n\n\n")
           assert_eq(4, #tokens)  -- 3 NEWLINE + EOF
       end)

       test("unterminated string error", function()
           local ok, err = pcall(function()
               lexer.tokenize('"unterminated')
           end)
           assert_eq(false, ok)
           assert(err:find("Unterminated"), "Expected unterminated string error")
       end)

       test("invalid rawcode length", function()
           local ok, err = pcall(function()
               lexer.tokenize("'abc'")  -- Only 3 chars
           end)
           assert_eq(false, ok)
           assert(err:find("rawcode"), "Expected rawcode error")
       end)

       test("line tracking", function()
           local tokens = lexer.tokenize("a\nb\nc")
           assert_eq(1, tokens[1].line)  -- 'a' on line 1
           assert_eq(2, tokens[3].line)  -- 'b' on line 2
           assert_eq(3, tokens[5].line)  -- 'c' on line 3
       end)

       test("column tracking", function()
           local tokens = lexer.tokenize("abc def")
           assert_eq(1, tokens[1].col)   -- 'abc' starts at col 1
           assert_eq(5, tokens[2].col)   -- 'def' starts at col 5
       end)
   end
   -- }}}
   ```

9. **Write integration tests with real JASS**
   ```lua
   -- {{{ test_real_jass
   local function test_real_jass()
       print("Testing real JASS code...")

       test("function declaration", function()
           local code = [[
function MyFunc takes integer x returns boolean
    return x > 0
endfunction
]]
           local tokens = lexer.tokenize(code)
           assert_token(tokens[1], TOKEN.FUNCTION)
           assert_token(tokens[2], TOKEN.IDENTIFIER, "MyFunc")
           assert_token(tokens[3], TOKEN.TAKES)
       end)

       test("variable declaration and assignment", function()
           local code = "local integer x = 5"
           local tokens = lexer.tokenize(code)
           assert_token(tokens[1], TOKEN.LOCAL)
           assert_token(tokens[2], TOKEN.IDENTIFIER, "integer")
           assert_token(tokens[3], TOKEN.IDENTIFIER, "x")
           assert_token(tokens[4], TOKEN.ASSIGN)
           assert_token(tokens[5], TOKEN.INTEGER, "5")
       end)

       test("if statement", function()
           local code = [[
if x > 0 then
    call DoSomething()
endif
]]
           local tokens = lexer.tokenize(code)
           assert_token(tokens[1], TOKEN.IF)
           assert_token(tokens[6], TOKEN.THEN)
           assert_token(tokens[8], TOKEN.CALL)
       end)

       test("loop with exitwhen", function()
           local code = [[
loop
    exitwhen i > 10
    set i = i + 1
endloop
]]
           local tokens = lexer.tokenize(code)
           assert_token(tokens[1], TOKEN.LOOP)
           -- Find EXITWHEN
           local found_exitwhen = false
           for _, tok in ipairs(tokens) do
               if tok.type == TOKEN.EXITWHEN then
                   found_exitwhen = true
                   break
               end
           end
           assert(found_exitwhen, "Expected EXITWHEN token")
       end)
   end
   -- }}}
   ```

10. **Write performance test**
    ```lua
    -- {{{ test_performance
    local function test_performance()
        print("Testing performance...")

        test("large input", function()
            -- Generate ~50k lines of JASS
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

            -- Should complete in reasonable time (< 5 seconds)
            assert(elapsed < 5, "Performance too slow: " .. elapsed .. " seconds")
        end)
    end
    -- }}}
    ```

11. **Test with actual war3map.j content**
    ```lua
    -- {{{ test_real_map_script
    local function test_real_map_script()
        print("Testing real map script...")

        test("tokenize extracted war3map.j", function()
            -- This test requires a war3map.j file extracted via issue 303
            local fixture_path = "src/tests/fixtures/jass/real_script.j"
            local f = io.open(fixture_path, "r")
            if not f then
                print("    [SKIP] No fixture file at " .. fixture_path)
                return
            end

            local code = f:read("*a")
            f:close()

            local tokens = lexer.tokenize(code)

            -- Basic sanity checks
            assert(#tokens > 100, "Expected substantial token count")
            assert(tokens[#tokens].type == TOKEN.EOF, "Should end with EOF")

            print(string.format("    Tokenized %d bytes into %d tokens",
                #code, #tokens))
        end)
    end
    -- }}}
    ```

12. **Main test runner**
    ```lua
    -- {{{ main
    local function main()
        print("=== JASS Lexer Test Suite ===\n")

        test_keywords()
        test_identifiers()
        test_operators()
        test_literals()
        test_comments()
        test_edge_cases()
        test_real_jass()
        test_performance()
        test_real_map_script()

        print(string.format("\n=== Results: %d passed, %d failed, %d total ===",
            tests_passed, tests_failed, tests_run))

        if tests_failed > 0 then
            os.exit(1)
        end
    end

    main()
    -- }}}
    ```

---

## Test Fixtures to Create

### fixtures/jass/keywords.j
```jass
function endfunction takes returns nothing
globals endglobals local set call
if then else elseif endif
loop endloop exitwhen return
constant native type extends array
and or not true false null
```

### fixtures/jass/literals.j
```jass
// Integers
0 123 999999
0x1F 0XFF $AB

// Reals
1.5 .5 1. 0.0

// Strings
"hello" "" "with\nnewline" "with\"quote"

// Rawcodes
'hfoo' 'AHbz' 'A000'
```

### fixtures/jass/edge_cases.j
```jass
// Empty lines


// Consecutive operators
+-*/
a+b-c*d/e

// Keywords as part of identifiers
functionName ifCondition loopCounter

// Very long identifier
abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789
```

---

## Related Documents

- issues/304-build-jass-lexer.md (parent issue)
- issues/304a-lexer-core-infrastructure.md (tested component)
- issues/304b-lexer-keywords-identifiers-operators.md (tested component)
- issues/304c-lexer-literals.md (tested component)
- issues/303-parse-war3map-j.md (provides real test data)
- src/tests/test_mpq.lua (example test structure)

---

## Acceptance Criteria

- [x] Test file exists at src/tests/test_jass_lexer.lua
- [x] Test fixtures created in src/tests/fixtures/jass/
- [x] All keyword tokens tested
- [x] All identifier patterns tested
- [x] All operator tokens tested
- [x] All literal types tested (integers, reals, strings, rawcodes)
- [x] Comment handling tested
- [x] Newline handling tested
- [x] Empty input handled
- [x] Unterminated string produces error with line/column
- [x] Invalid rawcode produces error with line/column
- [x] Line and column tracking verified
- [x] Performance test with 50k lines completes in < 5 seconds
- [x] Real war3map.j content tokenizes successfully (if fixture available)
- [x] All tests pass with zero failures
- [x] Test can be run via: `lua src/tests/test_jass_lexer.lua`

---

## Notes

This test suite serves multiple purposes:

1. **Validation** - Ensure the lexer works correctly
2. **Documentation** - Tests show expected behavior
3. **Regression prevention** - Catch bugs introduced by changes
4. **Integration check** - Real JASS content validates completeness

The test structure mirrors the existing test_mpq.lua pattern for consistency.
Consider adding this to the Phase 3 demo script once complete.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created

1. **src/tests/test_jass_lexer.lua** (450+ lines)
   - Comprehensive test suite with 58 tests
   - Edge case testing (19 tests)
   - Error message testing (8 tests)
   - Position tracking testing (5 tests)
   - Integration testing with real JASS patterns (15 tests)
   - Fixture file validation (6 tests)
   - Performance testing (4 tests)
   - Real war3map.j support (1 test, skips if file not available)

2. **src/tests/fixtures/jass/** directory with 6 fixture files:
   - `keywords.j` - All JASS keywords in context
   - `operators.j` - All operators and punctuation
   - `literals.j` - All literal types (integers, reals, strings, rawcodes)
   - `comments.j` - Comment variations and edge cases
   - `edge_cases.j` - Tricky inputs and boundary conditions
   - `real_script.j` - Realistic JASS script (~3.7KB, 639 tokens)

### Test Results

```
Total lexer tests: 195
- test_jass_lexer.lua: 58 tests (comprehensive)
- test_lexer_core.lua: 28 tests (core infrastructure)
- test_lexer_keywords.lua: 56 tests (keywords/identifiers/operators)
- test_lexer_literals.lua: 53 tests (literals)
```

### Performance Results

- 50k lines: 1.265 seconds (250,000 tokens)
- 10k-line function: 0.402 seconds (60,009 tokens)
- 10k string literals: 0.482 seconds (50,000 tokens)
- 100-deep nesting: 0.0008 seconds (202 tokens)

All performance tests complete well under the 5-second threshold.

### Key Design Decisions

1. **Separate fixture files** - Allows easy inspection and modification of test inputs
2. **Real script fixture** - Mimics actual war3map.j structure for realistic testing
3. **Optional war3map.j test** - Gracefully skips if no extracted file available
4. **Statistics output** - Performance tests print timing for visibility
5. **Helper functions** - `find_token_type()` and `count_token_type()` for cleaner assertions
