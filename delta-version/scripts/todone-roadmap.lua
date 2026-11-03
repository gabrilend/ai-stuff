#!/usr/bin/env luajit
-- todone-roadmap.lua - in what order to build the components several
-- projects share, and what each project then waits on.
--
-- Issue 053, its next slice (053c, shared library roadmap generation). It
-- reads what todone.lua --json found (the components two or more projects
-- each plan to build) and config/shared-components.conf (which component
-- needs which, how big each is, where it would live), and works out:
--   priority  usage x 2 + dependents x 1.5 + hours x 0.5, the issue's own
--             formula ("dependents" counts every component that needs this
--             one, directly or not)
--   order     a topological sort: nothing before what it needs, and among
--             what is ready, the higher priority first. A cycle is named,
--             and its members are left out of the order.
--   phases    shared phase 1 is everything that needs nothing, phase 2
--             what needs only phase 1, and so on
--   effort    building once (hours + 2 per project to fit it in) against
--             each project building its own (hours x projects)
--   projects  for each project, the shared components it waits on and the
--             phase after which it has them all
-- No model is involved, and nothing is written unless --out is given.
--
-- Usage: todone-roadmap.lua TODONE_JSON [--components=FILE] [--json]
--                           [--out=FILE]
--   TODONE_JSON        what `todone.lua --all --json` printed, or - to read it
--                      from standard input
--   --components=FILE  default config/shared-components.conf
--   --synonyms=FILE    default config/component-synonyms.conf
--   --json             print the roadmap as JSON instead of Markdown
--   --out=FILE         save it there instead (never over an existing file)
--
-- Exit status: 0 done, 1 refused (bad input, or a file in the way), 2 usage.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
local COMPONENTS = SCRIPT_DIR .. "/../config/shared-components.conf"
local SYNONYMS = SCRIPT_DIR .. "/../config/component-synonyms.conf"
-- }}}

-- {{{ Configuration
local config = {
    hours = { low = 5, medium = 20, high = 50, ["very high"] = 100 },
    default_complexity = "medium",
    fitting_hours = 2,      -- to fit a shared library into one project
    weights = { usage = 2, dependents = 1.5, hours = 0.5 },
}
-- }}}

local component_names = require("component-names")
local key_of = component_names.key_of

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message, code)
    io.stderr:write("todone-roadmap: " .. message .. "\n")
    os.exit(code or 2)
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    local ok, _, code = os.rename(path, path)
    return ok or code == 13
end
-- }}}

-- {{{ local function trim()
local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ local function number_text()
-- 12 stays 12, 4.5 stays 4.5.
local function number_text(value)
    if value % 1 == 0 then return string.format("%d", value) end
    return string.format("%.1f", value)
end
-- }}}
-- }}}

-- {{{ local function read_todone()
local function read_todone(path)
    local text
    if path == "-" then
        text = io.read("*a")
    else
        local file = io.open(path, "r") or fail("cannot read " .. path, 1)
        text = file:read("*a")
        file:close()
    end
    local record = require("dkjson").decode(text or "")
    if type(record) ~= "table" or type(record.shared) ~= "table" then
        fail(path .. " is not todone.lua --json output (it has no \"shared\" list)", 1)
    end
    return record
end
-- }}}

