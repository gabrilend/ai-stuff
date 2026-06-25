#!/usr/bin/env luajit
-- {{{ memory-budgeter.test.lua
-- Issue 10-057: unit tests for the memory budgeter.
--
-- The pure compute_fit() cases use headroom 0.5 (binary-exact) so floating point
-- cannot nudge an expected worker count off by one at a boundary. (In real use the
-- default 0.7 headroom means an exact boundary rounds DOWN -- conservative, i.e. one
-- fewer worker -- which is the safe direction for a memory budget, so it is fine.)
-- A light smoke test exercises the live RAM probe and file sizing.
--
-- Run: luajit libs/memory-budgeter.test.lua [DIR]
-- }}}

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local budget = require("memory-budgeter")

local GB = 1e9
local passed, failed = 0, 0
-- {{{ check()
local function check(name, cond)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. name)
    end
end
-- }}}

-- 1. Plenty of room: the requested count survives unchanged.
do
    local f = budget.compute_fit(60*GB, 2*GB, 0.05*GB, 8, 0.5)  -- budget 30GB
    check("comfortable: keeps want", f.threads == 8)
    check("comfortable: not reduced", f.reduced == false)
    check("comfortable: not swapping", f.swapping == false)
end

-- 2. Per-worker cost forces a reduction below the requested count.
do
    local f = budget.compute_fit(20*GB, 2*GB, 1*GB, 12, 0.5)  -- budget 10GB; (10-2)/1 = 8
    check("reduction: clamps to safe count", f.threads == 8)
    check("reduction: flagged reduced", f.reduced == true)
    check("reduction: not swapping", f.swapping == false)
end

-- 3. The shared (fixed) data alone overflows the budget: warn, 1 worker, no abort.
do
    local f = budget.compute_fit(20*GB, 12*GB, 0.5*GB, 8, 0.5)  -- budget 10GB; fixed 12 > 10
    check("swapping: returns 1 worker", f.threads == 1)
    check("swapping: flagged", f.swapping == true)
end

-- 4. Zero per-worker cost: workers are free, so keep the count; swapping only on fixed.
do
    local f = budget.compute_fit(20*GB, 2*GB, 0, 16, 0.5)  -- fixed fits
    check("zero per-worker: keeps want", f.threads == 16)
    check("zero per-worker: not swapping when fixed fits", f.swapping == false)
    local g = budget.compute_fit(20*GB, 12*GB, 0, 16, 0.5)  -- fixed overflows
    check("zero per-worker: swaps when fixed overflows", g.swapping == true)
    check("zero per-worker: count unchanged even when swapping", g.threads == 16)
end

-- 5. Exactly one worker fits (clear, non-fractional boundary).
do
    local f = budget.compute_fit(20*GB, 9*GB, 1*GB, 8, 0.5)  -- budget 10GB; (10-9)/1 = 1
    check("boundary: exactly one fits", f.threads == 1)
    check("boundary: not swapping", f.swapping == false)
end

-- 6. A nonsensical request is floored to at least one worker.
do
    local f = budget.compute_fit(60*GB, 1*GB, 0.1*GB, 0, 0.5)
    check("want floored to >= 1", f.threads == 1)
end

-- 7. Live RAM probe: fit_threads returns a sane count and never exceeds the request.
do
    local threads = budget.fit_threads({
        pool = "ram", fixed = 1*GB, per_thread = 0.05*GB, want = 4, label = "selftest",
    })
    check("live: returns >= 1", threads >= 1)
    check("live: never exceeds want", threads <= 4)
end

-- 8. file_size_bytes: positive on a real file, nil on a missing one.
do
    local self_size = budget.file_size_bytes(DIR .. "/libs/memory-budgeter.test.lua")
    check("file size: positive on real file", self_size ~= nil and self_size > 0)
    check("file size: nil on missing file", budget.file_size_bytes(DIR .. "/does-not-exist-xyz") == nil)
end

print(string.format("memory-budgeter: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
