-- conversation-page.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Turns one conversation into one page, with the two speakers on opposite
-- sides and the harness drawn as neither.
--
-- Taken from double-diaper-dungeon's src/050-conversation-page.lua (at its
-- commit 58f89bf) for every project's transcripts (issue 035). Changes from
-- that copy:
--
--   its libraries load from this folder, and its colours from a palette file
--   passed in (default-palette.lua, the game's colours, when none is);
--   the recap Contents list (issue 037) is drawn at the top, each entry a
--   link to the turn it comes before;
--   lines the harness wrote above the first request get a row of their own;
--   an archived transcript's missing header facts read "not recorded";
--   a link to a sibling transcript (a helper's, issue 025) points at that
--   transcript's page instead.
--
-- WHAT THE PAGE DOES THAT THE FILE CANNOT. A transcript on disk is a good
-- thing to keep and a poor thing to read. Four differences, and every one of
-- them is a property of the VIEW rather than of the stored text -- which is
-- the whole reason they live here and not in the exporter.
--
--   The two speakers sit on opposite sides. An earlier attempt padded the
--   stored file out to the right edge to get this, and padded prose renders as
--   a code box in every markdown viewer, which is how it looked on GitHub. A
--   stylesheet rule costs the file nothing and can be turned off by a reader.
--
--   Narration reads as narration. In the markdown it borrows the blockquote
--   marker, which also means "a line she pasted back". On a page those can be
--   two different registers and the ambiguity disappears.
--
--   Whose words these are is shown rather than stated. Each reply carries the
--   model that served it down its gutter, so a reader SEES where the character
--   changes instead of reading a line saying it did.
--
--   The harness's own recaps are neither speaker, and are drawn as neither.
--
-- WHAT IT REFUSES TO DO. It redacts nothing. The counting of oversized code
-- blocks happens elsewhere and is reported rather than acted on, because a
-- page that quietly removed content would be the silent fallback the house
-- rules exist to prevent.

local M = {}

-- This folder: the libraries and the default palette live beside this file,
-- so it runs from any directory without being told where it is.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- {{{ local function libs()
local function libs()
  return dofile(HERE .. "libs/markdown.lua"),
         dofile(HERE .. "libs/page-head.lua"),
         dofile(HERE .. "site-palette.lua")
end
-- }}}

-- {{{ function M.default_palette_file()
function M.default_palette_file()
  return HERE .. "default-palette.lua"
end
-- }}}

-- {{{ local function escape()
-- HTML-escapes a piece of text that is going into markup rather than through
-- the markdown renderer.
--
-- The markdown renderer escapes everything it emits, so body text is already
-- safe. This is for the pieces that go straight into a tag -- a title, a model
-- name, a date -- which would otherwise be the one hole in an otherwise sealed
-- page.
local function escape(text)
  return (tostring(text)
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;"))
end
-- }}}

-- {{{ local function summary_line()
-- The first thing she said, cut to something that fits on one line.
--
-- Cut on a word boundary rather than mid-word, because a summary ending
-- "...the transcr" reads as a bug and a summary ending "...the" reads as a
-- summary. Newlines collapse to spaces first: a request typed across six lines
-- is still one sentence to a reader looking at a list.
local function summary_line(text, width)
  if not text then
    return nil
  end
  local flat = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if #flat <= width then
    return flat
  end
  local cut = flat:sub(1, width)
  local last_space = cut:find("%s[^%s]*$")
  if last_space and last_space > width / 2 then
    cut = cut:sub(1, last_space - 1)
  end
  return cut .. "..."
end
-- }}}

M.summary_line = summary_line

-- {{{ local function speaker_class()
-- Which side of the page a turn sits on, and what it is called there.
--
-- A dispatch table rather than a chain of conditions: the kinds are data and
-- another would be one more row rather than one more branch. The labels are
-- deliberately plain nouns -- "she said", "the assistant", "the harness" --
-- because the page is a record of a conversation and not a chat interface.
local SPEAKERS = {
  user      = { class = "said",    label = "she said" },
  assistant = { class = "replied", label = "the assistant" },
  recap     = { class = "recap",   label = "the harness, summarising" },
  harness   = { class = "harness", label = "the harness" },
}

local function speaker_class(kind)
  local speaker = SPEAKERS[kind]
  if not speaker then
    error("no way to draw a turn of kind " .. tostring(kind))
  end
  return speaker
end
-- }}}

-- {{{ local function page_links()
-- A transcript links to a sibling transcript by its file name -- a parent
-- naming the helper it spawned, "[x.md](x.md)". On the site the sibling is a
-- page, so the link is pointed at x.html. Only a bare name with no folder in
-- it is a sibling; any other link is left exactly as written.
local function page_links(html)
  return (html:gsub('href="([^"/:]+)%.md"', 'href="%1.html"'))
end
-- }}}

-- {{{ local function turn_html()
-- One turn of the conversation as a block of markup.
--
-- The model name is printed only when it CHANGES from the turn before. Naming
-- it on every reply would put the same line down the page forty times and stop
-- anybody reading it, which is the opposite of what an attribution is for.
local function turn_html(markdown, exchange, previous_model)
  local speaker = speaker_class(exchange.kind)
  local parts = { string.format('<section class="turn %s">', speaker.class) }

  local heading = { '<span>' .. escape(speaker.label) .. "</span>" }
  if exchange.model and exchange.model ~= previous_model then
    heading[#heading + 1] = '<span class="model">' .. escape(exchange.model) .. "</span>"
  end
  if exchange.continued then
    heading[#heading + 1] = '<span class="continued">continued</span>'
  end

  -- Prose wrapped at eighty columns is re-wrapped to the reader's window, and
  -- a marker spanning a wrap is allowed to pair. See the note in the renderer.
  local rendered = page_links(markdown.render(exchange.body, { reflow = true }))

  -- THE HARNESS'S SUMMARY IS FOLDED AWAY UNTIL SOMEBODY WANTS IT.
  --
  -- When a conversation runs out of room the harness writes a recap of
  -- everything before, and it is long and it is not what a reader came for. It
  -- is also not something either speaker said, so hiding it by default costs
  -- the record nothing and unfolding it costs one click.
  --
  -- Done with <details>, which is a browser doing this on its own. The
  -- alternative is a script, and nothing on this site runs one.
  if exchange.kind == "recap" then
    parts[#parts + 1] = "<details>"
    parts[#parts + 1] = '<summary class="who">' .. table.concat(heading, "\n") ..
      '<span class="unfold">the conversation ran out of room here</span></summary>'
    parts[#parts + 1] = '<div class="what">'
    parts[#parts + 1] = rendered
    parts[#parts + 1] = "</div>"
    parts[#parts + 1] = "</details>"
  else
    parts[#parts + 1] = '<header class="who">' .. table.concat(heading, "\n") .. "</header>"
    parts[#parts + 1] = '<div class="what">'
    parts[#parts + 1] = rendered
    parts[#parts + 1] = "</div>"
  end

  parts[#parts + 1] = "</section>"

  return table.concat(parts, "\n")
end
-- }}}

-- {{{ local function contents_html()
-- The recap list at the top of the page (issue 037): when, where, and what,
-- in the order the recaps were written. "After Request N" is a link to the
-- turn that follows, so a reader skims the recaps and jumps in where they want
-- to read. Two paths: there are recaps, and the list is drawn; or there are
-- none, and nothing is, since an empty list says nothing.
local function contents_html(reader, conversation, anchored)
  if #conversation.contents == 0 then
    return nil
  end
  local parts = { '<nav class="contents">', "<h2>How it went</h2>", "<ol>" }
  for _, entry in ipairs(conversation.contents) do
    local place = (entry.after_request == 0) and "before Request 1"
      or ("after Request " .. entry.after_request)
    if anchored then
      place = string.format('<a href="#turn-%d">%s</a>',
        reader.turn_after_request(conversation, entry.after_request), place)
    end
    parts[#parts + 1] = string.format(
      '<li><span class="when">%s</span> <span class="where">%s</span><p>%s</p></li>',
      escape(entry.when), place, escape(entry.text))
  end
  parts[#parts + 1] = "</ol>"
  parts[#parts + 1] = "</nav>"
  return table.concat(parts, "\n")
end
-- }}}

-- {{{ function M.stylesheet()
-- The page's own rules, on top of the palette.
--
-- Every visual decision in this file is here rather than sprinkled through the
-- markup, which is the point of having moved alignment out of the stored file
-- in the first place: one block to read, one block to override.
function M.stylesheet()
  return [[
body {
  background: var(--ground);
  color: var(--plain);
  margin: 0;
  padding: 2rem 1rem 6rem;
  line-height: 1.55;
}
.sheet { max-width: 54rem; margin: 0 auto; }

img { max-width: 100%; }

/* TABLES GET THEIR LINES BACK.
   Grey rules so the grid is visible, cyan text so a table reads as a table
   rather than as a paragraph that happens to have gaps in it. */
table {
  border-collapse: collapse;
  overflow-x: auto;
  display: block;
  max-width: 100%;
  margin: 1rem 0;
}
table th, table td {
  border: 1px solid var(--plain);
  padding: 0.35rem 0.7rem;
  color: var(--intellect);
  text-align: left;
}
table th { color: var(--spirit); }

pre {
  overflow-x: auto;
  padding: 0.75rem;
  border-left: 2px solid var(--intellect);
  max-width: 100%;
}

/* Inline code is cyan, which is what carries the insight rules: they are one
   backtick span each, and they run wide, so they are allowed to scroll rather
   than wrap into a ragged staircase. */
code {
  color: var(--intellect);
  white-space: pre;
}
p > code:only-child {
  display: block;
  overflow-x: auto;
}

/* Bold is the same yellow as a heading. It is the other way a writer says
   "this is the part that matters", and the two should agree. */
strong, b { color: var(--spirit); }

/* A quoted line reads as quoted. */
blockquote {
  font-style: italic;
  border-left: 2px solid var(--plain);
  margin: 1rem 0;
  padding-left: 1rem;
}

.turn { margin: 2.5rem 0; }
.who {
  font-size: 0.75rem;
  letter-spacing: 0.08em;
  text-transform: lowercase;
  opacity: 0.75;
  margin-bottom: 0.4rem;
  display: flex;
  gap: 0.75rem;
}

/* WHAT SHE SAID IS GREEN, AND SITS ON THE LEFT. */
.said { border-left: 2px solid var(--dexterity); padding-left: 1rem; }
.said .what { color: var(--dexterity); }

/* THE REPLY SITS ON THE RIGHT -- AS A BLOCK, NOT AS RAGGED TEXT.
   text-align: right would give every line a different left edge, which is
   exactly what makes right-aligned prose hard to read. Instead each block is
   shrunk to the width of its own longest line and pushed right, so the text
   inside stays left-aligned and every line starts at the same column.
   Successive bullets line up with each other for the same reason. */
.replied { border-right: 2px solid var(--intellect); padding-right: 1rem; }
.replied .who { justify-content: flex-end; }
.replied .what > * {
  width: fit-content;
  max-width: 100%;
  margin-left: auto;
  margin-right: 0;
  text-align: left;
}
/* A list is one block, so all of its bullets share a left edge rather than
   each item finding its own. */
.replied .what ul, .replied .what ol { padding-left: 1.4rem; }
.replied pre { border-left: none; border-right: 2px solid var(--intellect); }

/* A bullet immediately after its paragraph belongs to it, so the gap between
   them closes. The gap between separate paragraphs stays. */
.what p { margin: 0.9rem 0; }
.what p + ul, .what p + ol { margin-top: -0.55rem; }
.what li { margin: 0.15rem 0; }
.what li > p { margin: 0.2rem 0; }

/* The harness's recap, folded away until asked for. */
.recap {
  opacity: 0.6;
  font-size: 0.9rem;
  border: 1px dashed var(--plain);
  padding: 0.5rem 1rem;
}
.recap summary { cursor: pointer; list-style: none; }
.recap summary::-webkit-details-marker { display: none; }
.recap summary::before { content: "\25B8\00a0"; color: var(--constitution); }
.recap details[open] summary::before { content: "\25BE\00a0"; }
.recap .unfold { opacity: 0.8; }

/* Lines the harness wrote before the first request: neither side, quiet. */
.harness { opacity: 0.6; font-size: 0.9rem; text-align: center; }
.harness .who { justify-content: center; }

/* THE RECAPS, AT THE TOP. Each is a place to jump into the conversation, so
   the link leads an entry and the prose sits under it. */
.contents { border-bottom: 1px solid var(--plain); margin: 1.5rem 0 2rem; }
.contents h2 { font-size: 1rem; }
.contents ol { padding-left: 1.6rem; }
.contents li { margin: 0 0 1.1rem; }
.contents .when { opacity: 0.6; font-size: 0.8rem; margin-right: 0.5rem; }
.contents p { margin: 0.2rem 0 0; }

.model { color: var(--constitution); }
.continued { color: var(--strength); }

a { color: var(--intellect); }
h1, h2, h3, h4 { color: var(--spirit); line-height: 1.25; }
.masthead { border-bottom: 1px solid var(--plain); padding-bottom: 1rem; }
.masthead .facts { font-size: 0.8rem; opacity: 0.7; }
.back { display: inline-block; margin-bottom: 1.5rem; }
]]
end
-- }}}

-- {{{ local function facts_line()
-- The small line under the title: when the file was written and which models
-- served it. An archived transcript may never have recorded either, and says
-- so rather than showing a blank that looks like nothing happened; a current
-- one with no models line had none named, and says that instead.
local function facts_line(conversation)
  local written = conversation.generated_on or "date not recorded"
  local models
  if #conversation.models > 0 then
    models = table.concat(conversation.models, ", ")
  elseif conversation.header_complete then
    models = "no model named"
  else
    models = "models not recorded"
  end
  return string.format('<p class="facts">written %s &middot; %s</p>',
    escape(written), escape(models))
end
-- }}}

-- {{{ function M.render()
-- A whole conversation as a finished HTML page.
--
-- `opts.title` names the page, `opts.back` is the link home, `opts.base_path`
-- is the route back to the site root where the font is, `opts.palette_file`
-- is the palette (default-palette.lua when omitted), and `opts.anchor = false`
-- turns off the per-turn ids and with them the Contents links, which would
-- have nowhere to land.
function M.render(conversation, opts)
  opts = opts or {}
  local markdown, page_head, palette = libs()
  local reader = dofile(HERE .. "transcript-reader.lua")
  local _, colours_css = palette.load(opts.palette_file or M.default_palette_file())

  local title = opts.title or ("conversation " .. conversation.session_id)
  local anchored = opts.anchor ~= false

  local body = {}
  body[#body + 1] = '<div class="sheet">'
  if opts.back then
    body[#body + 1] = string.format('<a class="back" href="%s">&larr; every conversation</a>', escape(opts.back))
  end

  body[#body + 1] = '<header class="masthead">'
  body[#body + 1] = "<h1>" .. escape(title) .. "</h1>"
  body[#body + 1] = facts_line(conversation)
  body[#body + 1] = "</header>"

  local contents = contents_html(reader, conversation, anchored)
  if contents then
    body[#body + 1] = contents
  end

  local previous_model = nil
  for index, exchange in ipairs(conversation.exchanges) do
    local turn = turn_html(markdown, exchange, previous_model)
    if anchored then
      turn = turn:gsub('^<section class="turn',
        string.format('<section id="turn-%d" class="turn', index), 1)
    end
    body[#body + 1] = turn
    if exchange.model then
      previous_model = exchange.model
    end
  end

  body[#body + 1] = "</div>"

  return table.concat({
    "<!DOCTYPE html>",
    '<html lang="en">',
    page_head.head({
      title = escape(title),
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

return M
