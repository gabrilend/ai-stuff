#!/usr/bin/env luajit
-- {{{ neocities-push-progress.lua
-- Live per-directory progress for `neocities push`.
--
-- For the general reader: the Neocities upload client prints one line per file as
-- it goes -- e.g. "Uploading similar-different/different/4902-01.html ... SUCCESS".
-- During a deploy that is thousands of lines scrolling by, impossible to read. This
-- filter consumes that stream and instead draws ONE progress bar per top-level
-- directory under similar-different/ (chronological, similar, different, wordcloud,
-- media, source, gallery, and "other" for loose root files), each filling as its
-- section uploads. It is a VIEWER only -- it changes nothing, just reformats the
-- push output. deploy-to-neocities pipes push through it when writing to a terminal.
--
-- Usage (driven by deploy-to-neocities):
--   neocities push ... 2>&1 | luajit neocities-push-progress.lua <bucket:total> ...
-- Each argument is a directory name and how many files it holds, e.g. different:7904
-- -- the totals are the bar denominators, computed once from the staged copy.
-- }}}

-- {{{ parse the bucket:total arguments (their order is the display order)
local order, total, done = {}, {}, {}
for _, a in ipairs(arg) do
    local name, n = a:match("^(.-):(%d+)$")
    if name and name ~= "" then
        order[#order + 1] = name
        total[name] = tonumber(n)
        done[name] = 0
    end
end
local known = {}
for _, n in ipairs(order) do known[n] = true end
if #order == 0 then
    -- Nothing to chart (no buckets passed): act as a pass-through so output is not lost.
    for line in io.lines() do io.write(line, "\n") end
    return
end
-- }}}

local BAR_W = 28
local failures = {}
local first = true

-- {{{ local function totals()
-- Sum uploaded / total across all buckets, for the header line.
local function totals()
    local td, tt = 0, 0
    for _, n in ipairs(order) do td = td + done[n]; tt = tt + total[n] end
    return td, tt
end
-- }}}

-- {{{ local function format_bar(name)
local function format_bar(name)
    local t, d = total[name] or 0, done[name] or 0
    local frac = t > 0 and d / t or 0
    if frac > 1 then frac = 1 end          -- never overflow if remote held extras
    local filled = math.floor(frac * BAR_W + 0.5)
    local bar = string.rep("█", filled) .. string.rep("░", BAR_W - filled)
    return string.format("  %-13s %s %6d/%-6d %3d%%",
        name, bar, d, t, math.floor(frac * 100 + 0.5))
end
-- }}}

-- {{{ local function render()
-- Redraw the header + every bar IN PLACE: move the cursor up over the block drawn
-- last frame, then rewrite each line (clearing it first). Assumes a terminal; the
-- caller only pipes us here when stdout is a TTY.
local function render()
    local nlines = #order + 1
    if not first then io.write(string.format("\27[%dA", nlines)) end
    first = false
    local td, tt = totals()
    io.write("\27[2K", string.format("Deploying to similar-different/  %d/%d files\n", td, tt))
    for _, n in ipairs(order) do
        io.write("\27[2K", format_bar(n), "\n")
    end
    io.flush()
end
-- }}}

render()  -- initial frame, so later cursor-up has a block to return to

-- {{{ consume the push stream, one line per uploaded file
for line in io.lines() do
    -- "Uploading <path> ... <STATUS>" -- pull out the path, bucket by its first dir.
    local path = line:match("^Uploading%s+(.-)%s+%.%.%.")
    if path then
        local rel = path:gsub("^similar%-different/", "")
        local bucket = rel:match("^([^/]+)/") or "other"
        if not known[bucket] then bucket = "other" end   -- fold surprises into other
        if done[bucket] ~= nil then done[bucket] = done[bucket] + 1 end
        if line:find("FAIL") or line:find("ERROR") then failures[#failures + 1] = line end
        render()
    end
    -- Non-"Uploading" lines (banners, blank lines) are not counted; genuine errors
    -- are captured above and the push exit code still propagates through the pipe.
end
-- }}}

-- {{{ final summary (below the finished bars)
io.write("\n")
local td, tt = totals()
io.write(string.format("Done: uploaded %d of %d staged files to similar-different/.\n", td, tt))
if #failures > 0 then
    io.write(string.format("%d failure(s):\n", #failures))
    for _, f in ipairs(failures) do io.write("  ", f, "\n") end
end
-- }}}
