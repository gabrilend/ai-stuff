-- progress-ui.lua
-- Issue 026: In-place redrawing progress region for the PDF page loop.
--
-- The PDF generator walks ~500 pages and prints ~15 status lines per
-- page. Letting all of that scroll past on the terminal makes the
-- progress bar unreadable and buries any interesting per-page detail.
-- This module fixes both problems by treating a fixed slice of the
-- terminal as a redraw region: every page reuses the same screen
-- real-estate, anchored by a high-water-mark height so the bar never
-- jumps once it has found its final position.
--
-- Two sinks, written to in parallel:
--   - /dev/tty (terminal-only, bypasses any tee/redirect the parent
--     shell set up) gets the colored, redraw-with-ANSI-escapes view.
--     If /dev/tty cannot be opened (run is piped, no controlling
--     terminal, etc.) the redraw path is skipped and lines are
--     emitted via plain print() — i.e. today's scrolling behavior.
--   - $LOG_FILE (path injected by ./run) gets every status line in
--     plain text with no ANSI escapes, in strict order. Reading the
--     log after the run looks like what the terminal showed before
--     this module existed.
--
-- The bar's filled portion is colored along a no-red gradient (dark
-- blue → purple → cyan → yellow → green) keyed on completion
-- fraction, so a glance at the terminal tells you roughly how far
-- along you are without needing to read the percentage.

local M = {}

-- {{{ module-level state
-- Held in a single table so M.init can reset all fields without
-- worrying about which variables it forgot to touch on a second run.
local state = {
    total_pages = 0,
    tty = nil,              -- io handle for /dev/tty, nil if non-interactive
    log = nil,              -- io handle for the run log file
    tty_rows = 24,          -- detected terminal height; the frame cap derives from this
    frame_cap = 23,         -- max lines we'll ever render to the tty per page (tty_rows - 1)
    max_region_height = 0,  -- high-water mark for what we ACTUALLY rendered, <= frame_cap
    bar_tty = nil,          -- colored bar string for the current page (line 1 of frame)
    bar_plain = nil,        -- plain mirror of bar_tty for the log and non-interactive path
    content_lines = {},     -- plain-text status lines collected by log() for current page
    pages_done = 0,         -- pages already flushed; 0 means "no anchor yet"
}
-- }}}

-- {{{ FRAC_TO_CODE
-- Dispatch table mapping the upper bound of a fraction bucket to a
-- 256-color ANSI code. Walked in order; the first entry whose bound
-- is >= the current fraction wins. Reds are deliberately omitted —
-- the bar should never read as "warning" or "error" since the run
-- is succeeding at every percentage value.
local FRAC_TO_CODE = {
    {0.2, 17},   -- dark blue
    {0.4, 93},   -- purple
    {0.6, 51},   -- cyan
    {0.8, 226},  -- yellow
    {1.0, 46},   -- green
}
-- }}}

-- {{{ local function ansi_color_for_fraction
local function ansi_color_for_fraction(frac)
    for _, entry in ipairs(FRAC_TO_CODE) do
        if frac <= entry[1] then return entry[2] end
    end
    -- Defensive: frac > 1.0 should not happen, but cap at green
    -- rather than returning nil and crashing the format string.
    return 46
end
-- }}}

-- {{{ local function build_progress_bar
-- Returns two strings: a tty-ready version with ANSI color escapes,
-- and a plain version for the log file. The two share the same text
-- content so the log reads exactly like the terminal would minus the
-- colors. White (256-color 15) is forced on the surrounding text so
-- the user-requested look ("dark blue bar on white text") holds even
-- on terminals whose default foreground is some other color.
local function build_progress_bar(page_num, total)
    local progress_percent = math.floor((page_num / total) * 100)
    local filled = math.floor(progress_percent / 5)
    local empty = 20 - filled
    local filled_str = string.rep("█", filled)
    local empty_str = string.rep("░", empty)

    local plain = string.format(
        "📖 Processing page %d/%d [%s%s] %d%% complete",
        page_num, total, filled_str, empty_str, progress_percent)

    local color = ansi_color_for_fraction(page_num / total)
    local tty = string.format(
        "\27[38;5;15m📖 Processing page %d/%d [\27[38;5;%dm%s\27[38;5;15m%s] %d%% complete\27[0m",
        page_num, total, color, filled_str, empty_str, progress_percent)

    return tty, plain
end
-- }}}

