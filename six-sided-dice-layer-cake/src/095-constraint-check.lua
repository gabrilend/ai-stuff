-- 095-constraint-check.lua
--
-- Evaluates every constraint in the blueprint set and says which ones hold.
-- This is the program that decides whether the project is finished.
--
-- For a general reader: each blueprint writes down the things that must be true
-- about the part it describes -- the core has to fit inside the cavity, the
-- input power has to equal the heat removed, the slice has to hold two layers
-- at once. This runs all of them at once and prints the ones that do not. A
-- failure line gives both sides worked out with their units and the sentence
-- the author wrote saying why it had to hold, because a line that just says a
-- constraint failed helps nobody.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local units      = dofile(DIR .. "/src/091-units.lua")
local expression = dofile(DIR .. "/src/092-expression.lua")
local ledger     = dofile(DIR .. "/src/094-ledger.lua")

local M = {}

-- What "the same" means for the approximate operator. One part in a thousand,
-- and it is the most valuable operator in the notation because it is what the
-- cross-checks are written with: two blueprints deriving the same quantity by
-- different routes will not agree to the last bit and should not be asked to.
-- What "the same" means for the approximate operator, and for checking a
-- `solved` value against the program that produced it. One part in a thousand:
-- two blueprints deriving one quantity by different routes will not agree to
-- the last bit and should not be asked to.
M.TOLERANCE = 1e-3

-- One comparison per operator, as a table, because the alternative is a
-- six-branch conditional in the middle of the only loop that matters.
local COMPARE = {
  ["<="] = function(a, b) return a.v <= b.v end,
  [">="] = function(a, b) return a.v >= b.v end,
  ["<"]  = function(a, b) return a.v <  b.v end,
  [">"]  = function(a, b) return a.v >  b.v end,
  ["=="] = function(a, b) return a.v == b.v end,
  ["~="] = function(a, b)
    local scale = math.max(math.abs(a.v), math.abs(b.v))
    if scale == 0 then return true end
    return math.abs(a.v - b.v) / scale <= M.TOLERANCE
  end,
}

-- {{{ local function comparable()
-- Zero is the one number that belongs to every dimension. Writing `L_cavity > 0`
-- is ordinary and correct, and the literal on the right is dimensionless because
-- every literal is -- so without this exception the notation's own rule would
-- forbid the commonest constraint anybody writes. The exception is deliberately
-- narrow: the value must be exactly zero and it must be the dimensionless side.
local function comparable(a, b)
  if units.dim_equal(a.d, b.d) then return true end
  if a.v == 0 and units.dim_equal(a.d, units.DIMENSIONLESS) then return true end
  if b.v == 0 and units.dim_equal(b.d, units.DIMENSIONLESS) then return true end
  return false
end
-- }}}

-- {{{ local function margin()
-- How far off a failing constraint is, as a fraction, so that a reader can tell
-- a rounding error from a design that is wrong by a factor of ten.
local function margin(a, b)
  local scale = math.max(math.abs(a.v), math.abs(b.v))
  if scale == 0 then return 0 end
  return (a.v - b.v) / scale
end
-- }}}

