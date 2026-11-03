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

-- 018-the-inside.lua
--
-- covers: 201
--
-- A map inside a box lines up with the box's ports, by N1-N6 of
-- docs/002-the-org-map.md, and the board looks inside.
--
-- **The rule that matters most is N5**: an inner map reaches the world only
-- through its box. Without it, a team could put a door to the river inside
-- its own map, where the parent's doors rule -- an outside eye and a week --
-- never sees it. That is the hidden complexity the vision worries about, one
-- level down, so it has its own case.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local board = dofile(ROOT .. "/src/008-blocked-board.lua")
local inside = dofile(ROOT .. "/src/017-inside.lua")

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
  for _, p in ipairs(problems) do set[p.code] = true end
  return set
end
-- }}}

local scratch = {}

-- {{{ local function org_dirs()
-- A scratch tree: files = { "relative/path" -> text }. Returns its root.
local function org_dirs(files)
  local root = os.tmpname()
  os.remove(root)
  scratch[#scratch + 1] = root
  for path, text in pairs(files) do
    local full = root .. "/" .. path
    assert(os.execute("mkdir -p '" .. full:match("^(.*)/[^/]+$") .. "'"))
    local f = assert(io.open(full, "wb"))
    f:write(text)
    f:close()
  end
  return root
end
-- }}}

-- An outer box with one in port and one out port, holding a map.
local OUTER = table.concat({
  "org outer", "person a", "outside world",
  "role shop", "  held-by a", "  in order $world", "  out goods - box.stock",
  "role box", "  held-by a", "  in stock - shop.goods", "  out made $world", "  inside inner", "",
}, "\n")

-- The inner map that lines up with `box`: stock comes in, made goes out.
local INNER = table.concat({
  "org inner", "person a",
  "outside stock", "outside made",
  "role first", "  held-by a", "  in stock $stock", "  out half - second.half",
  "role second", "  held-by a", "  in half - first.half", "  out made $made", "",
}, "\n")

-- {{{ the examples line up
do
  local problems = inside.check(ROOT .. "/examples/workshop")
  check(#problems == 0, "the workshop's making box lines up with the map inside it")
  local org = reader.read_org(ROOT .. "/examples/workshop")
  local rows = inside.descend(org, board.board(org))
  local making
  for _, r in ipairs(rows) do if r.source == "making" then making = r end end
  check(making and making.inside and making.inside.top.source == "cutting",
        "the board looks inside making and finds cutting first")
  check(board.render(rows):find("    inside making, first: cutting (ready, reach 1)", 1, true) ~= nil,
        "and says so under making's row")

  local ok = org_dirs({ ["org.map"] = OUTER, ["inner/org.map"] = INNER })
  check(#inside.check(ok) == 0, "a box and the map inside it that line up are accepted")
end
-- }}}

-- {{{ one refusal per rule
local cases = {
  { "N1", INNER:gsub("org inner", "org Inner") },
  { "N3", INNER:gsub("outside stock\n", ""):gsub("  in stock %$stock\n", "  in stock = \"x\"\n") },
  { "N3", INNER:gsub("  in stock %$stock", "  in stock = \"x\"") },
  { "N3", INNER:gsub("  out made %$made", "  out made $made\n  out back $stock") },
  { "N4", INNER:gsub("outside made\n", ""):gsub("  out made %$made\n", "") },
  { "N4", INNER:gsub("  out made %$made\n", "") },
  { "N5", INNER .. "outside river\n" },
}
for i, case in ipairs(cases) do
  local root = org_dirs({ ["org.map"] = OUTER, ["inner/org.map"] = case[2] })
  local problems = inside.check(root)
  local got = {}
  for c in pairs(codes(problems)) do got[#got + 1] = c end
  table.sort(got)
  check(codes(problems)[case[1]], string.format("inside case %d is refused with %s (got %s)", i,
        case[1], #got > 0 and table.concat(got, " ") or "nothing"))
end

do
  local both = OUTER:gsub("  out made %$world", "  out stock $world")
  local root = org_dirs({ ["org.map"] = both, ["inner/org.map"] = INNER })
  check(codes(inside.check(root)).N2, "a box with an in and an out port of one name is refused (N2)")

  local itself = org_dirs({ ["org.map"] = OUTER:gsub("inside inner", "inside .") })
  check(codes(inside.check(itself)).N6, "a map inside itself is refused (N6)")

  local loop_inner = INNER:gsub("  out half %- second%.half",
                                "  out half - second.half\n  inside ..")
  local looped = org_dirs({ ["org.map"] = OUTER, ["inner/org.map"] = loop_inner })
  check(codes(inside.check(looped)).N6, "a map inside a map inside it is refused (N6)")
end
-- }}}

-- {{{ all the way down
do
  -- box feeds sell, so box is a source on the outer board; inside it, first
  -- has what it needs and owes half to second, and first has a map inside too.
  local OUTER2 = OUTER:gsub("  out made %$world", "  out made - sell.made")
                 .. "role sell\n  held-by a\n  in made - box.made\n  out sold $world\n"
  local INNER2 = INNER:gsub("  out half %- second%.half", "  out half - second.half\n  inside deeper")
  local DEEPER = table.concat({
    "org deeper", "person a", "outside stock", "outside half",
    "role saw", "  held-by a", "  in stock $stock", "  out half $half", "",
  }, "\n")
  local root = org_dirs({ ["org.map"] = OUTER2, ["inner/org.map"] = INNER2,
                          ["inner/org.state"] = "fed first.stock 2026-11-03\n",
                          ["inner/deeper/org.map"] = DEEPER })
  local problems = inside.check(root)
  check(#problems == 0, "a map inside a box inside a map lines up at both levels"
        .. (problems[1] and (": " .. reader.format_problem(problems[1])) or ""))
  local org = reader.read_org(root)
  local text = board.render(inside.descend(org, board.board(org)))
  check(text:find("    inside inner, first: first (ready, reach 1)\n"
                  .. "    inside deeper, first: $stock (outside, reach 1)", 1, true) ~= nil,
        "the board looks inside a source, and inside the source it finds there")

  local bad_deeper = org_dirs({ ["org.map"] = OUTER2, ["inner/org.map"] = INNER2,
                                ["inner/deeper/org.map"] = DEEPER .. "outside sea\n" })
  check(codes(inside.check(bad_deeper)).N5, "a problem two levels down is found from the top")
end
-- }}}

-- {{{ the validator runs it
do
  local root = org_dirs({ ["org.map"] = OUTER, ["inner/org.map"] = INNER .. "outside river\n" })
  local status = os.execute(string.format("'%s/validate-org' '%s' '%s' > /dev/null", ROOT, ROOT, root))
  check(status ~= 0 and status ~= true, "./validate-org refuses an org whose inside does not line up")
end
-- }}}

for _, dir in ipairs(scratch) do os.execute("rm -rf '" .. dir .. "'") end

print(string.format("the inside: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
