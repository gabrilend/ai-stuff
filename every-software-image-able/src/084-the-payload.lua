-- 084-the-payload.lua
--
-- What is said at once, and what is fetched. The instruction, the patterns
-- and the descriptions together are far larger than anything the machine can
-- hold in one thought, so this decides what it wakes up holding and makes
-- everything else reachable when it becomes relevant. Issue 304.
--
-- For a general: the machine boots holding a page, not a library. The
-- library is there, indexed, and it can ask for any of it -- and what it
-- asked for costs room, which it can see, so what it is thinking with is a
-- decision it keeps making rather than a rule applied to it.
--
-- THE BOOT SET IS A MUTABLE FILE. The machine can change what it wakes up
-- believing, including the prohibition, which is an atom like everything
-- else. That follows from everything about the machine being mutable, and it
-- is implemented rather than quietly prevented. docs/013 names it as
-- something nobody has decided is correct; it is still what the design
-- implies, and preventing it would be a different design.
--
-- EVERY ATOM SAYS WHERE IT CAME FROM. Carried on the chip, written by the
-- machine, or arrived on a channel. That distinction matters the first time
-- a carried description turns out to be wrong, and by then it is too late to
-- start recording it.
--
-- THE DISK HALF OF THE ATOM OPERATIONS LIVES HERE, because phase 1 had no
-- storage and this phase does. An atom written out is not gone; it is on a
-- lower rung and can be fetched.

local M = {}

