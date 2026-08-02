-- 071-touch-memory.lua
--
-- Reading and writing physical addresses, as hands the machine can ask for.
-- Issue 203. No translation and no permission layer -- this machine has
-- neither, and adding one here would be inventing a kernel the design
-- deliberately does not have (docs/001).
--
-- For a general: the machine can now reach into the computer's memory
-- directly, by address, the way the hardware itself does. There is exactly
-- one thing it is not allowed to touch, and it is itself.
--
-- THE ONE REFUSAL. Writes into the engine and the weights are refused. This
-- is the only place in the seed where the model is stopped from doing
-- something it asked to do, and the reason is specific rather than
-- protective: a mind that overwrites itself does not report an error, it
-- goes quiet (docs/010). Every other mistake here is recoverable by writing
-- more software. That one is not.
--
-- READS ARE ALLOWED EVERYWHERE THE MAP CALLS USABLE, including the engine
-- and the weights -- a machine reading its own mind is doing something
-- useful, and 204 depends on being able to read back what was placed.
--
-- WHAT IS RETURNED IS WHAT WAS READ, never what was expected. Some addresses
-- are devices rather than memory and do not hold what was last written to
-- them; that difference is information the machine needs, and smoothing it
-- over would hide the most interesting thing on the bus.

local M = {}

-- {{{ M.WIDTHS -- what a single touch may be
--
-- A device register is often required to be touched at exactly its own
-- width: a four-byte register poked one byte at a time may do nothing, or
-- something else entirely. So the width is the machine's to choose rather
-- than something inferred from the value.
M.WIDTHS = { [1] = true, [2] = true, [4] = true, [8] = true }
-- }}}

-- {{{ M.new(options)
--
-- options:
--   usable   list of { base, length } the firmware map called usable
--   ours     list of { base, length, what } the engine and weights occupy
--   read     function(address, width) -> value        the real touch
--   write    function(address, width, value)          the real touch
--
-- `read` and `write` are handed in rather than built here, because on the
-- metal they are three instructions and hosted they are a pretend region.
-- The rules are the same either way, and the rules are what this file is.
function M.new(options)
  return {
    usable = options.usable or {},
    ours = options.ours or {},
    read = options.read,
    write = options.write,
    refusals = 0,
    reads = 0,
    writes = 0,
  }
end
-- }}}

-- {{{ local function within(ranges, address, width)
-- Which range holds all of this touch, or nil. A touch that begins inside a
-- range and ends outside it belongs to neither, which is the answer that
-- keeps a bulk operation from walking off the end of real memory.
local function within(ranges, address, width)
  for _, range in ipairs(ranges) do
    if address >= range.base and address + width <= range.base + range.length then
      return range
    end
  end
  return nil
end
-- }}}

-- {{{ local function overlaps(ranges, address, width)
local function overlaps(ranges, address, width)
  for _, range in ipairs(ranges) do
    if address < range.base + range.length and range.base < address + width then
      return range
    end
  end
  return nil
end
-- }}}

-- {{{ M.check_read(memory, address, width)
-- Whether a read may happen, and why not. Separate from doing it, so the
-- bulk forms can ask about a whole range before touching any of it.
function M.check_read(memory, address, width)
  if not M.WIDTHS[width] then
    return nil, "a touch is 1, 2, 4 or 8 bytes wide, not " .. tostring(width)
  end
  if address % width ~= 0 then
    -- Some processors fault on an unaligned touch and some quietly split it
    -- into two, which is a different operation than the one asked for.
    -- Refusing is the only answer that means the same thing everywhere.
    return nil, string.format("0x%x is not a multiple of %d, and an unaligned "
      .. "touch means different things on different processors", address, width)
  end
  if not within(memory.usable, address, width) then
    -- On some machines a read from nothing hangs the bus, which turns a
    -- typo into a dead computer.
    return nil, string.format("0x%x is not inside any range the firmware "
      .. "called usable, and on some machines reading from nothing hangs "
      .. "the bus", address)
  end
  return true
end
-- }}}

-- {{{ M.check_write(memory, address, width)
function M.check_write(memory, address, width)
  local ok, why = M.check_read(memory, address, width)
  if not ok then return nil, why end
  return M.check_range_write(memory, address, width)
end
-- }}}

