-- 074-run-what-it-wrote.lua
--
-- Placing code the machine wrote, calling it, and surviving it not
-- returning. Issue 204's second half, and the half the phase's risk is in:
-- code written by a model will sometimes loop forever, and without a way to
-- regain control the first bad function ends the machine.
--
-- For a general: the machine hands over a page of assembly, this puts it
-- somewhere real, runs it, and hands back what it returned. If it never
-- returns, the count the assembler was inserting at the bottom of every loop
-- crosses a line and the machine takes control back.
--
-- WHAT IS KEPT. The bytes and the text they came from, together, always. The
-- pair is what makes a later reading of "why is this here" possible, and it
-- is the first thing the machine builds that outlives the thought that made
-- it (docs/006 on what a machine writes down).
--
-- THE ESCAPE, AND ITS HOLES. Every loop this assembler built spends from an
-- allowance, so a loop that will not end runs out of allowance and is
-- stopped.
--
-- CORRECTED 2026-08-21, AND IT WAS A REAL DEFECT. The spending used to be
-- done against the machine-wide status magnitude -- fifty as ordinary, stop
-- at fifteen away -- which meant ANY LOOP OF FIFTEEN OR MORE ITERATIONS was
-- declared a runaway. Copying a hundred bytes. Summing twenty numbers.
-- Clearing a page, several hundred times over. The test suite missed it
-- because its loops count down from five.
--
-- The cause was two instruments welded into one. The two digits on the lamps
-- are POST codes -- breadcrumbs saying WHERE a program got to, in a
-- vocabulary that program owns, last writer wins (079, docs/006). They are
-- not a measurement and nothing accumulates in them. What stops a runaway is
-- a plain count with a large allowance, and it is PER PROGRAM, because
-- anything worth running is worth running on more than one thread and two
-- threads looping at once would both push a number neither of them owns. What escapes it: code that did not come through our assembler,
-- and a loop built out of something the assembler does not recognise as a
-- back-edge. For those, an instruction budget stepped one at a time is the
-- slow fallback -- it cannot be escaped, and it is worth having even if it
-- is rarely reached. Whether it exists here is a property of the machine
-- this is running on, and is answered rather than assumed: see `M.new`.

local M = {}

-- {{{ M.ALLOWANCE -- how many times a loop may go round before somebody looks
--
-- A million. Not a tuned number -- an obviously-generous one, chosen so that
-- no correct program meets it by accident, since the whole failure this
-- replaced was a bound so tight that correct programs met it immediately.
--
-- It is spent per program and starts at zero for every run, so it is a
-- private count rather than a shared dial. Programs that legitimately need
-- more say so when they are run.
M.ALLOWANCE = 1000000
-- }}}

-- {{{ M.new(options)
--
-- options:
--   memory       a memory (071), for placing and for the magnitude
--   somewhere    an address in usable memory that is not ours, with room
--   room         how many bytes are free there
--   count_at     an address holding this program's loop count
--   run          function(address, arguments) -> value; how this machine
--                actually transfers control
--   stop         function() -> nil; how it takes control back, or nil where
--                nothing can. Absent means a runaway is fatal, which is
--                said out loud rather than hoped about.
--   allowance    how many turns of a loop are enough (default a million)
function M.new(options)
  return {
    memory = options.memory,
    -- the rules themselves, so placing writes THROUGH them rather than
    -- around them. A hand that could bypass the one refusal would make the
    -- refusal decorative.
    touch = options.touch or dofile(
      (os.getenv("ESIA_DIR") or "/mnt/mtwo/programming/ai-stuff/every-software-image-able")
      .. "/src/071-touch-memory.lua"),
    somewhere = options.somewhere,
    room = options.room,
    count_at = options.count_at,
    run = options.run,
    stop = options.stop,
    allowance = options.allowance or M.ALLOWANCE,
    placed = {},        -- everything ever placed, with its text
    used = 0,
    runs = 0,
    stopped = 0,
  }
end
-- }}}

-- {{{ M.place(runner, name, bytes, text)
-- Puts a program somewhere real and hands back where it went.
--
-- The memory rules from 203 apply unchanged: this writes through them rather
-- than around them, so placing a program on top of the engine is refused by
-- the same check that refuses any other write there. A hand that could
-- bypass the one refusal would make the refusal decorative.
function M.place(runner, name, bytes, text)
  local at = runner.somewhere + runner.used
  if runner.used + #bytes > runner.room then
    return nil, "there are " .. (runner.room - runner.used)
      .. " bytes left where programs go, and this one is " .. #bytes
  end

  -- Changed 2026-08-21. Placing used to be refused outright when the bytes
  -- would land on the engine or the weights, because the memory hand refused
  -- any such write. The hand does not refuse any more (071), so neither does
  -- this -- what it does instead is carry the warning back out, once, from
  -- whichever byte first said something. Placing a program on top of your own
  -- mind is almost certainly a mistake; it is still yours to make, and the
  -- only thing that would make it fatal is not being told.
  local warned
  for offset = 0, #bytes - 1 do
    local ok, why, said = runner.touch.poke_byte(runner.memory, at + offset,
                                                 bytes:byte(offset + 1))
    if not ok then
      return nil, "could not place it: " .. tostring(why)
    end
    warned = warned or said
  end

  runner.used = runner.used + #bytes
  -- kept in the order they were made, because that order is the machine's
  -- own history of what it built and when.
  runner.placed[#runner.placed + 1] = {
    name = name, at = at, bytes = #bytes, text = text, warned = warned,
  }
  return at, nil, warned
end
-- }}}

