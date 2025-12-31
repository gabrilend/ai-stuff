# Issue 306d: Transpile Expressions

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 306a-transpiler-infrastructure
**Parent Issue:** 306-create-jass-lua-transpiler

---

## Current Behavior

The transpiler infrastructure (306a) has a stub for `transpile_expr()`
that returns `"nil --[[expr]]"`. All statement and declaration transpilation
depends on this function for values, conditions, and initializers.

---

## Intended Behavior

Transpile all JASS expression types into equivalent Lua expressions:

**Literals:**
```jass
42              → 42
3.14            → 3.14
true            → true
"hello"         → "hello"
null            → nil
'hfoo'          → 1751543663  (FourCC to integer)
```

**Identifiers:**
```jass
myVar           → myVar
```

**Binary Expressions:**
```jass
a + b           → (a + b)
a != b          → (a ~= b)
x and y         → (x and y)
```

**Unary Expressions:**
```jass
-x              → (-x)
not flag        → (not flag)
```

**Function Calls:**
```jass
GetRandomInt(1, 10)     → runtime.GetRandomInt(1, 10)
MyFunc(a, b)            → MyFunc(a, b)
```

**Array Access:**
```jass
arr[i]          → arr[i]
```

**Function References:**
```jass
function MyCallback     → MyCallback
```

---

## Suggested Implementation Steps

1. **Define operator mapping table**
   ```lua
   -- {{{ operator_map
   local operator_map = {
       -- Comparison operators
       ["=="] = "==",
       ["!="] = "~=",   -- JASS != becomes Lua ~=
       ["<"]  = "<",
       ["<="] = "<=",
       [">"]  = ">",
       [">="] = ">=",

       -- Arithmetic operators
       ["+"]  = "+",
       ["-"]  = "-",
       ["*"]  = "*",
       ["/"]  = "/",

       -- Logical operators
       ["and"] = "and",
       ["or"]  = "or",
       ["not"] = "not",
   }
   -- }}}
   ```

2. **Implement main expression dispatcher**
   ```lua
   -- {{{ transpile_expr
   local function transpile_expr(ctx, node)
       if not node then
           add_error(ctx, "Nil expression node")
           return "nil"
       end

       if node.type == "LITERAL" then
           return transpile_literal(ctx, node)

       elseif node.type == "IDENTIFIER" then
           return node.name

       elseif node.type == "BINARY_EXPR" then
           return transpile_binary(ctx, node)

       elseif node.type == "UNARY_EXPR" then
           return transpile_unary(ctx, node)

       elseif node.type == "CALL_EXPR" then
           return transpile_call_expr(ctx, node)

       elseif node.type == "ARRAY_ACCESS" then
           return transpile_array_access(ctx, node)

       elseif node.type == "FUNCTION_REF" then
           return node.name  -- First-class function reference

       else
           add_error(ctx, "Unknown expression type: " .. tostring(node.type), node)
           return "nil"
       end
   end
   -- }}}
   ```

3. **Implement literal transpilation**
   ```lua
   -- {{{ transpile_literal
   local function transpile_literal(ctx, node)
       local lit_type = node.literal_type or "unknown"
       local value = node.value

       if lit_type == "integer" then
           return tostring(value)

       elseif lit_type == "real" then
           -- Ensure real numbers have decimal point
           local str = tostring(value)
           if not str:find("%.") and not str:find("e") then
               str = str .. ".0"
           end
           return str

       elseif lit_type == "boolean" then
           return value and "true" or "false"

       elseif lit_type == "string" then
           -- Escape special characters in string
           return escape_string(value)

       elseif lit_type == "null" then
           return "nil"

       elseif lit_type == "fourcc" or lit_type == "rawcode" then
           -- FourCC like 'hfoo' → integer value
           return tostring(fourcc_to_int(value))

       else
           add_error(ctx, "Unknown literal type: " .. lit_type, node)
           return "nil"
       end
   end
   -- }}}
   ```

