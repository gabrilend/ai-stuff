-- Tests that a word page comes out the same on every run (found 2026-10-21:
-- the same code drew 13 of 60 word pages differently on two runs). The word
-- pages walked their tables in hash order, which changes from run to run; two
-- copies of one post tie on similarity, and the sorts kept whichever came
-- first. These check the order rules the page builder now uses, by feeding
-- each one the same items in many different orders.
-- Run: luajit src/generate-word-pages.order.test.lua [project-dir]

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = arg[1] or src_dir:gsub("src/$", "")
    package.path = project_dir .. "/src/?.lua;" .. project_dir .. "/libs/?.lua;" .. package.path
    return project_dir
end
-- }}}

local project_dir = setup_path()
-- the page builder reads its settings from the command line when it loads;
-- these tests use none of them, but the model must be named (no default)
-- config.lua testing names the model and server the checks use
local testing = require("config-loader").load().testing
arg = { project_dir, "--html-only", "--model", testing.model, "--server", testing.server }
local W = require("generate-word-pages")

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

-- {{{ local function shuffled()
-- A copy of list in a pseudo-random order fixed by seed (a small LCG, so the
-- test is the same on every machine).
local function shuffled(list, seed)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    local x = seed
    for i = #out, 2, -1 do
        x = (x * 1103515245 + 12345) % 2147483648
        local j = (x % i) + 1
        out[i], out[j] = out[j], out[i]
    end
    return out
end
-- }}}

-- {{{ local function indices()
local function indices(list)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.poem.poem_index end
    return table.concat(out, ",")
end
-- }}}

-- {{{ ordered keys
do
    local t = { ["10"] = 1, ["9"] = 1, ["100"] = 1, apple = 1, [3] = 1, banana = 1 }
    check("keys come numbers first, by value, then words", table.concat(W.ordered_keys(t), ",") == "3,9,10,100,apple,banana",
        table.concat(W.ordered_keys(t), ","))
end
-- }}}

-- {{{ ranking with ties
do
    -- poems 40 and 12 are copies of one post (equal similarity), as are 7 and 99
    local items = {
        { poem = { poem_index = 40 }, word_similarity = 0.9 },
        { poem = { poem_index = 12 }, word_similarity = 0.9 },
        { poem = { poem_index = 5 }, word_similarity = 0.8 },
        { poem = { poem_index = 99 }, word_similarity = 0.7 },
        { poem = { poem_index = 7 }, word_similarity = 0.7 },
        { poem = { poem_index = 1 }, word_similarity = 0.95 },
    }
    local first, all_same = nil, true
    for seed = 1, 50 do
        local list = shuffled(items, seed)
        table.sort(list, W.more_similar_first)
        local got = indices(list)
        first = first or got
        if got ~= first then all_same = false end
    end
    check("the ranking is the same from 50 starting orders", all_same)
    check("higher similarity first; a tie goes to the lower poem number", first == "1,12,40,5,7,99", first)
end
-- }}}

-- {{{ colour spreading with ties
do
    local items, colors = {}, {}
    local palette = { "red", "blue", "gray" }
    for i = 1, 12 do
        -- pairs of equal similarity, three colours
        items[i] = { poem = { poem_index = 100 + i }, word_similarity = 1 - math.floor((i - 1) / 2) * 0.1 }
        colors[100 + i] = { color = palette[(i % 3) + 1] }
    end
    local first, all_same = nil, true
    for seed = 1, 50 do
        local list = shuffled(items, seed)
        table.sort(list, W.more_similar_first)
        local got = indices(W.spread_colors_across_page(list, colors))
        first = first or got
        if got ~= first then all_same = false end
    end
    check("the colour-spread order is the same from 50 starting orders", all_same)
end
-- }}}

-- {{{ the GPU shortlist keeps every poem of the exact top list (Issue 10-035)
do
    -- exact scores with ties, and "GPU" scores off by up to a millionth
    local exact, gpu = {}, {}
    local x = 99
    for r = 1, 500 do
        x = (x * 1103515245 + 12345) % 2147483648
        exact[r] = math.floor((x / 2147483648) * 200) / 200     -- many exact ties
        x = (x * 1103515245 + 12345) % 2147483648
        gpu[r] = exact[r] + ((x / 2147483648) - 0.5) * 2e-6
    end
    local keep = 50
    local rows = W.shortlist(function(r) return gpu[r] end, #exact, keep)
    local in_list = {}
    for _, r in ipairs(rows) do in_list[r] = true end
    -- the exact top 50, ties by number
    local order = {}
    for r = 1, #exact do order[r] = r end
    table.sort(order, function(p, q)
        if exact[p] ~= exact[q] then return exact[p] > exact[q] end
        return p < q
    end)
    local missing = 0
    for k = 1, keep do if not in_list[order[k]] then missing = missing + 1 end end
    check("the shortlist holds all of the exact top 50", missing == 0, missing .. " missing")
    check("the shortlist is short (not every poem)", #rows < #exact, #rows .. " of " .. #exact)
    check("asking for more than there are keeps them all", #W.shortlist(function(r) return gpu[r] end, 10, 50) == 10)
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