-- {{{ M.call(runner, at, arguments)
-- Runs it, watching the magnitude.
--
-- Returns the value, or nil and what happened. A program stopped for running
-- away is not an error in the machine -- it is the machine working -- so it
-- comes back as a sentence the model can read and a new attempt can be made
-- from.
function M.call(runner, at, arguments)
  if not runner.run then
    return nil, "this machine has no way to transfer control to what it wrote"
  end

  -- the count starts at zero, so what the run spends is the run's own record
  -- rather than the previous one's.
  runner.memory.write(runner.count_at, 8, 0)
  runner.runs = runner.runs + 1

  local value, trouble = runner.run(at, arguments or {}, runner)

  local spent = runner.memory.read(runner.count_at, 8)

  if trouble == "ran away" then
    runner.stopped = runner.stopped + 1
    return nil, "it did not come back. Its loops went round " .. spent
      .. " times, which is past the " .. runner.allowance
      .. " it was allowed, and control was taken."
  end
  if trouble then return nil, trouble end

  return value, nil, { spent = spent, allowance = runner.allowance }
end
-- }}}

-- {{{ M.watch(runner)
-- What a machine asks between steps of something it is running: is this
-- still worth waiting for. Exposed because the answer belongs to the runner
-- and the asking belongs to whatever transfers control.
function M.watch(runner)
  local spent = runner.memory.read(runner.count_at, 8)
  return spent < runner.allowance, spent
end
-- }}}

-- {{{ M.offer(catalogue, hands, runner, assembler)
-- The hand itself: text in, a placed program out, and a second hand to call
-- it. Two hands rather than one, because placing and running are different
-- risks and a machine may want to look at what it built before running it.
function M.offer(catalogue, hands, runner, assembler)
  hands.offer(catalogue, {
    name = "assemble", takes = { "name", "text" },
    gives = "where it was placed",
    note = "turns written assembly into instructions and puts them somewhere",
    does = function(arguments)
      local name, text = arguments[1], arguments[2]
      local program = assembler.new({ count_at = runner.count_at })

      -- The text is read line by line, one instruction each, because a
      -- machine writing assembly writes lines. A line it cannot read is a
      -- refusal naming the line, since guessing at an instruction is a hand
      -- moving somewhere nobody asked it to.
      local line_number = 0
      for line in (text .. "\n"):gmatch("(.-)\n") do
        line_number = line_number + 1
        local words = {}
        for word in line:gmatch("%S+") do words[#words + 1] = word end
        if #words > 0 and words[1]:sub(1, 1) ~= "#" then
          local ok, why = pcall(function()
            if words[1]:sub(-1) == ":" then
              program:label(words[1]:sub(1, -2))
            elseif words[1] == "jump" then
              program:jump(words[2], words[3])
            else
              program:instruct(unpack(words))
            end
          end)
          if not ok then
            return nil, "line " .. line_number .. ": " .. tostring(why)
              :gsub("^.-073%-the%-assembler: ", "")
          end
        end
      end

      local ok, bytes, _, report = pcall(assembler.assemble, program)
      if not ok then return nil, tostring(bytes):gsub("^.-: ", "") end

      local at, refusal = M.place(runner, name, bytes, text)
      if not at then return nil, refusal end

      return string.format("placed '%s' at 0x%x, %d bytes, %d loops watched",
                           name, at, #bytes, report.emissions)
    end,
  })

  hands.offer(catalogue, {
    name = "run", takes = { "where" }, gives = "what it returned",
    note = "runs something already placed, and stops it if it will not stop",
    does = function(arguments)
      local at = tonumber(arguments[1])
      if not at then return nil, "'" .. tostring(arguments[1])
        .. "' is not an address. They may be written 0x1234." end

      local known = nil
      for _, entry in ipairs(runner.placed) do
        if entry.at == at then known = entry end
      end
      if not known then
        return nil, string.format("nothing was placed at 0x%x. What this "
          .. "machine has built is in <call built>.", at)
      end

      local value, trouble = M.call(runner, at, {})
      if not value then return nil, trouble end
      return tostring(value)
    end,
  })

  hands.offer(catalogue, {
    name = "built", takes = {}, gives = "what this machine has made",
    does = function()
      if #runner.placed == 0 then return "nothing yet" end
      local lines = { "what this machine has built, in the order it built it:" }
      for _, entry in ipairs(runner.placed) do
        lines[#lines + 1] = string.format("  0x%x  %-16s %d bytes",
                                          entry.at, entry.name, entry.bytes)
      end
      return table.concat(lines, "\n")
    end,
  })

  hands.offer(catalogue, {
    name = "why", takes = { "where" }, gives = "the text it came from",
    note = "what was written to make the program at an address",
    does = function(arguments)
      local at = tonumber(arguments[1])
      if not at then return nil, "'" .. tostring(arguments[1]) .. "' is not an address" end
      for _, entry in ipairs(runner.placed) do
        if entry.at == at then
          return "'" .. entry.name .. "' was made from:\n" .. entry.text
        end
      end
      return nil, string.format("nothing was placed at 0x%x", at)
    end,
  })
end
-- }}}

return M
