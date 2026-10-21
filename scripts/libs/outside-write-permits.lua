-- outside-write-permits.lua
--
-- The permissions a person can give for a write outside a session's folder,
-- kept where no agent can write them, for the write gate
-- (harness-hooks/refuse-outside-writes) and the hook that reads the person's
-- answer (harness-hooks/answer-outside-write). Issue 043, steps 9-12.
--
-- In plain terms: when the gate refuses a write it could pin down, it files
-- a request -- which places, which session, which project, and the one
-- question the agent must put to the person, with four answers. The owner,
-- 2026-10-21: "yes is one single write, this time is until session closes,
-- always is forever, and no means no", each reaching "the file's folder":
--   Yes        a grant the session spends on its next write needing no
--              more than those places
--   This time  the folders on a list only that session's gate reads,
--              until it ends
--   Always     the folders on a list read by the gate of every session
--              working in the same project folder -- never every session:
--              "it should never give global permissions"
--   No         nothing
--
-- Where things live:
--   requests  <state>/requests/<id>.json            in RAM; 30 minutes
--   grants    <state>/grants/<session>/<id>.json    in RAM; 30 minutes
--   session   <state>/session-allowed/<session>     in RAM, until the
--             session ends (forget-session-permits); lines
--             "<file|folder>\t<place>"
--   always    <allowed file>, on disk; lines
--             "<project>\t<file|folder>\t<place>"
-- <state> is /dev/shm/claude-outside-writes and <allowed file> is
-- ~/.claude/outside-write-allowed-folders; both are outside every project
-- folder, so the gate itself refuses an agent writing them. The environment
-- variables OUTSIDE_WRITE_STATE and OUTSIDE_WRITE_ALLOWED move them, for the
-- tests only. A "project" is the session's own folder as a real place, the
-- same folder the gate measures inside by. A "file" line covers exactly its
-- place; a "folder" line covers it and everything below.
--
-- A request file holds (JSON):
--   id          string   8 hex digits from /dev/urandom
--   session_id  string   the session that was refused
--   project     string   that session's folder, as a real place
--   places      list of strings, real places (links followed)
--   questions   list of the one question to ask, as the question tool
--               takes them: { question = string, header = string,
--               multiSelect = false, options = list of { label, description } }
--   made        number   seconds since 1970
-- A grant file holds { places = list of strings, made = number }.
--
-- LuaJIT compatible; no Lua 5.4 syntax.

local permits = {}

local LIFETIME_SECONDS = 30 * 60

local STATE = os.getenv("OUTSIDE_WRITE_STATE") or "/dev/shm/claude-outside-writes"
local ALLOWED = os.getenv("OUTSIDE_WRITE_ALLOWED") or ((os.getenv("HOME") or "") .. "/.claude/outside-write-allowed-folders")

-- {{{ local function shell_quote()
local function shell_quote(word)
    return "'" .. word:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local f = io.open(path, "r")
    -- no such file
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function write_file()
-- Writes whole, through a temporary name and a rename, so a reader never
-- sees half a file. Returns true, or nil and a message.
local function write_file(path, text)
    local folder = path:match("^(.*)/[^/]*$")
    os.execute("mkdir -p -m 700 " .. shell_quote(folder))
    local temporary = path .. ".writing"
    local f, err = io.open(temporary, "w")
    if not f then return nil, err end
    f:write(text)
    f:close()
    local ok, rename_err = os.rename(temporary, path)
    if not ok then return nil, rename_err end
    return true
end
-- }}}

