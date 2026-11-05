#!/usr/bin/env luajit
-- 073-test-lua-window.lua
--
-- Tests the Lua window (issue 802, src/072-lua-window.lua,
-- scripts/lua-window), all but the window itself, which is not built yet.
-- The settings and their refusals; the colour behind each cell (a voice's
-- colour laid over the background, a word mark stronger than a sentence
-- mark, fading with age, kuvalu's own); the letters (every printable
-- character drawn, a box for the rest); the writing-over (each changed word
-- written left to right over write-seconds, what was there shown until
-- then); the picture and the PNG it is saved as, read back pixel by pixel;
-- the text grid beside it; then the program: a replay with screenshots on a
-- pretend clock, a newer version cutting one short, keys (q stops, space
-- pauses, s screenshots), the live canvas, the stop file, the receipt, and
-- the screenshots filed into development-history/ by scripts/lua-window.
--
-- For a general: the canvas can be drawn as a picture with each voice's new
-- words written in over the old ones, ready for a window to show; until
-- kuvalu has a window library, the pictures are saved instead.
--
-- usage:
--   luajit 073-test-lua-window.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
local bit = require("bit")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
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
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function refused(f, ...)
    local ok, problem = pcall(f, ...)
    return not ok and tostring(problem) or nil
end
local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
local function show(rgb) return rgb and table.concat(rgb, ",") or "nil" end
local function list(path)
    local out = shell("ls -1 " .. q(path) .. " 2>/dev/null")
    local names = {}
    for name in string.gmatch(out or "", "[^\n]+") do names[#names + 1] = name end
    return names
end
-- }}}

-- {{{ the throwaway project
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
local SETTINGS = slurp(DIR .. "/input/lua-window")
write(ROOT .. "/input/lua-window", SETTINGS)
local CANVAS = ROOT .. "/tmp/shared-memory/canvas"
shell("mkdir -p " .. q(CANVAS .. "/history"))
local function with_setting(name, value)
    local text = string.gsub(SETTINGS, "\n" .. string.gsub(name, "%-", "%%-") .. "%s*=[^\n]*",
        "\n" .. name .. " = " .. value)
    write(ROOT .. "/input/lua-window", text)
end
-- }}}

