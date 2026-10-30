-- 058-gbnf.lua — reads a GBNF grammar and says whether a text is one the
-- grammar allows.
--
-- What this is, generally: the porch (032-porch.lua) hands the model a
-- grammar generated from the vocabulary, and llama.cpp lets the model say
-- only what that grammar allows. No model runs where the tests run, so
-- this is the stand-in: a small, slow, exact reader of the same grammar
-- language, enough to prove that every rule the porch names is defined,
-- and that the tool-calls a person would want are sayable (issue 704).
--
-- The GBNF it reads: `name ::= body` lines; a body is alternatives
-- (`|`) of sequences of items; an item is a "literal" (with \" \\ \n \t
-- escapes), a [character class] (ranges, ^ to negate), a rule name, or a
-- (group), each optionally followed by ?, * or +. Comments (#) and rules
-- running over several lines are not used by the porch and not read.
--
-- Matching tries every way through (a set of end positions per item),
-- with each rule's answers at each position remembered, so it is exact
-- and fast enough for a few hundred characters of tool-calls.

local gbnf = {}

-- {{{ local function parse_body()
-- One rule's body into a tree: { alt = { seq, ... } }, a seq being a list
-- of items { lit = "..." } / { class = {...}, neg } / { ref = name } /
-- { group = alt }, each with an optional rep ("?", "*", "+").
local function parse_body(text, name)
    local pos = 1
    -- {{{ local function fail()
    local function fail(why)
        error("gbnf: rule '" .. name .. "', at character " .. pos .. ": " .. why, 0)
    end
    -- }}}
    -- {{{ local function skip()
    local function skip()
        pos = text:find("[^ \t]", pos) or (#text + 1)
    end
    -- }}}
    local alt
    -- {{{ local function escape()
    local ESCAPES = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["]"] = "]",
                      ["["] = "[", ["-"] = "-", ["^"] = "^" }
    local function escape()
        local c = text:sub(pos + 1, pos + 1)
        local out = ESCAPES[c]
        if not out then fail("unknown escape \\" .. c) end
        pos = pos + 2
        return out
    end
    -- }}}
    -- {{{ local function item()
    local function item()
        local c = text:sub(pos, pos)
        local node
        if c == '"' then
            pos = pos + 1
            local parts = {}
            while true do
                local ch = text:sub(pos, pos)
                if ch == "" then fail("a literal never closes") end
                if ch == '"' then pos = pos + 1 break end
                if ch == "\\" then parts[#parts + 1] = escape()
                else parts[#parts + 1] = ch; pos = pos + 1 end
            end
            node = { lit = table.concat(parts) }
        elseif c == "[" then
            pos = pos + 1
            local neg = false
            if text:sub(pos, pos) == "^" then neg = true; pos = pos + 1 end
            local ranges = {}
            while true do
                local ch = text:sub(pos, pos)
                if ch == "" then fail("a character class never closes") end
                if ch == "]" then pos = pos + 1 break end
                local lo
                if ch == "\\" then lo = escape() else lo = ch; pos = pos + 1 end
                local hi = lo
                if text:sub(pos, pos) == "-" and text:sub(pos + 1, pos + 1) ~= "]" then
                    pos = pos + 1
                    local ch2 = text:sub(pos, pos)
                    if ch2 == "\\" then hi = escape() else hi = ch2; pos = pos + 1 end
                end
                ranges[#ranges + 1] = { lo:byte(), hi:byte() }
            end
            node = { class = ranges, neg = neg }
        elseif c == "(" then
            pos = pos + 1
            node = { group = alt() }
            skip()
            if text:sub(pos, pos) ~= ")" then fail("a group never closes") end
            pos = pos + 1
        else
            local ref = text:match("^[%w%-]+", pos)
            if not ref then fail("expected an item, found '" .. c .. "'") end
            pos = pos + #ref
            node = { ref = ref }
        end
        local rep = text:sub(pos, pos)
        if rep == "?" or rep == "*" or rep == "+" then
            node.rep = rep
            pos = pos + 1
        end
        return node
    end
    -- }}}
    -- {{{ alt()
    alt = function()
        local alts = { {} }
        while true do
            skip()
            local c = text:sub(pos, pos)
            if c == "" or c == ")" then break end
            if c == "|" then
                pos = pos + 1
                alts[#alts + 1] = {}
            else
                local seq = alts[#alts]
                seq[#seq + 1] = item()
            end
        end
        return alts
    end
    -- }}}
    local tree = alt()
    if pos <= #text then fail("a ')' with no '(' before it") end
    return tree
end
-- }}}

-- {{{ function gbnf.read()
-- Grammar text into { rules = { name = tree }, order = { name, ... } }.
function gbnf.read(text)
    local grammar = { rules = {}, order = {} }
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("%S") then
            local name, body = line:match("^([%w%-]+)%s*::=%s*(.*)$")
            if not name then error("gbnf: not a rule: " .. line, 0) end
            if grammar.rules[name] then error("gbnf: rule '" .. name .. "' is defined twice", 0) end
            grammar.rules[name] = parse_body(body, name)
            grammar.order[#grammar.order + 1] = name
        end
    end
    return grammar
end
-- }}}

-- {{{ function gbnf.undefined()
-- Every rule name used but never defined, sorted.
function gbnf.undefined(grammar)
    local missing = {}
    -- {{{ local function walk()
    local function walk(alts)
        for _, seq in ipairs(alts) do
            for _, node in ipairs(seq) do
                if node.ref and not grammar.rules[node.ref] then missing[node.ref] = true end
                if node.group then walk(node.group) end
            end
        end
    end
    -- }}}
    for _, name in ipairs(grammar.order) do walk(grammar.rules[name]) end
    local list = {}
    for name in pairs(missing) do list[#list + 1] = name end
    table.sort(list)
    return list
end
-- }}}

-- {{{ function gbnf.matches()
-- Whether the whole of `text` is one the grammar allows from `start`
-- (default "root").
function gbnf.matches(grammar, text, start)
    local memo = {}
    local match_alt
    -- {{{ local function once()
    -- The end positions of one item, without its repetition.
    local function once(node, pos)
        if node.lit then
            if text:sub(pos, pos + #node.lit - 1) == node.lit then return { pos + #node.lit } end
            return {}
        elseif node.class then
            local b = text:byte(pos)
            if not b then return {} end
            local inside = false
            for _, r in ipairs(node.class) do
                if b >= r[1] and b <= r[2] then inside = true break end
            end
            if inside ~= node.neg then return { pos + 1 } end
            return {}
        elseif node.ref then
            local key = node.ref .. "@" .. pos
            if memo[key] == nil then
                memo[key] = {} -- a rule reached again at the same place adds nothing
                memo[key] = match_alt(grammar.rules[node.ref], pos)
            end
            return memo[key]
        else
            return match_alt(node.group, pos)
        end
    end
    -- }}}
    -- {{{ local function item()
    -- The end positions of one item with its repetition.
    local function item(node, pos)
        if not node.rep then return once(node, pos) end
        local ends, seen = {}, {}
        if node.rep ~= "+" then ends[1] = pos; seen[pos] = true end
        local frontier = { pos }
        local first = true
        while #frontier > 0 do
            local nextf = {}
            for _, p in ipairs(frontier) do
                for _, e in ipairs(once(node, p)) do
                    if not seen[e] then
                        seen[e] = true
                        ends[#ends + 1] = e
                        if node.rep ~= "?" then nextf[#nextf + 1] = e end
                    end
                end
            end
            frontier = nextf
            if first and node.rep == "?" then break end
            first = false
        end
        return ends
    end
    -- }}}
    -- {{{ match_alt()
    match_alt = function(alts, pos)
        local ends, seen = {}, {}
        for _, seq in ipairs(alts) do
            local here = { pos }
            for _, node in ipairs(seq) do
                local nexth, nseen = {}, {}
                for _, p in ipairs(here) do
                    for _, e in ipairs(item(node, p)) do
                        if not nseen[e] then nseen[e] = true; nexth[#nexth + 1] = e end
                    end
                end
                here = nexth
                if #here == 0 then break end
            end
            for _, e in ipairs(here) do
                if not seen[e] then seen[e] = true; ends[#ends + 1] = e end
            end
        end
        return ends
    end
    -- }}}
    local root = grammar.rules[start or "root"]
    if not root then error("gbnf: no rule '" .. (start or "root") .. "'", 0) end
    for _, e in ipairs(match_alt(root, 1)) do
        if e == #text + 1 then return true end
    end
    return false
end
-- }}}

return gbnf
