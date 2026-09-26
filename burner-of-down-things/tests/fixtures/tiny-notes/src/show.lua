-- show.lua: notes as lines for a terminal.
local show = {}

function show.line(note)
    local tag_text = ""
    if #note.tags > 0 then
        tag_text = "  [" .. table.concat(note.tags, " ") .. "]"
    end
    return string.format("%4d  %s  %s%s", note.id, note.date, note.text, tag_text)
end

function show.list(notes)
    if #notes == 0 then
        return "(no notes)"
    end
    local lines = {}
    for i, n in ipairs(notes) do
        lines[i] = show.line(n)
    end
    return table.concat(lines, "\n")
end

return show
