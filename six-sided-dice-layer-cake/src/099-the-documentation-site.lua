-- 099-the-documentation-site.lua
--
-- Builds the whole project as a cross-linked site: every document, blueprint,
-- companion page and ticket, reachable from every other, with the numbers taken
-- from the ledger at build time rather than transcribed.
--
-- For a general reader: reading this project on disk means holding a
-- number-to-file mapping in your head, because a hundred and eighty files refer
-- to each other by number alone -- 037 is a blueprint, 1004 is a ticket, 009 is
-- a document. On a page every one of those is a link, and every page also says
-- what points at it, which is a direction nobody can see from inside a file.
--
-- Built, never edited. Nothing under docs/HTML/ is a source file and version
-- control ignores it. The builder is the artifact.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local units  = dofile(DIR .. "/src/091-units.lua")
local ledger = dofile(DIR .. "/src/094-ledger.lua")

local M = {}

-- {{{ local function esc()
local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
-- }}}

-- {{{ local function ls()
local function ls(pattern)
  local out = {}
  local p = io.popen("ls -1 " .. pattern .. " 2>/dev/null")
  if not p then return out end
  for line in p:lines() do out[#out + 1] = line end
  p:close()
  table.sort(out)
  return out
end
-- }}}

-- Every page in the site, keyed by the number a reference would use. Built
-- first, because rendering needs to know what a number resolves to before it
-- can turn it into a link.
local INDEX = {}

-- {{{ local function slug()
local function slug(path)
  local base = path:match("([^/]+)$"):gsub("%.md$", "")
  return base
end
-- }}}

-- {{{ local function collect()
local function collect(dir)
  local pages = {}
  local function add(path, kind)
    local base = path:match("([^/]+)$")
    local num = base:match("^(%d+%a?)%-")
    local page = {
      path = path, kind = kind, file = base,
      slug = slug(path), num = num, links = {}, backlinks = {},
    }
    pages[#pages + 1] = page
    -- a companion page shares its number with the blueprint it describes, so
    -- only the blueprint claims the number a reference resolves to
    if num and not (kind == "info") then INDEX[num] = page end
    return page
  end
  for _, p in ipairs(ls(dir .. "/docs/*.md")) do add(p, "doc") end
  for _, p in ipairs(ls(dir .. "/notes/*")) do add(p, "note") end
  for _, p in ipairs(ls(dir .. "/src/*.md")) do
    add(p, p:match("%.info%.md$") and "info" or "blueprint")
  end
  for _, p in ipairs(ls(dir .. "/issues/*.md")) do add(p, "issue") end
  for _, p in ipairs(ls(dir .. "/issues/completed/*.md")) do add(p, "done") end
  return pages
end
-- }}}

-- A very small markdown renderer. It handles what this project's documents
-- actually use and refuses to grow: headings, paragraphs, fenced blocks,
-- tables, lists, rules, and three kinds of span. Anything it does not know
-- passes through as text, which is the right failure for a document nobody is
-- going to write in a hurry.

-- {{{ local function spans()
local function spans(s, page)
  s = esc(s)
  -- `code`, and inside it a bare number becomes a link to whatever it names
  s = s:gsub("`([^`]+)`", function(code)
    local target = INDEX[code]
    if target then
      if page then page.links[code] = true end
      return ('<a class="ref" href="%s.html">%s</a>'):format(target.slug, code)
    end
    return "<code>" .. code .. "</code>"
  end)
  s = s:gsub("%*%*([^%*]+)%*%*", "<strong>%1</strong>")
  s = s:gsub("%f[%*]%*([^%*]+)%*%f[^%*]", "<em>%1</em>")
  return s
end
-- }}}

-- One renderer per fenced block tag. The notation blocks are the reason this
-- site is worth building: they are the only place a reader sees a symbol's
-- value beside its meaning without opening the ledger.
local FENCE = {}

-- {{{ FENCE.symbols()
FENCE.symbols = function(lines, L, page)
  local out = { '<table class="sym"><tr><th>symbol<th>unit<th>kind<th>value<th>meaning' }
  for _, ln in ipairs(lines) do
    local t = ln:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" and t:sub(1, 1) ~= "#" then
      local f = {}
      for part in (t .. "|"):gmatch("([^|]*)|") do
        f[#f + 1] = part:gsub("^%s+", ""):gsub("%s+$", "")
      end
      if #f >= 5 then
        local name = f[1]
        local val = "—"
        if L and L.value[name] then
          local ok, s = pcall(units.format, L.value[name], f[2], 5)
          val = ok and s or units.format(L.value[name])
        end
        out[#out + 1] = ('<tr><td><a class="sym" id="s-%s" href="#s-%s">%s</a>'
          .. '<td>%s<td class="k-%s">%s<td class="v">%s<td>%s')
          :format(name, name, esc(name), esc(f[2]), f[3], f[3], esc(val), spans(f[5], page))
      end
    end
  end
  out[#out + 1] = "</table>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ FENCE.constraints()
FENCE.constraints = function(lines, L, page)
  local out = { '<table class="con"><tr><th>tag<th>relation<th>because' }
  for _, ln in ipairs(lines) do
    local t = ln:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" and t:sub(1, 1) ~= "#" then
      local f = {}
      for part in (t .. "|"):gmatch("([^|]*)|") do
        f[#f + 1] = part:gsub("^%s+", ""):gsub("%s+$", "")
      end
      if #f >= 3 then
        out[#out + 1] = ("<tr><td><code>%s</code><td><code>%s</code><td>%s")
          :format(esc(f[1]), esc(f[2]), spans(f[3], page))
      end
    end
  end
  out[#out + 1] = "</table>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ FENCE.drawing()
FENCE.drawing = function(lines, L, page)
  local caption = lines[1] and lines[1]:gsub("^%s+", "") or ""
  local body = {}
  for i = 2, #lines do body[#body + 1] = esc(lines[i]) end
  return ('<figure class="dwg"><pre>%s</pre><figcaption>%s</figcaption></figure>')
    :format(table.concat(body, "\n"), spans(caption, page))
end
-- }}}

-- {{{ FENCE.meta()
FENCE.meta = function(lines, L, page)
  local bits = {}
  for _, ln in ipairs(lines) do
    local k, v = ln:match("^%s*([%w_]+)%s*|%s*(.-)%s*$")
    if k then bits[#bits + 1] = ("<span><b>%s</b> %s</span>"):format(k, spans(v, page)) end
  end
  return '<div class="meta">' .. table.concat(bits, "") .. "</div>"
end
-- }}}

-- {{{ local function markdown()
local function markdown(text, L, page)
  local out, i = {}, 1
  local lines = {}
  for ln in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = ln end

  local function flush_para(buf)
    if #buf > 0 then
      out[#out + 1] = "<p>" .. spans(table.concat(buf, " "), page) .. "</p>"
    end
  end

  local para = {}
  while i <= #lines do
    local ln = lines[i]
    local tag = ln:match("^%s*```%s*(%a*)%s*$")
    if tag ~= nil then
      flush_para(para); para = {}
      local body, j = {}, i + 1
      while j <= #lines and not lines[j]:match("^%s*```%s*$") do
        body[#body + 1] = lines[j]; j = j + 1
      end
      local f = FENCE[tag]
      if f then
        out[#out + 1] = f(body, L, page)
      else
        out[#out + 1] = "<pre>" .. esc(table.concat(body, "\n")) .. "</pre>"
      end
      i = j + 1
    elseif ln:match("^#+%s") then
      flush_para(para); para = {}
      local hashes, rest = ln:match("^(#+)%s+(.*)$")
      local n = math.min(#hashes, 4)
      out[#out + 1] = ("<h%d>%s</h%d>"):format(n, spans(rest, page), n)
      i = i + 1
    elseif ln:match("^%s*|") then
      flush_para(para); para = {}
      local rows, j = {}, i
      while j <= #lines and lines[j]:match("^%s*|") do rows[#rows + 1] = lines[j]; j = j + 1 end
      local t = { "<table>" }
      for r, row in ipairs(rows) do
        if not row:match("^%s*|[%s%-:|]+|%s*$") then
          local cells = {}
          for c in (row:gsub("^%s*|", "") .. "|"):gmatch("([^|]*)|") do
            cells[#cells + 1] = c:gsub("^%s+", ""):gsub("%s+$", "")
          end
          -- the trailing empty cell a bar-terminated row produces
          if cells[#cells] == "" then cells[#cells] = nil end
          local cell = (r == 1) and "th" or "td"
          local bits = {}
          for _, c in ipairs(cells) do
            bits[#bits + 1] = ("<%s>%s</%s>"):format(cell, spans(c, page), cell)
          end
          t[#t + 1] = "<tr>" .. table.concat(bits, "")
        end
      end
      t[#t + 1] = "</table>"
      out[#out + 1] = table.concat(t, "\n")
      i = j
    elseif ln:match("^%s*[%-%*]%s") or ln:match("^%s*%d+%.%s") then
      flush_para(para); para = {}
      local ordered = ln:match("^%s*%d+%.%s") ~= nil
      local items, j = {}, i
      while j <= #lines and (lines[j]:match("^%s*[%-%*]%s") or lines[j]:match("^%s*%d+%.%s")
                             or (lines[j]:match("^%s%s+%S") and #items > 0)) do
        local body = lines[j]:match("^%s*[%-%*]%s+(.*)$") or lines[j]:match("^%s*%d+%.%s+(.*)$")
        if body then items[#items + 1] = body
        else items[#items] = items[#items] .. " " .. lines[j]:gsub("^%s+", "") end
        j = j + 1
      end
      local t = { ordered and "<ol>" or "<ul>" }
      for _, it in ipairs(items) do t[#t + 1] = "<li>" .. spans(it, page) end
      t[#t + 1] = ordered and "</ol>" or "</ul>"
      out[#out + 1] = table.concat(t, "\n")
      i = j
    elseif ln:match("^%s*%-%-%-+%s*$") then
      flush_para(para); para = {}
      out[#out + 1] = "<hr>"
      i = i + 1
    elseif ln:match("^%s*>%s?") then
      flush_para(para); para = {}
      out[#out + 1] = "<blockquote>" .. spans(ln:gsub("^%s*>%s?", ""), page) .. "</blockquote>"
      i = i + 1
    elseif ln:match("^%s*$") then
      flush_para(para); para = {}
      i = i + 1
    else
      para[#para + 1] = ln
      i = i + 1
    end
  end
  flush_para(para)
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function style()
local function style()
  return [[
:root{--ink:#1a1a17;--bg:#faf8f4;--dim:#6b6a63;--rule:#d8d4cb;--acc:#8a4f1e;
--panel:#f2efe8;--given:#2e6f4e;--derived:#2c5a86;--measured:#7a5c14;--target:#a03328}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font:15.5px/1.6 Charter,"Bitstream Charter",Georgia,serif;}
#wrap{display:flex;align-items:flex-start}
nav{width:250px;flex:0 0 250px;position:sticky;top:0;height:100vh;overflow-y:auto;
padding:1.2rem .8rem;border-right:1px solid var(--rule);background:var(--panel);
font:12.5px/1.45 ui-monospace,"DejaVu Sans Mono",monospace}
nav h2{font:600 11px/1.4 ui-monospace,monospace;letter-spacing:.09em;
text-transform:uppercase;color:var(--dim);margin:1.1rem 0 .35rem}
nav a{display:block;padding:1px 4px;color:var(--ink);text-decoration:none;border-radius:2px}
nav a:hover{background:#e6e1d6}
nav a.here{background:var(--acc);color:#fff}
main{flex:1;min-width:0;max-width:52rem;padding:2rem 2.4rem 6rem}
h1{font-size:1.85rem;line-height:1.2;margin:.2rem 0 1rem}
h2{font-size:1.25rem;margin:2.2rem 0 .6rem;padding-bottom:.2rem;border-bottom:1px solid var(--rule)}
h3{font-size:1.05rem;margin:1.6rem 0 .4rem}
h4{font-size:.95rem;margin:1.2rem 0 .3rem;color:var(--dim)}
p{margin:.7rem 0}
a{color:var(--acc)}
a.ref{font:600 .88em ui-monospace,monospace;text-decoration:none;
background:#efe7dc;padding:0 .28em;border-radius:2px;white-space:nowrap}
a.ref:hover{background:var(--acc);color:#fff}
code{font:.88em ui-monospace,"DejaVu Sans Mono",monospace;background:#efece5;
padding:0 .25em;border-radius:2px}
pre{overflow-x:auto;background:#f4f1ea;border:1px solid var(--rule);
padding:.7rem .9rem;border-radius:3px;
font:12.5px/1.35 ui-monospace,"DejaVu Sans Mono",monospace}
table{border-collapse:collapse;margin:.9rem 0;font-size:.92em;display:block;
overflow-x:auto;max-width:100%}
th,td{border:1px solid var(--rule);padding:.28rem .55rem;text-align:left;vertical-align:top}
th{background:var(--panel);font-weight:600;font-size:.86em;letter-spacing:.02em}
table.sym td.v{font:12.5px ui-monospace,monospace;white-space:nowrap}
table.sym a.sym{font:600 12.5px ui-monospace,monospace;text-decoration:none;color:var(--ink)}
td.k-given{color:var(--given)}td.k-derived{color:var(--derived)}
td.k-measured{color:var(--measured)}td.k-target{color:var(--target);font-weight:700}
figure.dwg{margin:1.2rem 0}
figure.dwg pre{background:#fff}
figcaption{font-size:.85em;color:var(--dim);margin-top:.3rem;font-style:italic}
div.meta{font:12px ui-monospace,monospace;color:var(--dim);margin:.4rem 0 1rem}
div.meta span{margin-right:1.4rem}
blockquote{margin:.9rem 0;padding:.1rem 0 .1rem 1rem;border-left:3px solid var(--rule);
color:var(--dim);font-style:italic}
hr{border:0;border-top:1px solid var(--rule);margin:2rem 0}
.pointers{margin-top:3rem;padding-top:1rem;border-top:1px solid var(--rule);font-size:.9em}
.pointers h2{border:0;font-size:.8rem;letter-spacing:.09em;text-transform:uppercase;
color:var(--dim);margin:.2rem 0 .5rem}
.built{margin-top:2.5rem;font-size:.8em;color:var(--dim);font-style:italic}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:.7rem;margin:1.2rem 0}
.card{background:var(--panel);border:1px solid var(--rule);border-radius:3px;padding:.7rem .8rem}
.card b{display:block;font:600 1.5rem/1.1 Charter,Georgia,serif}
.card span{font-size:.8em;color:var(--dim)}
@media(max-width:820px){#wrap{display:block}nav{width:auto;height:auto;position:static;
border-right:0;border-bottom:1px solid var(--rule)}main{padding:1.2rem}}
]]
end
-- }}}

-- {{{ local function navigation()
local function navigation(pages, here)
  local groups = {
    { "doc", "documents" }, { "note", "notes" }, { "blueprint", "blueprints" },
    { "info", "companion pages" }, { "issue", "open tickets" }, { "done", "completed" },
  }
  local out = { '<nav><a href="index.html"' ..
                (here == "index" and ' class="here"' or "") .. ">&#8962; front page</a>" }
  for _, g in ipairs(groups) do
    local kind, label = g[1], g[2]
    local any = false
    for _, p in ipairs(pages) do
      if p.kind == kind then
        if not any then out[#out + 1] = "<h2>" .. label .. "</h2>"; any = true end
        out[#out + 1] = ('<a href="%s.html"%s>%s</a>')
          :format(p.slug, p.slug == here and ' class="here"' or "", esc(p.slug))
      end
    end
  end
  out[#out + 1] = "</nav>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function page_html()
local function page_html(title, nav, body)
  return table.concat({
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
    "<title>" .. esc(title) .. " — six sided dice layer cake</title>",
    "<style>" .. style() .. "</style></head><body><div id=\"wrap\">",
    nav, "<main>", body, "</main></div></body></html>",
  }, "\n")
end
-- }}}

-- {{{ function M.run()
function M.run(dir, opts)
  dir = dir or DIR
  opts = opts or {}
  local L = ledger.load(dir)
  local pages = collect(dir)
  local outdir = dir .. "/docs/HTML"
  os.execute("mkdir -p " .. outdir)

  -- read and render every page, collecting the links each makes
  for _, p in ipairs(pages) do
    local fh = io.open(p.path, "r")
    if fh then
      p.text = fh:read("*a"); fh:close()
      p.title = p.text:match("^#%s+([^\n]+)") or p.slug
      p.body = markdown(p.text, L, p)
    end
  end

  -- the direction nobody can see from inside a file
  for _, p in ipairs(pages) do
    for num in pairs(p.links) do
      local t = INDEX[num]
      if t and t ~= p then t.backlinks[p.slug] = true end
    end
  end

  local written = 0
  local nav_cache = {}
  for _, p in ipairs(pages) do
    if p.body then
      local back = {}
      for s in pairs(p.backlinks) do back[#back + 1] = s end
      table.sort(back)
      local tail = {}
      if #back > 0 then
        tail[#tail + 1] = '<div class="pointers"><h2>what points at this</h2><p>'
        for _, s in ipairs(back) do
          tail[#tail + 1] = ('<a class="ref" href="%s.html">%s</a> '):format(s, esc(s))
        end
        tail[#tail + 1] = "</p></div>"
      end
      tail[#tail + 1] = '<p class="built">Built from the repository by <code>099</code>. '
        .. 'Nothing under docs/HTML/ is a source file; edit the original and build again.</p>'
      local html = page_html(p.title, navigation(pages, p.slug), p.body .. table.concat(tail, "\n"))
      local out = io.open(outdir .. "/" .. p.slug .. ".html", "w")
      out:write(html); out:close()
      written = written + 1
    end
  end

  -- the front page: counts taken during the build rather than transcribed
  local counts = { given = 0, measured = 0, derived = 0, target = 0 }
  for _, n in ipairs(L.order) do counts[L.decl[n].kind] = counts[L.decl[n].kind] + 1 end
  local kinds = {}
  for _, p in ipairs(pages) do kinds[p.kind] = (kinds[p.kind] or 0) + 1 end

  local card = function(n, label)
    return ('<div class="card"><b>%s</b><span>%s</span></div>'):format(n, label)
  end
  local front = table.concat({
    "<h1>six sided dice layer cake</h1>",
    "<p>A cube, sixty millimetres on a side, that holds a language model still and ",
    "pours tokens through it. Six processors on the faces looking inward, a block of ",
    "static memory in the middle they all reach into, coolant through the corners, and ",
    "one face spent on a bundle of sixteen million wires.</p>",
    '<div class="cards">',
    card(kinds.blueprint or 0, "blueprints"),
    card(#L.order, "symbols"),
    card(#L.constraints, "constraints"),
    card(counts.derived, "derived"),
    card(counts.given + counts.measured, "chosen or measured"),
    card(counts.target, "still targets"),
    card(#L.orphans, "orphan symbols"),
    card((kinds.done or 0) .. "/" .. ((kinds.done or 0) + (kinds.issue or 0)), "tickets closed"),
    "</div>",
    "<h2>where to start</h2>",
    "<ul>",
    "<li><a class=\"ref\" href=\"000-concept-overview.html\">000</a> — what it is, in five minutes.</li>",
    "<li>The five datapaths, <a class=\"ref\" href=\"003-datapath-a-token.html\">003</a> to ",
    "<a class=\"ref\" href=\"007-datapath-a-pane.html\">007</a> — one journey each. The fastest route in.</li>",
    "<li><a class=\"ref\" href=\"008-where-the-vision-fights-physics.html\">008</a> — the six ",
    "places the original idea was overruled, each with the number that overruled it.</li>",
    "<li><a class=\"ref\" href=\"012-master-dimensions.html\">012</a> — the eleven chosen ",
    "lengths everything else derives from.</li>",
    "<li><a class=\"ref\" href=\"009-open-questions.html\">009</a> — before doing anything.</li>",
    "</ul>",
    "<h2>how to read a page</h2>",
    "<p>Every number in a blueprint's symbols table carries its kind: ",
    '<span style="color:var(--given)">given</span> is a number somebody chose, ',
    '<span style="color:var(--derived)">derived</span> is computed from others, ',
    '<span style="color:var(--measured)">measured</span> is the world, and ',
    '<span style="color:var(--target)">target</span> is a placeholder for a derivation ',
    "nobody has written. The values shown are resolved from the ledger while this site ",
    "is being built, so they cannot disagree with the design.</p>",
    "<p>At the foot of every page is <em>what points at this</em> — the direction you ",
    "cannot see from inside a file.</p>",
    '<p class="built">Built from the repository by <code>099</code>. Nothing under ',
    "docs/HTML/ is a source file.</p>",
  }, "\n")
  local fh = io.open(outdir .. "/index.html", "w")
  fh:write(page_html("front page", navigation(pages, "index"), front)); fh:close()
  written = written + 1

  return { ledger = L, pages = pages, written = written, outdir = outdir }
end
-- }}}

-- {{{ function M.report()
function M.report(R, out)
  out = out or io.stdout
  local function say(fmt, ...)
    out:write(select("#", ...) > 0 and fmt:format(...) or fmt, "\n")
  end
  local broken = {}
  for _, p in ipairs(R.pages) do
    for num in pairs(p.links) do
      if not INDEX[num] then broken[#broken + 1] = p.slug .. " -> " .. num end
    end
  end
  say("")
  say("  site: %d pages written to %s", R.written, R.outdir)
  if #broken > 0 then
    say("")
    say("  REFERENCES THAT GO NOWHERE")
    for _, b in ipairs(broken) do say("    %s", b) end
    say("")
    return 1
  end
  say("")
  return 0
end
-- }}}

if arg and arg[0] and arg[0]:match("099%-the%-documentation%-site%.lua$") then
  os.exit(M.report(M.run(DIR)))
end

return M
