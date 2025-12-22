-- tui.lua - Terminal UI core library with framebuffer rendering
-- Uses a screen buffer to track cell state, only writing changed cells.
-- LuaJIT compatible. Called from bash scripts to render interactive menus.

local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
    typedef unsigned char cc_t;
    typedef unsigned int speed_t;
    typedef unsigned int tcflag_t;

    struct termios {
        tcflag_t c_iflag;
        tcflag_t c_oflag;
        tcflag_t c_cflag;
        tcflag_t c_lflag;
        cc_t c_line;
        cc_t c_cc[32];
        speed_t c_ispeed;
        speed_t c_ospeed;
    };

    int tcgetattr(int fd, struct termios *termios_p);
    int tcsetattr(int fd, int optional_actions, const struct termios *termios_p);

    struct winsize {
        unsigned short ws_row;
        unsigned short ws_col;
        unsigned short ws_xpixel;
        unsigned short ws_ypixel;
    };
    int ioctl(int fd, unsigned long request, ...);
]]

local STDIN_FILENO = 0
local TCSANOW = 0
local TIOCGWINSZ = 0x5413

local ICANON = 0x0002
local ECHO = 0x0008
local ISIG = 0x0001

-- {{{ TUI module
local tui = {}

-- Terminal state
local original_termios = nil
local rows, cols = 24, 80

-- Framebuffer: each cell stores {char, fg, bg, attrs}
-- Attrs: bit flags for bold(1), dim(2), inverse(4), underline(8)
local front_buffer = {}   -- What's currently on screen
local back_buffer = {}    -- What we want to draw

-- ANSI codes
tui.ESC = "\027"
tui.CSI = "\027["

-- Color constants (foreground)
tui.FG_DEFAULT = 0
tui.FG_BLACK = 30
tui.FG_RED = 31
tui.FG_GREEN = 32
tui.FG_YELLOW = 33
tui.FG_BLUE = 34
tui.FG_MAGENTA = 35
tui.FG_CYAN = 36
tui.FG_WHITE = 37

-- Background colors
tui.BG_DEFAULT = 0
tui.BG_BLACK = 40
tui.BG_RED = 41
tui.BG_GREEN = 42
tui.BG_YELLOW = 43
tui.BG_BLUE = 44
tui.BG_MAGENTA = 45
tui.BG_CYAN = 46
tui.BG_WHITE = 47

-- Attribute flags
tui.ATTR_NONE = 0
tui.ATTR_BOLD = 1
tui.ATTR_DIM = 2
tui.ATTR_INVERSE = 4
tui.ATTR_UNDERLINE = 8

-- Current drawing state
local current_fg = tui.FG_DEFAULT
local current_bg = tui.BG_DEFAULT
local current_attrs = tui.ATTR_NONE
-- }}}

-- {{{ Cell operations
local function make_cell(char, fg, bg, attrs)
    return {
        char = char or " ",
        fg = fg or tui.FG_DEFAULT,
        bg = bg or tui.BG_DEFAULT,
        attrs = attrs or tui.ATTR_NONE
    }
end

local function cells_equal(a, b)
    if not a or not b then return false end
    return a.char == b.char and a.fg == b.fg and a.bg == b.bg and a.attrs == b.attrs
end

local function copy_cell(cell)
    return make_cell(cell.char, cell.fg, cell.bg, cell.attrs)
end
-- }}}

-- {{{ Buffer operations
local function create_buffer(r, c)
    local buf = {}
    for y = 1, r do
        buf[y] = {}
        for x = 1, c do
            buf[y][x] = make_cell(" ")
        end
    end
    return buf
end

local function clear_buffer(buf)
    for y = 1, rows do
        if buf[y] then
            for x = 1, cols do
                buf[y][x] = make_cell(" ")
            end
        end
    end
end
-- }}}

-- {{{ tui.get_size
function tui.get_size()
    local ws = ffi.new("struct winsize")
    if ffi.C.ioctl(STDIN_FILENO, TIOCGWINSZ, ws) == 0 then
        rows = ws.ws_row
        cols = ws.ws_col
    end
    return rows, cols
end
-- }}}

