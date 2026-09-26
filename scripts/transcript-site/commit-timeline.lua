-- commit-timeline.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Reads a project's history and folds it into the runs of commits each
-- conversation produced.
--
-- Taken from double-diaper-dungeon's src/051-commit-timeline.lua (at its
-- commit 58f89bf) for every project's transcripts (issue 035). That copy
-- reads a public "mirror" repository its project builds; this one reads the
-- project's own history, limited to the project's folder and with paths
-- written relative to it, so a project living inside a larger repository
-- (the ai-stuff monorepo) sees its own commits and its own
-- "llm-transcripts/..." paths exactly as the mirror presented them. A mirror
-- is still readable: it is a project whose folder is its whole repository.
-- Its libraries and palette load from this folder; the notes below are the
-- original's, with "mirror" meaning whichever history is read.

-- The landing page: every commit in order, with the conversations hung off it.
--
-- WHY THE COMMITS AND NOT THE FILES. A folder of transcripts has no reading
-- order. The files are named for the span of days they cover, which LOOKS
-- chronological and is not: several sessions run at once, a conversation begun
-- on Tuesday can be added to on Friday, and two files can cover overlapping
-- spans while belonging to different threads of work. Sorting by filename, by
-- date or by modification time all produce an order no human ever experienced.
--
-- The commits are the only true chronology. A commit happened at a moment, in
-- a sequence, and the mirror rebuilds that sequence exactly -- same message,
-- same dates, same order. So the spine of the site is that sequence, and a
-- reader with five minutes gets the story of the project by reading the commit
-- messages alone.
--
-- HOW A COMMIT FINDS ITS CONVERSATION. By adjacency in the sequence, never by
-- matching dates. A run of commits belongs to whichever conversation the
-- transcript-touching commit among them came from. Dates seem equivalent and
-- would quietly mis-file every commit made while two sessions overlapped,
-- which is the exact failure this whole design exists to avoid.
--
-- WHY THE EMPTY COMMITS MATTER. The mirror writes a commit even when a commit
-- touched no transcript -- an empty one, carrying only the message. That looks
-- like a curiosity and is load-bearing here: without it, a stretch of work
-- where several commits landed between two of her messages would appear as a
-- gap and the story would skip. A couple of hundred bytes buys a narrative
-- that never jumps.

local M = {}

-- This folder, where the libraries and the default palette live.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- The separator between a commit's fields. Chosen because git will not put it
-- in a hash, a subject or a date, and a subject can contain anything else.
local FIELD = "\30"
local RECORD = "\31"

