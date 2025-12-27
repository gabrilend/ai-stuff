--[[
JASS-to-Lua Transpiler - Core Infrastructure

Converts JASS AST (from parser.lua) to executable Lua code.
Uses a two-pass architecture:
1. Collection pass - scans declarations to build symbol tables
2. Generation pass - produces Lua code for each declaration

This module provides the foundation; actual transpilation of specific
constructs is implemented in sub-modules (306b-306e).
]]

local transpiler = {}

-- Forward declarations for mutually recursive functions
local emit
local emit_blank
local emit_comment
local add_error
local format_error
local format_params
local is_native
local is_global
local collect_declarations
local transpile_declaration
local transpile_globals
local transpile_function
local transpile_statement
local transpile_expr

-- {{{ create_context
-- Creates a new transpilation context for tracking state during code generation.
-- @return Context table with output, symbol tables, and state tracking
local function create_context()
    return {
        -- Output management
        indent = 0,           -- Current indentation level (4 spaces per level)
        output = {},          -- Array of output lines

        -- Declaration tracking (populated in first pass)
        globals = {},         -- Global variable declarations {name -> {var_type, is_array, is_constant}}
        functions = {},       -- Function signatures {name -> {params, return_type}}
        natives = {},         -- Native function declarations {name -> {params, return_type, is_constant}}
        types = {},           -- Type definitions {name -> base_type}

        -- Current state during generation
        current_func = nil,   -- Name of function being transpiled (for local scoping)
        current_locals = {},  -- Local variable names in current function
        in_loop = false,      -- Whether we're inside a loop (for exitwhen translation)
        loop_depth = 0,       -- Nesting depth of loops

        -- Error accumulation
        errors = {},          -- Array of error tables
    }
end
-- }}}

