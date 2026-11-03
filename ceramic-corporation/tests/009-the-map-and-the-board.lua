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

-- 009-the-map-and-the-board.lua
--
-- covers: 102, 103
--
-- The reader refuses every rule of docs/002-the-org-map.md by its code, and
-- the board computes docs/004-what-blocked-means.md exactly.
--
-- **One broken file per rule code.** Each case below is the smallest map that
-- breaks one rule, and the check is that the refusal names that rule's code.
-- A reader that refuses a bad file for the wrong reason has a bug that will
-- send somebody looking up the wrong rule, so "refused" is not enough.
--
-- The board's numbers are checked against the table printed in document 004
-- for the bakery, against a stack of ten pull requests (where frees and reach
-- disagree, which is why the board ranks by reach), and against a loop (which
-- must end and must not count a box in its own reach).

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local board = dofile(ROOT .. "/src/008-blocked-board.lua")

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
local function codes(problems)
  local set = {}
  for _, p in ipairs(problems) do set[p.code] = (set[p.code] or 0) + 1 end
  return set
end
-- }}}

-- {{{ local function org_from()
-- An org read from strings, the way read_org reads files.
local function org_from(map_text, state_text)
  local map, problems, warnings = reader.read_map(map_text, "test.map", nil)
  local state, sp = reader.read_state(state_text or "", "test.state", map)
  for _, p in ipairs(sp) do problems[#problems + 1] = p end
  return { map = map, state = state }, problems, warnings
end
-- }}}

-- A minimal valid map the broken cases are built from.
local BASE = table.concat({
  "org test",
  "person ana",
  "outside world",
  "role a",
  "  held-by ana",
  "  out x - b.y",
  "  out z $world",
  "role b",
  "  held-by ana",
  "  in y - a.x",
  "",
}, "\n")

-- {{{ the valid cases
do
  local org, problems, warnings = reader.read_org(ROOT .. "/examples/bakery")
  check(#problems == 0, "the bakery is valid")
  local w = codes(warnings)
  check(w.W1 == 1 and #warnings == 1, "the bakery warns once, that cleaning is vacant")
  check(reader.box_state(org, "baking") == "blocked", "baking is blocked on the bench")
  check(reader.box_state(org, "selling") == "ready", "selling has yesterday's loaves")
  check(reader.box_state(org, "delivery") == "blocked", "delivery waits on baking")
  check(reader.box_state(org, "cleaning") == "ready", "cleaning needs nothing")
  check(reader.is_fed(org, "baking", "recipe"), "a fixed value is always fed")

  local _, p = org_from(BASE)
  check(#p == 0, "the base map is valid")

  -- A finished work box has delivered everything it was going to.
  local done_map = BASE:gsub("role a", "work a")
  local o2, p2 = org_from(done_map, "done a 2026-11-03\n")
  check(#p2 == 0, "a done work box is a valid state line")
  check(reader.is_fed(o2, "b", "y"), "a wire from a done work box is fed")
  check(reader.box_state(o2, "a") == "done", "a done work box is done")

  -- Loops are not errors.
  local _, p3 = org_from(table.concat({
    "org loop", "person ana",
    "role a", "  held-by ana", "  in back - b.forth", "  out there - b.here",
    "role b", "  held-by ana", "  in here - a.there", "  out forth - a.back", "",
  }, "\n"))
  check(#p3 == 0, "a loop between two boxes is valid")

  -- No word is reserved: a box may be called role, and a port says.
  local _, p4 = org_from("org o\nperson ana\nrole role\n  held-by ana\n  in says = \"x\"\n")
  check(#p4 == 0, "a box called role with a port called says is valid")
end
-- }}}

-- {{{ one refusal per rule code
local broken = {
  { "L1", "org test" },
  { "L2", "org test\n\tsays \"x\"\n" },
  { "L3", "org test \n" },
  { "L4", "org test\n   says \"x\"\n" },
  { "L5", "  says \"x\"\norg test\n" },
  { "L6", "org test\n  says \"unclosed\n" },
  { "L7", "org Test\n" },
  { "L9", "org test\n  says \"x\" # a trailing comment\n" },
  { "M1", "person ana\norg test\n" },
  { "M1", "org test\norg other\n" },
  { "M2", "org test\nteam a\n" },
  { "M3", "org test\nrole a b\n" },
  { "M4", "org test\nperson a\nrole a\n" },
  { "M4", "org test\nrule bribery\n" },
  { "M4", "org test\nrule wiring\nrule wiring\n" },
  { "M5", "org test\nperson ana\n  held-by ana\n" },
  { "M6", "org test\n  says \"x\"\n  says \"y\"\n" },
  { "M7", "org test\nrole a\n  held-by nobody\n" },
  { "M7", "org test\nperson ana\nrole a\n  held-by ana\n  held-by ana\n" },
  { "M8", "org test\noutside w\n  spoken-for-by nobody\n" },
  { "M9", BASE .. "  in y2 = \"a\"\n  in y2 = \"b\"\n" },
  { "M10", BASE:gsub("  out z %$world", "  out z $world\n  out z $world") },
  { "M11", BASE:gsub("  in y %- a%.x", "  in y - a.x\n  in q - ghost.p") },
  { "M12", BASE:gsub("  in y %- a%.x\n", "") },
  { "M12", BASE:gsub("  out x %- b%.y\n", "") },
  { "M12", BASE:gsub("  in y %- a%.x", "  in y - a.wrong") },
  { "M13", BASE:gsub("%$world", "$nowhere") },
  { "M15", "org test\nrule wiring\n  approve affected 3/2\n" },
  { "M15", "org test\nrule wiring\n  approve others 1/2\n" },
  { "M15", "org test\nrule wiring\n  waits 3\n  waits 4\n" },
}
for i, case in ipairs(broken) do
  local code, text = case[1], case[2]
  local _, problems = org_from(text)
  local got = codes(problems)
  local names = {}
  for c in pairs(got) do names[#names + 1] = c end
  table.sort(names)
  check(got[code] ~= nil, string.format("case %d is refused with %s (got %s)", i, code,
        #names > 0 and table.concat(names, " ") or "nothing"))
end

-- M14 needs a directory to look in.
do
  local _, problems = reader.read_map("org t\nperson a\nrole r\n  held-by a\n  inside no/such/place\n",
                                      "t.map", ROOT .. "/examples")
  check(codes(problems).M14 ~= nil, "inside a directory with no org.map is refused with M14")
  local _, ok = reader.read_map("org t\nperson a\nrole r\n  held-by a\n  inside bakery\n",
                                "t.map", ROOT .. "/examples")
  check(#ok == 0, "inside a directory with an org.map is accepted")
end

-- The state file.
local state_broken = {
  { "S1", "fed b.y 2026-11-03\n  says \"x\"\n" },
  { "S1", "blocked b.y 2026-11-03\n" },
  { "S2", "fed b.nothing 2026-11-03\n" },
  { "S3", "done a 2026-11-03\n" },
  { "S4", "fed b.y 2026-11-03\nfed b.y 2026-11-04\n" },
  { "L8", "fed b.y 2026-02-30\n" },
}
for i, case in ipairs(state_broken) do
  local _, problems = org_from(BASE, case[2])
  check(codes(problems)[case[1]] ~= nil, string.format("state case %d is refused with %s", i, case[1]))
end
do
  local _, problems = org_from(BASE .. "  in fixed = \"v\"\n", "fed b.fixed 2026-11-03\n")
  check(codes(problems).S2 ~= nil, "a fixed port cannot be fed by a state line (S2)")
end

-- The warnings.
do
  local _, problems, warnings = org_from("org t\nperson a\noutside w\nrole r\n  held-by a\n")
  check(#problems == 0, "a box with no ports and an unused outside are legal")
  local w = codes(warnings)
  check(w.W2 == 1 and w.W3 == 1, "and warned about as W2 and W3")
end

-- Every problem, not the first.
do
  local _, problems = org_from("org t\nrole a\n  held-by x\n  held-by y\n  in p - nowhere.q\n")
  check(#problems >= 3, "the reader names every problem, not only the first")
end
-- }}}

-- {{{ the board
do
  local org = reader.read_org(ROOT .. "/examples/bakery")
  local rows = board.board(org)
  local want = {
    { "cleaning", "vacant", 1, 1, 2 },
    { "books", "ready", 1, 1, 1 },
    { "baking", "blocked", 1, 1, 1 },
  }
  check(#rows == #want, "the bakery's board has three rows")
  for i, w in ipairs(want) do
    local r = rows[i] or {}
    check(r.source == w[1] and r.state == w[2] and r.owes == w[3] and r.frees == w[4]
          and r.reach == w[5],
          string.format("bakery row %d is %s %s %d %d %d (document 004)", i, w[1], w[2], w[3], w[4], w[5]))
  end
end

-- A stack of ten: each pull request is built on the one before.
do
  local lines = { "org stack", "person ritz" }
  for i = 1, 10 do
    lines[#lines + 1] = "work pr-" .. i
    lines[#lines + 1] = "  held-by ritz"
    if i > 1 then lines[#lines + 1] = "  in base - pr-" .. (i - 1) .. ".merged" end
    if i < 10 then lines[#lines + 1] = "  out merged - pr-" .. (i + 1) .. ".base" end
  end
  local org, problems = org_from(table.concat(lines, "\n") .. "\n")
  check(#problems == 0, "the stack of ten is valid")
  local rows = board.board(org)
  check(#rows == 9, "nine of the ten owe something")
  local top = rows[1]
  check(top.source == "pr-1" and top.state == "ready", "the bottom of the stack ranks first, and can act")
  check(top.frees == 1 and top.reach == 9, "it frees one and reaches nine")
  check(rows[9].source == "pr-9" and rows[9].reach == 1, "the second from the top reaches only the top")

  -- Merging the bottom: the next one up becomes the top of the board.
  local merged, p2 = org_from(table.concat(lines, "\n") .. "\n", "done pr-1 2026-11-03\n")
  check(#p2 == 0, "a merged pull request is a done work box")
  local rows2 = board.board(merged)
  check(rows2[1].source == "pr-2" and rows2[1].reach == 8, "after the first merge the second leads with eight")
end

-- A loop must end, and a box is not in its own reach.
do
  local org = org_from(table.concat({
    "org loop", "person ana",
    "role a", "  held-by ana", "  in back - b.forth", "  out there - b.here",
    "role b", "  held-by ana", "  in here - a.there", "  out forth - a.back", "",
  }, "\n"))
  local rows = board.board(org)
  check(#rows == 2, "both ends of the loop owe something")
  for _, r in ipairs(rows) do
    check(r.reach == 1 and r.frees == 1 and r.state == "blocked",
          r.source .. " reaches only the other end, and is itself blocked")
  end
end

-- An outside party can be a source, and its speakers are shown.
do
  local org = org_from(table.concat({
    "org t", "person dee",
    "outside mill", "  spoken-for-by dee",
    "role buying", "  held-by dee", "  in flour $mill", "",
  }, "\n"))
  local rows = board.board(org)
  check(#rows == 1 and rows[1].source == "$mill" and rows[1].state == "outside",
        "a door in that is not fed makes the outside a source")
  check(rows[1].holders[1] == "dee", "the outside's row shows who speaks for it")
end

-- Frees counts only boxes whose every wait is this one source.
do
  local org = org_from(table.concat({
    "org t", "person a",
    "role p", "  held-by a", "  out x - c.one",
    "role q", "  held-by a", "  out y - c.two",
    "role c", "  held-by a", "  in one - p.x", "  in two - q.y", "",
  }, "\n"))
  local rows = board.board(org)
  check(#rows == 2 and rows[1].frees == 0 and rows[1].reach == 1,
        "a box waiting on two sources is freed by neither alone, and reached by both")
end
-- }}}

print(string.format("the map and the board: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
