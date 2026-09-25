--[[
profile_txt.lua - Warcraft III profile text files (INI-style)

Some of each object's data lives outside the SLK tables, in text files such as
Units\HumanUnitFunc.txt or Units\ItemStrings.txt:

  // a comment
  [hfoo]
  Art=ReplaceableTextures\CommandButtons\BTNFootman.blp
  Missilespeed=900
  Buttonpos=0,0

Sections are object ids; keys are field names; values are kept as the text
after "=" (lists stay comma-separated, quotes stay). A section that appears
again (in the same or a later file) adds to the first; a key set again keeps
the later value.

Usage:
  local profile = require("parsers.profile_txt")
  local objects = profile.parse(text)              -- { hfoo = { Art = "...", ... } }
  profile.parse(more_text, objects)                -- merge a second file

Issue: issues/completed/112c-route-a-stock-rows-merged-with-map-objects.md
]]

local M = {}

-- {{{ function M.parse
function M.parse(text, into)
    local objects = into or {}
    local current = nil
    for line in text:gmatch("[^\r\n]+") do
        local stripped = line:match("^%s*(.-)%s*$")
        if stripped == "" or stripped:sub(1, 2) == "//" then
            -- blank or comment
        else
            local section = stripped:match("^%[(.+)%]$")
            if section then
                current = objects[section]
                if not current then
                    current = {}
                    objects[section] = current
                end
            elseif current then
                local key, value = stripped:match("^([^=]+)=(.*)$")
                if key then
                    current[key:match("^%s*(.-)%s*$")] = value
                end
            end
        end
    end
    return objects
end
-- }}}

return M
