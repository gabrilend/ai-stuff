-- 021-the-tolerance-report.lua - a calculation's results, written for people.
--
-- In plain terms: reads a results file (output/calculations/NAME.results.lua,
-- written by 022) and nothing else -- not the calculation, not the engine --
-- and writes it out as a page: the question, every input with its tolerance
-- and source, every answer with its worst case, its usual spread, its limit
-- and whether it passes, and which inputs to tighten first. Kept apart from
-- the working out so a wrong number can be traced to one side or the other.
--
-- A results file returns:
--   { name, question, made = date string,
--     inputs = list of { name, nominal, unit, minus, plus, from, condition },
--     results = list of results as made by 020 }

local M = {}

-- {{{ local function number()
-- A number short enough to read: 4 significant figures.
local function number(v) return string.format("%.4g", v) end
-- }}}

-- {{{ local function limit_text()
local function limit_text(r)
    if r.at_least and r.at_most then return number(r.at_least) .. " to " .. number(r.at_most) end
    if r.at_least then return "at least " .. number(r.at_least) end
    if r.at_most then return "at most " .. number(r.at_most) end
    return "none"
end
-- }}}

-- {{{ function M.write()
-- results_path (string) -> the report's text.
function M.write(results_path)
    local chunk, problem = loadfile(results_path)
    if chunk == nil then error("cannot load " .. results_path .. ": " .. tostring(problem), 0) end
    local data = chunk()
    local out = {
        "<!-- made by src/021-the-tolerance-report.lua on " .. data.made .. " from " .. results_path
            .. ", so the numbers can be read without the calculation; format in docs/tolerances.md -->",
        "# " .. data.name, "", "**" .. data.question .. "**", "",
        "## Answers", "",
        "| answer | nominal | worst case | usual spread | limit | worst case | spread |",
        "|---|---|---|---|---|---|---|",
    }
    for _, r in ipairs(data.results) do
        out[#out + 1] = string.format("| %s (%s) | %s | %s to %s | %s to %s | %s | %s | %s |",
            r.name, r.unit, number(r.nominal), number(r.worst.low), number(r.worst.high),
            number(r.spread.low), number(r.spread.high), limit_text(r),
            r.worst_verdict, r.spread_verdict)
    end
    out[#out + 1] = ""
    -- shares split two ways: parts (which can be made more exactly) and
    -- conditions (temperature, the wearer: the design must absorb them)
    local is_condition = {}
    for _, input in ipairs(data.inputs) do is_condition[input.name] = input.condition end
    for _, heading in ipairs({ { "What to tighten first (parts)", false }, { "What the design must absorb (conditions)", true } }) do
        out[#out + 1] = "## " .. heading[1]
        out[#out + 1] = ""
        for _, r in ipairs(data.results) do
            local parts = {}
            for _, share in ipairs(r.shares) do
                if (is_condition[share.input] or false) == heading[2] and share.percent >= 0.5 and #parts < 3 then
                    parts[#parts + 1] = string.format("%s %.0f%%", share.input, share.percent)
                end
            end
            out[#out + 1] = "- **" .. r.name .. "**: " .. (#parts > 0 and table.concat(parts, ", ") or "nothing above 0.5%")
        end
        out[#out + 1] = ""
    end
    out[#out + 1] = ""
    out[#out + 1] = "## Inputs"
    out[#out + 1] = ""
    out[#out + 1] = "| input | kind | nominal | below | above | unit | from |"
    out[#out + 1] = "|---|---|---|---|---|---|---|"
    for _, input in ipairs(data.inputs) do
        out[#out + 1] = string.format("| %s | %s | %s | −%s | +%s | %s | %s |", input.name, input.condition and "condition" or "part",
            number(input.nominal), number(input.minus), number(input.plus), input.unit, input.from)
    end
    out[#out + 1] = ""
    out[#out + 1] = "Worst case: every combination of input extremes. Usual spread: root-sum-square of each input's own effect, "
        .. "as if the errors were independent. See docs/tolerances.md."
    return table.concat(out, "\n") .. "\n"
end
-- }}}

return M