-- {{{ local function detect_tty_rows
-- Asks tput how tall the terminal is. tput reads $TERM, $LINES, and the
-- TIOCGWINSZ ioctl; we don't care which it uses, only that the answer
-- reflects the actual user-visible row count. If tput is missing or
-- the read fails (containers without tput, terminfo missing, etc.) we
-- fall back to 24, the historical xterm default.
local function detect_tty_rows()
    local handle = io.popen("tput lines 2>/dev/null")
    if not handle then return 24 end
    local n = handle:read("*n")
    handle:close()
    return n or 24
end
-- }}}

-- {{{ function M.init
-- Called once before the page loop. total_pages is the divisor for
-- the gradient and the percentage. The /dev/tty open is nil-tolerant
-- because there are valid reasons it can fail (piped run, container
-- without a controlling terminal); the redraw simply degrades to
-- plain scrolling in that case. The $LOG_FILE open is NOT nil-
-- tolerant — if ./run forgot to export it the contract between the
-- script and this module has been broken and we want a loud failure.
--
-- Tee-buffered stdout is flushed up-front so the "Starting PDF
-- generation" banner (and anything else printed via stdout before
-- this call) hits the terminal BEFORE the first /dev/tty write.
-- Without the flush, tee can drip those lines into the middle of the
-- first redraw frame and offset every subsequent cursor-up by the
-- same amount, gradually walking the anchor off-screen.
function M.init(total_pages)
    state.total_pages = total_pages
    state.pages_done = 0
    state.max_region_height = 0
    state.content_lines = {}
    state.bar_tty = nil
    state.bar_plain = nil

    io.stdout:flush()
    io.stderr:flush()

    state.tty = io.open("/dev/tty", "w")

    -- Cap the redraw region at (rows - 1) so cursor-up never overshoots
    -- the visible terminal top. Anything over that triggers truncation
    -- at flush time, replacing dropped lines with a "…N more" indicator.
    -- A floor of 5 keeps the cap sane on absurdly short terminals.
    state.tty_rows = detect_tty_rows()
    state.frame_cap = math.max(state.tty_rows - 1, 5)

    local log_path = os.getenv("LOG_FILE")
    if not log_path or log_path == "" then
        error("progress-ui: LOG_FILE env var is not set; ./run is supposed to export it")
    end
    state.log = io.open(log_path, "a")
    if not state.log then
        error("progress-ui: cannot open log file " .. log_path)
    end
end
-- }}}

