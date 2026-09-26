-- search.lua (built from blueprint issue 202): plain-text, case-blind search.
local search = {}

function search.find(notes, word)
    word = word:lower()
    local out = {}
    for _, note in ipairs(notes) do
        if note.text:lower():find(word, 1, true) then
            out[#out + 1] = note
        end
    end
    return out
end

return search
