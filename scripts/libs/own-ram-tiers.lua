-- own-ram-tiers.lua
--
-- Finds the two RAM scratch rooms that belong to the folder a Claude Code
-- session is running in, as real places, for the hooks that judge paths
-- against them: allow-own-ram-tiers (lets the file tools in) and
-- refuse-outside-writes (counts them as inside when a shell command writes).
-- One definition, so the two hooks can never disagree about what "the
-- project's own rooms" means.
--
-- The layout is issue 033's (libs/ensure-ram-tiers):
--   <folder>/tmp                -> /tmp/<name>        the exec room
--   /tmp/<name>/shared-memory   -> /dev/shm/<name>    the artifact room
--
-- The rules are issue 042's, each the owner's word:
--   - only the `tmp` link in the session's own folder, never one above it
--     ("that symlinked one must be in the root of where the agent is running
--     otherwise it needs to ask the user");
--   - only those two rooms ("good, and ONLY those two locations");
--   - a room counts only when it lies strictly below its RAM root, so a link
--     aimed at a disk folder, or at /tmp itself, names no room;
--   - a link leading nowhere (a reboot emptied RAM) names no room.
--
-- Places are real places: every link followed (`realpath`).
--
-- LuaJIT compatible; no Lua 5.4 syntax.

local tiers = {}

-- The two RAM roots. Overridable from the environment only so the tests can
-- stand them in a scratch folder, exactly as libs/ensure-ram-tiers allows.
local EXEC_TIER_ROOT     = os.getenv("EXEC_TIER_ROOT") or "/tmp"
local ARTIFACT_TIER_ROOT = os.getenv("ARTIFACT_TIER_ROOT") or "/dev/shm"

-- {{{ local function shell_quote()
local function shell_quote(word)
    return "'" .. word:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function tiers.real_place()
-- Where a path really is, or nil when realpath cannot say. `must_exist`
-- asks for `realpath -e` (every part must exist); otherwise `-m` (links
-- followed for the parts that exist, the rest taken as written, so a file
-- about to be created is judged by its folder).
function tiers.real_place(path, must_exist)
    local handle = io.popen("realpath " .. (must_exist and "-e" or "-m") .. " -- " .. shell_quote(path) .. " 2>/dev/null", "r")
    local out = handle:read("*a")
    local ok, _, code = handle:close()
    -- realpath failed: no place
    if not (ok == true or code == 0) then return nil end
    out = out:gsub("%s+$", "")
    -- an empty answer is no place either
    if out == "" then return nil end
    return out
end
-- }}}

-- {{{ function tiers.is_inside()
-- True when `place` is `folder` or anything below it, compared up to a `/`
-- (so /tmp/alpha-other is not inside /tmp/alpha).
function tiers.is_inside(place, folder)
    -- the filesystem root holds everything
    if folder == "/" then return place:sub(1, 1) == "/" end
    return place == folder or place:sub(1, #folder + 1) == folder .. "/"
end
-- }}}

-- {{{ local function room_under_root()
-- The real place a link leads, when that is a folder strictly below the
-- given root; nil otherwise.
local function room_under_root(link, root)
    local room = tiers.real_place(link, true)
    local real_root = tiers.real_place(root, true)
    -- the link leads nowhere, or the root itself is missing: no room
    if not room or not real_root then return nil end
    -- a room must be inside its root and not the root itself
    if room == real_root or not tiers.is_inside(room, real_root) then return nil end
    return room
end
-- }}}

-- {{{ function tiers.rooms_of()
-- The rooms of the session folder `cwd` (an absolute path), as a list of
-- real folders: none, the exec room alone, or both.
function tiers.rooms_of(cwd)
    local folder = cwd:gsub("/+$", "")
    -- the filesystem root is never a project: /tmp there is the system's own
    -- folder, not a link (the same rule as restore-ram-tiers)
    if folder == "" then return {} end
    local link = folder .. "/tmp"
    local is_link = os.execute("test -L " .. shell_quote(link))
    -- LuaJIT's os.execute gives the exit status; 0 means the link is there
    if is_link ~= 0 and is_link ~= true then return {} end
    local rooms = {}
    local exec_room = room_under_root(link, EXEC_TIER_ROOT)
    -- the exec room is missing or outside /tmp: neither room is trusted, since
    -- the artifact room is only ever reached through it
    if not exec_room then return rooms end
    rooms[#rooms + 1] = exec_room
    local artifact_room = room_under_root(exec_room .. "/shared-memory", ARTIFACT_TIER_ROOT)
    -- the artifact link is there and leads under /dev/shm: it counts too
    if artifact_room then rooms[#rooms + 1] = artifact_room end
    return rooms
end
-- }}}

-- {{{ local function claude_temp_root()
-- Claude Code's temp root: $CLAUDE_CODE_TMPDIR, or /tmp/claude-<uid>.
local function claude_temp_root()
    local root = os.getenv("CLAUDE_CODE_TMPDIR")
    -- set: Claude Code uses it as written
    if root and root ~= "" then return root end
    local handle = io.popen("id -u", "r")
    local uid = handle:read("*a"):gsub("%s+$", "")
    handle:close()
    return "/tmp/claude-" .. uid
end
-- }}}

-- {{{ function tiers.is_in_claude_scratchpad()
-- True when a real place lies in one session's Claude Code scratchpad,
-- whether or not the folder exists yet. Claude Code makes the scratchpad
-- only when something first writes to it, so a lookup on disk (as
-- claude_scratchpad_of does) refused the very first write: found 2026-10-20
-- in a session whose `mkdir -p <scratchpad>/documentation-site` was turned
-- away. This compares the place against the shape instead.
function tiers.is_in_claude_scratchpad(place, session_id)
    -- not an id Claude Code would give: no scratchpad
    if type(session_id) ~= "string" or not session_id:match("^[%w%-]+$") then return false end
    local root = tiers.real_place(claude_temp_root(), false)
    -- the root cannot be placed: no scratchpad
    if not root then return false end
    local prefix = root .. "/"
    -- outside the temp root altogether
    if place:sub(1, #prefix) ~= prefix then return false end
    local slug, sid, rest = place:sub(#prefix + 1):match("^([^/]+)/([^/]+)/scratchpad(.*)$")
    -- the scratchpad itself, or below it, of exactly this session
    return slug ~= nil and sid == session_id and (rest == "" or rest:sub(1, 1) == "/")
end
-- }}}

-- {{{ function tiers.claude_scratchpad_of()
-- The scratchpad Claude Code made for one session, as a real folder, or nil
-- when there is none. Claude Code builds it as
--   <temp root>/<project slug>/<session id>/scratchpad
-- where the temp root is $CLAUDE_CODE_TMPDIR, or /tmp/claude-<uid> without
-- it (read from Claude Code's own code, 2026-10-20). The slug is found by
-- looking rather than worked out from a folder name, since it comes from the
-- folder the session started in, which a hook cannot know for sure.
-- Session ids are Claude Code's UUIDs; anything else names no scratchpad,
-- so a crafted id cannot widen the search.
function tiers.claude_scratchpad_of(session_id)
    -- not an id Claude Code would give: no scratchpad
    if type(session_id) ~= "string" or not session_id:match("^[%w%-]+$") then return nil end
    local root = claude_temp_root()
    local handle = io.popen("find " .. shell_quote(root) .. " -mindepth 3 -maxdepth 3 -type d -path "
        .. shell_quote("*/" .. session_id .. "/scratchpad") .. " -print -quit 2>/dev/null", "r")
    local found = handle:read("*a"):gsub("%s+$", "")
    handle:close()
    -- the session has not made its scratchpad (or the root is gone)
    if found == "" then return nil end
    return tiers.real_place(found, true)
end
-- }}}

return tiers
