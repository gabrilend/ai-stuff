-- history-phases.lua - a project's commits read from git, and where its
-- history breaks into phases.
--
-- Shared by roadmap-from-history.lua (issue 051b) and issues-from-history.lua
-- (051c). No model is involved: everything here comes from git.
--
--   M.commit_stream(project)  every commit touching the folder, oldest first,
--                             merges left out: hash, time, date, subject,
--                             files, lines and paths (relative to the folder).
--                             nil and a reason outside git.
--   M.score_breaks(commits, gap_days)   where a phase might start, and why
--   M.choose_breaks(candidates, count, max_phases)   the strongest of them
--   M.build_phases(commits, breaks)     the phases, with plain names
--   M.phases(project, options)          all of the above in one call:
--                             options.max_phases, options.gap_days
--   M.folder_of(path)         a path's top-level folder, or "(top level)"

local M = {}

-- {{{ Configuration
M.config = {
    max_phases = 8,
    min_phase_commits = 3,       -- no phase is shorter than this
    gap_days = 14,
    large_files = 20,            -- a commit this wide, or
    large_lines = 1000,          -- this many lines changed, is "large"
    threshold = 2,               -- the score a break needs to start a phase
    weights = { gap = 3, version = 3, readme = 1, large = 1, new_folder = 1 },
    accomplishments = 5,
}
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function run()
local function run(command)
    local handle = io.popen(command .. " 2>/dev/null")
    if not handle then return "" end
    local out = handle:read("*a")
    handle:close()
    return out
end
-- }}}

