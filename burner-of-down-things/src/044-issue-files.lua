-- 044-issue-files.lua
--
-- Reading a blueprint's issue files and checking each against the outline
-- (docs/006, "an issue file"). An issue is only as good as what a builder
-- can do with it, so the checks are the ones a build depends on: every
-- required section present, the same blockers the outline planned, at least
-- one acceptance command (an issue with no checks cannot be said to pass),
-- and the house validator's verdict.
--
-- An issue (in memory): id, name, path (strings); sections (heading ->
-- text); blocked_by (array of ids); acceptance (array of shell commands);
-- text (the whole file).

local fs = require("017-the-filesystem")
local outline = require("042-the-outline")

local issue_files = {}

issue_files.REQUIRED = {
    "Current Behavior", "Intended Behavior", "Suggested Implementation Steps",
    "Acceptance", "Blocked by", "Covers",
}

-- {{{ function issue_files.read
function issue_files.read(path)
    local file_name = path:match("([^/]+)$")
    local id, name = file_name:match("^(%d%d%d)%-(.+)%.md$")
    if not id then
        error("issue files: '" .. file_name .. "' is not named <id>-<name>.md")
    end
    local text = fs.read(path)
    local sections = {}
    local current
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local heading = line:match("^## +(.-)%s*$")
        if heading then
            current = heading
            sections[current] = {}
        elseif current then
            local list = sections[current]
            list[#list + 1] = line
        end
    end
    for heading, lines in pairs(sections) do
        sections[heading] = table.concat(lines, "\n")
    end
    -- Blockers: every three-digit id under "Blocked by" ("None" gives none).
    local blocked_by = {}
    for found in (sections["Blocked by"] or ""):gmatch("%f[%d](%d%d%d)%f[%D]") do
        blocked_by[#blocked_by + 1] = found
    end
    table.sort(blocked_by)
    -- Acceptance: the lines of the fenced block; failing a fence, each
    -- bullet's backticked command.
    local acceptance = {}
    local body = sections["Acceptance"] or ""
    local fenced = body:match("```[%w]*\n(.-)\n```")
    if fenced then
        for line in fenced:gmatch("[^\n]+") do
            local command = line:match("^%s*(.-)%s*$")
            if command ~= "" and command:sub(1, 1) ~= "#" then
                acceptance[#acceptance + 1] = command
            end
        end
    else
        for command in body:gmatch("\n?%s*[-*]%s+`([^`]+)`") do
            acceptance[#acceptance + 1] = command
        end
    end
    return {
        id = id, name = name, path = path, sections = sections,
        blocked_by = blocked_by, acceptance = acceptance, text = text,
    }
end
-- }}}

-- {{{ function issue_files.find
-- The path of the issue file with this id in the issues folder, or nil.
function issue_files.find(issues_folder, id)
    for _, name in ipairs(fs.list(issues_folder)) do
        if name:sub(1, 4) == id .. "-" and name:match("%.md$") then
            return issues_folder .. "/" .. name
        end
    end
    return nil
end
-- }}}

-- {{{ function issue_files.check
-- Findings (sentences) for one issue against its outline row: its own
-- shape. The house validator's verdict is asked separately (validate).
function issue_files.check(issue, row)
    local findings = {}
    for _, heading in ipairs(issue_files.REQUIRED) do
        if not issue.sections[heading] then
            findings[#findings + 1] = "the section '## " .. heading .. "' is missing"
        end
    end
    local planned = outline.words(row.blocked_by)
    table.sort(planned)
    if table.concat(planned, " ") ~= table.concat(issue.blocked_by, " ") then
        findings[#findings + 1] = "Blocked by lists [" .. table.concat(issue.blocked_by, " ")
            .. "] but the outline plans [" .. table.concat(planned, " ") .. "]"
    end
    if #issue.acceptance == 0 then
        findings[#findings + 1] = "the Acceptance section holds no command (a ```sh block, one command per line)"
    end
    if issue.name ~= row.name then
        findings[#findings + 1] = "the file is named '" .. issue.name .. "' but the outline names it '" .. row.name .. "'"
    end
    return findings
end
-- }}}

-- {{{ function issue_files.validate
-- The house validator's findings for one issue file, as sentences. Refuses
-- when the validator is missing: the machine does not quietly check less.
function issue_files.validate(validator, blueprint_folder, path)
    if not fs.exists(validator) then
        error("issue files: the house validator is missing at " .. validator)
    end
    local out, ok = fs.capture(fs.quote(validator) .. " " .. fs.quote(blueprint_folder)
        .. " --file " .. fs.quote(path) .. " 2>&1")
    if ok then
        return {}
    end
    local findings = {}
    for line in out:gmatch("[^\n]+") do
        -- A blocker with no file yet is the machine's business, not this
        -- issue's: its blockers already equal the outline's (check above),
        -- and a blocker whose own describe turn failed is held and retried.
        -- Counting it here would fail an issue for its neighbour's trouble.
        if not line:find("which has no file", 1, true)
            and not line:match("^%d+ issues?, %d+ findings?")
            and not line:match("^next free id") and line:match("%S") then
            findings[#findings + 1] = "validator: " .. line
        end
    end
    return findings
end
-- }}}

return issue_files
