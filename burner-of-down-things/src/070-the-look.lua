-- 070-the-look.lua
--
-- The owner's style in one table every paintbrush reads (docs/067, issue
-- 801a). `palette` has no default of its own: it follows `ground`, so it is
-- resolved rather than stored. A canvas may override any field by name
-- (801b); the flair's four quarter colours come from one function here, so
-- every end draws it the same way (801c); and `day` is refused for a
-- category marked night-only (801d).

local the_look = {}

-- Every setting but `palette`, matching docs/067's table field for field.
-- Adding a setting means adding a row here AND in that document, in the same
-- pass — 801a's own test reads the two against each other.
the_look.DEFAULTS = {
    ground = "black",
    flair = true,
    line_weight = 2,
    arrow = "there-here",
    -- How far the flair's lighter and darker quarters move from the
    -- midline's colour: a fraction of the way to white, or to black (801c).
    -- A balance number: a change goes to docs/balance-updates.md.
    flair_shift = 0.15,
}

-- The closed list of names a canvas may name at all (801b checks overrides
-- against this; 801a only needs it to say what "unknown" means).
the_look.FIELDS = { "ground", "palette", "flair", "line_weight", "arrow", "flair_shift" }

-- The categories marked night-only (801d): for these, `palette = "day"` is
-- refused. Which categories are mostly for night is the owner's own call
-- (docs/010, question 15), so none is marked yet; marking one is a line
-- here, `[category] = true`. `check_palette` takes another table for tests.
the_look.NIGHT_ONLY = {}

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
    -- palette follows ground: a canvas that names only its ground gets that
    -- ground's palette, not the default ground's (white ground, day palette).
    if overrides.palette == nil then
        look.palette = the_look.default_palette(look.ground)
    end
    return look
end
-- }}}

-- {{{ local function clamp_byte
local function clamp_byte(x)
    x = math.floor(x + 0.5)
    if x < 0 then return 0 end
    if x > 255 then return 255 end
    return x
end
-- }}}

-- {{{ function the_look.shift
-- A colour {r, g, b[, a]} (0-255, raylib's own range) moved `amount` of the
-- way toward white (amount > 0) or toward black (amount < 0), amount
-- between -1 and 1. Alpha is kept. Always a new table, rounded to whole
-- numbers, so the same colour and amount always give the same bytes.
function the_look.shift(colour, amount)
    if type(amount) ~= "number" or amount < -1 or amount > 1 then
        error("the_look.shift: amount must be a number from -1 to 1, got " .. tostring(amount))
    end
    local out = {}
    for i = 1, 3 do
        local c = colour[i]
        if type(c) ~= "number" or c < 0 or c > 255 then
            error("the_look.shift: a colour is {r, g, b} from 0 to 255, got channel " .. i .. " = " .. tostring(c))
        end
        if amount >= 0 then
            out[i] = clamp_byte(c + (255 - c) * amount)
        else
            out[i] = clamp_byte(c * (1 + amount))
        end
    end
    out[4] = colour[4]
    return out
end
-- }}}

-- {{{ function the_look.flair_quarters
-- The four quarters of a midline drawn in `base` (801c), as docs/067 says:
-- quarter one a little lighter, quarter four a little darker, quarters two
-- and three each half lighter, half darker. Each quarter is a pair of
-- halves, { first, second }, in drawing order along the line: quarter one
-- is { lighter, lighter }, two and three are { lighter, darker }, four is
-- { darker, darker } -- light falling across the middle of the shape. How
-- far lighter and darker is `look.flair_shift`; with `look.flair` off,
-- every half is the base colour.
function the_look.flair_quarters(base, look)
    look = look or the_look.defaults()
    if not look.flair then
        local plain = the_look.shift(base, 0)
        return { { plain, plain }, { plain, plain }, { plain, plain }, { plain, plain } }
    end
    local lighter = the_look.shift(base, look.flair_shift)
    local darker = the_look.shift(base, -look.flair_shift)
    return {
        { lighter, lighter },
        { lighter, darker },
        { lighter, darker },
        { darker, darker },
    }
end
-- }}}

-- {{{ function the_look.check_palette
-- Refuses `palette = "day"` for a category marked night-only (801d),
-- naming the rule it broke; any other look passes and is returned. Run
-- before a canvas compiles. `night_only` defaults to NIGHT_ONLY.
function the_look.check_palette(category, look, night_only)
    night_only = night_only or the_look.NIGHT_ONLY
    if look.palette == "day" and night_only[category] then
        error("the_look: palette 'day' is refused for category '" .. tostring(category)
            .. "', which is marked night-only -- docs/067: day (vibrant on white) only when"
            .. " the asset is not mostly for night")
    end
    return look
end
-- }}}

-- {{{ function the_look.for_canvas
-- A canvas's whole look: its overrides laid on the defaults (801b), then
-- checked against its category's night-only mark (801d).
function the_look.for_canvas(category, overrides, night_only)
    return the_look.check_palette(category, the_look.with_overrides(overrides or {}), night_only)
end
-- }}}

return the_look