4. **Implement string escaping**
   ```lua
   -- {{{ escape_string
   local function escape_string(str)
       -- Escape special characters for Lua string literal
       local escaped = str:gsub("\\", "\\\\")  -- Backslash first
                          :gsub("\n", "\\n")
                          :gsub("\r", "\\r")
                          :gsub("\t", "\\t")
                          :gsub("\"", "\\\"")

       return '"' .. escaped .. '"'
   end
   -- }}}
   ```

5. **Implement FourCC conversion**
   ```lua
   -- {{{ fourcc_to_int
   local function fourcc_to_int(str)
       -- Convert 4-character code to integer
       -- 'hfoo' → (h << 24) | (f << 16) | (o << 8) | o
       -- This matches WC3's rawcode handling

       if #str ~= 4 then
           return 0
       end

       local b1 = str:byte(1)
       local b2 = str:byte(2)
       local b3 = str:byte(3)
       local b4 = str:byte(4)

       -- Use bit operations (LuaJIT compatible)
       local bit = require("bit") or bit32
       return bit.bor(
           bit.lshift(b1, 24),
           bit.lshift(b2, 16),
           bit.lshift(b3, 8),
           b4
       )
   end
   -- }}}
   ```

6. **Implement binary expression transpilation**
   ```lua
   -- {{{ transpile_binary
   local function transpile_binary(ctx, node)
       local left = transpile_expr(ctx, node.left)
       local right = transpile_expr(ctx, node.right)
       local op = node.operator

       -- Map operator
       local lua_op = operator_map[op]
       if not lua_op then
           add_error(ctx, "Unknown operator: " .. tostring(op), node)
           lua_op = op  -- Use as-is and hope for the best
       end

       -- Handle string concatenation special case
       if op == "+" and is_string_context(ctx, node) then
           lua_op = ".."
       end

       -- Handle integer division (optional strictness)
       -- JASS: integer / integer truncates
       -- Lua: number / number returns float
       -- We can optionally wrap: math.floor(left / right)

       return string.format("(%s %s %s)", left, lua_op, right)
   end
   -- }}}
   ```

7. **Implement unary expression transpilation**
   ```lua
   -- {{{ transpile_unary
   local function transpile_unary(ctx, node)
       local operand = transpile_expr(ctx, node.operand)
       local op = node.operator

       if op == "-" then
           return string.format("(-%s)", operand)
       elseif op == "not" then
           return string.format("(not %s)", operand)
       else
           add_error(ctx, "Unknown unary operator: " .. tostring(op), node)
           return operand
       end
   end
   -- }}}
   ```

8. **Implement function call expression transpilation**
   ```lua
   -- {{{ transpile_call_expr
   local function transpile_call_expr(ctx, node)
       local func_name = node.function_name
       local args = {}

       -- Transpile each argument
       for _, arg in ipairs(node.arguments or {}) do
           args[#args + 1] = transpile_expr(ctx, arg)
       end

       local args_str = table.concat(args, ", ")

       -- Check if native function
       if is_native(ctx, func_name) then
           return string.format("runtime.%s(%s)", func_name, args_str)
       else
           return string.format("%s(%s)", func_name, args_str)
       end
   end
   -- }}}
   ```

9. **Implement array access transpilation**
   ```lua
   -- {{{ transpile_array_access
   local function transpile_array_access(ctx, node)
       local array = node.array  -- Variable name
       local index = transpile_expr(ctx, node.index)

       return string.format("%s[%s]", array, index)
   end
   -- }}}
   ```

