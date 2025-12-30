#!/usr/bin/env luajit
--[[
Quest & Bounty Generator

Generates gamified task documentation from structured input.
Transforms bug descriptions into adventure-style quests and bounties.

Usage:
  luajit quest-generator.lua bounty --name "..." --threat 8 ...
  luajit quest-generator.lua quest --tier seedling --xp 50 ...
  luajit quest-generator.lua from-spec quests.lua
  luajit quest-generator.lua scan-codebase --pattern "TODO|FIXME|BUG"
]]

local DIR = arg[0]:match("(.*/)")
if not DIR then DIR = "./" end

-- {{{ Utility functions
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end
-- }}}

-- {{{ write_file
local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then
        io.stderr:write("Error: Cannot write to " .. path .. "\n")
        return false
    end
    f:write(content)
    f:close()
    return true
end
-- }}}

-- {{{ threat_meter
local function threat_meter(level)
    local filled = string.rep("#", level)
    local empty = string.rep(".", 10 - level)
    return filled .. empty
end
-- }}}

-- {{{ generate_bounty
local function generate_bounty(spec)
    local template = [[
# BOUNTY BOARD: %s

```
+======================================================================+
|  BOSS MONSTER BOUNTY                                                 |
|                                                                      |
|  Name: %s
|  Threat Level: %s (%d/10)
|  Location: %s (%s:%s)
|  Reward: %s
|                                                                      |
|  "%s
|   %s
|   %s"
|                                                                      |
+======================================================================+
```

---

## The Monster's Nature

%s

---

## Lair Location

```%s
-- %s, lines %s
%s
```

---

## Battle Strategy

### What the Monster Exploits

%s

### Weapons Required

%s

---

## Victory Conditions

%s

---

## Test Arena

```%s
%s
```

---

## Adventurer's Log

*"%s"*

-- %s

---

## Related Scrolls

%s

---

**Bounty Posted By:** %s
**Date:** %s
**Status:** %s
]]

    -- Build victory conditions
    local conditions = ""
    for _, cond in ipairs(spec.conditions or {}) do
        conditions = conditions .. "- [ ] " .. cond .. "\n"
    end

    -- Build weapons section
    local weapons = ""
    for i, weapon in ipairs(spec.weapons or {}) do
        weapons = weapons .. string.format("**Weapon %d: %s**\n\n```%s\n%s\n```\n\n",
            i, weapon.name, spec.language or "lua", weapon.code)
    end

    -- Build related scrolls
    local scrolls = ""
    for _, scroll in ipairs(spec.related or {}) do
        scrolls = scrolls .. string.format("- `%s` - %s\n", scroll.file, scroll.desc)
    end

    local name_upper = spec.name:upper()
    -- Pad name to fit box
    local name_padded = name_upper .. string.rep(" ", 40 - #name_upper)

    return string.format(template,
        spec.name,
        name_padded,
        threat_meter(spec.threat), spec.threat,
        spec.location_desc or "The Source", spec.file, spec.line or "?",
        spec.reward or "Victory",
        spec.tagline and spec.tagline[1] or "",
        spec.tagline and spec.tagline[2] or "",
        spec.tagline and spec.tagline[3] or "",
        spec.description or "A dangerous bug lurks here.",
        spec.language or "lua",
        spec.file, spec.line_range or spec.line or "?",
        spec.code_snippet or "-- code here",
        spec.exploitation or "The bug exploits...",
        weapons,
        conditions,
        spec.language or "lua",
        spec.test_code or "-- test here",
        spec.lore_quote or "The bug was fearsome.",
        spec.lore_attribution or "Anonymous",
        scrolls,
        spec.posted_by or "The Guild",
        os.date("%Y-%m-%d"),
        spec.status or "UNCLAIMED"
    )
end
-- }}}

-- {{{ generate_quest
local function generate_quest(spec)
    local template = [[
### Quest %s: %s
**Location:** `%s:%s`
**XP Reward:** %d
**Skill Gained:** %s

*"%s"*

```%s
-- THE PROBLEM
%s
-- %s
```

**Your Quest:**
%s

**Reward:** %s

---
]]

    -- Build task list
    local tasks = ""
    for _, task in ipairs(spec.tasks or {}) do
        tasks = tasks .. "- [ ] " .. task .. "\n"
    end

    return string.format(template,
        spec.id or "?",
        spec.name or "Unnamed Quest",
        spec.file or "unknown.lua",
        spec.line or "?",
        spec.xp or 50,
        spec.skill or "Unknown Skill",
        spec.flavor or "A bug awaits.",
        spec.language or "lua",
        spec.code or "-- code here",
        spec.problem_comment or "This is the problem",
        tasks,
        spec.reward or "Knowledge and experience."
    )
end
-- }}}

-- {{{ tier_info
local TIER_INFO = {
    seedling = { prefix = "S", xp_min = 50, xp_max = 75, emoji = ":seedling:" },
    apprentice = { prefix = "A", xp_min = 100, xp_max = 150, emoji = ":herb:" },
    journeyman = { prefix = "J", xp_min = 200, xp_max = 300, emoji = ":crossed_swords:" },
    veteran = { prefix = "V", xp_min = 400, xp_max = 600, emoji = ":european_castle:" },
}
-- }}}

-- {{{ generate_quest_log
local function generate_quest_log(spec)
    local sections = {
        seedling = {},
        apprentice = {},
        journeyman = {},
        veteran = {},
    }

    -- Sort quests into tiers
    for _, quest in ipairs(spec.quests or {}) do
        local tier = quest.tier or "seedling"
        table.insert(sections[tier], quest)
    end

    local output = string.format([[
# The Adventurer's Quest Log

```
+======================================================================+
|                                                                      |
|   QUEST BOARD - %s                                                   |
|                                                                      |
|   "%s"                                                               |
|                                                                      |
+======================================================================+
```

---

## Your Adventure Begins

%s

---

]], spec.project or "PROJECT", spec.motto or "Start small. Slay slimes. Then dragons.",
    spec.intro or "Welcome, brave adventurer.")

    -- Generate each tier section
    for _, tier_name in ipairs({"seedling", "apprentice", "journeyman", "veteran"}) do
        local tier = TIER_INFO[tier_name]
        output = output .. string.format("## Quest Tier: %s %s\n\n",
            tier.emoji, tier_name:sub(1,1):upper() .. tier_name:sub(2))

        if #sections[tier_name] == 0 then
            output = output .. "*(No quests at this tier yet)*\n\n"
        else
            for _, quest in ipairs(sections[tier_name]) do
                output = output .. generate_quest(quest)
            end
        end
        output = output .. "---\n\n"
    end

    -- Add bounty links if present
    if spec.bounties and #spec.bounties > 0 then
        output = output .. "## The Boss Bounties\n\n"
        output = output .. "*When you have completed the Veteran quests, you are ready.*\n\n"
        output = output .. "| Bounty | Monster | Threat |\n"
        output = output .. "|--------|---------|--------|\n"
        for _, bounty in ipairs(spec.bounties) do
            output = output .. string.format("| %s | [%s](%s) | %s |\n",
                bounty.id, bounty.name, bounty.file, threat_meter(bounty.threat))
        end
        output = output .. "\n---\n\n"
    end

    output = output .. string.format([[
**Quest Board Maintained By:** %s
**Last Updated:** %s
]], spec.maintainer or "The Guild", os.date("%Y-%m-%d"))

    return output
end
-- }}}

-- {{{ scan_codebase
local function scan_codebase(root, pattern)
    -- Use grep to find TODOs, FIXMEs, BUGs
    local cmd = string.format("grep -rn '%s' '%s' --include='*.lua' 2>/dev/null", pattern, root)
    local handle = io.popen(cmd)
    if not handle then return {} end

    local results = {}
    for line in handle:lines() do
        local file, linenum, content = line:match("^(.+):(%d+):(.+)$")
        if file and linenum then
            table.insert(results, {
                file = file,
                line = tonumber(linenum),
                content = content,
                type = content:match("TODO") and "todo"
                    or content:match("FIXME") and "fixme"
                    or content:match("BUG") and "bug"
                    or "unknown"
            })
        end
    end
    handle:close()

    return results
end
-- }}}

-- {{{ suggest_quests_from_scan
local function suggest_quests_from_scan(results)
    local suggestions = {}

    for _, hit in ipairs(results) do
        local tier = "seedling"
        local xp = 50

        -- Estimate difficulty from content
        if hit.content:match("CRITICAL") or hit.content:match("SECURITY") then
            tier = "veteran"
            xp = 500
        elseif hit.content:match("performance") or hit.content:match("refactor") then
            tier = "journeyman"
            xp = 250
        elseif hit.content:match("error") or hit.content:match("handle") then
            tier = "apprentice"
            xp = 100
        end

        table.insert(suggestions, {
            file = hit.file,
            line = hit.line,
            tier = tier,
            xp = xp,
            raw = hit.content,
            type = hit.type
        })
    end

    return suggestions
end
-- }}}

-- {{{ parse_args
local function parse_args(args)
    local parsed = {
        command = nil,
        options = {}
    }

    local i = 1
    while i <= #args do
        local arg = args[i]

        if not parsed.command and not arg:match("^%-") then
            parsed.command = arg
        elseif arg == "--name" then
            i = i + 1
            parsed.options.name = args[i]
        elseif arg == "--threat" then
            i = i + 1
            parsed.options.threat = tonumber(args[i])
        elseif arg == "--location" or arg == "--file" then
            i = i + 1
            parsed.options.file = args[i]
        elseif arg == "--line" then
            i = i + 1
            parsed.options.line = args[i]
        elseif arg == "--tier" then
            i = i + 1
            parsed.options.tier = args[i]
        elseif arg == "--xp" then
            i = i + 1
            parsed.options.xp = tonumber(args[i])
        elseif arg == "--output" or arg == "-o" then
            i = i + 1
            parsed.options.output = args[i]
        elseif arg == "--pattern" then
            i = i + 1
            parsed.options.pattern = args[i]
        elseif arg == "--root" then
            i = i + 1
            parsed.options.root = args[i]
        elseif arg == "--help" or arg == "-h" then
            parsed.command = "help"
        else
            -- Positional arg for from-spec
            if parsed.command == "from-spec" and not parsed.options.spec_file then
                parsed.options.spec_file = arg
            end
        end

        i = i + 1
    end

    return parsed
end
-- }}}

-- {{{ show_help
local function show_help()
    print([[
Quest & Bounty Generator

Usage:
  luajit quest-generator.lua <command> [options]

Commands:
  bounty          Generate a boss monster bounty board
  quest           Generate a single quest entry
  quest-log       Generate a full quest log from spec
  from-spec       Generate from a Lua specification file
  scan            Scan codebase for TODOs/FIXMEs and suggest quests
  help            Show this help

Options:
  --name <str>    Monster/quest name
  --threat <n>    Threat level 1-10 (for bounty)
  --tier <str>    Quest tier: seedling, apprentice, journeyman, veteran
  --xp <n>        XP reward
  --file <path>   Source file location
  --line <n>      Line number
  --output <path> Output file path (default: stdout)
  --pattern <str> Grep pattern for scan (default: TODO|FIXME|BUG)
  --root <path>   Root directory for scan

Examples:
  # Generate a bounty
  luajit quest-generator.lua bounty \
    --name "The Phantom Priority" \
    --threat 8 \
    --file "astar.lua" \
    --line 355 \
    --output issues/B04-phantom.md

  # Scan and suggest quests
  luajit quest-generator.lua scan --root src/ --pattern "TODO|FIXME"

  # Generate from spec file
  luajit quest-generator.lua from-spec quests.lua
]])
end
-- }}}

-- {{{ main
local function main()
    local parsed = parse_args(arg)

    if not parsed.command or parsed.command == "help" then
        show_help()
        return
    end

    if parsed.command == "bounty" then
        local spec = {
            name = parsed.options.name or "Unnamed Monster",
            threat = parsed.options.threat or 5,
            file = parsed.options.file or "unknown.lua",
            line = parsed.options.line or "?",
            description = "A bug lurks in the code.",
            tagline = {"It strikes without warning.", "None have survived.", "Will you be the first?"},
            conditions = {"Fix the bug", "Add tests", "Update documentation"},
            weapons = {},
            related = {},
        }

        local output = generate_bounty(spec)

        if parsed.options.output then
            write_file(parsed.options.output, output)
            print("Bounty written to: " .. parsed.options.output)
        else
            print(output)
        end

    elseif parsed.command == "quest" then
        local tier = parsed.options.tier or "seedling"
        local tier_info = TIER_INFO[tier]

        local spec = {
            id = (tier_info and tier_info.prefix or "?") .. "1",
            name = parsed.options.name or "Unnamed Quest",
            tier = tier,
            file = parsed.options.file or "unknown.lua",
            line = parsed.options.line or "?",
            xp = parsed.options.xp or (tier_info and tier_info.xp_min) or 50,
            skill = "Unknown Skill",
            flavor = "A challenge awaits.",
            code = "-- the problematic code",
            problem_comment = "This is what's wrong",
            tasks = {"Fix it", "Test it", "Document it"},
            reward = "Knowledge gained.",
        }

        local output = generate_quest(spec)

        if parsed.options.output then
            write_file(parsed.options.output, output)
            print("Quest written to: " .. parsed.options.output)
        else
            print(output)
        end

    elseif parsed.command == "scan" then
        local root = parsed.options.root or "src/"
        local pattern = parsed.options.pattern or "TODO\\|FIXME\\|BUG"

        print("Scanning " .. root .. " for: " .. pattern)
        local results = scan_codebase(root, pattern)
        local suggestions = suggest_quests_from_scan(results)

        print(string.format("\nFound %d potential quests:\n", #suggestions))

        for i, s in ipairs(suggestions) do
            print(string.format("%d. [%s] %s:%d (%s, %d XP)",
                i, s.type:upper(), s.file, s.line, s.tier, s.xp))
            print("   " .. s.raw:sub(1, 60))
        end

    elseif parsed.command == "from-spec" then
        local spec_file = parsed.options.spec_file
        if not spec_file then
            io.stderr:write("Error: No spec file provided\n")
            return
        end

        -- Load and execute spec file
        local chunk, err = loadfile(spec_file)
        if not chunk then
            io.stderr:write("Error loading spec: " .. err .. "\n")
            return
        end

        local spec = chunk()
        if not spec then
            io.stderr:write("Error: Spec file returned nil\n")
            return
        end

        local output = generate_quest_log(spec)

        if parsed.options.output then
            write_file(parsed.options.output, output)
            print("Quest log written to: " .. parsed.options.output)
        else
            print(output)
        end

    else
        io.stderr:write("Unknown command: " .. parsed.command .. "\n")
        show_help()
    end
end
-- }}}

main()
