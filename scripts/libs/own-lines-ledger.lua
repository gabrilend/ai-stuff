-- own-lines-ledger.lua
--
-- The record of which lines this session wrote, and the reading of unified
-- diffs against it. These share it:
--   record-own-edits    writes to the ledger after every file edit
--   claim-own-change    writes a whole-file claim, said out loud
--   own-changes-patch   (library) judges changes against it, for
--   commit-own-changes  which commits only claimed lines, on a private
--                       staging list, and
--   stage-own-changes   which previews what that would commit
--
-- WHERE IT LIVES AND WHY
--
-- /dev/shm/claude-own-edits/<session-id>/ledger.tsv -- RAM, one folder per
-- session. RAM because it is working state for commits made today, not a
-- record: it is rebuilt by working, and losing it on reboot costs a
-- claim-own-change at worst. One folder per session because two sessions in
-- one repository are exactly the case this exists for. Subagents share their
-- parent's session id, so their edits count as the session's own.
--
-- FORMAT
--
-- One record per line, three tab-separated fields: kind, absolute real path,
-- line text. Kinds:
--   +   this line text was added to this file by the session
--   -   this line text was removed from this file by the session
--   W   the whole file is claimed: any added or removed line in it is ours
--   R   every removal in this file is ours (a whole-file rewrite removes
--       whatever was there before it, and that removal was our act)
-- The line text escapes \ as \\, tab as \t and carriage return as \r, so a
-- record is always one physical line. Records are only ever appended, each
-- batch in one write call to a file opened for appending, so two hooks
-- finishing at once cannot lose each other's lines.
--
-- Paths are stored resolved (realpath), because /home/ritz/programming and
-- /mnt/mtwo/programming are the same folder and git reports the second.
--
-- CLAIMS ARE BY TEXT, WITHIN A FILE
--
-- A claim says "a line reading exactly this, in this file, is ours". Positions
-- would be stronger but they shift with every edit above them; text survives.
-- The gap: a foreign line identical to one of ours in the same file passes.
--
-- LuaJIT compatible; no Lua 5.4 syntax.

local ledger = {}

ledger.ROOT = "/dev/shm/claude-own-edits"

