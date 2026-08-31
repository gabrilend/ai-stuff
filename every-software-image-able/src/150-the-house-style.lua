#!/usr/bin/env luajit
-- 150-the-house-style.lua
--
-- What the documentation site looks like: the page around the words, the
-- colours, and the small drawings made out of the project's own numbers.
--
-- For a general: `149` decides which pages exist and how they point at each
-- other. This decides what they look like when they arrive -- one page shape
-- used by all two hundred of them, one set of colours, and charts drawn from
-- counts rather than from anything typed in.
--
-- WHY THE APPEARANCE IS A SEPARATE FILE. The two halves fail differently. A
-- mistake in the site builder is a broken link or a missing page; a mistake here
-- is something ugly. Keeping them apart means the colours can be changed without
-- touching anything that knows what a ticket is, and it means this file can be
-- read by somebody who only wants to change how it looks.
--
-- THE CHARTS ARE DRAWN, NOT CHARTED. They are plain shapes written directly into
-- the page, with no library and nothing fetched -- the site has to work from a
-- file on a disk with nothing running and no network, the same way everything
-- else this project builds has to work with nothing underneath it.
--
-- THE NUMBERS IN THEM ARE COUNTED AT BUILD TIME. Nothing here holds a statistic.
-- A figure that was true when somebody typed it is the failure this project's
-- documentation rules exist to prevent, so every number on the front page comes
-- from counting the files during the build that drew it.
--
-- library:
--   local house = dofile(DIR .. "/src/150-the-house-style.lua")
--   local page = house.shell({ title = "...", body = "...", sidebar = "..." })

local M = {}

