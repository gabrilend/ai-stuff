-- 070-the-look.lua
--
-- The owner's style in one table every paintbrush reads (docs/067, issue
-- 801a). `palette` has no default of its own: it follows `ground`, so it is
-- resolved rather than stored, the same way this file only holds what the
-- document says and nothing a later piece (801b's overrides, 801c's colour
-- math, 801d's night-only refusal) will still decide.

local the_look = {}

-- Every setting but `palette`, matching docs/067's table field for field.
-- Adding a setting means adding a row here AND in that document, in the same
-- pass — 801a's own test reads the two against each other.
the_look.DEFAULTS = {
    ground = "black",
    flair = true,
    line_weight = 2,
    arrow = "there-here",
}

-- The closed list of names a canvas may name at all (801b checks overrides
-- against this; 801a only needs it to say what "unknown" means).
the_look.FIELDS = { "ground", "palette", "flair", "line_weight", "arrow" }

-- {{{ function the_look.default_palette
-- palette "follows ground": night (bright on dark) unless ground is white,
-- when it follows as day (vibrant on white).
function the_look.default_palette(ground)
    if ground == "white" then
        return "day"
    end
    return "night"
end
-- }}}

-- {{{ function the_look.defaults
-- A fresh table (never the shared one, so a caller's later changes cannot
-- leak back into it) holding every field, palette resolved from ground.
function the_look.defaults()
    local look = {}
    for k, v in pairs(the_look.DEFAULTS) do
        look[k] = v
    end
    look.palette = the_look.default_palette(look.ground)
    return look
end
-- }}}

-- {{{ function the_look.with_overrides
-- A canvas's own look (801b): defaults() with the given overrides laid on
-- top, by name. Every name is checked against FIELDS before any of them are
-- merged, so a refusal never leaves a half-applied look sitting around; the
-- refusal names the fields a canvas is allowed to give.
function the_look.with_overrides(overrides)
    for name in pairs(overrides) do
        local known = false
        for _, field in ipairs(the_look.FIELDS) do
            if field == name then
                known = true
                break
            end
        end
        if not known then
            error("the_look.with_overrides: unknown field '" .. tostring(name)
                .. "' (fields are " .. table.concat(the_look.FIELDS, ", ") .. ")")
        end
    end
    local look = the_look.defaults()
    for name, value in pairs(overrides) do
        look[name] = value
    end
    return look
end
-- }}}

return the_look
