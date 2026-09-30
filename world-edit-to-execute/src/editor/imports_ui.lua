--[[
The Import Manager's Panel (Issue 908)

Opened from the toolbar ("Files"), over the whole view:

  left     the map's files by kind (All, models, textures, sounds, ...,
           Unused), paged, each with its size; unnamed ones as StormLib
           names them
  right    the chosen file: name (click to rename: type the new one, Enter),
           kind, size, what reading it as its kind says, what uses it; a
           texture's picture; Export (to the path typed, beside the map by
           default), Delete
  bottom   Import: a file on disk (its path typed) under the name typed
           (war3mapImported\ and its own name if none)

    local fui = require("editor.imports_ui").new(E, w, h)
    fui:update(input); fui:draw(render)
]]

local imports = require("editor.imports")

local imports_ui = {}
imports_ui.LEFT = 420
imports_ui.PAGE = 24
imports_ui.PREVIEW = 128
imports_ui.FILTERS = { "all", "model", "texture", "sound", "script", "data", "other", "unused" }

local FUI = {}
FUI.__index = FUI

local C = {
    panel = { 22, 24, 30 }, edge = { 70, 74, 86 }, button = { 44, 48, 58 }, active = { 90, 120, 60 },
    text = { 225, 225, 215 }, dim = { 140, 140, 130 }, gold = { 240, 200, 90 }, head = { 130, 170, 230 },
    warn = { 240, 120, 90 }, ok = { 140, 210, 120 }, new = { 150, 200, 255 },
}

function imports_ui.new(E, w, h)
    local self = setmetatable({ E = E, w = w, h = h, filter = "all", page = 0 }, FUI)
    E:imports()
    self:layout()
    return self
end

local function short(s, n)
    s = tostring(s)
    return #s > n and (".." .. s:sub(-(n - 2))) or s
end

local function size_text(n)
    if n >= 1024 * 1024 then return string.format("%.1f MB", n / 1048576) end
    if n >= 1024 then return string.format("%d KB", math.floor(n / 1024 + 0.5)) end
    return n .. " B"
end