-- {{{ M.stylesheet()
--
-- One stylesheet for the whole site. Dark by default with a light setting kept
-- in the browser, because these are long documents and both kinds of reader
-- exist.
--
-- The look is meant to sit with the subject: a fixed-width face for anything the
-- machine would say -- headings, code, references, numbers -- and an ordinary
-- reading face for the prose, which is what most of these files are.
function M.stylesheet()
  return [[
:root {
  --bg: #0e0f12;
  --panel: #16181d;
  --panel-edge: #23262d;
  --ink: #d8d4cb;
  --ink-quiet: #8c8779;
  --ink-loud: #f2eee5;
  --amber: #e0a03c;
  --green: #86a95c;
  --red: #c4614f;
  --blue: #6f9bc4;
  --mono: ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
  --serif: Charter, Georgia, "Iowan Old Style", serif;
}
html[data-look="light"] {
  --bg: #f4f1ea;
  --panel: #ebe6dc;
  --panel-edge: #d8d2c4;
  --ink: #2b2822;
  --ink-quiet: #6b6558;
  --ink-loud: #14120e;
  --amber: #9a6410;
  --green: #4c6b28;
  --red: #9c3524;
  --blue: #2f5f8a;
}

* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--ink);
  font-family: var(--serif);
  font-size: 17px;
  line-height: 1.62;
}

/* the three columns: what there is, what you are reading, where you are in it */
.frame { display: flex; min-height: 100vh; align-items: flex-start; }

.aside {
  width: 310px;
  flex: 0 0 310px;
  position: sticky;
  top: 0;
  height: 100vh;
  overflow-y: auto;
  background: var(--panel);
  border-right: 1px solid var(--panel-edge);
  padding: 18px 14px 40px 18px;
  font-family: var(--mono);
  font-size: 13px;
}
.aside h1 {
  font-size: 14px;
  letter-spacing: 0.02em;
  margin: 0 0 2px 0;
  color: var(--ink-loud);
}
.aside .tagline { color: var(--ink-quiet); font-size: 11.5px; margin-bottom: 14px; }

.filter {
  width: 100%;
  padding: 7px 9px;
  margin-bottom: 6px;
  background: var(--bg);
  border: 1px solid var(--panel-edge);
  border-radius: 4px;
  color: var(--ink);
  font-family: var(--mono);
  font-size: 12.5px;
}
.filter:focus { outline: none; border-color: var(--amber); }
.filter-note { color: var(--ink-quiet); font-size: 11px; margin: 4px 2px 12px; }

.aside details { margin-bottom: 6px; }
.aside summary {
  cursor: pointer;
  color: var(--amber);
  font-size: 11.5px;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  padding: 5px 2px;
  list-style: none;
  user-select: none;
}
.aside summary::-webkit-details-marker { display: none; }
.aside summary::before { content: "▸ "; display: inline-block; width: 1em; }
.aside details[open] > summary::before { content: "▾ "; }
.aside summary .tally { color: var(--ink-quiet); text-transform: none; letter-spacing: 0; }

.aside a {
  display: block;
  padding: 3px 8px 3px 22px;
  color: var(--ink);
  text-decoration: none;
  border-radius: 3px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.aside a:hover { background: var(--bg); color: var(--ink-loud); }
.aside a.here { background: var(--bg); color: var(--amber); }
.aside a .num { color: var(--ink-quiet); }
.aside a.here .num { color: var(--amber); }

.main { flex: 1 1 auto; min-width: 0; padding: 34px 44px 120px; max-width: 1100px; }
.reading { max-width: 74ch; }

.crumb {
  font-family: var(--mono);
  font-size: 11.5px;
  color: var(--ink-quiet);
  letter-spacing: 0.06em;
  text-transform: uppercase;
  margin-bottom: 10px;
}
.crumb a { color: var(--ink-quiet); }

h1, h2, h3, h4, h5, h6 {
  font-family: var(--mono);
  color: var(--ink-loud);
  line-height: 1.28;
  font-weight: 600;
}
h1 { font-size: 27px; margin: 0 0 18px; letter-spacing: -0.01em; }
h2 { font-size: 20px; margin: 38px 0 12px; padding-top: 10px; border-top: 1px solid var(--panel-edge); }
h3 { font-size: 16px; margin: 26px 0 8px; }
h4 { font-size: 14px; margin: 20px 0 6px; color: var(--amber); }

.anchor {
  float: left;
  margin-left: -1.1em;
  color: var(--panel-edge);
  text-decoration: none;
  opacity: 0;
  transition: opacity 0.12s;
}
h1:hover .anchor, h2:hover .anchor, h3:hover .anchor, h4:hover .anchor { opacity: 1; }

p { margin: 0 0 15px; }
a { color: var(--blue); text-decoration-color: color-mix(in srgb, var(--blue) 40%, transparent); }
a:hover { color: var(--amber); }

code {
  font-family: var(--mono);
  font-size: 0.86em;
  background: var(--panel);
  border: 1px solid var(--panel-edge);
  border-radius: 3px;
  padding: 0.08em 0.34em;
}
a.ref { text-decoration: none; }
a.ref code {
  color: var(--amber);
  border-color: color-mix(in srgb, var(--amber) 35%, var(--panel-edge));
}
a.ref:hover code { background: color-mix(in srgb, var(--amber) 15%, var(--panel)); }

pre.code {
  background: var(--panel);
  border: 1px solid var(--panel-edge);
  border-left: 2px solid var(--amber);
  border-radius: 4px;
  padding: 13px 15px;
  overflow-x: auto;
  font-size: 12.5px;
  line-height: 1.55;
}
pre.code code { background: none; border: none; padding: 0; font-size: inherit; }
pre.code .k { color: var(--amber); }
pre.code .s { color: var(--green); }
pre.code .c { color: var(--ink-quiet); font-style: italic; }
pre.code .n { color: var(--blue); }

table { border-collapse: collapse; width: 100%; margin: 16px 0; font-size: 14.5px; }
th, td {
  border: 1px solid var(--panel-edge);
  padding: 7px 10px;
  text-align: left;
  vertical-align: top;
}
th { background: var(--panel); font-family: var(--mono); font-size: 12px;
     text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-quiet); }
tbody tr:hover { background: color-mix(in srgb, var(--panel) 55%, transparent); }

blockquote {
  margin: 16px 0;
  padding: 2px 18px;
  border-left: 2px solid var(--amber);
  color: var(--ink-quiet);
  font-style: italic;
}
blockquote p:last-child { margin-bottom: 0; }
hr { border: none; border-top: 1px solid var(--panel-edge); margin: 30px 0; }
ul, ol { padding-left: 24px; margin: 0 0 15px; }
li { margin-bottom: 5px; }
strong { color: var(--ink-loud); }

/* what points here, and where this came from */
.ledger { margin-top: 48px; border-top: 1px solid var(--panel-edge); padding-top: 18px; }
.ledger h2 { border: none; margin: 0 0 10px; padding: 0; font-size: 13px;
             text-transform: uppercase; letter-spacing: 0.08em; color: var(--ink-quiet); }
.chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 20px; }
.chip {
  font-family: var(--mono);
  font-size: 11.5px;
  padding: 3px 9px;
  border: 1px solid var(--panel-edge);
  border-radius: 12px;
  background: var(--panel);
  color: var(--ink);
  text-decoration: none;
}
.chip:hover { border-color: var(--amber); color: var(--amber); }
.chip .kind { color: var(--ink-quiet); }
.provenance { font-family: var(--mono); font-size: 11.5px; color: var(--ink-quiet); }

/* the outline that follows you down a long page */
.outline {
  width: 210px;
  flex: 0 0 210px;
  position: sticky;
  top: 0;
  max-height: 100vh;
  overflow-y: auto;
  padding: 40px 16px 40px 0;
  font-family: var(--mono);
  font-size: 11.5px;
}
.outline .label { color: var(--ink-quiet); text-transform: uppercase;
                  letter-spacing: 0.08em; margin-bottom: 8px; }
.outline a { display: block; color: var(--ink-quiet); text-decoration: none;
             padding: 2px 0 2px 8px; border-left: 1px solid var(--panel-edge); }
.outline a:hover { color: var(--amber); border-left-color: var(--amber); }
.outline a.deep { padding-left: 20px; }

/* the front page */
.tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
         gap: 12px; margin: 22px 0 34px; }
.tile { background: var(--panel); border: 1px solid var(--panel-edge);
        border-radius: 5px; padding: 14px 16px; }
.tile .figure { font-family: var(--mono); font-size: 27px; color: var(--amber); line-height: 1; }
.tile .caption { font-family: var(--mono); font-size: 11px; color: var(--ink-quiet);
                 text-transform: uppercase; letter-spacing: 0.06em; margin-top: 7px; }
.chart { background: var(--panel); border: 1px solid var(--panel-edge);
         border-radius: 5px; padding: 16px; margin: 16px 0 30px; overflow-x: auto; }
.chart .legend { font-family: var(--mono); font-size: 11.5px; color: var(--ink-quiet);
                 margin-top: 10px; display: flex; gap: 16px; flex-wrap: wrap; }
.chart .legend i { display: inline-block; width: 9px; height: 9px; margin-right: 5px; }
svg text { font-family: var(--mono); }

.controls { display: flex; gap: 14px; align-items: center; flex-wrap: wrap;
            font-family: var(--mono); font-size: 12px; color: var(--ink-quiet);
            margin: 0 0 14px; }
.controls input[type=range] { accent-color: var(--amber); width: 190px; }
button.knob {
  font-family: var(--mono); font-size: 11.5px; cursor: pointer;
  background: var(--panel); color: var(--ink); border: 1px solid var(--panel-edge);
  border-radius: 4px; padding: 5px 11px;
}
button.knob:hover { border-color: var(--amber); color: var(--amber); }
button.knob[aria-pressed="true"] { border-color: var(--amber); color: var(--amber); }

.look-toggle { position: fixed; top: 12px; right: 16px; z-index: 20; }

.miss { color: var(--red); }
.hidden { display: none !important; }

@media (max-width: 1180px) { .outline { display: none; } }
@media (max-width: 820px) {
  .frame { display: block; }
  .aside { position: static; width: auto; flex: none; height: auto; border-right: none;
           border-bottom: 1px solid var(--panel-edge); }
  .main { padding: 22px 18px 80px; }
}
]]
end
-- }}}

