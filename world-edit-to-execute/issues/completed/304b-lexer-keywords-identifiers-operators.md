# Issue 304b: Lexer Keywords, Identifiers, and Operators

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 304-build-jass-lexer
**Dependencies:** 304a-lexer-core-infrastructure

---

## Current Behavior

The lexer core infrastructure (304a) provides the scanning framework, token types,
and position tracking. However, it cannot yet tokenize keywords, identifiers, or
operators - the `scan_token` function returns nil for all input.

---

## Intended Behavior

Extend the lexer to recognize and tokenize:

1. **Keywords** - All 30 JASS reserved words (function, if, then, etc.)
2. **Identifiers** - User-defined names (variables, functions, types)
3. **Operators** - Arithmetic, comparison, and logical operators
4. **Punctuation** - Parentheses, brackets, commas

After this issue, the lexer can tokenize the "shape" of JASS code - everything
except literal values (numbers, strings, rawcodes), which are handled by 304c.

---

## Suggested Implementation Steps

1. **Create the keyword lookup table**
   ```lua
   -- {{{ KEYWORDS
   -- Maps lowercase keyword strings to their token types
   local KEYWORDS = {
       ["function"] = TOKEN.FUNCTION,
       ["endfunction"] = TOKEN.ENDFUNCTION,
       ["takes"] = TOKEN.TAKES,
       ["returns"] = TOKEN.RETURNS,
       ["nothing"] = TOKEN.NOTHING,
       ["globals"] = TOKEN.GLOBALS,
       ["endglobals"] = TOKEN.ENDGLOBALS,
       ["local"] = TOKEN.LOCAL,
       ["set"] = TOKEN.SET,
       ["call"] = TOKEN.CALL,
       ["if"] = TOKEN.IF,
       ["then"] = TOKEN.THEN,
       ["else"] = TOKEN.ELSE,
       ["elseif"] = TOKEN.ELSEIF,
       ["endif"] = TOKEN.ENDIF,
       ["loop"] = TOKEN.LOOP,
       ["endloop"] = TOKEN.ENDLOOP,
       ["exitwhen"] = TOKEN.EXITWHEN,
       ["return"] = TOKEN.RETURN,
       ["constant"] = TOKEN.CONSTANT,
       ["native"] = TOKEN.NATIVE,
       ["type"] = TOKEN.TYPE,
       ["extends"] = TOKEN.EXTENDS,
       ["array"] = TOKEN.ARRAY,
       ["and"] = TOKEN.AND,
       ["or"] = TOKEN.OR,
       ["not"] = TOKEN.NOT,
       ["true"] = TOKEN.TRUE,
       ["false"] = TOKEN.FALSE,
       ["null"] = TOKEN.NULL,
   }
   -- }}}
   ```

2. **Implement character classification helpers**
   ```lua
   -- {{{ is_alpha
   local function is_alpha(char)
       if not char then return false end
       local b = string.byte(char)
       return (b >= 65 and b <= 90)   -- A-Z
           or (b >= 97 and b <= 122)  -- a-z
           or char == "_"
   end
   -- }}}

   -- {{{ is_digit
   local function is_digit(char)
       if not char then return false end
       local b = string.byte(char)
       return b >= 48 and b <= 57  -- 0-9
   end
   -- }}}

   -- {{{ is_alnum
   local function is_alnum(char)
       return is_alpha(char) or is_digit(char)
   end
   -- }}}
   ```

3. **Implement identifier/keyword scanner**
   ```lua
   -- {{{ scan_identifier_or_keyword
   local function scan_identifier_or_keyword(state, start_line, start_col)
       -- Called when first char is alpha or underscore
       -- Collect all alphanumeric chars
       local chars = {}

       while not is_at_end(state) and is_alnum(peek(state)) do
           chars[#chars + 1] = advance(state)
       end

       local value = table.concat(chars)

       -- Check if it's a keyword (case-sensitive in JASS)
       local keyword_type = KEYWORDS[value]
       if keyword_type then
           add_token(state, keyword_type, value, start_line, start_col)
       else
           add_token(state, TOKEN.IDENTIFIER, value, start_line, start_col)
       end

       return true  -- Indicate we handled this token
   end
   -- }}}
   ```

