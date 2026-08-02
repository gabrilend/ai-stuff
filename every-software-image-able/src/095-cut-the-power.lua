-- 095-cut-the-power.lua
--
-- Cutting the power at a chosen instant, over and over, to find out which
-- instants a machine can be brought back from. Issue 704.
--
-- For a general: there is a window while a machine is moving into storage
-- where it exists in two places, or in neither. On real hardware that window
-- can only be tested by pulling a plug and hoping to hit the moment. An
-- emulated machine can be stopped at exactly the instant you choose, as many
-- times as you like, from the same starting point.
--
-- BISECT RATHER THAN SCAN. The window may be millions of instructions long
-- and testing each one is pointless -- what is wanted is where the
-- BOUNDARIES are. Find one instant that recovers and one that does not, then
-- narrow between them: the same answer for a few dozen runs instead of
-- millions.
--
-- BUT WATCH FOR MORE THAN ONE BAND. Bisection assumes a single boundary. A
-- window with two unrecoverable stretches will hide one of them, and the
-- hidden one is exactly the sort of thing that only ever happens to somebody
-- else's machine. So the sweep samples coarsely first, finds every band it
-- can see, and bisects each edge -- and says how coarse the sampling was, so
-- a reader knows what could still be hiding between the samples.
--
-- REPORT THE SHAPE OF THE DAMAGE, not a pass or a fail. What matters is
-- which instants come back, which come back confused, and which do not come
-- back at all.

local M = {}

-- {{{ M.OUTCOMES -- what a machine can be, after the power comes back
M.OUTCOMES = {
  recovered = "came back, knowing what it knew",
  partial = "came back, and does not know everything it knew. Worse than "
         .. "not coming back, because it will act on what it has",
  gone = "did not come back at all",
}
-- }}}

-- {{{ M.new(options)
--
-- options:
--   snapshot   function() -> a token standing for the whole machine's state
--   restore    function(token)
--   run_for    function(instructions) -> runs that many and stops
--   kill       function() -- cuts the power where it stands
--   restart    function() -> "recovered" | "partial" | "gone"
function M.new(options)
  return {
    snapshot = options.snapshot,
    restore = options.restore,
    run_for = options.run_for,
    kill = options.kill,
    restart = options.restart,
    runs = 0,
  }
end
-- }}}

-- {{{ M.at(sweep, from, instructions)
-- One instant: restore to the start, run forward, cut the power, and see
-- what comes back.
function M.at(sweep, from, instructions)
  sweep.restore(from)
  sweep.run_for(instructions)
  sweep.kill()
  sweep.runs = sweep.runs + 1
  return sweep.restart()
end
-- }}}

-- {{{ M.sweep(sweep, options)
-- The whole window, coarsely, then every edge narrowed.
--
-- options: window (how many instructions the window is), samples (how many
--          coarse points to take first)
function M.sweep(sweep, options)
  local window = options.window
  local samples = options.samples or 16
  local from = sweep.snapshot()

  -- {{{ coarse first, so more than one band can be seen
  local step = math.max(math.floor(window / samples), 1)
  local seen = {}
  for at = 0, window, step do
    seen[#seen + 1] = { at = at, outcome = M.at(sweep, from, at) }
  end
  -- }}}

  -- {{{ every edge, narrowed
  local bands = {}
  local current = { outcome = seen[1].outcome, from = seen[1].at }
  for index = 2, #seen do
    if seen[index].outcome ~= current.outcome then
      -- an edge between seen[index-1] and seen[index]. Narrow it.
      local low, high = seen[index - 1].at, seen[index].at
      local low_outcome = seen[index - 1].outcome
      while high - low > 1 do
        local middle = math.floor((low + high) / 2)
        if M.at(sweep, from, middle) == low_outcome then
          low = middle
        else
          high = middle
        end
      end
      current.to = low
      bands[#bands + 1] = current
      current = { outcome = seen[index].outcome, from = high }
    end
  end
  current.to = window
  bands[#bands + 1] = current
  -- }}}

  return {
    bands = bands,
    runs = sweep.runs,
    -- Said rather than left implicit: bisection found the edges BETWEEN the
    -- samples it took, and anything narrower than one step could sit
    -- entirely between two samples and never be seen.
    sampled_every = step,
    could_hide = "any band shorter than " .. step .. " instructions could sit "
      .. "entirely between two samples and has not been ruled out",
  }
end
-- }}}

-- {{{ M.say_the_shape(result)
-- The shape of the damage, rather than a pass or a fail.
function M.say_the_shape(result)
  local lines = { "what happens if the power goes, across the window:" }
  for _, band in ipairs(result.bands) do
    lines[#lines + 1] = string.format("  %10d to %10d  %s",
      band.from, band.to, M.OUTCOMES[band.outcome] or band.outcome)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  found in " .. result.runs .. " runs, sampling every "
    .. result.sampled_every
  lines[#lines + 1] = "  " .. result.could_hide

  -- the one that matters most gets said on its own, because a band of
  -- partial recovery is worse than a band of no recovery: a machine that
  -- comes back not knowing what it knew will act on what it has.
  for _, band in ipairs(result.bands) do
    if band.outcome == "partial" then
      lines[#lines + 1] = ""
      lines[#lines + 1] = string.format(
        "  WORTH SAYING TWICE: between %d and %d the machine comes back "
        .. "CONFUSED rather than not coming back. That is the worse outcome, "
        .. "because it will act on what it has.", band.from, band.to)
    end
  end

  return table.concat(lines, "\n")
end
-- }}}

return M
