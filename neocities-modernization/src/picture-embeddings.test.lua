#!/usr/bin/env luajit

-- Tests for src/picture-embeddings.lua (Issue 9-013), the step that asks the
-- vision model for each picture's numbers. Real files, real fingerprints and
-- real shrinking (ImageMagick) on a few drawn pictures; the server is a
-- stand-in that counts its calls, so the cache rules can be checked: a known
-- picture is not sent again, an edited one is, the same picture in two
-- places is sent once, a picture no longer on the site leaves the cache, and
-- a new size remakes everything.
--
-- Run directly:  luajit src/picture-embeddings.test.lua [project-dir]

-- {{{ local function setup()
local function setup()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local dir = (arg[1] or src_dir:gsub("src/$", "")):gsub("/$", "")
    package.path = dir .. "/libs/?.lua;" .. dir .. "/src/?.lua;" .. package.path
    return dir
end
-- }}}

local DIR = setup()
_G.PICTURE_EMBEDDINGS_NO_MAIN = true
local pictures = dofile(DIR .. "/src/picture-embeddings.lua")

local SCRATCH = DIR .. "/tmp/shared-memory/picture-embeddings-test"
os.execute(string.format("rm -rf %q && mkdir -p %q", SCRATCH, SCRATCH))

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. tostring(detail)) or ""))
    end
end
-- }}}

-- {{{ local function draw()
local function draw(path, size, colour, alpha)
    local cmd = string.format("magick -size %s xc:%s %s %q", size, colour,
        alpha and "-alpha set -channel A -evaluate set 50%" or "", path)
    assert(os.execute(cmd) == 0 or os.execute(cmd) == true, "could not draw " .. path)
end
-- }}}

-- {{{ local function dimensions()
local function dimensions(path)
    local p = assert(io.popen(string.format("magick identify -format '%%w %%h' %q", path)))
    local w, h = p:read("*a"):match("(%d+) (%d+)")
    p:close()
    return tonumber(w), tonumber(h)
end
-- }}}

-- Pictures: one large, one small, one with a name full of awkward letters,
-- one with transparency, and a copy of the large one under another name.
local big = SCRATCH .. "/big photo.png"
local small = SCRATCH .. "/small.png"
local odd = SCRATCH .. "/it's a \"name\".png"
local clear = SCRATCH .. "/clear.png"
local twin = SCRATCH .. "/big copy.png"
draw(big, "3000x1000", "red")
draw(small, "200x100", "blue")
draw(odd, "300x300", "green")
draw(clear, "400x400", "yellow", true)
os.execute(string.format("cp %q %q", big, twin))

-- {{{ Case: which pictures are placed
do
    local poems_data = { poems = {
        { attachments = { { media_type = "image/png", relative_path = "files/a.png" },
                          { media_type = "video/mp4", relative_path = "files/b.mp4" } } },
        { attachments = { { media_type = "image/jpeg", relative_path = "files/a.png" } } },
        { attachments = { { media_type = "audio/mpeg", relative_path = "files/c.mp3" } } },
        { content = "no attachments" },
    } }
    local catalog_data = { images = {
        { source_name = "my-art", file_path = "/art/one.png" },
        { source_name = "fediverse-media", file_path = "/media/a.png" },
    } }
    local list = pictures.pictures_to_place("/project", poems_data, catalog_data)
    check("a post's pictures and the gallery pictures are placed, each once",
        #list == 2 and list[1] == "/art/one.png" and list[2] == "/project/input/media_attachments/files/a.png",
        table.concat(list, ", "))
end
-- }}}

-- {{{ Case: fingerprints match md5sum, whatever the file is called
do
    local hashes = pictures.fingerprints({ big, small, odd, clear, twin }, SCRATCH)
    local p = assert(io.popen(string.format("md5sum %q", small)))
    local expected = p:read("*a"):match("^(%x+)")
    p:close()
    check("a fingerprint is the file's md5", hashes[small] == expected, hashes[small])
    check("a name with quotes and spaces is fingerprinted", hashes[odd] ~= nil)
    check("a copy has its original's fingerprint", hashes[big] == hashes[twin])
    local ok, err = pcall(pictures.fingerprints, { SCRATCH .. "/missing.png" }, SCRATCH)
    check("a missing picture is an error naming it", not ok and tostring(err):find("missing.png", 1, true), err)
end
-- }}}