-- {{{ layout
function FUI:shown()
    local out = {}
    for _, f in ipairs(self.E:imports()) do
        if self.filter == "all" or f.kind == self.filter or (self.filter == "unused" and #f.users == 0) then
            out[#out + 1] = f
        end
    end
    return out
end

function FUI:layout()
    local E = self.E
    local b = {}
    self.buttons, self.labels = b, {}
    local function add(x, y, w, label, action, arg, active, colour)
        b[#b + 1] = { x = x, y = y, w = w, h = 22, label = label, action = action, arg = arg, active = active, colour = colour }
    end
    local function label(x, y, s, c) self.labels[#self.labels + 1] = { x = x, y = y, s = s, c = c or C.text } end
    local f = self.field
    local function field(x, y, w, key, text)
        local editing = f and f.key == key
        add(x, y, w, editing and (short(f.buf, math.floor(w / 8) - 1) .. "_") or short(text, math.floor(w / 8)),
            "field", { key = key, text = text }, editing)
    end
    -- the filters
    local x = 8
    for i, k in ipairs(imports_ui.FILTERS) do
        add(x, 46 + math.floor((i - 1) / 4) * 26, 100, k, "filter", k, self.filter == k)
        x = (i % 4 == 0) and 8 or (x + 104)
    end
    local list = self:shown()
    -- as many lines as fit above the import row
    self.rows = math.max(4, math.min(imports_ui.PAGE, math.floor((self.h - 28 - 128 - 8) / 24)))
    local pages = math.max(1, math.ceil(#list / self.rows))
    self.page = math.max(0, math.min(self.page, pages - 1))
    local total = 0
    for _, it in ipairs(list) do total = total + it.size end
    label(8, 104, string.format("%d files, %s   page %d/%d", #list, size_text(total), self.page + 1, pages), C.head)
    add(imports_ui.LEFT - 84, 100, 36, "<", "page", -1)
    add(imports_ui.LEFT - 44, 100, 36, ">", "page", 1)
    local y = 128
    for k = 1, self.rows do
        local it = list[self.page * self.rows + k]
        if not it then break end
        add(8, y, imports_ui.LEFT - 16, short(it.name, 36) .. "  " .. size_text(it.size), "pick", it, it == self.sel,
            it.added and C.new or (it.unnamed and C.dim or nil))
        y = y + 24
    end
    -- the chosen file
    local rx = imports_ui.LEFT + 8
    local it = self.sel
    if it then
        field(rx, 46, self.w - rx - 8, "rename", it.name)
        label(rx, 76, string.format("%s, %s%s", it.kind, size_text(it.size), it.added and ", new here" or ""), C.text)
        local v = self.valid
        if v then label(rx, 96, v.message, v.status == "ok" and C.ok or (v.status == "warn" and C.gold or C.warn)) end
        label(rx, 122, #it.users > 0 and "Used by:" or "Nothing found uses it", C.head)
        for i, u in ipairs(it.users) do
            if i > 8 then label(rx + 10, 122 + i * 18, string.format("... and %d more", #it.users - 8), C.dim) break end
            label(rx + 10, 122 + i * 18, u, C.text)
        end
        local by = 300
        field(rx, by, self.w - rx - 8 - 196, "export", self.export_path or self:default_export(it))
        add(self.w - 8 - 188, by, 90, "Export", "export")
        add(self.w - 8 - 90, by, 90, "Delete", "delete")
        self.preview_at = { x = rx, y = by + 34 }
    end
    -- importing
    local iy = self.h - 28 - 60
    label(rx, iy - 22, "Import a file", C.head)
    field(rx, iy, 420, "import_path", self.import_path or "(path on disk)")
    field(rx + 428, iy, self.w - rx - 428 - 8 - 98, "import_name", self.import_name or "(name in the map)")
    add(self.w - 8 - 90, iy, 90, "Import", "import")
    return b
end

function FUI:default_export(it)
    local dir = self.E.path:match("^(.*)/[^/]*$") or "."
    return dir .. "/" .. (it.name:match("([^\\/]+)$") or it.name)
end
-- }}}

-- {{{ actions
function FUI:choose(it)
    self.sel = it
    self.export_path = nil
    self.valid = it and self.E:validate_import(it.name)
    self.preview = nil
    if it and it.kind == "texture" then
        local data = self.E:import_data(it.name)
        local ok, img = pcall(function()
            if it.name:lower():match("%.blp$") then return require("parsers.blp").decode(data, 0) end
            if it.name:lower():match("%.tga$") then return require("parsers.tga").decode(data) end
        end)
        if ok and img and img.rgba then self.preview = img end
    end
end

function FUI:commit()
    local f = self.field
    self.field = nil
    if not f then return end
    local E = self.E
    if f.key == "rename" and self.sel and f.buf ~= "" and f.buf ~= self.sel.name then
        local ok, why = E:rename_import(self.sel.name, f.buf)
        if ok then self:choose(E:import_named(f.buf)) else E:say("Not renamed: " .. tostring(why)) end
    elseif f.key == "export" then self.export_path = f.buf ~= "" and f.buf or nil
    elseif f.key == "import_path" then self.import_path = f.buf ~= "" and f.buf or nil
    elseif f.key == "import_name" then self.import_name = f.buf ~= "" and f.buf or nil
    end
end

function FUI:press(b)
    local E = self.E
    local a, arg = b.action, b.arg
    if self.field and a ~= "field" then self:commit() end
    if a == "filter" then self.filter, self.page = arg, 0
    elseif a == "page" then self.page = self.page + arg
    elseif a == "pick" then self:choose(arg)
    elseif a == "field" then
        if self.field then self:commit() end
        local text = arg.text
        if text:match("^%(") then text = "" end
        self.field = { key = arg.key, buf = text, fresh = true }
    elseif a == "export" and self.sel then
        local path = self.export_path or self:default_export(self.sel)
        local ok, why = E:export_import(self.sel.name, path)
        E:say(ok and ("Exported to " .. path) or ("Not exported: " .. tostring(why)))
    elseif a == "delete" and self.sel then
        E:delete_import(self.sel.name)
        self:choose(nil)
    elseif a == "import" then
        if not self.import_path then E:say("Type the path of a file to import first")
        else
            local ok, why = E:import_file(self.import_path, self.import_name)
            if ok then
                local name = self.import_name or ("war3mapImported\\" .. self.import_path:match("([^/\\]+)$"))
                E:say("Imported " .. name)
                self:choose(E:import_named(name))
            else E:say("Not imported: " .. tostring(why)) end
        end
    end
    self:layout()
end

local function inside(b, x, y) return x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h end

function FUI:update(input)
    local used = false
    if self.field then
        used = true
        local f = self.field
        if (input.chars or "") ~= "" then f.buf = (f.fresh and "" or f.buf) .. input.chars; f.fresh = false end
        for _, k in ipairs(input.keys or {}) do
            if k == "BACKSPACE" then f.buf = f.fresh and "" or f.buf:sub(1, -2); f.fresh = false
            elseif k == "ENTER" then self:commit()
            elseif k == "ESCAPE" then self.field = nil end
        end
        self:layout()
    elseif input.wheel and input.wheel ~= 0 then
        self.page = self.page - (input.wheel > 0 and 1 or -1)
        self:layout()
    end
    if input.lp then
        for _, b in ipairs(self.buttons) do
            if inside(b, input.mx or 0, input.my or 0) then self:press(b); return true end
        end
    end
    return used
end

function FUI:button(label)
    for _, b in ipairs(self.buttons) do if b.label == label then return b end end
end
-- }}}

-- {{{ drawing
-- a texture scaled to one fixed-size picture (one image slot, updated)
local function scaled(img, n)
    local out = {}
    local w, h, src = img.width, img.height, img.rgba
    for y = 0, n - 1 do
        local sy = math.floor(y * h / n)
        for x = 0, n - 1 do
            local sx = math.floor(x * w / n)
            local at = (sy * w + sx) * 4 + 1
            out[#out + 1] = src:sub(at, at + 3)
        end
    end
    return table.concat(out)
end

function FUI:draw(render)
    local function rect(x, y, w, h, c, a) render.ui_rect(x, y, w, h, c[1], c[2], c[3], a or 255) end
    rect(0, 38, self.w, self.h - 66, C.panel, 250)
    rect(imports_ui.LEFT, 38, 1, self.h - 66, C.edge)
    for _, l in ipairs(self.labels) do render.ui_text(l.s, l.x, l.y, 14, l.c[1], l.c[2], l.c[3], 255) end
    for _, b in ipairs(self.buttons) do
        rect(b.x, b.y, b.w, b.h, b.active and C.active or C.button)
        render.ui_frame(b.x, b.y, b.w, b.h, 1, C.edge[1], C.edge[2], C.edge[3], 255)
        local c = b.colour or C.text
        render.ui_text(b.label, b.x + 6, b.y + 5, 13, c[1], c[2], c[3], 255)
    end
    if self.preview and self.preview_at and render.ui_image_load then
        local n = imports_ui.PREVIEW
        if self.preview_shown ~= self.preview then
            local px = scaled(self.preview, n)
            if not self.preview_id then self.preview_id = render.ui_image_load(n, n, px)
            else render.ui_image_update(self.preview_id, n, n, px) end
            self.preview_shown = self.preview
        end
        if self.preview_id and self.preview_id >= 0 then
            local p = self.preview_at
            rect(p.x - 1, p.y - 1, n * 2 + 2, n * 2 + 2, C.edge)
            render.ui_image(self.preview_id, p.x, p.y, n * 2, n * 2)
        end
    end
end
-- }}}

return imports_ui
