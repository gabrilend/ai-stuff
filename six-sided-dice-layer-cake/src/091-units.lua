-- 091-units.lua
--
-- Quantities that know what they are, and refuse to be added to things they are
-- not. Every number in this project's blueprints is a value plus a dimension;
-- this file is where the dimension lives and where arithmetic on it is enforced.
--
-- For a general reader: the point is that a length and a temperature cannot be
-- added, a power divided by a voltage is a current whether or not anybody said
-- so, and a bandwidth in bits per second is a different kind of thing from a
-- clock in hertz even though both are one-over-seconds. The last of those is
-- the reason this file has ten slots where physics only needs seven.

local M = {}

-- The dimension vector. Ten slots, in this fixed order, and the order is part
-- of the file format in the sense that nothing outside here may assume a
-- different one.
--
--   1..7  the international system's base dimensions
--   8     bit   -- information
--   9     tok   -- tokens, the thing this machine produces
--  10     flop  -- floating point operations
--
-- Slots eight through ten are not physics. They exist because bits per second,
-- tokens per second and operations per second are all reciprocal seconds, and
-- confusing any two of them is a mistake somebody will make in a bandwidth
-- blueprint. Without these slots nothing catches it; with them, the addition
-- simply refuses. Three extra integers to make a whole class of error
-- impossible is the cheapest thing in this project.
M.SLOTS = { "m", "kg", "s", "A", "K", "mol", "cd", "bit", "tok", "flop" }
local NSLOT = 10

-- {{{ local function newdim()
local function newdim(t)
  local d = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
  if t then
    for i = 1, NSLOT do d[i] = t[i] or 0 end
  end
  return d
end
-- }}}

-- {{{ local function dim_equal()
local function dim_equal(a, b)
  for i = 1, NSLOT do
    if a[i] ~= b[i] then return false end
  end
  return true
end
-- }}}

-- {{{ local function dim_add()
local function dim_add(a, b, sign)
  local d = newdim()
  for i = 1, NSLOT do d[i] = a[i] + sign * b[i] end
  return d
end
-- }}}

-- {{{ local function dim_scale()
local function dim_scale(a, k)
  local d = newdim()
  for i = 1, NSLOT do d[i] = a[i] * k end
  return d
end
-- }}}

