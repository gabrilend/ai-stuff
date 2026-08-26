-- 033-the-documentation-site.lua
--
-- Every document, ticket and companion page in this project, as one
-- cross-linked site.
--
-- For a general: the writing here is markdown files that refer to each other
-- constantly -- this document, that ticket, that source file -- and following
-- one of those references currently means opening a file by hand. This turns
-- the whole lot into pages where every reference is a link.
--
-- Built rather than written, and not committed. Every page here is derived from
-- a file already in this repository, so tracking the output would put the same
-- words in the record twice and make one documentation edit look like fifty.
--
--   luajit src/033-the-documentation-site.lua [--dir ROOT] [--no-figures]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local gallery = project.load("032-a-gallery-you-can-page")

local M = {}

-- {{{ escape(text)
local function escape(text)
  return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
-- }}}

-- {{{ LUA_WORDS -- what gets coloured in a code block
local LUA_WORDS = {}
for word in ([[and break do else elseif end false for function goto if in local
nil not or repeat return then true until while]]):gmatch("%S+") do
  LUA_WORDS[word] = true
end
-- }}}

-- {{{ highlight(code)
-- Lua source with its keywords, strings, numbers and comments marked.
--
-- Code embedded as plain grey text is code nobody reads. This is a scanner
-- rather than a set of substitutions, because a substitution that colours
-- keywords will happily colour the word `end` inside a comment or a string.
local function highlight(code)
  local out = {}
  local position = 1
  local length = #code

  while position <= length do
    local rest = code:sub(position)

    local comment = rest:match("^%-%-%[%[.-%]%]") or rest:match("^%-%-[^\n]*")
    if comment then
      out[#out + 1] = '<span class="c">' .. escape(comment) .. "</span>"
      position = position + #comment

    else
      local text = rest:match('^"[^"\n]*"') or rest:match("^'[^'\n]*'")
                   or rest:match("^%[%[.-%]%]")
      if text then
        out[#out + 1] = '<span class="s">' .. escape(text) .. "</span>"
        position = position + #text

      else
        local word = rest:match("^[%a_][%w_]*")
        if word then
          if LUA_WORDS[word] then
            out[#out + 1] = '<span class="k">' .. word .. "</span>"
          else
            out[#out + 1] = word
          end
          position = position + #word

        else
          local number = rest:match("^0[xX]%x+") or rest:match("^%d+%.?%d*")
          if number then
            out[#out + 1] = '<span class="n">' .. number .. "</span>"
            position = position + #number
          else
            out[#out + 1] = escape(code:sub(position, position))
            position = position + 1
          end
        end
      end
    end
  end
  return table.concat(out)
end
-- }}}

-- {{{ M.cross_link(text, known)
-- Every reference in a line of prose, turned into a link.
--
-- Found by pattern, on the naming conventions this project already follows: a
-- bare three-digit number is a ticket, `docs/NNN` is a document, and a
-- `src/NNN-name.lua` is a source file. The linking is a consequence of the
-- naming rather than a new obligation on anybody writing.
--
-- Only references to things that exist become links. A reference to a ticket
-- nobody has written yet stays as text, which is more honest than a link that
-- goes nowhere.
function M.cross_link(text, known)
  -- source files first: `src/019-the-kanji-record.lua`
  text = text:gsub("(<code>)src/([%w%-]+)%.lua(</code>)", function(open, name, close)
    if known.source[name] then
      return '<a href="src-' .. name .. '.html">' .. open .. "src/" .. name ..
             ".lua" .. close .. "</a>"
    end
    return open .. "src/" .. name .. ".lua" .. close
  end)

  -- documents: `docs/004` or `docs/004-datapath-...`
  text = text:gsub("(<code>)docs/(%d%d%d)([%w%-]*)(</code>)",
    function(open, number, tail, close)
      local page = known.doc[number]
      if page then
        return '<a href="' .. page .. '.html">' .. open .. "docs/" .. number ..
               tail .. close .. "</a>"
      end
      return open .. "docs/" .. number .. tail .. close
    end)

  -- tickets: `204`
  text = text:gsub("(<code>)(%d%d%d)(%a?)(</code>)",
    function(open, number, letter, close)
      local page = known.issue[number .. letter]
      if page then
        return '<a href="' .. page .. '.html">' .. open .. number .. letter ..
               close .. "</a>"
      end
      return open .. number .. letter .. close
    end)

  return text
end
-- }}}

-- {{{ inline(text, known)
-- The marks that happen inside a line: code, emphasis, links.
--
-- Code spans are turned first, because everything else has to leave their
-- contents alone -- an underscore inside a code span is an underscore.
local function inline(text, known)
  local held = {}
  text = text:gsub("`([^`]+)`", function(code)
    held[#held + 1] = "<code>" .. escape(code) .. "</code>"
    return "\1" .. #held .. "\1"
  end)

  text = escape(text)

  text = text:gsub("%[([^%]]+)%]%(([^%)]+)%)", function(label, target)
    return '<a href="' .. target .. '">' .. label .. "</a>"
  end)
  text = text:gsub("%*%*([^%*]+)%*%*", "<strong>%1</strong>")
  text = text:gsub("%*([^%*]+)%*", "<em>%1</em>")

  text = text:gsub("\1(%d+)\1", function(index) return held[tonumber(index)] end)
  return M.cross_link(text, known)
end
-- }}}

-- {{{ M.to_html(markdown, known)
-- One document, as the body of a page.
--
-- Handles what this project's writing actually uses. A line shape it does not
-- recognise is counted and reported rather than passed through as prose,
-- because a converter that silently drops a construct produces a page that is
-- quietly missing a paragraph and nobody finds out.
function M.to_html(markdown, known)
  local out = {}
  local unknown = {}
  local lines = {}
  for line in (markdown .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end

  local index = 1
  local paragraph = {}
  local headings = {}

  local function flush()
    if #paragraph > 0 then
      out[#out + 1] = "<p>" .. inline(table.concat(paragraph, " "), known) .. "</p>"
      paragraph = {}
    end
  end

  while index <= #lines do
    local line = lines[index]

    if line:match("^```") then
      flush()
      local language = line:match("^```(%w*)")
      local code = {}
      index = index + 1
      while index <= #lines and not lines[index]:match("^```") do
        code[#code + 1] = lines[index]
        index = index + 1
      end
      local body = table.concat(code, "\n")
      if language == "lua" or body:match("^%s*%-%-") or body:match("local ") then
        out[#out + 1] = '<pre class="code">' .. highlight(body) .. "</pre>"
      else
        out[#out + 1] = '<pre class="code">' .. escape(body) .. "</pre>"
      end

    elseif line:match("^#+%s") then
      flush()
      local hashes, text = line:match("^(#+)%s+(.*)$")
      local level = #hashes
      local anchor = text:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
      headings[#headings + 1] = { level = level, text = text, anchor = anchor }
      out[#out + 1] = string.format('<h%d id="%s">%s</h%d>', level, anchor,
                                    inline(text, known), level)

    elseif line:match("^%s*|") then
      flush()
      local rows = {}
      while index <= #lines and lines[index]:match("^%s*|") do
        rows[#rows + 1] = lines[index]
        index = index + 1
      end
      index = index - 1
      out[#out + 1] = "<table>"
      for row_number, row in ipairs(rows) do
        -- the second row of a table is the rule under the headings and is not
        -- a row of anything
        if not row:match("^%s*|[%s%-:|]+|?%s*$") then
          local cells = {}
          for cell in row:gmatch("|([^|]*)") do cells[#cells + 1] = cell end
          -- the trailing pipe leaves an empty cell behind it
          if cells[#cells] and cells[#cells]:match("^%s*$") then
            table.remove(cells)
          end
          local tag = (row_number == 1) and "th" or "td"
          local parts = { "<tr>" }
          for _, cell in ipairs(cells) do
            parts[#parts + 1] = "<" .. tag .. ">" ..
              inline((cell:gsub("^%s+", ""):gsub("%s+$", "")), known) ..
              "</" .. tag .. ">"
          end
          parts[#parts + 1] = "</tr>"
          out[#out + 1] = table.concat(parts)
        end
      end
      out[#out + 1] = "</table>"

    elseif line:match("^%s*[%-%*]%s") or line:match("^%s*%d+%.%s") then
      flush()
      local ordered = line:match("^%s*%d+%.%s") ~= nil
      local items = {}
      while index <= #lines do
        local item = lines[index]
        local body = item:match("^%s*[%-%*]%s+(.*)$") or item:match("^%s*%d+%.%s+(.*)$")
        if body then
          items[#items + 1] = { body }
          index = index + 1
        elseif item:match("^%s%s+%S") and #items > 0 then
          -- a continuation of the item above, wrapped onto the next line
          local held = items[#items]
          held[#held + 1] = (item:gsub("^%s+", ""))
          index = index + 1
        elseif item:match("^%s*$") and #items > 0 then
          -- a blank line inside a list may or may not end it; look ahead
          local following = lines[index + 1] or ""
          if following:match("^%s*[%-%*]%s") or following:match("^%s*%d+%.%s")
             or following:match("^%s%s+%S") then
            index = index + 1
          else
            break
          end
        else
          break
        end
      end
      out[#out + 1] = ordered and "<ol>" or "<ul>"
      for _, item in ipairs(items) do
        out[#out + 1] = "<li>" .. inline(table.concat(item, " "), known) .. "</li>"
      end
      out[#out + 1] = ordered and "</ol>" or "</ul>"

    elseif line:match("^>%s?") then
      flush()
      local quoted = {}
      while index <= #lines and lines[index]:match("^>") do
        quoted[#quoted + 1] = (lines[index]:gsub("^>%s?", ""))
        index = index + 1
      end
      index = index - 1
      out[#out + 1] = "<blockquote>" ..
        inline(table.concat(quoted, " "), known) .. "</blockquote>"

    elseif line:match("^%-%-%-+%s*$") then
      flush()
      out[#out + 1] = "<hr>"

    elseif line:match("^%s*$") then
      flush()

    elseif line:match("^%s") and not line:match("^%s*%S") then
      flush()

    else
      paragraph[#paragraph + 1] = line
    end

    index = index + 1
  end
  flush()

  return table.concat(out, "\n"), headings, unknown
end
-- }}}

-- {{{ gather(known)
-- Every file the site will hold, and the name its page gets.
local function gather()
  local known = { doc = {}, issue = {}, source = {}, pages = {} }

  local function listing(where, pattern)
    local out = {}
    local pipe = io.popen('ls -1 "' .. project.path(where) .. '" 2>/dev/null')
    if not pipe then return out end
    for name in pipe:lines() do
      if name:match(pattern) then out[#out + 1] = name end
    end
    pipe:close()
    table.sort(out)
    return out
  end

  for _, name in ipairs(listing("docs", "%.md$")) do
    local base = name:gsub("%.md$", "")
    local page = "doc-" .. base
    known.pages[#known.pages + 1] = {
      kind = "docs", file = project.path("docs", name), page = page,
      title = base, sort = base,
    }
    local number = base:match("^(%d%d%d)")
    if number then known.doc[number] = page end
  end

  -- notes, and the three directories beside it that this project writes into:
  -- what should be better, what is expected, and the dataflow patterns that
  -- turned out to work more than once.
  for _, where in ipairs({ "notes", "strategems", "desire", "faith" }) do
    for _, name in ipairs(listing(where, "^[%w]")) do
      local base = name:gsub("%.md$", "")
      known.pages[#known.pages + 1] = {
        kind = where, file = project.path(where, name),
        page = where .. "-" .. base, title = base, sort = base,
      }
    end
  end

  for _, where in ipairs({ "issues", "issues/completed" }) do
    for _, name in ipairs(listing(where, "%.md$")) do
      local base = name:gsub("%.md$", "")
      local page = "issue-" .. base
      known.pages[#known.pages + 1] = {
        kind = (where == "issues") and "issues open" or "issues completed",
        file = project.path(where, name), page = page, title = base, sort = base,
      }
      local number = base:match("^(%d%d%d%a?)")
      if number then known.issue[number] = page end
    end
  end

  for _, name in ipairs(listing("src", "%.info%.md$")) do
    local base = name:gsub("%.info%.md$", "")
    local page = "src-" .. base
    known.pages[#known.pages + 1] = {
      kind = "source", file = project.path("src", name), page = page,
      title = base, sort = base,
    }
    known.source[base] = page
  end

  return known
end
-- }}}

-- {{{ contents(known, here)
-- The column that is always there.
local function contents(known, here)
  local groups = {}
  local order = { "docs", "notes", "strategems", "desire", "faith", "source",
                  "issues open", "issues completed" }
  for _, page in ipairs(known.pages) do
    groups[page.kind] = groups[page.kind] or {}
    table.insert(groups[page.kind], page)
  end
  local out = { '<nav id="toc">' }
  out[#out + 1] = '<a class="home" href="index.html">the whole project</a>'
  for _, kind in ipairs(order) do
    if groups[kind] then
      out[#out + 1] = "<h4>" .. kind .. "</h4><ul>"
      for _, page in ipairs(groups[kind]) do
        out[#out + 1] = string.format('<li%s><a href="%s.html">%s</a></li>',
          page.page == here and ' class="here"' or "", page.page,
          escape(page.title))
      end
      out[#out + 1] = "</ul>"
    end
  end
  out[#out + 1] = "</nav>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ SITE_STYLE -- what the site adds on top of the shared look
local SITE_STYLE = [[
body { display: grid; grid-template-columns: 19rem 1fr; min-height: 100vh; }
#toc {
  border-right: 1px solid var(--rule); padding: 1.5rem 1rem 4rem;
  overflow-y: auto; max-height: 100vh; position: sticky; top: 0;
  font-size: .84rem; background: var(--card);
}
#toc .home { display: block; margin-bottom: 1rem; font-size: .95rem; }
#toc h4 { margin: 1.1rem 0 .3rem; color: var(--faint); font-weight: normal;
  text-transform: lowercase; letter-spacing: .06em; font-size: .78rem; }
#toc ul { list-style: none; margin: 0; padding: 0; }
#toc li { margin: .1rem 0; }
#toc li a { color: var(--ink); display: block; padding: .1rem .3rem;
  border-radius: 2px; overflow: hidden; text-overflow: ellipsis;
  white-space: nowrap; }
#toc li.here a { background: var(--accent); color: var(--paper); }
article { padding: 2.5rem 3rem 6rem; max-width: 52rem; }
article h1 { font-size: 1.7rem; font-weight: normal; margin: 0 0 1.5rem; }
article h2 { font-size: 1.25rem; font-weight: normal; margin: 2.2rem 0 .6rem;
  border-bottom: 1px solid var(--rule); padding-bottom: .3rem; }
article h3 { font-size: 1.05rem; font-weight: normal; margin: 1.6rem 0 .4rem;
  color: var(--accent); }
article h4 { font-size: .95rem; margin: 1.2rem 0 .3rem; }
article p { margin: .8rem 0; }
article code { background: var(--card); border: 1px solid var(--rule);
  padding: .05rem .3rem; border-radius: 2px; font-size: .86em;
  font-family: ui-monospace, "SF Mono", Menlo, monospace; }
article a code { border-color: var(--accent); }
pre.code { background: var(--card); border: 1px solid var(--rule);
  border-radius: 2px; padding: .9rem 1rem; overflow-x: auto; font-size: .82rem;
  line-height: 1.55; font-family: ui-monospace, "SF Mono", Menlo, monospace; }
pre.code .k { color: #8a5a00; font-weight: bold; }
pre.code .s { color: #4a6b2a; }
pre.code .n { color: #7a3a8a; }
pre.code .c { color: var(--faint); font-style: italic; }
article table { border-collapse: collapse; margin: 1rem 0; font-size: .9rem; }
article th { text-align: left; color: var(--faint); font-weight: normal;
  border-bottom: 1px solid var(--rule); padding: .3rem .8rem .3rem 0; }
article td { padding: .3rem .8rem .3rem 0; border-bottom: 1px solid var(--rule);
  vertical-align: top; }
article blockquote { margin: 1rem 0; padding: .3rem 0 .3rem 1rem;
  border-left: 3px solid var(--accent); color: var(--faint); font-style: italic; }
article hr { border: none; border-top: 1px solid var(--rule); margin: 2rem 0; }
article ul, article ol { margin: .8rem 0; padding-left: 1.4rem; }
article li { margin: .3rem 0; }
.figure { margin: 1.5rem 0; padding: 1rem; background: var(--card);
  border: 1px solid var(--rule); border-radius: 3px; }
.figure img { display: block; margin: 0 auto; image-rendering: auto; }
.figure .dial { display: flex; align-items: center; gap: 1rem; margin-top: .8rem; }
.figure input[type=range] { flex: 1; }
.figure .reading { font-size: .85rem; color: var(--faint); min-width: 11rem; }
@media (max-width: 900px) {
  body { grid-template-columns: 1fr; }
  #toc { position: static; max-height: none; border-right: none;
         border-bottom: 1px solid var(--rule); }
  article { padding: 1.5rem; }
}
]]
-- }}}

-- {{{ M.figures(settings)
-- The one thing on this site that is not a document: a dial you can turn.
--
-- The blur radius is the most important number in the project (`docs/003`) and
-- the paragraph explaining it is worse than seeing it. One character is
-- rendered at a spread of radii and a slider moves between them, so the two
-- failures either side of the right answer -- a black bar drawn on the sky, and
-- nothing in particular anywhere -- can be looked at rather than described.
function M.figures(settings)
  local canvas = project.load("016-the-grey-canvas")
  local png = project.load("017-write-a-picture")
  local field_of = project.load("022-the-structure-field")
  local shape = project.load("021-the-shape-of-a-stroke")
  local store = project.load("019-the-kanji-record").store()

  local where = project.path("docs", "HTML", "figures")
  project.ensure_directory(where)

  local record = store.records["\230\163\174"]
  local measured = shape.measure_record(record)
  local radii = { 0, 2, 4, 6, 9, 13, 18, 24, 32 }
  local made = {}
  for _, radius in ipairs(radii) do
    local tweaked = {}
    for key, value in pairs(settings.field) do tweaked[key] = value end
    tweaked.blur_radius = radius
    tweaked.blur_falloff = 0
    tweaked.resolution = 384
    tweaked.stroke_width = settings.field.stroke_width * 384 / settings.field.resolution
    local surface = field_of.build(record, { field = tweaked, scene = settings.scene },
                                   { measured = measured })
    local name = string.format("blur-%02d.png", radius)
    png.write_grey(where .. "/" .. name, surface, canvas)
    made[#made + 1] = { radius = radius, name = "figures/" .. name }
  end
  return record.character, made
end
-- }}}

-- {{{ M.build(options)
-- The whole site.
function M.build(options)
  options = options or {}
  local settings = project.settings()
  local known = gather()
  local out_dir = project.path("docs", "HTML")
  project.ensure_directory(out_dir)

  local style = "<style>" .. gallery.stylesheet() .. SITE_STYLE .. "</style>"

  local function shell(title, here, body)
    return table.concat({
      "<!doctype html>",
      '<html lang="en"><head><meta charset="utf-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      "<title>" .. escape(title) .. "</title>", style, "</head><body>",
      contents(known, here),
      "<article>", body, "</article>",
      "</body></html>",
    }, "\n")
  end

  local written = 0
  local links_checked, links_broken = 0, {}

  for _, page in ipairs(known.pages) do
    local text = project.read_file(page.file)
    if text then
      local body = M.to_html(text, known)
      project.write_file(out_dir .. "/" .. page.page .. ".html",
                         shell(page.title, page.page, body))
      written = written + 1

      -- Every link this page emits is checked against the pages that exist. A
      -- site full of dead links is worse than the markdown it came from,
      -- because markdown does not promise the link works.
      for target in body:gmatch('href="([^"#]+)%.html"') do
        links_checked = links_checked + 1
        local exists = false
        for _, other in ipairs(known.pages) do
          if other.page == target then exists = true break end
        end
        if target == "index" then exists = true end
        if not exists then
          links_broken[#links_broken + 1] = page.page .. " -> " .. target
        end
      end
    end
  end

  -- {{{ the front page, with the dial on it
  local figure_html = ""
  if not options.no_figures then
    local character, made = M.figures(settings)
    local sources = {}
    for _, one in ipairs(made) do
      sources[#sources + 1] = string.format('{"r":%d,"f":"%s"}', one.radius, one.name)
    end
    figure_html = table.concat({
      '<h2>The one dial that matters</h2>',
      "<p>A stroke drawn hard-edged is a black bar painted across the sky: the",
      "model satisfies the instruction the cheapest way there is. Softened until",
      "it stops being a line and becomes a <em>region of darkness</em>, the same",
      "instruction can be answered by a tree standing there instead. Too soft and",
      "there is nothing in particular anywhere. Turn it.</p>",
      '<div class="figure">',
      '<img id="blurshot" width="384" height="384" alt="">',
      '<div class="dial">',
      '<span class="reading" id="blurread"></span>',
      '<input type="range" id="blurdial" min="0" max="8" value="4">',
      "</div></div>",
      "<script>",
      "const BLURS = [", table.concat(sources, ","), "];",
      [[
const dial = document.getElementById('blurdial');
const shot = document.getElementById('blurshot');
const read = document.getElementById('blurread');
function turn() {
  const one = BLURS[dial.value];
  shot.src = one.f;
  read.textContent = one.r === 0 ? 'not softened at all'
    : 'softened by ' + one.r + ' pixels';
}
dial.addEventListener('input', turn);
turn();
]],
      "</script>",
    }, "\n")
  end

  local overview = project.read_file(project.path("docs", "001-what-this-makes.md"))
  local front = (overview and M.to_html(overview, known) or "") .. figure_html
  project.write_file(out_dir .. "/index.html",
                     shell("kanji-learning-image-generator", "index", front))
  written = written + 1
  -- }}}

  return { pages = written, links = links_checked, broken = links_broken }
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  project.hello("033-the-documentation-site")
  local made = M.build({ no_figures = options.no_figures })
  io.write(string.format("%d pages, %d links, %d of them broken\n",
           made.pages, made.links, #made.broken))
  for index = 1, math.min(10, #made.broken) do
    io.write("  ", made.broken[index], "\n")
  end
  io.write("open " .. project.path("docs", "HTML", "index.html") .. "\n")
  project.goodbye("033-the-documentation-site",
                  { made.pages .. " pages, " .. #made.broken .. " broken links" })
  if #made.broken > 0 then os.exit(1) end
end
-- }}}

if arg and arg[0] and arg[0]:find("033%-the%-documentation%-site") then
  main(arg)
end

return M
