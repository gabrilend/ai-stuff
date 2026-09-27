-- 053-grading.lua
--
-- Where a request lands in the blueprint, and how deep it reaches (docs/008,
-- "the grade"). A locate turn reads the request and every issue's intended
-- behaviour and names the issues the change touches (or `new <phase>` for a
-- piece no issue describes). The grade is then decided by the machine from
-- the graph alone, so the same request against the same blueprint always
-- gets the same grade:
--
--   surface     every touched issue has nothing built on it
--   middle      some touched issue has others built on it, and the reach is
--               under half the blueprint
--   foundation  some touched issue is in level 0, or the reach is half the
--               blueprint or more
--
-- A request needing only new issues is surface: a new issue has nothing
-- built on it yet.

local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local kinds = require("034-turn-kinds")
local pool = require("039-the-turn-pool")
local graph = require("043-the-graph")
local issue_files = require("044-issue-files")

local grading = {}

grading.MOST_ATTEMPTS = 3

-- The lines between grades, in one place: when real updates show a line is
-- in the wrong place, moving it is a change here, recorded with its reason
-- in docs/balance-updates.md.
grading.RULE = {
    -- A reach of at least this fraction of the blueprint is foundation.
    foundation_fraction = 0.5,
    -- Touching an issue at this level or below is foundation.
    foundation_level = 0,
}

-- The grades in order of depth; `hold` compares against this.
grading.DEPTH = { none = 0, surface = 1, middle = 2, foundation = 3 }

-- {{{ function grading.grade
-- `touched` is an array of existing ids; `new_phases` an array of phase
-- digits for issues that do not exist yet. Returns grade and reach (sorted
-- ids of existing issues to rebuild).
function grading.grade(g, touched, new_phases)
    local reach = graph.reach(g, touched)
    if #touched == 0 then
        return "surface", reach
    end
    for _, id in ipairs(touched) do
        if g.nodes[id].level <= grading.RULE.foundation_level then
            return "foundation", reach
        end
    end
    if #reach >= #g.ids * grading.RULE.foundation_fraction then
        return "foundation", reach
    end
    for _, id in ipairs(touched) do
        if #g.nodes[id].blocks > 0 then
            return "middle", reach
        end
    end
    return "surface", reach
end
-- }}}

-- {{{ local function issue_list
-- Every issue's id, name and intended behaviour, for the locate prompt.
local function issue_list(record, g)
    local parts = {}
    for _, id in ipairs(g.ids) do
        local path = issue_files.find(record.issues, id)
        local intended = path and issue_files.read(path).sections["Intended Behavior"] or "(no file)"
        parts[#parts + 1] = "### " .. id .. " " .. g.nodes[id].name .. "\n" .. intended
    end
    return table.concat(parts, "\n\n")
end
-- }}}

-- {{{ function grading.parse_touched
-- Reads a locate turn's answer: ids and `new <phase>` lines. Returns
-- touched ids, new phases, and findings for anything that is neither an
-- existing id nor a well-formed new line.
function grading.parse_touched(text, g)
    local touched, new_phases, findings, seen = {}, {}, {}, {}
    for line in text:gmatch("[^\n]+") do
        local word = line:match("^%s*(.-)%s*$")
        local phase = word:match("^new%s+(%d)$")
        if phase then
            new_phases[#new_phases + 1] = phase
        elseif word ~= "" then
            if g.nodes[word] then
                if not seen[word] then
                    seen[word] = true
                    touched[#touched + 1] = word
                end
            else
                findings[#findings + 1] = "'" .. word .. "' is not an issue id in the blueprint (the ids are "
                    .. table.concat(g.ids, " ") .. ") nor a line `new <phase digit>`"
            end
        end
    end
    if #touched == 0 and #new_phases == 0 and #findings == 0 then
        findings[1] = "the answer names no issue"
    end
    table.sort(touched)
    return touched, new_phases, findings
end
-- }}}

-- {{{ function grading.locate
-- Runs locate turns until one answers well, up to MOST_ATTEMPTS. Returns
-- touched ids and new phases, or raises an error naming the last findings.
function grading.locate(project, record, g, request, options)
    local request_text = fs.read(record.input .. "/" .. request)
    local listing = issue_list(record, g)
    local findings_text = "none"
    for _ = 1, grading.MOST_ATTEMPTS do
        local turn = kinds.make_turn(record, "locate", {
            about = request, request = request, request_text = request_text,
            issue_list = listing, touched_path = "touched (a file in your working folder)",
            findings = findings_text,
        })
        local results, summary = pool.run_set(project, record, { turn }, options)
        if #summary.breaches > 0 then
            error("locate: the locate turn for " .. request .. " wrote outside its folders; stopping")
        end
        local problems = {}
        if results[1].verdict == "failed" then
            problems[1] = "the locate turn failed: " .. results[1].why
        elseif not fs.exists(turn.folder .. "/touched") then
            problems[1] = "no answer was written to touched"
        else
            local touched, new_phases, findings = grading.parse_touched(fs.read(turn.folder .. "/touched"), g)
            if #findings == 0 then
                return touched, new_phases, turn
            end
            problems = findings
        end
        findings_text = table.concat(problems, "\n")
    end
    error("locate: " .. grading.MOST_ATTEMPTS .. " locate turns for " .. request
        .. " gave no usable answer; the last findings:\n" .. findings_text)
end
-- }}}

-- {{{ function grading.record
-- Appends `graded` and writes output/<request>.grade for the person. The
-- ledger line's text is the machine's own record, read back by parse_graded.
function grading.record(record, request, grade, touched, new_phases, reach, total)
    local new_text = #new_phases > 0 and (" new " .. table.concat(new_phases, " ")) or ""
    ledger.append(record.ledger, "graded", request, string.format("%s; touched %s;%s reach %s",
        grade, #touched > 0 and table.concat(touched, " ") or "-", new_text ~= "" and new_text .. ";" or "",
        #reach > 0 and table.concat(reach, " ") or "-"))
    fs.write(record.output .. "/" .. request .. ".grade", table.concat({
        "request:  " .. request,
        "grade:    " .. grade,
        "touches:  " .. (#touched > 0 and table.concat(touched, " ") or "no existing issue")
            .. (#new_phases > 0 and ("; needs new issues in phase " .. table.concat(new_phases, ", ")) or ""),
        "rebuilds: " .. #reach .. " of " .. total .. " issues" .. (#reach > 0 and (" (" .. table.concat(reach, " ") .. ")") or ""),
        "",
    }, "\n"))
end
-- }}}

-- {{{ function grading.parse_graded
-- The grade, touched ids, new phases and reach, from a `graded` line's text.
function grading.parse_graded(text)
    local grade = text:match("^(%a+);")
    -- {{{ local function ids_after
    local function ids_after(label)
        local field = text:match(label .. " ([^;]*)")
        local out = {}
        for word in (field or ""):gmatch("%S+") do
            if word ~= "-" then out[#out + 1] = word end
        end
        return out
    end
    -- }}}
    return grade, ids_after("touched"), ids_after("new"), ids_after("reach")
end
-- }}}

return grading
