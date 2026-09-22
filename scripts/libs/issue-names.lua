-- issue-names.lua
--
-- The one place that knows how an issue file's name turns into a phase, a
-- number, and a status. The progress dashboard and the issue validator both
-- read issues through this file, so the two tools can never disagree about
-- which phase an issue belongs to.
--
-- How it works, in general terms: it lists every file under a project's
-- issues/ directory, keeps the ones whose names start like an issue, reads the
-- phase out of the name, and reads the status out of which folder the file sits
-- in. Where a name could mean two different phases, it says so instead of
-- picking one.
--
-- NAME SHAPES FOUND ON DISK (surveyed across ~70 projects, Sept 2026)
--
--   compact   522-fix-update-script     phase 5, issue 22 (the CLAUDE.md example)
--             1001-vertex-grid          phase 10, issue 01
--             16-loopback-demo          phase 1, issue 6 (usb-c-universal-encoder)
--             104a-sub-issue            the trailing letter is a sub-issue index
--   dashed    9-007-c-shared-memory     phase 9, issue 007 (neocities, symbeline)
--             10-004-command-preview    phase 10, issue 004
--   lettered  A04-issue-validator       phase A, issue 04 (scripts/, delta-version)
--
-- The compact shape is the ambiguous one. "1001" is phase 10 issue 01 if a
-- project numbers issues with two digits, and phase 1 issue 001 if it uses
-- three. The name alone cannot say which, so the split is decided per project
-- by weighing evidence (see choose_width): names that state their own phase
-- ("1020-phase-10-demo") count most; progress files and phase-N/ folders show
-- which phases exist; a width that leaves names with no valid phase, or with a
-- leading-zero phase like "02", counts against itself. With no evidence at all
-- the width is 2, because that is what the house rule's own example (522 =
-- phase 5, issue 22) uses -- and the scan says the split was not confirmed.
-- A file inside a phase-N/ folder is counted in phase N whatever its name
-- says, and a disagreement is reported (delta-version files by folder).
--
-- STATUS COMES FROM LOCATION, NOT FROM CONTENT
--
-- An issue is done when it has been moved into issues/completed/. Checkboxes
-- and "Status:" lines are not consulted: the house format does not require
-- them, so reading them would count most issues as whatever the default is.
-- Folders seen on disk and what they mean are in location_status below; a
-- folder not in that table is reported, not guessed.

local issue_names = {}

-- {{{ local location_status
-- First folder under issues/ -> what an issue file sitting there means.
--   open       still to be built
--   completed  built; the file is a finished blueprint
--   retired    deliberately not built (superseded, will not implement)
--   skip       not issue files at all (demo programs, worked examples, notes)
local location_status = {
    [""]                   = "open",       -- directly in issues/
    ["pending"]            = "open",
    ["unsorted"]           = "open",
    ["please-sort"]        = "open",
    ["design-driven"]      = "open",
    ["completed"]          = "completed",
    ["done"]               = "completed",
    ["superseded"]         = "retired",
    ["will-not-implement"] = "retired",
    ["declined"]           = "retired",    -- wow-chat-2026
    ["archive"]            = "retired",    -- world-edit-to-execute's shelved designs
    ["demos"]              = "skip",
    ["examples"]           = "skip",
    ["analysis"]           = "skip",
}
issue_names.location_status = location_status
-- }}}

-- {{{ local function status_for_location
-- phase-N/ folders hold open issues of that phase; any other folder name not in
-- the table above comes back as "unknown" so the caller can report it.
local function status_for_location(folder)
    local known = location_status[folder]
    if known then
        return known
    end
    if folder:match("^phase%-%d+$") or folder:match("^phase%-[A-Z]$") then
        return "open"
    end
    return "unknown"
end
-- }}}

-- {{{ local function is_progress_name
-- Progress files share the issue directory and sometimes the issue name shape
-- ("10-progress.md", "5-progress.md", "phase-3-progress.md"); they are the
-- phase's story, not an issue.
local function is_progress_name(stem)
    return stem == "progress" or stem:match("%-progress$") ~= nil
end
-- }}}

