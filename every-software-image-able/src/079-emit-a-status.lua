-- 079-emit-a-status.lua
--
-- Three numbers, said out loud on whatever the board has: an aspect saying
-- where this came from, a code meaning whatever the emitting program needs
-- it to mean, and a magnitude on an axis where fifty is ordinary. Issue 207.
--
-- For a general: a machine with a handful of lamps cannot spell. This is how
-- it says something anyway -- a colour and a shape together, so the reading
-- survives a failed lamp, a dim room, or a person who does not see the
-- colours the same way.
--
-- THE MEANINGS ARE NOT HERE, DELIBERATELY. The seed provides the mechanism;
-- the lookup that says what a given code means is something the grown
-- machine builds for itself (docs/006), and baking a vocabulary in would be
-- deciding something that is not ours to decide. Two machines emitting
-- seventeen mean unrelated things, and the aspect is what keeps them apart.
--
-- MAGNITUDE CARRIES NO OPINION. Fifty is ordinary; distance in either
-- direction means attention should be given, and nothing more. What the
-- attention should be about comes from the code.
--
-- THE READING IS MACHINE-WIDE. It lives at one address rather than being a
-- private number each program keeps, so the picture is comparable across
-- everything running at once -- and it is the same address the assembler's
-- loop emissions push on (073), which is what makes a runaway program and a
-- worried one show up on the same dial.

local M = {}

-- {{{ M.ORDINARY, and the thresholds
M.ORDINARY = 50
M.HIGH = 65
M.LOW = 40
-- }}}

-- {{{ M.COLOURSHAPES -- the aspects, as colour AND shape
--
-- Both encodings say the same thing on purpose. Colour alone fails a dim
-- room and a person who does not distinguish them; shape alone fails a
-- readout that has only colour. Together the reading survives either.
--
-- These are the shapes the SEED can emit about itself. A grown machine adds
-- its own, because its programs are its own.
M.COLOURSHAPES = {
  { aspect = 1, colour = "green",  shape = "circle",   about = "the engine, thinking" },
  { aspect = 2, colour = "blue",   shape = "square",   about = "memory" },
  { aspect = 3, colour = "yellow", shape = "triangle", about = "storage" },
  { aspect = 4, colour = "red",    shape = "cross",    about = "hardware being explored" },
  { aspect = 5, colour = "white",  shape = "bar",      about = "something the machine wrote, running" },
}

M.BY_ASPECT = {}
for _, entry in ipairs(M.COLOURSHAPES) do M.BY_ASPECT[entry.aspect] = entry end
-- }}}

-- {{{ M.new(options)
--
-- options:
--   lamps        function(colourshape, status) -> ok  -- where there are lamps
--   draw         function(colourshape, status) -> ok  -- the framebuffer (202)
--   wire         function(text) -> ok                 -- the serial port
--   memory       a memory (071), for the machine-wide reading
--   magnitude_at the address it lives at
--
-- All three displays are optional and tried in that order, and WHICH ONE
-- HAPPENED IS SAID. A status shown nowhere is worse than no status, because
-- it looks like nothing happened.
function M.new(options)
  return {
    lamps = options.lamps,
    draw = options.draw,
    wire = options.wire,
    memory = options.memory,
    magnitude_at = options.magnitude_at,
    emitted = 0,
    crossings = 0,
    last = nil,
  }
end
-- }}}

-- {{{ M.emit(status, aspect, code, magnitude, occasion)
-- The whole of it: keep the reading where everything can compare against it,
-- then show it wherever it can be shown.
function M.emit(status, aspect, code, magnitude, occasion)
  local shape = M.BY_ASPECT[aspect]
  if not shape then
    return nil, "there is no aspect " .. tostring(aspect) .. ". The seed's own "
      .. "are 1 to " .. #M.COLOURSHAPES .. "; a machine that wants more adds them."
  end
  -- Two digits each, so the whole thing fits on a small array of lamps.
  for name, value in pairs({ code = code, magnitude = magnitude }) do
    if type(value) ~= "number" or value < 0 or value > 99
       or value ~= math.floor(value) then
      return nil, "the " .. name .. " is two digits, and " .. tostring(value)
        .. " is not"
    end
  end

  local reading = {
    aspect = aspect, code = code, magnitude = magnitude,
    occasion = occasion or "", colour = shape.colour, shape = shape.shape,
  }

  if status.memory and status.magnitude_at then
    status.memory.write(status.magnitude_at, 8, magnitude)
  end

  -- {{{ which display took it, said rather than assumed
  local shown = nil
  if status.lamps and status.lamps(shape, reading) then
    shown = "lamps"
  elseif status.draw and status.draw(shape, reading) then
    shown = "the screen"
  elseif status.wire and status.wire(M.as_text(reading)) then
    shown = "the wire"
  end

  if not shown then
    return nil, "this machine has nowhere to show a status. That is worse "
      .. "than having none, because it looks like nothing happened."
  end
  -- }}}

  status.emitted = status.emitted + 1
  status.last = reading
  reading.shown_on = shown

  if magnitude >= M.HIGH or magnitude <= M.LOW then
    status.crossings = status.crossings + 1
    reading.crossed = true
  end

  return reading
end
-- }}}

