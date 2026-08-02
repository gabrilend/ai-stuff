-- 073-the-assembler.lua
--
-- The seed's own assembler: text the machine wrote, into instructions the
-- machine can run. Issue 204, and the hand the whole project rests on -- the
-- allocator, the interpreter, every driver and every program the machine
-- ever has are downstream of this one.
--
-- For a general: the machine writes assembly the way a person would, and
-- this turns it into the numbers a processor executes. It also quietly adds
-- one thing the machine did not write: a report at the bottom of every loop,
-- so a program that would run forever can be noticed and stopped.
--
-- WHY AN ASSEMBLER RATHER THAN RAW BYTES. Both were on the table. Direct
-- emission is less to build and asks the model to be exact about instruction
-- encoding, which is where it is least reliable; an assembler is more
-- software on the chip and makes everything after it easier to write and to
-- read back. The deciding argument is the escape below: the assembler is
-- OURS, so it can insert the status emission at every loop back-edge rather
-- than relying on the model to remember. A model that has to remember will
-- forget, and the first forgetting ends the machine.
--
-- THE BACK-EDGE IS THE WHOLE TRICK. A jump backwards is a loop; there is no
-- other way to make one. So every backward jump gets a few instructions
-- before it that push the machine-wide magnitude away from fifty, and
-- crossing a threshold is where control gets taken (docs/006). It costs a
-- handful of instructions per iteration rather than a timer, an interrupt
-- table and a handler -- none of which exist on a machine with nothing
-- underneath it.
--
-- TWO HOLES, NAMED RATHER THAN DISCOVERED. Code that did not come through
-- this assembler -- raw bytes, or a jump into the middle of something --
-- escapes the emission entirely. And a loop built out of something this
-- assembler does not recognise as a back-edge escapes it too. For those,
-- 074's instruction budget is the slower fallback that cannot be escaped.

local M = {}

-- {{{ M.REGISTER -- the ones a written program may name
--
-- Deliberately few, and deliberately the scratch ones: a program that
-- returns has not disturbed anything its caller was holding, and nothing
-- here has to explain the difference between a register you may use and one
-- you must give back.
M.REGISTER = {
  a = 0, c = 1, d = 2, b = 3, sp = 4, bp = 5, si = 6, di = 7,
}
-- }}}

-- {{{ M.ARGUMENT_ORDER -- where the arguments arrive
--
-- Written down here and in the bundled patterns (303) from one source, so
-- everything the machine writes afterwards agrees with everything else it
-- wrote. The convention is the ordinary one for this architecture.
M.ARGUMENT_ORDER = { "di", "si", "d", "c" }
M.RESULT_REGISTER = "a"
-- }}}

-- {{{ encoding helpers
local function u32(value)
  value = value % 4294967296
  return string.char(value % 256,
                     math.floor(value / 256) % 256,
                     math.floor(value / 65536) % 256,
                     math.floor(value / 16777216) % 256)
end

local function signed32(value)
  if value < 0 then value = value + 4294967296 end
  return u32(value)
end

-- mod-reg-rm: the byte that says which registers an instruction is about.
local function modrm(mod, reg, rm)
  return string.char(mod * 64 + reg * 8 + rm)
end
-- }}}

-- {{{ M.INSTRUCTIONS -- one encoder per thing a program may say
--
-- A dispatch table rather than a chain of questions about which instruction
-- this is. Adding an instruction is adding a row; nothing else changes.
--
-- Every one is 64-bit and register-to-register or register-and-number,
-- because a program that only touches what it was handed needs no addresses
-- of its own -- the same property that lets the kernels run hosted and bare.
M.INSTRUCTIONS = {}

local function two_register(name, opcode)
  M.INSTRUCTIONS[name] = {
    takes = { "register", "register" },
    encode = function(to, from)
      -- REX.W: this is about the full sixty-four bits
      return string.char(0x48, opcode) .. modrm(3, from, to)
    end,
  }
end

two_register("move", 0x89)
two_register("add", 0x01)
two_register("subtract", 0x29)
two_register("and", 0x21)
two_register("or", 0x09)
two_register("compare", 0x39)

M.INSTRUCTIONS.set = {
  takes = { "register", "number" },
  encode = function(to, value)
    return string.char(0x48, 0xc7) .. modrm(3, 0, to) .. signed32(value)
  end,
}

M.INSTRUCTIONS.add_number = {
  takes = { "register", "number" },
  encode = function(to, value)
    return string.char(0x48, 0x81) .. modrm(3, 0, to) .. signed32(value)
  end,
}

M.INSTRUCTIONS.compare_number = {
  takes = { "register", "number" },
  encode = function(to, value)
    return string.char(0x48, 0x81) .. modrm(3, 7, to) .. signed32(value)
  end,
}

M.INSTRUCTIONS.multiply = {
  takes = { "register", "register" },
  encode = function(to, from)
    return string.char(0x48, 0x0f, 0xaf) .. modrm(3, to, from)
  end,
}

M.INSTRUCTIONS.load = {
  -- what is at the address in a register
  takes = { "register", "register" },
  encode = function(to, from)
    return string.char(0x48, 0x8b) .. modrm(0, to, from)
  end,
}

M.INSTRUCTIONS.store = {
  takes = { "register", "register" },
  encode = function(address, from)
    return string.char(0x48, 0x89) .. modrm(0, from, address)
  end,
}

M.INSTRUCTIONS["return"] = {
  takes = {},
  encode = function() return string.char(0xc3) end,
}
-- }}}

