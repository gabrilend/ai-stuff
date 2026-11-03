-- ceramic-corporation — an organisation as a map everyone can read
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
-- General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- 007-org-reader.lua
--
-- Reads an org's files and refuses what breaks the org map's rules, by name.
--
-- Every tool in this project reads through here, so that there is one answer
-- to "what does this line mean". Each refusal carries the rule code from
-- docs/002-the-org-map.md, the file and the line, and the reader collects
-- every problem rather than stopping at the first: one mistake usually makes a
-- family of complaints, and seeing the family is what finds the cause.
--
-- Run directly, it is the validator: `luajit 007-org-reader.lua ORG_DIR`
-- prints every problem and warning and exits 0 only when the org is valid.

local M = {}

-- The seven kinds of change, in the order documents list them. A rule block is
-- named after one of these.
M.KINDS = { "inside", "holding", "wiring", "boxes", "doors", "people", "rules" }
local IS_KIND = {}
for _, kind in ipairs(M.KINDS) do IS_KIND[kind] = true end

local MAP_HEADS = { org = true, person = true, outside = true, role = true,
                    work = true, rule = true }

-- Which body keywords each head allows (M5).
local BODY_ALLOWED = {
  org     = { says = true },
  person  = { says = true },
  outside = { says = true, ["spoken-for-by"] = true },
  role    = { says = true, ["held-by"] = true, ["in"] = true, out = true, inside = true },
  work    = { says = true, ["held-by"] = true, ["in"] = true, out = true, inside = true },
  rule    = { approve = true, waits = true },
}
M.BODY_ALLOWED = BODY_ALLOWED

-- {{{ local function complain()
local function complain(list, file, line, code, format, ...)
  list[#list + 1] = { file = file, line = line, code = code,
                      message = string.format(format, ...) }
end
M.complain = complain
-- }}}

-- {{{ function M.format_problem()
function M.format_problem(p)
  return string.format("%s:%s: %s %s", p.file, tostring(p.line or "-"), p.code, p.message)
end
-- }}}

-- {{{ function M.is_name()
-- L7: a name is lowercase letters, digits and hyphens, starting with a letter
-- or digit, at most 64 characters.
function M.is_name(s)
  return type(s) == "string" and #s >= 1 and #s <= 64
     and s:match("^[a-z0-9][a-z0-9%-]*$") ~= nil
end
-- }}}

