-- 035-instructions.lua
--
-- The standing instructions every turn is handed (docs/005, "crafts"): the
-- machine's rules for that kind of turn, the paths it may read and write, the
-- owner's skill files the kind names (its crafts), and the center's paragraph
-- (phase 7). Written to the turn's instructions.md; the Claude Code harness
-- appends it to the model's system prompt.
--
-- Crafts come from two places: the kind's own list in the kinds table, and —
-- for build and repair turns — the skills the person names in the case's
-- input/crafts file, one per line. That file is how "whatever technology
-- marvels the claude-code skill files tell it how to build" reaches a build.

local fs = require("017-the-filesystem")

local instructions = {}

-- The largest instructions a turn may be given: the Claude Code harness
-- passes them as one argument, and a single argument is limited to 128 KiB
-- by the kernel. Refused above this rather than cut.
instructions.LIMIT = 120 * 1024

-- Kinds that take the person's crafts from input/crafts.
local TAKES_PERSON_CRAFTS = { build = true, repair = true }

-- {{{ local function rules_for
local function rules_for(turn)
    local out = {
        "# Standing instructions for one turn of the machine",
        "",
        "You are one turn of a machine that turns software into blueprints (issue",
        "files) and blueprints back into software. The machine started you for one",
        "job, described in the prompt, and will check your work when you stop.",
        "",
        "- Nobody is there to answer questions. Do not ask any; decide, and say what",
        "  you decided in the files you write.",
        "- Do not run commands, commit, or change anything but what the job names.",
        "- After you stop, the machine compares every file in the case and the source",
        "  with how they were before you started. A change outside the paths you may",
        "  write below is a breach: your whole turn is thrown away.",
        "",
        "You may read:",
    }
    for _, p in ipairs(turn.reads) do
        out[#out + 1] = "  " .. p
    end
    out[#out + 1] = ""
    out[#out + 1] = "You may write (paths starting with):"
    for _, p in ipairs(turn.writes) do
        out[#out + 1] = "  " .. p
    end
    if turn.kind == "build" or turn.kind == "repair" then
        out[#out + 1] = ""
        out[#out + 1] = "The original source does not exist for you. Everything you need is in"
        out[#out + 1] = "the blueprint; where it is silent, choose, and write the choice down in"
        out[#out + 1] = "a comment beside the code it shaped."
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ function instructions.person_crafts
-- Skill names from the case's input/crafts, one per line; blank lines and
-- lines starting with # are skipped.
function instructions.person_crafts(record)
    local path = record.input .. "/crafts"
    local names = {}
    if not fs.exists(path) then
        return names
    end
    for line in fs.read(path):gmatch("[^\n]+") do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" and name:sub(1, 1) ~= "#" then
            names[#names + 1] = name
        end
    end
    return names
end
-- }}}

-- {{{ function instructions.write
-- Assembles and writes the turn's instructions.md. `skills_folder` is where
-- skill folders live; `center_paragraph` is phase 7's (may be ""). Returns
-- the text. Refuses when a named craft's file is missing — a turn meant to
-- build the owner's way that cannot is not started without saying so.
function instructions.write(turn, record, skills_folder, center_paragraph)
    local parts = { rules_for(turn) }
    local crafts = {}
    for _, name in ipairs(turn.crafts) do
        crafts[#crafts + 1] = name
    end
    if TAKES_PERSON_CRAFTS[turn.kind] then
        for _, name in ipairs(instructions.person_crafts(record)) do
            crafts[#crafts + 1] = name
        end
    end
    for _, name in ipairs(crafts) do
        local path = skills_folder .. "/" .. name .. "/SKILL.md"
        if not fs.exists(path) then
            error("instructions: the craft '" .. name .. "' has no skill file at " .. path)
        end
        parts[#parts + 1] = "# Craft: " .. name .. "\n\n" .. fs.read(path)
    end
    if center_paragraph and center_paragraph ~= "" then
        parts[#parts + 1] = "# What the person has been attending to\n\n" .. center_paragraph
    end
    local text = table.concat(parts, "\n\n") .. "\n"
    if #text > instructions.LIMIT then
        error(string.format("instructions: %d bytes for turn %s, over the %d byte limit; name fewer crafts",
            #text, turn.id, instructions.LIMIT))
    end
    fs.write(turn.folder .. "/instructions.md", text)
    turn.crafts_given = crafts
    return text
end
-- }}}

return instructions
