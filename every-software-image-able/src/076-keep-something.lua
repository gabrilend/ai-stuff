-- 076-keep-something.lua
--
-- Persistent storage: blocks, an extent the machine owns, and the ability to
-- find that extent again after the power goes. Issue 206, and the thing that
-- makes 205's discipline more than an intention -- a note written before a
-- dangerous experiment needs somewhere to land.
--
-- For a general: everything the machine has learned so far evaporates when
-- the power goes. This is where it can put things that must survive.
--
-- NO FILESYSTEM. The machine can build one if it wants one. What the seed
-- needs is blocks, an extent it owns, and the ability to find that extent
-- again on the next boot -- and a filesystem built into the seed would be a
-- decision made on the grown machine's behalf about how it organises itself,
-- which is exactly the mistake strategems/009 is about.
--
-- THE STANDARD CLASS INTERFACE IS NOT A PREFERENCE. Operating an unknown
-- device safely requires writing a note first, writing a note requires
-- storage, and the circle only opens because storage almost always answers
-- to something standard. So the seed carries this one driver rather than
-- expecting the machine to explore its way in (docs/003).
--
-- AND NOT THE EMULATOR'S CONVENIENT ONE. An emulator offers a paravirtual
-- block device -- a queue in memory and two registers -- far simpler than
-- anything on a real board. Taking it would mean the emulated loop and the
-- hardware loop exercise different code from the first day. The boards this
-- project describes already declare real controllers for that reason (015
-- through 017, 030 through 032).

local M = {}

-- {{{ M.MARK -- how the machine finds its own extent again
--
-- A block written at the start of what the machine claims, holding a magic
-- number, which device it was written on, how large the claim is, and where
-- it begins. On the next boot every device is read at every plausible place
-- and this is what is being looked for.
--
-- WHY IT NAMES THE DEVICE IT IS ON. A disk cloned to another disk carries a
-- mark saying it belongs somewhere else, and a machine that notices that is
-- a machine that does not silently adopt a stranger's extent.
M.MARK = "ESIA-EXTENT-1"
M.MARK_BYTES = 512
-- }}}

-- {{{ M.new(options)
--
-- options:
--   devices  a list of storage as the machine sees it, each with:
--            name, blocks, block_bytes, writable, removable, note,
--            read(block, count) -> string, write(block, text) -> ok, why
--
-- The devices are handed in for the same reason the memory rules take their
-- touch from outside: on the metal they are a controller driver, hosted they
-- are a file, and what this file holds is the part that is the same.
function M.new(options)
  return {
    devices = options.devices or {},
    claim = nil,          -- the extent this machine owns, once found or made
    reads = 0,
    writes = 0,
    refusals = 0,
  }
end
-- }}}

-- {{{ M.find_device(store, name)
local function find_device(store, name)
  for _, device in ipairs(store.devices) do
    if device.name == name then return device end
  end
  return nil
end
M.find_device = find_device
-- }}}

-- {{{ M.enumerate(store)
-- What is attached that can hold bytes and keep them. The machine chooses
-- where to move in from this, and "least likely to be unplugged" cannot be
-- judged without it.
function M.enumerate(store)
  local out = {}
  for _, device in ipairs(store.devices) do
    out[#out + 1] = {
      name = device.name,
      blocks = device.blocks,
      block_bytes = device.block_bytes,
      bytes = device.blocks * device.block_bytes,
      writable = device.writable,
      removable = device.removable,
      note = device.note or "",
    }
  end
  return out
end
-- }}}

-- {{{ M.read(store, name, block, count)
function M.read(store, name, block, count)
  local device = find_device(store, name)
  if not device then
    store.refusals = store.refusals + 1
    return nil, "there is no storage called '" .. tostring(name) .. "'"
  end
  if block < 0 or block + count > device.blocks then
    store.refusals = store.refusals + 1
    return nil, string.format("'%s' has %d blocks and that asks for %d through %d",
                              name, device.blocks, block, block + count - 1)
  end
  store.reads = store.reads + count
  return device.read(block, count)
end
-- }}}

