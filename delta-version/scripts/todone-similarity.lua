#!/usr/bin/env luajit
-- todone-similarity.lua - which of the components todone.lua found are the
-- same thing under different names, and how sure that is.
--
-- Issue 053b, tiers 1-4. todone.lua lists what each project plans to build;
-- this groups those names into clusters, each member with a confidence:
--   tier 1  1.0   the same name once case, spaces, "-" and "_" are ignored
--   tier 2  0.95  names listed together in config/component-synonyms.conf
--   tier 3  0.8   a likely typo: one letter apart (names of 5+ letters) or
--                 two apart (9+ letters), e.g. threadpool ~ thredpool
--   tier 4  0.85  the local model says yes when asked about an uncertain
--                 pair: names that share a word, one inside the other, or
--                 three letters apart. "maybe" and unclear answers are not
--                 merged; they are listed as uncertain for a person to judge.
-- A member's confidence is the weakest link between it and the cluster's
-- first name. Tier 5 (a large model with code context) is not built.
--
-- Nothing is written anywhere; this only reports.
--
-- Usage: todone.lua --all --json --each > found.json
--        todone-similarity.lua found.json|- [--max-tier=1..4] [--max-asks=N]
--                              [--min=N] [--synonyms=FILE] [--json]
--   --max-tier=N   use tiers up to N (default 3: no model; 4 asks the model)
--   --max-asks=N   ask about at most N pairs (default 20)
--   --min=N        a cluster planned by N or more projects is a library
--                  candidate (default 2)
--   --synonyms=FILE   default config/component-synonyms.conf
--   --json         the report as JSON (clusters, unclustered, uncertain,
--                  analysis_stats)
--
-- The input needs todone's "each" list (from --each); without it the
-- "shared" list is used, which has lost the single-project names. The model
-- is reached through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST moves
-- it). Exit status: 0 done, 1 the model failed on some pairs (they are
-- listed as uncertain), 2 usage error.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
local SYNONYMS = SCRIPT_DIR .. "/../config/component-synonyms.conf"
-- }}}

-- {{{ Configuration
local config = {
    confidence = { [1] = 1.0, [2] = 0.95, [3] = 0.8, [4] = 0.85 },
    maybe_confidence = 0.5,
    max_asks = 20,
    system_prompt = table.concat({
        "Task: same-component.",
        "Two projects each plan to build a software component. Given the two names,",
        "say whether they are the same kind of component, so one shared library could",
        "serve both. Reply with one word: yes, no or maybe.",
    }, "\n"),
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message)
    io.stderr:write("todone-similarity: " .. message .. "\n")
    os.exit(2)
end
-- }}}

-- {{{ local function key_of()
-- Tier 1, the same rule todone.lua matches by.
local function key_of(name)
    return (name:lower():gsub("[%s%-_]+", ""))
end
-- }}}

-- {{{ local function load_synonyms()
-- Tier 2: "name = alias, alias" lines, as todone.lua reads them. Returns
-- key -> the line's first name.
local function load_synonyms(path)
    local map = {}
    local file = io.open(path, "r")
    if not file then return map end
    for line in file:lines() do
        line = line:gsub("#.*$", "")
        local name, aliases = line:match("^%s*([^=]-)%s*=%s*(.-)%s*$")
        if name and name ~= "" then
            map[key_of(name)] = name
            for alias in aliases:gmatch("[^,]+") do
                alias = alias:gsub("^%s+", ""):gsub("%s+$", "")
                if alias ~= "" then map[key_of(alias)] = name end
            end
        end
    end
    file:close()
    return map
end
-- }}}

-- {{{ local function distance()
-- Levenshtein distance between two strings, by bytes.
local function distance(a, b)
    if a == b then return 0 end
    local previous = {}
    for j = 0, #b do previous[j] = j end
    for i = 1, #a do
        local current = { [0] = i }
        local ca = a:byte(i)
        for j = 1, #b do
            local cost = (ca == b:byte(j)) and 0 or 1
            current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous = current
    end
    return previous[#b]
end
-- }}}

-- {{{ local function words_of()
-- The words of a name (split at spaces, "-", "_" and lower-to-upper case
-- changes), lower case, four letters or more.
local function words_of(name)
    local spaced = name:gsub("(%l)(%u)", "%1 %2"):lower()
    local words = {}
    for word in spaced:gmatch("[%w]+") do
        if #word >= 4 then words[word] = true end
    end
    return words
end
-- }}}
-- }}}