-- {{{ M.check_range_read(memory, address, bytes) and its writing twin
--
-- A stretch rather than a single touch. Separate from check_read because a
-- BYTE COUNT IS NOT A WIDTH: a sixty-four byte range is an ordinary thing to
-- copy and a nonsense thing to load in one instruction, and running the
-- range checks through the width check refused every bulk operation as
-- though sixty-four were an impossible width. It refused correctly, for
-- entirely the wrong reason, which is how it went unnoticed until the
-- comparison that should have caught it was itself refused.
function M.check_range_read(memory, address, bytes)
  if bytes <= 0 then
    return nil, "a range of " .. tostring(bytes) .. " bytes is not a range"
  end
  if not within(memory.usable, address, bytes) then
    return nil, string.format("0x%x for 0x%x bytes runs outside the ranges the "
      .. "firmware called usable", address, bytes)
  end
  return true
end

function M.check_range_write(memory, address, bytes)
  local ok, why = M.check_range_read(memory, address, bytes)
  if not ok then return nil, why end

  local mine = overlaps(memory.ours, address, bytes)
  if mine then
    return nil, string.format("0x%x for 0x%x bytes reaches into the %s. Writing "
      .. "there is the one thing this machine will not do: a mind that "
      .. "overwrites itself does not report an error, it goes quiet.",
      address, bytes, mine.what or "engine")
  end
  return true
end
-- }}}

-- {{{ M.peek(memory, address, width)
function M.peek(memory, address, width)
  local ok, why = M.check_read(memory, address, width)
  if not ok then
    memory.refusals = memory.refusals + 1
    return nil, why
  end
  memory.reads = memory.reads + 1
  return memory.read(address, width)
end
-- }}}

-- {{{ M.poke(memory, address, width, value)
-- Writes, then reads back and returns what is actually there. Not to check
-- the write -- to tell the machine what the address really is. A device
-- register that reads back differently is the bus saying something, and the
-- difference is the most interesting thing it can say.
function M.poke(memory, address, width, value)
  local ok, why = M.check_write(memory, address, width)
  if not ok then
    memory.refusals = memory.refusals + 1
    return nil, why
  end
  memory.writes = memory.writes + 1
  memory.write(address, width, value)
  return memory.read(address, width)
end
-- }}}

-- {{{ M.poke_byte(memory, address, value)
-- One byte, through the same rules. Placing a program (204) writes byte by
-- byte and must go through the rules rather than around them -- a hand that
-- could bypass the one refusal would make the refusal decorative.
function M.poke_byte(memory, address, value)
  local ok, why = M.check_range_write(memory, address, 1)
  if not ok then
    memory.refusals = memory.refusals + 1
    return nil, why
  end
  memory.writes = memory.writes + 1
  memory.write(address, 1, value)
  return true
end
-- }}}

-- {{{ the bulk forms
--
-- A model issuing one call per byte spends its whole context on addresses.
-- Each of these checks the WHOLE range before touching any of it, so a
-- refusal happens before a half-finished operation rather than in the middle
-- of one.

-- {{{ M.fill(memory, address, width, count, value)
function M.fill(memory, address, width, count, value)
  if not M.WIDTHS[width] then
    memory.refusals = memory.refusals + 1
    return nil, "a touch is 1, 2, 4 or 8 bytes wide, not " .. tostring(width)
  end
  if address % width ~= 0 then
    memory.refusals = memory.refusals + 1
    return nil, string.format("0x%x is not a multiple of %d", address, width)
  end
  local ok, why = M.check_range_write(memory, address, width * count)
  if not ok then
    memory.refusals = memory.refusals + 1
    return nil, why
  end
  for step = 0, count - 1 do
    memory.write(address + step * width, width, value)
  end
  memory.writes = memory.writes + count
  return count
end
-- }}}

-- {{{ M.copy(memory, from, to, bytes)
function M.copy(memory, from, to, bytes)
  local readable, why = M.check_range_read(memory, from, bytes)
  if not readable then
    memory.refusals = memory.refusals + 1
    return nil, why
  end
  local writable, refusal = M.check_range_write(memory, to, bytes)
  if not writable then
    memory.refusals = memory.refusals + 1
    return nil, refusal
  end

  -- Overlapping copies walk in whichever direction does not eat the source.
  -- Getting this wrong produces a repeating pattern rather than a copy, and
  -- it looks like a memory fault rather than a direction mistake.
  if to > from and to < from + bytes then
    for offset = bytes - 1, 0, -1 do
      memory.write(to + offset, 1, memory.read(from + offset, 1))
    end
  else
    for offset = 0, bytes - 1 do
      memory.write(to + offset, 1, memory.read(from + offset, 1))
    end
  end
  memory.reads = memory.reads + bytes
  memory.writes = memory.writes + bytes
  return bytes
end
-- }}}

-- {{{ M.compare(memory, first, second, bytes)
-- Where two ranges first differ: an offset when they do, FALSE when they are
-- the same, and nil with a reason when the comparison could not happen.
--
-- Three answers rather than two, because "they are identical" and "I could
-- not look" are different facts that both came back as nothing in the first
-- version -- and a test asking only whether the answer was nothing passed
-- happily while every comparison in it was being refused.
--
-- The offset rather than a yes or no, because "they differ" is a question
-- and "they differ at 0x40" is an answer.
function M.compare(memory, first, second, bytes)
  local ok, why = M.check_range_read(memory, first, bytes)
  if not ok then
    memory.refusals = memory.refusals + 1
    return nil, why
  end
  local also, refusal = M.check_range_read(memory, second, bytes)
  if not also then
    memory.refusals = memory.refusals + 1
    return nil, refusal
  end
  for offset = 0, bytes - 1 do
    if memory.read(first + offset, 1) ~= memory.read(second + offset, 1) then
      memory.reads = memory.reads + offset * 2
      return offset
    end
  end
  memory.reads = memory.reads + bytes * 2
  return false
end
-- }}}
-- }}}