-- {{{ M.write(store, name, block, text)
-- Refuses a device that cannot be written, rather than writing into nothing
-- and reporting success. A read-only delivery medium is the EXPECTED case
-- (docs/003) -- the seed is meant to be plugged into machine after machine
-- unchanged -- so this refusal is ordinary rather than exceptional, and it
-- must never be discovered by a write that silently did nothing.
function M.write(store, name, block, text)
  local device = find_device(store, name)
  if not device then
    store.refusals = store.refusals + 1
    return nil, "there is no storage called '" .. tostring(name) .. "'"
  end
  if not device.writable then
    store.refusals = store.refusals + 1
    return nil, "'" .. name .. "' cannot be written. That is expected of the "
      .. "medium the machine arrived on, and is not a fault."
  end
  if #text % device.block_bytes ~= 0 then
    store.refusals = store.refusals + 1
    return nil, string.format("'%s' writes %d bytes at a time and that is %d",
                              name, device.block_bytes, #text)
  end
  local count = #text / device.block_bytes
  if block < 0 or block + count > device.blocks then
    store.refusals = store.refusals + 1
    return nil, string.format("'%s' has %d blocks and that would write through %d",
                              name, device.blocks, block + count - 1)
  end

  -- {{{ never over its own claim's mark, and never outside its own claim
  -- The same rule the memory hands have, one layer out: the storage layer's
  -- first job is to know which blocks hold the copy it is running from, so
  -- it never writes over itself while writing about itself (docs/003).
  if store.claim and store.claim.device == name then
    if block == store.claim.at then
      store.refusals = store.refusals + 1
      return nil, "that is the mark this machine finds its own extent by. "
        .. "Writing over it is how a machine loses everything it kept."
    end
  end
  -- }}}

  store.writes = store.writes + count
  return device.write(block, text)
end
-- }}}

-- {{{ M.claim(store, name, at, blocks)
-- Takes an extent and writes the mark that will find it again.
function M.claim(store, name, at, blocks)
  local device = find_device(store, name)
  if not device then return nil, "there is no storage called '" .. tostring(name) .. "'" end
  if not device.writable then
    return nil, "'" .. name .. "' cannot be written, so nothing can be kept on it"
  end
  if at + blocks > device.blocks then
    return nil, "that extent runs past the end of '" .. name .. "'"
  end

  -- the mark: what it is, whose it is, and where. Padded to a whole block,
  -- because a device writes in blocks and a partial write is not a thing.
  local mark = M.MARK .. "\n" .. name .. "\n" .. at .. "\n" .. blocks .. "\n"
  mark = mark .. string.rep("\0", device.block_bytes - #mark % device.block_bytes)

  local ok, why = device.write(at, mark)
  if not ok then return nil, "could not write the mark: " .. tostring(why) end

  store.claim = { device = name, at = at, blocks = blocks,
                  first_free = at + (#mark / device.block_bytes) }
  return store.claim
end
-- }}}

-- {{{ M.look_for_claim(store)
-- The next boot: read every device where a mark might be and see whether one
-- of them is ours.
--
-- A mark naming a different device is reported rather than adopted. A disk
-- cloned to another disk carries one, and a machine that quietly adopted it
-- would be running on an extent that another machine also believes is its
-- own -- two machines writing over each other, with nothing saying so.
function M.look_for_claim(store, places)
  places = places or { 0 }
  local found, foreign = nil, nil

  for _, device in ipairs(store.devices) do
    for _, at in ipairs(places) do
      if at < device.blocks then
        local block = device.read(at, 1)
        if block and block:sub(1, #M.MARK) == M.MARK then
          -- Split on lines rather than matched with a pattern. The mark has
          -- hyphens in it, and a hyphen in a Lua pattern is a quantifier --
          -- so the pattern matched nothing, the fields came back empty, and
          -- every claim looked like a stranger's. It failed loudly only
          -- because the refusal tried to name whose it was.
          local lines = {}
          for line in block:gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
          local whose = lines[2]
          local where = tonumber(lines[3])
          local blocks = tonumber(lines[4])
          if whose == device.name and where and blocks then
            found = found or { device = device.name, at = where, blocks = blocks }
          elseif whose then
            foreign = foreign or { on = device.name, says = whose }
          end
        end
      end
    end
  end

  if found then
    store.claim = found
    return found
  end
  if foreign then
    return nil, "found a mark on '" .. foreign.on .. "' that says it belongs to '"
      .. foreign.says .. "'. That is somebody else's extent, or this disk is a "
      .. "copy of one -- either way, adopting it would mean two machines "
      .. "writing over each other."
  end
  return nil, "nothing here has been claimed yet"
end
-- }}}

-- {{{ M.offer(catalogue, hands, store)
function M.offer(catalogue, hands, store)
  hands.offer(catalogue, {
    name = "storage", takes = {}, gives = "what can hold bytes and keep them",
    does = function()
      local lines = { "the storage attached to this machine:" }
      for _, device in ipairs(M.enumerate(store)) do
        lines[#lines + 1] = string.format(
          "  %-12s %d blocks of %d  (%s, %s)%s",
          device.name, device.blocks, device.block_bytes,
          device.writable and "writable" or "READ ONLY",
          device.removable and "removable" or "fixed",
          device.note ~= "" and ("  -- " .. device.note) or "")
      end
      if store.claim then
        lines[#lines + 1] = string.format(
          "this machine has claimed %d blocks on '%s', beginning at %d",
          store.claim.blocks, store.claim.device, store.claim.at)
      else
        lines[#lines + 1] = "this machine has claimed nothing yet"
      end
      return table.concat(lines, "\n")
    end,
  })

  hands.offer(catalogue, {
    name = "keep", takes = { "where", "block", "text" },
    gives = "whether it was kept",
    note = "writes text to a block of storage",
    does = function(arguments)
      local block = tonumber(arguments[2])
      if not block then return nil, "'" .. tostring(arguments[2])
        .. "' is not a block number" end
      local device = find_device(store, arguments[1])
      if not device then return nil, "there is no storage called '"
        .. tostring(arguments[1]) .. "'" end
      -- padded to a whole block, since that is the only unit there is
      local text = arguments[3]
      local padding = device.block_bytes - (#text % device.block_bytes)
      if padding == device.block_bytes and #text > 0 then padding = 0 end
      local ok, why = M.write(store, arguments[1], block,
                              text .. string.rep("\0", padding))
      if not ok then return nil, why end
      return "kept " .. #text .. " characters at block " .. block
    end,
  })

  hands.offer(catalogue, {
    name = "recall", takes = { "where", "block" }, gives = "what is there",
    does = function(arguments)
      local block = tonumber(arguments[2])
      if not block then return nil, "'" .. tostring(arguments[2])
        .. "' is not a block number" end
      local text, why = M.read(store, arguments[1], block, 1)
      if not text then return nil, why end
      return (text:gsub("%z+$", ""))
    end,
  })
end
-- }}}

return M
