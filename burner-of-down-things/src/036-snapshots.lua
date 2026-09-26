-- 036-snapshots.lua
--
-- The check after a turn that it changed only what it was allowed to
-- (docs/005, "confinement, twice"). A snapshot is every file under some
-- folders with its size, modification time and SHA-256; comparing two gives
-- every path created, changed or removed; each change outside the writable
-- prefixes is a breach.
--
-- Checksums are what make a "change" real: a file rewritten with the same
-- bytes (new time, same content) is not a change. They are also expensive on
-- a large source, so a snapshot reuses a previous snapshot's checksum for any
-- file whose size and time have not moved, and hashes the rest across every
-- core. The first snapshot of a case pays once; later ones hash almost
-- nothing.
--
-- A snapshot (in memory): path (absolute) -> { size = number, time = string,
-- hash = 64 hex characters }.
-- A change: { path = absolute path, how = "created" | "changed" | "removed" }.

local text_tables = require("014-text-tables")
local fs = require("017-the-filesystem")

local snapshots = {}

-- Files larger than this are identified by size and time alone, never
-- hashed. One 943 MB git pack file in a source took 12 of a first
-- snapshot's 14 seconds on a single thread. The cost of the shortcut: such a
-- file rewritten with identical bytes counts as changed. For files this
-- large that is taken as the lesser harm.
snapshots.HASH_LIMIT = 64 * 1024 * 1024

