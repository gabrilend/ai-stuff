-- search.lua: finding notes by a word in their text, ignoring case.
local search = {}

function search.find(notes, word)
    word = word:lower()
    local out = {}
    for _, n in ipairs(notes) do
        if n.text:lower():find(word, 1, true) then
            out[#out + 1] = n
        end
    end
    return out
end

return search