-- {{{ emit
-- Emit a line of output with proper indentation.
-- @param ctx Transpiler context
-- @param line Line of code to emit (without leading indentation)
emit = function(ctx, line)
    local indent_str = string.rep("    ", ctx.indent)
    ctx.output[#ctx.output + 1] = indent_str .. line
end
-- }}}

-- {{{ emit_raw
-- Emit a line of output without indentation.
-- Used for blank lines or pre-formatted content.
-- @param ctx Transpiler context
-- @param line Line to emit exactly as-is
local function emit_raw(ctx, line)
    ctx.output[#ctx.output + 1] = line
end
-- }}}

-- {{{ emit_blank
-- Emit a blank line (no indentation).
-- @param ctx Transpiler context
emit_blank = function(ctx)
    ctx.output[#ctx.output + 1] = ""
end
-- }}}

-- {{{ emit_comment
-- Emit a Lua comment with proper indentation.
-- @param ctx Transpiler context
-- @param text Comment text (without -- prefix)
emit_comment = function(ctx, text)
    emit(ctx, "-- " .. text)
end
-- }}}

-- {{{ indent
-- Increase indentation level.
-- @param ctx Transpiler context
local function indent(ctx)
    ctx.indent = ctx.indent + 1
end
-- }}}

-- {{{ dedent
-- Decrease indentation level.
-- @param ctx Transpiler context
local function dedent(ctx)
    ctx.indent = ctx.indent - 1
    if ctx.indent < 0 then
        ctx.indent = 0
    end
end
-- }}}

-- {{{ add_error
-- Record a transpilation error with optional location info.
-- @param ctx Transpiler context
-- @param message Error description
-- @param node Optional AST node for location info
add_error = function(ctx, message, node)
    local err = {
        message = message,
        line = node and node.line,
        col = node and node.col,
    }
    ctx.errors[#ctx.errors + 1] = err
end
-- }}}

-- {{{ format_error
-- Format an error for human-readable display.
-- @param err Error table from ctx.errors
-- @return Formatted error string
format_error = function(err)
    if err.line then
        return string.format("Line %d, Col %d: %s",
            err.line, err.col or 0, err.message)
    else
        return err.message
    end
end
-- }}}

-- {{{ format_params
-- Format a parameter list for display in comments.
-- @param params Array of {type, name} parameter tables
-- @return Formatted string like "integer x, real y"
format_params = function(params)
    if not params or #params == 0 then
        return "nothing"
    end
    local parts = {}
    for _, p in ipairs(params) do
        parts[#parts + 1] = (p.type or "?") .. " " .. (p.name or "?")
    end
    return table.concat(parts, ", ")
end
-- }}}

-- {{{ is_native
-- Check if a function name refers to a native function.
-- @param ctx Transpiler context
-- @param name Function name to check
-- @return true if name is a native function
is_native = function(ctx, name)
    return ctx.natives[name] ~= nil
end
-- }}}

-- {{{ is_global
-- Check if a variable name refers to a global variable.
-- @param ctx Transpiler context
-- @param name Variable name to check
-- @return true if name is a global variable
is_global = function(ctx, name)
    return ctx.globals[name] ~= nil
end
-- }}}

-- {{{ is_local
-- Check if a variable name refers to a local variable in current function.
-- @param ctx Transpiler context
-- @param name Variable name to check
-- @return true if name is a local in current function
local function is_local(ctx, name)
    return ctx.current_locals[name] ~= nil
end
-- }}}

-- {{{ collect_declarations
-- First pass: scan all declarations to build symbol tables.
-- This allows forward references to work correctly in the generation pass.
-- @param ctx Transpiler context
-- @param ast PROGRAM AST node
collect_declarations = function(ctx, ast)
    for _, decl in ipairs(ast.declarations) do
        if decl.type == "TYPE_DEF" then
            -- Record type extension for reference
            ctx.types[decl.name] = decl.base_type

        elseif decl.type == "GLOBAL_BLOCK" then
            -- Record all global variable declarations
            for _, var in ipairs(decl.declarations or {}) do
                ctx.globals[var.name] = {
                    var_type = var.var_type,
                    is_array = var.is_array,
                    is_constant = var.is_constant,
                }
            end

        elseif decl.type == "NATIVE_DECL" then
            -- Record native function signature
            ctx.natives[decl.name] = {
                params = decl.params,
                return_type = decl.return_type,
                is_constant = decl.is_constant,
            }

        elseif decl.type == "FUNCTION_DEF" then
            -- Record user function signature
            ctx.functions[decl.name] = {
                params = decl.params,
                return_type = decl.return_type,
            }
        end
    end
end
-- }}}

-- {{{ transpile_globals (stub)
-- Transpile a globals block to Lua.
-- Stub implementation - full version in 306b.
-- @param ctx Transpiler context
-- @param node GLOBAL_BLOCK AST node
transpile_globals = function(ctx, node)
    emit_comment(ctx, "globals block")
    for _, var in ipairs(node.declarations or {}) do
        local array_str = var.is_array and " array" or ""
        local const_str = var.is_constant and "constant " or ""
        emit_comment(ctx, string.format("  %s%s%s %s",
            const_str, var.var_type or "?", array_str, var.name or "?"))
    end
end
-- }}}

-- {{{ transpile_function (stub)
-- Transpile a function definition to Lua.
-- Stub implementation - full version in 306b.
-- @param ctx Transpiler context
-- @param node FUNCTION_DEF AST node
transpile_function = function(ctx, node)
    emit_comment(ctx, string.format("function %s takes %s returns %s",
        node.name or "?",
        format_params(node.params),
        node.return_type or "nothing"))
end
-- }}}

-- {{{ transpile_statement (stub)
-- Transpile a statement to Lua.
-- Stub implementation - full version in 306c.
-- @param ctx Transpiler context
-- @param node Statement AST node
transpile_statement = function(ctx, node)
    emit_comment(ctx, "statement: " .. (node.type or "?"))
end
-- }}}

-- {{{ transpile_expr (stub)
-- Transpile an expression to Lua and return the code string.
-- Stub implementation - full version in 306d.
-- @param ctx Transpiler context
-- @param node Expression AST node
-- @return Lua expression string
transpile_expr = function(ctx, node)
    return "nil --[[expr: " .. (node and node.type or "?") .. "]]"
end
-- }}}

-- {{{ transpile_declaration
-- Dispatch to appropriate transpiler for each declaration type.
-- @param ctx Transpiler context
-- @param decl Declaration AST node
transpile_declaration = function(ctx, decl)
    if decl.type == "TYPE_DEF" then
        -- Type definitions don't generate code (Lua is dynamically typed)
        -- Emit as documentation comment
        emit_comment(ctx, string.format("type %s extends %s",
            decl.name or "?", decl.base_type or "handle"))

    elseif decl.type == "GLOBAL_BLOCK" then
        transpile_globals(ctx, decl)

    elseif decl.type == "NATIVE_DECL" then
        -- Native declarations don't generate code (provided by runtime)
        -- Emit as documentation comment
        local const_str = decl.is_constant and "constant " or ""
        emit_comment(ctx, string.format("%snative %s takes %s returns %s",
            const_str,
            decl.name or "?",
            format_params(decl.params),
            decl.return_type or "nothing"))

    elseif decl.type == "FUNCTION_DEF" then
        transpile_function(ctx, decl)

    else
        add_error(ctx, "Unknown declaration type: " .. tostring(decl.type), decl)
    end
end
-- }}}

-- {{{ transpile
-- Main entry point: transpile JASS AST to Lua code.
-- Uses two-pass architecture: collect declarations, then generate code.
-- @param ast PROGRAM AST node from parser
-- @return lua_code string, errors array
local function transpile(ast)
    local ctx = create_context()

    -- Validate input
    if not ast then
        add_error(ctx, "Invalid AST: nil")
        return nil, ctx.errors
    end

    if ast.type ~= "PROGRAM" then
        add_error(ctx, "Invalid AST: expected PROGRAM node, got " .. tostring(ast.type))
        return nil, ctx.errors
    end

    -- First pass: collect all declarations for symbol tables
    collect_declarations(ctx, ast)

    -- Emit header comment
    emit_comment(ctx, "Generated by JASS-to-Lua transpiler")
    emit_comment(ctx, "Do not edit - regenerate from source")
    emit_blank(ctx)

    -- Second pass: generate code for each declaration
    for i, decl in ipairs(ast.declarations) do
        transpile_declaration(ctx, decl)
        -- Add blank line between declarations (except after last)
        if i < #ast.declarations then
            emit_blank(ctx)
        end
    end

    -- Join output lines
    local output = table.concat(ctx.output, "\n")

    return output, ctx.errors
end
-- }}}

-- {{{ Module exports
-- Main entry point
transpiler.transpile = transpile

-- Internal functions exposed for sub-issues to extend
transpiler._create_context = create_context
transpiler._emit = emit
transpiler._emit_raw = emit_raw
transpiler._emit_blank = emit_blank
transpiler._emit_comment = emit_comment
transpiler._indent = indent
transpiler._dedent = dedent
transpiler._add_error = add_error
transpiler._format_error = format_error
transpiler._format_params = format_params
transpiler._is_native = is_native
transpiler._is_global = is_global
transpiler._is_local = is_local
transpiler._collect_declarations = collect_declarations

-- Stub functions that will be replaced by sub-issues
transpiler._transpile_declaration = transpile_declaration
transpiler._transpile_globals = transpile_globals
transpiler._transpile_function = transpile_function
transpiler._transpile_statement = transpile_statement
transpiler._transpile_expr = transpile_expr

return transpiler
-- }}}
