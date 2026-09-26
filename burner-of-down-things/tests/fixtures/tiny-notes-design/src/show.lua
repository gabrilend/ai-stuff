-- show.lua (built from blueprint issue 201): notes as terminal lines.
local show = {}

function show.line(note)
    local out = string.format("%4d  %s  %s", note.id, note.date, note.text)
    -- Tags in brackets only when there are any (201).
    if #note.tags > 0 then
        out = out .. "  [" .. table.concat(note.tags, " ") .. "]"
    end
    return out
end

function show.list(notes)
    if #notes == 0 then
        return "(no notes)"
    end
    local lines = {}
    for i, note in ipairs(notes) do
        lines[i] = show.line(note)
    end
    return table.concat(lines, "\n")
end

return show
