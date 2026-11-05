--[[
output.lua - a build folder's registration, written in its forms (issue W02c)

Every map converted into a build folder leaves its rows in
World/Maps/<dir>/registration.lua (wowbuild.registration). After each
conversion this gathers the rows of every map the folder holds and writes
them out in each form something reads:

  the loose overlay (the W client reads the build folder as one, its 105a)
    DBFilesClient/<Table>.dbc       only these maps' rows: nothing of
                                    Blizzard's is written; the W client
                                    reads a table per row, the overlay's
                                    first (its 106)
    map.lua                         which map Test Map opens: id, directory,
                                    start, the WC3 -> WoW transform (data)
    world/creatures-<map id>.tsv    the spawns, as the W client's --world
                                    folder holds them (its 035-creatures.h)
  the server (AzerothCore)
    server/dbc.sql                  these maps' rows for the world database's
                                    <table>_dbc copies, which the server
                                    reads over its DBC files
    server/dbc/<Table>.dbc          the stock tables with these maps' rows
                                    added, for the server's dbc folder;
                                    only when the stock tables are given
  the stock client and AzerothCore's extractors (W02d)
    patch-W.MPQ                     every map's ground files and loading
                                    screen, and (when the stock tables are
                                    given) the merged tables: a patch
                                    archive replaces a table whole, so it
                                    must hold the stock rows too

The stock tables are the player's own: a folder of the client's .dbc files
(AzerothCore's extracted dbc folder is one). They are read at build time
and their rows land only in the build folder, never in this repository.

    local output = require("wowbuild.output")
    local out = output.write(build_dir, { stock_dbc = dir, current = "WC3_DAoW_2_1" })
]]

local dbc = require("wowbuild.dbc")
local registration = require("wowbuild.registration")

local output = {}

output.PATCH = "patch-W.MPQ"
output.MAP_FILE = "map.lua"
output.SERVER_SQL = "server/dbc.sql"
output.OWNER_STOCK_DBC = "/mnt/mtwo/games/azeroth-core/data-files/dbc"

-- {{{ helpers
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function write_file(path, bytes)
    local dir = path:match("^(.*)/[^/]*$")
    if dir then os.execute("mkdir -p " .. quote(dir)) end
    local tmp = path .. ".part"
    local f, err = io.open(tmp, "wb")
    if not f then error("can't write " .. path .. ": " .. tostring(err), 0) end
    f:write(bytes)
    f:close()
    local ok, e = os.rename(tmp, path)
    if not ok then error("can't write " .. path .. ": " .. tostring(e), 0) end
end
local function list_dir(dir)
    local out = {}
    local p = io.popen("ls -1 " .. quote(dir) .. " 2>/dev/null")
    if p then for name in p:lines() do out[#out + 1] = name end p:close() end
    table.sort(out)
    return out
end
-- the stock table's file in a folder, in any capitals
local function find_stock(dir, name)
    if not dir then return nil end
    for _, f in ipairs(list_dir(dir)) do
        if f:lower() == (name .. ".dbc"):lower() then return dir .. "/" .. f end
    end
end
-- }}}

-- {{{ output.stock_dir: the folder of stock tables to merge with, or nil
function output.stock_dir(given)
    if given == false then return nil end
    if given then return given end
    local f = io.open(output.OWNER_STOCK_DBC .. "/Map.dbc", "rb")
    if f then f:close() return output.OWNER_STOCK_DBC end
end
-- }}}

-- {{{ output.gather: every registered map's rows, table by table, ordered by id
function output.gather(build_dir)
    local regs = registration.in_build(build_dir)
    local list = {}
    for _, r in pairs(regs) do list[#list + 1] = r end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    local tables = {}
    for _, name in ipairs(dbc.TABLES) do
        local rows = {}
        for _, r in ipairs(list) do
            for _, row in ipairs(r.rows[name] or {}) do rows[#rows + 1] = row end
        end
        table.sort(rows, function(a, b) return a.ID < b.ID end)
        tables[name] = rows
    end
    return list, tables
end
-- }}}

-- {{{ output.used_area_bits: the stock table's AreaBits outside this project's ids
function output.stock_area_bits(stock_dir)
    local path = find_stock(stock_dir, "AreaTable")
    local bytes = path and read_file(path)
    if not bytes then return nil end
    local ok, ids = pcall(dbc.column, bytes, 1)
    if not ok then return nil end
    local bits = dbc.column(bytes, 4)
    local used = {}
    for i, id in ipairs(ids) do
        if not registration.in_scheme("area", id) then used[bits[i]] = true end
    end
    return used
end
-- }}}

-- {{{ the server's SQL
local function server_sql(list, tables)
    local o = {}
    local function w(line) o[#o + 1] = line end
    local names = {}
    for _, r in ipairs(list) do names[#names + 1] = string.format("%s (map %d)", r.directory, r.ids.map) end
    w("-- W02c: the client tables' rows of the maps in this build folder (src/wowbuild/output.lua)")
    w("-- " .. table.concat(names, ", "))
    w("-- For AzerothCore's world database: its <table>_dbc tables hold rows the server reads over its")
    w("-- DBC files at start. Values are in each table's own column order (unchecked against the schema).")
    w("-- REPLACE keeps it runnable again; a row a map no longer uses stays until deleted by hand.")
    for _, name in ipairs(dbc.TABLES) do
        local layout = dbc.LAYOUTS[name]
        local rows = tables[name]
        if layout.server_table and #rows > 0 then
            w("")
            w(string.format("-- {{{ %s (%s.dbc): %d row%s", layout.server_table, name, #rows, #rows == 1 and "" or "s"))
            w(string.format("REPLACE INTO `%s` VALUES", layout.server_table))
            for k, row in ipairs(rows) do
                w("  (" .. table.concat(dbc.sql_values(name, row), ", ") .. ")" .. (k < #rows and "," or ";"))
            end
            w("-- }}}")
        end
    end
    w("")
    return table.concat(o, "\n")
end
-- }}}

-- {{{ patch-W.MPQ
local function write_patch(build_dir, list, merged, files_out)
    local stormlib = require("mpq.stormlib")
    local entries = {}
    for _, r in ipairs(list) do
        local rel = "World/Maps/" .. r.directory
        for _, f in ipairs(list_dir(build_dir .. "/" .. rel)) do
            local lower = f:lower()
            if lower:match("%.wdt$") or lower:match("%.wdl$") or lower:match("%.adt$") or lower:match("%.blp$") then
                entries[#entries + 1] = { name = "World\\Maps\\" .. r.directory .. "\\" .. f, path = build_dir .. "/" .. rel .. "/" .. f }
            end
        end
    end
    for _, name in ipairs(dbc.TABLES) do
        if merged[name] then entries[#entries + 1] = { name = dbc.file(name), bytes = merged[name] } end
    end
    local path = build_dir .. "/" .. output.PATCH
    local tmp = path .. ".part"
    os.remove(tmp)
    local made, archive = pcall(stormlib.create, tmp, #entries * 2 + 16, nil, 2)
    if not made then
        -- no StormLib here: the rest of the build stands without the archive
        if tostring(archive):find("StormLib not found", 1, true) then return nil, tostring(archive) end
        error("patch-W.MPQ: " .. tostring(archive), 0)
    end
    local ok, err = pcall(function()
        for _, e in ipairs(entries) do
            archive:write(e.name, e.bytes or read_file(e.path) or error("can't read " .. e.path, 0))
        end
    end)
    archive:close()
    if not ok then os.remove(tmp) error("patch-W.MPQ: " .. tostring(err), 0) end
    local renamed, e = os.rename(tmp, path)
    if not renamed then error("can't write " .. path .. ": " .. tostring(e), 0) end
    local names = {}
    for _, e2 in ipairs(entries) do names[#names + 1] = e2.name end
    local f = io.open(path, "rb")
    local size = f and f:seek("end") or 0
    if f then f:close() end
    files_out[#files_out + 1] = { path = output.PATCH, bytes = size }
    return names
end
-- }}}

-- {{{ output.write
-- opts: stock_dbc (a folder of stock tables; nil: the owner's AzerothCore
-- dbc folder when it is there; false: none), current (the directory just
-- converted, for map.lua), patch (false: no patch-W.MPQ), files (the
-- report's file list, added to). Returns what was written, for the report.
function output.write(build_dir, opts)
    opts = opts or {}
    local files = opts.files or {}
    local list, tables = output.gather(build_dir)
    local done = { maps = {}, tables = {}, warnings = {}, notes = {}, stock = nil }
    for _, r in ipairs(list) do done.maps[#done.maps + 1] = { directory = r.directory, slot = r.slot, map = r.ids.map } end

    -- the overlay's tables: these maps' rows only
    for _, name in ipairs(dbc.TABLES) do
        local bytes = dbc.write(name, tables[name])
        local rel = "DBFilesClient/" .. name .. ".dbc"
        write_file(build_dir .. "/" .. rel, bytes)
        files[#files + 1] = { path = rel, bytes = #bytes }
        done.tables[name] = { rows = #tables[name], checked = dbc.LAYOUTS[name].checked }
    end

    -- the server's SQL copy
    local sql = server_sql(list, tables)
    write_file(build_dir .. "/" .. output.SERVER_SQL, sql)
    files[#files + 1] = { path = output.SERVER_SQL, bytes = #sql }

    -- the stock tables, merged
    local stock_dir = output.stock_dir(opts.stock_dbc)
    local merged = {}
    if stock_dir then
        done.stock = { folder = stock_dir, tables = {} }
        for _, name in ipairs(dbc.TABLES) do
            local path = find_stock(stock_dir, name)
            local bytes = path and read_file(path)
            if not bytes then
                done.stock.tables[name] = { missing = true }
                done.warnings[#done.warnings + 1] = "no stock " .. name .. ".dbc in " .. stock_dir .. ": left out of the merged tables"
            else
                local kind = registration.TABLE_KIND[name]
                local m, n = dbc.merge(name, bytes, tables[name], function(id) return registration.in_scheme(kind, id) end)
                merged[name] = m
                done.stock.tables[name] = { stock = n.stock, dropped = n.dropped, ours = n.ours }
                if n.dropped > 0 then
                    done.warnings[#done.warnings + 1] = string.format("%s.dbc: %d stock rows inside W02c's ids replaced (an earlier build's, or a clash: ids %s)",
                        name, n.dropped, table.concat(n.dropped_ids, " ", 1, math.min(8, #n.dropped_ids)))
                end
                if dbc.LAYOUTS[name].server_table then
                    local rel = "server/dbc/" .. name .. ".dbc"
                    write_file(build_dir .. "/" .. rel, m)
                    files[#files + 1] = { path = rel, bytes = #m, stock_rows = true }
                end
            end
        end
    else
        -- a warning unless none was asked for
        local list_for = opts.stock_dbc == false and done.notes or done.warnings
        list_for[#list_for + 1] = "no stock tables (--stock-dbc): server/dbc/ not written, and patch-W.MPQ holds no tables, so the stock client and the extractors don't know these maps yet"
    end

    -- patch-W.MPQ
    if opts.patch ~= false then
        local names, why = write_patch(build_dir, list, merged, files)
        if names then
            done.patch = { path = output.PATCH, files = names, tables = next(merged) ~= nil }
        else
            -- an older build's archive would no longer match the folder
            os.remove(build_dir .. "/" .. output.PATCH)
            done.warnings[#done.warnings + 1] = "patch-W.MPQ not written (an older one removed): " .. why
        end
    end
    return done, list, tables
end
-- }}}

return output