-- {{{ function M.commit_stream()
-- Every commit touching the folder, oldest first, with what it changed.
-- Paths are relative to the project folder.
function M.commit_stream(project)
    local git = "git -C " .. shell_quote(project)
    local top = run(git .. " rev-parse --show-toplevel"):gsub("%s+$", "")
    if top == "" then return nil, project .. " is not inside a git repository" end
    local log = run(git .. " log --reverse --no-merges --no-renames --relative --numstat"
        .. " --date=short --format=%x1e%H%x1f%at%x1f%ad%x1f%s -- .")
    local commits = {}
    for record in log:gmatch("\30([^\30]*)") do
        local header, rest = record:match("^([^\n]*)\n?(.*)$")
        local hash, stamp, date, subject = header:match("^(%x+)\31(%d+)\31([^\31]*)\31(.*)$")
        if hash then
            local commit = { hash = hash:sub(1, 7), time = tonumber(stamp), date = date,
                             subject = subject, files = 0, lines = 0, paths = {} }
            for added, deleted, path in rest:gmatch("([%d%-]+)\t([%d%-]+)\t([^\n]+)") do
                commit.files = commit.files + 1
                local changed = (tonumber(added) or 0) + (tonumber(deleted) or 0)
                commit.lines = commit.lines + changed
                commit.paths[#commit.paths + 1] = { path = path, lines = changed }
            end
            commits[#commits + 1] = commit
        end
    end
    return commits
end
-- }}}

-- {{{ function M.folder_of()
function M.folder_of(path)
    return path:match("^([^/]+)/") or "(top level)"
end
-- }}}

-- {{{ function M.score_breaks()
-- For each commit after the first, why a phase might start there. A break
-- before commit i scores the quiet spell since commit i-1, a version or
-- release made in commit i-1 (it closes a phase), a README update in
-- commit i-1, and commit i being large or the first in a new folder.
function M.score_breaks(commits, gap_days)
    local w, seen, candidates = M.config.weights, {}, {}
    for _, entry in ipairs(commits[1] and commits[1].paths or {}) do seen[M.folder_of(entry.path)] = true end
    for index = 2, #commits do
        local before, commit, reasons, score = commits[index - 1], commits[index], {}, 0
        local days = math.floor((commit.time - before.time) / 86400)
        if days >= gap_days then
            score = score + w.gap
            reasons[#reasons + 1] = days .. " days after the commit before"
        end
        local lower = before.subject:lower()
        if lower:match("%f[%w]v?%d+%.%d+") or lower:match("%f[%a]release") then
            score = score + w.version
            reasons[#reasons + 1] = "follows a version or release (" .. before.hash .. ")"
        end
        for _, entry in ipairs(before.paths) do
            if entry.path:match("^[Rr][Ee][Aa][Dd][Mm][Ee]") then
                score = score + w.readme
                reasons[#reasons + 1] = "follows a README update (" .. before.hash .. ")"
                break
            end
        end
        if commit.files >= M.config.large_files or commit.lines >= M.config.large_lines then
            score = score + w.large
            reasons[#reasons + 1] = string.format("a large commit (%d files, %d lines)", commit.files, commit.lines)
        end
        local new = {}
        for _, entry in ipairs(commit.paths) do
            local folder = M.folder_of(entry.path)
            if not seen[folder] then
                seen[folder] = true
                if folder ~= "(top level)" then new[#new + 1] = folder .. "/" end
            end
        end
        if #new > 0 then
            score = score + w.new_folder
            reasons[#reasons + 1] = "first work in " .. table.concat(new, ", ")
        end
        if score >= M.config.threshold then
            candidates[#candidates + 1] = { index = index, score = score, reasons = reasons }
        end
    end
    return candidates
end
-- }}}

-- {{{ function M.choose_breaks()
-- The strongest breaks, as long as every phase keeps its minimum length,
-- up to max_phases - 1 of them. Ties go to the earlier break.
function M.choose_breaks(candidates, count, max_phases)
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.index < b.index
    end)
    local chosen = {}
    for _, candidate in ipairs(candidates) do
        if #chosen >= max_phases - 1 then break end
        local fits = candidate.index - 1 >= M.config.min_phase_commits
            and count - candidate.index + 1 >= M.config.min_phase_commits
        for _, other in ipairs(chosen) do
            if math.abs(other.index - candidate.index) < M.config.min_phase_commits then fits = false end
        end
        if fits then chosen[#chosen + 1] = candidate end
    end
    table.sort(chosen, function(a, b) return a.index < b.index end)
    return chosen
end
-- }}}

-- {{{ function M.build_phases()
function M.build_phases(commits, breaks)
    local phases, starts = {}, { { index = 1, reasons = {} } }
    for _, entry in ipairs(breaks) do starts[#starts + 1] = entry end
    for number, start in ipairs(starts) do
        local stop = (starts[number + 1] and starts[number + 1].index - 1) or #commits
        local slice, lines_by_folder = {}, {}
        for index = start.index, stop do
            slice[#slice + 1] = commits[index]
            for _, entry in ipairs(commits[index].paths) do
                local folder = M.folder_of(entry.path)
                lines_by_folder[folder] = (lines_by_folder[folder] or 0) + entry.lines
            end
        end
        local areas = {}
        for folder, lines in pairs(lines_by_folder) do areas[#areas + 1] = { folder = folder, lines = lines } end
        table.sort(areas, function(a, b)
            if a.lines ~= b.lines then return a.lines > b.lines end
            return a.folder < b.folder
        end)
        local area_names = {}
        for index = 1, math.min(3, #areas) do
            area_names[index] = areas[index].folder == "(top level)" and "the top level"
                or (areas[index].folder .. "/")
        end
        -- The largest commits, shown in the order they were made.
        local ranked = {}
        for position, commit in ipairs(slice) do ranked[#ranked + 1] = { position = position, commit = commit } end
        table.sort(ranked, function(a, b)
            if a.commit.lines ~= b.commit.lines then return a.commit.lines > b.commit.lines end
            return a.position < b.position
        end)
        local picked = {}
        for index = 1, math.min(M.config.accomplishments, #ranked) do picked[index] = ranked[index] end
        table.sort(picked, function(a, b) return a.position < b.position end)
        local accomplishments = {}
        for index, entry in ipairs(picked) do accomplishments[index] = entry.commit.subject end

        local first, last = slice[1], slice[#slice]
        phases[number] = {
            number = number,
            commits = #slice,
            from = first.date, to = last.date,
            first = first.hash, last = last.hash,
            areas = area_names,
            accomplishments = accomplishments,
            starts_because = start.reasons,
            subjects = slice,
            name = #area_names > 0 and ("Work in " .. table.concat(area_names, " and ", 1, math.min(2, #area_names)))
                or "Work",
            description = string.format("%d commit%s from %s to %s%s, from \"%s\" to \"%s\".", #slice,
                #slice == 1 and "" or "s", first.date, last.date,
                #area_names > 0 and (", most changes in " .. table.concat(area_names, ", ")) or "",
                first.subject, last.subject),
            named_by = "heuristics",
        }
    end
    return phases
end
-- }}}

-- {{{ function M.phases()
-- The commits and their phases in one call. nil and a reason when the folder
-- is outside git or no commit touches it.
function M.phases(project, options)
    options = options or {}
    local commits, why = M.commit_stream(project)
    if not commits then return nil, why end
    if #commits == 0 then return nil, "no commits touch " .. project end
    local breaks = M.choose_breaks(M.score_breaks(commits, options.gap_days or M.config.gap_days),
        #commits, options.max_phases or M.config.max_phases)
    return commits, M.build_phases(commits, breaks)
end
-- }}}

return M