-- {{{ local function list_with_stats
-- Every file and link under `root` with size and modification time, from
-- one find process. `excluded` is an array of absolute paths pruned from the
-- listing (folders and single files).
local function list_with_stats(root, excluded)
    local prune = {}
    for _, path in ipairs(excluded or {}) do
        prune[#prune + 1] = "-path " .. fs.quote((path:gsub("/$", "")))
    end
    local prune_expression = ""
    if #prune > 0 then
        prune_expression = "\\( " .. table.concat(prune, " -o ") .. " \\) -prune -o "
    end
    -- Five NUL-terminated fields per entry: type letter, size, time, link
    -- target (empty for a file), path. NUL is the one byte no path holds.
    local command = "find -P " .. fs.quote((root:gsub("/$", ""))) .. " " .. prune_expression
        .. "\\( -type f -o -type l \\) -printf '%y\\0%s\\0%T@\\0%l\\0%p\\0' 2>&1"
    local out, ok = fs.capture(command)
    if not ok then
        error("snapshots: find could not read everything under " .. root .. ":\n" .. out:gsub("%z", "\n"))
    end
    local entries = {}
    local fields = {}
    for field in out:gmatch("([^%z]*)%z") do
        fields[#fields + 1] = field
        if #fields == 5 then
            entries[#entries + 1] = {
                kind = fields[1], size = tonumber(fields[2]), time = fields[3],
                target = fields[4], path = fields[5],
            }
            fields = {}
        end
    end
    return entries
end
-- }}}

-- {{{ local function hash_list
-- Hashes a newline-separated list of paths; run inside a worker thread.
-- Returns "path\thash" lines. No upvalues: it loads SHA-256 itself.
local function hash_list(project_dir, paths_text)
    package.path = project_dir .. "/src/?.lua;" .. package.path
    local sha = require("015-sha-256")
    local out = {}
    for path in paths_text:gmatch("[^\n]+") do
        local file = io.open(path, "rb")
        if file then
            file:close()
            out[#out + 1] = path .. "\t" .. sha.of_file(path)
        else
            -- A link to nothing, or a file removed mid-snapshot, has no bytes
            -- to hash; it is recorded with an empty-marker hash.
            out[#out + 1] = path .. "\t" .. "unreadable"
        end
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ function snapshots.take
-- Snapshots every file under `roots` (absolute folders), minus `excluded`.
-- `previous` (a snapshot or nil) lends checksums for unmoved files.
-- Returns the snapshot and how many files were hashed.
function snapshots.take(project, roots, excluded, previous)
    local snap = {}
    local to_hash = {}
    for _, root in ipairs(roots) do
        for _, e in ipairs(list_with_stats(root, excluded)) do
            local before = previous and previous[e.path]
            if e.kind == "l" then
                -- A link's content is where it points; the bytes behind it
                -- may be anywhere (the design's tmp link points into RAM).
                snap[e.path] = { size = e.size, time = e.time, hash = "link:" .. e.target }
            elseif before and before.size == e.size and before.time == e.time then
                snap[e.path] = { size = e.size, time = e.time, hash = before.hash }
            elseif e.size > snapshots.HASH_LIMIT then
                snap[e.path] = { size = e.size, time = e.time, hash = "large:" .. e.size .. ":" .. e.time }
            else
                snap[e.path] = { size = e.size, time = e.time }
                to_hash[#to_hash + 1] = e.path
            end
        end
    end
    if #to_hash > 0 then
        local effil = require("effil")
        local threads = math.min(effil.hardware_threads(), #to_hash)
        local slices = {}
        for i, path in ipairs(to_hash) do
            local s = (i - 1) % threads + 1
            slices[s] = slices[s] or {}
            slices[s][#slices[s] + 1] = path
        end
        local results = {}
        if threads == 1 then
            results[1] = hash_list(project.dir, table.concat(slices[1], "\n"))
        else
            local runners = {}
            for s, list in ipairs(slices) do
                runners[s] = effil.thread(hash_list)(project.dir, table.concat(list, "\n"))
            end
            for s, runner in ipairs(runners) do
                local status, err = runner:wait()
                if status ~= "completed" then
                    error("snapshots: a hashing thread stopped (" .. tostring(status) .. "): " .. tostring(err))
                end
                results[s] = runner:get()
            end
        end
        for _, text in ipairs(results) do
            for path, hash in text:gmatch("([^\t\n]+)\t([^\n]+)") do
                snap[path].hash = hash
            end
        end
    end
    return snap, #to_hash
end
-- }}}

-- {{{ function snapshots.compare
-- Every path created, changed (different bytes) or removed between two
-- snapshots, sorted by path.
function snapshots.compare(before, after)
    local changes = {}
    for path, a in pairs(after) do
        local b = before[path]
        if not b then
            changes[#changes + 1] = { path = path, how = "created" }
        elseif b.hash ~= a.hash then
            changes[#changes + 1] = { path = path, how = "changed" }
        end
    end
    for path in pairs(before) do
        if not after[path] then
            changes[#changes + 1] = { path = path, how = "removed" }
        end
    end
    table.sort(changes, function(x, y) return x.path < y.path end)
    return changes
end
-- }}}

-- {{{ local function starts_with
local function starts_with(path, prefix)
    return path:sub(1, #prefix) == prefix
end
-- }}}

-- {{{ function snapshots.charge
-- Gives each change to the turn whose write prefix holds it most
-- specifically (the longest matching prefix). A change whose longest
-- matching prefix is shared by several turns is charged to the whole set
-- ("set"); a change no turn may write is a breach, also charged to the set,
-- since turns running together cannot be told apart by what they wrote.
-- Returns { by_turn = { [turn id] = { changes } }, set = { changes },
-- breaches = { changes } }.
function snapshots.charge(changes, turns)
    local by_turn, set, breaches = {}, {}, {}
    for _, turn in ipairs(turns) do
        by_turn[turn.id] = {}
    end
    for _, change in ipairs(changes) do
        local best_length, owners = -1, {}
        for _, turn in ipairs(turns) do
            for _, prefix in ipairs(turn.writes) do
                if starts_with(change.path, prefix) then
                    if #prefix > best_length then
                        best_length, owners = #prefix, { turn.id }
                    elseif #prefix == best_length then
                        owners[#owners + 1] = turn.id
                    end
                end
            end
        end
        if #owners == 0 then
            breaches[#breaches + 1] = change
        elseif #owners == 1 then
            local list = by_turn[owners[1]]
            list[#list + 1] = change
        else
            set[#set + 1] = change
        end
    end
    return { by_turn = by_turn, set = set, breaches = breaches }
end
-- }}}

-- {{{ function snapshots.save
-- Keeps a snapshot on disk so the next run can reuse its checksums.
function snapshots.save(path, snap)
    local rows = {}
    for p, e in pairs(snap) do
        rows[#rows + 1] = { p, e.size, e.time, e.hash or "" }
    end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    text_tables.write(path, { "path", "size", "time", "hash" }, rows)
end
-- }}}

-- {{{ function snapshots.load
-- A saved snapshot, or nil when there is none.
function snapshots.load(path)
    if not fs.exists(path) then
        return nil
    end
    local snap = {}
    for _, row in ipairs((text_tables.read(path))) do
        snap[row.path] = { size = tonumber(row.size), time = row.time, hash = row.hash }
    end
    return snap
end
-- }}}

return snapshots
