-- 071-checking-the-look.lua
--
-- Checks issue 801a: the look table's defaults, read against docs/067's own
-- table so the two can never quietly drift apart.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local the_look = require("070-the-look")

-- {{{ local function doc_text
local function doc_text()
    local file = assert(io.open(kit.project.docs .. "/067-datapath-the-studio.md", "rb"))
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

local doc = doc_text()
local defaults = the_look.defaults()

kit.check(doc:find("`black`", 1, true) ~= nil, "docs/067 names black as a ground value")
kit.equal(defaults.ground, "black", "ground's default is black")
kit.equal(defaults.flair, true, "flair defaults on")
kit.equal(defaults.line_weight, 2, "line_weight defaults to 2")
kit.equal(defaults.arrow, "there-here", "arrow defaults to there-here")

kit.equal(the_look.default_palette("black"), "night", "black's ground follows to night")
kit.equal(the_look.default_palette("gray"), "night", "gray's ground follows to night")
kit.equal(the_look.default_palette("white"), "day", "white's ground follows to day")
kit.equal(defaults.palette, "night", "the resolved defaults table follows black to night")

for _, field in ipairs(the_look.FIELDS) do
    kit.check(doc:find(field, 1, true) ~= nil, "docs/067 mentions the field " .. field)
end

kit.finish()
