-- 099-checking-canvas-overrides.lua
--
-- Checks issue 801b: a canvas may override any of the look's own fields by
-- name, but an unknown name is refused, naming the legal fields.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local the_look = require("070-the-look")

local overridden = the_look.with_overrides({ ground = "gray" })
kit.equal(overridden.ground, "gray", "an override of ground is visible in the merged look")
kit.equal(overridden.flair, the_look.DEFAULTS.flair, "an unoverridden field keeps its default")
kit.equal(overridden.line_weight, the_look.DEFAULTS.line_weight, "another unoverridden field also keeps its default")

kit.raises(function()
    the_look.with_overrides({ shimmer = "gold" })
end, "shimmer", "an invented field name is refused, naming the offender")

kit.raises(function()
    the_look.with_overrides({ shimmer = "gold" })
end, "ground", "the refusal also names a legal field")

kit.finish()
