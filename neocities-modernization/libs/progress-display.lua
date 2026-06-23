-- {{{ progress-display.lua
-- Pure-Lua mirror of the C progress renderer (libs/vulkan-compute/src/vk_compute.c
-- vkc_progress_*). Lua stages that have no reason to load the Vulkan shared
-- library -- HTML generation, word pages -- use this so their progress bar
-- looks identical to the GPU stages and obeys the same rules:
--
--   * VKC_DEBUG set (run.sh --debug) -> verbose: one plain, newline-terminated
--     line per update, so a redirected log keeps the full history of a run.
--   * else stdout is a TTY -> animated: updates overwrite one line with a "\r"
--     Unicode bar (█ done, ░ pending).
--   * else (piped to a file / cron, no debug) -> quiet: nothing is drawn.
--
-- The C version is the source of truth for the look; this is kept byte-for-byte
-- compatible (same bar width, same glyphs, same "label [bar] cur/total (pct%)
-- suffix" layout) so a reader cannot tell which stage drew a given bar.
local ffi = require("ffi")
-- isatty lives in libc; pcall guards the (impossible-in-practice) case where
-- the symbol is unavailable, so a missing isatty degrades to "not a TTY"
-- (quiet) rather than erroring a whole HTML run over a progress bar.
pcall(ffi.cdef, "int isatty(int fd);")

local M = {}

local BAR_WIDTH = 40
local MODE_QUIET, MODE_BAR, MODE_VERBOSE = 0, 1, 2

-- {{{ local function resolve_mode()
-- Resolved once and memoised: neither stdout's TTY-ness nor VKC_DEBUG changes
-- during a run. Mirrors vkc_progress_mode()'s ordering -- debug is checked
-- BEFORE isatty, so --debug through a pipe still yields verbose lines (the
-- whole point of --debug) instead of falling through to quiet.
local cached_mode = nil
local function resolve_mode()
    if cached_mode ~= nil then return cached_mode end
    local debug_flag = os.getenv("VKC_DEBUG")
    if debug_flag and debug_flag ~= "" then
        cached_mode = MODE_VERBOSE
    else
        local is_tty = false
        local ok, result = pcall(function() return ffi.C.isatty(1) end)
        if ok and result ~= 0 then is_tty = true end
        cached_mode = is_tty and MODE_BAR or MODE_QUIET
    end
    return cached_mode
end
-- }}}

-- {{{ function M.mode()
-- Exposes the resolved mode (0 quiet / 1 bar / 2 verbose) so callers can
-- throttle: animate every step in bar mode, but emit sparse lines when verbose.
function M.mode()
    return resolve_mode()
end
-- }}}

-- {{{ function M.update(label, current, total, suffix)
-- Draw one progress frame. suffix is optional extra text (e.g. rate / ETA)
-- appended after the percentage. Cheap to call; in bar mode call as often as
-- you like, in verbose mode throttle to keep the log readable.
function M.update(label, current, total, suffix)
    local mode = resolve_mode()
    if mode == MODE_QUIET then return end

    local frac = (total > 0) and (current / total) or 1.0
    if frac > 1.0 then frac = 1.0 end  -- callers may overshoot
    local pct = frac * 100
    local tail = suffix and (" " .. suffix) or ""

    if mode == MODE_VERBOSE then
        io.write(string.format("%s %d/%d (%.0f%%)%s\n", label, current, total, pct, tail))
        io.flush()
        return
    end

    -- Animated bar. Trailing spaces clear any leftover tail from a previously
    -- longer suffix (ETA strings shrink as a run finishes).
    local filled = math.floor(frac * BAR_WIDTH)
    local bar = string.rep("█", filled) .. string.rep("░", BAR_WIDTH - filled)
    io.write(string.format("\r%s [%s] %d/%d (%3.0f%%)%s   ",
        label, bar, current, total, pct, tail))
    io.flush()
end
-- }}}

-- {{{ function M.finish()
-- Close an animated line with a newline. No-op in verbose/quiet modes (they
-- never left the cursor mid-line).
function M.finish()
    if resolve_mode() == MODE_BAR then
        io.write("\n")
        io.flush()
    end
end
-- }}}

return M
-- }}}
