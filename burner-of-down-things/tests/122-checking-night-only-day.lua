-- 122-checking-night-only-day.lua
--
-- Checks issue 801d: `day` on a category marked night-only is refused,
-- naming the rule it broke; `day` on any other category succeeds; and a
-- canvas that names only a white ground gets the day palette it follows,
-- so the check sees it.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local the_look = require("070-the-look")

local marked = { clip = true }

kit.raises(function()
    the_look.for_canvas("clip", { palette = "day" }, marked)
end, "only when the asset is not mostly for night", "day on a night-only category is refused, naming the rule")
kit.raises(function()
    the_look.for_canvas("clip", { palette = "day" }, marked)
end, "'clip'", "the refusal names the category")

local chart = the_look.for_canvas("chart", { palette = "day" }, marked)
kit.equal(chart.palette, "day", "day on a category not marked night-only succeeds")

local night_clip = the_look.for_canvas("clip", { ground = "gray" }, marked)
kit.equal(night_clip.palette, "night", "a night-only category on its own palette passes")

kit.raises(function()
    the_look.for_canvas("clip", { ground = "white" }, marked)
end, "night-only", "a white ground alone brings the day palette, and is refused on a night-only category")
kit.equal(the_look.with_overrides({ ground = "white" }).palette, "day", "palette follows an overridden ground")
kit.equal(the_look.with_overrides({ ground = "white", palette = "night" }).palette, "night",
    "a palette named outright is kept")

-- The project's own marks: none until the owner names a category (docs/010, 15).
local count = 0
for _ in pairs(the_look.NIGHT_ONLY) do count = count + 1 end
kit.equal(count, 0, "no category is marked night-only until the owner marks one")
kit.equal(the_look.for_canvas("still", { palette = "day" }).palette, "day",
    "with nothing marked, day is allowed for every category")

kit.finish()
