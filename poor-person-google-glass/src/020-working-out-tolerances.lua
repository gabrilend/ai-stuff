-- 020-working-out-tolerances.lua - every answer a calculation can give.
--
-- In plain terms: a calculation's formula is asked the same question many
-- times, with its inputs nudged to their extremes, to find the best and
-- worst the answer can be (worst case), how wide it will usually spread
-- when the errors are independent (root-sum-square), and which input causes
-- most of that spread. Nothing is random, so the same calculation always
-- gives the same numbers.
--
-- Results, one per output:
--   { name, unit, nominal,
--     worst = { low, high },            every corner of the inputs' box
--     spread = { centre, low, high },   centre +/- root-sum-square
--     shares = list of { input = name, percent } (largest first),
--     at_least, at_most,                the limit, if any
--     worst_verdict, spread_verdict }   "pass", "fail" or "no limit"
--
-- Why corners: a tolerance stack-up (sums and differences of lengths) only
-- rises or falls with each input, so its extremes are at the corners of the
-- inputs' box and trying all 2^n corners is exact. A formula that turns
-- round inside a range (a square of a difference that can cross zero, say)
-- can be worse inside the box; calculations of that kind say so in their
-- question, and the engine checks the middle of every range as well.

local M = {}

-- {{{ local function evaluate()
-- The formula at one set of input values (a list in input order); checks
-- that every declared output came back as a finite number.
local function evaluate(calculation, values)
    local by_name = {}
    for index, input in ipairs(calculation.inputs) do by_name[input.name] = values[index] end
    local out = calculation.compute(by_name)
    for _, output in ipairs(calculation.outputs) do
        local value = out[output.name]
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
            error(calculation.name .. ": compute gave no finite number for '" .. output.name .. "'", 0)
        end
    end
    return out
end
-- }}}

-- {{{ local function verdict()
local function verdict(low, high, output)
    if output.at_least == nil and output.at_most == nil then return "no limit" end
    if output.at_least ~= nil and low < output.at_least then return "fail" end
    if output.at_most ~= nil and high > output.at_most then return "fail" end
    return "pass"
end
-- }}}

-- {{{ function M.work_out()
-- calculation (checked by 019) -> list of results (above), in output order.
function M.work_out(calculation)
    local inputs = calculation.inputs
    local n = #inputs
    local nominal, middle, lows, highs = {}, {}, {}, {}
    for i, input in ipairs(inputs) do
        nominal[i] = input.nominal
        lows[i], highs[i] = input.nominal - input.minus, input.nominal + input.plus
        middle[i] = (lows[i] + highs[i]) / 2
    end
    local at_nominal = evaluate(calculation, nominal)
    local at_middle = evaluate(calculation, middle)

    -- {{{ worst case: every corner, and the middle (see the note above)
    local low, high = {}, {}
    for _, output in ipairs(calculation.outputs) do
        low[output.name], high[output.name] = math.huge, -math.huge
    end
    local function take(out)
        for _, output in ipairs(calculation.outputs) do
            local v = out[output.name]
            if v < low[output.name] then low[output.name] = v end
            if v > high[output.name] then high[output.name] = v end
        end
    end
    take(at_middle)
    take(at_nominal)
    for corner = 0, 2 ^ n - 1 do
        local values = {}
        for i = 1, n do
            -- bit i-1 of the corner number picks this input's low or high end
            values[i] = (math.floor(corner / 2 ^ (i - 1)) % 2 == 1) and highs[i] or lows[i]
        end
        take(evaluate(calculation, values))
    end
    -- }}}

    -- {{{ spread: each input alone, low end to high end, others at middle
    local effects = {}
    for i = 1, n do
        local at_low, at_high = {}, {}
        for j = 1, n do at_low[j], at_high[j] = middle[j], middle[j] end
        at_low[i], at_high[i] = lows[i], highs[i]
        effects[i] = { low = evaluate(calculation, at_low), high = evaluate(calculation, at_high) }
    end
    -- }}}

    local results = {}
    for _, output in ipairs(calculation.outputs) do
        local name = output.name
        local sum_of_squares, halves = 0, {}
        for i = 1, n do
            -- the larger of the two one-sided moves from the middle: for a
            -- straight-line formula with the middle halfway it equals half
            -- the low-to-high change; for a formula that bends back (a
            -- square, a size) the low-to-high change can cancel to nothing,
            -- which once made a +/-0.05 degree tilt look like no spread at all
            local mid = at_middle[name]
            local half = math.max(math.abs(effects[i].high[name] - mid), math.abs(effects[i].low[name] - mid))
            halves[i] = half
            sum_of_squares = sum_of_squares + half * half
        end
        local rss = math.sqrt(sum_of_squares)
        local shares = {}
        for i, input in ipairs(inputs) do
            shares[i] = { input = input.name, percent = sum_of_squares > 0 and 100 * halves[i] ^ 2 / sum_of_squares or 0 }
        end
        table.sort(shares, function(a, b)
            if a.percent ~= b.percent then return a.percent > b.percent end
            return a.input < b.input
        end)
        local centre = at_middle[name]
        results[#results + 1] = {
            name = name, unit = output.unit, nominal = at_nominal[name],
            worst = { low = low[name], high = high[name] },
            spread = { centre = centre, low = centre - rss, high = centre + rss },
            shares = shares, at_least = output.at_least, at_most = output.at_most,
            worst_verdict = verdict(low[name], high[name], output),
            spread_verdict = verdict(centre - rss, centre + rss, output),
        }
    end
    return results
end
-- }}}

return M
