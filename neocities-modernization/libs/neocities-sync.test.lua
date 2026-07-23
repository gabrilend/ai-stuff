#!/usr/bin/env luajit
-- neocities-sync.test.lua -- offline tests for the adaptive deploy brain.
-- Run: luajit libs/neocities-sync.test.lua
-- No network: a mock op() simulates the server's status codes so we can prove the
-- control loop reacts correctly (halve on too-big, wait on 429, grow on success,
-- stop on fatal) and that the diff/batching are right.

package.path = arg[0]:gsub("[^/]+%.lua$", "") .. "?.lua;" .. package.path
local S = require("neocities-sync")

local pass, fail = 0, 0
local function check(label, cond)
    if cond then pass = pass + 1; print("  ok   - " .. label)
    else fail = fail + 1; print("  FAIL - " .. label) end
end

-- {{{ diff_delete: stale = remote files not built locally; dirs skipped
do
    local remote = {
        { path = "sd/a.html", is_directory = false },
        { path = "sd/old.html", is_directory = false },   -- stale
        { path = "sd/sub", is_directory = true },          -- dir, never deleted
    }
    local localset = { ["sd/a.html"] = true }
    local stale = S.diff_delete(remote, localset)
    check("diff_delete finds only the stale file", #stale == 1 and stale[1] == "sd/old.html")
end
-- }}}

-- {{{ diff_upload: only hash-mismatched/missing, largest first
do
    local items = {
        { remote = "a", bytes = 10, sha1 = "x" },   -- matches remote -> skip
        { remote = "b", bytes = 50, sha1 = "new" }, -- differs -> upload
        { remote = "c", bytes = 99, sha1 = "z" },   -- missing remote -> upload
    }
    local remote_by_path = { a = "x", b = "old" }
    local need = S.diff_upload(items, remote_by_path)
    check("diff_upload selects only changed/missing", #need == 2)
    check("diff_upload orders largest-first", need[1].remote == "c" and need[2].remote == "b")
end
-- }}}

-- {{{ take_batch: respects cost budget and count cap, always >=1
do
    local items = {}
    for i = 1, 10 do items[i] = { cost = 1 } end
    local b1 = S.take_batch(items, 1, 4, 100)       -- budget 4 -> 4 items
    check("take_batch honors budget", #b1 == 4)
    local b2 = S.take_batch(items, 1, 100, 3)       -- count cap 3
    check("take_batch honors max_count", #b2 == 3)
    local big = { { cost = 999 } }
    local b3 = S.take_batch(big, 1, 10, 100)        -- single oversized item still taken
    check("take_batch always takes >=1", #b3 == 1)
end
-- }}}

-- {{{ classify: status -> reaction
do
    check("200+body = ok",        S._classify(200, true)  == "ok")
    check("429 = throttle",       S._classify(429, false) == "throttle")
    check("413 = too_big",        S._classify(413, false) == "too_big")
    check("503 = too_big",        S._classify(503, false) == "too_big")
    check("200+HTML body = too_big", S._classify(200, false) == "too_big")
    check("403 = fatal",          S._classify(403, false) == "fatal")
end
-- }}}

-- {{{ run_adaptive: halves the batch until the server accepts it, then finishes
do
    local items = {}
    for i = 1, 10 do items[i] = { cost = 1, id = i } end
    -- server rejects any batch larger than 2 files (a "too big" 413)
    local op = function(batch)
        if #batch > 2 then return { status = 413 } end
        return { status = 200, ok_body = true }
    end
    local stats = S.run_adaptive(items, op, {
        budget = 8, max_count = 100, floor = 1, grow_after = 1e9,  -- no growth this test
        sleep = function() end,
    })
    check("adaptive completes every item", stats and stats.done == 10)
    check("adaptive shrank at least twice (8->4->2)", stats and stats.shrinks >= 2)
end
-- }}}

-- {{{ run_adaptive: 429 -> waits and retries, does NOT shrink
do
    local items = { { cost = 1 }, { cost = 1 } }
    local calls, slept = 0, 0
    local op = function(batch)
        calls = calls + 1
        if calls == 1 then return { status = 429, retry_after = 3 } end
        return { status = 200, ok_body = true }
    end
    local stats = S.run_adaptive(items, op, {
        budget = 8, grow_after = 1e9,
        sleep = function(s) slept = slept + s end,
    })
    check("throttle then success completes", stats and stats.done == 2)
    check("throttle slept for Retry-After", slept >= 3)
    check("throttle did NOT shrink the budget", stats and stats.shrinks == 0)
end
-- }}}

-- {{{ run_adaptive: steady success grows the budget
do
    local items = {}
    for i = 1, 30 do items[i] = { cost = 1 } end
    local op = function() return { status = 200, ok_body = true } end
    local stats = S.run_adaptive(items, op, {
        budget = 2, max_count = 100, grow = 2, grow_after = 2, sleep = function() end,
    })
    check("steady run completes", stats and stats.done == 30)
    check("steady run grew the budget", stats and stats.grows >= 1 and stats.final_budget > 2)
end
-- }}}

-- {{{ run_adaptive: on_batch_ok fires with batches that cover every item
do
    local items = {}
    for i = 1, 10 do items[i] = { cost = 1 } end
    local seen = 0
    local stats = S.run_adaptive(items, function() return { status = 200, ok_body = true } end, {
        budget = 3, max_count = 100, grow_after = 1e9, sleep = function() end,
        on_batch_ok = function(batch) seen = seen + #batch end,
    })
    check("on_batch_ok covered all items exactly once", stats and seen == 10)
end
-- }}}

-- {{{ run_adaptive: fatal status stops with an error
do
    local items = { { cost = 1 } }
    local op = function() return { status = 403 } end
    local stats, err = S.run_adaptive(items, op, { sleep = function() end })
    check("fatal returns nil + error", stats == nil and type(err) == "string")
end
-- }}}

-- {{{ run_adaptive: persistent failure at floor surfaces an error (no infinite shrink)
do
    local items = { { cost = 1, remote = "stubborn" } }
    local op = function() return { status = 500 } end   -- always fails, even at 1 file
    local stats, err = S.run_adaptive(items, op, { budget = 1, floor = 1, sleep = function() end })
    check("floor failure surfaces (no wedge)", stats == nil and err:match("minimum batch") ~= nil)
end
-- }}}

print("")
print(string.format("Result: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