-- {{{ M.script()
--
-- The three things on this site that move: the filter over the list of
-- everything, the light setting, and the sliders on the coverage page.
--
-- Written out rather than fetched. There is no network here by design -- the
-- site has to open from a file on a disk -- and a documentation site that needs
-- something downloaded before it renders is a documentation site that stops
-- working the first time somebody reads it on a machine with nothing on it,
-- which is a situation this project is unusually likely to be in.
function M.script()
  return [[
(function () {
  // The light setting, kept between visits. Applied from the head before paint
  // where possible, so a reader who chose light does not get a flash of dark.
  var root = document.documentElement;
  var stored = null;
  try { stored = localStorage.getItem("look"); } catch (e) { stored = null; }
  if (stored) root.setAttribute("data-look", stored);

  var toggle = document.getElementById("look-toggle");
  if (toggle) {
    var paint = function () {
      var light = root.getAttribute("data-look") === "light";
      toggle.textContent = light ? "dark" : "light";
    };
    paint();
    toggle.addEventListener("click", function () {
      var light = root.getAttribute("data-look") === "light";
      if (light) { root.removeAttribute("data-look"); } else { root.setAttribute("data-look", "light"); }
      try { localStorage.setItem("look", light ? "dark" : "light"); } catch (e) {}
      paint();
    });
  }

  // The filter. Every entry carries what it is searchable by in an attribute,
  // so this never reads the text it is showing -- a title with markup in it
  // would otherwise be searchable by its markup.
  var box = document.getElementById("filter");
  if (box) {
    var entries = Array.prototype.slice.call(document.querySelectorAll(".aside a[data-find]"));
    var groups = Array.prototype.slice.call(document.querySelectorAll(".aside details"));
    var note = document.getElementById("filter-note");
    var run = function () {
      var want = box.value.trim().toLowerCase();
      var shown = 0;
      entries.forEach(function (entry) {
        var hit = want === "" || entry.getAttribute("data-find").indexOf(want) !== -1;
        entry.classList.toggle("hidden", !hit);
        if (hit) shown++;
      });
      groups.forEach(function (group) {
        var any = group.querySelector("a[data-find]:not(.hidden)");
        group.classList.toggle("hidden", !any);
        // Opening every group while filtering is the whole point of filtering;
        // closing them again afterwards would hide what somebody just found.
        if (want !== "" && any) group.open = true;
      });
      if (note) {
        note.textContent = want === "" ? (entries.length + " pages")
                                       : (shown + " of " + entries.length);
      }
    };
    box.addEventListener("input", run);
    box.addEventListener("keydown", function (event) {
      if (event.key === "Escape") { box.value = ""; run(); }
    });
    run();
  }

  // The coverage page's sliders and buttons. Each control names the attribute it
  // filters on, so adding another one is markup rather than code.
  var shelf = document.getElementById("shelf");
  if (shelf) {
    var rows = Array.prototype.slice.call(shelf.querySelectorAll("tbody tr"));
    var lengthSlider = document.getElementById("at-least");
    var lengthShown = document.getElementById("at-least-shown");
    var kindButtons = Array.prototype.slice.call(document.querySelectorAll("button[data-kind]"));
    var tally = document.getElementById("shelf-tally");
    var kind = "all";

    var run = function () {
      var floor = lengthSlider ? parseInt(lengthSlider.value, 10) : 0;
      var shown = 0;
      rows.forEach(function (row) {
        var lines = parseInt(row.getAttribute("data-lines"), 10);
        var rowKind = row.getAttribute("data-kind");
        var hit = lines >= floor && (kind === "all" || rowKind === kind);
        row.classList.toggle("hidden", !hit);
        if (hit) shown++;
      });
      if (lengthShown) lengthShown.textContent = floor;
      if (tally) tally.textContent = shown + " of " + rows.length + " pages";
    };

    if (lengthSlider) lengthSlider.addEventListener("input", run);
    kindButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        kind = button.getAttribute("data-kind");
        kindButtons.forEach(function (other) {
          other.setAttribute("aria-pressed", other === button ? "true" : "false");
        });
        run();
      });
    });
    run();
  }
})();
]]
end
-- }}}