-- {{{ function M.is_date()
-- L8: YYYY-MM-DD, and a day that exists.
function M.is_date(s)
  if type(s) ~= "string" then return false end
  local y, m, d = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then return false end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if m < 1 or m > 12 or d < 1 then return false end
  local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local leap = (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
  if leap then days[2] = 29 end
  return d <= days[m]
end
-- }}}

-- {{{ function M.day_number()
-- Days since 1970-01-01 for a valid date, by the civil-from-days algorithm in
-- reverse. Only differences between two of these are ever used.
function M.day_number(s)
  local y, m, d = s:match("^(%d+)%-(%d+)%-(%d+)$")
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end
-- }}}

-- {{{ function M.split_fields()
-- L6: fields separated by one or more spaces; a quoted field begins and ends
-- with a double quote, with \" and \\ as its only escapes. Returns the field
-- texts and a parallel table saying which were quoted, or nil and a message.
function M.split_fields(s)
  local fields, quoted = {}, {}
  local i, n = 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c == " " then
      i = i + 1
    elseif c == '"' then
      local buf, j, closed = {}, i + 1, false
      while j <= n do
        local d = s:sub(j, j)
        if d == "\\" then
          local e = s:sub(j + 1, j + 1)
          if e == '"' or e == "\\" then
            buf[#buf + 1] = e
            j = j + 2
          else
            return nil, "a backslash inside quotes escapes only \" and \\"
          end
        elseif d == '"' then
          closed = true
          j = j + 1
          break
        else
          buf[#buf + 1] = d
          j = j + 1
        end
      end
      if not closed then return nil, "a quoted field is never closed" end
      if j <= n and s:sub(j, j) ~= " " then
        return nil, "a quoted field runs straight into the next one"
      end
      fields[#fields + 1] = table.concat(buf)
      quoted[#fields] = true
      i = j
    else
      local j = s:find(" ", i, true) or (n + 1)
      local word = s:sub(i, j - 1)
      if word:find('"', 1, true) then
        return nil, "a quote in the middle of a word"
      end
      fields[#fields + 1] = word
      quoted[#fields] = false
      i = j
    end
  end
  return fields, quoted
end
-- }}}

-- {{{ function M.lex()
-- L1-L5: split a file's text into classified lines. Every line comes back,
-- blank and comment lines included, because the proposal tool edits the text
-- and has to put every line back where it was.
function M.lex(text, file, problems)
  local lines = {}
  if #text > 0 and text:sub(-1) ~= "\n" then
    complain(problems, file, nil, "L1", "the last line does not end with a newline")
    text = text .. "\n"
  end
  local n = 0
  local current_head = nil
  for raw in text:gmatch("([^\n]*)\n") do
    n = n + 1
    local line = { n = n, raw = raw }
    lines[n] = line
    if raw:find("\t", 1, true) or raw:find("\r", 1, true) then
      complain(problems, file, n, "L2", "a tab or carriage return")
      line.kind = "bad"
    elseif raw ~= "" and raw:sub(-1) == " " then
      complain(problems, file, n, "L3", "trailing space")
      line.kind = "bad"
    elseif raw == "" then
      line.kind = "blank"
    elseif raw:match("^ *#") then
      line.kind = "comment"
    elseif raw:sub(1, 1) ~= " " then
      line.kind = "head"
    elseif raw:match("^  [^ ]") then
      line.kind = "body"
    else
      complain(problems, file, n, "L4", "indented by something other than exactly two spaces")
      line.kind = "bad"
    end
    if line.kind == "head" or line.kind == "body" then
      local fields, quoted = M.split_fields(line.kind == "head" and raw or raw:sub(3))
      local stray = nil
      if fields then
        for i = 2, #fields do
          if not quoted[i] and fields[i]:sub(1, 1) == "#" then stray = i end
        end
      end
      if not fields then
        complain(problems, file, n, "L6", "%s", quoted)
        line.kind = "bad"
      elseif stray then
        complain(problems, file, n, "L9", "a comment after a line's fields: comments are whole lines")
        line.kind = "bad"
      else
        line.fields, line.quoted = fields, quoted
        line.text = line.kind == "head" and raw or raw:sub(3)
      end
    end
    if line.kind == "head" then
      current_head = line
      line.body = {}
    elseif line.kind == "body" then
      if current_head == nil then
        complain(problems, file, n, "L5", "a body line with no head above it")
        line.kind = "bad"
      else
        line.head = current_head
        current_head.body[#current_head.body + 1] = line
      end
    elseif line.kind == "bad" and raw:match("^  ") and current_head then
      -- A malformed body line still belongs to its block for the purposes of
      -- later checks not complaining about the block twice.
      line.head = current_head
    end
  end
  return lines
end
-- }}}

-- {{{ local function quoted_only()
-- True when fields[i] exists, is quoted, and is the last field.
local function quoted_last(fields, quoted, i)
  return #fields == i and quoted[i] == true
end
-- }}}

-- {{{ local function parse_ref()
-- BOX.PORT, both names.
local function parse_ref(s)
  local box, port = s:match("^([^.]+)%.([^.]+)$")
  if box and M.is_name(box) and M.is_name(port) then return box, port end
  return nil
end
-- }}}

-- {{{ function M.parse_body()
-- Parses one body line of a map block of the given head kind, from its fields.
-- Returns a record, or nil, a rule code and a message. Shared with the
-- proposal reader, which must check that every + and - line would be a legal
-- map line (P3) without there being a map line to read.
function M.parse_body(head_kind, fields, quoted)
  local kw = fields[1]
  if quoted[1] or not (BODY_ALLOWED[head_kind] and BODY_ALLOWED[head_kind][kw]) then
    return nil, "M5", string.format("%q is not a line a %s block can hold", kw, head_kind)
  end
  if kw == "says" then
    if #fields == 2 and quoted[2] then return { kw = "says", value = fields[2] } end
    return nil, "M6", "says takes exactly one quoted field"
  elseif kw == "held-by" or kw == "spoken-for-by" then
    if #fields == 2 and not quoted[2] and M.is_name(fields[2]) then
      return { kw = kw, person = fields[2] }
    end
    return nil, kw == "held-by" and "M7" or "M8", kw .. " takes exactly one person's name"
  elseif kw == "inside" then
    if #fields == 2 and not quoted[2] and fields[2]:sub(1, 1) ~= "/" and fields[2] ~= "" then
      return { kw = "inside", path = fields[2] }
    end
    return nil, "M14", "inside takes one relative path"
  elseif kw == "in" or kw == "out" then
    local port = fields[2]
    if port == nil or quoted[2] or not M.is_name(port) then
      return nil, kw == "in" and "M9" or "M10", "a port needs a name"
    end
    local how = fields[3]
    local code = kw == "in" and "M9" or "M10"
    if how == "-" and not quoted[3] then
      local box, other = parse_ref(fields[4] or "")
      if not box or quoted[4] then
        return nil, "M11", "a wire names BOX.PORT"
      end
      if #fields == 4 or quoted_last(fields, quoted, 5) then
        return { kw = kw, port = port, form = "wire", box = box, other = other,
                 note = fields[5] }
      end
      return nil, code, "a wire takes at most one quoted note after BOX.PORT"
    elseif how == "=" and not quoted[3] then
      if kw == "out" then return nil, "M10", "an out port cannot hold a fixed value" end
      if #fields == 4 and quoted[4] then
        return { kw = "in", port = port, form = "fixed", value = fields[4] }
      end
      return nil, "M9", "a fixed value is exactly one quoted field"
    elseif how and not quoted[3] and how:sub(1, 1) == "$" then
      local outside = how:sub(2)
      if not M.is_name(outside) then return nil, "M13", "a door names an outside: $NAME" end
      if #fields == 3 or quoted_last(fields, quoted, 4) then
        return { kw = kw, port = port, form = "door", outside = outside, note = fields[4] }
      end
      return nil, code, "a door takes at most one quoted note"
    end
    return nil, code, "a port is wired (-), fixed (=, in only) or a door ($)"
  elseif kw == "approve" then
    local subject, amount = fields[2], fields[3]
    if #fields ~= 3 or quoted[2] or quoted[3] then
      return nil, "M15", "approve takes a subject and an amount"
    end
    local spec
    if amount == "all" then
      spec = { all = true }
    elseif amount:match("^%d+$") then
      spec = { count = tonumber(amount) }
    else
      local p, q = amount:match("^(%d+)/(%d+)$")
      p, q = tonumber(p), tonumber(q)
      if p and q and p > 0 and p <= q then spec = { p = p, q = q } end
    end
    if subject ~= "affected" and subject ~= "everyone" and subject ~= "others" then
      return nil, "M15", "approve's subject is affected, everyone or others"
    end
    if spec == nil then
      return nil, "M15", "approve's amount is all, a whole number, or P/Q with 0 < P <= Q"
    end
    if subject == "others" and spec.count == nil then
      return nil, "M15", "approve others takes a whole number only"
    end
    return { kw = "approve", subject = subject, spec = spec }
  elseif kw == "waits" then
    if #fields == 2 and not quoted[2] and fields[2]:match("^%d+$") then
      return { kw = "waits", days = tonumber(fields[2]) }
    end
    return nil, "M15", "waits takes a whole number of days"
  end
  return nil, "M5", "unknown line"
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end
M.read_file = read_file
-- }}}

-- {{{ local function new_box()
local function new_box(kind, name, line)
  return { kind = kind, name = name, line = line, holders = {}, holder_set = {},
           ins = {}, in_order = {}, outs = {}, says = nil, inside = nil }
end
-- }}}

-- {{{ function M.read_map()
-- Reads org.map text. `dir` is the directory it lives in, for M14; nil skips
-- that check (a proposal's result is checked against the real directory by
-- whoever calls with one). Returns the map, problems, warnings.
function M.read_map(text, file, dir)
  local problems, warnings = {}, {}
  local lines = M.lex(text, file, problems)
  local map = { file = file, dir = dir, lines = lines, persons = {}, person_order = {},
                outsides = {}, outside_order = {}, boxes = {}, box_order = {},
                rules = {}, names = {}, blocks = {} }

  -- {{{ heads
  local first_head_seen = false
  for _, line in ipairs(lines) do
    if line.kind == "head" then
      local f, q = line.fields, line.quoted
      local kw, name = f[1], f[2]
      local block = nil
      if q[1] or not MAP_HEADS[kw] then
        complain(problems, file, line.n, "M2", "%q is not a map head", kw)
      elseif #f ~= 2 or q[2] then
        complain(problems, file, line.n, "M3", "a head is a keyword and a name, nothing more")
      elseif not M.is_name(name) then
        complain(problems, file, line.n, "L7", "%q is not a name", name)
      elseif kw == "rule" then
        if not IS_KIND[name] then
          complain(problems, file, line.n, "M4", "%q is not a kind of change", name)
        elseif map.rules[name] then
          complain(problems, file, line.n, "M4", "a second rule for %s (first on line %d)",
                   name, map.rules[name].line)
        else
          block = { kind = "rule", name = name, line = line.n, approve = {}, waits = nil }
          map.rules[name] = block
        end
      elseif map.names[name] then
        complain(problems, file, line.n, "M4", "%q is already the name of the %s on line %d",
                 name, map.names[name].kind, map.names[name].line)
      else
        if kw == "org" then
          if map.org then
            complain(problems, file, line.n, "M1", "a second org head")
          else
            block = { kind = "org", name = name, line = line.n }
            map.org = block
          end
        elseif kw == "person" then
          block = { kind = "person", name = name, line = line.n }
          map.persons[name] = block
          map.person_order[#map.person_order + 1] = name
        elseif kw == "outside" then
          block = { kind = "outside", name = name, line = line.n, speakers = {}, speaker_set = {} }
          map.outsides[name] = block
          map.outside_order[#map.outside_order + 1] = name
        else
          block = new_box(kw, name, line.n)
          map.boxes[name] = block
          map.box_order[#map.box_order + 1] = name
        end
        if block then map.names[name] = block end
      end
      if not first_head_seen then
        first_head_seen = true
        if kw ~= "org" then
          complain(problems, file, line.n, "M1", "the first head must be org")
        end
      end
      line.block = block
      if block then
        block.head = line
        map.blocks[#map.blocks + 1] = block
      end
    end
  end
  if not map.org and not first_head_seen then
    complain(problems, file, nil, "M1", "there is no org head")
  end
  -- }}}

  -- {{{ bodies
  for _, line in ipairs(lines) do
    if line.kind == "body" and line.head.block then
      local block = line.head.block
      local rec, code, msg = M.parse_body(block.kind, line.fields, line.quoted)
      if not rec then
        complain(problems, file, line.n, code, "%s", msg)
      else
        rec.line = line.n
        rec.text = line.text
        line.rec = rec
        if rec.kw == "says" then
          if block.says ~= nil then
            complain(problems, file, line.n, "M6", "a second says in %s", block.name)
          else
            block.says = rec.value
          end
        elseif rec.kw == "held-by" then
          if block.holder_set[rec.person] then
            complain(problems, file, line.n, "M7", "%s holds %s twice", rec.person, block.name)
          else
            block.holder_set[rec.person] = line.n
            block.holders[#block.holders + 1] = rec.person
          end
        elseif rec.kw == "spoken-for-by" then
          if block.speaker_set[rec.person] then
            complain(problems, file, line.n, "M8", "%s speaks for %s twice", rec.person, block.name)
          else
            block.speaker_set[rec.person] = line.n
            block.speakers[#block.speakers + 1] = rec.person
          end
        elseif rec.kw == "inside" then
          if block.inside then
            complain(problems, file, line.n, "M14", "a second inside in %s", block.name)
          else
            block.inside = rec
          end
        elseif rec.kw == "in" then
          if block.ins[rec.port] then
            complain(problems, file, line.n, "M9",
                     "%s already has an in port called %s (line %d): every need has one source",
                     block.name, rec.port, block.ins[rec.port].line)
          else
            block.ins[rec.port] = rec
            block.in_order[#block.in_order + 1] = rec.port
          end
        elseif rec.kw == "out" then
          for _, other in ipairs(block.outs) do
            if other.port == rec.port and other.form == rec.form and other.box == rec.box
               and other.other == rec.other and other.outside == rec.outside then
              complain(problems, file, line.n, "M10",
                       "the same out port to the same place twice (line %d)", other.line)
            end
          end
          block.outs[#block.outs + 1] = rec
        elseif rec.kw == "approve" then
          if block.approve[rec.subject] then
            complain(problems, file, line.n, "M15", "a second approve %s", rec.subject)
          else
            block.approve[rec.subject] = rec.spec
          end
        elseif rec.kw == "waits" then
          if block.waits then
            complain(problems, file, line.n, "M15", "a second waits")
          else
            block.waits = rec.days
          end
        end
      end
    end
  end
  -- }}}

  -- {{{ references
  for _, name in ipairs(map.box_order) do
    local box = map.boxes[name]
    for _, holder in ipairs(box.holders) do
      if not map.persons[holder] then
        complain(problems, file, box.holder_set[holder], "M7", "%s is held by %s, who is not a person in the map",
                 name, holder)
      end
    end
    local ports = {}
    for _, port in ipairs(box.in_order) do ports[#ports + 1] = box.ins[port] end
    for _, rec in ipairs(box.outs) do ports[#ports + 1] = rec end
    for _, rec in ipairs(ports) do
      if rec.form == "door" then
        if not map.outsides[rec.outside] then
          complain(problems, file, rec.line, "M13", "$%s is not a declared outside", rec.outside)
        else
          map.outsides[rec.outside].used = true
        end
      elseif rec.form == "wire" then
        local other = map.boxes[rec.box]
        if not other then
          complain(problems, file, rec.line, "M11", "%s is not a role or work box", rec.box)
        elseif rec.kw == "out" then
          -- M12, from the producing end.
          local back = other.ins[rec.other]
          if not back or back.form ~= "wire" or back.box ~= name or back.other ~= rec.port then
            complain(problems, file, rec.line, "M12",
                     "%s says its %s feeds %s.%s, and %s does not have `in %s - %s.%s`",
                     name, rec.port, rec.box, rec.other, rec.box, rec.other, name, rec.port)
          end
        else
          -- M12, from the consuming end.
          local found = false
          for _, out in ipairs(other.outs) do
            if out.form == "wire" and out.port == rec.other and out.box == name
               and out.other == rec.port then
              found = true
            end
          end
          if not found then
            complain(problems, file, rec.line, "M12",
                     "%s says its %s comes from %s.%s, and %s does not have `out %s - %s.%s`",
                     name, rec.port, rec.box, rec.other, rec.box, rec.other, name, rec.port)
          end
        end
      end
    end
    if box.inside and dir then
      local path = dir .. "/" .. box.inside.path .. "/org.map"
      if not read_file(path) then
        complain(problems, file, box.inside.line, "M14", "%s has no org.map", box.inside.path)
      end
    end
    if #box.holders == 0 then
      complain(warnings, file, box.line, "W1", "%s is vacant: nobody holds it", name)
    end
    if #box.in_order == 0 and #box.outs == 0 then
      complain(warnings, file, box.line, "W2", "%s has no ports", name)
    end
  end
  for _, name in ipairs(map.outside_order) do
    local outside = map.outsides[name]
    for _, speaker in ipairs(outside.speakers) do
      if not map.persons[speaker] then
        complain(problems, file, outside.speaker_set[speaker], "M8", "%s is spoken for by %s, who is not a person",
                 name, speaker)
      end
    end
    if not outside.used then
      complain(warnings, file, outside.line, "W3", "no door leads to or from %s", name)
    end
  end
  -- }}}

  return map, problems, warnings
end
-- }}}

-- {{{ function M.read_state()
-- Reads org.state text against an already-read map.
function M.read_state(text, file, map)
  local problems = {}
  local lines = M.lex(text, file, problems)
  local state = { file = file, lines = lines, fed = {}, done = {} }
  for _, line in ipairs(lines) do
    if line.kind == "body" then
      complain(problems, file, line.n, "S1", "the state file has no body lines")
    elseif line.kind == "head" then
      local f, q = line.fields, line.quoted
      local kw = f[1]
      local well = (#f == 3 or (#f == 4 and q[4])) and not q[1] and not q[2] and not q[3]
      if kw ~= "fed" and kw ~= "done" then
        complain(problems, file, line.n, "S1", "%q is not a state line", kw)
      elseif not well then
        complain(problems, file, line.n, "S1", "%s takes a name, a date and at most one quoted note", kw)
      elseif not M.is_date(f[3]) then
        complain(problems, file, line.n, "L8", "%q is not a date", f[3])
      elseif kw == "fed" then
        local boxname, port = parse_ref(f[2])
        local box = boxname and map.boxes[boxname]
        local rec = box and box.ins[port]
        if not boxname then
          complain(problems, file, line.n, "S2", "fed names BOX.PORT")
        elseif not rec then
          complain(problems, file, line.n, "S2", "%s is not an in port in the map", f[2])
        elseif rec.form == "fixed" then
          complain(problems, file, line.n, "S2", "%s is a fixed value and always fed", f[2])
        elseif state.fed[f[2]] then
          complain(problems, file, line.n, "S4", "%s is fed twice", f[2])
        else
          state.fed[f[2]] = { line = line.n, date = f[3], note = f[4] }
        end
      else
        local box = map.boxes[f[2]]
        if not box then
          complain(problems, file, line.n, "S3", "%s is not a box in the map", f[2])
        elseif box.kind ~= "work" then
          complain(problems, file, line.n, "S3", "%s is a role, and a role is never done", f[2])
        elseif state.done[f[2]] then
          complain(problems, file, line.n, "S4", "%s is done twice", f[2])
        else
          state.done[f[2]] = { line = line.n, date = f[3], note = f[4] }
        end
      end
    end
  end
  return state, problems
end
-- }}}

-- {{{ function M.read_org()
-- Reads an org directory: org.map, and org.state when present. Returns the
-- org, problems and warnings. The org is { dir, map, state }.
function M.read_org(dir)
  local problems, warnings = {}, {}
  local map_text = read_file(dir .. "/org.map")
  if not map_text then
    complain(problems, dir .. "/org.map", nil, "M1", "there is no org.map here")
    return nil, problems, warnings
  end
  local map, p, w = M.read_map(map_text, dir .. "/org.map", dir)
  for _, x in ipairs(p) do problems[#problems + 1] = x end
  for _, x in ipairs(w) do warnings[#warnings + 1] = x end
  local state_text = read_file(dir .. "/org.state") or ""
  local state, sp = M.read_state(state_text, dir .. "/org.state", map)
  for _, x in ipairs(sp) do problems[#problems + 1] = x end
  return { dir = dir, map = map, state = state }, problems, warnings
end
-- }}}

-- {{{ function M.is_fed()
-- An in port is fed when it is a fixed value, when the state says so, or when
-- it is a wire from a work box the state marks done.
function M.is_fed(org, boxname, port)
  local rec = org.map.boxes[boxname].ins[port]
  if rec.form == "fixed" then return true end
  if org.state.fed[boxname .. "." .. port] then return true end
  if rec.form == "wire" then
    local source = org.map.boxes[rec.box]
    if source and source.kind == "work" and org.state.done[rec.box] then return true end
  end
  return false
end
-- }}}

-- {{{ function M.box_state()
-- done, ready, or blocked.
function M.box_state(org, boxname)
  local box = org.map.boxes[boxname]
  if box.kind == "work" and org.state.done[boxname] then return "done" end
  for _, port in ipairs(box.in_order) do
    if not M.is_fed(org, boxname, port) then return "blocked" end
  end
  return "ready"
end
-- }}}

-- {{{ function M.main()
-- The validator. Prints every problem, then every warning, then a verdict.
function M.main(args)
  local dir = args[1]
  if not dir then
    io.stderr:write("usage: 007-org-reader.lua ORG_DIR\n")
    return 2
  end
  dir = dir:gsub("/+$", "")
  local org, problems, warnings = M.read_org(dir)
  for _, p in ipairs(problems) do print(M.format_problem(p)) end
  for _, w in ipairs(warnings) do print(M.format_problem(w)) end
  if #problems > 0 then
    print(string.format("%s: refused, %d problem%s", dir, #problems, #problems == 1 and "" or "s"))
    return 1
  end
  local map = org.map
  -- Maps inside boxes are checked only once the org itself reads, because
  -- lining an inner map up with a box needs the box.
  for _, name in ipairs(map.box_order) do
    if map.boxes[name].inside then
      local root = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."
      local inner_problems, inner_warnings = dofile(root .. "/src/017-inside.lua").check(dir)
      for _, p in ipairs(inner_problems) do print(M.format_problem(p)) end
      for _, w in ipairs(inner_warnings) do print(M.format_problem(w)) end
      if #inner_problems > 0 then
        print(string.format("%s: refused, %d problem%s inside its boxes", dir, #inner_problems,
                            #inner_problems == 1 and "" or "s"))
        return 1
      end
      break
    end
  end
  print(string.format("%s: valid -- %d people, %d boxes, %d outside, %d warning%s",
    dir, #map.person_order, #map.box_order, #map.outside_order,
    #warnings, #warnings == 1 and "" or "s"))
  return 0
end
-- }}}

-- Run as a program only when this file is the program, and only once: a
-- module loaded by another one while it runs is a library, even when the
-- two share a name in arg[0].
if arg and arg[0] and arg[0]:match("007%-org%-reader%.lua$") and not rawget(_G, "CERAMIC_MAIN") then
  rawset(_G, "CERAMIC_MAIN", true)
  os.exit(M.main(arg))
end

return M
