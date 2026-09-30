--[[
A Text Editor for the Trigger Editor's Code View (Issue 905)

Lines of text with a cursor: typing, Backspace and Delete, Enter (keeping
the line's indent), Tab (four spaces), the arrows, Home and End, Page Up
and Page Down, the mouse wheel and a click to place the cursor. JASS is
coloured as it's drawn: keywords, natives' names (capitalised calls),
strings, numbers and rawcodes, comments; with opts.lang = "lua", Lua (issue
905b). A read-only one only moves. With opts.words, what's being typed is
completed: the words starting with it show under the cursor and Tab (or
Ctrl+Space to show them) takes the first. T.error = { line, message }
marks a line and shows why under the text.

    local textedit = require("editor.textedit")
    local T = textedit.new(text, { readonly = false, lang = "lua", words = { ... } })
    T:key("LEFT"); T:type("abc"); T:text()
    T:click(mx, my, box, measure)       -- box = { x, y, w, h, size }
    T:draw(render, box)
]]

local textedit = {}

local TE = {}
TE.__index = TE

textedit.KEYWORDS = {}
for w in ([[function takes returns nothing endfunction local set call if then else elseif endif loop
    exitwhen endloop return globals endglobals constant native type extends array and or not true false null
    integer real boolean string handle code unit player trigger group location rect timer force]]):gmatch("%S+") do
    textedit.KEYWORDS[w] = true
end

-- Lua's, for the triggers' Lua view (issue 905b: opts.lang = "lua")
textedit.LUA_KEYWORDS = {}
for w in ([[and break do else elseif end false for function goto if in local nil not or repeat return then
    true until while]]):gmatch("%S+") do
    textedit.LUA_KEYWORDS[w] = true
end

local COLOURS = {
    text = { 220, 220, 210 }, keyword = { 110, 170, 255 }, call = { 230, 200, 120 }, string = { 150, 220, 130 },
    number = { 230, 150, 110 }, comment = { 120, 130, 120 }, cursor = { 255, 255, 255 }, gutter = { 100, 105, 115 },
    back = { 18, 20, 24 }, line = { 34, 38, 46 }, error = { 90, 30, 30 }, error_text = { 255, 150, 130 },
    popup = { 40, 46, 60 }, popup_first = { 70, 90, 60 },
}

-- {{{ textedit.new
function textedit.new(text, opts)
    local self = setmetatable({ lines = {}, cy = 1, cx = 0, top = 1, opts = opts or {} }, TE)
    self:set_text(text or "")
    return self
end

function TE:set_text(text)
    self.lines = {}
    -- protected scripts end many lines with a lone carriage return
    for l in (text:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"):gmatch("(.-)\n") do self.lines[#self.lines + 1] = l end
    if #self.lines == 0 then self.lines[1] = "" end
    self.cy, self.cx, self.top = 1, 0, 1
    self.changed = false
end

function TE:text() return table.concat(self.lines, "\n") end
-- }}}

-- {{{ editing
local function clamp(self)
    self.cy = math.max(1, math.min(#self.lines, self.cy))
    self.cx = math.max(0, math.min(#self.lines[self.cy], self.cx))
end

-- {{{ completing words (opts.words: a list, or a function giving one)
-- the word being typed before the cursor
function TE:prefix()
    local l = self.lines[self.cy]
    return l:sub(1, self.cx):match("[%w_]+$") or ""
end

function TE:update_suggest()
    local words = self.opts.words
    if type(words) == "function" then words = words() end
    local p = self:prefix()
    self.suggest = nil
    if not words or #p < 2 then return end
    local list = {}
    for _, w in ipairs(words) do
        if #w > #p and w:sub(1, #p) == p then list[#list + 1] = w end
    end
    if #list > 0 then self.suggest = list end
end

-- the first suggestion put in place of what's typed: true when one was
function TE:complete()
    if not self.suggest or #self.suggest == 0 then return false end
    local w, p = self.suggest[1], self:prefix()
    local l = self.lines[self.cy]
    self.lines[self.cy] = l:sub(1, self.cx) .. w:sub(#p + 1) .. l:sub(self.cx + 1)
    self.cx = self.cx + #w - #p
    self.suggest = nil
    self.changed = true
    return true
end
-- }}}

function TE:type(s)
    if self.opts.readonly or s == "" then return end
    self.error = nil
    for ch in s:gmatch(".") do
        if ch == "\n" then self:key("ENTER")
        elseif ch:byte() >= 32 then
            local l = self.lines[self.cy]
            self.lines[self.cy] = l:sub(1, self.cx) .. ch .. l:sub(self.cx + 1)
            self.cx = self.cx + 1
            self.changed = true
        end
    end
    self:update_suggest()
end

function TE:key(name, ctrl)
    local l = self.lines[self.cy]
    local ro = self.opts.readonly
    if name == "LEFT" then
        if self.cx > 0 then self.cx = self.cx - 1
        elseif self.cy > 1 then self.cy = self.cy - 1; self.cx = #self.lines[self.cy] end
    elseif name == "RIGHT" then
        if self.cx < #l then self.cx = self.cx + 1
        elseif self.cy < #self.lines then self.cy = self.cy + 1; self.cx = 0 end
    elseif name == "UP" then self.cy = self.cy - 1
    elseif name == "DOWN" then self.cy = self.cy + 1
    elseif name == "HOME" then
        if ctrl then self.cy = 1 end
        self.cx = 0
    elseif name == "END" then
        if ctrl then self.cy = #self.lines end
        self.cx = #self.lines[math.max(1, math.min(#self.lines, self.cy))]
    elseif name == "PAGE_UP" then self.cy = self.cy - (self.page or 20)
    elseif name == "PAGE_DOWN" then self.cy = self.cy + (self.page or 20)
    elseif ro then
        -- nothing else for read-only text
    elseif name == "BACKSPACE" then
        if self.cx > 0 then
            self.lines[self.cy] = l:sub(1, self.cx - 1) .. l:sub(self.cx + 1)
            self.cx = self.cx - 1
        elseif self.cy > 1 then
            local prev = self.lines[self.cy - 1]
            self.lines[self.cy - 1] = prev .. l
            table.remove(self.lines, self.cy)
            self.cy, self.cx = self.cy - 1, #prev
        end
        self.changed = true
    elseif name == "DELETE" then
        if self.cx < #l then self.lines[self.cy] = l:sub(1, self.cx) .. l:sub(self.cx + 2)
        elseif self.cy < #self.lines then
            self.lines[self.cy] = l .. self.lines[self.cy + 1]
            table.remove(self.lines, self.cy + 1)
        end
        self.changed = true
    elseif name == "ENTER" then
        local indent = l:match("^(%s*)")
        self.lines[self.cy] = l:sub(1, self.cx)
        table.insert(self.lines, self.cy + 1, indent .. l:sub(self.cx + 1))
        self.cy, self.cx = self.cy + 1, #indent
        self.changed = true
    elseif name == "TAB" then
        if not self:complete() then self:type("    ") end
    elseif name == "SPACE" and ctrl then
        self:update_suggest()
        return
    end
    if name == "ESCAPE" then self.suggest = nil
    elseif name ~= "TAB" then
        if name == "BACKSPACE" then self:update_suggest() else self.suggest = nil end
    end
    clamp(self)
end

function TE:scroll(lines)
    self.top = math.max(1, math.min(#self.lines, self.top + lines))
end
-- }}}

-- {{{ colours: the pieces of one line
function textedit.pieces(line, lang)
    local lua = lang == "lua"
    local keywords = lua and textedit.LUA_KEYWORDS or textedit.KEYWORDS
    local out = {}
    local i = 1
    local n = #line
    local function push(s, c) out[#out + 1] = { s, c } end
    while i <= n do
        local c = line:sub(i, i)
        if line:sub(i, i + 1) == (lua and "--" or "//") then push(line:sub(i), "comment"); break end
        if c == '"' or (lua and c == "'") then
            local j = i + 1
            while j <= n and line:sub(j, j) ~= c do
                if line:sub(j, j) == "\\" then j = j + 1 end
                j = j + 1
            end
            push(line:sub(i, j), "string"); i = j + 1
        elseif c == "'" then
            local j = line:find("'", i + 1, true) or n
            push(line:sub(i, j), "number"); i = j + 1
        elseif c:match("[%a_]") then
            local w = line:match("^[%w_]+", i)
            local after = line:sub(i + #w):match("^%s*%(")
            -- in Lua a block is a name before "{": coloured as a call
            local block = lua and line:sub(i + #w):match("^%s*[{%(\"]")
            push(w, keywords[w] and "keyword" or ((after and w:match("^%u")) or block) and "call" or "text")
            i = i + #w
        elseif c:match("%d") then
            local w = line:match("^[%w%.]+", i)
            push(w, "number"); i = i + #w
        else
            local w = line:match(lua and "^[^%w_\"'%-]+" or "^[^%w_\"'/]+", i) or c
            push(w, "text"); i = i + #w
        end
    end
    return out
end
-- }}}

-- {{{ drawing and the mouse
local GUTTER = 44

function TE:rows(box) return math.max(1, math.floor(box.h / (box.size + 4))) end

function TE:draw(render, box)
    local size = box.size or 14
    local lh = size + 4
    local rows = self:rows(box)
    self.page = rows - 1
    -- keep the cursor in view
    if self.cy < self.top then self.top = self.cy end
    if self.cy >= self.top + rows then self.top = self.cy - rows + 1 end
    render.ui_rect(box.x, box.y, box.w, box.h, COLOURS.back[1], COLOURS.back[2], COLOURS.back[3], 245)
    local space = math.max(1, math.floor(size / 10))
    for r = 0, rows - 1 do
        local li = self.top + r
        local line = self.lines[li]
        if not line then break end
        local y = box.y + 2 + r * lh
        if self.error and self.error.line == li then
            local e = COLOURS.error
            render.ui_rect(box.x, y - 1, box.w, lh, e[1], e[2], e[3], 255)
        elseif li == self.cy and not self.opts.readonly then
            render.ui_rect(box.x, y - 1, box.w, lh, COLOURS.line[1], COLOURS.line[2], COLOURS.line[3], 255)
        end
        local g = COLOURS.gutter
        render.ui_text(tostring(li), box.x + 4, y, size - 2, g[1], g[2], g[3], 255)
        local x = box.x + GUTTER
        for _, p in ipairs(textedit.pieces(line, self.opts.lang)) do
            if x > box.x + box.w then break end
            local c = COLOURS[p[2]]
            local s = p[1]:gsub("\t", "    ")
            render.ui_text(s, x, y, size, c[1], c[2], c[3], 255)
            x = x + render.ui_text_width(s, size) + space
        end
        if li == self.cy and not self.opts.readonly then
            local cx = box.x + GUTTER + render.ui_text_width(line:sub(1, self.cx), size) + (self.cx > 0 and space or 0)
            local c = COLOURS.cursor
            render.ui_rect(cx, y - 1, 2, lh - 2, c[1], c[2], c[3], 255)
            -- the words that complete what's typed (Tab takes the first)
            if self.suggest and #self.suggest > 0 then
                local py = y + lh
                for k, w in ipairs(self.suggest) do
                    if k > 8 then break end
                    local bg = k == 1 and COLOURS.popup_first or COLOURS.popup
                    local pw = render.ui_text_width(w, size) + 12
                    render.ui_rect(cx, py, pw, lh, bg[1], bg[2], bg[3], 250)
                    render.ui_text(w, cx + 6, py + 1, size, COLOURS.text[1], COLOURS.text[2], COLOURS.text[3], 255)
                    py = py + lh
                end
            end
        end
    end
    -- the error, under the text
    if self.error and self.error.message then
        local e = COLOURS.error_text
        render.ui_text("line " .. tostring(self.error.line or "?") .. ": " .. self.error.message, box.x + 4,
            box.y + box.h + 4, size - 1, e[1], e[2], e[3], 255)
    end
end

-- the cursor to the character nearest (mx, my); measure(s, size) the width
function TE:click(mx, my, box, measure)
    local size = box.size or 14
    local r = math.floor((my - box.y - 2) / (size + 4))
    self.cy = self.top + r
    clamp(self)
    local line = self.lines[self.cy]
    local best, bd = 0, math.huge
    for k = 0, #line do
        local x = box.x + GUTTER + measure(line:sub(1, k), size)
        local d = math.abs(x - mx)
        if d < bd then best, bd = k, d end
    end
    self.cx = best
end
-- }}}

return textedit
