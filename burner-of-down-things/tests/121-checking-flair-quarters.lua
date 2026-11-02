-- 121-checking-flair-quarters.lua
--
-- Checks issue 801c: from a base colour, the flair's four quarters --
-- quarter one lighter than the base, quarter four darker, two and three
-- each split half lighter, half darker; how far is the look's own
-- flair_shift; the same base always gives the same four.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local the_look = require("070-the-look")

-- {{{ local function brightness
local function brightness(c)
    return c[1] + c[2] + c[3]
end
-- }}}

-- {{{ local function text
local function text(c)
    return table.concat({ c[1], c[2], c[3], tostring(c[4]) }, ",")
end
-- }}}

-- The colour-shift primitive.
kit.equal(text(the_look.shift({ 100, 100, 100 }, 0.5)), "178,178,178,nil", "lightening goes that far toward white")
kit.equal(text(the_look.shift({ 100, 100, 100 }, -0.5)), "50,50,50,nil", "darkening goes that far toward black")
kit.equal(text(the_look.shift({ 10, 20, 30, 200 }, 0)), "10,20,30,200", "no shift keeps the colour, alpha and all")
kit.equal(text(the_look.shift({ 255, 0, 128 }, 1)), "255,255,255,nil", "a full shift up is white")
kit.raises(function() the_look.shift({ 300, 0, 0 }, 0.1) end, "0 to 255", "a channel out of range is refused")
kit.raises(function() the_look.shift({ 1, 2, 3 }, 2) end, "from -1 to 1", "a shift past white or black is refused")

local base = { 40, 120, 200, 255 }
local look = the_look.defaults()
kit.equal(look.flair_shift, 0.15, "the flair's shift is the look's own setting")
local q = the_look.flair_quarters(base, look)

kit.equal(#q, 4, "four quarters")
kit.check(brightness(q[1][1]) > brightness(base) and brightness(q[1][2]) > brightness(base),
    "quarter one is lighter than the base, all the way along")
kit.check(brightness(q[4][1]) < brightness(base) and brightness(q[4][2]) < brightness(base),
    "quarter four is darker than the base, all the way along")
for i = 2, 3 do
    kit.check(brightness(q[i][1]) > brightness(base), "quarter " .. i .. "'s first half is lighter")
    kit.check(brightness(q[i][2]) < brightness(base), "quarter " .. i .. "'s second half is darker")
end
kit.equal(text(q[1][1]), text(the_look.shift(base, 0.15)), "lighter is the base shifted by flair_shift toward white")
kit.equal(text(q[4][1]), text(the_look.shift(base, -0.15)), "darker is the base shifted by flair_shift toward black")
kit.equal(q[1][1][4], 255, "the quarters keep the base's alpha")

local again = the_look.flair_quarters({ 40, 120, 200, 255 }, the_look.defaults())
local same = true
for i = 1, 4 do
    for h = 1, 2 do
        if text(again[i][h]) ~= text(q[i][h]) then same = false end
    end
end
kit.check(same, "the same base colour always gives the same four quarters")

local wider = the_look.flair_quarters(base, the_look.with_overrides({ flair_shift = 0.4 }))
kit.check(brightness(wider[1][1]) > brightness(q[1][1]), "a canvas's own larger flair_shift moves the quarters further")

local off = the_look.flair_quarters(base, the_look.with_overrides({ flair = false }))
kit.equal(text(off[1][1]) .. "|" .. text(off[4][2]), text(base) .. "|" .. text(base),
    "with the flair off, every quarter is the base colour")

kit.finish()