10. **Handle string context detection (optional)**
    ```lua
    -- {{{ is_string_context
    local function is_string_context(ctx, node)
        -- Determine if a binary + should be string concatenation
        -- This requires type information which we may not have

        -- Heuristic: if either operand is a string literal, use ..
        if node.left.type == "LITERAL" and node.left.literal_type == "string" then
            return true
        end
        if node.right.type == "LITERAL" and node.right.literal_type == "string" then
            return true
        end

        -- Without full type inference, we can't know for sure
        -- Default to arithmetic + and let runtime handle it
        -- OR: Always use .. for safety (strings + numbers both work in Lua)

        return false
    end
    -- }}}
    ```

11. **Handle parenthesized expressions**
    ```lua
    -- Parenthesized expressions in JASS are already handled by the parser
    -- The parser produces the correct AST structure based on operator precedence
    -- Our transpilation adds parentheses around all binary/unary expressions
    -- This ensures correct precedence in Lua output

    -- Example: JASS "a + b * c" parses to AST with * under +
    -- We output: (a + (b * c))
    -- Extra parens don't hurt and ensure correctness
    ```

12. **Update module exports**
    ```lua
    -- Add to transpiler module exports
    transpiler._transpile_expr = transpile_expr
    transpiler._transpile_literal = transpile_literal
    transpiler._transpile_binary = transpile_binary
    transpiler._transpile_unary = transpile_unary
    transpiler._transpile_call_expr = transpile_call_expr
    transpiler._transpile_array_access = transpile_array_access
    transpiler._operator_map = operator_map
    transpiler._fourcc_to_int = fourcc_to_int
    transpiler._escape_string = escape_string
    ```

---

## Technical Notes

### Operator Differences

| JASS | Lua | Notes |
|------|-----|-------|
| `!=` | `~=` | Not-equal syntax differs |
| `+` (strings) | `..` | String concatenation |
| `/` (integers) | `/` | Lua returns float, may need floor() |
| `and`, `or`, `not` | Same | Direct mapping |

### Type Coercion

JASS has stricter typing than Lua. The transpiler doesn't enforce types
but the runtime may need to handle coercion for:
- Integer to real conversion
- String concatenation with numbers
- Boolean contexts

### FourCC Rawcodes

WC3 uses 4-character codes like `'hfoo'` (Human Footman) as integer IDs.
These are converted to their numeric equivalent using big-endian byte order.

Example: `'hfoo'` = `0x68666F6F` = `1751543663`

### Parenthesization Strategy

We wrap all binary and unary expressions in parentheses. This is
conservative but guarantees correct precedence in the output.

Alternative: Track precedence and only add parens when needed.
This produces cleaner output but is more complex.

### String Context Detection

Detecting when `+` should become `..` is tricky without type information.
Options:
1. Use heuristics (string literal present)
2. Always use `..` (works for strings and numbers in Lua)
3. Leave as `+` and let runtime fail on string+string

We use option 1 (heuristics) with fallback to `+`.

---

## Related Documents

- issues/306-create-jass-lua-transpiler.md (parent issue)
- issues/306a-transpiler-infrastructure.md (provides context, is_native)
- issues/306b-transpile-declarations.md (uses transpile_expr for initializers)
- issues/306c-transpile-statements.md (uses transpile_expr for values/conditions)
- issues/306e-native-function-handling.md (call expression native detection)
- src/jass/parser.lua (expression node structures)
- src/compat.lua (bitwise operations for FourCC)

---

## Acceptance Criteria

- [x] Integer literals transpile correctly
- [x] Real literals transpile with decimal point
- [x] Boolean literals transpile to `true`/`false`
- [x] String literals are properly escaped
- [x] Null literal transpiles to `nil`
- [x] FourCC codes convert to correct integer values
- [x] Identifiers pass through unchanged
- [x] Binary expressions wrap operands correctly
- [x] Operator `!=` becomes `~=`
- [x] String concatenation uses `..` when detected
- [x] Unary minus transpiles correctly
- [x] Unary `not` transpiles correctly
- [x] Function call expressions work for user functions
- [x] Function call expressions prefix natives with `runtime.`
- [x] Array access expressions transpile correctly
- [x] Function references pass through as identifiers
- [x] Nested expressions maintain correct precedence
- [x] Unknown expression types generate error (not crash)

