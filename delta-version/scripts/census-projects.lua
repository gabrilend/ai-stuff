#!/usr/bin/env luajit
-- census-projects.lua - Count the monorepo: every project in it, how many
-- issues each one has filed, and how many of those are finished.
--
-- The root README used to carry these numbers as hand-typed prose, which meant
-- they were wrong the day after they were written. This script is where they
-- come from now.
--
-- It lists every project, not only the ones with issue tracking. A directory
-- holding nothing but a `vision` document is a project here -- the repository's
-- own epigraph says a project does not have to be more than a series of
-- documents -- and leaving those out of the count made the repository look
-- smaller and tidier than it is. Each project is reported in one of four states:
--
--   tracked   -- has issue files; the completed figure is meaningful
--   building  -- has source or documents but no issues filed yet
--   vision    -- a vision document and little else: an intention, not yet work
--   empty     -- a directory with nothing in it, reported so it gets noticed
--
-- What counts as an issue: a name that opens with an identifier containing a
-- digit and ends at a dash -- `301-feature.md`, `522a-sub-issue.md`,
-- `A02-lettered-phase.md`. It may be a markdown file or a directory, because
-- early projects kept an issue as a folder of pages; such a directory counts
-- once and is not descended into. Progress trackers and demo runners are not
-- issues.
--
-- Where an issue sits decides its state, and there are three:
--   open       -- in issues/, or in a phase-n/ subdirectory of it
--   completed  -- under issues/completed/, or issues/done/, at any depth
--   archived   -- under issues/archive/ or issues/superseded/, which is a
--                 different claim: work set aside or overtaken, rather than
--                 finished. Counted and reported separately so that shelving a
--                 mode cannot quietly inflate a percentage.
--
-- Usage:
--   census-projects.lua               -- terminal summary
--   census-projects.lua --markdown    -- the README's tables
--   census-projects.lua --json        -- machine-readable
--   census-projects.lua --conventions -- how many projects keep each house rule
--   census-projects.lua --write-readme -- rewrite the figures in the root README
--   census-projects.lua --check-readme -- name the README figures gone stale
--   census-projects.lua --say=91      -- a number in words (the README's prose form)
--
-- Options, in any position:
--   --dir=/path/to/delta-version      -- census a checkout elsewhere; the
--                                        monorepo is that directory's parent
--   --readme=/path/to/README.md       -- splice a different file (tests use it)
--
-- The README's figures sit between invisible markers,
--   <!-- census:projects:words -->ninety-one<!-- /census -->
-- naming a slot (what to count) and a format (how to write it). See the
-- "README slots" section below, and census-projects.info.md.

-- {{{ DIR Configuration
-- Hard-coded path so the script runs from any directory. Options are pulled
-- out of the argument list wherever they sit, so the mode can come first or
-- last; what remains is the mode.
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local README_OVERRIDE = nil
do
    local remaining = {}
    for _, argument in ipairs(arg) do
        local dir_value = argument:match("^%-%-dir=(.+)$")
        local readme_value = argument:match("^%-%-readme=(.+)$")
        if dir_value then
            DIR = dir_value
        elseif readme_value then
            README_OVERRIDE = readme_value
        else
            remaining[#remaining + 1] = argument
        end
    end
    for index = #arg, 1, -1 do arg[index] = nil end
    for index, argument in ipairs(remaining) do arg[index] = argument end
end
local MONOREPO_ROOT = DIR:match("(.*)/.+$") or "."
local README_PATH = README_OVERRIDE or (MONOREPO_ROOT .. "/README.md")
local FOCUS_PATH = DIR .. "/assets/project-focus.lua"
local DASHBOARD_PATH = MONOREPO_ROOT .. "/scripts/progress-dashboard.lua"
-- }}}

-- {{{ Configuration
local config = {
    -- Repository furniture: real directories that are not projects. Shared
    -- third-party code, loose notes, the transcripts of the work itself, the
    -- container's own helper scripts. Printed as skipped rather than dropped.
    furniture = {
        libs = true, notes = true, ideas = true, skills = true,
        ["llm-transcripts"] = true, ["docker-scripts"] = true,
        tmp = true, output = true, input = true,
    },
    -- Directories whose children are the projects: a shelf, not a project.
    -- `new-projects` keeps a vision of its own beside its children; that
    -- document belongs to the shelf and is not counted as a project.
    containers = {
        ["games"] = true,
        ["game-design"] = true,
        ["roms"] = true,
        ["new-projects"] = true,
        ["symbeline-realms/subprojects"] = true,
    },
    -- Copies rather than projects: a backup, a generated duplicate under an
    -- output directory, a dated archive of a retired mode, one project's
    -- working copy kept inside another's tree.
    not_a_project = {
        "/backups", "/output/", "/archives",
        "^scripts/world%-edit%-to%-execute$",
    },
    finished_folders = { completed = true, done = true },
    shelved_folders = { archive = true, superseded = true },
    ignored_folders = { demos = true, tmp = true },
    -- A directory is being built if it holds any of these.
    work_markers = { "src", "docs", "tests", "assets", "scripts", "main.lua",
                     "Makefile", "Cargo.toml", "package.json", "index.html",
                     "README.md", "conf.lua" },
    -- A directory is an intention if it holds one of these and nothing above.
    vision_markers = { "vision", "vision-2", "notes", "GDD.txt" },
    -- Changes the activity ranking does not count, matched against the part
    -- of a path inside its project. These are materials a project consumes or
    -- produces rather than work done on it: input/ is what it reads, output/
    -- and docs/HTML/ are what it generates (one regenerated HTML copy touched
    -- fifteen hundred files in a quarter), and llm-transcripts/ is the saved
    -- conversation, which rides along with commits whatever the work was.
    activity_excluded = { "^input/", "^output/", "^docs/HTML/", "^llm%-transcripts/" },
}
-- }}}

-- {{{ Utility Functions

-- {{{ local function read_command()
local function read_command(command)
    local pipe = io.popen(command)
    if not pipe then error("could not run: " .. command) end
    local lines = {}
    for line in pipe:lines() do
        if line ~= "" then lines[#lines + 1] = line end
    end
    pipe:close()
    return lines
end
-- }}}

-- {{{ local function entries_of()
local function entries_of(path)
    return read_command(string.format("ls -A %q 2>/dev/null", path))
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    return read_command(string.format("test -e %q && echo yes || echo no", path))[1] == "yes"
end
-- }}}

-- {{{ local function is_directory()
local function is_directory(path)
    return read_command(string.format("test -d %q && echo yes || echo no", path))[1] == "yes"
end
-- }}}

-- {{{ local function is_a_copy()
local function is_a_copy(relative_path)
    for _, pattern in ipairs(config.not_a_project) do
        if relative_path:match(pattern) then return true end
    end
    return false
end
-- }}}

-- {{{ local function looks_like_an_issue()
-- An issue's name opens with an identifier that contains a digit and ends at a
-- dash. Everything else in an issues directory is scaffolding -- progress
-- trackers, demo runners, loose notes -- however useful it is.
local function looks_like_an_issue(name)
    local identifier = name:match("^([%w]+)%-")
    if not identifier then return false end
    return identifier:match("%d") ~= nil
end
-- }}}

-- {{{ local function holds_any()
local function holds_any(path, names)
    for _, name in ipairs(names) do
        if exists(path .. "/" .. name) then return true end
    end
    return false
end
-- }}}

-- }}}

-- {{{ Counting

-- {{{ local function walk_issues()
-- Descends one issues directory, adding to the tally under the state it is
-- currently in. A `completed/` or `done/` folder changes the state for
-- everything below it; an `archive/` or `superseded/` folder sets the shelved
-- state instead. An issue that is itself a directory is counted once and left
-- unopened -- the pages inside are its body, not more issues.
local function walk_issues(path, state, tally)
    for _, name in ipairs(entries_of(path)) do
        local child = path .. "/" .. name
        local bare = name:gsub("%.md$", "")

        if looks_like_an_issue(bare) then
            tally[state] = tally[state] + 1
        elseif config.ignored_folders[name] then
            -- a deliverable, not a ticket: left alone on purpose
        elseif is_directory(child) then
            local inner = state
            if config.finished_folders[name] then
                inner = "completed"
            elseif config.shelved_folders[name] then
                inner = "archived"
            end
            walk_issues(child, inner, tally)
        end
    end
end
-- }}}

-- {{{ local function issues_directory_of()
-- Most projects keep `issues/` at their root; a few keep it under `src/`.
local function issues_directory_of(project_path)
    for _, candidate in ipairs({ "/issues", "/src/issues" }) do
        local path = project_path .. candidate
        if is_directory(path) then return path end
    end
    return nil
end
-- }}}

-- {{{ local function inspect()
-- One project's state and, if it has any, its tally.
local function inspect(relative, project_path)
    local record = { name = relative, open = 0, completed = 0, archived = 0,
                     total = 0, percent = 0 }

    local issues_dir = issues_directory_of(project_path)
    if issues_dir then
        local tally = { open = 0, completed = 0, archived = 0 }
        walk_issues(issues_dir, "open", tally)
        record.open, record.completed, record.archived =
            tally.open, tally.completed, tally.archived
        record.total = tally.open + tally.completed + tally.archived
    end

    if record.total > 0 then
        record.state = "tracked"
        record.percent = math.floor((record.completed / record.total) * 100 + 0.5)
    elseif holds_any(project_path, config.work_markers) then
        record.state = "building"
    elseif holds_any(project_path, config.vision_markers) then
        record.state = "vision"
    elseif #entries_of(project_path) == 0 then
        record.state = "empty"
    else
        record.state = "building"
    end

    return record
end
-- }}}

-- {{{ local function gather()
local function gather()
    local projects, furniture, copies = {}, {}, {}
    -- A shelf may hold loose notes beside its project directories. Each is an
    -- idea written down and not yet given a directory of its own; counted, so
    -- that the shelf's contents are not silently halved.
    local ideas = {}

    -- {{{ local function consider(relative)
    local function consider(relative)
        local path = MONOREPO_ROOT .. "/" .. relative
        if is_a_copy(relative) then
            copies[#copies + 1] = relative
            return
        end
        projects[#projects + 1] = inspect(relative, path)
    end
    -- }}}

    for _, name in ipairs(entries_of(MONOREPO_ROOT)) do
        local path = MONOREPO_ROOT .. "/" .. name
        if name:match("^%.") or not is_directory(path) then
            -- hidden directories and loose files are not projects
        elseif config.furniture[name] then
            furniture[#furniture + 1] = name
        elseif config.containers[name] then
            local loose = 0
            for _, child in ipairs(entries_of(path)) do
                if is_directory(path .. "/" .. child) then
                    consider(name .. "/" .. child)
                else
                    loose = loose + 1
                end
            end
            if loose > 0 then
                ideas[#ideas + 1] = { shelf = name, count = loose }
            end
        else
            consider(name)
            -- a project may shelve subprojects of its own
            local shelf = name .. "/subprojects"
            if config.containers[shelf] then
                for _, child in ipairs(entries_of(path .. "/subprojects")) do
                    consider(shelf .. "/" .. child)
                end
            end
        end
    end

    table.sort(projects, function(a, b)
        if a.state ~= b.state then
            local rank = { tracked = 1, building = 2, vision = 3, empty = 4 }
            return rank[a.state] < rank[b.state]
        end
        if a.percent ~= b.percent then return a.percent > b.percent end
        if a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)

    return projects, furniture, copies, ideas
end
-- }}}

-- {{{ local function totals()
local function totals(projects)
    local counted = { completed = 0, archived = 0, all = 0 }
    local states = { tracked = 0, building = 0, vision = 0, empty = 0 }
    for _, project in ipairs(projects) do
        counted.completed = counted.completed + project.completed
        counted.archived = counted.archived + project.archived
        counted.all = counted.all + project.total
        states[project.state] = states[project.state] + 1
    end
    -- A checkout with no issues at all has no percentage to speak of; zero
    -- is the honest figure. (Dividing 0 by 0 gave NaN, which LuaJIT printed
    -- as the most negative integer it can hold.)
    if counted.all > 0 then
        counted.percent = math.floor((counted.completed / counted.all) * 100 + 0.5)
    else
        counted.percent = 0
    end
    return counted, states
end
-- }}}

-- {{{ local function count_placement()
-- Where the projects sit: at the top of the repository, or on a shelf inside
-- another directory (a game under games/, a subproject under a project). A
-- shelved project is listed by its full path, so a slash in the name is the
-- whole test. Loose ideas are the notes lying on shelves beside the projects.
local function count_placement(projects, ideas)
    local placement = { top_level = 0, on_shelves = 0, loose_ideas = 0 }
    for _, project in ipairs(projects) do
        if project.name:find("/", 1, true) then
            placement.on_shelves = placement.on_shelves + 1
        else
            placement.top_level = placement.top_level + 1
        end
    end
    for _, shelf in ipairs(ideas) do
        placement.loose_ideas = placement.loose_ideas + shelf.count
    end
    return placement
end
-- }}}

-- {{{ local function count_conventions()
-- How widely each house convention has actually been adopted. The standards
-- section of the root README used to describe the canonical layout as though
-- every project had it; this counts the projects that really do, so the gap
-- between the standard and the practice is a number rather than an impression.
-- Returns the list in display order, and the same counts keyed for lookup.
local function count_conventions()
    local conventions = {
        { key = "tmp_symlink", name = "a tmp/ symlink into the RAM tier",
          find = "-maxdepth 2 -type l -name tmp" },
        { key = "input_dir", name = "an input/ directory, read first",
          find = "-maxdepth 2 -type d -name input" },
        { key = "output_dir", name = "an output/ directory, written last",
          find = "-maxdepth 2 -type d -name output" },
        { key = "desire_dir", name = "a desire/ directory",
          find = "-maxdepth 2 -type d -name desire" },
        { key = "transcripts", name = "llm-transcripts/, riding with the commits",
          find = "-maxdepth 2 -type d -name llm-transcripts" },
        { key = "html_copy", name = "docs/HTML/, the browsable copy",
          find = "-maxdepth 3 -type d -path '*/docs/HTML'" },
        { key = "index_counter", name = "a .file-index-counter, for read-order numbering",
          find = "-maxdepth 2 -name .file-index-counter" },
    }
    local by_key = {}
    for _, convention in ipairs(conventions) do
        local command = string.format("find %q %s | wc -l", MONOREPO_ROOT, convention.find)
        convention.count = tonumber(read_command(command)[1])
        by_key[convention.key] = convention.count
    end
    by_key.info_md = tonumber(read_command(string.format(
        "find %q -name '*.info.md' -not -path '*/.git/*' | wc -l", MONOREPO_ROOT))[1])
    return conventions, by_key
end
-- }}}

-- {{{ local function measure_activity()
-- Where the attention actually went: how many file changes git recorded inside
-- each project over the last three months. A file changed in five commits
-- counts five times -- this measures work done, not the size of the tree.
--
-- Each changed path is credited to the project whose directory is the longest
-- match at its start, trying three segments, then two, then one, so that
-- `games/enheim-tome/src/x.lua` goes to the game and not to `games`, and a
-- subproject's changes do not also count for its parent. A path that matches
-- no project (the root README, the shared libs/) is simply not credited.
--
-- `--relative` makes git print paths relative to the directory it was pointed
-- at, which keeps this right when the census runs on a checkout elsewhere.
--
-- Changes to a project's materials rather than its work are not credited;
-- see activity_excluded in the configuration.

-- {{{ local function is_material()
local function is_material(path_inside_project)
    for _, pattern in ipairs(config.activity_excluded) do
        if path_inside_project:match(pattern) then return true end
    end
    return false
end
-- }}}

local function measure_activity(projects)
    local is_project = {}
    for _, project in ipairs(projects) do is_project[project.name] = project end

    local changed_paths = read_command(string.format(
        "git -C %q log --relative --since='3 months ago' --name-only --pretty=format:",
        MONOREPO_ROOT))

    local changes = {}
    for _, path in ipairs(changed_paths) do
        local segments = {}
        for segment in path:gmatch("[^/]+") do segments[#segments + 1] = segment end
        for depth = math.min(3, #segments - 1), 1, -1 do
            local prefix = table.concat(segments, "/", 1, depth)
            if is_project[prefix] then
                -- Two paths: the change is to a consumed or generated
                -- material (not credited), or it is work (credited).
                local inside = path:sub(#prefix + 2)
                if not is_material(inside) then
                    changes[prefix] = (changes[prefix] or 0) + 1
                end
                break
            end
        end
    end

    local ranked = {}
    for name, count in pairs(changes) do
        ranked[#ranked + 1] = { project = is_project[name], changes = count }
    end
    table.sort(ranked, function(a, b)
        if a.changes ~= b.changes then return a.changes > b.changes end
        return a.project.name < b.project.name
    end)
    return ranked
end
-- }}}

-- {{{ local function count_phases()
-- How many phases a project has laid out -- defined, not finished. The shared
-- progress dashboard already knows how to read phases out of issue names in
-- every naming shape the repository uses, so it is asked rather than copied.
--
-- When the dashboard has warnings about a project -- most often that nothing
-- confirms where a name's phase ends and its issue number begins -- its phase
-- count is a guess. The project's own phase progress files are then asked
-- instead: one progress file per phase is a house rule, and a project that
-- keeps them has said in writing how many phases it has, whatever its issue
-- names look like. (neocities-modernization is the case that taught this:
-- its trackers are named `12-progress.md`, not `phase-12-progress.md`, which
-- the dashboard does not recognise as confirmation.) Three paths:
--   no warnings                  -> the dashboard's count
--   warnings, two or more        -> the number of progress files, with a
--   progress files                  notice on stderr, since it is a fallback
--   warnings, one or none        -> nil ("—"), with a notice on stderr
-- One tracker alone is not evidence of phases: the shared scripts/ project
-- keeps a single progress file over flat-numbered issues (032, 032a), and
-- counting it as "1 phase" claimed a structure the project does not have.
local dashboard = nil

-- {{{ local function count_progress_files()
local function count_progress_files(project)
    local issues_dir = MONOREPO_ROOT .. "/" .. project.name .. "/issues"
    local count = 0
    for _, name in ipairs(entries_of(issues_dir)) do
        if name:match("^%d+%-progress%.md$") or name:match("^phase%-%d+%-progress%.md$") then
            count = count + 1
        end
    end
    return count
end
-- }}}

local function count_phases(project)
    dashboard = dashboard or dofile(DASHBOARD_PATH)
    local phases, report = dashboard.collect(MONOREPO_ROOT .. "/" .. project.name)
    local warnings = dashboard.warning_lines(report)
    if #warnings > 0 then
        local trackers = count_progress_files(project)
        if trackers > 1 then
            io.stderr:write(string.format(
                "notice (fallback): %s's phases counted from its %d progress files; the progress dashboard warns: %s\n",
                project.name, trackers, warnings[1]))
            return trackers
        end
        io.stderr:write(string.format(
            "notice: %s's phases are shown as \"—\"; the progress dashboard warns: %s\n",
            project.name, warnings[1]))
        return nil
    end
    local count = 0
    for _ in pairs(phases) do count = count + 1 end
    return count
end
-- }}}

-- {{{ local function focus_of()
-- The hand-written sentence saying what a project is for. A project without
-- one stops the run: an empty cell would ship silently, and the fix -- one
-- line in the focus file -- is quicker than noticing the gap later.
local focus_sentences = nil
local function focus_of(project)
    focus_sentences = focus_sentences or dofile(FOCUS_PATH)
    local sentence = focus_sentences[project.name]
    if not sentence then
        error(string.format(
            "%s is in the Active Development table but has no focus sentence; add one to %s",
            project.name, FOCUS_PATH), 0)
    end
    return sentence
end
-- }}}

-- }}}

-- {{{ Rendering

-- {{{ local function headline()
local function headline(projects)
    local counted, states = totals(projects)
    return string.format(
        "%d projects. %d track issues, %d are building without them, " ..
        "%d are a vision document waiting to start, and %d %s empty.",
        #projects, states.tracked, states.building, states.vision,
        states.empty, states.empty == 1 and "is" or "are"),
        string.format(
        "%d issues completed out of %d, which is %d%% overall. %d more are shelved.",
        counted.completed, counted.all, counted.percent, counted.archived)
end
-- }}}

-- {{{ local function state_note()
local function state_note(project)
    local notes = {
        building = "no issues filed",
        vision = "a vision, not yet started",
        empty = "empty",
    }
    return notes[project.state]
end
-- }}}

-- {{{ local function render_terminal()
local function render_terminal(projects, furniture, copies, ideas)
    local first, second = headline(projects)
    print(first)
    print(second)
    print("")
    for _, project in ipairs(projects) do
        if project.state == "tracked" then
            local shelved = project.archived > 0
                and string.format("  (%d shelved)", project.archived) or ""
            print(string.format("  %-46s %4d/%-4d %3d%%%s",
                project.name, project.completed, project.total,
                project.percent, shelved))
        else
            print(string.format("  %-46s %s", project.name, state_note(project)))
        end
    end
    print("")
    for _, shelf in ipairs(ideas) do
        print(string.format(
            "%s/ holds %d further idea%s as loose notes, written down and not yet given a directory.",
            shelf.shelf, shelf.count, shelf.count == 1 and "" or "s"))
    end
    print("not projects, skipped: " .. table.concat(furniture, ", "))
    if #copies > 0 then
        print("copies, skipped: " .. table.concat(copies, ", "))
    end
end
-- }}}

-- {{{ local function appendix_table()
-- The every-project table, the loose ideas on each shelf, and the list of
-- directories skipped, as one block of markdown. Printed by --markdown and
-- spliced into the README's appendix; built once so the two cannot differ.
local function appendix_table(projects, furniture, copies, ideas)
    local lines = { "| Project | Progress | % |", "|---------|----------|---|" }
    for _, project in ipairs(projects) do
        if project.state == "tracked" then
            lines[#lines + 1] = string.format("| %s | %d/%d | %d%% |",
                project.name, project.completed, project.total, project.percent)
        else
            lines[#lines + 1] = string.format("| %s | — | *%s* |",
                project.name, state_note(project))
        end
    end
    lines[#lines + 1] = ""
    for _, shelf in ipairs(ideas) do
        lines[#lines + 1] = string.format(
            "`%s/` holds %d further idea%s as loose notes, written down and not yet given a directory.",
            shelf.shelf, shelf.count, shelf.count == 1 and "" or "s")
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = "Not projects: " .. table.concat(furniture, ", ") .. "." ..
        (#copies > 0 and (" Copies: " .. table.concat(copies, ", ") .. ".") or "")
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function active_table()
-- The busiest projects of the last three months, most first, with what each
-- is for, how far through its issues it is, and how many phases it has laid
-- out. A project without issue files shows "—" for its issues; one whose
-- phases the dashboard could not confirm shows "—" for its phases.
local ACTIVE_ROWS = 11
local function active_table(projects)
    local ranked = measure_activity(projects)
    local lines = { "| Project | Focus | Issues | Phases |",
                    "|---------|-------|--------|--------|" }
    for index = 1, math.min(ACTIVE_ROWS, #ranked) do
        local project = ranked[index].project
        local issues = project.state == "tracked"
            and string.format("%d/%d", project.completed, project.total) or "—"
        local phases = project.state == "tracked" and count_phases(project) or nil
        lines[#lines + 1] = string.format("| **%s** | %s | %s | %s |",
            project.name, focus_of(project), issues,
            phases and tostring(phases) or "—")
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function render_markdown()
local function render_markdown(projects, furniture, copies, ideas)
    local first, second = headline(projects)
    print(first .. " " .. second)
    print("")
    print(appendix_table(projects, furniture, copies, ideas))
end
-- }}}

-- {{{ local function render_json()
local function render_json(projects)
    local counted, states = totals(projects)
    print("{")
    print(string.format('  "projects": %d,', #projects))
    print(string.format('  "tracked": %d,', states.tracked))
    print(string.format('  "building": %d,', states.building))
    print(string.format('  "vision": %d,', states.vision))
    print(string.format('  "empty": %d,', states.empty))
    print(string.format('  "completed": %d,', counted.completed))
    print(string.format('  "archived": %d,', counted.archived))
    print(string.format('  "total": %d,', counted.all))
    print(string.format('  "percent": %d,', counted.percent))
    print('  "list": [')
    for index, project in ipairs(projects) do
        print(string.format(
            '    { "name": %q, "state": %q, "open": %d, "completed": %d, "archived": %d, "total": %d, "percent": %d }%s',
            project.name, project.state, project.open, project.completed,
            project.archived, project.total, project.percent,
            index < #projects and "," or ""))
    end
    print("  ]")
    print("}")
end
-- }}}

-- {{{ local function render_conventions()
local function render_conventions()
    local conventions, by_key = count_conventions()
    print("Conventions, by how many projects keep them:")
    print("")
    for _, convention in ipairs(conventions) do
        print(string.format("  %-52s %3d", convention.name, convention.count))
    end
    print("")
    print(string.format("  %-52s %3d", "companion .info.md interface files, in total", by_key.info_md))
end
-- }}}

-- }}}

-- {{{ Number words
-- The README writes counts inside prose as words ("ninety-one projects", "the
-- other eighteen"), so the census must be able to say them. 0 through 999 is
-- enough for any count this repository will reach soon; a larger number is an
-- error, not a string of digits passed off as words.

local ONES = { [0] = "zero", "one", "two", "three", "four", "five", "six",
    "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
    "fifteen", "sixteen", "seventeen", "eighteen", "nineteen" }
-- Indexed by the tens digit. Written out key by key: a list starting at [2]
-- would still number its unkeyed entries from 1, putting "thirty" at 1.
local TENS = { [2] = "twenty", [3] = "thirty", [4] = "forty", [5] = "fifty",
    [6] = "sixty", [7] = "seventy", [8] = "eighty", [9] = "ninety" }

-- {{{ local function say_number()
local function say_number(n)
    if n < 0 or n > 999 or n ~= math.floor(n) then
        error("cannot say " .. tostring(n) .. " in words (0 to 999 only)", 0)
    end
    -- Three shapes: under twenty is one word; under a hundred is tens plus a
    -- hyphenated unit; a hundred or more says the hundreds, then the rest
    -- after "and" if there is a rest.
    if n < 20 then return ONES[n] end
    if n < 100 then
        local tens, unit = math.floor(n / 10), n % 10
        return unit == 0 and TENS[tens] or (TENS[tens] .. "-" .. ONES[unit])
    end
    local hundreds, rest = math.floor(n / 100), n % 100
    local head = ONES[hundreds] .. " hundred"
    return rest == 0 and head or (head .. " and " .. say_number(rest))
end
-- }}}

-- }}}

-- {{{ README slots
-- A slot is a figure on the front page that the census owns. In the README it
-- is written as an opening marker naming the slot, the current value, and a
-- closing marker:
--
--   inline:  <!-- census:projects:words -->ninety-one<!-- /census -->
--   block:   <!-- census:active_table -->        (on a line of its own)
--            ...the table...
--            <!-- /census -->
--
-- The part after "census:" is the slot name; after a second colon, the format.
-- A block slot has no format and its contents always sit on their own lines.
-- A slot name of the form field@project reads one project's own figure, as in
-- total@hero-less-moba.
--
-- Unknown names, unknown formats and unclosed markers are errors that stop the
-- run with the file untouched: a figure the census cannot vouch for must not
-- be left looking as though it had been regenerated.

-- {{{ local function slot_context()
-- Everything a slot might read, measured lazily: the conventions walk the whole
-- tree with find, and the activity table reads three months of git history,
-- so neither is paid for unless the README asks for it.
local function slot_context()
    local projects, furniture, copies, ideas = gather()
    local counted, states = totals(projects)
    local context = {
        projects = projects, furniture = furniture, copies = copies, ideas = ideas,
        counted = counted, states = states,
        placement = count_placement(projects, ideas),
        by_name = {},
    }
    for _, project in ipairs(projects) do context.by_name[project.name] = project end
    function context.conventions()
        if not context.convention_counts then
            local _, by_key = count_conventions()
            context.convention_counts = by_key
        end
        return context.convention_counts
    end
    -- Who wrote what: the person's characters and the model's, measured
    -- across every saved conversation by measure-authorship.lua (issue 059),
    -- read from its JSON. A field missing from that JSON is an error, not a
    -- zero: a zero would print as a real measurement.
    function context.authorship()
        if not context.authorship_counts then
            local lines = read_command(string.format("luajit %q --json --dir=%q",
                DIR .. "/scripts/measure-authorship.lua", MONOREPO_ROOT))
            local json = table.concat(lines, "\n")
            local counts = {}
            for _, field in ipairs({ "human_written_total", "machine_written_total",
                                     "source_characters", "docs_characters" }) do
                local value = tonumber(json:match('"' .. field .. '"%s*:%s*([%d%.]+)'))
                if not value then
                    error("measure-authorship.lua gave no " .. field .. ": " .. json, 0)
                end
                counts[field] = value
            end
            context.authorship_counts = counts
        end
        return context.authorship_counts
    end
    return context
end
-- }}}

-- {{{ local function empty_clause()
-- "one is an empty directory" -- the verb and the noun follow the count, so
-- the sentence stays grammatical when the count moves. Three paths: none,
-- one (singular), several (plural).
local function empty_clause(count)
    if count == 0 then return "none is empty" end
    if count == 1 then return "one is an empty directory" end
    return say_number(count) .. " are empty directories"
end
-- }}}

-- A number slot returns a number and takes a format; a text slot returns a
-- finished string and takes the format "text"; a block slot returns lines.
local NUMBER_SLOTS = {
    projects      = function(c) return #c.projects end,
    top_level     = function(c) return c.placement.top_level end,
    on_shelves    = function(c) return c.placement.on_shelves end,
    loose_ideas   = function(c) return c.placement.loose_ideas end,
    tracked       = function(c) return c.states.tracked end,
    building      = function(c) return c.states.building end,
    vision        = function(c) return c.states.vision end,
    empty         = function(c) return c.states.empty end,
    completed     = function(c) return c.counted.completed end,
    issues        = function(c) return c.counted.all end,
    percent       = function(c) return c.counted.percent end,
    shelved       = function(c) return c.counted.archived end,
    tmp_symlink   = function(c) return c.conventions().tmp_symlink end,
    input_dir     = function(c) return c.conventions().input_dir end,
    output_dir    = function(c) return c.conventions().output_dir end,
    desire_dir    = function(c) return c.conventions().desire_dir end,
    transcripts   = function(c) return c.conventions().transcripts end,
    html_copy     = function(c) return c.conventions().html_copy end,
    index_counter = function(c) return c.conventions().index_counter end,
    info_md       = function(c) return c.conventions().info_md end,
    -- Who wrote what (issue 059). Human text is what the owner typed in
    -- conversation plus every notes/ folder; machine text is what the model
    -- wrote in conversation; source and docs are the repository's own files
    -- (docs including issue files), vendored code left out.
    human_written    = function(c) return c.authorship().human_written_total end,
    machine_written  = function(c) return c.authorship().machine_written_total end,
    source_generated = function(c) return c.authorship().source_characters end,
    docs_generated   = function(c) return c.authorship().docs_characters end,
}

-- Fields readable per project through field@project.
local PROJECT_FIELDS = { total = true, completed = true, open = true,
                         archived = true, percent = true }

local TEXT_SLOTS = {
    empty_clause = function(c) return empty_clause(c.states.empty) end,
}

local BLOCK_SLOTS = {
    active_table = function(c) return active_table(c.projects) end,
    appendix_table = function(c)
        return appendix_table(c.projects, c.furniture, c.copies, c.ideas)
    end,
}

-- {{{ local function with_commas()
local function with_commas(n)
    local digits = tostring(n)
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (grouped:gsub("^,", ""))
end
-- }}}

-- The authorship figures grow with every conversation, including the one
-- that is committing the README, so written exactly they would be stale
-- before the commit gate read them. `millions` and `tenths` round them to a
-- precision that holds for a while: 9,676,065 is "9.7 million" until another
-- fifty thousand characters are written.
local FORMATS = {
    digits = with_commas,
    millions = function(n) return string.format("%.1f million", n / 1e6) end,
    tenths   = function(n) return string.format("%.1f", n) end,
    words  = say_number,
    Words  = function(n)
        local said = say_number(n)
        return said:sub(1, 1):upper() .. said:sub(2)
    end,
}

-- {{{ local function render_slot()
-- The text a slot should hold now. Dispatches on which table knows the name;
-- a name no table knows, or a number without a known format, is an error.
local function render_slot(context, name, format)
    if BLOCK_SLOTS[name] then
        if format ~= "" then
            error("block slot " .. name .. " takes no format, was given " .. format, 0)
        end
        return "\n" .. BLOCK_SLOTS[name](context) .. "\n"
    end
    if TEXT_SLOTS[name] then
        if format ~= "text" then
            error("text slot " .. name .. " takes the format text, was given " .. format, 0)
        end
        return TEXT_SLOTS[name](context)
    end

    local value
    local field, project_name = name:match("^(%w+)@(.+)$")
    if field then
        local project = context.by_name[project_name]
        if not project then error("no project named " .. project_name, 0) end
        if not PROJECT_FIELDS[field] then error("no project field named " .. field, 0) end
        value = project[field]
    elseif NUMBER_SLOTS[name] then
        value = NUMBER_SLOTS[name](context)
    else
        error("unknown census slot: " .. name, 0)
    end
    if type(value) ~= "number" then
        error("slot " .. name .. " measured nothing (" .. tostring(value) .. ")", 0)
    end
    local formatter = FORMATS[format]
    if not formatter then
        error("unknown format for slot " .. name .. ": \"" .. format ..
              "\" (expected digits, words, Words, millions, or tenths)", 0)
    end
    return formatter(value)
end
-- }}}

-- {{{ local function splice()
-- Walks the text marker by marker and returns it with every slot refreshed,
-- plus a list of the slots whose contents changed. The text between markers
-- is copied through untouched: the prose belongs to people, only the figures
-- belong to the census.
local OPEN_MARKER = "<!%-%- census:([^%s:]+):?(%S*) %-%->"
local CLOSE_MARKER = "<!-- /census -->"
local function splice(text, context)
    local pieces, stale = {}, {}
    local position = 1
    while true do
        local open_start, open_end, name, format = text:find(OPEN_MARKER, position)
        if not open_start then break end
        local close_start, close_end = text:find(CLOSE_MARKER, open_end + 1, true)
        local next_open = text:find(OPEN_MARKER, open_end + 1)
        if not close_start or (next_open and next_open < close_start) then
            local line = select(2, text:sub(1, open_start):gsub("\n", "")) + 1
            error(string.format("census marker for %s on line %d is never closed", name, line), 0)
        end
        local current = text:sub(open_end + 1, close_start - 1)
        local fresh = render_slot(context, name, format)
        if fresh ~= current then
            stale[#stale + 1] = { name = format ~= "" and (name .. ":" .. format) or name,
                                  was = current, now = fresh }
        end
        pieces[#pieces + 1] = text:sub(position, open_end)
        pieces[#pieces + 1] = fresh
        pieces[#pieces + 1] = CLOSE_MARKER
        position = close_end + 1
    end
    pieces[#pieces + 1] = text:sub(position)
    return table.concat(pieces), stale
end
-- }}}

-- {{{ local function read_whole()
local function read_whole(path)
    local handle = io.open(path, "rb")
    if not handle then error("cannot read " .. path, 0) end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ local function brief()
-- A slot's old or new contents on one short line, for the stale report.
local function brief(text)
    local flat = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return #flat > 60 and (flat:sub(1, 57) .. "...") or flat
end
-- }}}

-- {{{ local function refresh_readme()
-- Two modes share the splice. Checking reports and exits 1 if anything is
-- stale; writing puts the new text in a sibling file first and renames it over
-- the README, so a failure part-way can never leave a half-written page.
local function refresh_readme(write)
    local original = read_whole(README_PATH)
    local refreshed, stale = splice(original, slot_context())

    for _, slot in ipairs(stale) do
        print(string.format("%-28s %s  ->  %s", slot.name, brief(slot.was), brief(slot.now)))
    end

    if not write then
        if #stale > 0 then
            print(string.format("%d stale figure%s in %s; run --write-readme",
                #stale, #stale == 1 and "" or "s", README_PATH))
            os.exit(1)
        end
        print("every census figure in " .. README_PATH .. " is current")
        return
    end

    if #stale == 0 then
        print("nothing to change in " .. README_PATH)
        return
    end
    local staging = README_PATH .. ".census-writing"
    local handle = assert(io.open(staging, "wb"))
    handle:write(refreshed)
    handle:close()
    assert(os.rename(staging, README_PATH))
    print(string.format("rewrote %d figure%s in %s",
        #stale, #stale == 1 and "" or "s", README_PATH))
end
-- }}}

-- }}}

-- {{{ Entry
-- Modes that need the project walk receive its results; the others do not pay
-- for it. --say=N is matched by prefix since it carries its number.
local function main()
    local mode = arg[1] or "--terminal"

    local said = mode:match("^%-%-say=(%d+)$")
    if said then
        print(say_number(tonumber(said)))
        return
    end

    local standalone = {
        ["--conventions"]  = render_conventions,
        ["--write-readme"] = function() refresh_readme(true) end,
        ["--check-readme"] = function() refresh_readme(false) end,
    }
    if standalone[mode] then
        standalone[mode]()
        return
    end

    local renderers = {
        ["--terminal"] = render_terminal,
        ["--markdown"] = render_markdown,
        ["--json"]     = render_json,
    }
    local render = renderers[mode]
    if not render then
        io.stderr:write("unknown mode: " .. mode .. "\n")
        io.stderr:write("expected --terminal, --markdown, --json, --conventions, " ..
                        "--write-readme, --check-readme, or --say=N\n")
        os.exit(2)
    end
    render(gather())
end

-- A refusal (unknown slot, unclosed marker, missing focus sentence) is printed
-- as one plain line and exits 1; anything else is a real fault and keeps its
-- traceback.
local ok, failure = xpcall(main, function(message)
    if type(message) == "string" and not message:match("^[^\n]*:%d+:") then
        return message
    end
    return debug.traceback(message, 2)
end)
if not ok then
    io.stderr:write("census-projects: " .. tostring(failure) .. "\n")
    os.exit(1)
end
-- }}}
