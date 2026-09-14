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
--   census-projects.lua --dir=/path   -- census a checkout elsewhere

-- {{{ DIR Configuration
-- Hard-coded path so the script runs from any directory.
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
if arg[1] and arg[1]:match("^%-%-dir=") then
    DIR = arg[1]:match("^%-%-dir=(.+)$")
    table.remove(arg, 1)
end
local MONOREPO_ROOT = DIR:match("(.*)/.+$") or "."
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
    counted.percent = math.floor((counted.completed / counted.all) * 100 + 0.5)
    return counted, states
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

-- {{{ local function render_markdown()
local function render_markdown(projects, furniture, copies, ideas)
    local first, second = headline(projects)
    print(first .. " " .. second)
    print("")
    print("| Project | Progress | % |")
    print("|---------|----------|---|")
    for _, project in ipairs(projects) do
        if project.state == "tracked" then
            print(string.format("| %s | %d/%d | %d%% |",
                project.name, project.completed, project.total, project.percent))
        else
            print(string.format("| %s | — | *%s* |", project.name, state_note(project)))
        end
    end
    print("")
    for _, shelf in ipairs(ideas) do
        print(string.format(
            "`%s/` holds %d further idea%s as loose notes, written down and not yet given a directory.\n",
            shelf.shelf, shelf.count, shelf.count == 1 and "" or "s"))
    end
    print("Not projects: " .. table.concat(furniture, ", ") .. "." ..
          (#copies > 0 and (" Copies: " .. table.concat(copies, ", ") .. ".") or ""))
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
-- How widely each house convention has actually been adopted. The standards
-- section of the root README used to describe the canonical layout as though
-- every project had it; this counts the projects that really do, so the gap
-- between the standard and the practice is a number rather than an impression.
local function render_conventions()
    local conventions = {
        { name = "a tmp/ symlink into the RAM tier",
          find = "-maxdepth 2 -type l -name tmp" },
        { name = "an input/ directory, read first",
          find = "-maxdepth 2 -type d -name input" },
        { name = "an output/ directory, written last",
          find = "-maxdepth 2 -type d -name output" },
        { name = "a desire/ directory",
          find = "-maxdepth 2 -type d -name desire" },
        { name = "llm-transcripts/, riding with the commits",
          find = "-maxdepth 2 -type d -name llm-transcripts" },
        { name = "docs/HTML/, the browsable copy",
          find = "-maxdepth 3 -type d -path '*/docs/HTML'" },
        { name = "a .file-index-counter, for read-order numbering",
          find = "-maxdepth 2 -name .file-index-counter" },
    }

    print("Conventions, by how many projects keep them:")
    print("")
    for _, convention in ipairs(conventions) do
        local command = string.format("find %q %s | wc -l", MONOREPO_ROOT, convention.find)
        local count = tonumber(read_command(command)[1]) or 0
        print(string.format("  %-52s %3d", convention.name, count))
    end

    local companions = tonumber(read_command(string.format(
        "find %q -name '*.info.md' -not -path '*/.git/*' | wc -l", MONOREPO_ROOT))[1]) or 0
    print("")
    print(string.format("  %-52s %3d", "companion .info.md interface files, in total", companions))
end
-- }}}

-- }}}

-- {{{ Entry
local function main()
    local mode = arg[1] or "--terminal"

    if mode == "--conventions" then
        render_conventions()
        return
    end

    local projects, furniture, copies, ideas = gather()
    local renderers = {
        ["--terminal"] = function() render_terminal(projects, furniture, copies, ideas) end,
        ["--markdown"] = function() render_markdown(projects, furniture, copies, ideas) end,
        ["--json"] = function() render_json(projects) end,
    }

    local render = renderers[mode]
    if not render then
        io.stderr:write("unknown mode: " .. mode .. "\n")
        io.stderr:write("expected --terminal, --markdown, --json, or --conventions\n")
        os.exit(1)
    end
    render()
end

main()
-- }}}
