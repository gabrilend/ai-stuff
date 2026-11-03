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

-- 010-proposals.lua
--
-- Reads a change proposal, applies it to the map as text, and says whether it
-- may be applied and why.
--
-- Everything here is docs/003-how-a-change-is-accepted.md made executable:
-- the proposal file (P1-P6), the change id, the six steps of applying, the
-- derived status, kinds of change, who each line affects, and the rules with
-- their defaults. Nothing about a proposal is taken from what it says about
-- itself; all of it is computed from its lines and the map's.
--
-- Run directly: `luajit 010-proposals.lua ORG_DIR PROPOSAL [--today DATE] [--write]`.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")

local M = {}
local complain = reader.complain

local CHANGE_HEADS = { add = true, edit = true, remove = true }
local CHANGE_KINDS = { person = true, outside = true, role = true, work = true,
                       rule = true, org = true }

-- The rules a kind uses when the map has no rule block for it.
M.DEFAULT_RULES = {
  inside  = { approve = { affected = { all = true } } },
  holding = { approve = { affected = { all = true } } },
  wiring  = { approve = { affected = { all = true } } },
  boxes   = { approve = { affected = { all = true } } },
  doors   = { approve = { affected = { all = true }, others = { count = 1 } }, waits = 7 },
  people  = { approve = { affected = { all = true }, others = { count = 1 } } },
  rules   = { approve = { everyone = { p = 2, q = 3 } }, waits = 30 },
}

-- {{{ local function set_add()
local function set_add(set, list)
  for _, x in ipairs(list or {}) do set[x] = true end
  return set
end
-- }}}

