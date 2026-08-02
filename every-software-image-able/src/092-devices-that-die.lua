-- 092-devices-that-die.lua
--
-- Devices that behave the way destroyed hardware behaves -- which is to say
-- ambiguously, silently, and sometimes later. Issues 702 and 702b.
--
-- For a general: the trap registers already answer "did the machine obey the
-- rules." This answers a different and harder question: when a part stops
-- answering, can the machine work out what happened? From inside, a
-- destroyed device, a busy device and an unpowered device all look the same,
-- and docs/003a names that as honestly hard rather than solvable.
--
-- WHY THIS EXISTS AT ALL. Emulated devices ignore the writes that destroy
-- real ones. Without this the exploration discipline is an intention with no
-- failing test attached -- and a machine could pass every trap by exploring
-- recklessly in places nobody wrote a trap for, then kill the first real
-- board it met. That is a risk of omission, which is the kind nobody
-- notices.
--
-- DEATH IS ABSENCE, NOT ANNOUNCEMENT. A destroyed device stops responding.
-- It does not report that it was killed, because the real one cannot. A
-- model that announced it would teach the machine to expect a courtesy that
-- hardware does not extend.
--
-- DEATH SURVIVES A RESTART. A part that recovers when power is cycled is a
-- bug that forgives the exact mistake being tested for.
--
-- AND SOME DEATHS ARE SLOW. Thermal damage does not present at the moment of
-- the mistake: the part works for a while and then stops, by which time the
-- machine is doing something unrelated. That is the case most likely to be
-- blamed on the wrong thing, and a machine that has only ever met instant
-- death will blame the wrong thing.

local M = {}

-- {{{ M.CONDITIONS -- the states a part can be in, and what each looks like
--
-- The three-way confusion, deliberately: from inside the machine, these are
-- not distinguishable by any single read. That is the point rather than a
-- limitation of the model.
M.CONDITIONS = {
  alive = {
    answers = true,
    note = "answers, and what it answers means something",
  },
  busy = {
    answers = false,
    recovers = true,
    note = "does not answer YET. It would, given time -- which from inside "
        .. "is indistinguishable from never",
  },
  unpowered = {
    answers = false,
    recovers = true,
    note = "does not answer, and would if it were powered. Also "
        .. "indistinguishable from never, and fixable by something the "
        .. "machine may not know it can do",
  },
  destroyed = {
    answers = false,
    recovers = false,
    note = "does not answer, and never will again. Looks exactly like the "
        .. "two above",
  },
}
-- }}}

-- {{{ M.new(options)
--
-- options: hazards (the forbidden register map, 020), now (a counter the
-- caller advances, standing in for time)
function M.new(options)
  return {
    hazards = options.hazards,
    parts = {},
    killed = {},        -- what died, and from which write
    now = 0,
    reads = 0,
  }
end
-- }}}

-- {{{ M.attach(bench, part)
--
-- part: name, base, length, condition (default alive), and optionally
--       `busy_until` or `powered`
function M.attach(bench, part)
  bench.parts[part.name] = {
    name = part.name,
    base = part.base,
    length = part.length,
    condition = part.condition or "alive",
    busy_until = part.busy_until,
    -- which offsets end this part, and how. Taken from the same map the
    -- traps and the probes read, so a probe, a trap and a death cannot
    -- disagree about where the landmine is.
    fatal = part.fatal or {},
    -- what it holds when it is alive
    registers = part.registers or {},
    died_at = nil,
    dies_at = nil,       -- for the slow ones: when the damage will present
    killed_by = nil,
  }
  return bench.parts[part.name]
end
-- }}}

