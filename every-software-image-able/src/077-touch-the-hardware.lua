-- 077-touch-the-hardware.lua
--
-- Finding out what body the machine has, and operating it -- under the
-- discipline in docs/003a, which is this ticket's subject rather than its
-- advice. Issue 205.
--
-- For a general: the machine can now ask every socket in the computer who is
-- plugged into it, and read and write those devices' controls. Some of those
-- controls destroy hardware permanently when written wrongly, so the
-- dangerous ones are refused until a description has been read and
-- confirmed, and every exploratory write must be written down before it
-- happens and must say what it expects.
--
-- WHY THE DISCIPLINE IS A CONSTRAINT AND NOT A PREFERENCE. Writing the wrong
-- value to the wrong register destroys hardware permanently -- not a crash,
-- not corruption, not something a reboot clears. Every other failure in this
-- project is recoverable by writing more software. These are not.
--
-- THE NOTE COMES FIRST, AND THAT IS WHY THIS NEEDS STORAGE (206). A probe
-- that kills the machine cannot report anything afterwards -- the reporting
-- channel dies with the machine (notes/023). So the intent is written to
-- storage BEFORE the write happens, and the next boot reads it and knows
-- what killed the last one. Without somewhere to put it, the discipline is
-- an intention with no failing test attached, and these two tickets land
-- together or not at all.

local M = {}

-- {{{ M.DESTROYING -- what may not be touched without a confirmed description
--
-- From docs/003a, with the mechanism for each, because a refusal that does
-- not say what it is protecting teaches nothing and gets worked around.
M.DESTROYING = {
  { kind = "voltage",
    why = "the regulator feeding the part; raising it past what the silicon "
       .. "tolerates damages it in seconds" },
  { kind = "clock",
    why = "the divider or multiplier that clocks the part; the same, and the "
       .. "register looks exactly like every other register" },
  { kind = "thermal",
    why = "the protection that stops it cooking. Switched off, a part run "
       .. "hard does not report a problem; it stops existing" },
  { kind = "non-volatile",
    why = "where the part keeps its identity and sometimes its firmware. "
       .. "Written into, it may never announce itself again -- so it cannot "
       .. "be repaired by trying harder, because it will not be found" },
  { kind = "pin-direction",
    why = "a pin driving one way while something outside drives the other is "
       .. "a short circuit through the driver transistor" },
}

M.DESTROYING_BY_KIND = {}
for _, entry in ipairs(M.DESTROYING) do M.DESTROYING_BY_KIND[entry.kind] = entry end
-- }}}

-- {{{ M.new(options)
--
-- options:
--   enumerate  function() -> a list of devices, each with slot, vendor,
--              part, class, registers, interrupt
--   read       function(device, offset, width) -> value
--   write      function(device, offset, width, value)
--   store      a storage (076), for the notes
--   note_on    which device the notes are written to
--   note_at    which block they start at
function M.new(options)
  return {
    enumerate = options.enumerate,
    read = options.read,
    write = options.write,
    store = options.store,
    note_on = options.note_on,
    note_at = options.note_at or 1,
    keep = options.keep,          -- the storage module (076)
    found = nil,
    confirmed = {},               -- device kind -> the description confirmed
    reset_known = {},             -- device name -> whether a reset was found
    notes_written = 0,
    reads = 0,
    writes = 0,
    refusals = 0,
  }
end
-- }}}

-- {{{ M.look(hardware)
-- The machine finding out what limbs it has. Walk the numbered slots and
-- return everything that answers.
function M.look(hardware)
  local found = hardware.enumerate()
  hardware.found = found
  return found
end
-- }}}

-- {{{ local function device_by_name(hardware, name)
local function device_by_name(hardware, name)
  for _, device in ipairs(hardware.found or {}) do
    if device.name == name then return device end
  end
  return nil
end
-- }}}

