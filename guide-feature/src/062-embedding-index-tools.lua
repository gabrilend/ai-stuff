#!/usr/bin/env luajit
-- 062-embedding-index-tools.lua - checking an embedding index, and putting
-- in place the git hooks that keep it built (issue 502).
--
-- In plain terms: two tools that go with the builder (061).
--
--   check  says whether the project's .embedding-index/ can be used: built
--          from the commit the checkout is at, its three files agreeing,
--          every vector of length 1, every piece inside its file at that
--          commit (060's check). What the look tool refuses, this names.
--   hooks  adds to the repository's post-commit, post-merge and
--          post-checkout hooks one marked block that runs the builder in the
--          background (--remove takes the blocks out). A hook the
--          repository already has keeps what it does; the block goes before
--          a last `exit` line, where it would otherwise never run. The
--          repository may be a monorepo with other projects' hooks: only
--          this project's block is touched.
--
--   scripts/check-embedding-index
--   scripts/install-index-hooks [--remove]
--   local tools = dofile(DIR .. "/src/062-embedding-index-tools.lua")
--   local ok, lines = tools.check(ROOT)
--   local lines = tools.hooks(ROOT, { remove = false })
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local index = dofile(DIR .. "/src/060-embedding-index.lua")

local M = {}

-- {{{ M.HOOKS
M.HOOKS = { "post-commit", "post-merge", "post-checkout" }
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
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function count_lines(text)
    if text == "" then return 0 end
    local _, newlines = string.gsub(text, "\n", "")
    return newlines + (string.sub(text, -1) == "\n" and 0 or 1)
end
-- }}}

-- {{{ function M.check()
-- Whether the project's index can be used, with what to say. Returns true
-- and one line, or false and the lines naming each problem.
function M.check(root)
    local commit, status = shell("git -C " .. quote(root) .. " rev-parse --verify --quiet HEAD")
    if status ~= 0 then return false, { root .. " is not a git checkout with a commit" } end
    local prefix = shell("git -C " .. quote(root) .. " rev-parse --show-prefix")
    local found, problems = index.check(root .. "/" .. index.FOLDER, {
        commit = commit,
        lines_of = function(file)
            -- printf's newline is the one shell() takes off before the status
            local text, shown = shell("git -C " .. quote(root) .. " cat-file -p " .. quote("HEAD:" .. prefix .. file)
                .. " && printf '\\n'")
            if shown ~= 0 then return nil end
            return count_lines(text)
        end,
    })
    if not found or #problems > 0 then
        local lines = { "the index at " .. root .. "/" .. index.FOLDER .. " cannot be used:" }
        for _, problem in ipairs(problems) do lines[#lines + 1] = "  - " .. problem end
        return false, lines
    end
    return true, { string.format("the index can be used: commit %s, %d pieces of %d dimensions, "
        .. "model %s, rule %s", string.sub(commit, 1, 7), found.count, found.dimensions,
        found.meta.model, found.meta.rule) }
end
-- }}}

-- {{{ function M.block()
-- The marked lines one hook gets, for the project at `root`.
function M.block(root, hook)
    return {
        "# >>> embedding index of " .. root .. " (scripts/install-index-hooks)",
        quote(root .. "/scripts/build-embedding-index") .. " --hook " .. hook
            .. ' "$@" </dev/null >/dev/null 2>&1 &',
        "# <<< embedding index of " .. root,
    }
end
-- }}}

-- {{{ function M.hooks_folder()
-- The repository's hooks folder, as git names it (core.hooksPath included).
function M.hooks_folder(root)
    local path, status = shell("cd " .. quote(root) .. " && git rev-parse --git-path hooks")
    if status ~= 0 then error("hooks: " .. root .. " is not in a git repository: " .. path, 0) end
    if string.sub(path, 1, 1) ~= "/" then path = root .. "/" .. path end
    return path
end
-- }}}

-- {{{ function M.hooks()
-- Adds (or with opts.remove, removes) this project's block in each hook.
-- Returns one line per hook saying what was done.
function M.hooks(root, opts)
    opts = opts or {}
    local folder = M.hooks_folder(root)
    shell("mkdir -p " .. quote(folder))
    local said = {}
    for _, hook in ipairs(M.HOOKS) do
        local path = folder .. "/" .. hook
        local text = slurp(path)
        local block = M.block(root, hook)
        local lines = {}
        for line in string.gmatch((text or ""), "([^\n]*)\n?") do lines[#lines + 1] = line end
        while lines[#lines] == "" do lines[#lines] = nil end
        local first, last
        for number, line in ipairs(lines) do
            if line == block[1] then first = number end
            if first and not last and line == block[3] then last = number end
        end
        if opts.remove then
            if not first then
                said[#said + 1] = hook .. ": not there"
            else
                for _ = first, last or first do table.remove(lines, first) end
                local rest = table.concat(lines, "\n")
                if string.match(rest, "^#!/bin/sh%s*$") then
                    os.remove(path)
                    said[#said + 1] = hook .. ": removed, and the hook with it (it held nothing else)"
                else
                    local handle = assert(io.open(path, "wb"))
                    handle:write(rest, "\n")
                    handle:close()
                    said[#said + 1] = hook .. ": removed"
                end
            end
        elseif first then
            said[#said + 1] = hook .. ": already there"
        else
            if #lines == 0 then lines[1] = "#!/bin/sh" end
            local at = #lines + 1
            if string.match(lines[#lines], "^%s*exit[%s%d]*$") then at = #lines end
            for offset, line in ipairs(block) do table.insert(lines, at + offset - 1, line) end
            local handle = assert(io.open(path, "wb"))
            handle:write(table.concat(lines, "\n"), "\n")
            handle:close()
            shell("chmod +x " .. quote(path))
            said[#said + 1] = hook .. ": added" .. (text and " beside what it already does" or "")
        end
    end
    return said
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "062%-embedding%-index%-tools%.lua$") then
    local root, command, remove = DIR, nil, false
    local at = 1
    while at <= #arg do
        if arg[at] == "--dir" then root = arg[at + 1]; at = at + 2
        elseif arg[at] == "--remove" then remove = true; at = at + 1
        elseif not command then command = arg[at]; at = at + 1
        else
            io.stderr:write("usage: 062-embedding-index-tools.lua [--dir ROOT] check | hooks [--remove]\n")
            os.exit(2)
        end
    end
    if command == "check" then
        local good, lines = M.check(root)
        for _, line in ipairs(lines) do print(line) end
        os.exit(good and 0 or 1)
    elseif command == "hooks" then
        local ok, lines = pcall(M.hooks, root, { remove = remove })
        if not ok then
            io.stderr:write(tostring(lines), "\n")
            os.exit(1)
        end
        for _, line in ipairs(lines) do print(line) end
        os.exit(0)
    end
    io.stderr:write("usage: 062-embedding-index-tools.lua [--dir ROOT] check | hooks [--remove]\n")
    os.exit(2)
end
-- }}}

return M