-- {{{ M.offer(catalogue, hands, memory)
-- The hands themselves. Numbers arrive as text and are read in whichever
-- base they were written in, because a machine reasoning about addresses
-- writes them in hexadecimal and a machine reasoning about counts does not.
local function number(text)
  local value = tonumber(text)
  if value and value == math.floor(value) then return value end
  return nil
end

function M.offer(catalogue, hands, memory)
  local function numbers(arguments, count)
    local out = {}
    for index = 1, count do
      local value = number(arguments[index])
      if not value then
        return nil, "'" .. tostring(arguments[index])
          .. "' is not a whole number. Addresses may be written 0x1234."
      end
      out[index] = value
    end
    return out
  end

  hands.offer(catalogue, {
    name = "peek", takes = { "address", "width" }, gives = "what is there",
    note = "reads 1, 2, 4 or 8 bytes at a physical address",
    does = function(arguments)
      local got, why = numbers(arguments, 2)
      if not got then return nil, why end
      local value, refusal = M.peek(memory, got[1], got[2])
      if not value then return nil, refusal end
      return string.format("0x%x", value)
    end,
  })

  hands.offer(catalogue, {
    name = "poke", takes = { "address", "width", "value" },
    gives = "what is there afterwards",
    note = "writes, then says what the address actually holds now",
    does = function(arguments)
      local got, why = numbers(arguments, 3)
      if not got then return nil, why end
      local value, refusal = M.poke(memory, got[1], got[2], got[3])
      if not value then return nil, refusal end
      return string.format("0x%x", value)
    end,
  })

  hands.offer(catalogue, {
    name = "fill", takes = { "address", "width", "count", "value" },
    gives = "how many were written",
    does = function(arguments)
      local got, why = numbers(arguments, 4)
      if not got then return nil, why end
      local written, refusal = M.fill(memory, got[1], got[2], got[3], got[4])
      if not written then return nil, refusal end
      return tostring(written)
    end,
  })

  hands.offer(catalogue, {
    name = "copy", takes = { "from", "to", "bytes" }, gives = "how many moved",
    does = function(arguments)
      local got, why = numbers(arguments, 3)
      if not got then return nil, why end
      local moved, refusal = M.copy(memory, got[1], got[2], got[3])
      if not moved then return nil, refusal end
      return tostring(moved)
    end,
  })

  hands.offer(catalogue, {
    name = "compare", takes = { "first", "second", "bytes" },
    gives = "where they first differ",
    does = function(arguments)
      local got, why = numbers(arguments, 3)
      if not got then return nil, why end
      local where, note = M.compare(memory, got[1], got[2], got[3])
      if where then return "they differ at " .. string.format("0x%x", where) end
      if where == false then return "the same, every byte" end
      return nil, note
    end,
  })

  hands.offer(catalogue, {
    name = "memory", takes = {}, gives = "what may be touched",
    note = "the usable ranges, and the ones this machine is made of",
    does = function()
      local lines = { "the ranges the firmware called usable:" }
      for _, range in ipairs(memory.usable) do
        lines[#lines + 1] = string.format("  0x%x for 0x%x bytes",
                                          range.base, range.length)
      end
      lines[#lines + 1] = "and inside those, what this machine is made of "
        .. "-- readable, never writable:"
      for _, range in ipairs(memory.ours) do
        lines[#lines + 1] = string.format("  0x%x for 0x%x bytes  -- %s",
                                          range.base, range.length,
                                          range.what or "ours")
      end
      return table.concat(lines, "\n")
    end,
  })
end
-- }}}

return M
