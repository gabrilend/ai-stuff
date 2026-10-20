-- outside-write-permits.lua
--
-- The permissions a person can give for a write outside a session's folder,
-- kept where no agent can write them, for the write gate
-- (harness-hooks/refuse-outside-writes) and the hook that reads the person's
-- answer (harness-hooks/answer-outside-write). Issue 043, step 9.
--
-- In plain terms: when the gate refuses a write it could pin down, it files
-- a request -- which places, which session, and the exact question the agent
-- must put to the person. The person answers Yes (this once), Always (these
-- folders, from now on) or No. A Yes becomes a grant the session spends on
-- its next write that needs no more than those places; an Always adds the
-- folders to a list every session's gate reads.
--
-- Where things live:
--   requests  <state>/requests/<id>.json            in RAM; 30 minutes
--   grants    <state>/grants/<session>/<id>.json    in RAM; 30 minutes
--   allowed   <allowed file>, one real folder per line, on disk
-- <state> is /dev/shm/claude-outside-writes and <allowed file> is
-- ~/.claude/outside-write-allowed-folders; both are outside every project
-- folder, so the gate itself refuses an agent writing them. The environment
-- variables OUTSIDE_WRITE_STATE and OUTSIDE_WRITE_ALLOWED move them, for the
-- tests only.
--
-- A request file holds (JSON):
--   id          string   8 hex digits from /dev/urandom
--   session_id  string   the session that was refused
--   places      list of strings, real places (links followed)
--   question    the question to ask, as the question tool takes it:
--               { question = string, header = string, multiSelect = false,
--                 options = list of { label = string, description = string } }
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

-- {{{ function permits.question_for()
-- The exact question the agent must ask for a request. Everything the
-- person needs to decide is in the words they see: the places, and what
-- Always would open.
function permits.question_for(id, places)
    return {
        question = "Allow a write outside this session's folder, to " .. table.concat(places, ", ") .. "? [outside-write " .. id .. "]",
        header = "Outside",
        multiSelect = false,
        options = {
            { label = "Yes", description = "Allow this write, this once." },
            { label = "Always", description = "Allow any write inside " .. table.concat(permits.folders_for(places), ", ") .. ", for every session, from now on." },
            { label = "No", description = "Keep it refused." },
        },
    }
end
-- }}}

-- {{{ function permits.file_request()
-- Files a request for a refused write and returns it (the table described
-- at the top), or nil and a message.
function permits.file_request(json, session_id, places)
    local id = new_id()
    local request = {
        id = id,
        session_id = session_id,
        places = places,
        question = permits.question_for(id, places),
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

-- {{{ function permits.allowed_folders()
-- The folders on the allowed list, as a list of strings.
function permits.allowed_folders()
    local folders = {}
    for line in (read_file(ALLOWED) or ""):gmatch("[^\n]+") do
        -- only absolute folders count; anything else in the file is ignored
        if line:sub(1, 1) == "/" then folders[#folders + 1] = line end
    end
    return folders
end
-- }}}

-- {{{ function permits.is_allowed()
-- True when a real place lies in a folder on the allowed list.
function permits.is_allowed(place)
    for _, folder in ipairs(permits.allowed_folders()) do
        if is_inside(place, folder) then return true end
    end
    return false
end
-- }}}

-- {{{ function permits.allow_always()
-- An Always: each folder added to the allowed list, unless it is already
-- covered by one there.
function permits.allow_always(places)
    local listed = permits.allowed_folders()
    for _, folder in ipairs(permits.folders_for(places)) do
        local covered = false
        for _, have in ipairs(listed) do
            if is_inside(folder, have) then covered = true end
        end
        if not covered then listed[#listed + 1] = folder end
    end
    return write_file(ALLOWED, table.concat(listed, "\n") .. "\n")
end
-- }}}

return permits