-- {{{ function M.start_page
-- Open a new redraw frame and paint the bar IMMEDIATELY so the user
-- sees the current page number the moment processing starts. This is
-- the critical fix for the issue-026 follow-up bug: previously the
-- bar was only emitted at end_page, so during the (slow) first-page
-- embedding initialization and the (variable-length) per-page work
-- the screen sat empty with the old bar wiped — looking to the user
-- like every status line had been erased.
--
-- On every page after the first, the cursor-up + clear-to-eos pair
-- repositions to the anchor and erases the previous frame before we
-- paint the new bar. \27[0J is used instead of bare \27[J because
-- some terminals interpret the parameter-less form as \27[2J (clear
-- entire screen); the explicit "0" mode is universally "cursor to
-- end of screen". The cursor-up amount is capped at frame_cap so it
-- can never overshoot the visible terminal top.
function M.start_page(page_num)
    state.content_lines = {}
    local bar_tty, bar_plain = build_progress_bar(page_num, state.total_pages)
    state.bar_tty = bar_tty
    state.bar_plain = bar_plain
    state.log:write(bar_plain .. "\n")
    state.log:flush()

    if state.tty then
        if state.pages_done > 0 then
            state.tty:write(string.format("\27[%dA\27[0J", state.max_region_height))
        end
        state.tty:write(bar_tty .. "\n")
        state.tty:flush()
    end
end
-- }}}

-- {{{ function M.log
-- Stream a status line to the tty IMMEDIATELY so the user can watch
-- per-page work happen in real time rather than waiting for end_page
-- to paint a finished frame. Two caps in play:
--   - LIVE_CONTENT_CAP = frame_cap - 2 lines are written live (the
--     -2 reserves one slot for a possible truncation indicator on
--     the last frame line and one slot for the bar at the top).
--   - Beyond that, lines still accumulate in content_lines and the
--     log file but are suppressed from the tty; end_page decides
--     whether the (LIVE+1)th line is rendered as-is (when it is the
--     last one) or replaced by a "…+N more (see log)" indicator.
function M.log(text)
    table.insert(state.content_lines, text)
    state.log:write(text .. "\n")
    state.log:flush()

    if state.tty and #state.content_lines <= state.frame_cap - 2 then
        state.tty:write(text .. "\n")
        state.tty:flush()
    end
end
-- }}}

-- {{{ function M.end_page
-- Finish the current frame. By the time we get here the bar and the
-- first (frame_cap - 2) content lines have already been streamed to
-- the tty by start_page and log(). End_page's job is to:
--   1. Emit the trailing content line OR a truncation indicator, if
--      content exceeded what log() was allowed to stream.
--   2. Pad with blank lines so the cursor always lands exactly
--      max_region_height rows below the anchor, regardless of how
--      many status lines this particular page emitted. The next
--      start_page's cursor-up uses max_region_height as its jump
--      magnitude, so the pad invariant must hold every page.
--   3. Grow max_region_height up to (but never past) frame_cap.
function M.end_page()
    if state.tty then
        local total = #state.content_lines
        local live_cap = state.frame_cap - 2  -- mirrored from M.log
        local frame_content_lines

        if total <= live_cap then
            -- Everything got streamed live by log(). Nothing more to draw.
            frame_content_lines = total
        elseif total == live_cap + 1 then
            -- Exactly one more line than log() was allowed to stream.
            -- No indicator needed — there's room to show it as-is.
            state.tty:write(state.content_lines[total] .. "\n")
            frame_content_lines = total
        else
            -- More content than fits even with one extra slot. Replace
            -- the would-be (live_cap + 1)th line with an indicator so
            -- the user knows there are extra lines, viewable in the log.
            state.tty:write(string.format(
                "  … +%d more lines (see log)\n",
                total - live_cap))
            frame_content_lines = live_cap + 1
        end

        local frame_height = 1 + frame_content_lines  -- +1 for the bar
        if frame_height > state.max_region_height then
            state.max_region_height = frame_height
        else
            for _ = frame_height + 1, state.max_region_height do
                state.tty:write("\n")
            end
        end
        state.tty:flush()
    else
        -- Non-interactive fallback: nothing was streamed live (log()
        -- only writes to tty when it exists), so dump the whole frame
        -- via print() now. No truncation — consumers of the captured
        -- stream (file, pipe, CI) want the complete record.
        print(state.bar_plain)
        for _, line in ipairs(state.content_lines) do
            print(line)
        end
    end
    state.pages_done = state.pages_done + 1
end
-- }}}

-- {{{ function M.finish
-- Tear down the tty side after the page loop. The log file handle
-- is left open intentionally — it lives in tmp/ (tmpfs), the OS
-- closes it on process exit, and we never need to read from it
-- during this process's lifetime.
function M.finish()
    if state.tty then
        state.tty:write("\27[0m")
        state.tty:flush()
        state.tty:close()
        state.tty = nil
    end
end
-- }}}

return M
