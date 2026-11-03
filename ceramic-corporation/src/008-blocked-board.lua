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

-- 008-blocked-board.lua
--
-- Ranks every source of waiting in an org by how much depends on it.
--
-- The definitions are docs/004-what-blocked-means.md, and nothing here adds to
-- them: a wait is an unfed in port on a box that is not done; its source is
-- the box or outside party at the other end; owes, frees and reach are counted
-- per source; the ranking is reach, then frees, then whether the source can
-- act now, then name.
--
-- Run directly: `luajit 008-blocked-board.lua ORG_DIR [--ready] [--says]`.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")

local M = {}

-- Which sources come first among equals: the ones somebody can act on.
local ACT_RANK = { ready = 1, vacant = 2, outside = 3, blocked = 4 }

-- {{{ function M.waits()
-- Every unfed in port on a box that is not done, with its source. A source is
-- a box name, or "$" and an outside's name.
function M.waits(org)
  local list = {}
  for _, name in ipairs(org.map.box_order) do
    if reader.box_state(org, name) ~= "done" then
      local box = org.map.boxes[name]
      for _, port in ipairs(box.in_order) do
        if not reader.is_fed(org, name, port) then
          local rec = box.ins[port]
          local source = rec.form == "wire" and rec.box or ("$" .. rec.outside)
          list[#list + 1] = { box = name, port = port, source = source }
        end
      end
    end
  end
  return list
end
-- }}}

-- {{{ local function source_state()
local function source_state(org, source)
  if source:sub(1, 1) == "$" then return "outside" end
  if reader.box_state(org, source) == "blocked" then return "blocked" end
  if #org.map.boxes[source].holders == 0 then return "vacant" end
  return "ready"
end
-- }}}

-- {{{ function M.board()
-- One row per source: { source, state, owes, frees, reach, holders }, ranked.
function M.board(org)
  local waits = M.waits(org)
  local owes, sources_of, dependents, order = {}, {}, {}, {}
  for _, w in ipairs(waits) do
    if owes[w.source] == nil then
      owes[w.source] = 0
      order[#order + 1] = w.source
      dependents[w.source] = {}
    end
    owes[w.source] = owes[w.source] + 1
    sources_of[w.box] = sources_of[w.box] or {}
    sources_of[w.box][w.source] = true
    dependents[w.source][w.box] = true
  end

  local rows = {}
  for _, source in ipairs(order) do
    -- frees: blocked boxes whose every wait has this source.
    local frees = 0
    for box, set in pairs(sources_of) do
      local only = true
      for s in pairs(set) do
        if s ~= source then only = false break end
      end
      if only and set[source] then frees = frees + 1 end
    end
    -- reach: everything that depends on this source, walked with a visited
    -- set so a loop ends; the source itself is never counted.
    local seen, stack, reach = { [source] = true }, { source }, 0
    while #stack > 0 do
      local s = table.remove(stack)
      for box in pairs(dependents[s] or {}) do
        if not seen[box] then
          seen[box] = true
          reach = reach + 1
          stack[#stack + 1] = box
        end
      end
    end
    local holders = {}
    if source:sub(1, 1) == "$" then
      holders = org.map.outsides[source:sub(2)].speakers
    else
      holders = org.map.boxes[source].holders
    end
    local says
    if source:sub(1, 1) == "$" then
      says = org.map.outsides[source:sub(2)].says
    else
      says = org.map.boxes[source].says
    end
    rows[#rows + 1] = { source = source, state = source_state(org, source),
                        owes = owes[source], frees = frees, reach = reach,
                        holders = holders, says = says }
  end

  table.sort(rows, function(a, b)
    if a.reach ~= b.reach then return a.reach > b.reach end
    if a.frees ~= b.frees then return a.frees > b.frees end
    if ACT_RANK[a.state] ~= ACT_RANK[b.state] then
      return ACT_RANK[a.state] < ACT_RANK[b.state]
    end
    return a.source < b.source
  end)
  return rows
end
-- }}}

-- {{{ function M.render()
-- A plain-text table. For an outside source the holders column is its
-- speakers. With `with_says`, each row is followed by the source's says line,
-- indented, so a board of numbered things says what each one is.
function M.render(rows, with_says)
  local out = {}
  local width = #"source"
  for _, r in ipairs(rows) do
    if #r.source > width then width = #r.source end
  end
  local fmt = "%-" .. width .. "s  %-7s  %4s  %5s  %5s  %s"
  out[#out + 1] = string.format(fmt, "source", "state", "owes", "frees", "reach", "holders")
  for _, r in ipairs(rows) do
    local holders = #r.holders > 0 and table.concat(r.holders, " ") or "-"
    out[#out + 1] = string.format(fmt, r.source, r.state, r.owes, r.frees, r.reach, holders)
    if with_says and r.says then out[#out + 1] = "    " .. r.says end
  end
  return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function M.main()
function M.main(args)
  local dir, ready_only, with_says = nil, false, false
  for _, a in ipairs(args) do
    if a == "--ready" then ready_only = true
    elseif a == "--says" then with_says = true
    elseif dir == nil then dir = a:gsub("/+$", "")
    else
      io.stderr:write("usage: 008-blocked-board.lua ORG_DIR [--ready] [--says]\n")
      return 2
    end
  end
  if not dir then
    io.stderr:write("usage: 008-blocked-board.lua ORG_DIR [--ready] [--says]\n")
    return 2
  end
  local org, problems = reader.read_org(dir)
  if #problems > 0 then
    for _, p in ipairs(problems) do io.stderr:write(reader.format_problem(p), "\n") end
    io.stderr:write(dir, ": refused; run validate-org for the whole list\n")
    return 1
  end
  local rows = M.board(org)
  if ready_only then
    local kept = {}
    for _, r in ipairs(rows) do
      if r.state == "ready" then kept[#kept + 1] = r end
    end
    rows = kept
  end
  if #rows == 0 then
    print(ready_only and "nothing anybody can deliver right now is owed" or "nothing is waiting")
    return 0
  end
  io.write(M.render(rows, with_says))
  return 0
end
-- }}}

if arg and arg[0] and arg[0]:match("008%-blocked%-board%.lua$") then
  os.exit(M.main(arg))
end

return M
