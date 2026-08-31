#!/usr/bin/env luajit
-- 149-the-documentation-site.lua
--
-- Every document this project has, as one cross-linked site you can open in a
-- browser with nothing running.
--
-- For a general: the writing here is spread over five directories and about two
-- hundred files, and the most valuable thing about it is that the files refer to
-- each other constantly. A ticket names the documents it depends on. A source
-- page names the tests that check it. A design note names the ticket that proved
-- it wrong. On disk those references are bare numbers you have to go and look
-- up by hand. This turns every one of them into something you click, puts a list
-- of everything down the left, and -- the part that does not exist on disk at all
-- -- shows every page the things that point AT it.
--
-- WHAT IT READS, AND WHAT IT NEVER WRITES. Everything in docs/, notes/ and
-- strategems/, every ticket open and completed, and the companion page beside
-- every source file. It writes only into the output directory. If a page is
-- wrong on this site it is wrong in the file, and the file is where it gets
-- fixed -- which is why nothing here is editable and every page says where it
-- came from.
--
-- THE HARD PART IS THE BARE NUMBERS. This project cites things as `502` and
-- `029`, three digits either way, and a number alone does not say whether it
-- means a ticket, a design document or a source file. Most do not collide,
-- because the ticket numbers mostly start above the file indices -- but the
-- first-phase tickets sit exactly on top of real source files, so `105` is both
-- a ticket and a program. The ticket wins there, because that is how the prose
-- uses it, and the full-name form `105-the-watchdog` still reaches the program.
-- Every collision is printed at the end of a build. A wrong link that announces
-- itself is a different thing from one that does not.
--
-- REFERENCES TO THINGS THAT ARE NOT THERE ARE LEFT ALONE AND COUNTED. They come
-- out as plain text, and the build ends by listing them, so the last thing this
-- prints is an inventory of everything the project points at and does not have.
--
-- WHEN THAT LIST IS NOT EMPTY, THE DOCUMENTS ARE WRONG AND THAT IS THE FIX. The
-- first build reported eight, all of them pointing at things deliberately removed
-- -- a deleted status system, an old filename, sub-issue names reserved and never
-- used. The temptation is to write the explanations down somewhere and have this
-- forgive them. That would be a second copy of the history, kept by hand, beside
-- the one git already keeps perfectly. The documents were corrected instead, and
-- an empty list means what it says.
--
-- usage:
--   luajit 149-the-documentation-site.lua               build into docs/HTML/
--   luajit 149-the-documentation-site.lua --to PATH     build somewhere else
--   luajit 149-the-documentation-site.lua --quiet       build without the report

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local M = {}

-- {{{ local function read_file(path) / write_file(path, text)
local function read_file(path)
  local handle = io.open(path, "r")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end

local function write_file(path, text)
  local handle = io.open(path, "w")
  if not handle then return false, "cannot write " .. path end
  handle:write(text)
  handle:close()
  return true
end
-- }}}

