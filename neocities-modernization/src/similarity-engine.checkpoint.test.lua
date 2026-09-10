#!/usr/bin/env luajit

-- Guards the rule that decides when the embedding run stops to rewrite its cache.
--
-- Why this exists. A checkpoint re-encodes every vector gathered so far, so its
-- cost climbs all run: measured on this corpus, one checkpoint at 7,300 poems is
-- about seven seconds. The old rule fired every ~96 poems regardless, which meant
-- the toll rose without limit -- on a measured 8,531-poem run the inference
-- server sat idle 249 seconds out of 460, so more than half the run was spent
-- saving rather than embedding. The rule now paces itself off what the last save
-- actually cost, and these tests pin that behaviour.
--
-- Run directly:  luajit src/similarity-engine.checkpoint.test.lua

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = src_dir:gsub("src/$", "")
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. package.path
end
-- }}}

setup_path()
local engine = require("similarity-engine")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("FAIL   " .. name)
        if detail then print("         " .. detail) end
    end
end
-- }}}

local due = engine.checkpoint_is_due
local cooldown = engine.checkpoint_cooldown_until

print("checkpoint pacing")

-- {{{ both gates must open
-- windows_since_save, min_windows, now, next_allowed_at, is_last_window
check("enough work and cooled down -> save",
    due(6, 6, 1000, 900, false) == true)

check("enough work but still cooling -> wait",
    due(6, 6, 1000, 1500, false) == false)

check("cooled down but not enough work -> wait",
    due(2, 6, 1000, 900, false) == false)

check("neither -> wait",
    due(2, 6, 1000, 1500, false) == false)

check("the cooldown boundary second counts as expired",
    due(6, 6, 1000, 1000, false) == true)
-- }}}

-- {{{ the last window is exempt from everything
-- The run is over; the file on disk has to be the complete one whatever it costs.
check("last window saves even mid-cooldown",
    due(1, 6, 1000, 99999, true) == true)

check("last window saves even with no work since the last save",
    due(0, 6, 1000, 99999, true) == true)
-- }}}

-- {{{ the cooldown a save earns
check("a 7 s save at duty 9 earns 63 s",
    cooldown(1000, 7, 9) == 1063)

check("a save too fast to measure earns nothing",
    cooldown(1000, 0, 9) == 1000)

check("cost scales the wait, not a fixed interval",
    cooldown(0, 20, 9) == 180)
-- }}}

-- {{{ the whole run, simulated against the measured numbers
-- Walk 8,531 poems in windows of 16. Embedding a window took about 0.46 s on the
-- measured run (211 s of server work across 460 s). A checkpoint's cost grows
-- with the poems already done: 6.8 s measured at 7,296 poems, so ~0.00093 s per
-- poem. Then count what each rule spends on saving.
local WINDOW, TOTAL = 16, 8531
local EMBED_SECONDS_PER_WINDOW = 0.46
local SAVE_SECONDS_PER_POEM = 6.8 / 7296

local function simulate(pace)
    local clock, saving, saves = 0, 0, 0
    local windows_since_save, next_allowed_at = 0, 0
    local done = 0
    for i = 1, TOTAL, WINDOW do
        local batch_end = math.min(i + WINDOW - 1, TOTAL)
        done = batch_end
        clock = clock + EMBED_SECONDS_PER_WINDOW
        windows_since_save = windows_since_save + 1
        local last = (batch_end == TOTAL)

        local fire
        if pace == "every-96" then
            fire = (windows_since_save >= 6) or last
        else
            fire = due(windows_since_save, 6, clock, next_allowed_at, last)
        end

        if fire then
            windows_since_save = 0
            local cost = done * SAVE_SECONDS_PER_POEM
            clock = clock + cost
            saving = saving + cost
            saves = saves + 1
            next_allowed_at = cooldown(clock, cost, 9)
        end
    end
    return { total = clock, saving = saving, saves = saves }
end

local old = simulate("every-96")
local new = simulate("self-paced")

print(string.format("\n   every 96 poems : %d saves, %.0f s saving of %.0f s total (%.0f%%)",
    old.saves, old.saving, old.total, old.saving / old.total * 100))
print(string.format("   self-paced     : %d saves, %.0f s saving of %.0f s total (%.0f%%)\n",
    new.saves, new.saving, new.total, new.saving / new.total * 100))

check("the old rule spent over half the run saving",
    old.saving / old.total > 0.5,
    string.format("%.0f%%", old.saving / old.total * 100))

check("the new rule holds saving near a tenth of the run",
    new.saving / new.total < 0.15,
    string.format("%.0f%%", new.saving / new.total * 100))

check("the run finishes in less than half the time",
    new.total < old.total * 0.5,
    string.format("%.0f s vs %.0f s", new.total, old.total))

check("it still checkpoints often enough to be worth having",
    new.saves >= 5,
    tostring(new.saves) .. " checkpoints")

check("and the last one is unconditional, so the cache ends complete",
    due(0, 6, 0, math.huge, true) == true)
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
