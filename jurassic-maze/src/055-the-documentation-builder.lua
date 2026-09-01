-- jurassic-maze — a simulation living inside an isometric maze of stacked stone
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

-- 055-the-documentation-builder.lua
--
-- Turns the project's Markdown into one cross-linked, browsable site.
--
-- Every document, every issue, every companion page and every source file, with
-- a contents column that reaches all of them from any of them. The pages under
-- docs/HTML are a **view**: they are generated, they are not committed, and
-- nothing is lost by their absence. Run ./build-documentation to get them back.
--
-- The Markdown converter here is deliberately small. It handles what this
-- project's prose actually uses -- headings, paragraphs, lists, tables, fenced
-- code, block quotes, rules, and the four inline forms -- and nothing else. A
-- general Markdown implementation would be several times the size of the thing
-- it is formatting.

local M = {}

-- {{{ local function read_file(path)
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end
-- }}}

-- {{{ local function write_file(path, text)
local function write_file(path, text)
  local f = io.open(path, "w")
  if not f then error("cannot write " .. path) end
  f:write(text)
  f:close()
end
-- }}}

-- {{{ local function list_dir(dir, pattern)
local function list_dir(dir, pattern)
  local names = {}
  local pipe = io.popen("ls " .. dir .. " 2>/dev/null")
  if not pipe then return names end
  for name in pipe:lines() do
    if name:match(pattern) then names[#names + 1] = name end
  end
  pipe:close()
  table.sort(names)
  return names
end
-- }}}

-- {{{ local function escape(text)
local function escape(text)
  return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
-- }}}

-- {{{ local function slug(path)
-- The output file name for a source path. Directories are flattened into the
-- name with a dash, so every page sits beside every other and a link between any
-- two of them is just the file name -- no relative paths to get wrong.
local function slug(path)
  local s = path:gsub("%.md$", ""):gsub("%.lua$", "-lua"):gsub("/", "-")
  return s:gsub("[^%w%-]", "-") .. ".html"
end
-- }}}

-- Lua's keywords, for the highlighter. A set rather than a pattern, because a
-- pattern that matches "end" also matches the end of "append".
local KEYWORDS = {}
for word in ([[and break do else elseif end false for function goto if in local
  nil not or repeat return then true until while]]):gmatch("%S+") do
  KEYWORDS[word] = true
end

-- {{{ local function highlight(code)
-- Syntax colouring for Lua, in one pass, by tokenising rather than by running a
-- sequence of substitutions over the whole text.
--
-- Substitutions are the obvious approach and they are wrong in a way that looks
-- fine until it does not: colouring keywords first and then comments means the
-- keywords inside a comment have already been wrapped in tags, and the comment
-- rule then swallows the tags. One pass, longest match first, no backtracking.
local function highlight(code)
  local out = {}
  local i = 1
  local n = #code

  while i <= n do
    local c = code:sub(i, i)

    -- A long comment, then a line comment, then a long string, then a short one.
    local long_comment = code:match("^%-%-%[%[.-%]%]", i) or code:match("^%-%-%[=%[.-%]=%]", i)
    if long_comment then
      out[#out + 1] = '<span class="c">' .. escape(long_comment) .. "</span>"
      i = i + #long_comment
    elseif code:sub(i, i + 1) == "--" then
      local line = code:match("^[^\n]*", i)
      out[#out + 1] = '<span class="c">' .. escape(line) .. "</span>"
      i = i + #line
    elseif c == '"' or c == "'" then
      local str = code:match("^" .. c .. "[^" .. c .. "\n]*" .. c, i)
                  or code:match("^[^\n]*", i)
      out[#out + 1] = '<span class="s">' .. escape(str) .. "</span>"
      i = i + #str
    elseif c:match("%d") then
      local num = code:match("^0[xX]%x+", i) or code:match("^%d+%.?%d*", i)
      out[#out + 1] = '<span class="n">' .. escape(num) .. "</span>"
      i = i + #num
    elseif c:match("[%a_]") then
      local word = code:match("^[%w_]+", i)
      if KEYWORDS[word] then
        out[#out + 1] = '<span class="k">' .. word .. "</span>"
      else
        out[#out + 1] = escape(word)
      end
      i = i + #word
    else
      out[#out + 1] = escape(c)
      i = i + 1
    end
  end

  return table.concat(out)
end
-- }}}

-- {{{ local function inline(text, links)
-- The four inline forms, plus the automatic cross-links.
--
-- Order matters. Code spans are pulled out first and put back last, so that a
-- backtick-quoted file name is not turned into a link and an underscore inside a
-- code span is not turned into emphasis. Every text formatter that does not do
-- this eventually mangles something and nobody can say which rule did it.
local function inline(text, links)
  local spans = {}
  text = text:gsub("`([^`]+)`", function(code)
    spans[#spans + 1] = code
    return "\1" .. #spans .. "\1"
  end)

  text = escape(text)
  text = text:gsub("%[([^%]]+)%]%(([^%)]+)%)", function(label, href)
    if href:match("^https?:") then
      return '<a href="' .. href .. '">' .. label .. "</a>"
    end
    local target = href:gsub("^%.%./", ""):gsub("^%./", "")
    local anchor = target:match("#(.*)$")
    target = target:gsub("#.*$", "")
    return '<a href="' .. slug(target) .. (anchor and ("#" .. anchor) or "") ..
           '">' .. label .. "</a>"
  end)
  text = text:gsub("%*%*([^%*]+)%*%*", "<strong>%1</strong>")
  text = text:gsub("%*([^%*]+)%*", "<em>%1</em>")

  text = text:gsub("\1(%d+)\1", function(k)
    local code = spans[tonumber(k)]
    local target = links[code]
    if target then
      return '<a class="ref" href="' .. target .. '"><code>' ..
             escape(code) .. "</code></a>"
    end
    return "<code>" .. escape(code) .. "</code>"
  end)

  return text
end
-- }}}

-- {{{ local function render(markdown, links)
-- Markdown to HTML. Line-oriented, one state at a time.
local function render(markdown, links)
  local out = {}
  local lines = {}
  for line in (markdown .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end

  local i = 1
  local in_list, in_quote = false, false

  local function close_list() if in_list then out[#out+1] = "</ul>"; in_list = false end end
  local function close_quote() if in_quote then out[#out+1] = "</blockquote>"; in_quote = false end end

  while i <= #lines do
    local line = lines[i]

    if line:match("^```") then
      close_list(); close_quote()
      local lang = line:match("^```(%S*)")
      local body = {}
      i = i + 1
      while i <= #lines and not lines[i]:match("^```") do
        body[#body + 1] = lines[i]
        i = i + 1
      end
      local code = table.concat(body, "\n")
      out[#out + 1] = '<pre class="code"><code>' ..
                      ((lang == "lua") and highlight(code) or escape(code)) ..
                      "</code></pre>"

    elseif line:match("^|") and lines[i + 1] and lines[i + 1]:match("^|[%s%-:|]+|?%s*$") then
      close_list(); close_quote()
      -- A table: a header row, a rule, then body rows until something is not a row.
      local function cells(row)
        local list = {}
        for cell in row:gmatch("|([^|]*)") do list[#list + 1] = cell end
        if #list > 0 and list[#list]:match("^%s*$") then list[#list] = nil end
        return list
      end
      out[#out + 1] = "<table><thead><tr>"
      for _, cell in ipairs(cells(line)) do
        out[#out + 1] = "<th>" .. inline(cell:match("^%s*(.-)%s*$"), links) .. "</th>"
      end
      out[#out + 1] = "</tr></thead><tbody>"
      i = i + 2
      while i <= #lines and lines[i]:match("^|") do
        out[#out + 1] = "<tr>"
        for _, cell in ipairs(cells(lines[i])) do
          out[#out + 1] = "<td>" .. inline(cell:match("^%s*(.-)%s*$"), links) .. "</td>"
        end
        out[#out + 1] = "</tr>"
        i = i + 1
      end
      out[#out + 1] = "</tbody></table>"
      i = i - 1

    elseif line:match("^    %S") and not in_list then
      close_list(); close_quote()
      -- An indented code block. Four spaces, the old spelling, which this
      -- project's prose uses for the two or three places it wants a formula
      -- rather than a program. Without it the lines run together into one
      -- paragraph and an equation reads as a sentence.
      local body = {}
      while i <= #lines and (lines[i]:match("^    ") or lines[i]:match("^%s*$")) do
        -- A blank line inside the block is kept; a blank line that ends it is
        -- not, so trailing blanks are trimmed afterwards.
        body[#body + 1] = lines[i]:gsub("^    ", "")
        i = i + 1
      end
      while #body > 0 and body[#body]:match("^%s*$") do body[#body] = nil end
      i = i - 1
      out[#out + 1] = '<pre class="code"><code>' ..
                      escape(table.concat(body, "\n")) .. "</code></pre>"

    elseif line:match("^#+%s") then
      close_list(); close_quote()
      local hashes, rest = line:match("^(#+)%s+(.*)$")
      local level = #hashes
      local id = rest:lower():gsub("[^%w]+", "-"):gsub("^%-", ""):gsub("%-$", "")
      out[#out + 1] = string.format('<h%d id="%s">%s</h%d>',
                                    level, id, inline(rest, links), level)

    elseif line:match("^%s*[%-%*]%s+") then
      close_quote()
      if not in_list then out[#out + 1] = "<ul>"; in_list = true end
      out[#out + 1] = "<li>" .. inline(line:match("^%s*[%-%*]%s+(.*)$"), links) .. "</li>"

    elseif line:match("^>%s?") then
      close_list()
      if not in_quote then out[#out + 1] = "<blockquote>"; in_quote = true end
      out[#out + 1] = "<p>" .. inline(line:match("^>%s?(.*)$"), links) .. "</p>"

    elseif line:match("^%-%-%-+%s*$") then
      close_list(); close_quote()
      out[#out + 1] = "<hr>"

    elseif line:match("^%s*$") then
      close_list(); close_quote()

    else
      close_quote()
      -- A paragraph runs until a blank line or something that starts a block.
      local para = { line }
      i = i + 1
      -- A continuation line ends the paragraph only if it starts a *block*.
      -- Matching a single backtick here rather than a fence splits a paragraph
      -- whenever a sentence happens to wrap onto a line beginning with an inline
      -- code span, which leaves the code span stranded as a paragraph of its own
      -- and reads as a typesetting fault nobody can find the cause of.
      while i <= #lines and not lines[i]:match("^%s*$")
            and not lines[i]:match("^[#>|]") and not lines[i]:match("^```")
            and not lines[i]:match("^%-%-%-+%s*$")
            and not lines[i]:match("^%s*[%-%*]%s+") do
        para[#para + 1] = lines[i]
        i = i + 1
      end
      i = i - 1
      if not in_list then
        out[#out + 1] = "<p>" .. inline(table.concat(para, " "), links) .. "</p>"
      else
        out[#out] = out[#out]:gsub("</li>$", " " .. inline(table.concat(para, " "), links) .. "</li>")
      end
    end

    i = i + 1
  end

  close_list(); close_quote()
  return table.concat(out, "\n")
end
-- }}}

-- The whole look of the site, in one string.
--
-- Limestone and moss, the same palette the renderer draws the stone with, and
-- the same three-tone shading applied to the page furniture -- so that the
-- documentation and the thing it documents look like they came from the same
-- place. See 041-the-palette.lua, which holds the actual numbers.
local STYLE = [==[
:root {
  --stone-low:  #9e9b88;
  --stone-high: #d1cebd;
  --stone-face: #b8b5a3;
  --moss:       #66854c;
  --ink:        #33312a;
  --ink-soft:   #6a6759;
  --page:       #f4f2e9;
  --panel:      #e7e4d6;
  --rule:       #cdc9b6;
  --link:       #4a6b3f;
  --accent:     #b8563a;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--page);
  color: var(--ink);
  font: 16px/1.62 "Iowan Old Style", "Palatino Linotype", Palatino, Georgia, serif;
}
#shell { display: flex; min-height: 100vh; }
#nav {
  width: 310px; flex: 0 0 310px;
  background: var(--panel);
  border-right: 1px solid var(--rule);
  padding: 22px 0 60px 0;
  position: sticky; top: 0; height: 100vh; overflow-y: auto;
}
#nav h1 {
  font-size: 17px; margin: 0 20px 4px 20px; letter-spacing: 0.02em;
}
#nav .tag { margin: 0 20px 18px 20px; color: var(--ink-soft); font-size: 12.5px; }
#nav .group {
  margin: 18px 20px 6px 20px; font-size: 11px; letter-spacing: 0.14em;
  text-transform: uppercase; color: var(--ink-soft);
  border-top: 1px solid var(--rule); padding-top: 12px;
}
#nav a {
  display: block; padding: 3px 20px 3px 20px;
  color: var(--ink); text-decoration: none; font-size: 13.5px;
  border-left: 3px solid transparent;
}
#nav a:hover { background: #dcd8c7; }
#nav a.here { border-left-color: var(--accent); background: #dcd8c7; font-weight: 600; }
#nav .num { color: var(--ink-soft); font-variant-numeric: tabular-nums; }
#filter {
  margin: 0 20px 6px 20px; width: calc(100% - 40px);
  padding: 5px 8px; border: 1px solid var(--rule); border-radius: 3px;
  background: var(--page); font: inherit; font-size: 13px;
}
main { flex: 1; max-width: 900px; padding: 42px 54px 120px 54px; }
h1, h2, h3, h4 { line-height: 1.24; }
h1 { font-size: 32px; margin: 0 0 6px 0; }
h2 {
  font-size: 22px; margin: 42px 0 12px 0;
  border-bottom: 1px solid var(--rule); padding-bottom: 6px;
}
h3 { font-size: 17.5px; margin: 30px 0 8px 0; }
a { color: var(--link); }
a.ref { text-decoration: none; border-bottom: 1px dotted var(--link); }
code {
  font: 13.5px/1.5 "SF Mono", "DejaVu Sans Mono", Menlo, monospace;
  background: var(--panel); padding: 1px 4px; border-radius: 3px;
}
pre.code {
  background: #2b2a24; color: #dedbc9; padding: 15px 18px;
  border-radius: 5px; overflow-x: auto; font-size: 13px; line-height: 1.55;
}
pre.code code { background: none; padding: 0; color: inherit; }
pre.code .k { color: #d7a75f; }
pre.code .s { color: #a3c27a; }
pre.code .c { color: #7d7a6a; font-style: italic; }
pre.code .n { color: #c98a6a; }
table { border-collapse: collapse; margin: 18px 0; width: 100%; font-size: 14.5px; }
th, td { text-align: left; padding: 7px 11px; border-bottom: 1px solid var(--rule); vertical-align: top; }
th { background: var(--panel); font-size: 12.5px; letter-spacing: 0.05em; text-transform: uppercase; }
tbody tr:hover { background: #eeebdd; }
blockquote {
  margin: 18px 0; padding: 4px 20px; border-left: 4px solid var(--moss);
  background: var(--panel); color: var(--ink-soft);
}
blockquote p { margin: 8px 0; }
hr { border: none; border-top: 1px solid var(--rule); margin: 34px 0; }
.crumb { color: var(--ink-soft); font-size: 12.5px; letter-spacing: 0.08em;
         text-transform: uppercase; margin-bottom: 4px; }
.toy {
  background: var(--panel); border: 1px solid var(--rule);
  border-radius: 6px; padding: 18px 20px; margin: 26px 0;
}
.toy h3 { margin-top: 0; }
.toy .hint { color: var(--ink-soft); font-size: 13.5px; }
.bits { display: flex; flex-wrap: wrap; gap: 3px; margin: 12px 0; }
.bit {
  width: 26px; height: 26px; border: 1px solid var(--rule); border-radius: 3px;
  background: var(--page); cursor: pointer; font-size: 10px; color: var(--ink-soft);
  display: flex; align-items: center; justify-content: center; user-select: none;
}
.bit.on { background: var(--stone-face); color: var(--ink); border-color: var(--stone-low); }
.bit.surface { box-shadow: inset 0 3px 0 var(--moss); }
.readout { font: 13px "DejaVu Sans Mono", monospace; margin: 6px 0; }
.readout b { color: var(--accent); }
label.slider { display: block; margin: 10px 0 2px 0; font-size: 13.5px; }
label.slider input { width: 260px; vertical-align: middle; }
label.slider .val { font: 13px "DejaVu Sans Mono", monospace; color: var(--accent); }
.bars { margin: 12px 0; }
.bar { display: flex; align-items: center; gap: 10px; margin: 2px 0; font-size: 13px; }
.bar .lab { width: 78px; text-align: right; color: var(--ink-soft);
            font: 12px "DejaVu Sans Mono", monospace; }
.bar .fill { height: 13px; background: var(--stone-low); border-radius: 2px; }
.bar .amt { font: 12px "DejaVu Sans Mono", monospace; color: var(--ink-soft); }
canvas { display: block; background: #cfdbe4; border-radius: 4px; margin: 10px 0; }
footer { margin-top: 70px; padding-top: 18px; border-top: 1px solid var(--rule);
         color: var(--ink-soft); font-size: 13px; }
@media (max-width: 900px) {
  #shell { display: block; }
  #nav { position: static; width: auto; height: auto; }
  main { padding: 24px 20px 80px 20px; }
}
]==]

-- The one piece of script every page carries: the contents filter, which is the
-- difference between a hundred and sixty links being navigable and being a wall.
local SCRIPT = [==[
(function () {
  var box = document.getElementById('filter');
  if (!box) return;
  var links = Array.prototype.slice.call(document.querySelectorAll('#nav a'));
  var groups = Array.prototype.slice.call(document.querySelectorAll('#nav .group'));
  box.addEventListener('input', function () {
    var q = box.value.toLowerCase();
    links.forEach(function (a) {
      a.style.display = a.textContent.toLowerCase().indexOf(q) >= 0 ? '' : 'none';
    });
    groups.forEach(function (g) {
      var any = false, n = g.nextElementSibling;
      while (n && !n.classList.contains('group')) {
        if (n.tagName === 'A' && n.style.display !== 'none') any = true;
        n = n.nextElementSibling;
      }
      g.style.display = any ? '' : 'none';
    });
  });
})();
]==]

-- {{{ local function page(title, crumb, nav, body, extra, home)
-- The shell every page shares.
local function page(title, crumb, nav, body, extra, home)
  return table.concat({
    "<!doctype html>",
    '<html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    "<title>", escape(title), " &middot; jurassic-maze</title>",
    "<style>", STYLE, "</style></head><body>",
    '<div id="shell">',
    '<aside id="nav">',
    '<h1><a href="', home, '" style="text-decoration:none;color:inherit">jurassic-maze</a></h1>',
    '<p class="tag">a simulation living inside an isometric maze of stacked stone</p>',
    '<input id="filter" placeholder="filter these&hellip;">',
    nav,
    "</aside>",
    "<main>",
    '<p class="crumb">', escape(crumb), "</p>",
    body,
    extra or "",
    '<footer>Generated by <code>./build-documentation</code> from the Markdown ',
    "beside it. These pages are a view, not a source: they are not committed, ",
    "and nothing is lost by their absence.</footer>",
    "</main></div>",
    "<script>", SCRIPT, "</script>",
    "</body></html>",
  })
end
-- }}}

-- {{{ local function toy_column()
-- The bit explorer. Click a layer, watch the surface expression compute.
--
-- This one page does more to explain the project's central idea than the
-- document does, because the expression `c & ~(c >> 1)` is three operations and
-- reading about it is nothing like watching the answer change as bits move.
local function toy_column()
  return [==[
<div class="toy">
<h3>A column, and the three operations that find its surfaces</h3>
<p class="hint">Click a layer to make it stone or air. A surface is a stone layer
with air directly above it &mdash; the green edge. The whole set of them comes out
of the column in three operations, all sixteen layers at once, with no loop and
no branch.</p>
<div class="bits" id="colbits"></div>
<div class="readout">column&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b id="r-col"></b></div>
<div class="readout">column &gt;&gt; 1&nbsp;<b id="r-shift"></b></div>
<div class="readout">~(that)&nbsp;&nbsp;&nbsp;&nbsp;<b id="r-not"></b></div>
<div class="readout">&amp; column&nbsp;&nbsp;&nbsp;<b id="r-and"></b> &nbsp; &larr; the surfaces</div>
<canvas id="colcanvas" width="300" height="260"></canvas>
<p class="hint" id="colsay"></p>
</div>
<script>
(function () {
  var N = 16, col = 0x001F;   // a plain pile five blocks high
  var wrap = document.getElementById('colbits');
  for (var i = N - 1; i >= 0; i--) {
    var d = document.createElement('div');
    d.className = 'bit'; d.dataset.layer = i; d.textContent = i;
    wrap.appendChild(d);
  }
  function bits(v) {
    var s = '';
    for (var i = N - 1; i >= 0; i--) s += ((v >> i) & 1) ? '1' : '0';
    return s;
  }
  function draw(surf) {
    var cv = document.getElementById('colcanvas'), g = cv.getContext('2d');
    g.fillStyle = '#cfdbe4'; g.fillRect(0, 0, cv.width, cv.height);
    // hw, hh and lp are the projection's three constants. lp has to be
    // comparable to hh or the blocks overlap so far that their side faces
    // vanish and the pile reads as a stack of flat plates.
    var x = 150, base = 236, hw = 30, hh = 15, lp = 17;
    function quad(pts, fill) {
      g.beginPath(); g.moveTo(pts[0][0], pts[0][1]);
      for (var k = 1; k < pts.length; k++) g.lineTo(pts[k][0], pts[k][1]);
      g.closePath(); g.fillStyle = fill; g.fill();
      g.strokeStyle = '#3a3830'; g.lineWidth = 1; g.stroke();
    }
    // Bottom up, so a block drawn later covers the one beneath it -- the same
    // painter's ordering the renderer uses, for the same reason.
    for (var l = 0; l < N; l++) {
      if (!((col >> l) & 1)) continue;
      var yt = base - (l + 1) * lp;
      quad([[x, yt + hh], [x + hw, yt], [x + hw, yt + lp], [x, yt + hh + lp]], '#8f8c7b');
      quad([[x, yt + hh], [x - hw, yt], [x - hw, yt + lp], [x, yt + hh + lp]], '#6f6d5f');
      quad([[x, yt - hh], [x + hw, yt], [x, yt + hh], [x - hw, yt]],
           ((surf >> l) & 1) ? '#8fae72' : '#c6c3b1');
    }
  }
  function refresh() {
    var surf = col & ~(col >> 1) & ((1 << N) - 1);
    document.getElementById('r-col').textContent = bits(col);
    document.getElementById('r-shift').textContent = bits(col >> 1);
    document.getElementById('r-not').textContent = bits(~(col >> 1) & ((1 << N) - 1));
    document.getElementById('r-and').textContent = bits(surf);
    var n = 0;
    for (var i = 0; i < N; i++) if ((surf >> i) & 1) n++;
    var say;
    if (col === 0) say = 'An empty column has no surfaces. There is nowhere on it to stand.';
    else if (surf === 0) say = 'Solid to the top of the world: still no surfaces, which is correct.';
    else if (n === 1) say = 'One surface. A plain pile of stone.';
    else say = n + ' surfaces. Every hole in the column makes another floor and another roof, and the expression found them all without knowing holes exist.';
    document.getElementById('colsay').textContent = say;
    Array.prototype.forEach.call(wrap.children, function (d) {
      var l = +d.dataset.layer;
      d.className = 'bit' + (((col >> l) & 1) ? ' on' : '') + (((surf >> l) & 1) ? ' surface' : '');
    });
    draw(surf);
  }
  wrap.addEventListener('click', function (e) {
    if (!e.target.dataset.layer) return;
    col ^= (1 << (+e.target.dataset.layer));
    refresh();
  });
  refresh();
})();
</script>
]==]
end
-- }}}

-- {{{ local function toy_projection()
-- The projection, with its three constants on sliders.
local function toy_projection()
  return [==[
<div class="toy">
<h3>The projection, with its three constants loose</h3>
<p class="hint">Half-width against half-height is the two-to-one that makes every
diamond edge advance exactly two pixels across for one down. Layer height is
independent of both, which is what lets the maze be squat or towering without the
floor plan changing underneath it.</p>
<label class="slider">half width <span class="val" id="v-hw">16</span>
  <input type="range" id="s-hw" min="6" max="34" value="16"></label>
<label class="slider">half height <span class="val" id="v-hh">8</span>
  <input type="range" id="s-hh" min="3" max="34" value="8"></label>
<label class="slider">layer pixels <span class="val" id="v-lp">10</span>
  <input type="range" id="s-lp" min="2" max="30" value="10"></label>
<canvas id="projcanvas" width="620" height="330"></canvas>
<p class="hint" id="projsay"></p>
</div>
<script>
(function () {
  var H = [[3,3,3,1,1],[3,0,3,1,1],[3,3,3,1,5],[1,1,1,1,1],[1,1,5,1,1]];
  function draw() {
    var hw = +document.getElementById('s-hw').value,
        hh = +document.getElementById('s-hh').value,
        lp = +document.getElementById('s-lp').value;
    document.getElementById('v-hw').textContent = hw;
    document.getElementById('v-hh').textContent = hh;
    document.getElementById('v-lp').textContent = lp;
    var cv = document.getElementById('projcanvas'), g = cv.getContext('2d');
    g.fillStyle = '#cfdbe4'; g.fillRect(0, 0, cv.width, cv.height);
    var ox = cv.width / 2, oy = 70;
    function P(x, y, h) { return [ (x - y) * hw + ox, (x + y) * hh - h * lp + oy ]; }
    // Row by row, which is back to front: the array's own memory order.
    for (var y = 0; y < 5; y++) for (var x = 0; x < 5; x++) {
      var h = H[y][x];
      var rh = (x + 1 < 5) ? H[y][x+1] : 0, lh = (y + 1 < 5) ? H[y+1][x] : 0;
      function quad(pts, fill) {
        g.beginPath(); g.moveTo(pts[0][0], pts[0][1]);
        for (var k = 1; k < pts.length; k++) g.lineTo(pts[k][0], pts[k][1]);
        g.closePath(); g.fillStyle = fill; g.fill();
        g.strokeStyle = '#3a3830'; g.lineWidth = 1; g.stroke();
      }
      if (h > rh) quad([P(x+1,y,h),P(x+1,y+1,h),P(x+1,y+1,rh),P(x+1,y,rh)], '#8f8c7b');
      if (h > lh) quad([P(x,y+1,h),P(x+1,y+1,h),P(x+1,y+1,lh),P(x,y+1,lh)], '#6f6d5f');
      quad([P(x,y,h),P(x+1,y,h),P(x+1,y+1,h),P(x,y+1,h)], '#c6c3b1');
    }
    var ratio = (hw / hh).toFixed(2);
    document.getElementById('projsay').textContent =
      'A cell is ' + ratio + ' times wider than it is tall. At exactly 2.00 the diamond edges land on whole pixels and the stone reads as stone; away from it they do not, and the maze reads as a stack of slightly wrong staircases.';
  }
  ['s-hw','s-hh','s-lp'].forEach(function (id) {
    document.getElementById(id).addEventListener('input', draw);
  });
  draw();
})();
</script>
]==]
end
-- }}}

-- {{{ local function toy_numbers(stats)
-- The numbers a real maze produced, at the moment the site was built.
local function toy_numbers(stats)
  local rows = {}
  local most = 1
  for _, row in ipairs(stats.histogram) do
    if row[2] > most then most = row[2] end
  end
  for _, row in ipairs(stats.histogram) do
    rows[#rows + 1] = string.format(
      '<div class="bar"><span class="lab">layer %d</span>' ..
      '<span class="fill" style="width:%dpx"></span>' ..
      '<span class="amt">%d</span></div>',
      row[1], math.max(2, math.floor(430 * row[2] / most)), row[2])
  end

  return table.concat({
    '<div class="toy"><h3>What one maze actually came out as</h3>',
    '<p class="hint">Measured when these pages were built, by generating seed ',
    tostring(stats.seed), ' and running the validator over it. No number here is ',
    'typed into a document, which is why none of them can go stale.</p>',
    '<table><tbody>',
    stats.table,
    '</tbody></table>',
    '<p class="hint">How many cells stand at each height. The spikes are the ',
    'terraces; the thin layers between them are what only staircases and wall ',
    'tops occupy.</p>',
    '<div class="bars">', table.concat(rows), "</div>",
    "</div>",
  })
end
-- }}}

-- {{{ local function gather_stats(root)
-- Generates a maze and validates it, so the site can show real numbers.
local function gather_stats(root)
  local Params    = dofile(root .. "/src/028-maze-parameters.lua")
  local Streams   = dofile(root .. "/src/029-random-streams.lua")
  local Carve     = dofile(root .. "/src/031-carving.lua")
  local Validator = dofile(root .. "/src/032-the-validator.lua")
  local Renderer  = dofile(root .. "/src/042-the-renderer.lua")
  local Stone     = dofile(root .. "/src/030-the-stone.lua")

  local seed = 7
  local p = Params.check(Params.with{ seed = seed })
  local store, report = Carve.generate(root, p, Streams.make_set(seed))
  Validator.validate(root, store, p, report)

  local blocks = 0
  for i = 0, store.cells - 1 do blocks = blocks + store.height[i] + 1 end
  local faces = Renderer.count_faces(Stone, store)

  local rows = {
    { "footprint", string.format("%d by %d cells, %d layers deep", p.width, p.depth, p.layers) },
    { "floor cells", report.floor_cells },
    { "staircases", string.format("%d, of which %d were needed for connectivity",
        (report.staircases_cut or 0) + (report.extra_staircases or 0),
        report.staircases_cut or 0) },
    { "orphan cells filled", report.orphans_filled or 0 },
    { "diameter", string.format("%d steps between the two most distant places", report.diameter) },
    { "wall-top pieces", string.format("%d &mdash; a wall you can climb onto is not a wall",
        report.wall_top_pieces) },
    { "blocks of stone", blocks },
    { "faces drawn", string.format("%d, which is %.1f%% of them", faces, 100 * faces / blocks) },
    { "fill fraction", string.format("%.3f", report.fill_fraction) },
  }

  local table_html = {}
  for _, row in ipairs(rows) do
    table_html[#table_html + 1] = "<tr><td>" .. row[1] .. "</td><td><strong>" ..
                                  tostring(row[2]) .. "</strong></td></tr>"
  end

  local histogram = {}
  for l = 0, p.layers - 1 do
    local n = report.height_histogram[l] or 0
    if n > 0 then histogram[#histogram + 1] = { l, n } end
  end

  return { seed = seed, table = table.concat(table_html), histogram = histogram }
end
-- }}}

-- {{{ function M.build(root)
-- The whole site.
function M.build(root)
  local out = root .. "/docs/HTML"
  os.execute("mkdir -p " .. out)

  -- Every page, grouped as the contents column shows them.
  local groups = {}
  local pages  = {}

  local function add(group, source, title, kind)
    local entry = { group = group, source = source, title = title, kind = kind,
                    file = slug(source) }
    pages[#pages + 1] = entry
    groups[group] = groups[group] or {}
    table.insert(groups[group], entry)
    return entry
  end

  -- {{{ collecting the pages
  for _, name in ipairs(list_dir(root .. "/docs", "%.md$")) do
    local text = read_file(root .. "/docs/" .. name) or ""
    local title = text:match("^#%s+([^\n]+)") or name
    add("Documents", "docs/" .. name, title, "doc")
  end
  for _, name in ipairs(list_dir(root .. "/notes", ".")) do
    add("Notes", "notes/" .. name, name, "note")
  end
  for _, name in ipairs(list_dir(root .. "/issues", "%.md$")) do
    local text = read_file(root .. "/issues/" .. name) or ""
    local title = text:match("^#%s+([^\n]+)") or name
    add("Issues, open", "issues/" .. name, title, "issue")
  end
  for _, name in ipairs(list_dir(root .. "/issues/completed", "%.md$")) do
    local text = read_file(root .. "/issues/completed/" .. name) or ""
    local title = text:match("^#%s+([^\n]+)") or name
    add("Issues, done", "issues/completed/" .. name, title, "issue")
  end
  for _, dir in ipairs({ "src", "assets" }) do
    for _, name in ipairs(list_dir(root .. "/" .. dir, "%.info%.md$")) do
      local text = read_file(root .. "/" .. dir .. "/" .. name) or ""
      local title = text:match("^#%s+([^\n]+)") or name
      add("Companion pages", dir .. "/" .. name, title, "info")
    end
    for _, name in ipairs(list_dir(root .. "/" .. dir, "%.lua$")) do
      add("Source", dir .. "/" .. name, name, "source")
    end
  end
  for _, name in ipairs({ "COPYING.md", "inspiration/NOTICE.md" }) do
    add("Licence", name, name, "doc")
  end
  -- }}}

  -- Automatic cross-links: any backticked source file name becomes a link to
  -- that file's companion page, and any `NNN-something.lua` mentioned anywhere
  -- resolves too. Written once, here, so no document has to carry the link.
  local links = {}
  for _, entry in ipairs(pages) do
    local base = entry.source:match("([^/]+)$")
    if entry.kind == "info" then
      local stem = base:gsub("%.info%.md$", "")
      links[stem] = entry.file
      links[stem .. ".lua"] = entry.file
    elseif entry.kind == "source" then
      links[base] = links[base] or entry.file
    end
  end

  local ORDER = { "Documents", "Notes", "Issues, open", "Issues, done",
                  "Companion pages", "Source", "Licence" }

  local stats = gather_stats(root)

  for _, entry in ipairs(pages) do
    -- {{{ the contents column, with this page marked
    local nav = {}
    for _, group in ipairs(ORDER) do
      if groups[group] then
        nav[#nav + 1] = '<p class="group">' .. group .. "</p>"
        for _, other in ipairs(groups[group]) do
          local number = other.source:match("(%d%d%d)%-") or ""
          nav[#nav + 1] = string.format('<a class="%s" href="%s"><span class="num">%s</span> %s</a>',
            (other == entry) and "here" or "", other.file, number,
            escape(other.title:gsub("^%d+%s*&mdash;%s*", ""):gsub("^%d+%s*—%s*", "")))
        end
      end
    end
    -- }}}

    local body, extra
    if entry.kind == "source" then
      local code = read_file(root .. "/" .. entry.source) or ""
      local companion = entry.source:gsub("%.lua$", ".info.md")
      body = "<h1>" .. escape(entry.title) .. "</h1>" ..
             '<p><a href="' .. slug(companion) .. '">Read the companion page instead</a> ' ..
             "&mdash; the source is for when one named function is misbehaving.</p>" ..
             '<pre class="code"><code>' .. highlight(code) .. "</code></pre>"
    else
      local text = read_file(root .. "/" .. entry.source) or ""
      if entry.kind == "note" then
        body = "<h1>" .. escape(entry.title) .. "</h1><pre class=\"code\"><code>" ..
               escape(text) .. "</code></pre>"
      else
        body = render(text, links)
      end
      -- The toys go on the pages they explain, so that a reader meets each one
      -- immediately after the paragraph that describes it.
      if entry.source == "docs/002-the-stone-and-what-is-inferred.md" then
        extra = toy_column()
      elseif entry.source == "docs/006-the-isometric-projection.md" then
        extra = toy_projection()
      elseif entry.source == "docs/001-what-this-is.md" then
        extra = toy_numbers(stats)
      end
    end

    write_file(out .. "/" .. entry.file,
               page(entry.title, entry.group, table.concat(nav), body, extra,
                    slug("docs/001-what-this-is.md")))
  end

  -- The front door.
  local first = nil
  for _, entry in ipairs(pages) do
    if entry.source == "docs/001-what-this-is.md" then first = entry end
  end
  if first then
    write_file(out .. "/index.html",
      '<!doctype html><meta charset="utf-8">' ..
      '<meta http-equiv="refresh" content="0; url=' .. first.file .. '">' ..
      '<p><a href="' .. first.file .. '">jurassic-maze</a></p>')
  end

  return #pages
end
-- }}}

M.render    = render
M.highlight = highlight
M.slug      = slug
M.read_file = read_file
M.write_file = write_file
M.list_dir  = list_dir
M.escape    = escape

return M
