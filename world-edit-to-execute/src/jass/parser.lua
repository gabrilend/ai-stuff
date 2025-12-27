--[[
JASS Parser - Core Infrastructure

Provides the foundational infrastructure for parsing JASS token streams:
- Parser state management
- Token consumption and lookahead helpers
- Error reporting with source location
- Error recovery/synchronization
- AST node type constants and creation helpers

This module is used by the parsing sub-modules (declarations, statements,
expressions) to build the complete AST.
]]

local lexer = require("jass.lexer")
local TOKEN = lexer.TOKEN

local parser = {}

-- {{{ AST
-- AST node type constants for the entire parser.
-- All node types are defined here for consistency across sub-modules.
local AST = {
    -- Top-level constructs
    PROGRAM = "PROGRAM",           -- Root node containing all declarations
    TYPE_DEF = "TYPE_DEF",         -- type foo extends bar
    GLOBAL_BLOCK = "GLOBAL_BLOCK", -- globals ... endglobals
    VAR_DECL = "VAR_DECL",         -- Variable declaration (in globals or local)
    NATIVE_DECL = "NATIVE_DECL",   -- native foo takes ... returns ...
    FUNCTION_DEF = "FUNCTION_DEF", -- function foo takes ... returns ... endfunction

    -- Statements
    SET_STMT = "SET_STMT",         -- set x = expr / set arr[i] = expr
    CALL_STMT = "CALL_STMT",       -- call foo(args)
    IF_STMT = "IF_STMT",           -- if ... then ... elseif ... else ... endif
    LOOP_STMT = "LOOP_STMT",       -- loop ... endloop
    EXITWHEN_STMT = "EXITWHEN_STMT", -- exitwhen condition
    RETURN_STMT = "RETURN_STMT",   -- return / return expr
    LOCAL_DECL = "LOCAL_DECL",     -- local type name = expr

    -- Expressions
    BINARY_EXPR = "BINARY_EXPR",   -- a + b, a == b, a and b, etc.
    UNARY_EXPR = "UNARY_EXPR",     -- -x, not x
    CALL_EXPR = "CALL_EXPR",       -- foo(args) as expression
    ARRAY_ACCESS = "ARRAY_ACCESS", -- arr[index]
    IDENTIFIER = "IDENTIFIER",     -- Variable reference
    LITERAL = "LITERAL",           -- Integer, real, string, rawcode, true, false, null
    FUNCTION_REF = "FUNCTION_REF", -- function foo (function reference)
}
-- }}}

parser.AST = AST

-- {{{ create_state
-- Create parser state from token array.
-- The state tracks current position and accumulated errors.
-- @param tokens Array of tokens from lexer.tokenize()
-- @return Parser state table
local function create_state(tokens)
    return {
        tokens = tokens,
        pos = 1,
        errors = {},
    }
end
-- }}}

-- {{{ at_end
-- Check if we've consumed all tokens.
-- Returns true if position is beyond token array or current token is EOF.
local function at_end(state)
    return state.pos > #state.tokens or
           state.tokens[state.pos].type == TOKEN.EOF
end
-- }}}

-- {{{ peek
-- Look at current token without consuming it.
-- @return Current token
local function peek(state)
    return state.tokens[state.pos]
end
-- }}}

-- {{{ peek_next
-- Look at next token without consuming current.
-- Useful for two-token lookahead.
-- @return Next token, or nil if at end
local function peek_next(state)
    if state.pos + 1 > #state.tokens then
        return nil
    end
    return state.tokens[state.pos + 1]
end
-- }}}

-- {{{ previous
-- Get the most recently consumed token.
-- @return Previous token
local function previous(state)
    return state.tokens[state.pos - 1]
end
-- }}}

-- {{{ check
-- Check if current token matches type without consuming.
-- @param state Parser state
-- @param token_type Expected token type
-- @return true if current token matches
local function check(state, token_type)
    if at_end(state) then return false end
    return peek(state).type == token_type
end
-- }}}

