#!/usr/bin/env luajit

-- Tests that a stored embedding is reused only for the poem and the text it
-- was made from, never by number (Issue 8-019). On 2026-10-07 the notes were
-- renumbered under their vectors and about 555 of 582 kept a vector made from
-- another note. Also tests the numbering stamps the caches carry
-- (libs/numbering-stamp.lua): a cache made under another numbering of the
-- poems is refused.
--
-- Run directly:  luajit src/similarity-engine.reuse.test.lua [--dir PATH]

-- {{{ local function setup_path()
-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = PROJECT_DIR_ARG and (PROJECT_DIR_ARG .. "/") or src_dir:gsub("src/$", "")
    project_dir = project_dir:gsub("/$", "")
    package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

local DIR = setup_path()
arg = { DIR }
local engine = require("similarity-engine")
local extractor = require("poem-extractor")
local fp = require("text-fingerprint")
local stamp = require("numbering-stamp")

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

local DIMS = 4
-- {{{ local function stored()
-- What the embedding stage stores for a poem: its key, the code of its text,
-- a vector
local function stored(poem, vector)
    local text = extractor.extract_pure_poem_content_for_embedding(poem.content)
    return { source_key = poem.source_key, text_fingerprint = fp.of(text), embedding = vector or { 1, 2, 3, 4 } }
end
-- }}}

-- {{{ reuse by key and text
do
    local poem = { source_key = "notes-3", content = "rivers carry the old stones down" }
    local prior = stored(poem)
    check("its own vector from the same text is reused", engine.reusable_vector(poem, prior, DIMS) == true)

    local edited = { source_key = "notes-3", content = "rivers carry the old stones away" }
    local ok, why = engine.reusable_vector(edited, prior, DIMS)
    check("an edited poem is made again", not ok and why == "text_changed", why)

    ok, why = engine.reusable_vector(poem, nil, DIMS)
    check("a poem with nothing stored is new", not ok and why == "new", why)

    ok, why = engine.reusable_vector(poem, stored(poem, { 1, 2 }), DIMS)
    check("a vector of the wrong length is made again", not ok and why == "invalid_dimensions", why)

    ok, why = engine.reusable_vector({ source_key = "fediverse-9", content = "   ",
        is_image_only = true, nearest_text_poem_index = 4 }, prior, DIMS)
    check("an image-only post is made fresh every run", not ok and why == "made_fresh", why)
end
-- }}}

-- {{{ the 2026-10-07 case: two notes swap numbers, each keeps its own vector
do
    local a = { source_key = "notes-1", content = "division by zero", poem_index = 8607 }
    local b = { source_key = "notes-2", content = "symbeline superheros", poem_index = 8608 }
    local by_key = { ["notes-1"] = stored(a, { 1, 0, 0, 0 }), ["notes-2"] = stored(b, { 0, 1, 0, 0 }) }
    -- the next run numbers them the other way round
    a.poem_index, b.poem_index = 8608, 8607
    local ok_a = engine.reusable_vector(a, by_key[a.source_key], DIMS)
    local ok_b = engine.reusable_vector(b, by_key[b.source_key], DIMS)
    check("renumbered notes each keep their own vector",
        ok_a and ok_b and by_key[a.source_key].embedding[1] == 1 and by_key[b.source_key].embedding[2] == 1)
    -- and a vector offered under the wrong key is refused by its text
    local ok_wrong = engine.reusable_vector(a, by_key["notes-2"], DIMS)
    check("another note's vector is refused", not ok_wrong)
end
-- }}}

-- {{{ a blended vector is never reused as the text vector (Issue 9-013)
do
    local text_vector, blended = { 1, 0, 0, 0 }, { 0.7, 0.7, 0, 0 }
    local prior = { source_key = "fediverse-7", poem_index = 12, embedding = blended, text_embedding = text_vector }
    local carried = engine.reused_entry(prior, 30)
    check("a blended post carries its text vector into the new run", carried.embedding == text_vector)
    check("and not the blend beside it", carried.text_embedding == nil)
    check("filed under this run's number", carried.poem_index == 30)
    check("the stored entry is left as it was", prior.embedding == blended and prior.poem_index == 12)
    local plain = engine.reused_entry({ source_key = "notes-1", embedding = text_vector }, 4)
    check("a text-only poem carries its own vector", plain.embedding == text_vector)
end
-- }}}

-- {{{ numbering stamps
do
    local dir = "/tmp/neocities-modernization/tmp/numbering-stamp-test"
    os.execute('mkdir -p "' .. dir .. '"')
    local cache = dir .. "/poem_colors.json"
    os.remove(cache .. stamp.SUFFIX)
    check("a cache with no stamp is refused", not pcall(stamp.check, cache, "aaaa", "poem colours", "stage 6"))
    stamp.write(cache, "aaaa")
    check("a stamp reads back", stamp.read(cache) == "aaaa")
    check("a cache in this numbering passes", pcall(stamp.check, cache, "aaaa", "poem colours", "stage 6"))
    local ok, err = pcall(stamp.check, cache, "bbbb", "poem colours", "stage 6")
    check("a cache in another numbering is refused", not ok)
    check("the refusal says what to rerun", tostring(err):find("stage 6", 1, true) ~= nil, tostring(err))
    check("poems.json without a numbering is an error", not pcall(stamp.of_poems, { metadata = {} }))
    check("poems.json's numbering is read",
        stamp.of_poems({ metadata = { numbering = { fingerprint = "cccc" } } }) == "cccc")
    check("embeddings without a numbering are an error", not pcall(stamp.of_embeddings, { metadata = {} }))
    os.execute('rm -rf "' .. dir .. '"')
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
