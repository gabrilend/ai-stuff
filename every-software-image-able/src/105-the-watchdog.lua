-- 105-the-watchdog.lua
--
-- Surviving a read that never comes back. One countdown per core, armed only
-- around the operation that can hang, and disarmed the moment it returns.
--
-- For a general: some addresses, when read, never answer. The processor is
-- not faulted -- it is stopped inside the load instruction, waiting for data
-- that will never arrive. Nothing inside the machine can notice, because the
-- thing that would notice is the thing that stopped. The only way out is a
-- piece of hardware that resets the machine when the machine stops telling
-- it everything is fine.
--
-- WHY IT MUST BE A RESET AND NOT AN INTERRUPT. This is the constraint that
-- shapes everything else here. A processor stalled on the bus is not
-- fetching instructions, so an interrupt cannot be delivered to it -- there
-- is nothing running to deliver it TO. The watchdog therefore takes the
-- machine down and brings it back up. Recovery is a reboot, not a jump.
--
-- WHICH IS WHY THE NOTE COMES FIRST, and why that rule is load-bearing
-- rather than tidy. The machine writes down what it is about to touch,
-- before touching it. If the read hangs and the watchdog resets the machine,
-- that note is the only thing that crosses the reboot. It is the machine's
-- last words to its own next start.
--
-- ARMED ONLY AROUND THE DANGEROUS READ. A watchdog running always costs
-- every part of the machine a periodic obligation. Armed around one
-- operation, the cost is paid exactly where the risk is, and a machine doing
-- ordinary arithmetic owes nothing.
--
-- ONE PER CORE, NOT ONE PER MACHINE. A stalled core is one worker lost; the
-- others keep running. A single machine-wide watchdog would reset all of
-- them because one of them stopped, which turns one lost worker into a lost
-- machine.

local M = {}

-- {{{ M.SLOTS -- how many countdowns exist
--
-- One per core, assigned rather than allocated: a core takes its own slot by
-- its own number, so no two cores can be handed the same one and nothing has
-- to be locked to find out which is free. The number of cores is discovered
-- at startup and does not change while the machine runs.
M.MAX_SLOTS = 64
-- }}}

-- {{{ M.new(options)
--
-- options:
--   cores       how many countdowns to make
--   patience    how long a read may take before the machine is reset,
--               in whatever the timer counts
--   arm         function(slot, patience)  -- starts the hardware countdown
--   disarm      function(slot)            -- stops it
--   note        function(text) -> where   -- writes the last words
--
-- The three functions are handed in for the same reason the memory rules
-- take their touch from outside: on the metal they are a timer device and a
-- disk, hosted they are pretend. What lives here is the shape.
function M.new(options)
  local cores = options.cores or 1
  if cores > M.MAX_SLOTS then
    return nil, "this machine reports " .. cores .. " cores and there are "
      .. M.MAX_SLOTS .. " countdowns. Raise the second or explain the first."
  end

  local watchdog = {
    cores = cores,
    patience = options.patience or 1000,
    arm = options.arm,
    disarm = options.disarm,
    note = options.note,
    slots = {},
    armed = 0,
    survived = 0,
    -- how many reads were attempted with a note written first. Counted
    -- because a read attempted WITHOUT one is the failure this whole
    -- arrangement exists to prevent, and it should be visible rather than
    -- inferred.
    unwitnessed = 0,
  }

  for slot = 0, cores - 1 do
    watchdog.slots[slot] = { armed = false, about = nil }
  end

  return watchdog
end
-- }}}

