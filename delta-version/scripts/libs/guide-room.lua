-- guide-room.lua - The two dated ledgers a reading-walk guide keeps in its own
-- room: what it made public, and what it kept to itself.
--
-- In plain terms: a guide (issue 065) owns a folder that the reader can look
-- into but not write to. Its words are its own and are written encrypted. To
-- share something, the guide lists it in the "made public" ledger with a short
-- note; what it keeps, it lists in the "kept to itself" ledger, so even the
-- private things are known to exist. Every entry names a real file in the room
-- and carries the moment it was written, and the ledgers are kept in time
-- order. Later edits and extensions get their own dated lines in a third
-- ledger, kept apart, so the record always reads as a line.
--
-- Ledger files are tab-separated text, one entry per line:
--   made-public.ledger     written <TAB> path <TAB> note
--   kept-to-itself.ledger  written <TAB> path
--   changes.ledger         when <TAB> path <TAB> edit|extension
-- "written" and "when" are local times as YYYY-MM-DDTHH:MM:SS, which sort as
-- they read. Paths are relative to the room and may not climb out of it.
--
-- This library writes; it does not decide who may. The room's ownership (a
-- separate system user, made with the person's consent by
-- reading-walk-guide-room.lua) is what keeps the reader from writing.

local M = {}

-- {{{ M.ledger_files
-- Which file holds which ledger, and how many fields its lines have. A table
-- rather than a chain of checks so a ledger is one line to add.
M.ledger_files = {
    public  = { file = "made-public.ledger",    fields = 3 },
    private = { file = "kept-to-itself.ledger", fields = 2 },
    changes = { file = "changes.ledger",        fields = 3 },
}
-- }}}

-- {{{ M.change_kinds
M.change_kinds = { edit = true, extension = true }
-- }}}

-- {{{ M.now()
-- The moment an entry is written. A function so a test can stand in a clock.
function M.now()
    return os.date("%Y-%m-%dT%H:%M:%S")
end
-- }}}

-- {{{ local function refuse()
local function refuse(message)
    error("guide-room: " .. message, 0)
end
-- }}}

-- {{{ local function file_exists()
local function file_exists(path)
    local handle = io.open(path, "r")
    if handle then handle:close() return true end
    return false
end
-- }}}

-- {{{ local function check_path()
-- A path inside the room: relative, no "..", no tabs or line breaks (which
-- would break the ledger's lines). Anything else is refused, not cleaned up.
local function check_path(path)
    if path == "" then refuse("an empty path names nothing") end
    if path:sub(1, 1) == "/" then refuse("paths are relative to the room: " .. path) end
    if path:find("[\t\n\r]") then refuse("a path may not hold a tab or line break") end
    for part in path:gmatch("[^/]+") do
        if part == ".." then refuse("a path may not climb out of the room: " .. path) end
    end
end
-- }}}

-- {{{ M.open(room_dir)
-- A room: its folder must exist. The ledgers need not yet.
function M.open(room_dir)
    local probe = io.open(room_dir .. "/.", "r")
    if not probe then refuse("no room at " .. room_dir) end
    probe:close()
    return { dir = room_dir }
end
-- }}}

-- {{{ local function append()
local function append(room, ledger, fields)
    local spec = M.ledger_files[ledger]
    local handle = io.open(room.dir .. "/" .. spec.file, "a")
    if not handle then refuse("cannot write the " .. ledger .. " ledger in " .. room.dir) end
    handle:write(table.concat(fields, "\t"), "\n")
    handle:close()
end
-- }}}

-- {{{ M.make_public(room, path, note)
-- Lists a file of the room as shared, with a plain-language note of what it is.
function M.make_public(room, path, note)
    check_path(path)
    if note:find("[\t\n\r]") then refuse("a note is one line, without tabs") end
    if not file_exists(room.dir .. "/" .. path) then refuse("no such file in the room: " .. path) end
    append(room, "public", { M.now(), path, note })
end
-- }}}

-- {{{ M.keep(room, path)
-- Lists a file of the room as kept to itself: known to exist, not shared.
function M.keep(room, path)
    check_path(path)
    if not file_exists(room.dir .. "/" .. path) then refuse("no such file in the room: " .. path) end
    append(room, "private", { M.now(), path })
end
-- }}}

-- {{{ M.record_change(room, path, kind)
-- Dates a later edit or extension of a file already listed.
function M.record_change(room, path, kind)
    check_path(path)
    if not M.change_kinds[kind] then refuse("a change is an edit or an extension, not " .. tostring(kind)) end
    if not file_exists(room.dir .. "/" .. path) then refuse("no such file in the room: " .. path) end
    append(room, "changes", { M.now(), path, kind })
end
-- }}}

-- {{{ M.read(room, ledger)
-- A ledger's entries, in file order: { written, path, note } (note and kind
-- share the third place; the private ledger has none). A missing ledger file
-- is an empty ledger: a new room has written nothing yet.
function M.read(room, ledger)
    local spec = M.ledger_files[ledger]
    if not spec then refuse("no ledger called " .. tostring(ledger)) end
    local entries = {}
    local handle = io.open(room.dir .. "/" .. spec.file, "r")
    if not handle then return entries end
    local number = 0
    for line in handle:lines() do
        number = number + 1
        local fields = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
        entries[#entries + 1] = { written = fields[1], path = fields[2], note = fields[3],
            field_count = #fields, line = number }
    end
    handle:close()
    return entries
end
-- }}}

-- {{{ M.check(room)
-- Every rule the ledgers keep, checked: each line has its fields, each time is
-- well formed and no earlier than the line before, each path is a real file in
-- the room, each change is an edit or an extension, and every changed file was
-- listed in one of the two ledgers first. Returns a list of problems (strings);
-- an empty list means the room is in order.
function M.check(room)
    local problems = {}
    local listed = {}
    local function problem(ledger, entry, text)
        problems[#problems + 1] = string.format("%s line %d: %s", M.ledger_files[ledger].file, entry.line, text)
    end
    for _, ledger in ipairs({ "public", "private", "changes" }) do
        local previous = ""
        for _, entry in ipairs(M.read(room, ledger)) do
            -- each rule is checked on its own, so one bad line reports all it breaks
            if entry.field_count ~= M.ledger_files[ledger].fields then
                problem(ledger, entry, "has " .. entry.field_count .. " fields, needs " .. M.ledger_files[ledger].fields)
            end
            if not (entry.written or ""):match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d$") then
                problem(ledger, entry, "time is not YYYY-MM-DDTHH:MM:SS: " .. tostring(entry.written))
            elseif entry.written < previous then
                problem(ledger, entry, "out of time order (" .. entry.written .. " after " .. previous .. ")")
            else
                previous = entry.written
            end
            local path_ok = pcall(check_path, entry.path or "")
            if not path_ok then
                problem(ledger, entry, "path is not inside the room: " .. tostring(entry.path))
            elseif not file_exists(room.dir .. "/" .. entry.path) then
                problem(ledger, entry, "names a file that is not in the room: " .. entry.path)
            end
            if ledger == "changes" then
                if not M.change_kinds[entry.note or ""] then
                    problem(ledger, entry, "change is not an edit or an extension: " .. tostring(entry.note))
                end
                if entry.path and not listed[entry.path] then
                    problem(ledger, entry, "changes a file never listed as public or kept: " .. entry.path)
                end
            elseif entry.path then
                listed[entry.path] = true
            end
        end
    end
    return problems
end
-- }}}

return M