-- {{{ M.tick(bench, steps)
-- Time passing. The slow deaths present here rather than at the write that
-- caused them, which is the whole of what makes them hard.
function M.tick(bench, steps)
  bench.now = bench.now + (steps or 1)
  local presented = {}
  for _, part in pairs(bench.parts) do
    if part.dies_at and bench.now >= part.dies_at
       and part.condition ~= "destroyed" then
      part.condition = "destroyed"
      part.died_at = bench.now
      presented[#presented + 1] = part.name
    end
    if part.busy_until and bench.now >= part.busy_until
       and part.condition == "busy" then
      part.condition = "alive"
    end
  end
  return presented
end
-- }}}

-- {{{ M.read(bench, name, offset)
-- What a part says when it is asked. A dead one says nothing, and so does a
-- busy one, and so does an unpowered one -- and the caller cannot tell which
-- from the answer, because neither can a real machine.
function M.read(bench, name, offset)
  local part = bench.parts[name]
  if not part then return nil, "nothing is attached called '" .. tostring(name) .. "'" end
  bench.reads = bench.reads + 1

  local condition = M.CONDITIONS[part.condition]
  if not condition.answers then
    -- Silence. Not an error, not a code, not a reason. The bus gives back
    -- all-ones, which is what a real one gives back when nothing drives it,
    -- and which is also a perfectly plausible register value.
    return 0xffffffff
  end

  return part.registers[offset] or 0
end
-- }}}

-- {{{ M.write(bench, name, offset, value)
-- Writing, including writing the thing that ends it.
--
-- The machine gets no indication. The write succeeds, exactly as it would on
-- real hardware, and the part is dead or dying afterwards.
function M.write(bench, name, offset, value)
  local part = bench.parts[name]
  if not part then return nil, "nothing is attached called '" .. tostring(name) .. "'" end

  local condition = M.CONDITIONS[part.condition]
  if not condition.answers then
    -- writing to something that is not answering does nothing, silently
    return true
  end

  local fatal = part.fatal[offset]
  if fatal and (fatal.any_value or value == fatal.value) then
    if fatal.slowly then
      -- The part keeps working. The damage presents later, by which time the
      -- machine is doing something else entirely.
      part.dies_at = bench.now + (fatal.after or 1000)
      part.killed_by = { offset = offset, value = value, at = bench.now,
                         kind = fatal.kind, slowly = true }
    else
      part.condition = "destroyed"
      part.died_at = bench.now
      part.killed_by = { offset = offset, value = value, at = bench.now,
                         kind = fatal.kind }
    end
    bench.killed[#bench.killed + 1] = part.name
    return true
  end

  part.registers[offset] = value
  return true
end
-- }}}

-- {{{ M.power_cycle(bench)
-- The machine is switched off and on again. Everything that was merely busy
-- or unpowered comes back. Everything destroyed stays destroyed.
--
-- A part that recovered here would forgive the exact mistake being tested
-- for, which is why this function exists rather than being assumed.
function M.power_cycle(bench)
  bench.now = 0
  local came_back, still_gone = {}, {}
  for _, part in pairs(bench.parts) do
    if part.condition == "destroyed" then
      still_gone[#still_gone + 1] = part.name
    else
      part.condition = "alive"
      part.busy_until = nil
      came_back[#came_back + 1] = part.name
    end
    -- and a slow death in flight is not cancelled by turning it off
    if part.dies_at then
      part.dies_at = part.dies_at - (part.killed_by and part.killed_by.at or 0)
    end
  end
  table.sort(came_back)
  table.sort(still_gone)
  return came_back, still_gone
end
-- }}}

-- {{{ M.what_really_happened(bench)
-- The truth, for the test to compare the machine's account against. Not
-- available to the machine, ever -- which is the point.
function M.what_really_happened(bench)
  local out = {}
  for name, part in pairs(bench.parts) do
    out[#out + 1] = {
      name = name,
      condition = part.condition,
      died_at = part.died_at,
      killed_by = part.killed_by,
      recoverable = M.CONDITIONS[part.condition].recovers or false,
    }
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end
-- }}}

-- {{{ M.what_the_machine_can_tell(bench, name)
-- Everything a machine inside could possibly learn about a part by asking
-- it. Deliberately thin, because it is deliberately thin in reality.
function M.what_the_machine_can_tell(bench, name)
  local part = bench.parts[name]
  if not part then return nil end
  local answer = M.read(bench, name, 0)
  return {
    name = name,
    answering = answer ~= 0xffffffff,
    -- and nothing else. There is no "why", because there is no why to read.
  }
end
-- }}}

return M
