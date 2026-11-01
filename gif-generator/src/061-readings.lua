-- 061-readings.lua — three readings of one sentence, side by side, and
-- the person picks (issue 602).
--
-- What this is, generally: one guess, however well constrained, carries
-- one understanding. So the same sentence goes to the porch three times
-- (to three doors, or to one door with three seeds), each reading faces
-- the wall on its own, and each that passes is filmed small. A page
-- shows the sentence above the three: the film looping, what the porch
-- heard in plain lines, and the score a click away. A reading the wall
-- refused is shown too, dimmed, with the wall's words, because a failed
-- understanding is information. Picking one moves its score into
-- input/, beside every other score, and the history remembers which
-- door heard best.
--
-- The readings land in output/readings/SLUG/, which is runtime, like
-- every film: reading-K.lua and reading-K.gif for a reading that
-- passed, reading-K.draft.lua for one that didn't, and reading-K.said
-- (the door, the seed, the heard lines or the wall's words) for each.

local porch = require("032-porch")
local gif = require("004-gif")
local ffi = require("ffi")

local readings = {}

-- The thumbnail profile: a film wider than this is shown at a whole
-- fraction of its size, every Nth pixel, so three fit side by side and
-- nothing bespoke is drawn. The score itself is never changed.
readings.THUMB_MOST = 128

-- {{{ function readings.plan()
-- Who reads, with which seed: one reading per door while doors last,
-- then round again with the next seed. One door answers `count` times
-- with seeds 1, 2, 3; three doors answer once each with seed 1. Pure.
function readings.plan(doors, count)
    count = count or 3
    local plan = {}
    for k = 1, count do
        local door = doors[(k - 1) % #doors + 1]
        plan[k] = { door = door, seed = math.floor((k - 1) / #doors) + 1 }
    end
    return plan
end
-- }}}

-- {{{ function readings.slug()
-- A sentence as a folder name: its words, lower case, joined by dashes,
-- at most 48 characters, never empty.
function readings.slug(prose)
    local words = {}
    for w in prose:lower():gmatch("[%w]+") do words[#words + 1] = w end
    local s = table.concat(words, "-"):sub(1, 48):gsub("%-$", "")
    return s ~= "" and s or "reading"
end
-- }}}

-- {{{ function readings.one()
-- One reading through one transport, never an error: a door that
-- doesn't answer is a reading that failed, saying so.
function readings.one(dir, prose, transport)
    local ok, text, second, third = pcall(porch.translate, dir, prose, transport)
    if not ok then
        return { ok = false, errors = tostring(text) }
    end
    if text then
        return { ok = true, text = text, compiled = second, heard = third }
    end
    return { ok = false, errors = second, draft = third }
end
-- }}}

-- {{{ local function write()
-- A file arrives whole, by rename from a dot-partial beside it.
local function write(path, text)
    local partial = path:gsub("([^/]+)$", ".%1.partial")
    local f = assert(io.open(partial, "wb"))
    f:write(text)
    f:close()
    assert(os.rename(partial, path))
end
-- }}}

-- {{{ function readings.thumbnail()
-- A passed reading filmed small: its frames, every Nth pixel when it is
-- wider than THUMB_MOST, encoded with its own palette and timing.
function readings.thumbnail(compiled)
    local main = require("026-render-main")
    local frames = main.render(compiled)
    local size = compiled.canvas.size
    local step = math.ceil(size / readings.THUMB_MOST)
    local small = math.floor(size / step)
    if step > 1 then
        for i, frame in ipairs(frames) do
            local out = ffi.new("uint8_t[?]", small * small)
            for y = 0, small - 1 do
                for x = 0, small - 1 do
                    out[y * small + x] = frame[(y * step) * size + x * step]
                end
            end
            frames[i] = out
        end
    end
    return gif.encode{
        width = small, height = small, palette_bytes = compiled.pal.bytes,
        frames = frames, delay_cs = math.floor(100 / compiled.canvas.fps),
    }, small
end
-- }}}

-- {{{ function readings.land()
-- One reading into its folder as reading-K.*, and its film when it
-- passed. Returns what was written.
function readings.land(folder, k, result, door_name, seed)
    local base = folder .. "/reading-" .. k
    local said = { "door " .. tostring(door_name), "seed " .. tostring(seed) }
    if result.ok then
        write(base .. ".lua", result.text)
        local bytes, small = readings.thumbnail(result.compiled)
        write(base .. ".gif", bytes)
        said[#said + 1] = "passed " .. small
        for _, line in ipairs(result.heard) do said[#said + 1] = "heard " .. line end
    else
        if result.draft then write(base .. ".draft.lua", result.draft) end
        said[#said + 1] = "failed"
        for line in (result.errors .. "\n"):gmatch("([^\n]*)\n") do
            if line ~= "" then said[#said + 1] = "wall " .. line end
        end
    end
    write(base .. ".said", table.concat(said, "\n") .. "\n")
    return base
end
-- }}}

-- {{{ function readings.read_said()
-- A reading-K.said back as { door, seed, passed, size, heard, wall }, or
-- nil when that reading never landed.
function readings.read_said(folder, k)
    local f = io.open(folder .. "/reading-" .. k .. ".said", "r")
    if not f then return nil end
    local r = { heard = {}, wall = {} }
    for line in f:lines() do
        local word, rest = line:match("^(%S+) ?(.*)$")
        if word == "door" then r.door = rest
        elseif word == "seed" then r.seed = tonumber(rest)
        elseif word == "passed" then r.passed = true; r.size = tonumber(rest)
        elseif word == "failed" then r.passed = false
        elseif word == "heard" then r.heard[#r.heard + 1] = rest
        elseif word == "wall" then r.wall[#r.wall + 1] = rest end
    end
    f:close()
    return r
end
-- }}}

-- {{{ local function slurp()
local function slurp(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ function readings.page()
-- The pick page for one folder: the sentence, then each reading with
-- its film (or the wall's words, dimmed), what was heard, and its score
-- behind a disclosure. HTML and CSS only, in the gallery's look.
function readings.page(folder, prose, count, slug)
    local gallery = require("027-gallery")
    local esc = gallery.escape
    local cards = {}
    for k = 1, count do
        local r = readings.read_said(folder, k)
        local card = { '<figure class="reading' .. ((r and r.passed) and "" or " failed") .. '">' }
        card[#card + 1] = "<h2>reading " .. k .. "</h2>"
        if not r then
            card[#card + 1] = "<p>never came back</p>"
        elseif r.passed then
            card[#card + 1] = '<img src="reading-' .. k .. '.gif" width="' .. r.size
                .. '" height="' .. r.size .. '" alt="reading ' .. k .. '">'
            card[#card + 1] = "<ul>"
            for _, line in ipairs(r.heard) do card[#card + 1] = "<li>" .. esc(line) .. "</li>" end
            card[#card + 1] = "</ul>"
            card[#card + 1] = "<details><summary>the score</summary><pre><code>"
                .. esc(slurp(folder .. "/reading-" .. k .. ".lua") or "")
                .. "</code></pre></details>"
            card[#card + 1] = "<p class=\"pick\">pick it: <code>./porch --pick "
                .. esc(slug) .. " " .. k .. "</code></p>"
        else
            card[#card + 1] = "<p>did not pass:</p><pre><code>"
                .. esc(table.concat(r.wall, "\n")) .. "</code></pre>"
            local draft = slurp(folder .. "/reading-" .. k .. ".draft.lua")
            if draft then
                card[#card + 1] = "<details><summary>its draft</summary><pre><code>"
                    .. esc(draft) .. "</code></pre></details>"
            end
        end
        if r then
            card[#card + 1] = "<figcaption>" .. esc(r.door or "?") .. ", seed "
                .. tostring(r.seed) .. "</figcaption>"
        end
        card[#card + 1] = "</figure>"
        cards[#cards + 1] = table.concat(card, "\n")
    end
    local style = gallery.STYLE .. [[
main { margin-left: 0; max-width: none; }
.readings { display: grid; gap: 26px;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); }
.reading img { width: 256px; height: 256px; image-rendering: pixelated; }
.reading ul { padding-left: 18px; font-size: 13px; }
.failed { opacity: 0.55; }
.pick code { color: #ffb15e; }
]]
    local html = "<!doctype html>\n<html><head><meta charset='utf-8'>"
        .. "<title>three readings</title><style>" .. style .. "</style>"
        .. "</head><body>\n<main>\n<h1>“" .. esc(prose) .. "”</h1>\n"
        .. '<div class="readings">\n' .. table.concat(cards, "\n") .. "\n</div>\n"
        .. "</main></body></html>\n"
    write(folder .. "/index.html", html)
    return folder .. "/index.html"
end
-- }}}

-- {{{ function readings.pick()
-- Moves reading K's score into input/NAME.lua, whole or not at all,
-- never over a score already there, and remembers the door that heard
-- it in input/porch-history.txt. Returns the new score's path.
function readings.pick(dir, folder, k, name)
    local text = slurp(folder .. "/reading-" .. k .. ".lua")
    if not text then
        error("porch: reading " .. k .. " in " .. folder .. " has no score to pick"
              .. " (it failed the wall, or never came back)", 0)
    end
    local path = dir .. "/input/" .. name .. ".lua"
    if slurp(path) then
        error("porch: input/" .. name .. ".lua is already a score; pick it with "
              .. "another name", 0)
    end
    write(path, text)
    local r = readings.read_said(folder, k) or {}
    local prose = slurp(folder .. "/prose.txt") or "?"
    local h = assert(io.open(dir .. "/input/porch-history.txt", "a"))
    h:write(string.format("%s  %s heard it best (seed %s), of %s: %s\n",
        os.date("!%Y-%m-%d"), tostring(r.door), tostring(r.seed),
        folder:match("[^/]+$"), (prose:gsub("%s+$", ""):gsub("\n", " "))))
    h:close()
    return path
end
-- }}}

return readings
