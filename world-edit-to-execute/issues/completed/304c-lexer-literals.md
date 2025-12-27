# Issue 304c: Lexer Literals

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 304-build-jass-lexer
**Dependencies:** 304a-lexer-core-infrastructure

---

## Current Behavior

The lexer core infrastructure (304a) provides the scanning framework. Keywords,
identifiers, and operators are handled by 304b. However, the lexer cannot yet
tokenize literal values: numbers, strings, and rawcodes.

---

## Intended Behavior

Extend the lexer to recognize and tokenize all JASS literal types:

1. **Integer literals**
   - Decimal: `123`, `0`, `42`
   - Hexadecimal: `0x1F`, `0X1f`, `$1F`
   - Octal: `017` (leading zero)

2. **Real literals**
   - Standard: `1.5`, `123.456`
   - No leading digit: `.5`, `.123`
   - No trailing digit: `1.`, `123.`

3. **String literals**
   - Double-quoted: `"hello world"`
   - Escape sequences: `\n`, `\r`, `\t`, `\\`, `\"`

4. **Rawcode literals**
   - Single-quoted 4-char: `'hfoo'`, `'AHbz'`
   - Represents 4-byte integer (used for unit/ability IDs)

---

## Suggested Implementation Steps

1. **Implement integer scanner**
   ```lua
   -- {{{ scan_integer
   local function scan_integer(state, start_line, start_col)
       local chars = {}
       local char = peek(state)

       -- Check for hex prefix
       if char == "0" and (peek(state, 1) == "x" or peek(state, 1) == "X") then
           chars[#chars + 1] = advance(state)  -- '0'
           chars[#chars + 1] = advance(state)  -- 'x' or 'X'
           -- Collect hex digits
           while not is_at_end(state) and is_hex_digit(peek(state)) do
               chars[#chars + 1] = advance(state)
           end
           if #chars == 2 then
               error(string.format(
                   "Invalid hex literal at line %d, column %d: expected digits after '0x'",
                   start_line, start_col
               ))
           end
           add_token(state, TOKEN.INTEGER, table.concat(chars), start_line, start_col)
           return true
       end

       -- Check for $ hex prefix (alternate syntax)
       if char == "$" then
           chars[#chars + 1] = advance(state)  -- '$'
           while not is_at_end(state) and is_hex_digit(peek(state)) do
               chars[#chars + 1] = advance(state)
           end
           if #chars == 1 then
               error(string.format(
                   "Invalid hex literal at line %d, column %d: expected digits after '$'",
                   start_line, start_col
               ))
           end
           add_token(state, TOKEN.INTEGER, table.concat(chars), start_line, start_col)
           return true
       end

       -- Decimal or octal (leading zero)
       -- Note: We don't distinguish at lexer level - parser/evaluator handles octal
       while not is_at_end(state) and is_digit(peek(state)) do
           chars[#chars + 1] = advance(state)
       end

       -- Check if this is actually a real number
       if peek(state) == "." and is_digit(peek(state, 1)) then
           -- This is a real, not an integer - let scan_real handle it
           -- But we've already consumed digits, so we need to continue here
           chars[#chars + 1] = advance(state)  -- '.'
           while not is_at_end(state) and is_digit(peek(state)) do
               chars[#chars + 1] = advance(state)
           end
           add_token(state, TOKEN.REAL, table.concat(chars), start_line, start_col)
           return true
       end

       -- Check for trailing dot (real without fractional part)
       if peek(state) == "." and not is_digit(peek(state, 1)) then
           chars[#chars + 1] = advance(state)  -- '.'
           add_token(state, TOKEN.REAL, table.concat(chars), start_line, start_col)
           return true
       end

       add_token(state, TOKEN.INTEGER, table.concat(chars), start_line, start_col)
       return true
   end
   -- }}}
   ```

2. **Implement hex digit helper**
   ```lua
   -- {{{ is_hex_digit
   local function is_hex_digit(char)
       if not char then return false end
       local b = string.byte(char)
       return (b >= 48 and b <= 57)   -- 0-9
           or (b >= 65 and b <= 70)   -- A-F
           or (b >= 97 and b <= 102)  -- a-f
   end
   -- }}}
   ```

3. **Implement real number scanner for leading dot**
   ```lua
   -- {{{ scan_real_from_dot
   local function scan_real_from_dot(state, start_line, start_col)
       -- Called when we see a '.' that might start a number like .5
       local chars = {}
       chars[#chars + 1] = advance(state)  -- '.'

       if not is_digit(peek(state)) then
           -- This is not a number - might be an error or other syntax
           -- Push back? For now, error
           error(string.format(
               "Unexpected '.' at line %d, column %d",
               start_line, start_col
           ))
       end

       while not is_at_end(state) and is_digit(peek(state)) do
           chars[#chars + 1] = advance(state)
       end

       add_token(state, TOKEN.REAL, table.concat(chars), start_line, start_col)
       return true
   end
   -- }}}
   ```