-- {{{ local function shell_quote()
local function shell_quote(word)
    return "'" .. word:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function ledger.escape()
function ledger.escape(text)
    return (text:gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\r", "\\r"))
end
-- }}}

-- {{{ function ledger.unescape()
function ledger.unescape(text)
    local map = { ["\\"] = "\\", t = "\t", r = "\r" }
    return (text:gsub("\\(.)", function(c) return map[c] or ("\\" .. c) end))
end
-- }}}

-- {{{ function ledger.realpath()
-- Resolves symlinks in a path whose last part may not exist yet (a deleted or
-- not-yet-written file), through `realpath -m`.
function ledger.realpath(path)
    local handle = io.popen("realpath -m -- " .. shell_quote(path), "r")
    local resolved = handle:read("*l")
    handle:close()
    if not resolved or resolved == "" then return path end
    return resolved
end
-- }}}

-- {{{ function ledger.session_dir()
function ledger.session_dir(session_id)
    return ledger.ROOT .. "/" .. session_id
end
-- }}}

-- {{{ function ledger.append()
-- Appends records {kind, path, text} for one session, in a single write.
-- Returns true, or nil and the reason.
function ledger.append(session_id, records)
    if #records == 0 then return true end
    if not session_id:match("^[%w%-_]+$") then
        return nil, "session id has unexpected characters: " .. session_id
    end
    local dir = ledger.session_dir(session_id)
    local ok = os.execute("mkdir -p -m 700 " .. shell_quote(dir))
    if ok ~= 0 and ok ~= true then return nil, "cannot create " .. dir end
    local lines = {}
    for i, r in ipairs(records) do
        lines[i] = r[1] .. "\t" .. r[2] .. "\t" .. ledger.escape(r[3] or "") .. "\n"
    end
    local data = table.concat(lines)
    local f, err = io.open(dir .. "/ledger.tsv", "a")
    if not f then return nil, err end
    -- one buffer big enough for the whole batch, so it leaves in one write
    f:setvbuf("full", #data + 1)
    f:write(data)
    f:close()
    return true
end
-- }}}

-- {{{ function ledger.load()
-- Reads a session's ledger into claims[path] = {
--   added   = { [text] = true }   lines added
--   removed = { [text] = true }   lines removed
--   whole   = bool                every line in the file claimed
--   all_removals = bool           every removal in the file claimed
-- }. A session with no ledger yet has no claims, which is not an error.
function ledger.load(session_id)
    local claims = {}
    local f = io.open(ledger.session_dir(session_id) .. "/ledger.tsv", "r")
    if not f then return claims end
    for line in f:lines() do
        local kind, path, text = line:match("^([%+%-WR])\t([^\t]*)\t(.*)$")
        if kind then
            local c = claims[path]
            if not c then
                c = { added = {}, removed = {}, whole = false, all_removals = false }
                claims[path] = c
            end
            -- dispatch on the record kind
            if kind == "+" then c.added[ledger.unescape(text)] = true
            elseif kind == "-" then c.removed[ledger.unescape(text)] = true
            elseif kind == "W" then c.whole = true
            elseif kind == "R" then c.all_removals = true end
        end
    end
    f:close()
    return claims
end
-- }}}

-- {{{ function ledger.records_from_hunks()
-- Turns change blocks in the harness's structuredPatch shape
-- ({ lines = { " context", "-removed", "+added" } }) into ledger records.
function ledger.records_from_hunks(path, hunks, records)
    for _, hunk in ipairs(hunks or {}) do
        for _, line in ipairs(hunk.lines or {}) do
            local mark, text = line:sub(1, 1), line:sub(2)
            if mark == "+" or mark == "-" then
                records[#records + 1] = { mark, path, text }
            end
        end
    end
    return records
end
-- }}}

-- {{{ function ledger.line_claimed()
-- Whether one diff line (mark "+" or "-", and its text) in a file is claimed.
function ledger.line_claimed(claims, path, mark, text)
    local c = claims[path]
    if not c then return false end
    if c.whole then return true end
    if mark == "+" then return c.added[text] == true end
    return c.all_removals or c.removed[text] == true
end
-- }}}

-- {{{ local function unquote_git_path()
-- git writes unusual file names C-quoted: "a\tb" with octal escapes.
local function unquote_git_path(p)
    if p:sub(1, 1) ~= '"' then return p end
    local inner = p:sub(2, -2)
    inner = inner:gsub("\\(%d%d%d)", function(o) return string.char(tonumber(o, 8)) end)
    local map = { n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\" }
    return (inner:gsub("\\(.)", function(c) return map[c] or c end))
end
-- }}}

-- {{{ function ledger.parse_diff()
-- Reads a git unified diff (best produced with -U0 --no-renames) into
-- files = { {
--   old_path, new_path    repository-relative, or nil for /dev/null
--   header = { lines }    everything before the first @@, kept verbatim
--   binary = bool         "Binary files ... differ"
--   hunks = { { old_start, old_count, new_start, new_count, suffix,
--               lines = { "+text" | "-text" | " text" | "\\ No newline" } } }
-- }, ... }
-- Body lines are counted against the @@ header, so a removed line whose text
-- begins "-- " (a Lua comment) is never mistaken for a file header.
function ledger.parse_diff(text)
    local files = {}
    local file, hunk
    local old_left, new_left = 0, 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if hunk and (old_left > 0 or new_left > 0 or line:sub(1, 1) == "\\") then
            -- inside a change block: the counts say where it ends
            local mark = line:sub(1, 1)
            hunk.lines[#hunk.lines + 1] = line
            if mark == "-" then old_left = old_left - 1
            elseif mark == "+" then new_left = new_left - 1
            elseif mark == " " then old_left = old_left - 1; new_left = new_left - 1 end
        elseif line:sub(1, 11) == "diff --git " then
            file = { header = { line }, hunks = {}, binary = false }
            files[#files + 1] = file
            hunk = nil
        elseif file and line:sub(1, 3) == "@@ " then
            local a, b, c, d, suffix = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@(.*)$")
            hunk = {
                old_start = tonumber(a), old_count = b == "" and 1 or tonumber(b),
                new_start = tonumber(c), new_count = d == "" and 1 or tonumber(d),
                suffix = suffix, lines = {},
            }
            old_left, new_left = hunk.old_count, hunk.new_count
            file.hunks[#file.hunks + 1] = hunk
        elseif file and not hunk then
            -- a header line: file names, modes, index, binary marker
            file.header[#file.header + 1] = line
            local old_name = line:match("^%-%-%- (.*)$")
            local new_name = line:match("^%+%+%+ (.*)$")
            if old_name then
                file.old_path = old_name ~= "/dev/null" and unquote_git_path(old_name):gsub("^a/", "") or nil
            elseif new_name then
                file.new_path = new_name ~= "/dev/null" and unquote_git_path(new_name):gsub("^b/", "") or nil
            elseif line:match("^Binary files ") then
                file.binary = true
            end
        end
    end
    -- a file with no --- / +++ lines (binary, mode-only) takes its names from
    -- the diff --git line
    for _, f in ipairs(files) do
        if not f.old_path and not f.new_path then
            local a, b = f.header[1]:match("^diff %-%-git a/(.-) b/(.*)$")
            f.old_path, f.new_path = a, b
        end
    end
    return files
end
-- }}}

-- {{{ function ledger.file_path()
-- The path a diff entry is about: the new name, or the old one for a deletion.
function ledger.file_path(entry)
    return entry.new_path or entry.old_path
end
-- }}}

return ledger
