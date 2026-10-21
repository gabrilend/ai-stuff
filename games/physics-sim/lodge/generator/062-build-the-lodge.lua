#!/usr/bin/env luajit
-- 062-build-the-lodge.lua
--
-- Turns the hand-written rooms in lodge/pages/ into the pages a browser
-- opens, in docs/HTML/lodge/.
--
-- For a general: the lodge is the project's front door -- a few connected
-- rooms, each written by hand in Markdown with its own stylesheet beside it.
-- This program is the carpenter, not the author. It reads every room, checks
-- that every door (link) opens onto something real, hangs the pictures,
-- puts the same list of rooms down the side of each page, and writes the
-- pages out. Where one room points at a particular corner of another, the
-- corner it points at gets a small "pointed at from" note at its end, with a
-- way back.
--
-- WHAT IT WILL NOT DO. It never forgives a broken door: a link to a file,
-- room, section or issue that is not there stops the build, after listing
-- every one. It never guesses at a line it does not understand: Markdown
-- outside the small set the rooms use stops the build with the room and the
-- line. It never creates a directory (lodge/build does that), and it never
-- writes anywhere but the output folder, the log and the goodbye.
--
-- Used two ways. As a command, by lodge/build:
--   luajit 062-build-the-lodge.lua [DIR]
-- and as a module, by the tests:
--   local lodge = dofile(".../062-build-the-lodge.lua")
--   local ok, report = pcall(lodge.build, { root = "...", ... })

local M = {}

-- {{{ DIR -- the project root, hard-coded, overridable by the first argument
local DIR = "/mnt/mtwo/programming/ai-stuff/games/physics-sim"
-- }}}

-- {{{ local function read_file()
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then
    return nil
  end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ local function write_file()
-- A page that cannot be written ends the build: a site with a hole in it and
-- an exit code saying all was well is worse than no site.
local function write_file(path, text)
  local handle, why = io.open(path, "wb")
  if not handle then
    error("cannot write " .. path .. ": " .. tostring(why), 0)
  end
  handle:write(text)
  handle:close()
end
-- }}}

-- {{{ local function exists()
local function exists(path)
  local handle = io.open(path, "rb")
  if handle then
    handle:close()
    return true
  end
  return false
end
-- }}}