-- {{{ M.attempt(watchdog, core, about, read)
-- The whole discipline in one call: write the note, arm the countdown,
-- attempt the read, disarm.
--
-- `about` says what is being touched and what is expected, and goes to
-- storage before anything happens. `read` is the thing that might not come
-- back.
--
-- Returns the value, or nil and what happened. A machine that comes back
-- from a reset never returns from here at all -- it returns from power-on,
-- which is why the note matters more than the return value.
function M.attempt(watchdog, core, about, read)
  local slot = watchdog.slots[core]
  if not slot then
    return nil, "there is no countdown for core " .. tostring(core)
      .. "; this machine has " .. watchdog.cores
  end
  if slot.armed then
    -- One at a time per core, because a core can only be stalled in one
    -- place, and a second arming would mean the first read returned without
    -- anyone disarming it.
    return nil, "core " .. core .. " is already inside a read it has not "
      .. "come back from. That should be impossible, which makes it worth "
      .. "saying rather than ignoring."
  end

  -- {{{ the note, before anything
  if not watchdog.note then
    watchdog.unwitnessed = watchdog.unwitnessed + 1
    return nil, "there is nowhere to write down what this is about to do. A "
      .. "read that hangs takes the machine with it, and without a note the "
      .. "next start learns nothing -- so the read is refused instead."
  end
  -- The note is written to THIS CORE'S slot, not to one place. With a single
  -- note per machine, a core that is still running overwrites the last words
  -- of the core that hung -- and the next start then reads a perfectly
  -- ordinary operation and learns nothing about what actually went wrong.
  -- Found by a test that expected the hung core's note and got a healthy
  -- core's, which is the same shape as the whole problem: the survivor's
  -- account replacing the casualty's.
  local where = watchdog.note(core, about)
  if not where then
    watchdog.unwitnessed = watchdog.unwitnessed + 1
    return nil, "the note could not be written, so the read was not attempted"
  end
  -- }}}

  slot.armed = true
  slot.about = about
  watchdog.armed = watchdog.armed + 1
  if watchdog.arm then watchdog.arm(core, watchdog.patience) end

  -- If this hangs on real hardware, nothing below runs. Ever. The machine
  -- resets and starts again at power-on, and reads its note.
  local value, why = read()

  if watchdog.disarm then watchdog.disarm(core) end
  slot.armed = false
  slot.about = nil
  watchdog.survived = watchdog.survived + 1

  if value == nil then return nil, why or "the read came back with nothing" end
  return value, nil, { note_at = where }
end
-- }}}

-- {{{ M.what_was_it_doing(watchdog, read_note)
-- What the next start does: read every core's last words and find out what
-- the machine before it was doing.
--
-- Every slot rather than one, because the core that hung is not necessarily
-- the last one to have written. A machine with four cores leaves four
-- accounts, and the interesting one is whichever core did not come back.
function M.what_was_it_doing(watchdog, read_note)
  local said = {}
  local any = false
  for core = 0, watchdog.cores - 1 do
    local last = read_note(core)
    if last and last ~= "" then
      said[core] = last
      any = true
    end
  end

  if not any then
    return nil, "nothing was written down by any core, so the last start "
      .. "either did nothing dangerous or never got as far as writing"
  end

  return {
    per_core = said,
    said = said,
    -- On a real machine there is no way to distinguish "wrote the note and
    -- was reset" from "wrote the note and finished" unless the finish is
    -- recorded too. That the finish is NOT recorded is deliberate: writing
    -- twice per read doubles the cost of the discipline, and the note is
    -- overwritten by the next attempt anyway. What the next start learns is
    -- the last thing tried, which is what it needs.
    means = "these are the last things each core was about to do. If that "
         .. "start is gone, one of these is what it was doing when it went, "
         .. "and the others are cores that were simply busy.",
  }
end
-- }}}

-- {{{ M.offer(catalogue, hands, watchdog)
function M.offer(catalogue, hands, watchdog)
  hands.offer(catalogue, {
    name = "countdowns", takes = {},
    gives = "how the machine is protected while touching what may not answer",
    does = function()
      local lines = {
        "this machine has " .. watchdog.cores .. " countdowns, one per core.",
        "one is started before a read that may never answer, and stopped when "
          .. "it does.",
        "if it runs out, the machine is RESET rather than interrupted -- a "
          .. "processor stopped inside a read is not running anything an "
          .. "interrupt could reach.",
        "so the note written before the read is what crosses the reboot. It "
          .. "is the machine's last words to its own next start.",
        "",
        string.format("%d reads attempted, %d came back, %d refused for "
                      .. "having nowhere to leave a note.",
                      watchdog.armed, watchdog.survived, watchdog.unwitnessed),
      }
      return table.concat(lines, "\n")
    end,
  })
end
-- }}}

return M