-- {{{ local function read_input()
-- Component mentions { name, project } from todone's JSON.
local function read_input(path)
    local text
    if path == "-" then text = io.read("*a")
    else
        local file = io.open(path, "r") or fail("cannot read " .. path)
        text = file:read("*a")
        file:close()
    end
    local data = require("dkjson").decode(text)
    if type(data) ~= "table" then fail(path .. " is not todone.lua's JSON (todone.lua --json --each)") end
    local mentions = {}
    if type(data.each) == "table" then
        for _, item in ipairs(data.each) do
            for _, name in ipairs(item.components or {}) do
                mentions[#mentions + 1] = { name = name, project = item.project }
            end
        end
        return mentions, false
    end
    if type(data.shared) ~= "table" then fail(path .. " has neither an \"each\" nor a \"shared\" list") end
    for _, entry in ipairs(data.shared) do
        for _, project in ipairs(entry.projects or {}) do
            mentions[#mentions + 1] = { name = entry.name, project = project }
        end
    end
    return mentions, true
end
-- }}}

-- {{{ local function gather()
-- Tier 1: one node per spelling key, with the projects that name it.
local function gather(mentions)
    local nodes, by_key = {}, {}
    for _, mention in ipairs(mentions) do
        local key = key_of(mention.name)
        if key ~= "" then
            local node = by_key[key]
            if not node then
                node = { key = key, name = mention.name, projects = {}, seen = {} }
                by_key[key] = node
                nodes[#nodes + 1] = node
            end
            if not node.seen[mention.project] then
                node.seen[mention.project] = true
                node.projects[#node.projects + 1] = mention.project
            end
        end
    end
    return nodes, #mentions - #nodes
end
-- }}}

-- {{{ Union-find with recorded links
local function new_sets(nodes)
    local sets = { parent = {}, links = {} }
    for index = 1, #nodes do sets.parent[index] = index end
    return sets
end

local function find(sets, index)
    while sets.parent[index] ~= index do
        sets.parent[index] = sets.parent[sets.parent[index]]
        index = sets.parent[index]
    end
    return index
end

local function join(sets, a, b, tier, confidence)
    local ra, rb = find(sets, a), find(sets, b)
    if ra == rb then return false end
    sets.parent[rb] = ra
    sets.links[#sets.links + 1] = { a = a, b = b, tier = tier, confidence = confidence }
    return true
end
-- }}}

-- {{{ local function tier3_match()
local function tier3_match(a, b)
    local shorter = math.min(#a, #b)
    if math.abs(#a - #b) > 2 or shorter < 5 then return false end
    local d = distance(a, b)
    return (d == 1 and shorter >= 5) or (d == 2 and shorter >= 9)
end
-- }}}

-- {{{ local function uncertain_pair()
-- Worth asking the model about: a shared word, one name inside the other,
-- or three letters apart.
local function uncertain_pair(x, y)
    for word in pairs(words_of(x.name)) do
        if words_of(y.name)[word] then return true end
    end
    local a, b = x.key, y.key
    if math.min(#a, #b) >= 4 and (a:find(b, 1, true) or b:find(a, 1, true)) then return true end
    return math.min(#a, #b) >= 6 and math.abs(#a - #b) <= 3 and distance(a, b) <= 3
end
-- }}}

-- {{{ local function ask()
-- "yes", "no", "maybe", or nil and a reason.
local function ask(client, x, y)
    local text = string.format("A: %s (planned in %s)\nB: %s (planned in %s)",
        x.name, table.concat(x.projects, ", "), y.name, table.concat(y.projects, ", "))
    local answer, err = client.complete(config.system_prompt, text, { temperature = 0.1, max_tokens = 10 })
    if not answer then return nil, tostring(err) end
    answer = answer:gsub("<think>.-</think>", "")
    local word = answer:match("^%s*(%a+)")
    word = word and word:lower()
    if word == "yes" or word == "no" or word == "maybe" then return word end
    return nil, "unclear answer: " .. answer:sub(1, 40):gsub("\n", " ")
end
-- }}}

-- {{{ local function cluster()
-- Runs the tiers and returns clusters, unclustered, uncertain, stats.
local function cluster(nodes, options)
    local sets = new_sets(nodes)
    local stats = { tier1_matches = options.tier1, tier2_matches = 0, tier3_matches = 0,
        tier4_queries = 0, tier4_matches = 0, total_components = #nodes }
    local uncertain, failures = {}, 0

    if options.max_tier >= 2 then
        local first_of = {}
        for index, node in ipairs(nodes) do
            local canonical = options.synonyms[node.key]
            if canonical then
                node.canonical = canonical
                local key = key_of(canonical)
                if first_of[key] then
                    if join(sets, first_of[key], index, 2, config.confidence[2]) then
                        stats.tier2_matches = stats.tier2_matches + 1
                    end
                else
                    first_of[key] = index
                end
            end
        end
    end

    if options.max_tier >= 3 then
        for i = 1, #nodes do
            for j = i + 1, #nodes do
                if find(sets, i) ~= find(sets, j) and tier3_match(nodes[i].key, nodes[j].key) then
                    join(sets, i, j, 3, config.confidence[3])
                    stats.tier3_matches = stats.tier3_matches + 1
                end
            end
        end
    end

    if options.max_tier >= 4 then
        local client = require("llama-chat-client")
        local down = false
        for i = 1, #nodes do
            for j = i + 1, #nodes do
                if find(sets, i) ~= find(sets, j) and uncertain_pair(nodes[i], nodes[j]) then
                    local pair = { a = nodes[i].name, b = nodes[j].name }
                    if down or stats.tier4_queries >= options.max_asks then
                        pair.answer = down and "not asked: the model could not be reached"
                            or "not asked: --max-asks reached"
                        uncertain[#uncertain + 1] = pair
                    else
                        stats.tier4_queries = stats.tier4_queries + 1
                        local answer, why = ask(client, nodes[i], nodes[j])
                        if answer == "yes" then
                            join(sets, i, j, 4, config.confidence[4])
                            stats.tier4_matches = stats.tier4_matches + 1
                        elseif answer == "maybe" then
                            pair.answer, pair.confidence = "maybe", config.maybe_confidence
                            uncertain[#uncertain + 1] = pair
                        elseif not answer then
                            failures = failures + 1
                            if why:match("^unreachable") or why:match("^no reply") then down = true end
                            pair.answer = why
                            uncertain[#uncertain + 1] = pair
                        end
                    end
                end
            end
        end
    end

    -- Gather each set and give each member its weakest-link confidence from
    -- the set's first node (the one most projects plan, then the first seen).
    local groups, order = {}, {}
    for index = 1, #nodes do
        local root = find(sets, index)
        if not groups[root] then groups[root] = {} order[#order + 1] = root end
        table.insert(groups[root], index)
    end
    local neighbours = {}
    for _, link in ipairs(sets.links) do
        neighbours[link.a] = neighbours[link.a] or {}
        neighbours[link.b] = neighbours[link.b] or {}
        table.insert(neighbours[link.a], { to = link.b, link = link })
        table.insert(neighbours[link.b], { to = link.a, link = link })
    end

    local clusters, unclustered = {}, {}
    for _, root in ipairs(order) do
        local members = groups[root]
        table.sort(members, function(a, b)
            if #nodes[a].projects ~= #nodes[b].projects then return #nodes[a].projects > #nodes[b].projects end
            return a < b
        end)
        local head = members[1]
        local best, tier = { [head] = 1.0 }, { [head] = 1 }
        local changed = true
        while changed do
            changed = false
            for _, index in ipairs(members) do
                if best[index] then
                    for _, edge in ipairs(neighbours[index] or {}) do
                        local value = math.min(best[index], edge.link.confidence)
                        if not best[edge.to] or value > best[edge.to] then
                            best[edge.to], tier[edge.to] = value, math.max(tier[index], edge.link.tier)
                            changed = true
                        end
                    end
                end
            end
        end
        local projects, seen, listed = {}, {}, {}
        for _, index in ipairs(members) do
            for _, project in ipairs(nodes[index].projects) do
                if not seen[project] then seen[project] = true projects[#projects + 1] = project end
            end
            listed[#listed + 1] = { name = nodes[index].name, projects = nodes[index].projects,
                confidence = best[index], tier = tier[index] }
        end
        if #members == 1 and #projects == 1 then
            unclustered[#unclustered + 1] = { name = nodes[head].name, projects = projects,
                reason = "no similar components found" }
        else
            local canonical = nodes[head].canonical
            for _, index in ipairs(members) do canonical = canonical or nodes[index].canonical end
            clusters[#clusters + 1] = { canonical_name = canonical or nodes[head].name, members = listed,
                total_projects = #projects, library_candidate = #projects >= options.min }
        end
    end
    table.sort(clusters, function(a, b)
        if a.total_projects ~= b.total_projects then return a.total_projects > b.total_projects end
        return a.canonical_name < b.canonical_name
    end)
    stats.total_clusters = #clusters
    return clusters, unclustered, uncertain, stats, failures
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
    local options, path = {}, nil
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key and ({ ["max-tier"] = true, ["max-asks"] = true, min = true, synonyms = true })[key]
            and options[key] == nil then options[key] = value
        elseif argument == "--json" then options.json = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif (argument == "-" or not argument:match("^%-")) and not path then path = argument
        else fail("unknown or repeated argument " .. argument .. " (see --help)") end
    end
    if not path then fail("name todone.lua's JSON (todone.lua --json --each), or - for standard input") end
    local function whole(name, text, low, high)
        local number = tonumber(text)
        if not number or number % 1 ~= 0 or number < low or (high and number > high) then
            fail("--" .. name .. " takes a whole number" .. (high and (" from " .. low .. " to " .. high) or ""))
        end
        return number
    end
    local max_tier = whole("max-tier", options["max-tier"] or "3", 1, 4)
    local max_asks = whole("max-asks", options["max-asks"] or tostring(config.max_asks), 0)
    local minimum = whole("min", options.min or "2", 1)

    local mentions, shared_only = read_input(path)
    local nodes, tier1 = gather(mentions)
    local clusters, unclustered, uncertain, stats, failures = cluster(nodes, {
        max_tier = max_tier, max_asks = max_asks, min = minimum, tier1 = tier1,
        synonyms = load_synonyms(options.synonyms or SYNONYMS),
    })

    if options.json then
        local keyorder = { "canonical_name", "members", "name", "projects", "confidence", "tier",
            "total_projects", "library_candidate", "reason", "a", "b", "answer",
            "tier1_matches", "tier2_matches", "tier3_matches", "tier4_queries", "tier4_matches",
            "total_components", "total_clusters", "clusters", "unclustered", "uncertain", "analysis_stats" }
        print(require("dkjson").encode({ clusters = clusters, unclustered = unclustered, uncertain = uncertain,
            analysis_stats = stats }, { indent = true, keyorder = keyorder }))
    else
        if shared_only then
            print("(no \"each\" list in the input, so names only one project planned are missing;"
                .. " run todone.lua with --each)\n")
        end
        print(string.format("%d clusters from %d component names (tier 1: %d, tier 2: %d, tier 3: %d,"
            .. " tier 4: %d of %d asked)\n", #clusters, stats.total_components, stats.tier1_matches,
            stats.tier2_matches, stats.tier3_matches, stats.tier4_matches, stats.tier4_queries))
        for _, item in ipairs(clusters) do
            print(string.format("  %-24s %d project%s%s", item.canonical_name, item.total_projects,
                item.total_projects == 1 and "" or "s", item.library_candidate and "  library candidate" or ""))
            for _, member in ipairs(item.members) do
                print(string.format("      %-22s %.2f  tier %d  %s", member.name, member.confidence,
                    member.tier, table.concat(member.projects, ", ")))
            end
        end
        if #uncertain > 0 then
            print("\nUncertain (not merged; a person should judge):")
            for _, pair in ipairs(uncertain) do
                print(string.format("  %s ~ %s: %s", pair.a, pair.b, pair.answer))
            end
        end
        if #unclustered > 0 then
            local names = {}
            for _, item in ipairs(unclustered) do names[#names + 1] = item.name end
            print("\nOnly one project plans: " .. table.concat(names, ", "))
        end
    end
    return failures > 0 and 1 or 0
end
-- }}}

os.exit(main(arg))
