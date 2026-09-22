-- build-reports.lua
--
-- Turns a progress report, written once as a plain data table, into the two
-- forms a reader wants: a styled HTML page to look at, and a Markdown file to
-- read in a terminal or paste into anything else.
--
-- The point of the split is that the words live in exactly one place. A report
-- is a Lua table in reports/; this program is the only thing that knows what a
-- heading looks like, what colour a chart bar is, or how a table is drawn. Edit
-- the data, rerun this, and both files are rewritten. Nothing is ever edited by
-- hand on the far side, which is how the two forms are prevented from drifting
-- apart and disagreeing about what happened in a given fortnight.
--
-- Usage:  luajit build-reports.lua [DIR]
--   DIR defaults to the hard-coded path below; every path this program touches
--   is built relative to it.

-- {{{ configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/progress-reports"
if arg and arg[1] then DIR = arg[1] end

local REPORTS_DIR = DIR .. "/reports"

-- Where a transcript link points. The files also sit beside this directory on
-- disk, but a page that gets shared is a page whose relative links are dead, so
-- the canonical target is the copy on the forge.
local FORGE = "https://github.com/gabrilend/ai-stuff/blob/main/"
-- }}}

-- {{{ local function escape_html(text)
-- Turns the four characters that mean something to a browser into the entities
-- that draw them literally. Applied to every scrap of prose before any of our
-- own tags are added, so a stray ampersand in a project name cannot break a page.
local function escape_html(text)
  text = text:gsub("&", "&amp;")
  text = text:gsub("<", "&lt;")
  text = text:gsub(">", "&gt;")
  return text
end
-- }}}

-- {{{ local function inline_to_html(text)
-- The report data uses Markdown's own emphasis marks, because Markdown is one of
-- the two outputs and passing them through untouched costs nothing there. Here
-- they become real tags. Double asterisk first, so that the single-asterisk pass
-- cannot eat half of a bold run and leave the other half stranded.
local function inline_to_html(text)
  text = escape_html(text)
  text = text:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
  text = text:gsub("%*(.-)%*", "<em>%1</em>")
  text = text:gsub("`(.-)`", "<code>%1</code>")
  return text
end
-- }}}

-- {{{ local function commas(number)
-- Thousands separators, inserted from the right. Figures in a progress report
-- are read rather than computed with, and an unbroken six-digit run is a figure
-- nobody actually reads.
local function commas(number)
  local text = tostring(math.floor(number))
  local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  out = out:gsub("^,", "")
  return out
end
-- }}}

-- {{{ local function nice_scale(peak)
-- Picks the gap between gridlines, and how many of them, so that every printed
-- label is a whole number a person would choose. Returns the top of the scale
-- and the number of intervals below it.
--
-- The trap this exists to avoid: fixing the count at four and rounding only the
-- top produces a top of 50 for a peak of 43, whose quarter marks are 12.5 and
-- 37.5. Printed as integers those read 12 and 37, which are lines drawn in one
-- place and labelled with another. Choosing the *gap* first and letting the
-- count follow means a label can never be a fraction.
local function nice_scale(peak)
  local gaps = { 1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000 }
  for _, gap in ipairs(gaps) do
    local count = math.ceil(peak / gap)
    -- three to six bands: fewer and the chart has no vertical reference,
    -- more and the gridlines start competing with the bars for attention
    if count >= 3 and count <= 6 then
      return gap * count, count
    end
  end
  return peak, 4
end
-- }}}

