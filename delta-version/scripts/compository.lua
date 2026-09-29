#!/usr/bin/env luajit
-- compository.lua - Carries every one of the owner's git repositories to a
-- flash drive, and keeps the copies current.
--
-- In general terms: plug in a flash drive that has been marked as a
-- "compository", run this, and every repository the owner started is on the
-- drive as an ordinary folder anyone can open. Run it again later and each
-- copy is moved forward to match the computer -- never backward, never over
-- work done on the drive itself. Run it with nothing new and nothing changes.
--
-- Each copy on the drive is a normal git clone whose upstream ("origin") is
-- the repository's folder on this computer; git treats a plain folder path as
-- a remote just as it treats a web address. Updating is a fetch followed by a
-- fast-forward: the drive's branch moves only if that is pure forward motion.
--
-- What goes on the drive comes from ../assets/compository-list.lua. Which
-- drives are written to is decided by a marker file, `.compository`, at the
-- drive's root: only a drive someone has deliberately marked (--init) is ever
-- touched, however it is connected.
--
-- Usage:
--   compository.lua                 -- update every connected marked drive
--   compository.lua --drive=/mount  -- update one marked drive (any disk)
--   compository.lua --init=/mount   -- mark a mounted drive as a compository
--   compository.lua --list          -- show what would be carried; write nothing
--
-- Options, in any position:
--   --dir=/path/to/delta-version    -- run against another checkout
--   --workers=N                     -- parallel repositories (default: cores)
--   --list-file=/path/list.lua      -- a different list (the tests use one)
--
-- Internal: `--one <relative path> <source root> <drive>` updates a single
-- repository; the parallel runner starts one of these per repository.
--
-- Exit status: 0 everything current; 1 any repository refused, no marked
-- drive found, or a refusal of the whole run; 2 an unknown mode.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local WORKERS = nil
local LIST_OVERRIDE = nil
do
    local remaining = {}
    for _, argument in ipairs(arg) do
        local dir_value = argument:match("^%-%-dir=(.+)$")
        local workers_value = argument:match("^%-%-workers=(%d+)$")
        local list_value = argument:match("^%-%-list%-file=(.+)$")
        if dir_value then
            DIR = dir_value
        elseif workers_value then
            WORKERS = tonumber(workers_value)
        elseif list_value then
            LIST_OVERRIDE = list_value
        else
            remaining[#remaining + 1] = argument
        end
    end
    for index = #arg, 1, -1 do arg[index] = nil end
    for index, argument in ipairs(remaining) do arg[index] = argument end
end
local MONOREPO_ROOT = DIR:match("(.*)/.+$")
local LIST_PATH = LIST_OVERRIDE or (DIR .. "/assets/compository-list.lua")
local SELF = DIR .. "/scripts/compository.lua"
local MARKER = ".compository"
local DRIVE_FOLDER = "compository"
-- }}}