-- {{{ local function dim_name()
-- A dimension rendered as something a person can read in an error message.
-- "m*kg/s^2" rather than a vector of ten integers, because the error message is
-- the whole value of this module and a vector teaches nobody anything.
local function dim_name(d)
  local num, den = {}, {}
  for i = 1, NSLOT do
    local e = d[i]
    if e > 0 then
      num[#num + 1] = (e == 1) and M.SLOTS[i] or (M.SLOTS[i] .. "^" .. e)
    elseif e < 0 then
      den[#den + 1] = (e == -1) and M.SLOTS[i] or (M.SLOTS[i] .. "^" .. (-e))
    end
  end
  if #num == 0 and #den == 0 then return "1" end
  local s = (#num > 0) and table.concat(num, "*") or "1"
  if #den > 0 then s = s .. "/" .. table.concat(den, "*") end
  return s
end
-- }}}

M.dim_name = dim_name
M.dim_equal = dim_equal

-- The unit table. Each entry is { scale, dimension }, where scale converts the
-- named unit into the base units above.
--
-- A note on what is deliberately absent: tesla is not here, because its symbol
-- collides with the tera prefix and nothing in this project measures a magnetic
-- field. Hour is spelled "hr" for the same reason -- "h" is the hecto prefix and
-- also the henry. Where a symbol would be ambiguous the rule is to drop the unit
-- rather than the prefix, because prefixes are used everywhere and these units
-- are used nowhere.
local U = {}

-- {{{ local function defunit()
local function defunit(name, scale, exps)
  U[name] = { scale, newdim(exps) }
end
-- }}}

-- base, and the awkward one: the kilogram is a base unit with a prefix already
-- attached, so the gram is what carries prefixes and the kilogram is defined
-- from it.
defunit("m",    1,     { 1 })
defunit("g",    1e-3,  { 0, 1 })
defunit("s",    1,     { 0, 0, 1 })
defunit("A",    1,     { 0, 0, 0, 1 })
defunit("K",    1,     { 0, 0, 0, 0, 1 })
defunit("mol",  1,     { 0, 0, 0, 0, 0, 1 })
defunit("cd",   1,     { 0, 0, 0, 0, 0, 0, 1 })
defunit("bit",  1,     { 0, 0, 0, 0, 0, 0, 0, 1 })
defunit("tok",  1,     { 0, 0, 0, 0, 0, 0, 0, 0, 1 })
defunit("flop", 1,     { 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 })

-- derived
defunit("N",    1,     { 1, 1, -2 })
defunit("Pa",   1,     { -1, 1, -2 })
defunit("J",    1,     { 2, 1, -2 })
defunit("W",    1,     { 2, 1, -3 })
defunit("C",    1,     { 0, 0, 1, 1 })
defunit("V",    1,     { 2, 1, -3, -1 })
defunit("ohm",  1,     { 2, 1, -3, -2 })
defunit("S",    1,     { -2, -1, 3, 2 })
defunit("F",    1,     { -2, -1, 4, 2 })
defunit("H",    1,     { 2, 1, -2, -2 })
defunit("Hz",   1,     { 0, 0, -1 })

-- convenience, all of which are exactly some multiple of the above
defunit("B",    8,     { 0, 0, 0, 0, 0, 0, 0, 1 })   -- byte
defunit("L",    1e-3,  { 3 })                        -- litre
defunit("min",  60,    { 0, 0, 1 })
defunit("hr",   3600,  { 0, 0, 1 })
defunit("bar",  1e5,   { -1, 1, -2 })
defunit("ppm",  1e-6,  {})
defunit("pct",  1e-2,  {})

local PREFIX = {
  f = 1e-15, p = 1e-12, n = 1e-9, u = 1e-6, m = 1e-3, c = 1e-2, d = 1e-1,
  da = 1e1, h = 1e2, k = 1e3, M = 1e6, G = 1e9, T = 1e12, P = 1e15,
}

-- {{{ local function lookup_unit()
-- Resolve one unit word. Exact match first, then prefix plus unit -- so "m" is
-- the metre and "mm" is milli plus metre, which is the whole reason the order
-- matters.
local function lookup_unit(w)
  local e = U[w]
  if e then return e[1], e[2] end
  -- two-character prefixes first, so "da" is not read as deci followed by "a"
  for plen = 2, 1, -1 do
    if #w > plen then
      local p = PREFIX[w:sub(1, plen)]
      if p then
        local rest = U[w:sub(plen + 1)]
        if rest then return p * rest[1], rest[2] end
      end
    end
  end
  return nil
end
-- }}}

-- The unit expression parser. A tiny recursive descent over
--
--   unit   := term (('*' | '/') term)*
--   term   := factor ('^' integer)?
--   factor := word | number | '(' unit ')'
--
-- Small enough that a parser generator would be more code than the parser.

-- {{{ local function unit_tokens()
local function unit_tokens(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c:match("[%a_]") then
      local j = i
      while j <= n and s:sub(j, j):match("[%w_]") do j = j + 1 end
      out[#out + 1] = { t = "word", v = s:sub(i, j - 1), at = i }
      i = j
    elseif c:match("%d") then
      local j = i
      while j <= n and s:sub(j, j):match("%d") do j = j + 1 end
      out[#out + 1] = { t = "num", v = tonumber(s:sub(i, j - 1)), at = i }
      i = j
    elseif c == "*" or c == "/" or c == "^" or c == "(" or c == ")" or c == "-" then
      out[#out + 1] = { t = c, at = i }
      i = i + 1
    else
      error(("units: cannot read %q in unit %q at %d"):format(c, s, i), 0)
    end
  end
  out[#out + 1] = { t = "eof", at = n + 1 }
  return out
end
-- }}}

-- {{{ local function parse_unit()
local function parse_unit(s)
  local tk = unit_tokens(s)
  local pos = 1
  local function peek() return tk[pos] end
  local function take() local t = tk[pos]; pos = pos + 1; return t end

  local parse_expr

  local function parse_factor()
    local t = take()
    if t.t == "word" then
      local sc, d = lookup_unit(t.v)
      if not sc then
        error(("units: unknown unit %q in %q"):format(t.v, s), 0)
      end
      return sc, d
    elseif t.t == "num" then
      -- the only legal bare number in a unit is 1, meaning dimensionless. Any
      -- other number would be a scale factor hiding in a unit string, which is
      -- exactly the unnamed magic constant the notation exists to forbid.
      if t.v ~= 1 then
        error(("units: %d is not a unit in %q; only 1 means dimensionless")
              :format(t.v, s), 0)
      end
      return 1, newdim()
    elseif t.t == "(" then
      local sc, d = parse_expr()
      if take().t ~= ")" then
        error(("units: missing ) in %q"):format(s), 0)
      end
      return sc, d
    end
    error(("units: unexpected token in %q at %d"):format(s, t.at or 0), 0)
  end

  local function parse_term()
    local sc, d = parse_factor()
    if peek().t == "^" then
      take()
      local neg = false
      if peek().t == "-" then take(); neg = true end
      local e = take()
      if e.t ~= "num" then
        error(("units: exponent must be an integer in %q"):format(s), 0)
      end
      local k = neg and -e.v or e.v
      return sc ^ k, dim_scale(d, k)
    end
    return sc, d
  end

  parse_expr = function()
    local sc, d = parse_term()
    while peek().t == "*" or peek().t == "/" do
      local op = take().t
      local sc2, d2 = parse_term()
      if op == "*" then
        sc, d = sc * sc2, dim_add(d, d2, 1)
      else
        sc, d = sc / sc2, dim_add(d, d2, -1)
      end
    end
    return sc, d
  end

  local sc, d = parse_expr()
  if peek().t ~= "eof" then
    error(("units: trailing text in unit %q"):format(s), 0)
  end
  return sc, d
end
-- }}}

M.parse_unit = parse_unit

-- The quantity type. A value already converted to base units, and a dimension.
-- Conversion happens once, at construction, so that no derivation anywhere in
-- the project depends on which unit a symbol happened to be declared in.

local Q = {}
Q.__index = Q

-- A quantity is recognised by a marker field rather than by the identity of its
-- metatable. That looks like a needless indirection until this file is loaded
-- twice in one process -- which happens whenever two modules each reach for it
-- with dofile, since dofile does not cache. Two loads means two metatables, and
-- a quantity built by one copy would then be rejected by the other with a
-- message about not being a quantity, which is both wrong and baffling. A
-- marker field is the same test without the identity trap.
local MARK = "quantity/091"

-- {{{ local function isq()
local function isq(x)
  return type(x) == "table" and rawget(x, "mark") == MARK
end
-- }}}

-- {{{ local function coerce()
-- A bare Lua number appearing in arithmetic is treated as dimensionless. This
-- is what makes `2 * t_face` work while `T_amb + 20` fails: the two is pure and
-- the twenty is not, and only the second one is a physical quantity wearing no
-- label.
local function coerce(x)
  if isq(x) then return x end
  if type(x) == "number" then
    return setmetatable({ mark = MARK, v = x, d = newdim() }, Q)
  end
  error("units: expected a quantity or a number, got " .. type(x), 0)
end
-- }}}

-- {{{ function M.new()
function M.new(value, unit)
  local sc, d = parse_unit(unit or "1")
  return setmetatable({ mark = MARK, v = value * sc, d = d }, Q)
end
-- }}}

-- {{{ function M.raw()
-- A quantity built directly from base-unit value and dimension. Used by the
-- expression evaluator, which has already done the conversion.
function M.raw(value, d)
  return setmetatable({ mark = MARK, v = value, d = newdim(d) }, Q)
end
-- }}}

M.isq = isq
M.DIMENSIONLESS = newdim()

-- {{{ local function require_same()
local function require_same(a, b, what)
  if dim_equal(a.d, b.d) then return end
  -- One side dimensionless and the other not is almost always the same mistake:
  -- somebody wrote a bare number where a physical quantity belongs. It is the
  -- error every author of a blueprint makes on their first day, so it gets the
  -- sentence that teaches the rule rather than the one that states the symptom.
  local ad, bd = dim_name(a.d), dim_name(b.d)
  if ad == "1" or bd == "1" then
    error(("units: cannot %s %s and %s -- a bare number in an expression is " ..
           "always dimensionless. If this was meant to be a physical quantity, " ..
           "declare it as a symbol with a unit and a meaning.")
          :format(what, ad, bd), 0)
  end
  error(("units: cannot %s %s and %s"):format(what, ad, bd), 0)
end
-- }}}

-- Arithmetic. Addition and subtraction refuse across dimensions; multiplication
-- and division combine them; powers scale them. There is no coercion anywhere
-- and no path by which a mismatch produces a number instead of an error, which
-- is the single property the rest of the project relies on.

function Q.__add(a, b)
  a, b = coerce(a), coerce(b); require_same(a, b, "add")
  return M.raw(a.v + b.v, a.d)
end

function Q.__sub(a, b)
  a, b = coerce(a), coerce(b); require_same(a, b, "subtract")
  return M.raw(a.v - b.v, a.d)
end

function Q.__mul(a, b)
  a, b = coerce(a), coerce(b)
  return M.raw(a.v * b.v, dim_add(a.d, b.d, 1))
end

function Q.__div(a, b)
  a, b = coerce(a), coerce(b)
  if b.v == 0 then error("units: division by zero", 0) end
  return M.raw(a.v / b.v, dim_add(a.d, b.d, -1))
end

function Q.__unm(a) return M.raw(-a.v, a.d) end

function Q.__pow(a, b)
  a, b = coerce(a), coerce(b)
  if not dim_equal(b.d, M.DIMENSIONLESS) then
    error("units: exponent must be dimensionless, got " .. dim_name(b.d), 0)
  end
  -- A dimensional base may only be raised to a whole power, because half a
  -- metre-dimension is not a thing this vector can hold. A dimensionless base
  -- may be raised to anything, which is what lets a ratio be raised to 0.8 in a
  -- correlation.
  if not dim_equal(a.d, M.DIMENSIONLESS) and b.v ~= math.floor(b.v) then
    error(("units: cannot raise %s to a fractional power"):format(dim_name(a.d)), 0)
  end
  return M.raw(a.v ^ b.v, dim_scale(a.d, b.v))
end

function Q.__eq(a, b)
  return dim_equal(a.d, b.d) and a.v == b.v
end

function Q.__lt(a, b)
  a, b = coerce(a), coerce(b); require_same(a, b, "compare")
  return a.v < b.v
end

function Q.__le(a, b)
  a, b = coerce(a), coerce(b); require_same(a, b, "compare")
  return a.v <= b.v
end

-- {{{ function M.value_in()
-- The value of a quantity expressed in a named unit. Raises if the unit does
-- not match the quantity's dimension, which is how a specification sheet is
-- stopped from printing a length in watts.
function M.value_in(q, unit)
  local sc, d = parse_unit(unit)
  if not dim_equal(q.d, d) then
    error(("units: cannot express %s as %s"):format(dim_name(q.d), unit), 0)
  end
  return q.v / sc
end
-- }}}

-- {{{ function M.format()
-- Human-readable. Given a unit, uses it; given none, falls back to base units,
-- which is correct and often unreadable -- so every place that prints for a
-- person is expected to name a unit rather than rely on this.
function M.format(q, unit, digits)
  digits = digits or 6
  local n = unit and M.value_in(q, unit) or q.v
  local label = unit or dim_name(q.d)
  -- A pure count reads worse with a unit than without one. "173 1" is correct
  -- and looks like a typing accident; "173" is what a person wants to see.
  if label == "1" then return ("%." .. digits .. "g"):format(n) end
  return ("%." .. digits .. "g %s"):format(n, label)
end
-- }}}

function Q.__tostring(q) return M.format(q) end

return M