-- {{{ Case: many pictures at once, every answer comes back, every time
-- The fingerprints are worked out by many md5sum copies at once. When they
-- all wrote into one shared pipe, each copy's 4 KB buffer could break off
-- mid-answer and another copy's buffer land in the gap, so a handful of
-- answers per run came back unreadable -- a different handful each time
-- (2026-11-02: 8 to 11 of 701 pictures, five runs, five different counts).
-- Long names make each batch of answers bigger than one buffer, which is
-- what made the old way break; five rounds make a lucky pass unlikely.
do
    local many_dir = SCRATCH .. "/many"
    os.execute(string.format("mkdir -p %q", many_dir))
    local many = {}
    for i = 1, 600 do
        local path = string.format("%s/a-long-picture-name-so-each-batch-of-answers-outgrows-one-buffer-%04d.png",
            many_dir, i)
        local f = assert(io.open(path, "wb"))
        f:write("picture ", i)
        f:close()
        many[i] = path
    end
    local all_rounds_whole = true
    local detail = nil
    for round = 1, 5 do
        local ok, hashes = pcall(pictures.fingerprints, many, SCRATCH)
        if not ok then
            all_rounds_whole = false
            detail = "round " .. round .. ": " .. tostring(hashes)
            break
        end
        local p = assert(io.popen(string.format("md5sum %q", many[600])))
        local expected = p:read("*a"):match("^(%x+)")
        p:close()
        if hashes[many[600]] ~= expected then
            all_rounds_whole = false
            detail = "round " .. round .. ": the last picture's fingerprint is " .. tostring(hashes[many[600]])
            break
        end
    end
    check("600 pictures fingerprinted five times over: none lost, none garbled", all_rounds_whole, detail)
end
-- }}}

-- {{{ Case: shrinking
do
    local jobs = {
        { source = big, target = SCRATCH .. "/out-big.jpg" },
        { source = small, target = SCRATCH .. "/out-small.jpg" },
        { source = clear, target = SCRATCH .. "/out-clear.jpg" },
    }
    pictures.shrink_all(jobs, 1800, SCRATCH)
    local w, h = dimensions(jobs[1].target)
    check("a large picture is shrunk to the long side", w == 1800 and h == 600, w .. "x" .. h)
    w, h = dimensions(jobs[2].target)
    check("a small picture keeps its size", w == 200 and h == 100, w .. "x" .. h)
    local p = assert(io.popen(string.format("magick %q -format '%%[pixel:p{10,10}]' info:", jobs[3].target)))
    local colour = p:read("*a")
    p:close()
    -- half-clear yellow over white: red and green stay full, blue comes up
    -- half way (JPEG may round a step either side)
    local r, g, b = colour:match("srgb%((%d+),(%d+),(%d+)%)")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    check("transparency is flattened onto white (half-clear yellow turns pale)",
        r and r >= 250 and g >= 250 and b >= 110 and b <= 145, colour)
    local ok, err = pcall(pictures.shrink_all, { { source = SCRATCH .. "/no-such.png", target = SCRATCH .. "/x.jpg" } }, 1800, SCRATCH)
    check("a picture that cannot be shrunk is an error naming it", not ok and tostring(err):find("no-such.png", 1, true), err)
end
-- }}}

-- {{{ Case: the cache rules
do
    local calls = 0
    local function embed(path)
        calls = calls + 1
        local f = assert(io.open(path, "rb")); f:close()   -- the shrunk copy exists when sent
        return { calls, 0, 0 }
    end
    local function shrink(jobs) pictures.shrink_all(jobs, 1800, SCRATCH) end
    local function quiet() end
    local paths = { big, small, twin }
    local hashes = pictures.fingerprints(paths, SCRATCH)
    local cache = { metadata = {}, pictures = {} }

    local first, report = pictures.update(cache, paths, hashes, 1800, shrink, embed, SCRATCH, quiet)
    check("first run: each different picture is sent once (the copy shares)", calls == 2 and report.made == 2, calls)
    check("the shrunk copies are removed once sent",
        io.open(SCRATCH .. "/" .. hashes[big] .. ".jpg") == nil)

    calls = 0
    local second, report2 = pictures.update(first, paths, hashes, 1800, shrink, embed, SCRATCH, quiet)
    check("second run: nothing is sent again", calls == 0 and report2.reused == 2, calls)
    check("and the vectors are the ones made before",
        second.pictures[pictures.cache_key(hashes[big], 1800)].embedding[1]
            == first.pictures[pictures.cache_key(hashes[big], 1800)].embedding[1])

    draw(small, "220x100", "blue")   -- the picture is edited
    hashes = pictures.fingerprints(paths, SCRATCH)
    calls = 0
    local third = pictures.update(second, paths, hashes, 1800, shrink, embed, SCRATCH, quiet)
    check("an edited picture is sent again, and only it", calls == 1, calls)

    calls = 0
    local fourth, report4 = pictures.update(third, { big }, hashes, 1800, shrink, embed, SCRATCH, quiet)
    check("a picture no longer on the site leaves the cache", report4.total == 1 and calls == 0, report4.total)

    calls = 0
    pictures.update(fourth, { big }, hashes, 900, shrink, embed, SCRATCH, quiet)
    check("a new size remakes the picture", calls == 1, calls)
end
-- }}}

-- {{{ Case: a server that does not answer
do
    local embed = pictures.server_embedder("http://127.0.0.1:1", SCRATCH, 5)
    pictures.shrink_all({ { source = small, target = SCRATCH .. "/send.jpg" } }, 1800, SCRATCH)
    local ok, err = pcall(embed, SCRATCH .. "/send.jpg")
    check("no vector from the server is an error that names the vision projector",
        not ok and tostring(err):find("--mmproj", 1, true), err)
end
-- }}}

os.execute(string.format("rm -rf %q", SCRATCH))
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
