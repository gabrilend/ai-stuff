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
    -- No tty write here anymore. The whole frame (bar + content + padding)
    -- is composed into ONE string and written once in end_page, so the
    -- terminal never shows a half-cleared region between pages. Painting
    -- the bar here would be a second write per page and reintroduce the
    -- clear-then-redraw flicker this redesign exists to remove.
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
    -- tty rendering is deferred to end_page, which paints the whole frame
    -- in a single write. See start_page for why lines are no longer
    -- streamed to the terminal one at a time.
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
        -- Compose the ENTIRE frame — reposition, bar, content, and the
        -- blank padding that erases a taller previous frame — into one
        -- string, then emit it with a single tty:write. Every line clears
        -- to end-of-line (\27[K) as it is overwritten, and leftover rows
        -- are blanked the same way, so we never issue a clear-to-end-of-
        -- screen (\27[0J). That full-region clear is what made the area
        -- below the bar flash black between pages; overwriting in place in
        -- one write removes the blank moment entirely.
        local parts = {}

        -- Reposition to the top of the region (the bar's row). On the very
        -- first page there is no prior frame, so there is nothing to move
        -- back over.
        if state.pages_done > 0 then
            parts[#parts + 1] = string.format("\27[%dA", state.max_region_height)
        end

        -- Bar occupies row 1 of the frame.
        parts[#parts + 1] = state.bar_tty .. "\27[K\n"

        -- Content rows, capped so bar + content never exceed frame_cap.
        local total = #state.content_lines
        local content_cap = state.frame_cap - 1  -- minus the bar row
        local shown_content
        if total <= content_cap then
            shown_content = total
            for i = 1, total do
                parts[#parts + 1] = state.content_lines[i] .. "\27[K\n"
            end
        else
            -- Show (content_cap - 1) real lines plus one indicator line so
            -- the operator knows the remainder lives in the log.
            shown_content = content_cap
            for i = 1, content_cap - 1 do
                parts[#parts + 1] = state.content_lines[i] .. "\27[K\n"
            end
            parts[#parts + 1] = string.format(
                "  … +%d more lines (see log)\27[K\n",
                total - (content_cap - 1))
        end

        -- Erase any rows the previous, taller frame left behind. These
        -- blank cleared lines keep the cursor landing exactly
        -- max_region_height rows below the anchor — the invariant the next
        -- page's cursor-up relies on. The region only ever grows (high-
        -- water mark), so it never visually shrinks mid-run.
        local frame_height = 1 + shown_content  -- +1 for the bar
        if frame_height < state.max_region_height then
            for _ = frame_height + 1, state.max_region_height do
                parts[#parts + 1] = "\27[K\n"
            end
        elseif frame_height > state.max_region_height then
            state.max_region_height = frame_height
        end

        state.tty:write(table.concat(parts))
        state.tty:flush()
    else
        -- Non-interactive fallback: dump the whole frame via print(). No
        -- truncation — consumers of the captured stream want everything.
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
-- is left open intentionally — it lives in tmp/shared-memory/ (tmpfs), the OS
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

-- {{{ standalone single-line progress bar (M.bar / M.bar_finish)
-- A lightweight in-place bar for the pre-render scoring passes (page and
-- per-poem axis projection) and any other long count-up loop that runs
-- OUTSIDE the page-frame model above. It owns no frame state: it redraws
-- one line on /dev/tty with a carriage return, throttled to integer-
-- percent changes so the loop doesn't spend its time in write(), and drops
-- a milestone line into $LOG_FILE every 10% so the captured log shows
-- progress without one line per iteration.
--
-- Unlike M.init, both sinks are optional here: this bar is purely
-- cosmetic, so a missing /dev/tty (piped run) or missing $LOG_FILE (a
-- direct lua invocation that bypassed ./run) degrades silently rather than
-- aborting the render. Call M.bar(label, current, total) each iteration
-- and M.bar_finish() once when the loop ends. It reuses the same no-red
-- gradient as the page bar via ansi_color_for_fraction.
local bar_state = { tty = nil, log = nil, opened = false, label = nil, last_pct = -1 }

-- {{{ local function bar_open
local function bar_open()
    if bar_state.opened then return end
    bar_state.opened = true
    -- Flush buffered stdout first so the "Scoring…" header printed just
    -- before the loop lands on the terminal BEFORE the first /dev/tty
    -- write — otherwise tee can drip it out on top of the bar line. Same
    -- precaution M.init takes for the page frame.
    io.stdout:flush()
    bar_state.tty = io.open("/dev/tty", "w")  -- nil when non-interactive
    local log_path = os.getenv("LOG_FILE")
    if log_path and log_path ~= "" then
        bar_state.log = io.open(log_path, "a")
    end
end
-- }}}

-- {{{ function M.bar
function M.bar(label, current, total)
    if total <= 0 then return end
    bar_open()
    if current > total then current = total end
    local pct = math.floor((current / total) * 100)
    -- A new label resets the throttle so a second bar in the same run draws
    -- immediately instead of waiting for the percent to move off the old one.
    if label ~= bar_state.label then
        bar_state.label = label
        bar_state.last_pct = -1
    end
    -- Throttle: only repaint when the integer percent moved, except always
    -- paint the final tick so the bar lands on 100%.
    if pct == bar_state.last_pct and current < total then return end
    bar_state.last_pct = pct

    local filled = math.floor(pct / 5)
    local filled_str = string.rep("█", filled)
    local empty_str = string.rep("░", 20 - filled)

    if bar_state.tty then
        local color = ansi_color_for_fraction(current / total)
        bar_state.tty:write(string.format(
            "\r\27[38;5;15m%s %d/%d [\27[38;5;%dm%s\27[38;5;15m%s] %d%%\27[0m\27[0K",
            label, current, total, color, filled_str, empty_str, pct))
        bar_state.tty:flush()
    end
    if bar_state.log and pct % 10 == 0 then
        bar_state.log:write(string.format("%s %d/%d %d%%\n", label, current, total, pct))
        bar_state.log:flush()
    end
end
-- }}}

-- {{{ function M.bar_finish
function M.bar_finish()
    -- Move off the bar line (it was drawn with \r and no trailing newline)
    -- so the next print() doesn't overwrite it, and release the handles so
    -- the page-frame M.init can reopen its own cleanly afterward.
    if bar_state.tty then
        bar_state.tty:write("\n")
        bar_state.tty:flush()
        bar_state.tty:close()
    end
    if bar_state.log then
        bar_state.log:close()
    end
    bar_state.tty = nil
    bar_state.log = nil
    bar_state.opened = false
    bar_state.label = nil
    bar_state.last_pct = -1
end
-- }}}

return M
