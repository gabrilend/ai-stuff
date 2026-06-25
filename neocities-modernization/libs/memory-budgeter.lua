-- {{{ memory-budgeter.lua
-- Issue 10-057: estimate-and-fit memory budgeter for threaded / GPU stages.
--
-- WHAT IT DOES (for a CEO): before a stage spins up N parallel workers, it asks
-- "will this actually fit in the machine's free memory, or will it spill into swap
-- and crawl?" This library answers that with simple arithmetic, and tells the stage
-- how many workers it can safely run. If even the shared data alone won't fit, it
-- does NOT stop the build -- it warns loudly that the run will use swap (a sign the
-- data should be shrunk, or the slowdown accepted) and proceeds at one worker.
--
-- HOW: every stage's memory has the same shape -- a FIXED part loaded once (caches,
-- a model) plus a PER-WORKER part that scales with the worker count. Given those two
-- numbers and how much memory is free, the safe worker count is just
--   floor((free * headroom - fixed) / per_worker).
-- The library knows nothing about WHAT the bytes are; each stage hands it the two
-- numbers and which pool (system RAM or GPU VRAM) to measure. RAM and VRAM differ
-- only in how "free" is measured -- the math is identical -- which is what makes one
-- budgeter reusable across every stage in the pipeline.
--
-- Two layers, kept separate so the arithmetic is testable without real memory:
--   * compute_fit() -- pure: numbers in, decision out. No I/O.
--   * fit_threads() -- wraps compute_fit() with a live memory probe and logging.
--
-- Usage:
--   local budget = require("memory-budgeter")
--   local threads = budget.fit_threads({
--       pool = "ram", fixed = cache_bytes, per_thread = page_buf_bytes,
--       want = requested_threads, label = "HTML",
--   })
-- }}}

local utils = require("utils")

local M = {}

-- {{{ format_bytes()
-- Human-readable size for log lines (decimal GB/MB/KB -- close enough for a log).
local function format_bytes(n)
    if n >= 1e9 then return string.format("%.1f GB", n / 1e9) end
    if n >= 1e6 then return string.format("%.0f MB", n / 1e6) end
    if n >= 1e3 then return string.format("%.0f KB", n / 1e3) end
    return string.format("%d B", n)
end
-- }}}

-- {{{ probe_ram_bytes()
-- Free system RAM, from /proc/meminfo's MemAvailable -- the kernel's own estimate of
-- how much can be allocated without swapping (it counts reclaimable page cache, so
-- it is more honest than MemFree). Pure file read, no exec. Errors rather than guess
-- if the field is somehow absent (a missing number is a real problem, not a default).
local function probe_ram_bytes()
    local f = io.open("/proc/meminfo", "r")
    if not f then
        error("memory-budgeter: cannot open /proc/meminfo to size free RAM")
    end
    local available_kb
    for line in f:lines() do
        local kb = line:match("^MemAvailable:%s+(%d+) kB")
        if kb then available_kb = tonumber(kb); break end
    end
    f:close()
    if not available_kb then
        error("memory-budgeter: /proc/meminfo has no MemAvailable field")
    end
    return available_kb * 1024
end
-- }}}

-- {{{ probe_vram_bytes()
-- Free GPU VRAM. Best-effort via nvidia-smi (read-only query). Non-NVIDIA GPUs have
-- no portable CLI, so this errors with a clear instruction rather than guessing -- a
-- caller on a different GPU passes its own `probe` function in the spec. The math
-- downstream is identical to RAM; only this measurement differs.
local function probe_vram_bytes()
    local pipe = io.popen("nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits")
    if pipe then
        local out = pipe:read("*l")
        pipe:close()
        local mib = out and out:match("(%d+)")
        if mib then return tonumber(mib) * 1024 * 1024 end
    end
    error("memory-budgeter: could not query free VRAM (nvidia-smi unavailable on " ..
          "this host/GPU). Pass a custom `probe` function in the spec for this GPU.")
end
-- }}}

