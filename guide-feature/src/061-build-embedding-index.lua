#!/usr/bin/env luajit
-- 061-build-embedding-index.lua - builds guide-feature's embedding index,
-- .embedding-index/, from the commit its checkout is at (issue 502).
--
-- In plain terms: this is the builder that docs/embedding-index-build-guide
-- .md describes, made for guide-feature by following that guide. It reads
-- the project's files at the checked-out commit (from git, not from the
-- working tree, so the index is exactly that commit's), cuts them into
-- pieces with their names (060's pieces-v1 and names-v1), asks the
-- embedder endpoint for a vector per piece, and writes the index the look
-- tool reads (docs/embedding-index-contract.md). It is run by git hooks on
-- kuvalu (scripts/install-index-hooks); the voices copy what it builds into
-- their clones (058's bring_index, issue 503).
--
-- Rebuilding is cheap. A commit that did not touch the project's folder
-- (the monorepo's other projects) only renames the index to the new commit.
-- A piece whose names are the same as in the index before keeps its vector,
-- so only changed pieces are sent to the model.
--
--   scripts/build-embedding-index [--dir ROOT] [--url URL --timeout SECONDS
--                                 [--key-file FILE]] [--hook NAME ARGS...]
--   local builder = dofile(DIR .. "/src/061-build-embedding-index.lua")
--   local done = builder.build({ root = ROOT })   -- { outcome, commit, pieces, ... }
--
-- The endpoint: --url and --timeout (a voice's turn passes the embedder line
-- of the canvas), or else the project's endpoints file, use.embedder.
-- --hook NAME is how the git hooks call it: it never fails a git command,
-- logs instead, skips a post-checkout of single files, and builds again
-- when the commit moved while it built. Settings: input/embedding-index,
-- read from the project being indexed. The log and receipt (build-embedding-
-- index) go to opts.log_root, by default the project itself. LuaJIT.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local caller = dofile(DIR .. "/src/046-model-caller.lua")
local index = dofile(DIR .. "/src/060-embedding-index.lua")

local M = {}

-- {{{ M.SETTINGS
M.SETTINGS = {
    ["extensions"]  = { type = "text", required = true },   -- files read, by extension
    ["shebang"]     = { type = "choice", of = { "on", "off" }, required = true },
    ["skip"]        = { type = "text", required = true },   -- folders left out
    ["piece-lines"] = { type = "whole", required = true },
    ["batch"]       = { type = "whole", required = true },  -- texts per embedding request
}
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
local function fail(text) error("embedding index: " .. text, 0) end
local function now()
    local pipe = io.popen("date +%s.%N")
    local value = tonumber(pipe:read("*l"))
    pipe:close()
    return value or os.time()
end
local function git(root, args) return shell("git -C " .. quote(root) .. " " .. args) end
-- }}}

-- {{{ function M.read_settings()
-- input/embedding-index of the project being indexed, read without making
-- RAM tiers in it (a voice's clone is not a place for them).
function M.read_settings(root)
    local text = slurp(root .. "/input/embedding-index")
    if not text then fail(root .. " has no input/embedding-index") end
    local source = "input/embedding-index"
    local values = settings.check(settings.parse(text, source), M.SETTINGS, source, "build-embedding-index")
    if values["piece-lines"] < 1 then fail("input/embedding-index: piece-lines must be at least 1") end
    if values.batch < 1 then fail("input/embedding-index: batch must be at least 1") end
    local wanted, skipped = {}, {}
    for word in string.gmatch(values.extensions, "[^%s%.]+") do wanted[string.lower(word)] = true end
    for word in string.gmatch(values.skip, "%S+") do skipped[#skipped + 1] = (string.gsub(word, "/+$", "")) end
    values.wanted, values.skipped = wanted, skipped
    return values
end
-- }}}

-- {{{ function M.where()
-- The project's commit (full), the project folder's tree, and its folder in
-- the repository (prefix), or an error.
function M.where(root)
    local commit, status = git(root, "rev-parse --verify --quiet HEAD")
    if status ~= 0 or not string.match(commit, "^%x+$") then fail(root .. " is not a git checkout with a commit") end
    local prefix = git(root, "rev-parse --show-prefix")
    local tree = git(root, "rev-parse " .. quote("HEAD:" .. prefix))
    return { commit = commit, tree = string.match(tree, "^%x+$") and tree or nil, prefix = prefix }
end
-- }}}

-- {{{ function M.files()
-- The project's code files at the commit, with their text:
-- { { path, text, language } }, path from the project's folder.
function M.files(root, values, place)
    local listing, status = git(root, "ls-tree -r HEAD")
    if status ~= 0 then fail("cannot list the files of " .. root .. ": " .. listing) end
    local wanted = {}
    for mode, path in string.gmatch(listing, "(%d+) blob %x+\t([^\n]+)") do
        if mode == "100644" or mode == "100755" then
            local skip = false
            for _, folder in ipairs(values.skipped) do
                if path == folder or string.sub(path, 1, #folder + 1) == folder .. "/" then skip = true end
            end
            local extension = string.match(path, "%.([%w]+)$")
            local base = string.match(path, "([^/]+)$")
            if not skip and (extension and values.wanted[string.lower(extension)]
                or not string.find(base, ".", 1, true) and values.shebang == "on") then
                wanted[#wanted + 1] = path
            end
        end
    end
    table.sort(wanted)
    if #wanted == 0 then return {} end
    -- every file's text in one git call
    local list = os.tmpname()
    local handle = assert(io.open(list, "wb"))
    for _, path in ipairs(wanted) do handle:write("HEAD:", place.prefix, path, "\n") end
    handle:close()
    local pipe = io.popen("git -C " .. quote(root) .. " cat-file --batch < " .. quote(list))
    local out = pipe:read("*a")
    pipe:close()
    os.remove(list)
    local files, at = {}, 1
    for _, path in ipairs(wanted) do
        local header_end = string.find(out, "\n", at, true)
        if not header_end then fail("git cat-file stopped early, at " .. path) end
        local size = tonumber(string.match(string.sub(out, at, header_end - 1), "^%x+ blob (%d+)$"))
        if not size then fail("git cat-file could not read " .. path) end
        local text = string.sub(out, header_end + 1, header_end + size)
        at = header_end + size + 2
        if not string.find(text, "\0", 1, true) then
            local language = index.language_of(path, string.match(text, "^[^\n]*"))
            if language then files[#files + 1] = { path = path, text = text, language = language } end
        end
    end
    return files
end
-- }}}

-- {{{ function M.endpoint_of()
-- The embedder: given, or from --url/--timeout, or the endpoints file's
-- use.embedder of `root`.
function M.endpoint_of(opts)
    if opts.endpoint then return opts.endpoint end
    if opts.url then
        local endpoint = { name = opts.name or "given", url = opts.url, kind = "embedding",
                           timeout = tonumber(opts.timeout) or 60, role = "embedder",
                           ["key-file"] = opts.key_file }
        return caller.load_key(endpoint, opts.root)
    end
    return caller.for_role(opts.root, "embedder")
end
-- }}}

-- {{{ local function lock()
-- One build at a time per project: a folder beside the index, holding the
-- builder's pid. A lock whose process is gone is taken over.
local function lock(root)
    local folder = root .. "/" .. index.FOLDER .. ".lock"
    for _ = 1, 2 do
        local _, made = shell("mkdir " .. quote(folder))
        if made == 0 then
            local handle = io.open(folder .. "/pid", "w")
            if handle then
                local pipe = io.popen("echo $PPID")
                handle:write(pipe:read("*l") or "", "\n")
                pipe:close()
                handle:close()
            end
            return folder
        end
        local pid = string.match(slurp(folder .. "/pid") or "", "%d+")
        -- alive: its /proc entry is there and it is not a zombie waiting to be reaped
        local stat = pid and slurp("/proc/" .. pid .. "/stat")
        if stat and string.match(stat, "%) (%a)") ~= "Z" then return nil end
        shell("rm -rf " .. quote(folder))
    end
    return nil
end
-- }}}

-- {{{ function M.build()
-- Builds the index for the commit the project is at. opts: root (the
-- project's folder in a git checkout), log_root (where the log and receipt
-- go; default root), endpoint or url/timeout/key_file, log (a function
-- called with each line, as well as the run's log). Returns { outcome
-- ("built", "up to date", "renamed" or "busy"), commit, pieces, files,
-- embedded, reused, model, dimensions, seconds }.
function M.build(opts)
    local started = now()
    local root = opts.root or DIR
    local log_root = opts.log_root or root
    shell("mkdir -p " .. quote(log_root .. "/output"))
    local run = goodbye.start("build-embedding-index", { root = log_root })
    local function say(line)
        run:log(line)
        if opts.log then opts.log(line) end
    end
    local held
    local ok, result = pcall(function()
        local values = M.read_settings(root)
        local place = M.where(root)
        local folder = root .. "/" .. index.FOLDER
        local before = index.read(folder)
        if before and before.meta.commit == place.commit and before.meta.rule == index.RULE then
            return { outcome = "up to date", commit = place.commit, pieces = before.count,
                     model = before.meta.model, dimensions = before.dimensions }
        end
        held = lock(root)
        if not held then
            return { outcome = "busy", commit = place.commit }
        end
        local endpoint = M.endpoint_of({ endpoint = opts.endpoint, url = opts.url, timeout = opts.timeout,
                                         key_file = opts.key_file, root = root })
        local model = caller.model_name(endpoint)
        local same_model = before and before.meta.model == model and before.meta.rule == index.RULE

        -- a commit that did not touch the project: the same index, renamed
        if same_model and place.tree and before.meta.tree == place.tree then
            local meta = {}
            for key, value in pairs(before.meta) do meta[key] = value end
            meta.commit = place.commit
            local handle = assert(io.open(folder .. "/meta.part", "wb"))
            handle:write(index.meta_text(meta))
            handle:close()
            assert(os.rename(folder .. "/meta.part", folder .. "/meta"))
            return { outcome = "renamed", commit = place.commit, pieces = before.count, model = model,
                     dimensions = before.dimensions, embedded = 0, reused = before.count }
        end

        -- the pieces
        local files = M.files(root, values, place)
        local pieces = {}
        for _, file in ipairs(files) do
            for _, piece in ipairs(index.cut(file.text, file.language, values["piece-lines"])) do
                piece.file = file.path
                pieces[#pieces + 1] = piece
            end
        end
        if #pieces == 0 then fail("there is nothing to index in " .. root .. " (no code files with names)") end

        -- vectors kept from the index before, by the piece's names
        local kept = {}
        if same_model then
            for number, piece in ipairs(before.pieces) do
                local list = {}
                for i = 0, before.dimensions - 1 do
                    list[i + 1] = before.vectors[(number - 1) * before.dimensions + i]
                end
                kept[piece.names] = list
            end
        end
        local vectors, wanted, texts = {}, {}, {}
        for number, piece in ipairs(pieces) do
            local text = table.concat(piece.names, " ")
            if kept[text] then
                vectors[number] = kept[text]
            else
                wanted[#wanted + 1] = number
                texts[#texts + 1] = text
            end
        end
        local batch = values.batch
        for first = 1, #texts, batch do
            local slice = {}
            for at = first, math.min(#texts, first + batch - 1) do slice[#slice + 1] = texts[at] end
            local got = caller.embed(endpoint, slice)
            for offset, vector in ipairs(got) do vectors[wanted[first + offset - 1]] = vector end
        end
        local dimensions = vectors[1] and #vectors[1]
        if not dimensions or dimensions < 1 then fail("the embedder gave no vector") end
        for number = 1, #pieces do
            if not vectors[number] or #vectors[number] ~= dimensions then
                fail("the embedder gave piece " .. number .. " a vector of "
                    .. tostring(vectors[number] and #vectors[number]) .. " numbers, not " .. dimensions)
            end
        end

        -- written beside, then swapped in
        local part = folder .. ".part"
        shell("rm -rf " .. quote(part))
        index.write(part, { commit = place.commit, tree = place.tree, model = model,
                            dimensions = dimensions, rule = index.RULE }, pieces, vectors)
        local found, problems = index.check(part, { commit = place.commit })
        if not found or #problems > 0 then
            shell("rm -rf " .. quote(part))
            fail("the index just written does not check: " .. table.concat(problems or {}, "; "))
        end
        shell("rm -rf " .. quote(folder .. ".old"))
        if before or slurp(folder .. "/meta") then os.rename(folder, folder .. ".old") end
        shell("rm -rf " .. quote(folder))
        assert(os.rename(part, folder))
        shell("rm -rf " .. quote(folder .. ".old"))
        return { outcome = "built", commit = place.commit, pieces = #pieces, files = #files,
                 embedded = #texts, reused = #pieces - #texts, model = model, dimensions = dimensions,
                 endpoint = endpoint.name }
    end)
    if held then shell("rm -rf " .. quote(held)) end
    if not ok then
        run:count("failed")
        say("failed: " .. tostring(result))
        run:finish()
        error(result, 0)
    end
    result.seconds = now() - started
    run:count(result.outcome == "up to date" and "up-to-date" or result.outcome)
    run:count("pieces", result.pieces or 0)
    run:count("embedded", result.embedded or 0)
    run:count("reused", result.reused or 0)
    run:count("milliseconds", math.floor(result.seconds * 1000 + 0.5))
    say(M.describe(result))
    run:finish()
    return result
end
-- }}}

-- {{{ function M.describe()
function M.describe(r)
    local short = r.commit and string.sub(r.commit, 1, 7) or "?"
    if r.outcome == "up to date" then
        return string.format("index for commit %s: up to date (%d pieces, model %s)", short, r.pieces or 0,
            tostring(r.model))
    elseif r.outcome == "busy" then
        return string.format("index for commit %s: another build of this project is running", short)
    elseif r.outcome == "renamed" then
        return string.format("index for commit %s: the project's files did not change, so the index of "
            .. "%d pieces now names this commit (%.2f seconds)", short, r.pieces, r.seconds or 0)
    end
    return string.format("index for commit %s: %d pieces from %d files, %d dimensions, model %s; "
        .. "%d embedded, %d kept, %.2f seconds", short, r.pieces, r.files, r.dimensions, r.model,
        r.embedded, r.reused, r.seconds or 0)
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "061%-build%-embedding%-index%.lua$") then
    local opts = { root = DIR }
    local hook
    local usage = "usage: build-embedding-index [--dir ROOT] [--url URL --timeout SECONDS "
        .. "[--key-file FILE]] [--hook NAME ARGS...]\n"
    local at = 1
    while at <= #arg do
        local name = arg[at]
        if name == "--hook" then
            hook = { name = arg[at + 1], args = {} }
            for rest = at + 2, #arg do hook.args[#hook.args + 1] = arg[rest] end
            break
        end
        local value = arg[at + 1]
        if value == nil then
            io.stderr:write(usage)
            os.exit(2)
        end
        if name == "--dir" then opts.root = value
        elseif name == "--url" then opts.url = value
        elseif name == "--timeout" then opts.timeout = value
        elseif name == "--key-file" then opts.key_file = value
        else
            io.stderr:write(usage)
            os.exit(2)
        end
        at = at + 2
    end
    if hook then
        -- a post-checkout of single files (its third argument 0) changes no commit
        if hook.name == "post-checkout" and hook.args[3] == "0" then os.exit(0) end
        for _ = 1, 3 do
            local ok, done = pcall(M.build, opts)
            if not ok or done.outcome == "busy" then break end
            local moved, place = pcall(M.where, opts.root)
            if not moved or place.commit == done.commit then break end
        end
        os.exit(0)   -- a hook never fails a git command; the log says what happened
    end
    local ok, done = pcall(M.build, opts)
    if not ok then
        io.stderr:write(tostring(done), "\n")
        os.exit(1)
    end
    print(M.describe(done))
    os.exit(done.outcome == "busy" and 3 or 0)
end
-- }}}

return M