-- {{{ check_any
-- Check if current token matches any of the given types.
-- @param state Parser state
-- @param ... Token types to check
-- @return true if current token matches any type
local function check_any(state, ...)
    local types = {...}
    for _, t in ipairs(types) do
        if check(state, t) then return true end
    end
    return false
end
-- }}}

-- {{{ advance
-- Consume and return current token.
-- Increments position if not at end.
-- @return The consumed token (now previous)
local function advance(state)
    if not at_end(state) then
        state.pos = state.pos + 1
    end
    return previous(state)
end
-- }}}

-- {{{ match
-- Consume token if it matches type, return success.
-- @param state Parser state
-- @param token_type Expected token type
-- @return true if token was consumed
local function match(state, token_type)
    if check(state, token_type) then
        advance(state)
        return true
    end
    return false
end
-- }}}

-- {{{ match_any
-- Consume token if it matches any of the given types.
-- @param state Parser state
-- @param ... Token types to match
-- @return true if a token was consumed
local function match_any(state, ...)
    local types = {...}
    for _, t in ipairs(types) do
        if check(state, t) then
            advance(state)
            return true
        end
    end
    return false
end
-- }}}

-- {{{ error_at
-- Report error at specific token.
-- Errors are accumulated in state.errors for later reporting.
-- @param state Parser state
-- @param token Token where error occurred
-- @param message Error description
local function error_at(state, token, message)
    local err = {
        message = message,
        line = token.line or 0,
        col = token.col or 0,
        token_type = token.type,
        token_value = token.value,
    }
    state.errors[#state.errors + 1] = err
end
-- }}}

-- {{{ error_at_current
-- Report error at current token position.
-- @param state Parser state
-- @param message Error description
local function error_at_current(state, message)
    error_at(state, peek(state), message)
end
-- }}}

-- {{{ error_at_previous
-- Report error at previously consumed token.
-- @param state Parser state
-- @param message Error description
local function error_at_previous(state, message)
    error_at(state, previous(state), message)
end
-- }}}

-- {{{ format_error
-- Format error for human-readable display.
-- @param err Error table from state.errors
-- @return Formatted error string
local function format_error(err)
    return string.format("Line %d, Column %d: %s",
        err.line, err.col, err.message)
end
-- }}}

-- {{{ consume
-- Consume token of expected type or report error.
-- @param state Parser state
-- @param token_type Expected token type
-- @param message Error message if mismatch
-- @return The consumed token, or nil on error
local function consume(state, token_type, message)
    if check(state, token_type) then
        return advance(state)
    end
    error_at_current(state, message or ("Expected " .. token_type))
    return nil
end
-- }}}

-- {{{ synchronize
-- Skip tokens until we find a synchronization point.
-- Used to recover from parse errors and continue parsing.
-- Synchronization points are statement and declaration boundaries.
local function synchronize(state)
    advance(state)

    while not at_end(state) do
        -- Synchronize at declaration boundaries (top-level constructs)
        if check_any(state,
            TOKEN.TYPE,
            TOKEN.GLOBALS,
            TOKEN.ENDGLOBALS,
            TOKEN.NATIVE,
            TOKEN.CONSTANT,
            TOKEN.FUNCTION,
            TOKEN.ENDFUNCTION
        ) then
            return
        end

        -- Synchronize at statement boundaries
        if check_any(state,
            TOKEN.SET,
            TOKEN.CALL,
            TOKEN.IF,
            TOKEN.ENDIF,
            TOKEN.ELSEIF,
            TOKEN.ELSE,
            TOKEN.LOOP,
            TOKEN.ENDLOOP,
            TOKEN.EXITWHEN,
            TOKEN.RETURN,
            TOKEN.LOCAL
        ) then
            return
        end

        advance(state)
    end
end
-- }}}

-- {{{ skip_newlines
-- Skip any NEWLINE and COMMENT tokens.
-- JASS is newline-sensitive but for parsing we often want to skip them.
-- @param state Parser state
local function skip_newlines(state)
    while check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) do
        advance(state)
    end
end
-- }}}

