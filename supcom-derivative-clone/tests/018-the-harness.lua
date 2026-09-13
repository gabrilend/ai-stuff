-- supcom-derivative-clone — a factory war on dunes where nothing is out of range
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

-- 018-the-harness.lua
--
-- covers: 113
--
-- Finds a source module by its stem, asserts, and reports; every test program
-- starts here.
--
-- ## Why a test cannot name a file number
--
-- Source files are numbered when they are created, and the tests were written
-- before any source existed. So a test names the *stem* of the file it wants --
-- "the-dunes" -- and this harness finds the one file in src/ whose name ends in
-- it. Zero matches is a **named absence**: the harness says which file it looked
-- for and which issue creates it, and the suite that asked fails. Two matches is
-- an error too, because a stem two files share is a naming bug and not something
-- to pick between.
--
-- ## Why an absence is a failure and never a skip
--
-- A skipped test is a fallback, and a fallback is a warning, and a warning is an
-- error. Today every suite fails this way, on purpose: the tests are the
-- specification, and a specification that quietly passes with nothing under it
-- specifies nothing.
--
-- ## Usage from a test program
--
--   local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
--   harness.start(arg, "019-the-dunes-and-the-clock")
--   harness.suite("the same seed raises the same field", function()
--     local dunes = harness.load("the-dunes", "102")
--     ...
--     harness.check("heights agree", a == b, "first differs at " .. i)
--   end)
--   harness.finish()

local M = {}

M.root = "/mnt/mtwo/programming/ai-stuff/supcom-derivative-clone"
M.name = "a test"
M.passed = 0
M.failed = 0
M.absent = {}

-- {{{ function M.start()
-- Reads --dir off the command line, or falls back to the hard-coded root above,
-- and names the program for the report.
function M.start(arguments, name)
  M.name = name
  for index = 1, #arguments do
    if arguments[index] == "--dir" and arguments[index + 1] ~= nil then
      M.root = arguments[index + 1]
    end
  end
  print(string.format("%s, against %s", name, M.root))
end
-- }}}

-- {{{ function M.seed()
-- The suite's seed, pinned by run-tests through SDC_SEED so the same inputs
-- produce the same match; a test that wants a different field asks for one
-- through the environment rather than by editing a number here.
function M.seed()
  local given = os.getenv("SDC_SEED")
  if given == nil or given == "" then
    return 20260912
  end
  local number = tonumber(given)
  if number == nil then
    error("SDC_SEED is '" .. given .. "', which is not a number")
  end
  return number
end
-- }}}

-- {{{ local function list()
-- Every entry in a directory, sorted. Read-only, and the only thing this file
-- ever asks the shell.
local function list(directory)
  local found = {}
  local handle = io.popen("ls -1 '" .. directory .. "' 2>/dev/null")
  for name in handle:lines() do
    found[#found + 1] = name
  end
  handle:close()
  table.sort(found)
  return found
end
-- }}}

-- {{{ local function issue_file()
-- The issue file that creates a stem, found by number, so an absence can name the
-- blueprint that fills it. Looks in the open and the completed directories.
local function issue_file(number)
  for _, place in ipairs({"/issues/", "/issues/completed/"}) do
    for _, name in ipairs(list(M.root .. place)) do
      if name:match("^" .. number .. "%-") then
        return place:sub(2) .. name
      end
    end
  end
  return "no issue file numbered " .. number
end
-- }}}

-- {{{ local function find_one()
-- The single file in a directory whose name is NNN-<stem>.lua.
local function find_one(directory, stem, issue)
  local matches = {}
  for _, name in ipairs(list(M.root .. "/" .. directory)) do
    if name:match("^%d%d%d%-" .. stem:gsub("%-", "%%-") .. "%.lua$") then
      matches[#matches + 1] = name
    end
  end
  if #matches == 0 then
    error({absent = true, message = string.format(
      "%s/NNN-%s.lua does not exist yet -- it is built by issue %s (%s)",
      directory, stem, issue, issue_file(issue))}, 0)
  end
  if #matches > 1 then
    error({absent = true, message = string.format(
      "%s has %d files named *-%s.lua, which is a naming bug: %s",
      directory, #matches, stem, table.concat(matches, ", "))}, 0)
  end
  return M.root .. "/" .. directory .. "/" .. matches[1]
end
-- }}}

-- {{{ function M.load()
-- The source module with the given stem, or a named absence.
function M.load(stem, issue)
  local path = find_one("src", stem, issue)
  local chunk, problem = loadfile(path)
  if chunk == nil then
    error("src file " .. path .. " does not load: " .. tostring(problem), 0)
  end
  return chunk()
end
-- }}}

-- {{{ function M.load_asset()
-- A catalogue table with the given stem, from assets/, or a named absence.
function M.load_asset(stem, issue)
  local path = find_one("assets", stem, issue)
  local chunk, problem = loadfile(path)
  if chunk == nil then
    error("asset file " .. path .. " does not load: " .. tostring(problem), 0)
  end
  return chunk()
end
-- }}}

-- {{{ function M.check()
-- One claim. Printed as it is judged, so a failure is read in context.
function M.check(name, condition, detail)
  if condition then
    M.passed = M.passed + 1
    print(string.format("  ok    %s", name))
  else
    M.failed = M.failed + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  --  " .. tostring(detail)) or ""))
  end
end
-- }}}

-- {{{ function M.suite()
-- A group of claims that share a subject. If the subject is absent, the suite
-- fails once, by name, and the program moves on to the next suite -- so one
-- missing module reports one missing module rather than hiding every suite
-- behind it.
function M.suite(name, body)
  print("-- " .. name)
  local ok, problem = pcall(body)
  if ok then
    return
  end
  M.failed = M.failed + 1
  if type(problem) == "table" and problem.absent then
    M.absent[#M.absent + 1] = problem.message
    print("  ABSENT  " .. problem.message)
  else
    print("  FAIL  the suite raised: " .. tostring(problem))
  end
end
-- }}}

-- {{{ function M.same_numbers()
-- Two flat arrays of numbers agree element for element. Returns true, or false
-- and the first index that differs, so the report can say where.
function M.same_numbers(a, b)
  if #a ~= #b then
    return false, "lengths " .. #a .. " and " .. #b
  end
  for index = 1, #a do
    if a[index] ~= b[index] then
      return false, "index " .. index .. ": " .. tostring(a[index]) .. " vs " .. tostring(b[index])
    end
  end
  return true
end
-- }}}

-- {{{ function M.finish()
-- The report, and the exit code run-tests reads.
function M.finish()
  print(string.format("%s: %d held, %d did not", M.name, M.passed, M.failed))
  if #M.absent > 0 then
    print(string.format("  %d subject(s) absent -- the source has not been built yet:", #M.absent))
    for _, message in ipairs(M.absent) do
      print("    " .. message)
    end
  end
  os.exit(M.failed == 0 and 0 or 1)
end
-- }}}

return M
