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

-- 017-inside.lua
--
-- Checks that a map inside a box lines up with the box, and looks inside.
--
-- "A map is a box": a box may say `inside PATH`, and the org at PATH is how
-- the box does its work. From inside, the box's ports are the outside world.
-- So the inner map declares one `outside` for each of the box's ports, named
-- after the port: each `in` port of the box is an outside the inner map has
-- doors in from, each `out` port an outside it has doors out to, and **the
-- inner map has no other outside** -- it reaches the world only through its
-- box, so nothing it does can bypass the parent map's doors and their rules.
--
-- The rules are N1-N6 in docs/002-the-org-map.md. Inner maps are checked all
-- the way down, and a map that ends up inside itself is refused.
--
-- Run directly: `luajit 017-inside.lua ORG_DIR` checks the nesting only;
-- ./validate-org runs it after the org's own checks.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local board = dofile(ROOT .. "/src/008-blocked-board.lua")

local M = {}

-- {{{ local function real_path()
-- The directory's absolute, symlink-free path, for N6.
local function real_path(dir)
  local pipe = io.popen("cd '" .. dir:gsub("'", "'\\''") .. "' 2>/dev/null && pwd -P")
  local path = pipe:read("*l")
  pipe:close()
  return path
end
-- }}}

-- {{{ local function doors_to()
-- How many inner door lines go in from, and out to, an outside.
local function doors_to(map, outside)
  local ins, outs = 0, 0
  for _, name in ipairs(map.box_order) do
    local box = map.boxes[name]
    for _, port in ipairs(box.in_order) do
      local rec = box.ins[port]
      if rec.form == "door" and rec.outside == outside then ins = ins + 1 end
    end
    for _, rec in ipairs(box.outs) do
      if rec.form == "door" and rec.outside == outside then outs = outs + 1 end
    end
  end
  return ins, outs
end
-- }}}

-- {{{ function M.check_box()
-- N2-N5 for one box against its already-read inner map.
function M.check_box(box, inner, file, problems)
  local where = box.inside.line
  local in_names, out_names = {}, {}
  for _, port in ipairs(box.in_order) do in_names[port] = true end
  for _, rec in ipairs(box.outs) do out_names[rec.port] = true end
  for name in pairs(in_names) do
    if out_names[name] then
      reader.complain(problems, file, where, "N2",
        "%s has an in port and an out port both called %s; from inside they would be one outside",
        box.name, name)
    end
  end
  for _, port in ipairs(box.in_order) do
    if not inner.outsides[port] then
      reader.complain(problems, file, where, "N3",
        "%s's inside has no `outside %s` for its in port %s", box.name, port, port)
    else
      local ins, outs = doors_to(inner, port)
      if ins == 0 then
        reader.complain(problems, file, where, "N3",
          "nothing inside %s takes in $%s, so its in port %s goes nowhere", box.name, port, port)
      end
      if outs > 0 and not out_names[port] then
        reader.complain(problems, file, where, "N3",
          "inside %s, something sends out to $%s, which is an in port of the box", box.name, port)
      end
    end
  end
  local seen = {}
  for _, rec in ipairs(box.outs) do
    local port = rec.port
    if not seen[port] then
      seen[port] = true
      if not inner.outsides[port] then
        reader.complain(problems, file, where, "N4",
          "%s's inside has no `outside %s` for its out port %s", box.name, port, port)
      else
        local ins, outs = doors_to(inner, port)
        if outs == 0 then
          reader.complain(problems, file, where, "N4",
            "nothing inside %s sends out to $%s, so its out port %s is never produced",
            box.name, port, port)
        end
        if ins > 0 and not in_names[port] then
          reader.complain(problems, file, where, "N4",
            "inside %s, something takes in $%s, which is an out port of the box", box.name, port)
        end
      end
    end
  end
  for _, outside in ipairs(inner.outside_order) do
    if not in_names[outside] and not out_names[outside] then
      reader.complain(problems, file, where, "N5",
        "%s's inside reaches $%s, which is not a port of %s: an inner map reaches the world "
        .. "only through its box", box.name, outside, box.name)
    end
  end
end
-- }}}

-- {{{ function M.check()
-- Every box with an inside, all the way down. `seen` holds the real paths of
-- the maps above this one, for N6. Returns problems and warnings.
function M.check(dir, seen, problems, warnings)
  problems, warnings = problems or {}, warnings or {}
  seen = seen or {}
  local here = real_path(dir) or dir
  seen[here] = true
  local org, p, w = reader.read_org(dir)
  if not org then
    for _, x in ipairs(p) do problems[#problems + 1] = x end
    return problems, warnings
  end
  for _, name in ipairs(org.map.box_order) do
    local box = org.map.boxes[name]
    if box.inside then
      local inner_dir = dir .. "/" .. box.inside.path
      local inner_real = real_path(inner_dir)
      if inner_real and seen[inner_real] then
        reader.complain(problems, org.map.file, box.inside.line, "N6",
          "%s's inside, %s, is a map %s is already inside: a map cannot contain itself",
          name, box.inside.path, name)
      elseif reader.read_file(inner_dir .. "/org.map") then
        local inner, ip, iw = reader.read_org(inner_dir)
        if #ip > 0 then
          reader.complain(problems, org.map.file, box.inside.line, "N1",
            "%s's inside, %s, is not a valid org (%d problem%s; run validate-org on it)",
            name, box.inside.path, #ip, #ip == 1 and "" or "s")
          for _, x in ipairs(ip) do problems[#problems + 1] = x end
        else
          for _, x in ipairs(iw) do warnings[#warnings + 1] = x end
          M.check_box(box, inner.map, org.map.file, problems)
          M.check(inner_dir, seen, problems, warnings)
        end
      end
      -- A missing org.map is M14, which the reader already refuses.
    end
  end
  seen[here] = nil
  return problems, warnings
end
-- }}}

-- {{{ function M.descend()
-- For each board row whose source is a box with a valid inside, the top row
-- of the inner board: which inner source most of the inside waits on.
function M.descend(org, rows)
  for _, row in ipairs(rows) do
    local box = row.source:sub(1, 1) ~= "$" and org.map.boxes[row.source]
    if box and box.inside then
      local inner, problems = reader.read_org(org.dir .. "/" .. box.inside.path)
      if inner and #problems == 0 then
        local inner_rows = board.board(inner)
        M.descend(inner, inner_rows)
        row.inside = { path = box.inside.path, top = inner_rows[1] }
      end
    end
  end
  return rows
end
-- }}}

-- {{{ function M.main()
function M.main(args)
  local dir = args[1]
  if not dir or args[2] then
    io.stderr:write("usage: 017-inside.lua ORG_DIR\n")
    return 2
  end
  dir = dir:gsub("/+$", "")
  local problems, warnings = M.check(dir)
  for _, p in ipairs(problems) do print(reader.format_problem(p)) end
  for _, w in ipairs(warnings) do print(reader.format_problem(w)) end
  if #problems > 0 then
    print(dir .. ": the maps inside its boxes do not line up")
    return 1
  end
  print(dir .. ": every map inside a box lines up with it")
  return 0
end
-- }}}

-- Run as a program only when this file is the program, and only once: a
-- module loaded by another one while it runs is a library, even when the
-- two share a name in arg[0].
if arg and arg[0] and arg[0]:match("017%-inside%.lua$") and not rawget(_G, "CERAMIC_MAIN") then
  rawset(_G, "CERAMIC_MAIN", true)
  os.exit(M.main(arg))
end

return M
