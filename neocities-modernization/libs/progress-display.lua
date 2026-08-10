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
-- ioctl + winsize, for asking the terminal how wide it is. Same pcall guard:
-- if the declaration or the call fails we fall back to a conservative width
-- rather than taking a build down over a cosmetic detail.
pcall(ffi.cdef, [[
struct winsize { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel; };
int ioctl(int fd, unsigned long request, ...);
]])

local M = {}

-- Issue 10-065: the bar is sized to the TERMINAL, not fixed at 40 columns.
--
-- Why it had to change. At a fixed 40 the full line came to 84 display columns
-- ("   <emoji> Semantic colors [40 cells] 8510/8510 (100%)" plus the trailing
-- pad) -- and 84 does not fit an 80-column terminal. It wrapped, and a wrapped
-- line defeats the whole mechanism: "\r" returns to the start of the LAST
-- screen row, not the start of the logical line, so each update redrew below
-- the previous one instead of over it. The console filled with hundreds of
-- half-erased bars. With a suffix -- the semantic-colour stage appends
-- "poem_index 1234 = orange" -- the line reached ~108 columns and every single
-- update survived on screen.
--
-- It looked exactly like the bar was ignoring the --debug setting and printing
-- a line per update. It was not: the mode was correct, the line was too long.
--
-- MIN_BAR keeps the bar meaningful on a narrow terminal; below that there is
-- not enough resolution for movement to be visible and the counts carry the
-- information instead. MAX_BAR preserves the old look where there is room.
local MIN_BAR, MAX_BAR = 10, 40
local FALLBACK_COLS = 80
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

-- {{{ local function display_width(s)
-- Columns a string occupies on screen, which is not its byte length and not its
-- character count. UTF-8 encodes the box-drawing glyphs used by the bar in three
-- bytes for one column each, and the emoji in the stage labels in four bytes for
-- TWO columns each. Counting bytes would make every label look far wider than it
-- is; counting characters would under-count every emoji by one. Both errors put
-- the line over the edge, which is the failure this whole exercise is about.
local function display_width(s)
    local cols, i = 0, 1
    while i <= #s do
        local b = s:byte(i)
        local seq = (b < 0x80) and 1 or (b < 0xE0) and 2 or (b < 0xF0) and 3 or 4
        -- Four-byte sequences are the astral plane, which is where the emoji
        -- live; those render double-width in every terminal font this project
        -- targets. Everything else is treated as one column.
        cols = cols + ((seq == 4) and 2 or 1)
        i = i + seq
    end
    return cols
end
-- }}}

-- {{{ local function terminal_cols()
-- How wide the terminal is, asked once and remembered. A resize mid-run would go
-- unnoticed; that is a deliberate trade, since asking on every frame means an
-- ioctl per redraw and a stale width merely makes the bar narrower than it could
-- be, never wider than it may be.
--
-- Order: ask the kernel what the terminal actually is; failing that trust the
-- COLUMNS the shell exported; failing that assume 80, which is the width that
-- has been safe since the punch card.
local cached_cols = nil
local function terminal_cols()
    if cached_cols then return cached_cols end

    local ok, cols = pcall(function()
        local ws = ffi.new("struct winsize")
        -- TIOCGWINSZ on Linux. This project is Linux-only throughout (it assumes
        -- /dev/shm, elogind, Vulkan), so the constant is written directly rather
        -- than discovered.
        if ffi.C.ioctl(1, 0x5413, ws) == 0 and ws.ws_col > 0 then
            return tonumber(ws.ws_col)
        end
        return nil
    end)
    if ok and cols then
        cached_cols = cols
        return cached_cols
    end

    local env_cols = tonumber(os.getenv("COLUMNS") or "")
    cached_cols = (env_cols and env_cols > 0) and env_cols or FALLBACK_COLS
    return cached_cols
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

    -- Animated bar, sized so the WHOLE line fits the terminal. Everything except
    -- the bar is measured first; the bar gets what is left.
    local counts = string.format(" %d/%d (%3.0f%%)", current, total, pct)
    local fixed = display_width(label) + display_width(counts)
                  + 3            -- the " [" and "] " framing
                  + 3            -- trailing pad, which erases a shrinking suffix
    local budget = terminal_cols() - 1 - fixed   -- -1: never write the last cell

    -- A suffix is a luxury: it is dropped entirely before the bar is allowed to
    -- shrink below MIN_BAR, and truncated to whatever room is left after the bar
    -- has taken its minimum. An ETA is worth less than a bar that stays put.
    local tail_room = budget - MIN_BAR
    if tail_room < 1 then
        tail = ""
    elseif display_width(tail) > tail_room then
        tail = tail:sub(1, tail_room)
    end
    budget = budget - display_width(tail)

    local bar_width = budget
    if bar_width > MAX_BAR then bar_width = MAX_BAR end
    if bar_width < MIN_BAR then bar_width = MIN_BAR end

    local filled = math.floor(frac * bar_width)
    local bar = string.rep("█", filled) .. string.rep("░", bar_width - filled)
    -- Writing the last cell of a line makes some terminals wrap immediately,
    -- which would reintroduce the very problem this sizing prevents -- hence the
    -- -1 above, and hence the trailing pad being counted as part of the budget
    -- rather than tacked on afterwards.
    io.write(string.format("\r%s [%s]%s%s   ", label, bar, counts, tail))
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
