-- guide-trail.lua - The guide's record of one reader's walk, written only
-- encrypted, into the guide's own room.
--
-- In plain terms: while a guide walks a reader through a project it notes
-- what happened -- which stop, what the reader chose. Those notes are the
-- guide's words, so each one is encrypted with the guide's own key before it
-- touches the disk, one encrypted note per line. The trail file is listed in
-- the guide's "kept to itself" ledger when it is begun, and every note added
-- later is dated in the changes ledger as an extension. The key lives in the
-- room too, readable only by the guide's account (the room maker gives the
-- room to that account; the key file is made unreadable to anyone else).
--
-- Entry text is free-form; the guide (issue 065g) writes lines like
-- "stop 12 more" or "stop 13 skip". Nothing here reads them.

local M = {}

-- {{{ local libraries
local HERE = debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or "."
local room_library = dofile(HERE .. "/guide-room.lua")
local cipher = dofile(HERE .. "/guide-cipher.lua")
M.room_library, M.cipher = room_library, cipher
-- }}}

-- {{{ local KEY_FILE
local KEY_FILE = "guide.key"
-- }}}

-- {{{ local function refuse()
local function refuse(message)
    error("guide-trail: " .. message, 0)
end
-- }}}

-- {{{ local function file_exists()
local function file_exists(path)
    local handle = io.open(path, "r")
    if handle then handle:close() return true end
    return false
end
-- }}}

-- {{{ M.key_for(room)
-- The guide's key: read from the room, or made and kept there on first use.
-- The key file's permissions are set to owner-only before the key is written
-- into it, so there is no moment when another account could read it.
function M.key_for(room)
    local path = room.dir .. "/" .. KEY_FILE
    if file_exists(path) then
        local handle = io.open(path, "rb")
        if not handle then refuse("the key exists but this account cannot read it: " .. path) end
        local key = handle:read("*a")
        handle:close()
        if #key < 16 then refuse("the key in " .. path .. " is too short") end
        return key
    end
    local empty = io.open(path, "wb")
    if not empty then refuse("cannot make a key in " .. room.dir) end
    empty:close()
    local status = os.execute("chmod 600 '" .. path:gsub("'", "'\\''") .. "'")
    if status ~= 0 and status ~= true then refuse("cannot make the key private: " .. path) end
    local key = cipher.make_key()
    local handle = io.open(path, "wb")
    handle:write(key)
    handle:close()
    room_library.keep(room, KEY_FILE)
    return key
end
-- }}}

-- {{{ M.open(room_dir)
-- A trail writer for a room: the room and the guide's key.
function M.open(room_dir)
    local room = room_library.open(room_dir)
    return { room = room, key = M.key_for(room) }
end
-- }}}

-- {{{ local function trail_path()
local function trail_path(walk_id)
    if not walk_id:match("^[%w%-]+$") then refuse("a walk id is letters, digits and dashes: " .. walk_id) end
    return "trail-" .. walk_id .. ".trail"
end
-- }}}

-- {{{ M.note(trail, walk_id, text)
-- One encrypted note added to a walk's trail. The first note begins the file
-- and lists it as kept; each later one is dated as an extension.
function M.note(trail, walk_id, text)
    local relative = trail_path(walk_id)
    local path = trail.room.dir .. "/" .. relative
    local is_new = not file_exists(path)
    local handle = io.open(path, "a")
    if not handle then refuse("cannot write the trail " .. path) end
    handle:write(cipher.to_hex(cipher.encrypt(trail.key, text)), "\n")
    handle:close()
    -- a new trail is listed once; every later note is an extension of it
    if is_new then room_library.keep(trail.room, relative)
    else room_library.record_change(trail.room, relative, "extension") end
end
-- }}}

-- {{{ M.read(trail, walk_id)
-- A walk's notes, decrypted, in order. Only the key's holder can do this.
function M.read(trail, walk_id)
    local path = trail.room.dir .. "/" .. trail_path(walk_id)
    local notes = {}
    local handle = io.open(path, "r")
    if not handle then return notes end
    for line in handle:lines() do
        notes[#notes + 1] = cipher.decrypt(trail.key, cipher.from_hex(line))
    end
    handle:close()
    return notes
end
-- }}}

return M