-- {{{ tui.resize
-- Handle terminal resize - recreate buffers
function tui.resize()
    local old_rows, old_cols = rows, cols
    tui.get_size()

    if rows ~= old_rows or cols ~= old_cols then
        front_buffer = create_buffer(rows, cols)
        back_buffer = create_buffer(rows, cols)
        return true  -- Size changed
    end
    return false
end
-- }}}

-- {{{ Terminal mode control
-- Use stty for terminal control - works properly with /dev/tty
local saved_stty = nil

function tui.enable_raw_mode()
    if saved_stty then return end

    -- Save current terminal settings
    local handle = io.popen("stty -g < /dev/tty 2>/dev/null")
    if handle then
        saved_stty = handle:read("*a"):gsub("%s+$", "")
        handle:close()
    end

    -- Set raw mode: no echo, no canonical, no signals
    os.execute("stty raw -echo -isig < /dev/tty 2>/dev/null")
end

function tui.disable_raw_mode()
    if saved_stty then
        os.execute("stty " .. saved_stty .. " < /dev/tty 2>/dev/null")
        saved_stty = nil
    else
        -- Fallback: restore sane defaults
        os.execute("stty sane < /dev/tty 2>/dev/null")
    end
end
-- }}}

-- {{{ Low-level I/O
-- Use /dev/tty directly so TUI works even when stdin/stdout are captured
local tty_out = io.open("/dev/tty", "w")
local tty_in = io.open("/dev/tty", "r")

local function write_raw(s)
    if tty_out then
        tty_out:write(s)
    else
        io.stdout:write(s)
    end
end

local function flush()
    if tty_out then
        tty_out:flush()
    else
        io.stdout:flush()
    end
end

local function read_char()
    if tty_in then
        return tty_in:read(1)
    else
        return io.stdin:read(1)
    end
end

local function goto_raw(row, col)
    write_raw(string.format("\027[%d;%dH", row, col))
end
-- }}}

-- {{{ tui.set_attrs
-- Set current drawing attributes
function tui.set_fg(fg)
    current_fg = fg
end

function tui.set_bg(bg)
    current_bg = bg
end

function tui.set_attrs(attrs)
    current_attrs = attrs
end

function tui.reset_style()
    current_fg = tui.FG_DEFAULT
    current_bg = tui.BG_DEFAULT
    current_attrs = tui.ATTR_NONE
end
-- }}}

-- {{{ tui.set_cell
-- Set a cell in the back buffer (1-indexed row/col)
function tui.set_cell(row, col, char)
    if row < 1 or row > rows or col < 1 or col > cols then return end
    if not back_buffer[row] then return end

    back_buffer[row][col] = make_cell(char, current_fg, current_bg, current_attrs)
end
-- }}}

-- {{{ tui.write_str
-- Write string to back buffer starting at row, col
function tui.write_str(row, col, str)
    local x = col
    for i = 1, #str do
        if x > cols then break end
        local c = str:sub(i, i)
        tui.set_cell(row, x, c)
        x = x + 1
    end
    return x  -- Return ending column
end
-- }}}

-- {{{ tui.clear_row
-- Clear a row in the back buffer
function tui.clear_row(row)
    if row < 1 or row > rows then return end
    tui.reset_style()
    for x = 1, cols do
        back_buffer[row][x] = make_cell(" ")
    end
end
-- }}}

-- {{{ tui.clear_back_buffer
-- Clear entire back buffer
function tui.clear_back_buffer()
    clear_buffer(back_buffer)
end
-- }}}

