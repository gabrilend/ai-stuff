-- 094-ledger.lua
--
-- Loads every blueprint, works out what depends on what, resolves every symbol
-- in an order that makes that possible, and refuses in the four ways that
-- matter: a name declared twice, a name referenced and never declared, a
-- circular derivation, and a derivation whose arithmetic does not agree with
-- itself dimensionally.
--
-- For a general reader: this is the file that makes the claim "a dimension is
-- written once and referenced everywhere" true rather than merely intended.
-- Nothing else in the project checks it, and without it the notation is just a
-- convention people would drift away from.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local units      = dofile(DIR .. "/src/091-units.lua")
local expression = dofile(DIR .. "/src/092-expression.lua")
local reader     = dofile(DIR .. "/src/093-blueprint-reader.lua")

local M = {}

-- {{{ local function list_blueprints()
-- Every .md in src/ except the companion pages, which are generated from these
-- and would otherwise be read back in as if they were sources.
local function list_blueprints(dir)
  local out = {}
  local p = io.popen("ls -1 " .. dir .. "/src/*.md 2>/dev/null")
  if not p then return out end
  for line in p:lines() do
    if not line:match("%.info%.md$") then out[#out + 1] = line end
  end
  p:close()
  table.sort(out)
  return out
end
-- }}}

-- {{{ local function topo_order()
-- Depth-first, with an explicit colour per node so that a cycle is reported as
-- a cycle rather than discovered as a stack overflow. Grey means "on the
-- current path"; meeting a grey node is the cycle, and the path stack is what
-- gets printed, because a cycle of five is much harder to find than to fix.
local function topo_order(names, deps, fail)
  local colour, order, path = {}, {}, {}
  local visit
  visit = function(n)
    local c = colour[n]
    if c == "black" then return end
    if c == "grey" then
      local at = 1
      for i = 1, #path do if path[i] == n then at = i break end end
      local cyc = {}
      for i = at, #path do cyc[#cyc + 1] = path[i] end
      cyc[#cyc + 1] = n
      fail("circular derivation: " .. table.concat(cyc, " -> "))
    end
    colour[n] = "grey"
    path[#path + 1] = n
    local d = deps[n]
    if d then
      for i = 1, #d do
        if deps[d[i]] ~= nil or colour[d[i]] then visit(d[i]) end
      end
    end
    path[#path] = nil
    colour[n] = "black"
    order[#order + 1] = n
  end
  for i = 1, #names do visit(names[i]) end
  return order
end
-- }}}

-- {{{ function M.load()
function M.load(dir, opts)
  dir = dir or DIR
  opts = opts or {}
  local L = {
    blueprints = {},   -- in file order
    by_number  = {},
    decl       = {},   -- name -> declaration record
    order      = {},   -- names, in declaration order
    value      = {},   -- name -> quantity
    used_by    = {},   -- name -> array of blueprint numbers that reference it
    errors     = {},
    constraints = {},
    drawings   = {},
  }

  local function note(msg) L.errors[#L.errors + 1] = msg end
  local function fail(msg) error(msg, 0) end

  for _, path in ipairs(list_blueprints(dir)) do
    local ok, bp = pcall(reader.read, path)
    if not ok then
      note(tostring(bp))
    else
      L.blueprints[#L.blueprints + 1] = bp
      if L.by_number[bp.number] then
        note(("two blueprints numbered %s: %s and %s")
             :format(bp.number, L.by_number[bp.number].file, bp.file))
      end
      L.by_number[bp.number] = bp
      for _, s in ipairs(bp.symbols) do
        -- The refusal that makes the whole notation worth having. Two
        -- blueprints declaring the same name is either a copy or a
        -- disagreement, and both are worth stopping for.
        local prev = L.decl[s.name]
        if prev then
          note(("%s:%d: %s is already declared at %s:%d")
               :format(s.file, s.line, s.name, prev.file, prev.line))
        else
          s.blueprint = bp
          L.decl[s.name] = s
          L.order[#L.order + 1] = s.name
        end
      end
      for _, c in ipairs(bp.constraints) do
        c.blueprint = bp
        L.constraints[#L.constraints + 1] = c
      end
      for _, d in ipairs(bp.drawings) do
        d.blueprint = bp
        L.drawings[#L.drawings + 1] = d
      end
    end
  end

  -- Parse every derivation once, and collect what it depends on, before
  -- evaluating anything. The ledger has to know the shape of the graph before
  -- it can know an order to walk it in.
  local deps = {}
  for _, name in ipairs(L.order) do
    local s = L.decl[name]
    if s.kind == "derived" or (s.kind == "target" and not s.literal) then
      if s.expr ~= "" then
        local ok, tree = pcall(expression.parse, s.expr,
                               ("%s:%d %s"):format(s.file, s.line, s.name))
        if ok then
          s.tree = tree
          deps[name] = expression.refs(tree)
        else
          note(tostring(tree))
          deps[name] = {}
        end
      else
        deps[name] = {}
      end
    else
      deps[name] = {}
    end
  end

  -- Undefined references, reported all at once rather than one per run.
  for _, name in ipairs(L.order) do
    for _, d in ipairs(deps[name] or {}) do
      if not L.decl[d] then
        local s = L.decl[name]
        note(("%s:%d: %s references %s, which nothing declares")
             :format(s.file, s.line, name, d))
      end
    end
  end

  local order
  local ok, err = pcall(function()
    order = topo_order(L.order, deps, fail)
  end)
  if not ok then
    note(tostring(err))
    order = L.order
  end

  -- Resolve, in dependency order.
  --
  -- A symbol whose own dependencies did not resolve is skipped rather than
  -- attempted. The root cause was already reported once, above, and attempting
  -- it would report the same missing name again at every step of the chain --
  -- so one undeclared symbol at the bottom of a six-deep derivation produces
  -- six identical complaints and the reader has to work out which one is real.
  L.unresolved = {}
  local function resolvable(name)
    for _, d in ipairs(deps[name] or {}) do
      if L.value[d] == nil then return false end
    end
    return true
  end

  for _, name in ipairs(order) do
    local s = L.decl[name]
    if s and L.value[name] == nil and not resolvable(name) then
      L.unresolved[name] = true
    elseif s and L.value[name] == nil then
      if s.kind == "given" or s.kind == "measured"
         or (s.kind == "target" and s.literal) then
        local okv, q = pcall(units.new, s.literal, s.unit)
        if okv then L.value[name] = q
        else note(("%s:%d: %s: %s"):format(s.file, s.line, name, tostring(q))) end
      elseif s.tree then
        local okv, q = pcall(expression.eval, s.tree, L.value)
        if not okv then
          note(("%s:%d: %s: %s"):format(s.file, s.line, name, tostring(q)))
        else
          -- The declared unit is not decoration: it is a second, independent
          -- statement of what this quantity is, and the derivation has to agree
          -- with it. A derivation that comes out in watts under a symbol
          -- declared in kelvin is a real mistake and this is where it is caught.
          local oku, du = pcall(units.parse_unit, s.unit)
          if not oku then
            note(("%s:%d: %s: %s"):format(s.file, s.line, name, tostring(du)))
          else
            local _, dim = units.parse_unit(s.unit)
            if not units.dim_equal(q.d, dim) then
              note(("%s:%d: %s is declared in %s but its derivation gives %s")
                   :format(s.file, s.line, name, s.unit, units.dim_name(q.d)))
            end
            L.value[name] = q
          end
        end
      end
    end
  end

  -- The reverse index. Worth as much as the values: a symbol nothing
  -- references is either dead or the design has a hole, and only the ledger can
  -- see it. Constraints count as references, or every symbol that exists only
  -- to be checked would look orphaned.
  for _, name in ipairs(L.order) do L.used_by[name] = {} end
  local function credit(name, bpnum)
    if L.used_by[name] then
      local u = L.used_by[name]
      for i = 1, #u do if u[i] == bpnum then return end end
      u[#u + 1] = bpnum
    end
  end
  for _, name in ipairs(L.order) do
    for _, d in ipairs(deps[name] or {}) do
      credit(d, L.decl[name].blueprint.number)
    end
  end
  for _, c in ipairs(L.constraints) do
    local okc, rel = pcall(expression.parse_relation, c.relation,
                           ("%s:%d %s"):format(c.file, c.line, c.tag))
    if okc then
      c.rel = rel
      for _, d in ipairs(expression.refs(rel.lhs)) do credit(d, c.blueprint.number) end
      for _, d in ipairs(expression.refs(rel.rhs)) do credit(d, c.blueprint.number) end
    else
      note(tostring(rel))
    end
  end

  -- Reported, never fatal. Both are conditions the project should see on every
  -- run, and neither is an error today -- 095 decides what to do about them.
  L.orphans, L.targets = {}, {}
  for _, name in ipairs(L.order) do
    if #L.used_by[name] == 0 then L.orphans[#L.orphans + 1] = name end
    if L.decl[name].kind == "target" then L.targets[#L.targets + 1] = name end
  end

  L.deps = deps
  return L
end
-- }}}

return M
