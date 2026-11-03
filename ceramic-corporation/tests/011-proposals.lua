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

-- 011-proposals.lua
--
-- covers: 104
--
-- A proposal is applied as docs/003-how-a-change-is-accepted.md says, and its
-- acceptance is computed from its lines.
--
-- **The rulings are tested, not only the mechanism.** Document 003 answers the
-- vision's questions with positions — a consumer may route around a producer
-- without asking, nobody gets a new obligation without saying yes, a door
-- needs an outside eye and a week, a change to the rules is judged by the old
-- rules, an approval names the change it approved. Each has a case here,
-- because a ruling the tool does not actually enforce is a slogan.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local proposals = dofile(ROOT .. "/src/010-proposals.lua")

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

-- {{{ local function bakery()
local function bakery()
  local org, problems = reader.read_org(ROOT .. "/examples/bakery")
  assert(#problems == 0)
  return org
end
-- }}}

-- {{{ local function judge()
-- Evaluates proposal text against an org on a day; the proposal's own name is
-- taken as its file's.
local function judge(org, text, today)
  local name = text:match("^proposal ([a-z0-9%-]+)")
  return proposals.evaluate(org, text, (name or "x") .. ".proposal", name, today or "2026-11-03")
end
-- }}}

-- {{{ local function org_from()
local function org_from(map_text, state_text)
  local map, problems = reader.read_map(map_text, "t.map", nil)
  assert(#problems == 0, problems[1] and reader.format_problem(problems[1]))
  local state = reader.read_state(state_text or "", "t.state", map)
  return { map = map, state = state }
end
-- }}}

-- {{{ local function check_of()
-- The named check of the named kind in a report, or nil.
local function check_of(report, kind, text)
  for _, k in ipairs(report.kinds or {}) do
    if k.kind == kind then
      for _, c in ipairs(k.checks) do
        if c.text == text then return c end
      end
    end
  end
  return nil
end
-- }}}

-- {{{ the change id
do
  check(proposals.fnv1a("") == "811c9dc5", "FNV-1a of nothing is the offset basis")
  check(proposals.fnv1a("a") == "e40c292c", "FNV-1a of a is the published vector")
  check(proposals.fnv1a("foobar") == "bf9cf968", "FNV-1a of foobar is the published vector")
end
-- }}}

-- {{{ the bakery's two proposals
do
  local org = bakery()
  local text = reader.read_file(ROOT .. "/examples/bakery/proposals/cy-takes-cleaning.proposal")
  local r = judge(org, text)
  check(r.status == "ready", "Cy taking the vacant bench is ready on Cy's word alone")
  check(#r.kinds == 1 and r.kinds[1].kind == "holding", "it is a holding change and nothing else")
  check(r.new_map_text:find("  out bench %- baking%.clean%-bench\n  held%-by cy\n") ~= nil,
        "held-by cy lands after the block's last body line")

  local oven = reader.read_file(ROOT .. "/examples/bakery/proposals/oven-money-from-takings.proposal")
  local r2 = judge(org, oven)
  check(r2.status == "waiting", "moving the oven money waits")
  check(r2.proposal.change_id == "513f1bd9", "its change id is the one document 003 prints")
  local k = r2.kinds[1]
  check(#r2.kinds == 1 and k.kind == "wiring", "it is a wiring change")
  check(table.concat(k.affected, " ") == "ana bo",
        "it affects Ana (the consumer) and Bo (the new producer), and not Dee (the old producer)")
  check(r2.standing.dee.kind == "object" and r2.status == "waiting",
        "Dee's objection is on the record")

  -- Bo approves the change as it stands: routed around Dee, without Dee.
  local r3 = judge(org, oven .. "approve bo 2026-11-03 513f1bd9\n")
  check(r3.status == "ready", "with Bo's approval it is ready, Dee's objection notwithstanding")

  -- Bo approved a different change: it does not count.
  local r4 = judge(org, oven .. "approve bo 2026-11-03 00000000\n")
  check(r4.status == "waiting", "an approval naming another change id does not count")
  check(r4.standing.bo.id_ok == false, "and is marked as approving another change")

  -- Bo approves on trust (no id), then objects: the later line stands.
  local r5 = judge(org, oven .. "approve bo 2026-11-03\nobject bo 2026-11-04 \"changed my mind\"\n",
                   "2026-11-05")
  check(r5.status == "waiting", "a person's latest answer is the one that counts")

  -- The applied map is valid, and the bakery's state comes across untouched.
  check(r3.new_state_text == reader.read_file(ROOT .. "/examples/bakery/org.state"),
        "no fed line in the bakery names a rewired port, so the state is unchanged")
end
-- }}}

-- {{{ statuses that stop a proposal before the rules
do
  local org = bakery()
  local head = "proposal p\n  by ana\n  opened 2026-11-01\n\n"

  local stale = judge(org, head .. "edit role baking\n  - in flour - nowhere.flour\n")
  check(stale.status == "stale", "a - line the map does not have is stale")

  local taken = judge(org, head .. "add role baking\n  + held-by ana\n")
  check(taken.status == "stale", "adding a block whose name is taken is stale")

  local partial = judge(org, head .. "remove work new-oven\n  - held-by ana\n")
  check(partial.status == "stale", "a remove that does not list every line is stale")

  local wrongkind = judge(org, head .. "edit role new-oven\n  + says \"x\"\n")
  check(wrongkind.status == "stale", "editing a work box as a role is stale")

  local twice = judge(org, head .. "edit role baking\n  + held-by ana\n")
  check(twice.status == "stale", "adding a line the block already has is stale")

  local broken = judge(org, head .. "edit role books\n  - out oven-budget - new-oven.budget\n")
  check(broken.status == "broken", "changing one end of a wire is broken")
  check(broken.reasons[1] and broken.reasons[1]:find("M12") ~= nil, "and the reason names M12")

  local invalid = judge(org, "proposal p\n  by ana\n\nedit role baking\n  + frobnicate\n")
  check(invalid.status == "invalid", "no opened line, and a line no box can hold, is invalid")

  local misnamed = proposals.evaluate(org, head .. "edit role baking\n  + says \"x\"\n",
                                      "q.proposal", "q", "2026-11-03")
  check(misnamed.status == "invalid", "a proposal named differently from its file is invalid (P1)")

  local noreason = judge(org, head .. "edit role baking\n  - says \"turns flour into loaves\"\n"
                         .. "object bo 2026-11-02 \"\"\n")
  check(noreason.status == "invalid", "an objection with an empty reason is invalid (P5)")

  local withdrawn = judge(org, head .. "edit role baking\n  + says \"x\"\n\nwithdrawn 2026-11-02\n")
  check(withdrawn.status == "withdrawn", "a withdrawn proposal is withdrawn")

  local stranger = judge(org, "proposal p\n  by zed\n  opened 2026-11-01\n\nedit role baking\n"
                         .. "  - says \"turns flour into loaves\"\n")
  check(stranger.status == "invalid", "a proposal by somebody not in the org is invalid")
end
-- }}}

-- {{{ who is affected, and the rulings
do
  local org = bakery()

  -- Nobody gets a new obligation without saying yes.
  local r = judge(org, table.concat({
    "proposal more-bread", "  by dee", "  opened 2026-11-01", "",
    "edit role baking", "  + in shop-list - books.list", "",
    "edit role books", "  + out list - baking.shop-list", "",
  }, "\n"))
  check(r.status == "waiting", "adding a wire waits")
  check(table.concat(r.kinds[1].affected, " ") == "ana dee", "on both ends of it")

  -- Nobody changes your box without you.
  local r2 = judge(org, "proposal recipe\n  by bo\n  opened 2026-11-01\n\nedit role baking\n"
                   .. "  - in recipe = \"the house sourdough, seventy percent water\"\n"
                   .. "  + in recipe = \"a cheaper loaf\"\n")
  check(r2.status == "waiting" and r2.kinds[1].kind == "inside", "a change inside Ana's box waits")
  check(table.concat(r2.kinds[1].affected, " ") == "ana", "for Ana")

  -- You can always leave.
  local r3 = judge(org, "proposal leave\n  by cy\n  opened 2026-11-01\n\nedit role delivery\n"
                   .. "  - held-by cy\n")
  check(r3.status == "ready", "Cy leaving delivery needs nobody else")

  -- Nobody can be put in a box without saying yes.
  local r4 = judge(org, "proposal draft\n  by ana\n  opened 2026-11-01\n\nedit role cleaning\n"
                   .. "  + held-by cy\n")
  check(r4.status == "waiting" and table.concat(r4.kinds[1].affected, " ") == "cy",
        "Ana putting Cy on the bench waits for Cy")

  -- A door: the holders, the speaker, an outside eye, and a week.
  local door = "proposal smoke\n  by ana\n  opened 2026-11-01\n\nedit role baking\n"
               .. "  + out smoke $drain \"the oven flue\"\n"
  local r5 = judge(org, door .. "approve dee 2026-11-02\n", "2026-11-03")
  check(r5.status == "waiting", "a new door waits")
  check(table.concat(r5.kinds[1].affected, " ") == "ana dee", "for the box's holder and the drain's speaker")
  check(check_of(r5, "doors", "approve affected all").met, "both of whom have approved")
  check(not check_of(r5, "doors", "approve others 1").met, "but nobody it does not affect has")
  check(not check_of(r5, "doors", "waits 7").met, "and a week has not passed")
  local r6 = judge(org, door .. "approve dee 2026-11-02\napprove bo 2026-11-02\n", "2026-11-08")
  check(r6.status == "ready", "with Bo's outside eye and a week, it is ready")

  -- Joining: you say yes, and somebody already here says yes.
  local join = "proposal eve-joins\n  by eve\n  opened 2026-11-01\n\nadd person eve\n  + says \"bakes rye\"\n"
  local r7 = judge(org, join)
  check(r7.status == "waiting", "Eve asking to join waits")
  check(not check_of(r7, "people", "approve others 1").met, "for somebody already here")
  local r8 = judge(org, join .. "approve bo 2026-11-02\n")
  check(r8.status == "ready", "Bo vouches, and Eve is in")
  local r9 = judge(org, join .. "approve zed 2026-11-02\n")
  check(r9.status == "waiting" and r9.standing.zed.counts == false,
        "a stranger's approval is not counted")

  -- Removing a box needs the consumers of everything it produced.
  local r10 = judge(org, table.concat({
    "proposal no-books", "  by dee", "  opened 2026-11-01", "",
    "remove role books", "  - held-by dee", "  - in takings - selling.takings",
    "  - out oven-budget - new-oven.budget", "  - out payment $mill", "",
    "edit role selling", "  - out takings - books.takings", "",
    "edit work new-oven", "  - in budget - books.oven-budget", "",
  }, "\n"))
  local kinds = {}
  for _, k in ipairs(r10.kinds or {}) do kinds[k.kind] = table.concat(k.affected, " ") end
  check(r10.status == "waiting", "closing the books waits")
  check(kinds.boxes == "" and kinds.holding == "dee", "the box itself affects nobody; Dee leaves it")
  check(kinds.wiring == "ana dee", "the wires out of it need their consumers, Ana; the wire in needs Dee")
  check(kinds.doors == "dee", "and the door to the mill needs Dee")
  check(not r10.new_map_text:find("role books", 1, true), "the block is gone from the new map")
  check(not r10.new_map_text:find("\n\n\n", 1, true), "and it left no double blank line")
end
-- }}}

-- {{{ the rules
do
  -- A rules change is judged by the old rules, and the default is two thirds
  -- and a month.
  local base = "org t\nperson a\nperson b\nperson c\n"
  local org = org_from(base)
  local loosen = "proposal loosen\n  by a\n  opened 2026-11-01\n\nadd rule wiring\n"
                 .. "  + approve affected 1\n"
  local r = judge(org, loosen .. "approve b 2026-11-02\n", "2026-11-05")
  check(r.status == "waiting" and r.kinds[1].kind == "rules", "a new rule waits")
  check(check_of(r, "rules", "approve everyone 2/3").met, "two of three have approved")
  check(not check_of(r, "rules", "waits 30").met, "but a month has not passed")
  local r2 = judge(org, loosen .. "approve b 2026-11-02\n", "2026-12-01")
  check(r2.status == "ready", "after thirty days it is ready")

  -- With a map rule demanding everyone, the same change needs everyone: the
  -- rule in force is the one before the change.
  local strict = org_from(base .. "rule rules\n  approve everyone all\n")
  local r3 = judge(strict, loosen .. "approve b 2026-11-02\n", "2026-12-01")
  check(r3.status == "waiting", "under a rule of everyone, two of three is not enough")
  local r4 = judge(strict, loosen .. "approve b 2026-11-02\napprove c 2026-11-02\n", "2026-11-02")
  check(r4.status == "ready", "and all three is, with no wait, because that rule names none")

  -- A rule in the map replaces the default for its kind.
  local lax = org_from(base .. "role x\n  held-by a\nrole y\n  held-by b\n"
                       .. "rule wiring\n  approve affected 1\n")
  local r5 = judge(lax, "proposal w\n  by a\n  opened 2026-11-01\n\nedit role x\n"
                   .. "  + out o - y.i\n\nedit role y\n  + in i - x.o\n")
  check(r5.status == "ready", "under `approve affected 1`, one of the two ends is enough")
end
-- }}}

-- {{{ carrying the state across
do
  local map = "org t\nperson a\nrole p\n  held-by a\n  out x - c.need\nrole q\n  held-by a\n"
              .. "role c\n  held-by a\n  in need - p.x\n  in keep $w\noutside w\n"
  local org = org_from(map, "fed c.need 2026-11-01\nfed c.keep 2026-11-01\n")
  local r = judge(org, table.concat({
    "proposal rewire", "  by a", "  opened 2026-11-01", "",
    "edit role c", "  - in need - p.x", "  + in need - q.y", "",
    "edit role p", "  - out x - c.need", "",
    "edit role q", "  + out y - c.need", "",
  }, "\n"))
  check(r.status == "ready", "one person rewiring their own boxes is ready")
  check(r.new_state_text == "fed c.keep 2026-11-01\n",
        "a rewired port is waiting again; the untouched one stays fed")
  check(r.dropped_state[1] == "fed c.need 2026-11-01", "and the dropped line is reported")
end
-- }}}

print(string.format("proposals: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
