-- 006-attention-trace-descriptor.lua
--
-- Story index 006. Experimental BCI branch (issue 207, Phase 2 STRETCH).
-- DOCUMENTED, NOT SCHEDULED — nothing in the game depends on this. It is the
-- sacrosanct stretch dream: "reads common brain patterns like 'look up and to the
-- left' ... which moved the headset mounted to the ceiling at just the right
-- tension." Per the issue's own steps, we prove the SOFTWARE core against a
-- scripted attention trace before any real EEG or servo exists.
--
-- WHAT this file is: the data-at-rest description of that software core — the
-- vocabulary of coarse "attention" directions a decoder (007) reads, the tuning
-- knobs for the decoder and the ceiling-rig tension model (008), and a sample
-- scripted trace to drive them. It is data only; it decodes and pulls nothing.

local M = {}

-- {{{ function M.default_descriptor()
-- WHY a single descriptor holds decoder + rig knobs: they are all tuning for one
-- imagined device; keeping the numbers in one data place (with comments) mirrors
-- the cassette branch's descriptor. These are knobs — a real build would move them
-- to config / balance-updates.md.
function M.default_descriptor()
   return {
      -- The coarse-attention vocabulary: a name -> a raw lean vector (x = right+,
      -- y = up+). A dispatch table so the decoder indexes a direction, never
      -- branches on a string. Diagonals are normalised to unit length by the
      -- decoder so "drift speed" is the same whichever way attention wanders.
      directions = {
         ["center"]     = { 0,  0 },
         ["up"]         = { 0,  1 },
         ["down"]       = { 0, -1 },
         ["left"]       = { -1, 0 },
         ["right"]      = { 1,  0 },
         ["up-left"]    = { -1, 1 },   -- the vision's literal example
         ["up-right"]   = { 1,  1 },
         ["down-left"]  = { -1, -1 },
         ["down-right"] = { 1,  -1 },
      },

      -- Decoder tuning: how fast held attention drifts the aim, and how far the
      -- neck can turn. Aim is integrated from attention (attention = a velocity of
      -- gaze), then clamped — you cannot look past these limits.
      drift_rate  = 1.5,   -- radians of aim per second at full attention
      max_yaw     = 1.2,   -- ~69 deg left/right of neutral
      max_pitch   = 0.9,   -- ~52 deg up/down of neutral

      -- Ceiling-rig tuning: a headset hung from 4 ceiling cables (N/S/E/W around
      -- the player). base is the resting "just right" tension every cable holds at
      -- neutral; gain is how hard a full lean pulls; [min,max] is the comfort band
      -- no cable may leave. Cables named by the lean direction that tightens them.
      rig = {
         base_tension = 50,
         gain         = 30,
         min_tension  = 10,
         max_tension  = 90,
         cables = {
            north = { 0,  1 },   -- tightens when you lean/look UP
            south = { 0, -1 },   -- tightens when you look DOWN
            east  = { 1,  0 },   -- tightens when you look RIGHT
            west  = { -1, 0 },   -- tightens when you look LEFT
         },
      },
   }
end
-- }}}

-- {{{ function M.example_trace()
-- A scripted attention trace: a list of {direction, seconds} the demo (009) plays
-- to prove the pipe without a brain in the loop. Reads like a little daydream.
function M.example_trace()
   return {
      { "center",   0.5 },
      { "up-left",  1.0 },   -- the vision's phrase, held for a beat
      { "up-left",  0.5 },
      { "right",    0.8 },
      { "down",     0.6 },
      { "center",   0.5 },
   }
end
-- }}}

-- {{{ function M.validate(desc)
-- Prove a descriptor well-formed; error LOUDLY on the first problem (no fallback),
-- because a malformed rig would silently produce nonsense tensions.
function M.validate(desc)
   if type(desc.directions) ~= "table" or desc.directions["center"] == nil then
      error("attention descriptor: 'directions' must include at least 'center'")
   end
   if desc.drift_rate <= 0 then
      error("attention descriptor: 'drift_rate' must be positive")
   end
   if desc.max_yaw <= 0 or desc.max_pitch <= 0 then
      error("attention descriptor: 'max_yaw' and 'max_pitch' must be positive")
   end
   local r = desc.rig
   if not r then error("attention descriptor: missing 'rig'") end
   if not (r.min_tension < r.base_tension and r.base_tension < r.max_tension) then
      error("attention descriptor: rig tensions must satisfy min < base < max")
   end
   if r.gain <= 0 then
      error("attention descriptor: rig 'gain' must be positive")
   end
   -- A rig needs opposing cables or a lean has nothing to pull against.
   local needed = { "north", "south", "east", "west" }
   for _, name in ipairs(needed) do
      if not r.cables[name] then
         error("attention descriptor: rig is missing the '" .. name .. "' cable")
      end
   end
   return desc
end
-- }}}

-- {{{ function M.lean_vector(desc, direction_name)
-- Resolve a named attention direction into a UNIT lean vector (or the zero vector
-- for center). Errors on an unknown name rather than guessing a direction.
function M.lean_vector(desc, direction_name)
   local raw = desc.directions[direction_name]
   if not raw then
      error("attention descriptor: unknown direction '" .. tostring(direction_name) .. "'")
   end
   local x, y = raw[1], raw[2]
   local len = math.sqrt(x * x + y * y)
   if len == 0 then
      return 0, 0   -- center: no lean, and no divide-by-zero
   end
   return x / len, y / len
end
-- }}}

return M