4. **Implement string scanner**
   ```lua
   -- {{{ scan_string
   local function scan_string(state, start_line, start_col)
       -- Called when we see opening '"'
       advance(state)  -- consume opening quote
       local chars = {}

       while not is_at_end(state) do
           local char = peek(state)

           if char == '"' then
               advance(state)  -- consume closing quote
               add_token(state, TOKEN.STRING, table.concat(chars), start_line, start_col)
               return true
           end

           if char == "\n" then
               error(string.format(
                   "Unterminated string at line %d, column %d",
                   start_line, start_col
               ))
           end

           if char == "\\" then
               advance(state)  -- consume backslash
               local escape_char = advance(state)
               if not escape_char then
                   error(string.format(
                       "Unterminated escape sequence at line %d",
                       state.line
                   ))
               end
               -- Handle escape sequences
               local ESCAPES = {
                   ["n"] = "\n",
                   ["r"] = "\r",
                   ["t"] = "\t",
                   ["\\"] = "\\",
                   ['"'] = '"',
               }
               local escaped = ESCAPES[escape_char]
               if escaped then
                   chars[#chars + 1] = escaped
               else
                   -- Unknown escape - preserve literally? Or error?
                   -- JASS behavior: preserve literally
                   chars[#chars + 1] = "\\"
                   chars[#chars + 1] = escape_char
               end
           else
               chars[#chars + 1] = advance(state)
           end
       end

       error(string.format(
           "Unterminated string at line %d, column %d",
           start_line, start_col
       ))
   end
   -- }}}
   ```

5. **Implement rawcode scanner**
   ```lua
   -- {{{ scan_rawcode
   local function scan_rawcode(state, start_line, start_col)
       -- Called when we see opening single quote
       -- Rawcodes are exactly 4 characters: 'hfoo', 'AHbz'
       advance(state)  -- consume opening quote
       local chars = {}

       for i = 1, 4 do
           if is_at_end(state) then
               error(string.format(
                   "Unterminated rawcode at line %d, column %d: expected 4 characters",
                   start_line, start_col
               ))
           end
           local char = peek(state)
           if char == "'" then
               error(string.format(
                   "Invalid rawcode at line %d, column %d: expected 4 characters, got %d",
                   start_line, start_col, i - 1
               ))
           end
           if char == "\n" then
               error(string.format(
                   "Unterminated rawcode at line %d, column %d",
                   start_line, start_col
               ))
           end
           chars[#chars + 1] = advance(state)
       end

       -- Expect closing quote
       if is_at_end(state) or peek(state) ~= "'" then
           error(string.format(
               "Unterminated rawcode at line %d, column %d: expected closing quote",
               start_line, start_col
           ))
       end
       advance(state)  -- consume closing quote

       add_token(state, TOKEN.RAWCODE, table.concat(chars), start_line, start_col)
       return true
   end
   -- }}}
   ```

6. **Implement unified number scanner entry point**
   ```lua
   -- {{{ scan_number
   local function scan_number(state, start_line, start_col)
       local char = peek(state)

       -- Leading dot: .5
       if char == "." then
           return scan_real_from_dot(state, start_line, start_col)
       end

       -- $ hex prefix
       if char == "$" then
           return scan_integer(state, start_line, start_col)
       end

       -- Digit: could be integer, hex, octal, or real
       if is_digit(char) then
           return scan_integer(state, start_line, start_col)
       end

       return false
   end
   -- }}}
   ```

7. **Update scan_token dispatcher in lexer.lua**
   ```lua
   -- In scan_token, add these checks:

   -- String literal
   if char == '"' then
       return scan_string(state, start_line, start_col)
   end

   -- Rawcode literal
   if char == "'" then
       return scan_rawcode(state, start_line, start_col)
   end

   -- Number (integer, hex, or real)
   if is_digit(char) or char == "." or char == "$" then
       return scan_number(state, start_line, start_col)
   end
   ```

---

## Technical Notes

### Rawcode to integer conversion

Rawcodes like `'hfoo'` are actually 4-byte integers:
```
'h' = 0x68, 'f' = 0x66, 'o' = 0x6F, 'o' = 0x6F
'hfoo' = 0x68666F6F = 1751937903
```

The lexer just stores the 4 characters as the token value. Conversion to
integer happens in the parser or evaluator.

