-- 132-checking-prose-templates.lua
--
-- Checks issue 807d: a template with every slot filled matches a stored
-- expected file exactly; a missing slot is a finding, never a blank.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local txt = require("072-the-txt-canvas")
local kinds = require("034-turn-kinds")

local fixtures = kit.DIR .. "/tests/fixtures/prose/"

-- {{{ local function read
local function read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

local template = read(fixtures .. "a-case-told.tmpl")
local data = {
    case = "notes", date = "2026-11-02", files = 14, languages = 3,
    issues = 9, built = 0, state = "designed, not yet built",
}

local text, findings = txt.prose(template, data)
kit.equal(findings, nil, "a fully filled template has no findings")
kit.equal(text, read(fixtures .. "a-case-told.txt"), "every slot filled matches the expected file byte for byte")
kit.equal(text, kinds.fill(template, data), "prose fills exactly as 034's fill does when nothing is missing")

local missing = {}
for k, v in pairs(data) do missing[k] = v end
missing.built = nil
missing.state = nil
local none, holes = txt.prose(template, missing)
kit.equal(none, nil, "a missing slot renders nothing at all, not a blank")
kit.equal(#holes, 2, "every missing slot is its own finding")
kit.equal(holes[1], "the slot 'built' has no value", "the first finding names the first missing slot")
kit.equal(holes[2], "the slot 'state' has no value", "the second names the next")

local once = txt.prose("{{a}} and {{a}}", {})
local _, repeated = txt.prose("{{a}} and {{a}}", {})
kit.equal(once, nil, "a slot missing twice still renders nothing")
kit.equal(#repeated, 1, "a slot missing twice is one finding")

local _, empty = txt.prose("name: {{name}}", { name = "" })
kit.equal(empty[1], "the slot 'name' is empty and would render blank", "an empty value is a finding too")

local _, wrong = txt.prose("{{t}}", { t = { 1, 2 } })
kit.equal(wrong[1], "the slot 't' holds a table, not text or a number", "a table value is a finding, not printed as an address")

local _, stray = txt.prose("hello {{ name}}", { name = "x" })
kit.check(stray and stray[1]:find("opens no slot mark", 1, true) ~= nil, "a '{{' that opens no slot mark is a finding")

kit.equal(txt.prose("no slots here", {}), "no slots here", "a template with no slots is itself")
kit.equal(txt.prose("{{n}}", { n = 0 }), "0", "the number zero is a value, not a blank")
kit.raises(function() txt.prose(nil, {}) end, "a template is a string", "a template that is not a string is refused")

kit.finish()