4. **Implement operator scanner**
   ```lua
   -- {{{ scan_operator
   local function scan_operator(state, start_line, start_col)
       local char = peek(state)

       -- Two-character operators first
       local next_char = peek(state, 1)

       if char == "=" and next_char == "=" then
           advance(state)
           advance(state)
           add_token(state, TOKEN.EQUALS, "==", start_line, start_col)
           return true
       end

       if char == "!" and next_char == "=" then
           advance(state)
           advance(state)
           add_token(state, TOKEN.NOT_EQUALS, "!=", start_line, start_col)
           return true
       end

       if char == "<" and next_char == "=" then
           advance(state)
           advance(state)
           add_token(state, TOKEN.LESS_EQUALS, "<=", start_line, start_col)
           return true
       end

       if char == ">" and next_char == "=" then
           advance(state)
           advance(state)
           add_token(state, TOKEN.GREATER_EQUALS, ">=", start_line, start_col)
           return true
       end

       -- Single-character operators
       local SINGLE_CHAR_OPS = {
           ["+"] = TOKEN.PLUS,
           ["-"] = TOKEN.MINUS,
           ["*"] = TOKEN.STAR,
           ["/"] = TOKEN.SLASH,  -- Note: // is comment, handled in core
           ["="] = TOKEN.ASSIGN,
           ["<"] = TOKEN.LESS,
           [">"] = TOKEN.GREATER,
       }

       local op_type = SINGLE_CHAR_OPS[char]
       if op_type then
           advance(state)
           add_token(state, op_type, char, start_line, start_col)
           return true
       end

       return false  -- Not an operator
   end
   -- }}}
   ```

5. **Implement punctuation scanner**
   ```lua
   -- {{{ scan_punctuation
   local function scan_punctuation(state, start_line, start_col)
       local char = peek(state)

       local PUNCTUATION = {
           ["("] = TOKEN.LPAREN,
           [")"] = TOKEN.RPAREN,
           ["["] = TOKEN.LBRACKET,
           ["]"] = TOKEN.RBRACKET,
           [","] = TOKEN.COMMA,
       }

       local punc_type = PUNCTUATION[char]
       if punc_type then
           advance(state)
           add_token(state, punc_type, char, start_line, start_col)
           return true
       end

       return false  -- Not punctuation
   end
   -- }}}
   ```

6. **Update scan_token dispatcher**
   ```lua
   -- {{{ scan_token
   local function scan_token(state, start_line, start_col)
       local char = peek(state)

       -- Identifier or keyword (starts with letter or underscore)
       if is_alpha(char) then
           return scan_identifier_or_keyword(state, start_line, start_col)
       end

       -- Operators
       if scan_operator(state, start_line, start_col) then
           return true
       end

       -- Punctuation
       if scan_punctuation(state, start_line, start_col) then
           return true
       end

       -- Numbers and strings will be handled by 304c
       -- For now, check if it looks like one and defer
       if is_digit(char) or char == "." or char == '"' or char == "'" or char == "$" then
           -- These will be handled by 304c
           -- For now, return false to trigger the "unexpected character" error
           -- Once 304c is integrated, this branch will call the literal scanners
           return false
       end

       return false  -- Unknown character
   end
   -- }}}
   ```

7. **Export character classification helpers for 304c**
   ```lua
   -- Add to lexer._internal:
   lexer._internal.is_alpha = is_alpha
   lexer._internal.is_digit = is_digit
   lexer._internal.is_alnum = is_alnum
   ```

---

## Technical Notes

### JASS is case-sensitive