-- {{{ M.file_size_bytes()
-- A convenience for the common "fixed = cache file size x parse factor" descriptor:
-- the on-disk size of a file, or nil if it does not exist (the caller decides whether
-- a missing input is fatal). Uses seek, not a shell stat -- no exec.
function M.file_size_bytes(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end
-- }}}

-- {{{ M.default_probe()
-- Map a pool name to its built-in measurement. A stage may bypass this entirely by
-- supplying its own `probe` in the spec (e.g. a Vulkan VRAM query).
function M.default_probe(pool)
    if pool == "ram" then return probe_ram_bytes end
    if pool == "vram" then return probe_vram_bytes end
    error("memory-budgeter: unknown pool '" .. tostring(pool) ..
          "' (expected 'ram' or 'vram', or pass a custom probe)")
end
-- }}}

-- {{{ M.compute_fit()
-- The pure decision -- numbers in, plan out, no I/O so it is unit-testable. How many
-- of `want` workers fit in `available` bytes, leaving a `headroom` fraction free for
-- the OS, GC churn, and JSON parse spikes? Returns:
--   threads  = the safe worker count (always >= 1)
--   reduced  = true if we cut below `want` to fit
--   swapping = true if even one worker overflows the budget (caller should WARN; the
--              fix is to shrink `fixed`, not to change the thread count)
--   budget   = available * headroom (the usable ceiling, for logging)
function M.compute_fit(available, fixed, per_thread, want, headroom)
    headroom = headroom or 0.7
    want = math.max(1, want or 1)
    local budget = available * headroom

    -- A worker with no marginal cost cannot be limited by per-worker memory; only the
    -- shared `fixed` can overflow. Threads are then "free" memory-wise, so we keep the
    -- requested count and only flag swapping if `fixed` itself blows the budget.
    if not per_thread or per_thread <= 0 then
        return { threads = want, reduced = false, swapping = fixed > budget, budget = budget }
    end

    local safe = math.floor((budget - fixed) / per_thread)
    if safe < 1 then
        -- Even one worker plus the fixed cost overflows the headroom budget. No thread
        -- count rescues this; run at one worker and let the caller warn about swap.
        return { threads = 1, reduced = want > 1, swapping = true, budget = budget }
    end

    local threads = math.min(want, safe)
    return { threads = threads, reduced = threads < want, swapping = false, budget = budget }
end
-- }}}

-- {{{ M.fit_threads()
-- The live entry point: probe the pool, run compute_fit, log the estimate and the
-- decision, and return the safe worker count. spec fields:
--   pool        "ram" | "vram"  (which memory to measure; ignored if `probe` given)
--   fixed       bytes loaded once, shared across workers
--   per_thread  bytes each worker adds (0/nil if workers are free)
--   want        requested worker count
--   headroom    optional fraction of free memory to use (default 0.7)
--   probe       optional function() -> free bytes (overrides the pool default)
--   label       optional short tag for the log lines (e.g. "HTML")
function M.fit_threads(spec)
    local probe = spec.probe or M.default_probe(spec.pool)
    local available = probe()
    local fit = M.compute_fit(available, spec.fixed, spec.per_thread, spec.want, spec.headroom)

    local tag = "[budget" .. (spec.label and (":" .. spec.label) or "") .. "]"
    local pool = (spec.pool or "ram"):upper()
    utils.log_info(string.format(
        "%s %s free %s, budget %s; fixed %s + %d x %s/worker -> %d worker(s)",
        tag, pool, format_bytes(available), format_bytes(fit.budget),
        format_bytes(spec.fixed or 0), fit.threads, format_bytes(spec.per_thread or 0),
        fit.threads))

    if fit.swapping then
        utils.log_warn(string.format(
            "%s the shared data (%s) does not fit the %s budget (%s) -- running at 1 " ..
            "worker and relying on SWAP. Shrink the shared data (shard/cap/stream it) " ..
            "or accept the slowdown. See issue 10-057.",
            tag, format_bytes(spec.fixed or 0), pool, format_bytes(fit.budget)))
    elseif fit.reduced then
        utils.log_info(string.format(
            "%s reduced workers %d -> %d to stay out of swap",
            tag, math.max(1, spec.want or 1), fit.threads))
    end

    return fit.threads
end
-- }}}

return M
