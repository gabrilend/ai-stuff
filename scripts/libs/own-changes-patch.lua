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
--            unchanged line between, so git sees one block. This session's
--            lines are taken out of it (an agent that wrote specific lines
--            gets exactly those committed), unless both changed the same
--            place, when the order of the two cannot be told; then it is left
--            out and reported as tangled (see untangle_hunk).
-- Our blocks are kept and renumbered so they still line up once the skipped
-- ones are gone. A new or deleted file is all-or-nothing. A binary or
-- mode-only change is ours only when the file is claimed whole. A file git has
-- never seen is ours when every line in it is claimed, or it is claimed whole.
--
-- TRANSCRIPTS
--
-- A transcript that differs from the branch tip (new, grown, or gone) rides
-- along, whoever's conversation it is, when it belongs to one of the
-- commit's projects: the session's project (the folder the session runs in,
-- where the exporter writes its transcripts and where earlier sessions'
-- stragglers pile up), or the project of a file the commit carries (the
-- nearest folder above it with an llm-transcripts/ folder). A transcript
-- whose "# Conversation Summary: <id>" header names this session or a helper
-- rides along wherever it is. Transcripts are one story told across
-- conversations, and the owner wants git to hold as much of each project's
-- part of it as possible; the rule before this one took only this session's
-- transcripts, and so a session that committed, talked a little more and quit
-- left its last lines uncommittable forever (kiln, 2026-09-23). Every
-- transcript in the repository was briefly the rule, but in the monorepo that
-- put every project's transcripts into one project's commit.
-- Taking another conversation's transcript is safe where taking its source
-- lines is not: the exporter writes each transcript to a temporary file and
-- moves it into place, so what is on disk is always a whole rendering, and
-- nobody edits a transcript line by line (lasting edits live in
-- llm-transcripts/.patches/). A transcript gone from disk was renamed or
-- retired by the exporter; its deletion rides along beside its new name.
-- Accidental deletions ride along too; git's history keeps the text.
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