Unlike some languages, JASS keywords must be lowercase:
- `function` is a keyword
- `Function` is an identifier
- `FUNCTION` is an identifier

The keyword lookup uses exact string matching.

### Operator precedence

The lexer doesn't care about precedence - that's the parser's job. The lexer
just needs to correctly distinguish:
- `==` (equality) from `=` (assignment)
- `<=` and `>=` from `<` and `>`
- `//` (comment) from `/` (division)

The two-character operators must be checked before single-character.

### No ternary or complex operators

JASS doesn't have:
- Ternary operator (`?:`)
- Compound assignment (`+=`, `-=`)
- Increment/decrement (`++`, `--`)
- Bitwise operators (`&`, `|`, `^`, `~`)

This makes the operator set relatively simple.

---

## Related Documents

- issues/304-build-jass-lexer.md (parent issue)
- issues/304a-lexer-core-infrastructure.md (dependency - provides framework)
- issues/304c-lexer-literals.md (sibling - handles numbers, strings, rawcodes)
- issues/304d-lexer-tests-validation.md (sibling - tests this code)
- issues/305-build-jass-parser.md (consumer - will parse token stream)

---

## Acceptance Criteria

- [x] All 30 JASS keywords are recognized and tokenized correctly
- [x] Identifiers starting with letter or underscore are tokenized
- [x] Identifiers can contain letters, digits, and underscores
- [x] Case sensitivity is preserved (function vs Function)
- [x] Two-character operators (==, !=, <=, >=) work correctly
- [x] Single-character operators (+, -, *, /, =, <, >) work correctly
- [x] All punctuation ((, ), [, ], ,) is tokenized
- [x] KEYWORDS lookup table is complete and correct
- [x] Character classification helpers are exported for 304c use
- [x] Slash followed by non-slash is SLASH token (not comment)

---

## Notes

This issue and 304c can be developed in parallel after 304a is complete. The
dispatcher in `scan_token` will need to be updated to call both sets of scanners.

The order of checks matters:
1. Comments (`//`) - handled in core, before scan_token is called
2. Identifiers/keywords - check first character
3. Operators - check for two-char before single-char
4. Punctuation - simple single-char lookup
5. Literals (304c) - numbers, strings, rawcodes

When 304c is complete, its scanners will be integrated into scan_token.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

- `src/jass/lexer.lua` - Extended with keywords, identifiers, operators, punctuation
- `src/tests/test_lexer_keywords.lua` - New test suite (56 tests)

### Implementation Details

1. **KEYWORDS table** - Maps all 30 lowercase JASS keywords to their token types.
   JASS is case-sensitive: "function" is a keyword, "Function" is an identifier.

2. **Character classification helpers**
   - `is_alpha(char)` - Returns true for A-Z, a-z, and underscore
   - `is_digit(char)` - Returns true for 0-9
   - `is_alnum(char)` - Combines alpha and digit checks
   - All handle nil input gracefully (return false)

3. **scan_identifier_or_keyword()** - Collects alphanumeric characters, then checks
   KEYWORDS table. If found, emits keyword token; otherwise emits IDENTIFIER.

4. **scan_operator()** - Checks two-character operators first (==, !=, <=, >=),
   then single-character (+, -, *, /, =, <, >). Returns false if not an operator.

5. **scan_punctuation()** - Simple lookup table for (, ), [, ], and comma.

6. **scan_token() dispatcher** - Delegates to appropriate scanner based on first
   character. Currently returns false for digits, quotes, and $ (literal prefixes)
   which will be handled by 304c.

### Test Coverage (56 tests)

- All 30 keywords recognized
- Case sensitivity verified (Function vs function)
- Keyword prefixes as identifiers (functions, ifs, returns2)
- Identifiers with underscores and digits
- All two-character operators
- All single-character operators
- All punctuation
- Combined realistic JASS patterns (function declarations, calls, expressions)
- Edge cases (no whitespace between tokens, nested parens, comments after code)
- Character classification helper functions