-- {{{ local function listing()
-- The names in one directory matching a shell pattern, sorted so two builds
-- over the same rooms write the same pages. `ls` is a read of the directory
-- and nothing else.
local function listing(dir, pattern)
  local names = {}
  local pipe = io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
  for line in pipe:lines() do
    if line:match(pattern) then
      names[#names + 1] = line
    end
  end
  pipe:close()
  table.sort(names)
  return names
end
-- }}}

-- {{{ local function escape()
local function escape(text)
  return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
-- }}}

-- {{{ local function slug()
-- A heading's anchor: lower case, letters and digits kept, every run of
-- anything else one hyphen. Bytes above 127 (an em-dash, an accented letter)
-- are dropped whole rather than matched in a character class, which would
-- split a multi-byte letter and corrupt the page.
local function slug(text)
  local kept = {}
  local last_was_gap = true
  for index = 1, #text do
    local byte = text:byte(index)
    local char = text:sub(index, index)
    if char:match("%w") and byte < 128 then
      kept[#kept + 1] = char:lower()
      last_was_gap = false
    elseif byte < 128 and not last_was_gap then
      kept[#kept + 1] = "-"
      last_was_gap = true
    end
  end
  local result = table.concat(kept):gsub("%-+$", "")
  return result
end
-- }}}

-- {{{ local function normalise()
-- Collapses "a/b/../c" to "a/c" so two spellings of one path compare equal.
local function normalise(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #parts > 0 and parts[#parts] ~= ".." then
        parts[#parts] = nil
      else
        parts[#parts + 1] = ".."
      end
    elseif part ~= "." then
      parts[#parts + 1] = part
    end
  end
  local joined = table.concat(parts, "/")
  if path:sub(1, 1) == "/" then
    return "/" .. joined
  end
  return joined
end
-- }}}

-- {{{ local function relative()
-- The path that reaches `target` from inside the folder `from_dir`, both
-- absolute: climb up to the shared beginning, then down.
local function relative(from_dir, target)
  local from_parts, target_parts = {}, {}
  for part in normalise(from_dir):gmatch("[^/]+") do
    from_parts[#from_parts + 1] = part
  end
  for part in normalise(target):gmatch("[^/]+") do
    target_parts[#target_parts + 1] = part
  end
  local shared = 0
  while shared < #from_parts and shared < #target_parts
        and from_parts[shared + 1] == target_parts[shared + 1] do
    shared = shared + 1
  end
  local pieces = {}
  for _ = shared + 1, #from_parts do
    pieces[#pieces + 1] = ".."
  end
  for index = shared + 1, #target_parts do
    pieces[#pieces + 1] = target_parts[index]
  end
  return table.concat(pieces, "/")
end
-- }}}

-- {{{ BLOCK_SHAPES -- the line shapes a room may use, tried in this order
-- Each entry answers "does this line start a block of my kind?". A line that
-- starts none of them and is not plain prose is refused (see is_prose).
local BLOCK_SHAPES = {
  { kind = "fence",   test = function(line) return line:match("^```") end },
  { kind = "heading", test = function(line) return line:match("^#%s") or line:match("^##%s") or line:match("^###%s") end },
  { kind = "rule",    test = function(line) return line:match("^%-%-%-+%s*$") end },
  { kind = "figure",  test = function(line) return line:match("^!%[[^%]]*%]%([^%)]+%)%s*$") end },
  { kind = "quote",   test = function(line) return line:match("^>") end },
  { kind = "table",   test = function(line) return line:match("^|") end },
  { kind = "bullets", test = function(line) return line:match("^[%-%*]%s") end },
  { kind = "numbers", test = function(line) return line:match("^%d+%.%s") end },
}
-- }}}

-- {{{ local function shape_of()
local function shape_of(line)
  for _, shape in ipairs(BLOCK_SHAPES) do
    if shape.test(line) then
      return shape.kind
    end
  end
  return nil
end
-- }}}

-- {{{ local function is_prose()
-- Plain prose starts with something a reader would start a sentence with.
-- What is refused, and why each one: a fourth-level heading (the rooms stop
-- at three), raw HTML (a room is Markdown, its look lives in its stylesheet),
-- an indented line outside a list (indented code is not in the subset, and an
-- accidental indent would silently become a paragraph), a tab, and "+" lists.
local function is_prose(line)
  if line:match("^####") then return false end
  if line:match("^<") then return false end
  if line:match("^%s") then return false end
  if line:match("^%+%s") then return false end
  return true
end
-- }}}

-- {{{ local function parse_room()
-- One room's Markdown, as a list of blocks. Each block is a table:
--   kind     "heading" | "paragraph" | "fence" | "rule" | "figure" | "quote"
--            | "table" | "bullets" | "numbers"
--   line     the line it starts on, for messages
--   level    headings: 1, 2 or 3
--   text     headings and paragraphs: the raw text
--   language fences: the word after ```
--   lines    fences: the raw lines; quotes: list of paragraph texts
--   items    lists: list of item texts
--   rows     tables: list of lists of cell texts, the first being the header
--   caption, path   figures
-- Fails with every refused line in the room, not only the first.
local function parse_room(name, text)
  local blocks, refused = {}, {}
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end

  local index = 1
  while index <= #lines do
    local line = lines[index]
    local kind = shape_of(line)

    if line:match("^%s*$") then
      -- a blank line separates blocks and is otherwise nothing
      index = index + 1

    elseif kind == "fence" then
      local block = { kind = "fence", line = index, language = line:match("^```%s*(%S*)"), lines = {} }
      index = index + 1
      while index <= #lines and not lines[index]:match("^```") do
        block.lines[#block.lines + 1] = lines[index]
        index = index + 1
      end
      if index > #lines then
        refused[#refused + 1] = name .. ":" .. block.line .. ": a fence that never closes"
      end
      blocks[#blocks + 1] = block
      index = index + 1

    elseif kind == "heading" then
      local hashes, words = line:match("^(#+)%s+(.-)%s*$")
      blocks[#blocks + 1] = { kind = "heading", line = index, level = #hashes, text = words }
      index = index + 1

    elseif kind == "rule" then
      blocks[#blocks + 1] = { kind = "rule", line = index }
      index = index + 1

    elseif kind == "figure" then
      local caption, path = line:match("^!%[([^%]]*)%]%(([^%)]+)%)")
      blocks[#blocks + 1] = { kind = "figure", line = index, caption = caption, path = path }
      index = index + 1

    elseif kind == "quote" then
      -- the lines are kept apart until here: an empty "> " line is a
      -- paragraph break inside the quote, not the end of it
      local block = { kind = "quote", line = index, lines = {} }
      local current = {}
      while index <= #lines and lines[index]:match("^>") do
        local inner = lines[index]:gsub("^>%s?", "")
        if inner:match("^%s*$") then
          if #current > 0 then
            block.lines[#block.lines + 1] = table.concat(current, " ")
            current = {}
          end
        else
          current[#current + 1] = inner
        end
        index = index + 1
      end
      if #current > 0 then
        block.lines[#block.lines + 1] = table.concat(current, " ")
      end
      blocks[#blocks + 1] = block

    elseif kind == "table" then
      local block = { kind = "table", line = index, rows = {} }
      local row_number = 0
      while index <= #lines and lines[index]:match("^|") do
        row_number = row_number + 1
        -- the second row is the rule under the headings, not a row of data
        if row_number ~= 2 then
          local cells = {}
          local body = lines[index]:gsub("^|", ""):gsub("|%s*$", "")
          for cell in (body .. "|"):gmatch("(.-)|") do
            cells[#cells + 1] = cell:match("^%s*(.-)%s*$")
          end
          block.rows[#block.rows + 1] = cells
        elseif not lines[index]:match("^|[%s:%-|]+$") then
          refused[#refused + 1] = name .. ":" .. index .. ": a table's second row must be its rule (|---|---|)"
        end
        index = index + 1
      end
      blocks[#blocks + 1] = block

    elseif kind == "bullets" or kind == "numbers" then
      -- an item runs on through lines indented under it; a new marker of the
      -- same kind starts the next item; anything else ends the list
      local block = { kind = kind, line = index, items = {} }
      local marker = (kind == "bullets") and "^[%-%*]%s+" or "^%d+%.%s+"
      while index <= #lines do
        local here = lines[index]
        if here:match(marker) then
          block.items[#block.items + 1] = here:gsub(marker, "")
        elseif here:match("^%s%s+%S") and #block.items > 0 then
          block.items[#block.items] = block.items[#block.items] .. " " .. here:match("^%s*(.-)$")
        else
          break
        end
        index = index + 1
      end
      blocks[#blocks + 1] = block

    elseif is_prose(line) then
      -- a paragraph runs until a blank line or the start of another block
      local words = { line }
      index = index + 1
      while index <= #lines and not lines[index]:match("^%s*$") and not shape_of(lines[index]) do
        if not is_prose(lines[index]) then
          break
        end
        words[#words + 1] = lines[index]
        index = index + 1
      end
      blocks[#blocks + 1] = { kind = "paragraph", line = index - #words, text = table.concat(words, " ") }

    else
      refused[#refused + 1] = name .. ":" .. index .. ": a line shape the lodge does not build: " .. line:sub(1, 60)
      index = index + 1
    end
  end

  return blocks, refused
end
-- }}}

-- {{{ local function find_issue()
-- The issue file a number names, open or completed: "606" finds
-- issues/completed/606-ball-health-damage-system.md, "114a" finds the
-- sub-issue. Answers the absolute path, or nil.
local function find_issue(root, number)
  for _, folder in ipairs({ root .. "/issues", root .. "/issues/completed" }) do
    local found = listing(folder, "^" .. number .. "%-.*%.md$")
    if #found > 0 then
      return folder .. "/" .. found[1]
    end
  end
  return nil
end
-- }}}

-- {{{ local function inline()
-- The marks inside one line of prose, and every link in it.
--
-- Order is the whole trick. Code spans are lifted out first and put back
-- last, so nothing inside them is linked or emphasised. Links are lifted out
-- next, so their text and target are never touched by later rules. Only then
-- is the remaining text escaped and given bold, emphasis and issue links.
-- Lifted pieces wait as \1N\2 markers, which escaping leaves alone.
--
-- `resolve(target)` answers href, or nil plus a reason; the reason is
-- collected into `dead` and the build fails at the end.
local function inline(text, resolve, dead, where, issue_href)
  local held = {}
  local function hold(html)
    held[#held + 1] = html
    return "\1" .. #held .. "\2"
  end

  text = text:gsub("`([^`]+)`", function(code)
    return hold("<code>" .. escape(code) .. "</code>")
  end)

  text = text:gsub("%[([^%]]+)%]%(([^%)%s]+)%)", function(label, target)
    local href, why = resolve(target)
    if not href then
      dead[#dead + 1] = where .. ": " .. why
      return hold(escape(label))
    end
    return hold('<a href="' .. escape(href) .. '">' .. escape(label) .. "</a>")
  end)

  text = escape(text)
  text = text:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
  text = text:gsub("%*([^%*%s][^%*]-)%*", "<em>%1</em>")

  -- "issue 606", "issues 901, 902 and 903", "issues 221a through 221e":
  -- after the word, every number in the run is linked, the run continuing
  -- through commas and the words and, or, through, to
  local function link_number(number)
    local href = issue_href(number)
    if not href then
      dead[#dead + 1] = where .. ": issue " .. number .. " has no file in issues/ or issues/completed/"
      return number
    end
    return '<a class="issue" href="' .. escape(href) .. '">' .. number .. "</a>"
  end
  local pieces, position = {}, 1
  while true do
    local start, finish = text:find("%f[%a][Ii]ssues?%s+", position)
    if not start then
      break
    end
    pieces[#pieces + 1] = text:sub(position, finish)
    position = finish + 1
    while true do
      local number = text:match("^(%d%d%d%d?%l?)%f[^%w]", position)
      if not number then
        break
      end
      pieces[#pieces + 1] = link_number(number)
      position = position + #number
      local joint = text:match("^,?%s+and%s+", position) or text:match("^,?%s+or%s+", position)
        or text:match("^%s+through%s+", position) or text:match("^%s+to%s+", position)
        or text:match("^,%s*", position)
      if not joint or not text:match("^%d%d%d", position + #joint) then
        break
      end
      pieces[#pieces + 1] = joint
      position = position + #joint
    end
  end
  pieces[#pieces + 1] = text:sub(position)
  text = table.concat(pieces)

  text = text:gsub("\1(%d+)\2", function(n)
    return held[tonumber(n)]
  end)
  return text
end
-- }}}

-- {{{ local function collect_rooms()
-- Every room in the pages folder, in index order. A room is a pair:
--   NNN-name.md   the words, written by hand
--   NNN-name.css  that room's own stylesheet
-- A room without its stylesheet stops the build: every room carries its own
-- look, even when two rooms look alike.
local function collect_rooms(pages_dir)
  local rooms, problems = {}, {}
  for _, file in ipairs(listing(pages_dir, "^%d%d%d%-.+%.md$")) do
    local stem = file:gsub("%.md$", "")
    local room = {
      stem = stem,
      source = pages_dir .. "/" .. file,
      style = pages_dir .. "/" .. stem .. ".css",
      page = stem .. ".html",
    }
    room.text = read_file(room.source)
    if not exists(room.style) then
      problems[#problems + 1] = file .. ": no stylesheet " .. stem .. ".css beside it"
    end
    room.title = room.text:match("^#%s+([^\n]+)") or room.text:match("\n#%s+([^\n]+)") or stem
    rooms[#rooms + 1] = room
  end
  return rooms, problems
end
-- }}}

-- {{{ local function rail()
-- The list of every room, the same on every page, with the room being read
-- marked. Written into every page so the lodge works from a disk with no
-- server.
local function rail(rooms, here)
  local out = { '<nav class="rail">', '<p class="rail-name">The Lodge</p>', "<ol>" }
  for _, room in ipairs(rooms) do
    if room == here then
      out[#out + 1] = '<li class="here"><span>' .. escape(room.title) .. "</span></li>"
    else
      out[#out + 1] = '<li><a href="' .. room.page .. '">' .. escape(room.title) .. "</a></li>"
    end
  end
  out[#out + 1] = "</ol>"
  out[#out + 1] = "</nav>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function backlink_list()
local function backlink_list(arrivals, heading)
  if not arrivals or #arrivals == 0 then
    return ""
  end
  local out = { '<aside class="pointed-at">', "<p>" .. heading .. "</p>", "<ul>" }
  for _, arrival in ipairs(arrivals) do
    out[#out + 1] = '<li><a href="' .. arrival.href .. '">' .. escape(arrival.label) .. "</a></li>"
  end
  out[#out + 1] = "</ul>"
  out[#out + 1] = "</aside>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function render_room()
-- One room's blocks as HTML. Every block that can hold a link gets an id
-- (b1, b2, ...) so a backlink can return to the exact paragraph. Sections
-- other rooms point at are closed with their "pointed at from" list just
-- before the next heading of the same or a higher level.
local function render_room(room, ctx)
  local out = {}
  local open_sections = {}

  local function close_sections(level)
    while #open_sections > 0 and open_sections[#open_sections].level >= level do
      local section = table.remove(open_sections)
      out[#out + 1] = backlink_list(ctx.arrivals[room.stem .. "#" .. section.anchor], "Pointed at from")
    end
  end

  for _, block in ipairs(room.blocks) do
    local id = block.id and (' id="' .. block.id .. '"') or ""
    local function text(raw)
      return inline(raw, block.resolve, ctx.dead, room.stem .. ".md:" .. block.line, ctx.issue_href)
    end

    if block.kind == "heading" then
      close_sections(block.level)
      out[#out + 1] = "<h" .. block.level .. ' id="' .. block.anchor .. '">' .. text(block.text) .. "</h" .. block.level .. ">"
      open_sections[#open_sections + 1] = { level = block.level, anchor = block.anchor }

    elseif block.kind == "paragraph" then
      out[#out + 1] = "<p" .. id .. ">" .. text(block.text) .. "</p>"

    elseif block.kind == "fence" then
      local class = block.language ~= "" and (' class="language-' .. escape(block.language) .. '"') or ""
      local escaped = {}
      for _, line in ipairs(block.lines) do
        escaped[#escaped + 1] = escape(line)
      end
      out[#out + 1] = "<pre><code" .. class .. ">" .. table.concat(escaped, "\n") .. "</code></pre>"

    elseif block.kind == "rule" then
      out[#out + 1] = "<hr>"

    elseif block.kind == "figure" then
      local href, why = block.resolve(block.path)
      if not href then
        ctx.dead[#ctx.dead + 1] = room.stem .. ".md:" .. block.line .. ": " .. why
        href = ""
      end
      ctx.pictures = ctx.pictures + 1
      -- loaded straight away, not lazily: the rooms are short, the gifs
      -- small, and a lazily loaded picture is missing from a page captured
      -- the moment it opens (the first headless photographs showed a dot)
      out[#out + 1] = "<figure" .. id .. '><img src="' .. escape(href) .. '" alt="' .. escape(block.caption)
        .. '"><figcaption>' .. text(block.caption) .. "</figcaption></figure>"

    elseif block.kind == "quote" then
      local inner = {}
      for _, para in ipairs(block.lines) do
        inner[#inner + 1] = "<p>" .. text(para) .. "</p>"
      end
      out[#out + 1] = "<blockquote" .. id .. ">" .. table.concat(inner, "\n") .. "</blockquote>"

    elseif block.kind == "table" then
      local rows = { "<table" .. id .. ">" }
      for row_index, cells in ipairs(block.rows) do
        local tag = (row_index == 1) and "th" or "td"
        local row = { "<tr>" }
        for _, cell in ipairs(cells) do
          row[#row + 1] = "<" .. tag .. ">" .. text(cell) .. "</" .. tag .. ">"
        end
        row[#row + 1] = "</tr>"
        rows[#rows + 1] = table.concat(row)
      end
      rows[#rows + 1] = "</table>"
      out[#out + 1] = table.concat(rows, "\n")

    elseif block.kind == "bullets" or block.kind == "numbers" then
      local tag = (block.kind == "bullets") and "ul" or "ol"
      local items = { "<" .. tag .. id .. ">" }
      for _, item in ipairs(block.items) do
        items[#items + 1] = "<li>" .. text(item) .. "</li>"
      end
      items[#items + 1] = "</" .. tag .. ">"
      out[#out + 1] = table.concat(items, "\n")

    else
      -- the parser only makes the kinds above; anything else is a parser
      -- that learned a shape this renderer was never taught
      error("render_room: unknown block kind " .. tostring(block.kind), 0)
    end
  end

  close_sections(1)
  out[#out + 1] = backlink_list(ctx.arrivals[room.stem], "Rooms that send you here")
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function page_shell()
local function page_shell(room, rooms, body, root)
  return table.concat({
    "<!doctype html>",
    "<!-- Built by lodge/generator/062-build-the-lodge.lua from lodge/pages/" .. room.stem
      .. ".md. Do not edit: the room is the source; this page is rebuilt from it. -->",
    '<html lang="en">',
    "<head>",
    '<meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    "<title>" .. escape(room.title) .. "</title>",
    '<link rel="stylesheet" href="' .. room.stem .. '.css">',
    "</head>",
    '<body class="room-' .. room.stem:gsub("^%d+%-", "") .. '">',
    rail(rooms, room),
    '<main class="room">',
    body,
    '<footer class="made-from">Built from <code>lodge/pages/' .. room.stem
      .. ".md</code> by <code>lodge/build</code>.</footer>",
    "</main>",
    "</body>",
    "</html>",
    "",
  }, "\n")
end
-- }}}

-- {{{ function M.build()
-- The whole lodge. `options`:
--   root       the project folder
--   pages_dir  where the rooms are (default root/lodge/pages)
--   out_dir    where the pages go (default root/docs/HTML/lodge)
-- Returns a report table:
--   rooms, links, backlinks, pictures (numbers), out_dir (string)
-- Raises one error listing every problem when any room is refused or any
-- link is dead; nothing is written in that case.
function M.build(options)
  local root = options.root
  local pages_dir = options.pages_dir or (root .. "/lodge/pages")
  local out_dir = options.out_dir or (root .. "/docs/HTML/lodge")

  local rooms, problems = collect_rooms(pages_dir)
  if #rooms == 0 then
    error("no rooms in " .. pages_dir, 0)
  end
  local by_file = {}
  for _, room in ipairs(rooms) do
    by_file[room.stem .. ".md"] = room
  end

  -- {{{ parse every room and give each heading its anchor
  for _, room in ipairs(rooms) do
    local blocks, refused = parse_room(room.stem .. ".md", room.text)
    for _, why in ipairs(refused) do
      problems[#problems + 1] = why
    end
    room.blocks = blocks
    room.anchors = {}
    local next_id = 0
    for _, block in ipairs(blocks) do
      if block.kind == "heading" then
        local anchor = slug(block.text)
        local base, count = anchor, 1
        while room.anchors[anchor] do
          count = count + 1
          anchor = base .. "-" .. count
        end
        room.anchors[anchor] = block
        block.anchor = anchor
      elseif block.kind ~= "fence" and block.kind ~= "rule" then
        next_id = next_id + 1
        block.id = "b" .. next_id
      end
    end
  end
  -- }}}

  local ctx = { dead = {}, arrivals = {}, pictures = 0, links = 0, backlinks = 0 }

  -- {{{ issue numbers to hrefs, remembered so each is looked up once
  local issue_cache = {}
  ctx.issue_href = function(number)
    if issue_cache[number] == nil then
      local path = find_issue(root, number)
      issue_cache[number] = path and relative(out_dir, path) or false
    end
    return issue_cache[number] or nil
  end
  -- }}}

  -- {{{ the resolver each block uses, which also records arrivals
  -- A target is one of: another room ("057-x.md" or "057-x.md#section"), a
  -- section of this room ("#section"), a web address (passed through), or a
  -- path to any file, written relative to lodge/pages/. Anything else, or
  -- anything that is not there, is a dead link.
  for _, room in ipairs(rooms) do
    local current_heading = room.title
    for _, block in ipairs(room.blocks) do
      if block.kind == "heading" then
        current_heading = block.text
      end
      local from_label = room.title .. (current_heading ~= room.title and (" · " .. current_heading) or "")
      local from_href = room.page .. "#" .. (block.id or block.anchor or "")
      block.resolve = function(target)
        ctx.links = ctx.links + 1
        if target:match("^https?://") then
          return target
        end
        local file, fragment = target:match("^([^#]*)#?(.*)$")
        local destination = (file == "") and room or by_file[file]
        if destination then
          if fragment ~= "" and not destination.anchors[fragment] then
            return nil, "no section #" .. fragment .. " in " .. destination.stem .. ".md"
          end
          if destination ~= room then
            local key = destination.stem .. (fragment ~= "" and ("#" .. fragment) or "")
            ctx.arrivals[key] = ctx.arrivals[key] or {}
            local list = ctx.arrivals[key]
            local seen = false
            for _, arrival in ipairs(list) do
              if arrival.href == from_href then
                seen = true
              end
            end
            if not seen then
              list[#list + 1] = { href = from_href, label = from_label }
              ctx.backlinks = ctx.backlinks + 1
            end
          end
          return destination.page .. (fragment ~= "" and ("#" .. fragment) or "")
        end
        if fragment ~= "" then
          return nil, "a section link only works between rooms: " .. target
        end
        if file:match("%.md$") and file:match("^%d%d%d%-") and not file:match("/") then
          return nil, "no room " .. file
        end
        local absolute = normalise(pages_dir .. "/" .. file)
        if not exists(absolute) then
          return nil, "nothing at " .. target .. " (looked for " .. absolute .. ")"
        end
        return relative(out_dir, absolute)
      end
    end
  end
  -- }}}

  -- {{{ render every room twice: once to gather arrivals, once to draw them
  -- The first pass resolves every link, which is what records who points
  -- where; only the second pass knows every section's visitors.
  for _, room in ipairs(rooms) do
    render_room(room, ctx)
  end
  local first_pass_dead = ctx.dead
  for _, why in ipairs(first_pass_dead) do
    problems[#problems + 1] = why
  end
  if #problems > 0 then
    error("the lodge was not built:\n  " .. table.concat(problems, "\n  "), 0)
  end
  local links, backlinks = ctx.links, ctx.backlinks
  ctx.dead, ctx.pictures = {}, 0
  local pages = {}
  for _, room in ipairs(rooms) do
    pages[room] = page_shell(room, rooms, render_room(room, ctx), root)
  end
  -- }}}

  -- {{{ write the pages, each room's stylesheet, and the front door
  for _, room in ipairs(rooms) do
    write_file(out_dir .. "/" .. room.page, pages[room])
    write_file(out_dir .. "/" .. room.stem .. ".css", read_file(room.style))
  end
  write_file(out_dir .. "/index.html", table.concat({
    "<!doctype html>",
    "<!-- Built by lodge/generator/062-build-the-lodge.lua: the lodge's address opens its first room. -->",
    '<meta charset="utf-8">',
    '<meta http-equiv="refresh" content="0; url=' .. rooms[1].page .. '">',
    "<title>" .. escape(rooms[1].title) .. "</title>",
    '<a href="' .. rooms[1].page .. '">' .. escape(rooms[1].title) .. "</a>",
    "",
  }, "\n"))
  -- }}}

  return {
    rooms = #rooms,
    links = links,
    backlinks = backlinks,
    pictures = ctx.pictures,
    out_dir = out_dir,
  }
end
-- }}}

-- {{{ the command
-- Run as a program: build, print what was counted, log it, and say goodbye.
-- Loaded with dofile there is no `arg` naming this file, and nothing runs.
if arg and arg[0] and arg[0]:match("062%-build%-the%-lodge%.lua$") then
  if arg[1] and arg[1] ~= "" then
    DIR = arg[1]
  end
  local ok, report = pcall(M.build, { root = DIR })
  local log_path = DIR .. "/tmp/shared-memory/lodge-build.log"
  if not ok then
    io.stderr:write(report, "\n")
    write_file(log_path, os.date("%Y-%m-%d %H:%M:%S") .. " FAILED\n" .. report .. "\n")
    os.exit(1)
  end
  local summary = string.format(
    "rooms built: %d\nlinks followed: %d\nbacklinks drawn: %d\npictures hung: %d\npages in: %s\n",
    report.rooms, report.links, report.backlinks, report.pictures, report.out_dir)
  io.write(summary)
  write_file(log_path, os.date("%Y-%m-%d %H:%M:%S") .. " built\n" .. summary)
  write_file(DIR .. "/lodge/output/goodbye", table.concat({
    "goodbye from lodge/build",
    "ended: " .. os.date("%Y-%m-%d %H:%M:%S"),
    summary,
  }, "\n"))
end
-- }}}

return M
