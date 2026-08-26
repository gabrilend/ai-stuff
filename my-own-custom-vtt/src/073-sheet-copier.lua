--[[
073-sheet-copier.lua -- copying a ruleset's sheets without reading them.

Loaded into the sandbox's registry at startup by 073-rules.c, where a ruleset
cannot reach it. It shares an index with that file because it is the same step of
the story rather than a later one.

WHY THIS IS LUA AND NOT C. A rollback restores the world by copying flat bytes. A
sheet is a Lua table, so it needs a different kind of copy -- and issue 703 says
the server must never read a sheet, because a server that knew what a hit point
was would not be system-agnostic.

Doing the copy here keeps that literally true. C says "copy" and "put it back"
and never looks inside one.

WHY IT REFUSES RATHER THAN COPING. The generic-serialisation option was rejected
in issue 703 for "breaking quietly on a closure". That is a property of one
implementation of it, not of the idea: a copier can know perfectly well what it
cannot copy, and the whole difference between a good answer and a bad one is
whether it says so, and where.

A turn whose sheets could not be copied is not rollbackable. Not
half-rollbackable -- restoring geometry and not hit points is a rollback that
looks like it worked, which is the thing this entire path exists to avoid.
]]

local guard = {}

--[[
Refuses an uncopyable value at the moment it is stored, naming the field.

The ruleset author learns at the line that did it rather than at the next
rollback, which may be an hour later and will look like something else entirely.

A ruleset can still call setmetatable and take this off, so the copier below
validates as well. THE GUARD IS FOR THE MESSAGE; THE COPIER IS THE AUTHORITY.
]]
guard.__newindex = function(t, k, v)
    local kind = type(v)

    if kind == 'function' or kind == 'userdata' or kind == 'thread' then
        error("a sheet holds data, not a " .. kind .. " -- you stored one at '"
              .. tostring(k) .. "', and a turn holding it could not be rolled"
              .. " back", 2)
    end

    -- A table put into a sheet becomes part of the sheet, so it is guarded too.
    if kind == 'table' then
        setmetatable(v, guard)
    end

    rawset(t, k, v)
end

-- {{{ local function copy
local function copy(value, path, seen)
    local kind = type(value)

    if kind == 'number' or kind == 'string' or kind == 'boolean' then
        return value
    end

    if kind ~= 'table' then
        return nil, path .. ' holds a ' .. kind .. ', which cannot be copied'
    end

    --[[
    A sheet that points at itself would copy forever. Refused rather than
    flattened, because flattening a cycle silently turns what the ruleset stored
    into a different shape that looks similar -- and the ruleset would go on
    using it as though nothing had happened.
    ]]
    if seen[value] then
        return nil, path .. ' points back at itself, and a copy of that is a'
                         .. ' different shape'
    end

    seen[value] = true

    local out = {}

    for k, v in pairs(value) do
        local key_kind = type(k)

        if key_kind ~= 'number' and key_kind ~= 'string' then
            return nil, path .. ' is keyed by a ' .. key_kind
        end

        local copied, why = copy(v, path .. '.' .. tostring(k), seen)

        if why then
            return nil, why
        end

        out[k] = copied
    end

    seen[value] = nil

    -- The copy is guarded too, so that restoring a snapshot restores the guard
    -- with it. Otherwise the second turn after a rollback could store anything.
    setmetatable(out, guard)

    return out
end
-- }}}

return guard, copy