-- {{{ M.shell(page)
--
-- The page around the words. Takes a table:
--
--   title     what it is called
--   crumb     the line above the title saying what kind of thing it is
--   body      the rendered document
--   sidebar   the list of everything, already rendered
--   outline   the headings of this page, already rendered, or nil
--   ledger    what points here and where it came from, or nil
--   wide      true for the front page, which is not a column of prose
function M.shell(page)
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("<!doctype html>")
  line('<html lang="en">')
  line("<head>")
  line('<meta charset="utf-8">')
  line('<meta name="viewport" content="width=device-width, initial-scale=1">')
  line("<title>" .. page.title .. " — every software image able</title>")
  line('<link rel="stylesheet" href="style.css">')
  -- Before the body, so a reader who chose the light setting never sees a dark
  -- page flash first.
  line("<script>try{var l=localStorage.getItem('look');" ..
       "if(l)document.documentElement.setAttribute('data-look',l);}catch(e){}</script>")
  line("</head>")
  line("<body>")
  line('<button class="knob look-toggle" id="look-toggle">light</button>')
  line('<div class="frame">')
  line('<nav class="aside">')
  line(page.sidebar)
  line("</nav>")
  line('<main class="main">')
  if page.crumb then line('<div class="crumb">' .. page.crumb .. "</div>") end
  line('<article class="' .. (page.wide and "wide" or "reading") .. '">')
  line(page.body)
  if page.ledger then line(page.ledger) end
  line("</article>")
  line("</main>")
  if page.outline then
    line('<aside class="outline">')
    line(page.outline)
    line("</aside>")
  end
  line("</div>")
  line('<script src="site.js"></script>')
  line("</body>")
  line("</html>")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.stacked_bars(rows, options)
--
-- One bar per row, each split into coloured parts. Rows are
-- { label = "phase 1", parts = { { value = 8, colour = "...", name = "..." } } }.
--
-- Drawn as plain shapes with the numbers written on them, because a bar you
-- cannot read the value off is a decoration. The widths are worked out here
-- rather than by the browser so that the drawing is the same everywhere.
function M.stacked_bars(rows, options)
  options = options or {}
  local width = options.width or 620
  local label_width = options.label_width or 86
  local row_height = 26
  local gap = 7
  local plot = width - label_width - 46

  local most = 1
  for _, row in ipairs(rows) do
    local total = 0
    for _, part in ipairs(row.parts) do total = total + part.value end
    if total > most then most = total end
  end

  local height = #rows * (row_height + gap)
  local out = { '<svg viewBox="0 0 ' .. width .. " " .. height ..
                '" width="100%" height="' .. height .. '" role="img">' }

  for index, row in ipairs(rows) do
    local y = (index - 1) * (row_height + gap)
    out[#out + 1] = '<text x="0" y="' .. (y + 17) ..
                    '" font-size="12" fill="var(--ink-quiet)">' .. row.label .. "</text>"
    local x = label_width
    local total = 0
    for _, part in ipairs(row.parts) do
      local w = (part.value / most) * plot
      if part.value > 0 then
        out[#out + 1] = '<rect x="' .. string.format("%.1f", x) .. '" y="' .. y ..
                        '" width="' .. string.format("%.1f", w) .. '" height="' .. row_height ..
                        '" fill="' .. part.colour .. '" rx="2">' ..
                        "<title>" .. part.name .. ": " .. part.value .. "</title></rect>"
        if w > 22 then
          out[#out + 1] = '<text x="' .. string.format("%.1f", x + 7) .. '" y="' .. (y + 17) ..
                          '" font-size="11.5" fill="var(--bg)" font-weight="600">' ..
                          part.value .. "</text>"
        end
      end
      x = x + w
      total = total + part.value
    end
    out[#out + 1] = '<text x="' .. string.format("%.1f", x + 8) .. '" y="' .. (y + 17) ..
                    '" font-size="11.5" fill="var(--ink-quiet)">' .. total .. "</text>"
  end

  out[#out + 1] = "</svg>"
  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.ranked_bars(rows, options)
--
-- One bar per row against a single scale, for comparing sizes -- how long each
-- document is, how much each holds. Rows are { label, value, colour, href }.
function M.ranked_bars(rows, options)
  options = options or {}
  local width = options.width or 620
  local label_width = options.label_width or 210
  local row_height = 17
  local gap = 4
  local plot = width - label_width - 52

  local most = 1
  for _, row in ipairs(rows) do if row.value > most then most = row.value end end

  local height = #rows * (row_height + gap)
  local out = { '<svg viewBox="0 0 ' .. width .. " " .. height ..
                '" width="100%" height="' .. height .. '" role="img">' }

  for index, row in ipairs(rows) do
    local y = (index - 1) * (row_height + gap)
    local w = (row.value / most) * plot
    local label = row.label
    if #label > 30 then label = label:sub(1, 29) .. "…" end
    if row.href then out[#out + 1] = '<a href="' .. row.href .. '">' end
    out[#out + 1] = '<text x="0" y="' .. (y + 12) ..
                    '" font-size="11" fill="var(--ink-quiet)">' .. label .. "</text>"
    out[#out + 1] = '<rect x="' .. label_width .. '" y="' .. y ..
                    '" width="' .. string.format("%.1f", w) .. '" height="' .. row_height ..
                    '" fill="' .. (row.colour or "var(--amber)") .. '" rx="2" opacity="0.85">' ..
                    "<title>" .. row.label .. ": " .. row.value .. "</title></rect>"
    out[#out + 1] = '<text x="' .. string.format("%.1f", label_width + w + 7) ..
                    '" y="' .. (y + 12) .. '" font-size="10.5" fill="var(--ink-quiet)">' ..
                    row.value .. "</text>"
    if row.href then out[#out + 1] = "</a>" end
  end

  out[#out + 1] = "</svg>"
  return table.concat(out, "\n")
end
-- }}}

return M
