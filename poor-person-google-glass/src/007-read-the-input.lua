-- 007-read-the-input.lua - the first thing the viewer does: read input/.
--
-- In plain terms: the viewer's window size, field of view and colours live
-- in input/viewer-settings.lua, a Lua file that returns one table. This file
-- loads it and checks every field, so a typo stops the program at start with
-- a message naming the field, instead of drawing something subtly wrong.

local M = {}

-- Every setting, its kind, and the range it must fall in. "colour" is a
-- list of three numbers 0..1.
M.REQUIRED_FIELDS = {
    { name = "window_width", kind = "whole", min = 320, max = 7680 },
    { name = "window_height", kind = "whole", min = 240, max = 4320 },
    { name = "field_of_view_degrees", kind = "number", min = 10, max = 120 },
    { name = "turn_degrees_per_second", kind = "number", min = 0, max = 360 },
    { name = "window_resizable", kind = "yes or no" },
    { name = "edge_margin_pixels", kind = "number", min = 4, max = 400 },
    { name = "edge_speed", kind = "number", min = 0, max = 10 },
    { name = "background_colour", kind = "colour" },
    { name = "edge_colour", kind = "colour" },
    { name = "text_colour", kind = "colour" },
}

-- {{{ local KIND_CHECKS
-- One check per kind (a dispatch table); each returns nil when the value is
-- right, or the reason it is wrong.
local KIND_CHECKS = {
    whole = function(value, field)
        if type(value) ~= "number" or value % 1 ~= 0 then return "must be a whole number" end
        if value < field.min or value > field.max then return "must be " .. field.min .. " to " .. field.max end
    end,
    number = function(value, field)
        if type(value) ~= "number" then return "must be a number" end
        if value < field.min or value > field.max then return "must be " .. field.min .. " to " .. field.max end
    end,
    ["yes or no"] = function(value)
        if type(value) ~= "boolean" then return "must be true or false" end
    end,
    colour = function(value)
        if type(value) ~= "table" or #value ~= 3 then return "must be three numbers { r, g, b }" end
        for _, part in ipairs(value) do
            if type(part) ~= "number" or part < 0 or part > 1 then return "each of r, g, b must be 0 to 1" end
        end
    end,
}
-- }}}

-- {{{ function M.check_settings()
-- Raises on the first missing or wrong field, naming it and the file.
function M.check_settings(settings, source_name)
    for _, field in ipairs(M.REQUIRED_FIELDS) do
        local value = settings[field.name]
        if value == nil then error(source_name .. ": missing setting '" .. field.name .. "'", 0) end
        local problem = KIND_CHECKS[field.kind](value, field)
        if problem then error(source_name .. ": '" .. field.name .. "' " .. problem, 0) end
    end
end
-- }}}

-- {{{ function M.read()
-- project_dir (string) -> the checked settings table.
function M.read(project_dir)
    local path = project_dir .. "/input/viewer-settings.lua"
    local chunk, problem = loadfile(path)
    if chunk == nil then error("cannot load " .. path .. ": " .. tostring(problem), 0) end
    local settings = chunk()
    if type(settings) ~= "table" then error(path .. " must return a table", 0) end
    M.check_settings(settings, path)
    return settings
end
-- }}}

return M
