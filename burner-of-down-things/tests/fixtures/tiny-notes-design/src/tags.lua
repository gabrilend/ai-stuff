-- tags.lua (built from blueprint issue 102): words starting with #.
local tags = {}

function tags.parse(text)
    local found, seen = {}, {}
    for tag in text:gmatch("#([%w_%-]+)") do
        tag = tag:lower()
        if not seen[tag] then
            seen[tag] = true
            found[#found + 1] = tag
        end
    end
    return found
end

function tags.filter(notes, tag)
    tag = tag:gsub("^#", ""):lower()
    local out = {}
    for _, note in ipairs(notes) do
        for _, t in ipairs(note.tags) do
            if t == tag then
                out[#out + 1] = note
                break
            end
        end
    end
    return out
end

return tags
