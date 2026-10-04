-- conversation-page.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Turns one conversation into one page, with the two speakers on opposite
-- sides and the harness drawn as neither.
--
-- Part of the transcript display (conversation/). It loads the shared
-- libraries and nothing from the table of contents or the films: colours,
-- films and the page's place in the site are handed in by the builder.
--
-- Taken from double-diaper-dungeon's src/050-conversation-page.lua for every
-- project's transcripts (issue 035), and joined with it again on 2026-10-04
-- (issue 035c), so the two copies are one. What each brought:
--
--   from this folder: the recap Contents list (issue 037) drawn at the top,
--   each entry a link to the turn it comes before; lines the harness wrote
--   above the first request as a row of their own; "not recorded" for an
--   archived transcript's missing header facts;
--
--   from the game: a small looping film beside every message (its issue
--   10-007); an id on every commit line, for the table of contents to land
--   on; the colours handed in as CSS, so a project can make them its own way.
--
-- A PAGE CARRIES ONLY THE RULES IT USES. The Contents and harness rules join
-- the stylesheet only on a page that draws them. That keeps the game's pages
-- -- which draw neither -- byte for byte what they were, and keeps every
-- page a little smaller.
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

-- This folder. The shared libraries sit one folder up, in libs/, so the page
-- runs from any directory without being told where it is.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- {{{ local function libs()
local function libs()
  return dofile(HERE .. "../libs/markdown.lua"),
         dofile(HERE .. "../libs/page-head.lua")
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

-- {{{ function M.commit_anchor()
-- The id a commit line carries on its page, from the first seven hex digits
-- of the hash it records: "commit-<seven>". Seven, because the exporter
-- writes seven or nine depending on the day, and seven is the part both
-- share.
--
-- THE ONE NAME TWO PARTS SHARE. The table of contents links to this id but
-- never loads this file: the builder asks this function for the anchor and
-- hands it to the table of contents with the rest of the evidence. Change
-- the rule here and both sides change together.
function M.commit_anchor(short)
  return "commit-" .. short:sub(1, 7)
end
-- }}}

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
--
-- `film` is the small looping film beside this turn -- { src = <string, its
-- address>, size = <whole number, CSS pixels> } -- or false for none. The
-- film goes first in the markup either way; the stylesheet puts hers on the
-- left and the assistant's on the right, mirrored, so the two face each other.
local function turn_html(markdown, exchange, previous_model, film)
  local speaker = speaker_class(exchange.kind)
  local parts = { string.format('<section class="turn %s%s">', speaker.class,
    film and " has-film" or "") }
  if film then
    -- alt is empty on purpose: the film is decoration chosen by a machine, and
    -- a screen reader announcing a file name before every message would be
    -- noise. The size is written in so the page does not jump as films load.
    parts[#parts + 1] = string.format(
      '<img class="film" src="%s" alt="" width="%d" height="%d" loading="lazy">',
      escape(film.src), film.size, film.size)
    parts[#parts + 1] = '<div class="turn-body">'
  end

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

  -- A PARAGRAPH THAT IS ONE CODE SPAN AND NOTHING ELSE is marked, so the
  -- stylesheet can let it run wide and scroll (an insight rule) while code
  -- inside a sentence stays in the sentence. Two paths: the paragraph holds
  -- exactly <code>...</code>, and gains the class; or it holds anything else
  -- around the code, and is left alone. The renderer escapes every "<" in
  -- text, so "[^<]*" is the whole span and can never run past it.
  rendered = rendered:gsub("<p><code>([^<]*)</code></p>", '<p class="code-line"><code>%1</code></p>')

  -- EVERY COMMIT GETS A PLACE TO LAND.
  --
  -- The exporter writes a line where each commit happened, as
  -- "*[commit] <hash> - <subject>*" (or "... in <repository> - ..."), which
  -- the renderer turns into <em>[commit] <hash> ...</em>. That line is the
  -- exact moment in the conversation the commit came out of, so it gets an id
  -- from M.commit_anchor, and the table of contents' button for that commit
  -- points straight at it. The builder hands the same rule to the table of
  -- contents, so the two parts agree on a name without knowing each other.
  rendered = rendered:gsub("<em>%[commit%] (%x%x%x%x%x%x%x)(%x*)",
    function(short, rest)
      return string.format('<em class="commit-mark" id="%s">[commit] %s%s',
        M.commit_anchor(short), short, rest)
    end)

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

  if film then parts[#parts + 1] = "</div>" end
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
--
-- `uses` says which optional rules this page needs: `uses.harness` (boolean,
-- the page draws a harness turn) and `uses.contents` (boolean, it draws the
-- Contents list). Each joins at the place it has always stood, and only when
-- used; with neither, the sheet is exactly the one the game's pages carry.
-- No `uses` at all means every rule, for a reader who wants the whole sheet.
function M.stylesheet(uses)
  uses = uses or { harness = true, contents = true }
  return M.STYLE_TOP
    .. (uses.harness and M.STYLE_HARNESS or "")
    .. (uses.contents and M.STYLE_CONTENTS or "")
    .. M.STYLE_BOTTOM
end
-- }}}

-- The stylesheet in its four pieces, in the order they join.
M.STYLE_TOP = [[
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
/* A paragraph that is one code span and nothing else -- an insight rule --
   is marked "code-line" by the page builder, and only that becomes a block.
   This was "p > code:only-child", which CSS answers by counting elements
   alone and ignoring words: "One file, `README.md`, written by hand" has one
   element child, so README.md was thrown onto a line of its own. She found
   it on 2026-10-04. */
p.code-line > code {
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
/* The lines she quotes back are her green, quieter: mixed 60 to 40 with a
   dark gray, so her own words and the words she is pointing at read apart.
   Her request, 2026-10-04: "slightly closer to dark-gray, but still green". */
.said .what blockquote { color: color-mix(in srgb, var(--dexterity) 60%, #555555); }

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

]]

M.STYLE_HARNESS = [[
/* Lines the harness wrote before the first request: neither side, quiet. */
.harness { opacity: 0.6; font-size: 0.9rem; text-align: center; }
.harness .who { justify-content: center; }

]]

M.STYLE_CONTENTS = [[
/* THE RECAPS, AT THE TOP. Each is a place to jump into the conversation, so
   the link leads an entry and the prose sits under it. */
.contents { border-bottom: 1px solid var(--plain); margin: 1.5rem 0 2rem; }
.contents h2 { font-size: 1rem; }
.contents ol { padding-left: 1.6rem; }
.contents li { margin: 0 0 1.1rem; }
.contents .when { opacity: 0.6; font-size: 0.8rem; margin-right: 0.5rem; }
.contents p { margin: 0.2rem 0 0; }

]]

M.STYLE_BOTTOM = [[
.model { color: var(--constitution); }
.continued { color: var(--strength); }

a { color: var(--intellect); }
h1, h2, h3, h4 { color: var(--spirit); line-height: 1.25; }
.masthead { border-bottom: 1px solid var(--plain); padding-bottom: 1rem; }
.masthead .facts { font-size: 0.8rem; opacity: 0.7; }
.back { display: inline-block; margin-bottom: 1.5rem; }

/* Where a commit happened. A reader sent here from the story page lands on
   the line with a little room above it, and the line lights up so the eye
   finds it at once in a long page. :target is the browser doing this on its
   own; nothing on this site runs a script. */
/* THE FILM BESIDE EACH MESSAGE (issue 10-007).
   A square like a profile picture: hers on the left, the assistant's on the
   right and mirrored left to right, so the two face each other across the
   conversation.

   It sits OUTSIDE the reading column, beyond the green or blue bar, her
   request on 2026-10-02: "They should not be part of the central column, but
   rather just outside of it." So the column keeps its full width for the
   words, and the film hangs in the margin level with the top of its message.
   It is pinned to its turn (position: absolute against the turn), then pushed
   just past the turn's edge: right: 100% puts its right edge on the turn's
   left edge, and the margin is the gap between film and bar.

   A window too narrow to have margins that wide (the column, plus a film and
   a gap on each side) brings the films back inside the column, beside the
   words, rather than pushing them off the screen where nobody would see
   them. */
.has-film { position: relative; }
.film { position: absolute; top: 0; border-radius: 0.4rem; background: #000; }
.said .film { right: 100%; margin-right: 1.25rem; }
.replied .film { left: 100%; margin-left: 1.25rem; transform: scaleX(-1); }

@media (max-width: 1200px) {
  .has-film { display: flex; gap: 0.9rem; align-items: flex-start; }
  .replied.has-film { flex-direction: row-reverse; }
  .film { position: static; flex: none; width: 64px; height: 64px; margin: 0; }
  .turn-body { flex: 1; min-width: 0; }
}

.commit-mark { scroll-margin-top: 30vh; }
.commit-mark:target { color: var(--spirit); outline: 1px solid var(--spirit);
                      outline-offset: 0.3rem; }
]]

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
--   opts.title        string, names the page
--   opts.back         string or nil, the link home
--   opts.base_path    string, the route back to the site root, where the
--                     font and the films are (default ".")
--   opts.colours_css  string, a :root { } block of the colours; the builder
--                     makes it from the project's settings
--   opts.films        list in exchange order, each a film's file name
--                     (string) or false; nil for no films at all
--   opts.film_size    whole number, the film's side in CSS pixels (64)
--   opts.anchor       false turns off the per-turn ids and with them the
--                     Contents links, which would have nowhere to land
function M.render(conversation, opts)
  opts = opts or {}
  local markdown, page_head = libs()
  local reader = dofile(HERE .. "transcript-reader.lua")
  if not opts.colours_css then
    -- Without colours every var(--...) in the sheet resolves to nothing, and
    -- text goes black on black: a page that looks blank rather than wrong.
    error("the conversation page needs opts.colours_css")
  end

  local title = opts.title or ("conversation " .. conversation.session_id)
  local anchored = opts.anchor ~= false

  -- Which optional rules this page needs (see M.stylesheet).
  local uses = { harness = false, contents = #conversation.contents > 0 }
  for _, exchange in ipairs(conversation.exchanges) do
    if exchange.kind == "harness" then
      uses.harness = true
    end
  end

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
  -- The films sit in one folder at the site's root, beside the fonts.
  local films = opts.films or {}
  local film_size = opts.film_size or 64
  for index, exchange in ipairs(conversation.exchanges) do
    local film = false
    if films[index] then
      film = { src = (opts.base_path or ".") .. "/films/" .. films[index], size = film_size }
    end
    local turn = turn_html(markdown, exchange, previous_model, film)
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
      extra_css = opts.colours_css .. "\n" .. M.stylesheet(uses),
    }),
    "<body>",
    table.concat(body, "\n"),
    "</body>",
    "</html>",
  }, "\n")
end
-- }}}

return M
