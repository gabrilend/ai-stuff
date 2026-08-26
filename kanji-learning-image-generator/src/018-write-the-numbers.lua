-- 018-write-the-numbers.lua
--
-- Writes the data format the far end of this project reads, keeping the keys in
-- the order they were put in.
--
-- For a general: the output of this whole project is a structured text file that
-- another program opens. A plain table in this language has no order to its
-- keys -- ask for them back and you get whichever arrangement the internals
-- happened to land on, differently between runs. For a file a person is going
-- to open and a version control system is going to compare, that is not
-- acceptable, and sorting does not fix it: sorted keys put the settings before
-- the name of the thing being configured, which is backwards for reading.
--
-- So there is an ordered table here, and every emitter in this project builds
-- one. Arrays stay ordinary.
--
-- There is no reader. Nothing in this project opens one of these.

local M = {}

-- {{{ ORDERED -- the behaviour an ordered table has
--
-- Assignment goes through a gate that remembers the order keys first appeared.
-- The values live in a table the gate holds rather than in the object itself,
-- which is what leaves the object empty enough for the gate to keep being
-- consulted -- a key written directly onto the object would be found by lookup
-- afterwards and never pass through here again.
local ORDERED = {}

ORDERED.__index = function(self, key)
  local inner = rawget(self, "__values")
  if inner then return inner[key] end
  return nil
end

ORDERED.__newindex = function(self, key, value)
  local inner = rawget(self, "__values")
  local order = rawget(self, "__order")
  if inner[key] == nil and value ~= nil then
    order[#order + 1] = key
  elseif value == nil and inner[key] ~= nil then
    for index, existing in ipairs(order) do
      if existing == key then table.remove(order, index) break end
    end
  end
  inner[key] = value
end
-- }}}

-- {{{ M.object(...)
-- A table that remembers the order its keys were given in.
--
-- Pairs may be passed in directly, which is how most call sites use it:
--   M.object("class_type", "KSampler", "inputs", something)
function M.object(...)
  local self = setmetatable({ __values = {}, __order = {} }, ORDERED)
  local count = select("#", ...)
  for index = 1, count, 2 do
    self[select(index, ...)] = select(index + 1, ...)
  end
  return self
end
-- }}}

-- {{{ M.is_object(value)
function M.is_object(value)
  return type(value) == "table" and getmetatable(value) == ORDERED
end
-- }}}

-- {{{ M.keys(value)
-- An ordered table's keys, in their order.
function M.keys(value)
  return rawget(value, "__order")
end
-- }}}

-- {{{ ESCAPES -- the characters that may not appear as themselves
--
-- The quote and the backslash, and everything below a space. Nothing above
-- that: this project's output is full of kanji, and escaping them would turn
-- every file into a wall of numbers for the person it is meant to be read by.
local ESCAPES = {
  ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
  ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}
for code = 0, 31 do
  local character = string.char(code)
  if not ESCAPES[character] then
    ESCAPES[character] = string.format("\\u%04x", code)
  end
end
-- }}}

-- {{{ write_string(text, out)
local function write_string(text, out)
  out[#out + 1] = '"'
  out[#out + 1] = (text:gsub('[%z\1-\31"\\]', ESCAPES))
  out[#out + 1] = '"'
end
-- }}}

-- {{{ write_number(value, out)
-- A number, printed the way the far end expects to read it.
--
-- A whole number must not come out with a decimal point on it. The program
-- reading this takes a seed and a step count as whole numbers, and a decimal
-- point there is a type error at the far end rather than a cosmetic one -- and
-- it is the default behaviour of this language's number printing, so it has to
-- be worked against rather than left alone.
--
-- The range test is not decoration: past a certain size a floating point number
-- cannot represent every whole number, and printing one as though it were exact
-- would be a quiet lie.
local function write_number(value, out)
  if value ~= value or value == math.huge or value == -math.huge then
    error("a number that is not a number cannot be written: " .. tostring(value))
  end
  if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
    out[#out + 1] = string.format("%d", value)
  else
    -- enough digits to survive a round trip through a double
    out[#out + 1] = string.format("%.17g", value)
  end
end
-- }}}

-- {{{ write_value(value, out, indent, depth)
local function write_value(value, out, indent, depth)
  local kind = type(value)

  if value == nil then
    out[#out + 1] = "null"

  elseif kind == "boolean" then
    out[#out + 1] = value and "true" or "false"

  elseif kind == "number" then
    write_number(value, out)

  elseif kind == "string" then
    write_string(value, out)

  elseif M.is_object(value) then
    local keys = M.keys(value)
    if #keys == 0 then out[#out + 1] = "{}" return end
    local gap = indent and ("\n" .. string.rep(indent, depth + 1)) or ""
    local close = indent and ("\n" .. string.rep(indent, depth)) or ""
    out[#out + 1] = "{"
    for index, key in ipairs(keys) do
      if index > 1 then out[#out + 1] = "," end
      out[#out + 1] = gap
      write_string(tostring(key), out)
      out[#out + 1] = indent and ": " or ":"
      write_value(value[key], out, indent, depth + 1)
    end
    out[#out + 1] = close
    out[#out + 1] = "}"

  elseif kind == "table" then
    -- An ordinary table is an array. An empty one is an empty array, and an
    -- empty ordered table is an empty object -- which is the whole reason the
    -- two are different types here. The format the far end reads contains both
    -- and treats them differently, and a writer that had to guess would be
    -- wrong about one of them.
    local count = #value
    if count == 0 then out[#out + 1] = "[]" return end
    local gap = indent and ("\n" .. string.rep(indent, depth + 1)) or ""
    local close = indent and ("\n" .. string.rep(indent, depth)) or ""
    out[#out + 1] = "["
    for index = 1, count do
      if index > 1 then out[#out + 1] = "," end
      out[#out + 1] = gap
      write_value(value[index], out, indent, depth + 1)
    end
    out[#out + 1] = close
    out[#out + 1] = "]"

  else
    error("a " .. kind .. " cannot be written out")
  end
end
-- }}}

-- {{{ M.encode(value, options)
-- One value, as text.
--
-- options.indent  the string one level of nesting is indented by, or false for
--                 no line breaks at all. Indented by default: these files are
--                 meant to be opened.
function M.encode(value, options)
  options = options or {}
  local indent = options.indent
  if indent == nil then indent = "  " end
  if indent == false then indent = nil end
  local out = {}
  write_value(value, out, indent, 0)
  return table.concat(out)
end
-- }}}

return M