-- {{{ local function check_solved()
-- The one category in the project that is remembered rather than recomputed.
--
-- A `solved` symbol holds a number some instrument produced because the
-- notation's own arithmetic cannot express the computation -- an iterative
-- solve, a search over a discrete set. The number in the blueprint is a copy,
-- and a copy of an answer goes stale the moment the question changes: narrow a
-- rail and the flow shares move, and nothing would notice that the blueprint is
-- now describing a machine that does not exist.
--
-- So the copy is checked against the original on every run. The declaration
-- names its producer by index in the meaning field, this loads that instrument,
-- asks it for its table of answers, and compares. The tolerance is the same one
-- the approximate operator uses everywhere else, because it is the same
-- question: do these two routes to one number agree.
--
-- Three ways it can go wrong, reported apart because they mean different
-- things. The number has drifted -- somebody changed an input and did not
-- re-run. Nobody answered for the symbol -- the named instrument does not know
-- it, so the declaration is pointing at the wrong program. Nobody declared the
-- answer -- the instrument computes something no blueprint records, which is
-- work being thrown away rather than a mistake, but is worth seeing.
local function check_solved(R, L, dir)
  -- Which instruments to ask. Gathering them first means each is loaded once
  -- however many symbols it answers for, and a solver that iterates is not
  -- something to run six times for six numbers.
  local wanted, producers = {}, {}
  for _, name in ipairs(L.solved or {}) do
    local d = L.decl[name]
    -- The marker is "-- from NNN" and not merely a three-digit number, because
    -- a meaning is a sentence and a sentence about a solved value very often
    -- mentions the blueprint the geometry came from.
    local idx = d.meaning:match("%-%- from (%d%d%d)")
    if not idx then
      R.unclaimed[#R.unclaimed + 1] = { name = name, why = "names no instrument" }
    else
      wanted[idx] = wanted[idx] or {}
      wanted[idx][#wanted[idx] + 1] = name
      producers[name] = idx
    end
  end

  for idx, names in pairs(wanted) do
    local path = nil
    local pipe = io.popen(("ls %s/src/%s-*.lua 2>/dev/null"):format(dir, idx))
    if pipe then path = pipe:read("*l"); pipe:close() end
    if not path or path == "" then
      for _, name in ipairs(names) do
        R.unclaimed[#R.unclaimed + 1] = {
          name = name, why = ("no instrument %s in src/"):format(idx),
        }
      end
    else
      local ok, inst = pcall(dofile, path)
      local answers = ok and type(inst) == "table" and inst.answers
      if not answers then
        for _, name in ipairs(names) do
          R.unclaimed[#R.unclaimed + 1] = {
            name = name,
            why = ok and ("%s answers for nothing"):format(idx)
                      or ("%s would not load: %s"):format(idx, tostring(inst)),
          }
        end
      else
        local okr, given = pcall(answers, dir)
        if not okr then
          for _, name in ipairs(names) do
            R.unclaimed[#R.unclaimed + 1] = {
              name = name, why = ("%s failed: %s"):format(idx, tostring(given)),
            }
          end
        else
          for _, name in ipairs(names) do
            local q = given[name]
            local have = L.value[name]
            if q == nil then
              R.unclaimed[#R.unclaimed + 1] = {
                name = name, why = ("%s does not answer for it"):format(idx),
              }
            elseif have then
              local scale = math.max(math.abs(q.v), math.abs(have.v))
              local off = scale == 0 and 0 or math.abs(q.v - have.v) / scale
              if off > M.TOLERANCE then
                R.drift[#R.drift + 1] = {
                  name = name, stored = have, fresh = q, off = off,
                  file = L.decl[name].file, line = L.decl[name].line,
                  by = idx,
                }
              end
            end
          end
          for name in pairs(given) do
            if not L.decl[name] then
              R.unwanted[#R.unwanted + 1] = { name = name, by = idx }
            end
          end
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.run()
-- Evaluate every constraint in a blueprint set and sort the results into the
-- kinds of wrong they are.
--
-- Held and failed are the obvious two. Apart from those: a comparison between
-- unlike dimensions, which means somebody wrote nonsense rather than the design
-- being tight; a constraint that will not evaluate at all, which nearly always
-- means it reaches into a blueprint nobody has written yet; a `solved` value
-- that no longer matches the program which produced it; and a literal in a
-- derivation that looks like somebody converting units by hand in a notation
-- that already converts.
--
-- Reads the files and nothing else. M.report turns the result into words.
function M.run(dir)
  dir = dir or DIR
  local L = ledger.load(dir)
  local R = {
    ledger = L,
    passed = {}, failed = {}, mismatched = {}, unresolved = {},
    structural = L.errors,
    bare = {},          -- blueprints with no constraints at all
    exact_warn = {},    -- == used on something with a fractional part
    conversions = {},   -- literals that look like hand-written unit conversions
    drift = {},         -- solved symbols whose producer no longer agrees
    unclaimed = {},     -- solved symbols no instrument answered for
    unwanted = {},      -- instrument answers nobody declared
  }

  check_solved(R, L, dir)

  -- Every derivation and every relation, swept for literals that look like
  -- somebody converting units by hand. See 092 for why this is worth doing:
  -- the dimensionless-literal rule catches an unlabelled quantity and misses a
  -- doubly-converted one, and the second is far more common.
  local function sweep_literals(tree, where, file, line)
    if not tree then return end
    for _, lit in ipairs(expression.literals(tree)) do
      if expression.suspicious_literal(lit.v) then
        R.conversions[#R.conversions + 1] = {
          where = where, file = file, line = line, v = lit.v,
        }
      end
    end
  end
  for _, name in ipairs(L.order) do
    local d = L.decl[name]
    if d.tree then sweep_literals(d.tree, name, d.file, d.line) end
  end
  for _, c in ipairs(L.constraints) do
    if c.rel then
      sweep_literals(c.rel.lhs, c.tag, c.file, c.line)
      sweep_literals(c.rel.rhs, c.tag, c.file, c.line)
    end
  end

  for _, c in ipairs(L.constraints) do
    local rel = c.rel
    if not rel then
      -- the relation would not parse; the ledger already said so
    else
      local okl, a = pcall(expression.eval, rel.lhs, L.value)
      local okr, b = pcall(expression.eval, rel.rhs, L.value)
      if not okl or not okr then
        -- A constraint that will not evaluate is kept apart from one that
        -- evaluates to nonsense. Nearly always this means it reaches into a
        -- blueprint that has not been written yet, which is the set being
        -- incomplete rather than wrong, and the two want different reading.
        R.unresolved[#R.unresolved + 1] = {
          c = c, why = tostring(okl and b or a),
        }
      elseif not comparable(a, b) then
        -- Reported apart from the failures on purpose. A dimension mismatch
        -- means somebody wrote nonsense; a failure means the design is too
        -- tight. Mixing the two in one list wastes the reader's time on the
        -- day they most need it not wasted.
        R.mismatched[#R.mismatched + 1] = {
          c = c,
          why = ("left side is %s, right side is %s")
                :format(units.dim_name(a.d), units.dim_name(b.d)),
        }
      else
        if c.rel.op == "==" and (a.v ~= math.floor(a.v) or b.v ~= math.floor(b.v)) then
          R.exact_warn[#R.exact_warn + 1] = c
        end
        local rec = { c = c, a = a, b = b, margin = margin(a, b) }
        if COMPARE[rel.op](a, b) then
          R.passed[#R.passed + 1] = rec
        else
          R.failed[#R.failed + 1] = rec
        end
      end
    end
  end

  for _, bp in ipairs(L.blueprints) do
    if #bp.constraints == 0 then R.bare[#R.bare + 1] = bp end
  end

  return R
end
-- }}}

-- {{{ local function unit_for()
-- Print a quantity in the unit its own symbol was declared in where that can be
-- worked out, and in base units otherwise. A cavity reported as 0.046 m when
-- every drawing says millimetres is technically right and practically useless.
local function unit_for(L, tree, q)
  if tree and tree.k == "ref" then
    local d = L.decl[tree.name]
    if d then
      local ok, s = pcall(units.format, q, d.unit)
      if ok then return s end
    end
  end
  return units.format(q)
end
-- }}}

-- {{{ function M.report()
-- Write a run out for a person, and return the exit code the run deserves.
--
-- A failure line gives the tag, the file and line, the relation as written,
-- both sides evaluated in the unit their own symbols were declared in, the
-- margin as a percentage, and the sentence the author wrote saying why it had
-- to hold. A line that only said a constraint failed would help nobody.
function M.report(R, out)
  out = out or io.stdout
  local L = R.ledger
  local function say(fmt, ...)
    out:write(select("#", ...) > 0 and fmt:format(...) or fmt, "\n")
  end

  say("")
  say("  six-sided-dice-layer-cake -- constraint check")
  say("  %d blueprints, %d symbols, %d constraints",
      #L.blueprints, #L.order, #L.constraints)
  say("")

  if #R.structural > 0 then
    say("  STRUCTURAL -- the blueprint set does not load cleanly")
    for _, e in ipairs(R.structural) do say("    %s", e) end
    say("")
  end

  if #R.mismatched > 0 then
    say("  NONSENSE -- these constraints compare unlike things")
    for _, m in ipairs(R.mismatched) do
      say("    %s  (%s:%d)", m.c.tag, m.c.file, m.c.line)
      say("      %s", m.c.relation)
      say("      %s", m.why)
    end
    say("")
  end

  if #R.unresolved > 0 then
    say("  NOT YET -- %d constraints reach for something that does not exist", #R.unresolved)
    say("  (the set is incomplete, which is different from being wrong)")
    for _, m in ipairs(R.unresolved) do
      say("    %s  (%s:%d)  %s", m.c.tag, m.c.file, m.c.line, m.why)
    end
    say("")
  end

  if #R.failed > 0 then
    say("  FAILED")
    for _, f in ipairs(R.failed) do
      say("    %s  (%s:%d)", f.c.tag, f.c.file, f.c.line)
      say("      %s", f.c.relation)
      say("      left  = %s", unit_for(L, f.c.rel.lhs, f.a))
      say("      right = %s", unit_for(L, f.c.rel.rhs, f.b))
      say("      off by %.3g%%", f.margin * 100)
      say("      because: %s", f.c.reason)
    end
    say("")
  end

  if #R.conversions > 0 then
    say("  WARNING -- literals that look like hand-written unit conversions")
    say("  (this notation converts between units; multiplying by a thousand or")
    say("  eight thousand million inside a derivation is almost always a mistake,")
    say("  and it is a silent one because the literal is dimensionless either way).")
    say("  Some of these are legitimate ratios -- a thousandth, a factor of ten --")
    say("  so this is a warning to read rather than a defect to fix.")
    for _, c in ipairs(R.conversions) do
      say("    %-22s %s:%d  %g", c.where, c.file, c.line, c.v)
    end
    say("")
  end

  if #R.exact_warn > 0 then
    say("  WARNING -- exact comparison on a value that is not a whole number")
    for _, c in ipairs(R.exact_warn) do
      say("    %s  (%s:%d) -- use ~= unless both sides are counts", c.tag, c.file, c.line)
    end
    say("")
  end

  -- Drift is a failure and reads like one. The design believes a number that
  -- the program which produced it no longer produces, which means an input
  -- moved and nobody re-ran the solver -- and every constraint downstream has
  -- been holding against a machine that is not the one on the drawings.
  if #R.drift > 0 then
    say("  STALE -- %d solved values no longer match what produced them", #R.drift)
    for _, d in ipairs(R.drift) do
      say("    %-24s %s:%d", d.name, d.file, d.line)
      local u = L.decl[d.name].unit
      local function show(q)
        local ok, t = pcall(units.format, q, u)
        return ok and t or units.format(q)
      end
      say("      blueprint says %s, %s now gives %s -- %.2f%% apart",
          show(d.stored), d.by, show(d.fresh), d.off * 100)
    end
    say("")
  end

  if #R.unclaimed > 0 then
    say("  UNANSWERED -- %d solved values have no working producer", #R.unclaimed)
    for _, u in ipairs(R.unclaimed) do
      say("    %-24s %s", u.name, u.why)
    end
    say("")
  end

  if #R.unwanted > 0 then
    say("  UNRECORDED -- %d answers no blueprint declares", #R.unwanted)
    say("  An instrument computed these and nothing in the design uses them.")
    for _, u in ipairs(R.unwanted) do
      say("    %-24s from %s", u.name, u.by)
    end
    say("")
  end

  if #(L.solved or {}) > 0 then
    say("  SOLVED -- %d values come from a program rather than an expression",
        #L.solved)
    for _, n in ipairs(L.solved) do
      local d = L.decl[n]
      say("    %-24s %s:%d  %s", n, d.file, d.line, d.meaning)
    end
    say("")
  end

  if #L.targets > 0 then
    say("  UNFINISHED -- %d symbols are still targets rather than derivations.", #L.targets)
    say("  A blueprint set with targets in it is not finished.")
    for _, n in ipairs(L.targets) do
      local d = L.decl[n]
      say("    %-24s %s:%d  %s", n, d.file, d.line, d.meaning)
    end
    say("")
  end

  if #L.orphans > 0 then
    say("  ORPHANS -- %d symbols nothing references", #L.orphans)
    for _, n in ipairs(L.orphans) do
      local d = L.decl[n]
      say("    %-24s %s:%d", n, d.file, d.line)
    end
    say("")
  end

  if #R.bare > 0 then
    say("  UNCHECKED -- %d blueprints assert nothing about themselves", #R.bare)
    for _, bp in ipairs(R.bare) do say("    %s  %s", bp.number, bp.title) end
    say("")
  end

  say("  %d of %d constraints hold; %d could not be evaluated.",
      #R.passed, #R.passed + #R.failed, #R.unresolved + #R.mismatched)
  say("")
  return M.exit_code(R)
end
-- }}}

-- {{{ function M.exit_code()
-- Non-zero for anything that means the set is wrong; zero for the two
-- conditions that only mean it is unfinished, so that the program can be run
-- from anything and its answer believed.
function M.exit_code(R)
  if #R.structural > 0 or #R.mismatched > 0 or #R.failed > 0 then return 1 end
  -- A stale solved value is wrong rather than unfinished, and it is the worse
  -- kind of wrong: every constraint that reads it passed, against a number the
  -- design no longer produces. An unanswered one is the same defect one step
  -- earlier -- a declaration pointing at a program that cannot confirm it.
  if #R.drift > 0 or #R.unclaimed > 0 then return 1 end
  -- An unresolved constraint is the set being unfinished, and unfinished is
  -- reported rather than failed -- the same treatment targets and orphans get.
  return 0
end
-- }}}

-- Runnable as well as loadable. When this file is the program rather than a
-- module -- which is how `run-checks` invokes it -- it does the run and exits
-- with the verdict. When something requires it, this does nothing.
if arg and arg[0] and arg[0]:match("095%-constraint%-check%.lua$") then
  os.exit(M.report(M.run(DIR)))
end

return M
