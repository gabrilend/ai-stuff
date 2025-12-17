# Issue 304: Build JASS Lexer

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 303-parse-war3map-j

---

## Current Behavior

No tokenization for JASS scripts. Cannot process JASS code into a format
suitable for parsing and analysis.

---

## Intended Behavior

A lexer that tokenizes JASS source code into a stream of tokens:
- Keywords (function, returns, if, then, etc.)
- Identifiers (variable/function names)
- Literals (integers, reals, strings, booleans)
- Operators (+, -, *, /, ==, !=, etc.)
- Punctuation (parentheses, brackets, commas)
- Comments (// single-line)

---

## Suggested Implementation Steps

1. **Create lexer module**
   ```
   src/jass/
   └── lexer.lua        (this issue)
   ```

2. **Define token types**
   ```lua
   local TOKEN = {
       -- Keywords
       FUNCTION = "FUNCTION",
       ENDFUNCTION = "ENDFUNCTION",
       TAKES = "TAKES",
       RETURNS = "RETURNS",
       NOTHING = "NOTHING",
       GLOBALS = "GLOBALS",
       ENDGLOBALS = "ENDGLOBALS",
       LOCAL = "LOCAL",
       SET = "SET",
       CALL = "CALL",
       IF = "IF",
       THEN = "THEN",
       ELSE = "ELSE",
       ELSEIF = "ELSEIF",
       ENDIF = "ENDIF",
       LOOP = "LOOP",
       ENDLOOP = "ENDLOOP",
       EXITWHEN = "EXITWHEN",
       RETURN = "RETURN",
       CONSTANT = "CONSTANT",
       NATIVE = "NATIVE",
       TYPE = "TYPE",
       EXTENDS = "EXTENDS",
       ARRAY = "ARRAY",
       AND = "AND",
       OR = "OR",
       NOT = "NOT",
       TRUE = "TRUE",
       FALSE = "FALSE",
       NULL = "NULL",

       -- Literals
       INTEGER = "INTEGER",
       REAL = "REAL",
       STRING = "STRING",
       RAWCODE = "RAWCODE",  -- 'hfoo' style

       -- Identifiers
       IDENTIFIER = "IDENTIFIER",

       -- Operators
       PLUS = "PLUS",
       MINUS = "MINUS",
       STAR = "STAR",
       SLASH = "SLASH",
       EQUALS = "EQUALS",
       NOT_EQUALS = "NOT_EQUALS",
       LESS = "LESS",
       LESS_EQUALS = "LESS_EQUALS",
       GREATER = "GREATER",
       GREATER_EQUALS = "GREATER_EQUALS",
       ASSIGN = "ASSIGN",

       -- Punctuation
       LPAREN = "LPAREN",
       RPAREN = "RPAREN",
       LBRACKET = "LBRACKET",
       RBRACKET = "RBRACKET",
       COMMA = "COMMA",

       -- Special
       NEWLINE = "NEWLINE",
       EOF = "EOF",
   }
   ```

3. **Implement tokenizer**
   ```lua
   function lexer.tokenize(source)
       local tokens = {}
       local pos = 1
       local line = 1
       local col = 1

       while pos <= #source do
           local token = next_token(source, pos, line, col)
           if token then
               tokens[#tokens + 1] = token
               pos = token.end_pos
               line = token.end_line
               col = token.end_col
           end
       end

       tokens[#tokens + 1] = { type = TOKEN.EOF, line = line, col = col }
       return tokens
   end
   ```

4. **Handle JASS-specific syntax**
   ```lua
   -- String literals with escape sequences
   -- "Hello\nWorld"

   -- Rawcode literals (4-char IDs)
   -- 'hfoo', 'AHbz'

   -- Hex integers
   -- 0x1F, $1F

   -- Real numbers
   -- 1.5, .5, 1.

   -- Line continuation (not standard, but some maps use it)
   ```

5. **Return token stream**
   ```lua
   -- Each token:
   {
       type = TOKEN.FUNCTION,
       value = "function",
       line = 10,
       col = 1,
       end_pos = 18,
   }
   ```

---

## Technical Notes

### JASS Lexical Rules

**Identifiers:**
- Start with letter or underscore
- Contain letters, digits, underscores
- Case-sensitive

**Integers:**
- Decimal: `123`
- Hex: `0x1F` or `$1F`
- Octal: `017` (leading zero)

**Reals:**
- Standard: `1.5`
- No leading digit: `.5`
- No trailing digit: `1.`

**Strings:**
- Double-quoted: `"hello"`
- Escape sequences: `\n`, `\r`, `\t`, `\\`, `\"`

**Rawcodes:**
- Single-quoted 4 characters: `'hfoo'`
- Converted to integer internally

**Comments:**
- Single-line only: `// comment`
- Extend to end of line

### Whitespace Handling

JASS is newline-sensitive for statements:
- Statements end at newline (no semicolons)
- Newlines significant in control flow
- Options: emit NEWLINE tokens or track implicitly

### Keywords vs Identifiers

All keywords must be checked before treating as identifier:
```lua
local KEYWORDS = {
    ["function"] = TOKEN.FUNCTION,
    ["endfunction"] = TOKEN.ENDFUNCTION,
    -- ...
}
```

---

## Related Documents

- docs/jass/lexer.md (to be created)
- issues/303-parse-war3map-j.md (input source)
- issues/305-build-jass-parser.md (consumes tokens)

---

## Acceptance Criteria

- [ ] Tokenizes all JASS keywords
- [ ] Tokenizes identifiers correctly
- [ ] Tokenizes integer literals (decimal, hex, octal)
- [ ] Tokenizes real literals
- [ ] Tokenizes string literals with escapes
- [ ] Tokenizes rawcode literals
- [ ] Tokenizes all operators
- [ ] Handles comments (strips or preserves)
- [ ] Tracks line/column for error reporting
- [ ] Handles edge cases (empty input, unterminated strings)
- [ ] Unit tests with comprehensive coverage

---

## Notes

The lexer is the foundation for JASS processing. It must be:

1. **Complete** - Handle all valid JASS syntax
2. **Robust** - Graceful error handling for malformed input
3. **Informative** - Track source locations for error messages
4. **Efficient** - Process large scripts (some maps have 50k+ lines)

The lexer does NOT need to understand JASS semantics. It just breaks
the source into tokens for the parser to consume.

Reference: [JASS Language Specification](http://jass.sourceforge.net/doc/)
Reference: [Crafting Interpreters - Scanning](https://craftinginterpreters.com/scanning.html)