-- {{{ local function draw_day_chart(days)
-- One column per day in the window, drawn straight from the same numbers the
-- prose quotes. A day with no commits gets a hairline rather than nothing at
-- all: zero that was observed reads differently from a day that is missing, and
-- a gap in a bar chart is ambiguous between the two.
local function draw_day_chart(days)
  local peak = 0
  for _, day in ipairs(days) do
    if day.value > peak then peak = day.value end
  end
  local top, bands = nice_scale(peak)

  local LEFT, RIGHT, BASE, HEAD = 40, 770, 176, 12
  local span = BASE - HEAD
  local slot = (RIGHT - LEFT) / #days
  local bar_width = math.min(34, slot * 0.62)

  local parts = {}
  local function add(line) parts[#parts + 1] = line end

  -- gridlines, and the value each one stands for
  for tick = 0, bands do
    local value = top * tick / bands
    local y = BASE - (value / top) * span
    local class = (tick == 0) and "baseline" or "gridline"
    add(string.format('    <line class="%s" x1="%d" y1="%.1f" x2="%d" y2="%.1f"></line>',
      class, LEFT, y, RIGHT, y))
    add(string.format('    <text class="tick" x="%d" y="%.1f" text-anchor="end">%d</text>',
      LEFT - 6, y + 3, value))
  end

  -- the bars themselves
  for index, day in ipairs(days) do
    local x = LEFT + slot * (index - 1) + (slot - bar_width) / 2
    local height = (day.value / top) * span
    if day.value == 0 then
      add(string.format('    <rect class="bar-zero" x="%.1f" y="%.1f" width="%.1f" height="1"></rect>',
        x, BASE - 1, bar_width))
    else
      if height < 2 then height = 2 end
      add(string.format('    <rect class="bar-fill" x="%.1f" y="%.1f" width="%.1f" height="%.1f"></rect>',
        x, BASE - height, bar_width, height))
    end
    -- only the peak carries a printed figure; labelling every bar turns the
    -- chart back into the table it is standing in for
    if day.value == peak then
      add(string.format('    <text class="bar-label" x="%.1f" y="%.1f" text-anchor="middle">%d</text>',
        x + bar_width / 2, BASE - height - 5, day.value))
    end
    local class = day.emphasis and "tick-strong" or "tick"
    add(string.format('    <text class="%s" x="%.1f" y="%d" text-anchor="middle">%s</text>',
      class, x + bar_width / 2, BASE + 16, escape_html(day.label)))
  end

  return table.concat(parts, "\n")
end
-- }}}

-- {{{ threads
-- A thread is a rule the collection learned, marked wherever it appears rather
-- than collected into a chapter at the end. Marking it in place is what makes
-- the connection legible: the reader meets "fallbacks hide bugs" on the day it
-- was written and again, marked the same way, each time it cost work to apply.
--
-- PART_FILE is filled in by main() before anything renders, so a thread can
-- link back to the part that started it.
local PART_FILE = {}

local function render_thread_html(block)
  local origin
  if block.first then
    local href = PART_FILE[block.first]
    origin = href
      and string.format('<a href="%s.html">first seen in Part %d</a>', href, block.first)
      or ("first seen in Part " .. block.first)
  else
    origin = "starts here"
  end
  return table.concat({
    '        <aside class="thread">',
    '          <p class="thread-tag">Thread · ' .. escape_html(block.name)
      .. ' <span>' .. origin .. "</span></p>",
    "          <p>" .. inline_to_html(block.text) .. "</p>",
    "        </aside>",
  }, "\n")
end
-- }}}

-- {{{ local function render_transcripts_html(block)
-- The working conversations behind a section, linked in order.
--
-- Links point at the forge rather than at the copy beside this directory, so
-- they survive the page being shared. A transcript that exists on disk but was
-- never committed has nothing to point at, and is named without a link rather
-- than quietly dropped.
--
-- A session that spawned sub-agents leaves one file per agent beside the main
-- one. Those are counted rather than listed; one January session has 296 of
-- them and listing those would bury the section they belong to.
local function render_transcripts_html(block)
  local items = {}
  for _, entry in ipairs(block.items) do
    local extra = (entry.agents and entry.agents > 0)
      and string.format(' <span>+%d agent</span>', entry.agents) or ""
    if entry.untracked then
      -- On disk here and not in the repository, so there is nothing to point at.
      -- Named rather than dropped: a conversation that exists and was never
      -- pushed is a different fact from one that does not exist.
      items[#items + 1] = string.format(
        '            <li><em>%s</em> <span>not pushed</span>%s</li>',
        escape_html(entry.label), extra)
    else
      items[#items + 1] = string.format(
        '            <li><a href="%s%s/llm-transcripts/%s">%s</a>%s</li>',
        FORGE, block.project, entry.file, escape_html(entry.label), extra)
    end
  end
  return table.concat({
    '        <div class="transcripts">',
    '          <p class="transcripts-tag">Working transcripts · '
      .. escape_html(block.project) .. "</p>",
    "          <ol>",
    table.concat(items, "\n"),
    "          </ol>",
    "        </div>",
  }, "\n")
end
-- }}}

-- {{{ local function render_totals(totals)
-- The figures under the title. A free list of value/label pairs rather than
-- fixed fields, because what is worth counting differs by part: a part built
-- from commits counts issue files, and the opening counts parts and projects.
--
-- Issue files are the unit throughout. This is a record of a project, and the
-- project's own unit of work is a written blueprint, not a commit or a line.
local function render_totals(totals)
  local out = {}
  for _, item in ipairs(totals) do
    out[#out + 1] = "      <span><b>" .. escape_html(item.value) .. "</b> "
      .. escape_html(item.label) .. "</span>"
  end
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function month_index(label, origin)
-- Months since an origin, both written "YYYY-MM". Used to place a span bar on a
-- timeline whose columns are months rather than days.
local function month_index(label, origin)
  local y, m = label:match("^(%d+)%-(%d+)$")
  local oy, om = origin:match("^(%d+)%-(%d+)$")
  return (tonumber(y) - tonumber(oy)) * 12 + (tonumber(m) - tonumber(om))
end
-- }}}

-- {{{ local function render_spans_html(block)
-- A horizontal span per project: when its files were first and last written.
-- Drawn as positioned bars rather than SVG because each row carries a name and a
-- count as real text, which stays selectable and wraps on a narrow screen.
--
-- A single-month span still gets a visible bar. A project that existed for one
-- month and a project whose bar is too short to see are different facts, and the
-- chart must not turn the first into the second.
local function render_spans_html(block)
  local total = month_index(block.to, block.from) + 1
  local rows = {}
  for _, item in ipairs(block.items) do
    local start = month_index(item.first, block.from)
    local width = month_index(item.last, block.from) - start + 1
    rows[#rows + 1] = table.concat({
      '          <div class="span-row">',
      '            <span class="span-name">' .. escape_html(item.name) .. "</span>",
      '            <span class="span-track"><i style="left:'
        .. string.format("%.2f%%;width:%.2f%%", start / total * 100,
             math.max(width / total * 100, 1.2)) .. '"></i></span>',
      '            <span class="span-count">' .. commas(item.count) .. "</span>",
      "          </div>",
    }, "\n")
  end

  -- year gridlines, so a bar can be read against a date without a ruler
  local marks = {}
  for index = 0, total - 1 do
    local year, month = block.from:match("^(%d+)%-(%d+)$")
    local absolute = tonumber(month) + index
    if ((absolute - 1) % 12) == 0 then
      local label = tostring(tonumber(year) + math.floor((absolute - 1) / 12))
      marks[#marks + 1] = string.format(
        '            <span class="span-year" style="left:%.2f%%">%s</span>',
        index / total * 100, label)
    end
  end

  return table.concat({
    '        <figure class="wide spans">',
    '          <div class="span-axis"><span class="span-name"></span>'
      .. '<span class="span-track">' .. table.concat(marks, "\n") .. "</span>"
      .. '<span class="span-count">files</span></div>',
    table.concat(rows, "\n"),
    "          <figcaption>" .. inline_to_html(block.caption) .. "</figcaption>",
    "        </figure>",
  }, "\n")
end
-- }}}

-- {{{ local function render_blocks_html(blocks)
-- A block is one paragraph-shaped thing. The kinds are deliberately few: prose,
-- a dated entry, a sub-heading, a pulled-out sentence, and a list of findings.
-- Anything that wanted a sixth kind has so far turned out to be one of these
-- five wearing a different name.
local function render_blocks_html(blocks)
  local out = {}
  for _, block in ipairs(blocks) do
    if block.kind == "p" then
      out[#out + 1] = "        <p>" .. inline_to_html(block.text) .. "</p>"
    elseif block.kind == "lead" then
      out[#out + 1] = '        <p class="lead">' .. inline_to_html(block.text) .. "</p>"
    elseif block.kind == "h" then
      out[#out + 1] = "        <h4>" .. inline_to_html(block.text) .. "</h4>"
    elseif block.kind == "pull" then
      out[#out + 1] = '        <p class="pull">' .. inline_to_html(block.text) .. "</p>"
    elseif block.kind == "entry" then
      out[#out + 1] = '        <p class="entry"><span class="when">'
        .. escape_html(block.when) .. "</span>" .. inline_to_html(block.text) .. "</p>"
    elseif block.kind == "transcripts" then
      out[#out + 1] = render_transcripts_html(block)
    elseif block.kind == "thread" then
      out[#out + 1] = render_thread_html(block)
    elseif block.kind == "spans" then
      out[#out + 1] = render_spans_html(block)
    elseif block.kind == "findings" then
      local items = {}
      for _, item in ipairs(block.items) do
        items[#items + 1] = "          <li>" .. inline_to_html(item) .. "</li>"
      end
      out[#out + 1] = '        <ul class="findings">\n' .. table.concat(items, "\n") .. "\n        </ul>"
    end
  end
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function render_blocks_markdown(blocks)
-- The same five kinds, flattened. A pulled-out sentence becomes a block quote,
-- a dated entry keeps its date as bold lead-in, and everything else is a
-- paragraph, because Markdown has no way to say "this sentence carries the
-- section" that a terminal will honour.
local function render_blocks_markdown(blocks)
  local out = {}
  for _, block in ipairs(blocks) do
    if block.kind == "p" or block.kind == "lead" then
      out[#out + 1] = block.text
    elseif block.kind == "h" then
      out[#out + 1] = "#### " .. block.text
    elseif block.kind == "pull" then
      out[#out + 1] = "> " .. block.text
    elseif block.kind == "entry" then
      out[#out + 1] = "**" .. block.when .. "** — " .. block.text
    elseif block.kind == "transcripts" then
      local rows = {}
      for _, entry in ipairs(block.items) do
        if entry.untracked then
          rows[#rows + 1] = "- " .. entry.label .. " (not pushed)"
        else
          rows[#rows + 1] = "- [" .. entry.label .. "](" .. FORGE .. block.project
            .. "/llm-transcripts/" .. entry.file .. ")"
            .. ((entry.agents and entry.agents > 0) and (" +" .. entry.agents .. " agent") or "")
        end
      end
      out[#out + 1] = "**Working transcripts — " .. block.project .. "**\n\n"
        .. table.concat(rows, "\n")
    elseif block.kind == "thread" then
      out[#out + 1] = "> **Thread — " .. block.name .. "** ("
        .. (block.first and ("first seen in Part " .. block.first) or "starts here")
        .. ")\n>\n> " .. block.text
    elseif block.kind == "spans" then
      local rows = { "| Project | First | Last | Files |", "| --- | --- | --- | ---: |" }
      for _, item in ipairs(block.items) do
        rows[#rows + 1] = "| " .. item.name .. " | " .. item.first .. " | "
          .. item.last .. " | " .. commas(item.count) .. " |"
      end
      out[#out + 1] = table.concat(rows, "\n") .. "\n\n" .. block.caption
    elseif block.kind == "findings" then
      local items = {}
      for _, item in ipairs(block.items) do
        items[#items + 1] = "- " .. item
      end
      out[#out + 1] = table.concat(items, "\n")
    end
  end
  return table.concat(out, "\n\n")
end
-- }}}

-- {{{ local function render_stats_html(stats)
-- The strip of figures under a project's name. Six cells, hairline-divided,
-- monospaced so the digits line up down the page from one project to the next.
local function render_stats_html(stats)
  if not stats then return "" end
  local cells = {}
  for _, stat in ipairs(stats) do
    local suffix = stat.note and (' <small>' .. escape_html(stat.note) .. '</small>') or ""
    cells[#cells + 1] = '          <div><span class="k">' .. escape_html(stat.key)
      .. '</span><span class="v">' .. escape_html(stat.value) .. suffix .. "</span></div>"
  end
  return '        <div class="stats">\n' .. table.concat(cells, "\n") .. "\n        </div>"
end
-- }}}

-- {{{ the stylesheet
-- One stylesheet, used by every page this program writes. It lives here as a
-- constant rather than inside the report renderer because the index page needs
-- the identical tokens: two pages that look almost the same are worse than two
-- that look different, and a second copy of these colours would drift.
local STYLESHEET = [==[
<style>
/* Drafting blue, because in this repository an issue file is called a
   blueprint and a report about them may as well be one. Every colour is
   declared on bare :root first, so a browser with no theme preference stamped
   on it still resolves a complete set. */
:root {
  --paper:#EBF0F4; --surface:#F9FBFC; --surface-2:#E2E9EE;
  --ink:#12202B; --ink-2:#354A59; --muted:#64798A;
  --rule:#C3D0DA; --rule-soft:#D6E0E7;
  --accent:#0F4C8A; --accent-2:#2E7CC4; --accent-wash:#DCE8F3;
  --built:#1B6B58; --open:#8C5F10; --blocked:#A03A2C;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --paper:#0B131A; --surface:#111C25; --surface-2:#17242F;
    --ink:#D9E4EC; --ink-2:#AFC0CD; --muted:#7D91A0;
    --rule:#223441; --rule-soft:#1B2A35;
    --accent:#6FA6E4; --accent-2:#8FBEF0; --accent-wash:#152634;
    --built:#4FB99A; --open:#D6A448; --blocked:#E27F72;
  }
}
:root[data-theme="dark"] {
  --paper:#0B131A; --surface:#111C25; --surface-2:#17242F;
  --ink:#D9E4EC; --ink-2:#AFC0CD; --muted:#7D91A0;
  --rule:#223441; --rule-soft:#1B2A35;
  --accent:#6FA6E4; --accent-2:#8FBEF0; --accent-wash:#152634;
  --built:#4FB99A; --open:#D6A448; --blocked:#E27F72;
}
* { box-sizing:border-box; }
html { -webkit-text-size-adjust:100%; }
body {
  margin:0; background:var(--paper); color:var(--ink);
  font-family:"Newsreader",Georgia,"Times New Roman",serif;
  font-size:18px; line-height:1.62; font-optical-sizing:auto;
  -webkit-font-smoothing:antialiased;
}
img { max-width:100%; }
.shell {
  max-width:1240px; margin:0 auto; padding:0 28px 96px;
  display:grid; grid-template-columns:232px minmax(0,1fr); gap:56px; align-items:start;
}
@media (max-width:1040px) {
  .shell { grid-template-columns:minmax(0,1fr); gap:0; padding:0 20px 72px; }
  .rail { position:static; margin:0 0 40px; }
}
.masthead { grid-column:1/-1; border-bottom:2px solid var(--ink); padding:56px 0 22px; margin-bottom:40px; }
.eyebrow {
  font-family:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,monospace;
  font-size:11px; font-weight:500; letter-spacing:.14em; text-transform:uppercase; color:var(--accent);
}
h1 {
  font-family:"Bricolage Grotesque","Helvetica Neue",Arial,sans-serif;
  font-weight:700; font-size:clamp(38px,6vw,62px); line-height:1.02;
  letter-spacing:-.022em; margin:14px 0 0; text-wrap:balance;
}
.dek { margin:16px 0 0; max-width:62ch; font-size:20px; color:var(--ink-2); }
.masthead-meta {
  display:flex; flex-wrap:wrap; gap:8px 26px; margin-top:26px;
  font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12px; color:var(--muted);
}
.masthead-meta b { color:var(--ink); font-weight:500; }
.rail { position:sticky; top:24px; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12px; }
.rail h2 {
  font-size:11px; letter-spacing:.14em; text-transform:uppercase; color:var(--muted);
  font-weight:500; margin:0 0 14px; padding-bottom:8px; border-bottom:1px solid var(--rule);
}
.rail ol { list-style:none; margin:0; padding:0; display:flex; flex-direction:column; gap:3px; }
.rail a {
  display:grid; grid-template-columns:1fr auto; align-items:baseline; gap:8px;
  padding:6px 8px 7px; border-radius:2px; text-decoration:none; color:var(--ink-2);
  border-left:2px solid transparent;
}
.rail a:hover { background:var(--accent-wash); color:var(--ink); border-left-color:var(--accent); }
.rail a:focus-visible { outline:2px solid var(--accent); outline-offset:1px; }
.rail .n { color:var(--muted); font-variant-numeric:tabular-nums; }
.rail .bar { grid-column:1/-1; height:3px; background:var(--rule-soft); margin-top:5px; position:relative; }
.rail .bar i { position:absolute; inset:0 auto 0 0; background:var(--accent); display:block; }
.rail .foot { margin-top:20px; padding-top:12px; border-top:1px solid var(--rule); color:var(--muted); line-height:1.55; }
.rail .foot a { display:inline; padding:0; border:0; }
main { min-width:0; }
main > * { max-width:68ch; }
main > .wide, main > figure, main > .scroll { max-width:none; }
h2.section {
  font-family:"Bricolage Grotesque",Arial,sans-serif; font-size:13px; font-weight:600;
  letter-spacing:.16em; text-transform:uppercase; color:var(--accent);
  margin:72px 0 22px; padding-bottom:9px; border-bottom:1px solid var(--rule); max-width:none;
}
h2.section:first-child { margin-top:0; }
p { margin:0 0 1.05em; }
p.lead { font-size:20px; color:var(--ink-2); }
strong { font-weight:600; color:var(--ink); }
a { color:var(--accent); }
code { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:.88em; background:var(--surface-2); padding:1px 4px; border-radius:2px; }
.project { margin:0 0 8px; padding:40px 0 0; max-width:none; }
.project + .project { border-top:1px solid var(--rule-soft); margin-top:44px; }
.project-head { max-width:68ch; }
.project h3 {
  font-family:"Bricolage Grotesque",Arial,sans-serif; font-size:clamp(26px,3.4vw,34px);
  font-weight:600; letter-spacing:-.018em; line-height:1.12; margin:0; text-wrap:balance;
}
.project h3 .slug {
  display:block; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12px;
  font-weight:400; letter-spacing:.04em; color:var(--muted); margin-bottom:8px;
}
.project .identity { margin:12px 0 0; color:var(--ink-2); max-width:66ch; }
.project .body { max-width:68ch; margin-top:26px; }
.project h4 {
  font-family:"JetBrains Mono",ui-monospace,monospace; font-size:11px; font-weight:500;
  letter-spacing:.13em; text-transform:uppercase; color:var(--muted); margin:30px 0 10px;
}
.stats { display:flex; flex-wrap:wrap; margin:22px 0 0; border-top:1px solid var(--rule); border-bottom:1px solid var(--rule); }
.stats div { flex:1 1 116px; padding:12px 16px 13px; border-right:1px solid var(--rule-soft); font-family:"JetBrains Mono",ui-monospace,monospace; }
.stats div:last-child { border-right:0; }
.stats .k { font-size:10px; letter-spacing:.1em; text-transform:uppercase; color:var(--muted); display:block; margin-bottom:4px; }
.stats .v { font-size:19px; font-weight:500; font-variant-numeric:tabular-nums; color:var(--ink); }
.stats .v small { font-size:11px; color:var(--muted); font-weight:400; letter-spacing:.02em; }
.entry { margin:0 0 1.05em; padding-left:17px; border-left:2px solid var(--rule); }
.entry .when {
  font-family:"JetBrains Mono",ui-monospace,monospace; font-size:11px; letter-spacing:.06em;
  text-transform:uppercase; color:var(--accent); display:block; margin-bottom:3px;
}
ul.findings { list-style:none; margin:0 0 1.2em; padding:0; display:flex; flex-direction:column; gap:15px; }
ul.findings > li { padding-left:17px; border-left:2px solid var(--accent-2); }
.pull {
  font-family:"Bricolage Grotesque",Arial,sans-serif; font-size:21px; font-weight:500;
  line-height:1.34; letter-spacing:-.012em; color:var(--ink); border-left:3px solid var(--accent);
  padding:4px 0 4px 20px; margin:26px 0; text-wrap:pretty;
}
.transcripts {
  margin:24px 0; padding:14px 18px 6px; border:1px solid var(--rule);
  border-radius:2px; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12px;
}
.transcripts-tag {
  font-size:10px; letter-spacing:.11em; text-transform:uppercase;
  color:var(--muted); margin:0 0 8px;
}
.transcripts ol {
  margin:0 0 10px; padding:0; list-style:none;
  display:flex; flex-wrap:wrap; gap:4px 10px;
}
.transcripts li::after { content:"·"; color:var(--rule); margin-left:10px; }
.transcripts li:last-child::after { content:""; }
.transcripts a { color:var(--accent); text-decoration:none; border-bottom:1px solid var(--rule); }
.transcripts a:hover { border-bottom-color:var(--accent); }
.transcripts span { color:var(--muted); font-size:10px; }
.transcripts em { color:var(--muted); font-style:normal; }
.thread {
  margin:26px 0; padding:16px 20px 4px; background:var(--accent-wash);
  border-left:3px solid var(--accent-2); border-radius:2px;
}
.thread p { margin:0 0 1em; }
.thread-tag {
  font-family:"JetBrains Mono",ui-monospace,monospace; font-size:10.5px; font-weight:500;
  letter-spacing:.11em; text-transform:uppercase; color:var(--accent); margin:0 0 8px;
}
.thread-tag span { color:var(--muted); font-weight:400; letter-spacing:.06em; }
.thread-tag a { color:var(--muted); }
.scroll { overflow-x:auto; margin:0 0 1.4em; }
table { border-collapse:collapse; width:100%; min-width:520px; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:13px; }
caption { caption-side:top; text-align:left; font-size:11px; letter-spacing:.12em; text-transform:uppercase; color:var(--muted); padding-bottom:9px; }
th { text-align:left; font-weight:500; font-size:10.5px; letter-spacing:.09em; text-transform:uppercase; color:var(--muted); padding:0 14px 7px 0; border-bottom:1px solid var(--rule); }
td { padding:9px 14px 9px 0; border-bottom:1px solid var(--rule-soft); vertical-align:top; }
td.num, th.num { text-align:right; font-variant-numeric:tabular-nums; padding-right:0; }
tbody tr:hover td { background:var(--accent-wash); }
table.prose { font-family:"Newsreader",Georgia,serif; font-size:16px; }
table.prose td { line-height:1.5; }
.chip {
  display:inline-block; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:10px;
  font-weight:500; letter-spacing:.07em; text-transform:uppercase; padding:2px 7px 3px;
  border:1px solid currentColor; border-radius:2px; white-space:nowrap;
}
.chip.built { color:var(--built); }
.chip.open { color:var(--open); }
.chip.blocked { color:var(--blocked); }
.spans { margin:26px 0 34px; font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12px; }
.span-axis, .span-row { display:flex; align-items:center; gap:12px; }
.span-axis { color:var(--muted); font-size:10px; letter-spacing:.08em; text-transform:uppercase; padding-bottom:6px; border-bottom:1px solid var(--rule); margin-bottom:6px; }
.span-row { padding:3px 0; }
.span-row:hover { background:var(--accent-wash); }
.span-name { flex:0 0 220px; color:var(--ink-2); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.span-track { flex:1 1 auto; position:relative; height:14px; }
.span-row .span-track::before { content:""; position:absolute; inset:6px 0 auto 0; height:1px; background:var(--rule-soft); }
.span-track i { position:absolute; top:3px; height:8px; background:var(--accent); border-radius:1px; display:block; }
.span-year { position:absolute; top:0; font-size:10px; color:var(--muted); border-left:1px solid var(--rule); padding-left:3px; }
.span-count { flex:0 0 54px; text-align:right; color:var(--muted); font-variant-numeric:tabular-nums; }
@media (max-width:700px) { .span-name { flex-basis:130px; } }
figure { margin:0 0 34px; }
figure svg { display:block; width:100%; height:auto; }
figcaption { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:11.5px; color:var(--muted); line-height:1.55; margin-top:10px; max-width:72ch; }
.tick { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:10px; fill:var(--muted); }
.tick-strong { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:10px; fill:var(--ink); font-weight:500; }
.gridline { stroke:var(--rule-soft); stroke-width:1; }
.baseline { stroke:var(--rule); stroke-width:1; }
.bar-fill { fill:var(--accent); }
.bar-zero { fill:var(--rule); }
.bar-label { font-family:"JetBrains Mono",ui-monospace,monospace; font-size:10px; fill:var(--ink); font-weight:500; }
.partnav {
  display:flex; gap:16px; align-items:stretch; margin-top:64px; padding-top:20px;
  border-top:2px solid var(--ink); font-family:"JetBrains Mono",ui-monospace,monospace; font-size:13px;
}
.partnav a { text-decoration:none; color:var(--ink); padding:10px 14px; border:1px solid var(--rule); border-radius:2px; line-height:1.35; }
.partnav a:hover { background:var(--accent-wash); border-color:var(--accent); }
.partnav a:focus-visible { outline:2px solid var(--accent); outline-offset:2px; }
.partnav span { display:block; font-size:10px; letter-spacing:.12em; text-transform:uppercase; color:var(--muted); margin-bottom:3px; }
.nav-prev { flex:1 1 0; }
.nav-next { flex:1 1 0; text-align:right; }
.nav-up { flex:0 0 auto; align-self:center; color:var(--muted); }
@media (max-width:600px) { .partnav { flex-direction:column; } .nav-next { text-align:left; } }
.colophon {
  margin-top:76px; padding-top:20px; border-top:2px solid var(--ink);
  font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12px; line-height:1.62;
  color:var(--muted); max-width:74ch;
}
.colophon b { color:var(--ink-2); font-weight:500; }
@media (prefers-reduced-motion:reduce) { * { animation:none !important; transition:none !important; } }
</style>
]==]
-- }}}

-- {{{ local function html_document(report)
-- The whole page, assembled. The style block is written here rather than beside
-- the data because a report is words and figures; how those look is this
-- program's business and nobody else's.
local function html_document(report, neighbours)
  local rail, sections = {}, {}

  -- Reading order is the point: this is one essay in parts, so every part ends
  -- with the way onward and the way back. A part with no neighbour on a side
  -- prints nothing there rather than a dead link.
  local nav = ""
  if neighbours then
    local left, right = "", ""
    if neighbours.prev then
      left = string.format('<a class="nav-prev" href="%s.html"><span>Previous</span>%s</a>',
        neighbours.prev.stem, escape_html(neighbours.prev.title))
    end
    if neighbours.next then
      right = string.format('<a class="nav-next" href="%s.html"><span>Next</span>%s</a>',
        neighbours.next.stem, escape_html(neighbours.next.title))
    end
    nav = '    <nav class="partnav">' .. left
      .. '<a class="nav-up" href="index.html">Contents</a>' .. right .. "</nav>"
  end
  local widest = 0
  for _, project in ipairs(report.projects) do
    if project.commits > widest then widest = project.commits end
  end

  for index, project in ipairs(report.projects) do
    rail[#rail + 1] = string.format(
      '      <li><a href="#%s"><span>%s</span><span class="n">%d</span>'
        .. '<span class="bar"><i style="width:%.0f%%"></i></span></a></li>',
      project.id, escape_html(project.short or project.name), project.commits,
      project.commits / widest * 100)

    sections[#sections + 1] = table.concat({
      string.format('    <section class="project" id="%s">', project.id),
      '      <div class="project-head">',
      string.format('        <h3><span class="slug">%02d · %s</span>%s</h3>',
        index,
        -- a page whose subject is not commits says so in the slug rather than
        -- printing a count of a thing it does not measure
        escape_html(project.slug or (project.commits .. " commits")),
        escape_html(project.name)),
      '        <p class="identity">' .. inline_to_html(project.identity) .. "</p>",
      "      </div>",
      render_stats_html(project.stats),
      '      <div class="body">',
      render_blocks_html(project.blocks),
      "      </div>",
      "    </section>",
    }, "\n")
  end

  local work_rows = {}
  for _, row in ipairs(report.work) do
    work_rows[#work_rows + 1] = string.format(
      '          <tr><td>%s</td><td class="num">%d</td><td class="num">%s</td><td class="num">%s</td></tr>',
      escape_html(row.name), row.commits, commas(row.added), commas(row.removed))
  end

  local open_rows = {}
  for _, row in ipairs(report.open) do
    open_rows[#open_rows + 1] = table.concat({
      "          <tr>",
      "            <td>" .. escape_html(row.project) .. "</td>",
      string.format('            <td><span class="chip %s">%s</span></td>',
        row.tone, escape_html(row.state)),
      "            <td>" .. inline_to_html(row.waiting) .. "</td>",
      "          </tr>",
    }, "\n")
  end

  -- Patterns were once a section in every part, which meant the same handful of
  -- observations restated eight times. They are threads now, marked where they
  -- happen. A part may still carry a patterns list; most no longer do.
  local patterns = {}
  for _, item in ipairs(report.patterns or {}) do
    patterns[#patterns + 1] = "      <li>" .. inline_to_html(item) .. "</li>"
  end

  return table.concat({
[[<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>]] .. escape_html(report.title) .. [[</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,600;12..96,700&family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&family=JetBrains+Mono:wght@400;500;700&display=swap">
]] .. STYLESHEET .. [[
</head>
<body>
<div class="shell">

  <header class="masthead">
    <div class="eyebrow">]] .. escape_html(report.eyebrow) .. [[</div>
    <h1>]] .. escape_html(report.title) .. [[</h1>
    <p class="dek">]] .. inline_to_html(report.dek) .. [[</p>
    <div class="masthead-meta">
]] .. render_totals(report.totals) .. [[
    </div>
  </header>

  <nav class="rail" aria-label="Projects, ordered by commits in this window">
    <h2>Projects · commits</h2>
    <ol>
]] .. table.concat(rail, "\n") .. [[

    </ol>
    <div class="foot">
]] .. ((#patterns > 0) and '      <a href="#patterns">Patterns across the window</a><br>\n' or "") .. [[
      <a href="#open">What is open</a><br>
      <a href="#tree">Notes on the tree</a>
    </div>
  </nav>

  <main>

    <h2 class="section">The window</h2>

]] .. render_blocks_html(report.intro) .. [[


    <figure class="wide">
      <svg viewBox="0 0 780 224" role="img" aria-label="]] .. escape_html(report.chart_alt) .. [[">
]] .. draw_day_chart(report.days) .. [[

        <text class="tick" x="40" y="212">]] .. escape_html(report.days[1].month or "") .. [[</text>
        <text class="tick" x="770" y="212" text-anchor="end">]] .. escape_html(
          -- a window inside one month prints its name once; repeating it at both
          -- ends reads as two months that happen to share a name
          (report.days[#report.days].month ~= report.days[1].month)
            and (report.days[#report.days].month or "") or "") .. [[</text>
      </svg>
      <figcaption>]] .. inline_to_html(report.chart_caption) .. [[</figcaption>
    </figure>

    <div class="scroll wide">
      <table>
        <caption>]] .. escape_html(report.work_caption) .. [[</caption>
        <thead>
          <tr><th>Project</th><th class="num">Commits</th><th class="num">Lines added</th><th class="num">Lines removed</th></tr>
        </thead>
        <tbody>
]] .. table.concat(work_rows, "\n") .. [[

        </tbody>
      </table>
    </div>

]] .. render_blocks_html(report.work_note) .. [[


    <h2 class="section">]] .. escape_html(report.projects_caption or "The projects, one at a time") .. [[</h2>

]] .. table.concat(sections, "\n\n") .. [[


]] .. ((#patterns > 0) and ('    <h2 class="section" id="patterns">Patterns across the window</h2>\n\n    <ul class="findings">\n' .. table.concat(patterns, "\n") .. "\n    </ul>") or "") .. [[

    <h2 class="section" id="open">What is open</h2>

    <div class="scroll wide">
      <table class="prose">
        <caption>Outstanding at the close of the window</caption>
        <thead>
          <tr><th style="width:22%">Project</th><th style="width:13%">State</th><th>Waiting on</th></tr>
        </thead>
        <tbody>
]] .. table.concat(open_rows, "\n") .. [[

        </tbody>
      </table>
    </div>

    <h2 class="section" id="tree">Notes on the tree</h2>

]] .. render_blocks_html(report.tree) .. [[


]] .. (report.colophon and ('    <div class="colophon">\n' .. inline_to_html(report.colophon) .. "\n    </div>") or "") .. [[
]] .. nav .. [[

  </main>
</div>
</body>
</html>
]],
  })
end
-- }}}

-- {{{ local function markdown_document(report)
-- The same report, flattened for a terminal. Kept deliberately plain: no tables
-- of contents, no anchors, nothing that only works in a browser.
local function markdown_document(report)
  local out = {}
  local function add(text) out[#out + 1] = text end

  add("# " .. report.title)
  add("*" .. report.eyebrow .. "*")
  add(report.dek)
  local figures = { "| | |", "| --- | --- |" }
  for _, item in ipairs(report.totals) do
    figures[#figures + 1] = "| " .. item.label .. " | " .. item.value .. " |"
  end
  add(table.concat(figures, "\n"))

  add("## The window")
  add(render_blocks_markdown(report.intro))

  local days = {}
  for _, day in ipairs(report.days) do
    days[#days + 1] = day.label .. ": " .. day.value
  end
  add("**Commits per day.** " .. table.concat(days, ", ") .. ".")
  add(report.chart_caption)

  local rows = { "| Project | Commits | Lines added | Lines removed |", "| --- | ---: | ---: | ---: |" }
  for _, row in ipairs(report.work) do
    rows[#rows + 1] = "| " .. row.name .. " | " .. row.commits .. " | "
      .. commas(row.added) .. " | " .. commas(row.removed) .. " |"
  end
  add(table.concat(rows, "\n"))
  add(render_blocks_markdown(report.work_note))

  add("# " .. (report.projects_caption or "The projects, one at a time"))
  for _, project in ipairs(report.projects) do
    add("## " .. project.name .. " — " .. (project.slug or (project.commits .. " commits")))
    add(project.identity)
    if project.stats then
      local stat_rows = { "| | |", "| --- | --- |" }
      for _, stat in ipairs(project.stats) do
        stat_rows[#stat_rows + 1] = "| " .. stat.key .. " | " .. stat.value
          .. (stat.note and (" " .. stat.note) or "") .. " |"
      end
      add(table.concat(stat_rows, "\n"))
    end
    add(render_blocks_markdown(project.blocks))
  end

  if report.patterns and #report.patterns > 0 then
    add("# Patterns across the window")
    local patterns = {}
    for _, item in ipairs(report.patterns) do patterns[#patterns + 1] = "- " .. item end
    add(table.concat(patterns, "\n"))
  end

  add("# What is open")
  local open_rows = { "| Project | State | Waiting on |", "| --- | --- | --- |" }
  for _, row in ipairs(report.open) do
    open_rows[#open_rows + 1] = "| " .. row.project .. " | " .. row.state .. " | " .. row.waiting .. " |"
  end
  add(table.concat(open_rows, "\n"))

  add("# Notes on the tree")
  add(render_blocks_markdown(report.tree))

  if report.colophon then
    add("---")
    add("*" .. report.colophon:gsub("%*%*", "") .. "*")
  end

  return table.concat(out, "\n\n") .. "\n"
end
-- }}}

-- {{{ local function strip_document_frame(page)
-- The same page with its outermost wrapper removed, keeping the title, the font
-- link and the stylesheet at the top.
--
-- This exists for one consumer: the hosting service that publishes a page to a
-- shareable link supplies its own document frame and rejects a file that brings
-- another. Rather than keep a second hand-edited copy of every report — which is
-- exactly the two-homes-for-one-fact problem these reports keep reporting on —
-- the frame is peeled off a generated page.
local function strip_document_frame(page)
  local body = page:gsub("^.-<head>%s*", "")
  body = body:gsub('<meta charset="utf%-8">%s*', "")
  body = body:gsub('<meta name="viewport"[^>]*>%s*', "")
  body = body:gsub("</head>%s*<body>%s*", "")
  body = body:gsub("%s*</body>%s*</html>%s*$", "\n")
  return body
end
-- }}}

-- {{{ local function figures_line(totals)
-- The masthead figures again, on one line, for a card in the contents list.
local function figures_line(totals)
  local out = {}
  for _, item in ipairs(totals) do
    out[#out + 1] = item.value .. " " .. item.label
  end
  return table.concat(out, " · ")
end
-- }}}

-- {{{ local function index_document(entries, opening)
-- The front door. Opening the reports directory in a browser has to land on
-- something that lists what is here and links to it; three loose HTML files
-- with no entry point means knowing the filenames before you can read anything.
--
-- Newest first, because the question somebody opens this with is almost always
-- "what happened lately" rather than "how did this start".
local function index_document(entries, opening)
  -- reading order, first part first: this is an essay, not a feed
  table.sort(entries, function(a, b) return (a.part or 0) < (b.part or 0) end)

  local rows = {}
  for _, entry in ipairs(entries) do
    local report = entry.report
    rows[#rows + 1] = table.concat({
      '    <li class="report">',
      string.format('      <a class="report-link" href="%s.html">', entry.stem),
      '        <span class="report-when">' .. escape_html(report.eyebrow) .. "</span>",
      "        <h2>" .. escape_html(report.title) .. "</h2>",
      "      </a>",
      '      <p class="report-dek">' .. inline_to_html(report.dek) .. "</p>",
      '      <p class="report-meta">Part ' .. entry.part .. " · "
        .. figures_line(report.totals)
        .. ' · <a href="' .. entry.stem .. '.md">plain text</a></p>',
      "    </li>",
    }, "\n")
  end

  return table.concat({
[[<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Progress Reports</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,600;12..96,700&family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&family=JetBrains+Mono:wght@400;500;700&display=swap">
]] .. STYLESHEET .. [[
<style>
/* The index reuses the report tokens and adds only what a list of reports
   needs. Nothing here restyles a report; the two pages share a palette on
   purpose so that following a link does not feel like leaving. */
.index-shell { max-width:820px; margin:0 auto; padding:0 28px 96px; }
.opening > * { max-width:68ch; }
.opening .stats, .opening .spans, .opening .scroll { max-width:none; }
.index-shell h2.section { margin-top:56px; }
.index-list { list-style:none; margin:0; padding:0; display:flex; flex-direction:column; gap:0; }
.report { padding:32px 0; border-bottom:1px solid var(--rule-soft); }
.report:last-child { border-bottom:0; }
.report-link { display:block; text-decoration:none; color:inherit; }
.report-link:hover h2 { color:var(--accent); }
.report-link:focus-visible { outline:2px solid var(--accent); outline-offset:4px; }
.report-when {
  font-family:"JetBrains Mono",ui-monospace,monospace; font-size:11px; font-weight:500;
  letter-spacing:.14em; text-transform:uppercase; color:var(--accent); display:block;
}
.report h2 {
  font-family:"Bricolage Grotesque","Helvetica Neue",Arial,sans-serif;
  font-size:clamp(28px,4vw,38px); font-weight:700; letter-spacing:-.02em;
  line-height:1.08; margin:8px 0 0; text-wrap:balance;
}
.report-dek { margin:12px 0 0; color:var(--ink-2); max-width:62ch; }
.report-meta {
  margin:12px 0 0; font-family:"JetBrains Mono",ui-monospace,monospace;
  font-size:12px; color:var(--muted); font-variant-numeric:tabular-nums;
}
.index-note {
  margin-top:56px; padding-top:20px; border-top:2px solid var(--ink);
  font-family:"JetBrains Mono",ui-monospace,monospace; font-size:12px;
  line-height:1.62; color:var(--muted);
}
.index-note b { color:var(--ink-2); font-weight:500; }
</style>
</head>
<body>
<div class="index-shell">
  <header class="masthead" style="grid-column:auto">
    <div class="eyebrow">]] .. escape_html(opening.eyebrow) .. [[</div>
    <h1>]] .. escape_html(opening.title) .. [[</h1>
    <p class="dek">]] .. inline_to_html(opening.dek) .. [[</p>
  </header>

  <div class="opening">
]] .. render_blocks_html(opening.blocks) .. [[

  </div>

  <h2 class="section">The parts</h2>

  <ul class="index-list">
]] .. table.concat(rows, "\n") .. [[

  </ul>

  <div class="colophon">
]] .. inline_to_html(opening.colophon) .. [[

  </div>
</div>
</body>
</html>
]],
  })
end
-- }}}

-- {{{ local function write_file(path, contents)
-- Refuses rather than falls back. A report that could not be written is worth
-- an error on the console; a report silently not written is worth nothing.
local function write_file(path, contents)
  local handle, err = io.open(path, "w")
  if not handle then
    error("cannot write " .. path .. ": " .. tostring(err))
  end
  handle:write(contents)
  handle:close()
  print("wrote " .. path)
end
-- }}}

-- {{{ main
local names = {}
local listing = io.popen("ls " .. REPORTS_DIR .. "/*.lua")
for line in listing:lines() do names[#names + 1] = line end
listing:close()

if #names == 0 then
  error("no report data files found in " .. REPORTS_DIR)
end

os.execute("mkdir -p " .. DIR .. "/artifact")

-- The order here is the order of importance. The standalone page and its plain
-- text twin are the deliverable: they are files on this disk, they open with no
-- server and no network, and they survive any hosting service going away. The
-- body-only copy written third exists only so a report can ALSO be published
-- somewhere with a link — it is an extra, never the thing itself.
local entries = {}

-- Load everything first, then order by part number, because a part needs to
-- know its neighbours before it can be written.
for _, path in ipairs(names) do
  local chunk = assert(loadfile(path))
  local report = chunk()
  local stem = path:match("([^/]+)%.lua$")
  if report.part then
    stem = string.format("part-%d-%s", report.part, report.slug_name or stem)
  end
  entries[#entries + 1] = { stem = stem, report = report, part = report.part or 0 }
end

table.sort(entries, function(a, b) return a.part < b.part end)

-- part 0 is the essay's opening: it becomes index.html and is not a part.
local opening = nil
if entries[1] and entries[1].part == 0 then
  opening = table.remove(entries, 1).report
end
if not opening then error("no opening found: one report must carry part = 0") end

for _, entry in ipairs(entries) do PART_FILE[entry.part] = entry.stem end

for index, entry in ipairs(entries) do
  local neighbours = nil
  if entry.report.part then
    neighbours = {
      prev = (index > 1) and entries[index - 1] or nil,
      next = (index < #entries) and entries[index + 1] or nil,
    }
    if neighbours.prev then neighbours.prev.title = neighbours.prev.report.title end
    if neighbours.next then neighbours.next.title = neighbours.next.report.title end
  end
  local page = html_document(entry.report, neighbours)
  write_file(DIR .. "/" .. entry.stem .. ".html", page)
  write_file(DIR .. "/" .. entry.stem .. ".md", markdown_document(entry.report))
  write_file(DIR .. "/artifact/" .. entry.stem .. ".html", strip_document_frame(page))
end

write_file(DIR .. "/index.html", index_document(entries, opening))

print(string.format("\n%d report%s: open %s/index.html",
  #entries, (#entries == 1) and "" or "s", DIR))
-- }}}
