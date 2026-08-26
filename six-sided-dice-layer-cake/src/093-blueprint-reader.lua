-- 093-blueprint-reader.lua
--
-- Turns one blueprint file into a structure: what it declares, what it
-- constrains, and what it draws. One file in, one table out, and it looks at
-- nothing else -- the place where files meet each other is 094, and keeping
-- that separation is what makes this testable against a fixture.
--
-- For a general reader: a blueprint is a markdown document with three kinds of
-- fenced block in it that a program is meant to read. This is the program. It
-- refuses malformed blocks rather than guessing at them, because a reader that
-- tolerates a bad declaration produces a design that is quietly missing a
-- number.

local M = {}

local VALID_KIND = {
  given = true, derived = true, measured = true, target = true, solved = true,
}

-- {{{ local function trim()
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
-- }}}

-- {{{ local function split_bar()
-- Split a declaration line on vertical bars. Written out rather than done with
-- gmatch so that an empty field between two bars survives as an empty string
-- instead of vanishing, which is the difference between "this field is blank"
-- and "this line has fewer fields than it should".
local function split_bar(line)
  local out, start = {}, 1
  while true do
    local at = line:find("|", start, true)
    if not at then
      out[#out + 1] = trim(line:sub(start))
      return out
    end
    out[#out + 1] = trim(line:sub(start, at - 1))
    start = at + 1
  end
end
-- }}}

-- One handler per fenced block tag. A dispatch table rather than a chain of
-- comparisons: adding a fourth kind of block is one entry here and nothing
-- anywhere else.
local BLOCK = {}

-- {{{ BLOCK.meta()
BLOCK.meta = function(bp, lines, fail)
  for _, ln in ipairs(lines) do
    local f = split_bar(ln.text)
    if #f ~= 2 then fail(ln.n, "a meta line needs exactly two fields") end
    local key, value = f[1], f[2]
    if key == "phase" then
      bp.phase = tonumber(value)
      if not bp.phase then fail(ln.n, "phase must be a number") end
    elseif key == "issues" then
      bp.issues = {}
      for id in value:gmatch("[^,%s]+") do bp.issues[#bp.issues + 1] = id end
    else
      fail(ln.n, ("unknown meta key %q"):format(key))
    end
  end
end
-- }}}

-- {{{ BLOCK.symbols()
BLOCK.symbols = function(bp, lines, fail)
  for _, ln in ipairs(lines) do
    local f = split_bar(ln.text)
    if #f ~= 5 then
      fail(ln.n, ("a symbol declaration needs five fields, found %d"):format(#f))
    end
    local name, unit, kind, value, meaning = f[1], f[2], f[3], f[4], f[5]
    if name == "" then fail(ln.n, "symbol has no name") end
    if not VALID_KIND[kind] then
      fail(ln.n, ("kind must be given, derived, measured, solved or target, not %q")
                 :format(kind))
    end
    if meaning == "" then fail(ln.n, ("symbol %s has no meaning"):format(name)) end
    -- A given or a measured carries a bare number. Anything else there is a
    -- derivation wearing the wrong label, and the two are treated differently
    -- everywhere downstream, so it has to be caught at the door.
    local literal = nil
    if kind == "given" or kind == "measured" or kind == "solved" then
      literal = tonumber(value)
      if not literal then
        fail(ln.n, ("%s is %s, so its value must be a bare number, not %q")
                   :format(name, kind, value))
      end
      -- A solved value is one an instrument computed because the notation's own
      -- arithmetic cannot express the computation -- an iterative solve, a
      -- search over a discrete set. The number here is a copy of that answer,
      -- and a copy goes stale, so the declaration has to say which program to
      -- ask. 095 re-runs that program and refuses if the two have drifted apart.
      -- Without the name there is nothing to re-run and the kind would be a
      -- comment.
      --
      -- The name is written as "-- from NNN" in the meaning, and the marker is
      -- there because meanings are prose: the first attempt took the first
      -- three-digit number it found and picked up a cross-reference to another
      -- blueprint out of the middle of a sentence, then reported that blueprint
      -- as a program that would not load.
      if kind == "solved" and not meaning:match("%-%- from (%d%d%d)") then
        fail(ln.n, ("solved symbol %s must name the instrument that produced it, "
                    .. "written as \"-- from NNN\" in its meaning"):format(name))
      end
    elseif kind == "target" then
      -- A target is a placeholder for a derivation nobody has written. Most are
      -- a bare number standing in for one, and those carry the declared unit
      -- exactly as a given does -- a target in seconds that resolved to a
      -- dimensionless number would fail against every other time in the project
      -- for a reason that has nothing to do with its being unfinished. A target
      -- may also be a partial expression, which is left as one.
      literal = tonumber(value)
    elseif kind == "derived" then
      if value == "" then fail(ln.n, ("derived symbol %s has no expression"):format(name)) end
    end
    bp.symbols[#bp.symbols + 1] = {
      name = name, unit = unit, kind = kind, expr = value,
      literal = literal, meaning = meaning,
      file = bp.file, line = ln.n,
    }
  end
end
-- }}}

-- {{{ BLOCK.constraints()
BLOCK.constraints = function(bp, lines, fail)
  for _, ln in ipairs(lines) do
    local f = split_bar(ln.text)
    if #f ~= 3 then
      fail(ln.n, ("a constraint needs three fields, found %d"):format(#f))
    end
    if f[1] == "" then fail(ln.n, "constraint has no tag") end
    if f[3] == "" then fail(ln.n, ("constraint %s has no reason"):format(f[1])) end
    bp.constraints[#bp.constraints + 1] = {
      tag = f[1], relation = f[2], reason = f[3],
      file = bp.file, line = ln.n,
    }
  end
end
-- }}}

-- {{{ BLOCK.drawing()
-- A drawing's first line is its caption and the rest is the picture. Every
-- bracketed word in the picture is a symbol reference, and 098 is what checks
-- that they exist -- here they are only collected.
BLOCK.drawing = function(bp, lines, fail)
  if #lines == 0 then fail(0, "empty drawing block") end
  -- The caption test exists to catch a drawing whose author forgot the caption
  -- and began the picture immediately. It looks for the two things a picture
  -- line has and a caption does not: a bracketed symbol reference, or a bar.
  -- It deliberately does not reject every bracket, because a caption is allowed
  -- to carry the marker that says this drawing is not dimensioned on purpose.
  local caption = trim(lines[1].text)
  if caption == "" or caption:find("%[[%w_]+%]") or caption:find("|", 1, true) then
    fail(lines[1].n, "a drawing's first line must be its caption")
  end
  local body, names = {}, {}
  for i = 2, #lines do
    body[#body + 1] = lines[i].text
    for nm in lines[i].text:gmatch("%[([%w_]+)%]") do
      names[#names + 1] = { name = nm, line = lines[i].n }
    end
  end
  bp.drawings[#bp.drawings + 1] = {
    caption = caption, body = table.concat(body, "\n"), refs = names,
    file = bp.file, line = lines[1].n,
  }
end
-- }}}

-- {{{ function M.read_string()
-- The reader proper. Blocks may appear as many times as they like and are
-- accumulated, because a long blueprint reads far better with its symbols
-- beside the prose that introduces them than with all of them gathered at the
-- bottom.
function M.read_string(text, filename)
  local bp = {
    file = filename or "<string>",
    symbols = {}, constraints = {}, drawings = {},
  }
  local function fail(line, msg)
    error(("%s:%s: %s"):format(bp.file, tostring(line), msg), 0)
  end

  local lineno, in_tag, buf, fence_line = 0, nil, nil, nil
  for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
    lineno = lineno + 1
    if in_tag then
      if raw:match("^%s*```%s*$") then
        BLOCK[in_tag](bp, buf, fail)
        in_tag, buf = nil, nil
      else
        local t = trim(raw)
        -- Blank lines and comments are how a long block is made readable, and
        -- neither is data. A drawing keeps its blank lines and its leading
        -- spaces, because in a drawing they are the picture.
        if in_tag == "drawing" then
          buf[#buf + 1] = { text = raw, n = lineno }
        elseif t ~= "" and t:sub(1, 1) ~= "#" then
          buf[#buf + 1] = { text = t, n = lineno }
        end
      end
    else
      local tag = raw:match("^%s*```%s*(%a+)%s*$")
      if tag and BLOCK[tag] then
        in_tag, buf, fence_line = tag, {}, lineno
      elseif not bp.number then
        local num, title = raw:match("^#%s+(%d+%a?)%s+[-\226\128\148]+%s+(.+)$")
        if num then bp.number, bp.title = num, trim(title) end
      end
    end
  end
  if in_tag then fail(fence_line, ("unclosed %s block"):format(in_tag)) end
  if not bp.number then fail(1, "no heading of the form '# NNN -- Title'") end
  if not bp.phase then fail(1, "no meta block, or no phase in it") end
  return bp
end
-- }}}

-- {{{ function M.read()
function M.read(path)
  local fh, err = io.open(path, "r")
  if not fh then error("blueprint: cannot open " .. tostring(err), 0) end
  local text = fh:read("*a")
  fh:close()
  local name = path:match("([^/]+)$") or path
  return M.read_string(text, name)
end
-- }}}

return M
