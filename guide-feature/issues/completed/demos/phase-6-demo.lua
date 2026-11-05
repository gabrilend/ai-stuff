-- phase-6-demo.lua - the body of phase-6-demo: newest and distill, side by
-- side.
--
-- phase-6-demo makes a throwaway project and runs this in it. This:
--
--   1. records a rehearsal's arrivals (src/043-rehearsal.lua, with the real
--      turn in all three voices, each voice's stand-in model rewriting the
--      first word of a row, so the voices meet on the same words): every
--      voice canvas the blitter took, and the version it started from;
--      or reads a recording made before (--from);
--   2. replays those same canvases through the blitter twice, once in each
--      merge mode (src/016-blitter.lua: `newest`, and `distill` with a
--      stand-in distiller, src/047-stand-in-llama.lua, on 127.0.0.1), one
--      arrival at a time;
--   3. shows, for each arrival, the two canvases side by side, with the
--      words changed, the conflicts and the words written over (newest:
--      a conflict is the blit's, a word the voice erased that the shared
--      canvas no longer showed; a word written over is one already on the
--      shared canvas that the write cut into or covered), and the distill's
--      fit tries and seconds (distill), and at the end how many of each
--      voice's changes survived to the shared canvas in each mode.
--
-- Both modes see exactly the same input: each arrival's changes are found
-- against the version that voice started from in the recorded run.
--
-- usage (phase-6-demo does this):
--   luajit phase-6-demo.lua --dir PROJECT --root THROWAWAY --base FOLDER
--                           [--minutes M] [--from RECORDING] [--save FOLDER]
--                           [--plain]