-- {{{ local function read_components()
-- Lines "NAME: needs A, B", "NAME: complexity high", "NAME: home PATH".
-- Every line is checked; a line that is none of these is refused, by number.
local function read_components(path, synonyms)
    local facts = {}
    local file = io.open(path, "r")
    if not file then return facts end
    local number = 0
    for line in file:lines() do
        number = number + 1
        line = trim(line:gsub("#.*$", ""))
        if line ~= "" then
            local name, field, value = line:match("^([^:]-)%s*:%s*(%a+)%s*(.-)$")
            if not name or name == "" or not ({ needs = true, complexity = true, home = true })[field] then
                fail(string.format("%s line %d: expected \"NAME: needs A, B\", \"NAME: complexity "
                    .. "low|medium|high|very high\" or \"NAME: home PATH\"", path, number), 1)
            end
            name = component_names.canonical(trim(name), synonyms)
            local entry = facts[key_of(name)] or { name = name, needs = {} }
            facts[key_of(name)] = entry
            if field == "needs" then
                for need in value:gmatch("[^,]+") do
                    need = trim(need)
                    if need ~= "" then entry.needs[#entry.needs + 1] = component_names.canonical(need, synonyms) end
                end
            elseif field == "complexity" then
                value = value:lower()
                if not config.hours[value] then
                    fail(string.format("%s line %d: complexity is low, medium, high or very high", path, number), 1)
                end
                entry.complexity = value
            else
                entry.home = value
            end
        end
    end
    file:close()
    return facts
end
-- }}}

-- {{{ local function build_graph()
-- The shared components, plus any component one of them needs that no two
-- projects share (it still has to be built first).
local function build_graph(todone, facts)
    local nodes, order = {}, {}
    local function add(name, projects)
        local key = key_of(name)
        if not nodes[key] then
            local fact = facts[key] or {}
            nodes[key] = { key = key, name = name, projects = projects or {}, needs = {},
                complexity = fact.complexity or config.default_complexity,
                complexity_guessed = fact.complexity == nil, home = fact.home }
            order[#order + 1] = nodes[key]
        elseif projects and #nodes[key].projects == 0 then
            nodes[key].projects = projects
        end
        return nodes[key]
    end
    for _, entry in ipairs(todone.shared) do
        if type(entry.name) == "string" then add(entry.name, entry.projects or {}) end
    end
    local index = 1
    while order[index] do   -- order grows as needs are found
        local node = order[index]
        for _, need in ipairs((facts[node.key] or {}).needs or {}) do
            local other = add(need)
            if other ~= node then node.needs[#node.needs + 1] = other end
        end
        index = index + 1
    end
    return nodes, order
end
-- }}}

-- {{{ local function score()
local function score(order)
    local needed_by = {}
    for _, node in ipairs(order) do
        for _, need in ipairs(node.needs) do
            needed_by[need.key] = needed_by[need.key] or {}
            needed_by[need.key][#needed_by[need.key] + 1] = node
        end
    end
    for _, node in ipairs(order) do
        local seen, stack, count = { [node.key] = true }, { node }, 0
        while #stack > 0 do
            local current = table.remove(stack)
            for _, user in ipairs(needed_by[current.key] or {}) do
                if not seen[user.key] then
                    seen[user.key] = true
                    count = count + 1
                    stack[#stack + 1] = user
                end
            end
        end
        local usage = #node.projects
        node.hours = config.hours[node.complexity]
        node.dependents = count
        node.priority = usage * config.weights.usage + count * config.weights.dependents
            + node.hours * config.weights.hours
        node.alone_hours = usage * node.hours
        node.shared_hours = node.hours + usage * config.fitting_hours
        node.saved_hours = math.max(0, node.alone_hours - node.shared_hours)
    end
end
-- }}}

-- {{{ local function by_priority()
local function by_priority(a, b)
    if a.priority ~= b.priority then return a.priority > b.priority end
    return a.name < b.name
end
-- }}}

-- {{{ local function find_cycles()
-- The cycles among the components left over by the sort, each as a list
-- of names that ends where it began.
local function find_cycles(left)
    local cycles, done = {}, {}
    for _, start in ipairs(left) do
        if not done[start.key] then
            local path, at, node = {}, {}, start
            while node and not at[node.key] and not done[node.key] do
                at[node.key] = #path + 1
                path[#path + 1] = node
                local next_node
                for _, need in ipairs(node.needs) do
                    if need.left then next_node = need break end
                end
                node = next_node
            end
            if node and at[node.key] then
                local names = {}
                for index = at[node.key], #path do names[#names + 1] = path[index].name end
                names[#names + 1] = node.name
                cycles[#cycles + 1] = names
            end
            for _, visited in ipairs(path) do done[visited.key] = true end
        end
    end
    return cycles
end
-- }}}

-- {{{ local function plan()
-- Phases by level: a component goes in the first phase after everything
-- it needs. Within a phase, higher priority first.
local function plan(order)
    local placed, phases, remaining = {}, {}, {}
    for _, node in ipairs(order) do remaining[#remaining + 1] = node end
    while #remaining > 0 do
        local ready, rest = {}, {}
        for _, node in ipairs(remaining) do
            local ok = true
            for _, need in ipairs(node.needs) do
                if not placed[need.key] then ok = false break end
            end
            if ok then ready[#ready + 1] = node else rest[#rest + 1] = node end
        end
        if #ready == 0 then break end
        table.sort(ready, by_priority)
        phases[#phases + 1] = ready
        for _, node in ipairs(ready) do
            placed[node.key] = true
            node.phase = #phases
        end
        remaining = rest
    end
    for _, node in ipairs(remaining) do node.left = true end
    return phases, remaining, find_cycles(remaining)
end
-- }}}

-- {{{ local function as_record()
local function as_record(todone, order, phases, left, cycles)
    local record = { roadmap = "todone-roadmap v1", projects_read = todone.projects,
                     phases = {}, projects = {}, cycles = cycles, unordered = {} }
    local total_alone, total_shared = 0, 0
    for number, phase in ipairs(phases) do
        local entry = { number = number, components = {}, saved_hours = 0 }
        for _, node in ipairs(phase) do
            entry.components[#entry.components + 1] = {
                name = node.name, used_by = node.projects, needs = (function()
                    local names = {}
                    for _, need in ipairs(node.needs) do names[#names + 1] = need.name end
                    return names
                end)(),
                priority = node.priority, dependents = node.dependents,
                complexity = node.complexity, complexity_guessed = node.complexity_guessed,
                home = node.home, hours = node.hours, alone_hours = node.alone_hours,
                shared_hours = node.shared_hours, saved_hours = node.saved_hours,
            }
            entry.saved_hours = entry.saved_hours + node.saved_hours
            total_alone, total_shared = total_alone + node.alone_hours, total_shared + node.shared_hours
        end
        record.phases[number] = entry
    end
    for _, node in ipairs(left) do record.unordered[#record.unordered + 1] = node.name end
    record.effort = { alone_hours = total_alone, shared_hours = total_shared,
                      saved_hours = math.max(0, total_alone - total_shared) }

    -- Each project: what it waits on, in build order, and when it has it all.
    local by_project, names = {}, {}
    for _, phase in ipairs(phases) do
        for _, node in ipairs(phase) do
            for _, project in ipairs(node.projects) do
                if not by_project[project] then
                    by_project[project] = { project = project, waits_on = {}, ready_after = 0 }
                    names[#names + 1] = project
                end
                local entry = by_project[project]
                entry.waits_on[#entry.waits_on + 1] = node.name
                entry.ready_after = math.max(entry.ready_after, node.phase)
            end
        end
    end
    for _, node in ipairs(left) do
        for _, project in ipairs(node.projects) do
            if not by_project[project] then
                by_project[project] = { project = project, waits_on = {}, ready_after = 0 }
                names[#names + 1] = project
            end
            local entry = by_project[project]
            entry.waits_on_unordered = entry.waits_on_unordered or {}
            entry.waits_on_unordered[#entry.waits_on_unordered + 1] = node.name
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do record.projects[#record.projects + 1] = by_project[name] end
    return record
end
-- }}}

-- {{{ local function as_markdown()
local function as_markdown(record)
    local out = { "# Shared components: build order", "" }
    local count = 0
    for _, phase in ipairs(record.phases) do count = count + #phase.components end
    if count == 0 and #record.unordered == 0 then
        out[#out + 1] = "No component is shared, so there is nothing to order."
        return table.concat(out, "\n") .. "\n"
    end
    out[#out + 1] = string.format("%d component%s to build, for the %s projects read, in %d phase%s. "
        .. "Built once: about %s hours instead of %s, saving %s.", count, count == 1 and "" or "s",
        tostring(record.projects_read or "?"), #record.phases, #record.phases == 1 and "" or "s",
        number_text(record.effort.shared_hours),
        number_text(record.effort.alone_hours), number_text(record.effort.saved_hours))
    local guessed = false
    for _, phase in ipairs(record.phases) do
        out[#out + 1] = ""
        out[#out + 1] = string.format("## Shared phase %d", phase.number)
        out[#out + 1] = ""
        out[#out + 1] = "| Component | Used by | Needs | Priority | Hours (once / each alone) |"
        out[#out + 1] = "|---|---|---|---|---|"
        for _, component in ipairs(phase.components) do
            if component.complexity_guessed then guessed = true end
            out[#out + 1] = string.format("| %s%s | %s | %s | %s | %s / %s%s |",
                component.name, component.home and (" (`" .. component.home .. "`)") or "",
                #component.used_by > 0 and table.concat(component.used_by, ", ") or "(only as a need)",
                #component.needs > 0 and table.concat(component.needs, ", ") or "-",
                number_text(component.priority), number_text(component.shared_hours),
                number_text(component.alone_hours), component.complexity_guessed and "*" or "")
        end
    end
    if #record.cycles > 0 then
        out[#out + 1] = ""
        out[#out + 1] = "## Cycles (left out of the order)"
        out[#out + 1] = ""
        for _, cycle in ipairs(record.cycles) do out[#out + 1] = "- " .. table.concat(cycle, " needs ") end
        out[#out + 1] = ""
        out[#out + 1] = "Unordered: " .. table.concat(record.unordered, ", ") .. "."
    end
    out[#out + 1] = ""
    out[#out + 1] = "## What each project waits on"
    out[#out + 1] = ""
    for _, project in ipairs(record.projects) do
        local parts = {}
        if #project.waits_on > 0 then
            parts[#parts + 1] = string.format("%s (all built by the end of shared phase %d)",
                table.concat(project.waits_on, ", "), project.ready_after)
        end
        if project.waits_on_unordered then
            parts[#parts + 1] = table.concat(project.waits_on_unordered, ", ") .. ", caught in a cycle"
        end
        out[#out + 1] = string.format("- **%s**: %s", project.project, table.concat(parts, "; and "))
    end
    if guessed then
        out[#out + 1] = ""
        out[#out + 1] = string.format("\\* No complexity given in config/shared-components.conf; "
            .. "taken as %s (%d hours).", config.default_complexity, config.hours[config.default_complexity])
    end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ local function as_json()
local function as_json(record)
    return require("dkjson").encode(record, { indent = true, keyorder = {
        "roadmap", "projects_read", "effort", "phases", "number", "components", "name", "used_by",
        "needs", "priority", "dependents", "complexity", "complexity_guessed", "home", "hours",
        "alone_hours", "shared_hours", "saved_hours", "cycles", "unordered", "projects", "project",
        "waits_on", "ready_after", "waits_on_unordered",
    } }) .. "\n"
end
-- }}}

-- {{{ local function show_help()
local function show_help()
    local file = io.open(arg[0], "r")
    if not file then return end
    for line in file:lines() do
        if line:match("^%-%- {{{") then break end
        if line:match("^%-%-") then print((line:gsub("^%-%- ?", ""))) end
    end
    file:close()
end
-- }}}

-- {{{ main
local function main(argv)
    local options, input = {}, nil
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key and ({ components = true, synonyms = true, out = true })[key] and not options[key] then
            options[key] = value
        elseif argument == "--json" then options.json = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif (argument == "-" or not argument:match("^%-")) and not input then input = argument
        else fail("unknown or repeated argument " .. argument .. " (see --help)") end
    end
    if not input then fail("name the file todone.lua --json wrote, or - for standard input") end
    if options.out and exists(options.out) then
        fail(options.out .. " already exists and is never replaced", 1)
    end
    if options.components and not exists(options.components) then
        fail(options.components .. " does not exist", 1)
    end

    local synonyms = component_names.load_synonyms(options.synonyms or SYNONYMS)
    local todone = read_todone(input)
    local facts = read_components(options.components or COMPONENTS, synonyms)
    local _, order = build_graph(todone, facts)
    score(order)
    local phases, left, cycles = plan(order)
    local record = as_record(todone, order, phases, left, cycles)
    local text = options.json and as_json(record) or as_markdown(record)
    if options.out then
        local file = io.open(options.out, "w") or fail("cannot write " .. options.out, 1)
        file:write(text)
        file:close()
        io.stderr:write("todone-roadmap: written to " .. options.out .. "\n")
    else
        io.write(text)
    end
    for _, cycle in ipairs(cycles) do
        io.stderr:write("todone-roadmap: a cycle, left out of the order: " .. table.concat(cycle, " needs ") .. "\n")
    end
    return 0
end
-- }}}

os.exit(main(arg))
