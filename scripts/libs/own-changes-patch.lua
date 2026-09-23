-- own-changes-patch.lua
--
-- Works out which of a repository's uncommitted changes are this session's own,
-- as a patch that can be applied to a staging list with `git apply --cached`.
-- Two tools share it, so they can never disagree about what "ours" means:
--   commit-own-changes   applies it to a private staging list and commits it
--   stage-own-changes    prints what commit-own-changes would commit
--
-- HOW A CHANGE IS JUDGED
--
-- git is asked for the difference between the working tree and a staging list
-- (for commit-own-changes, a private list seeded from the branch tip), for the
-- files this session's edit ledger names, with no context lines -- so every
-- change block is exactly the lines that changed. Each block is then:
--   ours     every added and removed line in it is claimed in the ledger
--   foreign  none is: another session's or person's work, left alone
--   mixed    some are: this session's lines sit against someone else's with no
--            unchanged line between, so git cannot take one without the other
-- Our blocks are kept and renumbered so they still line up once the skipped
-- ones are gone. A new or deleted file is all-or-nothing. A binary or
-- mode-only change is ours only when the file is claimed whole. A file git has
-- never seen is ours when every line in it is claimed, or it is claimed whole.
--
-- TRANSCRIPTS
--
-- A transcript rides along when it is this session's conversation: its first
-- line, "# Conversation Summary: <id>", names this session or one of its
-- helpers ("agent-<id>", found as <sessions-root>/*/<session>/subagents/
-- agent-<id>.jsonl in Claude Code's session store). Where it lives does not
-- matter, and it is taken whole, because the exporter rewrites it whole. This
-- replaced "every llm-transcripts/ folder near a touched file", which also took
-- other sessions' transcripts from the same folder.
--
-- LuaJIT compatible; no Lua 5.4 syntax.

local ledger = require("own-lines-ledger")

local M = {}

-- {{{ local function shell_quote()
local function shell_quote(word)
    return "'" .. word:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function M.command_line()
-- One shell command line from an argument list and optional environment
-- settings ({ NAME = value }), each word quoted.
function M.command_line(argv, env)
    local words = {}
    if env then
        words[1] = "env"
        local names = {}
        for name in pairs(env) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do words[#words + 1] = shell_quote(name .. "=" .. env[name]) end
    end
    for _, w in ipairs(argv) do words[#words + 1] = shell_quote(w) end
    return table.concat(words, " ")
end
-- }}}

-- {{{ function M.run()
-- Runs a command; returns its output (standard error folded in, so a failure
-- explains itself) and whether it exited 0.
function M.run(argv, env)
    local handle = io.popen(M.command_line(argv, env) .. " 2>&1", "r")
    local out = handle:read("*a")
    local ok, _, code = handle:close()
    return out, (ok == true or code == 0)
end
-- }}}

-- {{{ function M.run_quiet()
-- Runs a command keeping standard output apart from standard error: for output
-- that is data (object ids, file lists) where a warning must not mix in.
-- Returns stdout, whether it exited 0, and stderr.
function M.run_quiet(argv, env)
    local err_path = os.tmpname()
    local handle = io.popen(M.command_line(argv, env) .. " 2> " .. shell_quote(err_path), "r")
    local out = handle:read("*a")
    local ok, _, code = handle:close()
    local ef = io.open(err_path, "r")
    local err = ef and ef:read("*a") or ""
    if ef then ef:close() end
    os.remove(err_path)
    return out, (ok == true or code == 0), err
end
-- }}}

-- {{{ local function classify_hunk()
-- "ours" when every added and removed line is claimed, "foreign" when none is,
-- "mixed" otherwise.
local function classify_hunk(claims, path, hunk)
    local mine, theirs = 0, 0
    for _, line in ipairs(hunk.lines) do
        local mark = line:sub(1, 1)
        if mark == "+" or mark == "-" then
            if ledger.line_claimed(claims, path, mark, line:sub(2)) then
                mine = mine + 1
            else
                theirs = theirs + 1
            end
        end
    end
    if theirs == 0 then return "ours" end
    if mine == 0 then return "foreign" end
    return "mixed"
end
-- }}}

-- {{{ local function header_says()
-- Whether a diff entry's header carries a line starting with the given text.
local function header_says(entry, prefix)
    for _, line in ipairs(entry.header) do
        if line:sub(1, #prefix) == prefix then return true end
    end
    return false
end
-- }}}

-- {{{ local function filter_entry()
-- Decides what to take from one file's diff. Returns the patch text to apply
-- (or nil) and whether the file should instead be added whole; appends to the
-- report, and to `mixed` for every mixed block.
local function filter_entry(claims, top, entry, result)
    local rel = ledger.file_path(entry)
    local path = top .. "/" .. rel
    local c = claims[path]

    -- a change with no lines to judge -- binary content or a mode change --
    -- is ours only when the file is claimed whole
    if entry.binary or #entry.hunks == 0 then
        if c and c.whole then
            result.report[#result.report + 1] = "  whole          " .. rel .. " (binary or mode change, claimed whole)"
            return nil, true
        end
        result.report[#result.report + 1] = "  left out       " .. rel .. " (binary or mode change; claim it with claim-own-change if it is yours)"
        return nil, false
    end

    -- a new or deleted file is all-or-nothing: git cannot half-create a file
    local all_or_nothing = header_says(entry, "new file mode") or header_says(entry, "deleted file mode")

    local kept, shift = {}, 0
    for _, hunk in ipairs(entry.hunks) do
        local verdict = classify_hunk(claims, path, hunk)
        if verdict == "ours" then
            kept[#kept + 1] = { hunk = hunk, new_start = hunk.new_start - shift }
        else
            -- a skipped block's lines never land, so later blocks move up
            shift = shift + (hunk.new_count - hunk.old_count)
            result.report[#result.report + 1] = string.format("  left out       %s:%d (%s)", rel, hunk.new_start, verdict)
            if verdict == "mixed" then
                result.mixed[#result.mixed + 1] = string.format("%s:%d", rel, hunk.new_start)
            end
        end
    end
    if #kept == 0 then return nil, false end
    if all_or_nothing and #kept < #entry.hunks then
        result.report[#result.report + 1] = "  left out       " .. rel .. " (a new or deleted file with lines that are not this session's)"
        return nil, false
    end

    local out = {}
    for _, line in ipairs(entry.header) do out[#out + 1] = line end
    for _, k in ipairs(kept) do
        local h = k.hunk
        out[#out + 1] = string.format("@@ -%d,%d +%d,%d @@%s", h.old_start, h.old_count, k.new_start, h.new_count, h.suffix)
        for _, line in ipairs(h.lines) do out[#out + 1] = line end
    end
    result.report[#result.report + 1] = string.format("  ours           %s (%d of %d change blocks)", rel, #kept, #entry.hunks)
    return table.concat(out, "\n") .. "\n", false
end
-- }}}

-- {{{ local function untracked_whole()
-- A file the staging list does not have yet. Ours when every line in it is
-- claimed (it was written by this session) or it is claimed whole.
local function untracked_whole(claims, top, rel, report)
    local path = top .. "/" .. rel
    local c = claims[path]
    local f = io.open(path, "rb")
    if not f then return false end
    local content = f:read("*a")
    f:close()
    if c and c.whole then
        report[#report + 1] = "  whole          " .. rel .. " (new file, claimed whole)"
        return true
    end
    if content:find("\0", 1, true) then
        report[#report + 1] = "  left out       " .. rel .. " (new binary file; claim it with claim-own-change if it is yours)"
        return false
    end
    for line in (content:sub(-1) == "\n" and content or content .. "\n"):gmatch("(.-)\n") do
        if not ledger.line_claimed(claims, path, "+", line) then
            report[#report + 1] = "  left out       " .. rel .. " (new file with lines this session did not write)"
            return false
        end
    end
    report[#report + 1] = "  whole          " .. rel .. " (new file written by this session)"
    return true
end
-- }}}

-- {{{ function M.ledger_files()
-- The repository-relative paths this session's ledger names under `top`,
-- sorted.
function M.ledger_files(claims, top)
    local rels = {}
    for path in pairs(claims) do
        if path:sub(1, #top + 1) == top .. "/" then rels[#rels + 1] = path:sub(#top + 2) end
    end
    table.sort(rels)
    return rels
end
-- }}}

-- {{{ function M.collect()
-- Judges the working tree against the staging list that `env` selects (a
-- private GIT_INDEX_FILE, normally), for the ledger's files. Returns
-- { patch = text or nil, whole = { rel }, report = { line }, mixed = { "rel:n" } }
-- or nil and a reason when git fails.
function M.collect(top, claims, rels, env)
    local result = { patch = nil, whole = {}, report = {}, mixed = {} }
    if #rels == 0 then return result end

    -- tracked files: changed, deleted, mode-changed
    local diff_args = { "git", "-C", top, "diff", "-U0", "--no-color", "--no-ext-diff", "--no-renames",
        "--src-prefix=a/", "--dst-prefix=b/", "--" }
    for _, rel in ipairs(rels) do diff_args[#diff_args + 1] = rel end
    local diff, ok, err = M.run_quiet(diff_args, env)
    if not ok then return nil, "git diff failed: " .. err end
    local patches = {}
    for _, entry in ipairs(ledger.parse_diff(diff)) do
        local patch, add_whole = filter_entry(claims, top, entry, result)
        if patch then patches[#patches + 1] = patch end
        if add_whole then result.whole[#result.whole + 1] = ledger.file_path(entry) end
    end
    if #patches > 0 then result.patch = table.concat(patches) end

    -- files the staging list has never seen, and that are not ignored
    local others_args = { "git", "-C", top, "ls-files", "--others", "--exclude-standard", "-z", "--" }
    for _, rel in ipairs(rels) do others_args[#others_args + 1] = rel end
    local others
    others, ok, err = M.run_quiet(others_args, env)
    if not ok then return nil, "git ls-files failed: " .. err end
    for rel in others:gmatch("([^%z]+)") do
        if untracked_whole(claims, top, rel, result.report) then result.whole[#result.whole + 1] = rel end
    end
    return result
end
-- }}}

-- {{{ function M.own_ids()
-- The conversation ids that count as this session's: the session itself and
-- every helper whose log sits under its subagents/ folder.
function M.own_ids(session_id, sessions_root)
    local ids = { [session_id] = true }
    local out = M.run_quiet({ "find", sessions_root, "-mindepth", "4", "-maxdepth", "4",
        "-path", "*/" .. session_id .. "/subagents/agent-*.jsonl" })
    for path in out:gmatch("[^\n]+") do
        local name = path:match("([^/]+)%.jsonl$")
        if name then ids[name] = true end
    end
    return ids
end
-- }}}

-- {{{ function M.own_transcripts()
-- Changed or new transcript files (any llm-transcripts/*.md in the repository)
-- whose header names one of `ids`. Read-only: git status is run without
-- taking the index lock, so it never rewrites the shared staging list.
-- Returns a list of repository-relative paths, or nil and a reason.
function M.own_transcripts(top, ids)
    local out, ok, err = M.run_quiet({ "git", "-C", top, "--no-optional-locks", "status",
        "--porcelain=v1", "-z", "--no-renames", "--untracked-files=all", "--",
        ":(glob)**/llm-transcripts/*.md" })
    if not ok then return nil, "git status failed: " .. err end
    local list = {}
    for record in out:gmatch("([^%z]+)") do
        local rel = record:sub(4)
        local f = io.open(top .. "/" .. rel, "r")
        -- a deleted transcript has no header to read; deletions are not ours
        if f then
            local first = f:read("*l") or ""
            f:close()
            local id = first:match("^# Conversation Summary: (%S+)")
            if id and ids[id] then list[#list + 1] = rel end
        end
    end
    table.sort(list)
    return list
end
-- }}}

return M
