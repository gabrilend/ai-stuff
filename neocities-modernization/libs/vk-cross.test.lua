#!/usr/bin/env luajit

-- Tests the GPU's word-against-poem score table (Issue 10-035,
-- libs/vulkan-compute/lua/vk_cross.lua) against the CPU's exact score
-- (embedding-space.cosine_centred). The GPU works in single precision, so
-- each score must agree to within single-precision rounding; the word pages
-- re-score their chosen poems exactly, so this closeness is all they need.
-- Needs the GPU (the build does too, for its similarity and diversity steps).
--
-- Run directly:  luajit libs/vk-cross.test.lua [--dir PATH]

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
    local libs_dir = this:match("(.*/)") or "./"
    local project_dir = PROJECT_DIR_ARG or libs_dir:gsub("libs/$", "")
    project_dir = project_dir:gsub("/$", "")
    package.path = project_dir .. "/libs/?.lua;" .. project_dir .. "/libs/vulkan-compute/lua/?.lua;" .. package.path
    return project_dir
end
-- }}}

local DIR = setup_path()
local es = require("embedding-space")
local vk_cross = require("vk_cross")

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

-- {{{ fixtures: fixed pseudo-random vectors (a small LCG, the same everywhere)
local x = 4242
local function rnd()
    x = (x * 1103515245 + 12345) % 2147483648
    return x / 2147483648 - 0.5
end
local function vec(n) local v = {} for j = 1, n do v[j] = rnd() end return v end
local dim = 96
local a_mean, b_mean = vec(dim), vec(dim)
local words, poems = {}, {}
for i = 1, 37 do words[i] = es.centre_once(vec(dim), a_mean) end    -- not a multiple of 16
for i = 1, 211 do poems[i] = es.centre_once(vec(dim), b_mean) end
-- a vector equal to its average: no direction left, scores 0
poems[#poems + 1] = es.centre_once(b_mean, b_mean)
-- }}}

-- {{{ every score against the CPU
do
    local a, b = {}, {}
    for i, w in ipairs(words) do a[i] = w.v end
    for i, p in ipairs(poems) do b[i] = p.v end
    local score = vk_cross.cosine_table(DIR, a, b)
    local worst = 0
    for i = 1, #words do
        for j = 1, #poems do
            local d = math.abs(score(i, j) - es.cosine_centred(words[i], poems[j]))
            if d > worst then worst = d end
        end
    end
    check("every GPU score is within single-precision rounding of the CPU's (37 x 212)",
        worst < 1e-5, string.format("largest difference %.3g", worst))
    check("a vector equal to its average scores 0 on the GPU", score(1, #poems) == 0)
    check("an empty set is an error", not pcall(vk_cross.cosine_table, DIR, {}, b))
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
