#!/usr/bin/env luajit
-- 147-describe-the-source.lua
--
-- Reads a source file and writes the info document that belongs beside it.
--
-- For a general: every source file in this project is supposed to have a short
-- companion page saying what it offers, so a reader can learn what a file does
-- without reading the code. Most of them did not have one. This makes them --
-- not by inventing prose, but by lifting the prose the source file already
-- carries in its own comments, which is the only version that cannot drift.
--
-- WHY IT IS A TOOL AND NOT SEVENTY-EIGHT DOCUMENTS. A page written by hand
-- starts accurate and decays, and nobody notices, because nothing reads it.
-- A page derived from the comments is wrong only when the comments are wrong,
-- and the comments sit where somebody changing the code is already looking.
-- So the way to improve a generated page is to improve the source's header,
-- which is the outcome worth having anyway.
--
-- WHAT IT WILL NOT DO. It will not overwrite a page somebody wrote by hand.
-- Forty-seven of these existed before this file did and they are better than
-- anything derivable -- they say why a thing exists and what it deliberately
-- refuses to know, which is not in any signature. Those are left alone unless
-- --force is passed, and --force is not used by anything that runs unattended.
--
-- WHAT IT READS, AND THE CONVENTIONS IT DEPENDS ON. This project writes its
-- source files the same way everywhere, and that regularity is the whole reason
-- this is possible:
--
--   * a title line, `-- NNN-name.lua`, right after the shebang
--   * a prose header in comments, ending at the first line of real code
--   * paragraphs inside that header which OPEN WITH A CAPITALISED PHRASE when
--     they are making a separate point -- those become the page's sections
--   * `usage:` inside the header, followed by indented command lines
--   * exported things wrapped in vimfolds: `-- {{{ M.name(arguments)`, then
--     comment lines describing it, then the definition
--   * `return M` at the end of anything meant to be called by another file
--
-- If a file breaks those conventions the page comes out thin rather than wrong,
-- and a thin page is a signal about the source rather than a defect here.
--
-- usage:
--   luajit 147-describe-the-source.lua --all              every file missing one
--   luajit 147-describe-the-source.lua --all --force      every file, rewritten
--   luajit 147-describe-the-source.lua --file src/144-assemble-a-machine.lua
--   luajit 147-describe-the-source.lua --all --dry-run    say what would be made
--
-- library:
--   local describe = dofile(DIR .. "/src/147-describe-the-source.lua")
--   local page = describe.read("/path/to/018-launch-board.lua")
--   local text = describe.render(page)

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local M = {}

