-- 094-watch-what-it-wrote.lua
--
-- Stepping through code nobody wrote by hand. Issue 703.
--
-- For a general: the code under inspection was produced at runtime by the
-- model. There is no file, no symbols, no names -- so a debugger attached to
-- the machine sees an address and can say nothing about what that address
-- means. This is what turns "you are at 0x41f0" into "you are at instruction
-- eleven of the thing it called the allocator."
--
-- THE NAMING PROBLEM IS THE WHOLE TICKET. Attaching a debugger is
-- configuration; the trap runner (021) already does it. What is hard is that
-- there is nothing to load symbols from, and what exists instead is the
-- pairing 204 keeps -- the text the model wrote beside the bytes it became.
--
-- WHICH PUTS A REQUIREMENT BACK ON 204, and it is met here rather than
-- assumed: the machine's own bookkeeping has to be READABLE FROM OUTSIDE. A
-- debugger sees raw guest memory, so the layout of the structure pairing
-- text with bytes is part of a contract with a tool that lives outside the
-- machine, even though nothing inside the machine needs it to be. That
-- layout is declared here, once, as data -- the same rule as every other
-- layout in this project.

local M = {}

-- {{{ M.LEDGER_SLOTS -- how the pairing looks in guest memory
--
-- Written down because a tool outside the machine has to find it. Every
-- field is eight bytes so the arithmetic outside is a multiplication rather
-- than a table of offsets somebody has to keep in step.
--
-- WHY A MAGIC NUMBER FIRST. A debugger scanning guest memory for this has
-- nothing else to recognise it by -- there is no symbol table saying "the
-- ledger is here". So the machine writes a number nothing else would
-- plausibly be, and the tool looks for it.
M.MAGIC = 0x4c454447          -- "LEDG"

M.LEDGER_SLOTS = {
  { name = "magic",       why = "what a tool outside scans for" },
  { name = "count",       why = "how many programs are recorded" },
  { name = "stride",      why = "bytes per record, so a tool can walk them "
                              .. "without knowing this file's version" },
  { name = "first",       why = "where the records begin" },
}

M.RECORD_SLOTS = {
  { name = "at",          why = "where the program was placed" },
  { name = "bytes",       why = "how long it is" },
  { name = "name_at",     why = "where its name is, as bytes" },
  { name = "name_bytes",  why = "how long the name is" },
  { name = "text_at",     why = "where the text it was made from is" },
  { name = "text_bytes",  why = "how long that text is" },
}
-- }}}

-- {{{ M.offsets(slots)
function M.offsets(slots)
  local at, out = 0, {}
  for _, slot in ipairs(slots) do
    out[slot.name] = at
    at = at + 8
  end
  return out, at
end
-- }}}

-- {{{ M.lay_out(runner, at, write)
-- Writes the ledger into guest memory, so a tool outside can find it. This
-- is the machine publishing its own bookkeeping -- nothing inside needs it
-- in this shape, and that is exactly why it has to be written down.
function M.lay_out(runner, at, write)
  local ledger, ledger_bytes = M.offsets(M.LEDGER_SLOTS)
  local record, record_bytes = M.offsets(M.RECORD_SLOTS)

  local first = at + ledger_bytes
  local strings_at = first + record_bytes * #runner.placed

  write(at + ledger.magic, M.MAGIC)
  write(at + ledger.count, #runner.placed)
  write(at + ledger.stride, record_bytes)
  write(at + ledger.first, first)

  local strings = {}
  local cursor = strings_at
  for index, entry in ipairs(runner.placed) do
    local base = first + record_bytes * (index - 1)
    write(base + record.at, entry.at)
    write(base + record.bytes, entry.bytes)

    write(base + record.name_at, cursor)
    write(base + record.name_bytes, #entry.name)
    strings[#strings + 1] = { at = cursor, text = entry.name }
    cursor = cursor + #entry.name

    write(base + record.text_at, cursor)
    write(base + record.text_bytes, #entry.text)
    strings[#strings + 1] = { at = cursor, text = entry.text }
    cursor = cursor + #entry.text
  end

  return { at = at, strings = strings, ends_at = cursor }
end
-- }}}

-- {{{ M.find_ledger(read, from, to)
-- What a tool outside does: scan guest memory for the magic number, because
-- there is no symbol table to ask.
function M.find_ledger(read, from, to)
  for at = from, to, 8 do
    if read(at) == M.MAGIC then return at end
  end
  return nil, "nothing in that range of memory looks like the machine's own "
    .. "record of what it built. Either it has built nothing yet, or the "
    .. "record is somewhere else."
end
-- }}}

-- {{{ M.read_ledger(read, read_string, at)
function M.read_ledger(read, read_string, at)
  local ledger = M.offsets(M.LEDGER_SLOTS)
  local record, record_bytes = M.offsets(M.RECORD_SLOTS)

  if read(at + ledger.magic) ~= M.MAGIC then
    return nil, "there is no record at that address"
  end

  local count = read(at + ledger.count)
  local stride = read(at + ledger.stride)
  local first = read(at + ledger.first)

  -- The stride is READ rather than assumed, which is the point of writing it
  -- down: a machine that has grown and changed its own bookkeeping can still
  -- be walked by a tool built before it changed.
  local out = {}
  for index = 0, count - 1 do
    local base = first + stride * index
    out[#out + 1] = {
      at = read(base + record.at),
      bytes = read(base + record.bytes),
      name = read_string(read(base + record.name_at),
                         read(base + record.name_bytes)),
      text = read_string(read(base + record.text_at),
                         read(base + record.text_bytes)),
    }
  end
  return out
end
-- }}}

-- {{{ M.where_am_i(ledger, address)
-- The answer this whole ticket exists for: turning an address into a place
-- inside something the machine wrote, by name and by instruction.
function M.where_am_i(ledger, address)
  for _, entry in ipairs(ledger) do
    if address >= entry.at and address < entry.at + entry.bytes then
      local into = address - entry.at
      return {
        name = entry.name,
        at = address,
        into = into,
        of = entry.bytes,
        text = entry.text,
        -- The line of the text this is nearest to cannot be derived from the
        -- bytes alone -- an assembler that emitted one instruction per line
        -- would make it easy and this one inserts loop watches, so the count
        -- drifts. Said plainly rather than guessed at.
        line = nil,
      }
    end
  end
  return nil, string.format("0x%x is not inside anything this machine built. "
    .. "It is the engine, the firmware, or nowhere.", address)
end
-- }}}

-- {{{ M.break_when_it_runs(runner)
-- Where to stop: the moment the machine hands control to something it just
-- wrote. Those are exactly the addresses in the ledger, so the answer is the
-- ledger and this says so rather than making a second list.
function M.break_when_it_runs(ledger)
  local out = {}
  for _, entry in ipairs(ledger) do
    out[#out + 1] = { at = entry.at, name = entry.name }
  end
  return out
end
-- }}}

return M
