-- 032-a-gallery-you-can-page.lua
--
-- Builds a page you can look at a whole set through.
--
-- For a general: a run leaves thousands of folders of pictures and
-- descriptions, and nobody is going to open thousands of folders. This turns
-- one into a page.
--
-- It is an instrument, not a convenience. The specification of this entire
-- project is that a person squints at a thumbnail and sees the character
-- (`docs/003`), and nothing in this repository can assert that. So the design
-- follows from the test rather than from taste: the field is shown small,
-- because small is where it has to work; large is one click away, because large
-- is where it has to *fail*; and the reasoning behind every picture is on the
-- page, because when an image is wrong the wrongness is visible in the
-- reasoning before anybody generates anything.
--
-- NOTHING IS RECOMPUTED HERE. Everything on the page was read out of what the
-- run wrote down. A gallery that worked things out for itself would be a second
-- implementation of the scene grammar, and the day the two disagreed, the
-- gallery would be lying about the pictures.
--
--   luajit src/032-a-gallery-you-can-page.lua --set DIR [--per-page 150]
--   luajit src/032-a-gallery-you-can-page.lua --pool

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ M.stylesheet()
-- The look, shared with the documentation site in `033`.
--
-- Paper and ink, a great deal of space, one accent -- which is the yellow the
-- stroke-order arrows are drawn in, so the page and the pictures agree.
-- Written once and used by both, because two stylesheets diverge.
function M.stylesheet()
  return [[
:root {
  --paper: #f4f1ea; --ink: #23201b; --faint: #8a8377;
  --rule: #d9d4c8; --accent: #b8860b; --card: #fbf9f4;
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--paper); color: var(--ink);
  font: 16px/1.65 Georgia, "Times New Roman", serif;
}
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
header {
  padding: 2.5rem 2rem 1.5rem; border-bottom: 1px solid var(--rule);
}
header h1 { margin: 0 0 .3rem; font-size: 1.7rem; font-weight: normal; }
header p { margin: 0; color: var(--faint); }
main { padding: 1.5rem 2rem 5rem; max-width: 1400px; margin: 0 auto; }
.controls {
  display: flex; flex-wrap: wrap; gap: .6rem; align-items: center;
  padding: 1rem 0 1.5rem; border-bottom: 1px solid var(--rule);
  margin-bottom: 1.5rem; position: sticky; top: 0; background: var(--paper);
  z-index: 5;
}
.controls label { color: var(--faint); font-size: .85rem; }
.controls select, .controls input, .controls button {
  font: inherit; font-size: .9rem; padding: .3rem .5rem;
  border: 1px solid var(--rule); background: var(--card); color: var(--ink);
  border-radius: 2px;
}
.controls button { cursor: pointer; }
.controls button.on { background: var(--accent); color: var(--paper); border-color: var(--accent); }
.count { margin-left: auto; color: var(--faint); font-size: .85rem; }
.grid {
  display: grid; gap: 1.2rem;
  grid-template-columns: repeat(auto-fill, minmax(148px, 1fr));
}
.tile {
  background: var(--card); border: 1px solid var(--rule); border-radius: 3px;
  padding: .6rem; text-align: center;
}
.tile .glyph {
  font-size: 2.1rem; line-height: 1.1;
  font-family: "Noto Serif CJK JP", "Hiragino Mincho ProN", serif;
}
.tile .shots { position: relative; margin: .35rem 0; }
.tile img { width: 100%; display: block; border-radius: 2px; image-rendering: auto; }
.tile img.over { position: absolute; inset: 0; }
.tile .world { color: var(--faint); font-size: .72rem; letter-spacing: .04em; }
.tile .gloss { font-size: .78rem; color: var(--ink); min-height: 2.2em; }
.card {
  background: var(--card); border: 1px solid var(--rule); border-radius: 3px;
  padding: 1.4rem; margin-bottom: 1.6rem;
  display: grid; grid-template-columns: 300px 1fr; gap: 1.6rem;
}
.card .shots { position: relative; }
.card .shots img { width: 100%; display: block; border-radius: 2px; }
.card .shots img.over { position: absolute; inset: 0; }
.card .sizes { display: flex; gap: .8rem; align-items: flex-start; }
.card .small { width: 96px; flex: none; }
.card h2 {
  margin: 0 0 .2rem; font-weight: normal; font-size: 1.15rem;
}
.card h2 .glyph {
  font-size: 2.6rem; vertical-align: -.35em; margin-right: .5rem;
  font-family: "Noto Serif CJK JP", "Hiragino Mincho ProN", serif;
}
.card .facts { color: var(--faint); font-size: .85rem; margin: 0 0 1rem; }
.card dl { display: grid; grid-template-columns: 8.5rem 1fr; gap: .3rem 1rem;
  margin: 0 0 1rem; font-size: .9rem; }
.card dt { color: var(--faint); }
.card dd { margin: 0; }
.prompt {
  font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: .8rem;
  background: var(--paper); border: 1px solid var(--rule); border-radius: 2px;
  padding: .7rem .8rem; white-space: pre-wrap; line-height: 1.5;
}
.prompt.refused { color: var(--faint); }
table.strokes { border-collapse: collapse; font-size: .82rem; width: 100%; }
table.strokes th { text-align: left; color: var(--faint); font-weight: normal;
  border-bottom: 1px solid var(--rule); padding: .25rem .5rem .25rem 0; }
table.strokes td { padding: .18rem .5rem .18rem 0; border-bottom: 1px solid var(--rule); }
table.strokes tr.named td { color: var(--ink); }
table.strokes tr:not(.named) td { color: var(--faint); }
.pager { display: flex; gap: .5rem; flex-wrap: wrap; padding: 1.5rem 0; }
.pager a, .pager span {
  padding: .25rem .6rem; border: 1px solid var(--rule); border-radius: 2px;
  font-size: .85rem; background: var(--card);
}
.pager span.here { background: var(--accent); color: var(--paper); border-color: var(--accent); }
.missing { color: #a33; font-size: .8rem; }
.tiers { display: flex; gap: .2rem; justify-content: center; margin-top: .4rem; }
.tiers .tier {
  flex: 1; font: inherit; font-size: .8rem; padding: .15rem 0; cursor: pointer;
  border: 1px solid var(--rule); background: var(--paper); color: var(--faint);
  border-radius: 2px;
}
.tiers .tier:hover { border-color: var(--accent); color: var(--ink); }
.tiers .tier.on { background: var(--accent); color: var(--paper); border-color: var(--accent); }
.basket { }
.basket.on {
  background: var(--card); border: 1px solid var(--accent); border-radius: 3px;
  padding: .9rem 1rem; margin-bottom: 1.2rem;
}
.basket pre {
  white-space: pre-wrap; word-break: break-all; font-size: .78rem;
  background: var(--paper); border: 1px solid var(--rule); padding: .5rem;
  border-radius: 2px; margin: .5rem 0;
}
.basket button {
  font: inherit; font-size: .85rem; padding: .25rem .7rem; cursor: pointer;
  border: 1px solid var(--rule); background: var(--paper); border-radius: 2px;
}
@media (max-width: 800px) { .card { grid-template-columns: 1fr; } }
]]
end
-- }}}

