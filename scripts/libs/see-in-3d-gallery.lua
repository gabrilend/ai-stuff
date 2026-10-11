-- see-in-3d-gallery.lua - Lays out see-in-3d examples as one web page: each
-- picture beside the four views of what a model read it to be.
--
-- In plain terms: an example is a folder holding a scene file, an optional
-- picture it was read from, and a note -- a title, which stage of the gallery
-- it arrived in, an optional compare group, and what the views showed. This
-- reads those notes and writes the page. It draws nothing itself: the views
-- and the picture copies are made beforehand by the see-in-3d command and
-- only named here, so the page and the pictures can be checked separately.
--
-- The page is styled as a set of drawing sheets: front, right, top and angle
-- are the views of an engineering drawing, so each example gets a sheet
-- number and a title block, and compare groups sit side by side.
--
-- Note format (note.txt), key: value lines, then a line "---", then the text
-- saying what the views showed:
--   title: The reading walk on a watch
--   picture: /absolute/path.png      (or: none -- read from an idea, not a picture)
--   stage: 1                         (1, 3, 8 or 25: the gallery size it arrived in)
--   group: Two readings of one screen   (optional; same text = side by side)

local M = {}

-- {{{ local function escape()
local escapes = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }
local function escape(text)
    return (tostring(text):gsub('[&<>"]', escapes))
end
-- }}}

