#!/usr/bin/env luajit
-- 151-test-the-documentation-site.lua
--
-- Checks the renderer and the site builder: that written text comes out as the
-- markup it should, that references reach the right page, and that every page
-- the build produces is closed properly.
--
-- For a general: this project's documentation is now built by a program rather
-- than written by hand, which means a mistake in the program is a mistake in two
-- hundred pages at once. This runs the program over its own project and checks
-- the result, so that happens once rather than being noticed later by a reader.
--
-- THREE OF THESE ARE THERE BECAUSE THEY HAPPENED. The renderer took the comments
-- out of fenced blocks and replaced them with a number, because the marker it
-- used to hold them aside was made of digits and the pass that colours numbers
-- found it. A list whose every item was indented -- which is how a list inside a
-- comment block arrives -- opened an inner list with no outer item to sit in, and
-- left the page unbalanced. And the project root was stripped from paths with a
-- pattern, though it contains hyphens, which mean something in a pattern, so
-- every page displayed its full absolute path instead. All three produced output
-- that looked deliberate, which is this project's usual failure and the reason
-- the last check here reads every page rather than trusting any of them.
--
-- usage:
--   luajit 151-test-the-documentation-site.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

do
  local index = 1
  while index <= #arg do
    if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
    index = index + 1
  end
end

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

local passed, failed = 0, 0

-- {{{ local function check(what, ok, detail)
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-52s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-52s WRONG", what))
    if detail and detail ~= "" then
      for line in tostring(detail):gmatch("[^\n]+") do say("      " .. line) end
    end
  end
end
-- }}}

local render = dofile(DIR .. "/src/148-render-markdown.lua")
local site = dofile(DIR .. "/src/149-the-documentation-site.lua")
local house = dofile(DIR .. "/src/150-the-house-style.lua")

say("")
say("  the renderer")
say("")

-- {{{ the ordinary shapes
do
  local body = render.markdown("# A title\n\nSome words.")
  check("a heading becomes a heading with a place to jump to",
        body:find('<h1 id="a%-title"') ~= nil, body)
  check("a paragraph becomes a paragraph", body:find("<p>Some words.</p>") ~= nil, body)

  local table_body = render.markdown("| One | Two |\n|---|---|\n| a | b |")
  check("a row of pipes becomes a table",
        table_body:find("<th>One</th>") ~= nil and table_body:find("<td>b</td>") ~= nil,
        table_body)

  local quoted = render.markdown("> said once")
  check("a quote becomes a quote", quoted:find("<blockquote>") ~= nil, quoted)

  local marked = render.markdown("**loud** and *quiet*")
  check("emphasis survives",
        marked:find("<strong>loud</strong>") ~= nil and marked:find("<em>quiet</em>") ~= nil,
        marked)

  local escaped = render.markdown("a < b & c > d")
  check("the characters that would be markup are made safe",
        escaped:find("&lt;") ~= nil and escaped:find("&amp;") ~= nil, escaped)
end
-- }}}

-- {{{ a comment inside a fenced block survives
-- This is the one that failed. The marker holding comments aside was numbered
-- in digits, and the pass that colours numbers rewrote it -- so every comment
-- in every code block became the marker's own index.
do
  local body = render.markdown("```lua\nlocal x = 1 -- why it is one\n```")
  check("a comment in a fenced block is still there",
        body:find("why it is one", 1, true) ~= nil, body)
  check("the comment is coloured as a comment",
        body:find('<span class="c">') ~= nil, body)
  check("a keyword beside it is coloured as a keyword",
        body:find('<span class="k">local</span>') ~= nil, body)

  local shell = render.markdown("```sh\necho hello # a note\n```")
  check("the same holds for a shell block",
        shell:find("a note", 1, true) ~= nil, shell)

  local plain = render.markdown("```\n0x40 mov rax, 1\n```")
  check("a block with no language named is left uncoloured",
        plain:find("<span") == nil, plain)
end
-- }}}

-- {{{ lists, including the one that was not closed
-- A list written inside a comment block arrives indented in its entirety. Read
-- as absolute indentation every item looks nested, which opened an inner list
-- with no outer item to hold it and left the page broken.
do
  local flat = render.markdown("- one\n- two")
  check("a flat list has one item per line",
        select(2, flat:gsub("<li>", "")) == 2, flat)

  local nested = render.markdown("- one\n- two\n  - under two")
  check("a nested list sits inside the item above it",
        nested:find("two<ul><li>under two</li></ul></li>") ~= nil, nested)

  local indented = render.markdown("   * every item indented\n   * and so is this one")
  local opens = select(2, indented:gsub("<ul>", ""))
  local closes = select(2, indented:gsub("</ul>", ""))
  check("a wholly indented list is not read as nested",
        opens == 1 and closes == 1, indented)
end
-- }}}

