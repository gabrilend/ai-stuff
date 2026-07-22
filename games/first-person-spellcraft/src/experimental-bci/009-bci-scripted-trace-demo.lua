-- 009-bci-scripted-trace-demo.lua
--
-- Story index 009. Experimental BCI branch (issue 207, Phase 2 STRETCH).
-- DOCUMENTED, NOT SCHEDULED — nothing depends on this. It proves, in software and
-- with a scripted attention trace (no brain, no EEG, no servos), that the imagined
-- pipe holds together: attention -> aim -> ceiling-cable tensions. This is exactly
-- the issue's "validate with a scripted attention trace before any real hardware."
--
-- Run:  luajit 009-bci-scripted-trace-demo.lua [output_dir]
--   no argument  -> assertions only (exit 0 pass, non-zero fail).
--   output dir   -> also write <dir>/bci-trace-report.txt (the daydream + tensions).

local here = (arg[0]:match("(.*/)")) or "./"
package.path = here .. "?.lua;" .. package.path

local descriptor = require("006-attention-trace-descriptor")
local decoder    = require("007-attention-decoder")
local rig        = require("008-ceiling-headset-tension-model")

local EPS = 1e-9
local passed, failed = 0, 0

-- {{{ local function check(name, ok, detail)
local function check(name, ok, detail)
   if ok then
      passed = passed + 1
      print("  PASS  " .. name)
   else
      failed = failed + 1
      print("  FAIL  " .. name .. (detail and ("  -- " .. detail) or ""))
   end
end
-- }}}

print("bci attention -> aim -> ceiling-tension assertions (issue 207, software-only)")

local desc = descriptor.default_descriptor()
local dt = 0.1

-- 1) Attention up-and-to-the-left drifts the gaze up and left, and further over time.
do
   local aim = decoder.neutral_aim()
   for _ = 1, 3 do aim = decoder.advance(desc, aim, "up-left", dt) end
   local half = aim
   for _ = 1, 3 do aim = decoder.advance(desc, aim, "up-left", dt) end
   check("up-left drifts gaze left (yaw < 0)",  aim.yaw < 0, "yaw=" .. aim.yaw)
   check("up-left drifts gaze up (pitch > 0)",  aim.pitch > 0, "pitch=" .. aim.pitch)
   check("held attention drifts further over time", aim.pitch > half.pitch)
end

-- 2) Attention returning to center holds the gaze where it is (a neck holds its turn).
do
   local aim = decoder.advance(desc, decoder.neutral_aim(), "right", dt)
   local held = decoder.advance(desc, aim, "center", dt)
   check("center holds the gaze (no spring-back)",
         math.abs(held.yaw - aim.yaw) < EPS and math.abs(held.pitch - aim.pitch) < EPS)
end

-- 3) The gaze cannot exceed the neck's limit (clamps at max_pitch).
do
   local aim = decoder.neutral_aim()
   for _ = 1, 100 do aim = decoder.advance(desc, aim, "up", dt) end
   check("gaze clamps at the neck's pitch limit",
         math.abs(aim.pitch - desc.max_pitch) < EPS, "pitch=" .. aim.pitch)
end

-- 4) At rest, every cable holds the same base tension ("just right").
do
   local r = rig.tensions(desc, decoder.neutral_aim())
   local b = desc.rig.base_tension
   check("neutral: all four cables at base tension",
         math.abs(r.cables.north - b) < EPS and math.abs(r.cables.south - b) < EPS and
         math.abs(r.cables.east  - b) < EPS and math.abs(r.cables.west  - b) < EPS)
   check("neutral: mean tension equals base", math.abs(r.mean - b) < EPS)
end

-- 5) Leaning up-left tightens the up + left cables, eases their opposites, and — the
--    "just the right tension" invariant — keeps the AVERAGE at the resting base.
do
   local aim = { yaw = -0.6, pitch = 0.45 }   -- a moderate up-left lean, within the band
   local r = rig.tensions(desc, aim)
   local b = desc.rig.base_tension
   check("up-left lean tightens north (up) and west (left)",
         r.cables.north > b and r.cables.west > b)
   check("up-left lean eases south (down) and east (right)",
         r.cables.south < b and r.cables.east < b)
   check("just-the-right-tension: mean stays at base (no clamp)",
         (not r.any_clamped) and math.abs(r.mean - b) < EPS, rig.format(r))
   check("all cables stay inside the comfort band",
         r.cables.north <= desc.rig.max_tension and r.cables.south >= desc.rig.min_tension)
end

-- 6) An unknown attention direction errors, rather than guessing a direction.
do
   local ok = pcall(decoder.advance, desc, decoder.neutral_aim(), "sideways-ish", dt)
   check("unknown attention direction is rejected", not ok)
end

print(string.format("\nresult: %d passed, %d failed", passed, failed))

-- Optional report: the full scripted daydream, aim path + tensions, when asked for
-- and only if the assertions held.
local out_dir = arg[1]
if out_dir and failed == 0 then
   local trace = descriptor.example_trace()
   local path = decoder.run_trace(desc, trace, dt)
   local lines = { "bci scripted-trace daydream (issue 207, software-only)", "",
                   string.format("%6s  %-10s  %7s %7s   %s", "t(s)", "attention", "yaw", "pitch", "ceiling tensions") }
   for _, p in ipairs(path) do
      local r = rig.tensions(desc, { yaw = p.yaw, pitch = p.pitch })
      lines[#lines + 1] = string.format("%6.2f  %-10s  %7.3f %7.3f   %s",
                                        p.t, p.direction, p.yaw, p.pitch, rig.format(r))
   end
   local report_path = out_dir .. "/bci-trace-report.txt"
   local f = io.open(report_path, "w")
   if not f then
      error("bci demo: cannot write report to " .. report_path)
   end
   f:write(table.concat(lines, "\n") .. "\n")
   f:close()
   print("\nwrote daydream report : " .. report_path)
end

if failed > 0 then
   os.exit(1)
end