-- {{{ tui.render_cell
-- Render a single cell to terminal (builds ANSI sequence)
-- Track last rendered style to know when we need to reset
local last_rendered_has_style = false

local function render_cell(cell)
    local parts = {}

    -- Build SGR sequence
    local codes = {}

    local has_style = cell.attrs ~= tui.ATTR_NONE or cell.fg ~= tui.FG_DEFAULT or cell.bg ~= tui.BG_DEFAULT

    -- Always reset if: we have styling OR previous cell had styling (to clear it)
    if has_style or last_rendered_has_style then
        table.insert(codes, "0")  -- Reset
    end

    -- Attributes
    if bit.band(cell.attrs, tui.ATTR_BOLD) ~= 0 then
        table.insert(codes, "1")
    end
    if bit.band(cell.attrs, tui.ATTR_DIM) ~= 0 then
        table.insert(codes, "2")
    end
    if bit.band(cell.attrs, tui.ATTR_INVERSE) ~= 0 then
        table.insert(codes, "7")
    end
    if bit.band(cell.attrs, tui.ATTR_UNDERLINE) ~= 0 then
        table.insert(codes, "4")
    end

    -- Foreground
    if cell.fg ~= tui.FG_DEFAULT then
        table.insert(codes, tostring(cell.fg))
    end

    -- Background
    if cell.bg ~= tui.BG_DEFAULT then
        table.insert(codes, tostring(cell.bg))
    end

    -- Update style tracking for next cell
    last_rendered_has_style = has_style

    if #codes > 0 then
        return "\027[" .. table.concat(codes, ";") .. "m" .. cell.char
    else
        return cell.char
    end
end

-- Reset style tracking (call at start of present)
local function reset_style_tracking()
    last_rendered_has_style = false
end
-- }}}

-- {{{ tui.present
-- Blit back buffer to screen, only updating changed cells
function tui.present()
    local output = {}
    local last_row, last_col = 0, 0
    local needs_reset = false

    -- Reset style tracking at start of each present
    reset_style_tracking()

    for y = 1, rows do
        for x = 1, cols do
            local back = back_buffer[y] and back_buffer[y][x]
            local front = front_buffer[y] and front_buffer[y][x]

            if back and not cells_equal(back, front) then
                -- Need to update this cell
                -- Position cursor if not already there
                if y ~= last_row or x ~= last_col + 1 then
                    -- Reset terminal style before jumping if we had styling
                    if last_rendered_has_style then
                        table.insert(output, "\027[0m")
                    end
                    table.insert(output, string.format("\027[%d;%dH", y, x))
                    -- Reset style tracking when jumping to new position
                    reset_style_tracking()
                end

                table.insert(output, render_cell(back))
                needs_reset = back.attrs ~= tui.ATTR_NONE or back.fg ~= tui.FG_DEFAULT or back.bg ~= tui.BG_DEFAULT

                -- Update front buffer
                front_buffer[y][x] = copy_cell(back)

                last_row = y
                last_col = x
            end
        end
    end

    -- Reset attributes at end if needed
    if needs_reset then
        table.insert(output, "\027[0m")
    end

    -- Write all at once
    if #output > 0 then
        write_raw(table.concat(output))
        flush()
    end
end
-- }}}

-- {{{ tui.force_redraw
-- Force complete redraw (mark all front buffer cells as different)
function tui.force_redraw()
    for y = 1, rows do
        if front_buffer[y] then
            for x = 1, cols do
                front_buffer[y][x] = make_cell("\0")  -- Invalid char forces redraw
            end
        end
    end
end
-- }}}

-- {{{ tui.hide_cursor / show_cursor
function tui.hide_cursor()
    write_raw("\027[?25l")
    flush()
end

function tui.show_cursor()
    write_raw("\027[?25h")
    flush()
end
-- }}}

-- {{{ tui.alt_screen
function tui.alt_screen_on()
    write_raw("\027[?1049h")
    flush()
end

function tui.alt_screen_off()
    write_raw("\027[?1049l")
    flush()
end
-- }}}