### Octal numbers

JASS supports octal with leading zero: `017` = 15 decimal.

The lexer doesn't distinguish - it just captures the digits. The evaluator
must check for leading zero and interpret appropriately.

### String escapes

Standard escapes supported:
- `\n` - newline
- `\r` - carriage return
- `\t` - tab
- `\\` - backslash
- `\"` - double quote

Unknown escapes are preserved literally (JASS behavior).

### Real number edge cases

All these are valid:
- `1.5` - standard
- `.5` - no leading digit
- `1.` - no trailing digit
- `0.0` - zeros

The lexer handles all cases.

---

## Related Documents

- issues/304-build-jass-lexer.md (parent issue)
- issues/304a-lexer-core-infrastructure.md (dependency - provides framework)
- issues/304b-lexer-keywords-identifiers-operators.md (sibling - handles non-literals)
- issues/304d-lexer-tests-validation.md (sibling - tests this code)
- issues/305-build-jass-parser.md (consumer - will parse token stream)

---

## Acceptance Criteria

- [x] Decimal integers tokenized correctly (0, 123, 999999)
- [x] Hexadecimal integers with 0x prefix work (0x1F, 0XFF, 0x0)
- [x] Hexadecimal integers with $ prefix work ($1F, $FF)
- [x] Octal integers captured (017, 0777) - interpretation deferred to evaluator
- [x] Real numbers with both parts work (1.5, 123.456)
- [x] Real numbers with leading dot work (.5, .123)
- [x] Real numbers with trailing dot work (1., 123.)
- [x] String literals with content work ("hello", "")
- [x] String escape sequences processed (\n, \r, \t, \\, \")
- [x] Unknown escapes preserved literally
- [x] Unterminated strings produce clear error with location
- [x] Rawcode literals work ('hfoo', 'AHbz', 'A000')
- [x] Rawcodes must be exactly 4 characters
- [x] Unterminated rawcodes produce clear error
- [x] is_hex_digit helper exported for potential reuse

---

## Notes

This issue handles the most complex tokenization logic. Number formats have
multiple variations, and strings require careful escape handling.

Key insight: The lexer captures literal *text*, not values. Conversion to
actual numbers/integers happens later in the parser or evaluator. This keeps
the lexer simple and allows round-trip source preservation.

Edge case to watch: A lone `.` is not a valid token in JASS (no member access).
If we see `.` not followed by a digit, it's an error.

---

## Implementation Notes

*Completed by Claude Code on 2025-12-27*

### Files Modified

| File | Description |
|------|-------------|
| `src/jass/lexer.lua` | Added literal scanning functions (~210 lines) |
| `src/tests/test_lexer_literals.lua` | New test file (53 tests) |

### Implementation Details

1. **Helper Functions Added**
   - `is_hex_digit(char)` - Checks for 0-9, A-F, a-f
   - `scan_integer(state, start_line, start_col)` - Handles decimal, 0x hex, $ hex, and octal
   - `scan_real_from_dot(state, start_line, start_col)` - Handles .5 style reals
   - `scan_string(state, start_line, start_col)` - Handles "..." with escapes
   - `scan_rawcode(state, start_line, start_col)` - Handles 'hfoo' 4-char codes

2. **scan_token Updated**
   - String literal check (double quote)
   - Rawcode literal check (single quote)
   - Number literal checks (digit, $, or dot followed by digit)
   - Falls through to identifier/operator/punctuation handlers

3. **Error Handling**
   - Unterminated strings: "Unterminated string at line X, column Y"
   - Invalid hex: "expected digits after '0x'" or "'$'"
   - Invalid rawcode: "expected 4 characters" or "expected closing quote"
   - Lone dot: Falls through to "Unexpected character '.'" in main loop

4. **Test Coverage (53 tests)**
   - 4 decimal integer tests
   - 7 hex 0x tests (including error cases)
   - 4 hex $ tests
   - 2 octal tests
   - 4 standard real tests
   - 5 leading-dot real tests
   - 3 trailing-dot real tests
   - 12 string literal tests (including escapes)
   - 8 rawcode tests
   - 1 is_hex_digit export test
   - 3 mixed literal expression tests

### Observations

- The lexer captures literal *text*, not values. Conversion happens later.
- JASS octal (leading zero) is captured as INTEGER; evaluator interprets.
- Unknown escape sequences are preserved literally (JASS behavior).
- Rawcodes must be exactly 4 characters (unit/ability IDs).

### Related Test Runs

All 137 lexer tests pass:
- test_lexer_core.lua: 28 tests
- test_lexer_keywords.lua: 56 tests
- test_lexer_literals.lua: 53 tests