-- {{{ make_node
-- Create an AST node with common fields.
-- @param node_type AST node type constant from AST table
-- @param token Source token for location info (optional)
-- @return New AST node table with type, line, col fields
local function make_node(node_type, token)
    return {
        type = node_type,
        line = token and token.line or 0,
        col = token and token.col or 0,
    }
end
-- }}}

-- {{{ has_errors
-- Check if any errors have been recorded.
-- @param state Parser state
-- @return true if state.errors is non-empty
local function has_errors(state)
    return #state.errors > 0
end
-- }}}

-- {{{ get_errors
-- Get formatted error messages.
-- @param state Parser state
-- @return Array of formatted error strings
local function get_errors(state)
    local result = {}
    for _, err in ipairs(state.errors) do
        result[#result + 1] = format_error(err)
    end
    return result
end
-- }}}

-- ============================================================================
-- DECLARATION PARSING (305b)
-- ============================================================================

-- Forward declarations for mutually recursive functions
local parse_expression
local parse_statement
local parse_var_decl
local parse_param
local parse_param_list
local parse_type
local parse_type_def
local parse_globals_block
local parse_native_decl
local parse_function_def
local parse_local_decl
local parse_program

-- {{{ parse_type
-- Parse a type reference (identifier or 'nothing').
-- @param state Parser state
-- @return Type name string
parse_type = function(state)
    if match(state, TOKEN.NOTHING) then
        return "nothing"
    end

    local token = consume(state, TOKEN.IDENTIFIER, "Expected type name")
    return token and token.value or "?"
end
-- }}}

-- {{{ parse_param
-- Parse single parameter: type name
-- @param state Parser state
-- @return Parameter table {type, name}
parse_param = function(state)
    local param_type = parse_type(state)
    local name_token = consume(state, TOKEN.IDENTIFIER, "Expected parameter name")
    return {
        type = param_type,
        name = name_token and name_token.value or "?",
    }
end
-- }}}

-- {{{ parse_param_list
-- Parse function parameter list.
-- params = "nothing" | param ("," param)*
-- @param state Parser state
-- @return Array of {type, name} tables
parse_param_list = function(state)
    local params = {}

    -- Check for "takes nothing"
    if match(state, TOKEN.NOTHING) then
        return params
    end

    -- Parse first parameter
    local param = parse_param(state)
    if param then
        params[#params + 1] = param
    end

    -- Parse remaining parameters
    while match(state, TOKEN.COMMA) do
        param = parse_param(state)
        if param then
            params[#params + 1] = param
        end
    end

    return params
end
-- }}}

-- ============================================================================
-- EXPRESSION PARSING (305c)
-- ============================================================================
-- Implements full expression parsing with correct operator precedence.
-- Precedence levels (lowest to highest):
--   1. or
--   2. and
--   3. == != < <= > >=
--   4. + -
--   5. * /
--   6. unary (- not)
--   7. postfix ([] ())
--   8. primary (literals, identifiers, parens, function refs)

-- Forward declarations for expression parsing
local parse_or_expr
local parse_and_expr
local parse_comparison
local parse_additive
local parse_multiplicative
local parse_unary
local parse_postfix
local parse_primary
local parse_arguments
local can_start_expression

-- {{{ can_start_expression
-- Check if current token can begin an expression.
-- Useful for optional expression parsing (e.g., return statements).
can_start_expression = function(state)
    return check_any(state,
        TOKEN.MINUS,
        TOKEN.NOT,
        TOKEN.INTEGER,
        TOKEN.REAL,
        TOKEN.STRING,
        TOKEN.RAWCODE,
        TOKEN.TRUE,
        TOKEN.FALSE,
        TOKEN.NULL,
        TOKEN.FUNCTION,
        TOKEN.IDENTIFIER,
        TOKEN.LPAREN
    )
end
-- }}}

-- {{{ parse_arguments
-- Parse function call arguments: (expr ("," expr)*)?
-- @param state Parser state
-- @return Array of expression nodes
parse_arguments = function(state)
    local args = {}

    -- Empty argument list
    if check(state, TOKEN.RPAREN) then
        return args
    end

    -- First argument
    args[#args + 1] = parse_expression(state)

    -- Remaining arguments
    while match(state, TOKEN.COMMA) do
        args[#args + 1] = parse_expression(state)
    end

    return args
end
-- }}}

-- {{{ parse_primary
-- Parse primary expression: literal | identifier | "(" expr ")" | "function" IDENT
parse_primary = function(state)
    -- Integer literal
    if match(state, TOKEN.INTEGER) then
        local node = make_node(AST.LITERAL, previous(state))
        node.literal_type = "integer"
        node.value = previous(state).value
        return node
    end

    -- Real literal
    if match(state, TOKEN.REAL) then
        local node = make_node(AST.LITERAL, previous(state))
        node.literal_type = "real"
        node.value = previous(state).value
        return node
    end

    -- String literal
    if match(state, TOKEN.STRING) then
        local node = make_node(AST.LITERAL, previous(state))
        node.literal_type = "string"
        node.value = previous(state).value
        return node
    end

    -- Rawcode literal (four-character code like 'hfoo')
    if match(state, TOKEN.RAWCODE) then
        local node = make_node(AST.LITERAL, previous(state))
        node.literal_type = "rawcode"
        node.value = previous(state).value
        return node
    end

    -- Boolean true
    if match(state, TOKEN.TRUE) then
        local node = make_node(AST.LITERAL, previous(state))
        node.literal_type = "boolean"
        node.value = true
        return node
    end

    -- Boolean false
    if match(state, TOKEN.FALSE) then
        local node = make_node(AST.LITERAL, previous(state))
        node.literal_type = "boolean"
        node.value = false
        return node
    end

    -- Null literal
    if match(state, TOKEN.NULL) then
        local node = make_node(AST.LITERAL, previous(state))
        node.literal_type = "null"
        node.value = nil
        return node
    end

    -- Function reference: function FunctionName
    if match(state, TOKEN.FUNCTION) then
        local node = make_node(AST.FUNCTION_REF, previous(state))
        local name_token = consume(state, TOKEN.IDENTIFIER, "Expected function name after 'function'")
        node.name = name_token and name_token.value or "?"
        return node
    end

    -- Identifier (variable reference)
    if match(state, TOKEN.IDENTIFIER) then
        local node = make_node(AST.IDENTIFIER, previous(state))
        node.name = previous(state).value
        return node
    end

    -- Parenthesized expression
    if match(state, TOKEN.LPAREN) then
        local expr = parse_expression(state)
        consume(state, TOKEN.RPAREN, "Expected ')' after expression")
        return expr
    end

    -- Error: unexpected token
    error_at_current(state, "Expected expression")
    return nil
end
-- }}}

-- {{{ parse_postfix
-- Parse postfix: primary ("[" expr "]" | "(" args ")")*
-- Handles array access and function calls.
parse_postfix = function(state)
    local expr = parse_primary(state)

    while true do
        if match(state, TOKEN.LBRACKET) then
            -- Array access: expr[index]
            local node = make_node(AST.ARRAY_ACCESS, previous(state))
            node.array = expr
            node.index = parse_expression(state)
            consume(state, TOKEN.RBRACKET, "Expected ']' after array index")
            expr = node

        elseif match(state, TOKEN.LPAREN) then
            -- Function call: expr(args)
            -- In JASS, only identifiers can be called, but we parse
            -- generally and let semantic analysis catch errors
            local node = make_node(AST.CALL_EXPR, previous(state))
            node.callee = expr
            node.arguments = parse_arguments(state)
            consume(state, TOKEN.RPAREN, "Expected ')' after arguments")
            expr = node
        else
            break
        end
    end

    return expr
end
-- }}}

-- {{{ parse_unary
-- Parse unary: ("-" | "not") unary | postfix
-- Right-associative for chained unary operators.
parse_unary = function(state)
    if match(state, TOKEN.MINUS) then
        local node = make_node(AST.UNARY_EXPR, previous(state))
        node.operator = "-"
        node.operand = parse_unary(state)  -- Right-associative
        return node
    end

    if match(state, TOKEN.NOT) then
        local node = make_node(AST.UNARY_EXPR, previous(state))
        node.operator = "not"
        node.operand = parse_unary(state)
        return node
    end

    return parse_postfix(state)
end
-- }}}

-- {{{ parse_multiplicative
-- Parse multiplicative: unary (("*" | "/") unary)*
parse_multiplicative = function(state)
    local left = parse_unary(state)

    while true do
        local op = nil
        if match(state, TOKEN.STAR) then
            op = "*"
        elseif match(state, TOKEN.SLASH) then
            op = "/"
        else
            break
        end

        local node = make_node(AST.BINARY_EXPR, previous(state))
        node.operator = op
        node.left = left
        node.right = parse_unary(state)
        left = node
    end

    return left
end
-- }}}

-- {{{ parse_additive
-- Parse additive: multiplicative (("+" | "-") multiplicative)*
parse_additive = function(state)
    local left = parse_multiplicative(state)

    while true do
        local op = nil
        if match(state, TOKEN.PLUS) then
            op = "+"
        elseif match(state, TOKEN.MINUS) then
            op = "-"
        else
            break
        end

        local node = make_node(AST.BINARY_EXPR, previous(state))
        node.operator = op
        node.left = left
        node.right = parse_multiplicative(state)
        left = node
    end

    return left
end
-- }}}

-- {{{ parse_comparison
-- Parse comparison: additive (("==" | "!=" | "<" | "<=" | ">" | ">=") additive)*
parse_comparison = function(state)
    local left = parse_additive(state)

    while true do
        local op = nil
        if match(state, TOKEN.EQUALS) then
            op = "=="
        elseif match(state, TOKEN.NOT_EQUALS) then
            op = "!="
        elseif match(state, TOKEN.LESS) then
            op = "<"
        elseif match(state, TOKEN.LESS_EQUALS) then
            op = "<="
        elseif match(state, TOKEN.GREATER) then
            op = ">"
        elseif match(state, TOKEN.GREATER_EQUALS) then
            op = ">="
        else
            break
        end

        local node = make_node(AST.BINARY_EXPR, previous(state))
        node.operator = op
        node.left = left
        node.right = parse_additive(state)
        left = node
    end

    return left
end
-- }}}

-- {{{ parse_and_expr
-- Parse AND expression: comparison ("and" comparison)*
parse_and_expr = function(state)
    local left = parse_comparison(state)

    while match(state, TOKEN.AND) do
        local node = make_node(AST.BINARY_EXPR, previous(state))
        node.operator = "and"
        node.left = left
        node.right = parse_comparison(state)
        left = node
    end

    return left
end
-- }}}

-- {{{ parse_or_expr
-- Parse OR expression: and_expr ("or" and_expr)*
parse_or_expr = function(state)
    local left = parse_and_expr(state)

    while match(state, TOKEN.OR) do
        local node = make_node(AST.BINARY_EXPR, previous(state))
        node.operator = "or"
        node.left = left
        node.right = parse_and_expr(state)
        left = node
    end

    return left
end
-- }}}

-- {{{ parse_expression
-- Parse an expression starting at current token.
-- Entry point for expression parsing - starts at lowest precedence.
-- @param state Parser state
-- @return AST expression node
parse_expression = function(state)
    return parse_or_expr(state)
end
-- }}}

-- {{{ parse_var_decl
-- Parse variable declaration (used in globals and locals).
-- var_decl = "constant"? type ("array")? IDENT ("=" expr)?
-- @param state Parser state
-- @param allow_constant Whether 'constant' keyword is permitted
-- @return VAR_DECL AST node
parse_var_decl = function(state, allow_constant)
    local node = make_node(AST.VAR_DECL, peek(state))

    -- Check for constant modifier
    node.is_constant = false
    if allow_constant and match(state, TOKEN.CONSTANT) then
        node.is_constant = true
    end

    -- Parse type
    node.var_type = parse_type(state)

    -- Check for array
    node.is_array = match(state, TOKEN.ARRAY)

    -- Parse name
    local name_token = consume(state, TOKEN.IDENTIFIER, "Expected variable name")
    node.name = name_token and name_token.value or "?"

    -- Check for initializer (not allowed for arrays in JASS)
    node.initializer = nil
    if not node.is_array and match(state, TOKEN.ASSIGN) then
        node.initializer = parse_expression(state)
    end

    return node
end
-- }}}

-- {{{ parse_local_decl
-- Parse local variable declaration: local var_decl
-- @param state Parser state
-- @return LOCAL_DECL AST node
parse_local_decl = function(state)
    local node = make_node(AST.LOCAL_DECL, peek(state))
    consume(state, TOKEN.LOCAL, "Expected 'local'")

    -- Reuse var_decl parsing (no constant allowed for locals)
    local var = parse_var_decl(state, false)
    node.var_type = var.var_type
    node.name = var.name
    node.is_array = var.is_array
    node.initializer = var.initializer

    return node
end
-- }}}

-- {{{ parse_statement (placeholder)
-- Placeholder for statement parsing (implemented in 305d).
-- For now, skips tokens until newline.
-- @param state Parser state
-- @return Statement AST node or nil
parse_statement = function(state)
    local token = peek(state)

    -- Handle set statement
    if match(state, TOKEN.SET) then
        local node = make_node(AST.SET_STMT, token)
        local name_token = consume(state, TOKEN.IDENTIFIER, "Expected variable name after 'set'")
        node.name = name_token and name_token.value or "?"

        -- Check for array access
        if match(state, TOKEN.LBRACKET) then
            node.index = parse_expression(state)
            consume(state, TOKEN.RBRACKET, "Expected ']' after index")
        end

        consume(state, TOKEN.ASSIGN, "Expected '=' in set statement")
        node.value = parse_expression(state)
        return node
    end

    -- Handle call statement
    if match(state, TOKEN.CALL) then
        local node = make_node(AST.CALL_STMT, token)
        local name_token = consume(state, TOKEN.IDENTIFIER, "Expected function name after 'call'")
        node.name = name_token and name_token.value or "?"
        node.arguments = {}

        consume(state, TOKEN.LPAREN, "Expected '(' after function name")
        if not check(state, TOKEN.RPAREN) then
            node.arguments[#node.arguments + 1] = parse_expression(state)
            while match(state, TOKEN.COMMA) do
                node.arguments[#node.arguments + 1] = parse_expression(state)
            end
        end
        consume(state, TOKEN.RPAREN, "Expected ')' after arguments")
        return node
    end

    -- Handle return statement
    if match(state, TOKEN.RETURN) then
        local node = make_node(AST.RETURN_STMT, token)
        node.value = nil
        -- Check if there's a return value (not at newline/endfunction)
        if not check_any(state, TOKEN.NEWLINE, TOKEN.ENDFUNCTION, TOKEN.EOF) then
            node.value = parse_expression(state)
        end
        return node
    end

    -- Handle exitwhen statement
    if match(state, TOKEN.EXITWHEN) then
        local node = make_node(AST.EXITWHEN_STMT, token)
        node.condition = parse_expression(state)
        return node
    end

    -- Handle if statement (placeholder - skip to endif)
    if match(state, TOKEN.IF) then
        local node = make_node(AST.IF_STMT, token)
        node.condition = parse_expression(state)
        consume(state, TOKEN.THEN, "Expected 'then' after if condition")
        skip_newlines(state)

        node.then_branch = {}
        while not check_any(state, TOKEN.ELSE, TOKEN.ELSEIF, TOKEN.ENDIF, TOKEN.EOF) do
            if check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) then
                advance(state)
            else
                local stmt = parse_statement(state)
                if stmt then
                    node.then_branch[#node.then_branch + 1] = stmt
                end
            end
        end

        node.elseif_branches = {}
        while match(state, TOKEN.ELSEIF) do
            local elif = { condition = parse_expression(state) }
            consume(state, TOKEN.THEN, "Expected 'then' after elseif condition")
            skip_newlines(state)
            elif.body = {}
            while not check_any(state, TOKEN.ELSE, TOKEN.ELSEIF, TOKEN.ENDIF, TOKEN.EOF) do
                if check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) then
                    advance(state)
                else
                    local stmt = parse_statement(state)
                    if stmt then
                        elif.body[#elif.body + 1] = stmt
                    end
                end
            end
            node.elseif_branches[#node.elseif_branches + 1] = elif
        end

        node.else_branch = nil
        if match(state, TOKEN.ELSE) then
            skip_newlines(state)
            node.else_branch = {}
            while not check_any(state, TOKEN.ENDIF, TOKEN.EOF) do
                if check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) then
                    advance(state)
                else
                    local stmt = parse_statement(state)
                    if stmt then
                        node.else_branch[#node.else_branch + 1] = stmt
                    end
                end
            end
        end

        consume(state, TOKEN.ENDIF, "Expected 'endif'")
        return node
    end

    -- Handle loop statement
    if match(state, TOKEN.LOOP) then
        local node = make_node(AST.LOOP_STMT, token)
        skip_newlines(state)
        node.body = {}
        while not check_any(state, TOKEN.ENDLOOP, TOKEN.EOF) do
            if check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) then
                advance(state)
            else
                local stmt = parse_statement(state)
                if stmt then
                    node.body[#node.body + 1] = stmt
                end
            end
        end
        consume(state, TOKEN.ENDLOOP, "Expected 'endloop'")
        return node
    end

    -- Skip unrecognized tokens to next line
    while not check_any(state, TOKEN.NEWLINE, TOKEN.EOF) and not at_end(state) do
        advance(state)
    end
    return nil
end
-- }}}

-- {{{ parse_type_def
-- Parse type declaration: type NAME extends BASE_TYPE
-- @param state Parser state
-- @return TYPE_DEF AST node
parse_type_def = function(state)
    local node = make_node(AST.TYPE_DEF, peek(state))

    consume(state, TOKEN.TYPE, "Expected 'type'")
    local name_token = consume(state, TOKEN.IDENTIFIER, "Expected type name")
    node.name = name_token and name_token.value or "?"

    consume(state, TOKEN.EXTENDS, "Expected 'extends'")
    node.base_type = parse_type(state)

    return node
end
-- }}}

-- {{{ parse_globals_block
-- Parse globals block: globals var_decl* endglobals
-- @param state Parser state
-- @return GLOBAL_BLOCK AST node
parse_globals_block = function(state)
    local node = make_node(AST.GLOBAL_BLOCK, peek(state))
    node.declarations = {}

    consume(state, TOKEN.GLOBALS, "Expected 'globals'")

    -- Skip newlines after globals keyword
    skip_newlines(state)

    while not check(state, TOKEN.ENDGLOBALS) and not at_end(state) do
        if check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) then
            advance(state)
        else
            local var_decl = parse_var_decl(state, true)  -- allow constant
            if var_decl then
                node.declarations[#node.declarations + 1] = var_decl
            end
            -- Skip newlines after each declaration
            skip_newlines(state)
        end
    end

    consume(state, TOKEN.ENDGLOBALS, "Expected 'endglobals'")

    return node
end
-- }}}

-- {{{ parse_native_decl
-- Parse native function declaration.
-- native_decl = "constant"? "native" IDENT "takes" params "returns" type
-- @param state Parser state
-- @return NATIVE_DECL AST node
parse_native_decl = function(state)
    local node = make_node(AST.NATIVE_DECL, peek(state))

    -- Check for constant modifier (for constant functions)
    node.is_constant = match(state, TOKEN.CONSTANT)

    consume(state, TOKEN.NATIVE, "Expected 'native'")

    local name_token = consume(state, TOKEN.IDENTIFIER, "Expected native function name")
    node.name = name_token and name_token.value or "?"

    consume(state, TOKEN.TAKES, "Expected 'takes'")
    node.params = parse_param_list(state)

    consume(state, TOKEN.RETURNS, "Expected 'returns'")
    node.return_type = parse_type(state)

    return node
end
-- }}}

-- {{{ parse_function_def
-- Parse function definition.
-- function = "function" IDENT "takes" params "returns" type locals stmts "endfunction"
-- @param state Parser state
-- @return FUNCTION_DEF AST node
parse_function_def = function(state)
    local node = make_node(AST.FUNCTION_DEF, peek(state))

    consume(state, TOKEN.FUNCTION, "Expected 'function'")

    local name_token = consume(state, TOKEN.IDENTIFIER, "Expected function name")
    node.name = name_token and name_token.value or "?"

    consume(state, TOKEN.TAKES, "Expected 'takes'")
    node.params = parse_param_list(state)

    consume(state, TOKEN.RETURNS, "Expected 'returns'")
    node.return_type = parse_type(state)

    -- Skip newlines before body
    skip_newlines(state)

    -- Parse locals
    node.locals = {}
    while check(state, TOKEN.LOCAL) do
        local local_decl = parse_local_decl(state)
        if local_decl then
            node.locals[#node.locals + 1] = local_decl
        end
        skip_newlines(state)
    end

    -- Parse body statements
    node.body = {}
    while not check(state, TOKEN.ENDFUNCTION) and not at_end(state) do
        if check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) then
            advance(state)
        else
            local stmt = parse_statement(state)
            if stmt then
                node.body[#node.body + 1] = stmt
            end
            skip_newlines(state)
        end
    end

    consume(state, TOKEN.ENDFUNCTION, "Expected 'endfunction'")

    return node
end
-- }}}

-- {{{ parse_program
-- Parse entire JASS program.
-- program = (type_def | globals | native | function)*
-- @param state Parser state
-- @return PROGRAM AST node
parse_program = function(state)
    local program = make_node(AST.PROGRAM, peek(state))
    program.declarations = {}

    -- Skip leading newlines
    skip_newlines(state)

    while not at_end(state) do
        local decl = nil

        if check(state, TOKEN.TYPE) then
            decl = parse_type_def(state)
        elseif check(state, TOKEN.GLOBALS) then
            decl = parse_globals_block(state)
        elseif check(state, TOKEN.NATIVE) then
            decl = parse_native_decl(state)
        elseif check(state, TOKEN.CONSTANT) then
            -- Could be constant native or constant global
            local next_token = peek_next(state)
            if next_token and next_token.type == TOKEN.NATIVE then
                decl = parse_native_decl(state)
            else
                -- Unexpected constant at top level
                error_at_current(state, "Unexpected 'constant' at top level (did you mean to put this in globals?)")
                synchronize(state)
            end
        elseif check(state, TOKEN.FUNCTION) then
            decl = parse_function_def(state)
        elseif check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) then
            advance(state)  -- Skip blank lines and comments
        else
            error_at_current(state, "Expected type, globals, native, or function declaration")
            synchronize(state)
        end

        if decl then
            program.declarations[#program.declarations + 1] = decl
        end

        -- Skip trailing newlines after each declaration
        skip_newlines(state)
    end

    return program
end
-- }}}

-- {{{ parse
-- Main entry point: parse token stream into AST.
-- @param tokens Array of tokens from lexer.tokenize()
-- @return ast PROGRAM node, errors array
function parser.parse(tokens)
    local state = create_state(tokens)
    local program = parse_program(state)
    return program, state.errors
end
-- }}}

-- {{{ module export
parser.create_state = create_state

-- Token inspection
parser.at_end = at_end
parser.peek = peek
parser.peek_next = peek_next
parser.previous = previous
parser.check = check
parser.check_any = check_any

-- Token consumption
parser.advance = advance
parser.match = match
parser.match_any = match_any
parser.consume = consume

-- Error handling
parser.error_at = error_at
parser.error_at_current = error_at_current
parser.error_at_previous = error_at_previous
parser.format_error = format_error
parser.has_errors = has_errors
parser.get_errors = get_errors

-- Recovery
parser.synchronize = synchronize
parser.skip_newlines = skip_newlines

-- AST construction
parser.make_node = make_node

-- Expression parsing (305c)
parser.parse_expression = parse_expression
parser.can_start_expression = can_start_expression

return parser
-- }}}
