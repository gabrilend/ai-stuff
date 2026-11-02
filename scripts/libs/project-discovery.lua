-- project-discovery.lua
--
-- Finds the projects in a folder of projects, scores how much each looks like
-- one, and says what kind of project it is. The rules were lifted out of
-- delta-version/scripts/list-projects.sh, so any script can ask "which of
-- these folders are projects?" and get the same answer that tool gives,
-- instead of copying its rules and drifting from them (issue 010).
--
-- How it works, in general terms: it looks at every folder directly inside
-- the base folder, skips the ones whose names say they are not projects
-- (issues, scripts, build, node_modules, ...), and adds up points for the
-- marks a project leaves -- a src/ folder, an issues/ folder, a Cargo.toml,
-- a README.md. A folder that reaches the threshold is a project. Its kind is
-- read from the build file it keeps, or failing that from which source files
-- it holds most of.
--
-- One implementation, in Lua. libs/project-discovery.sh is the bash face of
-- this same file and runs it, rather than repeating the rules in bash: two
-- copies of a rulebook are a race, which is the lesson issue-names.lua and the
-- transcript naming rules were both built on.
--
-- Usage as a library:
--
--   local discovery = dofile(SCRIPTS_DIR .. "/libs/project-discovery.lua")
--   discovery.init("/home/ritz/programming/ai-stuff")
--   for _, p in ipairs(discovery.scan()) do print(p.name, p.score, p.type) end
--
-- Usage as a command (what the bash face calls):
--
--   luajit project-discovery.lua scan BASE [options]
--       one line per project: path, name, score, type, separated by tabs
--   luajit project-discovery.lua score PATH [options]     the score alone
--   luajit project-discovery.lua classify PATH            the kind alone
--
--   options: --all                      also print folders that are not
--                                       projects, with a fifth column
--                                       "project" / "not-project" / "excluded"
--            --exclude PATTERN          one more name to skip (a shell-style
--                                       glob on the folder's own name)
--            --only-exclude PATTERN     replace the skipped names entirely
--            --weight MARK=POINTS       change one mark's points (src=50)
--            --threshold N              points a project needs (default 50)

local M = {}

-- {{{ defaults
-- Names that are never projects, as list-projects.sh has them. Shell-style
-- globs matched against the folder's own name; the last two are the patterns
-- that tool tests on every pass of its loop.
M.DEFAULT_EXCLUDED = {
    "issues", "scripts", "docs", ".git", ".claude", "llm-transcripts",
    "build", "target", "dist", "out", "bin",
    "libs", "node_modules", "vendor", "external",
    "tools", "utils", "backup", "backups", "old", "archive", "tmp", "temp",
    "delta-version", ".operations", ".canaries",
    ".storage_*", ".*_operations*",
}

-- The marks a project leaves, with list-projects.sh's points. kind says
-- whether the mark is a folder or a file.
M.DEFAULT_WEIGHTS = {
    { mark = "src",          kind = "dir",  points = 50 },
    { mark = "issues",       kind = "dir",  points = 40 },
    { mark = "Cargo.toml",   kind = "file", points = 30 },
    { mark = "package.json", kind = "file", points = 30 },
    { mark = "Makefile",     kind = "file", points = 25 },
    { mark = ".gitignore",   kind = "file", points = 20 },
    { mark = "README.md",    kind = "file", points = 15 },
    { mark = "docs",         kind = "dir",  points = 10 },
}

M.DEFAULT_THRESHOLD = 50

-- Build files that settle a project's kind outright, checked in this order.
M.BUILD_FILES = {
    { file = "Cargo.toml",       type = "rust" },
    { file = "go.mod",           type = "go" },
    { file = "package.json",     type = "node" },
    { file = "pyproject.toml",   type = "python" },
    { file = "setup.py",         type = "python" },
    { file = "requirements.txt", type = "python" },
    { file = "rockspec",         type = "lua", suffix = true },
}

-- Source extensions counted when no build file settles it.
M.EXTENSIONS = {
    lua = "lua", c = "c", h = "c", rs = "rust", go = "go", py = "python",
    js = "node", ts = "node", sh = "shell", zig = "zig", cpp = "c++",
    hpp = "c++", cc = "c++",
}
-- }}}

-- {{{ state
local config = {
    base_dir = nil,
    excluded = nil,
    weights = nil,
    threshold = nil,
}
-- }}}

-- {{{ local function shell_quote
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function test_path
-- True when `test FLAG path` succeeds. os.execute answers 0 under LuaJIT and
-- true under Lua 5.2+, so both are read as success.
local function test_path(flag, path)
    local status = os.execute("test " .. flag .. " " .. shell_quote(path))
    return status == 0 or status == true
end
-- }}}

-- {{{ local function lines_of
local function lines_of(cmd)
    local out = {}
    local pipe = io.popen(cmd)
    for line in pipe:lines() do out[#out + 1] = line end
    pipe:close()
    return out
end
-- }}}

-- {{{ function M.glob_to_pattern
-- A shell-style glob (* and ? only, as list-projects.sh's [[ == ]] uses
-- them) as an anchored Lua pattern.
function M.glob_to_pattern(glob)
    local p = glob:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0")
    p = p:gsub("%*", ".*"):gsub("%?", ".")
    return "^" .. p .. "$"
end
-- }}}

-- {{{ function M.init
-- Sets the base folder and, optionally, any of:
--   excluded   list of globs replacing the default skipped names
--   exclude    list of globs added to them
--   weights    { mark = points } changing marks' points (a mark not in the
--              defaults is added, as a folder when it has no dot)
--   threshold  points a project needs
function M.init(base_dir, options)
    options = options or {}
    config.base_dir = (base_dir or "."):gsub("/+$", "")
    if config.base_dir == "" then config.base_dir = "/" end
    config.excluded = {}
    for _, g in ipairs(options.excluded or M.DEFAULT_EXCLUDED) do
        config.excluded[#config.excluded + 1] = g
    end
    for _, g in ipairs(options.exclude or {}) do
        config.excluded[#config.excluded + 1] = g
    end
    config.weights = {}
    for _, w in ipairs(M.DEFAULT_WEIGHTS) do
        config.weights[#config.weights + 1] = { mark = w.mark, kind = w.kind, points = w.points }
    end
    for mark, points in pairs(options.weights or {}) do
        local found = false
        for _, w in ipairs(config.weights) do
            if w.mark == mark then w.points = points; found = true end
        end
        if not found then
            config.weights[#config.weights + 1] = {
                mark = mark, kind = mark:find("%.") and "file" or "dir", points = points }
        end
    end
    config.threshold = options.threshold or M.DEFAULT_THRESHOLD
end
-- }}}

-- {{{ local function ensure_init
local function ensure_init()
    if not config.base_dir then M.init(".") end
end
-- }}}

-- {{{ function M.is_excluded
-- True when a folder's own name says it is not a project.
function M.is_excluded(path)
    ensure_init()
    local name = path:gsub("/+$", ""):match("([^/]+)$") or path
    for _, g in ipairs(config.excluded) do
        if name:match(M.glob_to_pattern(g)) then return true end
    end
    return false
end
-- }}}

-- {{{ function M.score
-- How much a folder looks like a project: the sum of the points of the marks
-- it has. Also returns the marks found, in the order they are weighed.
function M.score(path)
    ensure_init()
    local total, found = 0, {}
    for _, w in ipairs(config.weights) do
        local flag = (w.kind == "dir") and "-d" or "-f"
        if test_path(flag, path .. "/" .. w.mark) then
            total = total + w.points
            found[#found + 1] = w.mark
        end
    end
    return total, found
end
-- }}}

-- {{{ function M.classify
-- What kind of project a folder is: the kind its build file names, or the
-- kind of source file it holds most of (in the folder itself, src/ and one
-- level below src/), or "unknown". A tie goes to the kind named first in
-- alphabetical order, so the answer does not depend on directory order.
function M.classify(path)
    for _, b in ipairs(M.BUILD_FILES) do
        if b.suffix then
            local hits = lines_of("find " .. shell_quote(path) .. " -maxdepth 1 -type f -name "
                .. shell_quote("*." .. b.file) .. " 2>/dev/null")
            if #hits > 0 then return b.type end
        elseif test_path("-f", path .. "/" .. b.file) then
            return b.type
        end
    end
    local counts = {}
    local files = lines_of("find " .. shell_quote(path) .. " -maxdepth 1 -type f 2>/dev/null; "
        .. "find " .. shell_quote(path .. "/src") .. " -maxdepth 2 -type f 2>/dev/null")
    for _, f in ipairs(files) do
        local ext = f:match("%.([%w]+)$")
        local kind = ext and M.EXTENSIONS[ext:lower()]
        if kind then counts[kind] = (counts[kind] or 0) + 1 end
    end
    local best, best_n = "unknown", 0
    for kind, n in pairs(counts) do
        if n > best_n or (n == best_n and kind < best) then best, best_n = kind, n end
    end
    return best
end
-- }}}

-- {{{ function M.examine
-- Everything known about one folder:
--   { path, name, score, marks, type, excluded, is_project }
-- An excluded folder is not scored or classified: its name already says it
-- is not a project.
function M.examine(path)
    ensure_init()
    local entry = { path = path, name = path:match("([^/]+)$") or path }
    entry.excluded = M.is_excluded(path)
    if entry.excluded then
        entry.score, entry.marks, entry.type, entry.is_project = 0, {}, nil, false
        return entry
    end
    entry.score, entry.marks = M.score(path)
    entry.is_project = entry.score >= config.threshold
    entry.type = M.classify(path)
    return entry
end
-- }}}

-- {{{ function M.scan
-- The projects directly inside the base folder, sorted by name. With
-- include_all, every folder there, each marked with is_project and excluded.
-- The base folder itself is never listed: it is the shelf, not a book.
-- (list-projects.sh's find also visits the base, so a base that scores 50
-- or more appears in its own listing; that is the one place this differs.)
-- Symbolic links to folders are not followed, as find -type d does not.
function M.scan(include_all)
    ensure_init()
    local found = {}
    local dirs = lines_of("find " .. shell_quote(config.base_dir)
        .. " -mindepth 1 -maxdepth 1 -type d 2>/dev/null")
    table.sort(dirs)
    for _, dir in ipairs(dirs) do
        local entry = M.examine(dir)
        if include_all or entry.is_project then found[#found + 1] = entry end
    end
    return found
end
-- }}}

-- {{{ local function main
-- The command form, which the bash face runs. Prints tab-separated lines.
local function main(args)
    local command, target = args[1], args[2]
    local options = { exclude = {}, weights = {} }
    local include_all = false
    local i = 3
    while i <= #args do
        local a = args[i]
        if a == "--all" then
            include_all = true
        elseif a == "--exclude" and args[i + 1] then
            options.exclude[#options.exclude + 1] = args[i + 1]; i = i + 1
        elseif a == "--only-exclude" and args[i + 1] then
            options.excluded = options.excluded or {}
            options.excluded[#options.excluded + 1] = args[i + 1]; i = i + 1
        elseif a == "--weight" and args[i + 1] then
            local mark, points = args[i + 1]:match("^(.-)=(%-?%d+)$")
            if not mark then
                io.stderr:write("--weight wants MARK=POINTS, got " .. args[i + 1] .. "\n")
                os.exit(2)
            end
            options.weights[mark] = tonumber(points); i = i + 1
        elseif a == "--threshold" and tonumber(args[i + 1] or "") then
            options.threshold = tonumber(args[i + 1]); i = i + 1
        else
            io.stderr:write("unknown option: " .. a .. "\n")
            os.exit(2)
        end
        i = i + 1
    end
    if not target or not (command == "scan" or command == "score" or command == "classify") then
        io.stderr:write("usage: project-discovery.lua scan BASE | score PATH | classify PATH [options]\n")
        os.exit(2)
    end
    if not test_path("-d", target) then
        io.stderr:write("not a folder: " .. target .. "\n")
        os.exit(2)
    end
    if command == "scan" then
        M.init(target, options)
        for _, p in ipairs(M.scan(include_all)) do
            local line = { p.path, p.name, tostring(p.score), p.type or "" }
            if include_all then
                line[5] = p.excluded and "excluded" or (p.is_project and "project" or "not-project")
            end
            print(table.concat(line, "\t"))
        end
    elseif command == "score" then
        M.init(target:match("^(.*)/[^/]+/*$") or ".", options)
        print((M.score(target)))
    else
        print(M.classify(target))
    end
end
-- }}}

-- Run as a command only when this file is the one started, never when it is
-- loaded by another script with dofile or require.
if arg and arg[0] and arg[0]:match("project%-discovery%.lua$") then
    main(arg)
end

return M
