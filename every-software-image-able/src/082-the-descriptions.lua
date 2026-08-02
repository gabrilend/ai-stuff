-- 082-the-descriptions.lua
--
-- Machine-readable descriptions of the standard device classes, and the
-- read-only protocol that decides whether a description is about the part in
-- front of it. Issue 302.
--
-- For a general: the machine can find out what is plugged into it and learns
-- nothing from that about how to work any of it. Knowing there is a network
-- chip at an address tells you where the doorbell is, not what happens when
-- you ring it. These are the documents that say.
--
-- WRITTEN FOR A COMPUTER RATHER THAN FOR AN ENGINEER. Every field is
-- something a driver can be written from without a person in between.
--
-- CONFIRMATION IS A READ-ONLY ACT, AND THAT IS THE POINT. Confirming a
-- description by writing to the device is exactly the failure the whole
-- exploration discipline exists to prevent (docs/003a). So confirmation
-- reads: the maker and part must match, the registers the description calls
-- read-only must hold what it predicts, the reserved ones must hold their
-- predicted pattern, and the revision must be inside the range the
-- description covers.
--
-- A PARTIAL MATCH IS A FAILURE, NOT A NEAR MISS. Enough agreement to feel
-- confirmed with one silent disagreement in the register that matters is the
-- dangerous case, not the safe one.
--
-- A DESCRIPTION IS A TRANSCRIPTION OF SOMEBODY ELSE'S DOCUMENT, and
-- transcriptions rot. Every one names its source, so it can be re-checked
-- when a part revision lands.

local M = {}

-- {{{ M.FIELDS -- what a description must hold, and why each is there
--
-- Named as data so a description missing something is refused when it is
-- loaded rather than when a driver written from it fails strangely.
M.FIELDS = {
  { name = "class",        why = "which kind of thing this is" },
  { name = "identifies",   why = "what marks a device as a member of this class" },
  { name = "source",       why = "whose document this was transcribed from; a "
                              .. "description whose source is unnamed cannot be "
                              .. "re-checked when a part revision lands" },
  { name = "revisions",    why = "which revisions of the part this covers" },
  { name = "registers",    why = "offset, width, and what each bit means" },
  { name = "start",        why = "the initialisation sequence INCLUDING the "
                              .. "waits -- hardware needs time between steps, "
                              .. "and skipping one produces failures that look "
                              .. "random" },
  { name = "rings",        why = "how data actually moves: the descriptor "
                              .. "layout" },
  { name = "interrupts",   why = "what raises one, what to read to find out "
                              .. "why, what to write to acknowledge it" },
  { name = "errata",       why = "what is wrong with the part. Never derivable "
                              .. "by probing, and the commonest reason a "
                              .. "correct-looking driver fails" },
  { name = "destroying",   why = "which registers end the part permanently" },
}
-- }}}