-- {{{ M.read_note(path)
-- A note as { title, picture, stage, group, seen } (strings; group may be
-- ""), or an error naming the missing field. Unknown keys are refused, so a
-- misspelt key does not silently drop a field.
local known = { title = true, picture = true, stage = true, group = true }
function M.read_note(path)
    local handle = io.open(path, "r")
    if not handle then error("see-in-3d gallery: no note at " .. path, 0) end
    local note, body, in_body = { group = "" }, {}, false
    for line in handle:lines() do
        -- before the divider, each line is a field; after it, the text
        if in_body then body[#body + 1] = line
        elseif line == "---" then in_body = true
        elseif line:match("%S") then
            local key, value = line:match("^(%w+):%s*(.-)%s*$")
            if not key or not known[key] then error("see-in-3d gallery: " .. path .. ": not a note field: " .. line, 0) end
            note[key] = value
        end
    end
    handle:close()
    for _, field in ipairs({ "title", "picture", "stage" }) do
        if not note[field] then error("see-in-3d gallery: " .. path .. " needs " .. field .. ":", 0) end
    end
    note.seen = table.concat(body, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    return note
end
-- }}}

-- {{{ local STYLE
local STYLE = [[
/* layout: a stack of drawing sheets; each sheet is picture | views, title block below; compare groups pair sheets */
:root {
  --paper: #eef1ee; --sheet: #f8faf8; --ink: #1f2a2e; --pencil: #5d6b70; --rule: #c6cfcc;
  --accent: #2c5d86; --caught: #a3402d;
  --display: "Barlow Condensed", "Arial Narrow", sans-serif;
  --body: "Source Serif 4", Georgia, serif;
  --mono: "IBM Plex Mono", ui-monospace, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --paper: #13181a; --sheet: #1a2124; --ink: #dfe7e4; --pencil: #93a3a6; --rule: #2f3a3d;
  --accent: #86b3da; --caught: #e08a76; color-scheme: dark } }
:root[data-theme="dark"] {
  --paper: #13181a; --sheet: #1a2124; --ink: #dfe7e4; --pencil: #93a3a6; --rule: #2f3a3d;
  --accent: #86b3da; --caught: #e08a76; color-scheme: dark }
body { background: var(--paper); color: var(--ink); font: 17px/1.55 var(--body); margin: 0; }
.page { max-width: 1180px; margin: 0 auto; padding-inline: 16px; padding-block: 32px 64px; }
header h1 { font: 600 clamp(34px, 5vw, 52px)/1.05 var(--display); letter-spacing: 0.01em; margin: 0 0 8px; text-wrap: balance; }
header p { max-width: 65ch; margin: 0 0 8px; color: var(--pencil); }
.stages { display: flex; flex-wrap: wrap; gap: 8px; margin: 20px 0 8px; padding: 0; list-style: none;
  font: 500 14px var(--display); letter-spacing: 0.06em; text-transform: uppercase; }
.stages li { border: 1px solid var(--rule); padding: 4px 10px; color: var(--pencil); }
.stages b { color: var(--ink); font-variant-numeric: tabular-nums; }
h2 { font: 600 26px/1.2 var(--display); letter-spacing: 0.02em; margin: 48px 0 6px; text-wrap: balance; }
.lede { color: var(--pencil); max-width: 65ch; margin: 0 0 16px; font-style: italic; }
h3.compare { font: 600 20px/1.2 var(--display); letter-spacing: 0.03em; margin: 8px 0 10px; color: var(--accent); text-wrap: balance; }
.group { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 520px), 1fr)); gap: 20px; }
.sheets { display: grid; gap: 28px; }
.sheet { background: var(--sheet); border: 1px solid var(--rule); min-width: 0; }
.views { display: grid; grid-template-columns: 1fr 1fr; gap: 1px; background: var(--rule); }
.views.three { grid-template-columns: repeat(3, 1fr); }
.group .views.three { grid-template-columns: 1fr 1fr; }
.group .views.three figure:last-child { grid-column: 1 / -1; }
@media (max-width: 760px) { .views.three, .group .views.three { grid-template-columns: 1fr; } }
.views figure { margin: 0; background: var(--sheet); padding: 10px; min-width: 0; }
.views figcaption { font: 500 12px var(--display); letter-spacing: 0.1em; text-transform: uppercase; color: var(--pencil); margin-bottom: 6px; }
.views img { display: block; width: 100%; height: auto; }
.idea { aspect-ratio: 1; display: grid; place-items: center; text-align: center; color: var(--pencil);
  border: 1px dashed var(--rule); padding: 16px; font-style: italic; }
.block { display: grid; grid-template-columns: auto 1fr auto; border-top: 1px solid var(--ink); }
.block > div { padding: 8px 12px; border-right: 1px solid var(--rule); min-width: 0; }
.block > div:last-child { border-right: 0; }
.block .k { display: block; font: 500 11px var(--display); letter-spacing: 0.12em; text-transform: uppercase; color: var(--pencil); }
.block .no { font: 600 28px/1 var(--display); font-variant-numeric: tabular-nums; }
.block .title { font: 600 19px/1.25 var(--display); letter-spacing: 0.01em; }
.block .stage { font: 500 15px var(--display); font-variant-numeric: tabular-nums; white-space: nowrap; }
.seen { padding: 10px 12px 14px; border-top: 1px solid var(--rule); }
.seen p { margin: 0; max-width: 70ch; }
.seen .k { font: 500 11px var(--display); letter-spacing: 0.12em; text-transform: uppercase; color: var(--caught); display: block; margin-bottom: 2px; }
.what { font: 13px/1.45 var(--mono); color: var(--pencil); padding: 0 12px 10px; }
details { border-top: 1px solid var(--rule); padding: 8px 12px; }
summary { cursor: pointer; font: 500 13px var(--display); letter-spacing: 0.08em; text-transform: uppercase; color: var(--accent); }
summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
pre { overflow-x: auto; font: 12.5px/1.5 var(--mono); margin: 8px 0 0; color: var(--ink); }
footer { margin-top: 48px; color: var(--pencil); font-size: 14px; max-width: 65ch; }
@media (max-width: 560px) { .block { grid-template-columns: auto 1fr; } .block > div:last-child { grid-column: 1 / -1; border-top: 1px solid var(--rule); } }
]]
-- }}}

-- {{{ local function sheet_html()
-- One example as a drawing sheet: picture and views, title block, what the
-- views showed, and the scene itself folded away.
local function sheet_html(example, total)
    local note = example.note
    local parts = { '<article class="sheet" id="sheet-' .. example.number .. '"><div class="views' ..
        (example.imagined_file and ' three' or '') .. '">' }
    -- a picture is shown as read; an idea has no picture, and says so
    if example.picture_file then
        parts[#parts + 1] = '<figure><figcaption>The picture</figcaption><img src="' .. escape(example.picture_file) ..
            '" alt="' .. escape(note.title) .. ', as it was seen" loading="lazy"></figure>'
    else
        parts[#parts + 1] = '<figure><figcaption>The picture</figcaption><div class="idea">No picture: read from an idea in words.</div></figure>'
    end
    parts[#parts + 1] = '<figure><figcaption>Front · right / top · angle</figcaption><img src="' .. escape(example.sheet_file) ..
        '" alt="Four views of the scene: ' .. escape(example.what) .. '" loading="lazy"></figure>'
    -- the imagined picture, when the example has one: what an image model made
    -- of the angle view
    if example.imagined_file then
        parts[#parts + 1] = '<figure><figcaption>Imagined from the angle view</figcaption><img src="' .. escape(example.imagined_file) ..
            '" alt="The angle view imagined as a picture: ' .. escape(example.what) .. '" loading="lazy"></figure>'
    end
    parts[#parts + 1] = '</div>'
    parts[#parts + 1] = '<div class="block"><div><span class="k">Sheet</span><span class="no">' ..
        string.format("%02d", example.number) .. '</span></div><div><span class="k">Title</span><span class="title">' ..
        escape(note.title) .. '</span></div><div><span class="k">Stage</span><span class="stage">' ..
        escape(note.stage) .. '</span></div></div>'
    parts[#parts + 1] = '<p class="what">scene: ' .. escape(example.what) .. ' · ' .. example.shape_count .. ' shapes</p>'
    if note.seen ~= "" then
        parts[#parts + 1] = '<div class="seen"><span class="k">What the views showed</span><p>' .. escape(note.seen) .. '</p></div>'
    end
    parts[#parts + 1] = '<details><summary>The scene as written</summary><pre><code>' .. escape(example.scene_text) ..
        '</code></pre></details></article>'
    return table.concat(parts)
end
-- }}}

-- {{{ M.read_stages(path)
-- Optional words under each stage's heading, from a file of "N: words" lines
-- beside the examples. No file means no words; a malformed line is an error.
function M.read_stages(path)
    local ledes = {}
    local handle = io.open(path, "r")
    if not handle then return ledes end
    for line in handle:lines() do
        if line:match("%S") then
            local stage, text = line:match("^(%d+):%s*(.+)$")
            if not stage then error("see-in-3d gallery: " .. path .. ": a line must be \"N: words\": " .. line, 0) end
            ledes[stage] = text
        end
    end
    handle:close()
    return ledes
end
-- }}}

-- {{{ M.page(examples, ledes)
-- The whole page. examples: list of { number, note, picture_file (or nil),
-- sheet_file, what, shape_count, scene_text }, in sheet order; ledes: stage
-- -> words shown under that stage's heading. Examples that share a group are
-- drawn side by side under the group's name, at the place the group's first
-- member appears.
function M.page(examples, ledes)
    ledes = ledes or {}
    local total = #examples
    local counts = { ["1"] = 0, ["3"] = 0, ["8"] = 0, ["25"] = 0 }
    for _, example in ipairs(examples) do
        counts[example.note.stage] = (counts[example.note.stage] or 0) + 1
    end
    local parts = {
        '<title>Seen From Four Sides</title>',
        '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
        '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600&family=IBM+Plex+Mono&family=Source+Serif+4:opsz,wght@8..60,400;8..60,600&display=swap">',
        "<style>" .. STYLE .. "</style>",
        '<!-- Made by scripts/see-in-3d gallery, from the example folders\' notes and scenes, so the readings can be seen beside their pictures. -->',
        '<div class="page"><header><h1>Seen From Four Sides</h1>',
        "<p>Each sheet is a picture, and what a language model read it to be as an object in space, written as a few lines of shapes and drawn from the front, the right, above and an angle. Where the views disagree with the picture, the reading was wrong.</p>",
        '<ul class="stages">',
    }
    -- each stage that has sheets, with the running total it brought the gallery to
    local running = 0
    for _, stage in ipairs({ "1", "3", "8", "25" }) do
        if (counts[stage] or 0) > 0 then
            running = running + counts[stage]
            parts[#parts + 1] = "<li>Stage <b>" .. stage .. "</b> · " .. running .. (running == 1 and " sheet" or " sheets") .. "</li>"
        end
    end
    parts[#parts + 1] = "</ul></header>"

    local shown_groups = {}
    local current_stage = nil
    for _, example in ipairs(examples) do
        local stage = example.note.stage
        -- a new stage opens a section; a group is drawn whole, once
        if stage ~= current_stage then
            if current_stage then parts[#parts + 1] = "</div>" end
            current_stage = stage
            parts[#parts + 1] = "<h2>Stage " .. escape(stage) .. "</h2>"
            if ledes[stage] then parts[#parts + 1] = '<p class="lede">“' .. escape(ledes[stage]) .. '”</p>' end
            parts[#parts + 1] = '<div class="sheets">'
        end
        local group = example.note.group
        if group ~= "" then
            if not shown_groups[group] then
                shown_groups[group] = true
                parts[#parts + 1] = '<section><h3 class="compare">Compare: ' .. escape(group) .. '</h3><div class="group">'
                for _, member in ipairs(examples) do
                    if member.note.group == group then parts[#parts + 1] = sheet_html(member, total) end
                end
                parts[#parts + 1] = "</div></section>"
            end
        else
            parts[#parts + 1] = sheet_html(example, total)
        end
    end
    if current_stage then parts[#parts + 1] = "</div>" end
    parts[#parts + 1] = "<footer>Made by <code>scripts/see-in-3d gallery</code>. The views are drawn by its own software renderer; the pictures are the sources the scenes were read from, scaled down.</footer></div>"
    return table.concat(parts, "\n")
end
-- }}}

return M
