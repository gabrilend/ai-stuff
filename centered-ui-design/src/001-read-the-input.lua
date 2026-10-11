-- 001-read-the-input.lua - the first thing the program does: read input/.
--
-- In plain terms: before a window opens or a thread starts, the program reads
-- its settings file from the project's input folder and checks every field it
-- needs is there and is the right kind of thing. A missing or wrong field
-- stops the program with a message naming the field; nothing is guessed.
--
-- The settings file is plain Lua returning one table, so it can carry
-- comments explaining each number to whoever edits it.

local M = {}

-- The fields every settings file must have, and what kind each must be.
-- "whole" means a number with no fractional part; "number" any number.
-- Kept as data so adding a setting is one line here plus one in the file.
M.REQUIRED_FIELDS = {
    { name = "seed",                       kind = "whole" },
    { name = "window_width",               kind = "whole" },
    { name = "window_height",              kind = "whole" },
    { name = "max_framerate",              kind = "whole" },
    { name = "unit_count",                 kind = "whole" },
    { name = "worker_count",               kind = "whole" },
    { name = "cuboid_count",               kind = "whole" },
    { name = "camera_distance",            kind = "number" },
    { name = "view_half_height",           kind = "number" },
    { name = "camera_elevation_degrees",   kind = "number" },
    { name = "depth_half_range",           kind = "number" },
    { name = "view_plane_distance",        kind = "number" },
    { name = "tiers_shown",                kind = "number" },
    { name = "fold_strength",              kind = "number" },
    { name = "hub_radius",                 kind = "number" },
    { name = "edge_radius",                kind = "number" },
    { name = "team_size",                  kind = "whole" },
    { name = "seat",                       kind = "whole" },
    { name = "calendar_seconds_per_day",   kind = "number" },
    { name = "arch_height_share",          kind = "number" },
    { name = "view_depth",                 kind = "word", words = { "flat", "hub", "slant", "arch" } },
    { name = "view_standing",              kind = "word", words = { "upright", "outward" } },
    { name = "view_blur",                  kind = "word", words = { "on", "off" } },
    { name = "hub_eye_height",             kind = "number" },
    { name = "hub_look_down_degrees",      kind = "number" },
    { name = "hub_field_of_view_degrees",  kind = "number" },
    { name = "slant_reach",                kind = "number" },
    { name = "far_pole_tier",              kind = "number" },
    { name = "arch_reach",                 kind = "number" },
}

-- {{{ local function is_one_of()
local function is_one_of(value, words)
    for _, word in ipairs(words) do
        if value == word then
            return true
        end
    end
    return false
end
-- }}}

-- How each kind is checked: a dispatch table from kind name to a test.
-- "word" is a string from the field's own list of allowed words.
local KIND_TESTS = {
    number = function(value) return type(value) == "number" end,
    whole  = function(value) return type(value) == "number" and value == math.floor(value) end,
    word   = function(value, field) return type(value) == "string" and is_one_of(value, field.words) end,
}

-- {{{ local function check_settings()
-- Checks a settings table against the required fields and the ranges that
-- would make the program draw nonsense. Returns nothing; raises an error
-- naming the first problem found.
local function check_settings(settings, source_name)
    for _, field in ipairs(M.REQUIRED_FIELDS) do
        local value = settings[field.name]
        -- missing field: stop, naming it
        if value == nil then
            error(source_name .. ": the setting '" .. field.name .. "' is missing", 0)
        end
        -- present but the wrong kind: stop, naming what was expected
        if not KIND_TESTS[field.kind](value, field) then
            -- a word: say which words are allowed
            if field.kind == "word" then
                error(source_name .. ": the setting '" .. field.name .. "' must be one of "
                    .. table.concat(field.words, ", ") .. ", but is " .. tostring(value), 0)
            end
            error(source_name .. ": the setting '" .. field.name .. "' must be a "
                .. field.kind .. " number, but is " .. tostring(value), 0)
        end
    end

    -- Ranges. The framerate cap is a whole number 0..240 (0 = no cap).
    if settings.max_framerate < 0 or settings.max_framerate > 240 then
        error(source_name .. ": max_framerate must be 0 to 240, but is "
            .. settings.max_framerate, 0)
    end
    -- A team is 1 to 4 allies, and the seat must be one of theirs.
    if settings.team_size < 1 or settings.team_size > 4
        or settings.seat < 1 or settings.seat > settings.team_size then
        error(source_name .. ": team_size must be 1 to 4 and seat 1 to team_size", 0)
    end
    -- At least one unit and one worker, or there is nothing to show or no one
    -- to take the work.
    if settings.unit_count < 1 or settings.worker_count < 1 then
        error(source_name .. ": unit_count and worker_count must each be at least 1", 0)
    end
    -- The dashboard's view plane must hang inside the drawn depth band, or it
    -- would be clipped away; and in front of the camera.
    if settings.view_plane_distance >= settings.depth_half_range
        or settings.view_plane_distance >= settings.camera_distance then
        error(source_name .. ": view_plane_distance must be less than depth_half_range"
            .. " and less than camera_distance", 0)
    end
    -- The hub must sit inside the map's edge.
    if settings.hub_radius >= settings.edge_radius then
        error(source_name .. ": hub_radius must be less than edge_radius", 0)
    end
    -- The slant view must reach somewhere: a reach of nothing would zoom
    -- without end.
    if settings.slant_reach <= 0 then
        error(source_name .. ": slant_reach must be more than 0", 0)
    end
    -- The arch view's reach must lie beyond the hub, which sits on the arch
    -- itself: otherwise the rings would grow inward.
    if settings.arch_reach <= settings.hub_radius then
        error(source_name .. ": arch_reach must be more than hub_radius", 0)
    end
    -- The foes' pole must lie past the tiers shown: at or inside them, the
    -- laps near it would shrink to nothing on the map and walkers there
    -- would spin without end.
    if settings.far_pole_tier <= settings.tiers_shown then
        error(source_name .. ": far_pole_tier must be more than tiers_shown", 0)
    end
    -- A negative fold would bunch the inner tiers instead of the outer ones.
    if settings.fold_strength < 0 then
        error(source_name .. ": fold_strength must not be negative", 0)
    end
end
-- }}}
M.check_settings = check_settings

-- {{{ function M.read()
-- Reads <project>/input/game-settings.lua and returns the checked table.
function M.read(project_dir)
    local path = project_dir .. "/input/game-settings.lua"
    local chunk, load_error = loadfile(path)
    -- the file is absent or not valid Lua: stop with the loader's own words
    if chunk == nil then
        error("could not read the settings file: " .. tostring(load_error), 0)
    end
    -- run it with no access to anything, so a settings file can only be data
    setfenv(chunk, {})
    local settings = chunk()
    -- the file ran but did not hand back a table
    if type(settings) ~= "table" then
        error(path .. ": the settings file must return a table", 0)
    end
    check_settings(settings, path)
    return settings
end
-- }}}

return M