-- {{{ tui.read_key
function tui.read_key()
    local c = read_char()
    if not c then return nil end

    if c == "\027" then
        local seq1 = read_char()
        if not seq1 then return "ESCAPE" end

        if seq1 == "[" then
            local seq2 = read_char()
            if not seq2 then return "ESCAPE" end

            if seq2 == "A" then return "UP" end
            if seq2 == "B" then return "DOWN" end
            if seq2 == "C" then return "RIGHT" end
            if seq2 == "D" then return "LEFT" end
            if seq2 == "H" then return "HOME" end
            if seq2 == "F" then return "END" end
            if seq2 == "Z" then return "SHIFT_TAB" end  -- Shift+Tab (backtab)

            if seq2 >= "0" and seq2 <= "9" then
                local seq3 = read_char()
                if seq3 == "~" then
                    if seq2 == "1" then return "HOME" end
                    if seq2 == "3" then return "DELETE" end
                    if seq2 == "4" then return "END" end
                    if seq2 == "5" then return "PAGEUP" end
                    if seq2 == "6" then return "PAGEDOWN" end
                elseif seq3 == ";" then
                    -- Extended key with modifier: CSI number ; modifier ~ or u
                    local seq4 = read_char()
                    local seq5 = read_char()
                    -- Shift+Enter: \e[13;2u (kitty) or \e[27;2;13~ (xterm modifyOtherKeys)
                    if seq2 == "1" and seq4 == "2" and seq5 == "u" then
                        -- \e[1;2u - could be Shift+something, check context
                        return "SHIFT_ENTER"
                    elseif seq4 == "2" then
                        -- Modifier 2 = Shift
                        if seq5 == "u" or seq5 == "~" then
                            if seq2 == "1" then return "SHIFT_HOME" end
                        end
                    end
                end
            end
            -- Kitty keyboard protocol: \e[13;2u for Shift+Enter
            if seq2 == "1" then
                local seq3 = read_char()
                if seq3 == "3" then
                    local seq4 = read_char()
                    if seq4 == ";" then
                        local seq5 = read_char()
                        local seq6 = read_char()
                        if seq5 == "2" and seq6 == "u" then
                            return "SHIFT_ENTER"
                        end
                    end
                end
            end
        end
        return "ESCAPE"
    end

    if c == "\r" or c == "\n" then return "ENTER" end
    if c == "\t" then return "TAB" end
    if c == "\127" then return "BACKSPACE" end
    if c == " " then return "SPACE" end
    if c == "\003" then return "CTRL_C" end

    return c
end
-- }}}

-- {{{ Box drawing helpers (write to back buffer)
function tui.draw_box_top(row, col, width, style)
    local left, horiz, right
    if style == "double" then
        left, horiz, right = "\226\149\148", "\226\149\144", "\226\149\151"  -- ╔ ═ ╗
    else
        left, horiz, right = "\226\148\140", "\226\148\128", "\226\148\144"  -- ┌ ─ ┐
    end

    tui.set_cell(row, col, left)
    for x = col + 1, col + width - 2 do
        tui.set_cell(row, x, horiz)
    end
    tui.set_cell(row, col + width - 1, right)
end

function tui.draw_box_bottom(row, col, width, style)
    local left, horiz, right
    if style == "double" then
        left, horiz, right = "\226\149\154", "\226\149\144", "\226\149\157"  -- ╚ ═ ╝
    else
        left, horiz, right = "\226\148\148", "\226\148\128", "\226\148\152"  -- └ ─ ┘
    end

    tui.set_cell(row, col, left)
    for x = col + 1, col + width - 2 do
        tui.set_cell(row, x, horiz)
    end
    tui.set_cell(row, col + width - 1, right)
end

function tui.draw_box_separator(row, col, width, style)
    local left, horiz, right
    if style == "double" then
        left, horiz, right = "\226\149\160", "\226\149\144", "\226\149\163"  -- ╠ ═ ╣
    else
        left, horiz, right = "\226\148\156", "\226\148\128", "\226\148\164"  -- ├ ─ ┤
    end

    tui.set_cell(row, col, left)
    for x = col + 1, col + width - 2 do
        tui.set_cell(row, x, horiz)
    end
    tui.set_cell(row, col + width - 1, right)
end

function tui.draw_box_line(row, col, width, style)
    local vert = style == "double" and "\226\149\145" or "\226\148\130"  -- ║ or │
    tui.set_cell(row, col, vert)
    tui.set_cell(row, col + width - 1, vert)
end

function tui.draw_hline(row, start_col, end_col, char)
    char = char or "\226\148\128"  -- ─
    for x = start_col, end_col do
        tui.set_cell(row, x, char)
    end
end
-- }}}

-- {{{ tui.init
function tui.init()
    tui.get_size()
    front_buffer = create_buffer(rows, cols)
    back_buffer = create_buffer(rows, cols)

    tui.enable_raw_mode()
    tui.alt_screen_on()
    tui.hide_cursor()
    tui.force_redraw()

    return rows, cols
end
-- }}}

-- {{{ tui.cleanup
function tui.cleanup()
    tui.show_cursor()
    tui.alt_screen_off()
    tui.disable_raw_mode()
end
-- }}}

-- {{{ Accessors
function tui.rows()
    return rows
end

function tui.cols()
    return cols
end
-- }}}

return tui