-- {{{ local function new_id()
local function new_id()
    local f = io.open("/dev/urandom", "rb")
    local bytes = f:read(4)
    f:close()
    return (bytes:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end
-- }}}

-- {{{ local function folder_of()
-- The folder an Always answer adds for a place: the place itself when it is
-- a folder, otherwise the folder it is in.
local function folder_of(place)
    local is_folder = os.execute("test -d " .. shell_quote(place))
    -- an existing folder stands for itself
    if is_folder == 0 or is_folder == true then return place end
    return place:match("^(.*)/[^/]*$") or "/"
end
-- }}}

-- {{{ local function is_inside()
local function is_inside(place, folder)
    if folder == "/" then return place:sub(1, 1) == "/" end
    return place == folder or place:sub(1, #folder + 1) == folder .. "/"
end
-- }}}

-- {{{ function permits.folders_for()
-- The distinct folders an Always answer would add, for a list of places.
function permits.folders_for(places)
    local seen, folders = {}, {}
    for _, place in ipairs(places) do
        local folder = folder_of(place)
        if not seen[folder] then
            seen[folder] = true
            folders[#folders + 1] = folder
        end
    end
    return folders
end
-- }}}

-- The answers' labels, named once: the answer hook acts on these.
permits.ONCE, permits.SESSION, permits.ALWAYS, permits.NO = "Yes", "This time", "Always", "No"
-- The widths a list entry can have. Answers write FOLDER only (step 12);
-- FILE is kept so a narrower answer can return without a format change.
permits.FILE, permits.FOLDER = "file", "folder"

-- {{{ function permits.questions_for()
-- The exact question the agent must ask for a request, as a list of one
-- (the question tool takes a list). Everything the person needs to decide
-- is in the words they see: the places, the folders This time and Always
-- would open, and the project Always belongs to. It carries the request
-- id, so the answer hook can find it.
function permits.questions_for(id, project, places)
    local folders = table.concat(permits.folders_for(places), ", ")
    return {
        {
            question = "Allow a write outside this session's folder, to " .. table.concat(places, ", ") .. "? [outside-write " .. id .. "]",
            header = "Outside",
            multiSelect = false,
            options = {
                { label = permits.ONCE, description = "Allow this one write." },
                { label = permits.SESSION, description = "Allow any write inside " .. folders .. " until this session ends." },
                { label = permits.ALWAYS, description = "Allow any write inside " .. folders .. " from now on, for sessions working in " .. project .. " only." },
                { label = permits.NO, description = "Keep it refused." },
            },
        },
    }
end
-- }}}

-- {{{ function permits.file_request()
-- Files a request for a refused write and returns it (the table described
-- at the top), or nil and a message.
function permits.file_request(json, session_id, project, places)
    local id = new_id()
    local request = {
        id = id,
        session_id = session_id,
        project = project,
        places = places,
        questions = permits.questions_for(id, project, places),
        made = os.time(),
    }
    local ok, err = write_file(STATE .. "/requests/" .. id .. ".json", json.encode(request))
    if not ok then return nil, err end
    return request
end
-- }}}

-- {{{ function permits.read_request()
-- The request with this id, or nil when there is none or it has expired
-- (an expired one is removed).
function permits.read_request(json, id)
    -- not an id this store gives
    if type(id) ~= "string" or not id:match("^%x+$") then return nil end
    local path = STATE .. "/requests/" .. id .. ".json"
    local text = read_file(path)
    if not text then return nil end
    local request = json.decode(text)
    -- unreadable: as good as none
    if type(request) ~= "table" then return nil end
    if os.time() - (tonumber(request.made) or 0) > LIFETIME_SECONDS then
        os.remove(path)
        return nil
    end
    return request
end
-- }}}

-- {{{ function permits.close_request()
function permits.close_request(id)
    os.remove(STATE .. "/requests/" .. id .. ".json")
end
-- }}}

-- {{{ function permits.grant_once()
-- A Yes: one grant for these places, for this session.
function permits.grant_once(json, session_id, id, places)
    return write_file(STATE .. "/grants/" .. session_id .. "/" .. id .. ".json",
        json.encode({ places = places, made = os.time() }))
end
-- }}}

-- {{{ function permits.spend_grant()
-- Spends one of the session's grants that covers every place given, and
-- returns true; false when none does. Expired grants are removed on the way.
function permits.spend_grant(json, session_id, places)
    -- not a session id Claude Code gives: no grants
    if type(session_id) ~= "string" or not session_id:match("^[%w%-]+$") then return false end
    local folder = STATE .. "/grants/" .. session_id
    local handle = io.popen("ls -1 " .. shell_quote(folder) .. " 2>/dev/null", "r")
    local names = handle:read("*a")
    handle:close()
    for name in names:gmatch("[^\n]+") do
        local path = folder .. "/" .. name
        local grant = name:match("%.json$") and json.decode(read_file(path) or "") or nil
        if type(grant) ~= "table" or os.time() - (tonumber(grant.made) or 0) > LIFETIME_SECONDS then
            -- expired or unreadable: removed, never honoured
            os.remove(path)
        else
            local granted = {}
            for _, p in ipairs(grant.places or {}) do granted[p] = true end
            local covers = true
            for _, p in ipairs(places) do
                if not granted[p] then covers = false end
            end
            -- this grant covers the write: spent
            if covers and os.remove(path) then return true end
        end
    end
    return false
end
-- }}}

-- {{{ local function session_file()
-- Where one session's This-session permissions are kept, or nil for an id
-- Claude Code would not give.
local function session_file(session_id)
    if type(session_id) ~= "string" or not session_id:match("^[%w%-]+$") then return nil end
    return STATE .. "/session-allowed/" .. session_id
end
-- }}}

-- {{{ local function lines_of()
-- The lines of a file, split on tabs, as a list of lists of strings.
local function lines_of(path)
    local rows = {}
    for line in (path and read_file(path) or ""):gmatch("[^\n]+") do
        local row = {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do row[#row + 1] = field end
        rows[#rows + 1] = row
    end
    return rows
end
-- }}}

-- {{{ local function covers()
-- True when a permission of `kind` for `held` covers `place`. Anything that
-- is not one of the two kinds covers nothing.
local COVERS_OF_KIND = {
    file = function(place, held) return place == held end,
    folder = function(place, held) return is_inside(place, held) end,
}
local function covers(kind, held, place)
    local test = COVERS_OF_KIND[kind]
    return test ~= nil and type(held) == "string" and held:sub(1, 1) == "/" and test(place, held)
end
-- }}}

-- {{{ function permits.entries_for()
-- What an answer of `width` (permits.FILE or permits.FOLDER) puts on a list for these
-- places: a list of { kind = "file"|"folder", place = string }.
function permits.entries_for(width, places)
    local entries = {}
    if width == permits.FILE then
        for _, place in ipairs(places) do entries[#entries + 1] = { kind = "file", place = place } end
    else
        for _, folder in ipairs(permits.folders_for(places)) do entries[#entries + 1] = { kind = "folder", place = folder } end
    end
    return entries
end
-- }}}

-- {{{ function permits.session_entries()
-- One session's This-session permissions, as { kind, place } entries.
function permits.session_entries(session_id)
    local entries = {}
    for _, row in ipairs(lines_of(session_file(session_id))) do
        entries[#entries + 1] = { kind = row[1], place = row[2] }
    end
    return entries
end
-- }}}

-- {{{ function permits.project_entries()
-- One project's Always permissions, as { kind, place } entries.
function permits.project_entries(project)
    local entries = {}
    for _, row in ipairs(lines_of(ALLOWED)) do
        -- only this project's lines
        if row[1] == project then entries[#entries + 1] = { kind = row[2], place = row[3] } end
    end
    return entries
end
-- }}}

-- {{{ function permits.is_allowed()
-- True when a real place is covered by one of this project's Always
-- permissions or this session's This-session permissions.
function permits.is_allowed(place, session_id, project)
    for _, e in ipairs(permits.project_entries(project)) do
        if covers(e.kind, e.place, place) then return true end
    end
    for _, e in ipairs(permits.session_entries(session_id)) do
        if covers(e.kind, e.place, place) then return true end
    end
    return false
end
-- }}}

-- {{{ function permits.allow_for_session()
-- A This session: the entries added to the session's own list.
function permits.allow_for_session(session_id, width, places)
    local path = session_file(session_id)
    -- not a session id Claude Code gives: nothing kept
    if not path then return nil, "not a session id: " .. tostring(session_id) end
    local lines = {}
    for _, row in ipairs(lines_of(path)) do lines[#lines + 1] = table.concat(row, "\t") end
    for _, e in ipairs(permits.entries_for(width, places)) do lines[#lines + 1] = e.kind .. "\t" .. e.place end
    return write_file(path, table.concat(lines, "\n") .. "\n")
end
-- }}}

-- {{{ function permits.allow_for_project()
-- An Always: the entries added to the list on disk, for this project only.
function permits.allow_for_project(project, width, places)
    -- a project must be an absolute folder, or no session could ever match it
    if type(project) ~= "string" or project:sub(1, 1) ~= "/" then return nil, "not a project folder: " .. tostring(project) end
    local lines = {}
    for _, row in ipairs(lines_of(ALLOWED)) do lines[#lines + 1] = table.concat(row, "\t") end
    for _, e in ipairs(permits.entries_for(width, places)) do lines[#lines + 1] = project .. "\t" .. e.kind .. "\t" .. e.place end
    return write_file(ALLOWED, table.concat(lines, "\n") .. "\n")
end
-- }}}

-- {{{ function permits.forget_session()
-- At the end of a session: its This-session permissions and its unspent
-- grants are removed.
function permits.forget_session(session_id)
    local path = session_file(session_id)
    -- not a session id Claude Code gives: nothing to remove
    if not path then return end
    os.remove(path)
    os.execute("rm -rf -- " .. shell_quote(STATE .. "/grants/" .. session_id))
end
-- }}}

return permits