-- {{{ arguments
local DIR, ROOT, BASE, PLAIN, MINUTES, FROM, SAVE
local index = 1
while index <= #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1]; index = index + 1
    elseif arg[index] == "--root" then ROOT = arg[index + 1]; index = index + 1
    elseif arg[index] == "--base" then BASE = arg[index + 1]; index = index + 1
    elseif arg[index] == "--minutes" then MINUTES = tonumber(arg[index + 1]); index = index + 1
    elseif arg[index] == "--from" then FROM = arg[index + 1]; index = index + 1
    elseif arg[index] == "--save" then SAVE = arg[index + 1]; index = index + 1
    elseif arg[index] == "--plain" then PLAIN = true end
    index = index + 1
end
if not (DIR and ROOT and BASE) then
    io.stderr:write("usage: luajit phase-6-demo.lua --dir PROJECT --root THROWAWAY --base FOLDER "
        .. "[--minutes M] [--from RECORDING] [--save FOLDER] [--plain]\n")
    os.exit(2)
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int isatty(int fd);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
if not PLAIN and ffi.C.isatty(1) == 0 then PLAIN = true end
if os.getenv("NO_COLOR") and os.getenv("NO_COLOR") ~= "" then PLAIN = true end

local canvas = dofile(ROOT .. "/src/006-canvas-text.lua")
local changes = dofile(ROOT .. "/src/010-changes.lua")
local utf8 = dofile(ROOT .. "/src/005-utf8.lua")
local blitter = dofile(ROOT .. "/src/016-blitter.lua")
local series = dofile(ROOT .. "/src/018-phase-1-series.lua")
local rehearsal = dofile(ROOT .. "/src/043-rehearsal.lua")
local json = dofile(ROOT .. "/libs/dkjson.lua")

local MINUTES_RUN = MINUTES or 1
local MODES = { "newest", "distill" }

-- {{{ small helpers
local function plural(n, one, many) return n .. " " .. (n == 1 and one or many) end
local function say(...) io.write(...) io.write("\n") io.flush() end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body or text, tonumber(status)
end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function fail(text)
    io.stderr:write("phase-6-demo: ", text, "\n")
    os.exit(1)
end
-- }}}

-- {{{ the stand-in models
-- One per voice, each rewriting the first word of a row from its own words,
-- a row further down each turn, starting the row when it is empty (047's
-- `rewrite` with `fill`), so the voices land on the same words and newest
-- mode has words written over to show; each takes its own time over a
-- reply, so the voices drift apart;
-- and the distiller, which takes in every voice's newest changes, the voice
-- listed first keeping a contested place (047's `distill` reply). The
-- distiller runs past the edge every fifth request and takes a fifth of a
-- second, so the distill's retries and seconds have something to show.
local function start(name, replies)
    local folder = BASE .. "/models/" .. name
    shell("mkdir -p " .. q(folder))
    write(folder .. "/replies", json.encode(replies))
    shell("luajit " .. q(ROOT .. "/src/047-stand-in-llama.lua") .. " --kind chat --port-file "
        .. q(folder .. "/port") .. " --replies " .. q(folder .. "/replies") .. " --requests "
        .. q(folder .. "/requests") .. " --parent $PPID > " .. q(folder .. "/out") .. " 2>&1 &")
    local port
    for _ = 1, 100 do
        port = tonumber((slurp(folder .. "/port") or ""):match("%d+"))
        if port then break end
        sleep(0.05)
    end
    if not port then fail("the stand-in model " .. name .. " did not start") end
    return { name = name, folder = folder, url = "http://127.0.0.1:" .. port }
end
local VOICE_WORDS = {
    ["fg-sora-1"] = "lantern harbor kitten orchard",
    ["fg-sora-2"] = "willow meadow heron",
    ["fg-sora-3"] = "copper ember quarry slate",
}
local VOICE_SECONDS = { ["fg-sora-1"] = 4, ["fg-sora-2"] = 5, ["fg-sora-3"] = 6 }
local DISTILLER = start("stand-in-distiller", { { distill = true, wide_every = 5, delay = 0.2 } })
local function endpoints(models)
    local lines = { "# the demo's endpoints: stand-in llama.cpp servers on 127.0.0.1" }
    for _, model in ipairs(models) do
        lines[#lines + 1] = model.name .. '.url = "' .. model.url .. '"'
        lines[#lines + 1] = model.name .. '.kind = "chat"'
        lines[#lines + 1] = model.name .. ".timeout = 30"
    end
    for _, model in ipairs(models) do
        lines[#lines + 1] = "use." .. model.role .. ' = "' .. model.name .. '"'
    end
    return table.concat(lines, "\n") .. "\n"
end
DISTILLER.role = "distiller"
-- }}}

-- {{{ the recording
-- A recording is a folder: `index` (one line per arrival: its number and
-- name), and for each arrival NNNN.voice (the voice's canvas as it arrived)
-- and NNNN.base (the version it started from, as viewers read it).
local RECORDING = FROM or (BASE .. "/recording")
local recorded = 0
if FROM then
    if not slurp(FROM .. "/index") then fail(FROM .. " is not a recording (it has no index)") end
    say("Replaying the recording in " .. FROM .. ".")
else
    shell("mkdir -p " .. q(RECORDING))
    local models = { DISTILLER }
    for _, voice in ipairs(rehearsal.VOICES) do
        local model = start("stand-in-" .. voice, { { rewrite = VOICE_WORDS[voice], fill = true,
            delay = VOICE_SECONDS[voice] } })
        model.role = voice
        models[#models + 1] = model
    end
    write(ROOT .. "/endpoints", endpoints(models))
    write(ROOT .. "/input/blitter", series.SETTINGS)
    say(string.format("Recording: the rehearsal runs for %s with the real turn (scripts/turn) in "
        .. "all three voices, in newest mode. Each voice's stand-in model rewrites the first "
        .. "word of a row (or starts an empty one), a row further down each turn, from its own "
        .. "words, taking its own time over a reply:",
        plural(MINUTES_RUN, "minute", "minutes")))
    for _, voice in ipairs(rehearsal.VOICES) do
        say("  ", voice, ": ", VOICE_WORDS[voice], string.format(" (%s s a reply)",
            VOICE_SECONDS[voice]))
    end
    say("so the voices meet on the same words. Every canvas the blitter takes is recorded with "
        .. "the version it started from.")
    local index_lines = {}
    local ok, problem = pcall(rehearsal.run, { root = ROOT, minutes = MINUTES_RUN,
        on_arrival = function(name, text, b)
            local base = tonumber(string.match(text, "\nbase: (%d+)\n") or "")
            local base_record = base and b.history[base]
            if not base_record then return end
            recorded = recorded + 1
            local number = string.format("%04d", recorded)
            write(RECORDING .. "/" .. number .. ".voice", text)
            write(RECORDING .. "/" .. number .. ".base", canvas.write(base_record, "for-viewers"))
            index_lines[#index_lines + 1] = number .. " " .. name
            write(RECORDING .. "/index", table.concat(index_lines, "\n") .. "\n")
        end })
    if not ok then fail("the rehearsal stopped: " .. tostring(problem)) end
    say("Recorded " .. plural(recorded, "voice canvas", "voice canvases") .. ".")
end
if SAVE then
    shell("mkdir -p " .. q(SAVE) .. " && cp " .. q(RECORDING) .. "/* " .. q(SAVE) .. "/")
    say("The recording is saved in " .. SAVE .. "; replay it with --from " .. SAVE .. ".")
end

local arrivals = {}
for line in string.gmatch(slurp(RECORDING .. "/index") or "", "[^\n]+") do
    local number, name = line:match("^(%d+) (%S+)$")
    if number then
        local voice_text = slurp(RECORDING .. "/" .. number .. ".voice")
        local base_text = slurp(RECORDING .. "/" .. number .. ".base")
        if not voice_text or not base_text then fail("the recording is missing " .. number) end
        local voice = canvas.read(voice_text, "from-voice", number .. ".voice")
        local base = canvas.read(base_text, "for-viewers", number .. ".base")
        arrivals[#arrivals + 1] = { number = number, name = name, voice = voice, base = base,
            sender = voice.headers.voice, found = changes.find(base, voice) }
    end
end
if #arrivals == 0 then fail("the recording holds no arrivals") end
-- }}}

-- {{{ the replays
-- Each mode gets its own blitter in its own folder, with the size and the
-- voices of the recording, and the distiller's endpoint. Each arrival is
-- accepted as the blitter accepts one that passed its checks (b:accept),
-- with the base it was recorded with, and in distill mode distilled at
-- once, so each arrival is one step in both modes.
local WIDTH, HEIGHT = arrivals[1].base.width, arrivals[1].base.height
local runs = {}
for _, mode in ipairs(MODES) do
    local root = BASE .. "/replay-" .. mode
    shell("mkdir -p " .. q(root .. "/input") .. " " .. q(root .. "/output"))
    for _, link in ipairs({ "src", "libs" }) do
        shell("ln -s " .. q(ROOT .. "/" .. link) .. " " .. q(root .. "/" .. link))
    end
    write(root .. "/input/blitter", string.format("canvas-size = %dx%d\nmerge-mode = \"%s\"\n"
        .. "collision-rule = \"blank-whole\"\nmark-lifetime = 0\nproject = \"guide-feature\"\n"
        .. "voices = \"%s\"\n", WIDTH, HEIGHT, mode, table.concat(rehearsal.VOICES, " ")))
    for _, name in ipairs({ "distill", "distill-instructions" }) do
        write(root .. "/input/" .. name, assert(slurp(ROOT .. "/input/" .. name)))
    end
    write(root .. "/endpoints", endpoints({ DISTILLER }))
    local b = blitter.new({ root = root, wait = function() end, commit = "0000000" })
    runs[mode] = { mode = mode, b = b, steps = {}, root = root }
end

local function replay(run, arrival)
    local b = run.b
    local before = b.version
    local outcome = b:accept(arrival.sender, arrival.voice, arrival.base, arrival.name)
    local report
    if outcome == "held" then
        local result = b:distill_held()
        if result == "failed" then fail("the distill failed; see " .. run.root) end
        outcome = result
        report = b.reports[#b.reports].report
    else
        report = b.reports[#b.reports].report
    end
    return { outcome = outcome, report = report, version = b.version,
             made = b.version > before, rows = b.current.rows, marks = b.current.marks }
end
for _, arrival in ipairs(arrivals) do
    for _, mode in ipairs(MODES) do
        local run = runs[mode]
        run.steps[#run.steps + 1] = replay(run, arrival)
    end
end
-- }}}

-- {{{ drawing
-- Two canvases side by side, each in a frame, the cells this step's version
-- changed shown in reverse (marked under the row with ^ when --plain), and
-- a * between the frames on every row where the two differ.
local GAP = "   "
local function cells_marked(step)
    local marked = {}
    if not step.made then return marked end
    for _, mark in ipairs(step.marks or {}) do
        if mark.version == step.version and mark.kind == "word" then
            marked[mark.row] = marked[mark.row] or {}
            for column = mark.column, mark.column + mark.length - 1 do
                marked[mark.row][column] = true
            end
        end
    end
    return marked
end
local function row_text(rows, row, marked)
    local cells = utf8.split(utf8.pad(rows[row] or "", WIDTH))
    local out, under, any = {}, {}, false
    for column = 1, WIDTH do
        local hit = marked[row] and marked[row][column]
        if hit and not PLAIN then
            out[column] = "\27[7m" .. cells[column] .. "\27[0m"
        else
            out[column] = cells[column]
        end
        under[column] = hit and "^" or " "
        any = any or hit
    end
    return table.concat(out), table.concat(under), any
end
local function side_by_side(left, right, left_title, right_title)
    local edge = "+" .. string.rep("-", WIDTH) .. "+"
    say("  ", utf8.pad(left_title, WIDTH + 2), GAP, right_title)
    say("  ", edge, GAP, edge)
    local lm, rm = cells_marked(left), cells_marked(right)
    for row = 1, HEIGHT do
        local lt, lu, la = row_text(left.rows, row, lm)
        local rt, ru, ra = row_text(right.rows, row, rm)
        local differ = (left.rows[row] or ""):gsub("%s+$", "") ~= (right.rows[row] or ""):gsub("%s+$", "")
        say("  |", lt, "|", differ and " * " or GAP, "|", rt, "|")
        if PLAIN and (la or ra) then
            say((("   " .. lu .. " " .. GAP .. " " .. ru):gsub("%s+$", "")))
        end
    end
    say("  ", edge, GAP, edge)
end
local function words_changed(report)
    return report.counts["words-written"] + report.counts["removals-applied"]
end
-- A conflict is the blit's (106): a word the voice erased that the shared
-- canvas no longer showed. A word written over is one already on the shared
-- canvas that the voice's write cut into or covered.
local function written_over(report)
    return report.counts["words-covered"] + #report.cut
end
local function newest_line(step)
    if not step.made then return "newest: no new version" end
    return string.format("newest: v%d, %s, %s, %s", step.version,
        plural(words_changed(step.report), "word changed", "words changed"),
        plural(step.report.counts.conflicts, "conflict", "conflicts"),
        plural(written_over(step.report), "word written over", "words written over"))
end
local function distill_line(step)
    local d = step.report.distill
    local tries = d.counts.tries
    local text = string.format("%s, %.2f s", tries == 1 and "fit at the first try"
        or ("fit at try " .. tries), d.counts.seconds)
    if not step.made then return "distill: no new version (" .. text .. ")" end
    return string.format("distill: v%d, %s, %s", step.version,
        plural(words_changed(step.report), "word changed", "words changed"), text)
end
local function change_words(found)
    local list = {}
    for _, word in ipairs(found.written) do list[#list + 1] = '"' .. word.text .. '"' end
    if #list == 0 then return "no words written" end
    return "wrote " .. table.concat(list, ", ")
end
-- }}}

-- {{{ the arrivals, side by side
say("")
say(string.format("Both modes replay the same %s, one at a time. Each pair is the shared "
    .. "canvas after that arrival: newest mode on the left, distill mode on the right. Cells "
    .. "the arrival's version changed are %s; a * between the frames marks a row where the "
    .. "two modes differ.", plural(#arrivals, "voice canvas", "voice canvases"),
    PLAIN and "marked ^ underneath" or "shown in reverse"))
for number, arrival in ipairs(arrivals) do
    local left, right = runs.newest.steps[number], runs.distill.steps[number]
    say("")
    say(string.format("Arrival %d: %s turn %d, on version %d (%s)", number, arrival.sender,
        arrival.voice.headers.turn, arrival.voice.headers.base, change_words(arrival.found)))
    say("  ", newest_line(left))
    say("  ", distill_line(right))
    side_by_side(left, right, "newest", "distill")
end
-- }}}

-- {{{ the totals, and what survived
-- A voice's change survived when the final shared canvas still shows it: a
-- word it wrote still stands where it wrote it, a word it erased is still
-- not there.
local function survived(rows, found)
    local kept, total = 0, 0
    local function at(word)
        local cells = utf8.split(utf8.pad(rows[word.row] or "", WIDTH))
        local text = {}
        for column = word.column, word.column + word.length - 1 do text[#text + 1] = cells[column] or " " end
        return table.concat(text)
    end
    for _, word in ipairs(found.written) do
        total = total + 1
        if at(word) == word.text then kept = kept + 1 end
    end
    for _, list in ipairs({ found.removed, found.overwritten }) do
        for _, word in ipairs(list) do
            total = total + 1
            if at(word) ~= word.text then kept = kept + 1 end
        end
    end
    return kept, total
end
say("")
say("Totals")
local totals = {}
for _, mode in ipairs(MODES) do
    local t = { versions = 0, words = 0, conflicts = 0, over = 0, tries = 0, retries = 0,
                seconds = 0 }
    for _, step in ipairs(runs[mode].steps) do
        if step.made then t.versions = t.versions + 1 end
        t.words = t.words + words_changed(step.report)
        t.conflicts = t.conflicts + step.report.counts.conflicts
        t.over = t.over + written_over(step.report)
        if step.report.distill then
            t.tries = t.tries + step.report.distill.counts.tries
            t.retries = t.retries + step.report.distill.counts.tries - 1
            t.seconds = t.seconds + step.report.distill.counts.seconds
        end
    end
    totals[mode] = t
end
say(string.format("  newest:  %s, %s, %s, %s", plural(totals.newest.versions, "version",
    "versions"), plural(totals.newest.words, "word changed", "words changed"),
    plural(totals.newest.conflicts, "conflict", "conflicts"),
    plural(totals.newest.over, "word written over", "words written over")))
say(string.format("  distill: %s, %s, %s, %s, %.2f s distilling",
    plural(totals.distill.versions, "version", "versions"),
    plural(totals.distill.words, "word changed", "words changed"),
    plural(#arrivals, "distill", "distills"),
    plural(totals.distill.retries, "fit retry", "fit retries"), totals.distill.seconds))
say("")
say("What survived: each voice's changes (words written and erased) that the final shared "
    .. "canvas still shows, in each mode")
for _, voice in ipairs(rehearsal.VOICES) do
    local counts = {}
    for _, mode in ipairs(MODES) do
        local kept, total = 0, 0
        for _, arrival in ipairs(arrivals) do
            if arrival.sender == voice then
                local k, t = survived(runs[mode].b.current.rows, arrival.found)
                kept, total = kept + k, total + t
            end
        end
        counts[mode] = { kept = kept, total = total }
    end
    say(string.format("  %s: newest %d of %d, distill %d of %d", voice, counts.newest.kept,
        counts.newest.total, counts.distill.kept, counts.distill.total))
end
say("")
say("The final shared canvases:")
local last_left = { rows = runs.newest.b.current.rows, made = false }
local last_right = { rows = runs.distill.b.current.rows, made = false }
side_by_side(last_left, last_right, "newest, v" .. runs.newest.b.version,
    "distill, v" .. runs.distill.b.version)
for _, mode in ipairs(MODES) do runs[mode].b:finish() end
say("")
say("Each mode's blitter log is in its replay folder (replay-newest, replay-distill); with "
    .. "--keep they stay.")
-- }}}