-- {{{ M.as_text(reading)
-- For the wire, and for anywhere else that can spell. The colour and the
-- shape are both said, because the point of carrying two encodings is that
-- either one alone is enough.
function M.as_text(reading)
  local far = ""
  if reading.magnitude >= M.HIGH then far = "  (high -- look)"
  elseif reading.magnitude <= M.LOW then far = "  (low -- look)" end
  return string.format("status %02d %02d %02d  %s %s%s%s",
                       reading.aspect, reading.code, reading.magnitude,
                       reading.colour, reading.shape,
                       reading.occasion ~= "" and ("  after " .. reading.occasion) or "",
                       far)
end
-- }}}

-- {{{ M.settle(status)
-- What a program does when it breaks out of a loop that might have been
-- infinite: the magnitude returns to ordinary. The thresholds it crossed on
-- the way are the record of how close it came, which is why the crossings
-- are counted and not reset with it.
function M.settle(status)
  if status.memory and status.magnitude_at then
    status.memory.write(status.magnitude_at, 8, M.ORDINARY)
  end
  return M.ORDINARY
end
-- }}}

-- {{{ M.reading(status)
-- The machine-wide magnitude, as it stands. Anything may ask -- that is what
-- makes it a shared picture rather than a private count.
function M.reading(status)
  if not status.memory or not status.magnitude_at then return nil end
  return status.memory.read(status.magnitude_at, 8)
end
-- }}}

-- {{{ M.offer(catalogue, hands, status)
function M.offer(catalogue, hands, status)
  hands.offer(catalogue, {
    name = "emit", takes = { "aspect", "code", "magnitude", "occasion" },
    gives = "where it was shown",
    note = "says three numbers on whatever this machine has to show them on",
    does = function(arguments)
      local aspect = tonumber(arguments[1])
      local code = tonumber(arguments[2])
      local magnitude = tonumber(arguments[3])
      if not aspect or not code or not magnitude then
        return nil, "the aspect, code and magnitude are all numbers"
      end
      local reading, why = M.emit(status, aspect, code, magnitude, arguments[4])
      if not reading then return nil, why end
      return M.as_text(reading) .. "  -- shown on " .. reading.shown_on
    end,
  })

  hands.offer(catalogue, {
    name = "aspects", takes = {}, gives = "the colourshapes this machine has",
    note = "what each colour and shape stands for",
    does = function()
      local lines = { "the aspects the seed itself can emit:" }
      for _, entry in ipairs(M.COLOURSHAPES) do
        lines[#lines + 1] = string.format("  %d  %-7s %-9s %s",
          entry.aspect, entry.colour, entry.shape, entry.about)
      end
      lines[#lines + 1] = ""
      lines[#lines + 1] = "The codes mean whatever the emitting program needs "
        .. "them to mean; nothing here says what. Building the lookup that "
        .. "answers that is the first thing worth doing once anything is "
        .. "emitting at all."
      lines[#lines + 1] = "Magnitude carries no opinion. Fifty is ordinary; "
        .. "distance either way means a look is warranted, and nothing more."
      return table.concat(lines, "\n")
    end,
  })

  hands.offer(catalogue, {
    name = "how_it_is", takes = {}, gives = "the machine-wide reading",
    does = function()
      local now = M.reading(status)
      if not now then return "this machine keeps no shared reading" end
      local distance = math.abs(now - M.ORDINARY)
      return string.format("the magnitude is %d, which is %d from ordinary%s. "
        .. "%d thresholds have been crossed since this machine started.",
        now, distance,
        (now >= M.HIGH or now <= M.LOW) and " -- far enough to look" or "",
        status.crossings)
    end,
  })
end
-- }}}

return M
