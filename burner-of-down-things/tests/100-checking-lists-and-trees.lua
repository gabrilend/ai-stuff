-- 100-checking-lists-and-trees.lua
--
-- Checks issue 807b: the `list` word's bullets all land in the same
-- column, and the `tree` word indents each level by a fixed step,
-- recursively, depth-first.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local txt_canvas = require("072-the-txt-canvas")

-- {{{ local function leading_spaces
-- The number of leading space characters on a line, before its first
-- non-space character.
local function leading_spaces(line)
    local spaces = line:match("^( *)")
    return #spaces
end
-- }}}

local list_rendered = txt_canvas.list({ "café", "b", "third item" })
local list_lines = {}
for line in list_rendered:gmatch("[^\n]+") do
    list_lines[#list_lines + 1] = line
end
kit.equal(#list_lines, 3, "one line per item")
kit.check(list_lines[1]:find("^%- "), "each line opens with a bullet")
kit.equal(leading_spaces(list_lines[1]), leading_spaces(list_lines[2]),
    "every bullet lands in the same column (first item)")
kit.equal(leading_spaces(list_lines[2]), leading_spaces(list_lines[3]),
    "every bullet lands in the same column (later item)")

local tree_rendered = txt_canvas.tree({
    text = "root",
    children = {
        {
            text = "child a",
            children = {
                { text = "grandchild a1" },
                { text = "grandchild a2" },
            },
        },
        { text = "child b" },
    },
})
local tree_lines = {}
for line in tree_rendered:gmatch("[^\n]+") do
    tree_lines[#tree_lines + 1] = line
end
kit.equal(#tree_lines, 5, "one line per node, depth-first")
kit.equal(leading_spaces(tree_lines[1]), 0, "the root sits at the left margin")
kit.check(tree_lines[1]:find("root", 1, true), "the root's own text is on its line")

local step = leading_spaces(tree_lines[2]) - leading_spaces(tree_lines[1])
kit.check(step > 0, "each level indents further than its parent")
kit.equal(leading_spaces(tree_lines[2]), step, "child a is one step deep")
kit.equal(leading_spaces(tree_lines[3]), step * 2, "grandchild a1 is two steps deep")
kit.equal(leading_spaces(tree_lines[4]), step * 2, "grandchild a2 is two steps deep")
kit.equal(leading_spaces(tree_lines[5]), step, "child b is one step deep, same as child a")

kit.finish()
