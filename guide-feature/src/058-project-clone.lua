#!/usr/bin/env luajit
-- 058-project-clone.lua - each voice's git clone of the project the canvas
-- names, at the commit it names, in RAM if it fits (issue 501).
--
-- In plain terms: a voice's model may look into the project the canvas is
-- about (phase 5). To look, the voice needs the project's files, at the
-- commit kuvalu is at. The owner: "I think we'd git clone a project into the
-- mini-computer if we were gonna work on it. To RAM if it fits." So at the
-- start of every turn the clone keeper:
--
--   1. reads the project's name and commit from the canvas's project: header;
--   2. finds where that project comes from in input/project-clone (a
--      repository on kuvalu, reached over SSH, and the project's folder in
--      it), the one place that list is kept;
--   3. if this voice has no clone of that project yet, measures how big it
--      would be, and places it in RAM (the RAM tier, tmp/shared-memory/,
--      when that is a tmpfs that can be written) when the project and the
--      room the turn needs for itself fit a share of the memory available;
--      otherwise on disk, which is the slower path, and the log says why;
--   4. brings the clone to the commit: fetches when it lacks it, then checks
--      it out.
--
-- One clone is kept per project and voice, so returning to an earlier
-- project is a fetch, not a fresh clone, while it is still there. The voice
-- is in the path because the rehearsal runs all three voices on one machine;
-- on a voice's own machine it is always the same name.
--
-- The clone holds one commit at a time, and only what the project needs:
-- each commit is fetched alone with no history (--depth 1), only the
-- project's own folder is checked out (sparse), and only that folder's files
-- are fetched (git's blob filter, asked of the source's own upload-pack with
-- uploadpack.allowFilter, so kuvalu needs no setting changed). A source that
-- cannot filter sends every file of the commit, which the measurement after
-- cloning catches. The monorepo guide-feature lives in is 735 MiB of packs;
-- one commit of it fetched this way is about 7 MiB of git store and the
-- project's own files.
--
-- The size is measured twice. Before cloning: the project folder's files at
-- the commit, counted twice (once checked out, once in git's own store),
-- read from the source with git ls-tree. After cloning into RAM: the clone
-- itself, with du, since history and trees are not in the first figure. A
-- RAM clone measured bigger than the share is moved to disk, and the log
-- says so.
--
--   local clone = dofile(DIR .. "/src/058-project-clone.lua")
--   local kept = clone.keep({ root = DIR, voice = "fg-sora-1",
--                             project = { name = "guide-feature", commit = "9f2c1e0" } })
--   kept.place      -- "ram" or "disk"
--   kept.project    -- the project's folder in the clone (the look tool reads it)
--   clone.describe(kept)   -- the log line
--
--   scripts/project-clone --voice fg-sora-1 --project guide-feature --commit 9f2c1e0
--
-- Real machines behind seams, for tests: opts.memory (bytes available),
-- opts.filesystem_of(path), opts.free_space(path). LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")

local M = {}

-- {{{ M.SETTINGS
-- input/project-clone (docs/datapath-looking-into-the-project.md).
M.SETTINGS = {
    ["repository.*"] = { type = "text" },    -- where a project is cloned from
    ["folder.*"]     = { type = "text" },    -- the project's folder in it; "." its root
    ["ram-folder"]   = { type = "text", required = true },
    ["disk-folder"]  = { type = "text", required = true },
    ["ram-share"]    = { type = "decimal", required = true },
    ["working-room"] = { type = "whole", required = true },   -- MiB
}
-- }}}

-- {{{ M.RAM_FILESYSTEMS
-- The filesystems that live in memory, as stat -f names them.
M.RAM_FILESYSTEMS = { tmpfs = true, ramfs = true }
-- }}}

-- {{{ small helpers
local function quote(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end

local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body or text, tonumber(status)
end

local function fail(text) error("project clone: " .. text, 0) end

local function now()
    local pipe = io.popen("date +%s.%N")
    local value = tonumber(pipe:read("*l"))
    pipe:close()
    return value or os.time()
end

-- 1536 -> "1.5 KiB"; for the log
function M.size_text(bytes)
    local units = { "bytes", "KiB", "MiB", "GiB", "TiB" }
    local value, unit = bytes, 1
    while value >= 1024 and unit < #units do
        value, unit = value / 1024, unit + 1
    end
    if unit == 1 then return string.format("%d bytes", bytes) end
    return string.format("%.1f %s", value, units[unit])
end

local function first_line(text) return (string.match(text or "", "^%s*([^\n]*)")) end
-- }}}

-- {{{ function M.path()
-- A folder setting as a path: ~/ is the home folder, / is absolute, and
-- anything else is under the project root.
function M.path(root, text)
    if string.sub(text, 1, 2) == "~/" then
        return (os.getenv("HOME") or "") .. string.sub(text, 2)
    elseif string.sub(text, 1, 1) == "/" then
        return text
    end
    return root .. "/" .. text
end
-- }}}

-- {{{ function M.parse_repository()
-- A repository address: a path on this machine (/..., ~/...), or HOST:PATH,
-- which git and ssh both read as the path on that host. Returns
-- { host = ..., path = ... } (host nil for a path here), or nil and why.
function M.parse_repository(address)
    if type(address) ~= "string" or address == "" then return nil, "there is no address" end
    if string.sub(address, 1, 1) == "/" or string.sub(address, 1, 2) == "~/" then
        return { path = address }
    end
    if string.find(address, "://", 1, true) then
        return nil, "'" .. address .. "' is a URL; write HOST:/PATH, which git reaches over SSH"
    end
    local host, path = string.match(address, "^([%w][%w%.%-_@]*):(/.+)$")
    if host then return { host = host, path = path } end
    return nil, "'" .. address .. "' is neither a path here (/...) nor HOST:/PATH"
end
-- }}}

-- {{{ function M.on_source()
-- The shell command that runs a git command on the source repository: here,
-- or over SSH on its host. `git_args` is the part after `git -C PATH`.
-- BatchMode: never stop to ask for a password; a voice reaches kuvalu by key.
function M.on_source(repository, git_args)
    local where = assert(M.parse_repository(repository))
    if not where.host then
        local path = where.path
        if string.sub(path, 1, 2) == "~/" then path = (os.getenv("HOME") or "") .. string.sub(path, 2) end
        return "git -C " .. quote(path) .. " " .. git_args
    end
    return "ssh -o BatchMode=yes -o ConnectTimeout=10 " .. quote(where.host) .. " "
        .. quote("git -C " .. quote(where.path) .. " " .. git_args)
end
-- }}}

-- {{{ function M.measure()
-- The bytes of the project folder's files at the commit, on the source, and
-- the source's full name for the commit. Returns { bytes, files, commit } or
-- nil and why.
function M.measure(repository, commit, folder)
    local full, status = shell(M.on_source(repository, "rev-parse --verify --quiet "
        .. quote(commit .. "^{commit}")))
    if status ~= 0 or not string.match(full, "^%x+$") then
        return nil, repository .. " has no commit " .. commit
            .. (full ~= "" and (" (" .. first_line(full) .. ")") or "")
    end
    local listing, listed = shell(M.on_source(repository, "ls-tree -r -l " .. quote(full)
        .. (folder ~= "." and (" -- " .. quote(folder)) or "")))
    if listed ~= 0 then
        return nil, "cannot list " .. folder .. " at " .. commit .. " in " .. repository
            .. ": " .. first_line(listing)
    end
    local bytes, files = 0, 0
    for size in string.gmatch(listing, "%x+ blob %x+%s+(%d+)\t") do
        bytes, files = bytes + tonumber(size), files + 1
    end
    if files == 0 then
        return nil, repository .. " has no files in " .. folder .. " at " .. commit
    end
    return { bytes = bytes, files = files, commit = full }
end
-- }}}

-- {{{ machine readings: memory, filesystem, free space, size on disk
-- The memory available for new work, as the kernel counts it (MemAvailable).
function M.memory()
    local handle = io.open("/proc/meminfo", "r")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    local kib = string.match(text, "MemAvailable:%s*(%d+) kB")
    return kib and tonumber(kib) * 1024 or nil
end

-- The filesystem a folder is on, as stat -f names it (tmpfs, ext2/ext3, ...).
function M.filesystem_of(path)
    local name, status = shell("stat -f -c %T " .. quote(path))
    return status == 0 and first_line(name) or nil
end

-- The bytes free on the filesystem a folder is on.
function M.free_space(path)
    local text, status = shell("df -Pk " .. quote(path))
    if status ~= 0 then return nil end
    local kib = string.match(text, "\n%S+%s+%d+%s+%d+%s+(%d+)")
    return kib and tonumber(kib) * 1024 or nil
end

-- The bytes a folder takes, as du counts them.
function M.size_of(path)
    local text, status = shell("du -sk " .. quote(path))
    local kib = status == 0 and string.match(text, "^(%d+)")
    return kib and tonumber(kib) * 1024 or nil
end
-- }}}

-- {{{ function M.choose()
-- Where a new clone goes. opts: bytes (the estimate), ram_folder, share (0
-- to 1), room (bytes kept for the turn), and the seams memory,
-- filesystem_of, free_space. Returns "ram" or "disk", the reason, and the
-- numbers used ({ available, allowed }).
function M.choose(opts)
    local made = select(2, shell("mkdir -p " .. quote(opts.ram_folder)))
    if made ~= 0 then
        return "disk", "the RAM folder " .. opts.ram_folder .. " cannot be made", {}
    end
    local _, writable = shell("test -w " .. quote(opts.ram_folder))
    if writable ~= 0 then
        return "disk", "the RAM folder " .. opts.ram_folder .. " cannot be written", {}
    end
    local filesystem = (opts.filesystem_of or M.filesystem_of)(opts.ram_folder)
    if not M.RAM_FILESYSTEMS[filesystem or ""] then
        return "disk", "the RAM folder " .. opts.ram_folder .. " is not in memory (it is on "
            .. tostring(filesystem) .. ", not tmpfs)", {}
    end
    local available = (opts.memory or M.memory)()
    if not available then
        return "disk", "the memory available cannot be read", {}
    end
    local allowed = math.floor(available * opts.share)
    local numbers = { available = available, allowed = allowed }
    local needed = opts.bytes + opts.room
    if needed > allowed then
        return "disk", string.format("%s and %s of working room are more than %d%% of the %s "
            .. "of memory available (%s)", M.size_text(opts.bytes), M.size_text(opts.room),
            math.floor(opts.share * 100 + 0.5), M.size_text(available), M.size_text(allowed)),
            numbers
    end
    local free = (opts.free_space or M.free_space)(opts.ram_folder)
    if free and opts.bytes > free then
        return "disk", string.format("%s is more than the %s free in %s", M.size_text(opts.bytes),
            M.size_text(free), opts.ram_folder), numbers
    end
    return "ram", string.format("%s and %s of working room fit %d%% of the %s of memory "
        .. "available", M.size_text(opts.bytes), M.size_text(opts.room),
        math.floor(opts.share * 100 + 0.5), M.size_text(available)), numbers
end
-- }}}

-- {{{ git on the clone
local function git(dir, args) return shell("git -C " .. quote(dir) .. " " .. args) end

local function is_clone(dir)
    local _, status = shell("test -d " .. quote(dir .. "/.git"))
    if status ~= 0 then return false end
    _, status = git(dir, "rev-parse --git-dir")
    return status == 0
end

-- The full name of the commit in the clone, or nil when it has not got it.
local function resolve(dir, commit)
    local full, status = git(dir, "rev-parse --verify --quiet " .. quote(commit .. "^{commit}"))
    return status == 0 and string.match(full, "^%x+$") and full or nil
end

local function head(dir)
    local full, status = git(dir, "rev-parse --verify --quiet HEAD")
    return status == 0 and string.match(full, "^%x+$") and full or nil
end

-- The source's address as git fetches from it: file:// for a path here (git
-- honours the blob filter only through a transport), HOST:PATH as written.
local function url_of(repository)
    local where = assert(M.parse_repository(repository))
    if where.host then return repository end
    return "file://" .. M.path("", where.path)
end

-- Fetches one commit, by its full name, with no history (--depth 1) and
-- only the trees (--filter=blob:none); the files of the project's folder
-- come when it is checked out.
local function fetch(dir, full)
    local said, status = git(dir, "fetch --quiet --depth 1 --filter=blob:none origin " .. quote(full))
    if status ~= 0 then return nil, first_line(said) end
    return true
end

-- The clone at the commit: fetched when it lacks it, then checked out.
-- `lookup` gives the commit's full name from the source, which a fetch of
-- one commit needs (the canvas carries a short one).
local function bring_to(dir, commit, result, lookup)
    local full = resolve(dir, commit)
    if not full then
        local source_full, why = lookup()
        if not source_full then fail(why) end
        local ok, problem = fetch(dir, source_full)
        if not ok then fail("cannot fetch " .. commit .. " into " .. dir .. ": " .. tostring(problem)) end
        result.fetched = true
        full = resolve(dir, commit)
        if not full then fail("the source has no commit " .. commit .. ", even after a fetch") end
    end
    if head(dir) ~= full then
        local said, status = git(dir, "checkout --quiet --detach " .. quote(full))
        if status ~= 0 then fail("cannot check out " .. commit .. " in " .. dir .. ": " .. first_line(said)) end
        result.checked_out = true
    end
end

-- A new, empty clone at DEST that fetches from the source one commit at a
-- time, and checks out only the project's folder (sparse). Made beside DEST
-- and renamed in; bring_to then fetches the commit.
local function make_clone(repository, folder, dest)
    local part = dest .. ".part"
    shell("rm -rf " .. quote(part) .. " && mkdir -p " .. quote(string.match(dest, "^(.*)/[^/]+$")))
    local steps = {
        "init --quiet " .. quote(part),
        "-C " .. quote(part) .. " remote add origin " .. quote(url_of(repository)),
        -- asked of the source's own upload-pack, so kuvalu needs no setting
        "-C " .. quote(part) .. " config remote.origin.uploadpack "
            .. quote("git -c uploadpack.allowFilter=true upload-pack"),
        "-C " .. quote(part) .. " config remote.origin.promisor true",
        "-C " .. quote(part) .. " config remote.origin.partialclonefilter blob:none",
    }
    if folder ~= "." then
        steps[#steps + 1] = "-C " .. quote(part) .. " sparse-checkout set " .. quote(folder)
    end
    for _, step in ipairs(steps) do
        local said, status = shell("git " .. step)
        if status ~= 0 then
            shell("rm -rf " .. quote(part))
            fail("cannot make a clone of " .. repository .. " (git " .. step .. "): " .. first_line(said))
        end
    end
    local moved, why = os.rename(part, dest)
    if not moved then
        shell("rm -rf " .. quote(part))
        fail("cannot put the clone at " .. dest .. ": " .. tostring(why))
    end
end
-- }}}

-- {{{ function M.keep()
-- The clone keeper, at the start of a turn. opts: root, voice, project
-- ({ name, commit }, from the canvas), and the seams. Returns { name,
-- commit, repository, folder, place ("ram"|"disk"), path (the clone),
-- project (the project's folder in it), made, fetched, checked_out, moved,
-- was (the commit it was at), bytes (the clone's size), why, seconds }.
-- Raises with the reason when there is no clone to give.
function M.keep(opts)
    local started = now()
    local root, voice, project = opts.root or DIR, opts.voice, opts.project or {}
    local name, commit = project.name, project.commit
    if type(voice) ~= "string" or not string.match(voice, "^[%w_%-]+$") then
        fail("there is no voice name")
    end
    if type(name) ~= "string" or not string.match(name, "^[%w_%-%.]+$") then
        fail("the canvas names no project")
    end
    if type(commit) ~= "string" or not string.match(commit, "^%x+$") then
        fail("the canvas names no commit for " .. name)
    end
    local values = settings.read("project-clone", M.SETTINGS, { root = root })
    local repository = values["repository." .. name]
    if not repository then
        fail("input/project-clone has no repository." .. name .. " line, so " .. name
            .. " cannot be cloned")
    end
    local where, bad = M.parse_repository(repository)
    if not where then fail("input/project-clone: repository." .. name .. ": " .. bad) end
    local folder = values["folder." .. name] or "."
    if folder ~= "." and (string.sub(folder, 1, 1) == "/" or string.find(folder, "..", 1, true)) then
        fail("input/project-clone: folder." .. name .. " must be a folder inside the repository")
    end
    local share, room = values["ram-share"], values["working-room"]
    if share <= 0 or share > 1 then fail("input/project-clone: ram-share must be above 0 and at most 1") end
    if room < 0 then fail("input/project-clone: working-room cannot be below 0") end

    local ram_folder = M.path(root, values["ram-folder"]) .. "/" .. voice
    local disk_folder = M.path(root, values["disk-folder"]) .. "/" .. voice
    local result = { name = name, commit = commit, repository = repository, folder = folder,
                     made = false, fetched = false, checked_out = false, moved = false }

    if is_clone(ram_folder .. "/" .. name) then
        result.place, result.path = "ram", ram_folder .. "/" .. name
    elseif is_clone(disk_folder .. "/" .. name) then
        result.place, result.path = "disk", disk_folder .. "/" .. name
    end

    if result.path then
        result.was = head(result.path)
        bring_to(result.path, commit, result, function()
            local measured, why = (opts.measure or M.measure)(repository, commit, folder)
            return measured and measured.commit, why
        end)
        result.why = "kept from an earlier turn"
    else
        local measured, why = (opts.measure or M.measure)(repository, commit, folder)
        if not measured then fail(why) end
        result.estimate = measured.bytes * 2
        local place, reason, numbers = M.choose({
            bytes = result.estimate, ram_folder = ram_folder, share = share,
            room = room * 1024 * 1024, memory = opts.memory, filesystem_of = opts.filesystem_of,
            free_space = opts.free_space })
        result.place, result.why, result.numbers = place, reason, numbers
        result.path = (place == "ram" and ram_folder or disk_folder) .. "/" .. name
        if place == "disk" then shell("mkdir -p " .. quote(disk_folder)) end
        make_clone(repository, folder, result.path)
        result.made = true
        local ok, problem = pcall(bring_to, result.path, commit, result,
            function() return measured.commit end)
        if not ok then
            shell("rm -rf " .. quote(result.path))
            error(problem, 0)
        end
        -- measured again, now that history and trees are in it too
        if place == "ram" then
            local bytes = M.size_of(result.path) or result.estimate
            if bytes + room * 1024 * 1024 > numbers.allowed then
                local target = disk_folder .. "/" .. name
                shell("mkdir -p " .. quote(disk_folder) .. " && rm -rf " .. quote(target))
                local _, moved = shell("mv " .. quote(result.path) .. " " .. quote(target))
                if moved == 0 then
                    result.place, result.path, result.moved = "disk", target, true
                    result.why = string.format("measured at %s once cloned, which with %s of "
                        .. "working room is more than %s; moved to disk", M.size_text(bytes),
                        M.size_text(room * 1024 * 1024), M.size_text(numbers.allowed))
                end
            end
        end
    end
    result.project = folder == "." and result.path or (result.path .. "/" .. folder)
    result.bytes = M.size_of(result.path)
    result.seconds = now() - started
    return result
end
-- }}}

-- {{{ function M.describe()
-- The log line for a kept clone.
function M.describe(r)
    local place = r.place == "ram" and "in RAM" or "on disk (the slower path)"
    local size = r.bytes and (", " .. M.size_text(r.bytes)) or ""
    local at = string.format("project %s at %s: ", r.name, r.commit)
    local timing = string.format(", %.2f seconds", r.seconds or 0)
    if r.made then
        return at .. "cloned " .. place .. " at " .. r.path .. size .. ", because " .. r.why
            .. (r.fetched and "; fetched the commit" or "") .. timing
    end
    local steps = {}
    if r.fetched then steps[#steps + 1] = "fetched" end
    if r.checked_out then steps[#steps + 1] = "checked out" end
    local was = r.was and string.sub(r.was, 1, #r.commit) or "nothing"
    if #steps == 0 then
        return at .. "the clone " .. place .. " at " .. r.path .. " is already there" .. size .. timing
    end
    return at .. "the clone " .. place .. " at " .. r.path .. " was at " .. was .. "; "
        .. table.concat(steps, " and ") .. size .. timing
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "058%-project%-clone%.lua$") then
    local opts = { root = DIR, project = {} }
    local usage = "usage: project-clone [--dir ROOT] --voice NAME --project NAME --commit COMMIT\n"
    local index = 1
    while index <= #arg do
        local key, value = string.match(arg[index], "^%-%-(%a+)$"), arg[index + 1]
        if not key or value == nil then
            io.stderr:write(usage)
            os.exit(2)
        end
        if key == "dir" then opts.root = value
        elseif key == "voice" then opts.voice = value
        elseif key == "project" then opts.project.name = value
        elseif key == "commit" then opts.project.commit = value
        else
            io.stderr:write(usage)
            os.exit(2)
        end
        index = index + 2
    end
    if not (opts.voice and opts.project.name and opts.project.commit) then
        io.stderr:write(usage)
        os.exit(2)
    end
    local ok, result = pcall(M.keep, opts)
    if not ok then
        io.stderr:write(tostring(result), "\n")
        os.exit(1)
    end
    print(M.describe(result))
    os.exit(0)
end
-- }}}

return M