-- {{{ local function read_lines(path)
-- Returns the file as a list of lines, or nil if it is not there. Nil rather
-- than an error because a caller sweeping a directory meets deleted files.
local function read_lines(path)
  local handle = io.open(path, "r")
  if not handle then return nil end
  local lines = {}
  for line in handle:lines() do lines[#lines + 1] = line end
  handle:close()
  return lines
end
-- }}}

-- {{{ local function strip_comment(line)
-- One source line to the text inside its comment, or nil if it is not one.
-- `--` alone becomes an empty string, which is how paragraphs are separated.
local function strip_comment(line)
  local body = line:match("^%s*%-%-%-?%s?(.*)$")
  if not body then return nil end
  return (body:gsub("%s+$", ""))
end
-- }}}

-- {{{ local function paragraphs_of(lines)
-- A list of comment lines to a list of paragraphs, each a list of lines.
-- Blank comment lines separate them; runs of blanks do not make empty ones.
local function paragraphs_of(lines)
  local out, current = {}, {}
  for _, text in ipairs(lines) do
    if text == "" then
      if #current > 0 then out[#out + 1] = current ; current = {} end
    else
      current[#current + 1] = text
    end
  end
  if #current > 0 then out[#out + 1] = current end
  return out
end
-- }}}

-- {{{ local function opening_phrase(paragraph)
--
-- If a paragraph opens with a capitalised phrase -- the way this project writes
-- a point it wants set apart -- returns that phrase and the rest of the text.
-- Otherwise returns nil.
--
-- The rule is deliberately narrow: at least two consecutive words in capitals
-- at the very start, ending at the first full stop, comma or dash. One capital
-- word is an ordinary sentence beginning with a name and must not be caught,
-- which is why the threshold is two and not one.
local function opening_phrase(paragraph)
  local joined = table.concat(paragraph, " ")
  -- Commas and digits stay inside the run, so "WHY IT IS A FILE OF ITS OWN, AS
  -- OF 2026-08-22." keeps its whole clause as the heading instead of leaving
  -- the date shouting at the top of the body.
  local head = joined:match("^([A-Z][A-Z0-9'%-]*%s+[A-Z][A-Z0-9'%-]*[A-Z0-9%s',%-]*)")
  if not head then return nil end

  -- The run ends at the first full stop; trailing punctuation is the sentence's
  -- rather than the heading's.
  head = head:gsub("[%s,%-]+$", "")
  local words = 0
  for _ in head:gmatch("%S+") do words = words + 1 end
  if words < 2 then return nil end

  local rest = joined:sub(#head + 1)
  rest = rest:gsub("^[%.,%-–—:%s]+", "")

  -- A capitalised run that swallowed the whole paragraph is a shout, not a
  -- heading, and a heading with nothing under it is worse than no heading.
  if rest == "" then return nil end

  -- Headings read better in sentence case; the source shouts for emphasis in a
  -- plain-text file, and this page has real headings to do that job.
  local pretty = head:sub(1, 1) .. head:sub(2):lower()
  return pretty, rest
end
-- }}}

-- {{{ local function collect_usage(paragraph)
-- A `usage:` paragraph to the command lines under it. The lines are indented in
-- the source and the indent is not meaningful here, so it is removed.
local function collect_usage(paragraph)
  local commands = {}
  for index = 2, #paragraph do
    local text = paragraph[index]:gsub("^%s+", "")
    if text ~= "" then commands[#commands + 1] = text end
  end
  return commands
end
-- }}}

-- {{{ M.read(path)
--
-- One source file to a description of it. Returns a table:
--
--   name      "144-assemble-a-machine", the filename without .lua
--   index     144, the number it sorts by
--   kind      "library" if the file ends in `return M`, else "program"
--   summary   the header's first paragraph, as one string
--   sections  a list of { heading, body } lifted from capitalised paragraphs
--   notes     paragraphs that were not headed and not usage, as strings
--   usage     command lines from the header's `usage:` block
--   exports   a list of { signature, description, inline } from the vimfolds
--   issues    issue numbers the header mentions, in order, without repeats
--
-- Returns nil and a reason when the file cannot be read or carries no title
-- line, because a file that does not follow the shape is not one this can
-- describe and saying so is better than emitting an empty page.
function M.read(path)
  local lines = read_lines(path)
  if not lines then return nil, "cannot read " .. path end

  local page = { path = path, sections = {}, notes = {},
                 usage = {}, exports = {}, issues = {} }

  -- {{{ the title line, which also gives the name and the sort order
  local start = 1
  for index = 1, math.min(#lines, 4) do
    -- Nothing anchors the end, because a title line may carry a note after the
    -- filename -- the recorded fixture's says "generated; do not edit" there,
    -- and refusing it left the one file in assets/ without a page.
    local name = lines[index]:match("^%-%-%s*(%d+[a-z]?%-[%w%-%.]-)%.lua")
    if name then
      page.name = name
      page.index = tonumber(name:match("^(%d+)"))
      start = index + 1
      break
    end
  end
  if not page.name then return nil, "no title line in " .. path end
  -- }}}

  -- {{{ the header block -- comments until the first line of real code
  local header = {}
  for index = start, #lines do
    local text = strip_comment(lines[index])
    -- A fold marker ends the header even though it is still a comment. Without
    -- this the header runs on into the first fold's own commentary -- which in
    -- a program is the note about the hard-coded project root, and it appeared
    -- on seventy pages as though it were something the file wanted to say.
    if text and (text:match("^{{{") or text:match("^}}}")) then
      break
    elseif text then
      header[#header + 1] = text
    elseif lines[index]:match("^%s*$") then
      -- A blank line inside the header is ordinary; one after it has ended is
      -- the gap before the code, and the loop below stops on the code itself.
      header[#header + 1] = ""
    else
      break
    end
  end
  -- }}}

  -- {{{ the header's paragraphs, sorted into summary, usage, sections, notes
  local blocks = paragraphs_of(header)
  for order, paragraph in ipairs(blocks) do
    local first = paragraph[1] or ""
    if order == 1 then
      page.summary = table.concat(paragraph, " ")
    elseif first:match("^usage:") then
      page.usage = collect_usage(paragraph)
    elseif first:match("^library:") then
      page.library_usage = collect_usage(paragraph)
    elseif first:match("^For a general:") then
      -- The plainest sentence in the file, and it belongs directly under the
      -- summary rather than at the bottom with the leftovers. The prefix is an
      -- instruction to whoever wrote it, not something a reader needs.
      -- The sentence continued from the prefix, so it starts in lower case and
      -- has to be stood back up now that the prefix is gone.
      local plainly = table.concat(paragraph, " "):gsub("^For a general:%s*", "")
      page.plainly = plainly:sub(1, 1):upper() .. plainly:sub(2)
    else
      local heading, body = opening_phrase(paragraph)
      if heading then
        page.sections[#page.sections + 1] = { heading = heading, body = body }
      else
        page.notes[#page.notes + 1] = table.concat(paragraph, " ")
      end
    end
  end
  -- }}}

  -- {{{ the exports -- every vimfold that opens on something the file returns
  -- The fold marker is the signature. Everything commented under it, up to the
  -- definition, is the description -- which is where this project puts the
  -- arguments, the registers and the refusals.
  local index = 1
  while index <= #lines do
    local marker = lines[index]:match("^%-%-%s*{{{%s+(M%.[^%s].*)$")
    if marker then
      local signature, inline = marker, nil
      local cut, tail = marker:match("^(.-)%s+%-%-%s+(.+)$")
      if cut then signature, inline = cut, tail end

      local body = {}
      local scan = index + 1
      while scan <= #lines do
        local text = strip_comment(lines[scan])
        if not text then break end
        body[#body + 1] = text
        scan = scan + 1
      end

      -- What a thing hands back is the single most useful sentence about it and
      -- this project writes it the same way everywhere, so it is worth pulling
      -- out on its own for the summary table.
      local returns
      for _, text in ipairs(body) do
        local found = text:match("^(Returns%s+.+)$")
        if found then returns = found ; break end
      end

      page.exports[#page.exports + 1] = {
        signature = signature,
        inline = inline,
        returns = returns,
        description = table.concat(paragraphs_of(body)[1] or {}, " "),
        detail = body,
      }
      index = scan
    else
      index = index + 1
    end
  end
  -- }}}

  -- {{{ the fields, for a file that is a description rather than a module
  --
  -- Board descriptions and other data files return a table literal and export
  -- nothing, so a page built only from vimfolds comes out empty. What a reader
  -- wants from those is the fields and what each one is for, and the values are
  -- the documentation -- a board that says its console is a PL011 at a
  -- particular address has said the useful thing already.
  --
  -- Two levels deep, because the second level is where boards keep the parts
  -- somebody actually looks up: the boot path, the controller, the firmware.
  if #page.exports == 0 then
    local depth, pending = 0, {}
    for _, raw in ipairs(lines) do
      local text = strip_comment(raw)
      if text and depth >= 1 then
        if text ~= "" and not text:match("^{{{") then pending[#pending + 1] = text end
      elseif not text then
        if depth >= 1 then
          local name, value = raw:match("^%s*([%w_]+)%s*=%s*(.-),?%s*$")
          if name then
            if value:match("^{") and not value:match("}") then value = "a table below" end
            if value == "" then value = "a table below" end
            page.fields = page.fields or {}
            page.fields[#page.fields + 1] = {
              name = name, value = value, depth = depth,
              note = #pending > 0 and table.concat(pending, " ") or nil,
            }
          end
          pending = {}
        end
        -- Depth is counted after the line is read, so the `return {` line itself
        -- is not mistaken for a field and the closing brace ends the run.
        local _, opens = raw:gsub("{", "")
        local _, closes = raw:gsub("}", "")
        depth = depth + opens - closes
        if depth < 0 then depth = 0 end
      end
    end
  end
  -- }}}

  -- {{{ the kind, and the issue numbers the header claims
  page.kind = "program"
  for _, line in ipairs(lines) do
    if line:match("^return M%s*$") then page.kind = "library" ; break end
  end

  local seen = {}
  local whole = table.concat(header, " ")
  for number in whole:gmatch("[Ii]ssues?%s+`?(%d%d%d[a-z]?)`?") do
    if not seen[number] then seen[number] = true ; page.issues[#page.issues + 1] = number end
  end
  for number in whole:gmatch("%(issue%s+`?(%d%d%d[a-z]?)`?%)") do
    if not seen[number] then seen[number] = true ; page.issues[#page.issues + 1] = number end
  end
  -- }}}

  return page
end
-- }}}

-- {{{ M.checked_by(dir, name)
--
-- Which test programs mention this file by name. Derived by looking rather than
-- by being told, because a list of tests written into a comment is a list that
-- stops being true the first time somebody adds one.
--
-- Returns a list of test file names, without the .lua.
function M.checked_by(dir, name)
  local found, seen = {}, {}
  local pipe = io.popen("grep -l '" .. name .. "' " .. dir .. "/src/*test*.lua 2>/dev/null")
  if not pipe then return found end
  for line in pipe:lines() do
    local test = line:match("([^/]+)%.lua$")
    if test and test ~= name and not seen[test] then
      seen[test] = true
      found[#found + 1] = test
    end
  end
  pipe:close()
  table.sort(found)
  return found
end
-- }}}

-- {{{ M.render(page, checked_by)
--
-- A description to the markdown of its info document. The shape follows the
-- pages that were written by hand: what it is, how it is called, what it
-- offers, then whatever the source had to say about itself.
function M.render(page, checked_by)
  local out = {}
  local function line(text) out[#out + 1] = text or "" end

  line("# " .. page.name .. " — info")
  line()
  line(page.summary or "No summary; the source file's header does not open with one.")
  line()
  if page.plainly then
    line(page.plainly)
    line()
  end

  -- Said once, at the top, because somebody who edits this file instead of the
  -- source will lose their work the next time the sweep runs.
  line("*Lifted from this file's own comments by `147`. To change this page,")
  line("change the comments in `" .. page.name .. ".lua` and run the sweep again.*")
  line()

  -- {{{ how it is called
  if #page.usage > 0 or #(page.library_usage or {}) > 0 then
    line("## Invocation")
    line()
    if #page.usage > 0 then
      line("```")
      for _, command in ipairs(page.usage) do line(command) end
      line("```")
      line()
    end
    if page.library_usage and #page.library_usage > 0 then
      line("```lua")
      for _, command in ipairs(page.library_usage) do line(command) end
      line("```")
      line()
    end
  elseif page.kind == "library" then
    line("## Invocation")
    line()
    line("```lua")
    line("local it = dofile(DIR .. \"/src/" .. page.name .. ".lua\")")
    line("```")
    line()
  end
  -- }}}

  -- {{{ what it offers
  if #page.exports > 0 then
    line("## What it offers")
    line()
    line("| | What it is |")
    line("|---|---|")
    for _, export in ipairs(page.exports) do
      -- A parameter list is aligned text, and flattening it into a table cell
      -- produces a run of words with the alignment gone and the meaning with
      -- it. Those are recognised by their internal runs of spaces and sent to
      -- the detail section below, where the alignment survives.
      local blurb = export.inline or export.description or ""
      if blurb:match("^options:") or blurb:match("%S%s%s+%S") then
        blurb = export.returns or "described below"
      end
      blurb = blurb:gsub("|", "\\|")
      -- One sentence in a table cell; the rest of the paragraph is below.
      local stop = blurb:find("%.%s")
      if stop and stop > 30 then blurb = blurb:sub(1, stop) end
      if #blurb > 150 then blurb = blurb:sub(1, 147) .. "..." end
      line("| `" .. export.signature:gsub("|", "\\|") .. "` | " .. blurb .. " |")
    end
    line()

    -- The table is for finding something; this is for understanding it. Only
    -- the ones whose comments said more than the table could hold appear here.
    local wrote_heading = false
    for _, export in ipairs(page.exports) do
      local detail = table.concat(export.detail, "\n")
      if #export.detail > 1 and #detail > 120 then
        if not wrote_heading then
          line("### In more detail")
          line()
          wrote_heading = true
        end
        line("**`" .. export.signature .. "`**")
        line()

        -- Leading blank comment lines are the gap under a fold marker, not part
        -- of what was written.
        local body, started = {}, false
        for _, text in ipairs(export.detail) do
          if text ~= "" then started = true end
          if started then body[#body + 1] = text end
        end
        while #body > 0 and body[#body] == "" do body[#body] = nil end

        -- Aligned text -- parameter lists, register assignments, tables -- loses
        -- its meaning when a markdown renderer reflows it, so anything holding
        -- an internal run of spaces is fenced whole rather than reflowed.
        local aligned = false
        for _, text in ipairs(body) do
          if text:match("%S%s%s+%S") then aligned = true ; break end
        end

        if aligned then line("```") end
        for _, text in ipairs(body) do line(text) end
        if aligned then line("```") end
        line()
      end
    end
  end
  -- }}}

  -- {{{ what it describes, for a data file
  if page.fields and #page.fields > 0 then
    line("## What it describes")
    line()
    line("| Field | Value | |")
    line("|---|---|---|")
    for _, field in ipairs(page.fields) do
      local name = field.depth > 1 and ("&nbsp;&nbsp;↳ `" .. field.name .. "`")
                                    or ("`" .. field.name .. "`")
      local value = field.value:gsub("|", "\\|")
      if #value > 60 then value = value:sub(1, 57) .. "..." end
      local note = (field.note or ""):gsub("|", "\\|")
      if #note > 120 then note = note:sub(1, 117) .. "..." end
      line("| " .. name .. " | `" .. value .. "` | " .. note .. " |")
    end
    line()
  end
  -- }}}

  -- {{{ whatever the source had to say about itself
  for _, section in ipairs(page.sections) do
    line("## " .. section.heading)
    line()
    line(section.body)
    line()
  end

  if #page.notes > 0 then
    line("## Worth knowing")
    line()
    for _, note in ipairs(page.notes) do
      line(note)
      line()
    end
  end
  -- }}}

  -- {{{ where it sits -- the issues it belongs to, the tests that check it
  if #page.issues > 0 or (checked_by and #checked_by > 0) then
    line("## Where it sits")
    line()
    if #page.issues > 0 then
      local marked = {}
      for _, number in ipairs(page.issues) do marked[#marked + 1] = "`" .. number .. "`" end
      line("**Belongs to** " .. table.concat(marked, ", ") .. ".")
      line()
    end
    if checked_by and #checked_by > 0 then
      local marked = {}
      for _, test in ipairs(checked_by) do marked[#marked + 1] = "`" .. test .. "`" end
      line("**Checked by** " .. table.concat(marked, ", ") .. ".")
      line()
    end
  end
  -- }}}

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.sweep(dir, options)
--
-- Every source file in the project, described. options.force rewrites pages
-- that already exist; without it, hand-written pages are left alone.
-- options.dry_run says what would happen and writes nothing.
--
-- Returns counts: made, skipped, refused -- and the list of refusals, because
-- a file this cannot describe is a file worth looking at by hand.
function M.sweep(dir, options)
  options = options or {}
  local result = { made = 0, skipped = 0, refused = 0, refusals = {} }

  -- Both directories that hold code. assets/ holds things the seed carries
  -- rather than things that build it -- the recorded answer the arithmetic is
  -- checked against lives there -- and it is referred to by number in the same
  -- way, so a reader following a reference needs it to have a page like the rest.
  local listing = io.popen("ls " .. dir .. "/src/*.lua " .. dir .. "/assets/*.lua 2>/dev/null")
  if not listing then return result end

  for path in listing:lines() do
    local name = path:match("([^/]+)%.lua$")
    -- The page sits beside the file it describes, wherever that is.
    local info_path = path:gsub("%.lua$", ".info.md")

    -- Three states, not two, and the difference is what makes this safe to run
    -- unattended: no page at all, a page this wrote, and a page a person wrote.
    -- The first two are ours to write; the third is not, and is recognised by
    -- the absence of the line the renderer stamps into everything it makes.
    local mine, exists = false, false
    local handle = io.open(info_path, "r")
    if handle then
      exists = true
      mine = handle:read("*a"):find("own comments by `147`", 1, true) ~= nil
      handle:close()
    end

    if exists and not mine and not options.force then
      result.skipped = result.skipped + 1
    else
      local page, why = M.read(path)
      if not page then
        result.refused = result.refused + 1
        result.refusals[#result.refusals + 1] = (why or name)
      else
        local text = M.render(page, M.checked_by(dir, name))
        if options.dry_run then
          io.write("would write ", info_path, "\n")
        else
          local handle = io.open(info_path, "w")
          if not handle then
            result.refused = result.refused + 1
            result.refusals[#result.refusals + 1] = "cannot write " .. info_path
          else
            handle:write(text, "\n")
            handle:close()
          end
        end
        result.made = result.made + 1
      end
    end
  end
  listing:close()
  return result
end
-- }}}

-- {{{ the command line
-- Only when run directly. Required as a library by the HTML build, which wants
-- the reading and not the writing.
if arg and arg[0] and arg[0]:match("147%-describe%-the%-source") then
  local one_file, force, dry_run, do_all = nil, false, false, false

  local index = 1
  while index <= #arg do
    local word = arg[index]
    if word == "--dir" then index = index + 1 ; DIR = arg[index]
    elseif word == "--file" then index = index + 1 ; one_file = arg[index]
    elseif word == "--force" then force = true
    elseif word == "--dry-run" then dry_run = true
    elseif word == "--all" then do_all = true
    else
      io.write("147-describe-the-source: unknown option ", word, "\n")
      os.exit(1)
    end
    index = index + 1
  end

  if one_file then
    local page, why = M.read(one_file)
    if not page then io.write("147: ", why, "\n") ; os.exit(1) end
    local text = M.render(page, M.checked_by(DIR, page.name))
    if dry_run then
      io.write(text, "\n")
    else
      local target = DIR .. "/src/" .. page.name .. ".info.md"
      local handle = io.open(target, "w")
      handle:write(text, "\n")
      handle:close()
      io.write("wrote ", target, "\n")
    end
  elseif do_all then
    local result = M.sweep(DIR, { force = force, dry_run = dry_run })
    io.write("\n")
    io.write("  described:  ", result.made, "\n")
    io.write("  left alone: ", result.skipped, "  (written by hand; --force to rewrite)\n")
    if result.refused > 0 then
      io.write("  refused:    ", result.refused, "\n")
      for _, why in ipairs(result.refusals) do io.write("    ", why, "\n") end
    end
    io.write("\n")
  else
    io.write("147-describe-the-source: name --all or --file; nothing was done\n")
    os.exit(1)
  end
end
-- }}}

return M
