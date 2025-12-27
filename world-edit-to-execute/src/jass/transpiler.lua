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

-- {{{ BUILTIN_NATIVES
-- Built-in list of common native functions as fallback when common.j is not available.
-- These are functions defined with 'native' keyword in common.j that require runtime. prefix.
-- BJ functions (from blizzard.j) are NOT included - they're regular JASS functions.
local BUILTIN_NATIVES = {
    -- Player functions
    "Player", "GetLocalPlayer", "GetTriggerPlayer", "GetOwningPlayer",
    "SetPlayerState", "GetPlayerState", "GetPlayerName", "GetPlayerId",
    "GetPlayerRace", "GetPlayerController", "GetPlayerSlotState",

    -- Unit creation and management
    "CreateUnit", "CreateUnitAtLoc", "CreateUnitAtLocByName",
    "RemoveUnit", "KillUnit", "ShowUnit",
    "GetTriggerUnit", "GetSpellAbilityUnit", "GetAttacker", "GetKillingUnit",
    "GetDyingUnit", "GetDecayingUnit", "GetLevelingUnit",
    "GetFilterUnit", "GetEnumUnit",
    "SetUnitX", "SetUnitY", "SetUnitPosition", "SetUnitPositionLoc",
    "GetUnitX", "GetUnitY", "GetUnitLoc",
    "SetUnitFacing", "GetUnitFacing",
    "GetUnitTypeId", "GetUnitName", "GetUnitRace",
    "IsUnitType", "IsUnitAlly", "IsUnitEnemy",
    "UnitAddAbility", "UnitRemoveAbility", "UnitHasBuffBJ",
    "SetUnitState", "GetUnitState",
    "SetUnitOwner", "SetUnitColor",
    "UnitAddItem", "UnitRemoveItem", "UnitHasItem",
    "IssueImmediateOrder", "IssuePointOrder", "IssueTargetOrder",

    -- Triggers
    "CreateTrigger", "DestroyTrigger", "EnableTrigger", "DisableTrigger",
    "TriggerAddCondition", "TriggerAddAction", "TriggerRemoveAction",
    "TriggerRegisterTimerEvent", "TriggerRegisterTimerExpireEvent",
    "TriggerRegisterUnitEvent", "TriggerRegisterPlayerEvent",
    "TriggerRegisterPlayerUnitEvent", "TriggerRegisterEnterRegion",
    "TriggerRegisterLeaveRegion", "TriggerEvaluate", "TriggerExecute",
    "GetTriggeringTrigger", "GetTriggerEventId",
    "Condition", "Filter", "And", "Or", "Not", "DestroyCondition",
    "DestroyBoolExpr",

    -- Groups
    "CreateGroup", "DestroyGroup", "GroupClear",
    "GroupAddUnit", "GroupRemoveUnit",
    "ForGroup", "FirstOfGroup", "CountUnitsInGroup",
    "GroupEnumUnitsInRange", "GroupEnumUnitsInRect",
    "GroupEnumUnitsOfPlayer", "GroupEnumUnitsOfType",
    "IsUnitInGroup",

    -- Forces (player groups)
    "CreateForce", "DestroyForce", "ForceClear",
    "ForceAddPlayer", "ForceRemovePlayer",
    "ForForce", "IsPlayerInForce",

    -- Regions/Rects
    "Rect", "RectFromLoc", "RemoveRect",
    "GetRectCenterX", "GetRectCenterY",
    "GetRectMinX", "GetRectMinY", "GetRectMaxX", "GetRectMaxY",
    "SetRect", "MoveRectTo",
    "CreateRegion", "RemoveRegion", "RegionAddRect", "RegionClearRect",
    "IsPointInRegion", "IsUnitInRegion",

    -- Locations
    "Location", "RemoveLocation", "GetLocationX", "GetLocationY",
    "GetLocationZ",

    -- Math
    "Cos", "Sin", "Tan", "Acos", "Asin", "Atan", "Atan2",
    "SquareRoot", "Pow", "Deg2Rad", "Rad2Deg",
    "GetRandomInt", "GetRandomReal", "SetRandomSeed",
    "RMinBJ", "RMaxBJ", "IMinBJ", "IMaxBJ", "RAbsBJ", "IAbsBJ",
    "SignReal", "SignInteger",

    -- String functions
    "I2S", "R2S", "R2SW", "S2I", "S2R",
    "I2H", "SubString", "StringLength", "StringCase", "StringHash",
    "GetLocalizedString", "GetLocalizedHotkey",

    -- Display/UI
    "DisplayTextToPlayer", "DisplayTimedTextToPlayer",
    "DisplayTimedTextFromPlayer", "ClearTextMessages",
    "SetTextTagText", "SetTextTagPos", "SetTextTagColor",
    "SetTextTagVelocity", "SetTextTagVisibility", "SetTextTagPermanent",
    "SetTextTagAge", "SetTextTagLifespan", "SetTextTagFadepoint",
    "CreateTextTag", "DestroyTextTag",
    "CreateLeaderboard", "DestroyLeaderboard",
    "CreateMultiboard", "DestroyMultiboard",

    -- Effects
    "AddSpecialEffect", "AddSpecialEffectLoc", "AddSpecialEffectTarget",
    "DestroyEffect", "GetSpellAbilityId",
    "AddSpellEffect", "AddSpellEffectLoc", "AddSpellEffectTarget",
    "AddLightning", "MoveLightning", "DestroyLightning",

    -- Timers
    "CreateTimer", "DestroyTimer", "TimerStart", "PauseTimer", "ResumeTimer",
    "GetExpiredTimer", "TimerGetElapsed", "TimerGetRemaining", "TimerGetTimeout",

    -- Sound
    "CreateSound", "CreateSoundFilenameWithLabel", "CreateMIDISound",
    "SetSoundDuration", "SetSoundVolume", "SetSoundPitch",
    "SetSoundPosition", "SetSoundDistances", "SetSoundConeAngles",
    "StartSound", "StopSound", "KillSoundWhenDone",
    "PlaySoundBJ", "PlaySoundOnUnitBJ",

    -- Camera
    "SetCameraPosition", "SetCameraTargetController",
    "PanCameraTo", "PanCameraToTimed", "PanCameraToWithZ",
    "SetCameraField", "GetCameraField", "AdjustCameraField",
    "GetCameraTargetPositionX", "GetCameraTargetPositionY", "GetCameraTargetPositionZ",
    "GetCameraEyePositionX", "GetCameraEyePositionY", "GetCameraEyePositionZ",
    "SetCinematicCamera", "ResetToGameCamera", "CameraSetupApply",

    -- Fog of war
    "CreateFogModifierRect", "CreateFogModifierRadius",
    "FogModifierStart", "FogModifierStop", "DestroyFogModifier",
    "SetFogStateRect", "SetFogStateRadius",

    -- Item
    "CreateItem", "RemoveItem", "GetItemTypeId", "GetItemX", "GetItemY",
    "SetItemPosition", "SetItemDropOnDeath", "SetItemDroppable",
    "SetItemPlayer", "GetItemPlayer",

    -- Destructable
    "CreateDestructable", "CreateDestructableZ", "RemoveDestructable",
    "KillDestructable", "SetDestructableLife", "GetDestructableLife",
    "GetDestructableMaxLife", "GetDestructableX", "GetDestructableY",
    "GetDestructableTypeId",

    -- Game state
    "PauseGame", "SetGameSpeed", "SetMapFlag", "SetCreepCampFilterState",
    "SetAllyColorFilterState", "GetGamePlaying",

    -- Handles
    "GetHandleId",

    -- ExecuteFunc (special - calls function by string name)
    "ExecuteFunc",

    -- Ability-related
    "GetSpellAbility", "GetSpellTargetUnit", "GetSpellTargetItem",
    "GetSpellTargetLoc", "GetSpellTargetX", "GetSpellTargetY",
    "GetSpellTargetDestructable",
}

-- Convert BUILTIN_NATIVES list to a lookup table for O(1) access
local builtin_natives_set = {}
for _, name in ipairs(BUILTIN_NATIVES) do
    builtin_natives_set[name] = true
end
-- }}}

