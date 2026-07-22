-- 007-attention-decoder.lua
--
-- Story index 007. Experimental BCI branch (issue 207, Phase 2 STRETCH).
-- DOCUMENTED, NOT SCHEDULED. WHAT it does: DATA GENERATION for the imagined brain
-- source — turns a coarse "attention" direction, held over time, into an aim
-- orientation (yaw, pitch). This is the vision made literal: "the player moving
-- their attention upward and leftward" drifts the gaze upward and leftward.
--
-- The model: attention is a VELOCITY of gaze. Held attention drifts the aim in
-- that direction at drift_rate; let attention return to center and the aim simply
-- stops where it is (it does not spring back — a real neck holds its turn). The
-- aim is clamped to the neck's limits. Pure: same trace + same dt -> same path.
--
-- Kept separate from the tension model (008): decoding "where does the gaze want
-- to go" is a different concern from "what cable tensions hold the head there."

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
   if v < lo then return lo end   -- past the neck's limit one way
   if v > hi then return hi end   -- past it the other way
   return v
end
-- }}}

-- {{{ function M.neutral_aim()
-- The rest pose: looking straight ahead.
function M.neutral_aim()
   return { yaw = 0, pitch = 0 }
end
-- }}}

-- {{{ function M.advance(desc, aim, direction_name, dt)
-- Integrate one step of held attention into the aim. Returns a NEW aim table so
-- the caller's previous state is never mutated (easy to keep a path history).
function M.advance(desc, aim, direction_name, dt)
   local descM = descriptor_module()
   local lx, ly = descM.lean_vector(desc, direction_name)   -- unit lean, x=right y=up
   local yaw   = clamp(aim.yaw   + lx * desc.drift_rate * dt, -desc.max_yaw,   desc.max_yaw)
   local pitch = clamp(aim.pitch + ly * desc.drift_rate * dt, -desc.max_pitch, desc.max_pitch)
   return { yaw = yaw, pitch = pitch }
end
-- }}}

-- {{{ function M.run_trace(desc, trace, dt)
-- Play a scripted trace (a list of {direction, seconds}) from neutral, sampling
-- each segment in dt steps. Returns the aim PATH: an array of
-- {t, direction, yaw, pitch}. The last entry is the final aim. This is what the
-- demo (009) charts and what the tension model (008) is fed frame by frame.
function M.run_trace(desc, trace, dt)
   descriptor_module().validate(desc)
   if dt <= 0 then
      error("attention decoder: dt must be positive")
   end
   local path = {}
   local aim = M.neutral_aim()
   local t = 0
   for _, segment in ipairs(trace) do
      local direction, seconds = segment[1], segment[2]
      -- How many whole dt steps this segment lasts. A short segment still gets at
      -- least one step so no instruction is silently skipped.
      local steps = math.max(1, math.floor(seconds / dt + 0.5))
      for _ = 1, steps do
         aim = M.advance(desc, aim, direction, dt)
         t = t + dt
         path[#path + 1] = { t = t, direction = direction, yaw = aim.yaw, pitch = aim.pitch }
      end
   end
   return path
end
-- }}}

return M
