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

-- 016-the-history.lua
--
-- covers: 202
--
-- Replaying first.map and the applied proposals rebuilds org.map exactly, and
-- every way a history can fail to explain a map is caught by its code.
--
-- **Each failure is made by tampering with a real history**: the workshop is
-- copied to a scratch directory and one thing is changed -- the map edited by
-- hand, an approval back-dated past the day of applying, a change applied a
-- day before its week was up, two numbers swapped. A replay that let any of
-- those through would make "every change is a diff somebody agreed to" false
-- without anybody being told.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local history = dofile(ROOT .. "/src/015-history.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(ok, what)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("FAIL: " .. what)
  end
end
-- }}}

-- {{{ local function codes()
local function codes(result)
  local set = {}
  for _, p in ipairs(result.problems) do set[p.code] = true end
  return set
end
-- }}}

local scratch = {}

-- {{{ local function copy_of()
-- A scratch copy of an example org, with `changes` = { path -> function(text) }
-- applied to its files.
local function copy_of(example, changes)
  local dir = os.tmpname()
  os.remove(dir)
  assert(os.execute(string.format("mkdir -p '%s' && cp -r '%s/examples/%s/.' '%s/'",
                                  dir, ROOT, example, dir)))
  scratch[#scratch + 1] = dir
  for path, change in pairs(changes or {}) do
    local full = dir .. "/" .. path
    local text = change(reader.read_file(full))
    local f = assert(io.open(full, "wb"))
    f:write(text)
    f:close()
  end
  return dir
end
-- }}}

-- {{{ local function sub()
-- A change that replaces the first plain occurrence of `from` with `to`.
local function sub(from, to)
  return function(text)
    local i, j = text:find(from, 1, true)
    assert(i, "the test's text to replace is not there: " .. from)
    return text:sub(1, i - 1) .. to .. text:sub(j + 1)
  end
end
-- }}}

local KAI = "proposals/kai-joins.proposal"
local FINISHING = "proposals/finishing-is-its-own-role.proposal"

-- {{{ histories that explain their maps
do
  local r = history.replay(ROOT .. "/examples/workshop")
  check(r.history and r.matches and #r.problems == 0, "the workshop's history explains its map")
  check(#r.steps == 2 and r.steps[1].name == "kai-joins" and r.steps[2].name == "finishing-is-its-own-role",
        "two changes, in their numbered order; the open proposal is not part of history")

  local b = history.replay(ROOT .. "/examples/bakery")
  check(b.history and b.matches and #b.steps == 0, "the bakery has applied nothing, and its map is its first")

  local m = history.replay(ROOT .. "/examples/monorepo")
  check(not m.history and #m.problems == 0, "an org with no first.map keeps no history, and that is not a fault")
end
-- }}}

-- {{{ histories that do not
do
  local hand = history.replay(copy_of("workshop", {
    ["org.map"] = sub("  held-by jon\n", "  held-by jon\n  held-by ines\n") }))
  check(codes(hand).H7 and not hand.matches, "a map edited by hand is caught (H7)")

  local late = history.replay(copy_of("workshop", {
    [FINISHING] = sub("approve ines 2026-10-04", "approve ines 2026-10-13") }))
  check(codes(late).H6, "an approval given after the change was applied does not count (H6)")
  check(late.steps[2].reasons[1] and late.steps[2].reasons[1]:find("others", 1, true) ~= nil,
        "and the step says which rule was not met")
  check(late.matches, "the text still replays, so only the agreement is at fault")

  local early = history.replay(copy_of("workshop", {
    [FINISHING] = sub("applied 2026-10-12 2", "applied 2026-10-08 2") }))
  check(codes(early).H6, "a door applied before its week was up is caught (H6)")

  local swapped = history.replay(copy_of("workshop", {
    [KAI] = sub("applied 2026-10-01 1", "applied 2026-10-01 2"),
    [FINISHING] = sub("applied 2026-10-12 2", "applied 2026-10-12 1") }))
  check(codes(swapped).H4, "numbers that put a later date first are refused (H4)")

  local gap = history.replay(copy_of("workshop", {
    [FINISHING] = sub("applied 2026-10-12 2", "applied 2026-10-12 3") }))
  check(codes(gap).H3, "a gap in the numbers is refused (H3)")

  local twice = history.replay(copy_of("workshop", {
    [FINISHING] = sub("applied 2026-10-12 2", "applied 2026-10-12 1") }))
  check(codes(twice).H3, "a number used twice is refused (H3)")

  local mixed = history.replay(copy_of("workshop", {
    [KAI] = sub("applied 2026-10-01 1", "applied 2026-10-01") }))
  check(codes(mixed).H2, "some numbered and some not is refused (H2)")

  local none = history.replay(copy_of("workshop", {
    [KAI] = sub("applied 2026-10-01 1", "applied 2026-10-01"),
    [FINISHING] = sub("applied 2026-10-12 2", "applied 2026-10-12") }))
  check(none.matches and #none.problems == 0 and none.warnings[1] and none.warnings[1].code == "W4",
        "none numbered replays by date, with a warning that the order was inferred")

  local stale = history.replay(copy_of("workshop", {
    [FINISHING] = sub("  - out chair $buyers", "  - out stool $buyers") }))
  check(codes(stale).H5 and #stale.steps == 2, "a change that does not apply to the map before it stops the replay (H5)")

  local bad_first = history.replay(copy_of("workshop", {
    ["first.map"] = sub("org workshop", "org Workshop") }))
  check(codes(bad_first).H1, "an invalid first.map is refused (H1)")
end
-- }}}

-- {{{ the applied line
do
  local proposals = dofile(ROOT .. "/src/010-proposals.lua")
  local head = "proposal p\n  by a\n  opened 2026-10-01\n\nedit role r\n  + says \"x\"\n\n"
  local p = proposals.read_proposal(head .. "applied 2026-10-02 7\n", "p.proposal", "p")
  check(p.applied == "2026-10-02" and p.applied_seq == 7, "`applied DATE N` carries the change number")
  local _, problems = proposals.read_proposal(head .. "applied 2026-10-02 0\n", "p.proposal", "p")
  check(problems[1] and problems[1].code == "P5", "change numbers start at 1 (P5)")
end
-- }}}

for _, dir in ipairs(scratch) do os.execute("rm -rf '" .. dir .. "'") end

print(string.format("the history: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
