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

-- 014-the-monorepo-and-the-page.lua
--
-- covers: 105, 106
--
-- The monorepo's queue becomes a valid org map whose board puts the bottom of
-- a stack first; the page is static, links every wire to a box that exists,
-- and escapes what it shows.
--
-- **Generated files are checked against their generators.** The committed
-- monorepo map, its board and both example pages are each regenerated here
-- and compared byte for byte, because a generated file that has drifted from
-- its input is the one kind of wrong nobody looks for.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local board = dofile(ROOT .. "/src/008-blocked-board.lua")
local mono = dofile(ROOT .. "/src/012-monorepo-map.lua")
local page = dofile(ROOT .. "/src/013-org-page.lua")

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

-- {{{ local function org_from()
local function org_from(map_text, state_text)
  local map, problems = reader.read_map(map_text, "t.map", nil)
  local state = reader.read_state(state_text or "", "t.state", map)
  return { map = map, state = state }, problems
end
-- }}}

-- {{{ names and quoting
do
  check(mono.project_name("RPG-autobattler") == "rpg-autobattler", "uppercase is lowered")
  check(mono.project_name("games/nazi_heaven") == "games-nazi-heaven", "other characters become hyphens")
  check(mono.project_name(".") == "repository-root", "the root has a name")
  check(mono.quote('say "hi" \\ there') == '"say \\"hi\\" \\\\ there"', "quotes and backslashes are escaped")
  local fields = reader.split_fields(mono.quote('a "b" \\c'))
  check(fields and fields[1] == 'a "b" \\c', "and read back as they were")
end
-- }}}

-- {{{ a small queue
local SNAPSHOT = table.concat({
  "# taken 2026-11-03 from a test",
  "1\tmain\tclaude/a\talpha\tthe bottom of a stack",
  "2\tclaude/a\tclaude/b\talpha\tbuilt on 1",
  "3\tclaude/b\tclaude/c\talpha,beta\tbuilt on 2, and touches \"two\" projects",
  "4\tmain\tclaude/d\tbeta\ta lone one",
  "5\tclaude/gone\tclaude/e\t.\tbuilt on a branch nobody has open",
  "",
}, "\n")
local QUESTIONS = "question q1\n  project alpha\n  says \"which way?\"\n  source \"alpha/docs\"\n"

do
  local snap = assert(mono.read_snapshot(SNAPSHOT))
  check(snap.taken == "2026-11-03" and #snap.prs == 5, "the snapshot reads, with its date")
  local questions = assert(mono.read_questions(QUESTIONS, "questions"))
  local text = assert(mono.build(snap, questions))
  check(text == mono.build(assert(mono.read_snapshot(SNAPSHOT)), questions),
        "the same input writes the same map")
  local org, problems = org_from(text)
  check(#problems == 0, "the map it writes is valid"
        .. (problems[1] and (": " .. reader.format_problem(problems[1])) or ""))
  local boxes = org.map.boxes
  check(boxes["pr-2"].ins.base.box == "pr-1", "a stacked pull request waits on the one it is built on")
  check(boxes["pr-5"].ins.base.form == "fixed", "one built on a branch nobody has open is not blocked")
  check(boxes["beta"] and boxes["beta"].ins["pr-3"] and boxes["beta"].ins["pr-4"],
        "a project waits on every pull request that touches it")
  check(boxes["repository-root"].ins["pr-5"] ~= nil, "files at the root belong to the root")
  check(boxes["alpha"].ins["question-q1"].box == "question-q1", "a question holds up its project")
  check(boxes["pr-3"].says:find('"two"', 1, true) ~= nil, "a title's quotes survive")

  local rows = board.board(org)
  check(rows[1].source == "pr-1" and rows[1].state == "ready",
        "the bottom of the stack is the top of the board")
  check(rows[1].reach == 4, "it reaches the two above it and both projects they touch")

  -- Two directories that would get one name are refused, not merged.
  local clash = assert(mono.read_snapshot("1\tmain\th\tBeta,beta\tt\n"))
  local none, err = mono.build(clash, {})
  check(none == nil and err:find("both be called", 1, true) ~= nil,
        "two directories with one map name are refused")
  check(mono.read_snapshot("not a line\n") == nil, "a malformed snapshot line is refused")
  check(mono.read_questions("question q\n  says \"x\"\n", "q") == nil, "a question needs a project")
end
-- }}}

-- {{{ the committed monorepo example is what its input makes
do
  local dir = ROOT .. "/examples/monorepo"
  local snap = assert(mono.read_snapshot(reader.read_file(dir .. "/input/open-pull-requests.tsv")))
  local questions = assert(mono.read_questions(reader.read_file(dir .. "/input/questions"), "questions"))
  check(mono.build(snap, questions) == reader.read_file(dir .. "/org.map"),
        "examples/monorepo/org.map is exactly what its input writes (run ./map-the-monorepo)")
  local org, problems = reader.read_org(dir)
  check(#problems == 0, "the monorepo map is valid")
  check(board.render(board.board(org), true) == reader.read_file(dir .. "/board.txt"),
        "examples/monorepo/board.txt is the board of that map")
  check(page.page(org) == reader.read_file(dir .. "/page.html"),
        "examples/monorepo/page.html is the page of that map")
  local bakery = reader.read_org(ROOT .. "/examples/bakery")
  check(page.page(bakery) == reader.read_file(ROOT .. "/examples/bakery/page.html"),
        "examples/bakery/page.html is the page of the bakery")
end
-- }}}

-- {{{ the page
do
  local bakery = reader.read_org(ROOT .. "/examples/bakery")
  local html = page.page(bakery)
  check(html:sub(1, 15) == "<!DOCTYPE html>", "the page is HTML5")
  check(not html:lower():find("<script", 1, true), "and has no script")
  check(not html:lower():find(" on%a+="), "and no event handlers")
  local ids = {}
  for id in html:gmatch(' id="([^"]+)"') do ids[id] = true end
  local links, broken = 0, 0
  for target in html:gmatch('href="#([^"]+)"') do
    links = links + 1
    if not ids[target] then broken = broken + 1 end
  end
  check(links > 0 and broken == 0, "every link on the page lands on something on the page")
  for _, name in ipairs(bakery.map.box_order) do
    check(ids["box-" .. name], "the page has a place for " .. name)
  end
  check(html:find('<code>clean%-bench</code></td><td>from <a href="#box%-cleaning">cleaning</a>%.bench</td>'
                  .. '<td><span class="waiting">waiting</span>') ~= nil,
        "baking's clean-bench port says it waits on cleaning")
  check(html:find("yesterday's bake, still on the shelf", 1, true) ~= nil, "a fed port shows its note")

  local org = org_from("org t\n  says \"<b>bold</b> & co\"\nperson a\nrole r\n  held-by a\n")
  local escaped = page.page(org)
  check(escaped:find("&lt;b&gt;bold&lt;/b&gt; &amp; co", 1, true) ~= nil and
        not escaped:find("<b>bold", 1, true), "what the map says is escaped, never markup")
end
-- }}}

print(string.format("the monorepo and the page: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