-- {{{ local function shell_quote()
-- Wraps a path so a space or a quote in it cannot end the argument early.
local function shell_quote(text)
  return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function M.read_commits()
-- Walks the mirror's history oldest to newest and returns one record per
-- commit: its hash, its message, its date, and the transcript files it
-- touched.
--
-- Reversed rather than asked for in reverse, because git's own reverse walk
-- and its name-only output do not compose the way one would hope; collecting
-- forward and flipping is shorter to read and cannot get the two out of step.
function M.read_commits(mirror_path)
  -- The record mark goes at the FRONT of the format, not the end.
  --
  -- This was wrong the other way round first, and the symptom is worth knowing
  -- because it looked like a smaller bug than it was: with the mark trailing,
  -- splitting the output hands you a chunk holding the PREVIOUS commit's file
  -- list followed by this commit's header, since --name-only prints a commit's
  -- files after the header line they belong to. Every commit then gets its
  -- neighbour's files. It read 8 commits out of 43 and found no transcripts at
  -- all, which is the good kind of failure -- loud enough to notice.
  --
  -- Leading, each chunk is one header and then exactly its own files.
  -- The body comes too, because a commit message here is two things: a
  -- subject somebody skims and a body saying what actually happened. The
  -- timeline shows the first and folds the second away until it is asked for.
  local format = RECORD .. "%H" .. FIELD .. "%s" .. FIELD .. "%ad" .. FIELD .. "%b"
  local command = string.format(
    -- "--relative" and the "." at the end: only commits that touched this
    -- folder, with their paths written from it (see the header).
    "git -C %s log --relative --date=short --format=%s --name-only -- .",
    shell_quote(mirror_path), shell_quote(format))

  local pipe = io.popen(command, "r")
  if not pipe then
    error("could not read the mirror's history at " .. mirror_path)
  end
  local text = pipe:read("*a")
  pipe:close()

  if text == "" then
    error("the mirror at " .. mirror_path .. " has no commits in it")
  end

  local commits = {}
  -- Each chunk is one commit: its header line, then the files it touched.
  for chunk in text:gmatch(RECORD .. "([^" .. RECORD .. "]*)") do
    local hash, subject, date, rest =
      chunk:match("^(%x+)" .. FIELD .. "(.-)" .. FIELD .. "([%d%-]+)" .. FIELD .. "(.*)$")
    if hash then
      -- The body runs until the file list starts. --name-only prints the files
      -- after a blank line, and a body's own blank lines are not special, so
      -- the split is on the first line that looks like a tracked path rather
      -- than on blankness.
      local body_lines, files = {}, {}
      local in_files = false
      for line in rest:gmatch("([^\n]*)\n?") do
        if line:match("^llm%-transcripts/") or line:match("^[%w%-%._]+/[%w%-%./_]+$")
          or line:match("^[%w%-%._]+%.%w+$") then
          in_files = true
          -- Only a transcript counts: a file directly inside llm-transcripts/
          -- ending .md. The pages built from them live in llm-transcripts/HTML/
          -- and are not conversations.
          if line:match("^llm%-transcripts/[^/]+%.md$") then
            files[#files + 1] = line
          end
        elseif not in_files then
          body_lines[#body_lines + 1] = line
        end
      end

      local body = table.concat(body_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      commits[#commits + 1] = {
        hash = hash, subject = subject, date = date,
        body = (body ~= "" and body) or nil,
        transcripts = files,
      }
    end
  end

  if #commits == 0 then
    error("read the mirror's history and understood none of it -- the format moved")
  end

  -- Oldest first, because the page is read top to bottom as a story.
  local ordered = {}
  for index = #commits, 1, -1 do
    ordered[#ordered + 1] = commits[index]
  end
  return ordered
end
-- }}}

-- {{{ function M.attribute()
-- Decides, for each commit, which conversation made it -- by evidence, never
-- by where it sits in the list (issue 035).
--
-- The rule this replaced gave a run of commits to the conversation whose
-- transcript the run's last commit touched. That holds for a mirror where
-- each commit carries only its own conversation, and fails everywhere else:
-- one project's first 220 commits hung off a one-turn transcript because the
-- first commit to touch any transcript was a bulk import of 297 of them, and
-- other work hung off a read-only helper that happened to sort first.
--
-- `evidence` comes from build-site.lua:
--   by_hash      abbreviated hash (string) -> { path, turn }
--   by_subject   commit subject (string) -> list of { path, turn }
--   parent_of    helper transcript path -> the transcript that links to it
--   is_main      transcript path -> true for a main conversation
--
-- Sets on each commit `conversation` (a transcript path, or nil), `turn` (the
-- turn index that made it, or nil) and `how`. Three outcomes, in order:
--
--   "recorded"  a transcript records making this commit: its hash, or --
--               when history was rewritten and the hash moved -- its
--               subject, if exactly one transcript records that subject.
--   "saved"     the commit touched exactly one main conversation's
--               transcript, a helper counting as its parent. The commit
--               routine saves the committing conversation's transcript with
--               its work, so this is weaker evidence but still evidence.
--   nil         neither: an import or rebuild touching many conversations,
--               or a commit that touched none. Left unattributed.
function M.attribute(commits, evidence)
  for _, commit in ipairs(commits) do
    local found = evidence.by_hash[commit.hash:sub(1, 7)]
    if found and commit.hash:sub(1, #found.hash) ~= found.hash then
      found = nil
    end
    if not found then
      local same = evidence.by_subject[commit.subject]
      if same and #same == 1 then
        found = same[1]
      end
    end

    if found then
      commit.conversation, commit.turn, commit.how = found.path, found.turn, "recorded"
    else
      local mains, count = {}, 0
      for _, path in ipairs(commit.transcripts) do
        local owner = evidence.parent_of[path] or path
        if evidence.is_main[owner] and not mains[owner] then
          mains[owner] = true
          count = count + 1
        end
      end
      if count == 1 then
        commit.conversation, commit.how = next(mains), "saved"
      end
    end
  end
end
-- }}}

-- {{{ function M.group()
-- Folds the attributed commit list into the runs the page draws: consecutive
-- commits with the same conversation (or the same lack of one) are one run.
-- Each run is { commits = <list>, conversation = <path or nil> }.
function M.group(commits)
  local runs = {}
  local current = nil
  for _, commit in ipairs(commits) do
    if not current or current.conversation ~= commit.conversation then
      current = { commits = {}, conversation = commit.conversation }
      runs[#runs + 1] = current
    end
    current.commits[#current.commits + 1] = commit
  end
  return runs
end
-- }}}

-- {{{ local function escape()
local function escape(text)
  return (tostring(text)
    :gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
-- }}}

-- {{{ function M.stylesheet()
-- The timeline's own rules. The commit messages are the thing being read, so
-- they are the largest text on the page and everything else gets out of their
-- way.
function M.stylesheet()
  return [[
body { background: var(--ground); color: var(--plain); margin: 0;
       padding: 2rem 1rem 6rem; line-height: 1.55; }
.sheet { max-width: 48rem; margin: 0 auto; }
h1 { color: var(--spirit); }
.intro { opacity: 0.8; }

.run { margin: 0 0 2.75rem; border-left: 2px solid var(--plain); padding-left: 1.25rem; }
.run:hover { border-left-color: var(--spirit); }

/* The commit messages, which are the story. Largest thing on the page. */
.messages { list-style: none; margin: 0; padding: 0; }
.messages li { margin: 0.35rem 0; }

/* The subject is the story; the body is what actually happened, and it unfolds
   when asked for rather than burying the story under itself. */
.messages summary { cursor: pointer; list-style: none; color: var(--spirit); }
.messages summary::-webkit-details-marker { display: none; }
.messages summary::before { content: "\25B8\00a0"; color: var(--plain); flex: none; }
.messages details[open] summary::before { content: "\25BE\00a0"; }
.messages .subject { color: var(--spirit); }
.messages li.bare { color: var(--spirit); padding-left: 1.1em; }

/* ONE COMMIT, ONE LINE. A subject that wrapped went back to the left edge,
   under the date, and read as a second commit. The subject keeps to its
   line and ends in an ellipsis when the window is too narrow; the whole of
   it shows on hover and in the unfolded message. */
.messages summary, .messages li.bare { display: flex; align-items: baseline; min-width: 0; }
.messages .when { flex: none; }
.messages .subject { flex: 1 1 auto; min-width: 0; white-space: nowrap;
                     overflow: hidden; text-overflow: ellipsis; }
.messages .turn-link { flex: none; margin-left: 0.6rem; font-size: 0.8rem;
                       text-decoration: none; opacity: 0.7; }
.fulltext .whole-subject { color: var(--spirit); display: block; margin-bottom: 0.4rem; }
.fulltext {
  white-space: pre-wrap;
  color: var(--plain);
  border-left: 1px solid var(--plain);
  margin: 0.5rem 0 1rem 1.1em;
  padding: 0.3rem 0 0.3rem 0.9rem;
  font-size: 0.92rem;
}
.messages .when { color: var(--plain); opacity: 0.55; font-size: 0.75rem;
                  margin-right: 0.6rem; }

/* The conversation hung off the run, quieter than the commits above it. */
.came-from { margin-top: 0.8rem; font-size: 0.9rem; }
.came-from a { color: var(--intellect); }
.came-from .said { display: block; opacity: 0.7; margin-top: 0.2rem;
                   font-style: italic; }
.unwritten { opacity: 0.45; font-size: 0.9rem; margin-top: 0.8rem; }
a { color: var(--intellect); }
]]
end
-- }}}

-- {{{ function M.render_index()
-- The landing page: every run of commits, oldest first, with the conversation
-- that produced it underneath.
--
-- `conversations` maps a transcript path to { href, summary }. A run whose
-- transcript is not in that map gets no link. That happens for real: the
-- exporter renames a transcript when a session resumes across a day boundary,
-- so history holds names that no longer exist on disk. Linking to one anyway
-- would put a dead link on a public page, and dropping the run would leave a
-- hole in the story -- so the commits show and the link does not.
function M.render_index(runs, conversations, opts)
  opts = opts or {}
  local page_head = dofile(HERE .. "libs/page-head.lua")
  local palette = dofile(HERE .. "site-palette.lua")
  local _, colours_css = palette.load(opts.palette_file or (HERE .. "default-palette.lua"))

  local body = { '<div class="sheet">' }
  body[#body + 1] = "<h1>" .. escape(opts.title or "How this got made") .. "</h1>"
  body[#body + 1] = '<p class="intro">Every commit, oldest first. Read the messages'
    .. " straight down for the story; click into a conversation to find out why"
    .. " something was done.</p>"

  for _, run in ipairs(runs) do
    body[#body + 1] = '<section class="run">'
    body[#body + 1] = '<ul class="messages">'
    local found = run.conversation and conversations[run.conversation]

    for _, commit in ipairs(run.commits) do
      -- A COMMIT MESSAGE IS TWO THINGS AND THE PAGE SHOWS ONE OF THEM.
      --
      -- The subject is what somebody reads straight down to get the story. The
      -- body is what actually happened and why, and printing all of them at
      -- once would bury the story under itself. So the subject is the visible
      -- line and the body unfolds under it when clicked.
      --
      -- <details> again, so the page needs no script to do it.
      --
      -- A commit its conversation records making links to the turn that made
      -- it; one known only from the transcript it saved has no turn to point
      -- at, and gets no link.
      local turn_link = ""
      if found and commit.turn then
        turn_link = string.format(' <a class="turn-link" href="%s#turn-%d" title="where this was made">&#8599;</a>',
          escape(found.href), commit.turn)
      end
      if commit.body then
        body[#body + 1] = string.format(
          '<li><details><summary><span class="when">%s</span> <span class="subject" title="%s">%s</span>%s</summary>'
            .. '<div class="fulltext"><span class="whole-subject">%s</span>%s</div></details></li>',
          escape(commit.date), escape(commit.subject), escape(commit.subject), turn_link,
          escape(commit.subject), escape(commit.body))
      else
        -- A commit with only a subject has nothing to unfold, and drawing it
        -- as though it did would promise something that is not there.
        body[#body + 1] = string.format(
          '<li class="bare"><span class="when">%s</span> <span class="subject" title="%s">%s</span>%s</li>',
          escape(commit.date), escape(commit.subject), escape(commit.subject), turn_link)
      end
    end
    body[#body + 1] = "</ul>"

    if found then
      body[#body + 1] = '<div class="came-from">'
      -- Two kinds of conversation: this project's own, or one filed under
      -- another project in the same repository (`elsewhere` names where),
      -- whose page sits in that project's folder.
      if found.elsewhere then
        body[#body + 1] = string.format('<a href="%s">the conversation these came out of</a> '
          .. '<span class="where-filed">(filed under %s)</span>', escape(found.href), escape(found.elsewhere))
      else
        body[#body + 1] = string.format('<a href="%s">the conversation these came out of</a>',
          escape(found.href))
      end
      if found.summary then
        body[#body + 1] = '<span class="said">&ldquo;' .. escape(found.summary) .. '&rdquo;</span>'
      end
      body[#body + 1] = "</div>"
    elseif run.conversation then
      -- Attributed to a transcript that is not in the folder any more.
      body[#body + 1] = '<p class="unwritten">The conversation behind these was'
        .. " written under a name the project no longer carries.</p>"
    else
      -- No evidence either way: the page says so rather than guessing.
      body[#body + 1] = '<p class="unwritten">No conversation is recorded'
        .. " for these commits.</p>"
    end

    body[#body + 1] = "</section>"
  end

  body[#body + 1] = "</div>"

  return table.concat({
    "<!DOCTYPE html>",
    '<html lang="en">',
    page_head.head({
      title = escape(opts.title or "How this got made"),
      -- How deep this page sits. The font lives at the site root, and a page
      -- that guesses wrong loads no font at all and silently falls back --
      -- the exact failure the shipped font exists to prevent.
      base_path = opts.base_path or ".",
      extra_css = colours_css .. "\n" .. M.stylesheet(),
    }),
    "<body>",
    table.concat(body, "\n"),
    "</body>",
    "</html>",
  }, "\n")
end
-- }}}


-- {{{ function M.rename_map()
-- Follows every rename in the mirror, so a commit that touched a transcript
-- under an old name still finds the page that transcript became.
--
-- WHY THIS IS NEEDED AND WHAT IT LOOKED LIKE WITHOUT IT. The exporter renames
-- a transcript when a session resumes across a day boundary: a file covering
-- one day becomes a file covering a span. History therefore holds names that
-- no longer exist on disk, and the first build linked only ten of thirty-one
-- runs to a conversation -- two thirds of the story dead-ending on a name
-- nobody could follow.
--
-- Git recorded the renames, so nothing has to be guessed. Walking them oldest
-- to newest and chaining them means a file renamed twice still resolves: if A
-- became B and B later became C, A answers C.
function M.rename_map(mirror_path)
  -- An empty format rather than a marked one: the only lines wanted are the
  -- rename lines git prints itself, and a control character is not a legal
  -- pretty format anyway -- which git says plainly rather than guessing at.
  local command = string.format(
    "git -C %s log --relative --reverse --diff-filter=R --name-status --format= -M -- .",
    shell_quote(mirror_path))

  local pipe = io.popen(command, "r")
  if not pipe then
    error("could not read the mirror's renames at " .. mirror_path)
  end
  local text = pipe:read("*a")
  pipe:close()

  local becomes = {}
  for line in text:gmatch("[^\n]+") do
    -- R<similarity><tab><old path><tab><new path>
    local from, to = line:match("^R%d*\t(.-)\t(.+)$")
    if from and to then
      -- Anything that already pointed at the old name now points at the new
      -- one, which is what makes a chain of renames resolve in one step.
      for older, current in pairs(becomes) do
        if current == from then
          becomes[older] = to
        end
      end
      becomes[from] = to
    end
  end
  return becomes
end
-- }}}

-- {{{ function M.resolve()
-- The name a path goes by now, following renames.
--
-- Returns the path unchanged when it was never renamed, which is the common
-- case and wants no special handling by the caller.
function M.resolve(path, becomes)
  return becomes[path] or path
end
-- }}}

return M