-- {{{ M.CHIP -- what every image carries, as atoms
--
-- Ordered, because the order is what the boot set is chosen from and a set
-- that varied between builds would make two images differ in what they woke
-- up believing without anybody deciding that.
function M.build(options)
  local instruction = options.instruction
  local patterns = options.patterns
  local descriptions = options.descriptions

  -- WHICH PROCESSOR THIS CARD IS FOR, and it is required rather than
  -- defaulted. One of the patterns -- the calling convention -- is different
  -- on every machine, and it is the one pattern that is an agreement rather
  -- than a suggestion. Handing a machine somebody else's is an instruction
  -- to write routines that return to addresses that were never return
  -- addresses, on a machine with nothing above it to notice.
  --
  -- It carried the first architecture's registers to all three for as long
  -- as there were three, because it was written when there was one.
  local architecture = options.architecture
  if not architecture then
    error("084-the-payload: no architecture was given, and the patterns "
          .. "cannot be written without one -- the calling convention is "
          .. "different on every machine and there is no general form of it.")
  end

  local atoms = {}
  local function carry(topic, content, resident)
    atoms[#atoms + 1] = {
      topic = topic, content = content,
      origin = "carried on the chip",
      resident = resident or false,
      -- a rough count: what matters is that room is a real cost the machine
      -- can see, and the real number arrives when a tokenizer is attached.
      tokens = math.ceil(#content / 4),
    }
  end

  -- {{{ the instruction, split so the boot set can be chosen finely
  --
  -- One atom would mean waking up holding all of it or none of it. Split at
  -- its own headings, the parts that cannot be left behind can be resident
  -- while the rest is fetched -- which is the entire point of this ticket.
  local sections = {}
  local current = { title = "what you are", lines = {} }
  for line in (instruction .. "\n"):gmatch("(.-)\n") do
    local heading = line:match("^## (.+)$")
    if heading then
      sections[#sections + 1] = current
      current = { title = heading, lines = {} }
    else
      current.lines[#current.lines + 1] = line
    end
  end
  sections[#sections + 1] = current

  -- Which sections the machine wakes up holding: the order that cannot be
  -- rearranged, the one prohibition, what to do when stuck, the rules about
  -- other people's property, and how to ask for anything else.
  --
  -- Changed 2026-08-21. There used to be two prohibitions and the second one
  -- (never write your own weights) is gone -- it is advice now, fetchable
  -- rather than carried, because the only things worth restricting are the
  -- ones that damage hardware. Being stuck and other people's disks joined the
  -- boot set the same day: both are things a machine can meet before it has
  -- any way to ask about them.
  -- Everything beyond those competes with the machine's actual work for room.
  local RESIDENT = {
    ["what you are"] = true,
    ["What to do, in an order that cannot be rearranged"] = true,
    ["The one prohibition"] = true,
    ["When you get stuck"] = true,
    ["About other people's things"] = true,
    ["What you are for"] = true,
    ["About this text"] = true,
    ["Some things worth knowing"] = true,
  }

  for _, section in ipairs(sections) do
    local body = table.concat(section.lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    if #body > 0 then
      carry("the instruction: " .. section.title,
            "## " .. section.title .. "\n\n" .. body,
            RESIDENT[section.title] or false)
    end
  end
  -- }}}

  -- {{{ the patterns, one atom each, none resident
  -- A pattern is relevant when the machine is about to build something of
  -- that shape, which is not at boot.
  for _, name in ipairs(patterns.names()) do
    carry("pattern: " .. name, patterns.as_text(name, architecture), false)
  end
  -- }}}

  -- {{{ the descriptions, one atom each, none resident
  for name, description in pairs(descriptions.CARRIED) do
    carry("device: " .. name, descriptions.as_text(description), false)
  end
  -- }}}

  return atoms
end
-- }}}

-- {{{ M.new(options)
--
-- options: context (the atom context, 052), atoms (from build), store and
-- keep (076) for the disk half, extent (which blocks the atoms may use)
function M.new(options)
  local payload = {
    context = options.context,
    atoms = options.context_module,
    store = options.store,
    keep = options.keep,
    on = options.on,
    extent = options.extent or { at = 2000, blocks = 512 },
    catalogue = {},        -- topic -> the carried text, whether resident or not
    numbers = {},          -- topic -> its number in the context
    written_out = {},      -- topic -> where on disk
    fetches = 0,
  }

  for _, atom in ipairs(options.atoms or {}) do
    payload.catalogue[atom.topic] = atom
    if atom.resident then
      payload.numbers[atom.topic] = options.context_module.add(options.context, {
        topic = atom.topic, content = atom.content,
        tokens = atom.tokens, origin = atom.origin,
      })
    end
  end

  return payload
end
-- }}}

-- {{{ M.index(payload)
-- What exists, whether or not it is being held. The machine should be able
-- to ask what it is carrying rather than being expected to remember.
function M.index(payload)
  local out = {}
  for topic, atom in pairs(payload.catalogue) do
    out[#out + 1] = {
      topic = topic,
      -- being held NOW, which is not the same as being in the boot set --
      -- see boot_set below.
      resident = payload.numbers[topic] ~= nil,
      wakes_with = atom.resident or false,
      stored = payload.written_out[topic] ~= nil,
      tokens = atom.tokens,
      origin = atom.origin,
    }
  end
  table.sort(out, function(a, b) return a.topic < b.topic end)
  return out
end
-- }}}

-- {{{ M.fetch(payload, topic)
-- Bring something in. Costs room, which the machine can see afterwards --
-- that is what makes what it is thinking with a decision rather than a rule.
function M.fetch(payload, topic)
  if payload.numbers[topic] then
    return nil, "'" .. topic .. "' is already being held"
  end

  local atom = payload.catalogue[topic]
  if not atom then
    return nil, "nothing here is called '" .. topic .. "'. Ask what is "
      .. "carried and you will get the list."
  end

  -- if it was written out rather than carried, read it back from where it
  -- went -- an atom on a lower rung is not gone.
  local content = atom.content
  if payload.written_out[topic] and payload.store then
    local text = payload.keep.read(payload.store, payload.on,
                                   payload.written_out[topic], atom.blocks or 1)
    if text then content = (text:gsub("%z+$", "")) end
  end

  payload.fetches = payload.fetches + 1
  payload.numbers[topic] = payload.atoms.add(payload.context, {
    topic = topic, content = content, tokens = atom.tokens,
    origin = atom.origin,
  })
  return payload.numbers[topic]
end
-- }}}

-- {{{ M.write_out(payload, topic)
-- The disk half that 105 had to leave as a seam. An atom goes to storage and
-- stops taking room, and can be fetched again -- which is what makes
-- dropping it a choice rather than a loss.
function M.write_out(payload, topic)
  if not payload.store or not payload.on then
    return nil, "there is nowhere to write an atom out to"
  end
  local number = payload.numbers[topic]
  if not number then
    return nil, "'" .. tostring(topic) .. "' is not being held, so there is "
      .. "nothing to write out"
  end

  local atom = payload.context.atoms[number]
  local block_bytes = 512
  local text = atom.content
  local blocks = math.ceil(#text / block_bytes)
  local padded = text .. string.rep("\0", blocks * block_bytes - #text)

  local used = 0
  for _, where in pairs(payload.written_out) do used = math.max(used, where) end
  local at = math.max(payload.extent.at, used + 1)

  local ok, why = payload.keep.write(payload.store, payload.on, at, padded)
  if not ok then return nil, "could not write it out: " .. tostring(why) end

  payload.written_out[topic] = at
  payload.catalogue[topic] = payload.catalogue[topic] or {
    topic = topic, content = text, tokens = atom.tokens, origin = atom.origin,
  }
  payload.catalogue[topic].blocks = blocks

  payload.atoms.drop(payload.context, number)
  payload.numbers[topic] = nil
  payload.context.written = payload.context.written + 1
  return at
end
-- }}}

-- {{{ M.boot_set(payload)
-- Which atoms the NEXT start wakes holding, as a file the machine can read
-- and change. Being able to change it is being able to change what the next
-- start believes, including the prohibitions -- which is uncomfortable and
-- is the design.
--
-- WHAT THIS IS AND IS NOT. Two different things were briefly one here: what
-- the machine is holding right now, and what the next start will hold. They
-- move independently -- fetching something does not make the next start wake
-- with it, and dropping the prohibitions from this file does not remove them
-- from the thought in progress. Reading the file from what happened to be
-- held made the second unchangeable, which quietly turned the design's most
-- uncomfortable property into a thing the machine could not do.
function M.boot_set(payload)
  local lines = {}
  for topic, atom in pairs(payload.catalogue) do
    if atom.resident then lines[#lines + 1] = topic end
  end
  table.sort(lines)
  return table.concat(lines, "\n")
end
-- }}}

-- {{{ M.set_boot_set(payload, text)
-- Rewriting it. Refuses only topics that do not exist -- never a topic
-- somebody would rather stayed.
function M.set_boot_set(payload, text)
  local wanted, unknown = {}, {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local topic = line:gsub("^%s+", ""):gsub("%s+$", "")
    if #topic > 0 then
      if payload.catalogue[topic] then wanted[topic] = true
      else unknown[#unknown + 1] = topic end
    end
  end
  if #unknown > 0 then
    return nil, "nothing here is called: " .. table.concat(unknown, ", ")
  end

  for topic in pairs(payload.catalogue) do
    payload.catalogue[topic].resident = wanted[topic] or false
  end
  return true
end
-- }}}

-- {{{ M.offer(catalogue, hands, payload)
function M.offer(catalogue, hands, payload)
  hands.offer(catalogue, {
    name = "carried", takes = {}, gives = "everything there is, held or not",
    note = "what this machine is carrying, and what it is holding right now",
    does = function()
      local lines = { "what this machine carries:" }
      for _, entry in ipairs(M.index(payload)) do
        lines[#lines + 1] = string.format("  %-46s %s%s  ~%d",
          entry.topic,
          entry.resident and "held" or "not held",
          entry.stored and ", written out" or "",
          entry.tokens)
      end
      lines[#lines + 1] = ""
      lines[#lines + 1] = "Ask <call fetch TOPIC> for any of it. What you fetch "
        .. "takes room, and <call room> says how much is left."
      return table.concat(lines, "\n")
    end,
  })

  hands.offer(catalogue, {
    name = "fetch", takes = { "topic" }, gives = "whether it is now held",
    does = function(arguments)
      local number, why = M.fetch(payload, arguments[1])
      if not number then return nil, why end
      return "now holding '" .. arguments[1] .. "'; "
        .. payload.atoms.room_left(payload.context) .. " room left"
    end,
  })

  hands.offer(catalogue, {
    name = "put_away", takes = { "topic" }, gives = "where it went",
    note = "writes something out to storage; it can be fetched again",
    does = function(arguments)
      local at, why = M.write_out(payload, arguments[1])
      if not at then return nil, why end
      return "'" .. arguments[1] .. "' is at block " .. at .. " now, and out "
        .. "of the way. " .. payload.atoms.room_left(payload.context)
        .. " room left."
    end,
  })

  hands.offer(catalogue, {
    name = "room", takes = {}, gives = "how much room is left",
    does = function()
      return payload.atoms.room_left(payload.context) .. " of "
        .. payload.context.budget .. ", and "
        .. #payload.context.order .. " things being held"
    end,
  })

  hands.offer(catalogue, {
    name = "what_i_wake_with", takes = {},
    gives = "the list the next start reads",
    note = "this file is yours to change, and the next start believes it",
    does = function() return M.boot_set(payload) end,
  })

  hands.offer(catalogue, {
    name = "wake_with", takes = { "topics" },
    gives = "whether it was changed",
    note = "rewrites what the next start wakes up holding",
    does = function(arguments)
      local ok, why = M.set_boot_set(payload, (arguments[1]:gsub(",", "\n")))
      if not ok then return nil, why end
      return "the next start will wake holding what you said"
    end,
  })
end
-- }}}

return M
