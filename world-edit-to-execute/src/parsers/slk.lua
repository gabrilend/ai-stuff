--[[
slk.lua - SYLK ("SLK") spreadsheet parser

Warcraft III keeps its stock object tables (Units\UnitData.slk,
Units\AbilityData.slk, …) in SYLK, a line-based text spreadsheet format:

  ID;PWXL;N;E            file header
  B;X95;Y804;D0          bounds: 95 columns, 804 rows
  C;X1;Y1;K"alias"       a cell: column 1, row 1, value "alias"
  C;X2;K"code"           a cell that leaves out Y keeps the previous row
  C;Y2;X1;K"AHbz"        fields may come in any order
  C;X11;K4               an unquoted value is a number
  E                      end

Row 1 holds the column names; column 1 holds each row's id. Other record
kinds (F formatting, P, O, …) carry nothing the game data needs and are
skipped. Inside a quoted value, ";;" stands for one ";".

Usage:
  local slk = require("parsers.slk")
  local sheet = slk.parse(text)
  sheet.columns      -- { [1] = "alias", [2] = "code", ... }
  sheet.rows["AHbz"] -- { alias = "AHbz", code = "AHbz", levels = 3, ... }
  sheet.order        -- ids in file order

Issue: issues/112c-route-a-stock-rows-merged-with-map-objects.md
]]

local M = {}

-- {{{ local function decode_value
-- A quoted value is text (";;" meaning ";"); anything else is a number when
-- it reads as one, otherwise kept as text.
local function decode_value(raw)
    if raw:sub(1, 1) == '"' then
        local inner = raw:sub(2)
        if inner:sub(-1) == '"' then
            inner = inner:sub(1, -2)
        end
        return (inner:gsub(";;", ";"))
    end
    return tonumber(raw) or raw
end
-- }}}

-- {{{ local function parse_cell
-- Returns x, y (either may be nil when left out) and the value (nil when the
-- record has no K field) for a "C;..." record.
local function parse_cell(line)
    local x, y, value
    local pos = 3                                  -- after "C;"
    while pos <= #line do
        local kind = line:sub(pos, pos)
        if kind == "K" then
            value = decode_value(line:sub(pos + 1))
            break
        end
        local stop = line:find(";", pos, true) or (#line + 1)
        local field = line:sub(pos + 1, stop - 1)
        if kind == "X" then
            x = tonumber(field)
        elseif kind == "Y" then
            y = tonumber(field)
        end
        pos = stop + 1
    end
    return x, y, value
end
-- }}}

-- {{{ function M.parse
-- Returns { columns, rows, order } or raises an error naming the line.
function M.parse(text)
    local cells = {}          -- cells[y][x] = value
    local max_y = 0
    local x, y = 1, 1
    local line_number = 0
    local seen_header = false

    for line in text:gmatch("[^\r\n]+") do
        line_number = line_number + 1
        local kind = line:sub(1, 1)
        if kind == "I" and line:sub(1, 3) == "ID;" then
            seen_header = true
        elseif kind == "C" and line:sub(2, 2) == ";" then
            local cx, cy, value = parse_cell(line)
            x = cx or x
            y = cy or y
            if value ~= nil then
                cells[y] = cells[y] or {}
                cells[y][x] = value
                if y > max_y then max_y = y end
            end
        elseif kind == "E" and #line == 1 then
            break
        end
    end
    if not seen_header then
        error("not an SLK file (no ID; header line)")
    end

    local columns = {}
    for cx, name in pairs(cells[1] or {}) do
        columns[cx] = tostring(name)
    end
    if not columns[1] then
        error("SLK file has no column names in row 1")
    end

    local rows, order = {}, {}
    for cy = 2, max_y do
        local row_cells = cells[cy]
        if row_cells and row_cells[1] ~= nil then
            local id = tostring(row_cells[1])
            local row = rows[id]
            if not row then
                row = {}
                rows[id] = row
                order[#order + 1] = id
            end
            for cx, value in pairs(row_cells) do
                local name = columns[cx]
                if name then
                    row[name] = value
                end
            end
        end
    end
    return { columns = columns, rows = rows, order = order }
end
-- }}}

return M