-- {{{ escape(text)
-- Text that will not be read as markup.
local function escape(text)
  return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
-- }}}

-- {{{ M.read_set(set_dir)
-- Every character a run left behind, as the raw text of its card.
--
-- The card is not parsed here. It is spliced into the page and the browser
-- parses it -- which is why there is no reader for this format anywhere in this
-- project. The one thing that needs to understand a card is a web page, and a
-- web page already understands it.
--
-- A folder missing its card is recorded rather than skipped. A gallery that is
-- quietly short of the set it claims to show is worse than one with a gap in
-- it, because the gap is at least visible.
function M.read_set(set_dir)
  local cards, broken = {}, {}
  local listing = io.popen('ls -1 "' .. set_dir .. '" 2>/dev/null')
  if not listing then return cards, broken end
  local folders = {}
  for name in listing:lines() do
    if name:match("^%x+%-") then folders[#folders + 1] = name end
  end
  listing:close()
  table.sort(folders)

  for _, folder in ipairs(folders) do
    local text = project.read_file(set_dir .. "/" .. folder .. "/card.json")
    if not text then
      broken[#broken + 1] = folder
    else
      cards[#cards + 1] = { folder = folder, text = text }
    end
  end
  return cards, broken
end
-- }}}

-- {{{ M.summarise(card_text, folder)
-- The handful of fields the index needs, pulled straight out of the text.
--
-- By pattern rather than by parsing, because these are five known fields at the
-- top of a file this project wrote itself, and the alternative is a parser for
-- a format nothing else here reads.
local function summarise(text, folder)
  return {
    folder = folder,
    character = text:match('"character":%s*"(.-)"') or "?",
    world = text:match('"name":%s*"(.-)"') or "?",
    grade = tonumber(text:match('"grade":%s*(%-?%d+)')) or 0,
    jlpt = tonumber(text:match('"jlpt":%s*(%-?%d+)')) or 0,
    strokes = tonumber(text:match('"strokes":%s*(%d+)')) or 0,
    gloss = (text:match('"meanings":%s*%[%s*"(.-)"') or ""),
  }
end
M.summarise = summarise
-- }}}

-- {{{ page_shell(title, subtitle, body)
function page_shell(title, subtitle, body)
  return table.concat({
    "<!doctype html>",
    '<html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    "<title>" .. escape(title) .. "</title>",
    "<style>" .. M.stylesheet() .. "</style>",
    "</head><body>",
    "<header><h1>" .. escape(title) .. "</h1><p>" .. subtitle .. "</p></header>",
    "<main>", body, "</main>",
    "</body></html>",
  }, "\n")
end
-- }}}

-- {{{ M.build(set_dir, options)
-- The whole gallery for one set.
function M.build(set_dir, options)
  options = options or {}
  local per_page = tonumber(options.per_page) or 150
  local cards, broken = M.read_set(set_dir)
  if #cards == 0 then
    error("there are no characters in " .. set_dir ..
          "\n  make some with:  luajit src/031-make-them-all.lua --grade 1")
  end

  local summaries = {}
  for index, card in ipairs(cards) do
    summaries[index] = summarise(card.text, card.folder)
  end

  local pages = math.ceil(#cards / per_page)
  for index, summary in ipairs(summaries) do
    summary.page = math.ceil(index / per_page)
  end

  -- {{{ the index: every character at the size the illusion works at
  local rows = {}
  for _, summary in ipairs(summaries) do
    rows[#rows + 1] = string.format(
      '{"f":"%s","c":"%s","w":"%s","g":%d,"j":%d,"s":%d,"m":"%s","p":%d}',
      summary.folder, summary.character, summary.world, summary.grade,
      summary.jlpt, summary.strokes, escape(summary.gloss):gsub('"', "&quot;"),
      summary.page)
  end

  local worlds = {}
  for _, summary in ipairs(summaries) do worlds[summary.world] = true end
  local world_names = {}
  for name in pairs(worlds) do world_names[#world_names + 1] = name end
  table.sort(world_names)
  local world_options = { '<option value="">every world</option>' }
  for _, name in ipairs(world_names) do
    world_options[#world_options + 1] =
      '<option value="' .. name .. '">' .. name .. "</option>"
  end

  local index_body = table.concat({
    '<div class="controls">',
    '<label>world</label><select id="world">',
    table.concat(world_options), "</select>",
    '<label>grade</label><select id="grade">',
    '<option value="">any</option><option value="1">1</option>',
    '<option value="2">2</option><option value="3">3</option>',
    '<option value="4">4</option><option value="5">5</option>',
    '<option value="6">6</option><option value="8">beyond school</option>',
    "</select>",
    '<label>JLPT</label><select id="jlpt">',
    '<option value="">any</option><option value="5">N5</option>',
    '<option value="4">N4</option><option value="3">N3</option>',
    '<option value="2">N2</option><option value="1">N1</option></select>',
    '<label>strokes up to</label><input id="strokes" type="number" min="1" max="34" style="width:4.5rem">',
    '<label>find</label><input id="find" type="search" placeholder="a meaning" style="width:9rem">',
    '<button id="arrows" title="show the stroke-order layer over every thumbnail">arrows</button>',
    '<span class="count" id="count"></span>',
    "</div>",
    (#broken > 0 and ('<p class="missing">' .. #broken ..
      " folders in this set have no card and are not shown: " ..
      escape(table.concat(broken, " ", 1, math.min(8, #broken))) .. "</p>") or ""),
    '<div class="grid" id="grid"></div>',
    "<script>",
    "const CARDS = [", table.concat(rows, ","), "];",
    [[
const grid = document.getElementById('grid');
const count = document.getElementById('count');
const arrowsButton = document.getElementById('arrows');
let showArrows = false;

function draw() {
  const world = document.getElementById('world').value;
  const grade = document.getElementById('grade').value;
  const jlpt = document.getElementById('jlpt').value;
  const strokes = parseInt(document.getElementById('strokes').value, 10);
  const find = document.getElementById('find').value.toLowerCase();
  const shown = CARDS.filter(c =>
    (!world || c.w === world) &&
    (!grade || c.g === parseInt(grade, 10)) &&
    (!jlpt || c.j === parseInt(jlpt, 10)) &&
    (!strokes || c.s <= strokes) &&
    (!find || c.m.toLowerCase().includes(find) || c.c === find));
  count.textContent = shown.length + ' of ' + CARDS.length;
  grid.innerHTML = shown.map(c =>
    '<div class="tile">' +
      '<a href="page-' + String(c.p).padStart(3,'0') + '.html#' + c.f + '">' +
      '<div class="shots">' +
        '<img loading="lazy" src="' + c.f + '/field-thumb.png" alt="">' +
        (showArrows ? '<img loading="lazy" class="over" src="' + c.f + '/arrows.png" alt="">' : '') +
      '</div></a>' +
      '<div class="glyph">' + c.c + '</div>' +
      '<div class="world">' + c.w + '</div>' +
      '<div class="gloss">' + c.m + '</div>' +
    '</div>').join('');
}
for (const id of ['world','grade','jlpt','strokes','find']) {
  document.getElementById(id).addEventListener('input', draw);
}
arrowsButton.addEventListener('click', () => {
  showArrows = !showArrows;
  arrowsButton.classList.toggle('on', showArrows);
  draw();
});
draw();
]],
    "</script>",
  }, "\n")

  project.write_file(set_dir .. "/index.html", page_shell(
    "A set of kanji, as pictures that are the kanji",
    "Every field is shown at the size the illusion is meant to work at. " ..
    "Click one to see it large, which is the size it is meant to fail at. " ..
    "The reasoning behind each picture is on its page.",
    index_body))
  -- }}}

  -- {{{ the pages: everything a run decided, per character
  for page = 1, pages do
    local first = (page - 1) * per_page + 1
    local last = math.min(page * per_page, #cards)

    local pager = {}
    for other = 1, pages do
      if other == page then
        pager[#pager + 1] = '<span class="here">' .. other .. "</span>"
      else
        pager[#pager + 1] = string.format('<a href="page-%03d.html">%d</a>',
                                          other, other)
      end
    end

    local embedded = {}
    for index = first, last do
      embedded[#embedded + 1] = string.format('{"folder":"%s","card":%s}',
                                              cards[index].folder,
                                              cards[index].text)
    end

    local body = table.concat({
      '<p><a href="index.html">&larr; back to the whole set</a></p>',
      '<div class="pager">', table.concat(pager), "</div>",
      '<div id="cards"></div>',
      '<div class="pager">', table.concat(pager), "</div>",
      "<script>",
      "const ENTRIES = [", table.concat(embedded, ","), "];",
      [[
function row(label, value) {
  return value === undefined || value === null || value === ''
    ? '' : '<dt>' + label + '</dt><dd>' + value + '</dd>';
}
document.getElementById('cards').innerHTML = ENTRIES.map(e => {
  const c = e.card, f = e.folder;
  const subjects = (c.subjects || []).map(s =>
    s.element + ' &mdash; ' + s.depicts + ', ' + s.where).join('<br>');
  const ground = (c.sound_half || []).map(s =>
    s.element + ' &mdash; ' + s.becomes + ', ' + s.where +
    (s.marked_in_the_archive ? '' : ' <em>(inside the sound half)</em>')).join('<br>');
  const strokes = (c.strokes_and_what_they_carry || []).map(s =>
    '<tr class="' + (s.named_in_the_prompt ? 'named' : '') + '">' +
    '<td>' + s.order + '</td><td>' + s.shape + '</td><td>' + s.where +
    '</td><td>' + s.carries + '</td>' +
    '<td>' + (s.named_in_the_prompt ? 'named' : '') + '</td></tr>').join('');
  return '<div class="card" id="' + f + '">' +
    '<div>' +
      '<div class="sizes">' +
        '<div class="shots" style="flex:1">' +
          '<img src="' + f + '/field.png" alt="">' +
          '<img class="over" src="' + f + '/arrows.png" alt="">' +
        '</div>' +
        '<div class="small"><img src="' + f + '/field-thumb.png" alt="">' +
        '<div class="world" style="text-align:center">thumbnail</div></div>' +
      '</div>' +
    '</div>' +
    '<div>' +
      '<h2><span class="glyph">' + c.character + '</span>' +
        (c.meanings || []).join(', ') + '</h2>' +
      '<p class="facts">' +
        (c.strokes || '?') + ' strokes' +
        (c.grade ? ' &middot; taught in year ' + c.grade : '') +
        (c.jlpt ? ' &middot; JLPT N' + c.jlpt : '') +
        (c.frequency ? ' &middot; ' + c.frequency + 'th commonest' : '') +
        ' &middot; ' + (c.readings_on || []).join(' ') + ' ' +
        (c.readings_kun || []).join(' ') +
      '</p>' +
      '<dl>' +
        row('world', c.world.name + ' <span style="color:var(--faint)">(' +
            c.world.score + ', next was ' + c.world.runner_up + ' at ' +
            c.world.runner_up_score + ')</span>') +
        row('register', c.world.register) +
        row('light', c.world.light) +
        row('ink', c.world.polarity === 'dark_ink' ? 'dark on light' : 'light on dark') +
        row('subjects', subjects) +
        row('sound half', ground) +
        row('no picture for', (c.no_picture_for || []).join(' ')) +
        row('seed', c.seed) +
        row('softened by', c.field.blur_radius.toFixed(1)) +
        row('arrows', c.arrows.count +
            (c.arrows.shortened_for_room ? ', ' + c.arrows.shortened_for_room +
             ' shortened for room' : '')) +
      '</dl>' +
      '<div class="prompt">' + c.prompt.positive + '</div>' +
      '<div class="prompt refused" style="margin-top:.5rem">refused: ' +
        c.prompt.negative + '</div>' +
      '<p class="facts" style="margin-top:.6rem">' +
        c.prompt.words + ' words, about ' + c.prompt.about_tokens +
        ' tokens, ' + c.prompt.clauses_dropped + ' clauses dropped &middot; ' +
        '<a href="' + f + '/workflow.ui.json">workflow for the editor</a> &middot; ' +
        '<a href="' + f + '/workflow.api.json">workflow to post</a></p>' +
      '<table class="strokes"><tr><th></th><th>shape</th><th>where</th>' +
        '<th>carries</th><th></th></tr>' + strokes + '</table>' +
    '</div>' +
  '</div>';
}).join('');
]],
      "</script>",
    }, "\n")

    project.write_file(string.format("%s/page-%03d.html", set_dir, page),
      page_shell(string.format("Characters %d to %d", first, last),
                 "Each field is shown large, with its arrows over it, and the " ..
                 "thumbnail beside it. Everything below a picture is what was " ..
                 "decided before it was made.", body))
  end
  -- }}}

  return { characters = #cards, pages = pages, broken = broken }
end
-- }}}

-- {{{ M.build_pool(settings)
-- The other gallery: everything ever made, with five buttons under each one.
--
-- This is the person's grader. It shows finished pictures and collects tiers,
-- and it never reaches back into the machinery that made them -- a grader with
-- access to the generator's internals is grading the intent rather than the
-- result, and the result is the only thing anybody else will ever see.
--
-- IT CANNOT WRITE TO THE POOL, AND THAT IS THE POINT. A page on a filesystem
-- has no way to change a file, and giving it one would mean the viewer and the
-- store share a door. So it collects clicks and hands back a single line to
-- run. The wall between making and looking stays a wall.
function M.build_pool(settings)
  local pool = project.load("045-the-pool-that-remembers")
  local entries = pool.walk(settings, {})
  local root = pool.root(settings)
  if #entries == 0 then
    error("nothing has been made yet, so there is nothing to look at.\n" ..
          "  the pool is " .. root)
  end

  local rows = {}
  local worlds = {}
  for _, entry in ipairs(entries) do
    local tier, who = pool.tier_of(entry)
    local by_person = pool.tier_by_a_person(entry)
    worlds[entry.category or "?"] = true
    rows[#rows + 1] = string.format(
      '{"s":"%s","p":"%s","c":"%s","w":"%s","k":"%s","t":%s,"h":%s,"y":"%s",' ..
      '"m":"%s","e":%d}',
      (entry.path:gsub(".*/", ""):gsub("%.info%.md$", "")),
      entry.picture:gsub("^" .. root .. "/", ""),
      entry.character or "?", entry.category or "?", entry.kind or "?",
      tier and tostring(tier) or "null",
      by_person and tostring(by_person) or "null",
      (who or ""):gsub('"', ""),
      (entry.means or ""):gsub('"', "&quot;"),
      #entry.elaborations)
  end

  local world_options = { '<option value="">every world</option>' }
  local names = {}
  for name in pairs(worlds) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    world_options[#world_options + 1] =
      '<option value="' .. name .. '">' .. name .. "</option>"
  end

  local body = table.concat({
    '<div class="controls">',
    '<label>world</label><select id="world">',
    table.concat(world_options), "</select>",
    '<label>at least</label><select id="floor">',
    '<option value="">any tier</option><option value="5">5</option>',
    '<option value="4">4</option><option value="3">3</option>',
    '<option value="2">2</option><option value="1">1</option></select>',
    '<label><input type="checkbox" id="byperson"> only what a person rated</label>',
    '<span class="count" id="count"></span>',
    "</div>",
    '<div id="basket" class="basket"></div>',
    '<div class="grid" id="grid"></div>',
    "<script>",
    "const POOL = [", table.concat(rows, ","), "];",
    "const RATER = " .. string.format("%q",
      "luajit " .. project.path("src", "046-two-ways-of-saying-it-is-good.lua") ..
      " --rate") .. ";",
    [[
const grid = document.getElementById('grid');
const count = document.getElementById('count');
const basket = document.getElementById('basket');
const mine = {};

function shown() {
  const world = document.getElementById('world').value;
  const floor = parseInt(document.getElementById('floor').value, 10);
  const byperson = document.getElementById('byperson').checked;
  return POOL.filter(e =>
    (!world || e.w === world) &&
    (!floor || ((byperson ? e.h : e.t) || 0) >= floor) &&
    (!byperson || e.h !== null));
}

function showBasket() {
  const keys = Object.keys(mine);
  if (!keys.length) { basket.innerHTML = ''; basket.className = 'basket'; return; }
  const line = RATER + ' ' + keys.map(k => k + '=' + mine[k]).join(' ');
  basket.className = 'basket on';
  basket.textContent = '';
  const said = document.createElement('div');
  said.innerHTML = '<strong>' + keys.length + ' rated.</strong> This page cannot ' +
    'write to the pool &mdash; it is a viewer. Run this to apply them:';
  const box = document.createElement('pre');
  box.textContent = line;
  const copy = document.createElement('button');
  copy.textContent = 'copy';
  copy.addEventListener('click', () => navigator.clipboard.writeText(line));
  const forget = document.createElement('button');
  forget.textContent = 'forget them';
  forget.addEventListener('click', () => {
    for (const key of Object.keys(mine)) delete mine[key];
    showBasket(); draw();
  });
  basket.append(said, box, copy, document.createTextNode(' '), forget);
}

// One listener on the grid rather than an attribute on every button. An inline
// handler runs in the global scope, where nothing declared in this script is
// visible -- so it would have been unable to see the ratings it was adding to.
grid.addEventListener('click', event => {
  const button = event.target.closest('button.tier');
  if (!button) return;
  mine[button.dataset.stem] = Number(button.dataset.tier);
  showBasket();
  draw();
});

function draw() {
  const list = shown();
  count.textContent = list.length + ' of ' + POOL.length;
  grid.textContent = '';
  for (const entry of list) {
    const tile = document.createElement('div');
    tile.className = 'tile';

    const shots = document.createElement('div');
    shots.className = 'shots';
    const picture = document.createElement('img');
    picture.loading = 'lazy';
    picture.src = entry.p;
    picture.alt = '';
    shots.append(picture);

    const glyph = document.createElement('div');
    glyph.className = 'glyph';
    glyph.textContent = entry.c;

    const world = document.createElement('div');
    world.className = 'world';
    world.textContent = entry.w +
      (entry.t !== null ? ' \u00b7 tier ' + entry.t : ' \u00b7 unrated') +
      (entry.h !== null ? ' \u00b7 you said ' + entry.h : '') +
      (entry.e ? ' \u00b7 ' + entry.e + ' extra' : '');

    const gloss = document.createElement('div');
    gloss.className = 'gloss';
    gloss.textContent = entry.m;

    const tiers = document.createElement('div');
    tiers.className = 'tiers';
    for (const tier of [1, 2, 3, 4, 5]) {
      const button = document.createElement('button');
      button.className = 'tier' + (mine[entry.s] === tier ? ' on' : '');
      button.textContent = tier;
      button.dataset.stem = entry.s;
      button.dataset.tier = tier;
      tiers.append(button);
    }

    tile.append(shots, glyph, world, gloss, tiers);
    grid.append(tile);
  }
}

draw();
draw();
]],
    "</script>",
  }, "\n")

  project.write_file(root .. "/index.html", page_shell(
    "Everything this has ever made",
    "Every picture kept, good and bad. Click a number under one to say what " ..
    "you think of it &mdash; 5 is <em>reach for this first</em> and 1 is " ..
    "<em>no</em>. Nothing is ever deleted; a low tier is the record of what " ..
    "missed.",
    body))

  return { renderings = #entries, where = root .. "/index.html" }
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("032-a-gallery-you-can-page")
  if options.pool then
    local made = M.build_pool(settings)
    io.write(string.format("%d renderings\n", made.renderings))
    io.write("open " .. made.where .. "\n")
    project.goodbye("032-a-gallery-you-can-page",
                    { made.renderings .. " renderings" })
    return
  end

  local set_dir = options.set or project.path(settings.batch.out_dir)
  local made = M.build(set_dir, options)
  io.write(string.format("%d characters over %d pages\n", made.characters, made.pages))
  if #made.broken > 0 then
    io.write(string.format("%d folders had no card and are shown as gaps\n",
             #made.broken))
  end
  io.write("open " .. set_dir .. "/index.html\n")
  project.goodbye("032-a-gallery-you-can-page",
                  { made.characters .. " characters, " .. made.pages .. " pages" })
end
-- }}}

if arg and arg[0] and arg[0]:find("032%-a%-gallery%-you%-can%-page") then
  main(arg)
end

return M