-- {{{ M.peek(hardware, name, offset, width)
-- Reads are where nearly all the information is and nearly none of the
-- danger, so this is the easy one and is deliberately easier to reach than
-- its writing twin.
--
-- Two things keep "reads are safe" from being exactly true, and both are
-- said rather than assumed away: some registers clear themselves when read,
-- so reading them is a change; and on some buses a read from an address
-- nothing answers on hangs until something resets the bus. Both are
-- survivable. Neither is destructive.
function M.peek(hardware, name, offset, width)
  local device = device_by_name(hardware, name)
  if not device then
    hardware.refusals = hardware.refusals + 1
    return nil, "nothing answered to '" .. tostring(name) .. "'. Ask <call body>."
  end
  hardware.reads = hardware.reads + 1
  return hardware.read(device, offset, width)
end
-- }}}

-- {{{ M.write_the_note(hardware, note)
-- Device, register, value, and what is expected -- to storage, before the
-- write happens, so a probe that kills the machine still tells the next boot
-- what killed it.
function M.write_the_note(hardware, note)
  if not hardware.store or not hardware.note_on then
    return nil, "there is nowhere to write a note, so no exploratory write "
      .. "may happen. A probe that kills the machine has to leave something "
      .. "behind, because the machine cannot say anything afterwards."
  end

  local text = table.concat({
    "about to write", note.device, note.register, note.value,
    "expecting: " .. (note.expecting or ""),
  }, "\n")

  local at = hardware.note_at + hardware.notes_written
  local ok, why = hardware.keep.write(hardware.store, hardware.note_on, at,
    text .. string.rep("\0", 512 - #text % 512))
  if not ok then return nil, "the note could not be kept: " .. tostring(why) end

  hardware.notes_written = hardware.notes_written + 1
  return at
end
-- }}}

-- {{{ M.poke(hardware, name, offset, width, value, options)
-- The dangerous one, and made harder to reach than the reading one on
-- purpose.
--
-- options: expecting (what the machine thinks will happen; required),
--          kind (which destroying category this register is, if any)
function M.poke(hardware, name, offset, width, value, options)
  options = options or {}
  local device = device_by_name(hardware, name)
  if not device then
    hardware.refusals = hardware.refusals + 1
    return nil, "nothing answered to '" .. tostring(name) .. "'"
  end

  -- {{{ a prediction is required
  -- A call that says what is expected can be evaluated; one that does not
  -- produces a result nobody can interpret. This is the same rule the
  -- compiler follows when it varies an approach (docs/004) -- the value of
  -- an experiment lives in having said beforehand what would count as which
  -- answer.
  if not options.expecting or options.expecting == "" then
    hardware.refusals = hardware.refusals + 1
    return nil, "an exploratory write must say what it expects to happen. "
      .. "A write with no prediction produces a result nobody can interpret."
  end
  -- }}}

  -- {{{ the destroying registers, refused by default
  local kind = options.kind or (device.destroying and device.destroying[offset])
  if kind then
    local entry = M.DESTROYING_BY_KIND[kind]
    if not hardware.confirmed[kind] then
      hardware.refusals = hardware.refusals + 1
      return nil, "that is a " .. kind .. " register: " ..
        (entry and entry.why or "it can destroy the part permanently")
        .. ". It is refused until a description of this part has been read "
        .. "and confirmed, and confirming is a read-only act."
    end
  end
  -- }}}

  -- {{{ the note, before the write
  local at, refusal = M.write_the_note(hardware, {
    device = name,
    register = string.format("0x%x", offset),
    value = string.format("0x%x", value),
    expecting = options.expecting,
  })
  if not at then
    hardware.refusals = hardware.refusals + 1
    return nil, refusal
  end
  -- }}}

  hardware.writes = hardware.writes + 1
  hardware.write(device, offset, width, value)

  -- and read back, so the machine finds out what actually happened rather
  -- than what it predicted. The difference between those two is the entire
  -- content of an experiment.
  local now = hardware.read(device, offset, width)
  return now, nil, { note_at = at, expected = options.expecting }
end
-- }}}

-- {{{ M.confirm(hardware, kind, description)
-- Opening a destroying category. Confirming is a read-only act -- it is
-- reading a description and saying it matches what the part reports about
-- itself -- which is why it is separate from writing anything.
function M.confirm(hardware, kind, description)
  if not M.DESTROYING_BY_KIND[kind] then
    return nil, "'" .. tostring(kind) .. "' is not one of the destroying "
      .. "kinds. They are: " .. M.kinds()
  end
  if type(description) ~= "string" or #description < 1 then
    return nil, "confirming needs the description that was read"
  end
  hardware.confirmed[kind] = description
  return true
end
-- }}}

-- {{{ M.kinds()
function M.kinds()
  local names = {}
  for _, entry in ipairs(M.DESTROYING) do names[#names + 1] = entry.kind end
  return table.concat(names, ", ")
end
-- }}}

-- {{{ M.offer(catalogue, hands, hardware)
function M.offer(catalogue, hands, hardware)
  hands.offer(catalogue, {
    name = "body", takes = {}, gives = "what is attached",
    note = "every device that answers, and where its controls are",
    does = function()
      local found = M.look(hardware)
      if #found == 0 then return "nothing answered. This machine has no body "
        .. "it can find, which is a real answer and not a failure." end
      local lines = { "what answered:" }
      for _, device in ipairs(found) do
        lines[#lines + 1] = string.format(
          "  %-12s slot %d  made by 0x%04x, part 0x%04x, a %s",
          device.name, device.slot, device.vendor, device.part,
          device.class or "thing nobody named")
        for _, window in ipairs(device.registers or {}) do
          lines[#lines + 1] = string.format("      controls at 0x%x for 0x%x",
                                            window.base, window.length)
        end
        if device.interrupt and device.interrupt >= 0 then
          lines[#lines + 1] = "      pulls line " .. device.interrupt
        end
      end
      return table.concat(lines, "\n")
    end,
  })

  hands.offer(catalogue, {
    name = "read_register", takes = { "device", "offset", "width" },
    gives = "what the register says",
    does = function(arguments)
      local offset, width = tonumber(arguments[2]), tonumber(arguments[3])
      if not offset or not width then return nil, "the offset and the width "
        .. "must be numbers" end
      local value, why = M.peek(hardware, arguments[1], offset, width)
      if not value then return nil, why end
      return string.format("0x%x", value)
    end,
  })

  hands.offer(catalogue, {
    name = "write_register",
    takes = { "device", "offset", "width", "value", "expecting" },
    gives = "what the register says afterwards",
    note = "writes a device register, after writing down what is expected",
    dangerous = true,
    does = function(arguments)
      local offset = tonumber(arguments[2])
      local width = tonumber(arguments[3])
      local value = tonumber(arguments[4])
      if not offset or not width or not value then
        return nil, "the offset, width and value must be numbers"
      end
      local now, why = M.poke(hardware, arguments[1], offset, width, value,
                              { expecting = arguments[5] })
      if not now then return nil, why end
      return string.format("0x%x", now)
    end,
  })

  hands.offer(catalogue, {
    name = "dangers", takes = {}, gives = "what may not be touched, and why",
    does = function()
      local lines = { "these registers are refused until a description is "
        .. "read and confirmed:" }
      for _, entry in ipairs(M.DESTROYING) do
        lines[#lines + 1] = "  " .. entry.kind .. " -- " .. entry.why
        if hardware.confirmed[entry.kind] then
          lines[#lines + 1] = "      (confirmed, and therefore open)"
        end
      end
      lines[#lines + 1] = "Every other failure in this machine can be undone "
        .. "by writing more software. These cannot."
      return table.concat(lines, "\n")
    end,
  })
end
-- }}}

return M
