-- 031a-when-the-machine-runs-hot.lua
--
-- Reads the processor's temperature and rests when it is climbing.
--
-- For a general: making six thousand pictures is several minutes of every core
-- on the machine at full load, and sustained full load is what heats a chip.
-- Nothing here is going to damage anything -- a processor throttles itself long
-- before that, and the limits it reports have that margin built in -- but heat
-- is wear, and wear is worth not spending for no reason.
--
-- Three things are done about it and only the last is really about heat.
-- Leaving cores free keeps the machine usable. Asking politely means anything
-- else on the machine goes first. And resting between characters when the
-- temperature climbs is a duty cycle, which genuinely lowers the sustained
-- temperature rather than moving it somewhere else: brief regular idleness is
-- how a chip sheds what it has built up.
--
-- Numbered to sit beside `031` rather than after it, because it is that file's
-- governor and not a step of its own.

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ ffi and nanosleep -- resting without spinning
--
-- A pause implemented by looping until the clock moves would be a busy-wait,
-- which is to say a way of avoiding heat by generating it. This asks the
-- kernel to stop running us, which is the only kind of rest that helps.
--
-- Not `sleep` through a shell, either: that starts a process for every pause,
-- and there is one every few characters across thousands of them.
local ok_ffi, ffi = pcall(require, "ffi")
if ok_ffi then
  pcall(ffi.cdef, [[
    struct kanji_timespec { long tv_sec; long tv_nsec; };
    int nanosleep(const struct kanji_timespec *req, struct kanji_timespec *rem);
  ]])
end
-- }}}

-- {{{ M.rest(seconds)
-- Stop running for a while.
function M.rest(seconds)
  if seconds <= 0 then return end
  if ok_ffi then
    local span = ffi.new("struct kanji_timespec")
    span.tv_sec = math.floor(seconds)
    span.tv_nsec = math.floor((seconds - math.floor(seconds)) * 1e9)
    ffi.C.nanosleep(span, nil)
  else
    os.execute("sleep " .. string.format("%.3f", seconds))
  end
end
-- }}}

local source = nil
local looked = false

