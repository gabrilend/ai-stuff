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

-- 015-history.lua
--
-- Replays an org's history and says whether it explains the map.
--
-- An org that keeps a history has `first.map`, the map as it was founded.
-- Starting there, every applied proposal is applied again in its numbered
-- order, each judged as it stood on the day it was applied (answers given
-- later do not count). The result must be `org.map`, byte for byte. Where it
-- is not, the map was changed by something other than an agreed proposal --
-- which, in an organisation where every change is meant to be a diff somebody
-- agreed to, is the one thing that must never go unnoticed.
--
-- The rules are H1-H7 in docs/003-how-a-change-is-accepted.md.
--
-- Run directly: `luajit 015-history.lua ORG_DIR`.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local proposals = dofile(ROOT .. "/src/010-proposals.lua")

local M = {}

-- {{{ local function fail()
local function fail(result, code, format, ...)
  result.problems[#result.problems + 1] = { code = code, message = string.format(format, ...) }
end
-- }}}

-- {{{ function M.applied_in_order()
-- The applied proposals, in history order, or nil when they cannot be put in
-- one (the problems say why). Each is { path, name, text, proposal }.
function M.applied_in_order(dir, result)
  local list, numbered, unnumbered = {}, 0, 0
  for _, path in ipairs(proposals.list_proposals(dir)) do
    local text = reader.read_file(path)
    local name = path:match("([^/]+)%.proposal$")
    local p = proposals.read_proposal(text, path, name)
    if p.applied then
      list[#list + 1] = { path = path, name = name, text = text, proposal = p }
      if p.applied_seq then numbered = numbered + 1 else unnumbered = unnumbered + 1 end
    end
  end
  if numbered > 0 and unnumbered > 0 then
    fail(result, "H2", "%d applied proposals carry a change number and %d do not: "
         .. "the order cannot be known", numbered, unnumbered)
    return nil
  end
  if numbered > 0 then
    table.sort(list, function(a, b) return a.proposal.applied_seq < b.proposal.applied_seq end)
    for i, step in ipairs(list) do
      if step.proposal.applied_seq ~= i then
        fail(result, "H3", "change numbers run 1 to %d once each; %s is number %d where %d belongs",
             #list, step.name, step.proposal.applied_seq, i)
        return nil
      end
      if i > 1 and step.proposal.applied < list[i - 1].proposal.applied then
        fail(result, "H4", "change %d (%s, %s) is dated before change %d (%s, %s)", i, step.name,
             step.proposal.applied, i - 1, list[i - 1].name, list[i - 1].proposal.applied)
        return nil
      end
    end
  else
    table.sort(list, function(a, b)
      if a.proposal.applied ~= b.proposal.applied then
        return a.proposal.applied < b.proposal.applied
      end
      return a.name < b.name
    end)
    if #list > 1 then
      result.warnings[#result.warnings + 1] = { code = "W4",
        message = "no applied proposal carries a change number; the order is inferred from dates and names" }
    end
  end
  return list
end
-- }}}

-- {{{ function M.replay()
-- Returns { history = bool, steps, matches, final_text, problems, warnings }.
-- A step is { seq, name, date, status, reasons }.
function M.replay(dir)
  local result = { steps = {}, problems = {}, warnings = {}, history = false, matches = false }
  local first_text = reader.read_file(dir .. "/first.map")
  if not first_text then return result end
  result.history = true

  local map, problems = reader.read_map(first_text, dir .. "/first.map", dir)
  if #problems > 0 then
    for _, p in ipairs(problems) do
      fail(result, "H1", "first.map is not a valid map: %s", reader.format_problem(p))
    end
    return result
  end
  local list = M.applied_in_order(dir, result)
  if not list then return result end

  local text = first_text
  local empty_state = reader.read_state("", dir .. "/org.state", map)
  for i, step in ipairs(list) do
    local date = step.proposal.applied
    local org = { dir = dir, map = map, state = empty_state }
    local report = proposals.evaluate(org, step.text, step.path, step.name, date, date)
    local record = { seq = i, name = step.name, date = date, status = report.status,
                     reasons = report.reasons }
    result.steps[#result.steps + 1] = record
    if report.status == "invalid" then
      for _, p in ipairs(report.problems) do record.reasons[#record.reasons + 1] = reader.format_problem(p) end
      fail(result, "H5", "change %d, %s, cannot be read", i, step.name)
      return result
    elseif report.status == "stale" or report.status == "broken" then
      fail(result, "H5", "change %d, %s, does not apply to the map before it: it is %s",
           i, step.name, report.status)
      return result
    elseif report.status ~= "ready" then
      for _, k in ipairs(report.kinds or {}) do
        for _, c in ipairs(k.checks) do
          if not c.met then
            record.reasons[#record.reasons + 1] = string.format("%s: %s -- %s", k.kind, c.text, c.detail)
          end
        end
      end
      fail(result, "H6", "change %d, %s, was not agreed on %s, the day it was applied", i, step.name, date)
    end
    text = report.new_map_text
    map = reader.read_map(text, dir .. "/org.map", dir)
    empty_state = reader.read_state("", dir .. "/org.state", map)
  end

  result.final_text = text
  local actual = reader.read_file(dir .. "/org.map") or ""
  result.matches = actual == text
  if not result.matches then
    fail(result, "H7", "org.map is not what first.map and the applied proposals make: "
         .. "it was changed some other way")
  end
  return result
end
-- }}}

-- {{{ function M.main()
function M.main(args)
  local dir = args[1]
  if not dir or args[2] then
    io.stderr:write("usage: 015-history.lua ORG_DIR\n")
    return 2
  end
  dir = dir:gsub("/+$", "")
  local result = M.replay(dir)
  if not result.history then
    print(dir .. ": keeps no history (no first.map), so there is nothing to replay")
    return 0
  end
  print(string.format("%s: first.map, then %d applied proposal%s", dir, #result.steps,
                      #result.steps == 1 and "" or "s"))
  for _, step in ipairs(result.steps) do
    local verdict = step.status == "ready" and "agreed, and applies" or step.status
    print(string.format("  %3d  %s  %-36s %s", step.seq, step.date, step.name, verdict))
    for _, r in ipairs(step.reasons) do print("         " .. r) end
  end
  for _, w in ipairs(result.warnings) do print(w.code .. " " .. w.message) end
  for _, p in ipairs(result.problems) do print(p.code .. " " .. p.message) end
  if result.final_text and not result.matches then
    io.write(proposals.diff(result.final_text, reader.read_file(dir .. "/org.map") or "",
                            "org.map"))
  end
  if #result.problems > 0 then
    print(dir .. ": the history does not explain the map")
    return 1
  end
  print(dir .. ": the history explains the map exactly")
  return 0
end
-- }}}

-- Run as a program only when this file is the program, and only once: a
-- module loaded by another one while it runs is a library, even when the
-- two share a name in arg[0].
if arg and arg[0] and arg[0]:match("015%-history%.lua$") and not rawget(_G, "CERAMIC_MAIN") then
  rawset(_G, "CERAMIC_MAIN", true)
  os.exit(M.main(arg))
end

return M