-- {{{ local function sorted_keys()
local function sorted_keys(set)
  local list = {}
  for k in pairs(set) do list[#list + 1] = k end
  table.sort(list)
  return list
end
-- }}}

-- {{{ function M.fnv1a()
-- 32-bit FNV-1a in arithmetic both LuaJIT and Lua 5.4 compute exactly: no bit
-- library, no integer division operator, no product over 2^53.
local function xor8(a, b)
  local r, place = 0, 1
  for _ = 1, 8 do
    local x, y = a % 2, b % 2
    if x ~= y then r = r + place end
    a, b, place = (a - x) / 2, (b - y) / 2, place * 2
  end
  return r
end

function M.fnv1a(s)
  local h = 2166136261
  for i = 1, #s do
    local low = h % 256
    h = h - low + xor8(low, s:byte(i))
    -- times 16777619, which is 2^24 + 403, modulo 2^32
    h = ((h % 256) * 16777216 + h * 403) % 4294967296
  end
  return string.format("%08x", h)
end
-- }}}

-- {{{ function M.read_proposal()
-- Reads a proposal's text. `basename` is the file name without .proposal, for
-- P1. Returns the proposal and its problems; the problems make it invalid.
function M.read_proposal(text, file, basename)
  local problems = {}
  local lines = reader.lex(text, file, problems)
  local p = { file = file, lines = lines, changes = {}, answers = {}, targets = {} }
  local first = true
  for _, line in ipairs(lines) do
    if line.kind == "head" then
      local f, q = line.fields, line.quoted
      local kw = f[1]
      if first then
        first = false
        if kw ~= "proposal" or #f ~= 2 or not reader.is_name(f[2]) then
          complain(problems, file, line.n, "P1", "a proposal begins `proposal NAME`")
        elseif basename and f[2] ~= basename then
          complain(problems, file, line.n, "P1", "named %s in a file called %s.proposal", f[2], basename)
        end
        p.name, p.head = f[2], line
        for _, body in ipairs(line.body) do
          local bf, bq = body.fields, body.quoted
          local bkw = bf[1]
          if (bkw == "by" or bkw == "opened") and #bf == 2 and not bq[2] then
            if p[bkw] then
              complain(problems, file, body.n, "P2", "a second %s", bkw)
            elseif bkw == "by" and not reader.is_name(bf[2]) then
              complain(problems, file, body.n, "P2", "by names a person")
            elseif bkw == "opened" and not reader.is_date(bf[2]) then
              complain(problems, file, body.n, "L8", "%q is not a date", bf[2])
            else
              p[bkw] = bf[2]
            end
          elseif bkw == "says" and #bf == 2 and bq[2] then
            if p.says then complain(problems, file, body.n, "P2", "a second says") end
            p.says = bf[2]
          else
            complain(problems, file, body.n, "P2", "a proposal's own lines are by, opened and says")
          end
        end
      elseif CHANGE_HEADS[kw] then
        local kind, name = f[2], f[3]
        if #f ~= 3 or q[2] or q[3] or not CHANGE_KINDS[kind] or not reader.is_name(name) then
          complain(problems, file, line.n, "P3", "a change is `add|edit|remove KIND NAME`")
        elseif kind == "org" and kw ~= "edit" then
          complain(problems, file, line.n, "P3", "the org can only be edited")
        else
          local key = (kind == "rule" and "rule:" or "") .. name
          if p.targets[key] then
            complain(problems, file, line.n, "P4", "%s is changed twice in one proposal", name)
          end
          p.targets[key] = true
          local change = { op = kw, kind = kind, name = name, line = line, adds = {}, removes = {} }
          for _, body in ipairs(line.body) do
            local marker = body.fields[1]
            local rest = body.text:match("^[+-] +(.+)$")
            if (marker ~= "+" and marker ~= "-") or body.quoted[1] or not rest then
              complain(problems, file, body.n, "P3", "a change line is `+ LINE` or `- LINE`")
            elseif (kw == "add" and marker == "-") or (kw == "remove" and marker == "+") then
              complain(problems, file, body.n, "P3", "%s takes only %s lines", kw,
                       kw == "add" and "+" or "-")
            else
              local lf, lq = reader.split_fields(rest)
              local rec, code, msg
              if lf then rec, code, msg = reader.parse_body(kind, lf, lq) end
              if not rec then
                complain(problems, file, body.n, "P3", "not a %s line: %s", kind, msg or lq)
              else
                rec.text, rec.line = rest, body.n
                local list = marker == "+" and change.adds or change.removes
                list[#list + 1] = rec
              end
            end
          end
          if kw == "edit" and #line.body == 0 then
            complain(problems, file, line.n, "P3", "an edit with no lines")
          end
          p.changes[#p.changes + 1] = change
        end
      elseif kw == "approve" or kw == "object" or kw == "withdrawn" or kw == "applied" then
        if #line.body > 0 then
          complain(problems, file, line.n, "P5", "an answer has no body lines")
        end
        local ok = false
        if kw == "approve" then
          ok = (#f == 3 or (#f == 4 and not q[4] and f[4]:match("^%x%x%x%x%x%x%x%x$") ~= nil))
               and not q[2] and not q[3] and reader.is_name(f[2]) and reader.is_date(f[3])
        elseif kw == "object" then
          ok = #f == 4 and q[4] and f[4]:match("%S") ~= nil and not q[2] and not q[3]
               and reader.is_name(f[2]) and reader.is_date(f[3])
        elseif kw == "applied" then
          -- `applied DATE [N]`: N is the change's place in the org's history.
          ok = (#f == 2 or (#f == 3 and not q[3] and f[3]:match("^[1-9]%d*$") ~= nil))
               and not q[2] and reader.is_date(f[2])
        else
          ok = #f == 2 and not q[2] and reader.is_date(f[2])
        end
        if not ok then
          complain(problems, file, line.n, "P5", "%s is malformed%s", kw,
                   kw == "object" and ": an objection needs a non-empty reason" or "")
        elseif kw == "withdrawn" or kw == "applied" then
          if p[kw] then complain(problems, file, line.n, "P6", "%s twice", kw) end
          p[kw] = f[2]
          if kw == "applied" and f[3] then p.applied_seq = tonumber(f[3]) end
        else
          p.answers[#p.answers + 1] = { kind = kw, person = f[2], date = f[3],
                                        id = kw == "approve" and f[4] or nil,
                                        reason = kw == "object" and f[4] or nil,
                                        line = line.n }
        end
      else
        complain(problems, file, line.n, "P3", "%q is not a head a proposal can have", kw)
      end
    end
  end
  if first then complain(problems, file, nil, "P1", "the file is empty") end
  if not p.by and not first then complain(problems, file, p.head and p.head.n, "P2", "no by line") end
  if not p.opened and not first then complain(problems, file, p.head and p.head.n, "P2", "no opened line") end
  if p.withdrawn and p.applied then
    complain(problems, file, nil, "P6", "both withdrawn and applied")
  end
  -- The change id: the change's lines exactly as written.
  local parts = {}
  for _, c in ipairs(p.changes) do
    parts[#parts + 1] = c.line.raw
    for _, body in ipairs(c.line.body) do parts[#parts + 1] = body.raw end
  end
  p.change_id = M.fnv1a(table.concat(parts, "\n"))
  return p, problems
end
-- }}}

-- {{{ local function find_block()
-- The map block a change names, if it exists with that kind.
local function find_block(map, kind, name)
  if kind == "rule" then return map.rules[name] end
  if kind == "org" then return (map.org and map.org.name == name) and map.org or nil end
  local b = map.names[name]
  if b and b.kind == kind then return b end
  return nil
end
-- }}}

-- {{{ function M.apply_text()
-- Steps 1 to 4 of applying: check every - line, remove, add, tidy. Returns
-- the new map text, or nil and the reasons it is stale.
function M.apply_text(map, proposal)
  local stale = {}
  local removed = {}      -- map line number -> true
  local insert_after = {} -- map line number -> list of raw lines
  local appended = {}

  for _, c in ipairs(proposal.changes) do
    local block = find_block(map, c.kind, c.name)
    if c.op == "add" then
      local taken = c.kind == "rule" and map.rules[c.name] or map.names[c.name]
      if taken then
        stale[#stale + 1] = string.format("add %s %s: the name is already taken", c.kind, c.name)
      else
        appended[#appended + 1] = ""
        appended[#appended + 1] = c.kind .. " " .. c.name
        for _, rec in ipairs(c.adds) do appended[#appended + 1] = "  " .. rec.text end
      end
    elseif not block then
      stale[#stale + 1] = string.format("%s %s %s: there is no such %s in the map",
                                        c.op, c.kind, c.name, c.kind)
    else
      local head = block.head
      local claimed = {}
      for _, rec in ipairs(c.removes) do
        local found = nil
        for _, body in ipairs(head.body) do
          if not claimed[body.n] and body.text == rec.text then found = body break end
        end
        if found then
          claimed[found.n] = true
        else
          stale[#stale + 1] = string.format("%s %s %s: `%s` is not in the map", c.op, c.kind,
                                            c.name, rec.text)
        end
      end
      if c.op == "remove" then
        for _, body in ipairs(head.body) do
          if not claimed[body.n] then
            stale[#stale + 1] = string.format("remove %s %s: `%s` is in the map and not listed",
                                              c.kind, c.name, body.text)
          end
        end
        -- The head, everything up to its last body line, and the comments
        -- directly above it.
        local last = head.body[#head.body] and head.body[#head.body].n or head.n
        for n = head.n, last do removed[n] = true end
        local n = head.n - 1
        while n >= 1 and map.lines[n].kind == "comment" do
          removed[n] = true
          n = n - 1
        end
      else
        local anchor = head.n
        local remaining = {}
        for _, body in ipairs(head.body) do
          if claimed[body.n] then
            removed[body.n] = true
          else
            anchor = body.n
            remaining[body.text] = true
          end
        end
        local adding = {}
        for _, rec in ipairs(c.adds) do
          if remaining[rec.text] or adding[rec.text] then
            stale[#stale + 1] = string.format("edit %s %s: `%s` is already there", c.kind,
                                              c.name, rec.text)
          end
          adding[rec.text] = true
          insert_after[anchor] = insert_after[anchor] or {}
          table.insert(insert_after[anchor], "  " .. rec.text)
        end
      end
    end
  end
  if #stale > 0 then return nil, stale end

  local out = {}
  local after_removal = false
  for n, line in ipairs(map.lines) do
    if removed[n] then
      after_removal = true
    else
      -- Tidy: a removal never leaves two blank lines in a row, or a blank
      -- line first in the file.
      if not (line.raw == "" and after_removal and (#out == 0 or out[#out] == "")) then
        out[#out + 1] = line.raw
      end
      after_removal = false
    end
    for _, raw in ipairs(insert_after[n] or {}) do out[#out + 1] = raw end
  end
  -- A removal at the end of the file does not leave a blank line there.
  if #map.lines > 0 and removed[#map.lines] then
    while #out > 0 and out[#out] == "" do out[#out] = nil end
  end
  for i, raw in ipairs(appended) do
    if i == 1 and (#out == 0 or out[#out] == "") then
      -- the file already ends in a blank line, or is empty
    else
      out[#out + 1] = raw
    end
  end
  return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function M.carry_state()
-- Step 6: a fed line survives only if its port still has the identical in
-- line; a done line only if its work box survives. Returns the new state text
-- and the lines dropped.
function M.carry_state(state, old_map, new_map)
  local out, dropped = {}, {}
  for _, line in ipairs(state.lines) do
    local keep = true
    if line.kind == "head" then
      local kw, ref = line.fields[1], line.fields[2]
      if kw == "fed" then
        local box, port = ref:match("^([^.]+)%.([^.]+)$")
        local old = old_map.boxes[box] and old_map.boxes[box].ins[port]
        local new = new_map.boxes[box] and new_map.boxes[box].ins[port]
        keep = old ~= nil and new ~= nil and old.text == new.text
      elseif kw == "done" then
        keep = new_map.boxes[ref] ~= nil and new_map.boxes[ref].kind == "work"
      end
    end
    if keep then out[#out + 1] = line.raw else dropped[#dropped + 1] = line.raw end
  end
  local text = #out > 0 and (table.concat(out, "\n") .. "\n") or ""
  return text, dropped
end
-- }}}

-- {{{ local function holders_of()
-- A box's holders before the change; for a box the proposal adds, the
-- holders it is added with.
local function holders_of(old_map, new_map, name)
  local b = old_map.boxes[name] or new_map.boxes[name]
  return b and b.holders or {}
end
-- }}}

-- {{{ local function speakers_of()
local function speakers_of(old_map, new_map, name)
  local set = {}
  if old_map.outsides[name] then set_add(set, old_map.outsides[name].speakers) end
  if new_map and new_map.outsides[name] then set_add(set, new_map.outsides[name].speakers) end
  return set
end
-- }}}

-- {{{ function M.kinds_and_affected()
-- For every changed line: its kind and the people it affects. Returns
-- { kind -> set of people } for each kind present.
function M.kinds_and_affected(proposal, old_map, new_map)
  local by_kind = {}
  local everyone = set_add({}, old_map.person_order)
  local function note(kind, people)
    by_kind[kind] = by_kind[kind] or {}
    for person in pairs(people) do by_kind[kind][person] = true end
  end
  for _, c in ipairs(proposal.changes) do
    -- The block itself, when it is added or removed.
    if c.op ~= "edit" then
      if c.kind == "person" then note("people", { [c.name] = true })
      elseif c.kind == "outside" then note("doors", speakers_of(old_map, new_map, c.name))
      elseif c.kind == "rule" then note("rules", everyone)
      else note("boxes", {}) end
    end
    local lines = {}
    for _, rec in ipairs(c.adds) do lines[#lines + 1] = { added = true, rec = rec } end
    for _, rec in ipairs(c.removes) do lines[#lines + 1] = { added = false, rec = rec } end
    for _, l in ipairs(lines) do
      local rec, added = l.rec, l.added
      if c.kind == "org" or c.kind == "rule" then
        note("rules", everyone)
      elseif c.kind == "person" then
        note("inside", { [c.name] = true })
      elseif c.kind == "outside" then
        note("doors", speakers_of(old_map, new_map, c.name))
      else
        local holders = set_add({}, holders_of(old_map, new_map, c.name))
        if rec.kw == "says" or rec.kw == "inside" or (rec.kw == "in" and rec.form == "fixed") then
          note("inside", holders)
        elseif rec.kw == "held-by" then
          if added then
            holders[rec.person] = true
            note("holding", holders)
          else
            note("holding", { [rec.person] = true })
          end
        elseif rec.form == "door" then
          note("doors", set_add(holders, sorted_keys(speakers_of(old_map, new_map, rec.outside))))
        elseif rec.kw == "in" then
          note("wiring", holders)
        elseif added then
          note("wiring", holders)
        else
          -- Removing an out line affects the consumer's holders, not the
          -- producer's: an obligation taken away is not imposed.
          note("wiring", set_add({}, holders_of(old_map, new_map, rec.box)))
        end
      end
    end
  end
  return by_kind
end
-- }}}

-- {{{ function M.answers()
-- Each person's standing answer: their latest line, the later in the file on
-- a tie; the proposer's `by` is an approval on the opened date. Returns
-- { person -> answer }, with answer.counts saying whether an approval counts.
function M.answers(proposal, people)
  local standing = {}
  local list = {}
  if proposal.by then
    list[#list + 1] = { kind = "approve", person = proposal.by, date = proposal.opened,
                        line = 0, proposer = true }
  end
  for _, a in ipairs(proposal.answers) do list[#list + 1] = a end
  for _, a in ipairs(list) do
    local prev = standing[a.person]
    if prev == nil or a.date > prev.date or (a.date == prev.date and a.line > prev.line) then
      standing[a.person] = a
    end
  end
  for person, a in pairs(standing) do
    a.is_person = people[person] == true
    a.id_ok = a.id == nil or a.id == proposal.change_id
    a.counts = a.kind == "approve" and a.is_person and a.id_ok
  end
  return standing
end
-- }}}

-- {{{ local function enough()
-- Whether `have` approvals out of `of` meet an approve spec.
local function enough(spec, have, of)
  if spec.all then return have >= of end
  if spec.count then return have >= math.min(spec.count, of) end
  return have * spec.q >= spec.p * of
end
-- }}}

-- {{{ local function spec_text()
local function spec_text(subject, spec)
  local amount = spec.all and "all" or spec.count and tostring(spec.count)
                 or (spec.p .. "/" .. spec.q)
  return "approve " .. subject .. " " .. amount
end
-- }}}

-- {{{ function M.judge()
-- The rules for each kind present, against the standing answers. Returns
-- { { kind, affected (sorted list), from (map or default), checks = { {text, met, detail} } } }.
function M.judge(proposal, old_map, by_kind, standing, today)
  local results = {}
  local everyone = old_map.person_order
  for _, kind in ipairs(reader.KINDS) do
    local affected = by_kind[kind]
    if affected then
      local rule = old_map.rules[kind]
      local from = rule and "the map" or "the default"
      rule = rule or M.DEFAULT_RULES[kind]
      local checks = {}
      local function approved(person)
        return standing[person] and standing[person].counts
      end
      local aff_list = sorted_keys(affected)
      for _, subject in ipairs({ "affected", "everyone", "others" }) do
        local spec = rule.approve[subject]
        if spec then
          local have, of, missing = 0, 0, {}
          if subject == "others" then
            for person, a in pairs(standing) do
              if a.counts and not affected[person] then have = have + 1 end
            end
            of = spec.count
            local met = have >= spec.count
            checks[#checks + 1] = { text = spec_text(subject, spec), met = met,
              detail = string.format("%d approval%s from people this does not affect",
                                     have, have == 1 and "" or "s") }
          else
            local pool = subject == "affected" and aff_list or everyone
            for _, person in ipairs(pool) do
              of = of + 1
              if approved(person) then have = have + 1 else missing[#missing + 1] = person end
            end
            local met = enough(spec, have, of)
            checks[#checks + 1] = { text = spec_text(subject, spec), met = met,
              detail = string.format("%d of %d%s", have, of,
                #missing > 0 and ("; not yet: " .. table.concat(missing, " ")) or "") }
          end
        end
      end
      if rule.waits then
        local days = reader.day_number(today) - reader.day_number(proposal.opened)
        checks[#checks + 1] = { text = "waits " .. rule.waits, met = days >= rule.waits,
          detail = string.format("open %d day%s", days, days == 1 and "" or "s") }
      end
      results[#results + 1] = { kind = kind, affected = aff_list, from = from, checks = checks }
    end
  end
  return results
end
-- }}}

-- {{{ function M.evaluate()
-- Everything about a proposal against an org, today. Returns a report:
-- { status, proposal, problems, reasons, kinds, new_map_text, new_state_text,
--   dropped_state, standing }.
--
-- With `as_of` (a date), the proposal is judged as it stood that day: its
-- `applied` line is set aside and so is every answer dated after it. That is
-- how a replayed history asks whether a change was ready when it was applied.
function M.evaluate(org, proposal_text, file, basename, today, as_of)
  local proposal, problems = M.read_proposal(proposal_text, file, basename)
  if as_of then
    proposal.applied, proposal.applied_seq = nil, nil
    local kept = {}
    for _, a in ipairs(proposal.answers) do
      if a.date <= as_of then kept[#kept + 1] = a end
    end
    proposal.answers = kept
  end
  local report = { proposal = proposal, problems = problems, reasons = {} }
  if proposal.withdrawn then report.status = "withdrawn" return report end
  if proposal.applied then report.status = "applied" return report end
  if #problems > 0 then report.status = "invalid" return report end

  local old_map = org.map
  local new_text, stale = M.apply_text(old_map, proposal)
  if not new_text then
    report.status, report.reasons = "stale", stale
    return report
  end
  report.new_map_text = new_text
  local new_map, broken = reader.read_map(new_text, old_map.file, org.dir)
  if #broken > 0 then
    report.status = "broken"
    for _, b in ipairs(broken) do report.reasons[#report.reasons + 1] = reader.format_problem(b) end
    return report
  end
  report.new_state_text, report.dropped_state = M.carry_state(org.state, old_map, new_map)

  -- Who may answer: everyone in the map before, and anybody this adds.
  local people = set_add({}, old_map.person_order)
  for _, c in ipairs(proposal.changes) do
    if c.kind == "person" and c.op == "add" then people[c.name] = true end
  end
  if not people[proposal.by] then
    report.status = "invalid"
    complain(problems, file, proposal.head.n, "P2",
             "%s is not a person in the map, and this proposal does not add them", proposal.by)
    return report
  end
  report.standing = M.answers(proposal, people)
  local by_kind = M.kinds_and_affected(proposal, old_map, new_map)
  report.kinds = M.judge(proposal, old_map, by_kind, report.standing, today)
  report.status = "ready"
  for _, k in ipairs(report.kinds) do
    for _, check in ipairs(k.checks) do
      if not check.met then report.status = "waiting" end
    end
  end
  return report
end
-- }}}

-- {{{ function M.render()
-- The report as text, without the diff.
function M.render(report)
  local p, out = report.proposal, {}
  out[#out + 1] = string.format("proposal %s, by %s, opened %s", p.name or "?",
                                p.by or "?", p.opened or "?")
  if p.says then out[#out + 1] = "  \"" .. p.says .. "\"" end
  out[#out + 1] = "status: " .. report.status
  out[#out + 1] = "change id: " .. p.change_id
  for _, prob in ipairs(report.problems) do out[#out + 1] = "  " .. reader.format_problem(prob) end
  for _, r in ipairs(report.reasons) do out[#out + 1] = "  " .. r end
  for _, k in ipairs(report.kinds or {}) do
    out[#out + 1] = string.format("%s (rule from %s); affects: %s", k.kind, k.from,
      #k.affected > 0 and table.concat(k.affected, " ") or "nobody")
    for _, check in ipairs(k.checks) do
      out[#out + 1] = string.format("  [%s] %s -- %s", check.met and "met" or "not met",
                                    check.text, check.detail)
    end
  end
  if report.standing then
    local touched = {}
    for _, k in ipairs(report.kinds or {}) do set_add(touched, k.affected) end
    out[#out + 1] = "answers:"
    for _, person in ipairs(sorted_keys(report.standing)) do
      local a = report.standing[person]
      local line = string.format("  %s %s %s", person, a.kind, a.date)
      if a.proposer then line = line .. " (proposer)" end
      if a.reason then line = line .. " \"" .. a.reason .. "\"" end
      if not a.is_person then
        line = line .. " -- not a person in the org; not counted"
      elseif a.kind == "object" and not touched[person] then
        line = line .. " -- this change does not affect them: on the record, and not blocking"
      end
      if a.kind == "approve" and a.is_person then
        if a.id == nil and not a.proposer then
          line = line .. " -- no change id; taken on trust"
        elseif a.id and not a.id_ok then
          line = line .. " -- approved change " .. a.id .. ", which is no longer this one; not counted"
        end
      end
      out[#out + 1] = line
    end
  end
  for _, d in ipairs(report.dropped_state or {}) do
    out[#out + 1] = "state no longer true after this: " .. d
  end
  return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ local function write_file()
local function write_file(path, text)
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
end
-- }}}

-- {{{ function M.diff()
-- A unified diff of two texts, by the system's diff.
function M.diff(old_text, new_text, label)
  local a, b = os.tmpname(), os.tmpname()
  write_file(a, old_text)
  write_file(b, new_text)
  local pipe = io.popen(string.format("diff -u --label 'a/%s' --label 'b/%s' '%s' '%s'",
                                      label, label, a, b))
  local text = pipe:read("*a")
  pipe:close()
  os.remove(a)
  os.remove(b)
  return text
end
-- }}}

-- {{{ function M.list_proposals()
-- The proposal files of an org, by path, in name order.
function M.list_proposals(dir)
  local list = {}
  local pipe = io.popen("ls -1 '" .. dir:gsub("'", "'\\''") .. "/proposals' 2>/dev/null")
  for name in pipe:lines() do
    if name:match("%.proposal$") then list[#list + 1] = dir .. "/proposals/" .. name end
  end
  pipe:close()
  table.sort(list)
  return list
end
-- }}}

-- {{{ function M.next_seq()
-- One more than the highest change number any applied proposal carries.
function M.next_seq(dir)
  local high = 0
  for _, path in ipairs(M.list_proposals(dir)) do
    local p = M.read_proposal(reader.read_file(path) or "", path, nil)
    if p.applied_seq and p.applied_seq > high then high = p.applied_seq end
  end
  return high + 1
end
-- }}}

-- {{{ function M.main()
function M.main(args)
  local usage = "usage: 010-proposals.lua ORG_DIR PROPOSAL [--today YYYY-MM-DD] [--write]\n"
  local dir, path, today, write = nil, nil, os.date("%Y-%m-%d"), false
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--write" then write = true
    elseif a == "--today" then i = i + 1; today = args[i]
    elseif dir == nil then dir = a:gsub("/+$", "")
    elseif path == nil then path = a
    else io.stderr:write(usage) return 2 end
    i = i + 1
  end
  if not dir or not path or not reader.is_date(today or "") then
    io.stderr:write(usage)
    return 2
  end
  if not path:find("/", 1, true) and not reader.read_file(path) then
    path = dir .. "/proposals/" .. path
    if not path:match("%.proposal$") then path = path .. ".proposal" end
  end
  local text = reader.read_file(path)
  if not text then
    io.stderr:write("no proposal at " .. path .. "\n")
    return 1
  end
  local org, problems = reader.read_org(dir)
  if #problems > 0 then
    for _, p in ipairs(problems) do io.stderr:write(reader.format_problem(p), "\n") end
    io.stderr:write(dir .. ": the map itself is refused; fix it before judging a change to it\n")
    return 1
  end
  local basename = path:match("([^/]+)%.proposal$")
  local report = M.evaluate(org, text, path, basename, today)
  io.write(M.render(report))
  if report.new_map_text then
    local map_text = reader.read_file(dir .. "/org.map")
    io.write(M.diff(map_text, report.new_map_text, "org.map"))
  end
  if write then
    if report.status ~= "ready" then
      io.stdout:flush()
      io.stderr:write("not written: the proposal is " .. report.status .. ", not ready\n")
      return 1
    end
    write_file(dir .. "/org.map", report.new_map_text)
    if reader.read_file(dir .. "/org.state") or report.new_state_text ~= "" then
      write_file(dir .. "/org.state", report.new_state_text)
    end
    local sep = text:sub(-1) == "\n" and "" or "\n"
    local seq = M.next_seq(dir)
    write_file(path, text .. sep .. "\napplied " .. today .. " " .. seq .. "\n")
    print(string.format("applied %s as change %d: org.map written, the proposal marked applied",
                        today, seq))
  end
  return (report.status == "ready" or report.status == "applied") and 0 or 3
end
-- }}}

-- Run as a program only when this file is the program, and only once: a
-- module loaded by another one while it runs is a library, even when the
-- two share a name in arg[0].
if arg and arg[0] and arg[0]:match("010%-proposals%.lua$") and not rawget(_G, "CERAMIC_MAIN") then
  rawset(_G, "CERAMIC_MAIN", true)
  os.exit(M.main(arg))
end

return M