-- {{{ init_builtin_natives
-- Initialize the built-in native registry as a fallback.
-- Returns a table mapping function names to minimal signature info.
-- @return Native registry table
local function init_builtin_natives()
    local registry = {}
    for _, name in ipairs(BUILTIN_NATIVES) do
        registry[name] = {
            params = {},           -- Unknown params for builtins
            return_type = "unknown",
            is_constant = false,
            is_builtin = true,     -- Mark as builtin (not from parsed common.j)
        }
    end
    return registry
end
-- }}}

-- {{{ load_natives_from_ast
-- Extract native function declarations from a parsed AST.
-- Used to load natives from common.j or similar files.
-- @param ast PROGRAM AST node containing NATIVE_DECL nodes
-- @return Native registry table mapping names to signatures
local function load_natives_from_ast(ast)
    local registry = {}

    if not ast or not ast.declarations then
        return registry
    end

    for _, decl in ipairs(ast.declarations) do
        if decl.type == "NATIVE_DECL" then
            registry[decl.name] = {
                params = decl.params or {},
                return_type = decl.return_type or "nothing",
                is_constant = decl.is_constant or false,
                is_builtin = false,
            }
        end
    end

    return registry
end
-- }}}

-- {{{ load_common_j_natives
-- Parse a common.j source string and extract native signatures.
-- @param common_j_source Source code string of common.j
-- @return Native registry table, errors array
local function load_common_j_natives(common_j_source)
    local lexer = require("jass.lexer")
    local parser = require("jass.parser")

    local tokens, lex_err = lexer.tokenize(common_j_source)
    if lex_err then
        return {}, {{message = "Lexer error: " .. lex_err}}
    end

    local ast, parse_errors = parser.parse(tokens)

    -- Parse errors are warnings - we may still have extracted some natives
    local registry = load_natives_from_ast(ast)

    return registry, parse_errors
end
-- }}}

