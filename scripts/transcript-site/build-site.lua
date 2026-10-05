-- build-site.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Writes one project's transcript site, and says what it saw doing it. The
-- only file in the library that loads more than one of its parts.
--
-- In general terms: the library has three parts that never meet -- the
-- conversation page (conversation/), the table of contents (contents/) and
-- the films (films/). This file reads a project's transcripts once, hands
-- each part the plain tables it needs, and puts the files they make where the
-- project's settings say:
--
--   <output>/fonts/              the shipped monospace
--   <output>/films/              every film some message uses (when filmed)
--   <output>/<pages>/index.html  the table of contents
--   <output>/<pages>/<name>.html one page per transcript, named as it is
--
-- Used two ways. As a command, by build-transcript-pages:
--
--   luajit build-site.lua <project-dir> [<settings-file>]
--
-- and as a module, by a project that writes pages of its own around these
-- (double-diaper-dungeon's age gate and game pages):
--
--   local site = dofile(".../transcript-site/build-site.lua")
--   local report = site.build(settings)     -- settings from settings.lua
--   site.print_report(report)
--
-- IT REDACTS NOTHING AND REPORTS EVERYTHING. A fenced code block longer than
-- the threshold is counted and listed, never cut. A development record's
-- value is the reasoning together with the code it produced, so cutting the
-- code leaves an argument about something the reader cannot see; and a page
-- that quietly removed content would be the silent fallback the house rules
-- exist to prevent.
--
-- IT STOPS RATHER THAN LIMPS. A transcript that cannot be read ends the
-- build: the exporter's format moved, and skipping it would publish a site
-- quietly missing a conversation.

local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

local M = {}

-- A fenced block longer than this is worth mentioning. Not a limit anything
-- acts on: a number above which a person should glance at what went out.
M.WORTH_MENTIONING = 200

-- The parts, and the settings reader.
local reader = dofile(HERE .. "conversation/transcript-reader.lua")
local page = dofile(HERE .. "conversation/conversation-page.lua")
local history = dofile(HERE .. "contents/commit-history.lua")
local attribution = dofile(HERE .. "contents/attribution.lua")
local contents_page = dofile(HERE .. "contents/contents-page.lua")
local settings_reader = dofile(HERE .. "settings.lua")

-- The films are loaded only for a project that has them, so a project
-- without films never needs their libraries to load.
local function films_part()
  return dofile(HERE .. "films/film-matcher.lua"), dofile(HERE .. "films/film-describer.lua")
end

-- {{{ local function slurp()
local function slurp(path)
  local file = io.open(path, "r")
  if not file then
    error("cannot read " .. path)
  end
  local text = file:read("*a")
  file:close()
  return text
end
-- }}}

-- {{{ local function spit()
-- Writes a file, and refuses rather than carries on if it cannot. A build
-- that could not write one page and finished anyway would leave a site with a
-- hole in it and an exit code saying all was well.
local function spit(path, text)
  local file = io.open(path, "w")
  if not file then
    error("cannot write " .. path)
  end
  file:write(text)
  file:close()
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
  return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function lines_of()
-- Runs a read-only command and returns its output lines.
local function lines_of(command)
  local pipe = assert(io.popen(command, "r"))
  local out = {}
  for line in pipe:lines() do out[#out + 1] = line end
  pipe:close()
  return out
end
-- }}}

-- {{{ local function run()
-- Runs a command that changes files, and raises when it fails.
local function run(command, what)
  local ok = os.execute(command)
  if not (ok == true or ok == 0) then
    error("could not " .. what)
  end
end
-- }}}

-- {{{ local function count_oversized()
-- Finds fenced code blocks longer than the threshold, so the run can list
-- them. Counts only; changes nothing.
local function count_oversized(conversation, name, found)
  for _, exchange in ipairs(conversation.exchanges) do
    local inside, lines, language = false, 0, nil
    for line in (exchange.body .. "\n"):gmatch("([^\n]*)\n") do
      local fence, tag = line:match("^(```+)(.*)$")
      if fence then
        if inside then
          if lines > M.WORTH_MENTIONING then
            found[#found + 1] = { file = name, lines = lines, language = language }
          end
          inside, lines, language = false, 0, nil
        else
          inside = true
          language = (tag ~= "" and tag) or nil
        end
      elseif inside then
        lines = lines + 1
      end
    end
  end
end
-- }}}

-- {{{ function M.shape()
-- A conversation as this project draws it: its two switches applied.
--
--   harness_lines false: the turn of lines above the first request is taken
--     out, BEFORE anything numbers the turns, so the page's turn ids and the
--     films' choices both count only the turns that are drawn;
--   recap_contents false: the Contents list is emptied, so the page draws
--     none and carries none of its rules.
--
-- Used by the build and by the film matcher both, which is what keeps the
-- two in step.
function M.shape(conversation, settings)
  if not settings.harness_lines then
    local kept = {}
    for _, exchange in ipairs(conversation.exchanges) do
      if exchange.kind ~= "harness" then
        kept[#kept + 1] = exchange
      end
    end
    conversation.exchanges = kept
  end
  if not settings.recap_contents then
    conversation.contents = {}
  end
  return conversation
end
-- }}}

-- {{{ function M.read_transcripts()
-- Every transcript in the project's transcripts folder, read and shaped,
-- sorted by name so two runs over an unchanged folder make the same site.
--
-- Returns two lists: the transcripts, each { name, text, conversation }; and
-- the names of files that are not transcripts. Three outcomes per file: no
-- transcript header, so not a transcript -- a word cloud, a note -- left
-- alone and listed; read, and kept; or a transcript that does NOT read, which
-- stops everything (see the header).
function M.read_transcripts(settings)
  local paths = lines_of("find " .. shell_quote(settings.transcripts)
    .. " -maxdepth 1 -name '*.md' -type f")
  table.sort(paths)
  local transcripts, not_transcripts = {}, {}
  for _, path in ipairs(paths) do
    local name = path:match("([^/]+)$")
    local text = slurp(path)
    if not text:match("^# Conversation Summary: ") then
      not_transcripts[#not_transcripts + 1] = name
    else
      local ok, conversation = pcall(reader.read, text)
      if not ok then
        error("cannot read " .. name .. "\n  " .. tostring(conversation))
      end
      transcripts[#transcripts + 1] = {
        name = name, text = text, conversation = M.shape(conversation, settings),
      }
    end
  end
  return transcripts, not_transcripts
end
-- }}}

-- {{{ local function inside()
-- The path of `folder` written from `base`, or nil when it is not inside it.
local function inside(folder, base)
  if folder == base then
    return ""
  end
  if folder:sub(1, #base + 1) == base .. "/" then
    return folder:sub(#base + 2)
  end
  return nil
end
-- }}}

-- {{{ function M.gather_evidence()
-- What the table of contents attributes commits by, from this project's
-- conversations: the commit lines each records (the first transcript in
-- name order wins a hash recorded twice), whether each is a main
-- conversation or a helper (a helper's session id begins "agent-"), and
-- which helpers each links to, since a helper's transcript saved in a commit
-- stands for its parent's.
--
-- The anchor each commit line carries comes from the conversation page's own
-- rule, handed over here, so the two parts agree on the name without knowing
-- each other.
--
-- `transcripts` is a list of { name, conversation }, in name order; `key_of`
-- turns a transcript's file name into its key. Returns the evidence table
-- attribution.lua reads. Public so a project's own tests can check the rules
-- the evidence is gathered by (double-diaper-dungeon's do).
function M.gather_evidence(transcripts, key_of)
  local evidence = { by_hash = {}, by_subject = {}, parent_of = {}, is_main = {} }
  local links = {}
  for _, transcript in ipairs(transcripts) do
    local key = key_of(transcript.name)
    local conversation = transcript.conversation
    evidence.is_main[key] = not conversation.session_id:match("^agent%-")
    for _, exchange in ipairs(conversation.exchanges) do
      for _, commit in ipairs(exchange.commits or {}) do
        local record = { key = key, anchor = page.commit_anchor(commit.hash), hash = commit.hash }
        local short = commit.hash:sub(1, 7)
        if not evidence.by_hash[short] then
          evidence.by_hash[short] = record
        end
        local same = evidence.by_subject[commit.subject] or {}
        same[#same + 1] = record
        evidence.by_subject[commit.subject] = same
      end
      for linked in exchange.body:gmatch("%]%(([^/%)]+%.md)%)") do
        links[#links + 1] = { from = key, to = key_of(linked) }
      end
    end
  end
  -- A helper's parent is the transcript that links to it; a link between two
  -- main conversations says nothing about who made what.
  for _, link in ipairs(links) do
    if evidence.is_main[link.to] == false then
      evidence.parent_of[link.to] = link.from
    end
  end
  return evidence
end
-- }}}

-- {{{ local function evidence_elsewhere()
-- A project that lives inside a larger repository (the ai-stuff monorepo)
-- has commits made from conversations filed under OTHER projects: a session
-- started at the repository's top commits to every project in it. Those
-- transcripts record the commits too, so every other llm-transcripts/ folder
-- in the repository, down to three levels, is read for commit lines -- only
-- those -- and a commit found there links to that project's pages.
--
-- Two paths: the history folder is its repository's top, and there is
-- nowhere else to look; or it is inside one, and the rest is searched. This
-- project's own transcripts win a tie: a record there is nearer the work.
local function evidence_elsewhere(settings, evidence, conversations)
  -- Asked of the history reader, which compares real paths: git names the
  -- top by its real path, and a settings path holding ".." or a symbolic
  -- link would otherwise never equal it -- the first version of this read 61
  -- "other projects'" commit lines out of a mirror that has no other projects.
  if history.is_repository_top(settings.history) then
    return 0
  end
  local top = lines_of("git -C " .. shell_quote(settings.history) .. " rev-parse --show-toplevel")[1]
  local project = lines_of("realpath " .. shell_quote(settings.history))[1]
  local found = 0
  local candidates = lines_of("grep -l -s '^\\*\\[commit\\] ' '" .. top .. "'/llm-transcripts/*.md '"
    .. top .. "'/*/llm-transcripts/*.md '" .. top .. "'/*/*/llm-transcripts/*.md")
  for _, path in ipairs(candidates) do
    if path:sub(1, #project + 1) ~= project .. "/" then
      local ok, other = pcall(reader.read, slurp(path))
      -- A transcript elsewhere that does not read is that project's build's
      -- problem to report; here it only means no evidence from it.
      if ok then
        -- The route from this project's pages up to the repository's top,
        -- then down into the other project's pages, which sit in the same
        -- place within it (its llm-transcripts/HTML/, the default).
        local pages_inside = inside(lines_of("realpath " .. shell_quote(settings.pages_folder))[1], top)
        local depth = select(2, (pages_inside or ""):gsub("[^/]+", ""))
        local other_dir = path:match("^(.*)/llm%-transcripts/[^/]+$"):sub(#top + 2)
        local href = ("../"):rep(depth) .. (other_dir ~= "" and (other_dir .. "/") or "")
          .. "llm-transcripts/HTML/" .. path:match("([^/]+)%.md$") .. ".html"
        local key = "elsewhere:" .. path
        conversations[key] = {
          href = href,
          title = path:match("([^/]+)%.md$"),
          summary = page.summary_line(reader.first_request(other), 96),
          elsewhere = other_dir ~= "" and other_dir or "the repository's top",
        }
        for _, exchange in ipairs(other.exchanges) do
          for _, commit in ipairs(exchange.commits or {}) do
            local short = commit.hash:sub(1, 7)
            if not evidence.by_hash[short] then
              evidence.by_hash[short] = { key = key, anchor = page.commit_anchor(commit.hash),
                                          hash = commit.hash }
            end
            found = found + 1
          end
        end
      end
    end
  end
  return found
end
-- }}}

-- {{{ local function recorded_elsewhere()
-- The commits that transcripts in the evidence_from folders record making
-- (issue 040), as a set of seven-character hashes. A commit only they
-- record was made from another project's conversation. A listed folder that
-- does not exist stops the build: a missing folder would quietly show those
-- commits again.
local function recorded_elsewhere(settings)
  local hashes = {}
  for _, folder in ipairs(settings.evidence_from) do
    local probe = io.open(folder, "r")
    if not probe then
      error("evidence_from names a folder that is not there: " .. folder)
    end
    probe:close()
    for _, path in ipairs(lines_of("find " .. shell_quote(folder) .. " -maxdepth 1 -name '*.md' -type f")) do
      local ok, conversation = pcall(reader.read, slurp(path))
      -- A transcript there that does not read is that folder's problem to
      -- report; here it only means no evidence from it.
      if ok then
        for _, exchange in ipairs(conversation.exchanges) do
          for _, commit in ipairs(exchange.commits or {}) do
            hashes[commit.hash:sub(1, 7)] = true
          end
        end
      end
    end
  end
  return hashes
end
-- }}}

-- {{{ local function nearest_heading()
-- The markdown heading at or above a line of a file, without its hashes, or
-- nil when there is none above it.
local function nearest_heading(file_lines, line_number)
  for n = math.min(line_number, #file_lines), 1, -1 do
    local heading = file_lines[n]:match("^#+%s+(.-)%s*$")
    if heading then return heading end
  end
  return nil
end
-- }}}

-- {{{ function M.hand_made_conversation()
-- A commit she made by hand, as a conversation in which she is the only
-- speaker (issue 040): for each file the commit touched, outside the
-- transcripts folder, a quiet "context" turn naming the file and the heading
-- above the lines, then a turn of HER lines -- only the lines that commit
-- added, never the file whole, so text an assistant wrote around her answers
-- is never put in her mouth.
--
-- `repository` is where the files are read from (nil: none can be, and the
-- page holds the commit message alone); `transcripts_name` is the
-- transcripts folder's name, whose files are left out.
function M.hand_made_conversation(commit, repository, transcripts_name)
  local exchanges = {}
  local function said(text) exchanges[#exchanges + 1] = { kind = "user", number = 1, body = text, continued = false } end
  local function where(text) exchanges[#exchanges + 1] = { kind = "context", body = text, continued = false } end

  if repository then
    local files = lines_of("git -C " .. shell_quote(repository) .. " show --format= --name-only "
      .. shell_quote(commit.source))
    for _, path in ipairs(files) do
      if path ~= "" and path:sub(1, #transcripts_name + 1) ~= transcripts_name .. "/" then
        local file_lines = lines_of("git -C " .. shell_quote(repository) .. " show "
          .. shell_quote(commit.source .. ":" .. path))
        local diff = lines_of("git -C " .. shell_quote(repository) .. " show --format= --unified=0 "
          .. shell_quote(commit.source) .. " -- " .. shell_quote(path))
        -- Walk the diff's hunks. Each "@@ ... +start ..." says where the
        -- added lines that follow begin in the file at this commit; a run of
        -- "+" lines is one block of her words.
        local blocks, current, next_line = {}, nil, nil
        for _, line in ipairs(diff) do
          local start = line:match("^@@ %-%d+,?%d* %+(%d+)")
          if start then
            next_line = tonumber(start)
            current = nil
          elseif line:sub(1, 1) == "+" and line:sub(1, 3) ~= "+++" and next_line then
            if not current then
              current = { first = next_line, lines = {} }
              blocks[#blocks + 1] = current
            end
            current.lines[#current.lines + 1] = line:sub(2)
            next_line = next_line + 1
          end
        end
        for _, block in ipairs(blocks) do
          local text = table.concat(block.lines, "\n")
          if text:match("%S") then
            local heading = nearest_heading(file_lines, block.first - 1)
            where("`" .. path .. "`" .. (heading and (", under \"" .. heading .. "\"") or ""))
            said(text)
          end
        end
      end
    end
  end
  if #exchanges == 0 then
    said(commit.body and (commit.subject .. "\n\n" .. commit.body) or commit.subject)
  end
  return { session_id = "by-hand-" .. commit.source:sub(1, 7), generated_on = commit.date,
           models = {}, header_complete = true, by_hand = true, contents = {}, exchanges = exchanges }
end
-- }}}

-- {{{ local function copy_fonts()
-- The pages ask for a font that sits in fonts/ at the site's root
-- (libs/page-head.lua says which files). Each file is copied when it is not
-- there yet. A copy that fails stops the build, since pages without their
-- font fall back silently to whatever the reader happens to own.
local function copy_fonts(settings)
  local page_head = dofile(HERE .. "libs/page-head.lua")
  local fonts_out = settings.output .. "/" .. page_head.FONT_DIR_NAME
  run("mkdir -p " .. shell_quote(fonts_out), "make " .. fonts_out)
  for _, file in ipairs(page_head.FONT_FILES) do
    local target = fonts_out .. "/" .. file
    local present = io.open(target, "rb")
    if present then
      present:close()
    else
      run("cp " .. shell_quote(settings.fonts .. "/" .. file) .. " " .. shell_quote(target),
        "copy the font " .. file .. " into " .. fonts_out)
    end
  end
end
-- }}}

-- {{{ function M.build()
-- Writes the whole site for one project's resolved settings, and returns a
-- report: a table of what it counted.
--
--   conversations     number of pages written
--   not_transcripts   list of file names left alone
--   commits           number of commits read
--   groups            number of groups on the table of contents
--   linked            number of commits whose button lands on a page
--   how               table: rule name -> number of commits it decided
--   elsewhere         number of commit lines read from other projects
--   films_used        number of films copied, or nil without films
--   films_unmatched   number of messages with no film chosen yet
--   oversized         list of { file, lines, language }
--   output            the site's root folder
function M.build(settings)
  local report = { how = {}, oversized = {}, output = settings.output }
  local transcripts, not_transcripts = M.read_transcripts(settings)
  if #transcripts == 0 then
    error(settings.transcripts .. " holds no transcripts")
  end
  report.not_transcripts = not_transcripts

  run("mkdir -p " .. shell_quote(settings.pages_folder), "make " .. settings.pages_folder)
  copy_fonts(settings)
  local colours_css = settings_reader.colours_css(settings)

  -- A transcript's key is its path as the history writes it, so a commit's
  -- list of touched files can be looked up directly; a transcripts folder
  -- outside the history folder has keys of its name alone, and the "saved"
  -- rule then finds nothing, which is the truth.
  local within = inside(settings.transcripts, settings.history)
  local function key_of(name)
    if within and within ~= "" then
      return within .. "/" .. name
    end
    return name
  end

  -- THE FILMS, for a project that asked for them. Each conversation's film
  -- choices are read from the project's own choices folder; a message with no
  -- choice yet is drawn without one and counted, so a gap is seen rather
  -- than discovered.
  local matcher, describer, film_names, films_used, scratch
  if settings.films then
    matcher, describer = films_part()
    film_names = {}
    for hash, entry in pairs(describer.read_descriptions(settings.films.descriptions_file)) do
      film_names[hash] = entry.name
    end
    films_used = {}
    report.films_unmatched = 0
    scratch = settings.scratch .. "/films"
    run("mkdir -p " .. shell_quote(scratch), "make " .. scratch)
  end

  local conversations = {}
  local written = 0
  for _, transcript in ipairs(transcripts) do
    local name, conversation = transcript.name, transcript.conversation
    count_oversized(conversation, name, report.oversized)

    local films = nil
    if settings.films then
      local keys = matcher.message_keys(conversation, scratch)
      local choices = matcher.read_choices(matcher.choices_path(settings.films, name))
      local unmatched
      films, unmatched = matcher.films_for_page(conversation, keys, choices, film_names)
      report.films_unmatched = report.films_unmatched + unmatched
      for _, film in ipairs(films) do
        if film then films_used[film] = true end
      end
    end

    local title = name:gsub("%.md$", "")
    local out_name = title .. ".html"
    spit(settings.pages_folder .. "/" .. out_name, page.render(conversation, {
      title = title,
      back = "index.html",
      base_path = settings.base_path,
      colours_css = colours_css,
      films = films,
      film_size = settings.films and settings.films.square_px or nil,
    }))
    written = written + 1

    conversations[key_of(name)] = {
      href = out_name,
      title = title,
      summary = page.summary_line(reader.first_request(conversation), 96),
    }
  end
  report.conversations = written

  -- THE TABLE OF CONTENTS. Each commit finds its conversation by evidence,
  -- under the rules the project chose.
  local evidence = M.gather_evidence(transcripts, key_of)
  report.elsewhere = evidence_elsewhere(settings, evidence, conversations)

  local commits = history.read(settings.history, within ~= "" and within or "llm-transcripts")
  local becomes = history.rename_map(settings.history)
  for _, commit in ipairs(commits) do
    for index, path in ipairs(commit.transcripts) do
      commit.transcripts[index] = history.resolve(path, becomes)
    end
  end
  attribution.attribute(commits, evidence, settings.attribution)

  -- WHAT NO CONVERSATION OF THIS PROJECT MADE (issue 040), two ways. Made
  -- from another project's conversation (recorded in an evidence_from
  -- folder): left off the page, her choice, and only counted here. Made by
  -- hand (no evidence, and no assistant's trailer): shown like any other,
  -- with a page of her own words behind its button.
  local elsewhere = recorded_elsewhere(settings)
  local shown = {}
  report.hidden_elsewhere = 0
  report.hand_made = 0
  for _, commit in ipairs(commits) do
    if not commit.how and elsewhere[commit.source:sub(1, 7)] then
      report.hidden_elsewhere = report.hidden_elsewhere + 1
    else
      if not commit.how and not commit.assisted then
        -- Where her files are read from: the setting, else the history
        -- folder. A mirror does not hold the project commit, so a project
        -- with a mirror and no setting gets the commit message alone.
        local repository = settings.hand_made_from or settings.history
        local out_name = "by-hand-" .. commit.source:sub(1, 7) .. ".html"
        spit(settings.pages_folder .. "/" .. out_name, page.render(
          M.hand_made_conversation(commit, repository, settings.transcripts:match("([^/]+)/*$")), {
            title = commit.subject, back = "index.html", base_path = settings.base_path,
            colours_css = colours_css,
          }))
        local key = "by-hand:" .. commit.source
        conversations[key] = { href = out_name, title = commit.subject }
        commit.conversation, commit.how = key, "by hand"
        report.hand_made = report.hand_made + 1
      end
      shown[#shown + 1] = commit
    end
  end
  commits = shown
  local groups = attribution.group(commits)

  local nav, nav_css = nil, nil
  if settings.nav then
    nav, nav_css = settings.nav(settings.project)
  end
  spit(settings.pages_folder .. "/index.html", contents_page.render(groups, conversations, {
    title = settings.title,
    base_path = settings.base_path,
    colours_css = colours_css,
    nav = nav,
    nav_css = nav_css,
  }))

  report.commits = #commits
  report.groups = #groups
  report.linked = 0
  for _, commit in ipairs(commits) do
    if commit.how then
      report.how[commit.how] = (report.how[commit.how] or 0) + 1
      if conversations[commit.conversation] then
        report.linked = report.linked + 1
      end
    end
  end

  -- The films the pages ask for, copied whole from the film folder: only the
  -- ones some message uses, each once, at full size, so a reader's browser
  -- fetches each once. A film named in a choice but missing from the folder
  -- stops the build, because the page would otherwise show a broken square.
  if settings.films then
    local films_out = settings.output .. "/films"
    run("mkdir -p " .. shell_quote(films_out), "make " .. films_out)
    report.films_used = 0
    for name in pairs(films_used) do
      run("cp " .. shell_quote(settings.films.film_folder .. "/" .. name) .. " "
        .. shell_quote(films_out .. "/"), "copy the film " .. name)
      report.films_used = report.films_used + 1
    end
  end

  return report
end
-- }}}

-- {{{ function M.assign_films()
-- Gives every message in the project's conversations its film: looks at any
-- film never seen before, then matches every message with no film yet. Needs
-- the model server running. The conversations are read and shaped exactly as
-- the build reads them, so a message has the same key in both.
function M.assign_films(settings)
  if not settings.films then
    error("this project's settings ask for no films; add a films table to give it some")
  end
  local matcher = films_part()
  local transcripts = M.read_transcripts(settings)
  matcher.run(settings.films, transcripts, settings.scratch .. "/films")
end
-- }}}

-- {{{ function M.print_report()
-- Says what the build saw, so a number that moves is seen rather than
-- discovered.
function M.print_report(report)
  print("")
  print("  conversations  " .. report.conversations)
  print("  commits        " .. report.commits)
  print("  groups         " .. report.groups)
  print("  written to     " .. report.output)
  print("  commits linked " .. report.linked .. " of " .. report.commits)
  for _, rule in ipairs(attribution.DEFAULT_RULES) do
    if report.how[rule] then
      print(string.format("    by %-10s %d", rule, report.how[rule]))
    end
  end
  if report.hand_made > 0 then
    print(string.format("    by %-10s %d", "hand", report.hand_made))
  end
  if report.hidden_elsewhere > 0 then
    print("  commits made from conversations elsewhere, not shown: " .. report.hidden_elsewhere)
  end
  if report.elsewhere > 0 then
    print("  commit lines read from other projects " .. report.elsewhere)
  end
  if report.films_used then
    print("  films          " .. report.films_used .. " used")
    if report.films_unmatched > 0 then
      print("  " .. report.films_unmatched .. " message(s) have no film yet; "
        .. "run assign-films to choose them")
    end
  end
  if #report.not_transcripts > 0 then
    print("  not transcripts, left alone: " .. table.concat(report.not_transcripts, ", "))
  end
  print("")
  if #report.oversized == 0 then
    print("  No fenced block over " .. M.WORTH_MENTIONING .. " lines.")
  else
    print("  " .. #report.oversized .. " fenced block(s) over " .. M.WORTH_MENTIONING .. " lines:")
    for _, block in ipairs(report.oversized) do
      print(string.format("    %-44s %4d lines   %s",
        block.file, block.lines, block.language or ""))
    end
  end
end
-- }}}

M.settings = settings_reader

-- {{{ the command
-- Run as a command, with a project folder and optionally a settings file,
-- and exit non-zero on any failure, with the reason. Two jobs: build and
-- report (the default), or, after --assign-films, choose the films. Loaded
-- with dofile there are no arguments, and nothing runs.
local arguments = { ... }
if #arguments > 0 then
  local job = "build"
  if arguments[1] == "--assign-films" then
    job = "films"
    table.remove(arguments, 1)
  end
  local project, file = arguments[1], arguments[2]
  local ok, failure = pcall(function()
    local settings = settings_reader.load(project, file)
    if job == "films" then
      M.assign_films(settings)
    else
      print("Reading " .. settings.transcripts)
      M.print_report(M.build(settings))
    end
  end)
  if not ok then
    io.stderr:write("build-site: " .. tostring(failure) .. "\n")
    os.exit(1)
  end
end
-- }}}

return M