-- {{{ Shell helpers

-- {{{ local function quote()
-- Single-quotes text for sh, so a folder name holding a quote or a space
-- cannot end the argument early.
local function quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function run()
-- Runs a command and returns its output lines and its exit status. The status
-- is printed after the command and read back, because io.popen():close()
-- under LuaJIT reports success whatever happened. Standard error is merged in
-- so a refusal's reason reaches the report.
local function run(command)
    local pipe = io.popen(command .. " 2>&1; echo \"__exit:$?\"")
    local lines, status = {}, nil
    for line in pipe:lines() do
        local code = line:match("^__exit:(%d+)$")
        if code then status = tonumber(code) else lines[#lines + 1] = line end
    end
    pipe:close()
    return lines, status
end
-- }}}

-- {{{ local function first_line()
local function first_line(command)
    local lines, status = run(command)
    return lines[1], status
end
-- }}}

-- {{{ local function is_directory()
local function is_directory(path)
    local _, status = run("test -d " .. quote(path))
    return status == 0
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    local _, status = run("test -e " .. quote(path))
    return status == 0
end
-- }}}

-- }}}

-- {{{ Discovery: which repositories are the owner's

-- {{{ local function find_git_folders()
-- Every `.git` folder under a root, without descending into the folders the
-- list says hold no repository of the owner's. `.git` is pruned once found,
-- so the search never wanders through a repository's object store. Only
-- folders are matched: a worktree or submodule has a `.git` *file* and is a
-- view into a repository already found.
local function find_git_folders(root, never_enter)
    local prunes = {}
    for _, name in ipairs(never_enter) do
        if name ~= ".git" then prunes[#prunes + 1] = "-name " .. quote(name) end
    end
    local command = string.format(
        "find %s \\( %s \\) -prune -o -name .git -type d -print -prune",
        quote(root), table.concat(prunes, " -o "))
    local lines = run(command)
    local folders = {}
    for _, line in ipairs(lines) do
        -- find's own complaints (unreadable folders) are not paths
        if line:match("/%.git$") then folders[#folders + 1] = line:sub(1, -6) end
    end
    return folders
end
-- }}}

-- {{{ local function first_author_email()
-- The email of the repository's first commit: the oldest root commit across
-- all branches. Returns nil for a repository with no commits at all, which is
-- a fact about the repository (an empty `git init`), not a failure.
local function first_author_email(repository)
    local lines, status = run(string.format(
        "git -C %s log --all --max-parents=0 --format='%%at %%ae'", quote(repository)))
    if status ~= 0 or #lines == 0 then return nil end
    table.sort(lines, function(a, b)
        return tonumber(a:match("^(%d+)")) < tonumber(b:match("^(%d+)"))
    end)
    return lines[1]:match("^%d+ (.+)$")
end
-- }}}

-- {{{ local function discover()
-- The owner's repositories, as { relative = "civics/algorism", source =
-- "/mnt/.../civics/algorism", root = "/mnt/mtwo/programming" }, sorted by
-- path, plus the repositories passed over and why, so --list can show both.
local function discover(list)
    local wanted_email, excluded = {}, {}
    for _, email in ipairs(list.owner_emails) do wanted_email[email:lower()] = true end
    for _, relative in ipairs(list.exclude) do excluded[relative] = true end

    local carried, passed_over = {}, {}
    for _, root in ipairs(list.roots) do
        for _, repository in ipairs(find_git_folders(root, list.never_enter)) do
            local relative = repository:sub(#root + 2)
            local email = first_author_email(repository)
            -- Four paths: excluded by the list, empty, someone else's, or
            -- the owner's (carried).
            if excluded[relative] then
                passed_over[#passed_over + 1] = { relative = relative, why = "excluded by the list" }
            elseif not email then
                passed_over[#passed_over + 1] = { relative = relative, why = "no commits" }
            elseif not wanted_email[email:lower()] then
                passed_over[#passed_over + 1] = { relative = relative, why = "first commit by " .. email }
            else
                carried[#carried + 1] = { relative = relative, source = repository, root = root }
            end
        end
    end
    table.sort(carried, function(a, b) return a.relative < b.relative end)
    table.sort(passed_over, function(a, b) return a.relative < b.relative end)
    return carried, passed_over
end
-- }}}

-- }}}

-- {{{ Selected notes, documents and tools

-- {{{ local function refresh_selected()
-- Gathers the hand-picked items into their own git repository on this
-- computer and commits whatever changed, so they reach the drive the same way
-- the repositories do: as history that plays forward. The repository holds
-- exactly the selected set -- everything but .git is cleared and copied
-- afresh each run -- so an item taken off the list leaves it too, in a
-- commit that says so rather than silently.
--
-- The commit is made under the owner's own git identity, so the repository's
-- first commit is the owner's and the ordinary discovery carries it. Three
-- paths: an empty list (nothing made, nothing done), nothing changed (no
-- commit), something changed (one commit). A listed item that does not exist
-- stops the run: a missing document is a mistake to fix, not to skip.
local function refresh_selected(list)
    if #list.selected == 0 then return nil end
    local root = list.repositories.roots[1]
    local repository = list.selected_repository

    for _, relative in ipairs(list.selected) do
        if not exists(root .. "/" .. relative) then
            error("selected item " .. relative .. " does not exist under " .. root, 0)
        end
    end

    if not is_directory(repository .. "/.git") then
        local lines, status = run(string.format("git init --quiet -b main %s", quote(repository)))
        if status ~= 0 then error("could not create " .. repository .. ": " .. table.concat(lines, " "), 0) end
    end

    run(string.format("find %s -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +", quote(repository)))
    for _, relative in ipairs(list.selected) do
        local lines, status = run(string.format("cd %s && cp -a --parents %s %s",
            quote(root), quote(relative), quote(repository)))
        if status ~= 0 then error("could not copy " .. relative .. ": " .. table.concat(lines, " "), 0) end
    end

    run(string.format("git -C %s add -A", quote(repository)))
    local changed = run(string.format("git -C %s status --porcelain", quote(repository)))
    if #changed == 0 then return "selected items unchanged" end
    local lines, status = run(string.format(
        "git -C %s commit --quiet -m %s", quote(repository),
        quote("Selected notes and documents, gathered " .. os.date("%Y-%m-%d %H:%M"))))
    if status ~= 0 then error("could not commit selected items: " .. table.concat(lines, " "), 0) end
    return string.format("selected items committed (%d change%s)", #changed, #changed == 1 and "" or "s")
end
-- }}}

-- }}}

-- {{{ Drives

-- {{{ local function decode_lsblk()
-- lsblk's raw output writes a space inside a mount point as \x20.
local function decode_lsblk(text)
    return (text:gsub("\\x(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end
-- }}}

-- {{{ local function removable_mounts()
-- Mount points of partitions on removable or USB disks. lsblk reports the
-- transport (usb, sata, nvme) only on the whole disk, so partitions are
-- judged by their parent disk: removable if either the partition or its disk
-- says removable, or the disk is on USB.
local function removable_mounts()
    local lines, status = run("lsblk -rpno NAME,PKNAME,RM,TRAN,MOUNTPOINT")
    if status ~= 0 then error("lsblk failed: " .. table.concat(lines, " "), 0) end
    local devices = {}
    for _, line in ipairs(lines) do
        local fields = {}
        -- raw mode separates by single spaces; empty fields collapse, so the
        -- columns are read positionally from a split that keeps empties
        for field in (line .. " "):gmatch("([^ ]*) ") do fields[#fields + 1] = field end
        devices[#devices + 1] = { name = fields[1], parent = fields[2], rm = fields[3],
                                  tran = fields[4], mount = decode_lsblk(fields[5] or "") }
    end
    local by_name = {}
    for _, device in ipairs(devices) do by_name[device.name] = device end

    local mounts = {}
    for _, device in ipairs(devices) do
        if device.mount ~= "" then
            local disk = by_name[device.parent] or device
            if device.rm == "1" or disk.rm == "1" or disk.tran == "usb" then
                mounts[#mounts + 1] = device.mount
            end
        end
    end
    return mounts
end
-- }}}

-- {{{ local function marked()
local function marked(mount)
    return exists(mount .. "/" .. MARKER)
end
-- }}}

-- }}}

-- {{{ One repository

-- {{{ local function on_limited_filesystem()
-- FAT and exFAT (the usual flash-drive formats) store no symlinks and no
-- executable bit; git must be told, or every script shows as modified.
local function on_limited_filesystem(path)
    local kind = first_line("stat -f -c %T " .. quote(path))
    return kind == "msdos" or kind == "vfat" or kind == "exfat" or kind == "fuseblk"
end
-- }}}

-- {{{ local function short()
local function short(commit) return commit and commit:sub(1, 8) or "none" end
-- }}}

-- {{{ local function update_one()
-- Brings one repository's drive copy up to the computer's. Returns a status
-- word and a sentence. Every refusal names its reason and leaves the copy as
-- it was; one repository's refusal never stops the others.
local function update_one(relative, source_root, drive)
    local source = source_root .. "/" .. relative
    local target = drive .. "/" .. DRIVE_FOLDER .. "/" .. relative

    -- Absent: clone. --no-hardlinks, because a drive is another filesystem
    -- and a clone that shared files with the computer would not be a copy.
    if not is_directory(target .. "/.git") then
        if exists(target) then
            return "refused", "a folder is already there without a repository in it"
        end
        run("mkdir -p " .. quote(target:match("(.*)/")))
        local lines, status = run(string.format("git clone --quiet --no-hardlinks %s %s",
            quote(source), quote(target)))
        if status ~= 0 then return "refused", "clone failed: " .. table.concat(lines, " ") end
        local note = ""
        if on_limited_filesystem(target) then
            run(string.format("git -C %s config core.symlinks false", quote(target)))
            run(string.format("git -C %s config core.fileMode false", quote(target)))
            note = " (FAT/exFAT drive: symlinks and executable bits not kept)"
        end
        return "cloned", "at " .. short(first_line(string.format("git -C %s rev-parse HEAD", quote(target)))) .. note
    end

    -- Present: the upstream must be this computer's folder. A repository that
    -- moved on the computer leaves the drive pointing at the old place; the
    -- drive copy is re-pointed, and the report says so.
    local repaired = ""
    local origin = first_line(string.format("git -C %s remote get-url origin", quote(target)))
    if origin ~= source then
        run(string.format("git -C %s remote remove origin", quote(target)))
        run(string.format("git -C %s remote add origin %s", quote(target), quote(source)))
        repaired = " (upstream re-pointed from " .. tostring(origin) .. ")"
    end

    -- Only tracked files count as uncommitted work. Untracked folders are
    -- expected: a repository nested inside this one on the computer (such as
    -- symbeline-realms inside ai-stuff) is cloned inside this copy on the
    -- drive too, and shows here as untracked.
    local dirty = run(string.format("git -C %s status --porcelain --untracked-files=no", quote(target)))
    if #dirty > 0 then
        return "refused", "has uncommitted changes on the drive; left as it is" .. repaired
    end

    local fetched, fetch_status = run(string.format("git -C %s fetch --quiet --prune origin", quote(target)))
    if fetch_status ~= 0 then
        return "refused", "fetch failed: " .. table.concat(fetched, " ") .. repaired
    end

    local branch = first_line(string.format("git -C %s symbolic-ref --short HEAD", quote(target)))
    if not branch then return "refused", "the drive copy is not on a branch" .. repaired end
    local _, known = run(string.format("git -C %s rev-parse --verify --quiet origin/%s",
        quote(target), quote(branch)))
    if known ~= 0 then
        return "refused", "branch " .. branch .. " no longer exists on the computer" .. repaired
    end

    local before = first_line(string.format("git -C %s rev-parse HEAD", quote(target)))
    local merged, merge_status = run(string.format("git -C %s merge --quiet --ff-only origin/%s",
        quote(target), quote(branch)))
    if merge_status ~= 0 then
        return "refused", "branch " .. branch .. " has commits the computer does not; not moved" .. repaired
    end
    local after = first_line(string.format("git -C %s rev-parse HEAD", quote(target)))

    if before == after then return "current", "at " .. short(after) .. repaired end
    return "advanced", short(before) .. " -> " .. short(after) .. repaired
end
-- }}}

-- }}}

-- {{{ Running over a drive

-- {{{ local function worker_count()
local function worker_count()
    -- first_line also returns the exit status; the parentheses keep only the
    -- line, or tonumber would take the status as a number base.
    return WORKERS or tonumber((first_line("nproc"))) or error("nproc gave no count", 0)
end
-- }}}

-- {{{ local function nesting_layers()
-- Repositories grouped by how deeply they sit inside other carried ones:
-- layer 1 is nested in nothing, layer 2 inside a layer-1 repository, and so
-- on. On the drive a nested repository is cloned inside its parent's copy, so
-- the parent must exist first -- and a parent cannot be cloned into a folder a
-- child already occupies. Layers run one after another; within a layer,
-- everything runs in parallel.
local function nesting_layers(carried)
    local layers = {}
    for _, repository in ipairs(carried) do
        local depth = 1
        for _, other in ipairs(carried) do
            if other.root == repository.root
               and repository.relative:sub(1, #other.relative + 1) == other.relative .. "/" then
                depth = depth + 1
            end
        end
        layers[depth] = layers[depth] or {}
        table.insert(layers[depth], repository)
    end
    return layers
end
-- }}}

-- {{{ local function run_layer()
-- One layer, in parallel: each repository is an independent fetch and copy,
-- so one worker per core runs them side by side. The work list is written to
-- the RAM tier and handed to xargs, which starts this same script in its
-- one-repository mode for each line. Returns the workers' report lines.
local function run_layer(drive, layer)
    local work_file = DIR .. "/tmp/shared-memory/compository-work.txt"
    local handle = assert(io.open(work_file, "w"))
    for _, repository in ipairs(layer) do
        handle:write(repository.root, "\t", repository.relative, "\n")
    end
    handle:close()
    local lines = run(string.format(
        "xargs -a %s -d '\\n' -P %d -I{} sh -c 'root=$(printf %%s \"$1\" | cut -f1); rel=$(printf %%s \"$1\" | cut -f2); luajit %s --dir=%s --one \"$rel\" \"$root\" %s' _ {}",
        quote(work_file), worker_count(), quote(SELF), quote(DIR), quote(drive)))
    os.remove(work_file)
    return lines
end
-- }}}

-- {{{ local function update_drive()
-- Every carried repository, layer by layer (see nesting_layers). Prints one
-- line per repository and returns how many were refused.
local function update_drive(drive, carried)
    local tiers = dofile(MONOREPO_ROOT .. "/scripts/libs/ensure-ram-tiers.lua")
    tiers.ensure(DIR)

    local lines = {}
    local layers = nesting_layers(carried)
    for depth = 1, #layers do
        for _, line in ipairs(run_layer(drive, layers[depth])) do lines[#lines + 1] = line end
    end

    table.sort(lines, function(a, b)
        return (a:match("\t([^\t]+)\t") or a) < (b:match("\t([^\t]+)\t") or b)
    end)
    local refused = 0
    print("drive " .. drive)
    for _, line in ipairs(lines) do
        local status, relative, detail = line:match("^(%a+)\t([^\t]+)\t(.*)$")
        if status then
            print(string.format("  %-9s %-44s %s", status, relative, detail))
            if status == "refused" then refused = refused + 1 end
        else
            -- a worker that died without its one line: counted as refused
            print("  refused   (worker) " .. line)
            refused = refused + 1
        end
    end
    return refused
end
-- }}}

-- }}}

-- {{{ Modes

-- {{{ local function mode_list()
local function mode_list(list)
    local carried, passed_over = discover(list.repositories)
    print(string.format("selected items (%d), gathered into %s:", #list.selected, list.selected_repository))
    for _, relative in ipairs(list.selected) do print("  " .. relative) end
    print(string.format("carried (%d):", #carried))
    for _, repository in ipairs(carried) do print("  " .. repository.relative) end
    print(string.format("passed over (%d):", #passed_over))
    for _, entry in ipairs(passed_over) do
        print(string.format("  %-44s %s", entry.relative, entry.why))
    end
    local drives = {}
    for _, mount in ipairs(removable_mounts()) do
        drives[#drives + 1] = mount .. (marked(mount) and " (marked)" or " (not marked)")
    end
    print("removable drives mounted: " .. (#drives > 0 and table.concat(drives, ", ") or "none"))
end
-- }}}

-- {{{ local function mode_init()
-- Marking is deliberate and separate from updating, so a drive is never
-- written to because it merely happened to be plugged in.
local function mode_init(mount)
    if not is_directory(mount) then error(mount .. " is not a folder", 0) end
    if marked(mount) then
        print(mount .. " is already a compository")
        return
    end
    local handle = assert(io.open(mount .. "/" .. MARKER, "w"))
    handle:write("This drive is a compository: compository.lua keeps copies of the\n",
                 "owner's git repositories in the compository/ folder beside this file.\n")
    handle:close()
    print("marked " .. mount .. " as a compository; run compository.lua to fill it")
end
-- }}}

-- {{{ local function mode_update()
local function mode_update(list, drives)
    -- The selected items are gathered first, so the repository holding them
    -- is found and carried by the same discovery as every other.
    local gathered = refresh_selected(list)
    if gathered then print(gathered) end
    local carried = discover(list.repositories)
    local refused = 0
    for _, drive in ipairs(drives) do
        refused = refused + update_drive(drive, carried)
    end
    if refused > 0 then
        print(string.format("%d repositor%s refused; see the lines above",
            refused, refused == 1 and "y" or "ies"))
        os.exit(1)
    end
end
-- }}}

-- }}}

-- {{{ Entry
local function main()
    local mode = arg[1] or "--all"

    -- The worker mode prints exactly one tab-separated line, which the
    -- parallel runner collects.
    if mode == "--one" then
        local status, detail = update_one(arg[2], arg[3], arg[4])
        print(status .. "\t" .. arg[2] .. "\t" .. detail)
        return
    end

    local list = dofile(LIST_PATH)
    local init_path = mode:match("^%-%-init=(.+)$")
    local drive_path = mode:match("^%-%-drive=(.+)$")

    if mode == "--list" then
        mode_list(list)
    elseif init_path then
        mode_init(init_path)
    elseif drive_path then
        if not marked(drive_path) then
            error(drive_path .. " has no " .. MARKER .. " marker; mark it first with --init=" .. drive_path, 0)
        end
        mode_update(list, { drive_path })
    elseif mode == "--all" then
        local drives = {}
        for _, mount in ipairs(removable_mounts()) do
            if marked(mount) then drives[#drives + 1] = mount end
        end
        if #drives == 0 then
            error("no connected drive carries a " .. MARKER .. " marker; mount a drive and run --init=<mount point> once", 0)
        end
        mode_update(list, drives)
    else
        io.stderr:write("unknown mode: " .. mode .. "\n")
        io.stderr:write("expected --list, --init=PATH, --drive=PATH, or nothing (every marked drive)\n")
        os.exit(2)
    end
end

-- A refusal is one plain line and exit 1; anything else keeps its traceback.
local ok, failure = xpcall(main, function(message)
    if type(message) == "string" and not message:match("^[^\n]*:%d+:") then return message end
    return debug.traceback(message, 2)
end)
if not ok then
    io.stderr:write("compository: " .. tostring(failure) .. "\n")
    os.exit(1)
end
-- }}}
