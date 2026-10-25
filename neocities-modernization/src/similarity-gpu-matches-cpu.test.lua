#!/usr/bin/env luajit

-- Does the GPU's similarity table say what plain arithmetic says? (Issue 9-002b)
--
-- Stage 7 works out every poem-to-poem similarity on the graphics card and
-- writes one file per poem. Nothing checked those numbers against a plain
-- calculation, so a shader or file-writing fault would ship as a complete,
-- plausible, wrong set of similar pages. This test picks poems at random
-- (seeded, so a failure repeats), recomputes their similarity to every other
-- poem on the processor in double precision, from the same embeddings and
-- the same centring (libs/embedding-space.lua), and compares:
--   - every score agrees within 1e-4 (the card works in single precision
--     from the same vectors; the files keep 8 decimals);
--   - each file lists every other poem once, ordered most similar first;
--   - each file is filed under the right poem.
-- It reads the newest built table of every model on disk. A model whose
-- embeddings are newer than its table (a build stopped between Stage 6 and
-- 7), or whose table was made under another numbering of the poems (its
-- numbering stamp, libs/numbering-stamp.lua, differs or is missing -- an
-- old model's leftovers from before Issue 8-019), is skipped and said so:
-- the two no longer describe the same poems.
--
-- Run directly:  luajit src/similarity-gpu-matches-cpu.test.lua [project-dir]

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
local json = require("dkjson")
local utils = require("utils")
local embedding_space = require("embedding-space")
local stamp = require("numbering-stamp")

local SAMPLE = 12            -- poems checked per model, each against every other
local TOLERANCE = 1e-4

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

-- {{{ local function mtime()
local function mtime(path)
    local p = assert(io.popen(string.format("stat -c %%Y %q 2>/dev/null", path)))
    local t = tonumber(p:read("*l"))
    p:close()
    return t
end
-- }}}

-- {{{ local function read_json()
local function read_json(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = json.decode(f:read("*a"))
    f:close()
    return data
end
-- }}}

local listing = assert(io.popen("ls " .. DIR .. "/assets/embeddings"))
local models = {}
for name in listing:lines() do models[#models + 1] = name end
listing:close()

local checked = 0
for _, model in ipairs(models) do
    local edir = utils.embeddings_dir(model)
    local emb_path = edir .. "/embeddings.json"
    local sim_dir = edir .. "/similarities"
    local emb_time = mtime(emb_path)
    local sim_time = mtime(sim_dir .. "/poem_index_1.json")
    if not emb_time or not sim_time then
        -- no table built for this model: nothing to compare
    elseif emb_time > sim_time then
        print(string.format("  skip %s: its embeddings are newer than its similarity table (rebuild Stage 7)", model))
    else
      local emb_data = read_json(emb_path)
      local ok_numbering, numbering = pcall(stamp.of_embeddings, emb_data)
      local table_numbering = stamp.read(edir .. "/similarity_rankings_cache.json")
      if not ok_numbering or numbering ~= table_numbering then
        -- made under another numbering of the poems: its numbers name other
        -- poems now, so a comparison would test nothing
        print(string.format("  skip %s: its similarity table was made under another numbering of the poems (rebuild Stages 6-7)", model))
      else
        checked = checked + 1
        local entries = emb_data.embeddings
        local mean = assert(embedding_space.corpus_mean(entries))
        local dims = #mean
        -- each poem's centred vector and its length, by poem number
        local centred, length, numbers = {}, {}, {}
        for _, e in ipairs(entries) do
            local v, sq = {}, 0
            for d = 1, dims do v[d] = e.embedding[d] - mean[d]; sq = sq + v[d] * v[d] end
            centred[e.poem_index], length[e.poem_index] = v, math.sqrt(sq)
            numbers[#numbers + 1] = e.poem_index
        end
        math.randomseed(20261025)
        local worst, worst_at, all_listed, all_ordered, all_filed = 0, nil, true, true, true
        for _ = 1, SAMPLE do
            local anchor = numbers[math.random(#numbers)]
            local file = read_json(string.format("%s/poem_index_%d.json", sim_dir, anchor))
            if file.metadata.poem_index ~= anchor then all_filed = false end
            local seen, count, previous = {}, 0, math.huge
            for _, pair in ipairs(file.similarities) do
                local other = tonumber(pair.id)
                if seen[other] or other == anchor or not centred[other] then all_listed = false end
                seen[other] = true
                count = count + 1
                if pair.similarity > previous + 1e-9 then all_ordered = false end
                previous = pair.similarity
                local a, b, dot = centred[anchor], centred[other], 0
                if b then
                    for d = 1, dims do dot = dot + a[d] * b[d] end
                    local exact = dot / (length[anchor] * length[other])
                    local off = math.abs(exact - pair.similarity)
                    if off > worst then worst, worst_at = off, anchor .. "-" .. other end
                end
            end
            if count ~= #numbers - 1 then all_listed = false end
        end
        check(string.format("%s: %d poems x %d others agree within %g (worst %.2e at %s)",
            model, SAMPLE, #numbers - 1, TOLERANCE, worst, tostring(worst_at)), worst <= TOLERANCE)
        check(model .. ": each file lists every other poem once", all_listed)
        check(model .. ": each file is ordered most similar first", all_ordered)
        check(model .. ": each file is filed under its own poem", all_filed)
      end
    end
end

if checked == 0 then
    print("SKIP: no model has a similarity table built from its current embeddings")
    os.exit(0)
end
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
