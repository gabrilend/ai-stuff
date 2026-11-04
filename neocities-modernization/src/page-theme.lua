-- page-theme.lua: the site's colours, from one place.
--
-- Every page opens its body with the same four colours -- background, text,
-- link, visited link -- and they come from config.lua html_theme and nowhere
-- else (owner, 2026-10-25: "one place for the colours", so a new kind of
-- page cannot drift off pure black). Read once per Lua state, so each page
-- worker reads it once too.

local M = {}

local theme = nil

-- {{{ function M.colours()
-- returns { background, text, link, vlink } (hex strings); a missing one is
-- an error naming it.
function M.colours()
    if theme then return theme end
    local t = require("config-loader").load().html_theme
        or error("config.lua has no html_theme section")
    local out = {}
    for _, name in ipairs({ "background", "text", "link", "vlink" }) do
        out[name] = t[name] or error("config.lua html_theme." .. name .. " is missing")
    end
    theme = out
    return theme
end
-- }}}

-- {{{ function M.body_tag()
-- The opening <body> tag every page uses.
function M.body_tag()
    local c = M.colours()
    return string.format('<body bgcolor="%s" text="%s" link="%s" vlink="%s">',
        c.background, c.text, c.link, c.vlink)
end
-- }}}

return M
