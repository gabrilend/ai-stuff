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

-- 013-org-page.lua
--
-- Writes an org as one static HTML5 page anybody can open: no JavaScript, no
-- server, nothing the files do not hold.
--
-- The board comes first, because "what is blocking" is the question the page
-- exists to answer. Then every box, each with its holders and ports; every
-- wire is a link to the box at the other end, and every waiting port is marked
-- with what it waits on, so following the links from the top row of the board
-- walks the chain of waiting by hand. Then the people, with what each holds,
-- and the outside parties.
--
-- Run directly: `luajit 013-org-page.lua ORG_DIR > page.html`.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")
local board = dofile(ROOT .. "/src/008-blocked-board.lua")

local M = {}

local STYLE = [[
:root { color-scheme: light dark; --line: #8884; --wait: #c62; --ok: #284; --dim: #888; }
body { font: 15px/1.45 system-ui, sans-serif; max-width: 62rem; margin: 0 auto; padding: 1rem; }
h1, h2, h3 { line-height: 1.2; }
h3 { margin: 0 0 .3rem; font-size: 1.05rem; }
table { border-collapse: collapse; width: 100%; }
th, td { text-align: left; padding: .2rem .5rem; border-bottom: 1px solid var(--line); vertical-align: top; }
td.n { text-align: right; font-variant-numeric: tabular-nums; }
article { border: 1px solid var(--line); border-radius: .4rem; padding: .6rem .8rem; margin: .6rem 0; }
article:target { outline: 2px solid var(--wait); }
.state { font-size: .8rem; padding: 0 .4rem; border-radius: .3rem; border: 1px solid currentColor; }
.blocked, .waiting { color: var(--wait); }
.ready, .fed, .done { color: var(--ok); }
.vacant, .outside, .note { color: var(--dim); }
code { font-size: .9em; }
]]

-- {{{ function M.escape()
function M.escape(s)
  return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
-- }}}
local esc = M.escape

-- {{{ local function link()
-- A box or outside name as a link to its place on the page.
local function link(name)
  if name:sub(1, 1) == "$" then
    return string.format('<a href="#outside-%s">%s</a>', esc(name:sub(2)), esc(name))
  end
  return string.format('<a href="#box-%s">%s</a>', esc(name), esc(name))
end
-- }}}

-- {{{ local function people_links()
local function people_links(list)
  if #list == 0 then return '<span class="vacant">nobody</span>' end
  local out = {}
  for _, p in ipairs(list) do out[#out + 1] = string.format('<a href="#person-%s">%s</a>', esc(p), esc(p)) end
  return table.concat(out, ", ")
end
-- }}}

-- {{{ function M.page()
function M.page(org)
  local map, state = org.map, org.state
  local out = {}
  local function emit(s) out[#out + 1] = s end
  local counts = { ready = 0, blocked = 0, done = 0 }
  for _, name in ipairs(map.box_order) do
    local s = reader.box_state(org, name)
    counts[s] = counts[s] + 1
  end

  emit("<!DOCTYPE html>")
  emit('<html lang="en">')
  emit("<head>")
  emit('<meta charset="utf-8">')
  emit('<meta name="viewport" content="width=device-width, initial-scale=1">')
  emit("<title>" .. esc(map.org.name) .. " — the map</title>")
  emit("<style>" .. STYLE .. "</style>")
  emit("</head>")
  emit("<body>")
  emit("<header>")
  emit("<h1>" .. esc(map.org.name) .. "</h1>")
  if map.org.says then emit("<p>" .. esc(map.org.says) .. "</p>") end
  emit(string.format("<p>%d people, %d boxes: %d blocked, %d ready, %d done. "
    .. "Written from <code>org.map</code> and <code>org.state</code>; nothing on this page is "
    .. "anywhere but those files.</p>",
    #map.person_order, #map.box_order, counts.blocked, counts.ready, counts.done))
  emit('<nav><a href="#board">What is blocking</a> · <a href="#boxes">Every box</a> · '
       .. '<a href="#people">People</a> · <a href="#outside">Outside</a></nav>')
  emit("</header>")

  -- {{{ the board
  local rows = board.board(org)
  emit('<section id="board">')
  emit("<h2>What is blocking</h2>")
  if #rows == 0 then
    emit("<p>Nothing is waiting.</p>")
  else
    emit("<p>Every source of waiting, ranked by <em>reach</em> (how many boxes cannot finish "
         .. "without it), then <em>frees</em> (how many become ready the moment it delivers).</p>")
    emit("<table>")
    emit("<thead><tr><th>source</th><th>state</th><th>owes</th><th>frees</th><th>reach</th>"
         .. "<th>holders</th><th>what it is</th></tr></thead>")
    emit("<tbody>")
    for _, r in ipairs(rows) do
      emit(string.format('<tr><td>%s</td><td class="%s">%s</td><td class="n">%d</td>'
        .. '<td class="n">%d</td><td class="n">%d</td><td>%s</td><td>%s</td></tr>',
        link(r.source), r.state, r.state, r.owes, r.frees, r.reach,
        people_links(r.holders), esc(r.says or "")))
    end
    emit("</tbody>")
    emit("</table>")
  end
  emit("</section>")
  -- }}}

  -- {{{ every box
  emit('<section id="boxes">')
  emit("<h2>Every box</h2>")
  for _, name in ipairs(map.box_order) do
    local box = map.boxes[name]
    local s = reader.box_state(org, name)
    local shown = (s == "ready" and #box.holders == 0) and "vacant" or s
    emit(string.format('<article id="box-%s">', esc(name)))
    emit(string.format('<h3>%s %s <span class="state %s">%s</span></h3>',
                       box.kind, esc(name), shown, shown))
    if box.says then emit("<p>" .. esc(box.says) .. "</p>") end
    emit("<p>Held by " .. people_links(box.holders) .. ".</p>")
    if box.inside then
      emit("<p>Its inside is the org in <code>" .. esc(box.inside.path) .. "</code>.</p>")
    end
    if #box.in_order > 0 or #box.outs > 0 then
      emit("<table>")
      for _, port in ipairs(box.in_order) do
        local rec = box.ins[port]
        local from, mark
        if rec.form == "fixed" then
          from = '<span class="note">fixed: ' .. esc(rec.value) .. "</span>"
          mark = '<span class="fed">fed</span>'
        else
          from = rec.form == "wire" and (link(rec.box) .. "." .. esc(rec.other)) or link("$" .. rec.outside)
          local fed = state.fed[name .. "." .. port]
          if reader.is_fed(org, name, port) then
            mark = '<span class="fed">fed' .. (fed and (" " .. esc(fed.date)) or "") .. "</span>"
            if fed and fed.note then mark = mark .. ' <span class="note">' .. esc(fed.note) .. "</span>" end
          else
            mark = '<span class="waiting">waiting</span>'
          end
        end
        local note = rec.note and (' <span class="note">' .. esc(rec.note) .. "</span>") or ""
        emit(string.format("<tr><td>in</td><td><code>%s</code></td><td>from %s%s</td><td>%s</td></tr>",
                           esc(port), from, note, mark))
      end
      for _, rec in ipairs(box.outs) do
        local to = rec.form == "wire" and (link(rec.box) .. "." .. esc(rec.other)) or link("$" .. rec.outside)
        local note = rec.note and (' <span class="note">' .. esc(rec.note) .. "</span>") or ""
        emit(string.format("<tr><td>out</td><td><code>%s</code></td><td>to %s%s</td><td></td></tr>",
                           esc(rec.port), to, note))
      end
      emit("</table>")
    end
    emit("</article>")
  end
  emit("</section>")
  -- }}}

  -- {{{ the people, and the outside
  local holds = {}
  for _, name in ipairs(map.box_order) do
    for _, p in ipairs(map.boxes[name].holders) do
      holds[p] = holds[p] or {}
      table.insert(holds[p], link(name))
    end
  end
  emit('<section id="people">')
  emit("<h2>People</h2>")
  emit("<table>")
  for _, p in ipairs(map.person_order) do
    local person = map.persons[p]
    local list = holds[p] or {}
    emit(string.format('<tr id="person-%s"><td>%s</td><td>%s</td><td>%s</td></tr>', esc(p), esc(p),
      esc(person.says or ""), #list > 0 and ("holds " .. table.concat(list, ", ")) or
      '<span class="note">holds nothing</span>'))
  end
  emit("</table>")
  emit("</section>")
  emit('<section id="outside">')
  emit("<h2>Outside</h2>")
  if #map.outside_order == 0 then
    emit("<p>No door leads outside this org.</p>")
  else
    emit("<table>")
    for _, o in ipairs(map.outside_order) do
      local outside = map.outsides[o]
      emit(string.format('<tr id="outside-%s"><td>$%s</td><td>%s</td><td>spoken for by %s</td></tr>',
        esc(o), esc(o), esc(outside.says or ""), people_links(outside.speakers)))
    end
    emit("</table>")
  end
  emit("</section>")
  -- }}}

  emit("</body>")
  emit("</html>")
  return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function M.main()
function M.main(args)
  local dir = args[1]
  if not dir or args[2] then
    io.stderr:write("usage: 013-org-page.lua ORG_DIR > page.html\n")
    return 2
  end
  dir = dir:gsub("/+$", "")
  local org, problems = reader.read_org(dir)
  if #problems > 0 then
    for _, p in ipairs(problems) do io.stderr:write(reader.format_problem(p), "\n") end
    io.stderr:write(dir .. ": refused; a page of an invalid map would show something untrue\n")
    return 1
  end
  io.write(M.page(org))
  return 0
end
-- }}}

-- Run as a program only when this file is the program, and only once: a
-- module loaded by another one while it runs is a library, even when the
-- two share a name in arg[0].
if arg and arg[0] and arg[0]:match("013%-org%-page%.lua$") and not rawget(_G, "CERAMIC_MAIN") then
  rawset(_G, "CERAMIC_MAIN", true)
  os.exit(M.main(arg))
end

return M