-- {{{ local function owner_runs()
-- One side of a change block (the removed lines, mark "-", or the added
-- lines, mark "+") cut into runs of consecutive lines with the same owner:
-- { { mine = boolean, texts = { string } } }, in file order.
local function owner_runs(claims, path, hunk, mark)
    local runs = {}
    for _, line in ipairs(hunk.lines) do
        if line:sub(1, 1) == mark then
            local text = line:sub(2)
            local mine = ledger.line_claimed(claims, path, mark, text) and true or false
            local last = runs[#runs]
            -- same owner as the line above: the run grows; otherwise a new run
            if last and last.mine == mine then
                last.texts[#last.texts + 1] = text
            else
                runs[#runs + 1] = { mine = mine, texts = { text } }
            end
        end
    end
    return runs
end
-- }}}

-- {{{ local function embed_runs()
-- Places runs, in order, into a sequence of regions (a list of owners,
-- `regions[i]` true for ours), each run into a region of its own owner.
-- `from_end` places them as late as possible instead of as early as possible.
-- Returns the region index of each run, or nil when they do not fit.
local function embed_runs(runs, regions, from_end)
    local placed = {}
    if not from_end then
        local r = 1
        for i, run in ipairs(runs) do
            while regions[r] ~= nil and regions[r] ~= run.mine do r = r + 1 end
            if regions[r] == nil then return nil end
            placed[i] = r
            r = r + 1
        end
    else
        local r = #regions
        for i = #runs, 1, -1 do
            while r >= 1 and regions[r] ~= runs[i].mine do r = r - 1 end
            if r < 1 then return nil end
            placed[i] = r
            r = r - 1
        end
    end
    return placed
end
-- }}}

-- {{{ local function region_text()
-- The committed text of a block, given where its runs were placed: region by
-- region, our regions give the lines this session added, their regions give
-- back the lines they removed (their removal is theirs to commit). Lines we
-- removed and lines they added are left out.
local function region_text(removed, added, removed_at, added_at, region_count)
    local out = {}
    for region = 1, region_count do
        for i, run in ipairs(added) do
            if run.mine and added_at[i] == region then
                for _, t in ipairs(run.texts) do out[#out + 1] = t end
            end
        end
        for i, run in ipairs(removed) do
            if not run.mine and removed_at[i] == region then
                for _, t in ipairs(run.texts) do out[#out + 1] = t end
            end
        end
    end
    return out
end
-- }}}

-- {{{ local function untangle_hunk()
-- Takes this session's lines out of a mixed block. Returns the list of lines
-- the region should hold once only this session's change is applied, or nil
-- when the order of its lines against the other's cannot be told (both
-- changed the same place). Why the order must be worked out at all: the
-- ledger records which lines are ours by their text, not where they sat, and
-- git lists a block as all its removed lines and then all its added lines.
-- The two sides' runs of ours/theirs must fit one alternating sequence of
-- regions; the shortest such sequence is the reading used, and if two
-- shortest sequences, or two placements inside one, give different text, the
-- block is truly tangled. (Worked examples: issue 032a, "Two sessions,
-- touching lines".)
local function untangle_hunk(claims, path, hunk)
    for _, line in ipairs(hunk.lines) do
        -- a "\ No newline" marker belongs to one line; splitting could move it
        if line:sub(1, 1) == "\\" then return nil end
    end
    local removed = owner_runs(claims, path, hunk, "-")
    local added = owner_runs(claims, path, hunk, "+")
    local longest = math.max(#removed, #added)
    for length = longest, #removed + #added do
        local readings = {}
        for _, first_mine in ipairs({ true, false }) do
            local regions = {}
            for i = 1, length do
                -- regions alternate owner, starting with first_mine
                regions[i] = (i % 2 == 1) == first_mine
            end
            -- every corner of where the runs could sit: earliest and latest
            for _, removed_late in ipairs({ false, true }) do
                for _, added_late in ipairs({ false, true }) do
                    local r_at = embed_runs(removed, regions, removed_late)
                    local a_at = embed_runs(added, regions, added_late)
                    if r_at and a_at then
                        readings[#readings + 1] = region_text(removed, added, r_at, a_at, length)
                    end
                end
            end
        end
        if #readings > 0 then
            -- the shortest fitting length: all its readings must agree
            local first = table.concat(readings[1], "\n")
            for i = 2, #readings do
                if table.concat(readings[i], "\n") ~= first then return nil end
            end
            return readings[1]
        end
    end
    return nil
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

    -- `shift` is how many lines further down a spot sits on disk than in the
    -- version being committed: skipped blocks' lines never land, and a block
    -- taken apart lands shorter or longer than it is on disk
    local kept, shift = {}, 0
    local untangled = 0
    for _, hunk in ipairs(entry.hunks) do
        local verdict = classify_hunk(claims, path, hunk)
        local lines = nil
        if verdict == "mixed" then
            -- this session's lines come out of it, unless it is truly tangled
            lines = untangle_hunk(claims, path, hunk)
        end
        if verdict == "ours" then
            kept[#kept + 1] = { hunk = hunk, new_start = hunk.new_start - shift }
        elseif lines then
            -- the block becomes: remove every tip line in it, add `lines`.
            -- With no context lines, a range of 0 lines names the line before
            -- it, one of 1+ lines names its first line.
            local before = (hunk.new_count == 0) and hunk.new_start or (hunk.new_start - 1)
            local body = {}
            for _, line in ipairs(hunk.lines) do
                if line:sub(1, 1) == "-" then body[#body + 1] = line end
            end
            for _, text in ipairs(lines) do body[#body + 1] = "+" .. text end
            kept[#kept + 1] = {
                hunk = { old_start = hunk.old_start, old_count = hunk.old_count,
                         new_count = #lines, suffix = hunk.suffix, lines = body },
                new_start = before - shift + ((#lines > 0) and 1 or 0),
            }
            shift = shift + (hunk.new_count - #lines)
            untangled = untangled + 1
            result.report[#result.report + 1] = string.format(
                "  untangled      %s:%d (this session's lines taken from a block that touches someone else's)", rel, hunk.new_start)
        else
            -- a skipped block's lines never land, so later blocks move up
            shift = shift + (hunk.new_count - hunk.old_count)
            -- a mixed block reaching here could not be taken apart
            local why = (verdict == "mixed") and "tangled: both changed the same place" or verdict
            result.report[#result.report + 1] = string.format("  left out       %s:%d (%s)", rel, hunk.new_start, why)
            if verdict == "mixed" then
                result.mixed[#result.mixed + 1] = string.format("%s:%d", rel, hunk.new_start)
            end
        end
    end
    if #kept == 0 then return nil, false end
    -- a new or deleted file cannot be half-made, so a block taken apart
    -- counts as not wholly ours there
    if all_or_nothing and (#kept < #entry.hunks or untangled > 0) then
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
-- sorted -- except transcripts. A transcript (any llm-transcripts/*.md) is
-- always taken whole (changed_transcripts below), never
-- line by line: the backup hook writes most of its lines, so the ledger only
-- ever holds scraps of one (from a backup run by hand, whose file diff the
-- ledger hook records), and judging those scraps made this session's own
-- transcript look tangled and stopped the whole commit (2026-09-22).
function M.ledger_files(claims, top)
    local rels = {}
    for path in pairs(claims) do
        if path:sub(1, #top + 1) == top .. "/" then
            local rel = path:sub(#top + 2)
            -- a transcript: left to the conversation rule
            -- anything else: judged by its claimed lines
            if not rel:match("llm%-transcripts/[^/]+%.md$") then rels[#rels + 1] = rel end
        end
    end
    table.sort(rels)
    return rels
end
-- }}}

-- {{{ function M.collect()
-- Judges the working tree against the staging list that `env` selects (a
-- private GIT_INDEX_FILE, normally), for the ledger's files. Returns
-- { patch = text or nil, whole = { rel }, taken = { rel } (files the patch
-- changes), report = { line }, mixed = { "rel:n" } (blocks that could not be
-- taken apart) }
-- or nil and a reason when git fails.
function M.collect(top, claims, rels, env)
    local result = { patch = nil, whole = {}, taken = {}, report = {}, mixed = {} }
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
        if patch then
            patches[#patches + 1] = patch
            result.taken[#result.taken + 1] = ledger.file_path(entry)
        end
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

-- {{{ local function transcript_project()
-- The project a transcript belongs to: the folder holding its llm-transcripts/
-- folder, repository-relative ("" for the repository's top).
local function transcript_project(rel)
    if rel:match("^llm%-transcripts/[^/]+%.md$") then return "" end
    return rel:match("^(.*)/llm%-transcripts/[^/]+%.md$")
end
-- }}}

-- {{{ function M.project_of()
-- The project a repository-relative file belongs to: the nearest folder above
-- it (inside the repository) that has an llm-transcripts/ folder, as a
-- repository-relative path ("" for the top). Nil when no folder above it has
-- one, so the file brings no transcripts with it.
function M.project_of(top, rel)
    local dir = rel:match("^(.*)/[^/]+$") or ""
    while true do
        local candidate = (dir == "") and (top .. "/llm-transcripts") or (top .. "/" .. dir .. "/llm-transcripts")
        local _, is_dir = M.run_quiet({ "test", "-d", candidate })
        if is_dir then return dir end
        -- at the top already: no project; otherwise one folder up
        if dir == "" then return nil end
        dir = dir:match("^(.*)/[^/]+$") or ""
    end
end
-- }}}

-- {{{ function M.transcript_projects()
-- The projects whose transcripts ride along in a commit, as a set of
-- repository-relative folders: the session's project, when `session_dir`
-- (the folder the session runs in, an absolute path) is inside `top`, and the
-- project of each file in `files` (repository-relative paths the commit
-- carries). Returns the set, or nil and a reason.
function M.transcript_projects(top, session_dir, files)
    local projects = {}
    -- the real path, so a symlinked spelling of the folder still matches
    local real, ok, err = M.run_quiet({ "realpath", "-e", session_dir })
    if not ok then return nil, "cannot resolve the session's folder " .. session_dir .. ": " .. err end
    real = real:gsub("%s+$", "")
    -- the session's folder: the top itself, somewhere inside, or elsewhere
    if real == top then
        projects[""] = true
    elseif real:sub(1, #top + 1) == top .. "/" then
        projects[real:sub(#top + 2)] = true
    end
    for _, rel in ipairs(files) do
        local project = M.project_of(top, rel)
        if project then projects[project] = true end
    end
    return projects
end
-- }}}

-- {{{ function M.changed_transcripts()
-- Every transcript file (any llm-transcripts/*.md in the repository) that
-- differs from the commit `tip` (new, changed, or deleted) and belongs to one
-- of `projects` (a set from transcript_projects) or is this session's by its
-- header. Read-only: nothing here takes the shared staging list's lock or
-- writes it.
-- Returns a sorted list of { rel = path (string), ours = boolean (its header
-- names one of `ids`), gone = boolean (deleted from disk) }, or nil and a
-- reason.
function M.changed_transcripts(top, tip, ids, projects)
    local glob = ":(glob)**/llm-transcripts/*.md"
    -- tracked at the tip and different on disk (changed or deleted); compared
    -- with the tip itself, not the shared staging list, so nothing anyone has
    -- staged by hand changes the answer
    local diff, ok, err = M.run_quiet({ "git", "-C", top, "--no-optional-locks", "diff",
        "--name-status", "-z", "--no-renames", tip, "--", glob })
    if not ok then return nil, "git diff failed: " .. err end
    local found = {}
    local status = nil
    for word in diff:gmatch("([^%z]+)") do
        -- -z name-status alternates: a status letter, then its path
        if not status then status = word else found[word] = (status == "D"); status = nil end
    end
    -- never tracked, and not ignored
    local others
    others, ok, err = M.run_quiet({ "git", "-C", top, "ls-files", "--others",
        "--exclude-standard", "-z", "--", glob })
    if not ok then return nil, "git ls-files failed: " .. err end
    for rel in others:gmatch("([^%z]+)") do found[rel] = false end

    local list = {}
    for rel, gone in pairs(found) do
        local ours = false
        -- a deleted transcript has no header left to read, so it counts as
        -- not ours and rides along by its project alone; a present one is
        -- read for its header
        if not gone then
            local f = io.open(top .. "/" .. rel, "r")
            if f then
                local id = (f:read("*l") or ""):match("^# Conversation Summary: (%S+)")
                f:close()
                ours = (id ~= nil and ids[id] == true)
            end
        end
        -- this session's, or in one of the commit's projects: rides along;
        -- another project's: left for a commit in that project
        if ours or projects[transcript_project(rel)] then
            list[#list + 1] = { rel = rel, ours = ours, gone = gone }
        end
    end
    table.sort(list, function(a, b) return a.rel < b.rel end)
    return list
end
-- }}}

-- {{{ function M.transcript_report_line()
-- One report line for a transcript entry from changed_transcripts().
function M.transcript_report_line(t)
    local whose = t.ours and "this conversation" or "another conversation"
    if t.gone then whose = "gone from disk, renamed or retired by the exporter" end
    return "  transcript     " .. t.rel .. " (" .. whose .. ")"
end
-- }}}

return M