-- {{{ local function split_name
-- Reads the shape of one file name. Returns a table with the shape and the raw
-- pieces, or nil when the name does not start like an issue at all (README.md,
-- CLAUDE.md, PRIORITY.md, phase-2-demo.md ...). The compact shape's phase is
-- not decided here -- it needs the project-wide width, see phase_of_compact.
local function split_name(filename)
    local stem = filename:gsub("%.md$", "")
    local has_extension = stem ~= filename
    if is_progress_name(stem) then
        return nil
    end

    -- lettered: A04-descr / A04b-descr
    local letter, number, index, descr = stem:match("^([A-Z])(%d+)([a-z]?)%-(.+)$")
    if letter then
        return { shape = "lettered", phase = letter, number = number,
                 index = index, descr = descr, id = letter .. number .. index,
                 has_extension = has_extension }
    end

    -- dashed: 9-007-descr / 10-004c-descr. The second group must be three
    -- digits, which keeps "101-3d-view" (compact, description "3d-view") from
    -- being read as phase 101 issue 3.
    local dphase, dnumber, dindex, ddescr = stem:match("^(%d%d?)%-(%d%d%d)([a-z]?)%-(.+)$")
    if dphase then
        return { shape = "dashed", phase = tostring(tonumber(dphase)),
                 number = dnumber, index = dindex, descr = ddescr,
                 id = dphase .. "-" .. dnumber .. dindex,
                 has_extension = has_extension }
    end

    -- compact: 522-descr / 1001a-descr / 16-descr
    local digits, cindex, cdescr = stem:match("^(%d+)([a-z]?)%-(.+)$")
    if digits then
        return { shape = "compact", digits = digits, index = cindex,
                 descr = cdescr, id = digits .. cindex,
                 has_extension = has_extension }
    end

    return nil
end
issue_names.split_name = split_name
-- }}}