-- {{{ M.source()
-- Where this machine says how hot it is, or nil.
--
-- The kernel exposes thermal zones under a known path, and the useful one is
-- not reliably the first -- a laptop may report its battery and its wireless
-- card alongside its processor. The zone is found by what it says it is.
--
-- Looked for once. A machine with no thermal zone is not going to grow one
-- during a run, and checking every few seconds would be its own small waste.
function M.source()
  if looked then return source end
  looked = true

  local wanted = { "x86_pkg_temp", "cpu%-thermal", "acpitz", "coretemp",
                   "soc_thermal", "cpu" }
  local pipe = io.popen("ls -d /sys/class/thermal/thermal_zone* 2>/dev/null")
  local zones = {}
  if pipe then
    for line in pipe:lines() do zones[#zones + 1] = line end
    pipe:close()
  end

  for _, pattern in ipairs(wanted) do
    for _, zone in ipairs(zones) do
      local kind = project.read_file(zone .. "/type")
      if kind and kind:lower():find(pattern) then
        local reading = project.read_file(zone .. "/temp")
        if tonumber(reading) then
          source = zone .. "/temp"
          return source
        end
      end
    end
  end
  return nil
end
-- }}}

-- {{{ M.temperature()
-- How hot the processor is, in degrees, or nil.
--
-- The kernel reports thousandths of a degree.
function M.temperature()
  local where = M.source()
  if not where then return nil end
  local reading = tonumber(project.read_file(where))
  if not reading then return nil end
  return reading / 1000
end
-- }}}

-- {{{ M.workers(settings)
-- How many workers to run, and why that many.
--
-- Processors minus a reserve, under a ceiling, never below one. Taking every
-- core is what makes a machine unresponsive while a batch runs, and the last
-- two cores buy far more comfort than they buy speed.
function M.workers(settings)
  local pipe = io.popen("nproc 2>/dev/null")
  local said = pipe and pipe:read("*l") or nil
  if pipe then pipe:close() end
  local processors = tonumber(said)
  if not processors or processors < 1 then
    io.stderr:write("notice: this machine would not say how many processors " ..
                    "it has; using one.\n")
    processors = 1
  end

  local batch = settings.batch
  -- A share rather than a subtraction. Leaving two cores free is a big
  -- concession on a four-core machine and almost none on a thirty-two-core
  -- one, and it is the *proportion* of the machine held at full load that
  -- decides how hot it gets.
  local howmany = math.floor(processors * (batch.share or 1))
  local spare = processors - (batch.reserve or 0)
  if howmany > spare then howmany = spare end
  if batch.max_workers and howmany > batch.max_workers then
    howmany = batch.max_workers
  end
  if howmany < 1 then howmany = 1 end
  return howmany, processors
end
-- }}}

-- {{{ M.governor(settings)
-- Something to call between units of work that rests when the machine is hot.
--
-- Returns nil when this machine will not say how hot it is. That is deliberate:
-- resting on a fixed schedule to guard against a temperature nobody measured is
-- a slower run bought for nothing, and doing it silently would be worse than
-- not doing it at all.
function M.governor(settings)
  local heat = settings.heat or {}
  if not M.source() then
    io.stderr:write("notice: this machine does not report its temperature, so " ..
                    "the run will not\n        pause to let it cool. It will " ..
                    "simply go as fast as it can.\n")
    return nil
  end

  local self = {
    seen = 0, rested = 0, peak = 0, readings = 0,
    warm = heat.warm or 62, hot = heat.hot or 76,
    rest_warm = heat.rest_warm or 0.06, rest_hot = heat.rest_hot or 0.55,
    ceiling = heat.ceiling or 2.5,
    every = heat.check_every or 2,
  }

  -- {{{ self.consider()
  -- One unit of work has finished. Rest if the machine wants it.
  function self.consider()
    self.seen = self.seen + 1
    if self.seen % self.every ~= 0 then return end
    local degrees = M.temperature()
    if not degrees then return end
    self.readings = self.readings + 1
    if degrees > self.peak then self.peak = degrees end
    -- The rest is proportional to how far over the mark it is, not a step.
    --
    -- WHY. A flat pause treats one degree over as the same emergency as ten,
    -- so it either does nothing when the machine is genuinely climbing or
    -- throttles a run that was barely warm. Sloping the response between the
    -- two marks means a machine that is only just warm barely slows down, and
    -- one that is still climbing past the hot mark keeps giving ground.
    if degrees >= self.warm then
      local over = (degrees - self.warm) / math.max(self.hot - self.warm, 1)
      if over > self.ceiling then over = self.ceiling end
      local rest = self.rest_warm + (self.rest_hot - self.rest_warm) * over
      M.rest(rest)
      self.rested = self.rested + rest
    end
  end
  -- }}}

  -- {{{ self.report()
  function self.report()
    return { peak = self.peak, rested = self.rested, readings = self.readings }
  end
  -- }}}

  return self
end
-- }}}

-- {{{ M.nice_prefix(settings)
-- The words that put a worker at the back of the queue.
--
-- This does not make the machine cooler -- a busy core is a busy core -- but it
-- means a run that is heating the processor never also makes the machine feel
-- broken to whoever is using it.
function M.nice_prefix(settings)
  local level = settings.batch and settings.batch.nice
  if not level or level == 0 then return "" end
  return "nice -n " .. tostring(level) .. " "
end
-- }}}

-- {{{ main(argv)
-- Run directly, this just says what it can see.
local function main(argv)
  project.arguments(argv)
  local settings = project.hello("031a-when-the-machine-runs-hot")
  local where = M.source()
  if not where then
    io.write("this machine does not report its temperature.\n")
  else
    io.write("reading ", where, "\n")
    io.write(string.format("it is %.1f degrees right now\n", M.temperature()))
    io.write(string.format("resting starts at %d and gets serious at %d\n",
             settings.heat.warm, settings.heat.hot))
  end
  local howmany, processors = M.workers(settings)
  io.write(string.format("%d processors, %d workers, %sat the back of the queue\n",
           processors, howmany,
           M.nice_prefix(settings) == "" and "not " or ""))
  project.goodbye("031a-when-the-machine-runs-hot", { howmany .. " workers" })
end
-- }}}

if arg and arg[0] and arg[0]:find("031a%-when%-the%-machine%-runs%-hot") then
  main(arg)
end

return M
