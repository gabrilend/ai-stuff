-- tags.lua: a tag is a word starting with # in a note's text.
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
    for _, n in ipairs(notes) do
        for _, t in ipairs(n.tags) do
            if t == tag then
                out[#out + 1] = n
                break
            end
        end
    end
    return out
end

return tags
