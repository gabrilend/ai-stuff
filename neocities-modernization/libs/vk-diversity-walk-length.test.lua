#!/usr/bin/env luajit

-- Tests that a diversity walk stopped early is the start of the full walk
-- (Issue 10-074). The "different" pages show the first K poems of each walk;
-- until 2026-10-22 the GPU walked every poem and the caller kept K, about 50
-- minutes a build thrown away. The walk is greedy, one step at a time, so
-- stopping at K must not change its first K steps; this checks that on made-
-- up vectors, on the GPU, and that the result holds the start plus K poems.
-- Needs the GPU (the build does too).
--
-- Run directly:  luajit libs/vk-diversity-walk-length.test.lua [--dir PATH]

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
-- the GPU library finds its shaders by paths relative to the project folder
local ffi = require("ffi")
ffi.cdef("int chdir(const char *path);")
ffi.C.chdir(DIR)
local vk = require("vk_compute")

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

-- {{{ fixtures: 300 made-up vectors, half precision, as the build hands them over
local num, dim = 300, 64
local x = 777
local function rnd()
    x = (x * 1103515245 + 12345) % 2147483648
    return x / 2147483648 - 0.5
end
local f32 = ffi.new("float[?]", num * dim)
for i = 0, num * dim - 1 do f32[i] = rnd() end
local f16 = ffi.new("uint16_t[?]", num * dim)
vk.fp32_to_fp16(f32, f16, num * dim)
-- }}}

local ctx = vk.init(false)
-- the card tuning the build uses (config.lua gpu.diversity)
local tuning = require("config-loader").load().gpu.diversity
local full = vk.compute_all_diversity_sequences_batched(ctx, f16, num, dim, nil, 128, nil, tuning)
local short = vk.compute_all_diversity_sequences_batched(ctx, f16, num, dim, nil, 128, 20, tuning)
vk.shutdown(ctx)

local same, right_length = 0, 0
for p = 0, num - 1 do
    local f, s = full[p], short[p]
    local ok = true
    for i = 1, 21 do
        if f[i] ~= s[i] then ok = false break end
    end
    if ok then same = same + 1 end
    if #s == 21 then right_length = right_length + 1 end
end
check("a full walk visits every poem", #full[0] == num, tostring(#full[0]))
check("every 20-step walk is the start of the full walk (300 walks)", same == num, same .. " of " .. num)
check("a 20-step walk holds its start and 20 poems", right_length == num, right_length .. " of " .. num)
check("each walk starts at its own poem", short[7][1] == 7, tostring(short[7][1]))

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