-- {{{ M.JUMPS -- the conditions, and their opcodes in the long form
M.JUMPS = {
  always = 0xe9,          -- one byte of opcode, four of distance
  if_equal = 0x84,        -- these are two bytes of opcode, four of distance
  if_not_equal = 0x85,
  if_less = 0x8c,
  if_greater = 0x8f,
  if_at_most = 0x8e,
  if_at_least = 0x8d,
}
-- }}}

-- {{{ M.new(options)
--
-- options: emit_at (the address of the machine-wide magnitude), aspect (who
-- these emissions are from). Both may be absent for a program whose loops
-- are not being watched, and 074 refuses to run one of those.
function M.new(options)
  options = options or {}
  local program = {
    entries = {},
    labels = {},
    emit_at = options.emit_at,
    aspect = options.aspect or 1,
    back_edges = 0,
    emissions = 0,
  }

  -- {{{ program:label(name)
  function program:label(name)
    if self.labels[name] then
      error("073-the-assembler: '" .. name .. "' is a label twice, and a jump "
        .. "to it could mean either")
    end
    self.labels[name] = true
    self.entries[#self.entries + 1] = { kind = "label", name = name, bytes = 0 }
  end
  -- }}}

  -- {{{ program:instruct(name, ...)
  function program:instruct(name, ...)
    local instruction = M.INSTRUCTIONS[name]
    if not instruction then
      error("073-the-assembler: nothing here is called '" .. tostring(name)
        .. "'. There is: " .. M.what_there_is())
    end

    local arguments = { ... }
    if #arguments ~= #instruction.takes then
      error("073-the-assembler: '" .. name .. "' takes " .. #instruction.takes
        .. " and was given " .. #arguments)
    end

    local settled = {}
    for index, wants in ipairs(instruction.takes) do
      if wants == "register" then
        local number = M.REGISTER[arguments[index]]
        if not number then
          error("073-the-assembler: '" .. tostring(arguments[index])
            .. "' is not a register this assembler knows")
        end
        settled[index] = number
      else
        local value = tonumber(arguments[index])
        if not value or value ~= math.floor(value) then
          error("073-the-assembler: '" .. tostring(arguments[index])
            .. "' is not a whole number")
        end
        if value < -2147483648 or value > 2147483647 then
          error("073-the-assembler: " .. value .. " does not fit in the "
            .. "thirty-two bits an instruction carries")
        end
        settled[index] = value
      end
    end

    local bytes = instruction.encode(unpack(settled))
    self.entries[#self.entries + 1] = { kind = "bytes", bytes = #bytes,
                                        text = bytes, said = name }
  end
  -- }}}

  -- {{{ program:jump(condition, label)
  function program:jump(condition, label)
    if not M.JUMPS[condition] then
      error("073-the-assembler: there is no jump called '" .. tostring(condition) .. "'")
    end
    local width = condition == "always" and 5 or 6
    self.entries[#self.entries + 1] = {
      kind = "jump", bytes = width, condition = condition, target = label,
    }
  end
  -- }}}

  return program
end
-- }}}

-- {{{ M.what_there_is()
function M.what_there_is()
  local names = {}
  for name in pairs(M.INSTRUCTIONS) do names[#names + 1] = name end
  table.sort(names)
  return table.concat(names, ", ")
end
-- }}}

-- {{{ M.assemble(program)
-- Two passes. The first settles where everything is, WITH the emissions in
-- place, because inserting them afterwards would move every label they sit
-- before -- which is the mistake that makes a watched program jump into the
-- middle of its own watch.
--
-- Returns the bytes, where each label ended up, and what was inserted.
function M.assemble(program)
  -- {{{ the emission, as instructions
  -- Pushes the machine-wide magnitude one step away from fifty. Written with
  -- the same encoders as everything else, so there is one description of
  -- what an instruction is.
  --
  -- It borrows two registers and gives them back, so a program cannot tell
  -- it happened except by the magnitude moving -- which is the point: a
  -- program that could see its own watchdog could avoid it.
  --
  -- AND IT SAVES THE FLAGS, WHICH IS THE WHOLE OF THE FIRST DEFECT HERE.
  -- A back-edge sits immediately after the comparison that decides whether
  -- to take it. The emission adds one to a number, which sets the flags,
  -- which destroys the comparison the jump was about to read -- so the loop
  -- turns on the watchdog's arithmetic rather than its own. Every loop
  -- became endless, including the ones that were correct, and the machine
  -- hung rather than failing.
  --
  -- The rule this leaves: a watch that changes what it watches is not a
  -- watch. Registers, flags, and anything else the processor carries between
  -- instructions must come back exactly as they were.
  local function emission_bytes()
    if not program.emit_at then return "" end
    local pieces = {}
    pieces[#pieces + 1] = string.char(0x9c)                          -- push flags
    pieces[#pieces + 1] = string.char(0x50 + M.REGISTER.a)           -- push a
    pieces[#pieces + 1] = string.char(0x51)                          -- push c
    pieces[#pieces + 1] = string.char(0x48, 0xb8)                    -- movabs a, addr
      .. u32(program.emit_at % 4294967296)
      .. u32(math.floor(program.emit_at / 4294967296))
    pieces[#pieces + 1] = string.char(0x48, 0x8b, 0x08)              -- load c, [a]
    pieces[#pieces + 1] = string.char(0x48, 0x83, 0xc1, 0x01)        -- add c, 1
    pieces[#pieces + 1] = string.char(0x48, 0x89, 0x08)              -- store [a], c
    pieces[#pieces + 1] = string.char(0x59)                          -- pop c
    pieces[#pieces + 1] = string.char(0x58)                          -- pop a
    pieces[#pieces + 1] = string.char(0x9d)                          -- pop flags
    return table.concat(pieces)
  end

  local emission = emission_bytes()
  -- }}}

  -- {{{ first pass: where everything is, and which jumps go backwards
  --
  -- A jump's direction decides whether it needs an emission, and its
  -- direction is not known until every label has a position -- so the
  -- positions are settled once assuming no emissions, the backward jumps are
  -- found, and then the positions are settled again with them in. Twice,
  -- because inserting an emission can only ever push labels later, never
  -- earlier, so the second pass cannot turn a backward jump forward.
  local function positions(with_emissions)
    local at, where = 0, {}
    for _, entry in ipairs(program.entries) do
      if entry.kind == "label" then
        where[entry.name] = at
      elseif entry.kind == "jump" then
        if with_emissions and with_emissions[entry] then
          at = at + #emission
        end
        at = at + entry.bytes
      else
        at = at + entry.bytes
      end
      entry.at = at
    end
    return where, at
  end

  local first_guess = positions(nil)
  local watched = {}
  for _, entry in ipairs(program.entries) do
    if entry.kind == "jump" then
      local target = first_guess[entry.target]
      if not target then
        error("073-the-assembler: a jump to '" .. entry.target
          .. "', which is nowhere in this program")
      end
      -- backwards, or to itself: a loop, and there is no other way to build
      -- one out of jumps.
      if target <= entry.at - entry.bytes then
        watched[entry] = true
        program.back_edges = program.back_edges + 1
      end
    end
  end

  local where = positions(watched)
  -- }}}

  -- {{{ second pass: the bytes
  local out = {}
  local inserted = 0
  for _, entry in ipairs(program.entries) do
    if entry.kind == "bytes" then
      out[#out + 1] = entry.text
    elseif entry.kind == "jump" then
      if watched[entry] and #emission > 0 then
        out[#out + 1] = emission
        inserted = inserted + 1
      end
      local target = where[entry.target]
      local after = entry.at
      local distance = target - after
      if entry.condition == "always" then
        out[#out + 1] = string.char(M.JUMPS.always) .. signed32(distance)
      else
        out[#out + 1] = string.char(0x0f, M.JUMPS[entry.condition])
          .. signed32(distance)
      end
    end
  end
  -- }}}

  program.emissions = inserted
  return table.concat(out), where, {
    back_edges = program.back_edges,
    emissions = inserted,
    watched = program.emit_at ~= nil,
  }
end
-- }}}

return M
