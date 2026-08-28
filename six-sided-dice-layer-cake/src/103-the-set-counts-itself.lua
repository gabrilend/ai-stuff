-- 103-the-set-counts-itself.lua
--
-- Counts the blueprint set, so that the blueprints which describe the blueprint
-- set stop being wrong.
--
-- For a general reader: two of the documents in this project are about the
-- project rather than about the machine. One asks whether every number produced
-- in one part is checked where it is used in another; the other is the covering
-- note a materials engineer opens first, and it says how large the thing they
-- have been handed is. Both of them carried those figures as numbers a person had
-- typed, and both had drifted -- the covering note was offering eighty blueprints
-- and five hundred and eight requirements when the set held eighty-four and five
-- hundred and forty-four.
--
-- Nothing was wrong with the design; the design was describing an earlier version
-- of itself. This counts what is actually there, the two documents copy the
-- answer, and the checker compares the copy to the count on every run. A figure
-- about the project can now go stale for exactly as long as it takes somebody to
-- run the checker once.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local units  = dofile(DIR .. "/src/091-units.lua")
local ledger = dofile(DIR .. "/src/094-ledger.lua")

local M = {}

-- {{{ function M.count()
-- Everything the set knows about its own size. All of it comes from the ledger,
-- which is the same object the checker evaluates against, so there is no second
-- reading of the files and no way for the two to disagree.
function M.count(dir)
  dir = dir or DIR
  local L = ledger.load(dir)

  local n = { blueprint = #L.blueprints, symbol = #L.order, constraint = #L.constraints,
              given = 0, measured = 0, derived = 0, solved = 0, target = 0 }
  for _, name in ipairs(L.order) do
    local k = L.decl[name].kind
    n[k] = (n[k] or 0) + 1
  end
  -- A `given` and a `measured` are both numbers nothing computed, and the share
  -- of the project that is worked out rather than chosen is the figure the
  -- handoff note quotes. A `solved` counts as worked out: a program produced it,
  -- and the checker re-runs the program.
  n.chosen = n.given + n.measured
  n.worked = n.derived + n.solved
  return n, L
end
-- }}}

-- {{{ function M.answers()
-- What the two self-describing blueprints copy, and what 095 re-runs this to
-- check.
function M.answers(dir)
  local n = M.count(dir)
  local Q = units.new
  return {
    n_bp          = Q(n.blueprint, "1"),
    n_constraint  = Q(n.constraint, "1"),
    n_sym_pkg     = Q(n.symbol, "1"),
    n_given_pkg   = Q(n.chosen, "1"),
    n_open_pkg    = Q(n.target, "1"),
    n_solved_pkg  = Q(n.solved, "1"),
  }
end
-- }}}

-- {{{ function M.report()
-- The counts in a page, for a person. Exits non-zero while any symbol is still
-- a `target`, because a blueprint set with a goal left in it is not a design --
-- which makes this runnable as the project's own finished-or-not test.
function M.report(n, out)
  out = out or io.stdout
  local function say(fmt, ...)
    out:write(select("#", ...) > 0 and fmt:format(...) or fmt, "\n")
  end
  say("")
  say("  the set, counted")
  say("")
  say("    blueprints            %5d", n.blueprint)
  say("    symbols               %5d", n.symbol)
  say("    constraints           %5d", n.constraint)
  say("")
  say("    chosen by a person    %5d", n.given)
  say("    taken from the world  %5d", n.measured)
  say("      -- neither computed %5d", n.chosen)
  say("    worked out by hand    %5d", n.derived)
  say("    worked out by program %5d", n.solved)
  say("    still only a goal     %5d", n.target)
  say("")
  say("    share not chosen      %5.1f%%", 100 * n.worked / n.symbol)
  say("")
  return n.target > 0 and 1 or 0
end
-- }}}

if arg and arg[0] and arg[0]:match("103%-the%-set%-counts%-itself%.lua$") then
  os.exit(M.report((M.count(DIR))))
end

return M