local window = dofile(DIR .. "/src/072-lua-window.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local font = dofile(DIR .. "/libs/bitmap-font.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")

-- {{{ local function version() -- a canvas for viewers, 24x3
local function version(n, rows, marks, voices)
    local r = canvas.blank(24, 3, "for-viewers")
    for number, row in ipairs(rows) do r.rows[number] = row end
    r.headers = { canvas = n, size = { width = 24, height = 3 }, mode = "newest",
        project = { name = "guide-feature", commit = "0000000" }, written = "2026-11-05T10:00:00Z",
        voices = voices or { "fg-sora-1", "fg-sora-2", "fg-sora-3" } }
    r.marks = {}
    for _, m in ipairs(marks or {}) do
        r.marks[#r.marks + 1] = { row = m[1], column = m[2], length = m[3], voice = m[4],
                                  version = m[5], kind = m[6] }
    end
    return canvas.write(r, "for-viewers")
end
-- }}}

-- the replay: the cat sits; a dog takes its place and it rains; the dog runs
local V1 = version(1, { "the cat sat." }, { { 1, 5, 3, "fg-sora-1", 1, "word" },
    { 1, 1, 4, "fg-sora-1", 1, "sentence" } })
local V2 = version(2, { "the dog sat.", "it rains $5 & @home" }, {
    { 1, 5, 3, "fg-sora-2", 2, "word" }, { 2, 1, 8, "fg-sora-3", 2, "word" } })
local V3 = version(3, { "the dog ran.", "it rains $5 & @home", "caf\195\169 ~ {ok}" }, {
    { 1, 5, 3, "fg-sora-2", 2, "word" }, { 1, 9, 3, "kuvalu", 3, "word" },
    { 2, 1, 8, "fg-sora-3", 2, "word" }, { 3, 1, 4, "fg-sora-1", 3, "sentence" } })
local REPLAY = BASE .. "/replay"
shell("mkdir -p " .. q(REPLAY))
write(REPLAY .. "/0001", V1)
write(REPLAY .. "/0002", V2)
write(REPLAY .. "/0003", V3)

io.write("\n=== the settings ===\n")
-- {{{
local s = window.read_settings(ROOT)
check("input/lua-window reads: three voice colours, letters twice their size",
    #s.voices == 3 and s.scale == 2 and s.write_seconds == 0.4 and s.fps == 30
    and same(s.background, { 16, 20, 24 }))
local function refusal(name, value)
    with_setting(name, value)
    local problem = refused(window.read_settings, ROOT)
    write(ROOT .. "/input/lua-window", SETTINGS)
    return problem
end
check("a colour not written #rrggbb is refused, naming the file and the setting",
    has(refusal("voice-colours", '"#e05050 red #4a78e0"'), "input/lua-window: voice-colours: 'red'"))
check("so is a background not written #rrggbb", has(refusal("background", '"#1014"'), "background:"))
check("a strength above 1 is refused", has(refusal("word-strengths", '"0.9 1.5"'), "'1.5' is not a strength"))
check("an empty list is refused", has(refusal("sentence-strengths", '""'), "sentence-strengths: no strength"))
check("a letter scale below 1 is refused", has(refusal("letter-scale", "0"), "letter-scale"))
check("a write time of 0 is refused", has(refusal("write-seconds", "0"), "write-seconds: must be above 0"))
-- }}}

io.write("\n=== the colour behind each cell ===\n")
-- {{{
local aging = viewer.read(slurp(DIR .. "/assets/test-canvases/04-aging.canvas"), "04-aging")
local function mark_at(view, row, column) return view.cells[row][column].mark end
check("an unmarked cell has the background", same(window.background(aging, nil, s), s.background))
-- 04-aging, row 1, column 1: fg-sora-3's word mark, made at this version
check("a new word mark lays its voice's colour over the background at the first strength "
    .. "(0.85 of #4a78e0 over #101418)", same(window.background(aging, mark_at(aging, 1, 1), s),
        { 65, 105, 194 }), show(window.background(aging, mark_at(aging, 1, 1), s)))
check("each channel is rounded, not cut (0.35 of #e05050 over #101418 is 89,41,44)",
    same(window.blend(s.background, s.voices[1], 0.35), { 89, 41, 44 }),
    show(window.blend(s.background, s.voices[1], 0.35)))
local word = { voice = "fg-sora-1", kind = "word", age = 0 }
local sentence = { voice = "fg-sora-1", kind = "sentence", age = 0 }
local fading, stronger = true, true
for age = 0, 6 do
    word.age, sentence.age = age, age
    local w, sen = window.strength(word, s), window.strength(sentence, s)
    if w < sen then stronger = false end
    word.age = age + 1
    if age + 1 < #s.word and window.strength(word, s) >= w then fading = false end
end
check("a word mark is stronger than a sentence mark of the same age", stronger)
check("a mark fades with each version it ages", fading)
word.age = 50
check("a mark older than the list takes the last strength", window.strength(word, s) == s.word[#s.word])
check("an orphan mark is drawn as a sentence mark",
    window.strength({ voice = "fg-sora-2", kind = "orphan", age = 0 }, s) == s.sentence[1])
check("kuvalu's mark is in kuvalu's colour",
    same(window.voice_colour(aging, mark_at(aging, 3, 6), s), s.kuvalu))
local five = viewer.read(version(1, { "abcde" }, { { 1, 5, 1, "e5", 1, "word" } },
    { "a1", "b2", "c3", "d4", "e5" }), "five")
check("a fifth voice takes the colours round again (the second colour)",
    same(window.voice_colour(five, mark_at(five, 1, 5), s), s.voices[2]))
check("a voice the header does not list gets no colour", window.voice_colour(aging,
    { voice = "nobody", kind = "word", age = 0 }, s) == nil
    and same(window.background(aging, { voice = "nobody", kind = "word", age = 0 }, s), s.background))
-- }}}

io.write("\n=== the letters ===\n")
-- {{{
local all_found, missing = true, {}
for code = 32, 126 do
    local _, found = window.glyph(string.char(code))
    if not found then all_found = false; missing[#missing + 1] = string.char(code) end
end
check("every printable character has a picture (the font's own, or one drawn here)", all_found,
    table.concat(missing, " "))
local extra_ok = true
for character, picture in pairs(window.EXTRA_PICTURES) do
    if font.PICTURES[character] or not pcall(font.rows_of_picture, picture, character) then
        extra_ok = false
    end
end
check("the pictures drawn here are eight by eight and only for what the font lacks", extra_ok)
local box, box_found = window.glyph("\195\169")
local want_box = font.rows_of_picture(font.MISSING, "box")
check("a letter beyond ASCII is the font's hollow box, never a blank",
    not box_found and table.concat(box, ",") == table.concat(want_box, ","))
check("a space is blank", table.concat(window.glyph(" "), ",") == "0,0,0,0,0,0,0,0")
-- }}}

io.write("\n=== the writing-over ===\n")
-- {{{
local v1, v2, v3 = viewer.read(V1, "v1"), viewer.read(V2, "v2"), viewer.read(V3, "v3")
local w3 = window.animation(v3, v2, 10, 0.4)
check("'sat' to 'ran' is one run of three, though its 'a' stayed",
    w3.flips[1][9] and w3.flips[1][10] == nil and w3.flips[1][11]
    and math.abs(w3.flips[1][9] - (10 + 0.4 / 3)) < 1e-9 and math.abs(w3.flips[1][11] - 10.4) < 1e-9,
    tostring(w3.flips[1][9]) .. " " .. tostring(w3.flips[1][11]))
check("each word is its own run, all written at once", w3.runs == 4
    and math.abs(w3.flips[3][4] - 10.4) < 1e-9 and math.abs(w3.flips[3][6] - 10.4) < 1e-9
    and math.abs(w3.flips[3][11] - 10.4) < 1e-9 and w3.ends == 10.4, w3.runs)
local w1 = window.animation(v1, nil, 0, 0.4)
check("the first version is written over a blank: every letter is new",
    w1.changes == 10 and w1.previous == nil)
local start = window.frame(w3, 10, s)
check("as the version arrives, the changed cells still show what was there", start.cells[1][9].character
    == "s" and start.cells[1][11].character == "t" and start.cells[3][1].character == " "
    and start.cells[1][9].writing and not start.done)
check("an unchanged cell inside the word shows the new mark at once",
    start.cells[1][10].character == "a" and not start.cells[1][10].writing
    and same(start.cells[1][10].background, window.background(v3, mark_at(v3, 1, 10), s)))
local w2 = window.animation(v2, v1, 0, 0.4)
local before_dog = window.frame(w2, 0, s)
check("a cell not yet written over keeps its old background (the old voice's colour)",
    before_dog.cells[1][5].character == "c" and mark_at(v1, 1, 5) ~= nil
    and same(before_dog.cells[1][5].background, window.background(v1, mark_at(v1, 1, 5), s))
    and not same(before_dog.cells[1][5].background, window.background(v2, mark_at(v2, 1, 5), s)))
local middle = window.frame(w3, 10 + 0.4 / 3, s)
check("a third of the way, the run's first letter is written; the rest wait",
    middle.cells[1][9].character == "r" and middle.cells[1][11].character == "t"
    and middle.cells[3][1].character == "c" and middle.cells[3][2].character == " ")
local finish = window.frame(w3, 10.4, s)
check("after write-seconds every change is written, in its new colours", finish.done
    and finish.cells[1][11].character == "n" and finish.cells[3][4].character == "\195\169"
    and same(finish.cells[1][11].background, window.background(v3, mark_at(v3, 1, 11), s)))
local grid = window.text_grid(middle, w3)
check("the text grid: the characters, then what is behind each cell",
    has(grid, "|the dog rat.            |") and has(grid, "|....222.KK~.............|")
    and has(grid, "|33333333................|") and has(grid, "|a~~~.~..~~~.............|"), grid)
local aging_grid = window.text_grid(window.frame(window.animation(aging, aging, 0, 0.4), 1, s),
    window.animation(aging, aging, 0, 0.4))
check("word marks by voice number, sentence marks by letter, kuvalu as K or k",
    has(aging_grid, "|333.............|") and has(aging_grid, "|111.aa.bbbbb....|")
    and has(aging_grid, "|...b.KKK........|"), aging_grid)
-- }}}

io.write("\n=== the picture and its PNG ===\n")
-- {{{
-- {{{ local function read_png() -- the test's own reader, stored blocks only
local crc_table = {}
for n = 0, 255 do
    local c = n
    for _ = 1, 8 do
        if c % 2 == 1 then c = bit.bxor(0xEDB88320, bit.rshift(c, 1)) else c = bit.rshift(c, 1) end
    end
    crc_table[n] = c
end
local function crc(text)
    local c = bit.bnot(0)
    for index = 1, #text do
        c = bit.bxor(crc_table[bit.band(bit.bxor(c, text:byte(index)), 0xFF)], bit.rshift(c, 8))
    end
    return bit.tobit(bit.bnot(c))
end
local function u32(text, at)
    local a, b, c, d = text:byte(at, at + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
end
local function read_png(data)
    if data:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil, "no PNG signature" end
    local at, width, height, idat, kinds = 9, nil, nil, {}, {}
    while at <= #data do
        local length = u32(data, at)
        local kind = data:sub(at + 4, at + 7)
        local body = data:sub(at + 8, at + 7 + length)
        if bit.tobit(u32(data, at + 8 + length)) ~= crc(kind .. body) then
            return nil, kind .. "'s CRC is wrong"
        end
        kinds[#kinds + 1] = kind
        if kind == "IHDR" then
            width, height = u32(body, 1), u32(body, 5)
            if body:sub(9, 13) ~= "\8\2\0\0\0" then return nil, "not 8-bit RGB" end
        elseif kind == "IDAT" then idat[#idat + 1] = body end
        at = at + 12 + length
    end
    local z = table.concat(idat)
    local raw, place, a, b = {}, 3, 1, 0
    while true do
        local final = z:byte(place) % 2
        local size = z:byte(place + 1) + z:byte(place + 2) * 256
        local inverse = z:byte(place + 3) + z:byte(place + 4) * 256
        if size + inverse ~= 65535 then return nil, "a stored block's length is wrong" end
        raw[#raw + 1] = z:sub(place + 5, place + 4 + size)
        place = place + 5 + size
        if final == 1 then break end
    end
    raw = table.concat(raw)
    for index = 1, #raw do
        a = (a + raw:byte(index)) % 65521
        b = (b + a) % 65521
    end
    if u32(z, place) ~= b * 65536 + a then return nil, "the Adler-32 is wrong" end
    if #raw ~= (width * 3 + 1) * height then return nil, "the pixel data's length is wrong" end
    for y = 0, height - 1 do
        if raw:byte(y * (width * 3 + 1) + 1) ~= 0 then return nil, "a row has a filter" end
    end
    return { width = width, height = height, kinds = table.concat(kinds, " "),
             pixel = function(x, y)
                 local at = y * (width * 3 + 1) + 1 + x * 3 + 1
                 return { raw:byte(at, at + 2) }
             end }
end
-- }}}
local picture = window.raster(finish, s)
check("the picture is the canvas's size in cells, each 8 x letter-scale pixels",
    picture.width == 24 * 16 and picture.height == 3 * 16)
local png, problem = read_png(window.png(picture))
check("it is saved as a PNG that reads back (chunk CRCs, stored blocks, Adler-32)",
    png and png.width == 384 and png.height == 48 and png.kinds == "IHDR IDAT IEND", problem)
-- cell (1,1) 't' unmarked; 'd' at (1,5) under fg-sora-2's word mark, age 1
check("an unmarked space is the background", png and same(png.pixel(23 * 16 + 3, 3), s.background))
local t_rows = font.rows("t")
local lit_x, lit_y
for y = 0, 7 do
    for x = 0, 7 do
        if not lit_x and bit.band(t_rows[y + 1], bit.rshift(0x80, x)) ~= 0 then lit_x, lit_y = x, y end
    end
end
check("a letter's lit dots are in ink, each dot letter-scale pixels square", png
    and same(png.pixel(lit_x * 2, lit_y * 2), s.ink) and same(png.pixel(lit_x * 2 + 1, lit_y * 2 + 1), s.ink))
local every_dot = png ~= nil
for y = 0, 15 do
    for x = 0, 15 do
        local lit = bit.band(t_rows[math.floor(y / 2) + 1], bit.rshift(0x80, math.floor(x / 2))) ~= 0
        if png and not same(png.pixel(x, y), lit and s.ink or s.background) then every_dot = false end
    end
end
check("every pixel of the 't' is its picture's dot, scaled", every_dot)
check("an unlit dot of a marked cell is its voice's colour at the mark's strength",
    png and same(png.pixel(4 * 16, 0), window.background(v3, mark_at(v3, 1, 5), s)),
    png and show(png.pixel(4 * 16, 0)))
local big = window.raster(window.frame(window.animation(aging, nil, 0, 0.4), 1, s),
    { scale = 1, ink = s.ink, background = s.background })
check("a letter scale of 1 draws 8 by 8 cells", big.width == 16 * 8 and big.height == 3 * 8)
-- }}}

io.write("\n=== the program: a replay on a pretend clock ===\n")
-- {{{
local LUA = "luajit " .. q(DIR .. "/src/072-lua-window.lua") .. " --dir " .. q(ROOT)
local SHOTS = ROOT .. "/tmp/shared-memory/lua-window/screenshots"
local LOG = ROOT .. "/tmp/shared-memory/lua-window.log"
local function receipt() return goodbye.read(ROOT .. "/output/goodbye-lua-window").counters end
write(REPLAY .. "/0004", "not a canvas\n")
local out, status = shell(LUA .. " --replay " .. q(REPLAY) .. " --fast --screenshot 1.2 --screenshot 2.6")
local c = receipt()
check("a replay runs to its end and says goodbye", status == 0 and has(out, "goodbye-lua-window")
    and has(slurp(LOG), "the replay is over"), out)
check("its receipt counts every version, and the one that does not read",
    c["versions-received"] == 4 and c["unreadable"] == 1 and c["versions-drawn"] == 3
    and c["cut-short"] == 0 and c["screenshots"] == 2 and c["seconds-run"] == 3)
check("each version is drawn at the frame rate while it is written over (at least 12 frames "
    .. "in 0.4 s at 30 a second)", c["frames-drawn"] >= 3 * 12 and c["frames-drawn"] <= 3 * 15,
    c["frames-drawn"])
local frames = c["frames-drawn"]
local shots = list(SHOTS)
check("each screenshot is a PNG and a text grid, named by its time and version",
    #shots == 4 and shots[1] == "01-at-001.20s-version-2.png" and shots[4] == "02-at-002.60s-version-3.txt",
    table.concat(shots, " "))
local early = slurp(SHOTS .. "/01-at-001.20s-version-2.txt") or ""
check("0.2 s into version 2, 'cat' is half written over: 'dat'",
    has(early, "|the dat sat.            |") and has(early, "|....2~~.................|"), early)
local late = slurp(SHOTS .. "/02-at-002.60s-version-3.txt") or ""
check("after it, the last version in full", has(late, "|the dog ran.            |")
    and has(late, "|....222.KKK.............|") and has(late, "|aaaa....................|"), late)
local png_late = read_png(slurp(SHOTS .. "/02-at-002.60s-version-3.png") or "")
check("the saved PNG reads back", png_late ~= nil and png_late.width == 384)
shell(LUA .. " --replay " .. q(REPLAY) .. " --fast --screenshot 0.5")
check("a later run's screenshots are numbered after those still waiting to be filed",
    slurp(SHOTS .. "/03-at-000.50s-version-1.png") ~= nil and #list(SHOTS) == 6)
shell("rm -f " .. q(SHOTS) .. "/*")
shell(LUA .. " --replay " .. q(REPLAY) .. " --fast --screenshot 8")
c = receipt()
check("waiting with nothing new draws no frames (a screenshot at 8 s, the same frames)",
    c["frames-drawn"] == frames and c["seconds-run"] == 8 and #list(SHOTS) == 2, c["frames-drawn"])
shell("rm -f " .. q(SHOTS) .. "/*")
with_setting("replay-every", "0.2")
shell(LUA .. " --replay " .. q(REPLAY) .. " --fast --screenshot 0.25")
c = receipt()
write(ROOT .. "/input/lua-window", SETTINGS)
local cut = slurp(SHOTS .. "/01-at-000.25s-version-2.txt") or ""
check("the version cut short is what the next is written over", has(cut, "|the cat sat.            |")
    and has(cut, "|....~~~.................|"), cut)
shell("rm -f " .. q(SHOTS) .. "/*")
check("a version arriving before the last is written over cuts it short: shown in full at once",
    c["cut-short"] == 2 and c["versions-drawn"] == 1 and has(slurp(LOG), "version 1 cut short by version 2"))
os.remove(REPLAY .. "/0004")
-- }}}

io.write("\n=== keys ===\n")
-- {{{
shell(LUA .. " --replay " .. q(REPLAY) .. " --fast --key 1.5 q")
c = receipt()
check("q stops it: two versions in, at 1.5 s", c["versions-received"] == 2 and c["keys-pressed"] == 1
    and c["seconds-run"] == 2 and has(slurp(LOG), "q pressed at 1.50 s: stopping"))
shell(LUA .. " --replay " .. q(REPLAY) .. " --fast --key 0.5 space --screenshot 3 --key 3.5 space"
    .. " --key 3.6 x --key 4.5 s")
c = receipt()
shots = list(SHOTS)
check("space pauses the replay and space again resumes it: at 3 s still version 1",
    shots[1] == "01-at-003.00s-version-1.png" and c["versions-received"] == 3
    and has(slurp(LOG), "space at 0.50 s: replay paused"), table.concat(shots, " "))
check("s takes a screenshot (version 2 arrived at 4 s, a second late, after the pause)",
    shots[3] == "02-at-004.50s-version-2.png" and c["screenshots"] == 2, table.concat(shots, " "))
check("a key with no use is logged and does nothing", has(slurp(LOG), "key x at 3.60 s does nothing")
    and c["keys-pressed"] == 4 and c["versions-drawn"] == 3)
shell("rm -f " .. q(SHOTS) .. "/*")
-- }}}

io.write("\n=== the live canvas, the stop file, development-history ===\n")
-- {{{
write(CANVAS .. "/current", V1)
shell(LUA .. " --fast --for 2 --screenshot 1")
c = receipt()
check("without --replay it draws canvas/current, once while it is unchanged",
    c["versions-received"] == 1 and c["versions-drawn"] == 1 and c["seconds-run"] == 2
    and has(slurp(LOG), "watching "))
shell("rm -f " .. q(SHOTS) .. "/*")
shell("mkdir -p " .. q(ROOT .. "/development-history"))
write(ROOT .. "/development-history/007-an-older-picture.png", "older")
local LIVE = BASE .. "/live.out"
shell("( " .. q(ROOT .. "/scripts/lua-window") .. " " .. q(ROOT) .. " --screenshot 0.6 > " .. q(LIVE)
    .. " 2>&1; echo $? > " .. q(BASE .. "/live.status") .. " ) > /dev/null 2>&1 &")
local function wait_for(test)
    for _ = 1, 100 do
        if test() then return true end
        sleep(0.05)
    end
    return false
end
check("scripts/lua-window draws the live canvas", wait_for(function()
    return has(slurp(LOG), "watching ") and has(slurp(LOG), "screenshot at 0.6") end), slurp(LIVE))
write(CANVAS .. "/.current", V2)
os.rename(CANVAS .. "/.current", CANVAS .. "/current")
sleep(0.8)
shell("mkdir -p " .. q(ROOT .. "/tmp/shared-memory/lua-window") .. " && : > "
    .. q(ROOT .. "/tmp/shared-memory/lua-window/stop"))
check("the stop file ends it cleanly", wait_for(function()
    return (slurp(BASE .. "/live.status") or ""):match("^0") ~= nil end), slurp(LIVE))
c = receipt()
check("its receipt: both versions received and written over", c["versions-received"] == 2
    and c["versions-drawn"] == 2 and has(slurp(LOG), "stop file found"))
local history = list(ROOT .. "/development-history")
check("its screenshot is filed into development-history/, numbered after what is there",
    history[1] == "007-an-older-picture.png" and history[2] == "008-lua-window-01-at-000.60s-version-1.info.md"
    and history[3] == "008-lua-window-01-at-000.60s-version-1.png"
    and history[4] == "008-lua-window-01-at-000.60s-version-1.txt" and #list(SHOTS) == 0,
    table.concat(history, " ") .. "\n" .. (slurp(LIVE) or ""))
local note = slurp(ROOT .. "/development-history/008-lua-window-01-at-000.60s-version-1.info.md") or ""
check("with a note of what made it, the version and the time", has(note, "version 1 of the canvas, 0.60 s")
    and has(note, "made by: scripts/lua-window --screenshot 0.6") and has(note, "commit: "), note)
-- }}}

io.write("\n=== the command line ===\n")
-- {{{
local _, bad = shell(LUA .. " --nonsense")
check("an unknown argument is refused (2)", bad == 2)
local text, no_name = shell(LUA .. " --key 3")
check("--key without a name is refused (2)", no_name == 2 and has(text, "--key takes SECONDS NAME"))
with_setting("ink", '"white"')
local said, broken = shell(LUA .. " --fast --for 1")
write(ROOT .. "/input/lua-window", SETTINGS)
check("a bad setting stops it, naming the file (1)", broken == 1
    and has(said, "input/lua-window: ink: 'white'"), said)
check("it says it is drawing without a window", has(said, "no window backend is built yet"))
-- a real clock: the replay takes its time
local started = os.time()
local _, real = shell(LUA .. " --replay " .. q(REPLAY))
c = receipt()
check("on the real clock the replay takes its time (two seconds between three versions)",
    real == 0 and c["seconds-run"] == 2 and c["versions-drawn"] == 3 and os.time() - started >= 1)
-- }}}

if failed > 0 then io.write("kept ", BASE, "\n") else shell("rm -rf " .. q(BASE)) end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