-- {{{ references, which are the point of the whole thing
do
  local body = render.markdown("see `502` and `nothing`", function(text)
    if text == "502" then return "issue-502.html" end
    return nil
  end)
  check("a reference that resolves becomes a link",
        body:find('href="issue%-502.html"') ~= nil, body)
  check("a code span that resolves to nothing stays plain",
        body:find("<code>nothing</code>") ~= nil and
        body:find('>nothing</a>') == nil, body)

  local inside = render.markdown("`a_path_with_underscores`")
  check("markup inside a code span is left alone",
        inside:find("a_path_with_underscores", 1, true) ~= nil, inside)
end
-- }}}

say("")
say("  what the site knows")
say("")

-- {{{ collecting, resolving and pointing
local pages = site.collect(DIR)
check("it finds pages", #pages > 100, tostring(#pages) .. " found")

do
  local kinds = {}
  for _, page in ipairs(pages) do kinds[page.kind] = (kinds[page.kind] or 0) + 1 end
  check("it finds every kind of writing this project has",
        (kinds.document or 0) > 0 and (kinds.note or 0) > 0 and
        (kinds.issue or 0) > 0 and (kinds.source or 0) > 0 and
        (kinds.carried or 0) > 0 and (kinds.strategem or 0) > 0,
        "documents " .. tostring(kinds.document) .. ", notes " .. tostring(kinds.note) ..
        ", tickets " .. tostring(kinds.issue) .. ", source " .. tostring(kinds.source) ..
        ", carried " .. tostring(kinds.carried))

  -- The instruction the machine wakes up holding is not in docs/, and the first
  -- build of this site could not see it for exactly that reason.
  local found_instruction = false
  for _, page in ipairs(pages) do
    if page.name == "081-the-instruction" then found_instruction = true end
  end
  check("what the seed carries is included, not only what was written about it",
        found_instruction)

  local relative = true
  for _, page in ipairs(pages) do
    if page.source:sub(1, 1) == "/" then relative = false end
  end
  check("every page says where it came from, relative to the project",
        relative, "a root full of hyphens is not a pattern")
end

do
  local resolve, collisions, missing = site.resolver(pages)

  local ticket = resolve("502")
  check("a bare number reaches the ticket it names",
        ticket ~= nil and ticket.name:match("^502"), ticket and ticket.name)

  local named = resolve("144-assemble-a-machine")
  check("a full name reaches the source page it names",
        named ~= nil and named.kind == "source", named and named.kind)

  local with_extension = resolve("018-launch-board.lua")
  check("a name written with its extension reaches the same page",
        with_extension ~= nil and with_extension.name == "018-launch-board")

  local from_path = resolve("docs/011-roadmap.md")
  check("a path, as a table of contents writes it, reaches the document",
        from_path ~= nil and from_path.name == "011-roadmap")

  -- The documented rule, checked rather than trusted: where a ticket and a
  -- source file share a number, the ticket wins.
  local contested = resolve("105")
  check("where a ticket and a program share a number, the ticket wins",
        contested ~= nil and contested.kind == "issue", contested and contested.kind)
  check("and the program is still reachable by its full name",
        resolve("105-the-watchdog") ~= nil)
  check("every collision is reported rather than settled quietly",
        #collisions > 0, tostring(#collisions))

  resolve("999")
  check("a reference to nothing is counted rather than invented",
        missing["999"] == 1)
  resolve("an ordinary phrase")
  check("a code span that is not shaped like a reference is not counted",
        missing["an ordinary phrase"] == nil)
end

-- {{{ nothing in the project points at something that is not there
-- The first build of the site reported eight, every one of them a document still
-- describing something that had been removed. They were corrected rather than
-- excused, so this is allowed to be strict: any new one is a document that needs
-- fixing, and what the removed thing used to be is in the commit history.
do
  -- The counter has to belong to the resolver being called. The first version of
  -- this made a second resolver and read ITS counter while calling the first, so
  -- the count was always zero and the check passed while the build reported a
  -- dangling reference. A check that cannot fail is worse than no check, which is
  -- this project's own finding arriving in its own test suite.
  local resolve, _, missing = site.resolver(pages)
  for _, page in ipairs(pages) do
    for span in page.text:gmatch("`([^`\n]+)`") do resolve(span) end
  end

  -- Proof the counter above is live, so that "none missing" means none rather
  -- than meaning nothing was counted.
  resolve("997-a-document-that-is-not-here")
  check("the counter this check reads is the one being written to",
        missing["997-a-document-that-is-not-here"] == 1)
  missing["997-a-document-that-is-not-here"] = nil

  local unreachable = {}
  for reference in pairs(missing) do unreachable[#unreachable + 1] = reference end
  table.sort(unreachable)
  check("every reference in every document reaches something",
        #unreachable == 0, table.concat(unreachable, " "))
end
-- }}}

say("")
say("  the built site")
say("")

-- {{{ build it somewhere disposable and read everything back
do
  local out = DIR .. "/tmp/shared-memory/site-check"
  os.execute("rm -rf " .. out)
  local report, why = site.build(DIR, out, true)
  check("it builds", report ~= nil, why)

  if report then
    check("it writes a page for every document, and two more",
          report.pages == #pages + 2,
          tostring(report.pages) .. " against " .. tostring(#pages + 2))

    local listing = io.popen("ls -1 " .. out .. "/*.html 2>/dev/null | wc -l")
    local written = tonumber(listing:read("*a")) or 0
    listing:close()
    check("the pages are on the disk", written == report.pages,
          tostring(written) .. " files")

    local style = io.open(out .. "/style.css", "r")
    check("the look is written beside them", style ~= nil)
    if style then style:close() end

    -- {{{ every page is closed properly
    -- The check that would have caught the unbalanced list, and the reason it
    -- reads all of them: one broken page in two hundred is invisible.
    local VOID = { br = true, hr = true, img = true, input = true,
                   link = true, meta = true, area = true }
    local unbalanced, first_trouble = 0, nil
    local pipe = io.popen("ls -1 " .. out .. "/*.html")
    for path in pipe:lines() do
      local handle = io.open(path, "r")
      local text = handle:read("*a")
      handle:close()
      text = text:gsub("<script.-</script>", "")

      local stack, trouble = {}, nil
      for closing, name in text:gmatch("<(/?)([%a][%w]*)") do
        name = name:lower()
        if not VOID[name] then
          if closing == "/" then
            if #stack == 0 then
              trouble = trouble or ("closed " .. name .. " with nothing open")
            elseif stack[#stack] ~= name then
              trouble = trouble or ("closed " .. name .. " inside " .. stack[#stack])
            else
              stack[#stack] = nil
            end
          else
            stack[#stack + 1] = name
          end
        end
      end
      if #stack > 0 and not trouble then
        trouble = "left open: " .. table.concat(stack, ", ")
      end
      if trouble then
        unbalanced = unbalanced + 1
        first_trouble = first_trouble or (path:match("[^/]+$") .. ": " .. trouble)
      end
    end
    pipe:close()
    check("every page is closed properly", unbalanced == 0,
          first_trouble or "")
    -- }}}

    -- {{{ the links go somewhere
    -- A site whose pages exist and whose links do not is worse than no site,
    -- because the failure is only found by clicking.
    local broken, example = 0, nil
    local checked = 0
    local pages_pipe = io.popen("ls -1 " .. out .. "/*.html")
    for path in pages_pipe:lines() do
      local handle = io.open(path, "r")
      local text = handle:read("*a")
      handle:close()
      for target in text:gmatch('href="([^"#]+)"') do
        if not target:match("^%a+:") then
          checked = checked + 1
          local exists = io.open(out .. "/" .. target, "r")
          if exists then exists:close() else
            broken = broken + 1
            example = example or (path:match("[^/]+$") .. " → " .. target)
          end
        end
      end
    end
    pages_pipe:close()
    check("every link on every page reaches a file that exists",
          broken == 0, example)
    check("there are a great many of them", checked > 5000, tostring(checked))
    -- }}}
  end

  os.execute("rm -rf " .. out)
end
-- }}}

-- {{{ the drawings
do
  local bars = house.stacked_bars({
    { label = "one", parts = { { value = 3, colour = "red", name = "a" },
                               { value = 1, colour = "blue", name = "b" } } },
  })
  check("a chart is drawn as shapes, with its numbers readable",
        bars:find("<svg") ~= nil and bars:find("<title>a: 3</title>") ~= nil, bars)

  local ranked = house.ranked_bars({ { label = "a document", value = 40 } })
  check("the other chart draws too", ranked:find("<rect") ~= nil)
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")

os.execute("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("the documentation site: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