-- {{{ local function phase_of_compact
-- Splits a compact name's digits into phase and issue number, given how many
-- trailing digits the project uses for the issue number. Returns nil when the
-- name is too short to hold a phase at that width (e.g. "07" at width 2): such
-- a name is ambiguous and is reported rather than assigned.
local function phase_of_compact(digits, width)
    if #digits <= width then
        return nil, nil
    end
    local phase_digits = digits:sub(1, #digits - width)
    -- nobody writes a phase with a leading zero: "023" split as phase "02" is
    -- the wrong width, not phase 2 (delta-version numbers 001-057 in sequence)
    if #phase_digits > 1 and phase_digits:sub(1, 1) == "0" then
        return nil, nil
    end
    return tostring(tonumber(phase_digits)), digits:sub(#digits - width + 1)
end
issue_names.phase_of_compact = phase_of_compact
-- }}}

-- {{{ local function list_files
-- Every regular file under the issues directory, as paths relative to it.
-- `find` writes its own complaints to stderr, which is left visible on purpose.
local function list_files(issues_dir)
    local files = {}
    local handle = io.popen("find '" .. issues_dir:gsub("'", "'\\''") .. "' -type f")
    for line in handle:lines() do
        files[#files + 1] = line:sub(#issues_dir + 2)
    end
    handle:close()
    table.sort(files)
    return files
end
-- }}}

-- {{{ local function collect_known_phases
-- Evidence that a phase exists: a phase-N-progress.md or N-progress.md file
-- (anywhere under issues/) or a phase-N/ folder. Returns a set of phase strings.
local function collect_known_phases(relative_paths)
    local known = {}
    for _, rel in ipairs(relative_paths) do
        for piece in rel:gmatch("[^/]+") do
            local phase = piece:match("^phase%-(%w+)%-progress%.md$")
                or piece:match("^(%w+)%-progress%.md$")
                or piece:match("^phase%-(%w+)$")
            if phase and phase ~= "phase" then
                known[tostring(tonumber(phase) or phase)] = true
            end
        end
    end
    return known
end
-- }}}

-- {{{ local function named_phase
-- Some issues say their own phase in their description: "1020-phase-10-demo",
-- "113-phase-1-demo", "1309-the-phase-13-demo". That is the strongest evidence
-- of how the project splits its digits. Returns the phase string or nil.
local function named_phase(descr)
    local phase = ("-" .. descr .. "-"):match("%-phase%-(%d+)%-")
    return phase and tostring(tonumber(phase)) or nil
end
-- }}}

-- {{{ local function choose_width
-- Picks how many trailing digits a compact name spends on the issue number by
-- scoring each candidate width against the evidence:
--   +10  a name that says its own phase ("phase-10-demo") splits to that phase
--   -10  ... splits to some other phase
--    +1  a name splits into a phase that has a progress file or folder
--    -1  a name has no valid phase at this width (too short, leading zero)
-- Ties go to 2, the house rule's width. Returns the width and whether any
-- positive evidence supported it.
local function choose_width(compact_names, known)
    local best_width, best_score, best_support = 2, nil, 0
    for _, width in ipairs({ 2, 1, 3 }) do  -- 2 first, so it wins ties
        local score, support = 0, 0
        for _, name in ipairs(compact_names) do
            local phase = phase_of_compact(name.digits, width)
            local says = named_phase(name.descr)
            -- the name states its phase: agreement or disagreement is decisive
            if phase and says then
                local agrees = phase == says
                score = score + (agrees and 10 or -10)
                support = support + (agrees and 1 or 0)
            -- no valid phase at this width counts against the width
            elseif not phase then
                score = score - 1
            -- a phase with a progress file or folder is mild support
            elseif known[phase] then
                score, support = score + 1, support + 1
            end
        end
        if best_score == nil or score > best_score then
            best_width, best_score, best_support = width, score, support
        end
    end
    return best_width, best_support > 0
end
-- }}}

-- {{{ local function scan
-- Reads a whole project's issues. Returns:
--   issues   list of { path, rel, filename, shape, id, phase, number, index,
--                      descr, status, has_extension }   (phase nil = ambiguous)
--   report   { width, has_compact, width_confirmed, known_phases,
--              ambiguous = {...}, unknown_locations = {...},
--              phases_without_evidence = {...}, folder_disagreements = {...},
--              skipped = n }
-- Raises an error when the project has no issues/ directory, so a mistyped
-- path fails loudly instead of reporting an empty project.
local function scan(project_dir)
    local issues_dir = project_dir .. "/issues"
    local probe = io.open(issues_dir .. "/.", "r")
    if not probe then
        error("no issues directory at " .. issues_dir, 0)
    end
    probe:close()

    local relative_paths = list_files(issues_dir)
    local known = collect_known_phases(relative_paths)

    local candidates, compact_names, skipped = {}, {}, 0
    for _, rel in ipairs(relative_paths) do
        local filename = rel:match("([^/]+)$")
        local folder = rel:match("^([^/]+)/") or ""
        local status = status_for_location(folder)
        local parsed = split_name(filename)
        -- a file that is not issue-shaped, or sits in a skip folder, is not an
        -- issue; it is only counted so the totals can be reconciled
        if not parsed or status == "skip" then
            skipped = skipped + 1
        else
            parsed.rel, parsed.filename = rel, filename
            parsed.path = issues_dir .. "/" .. rel
            parsed.status = status
            parsed.folder = folder
            candidates[#candidates + 1] = parsed
            if parsed.shape == "compact" then
                compact_names[#compact_names + 1] = parsed
            end
        end
    end

    local width, width_confirmed = choose_width(compact_names, known)
    local report = {
        width = width, has_compact = #compact_names > 0,
        width_confirmed = width_confirmed, known_phases = known,
        ambiguous = {}, unknown_locations = {}, phases_without_evidence = {},
        folder_disagreements = {}, skipped = skipped,
    }

    local unevidenced = {}
    for _, issue in ipairs(candidates) do
        if issue.shape == "compact" then
            issue.phase, issue.number = phase_of_compact(issue.digits, width)
        end
        -- a phase-N/ folder is the author placing the file in phase N by hand,
        -- which outranks the name; a name that disagrees is reported
        -- name_phase keeps what the name alone says, for numbering new issues
        issue.name_phase = issue.phase
        local folder_phase = issue.folder:match("^phase%-(%w+)$")
        if folder_phase then
            folder_phase = tostring(tonumber(folder_phase) or folder_phase)
            if issue.phase ~= folder_phase then
                report.folder_disagreements[#report.folder_disagreements + 1] =
                    issue.rel .. " (name reads as phase " .. tostring(issue.phase) .. ")"
            end
            issue.phase = folder_phase
        end
        -- no phase at this width: report it, never assign one
        if not issue.phase then
            report.ambiguous[#report.ambiguous + 1] = issue.rel
        -- a phase nobody wrote a progress file or folder for is worth saying,
        -- once per phase, only when the project keeps such evidence at all
        elseif next(known) and not known[issue.phase] then
            unevidenced[issue.phase] = true
        end
        if issue.status == "unknown" then
            report.unknown_locations[#report.unknown_locations + 1] = issue.rel
        end
    end
    for phase in pairs(unevidenced) do
        report.phases_without_evidence[#report.phases_without_evidence + 1] = phase
    end
    table.sort(report.phases_without_evidence)

    return candidates, report
end
issue_names.scan = scan
-- }}}

-- {{{ local function phase_sort_key
-- Numbers sort numerically and before letters, so phase 10 follows phase 9 and
-- phase A follows both.
local function phase_sort_key(phase)
    local n = tonumber(phase)
    if n then
        return string.format("0%08d", n)
    end
    return "1" .. phase
end
issue_names.phase_sort_key = phase_sort_key
-- }}}

-- {{{ local function format_id
-- Writes an issue id in the project's own shape: compact 5 + 22 -> "522",
-- dashed 9 + 14 -> "9-014", lettered A + 8 -> "A08".
local function format_id(shape, phase, number, width)
    local formatters = {
        compact  = function() return phase .. string.format("%0" .. width .. "d", number) end,
        dashed   = function() return phase .. "-" .. string.format("%03d", number) end,
        lettered = function() return phase .. string.format("%02d", number) end,
    }
    return formatters[shape]()
end
issue_names.format_id = format_id
-- }}}

return issue_names