-- {{{ merge_native_registries
-- Merge multiple native registries into one.
-- Later registries override earlier ones for duplicate names.
-- @param ... Variable number of registry tables
-- @return Merged registry table
local function merge_native_registries(...)
    local merged = {}
    for i = 1, select("#", ...) do
        local registry = select(i, ...)
        if registry then
            for name, info in pairs(registry) do
                merged[name] = info
            end
        end
    end
    return merged
end
-- }}}

-- {{{ create_context
-- Creates a new transpilation context for tracking state during code generation.
-- @param options Optional configuration table:
--   - native_registry: Pre-loaded native function registry (default: builtin natives)
--   - use_runtime_prefix: Whether to prefix native calls with runtime. (default: true)
-- @return Context table with output, symbol tables, and state tracking
local function create_context(options)
    options = options or {}

    return {
        -- Output management
        indent = 0,           -- Current indentation level (4 spaces per level)
        output = {},          -- Array of output lines

        -- Declaration tracking (populated in first pass)
        globals = {},         -- Global variable declarations {name -> {var_type, is_array, is_constant}}
        functions = {},       -- Function signatures {name -> {params, return_type}}
        natives = {},         -- Native function declarations from map script {name -> {params, return_type, is_constant}}
        types = {},           -- Type definitions {name -> base_type}

        -- Native function handling
        native_registry = options.native_registry or init_builtin_natives(),
        use_runtime_prefix = options.use_runtime_prefix ~= false,  -- Default true

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
-- Checks both the pre-loaded native registry (from common.j or builtins)
-- and natives declared in the map script itself.
-- @param ctx Transpiler context
-- @param name Function name to check
-- @return true if name is a native function
is_native = function(ctx, name)
    -- Check native registry first (from common.j or builtins)
    if ctx.native_registry and ctx.native_registry[name] then
        return true
    end

    -- Check declarations collected from map script (native declarations in war3map.j)
    if ctx.natives[name] then
        return true
    end

    -- Check builtin natives set as final fallback
    if builtin_natives_set[name] then
        return true
    end

    return false
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

-- {{{ default_value
-- Return the default Lua value for a JASS type.
-- JASS variables have defined default values when not explicitly initialized.
-- @param var_type JASS type name
-- @return Lua literal string for the default value
local function default_value(var_type)
    local defaults = {
        integer = "0",
        real = "0.0",
        boolean = "false",
        string = '""',
        code = "nil",
        nothing = "nil",
    }

    -- Primitive types have specific defaults
    if defaults[var_type] then
        return defaults[var_type]
    else
        -- Handle types (unit, player, etc.) default to nil (null)
        return "nil"
    end
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

-- {{{ transpile_globals
-- Transpile a globals block to Lua local variables.
-- Global variables become module-level locals in Lua.
-- @param ctx Transpiler context
-- @param node GLOBAL_BLOCK AST node
transpile_globals = function(ctx, node)
    emit_comment(ctx, "Globals")

    for _, var in ipairs(node.declarations or {}) do
        local decl

        if var.is_array then
            -- Arrays become empty tables
            decl = string.format("local %s = {}", var.name)

        elseif var.initializer then
            -- Variable with explicit initializer
            local init_value = transpile_expr(ctx, var.initializer)
            decl = string.format("local %s = %s", var.name, init_value)

        else
            -- Variable without initializer - use type default
            local def = default_value(var.var_type)
            decl = string.format("local %s = %s", var.name, def)
        end

        -- Add constant annotation if applicable
        if var.is_constant then
            decl = decl .. "  -- constant"
        end

        emit(ctx, decl)
    end
end
-- }}}

-- {{{ transpile_local_decl
-- Transpile a local variable declaration inside a function.
-- @param ctx Transpiler context
-- @param node LOCAL_DECL AST node
local function transpile_local_decl(ctx, node)
    local decl

    if node.is_array then
        -- Local arrays become empty tables
        decl = string.format("local %s = {}", node.name)

    elseif node.initializer then
        -- Local with explicit initializer
        local init_value = transpile_expr(ctx, node.initializer)
        decl = string.format("local %s = %s", node.name, init_value)

    else
        -- Local without initializer - use type default
        local def = default_value(node.var_type)
        decl = string.format("local %s = %s", node.name, def)
    end

    emit(ctx, decl)

    -- Track local for scoping
    ctx.current_locals[node.name] = true
end
-- }}}

-- {{{ transpile_function
-- Transpile a function definition to Lua.
-- @param ctx Transpiler context
-- @param node FUNCTION_DEF AST node
transpile_function = function(ctx, node)
    -- Track current function for context
    ctx.current_func = node.name
    ctx.current_locals = {}

    -- Build parameter list (skip 'nothing' type parameters)
    local params = {}
    if node.params then
        for _, p in ipairs(node.params) do
            if p.type ~= "nothing" then
                params[#params + 1] = p.name
                -- Parameters are also locals
                ctx.current_locals[p.name] = true
            end
        end
    end

    local param_str = table.concat(params, ", ")

    -- Emit function signature
    emit(ctx, string.format("local function %s(%s)", node.name, param_str))
    indent(ctx)

    -- Emit local declarations first (JASS requires locals before statements)
    if node.locals and #node.locals > 0 then
        for _, local_var in ipairs(node.locals) do
            transpile_local_decl(ctx, local_var)
        end
        -- Blank line between locals and statements if both exist
        if node.body and #node.body > 0 then
            emit_blank(ctx)
        end
    end

    -- Emit function body statements
    if node.body then
        for _, stmt in ipairs(node.body) do
            transpile_statement(ctx, stmt)
        end
    end

    -- Close function
    dedent(ctx)
    emit(ctx, "end")

    -- Clear current function context
    ctx.current_func = nil
    ctx.current_locals = {}
end
-- }}}

-- Forward declarations for statement transpilation
local transpile_set
local transpile_call
local transpile_if
local transpile_loop
local transpile_exitwhen
local transpile_return

-- {{{ transpile_set
-- Transpile SET statement: set x = expr / set arr[i] = expr
-- @param ctx Transpiler context
-- @param node SET_STMT AST node
transpile_set = function(ctx, node)
    local target = node.name  -- Variable name

    if node.index then
        -- Array assignment: set arr[i] = value
        local index_expr = transpile_expr(ctx, node.index)
        local value_expr = transpile_expr(ctx, node.value)
        emit(ctx, string.format("%s[%s] = %s", target, index_expr, value_expr))
    else
        -- Simple assignment: set x = value
        local value_expr = transpile_expr(ctx, node.value)
        emit(ctx, string.format("%s = %s", target, value_expr))
    end
end
-- }}}

-- {{{ transpile_call
-- Transpile CALL statement: call foo(args)
-- Native functions are prefixed with runtime.
-- @param ctx Transpiler context
-- @param node CALL_STMT AST node
transpile_call = function(ctx, node)
    local func_name = node.name
    local args = {}

    -- Transpile each argument
    for _, arg in ipairs(node.arguments or {}) do
        args[#args + 1] = transpile_expr(ctx, arg)
    end

    local args_str = table.concat(args, ", ")

    -- Check if this is a native function call
    if is_native(ctx, func_name) then
        -- Native calls go through runtime
        emit(ctx, string.format("runtime.%s(%s)", func_name, args_str))
    else
        -- User-defined function call
        emit(ctx, string.format("%s(%s)", func_name, args_str))
    end
end
-- }}}

-- {{{ transpile_if
-- Transpile IF statement: if...then...elseif...else...endif
-- @param ctx Transpiler context
-- @param node IF_STMT AST node
transpile_if = function(ctx, node)
    -- Main condition
    local cond_expr = transpile_expr(ctx, node.condition)
    emit(ctx, string.format("if %s then", cond_expr))

    -- Then branch
    ctx.indent = ctx.indent + 1
    for _, stmt in ipairs(node.then_branch or {}) do
        transpile_statement(ctx, stmt)
    end
    ctx.indent = ctx.indent - 1

    -- Elseif branches
    for _, elseif_clause in ipairs(node.elseif_branches or {}) do
        local elseif_cond = transpile_expr(ctx, elseif_clause.condition)
        emit(ctx, string.format("elseif %s then", elseif_cond))

        ctx.indent = ctx.indent + 1
        for _, stmt in ipairs(elseif_clause.body or {}) do
            transpile_statement(ctx, stmt)
        end
        ctx.indent = ctx.indent - 1
    end

    -- Else branch
    if node.else_branch and #node.else_branch > 0 then
        emit(ctx, "else")

        ctx.indent = ctx.indent + 1
        for _, stmt in ipairs(node.else_branch) do
            transpile_statement(ctx, stmt)
        end
        ctx.indent = ctx.indent - 1
    end

    emit(ctx, "end")
end
-- }}}

-- {{{ transpile_loop
-- Transpile LOOP statement: loop...endloop → while true do...end
-- @param ctx Transpiler context
-- @param node LOOP_STMT AST node
transpile_loop = function(ctx, node)
    -- JASS loop becomes Lua while true do
    emit(ctx, "while true do")

    -- Track that we're in a loop (for exitwhen validation)
    local was_in_loop = ctx.in_loop
    ctx.in_loop = true
    ctx.loop_depth = (ctx.loop_depth or 0) + 1

    ctx.indent = ctx.indent + 1
    for _, stmt in ipairs(node.body or {}) do
        transpile_statement(ctx, stmt)
    end
    ctx.indent = ctx.indent - 1

    -- Restore loop context
    ctx.in_loop = was_in_loop
    ctx.loop_depth = ctx.loop_depth - 1

    emit(ctx, "end")
end
-- }}}

-- {{{ transpile_exitwhen
-- Transpile EXITWHEN statement: exitwhen cond → if cond then break end
-- @param ctx Transpiler context
-- @param node EXITWHEN_STMT AST node
transpile_exitwhen = function(ctx, node)
    -- Validate we're inside a loop
    if not ctx.in_loop then
        add_error(ctx, "exitwhen outside of loop", node)
    end

    -- exitwhen condition → if condition then break end
    local cond_expr = transpile_expr(ctx, node.condition)
    emit(ctx, string.format("if %s then break end", cond_expr))
end
-- }}}

-- {{{ transpile_return
-- Transpile RETURN statement: return / return expr
-- @param ctx Transpiler context
-- @param node RETURN_STMT AST node
transpile_return = function(ctx, node)
    if node.value then
        -- Return with value
        local value_expr = transpile_expr(ctx, node.value)
        emit(ctx, string.format("return %s", value_expr))
    else
        -- Return without value (from "returns nothing" function)
        emit(ctx, "return")
    end
end
-- }}}

-- {{{ transpile_statement
-- Main statement transpilation dispatcher.
-- @param ctx Transpiler context
-- @param node Statement AST node
transpile_statement = function(ctx, node)
    if not node then
        add_error(ctx, "Nil statement node")
        return
    end

    -- Handle debug-marked statements (optional debug prefix in JASS)
    if node.is_debug then
        emit_comment(ctx, "debug statement")
    end

    if node.type == "SET_STMT" then
        transpile_set(ctx, node)

    elseif node.type == "CALL_STMT" then
        transpile_call(ctx, node)

    elseif node.type == "IF_STMT" then
        transpile_if(ctx, node)

    elseif node.type == "LOOP_STMT" then
        transpile_loop(ctx, node)

    elseif node.type == "EXITWHEN_STMT" then
        transpile_exitwhen(ctx, node)

    elseif node.type == "RETURN_STMT" then
        transpile_return(ctx, node)

    else
        add_error(ctx, "Unknown statement type: " .. tostring(node.type), node)
    end
end
-- }}}

-- {{{ operator_map
-- Maps JASS operators to Lua operators.
-- Most are identical, but != becomes ~= in Lua.
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

-- {{{ escape_string
-- Escape special characters in a string for Lua literal.
-- @param str Raw string value
-- @return Lua string literal with quotes
local function escape_string(str)
    if not str then return '""' end

    local escaped = str:gsub("\\", "\\\\")  -- Backslash first
                       :gsub("\n", "\\n")
                       :gsub("\r", "\\r")
                       :gsub("\t", "\\t")
                       :gsub("\"", "\\\"")

    return '"' .. escaped .. '"'
end
-- }}}

-- {{{ fourcc_to_int
-- Convert a 4-character FourCC code to its integer value.
-- WC3 uses big-endian byte order: 'hfoo' = (h << 24) | (f << 16) | (o << 8) | o
-- @param str 4-character string
-- @return Integer value
local function fourcc_to_int(str)
    if not str or #str ~= 4 then
        return 0
    end

    local b1 = str:byte(1)
    local b2 = str:byte(2)
    local b3 = str:byte(3)
    local b4 = str:byte(4)

    -- Manual bit shift using multiplication (works in all Lua versions)
    return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end
-- }}}

-- {{{ is_string_context
-- Determine if a binary + should be string concatenation.
-- Uses heuristics: if either operand is a string literal, use ..
-- @param ctx Transpiler context
-- @param node BINARY_EXPR node
-- @return true if string concatenation should be used
local function is_string_context(ctx, node)
    if node.left and node.left.type == "LITERAL" and node.left.literal_type == "string" then
        return true
    end
    if node.right and node.right.type == "LITERAL" and node.right.literal_type == "string" then
        return true
    end
    return false
end
-- }}}

-- Forward declarations for expression transpilation
local transpile_literal
local transpile_binary
local transpile_unary
local transpile_call_expr
local transpile_array_access

-- {{{ transpile_literal
-- Transpile a literal value to Lua.
-- @param ctx Transpiler context
-- @param node LITERAL AST node
-- @return Lua literal string
transpile_literal = function(ctx, node)
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
        return escape_string(value)

    elseif lit_type == "null" then
        return "nil"

    elseif lit_type == "rawcode" or lit_type == "fourcc" then
        -- FourCC like 'hfoo' → integer value
        return tostring(fourcc_to_int(value))

    else
        add_error(ctx, "Unknown literal type: " .. lit_type, node)
        return "nil"
    end
end
-- }}}

-- {{{ transpile_binary
-- Transpile a binary expression to Lua.
-- @param ctx Transpiler context
-- @param node BINARY_EXPR AST node
-- @return Lua expression string
transpile_binary = function(ctx, node)
    local left = transpile_expr(ctx, node.left)
    local right = transpile_expr(ctx, node.right)
    local op = node.operator

    -- Map operator
    local lua_op = operator_map[op]
    if not lua_op then
        add_error(ctx, "Unknown operator: " .. tostring(op), node)
        lua_op = op  -- Use as-is
    end

    -- Handle string concatenation special case
    if op == "+" and is_string_context(ctx, node) then
        lua_op = ".."
    end

    return string.format("(%s %s %s)", left, lua_op, right)
end
-- }}}

-- {{{ transpile_unary
-- Transpile a unary expression to Lua.
-- @param ctx Transpiler context
-- @param node UNARY_EXPR AST node
-- @return Lua expression string
transpile_unary = function(ctx, node)
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

-- {{{ transpile_call_expr
-- Transpile a function call expression to Lua.
-- Native functions are prefixed with "runtime." for runtime dispatch.
-- @param ctx Transpiler context
-- @param node CALL_EXPR AST node
-- @return Lua expression string
transpile_call_expr = function(ctx, node)
    -- Get function name from callee (which is an IDENTIFIER node)
    local func_name
    if node.callee and node.callee.type == "IDENTIFIER" then
        func_name = node.callee.name
    else
        func_name = "unknown"
    end

    -- Transpile each argument
    local args = {}
    for _, arg in ipairs(node.arguments or {}) do
        args[#args + 1] = transpile_expr(ctx, arg)
    end

    local args_str = table.concat(args, ", ")

    -- Check if native function (prefix with runtime.)
    if is_native(ctx, func_name) then
        return string.format("runtime.%s(%s)", func_name, args_str)
    else
        return string.format("%s(%s)", func_name, args_str)
    end
end
-- }}}

-- {{{ transpile_array_access
-- Transpile an array access expression to Lua.
-- @param ctx Transpiler context
-- @param node ARRAY_ACCESS AST node
-- @return Lua expression string
transpile_array_access = function(ctx, node)
    -- Array is an expression (usually IDENTIFIER)
    local array
    if node.array and node.array.type == "IDENTIFIER" then
        array = node.array.name
    else
        array = transpile_expr(ctx, node.array)
    end

    local index = transpile_expr(ctx, node.index)

    return string.format("%s[%s]", array, index)
end
-- }}}

-- {{{ transpile_expr
-- Main expression transpilation dispatcher.
-- @param ctx Transpiler context
-- @param node Expression AST node
-- @return Lua expression string
transpile_expr = function(ctx, node)
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
        -- Function reference: just the function name (first-class function)
        return node.name

    else
        add_error(ctx, "Unknown expression type: " .. tostring(node.type), node)
        return "nil"
    end
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
-- @param options Optional configuration table:
--   - native_registry: Pre-loaded native function registry
--   - use_runtime_prefix: Whether to prefix native calls with runtime. (default: true)
-- @return lua_code string, errors array
local function transpile(ast, options)
    local ctx = create_context(options)

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

-- Declaration transpilation (306b)
transpiler._default_value = default_value
transpiler._transpile_declaration = transpile_declaration
transpiler._transpile_globals = transpile_globals
transpiler._transpile_function = transpile_function
transpiler._transpile_local_decl = transpile_local_decl

-- Expression transpilation (306d)
transpiler._operator_map = operator_map
transpiler._escape_string = escape_string
transpiler._fourcc_to_int = fourcc_to_int
transpiler._is_string_context = is_string_context
transpiler._transpile_expr = transpile_expr
transpiler._transpile_literal = transpile_literal
transpiler._transpile_binary = transpile_binary
transpiler._transpile_unary = transpile_unary
transpiler._transpile_call_expr = transpile_call_expr
transpiler._transpile_array_access = transpile_array_access

-- Statement transpilation (306c)
transpiler._transpile_statement = transpile_statement
transpiler._transpile_set = transpile_set
transpiler._transpile_call = transpile_call
transpiler._transpile_if = transpile_if
transpiler._transpile_loop = transpile_loop
transpiler._transpile_exitwhen = transpile_exitwhen
transpiler._transpile_return = transpile_return

-- Native function handling (306e)
transpiler.load_natives = load_common_j_natives        -- Public API: parse common.j source
transpiler._BUILTIN_NATIVES = BUILTIN_NATIVES          -- List of built-in native names
transpiler._builtin_natives_set = builtin_natives_set  -- Lookup set for O(1) checks
transpiler._init_builtin_natives = init_builtin_natives
transpiler._load_natives_from_ast = load_natives_from_ast
transpiler._merge_native_registries = merge_native_registries

return transpiler
-- }}}