-- {{{ M.check(description)
-- Refuses a description that could not be written from. Loading is where
-- this belongs: a description with no errata section may genuinely have no
-- errata, but one that never had the section is one nobody checked.
function M.check(description)
  local missing = {}
  for _, field in ipairs(M.FIELDS) do
    if description[field.name] == nil then missing[#missing + 1] = field.name end
  end
  if #missing > 0 then
    return nil, "this description has no " .. table.concat(missing, ", ")
      .. ". A description missing a section is one nobody checked, which is "
      .. "different from a part that has nothing to say there."
  end
  return true
end
-- }}}

-- {{{ M.CARRIED -- the classes worth carrying
--
-- Storage first, because 206 depends on it and the whole move-in sequence
-- depends on that. Then the ones a person needs to be able to use the
-- machine at all, and the one that speaks before anything else works.
M.CARRIED = {}

-- {{{ storage
M.CARRIED.storage = {
  class = "storage",
  identifies = { class_code = 0x01, subclass = 0x06, interface = 0x01,
                 note = "mass storage, serial ATA, in the standard "
                     .. "host-controller arrangement" },
  source = "the AHCI specification, revision 1.3.1, transcribed 2026-08",
  revisions = { from = 0, to = 0xff,
                note = "the standard arrangement does not vary by revision "
                    .. "in what is used here" },
  registers = {
    { offset = 0x00, width = 4, read_only = true, name = "capabilities",
      bits = { [31] = "64-bit addressing", [30] = "native command queueing",
               [5] = "supports only a single port" } },
    { offset = 0x04, width = 4, name = "global control",
      bits = { [31] = "this controller owns the ports", [0] = "reset, self-clearing" } },
    { offset = 0x08, width = 4, name = "interrupt status",
      bits = { note = "one bit per port; write the bit back to acknowledge" } },
    { offset = 0x0c, width = 4, read_only = true, name = "ports present",
      bits = { note = "one bit per port that exists" } },
  },
  start = {
    { do_what = "set the reset bit in global control" },
    { wait = "until it clears itself, up to one second",
      why = "the controller clears it when the reset finishes, and reading "
         .. "before then reads a controller that is not there yet" },
    { do_what = "set the bit that says this controller owns its ports" },
    { do_what = "read ports present, and for each port that exists, give it "
             .. "a command list and a place to receive" },
    { wait = "at least 500 milliseconds after starting a port",
      why = "a drive that was spun down needs the time, and asking sooner "
         .. "gets a refusal that looks like a broken drive" },
  },
  rings = {
    note = "a command list of 32 slots per port; each slot points at a table "
        .. "holding the command and a scatter list of where the data goes",
    slot_bytes = 32, table_bytes = 128,
  },
  interrupts = {
    raised_by = "a command finishing, or a port changing state",
    read = "the port's own interrupt status register to find out which",
    acknowledge = "write the same bits back to the same register",
  },
  errata = {
    "Some controllers report more ports present than are wired. A port whose "
      .. "status never leaves its initial value after the wait is not there.",
    "Reading the capabilities register before the reset finishes returns "
      .. "zeros on several parts, which reads as a controller with no "
      .. "features rather than as an error.",
  },
  destroying = {},
}
-- }}}

-- {{{ serial
M.CARRIED.serial = {
  class = "serial",
  identifies = { note = "the 16550 arrangement, at a base address the board "
                     .. "description gives; it does not announce itself" },
  source = "the 16550 datasheet, transcribed 2026-08",
  revisions = { from = 0, to = 0xff },
  registers = {
    { offset = 0, width = 1, name = "data",
      bits = { note = "written, a byte leaves on the wire; read, a byte "
                   .. "that arrived" } },
    { offset = 3, width = 1, name = "line control",
      bits = { [7] = "the next two registers are the speed divisor instead",
               [1] = "eight bits per character", [0] = "eight bits per character" } },
    { offset = 5, width = 1, read_only = true, name = "line status",
      bits = { [5] = "the transmitter is empty and will take another byte",
               [0] = "a byte has arrived" } },
  },
  start = {
    { do_what = "set the divisor bit in line control" },
    { do_what = "write the speed divisor to offsets 0 and 1" },
    { do_what = "clear the divisor bit, and set eight bits, no parity, one stop" },
  },
  rings = { note = "none. One byte at a time, both directions." },
  interrupts = { raised_by = "a byte arriving, if enabled",
                 read = "offset 2", acknowledge = "reading it is the acknowledgement" },
  errata = {
    "Do not buffer what is written. Buffering loses exactly the last thing "
      .. "said, which is what anybody reads after a crash.",
  },
  destroying = {},
}
-- }}}

-- {{{ keyboard
M.CARRIED.keyboard = {
  class = "keyboard",
  identifies = { note = "the standard controller at ports 0x60 and 0x64 on "
                     .. "machines that have one" },
  source = "the standard keyboard controller documentation, transcribed 2026-08",
  revisions = { from = 0, to = 0xff },
  registers = {
    { offset = 0x60, width = 1, name = "data",
      bits = { note = "the scan code of what happened" } },
    { offset = 0x64, width = 1, read_only = true, name = "status",
      bits = { [0] = "there is something to read",
               [1] = "the controller is not ready to be written to" } },
  },
  start = {
    { do_what = "read the data port until the status says nothing is waiting",
      why = "whatever was pressed before the machine started is still queued" },
  },
  rings = { note = "none" },
  interrupts = { raised_by = "a key changing state", read = "the data port",
                 acknowledge = "reading the data port" },
  errata = {
    "A scan code is not a character. The translation depends on a layout "
      .. "nobody can derive from the hardware.",
    "Some machines emulate this controller over a different bus entirely, "
      .. "and the emulation stops the moment that bus is initialised.",
  },
  destroying = {},
}
-- }}}

-- {{{ display
M.CARRIED.display = {
  class = "display",
  identifies = { note = "whatever the firmware handed over: an address, a "
                     .. "geometry, a pixel format, and a row stride" },
  source = "the firmware's own handover, which is not a transcription and "
        .. "cannot rot",
  revisions = { from = 0, to = 0xff },
  registers = {
    { offset = 0, width = 4, name = "the pixels themselves",
      bits = { note = "not registers. Memory. Writing changes what is shown." } },
  },
  start = { { do_what = "nothing. The firmware already did it." } },
  rings = { note = "none" },
  interrupts = { raised_by = "nothing that matters for drawing" },
  errata = {
    "The pixels per row is not the width. It is usually larger, because rows "
      .. "are padded, and assuming otherwise produces a picture that shears "
      .. "diagonally -- which looks like a broken drawing routine and is a "
      .. "misread structure.",
    "This exists only where the firmware is UEFI. A machine started any other "
      .. "way has no display until a driver, an enumeration and a command "
      .. "queue exist.",
  },
  destroying = {},
}
-- }}}
-- }}}

-- {{{ M.confirm(description, device, read)
-- The read-only protocol. Returns true, or nil and everything that did not
-- match -- everything rather than the first, because a person or a machine
-- deciding whether this is the right document wants the whole disagreement.
function M.confirm(description, device, read)
  local wrong = {}

  -- {{{ the maker and the part
  local marks = description.identifies
  for _, field in ipairs({ "vendor", "part", "class_code", "subclass", "interface" }) do
    if marks[field] ~= nil and device[field] ~= nil and marks[field] ~= device[field] then
      wrong[#wrong + 1] = string.format("%s is 0x%x and the description says 0x%x",
                                        field, device[field], marks[field])
    end
  end
  -- }}}

  -- {{{ the revision, against the range this description covers
  if device.revision and description.revisions then
    local from = description.revisions.from or 0
    local to = description.revisions.to or 0xff
    if device.revision < from or device.revision > to then
      wrong[#wrong + 1] = string.format("this part is revision 0x%x and the "
        .. "description covers 0x%x to 0x%x", device.revision, from, to)
    end
  end
  -- }}}

  -- {{{ what the read-only registers actually say
  -- The only part that touches the device, and it only reads.
  for _, register in ipairs(description.registers or {}) do
    if register.read_only and register.expect ~= nil then
      local found = read(device, register.offset, register.width)
      if found ~= register.expect then
        wrong[#wrong + 1] = string.format("%s at 0x%x reads 0x%x and the "
          .. "description predicts 0x%x", register.name, register.offset,
          found or 0, register.expect)
      end
    end
  end
  -- }}}

  if #wrong > 0 then
    -- A partial match is a failure. Enough agreement to feel confirmed with
    -- one silent disagreement in the register that matters is the dangerous
    -- case, not the safe one.
    return nil, "this description is not about this part:\n  "
      .. table.concat(wrong, "\n  ")
  end
  return true
end
-- }}}

-- {{{ M.as_text(description)
-- A description the machine can read. Everything, in the order a driver
-- would be written in.
function M.as_text(description)
  local lines = {
    "device class: " .. description.class,
    "transcribed from: " .. description.source,
    "",
    "what marks a device as one of these:",
  }
  for key, value in pairs(description.identifies) do
    lines[#lines + 1] = "  " .. key .. ": " .. tostring(value)
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "registers:"
  for _, register in ipairs(description.registers or {}) do
    lines[#lines + 1] = string.format("  0x%x  %d bytes  %s%s",
      register.offset, register.width, register.name,
      register.read_only and "  (read only)" or "")
    for bit, meaning in pairs(register.bits or {}) do
      if bit == "note" then
        lines[#lines + 1] = "        " .. meaning
      else
        lines[#lines + 1] = string.format("        bit %s: %s", bit, meaning)
      end
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "to start it:"
  for index, step in ipairs(description.start or {}) do
    if step.do_what then
      lines[#lines + 1] = "  " .. index .. ". " .. step.do_what
    end
    if step.wait then
      lines[#lines + 1] = "  " .. index .. ". WAIT " .. step.wait
      if step.why then lines[#lines + 1] = "        because " .. step.why end
    elseif step.why then
      lines[#lines + 1] = "        because " .. step.why
    end
  end

  if description.rings and description.rings.note then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "how data moves: " .. description.rings.note
  end

  if description.interrupts and description.interrupts.raised_by then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "interrupts:"
    lines[#lines + 1] = "  raised by " .. description.interrupts.raised_by
    if description.interrupts.read then
      lines[#lines + 1] = "  read " .. description.interrupts.read
    end
    if description.interrupts.acknowledge then
      lines[#lines + 1] = "  acknowledge by " .. description.interrupts.acknowledge
    end
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "what is wrong with it -- none of this is discoverable "
    .. "by probing:"
  if #(description.errata or {}) == 0 then
    lines[#lines + 1] = "  nothing known"
  end
  for _, entry in ipairs(description.errata or {}) do
    lines[#lines + 1] = "  - " .. entry
  end

  return table.concat(lines, "\n")
end
-- }}}

-- {{{ M.offer(catalogue, hands, read)
-- The whole set, readable rather than compiled in -- so the machine can
-- extend it when it works out a new device.
function M.offer(catalogue, hands, read)
  hands.offer(catalogue, {
    name = "descriptions", takes = {},
    gives = "which device kinds this machine carries documents for",
    does = function()
      local lines = { "documents carried on this chip:" }
      for name, description in pairs(M.CARRIED) do
        lines[#lines + 1] = "  " .. name .. "  -- from " .. description.source
      end
      lines[#lines + 1] = ""
      lines[#lines + 1] = "Ask <call describe NAME> for one of them. Anything "
        .. "not here you work out yourself, carefully."
      return table.concat(lines, "\n")
    end,
  })

  hands.offer(catalogue, {
    name = "describe", takes = { "class" }, gives = "the whole document",
    does = function(arguments)
      local description = M.CARRIED[arguments[1]]
      if not description then
        return nil, "nothing is carried about '" .. tostring(arguments[1]) .. "'"
      end
      return M.as_text(description)
    end,
  })
end
-- }}}

return M
