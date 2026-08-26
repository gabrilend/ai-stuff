-- 092-expression.lua
--
-- Reads the derivation expressions that appear in a blueprint's symbols block,
-- and the relations that appear in its constraints block. Turns text into a
-- tree, tells you which symbols a tree depends on, and evaluates a tree once
-- those symbols have values.
--
-- For a general reader: this is the small language a blueprint is allowed to do
-- arithmetic in. It is deliberately tiny -- the four operations, powers,
-- parentheses, a dozen functions -- and it has one rule that makes the whole
-- notation worth having: a bare number in an expression is always dimensionless.
-- If a derivation needs twenty kelvin, twenty kelvin has to be a symbol
-- somebody named and explained. There is no way to smuggle an unlabelled
-- physical quantity into this project.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local units = dofile(DIR .. "/src/091-units.lua")

local M = {}

-- Collecting the symbols an expression references, and evaluating it, are kept
-- as two separate walks over the same tree. The ledger needs the first before
-- any value exists anywhere, in order to work out what order to resolve things
-- in; a module that only offered evaluation would force it to guess.

-- {{{ local function tokenise()
local function tokenise(s, where)
  local out, i, n = {}, 1, #s
  local function fail(msg, at)
    error(("%s: %s at position %d in %q"):format(where or "expression", msg, at, s), 0)
  end
  while i <= n do
    local c = s:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c:match("[%a_]") then
      local j = i
      while j <= n and s:sub(j, j):match("[%w_]") do j = j + 1 end
      out[#out + 1] = { t = "name", v = s:sub(i, j - 1), at = i }
      i = j
    elseif c:match("%d") or (c == "." and s:sub(i + 1, i + 1):match("%d")) then
      -- a decimal number, optionally with an exponent. Written out rather than
      -- handed to a pattern so that "1e" fails here with a position instead of
      -- silently becoming 1 followed by a symbol called e.
      local j = i
      while j <= n and s:sub(j, j):match("[%d%.]") do j = j + 1 end
      if s:sub(j, j) == "e" or s:sub(j, j) == "E" then
        local k = j + 1
        if s:sub(k, k) == "+" or s:sub(k, k) == "-" then k = k + 1 end
        if not s:sub(k, k):match("%d") then fail("malformed exponent", i) end
        while k <= n and s:sub(k, k):match("%d") do k = k + 1 end
        j = k
      end
      local num = tonumber(s:sub(i, j - 1))
      if not num then fail("malformed number", i) end
      out[#out + 1] = { t = "num", v = num, at = i }
      i = j
    elseif ("+-*/^(),"):find(c, 1, true) then
      out[#out + 1] = { t = c, at = i }
      i = i + 1
    else
      fail(("cannot read %q"):format(c), i)
    end
  end
  out[#out + 1] = { t = "eof", at = n + 1 }
  return out
end
-- }}}

-- How many arguments each function takes. A dispatch table rather than a chain
-- of comparisons, so that adding a function is one line here and one line in
-- the evaluator's table below, and neither is a branch anybody has to read.
local ARITY = {
  sqrt = 1, abs = 1, log = 1, ln = 1, exp = 1, floor = 1, ceil = 1,
  round = 1, sin = 1, cos = 1, tan = 1, atan = 1, min = 2, max = 2,
}

-- {{{ function M.parse()
function M.parse(s, where)
  local tk = tokenise(s, where)
  local pos = 1
  local function peek() return tk[pos] end
  local function take() local t = tk[pos]; pos = pos + 1; return t end
  local function fail(msg, at)
    error(("%s: %s at position %d in %q"):format(where or "expression", msg, at or 0, s), 0)
  end

  local parse_expr

  local function parse_primary()
    local t = take()
    if t.t == "num" then
      return { k = "num", v = t.v, at = t.at }
    elseif t.t == "name" then
      if peek().t == "(" then
        local ar = ARITY[t.v]
        if not ar then fail(("unknown function %q"):format(t.v), t.at) end
        take()
        local args = {}
        args[#args + 1] = parse_expr()
        while peek().t == "," do take(); args[#args + 1] = parse_expr() end
        if take().t ~= ")" then fail("missing ) after function arguments", t.at) end
        if #args ~= ar then
          fail(("%s takes %d argument(s), got %d"):format(t.v, ar, #args), t.at)
        end
        return { k = "call", fn = t.v, args = args, at = t.at }
      end
      if t.v == "pi" then return { k = "num", v = math.pi, at = t.at } end
      return { k = "ref", name = t.v, at = t.at }
    elseif t.t == "(" then
      local e = parse_expr()
      if take().t ~= ")" then fail("missing )", t.at) end
      return e
    elseif t.t == "-" then
      return { k = "neg", a = parse_primary(), at = t.at }
    end
    fail("unexpected token", t.at)
  end

  -- Exponentiation binds tighter than multiplication and is right-associative,
  -- so a^b^c is a^(b^c). Unary minus binds tighter than exponentiation on its
  -- left operand, which is why parse_primary handles it -- -x^2 is -(x^2) in
  -- every language a reader is likely to come from, and matching that is worth
  -- more than any argument about which is more principled.
  local function parse_power()
    local base = parse_primary()
    if peek().t == "^" then
      local at = take().at
      return { k = "pow", a = base, b = parse_power(), at = at }
    end
    return base
  end

  local function parse_mul()
    local a = parse_power()
    while peek().t == "*" or peek().t == "/" do
      local t = take()
      a = { k = t.t == "*" and "mul" or "div", a = a, b = parse_power(), at = t.at }
    end
    return a
  end

  parse_expr = function()
    local a = parse_mul()
    while peek().t == "+" or peek().t == "-" do
      local t = take()
      a = { k = t.t == "+" and "add" or "sub", a = a, b = parse_mul(), at = t.at }
    end
    return a
  end

  local tree = parse_expr()
  if peek().t ~= "eof" then fail("trailing text", peek().at) end
  return tree
end
-- }}}

-- {{{ function M.refs()
-- Every symbol name a tree depends on. Order is deterministic -- first
-- appearance -- so that a dependency graph built from this is the same graph
-- every run, which matters because the ledger's error messages name a cycle in
-- the order it found it.
function M.refs(tree, out, seen)
  out, seen = out or {}, seen or {}
  local k = tree.k
  if k == "ref" then
    if not seen[tree.name] then
      seen[tree.name] = true
      out[#out + 1] = tree.name
    end
  elseif k == "call" then
    for i = 1, #tree.args do M.refs(tree.args[i], out, seen) end
  elseif k == "neg" then
    M.refs(tree.a, out, seen)
  elseif k ~= "num" then
    M.refs(tree.a, out, seen)
    M.refs(tree.b, out, seen)
  end
  return out
end
-- }}}

-- {{{ function M.literals()
-- Every numeric literal in a tree, with its position. Collected so that 095 can
-- warn about the ones that look like unit conversions.
--
-- The rule that every literal is dimensionless stops an unlabelled physical
-- quantity entering a derivation. It does nothing about a *labelled* one being
-- converted twice -- somebody writing `C_weights * 8e9 / B_core` because they
-- were thinking in gigabytes and bits per second rather than trusting the
-- notation to convert. Twenty-seven of those were found in one sweep across the
-- blueprint set, three of which had produced visible failures and the rest of
-- which were silent. One was silent because two of them cancelled.
--
-- They have a signature: a round power of ten, large or small. Ordinary
-- arithmetic uses small numbers -- a two because something has two sides, a
-- polynomial coefficient, a factor of four for a duct's walls. Nothing in real
-- physics needs to be multiplied by eight thousand million.
--
-- A literal standing alone as one whole side of a comparison is not one of
-- these -- `f_overhead < 0.05` is a threshold, not a conversion -- so the root
-- of a tree is skipped. What is looked for is a literal *scaling* something.
function M.literals(tree, out, depth)
  out, depth = out or {}, depth or 0
  local k = tree.k
  if k == "num" then
    if depth > 0 then out[#out + 1] = { v = tree.v, at = tree.at } end
  elseif k == "call" then
    for i = 1, #tree.args do M.literals(tree.args[i], out, depth + 1) end
  elseif k == "neg" then
    M.literals(tree.a, out, depth)
  elseif k ~= "ref" then
    M.literals(tree.a, out, depth + 1)
    M.literals(tree.b, out, depth + 1)
  end
  return out
end
-- }}}

-- {{{ function M.suspicious_literal()
-- Whether a literal looks like a hand-written unit conversion rather than
-- arithmetic. Large or tiny, and near a round power of ten.
function M.suspicious_literal(v)
  local a = math.abs(v)
  if a == 0 then return false end
  if a < 1000 and a > 0.001 then return false end
  -- near a round power of ten, or a small integer times one
  local e = math.floor(math.log(a) / math.log(10) + 0.5)
  local m = a / (10 ^ e)
  return m > 0.95 and m < 1.05 or (a >= 1000 and a / (10 ^ math.floor(math.log(a)/math.log(10))) % 1 == 0)
end
-- }}}

-- {{{ local function need_dimensionless()
local function need_dimensionless(q, fn)
  if not units.dim_equal(q.d, units.DIMENSIONLESS) then
    error(("%s needs a dimensionless argument, got %s")
          :format(fn, units.dim_name(q.d)), 0)
  end
end
-- }}}

-- What each function does to a value and to its dimension. Kept as a table for
-- the same reason ARITY is: the alternative is a fourteen-branch conditional
-- that nobody reads and everybody adds to.
local FN = {
  -- sqrt halves the dimension, which only works if every exponent is even.
  -- A square root of a cubic metre is not expressible in this vector and
  -- failing loudly beats inventing a fractional exponent nothing can print.
  sqrt = function(q)
    local d = {}
    for i = 1, 10 do
      local e = q.d[i]
      if e % 2 ~= 0 then
        error(("sqrt of %s has a fractional dimension"):format(units.dim_name(q.d)), 0)
      end
      d[i] = e / 2
    end
    return units.raw(math.sqrt(q.v), d)
  end,
  abs   = function(q) return units.raw(math.abs(q.v), q.d) end,
  log   = function(q) need_dimensionless(q, "log");  return units.raw(math.log(q.v) / math.log(10), q.d) end,
  ln    = function(q) need_dimensionless(q, "ln");   return units.raw(math.log(q.v), q.d) end,
  exp   = function(q) need_dimensionless(q, "exp");  return units.raw(math.exp(q.v), q.d) end,
  sin   = function(q) need_dimensionless(q, "sin");  return units.raw(math.sin(q.v), q.d) end,
  cos   = function(q) need_dimensionless(q, "cos");  return units.raw(math.cos(q.v), q.d) end,
  tan   = function(q) need_dimensionless(q, "tan");  return units.raw(math.tan(q.v), q.d) end,
  atan  = function(q) need_dimensionless(q, "atan"); return units.raw(math.atan(q.v), q.d) end,
  -- floor, ceil and round keep the dimension. Rounding a count of channels to
  -- a whole number is the commonest use in this project and refusing it would
  -- make the microchannel blueprint impossible to write.
  floor = function(q) return units.raw(math.floor(q.v), q.d) end,
  ceil  = function(q) return units.raw(math.ceil(q.v), q.d) end,
  round = function(q) return units.raw(math.floor(q.v + 0.5), q.d) end,
  min   = function(a, b)
    if not units.dim_equal(a.d, b.d) then
      error(("min of %s and %s"):format(units.dim_name(a.d), units.dim_name(b.d)), 0)
    end
    return units.raw(math.min(a.v, b.v), a.d)
  end,
  max   = function(a, b)
    if not units.dim_equal(a.d, b.d) then
      error(("max of %s and %s"):format(units.dim_name(a.d), units.dim_name(b.d)), 0)
    end
    return units.raw(math.max(a.v, b.v), a.d)
  end,
}

local BINOP = {
  add = function(a, b) return a + b end,
  sub = function(a, b) return a - b end,
  mul = function(a, b) return a * b end,
  div = function(a, b) return a / b end,
  pow = function(a, b) return a ^ b end,
}

-- {{{ function M.eval()
-- Evaluate a tree against a table of name to quantity. Anything that goes wrong
-- is raised with the expression's own position attached by the caller, because
-- an arithmetic error with no location is a scavenger hunt.
function M.eval(tree, symbols)
  local k = tree.k
  if k == "num" then
    -- The rule. A literal is dimensionless, always, with no exception and no
    -- unit suffix. Everything else in the notation follows from this.
    return units.raw(tree.v, units.DIMENSIONLESS)
  elseif k == "ref" then
    local q = symbols[tree.name]
    if q == nil then
      error(("undefined symbol %q"):format(tree.name), 0)
    end
    return q
  elseif k == "neg" then
    return -M.eval(tree.a, symbols)
  elseif k == "call" then
    local f = FN[tree.fn]
    if #tree.args == 1 then return f(M.eval(tree.args[1], symbols)) end
    return f(M.eval(tree.args[1], symbols), M.eval(tree.args[2], symbols))
  end
  local op = BINOP[k]
  if not op then error("expression: unknown node kind " .. tostring(k), 0) end
  return op(M.eval(tree.a, symbols), M.eval(tree.b, symbols))
end
-- }}}

-- The comparison operators a constraint may use. Longest first, so that "<="
-- is not read as "<" followed by "=".
local RELOPS = { "<=", ">=", "==", "~=", "<", ">" }

-- {{{ function M.parse_relation()
-- Split "a <= b" into its two sides and the operator between them, and parse
-- both sides. Refuses a relation with no operator or with two, because either
-- is a line somebody meant to write differently.
function M.parse_relation(s, where)
  local found, fat, flen = nil, nil, nil
  for _, op in ipairs(RELOPS) do
    local at = s:find(op, 1, true)
    if at and (not fat or at < fat) then
      found, fat, flen = op, at, #op
    end
  end
  if not found then
    error(("%s: no comparison operator in %q"):format(where or "constraint", s), 0)
  end
  local lhs = s:sub(1, fat - 1)
  local rhs = s:sub(fat + flen)
  if rhs:find("[<>=~]") then
    error(("%s: more than one comparison in %q"):format(where or "constraint", s), 0)
  end
  return {
    op = found,
    lhs = M.parse(lhs, where),
    rhs = M.parse(rhs, where),
    lhs_text = lhs:gsub("^%s+", ""):gsub("%s+$", ""),
    rhs_text = rhs:gsub("^%s+", ""):gsub("%s+$", ""),
  }
end
-- }}}

return M