-- {{{ local function listing(pattern)
-- The files matching a shell pattern, as a list. Empty rather than an error
-- when a directory is absent, because a project without strategems is fine.
local function listing(pattern)
  local found = {}
  local pipe = io.popen("ls -1 " .. pattern .. " 2>/dev/null")
  if not pipe then return found end
  for line in pipe:lines() do found[#found + 1] = line end
  pipe:close()
  return found
end
-- }}}

-- {{{ M.collect(dir)
--
-- Every document in the project, as a list of pages. Each page is:
--
--   kind     "document" | "note" | "strategem" | "issue" | "source" | "index"
--   key      the leading number if it has one -- "011", "107a", "502"
--   name     the filename without its extension
--   title    the first heading in the file, or the name
--   file     the html file it becomes, prefixed by kind so nothing collides
--   source   where it came from, shown at the foot of every page
--   text     the markdown itself
--   phase    for tickets, the first digit -- which is the phase it belongs to
--   status   for tickets, "open" or "completed"
--
-- The kind prefix on the filename is not decoration: there is a document `102`
-- and a ticket `102`, and without the prefix one would overwrite the other.
function M.collect(dir)
  local pages = {}

  local function add(kind, path, extra)
    local text = read_file(path)
    if not text then return end
    local name = path:match("([^/]+)$")
    name = name:gsub("%.info%.md$", ""):gsub("%.md$", "")
    local page = {
      kind = kind,
      name = name,
      key = name:match("^(%d+[a-z]?)%-") or name:match("^(%d+[a-z]?)$"),
      title = text:match("^#%s+(.-)\r?\n") or name,
      file = kind .. "-" .. name .. ".html",
      -- The project root is stripped by length rather than by pattern. It holds
      -- hyphens, which mean something in a Lua pattern, so matching it as one
      -- silently failed and every page showed its full absolute path.
      source = path:sub(1, #dir + 1) == (dir .. "/") and path:sub(#dir + 2) or path,
      text = text,
    }
    -- The info pages title themselves "144-assemble-a-machine — info", which is
    -- the name twice over once it sits under a heading that already says it.
    page.title = page.title:gsub("%s+—%s+info$", "")
    if extra then for field, value in pairs(extra) do page[field] = value end end
    pages[#pages + 1] = page
  end

  for _, path in ipairs(listing(dir .. "/docs/*.md")) do add("document", path) end
  for _, path in ipairs(listing(dir .. "/notes/*")) do
    if not path:match("%.swp$") then add("note", path) end
  end
  for _, path in ipairs(listing(dir .. "/strategems/*")) do add("strategem", path) end
  -- What the seed carries rather than what was written about it. The instruction
  -- a machine wakes up holding lives here, and it is the most consequential
  -- document in the project -- it was invisible to the first build of this site
  -- because it is not in docs/, which is exactly the kind of absence a site
  -- assembled from directory listings is prone to.
  for _, path in ipairs(listing(dir .. "/assets/*.md")) do
    -- A companion page is not a thing the seed carries, and the pattern for one
    -- ends in .md too -- so without this the fixture's page is collected twice,
    -- under two kinds, and writes two files claiming the same number.
    if not path:match("%.info%.md$") then add("carried", path) end
  end
  for _, path in ipairs(listing(dir .. "/issues/*.md")) do
    local name = path:match("([^/]+)$")
    -- The per-phase progress files are not tickets and do not sort with them.
    local kind = name:match("^phase%-") and "progress" or "issue"
    add(kind, path, { status = "open" })
  end
  for _, path in ipairs(listing(dir .. "/issues/completed/*.md")) do
    add("issue", path, { status = "completed" })
  end
  for _, path in ipairs(listing(dir .. "/src/*.info.md")) do add("source", path) end
  for _, path in ipairs(listing(dir .. "/assets/*.info.md")) do add("source", path) end

  for _, page in ipairs(pages) do
    if page.kind == "issue" and page.key then
      page.phase = tonumber(page.key:sub(1, 1))
    end
  end

  return pages
end
-- }}}

-- {{{ M.resolver(pages)
--
-- Builds the function that turns the text of a code span into a destination.
-- Returns that function, the list of collisions it had to settle, and a table
-- it fills in as it goes with every reference that pointed at nothing.
--
-- What it will follow:
--
--   `502`                     a bare number -- ticket, then document, then source
--   `144-assemble-a-machine`  a full name, which is never ambiguous
--   `018-launch-board.lua`    the same, with the extension people actually type
--   `docs/011-roadmap.md`     a path, as written in a table of contents
--
-- Precedence on a bare number is ticket, document, source, and it is only ever
-- exercised by the first-phase tickets. It is settled this way because the prose
-- that writes `105` means the ticket every time it was checked, and the program
-- of the same number is always written out in full where it is meant.
function M.resolver(pages)
  local by_key, by_name, collisions, missing = {}, {}, {}, {}

  local rank = { issue = 1, document = 2, carried = 3, progress = 4, note = 5,
                 strategem = 6, source = 7 }

  for _, page in ipairs(pages) do
    by_name[page.name] = page
    if page.key then
      local held = by_key[page.key]
      if not held then
        by_key[page.key] = page
      else
        collisions[#collisions + 1] = {
          key = page.key, kept = nil,
          held = held.kind, held_name = held.name,
          other = page.kind, other_name = page.name,
        }
        if (rank[page.kind] or 9) < (rank[held.kind] or 9) then
          by_key[page.key] = page
        end
      end
    end
  end

  -- Recorded after the fact so the report says which one actually won rather
  -- than which one the rule says should.
  for _, clash in ipairs(collisions) do
    clash.kept = by_key[clash.key].kind
    clash.kept_name = by_key[clash.key].name
    clash.lost_name = (clash.kept_name == clash.held_name) and clash.other_name
                                                            or clash.held_name
  end

  local function resolve(text)
    -- Trim what people write around a reference: possessives, punctuation and
    -- the backticked-path form used in tables of contents.
    local body = text:gsub("'s$", ""):gsub("[%.,;:]$", "")
    body = body:gsub("^[%w]+/", "")
    body = body:gsub("%.info%.md$", ""):gsub("%.lua$", ""):gsub("%.md$", "")
    body = body:gsub("%.sh$", "")

    local page = by_name[body]
    if not page then
      local key = body:match("^(%d%d%d[a-z]?)$")
      if key then page = by_key[key] end
    end
    if page then return page end

    -- Only things SHAPED like a reference are worth counting as missing; a code
    -- span holding a word is just a code span.
    if body:match("^%d%d%d[a-z]?$") or body:match("^%d%d%d[a-z]?%-[%w%-]+$") then
      missing[body] = (missing[body] or 0) + 1
    end
    return nil
  end

  return resolve, collisions, missing
end
-- }}}

-- {{{ M.references(pages, resolve)
--
-- Which pages point at which. Walks every code span in every document before
-- anything is rendered, so that by the time a page is written it already knows
-- what points at it.
--
-- This is the one thing the site has that the files do not. On disk a reference
-- runs one way and the only way to find what mentions a document is to search
-- the whole project; here it is at the foot of the page.
function M.references(pages, resolve)
  local forward, backward = {}, {}
  for _, page in ipairs(pages) do
    forward[page.name], backward[page.name] = forward[page.name] or {}, backward[page.name] or {}
  end

  for _, page in ipairs(pages) do
    local seen = {}
    for span in page.text:gmatch("`([^`\n]+)`") do
      local target = resolve(span)
      if target and target.name ~= page.name and not seen[target.name] then
        seen[target.name] = true
        forward[page.name][#forward[page.name] + 1] = target
        backward[target.name] = backward[target.name] or {}
        backward[target.name][#backward[target.name] + 1] = page
      end
    end
  end

  return forward, backward
end
-- }}}

-- {{{ local function group_pages(pages)
--
-- The order things appear down the left. Groups rather than one list of two
-- hundred entries, and the order is the order somebody arriving would want:
-- what this is, then the design, then the work, then the parts.
local function group_pages(pages)
  local groups = {
    { name = "Documents",  kind = "document",  open = true },
    { name = "Notes",      kind = "note",      open = true },
    { name = "Strategems", kind = "strategem", open = true },
    { name = "What it carries", kind = "carried", open = true },
    { name = "Tickets, open",      kind = "issue", status = "open",      open = true },
    { name = "Tickets, completed", kind = "issue", status = "completed", open = false },
    { name = "Phase progress",     kind = "progress", open = false },
    { name = "Source pages",       kind = "source",   open = false },
  }

  for _, group in ipairs(groups) do
    group.entries = {}
    for _, page in ipairs(pages) do
      if page.kind == group.kind and (not group.status or page.status == group.status) then
        group.entries[#group.entries + 1] = page
      end
    end
    table.sort(group.entries, function(left, right)
      -- By number where there is one, so the reading order the file indices
      -- encode survives; by name otherwise.
      local a = tonumber(left.key and left.key:match("^(%d+)") or nil)
      local b = tonumber(right.key and right.key:match("^(%d+)") or nil)
      if a and b and a ~= b then return a < b end
      return left.name < right.name
    end)
  end

  return groups
end
-- }}}

-- {{{ local function sidebar(groups, here)
-- The list of everything, with whichever page is being read marked. Built once
-- and written into every page, because a site that has to be served to work is
-- a site that does not work from a disk.
local function sidebar(groups, here)
  local out = {}
  local function line(text) out[#out + 1] = text end

  line('<h1>every software image able</h1>')
  line('<div class="tagline">a seed generation system</div>')
  line('<input class="filter" id="filter" type="search" placeholder="filter everything…" ' ..
       'autocomplete="off" spellcheck="false">')
  line('<div class="filter-note" id="filter-note"></div>')

  local function entry(file, number, title, find, current)
    local shown = number and ('<span class="num">' .. number .. "</span> " .. title) or title
    line('<a href="' .. file .. '"' ..
         (current and ' class="here"' or "") ..
         ' data-find="' .. find:lower():gsub('"', "") .. '">' .. shown .. "</a>")
  end

  line("<details open><summary>Start</summary>")
  entry("index.html", nil, "the front page", "front page index start overview", here == "index")
  entry("coverage.html", nil, "what is documented", "coverage documented missing", here == "coverage")
  line("</details>")

  for _, group in ipairs(groups) do
    if #group.entries > 0 then
      line("<details" .. (group.open and " open" or "") .. "><summary>" .. group.name ..
           ' <span class="tally">' .. #group.entries .. "</span></summary>")
      for _, page in ipairs(group.entries) do
        entry(page.file, page.key, page.title, page.name .. " " .. page.title,
              here == page.name)
      end
      line("</details>")
    end
  end

  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function outline_of(headings)
-- The headings of one page, to follow down the side of a long document. Only
-- the second and third levels: the first is the title, which is already there,
-- and the fourth is detail that would make the outline as long as the page.
local function outline_of(headings)
  local wanted = {}
  for _, heading in ipairs(headings) do
    if heading.level == 2 or heading.level == 3 then wanted[#wanted + 1] = heading end
  end
  if #wanted < 3 then return nil end

  local out = { '<div class="label">on this page</div>' }
  for _, heading in ipairs(wanted) do
    -- The heading arrives rendered, so it may hold markup that must not end up
    -- inside a link's text.
    local text = heading.text:gsub("<[^>]->", "")
    out[#out + 1] = '<a class="' .. (heading.level == 3 and "deep" or "") ..
                    '" href="#' .. heading.id .. '">' .. text .. "</a>"
  end
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function ledger_of(page, forward, backward)
--
-- What points here, what this points at, and where the words came from.
--
-- The backward half is the reason this site is worth building. On disk a
-- reference runs one way only, and finding what mentions a document means
-- searching the whole project; here it is a row of things to click.
local function ledger_of(page, forward, backward)
  local out = { '<div class="ledger">' }

  local function chips(label, list)
    if not list or #list == 0 then return end
    out[#out + 1] = "<h2>" .. label .. "</h2>"
    out[#out + 1] = '<div class="chips">'
    local sorted = {}
    for _, other in ipairs(list) do sorted[#sorted + 1] = other end
    table.sort(sorted, function(left, right) return left.name < right.name end)
    for _, other in ipairs(sorted) do
      out[#out + 1] = '<a class="chip" href="' .. other.file .. '">' ..
                      (other.key and (other.key .. " ") or "") ..
                      other.title .. ' <span class="kind">' .. other.kind .. "</span></a>"
    end
    out[#out + 1] = "</div>"
  end

  chips("What points here", backward[page.name])
  chips("What this points at", forward[page.name])

  out[#out + 1] = '<div class="provenance">This page is ' .. page.source ..
                  ". Nothing here is edited; it is built from that file.</div>"
  out[#out + 1] = "</div>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function count_words(text)
local function count_words(text)
  local words = 0
  for _ in text:gmatch("%S+") do words = words + 1 end
  return words
end
-- }}}

-- {{{ local function front_page(pages, groups, missing, house, render)
--
-- What the project is, in numbers counted during this build. Every figure here
-- is arrived at by counting files a moment ago, because a statistic typed into
-- a document is a statistic that was true once.
local function front_page(pages, groups, missing, house, render)
  local out = {}
  local function line(text) out[#out + 1] = text end

  local counts, words, lines_total = {}, 0, 0
  for _, page in ipairs(pages) do
    counts[page.kind] = (counts[page.kind] or 0) + 1
    words = words + count_words(page.text)
    local _, breaks = page.text:gsub("\n", "")
    lines_total = lines_total + breaks
  end

  local open_tickets, done_tickets = 0, 0
  for _, page in ipairs(pages) do
    if page.kind == "issue" then
      if page.status == "completed" then done_tickets = done_tickets + 1
      else open_tickets = open_tickets + 1 end
    end
  end

  local hand, derived = 0, 0
  for _, page in ipairs(pages) do
    if page.kind == "source" then
      if page.text:find("own comments by `147`", 1, true) then derived = derived + 1
      else hand = hand + 1 end
    end
  end

  line("<h1>every software image able</h1>")
  line("<p>An image flashed to a computer that has nothing on it, holding a model " ..
       "and instructions to build every piece of software it can fit on the disk. " ..
       "This is everything written down about it, cross-linked. Every number on " ..
       "this page was counted while it was being built.</p>")

  -- {{{ the tiles
  line('<div class="tiles">')
  local function tile(figure, caption)
    line('<div class="tile"><div class="figure">' .. figure ..
         '</div><div class="caption">' .. caption .. "</div></div>")
  end
  tile(#pages, "pages here")
  tile(string.format("%.0fk", words / 1000), "words")
  tile(done_tickets .. "<span style='color:var(--ink-quiet);font-size:17px'>/" ..
       (done_tickets + open_tickets) .. "</span>", "tickets done")
  tile(counts.source or 0, "source pages")
  tile(counts.document or 0, "design documents")
  line("</div>")
  -- }}}

  -- {{{ tickets by phase
  line("<h2>The work, by phase</h2>")
  line("<p>Phases are clusters of functionality rather than a schedule, so the last " ..
       "ticket finished may well be an early one. Phase six is the capstone and the " ..
       "only one that proves anything; phase seven is numbered last and was built first.</p>")

  local by_phase = {}
  for _, page in ipairs(pages) do
    if page.kind == "issue" and page.phase then
      by_phase[page.phase] = by_phase[page.phase] or { open = 0, done = 0 }
      if page.status == "completed" then
        by_phase[page.phase].done = by_phase[page.phase].done + 1
      else
        by_phase[page.phase].open = by_phase[page.phase].open + 1
      end
    end
  end

  local phase_names = {
    "the engine", "the hands", "what it is told", "three tongues",
    "the image", "waking", "the proving ground",
  }
  local rows = {}
  for phase = 1, 7 do
    local tally = by_phase[phase] or { open = 0, done = 0 }
    rows[#rows + 1] = {
      label = phase .. ". " .. (phase_names[phase] or ""),
      parts = {
        { value = tally.done, colour = "var(--green)", name = "completed" },
        { value = tally.open, colour = "var(--amber)", name = "open" },
      },
    }
  end
  line('<div class="chart">')
  line(house.stacked_bars(rows, { width = 640, label_width = 150 }))
  line('<div class="legend">' ..
       '<span><i style="background:var(--green)"></i>completed</span>' ..
       '<span><i style="background:var(--amber)"></i>open</span></div>')
  line("</div>")
  -- }}}

  -- {{{ the longest documents
  line("<h2>Where the writing is</h2>")
  line("<p>The design documents and notes, by length. Click one to read it.</p>")
  local written = {}
  for _, page in ipairs(pages) do
    if page.kind == "document" or page.kind == "note" or page.kind == "strategem" then
      written[#written + 1] = { label = page.title, value = count_words(page.text),
                                href = page.file, colour = "var(--blue)" }
    end
  end
  table.sort(written, function(left, right) return left.value > right.value end)
  while #written > 14 do written[#written] = nil end
  line('<div class="chart">')
  line(house.ranked_bars(written, { width = 640, label_width = 230 }))
  line('<div class="legend"><span>words per document, longest fourteen</span></div>')
  line("</div>")
  -- }}}

  -- {{{ how the source pages came to exist
  line("<h2>The companion pages</h2>")
  line("<p>Every source file has a page saying what it offers. Forty-seven were " ..
       "written by hand and say things no signature contains — why a thing exists, " ..
       "what it deliberately refuses to know. The rest are lifted from each file's " ..
       "own comments, which means they cannot drift, and the way to improve one is " ..
       "to improve the comments it was taken from. " ..
       '<a href="coverage.html">The full list is here</a>, with the thin ones findable.</p>')
  line('<div class="chart">')
  line(house.stacked_bars({
    { label = "source pages", parts = {
        { value = hand, colour = "var(--green)", name = "written by hand" },
        { value = derived, colour = "var(--blue)", name = "lifted from comments" } } },
  }, { width = 640, label_width = 150 }))
  line('<div class="legend">' ..
       '<span><i style="background:var(--green)"></i>written by hand</span>' ..
       '<span><i style="background:var(--blue)"></i>lifted from the source\'s comments</span></div>')
  line("</div>")
  -- }}}

  -- {{{ what the project points at and does not have
  local absent = {}
  for reference, times in pairs(missing) do
    absent[#absent + 1] = { reference = reference, times = times }
  end
  table.sort(absent, function(left, right)
    if left.times ~= right.times then return left.times > right.times end
    return left.reference < right.reference
  end)

  line("<h2>Pointed at, and not here</h2>")
  if #absent == 0 then
    line("<p>Every reference in every document reaches something. This is checked on " ..
         "each build rather than believed.</p>")
  else
    line("<p><strong>References that reach nothing.</strong> Each one is a document " ..
         "describing something this project does not have — usually because it was " ..
         "removed and the writing about it was not. The fix is in the document rather " ..
         "than here; what was there before is in the commit history.</p>")
    line('<div class="chips">')
    for index = 1, math.min(#absent, 40) do
      line('<span class="chip miss">' .. absent[index].reference ..
           ' <span class="kind">×' .. absent[index].times .. "</span></span>")
    end
    line("</div>")
  end

  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function coverage_page(pages)
--
-- Every companion page, how long it is, and where it came from -- with a slider
-- and a set of buttons, because the useful question is "which of these is too
-- thin to be worth reading" and that is a question about a threshold.
local function coverage_page(pages)
  local out = {}
  local function line(text) out[#out + 1] = text end

  local rows = {}
  for _, page in ipairs(pages) do
    if page.kind == "source" then
      local _, breaks = page.text:gsub("\n", "")
      rows[#rows + 1] = {
        page = page,
        lines = breaks + 1,
        words = count_words(page.text),
        kind = page.text:find("own comments by `147`", 1, true) and "derived" or "hand",
      }
    end
  end
  table.sort(rows, function(left, right) return left.lines < right.lines end)

  line("<h1>What is documented</h1>")
  line("<p>Every source file in this project has a companion page. This is all of " ..
       "them, shortest first — because the shortest are the ones whose source file " ..
       "has the least to say about itself, and that is a fact about the source " ..
       "rather than about the page.</p>")
  line("<p>A page <strong>written by hand</strong> says why a thing exists and what it " ..
       "refuses to know. A page <strong>lifted from comments</strong> is generated from " ..
       "the file's own header and cannot drift from it. To make one of those longer, " ..
       "write more in the source file and build again.</p>")

  line('<div class="controls">')
  line('<label for="at-least">at least <span id="at-least-shown">0</span> lines</label>')
  line('<input type="range" id="at-least" min="0" max="80" value="0" step="1">')
  line('<button class="knob" data-kind="all" aria-pressed="true">both</button>')
  line('<button class="knob" data-kind="hand" aria-pressed="false">written by hand</button>')
  line('<button class="knob" data-kind="derived" aria-pressed="false">lifted from comments</button>')
  line('<span id="shelf-tally"></span>')
  line("</div>")

  line('<div id="shelf">')
  line("<table><thead><tr><th>Page</th><th>Lines</th><th>Words</th><th>Where it came from</th>" ..
       "</tr></thead><tbody>")
  for _, row in ipairs(rows) do
    line('<tr data-lines="' .. row.lines .. '" data-kind="' .. row.kind .. '">' ..
         '<td><a href="' .. row.page.file .. '">' .. row.page.name .. "</a></td>" ..
         "<td>" .. row.lines .. "</td>" ..
         "<td>" .. row.words .. "</td>" ..
         "<td>" .. (row.kind == "hand" and "written by hand" or "lifted from comments") ..
         "</td></tr>")
  end
  line("</tbody></table>")
  line("</div>")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.build(dir, out_dir, quiet)
--
-- The whole site. Returns a report: how many pages, which references collided,
-- and everything pointed at that does not exist.
function M.build(dir, out_dir, quiet)
  local render = dofile(dir .. "/src/148-render-markdown.lua")
  local house = dofile(dir .. "/src/150-the-house-style.lua")

  local pages = M.collect(dir)
  local resolve, collisions, missing = M.resolver(pages)
  local forward, backward = M.references(pages, resolve)
  local groups = group_pages(pages)

  os.execute("mkdir -p " .. out_dir)

  -- The link function handed to the renderer: a code span to a file, or nothing.
  local function link(text)
    local target = resolve(text)
    return target and target.file or nil
  end

  local crumbs = {
    document = "design document", note = "note", strategem = "strategem",
    issue = "ticket", progress = "phase progress", source = "source page",
    carried = "carried by the seed",
  }

  local written = 0
  for _, page in ipairs(pages) do
    local body, headings = render.markdown(page.text, link)
    local crumb = crumbs[page.kind] or page.kind
    if page.kind == "issue" then
      crumb = crumb .. " · " .. (page.status == "completed" and "completed" or "open")
      if page.phase then crumb = crumb .. " · phase " .. page.phase end
    end
    local html = house.shell({
      title = page.title,
      crumb = crumb .. ' · <a href="index.html">everything</a>',
      body = body,
      sidebar = sidebar(groups, page.name),
      outline = outline_of(headings),
      ledger = ledger_of(page, forward, backward),
    })
    local ok, why = write_file(out_dir .. "/" .. page.file, html)
    if not ok then return nil, why end
    written = written + 1
  end

  -- {{{ the two pages that are not documents
  local front = house.shell({
    title = "everything",
    body = front_page(pages, groups, missing, house, render),
    sidebar = sidebar(groups, "index"),
    wide = true,
  })
  write_file(out_dir .. "/index.html", front)

  local coverage = house.shell({
    title = "what is documented",
    crumb = 'the companion pages · <a href="index.html">everything</a>',
    body = coverage_page(pages),
    sidebar = sidebar(groups, "coverage"),
    wide = true,
  })
  write_file(out_dir .. "/coverage.html", coverage)
  -- }}}

  write_file(out_dir .. "/style.css", house.stylesheet())
  write_file(out_dir .. "/site.js", house.script())

  local absent = {}
  for reference, times in pairs(missing) do
    absent[#absent + 1] = { reference = reference, times = times }
  end
  table.sort(absent, function(left, right) return left.reference < right.reference end)

  return {
    pages = written + 2,
    documents = written,
    collisions = collisions,
    absent = absent,
    out_dir = out_dir,
  }
end
-- }}}

-- {{{ the command line
if arg and arg[0] and arg[0]:match("149%-the%-documentation%-site") then
  local out_dir, quiet = nil, false
  local index = 1
  while index <= #arg do
    local word = arg[index]
    if word == "--dir" then index = index + 1 ; DIR = arg[index]
    elseif word == "--to" then index = index + 1 ; out_dir = arg[index]
    elseif word == "--quiet" then quiet = true
    else
      io.write("149-the-documentation-site: unknown option ", word, "\n")
      os.exit(1)
    end
    index = index + 1
  end
  out_dir = out_dir or (DIR .. "/docs/HTML")

  local report, why = M.build(DIR, out_dir, quiet)
  if not report then
    io.write("149-the-documentation-site: ", tostring(why), "\n")
    os.exit(1)
  end

  if not quiet then
    io.write("\n  built ", report.pages, " pages into ", report.out_dir, "\n")
    io.write("  open ", report.out_dir, "/index.html\n\n")

    if #report.collisions > 0 then
      io.write("  numbers meaning two things, settled in favour of the first:\n")
      for _, clash in ipairs(report.collisions) do
        io.write("    `", clash.key, "`  ", clash.kept_name,
                 " (", clash.kept, ")  over  ", clash.lost_name, "\n")
      end
      io.write("\n")
    end

    if #report.absent > 0 then
      io.write("  pointed at and not here (", #report.absent, "):\n    ")
      local names = {}
      for _, entry in ipairs(report.absent) do names[#names + 1] = entry.reference end
      io.write(table.concat(names, "  "), "\n")
      io.write("    each one is a document that needs correcting\n\n")
    else
      io.write("  every reference reaches something\n\n")
    end
  end
end
-- }}}

return M
