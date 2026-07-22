-- 008-ceiling-headset-tension-model.lua
--
-- Story index 008. Experimental BCI branch (issue 207, Phase 2 STRETCH).
-- DOCUMENTED, NOT SCHEDULED. This is the poetic, hardware-real heart of the dream:
-- "moved the headset mounted to the ceiling at just the right tension."
--
-- The model: the headset hangs from four ceiling cables (north/south/east/west
-- around the player). To hold the gaze leaning a certain way, the cables in that
-- direction pull harder and the opposite cables ease off. At rest (looking ahead)
-- every cable holds the same resting "just right" base tension. Because opposing
-- cables are symmetric, a moderate lean keeps the AVERAGE tension exactly at base —
-- that average-stays-at-rest property IS "just the right tension," and it is a
-- testable invariant, not a vibe.
--
-- Pure geometry/statics: an aim in, four tensions out. It moves nothing and reads
-- no hardware — a real rig would feed these numbers to servos, which is the
-- deferred hardware sub-project (see FINDINGS).

local desc_mod

local M = {}

-- {{{ local function descriptor_module()
local function descriptor_module()
   if not desc_mod then
      desc_mod = require("006-attention-trace-descriptor")
   end
   return desc_mod
end
-- }}}

-- {{{ local function clamp(v, lo, hi)
local function clamp(v, lo, hi)
   if v < lo then return lo end
   if v > hi then return hi end
   return v
end
-- }}}

-- {{{ function M.lean_from_aim(desc, aim)
-- Reduce an aim orientation to a normalised lean vector in [-1,1]^2: how far
-- off-centre the head is turned, as a fraction of its limits. x=right, y=up.
function M.lean_from_aim(desc, aim)
   local lx = clamp(aim.yaw   / desc.max_yaw,   -1, 1)
   local ly = clamp(aim.pitch / desc.max_pitch, -1, 1)
   return lx, ly
end
-- }}}

-- {{{ function M.tensions(desc, aim)
-- The one door: aim orientation -> the four cable tensions holding the head there.
-- Returns { cables = {north,south,east,west}, mean = <clamped mean>,
--           any_clamped = <true if a cable hit the comfort band edge> }.
function M.tensions(desc, aim)
   descriptor_module().validate(desc)
   local rig = desc.rig
   local lx, ly = M.lean_from_aim(desc, aim)

   local cables = {}
   local sum = 0
   local any_clamped = false
   for name, dir in pairs(rig.cables) do
      -- Tension rises with how much this cable's direction agrees with the lean
      -- (a dot product), around the resting base. A cable pulling toward the lean
      -- tightens; its opposite eases.
      local raw = rig.base_tension + rig.gain * (dir[1] * lx + dir[2] * ly)
      local t = clamp(raw, rig.min_tension, rig.max_tension)
      if t ~= raw then
         any_clamped = true   -- lean so extreme the comfort band capped this cable
      end
      cables[name] = t
      sum = sum + t
   end

   return { cables = cables, mean = sum / 4, any_clamped = any_clamped }
end
-- }}}

-- {{{ function M.format(result)
-- A one-line human view of a tension result, for the demo/report. Viewing only.
function M.format(result)
   local c = result.cables
   return string.format(
      "N %5.1f  S %5.1f  E %5.1f  W %5.1f  (mean %5.1f%s)",
      c.north, c.south, c.east, c.west, result.mean,
      result.any_clamped and ", clamped" or "")
end
-- }}}

return M