---

## Notes

This sub-issue is foundational for the transpiler - expressions appear in:
- Variable initializers (globals and locals)
- Assignment values (SET statements)
- Condition expressions (IF, ELSEIF, EXITWHEN)
- Function arguments (CALL statements and expressions)
- Return values (RETURN statements)
- Array indices (access and assignment)

The expression transpilation must be complete before 306b and 306c can
produce fully functional output.

String concatenation detection is intentionally simple. A more robust
solution would require tracking variable types through the transpilation
context, which adds significant complexity for marginal benefit.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

- `src/jass/transpiler.lua` - Added expression transpilation functions
- `src/tests/test_transpiler_expr.lua` - New test suite (69 tests)

### Implementation Details

1. **operator_map** - Maps JASS operators to Lua operators:
   - Most operators are identical (`+`, `-`, `*`, `/`, `<`, `>`, `<=`, `>=`, `==`)
   - `!=` maps to `~=` (Lua not-equal syntax)
   - `and`, `or`, `not` map directly

2. **escape_string(str)** - Escapes special characters for Lua string literals:
   - Handles `\\`, `\n`, `\r`, `\t`, `\"`
   - Wraps result in double quotes

3. **fourcc_to_int(str)** - Converts 4-character rawcodes to integers:
   - Uses big-endian byte order (matches WC3)
   - `'hfoo'` → `1751543663`
   - Uses multiplication for LuaJIT compatibility (avoids bit library dependency)

4. **is_string_context(ctx, node)** - Heuristic for string concatenation:
   - Returns true if left or right operand is a string literal
   - Causes `+` to become `..` in transpiled output

5. **transpile_literal(ctx, node)** - Handles all literal types:
   - integer → `tostring(value)`
   - real → ensures decimal point present
   - boolean → `"true"` or `"false"`
   - string → escaped and quoted
   - null → `"nil"`
   - fourcc/rawcode → integer conversion

6. **transpile_binary(ctx, node)** - Binary expression transpilation:
   - Wraps in parentheses for precedence safety: `(left op right)`
   - Handles string concatenation via `is_string_context()`
   - Logs error for unknown operators

7. **transpile_unary(ctx, node)** - Unary expression transpilation:
   - `-x` → `(-x)`
   - `not x` → `(not x)`

8. **transpile_call_expr(ctx, node)** - Function call transpilation:
   - User functions: `FuncName(args)`
   - Native functions: `runtime.FuncName(args)`

9. **transpile_array_access(ctx, node)** - Array access transpilation:
   - `arr[index]` format, index can be any expression

10. **transpile_expr(ctx, node)** - Main dispatcher:
    - Routes to appropriate handler by node type
    - IDENTIFIER → `node.name` (pass through)
    - FUNCTION_REF → `node.name` (first-class function)
    - Logs error for unknown types, returns `"nil"`

### Generated Code Format

```lua
-- Binary expressions wrapped in parens
(a + b)
(x ~= 0)  -- != becomes ~=
("hello" .. name)  -- string concatenation

-- Function calls
MyUserFunc(arg1, arg2)
runtime.GetRandomInt(1, 10)  -- natives prefixed

-- Array access
arr[i]
data[(offset + 1)]

-- Nested expressions maintain structure
((a + b) * c)
(not ((x == y) and (z > 0)))
```

### Test Coverage (69 tests)

- Helper functions: escape_string, fourcc_to_int
- All literal types: integer, real, boolean, string, null, fourcc, rawcode
- Binary operators: arithmetic, comparison, logical
- String concatenation detection
- Unary operators: minus, not
- Function calls: user functions, native functions, nested calls
- Array access: literal index, variable index, expression index
- Main dispatcher: identifiers, function refs, nil/unknown handling
- Integration: full source transpilation with expressions
- Nested expressions: complex expression trees

